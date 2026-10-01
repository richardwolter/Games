"""The hut, redrawn at the angler's grain (one world px an art px).

The geometry is the painted hut's (`art_source/shed_paint.png`, 105x103, drawn at 1.4), measured
corner by corner and multiplied by 1.4, so the new picture is 147x144 and its walls, door and
eaves land where the old ones did: footprint, door spot, shadow sweep and hem need not move.
Everything inside that outline is drawn afresh by rule: board-and-batten walls, lap siding in
the gable, shingles, moss, door, shuttered window, and the plants of the three stages, picked by
the meter: neglected (weeds, mushrooms, a broken roof), tidied (repaired, young ivy, pots) and
cosy (roses over the door, hollyhocks, a flower box, a birdhouse, flowers in the moss).

Rules first, polish after: this writes a review sheet, `tools/last_shed_mockup.png`; --write
overwrites the three stage pictures `art_source/shed_v2_<stage>.png` and the window's glow mask
`shed_v2_glow.png` (Richard polishes those by hand), and --ship copies them to `assets/shed_*.png`,
which is what the game reads. Reimport after shipping.

Run from the project root with the psd-extract venv's site-packages on PYTHONPATH.
"""
import argparse
import random

import numpy as np
from PIL import Image, ImageDraw

K = 1.4  # old painted px -> new art px
W, H = 147, 144
INK = (24, 18, 17)

# The old picture's corners, in its own pixels (measured off shed_paint.png).
OLD = {
	"ridge_l": (21.5, 0.5), "ridge_r": (80.0, 28.5),
	"eave_l": (2.5, 41.0), "eave_r": (62.5, 71.0),
	"back_r": (102.5, 49.0),
	"wall_tl": (9.0, 44.0), "wall_bl": (9.0, 77.5),
	"near_b": (61.0, 101.5),
	"right_b": (99.0, 84.0), "right_t": (99.0, 51.0),
	"window": (80.5, 52.5),
}
DOOR = (35.0, 55.0)   # door across the front face, new px
DOOR_TALL = 34


def P(name):
	x, y = OLD[name]
	return (x * K, y * K)


def mix(c1, c2, t):
	return tuple(int(round(c1[i] + (c2[i] - c1[i]) * t)) for i in range(3))


def stops(*cols, n=None):
	"""A ramp through the given colours, n steps (default: as given)."""
	if n is None:
		return list(cols)
	out = []
	for i in range(n):
		f = i / (n - 1) * (len(cols) - 1)
		k = min(int(f), len(cols) - 2)
		out.append(mix(cols[k], cols[k + 1], f - k))
	return out


WALL = stops((38, 24, 22), (78, 48, 36), (122, 80, 54), (168, 118, 76), (214, 166, 110), n=7)
ROOF = [(28, 38, 30), (48, 62, 42), (72, 88, 50), (100, 114, 60), (132, 142, 74), (170, 172, 96)]
MOSS = [(30, 56, 36), (52, 92, 46), (86, 132, 56), (128, 170, 72), (180, 206, 104)]
FRESH = [(80, 50, 36), (128, 86, 56), (176, 126, 82), (214, 166, 108), (236, 198, 140), (246, 222, 170)]
LEAF = [(22, 44, 32), (38, 78, 44), (66, 120, 52), (110, 162, 66), (168, 204, 96)]
DEAD = [(56, 46, 30), (92, 78, 44), (132, 114, 62), (172, 154, 90)]
DOORW = stops((50, 30, 26), (98, 58, 38), (150, 94, 58), (196, 136, 84), n=5)
SHUT = [(36, 52, 46), (60, 92, 74), (92, 130, 96), (138, 172, 126)]
CLAY = [(84, 38, 30), (140, 68, 46), (192, 106, 70), (224, 150, 104)]
HOLE = [(18, 13, 13), (32, 23, 21), (48, 34, 28)]
RAFTER = [(64, 42, 32), (98, 66, 46)]
PINK = [(140, 40, 66), (214, 84, 118), (248, 160, 178), (255, 214, 220)]
YELLOW = [(190, 120, 30), (240, 190, 70), (255, 232, 140)]
WHITE = [(170, 170, 170), (226, 224, 214), (255, 255, 246)]
BLUE = [(56, 70, 150), (100, 130, 214), (170, 196, 246)]
RED = [(130, 30, 30), (206, 62, 52), (246, 122, 96)]
WISTERIA = [(74, 46, 116), (132, 92, 186), (190, 158, 232), (228, 210, 250)]

STAGES = ("neglected", "tidied", "cosy")


def wallc(t):
	"""The wall ramp read at a fractional step, so a board can sit half a step off its neighbour."""
	t = max(0.0, min(6.0, t))
	k = min(int(t), 5)
	return mix(WALL[k], WALL[k + 1], t - k)


def poly_mask(pts):
	im = Image.new("L", (W, H), 0)
	ImageDraw.Draw(im).polygon([(round(x), round(y)) for x, y in pts], fill=255)
	return np.array(im) > 0


def noise(seed, cell):
	rng = np.random.default_rng(seed)
	g = rng.random((H // cell + 2, W // cell + 2))
	ys, xs = np.mgrid[0:H, 0:W]
	fx, fy = xs / cell, ys / cell
	x0, y0 = fx.astype(int), fy.astype(int)
	tx, ty = fx - x0, fy - y0
	tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
	a = g[y0, x0] * (1 - tx) + g[y0, x0 + 1] * tx
	b = g[y0 + 1, x0] * (1 - tx) + g[y0 + 1, x0 + 1] * tx
	return a * (1 - ty) + b * ty


def line_y(a, b, x):
	return a[1] + (b[1] - a[1]) * (x - a[0]) / (b[0] - a[0])


class Canvas:
	def __init__(self):
		self.c = np.zeros((H, W, 4), np.uint8)
		self.plant = np.zeros((H, W), bool)

	def put(self, x, y, col, plant=False):
		x, y = int(round(x)), int(round(y))
		if 0 <= x < W and 0 <= y < H:
			self.c[y, x, :3] = col
			self.c[y, x, 3] = 255
			if plant:
				self.plant[y, x] = True

	def has(self, x, y):
		return 0 <= x < W and 0 <= y < H and self.c[y, x, 3] > 0


class Hut:
	def __init__(self, stage, seed=11):
		self.lvl = STAGES.index(stage)
		self.seed = seed
		self.cv = Canvas()
		self.wall_tl, self.wall_bl, self.near_b = P("wall_tl"), P("wall_bl"), P("near_b")
		self.right_b, self.right_t = P("right_b"), P("right_t")
		self.ridge_l, self.ridge_r = P("ridge_l"), P("ridge_r")
		self.eave_l, self.eave_r, self.back_r = P("eave_l"), P("eave_r"), P("back_r")
		self.near_t = (self.near_b[0], self.eave_r[1] - 1)
		self.front = poly_mask([self.wall_tl, self.near_t, self.near_b, self.wall_bl])
		self.gable = poly_mask([self.near_t, self.ridge_r, self.right_t, self.right_b, self.near_b])
		self.roof = poly_mask([self.ridge_l, self.ridge_r, self.eave_r, self.eave_l])
		rb = self.back_r
		self.back = poly_mask([self.ridge_r, rb, (rb[0] - 3, rb[1] + 3), self.right_t,
			(self.ridge_r[0], self.ridge_r[1] + 4)]) & ~self.gable
		self.glow = np.zeros((H, W), bool)

	# --- lines ---
	def front_base(self, x):
		return line_y(self.wall_bl, self.near_b, x)

	def gable_base(self, x):
		return line_y(self.near_b, self.right_b, x)

	def eave(self, x):
		return line_y(self.eave_l, self.eave_r, x)

	def divider(self, x):
		return line_y(self.near_t, self.right_t, x)

	def put(self, x, y, c, plant=False):
		self.cv.put(x, y, c, plant)

	def build(self):
		self.walls_front()
		self.door()
		self.walls_gable()
		self.window()
		self.roof_and_trim()
		self.nature()
		self.outline()
		return Image.fromarray(self.cv.c, "RGBA"), self.glow

	# --- walls: lap siding all round, the front in shade, the gable in the sun ---
	ROW = 5    # a board's height
	SEG = 16   # a board's length

	def walls_front(self):
		self.siding(self.front, self.front_base, int(self.wall_tl[0]), 3.3, 1)

	def walls_gable(self):
		self.siding(self.gable, self.gable_base, int(self.near_b[0]), 4, 2)
		# the frieze at eave height, the front's fascia carried round the corner
		xn, xr = int(self.near_b[0]), int(self.right_t[0])
		for x in range(xn, xr + 1):
			y = self.divider(x)
			j = (x - xn) % 19 == 7
			for dy, t in ((-1, 5), (0, 4), (1, 2)):
				if self.gable[int(round(y + dy)), x]:
					self.put(x, y + dy, WALL[t - 2 if j and dy < 1 else t])
		self.corners()

	def board(self, face, row, seg):
		"""What one board is: its tone, grain, and the damage it carries through the stages."""
		r = random.Random(face * 100003 + row * 1009 + seg * 31 + self.seed)
		b = dict(tone=r.uniform(-0.45, 0.45), gx=r.randint(3, self.SEG - 7), gl=r.randint(2, 4))
		roll = r.random()
		b["missing"] = roll < 0.07 and row >= 1
		b["crack"] = None
		if not b["missing"] and roll < 0.42:
			b["crack"] = (r.randint(2, self.SEG - 9), r.randint(3, 7), r.random())
		b["knot"] = r.randint(3, self.SEG - 3) if r.random() < 0.18 else None
		b["gap"] = (r.randint(2, self.SEG - 10), r.randint(4, 7))
		return b

	def siding(self, mask, base_fn, x0, base, face):
		lvl, seed = self.lvl, self.seed
		grime = noise(seed + face * 7, 5) * 0.6 + noise(seed + face * 7 + 1, 2) * 0.4
		creep = noise(seed + face * 7 + 2, 4)
		ROW, SEG = self.ROW, self.SEG
		boards = {}
		for x in range(W):
			u = x - x0
			for y in range(H):
				if not mask[y, x]:
					continue
				d = base_fn(x) - y
				if d < 3:   # the sill plate, a heavier board
					t = (base - 2, base + 0.8, base)[int(d)]
					if (u + 5) % 23 == 0 and d >= 1:
						t -= 1.6
					self.put(x, y, wallc(t))
					continue
				dd = d - 3
				row, lap = int(dd // ROW), dd % ROW
				off = (row * 7 + face * 3) % SEG
				seg, pu = (u + off) // SEG, (u + off) % SEG
				key = (row, seg)
				if key not in boards:
					boards[key] = self.board(face, row, seg)
				b = boards[key]
				t = base + b["tone"]
				if lap < 1:
					t -= 1.7          # the board's own lower edge, in its shadow
				elif lap >= ROW - 1:
					t += 0.8          # its top, catching the light
				if pu == 0 and lap >= 1:
					t -= 1.6          # the butt joint
				elif pu == 1 and lap >= 1:
					t += 0.4
				elif lap == 2 and b["gx"] <= pu < b["gx"] + b["gl"]:
					t -= 0.7          # grain
				elif lap == 3 and pu == b["gx"] + b["gl"] + 2:
					t -= 0.7
				c = None
				fresh = None
				if b["missing"]:
					a, n = b["gap"]
					if a <= pu < a + n and lap >= 1:
						if lvl == 0:
							c = HOLE[0] if lap >= ROW - 1 else HOLE[1]
						else:
							fresh = FRESH if lvl == 1 else [mix(f, w, 0.5) for f, w in zip(FRESH, WALL[1:])]
					elif lvl == 0 and pu in (a - 1, a + n) and lap >= 1:
						t += 2            # splintered ends, raw wood
				if b["crack"] and c is None and fresh is None:
					a, n, keep = b["crack"]
					shown = lvl == 0 or (lvl == 1 and keep < 0.3)
					if shown and a <= pu < a + n and int(lap) == 2:
						t = base - 3
					elif shown and pu == a + n // 2 and int(lap) == 3:
						t = base - 3
					elif shown and a <= pu < a + n and int(lap) == 1:
						t += 1
				if b["knot"] is not None and pu == b["knot"] and int(lap) == 2 and lvl < 2:
					t = base - 3
				# shade under the eave (front) or the barge and back eave (gable)
				if face == 1:
					v = y - (self.eave(x) + 1)
					t -= 2 if v < 1 else 1 if v < 3 else 0
				else:
					barge = x - (self.ridge_r[0] + (self.eave_r[0] - self.ridge_r[0]) *
						(y - self.ridge_r[1]) / (self.eave_r[1] - self.ridge_r[1]))
					t -= 2 if barge < 1.5 else 1 if barge < 3 else 0
					if y < self.back_r[1] and x > self.right_t[0] - 4:
						t -= 1
				if d < 5:
					t -= 0.6
				if grime[y, x] > (0.66, 0.8, 9)[lvl]:
					t -= 0.8
				if c is None:
					if fresh is not None:
						c = fresh[max(0, min(5, int(round(t - base + 2))))]
					else:
						c = wallc(t)
				reach = (7, 5, 0)[lvl] - (u * 7 % 5) * 0.4
				if 3 <= d < 3 + reach and creep[y, x] + grime[y, x] * 0.3 > (0.7 if lvl == 0 else 0.85):
					c = MOSS[(1 if lap < 1 else 2 if (d < 3 + reach - 1.5) else 3) - (lvl == 1)]
				self.put(x, y, c)

	def corners(self):
		"""Corner boards: the near corner, and each wall's far end."""
		xn = int(round(self.near_b[0]))
		for y in range(H):
			for x, t in ((xn - 2, 4), (xn - 1, 5), (xn, 5), (xn + 1, 4), (xn + 2, 3)):
				if self.front[y, x] or self.gable[y, x]:
					top = y - self.near_t[1]
					tt = t - (2 if top < 2 else 0)
					if (y % 11 == 4) and x in (xn - 1, xn + 1):
						tt = 6
					self.put(x, y, WALL[tt])
		for mask in (self.front, self.gable):
			cols = np.where(mask.any(axis=0))[0]
			ends = (cols.min(), cols.min() + 1) if mask is self.front else (cols.max() - 1, cols.max())
			for i, x in enumerate(ends):
				for y in np.where(mask[:, x])[0]:
					t = (4, 3)[i] if mask is self.front else (5, 4)[i]
					self.put(x, y, WALL[t])

	def door(self):
		dl, dr = DOOR
		lvl = self.lvl
		for x in range(int(dl), int(dr) + 1):
			bot = self.front_base(x)
			top = bot - DOOR_TALL
			for y in range(int(top) - 2, int(bot) - 2):
				u = x - int(dl)
				v = y - (bot - DOOR_TALL)
				frame = u < 2 or u > dr - dl - 2 or v < 0
				if frame:
					c = WALL[5] if (u == 0 or v == -2) else WALL[3]
					if u == 1 or v == -1:
						c = WALL[0]
					self.put(x, y, c)
					continue
				pu = (u - 2) % 4
				t = 2 + (pu == 1) - (pu == 0)
				if (y + u * 5) % 9 == 0 and pu == 2:
					t -= 1
				vv = int(v)
				for ledge in (4, DOOR_TALL - 8):
					if ledge <= vv < ledge + 3:
						t = (3, 2, 0)[vv - ledge]
				# the Z brace
				run = (DOOR_TALL - 15) / (dr - dl - 4)
				diag = (DOOR_TALL - 8) - (u - 2) * run
				if 0 <= diag - vv < 2.5 and 7 <= vv < DOOR_TALL - 8:
					t = 3 if diag - vv < 1 else 1
				if lvl == 0 and (x * 7 + y * 3) % 23 == 0:
					t -= 1
				self.put(x, y, DOORW[max(0, min(4, t))])
		# hinges and the ring
		for ledge in (5, DOOR_TALL - 7):
			for i in range(7):
				x = int(dl) + 2 + i
				y = self.front_base(x) - DOOR_TALL + ledge
				self.put(x, y, (40, 38, 40) if i < 6 else (90, 88, 86))
			self.put(int(dl) + 4, self.front_base(int(dl) + 4) - DOOR_TALL + ledge, (150, 146, 140))
		hx = int(dr) - 4
		hy = self.front_base(hx) - DOOR_TALL // 2
		ring = (200, 176, 110) if lvl else (110, 100, 84)
		for dx, dy in ((0, 0), (-1, 1), (1, 1), (0, 2)):
			self.put(hx + dx, hy + dy, ring if dy < 2 else (60, 50, 40))
		# a stone step
		for x in range(int(dl) - 1, int(dr) + 2):
			bot = self.front_base(x)
			self.put(x, bot - 1, (150, 146, 134) if lvl else (108, 104, 96))
			self.put(x, bot, (96, 92, 86))

	def hanging_shutter(self, wx, wy, hw, hh, gs):
		"""The right shutter, both hinges given way but one bent strap, so it dangles below the
		window from a single corner. A paler ghost stays on the wall where it used to shade it."""
		import math
		for k in range(5):
			i = hw + 1 + k
			for j in range(-hh, hh + 1):
				x, y = int(round(wx + i)), int(round(wy + j + i * gs))
				if 0 <= x < W and 0 <= y < H and self.cv.c[y, x, 3]:
					under = tuple(int(v) for v in self.cv.c[y, x, :3])
					edge = k == 4 or j in (-hh, hh)
					self.put(x, y, mix(under, WALL[0], 0.4) if edge else mix(under, WALL[6], 0.3))
		top = (wx + hw + 1, wy - hh + 2 + (hw + 1) * gs)
		self.put(top[0], top[1], (60, 58, 60))            # the bare upper pin
		self.put(top[0] + 1, top[1], (96, 94, 92))
		hx, hy = wx + hw + 1, wy + hh + 3 + (hw + 1) * gs  # the bent strap, under the sill's corner
		ang = 0.35   # it swings in under the window, dangling
		ca, sa = math.cos(ang), math.sin(ang)
		done = set()
		for k2 in range(0, 9):
			for j2 in range(0, (2 * hh + 1) * 2):
				k, j = k2 / 2, j2 / 2 - hh
				ox, oy = k, j + hh + k * gs
				key = (int(round(hx + ca * ox - sa * oy)), int(round(hy + sa * ox + ca * oy)))
				if key in done:
					continue
				done.add(key)
				edge = k >= 3.5 or j <= -hh + 0.5 or j >= hh - 0.5
				t = 0 if edge else (1 if int(k) % 2 else 2)
				if not edge and (abs(j - (-hh + 3)) < 0.6 or abs(j - (hh - 3)) < 0.6):
					t = 3
				self.put(key[0], key[1], mix(SHUT[t], WALL[2], 0.45))
		for dx, dy in ((-1, -3), (-1, -2), (-1, -1), (0, -1), (0, 0)):   # the strap, bent
			self.put(hx + dx, hy + dy, (44, 42, 44))

	def cobweb(self):
		"""A web strung into the corner under the eave, over the end board: threads fanned from
		the corner, rings sagging between them, blended into the wood behind."""
		import math
		cols = np.where(self.front.any(axis=0))[0]
		ax = int(cols.min()) + 2
		ay = int(round(self.eave(ax))) + 3
		eave_ang = math.atan2(self.eave_r[1] - self.eave_l[1], self.eave_r[0] - self.eave_l[0])
		angs = [eave_ang + (math.pi / 2 - eave_ang) * f for f in (0.0, 0.3, 0.62, 1.0)]
		long = (17, 16, 15, 14)

		def thread(x, y, a):
			x, y = int(round(x)), int(round(y))
			if not (0 <= x < W and 0 <= y < H) or self.cv.c[y, x, 3] == 0:
				return
			under = tuple(int(v) for v in self.cv.c[y, x, :3])
			self.put(x, y, mix(under, (232, 232, 222), a))

		for a, n in zip(angs, long):
			for r in range(n * 2):
				thread(ax + math.cos(a) * r / 2, ay + math.sin(a) * r / 2, 0.24 if r > 4 else 0.32)
		for ring in (6.0, 11.0, 15.0):
			for p, q in zip(angs, angs[1:]):
				x1, y1 = ax + math.cos(p) * ring, ay + math.sin(p) * ring
				x2, y2 = ax + math.cos(q) * ring, ay + math.sin(q) * ring
				for st in range(17):
					f = st / 16
					sag = math.sin(f * math.pi) * 0.9
					thread(x1 + (x2 - x1) * f - sag * 0.6, y1 + (y2 - y1) * f - sag * 0.8, 0.18)
		# the spider, sat in the web
		self.put(ax + 7, ay + 6, (30, 24, 22))
		self.put(ax + 8, ay + 7, (30, 24, 22))

	def gs(self):
		return (self.right_b[1] - self.near_b[1]) / (self.right_b[0] - self.near_b[0])

	def window(self):
		wx, wy = P("window")
		wx, wy = round(wx), round(wy) + 2
		gs = self.gs()
		hw, hh = 6, 7
		dim = self.lvl == 0
		for i in range(-hw, hw + 1):
			for j in range(-hh, hh + 1):
				x, y = wx + i, wy + j + i * gs
				if abs(i) == hw or abs(j) == hh:
					c = WALL[5] if j == -hh or i == hw else WALL[2]
					self.put(x, y, c)
				elif abs(i) == hw - 1 or abs(j) == hh - 1:
					self.put(x, y, WALL[1])
				elif i == 0 or j == 0:
					self.put(x, y, WALL[3])
				else:
					f = max(0.0, 1 - (abs(i) + abs(j)) / 9)
					warm = mix((240, 170, 70), (255, 238, 170), f)
					if dim:
						warm = mix(warm, (90, 70, 50), 0.45)
						if i - j == 2 and i > 0:
							warm = (40, 30, 26)  # a crack
					if (i, j) in ((-3, -4), (-2, -5), (2, -4)) and not dim:
						warm = (255, 252, 230)
					self.put(x, y, warm)
					self.glow[int(round(y)), x] = True
		# sill
		for i in range(-hw - 2, hw + 3):
			x, y = wx + i, wy + hh + 1 + i * gs
			self.put(x, y, WALL[6])
			self.put(x, y + 1, WALL[3])
			self.put(x, y + 2, WALL[0])
		self.win = (wx, wy, hw, hh, gs)
		# shutters
		for side in (-1, 1):
			if self.lvl == 0 and side == 1:
				self.hanging_shutter(wx, wy, hw, hh, gs)
				continue
			sag = 3 if (self.lvl == 0 and side == -1) else 0
			for k in range(5):
				i = side * (hw + 1 + k)
				for j in range(-hh, hh + 1):
					x = wx + i
					y = wy + j + i * gs + sag + (k * sag) // 4
					edge = k == 4 or j in (-hh, hh)
					t = 1 if edge else (2 if k % 2 else 3)
					if j in (-hh + 3, hh - 3) and not edge:
						t = 3 if k % 2 else 2
					if (k == 2 and j == -1) and self.lvl:
						t = 0          # the heart cut out
					if (k in (1, 3) and j == -2) and self.lvl:
						t = 0
					c = SHUT[t] if self.lvl else mix(SHUT[t], WALL[2], 0.5)
					self.put(x, y, c)

	# --- roof ---
	def roof_and_trim(self):
		lvl, seed = self.lvl, self.seed
		el, er = self.eave_l, self.eave_r
		moss_n = noise(seed + 9, 8) * 0.65 + noise(seed + 10, 3) * 0.35
		cut = (0.47, 0.6, 9.0)[lvl]   # the cosy roof carries no moss
		row_h, sw = 5, 6
		rng = random.Random(seed + 77)
		holes = set()
		for _ in range(10):  # clusters of broken shingles
			row, col = rng.randint(2, 11), rng.randint(2, 16)
			holes.add((row, col))
			for _ in range(rng.randint(1, 4)):
				holes.add((row + rng.choice((0, 0, 1, -1)), col + rng.choice((-1, 1))))
		cracked = {(rng.randint(1, 12), rng.randint(1, 18)) for _ in range(30)}
		moss = np.zeros((H, W), bool)
		info = {}
		for y in range(H):
			for x in range(W):
				if not self.roof[y, x]:
					continue
				d = line_y(el, er, x) - y
				row = int(d // row_h)
				pr = d % row_h
				off = (row % 2) * 3
				col = int((x + off) // sw)
				pc = (x + off) % sw
				info[(x, y)] = (row, pr, col, pc)
				m = moss_n[y, x] + random.Random(row * 97 + col).random() * 0.08
				if m > cut and (row, col) not in holes:
					moss[y, x] = True
		for (x, y), (row, pr, col, pc) in info.items():
			r = random.Random(row * 101 + col * 7 + seed)
			key = (row, col)
			ramp = ROOF
			hole = key in holes
			if hole and lvl >= 1:
				ramp = FRESH if lvl == 1 else [mix(f, rf, 0.55) for f, rf in zip(FRESH, ROOF)]
				hole = False
			t = 3 + r.choice((0, 0, 1, -1))
			if pr < 1:
				t = 0
			elif pr < 2:
				t -= 1
			elif pr > row_h - 1.2:
				t += 1
			if pc == 0 and pr >= 1:
				t = 1
			elif pc == 1 and pr > row_h - 2.2:
				t += 1
			if (x * 5 + y * 3 + row) % 13 == 0 and pr >= 1:
				t -= 1
			if key in cracked and (lvl == 0 or lvl == 1 and (key[0] + key[1]) % 4 == 0) and pr >= 1 and pc - 1 == int(pr):
				t = 0
			c = ramp[max(0, min(5, t))]
			if hole:
				if pr < 1:
					c = HOLE[0]
				else:
					s = 0.86 * x + 0.5 * y
					c = RAFTER[int(s % 9) == 1] if s % 9 < 2 else HOLE[1 + (pr > 3.5)]
			elif moss[y, x]:
				above = moss[y - 1, x] if y > 0 else False
				below = moss[y + 1, x] if y + 1 < H else False
				mt = 2 + (not above) + (not above and r.random() < 0.4) - (not below)
				if pr < 1 and above:
					mt -= 1
				if (x + y * 3) % 7 == 0:
					mt += 1
				c = MOSS[max(0, min(4, mt))]
				if lvl == 2 and not above and (x * 13 + y * 7) % 19 == 0:
					c = (WHITE[2], YELLOW[1], PINK[2])[(x + y) % 3]   # flowers in the moss
			self.put(x, y, c)
		# back strip past the gable
		for y in range(H):
			for x in range(W):
				if self.back[y, x]:
					self.put(x, y, ROOF[1] if (x + y) % 5 else ROOF[0])
		# fascia along the eave: a plank of the front's own wood
		for x in range(int(el[0]), int(er[0]) + 2):
			y = line_y(el, er, x)
			j = (x - int(el[0])) % 21 == 9
			for dy, t in ((0, 5), (1, 3), (2, 1)):
				tt = t - 2 if j and dy < 2 else t - ((x * 7) % 17 < 2 and dy == 1)
				self.put(x, y + dy, WALL[tt])
			# moss hanging over it
			if lvl < 2 and 0 < y < H and moss[int(y) - 1, x]:
				for k in range(1 + (x * 7) % (3 if lvl == 0 else 2)):
					self.put(x, y + 1 + k, MOSS[1 + (k == 0)])
		# ridge cap: little caps along the ridge
		rl, rr = self.ridge_l, self.ridge_r
		for x in range(int(rl[0]), int(rr[0]) + 1):
			y = line_y(rl, rr, x)
			seg = (x - int(rl[0])) % 6
			for dy, t in ((0, 5), (1, 4), (2, 2), (3, 0)):
				tt = t - (seg == 0) * 2
				gone = lvl == 0 and (x - int(rl[0])) // 6 in (2, 5, 6)
				if gone:
					self.put(x, y + dy, HOLE[1] if dy < 3 else ROOF[0])
					continue
				self.put(x, y + dy, ROOF[max(0, tt)] if dy < 3 else ROOF[0])
		# barge board down the roof's right end: a plank of the gable's wood
		n = int(abs(self.eave_r[1] - rr[1]))
		for i in range(n + 1):
			px = rr[0] + (self.eave_r[0] - rr[0]) * i / n
			py = rr[1] + (self.eave_r[1] - rr[1]) * i / n
			j = i % 17 == 8
			for dx, t in ((0, 6), (1, 4), (2, 2)):
				self.put(px + dx, py, WALL[t - 2 if j and dx else t])
		self.moss = moss

	# --- nature ---
	def leaf(self, x, y, ramp, flip=False, size=1):
		"""A small leaf; light up and right, dark down and left, ringed below in the darkest."""
		shapes = [
			[".l.", "mlh", "dm."],
			[".lh", "mml", "dd."],
		]
		rows = shapes[size % 2]
		for j, row in enumerate(rows):
			for i, ch in enumerate(row):
				if ch == ".":
					continue
				ii = (2 - i) if flip else i
				t = {"d": 1, "m": 2, "l": 3, "h": 4}[ch]
				self.put(x + ii - 1, y + j - 1, ramp[t], True)
		self.put(x - (1 if not flip else -1), y + 2, ramp[0], True)

	def flower(self, x, y, ramp, centre=None):
		centre = centre or YELLOW[1]
		for dx, dy, t in ((0, -1, 2), (-1, 0, 1), (1, 0, 2), (0, 1, 1)):
			self.put(x + dx, y + dy, ramp[t], True)
		self.put(x, y, centre, True)
		self.put(x - 1, y + 1, ramp[0], True)

	def tuft(self, x, y, tall, ramp, lean=0):
		"""Grass blades standing on y."""
		for b in range(-1, 2):
			h = max(2, tall - abs(b) * 2)
			for k in range(h):
				lx = x + b * (k > h // 2) + (lean if k > h * 0.6 else 0)
				t = 1 + (k > h // 3) + (k > h * 0.7)
				self.put(lx, y - k, ramp[min(len(ramp) - 1, t)], True)

	def vine(self, x, y, height, rng, dead=False, lean=0.0, blooms=None, leafy=3):
		px = x
		for k in range(height):
			px += lean + rng.choice((-0.6, 0, 0, 0.6))
			self.put(px, y - k, (DEAD if dead else LEAF)[0 if dead else 1], True)
			if not dead and k % leafy == 0 and k > 1:
				side = 1 if (k // leafy) % 2 else -1
				self.leaf(px + side * 2, y - k, LEAF, flip=side < 0, size=k)
				if blooms and rng.random() < 0.45:
					self.flower(px - side * 2, y - k - 1, blooms)
			if dead and k % 5 == 3:
				self.put(px + 1, y - k - 1, DEAD[1], True)
				self.put(px + 2, y - k - 2, DEAD[2], True)
		return px

	def pot(self, x, y, plant, rng):
		"""A clay pot standing on y, its plant over it."""
		rows = ["xxxxxxx", "x3332x.", ".x221x.", ".x110x.", "..xxx.."]
		for j, row in enumerate(rows):
			for i, ch in enumerate(row):
				if ch == ".":
					continue
				c = INK if ch == "x" else CLAY[int(ch)]
				self.put(x + i - 3, y - 5 + j, c, True)
		top = y - 6
		if plant == "fern":
			for k in range(-3, 4, 2):
				for s in range(4):
					self.put(x + k + (k > 0) * s // 2 - (k < 0) * s // 2, top - s + abs(k) // 2, LEAF[2 + (s > 1)], True)
		elif plant == "sprout":
			self.leaf(x - 1, top - 1, LEAF, flip=True)
			self.leaf(x + 1, top - 2, LEAF)
		else:
			for k in range(5):
				self.put(x - 2 + k, top, LEAF[1], True)
			for dx in (-2, 0, 2):
				self.put(x + dx, top - 1, LEAF[2], True)
				self.flower(x + dx, top - 3 - (dx == 0), plant)

	def mushroom(self, x, y, big=False):
		cap = RED if big else [(110, 70, 50), (160, 110, 70), (200, 150, 100)]
		self.put(x, y, WHITE[1], True)
		self.put(x, y - 1, WHITE[2], True)
		for dx in (-1, 0, 1):
			self.put(x + dx, y - 2, cap[1 + (dx == 1)], True)
		self.put(x, y - 3, cap[2], True)
		if big:
			self.put(x - 2, y - 2, cap[0], True)
			self.put(x + 2, y - 2, cap[1], True)
			self.put(x, y - 2, WHITE[2], True)

	def hollyhock(self, x, y, tall, ramp, rng):
		for k in range(tall):
			self.put(x, y - k, LEAF[1 + (k % 4 == 0)], True)
			if k < tall * 0.4 and k % 4 == 1:
				self.leaf(x + 2, y - k, LEAF)
				self.leaf(x - 2, y - k - 1, LEAF, flip=True)
			elif k >= tall * 0.4 and k % 3 == 0:
				self.flower(x + rng.choice((-1, 1)), y - k, ramp, centre=ramp[3] if len(ramp) > 3 else WHITE[2])
		self.put(x, y - tall, LEAF[3], True)

	def birdhouse(self, x, y):
		rows = [
			"...xx...",
			"..x55x..",
			".x5543x.",
			"x544433x",
			".x3332x.",
			".x3oo2x.",
			".x3oo1x.",
			".x2211x.",
			"..xxxx..",
			"...xx...",
		]
		ramp = [SHUT[0], SHUT[1], SHUT[2], SHUT[3], WALL[5], WALL[6]]
		for j, row in enumerate(rows):
			for i, ch in enumerate(row):
				if ch == ".":
					continue
				c = INK if ch == "x" else HOLE[0] if ch == "o" else ramp[int(ch)]
				self.put(x + i - 4, y + j, c, True)
		self.put(x + 2, y + 7, WALL[5], True)  # the perch

	def bush(self, cx, by, r, rng, buds=None):
		"""A round shrub standing on by, lit from the right."""
		cy = by - r * 0.85
		for y in range(int(by - r * 1.8), int(by) + 1):
			for x in range(int(cx - r - 1), int(cx + r + 2)):
				dx, dy = (x - cx) / (r + 0.5), (y - cy) / (r * 0.9)
				if dx * dx + dy * dy > 1 - ((x * 13 + y * 7) % 5) * 0.04:
					continue
				shade = -dx * 0.6 + dy * 0.8
				t = 3 if shade < -0.35 else 2 if shade < 0.35 else 1
				if (x * 7 + y * 11) % 9 == 0:
					t = min(4, t + 1)
				self.put(x, y, LEAF[t], True)
		if buds:
			for _ in range(4):
				self.flower(int(cx + rng.uniform(-r + 1, r - 1)), int(cy + rng.uniform(-r + 1, 0)), buds)

	def raceme(self, x, y, ramp):
		"""A drooping cluster of blooms hanging from (x, y)."""
		for dx, dy, t in ((-1, 0, 1), (0, 0, 2), (1, 0, 2), (-1, 1, 0), (0, 1, 2), (1, 1, 1),
				(0, 2, 1), (1, 2, 3), (0, 3, 0)):
			self.put(x + dx, y + dy, ramp[t], True)

	def strand(self, x, y, n, rng, bloom):
		"""A vine falling from (x, y), leaves on alternate sides, a bloom at its end."""
		px = x
		for k in range(n):
			if k and k % 3 == 0:
				px += rng.choice((-1, 0, 0, 1)) * 0.5
			self.put(px, y + k, LEAF[1 + (k % 2 == 0)], True)
			if k % 3 == 1:
				side = 1 if (k // 3) % 2 else -1
				self.put(px + side, y + k, LEAF[3], True)
				self.put(px + side, y + k + 1, LEAF[2], True)
				self.put(px + side * 2, y + k + 1, LEAF[1], True)
		if bloom == "wisteria":
			self.raceme(int(round(px)), y + n, WISTERIA)
		elif bloom:
			self.flower(int(round(px)), y + n + 1, bloom)

	def climb(self, x, y, tx, ty, rng, blooms, every=5, leafy=3, keep=None):
		"""A vine from (x, y) towards (tx, ty), leafing as it goes; stops where keep runs out."""
		n = int(max(abs(tx - x), abs(ty - y)))
		px, py = x, y
		for k in range(n):
			px += (tx - x) / n + rng.uniform(-0.3, 0.3)
			py += (ty - y) / n + rng.uniform(-0.2, 0.2)
			if keep is not None and not keep[int(round(py)) % H, int(round(px)) % W]:
				break
			self.put(px, py, LEAF[1], True)
			if k % leafy == 1:
				side = 1 if (k // 3) % 2 else -1
				self.leaf(px + side * 2, py, LEAF, flip=side < 0, size=k)
			if blooms and k % every == every - 1:
				self.flower(px - 1, py - 1, blooms)
		return px, py

	def nature(self):
		lvl = self.lvl
		rng = random.Random(self.seed + 500 + lvl)
		fb, gb = self.front_base, self.gable_base
		x0, xn, xr = int(self.wall_bl[0]), int(self.near_b[0]), int(self.right_b[0])
		dl, dr = DOOR
		if lvl == 0:
			# overgrown: weeds and dock all along both walls, dead ivy, mushrooms, a web
			for x in range(x0 + 1, xr - 1, 3):
				if dl - 1 <= x <= dr + 1:
					continue
				base = (fb(x) if x <= xn else gb(x)) - 2
				ramp = DEAD if rng.random() < 0.35 else LEAF[:4]
				self.tuft(x, base, rng.randint(5, 11), ramp, lean=rng.choice((-1, 0, 1)))
				if rng.random() < 0.25:
					self.put(x, base - rng.randint(9, 12), DEAD[3], True)  # seed head
			for x in (xn - 9, xn + 6, x0 + 6):
				base = (fb(x) if x <= xn else gb(x)) - 3
				self.leaf(x, base - 3, LEAF[:4] + [LEAF[3]], size=0)
				self.leaf(x + 3, base - 1, LEAF, flip=True, size=1)
			self.vine(xn - 2, fb(xn - 2) - 4, 30, rng, dead=True, lean=0.05)
			self.vine(xn + 9, gb(xn + 9) - 4, 22, rng, dead=True, lean=0.1)
			for x, big in ((xn - 5, True), (xn - 3, False), (xn + 14, False), (x0 + 12, False)):
				self.mushroom(x, (fb(x) if x <= xn else gb(x)) - 3, big)
			self.cobweb()
		if lvl >= 1:
			# trimmed: short grass, ivy climbing the near corner, pots by the door
			for x in range(x0 + 2, xr - 1, 5):
				if dl - 1 <= x <= dr + 1:
					continue
				base = (fb(x) if x <= xn else gb(x)) - 2
				self.tuft(x, base, rng.randint(3, 4), LEAF)
			tall = 26 if lvl == 1 else 58
			end = self.vine(xn - 2, fb(xn - 2) - 3, tall, rng, lean=0.0,
				blooms=None if lvl == 1 else WHITE, leafy=3)
			self.vine(xn + 3, gb(xn + 3) - 3, tall - 8, rng, lean=0.15,
				blooms=None if lvl == 1 else WHITE, leafy=3)
			if lvl == 1:
				self.pot(int(dr) + 6, int(fb(dr + 6)) - 2, "sprout", rng)
				self.pot(int(dr) + 14, int(fb(dr + 14)) - 2, "fern", rng)
				# a watering can
				wx = int(dr) + 22
				wy = int(fb(wx)) - 3
				rows = ["..x.....", ".x2xxx..", "x1222x.x", "x1112xx.", "x0001x..", ".xxxx..."]
				grey = [(80, 86, 94), (130, 138, 146), (186, 194, 200)]
				for j, row in enumerate(rows):
					for i, ch in enumerate(row):
						if ch != ".":
							self.put(wx + i - 3, wy - 5 + j, INK if ch == "x" else grey[int(ch)], True)
				# shrubs at the walls' ends, a young rose by the door, daisies in the grass
				self.bush(x0 + 7, fb(x0 + 7) - 2, 5, rng, buds=PINK)
				self.bush(xr - 8, gb(xr - 8) - 2, 5, rng, buds=WHITE)
				self.bush(xn + 20, gb(xn + 20) - 2, 4, rng)
				self.vine(int(dl) - 1, fb(dl - 1) - 2, 16, rng, blooms=PINK, leafy=3)
				for x in range(x0 + 14, xr - 12, 6):
					if dl - 2 <= x <= dr + 26 or abs(x - (xn + 20)) < 6:
						continue
					base = (fb(x) if x <= xn else gb(x)) - 2
					for k in range(1, 4):
						self.put(x, base - k, LEAF[2], True)
					self.flower(x, base - 5, WHITE if x % 12 < 6 else YELLOW + [YELLOW[2]])
		if lvl == 2:
			# cosy: roses over the door, ivy along the eave, hollyhocks, a flower box, a birdhouse
			for side, sx in ((-1, int(dl) - 1), (1, int(dr) + 1)):
				top = self.vine(sx, fb(sx) - 2, DOOR_TALL + 2, rng, blooms=PINK, leafy=3)
			for k in range(int(dr - dl) + 4):
				x = int(dl) - 2 + k
				y = fb(x) - DOOR_TALL - 3 - (2 if 4 < k < dr - dl - 2 else 0) - (k % 3 == 0)
				self.put(x, y, LEAF[1], True)
				if k % 3 == 1:
					self.leaf(x, y - 1, LEAF, flip=k % 2 == 0, size=k)
				if k % 4 == 2:
					self.flower(x, y - 2, PINK)
			# the corner ivy climbs onto the roof, up beside the barge, with a side shoot
			cx, cy = self.near_b[0] - 3, self.eave(self.near_b[0] - 3) - 1
			self.climb(cx, cy, self.ridge_r[0] - 5, self.ridge_r[1] + 10, rng, WHITE, every=6)
			# branches climbing the roof from its edge, up towards the ridge
			up = (self.ridge_r[0] - self.eave_r[0], self.ridge_r[1] - self.eave_r[1])
			for off, reach, lean, bl in ((4, 0.62, -0.10, PINK), (11, 0.5, -0.04, WHITE),
					(19, 0.42, 0.04, PINK), (28, 0.3, -0.06, WHITE), (38, 0.2, 0.0, PINK),
					(52, 0.14, 0.0, WHITE), (66, 0.1, 0.0, PINK)):
				sx = self.near_b[0] - off
				sy = self.eave(sx) - 2
				tx = sx + up[0] * reach + up[1] * lean * reach * 2
				ty = sy + up[1] * reach
				self.climb(sx, sy, tx, ty, rng, bl, every=4, leafy=2, keep=self.roof)
			# and runs along the roof's edge, dropping strands over the fascia
			px = self.near_b[0] - 4
			k = 0
			while px > self.eave_l[0] + 8:
				y = self.eave(px) - 2 + (k % 4 == 1)
				self.put(px, y, LEAF[1], True)
				if k % 3 == 0:
					self.leaf(px, y - 1, LEAF, flip=k % 2 == 0, size=k)
				if k % 7 == 3:
					over_door = dl - 3 <= px <= dr + 5
					n = rng.randint(2, 3) if over_door else rng.randint(5, 13)
					self.strand(px, self.eave(px) + 3, n, rng, "wisteria" if k % 14 == 3 else PINK)
				px -= 1
				k += 1
			# a few strands off the barge onto the gable, clear of the window
			for t, n in ((0.18, 7), (0.8, 6)):
				bx = self.eave_r[0] + (self.ridge_r[0] - self.eave_r[0]) * t + 3
				by = self.eave_r[1] + (self.ridge_r[1] - self.eave_r[1]) * t + 1
				self.strand(bx, by, n, rng, "wisteria")
			# hollyhocks against the gable, either side of the window's drop
			for hx, ramp, tall in ((xn + 14, PINK, 24), (xr - 6, PINK, 30), (xr - 11, WHITE, 22)):
				self.hollyhock(hx, gb(hx) - 3, tall, ramp, rng)
			# pots with flowers by the door
			self.pot(int(dr) + 7, int(fb(dr + 7)) - 2, YELLOW, rng)
			self.pot(int(dr) + 15, int(fb(dr + 15)) - 2, BLUE, rng)
			self.pot(int(dl) - 7, int(fb(dl - 7)) - 2, "fern", rng)
			# flowers in the grass along both walls
			for x in range(x0 + 3, xr - 2, 4):
				if dl - 2 <= x <= dr + 18:
					continue
				base = (fb(x) if x <= xn else gb(x)) - 2
				self.tuft(x, base, 3, LEAF)
				if x % 8 == 3:
					self.flower(x, base - 4, (YELLOW + [YELLOW[2]]) if x % 16 == 3 else BLUE, centre=WHITE[2])
			# flower box under the window, trailing
			wx, wy, hw, hh, gs = self.win
			for i in range(-hw - 2, hw + 3):
				x = wx + i
				y = wy + hh + 3 + i * gs
				for dy, t in ((0, 5), (1, 3), (2, 3), (3, 2)):
					self.put(x, y + dy, WALL[t], True)
				self.put(x, y + 4, INK, True)
				if (i + hw) % 3 == 0:
					self.leaf(x, y - 1, LEAF, flip=i < 0, size=i)
				if (i + hw) % 3 == 1:
					self.flower(x, y - 3, (RED, YELLOW + [YELLOW[2]], WHITE)[(i + 9) % 3])
				if (i + hw) % 4 == 1:
					for k in range(1, 5 + (i % 3)):
						self.put(x, y + 3 + k, LEAF[1 + (k % 2)], True)
			# a lantern by the door and a birdhouse up the gable
			lx = int(dr) + 4
			ly = int(fb(lx)) - DOOR_TALL - 1
			rows = [".x.", "xmx", "xgx", "xyx", "xgx", "xmx", ".x."]
			cols = {"x": INK, "m": (70, 70, 74), "g": (255, 200, 100), "y": (255, 244, 190)}
			for j, row in enumerate(rows):
				for i, ch in enumerate(row):
					if ch != ".":
						self.put(lx + i - 1, ly + j, cols[ch])
			self.birdhouse(int(self.ridge_r[0]) + 2, int(self.ridge_r[1]) + 14)

	def outline(self):
		a = self.cv.c[:, :, 3] > 0
		edge = np.zeros_like(a)
		edge[1:, :] |= ~a[:-1, :]
		edge[:-1, :] |= ~a[1:, :]
		edge[:, 1:] |= ~a[:, :-1]
		edge[:, :-1] |= ~a[:, 1:]
		edge &= a
		self.cv.c[edge, :3] = INK


def draw(stage):
	return Hut(stage).build()


def sheet(out):
	grass = (82, 120, 60, 255)
	old = Image.open("art_source/shed_paint.png").convert("RGBA")
	old = old.resize((round(old.width * K), round(old.height * K)), Image.NEAREST)
	pics = [draw(s)[0] for s in STAGES]
	z = 4
	cw = W * z + 16
	im = Image.new("RGBA", (cw * 3, 40 + H * z + 40 + H * 2 + 40), (40, 44, 40, 255))
	d = ImageDraw.Draw(im)
	for i, (s, p) in enumerate(zip(STAGES, pics)):
		bg = Image.new("RGBA", (W * z, H * z), grass)
		bg.alpha_composite(p.resize((W * z, H * z), Image.NEAREST))
		im.alpha_composite(bg, (i * cw + 8, 24))
		d.text((i * cw + 8, 6), f"{i + 1}: {s}  (x{z})", fill=(230, 230, 230))
	# play size: x1 and x2 beside the angler and the old hut
	y0 = 40 + H * z + 30
	d.text((8, y0 - 18), "play size: old, then the three stages, x1 and x2, angler for scale", fill=(230, 230, 230))
	char = Image.open("assets/character.png").convert("RGBA").crop((0, 0, 44, 50))
	strip = Image.new("RGBA", (im.width - 16, H * 2 + 10), grass)
	x = 4
	for p in [old] + pics:
		strip.alpha_composite(p, (x, H * 2 + 10 - p.height - 4))
		x += p.width + 6
	strip.alpha_composite(char, (x, H * 2 + 10 - 54))
	x += 60
	for p in pics:
		big = p.resize((W * 2, H * 2), Image.NEAREST)
		if x + big.width > strip.width:
			break
		strip.alpha_composite(big, (x, 4))
		x += big.width + 6
	im.alpha_composite(strip, (8, y0))
	im.save(out)


if __name__ == "__main__":
	ap = argparse.ArgumentParser()
	ap.add_argument("--write", action="store_true", help="overwrite the art_source pictures")
	ap.add_argument("--ship", action="store_true", help="copy the art_source pictures to assets")
	args = ap.parse_args()
	if args.write:
		for s in STAGES:
			img, glow = draw(s)
			img.save(f"art_source/shed_v2_{s}.png")
		mask = np.zeros((H, W, 4), np.uint8)
		mask[glow] = (255, 255, 255, 255)
		Image.fromarray(mask, "RGBA").save("art_source/shed_v2_glow.png")
	if args.ship:
		# What the game draws is a straight copy of art_source, so a hand polish there survives
		# the next run of --ship and only --write throws it away.
		for s in STAGES + ("glow",):
			Image.open(f"art_source/shed_v2_{s}.png").save(f"assets/shed_{s}.png")
	if not args.ship or args.write:
		sheet("tools/last_shed_mockup.png")
