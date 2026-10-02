#!/bin/sh
# Look A: film, check the engine log, build the gif/mp4/sheet.
cd "$(dirname "$0")/../.."
"/c/Users/Administrador/Desktop/Godot_v4.7.1-stable_win64.exe" --path . --fixed-fps 60 res://tools/tornado_mock/shot_a.tscn --log-file tools/tornado_mock/a_engine.log > /dev/null 2>&1
grep -n "ERROR\|SCRIPT\|SHADER" tools/tornado_mock/a_engine.log | head -20
tail -2 tools/tornado_mock/out_a/log.txt
powershell -ExecutionPolicy Bypass -File tools/tornado_mock/make_gif.ps1 a > /dev/null
