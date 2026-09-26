extends Node
## Screenshot probe: loads main.tscn under this node, lets it run, saves the frame.
## Run windowed (a headless run has no renderer):
##   <godot> --path . tools/shot.tscn --log-file tools/_shot.log
## Optional user args after `--`: out=<path> frames=<n> fly=1 (sends the crew out).

var _frames := 0
var _target := 90
var _out := "res://tools/_shot.png"
var _fly := false
var _game: Node

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			match kv[0]:
				"out": _out = kv[1]
				"frames": _target = int(kv[1])
				"fly": _fly = kv[1] == "1"
	_game = load("res://main.tscn").instantiate()
	add_child(_game)

func _physics_process(_d: float) -> void:
	_frames += 1
	if _fly and _frames == 20 and _game.has_method("_on_dispatch_pressed"):
		_game.call("_on_dispatch_pressed")
	if _frames >= _target:
		var img := get_viewport().get_texture().get_image()
		img.save_png(_out)
		print("saved ", _out)
		get_tree().quit()
