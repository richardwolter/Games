extends Node
## Opens the lake on a real window and saves what the graded grime looks like as the lake
## is worked: fresh, then with a quarter, a half and three quarters of its rubbish lifted,
## each from the whole-lake view and from close in off the island. The lifting is uneven —
## noise pools a few tiles across, some bays worked harder than others — because a lake
## thinned evenly is a lake nobody has played. A probe, not a test: the shades, the scum
## and where the contours fall are things to look at; the log says how much water is in
## each state at each stage.
##
## Runs on a save of its own and never writes the player's. Desktop build, not --headless
## (headless compiles no shader, so this is also what proves water.gdshader):
##
##   godot --path . --fixed-fps 60 --log-file tools/grime_engine.log res://tools/shot_grime.tscn

const SHOT := "res://tools/last_grime_%s_%s.png"
const LOG := "res://tools/last_grime.log"
const SAVE_PATH := "user://shot_grime.save"
const HOLD := 50
const STAGES := ["fresh", "quarter", "half", "threeq"]
const VIEWS := ["far", "near"]
const STATE_NAMES := ["clean", "hazy", "murky", "foul", "dirty"]
## How wide a worked bay is, in tiles, and how unevenly the lifting falls across them.
const POOL := 7.0
const UNEVEN := 0.35

var _main: Node
var _grid: LakeGrid
var _camera: Camera2D
var _frames := 0
var _step := 0
var _due := 0
var _full: Array[int] = []


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	if FileAccess.file_exists(LOG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG))
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE_PATH)
	_main.set(&"autoload_save", false)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	# Under this node, not the root: a lake under the root wears the menu.
	add_child.call_deferred(_main)
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _main == null or not _main.is_inside_tree():
		return
	if _frames < 6:
		return
	if _frames == 6:
		_grid = _main.get(&"_grid")
		_camera = _main.get(&"_camera")
		for stack in _grid.stacks:
			_full.append(stack.size())
		get_viewport().warp_mouse(Vector2(8.0, 8.0))
		_pose()
		_due = _frames + HOLD
		return
	if _frames != _due:
		return
	var stage: int = _step / VIEWS.size()
	var view: int = _step % VIEWS.size()
	_write(STAGES[stage], VIEWS[view], view == 0)
	_step += 1
	if _step >= STAGES.size() * VIEWS.size():
		get_tree().quit()
		return
	_pose()
	_due = _frames + HOLD


func _pose() -> void:
	var stage: int = _step / VIEWS.size()
	var view: int = _step % VIEWS.size()
	if view == 0 and stage > 0:
		_lift(float(stage) / float(STAGES.size()))
	var angler: Node2D = _main.get(&"_angler")
	var level := 1 if view == 0 else 3
	var spot := Iso.tile_to_world(Iso.ISLAND_CENTRE.x, Iso.ISLAND_CENTRE.y)
	if view == 1:
		spot = Iso.tile_to_world(Iso.ISLAND_CENTRE.x + 7.0, Iso.ISLAND_CENTRE.y + 8.0)
	_main.set(&"_pan", spot - angler.position)
	_main.set(&"_panning", true)
	_main.set(&"_view_zoom", _main.call(&"_zoom_level", level))
	_main.call(&"_push_zoom")
	var zoom := float(level) / (Lake.ART_PIXEL * float(_main.call(&"_stretch")))
	_camera.zoom = Vector2(zoom, zoom)


## Take every stack down to about `1 - share` of what it started with, more in some bays
## and less in others, from the top as a net does.
func _lift(share: float) -> void:
	for index in _grid.stacks.size():
		if _full[index] == 0:
			continue
		var tile := _grid.tile_of(index)
		var pool := _noise(Vector2(tile) / POOL) * 2.0 - 1.0
		var gone := clampf(share + pool * UNEVEN, 0.0, 1.0)
		var left := int(round(float(_full[index]) * (1.0 - gone)))
		if left < _grid.stacks[index].size():
			_grid.stacks[index].resize(left)
	_grid._rebuild()
	_main._build_filth_map()


func _noise(p: Vector2) -> float:
	var i := p.floor()
	var f := p - i
	f = f * f * (Vector2(3.0, 3.0) - 2.0 * f)
	var a := _hash(i)
	var b := _hash(i + Vector2(1.0, 0.0))
	var c := _hash(i + Vector2(0.0, 1.0))
	var d := _hash(i + Vector2(1.0, 1.0))
	return lerpf(lerpf(a, b, f.x), lerpf(c, d, f.x), f.y)


func _hash(cell: Vector2) -> float:
	var h := sin(cell.x * 12.9898 + cell.y * 78.233) * 43758.5453
	return h - floor(h)


func _write(stage: String, view: String, count: bool) -> void:
	if count:
		var states := [0, 0, 0, 0, 0]
		var pieces := 0
		var wet := 0
		for index in _grid.stacks.size():
			var tile := _grid.tile_of(index)
			if not Iso.in_lake(tile.x, tile.y):
				continue
			wet += 1
			pieces += _grid.stacks[index].size()
			states[_grid.water_state(index)] += 1
		var line := "%s: %d pieces," % [stage, pieces]
		for k in states.size():
			line += " %s %.1f%%" % [STATE_NAMES[k], 100.0 * float(states[k]) / float(maxi(wet, 1))]
		var began := Time.get_ticks_usec()
		_main._build_filth_map()
		line += ", map build %.2f ms" % (float(Time.get_ticks_usec() - began) / 1000.0)
		began = Time.get_ticks_usec()
		_main._pooled_share(Iso.COLS, Iso.ROWS)
		line += ", of which the pooled share %.2f ms" % (float(Time.get_ticks_usec() - began) / 1000.0)
		began = Time.get_ticks_usec()
		_main._count_clean()
		line += ", the clean count %.2f ms" % (float(Time.get_ticks_usec() - began) / 1000.0)
		var log := FileAccess.open(LOG, FileAccess.READ_WRITE if FileAccess.file_exists(LOG) else FileAccess.WRITE)
		log.seek_end()
		log.store_line(line)
		log.close()
	var shot := get_viewport().get_texture().get_image()
	shot.save_png(ProjectSettings.globalize_path(SHOT % [stage, view]))
