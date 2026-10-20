#!/usr/bin/env python
"""The cast net drawn by the game's own rule, offline: a port of shaders/net_mesh.gdshader's
`cls` and colouring for a net lying open on the water (haul 0, no flutter), at one pixel per
world px. For the honey sheet (tools/hive_look/honey_mockup.py) so the plain, lucky and honeyed
nets can be laid side by side with nothing but the rim's colours different.

OFFLINE MOCKUPS ONLY. Nothing here is read by the game. Numbers are NetShape's (2026-10-16):
CELL 12, DOME 0.16 (DOME_MOST 8), BEAD_EVERY 9, RIM_OUT 6, MIN_GAP 3.5, the cord, lead and gold
swatches; the honey ramps are passed in, so the sheet can try more than one.
"""
import math

import numpy as np
from PIL import Image

TAU = math.tau
CELL = 12.0
DOME = 0.16
DOME_MOST = 8.0
BEAD_EVERY = 9.0
RIM_OUT = 6.0
MIN_GAP = 3.5
FADE_CELLS = 2.2

CORD = (168, 124, 76)
CORD_LIT = (204, 162, 108)
CORD_BACK = (116, 80, 46)
SHADE = (44, 29, 17)
LEAD_DARK = (30, 32, 38)
LEAD_MID = (78, 82, 92)
LEAD_LIT = (138, 144, 156)
GOLD = {"deep": (122, 76, 18), "low": (196, 136, 34), "mid": (240, 190, 64),
        "lit": (255, 226, 128), "pale": (255, 244, 196), "shade": (70, 40, 8)}

NONE, STRAND, RIM, BEAD, RING, KNOT = range(6)


def rim_spokes(open_half):
    return max(32, int(round(TAU * open_half / CELL / 32.0)) * 32)


def levels(open_half):
    n = rim_spokes(open_half)
    hi, lvl = 1.0, 0
    while n >= 16 and hi * 0.5 * open_half >= CELL * 1.5:
        n //= 2
        hi *= 0.5
        lvl += 1
    return lvl


def beads(open_half):
    return max(8, int(round(TAU * open_half / BEAD_EVERY / 4.0)) * 4)


def _axis(gx, gy):
    return np.maximum(np.maximum(np.abs(gx), np.abs(gy)), 1e-6)


def _cls(rho, th, grx, gry, gtx, gty, p):
    """The shader's `cls`, vectorised: what each pixel is."""
    out = np.full(rho.shape, NONE, np.int8)
    done = np.zeros(rho.shape, bool)
    ax_r = _axis(grx, gry)
    across = (rho - 1.0) / ax_r
    near = np.abs(across) < 2.5
    bc = p["bead_count"]
    gbx, gby = gtx * bc / TAU, gty * bc / TAU
    t = th * bc / TAU
    along = np.abs(t - np.round(t)) / np.maximum(np.hypot(gbx, gby), 1e-6)
    bead = near & (along < 1.5) & (across > -0.5) & (across < 1.5)
    out[bead] = BEAD
    done |= bead
    ring = near & ~done & (along < 2.5) & (across > -1.5)
    out[ring] = RING
    done |= ring
    rim = near & ~done & (np.abs(across) < p["rim_half"])
    out[rim] = RIM
    done |= rim
    outside = (rho > 1.0) | (rho < 0.0)
    done |= outside
    knot = ~done & (rho / ax_r < 2.0)
    out[knot] = KNOT
    done |= knot
    lvl = np.clip(np.floor(-np.log2(np.maximum(rho, 1e-4))), 0.0, p["max_lvl"])
    tuck = ~done & (((lvl > 0.5) & (np.abs(rho - np.exp2(-lvl)) / ax_r < 0.5))
                    | ((lvl < p["max_lvl"] - 0.5) & (np.abs(rho - np.exp2(-lvl - 1.0)) / ax_r < 0.5)))
    out[tuck] = STRAND
    done |= tuck
    k = p["n_rim"] / np.exp2(lvl) / TAU
    rc = p["radial_cells"]
    for sgn in (1.0, -1.0):
        f = th * k + sgn * rho * rc
        gx = gtx * k + sgn * grx * rc
        gy = gty * k + sgn * gry * rc
        gap = 1.0 / np.maximum(np.hypot(gx, gy), 1e-6)
        every = np.ones(rho.shape)
        every[gap < MIN_GAP] = 2.0
        every[gap * 2.0 < MIN_GAP] = 4.0
        every[gap * 4.0 < MIN_GAP] = 8.0
        idx = np.round(f)
        hit = ~done & (np.mod(idx, every) < 0.5) & (np.abs(f - idx) / _axis(gx, gy) < 0.5)
        out[hit] = STRAND
        done |= hit
    return out


def _inverse(X, Y, w, h):
    """(rho, theta) of the lying net at local point (X, Y): plane (w rho cos, w rho sin),
    drawn at (x, y / 2 - z), z = h (1 - rho)^1.4."""
    z = np.zeros_like(X)
    for _ in range(40):
        py = 2.0 * (Y + z)
        rho = np.hypot(X, py) / w
        z = h * np.power(np.maximum(1.0 - rho, 0.0), 1.4)
    th = np.mod(np.arctan2(py, X), TAU)
    return rho, th


def render(w, mode="plain", ramp=None, rim_half=None, tint=(1.0, 1.0, 1.0)):
    """The lying net, half-width `w` world px, at 1x: (RGBA image, (ox, oy)) where (ox, oy) is
    the mouth's middle in the image. mode: 'plain', 'gold' (lucky, with the gold creeping in
    from the rim), or 'ramp' (honey: rim and beads in `ramp`, a dict deep/low/mid/lit/shade,
    the mesh tan). `tint` is the day's modulate measured off the plate."""
    h = min(w * DOME, DOME_MOST)
    p = {"bead_count": float(beads(w)), "n_rim": float(rim_spokes(w)), "max_lvl": float(levels(w)),
         "radial_cells": w / CELL,
         "rim_half": rim_half if rim_half is not None else (1.5 if mode in ("gold", "ramp") else 1.0)}
    pad = 10
    W = int(2 * w + 2 * pad)
    H = int(w + h + 2 * pad)
    ox, oy = W // 2, int(h + pad + w / 2.0)
    ys, xs = np.mgrid[0:H, 0:W].astype(float)
    X = xs + 0.5 - ox
    Y = ys + 0.5 - oy
    rho, th = _inverse(X, Y, w, h)
    # d(rho, theta)/d(local), one px central differences, theta unwrapped
    def grad(a, wrap):
        gy, gx = np.gradient(a)
        if wrap:
            dx = np.diff(a, axis=1, append=a[:, -1:])
            dy = np.diff(a, axis=0, append=a[-1:, :])
            dx = (dx + math.pi) % TAU - math.pi
            dy = (dy + math.pi) % TAU - math.pi
            gx, gy = dx, dy
        return gx, gy
    grx, gry = grad(rho, False)
    gtx, gty = grad(th, True)
    c = _cls(rho, th, grx, gry, gtx, gty, p)
    up_rho, up_th = rho - gry, th - gty
    dn_rho, dn_th = rho + gry, th + gty
    above = _cls(up_rho, np.mod(up_th, TAU), grx, gry, gtx, gty, p)
    below = _cls(dn_rho, np.mod(dn_th, TAU), grx, gry, gtx, gty, p)
    img = np.zeros((H, W, 4), np.float64)

    def put(mask, col):
        img[mask, 0], img[mask, 1], img[mask, 2], img[mask, 3] = col[0], col[1], col[2], 255

    gold = mode == "gold"
    sweet = mode == "ramp"
    r = ramp or {}
    # strands (the gold creeps in from the rim on a lucky net)
    st = c == STRAND
    put(st, CORD)
    if gold:
        g = 1.0 - (1.0 - rho) * p["radial_cells"] / FADE_CELLS
        m = st & (g > 0)
        a = np.clip(g * 0.95, 0, 1)[m][:, None]
        img[m, :3] = np.array(CORD) * (1 - a) + np.array(GOLD["mid"]) * a
    top = ~np.isin(above, (RIM, BEAD, RING))
    rimm = c == RIM
    if gold:
        put(rimm & top, GOLD["lit"]); put(rimm & ~top, GOLD["mid"])
    elif sweet:
        put(rimm & top, r["lit"]); put(rimm & ~top, r["mid"])
    else:
        put(rimm & top, CORD_LIT); put(rimm & ~top, CORD)
    put(c == KNOT, CORD_LIT)
    bd = c == BEAD
    b_up = bd & (above == RING)
    b_dn = bd & (below == RING) & ~b_up
    b_mid = bd & ~b_up & ~b_dn
    if gold:
        put(b_mid, GOLD["low"]); put(b_up, GOLD["lit"]); put(b_dn, GOLD["deep"])
    elif sweet:
        put(b_mid, r["low"]); put(b_up, r["lit"]); put(b_dn, r["deep"])
    else:
        put(b_mid, LEAD_MID); put(b_up, LEAD_LIT); put(b_dn, LEAD_DARK)
    rg = c == RING
    put(rg, GOLD["shade"] if gold else (r["shade"] if sweet else SHADE))
    rest = c == NONE
    put(rest & np.isin(above, (STRAND, KNOT)), SHADE)
    put(rest & (above == RIM), GOLD["shade"] if gold else (r["shade"] if sweet else SHADE))
    img[..., 0] *= tint[0]
    img[..., 1] *= tint[1]
    img[..., 2] *= tint[2]
    out = Image.fromarray(np.clip(np.round(img), 0, 255).astype(np.uint8), "RGBA")
    return out, (ox, oy), {"rho": rho, "theta": th, "cls": c, "h": h, "p": p}


def rim_point(w, theta):
    """Where the rim is drawn at bearing theta, relative to the mouth's middle (lying net)."""
    return (w * math.cos(theta), w * math.sin(theta) * 0.5)
