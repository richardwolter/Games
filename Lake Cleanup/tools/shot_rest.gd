extends Node
## Photographs the player resting in the shed: on the sofa beside a dog, on the armchair from
## behind, asleep in the bed and reading at the bookcase (2026-09-29). Saves
## `tools/last_rest_<name>.png`, each cropped round the piece, and `tools/last_rest.log`.
##
## Desktop build, not --headless: nothing renders under the dummy driver. On its own save
## path, under its own node, so the player's run is never touched.

const SAVE := "user://probe_rest.save"
const LOG := "res://tools/last_rest.log"

const SHOTS := [
	# name, piece, view, rest age, a dog on its seat
	# The pack's pieces since 2026-10-03 (the reference the lake deals): their views run
	# front, side, back, so the back is view 2 on every one.
	["sofa", &"decor_pk_sofa", 0, 0.5, true],
	["sofa_back", &"decor_pk_sofa", 2, 0.5, false],
	["armchair", &"decor_pk_armchair", 0, 2.2, false],
	["armchair_back", &"decor_pk_armchair", 2, 0.5, false],
	["chair_back", &"decor_pk_wood_chair", 2, 0.5, false],
	["diner_back", &"decor_pk_diner_chair", 2, 0.5, false],
	["carved_back", &"decor_pk_carved_chair", 2, 0.5, false],
	["plain_back", &"decor_pk_chair", 2, 0.5, false],
	["green_back", &"decor_pk_green_chair", 2, 0.5, false],
	["bed", &"decor_pk_bed", 0, 8.0, true],
	["fancy_bed", &"decor_pk_fancy_bed", 0, 8.0, true],
	# Every face of both beds (2026-10-03): where the pillow is moves with the turn.
	["bed_side", &"decor_pk_bed", 1, 0.5, true],
	["bed_back", &"decor_pk_bed", 2, 0.5, true],
	["fancy_side", &"decor_pk_fancy_bed", 1, 0.5, true],
	["fancy_back", &"decor_pk_fancy_bed", 2, 0.5, true],
	["fancy_side_r", &"decor_pk_fancy_bed", 3, 0.5, true],
	["old_bed", &"decor_bed", 0, 0.5, false],
	["read", &"decor_pk_bookshelf", 0, 5.0, false],
]

var _lake: Node
var _frames := 0
var _shot := 0
var _log: FileAccess


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_log = FileAccess.open(LOG, FileAccess.WRITE)
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	_lake = load("res://scenes/main.tscn").instantiate()
	_lake.set(&"save_path", SAVE)
	_lake.set(&"autoload_save", false)
	add_child(_lake)


func _room() -> ShedRoom:
	return _lake.get_node(^"HUD/Shed/Pad/Lines/Room")


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames < 10:
		return
	if _frames == 10:
		_room().pack_size = func() -> int: return ShedRoom.DOGS_MOST
		_lake.call(&"_set_shed", true)
		# The whole pack, rather than whatever the roll gives (`shot_shed`'s rule).
		for _try in 400:
			if _room().dogs().size() >= ShedRoom.DOGS_MOST:
				break
			_room().call(&"_room_shown")
		return
	var phase := (_frames - 11) % 12
	if _shot >= SHOTS.size():
		get_tree().quit()
		return
	var shot: Array = SHOTS[_shot]
	# REST_ONLY=bed,fancy: only the shots whose name holds one of the words.
	var only := OS.get_environment("REST_ONLY")
	var wanted := only.is_empty()
	for word in only.split(",", false):
		wanted = wanted or String(shot[0]).contains(word)
	if phase == 0 and not wanted:
		_shot += 1
		_frames -= 1
		return
	var room := _room()
	if phase == 0:
		var decor: Array = room.decor
		decor.clear()
		var cell := Vector2i(18 * ShedRoom.CELL, 6 * ShedRoom.CELL)
		room.place(shot[1], cell, shot[2])
		var span := room.span_of(shot[1], shot[2])
		room.set(&"_you_at", Vector2(cell.x + span.x * 0.5, cell.y + span.y + 6) / float(ShedRoom.CELL))
		room.set(&"_you_pet", -1.0)
		room.rest_on(0)
		room.set(&"_rest_age", float(shot[3]))
		for dog in room.dogs():
			dog.seat = ""
			dog.at = Vector2(3.0, 12.0)
		if shot[4] and not room.dogs().is_empty():
			var dog: ShedRoom.ShedDog = room.dogs()[0]
			dog.seat = "%s@%d,%d" % [shot[1], cell.x, cell.y]
			dog.at = room.call(&"_seat_point", dog.seat)
			dog.state = &"sleep"
			dog.mood = 60.0
		room.set_process(false)
		room.queue_redraw()
		_log.store_line("%s resting %s dogs %d" % [shot[0], room.resting(), room.dogs().size()])
	elif phase == 8:
		var image := get_viewport().get_texture().get_image()
		var origin: Vector2 = room.get_global_rect().position + room.call(&"_floor_rect").position
		var zoom: float = room.call(&"_zoom")
		var scale := Vector2(image.get_size()) / get_viewport().get_visible_rect().size
		var span := Vector2(room.span_of(shot[1], shot[2]))
		var middle := Vector2(18 * ShedRoom.CELL, 6 * ShedRoom.CELL) + span * 0.5
		var centre := (origin + middle * zoom) * scale
		var box := Rect2i(Vector2i(centre) - Vector2i(170, 170), Vector2i(340, 300))
		box = box.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
		image.get_region(box).save_png(
			ProjectSettings.globalize_path("res://tools/last_rest_%s.png" % shot[0])
		)
		_log.flush()
	elif phase == 11:
		room.stand_up()
		room.set_process(true)
		_shot += 1
