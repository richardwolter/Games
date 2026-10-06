extends Node
## Watches the capybara pairs walk, frame by frame, and counts what reads as jiggle: a
## follower or lead switching between moving and resting pictures within a few frames,
## turning round (facing) and back, the view swapping side/front/back and back, and a step
## that reverses the last. Also counts wildlife that goes away while on screen. Headless is
## fine (no picture is taken):
##
##   godot --headless --path . --fixed-fps 60 res://tools/probe_capy.tscn
##
## Own save, under its own node. `tools/last_probe_capy.log`.

const LOG := "res://tools/last_probe_capy.log"
const SAVE_PATH := "user://probe_capy.save"
const SETTLE := 2400
const WATCH := 3600
var _main: Node
var _frames := 0
var _log: FileAccess
var _last := {}
var _counts := {}
var _start_ms := 0


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
	if _frames < SETTLE:
		return
	if _frames >= SETTLE + WATCH:
		for k in _counts:
			_log.store_line("%s: %s" % [k, _counts[k]])
		_log.close()
		get_tree().quit()
		return
	var wild: Wildlife = _main.get(&"_wildlife")
	var i := 0
	for c: Dictionary in wild.land_animals():
		if c["kind"] != &"capy":
			continue
		var who := "%s%d" % ["F" if c.has("lead") else "L", i]
		i += 1
		_watch(who, c, wild)


func _watch(who: String, c: Dictionary, wild: Wildlife) -> void:
	var frame: String = wild._land_frame(c)
	var moving := frame.contains("walk") or frame.contains("run")
	var at: Vector2 = c["at"]
	var was: Dictionary = _last.get(who, {})
	if not was.is_empty():
		var step := at - (was["at"] as Vector2)
		var prev_step: Vector2 = was["step"]
		if step.length() > 0.01 and prev_step.length() > 0.01 and step.dot(prev_step) < 0.0:
			_bump(who + " step reversed")
		if bool(was["moving"]) != moving:
			if _frames - int(was["moving_at"]) < 6:
				_bump(who + " move/rest flicker")
			was["moving_at"] = _frames
		if float(was["facing"]) != float(c["facing"]):
			if _frames - int(was["facing_at"]) < 20:
				_bump(who + " facing flicker")
			was["facing_at"] = _frames
		if String(was["view"]) != String(c["view"]):
			if _frames - int(was["view_at"]) < 20:
				_bump(who + " view flicker")
			was["view_at"] = _frames
		if _frames % 6 == 0 or who.begins_with("F0") or who.begins_with("L0"):
			if _frames < SETTLE + 600:
				_log.store_line("%d %s at %s step %s state %d frame %s face %.0f view %s" % [_frames, who, at.round(),
					step, int(c["state"]), frame, float(c["facing"]), c["view"]])
		was["step"] = step if step.length() > 0.01 else prev_step
	else:
		was = {"moving_at": 0, "facing_at": 0, "view_at": 0, "step": Vector2.ZERO}
	was["at"] = at
	was["moving"] = moving
	was["facing"] = float(c["facing"])
	was["view"] = String(c["view"])
	_last[who] = was
	_bump(who + " frames")


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
	wild.refresh(_main.clean_share(), _main.get(&"_clean_tiles"), 0.95)
	wild._reckon()
