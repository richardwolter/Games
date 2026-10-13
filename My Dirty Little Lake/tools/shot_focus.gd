extends Node
## The pad's focus mark on real boards (2026-10-13, `/grill-me` with Richard: the gold halo
## was ugly). Photographs a pick on each board and logs its box (canvas pixels; the window is
## 1.5 of the canvas) so a sheet can be cropped round it. The look was picked off
## `tools/last_focus_sheet.png`, three looks side by side; this run shoots the one that ships.
##
## Desktop build, not --headless, `--fixed-fps 60`. Two runs: `FOCUS_FRONT=1` wears the main
## menu (its doors and its settings board), without it the lake's own boards (settings,
## controls, shop). Under its own node, on a save of its own that is removed first; the
## mode is put back on the way out, `settings.cfg` is not touched.

const OUT := "res://tools/film/focus/%s.png"
const LOG := "res://tools/film/focus/last_focus_%s.log"
const SAVE := "user://probe_focus.save"
## Frames a pick is given to settle (the halo glides) before it is photographed.
const SETTLE := 20

var _front := OS.get_environment("FOCUS_FRONT") == "1"
var _main: Node
var _frames := 0
var _plan: Array = []
var _step := 0
var _wait := 0
var _log: FileAccess
var _busy := false


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/film/focus"))
	_log = FileAccess.open(LOG % ("front" if _front else "lake"), FileAccess.WRITE)
	for path in [SAVE, SAVE + ".bak", SAVE + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE)
	_main.set(&"force_front", _front)
	add_child.call_deferred(_main)
	if _front:
		_plan = [
			[&"open", &""], [&"pick", 1], [&"shoot", "menu"],
			[&"open", &"menu_settings"], [&"pick", 3], [&"shoot", "menu_settings"],
		]
	else:
		_plan = [
			[&"open", &"settings"], [&"pick", 4], [&"shoot", "settings"],
			[&"open", &"controls"], [&"pick", 6], [&"shoot", "controls"],
			[&"open", &"shop"], [&"pick", 3], [&"shoot", "shop"],
			[&"open", &"shed"], [&"stand", 0], [&"shoot", "shed"],
		]
	_wait = 170 if _front else 120
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames > 4000:
		_finish()
		return
	if _main == null or not _main.is_inside_tree():
		return
	if _frames == 3:
		Pad.set_mode(Pad.Mode.PAD)
	if _busy:
		return
	if _wait > 0:
		_wait -= 1
		return
	if _step >= _plan.size():
		_finish()
		return
	var what: Array = _plan[_step]
	_step += 1
	match what[0]:
		&"open":
			_open(StringName(what[1]))
			_wait = SETTLE
		&"pick":
			_pick(int(what[1]))
			_wait = SETTLE
		&"stand":
			_stand_by(int(what[1]))
			_wait = SETTLE * 3
		&"shoot":
			_shoot(String(what[1]))


func _open(board: StringName) -> void:
	Pad.set_mode(Pad.Mode.PAD)
	match board:
		&"menu_settings":
			var menu: Node = _main.get(&"_menu")
			if menu != null:
				menu.call(&"_show_settings", true)
		&"settings":
			_main.call(&"_set_settings", true)
		&"controls":
			_main.call(&"_set_controls", true)
		&"shop":
			_main.call(&"_set_controls", false)
			_main.call(&"_set_settings", false)
			_main.call(&"_set_menu", true)
		&"shed":
			_main.call(&"_set_menu", false)
			_main.call(&"_set_shed", true)


## The player stood still at the foot of a placed piece in the house: the pick-up chip.
func _stand_by(index: int) -> void:
	var room: ShedRoom = _main.get(&"_room")
	if room == null or room.decor.is_empty():
		_say("no piece in the house to stand by")
		return
	var row: Dictionary = room.decor[mini(index, room.decor.size() - 1)]
	var span: Vector2i = room.span_of(StringName(row["piece"]), int(row.get("view", 0)))
	room.set(&"_you_at", Vector2(
		(float(int(row["cell"][0])) + float(span.x) * 0.5) / ShedRoom.CELL,
		(float(int(row["cell"][1])) + float(span.y)) / ShedRoom.CELL + 0.6
	))


func _pick(index: int) -> void:
	var owner := Pad.focus_owner()
	if owner == null:
		_say("no focus owner to pick on")
		return
	var list: Array = owner.call(&"pad_focus")
	if list.is_empty():
		return
	var entry: Dictionary = list[mini(index, list.size() - 1)]
	Pad.set(&"_focus_owner", owner)
	Pad.set(&"_stepped", true)
	Pad.set(&"_focus_key", entry.get("key", mini(index, list.size() - 1)))
	Pad.set(&"_focus_at", Vector2.INF)


func _shoot(shot: String) -> void:
	_busy = true
	for f in SETTLE:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT % shot))
	_say("%s box %s owner %s" % [shot, Pad.ring.box, Pad.focus_owner()])
	_busy = false


func _say(line: String) -> void:
	if _log != null:
		_log.store_line(line)
		_log.flush()


func _finish() -> void:
	Pad.set_mode(Pad.Mode.MOUSE)
	get_tree().quit()
