# Generates game art locally through ComfyUI (SDXL + LayerDiffuse), driven by
# <project>/art/assets.json. LayerDiffuse emits a true alpha channel in one pass,
# so there is no background-removal guesswork.
#
# This copy is shared by every game repo, so it has no home project of its own.
# It works out which project it is generating for, in this order:
#   1. -Project <path>            explicit, wins over everything
#   2. -Manifest <path>           project is the manifest's grandparent
#                                 (<project>/art/assets.json)
#   3. the current directory      the usual case: cd into the game, run the script
#
# Every path in the manifest -- `out`, `ref` -- stays relative to that project
# root, so a manifest never has to know where this script lives.
#
#   .\tools\generate_art.ps1                 # everything in the manifest
#   .\tools\generate_art.ps1 -Name plank     # just one asset (all its variants)
#   .\tools\generate_art.ps1 -Name plank -DryRun
#
# Start ComfyUI first:  .\tools\comfy.ps1 start

param(
    [string]$Name = "",
    [string]$Manifest = "",
    # Game repo to generate for. Defaults to the current directory; the per-repo
    # tools\generate_art.ps1 wrappers pass their own root explicitly.
    [string]$Project = "",
    [string]$Server = "http://127.0.0.1:8188",
    [string]$ComfyInput = "C:\Users\Administrador\ComfyUI\input",
    [switch]$DryRun,
    [switch]$Force,
    # Write to art/_preview/ instead of the real output path, for trying prompts
    # and denoise values without touching what the game loads.
    [switch]$Preview,
    # Override the manifest's denoise for this run - the fastest dial to explore.
    [double]$Denoise = -1,
    # Fraction of the generation canvas the reference fills. Higher leaves less
    # empty margin for the model to invent junk into.
    [double]$RefFill = 0.97,
    # Override the manifest's variant count - handy for rolling several seeds and
    # picking the cleanest.
    [int]$Variants = 0
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

# Cleanup + framing pass. Diffusion output is never perfectly clean: there is a
# faint alpha haze around the silhouette and usually a few detached specks. Both
# read as grime once the sprite sits on the water, so they get removed here
# rather than by hand.
Add-Type -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class SpriteOut
{
    // A cast shadow in this art style is a light, desaturated blue-grey blob
    // sitting OUTSIDE the sprite's black outline. It is near-opaque, so alpha
    // thresholds cannot touch it - but it is unmistakable by colour, and a flood
    // fill inward from the border stops dead at the black outline, so the
    // sprite's own pale areas (enamel, chrome) are never reached.
    static bool ShadowLike(byte r, byte g, byte b, byte a, double vMin, double sMax)
    {
        if (a < 24) return true;
        int max = r; if (g > max) max = g; if (b > max) max = b;
        int min = r; if (g < min) min = g; if (b < min) min = b;
        double v = max / 255.0;
        double s = max == 0 ? 0.0 : (max - min) / (double)max;
        return v > vMin && s < sMax;
    }

    static int StripShadow(byte[] buf, int W, int H, int stride, double vMin, double sMax)
    {
        int n = W * H;
        bool[] outside = new bool[n];
        int[] stack = new int[n];
        int sp = 0;
        for (int x = 0; x < W; x++)
        {
            int[] seeds = { x, (H - 1) * W + x };
            foreach (int i in seeds)
            {
                int px = i % W, py = i / W, o = py * stride + px * 4;
                if (!outside[i] && ShadowLike(buf[o + 2], buf[o + 1], buf[o], buf[o + 3], vMin, sMax))
                { outside[i] = true; stack[sp++] = i; }
            }
        }
        for (int y = 0; y < H; y++)
        {
            int[] seeds = { y * W, y * W + W - 1 };
            foreach (int i in seeds)
            {
                int px = i % W, py = i / W, o = py * stride + px * 4;
                if (!outside[i] && ShadowLike(buf[o + 2], buf[o + 1], buf[o], buf[o + 3], vMin, sMax))
                { outside[i] = true; stack[sp++] = i; }
            }
        }
        int cleared = 0;
        while (sp > 0)
        {
            int i = stack[--sp];
            int x = i % W, y = i / W, o = y * stride + x * 4;
            if (buf[o + 3] != 0) cleared++;
            buf[o] = 0; buf[o + 1] = 0; buf[o + 2] = 0; buf[o + 3] = 0;
            for (int dy = -1; dy <= 1; dy++)
                for (int dx = -1; dx <= 1; dx++)
                {
                    int nx = x + dx, ny = y + dy;
                    if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
                    int j = ny * W + nx;
                    if (outside[j]) continue;
                    int no = ny * stride + nx * 4;
                    if (!ShadowLike(buf[no + 2], buf[no + 1], buf[no], buf[no + 3], vMin, sMax)) continue;
                    outside[j] = true; stack[sp++] = j;
                }
        }
        return cleared;
    }

    // Strips the shadow off a reference sprite before it is used for img2img, so
    // the model never sees one to copy.
    public static string StripShadowFile(string src, string dst, double vMin, double sMax)
    {
        Bitmap bmp = new Bitmap(src);
        int W = bmp.Width, H = bmp.Height;
        BitmapData bd = bmp.LockBits(new Rectangle(0, 0, W, H), ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        byte[] buf = new byte[bd.Stride * H];
        Marshal.Copy(bd.Scan0, buf, 0, buf.Length);
        int cleared = StripShadow(buf, W, H, bd.Stride, vMin, sMax);
        Marshal.Copy(buf, 0, bd.Scan0, buf.Length);
        bmp.UnlockBits(bd);
        bmp.Save(dst, ImageFormat.Png);
        bmp.Dispose();
        return cleared + "px";
    }

    // Forces every pixel opaque. Rescaling with bicubic makes GDI+ sample past
    // the source edge, which leaves the outermost pixels semi-transparent - on an
    // opaque backdrop that shows up as dark seams along the border.
    public static string Flatten(string path)
    {
        // Copy into memory first: Bitmap keeps the source file open, so saving
        // back to the same path throws a generic GDI+ error.
        Bitmap b;
        using (Bitmap loaded = new Bitmap(path))
            b = new Bitmap(loaded);
        int W = b.Width, H = b.Height, fixedPx = 0;
        BitmapData bd = b.LockBits(new Rectangle(0, 0, W, H), ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        byte[] buf = new byte[bd.Stride * H];
        Marshal.Copy(bd.Scan0, buf, 0, buf.Length);
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                int o = y * bd.Stride + x * 4;
                if (buf[o + 3] != 255) { buf[o + 3] = 255; fixedPx++; }
            }
        Marshal.Copy(buf, 0, bd.Scan0, buf.Length);
        b.UnlockBits(bd);
        b.Save(path, ImageFormat.Png);
        b.Dispose();
        return fixedPx + "px forced opaque";
    }

    public static string Process(string src, string dst, int targetW, int targetH,
                                 bool trim, string fit, int deadzone, double speckleFrac,
                                 bool solo, bool stripShadow, double shadowV, double shadowS)
    {
        Bitmap bmp = new Bitmap(src);
        int W = bmp.Width, H = bmp.Height, n = W * H;
        BitmapData bd = bmp.LockBits(new Rectangle(0, 0, W, H), ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        byte[] buf = new byte[bd.Stride * H];
        Marshal.Copy(bd.Scan0, buf, 0, buf.Length);

        // 0. Cast shadow, flood-filled from the border inward.
        int shadowPx = 0;
        if (stripShadow) shadowPx = StripShadow(buf, W, H, bd.Stride, shadowV, shadowS);

        // 1. Alpha deadzone - kills the low-level haze the VAE leaves behind.
        int hazed = 0;
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                int o = y * bd.Stride + x * 4;
                if (buf[o + 3] > 0 && buf[o + 3] <= deadzone) { buf[o + 3] = 0; hazed++; }
            }

        // 2. Speckle removal - drop blobs far smaller than the main silhouette.
        int[] label = new int[n];
        for (int i = 0; i < n; i++) label[i] = -1;
        int[] stack = new int[n];
        System.Collections.Generic.List<int> sizes = new System.Collections.Generic.List<int>();
        int biggest = 0;
        for (int s = 0; s < n; s++)
        {
            int sx = s % W, sy = s / W;
            if (label[s] >= 0 || buf[sy * bd.Stride + sx * 4 + 3] == 0) continue;
            int id = sizes.Count, count = 0, sp = 0;
            stack[sp++] = s; label[s] = id;
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
                        if (label[j] >= 0 || buf[ny * bd.Stride + nx * 4 + 3] == 0) continue;
                        label[j] = id; stack[sp++] = j;
                    }
            }
            sizes.Add(count);
            if (count > biggest) biggest = count;
        }
        // `solo` keeps ONLY the largest blob. At high denoise the model paints
        // extra structure into the empty canvas - ghost outlines, stray feet -
        // which is real opaque art, not a speck, so no size threshold catches it.
        // The sprite is by definition one object, so everything else goes.
        int biggestId = -1;
        for (int i = 0; i < sizes.Count; i++) if (sizes[i] == biggest) { biggestId = i; break; }
        int cutoff = (int)(biggest * speckleFrac);
        int specks = 0;
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                int i = y * W + x, o = y * bd.Stride + x * 4;
                if (label[i] < 0) continue;
                bool drop = solo ? (label[i] != biggestId) : (sizes[label[i]] < cutoff);
                if (drop)
                { buf[o] = 0; buf[o + 1] = 0; buf[o + 2] = 0; buf[o + 3] = 0; specks++; }
            }

        // 2b. De-fringe. LayerDiffuse leaves the semi-transparent rim carrying a
        // pale halo colour, which reads as a white outline once composited. Take
        // the colour of the nearest fully-opaque pixels instead and keep the
        // alpha, so the edge stays smooth but stops glowing.
        int fringed = 0;
        byte[] copy = (byte[])buf.Clone();
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                int o = y * bd.Stride + x * 4;
                byte a = copy[o + 3];
                if (a == 0 || a == 255) continue;
                int sr = 0, sg = 0, sb = 0, cnt = 0;
                for (int dy = -2; dy <= 2; dy++)
                    for (int dx = -2; dx <= 2; dx++)
                    {
                        int nx = x + dx, ny = y + dy;
                        if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
                        int no = ny * bd.Stride + nx * 4;
                        if (copy[no + 3] != 255) continue;
                        sb += copy[no]; sg += copy[no + 1]; sr += copy[no + 2]; cnt++;
                    }
                if (cnt == 0) continue;
                buf[o] = (byte)(sb / cnt); buf[o + 1] = (byte)(sg / cnt); buf[o + 2] = (byte)(sr / cnt);
                fringed++;
            }

        Marshal.Copy(buf, 0, bd.Scan0, buf.Length);
        bmp.UnlockBits(bd);

        // 3. Trim to what is actually left.
        int x0 = 0, y0 = 0, x1 = W - 1, y1 = H - 1;
        if (trim)
        {
            int minX = W, minY = H, maxX = -1, maxY = -1;
            for (int y = 0; y < H; y++)
                for (int x = 0; x < W; x++)
                    if (buf[y * bd.Stride + x * 4 + 3] > 0)
                    {
                        if (x < minX) minX = x; if (x > maxX) maxX = x;
                        if (y < minY) minY = y; if (y > maxY) maxY = y;
                    }
            if (maxX >= 0) { x0 = minX; y0 = minY; x1 = maxX; y1 = maxY; }
        }
        int cw = x1 - x0 + 1, ch = y1 - y0 + 1;

        // 4. Frame. targetW/H of 0 means "keep native size" - the sprite stays at
        // full generated resolution so it can be rescaled later without loss.
        int ow = targetW > 0 ? targetW : cw;
        int oh = targetH > 0 ? targetH : ch;
        Bitmap outBmp = new Bitmap(ow, oh, PixelFormat.Format32bppArgb);
        Graphics g = Graphics.FromImage(outBmp);
        g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
        g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.HighQuality;
        g.CompositingQuality = System.Drawing.Drawing2D.CompositingQuality.HighQuality;
        Rectangle destRect;
        if (fit == "contain" && targetW > 0)
        {
            double sc = Math.Min((double)ow / cw, (double)oh / ch);
            int dw = (int)Math.Round(cw * sc), dh = (int)Math.Round(ch * sc);
            destRect = new Rectangle((ow - dw) / 2, (oh - dh) / 2, dw, dh);
        }
        else destRect = new Rectangle(0, 0, ow, oh);
        g.DrawImage(bmp, destRect, x0, y0, cw, ch, GraphicsUnit.Pixel);
        g.Dispose();
        outBmp.Save(dst, ImageFormat.Png);
        outBmp.Dispose();
        bmp.Dispose();

        // Shadow-bar screen. The model sometimes invents a dark neutral slab under
        // the sprite. It is near-black, so no colour flood fill can remove it
        // without eating the sprite's own black outline - the only fix is another
        // seed, so flag it loudly rather than shipping it.
        //
        // Skipped for long thin pieces: on a plank only ~77px tall, the bottom 18%
        // IS the plank's own outline, a wide dark band spanning the full width, so
        // the test fires on every seed and means nothing.
        int barRows = 0;
        bool barCheck = ch > 0 && (double)cw / ch <= 3.0;
        for (int y = y0 + (int)((y1 - y0) * 0.82); barCheck && y <= y1; y++)
        {
            int filled = 0, dark = 0;
            for (int x = x0; x <= x1; x++)
            {
                int o = y * bd.Stride + x * 4;
                if (buf[o + 3] < 8) continue;
                filled++;
                int r = buf[o + 2], gg = buf[o + 1], bb = buf[o];
                int mx = Math.Max(r, Math.Max(gg, bb)), mn = Math.Min(r, Math.Min(gg, bb));
                double v = mx / 255.0, s = mx == 0 ? 0.0 : (mx - mn) / (double)mx;
                if (v < 0.30 && s < 0.25) dark++;
            }
            if (filled > cw * 0.6 && dark > filled * 0.85) barRows++;
        }

        return string.Format("{0}x{1} -> {2}x{3}  (shadow {4}px, haze {5}px, specks {6}px, defringed {7}px){8}",
            cw, ch, ow, oh, shadowPx, hazed, specks, fringed,
            (barCheck && barRows >= 4)
                ? "  <-- WARNING: " + barRows + " rows look like a dark shadow bar, try another seed"
                : (barCheck ? "" : "  [bar-check skipped: too long and thin to test]"));
    }
}
"@ -ReferencedAssemblies System.Drawing

# Resolve the project root before anything else -- `out` and `ref` in the
# manifest are relative to it. $PSScriptRoot is deliberately NOT used: this
# script lives in _pipeline, which is not any game's root.
if ($Project) {
    $projectRoot = (Resolve-Path $Project).Path
}
elseif ($Manifest) {
    # <project>\art\assets.json -- up two levels is the project.
    $projectRoot = Split-Path (Split-Path (Resolve-Path $Manifest).Path -Parent) -Parent
}
else {
    $projectRoot = (Get-Location).Path
}

if (-not $Manifest) { $Manifest = Join-Path $projectRoot "art\assets.json" }
if (-not (Test-Path $Manifest)) {
    throw "manifest not found: $Manifest`n(project root resolved to '$projectRoot' -- pass -Project if that is wrong)"
}

$data = Get-Content $Manifest -Raw | ConvertFrom-Json
$def = $data.defaults

function Get-Setting($asset, [string]$key, $fallback) {
    if ($key -eq 'denoise' -and $Denoise -ge 0) { return $Denoise }
    $p = $asset.PSObject.Properties[$key]
    if ($p -and $null -ne $p.Value) { return $p.Value }
    $p = $def.PSObject.Properties[$key]
    if ($p -and $null -ne $p.Value) { return $p.Value }
    return $fallback
}

# --- build the ComfyUI API graph -------------------------------------------
# Transparent assets route the model through LayeredDiffusionApply and decode
# via LayeredDiffusionDecodeRGBA. Opaque ones use a plain VAEDecode.
# Lays a reference sprite onto a neutral grey canvas at the generation size,
# preserving aspect. This becomes the img2img starting image, so the result keeps
# the reference's silhouette and viewing angle instead of inventing its own.
function Write-RefCanvas([string]$refPath, [int]$w, [int]$h, [string]$dest) {
    $src = [System.Drawing.Bitmap]::FromFile($refPath)
    try {
        $canvas = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [System.Drawing.Graphics]::FromImage($canvas)
        $g.Clear([System.Drawing.Color]::FromArgb(255, 128, 128, 128))
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        # Fill most of the frame. Empty margin is where the model invents extra
        # structure - ghost outlines and stray feet - which LayerDiffuse then
        # makes opaque and fuses to the sprite. Less margin, less invention.
        $s = [Math]::Min(($w * $RefFill) / $src.Width, ($h * $RefFill) / $src.Height)
        $dw = [int][Math]::Round($src.Width * $s); $dh = [int][Math]::Round($src.Height * $s)
        $g.DrawImage($src, [int](($w - $dw) / 2), [int](($h - $dh) / 2), $dw, $dh)
        $g.Dispose()
        $canvas.Save($dest, [System.Drawing.Imaging.ImageFormat]::Png)
        $canvas.Dispose()
    }
    finally { $src.Dispose() }
}

function New-Graph($asset, [int]$seed, [bool]$transparent, [string]$refFile, [string]$poseFile) {
    $w, $h = $asset.gen
    $prompt = "$($asset.prompt), $(Get-Setting $asset 'style' '')"

    # `negative` replaces the shared list; `negative_extra` appends to it. Prefer
    # appending: a full override is a copy of the defaults that silently stops
    # tracking them the moment the shared list is improved.
    $negative = Get-Setting $asset 'negative' ''
    $negExtra = Get-Setting $asset 'negative_extra' ''
    if ($negExtra) { $negative = "$negExtra, $negative" }

    $g = [ordered]@{
        "1" = @{ class_type = "CheckpointLoaderSimple"; inputs = @{ ckpt_name = (Get-Setting $asset 'model' '') } }
        "2" = @{ class_type = "CLIPTextEncode";        inputs = @{ text = $prompt;                          clip = @("1", 1) } }
        "3" = @{ class_type = "CLIPTextEncode";        inputs = @{ text = $negative;                        clip = @("1", 1) } }
        "4" = @{ class_type = "EmptyLatentImage";      inputs = @{ width = [int]$w; height = [int]$h; batch_size = 1 } }
        "6" = @{ class_type = "KSampler"; inputs = @{
                seed = $seed
                steps = [int](Get-Setting $asset 'steps' 30)
                cfg = [double](Get-Setting $asset 'cfg' 6.5)
                sampler_name = (Get-Setting $asset 'sampler' 'dpmpp_2m')
                scheduler = (Get-Setting $asset 'scheduler' 'karras')
                denoise = [double](Get-Setting $asset 'denoise' 1.0)
                model = @("5", 0)
                positive = @("2", 0); negative = @("3", 0); latent_image = @("4", 0)
            } }
        "7" = @{ class_type = "VAEDecode"; inputs = @{ samples = @("6", 0); vae = @("1", 2) } }
    }

    # img2img: start from the reference instead of noise, so the established
    # silhouette and viewing angle survive.
    if ($refFile) {
        $g["10"] = @{ class_type = "LoadImage"; inputs = @{ image = $refFile } }
        $g["11"] = @{ class_type = "VAEEncode"; inputs = @{ pixels = @("10", 0); vae = @("1", 2) } }
        $g["6"].inputs.latent_image = @("11", 0)
    }

    # ControlNet: the pose comes from an explicit skeleton image instead of from
    # the prompt, which cannot hold a camera angle on its own. This is what lets
    # `denoise` drop the reference's grip on anatomy without the figure
    # collapsing -- structure from the skeleton, identity from the reference.
    #
    # Applied to BOTH conditionings (ApplyAdvanced), so the negative prompt is
    # posed too; applying to the positive alone lets the model satisfy the
    # negative with an off-pose figure.
    if ($poseFile) {
        $g["12"] = @{ class_type = "ControlNetLoader"; inputs = @{
                control_net_name = (Get-Setting $asset 'control_model' 'controlnet-openpose-sdxl.safetensors') } }
        $g["13"] = @{ class_type = "LoadImage"; inputs = @{ image = $poseFile } }
        $g["14"] = @{ class_type = "ControlNetApplyAdvanced"; inputs = @{
                positive = @("2", 0)
                negative = @("3", 0)
                control_net = @("12", 0)
                image = @("13", 0)
                strength = [double](Get-Setting $asset 'control_strength' 0.8)
                # Releasing control before the last steps lets the model finish
                # detail freely; holding it to 1.0 tends to keep a stiff,
                # mannequin-like pose.
                start_percent = [double](Get-Setting $asset 'control_start' 0.0)
                end_percent = [double](Get-Setting $asset 'control_end' 0.75) } }
        $g["6"].inputs.positive = @("14", 0)
        $g["6"].inputs.negative = @("14", 1)
    }

    if ($transparent) {
        $g["5"] = @{ class_type = "LayeredDiffusionApply"; inputs = @{
                model = @("1", 0)
                config = (Get-Setting $asset 'ld_config' 'SDXL, Conv Injection')
                weight = [double](Get-Setting $asset 'ld_weight' 1.0) } }
        $g["8"] = @{ class_type = "LayeredDiffusionDecodeRGBA"; inputs = @{
                samples = @("6", 0); images = @("7", 0); sd_version = "SDXL"; sub_batch_size = 16 } }
        $saveFrom = "8"
    }
    else {
        # No LayerDiffuse: KSampler takes the raw checkpoint model and we keep
        # the plain VAEDecode output.
        $g["6"].inputs.model = @("1", 0)
        $saveFrom = "7"
    }

    $g["9"] = @{ class_type = "SaveImage"; inputs = @{ images = @($saveFrom, 0); filename_prefix = "gen_$($asset.name)" } }
    return $g
}

function Invoke-Comfy($graph) {
    $body = @{ prompt = $graph } | ConvertTo-Json -Depth 12 -Compress
    $resp = Invoke-RestMethod "$Server/prompt" -Method Post -Body $body -ContentType "application/json"
    $id = $resp.prompt_id

    # Poll history. Generation is 10-60s depending on size and steps.
    for ($i = 0; $i -lt 600; $i++) {
        Start-Sleep -Milliseconds 1000
        try { $hist = Invoke-RestMethod "$Server/history/$id" -TimeoutSec 10 } catch { continue }
        $entry = $hist.$id
        if (-not $entry) { continue }
        if ($entry.status -and $entry.status.status_str -eq "error") {
            throw "ComfyUI reported an error: $($entry.status.messages | ConvertTo-Json -Depth 6 -Compress)"
        }
        if ($entry.outputs) {
            foreach ($node in $entry.outputs.PSObject.Properties) {
                if ($node.Value.images) { return $node.Value.images[0] }
            }
        }
    }
    throw "timed out waiting for prompt $id"
}

function Get-Image($img, [string]$dest) {
    $url = "$Server/view?filename=$([uri]::EscapeDataString($img.filename))&subfolder=$([uri]::EscapeDataString($img.subfolder))&type=$($img.type)"
    Invoke-WebRequest $url -OutFile $dest -UseBasicParsing
}

# --- post-process ------------------------------------------------------------
# `target` may be [w,h] to fit a fixed size, or the string "native" to keep the
# trimmed silhouette at full generated resolution (rescale later, losslessly).
function Convert-Asset($src, $dst, $target, [bool]$trim, [string]$fit, [int]$deadzone,
    [double]$speckleFrac, [bool]$solo, [bool]$stripShadow, [double]$shadowV, [double]$shadowS) {
    $tw = 0; $th = 0
    if ($target -is [array]) { $tw = [int]$target[0]; $th = [int]$target[1] }
    return [SpriteOut]::Process($src, $dst, $tw, $th, $trim, $fit, $deadzone, $speckleFrac,
        $solo, $stripShadow, $shadowV, $shadowS)
}

# --- main -------------------------------------------------------------------
# Checked lazily: procedural assets never touch ComfyUI, so a stopped server is
# only an error for the ones that actually need it.
$script:ComfyChecked = $false
function Assert-Comfy {
    if ($script:ComfyChecked) { return }
    try { $null = Invoke-RestMethod "$Server/system_stats" -TimeoutSec 5 }
    catch { throw "ComfyUI is not responding at $Server. Start it with: .\tools\comfy.ps1 start" }
    $script:ComfyChecked = $true
}

$assets = $data.assets
if ($Name) {
    $assets = $assets | Where-Object { $_.name -eq $Name }
    if (-not $assets) { throw "no asset named '$Name' in the manifest" }
}

$tmp = Join-Path $env:TEMP "straitart"
New-Item -ItemType Directory -Force $tmp | Out-Null

# Draws a lid cap over the centre of a finished sprite.
#
# LayerDiffuse punches a light disc ringed in black out to alpha 0 - it reads the
# shape as a washer - so at any denoise high enough to weather the drum, the lid
# becomes a hole. Drawing it afterwards removes it from the model's control
# entirely, which also makes the lid identical across regenerations.
function Add-Lid([string]$file, $lid) {
    $bmp = [System.Drawing.Bitmap]::FromFile($file)
    try {
        $img = New-Object System.Drawing.Bitmap($bmp.Width, $bmp.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [System.Drawing.Graphics]::FromImage($img)
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.DrawImage($bmp, 0, 0, $bmp.Width, $bmp.Height)

        $parse = { param($s) $q = $s -split ','; [System.Drawing.Color]::FromArgb(255, [int]$q[0], [int]$q[1], [int]$q[2]) }
        $body = & $parse ($lid.color)
        $line = & $parse ($lid.outline)

        $d = [Math]::Min($bmp.Width, $bmp.Height) * [double]$lid.frac
        $x = ($bmp.Width - $d) / 2.0
        $y = ($bmp.Height - $d) / 2.0
        $ringW = [Math]::Max(3, $d * 0.14)

        $br = New-Object System.Drawing.SolidBrush($body)
        $g.FillEllipse($br, $x, $y, $d, $d); $br.Dispose()
        $pen = New-Object System.Drawing.Pen($line, $ringW)
        $g.DrawEllipse($pen, ($x + $ringW / 2), ($y + $ringW / 2), ($d - $ringW), ($d - $ringW)); $pen.Dispose()
        $hi = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(80, 255, 255, 255))
        $g.FillEllipse($hi, ($x + $d * 0.20), ($y + $d * 0.16), ($d * 0.44), ($d * 0.34)); $hi.Dispose()

        $g.Dispose()
        $bmp.Dispose()
        $img.Save($file, [System.Drawing.Imaging.ImageFormat]::Png)
        $img.Dispose()
        return "lid redrawn d=$([int]$d)px"
    }
    catch { $bmp.Dispose(); throw }
}

foreach ($asset in $assets) {
    $variants = if ($Variants -gt 0) { $Variants } else { [int](Get-Setting $asset 'variants' 1) }
    $transparent = [bool](Get-Setting $asset 'transparent' $true)
    $trim = [bool](Get-Setting $asset 'trim' $true)
    $target = $asset.target
    $baseSeed = [int](Get-Setting $asset 'seed' 0)

    for ($v = 1; $v -le $variants; $v++) {
        $outRel = $asset.out
        if ($variants -gt 1) { $outRel = $outRel -replace '\.png$', "_$v.png" }
        if ($Preview) {
            # Invariant formatting: this machine's locale writes 0,5 not 0.5,
            # which puts commas in filenames.
            $den = [double](Get-Setting $asset 'denoise' 1.0)
            $tag = ($den.ToString([System.Globalization.CultureInfo]::InvariantCulture)) -replace '\.', ''
            $outRel = "art/_preview/$($asset.name)_${v}_d$tag.png"
        }
        $outAbs = Join-Path $projectRoot $outRel
        $seed = $baseSeed + $v - 1

        if ((Test-Path $outAbs) -and -not $Force) {
            Write-Host "skip   $outRel (exists; -Force to regenerate)"
            continue
        }

        # Stage the reference into ComfyUI's input folder if this asset uses one.
        $refFile = ""
        $refClean = ""
        $refSetting = Get-Setting $asset 'ref' ""
        if ($refSetting) {
            $refAbs = Join-Path $projectRoot $refSetting
            if (-not (Test-Path $refAbs)) { throw "reference not found for '$($asset.name)': $refAbs" }
            $refFile = "ref_$($asset.name)_$v.png"
            New-Item -ItemType Directory -Force $ComfyInput | Out-Null
            # Strip the reference's own cast shadow first - otherwise img2img
            # faithfully reproduces it and no amount of negative prompting helps.
            $refClean = $refAbs
            if ([bool](Get-Setting $asset 'strip_shadow' $true)) {
                $refClean = Join-Path $tmp "refclean_$($asset.name).png"
                $n = [SpriteOut]::StripShadowFile($refAbs, $refClean,
                    [double](Get-Setting $asset 'shadow_value' 0.60),
                    [double](Get-Setting $asset 'shadow_sat' 0.30))
                Write-Host "  ref shadow stripped: $n"
            }
            Write-RefCanvas $refClean $asset.gen[0] $asset.gen[1] (Join-Path $ComfyInput $refFile)
        }

        # Stage the ControlNet pose image the same way. It is NOT laid onto a grey
        # canvas like a reference: an OpenPose skeleton must reach the model as
        # drawn, on black, at generation size, or the joint positions shift and
        # the pose the model sees is not the pose that was authored.
        $poseFile = ""
        $poseSetting = Get-Setting $asset 'pose' ""
        if ($poseSetting) {
            $poseAbs = Join-Path $projectRoot $poseSetting
            if (-not (Test-Path $poseAbs)) { throw "pose not found for '$($asset.name)': $poseAbs" }
            $poseFile = "pose_$($asset.name)_$v.png"
            New-Item -ItemType Directory -Force $ComfyInput | Out-Null
            Copy-Item $poseAbs (Join-Path $ComfyInput $poseFile) -Force
        }

        $den = [double](Get-Setting $asset 'denoise' 1.0)
        $useModel = [bool](Get-Setting $asset 'generate' $true)
        $mode = if (-not $useModel) { "procedural (no diffusion)" }
                elseif ($refFile) { "img2img ref=$refSetting denoise=$den" }
                else { "txt2img" }
        if ($poseFile) { $mode += " +controlnet pose=$poseSetting str=$(Get-Setting $asset 'control_strength' 0.8)" }
        Write-Host "gen    $outRel  seed=$seed  $($asset.gen[0])x$($asset.gen[1])  $mode"

        $raw = Join-Path $tmp "$($asset.name)_$v.png"
        if (-not $useModel) {
            # The reference IS the artwork. Skip ComfyUI entirely and send the
            # drawing straight through the same cleanup and framing, so
            # procedural and generated assets come out of one pipeline.
            if (-not $refClean) { throw "'$($asset.name)' has generate:false but no ref to draw from" }
            Copy-Item $refClean $raw -Force
        }
        else {
            if ($DryRun) {
                $graph = New-Graph $asset $seed $transparent $refFile $poseFile
                Write-Host ($graph | ConvertTo-Json -Depth 12)
                continue
            }
            Assert-Comfy
            $graph = New-Graph $asset $seed $transparent $refFile $poseFile
            $img = Invoke-Comfy $graph
            Get-Image $img $raw
        }

        New-Item -ItemType Directory -Force (Split-Path $outAbs -Parent) | Out-Null
        $info = Convert-Asset $raw $outAbs $target $trim (Get-Setting $asset 'fit' 'stretch') `
            ([int](Get-Setting $asset 'deadzone' 32)) ([double](Get-Setting $asset 'speckle' 0.02)) `
            ([bool](Get-Setting $asset 'solo' $false)) ([bool](Get-Setting $asset 'strip_shadow' $true)) `
            ([double](Get-Setting $asset 'shadow_value' 0.60)) ([double](Get-Setting $asset 'shadow_sat' 0.30))
        Write-Host "  ok   $info"

        if (-not $transparent) { Write-Host "       $([SpriteOut]::Flatten($outAbs))" }

        $lid = Get-Setting $asset 'lid' $null
        if ($lid) { Write-Host "       $(Add-Lid $outAbs $lid)" }
    }
}

Write-Host "Done."
