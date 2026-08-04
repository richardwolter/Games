## Builds BridgeObjects from ObjectDefs and drops them above the strait.
## Knows nothing about cost or inventory — Main decides whether a spawn is
## allowed and what happens to the def when a piece is removed.
extends Node

const OBJECT_SCENE := preload("res://scenes/bridge_object.tscn")

## Emitted for each placed object that gets removed, so it can be refunded.
signal object_removed(def: ObjectDef)

@export var spawn_position: Vector2 = Vector2(0, -200)
## Pieces appear inside this box, so a piece placed from the stock list can't
## arrive on the wrong side of a wall. Set per level via set_area().
var spawn_area: Rect2 = Rect2(-1500, -820, 3000, 1900)
## Safety net behind the world's walls. Anything that still escapes — usually by
## tunnelling at speed — is refunded to stock rather than silently lost.
var bounds: Rect2 = Rect2(-1800, -1100, 3600, 2600)
## Stops a very patient player from filling the strait until the physics chokes.
## Raised from 140 after benchmarking: at 60Hz physics (the web rate) a full
## strait settles at ~2.0ms per physics frame with ~200 live pieces, against a
## 16.6ms budget. The strait itself saturates before the cap does — spawning 400
## into the bench lattice leaves only ~190 in bounds — so this is headroom for
## bigger levels rather than a number players will routinely hit.
@export var max_objects: int = 250
## Where spawned objects are parented. Set in the scene.
@export var container_path: NodePath

var _container: Node2D


func _ready() -> void:
	_container = get_node(container_path) as Node2D


## variant picks which of the def's drawings the piece wears; -1 rolls a fresh
## one. Only restore() passes it, to put a bridge back as it looked.
func spawn(def: ObjectDef, at: Vector2 = Vector2.INF, variant: int = -1) -> BridgeObject:
	var obj := OBJECT_SCENE.instantiate() as BridgeObject
	obj.setup(def, variant)
	var drop := at
	if drop == Vector2.INF:
		drop = spawn_position + Vector2(randf_range(-80.0, 80.0), randf_range(-40.0, 0.0))
	obj.position = drop.clamp(spawn_area.position, spawn_area.end)
	_container.add_child(obj)
	return obj


## How many physics ticks between escape sweeps.
##
## The sweep walks every placed piece, so at the cap it was one global transform
## read and rectangle test per piece every tick — tens of thousands a second — to
## catch an event that happens rarely and is not time-critical. A piece that has
## left the world is not coming back; noticing 8 ticks later is invisible, and the
## walls do the actual containing.
const SWEEP_EVERY := 8

var _sweep_countdown: int = SWEEP_EVERY


## Speeds no legitimate piece ever reaches, used to catch a body the solver has
## thrown rather than one the player dropped hard. Release clamps a throw to
## 600 px/s and 6 rad/s, so these are more than an order of magnitude clear of
## anything the game itself produces.
const SANE_SPEED := 20000.0
const SANE_SPIN := 200.0


func _physics_process(_delta: float) -> void:
	_sweep_countdown -= 1
	if _sweep_countdown > 0:
		return
	_sweep_countdown = SWEEP_EVERY
	for child: Node in _container.get_children():
		var obj := child as BridgeObject
		if obj == null:
			continue
		# Out of the world: refunded. has_point() is false for a NaN position too,
		# which is the existing and correct catch for a piece the physics lost.
		if not bounds.has_point(obj.global_position):
			remove(obj)
			continue
		_sanitise(obj)


## Pull a piece back from a velocity it cannot have earned.
##
## Deliberately does NOT delete. A piece that briefly stops dead is a small
## oddity; a piece that vanishes out of the middle of a bridge the player spent
## ten minutes on is the game breaking. Deletion stays reserved for a piece that
## has actually left the world, which is unambiguous.
##
## The case this exists for is one body going non-finite and the solver spreading
## it: velocity is where that shows up first, a step or two before the position
## follows and the piece is lost for good.
func _sanitise(obj: BridgeObject) -> void:
	var v := obj.linear_velocity
	var spin := obj.angular_velocity
	var bad_v := not (is_finite(v.x) and is_finite(v.y)) or v.length() > SANE_SPEED
	var bad_spin := not is_finite(spin) or absf(spin) > SANE_SPIN
	if not (bad_v or bad_spin):
		return
	obj.linear_velocity = Vector2.ZERO
	obj.angular_velocity = 0.0
	# Not push_error: this is a recovery, not a failure, and it must not spam a
	# release build's console every sweep if something is genuinely stuck.
	push_warning("Piece had an impossible velocity (%s, %.1f); zeroed it" % [str(v), spin])


## Levels differ in width, so where a piece may exist changes with them.
func set_area(build_area: Rect2, escape_bounds: Rect2) -> void:
	spawn_area = build_area
	bounds = escape_bounds
	spawn_position = Vector2(build_area.get_center().x, build_area.position.y + 200.0)


func is_full() -> bool:
	return count() >= max_objects


func remove(obj: BridgeObject) -> void:
	# is_instance_valid() alone isn't enough: freeing is deferred, so a piece
	# removed earlier this frame is still a valid, still-parented child, and a
	# second pass over the container would refund it twice. Loading a saved layout
	# does exactly that — it recalls everything and then rebuilds in one frame.
	if not is_instance_valid(obj) or obj.is_queued_for_deletion():
		return
	object_removed.emit(obj.def)
	obj.queue_free()


## Recall every placed piece to stock, so the player can rebuild from scratch
## without having to re-buy.
func clear_all() -> void:
	for child: Node in _container.get_children():
		remove(child as BridgeObject)


## How many of one kind of piece are currently in the strait.
##
## The whole table at once rather than a query per def: the belt asks about every
## piece it shows, several times a second, and doing that as one walk of the
## container is one pass instead of a pass per card.
func placed_counts() -> Dictionary[ObjectDef, int]:
	var out: Dictionary[ObjectDef, int] = {}
	for child: Node in _container.get_children():
		var obj := child as BridgeObject
		if obj == null or obj.def == null or obj.is_queued_for_deletion():
			continue
		out[obj.def] = out.get(obj.def, 0) + 1
	return out


## Recall just one kind of piece, leaving the rest of the bridge standing.
##
## The counterpart to Recall All, for the far commoner case: the span is roughly
## right and one material is in the wrong place. Recalling everything to fix that
## costs the whole arrangement, so players were dragging pieces out one at a time
## instead — which is the same operation, done slowly.
##
## Returns how many came back, so the caller can report it.
func remove_all_of(def: ObjectDef) -> int:
	var recalled := 0
	for child: Node in _container.get_children():
		var obj := child as BridgeObject
		if obj != null and obj.def == def and not obj.is_queued_for_deletion():
			remove(obj)
			recalled += 1
	return recalled


## Empty the strait without refunding anything — used when a level ends, where
## the pieces are being thrown away along with the level's inventory.
func discard_all() -> void:
	for child: Node in _container.get_children():
		child.free()


## Records where every placed piece is sitting, so a crossing attempt can be
## undone. Just def + transform: the bridge is only interesting at rest, so
## velocities aren't worth keeping.
func snapshot() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for child: Node in _container.get_children():
		var obj := child as BridgeObject
		# Freeing is deferred, so a piece removed earlier this frame is still a
		# child. Snapshotting it would put it back on the next restore *and* leave
		# the refund it already earned in stock — one piece becoming two.
		if obj != null and not obj.is_queued_for_deletion():
			out.append({
				&"def": obj.def,
				&"position": obj.global_position,
				&"rotation": obj.global_rotation,
				&"variant": obj.variant,
			})
	return out


## Puts the bridge back exactly as snapshot() found it. Nothing is refunded and
## nothing is charged — the pieces never left the player's bridge, conceptually.
func restore(snap: Array[Dictionary]) -> void:
	for child: Node in _container.get_children():
		child.queue_free()
	# Freeing is deferred, so the old bodies are still parented this frame.
	# Detach them now or the restored pieces spawn inside their collision shapes.
	for child: Node in _container.get_children():
		_container.remove_child(child)

	for entry: Dictionary in snap:
		var obj := spawn(
			entry[&"def"] as ObjectDef,
			entry[&"position"] as Vector2,
			entry[&"variant"] as int
		)
		obj.rotation = entry[&"rotation"] as float
		obj.linear_velocity = Vector2.ZERO
		obj.angular_velocity = 0.0


## Pieces actually in the strait.
##
## Not get_child_count(): freeing is deferred, so anything removed earlier this
## frame is still parented, and the raw count would disagree with
## placed_counts() for the rest of the frame. That gap is what the belt reads
## while recalling a material — it would show the pieces as gone from the badge
## and still present in the "N pieces placed" line at the same moment.
func count() -> int:
	var n := 0
	for child: Node in _container.get_children():
		if not child.is_queued_for_deletion():
			n += 1
	return n
