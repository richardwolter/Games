extends Node
## A frog put on a grown lily pad: its drawn offset (`Wildlife._frog_ride`) against the pad's
## own offset worked out here from flora_sway.gdshader's afloat lines, written out again
## (the packing, the swell, the wander), over two seconds. Headless:
##
##   godot --headless --path . --fixed-fps 60 res://tools/probe_frog_pad.tscn
##
## Own save, under its own node. `tools/last_probe_frog_pad.log`.

const LOG := "res://tools/last_probe_frog_pad.log"
const SAVE_PATH := "user://probe_frog_pad.save"
var _main: Node
var _frames := 0
var _log: FileAccess
var _frog: Dictionary = {}
var _worst := 0.0
var _moved := 0.0
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
	if Time.get_ticks_msec() - _start_ms > 300000:
		get_tree().quit(2)
		return
	if _main == null or not _main.is_inside_tree():
		return
	var wild: Wildlife = _main.get(&"_wildlife")
	var flora: Flora = _main.get(&"_flora")
	if _frames == 6:
		_clean()
	if _frames == 30:
		var pads := flora.pad_spots()
		_log.store_line("pads %d frogs %d" % [pads.size(), wild._frogs.size()])
		if pads.is_empty() or wild._frogs.is_empty():
			_log.store_line("FAIL no pad or no frog")
			_done(1)
			return
		_frog = wild._frogs[0]
		_frog["at"] = pads[0]
		_frog["on_pad"] = true
		_frog["ride_x"] = pads[0].x
		_frog["fade"] = 1.0
		wild._frog_sit(_frog)
		_frog["timer"] = 99.0
	if _frames > 30 and _frames < 150:
		var grid: LakeGrid = _main.get(&"_grid")
		var want := _shader_afloat(float(_frog["ride_x"]), grid.wave_time())
		var got: Vector2 = wild._frog_ride(_frog)
		_worst = maxf(_worst, got.distance_to(want))
		_moved = maxf(_moved, got.length())
		if _frames % 20 == 0:
			_log.store_line("%d ride %s shader %s state %d" % [_frames, got, want, int(_frog["state"])])
	if _frames == 150:
		_log.store_line("worst gap %.6f px, largest bob %.3f px" % [_worst, _moved])
		_done(0 if _worst < 0.001 and _moved > 0.5 else 1)


## flora_sway.gdshader's afloat branch, written out on its own: the anchor packed into the
## red and green as 16 bits, unpacked; the swell and the wander at `lake_clock * wave_speed`.
func _shader_afloat(x: float, t: float) -> Vector2:
	var span := LakeGrid.ANCHOR_SPAN
	var whole := int(round(clampf((x + span * 0.5) / span, 0.0, 1.0) * 65535.0))
	var high := float(whole >> 8)
	var low := float(whole & 255)
	var px := (high * 256.0 + low) / 65535.0 * span - span * 0.5
	var swell := sin(px * 0.011 + t) * 0.62 + sin(px * 0.029 - t * 1.7) * 0.38
	var v := Vector2(0.0, swell * 5.0)
	v.x += sin(t * 0.53 + px * 0.017) * 3.2
	v.y += cos(t * 0.41 + px * 0.023) * 3.2 * 0.5
	return v


func _done(code: int) -> void:
	_log.close()
	get_tree().quit(code)


func _clean() -> void:
	var grid: LakeGrid = _main.get(&"_grid")
	for index in grid.stacks.size():
		if grid.stacks[index].is_empty():
			continue
		var tile := grid.tile_of(index)
		var h := sin(float(tile.x) * 12.9898 + float(tile.y) * 78.233) * 43758.5453
		if (h - floor(h)) >= 0.002:
			grid.stacks[index] = PackedInt32Array()
	grid._rebuild()
	_main._build_filth_map()
	var wild: Wildlife = _main.get(&"_wildlife")
	var flora: Flora = _main.get(&"_flora")
	flora.refresh(1.0, true)
	wild.refresh(_main.clean_share(), _main.get(&"_clean_tiles"), 0.95, true)
	wild._reckon()
