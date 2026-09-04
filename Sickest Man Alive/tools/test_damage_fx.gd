extends SceneTree

## Checks the hit feedback holds for the number of FRAMES it is supposed to and
## then stops. Both effects are frame-counted rather than timed, so a test that
## measured seconds would prove nothing.
##
## Run: <godot> --headless --script tools/test_damage_fx.gd

var _frames: int = 0
var _main: Node
var _player: Player
var _vignette: DamageVignette
var _hit_frame: int = -1
var _white_seen: int = 0
var _vignette_seen: int = 0


func _initialize() -> void:
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	current_scene = _main
	_player = _main.get_node("Player") as Player
	_vignette = _main.get_node("HUD/DamageVignette") as DamageVignette


func _process(_delta: float) -> bool:
	_frames += 1

	if _frames == 20:
		_hit_frame = _frames
		_player.take_damage(1.0, Vector2.ZERO, {}, false)

	# Sampling starts the frame AFTER the hit. This loop runs ahead of the node
	# _process pass, so what is read on frame N is the state that frame N-1's
	# pass left behind -- which is exactly the state frame N-1 was drawn with.
	# Reading on the hit frame itself would just read back what this test set a
	# few lines earlier, before anything had been drawn at all.
	if _hit_frame > 0 and _frames > _hit_frame:
		var mat := (_player.get_node("Rig") as Node2D).material as ShaderMaterial
		if float(mat.get_shader_parameter("flash")) > 0.0:
			_white_seen += 1
		if _vignette.visible:
			_vignette_seen += 1

	if _frames == 40:
		print("white frames: %d  vignette frames: %d" % [_white_seen, _vignette_seen])
		assert(_white_seen == Player.HIT_FLASH_FRAMES,
			"player white blink held %d frames, wanted %d" % [_white_seen, Player.HIT_FLASH_FRAMES])
		assert(_vignette_seen == DamageVignette.HOLD_FRAMES,
			"vignette held %d frames, wanted %d" % [_vignette_seen, DamageVignette.HOLD_FRAMES])
		print("OK: white blink %d frame(s), blood vignette %d frame(s), both cleared after." % [
			_white_seen, _vignette_seen])
		return true

	return _frames > 200
