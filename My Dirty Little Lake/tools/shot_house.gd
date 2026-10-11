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
const QUIT_AFTER_MS := 90000
const LAYERS := preload("res://tools/shot_house_layers.gd")

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
