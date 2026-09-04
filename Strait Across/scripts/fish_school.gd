## Fish in the strait.
##
## They have no collision and nothing in the game can see them; they swim in
## front of everything, pieces included. That is a deliberate cheat rather than
## an oversight — putting them behind the bridge would hide them completely the
## moment the player builds anything, and giving them collision would make them
## part of the puzzle, which is the last thing a decoration should be.
##
## What keeps them from looking pasted on is that they react anyway: a fish gives
## a wide berth to anything the player has dropped in the water, and bolts if it
## finds itself right next to one. So a crate landing in the strait scatters the
## fish around it even though the crate never touches them.
class_name FishSchool
extends Node2D

const ART_DIR := "res://art/wildlife/"
const SPRITES: Array[String] = ["fish_1", "fish_2", "fish_3", "fish_4"]
## Which of those drawings face LEFT on the sheet.
##
## Three of the four are drawn nose-right and one is not, and the flip was done
## against a blanket "the sprites face right" — so every carp in the game swam
## backwards. Recorded per drawing rather than fixed in the .png so the art stays
## as it was delivered; adding a new fish means adding it here if it faces left.
const FACES_LEFT: Array[String] = ["fish_4"]

## Fish per 1000 world units of strait. Sparse on purpose — this is a strait with
## some fish in it, not an aquarium.
@export var density: float = 1.6
@export var max_fish: int = 14
## Body length on screen, in world units. A plank is 260 or so, so these read as
## fish rather than as another thing that might hold a car up.
@export var min_length: float = 46.0
@export var max_length: float = 92.0
@export var min_speed: float = 34.0
@export var max_speed: float = 78.0

## How close a piece has to be before a fish starts avoiding it, and how hard it
## is pushed away. The radius is generous: a fish that only swerves once it is
## touching a girder looks oblivious, not shy.
@export var fear_radius: float = 320.0
@export var fear_force: float = 900.0
## Multiplier on a fish's top speed while it is fleeing something.
@export var bolt_speed: float = 2.1

## Clearance kept from the waterline and from the rock. The bed margin is now
## measured from an envelope that already leans high, and it is still generous:
## a fish grazing the rock reads as a bug even when it is technically clear.
const SURFACE_MARGIN := 70.0
const BED_MARGIN := 80.0
## A fish will not be placed in a gap shallower than this.
##
## Nothing was stopping one from spawning in the sliver of water over a shelf,
## where the band between the surface margin and the rock is a few units tall
## and the fish sits pinned to the bottom of it looking beached.
const MIN_BAND := 150.0
## Tail beats per second at cruising speed.
const WAG_HZ := 2.4


class Fish:
	var sprite: Sprite2D
	var velocity: Vector2
	var speed: float
	var phase: float
	var length: float
	## Rises and falls slowly around this, so a school doesn't sit in a flat line.
	var drift: float
	var alarm: float = 0.0
	## True when this fish's drawing is nose-left, so the mirror has to be inverted.
	var art_faces_left: bool = false


var _fish: Array[Fish] = []
var _half_width: float = 0.0
var _surface_y: float = 0.0
## Seabed height sampled on a fixed grid, so the floor under a fish is a lookup
## rather than a walk along the polyline every frame.
var _floor: PackedFloat32Array = PackedFloat32Array()
var _floor_step: float = 1.0


func _ready() -> void:
	# Fish are swum from _process, not from physics. Physics interpolation would
	# smooth them between transforms they never had, which shows up as a lag and
	# a wobble on exactly the thing that is supposed to look effortless.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


## `bed` is the seabed polyline the world just generated, same one the flora is
## planted along.
func populate(
	bed: PackedVector2Array, surface_y: float, half_width: float, school_seed: int
) -> void:
	for fish: Fish in _fish:
		fish.sprite.queue_free()
	_fish.clear()
	_surface_y = surface_y
	_half_width = half_width
	_sample_floor(bed)
	if bed.size() < 2 or half_width <= 0.0:
		return

	# Each entry is [texture, faces_left], kept together so a fish can't be given
	# one drawing's picture and another's facing.
	var textures: Array[Array] = []
	for name: String in SPRITES:
		var texture := load(ART_DIR + name + ".png") as Texture2D
		if texture != null:
			textures.append([texture, FACES_LEFT.has(name)])
	if textures.is_empty():
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = school_seed
	var count: int = clampi(
		int(half_width * 2.0 / 1000.0 * density), 3, max_fish
	)
	for i in count:
		var fish := _spawn(textures, rng)
		if fish != null:
			_fish.append(fish)


## The seabed as a height-per-column table.
##
## Two things matter here, and the first version got both wrong, which is why
## fish ended up sitting in the rock.
##
## It samples FINER than the seabed's own vertices (the bed is built every 40
## units and carries a second, much finer noise pass on top), because sampling
## coarser than the thing you are measuring means reading the height between two
## ridges and never seeing either.
##
## And each cell then takes the HIGHEST rock in its neighbourhood, not the height
## at its own x. A fish is a sprite tens of units wide sitting at one position,
## so what has to clear the rock is the whole fish, and the table has to err
## towards "the rock is higher than you think" everywhere. Erring the other way
## is invisible — a fish swimming slightly too high over a trough — while erring
## this way buries it.
func _sample_floor(bed: PackedVector2Array) -> void:
	_floor = PackedFloat32Array()
	if bed.size() < 2:
		return
	_floor_step = 16.0
	var columns: int = int((bed[bed.size() - 1].x - bed[0].x) / _floor_step) + 2
	var raw := PackedFloat32Array()
	raw.resize(maxi(columns, 2))
	var at := 0
	for i in raw.size():
		var x: float = bed[0].x + float(i) * _floor_step
		while at < bed.size() - 2 and bed[at + 1].x < x:
			at += 1
		var a := bed[at]
		var b := bed[at + 1]
		var span: float = maxf(b.x - a.x, 0.001)
		raw[i] = lerpf(a.y, b.y, clampf((x - a.x) / span, 0.0, 1.0))

	# Smaller y is higher up, so the highest rock nearby is the minimum.
	_floor.resize(raw.size())
	var reach: int = maxi(int(max_length / _floor_step), 2)
	for i in raw.size():
		var highest: float = raw[i]
		for j in range(maxi(i - reach, 0), mini(i + reach + 1, raw.size())):
			highest = minf(highest, raw[j])
		_floor[i] = highest


func _floor_at(x: float) -> float:
	if _floor.is_empty():
		return _surface_y + 600.0
	var i: int = clampi(
		int((x + _half_width) / _floor_step), 0, _floor.size() - 1
	)
	return _floor[i]


func _spawn(textures: Array[Array], rng: RandomNumberGenerator) -> Fish:
	var fish := Fish.new()
	var sprite := Sprite2D.new()
	var drawing: Array = textures[rng.randi() % textures.size()]
	var texture := drawing[0] as Texture2D
	fish.art_faces_left = drawing[1] as bool
	sprite.texture = texture

	fish.length = rng.randf_range(min_length, max_length)
	var factor: float = fish.length / maxf(float(texture.get_width()), 1.0)
	sprite.scale = Vector2(factor, factor)
	# Down here everything is seen through the water overlay; knocking the alpha
	# back a little more puts them IN the water rather than on top of it, which
	# matters because they are drawn over every other underwater thing.
	sprite.modulate = Color(1, 1, 1, 0.92)

	fish.speed = rng.randf_range(min_speed, max_speed)
	fish.phase = rng.randf() * TAU
	var heading: float = -1.0 if rng.randf() < 0.5 else 1.0
	fish.velocity = Vector2(heading * fish.speed, 0.0)

	# Several attempts before giving up: most of the strait is deep enough, but
	# a single unlucky roll used to land on the shelf and the fish was simply
	# placed there anyway.
	var top: float = _surface_y + SURFACE_MARGIN
	var placed := Vector2.INF
	for attempt in 12:
		var x: float = rng.randf_range(-_half_width * 0.85, _half_width * 0.85)
		var bottom: float = _floor_at(x) - BED_MARGIN
		if bottom - top < MIN_BAND:
			continue
		placed = Vector2(x, rng.randf_range(top, bottom))
		break
	if placed == Vector2.INF:
		return null
	sprite.position = placed
	fish.drift = rng.randf_range(0.15, 0.85)
	add_child(sprite)
	fish.sprite = sprite
	return fish


## Piece positions, so the inner loop is arithmetic on a packed array instead of
## a node cast and a global_position lookup per fish per piece.
var _piece_positions: PackedVector2Array = PackedVector2Array()
## How often that list is rebuilt. See _process().
const PIECE_REFRESH_HZ := 10.0
var _piece_refresh: float = 0.0


func _process(delta: float) -> void:
	if _fish.is_empty():
		return

	# Gathered once a frame rather than once per fish. With a full strait that is
	# fourteen group queries and two thousand transform reads a frame turned into
	# one query and a flat array walk.
	#
	# And now not even once a frame. The group query allocates an Array of up to
	# 140 nodes and each entry costs a cast and a global transform, all to feed a
	# soft steering push away from scenery. Refreshed at PIECE_REFRESH_HZ instead:
	# a position that is at most a tenth of a second stale cannot be seen in a
	# fish's swimming, and this is the most expensive decorative loop in the game.
	_piece_refresh -= delta
	if _piece_refresh <= 0.0:
		_piece_refresh = 1.0 / PIECE_REFRESH_HZ
		_piece_positions.clear()
		for piece: Node in get_tree().get_nodes_in_group(&"bridge_objects"):
			var body := piece as Node2D
			if body != null:
				_piece_positions.append(body.global_position)

	var t := float(Time.get_ticks_msec()) / 1000.0
	for fish: Fish in _fish:
		_swim(fish, t, delta)


func _swim(fish: Fish, t: float, delta: float) -> void:
	var sprite := fish.sprite
	var at := sprite.position

	# Everything a fish wants to do is a push on its velocity, summed. Steering
	# rather than pathing: there is nothing to path around that will still be in
	# the same place in two seconds.
	var steer := Vector2.ZERO
	var nearest := INF

	var fear_squared := fear_radius * fear_radius
	for piece_at: Vector2 in _piece_positions:
		var away: Vector2 = at - piece_at
		# Two compares before any arithmetic. This is the innermost loop in the
		# game — fish times pieces, every frame — and in a full strait almost every
		# pair is far apart on one axis alone. Rejecting on x before computing a
		# length skips the multiplies for the overwhelming majority.
		if absf(away.x) > fear_radius or absf(away.y) > fear_radius:
			continue
		# Squared next: the square root is the expensive part and most pieces in a
		# full strait are nowhere near this fish.
		var squared: float = away.length_squared()
		if squared > fear_squared or squared < 0.000001:
			continue
		var distance: float = sqrt(squared)
		nearest = minf(nearest, distance)
		# Falls off with the square: a piece across the strait is ignored, a
		# piece alongside is the only thing that matters.
		var strength: float = fear_force * pow(1.0 - distance / fear_radius, 2.0)
		steer += away / distance * strength

	# Alarm decays on its own, so a fish keeps bolting for a moment after it is
	# clear rather than resuming its cruise the instant it stops being crowded.
	if nearest < fear_radius:
		fish.alarm = 1.0
	else:
		fish.alarm = maxf(fish.alarm - delta * 0.8, 0.0)

	# Hold the depth band. Both of these ramp up as the fish nears the boundary
	# rather than switching on at it, so nothing ever visibly bounces.
	var top: float = _surface_y + SURFACE_MARGIN
	var bottom: float = _floor_at(at.x) - BED_MARGIN
	if bottom <= top:
		# Over a shelf: there is no band to hold. Head for deeper water rather
		# than for a depth that doesn't exist here. Previously this case fell
		# through and did nothing, so a fish that wandered onto the shallows kept
		# its heading and swam straight into the rock.
		steer.y -= 260.0
		steer.x -= signf(at.x) * 420.0
	else:
		if at.y < top:
			steer.y += (top - at.y) * 6.0
		elif at.y > bottom:
			steer.y -= (at.y - bottom) * 6.0
		else:
			# A slow wander up and down the band it is in, so an undisturbed
			# school still drifts instead of running on rails.
			var wanted: float = lerpf(top, bottom, fish.drift)
			steer.y += (wanted - at.y) * 0.35
			fish.drift = clampf(
				fish.drift + sin(t * 0.21 + fish.phase) * delta * 0.09, 0.06, 0.94
			)

	# Turn back before the shore rather than at it.
	var edge: float = _half_width - 120.0
	if absf(at.x) > edge:
		steer.x -= signf(at.x) * (absf(at.x) - edge) * 5.0

	fish.velocity = fish.velocity.lerp(fish.velocity + steer, clampf(delta * 3.0, 0.0, 1.0))
	var top_speed: float = fish.speed * lerpf(1.0, bolt_speed, fish.alarm)
	if fish.velocity.length() > top_speed:
		fish.velocity = fish.velocity.normalized() * top_speed
	elif fish.velocity.length() < fish.speed * 0.35:
		# Never quite stops: a fish hanging motionless mid-water is the one pose
		# that reads as a dead sprite.
		fish.velocity = (fish.velocity + Vector2(signf(fish.velocity.x) * 20.0, 0.0))

	sprite.position += fish.velocity * delta

	# Hard stop on top of the steering. Steering is a force and a force can be
	# outrun — a startled fish at bolt speed covers 160 units in a second and can
	# cross the margin before the push has turned it. Being briefly held against
	# an invisible ceiling is not noticeable; being inside a rock is.
	# Sideways first, because the floor lookup below reads the height at whatever
	# x the fish ended up at, and an x outside the table is clamped to the edge
	# column — so a fish that had crossed the shore would be held against the
	# depth of the last sampled column rather than of the rock it is actually in.
	var edge_stop: float = _half_width - 40.0
	if absf(sprite.position.x) > edge_stop:
		sprite.position.x = signf(sprite.position.x) * edge_stop
		# Turn it round rather than pinning it: a fish held flat against the shore
		# with its tail still beating is more obviously stuck than one that leaves.
		fish.velocity.x = -signf(sprite.position.x) * absf(fish.velocity.x)

	var floor_y: float = _floor_at(sprite.position.x) - BED_MARGIN
	if sprite.position.y > floor_y:
		sprite.position.y = floor_y
		fish.velocity.y = minf(fish.velocity.y, 0.0)
	if sprite.position.y < _surface_y + SURFACE_MARGIN:
		sprite.position.y = _surface_y + SURFACE_MARGIN
		fish.velocity.y = maxf(fish.velocity.y, 0.0)

	# Mirror rather than rotate through 180, or the fish swims home upside down.
	# The mirror is relative to which way its own drawing faces, not to a blanket
	# assumption about the sheet.
	var heading_left: bool = fish.velocity.x < 0.0
	sprite.flip_h = heading_left != fish.art_faces_left
	# A shallow pitch towards where it is going, capped well short of vertical —
	# these are not dolphins.
	var pitch: float = clampf(fish.velocity.y / maxf(absf(fish.velocity.x), 1.0), -1.0, 1.0)
	var facing: float = -1.0 if heading_left else 1.0
	sprite.rotation = lerp_angle(sprite.rotation, pitch * 0.45 * facing, clampf(delta * 4.0, 0.0, 1.0))

	# Tail beat: a horizontal squeeze, faster when startled. Same trick as the
	# birds' wings, and for the same reason — one drawing, no frames.
	var beat: float = t * WAG_HZ * TAU * lerpf(1.0, 2.0, fish.alarm) + fish.phase
	var base: float = absf(sprite.scale.y)
	sprite.scale.x = base * (1.0 - 0.10 * (0.5 + 0.5 * sin(beat)))
