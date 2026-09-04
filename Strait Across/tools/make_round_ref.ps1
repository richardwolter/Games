# Builds a round reference sprite from a squarish one.
#
# img2img follows the reference's silhouette, so a barrel drawn as a rounded
# square keeps producing corners no matter what the prompt says. This masks the
# artwork to a circle and lays a thick black ring over the cut edge, giving the
# model a round silhouette that already matches the house outline weight.
#
#   .\tools\make_round_ref.ps1 -In art_ref\barrel_1.png -Out art_ref\barrel_round.png

param(
    [Parameter(Mandatory = $true)][string]$In,
    [Parameter(Mandatory = $true)][string]$Out,
    # Outline thickness as a fraction of the diameter.
    [double]$RingFrac = 0.035
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$src = [System.Drawing.Bitmap]::FromFile((Resolve-Path $In))

# Trim to the visible artwork first, so the circle is centred on the drawing
# rather than on whatever padding the sheet happened to leave.
$minX = $src.Width; $minY = $src.Height; $maxX = -1; $maxY = -1
for ($y = 0; $y -lt $src.Height; $y++) {
    for ($x = 0; $x -lt $src.Width; $x++) {
        if ($src.GetPixel($x, $y).A -gt 40) {
            if ($x -lt $minX) { $minX = $x }; if ($x -gt $maxX) { $maxX = $x }
            if ($y -lt $minY) { $minY = $y }; if ($y -gt $maxY) { $maxY = $y }
        }
    }
}
$cw = $maxX - $minX + 1; $ch = $maxY - $minY + 1
$size = [Math]::Max($cw, $ch)

$dst = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($dst)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

# Clip to a circle, then draw the artwork stretched to fill that circle's box.
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$path.AddEllipse(0, 0, $size, $size)
$g.SetClip($path)
$g.DrawImage($src, (New-Object System.Drawing.Rectangle(0, 0, $size, $size)),
    $minX, $minY, $cw, $ch, [System.Drawing.GraphicsUnit]::Pixel)
$g.ResetClip()

# Black ring over the cut edge, so the silhouette reads as a drawn outline
# rather than a crop.
$ring = [Math]::Max(3, [int]($size * $RingFrac))
$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 12, 12, 16)), $ring
$inset = $ring / 2.0
$g.DrawEllipse($pen, $inset, $inset, ($size - $ring), ($size - $ring))
$pen.Dispose()
$g.Dispose()

$outPath = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Out))
$dst.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host "wrote $Out  ${size}x${size}  (from ${cw}x${ch}, ring ${ring}px)"
$dst.Dispose()
$src.Dispose()
