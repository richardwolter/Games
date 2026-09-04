# Draws the img2img references for the driver: a seated figure in side view,
# split into a headless body and a separate head.
#
# TWO SPRITES, not one, because the head has to bobble. driver.gd draws the head
# as its own node with its own spring, so it can lag and rebound against the
# chassis; baked into the body it could only ever move with it.
#
# Both are drawn facing RIGHT, matching the truck. The pose is a driving pose:
# torso upright and leaning back slightly, upper arms down and forearms forward
# to the wheel, thighs forward, knees bent, shins down to the pedals.
#
#   .\tools\make_driver_ref.ps1

param(
    [string]$BodyOut = "art_ref\driver_body.png",
    [string]$HeadOut = "art_ref\driver_head.png",

    [int]$BodyW = 384,
    [int]$BodyH = 384,
    [int]$HeadSize = 256,

    # House palette. The reference photo is a grey jacket and jeans; this keeps
    # the value structure but pulls it toward the game's warm salvage colours so
    # the driver doesn't read as a different art set from the truck he's in.
    [string]$Jacket = "142,86,44",
    [string]$JacketDark = "108,63,30",
    [string]$Trouser = "78,84,94",
    [string]$TrouserDark = "58,63,72",
    [string]$Boot = "44,42,44",
    [string]$Skin = "226,178,140",
    [string]$SkinDark = "196,146,110",
    [string]$Hair = "92,58,34",
    [string]$Outline = "22,22,26"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = Split-Path $PSScriptRoot -Parent

function C([string]$triplet, [int]$alpha = 255) {
    $p = $triplet -split ","
    [System.Drawing.Color]::FromArgb($alpha, [int]$p[0], [int]$p[1], [int]$p[2])
}

function New-Canvas([int]$w, [int]$h) {
    $b = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($b)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    return @($b, $g)
}

function Save-Canvas($bitmap, [string]$relPath) {
    $full = Join-Path $root $relPath
    $dir = Split-Path $full -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    $bitmap.Save($full, [System.Drawing.Imaging.ImageFormat]::Png)
    "$relPath  $($bitmap.Width)x$($bitmap.Height)"
}

# Limbs are drawn as fat round-capped strokes with a wider ink stroke beneath,
# which is how the rest of the sprite set gets its single uniform outline.
function Limb($g, [double]$x1, [double]$y1, [double]$x2, [double]$y2, [double]$w, $fill, [string]$ink) {
    $edge = New-Object System.Drawing.Pen((C $ink), ($w + 9))
    $edge.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $edge.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $core = New-Object System.Drawing.Pen($fill, $w)
    $core.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $core.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $g.DrawLine($edge, $x1, $y1, $x2, $y2)
    $g.DrawLine($core, $x1, $y1, $x2, $y2)
}

# --- body ------------------------------------------------------------------
# Drawn far-side limbs first in the darker shade, then the torso, then near-side
# limbs in the lighter one. That back-to-front order is the whole trick for a
# side-view figure: without it the arm and torso are the same brown blob and the
# pose stops reading.
#
# The neck stub at the top is deliberate: the head sprite overlaps it, so there
# is no gap at the join however far the bobble swings.
function New-DriverBody {
    $c = New-Canvas $BodyW $BodyH
    $bmp = $c[0]; $g = $c[1]

    $brJacket = New-Object System.Drawing.SolidBrush (C $Jacket)
    $brJacketDark = New-Object System.Drawing.SolidBrush (C $JacketDark)
    $brTrouser = New-Object System.Drawing.SolidBrush (C $Trouser)
    $brTrouserDark = New-Object System.Drawing.SolidBrush (C $TrouserDark)
    $brSkin = New-Object System.Drawing.SolidBrush (C $Skin)
    $pen = New-Object System.Drawing.Pen((C $Outline), 8)
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $thin = New-Object System.Drawing.Pen((C $Outline), 5)

    # Seated skeleton in canvas coordinates, figure facing right. Hip is the
    # anchor: thigh runs forward and slightly up, shin drops to the pedals,
    # torso rises with a slight backward lean.
    $hipX = 140.0; $hipY = 250.0
    $shoulderX = 154.0; $shoulderY = 142.0
    $kneeX = 252.0; $kneeY = 244.0
    $ankleX = 240.0; $ankleY = 326.0
    $elbowX = 186.0; $elbowY = 196.0
    $handX = 254.0; $handY = 180.0

    # Far leg and far arm, shifted back and darkened.
    Limb $g ($hipX - 8) $hipY ($kneeX - 14) ($kneeY + 6) 38 $brTrouserDark $Outline
    Limb $g ($kneeX - 14) ($kneeY + 6) ($ankleX - 16) $ankleY 30 $brTrouserDark $Outline
    Limb $g ($shoulderX - 10) $shoulderY ($elbowX - 12) ($elbowY + 6) 30 $brJacketDark $Outline
    Limb $g ($elbowX - 12) ($elbowY + 6) ($handX - 16) ($handY + 10) 26 $brJacketDark $Outline

    # Near leg.
    Limb $g $hipX $hipY $kneeX $kneeY 42 $brTrouser $Outline
    Limb $g $kneeX $kneeY $ankleX $ankleY 34 $brTrouser $Outline
    # Boot: a wedge on the end of the shin, pointing forward to the pedals.
    $bootPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $bootPath.AddPolygon(@(
            (New-Object System.Drawing.PointF(($ankleX - 20), ($ankleY - 14))),
            (New-Object System.Drawing.PointF(($ankleX + 18), ($ankleY - 18))),
            (New-Object System.Drawing.PointF(($ankleX + 48), ($ankleY + 12))),
            (New-Object System.Drawing.PointF(($ankleX + 42), ($ankleY + 30))),
            (New-Object System.Drawing.PointF(($ankleX - 22), ($ankleY + 30)))
        ))
    $g.FillPath((New-Object System.Drawing.SolidBrush (C $Boot)), $bootPath)
    $g.DrawPath($pen, $bootPath)

    # Torso, over the leg roots. One thick limb so the outline stays uniform.
    Limb $g $hipX $hipY $shoulderX $shoulderY 58 $brJacket $Outline
    # Jacket hem across the hip, and a zip line up the front.
    $g.DrawLine($thin, ($hipX - 26), ($hipY - 6), ($hipX + 28), ($hipY - 14))
    $g.DrawLine($thin, ($hipX + 24), ($hipY - 12), ($shoulderX + 22), ($shoulderY + 14))

    # Near arm, reaching to the wheel.
    Limb $g $shoulderX $shoulderY $elbowX $elbowY 32 $brJacket $Outline
    Limb $g $elbowX $elbowY $handX $handY 28 $brJacket $Outline
    $g.DrawLine($thin, ($handX - 26), ($handY + 12), ($handX - 20), ($handY - 12))
    $g.FillEllipse($brSkin, ($handX - 16), ($handY - 17), 32, 32)
    $g.DrawEllipse($pen, ($handX - 16), ($handY - 17), 32, 32)

    # Neck stub. Overlapped by the head sprite in game.
    Limb $g $shoulderX ($shoulderY - 2) ($shoulderX + 8) ($shoulderY - 32) 26 $brSkin $Outline

    $g.Dispose()
    $out = Save-Canvas $bmp $BodyOut
    $bmp.Dispose()
    $out
    "  neck top at ({0:N0},{1:N0}) - where the head sprite sits" -f ($shoulderX + 8), ($shoulderY - 32)
}

# --- head ------------------------------------------------------------------
# Facing right. Built as two overlapping ellipses - a hair-coloured one set high
# and a skin one set low - so the crop between them is the hairline. Drawing the
# hair as its own arc path, which is what the first version did, produced a
# sliver that read as a scar.
function New-DriverHead {
    $c = New-Canvas $HeadSize $HeadSize
    $bmp = $c[0]; $g = $c[1]
    $cx = $HeadSize / 2.0
    $cy = $HeadSize / 2.0

    $brSkin = New-Object System.Drawing.SolidBrush (C $Skin)
    $brSkinDark = New-Object System.Drawing.SolidBrush (C $SkinDark)
    $brHair = New-Object System.Drawing.SolidBrush (C $Hair)
    $pen = New-Object System.Drawing.Pen((C $Outline), 8)
    $thin = New-Object System.Drawing.Pen((C $Outline), 5)

    $r = 70.0
    # Hair mass: the whole skull, set high and back.
    $g.FillEllipse($brHair, ($cx - $r - 4), ($cy - $r - 12), ($r * 2), ($r * 2))
    $g.DrawEllipse($pen, ($cx - $r - 4), ($cy - $r - 12), ($r * 2), ($r * 2))

    # Face: a slightly smaller ellipse set low and forward, which crops the hair
    # down to a cap and leaves the hairline where the two edges cross.
    $fr = $r * 0.92
    $g.FillEllipse($brSkin, ($cx - $fr + 10), ($cy - $fr + 6), ($fr * 2), ($fr * 2))
    $g.DrawEllipse($pen, ($cx - $fr + 10), ($cy - $fr + 6), ($fr * 2), ($fr * 2))

    # Nose: a small wedge off the front edge, at eye level. It is the only thing
    # that says which way the driver is facing, so it is drawn proud of the face.
    $nose = New-Object System.Drawing.Drawing2D.GraphicsPath
    $nose.AddPolygon(@(
            (New-Object System.Drawing.PointF(($cx + $fr - 4), ($cy - 4))),
            (New-Object System.Drawing.PointF(($cx + $fr + 20), ($cy + 12))),
            (New-Object System.Drawing.PointF(($cx + $fr - 6), ($cy + 22)))
        ))
    $g.FillPath($brSkin, $nose)
    $g.DrawPath($pen, $nose)

    # Ear, eye, brow.
    $g.FillEllipse($brSkinDark, ($cx - 24), ($cy + 2), 20, 26)
    $g.DrawEllipse($thin, ($cx - 24), ($cy + 2), 20, 26)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush (C $Outline)), ($cx + 26), ($cy - 6), 11, 14)
    $g.DrawLine($thin, ($cx + 16), ($cy - 22), ($cx + 44), ($cy - 16))

    $g.Dispose()
    $out = Save-Canvas $bmp $HeadOut
    $bmp.Dispose()
    $out
    "  neck pivot is at ({0:N0},{1:N0}) in this canvas" -f $cx, ($cy + $r - 4)
}

New-DriverBody
New-DriverHead
