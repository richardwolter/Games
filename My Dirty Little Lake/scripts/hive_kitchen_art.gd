## The hive room's harvest kit: the oak honey bucket, the oak V-flume, the hot knife, the
## hive-stack bottling stand, the fence shelf, the brass tap and lever, the prize rosette
## (2026-10-18, the hive's visual overhaul: Richard's option B of the uncap and pour sheets,
## `tools/hive_look/last_uncap.png` and `last_pour.png`, with one oak bucket through both steps).
##
## `tools/build_hive_kitchen.py` bakes `assets/hive_kitchen.png` and `assets/hive_kitchen.json`
## off the mockups' own drawing. The json says where each piece is on the sheet and where its
## anchors are inside it, and for the pieces laid where they stand in the room (`flume_*`,
## `stand`, `bench`) where their top left is on the art grid (`at`). It also carries the
## geometry the steps draw the moving honey on (`data(&"uncap")`, `data(&"bucket")`,
## `data(&"pour")`) and the colours the code draws with (`colour`), so a honey drawn here is the
## honey baked beside it.
##
## `HiveArt`'s rules: one painted pixel drawn at `HiveArt.PIXEL` canvas pixels, loaded once and
## kept for the session, nothing sets a canvas transform, and **nothing errors**: with no sheet
## every draw draws nothing and returns an empty rect, and the json is still read.
class_name HiveKitchenArt
extends RefCounted

const SHEET := "res://assets/hive_kitchen.png"
const CONTRACT := "res://assets/hive_kitchen.json"

static var _loaded := false
static var _sheet: Texture2D = null
static var _pieces := {}
static var _data := {}
static var _colours := {}


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
					anchors[StringName(str(mark))] = vec((marks as Dictionary)[mark])
			_pieces[StringName(str(key))] = {
				"rect": Rect2(float(cut[0]), float(cut[1]), float(cut[2]), float(cut[3])),
				"anchors": anchors,
				"at": vec((entry as Dictionary).get("at", [0, 0])),
			}
	for section: String in ["uncap", "pour", "bucket"]:
		var d: Variant = (book as Dictionary).get(section, {})
		_data[StringName(section)] = d if d is Dictionary else {}
	var cols: Variant = (book as Dictionary).get("colours", {})
	if cols is Dictionary:
		for key: Variant in (cols as Dictionary).keys():
			var c: Variant = (cols as Dictionary)[key]
			if c is Array and (c as Array).size() >= 3:
				_colours[StringName(str(key))] = Color8(int(c[0]), int(c[1]), int(c[2]))
	var turns: Variant = (book as Dictionary).get("lever_turns", [])
	_data[&"lever_turns"] = turns if turns is Array else []


## A json pair `[x, y]` as a Vector2, nought for anything else.
static func vec(value: Variant) -> Vector2:
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


static func forget() -> void:
	_loaded = false
	_sheet = null
	_pieces = {}
	_data = {}
	_colours = {}


static func sheet() -> Texture2D:
	_load()
	return _sheet


## Named in the json and the sheet there to draw it.
static func has(name: StringName) -> bool:
	_load()
	return _sheet != null and _pieces.has(name)


## Named in the json, sheet or no sheet.
static func knows(name: StringName) -> bool:
	_load()
	return _pieces.has(name)


static func size(name: StringName) -> Vector2:
	_load()
	return (_pieces[name]["rect"] as Rect2).size if _pieces.has(name) else Vector2.ZERO


## Where an anchor is inside a piece, painted pixels from its top left (`&""` is the top left).
static func anchor(name: StringName, a: StringName) -> Vector2:
	_load()
	if a == &"" or not _pieces.has(name):
		return Vector2.ZERO
	var marks: Dictionary = _pieces[name]["anchors"]
	return marks.get(a, size(name) * 0.5)


## Where a room-placed piece's top left stands on the art grid.
static func at(name: StringName) -> Vector2:
	_load()
	return _pieces[name]["at"] if _pieces.has(name) else Vector2.ZERO


## A section of the json's geometry (`&"uncap"`, `&"pour"`, `&"bucket"`), {} when missing.
static func data(section: StringName) -> Dictionary:
	_load()
	var d: Variant = _data.get(section, {})
	return d if d is Dictionary else {}


## The lever frames' turns, in frame order.
static func lever_turns() -> Array:
	_load()
	return _data.get(&"lever_turns", [])


## A colour the builder named, or `fallback`.
static func colour(name: StringName, fallback := Color(0.5, 0.5, 0.5)) -> Color:
	_load()
	return _colours.get(name, fallback)


## Draw a piece with its anchor `anchor_name` on `at` (the item's canvas pixels), each painted
## pixel `HiveArt.PIXEL * scale` canvas pixels. Returns the canvas rect it covered.
static func draw(
	ci: CanvasItem, name: StringName, at_canvas: Vector2, anchor_name := &"", alpha := 1.0,
	scale := 1.0, tint := Color.WHITE
) -> Rect2:
	_load()
	if ci == null or not _pieces.has(name):
		return Rect2()
	var cut: Rect2 = _pieces[name]["rect"]
	var grain := HiveArt.PIXEL * scale
	var box := Rect2(at_canvas - anchor(name, anchor_name) * grain, cut.size * grain)
	if _sheet == null or alpha <= 0.0:
		return box
	ci.draw_texture_rect_region(_sheet, box, cut, Color(tint.r, tint.g, tint.b, tint.a * alpha))
	return box
