## The bee's pictures: one sheet, read once, drawn by whoever needs a bee.
##
## There are bees all over this game since the hive's visual overhaul (2026-10-18, Richard's
## pick: bee "A", the coin bee, off `tools/hive_look/last_bee.png`): the swarm on the island and
## the ones at the flowers, the clumps in the catch, the beard in the smoke, the workers on the
## brood frame and their queen, the loose bees in every step, the card icons. They are driven
## by completely different code and none of it should learn to read a sprite sheet, so the
## sheet lives here, static, loaded on the first ask and shared from then on — `DogArt`'s
## bargain for the dogs.
##
## `tools/build_bees.py` bakes `assets/bees.png` and `assets/bees.json` straight from the
## mockups' own `tools/hive_look/look.py` (variant A only): change the bee there, run the
## builder, reimport. What is on the sheet, every frame facing RIGHT on a fixed canvas a kind:
##
##   worker_fly0..5      wings up / mid / down, a one-px bob on 3-5        16 x 16
##   worker_hover0..2    the same wings, no bob (held in a clump, at a flower)
##   worker_walk0..1     crawling, wings folded
##   worker_rest0..3     landed; 3 blinks
##   worker_walkback0..1 / worker_restback0..3   the same seen from behind (no face)
##   mini_fly0..5, mini_rest0                    the lake's round bee      12 x 11
##   queen_walk0..1, queen_lay0                  the queen with her crown  21 x 16
##
## **The anchor is the middle of the body**, and it is where `at` puts the bee: every frame of
## a kind lines up on it, the bob included, so a bee is stood on one point however it flaps.
##
## **Nothing here sets a canvas transform** (`HiveArt`'s rule): a mirrored or turned bee is the
## same quad with its texture coordinates moved round, so a caller drawing under a transform of
## its own (the queen step's lens) keeps it. A quarter turn is exact on the pixel grid.
##
## **It never errors.** With no sheet (a headless run before an import) every draw draws
## nothing and returns an empty rect; what the json says is still read.
class_name BeeArt
extends RefCounted

const SHEET := "res://assets/bees.png"
const CONTRACT := "res://assets/bees.json"

static var _loaded := false
static var _sheet: Texture2D = null
## Frame name -> {"rect": Rect2 on the sheet, "anchor": Vector2 in the frame}.
static var _frames := {}
## Animation name ("worker_fly") -> how many frames, and how long one is held (seconds).
static var _loops := {}
static var _held := {}


## Read the sheet and its json, once. Anything missing is left empty and nothing is raised.
static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_sheet = Art.texture(SHEET)
	if not FileAccess.file_exists(CONTRACT):
		return
	var book: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT))
	if not (book is Dictionary):
		return
	var frames: Variant = (book as Dictionary).get("frames", {})
	if frames is Dictionary:
		for key: Variant in (frames as Dictionary).keys():
			var entry: Variant = (frames as Dictionary)[key]
			if not (entry is Dictionary):
				continue
			var cut: Variant = (entry as Dictionary).get("rect", [])
			var mark: Variant = (entry as Dictionary).get("anchor", [])
			if not (cut is Array) or (cut as Array).size() < 4:
				continue
			_frames[StringName(str(key))] = {
				"rect": Rect2(float(cut[0]), float(cut[1]), float(cut[2]), float(cut[3])),
				"anchor": Vector2(float(mark[0]), float(mark[1])) if mark is Array and (mark as Array).size() >= 2 else Vector2.ZERO,
			}
	for field: String in ["loops", "held"]:
		var table: Variant = (book as Dictionary).get(field, {})
		if not (table is Dictionary):
			continue
		for key: Variant in (table as Dictionary).keys():
			if field == "loops":
				_loops[StringName(str(key))] = int((table as Dictionary)[key])
			else:
				_held[StringName(str(key))] = float((table as Dictionary)[key])


## Forget what was loaded, so the next ask reads the files again (a harness that reimports).
static func forget() -> void:
	_loaded = false
	_sheet = null
	_frames = {}
	_loops = {}
	_held = {}


## True when the sheet is there to draw with.
static func ready() -> bool:
	_load()
	return _sheet != null and not _frames.is_empty()


static func sheet() -> Texture2D:
	_load()
	return _sheet


## Is there a frame of this name (`&"worker_fly3"`)?
static func has(name: StringName) -> bool:
	_load()
	return _frames.has(name)


## How many frames an animation has (`&"worker_fly"` -> 6). Zero for one the sheet lacks.
static func length(anim: StringName) -> int:
	_load()
	return int(_loops.get(anim, 0))


## How long the builder suggests a frame of an animation is held, in seconds.
static func held(anim: StringName) -> float:
	_load()
	return float(_held.get(anim, 0.1))


## The name of frame `frame` of an animation, wrapped round its loop: (`&"worker_fly"`, 7) ->
## `&"worker_fly1"`.
static func frame_name(anim: StringName, frame: int) -> StringName:
	var count := maxi(length(anim), 1)
	return StringName("%s%d" % [anim, posmod(frame, count)])


## Which frame of an animation shows at `age` seconds; `hold` overrides the json's hold.
static func frame_at(anim: StringName, age: float, hold := -1.0) -> int:
	var count := length(anim)
	if count <= 0:
		return 0
	var each := hold if hold > 0.0 else held(anim)
	return posmod(int(floorf(age / maxf(each, 0.001))), count)


## A frame's size in sheet pixels (its whole canvas), and where on the sheet it is.
static func size(name: StringName) -> Vector2:
	_load()
	return (_frames[name]["rect"] as Rect2).size if _frames.has(name) else Vector2.ZERO


static func region(name: StringName) -> Rect2:
	_load()
	return _frames[name]["rect"] if _frames.has(name) else Rect2()


## The body's middle inside a frame, in sheet pixels, mirrored when the bee faces left.
static func anchor(name: StringName, facing_left := false) -> Vector2:
	_load()
	if not _frames.has(name):
		return Vector2.ZERO
	var mark: Vector2 = _frames[name]["anchor"]
	if facing_left:
		mark.x = size(name).x - 1.0 - mark.x
	return mark


## Draw a frame with the body's middle on `at`, each sheet pixel `scale` canvas pixels.
##
## `facing_left` mirrors it (the sheet faces right). `turn` is quarter turns ANTICLOCKWISE
## about the body's middle, after the mirror (look.py's own order): 1 is a right-facing bee
## crawling up a comb, 3 crawling down. `at` is not snapped: snap it first where a bee should
## sit on the grid. Returns the box drawn, in canvas pixels.
static func draw(
	ci: CanvasItem, name: StringName, at: Vector2, facing_left := false, scale := 1.0,
	turn := 0, tint := Color.WHITE
) -> Rect2:
	_load()
	if ci == null or not _frames.has(name):
		return Rect2()
	var cut: Rect2 = _frames[name]["rect"]
	var mark := anchor(name, facing_left)
	var box := Rect2(at - mark * scale, cut.size * scale)
	if _sheet == null or tint.a <= 0.0:
		return box
	turn = posmod(turn, 4)
	if not facing_left and turn == 0:
		ci.draw_texture_rect_region(_sheet, box, cut, tint)
		return box
	var whole := _sheet.get_size()
	var u0 := cut.position.x / whole.x
	var u1 := cut.end.x / whole.x
	var v0 := cut.position.y / whole.y
	var v1 := cut.end.y / whole.y
	if facing_left:
		var swap := u0
		u0 = u1
		u1 = swap
	var corners := [
		box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)
	]
	var points := PackedVector2Array()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for corner: Vector2 in corners:
		var p := at + _turned(corner - at, turn)
		points.append(p)
		lo = lo.min(p)
		hi = hi.max(p)
	ci.draw_primitive(
		points, PackedColorArray([tint, tint, tint, tint]),
		PackedVector2Array([Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)]),
		_sheet
	)
	return Rect2(lo, hi - lo)


## `draw` by animation and frame number: (`&"worker_fly"`, 4) draws `worker_fly4`, wrapped.
static func stamp(
	ci: CanvasItem, anim: StringName, frame: int, at: Vector2, facing_left := false,
	scale := 1.0, turn := 0, tint := Color.WHITE
) -> Rect2:
	return draw(ci, frame_name(anim, frame), at, facing_left, scale, turn, tint)


## `stamp` at an age in seconds, on the json's hold (or `hold`): a bee that only needs to look
## alive. Hand each bee its own phase in `age` so a clump does not flap in step.
static func animate(
	ci: CanvasItem, anim: StringName, age: float, at: Vector2, facing_left := false,
	scale := 1.0, turn := 0, tint := Color.WHITE, hold := -1.0
) -> Rect2:
	return stamp(ci, anim, frame_at(anim, age, hold), at, facing_left, scale, turn, tint)


## One frame as a picture something else can draw: the sheet and the rectangle on it.
static func art_frame(name: StringName) -> Dictionary:
	_load()
	if _sheet == null or not _frames.has(name):
		return {}
	return {"sheet": _sheet, "region": _frames[name]["rect"], "anchor": _frames[name]["anchor"]}


## A screen offset turned `turn` quarter turns anticlockwise (y runs down the screen).
static func _turned(v: Vector2, turn: int) -> Vector2:
	match turn:
		1:
			return Vector2(v.y, -v.x)
		2:
			return Vector2(-v.x, -v.y)
		3:
			return Vector2(-v.y, v.x)
	return v
