extends Node
## A playable lake whose shed shelf holds every piece of the 0_mem0ry decoration batch
## (`tools/build_pack_decor.py`, the decor_pk_* pieces), with the shed opened for you. Place,
## turn (R), switch (E), close and reopen the shed as in play. A save of its own, so the
## player's run is never touched. Desktop build:
##
##   godot --path . res://tools/play_decor.tscn
##
## The layout is kept between runs (2026-10-02, Richard decorates, the probe photographs): the
## lake saves on the window's close and every `SAVE_EVERY` seconds, and the next run loads it.
## `PLAY_DECOR_FRESH=1` starts over with an empty room. The whole pack is let into the shed.
##
## `PLAY_DECOR_SHOT=1`: load the saved layout, open the shed with the whole pack in, and save
## `tools/last_play_decor[_n].png` (the window) and `tools/last_play_decor_room[_n].png` (the
## room alone), `SHOTS` of each, then quit without writing the save.

const Style := preload("res://scripts/style.gd")
const SAVE_PATH := "user://play_decor.save"
const SAVE_EVERY := 10.0
## Frames to let the room settle (dogs walk to their spots, the light lands) before the shot.
const SHOT_AFTER := 150
## How many pictures, how many frames apart: the dogs wander, so there is one to pick from.
const SHOTS := 6
## How far in front of the fireplace's foot the sleeping dog lies, in cells.
const FIRE_FRONT := 0.9
const SHOT_GAP := 90

var _main: Node
var _frames := 0
var _shot := false
var _save_in := SAVE_EVERY
var _taken := 0


func _ready() -> void:
	_shot = OS.get_environment("PLAY_DECOR_SHOT") == "1"
	if OS.get_environment("PLAY_DECOR_FRESH") == "1":
		for path in [SAVE_PATH, SAVE_PATH + ".bak", SAVE_PATH + ".tmp"]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE_PATH)
	_main.set(&"autoload_save", FileAccess.file_exists(SAVE_PATH))
	# Under this node, not the root: the root's lake wears the menu.
	add_child.call_deferred(_main)


func _process(delta: float) -> void:
	_frames += 1
	if _main == null or not _main.is_inside_tree():
		return
	if _frames == 6:
		_open()
		return
	if _shot:
		_hold_pose()
		if _frames >= SHOT_AFTER and (_frames - SHOT_AFTER) % SHOT_GAP == 0:
			_taken += 1
			_photograph("_%d" % _taken if _taken > 1 else "")
			if _taken >= SHOTS:
				get_tree().quit()
		return
	_save_in -= delta
	if _frames > 6 and _save_in <= 0.0:
		_save_in = SAVE_EVERY
		_main.call(&"save_game")


func _open() -> void:
	# English for the store's picture, set by hand so `settings.cfg` is never written.
	TranslationServer.set_locale("en")
	Style.set_locale("en")
	var sheets: Sheets = _main.get(&"_sheets")
	var unlocked: Array[String] = _main.get(&"unlocked")
	for name: String in sheets.names:
		if (name.begins_with("decor_pk_") or name == "decor_vynil_player") and not unlocked.has(name):
			unlocked.append(name)
	while int(_main.get(&"dog_count_level")) < 3:
		_main.set(&"dog_count_level", int(_main.get(&"dog_count_level")) + 1)
		_main.call(&"_add_dog")
	var room: ShedRoom = _main.get_node(^"HUD/Shed/Pad/Lines/Room")
	room.pack_size = func() -> int: return ShedRoom.DOGS_MOST
	_main.call(&"_set_shed", true)
	if _shot:
		# The whole pack, rather than whatever the roll lets in: see `shot_shed`.
		for _try in 400:
			if room.dogs().size() >= ShedRoom.DOGS_MOST:
				break
			room.call(&"_room_shown")
		_by_the_fire(room)


## The shot's poses (2026-10-02, Richard): the player on the first frame of the idle row,
## and the dog asleep by the fire kept there. Held every frame, since the room's own clocks
## run on.
func _hold_pose() -> void:
	var room: ShedRoom = _main.get_node(^"HUD/Shed/Pad/Lines/Room")
	room.set(&"_you_age", 0.0)
	room.set(&"_you_step", 0.0)
	if _fire_dog != null:
		_fire_dog.mood = 1.0e9
		_fire_dog.state = &"sleep"


var _fire_dog: ShedRoom.ShedDog


## A dog with no seat laid asleep on the floor in front of the fireplace: the middle of the
## hearth across, `FIRE_FRONT` cells in front of its foot.
func _by_the_fire(room: ShedRoom) -> void:
	var hearth: Dictionary = {}
	for row: Dictionary in room.decor:
		if String(row["piece"]) == "decor_pk_fireplace":
			hearth = row
	if hearth.is_empty():
		push_warning("play_decor: no fireplace in the room")
		return
	var dog: ShedRoom.ShedDog = null
	for each in room.dogs():
		if each.seat.is_empty():
			dog = each
	if dog == null and not room.dogs().is_empty():
		dog = room.dogs()[room.dogs().size() - 1]
		room.call(&"_drop_seat", dog)
	if dog == null:
		return
	var span := room.span_of(StringName(hearth["piece"]), int(hearth.get("view", 0)))
	var middle := (float(int(hearth["cell"][0])) + float(span.x) * 0.5) / float(ShedRoom.CELL)
	var foot: float = room.call(&"_foot_of", hearth)
	var spot := Vector2(middle, foot + FIRE_FRONT)
	for step in 12:
		if room.call(&"_dog_may_stand", spot, dog.over):
			break
		spot.y += 0.25
	dog.at = spot
	dog.target = spot
	dog.state = &"sleep"
	dog.mood = 1.0e9
	dog.age = 0.0
	_fire_dog = dog


func _photograph(suffix: String) -> void:
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://tools/last_play_decor%s.png" % suffix))
	var room: ShedRoom = _main.get_node(^"HUD/Shed/Pad/Lines/Room")
	var shed: Rect2 = room.call(&"_shed_rect")
	# The room's rect is in the room's own canvas; the picture is the window's pixels.
	var scale := Vector2(image.get_size()) / get_viewport().get_visible_rect().size
	var box := Rect2i(
		Vector2i((room.get_global_rect().position + shed.position) * scale),
		Vector2i(shed.size * scale)
	).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if box.size.x > 0 and box.size.y > 0:
		image.get_region(box).save_png(ProjectSettings.globalize_path("res://tools/last_play_decor_room%s.png" % suffix))
