# Draws a tire with a ROUND silhouette but the prototype's three-quarter feel:
# chunky rounded rubber lugs in staggered rows, and a centre rim pushed off to
# one side and slightly elliptical, which suggests the viewing angle without
# breaking the circular outline.
#
# The outline has to stay circular because tire.tres uses a CIRCLE collider and
# the piece rotates constantly - a non-round silhouette visibly detaches from
# its collider the moment it spins.
#
#   .\tools\make_tire_ref.ps1 -Out art_ref\tire_flat.png -Size 768

param(
    [Parameter(Mandatory = $true)][string]$Out,
    [int]$Size = 768,
    [string]$Rubber = "40,48,57",
    [string]$Lug = "58,68,79",
    [string]$Rim = "224,227,223",
    [string]$Hub = "72,78,86",
    [string]$Outline = "12,12,16",
    [double]$RingFrac = 0.035,

    # Two staggered rows of lugs, as fractions of the tyre radius.
    [double]$LugRowOuter = 0.84,
    [double]$LugRowInner = 0.63,
    [int]$LugsPerRow = 11,
    [double]$LugW = 0.20,
    [double]$LugH = 0.17,

    # Rim, pushed off centre to imply the three-quarter angle.
    [double]$RimOffsetX = 0.20,
    [double]$RimW = 0.40,
    [double]$RimH = 0.46,
    [double]$HubScale = 0.58,

    [int]$WearSeed = 5,
    [int]$Blotches = 20,
    [int]$Scuffs = 10,
    [double]$HighlightAlpha = 18
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

function ToColor([string]$s) {
    $p = $s -split ','
    return [System.Drawing.Color]::FromArgb(255, [int]$p[0], [int]$p[1], [int]$p[2])
}
function RoundedRect([double]$w, [double]$h, [double]$r) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $x = -$w / 2; $y = -$h / 2
    $path.AddArc([single]$x, [single]$y, [single]$d, [single]$d, 180, 90)
    $path.AddArc([single]($x + $w - $d), [single]$y, [single]$d, [single]$d, 270, 90)
    $path.AddArc([single]($x + $w - $d), [single]($y + $h - $d), [single]$d, [single]$d, 0, 90)
    $path.AddArc([single]$x, [single]($y + $h - $d), [single]$d, [single]$d, 90, 90)
    $path.CloseFigure()
    return $path
}

$cRub = ToColor $Rubber
$cLug = ToColor $Lug
$cRim = ToColor $Rim
$cHub = ToColor $Hub
$cLine = ToColor $Outline

$bmp = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

$ring = [Math]::Max(4, [int]($Size * $RingFrac))
$inset = $ring / 2.0
$cx = $Size / 2.0; $cy = $Size / 2.0
$R = ($Size - $ring) / 2.0

# Rubber body.
$g.FillEllipse((New-Object System.Drawing.SolidBrush($cRub)), $inset, $inset, ($Size - $ring), ($Size - $ring))

$clip = New-Object System.Drawing.Drawing2D.GraphicsPath
$clip.AddEllipse($inset, $inset, ($Size - $ring), ($Size - $ring))
$g.SetClip($clip)

# Lugs: rounded blocks laid around two rows, the inner row offset by half a step
# so the tread reads as a staggered pattern rather than radial spokes.
$lugBrush = New-Object System.Drawing.SolidBrush($cLug)
$lugPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(190, 0, 0, 0), ([Math]::Max(2, $Size * 0.006)))
$rows = @(
    @{ r = $R * $LugRowOuter; off = 0.0;  scale = 1.0 },
    @{ r = $R * $LugRowInner; off = 0.5;  scale = 0.86 }
)
foreach ($row in $rows) {
    $step = 360.0 / $LugsPerRow
    for ($i = 0; $i -lt $LugsPerRow; $i++) {
        $deg = $i * $step + $row.off * $step
        $rad = $deg * [Math]::PI / 180.0
        $lx = $cx + [Math]::Cos($rad) * $row.r
        $ly = $cy + [Math]::Sin($rad) * $row.r
        $w = $Size * $LugW * $row.scale
        $h = $Size * $LugH * $row.scale

        $state = $g.Save()
        $g.TranslateTransform([single]$lx, [single]$ly)
        $g.RotateTransform([single]($deg + 90))
        $rp = RoundedRect $w $h ([Math]::Min($w, $h) * 0.34)
        $g.FillPath($lugBrush, $rp)
        $g.DrawPath($lugPen, $rp)
        $rp.Dispose()
        $g.Restore($state)
    }
}
$lugBrush.Dispose(); $lugPen.Dispose()

# Wear: dried mud and light scuffing.
$rand = New-Object System.Random($WearSeed)
for ($i = 0; $i -lt $Blotches; $i++) {
    $ang = $rand.NextDouble() * [Math]::PI * 2
    $dist = [Math]::Sqrt($rand.NextDouble()) * $R * 0.94
    $bx = $cx + [Math]::Cos($ang) * $dist
    $by = $cy + [Math]::Sin($ang) * $dist
    $bw = $Size * (0.03 + $rand.NextDouble() * 0.08)
    $bh = $bw * (0.5 + $rand.NextDouble())
    $mud = $rand.NextDouble() -lt 0.62
    $alpha = 20 + $rand.Next(26)
    $col = if ($mud) { [System.Drawing.Color]::FromArgb($alpha, 150, 122, 78) }
           else { [System.Drawing.Color]::FromArgb($alpha, 210, 214, 220) }
    $br2 = New-Object System.Drawing.SolidBrush($col)
    $g.FillEllipse($br2, ($bx - $bw / 2), ($by - $bh / 2), $bw, $bh)
    $br2.Dispose()
}
for ($i = 0; $i -lt $Scuffs; $i++) {
    $r2 = $R * (0.35 + $rand.NextDouble() * 0.6)
    $sp = New-Object System.Drawing.Pen(
        [System.Drawing.Color]::FromArgb((22 + $rand.Next(28)), 220, 224, 230),
        ([Math]::Max(2, $Size * 0.005)))
    $g.DrawArc($sp, ($cx - $r2), ($cy - $r2), ($r2 * 2), ($r2 * 2), $rand.Next(360), (10 + $rand.Next(40)))
    $sp.Dispose()
}

# Faint highlight across the upper rubber.
$hi = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb([int]$HighlightAlpha, 255, 255, 255))
$g.FillEllipse($hi, ($cx - $R * 0.72), ($cy - $R * 0.98), ($R * 1.44), ($R * 0.80))
$hi.Dispose()
$g.ResetClip()

# Outer outline.
$pen = New-Object System.Drawing.Pen($cLine, $ring)
$g.DrawEllipse($pen, $inset, $inset, ($Size - $ring), ($Size - $ring))
$pen.Dispose()

# Rim: an ellipse pushed off centre. Taller than wide and offset sideways, which
# is what sells the three-quarter angle while the silhouette stays circular.
$rx = $cx + $R * $RimOffsetX
$rw = $R * $RimW; $rh = $R * $RimH
$g.FillEllipse((New-Object System.Drawing.SolidBrush($cRim)), ($rx - $rw), ($cy - $rh), ($rw * 2), ($rh * 2))
$rimPen = New-Object System.Drawing.Pen($cLine, ($ring * 0.9))
$g.DrawEllipse($rimPen, ($rx - $rw), ($cy - $rh), ($rw * 2), ($rh * 2))
$rimPen.Dispose()

# Hub inside the rim, mid-dark so it never reads as a hole.
$hw = $rw * $HubScale; $hh = $rh * $HubScale
$g.FillEllipse((New-Object System.Drawing.SolidBrush($cHub)), ($rx - $hw), ($cy - $hh), ($hw * 2), ($hh * 2))
$hubPen = New-Object System.Drawing.Pen($cLine, ($ring * 0.7))
$g.DrawEllipse($hubPen, ($rx - $hw), ($cy - $hh), ($hw * 2), ($hh * 2))
$hubPen.Dispose()
$hi2 = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(55, 255, 255, 255))
$g.FillEllipse($hi2, ($rx - $hw * 0.6), ($cy - $hh * 0.72), ($hw * 0.8), ($hh * 0.6))
$hi2.Dispose()

$g.Dispose()
$outPath = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Out))
$bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host "wrote $Out  ${Size}x${Size}  lugs=$LugsPerRow x2 rim offset=$RimOffsetX"
$bmp.Dispose()
