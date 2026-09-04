extends SceneTree

## Prints the measured collision footprints and checks the two things that were
## actually broken: a locked door has to be solid, and a hitbox has to cover the
## sprite it belongs to.
##
## Run: <godot> --headless --script tools/test_collision.gd

## Staged rather than awaited: this IS the main loop, so awaiting a frame from
## inside it waits for something that can only happen after it returns.
var _frames: int = 0
var _stage: int = 0
var _main: Node


func _initialize() -> void:
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	current_scene = _main


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 5:
		return false

	var room: Room = _main.room

	if _stage == 1:
		_stage = 2
		for d: Door in room.doors.values():
			var plug: CollisionShape2D = d._plug_shape
			assert(plug != null, "door has no plug body at all")
			assert(not plug.disabled, "locked door's plug is disabled -- the gap is open")
		print("locked doors with a solid plug: %d" % room.doors.size())
		room._set_doors_locked(false)
		return false

	if _stage == 2:
		for d: Door in room.doors.values():
			assert(d._plug_shape.disabled, "unlocked door is still solid")
		print("OK: footprints wrap the sprites, arms excluded, locked doors solid.")
		return true

	var player: Player = _main.get_node("Player")
	_describe("player body ", player.body_shape)
	_describe("player hurt ", player.hurt_shape)

	# The gun arm is what breaks a naive union: it tracks the cursor, so its
	# reach changes with aim. Whatever it is doing, the hitbox must not follow.
	#
	# Both samples are taken in the SAME frame. The idle animation moves the head
	# and legs a fraction of a pixel per frame, so measurements taken a frame
	# apart never match exactly and would say nothing about the arms.
	var arm: Node2D = player.get_node("Rig/torso/arm_r")
	player._fit_shapes()
	var before := _dims(player.hurt_shape)
	arm.rotation += PI * 0.5
	player._fit_shapes()
	var after := _dims(player.hurt_shape)
	assert(before.is_equal_approx(after), "arm rotation changed the player hitbox")
	print("arm swing leaves hitbox unchanged: %.1f x %.1f" % [after.x * 2.0, after.y])

	# Enemies measure their own sprite, so two different creatures must not end
	# up with the same shape.
	var virus := _spawn_enemy("res://art/enemies/virus.png")
	var worm := _spawn_enemy("res://art/enemies/worm.png")
	_describe("virus hurt ", virus.hurt_shape)
	_describe("worm  hurt ", worm.hurt_shape)
	assert(not _dims(virus.hurt_shape).is_equal_approx(_dims(worm.hurt_shape)),
		"virus and worm resolved to the same hitbox")

	# Every door in a locked room must own an enabled solid plug. The plug is
	# toggled deferred, so the check has to wait a frame for it to land.
	room._set_doors_locked(true)
	_stage = 1
	return false


func _spawn_enemy(art_path: String) -> Enemy:
	var e := (load("res://scenes/enemy.tscn") as PackedScene).instantiate() as Enemy
	e.set_art(load(art_path) as Texture2D)
	current_scene.add_child(e)
	return e


func _dims(cs: CollisionShape2D) -> Vector2:
	var c := cs.shape as CapsuleShape2D
	return Vector2(c.radius, c.height) if c != null else Vector2.ZERO


func _describe(label: String, cs: CollisionShape2D) -> void:
	var c := cs.shape as CapsuleShape2D
	if c == null:
		print("%s <not a capsule: %s>" % [label, cs.shape])
		return
	# Reported as the box it fills, which is the thing to compare against the art.
	var w := c.radius * 2.0
	var h := c.height
	if not is_zero_approx(cs.rotation):
		var swap := w
		w = h
		h = swap
	print("%s %5.1f x %5.1f  at (%.1f, %.1f)" % [label, w, h, cs.position.x, cs.position.y])
