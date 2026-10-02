#!/usr/bin/env bash
# Look B's loop: film, build the gif/mp4/sheet, cut zoomed crops at key moments.
#   bash tools/tornado_mock/run_b.sh [wide]
set -e
cd "$(dirname "$0")/../.."
if [ "$1" = "wide" ]; then
  TORNADO_WIDE=1 "/c/Users/Administrador/Desktop/Godot_v4.7.1-stable_win64.exe" --path . --fixed-fps 60 res://tools/tornado_mock/shot_b.tscn --log-file tools/tornado_mock/b_wide_engine.log > /dev/null 2>&1 || true
  grep -iE "error|look_b" tools/tornado_mock/b_wide_engine.log | head -20 || true
  powershell -ExecutionPolicy Bypass -File tools/tornado_mock/make_gif.ps1 b wide
  exit 0
fi
"/c/Users/Administrador/Desktop/Godot_v4.7.1-stable_win64.exe" --path . --fixed-fps 60 res://tools/tornado_mock/shot_b.tscn --log-file tools/tornado_mock/b_engine.log > /dev/null 2>&1 || true
grep -iE "error|look_b|SCRIPT" tools/tornado_mock/b_engine.log | head -20 || true
tail -2 tools/tornado_mock/out_b/log.txt
powershell -ExecutionPolicy Bypass -File tools/tornado_mock/make_gif.ps1 b
cd tools/tornado_mock/out_b
mkdir -p ../zoom
# Key frames, zoomed x2: touchdown, roam, hit 1, hit 2, collapse.
for f in 0040 0180 0288 0332 0385 0400 0415; do
  ffmpeg -y -loglevel error -i f_$f.png -vf "scale=1600:1280:flags=neighbor" ../zoom/b_$f.png
done
ffmpeg -y -loglevel error -i f_0180.png -vf "crop=400:320:200:320,scale=800:640:flags=neighbor" ../zoom/b_foot.png
ffmpeg -y -loglevel error -i f_0180.png -vf "crop=400:320:200:0,scale=800:640:flags=neighbor" ../zoom/b_top.png
ffmpeg -y -loglevel error -i f_0284.png -i f_0288.png -i f_0292.png -i f_0298.png -filter_complex "[0][1][2][3]hstack=inputs=4" ../zoom/b_hit_strip.png
ffmpeg -y -loglevel error -i f_0378.png -i f_0390.png -i f_0400.png -i f_0410.png -i f_0425.png -filter_complex "[0][1][2][3][4]hstack=inputs=5" ../zoom/b_collapse_strip.png
ffmpeg -y -loglevel error -i f_0010.png -i f_0025.png -i f_0038.png -i f_0046.png -i f_0060.png -filter_complex "[0][1][2][3][4]hstack=inputs=5" ../zoom/b_touch_strip.png
# Spin: the funnel cropped over five pattern steps; hit close-up; the end of the collapse.
for f in 0180 0184 0188 0192 0196; do
  ffmpeg -y -loglevel error -i f_$f.png -vf "crop=160:240:300:190,scale=320:480:flags=neighbor" ../zoom/_s$f.png
done
ffmpeg -y -loglevel error -i ../zoom/_s0180.png -i ../zoom/_s0184.png -i ../zoom/_s0188.png -i ../zoom/_s0192.png -i ../zoom/_s0196.png -filter_complex "hstack=inputs=5" ../zoom/b_spin5.png
rm -f ../zoom/_s*.png
ffmpeg -y -loglevel error -i f_0286.png -i f_0290.png -i f_0296.png -filter_complex "[0]crop=240:300:260:260[a];[1]crop=240:300:260:260[b];[2]crop=240:300:260:260[c];[a][b][c]hstack=inputs=3,scale=1440:900:flags=neighbor" ../zoom/b_hitz.png
ffmpeg -y -loglevel error -i f_0400.png -i f_0420.png -i f_0440.png -i f_0460.png -filter_complex "hstack=inputs=4" ../zoom/b_end_strip.png
echo done
