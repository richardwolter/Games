# Cleans up the cut-out sprites in art/generated:
#   1. flood-fills background + neutral drop shadows away from the outside in
#   2. drops small disconnected speckles (leftovers from neighbouring sheet art)
#   3. rebuilds the alpha edge so there is no light halo from the original white bg
#
# Originals are copied to art/generated/_raw the first time this runs, and are
# always re-read from there so the pass is idempotent.

Add-Type -AssemblyName System.Drawing

$genDir = Join-Path $PSScriptRoot "generated"
$rawDir = Join-Path $genDir "_raw"
if (-not (Test-Path $rawDir)) { New-Item -ItemType Directory -Path $rawDir | Out-Null }

Add-Type -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class SpriteCleaner
{
    static int W, H;
    static byte[] A, R, G, B;

    static void Load(Bitmap bmp)
    {
        W = bmp.Width; H = bmp.Height;
        int n = W * H;
        A = new byte[n]; R = new byte[n]; G = new byte[n]; B = new byte[n];
        BitmapData bd = bmp.LockBits(new Rectangle(0, 0, W, H), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        byte[] buf = new byte[bd.Stride * H];
        Marshal.Copy(bd.Scan0, buf, 0, buf.Length);
        bmp.UnlockBits(bd);
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                int o = y * bd.Stride + x * 4, i = y * W + x;
                B[i] = buf[o]; G[i] = buf[o + 1]; R[i] = buf[o + 2]; A[i] = buf[o + 3];
            }
    }

    static float Value(int i)
    {
        int max = R[i]; if (G[i] > max) max = G[i]; if (B[i] > max) max = B[i];
        return max / 255f;
    }

    static float Sat(int i)
    {
        int max = R[i], min = R[i];
        if (G[i] > max) max = G[i]; if (B[i] > max) max = B[i];
        if (G[i] < min) min = G[i]; if (B[i] < min) min = B[i];
        return max == 0 ? 0f : (max - min) / (float)max;
    }

    // A pixel the outside flood fill is allowed to eat: transparent, near-white
    // background, or a neutral (unsaturated, light) drop shadow.
    static bool Erasable(int i, float shadowValue, float shadowSat)
    {
        if (A[i] < 24) return true;
        float v = Value(i), s = Sat(i);
        if (v > 0.93f && s < 0.10f) return true;          // background white
        return v > shadowValue && s < shadowSat;           // cast shadow
    }

    public static string Clean(string inPath, string outPath, float shadowValue, float shadowSat, int minBlob)
    {
        Bitmap src = new Bitmap(inPath);
        Load(src);
        src.Dispose();
        int n = W * H;

        // --- 1. flood fill the outside, eating background and cast shadows ---
        bool[] outside = new bool[n];
        int[] stack = new int[n];
        int sp = 0;
        for (int x = 0; x < W; x++)
        {
            int t = x, b = (H - 1) * W + x;
            if (!outside[t] && Erasable(t, shadowValue, shadowSat)) { outside[t] = true; stack[sp++] = t; }
            if (!outside[b] && Erasable(b, shadowValue, shadowSat)) { outside[b] = true; stack[sp++] = b; }
        }
        for (int y = 0; y < H; y++)
        {
            int l = y * W, r = y * W + W - 1;
            if (!outside[l] && Erasable(l, shadowValue, shadowSat)) { outside[l] = true; stack[sp++] = l; }
            if (!outside[r] && Erasable(r, shadowValue, shadowSat)) { outside[r] = true; stack[sp++] = r; }
        }
        while (sp > 0)
        {
            int i = stack[--sp];
            int x = i % W, y = i / W;
            for (int dy = -1; dy <= 1; dy++)
                for (int dx = -1; dx <= 1; dx++)
                {
                    int nx = x + dx, ny = y + dy;
                    if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
                    int j = ny * W + nx;
                    if (outside[j] || !Erasable(j, shadowValue, shadowSat)) continue;
                    outside[j] = true; stack[sp++] = j;
                }
        }

        bool[] solid = new bool[n];
        for (int i = 0; i < n; i++) solid[i] = !outside[i] && A[i] >= 96;

        // --- 2. drop small disconnected speckles ---
        int[] label = new int[n];
        for (int i = 0; i < n; i++) label[i] = -1;
        int best = 0;
        System.Collections.Generic.List<int> sizes = new System.Collections.Generic.List<int>();
        for (int s = 0; s < n; s++)
        {
            if (!solid[s] || label[s] >= 0) continue;
            int id = sizes.Count, count = 0;
            sp = 0; stack[sp++] = s; label[s] = id;
            while (sp > 0)
            {
                int i = stack[--sp]; count++;
                int x = i % W, y = i / W;
                for (int dy = -1; dy <= 1; dy++)
                    for (int dx = -1; dx <= 1; dx++)
                    {
                        int nx = x + dx, ny = y + dy;
                        if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
                        int j = ny * W + nx;
                        if (!solid[j] || label[j] >= 0) continue;
                        label[j] = id; stack[sp++] = j;
                    }
            }
            sizes.Add(count);
            if (count > best) best = count;
        }
        int cutoff = Math.Max(minBlob, best / 60);
        int killed = 0;
        for (int i = 0; i < n; i++)
            if (solid[i] && sizes[label[i]] < cutoff) { solid[i] = false; killed++; }

        // --- 3. rebuild colours + alpha along the edge ---
        // Interior pixels (no empty neighbour) keep their colour; boundary pixels
        // get the average of nearby interior colour so the white fringe goes away.
        bool[] interior = new bool[n];
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                int i = y * W + x;
                if (!solid[i]) continue;
                bool all = true;
                for (int dy = -1; dy <= 1 && all; dy++)
                    for (int dx = -1; dx <= 1; dx++)
                    {
                        int nx = x + dx, ny = y + dy;
                        if (nx < 0 || ny < 0 || nx >= W || ny >= H || !solid[ny * W + nx]) { all = false; break; }
                    }
                interior[i] = all;
            }

        byte[] oR = new byte[n], oG = new byte[n], oB = new byte[n], oA = new byte[n];
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                int i = y * W + x;
                int sr = 0, sg = 0, sb = 0, cnt = 0, near = 0;
                for (int dy = -2; dy <= 2; dy++)
                    for (int dx = -2; dx <= 2; dx++)
                    {
                        int nx = x + dx, ny = y + dy;
                        if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
                        int j = ny * W + nx;
                        if (Math.Abs(dx) <= 1 && Math.Abs(dy) <= 1 && solid[j]) near++;
                        if (!interior[j]) continue;
                        sr += R[j]; sg += G[j]; sb += B[j]; cnt++;
                    }

                if (interior[i])
                {
                    oR[i] = R[i]; oG[i] = G[i]; oB[i] = B[i]; oA[i] = 255;
                }
                else if (solid[i])
                {
                    if (cnt > 0) { oR[i] = (byte)(sr / cnt); oG[i] = (byte)(sg / cnt); oB[i] = (byte)(sb / cnt); }
                    else { oR[i] = R[i]; oG[i] = G[i]; oB[i] = B[i]; }
                    oA[i] = 255;
                }
                else if (near >= 4 && cnt > 0)
                {
                    // one soft antialias step outside the silhouette
                    oR[i] = (byte)(sr / cnt); oG[i] = (byte)(sg / cnt); oB[i] = (byte)(sb / cnt);
                    oA[i] = (byte)(near * 24);
                }
            }

        // --- write out, trimmed to the new bounds ---
        int minX = W, minY = H, maxX = -1, maxY = -1;
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
                if (oA[y * W + x] > 0)
                {
                    if (x < minX) minX = x; if (x > maxX) maxX = x;
                    if (y < minY) minY = y; if (y > maxY) maxY = y;
                }
        if (maxX < 0) return "no pixels left in " + inPath;
        int pad = 2;
        minX = Math.Max(0, minX - pad); minY = Math.Max(0, minY - pad);
        maxX = Math.Min(W - 1, maxX + pad); maxY = Math.Min(H - 1, maxY + pad);
        int cw = maxX - minX + 1, ch = maxY - minY + 1;

        Bitmap dst = new Bitmap(cw, ch, PixelFormat.Format32bppArgb);
        BitmapData db = dst.LockBits(new Rectangle(0, 0, cw, ch), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
        byte[] obuf = new byte[db.Stride * ch];
        for (int y = 0; y < ch; y++)
            for (int x = 0; x < cw; x++)
            {
                int i = (minY + y) * W + (minX + x), o = y * db.Stride + x * 4;
                obuf[o] = oB[i]; obuf[o + 1] = oG[i]; obuf[o + 2] = oR[i]; obuf[o + 3] = oA[i];
            }
        Marshal.Copy(obuf, 0, db.Scan0, obuf.Length);
        dst.UnlockBits(db);
        dst.Save(outPath, ImageFormat.Png);
        dst.Dispose();

        return string.Format("{0}x{1} -> {2}x{3}, {4} speckle px removed (cutoff {5})", W, H, cw, ch, killed, cutoff);
    }
}
"@ -ReferencedAssemblies System.Drawing

# name -> shadow value floor, shadow saturation ceiling, min blob size
$targets = @(
    @{ Name = "car_hero_iso.png";      V = 0.46; S = 0.12; Blob = 60 },
    @{ Name = "car_hero_iso_rear.png"; V = 0.46; S = 0.12; Blob = 60 },
    @{ Name = "zombie.png";            V = 0.74; S = 0.45; Blob = 40 },
    @{ Name = "dead_tree.png";         V = 0.40; S = 0.12; Blob = 40 },
    @{ Name = "fence_post.png";        V = 0.62; S = 0.20; Blob = 40 },
    @{ Name = "barrel_debris.png";     V = 0.72; S = 0.12; Blob = 40 },
    # the glow pool on the ground is erased too - it is a baked-in decal that
    # will not sit right on the road; the ring on the machine itself is enclosed
    # by the frame so the outside fill never reaches it.
    @{ Name = "charging_station.png";  V = 0.70; S = 0.55; Blob = 40 },
    @{ Name = "road_tile.png";         V = 0.99; S = 0.02; Blob = 40 }
)

foreach ($t in $targets) {
    $gen = Join-Path $genDir $t.Name
    $raw = Join-Path $rawDir $t.Name
    if (-not (Test-Path $gen) -and -not (Test-Path $raw)) { Write-Host "skip $($t.Name) (missing)"; continue }
    if (-not (Test-Path $raw)) { Copy-Item $gen $raw }
    $msg = [SpriteCleaner]::Clean($raw, $gen, [float]$t.V, [float]$t.S, [int]$t.Blob)
    Write-Host "$($t.Name): $msg"
}

Write-Host "Done."
