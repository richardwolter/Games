#!/bin/sh
# Films look C (near, or wide with TORNADO_WIDE=1) and builds its gif, mp4 and sheet.
cd "$(dirname "$0")/../.."
if [ "$TORNADO_WIDE" = "1" ]; then name=c_wide; mode=wide; else name=c; mode=; fi
"/c/Users/Administrador/Desktop/Godot_v4.7.1-stable_win64.exe" --path . --fixed-fps 60 res://tools/tornado_mock/shot_c.tscn --log-file tools/tornado_mock/${name}_engine.log > /dev/null 2>&1
grep -iE "error|parse|invalid" tools/tornado_mock/${name}_engine.log | sort | uniq -c | head -20
powershell -ExecutionPolicy Bypass -File tools/tornado_mock/make_gif.ps1 c $mode > /dev/null
echo built $name
