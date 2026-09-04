extends SceneTree

## Covers the two things that are easy to get silently wrong here: the syringe
## must not fire unless the player is asking it to, and the body's bob must not
## drag the aim around with it.
##
## Run: <godot> --headless --script tools/test_motion.gd

## Gated on accumulated delta, not frame count: headless runs uncapped, so 30
## frames can be a couple of milliseconds while the syringe's cooldown is real
## seconds.
var _frames: int = 0
var _elapsed: float = 0.0
var _main: Node
var _player: Player
var _stage: int = 0

var _y_seen: Array[float] = []
var _rot_seen: Array[float] = []
var _scale_seen: Array[float] = []


func _initialize() -> void:
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	current_scene = _main
	_player = _main.get_node("Player") as Player


func _process(delta: float) -> bool:
	_frames += 1
	_elapsed += delta
	if _frames < 5:
		return false

	var rig := _player.get_node("Rig") as Node2D
	_y_seen.append(rig.position.y)
	_rot_seen.append(rig.rotation)
	_scale_seen.append(rig.scale.y)

	# Something to shoot at, so "did not fire" cannot be "had no reason to".
	if _stage == 0:
		_stage = 1
		var dummy := (load("res://scenes/enemy.tscn") as PackedScene).instantiate() as Enemy
		dummy.max_health = 9999.0
		dummy.move_speed = 0.0
		dummy.contact_damage = 0.0
		dummy.global_position = _player.global_position + Vector2(140.0, 0.0)
		current_scene.add_child(dummy)
		return false

	# Idle: no stick, no fire button, so nothing should leave the needle.
	if _stage == 1 and _elapsed > 1.0:
		_stage = 2
		assert(not _player._aiming, "player is aiming with no input")
		assert(get_nodes_in_group(&"projectiles").is_empty(),
			"syringe fired without the player aiming")
		print("not aiming: %d shots" % get_nodes_in_group(&"projectiles").size())
		# Real input, not a poke at the flag: _aiming is recomputed from the input
		# every physics frame, so setting it by hand would last exactly one frame.
		Input.action_press(&"fire")
		return false

	if _stage == 2 and _elapsed > 2.0:
		_stage = 3
		var shots := get_nodes_in_group(&"projectiles").size()
		print("aiming: %d shots" % shots)
		assert(shots > 0, "syringe did not fire while aiming")
		return false

	if _stage == 3:
		_check_motion()
		_check_aim_compensation()
		print("OK: bob/squash/sway animate, aim is tilt-compensated, fire needs aim input.")
		return true

	return _elapsed > 30.0


func _check_motion() -> void:
	assert(_spread(_y_seen) > 0.2, "rig never bobbed (%.3f)" % _spread(_y_seen))
	assert(_spread(_rot_seen) > 0.005, "rig never swayed (%.4f)" % _spread(_rot_seen))
	assert(_spread(_scale_seen) > 0.0001, "rig never squashed (%.5f)" % _spread(_scale_seen))
	print("bob %.2fpx  sway %.3frad  squash %.4f" % [
		_spread(_y_seen), _spread(_rot_seen), _spread(_scale_seen)])


## The arm's LOCAL angle, pushed back out through the rig's transform, has to
## land on the world angle that was asked for -- at any tilt, mirrored or not.
func _check_aim_compensation() -> void:
	var rig := _player.get_node("Rig") as Node2D
	for tilt in [0.0, 0.09, -0.12]:
		rig.rotation = tilt
		for mirror in [1.0, -1.0]:
			_player._mirror = mirror
			for world in [0.0, 1.0, 2.5, -2.0]:
				var mount := 1.5708
				var local: float = _player._aim_rotation(world, mount)
				var rendered: float = tilt + local + mount if mirror > 0.0 \
					else tilt + PI - (local + mount)
				assert(is_zero_approx(angle_difference(rendered, world)),
					"tilt %.2f mirror %.0f: aimed %.3f, rendered %.3f" % [
						tilt, mirror, world, rendered])
	print("aim compensation exact across tilt and mirror")


func _spread(values: Array[float]) -> float:
	var lo := INF
	var hi := -INF
	for v in values:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	return hi - lo
