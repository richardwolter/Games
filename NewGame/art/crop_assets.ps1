Add-Type -AssemblyName System.Drawing

$src = "C:\Users\Administrador\Documents\Games\NewGame\Image_Assets.png"
$outDir = "C:\Users\Administrador\Documents\Games\NewGame\art\generated"
$full = [System.Drawing.Bitmap]::FromFile($src)

function ColorDist($c1, $c2) {
    $dr = [double]$c1.R - [double]$c2.R
    $dg = [double]$c1.G - [double]$c2.G
    $db = [double]$c1.B - [double]$c2.B
    return [Math]::Sqrt($dr*$dr + $dg*$dg + $db*$db)
}

function Trim-And-Save {
    param(
        [System.Drawing.Bitmap]$Source,
        [int]$X, [int]$Y, [int]$W, [int]$H,
        [string]$OutName,
        [int]$Padding = 4,
        [double]$Threshold = 22.0
    )

    $X = [Math]::Max(0, $X); $Y = [Math]::Max(0, $Y)
    $W = [Math]::Min($W, $Source.Width - $X); $H = [Math]::Min($H, $Source.Height - $Y)
    $rect = New-Object System.Drawing.Rectangle($X, $Y, $W, $H)
    $rough = $Source.Clone($rect, $Source.PixelFormat)

    # Sample background reference from the 4 corners (average), since corners
    # of each rough region should be empty background.
    $corners = @($rough.GetPixel(0,0), $rough.GetPixel($W-1,0), $rough.GetPixel(0,$H-1), $rough.GetPixel($W-1,$H-1))
    $bgR = ($corners | ForEach-Object { $_.R } | Measure-Object -Average).Average
    $bgG = ($corners | ForEach-Object { $_.G } | Measure-Object -Average).Average
    $bgB = ($corners | ForEach-Object { $_.B } | Measure-Object -Average).Average
    $bg = [System.Drawing.Color]::FromArgb(255, [int]$bgR, [int]$bgG, [int]$bgB)

    $minX = $W; $minY = $H; $maxX = 0; $maxY = 0
    $found = $false
    for ($py = 0; $py -lt $H; $py++) {
        for ($px = 0; $px -lt $W; $px++) {
            $c = $rough.GetPixel($px, $py)
            if ((ColorDist $c $bg) -gt $Threshold) {
                $found = $true
                if ($px -lt $minX) { $minX = $px }
                if ($py -lt $minY) { $minY = $py }
                if ($px -gt $maxX) { $maxX = $px }
                if ($py -gt $maxY) { $maxY = $py }
            }
        }
    }

    if (-not $found) {
        Write-Host "No foreground pixels found for $OutName (bg=$($bg.R),$($bg.G),$($bg.B))"
        return
    }

    $minX = [Math]::Max(0, $minX - $Padding)
    $minY = [Math]::Max(0, $minY - $Padding)
    $maxX = [Math]::Min($W - 1, $maxX + $Padding)
    $maxY = [Math]::Min($H - 1, $maxY + $Padding)

    $cw = $maxX - $minX + 1
    $ch = $maxY - $minY + 1
    $final = New-Object System.Drawing.Bitmap($cw, $ch, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

    for ($py = 0; $py -lt $ch; $py++) {
        for ($px = 0; $px -lt $cw; $px++) {
            $c = $rough.GetPixel($minX + $px, $minY + $py)
            $d = ColorDist $c $bg
            if ($d -le $Threshold) {
                $final.SetPixel($px, $py, [System.Drawing.Color]::FromArgb(0, $c.R, $c.G, $c.B))
            } else {
                # Soft edge feather just above threshold
                $alpha = [Math]::Min(255, [int](($d - $Threshold) * 12))
                $final.SetPixel($px, $py, [System.Drawing.Color]::FromArgb($alpha, $c.R, $c.G, $c.B))
            }
        }
    }

    $outPath = Join-Path $outDir $OutName
    $final.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host "Saved $OutName -> ${cw}x${ch} (bg was $($bg.R),$($bg.G),$($bg.B))"

    $final.Dispose()
    $rough.Dispose()
}

Trim-And-Save -Source $full -X 620  -Y 260 -W 100 -H 272 -OutName "dead_tree.png"

$full.Dispose()
Write-Host "Done."
