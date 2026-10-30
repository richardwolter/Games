extends Node
## The house's inside at its three stages, drawn by the game (2026-10-11, `HouseInside`):
## tools/last_house_s{1,2,3}.png, stage 1 in a shower (last_house_s1_rain.png), the stage-ups
## a second in (last_house_up12.png, last_house_up23.png), and tools/last_house.log (the
## blocking checks: a piece refused on a hole, the player held off one).
##
## Desktop build, not --headless:
##   godot --path . --log-file <path> res://tools/shot_house.tscn
## Its own save path and no autosave. Furnished as the mockup's captures were
## (tools/shot_house_layers.gd), pieces the layout keeps clear of.

const OUT := "res://tools/"
const QUIT_AFTER_MS := 240000
const LAYERS := preload("res://tools/shot_house_layers.gd")
const Style := preload("res://scripts/style.gd")

var _main: Node
var _room: ShedRoom
var _n := 0
var _busy := false
var _lines: Array[String] = []
var _rain := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"autoload_save", false)
	_main.set(&"save_path", "user://probe_house.save")
	add_child(_main)


func _process(_delta: float) -> void:
	if _rain:
		Weather.now = 1.0
	if Time.get_ticks_msec() > QUIT_AFTER_MS:
		_finish("gave up: wall clock")
		return
	if _busy:
		return
	_n += 1
	if _n == 10:
		_busy = true
		_run()


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _shot(name: String) -> void:
	for i in 2:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name))


func _stage(stage: int, seen: int) -> void:
	_main.set(&"_inside_pin", stage)
	_main.call(&"_latch_house")
	_room.house_seen = seen
	_main.call(&"_set_shed", false)
	await _wait(2)
	_main.call(&"_set_shed", true)


func _run() -> void:
	_room = _main.get_node(^"HUD/Shed/Pad/Lines/Room")
	if OS.get_environment("HOUSE_STORE") != "":
		await _store_still()
		return
	if OS.get_environment("HOUSE_FILM") != "":
		await _store_film()
		return
	# The mending's shine (2026-10-29): tools/last_house_shine_{taps,burst}.png, a second into
	# the stage-up and just after its chime.
	if OS.get_environment("HOUSE_SHINE") != "":
		var seen: Dictionary = _main.get(&"_cues_seen")
		seen[&"demo_house"] = true
		await _stage(1, 1)
		_furnish(LAYERS.STAGE_1)
		await _stage(2, 1)
		_room.mend_card = false
		await _wait(60)
		await _shot("last_house_shine_taps.png")
		await _wait(90)
		await _shot("last_house_shine_burst.png")
		_finish("shine")
		return
	var placed: Array = []
	for stage in [1, 2, 3]:
		placed.append_array([LAYERS.STAGE_1, LAYERS.STAGE_2, LAYERS.STAGE_3][stage - 1])
		await _stage(stage, stage)
		_furnish(placed)
		await _wait(30)
		await _shot("last_house_s%d.png" % stage)
		if stage == 1:
			_check_blocks()
			_rain = true
			await _wait(200)
			await _shot("last_house_s1_rain.png")
			_rain = false
			Weather.now = 0.0
	await _stage(2, 1)
	await _wait(12)
	await _shot("last_house_up12.png")
	await _stage(3, 2)
	await _wait(12)
	await _shot("last_house_up23.png")
	_finish("done")


## The store's still (2026-10-16): stage 1 furnished as the probe's first stage, a few early
## finds waiting on the shelf, no pointing hands; tools/last_house_store.png.
const STORE_SHELF := ["decor_pk_coffee_table", "decor_vynil_player", "decor_pk_flower_vase"]


func _store_still() -> void:
	TranslationServer.set_locale("en")
	Style.set_locale("en")
	var unlocked: Array[String] = _main.get(&"unlocked")
	for name: String in STORE_SHELF:
		unlocked.append(name)
	await _stage(1, 1)
	_furnish_store()
	var tried: Array[String] = _main.get(&"switch_tried")
	for row: Dictionary in _main.get(&"decor"):
		if not tried.has(String(row["piece"])):
			tried.append(String(row["piece"]))
	_room.pack_size = func() -> int: return 1
	for _try in 200:
		if not _room.dogs().is_empty():
			break
		_room.call(&"_room_shown")
	for _f in 90:
		_hold_store()
		await get_tree().process_frame
	await _shot("last_house_store.png")
	_finish("store still")


## Stage 1 laid out for the store (2026-10-16, Richard): the bed against the left wall below
## the hole, the nightstand at its head with the record player centred on it, the coat rack
## beside the door. Cells, as the layouts are.
const STORE_ROWS := [[&"decor_pk_sofa", 22, 8], [&"decor_pk_wood_chair", 14, 10],
	[&"decor_pk_coat_stand", 24, -3]]
## The bed turned side on (view 1), its cell; where the player stands (cells) facing left.
const STORE_BED := Vector2i(1, 21)
const STORE_BED_VIEW := 1
const STORE_YOU := Vector2(36.0, 15.0)


const SIT_IN := 3


## The store's clip of the house mending (2026-10-16): the still's stage-1 room, then the
## door reopened on stage 2 (its stage-up playing in), then on stage 3. Every frame a JPEG
## in tools/film/c5_house/, the gaps where the door shut left out.
const FILM_DIR := "res://tools/film/c5_house"
const FILM_HOLD := [90, 200, 230]
var _film_n := 0


func _store_film() -> void:
	TranslationServer.set_locale("en")
	Style.set_locale("en")
	var dir := ProjectSettings.globalize_path(FILM_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	for old in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(old))
	await _stage(1, 1)
	_furnish_store()
	_room.pack_size = func() -> int: return 1
	for _try in 200:
		if not _room.dogs().is_empty():
			break
		_room.call(&"_room_shown")
	var tried: Array[String] = _main.get(&"switch_tried")
	for row: Dictionary in _main.get(&"decor"):
		if not tried.has(String(row["piece"])):
			tried.append(String(row["piece"]))
	for _f in 40:
		_hold_store()
		await get_tree().process_frame
	await _film(FILM_HOLD[0])
	await _stage(2, 1)
	_room.pack_size = func() -> int: return 1
	await _film(FILM_HOLD[1])
	await _stage(3, 2)
	_room.pack_size = func() -> int: return 1
	await _film(FILM_HOLD[2])
	_finish("film %d frames" % _film_n)


func _film(frames: int) -> void:
	for _f in frames:
		_hold_store()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(
				ProjectSettings.globalize_path(FILM_DIR).path_join("%05d.jpg" % _film_n), 0.94)
		_film_n += 1


func _furnish_store() -> void:
	_furnish(STORE_ROWS)
	var bed := _room.span_of(&"decor_pk_bed", STORE_BED_VIEW)
	if not _room.place(&"decor_pk_bed", STORE_BED * ShedRoom.CELL, STORE_BED_VIEW):
		_say("refused: bed side on")
	var stand := _room.span_of(&"decor_pk_nightstand", 0)
	var player := _room.span_of(&"decor_vynil_player", 0)
	var at := Vector2i(STORE_BED.x * ShedRoom.CELL + bed.x + 3, STORE_BED.y * ShedRoom.CELL)
	if not _room.place(&"decor_pk_nightstand", at):
		_say("refused: nightstand at %s" % str(at))
	# Two cells up the stand, as the probe's own layout had it, less `SIT_IN` so it sits down
	# into the stand's top rather than on its edge.
	var on := Vector2i(at.x + (stand.x - player.x) / 2, at.y - 2 * ShedRoom.CELL + SIT_IN)
	if not _room.place(&"decor_vynil_player", on):
		_say("refused: record player at %s" % str(on))


## The player on the right facing left, and the one dog asleep on the sofa: held every
## frame, the room's own clocks running on.
func _hold_store() -> void:
	_room.set(&"_you_at", STORE_YOU)
	_room.set(&"_you_facing", Vector2(-1.0, 0.0))
	_room.set(&"_you_age", 0.0)
	_room.set(&"_you_step", 0.0)
	if _room.dogs().is_empty():
		return
	var dog: ShedRoom.ShedDog = _room.dogs()[0]
	for seat: Dictionary in _room.call(&"_seats"):
		if String(seat["key"]).begins_with("decor_pk_sofa@"):
			dog.seat = String(seat["key"])
			dog.over = seat["over"]
			dog.at = seat["feet"]
			dog.target = seat["feet"]
	dog.state = &"sleep"
	dog.mood = 1.0e9


func _furnish(rows: Array) -> void:
	var decor: Array = _main.get(&"decor")
	decor.clear()
	_room.decor = decor
	for want: Array in rows:
		if not _room.sheets.has(want[0]):
			continue
		var at := Vector2i(int(want[1]), int(want[2])) * ShedRoom.CELL
		if not _room.place(want[0], at):
			_say("refused: %s at %s,%s" % want)


## A hole refuses a piece and a walker; a puddle refuses a piece and not a walker.
func _check_blocks() -> void:
	var holes := HouseInside.walk_blocks(1)
	var pools := HouseInside.puddles(1)
	_say("stage 1: %d hole rects, %d puddles" % [holes.size(), pools.size()])
	if holes.is_empty():
		return
	var r: Rect2i = holes[0]
	var mid := Vector2(r.get_center())
	_say("a chair on a hole refused: %s" % str(not _room.can_place(&"decor_pk_wood_chair",
		Vector2i(r.get_center()) - Vector2i(6, 20))))
	_say("a walker on a hole refused: %s" % str(not _room.call(&"_dog_may_stand", mid / float(ShedRoom.CELL))))
	if not pools.is_empty():
		var p: Vector2 = Vector2(pools[0].get_center())
		_say("a walker in a puddle allowed: %s" % str(_room.call(&"_dog_may_stand", p / float(ShedRoom.CELL))))


func _say(text: String) -> void:
	_lines.append(text)


func _finish(why: String) -> void:
	_say(why)
	var f := FileAccess.open(OUT + "last_house.log", FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_lines) + "\n")
		f.close()
	get_tree().quit()
