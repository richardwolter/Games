class_name Flora
extends Node2D
## The plants that grow back as the lake comes clean: flowers, shrubs and patches on the
## lawns, reeds and pale grass on the beaches, lily pads on the water along the shore.
##
## Decoration only, by decision (2026-09-16): nothing collides with a plant, nothing reads
## one, nothing is saved. What is drawn follows from two things the lake already knows —
## the filth map (is the water beside this spot clean?) and how much of the whole lake is
## clean (`stage`) — so a load lands on the same plants a run would have grown.
##
## Every possible plant is rolled once at build (`_sow`): a spot, a species by the ground it
## stands on, and a rank in 0..1. A plant is *due* when the water nearest it reads clean on
## the map and its rank is under the density the stage buys. Once due it grows in over
## GROW_TIME, staggered by its own delay, and never goes back: the lake cannot get dirtier.
##
## One batch, one draw call, off assets/flora.png (tools/build_flora.py): the island redraws
## every frame, and the rule from Ground's props holds — anything in the hundreds goes in a
## triangle array, never a loop of draw_texture_rect.

const SHEET := "res://assets/flora.png"
const TABLE := "res://assets/flora.json"
## World px to a painted px, the game's own.
const SCALE := 2.0
## How much of the lawn/beach is planted at the end: the share of candidate spots.
const MOST := 0.55
## Candidates per tile on the lawn, the beach, and the water's edge.
const LAWN_SPOTS := 2
const BEACH_SPOTS := 1
const WATER_SPOTS := 1
## Shore band the outer bank's plants live in, tiles out of the water: the shores are where
## the eye is, and a wood full of flowers a screen from any water is not "the lake coming
## back".
const BANK_REACH := 7.0
## Lily pads: this far past the drawn water's edge, in tiles, and no further.
const PAD_OUT := Vector2(0.5, 1.6)
## Seconds a plant takes to arrive, and the most its own delay can add.
const GROW_TIME := 3.5
const GROW_STAGGER := 2.5
## A sprout shows until this far through the grow; the full picture rises after.
const SPROUT_UNTIL := 0.4
## How far the filth map is followed to find "the water beside this spot", in tiles.
const WATER_LOOK := 9
## The map's byte under which water is clean enough for something to grow beside it. The
## shader's first cutoff, clean to hazy, is on the bent value (LakeGrid.water_state); this
## asks the same.
const SEED := 20260916

var grid: LakeGrid
var grounds: Array[Ground] = []
var crate_tile := Vector2.INF
## 0..1, the share of the lake's water that reads clean. Set by `refresh`.
var stage: float = 0.0

var _sheet: Texture2D
var _table: Dictionary = {}
## Parallel arrays, one entry a candidate, in painter's order (by foot y).
var _foot := PackedVector2Array()
var _rank := PackedFloat32Array()
var _delay := PackedFloat32Array()
var _species := PackedStringArray()
var _water_index := PackedInt32Array()
## -1 not due, otherwise seconds since it became due.
var _age := PackedFloat32Array()
var _growing := 0
var _alive := 0

var _points := PackedVector2Array()
var _uvs := PackedVector2Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()
var _dirty := true


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 3
	z_as_relative = false
	_sheet = load(SHEET) as Texture2D
	if FileAccess.file_exists(TABLE):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(TABLE))
		if parsed is Dictionary:
			_table = parsed
	if grid != null and _sheet != null and not _table.is_empty():
		_sow()
	set_process(false)


## Whether the art is in the project and read.
func ready_to_grow() -> bool:
	return _sheet != null and not _table.is_empty() and not _foot.is_empty()


func candidate_count() -> int:
	return _foot.size()


func alive_count() -> int:
	return _alive


## Where the k-th plant stands (tile coordinates) and what it is. For the harness.
func candidate(k: int) -> Dictionary:
	return {
		"tile": Iso.world_to_tile(_foot[k]), "species": _species[k],
		"kind": String(_table[_species[k]]["kind"]), "alive": _age[k] >= 0.0,
	}


## Forget everything that has grown. For the harness, which refills the lake; a run never
## goes backwards.
func reset() -> void:
	_age.fill(-1.0)
	_growing = 0
	_alive = 0
	_dirty = true
	set_process(false)
	queue_redraw()


## The lake's clean share changed, or the map did: see what is due now.
func refresh(clean_share: float) -> void:
	stage = clean_share
	if grid == null or grid.filth.is_empty():
		return
	var density := clampf(stage, 0.0, 1.0) * MOST
	for k in _foot.size():
		if _age[k] >= 0.0:
			continue
		if _rank[k] >= density:
			continue
		if grid.water_state(_water_index[k]) != 0:
			continue
		_age[k] = 0.0
		_growing += 1
		_alive += 1
	if _growing > 0:
		set_process(true)
	_dirty = true
	queue_redraw()


func _process(delta: float) -> void:
	var still := 0
	for k in _age.size():
		if _age[k] < 0.0:
			continue
		var done := _delay[k] + GROW_TIME
		if _age[k] >= done:
			continue
		_age[k] += delta
		still += 1
	_growing = still
	_dirty = true
	queue_redraw()
	if still == 0:
		set_process(false)


## Every spot a plant could stand, rolled once. Lawn and beach tiles of both grounds within
## the shore band, and the ring of water just off each shore for the pads.
func _sow() -> void:
	var entries: Array = []
	for tx in Iso.COLS:
		for ty in Iso.ROWS:
			var kinds := _kinds_at(tx, ty)
			for spot in kinds.size():
				var kind: String = kinds[spot]
				var per := LAWN_SPOTS if kind == "lawn" else (BEACH_SPOTS if kind == "beach" else WATER_SPOTS)
				for n in per:
					var at := Vector2(
						float(tx) + 0.1 + 0.8 * _hash(float(tx) * 3.3 + float(n) * 7.1, float(ty) * 1.9 + 2.0),
						float(ty) + 0.1 + 0.8 * _hash(float(ty) * 5.7 + float(n) * 2.3, float(tx) * 4.1 - 1.0)
					)
					var here := _kind_at(at)
					if here != kind:
						continue
					if Iso.in_shed(at.x, at.y, Iso.SHED_COVER):
						continue
					if Pump.covers(at, 0.5):
						continue
					if crate_tile != Vector2.INF and Yard.covers(crate_tile, at, 0.6):
						continue
					var water := _water_beside(at, kind)
					if water < 0:
						continue
					var species := _pick_species(kind, at)
					if species.is_empty():
						continue
					entries.append([Iso.tile_to_world(at.x, at.y), _hash(at.x * 9.7, at.y * 6.3),
						_hash(at.y * 2.9, at.x * 8.1) * GROW_STAGGER, species, water])
	entries.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as Vector2).y < (b[0] as Vector2).y)
	for e: Array in entries:
		_foot.append(e[0])
		_rank.append(e[1])
		_delay.append(e[2])
		_species.append(e[3])
		_water_index.append(e[4])
		_age.append(-1.0)


## What may grow on a tile, by its middle: none, or a list of kinds. Water gets a pad
## candidate only along the shores.
func _kinds_at(tx: int, ty: int) -> Array:
	var at := Vector2(float(tx) + 0.5, float(ty) + 0.5)
	var kind := _kind_at(at)
	if kind.is_empty():
		return []
	return [kind]


## "lawn", "beach", "water" or "" for a spot on the plane.
func _kind_at(at: Vector2) -> String:
	for ground in grounds:
		var k := ground.kind_at(at.x, at.y)
		if k == Ground.Kind.NONE or k == Ground.Kind.WATER:
			continue
		if ground.layer == Ground.Layer.OUTSIDE:
			var out := Ground.out_of_water(at.x, at.y)
			# Past the shore band, or on the sand that runs out under the water.
			if out > BANK_REACH or out < 0.3:
				return ""
		elif Iso.past_shelf(at) > -0.6:
			# The island's drowned sand, as its tufts are kept off it.
			return ""
		return "lawn" if k == Ground.Kind.GRASS else "beach"
	# Not ground: the water just off a shore is a pad's.
	var tile := Vector2i(int(floor(at.x)), int(floor(at.y)))
	if not Iso.in_lake(tile.x, tile.y):
		return ""
	var shelf := Iso.past_shelf(at)
	if shelf > PAD_OUT.x and shelf < PAD_OUT.y:
		return "water"
	var out := -Ground.out_of_water(at.x, at.y)
	if out > PAD_OUT.x + 1.0 and out < PAD_OUT.y + 1.0:
		return "water"
	return ""


## The index of the water tile this spot answers to: itself if it is water, else the first
## lake tile walking out from the shore it stands on. -1 if none within WATER_LOOK.
func _water_beside(at: Vector2, kind: String) -> int:
	var tile := Vector2i(int(floor(at.x)), int(floor(at.y)))
	if kind == "water":
		return grid.index_of(tile.x, tile.y)
	var on_island := Iso.island_fraction(at.x, at.y) < 1.0 + 1.5
	var dir: Vector2
	if on_island:
		dir = (at - Iso.ISLAND_CENTRE)
	else:
		dir = (Iso.CENTRE - at)
	if dir.length() < 0.001:
		return -1
	dir = dir.normalized()
	for step in range(1, WATER_LOOK * 2):
		var p := at + dir * float(step) * 0.5
		var t := Vector2i(int(floor(p.x)), int(floor(p.y)))
		if not Iso.in_lake(t.x, t.y):
			continue
		if Iso.shore_fraction(p.x, p.y) < 1.0 and Iso.island_fraction(p.x, p.y) > 1.0 + Iso.SHELF_CLEAR:
			return grid.index_of(t.x, t.y)
	return -1


func _pick_species(kind: String, at: Vector2) -> String:
	var names: Array = []
	var weights: Array = []
	for name: String in _table.keys():
		if String(_table[name]["kind"]) != kind:
			continue
		names.append(name)
		# Shrubs are big and rarer; patches and flowers common.
		weights.append(0.25 if name.begins_with("shrub") else 1.0)
	if names.is_empty():
		return ""
	var total := 0.0
	for w: float in weights:
		total += w
	var roll := _hash(at.x * 4.4 + 1.0, at.y * 7.9 + 3.0) * total
	for i in names.size():
		roll -= weights[i]
		if roll <= 0.0:
			return names[i]
	return names[names.size() - 1]


func _lay() -> void:
	_points.resize(0)
	_uvs.resize(0)
	_colors.resize(0)
	_indices.resize(0)
	var sheet_size := Vector2(_sheet.get_width(), _sheet.get_height())
	for k in _foot.size():
		if _age[k] < 0.0:
			continue
		var t := clampf((_age[k] - _delay[k]) / GROW_TIME, 0.0, 1.0)
		if t <= 0.0:
			continue
		var entry: Dictionary = _table[_species[k]]
		var rect: Array
		var rise: float
		if t < SPROUT_UNTIL:
			rect = entry["sprout"]
			rise = 1.0
		else:
			rect = entry["full"]
			var u := (t - SPROUT_UNTIL) / (1.0 - SPROUT_UNTIL)
			rise = 0.5 + 0.5 * (1.0 - (1.0 - u) * (1.0 - u))
		var w := float(rect[2]) * SCALE
		var h := float(rect[3]) * SCALE * rise
		var foot := _foot[k]
		var box := Rect2(foot - Vector2(w * 0.5, h), Vector2(w, h))
		var uv := Rect2(Vector2(rect[0], rect[1]) / sheet_size, Vector2(rect[2], rect[3]) / sheet_size)
		var base := _points.size()
		_points.append(box.position)
		_points.append(Vector2(box.end.x, box.position.y))
		_points.append(box.end)
		_points.append(Vector2(box.position.x, box.end.y))
		_uvs.append(uv.position)
		_uvs.append(Vector2(uv.end.x, uv.position.y))
		_uvs.append(uv.end)
		_uvs.append(Vector2(uv.position.x, uv.end.y))
		for i in 4:
			_colors.append(Color.WHITE)
		_indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
	_dirty = false


func _draw() -> void:
	if _sheet == null or _foot.is_empty():
		return
	if _dirty:
		_lay()
	if _indices.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(
		get_canvas_item(), _indices, _points, _colors, _uvs,
		PackedInt32Array(), PackedFloat32Array(), _sheet.get_rid()
	)


func _hash(x: float, y: float) -> float:
	var h := sin(x * 127.1 + y * 311.7 + float(SEED) * 0.0001) * 43758.5453
	return h - floor(h)
