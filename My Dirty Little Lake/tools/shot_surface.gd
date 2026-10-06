extends Node
## What the lake shows on its surface when a new game opens: the picture the player gets
## first, and the numbers behind it.
##
## Two pictures — the game's own starting view, and a close one out over the water where
## individual pieces read — plus `tools/last_surface.log`, which counts what every tile is
## showing. The log is what says whether the fill got more varied; the pictures are what
## says whether it looks it. A probe, not a test: `test_lake` guards the rules, this is for
## judging the numbers by eye and retuning `LakeGrid.SURFACE_QUOTA`, `SURFACE_APART`,
## `SURFACE_BAIT` and `OPEN_RING`.
##
## Runs on a save of its own and never writes the player's. Desktop build, not --headless:
##
##   godot --path . --fixed-fps 60 res://tools/shot_surface.tscn

const SHOT := "res://tools/last_surface_%s.png"
const LOG := "res://tools/last_surface.log"
const SAVE_PATH := "user://shot_surface.save"
## Frames the lake is given to settle — the soup is laid out for the view, and the swell
## and the foam want a moment — before a picture is kept.
const HOLD := 150
## How many kinds the log names one by one before it stops.
const NAMED := 10

var _main: Node
var _grid: LakeGrid
var _camera: Camera2D
var _frames := 0
var _stage := 0
var _due := 0


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	if FileAccess.file_exists(LOG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG))
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE_PATH)
	_main.set(&"autoload_save", false)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	get_tree().root.add_child.call_deferred(_main)
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _main == null or not _main.is_inside_tree():
		return
	if _frames == 6:
		_grid = _main.get(&"_grid")
		_camera = _main.get_node(^"Camera") as Camera2D
		# The aim ring off the lake, so the picture is the water and not the marker.
		get_viewport().warp_mouse(Vector2(8.0, 8.0))
		_count()
		_look(0)
		_due = _frames + HOLD
	if _frames < 6 or _frames != _due:
		return
	_write(["far", "near"][_stage])
	_stage += 1
	if _stage >= 2:
		_time_fill()
		get_tree().quit()
		return
	_look(_stage)
	_due = _frames + HOLD


## Where each picture is taken from. The far one is the game's own opening view, untouched,
## because that is the frame the first impression is actually made in. The near one is out
## over the water off the island's south-east shore, close enough that one piece is one
## object rather than a speck.
func _look(stage: int) -> void:
	var angler: Node2D = _main.get(&"_angler")
	if stage == 0:
		_main.call(&"_snap_camera")
		return
	var spot := Iso.tile_to_world(Iso.ISLAND_CENTRE.x + 6.0, Iso.ISLAND_CENTRE.y + 7.0)
	_main.set(&"_pan", spot - angler.position)
	_main.set(&"_panning", true)
	_main.set(&"_view_zoom", _main.call(&"_zoom_level", 3))
	_main.call(&"_push_zoom")
	var zoom: float = 3.0 / (Lake.ART_PIXEL * float(_main.call(&"_stretch")))
	_camera.zoom = Vector2(zoom, zoom)


## Count what the lake is showing, once, and write it down.
func _count() -> void:
	var shown := {}          # def index -> how many tiles show it
	var surface_kind := [0, 0, 0, 0]
	var every_kind := [0, 0, 0, 0]
	var pieces := 0
	var tiles := 0
	var ring_tiles := 0
	var ring_liftable := 0
	var at: Array[Vector2] = []
	var tops := PackedInt32Array()
	for index in _grid.stacks.size():
		var stack := _grid.stacks[index]
		for piece in stack:
			every_kind[_grid.defs[piece].material] += 1
			pieces += 1
		if stack.is_empty():
			continue
		var top := stack[stack.size() - 1]
		tiles += 1
		shown[top] = int(shown.get(top, 0)) + 1
		surface_kind[_grid.defs[top].material] += 1
		var tile := Vector2(_grid.tile_of(index))
		at.append(tile)
		tops.append(top)
		if Iso.past_shelf(tile) < LakeGrid.OPEN_RING:
			ring_tiles += 1
			if _grid.defs[top].tier == 0:
				ring_liftable += 1

	var order := shown.keys()
	order.sort_custom(func(a: int, b: int) -> bool: return shown[a] > shown[b])
	# What the eye actually gets. A tile showing a 10 px can and a tile showing a 55 px
	# painting are one tile each, and thirty times as much water is the painting. So the
	# same count again, weighted by how much of the lake each kind covers.
	var ink := {}
	var ink_all := 0.0
	for idx: int in shown.keys():
		var size: Vector2 = _grid.defs[idx].size
		var area := size.x * size.y * float(shown[idx])
		ink[idx] = area
		ink_all += area
	var by_ink := ink.keys()
	by_ink.sort_custom(func(a: int, b: int) -> bool: return ink[a] > ink[b])
	var log := FileAccess.open(LOG, FileAccess.WRITE)
	log.store_line("--- the lake's surface, fresh")
	log.store_line("%d tiles showing a piece, %d pieces in the water, %d kinds on top"
		% [tiles, pieces, order.size()])
	if not order.is_empty():
		log.store_line("commonest: %s, %.1f%% of what is shown"
			% [_grid.defs[order[0]].piece, 100.0 * float(shown[order[0]]) / float(tiles)])
	# And by family of look-alikes, which is what the eye counts: four cans are one can.
	var clan := {}
	for idx: int in shown.keys():
		var head: int = _grid.family_of(idx)
		clan[head] = int(clan.get(head, 0)) + int(shown[idx])
	var by_clan := clan.keys()
	by_clan.sort_custom(func(a: int, b: int) -> bool: return clan[a] > clan[b])
	if not by_clan.is_empty():
		log.store_line("commonest family: %s, %.1f%% (%d families on the surface)"
			% [_grid.defs[by_clan[0]].piece,
			100.0 * float(clan[by_clan[0]]) / float(tiles), by_clan.size()])

	log.store_line("")
	for i in mini(NAMED, order.size()):
		var idx: int = order[i]
		log.store_line("  %-18s %5.2f%%  tier %d  lightness %.1f  %s"
			% [_grid.defs[idx].piece, 100.0 * float(shown[idx]) / float(tiles),
			_grid.defs[idx].tier, _grid.defs[idx].lightness,
			TrashDef.KIND_NAMES[_grid.defs[idx].material]])
	log.store_line("")
	log.store_line("  by how much water each covers:")
	for i in mini(NAMED, by_ink.size()):
		var idx: int = by_ink[i]
		log.store_line("  %-18s %5.2f%%  %.0fx%.0f px"
			% [_grid.defs[idx].piece, 100.0 * float(ink[idx]) / maxf(ink_all, 1.0),
			_grid.defs[idx].size.x, _grid.defs[idx].size.y])
	log.store_line("")
	# The bargain the surface quota strikes: what is *seen* leans towards the colourful
	# materials, what is *in the water* — and so what each yard is paid for over a run —
	# stays where `MATERIAL_QUOTA` put it.
	for m in 4:
		log.store_line("  %-8s surface %5.2f%%  (asked %4.0f%%)   all pieces %5.2f%%  (quota %4.0f%%)"
			% [TrashDef.KIND_NAMES[m],
			100.0 * float(surface_kind[m]) / maxf(float(tiles), 1.0),
			100.0 * float(LakeGrid.SURFACE_QUOTA[m]),
			100.0 * float(every_kind[m]) / maxf(float(pieces), 1.0),
			100.0 * float(LakeGrid.MATERIAL_QUOTA[m])])
	log.store_line("")
	log.store_line("opening ring: %d tiles, %d showing something a level-0 net can lift"
		% [ring_tiles, ring_liftable])
	var repeats := _repeats(at, tops)
	log.store_line("repeats inside the kind's own room: %.2f%% of tiles, %d of them touching"
		% [100.0 * float(repeats.x) / maxf(float(tiles), 1.0), int(repeats.y)])
	log.close()


## How often the anti-repeat is not met: how many tiles show a kind that another tile within
## that kind's own room (`LakeGrid._apart_of`, which is wider for a big piece) is also
## showing, and how many of those are touching outright.
##
## A share, not the worst case. The rule is a preference and cannot be anything else — the
## pick comes out of the stack the tile already holds, and a stack whose every piece is a
## kind already showing nearby has nothing else to offer. Over four thousand tiles the worst
## case is therefore always "touching", and says nothing; the share says whether it is rare.
##
## Walked as a window rather than every pair: eight thousand tiles squared is sixty million
## comparisons and the answer only ever comes from a few tiles away.
func _repeats(at: Array[Vector2], tops: PackedInt32Array) -> Vector2:
	var where := {}
	for i in at.size():
		where[Vector2i(at[i])] = tops[i]
	var hit := 0
	var touching := 0
	var reach := int(ceil(LakeGrid.SURFACE_APART * LakeGrid.BIG_ROOM))
	for i in at.size():
		var tile := Vector2i(at[i])
		var near := false
		var next_door := false
		var apart: float = _grid.call(&"_apart_of", _grid.defs[tops[i]])
		var family: int = _grid.family_of(tops[i])
		for dy in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				if dx == 0 and dy == 0:
					continue
				var away := Vector2(float(dx), float(dy)).length()
				if away > apart:
					continue
				var other := tile + Vector2i(dx, dy)
				if not where.has(other) or _grid.family_of(int(where[other])) != family:
					continue
				near = true
				if away <= 1.5:
					next_door = true
		if near:
			hit += 1
		if next_door:
			touching += 1
	return Vector2(float(hit), float(touching))


## What the fill itself costs, since the surface pass walks a window round every tile.
##
## Last, and never before a picture: `build` re-rolls the whole field, and while the seed
## makes that the same field again it is laid down *without* the finds, which `Lake` plants
## afterwards. Timed where it was first written — between the count and the shots — it
## quietly took the treasure out of both photographs.
func _time_fill() -> void:
	var clock := Time.get_ticks_usec()
	_grid.build(_grid.defs, 20260817, true)
	var took := float(Time.get_ticks_usec() - clock) / 1000.0
	var log := FileAccess.open(LOG, FileAccess.READ_WRITE)
	log.seek_end()
	log.store_line("the fill takes %.1f ms" % took)
	log.close()


func _write(name: String) -> void:
	var note := FileAccess.open(LOG, FileAccess.READ_WRITE)
	note.seek_end()
	note.store_line("%s: camera zoom %.4f, view zoom %.4f, stretch %.3f"
		% [name, _camera.zoom.x, float(_main.get(&"_view_zoom")),
		float(_main.call(&"_stretch"))])
	note.close()
	var shot := get_viewport().get_texture().get_image()
	shot.save_png(ProjectSettings.globalize_path(SHOT % name))
