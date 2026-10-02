#!/usr/bin/env bash
# Crops that follow the eye (out_d/log_eye_all.txt: frame x y in the cropped picture).
#   bash eye_strip.sh out.png W H DX DY COLS SCALE frames...
# Each tile is W x H with the eye at (DX, DY) inside it; tiles laid COLS across, scaled SCALE
# (nearest). Run from tools/tornado_mock.
out=$1; w=$2; h=$3; dx=$4; dy=$5; cols=$6; sc=$7; shift 7
dir=out_d
args=""; fc=""; ins=""; lay=""; n=0
for k in "$@"; do
  read ex ey < <(awk -v k="$k" '$1==k {print $2, $3; exit}' $dir/log_eye_all.txt)
  [ -z "$ex" ] && ex=560 && ey=300
  x=$(( ex - dx )); y=$(( ey - dy ))
  [ $x -lt 0 ] && x=0; [ $y -lt 0 ] && y=0
  [ $((x + w)) -gt 1120 ] && x=$((1120 - w)); [ $((y + h)) -gt 800 ] && y=$((800 - h))
  args="$args -i $dir/$(printf f_%04d.png $k)"
  fc="$fc[$n]crop=$w:$h:$x:$y[c$n];"
  r=$((n / cols)); c=$((n % cols)); lay="$lay$((c * w))_$((r * h))|"; ins="$ins[c$n]"
  n=$((n + 1))
done
lay=${lay%|}
ffmpeg -y -loglevel error $args -filter_complex "${fc}${ins}xstack=inputs=$n:layout=$lay:fill=black,scale=iw*$sc:-1:flags=neighbor" -frames:v 1 "$out"
