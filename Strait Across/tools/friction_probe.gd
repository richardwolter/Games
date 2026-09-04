## Drives the truck along a flat floor made of each material in turn and prints
## how far it got, so the grip spread can be read as numbers instead of argued
## about.
##
##   godot --headless --quit-after 4000 --script tools/friction_probe.gd
##
## Deliberately not a real strait: a level's gap, buoyancy and the shape of the
## pieces would all mix into the result. This is one flat floor whose only
## variable is its friction, which is the thing being tuned.
extends SceneTree

const CAR_SCENE := preload("res://scenes/car.tscn")
const DRIVE_SECONDS := 4.0
const FLOOR_LENGTH := 12000.0
const FLOOR_Y := 400.0


## Climb angle, in degrees. A bridge is rarely flat, and a slope is where grip
## stops being a speed difference and starts being pass/fail.
const SLOPE_DEGREES := 14.0


func _initialize() -> void:
	print("material          friction     flat  flat_top     climb")
	for path: String in _object_defs():
		var def: ObjectDef = load(path)
		var flat := await _run(def.friction, 0.0)
		var climb := await _run(def.friction, SLOPE_DEGREES)
		print("%-16s  %8.2f  %7.0f  %8.0f  %8.0f" % [
			def.display_name, def.friction, flat[0], flat[1], climb[0]
		])
	# The ground the truck launches from, for comparison.
	var shore_flat := await _run(1.0, 0.0)
	var shore_climb := await _run(1.0, SLOPE_DEGREES)
	print("%-16s  %8.2f  %7.0f  %8.0f  %8.0f" % [
		"(shore)", 1.0, shore_flat[0], shore_flat[1], shore_climb[0]
	])
	quit()


func _object_defs() -> PackedStringArray:
	var out := PackedStringArray()
	for file: String in DirAccess.get_files_at("res://data/objects"):
		if file.ends_with(".tres"):
			out.append("res://data/objects/" + file)
	return out


## One run: a floor of the given friction, the real truck, full throttle.
## Returns [distance, top_speed].
func _run(friction: float, slope_degrees: float) -> Array:
	var stage := Node2D.new()
	root.add_child(stage)

	var ground := StaticBody2D.new()
	ground.rotation = -deg_to_rad(slope_degrees)
	var pm := PhysicsMaterial.new()
	pm.friction = friction
	pm.bounce = 0.0
	ground.physics_material_override = pm
	ground.position = Vector2(0.0, FLOOR_Y + 200.0)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(FLOOR_LENGTH, 400.0)
	var cs := CollisionShape2D.new()
	cs.shape = rect
	ground.add_child(cs)
	stage.add_child(ground)

	# Put the truck on the top face wherever that face has ended up, so the drop
	# onto it is the same whatever the slope. Rotated with the ground rather than
	# left level, because a truck landing tilted bounces and the run is measuring
	# grip, not the first half-second of chassis wobble.
	var car: Car = CAR_SCENE.instantiate()
	var along := Vector2(-FLOOR_LENGTH * 0.4, -200.0 - Car.RIDE_HEIGHT)
	car.position = ground.position + along.rotated(ground.rotation)
	car.rotation = ground.rotation
	stage.add_child(car)

	# Let it settle onto its springs before the throttle opens, so the first
	# moments are not the chassis dropping.
	for i in 30:
		await physics_frame
	var start_x: float = car.chassis.global_position.x
	car.start()

	var top := 0.0
	var ticks := int(DRIVE_SECONDS * Engine.physics_ticks_per_second)
	for i in ticks:
		await physics_frame
		top = maxf(top, car.chassis.linear_velocity.x)
	var distance: float = car.chassis.global_position.x - start_x

	stage.queue_free()
	await physics_frame
	return [distance, top]
