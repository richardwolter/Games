#!/usr/bin/env python
"""Bake Spotify's official icon into the size the credits board draws it at.

    <psd-extract venv python> tools/build_spotify_icon.py

Source is Spotify's own download (developer.spotify.com/documentation/design,
"Icon" zip), unpacked into `art_source/spotify/`. The mark itself is never
redrawn, recoloured or distorted -- their brand guidelines forbid it. All this
does is trim the transparent margin the download ships with, square the result
so the circle cannot go oval, and resample it down to `SIZE` with Lanczos, so
the board is scaling a 96 px picture rather than a 939 px one.

The board draws it with a linear filter (it is a smooth vector mark, not pixel
art), which is why this is not baked at an art-pixel multiple.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art_source" / "spotify" / "Spotify_Primary_Logo_RGB_Green.png"
OUT = ROOT / "assets" / "ui" / "spotify_icon.png"
SIZE = 96


def main() -> None:
    im = Image.open(SOURCE).convert("RGBA")
    im = im.crop(im.getbbox())
    side = max(im.size)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
    square.resize((SIZE, SIZE), Image.LANCZOS).save(OUT)
    print(f"{OUT.relative_to(ROOT)} {SIZE}x{SIZE} from {im.width}x{im.height}")


if __name__ == "__main__":
    main()
