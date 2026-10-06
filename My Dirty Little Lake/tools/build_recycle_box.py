"""The recycle box, drawn by rule at the angler's grain (one world px an art px).

The island's crate and the four piers' boxes are one picture. It used to be a 32x33 painting
drawn at 2.0; this is the same box at twice the pixels, 64x66, drawn at 1.0, so every number
the runtime reads keeps its meaning in world px: the top face is a 64x32 diamond centred on
row ART_TOP (16), the box stands on a matching diamond centred on row ART_GROUND (48), the
walls are 32 rows tall and the bottom corner is the last row.

What is drawn, from the back: the inside of the two far walls, falling into shade towards the
floor; the rim, the top edges of the four walls, lit; the two near walls in horizontal boards
(lit right, shaded left) with a vertical corner post at the near corner and at each outer
edge, nails where a board meets a post, the odd board darker, grain dashes and a knot or two;
the recycle mark (two arrows chasing round a ring, the ferry's sail's mark) on the shaded left
face; and the near-black outline round the whole silhouette. The emblem a pier carves into the
lit right face is the pier builder's business (`face_right`).

Palettes are wood ramps, darkest to lightest, seven steps: "oak" is the redrawn hut's own wall
ramp (tools/build_shed_v2.py WALL) with its moss, "brown" is the old box's plank browns.

Rules first, polish after. Run from the project root with the psd-extract venv's
site-packages on PYTHONPATH:
  python tools/build_recycle_box.py [--palette oak|brown] [--write]
--write overwrites assets/Recycle_Box.png (the old 2x painting is kept in art_source/).
Reimport after writing.
"""
import math
import sys
from pathlib import Path

import random

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import build_shed_v2 as shed  # noqa: E402  the hut's wall ramp and siding rules

W, H = 64, 66
MID = 32
ART_TOP = 16
ART_GROUND = 48
WALL_TALL = ART_GROUND - ART_TOP
INK = (24, 18, 17)

RAMPS = {
	# The hut's wall ramp (build_shed_v2.WALL, seven steps).
	"oak": [(38, 24, 22), (58, 36, 29), (78, 48, 36), (100, 64, 45), (122, 80, 54), (168, 118, 76), (214, 166, 110)],
	# The old box's own browns, darkest to lightest.
	"brown": [(47, 30, 25), (74, 46, 34), (101, 65, 45), (124, 82, 55), (142, 96, 64), (164, 115, 76), (196, 146, 98)],
}
MOSS = [(30, 56, 36), (52, 92, 46), (86, 132, 56), (128, 170, 72)]
BLUE = (77, 133, 166)       # Style.BOX_BLUE
BLUE_LIT = (110, 168, 204)  # Style.BOX_BLUE_LIT
BLUE_DEEP = (46, 86, 112)

## Board pitch on the walls, in rows: a lit row, body, a darker row, the seam.
BOARD = 8
## How wide a corner post is, in columns.
POST = 4
## Rim: how many rows of wall top show round the mouth.
RIM = 3
## The mark, in the left face's own px: centre, ring radius, bar, arcs and heads.
MARK_AT = (16.5, 16.5)
MARK_RAD = 7.5
MARK_BAR = 2.2
MARK_SPAN = 100.0
MARK_START = 225.0
MARK_HEAD_LONG = 5.0
MARK_HEAD_WIDE = 4.5


def mix(a, b, t):
	return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def hash01(*args):
	h = 2166136261
	for a in args:
		for ch in repr(a).encode():
			h = ((h ^ ch) * 16777619) & 0xFFFFFFFF
	return (h % 10007) / 10007.0


def outer_diamond(x, y, cy, grow=0.0):
	return abs(x - MID) / (MID + grow) + abs(y - cy) / (16.0 + grow * 0.5) <= 1.0


def face_left(x, y):
	"""(u, v) on the left wall, u across from its outer edge (0) to the corner (32), v down
	from its top edge, or None."""
	if not (0 <= x < MID):
		return None
	top = ART_TOP + x * 0.5
	v = y - top
	if 0 <= v < WALL_TALL:
		return (x, v)
	return None


def face_right(x, y):
	"""(u, v) on the right wall, u across from the corner (0) to its outer edge (32), v down
	from its top edge, or None."""
	if not (MID <= x < W):
		return None
	u = x - MID
	top = 2 * ART_TOP - u * 0.5
	v = y - top
	if 0 <= v < WALL_TALL:
		return (u, v)
	return None


def board_tone(ramp, v, lit, index, u, seed):
	"""The wall's board rows: a lit row, body, a darker row and the seam."""
	r = int(v) % BOARD
	base = 4 if lit else 2
	if hash01(seed, "dark board", lit, index) < 0.28:
		base -= 1
	if r == 0:
		tone = ramp[base + 1]
	elif r == BOARD - 1:
		tone = ramp[max(base - 2, 0)]
	elif r == BOARD - 2:
		tone = ramp[base - 1]
	else:
		tone = ramp[base]
		# Grain: a short dash a step darker inside the board's body.
		g = hash01(seed, "grain", lit, index, int(u) // 5)
		if g < 0.35 and r == 2 + int(g * 10) % 3 and int(u) % 5 != 0:
			tone = mix(ramp[base], ramp[base - 1], 0.6)
	return tone


def ring_mark(u, v, cu, cv):
	"""The recycle mark: two arrows chasing round a ring, each ending in a chevron head
	pointing on round it. Picked off a sheet of four (rad 7.5, bar 2.2, arcs of 100 degrees
	from 225 and 45, heads 5 long and 4.5 a side). True where the mark is."""
	du, dv = u - cu, v - cv
	d = math.hypot(du, dv)
	a = math.atan2(dv, du)  # 0 right, +pi/2 down
	for start in (math.radians(MARK_START), math.radians(MARK_START - 180)):
		span = math.radians(MARK_SPAN)
		if (a - start) % math.tau <= span and abs(d - MARK_RAD) <= MARK_BAR * 0.5:
			return True
		end = start + span
		hx, hy = cu + math.cos(end) * MARK_RAD, cv + math.sin(end) * MARK_RAD
		tx, ty = -math.sin(end), math.cos(end)  # the way round
		nx, ny = math.cos(end), math.sin(end)   # outward
		along = (u - hx) * tx + (v - hy) * ty
		across = (u - hx) * nx + (v - hy) * ny
		if -0.5 <= along <= MARK_HEAD_LONG and abs(across) <= MARK_HEAD_WIDE * (1.0 - max(along, 0.0) / MARK_HEAD_LONG):
			return True
	return False


## The hut's siding, laid on a box face (2026-10-02, Richard: "give box the same wood
## treatment and construction, so it perfectly matches"): the hut's wall ramp, a three-row
## sill at the foot, lap boards Hut.ROW tall each with a dark seam, its shadow and a lit top
## edge, butt joints every Hut.SEG, grain and the odd knot, and the hut's corner boards — a
## five-wide board down the near corner and two at each far end. The left face is the hut's
## shaded front (Hut.FRONT), the right its sunlit gable (Hut.GABLE).
def hut_wall(u, v, lit, seed):
	"""One pixel of a near wall: u across from the face's left end, v down from its top."""
	H_ = shed.Hut
	base = H_.GABLE if lit else H_.FRONT
	d = WALL_TALL - 1 - int(v)  # rows up from the foot
	ui = int(u)
	# Corner boards: the near corner's five (two on the left face, three on the right) and
	# two at each far end, the hut's own tones.
	if not lit and ui >= MID - 2:
		t = (4, 5)[ui - (MID - 2)]
	elif lit and ui <= 2:
		t = (5, 4, 3)[ui]
	elif not lit and ui <= 1:
		t = (4, 3)[ui]
	elif lit and ui >= MID - 2:
		t = (5, 4)[ui - (MID - 2)]
	else:
		t = None
	if t is not None:
		if int(v) < 2:
			t -= 2
		elif int(v) % 11 == 4 and (ui in (MID - 1, 1) if not lit else ui == 1):
			t = 6
		return shed.WALL[max(0, min(6, t))]
	if d < 3:  # the sill, a heavier board
		return shed.wallc((base - 2, base + 0.8, base)[d])
	dd = d - 3
	row, lap = dd // H_.ROW, dd % H_.ROW
	face = 2 if lit else 1
	off = (row * 7 + face * 3) % H_.SEG
	seg, pu = (ui + off) // H_.SEG, (ui + off) % H_.SEG
	r = random.Random(hash((seed, face, row, seg)) & 0xFFFFFFFF)
	tone = r.uniform(-H_.TONE, H_.TONE)
	gx, gl = r.randint(3, 12), r.randint(3, 7)
	knot = r.randint(3, 20) if r.random() < 0.18 else None
	t = base + tone
	if lap < 1:
		t = 0.6
	elif lap < 2:
		t -= 1.0
	elif lap >= H_.ROW - 1:
		t += 1.3
	if pu == 0 and lap >= 1:
		t = 0.9
	elif pu == 1 and lap >= 1:
		t += 0.6
	elif lap == 2 and gx <= pu < gx + gl:
		t -= 0.7
	elif lap == 3 and pu == gx + gl + 2:
		t -= 0.7
	if knot is not None and pu == knot and lap == 2:
		t = base - 3
	if d < 5:
		t -= 0.6
	return shed.wallc(t)


def build_box(palette="brown", seed="box"):
	# The hut's ramp whatever the pier wears: the box is the hut's carpentry.
	ramp = list(shed.WALL)
	moss = False
	img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	px = img.load()
	for y in range(H):
		for x in range(W):
			cx, cy = x + 0.5, y + 0.5
			top_in = outer_diamond(cx, cy, ART_TOP)
			left = face_left(cx, cy)
			right = face_right(cx, cy)
			if top_in:
				# The mouth: the rim, then the inside of the far walls.
				hole = abs(cx - MID) / (MID - RIM * 2.0) + abs(cy - ART_TOP) / (16.0 - RIM) <= 1.0
				if not hole:
					# The rim: the walls' top edges, lit, with the end grain at the corners.
					corner = abs(cx - MID) > MID - 5 or abs(cy - ART_TOP) > 16 - 3
					tone = ramp[6] if (cy < ART_TOP) else ramp[5]
					if corner:
						tone = ramp[4]
					if cy < ART_TOP and hash01(seed, "rim", int(cx) // 4) < 0.25:
						tone = ramp[5]
					px[x, y] = tone + (255,)
					continue
				# Inside: which far wall, and how far down it (darker the deeper).
				far_left = cx < MID
				edge_y = ART_TOP - 16 + abs(cx - MID) * 0.5 + RIM  # the far rim's inner edge
				depth = (cy - edge_y) / (16.0 * 1.2)
				base = 2 if far_left else 1
				t = min(max(depth, 0.0), 1.0)
				tone = mix(ramp[base + 1], ramp[0], t * 0.9)
				r = int(cy - edge_y) % BOARD
				if r == BOARD - 1:
					tone = mix(tone, ramp[0], 0.6)
				px[x, y] = tone + (255,)
				continue
			if left is not None:
				px[x, y] = hut_wall(left[0], left[1], False, seed) + (255,)
				continue
			if right is not None:
				px[x, y] = hut_wall(right[0], right[1], True, seed) + (255,)
	# The mark on the shaded left face.
	for y in range(H):
		for x in range(MID):
			f = face_left(x + 0.5, y + 0.5)
			if f is None:
				continue
			u, v = f
			if ring_mark(u, v, *MARK_AT):
				px[x, y] = BLUE + (255,)
	# The mark's dark edge, one pixel round it, so the blue stands off the wood.
	marks = {(x, y) for y in range(H) for x in range(MID) if px[x, y][:3] in (BLUE, BLUE_LIT)}
	for (x, y) in marks:
		for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
			q = (x + dx, y + dy)
			if q not in marks and 0 <= q[0] < MID and face_left(q[0] + 0.5, q[1] + 0.5) and px[q][3]:
				px[q] = BLUE_DEEP + (255,)
	if moss:
		# Moss along the foot of the walls and up the corner posts' bottoms.
		for y in range(H):
			for x in range(W):
				f = face_left(x + 0.5, y + 0.5) or face_right(x + 0.5, y + 0.5)
				if f is None or px[x, y][:3] in (BLUE, BLUE_LIT, BLUE_DEEP):
					continue
				u, v = f
				up = WALL_TALL - v
				n = hash01(seed, "moss", x // 2, y // 2)
				if up < 2.5 + n * 5.0 and n < 0.55:
					px[x, y] = MOSS[1 if n < 0.25 else (2 if n < 0.45 else 0)] + (255,)
	# The outline: every opaque pixel touching a clear one.
	out = img.copy()
	op = out.load()
	for y in range(H):
		for x in range(W):
			if px[x, y][3] == 0:
				continue
			for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
				xx, yy = x + dx, y + dy
				if not (0 <= xx < W and 0 <= yy < H) or px[xx, yy][3] == 0:
					op[x, y] = INK + (255,)
					break
	# The near corner's seam, a dark line down the join of the two walls.
	for y in range(2 * ART_TOP + 1, H - 1):
		if op[MID, y][3]:
			op[MID, y] = mix(ramp[0], INK, 0.5) + (255,)
	# The mouth's inner edge: the far rim's lip, one dark row where it drops inside.
	for y in range(H):
		for x in range(W):
			cx, cy = x + 0.5, y + 0.5
			hole = abs(cx - MID) / (MID - RIM * 2.0) + abs(cy - ART_TOP) / (16.0 - RIM) <= 1.0
			if hole and not (abs(cx - MID) / (MID - RIM * 2.0) + abs(cy - 1 - ART_TOP) / (16.0 - RIM) <= 1.0):
				op[x, y] = mix(ramp[0], INK, 0.5) + (255,)
	return out


def main():
	args = sys.argv[1:]
	palette = args[args.index("--palette") + 1] if "--palette" in args else "brown"
	box = build_box(palette)
	if "--write" in args:
		old = ROOT / "art_source" / "recycle_box_2x.png"
		cur = ROOT / "assets" / "Recycle_Box.png"
		if cur.exists() and not old.exists():
			Image.open(cur).save(old)
		box.save(cur)
		print("wrote", cur, box.size)
	box.resize((W * 6, H * 6), Image.NEAREST).save(ROOT / "tools" / "last_recycle_box.png")


if __name__ == "__main__":
	main()
