extends Node
## The pump on the island and the wash room it opens, photographed (issue #37).
##
## A probe, not a test: `test_lake`'s `_stage_wash` guards the rules; where the pump stands
## beside the hut and what the tray looks like are things to look at. Run it with the desktop
## build, not --headless — nothing renders under the dummy driver:
##
##   <godot> --path . --fixed-fps 60 res://tools/shot_pump.tscn
##
## Saves `tools/last_pump.png` (cropped on the pump, the angler beside it so the lamp is lit),
## `tools/last_wash_room.png` (the room with three finds waiting, one on the stand),
## `tools/last_wash_room_clean.png` (the same over a cleaned lake, late in the day) and
## `tools/last_pump.log`.
##
## **On a save of its own, under its own node**: a lake hung off the root is the game's own
## lake and wears the front, and a probe may not touch the player's run.

const SAVE := "user://probe_pump.save"
const SETTLE := 2.0
const CROP := Vector2i(520, 360)

var _lake: Node2D
var _age := 0.0
var _step := 0
var _log: FileAccess


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_log = FileAccess.open("res://tools/last_pump.log", FileAccess.WRITE)
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	_lake = load("res://scenes/main.tscn").instantiate()
	_lake.set(&"save_path", SAVE)
	_lake.set(&"autoload_save", false)
	add_child(_lake)


func _say(line: String) -> void:
	if _log != null:
		_log.store_line(line)
		_log.flush()


func _physics_process(delta: float) -> void:
	_age += delta
	# A probe's safety may not depend on the probe working: out after a while regardless.
	if Time.get_ticks_msec() > 90000:
		get_tree().quit(1)
		return
	match _step:
		0:
			if _age < SETTLE:
				return
			var angler: Angler = _lake.get(&"_angler")
			angler.stand_at(Pump.tile + Vector2(0.9, 0.9))
			_say("pump tile %s, angler %s" % [Pump.tile, angler.tile_pos])
			_step = 1
			_age = 0.0
		1:
			if _age < 1.5:
				return
			var pump: Node2D = _lake.get(&"_pump")
			var shot := get_viewport().get_texture().get_image()
			var scale := float(shot.get_width()) / get_viewport().get_visible_rect().size.x
			var at := pump.get_global_transform_with_canvas().origin * scale
			var corner := Vector2i(at) - Vector2i(CROP.x / 2, CROP.y * 2 / 3)
			corner = corner.clamp(Vector2i.ZERO, shot.get_size() - CROP)
			shot.get_region(Rect2i(corner, CROP)).save_png("res://tools/last_pump.png")
			_say("at pump: %s, lamp %s" % [_lake.call(&"_at_pump"), pump.get(&"lit")])
			var sheets: Sheets = _lake.get(&"_sheets")
			var waiting: Array = _lake.get(&"unwashed")
			for name: String in sheets.names:
				if WashRoom.is_find(sheets, name) and name != "decor_bed" and waiting.size() < 3:
					waiting.append(name)
			_lake.set(&"sludge", 12.0)
			_lake.call(&"_set_wash", true)
			var room: WashRoom = _lake.get(&"_wash")
			# A purse of 12: the big ones are drawn back, and the first it can cover goes on.
			for name: String in waiting:
				if room.pick(StringName(name)):
					_say("picked %s" % name)
					break
			for name: String in waiting:
				_say("%s soap %d, affordable %s" % [
					name, room.soap_of(StringName(name)), room.can_afford(StringName(name))
				])
			_step = 2
			_age = 0.0
		2:
			var room: WashRoom = _lake.get(&"_wash")
			var box := room.stand().piece_box()
			room.stand().spray(box.position + box.size * Vector2(0.35 + _age * 0.2, 0.4), true)
			if _age < 1.2:
				return
			get_viewport().get_texture().get_image().save_png("res://tools/last_wash_room.png")
			_say("backdrop painted %s, filth %.2f, state %d, sun %.2f" % [
				room.backdrop().is_painted(), room.backdrop().filth,
				WashBackdrop.state_of(room.backdrop().filth), room.backdrop().sun
			])
			_say("clean %.2f" % room.stand().share_clean())
			var art: Image = room.stand().get(&"_art")
			var solid: PackedByteArray = room.stand().get(&"_solid")
			_say("art %s, solid %d of %d, region %s" % [
				art != null, solid.count(1), solid.size(), room.stand().get(&"_region")
			])
			# Two hulls whatever the fleet, one on each lane, one each way: which way a
			# bow points is a thing to look at.
			room.backdrop().fleet = 2
			room.backdrop().reset()
			var lanes := 0
			for hull in room.backdrop().hulls():
				hull.wait = 0.0
				hull.way = 1.0 if lanes == 0 else -1.0
				hull.x = room.size.x * (0.62 + 0.2 * lanes)
				lanes += 1
			# Something of everything in the picture: a pair of pigeons well across, and the
			# pack wherever it has got to.
			for k in 2:
				var bird := room.backdrop().send_bird(true, 0.25 + 0.12 * k)
				if bird != null:
					bird.along = room.size.x * (0.5 + 0.2 * k)
			_say("hulls %d, flotsam %d" % [
				room.backdrop().hulls().size(), room.backdrop().flotsam_shown()
			])
			_say("dogs %d, birds %d" % [room.backdrop().dogs().size(), room.backdrop().birds().size()])
			# And again over a lake that has come clean, late in the day.
			room.day = null
			room.backdrop().filth = 0.0
			room.backdrop().sun = 0.8
			_step = 3
			_age = 0.0
		3:
			if _age < 0.3:
				return
			get_viewport().get_texture().get_image().save_png("res://tools/last_wash_room_clean.png")
			get_tree().quit()
