## The honey pot: one jar, drawn the same wherever the game shows it.
##
## Richard (2026-10-18, the hive's visual overhaul): "make sure to use the same honey pot as the
## other scenes". The jar is the bottling jar of the pour sheet's option B
## (`tools/hive_look/last_pour.png`): pale glass ringed in the outline, lit white down its left
## and blue-grey down its right, honey in the hive's ramp with a shine on it, a paper label with
## red rules and a red honeycomb cell, a gingham cloth lid tied on with oak twine. **A lid means
## a label**: a jar being filled or being eaten is bare glass.
##
## `tools/build_honey_pot.py` bakes `assets/honey_pot.png` and `assets/honey_pot.json` at four
## sizes, each its own drawing at its own grain (never a scaled copy):
##
##   room   the pour step's jars, in layers (26 x 42, feet (13, 41)). Draw, all at the same feet:
##          `room_back<k>` (the glass behind with the honey at level k, `room_level`), then
##          `room_mouth` on an open jar, then `room_front`, then `room_line` on the jar under the
##          gate, then `room_label` and `room_lid` on a sealed one. `room_full` and `room_empty`
##          are composed; `room_payoff` is the finished jar with the finds' gold rim (28 x 44).
##   hud    the jar plate's jar: `hud_sealed`, and `hud_open<k>` (lid off, a dipper standing in
##          it, the honey at level k — the window's hourglass, `hud_level`).
##   cue    the first jar's card icon: `cue_sealed`, `cue_open` (honey heaped out of the mouth),
##          `cue_pop0..2` (its lid tilted on top, 0..2 px up its hop), `cue_lid` alone.
##   shelf  the island cupboard's jar, 7 x 9: `shelf`, and `shelf_shade` on the shaded face.
##
## **`at` is always the jar's feet**: the middle of its bottom outline row. Every frame of one
## size is on one canvas with one feet anchor, so layers stack by being drawn at the same point.
## Like `HiveArt`, nothing here sets a canvas transform, and nothing errors: with no sheet every
## draw draws nothing.
class_name HoneyPot
extends RefCounted

const SHEET := "res://assets/honey_pot.png"
const CONTRACT := "res://assets/honey_pot.json"

static var _loaded := false
static var _sheet: Texture2D = null
## Frame name -> {"rect": Rect2 on the sheet, "anchor": Vector2 (the feet), "size": StringName}.
static var _frames := {}
## Size name -> the builder's geometry for it (canvas, feet, levels, and for the room the honey
## rows, the glass's span on every row, the neck and the fill line). Raw json values.
static var _sizes := {}


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
				"size": StringName(str((entry as Dictionary).get("size", ""))),
			}
	var sizes: Variant = (book as Dictionary).get("sizes", {})
	if sizes is Dictionary:
		for key: Variant in (sizes as Dictionary).keys():
			_sizes[StringName(str(key))] = (sizes as Dictionary)[key]


## Forget what was loaded, so the next ask reads the files again (a harness that reimports).
static func forget() -> void:
	_loaded = false
	_sheet = null
	_frames = {}
	_sizes = {}


static func ready() -> bool:
	_load()
	return _sheet != null and not _frames.is_empty()


static func sheet() -> Texture2D:
	_load()
	return _sheet


static func has(name: StringName) -> bool:
	_load()
	return _frames.has(name)


## A frame's size in sheet pixels, where it is on the sheet, and its feet inside it.
static func size(name: StringName) -> Vector2:
	_load()
	return (_frames[name]["rect"] as Rect2).size if _frames.has(name) else Vector2.ZERO


static func region(name: StringName) -> Rect2:
	_load()
	return _frames[name]["rect"] if _frames.has(name) else Rect2()


static func feet(name: StringName) -> Vector2:
	_load()
	return _frames[name]["anchor"] if _frames.has(name) else Vector2.ZERO


## The builder's geometry for a size (`&"room"`, `&"hud"`, `&"cue"`, `&"shelf"`), as the json
## has it: {} when there is none.
static func geometry(size_name: StringName) -> Dictionary:
	_load()
	var g: Variant = _sizes.get(size_name, {})
	return g if g is Dictionary else {}


## How many honey levels a size bakes (room 28, hud 11): level 0 is empty.
static func levels(size_name: StringName) -> int:
	return int(geometry(size_name).get("levels", 1))


## The room jar's level for a fill of 0..1 (1 is up to the shoulder; the pour's line is
## `room.line_fill`): the builder's own `jar_surface` rounding, so a level drawn here is the
## surface the mockup drew. Over 1 it holds at full and the step draws the crown itself.
static func room_level(fill: float) -> int:
	var g := geometry(&"room")
	var rows: Array = g.get("honey_rows", [13, 39])
	if fill <= 0.0 or rows.size() < 2:
		return 0
	var lo := float(rows[0])
	var hi := float(rows[1])
	var surface := roundi(hi - (hi - lo) * minf(fill, 1.0))
	return clampi(int(hi) - surface + 1, 1, levels(&"room") - 1)


## The HUD jar's level for the share of the window left (0 empty .. 1 full).
static func hud_level(share: float) -> int:
	if share <= 0.0:
		return 0
	var top := levels(&"hud") - 1
	return clampi(int(ceilf(share * float(top))), 1, top)


## Draw a frame with the jar's feet on `at`, each sheet pixel `scale` canvas pixels (the room
## jar at `HiveArt.PIXEL`, the HUD jar at 1, the cue icon at `CueCard.CELL_HINT`, the shelf jar
## at one world px). `at` is not snapped. Returns the box drawn.
static func draw(
	ci: CanvasItem, name: StringName, at: Vector2, scale := 1.0, tint := Color.WHITE
) -> Rect2:
	_load()
	if ci == null or not _frames.has(name):
		return Rect2()
	var cut: Rect2 = _frames[name]["rect"]
	var box := Rect2(at - (_frames[name]["anchor"] as Vector2) * scale, cut.size * scale)
	if _sheet != null and tint.a > 0.0:
		ci.draw_texture_rect_region(_sheet, box, cut, tint)
	return box


## The room jar whole, its layers in order: `fill` 0..1 of honey, `sealed` (label and lid),
## `line` (the dashed fill line), the lid `lid_up` px above its place at `lid_alpha` (dropping
## in). Open and unsealed, the mouth shows. Returns the glass's box.
static func draw_room(
	ci: CanvasItem, at: Vector2, fill: float, sealed := false, line := false, scale := 1.0,
	lid_up := 0.0, lid_alpha := 1.0
) -> Rect2:
	var box := draw(ci, StringName("room_back%d" % room_level(fill)), at, scale)
	if not sealed:
		draw(ci, &"room_mouth", at, scale)
	draw(ci, &"room_front", at, scale)
	if line:
		draw(ci, &"room_line", at, scale)
	if sealed:
		draw(ci, &"room_label", at, scale)
		if lid_alpha > 0.0:
			draw(ci, &"room_lid", at - Vector2(0.0, roundf(lid_up) * scale), scale,
				Color(1.0, 1.0, 1.0, lid_alpha))
	return box


## The HUD jar: **always the sealed pot, label and gingham lid** (2026-10-19, Richard: "Honey
## pot on UI should always look the same"); the window left is the medallion's ring, not the
## jar. `share` is kept for the callers and not read. The `hud_open<k>` frames stay on the
## sheet, drawn by nothing.
static func draw_hud(ci: CanvasItem, at: Vector2, _share := -1.0, scale := 1.0) -> Rect2:
	return draw(ci, &"hud_sealed", at, scale)


## One art frame for callers that blit it themselves: the sheet, the rectangle and the feet.
static func art_frame(name: StringName) -> Dictionary:
	_load()
	if _sheet == null or not _frames.has(name):
		return {}
	return {"sheet": _sheet, "region": _frames[name]["rect"], "feet": _frames[name]["anchor"]}
