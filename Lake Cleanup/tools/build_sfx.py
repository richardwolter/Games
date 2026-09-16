"""Build the game's sound files from the recordings in art_source/SFX.

    python tools/build_sfx.py          (from the project root; needs ffmpeg on PATH)

The recordings are kept as they were saved: 24-bit, 96 kHz, seconds of silence either
side. The game gets `assets/sfx/`: short sounds as 16-bit 44.1 kHz WAV with the silence cut
and the end faded, footsteps and sniffs cut into single steps, and the two long beds (the
lake and the fireplace) as seamless OGG loops. Every cut is a number in `PLAN` below, so a
re-recorded file is a re-run, not a hand edit.

**Every cut is then brought to one loudness** (2026-09-16, issue #1: "measured, then by
ear"). The takes were delivered up to twenty decibels apart, so `SOUNDS` in `scripts/sfx.gd`
was carrying two jobs at once — rescuing a quiet recording and mixing the game — and there
was no way to tell which of its numbers was which. Each file is measured K-weighted
(ITU-R BS.1770, `loudness` below) and gained to `TARGET_LUFS`, held under `PEAK_CEIL`. What
`SOUNDS` holds after that is the mix and nothing else.

The report goes to `tools/last_sfx.log`: every file's length, its loudness before and after,
its peak, and the gain applied. The last column is what a name's `SOUNDS` entry should move
by to keep the mix it had; after a re-record, read it and shift by hand.

Nothing here reads the game; the game reads the names this writes (`scripts/sfx.gd`).
"""

import array
import math
import os
import subprocess
import sys
import wave

SRC = "art_source/SFX"
OUT = "assets/sfx"
RATE = 44100

# name in the game: (source file, how to cut it)
#   ("trim", end_s)            silence cut from the front, faded out by end_s at the latest
#   ("span", start_s, end_s[, fade_s])  exactly that stretch, short fade in, FADE_OUT (or
#                              fade_s) out
#   ("peak", end_s)            from just before the loudest transient, faded by end_s
#   ("steps", gap_rel, most_s) one file per onset, `name_1`, `name_2`...; onsets under
#                              STEP_LEAST of the loudest are dropped as room, not steps
#   ("loop", start_s, len_s[, cross_s])  a seamless loop of len_s, its end crossfaded into its
#                              start over cross_s (default CROSSFADE); OGG, or WAV for the
#                              names in LOOP_WAV
# Every cut then goes through `level` to TARGET_LUFS, so how loud a take was recorded is not
# something this table has to know about.
PLAN = {
    "ferry_bell": ("Boat_Bell.wav", ("trim", 3.2)),
    # Two ticks, the loud one 145 ms after a soft one: heard as a late click. The loud one only.
    "ui_click": ("Click_Sound.wav", ("peak", 0.16)),
    # Its own tick is 125 ms into the take, which was heard as a late close.
    "ui_close": ("Close_Tab.wav", ("peak", 0.5)),
    "ui_hover": ("Mouse_Over_Sound.wav", ("trim", 0.2)),
    "coin": ("Coin_Sound_2.wav", ("trim", 0.4)),
    "find_caught": ("Decoration_Caught_Net.wav", ("trim", 1.0)),
    # The first hit and its ring, let go gently: at 5 s with a short fade it was heard as cut.
    "find_chime": ("Decoration_Chime.wav", ("span", 0.0, 1.5, 0.9)),
    "shed_open": ("Decoration_Menu_Open.wav", ("trim", 1.0)),
    "bark_1": ("Dog_Bark1.wav", ("trim", 0.6)),
    "bark_2": ("Dog_Bark2.wav", ("trim", 0.6)),
    "sniff_1": ("Dog_Sniff.wav", ("span", 0.0, 0.66)),
    "sniff_2": ("Dog_Sniff.wav", ("span", 0.84, 1.5)),
    "sniff_3": ("Dog_Sniff.wav", ("span", 1.52, 2.4)),
    # From the hit itself, not from its rise: both takes climb over 7-12 ms, which reads as a
    # drop landing a moment after the piece does (Richard, 2026-09-16).
    "drop_big": ("Drop_Big_Decoration.wav", ("peak", 0.5)),
    "drop_small": ("Drop_Small_Decoration.wav", ("peak", 0.4)),
    "fireplace": ("Fireplace_On.wav", ("loop", 10.0, 30.0)),
    "step_grass": ("Grass_Steps.wav", ("steps", 0.25, 0.34)),
    "step_sand": ("Sand_Steps.wav", ("steps", 0.3, 0.34)),
    # The water a hull pushes as it leaves: the body of Boatmove_water_steps, its opening
    # splash left out. Back after a day off the build (Richard, 2026-09-15) — what read as a
    # weird space sound was two ferries setting off together, so it has one player and is
    # skipped rather than doubled. `Water_Steps.wav` is out of the build.
    "boat_move": ("Boatmove_water_steps.wav", ("span", 0.30, 1.45, 0.25)),
    # Wading is a held loop, not footsteps: WaterSteps3 is water being moved rather than a
    # drip or a splash, so it runs while the angler walks in the shallows (Richard, 2026-09-15).
    # Retired as steps with it: WaterSteps2's drip, Boatmove's tail and Water_Steps.wav.
    "wading": ("WaterSteps3.flac", ("loop", 1.11, 2.2, 0.5)),
    "haul": ("Haul_Sound.wav", ("span", 0.2, 1.8)),
    "lake_ambient": ("Lake_Ambient.wav", ("loop", 1.0, 236.0)),
    "net_splash": ("Net_Splash.wav", ("trim", 1.3)),
    "game_start": ("NewGame_Continue_Sound.wav", ("trim", 2.8)),
    "piece_splash": ("Object_Splash.wav", ("trim", 1.1)),
    "pigeon_fly": ("Pigeon_Fly.wav", ("trim", 1.3)),
    "pigeon_coo": ("Pigeon_Noise.wav", ("trim", 2.0)),
    "net_throw": ("Throwing_Net.wav", ("trim", 0.45)),
    "upgrade": ("Upgrade_Purchase.wav", ("trim", 1.2)),
}

## Names whose low end is rolled off and whose start is eased in: brought up to level, the
## rumble under a quiet take reads as a click or a thump rather than as water.
## Short loops kept as WAV rather than OGG. The wading loop as an .ogg would not open in the
## editor's inspector however often it was reimported, renamed or had its UID rebuilt, while
## every other .ogg in the project did (2026-09-15); as a WAV it is one of the ordinary sounds.
## The long beds stay OGG — the lake's four minutes would be 41 MB of WAV.
LOOP_WAV = {"wading"}  # also a plain sound now: the game leaves a gap between plays
SMOOTH = {"step_water"}
SMOOTH_HZ = 500.0
SMOOTH_IN = 0.03
## The faintest onset in a footstep take that is still a footstep, against the loudest.
STEP_LEAST = 0.25

## Where every cut lands, in LUFS. Issue #1 asks for -24 to -20 for the effects and -20 for
## the ambience; the middle of the band for the one, the spec's own figure for the other.
##
## Measured ungated over the whole cut, not as EBU R128's gated integrated loudness: the
## gate and its 400 ms blocks are built for programme material, and most of what is here is
## a tenth of a second long. One rule for every file is worth more than a standard applied
## to a third of them.
TARGET_LUFS = -22.0
BED_LUFS = -20.0
BEDS = {"lake_ambient", "fireplace"}

## No cut goes over this, whatever the loudness pass asks for. The spec's own ceiling: a
## transient at nought would be the one that clips when the player's slider is at the top.
PEAK_CEIL = -3.0
## How much of a long bed is measured. A steady bed's loudness is the same over twenty
## seconds as over four minutes, and the filters are a Python loop.
MEASURE_MOST = 20.0

FADE_IN = 0.004
FADE_OUT = 0.08
CROSSFADE = 3.0


def decode(path):
    """Stereo 16-bit frames at RATE, as one interleaved array."""
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", path, "-ac", "2", "-ar", str(RATE), "-f", "s16le", "-"],
        capture_output=True, check=True,
    ).stdout
    samples = array.array("h")
    samples.frombytes(raw)
    return samples


def envelope(samples, win_s):
    n = max(1, int(RATE * win_s))
    out = []
    for i in range(0, len(samples) // 2 - n, n):
        chunk = samples[i * 2:(i + n) * 2]
        out.append(math.sqrt(sum(x * x for x in chunk) / len(chunk)) / 32768.0)
    return out


def cut(samples, a_s, b_s):
    a = max(0, int(a_s * RATE)) * 2
    b = min(len(samples), int(b_s * RATE) * 2)
    return samples[a:b]


def fade(samples, fade_in, fade_out):
    frames = len(samples) // 2
    fin = int(fade_in * RATE)
    fout = min(int(fade_out * RATE), frames // 2)
    for f in range(frames):
        g = 1.0
        if f < fin:
            g = f / fin
        if f >= frames - fout:
            g = min(g, (frames - f) / fout)
        if g < 1.0:
            samples[f * 2] = int(samples[f * 2] * g)
            samples[f * 2 + 1] = int(samples[f * 2 + 1] * g)
    return samples


def trimmed(samples, end_s):
    """Cut the silence before the sound and anything past end_s after its start."""
    env = envelope(samples, 0.005)
    peak = max(env)
    start = next(i for i, e in enumerate(env) if e > peak * 0.03) * 0.005
    start = max(0.0, start - 0.005)
    last = max(i for i, e in enumerate(env) if e > peak * 0.01) * 0.005 + 0.02
    end = min(start + end_s, last + FADE_OUT)
    return fade(cut(samples, start, end), FADE_IN, FADE_OUT)


def high_pass(samples, hz):
    """One-pole high pass, per channel: what is left is the splash, not the knock under it."""
    import math as _m
    a = _m.exp(-2.0 * _m.pi * hz / RATE)
    for c in (0, 1):
        last_in = 0
        last_out = 0.0
        for f in range(len(samples) // 2):
            i = f * 2 + c
            x = samples[i]
            last_out = a * (last_out + x - last_in)
            last_in = x
            samples[i] = max(-32768, min(32767, int(last_out)))
    return samples


def _biquad(samples, b, a):
    """One biquad over both channels, in place. `a[0]` is already divided out."""
    for c in (0, 1):
        x1 = x2 = y1 = y2 = 0.0
        for f in range(len(samples) // 2):
            i = f * 2 + c
            x0 = samples[i] / 32768.0
            y0 = b[0] * x0 + b[1] * x1 + b[2] * x2 - a[1] * y1 - a[2] * y2
            x2, x1 = x1, x0
            y2, y1 = y1, y0
            samples[i] = max(-32768, min(32767, int(y0 * 32768.0)))
    return samples


def _k_weight():
    """The two stages of ITU-R BS.1770's K-weighting, designed for RATE: a high shelf that
    stands in for the head, and a high pass that takes the rumble out."""
    import math as _m
    out = []
    # Stage 1: high shelf, +4 dB at the top.
    f0, gain_db, q = 1681.974450955533, 3.999843853973347, 0.7071752369554196
    amp = 10.0 ** (gain_db / 40.0)
    w0 = 2.0 * _m.pi * f0 / RATE
    alpha = _m.sin(w0) / (2.0 * q)
    root = 2.0 * _m.sqrt(amp) * alpha
    a0 = (amp + 1) - (amp - 1) * _m.cos(w0) + root
    out.append((
        [amp * ((amp + 1) + (amp - 1) * _m.cos(w0) + root) / a0,
         -2.0 * amp * ((amp - 1) + (amp + 1) * _m.cos(w0)) / a0,
         amp * ((amp + 1) + (amp - 1) * _m.cos(w0) - root) / a0],
        [1.0,
         2.0 * ((amp - 1) - (amp + 1) * _m.cos(w0)) / a0,
         ((amp + 1) - (amp - 1) * _m.cos(w0) - root) / a0],
    ))
    # Stage 2: the RLB high pass.
    f0, q = 38.13547087602444, 0.5003270373238773
    w0 = 2.0 * _m.pi * f0 / RATE
    alpha = _m.sin(w0) / (2.0 * q)
    a0 = 1.0 + alpha
    out.append((
        [(1.0 + _m.cos(w0)) / 2.0 / a0,
         -(1.0 + _m.cos(w0)) / a0,
         (1.0 + _m.cos(w0)) / 2.0 / a0],
        [1.0, -2.0 * _m.cos(w0) / a0, (1.0 - alpha) / a0],
    ))
    return out


K_WEIGHT = None


def loudness(samples):
    """The cut's loudness in LUFS, K-weighted, ungated, over the whole of it (or over
    MEASURE_MOST of a long bed). Silence comes back as -inf."""
    global K_WEIGHT
    if K_WEIGHT is None:
        K_WEIGHT = _k_weight()
    frames = len(samples) // 2
    if frames > MEASURE_MOST * RATE:
        at = (frames - int(MEASURE_MOST * RATE)) // 2
        samples = samples[at * 2:(at + int(MEASURE_MOST * RATE)) * 2]
    work = array.array("h", samples)
    for b, a in K_WEIGHT:
        _biquad(work, b, a)
    frames = len(work) // 2
    if frames == 0:
        return float("-inf")
    # Both channels count for one, as BS.1770 weights left and right.
    mean = sum((v / 32768.0) ** 2 for v in work) / frames
    if mean <= 0.0:
        return float("-inf")
    return -0.691 + 10.0 * math.log10(mean)


def peak_db(samples):
    loudest = max(abs(v) for v in samples) if samples else 0
    if loudest == 0:
        return float("-inf")
    return 20.0 * math.log10(loudest / 32768.0)


def level(samples, target):
    """Bring the cut to `target` LUFS, backed off so nothing goes over PEAK_CEIL.

    Returns the gain applied in decibels, which is what the name's `SOUNDS` entry should
    move by in the other direction to keep the mix it had."""
    was = loudness(samples)
    if was == float("-inf"):
        return 0.0
    gain = target - was
    room = PEAK_CEIL - peak_db(samples)
    if gain > room:
        gain = room
    scale = 10.0 ** (gain / 20.0)
    for i in range(len(samples)):
        samples[i] = max(-32768, min(32767, int(samples[i] * scale)))
    return gain


def from_peak(samples, end_s):
    loudest = max(range(len(samples)), key=lambda i: abs(samples[i])) // 2
    start = max(0.0, loudest / RATE - 0.003)
    return fade(cut(samples, start, start + end_s), 0.001, FADE_OUT)


def steps(samples, rel, most_s):
    env = envelope(samples, 0.01)
    peak = max(env)
    onsets = []
    low = True
    for i, e in enumerate(env):
        if low and e > peak * rel:
            onsets.append(i * 0.01)
            low = False
        elif e < peak * rel * 0.35:
            low = True
    out = []
    for k, at in enumerate(onsets):
        end = at + most_s
        if k + 1 < len(onsets):
            end = min(end, onsets[k + 1] - 0.02)
        if end - at < 0.08:
            continue
        out.append(fade(cut(samples, at - 0.015, end), FADE_IN, 0.06))
    # A footstep off a take this quiet is mostly room: the faint ones are left out. Bringing
    # the rest up is the loudness pass's job now, and it levels every step separately, so no
    # step drops out of the walk.
    loudest = max(max(abs(v) for v in step) for step in out)
    return [step for step in out if max(abs(v) for v in step) >= loudest * STEP_LEAST]


def loop(samples, start_s, len_s, cross_s=None):
    """len_s of sound whose last CROSSFADE seconds are blended into its first, so the
    end runs into the start without a click or a gap."""
    cross = CROSSFADE if cross_s is None else cross_s
    body = cut(samples, start_s + cross, start_s + cross + len_s)
    lead = cut(samples, start_s, start_s + cross)
    tail_at = len(body) - len(lead)
    frames = len(lead) // 2
    for f in range(frames):
        # Equal power: the two stretches are different noise, not the same signal.
        t = f / frames
        g_in = math.sin(t * math.pi / 2)
        g_out = math.cos(t * math.pi / 2)
        for c in (0, 1):
            v = body[tail_at + f * 2 + c] * g_out + lead[f * 2 + c] * g_in
            body[tail_at + f * 2 + c] = max(-32768, min(32767, int(v)))
    # The blended tail is where the loop ends; it hands over to the body's first frame,
    # which follows the lead in the recording.
    return body


def write_wav(name, samples):
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(samples.tobytes())
    return path


def write_ogg(name, samples):
    path = os.path.join(OUT, name + ".ogg")
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", str(RATE), "-ac", "2", "-i", "-",
         "-c:a", "libvorbis", "-q:a", "4", path],
        input=samples.tobytes(), check=True,
    )
    return path


def main():
    os.makedirs(OUT, exist_ok=True)
    cache = {}
    report = []
    for name, (source, how) in PLAN.items():
        if source not in cache:
            cache[source] = decode(os.path.join(SRC, source))
        samples = cache[source]
        kind = how[0]
        cuts = []
        if kind == "trim":
            cuts = [(name, trimmed(samples, how[1]), "wav")]
        elif kind == "span":
            out_s = how[3] if len(how) > 3 else FADE_OUT
            clip = cut(samples, how[1], how[2])
            if name in SMOOTH:
                clip = high_pass(clip, SMOOTH_HZ)
            cuts = [(name, fade(clip, SMOOTH_IN if name in SMOOTH else FADE_IN, out_s), "wav")]
        elif kind == "peak":
            cuts = [(name, from_peak(samples, how[1]), "wav")]
        elif kind == "steps":
            cuts = [("%s_%d" % (name, i + 1), s, "wav")
                    for i, s in enumerate(steps(samples, how[1], how[2]))]
        elif kind == "loop":
            bed = loop(samples, how[1], how[2], how[3] if len(how) > 3 else None)
            cuts = [(name, bed, "wav" if name in LOOP_WAV else "ogg")]
        else:
            sys.exit("unknown cut %s" % kind)

        target = BED_LUFS if name in BEDS else TARGET_LUFS
        for out_name, clip, how_write in cuts:
            was = loudness(clip)
            gain = level(clip, target)
            path = write_wav(out_name, clip) if how_write == "wav" else write_ogg(out_name, clip)
            report.append((out_name, path, len(clip) / 2.0 / RATE, was,
                           loudness(clip), peak_db(clip), gain))

    lines = ["%-16s %7s %9s %9s %8s %8s" % ("name", "secs", "was", "now", "peak", "gain")]
    for out_name, _path, secs, was, now, peak, gain in report:
        lines.append("%-16s %7.2f %9.1f %9.1f %8.1f %+8.1f" % (out_name, secs, was, now, peak, gain))
    # What each name's `SOUNDS` entry in sfx.gd should move by to keep the mix it had: the
    # file went up by `gain`, so the mix comes down by the same.
    lines.append("")
    lines.append("SOUNDS shift (keep today's mix):")
    for out_name, _path, _secs, _was, _now, _peak, gain in report:
        lines.append("  %-16s %+6.1f" % (out_name, -gain))
    text = chr(10).join(lines) + chr(10)
    with open("tools/last_sfx.log", "w", encoding="utf-8") as log:
        log.write(text)
    print(text)
    print("%d files, %.1f KB" % (
        len(report), sum(os.path.getsize(p) for _n, p, *_r in report) / 1024))


if __name__ == "__main__":
    main()
