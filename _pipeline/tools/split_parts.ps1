# Slices an approved character sprite into cutout puppet parts.
#
#   .\tools\split_parts.ps1 -Spec art\kid_parts.json
#   .\tools\split_parts.ps1 -Spec art\kid_parts.json -DebugOverlay
#
# WHY CUT ONE SPRITE instead of generating each limb separately: consistency.
# Parts generated independently drift -- six prompts produce six slightly
# different suits, and no amount of seed matching fixes it. Cutting the single
# approved sprite means every part is, by construction, the same character.
#
# The cost is occlusion: an arm cut away leaves a hole in the torso behind it.
# That is acceptable here because this is a paper-puppet rig doing small
# rotations and bobs, never a limb swinging clear of the body. If a pose ever
# needs that, the hole gets painted once, by hand, not solved by the pipeline.
#
# PIVOTS ARE THE REAL OUTPUT. A trimmed PNG has lost all memory of where it sat
# on the body, and a joint position cannot be recovered from it afterwards --
# guessing puts the shoulder in the middle of the bicep and the arm swings like
# a broken wing. They are authored in the spec, in source-image coordinates, and
# written through to parts.json in part-local pixels for the rig builder.

param(
    [Parameter(Mandatory = $true)][string]$Spec,
    [string]$Project = "",
    # Writes a check image with every box outlined and every pivot crossed, over
    # the original. Authoring the spec without looking at this is guesswork.
    [switch]$DebugOverlay,
    # How far a refilled erase reaches past the cut, in source pixels. Enough to
    # rebuild an edge, not enough to repaint the limb's whole footprint.
    [int]$FillSpan = 16
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

# Erasing a limb out of the torso leaves a hole, and the hole is only hidden
# while the limb sits where it was drawn. Raise an arm and the audience sees
# straight through the chest, with hard rectangular edges because the cut was a
# rectangle.
#
# So the cut is refilled: for every erased row, the nearest surviving pixel just
# inside the cut is smeared back out across it. The result is a slightly smudged
# but solid body edge -- and it is only ever seen when a limb has swung away,
# where "vaguely torso-coloured" is all it needs to be.
#
# The fill is clipped to the ORIGINAL silhouette, so it rebuilds the body without
# inventing any shape beyond where the character actually was.
Add-Type -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class SmearFill
{
    // dir: 0 donor lies to the right of the cut, 1 to the left, 2 below, 3 above.
    // span: how far the fill reaches past the cut edge. It must stay SMALL. The
    // job is to rebuild the body's edge so the seam is not a hole -- not to
    // repaint the whole cut, which would lay a torso-coloured slab across the
    // area the limb used to occupy and leave him looking twice as wide.
    public static void Fill(Bitmap crop, Bitmap src, int ox, int oy,
                            int rx0, int ry0, int rx1, int ry1, int dir, int span)
    {
        int W = crop.Width, H = crop.Height;
        rx0 = Math.Max(0, rx0); ry0 = Math.Max(0, ry0);
        rx1 = Math.Min(W, rx1); ry1 = Math.Min(H, ry1);
        if (rx1 <= rx0 || ry1 <= ry0) return;

        BitmapData cd = crop.LockBits(new Rectangle(0, 0, W, H), ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        BitmapData sd = src.LockBits(new Rectangle(0, 0, src.Width, src.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        byte[] cb = new byte[cd.Stride * H];
        byte[] sb = new byte[sd.Stride * src.Height];
        Marshal.Copy(cd.Scan0, cb, 0, cb.Length);
        Marshal.Copy(sd.Scan0, sb, 0, sb.Length);

        bool horizontal = (dir == 0 || dir == 1);
        int outer = horizontal ? ry1 - ry0 : rx1 - rx0;

        for (int k = 0; k < outer; k++)
        {
            int fixedCoord = horizontal ? ry0 + k : rx0 + k;

            // Find the donor: first opaque pixel just past the cut, on the body side.
            int dx = -1, dy = -1;
            for (int step = 0; step < 220; step++)
            {
                int px, py;
                if (dir == 0) { px = rx1 + step; py = fixedCoord; }
                else if (dir == 1) { px = rx0 - 1 - step; py = fixedCoord; }
                else if (dir == 2) { px = fixedCoord; py = ry1 + step; }
                else { px = fixedCoord; py = ry0 - 1 - step; }
                if (px < 0 || py < 0 || px >= W || py >= H) break;
                if (cb[py * cd.Stride + px * 4 + 3] > 200) { dx = px; dy = py; break; }
            }
            if (dx < 0) continue;

            int doff = dy * cd.Stride + dx * 4;
            byte b = cb[doff], g = cb[doff + 1], r = cb[doff + 2];

            int inner = Math.Min(span, horizontal ? rx1 - rx0 : ry1 - ry0);
            for (int j = 0; j < inner; j++)
            {
                // Walk outward from the cut edge that touches the body.
                int px, py;
                if (dir == 0) { px = rx1 - 1 - j; py = fixedCoord; }
                else if (dir == 1) { px = rx0 + j; py = fixedCoord; }
                else if (dir == 2) { px = fixedCoord; py = ry1 - 1 - j; }
                else { px = fixedCoord; py = ry0 + j; }
                if (px < 0 || py < 0 || px >= W || py >= H) continue;

                // Only paint where the character actually was.
                int sx = px + ox, sy = py + oy;
                if (sx < 0 || sy < 0 || sx >= src.Width || sy >= src.Height) continue;
                if (sb[sy * sd.Stride + sx * 4 + 3] < 40) continue;

                int o = py * cd.Stride + px * 4;
                cb[o] = b; cb[o + 1] = g; cb[o + 2] = r; cb[o + 3] = 255;
            }
        }

        Marshal.Copy(cb, 0, cd.Scan0, cb.Length);
        crop.UnlockBits(cd);
        src.UnlockBits(sd);
    }
}
"@ -ReferencedAssemblies System.Drawing

if ($Project) { $projectRoot = (Resolve-Path $Project).Path }
else { $projectRoot = (Get-Location).Path }

$specPath = if (Test-Path $Spec) { (Resolve-Path $Spec).Path } else { Join-Path $projectRoot $Spec }
if (-not (Test-Path $specPath)) { throw "spec not found: $specPath" }

# NOT $spec: variable names are case-insensitive, so that would collide with the
# [string]$Spec parameter and PowerShell would coerce the parsed object straight
# back into a string through the parameter's type constraint. Every property
# access then silently returns $null.
$def = Get-Content $specPath -Raw | ConvertFrom-Json
$srcPath = Join-Path $projectRoot $def.source
if (-not (Test-Path $srcPath)) { throw "source sprite not found: $srcPath" }

$outDir = Join-Path $projectRoot $def.out_dir
New-Item -ItemType Directory -Force $outDir | Out-Null

$src = [System.Drawing.Bitmap]::FromFile($srcPath)
$W = $src.Width
$H = $src.Height
Write-Host "source $($def.source)  ($W x $H)"

$manifest = [ordered]@{
    source = $def.source
    source_size = @($W, $H)
    parts = @()
}

foreach ($part in $def.parts) {
    $x0 = [int][Math]::Floor($part.rect[0] * $W)
    $y0 = [int][Math]::Floor($part.rect[1] * $H)
    $x1 = [int][Math]::Ceiling($part.rect[2] * $W)
    $y1 = [int][Math]::Ceiling($part.rect[3] * $H)
    $x0 = [Math]::Max(0, $x0); $y0 = [Math]::Max(0, $y0)
    $x1 = [Math]::Min($W, $x1); $y1 = [Math]::Min($H, $y1)
    $pw = $x1 - $x0
    $ph = $y1 - $y0
    if ($pw -le 0 -or $ph -le 0) { throw "part '$($part.name)' has an empty rect" }

    $rect = New-Object System.Drawing.Rectangle($x0, $y0, $pw, $ph)
    $crop = $src.Clone($rect, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

    # A box cannot exclude a region, and a torso box wide enough to hold the
    # chest inevitably also holds the arms, the head and the thighs. Left in,
    # those baked-in copies never move -- so a rotating arm slides out from
    # behind a second arm still standing at its rest pose. `erase` cuts them
    # out. SourceCopy is required: the default blends, and blending transparent
    # over opaque changes nothing.
    if ($part.PSObject.Properties['erase']) {
        $g = [System.Drawing.Graphics]::FromImage($crop)
        $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $clear = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
        $rects = @()
        foreach ($e in $part.erase) {
            $ex = [int][Math]::Round($e[0] * $W - $x0)
            $ey = [int][Math]::Round($e[1] * $H - $y0)
            $ex1 = [int][Math]::Round($e[2] * $W - $x0)
            $ey1 = [int][Math]::Round($e[3] * $H - $y0)
            $g.FillRectangle($clear, [float]$ex, [float]$ey, [float]($ex1 - $ex), [float]($ey1 - $ey))
            # Optional 5th element is the refill direction -- which side the donor
            # pixels sit on: 0 right, 1 left, 2 below, 3 above. Omit it to leave a
            # real hole (correct for the head, which nothing ever moves off).
            $dir = if ($e.Count -ge 5) { [int]$e[4] } else { -1 }
            $rects += , @($ex, $ey, $ex1, $ey1, $dir)
        }
        $clear.Dispose()
        $g.Dispose()

        # Refill after ALL cuts, never between them: a donor sampled while a
        # later rect is still unerased would smear the very limb being removed
        # back across the torso.
        foreach ($r in $rects) {
            if ($r[4] -lt 0) { continue }
            [SmearFill]::Fill($crop, $src, $x0, $y0, $r[0], $r[1], $r[2], $r[3], $r[4], $FillSpan)
        }
    }

    $dest = Join-Path $outDir "$($part.name).png"
    $crop.Save($dest, [System.Drawing.Imaging.ImageFormat]::Png)
    $crop.Dispose()

    # Pivot is authored against the source image, because that is the only frame
    # of reference a human can actually see the joint in. Convert to part-local
    # pixels here so the rig builder never needs to know about the source.
    $pivX = $part.pivot[0] * $W - $x0
    $pivY = $part.pivot[1] * $H - $y0

    $manifest.parts += [ordered]@{
        name = $part.name
        file = "$($part.name).png"
        size = @($pw, $ph)
        # Where this part's joint sits inside its own PNG.
        pivot = @([Math]::Round($pivX, 1), [Math]::Round($pivY, 1))
        # Where that same joint sits in the assembled character, so the rig can
        # reconstruct the original pose exactly before any animation is applied.
        anchor = @([Math]::Round($part.pivot[0] * $W, 1), [Math]::Round($part.pivot[1] * $H, 1))
        parent = $part.parent
        z = $part.z
    }

    $off = if ($pivX -lt 0 -or $pivY -lt 0 -or $pivX -gt $pw -or $pivY -gt $ph) { "  <-- WARNING: pivot lies outside the part" } else { "" }
    Write-Host ("  {0,-10} {1,4}x{2,-4} pivot {3,6},{4,-6} parent {5}{6}" -f `
        $part.name, $pw, $ph, [Math]::Round($pivX), [Math]::Round($pivY), $part.parent, $off)
}

# Attachments are not cut out of the sprite -- they are separate art hung off a
# part. They pass through here only so that everything the rig builder needs
# lives in one generated file, and so `grip` gets the same source-coordinates
# treatment a pivot does.
if ($def.PSObject.Properties['attachments']) {
    $anchorOf = @{}
    foreach ($p in $manifest.parts) { $anchorOf[$p.name] = $p.anchor }

    $manifest.attachments = @()
    foreach ($att in $def.attachments) {
        if (-not $anchorOf.ContainsKey($att.parent)) {
            throw "attachment '$($att.name)' hangs off unknown part '$($att.parent)'"
        }
        $gx = $att.grip[0] * $W - $anchorOf[$att.parent][0]
        $gy = $att.grip[1] * $H - $anchorOf[$att.parent][1]

        $entry = [ordered]@{
            name = $att.name
            file = $att.file
            parent = $att.parent
            # Position in the parent part's local pixels.
            grip = @([Math]::Round($gx, 1), [Math]::Round($gy, 1))
            pivot = @($att.pivot[0], $att.pivot[1])
            rotation = $att.rotation
            scale = $att.scale
            z = $att.z
        }
        if ($att.PSObject.Properties['muzzle']) { $entry.muzzle = @($att.muzzle[0], $att.muzzle[1]) }
        $manifest.attachments += $entry

        Write-Host ("  {0,-14} -> {1,-6} grip {2,6},{3,-6} rot {4}" -f `
            $att.name, $att.parent, [Math]::Round($gx), [Math]::Round($gy), $att.rotation)
    }
}

$manifestPath = Join-Path $outDir "parts.json"
$manifest | ConvertTo-Json -Depth 6 | Set-Content $manifestPath -Encoding utf8
Write-Host "wrote $($def.out_dir)/parts.json  ($($manifest.parts.Count) parts)"

if ($DebugOverlay) {
    $ov = New-Object System.Drawing.Bitmap($W, $H, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($ov)
    $g.Clear([System.Drawing.Color]::FromArgb(255, 40, 40, 40))
    $g.DrawImage($src, 0, 0, $W, $H)
    $font = New-Object System.Drawing.Font("Consolas", 12, [System.Drawing.FontStyle]::Bold)
    $palette = @(
        [System.Drawing.Color]::Cyan, [System.Drawing.Color]::Magenta,
        [System.Drawing.Color]::Yellow, [System.Drawing.Color]::LimeGreen,
        [System.Drawing.Color]::Orange, [System.Drawing.Color]::DeepSkyBlue,
        [System.Drawing.Color]::HotPink
    )
    $i = 0
    foreach ($part in $def.parts) {
        $c = $palette[$i % $palette.Count]; $i++
        $x0 = $part.rect[0] * $W; $y0 = $part.rect[1] * $H
        $pw = ($part.rect[2] - $part.rect[0]) * $W
        $ph = ($part.rect[3] - $part.rect[1]) * $H
        $pen = New-Object System.Drawing.Pen($c, 2)
        $g.DrawRectangle($pen, $x0, $y0, $pw, $ph)
        $pen.Dispose()
        $br = New-Object System.Drawing.SolidBrush($c)
        $g.DrawString($part.name, $font, $br, ($x0 + 3), ($y0 + 2))
        # Pivot as a cross plus a ring -- a dot alone is unreadable against art.
        $px = $part.pivot[0] * $W; $py = $part.pivot[1] * $H
        $pen2 = New-Object System.Drawing.Pen($c, 2)
        $g.DrawLine($pen2, ($px - 9), $py, ($px + 9), $py)
        $g.DrawLine($pen2, $px, ($py - 9), $px, ($py + 9))
        $g.DrawEllipse($pen2, ($px - 5), ($py - 5), 10, 10)
        $pen2.Dispose(); $br.Dispose()
    }
    $g.Dispose()
    $ovPath = Join-Path $projectRoot "art\_preview\parts_debug.png"
    New-Item -ItemType Directory -Force (Split-Path $ovPath -Parent) | Out-Null
    $ov.Save($ovPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $ov.Dispose()
    Write-Host "wrote art/_preview/parts_debug.png"
}

$src.Dispose()
