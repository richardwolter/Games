"""Minimal 8-bit RGBA PNG read and write, so the art tools need no dependencies.

Pillow is not installed in this project and is not worth adding for two
functions: everything here writes small, freshly generated images, and reading is
only ever done on files this project produced or on frames ffmpeg just wrote.

Both are deliberately strict — 8-bit RGBA, no interlacing — because a silent
misread of some other PNG flavour would show up as corrupt artwork rather than as
an error.
"""

import pathlib
import struct
import zlib


def read_png(path: pathlib.Path) -> tuple[int, int, bytearray]:
    """Decodes an 8-bit RGBA PNG to a flat byte array. No interlacing."""
    data = path.read_bytes()
    width, height, depth, colour = struct.unpack(">IIBB", data[16:26])
    if depth != 8 or colour != 6:
        raise ValueError("%s is not 8-bit RGBA" % path.name)

    raw = bytearray()
    at = 8
    while at < len(data):
        length = struct.unpack(">I", data[at:at + 4])[0]
        kind = data[at + 4:at + 8]
        if kind == b"IDAT":
            raw += data[at + 8:at + 8 + length]
        at += 12 + length
        if kind == b"IEND":
            break

    stream = zlib.decompress(bytes(raw))
    stride = width * 4
    out = bytearray(stride * height)
    for y in range(height):
        filt = stream[y * (stride + 1)]
        line = stream[y * (stride + 1) + 1:(y + 1) * (stride + 1)]
        row = y * stride
        for i in range(stride):
            value = line[i]
            left = out[row + i - 4] if i >= 4 else 0
            up = out[row - stride + i] if y > 0 else 0
            up_left = out[row - stride + i - 4] if y > 0 and i >= 4 else 0
            if filt == 1:
                value += left
            elif filt == 2:
                value += up
            elif filt == 3:
                value += (left + up) >> 1
            elif filt == 4:
                # Paeth: whichever of the three neighbours the gradient predicts.
                p = left + up - up_left
                pa, pb, pc = abs(p - left), abs(p - up), abs(p - up_left)
                value += left if pa <= pb and pa <= pc else (up if pb <= pc else up_left)
            out[row + i] = value & 0xFF
    return width, height, out


def write_png(path: pathlib.Path, width: int, height: int, pixels: bytearray) -> None:
    raw = bytearray()
    stride = width * 4
    for y in range(height):
        raw.append(0)  # filter: none. The image is small and this stays readable.
        raw += pixels[y * stride:(y + 1) * stride]

    def chunk(kind: bytes, body: bytes) -> bytes:
        return (struct.pack(">I", len(body)) + kind + body
                + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF))

    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )
