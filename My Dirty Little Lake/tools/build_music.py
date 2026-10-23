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

The radio recipe was lost with the first bake (`music_goin_radio.mp3`); the first one here was
matched to that file by spectrum and loudness (-20.7 LUFS on Goin). Made subtler on 2026-10-23
(Richard's QA run: "radio effect can be a little more subtle"): a wider band, a little stereo
kept, less drive, a lighter slap, and about 5 dB under the open song on Goin (-16 LUFS) rather
than 9.5, so going in and out of it is not a drop. `--radio` builds the radio copies alone.
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
    # Loobas, a friend of Richard's (2026-10-12), not Nuven. WAVs as delivered.
    "movimento_tranquilo": ("Movimento Tranquilo.wav", None, True, True),
    "tudo_que_eu_fiz": ("Tudo Que Eu Fiz.wav", None, True, True),
}

# Trailing silence under this is taken off the end.
SILENCE_DB = -50
## Ogg Vorbis quality: 5 is about 160 kbps, half the 320 kbps MP3 the songs used to ship as
## (2026-10-03, the pre-release size pass). The radio copy is band-limited; quality 2 (about
## 96 kbps) since it kept some stereo and a wider band (2026-10-23).
SONG_Q = "5"
RADIO_Q = "2"

RADIO = ",".join([
    "pan=stereo|c0=0.75*c0+0.25*c1|c1=0.25*c0+0.75*c1",
    "highpass=f=120:poles=2",
    "lowpass=f=9500:poles=2",
    "volume=3dB", "asoftclip=type=tanh",
    "aecho=0.8:0.5:30:0.12",
    "volume=2.5dB",
])


def ffmpeg(args):
    subprocess.run(["ffmpeg", "-v", "error", "-y"] + args, check=True)


def main():
    if not os.path.isdir(SOURCE):
        sys.exit("run from the project root: no %s" % SOURCE)
    os.makedirs(OUT, exist_ok=True)
    only = None
    radio_only = "--radio" in sys.argv
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
        if outdoors and not radio_only:
            ffmpeg(["-i", src, "-af", chain, "-c:a", "libvorbis", "-q:a", SONG_Q,
                    "-map_metadata", "-1", os.path.join(OUT, slug + ".ogg")])
        if radio:
            ffmpeg(["-i", src, "-af", chain + "," + RADIO, "-c:a", "libvorbis",
                    "-q:a", RADIO_Q, "-map_metadata", "-1",
                    os.path.join(OUT, slug + "_radio.ogg")])
        print("built", slug)


if __name__ == "__main__":
    main()
