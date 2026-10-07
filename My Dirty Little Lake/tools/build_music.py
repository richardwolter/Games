"""Build the game's music from the songs in art_source/Music.

    python tools/build_music.py        (from the project root; needs ffmpeg on PATH)

Writes `assets/music/`: each song as delivered, cut where the game stops it and with its
trailing silence taken off, and the songs heard indoors a second time as a radio through a
wall (the same file, squeezed into a band, a little drive, a slap of room, mono). Ogg Vorbis,
see SONG_Q / RADIO_Q.
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
# Every song has both copies since the record player (2026-09-28): the player may send any
# song to the lake or to the shed. `--only a,b` builds the named slugs alone.
PLAN = {
    "beatgucci": ("beatgucci (Zé)#3.mp3", 132.0, True, True),
    "save_me": ("Save ME #sketch.mp3", None, True, True),
    "goin": ("Goin (edit2)#2.2.mp3", None, True, True),
    "indie_boi": ("INDIE BOI #sketch.mp3", None, True, True),
    "habibs": ("Habibs 3 #4.2.mp3", None, True, True),
}

# Trailing silence under this is taken off the end.
SILENCE_DB = -50
## Ogg Vorbis quality: 5 is about 160 kbps, half the 320 kbps MP3 the songs used to ship as
## (2026-10-03, the pre-release size pass). The radio copy is mono and band-limited, so
## quality 0 (about 64 kbps) loses nothing it still has.
SONG_Q = "5"
RADIO_Q = "0"

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
    only = None
    if "--only" in sys.argv:
        only = set(sys.argv[sys.argv.index("--only") + 1].split(","))
    for slug, (name, cut, outdoors, radio) in PLAN.items():
        if only is not None and slug not in only:
            continue
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
            ffmpeg(["-i", src, "-af", chain, "-c:a", "libvorbis", "-q:a", SONG_Q,
                    "-map_metadata", "-1", os.path.join(OUT, slug + ".ogg")])
        if radio:
            ffmpeg(["-i", src, "-af", chain + "," + RADIO, "-c:a", "libvorbis",
                    "-q:a", RADIO_Q, "-map_metadata", "-1",
                    os.path.join(OUT, slug + "_radio.ogg")])
        print("built", slug)


if __name__ == "__main__":
    main()
