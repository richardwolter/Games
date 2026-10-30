extends Node
## Round 4 of the staged shop's test branch (2026-10-29), photographed: a honeyed sweep's
## coins and its "+$N" rising over the catch.
##
## Desktop build: `<exe> --path . --fixed-fps 60 tools/shot_round4.tscn`. Saves
## `tools/last_round4_honey_{0,1}.png`. Its own save, deleted first and after, the lake under
## this node.

const SHOT := "res://tools/last_round4_%s.png"
const SAVE := "user://probe_round4.save"
const SETTLE := 90
const QUIT_AFTER_MS := 60000

var _main: Node
var _frames := 0
var _step := 0
var _busy := false
var _started_ms := 0


func _ready() -> void:
	_started_ms = Time.get_ticks_msec()
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE)
	add_child(_main)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if Time.get_ticks_msec() - _started_ms > QUIT_AFTER_MS:
		_finish()
		return
	if _busy or _frames < SETTLE:
		return
	match _step:
		0:
			var grid: LakeGrid = _main.get(&"_grid")
			var rubbish := -1
			for i in grid.defs.size():
				if not grid.defs[i].keepsake:
					rubbish = i
					break
			var defs := PackedInt32Array()
			for k in 12:
				defs.append(rubbish)
			_main.set(&"_honey_left", 10.0)
			var angler: Node2D = _main.get(&"_angler")
			_main.call(&"_honey_pay", defs, angler.position + Vector2(120.0, -40.0))
			_step += 1
			_frames = SETTLE - 18
		1:
			_shoot("honey_0")
		2:
			_step += 1
			_frames = SETTLE - 24
		3:
			_shoot("honey_1")
		_:
			_finish()


func _shoot(name_of: String) -> void:
	_busy = true
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(SHOT % name_of)
	_step += 1
	_busy = false


func _finish() -> void:
	set_physics_process(false)
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	get_tree().quit()
