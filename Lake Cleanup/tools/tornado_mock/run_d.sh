#!/usr/bin/env bash
# Look D: film, check the engine log, build the gif/mp4/sheet, and cut the proof strips.
#   bash tools/tornado_mock/run_d.sh            # film + everything
#   bash tools/tornado_mock/run_d.sh cut        # strips and crops only, from the last film
#   bash tools/tornado_mock/run_d.sh wide       # the wide film
# Frame k of out_d/ is the tornado clock (k + 1) / 30 s.
cd "$(dirname "$0")/../.."
GODOT="/c/Users/Administrador/Desktop/Godot_v4.7.1-stable_win64.exe"
if [ "$1" = "wide" ]; then
  TORNADO_WIDE=1 "$GODOT" --path . --fixed-fps 60 res://tools/tornado_mock/shot_d.tscn --log-file tools/tornado_mock/d_wide_engine.log > /dev/null 2>&1
  grep -nE "ERROR|SCRIPT|SHADER|look_d" tools/tornado_mock/d_wide_engine.log | head -20
  powershell -ExecutionPolicy Bypass -File tools/tornado_mock/make_gif.ps1 d wide
  exit 0
fi
if [ "$1" != "cut" ]; then
  start=$(date +%s)
  "$GODOT" --path . --fixed-fps 60 res://tools/tornado_mock/shot_d.tscn --log-file tools/tornado_mock/d_engine.log > /dev/null 2>&1
  echo "film took $(( $(date +%s) - start )) s"
  grep -nE "ERROR|SCRIPT|SHADER|Parse|look_d" tools/tornado_mock/d_engine.log | grep -v hud_skin | head -8
  if grep -qE "Parse Error|SHADER ERROR|Nonexistent function" tools/tornado_mock/d_engine.log; then echo "ENGINE ERRORS, stopping"; exit 1; fi
  tail -3 tools/tornado_mock/out_d/log.txt
  powershell -ExecutionPolicy Bypass -File tools/tornado_mock/make_gif.ps1 d
fi
cd tools/tornado_mock/out_d
frame() { printf "f_%04d.png" "$1"; }
# Touchdown: 8 frames evenly over 0-2 s.
args=""; n=0
for k in 0 8 16 25 33 42 50 59; do args="$args -i $(frame $k)"; n=$((n+1)); done
ffmpeg -y -loglevel error $args -filter_complex "hstack=inputs=$n,scale=iw/2:-1:flags=neighbor" strip_touchdown.png
# The vanish: 12 frames evenly from hit 3 (12.5 s) to the end of the calm (16 s), two rows.
args=""; n=0
for i in 0 1 2 3 4 5 6 7 8 9 10 11; do
  k=$(( 374 + (i * 105 + 5) / 11 )); [ $k -gt 479 ] && k=479
  args="$args -i $(frame $k)"; n=$((n+1))
done
ffmpeg -y -loglevel error $args -filter_complex "[0][1][2][3][4][5]hstack=inputs=6[a];[6][7][8][9][10][11]hstack=inputs=6[b];[a][b]vstack=inputs=2,scale=iw/2:-1:flags=neighbor" strip_vanish.png
# The eye at mid-roam (6.0 s), cropped round the eye's middle (found by the look, logged) and
# scaled up 2x nearest.
ey=$(grep -m1 "eye@6" log_eye.txt 2>/dev/null | awk '{print $2}')
ex=$(grep -m1 "eye@6" log_eye.txt 2>/dev/null | awk '{print $3}')
[ -z "$ex" ] && ex=460 && ey=300
cx=$(( ex - 200 )); cy=$(( ey - 110 )); [ $cy -lt 0 ] && cy=0; [ $cx -lt 0 ] && cx=0
ffmpeg -y -loglevel error -i $(frame 179) -vf "crop=400:220:$cx:$cy,scale=800:440:flags=neighbor" eye_close.png
echo "eye crop at $cx,$cy"
# Crops that follow the eye (out_d/log_eye_all.txt): the gather, the eye shutting, the break-up.
cd ..
bash eye_strip.sh out_d/strip_gather.png 560 440 280 150 4 0.6 4 8 12 16 20 24 30 36
bash eye_strip.sh out_d/strip_eye_shut.png 420 260 210 130 4 1.0 404 410 414 418 422 426 430 434
bash eye_strip.sh out_d/strip_breakup.png 760 440 380 200 3 0.6 436 440 444 448 451 454 457 460 464
echo cut done
# The rope entering the eye (touchdown), and hit 1 against hit 2.
bash eye_strip.sh out_d/strip_neck.png 360 440 180 120 4 1.0 12 24 32 38 42 46 50 56
bash eye_strip.sh out_d/strip_hits.png 300 440 150 60 6 0.8 280 285 288 292 296 300 326 330 333 337 341 345
echo neck and hit strips done
