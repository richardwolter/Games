# Clears the cab glass out of art/car_body.png so the driver can be seen through
# the opening.
#
# WHY THIS EXISTS. The driver is two sprites drawn as siblings of the truck body.
# Drawn in front, he sits on top of the door and pillars and reads as a sticker
# on the outside of the truck. Drawn behind, he is correctly occluded - but the
# generated glass is opaque, so he vanishes entirely. Punching the glass out is
# what makes "behind" the right answer: the roof, A-pillar, door and cage still
# cover him at the edges, and the window is genuinely a hole he shows through.
#
# The rectangle is hand-measured against the generated sprite rather than found
# by colour. The glass sits at roughly RGB(80,96,96), but so do several shadowed
# steel areas of the roll cage and chassis, and every tolerance wide enough to
# catch all the glass also ate parts of those.
#
# This is a POST-PROCESS: generate_art.ps1 -Name car_body overwrites the file and
# undoes it. Re-run this afterwards, and re-measure the rectangle if the seed or
# the reference changes, since both move the cab.
#
#   .\tools\punch_cab_window.ps1
#   .\tools\punch_cab_window.ps1 -WhatIf      # report only, write nothing

param(
    [string]$Target = "art\car_body.png",
    # The window opening, in sprite pixels. Measured off the 715x339 sprite.
    [int]$Left = 316,
    [int]$Top = 34,
    [int]$Right = 447,
    [int]$Bottom = 132,
    # Corner rounding, so the hole follows the drawn window rather than being an
    # obvious rectangle where it meets the pillars.
    [int]$Radius = 14,
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = Split-Path $PSScriptRoot -Parent
$path = Join-Path $root $Target
if (-not (Test-Path $path)) { throw "no such file: $path" }

$src = [System.Drawing.Bitmap]::FromFile($path)
$bmp = New-Object System.Drawing.Bitmap($src)
$src.Dispose()

$cleared = 0
$already = 0
for ($x = $Left; $x -le $Right; $x++) {
    for ($y = $Top; $y -le $Bottom; $y++) {
        if ($x -lt 0 -or $y -lt 0 -or $x -ge $bmp.Width -or $y -ge $bmp.Height) { continue }
        # Round the corners by skipping anything outside the inset ellipse arcs.
        $dx = 0; $dy = 0
        if ($x -lt $Left + $Radius) { $dx = $Left + $Radius - $x }
        elseif ($x -gt $Right - $Radius) { $dx = $x - ($Right - $Radius) }
        if ($y -lt $Top + $Radius) { $dy = $Top + $Radius - $y }
        elseif ($y -gt $Bottom - $Radius) { $dy = $y - ($Bottom - $Radius) }
        if ($dx * $dx + $dy * $dy -gt $Radius * $Radius) { continue }

        if ($bmp.GetPixel($x, $y).A -eq 0) { $already++; continue }
        $cleared++
        if (-not $WhatIf) {
            $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, 0, 0, 0))
        }
    }
}

"window x $Left..$Right  y $Top..$Bottom  radius $Radius"
"  {0} px cleared, {1} px already transparent" -f $cleared, $already
if ($WhatIf) {
    "  -WhatIf: nothing written"
}
else {
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    "  wrote $Target"
}
$bmp.Dispose()
