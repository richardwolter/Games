## The ferry: the second half of the loop, and the only thing that turns a full yard into
## money.
##
## Not a physics body and not steered. The angler owns the walk keys, and two things cannot
## own the same keys — so the boat runs itself. It loads whatever is in the island's yard
## and then does a round of the lake: four merchants sit on the bank, each buying one
## material, and the boat calls at every one it is carrying something for before coming
## home for the next load.
##
## The route is the interesting part. A hold of nothing but bottles is one stop and back;
## a hold with a bit of everything is a lap. And because each leg has a destination that
## wants one particular material, the skimmer knows what to look for on the way — it fishes
## for timber while it is running timber to the sawmill, which is what makes a laden ferry
## worth watching rather than a delivery animation.
##
## Legs are planned around the island rather than straight through it: a chord from the
## east yard to the west one would drive the hull over the shed.
class_name Boat
extends Node2D

## Emitted at a yard with everything that was landed there. The lake pays for it; the boat
## does not know what a sludge is.
signal sold(cargo: PackedInt32Array, kind: int)

## One piece the skimmer took out of the water on the way past. Reported as it happens,
## because that is the moment it left the lake — selling it later is a separate event.
signal skimmed(def_index: int)

enum State { DOCKED, LOADING, SAILING, UNLOADING, RETURNING, PATROL }

## Where an unled patrol wanders: how far out in the basin one leg may end, as a fraction
## of the way to the shore, and how far round the lake it may go. Ranges rather than
## numbers, because a hull that walks the same ring at the same rate is a clock, and the
## water it is not on is always the same water.
const PATROL_INSET := Vector2(0.30, 0.85)
const PATROL_STEP := Vector2(0.5, 2.2)

## How far the point a hull has been sent to has to move before it turns for the new one, in
## tiles. Without it a boat chasing something that is itself moving spends every frame
## replanning and never commits to a heading.
const PATROL_REPLAN := 2.5

## Matches the swell in lake_grid.gd and the surface motion in the shader.
const WAVE_AMPLITUDE := 5.0
const WAVE_SPEED := 1.0

## How high the hull rides above the tile it is over.
const RIDE_HEIGHT := 7.0

## The wake, in stern-lengths and hull-widths: how far back it reaches, how wide it opens,
## how many ripples are in it and how fast they shed backwards down it.
const WAKE_LONG := 2.2
const WAKE_WIDE := 0.68
const WAKE_RIPPLES := 7
const WAKE_SPEED_OFF := 0.55

## How many slabs the disturbed water behind the hull is built from.
##
## One flat polygon was a cone: a hard-edged triangle of pale grey laid on the lake, with a
## visible line down each side where it stopped being water. Stacking shorter, wider, fainter
## slabs gives the same shape an edge that runs out instead of ending, which is what lets it
## sit in the surface rather than on it.
const WAKE_LAYERS := 4

## How far a ripple's ends may wander from where an even, symmetrical one would put them, as
## a fraction of its own width, and how much its width and its speed may vary from its
## neighbours'. A wake is water falling off a hull, and water does not queue.
const WAKE_WANDER := 0.34
const WAKE_VARY := 0.3

## How far each ripple bows back towards the stern across its own span, as a fraction of its
## width. A wake ripple is an arc trailing from the hull, not a chevron: the straight-line
## vee read as a machined part, and two of them one behind the other read as a chevron
## pattern rather than as water.
const WAKE_BOW := 0.42

## The skimmer's mouth, as a fraction of the hull's beam at radius zero and per level after
## it, and how far back off the hull it hangs. Small and tucked in: it is a net on a frame
## bolted to the transom, not a trawl.
const SKIM_MOUTH := 0.42
const SKIM_MOUTH_STEP := 0.11
const SKIM_BEHIND := 0.62

## How far behind the boat the skimmer's mouth sits, in tiles. The same offset the net is
## drawn at, converted out of hull lengths — the sweep has to happen where the net is, not
## where the wheelhouse is.
const SKIM_TRAIL := HULL_LENGTH * 0.5 * SKIM_BEHIND / TILE_REACH

## How often a boat under way throws spray off its bow, in seconds, and how big. Small: it is
## a work boat at walking pace, not a speedboat.
## Seconds between the rings a hull leaves in the water under way. Slower than the net's:
## the boat is bigger, its rings are wider, and packed any tighter they merge into a band.
const HULL_RIPPLE := 0.22

const BOW_SPRAY := 0.34
const BOW_SPRAY_SIZE := 0.22

## Bigger than anything it collects, and no bigger. At a bit over two tiles long it reads
## as the machine that eats the lake without the lake stopping being the thing on screen.
const HULL_LENGTH := 138.0
const HULL_WIDTH := 57.0

## How tall the drawn hull stands above the water, for the things that sit on it: the load
## in the hold and the pennant above it.
const HULL_HEIGHT := 16.0

## The open hold, as a fraction of the hull: where along it the cargo deck starts and ends,
## and how far across it reaches. Taken off the model — the cabin sits over the stern and
## the bow is decked in, so the load goes in the middle and slightly forward.
const HOLD_FROM := 0.02
const HOLD_TO := 0.33
const HOLD_ACROSS := 0.30

## How many pieces are drawn in the hold, and how big. A hold packed with forty things is
## a smear; six is enough to read as laden.
const HOLD_SHOWN := 6
const HOLD_SCALE := 0.55

## How many screen pixels one tile of travel covers, for laying things out on the deck in
## tiles rather than in pixels.
const TILE_REACH := 35.777

## The baked headings, and how much of one frame the hull actually covers — the bake leaves
## room around it for the diagonals, and the load and the wake are placed against the hull
## rather than against the frame.
const FRAMES_PATH := "res://assets/boat_frames.png"
const HULL_IN_FRAME := 104.0

static var _sheet_cache: Texture2D
static var _sheet_missing: bool = false

## How close to the end of a leg counts as arrived, in tiles.
const ARRIVE_DISTANCE := 0.25

## Seconds spent alongside at each end. Long enough to read as loading and unloading rather
## than as a boat teleporting through its own destination.
const DWELL := 0.7

## How far out the ferry roams when it has to go round something, as a fraction of the
## shore radius. Inside the waterline, outside everything else.
const RING := 0.84

## How far clear of the island a leg has to stay, in island_fraction. 1.0 is the beach.
##
## All three of these are multiples of the island's radius, so growing the island grew the
## room the ferry left round it by the same factor — and a bend that swings wide of a bigger
## island is a longer trip for the same crossing. Pulled back in (from 1.7 / 2.6 / 2.15) so
## the ferry keeps about the same distance in tiles off the beach as it did before.
const ISLAND_CLEAR := 1.25

## How far out a bend round the island swings, and how far out the dock is approached from,
## in the same units. Both are comfortably outside ISLAND_CLEAR: a waypoint sitting exactly
## on the limit makes the chords either side of it dip below the limit, and the leg gets
## split again for no gain.
const ISLAND_BEND := 1.72
const ISLAND_BERTH := 1.44

## How often a moving skimmer gets a go at the water, in tiles travelled. Rolling once per
## frame would make the catch rate depend on the frame rate, which is the kind of bug that
## only shows up on someone else's machine.
const SKIM_STEP := 0.6

## Set from the lake's upgrade levels when a run starts. Speed is in tiles per second.
var speed: float = 4.2
var capacity: int = 6
## Tiles out from the hull the skimmer bites. Below zero is a boat with no skimmer fitted,
## which is what every ferry starts as.
var skim_radius: int = -1
## The heaviest tier the skimmer can lift.
var skim_power: int = 0

## How many slots down the skimmer will dig for the material it is after.
##
## It has to be more than one. A skimmer looking only at the top of each stack is hunting
## for a particular material among whatever happens to be floating, and on a run to the
## sawmill most of what is on top is not timber — a whole lap would bring up one plank.
## Digging a little is what makes a filtered skimmer worth fitting at all.
var skim_depth: int = 1
## Odds that any one piece the skimmer passes over actually comes up, 0 to 1. A net dragged
## behind a moving hull is a chance at a piece, not a guarantee — and turning that chance
## up is what the skimmer upgrade mostly buys.
var skim_chance: float = 0.0

## Room the skimmer gets over and above the hold, in pieces.
##
## Without this the skimmer would be dead weight exactly when the player was doing well:
## the ferry loads the hold full from the yard, and a full hold has nowhere to put anything
## it fishes up. The deck space is the skimmer's own, so a laden ferry still works the water
## it crosses.
var skim_hold: int = 0

## Whether it sets off on its own as soon as there is something to carry.
var auto_ferry: bool = true

## Set while the boat has nothing to ferry and should be out on the water anyway.
##
## The siege turns this on. There is no rubbish in that lake and so nothing to carry, and a
## fleet moored all afternoon behind a fight is three boats pretending to be scenery — but
## the guns ammo loads are on these hulls, so where they are is the whole of what they are
## worth. A patrolling boat circles the island and takes its gun with it.
var patrol: bool = false

## Where the patrol has been told to go, in tiles, or INF for "your own business".
##
## The boat does not know what a monster is and should not: it is a hull with a gun on it
## and a lake to cross. Something that does know — the siege — points it at water worth
## being on, and moves the point as the fight moves. With nothing pointing it anywhere it
## wanders the basin on its own.
var patrol_at := Vector2.INF

## The point the current leg was planned for, so a target that has drifted can be told from
## one that has not.
var _patrol_aim := Vector2.INF

var state: int = State.DOCKED
## What is aboard, as def indices.
var cargo := PackedInt32Array()

## Where it sits, in tile coordinates, and where it comes home to.
var tile_pos := Vector2.ZERO
var dock := Vector2(Iso.CENTRE.x, Iso.CENTRE.y)

## Which way it is pointing on the plane, for the wake and the hull's lean.
var heading := Vector2(1.0, 0.0)

## Wired up by lake.gd. The boat loads straight out of the yard and skims straight out of
## the grid, for the same reason the net does: it is the thing doing the work.
var yard: Yard
var grid: LakeGrid
var splash: WaterSplash
## The noises. Optional — a boat with no sound board still ferries.
var sfx: Sfx
## Where cargo is thrown from the yard. Optional — with no haul the load simply appears
## aboard the way it used to.
var haul: Haul

## The net the skimmer drags, borrowed off the angler's own sheet. Empty means no art, and
## the skimmer falls back to the shape it was blocked in as.
var skim_sheet: Texture2D
var skim_frame := {}
## The four merchants, in TrashDef.Kind order.
var dropoffs: Array[Dropoff] = []

var runs_done: int = 0

## Which seed this hull's skimmer rolls from. Every ferry in the fleet has to roll its own
## dice, or two boats on the same leg bring up the same pieces in the same order.
var rng_seed: int = 771144

## Which dropoff it is sailing to, as an index into `dropoffs`; -1 when heading home.
var target: int = -1

## The stops still to make this run, and the waypoints of the current leg.
var _route: Array[int] = []
var _legs: Array[Vector2] = []

var _time: float = 0.0
## Counts down to the next puff of spray off the bow.
var _spray_in: float = 0.0
var _dwell: float = 0.0

## What the last painted hull was made of, while it is sitting still. See `_repaint`.
var _painted: int = 0
var _skim_travel: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Seeded, like the lake itself: a run that can be replayed is a run that can be tuned.
	_rng.seed = rng_seed
	tile_pos = dock
	_place()


func is_running() -> bool:
	return state != State.DOCKED


## Where it is on its run, for the HUD. One line rather than five branches at the call site.
func status_line() -> String:
	match state:
		State.LOADING:
			return "loading"
		State.SAILING:
			return "running %s out" % _target_name()
		State.UNLOADING:
			return "unloading at the %s yard" % _target_name()
		State.RETURNING:
			return "coming home"
		_:
			return "docked"


func _target_name() -> String:
	if target < 0 or target >= dropoffs.size():
		return "cargo"
	return dropoffs[target].kind_name().to_lower()


## Send it out now, if there is anything to send it with. Called by the auto-ferry check
## and by the shop's button, so "go now" and "go by itself" are one path.
func dispatch() -> bool:
	if state != State.DOCKED or yard == null or yard.held.is_empty():
		return false
	var lot := yard.take_lot(capacity)
	state = State.LOADING
	if haul == null:
		cargo = lot
		_dwell = DWELL
		return true
	# Thrown aboard rather than conjured into the hold, one piece at a time and into the
	# stowage spot it will sit in. The berth is held until the last one lands: a boat that
	# sails out from under its own cargo is worse than no animation at all.
	cargo = PackedInt32Array()
	var shown := mini(lot.size(), HOLD_SHOWN)
	for i in lot.size():
		haul.send(
			lot[i], yard.drop_point(), hold_spot(mini(i, shown - 1), shown),
			i, lot.size(), self, self
		)
	_dwell = maxf(DWELL, Haul.volley_time(lot.size()) + 0.15)
	return true


## A piece landing in the hold. The haul calls this when it arrives, which is the only way
## anything gets aboard while there is a haul to throw it.
func stow(def_index: int) -> void:
	cargo.append(def_index)
	queue_redraw()


## Space for cargo out of the yard.
func room_left() -> int:
	return maxi(capacity - cargo.size(), 0)


## Space the skimmer may fill: the hold plus its own deck space.
func skim_room() -> int:
	return maxi(capacity + skim_hold - cargo.size(), 0)


## Which materials are aboard, as dropoff indices, in the order they will be visited:
## round the lake one way from where the boat is now, so a run is a lap rather than a
## series of dashes back and forth across the middle.
func plan_route() -> Array[int]:
	var wanted: Array[int] = []
	for i in cargo.size():
		var kind := grid.defs[cargo[i]].material as int
		if not wanted.has(kind):
			wanted.append(kind)
	var here := Iso.basin_angle(tile_pos)
	wanted.sort_custom(
		func(a: int, b: int) -> bool:
			return _sweep_from(here, a) < _sweep_from(here, b)
	)
	return wanted


## How far anticlockwise-to-clockwise round the lake a dropoff is from an angle, always
## between 0 and TAU. Sorting on this is what turns a set of stops into a lap.
func _sweep_from(from: float, index: int) -> float:
	var to := Iso.basin_angle(dropoffs[index].berth)
	return fposmod(to - from, TAU)


func _place() -> void:
	position = Iso.tile_to_world(tile_pos.x, tile_pos.y)
	position.y += -RIDE_HEIGHT + _swell(position.x, _time * WAVE_SPEED) * WAVE_AMPLITUDE


func _process(delta: float) -> void:
	_time += delta

	match state:
		State.DOCKED:
			# Ferrying first: a hull with something to carry carries it, and only a hull
			# with nothing to do goes wandering.
			if auto_ferry and dispatch():
				pass
			elif patrol:
				_next_patrol()
		State.PATROL:
			if not patrol:
				_head_home()
			elif _patrol_moved():
				_next_patrol()
			elif _sail(delta):
				_next_patrol()
		State.LOADING:
			_dwell -= delta
			if _dwell <= 0.0:
				_begin_route()
		State.SAILING:
			if _sail(delta):
				state = State.UNLOADING
				_dwell = DWELL
		State.UNLOADING:
			_dwell -= delta
			if _dwell <= 0.0:
				_land_cargo()
		State.RETURNING:
			if _sail(delta):
				state = State.DOCKED
				target = -1
				runs_done += 1

	_place()
	_throw_spray(delta)
	# The wake drawn under the hull is the boat's own; this is what it leaves behind in the
	# lake, on the same water everything else disturbs.
	if splash != null and _under_way():
		splash.wake(self, position + _screen_heading() * -HULL_LENGTH * 0.5,
			HULL_WIDTH * 1.1, HULL_RIPPLE)
	_repaint()


## Repaint while the hull is moving, and otherwise only when its picture would differ.
##
## A hull under way has a wake that runs on the clock, so it earns its frame. A hull tied up
## at a yard does not: it is a silhouette and a load, and both of those sit still. The bob
## on the swell moves the node rather than the drawing, so it costs nothing to skip.
func _repaint() -> void:
	if _under_way():
		queue_redraw()
		return
	var key := hash([
		state, cargo.size(), skim_radius, (_screen_heading() * 64.0).round()
	])
	if key != _painted:
		_painted = key
		queue_redraw()


## Spray off the bow while under way. The same splash the net and the falling rubbish make,
## so the water breaks the one way in this game however it is broken.
func _throw_spray(delta: float) -> void:
	if splash == null or not _under_way():
		_spray_in = 0.0
		return
	_spray_in -= delta
	if _spray_in > 0.0:
		return
	_spray_in = BOW_SPRAY
	# Off the bow, and off to one side or the other of it: a hull pushing water throws it
	# outward rather than straight ahead.
	var along := _screen_heading()
	var across := Vector2(-along.y, along.x)
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	splash.splash(
		position + along * HULL_LENGTH * 0.44 + across * HULL_WIDTH * 0.3 * side,
		BOW_SPRAY_SIZE * _rng.randf_range(0.7, 1.3)
	)


## Work out the stops and set off for the first one. A hold that turns out to be empty —
## nothing but materials with no yard, which cannot happen but is cheap to survive — goes
## straight home.
func _begin_route() -> void:
	if sfx != null:
		sfx.play_horn()
	_route = plan_route()
	if _route.is_empty():
		_head_home()
		return
	_next_stop()


func _next_stop() -> void:
	target = _route.pop_front()
	_legs = _plan_legs(tile_pos, dropoffs[target].berth)
	state = State.SAILING


## Has the water it was sent to moved out from under it?
func _patrol_moved() -> bool:
	if patrol_at == Vector2.INF:
		return false
	return _patrol_aim == Vector2.INF or patrol_at.distance_to(_patrol_aim) > PATROL_REPLAN


## Off to the next bit of water. One leg at a time rather than a planned lap, so a boat that
## is told to stop patrolling stops at the end of the leg it is on instead of finishing a
## circuit nobody asked for — and so a hull can be turned towards something the moment
## there is something to turn towards.
func _next_patrol() -> void:
	target = -1
	_patrol_aim = patrol_at
	var to := patrol_at if patrol_at != Vector2.INF else _wander_to()
	_legs = _plan_legs(tile_pos, to)
	state = State.PATROL


## Somewhere else on the basin, chosen loosely. Both the angle it moves round by and how
## far out it ends are rolled, so an idle fleet drifts about the lake instead of tracing a
## ring at a fixed rate.
func _wander_to() -> Vector2:
	for attempt in 8:
		var angle := (
			Iso.basin_angle(tile_pos)
			+ _rng.randf_range(PATROL_STEP.x, PATROL_STEP.y) * (1.0 if _rng.randf() < 0.75 else -1.0)
		)
		var to := Iso.basin_point(angle, _rng.randf_range(PATROL_INSET.x, PATROL_INSET.y))
		if Iso.in_lake(int(to.x), int(to.y)):
			return to
	return Iso.basin_point(Iso.basin_angle(tile_pos) + 1.0, 0.55)


func _head_home() -> void:
	target = -1
	_legs = _plan_legs(tile_pos, dock)
	state = State.RETURNING


## Everything of this yard's material comes off; the rest stays aboard for the next stop.
func _land_cargo() -> void:
	var kind := dropoffs[target].kind
	var landed := PackedInt32Array()
	var kept := PackedInt32Array()
	for i in cargo.size():
		if grid.defs[cargo[i]].material == kind:
			landed.append(cargo[i])
		else:
			kept.append(cargo[i])
	cargo = kept
	if not landed.is_empty():
		sold.emit(landed, kind)

	if _route.is_empty():
		_head_home()
	else:
		_next_stop()


## How hard this hull is working its engine, 0 to 1. Loading and unloading is the crane
## hauling rubbish on and off at the island, which is the loudest the boat ever gets; under
## way it is a cruise; docked it is off.
func engine_effort() -> float:
	match state:
		State.LOADING, State.UNLOADING:
			return 1.0
		State.SAILING, State.RETURNING:
			return 0.45
	return 0.0


## One frame of travel along the current leg list, plus a bite of the water on the way.
## Returns true once the last waypoint is reached.
func _sail(delta: float) -> bool:
	if _legs.is_empty():
		return true
	var step := speed * delta
	var moved := 0.0
	while step > 0.0 and not _legs.is_empty():
		var to: Vector2 = _legs[0]
		var gap := to - tile_pos
		if gap.length() <= maxf(step, ARRIVE_DISTANCE):
			moved += gap.length()
			tile_pos = to
			_legs.pop_front()
			step -= gap.length()
			continue
		heading = gap.normalized()
		tile_pos += heading * step
		moved += step
		step = 0.0

	# Only a boat with somewhere to be fishes. On the way home it is empty and pointed at
	# the dock, and there is no material it would be looking for.
	if target >= 0:
		_skim_along(moved)
	return _legs.is_empty()


## The skimmer, worked in fixed steps of travel rather than per frame.
##
## Every piece it passes over is a roll of the dice, not a certainty: the boat is dragging
## a net behind a moving hull, and most of what it goes over slips underneath. Turning that
## chance up is most of what the skimmer upgrade buys.
func _skim_along(distance: float) -> void:
	if skim_radius < 0 or grid == null or target < 0:
		return
	_skim_travel += distance
	while _skim_travel >= SKIM_STEP:
		_skim_travel -= SKIM_STEP
		_skim_once()


## Where the skimmer's mouth is, in tile coordinates: off the stern rather than under the
## hull.
##
## It used to sweep from the boat's own tile, which meant the ferry ate the water it was
## about to sail over and left the water it had just dragged a net through untouched. The
## rubbish went in the hold either way, but it went in from the wrong place.
func _skim_centre() -> Vector2:
	return tile_pos - heading.normalized() * SKIM_TRAIL


func _skim_once() -> void:
	if skim_room() <= 0:
		return
	var kind := dropoffs[target].kind
	var mouth := _skim_centre()
	var here := grid.tile_at(Iso.tile_to_world(mouth.x, mouth.y))
	if here < 0:
		return
	for index in grid.tiles_around(here, skim_radius):
		if skim_room() <= 0:
			return
		var k := grid.reachable_slot(index, skim_depth, skim_power, kind, false)
		if k < 0:
			continue
		if _rng.randf() >= skim_chance:
			continue
		var at := grid.surface_pos(index)
		var def := grid.def_at(index, k)
		var taken := grid.take(index, k)
		cargo.append(taken)
		skimmed.emit(taken)
		if splash != null:
			# At the net, not at the tile the piece came off. The sweep reaches further than
			# the net is drawn, so a crown of water blooming a couple of tiles out to one
			# side reads as the lake spitting rather than as the boat catching something.
			splash.splash(
				_at_the_net(at), clampf(0.2 + def.size.x / 40.0, 0.0, 0.85)
			)


## A point pulled onto the skimmer's mouth, along the line from the middle of it. Measured in
## a space where the mouth is a unit circle, the same way the cast net does it.
func _at_the_net(at: Vector2) -> Vector2:
	var centre := _skim_centre()
	var middle := Iso.tile_to_world(centre.x, centre.y) + Vector2(0.0, -RIDE_HEIGHT)
	var span := HULL_WIDTH * 0.5 * (SKIM_MOUTH + SKIM_MOUTH_STEP * float(skim_radius))
	var gap := at - middle
	var out := Vector2(gap.x / span, gap.y / (span * 0.5)).length()
	if out <= 1.0:
		return at
	return middle + gap / out


## The waypoints from one point to another, bent around the island and then straightened
## back out again.
##
## A straight run between two yards on opposite banks goes over the shed, so any leg that
## comes too near the island is split at a point out on the roaming ring, halfway round
## between its two ends, and each half is checked again. The splitting is deliberately
## crude, and the tidy pass afterwards is what makes it acceptable: it drops every waypoint
## the boat did not actually need, so a route that only wanted bending at one end does not
## come back as a tour of the lake.
func _plan_legs(from: Vector2, to: Vector2) -> Array[Vector2]:
	# The dock is tucked against the island's beach, so it is approached and left head-on,
	# straight out from the island, the way any boat comes at a jetty. Without this every
	# path to it is a chord that clips the beach on one side and has to be bent again, and
	# the bend has to be bent, and the ferry arrives home sideways after four corrections.
	var points: Array[Vector2] = []
	var start := from
	if from.is_equal_approx(dock):
		start = _dock_approach()
		points.append(start)
	var finish := to
	var tail: Array[Vector2] = []
	if to.is_equal_approx(dock):
		finish = _dock_approach()
		tail.append(dock)

	points.append_array(_split_leg(start, finish))
	points.append_array(tail)
	# Tidy first, so smoothing is not spent pulling on corners that should not exist; the
	# approach point is dropped here when the ferry was already coming in straight. Then
	# tidy again, because a smoothed corner is often one that can go entirely.
	points = _tidy(from, points)
	points = _smooth(from, points)
	return _tidy(from, points)


## Pull every corner in towards the straight line through it, as far as it will go without
## fouling the island.
##
## The splitting step picks corners that are clear but not short — for a run that passes
## dead over the island it can only guess a side, and it guesses square on. Dragging each
## corner towards its neighbours afterwards turns that right-angle dogleg into the shallow
## curve a boat would actually steer, and costs a handful of clearance samples on a path
## that is planned once per leg.
func _smooth(from: Vector2, legs: Array[Vector2]) -> Array[Vector2]:
	if legs.size() < 2:
		return legs
	var out := legs.duplicate()
	for pass_number in 3:
		for i in range(0, out.size() - 1):
			var before: Vector2 = from if i == 0 else out[i - 1]
			var after: Vector2 = out[i + 1]
			var mid := (before + after) * 0.5
			# Furthest pull first, so the loop keeps the biggest improvement that fits.
			for step in [1.0, 0.75, 0.5, 0.25]:
				var moved: Vector2 = out[i].lerp(mid, step)
				if _leg_is_clear(before, moved) and _leg_is_clear(moved, after):
					out[i] = moved
					break
	return out


## Where the ferry lines up before coming in to the dock: straight out from the island,
## far enough off the beach that everything outside it is open water.
func _dock_approach() -> Vector2:
	return Iso.ISLAND_CENTRE + (dock - Iso.ISLAND_CENTRE).normalized() * Iso.ISLAND_RADIUS \
		* ISLAND_BERTH


func _split_leg(from: Vector2, to: Vector2, depth: int = 0) -> Array[Vector2]:
	if depth >= 3 or _leg_is_clear(from, to):
		return [to]
	var via := _around_island(from, to)
	var out: Array[Vector2] = []
	out.append_array(_split_leg(from, via, depth + 1))
	out.append_array(_split_leg(via, to, depth + 1))
	return out


## A point to go via, close alongside the island rather than out on the bank.
##
## Worked out in the island's own squashed coordinates, where it is a unit circle: take the
## point on the direct line that comes nearest the middle, and push it out to a clear
## radius along the direction it already lies in. That is the shortest way past an obstacle
## in the middle of open water, and it is what the ferry should do — an earlier version
## bent via a point on the shore ring, which for two places on opposite banks sent it round
## most of the lake to get past something the size of a shed.
func _around_island(from: Vector2, to: Vector2) -> Vector2:
	var a := (from - Iso.ISLAND_CENTRE) / Iso.ISLAND_RADIUS
	var b := (to - Iso.ISLAND_CENTRE) / Iso.ISLAND_RADIUS
	var span := b - a
	var near := a
	if span.length_squared() > 0.0001:
		near = a + span * clampf(-a.dot(span) / span.length_squared(), 0.0, 1.0)
	# Dead through the middle: there is no "which side" in the line itself, so take the
	# perpendicular. Either side is the same length; this one is consistent.
	if near.length() < 0.05:
		near = Vector2(-span.y, span.x).normalized()
	return Iso.ISLAND_CENTRE + near.normalized() * ISLAND_BEND * Iso.ISLAND_RADIUS


## Drop any waypoint the boat can simply sail past. Walked repeatedly rather than once,
## because removing one waypoint often makes its neighbour redundant too — which is exactly
## the case on the way home, where the destination is the thing that forced the bend.
func _tidy(from: Vector2, legs: Array[Vector2]) -> Array[Vector2]:
	var out := legs.duplicate()
	var i := 0
	while i < out.size() - 1:
		var before: Vector2 = from if i == 0 else out[i - 1]
		if _leg_is_clear(before, out[i + 1]):
			out.remove_at(i)
			i = maxi(i - 1, 0)
		else:
			i += 1
	return out


## Does this leg keep far enough off the island?
##
## "Far enough" is measured against its own ends, not against a fixed ring. The dock is
## tucked against the island's beach on purpose — it is where the boat ties up — and a
## flat clearance rule calls every leg that touches it a collision. That is what used to
## send the empty ferry home by way of three quarters of the lake: the destination itself
## failed the test, so the leg split until it ran out of recursion. A leg only has to stay
## as clear of the island as the places it is joining already are.
func _leg_is_clear(from: Vector2, to: Vector2) -> bool:
	var limit := minf(
		ISLAND_CLEAR,
		minf(
			Iso.island_fraction(from.x, from.y), Iso.island_fraction(to.x, to.y)
		)
	)
	for i in 17:
		var at := from.lerp(to, float(i) / 16.0)
		if Iso.island_fraction(at.x, at.y) < limit - 0.001:
			return false
	return true


static func _swell(x: float, t: float) -> float:
	return sin(x * 0.011 + t) * 0.62 + sin(x * 0.029 - t * 1.7) * 0.38


## The ferry, drawn from the sheet of headings baked out of the 3D model, plus the parts
## that are not the boat: its wake, its load, its pennant and its skimmer.
##
## The hull is a picture per heading rather than one picture turned. A boat is not a flat
## card: seen on an isometric plane, one pointing away from the camera shows its stern and
## one coming towards it shows its bow, and no amount of rotating a single sprite produces
## the second from the first. tools/bake_boat.gd renders the model once per heading through
## the same camera the game's projection describes, and this picks the frame.
func _draw() -> void:
	_painted = hash([
		state, cargo.size(), skim_radius, (_screen_heading() * 64.0).round()
	])
	var ink := Color(0.11, 0.09, 0.1)
	var half_l := HULL_LENGTH * 0.5
	var half_w := HULL_WIDTH * 0.5
	# Where the boat is pointing on screen, which is not where it is pointing on the tile
	# field: everything drawn alongside the hull has to lie along the same line the hull
	# does.
	var along := _screen_heading()
	var across := Vector2(-along.y, along.x)

	# The wake, first, so the hull sits in it. Only while actually moving — a docked boat
	# throwing a wake is the kind of detail that reads as broken.
	if _under_way():
		_draw_wake(half_l, half_w, along, across)

	# The skimmer, trailing off the stern. Drawn before the hull so it sits behind it, and
	# only once one is fitted, because it is the visible difference a bought upgrade makes.
	if skim_radius >= 0:
		_draw_skimmer(half_l, half_w, along, across, ink)

	_draw_hull(half_l, half_w, ink)

	# The load, sitting in the hold rather than on top of the boat. A laden ferry and an
	# empty one have to be different silhouettes, or the run has nothing to show for
	# itself — but it has to look stowed, so the rows are laid out along the hull between
	# the cabin and the foredeck and are drawn back to front.
	if grid != null:
		var shown := mini(cargo.size(), HOLD_SHOWN)
		for i in shown:
			var spot := hold_spot(i, shown)
			draw_set_transform(spot, 0.0, Vector2(HOLD_SCALE, HOLD_SCALE))
			grid.defs[cargo[i]].stamp_iso(self)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# A pennant in the colour of wherever it is going, so a glance at the boat says which
	# yard it is running to.
	if target >= 0 and target < dropoffs.size():
		var mast := Vector2(0.0, -HULL_HEIGHT * 1.4)
		draw_line(mast, mast + Vector2(0.0, -24.0), ink, 1.6)
		draw_colored_polygon(
			PackedVector2Array([
				mast + Vector2(0.0, -24.0), mast + Vector2(16.0, -18.0),
				mast + Vector2(0.0, -12.0)
			]),
			dropoffs[target].tint
		)


## The hull itself: the baked frame for the way it is pointing, or the blocked-in
## placeholder if the sheet is missing, so the game still runs without the bake.
func _draw_hull(half_l: float, half_w: float, ink: Color) -> void:
	var sheet := _sheet()
	if sheet != null:
		var frame := float(sheet.get_height())
		var span := frame * (HULL_LENGTH / HULL_IN_FRAME)
		draw_texture_rect_region(
			sheet,
			Rect2(Vector2(-span, -span) * 0.5 + Vector2(0.0, -HULL_HEIGHT * 0.5), Vector2(span, span)),
			Rect2(float(heading_frame()) * frame, 0.0, frame, frame)
		)
		return

	var along := _screen_heading()
	var across := Vector2(-along.y, along.x)
	var hull := PackedVector2Array([
		along * half_l, along * half_l * 0.45 + across * half_w * 0.5,
		-along * half_l * 0.8 + across * half_w * 0.5, -along * half_l,
		-along * half_l * 0.8 - across * half_w * 0.5, along * half_l * 0.45 - across * half_w * 0.5
	])
	draw_colored_polygon(hull, Color(0.72, 0.34, 0.24))
	var closed := hull.duplicate()
	closed.append(hull[0])
	draw_polyline(closed, ink, 1.6)


## Under way, as opposed to sitting at a berth or a merchant with the engine idling.
func _under_way() -> bool:
	return (
		state == State.SAILING or state == State.RETURNING or state == State.PATROL
	)


## The wake: disturbed water off the stern with arcs shedding backwards down it.
##
## The wedge alone was still: correct in shape and dead as a photograph, which under a moving
## hull reads as a grey plate the boat is sitting on. What makes water look like water is
## that it keeps arriving — so the arcs are spaced along the wedge and slid backwards with
## time, each fading as it goes, and a new one appears at the stern as the last one dies.
##
## Everything that made the old one look machined is gone. One hard polygon has become a
## stack of fainter ones, so the wake has no outline; the chevrons have become arcs that bow
## back the way water peels off a hull; and every arc gets its own width, its own drift and
## its own offset off the centreline, so no two are the same shape and the pattern never
## repeats down the length of it. The jitter is hashed off the arc's own index rather than
## drawn from `_rng`, because it has to be the same jitter every frame — rolled fresh, the
## wake boils.
func _draw_wake(half_l: float, half_w: float, along: Vector2, across: Vector2) -> void:
	var stern := -along * half_l * 0.85
	var length := half_l * WAKE_LONG

	# The disturbed water, as overlapping slabs rather than one wedge: each shorter and
	# wider and fainter than the last, so the sides fray out into the lake instead of
	# ending on a line. Off-centre by a little, because a hull throws more water one side
	# than the other and a perfectly balanced wake is the tell that this is geometry.
	for layer in WAKE_LAYERS:
		var t := float(layer) / float(WAKE_LAYERS - 1)
		var reach := length * lerpf(1.0, 0.34, t)
		var wide := half_w * WAKE_WIDE * lerpf(0.72, 1.35, t)
		var skew := across * half_w * 0.16 * (_wake_noise(layer, 3.1) * 2.0 - 1.0)
		var tail := stern - along * reach + skew
		draw_colored_polygon(
			PackedVector2Array([
				stern + across * half_w * 0.2,
				stern - across * half_w * 0.2,
				tail - across * wide,
				tail + across * wide,
			]),
			Color(1.0, 1.0, 1.0, 0.035)
		)

	for i in WAKE_RIPPLES:
		# Each arc's own place along the wedge, sliding back and wrapping round, at its own
		# pace so the spacing between them keeps changing.
		var pace := lerpf(1.0 - WAKE_VARY, 1.0 + WAKE_VARY, _wake_noise(i, 7.7))
		var speed := WAKE_SPEED_OFF * pace
		var down := fposmod(float(i) / float(WAKE_RIPPLES) + _time * speed, 1.0)
		var wide := half_w * lerpf(0.3, WAKE_WIDE, down)
		wide *= lerpf(1.0 - WAKE_VARY, 1.0 + WAKE_VARY, _wake_noise(i, 1.3))
		var at := stern - along * (length * down)
		# Off the centreline, and by a different amount at each end: this is the one thing
		# that stops a row of arcs reading as a stencil.
		at += across * wide * WAKE_WANDER * (_wake_noise(i, 2.9) * 2.0 - 1.0)
		var left := wide * lerpf(1.0 - WAKE_WANDER, 1.0 + WAKE_WANDER, _wake_noise(i, 5.2))
		var right := wide * lerpf(1.0 - WAKE_WANDER, 1.0 + WAKE_WANDER, _wake_noise(i, 8.6))
		# Fades in off the stern and out at the tail, so neither end pops.
		var fade := sin(down * PI) * 0.2 * lerpf(0.7, 1.2, _wake_noise(i, 4.4))
		draw_polyline(
			_wake_arc(at, along, across, left, right), Color(1.0, 1.0, 1.0, fade), 1.5
		)


## One arc of the wake: a curve bowing back towards the stern, longer on one side than the
## other. Built point by point rather than as a polyline through three corners, because the
## corners were what read as a chevron.
func _wake_arc(
	at: Vector2, along: Vector2, across: Vector2, left: float, right: float
) -> PackedVector2Array:
	var out := PackedVector2Array()
	var steps := 8
	for step in steps + 1:
		# -1 at the left tip, 0 on the centreline, 1 at the right.
		var u := lerpf(-1.0, 1.0, float(step) / float(steps))
		var reach := left if u < 0.0 else right
		# Squared, so the arc is flat through the middle and turns hard at the tips, which
		# is the shape water peeling off a hull actually leaves.
		out.append(
			at + across * u * reach + along * (1.0 - u * u) * maxf(left, right) * WAKE_BOW
		)
	return out


## Fixed noise for the wake, 0 to 1, from an arc's index and a salt. Hashed rather than
## random: the same arc has to come out the same shape every frame it is drawn.
func _wake_noise(i: int, salt: float) -> float:
	var h := sin(float(i) * 12.9898 + salt * 78.233 + float(rng_seed) * 0.017) * 43758.5453
	return fposmod(h, 1.0)


## The skimmer: the angler's own net, lying open on the water and trailing off the stern.
##
## The same drawing the player casts, at the width the upgrade actually sweeps. It used to be
## a green quadrilateral, which said "there is a thing here" and nothing else — and a skimmer
## is a net, so it may as well be the one the game already has a picture of.
func _draw_skimmer(
	half_l: float, half_w: float, along: Vector2, across: Vector2, ink: Color
) -> void:
	var mouth := half_w * (SKIM_MOUTH + SKIM_MOUTH_STEP * float(skim_radius))
	# Right off the transom rather than towed behind on a warp: it is a net slung off the
	# back of a working boat, and a gap between the two reads as a net somebody dropped.
	var back := -along * half_l * SKIM_BEHIND

	if skim_sheet != null and not skim_frame.is_empty():
		var region: Rect2 = skim_frame["region"]
		# Scaled by the frame's own rim, the same way the angler's net is, so the drawn
		# mouth is the width the skimmer sweeps rather than whatever the picture happens
		# to be.
		var scale := mouth * 2.0 / maxf(float(skim_frame["rim"]), 1.0)
		var size := region.size * scale
		var hang := Vector2(size.x * 0.5, size.y * float(skim_frame["hang"]))
		draw_texture_rect_region(
			skim_sheet, Rect2(back - hang, size), region, Color(ink.r, ink.g, ink.b, 0.85)
		)
		return

	var net := PackedVector2Array([
		back + across * mouth * 0.4, back - across * mouth * 0.4,
		back - along * mouth - across * mouth * 0.22,
		back - along * mouth + across * mouth * 0.22
	])
	draw_colored_polygon(net, Color(0.30, 0.36, 0.30, 0.75))
	var closed := net.duplicate()
	closed.append(net[0])
	draw_polyline(closed, ink, 1.4)


## Where the i-th piece of a load of `shown` sits, in this node's own space.
##
## Laid out in tile space and then projected, not offset around the screen. The plane is
## seen at an angle: a step of one tile across the deck is a short step on screen when the
## boat is pointing north and a long one when it is pointing east, and stowing cargo by
## screen offsets floats half of it off the side of the hull.
func hold_spot(i: int, shown: int) -> Vector2:
	var beam := Vector2(-heading.y, heading.x).normalized()
	var rows := maxf(float((shown - 1) / 2), 1.0)
	var down_hold := float(i / 2) / rows
	var across_hold := -1.0 if i % 2 == 0 else 1.0
	if shown == 1:
		across_hold = 0.0
	var in_tiles := (
		heading.normalized() * lerpf(HOLD_FROM, HOLD_TO, down_hold) * (HULL_LENGTH / TILE_REACH)
		+ beam * across_hold * (HULL_WIDTH / TILE_REACH) * HOLD_ACROSS * 0.5
	)
	return Iso.tile_to_world(in_tiles.x, in_tiles.y) + Vector2(0.0, -HULL_HEIGHT * 0.55)


## Which baked frame shows the boat pointing the way it is pointing.
##
## The bake turns the model about its up axis, and Godot's forward is -Z. The camera it was
## baked through puts world +X along the tile field's +x and world +Z along its +y, so a
## model turned by t is heading (-sin t, -cos t) in tiles — and the frame wanted for a
## heading is that read backwards.
func heading_frame() -> int:
	var frames := _frame_count()
	if frames <= 0:
		return 0
	var turn := atan2(-heading.x, -heading.y)
	return posmod(int(round(turn / TAU * float(frames))), frames)


## How many headings the sheet holds. Taken from the sheet itself rather than written down
## twice: it is one row of square frames.
func _frame_count() -> int:
	var sheet := _sheet()
	if sheet == null:
		return 0
	return int(round(float(sheet.get_width()) / float(sheet.get_height())))


## One frame of the baked sheet, for anything that wants a picture of a ferry without being
## one — the shop's rows, so far. `turn` runs 0 to 1 round the compass.
static func art_frame(turn: float) -> Dictionary:
	var sheet := _sheet()
	if sheet == null:
		return {}
	var side := float(sheet.get_height())
	var count := int(round(float(sheet.get_width()) / side))
	var index := clampi(int(turn * float(count)), 0, count - 1)
	return {
		"sheet": sheet,
		"region": Rect2(float(index) * side, 0.0, side, side),
	}


## The baked sheet, loaded once and shared by every hull in the fleet.
static func _sheet() -> Texture2D:
	if _sheet_cache == null and not _sheet_missing:
		if ResourceLoader.exists(FRAMES_PATH):
			_sheet_cache = load(FRAMES_PATH) as Texture2D
		_sheet_missing = _sheet_cache == null
	return _sheet_cache


## Which way the boat points on screen. The tile field is seen at an angle, so a heading of
## one tile east is not a screen vector of one to the right.
func _screen_heading() -> Vector2:
	var on_screen := Iso.tile_to_world(heading.x, heading.y)
	return on_screen.normalized() if on_screen.length_squared() > 0.0001 else Vector2.RIGHT
