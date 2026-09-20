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
## a hold with a bit of everything is a lap.
##
## Legs are planned around the island rather than straight through it: a chord from the
## east yard to the west one would drive the hull over the shed.
class_name Boat
extends Node2D

## Emitted at a yard with everything that was landed there. The lake pays for it; the boat
## does not know what a sludge is.
signal sold(cargo: PackedInt32Array, kind: int)

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

## How often a boat under way throws spray off its bow, in seconds, and how big. Small: it is
## a work boat at walking pace, not a speedboat.
const BOW_SPRAY := 0.34
const BOW_SPRAY_SIZE := 0.22

## The hull at the waterline, in world pixels: the blue boat's forty-six by twenty-five art
## pixels at two world pixels each, the scale every other sprite in the lake is drawn at.
## Bigger than anything it collects, and no bigger.
const HULL_LENGTH := 92.0
const HULL_WIDTH := 50.0

## How tall the drawn hull stands above the water, for the things that sit on it: the load
## in the hold.
const HULL_HEIGHT := 16.0

## The open hold, as a fraction of the hull: where along it the cargo deck starts and ends,
## how far across it reaches, and how high above the water it is, in HULL_HEIGHTs. Taken off
## the drawing — the cabin sits over the stern and the mast is amidships, so the load goes in
## the well round the mast, on the foredeck side of it. Kept short of the bow: the frames draw
## the bow-on deck higher than the plane's projection puts it, and a load laid to the bow rail
## by the projection floats past the cut bow.
##
## Down in the boat rather than on top of it (2026-09-12): the lift is what decides whether a
## piece reads as stowed or as balanced on the deck, and the sail overlay is what lets the
## load sit round the mast at all — before it, anything that high cut through the cloth.
const HOLD_FROM := 0.02
const HOLD_TO := 0.20
const HOLD_ACROSS := 0.26
const HOLD_LIFT := 0.55

## How the hold fills: how many pieces are drawn, how big, how many lie in one layer before
## the next starts on top of them, and how far each layer rides above the one under it, in
## HULL_HEIGHTs. It fills bottom up like the recycle box — a ferry with one piece aboard has
## it lying on the boards, and a full one is heaped — rather than spreading flat, which reads
## as a deck cargo lashed down. Twelve is what a heap needs; six read as a handful.
const HOLD_SHOWN := 12
const HOLD_SCALE := 0.5
const HOLD_LAYER := 4
const HOLD_STACK := 0.3

## How many screen pixels one tile of travel covers, for laying things out on the deck in
## tiles rather than in pixels.
const TILE_REACH := 35.777

## The sheet of headings: sixteen turns of the PixZels blue boat, one row of square frames,
## cut by tools/build_boat_sheet.py (jib, forestay and floor shadow removed). The hull's
## waterline length in a frame sets the scale — HULL_LENGTH over it is the two world pixels
## per art pixel — and the load and the foam are placed against the hull rather than
## against the frame.
const FRAMES_PATH := "res://assets/boat_sail_frames.png"

## The sail on its own, frame for frame, from the same builder. Drawn over the load so the
## load sits in the hull instead of on top of the picture (2026-09-12). It is a *copy* of the
## sail's pixels rather than a cut, so the main sheet is whole and a missing overlay costs
## nothing but the layering. This supersedes the 2026-09-11 call that the load draws over the
## picture, sails and all: that weighed hand-cutting sixteen headings into two layers, and the
## builder detects the cloth instead.
const SAIL_OVER_PATH := "res://assets/boat_sail_over.png"
const FRAMES_META := "res://assets/boat_sail_frames.json"
const HULL_IN_FRAME := 46.0
const FRAME_SIDE := 128

## Where in a frame the water meets the hull under the mast — the point the sheet turns
## about — laid on the boat's position. In frame pixels. The sheet's json says where that
## is (its side view's waterline); this is the guess used without it.
const HULL_ANCHOR := Vector2(64.0, 92.0)

## Which way the sheet's first frame points, as an angle in tile space: bow towards the
## camera, which on the plane is down the tile diagonal (1, 1). The frames turn clockwise
## seen from above, and the projection keeps that.
const FRAME_ZERO_TURN := PI * 0.25

## The hull in the water rather than on it. Each frame is cut along the waterline its json
## lists (`cut`, from tools/build_boat_sheet.py: one level row, under the painted boot-top
## at the near end), so what is under the water is not drawn — the same cut every floating
## piece gets (LakeGrid.WATERLINE). Level by decision (2026-09-11): a line bent to follow
## the near side ran into the bow and the transom. The lake's own foam collar
## (foam.gdshader) lies along that line, scaled up from the ten-pixel rubbish to the hull
## and reaching COLLAR_REACH past its ends. Its shadow is the sun's, cast from the same
## picture: see HullShade. Collar and shadow ride in this node's space, which already bobs
## (`_place`), so the collar's material carries no swell.
const COLLAR_SCALE := 2.4
const COLLAR_REACH := 1.5

## How far the collar bows towards the camera at the near side, as a fraction of the hull's
## half beam on screen, and how many segments the curve is built from. Shallow: the point is
## that the hull is in the water all the way round, and a deeper curve reads as a puddle the
## boat is standing in rather than the line it floats on.
const COLLAR_BOW := 0.34
const COLLAR_STEPS := 8

## How far the whole arc is lifted up into the hull, as a fraction of the foam's own reach
## below the line. The cut is the bottom of the drawn hull, so a collar hung straight on it
## puts its whole lower band outside the sprite and the boat wears a skirt. Lifted, the froth
## sits in the hull's own bottom edge and only its tongues show past it, which is what a
## waterline looks like.
const COLLAR_LIFT := 0.8

## How far the froth carries out towards the ends of the collar: the exponent on the shader's
## half-ellipse round-off, where 1 is the ellipse the rubbish uses. Lower spreads it, and how
## many tongues the tear puts across the hull's width is raised with it, so what spreads is
## foam rather than a stretched copy of the same shapes.
const COLLAR_SIDES := 0.45
const COLLAR_TEAR := 1.45

## How far the drawn hull sits below where its anchor puts it, in world pixels: one art pixel
## (Lake.ART_PIXEL), so the picture stays on its own grid — half of one would put a
## nearest-filtered texture off its texels and make the planking crawl. The hull, its shadow,
## the sail over it and the load in it all move together; the waterline collar does not, so
## the froth rides that much higher up the sprite. That is the point of it (2026-09-12): the
## boat sits down into its own foam rather than on top of it.
const HULL_DROP := 2.0

## How much darker than the day's ink the boat's shadow is drawn, and the most it may be.
## The day's ink is set for shadows on sand and grass; on the lake, darker to begin with,
## the same alpha at dawn is a shade of blue nobody can see.
const SHADE_GAIN := 3.0
const SHADE_MOST := 0.7

static var _over_cache: Texture2D
static var _over_missing: bool = false
static var _sheet_cache: Texture2D
static var _sheet_missing: bool = false
static var _anchor := HULL_ANCHOR
static var _cuts: Array[PackedVector2Array] = []
static var _boxes: Dictionary = {}

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
## island is a longer trip for the same crossing.
##
## 1.0 is the waterline, not the edge of what the island looks like. The island's sand keeps
## going under the lake for `Iso.SHELF_TILES` — 2.2 tiles — and fades out there, and that
## faded sand is what the eye reads as the island. At 1.25 this left 1.85 tiles, which ended
## inside the sand: the ferry crossed the shelf on every run past. At 1.43 it is 3.2 tiles,
## which is the sand plus a lane of open water wide enough to read as one.
##
## Deliberately inside where the rubbish starts (`Iso.SHELF_CLEAR`, 2.3 tiles out): the lane
## the ferry keeps is over the near edge of the rubbish ring. Clearance here is about the
## picture — a boat crossing a beach — not about the water being empty.
const ISLAND_CLEAR := 1.43

## How far out a bend round the island swings, and how far out the dock is approached from,
## in the same units. Both are comfortably outside ISLAND_CLEAR: a waypoint sitting exactly
## on the limit makes the chords either side of it dip below the limit, and the leg gets
## split again for no gain.
##
## The berth moved out with the clearance; the bend did not have to. At 2.1 tiles outside
## `ISLAND_CLEAR` it is still comfortably clear of it, and swinging it wider only bought a
## longer trip: 1.80 put the worst run home at 1.32 times the direct distance against 1.30
## here, and pulling it in to 1.58 traded a hundredth of that back for six corners instead of
## four.
const ISLAND_BEND := 1.72
const ISLAND_BERTH := 1.57

## Set from the lake's upgrade levels when a run starts. Speed is in tiles per second.
## How far round the hull floating pieces are set bobbing as it passes, in tiles.
const BUMP_REACH := 1.6

## How far round the hull pieces are looked at for shoving aside, in tiles, and how much room
## past the hull's side they are pushed out to, in pixels.
const SHOVE_REACH := 2.6
const SHOVE_CLEAR := 10.0

var speed: float = 4.2
var capacity: int = 6
## What Fast Sell has bought: the multiple on the gap between two pieces of this hull's
## volleys, at both ends of the run — loading out of the island crate and landing the hold in
## a yard's box. 1.0 is an untrained ferry, so a Boat with no lake behind it throws exactly
## as it did before there was a track to buy. See Haul._gap.
var volley_gap: float = 1.0
## Whether it sets off on its own once there is a full hold to carry (`ready_to_sail`).
var auto_ferry: bool = true

## Held at its berth: the main menu's pose (2026-09-17, Richard: "boats are stationary at
## island"). The lake runs live behind the menu, and a fleet ferrying and selling there would
## be the game playing itself. A moored hull never sets off, whatever the yard holds;
## `dispatch` itself is left alone, so nothing else has to know.
var moored: bool = false

## How often a docked hull looks to see whether the lake has anything left in it, in seconds.
## Counting the lake walks every tile, which is not a thing to do sixty times a second a hull.
const DRY_CHECK_EVERY := 1.0

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

## Whether the lake had any rubbish left the last time a docked hull counted, and when it
## counts again. See `ready_to_sail`.
var _lake_dry: bool = false
var _dry_check_in: float = 0.0

## What is aboard, as def indices.
var cargo := PackedInt32Array()

## Where it sits, in tile coordinates, and where it comes home to.
var tile_pos := Vector2.ZERO
var dock := Vector2(Iso.CENTRE.x, Iso.CENTRE.y)

## Which way it is pointing on the plane, for the foam and the hull's lean.
var heading := Vector2(1.0, 0.0)

## Wired up by lake.gd. The boat loads straight out of the yard, for the same reason the net
## takes straight out of the grid: it is the thing doing the work.
var yard: Yard
var grid: LakeGrid
var splash: WaterSplash
## The noises. Optional — a boat with no sound board still ferries.
var sfx: Sfx
## Where cargo is thrown from the yard. Optional — with no haul the load simply appears
## aboard the way it used to.
var haul: Haul

## The four merchants, in TrashDef.Kind order.
var dropoffs: Array[Dropoff] = []

var runs_done: int = 0

## Which seed this hull rolls from. Every ferry in the fleet has to roll its own dice, or two
## boats throw the same spray and patrol the same line.
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
var _rng := RandomNumberGenerator.new()

## Whether the load it just tipped ashore is still in the air. Both halves of unloading are
## State.UNLOADING with a dwell running down, and this is what tells them apart.
var _landing := false

## The hull's drawn shape and its place on the sheet, kept from the frame just drawn so the
## sail can be laid over the load with the same polygon rather than a second measurement.
var _hull_mesh := PackedVector2Array()
var _hull_uvs := PackedVector2Array()

## The bow wave the hull leaves while under way. See HullFoam.
var _foam: HullFoam

## The day, for the sun the shadow is cast by. Handed over by the lake; null in a scene
## with no day, which draws no shadow.
var day: DayCycle

## The shadow on the water and the foam along the waterline, both children so they draw
## under the hull, the collar wearing its own shader.
var _shade: HullShade
var _collar: HullCollar


func _ready() -> void:
	# Pixel art at a whole number of world pixels per art pixel: filtered, its edges smear.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Seeded, like the lake itself: a run that can be replayed is a run that can be tuned.
	_rng.seed = rng_seed
	tile_pos = dock
	_place()
	_foam = HullFoam.new()
	_foam.name = &"Foam"
	_foam.half_length = HULL_LENGTH * 0.5
	_foam.half_width = HULL_WIDTH * 0.5
	add_child(_foam)
	_shade = HullShade.new()
	_shade.name = &"Shade"
	add_child(_shade)
	_collar = HullCollar.new(rng_seed)
	_collar.name = &"Collar"
	add_child(_collar)


func is_running() -> bool:
	return state != State.DOCKED


## Back at the berth this instant, wherever on its run it was, and what was aboard handed
## back. The lake puts that in the crate — the rule a save already keeps for a hold afloat
## (`Lake.load_game` and `afloat`) — so going to the menu mid-run loses nothing and sells
## nothing. Done under the menu's fade, never in sight.
func moor_now() -> PackedInt32Array:
	var aboard := cargo
	cargo = PackedInt32Array()
	_route.clear()
	_legs.clear()
	_landing = false
	_dwell = 0.0
	target = -1
	state = State.DOCKED
	tile_pos = dock
	_place()
	queue_redraw()
	return aboard


## Sail in from off the lake and berth, as if coming home from a run (2026-09-19, issue
## #24). The new game's arrival: this hull carries the angler and his dog in and is the
## fleet's first ferry from then on, rather than a visitor that has to be built and sailed
## away again. `RETURNING` rather than a state of its own — the course home, the bell at the
## berth and the docking are all exactly what this is, and a hull with `moored` set will
## simply sit there once it lands.
func arrive_from(at: Vector2) -> void:
	cargo = PackedInt32Array()
	_route.clear()
	_landing = false
	_dwell = 0.0
	target = -1
	tile_pos = at
	heading = (dock - at).normalized()
	_legs = _plan_legs(at, dock)
	state = State.RETURNING
	_place()
	queue_redraw()


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
			i, lot.size(), self, self, null, volley_gap
		)
	_dwell = maxf(DWELL, Haul.volley_time(lot.size(), volley_gap) + 0.15)
	return true


## Whether the yard has a full hold waiting for this hull, or the lake has nothing left that
## could ever fill one.
##
## Full holds only, by decision (Richard, 2026-09-14: "too many missed trips"): a ferry that
## sailed the moment anything was in the box made its long lap for two or three pieces, and
## was out on the water when the real load came in. The one exception is the end of the lake:
## once every piece is out of the water, what is in the box is all there will ever be, and a
## hull waiting for more would leave it unsold for good. The shop's "send now" still sends
## whatever there is (`dispatch` alone).
func ready_to_sail(delta: float) -> bool:
	if yard == null or yard.held.is_empty():
		return false
	if yard.held.size() >= maxi(capacity, 1):
		return true
	if grid == null:
		return true
	_dry_check_in -= delta
	if _dry_check_in <= 0.0:
		_dry_check_in = DRY_CHECK_EVERY
		_lake_dry = grid.piece_count() == 0
	return _lake_dry


## A piece landing in the hold. The haul calls this when it arrives, which is the only way
## anything gets aboard while there is a haul to throw it.
func stow(def_index: int) -> void:
	cargo.append(def_index)
	queue_redraw()


## Space for cargo out of the yard.
func room_left() -> int:
	return maxi(capacity - cargo.size(), 0)


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
			# Ferrying first: a hull with a full hold to carry carries it, and only a hull
			# with nothing to do goes wandering.
			if moored:
				pass
			elif auto_ferry and ready_to_sail(delta) and dispatch():
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
			# Twice through: once to tip the load ashore, and again while it is in the air.
			# `_landing` is what tells the two apart, since both are this state with a dwell
			# running down.
			_dwell -= delta
			if _dwell <= 0.0:
				if _landing:
					_landing = false
					_head_back()
				else:
					_land_cargo()
					if not _landing:
						_head_back()
		State.RETURNING:
			if _sail(delta):
				state = State.DOCKED
				target = -1
				runs_done += 1
				# Coming alongside is heard, the way setting off is — the water first, the
				# bell now and then. The berth is on the island the player stands on.
				if sfx != null:
					sfx.play_berth()

	_place()
	_throw_spray(delta)
	if _foam != null:
		_foam.lay(_screen_heading(), 1.0 if _under_way() else 0.0, delta)
	# The water the hull pushes aside sets what is floating near it bobbing, the same bobble a
	# piece settles with when it surfaces. See LakeGrid.bump.
	if grid != null and _under_way():
		var here := grid.tile_at(position)
		if here >= 0:
			for index in grid.tiles_within(here, BUMP_REACH):
				grid.bump(index)
			_shove_aside(here, delta)
	_repaint()


## Push the floating pieces in the hull's way out to either side of it, the way a bow parts
## what is floating in front of it. A piece is pushed out across the hull's line to just clear
## its side, on whichever side it already was; one dead ahead goes to a side picked off its
## tile, so a row of them parts both ways rather than all to one. Drawing only — see
## LakeGrid.shove_to.
func _shove_aside(here: int, delta: float) -> void:
	var along := _screen_heading()
	var across := Vector2(-along.y, along.x)
	# The hull's footprint on the water, squashed across the way the plane is.
	var flat := Vector2(across.x, across.y * HullFoam.SQUASH)
	var half_l := HULL_LENGTH * 0.5
	var clear := HULL_WIDTH * 0.5 * HullFoam.SQUASH + SHOVE_CLEAR
	for index in grid.tiles_within(here, SHOVE_REACH):
		var tile := grid.tile_of(index)
		var rest := Iso.tile_to_world(float(tile.x) + 0.5, float(tile.y) + 0.5) + grid.nudge[index]
		var rel := rest - position
		var ahead := rel.dot(along)
		# Only alongside the hull and a little ahead of the bow; behind the stern it is left
		# to drift back.
		if ahead < -half_l or ahead > half_l * 1.2:
			continue
		var side := rel.dot(across)
		var gap := clear - absf(side)
		if gap <= 0.0:
			continue
		# Out on the side it already sits, or a side picked off the tile if it is dead ahead.
		var way := signf(side) if absf(side) > 0.5 else (1.0 if (tile.x + tile.y) % 2 == 0 else -1.0)
		grid.shove_to(index, flat * way * gap, delta)


## Repaint while the hull is moving, and otherwise only when its picture would differ.
##
## A hull under way is followed by foam that runs on the clock, so it earns its frame. A hull
## tied up at a yard does not: it is a silhouette and a load, and both of those sit still. The
## bob on the swell moves the node rather than the drawing, so it costs nothing to skip.
func _repaint() -> void:
	if _under_way():
		queue_redraw()
		return
	var key := hash([
		state, cargo.size(), (_screen_heading() * 64.0).round(), _sun_key()
	])
	if key != _painted:
		_painted = key
		queue_redraw()


## Where the sun is, coarsely, for the repaint key: a shadow that only moves when the boat
## does is a shadow stuck to the morning. Mirrors Dog._sun_key.
func _sun_key() -> int:
	return 0 if day == null else roundi(day.lean * 60.0) * 1000 + roundi(day.ink * 200.0)


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
		sfx.play_bell()
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
	var yard_here := dropoffs[target]
	var kind := yard_here.kind
	var landed := PackedInt32Array()
	var kept := PackedInt32Array()
	for i in cargo.size():
		if grid.defs[cargo[i]].material == kind:
			landed.append(cargo[i])
		else:
			kept.append(cargo[i])
	cargo = kept
	if landed.is_empty():
		return
	if haul == null:
		sold.emit(landed, kind)
		return
	# Thrown ashore rather than deducted, the same half second the yard already gets when it
	# loads the boat — and counted as each one comes down, not when the last one leaves, so
	# what is on screen and what the purse says are the same thing. See lake.gd's haul
	# handler: a piece tagged with a yard is a piece sold at it.
	#
	# The berth is held until the volley is over, for the reason the loading one is: a hull
	# that sails away from its own cargo in mid-air is worse than no animation.
	for i in landed.size():
		haul.send(
			landed[i], position, yard_here.drop_point(),
			i, landed.size(), null, yard_here, self, volley_gap
		)
	state = State.UNLOADING
	_dwell = maxf(DWELL, Haul.volley_time(landed.size(), volley_gap) + 0.15)
	_landing = true


## On to the next yard on the run, or home if that was the last of them.
func _head_back() -> void:
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


## One frame of travel along the current leg list.
## Returns true once the last waypoint is reached.
func _sail(delta: float) -> bool:
	if _legs.is_empty():
		return true
	var step := speed * delta
	while step > 0.0 and not _legs.is_empty():
		var to: Vector2 = _legs[0]
		var gap := to - tile_pos
		if gap.length() <= maxf(step, ARRIVE_DISTANCE):
			tile_pos = to
			_legs.pop_front()
			step -= gap.length()
			continue
		heading = gap.normalized()
		tile_pos += heading * step
		step = 0.0

	return _legs.is_empty()


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
	#
	# A yard's berth is the same case (2026-09-12): it lies alongside the end of a jetty, so
	# the ferry lines up out along the jetty and comes in parallel to it, and leaves the same
	# way, rather than cutting across the planks from wherever it happens to be.
	var points: Array[Vector2] = []
	var start := from
	if from.distance_to(dock) < ARRIVE_DISTANCE:
		start = _dock_approach()
		points.append(start)
	else:
		var leaving := _yard_at(from)
		if leaving != null:
			start = leaving.approach()
			points.append(start)
	var finish := to
	var tail: Array[Vector2] = []
	if to.distance_to(dock) < ARRIVE_DISTANCE:
		finish = _dock_approach()
		tail.append(to)
	else:
		var calling := _yard_at(to)
		if calling != null:
			finish = calling.approach()
			tail.append(to)

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


## The yard whose berth `at` is, if it is one.
func _yard_at(at: Vector2) -> Dropoff:
	for yard: Dropoff in dropoffs:
		if at.distance_to(yard.berth) < ARRIVE_DISTANCE:
			return yard
	return null


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
## Whether a leg keeps `ISLAND_CLEAR` all the way along it.
##
## Only `from` may lower the limit, and only because the boat is already there: a ferry
## leaving the dock is inside the clearance by definition and has to be allowed to drive out
## of it. `to` may not, and neither may any point sampled in between.
##
## That asymmetry is the whole fix. The limit used to be the smallest of the two ends, which
## sounds even-handed and is not: `_smooth` asks whether a corner it has *invented* is clear,
## passes that corner as `to`, and a corner far enough inside the island answered its own
## question. The planner was pulling waypoints onto the shed and approving them for being
## there — a run home from the north yard went 1.7 tiles inland.
##
## The dock is the one destination that may lower it as well, because the dock is tucked
## against the beach and cannot be reached from outside the clearance at all. That is safe
## for the same reason the invented corners are not: the dock is a fixed point the level put
## there, so letting a leg run in as close as the dock itself never licenses anything nearer
## than the dock. A run that comes in straight, like the yard due south of it, stays one leg;
## one that would cut the corner still has to bend, because the sampled points along it are
## judged against the dock's own distance and not against their own.
func _leg_is_clear(from: Vector2, to: Vector2) -> bool:
	var limit := minf(ISLAND_CLEAR, Iso.island_fraction(from.x, from.y))
	if to.distance_to(dock) < ARRIVE_DISTANCE:
		limit = minf(limit, Iso.island_fraction(to.x, to.y))
	for i in 17:
		var at := from.lerp(to, float(i) / 16.0)
		if Iso.island_fraction(at.x, at.y) < limit - 0.001:
			return false
	return true


static func _swell(x: float, t: float) -> float:
	return sin(x * 0.011 + t) * 0.62 + sin(x * 0.029 - t * 1.7) * 0.38


## The ferry, drawn from its sheet of headings, plus the parts that are not the boat: its
## foam and its load.
##
## The hull is a picture per heading rather than one picture turned. A boat is not a flat
## card: seen on an isometric plane, one pointing away from the camera shows its stern and
## one coming towards it shows its bow, and no amount of rotating a single sprite produces
## the second from the first. The sheet is sixteen turns of one drawn boat, and this picks
## the frame.
func _draw() -> void:
	_painted = hash([
		state, cargo.size(), (_screen_heading() * 64.0).round(), _sun_key()
	])
	var ink := Color(0.11, 0.09, 0.1)
	var half_l := HULL_LENGTH * 0.5
	var half_w := HULL_WIDTH * 0.5
	# No wake under the hull, by decision (2026-09-12): the pale wedge with arcs shedding
	# down it, and the rings dropped behind the stern, are both gone. What a boat leaves is
	# the foam it drags, and that is HullFoam's job.
	_draw_hull(half_l, half_w, ink)

	# The load, down in the hold round the mast. A laden ferry and an empty one have to be
	# different silhouettes, or the run has nothing to show for itself. It fills from the
	# bottom up like the recycle box it is feeding: the first pieces lie on the boards and
	# later ones heap on top of them, each row drawn back to front. Then the sail goes over
	# the lot, so nothing in the hold cuts through the cloth.
	if grid != null:
		var shown := mini(cargo.size(), HOLD_SHOWN)
		for i in shown:
			var spot := hold_spot(i, shown)
			draw_set_transform(spot, 0.0, Vector2(HOLD_SCALE, HOLD_SCALE))
			grid.defs[cargo[i]].stamp_iso(self)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_sail_over()

	# No pennant, by decision (2026-09-12): the flag in the colour of the yard it was running
	# to was a cue nobody needed, and the yards' own tints already tell the piers apart.


## The hull itself: the frame for the way it is pointing, cut along its waterline, its
## anchor on this node's origin — with its shadow and its collar laid for the same frame —
## or the blocked-in placeholder if the sheet is missing, so the game still runs without it.
func _draw_hull(half_l: float, half_w: float, ink: Color) -> void:
	var sheet := _sheet()
	if sheet != null:
		var frame := float(sheet.get_height())
		var scale := HULL_LENGTH / HULL_IN_FRAME
		var index := heading_frame()
		var sheet_size := Vector2(sheet.get_size())
		var corner := Vector2(float(index) * frame, 0.0)
		var points := PackedVector2Array()
		var uvs := PackedVector2Array()
		var drop := Vector2(0.0, HULL_DROP)
		for at in hull_polygon(index):
			points.append((at - _anchor) * scale + drop)
			uvs.append((corner + at) / sheet_size)
		draw_polygon(points, PackedColorArray([Color.WHITE]), uvs, sheet)
		_shade.lay(sheet, points, uvs, day)
		_collar.lay(waterline_arc(index, scale))
		_hull_mesh = points
		_hull_uvs = uvs
		return
	_hull_mesh = PackedVector2Array()
	_shade.visible = false
	_collar.visible = false

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


## The sail again, over whatever has been drawn since the hull — which is the load. The same
## polygon and the same texture coordinates the hull was drawn with, so the two line up by
## construction rather than by a second measurement that could drift.
func _draw_sail_over() -> void:
	var over := _sail_over()
	if over == null or _hull_mesh.is_empty():
		return
	draw_polygon(_hull_mesh, PackedColorArray([Color.WHITE]), _hull_uvs, over)


## Under way, as opposed to sitting at a berth or a merchant with the engine idling.
func _under_way() -> bool:
	return (
		state == State.SAILING or state == State.RETURNING or state == State.PATROL
	)


## Where the i-th piece of a load of `shown` sits, in this node's own space.
##
## Laid out in tile space and then projected, not offset around the screen. The plane is
## seen at an angle: a step of one tile across the deck is a short step on screen when the
## boat is pointing north and a long one when it is pointing east, and stowing cargo by
## screen offsets floats half of it off the side of the hull.
func hold_spot(i: int, shown: int) -> Vector2:
	var beam := Vector2(-heading.y, heading.x).normalized()
	# Which layer this piece is in and where it sits within it. A layer is HOLD_LAYER pieces
	# laid out over the well; the next starts on top once it is full, so the heap grows
	# upwards and the boat is visibly laden before it is visibly full.
	var layer := i / HOLD_LAYER
	var within := i % HOLD_LAYER
	var rows := maxf(float((HOLD_LAYER - 1) / 2), 1.0)
	var down_hold := float(within / 2) / rows
	var across_hold := -1.0 if within % 2 == 0 else 1.0
	if shown == 1:
		across_hold = 0.0
	# Each layer sits a little further aft and a little narrower than the one under it, so a
	# heap comes to a point rather than standing as a column.
	var taper := 1.0 - 0.18 * float(layer)
	var in_tiles := (
		heading.normalized() * lerpf(HOLD_FROM, HOLD_TO, down_hold) * taper
		* (HULL_LENGTH / TILE_REACH)
		+ beam * across_hold * (HULL_WIDTH / TILE_REACH) * HOLD_ACROSS * 0.5 * taper
	)
	var lift := HULL_HEIGHT * (HOLD_LIFT + HOLD_STACK * float(layer))
	# Down with the hull it is stowed in, or the heap floats a pixel over its own deck.
	return Iso.tile_to_world(in_tiles.x, in_tiles.y) + Vector2(0.0, HULL_DROP - lift)


## Which frame shows the boat pointing the way it is pointing: how far round the compass
## the heading is from the first frame's, in frames.
func heading_frame() -> int:
	return frame_heading(heading, _frame_count())


## The frame for a heading in tiles, out of `frames`. Static so something that draws a ferry
## without being one picks its frame by the boat's own rule and never by a number somebody
## read off the sheet.
static func frame_heading(towards: Vector2, frames: int) -> int:
	if frames <= 0:
		return 0
	var turn := atan2(towards.y, towards.x) - FRAME_ZERO_TURN
	return posmod(int(round(turn / TAU * float(frames))), frames)


## The `art_frame` turn (0 to 1) of a ferry sailing `across` **the screen** — the wash
## room's backdrop, whose boats go left and right and have no tiles under them. The screen
## direction is taken back to tiles the way `Iso` lays them out, and then it is
## `frame_heading`'s answer.
static func turn_sailing(across: Vector2) -> float:
	var sheet := _sheet()
	if sheet == null:
		return 0.0
	var count := int(round(float(sheet.get_width()) / float(sheet.get_height())))
	var tiles := Vector2(
		across.x / (Iso.TILE_W * 0.5) + across.y / (Iso.TILE_H * 0.5),
		across.y / (Iso.TILE_H * 0.5) - across.x / (Iso.TILE_W * 0.5)
	)
	return (float(frame_heading(tiles, count)) + 0.5) / float(count)


## The heading, in tiles, of the frame `turn` picks (0 to 1 round the compass) — for laying
## a wake under a frame drawn somewhere other than the lake.
static func turn_heading(turn: float) -> Vector2:
	var sheet := _sheet()
	if sheet == null:
		return Vector2.RIGHT
	var count := int(round(float(sheet.get_width()) / float(sheet.get_height())))
	var index := clampi(int(turn * float(count)), 0, count - 1)
	var angle := FRAME_ZERO_TURN + TAU * float(index) / float(count)
	return Vector2(cos(angle), sin(angle))


## How many headings the sheet holds. Taken from the sheet itself rather than written down
## twice: it is one row of square frames.
func _frame_count() -> int:
	var sheet := _sheet()
	if sheet == null:
		return 0
	return int(round(float(sheet.get_width()) / float(sheet.get_height())))


## One frame of the sheet, for anything that wants a picture of a ferry without being one —
## the shop's board, so far. `turn` runs 0 to 1 round the compass. The region is the box
## round the drawn boat, not the whole frame, so a board fits the boat rather than the air
## round it and can draw it at a whole number of pixels per art pixel; `anchor` is where
## the water meets the hull, in the region's own pixels.
static func art_frame(turn: float) -> Dictionary:
	var sheet := _sheet()
	if sheet == null:
		return {}
	var side := float(sheet.get_height())
	var count := int(round(float(sheet.get_width()) / side))
	var index := clampi(int(turn * float(count)), 0, count - 1)
	var box := _ink_box(sheet, index)
	# Cut along the waterline like the lake draws it, so the board's hull sits in its wake:
	# the region reaches down to the cut's deepest point, and `cut` is the polygon of what
	# is above the water, in the region's own pixels.
	var deepest := 0.0
	for at in cut_line(index):
		deepest = maxf(deepest, at.y)
	var kept := Vector2(float(box.size.x), minf(float(box.end.y), deepest) - float(box.position.y))
	var cut := PackedVector2Array()
	for at in hull_polygon(index):
		cut.append(at - Vector2(box.position))
	return {
		"sheet": sheet,
		"region": Rect2(Vector2(float(index) * side, 0.0) + Vector2(box.position), kept),
		"anchor": _anchor - Vector2(box.position),
		# Where the hull meets the water, left end and right, in the region's own pixels:
		# for a collar laid by something that is not a `HullCollar`.
		"waterline": Vector2(
			cut_line(index)[0].x - float(box.position.x),
			cut_line(index)[cut_line(index).size() - 1].x - float(box.position.x)
		),
		"cut": cut,
	}


## The waterline across a frame, left end and right end in frame pixels, off the sheet's
## json; a level line the hull's length through the anchor when the json is missing.
static func cut_line(index: int) -> PackedVector2Array:
	if index < _cuts.size() and _cuts[index].size() >= 2:
		return _cuts[index]
	return PackedVector2Array([
		_anchor + Vector2(-HULL_IN_FRAME * 0.5, 0.0), _anchor + Vector2(HULL_IN_FRAME * 0.5, 0.0)
	])


## Where the hull meets the water, as a curve in the parent's space: from one end of the
## frame's waterline, round the near side, to the other.
##
## The cut is one level line, so the collar laid straight along it is a bar under the hull —
## a boat leaning on one strip of the lake rather than floating in it (2026-09-12). A hull
## afloat is in the water all the way round, and on this plane the near half of that is an
## arc bowing towards the camera.
##
## The shape is the hull's footprint on the plane, turned with the heading and squashed by
## it, but **scaled so its widest point lands on the frame's own cut** rather than where the
## projection would put it: the frames are not one strict projection — the bow-on rail is six
## rows tall where thirty degrees would make it eighteen — and the load already floated past
## the cut bow once for trusting the projection over the drawing. Fitted, the foam cannot
## leave the hull at any heading.
##
## The far half is not drawn. It would be above the cut on screen, behind the hull that is
## drawn over it, so it is geometry nobody sees.
static func waterline_arc(index: int, scale: float) -> PackedVector2Array:
	var line := cut_line(index)
	var left := (line[0] - _anchor) * scale
	var right := (line[line.size() - 1] - _anchor) * scale
	# The ends of the cut are the arc's ends, so the fit is exact by construction rather than
	# by a ratio worked out from a length the drawing does not agree with.
	var middle := (left + right) * 0.5
	var span := (right - left) * 0.5
	var across := Vector2(-span.y, span.x).normalized() if span.length_squared() > 0.0 		else Vector2.DOWN
	# Towards the camera, which on this plane is down the screen.
	if across.y < 0.0:
		across = -across
	var sag := across * span.length() * COLLAR_BOW
	# Up into the hull, so the band sits in the sprite's own bottom edge rather than hanging
	# under it. In the parent's space, where the scale is already applied, so it is measured
	# in the same pixels the foam's own reach is.
	var lift := Vector2(0.0, -LakeGrid.FOAM_TALL * COLLAR_SCALE * COLLAR_LIFT)
	var out := PackedVector2Array()
	for step in COLLAR_STEPS + 1:
		var u := lerpf(-1.0, 1.0, float(step) / float(COLLAR_STEPS))
		out.append(middle + span * u + sag * (1.0 - u * u) + lift)
	return out


## The part of a frame that is above the water, as a polygon in frame pixels: the frame's
## top edge, then the waterline read back right to left with its ends carried out to the
## frame's sides. Takes a bent line too, should one ever come back.
static func hull_polygon(index: int) -> PackedVector2Array:
	var line := cut_line(index)
	var side := float(FRAME_SIDE)
	var polygon := PackedVector2Array([Vector2(0.0, 0.0), Vector2(side, 0.0)])
	polygon.append(Vector2(side, line[line.size() - 1].y))
	for i in range(line.size() - 2, 0, -1):
		polygon.append(line[i])
	polygon.append(Vector2(0.0, line[0].y))
	return polygon


## The box round the drawn boat in a frame, measured off the sheet once per frame.
static func _ink_box(sheet: Texture2D, index: int) -> Rect2i:
	if _boxes.has(index):
		return _boxes[index]
	var side := sheet.get_height()
	var box := Rect2i(0, 0, side, side)
	var image := sheet.get_image()
	if image != null:
		var used := image.get_region(Rect2i(index * side, 0, side, side)).get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			box = used
	_boxes[index] = box
	return box


## The sheet, loaded once and shared by every hull in the fleet, with its json.
## The sail-only sheet, loaded once for every boat, or null when it has not been built.
static func _sail_over() -> Texture2D:
	if _over_cache == null and not _over_missing:
		if ResourceLoader.exists(SAIL_OVER_PATH):
			_over_cache = load(SAIL_OVER_PATH) as Texture2D
		_over_missing = _over_cache == null
	return _over_cache


static func _sheet() -> Texture2D:
	if _sheet_cache == null and not _sheet_missing:
		if ResourceLoader.exists(FRAMES_PATH):
			_sheet_cache = load(FRAMES_PATH) as Texture2D
		_sheet_missing = _sheet_cache == null
		_read_meta()
	return _sheet_cache


static func _read_meta() -> void:
	_anchor = HULL_ANCHOR
	_cuts = []
	if not FileAccess.file_exists(FRAMES_META):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(FRAMES_META))
	if not parsed is Dictionary:
		return
	if parsed.has("anchor"):
		_anchor = Vector2(float(parsed["anchor"][0]), float(parsed["anchor"][1]))
	if parsed.has("cut"):
		for line in parsed["cut"]:
			var points := PackedVector2Array()
			for pair in line:
				points.append(Vector2(float(pair[0]), float(pair[1])))
			_cuts.append(points)


## Which way the boat points on screen. The tile field is seen at an angle, so a heading of
## one tile east is not a screen vector of one to the right.
func _screen_heading() -> Vector2:
	var on_screen := Iso.tile_to_world(heading.x, heading.y)
	return on_screen.normalized() if on_screen.length_squared() > 0.0001 else Vector2.RIGHT


## The boat's shadow: the sun's, like the angler's, the dog's and the trees' (see Shade).
## The frame above the waterline is drawn a second time in the day's ink, laid out on the
## water away from the sun about the hull's anchor, so it is the shape of the boat on this
## heading — sails and all — and leans and stretches as the day goes. Not the rubbish's
## squashed crescent (LakeGrid.ShadowLayer): that is eighteen thousand shadows that cannot
## afford to follow the sun, and under a hull it was a sliver nobody could see. A child so
## it sits under the collar and the bow wave as well as the hull. Without a day, no shadow.
class HullShade extends Node2D:
	var _sheet: Texture2D
	var _points := PackedVector2Array()
	var _uvs := PackedVector2Array()
	var _day: DayCycle

	func _init() -> void:
		z_index = -2

	## The boat above the water, in the parent's space, with its texture coordinates on the
	## sheet, 0 to 1 — the same polygon the hull is drawn from.
	func lay(sheet: Texture2D, points: PackedVector2Array, uvs: PackedVector2Array, day: DayCycle) -> void:
		_sheet = sheet
		_points = points
		_uvs = uvs
		_day = day
		visible = true
		queue_redraw()

	func _draw() -> void:
		if _sheet == null or _points.is_empty() or _day == null:
			return
		draw_set_transform_matrix(Shade.lying(Vector2.ZERO, _day.lean, _day.stretch))
		var ink := minf(_day.ink * Boat.SHADE_GAIN, Boat.SHADE_MOST)
		draw_polygon(_points, PackedColorArray([Shade.tint(ink)]), _uvs, _sheet)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The foam along the hull's waterline: the lake's collar (foam.gdshader, the rubbish's
## FOAM_RISE over and FOAM_TALL under the line) grown COLLAR_SCALE times for a hull, laid
## along `Boat.waterline_arc` as one strip, its tear and its bubbles scaled with the width so
## the froth is the same grain as on the rubbish beside it. Drawn behind the hull, so its
## tongues show past the sides and its lip lies on the water. No swell in the material: the
## parent bobs.
##
## Not a WaterlineFoam: that is one material shared by every figure, sized for a boot or a
## dog, on one straight edge. A hull is four times as wide, bends round its near end, and
## every heading is a different width, so this owns its material.
class HullCollar extends Node2D:
	## The rubbish collar's own width, which its tear and bubble counts were set for.
	const PIECE_WIDE := 24.0

	var _points := PackedVector2Array()
	var _uvs := PackedVector2Array()
	var _indices := PackedInt32Array()
	var _colors := PackedColorArray()
	var _anchor: Color
	var _skin: ShaderMaterial

	func _init(seed: int) -> void:
		z_index = -1
		var lip := LakeGrid.FOAM_COLOUR
		lip.a = LakeGrid.FOAM_ALPHA
		_skin = ShaderMaterial.new()
		_skin.shader = load("res://shaders/foam.gdshader") as Shader
		_skin.set_shader_parameter("sway", 0.0)
		_skin.set_shader_parameter("wave_amplitude", 0.0)
		_skin.set_shader_parameter("wave_speed", LakeGrid.WAVE_SPEED)
		_skin.set_shader_parameter("anchor_span", LakeGrid.ANCHOR_SPAN)
		_skin.set_shader_parameter("foam", lip)
		Palette.dress_foam(_skin, LakeGrid.FOAM_ALPHA)
		_skin.set_shader_parameter(
			"cut_at", LakeGrid.FOAM_RISE / maxf(LakeGrid.FOAM_RISE + LakeGrid.FOAM_TALL, 0.001)
		)
		_skin.set_shader_parameter("bubble_down", 7.0 * Boat.COLLAR_SCALE)
		# The froth carries further out towards the ends than it does on a piece of rubbish:
		# a ten-pixel collar is a lip that should draw up to nothing quickly, and a hull's
		# length of waterline is in the water at its ends as much as its middle.
		_skin.set_shader_parameter("round_bite", Boat.COLLAR_SIDES)
		material = _skin
		# The anchor only seeds the tear here, so each hull froths its own way.
		_anchor = LakeGrid.pack_anchor(float(seed % 4096) - 2048.0, 0.0, 1.0)

	## The waterline, left to right, in the parent's space: the curve `Boat.waterline_arc`
	## builds, bowing towards the camera round the hull's near side.
	##
	## Built from its points rather than from independent quads, with each point's normal
	## taken from the run either side of it: quads squared up to their own segment leave a
	## notch on the outside of every bend and overlap on the inside, which on a curve this
	## shallow reads as a foam line someone has kinked. The strip's UV runs 0 to 1 over the
	## whole curve, so the shader's rounding off and its tear read it as one collar however
	## many segments it arrived in.
	func lay(line: PackedVector2Array) -> void:
		visible = true
		if line.size() < 2:
			_points = PackedVector2Array()
			queue_redraw()
			return
		# The ends run COLLAR_REACH past the hull, along the curve's own direction there, so
		# the froth spills off the bow and the transom rather than stopping square on them.
		var run := PackedVector2Array(line)
		var head := (run[1] - run[0]).normalized()
		var tail := (run[run.size() - 1] - run[run.size() - 2]).normalized()
		run[0] -= head * Boat.COLLAR_REACH
		run[run.size() - 1] += tail * Boat.COLLAR_REACH

		var total := 0.0
		var along := PackedFloat32Array([0.0])
		for i in run.size() - 1:
			total += run[i].distance_to(run[i + 1])
			along.append(total)
		total = maxf(total, 1.0)

		_points = PackedVector2Array()
		_uvs = PackedVector2Array()
		_indices = PackedInt32Array()
		_colors = PackedColorArray()
		var top := LakeGrid.FOAM_RISE * Boat.COLLAR_SCALE
		var low := LakeGrid.FOAM_TALL * Boat.COLLAR_SCALE
		for i in run.size():
			var back := run[maxi(i - 1, 0)]
			var next := run[mini(i + 1, run.size() - 1)]
			var way := (next - back)
			var out := way.normalized() if way.length_squared() > 0.0 else Vector2.RIGHT
			var side := Vector2(-out.y, out.x)
			var u := along[i] / total
			_points.append_array(PackedVector2Array([run[i] - side * top, run[i] + side * low]))
			_uvs.append_array(PackedVector2Array([Vector2(u, 0.0), Vector2(u, 1.0)]))
			_colors.append_array(PackedColorArray([_anchor, _anchor]))
			if i < run.size() - 1:
				var base := i * 2
				_indices.append_array(PackedInt32Array([
					base, base + 1, base + 3, base, base + 3, base + 2
				]))
		var wide := total / PIECE_WIDE
		_skin.set_shader_parameter("tear_across", 12.0 * wide * Boat.COLLAR_TEAR)
		_skin.set_shader_parameter("bubble_across", 20.0 * wide)
		queue_redraw()

	func _draw() -> void:
		if _points.is_empty():
			return
		RenderingServer.canvas_item_add_triangle_array(
			get_canvas_item(), _indices, _points, _colors, _uvs
		)
