## The hive room's pieces, and the few drawing helpers every step shares (2026-09-30, the
## beehive sidequest; `docs/hive/contract.md` section 4).
##
## **Everything is authored at one painted pixel** and drawn at `PIXEL` canvas pixels to one:
## the room's art grid is 640x360 painted pixels on the 1280x720 design canvas, the mockup's
## own grid (`tools/hive_mockup.py`). The pieces are baked by `tools/build_hive.py` onto
## `assets/hive_room.png`, and `assets/hive_room.json` says where each one is on the sheet and
## where its anchors are inside it — the spout, the landing slot, the queen's white dot. **The
## anchors are the contract, not a guess made here**: a step puts a piece down by saying where
## one of its anchors lands, so a re-bake that moves a spout moves nothing in the code.
##
## **Loaded once and kept for the session**, by the class rather than by a node: six steps and
## the room all read the same sheet, and none of them owns it.
##
## **It never errors.** A harness running headless before an import has no texture to load,
## and a sheet that is missing is a thing to be drawn around, not a crash: with no sheet every
## helper that draws draws nothing and `draw` returns an empty rect. What the json says is
## still read without the texture, so a step can lay itself out and be driven by its hooks.
##
## **Nothing here sets a canvas transform.** A flipped piece is drawn as a quad with its
## texture coordinates swapped rather than through `draw_set_transform`, which replaces the
## transform rather than adding to it: the queen step's lens draws the comb and its bees twice
## the size under a transform of its own, and a helper that reset it would put half the
## comb back at its own size.
class_name HiveArt
extends RefCounted

const SHEET := "res://assets/hive_room.png"
const CONTRACT := "res://assets/hive_room.json"
## Canvas pixels to one painted pixel in the room.
const PIXEL := 2.0
## The room's art grid, in painted pixels: the mockup's 640x360.
const GRID := Vector2(640.0, 360.0)

## The colours the code draws with. **The same numbers as `tools/build_hive.py`**: a honey
## fill that is a shade off the baked jar beside it reads as a different honey. Written as
## the builder's own 0-255 figures over 255, so a retune there is a copy here.
## The honey ramp, deep to shine.
const HONEY_DEEP := Color(150 / 255.0, 72 / 255.0, 12 / 255.0)
const HONEY_MID := Color(206 / 255.0, 120 / 255.0, 22 / 255.0)
const HONEY := Color(238 / 255.0, 164 / 255.0, 38 / 255.0)
const HONEY_LIGHT := Color(252 / 255.0, 204 / 255.0, 84 / 255.0)
const HONEY_SHINE := Color(255 / 255.0, 242 / 255.0, 190 / 255.0)
## Wax.
const WAX := Color(246 / 255.0, 226 / 255.0, 164 / 255.0)
const WAX_LIT := Color(255 / 255.0, 246 / 255.0, 214 / 255.0)
const WAX_SHADE := Color(218 / 255.0, 186 / 255.0, 116 / 255.0)
const WAX_WALL := Color(190 / 255.0, 150 / 255.0, 84 / 255.0)
## A bee drawn in code rather than off the sheet: gold, stripe, thorax, head, and the wings.
const BEE_GOLD := Color(244 / 255.0, 184 / 255.0, 40 / 255.0)
const BEE_STRIPE := Color(44 / 255.0, 30 / 255.0, 20 / 255.0)
## The finds' star gold, the hive's white trim, and the near-black every piece is inked in.
const GOLD := Color(255 / 255.0, 204 / 255.0, 77 / 255.0)
const TRIM := Color(248 / 255.0, 244 / 255.0, 232 / 255.0)
const OUT := Color(24 / 255.0, 18 / 255.0, 17 / 255.0)
## The white a star's middle burns at: the lake's own `LakeGrid.STAR_WHITE`, so a star in
## the room and a star on a find out on the water are one star.
const STAR_WHITE := Color(1.0, 0.97, 0.85)

static var _loaded := false
static var _sheet: Texture2D = null
## Piece name -> {"rect": Rect2 on the sheet, "anchors": {StringName: Vector2}}. Keyed by
## StringName on the way in: a Dictionary does not count a String and a StringName of the
## same letters as one key, and every caller asks with `&"..."`.
static var _pieces := {}
static var _comb := {}


## Read the sheet and its json, once. Anything missing is left empty and nothing is raised.
static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if ResourceLoader.exists(SHEET):
		_sheet = load(SHEET) as Texture2D
	if not FileAccess.file_exists(CONTRACT):
		return
	var book: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT))
	if not (book is Dictionary):
		return
	var pieces: Variant = (book as Dictionary).get("pieces", {})
	if pieces is Dictionary:
		for key: Variant in (pieces as Dictionary).keys():
			var entry: Variant = (pieces as Dictionary)[key]
			if not (entry is Dictionary):
				continue
			var cut: Variant = (entry as Dictionary).get("rect", [])
			if not (cut is Array) or (cut as Array).size() < 4:
				continue
			var anchors := {}
			var marks: Variant = (entry as Dictionary).get("anchors", {})
			if marks is Dictionary:
				for mark: Variant in (marks as Dictionary).keys():
					anchors[StringName(str(mark))] = _vec((marks as Dictionary)[mark])
			_pieces[StringName(str(key))] = {"rect": _rect(cut), "anchors": anchors}
	var comb: Variant = (book as Dictionary).get("comb", {})
	if comb is Dictionary and (comb as Dictionary).has("inner"):
		var inner := _rect((comb as Dictionary)["inner"])
		var pitch := _vec((comb as Dictionary).get("pitch", [8, 7]))
		_comb = {
			"inner": inner,
			"pitch": pitch,
			"offset": float((comb as Dictionary).get("offset", 4)),
			"cell": _vec((comb as Dictionary).get("cell", [7, 8])),
			# Worked out here rather than by every caller: how many whole cells the comb
			# holds across and down. Rows start at the comb's top on both faces.
			"cols": int(floorf(inner.size.x / maxf(pitch.x, 1.0))),
			"rows": int(floorf(inner.size.y / maxf(pitch.y, 1.0))),
		}


static func _vec(value: Variant) -> Vector2:
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


static func _rect(value: Variant) -> Rect2:
	if value is Array and (value as Array).size() >= 4:
		return Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
	return Rect2()


## Forget what was loaded, so the next ask reads the files again. For a harness that
## reimports under a running session; nothing in the game calls it.
static func forget() -> void:
	_loaded = false
	_sheet = null
	_pieces = {}
	_comb = {}


## The room sheet, or null before an import. Drawn nearest by whoever draws it: the room
## sets `texture_filter` once and every step inherits it.
static func sheet() -> Texture2D:
	_load()
	return _sheet


## Whether a piece can be drawn: named in the json **and** the sheet is there to draw it off.
## A step that has a code-drawn stand-in for a piece asks this to decide which to draw.
static func has(name: StringName) -> bool:
	_load()
	return _sheet != null and _pieces.has(name)


## Whether the json names a piece at all, sheet or no sheet: what a layout may lean on.
static func knows(name: StringName) -> bool:
	_load()
	return _pieces.has(name)


## A piece's region on the sheet, or an empty rect.
static func rect(name: StringName) -> Rect2:
	_load()
	var entry: Dictionary = _pieces.get(name, {})
	return entry.get("rect", Rect2())


## A piece's size in painted pixels.
static func size(name: StringName) -> Vector2:
	return rect(name).size


## Where an anchor is inside a piece, in painted pixels from its top left. **`&""` is the
## top left itself**, and an anchor the piece does not carry is its middle — a step asking
## for a mark a re-bake dropped still puts the piece somewhere sensible rather than at the
## corner. Some anchors lie outside the piece on purpose (`extractor`'s `orbit`, above it).
static func anchor(name: StringName, a: StringName) -> Vector2:
	_load()
	if a == &"":
		return Vector2.ZERO
	var entry: Dictionary = _pieces.get(name, {})
	var marks: Dictionary = entry.get("anchors", {})
	if marks.has(a):
		return marks[a]
	return (entry.get("rect", Rect2()) as Rect2).size * 0.5


## Every anchor a piece carries, by name.
static func anchors(name: StringName) -> Dictionary:
	_load()
	var entry: Dictionary = _pieces.get(name, {})
	return (entry.get("anchors", {}) as Dictionary).duplicate()


## The comb's geometry for the uncap step, relative to `frame_capped` (and `frame_open`,
## which is cut to the same box): `inner` (Rect2), `pitch` (Vector2, 8x7), `offset` (the odd
## rows' shove, 4), `cell` (Vector2, 7x8), and `cols`/`rows`. Empty before the json is there.
static func comb() -> Dictionary:
	_load()
	return _comb.duplicate()



## Draw a piece with its anchor `anchor_name` landing on `at`, in the canvas pixels of the
## item drawing (`ci`'s own). `flip` mirrors it about that anchor, for the left-facing bees
## and anything else the sheet carries facing one way only. `scale` multiplies `PIXEL`, for a
## crown popping in; `tint` multiplies the colours. Returns the canvas rect it covered, or an
## empty one when the piece or the sheet is missing (nothing is drawn then).
##
## `at` is not snapped: a moving piece glides between art pixels, the lake's own rule (a
## stepped glide was tried in the lake and judged worse). Snap it first (`snap`) where a
## piece should sit still on the grid.
static func draw(
	ci: CanvasItem, name: StringName, at: Vector2, anchor_name := &"", flip := false,
	alpha := 1.0, scale := 1.0, tint := Color.WHITE
) -> Rect2:
	_load()
	if ci == null or _sheet == null or not _pieces.has(name):
		return Rect2()
	var cut: Rect2 = (_pieces[name] as Dictionary)["rect"]
	if cut.size.x <= 0.0 or cut.size.y <= 0.0:
		return Rect2()
	var grain := PIXEL * scale
	var mark := anchor(name, anchor_name)
	if flip:
		mark.x = cut.size.x - mark.x
	var box := Rect2(at - mark * grain, cut.size * grain)
	# Faded right out it still says where it would be, for a caller hit-testing a piece that
	# is fading in.
	if alpha <= 0.0:
		return box
	var ink := Color(tint.r, tint.g, tint.b, tint.a * alpha)
	if not flip:
		ci.draw_texture_rect_region(_sheet, box, cut, ink)
		return box
	# Mirrored: the same quad with its texture coordinates run right to left. A `Rect2` of
	# negative width does not flip a region, it degenerates (CLAUDE.md, the HUD buttons).
	var sheet_size := _sheet.get_size()
	var u0 := cut.position.x / sheet_size.x
	var u1 := cut.end.x / sheet_size.x
	var v0 := cut.position.y / sheet_size.y
	var v1 := cut.end.y / sheet_size.y
	ci.draw_primitive(
		PackedVector2Array([
			box.position, Vector2(box.end.x, box.position.y), box.end,
			Vector2(box.position.x, box.end.y),
		]),
		PackedColorArray([ink, ink, ink, ink]),
		PackedVector2Array([Vector2(u1, v0), Vector2(u0, v0), Vector2(u0, v1), Vector2(u1, v1)]),
		_sheet
	)
	return box


## Draw part of a piece: `src_local` in painted pixels inside the piece, into `dest` in canvas
## pixels. The uncap step draws the capped face below the cut this way, and the plank fills
## a pip with honey from the bottom up. The source is held inside the piece and `dest` is
## cut back in proportion, so an overhanging ask draws the part that exists.
static func draw_region(
	ci: CanvasItem, name: StringName, dest: Rect2, src_local: Rect2, alpha := 1.0
) -> void:
	_load()
	if ci == null or _sheet == null or not _pieces.has(name) or alpha <= 0.0:
		return
	var cut: Rect2 = (_pieces[name] as Dictionary)["rect"]
	var want := src_local.abs()
	var held := want.intersection(Rect2(Vector2.ZERO, cut.size))
	if held.size.x <= 0.0 or held.size.y <= 0.0 or want.size.x <= 0.0 or want.size.y <= 0.0:
		return
	var per := dest.size / want.size
	var out := Rect2(dest.position + (held.position - want.position) * per, held.size * per)
	ci.draw_texture_rect_region(
		_sheet, out, Rect2(cut.position + held.position, held.size), Color(1.0, 1.0, 1.0, alpha)
	)


## The finds' four-point star, in whole painted pixels: a white middle and `arm` pixels of
## gold each way, each one fainter than the last — `LakeGrid.GlintTwinkle.draw_star`'s own
## shape at the room's grain, so the room's payoffs are the lake's glitter. `at` is snapped.
static func star(ci: CanvasItem, at: Vector2, arm: int, alpha := 1.0) -> void:
	if ci == null or alpha <= 0.0:
		return
	var middle := snap(at)
	var cell := Vector2.ONE * PIXEL
	ci.draw_rect(Rect2(middle, cell), Color(STAR_WHITE.r, STAR_WHITE.g, STAR_WHITE.b, alpha))
	for k in range(1, maxi(arm, 0) + 1):
		var fade := alpha * (1.0 - float(k - 1) / float(arm + 1))
		var ink := GOLD.lerp(STAR_WHITE, 0.35 if k == 1 else 0.0)
		ink.a = fade
		var step := float(k) * PIXEL
		ci.draw_rect(Rect2(middle + Vector2(step, 0.0), cell), ink)
		ci.draw_rect(Rect2(middle + Vector2(-step, 0.0), cell), ink)
		ci.draw_rect(Rect2(middle + Vector2(0.0, step), cell), ink)
		ci.draw_rect(Rect2(middle + Vector2(0.0, -step), cell), ink)


## A run of honey hanging from `at` (its top, canvas pixels) `length_px` painted pixels long,
## with a bead swelling at its foot: a column one painted pixel wide, darker where it leaves
## the edge, and a bead three wide over one, lit on its top. Grows a whole pixel at a time.
static func drip(ci: CanvasItem, at: Vector2, length_px: float, alpha := 1.0) -> void:
	if ci == null or alpha <= 0.0:
		return
	var top := snap(at)
	var cell := Vector2.ONE * PIXEL
	var long := maxi(int(floorf(length_px)), 0)
	for k in long:
		var ink := HONEY_MID if k == 0 else HONEY
		ci.draw_rect(Rect2(top + Vector2(0.0, k * PIXEL), cell), Color(ink.r, ink.g, ink.b, alpha))
	var foot := top + Vector2(0.0, long * PIXEL)
	ci.draw_rect(Rect2(foot + Vector2(-PIXEL, 0.0), cell), Color(HONEY.r, HONEY.g, HONEY.b, alpha))
	ci.draw_rect(Rect2(foot, cell), Color(HONEY_SHINE.r, HONEY_SHINE.g, HONEY_SHINE.b, alpha))
	ci.draw_rect(Rect2(foot + Vector2(PIXEL, 0.0), cell), Color(HONEY.r, HONEY.g, HONEY.b, alpha))
	ci.draw_rect(
		Rect2(foot + Vector2(0.0, PIXEL), cell), Color(HONEY_MID.r, HONEY_MID.g, HONEY_MID.b, alpha)
	)


## One painted pixel, the one `at` falls in.
static func px(ci: CanvasItem, at: Vector2, color: Color) -> void:
	if ci == null or color.a <= 0.0:
		return
	ci.draw_rect(Rect2(snap(at), Vector2.ONE * PIXEL), color)


## A canvas point to the top left of the painted pixel it falls in. The room keeps its art
## grid's origin on a whole painted pixel (`HiveRoom.origin`), so this is the same grid.
static func snap(p: Vector2) -> Vector2:
	return (p / PIXEL).floor() * PIXEL
