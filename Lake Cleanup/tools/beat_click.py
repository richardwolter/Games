#!/usr/bin/env python
"""Writes the first 40 s of each song with a click on every beat assets/music/beats.json
measured (tools/measure_beats.py), to tools/last_beat_<slug>.wav, for checking by ear that
the grid the animals move to is the one the song is on. Accented on every fourth beat.

  <psd-extract venv python> tools/beat_click.py
"""
import json
import os
import subprocess
import wave

import numpy as np

RATE = 44100
SECONDS = 40.0

table = json.load(open(os.path.join("assets", "music", "beats.json"), encoding="utf-8"))
for slug, beat in table.items():
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", os.path.join("assets", "music", slug + ".mp3"),
                          "-t", str(SECONDS), "-ac", "1", "-ar", str(RATE), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    x = np.frombuffer(raw, dtype=np.float32).copy() * 0.6
    period = 60.0 / beat["bpm"]
    tick = np.sin(np.arange(int(RATE * 0.03)) * 2 * np.pi * 1800 / RATE) * np.exp(-np.arange(int(RATE * 0.03)) / 200.0)
    for n, t in enumerate(np.arange(beat["offset"], len(x) / RATE, period)):
        i = int(t * RATE)
        seg = tick * (0.9 if n % 4 == 0 else 0.5)
        x[i:i + len(seg)] += seg[: len(x) - i]
    out = os.path.join("tools", f"last_beat_{slug}.wav")
    with wave.open(out, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())
    print("wrote", out)
