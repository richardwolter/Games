extends Node
## Films the game loop for the store's About This Game (2026-10-02, Richard): a find washed at
## the pump and then carried off the shelf into the decorated house and put down. The house is
## the layout Richard made in `tools/play_decor.tscn` (its save is copied, never written), with
## one piece (`PIECE`, the globe) taken off the floor and put back at the pump. Every frame is
## saved as a JPEG into `tools/film/steam/wash_place/`, and `last_wash_place.log` says on which
## frame the room swap and the put-down fall, for the GIF's cut.
##
##   godot --path . --fixed-fps 60 res://tools/shot_wash_place.tscn --log-file tools/film/wash_place.log
##
## Desktop build. Under its own node, on its own save, quits on a wall clock too.
##
## Deleted with the Steam probes on 2026-10-03 and brought back for the vertical trailer
## (2026-10-05): `FILM_TALL=1` films it in film_trailer's portrait window (1080x1920, canvas
## 720x1280) into `tools/film/v_wash_place/`. The decorated house's save was written by an
## older build (version 21, refused since the fill's tier shares moved); the copy this probe
## loads has its version number raised to the game's, which is safe for a shot of the house:
## only the lake's stacks changed meaning, and nothing here is judged by them.

const Style := preload("res://scripts/style.gd")
const FROM_SAVE := "user://play_decor.save"
const SAVE_PATH := "user://shot_wash_place.save"
var _tall := OS.get_environment("FILM_TALL") != ""
var OUT := "res://tools/film/v_wash_place" if _tall else "res://tools/film/steam/wash_place"
var LOG := "res://tools/film/last_wash_place_tall.log" if _tall else "res://tools/film/steam/last_wash_place.log"
const QUIT_AFTER_MS := 240000
const PIECE := &"decor_pk_globe"
## Frames: when the wash room opens, when the nozzle starts, how long the clean find is shown
## before the room swap, how long the shelf is shown before the piece is lifted, the carry,
## and the hold after it lands.
const OPEN_AT := 8
const SPRAY_FROM := 40
const AFTER_CLEAN := 60
const SHELF_HOLD := 30
const CARRY := 75
const HOLD := 80
## Other finds waiting on the tray beside the globe (Richard: the illusion of more to wash,
## though they are standing in the house already).
const TRAY_MORE := 7
## The jet sweeps the find in rows (2026-10-02, Richard: clean efficiently, in real time):
## rows `ROW_GAP` jet radii apart, crossed at `SWEEP_PACE` px a second over the piece's own
## width in that row, then the last specks chased at `CHASE_PACE`.
const ROW_GAP := 1.0
const SWEEP_PACE := 340.0
const CHASE_PACE := 700.0
const RETARGET_EVERY := 4
## Where the pointer is drawn into each frame afterwards (the capture has no hardware
## cursor), one line a frame: `frame x y` in window pixels, or `frame -` for none.
var POINTER_LOG := OUT + "/pointer.txt"
## The window and canvas from the room swap on, in the vertical film (see `_to_shed`).
const SHED_WINDOW := Vector2i(1650, 1920)
const SHED_CANVAS := Vector2i(1100, 1280)

var _main: Node
var _frames := 0
var _log: FileAccess
var _started := 0
var _target_cell := Vector2i.ZERO
var _target_view := 0
var _clean_at := -1
var _swap_at := -1
var _lift_at := -1
var _down_at := -1
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _saved := 0
var _aim := Vector2.INF
var _goal := Vector2.ZERO
var _path: Array[Vector2] = []
var _pointers: FileAccess


func _ready() -> void:
	_started = Time.get_ticks_msec()
	if _tall:
		var win := get_window()
		win.mode = Window.MODE_WINDOWED
		win.borderless = true
		win.size = Vector2i(1080, 1920)
		win.position = Vector2i.ZERO
		win.content_scale_size = Vector2i(720, 1280)
	else:
		DisplayServer.window_set_size(Vector2i(1920, 1080))
	_log = FileAccess.open(LOG, FileAccess.WRITE)
	var dir := ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(dir)
	for old in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(old))
	for path in [SAVE_PATH, SAVE_PATH + ".bak", SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if not FileAccess.file_exists(FROM_SAVE):
		_say("no decorated house: run tools/play_decor.tscn first")
		get_tree().quit()
		return
	_pointers = FileAccess.open(POINTER_LOG, FileAccess.WRITE)
	DirAccess.copy_absolute(ProjectSettings.globalize_path(FROM_SAVE), ProjectSettings.globalize_path(SAVE_PATH))
	_raise_version(SAVE_PATH)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE_PATH)
	_main.set(&"autoload_save", true)
	add_child.call_deferred(_main)


func _say(line: String) -> void:
	_log.store_line(line)
	_log.flush()


func _room() -> ShedRoom:
	return _main.get_node(^"HUD/Shed/Pad/Lines/Room")


func _process(_delta: float) -> void:
	_frames += 1
	if Time.get_ticks_msec() - _started > QUIT_AFTER_MS:
		_say("wall clock ran out")
		get_tree().quit()
		return
	if _main == null or not _main.is_inside_tree():
		return
	if _frames == OPEN_AT:
		_open_wash()
		return
	if _frames < OPEN_AT:
		return
	var room := _room()
	room.set(&"_you_age", 0.0)
	room.set(&"_you_step", 0.0)
	var unlocked: Array = _main.get(&"unlocked")
	if _swap_at >= 0 and _frames - _swap_at == 12:
		var at := room.get_global_transform_with_canvas()
		var stretch := Vector2(get_viewport().get_texture().get_size()) / get_viewport().get_visible_rect().size
		var shed: Rect2 = at * (room.call(&"_shed_rect") as Rect2)
		_say("room zoom %s, shed rect in window px %s" % [str(room.call(&"_zoom")),
				str(Rect2(shed.position * stretch, shed.size * stretch))])
	if _swap_at < 0:
		var wash: WashRoom = _main.get(&"_wash")
		if _clean_at < 0 and unlocked.has(String(PIECE)):
			_clean_at = _frames
			_say("washed on frame %d" % _frames)
		if _clean_at < 0 and _frames >= SPRAY_FROM:
			_spray(wash)
		if _clean_at >= 0 and _frames - _clean_at == AFTER_CLEAN:
			_to_shed()
	elif _lift_at < 0 and _frames - _swap_at == SHELF_HOLD:
		_lift_at = _frames
		room.carrying = PIECE
		room.set(&"_carry_view", 0)
		room.set(&"_carried_from", -1)
		_say("lifted on frame %d, carry %s -> %s" % [_frames, str(_from.round()), str(_to.round())])
	if _lift_at >= 0 and _down_at < 0:
		var t := clampf(float(_frames - _lift_at) / float(CARRY), 0.0, 1.0)
		var eased := t * t * (3.0 - 2.0 * t)
		var arc := Vector2(0.0, -60.0 * sin(t * PI))
		room.set(&"_pointer", _from.lerp(_to, eased) + arc)
		room.queue_redraw()
		if t >= 1.0:
			room.set(&"_carry_view", _target_view)
			room.call(&"_put_down")
			_down_at = _frames
			_say("put down on frame %d, row %s" % [_frames, str(_placed_row())])
	elif _swap_at >= 0 and _lift_at < 0:
		# Planned each frame until the lift: the room has just come up and lays itself out
		# over its first frames, so its floor and its zoom are not final at the swap.
		_plan_carry()
		room.set(&"_pointer", _from)
	_capture()
	if _down_at >= 0 and _frames - _down_at >= HOLD:
		_say("frames %d" % _saved)
		get_tree().quit()


## English for the store, set by hand; the globe off the floor and back at the pump; the wash
## room up with it on the stand and the hose at its top level.
func _open_wash() -> void:
	TranslationServer.set_locale("en")
	Style.set_locale("en")
	var room := _room()
	var decor: Array = _main.get(&"decor")
	for i in range(decor.size() - 1, -1, -1):
		var row: Dictionary = decor[i]
		if StringName(row["piece"]) == PIECE:
			_target_cell = Vector2i(int(row["cell"][0]), int(row["cell"][1]))
			_target_view = int(row.get("view", 0))
			decor.remove_at(i)
	room.decor = decor
	var unlocked: Array = _main.get(&"unlocked")
	unlocked.erase(String(PIECE))
	var waiting: Array = _main.get(&"unwashed")
	waiting.clear()
	waiting.append(String(PIECE))
	var sheets: Sheets = _main.get(&"_sheets")
	for name: String in sheets.names:
		if waiting.size() > TRAY_MORE:
			break
		if name.begins_with("decor_pk_") and name != String(PIECE) and name != "decor_pk_bed":
			waiting.append(name)
	_main.set(&"hose_level", 3)
	_main.set(&"sludge", maxf(float(_main.get(&"sludge")), 4210.0))
	while int(_main.get(&"dog_count_level")) < 3:
		_main.set(&"dog_count_level", int(_main.get(&"dog_count_level")) + 1)
		_main.call(&"_add_dog")
	room.pack_size = func() -> int: return ShedRoom.DOGS_MOST
	_main.call(&"_set_wash", true)
	var wash: WashRoom = _main.get(&"_wash")
	_say("globe from cell %s view %d, picked %s" % [str(_target_cell), _target_view, str(wash.pick(PIECE))])


## Rows across the find, top to bottom, each from the piece's left to its right edge in that
## band and back the other way on the next, then the nearest grime left until it is done.
func _spray(wash: WashRoom) -> void:
	var stand := wash.stand()
	if _aim == Vector2.INF:
		_path = _rows(stand)
		_aim = _path[0] if not _path.is_empty() else stand.piece_box().get_center()
	var pace := SWEEP_PACE
	if _path.is_empty():
		pace = CHASE_PACE
		if _frames % RETARGET_EVERY == 0:
			_goal = _dirtiest_near(stand, _aim)
	else:
		_goal = _path[0]
		if _aim.distance_to(_goal) < 1.0:
			_path.remove_at(0)
	_aim = _aim.move_toward(_goal, pace / 60.0)
	stand.spray(_aim, true)
	if _frames % 20 == 0:
		_say("  f %d clean %.3f rows left %d" % [_frames, stand.share_clean(), _path.size()])


func _rows(stand: WashStand) -> Array[Vector2]:
	var solid: PackedByteArray = stand.get(&"_solid")
	var cols: int = stand.get(&"_cols")
	var rows: int = stand.get(&"_rows")
	var cell: float = stand.get(&"_cell")
	var origin: Vector2 = stand.get(&"_origin")
	var gap := maxi(int(stand.jet_radius() * float(WashStand.FINE) * ROW_GAP), 1)
	var out: Array[Vector2] = []
	var left_first := true
	var y := gap / 3
	while y < rows:
		var lo := cols
		var hi := -1
		for cy in range(maxi(y - gap / 2, 0), mini(y + gap / 2 + 1, rows)):
			for cx in cols:
				if solid[cy * cols + cx] != 0:
					lo = mini(lo, cx)
					hi = maxi(hi, cx)
		if hi >= lo:
			# Past the edges by a third of the jet, so the silhouette's own rim is washed too.
			var over := float(gap) * 0.33
			var a := origin + (Vector2(float(lo) - over, y) + Vector2(0.5, 0.5)) * cell
			var b := origin + (Vector2(float(hi) + over, y) + Vector2(0.5, 0.5)) * cell
			if left_first:
				out.append_array([a, b])
			else:
				out.append_array([b, a])
			left_first = not left_first
		y += gap
	return out


## The middle of the nearest cell with grime left on it, from `from`, in the stand's canvas.
func _dirtiest_near(stand: WashStand, from: Vector2) -> Vector2:
	var grime: PackedFloat32Array = stand.get(&"_grime")
	var cols: int = stand.get(&"_cols")
	var rows: int = stand.get(&"_rows")
	var cell: float = stand.get(&"_cell")
	var origin: Vector2 = stand.get(&"_origin")
	var best := from
	var best_d := INF
	for cy in range(0, rows, 2):
		for cx in range(0, cols, 2):
			if grime[cy * cols + cx] <= 0.0:
				continue
			var at := origin + (Vector2(cx, cy) + Vector2(0.5, 0.5)) * cell
			var d := at.distance_squared_to(from)
			if d < best_d:
				best_d = d
				best = at
	if best_d == INF:
		# Only odd cells left: look at every one.
		for i in grime.size():
			if grime[i] > 0.0:
				return origin + (Vector2(i % cols, i / cols) + Vector2(0.5, 0.5)) * cell
	return best


## The room's own close: into the shed. The whole pack let in, and the carry planned from the
## shelf's first row to where the globe stood.
func _to_shed() -> void:
	if _tall:
		# The vertical cut wants the room close (2026-10-05, Richard: "decoration should be
		# much more zoomed in"). The room draws at the largest whole zoom its panel holds, which
		# on the portrait canvas is 1; a canvas 1100 wide holds 2, and the edit crops the room
		# out of the wider frame at its own pixels.
		var win := get_window()
		win.size = SHED_WINDOW
		win.content_scale_size = SHED_CANVAS
	_main.call(&"_wash_to_shed")
	_swap_at = _frames
	var room := _room()
	for _try in 400:
		if room.dogs().size() >= ShedRoom.DOGS_MOST:
			break
		room.call(&"_room_shown")
	_say("swap on frame %d" % _frames)


## From the shelf's row for the globe to the middle of where it stood, in the room's canvas.
func _plan_carry() -> void:
	var room := _room()
	var list: Rect2 = room.call(&"_list_rect")
	var row := maxi(room.in_store().find(String(PIECE)), 0)
	_from = list.position + Vector2(list.size.x * 0.22, (float(row) + 0.5) * float(ShedRoom.ROW_HEIGHT))
	var span := room.span_of(PIECE, _target_view)
	var origin: Vector2 = room.call(&"_floor_origin")
	var zoom: float = room.call(&"_zoom")
	_to = origin + (Vector2(_target_cell) + Vector2(span) * 0.5) * zoom


func _placed_row() -> Variant:
	for row: Dictionary in _room().decor:
		if StringName(row["piece"]) == PIECE:
			return row["cell"]
	return null


func _capture() -> void:
	var image := get_viewport().get_texture().get_image()
	var scale := Vector2(image.get_size()) / get_viewport().get_visible_rect().size
	var at := Vector2.INF
	if _swap_at < 0:
		var wash: WashRoom = _main.get(&"_wash")
		if wash != null and _aim != Vector2.INF and _clean_at < 0:
			at = wash.stand().get_global_transform_with_canvas() * _aim
	else:
		var room := _room()
		at = room.get_global_transform_with_canvas() * (room.get(&"_pointer") as Vector2)
	if at == Vector2.INF:
		_pointers.store_line("%d -" % _saved)
	else:
		at *= scale
		_pointers.store_line("%d %d %d" % [_saved, roundi(at.x), roundi(at.y)])
	_pointers.flush()
	image.save_jpg(ProjectSettings.globalize_path(OUT).path_join("f_%04d.jpg" % _saved), 0.95)
	_saved += 1


## The copy's saved version raised to the game's own (see the header). The save is a
## `var_to_bytes` dictionary: the key "version" is followed by its value as a 32-bit int.
func _raise_version(path: String) -> void:
	var bytes := FileAccess.get_file_as_bytes(path)
	var key := "version".to_utf8_buffer()
	for i in bytes.size() - 20:
		if bytes.slice(i, i + key.size()) != key:
			continue
		# The string is padded to four bytes, then the value's type (2, an int) and the int.
		var at := i + 8
		if bytes.decode_u32(at) == 2:
			var was := bytes.decode_u32(at + 4)
			bytes.encode_u32(at + 4, Lake.SAVE_VERSION)
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_buffer(bytes)
			f.close()
			_say("save version %d raised to %d" % [was, Lake.SAVE_VERSION])
		return
