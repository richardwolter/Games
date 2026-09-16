"""Build the game's music from the songs in art_source/Music.

    python tools/build_music.py        (from the project root; needs ffmpeg on PATH)

Writes `assets/music/`: each song as delivered, cut where the game stops it and with its
trailing silence taken off, and the songs heard indoors a second time as a radio through a
wall (the same file, squeezed into a band, a little drive, a slap of room, mono, 64 kbps).
Reimport afterwards (`<exe> --path . --headless --import`).

Why cut the end in the file rather than at runtime: the station (`scripts/music_station.gd`)
fades every song out over its own last seconds, so a song's length has to be where it ends.
beatgucci stops at 2:12 by decision; the fade is not baked, the station makes it.

The radio recipe was lost with the first bake (`music_goin_radio.mp3`); this one was matched
to that file by spectrum and loudness (-20.7 LUFS on Goin), so the shed sounds as it did.
"""

import os
import subprocess
import sys

SOURCE = "art_source/Music"
OUT = "assets/music"

# slug: (source file, cut at seconds or None, outdoors copy, radio copy)
PLAN = {
    "beatgucci": ("beatgucci (Zé)#3.mp3", 132.0, True, True),
    "save_me": ("Save ME #sketch.mp3", None, True, True),
    "goin": ("Goin (edit2)#2.2.mp3", None, True, True),
    "indie_boi": ("INDIE BOI #sketch.mp3", None, False, True),
    "habibs": ("Habibs 2#1.mp3", None, True, False),
}

# Trailing silence under this is taken off the end.
SILENCE_DB = -50

RADIO = ",".join([
    "pan=mono|c0=0.5*c0+0.5*c1",
    "highpass=f=190:poles=2", "highpass=f=190:poles=2",
    "lowpass=f=7200:poles=2", "lowpass=f=7200:poles=2",
    "volume=6dB", "asoftclip=type=tanh",
    "aecho=0.8:0.6:35:0.2",
    "volume=-2dB",
])


def ffmpeg(args):
    subprocess.run(["ffmpeg", "-v", "error", "-y"] + args, check=True)


def main():
    if not os.path.isdir(SOURCE):
        sys.exit("run from the project root: no %s" % SOURCE)
    os.makedirs(OUT, exist_ok=True)
    for slug, (name, cut, outdoors, radio) in PLAN.items():
        src = os.path.join(SOURCE, name)
        trim = []
        if cut is not None:
            trim.append("atrim=0:%s" % cut)
        trim += [
            "areverse",
            "silenceremove=start_periods=1:start_threshold=%ddB" % SILENCE_DB,
            "areverse",
        ]
        chain = ",".join(trim)
        if outdoors:
            ffmpeg(["-i", src, "-af", chain, "-c:a", "libmp3lame", "-b:a", "320k",
                    "-map_metadata", "-1", os.path.join(OUT, slug + ".mp3")])
        if radio:
            ffmpeg(["-i", src, "-af", chain + "," + RADIO, "-c:a", "libmp3lame",
                    "-b:a", "64k", "-map_metadata", "-1",
                    os.path.join(OUT, slug + "_radio.mp3")])
        print("built", slug)


if __name__ == "__main__":
    main()
