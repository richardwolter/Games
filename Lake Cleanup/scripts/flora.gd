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
## Open water (2026-09-22): clumps of pads and reeds away from both shores. A spot is in a
## clump where a coarse value noise over `OPEN_CELL` tiles is over `OPEN_AT`, so the pads
## gather in beds rather than peppering the lake. Kept `OPEN_CLEAR` tiles off the yards'
## jetties and berths (`avoid`), where the ferries turn.
const OPEN_CELL := 4.5
const OPEN_AT := 0.6
const OPEN_CLEAR := 3.5
## Bees: at most this many, on the flowers whose rank is under this share of what has grown,
## one or two to a flower, circling its head. Tiny dots, drawn in one untextured batch.
const BEES_MOST := 90
const BEE_SHARE := 0.45
const BEE_COLOR := Color(0.96, 0.8, 0.28)
const BEE_BAND := Color(0.18, 0.13, 0.06)
const BEE_WING := Color(0.93, 0.97, 0.98, 0.55)
## The plants a bee visits, by the start of the species' name.
const BEE_HOSTS := ["flower_", "patch_", "tulip_", "daisies", "clover_", "shrub_flowering", "thrift", "beach_flower"]
## One painted pixel, in world px: a bee is on the art grid like everything else.
const ART := 2.0
## On each beat of the song a bee's orbit jumps ahead by BEE_PULSE radians, fast at the beat
## and easing out before the next, so the whole meadow quickens in time. The beat is
## `music`'s (MusicStation.beat_clock); none, and the orbit runs even.
const BEE_PULSE := 1.1
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
## Tile points the open-water clumps keep `OPEN_CLEAR` away from: the yards' feet and berths.
var avoid := PackedVector2Array()
var music: MusicStation
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
## The flowers bees are circling, and each bee's seed. Parallel.
var _bee_host := PackedInt32Array()
var _bee_seed := PackedFloat32Array()
var _bee_points := PackedVector2Array()
var _bee_colors := PackedColorArray()
var _bee_indices := PackedInt32Array()
## The bees draw on a child of their own, so their frame-by-frame redraw does not send the
## whole plant batch again with them.
var _bees: Bees


class Bees:
	extends Node2D
	var flora: Flora

	func _draw() -> void:
		flora._draw_bees(self)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 3
	z_as_relative = false
	_bees = Bees.new()
	_bees.name = &"Bees"
	_bees.flora = self
	add_child(_bees)
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
	_bee_host.resize(0)
	_bee_seed.resize(0)
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
	_find_bees()
	queue_redraw()


func bee_count() -> int:
	return _bee_host.size()


## Where the grown pads are, world px: somewhere a frog may sit. Shore pads and open ones.
func pad_spots() -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in _foot.size():
		if _age[k] < _delay[k] + GROW_TIME:
			continue
		var name := _species[k]
		if name.contains("reed"):
			continue
		var kind := String(_table[name]["kind"])
		if kind == "water" or kind == "open":
			out.append(_foot[k] - Vector2(0.0, 4.0))
	return out


## The flowers with bees at them: the lowest ranks among the grown hosts, up to BEES_MOST.
func _find_bees() -> void:
	_bee_host.resize(0)
	_bee_seed.resize(0)
	var density := clampf(stage, 0.0, 1.0) * MOST * BEE_SHARE
	# Every grown host under the density, lowest rank first — the painter's order put all
	# of them on the far bank — with the island's own flowers well up the queue, since the
	# island is where the player stands.
	var hosts: Array = []
	for k in _foot.size():
		if _age[k] < 0.0 or _rank[k] >= density:
			continue
		var tile := Iso.world_to_tile(_foot[k])
		var near := Iso.island_fraction(tile.x, tile.y) < 1.5
		hosts.append([_rank[k] * (0.25 if near else 1.0), k])
	hosts.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for pair: Array in hosts:
		var k: int = pair[1]
		if _bee_host.size() >= BEES_MOST:
			break
		var name := _species[k]
		var host := false
		for prefix: String in BEE_HOSTS:
			if name.begins_with(prefix):
				host = true
				break
		if not host:
			continue
		var n := 1 if _hash(float(k) * 1.3, 4.0) < 0.7 else 2
		for i in n:
			_bee_host.append(k)
			_bee_seed.append(_hash(float(k) * 2.1 + float(i) * 5.3, 9.0) * 100.0)
	if not _bee_host.is_empty():
		set_process(true)


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
	if still > 0 or _growing > 0:
		_dirty = true
		queue_redraw()
	_growing = still
	if not _bee_host.is_empty():
		_bees.queue_redraw()
	if still == 0 and _bee_host.is_empty():
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
				if kind == "open" and _near_avoid(Vector2(float(tx) + 0.5, float(ty) + 0.5)):
					continue
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
	# Out on the open water, in a bed.
	if shelf > PAD_OUT.y + 1.5 and out > PAD_OUT.y + 2.5 and _noise(at / OPEN_CELL) > OPEN_AT:
		return "open"
	return ""


func _near_avoid(at: Vector2) -> bool:
	for p in avoid:
		if at.distance_to(p) < OPEN_CLEAR:
			return true
	return false


## Value noise, 0..1, smooth between whole-number corners.
func _noise(p: Vector2) -> float:
	var i := p.floor()
	var f := p - i
	f = f * f * (Vector2(3.0, 3.0) - 2.0 * f)
	var a := _hash(i.x, i.y)
	var b := _hash(i.x + 1.0, i.y)
	var c := _hash(i.x, i.y + 1.0)
	var d := _hash(i.x + 1.0, i.y + 1.0)
	return lerpf(lerpf(a, b, f.x), lerpf(c, d, f.x), f.y)


## The index of the water tile this spot answers to: itself if it is water, else the first
## lake tile walking out from the shore it stands on. -1 if none within WATER_LOOK.
func _water_beside(at: Vector2, kind: String) -> int:
	var tile := Vector2i(int(floor(at.x)), int(floor(at.y)))
	if kind == "water" or kind == "open":
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
		var weight := 1.0
		if name.begins_with("shrub"):
			weight = 0.25
		elif name == "mushroom":
			weight = 0.35
		elif name == "fern" or name == "open_reeds":
			weight = 0.6
		weights.append(weight)
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


## Each bee circles its flower's head on a wobbling loop, on whole art pixels: a yellow dot,
## a dark one behind it, and a pale wing pixel flicking over it. One untextured batch.
func _draw_bees(on: CanvasItem) -> void:
	if _bee_host.is_empty():
		return
	_bee_points.resize(0)
	_bee_colors.resize(0)
	_bee_indices.resize(0)
	var now := float(Time.get_ticks_msec()) * 0.001
	var flick := int(now * 18.0) % 2 == 0
	var pulse := 0.0
	if music != null:
		var b := music.beat_clock()
		var into := b - floorf(b)
		pulse = (floorf(b) + 1.0 - pow(1.0 - into, 3.0)) * BEE_PULSE
	for i in _bee_host.size():
		var k := _bee_host[i]
		var t := clampf((_age[k] - _delay[k]) / GROW_TIME, 0.0, 1.0)
		if t < 1.0:
			continue
		var rect: Array = _table[_species[k]]["full"]
		var head := _foot[k] - Vector2(0.0, float(rect[3]) * SCALE * 0.85)
		var seed := _bee_seed[i]
		var rx := 5.0 + fmod(seed, 5.0)
		var ry := 3.0 + fmod(seed * 1.7, 3.0)
		var a := now * (2.2 + fmod(seed, 1.3)) + seed + pulse
		var at := head + Vector2(cos(a) * rx + sin(a * 2.3) * 2.0, sin(a * 1.6) * ry - 2.0)
		at = (at / ART).floor() * ART
		# The dark band trails the way it is flying.
		var back := Vector2(signf(sin(a)), 0.0) * ART
		_bee_quad(at, BEE_COLOR)
		_bee_quad(at + back, BEE_BAND)
		if flick:
			_bee_quad(at + Vector2(0.0, -ART), BEE_WING)
	if _bee_indices.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(
		on.get_canvas_item(), _bee_indices, _bee_points, _bee_colors
	)


func _bee_quad(at: Vector2, color: Color) -> void:
	var base := _bee_points.size()
	_bee_points.append(at)
	_bee_points.append(at + Vector2(ART, 0.0))
	_bee_points.append(at + Vector2(ART, ART))
	_bee_points.append(at + Vector2(0.0, ART))
	for n in 4:
		_bee_colors.append(color)
	_bee_indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))


func _hash(x: float, y: float) -> float:
	var h := sin(x * 127.1 + y * 311.7 + float(SEED) * 0.0001) * 43758.5453
	return h - floor(h)
