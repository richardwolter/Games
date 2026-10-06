"""Bake the lake's fish: six freshwater species at sixteen headings, three tail-wag frames
each, and each heading's flat shadow.

Offline, from the project root:
  PYTHONPATH=<psd-extract venv site-packages> python tools/build_fish.py
then reimport (`<exe> --path . --headless --import`).

Writes assets/fish.png, assets/fish.json and a contact sheet, tools/last_fish_sheet.png.

The look was picked off tools/lakebed_mockup.py (2026-09-30, Richard: "big fish looks too
blocky... add a bit of color variety"). A fish is a run of elliptic sections, fatter towards
the head, a forked tail standing up, a low dorsal and two pectorals. Every surface point is
laid on the plane at the heading, lifted by its height, projected to the game's 2:1 view
through a depth buffer, and lit by its normal from the upper left; the back a step darker,
each species' pattern on top, ringed in its ramp's darkest step, an eye on the near side.
The shadow is the same body's footprint on the plane, flat. Colours are the fish's own; the
game mixes them towards the water by depth (shaders/fish.gdshader).

Every cell is CELL wide and tall with the body's middle at its middle, so the game draws a
frame by its index and needs no per-frame anchor.
"""
import json, math, os
from PIL import Image

OUT_PNG = os.path.join("assets", "fish.png")
OUT_JSON = os.path.join("assets", "fish.json")
SHEET_PNG = os.path.join("tools", "last_fish_sheet.png")
HEADINGS = 16
WAGS = (-1.0, 0.0, 1.0)
CELL = (48, 40)


def c(r, g, b): return (int(r * 255 + .5), int(g * 255 + .5), int(b * 255 + .5))
def ramp5(*cols): return [c(*k) for k in cols]
def step(ramp, i): return ramp[int(max(0, min(4, i)))]
def lerp(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t + .5) for i in range(3))


FIN_RED = ramp5((.3, .08, .04), (.55, .16, .07), (.8, .32, .12), (.9, .5, .24), (.96, .72, .45))
# name: length, width, height, tail, body ramp, fin ramp, pattern (all in art pixels)
SPECIES = {
    "minnow": (10, 2.8, 3.4, 3.0, ramp5((.14, .17, .13), (.3, .34, .24), (.5, .53, .38), (.7, .7, .55), (.88, .87, .76)), None, "stripe"),
    "roach": (13, 3.2, 4.6, 3.4, ramp5((.1, .14, .2), (.24, .32, .4), (.48, .56, .62), (.72, .77, .8), (.9, .92, .92)), FIN_RED, None),
    "perch": (14, 3.6, 5.0, 3.4, ramp5((.1, .16, .08), (.24, .34, .14), (.45, .52, .2), (.66, .68, .32), (.85, .82, .5)), FIN_RED, "bars"),
    "rudd": (13, 3.2, 4.8, 3.4, ramp5((.2, .14, .05), (.42, .3, .1), (.66, .5, .18), (.84, .7, .32), (.95, .87, .55)), FIN_RED, None),
    "tench": (17, 4.4, 5.2, 4.0, ramp5((.08, .12, .06), (.18, .26, .12), (.3, .4, .18), (.46, .54, .28), (.62, .68, .42)), None, None),
    "carp": (21, 5.6, 6.8, 5.0, ramp5((.18, .11, .06), (.38, .24, .12), (.58, .4, .2), (.75, .58, .32), (.9, .78, .52)), None, "scales"),
}
LIGHT = (-.45, -.35, .82)          # from the upper left and above, in plane coordinates
WAG = .32                          # how far the tail swings at the end of a beat, in radians


def _norm(v):
    m = math.sqrt(sum(k * k for k in v)) or 1
    return tuple(k / m for k in v)


def frange(a, b, s):
    v = a
    while v <= b + 1e-9:
        yield v; v += s


def fish_render(sp, heading, wag):
    """(pixels, shadow): pixels {(x, y): colour}, shadow a set, both about the body's middle."""
    L, Wd, Hh, F, body, fin, pat = SPECIES[sp]
    fin = fin or body
    ca, sa = math.cos(heading), math.sin(heading)
    zb, flat = {}, set()

    def bend(t):
        """How far the body is swung sideways at `t` (-1 tail .. 1 head)."""
        return math.sin(wag * WAG) * max(0.0, -t + .1) ** 2 * L * .32

    def put(x, y, z, n, part, t):
        X, Y = x * ca - y * sa, x * sa + y * ca
        key = (round(X), round(Y * .5 - z * .8))
        dep = Y * .87 + z * .5
        if key not in zb or dep > zb[key][0]:
            n = _norm(n)
            nx, ny = n[0] * ca - n[1] * sa, n[0] * sa + n[1] * ca
            lit = nx * LIGHT[0] + ny * LIGHT[1] + n[2] * LIGHT[2]
            zb[key] = (dep, lit, part, t, n[2])
        if part in ("body", "pec"): flat.add((round(X), round(Y * .5)))

    def prof(t): return math.sqrt(max(0, 1 - t * t)) ** .9 * (.62 + .38 * (t + 1) / 2)
    for t in frange(-1, 1, .35 / L):
        xf = t * L / 2
        w, h = Wd / 2 * prof(t), Hh / 2 * prof(t)
        for a in frange(0, 2 * math.pi, .12):
            put(xf, w * math.cos(a) + bend(t), h * math.sin(a),
                (0, math.cos(a) / max(w, .3), math.sin(a) / max(h, .3)), "body", t)
    for u in frange(0, 1, .06):                                  # the tail, standing up, forked
        half = Hh * (.12 + .3 * u)
        notch = max(0, u - .5) * 1.4
        for v in frange(-1, 1, .08):
            if abs(v) < notch: continue
            put(-L / 2 - u * F, v * half * .35 + bend(-1 - u * .6), v * half, (0, .7, .7), "fin", -1)
    x0, x1 = -.15 * L, .2 * L                                    # the dorsal, taller at its front
    for x in frange(x0, x1, .3):
        t = x / (L / 2)
        top = Hh / 2 * prof(t)
        rise = Hh * .22 * (x - x0) / (x1 - x0)
        for z in frange(top, top + rise, .3):
            put(x, bend(t), z, (0, .5, .9), "fin", t)
    for s in (-1, 1):                                            # pectorals
        for x in frange(.08 * L, .26 * L, .3):
            t = x / (L / 2)
            w = Wd / 2 * prof(t)
            for k in frange(0, Wd * .5, .3):
                put(x - k * .6, s * (w + k), -Hh * .1, (0, 0, 1), "pec", t)
    px = {}
    for key, (dep, lit, part, t, nz) in zb.items():
        if part == "body":
            i = 2 + round(lit * 2.1)
            if nz > .6: i -= 1
            if pat == "bars" and -.6 < t < .6 and math.sin(t * math.pi * 3.5) > .55 and nz > -.3: i -= 1
            if pat == "stripe" and abs(nz) < .22: i -= 1
            if pat == "scales" and i == 3 and (key[0] + 2 * key[1]) % 3 == 0: i -= 1
            px[key] = step(body, i)
        else:
            px[key] = step(fin, 2 + round(lit * 1.5))
    for key in list(px):
        if any((key[0] + dx, key[1] + dy) not in zb for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            px[key] = body[0] if zb[key][2] == "body" else lerp(fin[0], body[0], .5)
    ex, ey = L * .36, Wd * .32                                   # the eye, on the side nearer us
    best = None
    for s in (-1, 1):
        X, Y = ex * ca - s * ey * sa, ex * sa + s * ey * ca
        z = Hh * .12
        if best is None or Y * .87 + z * .5 > best[0]:
            best = (Y * .87 + z * .5, (round(X), round(Y * .5 - z * .8)))
    if best[1] in px and zb[best[1]][2] == "body": px[best[1]] = (14, 16, 18)
    return px, flat


def main():
    names = list(SPECIES)
    per = HEADINGS * (len(WAGS) + 1)                  # the wag frames, then the shadow
    cols = HEADINGS
    rows = len(names) * (len(WAGS) + 1)
    sheet = Image.new("RGBA", (cols * CELL[0], rows * CELL[1]), (0, 0, 0, 0))
    clipped = 0
    for si, sp in enumerate(names):
        for h in range(HEADINGS):
            a = 2 * math.pi * h / HEADINGS
            for wi, wag in enumerate(WAGS):
                px, flat = fish_render(sp, a, wag)
                ox, oy = h * CELL[0] + CELL[0] // 2, (si * (len(WAGS) + 1) + wi) * CELL[1] + CELL[1] // 2
                for (x, y), col in px.items():
                    if abs(x) < CELL[0] // 2 and abs(y) < CELL[1] // 2:
                        sheet.putpixel((ox + x, oy + y), col + (255,))
                    else: clipped += 1
                if wag == 0.0:
                    sy = (si * (len(WAGS) + 1) + len(WAGS)) * CELL[1] + CELL[1] // 2
                    for (x, y) in flat:
                        if abs(x) < CELL[0] // 2 and abs(y) < CELL[1] // 2:
                            sheet.putpixel((ox + x, sy + y), (255, 255, 255, 255))
    sheet.save(OUT_PNG, optimize=True)
    with open(OUT_JSON, "w", encoding="utf-8", newline="\n") as f:
        json.dump({"cell": list(CELL), "headings": HEADINGS, "wags": len(WAGS),
                   "species": names, "rows_per_species": len(WAGS) + 1,
                   "note": "row (species * rows_per_species + wag) holds a heading per column; "
                           "the last row of a species is its shadow; heading 0 faces +x on the "
                           "plane, counting towards +y (down the screen)"}, f, indent=1)
    big = Image.new("RGBA", sheet.size, (92, 118, 140, 255))
    big.alpha_composite(sheet)
    big.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(SHEET_PNG)
    print("wrote", OUT_PNG, sheet.size, "clipped", clipped)


if __name__ == "__main__":
    main()
