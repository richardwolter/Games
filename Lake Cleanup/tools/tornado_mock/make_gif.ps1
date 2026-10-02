# Builds the gif, the mp4 and the contact sheet for one look's frames.
#   powershell -ExecutionPolicy Bypass -File tools/tornado_mock/make_gif.ps1 a
#   powershell -ExecutionPolicy Bypass -File tools/tornado_mock/make_gif.ps1 a wide
# Reads out_<look>/f_%04d.png (or out_<look>/wide/f_%04d.png), 30 fps.
param(
    [Parameter(Mandatory = $true)][string]$Look,
    [string]$Mode = ""
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$dir = Join-Path $root "out_$Look"
$name = "tornado_$Look"
if ($Mode -eq "wide") {
    $dir = Join-Path $dir "wide"
    $name = "tornado_${Look}_wide"
}
$frames = Join-Path $dir "f_%04d.png"
$count = (Get-ChildItem -Path $dir -Filter "f_*.png").Count
if ($count -eq 0) { throw "no frames in $dir" }

$gif = Join-Path $dir "$name.gif"
$mp4 = Join-Path $dir "$name.mp4"
$sheet = Join-Path $dir "sheet_$Look$(if ($Mode -eq 'wide') { '_wide' }).png"
$pal = Join-Path $dir "palette.png"

# Nearest scaling keeps the art pixels square; 600 px wide for the gif.
ffmpeg -y -loglevel error -framerate 30 -i $frames -vf "scale=600:-1:flags=neighbor,palettegen=stats_mode=diff" $pal
ffmpeg -y -loglevel error -framerate 30 -i $frames -i $pal -lavfi "scale=600:-1:flags=neighbor [x]; [x][1:v] paletteuse=dither=none" $gif
Remove-Item $pal
ffmpeg -y -loglevel error -framerate 30 -i $frames -c:v libx264 -pix_fmt yuv420p -crf 16 -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2" $mp4

# 4x3 contact sheet of evenly spaced frames.
$step = [math]::Max([math]::Floor($count / 12), 1)
ffmpeg -y -loglevel error -framerate 30 -i $frames -vf "select='not(mod(n\,$step))',scale=400:-1:flags=neighbor,tile=4x3" -frames:v 1 $sheet
Write-Output "frames $count -> $gif, $mp4, $sheet"
