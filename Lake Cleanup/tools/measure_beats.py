#!/usr/bin/env python
"""Measures each song's beat grid for the animals that move to the music (scripts/wildlife.gd,
MusicStation.beat_phase): its tempo and where its first beat falls, written to
assets/music/beats.json as {"<slug>": {"bpm": .., "offset": ..}}.

Onset strength is the spectral flux of the song decoded to mono at 11025 Hz, weighted to the
low end (the kick is what an animal dances to). The tempo is the autocorrelation peak of that
envelope between MIN_BPM and MAX_BPM, refined to a hundredth of a BPM by scoring the whole
song's grid; the offset is the phase that grid scores best at. A person should still listen:
tools/beat_click.py writes each song with a click on every measured beat.

Run from the project root (ffmpeg on PATH, psd-extract venv python for numpy):
  <venv python> tools/measure_beats.py
"""
from __future__ import annotations

import json
import os
import subprocess

import numpy as np

SONGS = ["beatgucci", "save_me", "goin", "habibs"]
DIR = os.path.join("assets", "music")
OUT = os.path.join(DIR, "beats.json")
RATE = 11025
HOP = 256
MIN_BPM, MAX_BPM = 60.0, 170.0
DOUBLE_UNDER = 90.0
DOUBLE_NEAR = 0.92
## Which octave a song is in is a thing an ear decides, not a score: beatgucci's half-time
## (67.5) outscores its 135 by more than Save ME's 160 trails its 80, and no one threshold
## puts both where they belong. A hint only picks the octave; the tempo within a BPM of it,
## and the offset, are still measured. Check by ear with tools/beat_click.py.
TEMPO_HINT = {"beatgucci": 135.0}


def decode(path: str) -> np.ndarray:
    raw = subprocess.run(
        ["ffmpeg", "-v", "quiet", "-i", path, "-ac", "1", "-ar", str(RATE), "-f", "f32le", "-"],
        capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32)


def onsets(x: np.ndarray) -> np.ndarray:
    win = np.hanning(1024)
    frames = np.lib.stride_tricks.sliding_window_view(x, 1024)[::HOP] * win
    spec = np.abs(np.fft.rfft(frames, axis=1))
    freqs = np.fft.rfftfreq(1024, 1.0 / RATE)
    weight = np.where(freqs < 200, 3.0, np.where(freqs < 2000, 1.0, 0.4))
    spec = np.log1p(spec * 10.0) * weight
    flux = np.maximum(np.diff(spec, axis=0), 0.0).sum(axis=1)
    flux = flux - np.convolve(flux, np.ones(16) / 16, mode="same")
    return np.maximum(flux, 0.0)


def score(env: np.ndarray, bpm: float, offset: float) -> float:
    fps = RATE / HOP
    period = 60.0 / bpm
    times = np.arange(offset, len(env) / fps, period)
    idx = np.round(times * fps).astype(int)
    idx = idx[idx < len(env)]
    return float(env[idx].mean())


def best_phase(env: np.ndarray, bpm: float) -> tuple[float, float]:
    period = 60.0 / bpm
    best = (-1.0, 0.0)
    for off in np.linspace(0, period, 96, endpoint=False):
        s = score(env, bpm, off)
        if s > best[0]:
            best = (s, off)
    return best


def measure(slug: str) -> dict:
    """Every tempo from MIN_BPM to MAX_BPM a twentieth apart is scored over the whole song,
    the envelope widened a frame each side so a beat a frame early still counts. The best
    wins, except that a winner under DOUBLE_UNDER whose double scores within DOUBLE_NEAR of
    it is taken at the double: a song's half-time always scores well (Habibs' 72 beat its
    own 144 by a hair), and a turtle nodding at half the song's pace reads as off the beat."""
    env = onsets(decode(os.path.join(DIR, slug + ".mp3")))
    env = np.maximum(env, np.maximum(np.roll(env, 1), np.roll(env, -1)))
    scored = {}
    for bpm in np.arange(MIN_BPM, MAX_BPM + 0.001, 0.05):
        scored[round(float(bpm), 2)] = best_phase(env, bpm)
    bpm = max(scored, key=lambda b: scored[b][0])
    if slug in TEMPO_HINT:
        near = [b for b in scored if abs(b - TEMPO_HINT[slug]) <= 1.0]
        bpm = max(near, key=lambda b: scored[b][0])
        return {"bpm": bpm, "offset": round(float(scored[bpm][1]), 4)}
    double = round(bpm * 2.0, 2)
    if bpm < DOUBLE_UNDER and double in scored and scored[double][0] >= scored[bpm][0] * DOUBLE_NEAR:
        bpm = double
    return {"bpm": bpm, "offset": round(float(scored[bpm][1]), 4)}


def main() -> None:
    table = {}
    for slug in SONGS:
        table[slug] = measure(slug)
        print(slug, table[slug])
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        json.dump(table, f, indent=1)


if __name__ == "__main__":
    main()
