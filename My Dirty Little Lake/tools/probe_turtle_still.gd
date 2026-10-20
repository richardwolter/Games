extends Node
## Watches every turtle, frame by frame, for one standing frozen: the picture it shows (its
## frame's name), where it is drawn and which way it faces all unchanged for half a second
## or more while it is in sight on the sand or the water (not dived). At rest a turtle should
## nod to the beat (four frames a beat), otherwise walk, swim or paddle, so any such run is a
## frozen turtle. Runs are counted by state and pose, with the longest. Halfway through, the
## angler walks back and forth along the island's beach and a dog is sent past, so the
## frights (the tuck) are in it too. Also logs the beat clock, which the nod runs on.
##
##   godot --headless --path . --fixed-fps 60 res://tools/probe_turtle_still.tscn
##
## Own save, under its own node. `tools/last_probe_turtle_still.log`.

const LOG := "res://tools/last_probe_turtle_still.log"
const SAVE_PATH := "user://probe_turtle_still.save"
const SETTLE := 1800
const WATCH := 5400
const STILL_LEAST := 30
var _main: Node
var _frames := 0
var _log: FileAccess
var _last := {}
var _counts := {}
var _longest := {}
var _start_ms := 0
var _beat_at := -1.0


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
	if Time.get_ticks_msec() - _start_ms > 600000:
		get_tree().quit(2)
		return
	if _main == null or not _main.is_inside_tree():
		return
	if _frames == 6:
		_clean()
	var wild: Wildlife = _main.get(&"_wildlife")
	if _frames < SETTLE:
		return
	if _frames >= SETTLE + WATCH:
		_finish(wild)
		return
	if _frames >= SETTLE + WATCH / 2:
		_walk_the_angler(wild)
	if _frames % 60 == 0:
		var b := wild.beat()
		_log.store_line("%d beat %.2f (moved %.2f) turtles %d" % [_frames, b, b - _beat_at, wild._turtles.size()])
		_beat_at = b
	var i := 0
	for t: Dictionary in wild._turtles:
		_watch("T%d" % i, t, wild)
		i += 1


func _watch(who: String, t: Dictionary, wild: Wildlife) -> void:
	var state := int(t["state"])
	var shown := state != Wildlife.Turtle.UNDER and float(t["fade"]) > 0.5
	var sig := "%s|%s|%.0f" % [wild._turtle_frame(t), str((t["at"] as Vector2).round()), float(t["facing"])]
	var was: Dictionary = _last.get(who, {"sig": "", "run": 0})
	if shown and sig == String(was["sig"]):
		was["run"] = int(was["run"]) + 1
	else:
		_close(was)
		was["run"] = 1 if shown else 0
		was["key"] = "%s %s %s" % [["BASK", "WALK", "TUCK", "SWIM", "UNDER"][state], t.get("pose", ""),
			wild._turtle_frame(t).rstrip("0123456789")]
	was["sig"] = sig if shown else ""
	_last[who] = was
	if shown:
		_bump("shown frames")
	if int(was["run"]) == 120:
		_log.store_line("%d %s frozen: %s" % [_frames, who, str(t)])


func _close(was: Dictionary) -> void:
	var run := int(was.get("run", 0))
	if run < STILL_LEAST:
		return
	var key := String(was.get("key", "?"))
	_bump("frozen >=0.5s: " + key)
	if run >= 60:
		_bump("frozen >=1s: " + key)
	_longest[key] = maxi(int(_longest.get(key, 0)), run)


func _finish(wild: Wildlife) -> void:
	for who in _last:
		_close(_last[who])
	for k in _counts:
		_log.store_line("%s: %s" % [k, _counts[k]])
	for k in _longest:
		_log.store_line("longest frozen, frames, %s: %s" % [k, _longest[k]])
	_log.close()
	get_tree().quit()


## The angler walked along the island's beach by hand, back and forth, so the turtles there
## have a walker coming past them; set on its position, which is what the lake reads.
func _walk_the_angler(wild: Wildlife) -> void:
	var angler: Node2D = _main.get(&"_angler")
	if angler == null:
		return
	var isle: Array = wild._shore.filter(func(s: Dictionary) -> bool: return s["side"] == "island")
	if isle.is_empty():
		return
	var k := int(float(_frames - SETTLE) / 90.0) % isle.size()
	var a: Vector2 = isle[k]["land"]
	var b: Vector2 = isle[(k + 1) % isle.size()]["land"]
	var u := float((_frames - SETTLE) % 90) / 90.0
	angler.position = a.lerp(b, u)


func _bump(k: String) -> void:
	_counts[k] = int(_counts.get(k, 0)) + 1


func _clean() -> void:
	var grid: LakeGrid = _main.get(&"_grid")
	for index in grid.stacks.size():
		if grid.stacks[index].is_empty():
			continue
		var tile := grid.tile_of(index)
		var h := sin(float(tile.x) * 12.9898 + float(tile.y) * 78.233) * 43758.5453
		if (h - floor(h)) >= 0.03:
			grid.stacks[index] = PackedInt32Array()
	grid._rebuild()
	_main._build_filth_map()
	var wild: Wildlife = _main.get(&"_wildlife")
	wild.refresh(_main.clean_share(), _main.get(&"_clean_tiles"), 0.95, true)
	wild._reckon()
