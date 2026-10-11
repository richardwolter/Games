"""Plants the angler's idle feet: every frame of an idle strip wears one frame's legs.

The painted idle strips redraw the legs in some frames (the back boot lifted in two of west's
nine), which reads as the feet shuffling while the upper body breathes. This lays the bottom
rows of a reference frame over every other frame, lined up on the front boot, so the trousers
and boots are the same pixels all loop.

East wears west's lower body mirrored (2026-10-11, Richard): its own was near-black shoes a
size small under lighter trousers, stepping in the last frames. Belt, pouch, the seat of the
trousers and the boots come over whole; west's hand, which hangs at the hip, is lifted out and
the hip under it filled with the trousers below it, since east's hand is holding the basket.
East keeps its own body to the belt and its basket and hand, drawn over the new legs.

Next to each strip goes `idle_<dir>_feet.json`: the cell column and row of the planted boot's
toe, frame by frame. `tools/slice_character.gd` pins a strip that has one on that pixel rather
than on the frame's whole ink box. The builder knows where it put the legs; the slicer reading
it back off the pixels would take the basket for a boot whenever the basket reaches the ground.

The painted original is kept beside the strip as `idle_<dir>_orig.png` the first time and is
what every later run reads, so a re-run is the same strip, not a copy of a copy.

  PYTHONPATH=<psd-extract site-packages> python tools/build_idle_frames.py [dir ...] [--out DIR]

Then re-slice (`tools/slice_character.gd`) and reimport. `--out` writes the strips somewhere
else for a preview (tools/char_preview) and leaves the art alone.
"""
import json
import os
import shutil
import sys
from PIL import Image

DIR = 'art_source/character_extracted'
FRAMES = 9

# Per direction: the frame whose legs every frame wears, and how many rows off the bottom
# hold nothing but trousers and boots. Picked off tools/char_preview (2026-10-11).
LEGS = {
    'west': {'ref': 2, 'rows': 8},
}

# Strips whose boots are already the same pixels every frame, the body still over them: only
# pinned. South's slid only because each frame was centred on an ink box the basket swings.
PINNED = ('south',)

# East: west's lower body mirrored. `rows` is how far up from the boot it is taken (the row
# under the belt down); `ground` the row the boots stand on in east's cells; `nudge` moves the
# legs across under the body, in pixels, by eye.
MIRRORED = {
    'east': {'from': 'west', 'rows': 13, 'ground': 44, 'nudge': 0, 'bag_in': 0, 'clear': 40, 'lift_frames': (0, 1, 2)},
}

# Trousers and boots, as painted.
TROUSERS = {
    (62, 76, 108), (95, 120, 142), (76, 95, 126), (108, 135, 151), (130, 143, 158),
    (140, 156, 184), (57, 64, 82), (68, 77, 94), (83, 93, 108), (92, 105, 122), (45, 49, 66),
}
BOOTS = {(93, 46, 40), (74, 36, 35), (73, 45, 51), (24, 10, 12), (23, 25, 24), (4, 3, 8)}
# The basket's weave and the hand: what a part of the leg rows must touch to be kept.
WICKER = {
    (200, 115, 57), (125, 61, 42), (181, 125, 85), (182, 104, 48), (165, 94, 52),
    (145, 77, 49), (170, 115, 69), (220, 191, 140),
}
SKIN = {
    (243, 166, 119), (238, 179, 136), (212, 109, 76), (233, 136, 91), (192, 87, 63),
    (223, 124, 80), (221, 150, 108),
}
# The light on the frame's own paler trousers, seen through the gap between the basket and
# its handle. Gone with the rest of its legs, so the gap shows the legs that replace them.
TROUSER_LIGHTS = {(168, 181, 196), (204, 212, 220), (182, 190, 206), (222, 222, 220)}

# The three tones the trousers are lit in, darkest first.
TROUSER_DARK = (62, 76, 108, 255)
TROUSER_MID = (76, 95, 126, 255)
TROUSER_LIGHT = (95, 120, 142, 255)
OUTLINE = (0, 0, 0)
CLEAR = (0, 0, 0, 0)

# How many rows over the belt the bag on it reaches, past the legs' own rows.
BAG_ROWS = 3

# The rows legs are hung from: the chest down to the belt. The face nods and leans over the
# idle, the chest only breathes, and matched on the face the legs followed the nod.
CHEST = (24, 31)

NEIGHBOURS = [(dx, dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1) if dx or dy]
SIDES = ((1, 0), (-1, 0), (0, 1), (0, -1))


def solid(p):
    return p[3] > 128


def cells_of(image):
    w = image.width / FRAMES
    bounds = [(round(c * w), round((c + 1) * w)) for c in range(FRAMES)]
    return bounds, [image.crop((l, 0, r, image.height)) for l, r in bounds]


def foot(cell):
    """The front boot's toe: the leftmost pixel of the lowest row of ink, and that row."""
    box = cell.getbbox()
    row = box[3] - 1
    xs = [x for x in range(cell.width) if solid(cell.getpixel((x, row)))]
    return min(xs), row


def parts(pixels):
    """`pixels` split into the groups that touch, corners included."""
    left = set(pixels)
    out = []
    while left:
        start = left.pop()
        part, todo = {start}, [start]
        while todo:
            x, y = todo.pop()
            for dx, dy in NEIGHBOURS:
                n = (x + dx, y + dy)
                if n in left:
                    left.discard(n)
                    part.add(n)
                    todo.append(n)
        out.append(part)
    return out


def with_legs(cell, ref, rows):
    fx, fy = foot(cell)
    rx, ry = foot(ref)
    out = cell.copy()
    top = fy + 1 - rows
    for y in range(top, out.height):
        for x in range(out.width):
            out.putpixel((x, y), CLEAR)
    legs = ref.crop((0, ry + 1 - rows, ref.width, ry + 1))
    dx = fx - rx
    out.alpha_composite(legs, (max(dx, 0), top), (max(-dx, 0), 0))
    return out


def torso_at(cells, ref=0, rows=CHEST):
    """How far each frame's chest sits from frame `ref`'s across its cell: the shift that best
    lays one on the other. The strips are hand-trimmed, so a frame's body is wherever the even
    split happened to leave it."""
    a = cells[ref]
    out = []
    for b in cells:
        best = None
        for dy in range(-2, 3):
            for dx in range(-40, 41):
                score = 0
                for y in range(rows[0], rows[1]):
                    for x in range(a.width):
                        pa = a.getpixel((x, y))
                        bx, by = x + dx, y + dy
                        inside = 0 <= bx < b.width and 0 <= by < b.height
                        pb = b.getpixel((bx, by)) if inside else CLEAR
                        if solid(pa) != solid(pb):
                            score += 3
                        elif solid(pa) and sum(abs(pa[i] - pb[i]) for i in range(3)) > 60:
                            score += 1
                if best is None or score < best[0]:
                    best = (score, dx)
        out.append(best[1])
    return out


def outline(image):
    """A one-pixel ring of outline round whatever is drawn, where it touches nothing."""
    ring = []
    for y in range(image.height):
        for x in range(image.width):
            if solid(image.getpixel((x, y))):
                continue
            for dx, dy in SIDES:
                nx, ny = x + dx, y + dy
                if not (0 <= nx < image.width and 0 <= ny < image.height):
                    continue
                n = image.getpixel((nx, ny))
                # Round what is drawn, not round the outline already there: ringing the
                # outline too doubled it on every edge.
                if solid(n) and n[:3] != OUTLINE:
                    ring.append((x, y))
                    break
    for x, y in ring:
        image.putpixel((x, y), OUTLINE + (255,))


def lower_body(cell, rows):
    """A frame from the belt down, the bottom `rows` up from its boot: the trousers and boots,
    and the bag on the belt as a picture of its own. The hand that hangs at the hip and the bag
    are both lifted out and the hip under them filled with the trousers' own tones."""
    _, g = foot(cell)
    out = cell.crop((0, g + 1 - rows, cell.width, g + 1))
    px = out.load()
    w, h = out.size
    # What hangs off the hip that is not trouser: the boots at the bottom, the bag on the belt,
    # and what belongs to the upper body (the hand, the strap of the pouch on the near front,
    # the hem of the vest in the top rows), which cut off at the band's top stood out in stubs.
    loose = {
        (x, y) for y in range(h) for x in range(w)
        if solid(px[x, y]) and px[x, y][:3] != OUTLINE and px[x, y][:3] not in TROUSERS
    }
    groups = parts(loose)
    boots = [g for g in groups if max(y for _, y in g) >= h - 6]
    rest = [g for g in groups if g not in boots and not {px[p][:3] for p in g} & SKIN]
    # The bag is the biggest of what is left below the band's own top rows, which can still
    # hold a strip of the donor's vest.
    bag = max(rest, key=lambda g: sum(1 for _, y in g if y >= BAG_ROWS)) if rest else set()
    # The pouch on the strap at the near front of the hip: what is left in leather, ahead of
    # the bag.
    front = set()
    for group in rest:
        if group is not bag and {px[p][:3] for p in group} & WICKER:
            if min(x for x, _ in group) < min(x for x, _ in bag):
                front |= group

    def cut(part):
        """`part` and the outline round it, as a picture, and where it stood in the band."""
        ring = {
            (x + dx, y + dy) for x, y in part for dx, dy in NEIGHBOURS
            if 0 <= x + dx < w and 0 <= y + dy < h and solid(px[x + dx, y + dy])
            and px[x + dx, y + dy][:3] == OUTLINE
        }
        every = part | ring
        box = (
            min(x for x, _ in every), min(y for _, y in every),
            max(x for x, _ in every) + 1, max(y for _, y in every) + 1,
        )
        picture = Image.new('RGBA', (box[2] - box[0], box[3] - box[1]), CLEAR)
        for x, y in every:
            picture.putpixel((x - box[0], y - box[1]), px[x, y])
        return picture, box

    pouch, box = cut(bag)
    strap, strap_box = cut(front) if front else (None, None)
    lifted = set()
    for group in groups:
        if group not in boots:
            lifted |= group
    # A lifted part's own outline goes with it: an outline pixel touching it and nothing else
    # that is drawn.
    for y in range(h):
        for x in range(w):
            if px[x, y][:3] != OUTLINE or not solid(px[x, y]) or (x, y) in lifted:
                continue
            near = [(x + dx, y + dy) for dx, dy in NEIGHBOURS]
            touches = any(n in lifted for n in near)
            touches_body = any(
                0 <= nx < w and 0 <= ny < h and (nx, ny) not in lifted and solid(px[nx, ny])
                and px[nx, ny][:3] != OUTLINE for nx, ny in near
            )
            if touches and not touches_body:
                lifted.add((x, y))
    for x, y in lifted:
        px[x, y] = CLEAR
    # How wide the hip is: as wide as the trousers ever are below the belt.
    trouser_xs = [x for y in range(h) for x in range(w) if solid(px[x, y]) and px[x, y][:3] in TROUSERS]
    left, right = min(trouser_xs), max(trouser_xs)
    trouser_top = min(y for y in range(h) for x in range(w) if solid(px[x, y]) and px[x, y][:3] in TROUSERS)
    # Filled in the trousers' own three tones, lit as the leg under it is: light on the open
    # face, a step down along the back edge and under the belt. Not above the band's own top
    # rows, which are the belt's.
    filled = {(x, y) for x, y in lifted if left <= x <= right and y >= min(BAG_ROWS, trouser_top)}
    for x, y in filled:
        px[x, y] = TROUSER_MID
    for x, y in filled:
        edge = right - x
        shade = TROUSER_LIGHT if edge >= 2 else (TROUSER_MID if edge == 1 else TROUSER_DARK)
        above = px[x, y - 1] if y > 0 else CLEAR
        if (x, y - 1) not in filled and solid(above) and above[:3] not in TROUSERS:
            shade = TROUSER_DARK if shade == TROUSER_MID else TROUSER_MID
        px[x, y] = shade
    # An outline that ran between a lifted part and the hip is inside the hip now.
    for y in range(h):
        for x in range(w):
            if not solid(px[x, y]) or px[x, y][:3] != OUTLINE:
                continue
            if not any((x + dx, y + dy) in lifted for dx, dy in NEIGHBOURS):
                continue
            open_side = any(
                not (0 <= x + dx < w and 0 <= y + dy < h) or not solid(px[x + dx, y + dy])
                for dx, dy in SIDES
            )
            if open_side:
                continue
            below = px[x, y + 1] if y + 1 < h else None
            if below and solid(below) and below[:3] in TROUSERS:
                px[x, y] = below
            else:
                for dx in (1, -1):
                    if 0 <= x + dx < w and px[x + dx, y][:3] in TROUSERS:
                        px[x, y] = px[x + dx, y]
                        break
    trim(out)
    outline(out)
    return out, pouch, box, strap, strap_box


def trim(image, top=0, bottom=None, keep=()):
    """Outline standing on its own: a pixel of it that touches nothing drawn but more outline,
    corners included. What is left once a part is lifted out from beside it, or two outlines
    are laid side by side, and it reads as pixels sticking off the figure."""
    px = image.load()
    w, h = image.size
    while True:
        loose = [
            (x, y) for y in range(top, h if bottom is None else bottom) for x in range(w)
            if solid(px[x, y]) and px[x, y][:3] == OUTLINE and (x, y) not in keep and not any(
                0 <= x + dx < w and 0 <= y + dy < h and solid(px[x + dx, y + dy])
                and px[x + dx, y + dy][:3] != OUTLINE for dx, dy in NEIGHBOURS
            )
        ]
        if not loose:
            return
        for x, y in loose:
            px[x, y] = CLEAR


def without_legs(cell, top, covered=None):
    """A frame with everything from row `top` down taken out but the basket and the hand, and
    what hangs together with them, and the outline that touches it. A smaller part in the
    basket's weave is kept too (the pouch on the front of the hip) unless it lies mostly inside
    `covered`, the box the borrowed bag is laid in: that is the frame's own back pouch peeking
    out from behind the hip, which the bag replaces."""
    out = cell.copy()
    px = out.load()
    loose = {
        (x, y) for y in range(top, cell.height) for x in range(cell.width)
        if solid(px[x, y]) and px[x, y][:3] != OUTLINE
        and px[x, y][:3] not in TROUSERS and px[x, y][:3] not in TROUSER_LIGHTS
    }
    # The boots' browns are the handle's darks too: kept where they hang together with the
    # basket, which an old boot does not. Dropped, the handle had holes the back bag showed
    # through.
    # Only what hangs together with the basket or the hand: a boot's shade or a trouser's light
    # that is not in the lists above is a scrap of the old legs left standing on its own.
    def under_bag(part):
        inside = sum(
            1 for x, y in part
            if any(l <= x < r and t <= y < b for l, t, r, b in covered or [])
        )
        return inside * 2 > len(part)

    kept = set()
    for part in parts(loose):
        colours = {px[p][:3] for p in part}
        if colours & SKIN or (colours & WICKER and not under_bag(part)):
            kept |= part
    # The outline that rims what is kept: beside it, or on a corner between two pixels of rim.
    # Corner-touching alone kept the basket's wide shadow line under it, which lay across the
    # legs once the basket was lifted, and the hand's rim eating into the bag behind it.
    rim = {
        (x, y) for y in range(top, cell.height) for x in range(cell.width)
        if solid(px[x, y]) and px[x, y][:3] == OUTLINE
        and any((x + dx, y + dy) in kept for dx, dy in SIDES)
    }
    corners = {
        (x, y) for y in range(top, cell.height) for x in range(cell.width)
        if solid(px[x, y]) and px[x, y][:3] == OUTLINE and (x, y) not in rim
        and any((x + dx, y + dy) in kept for dx, dy in NEIGHBOURS)
        and sum((x + dx, y + dy) in rim for dx, dy in SIDES) >= 2
    }
    for y in range(top, cell.height):
        for x in range(cell.width):
            if not solid(px[x, y]) or (x, y) in kept or (x, y) in rim or (x, y) in corners:
                continue
            px[x, y] = CLEAR
    return out


def in_front(cell, top):
    """What of a frame hangs in front of the front pouch: the basket and the hand on it from
    row `top` down, and the basket's handle where it rises above that row, with the outline
    that touches them. Not the free hand, which the pouch hangs in front of."""
    out = Image.new('RGBA', cell.size, CLEAR)
    out.alpha_composite(cell.crop((0, top, cell.width, cell.height)), (0, top))
    px = cell.load()
    woven = {
        (x, y) for y in range(cell.height) for x in range(cell.width)
        if solid(px[x, y]) and (px[x, y][:3] in WICKER or px[x, y][:3] in BOOTS)
    }
    # The boots' browns are the handle's darks too: left out, the front pouch drew over them.
    handle = set()
    for part in parts(woven):
        if any(y >= top for _, y in part):
            handle |= {(x, y) for x, y in part if y < top}
    for x, y in handle:
        out.putpixel((x, y), px[x, y])
        for dx, dy in NEIGHBOURS:
            nx, ny = x + dx, y + dy
            if 0 <= nx < cell.width and 0 <= ny < top and px[nx, ny][:3] == OUTLINE and solid(px[nx, ny]):
                out.putpixel((nx, ny), px[nx, ny])
    return out


def build_planted(direction):
    src = Image.open(original(direction)).convert('RGBA')
    bounds, cells = cells_of(src)
    plan = LEGS[direction]
    ref = cells[plan['ref']]
    out = Image.new('RGBA', src.size, CLEAR)
    feet = []
    for i, ((l, _), cell) in enumerate(zip(bounds, cells)):
        built = cell if i == plan['ref'] else with_legs(cell, ref, plan['rows'])
        feet.append(list(foot(built)))
        out.alpha_composite(built, (l, 0))
    return out, feet


def build_pinned(direction):
    # The art is not touched, so no original is kept beside it.
    src = Image.open(os.path.join(DIR, 'idle_%s.png' % direction)).convert('RGBA')
    _, cells = cells_of(src)
    return src, [list(foot(cell)) for cell in cells]


def build_mirrored(direction):
    plan = MIRRORED[direction]
    donor_dir = plan['from']
    _, donor = cells_of(Image.open(original(donor_dir)).convert('RGBA'))
    donor_ref = LEGS[donor_dir]['ref']
    # The donor's body against its own planted toe, frame by frame: how it sways over its feet.
    toes = [foot(c)[0] for c in donor]
    torso = torso_at(donor, donor_ref)
    sway = [torso[i] - (toes[i] - toes[donor_ref]) for i in range(FRAMES)]
    ref = donor[donor_ref]
    # Taken `BAG_ROWS` higher than the legs, for the top of the bag on the belt, which is drawn
    # back over the frame's own belt.
    legs, pouch, pouch_box, strap, strap_box = lower_body(ref, plan['rows'] + BAG_ROWS)
    pouch_y = pouch_box[1]
    # Where the donor wears the bag, mirrored: the middle of the hip, seen through the gap
    # between the basket and its handle.
    middle_x = legs.width - pouch_box[2]
    # The strap's pouch stays where the donor wears it, mirrored: on the near front of the hip.
    strap_at = (legs.width - strap_box[2], strap_box[1])
    strap = strap.transpose(Image.FLIP_LEFT_RIGHT)
    # Only from the belt down: over the chest the strap read as a smudge on the frame's arm.
    belt = BAG_ROWS - 1 - strap_at[1]
    if belt > 0:
        strap = strap.crop((0, belt, strap.width, strap.height))
        strap_at = (strap_at[0], strap_at[1] + belt)
    legs = legs.transpose(Image.FLIP_LEFT_RIGHT)
    pouch = pouch.transpose(Image.FLIP_LEFT_RIGHT)
    legs_toe = foot(legs)[0]
    # The bag goes on the back of the hip, where the frame's own art had one peeking out from
    # behind the body: its back edge on the seat's, `plan['bag_in']` in from it.
    seat = min(
        x for y in range(pouch_y, pouch_y + pouch.height) for x in range(legs.width)
        if solid(legs.getpixel((x, y)))
    )
    pouch_x = seat + plan['bag_in']
    flipped = ref.transpose(Image.FLIP_LEFT_RIGHT)

    src = Image.open(original(direction)).convert('RGBA')
    bounds, cells = cells_of(src)
    # Where the legs go under each frame: frame 0's chest laid on the mirrored donor's once,
    # then every frame by how far its chest sits from frame 0's (a frame against its own strip
    # matches far better than against another drawing).
    base = torso_at([flipped, cells[0]], 0)[1]
    body = [base + dx for dx in torso_at(cells, 0)]
    out = Image.new('RGBA', src.size, CLEAR)
    top = plan['ground'] + 1 - plan['rows']
    feet = []
    for i, ((l, _), cell) in enumerate(zip(bounds, cells)):
        frame = Image.new('RGBA', cell.size, CLEAR)
        # Mirrored, the donor's body sways the other way over its feet.
        x = body[i] + sway[i] + plan['nudge']
        at = (max(x, 0), top - BAG_ROWS)
        frame.alpha_composite(legs, at, (max(-x, 0), 0))
        # The bag hangs on the seat, under the frame's own body (the net bundled on the back
        # comes down over its top) and under the basket and the arm in front of the hip.
        bag_at = (x + pouch_x, top - BAG_ROWS + pouch_y)
        frame.alpha_composite(pouch, bag_at)
        # The bag also stays where the donor wears it, so the gap between the basket and its
        # handle shows a bag on the belt and not bare trousers.
        middle_at = (x + middle_x, bag_at[1])
        frame.alpha_composite(pouch, middle_at)
        bag_box = (bag_at[0], bag_at[1], bag_at[0] + pouch.width, bag_at[1] + pouch.height)
        front_at = (x + strap_at[0], top - BAG_ROWS + strap_at[1])
        front_box = (front_at[0], front_at[1], front_at[0] + strap.width, front_at[1] + strap.height)
        kept = without_legs(cell, top, [bag_box, front_box])
        # A basket swung below the soles makes the boots read as off the ground: lifted back
        # up to stand on it.
        # Where the hand hangs down among the basket rows (`lift_frames`), basket and hand go
        # up together until the basket clears `clear`, the row over the back boot's top. Where
        # the arm is raised and the hand is up at the sleeve the basket stays as drawn:
        # lifting it there tore the handle off the hand, and a shorter basket (tried,
        # 2026-10-11) lost the basket's own shape.
        bottom = kept.getbbox()[3] - 1
        raised = max(bottom - plan['ground'], bottom - plan['clear'] if i in plan['lift_frames'] else 0)
        if raised > 0:
            band = kept.crop((0, top, kept.width, kept.height))
            kept = kept.crop((0, 0, kept.width, top))
            kept = kept.crop((0, 0, cell.width, cell.height))
            kept.alpha_composite(band, (0, top - raised))
        frame.alpha_composite(kept)
        # The front pouch hangs over the vest, as the donor wears it, and under the hand and
        # the basket, which are laid back over it.
        frame.alpha_composite(strap, front_at)
        frame.alpha_composite(in_front(kept, top - max(raised, 0)))
        # Not the bottom rows: where the basket comes down over a boot, the boot's sole is all
        # that is left of it there, and taken off, the boot stands a row off the ground.
        # Nor the legs' own rim: where the basket hides the trouser beside it, a pixel of it
        # touches nothing but outline, and taken off it left a gap down the leg.
        rim = {
            (at[0] + lx - max(-x, 0), at[1] + ly)
            for ly in range(legs.height) for lx in range(max(-x, 0), legs.width)
            if solid(legs.getpixel((lx, ly))) and legs.getpixel((lx, ly))[:3] == OUTLINE
        }
        trim(frame, top - BAG_ROWS - 1, plan['ground'] - 1, rim)
        feet.append([x + legs_toe, plan['ground']])
        out.alpha_composite(frame, (l, 0))
    return out, feet


def original(direction):
    strip = os.path.join(DIR, 'idle_%s.png' % direction)
    orig = os.path.join(DIR, 'idle_%s_orig.png' % direction)
    if not os.path.exists(orig):
        shutil.copyfile(strip, orig)
    return orig


def main(argv):
    out_dir = None
    if '--out' in argv:
        i = argv.index('--out')
        out_dir = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]
    for direction in argv or list(LEGS) + list(MIRRORED) + list(PINNED):
        if direction in MIRRORED:
            image, feet = build_mirrored(direction)
        elif direction in PINNED:
            image, feet = build_pinned(direction)
        else:
            image, feet = build_planted(direction)
        path = os.path.join(out_dir or DIR, 'idle_%s.png' % direction)
        image.save(path)
        with open(os.path.join(out_dir or DIR, 'idle_%s_feet.json' % direction), 'w', newline='\n') as f:
            json.dump(feet, f)
            f.write('\n')
        print('wrote', path)


main(sys.argv[1:])
