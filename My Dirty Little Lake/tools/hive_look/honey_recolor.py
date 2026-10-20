#!/usr/bin/env python
"""Honey a net that is already on a plate: recolour the captured plain net's rim, beads and their
shade, pixel for pixel, into a honey ramp (for tools/hive_look/honey_mockup.py).

OFFLINE MOCKUPS ONLY. The store stills are captures of the real game, so the net on them is the
shader's own drawing; repainting only its rim classes keeps every strand, catch piece and pixel
edge exactly where the game put them. The classes are told apart by colour (net_mesh.gdshader's
swatches, times the plate's day tint, which on the store stills is a near-white 0.98): the lead
beads' three greys are unique on the net, and the rim band is everything net-coloured within a
few screen px of a bead (the beads ride on the rim cord, every 9 world px).

`recolour(plate, box, ramp, ...)` works in place on the plate's screen pixels and returns the
masks it used, so the caller can hang drips off the beads it found.
"""
import numpy as np
from PIL import Image

CORD = (168, 124, 76)
CORD_LIT = (204, 162, 108)
CORD_BACK = (116, 80, 46)
SHADE = (44, 29, 17)
LEAD_DARK = (30, 32, 38)
LEAD_MID = (78, 82, 92)
LEAD_LIT = (138, 144, 156)

# NetShape's own ramps (scripts/net_shape.gd, 2026-10-16), for the comparison only.
GOLD = {"deep": (122, 76, 18), "low": (196, 136, 34), "mid": (240, 190, 64),
        "lit": (255, 226, 128), "pale": (255, 244, 196), "shade": (70, 40, 8)}
AMBER_GAME = {"deep": (104, 40, 8), "low": (160, 70, 14), "mid": (210, 108, 24),
              "lit": (242, 154, 52), "shade": (54, 20, 4)}


def dilate(m, r):
    """Square dilation by r px, numpy only."""
    out = m.copy()
    h, w = m.shape
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx == 0 and dy == 0:
                continue
            src = m[max(0, -dy):h - max(0, dy), max(0, -dx):w - max(0, dx)]
            out[max(0, dy):h - max(0, -dy), max(0, dx):w - max(0, -dx)] |= src
    return out


def _is(reg, col, tint, tol=3):
    tc = np.round(np.array(col[:3]) * np.array(tint)).astype(int)
    return np.abs(reg - tc).max(2) <= tol


def recolour(plate, box, ramp, tint=(0.98, 0.976, 0.974), band=3, soak=0, soak_ramp=None,
             keep=None):
    """Recolour the plain net inside `box` (x0, y0, x1, y1 screen px) of `plate` (RGBA, in place).

    ramp: {deep, low, mid, lit, shade} - beads lit/low/deep as the shader's lead_lit/mid/dark,
          the cord's lit row `lit`, the rest of the rim `mid`, the shade round them `shade`.
    band: screen px round a bead that count as the rim.
    soak: if > 0, cord strands within this many screen px of the rim (inside the net) are mixed
          towards soak_ramp['mid'] by how near they are (the gold's creep, in honey).
    keep: optional bool mask (plate-sized) of pixels never to touch.
    Returns a dict of plate-sized masks: bead, band, lit_bead (the beads' lit pixels)."""
    a = np.array(plate).astype(int)
    x0, y0, x1, y1 = box
    reg = a[y0:y1, x0:x1, :3]
    m = {k: _is(reg, c, tint) for k, c in (("cord", CORD), ("lit", CORD_LIT), ("back", CORD_BACK),
                                            ("shade", SHADE), ("ld", LEAD_DARK), ("lm", LEAD_MID),
                                            ("ll", LEAD_LIT))}
    bead = m["ld"] | m["lm"] | m["ll"]
    # Lone grey pixels are catch (a can, a pot), not beads: a bead is a clump of lead greys.
    clump = dilate(bead, 1)
    n = np.zeros(bead.shape, int)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            n += np.roll(np.roll(bead, dy, 0), dx, 1)
    bead &= n >= 3
    netc = m["cord"] | m["lit"] | m["back"] | m["shade"] | bead
    near = dilate(bead, band) & netc
    out = reg.copy()

    def put(mask, col):
        out[mask] = np.round(np.array(col[:3]) * np.array(tint)).astype(int)
    if soak > 0 and soak_ramp is not None:
        # distance (in dilation steps) from the rim band, cord only
        dist = np.full(bead.shape, 999)
        grown = near.copy()
        for d in range(1, soak + 1):
            nxt = dilate(grown, 1)
            dist[nxt & ~grown] = d
            grown = nxt
        st = m["cord"] & ~near & (dist <= soak)
        g = 1.0 - dist[st] / float(soak + 1)
        g = np.ceil(g * 3) / 3.0           # three hard steps, no smooth gradient
        base = np.array(CORD) * np.array(tint)
        tgt = np.array(soak_ramp["mid"][:3]) * np.array(tint)
        out[st] = np.round(base * (1 - g[:, None]) + tgt * g[:, None]).astype(int)
    put(near & m["cord"], ramp["mid"])
    put(near & m["lit"], ramp["lit"])
    put(near & m["back"], ramp["low"])
    put(near & m["shade"], ramp["shade"])
    put(bead & m["ll"], ramp["lit"])
    put(bead & m["lm"], ramp["low"])
    put(bead & m["ld"], ramp["deep"])
    if keep is not None:
        k = keep[y0:y1, x0:x1]
        out[k] = reg[k]
    a[y0:y1, x0:x1, :3] = out
    plate.paste(Image.fromarray(a.astype(np.uint8), "RGBA"))

    def full(mm):
        f = np.zeros((a.shape[0], a.shape[1]), bool)
        f[y0:y1, x0:x1] = mm
        return f
    return {"bead": full(bead), "band": full(near), "lit_bead": full(bead & m["ll"]),
            "net": full(netc)}
