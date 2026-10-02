extends Node
## The beehive on the island and its room, photographed (2026-09-30, the beehive sidequest;
## `docs/hive/contract.md` section 10).
##
## A probe, not a test: `test_lake`'s `_stage_hive` guards the rules; how the hive reads on
## the lawn and how each step of the room looks mid-move are things to look at, against the
## approved mockup (`tools/last_hive_mockup_{island,room}.png`). Run it with the desktop
## build, not --headless — nothing renders under the dummy driver, and no shader compiles:
##
##   <godot> --path . --fixed-fps 60 res://tools/shot_hive.tscn --log-file tools/last_hive_engine.log
##
## Saves, cropped on the hive with the angler beside it: `tools/last_hive_empty.png` (a new
## game's weathered hive), `last_hive_swarm.png` (the shrub up and the swarm on it),
## `last_hive_ready.png` (full window, the ready mark, three jars, the lamp) and
## `last_hive_busy.png` (the colony at work, the window half full). `last_hive_moment.png` is
## the whole window mid-moment, since its card stands low in the window where no crop on the
## hive reaches. `last_hive_honey.png` is the first honey's moment ("The honey is ready!").
## Then the room, each step driven by its own hooks part way through, first a new colony's
## visit (`last_hive_room_{catch,smoke,queen,settled}.png`) and then a harvest's
## (`last_hive_room_{uncap,pour,done}.png`), against the second pass's mockup
## (`tools/last_hive_mockup2_*.png`). And `tools/last_hive.log`.
##
## **On a save of its own, under its own node**, and with `Lake.force_hive`: a borrowed lake
## holds the hive's arc, and a lake hung off the root is the game's own and wears the front.
## Out on a wall clock whatever happens: a probe's safety may not depend on it working.

const Style := preload("res://scripts/style.gd")

const SAVE := "user://probe_hive.save"
const SETTLE := 2.0
## The island crops: this many window pixels round the hive, blown up `ZOOM` times, nearest,
## so a painted pixel can be read without opening the picture in anything else.
const CROP := Vector2i(360, 240)
const ZOOM := 2
const QUIT_AFTER_MS := 150000

var _lake: Node2D
var _age := 0.0
var _step := 0
var _log: FileAccess
## The room's steps, in order, and how far through them the probe is.
var _room_step := 0


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	# The mockup is in English. Set on the server, not through `Prefs`, which would write it
	# into the player's `settings.cfg` (test_lake's own way).
	TranslationServer.set_locale("en")
	Style.set_locale("en")
	_log = FileAccess.open("res://tools/last_hive.log", FileAccess.WRITE)
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	Lake.force_hive = true
	_lake = load("res://scenes/main.tscn").instantiate()
	_lake.set(&"save_path", SAVE)
	_lake.set(&"autoload_save", false)
	add_child(_lake)


func _say(line: String) -> void:
	if _log != null:
		_log.store_line(line)
		_log.flush()


func _hive() -> Hive:
	return _lake.get(&"_hive")


func _room() -> HiveRoom:
	return _lake.get(&"_hive_room")


## Where the angler stands: just off the stand's right, on screen, inside the hive's range so
## the lamp is lit when there is something to do, and clear of the picture so he does not
## stand in front of the shelf it is here to show.
func _beside() -> Vector2:
	return Hive.tile + Vector2(0.8, -0.3)


## The window, cropped on the hive's picture.
func _crop(called: String) -> void:
	var shot := get_viewport().get_texture().get_image()
	var scale := float(shot.get_width()) / get_viewport().get_visible_rect().size.x
	var hive := _hive()
	var middle := hive.get_global_transform_with_canvas() * hive.picture_rect().get_center()
	var at := middle * scale
	var corner := Vector2i(at) - Vector2i(CROP.x / 2, CROP.y / 2)
	corner = corner.clamp(Vector2i.ZERO, shot.get_size() - CROP)
	var cut := shot.get_region(Rect2i(corner, CROP))
	cut.resize(CROP.x * ZOOM, CROP.y * ZOOM, Image.INTERPOLATE_NEAREST)
	cut.save_png("res://tools/last_hive_%s.png" % called)
	_say("%s: stage %d, jars %d, lamp %s, at_hive %s, window %.2f, shrub %.2f, commuters %d" % [
		called, hive.stage, hive.jars, hive.lit, _lake.call(&"_at_hive"), hive.window_share(),
		hive.shrub_grown(), hive.commuters().size()
	])


func _whole(called: String) -> void:
	get_viewport().get_texture().get_image().save_png("res://tools/last_hive_%s.png" % called)


func _physics_process(delta: float) -> void:
	_age += delta
	if Time.get_ticks_msec() > QUIT_AFTER_MS:
		_say("wall clock: quit at step %d, room step %d" % [_step, _room_step])
		get_tree().quit(1)
		return
	match _step:
		0:
			if _age < SETTLE:
				return
			var angler: Angler = _lake.get(&"_angler")
			angler.stand_at(_beside())
			var hive := _hive()
			_say("hive tile %s, position %s, held %s, angler %s" % [
				Hive.tile, hive.position, hive.held, angler.tile_pos
			])
			_next()
		1:
			if _age < 1.5:
				return
			_crop("empty")
			_hive().set_stage(Hive.Stage.SWARM)
			_hive().moment_seen = true
			_next()
		2:
			if _age < Hive.SHRUB_GROW + 0.6:
				return
			_crop("swarm")
			# The moment, as the gate would owe it.
			_hive().moment_seen = false
			_lake.call(&"_owe_swarm")
			_say("moment started %s" % (float(_lake.get(&"_moment")) >= 0.0))
			_next()
		3:
			if _age < Lake.MOMENT_IN + 1.2:
				return
			var card: MomentCard = _lake.get(&"_moment_card")
			_whole("moment")
			_say("moment card: '%s'" % (card.text if card != null else "<none>"))
			_next()
		4:
			if float(_lake.get(&"_moment")) >= 0.0 and _age < 10.0:
				return
			var hive := _hive()
			hive.jars = Hive.JARS_PER
			hive.harvests = 1
			hive.first_done = true
			hive.set_stage(Hive.Stage.READY)
			_next()
		5:
			if _age < 1.5:
				return
			_crop("ready")
			var hive := _hive()
			var play: float = _lake.get(&"_play")
			hive.refill_from = play - 120.0
			hive.refill_at = play + 120.0
			hive.jars = 2 * Hive.JARS_PER
			hive.set_stage(Hive.Stage.BUSY)
			hive.play_now = play
			_next()
		6:
			if _age < 1.5:
				return
			_crop("busy")
			# The first honey's moment, as the refill would owe it.
			var ready_hive := _hive()
			ready_hive.jars = 0
			ready_hive.harvests = 0
			ready_hive.ready_seen = false
			ready_hive.set_stage(Hive.Stage.READY)
			_lake.call(&"_owe_ready")
			_next()
		7:
			if _age < Lake.MOMENT_IN + 1.2:
				return
			_whole("honey")
			var ready_card: MomentCard = _lake.get(&"_moment_card")
			_say("honey card: '%s'" % (ready_card.text if ready_card != null else "<none>"))
			_next()
		8:
			if float(_lake.get(&"_moment")) >= 0.0 and _age < 10.0:
				return
			# The room, the whole ceremony: back to a swarm, its moment already had.
			var hive := _hive()
			hive.jars = 0
			hive.harvests = 0
			hive.first_done = false
			hive.moment_seen = true
			hive.set_stage(Hive.Stage.SWARM)
			_lake.call(&"_open_hive_room")
			_say("room open %s, plan %s, size %s, origin %s, viewport %s" % [
				_lake.get(&"_hive_open"), _room().plan() if _room() != null else [],
				_room().size if _room() != null else Vector2.ZERO,
				_room().origin() if _room() != null else Vector2.ZERO,
				get_viewport().get_visible_rect().size
			])
			_next()
		9:
			_drive_room()
		10:
			# The harvest: the uncapping and the pour.
			if _age < 1.0:
				return
			var hive := _hive()
			_lake.call(&"_set_hive_room", false)
			hive.set_stage(Hive.Stage.READY)
			_lake.call(&"_open_hive_room")
			_say("harvest room: plan %s" % [_room().plan()])
			_room_step = 0
			_next()
		11:
			_drive_room()
		_:
			pass


func _next() -> void:
	_step += 1
	_age = 0.0


## The room, one step at a time: wait for the step to come up and wake, move it part way by
## its hooks, photograph it, and finish it by its hooks.
func _drive_room() -> void:
	var room := _room()
	if room == null:
		_say("no room")
		get_tree().quit(1)
		return
	var plan := room.plan()
	# The last step's finish puts the done card straight up: there is no settle to wait out.
	if room.is_done() and _room_step < plan.size():
		_say("room %s done" % plan[_room_step])
		_room_step = plan.size()
		_age = 0.0
	if _room_step >= plan.size():
		# The done card.
		if _age < 0.7:
			return
		var called := "room_done" if plan.has(&"pour") else "room_settled"
		_whole(called)
		_say("%s: card '%s', jars %d, stage %d" % [called, room.hint_text(), _hive().jars, _hive().stage])
		if plan.has(&"pour"):
			get_tree().quit()
		else:
			_next()
		return
	var want := plan[_room_step]
	if room.step_name() != want or room.index() != _room_step:
		_age = 0.0
		return
	var step := room.step()
	# Phase A: part way, then the picture; phase B: finish; the room's settle brings the next.
	if _age < 0.7:
		return
	if not step.has_meta(&"probe_moved"):
		step.set_meta(&"probe_moved", true)
		match want:
			&"catch":
				# Three clumps in, the fourth in hand over the lawn on its way to the box.
				for k in 3:
					step.call(&"box_clump", k)
				step.call(&"grab_at", step.call(&"clump_pos", 3))
				step.call(&"drag_to", Vector2(372.0, 176.0))
			&"smoke":
				step.call(&"smoke_ring", 0, 3.0)
				step.call(&"smoke_ring", 1, 0.1)
				step.call(&"aim", Vector2(262.0, 154.0) - HiveArt.anchor(&"smoker", &"nozzle")
					+ HiveArt.anchor(&"smoker", &"bellows") + Vector2(72.0, 30.0))
				step.call(&"hold", 3.0)
			&"queen":
				step.call(&"aim", (step.call(&"queen_pos") as Vector2) + Vector2(6.0, -3.0))
			&"uncap":
				step.call(&"cut_to", 0.5)
			&"pour":
				step.call(&"pour", 2.6)
				step.call(&"release")
				step.call(&"pour", 1.3)
		_age = 0.7
		return
	# The honey needs time to run: the uncapping is photographed well after the cut.
	var hold := 3.2 if want == &"uncap" else (1.8 if want == &"smoke" else 1.05)
	if _age < hold:
		return
	if not step.has_meta(&"probe_shot"):
		step.set_meta(&"probe_shot", true)
		_whole("room_%s" % want)
		_say("room %s: hint '%s', pad_free %s" % [want, room.hint_text(), room.pad_free()])
		match want:
			&"catch":
				step.call(&"let_go")
				step.call(&"settle")
			&"smoke":
				step.call(&"settle")
			&"queen":
				_say("queen found %s" % step.call(&"find_at", step.call(&"queen_pos")))
				step.call(&"settle")
			&"uncap":
				_say("bucket %.2f" % float(step.call(&"bucket_level")))
				step.call(&"settle")
			&"pour":
				step.call(&"settle")
				_say("jars done %d" % step.call(&"jars_done"))
		return
	if step.is_done():
		_say("room %s done" % want)
		_room_step += 1
		_age = 0.0
