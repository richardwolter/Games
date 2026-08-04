## Plays an AttemptRecorder's recording back.
##
## Builds its own copies of everything that was on screen and drives them off the
## recorded transforms. The copies are inert — frozen, collisionless, out of the
## water's reach — so a replay cannot be pushed, cannot float, and cannot be
## caught by the object spawner's escape sweep. It is a puppet show, not a
## second physics world.
##
## The live strait is hidden for the duration rather than cleared. A replay is a
## thing you watch and then dismiss, and it must leave the bridge you built
## exactly as it was.
class_name ReplayPlayer
extends Node2D

signal finished()

const OBJECT_SCENE := preload("res://scenes/bridge_object.tscn")
const CAR_SCENE := preload("res://scenes/car.tscn")

var is_playing: bool = false
## Seconds into the recording.
var elapsed: float = 0.0

## The strait's water, so a replay can splash.
##
## The puppets have no collision layer — that is what keeps them out of the
## water's buoyancy list and out of the spawner's escape sweep — which also means
## the Area2D that normally reports an impact never sees them. So the replay
## watches its own puppets cross the waterline and asks for the splash directly.
## Without this a replay is the same footage with the water gone flat, and the
## moment the truck goes in is the moment that most needs it.
var water: WaterBody = null

var _recorder: AttemptRecorder
## One per cast entry, and each is the node whose transform that entry drives —
## for the truck that is the chassis body itself, not the Car wrapper around it.
## Wheel entries are null: they are children of the same scene and are written
## separately at the end of _apply().
var _puppets: Array[Node2D] = []
## The live nodes switched off while the replay runs, and put back after.
var _hidden: Array[Node2D] = []
var _car: Car = null


## `hide_while_playing` are the live containers — the bridge and the truck — that
## would otherwise be sitting behind the puppets showing the same objects in
## different places.
func play(recorder: AttemptRecorder, hide_while_playing: Array[Node2D]) -> void:
	if not recorder.has_recording():
		return
	stop()

	_recorder = recorder
	_hidden = hide_while_playing
	for node: Node2D in _hidden:
		if is_instance_valid(node):
			node.visible = false

	var car_at := recorder.car_index()
	for i in recorder.cast.size():
		var entry := recorder.cast[i]
		var puppet: Node2D
		if bool(entry.get(&"car", false)):
			# One truck, built on the chassis entry. The entry drives the chassis
			# body rather than the Car node wrapping it — the recording holds the
			# chassis's own global transform, and writing that onto the wrapper
			# would apply the chassis's local offset to it a second time.
			puppet = _build_car().chassis if i == car_at else null
		else:
			puppet = _build_piece(entry[&"def"] as ObjectDef, int(entry[&"variant"]))
		_puppets.append(puppet)

	# Seeded from frame zero, so the first _apply compares against where things
	# actually started rather than against the origin — which every piece already
	# below the waterline would read as a crossing, and the replay would open on a
	# row of splashes.
	_was_above.resize(recorder.cast.size())
	_last_chassis = Vector2.INF
	elapsed = 0.0
	is_playing = true
	_apply(0.0)
	_note_sides()


## The truck the replay's camera should follow, or null if the attempt had none.
func follow_target() -> Node2D:
	return _car.chassis if is_instance_valid(_car) else null


func stop() -> void:
	is_playing = false
	# Every puppet is a child of this node, so the whole cast goes at once. Freeing
	# _puppets entry by entry would miss the Car wrapper, whose entry is its
	# chassis rather than the scene root.
	for child: Node in get_children():
		child.queue_free()
	_puppets.clear()
	for node: Node2D in _hidden:
		if is_instance_valid(node):
			node.visible = true
	_hidden.clear()
	_car = null
	_recorder = null


func _build_piece(def: ObjectDef, variant: int) -> Node2D:
	var obj := OBJECT_SCENE.instantiate() as BridgeObject
	obj.setup(def, variant)
	_deaden(obj)
	add_child(obj)
	return obj


func _build_car() -> Car:
	var car := CAR_SCENE.instantiate() as Car
	add_child(car)
	# After add_child, so @onready has run and the wheels exist to be deadened.
	for child: Node in car.get_children():
		if child is PhysicsBody2D:
			_deaden(child as PhysicsBody2D)
	# The axles would fight the transforms being written onto the bodies every
	# frame, and a pin joint arguing with a puppeteer is a puppet that shakes.
	for child: Node in car.get_children():
		if child is PinJoint2D:
			(child as PinJoint2D).node_a = NodePath()
			(child as PinJoint2D).node_b = NodePath()
	car.set_physics_process(false)
	# The sprung bodywork and the driver are deliberately LEFT running. They
	# differentiate the chassis's linear_velocity, which on a frozen kinematic
	# body being teleported each frame is a derived number rather than a real
	# one — but measured against a live run it comes out with the same travel
	# (9.8 units against 8.8 over the same crossing), so the truck rides in a
	# replay the way it rode in the attempt. Switching them off left it dead
	# still, which is a worse likeness than an approximate one.

	# Dripping survives too, because it runs on _process and off positions rather
	# than velocities. A replay of a crossing where the truck ploughed through the
	# water should show the same water coming off it afterwards.
	car.water = water
	_car = car
	return car


## Everything that would make a body behave like a body. Layer and mask zero is
## the important one: the water is an Area2D and only ever sees what collides
## with it, so a puppet with no layer is never added to its buoyancy list.
##
## FREEZE_MODE_STATIC, emphatically not KINEMATIC. A kinematic frozen body is
## still a moving body as far as the server is concerned: it derives a velocity
## from the transform it is given and syncs its own answer back to the node once
## per physics tick. Puppets are written to once per *rendered* frame, so on any
## machine where the two rates disagree — which is most of them, and worse the
## higher the refresh rate — the node's transform is set by us and then partly
## overwritten by the server, over and over. That shows up as the truck's wheels
## buzzing for the whole replay while the recording behind them is perfectly
## smooth. A static frozen body is not integrated at all, so what we write is
## what gets drawn.
func _deaden(body: PhysicsBody2D) -> void:
	body.collision_layer = 0
	body.collision_mask = 0
	if body is RigidBody2D:
		var rb := body as RigidBody2D
		rb.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
		rb.freeze = true
		rb.gravity_scale = 0.0
		rb.linear_velocity = Vector2.ZERO
		rb.angular_velocity = 0.0
	body.remove_from_group(&"bridge_objects")


## Driven off _process rather than _physics_process: the recording is a fixed
## 60Hz timeline being resampled onto whatever the display is doing, and doing
## that on the render clock is what makes it smooth on a 144Hz monitor.
func _process(delta: float) -> void:
	if not is_playing:
		return
	elapsed += delta
	if elapsed >= _recorder.duration():
		_apply(_recorder.duration())
		is_playing = false
		finished.emit()
		return
	_apply(elapsed)
	_splash_crossings(delta)
	_feed_chassis_velocity(delta)


## Whether each cast member was above the waterline last frame. The crossing, not
## the position, is what makes a splash — a piece that spends the whole replay
## underwater must not splash every frame it is down there.
var _was_above := PackedByteArray()


func _note_sides() -> void:
	var line := water.surface_y if water != null else 0.0
	_last_y.resize(_puppets.size())
	for i in _puppets.size():
		var puppet := _puppets[i]
		var placed := is_instance_valid(puppet) and puppet.visible
		_was_above[i] = 1 if (placed and puppet.global_position.y < line) else 0
		_last_y[i] = puppet.global_position.y if placed else line


## Splash anything that has just gone through the surface since the last frame.
##
## Speed is taken from how far it moved this frame rather than from a velocity,
## because a puppet has none — it is being placed, not simulated. Same threshold
## and the same cooldown as the live game, so a replay throws the same water the
## attempt did.
func _splash_crossings(delta: float) -> void:
	if water == null or water.splash == null or delta <= 0.0:
		return
	var line := water.surface_y
	for i in _puppets.size():
		var puppet := _puppets[i]
		if not is_instance_valid(puppet) or not puppet.visible:
			_was_above[i] = 0
			continue
		var y := puppet.global_position.y
		var above := y < line
		var was := _was_above[i] == 1
		var moved := absf(y - _last_y[i])
		_was_above[i] = 1 if above else 0
		_last_y[i] = y
		if above == was:
			continue

		var piece := puppet as BridgeObject
		var width := WaterBody.NOMINAL_WIDTH
		if piece != null and piece.def != null:
			var facing := absf(cos(piece.global_rotation))
			width = lerpf(piece.def.get_height(), piece.def.size.x, facing)
		# `above` is where it ended up, so a puppet that is now above the line has
		# just left the water and is held to the higher bar.
		var speed := moved / delta
		if above:
			speed /= WaterBody.EXIT_SPEED_FACTOR
		water.splash.splash_for(puppet, speed, width)


## Where each puppet was last frame, for the speed a crossing was made at.
var _last_y := PackedFloat32Array()

## The puppet chassis's position last frame, for the velocity fed to the ride.
var _last_chassis := Vector2.INF


## Tell the truck's springs how fast it is going.
##
## The bodywork and the driver both heave off the chassis's ACCELERATION, which
## they get by differentiating linear_velocity. A statically frozen body has no
## velocity — the server never integrates it — so left alone the replayed truck
## rides like a brick, with the body welded rigid over the wheels while the
## recording underneath shows it crossing rough planks.
##
## So the velocity is written by hand, measured off the puppet's own motion. It
## is the same number the body would have had, arrived at by measuring rather
## than by simulating, and it costs one subtraction a frame.
func _feed_chassis_velocity(delta: float) -> void:
	if not is_instance_valid(_car) or delta <= 0.0:
		return
	var pos := _car.chassis.global_position
	if _last_chassis != Vector2.INF:
		_car.chassis.linear_velocity = (pos - _last_chassis) / delta
	_last_chassis = pos


func _apply(at: float) -> void:
	var frames := _recorder.frames
	var exact := at * AttemptRecorder.SAMPLE_HZ
	var a := clampi(int(exact), 0, frames.size() - 1)
	var b := mini(a + 1, frames.size() - 1)
	var t := clampf(exact - float(a), 0.0, 1.0)
	var first := frames[a]
	var second := frames[b]

	var stride := AttemptRecorder.STRIDE
	for i in _puppets.size():
		var puppet := _puppets[i]
		if not is_instance_valid(puppet):
			continue
		var k := i * stride
		# A body that has gone by either sample is gone: showing it for one last
		# interpolated frame would have it fade out of a position it never held.
		var alive := first[k + 3] > 0.5 and second[k + 3] > 0.5
		puppet.visible = alive
		if not alive:
			continue
		puppet.global_position = Vector2(
			lerpf(first[k], second[k], t), lerpf(first[k + 1], second[k + 1], t)
		)
		# lerp_angle, not lerpf: a piece spinning past PI would otherwise take the
		# long way round in a single frame, which reads as the object exploding.
		puppet.global_rotation = lerp_angle(first[k + 2], second[k + 2], t)

	# The wheels are cast entries in their own right, but they live inside the car
	# scene rather than as puppets of this node, so they are written here instead
	# of in the loop above.
	var car_at := _recorder.car_index()
	if car_at >= 0 and is_instance_valid(_car):
		var wheels: Array[Node] = [_car.get_node(^"WheelBack"), _car.get_node(^"WheelFront")]
		for w in wheels.size():
			var k := (car_at + 1 + w) * stride
			var wheel := wheels[w] as Node2D
			wheel.visible = first[k + 3] > 0.5
			wheel.global_position = Vector2(
				lerpf(first[k], second[k], t), lerpf(first[k + 1], second[k + 1], t)
			)
			wheel.global_rotation = lerp_angle(first[k + 2], second[k + 2], t)
