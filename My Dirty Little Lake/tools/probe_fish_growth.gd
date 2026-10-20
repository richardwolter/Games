extends Node
## How the fish come back as the lake clears: the clean share is stepped from nought to one in
## twentieths, by emptying the lake in a wave out from the island, and after each step the
## lake runs on for `HOLD` frames while the schools are counted. Logs, per step and at a few
## moments inside it, the schools and the fish of each tier (fish counted whole, and weighted
## by how far in they have faded), and how many schools arrived in the busiest frame and the
## busiest two seconds of the run. Headless is fine (nothing is photographed):
##
##   godot --headless --path . --fixed-fps 60 res://tools/probe_fish_growth.tscn
##
## Own save, under its own node. `tools/last_probe_fish_growth.log`.

const LOG := "res://tools/last_probe_fish_growth.log"
const SAVE_PATH := "user://probe_fish_growth.save"
## Frames each step of the share is held, and the frames inside it the schools are counted at.
const HOLD := 900
const MARKS := [60, 240, 480, 899]
const STEPS := 20
## Tiles emptied between two looks at the share.
const CHUNK := 120

var _main: Node
var _frames := 0
var _log: FileAccess
var _start_ms := 0
var _order: Array[int] = []
var _cleared := 0
var _step := -1
var _held := 0
## Frames at which a school arrived, for the busiest two seconds.
var _arrivals: Array[int] = []
var _busiest_frame := 0


func _ready() -> void:
	_start_ms = Time.get_ticks_msec()
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE_PATH)
	_main.set(&"autoload_save", false)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	add_child.call_deferred(_main)
	_log = FileAccess.open(LOG, FileAccess.WRITE)


func _physics_process(_delta: float) -> void:
	_frames += 1
	# A probe's safety never depends on the probe working: quit on a wall clock as well.
	if Time.get_ticks_msec() - _start_ms > 900000:
		_say("wall clock ran out")
		_log.close()
		get_tree().quit(2)
		return
	if _main == null or not _main.is_inside_tree():
		return
	if _frames < 6:
		return
	if _order.is_empty():
		_lay_order()
	_count_arrivals()
	if _step < 0 or _held >= HOLD:
		_step += 1
		if _step > STEPS:
			_finish()
			return
		_clean_to(float(_step) / float(STEPS))
		_held = 0
	_held += 1
	if MARKS.has(_held):
		_tally()


## Every tile holding anything, nearest the island first, with a little noise so the wave
## has a ragged front rather than a ring.
func _lay_order() -> void:
	var grid: LakeGrid = _main.get(&"_grid")
	var keyed: Array = []
	for index in grid.stacks.size():
		if grid.stacks[index].is_empty():
			continue
		var tile := grid.tile_of(index)
		var h := sin(float(tile.x) * 12.9898 + float(tile.y) * 78.233) * 43758.5453
		var key: float = Vector2(tile).distance_to(Iso.ISLAND_CENTRE) + (h - floor(h)) * 6.0
		keyed.append([key, index])
	keyed.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for k: Array in keyed:
		_order.append(int(k[1]))
	_say("tiles to clear %d" % _order.size())


## Empty tiles in the wave until the clean share reaches `target`.
func _clean_to(target: float) -> void:
	var grid: LakeGrid = _main.get(&"_grid")
	_main._build_filth_map()
	while float(_main.clean_share()) < target and _cleared < _order.size():
		for n in CHUNK:
			if _cleared >= _order.size():
				break
			grid.stacks[_order[_cleared]] = PackedInt32Array()
			_cleared += 1
		grid._rebuild()
		_main._build_filth_map()
	var fish: Fish = _main.get(&"_fish")
	_say("step %d: target %.2f share %.3f clean tiles %d (cleared %d of %d)" % [
		_step, target, float(_main.clean_share()), (_main.get(&"_clean_tiles") as PackedInt32Array).size(),
		_cleared, _order.size()])


func _count_arrivals() -> void:
	var fish: Fish = _main.get(&"_fish")
	if fish == null:
		return
	var now := 0
	for s: Dictionary in fish.schools():
		if not s.has("probe_seen"):
			s["probe_seen"] = true
			now += 1
			_arrivals.append(_frames)
	_busiest_frame = maxi(_busiest_frame, now)


func _tally() -> void:
	var fish: Fish = _main.get(&"_fish")
	var schools := [0, 0, 0]
	var whole := [0, 0, 0]
	var shown := [0.0, 0.0, 0.0]
	var biggest := [0, 0, 0]
	for s: Dictionary in fish.schools():
		var tier := int(s["tier"])
		var m: PackedVector2Array = s["members"]
		schools[tier] += 1
		whole[tier] += m.size()
		biggest[tier] = maxi(biggest[tier], m.size())
		var each: PackedFloat32Array = s.get("member_fade", PackedFloat32Array())
		for i in m.size():
			shown[tier] += float(s["fade"]) * (each[i] if i < each.size() else 1.0)
	_say("  +%4d f  share %.3f  schools %s  fish %s  shown %.1f/%.1f/%.1f  biggest %s  total %d schools %d fish" % [
		_held, float(_main.clean_share()), str(schools), str(whole), shown[0], shown[1], shown[2],
		str(biggest), fish.school_count(), whole[0] + whole[1] + whole[2]])


func _finish() -> void:
	var window := 0
	for i in _arrivals.size():
		var n := 0
		for j in range(i, _arrivals.size()):
			if _arrivals[j] - _arrivals[i] < 120:
				n += 1
		window = maxi(window, n)
	_say("arrivals %d, busiest frame %d schools, busiest two seconds %d schools" % [
		_arrivals.size(), _busiest_frame, window])
	_log.close()
	get_tree().quit()


func _say(line: String) -> void:
	_log.store_line(line)
	_log.flush()
