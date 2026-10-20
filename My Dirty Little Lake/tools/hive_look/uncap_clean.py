#!/usr/bin/env python
"""The uncap plate with today's bucket, gutter, knife handle, wax curl, bee and the backdrop's
dog taken off, everything else (the backdrop, the rest, the frame, the curtains, the wax sheet
on the blade, the hint card) left exactly as captured. Imported by uncap_mockup.py.

Works on the art grid (640 x 360, 3 screen px an art px): a removed art cell is refilled with
the backdrop from the same art row a fixed distance along (the backdrop is horizontal bands:
sky, treeline, lake, sand, lawn), then the game's own rest and frame pieces are laid back over
it where they stand. Only removed cells are written back to the full-size plate, so the UI
(drawn finer than the art grid) is never touched.
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import look  # noqa: E402

G = look.ROOM_GRAIN
W, H = look.ROOM_GRID

# Where things stand on the uncap plate, art px (matched pixel for pixel, see uncap_mockup).
REST_AT = (134, 37)            # the rest piece's top left (frame_tl anchor at FRAME_AT)
FRAME_AT = (157, 38)           # hive_step_uncap.FRAME_AT
FRAME_SIZE = (326, 182)
CUT_ROW = 138                  # frame_capped from this art row down, frame_open above
G0 = (145.0, 228.0)            # the gutter's high end (FRAME_AT + (0, 182) + GUTTER_IN)
G1 = (499.0, 260.0)            # its low end (+ GUTTER_OUT)
CURTAIN_X = [70, 112, 150, 186, 224, 262]     # hive_step_uncap.CURTAINS, from the frame's left

# UI boxes on the art grid that are never a source and never written.
UI = [(195, 314, 446, 351),    # the hint card
      (270, 0, 370, 40),       # the step plaque
      (603, 3, 636, 25)]       # the close cross


def gut(x):
    return G0[1] + (x - G0[0]) * (G1[1] - G0[1]) / (G1[0] - G0[0])


def _in_ui(x, y):
    return any(a <= x < c and b <= y < d for a, b, c, d in UI)


def _piece_alpha(name, at):
    im, _ = look.room_piece(name)
    a = np.zeros((H, W), bool)
    p = np.array(im)[..., 3] > 0
    x0, y0 = at
    h, w = p.shape
    ys, xs = slice(max(0, y0), min(H, y0 + h)), slice(max(0, x0), min(W, x0 + w))
    a[ys, xs] = p[ys.start - y0:ys.stop - y0, xs.start - x0:xs.stop - x0]
    return a, im


HONEY = {look.bh.HONEY_DEEP[:3], look.bh.HONEY_MID[:3], look.bh.HONEY[:3],
         look.bh.HONEY_LIGHT[:3], look.bh.HONEY_SHINE[:3], (255, 255, 255)}


def removal_mask(art):
    """The art cells today's bucket, gutter (straps, honey, lip, stream), knife handle, wax curl
    and the backdrop's dog and its shadow stand on."""
    m = np.zeros((H, W), bool)
    # the knife's handle and ferrule, past the blade
    m[124:142, 461:509] = True
    # the wax curl at the blade's tip (the sheet on the blade is kept)
    m[112:151, 154:181] = True
    # the gutter, its straps up to the frame's foot, the honey in it, the dog behind it
    for x in range(132, 514):
        m[216:int(gut(x)) + 12, x] = True
    # the stream off the lip and the old bucket
    m[255:292, 494:514] = True
    m[284:H, 449:569] = True
    # the dog's shadow on the lawn under the gutter
    m[254:274, 176:350] = True
    # keep the curtains: honey in the curtain columns above the old gutter's back wall, joined
    # to the curtain coming off the frame (so stray drops of the old gutter's honey go)
    keep = np.zeros((H, W), bool)
    for cx in CURTAIN_X:
        x0 = FRAME_AT[0] + cx
        for y in range(214, H):
            for x in range(x0 - 14, x0 + 15):
                if y >= int(gut(x)) - 9 or tuple(art[y, x, :3]) not in HONEY:
                    continue
                if y == 214 or keep[y - 1, x - 1:x + 2].any():
                    keep[y, x] = True
    m &= ~keep
    for y in range(H):
        for x in range(W):
            if m[y, x] and _in_ui(x, y):
                m[y, x] = False
    return m, keep


def clean():
    """The cleaned plate (full size RGBA), its art-grid copy, the removed cells and the curtain
    cells kept under the frame's foot."""
    plate = look.plate("uncap")
    look.clean_bees(plate, (360, 330, 430, 370))
    art = np.array(look.downsample(plate)).copy()
    rem, curtains = removal_mask(art)
    rest_a, rest_im = _piece_alpha("rest", REST_AT)
    fo_a, fo_im = _piece_alpha("frame_open", FRAME_AT)
    fc_a, fc_im = _piece_alpha("frame_capped", FRAME_AT)
    fore = rest_a | fo_a | fc_a
    src_ok = ~rem & ~fore
    for y in range(H):
        for x in range(W):
            if _in_ui(x, y):
                src_ok[y, x] = False
    # the honey curtains and anything orange under the frame are not backdrop
    for y in range(205, 280):
        for x in range(130, 520):
            if tuple(art[y, x, :3]) in HONEY:
                src_ok[y, x] = False
    # refill the backdrop, a run of removed cells at a time from one offset
    offsets = sorted({d for k in range(1, 110) for d in (-6 * k, 6 * k)}, key=abs)
    for y in range(H):
        x = 0
        while x < W:
            if not rem[y, x]:
                x += 1
                continue
            x1 = x
            while x1 < W and rem[y, x1]:
                x1 += 1
            # split long runs so each chunk can find a clean stretch
            for c0 in range(x, x1, 48):
                c1 = min(c0 + 48, x1)
                done = False
                for d in offsets:
                    s0, s1 = c0 + d, c1 + d
                    if s0 < 0 or s1 > W:
                        continue
                    if src_ok[y, s0:s1].all():
                        art[y, c0:c1] = art[y, s0:s1]
                        done = True
                        break
                if not done:
                    for cx in range(c0, c1):
                        for d in offsets:
                            sx = cx + d
                            if 0 <= sx < W and src_ok[y, sx]:
                                art[y, cx] = art[y, sx]
                                break
            x = x1
    # the rest and the frame back over the refilled cells
    rest = np.array(rest_im)
    fo = np.array(fo_im)
    fc = np.array(fc_im)
    for y in range(H):
        for x in range(W):
            if not rem[y, x]:
                continue
            ry, rx = y - REST_AT[1], x - REST_AT[0]
            if 0 <= ry < rest.shape[0] and 0 <= rx < rest.shape[1] and rest[ry, rx, 3]:
                art[y, x] = rest[ry, rx]
            fy, fx = y - FRAME_AT[1], x - FRAME_AT[0]
            src = fc if y >= CUT_ROW else fo
            if 0 <= fy < src.shape[0] and 0 <= fx < src.shape[1] and src[fy, fx, 3]:
                art[y, x] = src[fy, fx]
    # write the removed cells back to the full plate
    big = np.array(plate)
    for y in range(H):
        for x in range(W):
            if rem[y, x]:
                big[y * G:(y + 1) * G, x * G:(x + 1) * G] = art[y, x]
    return Image.fromarray(big), art, rem, curtains


if __name__ == "__main__":
    im, art, rem, _ = clean()
    os.makedirs(os.path.join(look.HERE, "scratch"), exist_ok=True)
    im.save(os.path.join(look.HERE, "scratch", "uncap_clean.png"))
    print("removed cells:", int(rem.sum()))
