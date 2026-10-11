extends Node
## The house's inside, photographed in layers for the stage mockup (2026-10-11, the house
## stages plan): for each of three furnishings, the frame is frozen and taken four times --
##
##   full   the room as the game draws it
##   keyb   the floor layer swapped for flat black over the shed's rect
##   keyg   the same in flat grey (0.5)
##   shell  the floor layer alone: the room's own drawing, the shadows and the light hidden
##
## From keyb and keyg the mockup recovers everything drawn over the floor (the dim, the
## shadows, the furniture, the walkers, the light) as one premultiplied layer, and lays it
## back over a damaged floor. Rects, pieces and walkers go to `layers.json` beside the
## pictures, in screen pixels and in the room's source pixels.
##
## Desktop build, not --headless:
##   godot --path . --log-file <path> res://tools/shot_house_layers.tscn
## Its own save path and no autosave: nothing here touches the player's run.

const OUT := "res://art_source/house_inside/captures/"
const QUIT_AFTER_MS := 120000

## Cells, the eye's unit; scaled to source pixels on placing. Stage 1 is the room a player
## has after the first finds; each later stage keeps every piece where it stood.
const STAGE_1 := [
	[&"decor_pk_bed", 24, 14], [&"decor_pk_sofa", 22, 8], [&"decor_pk_wood_chair", 14, 10],
	[&"decor_pk_coat_stand", 2, 14], [&"decor_pk_nightstand", 31, 15],
	[&"decor_vynil_player", 31, 13],
]
const STAGE_2 := [
	[&"decor_pk_rug", 20, 6], [&"decor_pk_table", 4, 8], [&"decor_pk_chair", 12, 10],
	[&"decor_pk_globe", 9, 5], [&"decor_pk_armchair", 34, 8], [&"decor_pk_bookshelf", 1, -4],
	[&"decor_pk_fireplace", 30, 2], [&"decor_pk_floor_lamp", 38, 3],
	[&"decor_pk_potted_tree", 36, 14],
]
const STAGE_3 := [
	[&"decor_pk_fridge", 9, -3], [&"decor_pk_landscape", 14, -3], [&"decor_pk_portrait", 18, -4],
	[&"decor_pk_kitchen_counter", 22, -2], [&"decor_pk_stove", 33, -1],
	[&"decor_pk_grandfather_clock", 28, -4], [&"decor_pk_flower_vase", 6, 6],
	[&"decor_pk_table_lamp", 5, 6],
]
const DOGS := [1, 3, 4]
const PLAYER_AT := [Vector2(17.0, 19.0), Vector2(17.0, 19.0), Vector2(17.0, 19.0)]

var _main: Node
var _room: ShedRoom
var _n := 0
var _busy := false
## The flat colour the floor layer is swapped for. A member, not a local: a lambda keeps a
## copy of the locals it was made with.
var _key := Color.BLACK
var _record := {"stages": []}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"autoload_save", false)
	_main.set(&"save_path", "user://probe_house_layers.save")
	add_child(_main)


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() > QUIT_AFTER_MS:
		_finish("gave up: wall clock")
		return
	if _busy:
		return
	_n += 1
	if _n == 10:
		_busy = true
		_run()


func _run() -> void:
	_room = _main.get_node(^"HUD/Shed/Pad/Lines/Room")
	var placed: Array = []
	for stage in 3:
		Engine.time_scale = 1.0
		get_tree().paused = false
		placed.append_array([STAGE_1, STAGE_2, STAGE_3][stage])
		_furnish(placed, stage)
		for i in 40:
			await get_tree().process_frame
		get_tree().paused = true
		Engine.time_scale = 0.0
		await _shoot(stage + 1)
	Engine.time_scale = 1.0
	get_tree().paused = false
	_finish("done")


func _furnish(rows: Array, stage: int) -> void:
	var decor: Array = _main.get(&"decor")
	decor.clear()
	_room.decor = decor
	var refused: Array = []
	for want: Array in rows:
		if not _room.sheets.has(want[0]):
			refused.append("%s (unknown)" % want[0])
			continue
		var at := Vector2i(int(want[1]), int(want[2])) * ShedRoom.CELL
		if not _room.place(want[0], at):
			refused.append("%s at %s,%s" % want)
	# Every switchable piece on from stage 2, for the light; stage 1 is a room with nothing lit.
	for row: Dictionary in _room.decor:
		var piece := StringName(row["piece"])
		var view := int(row.get("view", 0))
		var on := _room.sheets.switched(piece, view)
		if stage >= 1 and on >= 0 and not _room.sheets.is_on(piece, view):
			row["view"] = on
	if stage == 0:
		_main.call(&"_set_shed", true)
	# No pointing hands: every kind counts as tried. After the door, which re-points the list.
	var tried: Array[String] = _room.switch_tried
	for row: Dictionary in _room.decor:
		if not tried.has(String(row["piece"])):
			tried.append(String(row["piece"]))
	var want_dogs: int = DOGS[stage]
	_room.pack_size = func() -> int: return want_dogs
	for _try in 400:
		_room.call(&"_room_shown")
		if _room.dogs().size() == want_dogs:
			break
	_room.set(&"_you_at", PLAYER_AT[stage])
	_room.set(&"_you_facing", Vector2(0.0, 1.0))
	_room.unlocked = [] as Array[String]
	(_record["stages"] as Array).append({"refused": refused})


func _grab() -> Image:
	for i in 3:
		await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _shoot(stage: int) -> void:
	var floor: Node2D = _room.get(&"_floor_layer")
	var shades: CanvasItem = _room.get(&"_shades")
	var light: CanvasItem = _room.get(&"_light")
	var full: Image = await _grab()
	var hooks := floor.get_signal_connection_list(&"draw")
	for hook: Dictionary in hooks:
		floor.draw.disconnect(hook["callable"])
	_key = Color.BLACK
	var paint := func() -> void:
		floor.draw_rect(Rect2(-_room.global_position, _room.get_viewport_rect().size), ShedRoom.ROOM_SCRIM)
		floor.draw_rect(_room.call(&"_shed_rect"), _key)
	floor.draw.connect(paint)
	floor.queue_redraw()
	var keyb: Image = await _grab()
	_key = Color(0.5, 0.5, 0.5)
	floor.queue_redraw()
	var keyg: Image = await _grab()
	floor.draw.disconnect(paint)
	for hook: Dictionary in hooks:
		floor.draw.connect(hook["callable"])
	floor.queue_redraw()
	_room.self_modulate = Color(1, 1, 1, 0)
	shades.visible = false
	light.visible = false
	var shell: Image = await _grab()
	_room.self_modulate = Color.WHITE
	shades.visible = true
	light.visible = true
	_room.queue_redraw()
	var again: Image = await _grab()
	var tag := "s%d_" % stage
	full.save_png(OUT + tag + "full.png")
	keyb.save_png(OUT + tag + "keyb.png")
	keyg.save_png(OUT + tag + "keyg.png")
	shell.save_png(OUT + tag + "shell.png")
	var rec: Dictionary = (_record["stages"] as Array)[stage - 1]
	rec["freeze_ok"] = _same(full, again)
	rec["pieces"] = _pieces()
	rec["dogs"] = _dogs()
	rec["player_cells"] = [(_room.get(&"_you_at") as Vector2).x, (_room.get(&"_you_at") as Vector2).y]
	if stage == 1:
		_geometry(full)


func _same(a: Image, b: Image) -> String:
	var differ := 0
	for y in range(0, a.get_height(), 2):
		for x in range(0, a.get_width(), 2):
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				differ += 1
	return "%d sampled pixels differ" % differ


## The room's rects in screen pixels of the saved picture, plus what one source pixel is.
func _geometry(shot: Image) -> void:
	var to_screen := float(shot.get_width()) / _room.get_viewport_rect().size.x
	var xf := _room.get_global_transform_with_canvas()
	var box := func(r: Rect2) -> Array:
		var p := xf * r.position * to_screen
		return [p.x, p.y, r.size.x * to_screen, r.size.y * to_screen]
	var floor_box: Rect2 = _room.call(&"_floor_rect")
	var shed: Rect2 = _room.call(&"_shed_rect")
	var wall_tall: float = _room.call(&"_wall_tall")
	var wall := Rect2(Vector2(floor_box.position.x, floor_box.position.y - wall_tall),
		Vector2(floor_box.size.x, wall_tall))
	var opening: Rect2 = _room.call(&"_door_opening", wall)
	var zoom: float = _room.call(&"_zoom")
	_record["screen"] = [shot.get_width(), shot.get_height()]
	_record["to_screen"] = to_screen
	_record["zoom"] = zoom
	_record["source_px"] = zoom * to_screen
	_record["floor"] = box.call(floor_box)
	_record["shed"] = box.call(shed)
	_record["wall"] = box.call(wall)
	_record["door"] = box.call(opening)
	_record["board"] = box.call(_room.call(&"_board_rect"))
	_record["window_at"] = [
		(xf * (_room.call(&"_window_at") as Vector2) * to_screen).x,
		(xf * (_room.call(&"_window_at") as Vector2) * to_screen).y,
	]
	_record["border_px"] = {
		"vertical": [ShedRoom.BORDER_VERTICAL.get_width(), ShedRoom.BORDER_VERTICAL.get_height()],
		"horizontal": [ShedRoom.BORDER_HORIZONTAL.get_width(), ShedRoom.BORDER_HORIZONTAL.get_height()],
		"sill": [ShedRoom.BORDER_SILL.get_width(), ShedRoom.BORDER_SILL.get_height()],
		"corner_top": [ShedRoom.BORDER_TOP_LEFT.get_width(), ShedRoom.BORDER_TOP_LEFT.get_height()],
		"corner_bottom": [ShedRoom.BORDER_BOTTOM_LEFT.get_width(), ShedRoom.BORDER_BOTTOM_LEFT.get_height()],
	}
	_record["cells"] = [ShedRoom.COLS, ShedRoom.ROWS, ShedRoom.CELL, ShedRoom.WALL_ROWS]


## Every standing piece: its spot and base in placement (source) pixels from the floor's
## top-left, its drawn size, and what it is.
func _pieces() -> Array:
	var out: Array = []
	for row: Dictionary in _room.decor:
		var piece := StringName(row["piece"])
		var view := int(row.get("view", 0))
		var cell: Array = row["cell"]
		var span: Vector2i = _room.span_of(piece, view)
		out.append({
			"piece": String(piece), "view": view,
			"at": [int(cell[0]), int(cell[1])], "span": [span.x, span.y],
			"base": _room.base_of(piece, view),
		})
	return out


func _dogs() -> Array:
	var out: Array = []
	for dog in _room.dogs():
		out.append({"at": [dog.at.x, dog.at.y], "seat": dog.seat, "state": str(dog.state)})
	return out


func _finish(why: String) -> void:
	_record["end"] = why
	var f := FileAccess.open(OUT + "layers.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_record, "  "))
		f.close()
	Engine.time_scale = 1.0
	get_tree().quit()
