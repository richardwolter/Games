extends "res://tools/film_trailer.gd"
## The release-date plates (2026-10-10, `/grill-me` with Richard): the angler throws the
## widest net in the game over the lake, and the net is caught mid-flight, opening, over the
## spot where the date sits. Two looks, to be judged side by side before the set is built:
##
##   rel_a   "NOV 16" spelled out on the water in the lake's own rubbish, under the net.
##   rel_b   a clear patch of water under the net, where the compose script lays the date
##           as a graphic and puts the net's mesh back over it.
##
## Every shot freezes the world on the chosen frame (tree paused, time scale nought) and
## photographs it twice: with the net, and with the net hidden. The difference is the net's
## own pixels (mesh, rope, shadow), which is what lets a graphic go under the mesh.
## Pictures and `plates.json` (where the net and the text box landed, in window pixels) go
## to `tools/film/release/`. `FILM_TALL=1` films the portrait plates (`v_` prefix).
##
##   godot --path . --fixed-fps 60 res://tools/shot_release.tscn --log-file tools/film/release_engine.log
##
## Desktop build, not --headless. Its own save, under its own node; `FILM_ONLY=rel_a` runs one.

const OUT_DIR := "res://tools/film/release"

## The throw: Width at the track's top, out to `THROW_TILES` along the shot's direction,
## caught when `FREEZE` of the flight is behind it.
const THROW_TILES := 12.5
const FREEZE := 0.8
## Where the net's middle stands in the frame, as a share of the window.
const NET_AT_WIDE := Vector2(0.5, 0.53)
const NET_AT_TALL := Vector2(0.5, 0.5)
## The text's cells in world pixels: two tile centres to a cell, on the iso lattice.
const CELL := Vector2(64.0, 32.0)
## Tiles cleared round the text box, so no big piece from the soup leans over a letter.
const CLEAR_MARGIN := 64.0
## The clear patch under the net for the graphic look, in tiles.
const PATCH_TILES := 6.5
## Pieces drawn between these sizes (world px, the longer side) spell the letters.
const PIECE_LEAST := 24.0
const PIECE_MOST := 36.0
## Empty rows between the two lines.
const LINE_GAP := 1

## The letters, rows of a 7-high pixel font, "NOV" over "16" on both plates.
const GLYPHS := {
	"N": ["X..X", "XX.X", "XX.X", "X.XX", "X.XX", "X..X", "X..X"],
	"O": [".XX.", "X..X", "X..X", "X..X", "X..X", "X..X", ".XX."],
	"V": ["X..X", "X..X", "X..X", "X..X", "X..X", ".XX.", ".XX."],
	"1": [".XX", "XXX", ".XX", ".XX", ".XX", ".XX", ".XX"],
	"6": [".XX.", "X...", "X...", "XXX.", "X..X", "X..X", ".XX."],
}

var _step := ""
var _wait_until := -1
var _net_at := Vector2.ZERO
var _busy := false
var _plate_info := {}
var _text_box := Rect2()
var _letter_tiles: Array[int] = []


func _init() -> void:
	SAVE_PATH = "user://shot_release.save"
	LOG_PATH = "res://tools/film/last_release.log"


func _plan() -> void:
	_shots = [["rel_a", 0.0, _pose, Callable()], ["rel_b", 0.0, _pose, Callable()]]
	var only := OS.get_environment("FILM_ONLY")
	if only != "":
		var names := only.split(",")
		_shots = _shots.filter(func(s: Array) -> bool: return s[0] in names)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	super._ready()


func _process(_delta: float) -> void:
	_frames += 1
	if Time.get_ticks_msec() > QUIT_AFTER_MS:
		_say("--- wall clock, quitting")
		_quit()
		return
	if _busy:
		return
	if _frames == 3:
		_setup()
		_levels(20, 6, 14, 8, 3)
		_plan()
		_begin(0)
		return
	if _frames < 4 or _shot >= _shots.size():
		return
	_run(_shot_frame)
	_aim()
	_shot_frame += 1


func _begin(i: int) -> void:
	_shot = i
	if _shot >= _shots.size():
		_write_plates()
		_say("--- release done")
		_quit()
		return
	_shot_frame = 0
	_step = "settle"
	_pose()


func _name() -> String:
	return ("v_" if _tall else "") + String(_shots[_shot][0])


## The screen direction the throw goes, as a tile direction: up and right on the wide
## plate, up and a little right on the tall one (straight up, the rope stood like a stick).
func _dir() -> Vector2:
	var screen := Vector2(1.0, -0.55) if not _tall else Vector2(0.6, -1.0)
	# tile_to_world: x = (tx - ty) * 32, y = (tx + ty) * 16.
	var a := screen.x / 32.0
	var b := screen.y / 16.0
	return Vector2((a + b) * 0.5, (b - a) * 0.5).normalized()


func _pose() -> void:
	_hide_boats()
	_unpack()
	_levels(20, 6, 14, 8, 3)
	_drop_finds()
	var dir := _dir()
	var bearing := atan2(dir.y, dir.x)
	_angler.stand_at(Iso.world_to_tile(Iso.island_point(bearing, -0.6)))
	_angler.facing = dir
	_sit_dog(Vector2(0.9, 0.9) if not _tall else Vector2(1.1, 0.2), not _tall)
	_zoom(2)
	_phase = DAY_PHASE
	_hold = Iso.tile_to_world(_angler.tile_pos.x, _angler.tile_pos.y)
	_say("%s: angler %s dir %s" % [_name(), str(_angler.tile_pos.round()), str(dir)])


func _gone() -> float:
	var from: Vector2 = _net.get(&"_cast_from")
	var span: float = _net.get(&"_cast_span")
	return clampf(from.distance_to(_net.tile_pos) / maxf(span, 0.001), 0.0, 1.0)


func _throw() -> void:
	_cast(_dir(), THROW_TILES)


func _run(f: int) -> void:
	_dress_island()
	match _step:
		"settle":
			if f == SETTLE:
				_throw()
				_step = "practice"
		"practice":
			if _net.state == CastNet.State.FLYING and _gone() >= FREEZE:
				_net_at = _net.draw_at()
				_say("  practice: net at %s, open %.0f px" % [str(_net_at.round()), _net.open_extent()])
				_net.call(&"_come_home")
				_lay()
				var at: Vector2 = NET_AT_TALL if _tall else NET_AT_WIDE
				var view := Vector2(get_viewport().get_visible_rect().size)
				var per := _camera.zoom.x
				_hold = _net_at - (at - Vector2(0.5, 0.5)) * view / per
				_wait_until = f + 120
				_step = "wait"
		"wait":
			# The hold is a request; the lake's own view rules (pan, snap) move it a little.
			# Steered until the net's spot is where the frame wants it.
			var want: Vector2 = (NET_AT_TALL if _tall else NET_AT_WIDE) * Vector2(get_window().size)
			var err := _to_window(_net_at) - want
			_hold += err / (_camera.zoom.x * _stretch()) * 0.5
			if f == _wait_until - 30:
				_grid.set(&"_dirty", true)
				_grid.queue_redraw()
			if f >= _wait_until and _net.state == CastNet.State.IDLE:
				_throw()
				_step = "throw"
		"throw":
			if _net.state == CastNet.State.FLYING and _gone() >= FREEZE:
				_step = "done"
				_shoot()


## The date for look A, or the clear patch for look B, laid round where the net will be.
func _lay() -> void:
	var name := String(_shots[_shot][0])
	if name == "rel_b":
		var tile := Iso.world_to_tile(_net_at + Vector2(0.0, 40.0))
		var at := _grid.tile_at(Iso.tile_to_world(tile.x, tile.y))
		var taken := 0
		for index: int in _grid.tiles_within(at, PATCH_TILES):
			while not _grid.stacks[index].is_empty():
				var def_index := _grid.take(index, _grid.stacks[index].size() - 1)
				if not _grid.defs[def_index].keepsake:
					_main.call(&"_on_net_caught", def_index)
				taken += 1
		_main.call(&"_build_filth_map")
		_grid.set(&"_dirty", true)
		_grid.queue_redraw()
		_text_box = Rect2(_net_at, Vector2.ZERO)
		_say("  patch: %d taken" % taken)
		return
	var lines: Array = ["NOV", "16"]
	var rows := 7 * lines.size() + LINE_GAP * (lines.size() - 1)
	var cols := 0
	for line: String in lines:
		cols = maxi(cols, _width_of(line))
	var size := Vector2(cols, rows) * CELL
	var top_left := _net_at + Vector2(0.0, -90.0) - size * 0.5
	_text_box = Rect2(top_left, size)
	var filled := {}
	for li in lines.size():
		var line: String = lines[li]
		var x := (cols - _width_of(line)) / 2
		var y := li * (7 + LINE_GAP)
		for ch in line:
			var glyph: Array = GLYPHS[ch]
			for gy in glyph.size():
				var row: String = glyph[gy]
				for gx in row.length():
					if row[gx] == "X":
						filled[Vector2i(x + gx, y + gy)] = true
			x += (glyph[0] as String).length() + 1
	var pieces: Array = []
	for i in _grid.defs.size():
		var def: TrashDef = _grid.defs[i]
		if def.keepsake or def.atlas == null:
			continue
		var long := maxf(def.size.x, def.size.y)
		var squat := def.size.x / maxf(def.size.y, 1.0)
		if long >= PIECE_LEAST and long <= PIECE_MOST and squat > 0.6 and squat < 1.7:
			pieces.append(i)
	var clear := _text_box.grow(CLEAR_MARGIN)
	var placed := 0
	for index in _grid.stacks.size():
		if _grid.dry[index] == 1:
			continue
		var tile := _grid.tile_of(index)
		var w := Iso.tile_to_world(float(tile.x) + 0.5, float(tile.y) + 0.5)
		if not clear.has_point(w):
			continue
		while not _grid.stacks[index].is_empty():
			var def_index := _grid.take(index, _grid.stacks[index].size() - 1)
			if not _grid.defs[def_index].keepsake:
				_main.call(&"_on_net_caught", def_index)
		var cell := Vector2i(((w - top_left) / CELL).floor())
		if filled.has(cell) and _text_box.has_point(w):
			# The cell's two tile centres sit on a diagonal; laid side by side instead, so a
			# stroke is a straight row, not a zig-zag.
			var corner := top_left + Vector2(cell) * CELL
			var left := Iso.tile_to_world(float(tile.x) + 0.5, float(tile.y) + 0.5).x < corner.x + CELL.x * 0.5
			var spot := corner + Vector2(CELL.x * (0.25 if left else 0.75), CELL.y * 0.5)
			_grid.insert(index, 0, pieces[_rng.randi_range(0, pieces.size() - 1)])
			_grid.nudge[index] = spot - w
			_grid.tilt[index] = 0.0
			_grid.swing[index] = 1.0
			_grid.call(&"_restamp", index)
			placed += 1
			_letter_tiles.append(index)
	_main.call(&"_build_filth_map")
	_grid.set(&"_dirty", true)
	_grid.queue_redraw()
	_say("  letters: %d tiles, %d kinds, box %s" % [placed, pieces.size(), str(_text_box)])


func _width_of(line: String) -> int:
	var w := 0
	for ch in line:
		w += (GLYPHS[ch][0] as String).length() + 1
	return w - 1


## World point to window pixel, through the held camera.
func _to_window(at: Vector2) -> Vector2:
	var per := _camera.zoom.x * _stretch()
	var view := Vector2(get_window().size)
	return (at - _camera.get_screen_center_position()) * per + view * 0.5


func _shoot() -> void:
	_busy = true
	var at := _net.draw_at()
	_say("  frozen: net at %s (practice %s), open %.0f px, gone %.2f" % [
			str(at.round()), str(_net_at.round()), _net.open_extent(), _gone()])
	get_tree().paused = true
	Engine.time_scale = 0.0
	# The aim ring, pointed off the lake, still draws its dashes somewhere in the frame.
	(_net.get_node(^"Aim") as CanvasItem).visible = false
	var with_net: Image = await _grab()
	var nets: Array = [_net, _main.get(&"_net2")]
	for n in nets:
		if n != null:
			(n as CanvasItem).visible = false
	var bare: Image = await _grab()
	for n in nets:
		if n != null:
			(n as CanvasItem).visible = true
	# The net alone, over black and over white: the two give its exact colour and alpha,
	# shadow and rope included, so type can go under the mesh and still take the shadow.
	var hidden: Array = []
	for child in _main.get_children():
		if child == _net:
			continue
		if (child is CanvasItem or child is CanvasLayer) and child.visible:
			child.visible = false
			hidden.append(child)
	var clear := ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color", Color.BLACK) as Color
	RenderingServer.set_default_clear_color(Color.BLACK)
	var on_black: Image = await _grab()
	RenderingServer.set_default_clear_color(Color.WHITE)
	var on_white: Image = await _grab()
	RenderingServer.set_default_clear_color(clear)
	for child in hidden:
		child.visible = true
	var dir := ProjectSettings.globalize_path(OUT_DIR)
	with_net.save_png(dir.path_join(_name() + "_net.png"))
	bare.save_png(dir.path_join(_name() + "_bare.png"))
	on_black.save_png(dir.path_join(_name() + "_netblack.png"))
	on_white.save_png(dir.path_join(_name() + "_netwhite.png"))
	var box := Rect2(_to_window(_text_box.position), _text_box.size * _camera.zoom.x * _stretch())
	var net := _to_window(at)
	_plate_info[_name()] = {
		"size": [with_net.get_width(), with_net.get_height()],
		"net": [net.x, net.y],
		"open": _net.open_extent() * _camera.zoom.x * _stretch(),
		"text_box": [box.position.x, box.position.y, box.size.x, box.size.y],
	}
	_say("  saved %s: net %s, box %s" % [_name(), str(net.round()), str(box)])
	Engine.time_scale = 1.0
	get_tree().paused = false
	_net.call(&"_come_home")
	_busy = false
	_begin(_shot + 1)


func _grab() -> Image:
	for i in 3:
		await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _write_plates() -> void:
	var path := ProjectSettings.globalize_path(OUT_DIR).path_join(
			"plates_tall.json" if _tall else "plates.json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(_plate_info, "  "))
	f.close()


func _quit() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().quit()


## The trailer's hold without the lake's clamp: the clamp keeps a player's view off the edge
## of the ground and stopped the frame short of centring the net. Forest fills past it.
func _aim() -> void:
	(_main.get(&"_day") as DayCycle).phase = _phase
	_push_camera_zoom()
	_net.pad_aim = Vector2(-1.0e6, -1.0e6)
	# Pinned the game's own way, so its follow does not chase the flying net.
	_main.set(&"_free_view", true)
	_main.set(&"_free_at", _hold)
	_main.set(&"_panning", true)
	_camera.position = _hold
	_snap()
