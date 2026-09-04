"""Builds the skate ramp piece: its shape, its artwork and its def.

    python tools/make_ramp_piece.py

Outputs:

    art/ramp_spine.png      the drawing
    data/objects/ramp.tres  the def, outline and all

This replaces the ramp that was traced off the painted plate by
tools/make_ramp.gd. That piece was a one-sided wedge whose deck the truck
slapped into rather than rode; this one is a SPINE — up, over a rounded crown,
and down the far side, symmetric so it drives the same both ways.

THE DECK IS A CURVATURE SCHEDULE, NOT AN ARC. A circular transition joins the
ground with its full curvature already switched on, so the wheel meets a corner
in the rate of turn even though the surface angle matches. Here the deck's
heading is eased with a smoothstep: curvature starts at zero, builds, and comes
back to zero at the crown. That, plus a peak angle well under the old wedge's,
is the difference between a ramp the truck rides and one it stops dead on.

The artwork is painted onto that outline rather than drawn by hand, so the
picture cannot disagree with the collision shape — the deck the truck drives on
is the deck you can see. Its palette is SAMPLED FROM art/ramp.png, the painted
skate ramp this replaces: same sanded plywood, same brown outline, same steel.
The details are quoted from it too — coping along the crown, bolts down the deck
edge, a steel kickplate at each toe.

Sizes are set against the truck, which has 38-unit tyres on a 148 wheelbase
(scenes/car.tscn). The ramp is described by the height it gains and the angle it
reaches; the length needed to do that smoothly falls out of the easing, which is
why it is long and low rather than the tall wedge it replaces.
"""

import math
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from pnglite import read_png, write_png

ROOT = pathlib.Path(__file__).resolve().parent.parent
REFERENCE = ROOT / "art" / "ramp.png"
ART = ROOT / "art" / "ramp_spine.png"
DEF = ROOT / "data" / "objects" / "ramp.tres"

## How much height the ramp gains, and the steepest angle it uses to do it.
RISE = 50.0
PEAK_DEGREES = 30.0

## The toe cannot come to a point. A zero-thickness tip is a sliver in the convex
## decomposition and a shape the physics server resolves badly; a few units of
## lip is invisible to a 38-unit tyre and gives the toe a real edge.
TOE = 6.0

## Points along the deck. Every one of them is potentially another convex part on
## the body, so this is a budget, not a quality dial — enough that a 38-unit tyre
## rolls the transition instead of clacking over facets, and no more.
DECK_POINTS = 22

## Artwork pixels per world unit. The piece is only 56 units tall, so the drawing
## is supersampled to keep the coping and the bolts from turning into mush when
## the camera is close.
SCALE = 3


# ---------------------------------------------------------------- geometry


def smoothstep(t: float) -> float:
    t = min(1.0, max(0.0, t))
    return t * t * (3.0 - 2.0 * t)


def _heading(t: float) -> float:
    """Surface angle at a fraction along the deck, in radians.

    Up to the peak angle over the first quarter, back to flat by the crown, then
    the mirror of that going down the far side.
    """
    peak = math.radians(PEAK_DEGREES)
    if t < 0.25:
        return peak * smoothstep(t / 0.25)
    if t < 0.5:
        return peak * (1.0 - smoothstep((t - 0.25) / 0.25))
    return -_heading(1.0 - t)


def _walk(length: float) -> list[tuple[float, float]]:
    """Traces a deck of the given length, turning as the schedule says to.

    Integrating the heading rather than solving for a shape is what lets the
    curvature be scheduled: any easing that is smooth in angle gives a deck that
    is smooth in curvature, which is the property the tyre actually feels.
    """
    points = [(0.0, 0.0)]
    x = y = 0.0
    for i in range(DECK_POINTS):
        angle = _heading((i + 0.5) / DECK_POINTS)
        step = length / DECK_POINTS
        x += step * math.cos(angle)
        y -= step * math.sin(angle)
        points.append((x, y))
    return points


def deck() -> list[tuple[float, float]]:
    """The riding surface, left toe at the origin and rising to the left of it.

    The profile fixes the shape and the angles, so the length needed to reach a
    given height depends on the whole easing — solved for here rather than being
    another number to keep in sync by hand.
    """
    low, high = RISE, RISE * 40.0
    for _ in range(40):
        mid = (low + high) * 0.5
        if -min(p[1] for p in _walk(mid)) < RISE:
            low = mid
        else:
            high = mid
    return _walk(high)


def outline(surface: list[tuple[float, float]]) -> list[tuple[float, float]]:
    """The deck closed off with a flat base, TOE below the toes."""
    return surface + [(surface[-1][0], TOE), (0.0, TOE)]


def shoelace(points: list[tuple[float, float]]) -> float:
    total = 0.0
    for i, (x, y) in enumerate(points):
        nx, ny = points[(i + 1) % len(points)]
        total += x * ny - nx * y
    return total


# --------------------------------------------------------------- palette


def palette() -> dict[str, tuple[int, int, int]]:
    """Wood, outline and steel, taken from the painted ramp this replaces.

    Sampled rather than typed in so the new piece is the same plywood as the old
    one even if the plate is ever repainted. Split by saturation: the plywood is
    bright and warm, the coping and the kickplate are just as bright and have no
    colour in them at all, and the drawn outline is what is left at the bottom.
    """
    width, height, pixels = read_png(REFERENCE)
    wood, steel, ink = [], [], []
    for i in range(0, width * height * 4, 4):
        r, g, b, a = pixels[i], pixels[i + 1], pixels[i + 2], pixels[i + 3]
        if a < 200:
            continue
        value = max(r, g, b)
        chroma = value - min(r, g, b)
        if value < 110:
            ink.append((r, g, b))
        elif chroma > 30 and value > 150:
            wood.append((r, g, b))
        elif chroma < 14 and 90 < value < 210:
            steel.append((r, g, b))

    def median(samples, fallback):
        if not samples:
            return fallback
        return tuple(sorted(s[c] for s in samples)[len(samples) // 2] for c in range(3))

    return {
        "wood": median(wood, (222, 180, 128)),
        "ink": median(ink, (74, 47, 30)),
        "steel": median(steel, (150, 152, 152)),
    }


def shade(colour: tuple[int, int, int], factor: float) -> tuple[int, int, int]:
    return tuple(min(255, max(0, int(c * factor))) for c in colour)


# --------------------------------------------------------------- painting


def paint(surface: list[tuple[float, float]], colours) -> tuple[int, int, bytearray]:
    """Draws the ramp onto its own outline.

    Everything is placed by walking the deck, so no detail can drift off the
    shape: the coping sits on the crown because the crown is where the deck's
    highest point is, and the bolts follow the surface because they are offset
    from it.
    """
    length = surface[-1][0]
    top = min(p[1] for p in surface)
    width = int(round(length * SCALE))
    height = int(round((TOE - top) * SCALE))
    pixels = bytearray(width * height * 4)

    wood = colours["wood"]
    ink = colours["ink"]
    steel = colours["steel"]

    def deck_y(x: float) -> float:
        """Surface height above the piece's top edge, in world units."""
        for i in range(len(surface) - 1):
            x0, y0 = surface[i]
            x1, y1 = surface[i + 1]
            if x0 <= x <= x1:
                t = (x - x0) / (x1 - x0)
                return (y0 + (y1 - y0) * t) - top
        return surface[-1][1] - top

    def put(px: int, py: int, colour, alpha: int = 255) -> None:
        if 0 <= px < width and 0 <= py < height:
            at = (py * width + px) * 4
            pixels[at] = colour[0]
            pixels[at + 1] = colour[1]
            pixels[at + 2] = colour[2]
            pixels[at + 3] = alpha

    base_y = TOE - top

    # The plywood body: darker with depth, streaked with grain. The streaks come
    # from a sum of sines rather than a random number generator so a rebuild is
    # byte-identical and does not show up as a diff for no reason.
    for px in range(width):
        x = (px + 0.5) / SCALE
        surface_y = deck_y(x)
        # Long, lazy periods — around 30 and 17 units. Tighter than that and the
        # plywood reads as a picket fence rather than as grain.
        streak = (math.sin(x * 0.21) * math.sin(x * 0.083 + 1.7)
                  + 0.5 * math.sin(x * 0.37 + 0.9))
        for py in range(height):
            y = (py + 0.5) / SCALE
            if y < surface_y or y > base_y:
                continue
            depth = (y - surface_y) / max(1.0, base_y - surface_y)
            put(px, py, shade(wood, 1.06 - 0.26 * depth + 0.05 * streak))

    # Everything else is placed by walking the deck, so no detail can drift off
    # the shape: the coping sits on the crown because that is where the walk is
    # highest, and the bolts follow the surface because they are offset from it
    # along its own normal.
    # Shifted into the image's own space, where the top edge is zero, so details
    # land where deck_y() says the surface is.
    walk = _along([(x, y - top) for x, y in surface])
    total = walk[-1][0]
    crown = min(walk, key=lambda step: step[2])[0]

    def stamp(cx: float, cy: float, radius: float, colour, lit: float = 0.0) -> None:
        """A filled disc in world units, clipped to the body."""
        for px in range(int((cx - radius) * SCALE), int((cx + radius) * SCALE) + 1):
            for py in range(int((cy - radius) * SCALE), int((cy + radius) * SCALE) + 1):
                x, y = (px + 0.5) / SCALE, (py + 0.5) / SCALE
                if (x - cx) ** 2 + (y - cy) ** 2 > radius * radius:
                    continue
                if y < deck_y(x) or y > base_y:
                    continue
                # Lit from above: the tube on the painted plate is a bright edge
                # over a dark underside, which is most of what makes it read as
                # round rather than as a grey stripe.
                fade = 1.0 + lit * (0.5 - (y - cy + radius) / (2.0 * radius))
                put(px, py, shade(colour, fade))

    # Quoted from the plate: a coping tube over the lip, and a steel kickplate
    # where the ramp meets the ground. A spine has two of each, being two ramps
    # back to back — so the kickplate is mirrored onto the far toe.
    coping_span = 34.0
    kickplate_span = 0.13 * total
    bolt_spacing = 30.0
    next_bolt = bolt_spacing * 0.5

    for distance, x, y, angle in walk:
        # Into the body, along the surface's own normal.
        nx, ny = math.sin(angle), math.cos(angle)
        if abs(distance - crown) < coping_span * 0.5:
            radius = 3.0
            stamp(x + nx * radius, y + ny * radius, radius, steel, lit=0.9)
        elif distance < kickplate_span or distance > total - kickplate_span:
            radius = 2.0
            stamp(x + nx * radius, y + ny * radius, radius, steel, lit=0.5)
        elif distance >= next_bolt:
            next_bolt = distance + bolt_spacing
            stamp(x + nx * 5.0, y + ny * 5.0, 1.3, shade(ink, 1.6))
            stamp(x + nx * 4.6, y + ny * 4.6, 0.6, shade(wood, 0.8))

    # The drawn outline: along the deck, along the base, and down both end faces,
    # so the piece is closed the way the painted one is. Thicker than a hairline
    # because the piece is 56 units tall and the line has to survive being drawn
    # at that size.
    thickness = 1.5
    for px in range(width):
        x = (px + 0.5) / SCALE
        for step in range(int(thickness * SCALE)):
            put(px, int(deck_y(x) * SCALE) + step, ink)
            put(px, int(base_y * SCALE) - 1 - step, ink)
    for py in range(height):
        if (py + 0.5) / SCALE < deck_y(0.0):
            continue
        for step in range(int(thickness * SCALE)):
            put(step, py, ink)
            put(width - 1 - step, py, ink)
    return width, height, pixels


def _along(surface: list[tuple[float, float]], step: float = 0.4) -> list:
    """The deck resampled at even arc length: (distance, x, y, angle) per step.

    Details are spaced along the SURFACE, not along x. Bolts spaced by x bunch up
    where the deck is steep, which on a ramp is exactly where the eye is.
    """
    out = []
    distance = 0.0
    for i in range(len(surface) - 1):
        x0, y0 = surface[i]
        x1, y1 = surface[i + 1]
        span = math.hypot(x1 - x0, y1 - y0)
        angle = math.atan2(-(y1 - y0), x1 - x0)
        at = 0.0
        while at < span:
            t = at / span
            out.append((distance + at, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, angle))
            at += step
        distance += span
    return out


# ------------------------------------------------------------------- def


def write_def(shape: list[tuple[float, float]]) -> None:
    points = shape if shoelace(shape) < 0.0 else list(reversed(shape))
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    width, height = max(xs) - min(xs), max(ys) - min(ys)
    ox, oy = (max(xs) + min(xs)) * 0.5, (max(ys) + min(ys)) * 0.5
    body = ", ".join(
        "%.4f, %.4f" % ((x - ox) / width, (y - oy) / height) for x, y in points
    )
    area = abs(shoelace(points)) * 0.5

    DEF.write_text(
        '[gd_resource type="Resource" script_class="ObjectDef" load_steps=3 format=3]\n'
        "\n"
        '[ext_resource type="Script" path="res://scripts/object_def.gd" id="1_def"]\n'
        '[ext_resource type="Texture2D" path="res://art/ramp_spine.png" id="2_art"]\n'
        "\n"
        "[resource]\n"
        'script = ExtResource("1_def")\n'
        "tier = 3\n"
        'display_name = "Skate Ramp"\n'
        'shape = "polygon"\n'
        "size = Vector2(%.0f, %.0f)\n"
        "polygon = PackedVector2Array(%s)\n"
        # Mass and price come from the area, so a change to the profile carries
        # them with it instead of leaving two hand-typed numbers behind. Tuned
        # against the girder, which is 520x40 and 85 mass.
        "mass = %.1f\n"
        "buoyancy = 1.40\n"
        "friction = 1.35\n"
        "bounce = 0.0\n"
        "color = Color(0.85, 0.68, 0.44, 1)\n"
        "price = %d\n"
        "textures = Array[Texture2D]([ExtResource(\"2_art\")])\n"
        % (width, height, body, round(area * 0.0035, 1), int(area * 0.008)),
        encoding="utf-8",
    )
    print("%s  %.0fx%.0f  %d points" % (DEF.name, width, height, len(points)))


def main() -> None:
    surface = deck()
    colours = palette()
    print("palette  wood=%s ink=%s steel=%s" % (
        colours["wood"], colours["ink"], colours["steel"]))
    width, height, pixels = paint(surface, colours)
    write_png(ART, width, height, pixels)
    print("%s  %dx%d" % (ART.name, width, height))
    write_def(outline(surface))


if __name__ == "__main__":
    main()
