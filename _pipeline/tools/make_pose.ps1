# Draws OpenPose skeletons for ControlNet, without a preprocessor.
#
#   .\tools\make_pose.ps1 -Preset tq_mid -Width 704 -Height 1024 -Out art\poses\tq_mid.png
#   .\tools\make_pose.ps1 -All -OutDir "art\poses"
#
# The usual way to get a pose image is to run a photo through an OpenPose
# preprocessor. That needs a custom node, and it can only reproduce camera angles
# you already have a photo of -- which is exactly the problem here, since no
# reference exists for the 3/4 top-down view this game needs. So the skeletons
# are authored directly instead.
#
# Format is COCO-18, the layout xinsir/controlnet-openpose-sdxl-1.0 was trained
# on: 18 keypoints, 17 limbs, each limb its own hue, joints as dots, on black.
# The colours are not decorative -- the model reads limb identity from them, so
# they must match OpenPose's own palette or the pose is misread.

param(
    [string]$Preset = "tq_mid",
    [switch]$All,
    [int]$Width = 704,
    [int]$Height = 1024,
    [string]$Out = "",
    [string]$OutDir = "",
    # How far the figure turns toward screen-right. 0 = square to camera,
    # 1 = full profile.
    [double]$Turn = 0.35
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

# Base pose: a four-head-tall child standing square to the camera, arms down.
# Proportions come from ART_BIBLE.md -- an adult skeleton generates an adult, no
# matter what the prompt says. Normalised 0..1, y down.
#
# Head SIZE is the thing to get right, and OpenPose has no keypoint for it -- the
# model infers it from how far apart the eyes and ears sit relative to the
# shoulders. An adult skeleton has a head roughly 60% of shoulder width; a small
# child is close to 1:1. Left at adult spacing, every generation comes out as a
# lanky grown-up no matter what the prompt or the reference says.
$BASE = @{
    0  = @(0.500, 0.185)  # nose
    1  = @(0.500, 0.300)  # neck
    2  = @(0.415, 0.335)  # right shoulder
    3  = @(0.385, 0.455)  # right elbow
    4  = @(0.370, 0.565)  # right wrist
    5  = @(0.585, 0.335)  # left shoulder
    6  = @(0.615, 0.455)  # left elbow
    7  = @(0.630, 0.565)  # left wrist
    8  = @(0.450, 0.580)  # right hip
    9  = @(0.445, 0.760)  # right knee
    10 = @(0.440, 0.935)  # right ankle
    11 = @(0.550, 0.580)  # left hip
    12 = @(0.555, 0.760)  # left knee
    13 = @(0.560, 0.935)  # left ankle
    14 = @(0.462, 0.155)  # right eye
    15 = @(0.538, 0.155)  # left eye
    16 = @(0.405, 0.175)  # right ear
    17 = @(0.595, 0.175)  # left ear
}

# Camera elevation, as the factor everything below the neck is squashed by.
# Looking down at someone foreshortens the body while the head, being nearest
# the camera, keeps its size -- which is the whole reason a top-down character
# reads as head-and-shoulders.
$PRESETS = @{
    "front"     = 1.00
    "tq_low"    = 0.88
    "tq_mid"    = 0.72
    "tq_high"   = 0.55
    "topdown"   = 0.38
}

$LIMBS = @(
    @(1, 2), @(1, 5), @(2, 3), @(3, 4), @(5, 6), @(6, 7), @(1, 8), @(8, 9),
    @(9, 10), @(1, 11), @(11, 12), @(12, 13), @(1, 0), @(0, 14), @(14, 16),
    @(0, 15), @(15, 17)
)

# OpenPose's canonical 18 colours, in order.
$COLORS = @(
    @(255, 0, 0),   @(255, 85, 0),  @(255, 170, 0), @(255, 255, 0), @(170, 255, 0),
    @(85, 255, 0),  @(0, 255, 0),   @(0, 255, 85),  @(0, 255, 170), @(0, 255, 255),
    @(0, 170, 255), @(0, 85, 255),  @(0, 0, 255),   @(85, 0, 255),  @(170, 0, 255),
    @(255, 0, 255), @(255, 0, 170), @(255, 0, 85)
)

function New-Pose([double]$squash, [double]$turn) {
    $neckY = $BASE[1][1]
    $pose = @{}
    foreach ($k in $BASE.Keys) {
        $x = $BASE[$k][0]
        $y = $BASE[$k][1]

        # Foreshorten everything below the neck toward the neck.
        if ($y -gt $neckY) { $y = $neckY + ($y - $neckY) * $squash }

        # Turning to screen-right narrows the figure's width and slides the mass
        # across, so the far-side limbs tuck behind the near ones.
        $x = 0.5 + ($x - 0.5) * (1.0 - $turn * 0.55) + $turn * 0.05

        $pose[$k] = @($x, $y)
    }
    return $pose
}

function Write-Pose($pose, [int]$w, [int]$h, [string]$dest) {
    $bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::Black)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

    # Scale line and dot weight with the canvas so a 512px and a 1024px pose look
    # the same to the model.
    $unit = [Math]::Min($w, $h) / 1024.0
    $limbW = [float](10.0 * $unit)
    $dotR = [float](7.0 * $unit)

    for ($i = 0; $i -lt $LIMBS.Count; $i++) {
        $a = $pose[$LIMBS[$i][0]]
        $b = $pose[$LIMBS[$i][1]]
        $c = $COLORS[$i]
        $pen = New-Object System.Drawing.Pen(
            [System.Drawing.Color]::FromArgb(255, $c[0], $c[1], $c[2]), $limbW)
        $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $g.DrawLine($pen, [float]($a[0] * $w), [float]($a[1] * $h),
                          [float]($b[0] * $w), [float]($b[1] * $h))
        $pen.Dispose()
    }

    foreach ($k in ($pose.Keys | Sort-Object)) {
        $c = $COLORS[$k]
        $br = New-Object System.Drawing.SolidBrush(
            [System.Drawing.Color]::FromArgb(255, $c[0], $c[1], $c[2]))
        $g.FillEllipse($br, [float]($pose[$k][0] * $w - $dotR),
                            [float]($pose[$k][1] * $h - $dotR),
                            [float]($dotR * 2), [float]($dotR * 2))
        $br.Dispose()
    }

    $g.Dispose()
    New-Item -ItemType Directory -Force (Split-Path $dest -Parent) | Out-Null
    $bmp.Save($dest, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "pose   $dest  ($($w)x$($h))"
}

if ($All) {
    if (-not $OutDir) { throw "-All needs -OutDir" }
    foreach ($name in ($PRESETS.Keys | Sort-Object)) {
        Write-Pose (New-Pose $PRESETS[$name] $Turn) $Width $Height (Join-Path $OutDir "$name.png")
    }
}
else {
    if (-not $PRESETS.ContainsKey($Preset)) {
        throw "unknown preset '$Preset'. Known: $($PRESETS.Keys -join ', ')"
    }
    if (-not $Out) { throw "-Out is required unless -All is used" }
    Write-Pose (New-Pose $PRESETS[$Preset] $Turn) $Width $Height $Out
}
