Add-Type -AssemblyName System.Drawing

$src = "C:\Users\Administrador\Documents\Games\NewGame\Car_Asset.png"
$outPath = "C:\Users\Administrador\Documents\Games\NewGame\art\generated\car_hero_iso_rear.png"
$img = [System.Drawing.Bitmap]::FromFile($src)
$W = $img.Width
$H = $img.Height

# Corners are near-black vignette; find bounding box of pixels brighter than a threshold.
$corner = $img.GetPixel(2,2)
$threshold = 28.0

$minX = $W; $minY = $H; $maxX = 0; $maxY = 0
$found = $false
for ($y = 0; $y -lt $H; $y += 2) {
    for ($x = 0; $x -lt $W; $x += 2) {
        $c = $img.GetPixel($x, $y)
        $dr = [double]$c.R - [double]$corner.R
        $dg = [double]$c.G - [double]$corner.G
        $db = [double]$c.B - [double]$corner.B
        $d = [Math]::Sqrt($dr*$dr + $dg*$dg + $db*$db)
        if ($d -gt $threshold) {
            $found = $true
            if ($x -lt $minX) { $minX = $x }
            if ($y -lt $minY) { $minY = $y }
            if ($x -gt $maxX) { $maxX = $x }
            if ($y -gt $maxY) { $maxY = $y }
        }
    }
}

if (-not $found) {
    Write-Host "No foreground found."
} else {
    $pad = 20
    $minX = [Math]::Max(0, $minX - $pad)
    $minY = [Math]::Max(0, $minY - $pad)
    $maxX = [Math]::Min($W - 1, $maxX + $pad)
    $maxY = [Math]::Min($H - 1, $maxY + $pad)
    $rect = New-Object System.Drawing.Rectangle($minX, $minY, ($maxX - $minX + 1), ($maxY - $minY + 1))
    $cropped = $img.Clone($rect, $img.PixelFormat)
    $cropped.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host "Saved car_hero_iso_rear.png -> $($cropped.Width)x$($cropped.Height)"
    $cropped.Dispose()
}

$img.Dispose()
