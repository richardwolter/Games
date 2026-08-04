## Films a crossing attempt, so it can be watched again afterwards.
##
## Records transforms, not inputs. Re-simulating from a seed would be smaller and
## is the usual way to do this, but it needs the physics to land on the same
## answer twice — and this game's whole appeal is a pile of loosely stacked
## rigid bodies, which is exactly the arrangement where a solver's iteration
## order and a platform's floating point stop agreeing. A replay that diverges
## halfway through is worse than no replay, because the thing the player wants to
## show somebody is precisely the improbable bit.
##
## So every body's position and rotation is written down each tick and played
## back on inert copies. It cannot diverge, because there is nothing to diverge:
## it is a recording, not a simulation.
class_name AttemptRecorder
extends Node

## Samples per second. Physics runs at 120 on both desktop and web, so this
## stores every other tick and playback interpolates the gaps. At 60Hz a bridge
## folding is already smoother than the eye resolves, and it halves the memory.
const SAMPLE_HZ := 60.0

## Attempts are cut off by the stall timer long before this, and a crossing that
## somehow ran longer is one nobody wants to sit through anyway. Recording simply
## stops — the attempt itself is untouched.
const MAX_SECONDS := 30.0

## Floats stored per body per frame: x, y, rotation, and whether it still exists.
## A piece that tunnelled out of the world mid-attempt is gone from that frame
## on, and the replay has to be able to make it vanish at the same moment rather
## than leave it frozen where it was last seen.
const STRIDE := 4

## One entry per recorded body: {def, variant} for a bridge piece, or
## {car: true} for one of the truck's three bodies. Playback rebuilds the scene
## from this, so nothing about the live world needs to survive to watch it.
var cast: Array[Dictionary] = []
## One PackedFloat32Array per sample, cast.size() * STRIDE long.
var frames: Array[PackedFloat32Array] = []

var is_recording: bool = false

## Live bodies in cast order. Held as plain references and checked with
## is_instance_valid every sample: a piece can be removed mid-attempt, and a
## freed body is exactly the case the alive flag exists for.
var _bodies: Array[Node2D] = []
var _elapsed: float = 0.0
var _next_sample: float = 0.0


## Begin filming. `pieces` is the object container, `vehicle` the truck that has
## just been spawned onto the start line.
func start(pieces: Node, vehicle: Car) -> void:
	discard()
	is_recording = true

	for child: Node in pieces.get_children():
		var obj := child as BridgeObject
		if obj == null or obj.is_queued_for_deletion() or obj.def == null:
			continue
		cast.append({&"def": obj.def, &"variant": obj.variant})
		_bodies.append(obj)

	# The truck last, as three separate bodies. Its chassis is cast entry
	# `car_index()`, which is what the replay's camera follows.
	if is_instance_valid(vehicle):
		for body: Node2D in [vehicle.chassis, vehicle.get_node(^"WheelBack"),
				vehicle.get_node(^"WheelFront")]:
			cast.append({&"car": true})
			_bodies.append(body)

	# Frame zero, so a replay opens on the bridge as it stood rather than one
	# sample into the run.
	_sample()


## Where the truck's chassis sits in the cast, or -1 if the attempt had no truck.
## The last three entries are always chassis, back wheel, front wheel.
func car_index() -> int:
	var n := cast.size()
	if n < 3 or not bool(cast[n - 1].get(&"car", false)):
		return -1
	return n - 3


func stop() -> void:
	is_recording = false
	_bodies.clear()


func discard() -> void:
	is_recording = false
	cast.clear()
	frames.clear()
	_bodies.clear()
	_elapsed = 0.0
	_next_sample = 0.0


func has_recording() -> bool:
	return frames.size() > 1


func duration() -> float:
	return float(maxi(frames.size() - 1, 0)) / SAMPLE_HZ


func _physics_process(delta: float) -> void:
	if not is_recording:
		return
	_elapsed += delta
	if _elapsed >= MAX_SECONDS:
		stop()
		return
	# Accumulated against a target time rather than counting ticks, so the sample
	# rate is right whatever the physics rate happens to be — the web build has
	# already been on 60 once.
	if _elapsed < _next_sample:
		return
	_next_sample += 1.0 / SAMPLE_HZ
	_sample()


func _sample() -> void:
	var frame := PackedFloat32Array()
	frame.resize(_bodies.size() * STRIDE)
	for i in _bodies.size():
		var body := _bodies[i]
		var at := i * STRIDE
		if not is_instance_valid(body) or body.is_queued_for_deletion():
			frame[at + 3] = 0.0
			continue
		var pos := body.global_position
		frame[at] = pos.x
		frame[at + 1] = pos.y
		frame[at + 2] = body.global_rotation
		frame[at + 3] = 1.0
	frames.append(frame)
