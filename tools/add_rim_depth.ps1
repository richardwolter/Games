# Gives the tire's rim a recessed look by shading the hub cavity.
#
# The prototype's rim reads flat - a pale ring with a dark disc inside it. Real
# depth needs a shadow on the near wall and a light catch opposite. Rather than
# hoping the prompt produces that, it is drawn here and the diffusion pass
# renders it in style.
#
# The rim is found automatically as the largest connected patch of pale pixels,
# so this keeps working if the source art is redrawn.
#
#   .\tools\add_rim_depth.ps1 -In art_ref\tire.png -Out art_ref\tire_depth.png

param(
    [Parameter(Mandatory = $true)][string]$In,
    [Parameter(Mandatory = $true)][string]$Out,
    # The source cut is small; work at a multiple of it so the shading has room.
    [int]$Upscale = 4,
    # How far into the rim the cavity sits, as a fraction of the ring box.
    [double]$CavityScale = 0.70,
    [double]$ShadowAlpha = 115,
    [double]$LightAlpha = 42,
    # Direction the light comes from, degrees. 270 = straight down from above,
    # which is where the tread highlights sit, so the rim matches the tyre.
    [double]$LightDeg = 270,
    # Flat darkening of the whole cavity before the directional shading. Buries
    # leftover detail from the source art - the prototype has a valve stem in
    # there that otherwise survives as a pale smudge.
    [double]$CavityFlatten = 120
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$src = [System.Drawing.Bitmap]::FromFile((Resolve-Path $In))
$W = $src.Width; $H = $src.Height

# --- find the pale rim ring: largest connected component of light, low-sat px --
$pale = New-Object 'bool[]' ($W * $H)
for ($y = 0; $y -lt $H; $y++) {
    for ($x = 0; $x -lt $W; $x++) {
        $c = $src.GetPixel($x, $y)
        if ($c.A -lt 200) { continue }
        $mx = [Math]::Max($c.R, [Math]::Max($c.G, $c.B))
        $mn = [Math]::Min($c.R, [Math]::Min($c.G, $c.B))
        $v = $mx / 255.0
        $s = if ($mx -gt 0) { ($mx - $mn) / [double]$mx } else { 0 }
        if ($v -gt 0.86 -and $s -lt 0.16) { $pale[$y * $W + $x] = $true }
    }
}
$lab = New-Object 'int[]' ($W * $H)
for ($i = 0; $i -lt $lab.Length; $i++) { $lab[$i] = -1 }
$bestN = 0; $box = $null; $id = 0
for ($s0 = 0; $s0 -lt $W * $H; $s0++) {
    if (-not $pale[$s0] -or $lab[$s0] -ge 0) { continue }
    $stack = New-Object System.Collections.Stack
    $stack.Push($s0); $lab[$s0] = $id
    $cnt = 0; $mnX = $W; $mxX = -1; $mnY = $H; $mxY = -1
    while ($stack.Count -gt 0) {
        $i = $stack.Pop(); $cnt++
        $x = $i % $W; $y = [int][Math]::Floor($i / $W)
        if ($x -lt $mnX) { $mnX = $x }; if ($x -gt $mxX) { $mxX = $x }
        if ($y -lt $mnY) { $mnY = $y }; if ($y -gt $mxY) { $mxY = $y }
        for ($dy = -1; $dy -le 1; $dy++) {
            for ($dx = -1; $dx -le 1; $dx++) {
                $nx = $x + $dx; $ny = $y + $dy
                if ($nx -lt 0 -or $ny -lt 0 -or $nx -ge $W -or $ny -ge $H) { continue }
                $j = $ny * $W + $nx
                if ($pale[$j] -and $lab[$j] -lt 0) { $lab[$j] = $id; $stack.Push($j) }
            }
        }
    }
    if ($cnt -gt $bestN) { $bestN = $cnt; $box = @($mnX, $mnY, $mxX, $mxY) }
    $id++
}
if (-not $box) { throw "could not find a pale rim ring in $In" }
Write-Host ("rim found: ({0},{1})-({2},{3})  {4}x{5}px" -f $box[0], $box[1], $box[2], $box[3],
    ($box[2] - $box[0] + 1), ($box[3] - $box[1] + 1))

# --- upscale, then shade the cavity -------------------------------------------
$oW = $W * $Upscale; $oH = $H * $Upscale
$dst = New-Object System.Drawing.Bitmap($oW, $oH, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($dst)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.DrawImage($src, 0, 0, $oW, $oH)

$rx0 = $box[0] * $Upscale; $ry0 = $box[1] * $Upscale
$rw = ($box[2] - $box[0] + 1) * $Upscale
$rh = ($box[3] - $box[1] + 1) * $Upscale
$mx = $rx0 + $rw / 2.0; $my = $ry0 + $rh / 2.0
$cw = $rw * $CavityScale; $ch = $rh * $CavityScale

# Clip everything to the cavity so no shading spills onto the tread.
$cav = New-Object System.Drawing.Drawing2D.GraphicsPath
$cav.AddEllipse(($mx - $cw / 2), ($my - $ch / 2), $cw, $ch)
$g.SetClip($cav)

# Flatten first, so nothing from the source shows through the shading.
$flat = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int]$CavityFlatten, 14, 16, 20))
$g.FillEllipse($flat, ($mx - $cw / 2), ($my - $ch / 2), $cw, $ch)
$flat.Dispose()

$rad = $LightDeg * [Math]::PI / 180.0
$offX = [Math]::Cos($rad) * $cw * 0.16
$offY = [Math]::Sin($rad) * $ch * 0.16

# Near wall in shadow: a dark ellipse pushed toward the light, so the crescent it
# leaves sits on the far side of the cavity.
$sh = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int]$ShadowAlpha, 0, 0, 0))
$g.FillEllipse($sh, ($mx - $cw / 2 - $offX), ($my - $ch / 2 - $offY), $cw, $ch)
$sh.Dispose()

# Light catch opposite it.
$li = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int]$LightAlpha, 235, 238, 242))
$g.FillEllipse($li, ($mx - $cw * 0.34 + $offX * 1.6), ($my - $ch * 0.30 + $offY * 1.6), ($cw * 0.62), ($ch * 0.56))
$li.Dispose()

# A dark inner lip right against the pale ring, so the rim reads as a wall with
# thickness rather than a painted circle.
$lip = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(120, 0, 0, 0), ($cw * 0.09))
$g.DrawEllipse($lip, ($mx - $cw / 2), ($my - $ch / 2), $cw, $ch)
$lip.Dispose()
$g.ResetClip()

$g.Dispose()
$outPath = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Out))
$dst.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host "wrote $Out  ${oW}x${oH}"
$dst.Dispose()
$src.Dispose()
