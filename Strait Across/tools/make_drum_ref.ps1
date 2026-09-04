# Draws a clean plastic-drum reference from scratch: a flat coloured disc, a
# bold black outline, and a grey lid cap in the centre. Nothing else.
#
# Masking the prototype barrel into a circle fixed its silhouette but kept its
# STRUCTURE - wooden staves and hoop lines - and img2img faithfully redraws
# those every time. A reference with no straight lines in it is the only way to
# get a barrel with no straight lines out.
#
#   .\tools\make_drum_ref.ps1 -Out art_ref\barrel_plastic.png
#
# Colours default to the prototype palette sampled from barrel_round.png.

param(
    [Parameter(Mandatory = $true)][string]$Out,
    [int]$Size = 512,
    [string]$Body = "36,96,169",
    # Deliberately mid-dark. A LIGHT grey disc ringed in black reads to
    # LayerDiffuse as a washer, and its transparent decoder punches the centre
    # out to alpha 0 - the lid literally becomes a hole. Darker also keeps the
    # lid below the shadow-strip's value threshold, so that can't eat it either.
    [string]$Lid = "112,110,108",
    [string]$Outline = "12,12,16",
    [double]$RingFrac = 0.045,
    [double]$LidFrac = 0.26,
    # Procedural wear baked into the reference. The drum has to look aged, but
    # raising denoise far enough to invent wear also breaks the lid, so the wear
    # is drawn here and a low denoise renders it in the cartoon style. All marks
    # are ellipses and arcs - nothing introduces a straight line.
    [int]$WearSeed = 7,
    [int]$Blotches = 26,
    [int]$Scuffs = 14,
    # Toxic-hazard sticker beside the lid. Round, with a trefoil symbol built
    # from circles and arcs - so it adds no straight lines to the drum.
    [switch]$NoSticker,
    [double]$StickerFrac = 0.17,
    [double]$StickerAngleDeg = 38,
    # Far enough out that the sticker clears the lid rather than overlapping it:
    # needs to exceed (lid radius + sticker radius) as a fraction of the body.
    [double]$StickerDist = 0.60,
    [string]$StickerBg = "214,196,48",
    [double]$StickerRotDeg = -12
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

function ToColor([string]$s) {
    $p = $s -split ','
    return [System.Drawing.Color]::FromArgb(255, [int]$p[0], [int]$p[1], [int]$p[2])
}
$cBody = ToColor $Body
$cLid = ToColor $Lid
$cLine = ToColor $Outline

$bmp = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

$ring = [Math]::Max(4, [int]($Size * $RingFrac))
$inset = $ring / 2.0

# Body disc.
$g.FillEllipse((New-Object System.Drawing.SolidBrush($cBody)), $inset, $inset, ($Size - $ring), ($Size - $ring))

# A soft radial gradient so the disc reads as a curved plastic surface rather
# than a flat sticker. Concentric, so it adds no straight edges.
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$path.AddEllipse($inset, $inset, ($Size - $ring), ($Size - $ring))
$grad = New-Object System.Drawing.Drawing2D.PathGradientBrush($path)
$grad.CenterPoint = New-Object System.Drawing.PointF(($Size * 0.40), ($Size * 0.36))
$grad.CenterColor = [System.Drawing.Color]::FromArgb(90, 255, 255, 255)
$grad.SurroundColors = @([System.Drawing.Color]::FromArgb(70, 0, 0, 40))
$g.FillPath($grad, $path)
$grad.Dispose()

# Weathering, clipped to the body so nothing spills past the silhouette.
$g.SetClip($path)
$rand = New-Object System.Random($WearSeed)
$cx = $Size / 2.0; $cy = $Size / 2.0; $rad = ($Size - $ring) / 2.0
for ($i = 0; $i -lt $Blotches; $i++) {
    # Uniform over the disc: sqrt keeps them from clustering in the middle.
    $ang = $rand.NextDouble() * [Math]::PI * 2
    $dist = [Math]::Sqrt($rand.NextDouble()) * $rad * 0.92
    $bx = $cx + [Math]::Cos($ang) * $dist
    $by = $cy + [Math]::Sin($ang) * $dist
    $bw = $Size * (0.03 + $rand.NextDouble() * 0.09)
    $bh = $bw * (0.5 + $rand.NextDouble())
    $dark = $rand.NextDouble() -lt 0.72
    $alpha = 22 + $rand.Next(30)
    $col = if ($dark) { [System.Drawing.Color]::FromArgb($alpha, 20, 26, 40) }
           else { [System.Drawing.Color]::FromArgb($alpha, 220, 225, 235) }
    $br2 = New-Object System.Drawing.SolidBrush($col)
    $g.FillEllipse($br2, ($bx - $bw / 2), ($by - $bh / 2), $bw, $bh)
    $br2.Dispose()
}
# Scuff arcs - curved, following the drum's curvature.
for ($i = 0; $i -lt $Scuffs; $i++) {
    $r2 = $rad * (0.25 + $rand.NextDouble() * 0.7)
    $start = $rand.Next(360)
    $sweep = 12 + $rand.Next(48)
    $alpha = 26 + $rand.Next(34)
    $light = $rand.NextDouble() -lt 0.45
    $col = if ($light) { [System.Drawing.Color]::FromArgb($alpha, 235, 240, 248) }
           else { [System.Drawing.Color]::FromArgb($alpha, 16, 20, 34) }
    $sp = New-Object System.Drawing.Pen($col, ([Math]::Max(2, $Size * 0.006)))
    $g.DrawArc($sp, ($cx - $r2), ($cy - $r2), ($r2 * 2), ($r2 * 2), $start, $sweep)
    $sp.Dispose()
}
$g.ResetClip()

# Outline.
$pen = New-Object System.Drawing.Pen($cLine, $ring)
$g.DrawEllipse($pen, $inset, $inset, ($Size - $ring), ($Size - $ring))

# Grey lid cap, centred.
$lidD = $Size * $LidFrac
$lidX = ($Size - $lidD) / 2.0
$g.FillEllipse((New-Object System.Drawing.SolidBrush($cLid)), $lidX, $lidX, $lidD, $lidD)
$lidPen = New-Object System.Drawing.Pen($cLine, ([Math]::Max(3, $ring * 0.6)))
$g.DrawEllipse($lidPen, $lidX, $lidX, $lidD, $lidD)
$lidPen.Dispose()

# A highlight crescent inside the lid, so it reads as a solid raised cap catching
# light rather than an empty opening.
$hi = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(70, 255, 255, 255))
$g.FillEllipse($hi, ($lidX + $lidD * 0.16), ($lidX + $lidD * 0.13), ($lidD * 0.5), ($lidD * 0.38))
$hi.Dispose()

# Toxic-hazard sticker, sitting beside the lid.
if (-not $NoSticker) {
    $cxs = $Size / 2.0; $cys = $Size / 2.0
    $bodyR = ($Size - $ring) / 2.0
    $ang = $StickerAngleDeg * [Math]::PI / 180.0
    $sd = $Size * $StickerFrac
    $sx = $cxs + [Math]::Cos($ang) * $bodyR * $StickerDist - $sd / 2.0
    $sy = $cys + [Math]::Sin($ang) * $bodyR * $StickerDist - $sd / 2.0

    $state = $g.Save()
    # Slight rotation so it reads as stuck on by hand, not printed.
    $g.TranslateTransform([single]($sx + $sd / 2), [single]($sy + $sd / 2))
    $g.RotateTransform([single]$StickerRotDeg)
    $g.TranslateTransform([single](-($sx + $sd / 2)), [single](-($sy + $sd / 2)))

    $cSticker = ToColor $StickerBg
    $sBr = New-Object System.Drawing.SolidBrush($cSticker)
    $g.FillEllipse($sBr, $sx, $sy, $sd, $sd); $sBr.Dispose()
    $sPen = New-Object System.Drawing.Pen($cLine, ([Math]::Max(2, $sd * 0.09)))
    $g.DrawEllipse($sPen, ($sx + $sd * 0.045), ($sy + $sd * 0.045), ($sd * 0.91), ($sd * 0.91)); $sPen.Dispose()

    # Trefoil: a hub circle plus three thick arcs at 120 degrees.
    $mx = $sx + $sd / 2; $my = $sy + $sd / 2
    $hub = $sd * 0.13
    $hubBr = New-Object System.Drawing.SolidBrush($cLine)
    $g.FillEllipse($hubBr, ($mx - $hub), ($my - $hub), ($hub * 2), ($hub * 2)); $hubBr.Dispose()
    $ringR = $sd * 0.27
    $aPen = New-Object System.Drawing.Pen($cLine, ($sd * 0.15))
    for ($k = 0; $k -lt 3; $k++) {
        $start = -90 + $k * 120 - 42
        $g.DrawArc($aPen, ($mx - $ringR), ($my - $ringR), ($ringR * 2), ($ringR * 2), $start, 84)
    }
    $aPen.Dispose()
    $g.Restore($state)
}
$pen.Dispose()
$g.Dispose()

$outPath = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Out))
$bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host "wrote $Out  ${Size}x${Size}  body=$Body lid=$Lid ring=${ring}px"
$bmp.Dispose()
