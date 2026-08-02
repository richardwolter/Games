# Draws the img2img references for the car: a side-on monster truck body with
# EMPTY wheel arches, and a side-on monster truck tyre.
#
# The reference exists to fix anatomy, which is the whole point here. The
# diffusion pass runs at denoise 0.5 and only repaints surface detail, so
# anything the truck needs to HAVE must be drawn here - a bare ref comes back as
# a bare sprite no matter what the prompt asks for.
#
# MONSTER TRUCK PROPORTIONS. The single number that makes the format read is the
# wheelbase measured in tyre radii. A pickup is ~5.5; a monster truck is ~3.3,
# which is what this ref uses. Getting there means big tyres, not a short truck:
# the bodywork is a compact slab riding high above the axle line, with open air
# and visible suspension between it and the ground.
#
# The arches are drawn as holes, not as painted wheels: car.tscn draws the
# tyres itself so they can spin, and any wheel baked into the body sprite shows
# up as a second, stationary tyre behind the real one. The arch radius here is
# matched to the tyre so the physics wheel fills its opening.
#
#   .\tools\make_truck_ref.ps1

param(
    [string]$BodyOut = "art_ref\truck_body.png",
    [string]$TyreOut = "art_ref\truck_tyre.png",

    # Body canvas. 700 units of truck inside a 768x448 frame - taller than the
    # pickup ref was, because the cage and the blower now sit above the cab and
    # the suspension hangs below the body.
    [int]$BodyW = 768,
    [int]$BodyH = 576,
    [int]$TyreSize = 640,

    # Wheel arch centres, as a fraction of the truck's length. The gap between
    # them is the wheelbase.
    [double]$RearAxle = 0.19,
    [double]$FrontAxle = 0.81,
    # Arch radius, same units. 0.19 of 700 = 133, against a 434-unit wheelbase:
    # a ratio of 3.3, which is the monster-truck number.
    [double]$ArchRadius = 0.19,

    # Deliberately NOT the reference photo's blue-and-orange flames. This is the
    # house palette the rest of the sprite set is drawn in: mustard bodywork,
    # weathered steel structure, rust. The format is borrowed; the look is ours.
    [string]$Paint = "232,163,23",
    [string]$PaintDark = "196,128,14",
    [string]$Glass = "58,74,90",
    [string]$Chrome = "200,204,208",
    [string]$Steel = "150,158,166",
    [string]$SteelDark = "92,100,107",
    [string]$Rubber = "34,34,38",
    [string]$Tread = "52,54,60",
    [string]$Rim = "222,224,220",
    [string]$Hub = "70,74,82",
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

# --- body ------------------------------------------------------------------
# Facing right. Read bottom-up: axle line, then the tube frame and coil-overs
# that carry the body, then the compact cab-and-bed slab, then the cage, stack
# and blower on top. Flat fills with one heavy outline, house style.
function New-TruckBody {
    $c = New-Canvas $BodyW $BodyH
    $bmp = $c[0]; $g = $c[1]

    $len = 700.0
    $x0 = ($BodyW - $len) / 2.0
    $archR = $len * $ArchRadius
    $rearX = $x0 + $len * $RearAxle
    $frontX = $x0 + $len * $FrontAxle
    # Axle line low in the frame, with a full arch radius of canvas beneath it:
    # the punched openings are circles centred here and must not clip.
    $axleY = $BodyH - $archR - 76.0
    # Bottom of the bodywork. The gap between this and the tyre tops is the one
    # thing that makes the sprite read as a monster truck rather than a pickup.
    $rocker = $axleY - $archR * 0.72
    # Everything structural lives in the span BETWEEN the arches. Anything drawn
    # inside an arch is erased by the punch at the end of this function, which is
    # what happened to the first version's suspension.
    $innerL = $rearX + $archR
    $innerR = $frontX - $archR

    $brPaint = New-Object System.Drawing.SolidBrush (C $Paint)
    $brPaintDark = New-Object System.Drawing.SolidBrush (C $PaintDark)
    $brGlass = New-Object System.Drawing.SolidBrush (C $Glass)
    $brChrome = New-Object System.Drawing.SolidBrush (C $Chrome)
    $brSteel = New-Object System.Drawing.SolidBrush (C $Steel)
    $ink = New-Object System.Drawing.SolidBrush (C $Outline)
    $pen = New-Object System.Drawing.Pen((C $Outline), 7)
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $thin = New-Object System.Drawing.Pen((C $Outline), 4)

    # --- chassis and suspension, drawn first so the body sits over it --------
    # Outlined tube: a fat ink stroke with a thinner steel stroke on top, which
    # is how the rest of the sprite set gets its uniform black outline.
    function Tube([double]$x1, [double]$y1, [double]$x2, [double]$y2, [double]$w = 13) {
        $edge = New-Object System.Drawing.Pen((C $Outline), ($w + 8))
        $edge.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $edge.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $core = New-Object System.Drawing.Pen((C $SteelDark), $w)
        $core.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $core.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $g.DrawLine($edge, $x1, $y1, $x2, $y2)
        $g.DrawLine($core, $x1, $y1, $x2, $y2)
    }
    # Frame rail along the axle line, plus a truss up to the body. Kept inside
    # innerL..innerR so the punch leaves it alone.
    Tube $innerL $axleY $innerR $axleY 16
    Tube $innerL $axleY ($innerL + 34) ($rocker + 4)
    Tube $innerR $axleY ($innerR - 34) ($rocker + 4)
    Tube ($innerL + 34) ($rocker + 4) ($innerR - 34) ($rocker + 4)
    # Diff housing at the centre of the axle line.
    $mid = ($innerL + $innerR) / 2.0
    $g.FillEllipse($brSteel, ($mid - 26), ($axleY - 24), 52, 48)
    $g.DrawEllipse($pen, ($mid - 26), ($axleY - 24), 52, 48)

    # Coil-over shocks, leaning outward from the frame down toward each hub.
    # They stop at the arch edge for the same reason the frame does.
    function Shock([double]$topX, [double]$topY, [double]$botX, [double]$botY) {
        $g.DrawLine((New-Object System.Drawing.Pen((C $Outline), 30)), $topX, $topY, $botX, $botY)
        $g.DrawLine((New-Object System.Drawing.Pen((C $Steel), 20)), $topX, $topY, $botX, $botY)
        $turns = 6
        for ($i = 0; $i -le $turns; $i++) {
            $t = $i / [double]$turns
            $px = $topX + ($botX - $topX) * $t
            $py = $topY + ($botY - $topY) * $t
            $g.DrawLine($thin, ($px - 12), $py, ($px + 12), ($py + 6))
        }
    }
    Shock ($innerL + 46) ($rocker + 2) ($innerL + 4) ($axleY - 6)
    Shock ($innerR - 46) ($rocker + 2) ($innerR - 4) ($axleY - 6)

    # --- bodywork -----------------------------------------------------------
    # One silhouette path so the outline reads as a single bold stroke. Short
    # bed, upright cab, stubby hood: a compact slab, not a long pickup.
    $bedTop = $rocker - 84.0
    $hoodTop = $rocker - 92.0
    $roof = $rocker - 168.0
    $body = New-Object System.Drawing.Drawing2D.GraphicsPath
    $body.AddPolygon(@(
            (New-Object System.Drawing.PointF(($x0 + 30), ($rocker - 44))),
            (New-Object System.Drawing.PointF(($x0 + 46), $bedTop)),
            (New-Object System.Drawing.PointF(($x0 + 258), $bedTop)),
            (New-Object System.Drawing.PointF(($x0 + 292), $roof)),
            (New-Object System.Drawing.PointF(($x0 + 446), $roof)),
            (New-Object System.Drawing.PointF(($x0 + 478), $hoodTop)),
            (New-Object System.Drawing.PointF(($x0 + 646), $hoodTop)),
            (New-Object System.Drawing.PointF(($x0 + 670), ($rocker - 48))),
            (New-Object System.Drawing.PointF(($x0 + 670), $rocker)),
            (New-Object System.Drawing.PointF(($x0 + 30), $rocker))
        ))
    $g.FillPath($brPaint, $body)
    # Bed side a shade darker, so the bed reads as separate from the cab.
    $g.FillRectangle($brPaintDark, ($x0 + 46), $bedTop, 212, ($rocker - $bedTop))
    # Cab glass, split by the B-pillar.
    $g.FillRectangle($brGlass, ($x0 + 306), ($roof + 16), 56, 58)
    $g.FillRectangle($brGlass, ($x0 + 374), ($roof + 16), 74, 58)
    $g.DrawPath($pen, $body)
    $g.DrawRectangle($thin, ($x0 + 306), ($roof + 16), 56, 58)
    $g.DrawRectangle($thin, ($x0 + 374), ($roof + 16), 74, 58)

    # --- roll cage, stack, blower, push bar ---------------------------------
    # A hoop over the cab, with both legs landing on something solid. An earlier
    # version ran a long brace back over the bed, which at this scale read as a
    # spoiler floating in mid-air rather than as structure.
    Tube ($x0 + 300) ($roof - 14) ($x0 + 440) ($roof - 14) 14
    Tube ($x0 + 300) ($roof - 14) ($x0 + 274) ($bedTop + 10) 14
    Tube ($x0 + 440) ($roof - 14) ($x0 + 452) ($hoodTop - 6) 14

    # Exhaust stack behind the cab. Vertical: angled, it read as a fallen pole.
    $g.DrawLine((New-Object System.Drawing.Pen((C $Outline), 32)), ($x0 + 240), ($bedTop + 6), ($x0 + 240), ($roof - 40))
    $g.DrawLine((New-Object System.Drawing.Pen((C $Chrome), 22)), ($x0 + 240), ($bedTop + 6), ($x0 + 240), ($roof - 40))
    $g.FillRectangle($brChrome, ($x0 + 226), ($roof - 52), 30, 16)
    $g.DrawRectangle($thin, ($x0 + 226), ($roof - 52), 30, 16)

    # Supercharger poking through the hood, with its scoop.
    $g.FillRectangle($brSteel, ($x0 + 512), ($hoodTop - 48), 92, 48)
    $g.DrawRectangle($pen, ($x0 + 512), ($hoodTop - 48), 92, 48)
    $g.FillRectangle($brChrome, ($x0 + 528), ($hoodTop - 70), 60, 24)
    $g.DrawRectangle($thin, ($x0 + 528), ($hoodTop - 70), 60, 24)
    for ($i = 0; $i -lt 4; $i++) {
        $g.DrawLine($thin, ($x0 + 522 + $i * 21), ($hoodTop - 42), ($x0 + 522 + $i * 21), ($hoodTop - 8))
    }

    # Front push bar, grille slats, headlight, door furniture, bed rail.
    $g.FillRectangle($brChrome, ($x0 + 654), ($rocker - 70), 24, 58)
    $g.DrawRectangle($thin, ($x0 + 654), ($rocker - 70), 24, 58)
    for ($i = 0; $i -lt 3; $i++) {
        $g.DrawLine($thin, ($x0 + 628), ($rocker - 60 + $i * 13), ($x0 + 662), ($rocker - 60 + $i * 13))
    }
    $g.FillRectangle($brChrome, ($x0 + 590), ($hoodTop + 12), 40, 22)
    $g.DrawRectangle($thin, ($x0 + 590), ($hoodTop + 12), 40, 22)
    $g.DrawLine($thin, ($x0 + 366), $bedTop, ($x0 + 366), ($rocker - 6))
    $g.DrawLine($thin, ($x0 + 478), $bedTop, ($x0 + 478), ($rocker - 6))
    $g.FillRectangle($ink, ($x0 + 408), ($bedTop + 24), 28, 9)
    $g.DrawLine($thin, ($x0 + 52), ($bedTop + 12), ($x0 + 254), ($bedTop + 12))

    # Arch flares, drawn before the punch so the punch trims them to shape.
    foreach ($cx in @($rearX, $frontX)) {
        $g.DrawArc($thin, ($cx - $archR - 15), ($axleY - $archR - 15), (($archR + 15) * 2), (($archR + 15) * 2), 180, 180)
    }

    # Arches punched out last, so they cut through fill, tube and outline alike
    # and leave a genuinely empty opening for the physics tyre to sit in. Exact
    # circles on the axle line, which is where car.tscn puts the wheels.
    $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $clear = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
    foreach ($cx in @($rearX, $frontX)) {
        $g.FillEllipse($clear, ($cx - $archR), ($axleY - $archR), ($archR * 2), ($archR * 2))
    }
    $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver

    # Re-stroke the arch lips, which the punch just erased. Top half only: the
    # bottom half is open air under the truck.
    foreach ($cx in @($rearX, $frontX)) {
        $g.DrawArc($pen, ($cx - $archR), ($axleY - $archR), ($archR * 2), ($archR * 2), 180, 180)
    }

    $g.Dispose()
    $out = Save-Canvas $bmp $BodyOut
    $bmp.Dispose()
    $out
    "  arches at x {0:N0} and {1:N0} of {2:N0}, radius {3:N0}" -f `
    ($len * $RearAxle), ($len * $FrontAxle), $len, $archR
    "  wheelbase {0:N0} = {1:N2} tyre radii  (pickup ~5.5, monster truck ~3.3)" -f `
    ($len * ($FrontAxle - $RearAxle)), (($FrontAxle - $RearAxle) / $ArchRadius)
    "  axle line at y {0:N0}, bodywork bottom at y {1:N0}, roof at y {2:N0}" -f $axleY, $rocker, $roof
}

# --- tyre ------------------------------------------------------------------
# Straight-on side view, unlike art_ref/tire_depth.png, which is deliberately
# three-quarter. A wheel that spins has to be drawn face-on or it wobbles.
#
# Monster-truck tyre: deep paddle lugs biting well into the carcass, and a small
# rim relative to the sidewall. Both are what separate it from the pickup tyre
# this replaces - that one had a big rim and shallow shoulder blocks.
function New-TruckTyre {
    $c = New-Canvas $TyreSize $TyreSize
    $bmp = $c[0]; $g = $c[1]
    $mid = $TyreSize / 2.0
    $r = $TyreSize * 0.47

    $brRubber = New-Object System.Drawing.SolidBrush (C $Rubber)
    $brTread = New-Object System.Drawing.SolidBrush (C $Tread)
    $brRim = New-Object System.Drawing.SolidBrush (C $Rim)
    $brHub = New-Object System.Drawing.SolidBrush (C $Hub)
    $pen = New-Object System.Drawing.Pen((C $Outline), 7)

    $g.FillEllipse($brRubber, ($mid - $r), ($mid - $r), ($r * 2), ($r * 2))

    # Paddle lugs around the shoulder, angled off radial so they read as a tread
    # pattern rather than a gear. Blocky and countable: at speed these are what
    # makes the rotation readable.
    $blocks = 16
    for ($i = 0; $i -lt $blocks; $i++) {
        $a = [Math]::PI * 2 * $i / $blocks
        $bw = $r * 0.30; $bh = $r * 0.20
        $bx = $mid + [Math]::Cos($a) * $r * 0.80
        $by = $mid + [Math]::Sin($a) * $r * 0.80
        $st = $g.Save()
        $g.TranslateTransform($bx, $by)
        $g.RotateTransform($a * 180 / [Math]::PI + 18)
        $g.FillRectangle($brTread, (-$bw / 2), (-$bh / 2), $bw, $bh)
        $g.DrawRectangle($pen, (-$bw / 2), (-$bh / 2), $bw, $bh)
        $g.Restore($st)
    }

    $g.DrawEllipse($pen, ($mid - $r), ($mid - $r), ($r * 2), ($r * 2))

    # Deep sidewall, small rim: the monster-truck signature. The pickup ref had
    # this at 0.52 of the tyre, which reads as a road wheel.
    $rimR = $r * 0.38
    $g.FillEllipse($brRim, ($mid - $rimR), ($mid - $rimR), ($rimR * 2), ($rimR * 2))
    $g.DrawEllipse($pen, ($mid - $rimR), ($mid - $rimR), ($rimR * 2), ($rimR * 2))
    $hubR = $r * 0.15
    $g.FillEllipse($brHub, ($mid - $hubR), ($mid - $hubR), ($hubR * 2), ($hubR * 2))
    $g.DrawEllipse($pen, ($mid - $hubR), ($mid - $hubR), ($hubR * 2), ($hubR * 2))
    # Lug nuts: the asymmetry the eye tracks when the wheel is turning.
    for ($i = 0; $i -lt 8; $i++) {
        $a = [Math]::PI * 2 * $i / 8
        $lr = $r * 0.045
        $lx = $mid + [Math]::Cos($a) * $r * 0.26
        $ly = $mid + [Math]::Sin($a) * $r * 0.26
        $g.FillEllipse($brHub, ($lx - $lr), ($ly - $lr), ($lr * 2), ($lr * 2))
    }

    $g.Dispose()
    $out = Save-Canvas $bmp $TyreOut
    $bmp.Dispose()
    $out
}

New-TruckBody
New-TruckTyre
