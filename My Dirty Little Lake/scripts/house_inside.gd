class_name HouseInside
extends RefCounted
## The house's inside at its three stages (2026-10-11, `/grill-me` with Richard): holes,
## broken boards and leak puddles when the lake is filthy, patched boards and green ivy on the
## frame half way, flowers and bees when it is clean.
##
## Drawn, not computed: `tools/build_house_inside.py` bakes the approved mockup
## (art_source/house_inside/) into assets/house/. Each set is a still layer plus the 8x8 tiles that
## move, one row of tile numbers a frame (`<set>_index.png`), played back here at the bake's
## frame rate. Loops: s1 (stage 1), s1r (stage 1 in a shower), s2, s3. Once: u12, u23 (the
## stage-up, on the next visit). Every picture is on the room's own source grid and is laid
## from `region`'s corner, in placement pixels from the floor box's top-left.
##
## The layout's blocking rects come with it (`walk_blocks`, `place_blocks`): holes and broken
## boards stop walkers and placing, puddles stop placing only.

const DATA := "res://assets/house/house.json"
const ROOT := "res://assets/house/"

static var _data: Dictionary = {}
static var _sets: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(DATA):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		if parsed is Dictionary:
			_data = parsed
	return _data


static func ready_to_draw() -> bool:
	return not data().is_empty()


static func fps() -> float:
	return float(data().get("fps", 12))


## The baked region, (x, y, w, h) in placement px from the floor box's top-left.
static func region() -> Rect2i:
	var r: Array = data().get("region", [0, 0, 0, 0])
	return Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))


static func _rects(stage: int, which: String) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	var by: Dictionary = data().get("blocks", {}).get(str(stage), {})
	for r: Array in by.get(which, []):
		out.append(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
	return out


## Holes and broken boards at `stage`: no walking, no placing. Placement px.
static func walk_blocks(stage: int) -> Array[Rect2i]:
	return _rects(stage, "walk")


## Puddles at `stage`: no placing (walkers splash through). Placement px.
static func puddles(stage: int) -> Array[Rect2i]:
	return _rects(stage, "place")


## Everything a piece may not stand on at `stage`.
static func place_blocks(stage: int) -> Array[Rect2i]:
	var out := walk_blocks(stage)
	out.append_array(puddles(stage))
	return out


## Whether a piece's base (placement px) meets anything it may not stand on at `stage`.
static func base_blocked(stage: int, base: Rect2i) -> bool:
	if base.size.x <= 0 or base.size.y <= 0:
		return false
	for r in place_blocks(stage):
		if r.intersects(base):
			return true
	return false


## The loop shown at a stage, in a shower or not.
static func loop_of(stage: int, rain: bool) -> String:
	if stage <= 1:
		return "s1r" if rain else "s1"
	return "s2" if stage == 2 else "s3"


static func has_set(name: String) -> bool:
	return data().get("sets", {}).has(name)


## One baked set, loaded the first time it is asked for: its two still layers, its tile
## sheet and its frames decoded to tile numbers (0 = an empty tile).
static func set_of(name: String) -> Dictionary:
	if _sets.has(name):
		return _sets[name]
	var meta: Dictionary = data().get("sets", {}).get(name, {})
	if meta.is_empty():
		return {}
	var index_tex: Texture2D = load(ROOT + name + "_index.png")
	var index: Image = index_tex.get_image() if index_tex != null else null
	var frames: int = int(meta["frames"])
	var cols := (meta["under"] as Array).size() + (meta["over"] as Array).size()
	var numbers := PackedInt32Array()
	numbers.resize(frames * cols)
	if index != null:
		if index.is_compressed():
			index.decompress()
		for f in frames:
			for c in cols:
				var px := index.get_pixel(c, f)
				numbers[f * cols + c] = int(round(px.r * 255.0)) + 256 * int(round(px.g * 255.0))
	var drips := {}
	for d: Array in meta.get("drips", []):
		var f := int(d[0])
		if not drips.has(f):
			drips[f] = []
		(drips[f] as Array).append(Vector2(float(d[1]), float(d[2])))
	var out := {
		"frames": frames, "loop": bool(meta.get("loop", true)), "cols": cols,
		"per_row": int(meta.get("per_row", 64)),
		"under_tiles": meta["under"], "over_tiles": meta["over"],
		"under": load(ROOT + name + "_under.png"), "over": load(ROOT + name + "_over.png"),
		"sheet": load(ROOT + name + "_tiles.png"), "numbers": numbers, "drips": drips,
	}
	_sets[name] = out
	return out


## A set's layer on the room, at a frame. Two of these per layer let one set give way to
## another a pixel at a time (`show`, `flip`; the shader keeps a source pixel whose roll is
## under `show`, or over it when flipped), the rain coming and going.
class Layer:
	extends Node2D

	const DISSOLVE := preload("res://shaders/house_dissolve.gdshader")
	## "under" or "over".
	var which := "under"
	var set_name := ""
	var frame := 0
	## Where the region's corner is in the room, and the room's zoom (screen px a source px).
	var origin := Vector2.ZERO
	var zoom := 1.0
	var show_share := 1.0
	var flip := false
	func _ready() -> void:
		var mat := ShaderMaterial.new()
		mat.shader = DISSOLVE
		material = mat
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _draw() -> void:
		var mat := material as ShaderMaterial
		mat.set_shader_parameter(&"show", show_share)
		mat.set_shader_parameter(&"flip", flip)
		mat.set_shader_parameter(&"origin", origin)
		mat.set_shader_parameter(&"px", zoom)
		if set_name.is_empty() or show_share <= 0.0 and not flip or show_share >= 1.0 and flip:
			return
		var s := HouseInside.set_of(set_name)
		if s.is_empty():
			return
		var still: Texture2D = s[which]
		if still != null:
			draw_texture_rect(still, Rect2(origin, Vector2(still.get_size()) * zoom), false)
		var sheet: Texture2D = s["sheet"]
		if sheet == null:
			return
		var tiles: Array = s[which + "_tiles"]
		var numbers: PackedInt32Array = s["numbers"]
		var cols: int = s["cols"]
		var per_row: int = s["per_row"]
		var f := clampi(frame, 0, int(s["frames"]) - 1)
		var first := 0 if which == "under" else (s["under_tiles"] as Array).size()
		var step := 8.0 * zoom
		for k in tiles.size():
			var v := numbers[f * cols + first + k]
			if v <= 0:
				continue
			var t: Array = tiles[k]
			var r := (v - 1) / per_row
			var c := (v - 1) % per_row
			draw_texture_rect_region(
				sheet,
				Rect2(origin + Vector2(float(t[0]), float(t[1])) * step, Vector2(step, step)),
				Rect2(c * 8, r * 8, 8, 8)
			)
