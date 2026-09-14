## The dog.
##
## It lives on the island with the angler and it has one job it gave itself: small rubbish
## floating near the shore is a stick, and a stick has to be brought back. So it swims out,
## takes a piece — or several, once it has been trained to — swims in and drops the lot in
## the yard crate, the same crate the net fills, so a dog's afternoon is worth the same as a
## cast, in smaller change.
##
## The point of it is not the rubbish. The lake is a long quiet job and the dog is the thing
## in it that is pleased to see you: it dozes on the grass, it wanders the beach, it comes
## when the water is worth swimming in, and it can be petted. What it fetches is a reason for
## it to be out there where you can watch it.
##
## Kept in tile coordinates and projected for drawing, like the angler and the boat. There is
## no physics: the island's own edge function says where it may stand, which cannot wedge an
## animal inside geometry the way a collision shape can.
class_name Dog
extends Node2D

const DogArt := preload("res://scripts/dog_art.gd")
const Style := preload("res://scripts/style.gd")

## How tall the standing dog draws, in pixels. Against the angler's 34: a dog that comes up
## to about the knee.
const HEIGHT := 22.0

## Tiles a second, swimming and on land. It swims slower than it runs, and it runs home
## faster than it goes out — a dog carrying something is a dog with a purpose.
const SWIM_SPEED := 2.6
const WALK_SPEED := 2.4
const RUN_SPEED := 6.2

## How far out the dog may walk on the island, as a fraction of its radius, and how close to
## the shed it will settle. Under the angler's own limit, so it stays visibly on the grass.
const LAND_LIMIT := 0.84

## How much of the picture goes under the water while it swims, as a fraction of the frame.
## Enough that the legs and most of the chest are gone and the head and shoulders are not.
const SINK := 0.42

## How far the swimming dog bobs, in pixels, and how fast.
const BOB := 1.6
const BOB_RATE := 3.4

## How far the dog's paws sink into dry ground, in screen pixels. See Angler.LAND_SINK — the
## same idea, scaled down for a much smaller animal.
const LAND_SINK := 2.0

## Sheet pixels of paw hidden in the island's grass. Sand keeps the paws whole.
const GRASS_BURY := 1.0

## How far apart the paw prints land while it is walking on dry ground, in world pixels, and
## how far to the side of the last one the next one sits. See Angler.PRINT_SPACING.
const PRINT_SPACING := 10.0
const PRINT_OFFSET := 1.6

## How far out from the island the dog will go looking, in tiles, and how heavy a piece it
## will bring back. A dog fetches sticks: tier zero, and small enough to get its mouth round.
const REACH := 15.0
const CARRY_TIER := 0
const CARRY_WIDE := 16.0

## The bank run: how often a spell with nothing near to fetch is spent swimming off to the
## outer bank for the rubbish washed up there, how far out along the basin's radius it looks,
## and how long such a trip may run before it counts as stuck. Longer than an ordinary trip,
## because the bank is most of the lake away. See LakeGrid.STRAND_CHANCE.
const STRAND_ODDS := 0.35
const STRAND_AT := Vector2(0.955, 1.06)

## How far up the outer bank's beach the dog may go, in tiles past the waterline — a little
## past the furthest washed-up rubbish, so it can stand over the last piece to pick it up.
const BEACH_WALK := 3.0
const STRAND_TRIP_MOST := 60.0

## How near the target counts as arrived, in tiles.
const CLOSE := 0.35

## How fast the dog changes speed, in tiles a second, per second.
##
## Without it, wading out of the lake was a jump from a swim to a run between one frame and
## the next, which read as the animal being fired out of the water. Everything it does now
## eases into its pace, and the pace it eases towards is what the state asks for.
const ACCEL := 7.0

## The foam where the swimming dog cuts the surface. See WaterlineFoam.
var _foam: WaterlineFoam

## The longest step allowed in one frame, in tiles.
##
## A dropped frame or a window coming back from being minimised hands `_process` a delta of
## whatever it likes, and speed times that is a teleport. The clamp is the same idea as the
## one every mover in this game needs: a slow dog for one frame is a cost nobody sees, a dog
## that appears on the far bank is a bug report.
const STEP_MOST := 0.5

## How long a trip may take before the dog admits something is in the way, in seconds, and
## how long it has to be walking into that thing before it counts as stuck.
const TRIP_MOST := 26.0
const STUCK_TIME := 0.45

## How long the dog may go without getting any nearer to what it is heading for before that
## counts as stuck too, and how much nearer counts as getting nearer.
##
## Being blocked outright is the easy case. The one that actually happened is subtler: a step
## refused, slid along one axis, and then pulled straight back the next frame — every frame
## legal, every frame reported as movement, and the dog rocking on the spot for half a minute
## with a bottle in its mouth. Distance to the target is the only honest measure of progress.
const STALL_TIME := 1.6
const GAIN_LEAST := 0.05

## How far to one side of the crate the dog stands to drop something in, in tiles. The crate
## is about a tile and a third across, so this is far enough not to be drawn standing inside
## the box and near enough to plainly be at it.
const CRATE_SIDE := 1.35

## How long a spell of doing nothing in particular lasts, and the odds it is spent asleep
## rather than mooching about. A dog that never settles reads as a machine on a patrol route.
##
## The top of that window is what `wait_cut` comes off: an untrained dog takes its full ten
## seconds between jobs, and every level of training brings the longest wait down without
## touching the shortest. See `_settle`.
const MOOD_LEAST := 3.0
const MOOD_MOST := 10.0

## How long the dog stays pleased about being petted, and how far the angler can be for the
## button to reach it, in tiles.
const PET_TIME := 2.6
const PET_REACH := 1.9

## How big a carried piece draws against its own size, so a plank in a dog's mouth is a stick
## rather than a plank.
const CARRY_SCALE := 0.6

## How long it waits at the crate before going out again, so a delivery is a visible event
## rather than a bounce off the box.
const DROP_WAIT := 0.8

## The greeting: how long the hearts show when the angler simply walks up, and how long
## before walking up again counts as arriving again.
##
## A greeting rather than a petting — it does not interrupt what the dog is doing, and it
## costs the player nothing. The cooldown is what keeps it from firing over and over while
## somebody stands on the edge of reach and shuffles about.
const GREET_TIME := 1.3
const GREET_AGAIN := 7.0

## Where the hearts go and how big they draw when the dog is petted.
const HEART_RISE := 18.0
const HEART_SIDE := 3.4

enum State { IDLE, WANDER, NAP, LOUNGE, SWIM_OUT, CARRY_BACK, DROPPING, PETTED }

## One piece of rubbish, on its way to the crate. Emitted once per piece: a dog that came
## home with a mouthful fires this several times over one delivery.
signal fetched(def_index: int)

## The dog got some attention. The lake makes the noise; this does not know what a speaker
## is.
signal petted

## Set by lake.gd. Without a grid the dog never fetches — it still lives on the island, which
## is what the shed screen and any test without a lake want.
var grid: LakeGrid
var angler: Angler

## What training has bought, set by lake.gd from the two `dog_*` upgrade tracks. How many
## pieces one trip out may bring back, and how many seconds come off the top of the wait
## between trips. The defaults are an untrained dog, so a Dog with no lake behind it — the
## shed screen, a test — behaves exactly as it did before there were upgrades to buy.
var fetch_most: int = 1
var wait_cut: float = 0.0

## Tree test mode's dog training (see `Lake.tree_mode`). At these defaults the dog is exactly
## the one the constants describe: `reach` is REACH, nothing sends it to the strand first, and
## it swims at its own pace. A tree run sets them from its nodes (Long Leash, Beachcomber).
var reach: float = REACH
## Chance a trip goes to the strand before the near water is even looked at.
var strand_first: float = 0.0
## Pace on strand runs, as a multiple of the ordinary swim and run.
var strand_speed: float = 1.0

## The lake's own splash system, handed over by the level, for the wake the dog leaves when
## it swims. Null until then, and the dog swims the same either way.
var splash: WaterSplash

## The daylight, handed over by the level. Null in the shed screen and in any test without a
## lake, where the dog draws no shadow at all rather than guessing at one.
var day: DayCycle

## The island's trail of footprints, handed over the same way. Null until then, and the dog
## walks the same either way.
var prints: Footprints

## How wide a ring the dog pushes out, and how often one is shed while it is moving. Smaller
## and quicker than the angler's: less dog in the water, and more of it in a hurry.
const WAKE_SPAN := 12.0
const WAKE_EVERY := 0.12

## Where the crate stands, in tile coordinates. Set by lake.gd once the yard has been put
## down. The dog walks to the grass beside it and drops what it is carrying in.
var crate_tile := Vector2(Iso.ISLAND_CENTRE.x + 2.7, Iso.ISLAND_CENTRE.y + 2.7)

## Where the dog is, in tile coordinates, and which way it is turned.
var tile_pos := Vector2(Iso.ISLAND_CENTRE.x - 2.0, Iso.ISLAND_CENTRE.y + 1.6)
var facing_left: bool = false

var _state: int = State.IDLE
var _age: float = 0.0
var _mood_left: float = 0.0
var _target := Vector2.ZERO
## What it has in its mouth, oldest first, at most `fetch_most` of them. Only the last one
## is drawn — see `_draw_stick`.
var _carried := PackedInt32Array()
var _rng := RandomNumberGenerator.new()
var _painted: int = 0

## Bookkeeping for the paw-print trail: where the last mark was drawn from, how far the dog
## has come since, and which paw is due next. See Angler's own copy of the same idea.
var _last_print_pos := Vector2.ZERO
var _dist_since_print: float = 0.0
var _print_left: bool = false

## How fast it is actually going, which chases the speed its state wants; how long it has
## been shoving at something that will not move; how long the current trip has run; and a
## point off to one side it is making for while it gets round whatever that was.
var _speed: float = 0.0
var _stuck: float = 0.0

## The greeting: how long its hearts have left, how long until it may happen again, and
## whether the angler was already within reach last frame. See GREET_TIME.
var _greet: float = 0.0
var _greet_wait: float = 0.0
var _was_near: bool = false

## What it is heading for, the nearest it has got to that, and how long it has been failing
## to get any nearer. See STALL_TIME.
var _aiming := Vector2.INF
var _closest: float = INF
var _no_gain: float = 0.0
var _trip: float = 0.0
var _detour := Vector2.INF

## Whether the trip under way is a bank run, which picks its sticks off the strand line and
## gets the longer time limit. See STRAND_ODDS.
var _to_strand: bool = false

## Which tile each dog in the pack is swimming for, tile index to dog, shared by every dog
## (2026-09-14, the pack): a stick one dog has claimed is skipped by the others' sampling,
## so four dogs do not all swim for the same can and three come home with nothing. Cleared
## when the piece is taken, the trip given up, or the dog settles. Not a lock on the grid:
## the net and the ferry still take what they like, and a dog whose stick went re-aims.
static var claims: Dictionary = {}
## The tile index this dog has claimed, or -1.
var _claim: int = -1


func _ready() -> void:
	_foam = WaterlineFoam.new()
	_foam.name = &"Foam"
	add_child(_foam)
	_rng.randomize()
	_place()
	_last_print_pos = position
	_settle()


## Turn to face along a step, or towards a thing, given in tiles.
##
## The mirroring is a screen question and the walk is a tile one, and those are not the same
## question: the projection is `x - y` across the screen, so a dog going one tile east and
## two tiles south has a positive tile x and is walking left. Comparing tile x alone — which
## is what this did — turned the animal round on every heading between south and east, which
## on an island it circles is a good quarter of the time. `Iso.tile_to_world` would answer
## this too, but only its x is wanted and the y half of it is not free.
func _look_along(gap: Vector2) -> void:
	var across := gap.x - gap.y
	if absf(across) > 0.001:
		facing_left = across < 0.0


## Is the dog near enough to this tile to be petted from it?
func within_reach(of: Vector2) -> bool:
	return tile_pos.distance_to(of) <= PET_REACH


## Somebody said hello. Ignored while the dog is out in the water with a job on — it is a
## dog, not a butler, and it finishes the stick first.
func pet() -> void:
	if _state == State.SWIM_OUT or _state == State.CARRY_BACK:
		return
	_state = State.PETTED
	_age = 0.0
	_mood_left = PET_TIME
	if angler != null:
		_look_along(angler.tile_pos - tile_pos)
	petted.emit()
	queue_redraw()


func _process(delta: float) -> void:
	# One long frame is one slow frame, never a jump. See STEP_MOST.
	delta = minf(delta, 0.1)
	_age += delta
	_mood_left -= delta
	_trip += delta
	_greet = maxf(_greet - delta, 0.0)
	_greet_wait = maxf(_greet_wait - delta, 0.0)
	# Somebody came over. Noticed on the step into reach rather than while they are in it,
	# so it is a hello and not a hum.
	var near := angler != null and within_reach(angler.tile_pos)
	if near and not _was_near and _greet_wait <= 0.0 and _state != State.PETTED:
		_greet = GREET_TIME
		_greet_wait = GREET_AGAIN
	_was_near = near
	match _state:
		State.SWIM_OUT:
			_go_fetch(delta)
		State.CARRY_BACK:
			_come_home(delta)
		State.DROPPING:
			_slow(delta)
			if _mood_left <= 0.0:
				_hand_over()
		State.WANDER:
			if (
				_step_towards(_target, WALK_SPEED, delta)
				or _mood_left <= 0.0
				or _blocked()
			):
				_settle()
		State.PETTED:
			_slow(delta)
			if _mood_left <= 0.0:
				_settle()
		_:
			_slow(delta)
			if _mood_left <= 0.0:
				_settle()
	_wake()
	_place()
	_leave_print()
	_repaint()


## Come to a stop rather than stopping. Standing still is a speed like any other, and a dog
## that reaches a full halt on the frame its mood changes reads as a sprite being switched
## rather than an animal arriving.
func _slow(delta: float) -> void:
	_speed = move_toward(_speed, 0.0, ACCEL * delta)


## Pick what to do next.
##
## Weighted rather than uniform: most of the time the dog is on the island doing dog things,
## and going for a swim is the occasional event that makes the player look up. If there is
## nothing small enough floating within reach the swim simply is not offered, and the roll
## falls through to the land moods.
func _settle() -> void:
	_release()
	_age = 0.0
	_trip = 0.0
	_detour = Vector2.INF
	_fresh_aim()
	_mood_left = _rng.randf_range(MOOD_LEAST, maxf(MOOD_MOST - wait_cut, MOOD_LEAST))
	_to_strand = false
	if _rng.randf() < 0.45:
		var stick := -1
		if strand_first > 0.0 and _rng.randf() < strand_first:
			stick = _find_strand()
			_to_strand = stick >= 0
		if stick < 0:
			stick = _find_stick()
		if stick < 0 and _rng.randf() < STRAND_ODDS:
			stick = _find_strand()
			_to_strand = stick >= 0
		if stick >= 0:
			_aim_at(stick)
			_state = State.SWIM_OUT
			return
	# Afloat with nothing to fetch: swim in. Every mood below is a thing done on grass, and
	# a dog dozing in open water is the kind of picture that gets screenshotted.
	if not _on_land():
		_state = State.WANDER
		_target = _somewhere_on_land()
		return
	var roll := _rng.randf()
	if roll < 0.34:
		_state = State.WANDER
		_target = _somewhere_on_land()
	elif roll < 0.58:
		_state = State.IDLE
	elif roll < 0.82:
		_state = State.NAP
	else:
		_state = State.LOUNGE


## The best tile to go and fetch from, or -1 when there is nothing worth swimming for.
##
## Sampled rather than searched, and then the nearest of what turned up is taken. The lake is
## eight thousand tiles and the dog wants one of them; walking the whole field to rank them
## is work nobody sees, where a few dozen darts finds a stick almost every time there is one
## and costs nothing when there is not.
##
## Nearest to the shed rather than nearest to the dog: the trip that matters is the one back
## with something in its mouth, and the shortest of those keeps the dog in the water the
## player is actually looking at instead of off at the far bank for a minute at a time.
##
## `from_dog` flips that, and only the second and later picks of one trip use it. Measured
## from the shed, the next piece of a mouthful is as likely to be on the far side of the
## island as the near one — and the dog swims at it in a straight line, which walks it up
## the beach, across the grass and into the corner of the shed, where it stood with three
## bottles in its mouth until the trip timed out. Measured from the dog, the rest of the
## trip is the patch of water it is already in.
func _find_stick(from_dog: bool = false) -> int:
	if grid == null or grid.stacks.is_empty():
		return -1
	var best := -1
	var best_gap := INF
	for _try in 40:
		var angle := _rng.randf_range(0.0, TAU)
		var out := Iso.ISLAND_RADIUS.x + _rng.randf_range(1.0, maxf(reach, 1.0))
		var tile := Iso.ISLAND_CENTRE + Vector2(cos(angle), sin(angle) * 0.85) * out
		if not Iso.in_lake(int(tile.x), int(tile.y)):
			continue
		var index := grid.index_of(int(tile.x), int(tile.y))
		if index < 0 or index >= grid.stacks.size():
			continue
		var stack: PackedInt32Array = grid.stacks[index]
		if stack.is_empty():
			continue
		var def := grid.defs[stack[stack.size() - 1]]
		if def.tier > CARRY_TIER or def.size.x > CARRY_WIDE or def.keepsake:
			continue
		if _claimed_by_other(index):
			continue
		var gap := tile.distance_squared_to(tile_pos if from_dog else Iso.ISLAND_CENTRE)
		if gap < best_gap:
			best_gap = gap
			best = index
	return best


## Something washed up on the outer bank to fetch, or -1 if nothing turned up.
##
## Sampled round the bank the way `_find_stick` samples round the island. The first pick of a
## run is the nearest to the island, so the swim out is as short as the bank allows; later
## picks of one trip (`from_dog`) are the nearest to the dog, so a trained dog works along the
## shore it has reached instead of crossing the lake again for each piece.
func _find_strand(from_dog: bool = false) -> int:
	if grid == null or grid.stacks.is_empty():
		return -1
	var best := -1
	var best_gap := INF
	for _try in 60:
		var angle := _rng.randf_range(0.0, TAU)
		if from_dog:
			angle = Iso.basin_angle(tile_pos) + _rng.randf_range(-0.25, 0.25)
		var tile := Iso.basin_point(angle, _rng.randf_range(STRAND_AT.x, STRAND_AT.y))
		if not Iso.on_strand(int(tile.x), int(tile.y)) and not Iso.on_beach(int(tile.x), int(tile.y)):
			continue
		var index := grid.index_of(int(tile.x), int(tile.y))
		var stack: PackedInt32Array = grid.stacks[index]
		if stack.is_empty():
			continue
		var def := grid.defs[stack[stack.size() - 1]]
		if def.tier > CARRY_TIER or def.size.x > CARRY_WIDE or def.keepsake:
			continue
		if _claimed_by_other(index):
			continue
		var gap := tile.distance_squared_to(tile_pos if from_dog else Iso.ISLAND_CENTRE)
		if gap < best_gap:
			best_gap = gap
			best = index
	return best


## Out to the stick. If it has gone — the net took it, or the ferry did — the dog gives up
## and goes back to being a dog rather than swimming to an empty patch of water.
func _go_fetch(delta: float) -> void:
	# Getting round something first, if it is doing that.
	if _detour != Vector2.INF:
		if _step_towards(_detour, _swim_pace(), delta) or _blocked():
			_detour = Vector2.INF
			_fresh_aim()
		return
	# A swim that has gone on this long is a swim towards something unreachable. Head home
	# rather than paddle at it for the rest of the run.
	if _trip > (STRAND_TRIP_MOST if _to_strand else TRIP_MOST):
		_release()
		_state = State.CARRY_BACK
		_trip = 0.0
		return
	var index := grid.index_of(int(_target.x), int(_target.y))
	if (
		index < 0 or index >= grid.stacks.size()
		or (grid.stacks[index] as PackedInt32Array).is_empty()
	):
		# Somebody else got there first — the net, or a ferry running its skimmer. A dog that
		# swam out for a stick does not come back without one if there is another one
		# floating, so it picks the next nearest and carries on.
		var again := _find_strand(true) if _to_strand else _find_stick()
		if again >= 0:
			_aim_at(again)
			return
		_release()
		_state = State.CARRY_BACK
		return
	if not _step_towards(_target, _swim_pace(), delta):
		if _blocked():
			_detour = _way_round(_target)
			_fresh_aim()
			if _detour == Vector2.INF:
				_state = State.CARRY_BACK
		return
	var stack: PackedInt32Array = grid.stacks[index]
	_carried.append(grid.take(index, stack.size() - 1))
	_release()
	_trip = 0.0
	# Room for another and another one floating: the dog stays out and works the water
	# rather than rowing back for each piece. `_find_stick` is the same sampling that
	# started the trip, so the next one is the nearest to the island of what it turns up —
	# a trained dog does a short circuit of the near shore, not a tour of the far bank.
	if _carried.size() < fetch_most:
		var next := _find_strand(true) if _to_strand else _find_stick(true)
		if next >= 0:
			_aim_at(next)
			_fresh_aim()
			return
	_state = State.CARRY_BACK


## The swim out, quicker on a strand run once Beachcomber is trained.
func _swim_pace() -> float:
	return SWIM_SPEED * (strand_speed if _to_strand else 1.0)


## Back to the crate, by way of the shore. Swims while it is over water and runs once it is
## on the grass, which is what the two animations are for.
##
## The trip ends standing next to the crate, and the dog is put exactly there before it drops
## anything: a delivery that happens a step short of the box, because a corner of the shed
## got in the way on the last stride, reads as the dog dropping the thing on the lawn.
func _come_home(delta: float) -> void:
	var landing := _drop_spot()
	var pace := (RUN_SPEED if _on_land() else SWIM_SPEED) * (strand_speed if _to_strand else 1.0)
	if _detour != Vector2.INF:
		if _step_towards(_detour, pace, delta) or _blocked():
			_detour = Vector2.INF
			_fresh_aim()
		return
	if _step_towards(landing, pace, delta):
		# Not snapped onto the spot: `_step_towards` only reports the trip done when the dog
		# is genuinely within CLOSE of it, and shoving it the last third of a tile is a jump
		# on the frame it arrives — small, but the only jump left in the whole animal.
		_look_along(crate_tile - tile_pos)
		_state = State.DROPPING
		_mood_left = DROP_WAIT
		return
	if not _blocked() and _trip <= (STRAND_TRIP_MOST if _to_strand else TRIP_MOST):
		return
	# Something is between the dog and the crate. Try to walk round it; and if there is no
	# way round at all, or the trip has run long enough that something is properly wrong,
	# put the piece down here rather than carry it about for the rest of the run. A dog that
	# drops a bottle on the grass once in a blue moon is a dog; one that stands in a corner
	# holding it forever is a bug.
	_detour = _way_round(landing)
	_fresh_aim()
	if _detour == Vector2.INF or _trip > (STRAND_TRIP_MOST if _to_strand else TRIP_MOST):
		_detour = Vector2.INF
		_state = State.DROPPING
		_mood_left = DROP_WAIT


## Where the dog stands to drop something in: on the grass beside the crate.
##
## Alongside rather than in front. Straight out from the middle of the island puts the dog in
## the water, which is where it just came from and not where a delivery happens; straight in
## puts it behind the box, where it is drawn over the top of it. Either side is grass, level
## with the crate, and clear of it.
func _drop_spot() -> Vector2:
	var out := crate_tile - Iso.ISLAND_CENTRE
	if out.length_squared() < 0.0001:
		out = Vector2(1.0, 1.0)
	out = out.normalized()
	var along := Vector2(-out.y, out.x) * CRATE_SIDE
	for spot: Vector2 in [
		crate_tile + along, crate_tile - along, crate_tile - out * CRATE_SIDE
	]:
		if Iso.on_island_ground(spot) and not Iso.in_shed(spot.x, spot.y, Iso.SHED_KEEP):
			return spot
	return crate_tile


## The sticks go in the crate. An empty mouth still counts as a trip — the dog does not
## know the difference, and neither does the lake, which is handed nothing.
##
## A mouthful goes in as one delivery: every piece is emitted here, on the same frame, and
## the dog leaves after the one DROP_WAIT it always waited. Emptying the mouth piece by
## piece would make a trained dog stand at the box for longer the more it caught, which is
## the wait the other track was bought to get rid of.
func _hand_over() -> void:
	_trip = 0.0
	for i in _carried.size():
		fetched.emit(_carried[i])
	_carried.clear()
	_settle()


## Swim for this tile, and tell the rest of the pack so.
func _aim_at(index: int) -> void:
	_release()
	_claim = index
	claims[index] = self
	_target = Vector2(grid.tile_of(index)) + Vector2(0.5, 0.5)


## Give up the claim, if any.
func _release() -> void:
	if _claim >= 0 and claims.get(_claim) == self:
		claims.erase(_claim)
	_claim = -1


## Is another dog already swimming for this tile?
func _claimed_by_other(index: int) -> bool:
	var who = claims.get(index)
	return who != null and who != self and is_instance_valid(who)


## Walk or swim towards a tile. True the moment it is there.
##
## Three things this has to get right, all of them learned the hard way:
##
## It eases into its pace. `speed` is what the state is asking for, not what the dog is
## doing; the dog's own speed walks towards it at ACCEL. Wading ashore used to swap a swim
## for a run between two frames, which looked like the animal being launched.
##
## It cannot cross the world in one frame. The step is capped at STEP_MOST however long the
## frame was, so a hitch costs a slow moment rather than a teleport.
##
## It goes round things instead of into them. On land the step is checked against the
## island's edge and the shed's footprint; a blocked step is retried along each axis alone,
## which slides along whatever it walked into. Only when both of those fail as well is the
## dog actually stuck, and being stuck is timed rather than acted on at once — one frame of
## nudging a corner is normal, half a second of it is a dog that needs to try something else.
func _step_towards(tile: Vector2, speed: float, delta: float) -> bool:
	# A new destination is a fresh start: the progress it was failing to make towards the old
	# one says nothing about this one.
	if tile.distance_squared_to(_aiming) > 0.01:
		_aiming = tile
		_closest = INF
		_no_gain = 0.0
	var gap := tile - tile_pos
	var out := gap.length()
	if out < _closest - GAIN_LEAST:
		_closest = out
		_no_gain = 0.0
	else:
		_no_gain += delta
	if out <= CLOSE:
		_stuck = 0.0
		_slow(delta)
		return true
	_speed = move_toward(_speed, speed, ACCEL * delta)
	var step := gap.normalized() * minf(_speed * delta, STEP_MOST)
	_look_along(step)
	var wanted := tile_pos + step
	if _may_stand(wanted):
		tile_pos = wanted
		_stuck = 0.0
		return tile_pos.distance_to(tile) <= CLOSE
	# Each axis on its own — but only an axis the dog is actually moving along. A step
	# straight down the screen has no sideways part, and "slide sideways by nothing" is a
	# legal move to nowhere: it succeeds every frame, clears the stuck timer, and leaves the
	# animal treading water for ever while believing it is walking.
	var slide_x := tile_pos + Vector2(step.x, 0.0)
	var slide_y := tile_pos + Vector2(0.0, step.y)
	if absf(step.x) > 0.0005 and _may_stand(slide_x):
		tile_pos = slide_x
		_stuck = 0.0
	elif absf(step.y) > 0.0005 and _may_stand(slide_y):
		tile_pos = slide_y
		_stuck = 0.0
	else:
		# Both ways blocked. Held against the wall rather than reported as arrived: saying
		# "there" here is what used to make the dog take a piece of rubbish from across the
		# lake, or drop one on the lawn a stride short of the crate.
		_stuck += delta
		_speed = 0.0
	return tile_pos.distance_to(tile) <= CLOSE


## Is the dog getting nowhere — either shoving at something solid, or rocking on the spot
## without closing on what it is heading for?
func _blocked() -> bool:
	return _stuck > STUCK_TIME or _no_gain > STALL_TIME


## Clear the going-nowhere bookkeeping, for a caller that has just changed its mind.
func _fresh_aim() -> void:
	_stuck = 0.0
	_no_gain = 0.0
	_closest = INF
	_aiming = Vector2.INF


## Somewhere off to one side to make for while whatever is in the way is got round.
##
## Picked square to the direction the dog was heading and on whichever side it can actually
## stand, so a corner is walked around rather than argued with. Vector2.INF when there is no
## way out at all, which the callers read as "give this trip up".
func _way_round(towards: Vector2) -> Vector2:
	var along := (towards - tile_pos)
	if along.length_squared() < 0.0001:
		along = Vector2(1.0, 0.0)
	along = along.normalized()
	var side := Vector2(-along.y, along.x)
	for out: float in [2.0, 3.5, 5.0]:
		for turn: Vector2 in [side, -side]:
			var spot := tile_pos + turn * out + along * 0.5
			if _may_stand(spot):
				return spot
	return Vector2.INF


## Anywhere the dog may be: open water, or island grass outside the shed.
##
## Asked of the island and the shore as continuous functions, never of the tile the dog
## happens to be standing in. `Iso.in_lake` takes whole tiles, and rounding the dog's own
## position down to one made a ring of squares around the island where the float position was
## water and the whole tile under it was still island — the dog swam up to that ring and
## stopped dead, half a tile short of wherever it was going, for the rest of the run.
func _may_stand(tile: Vector2) -> bool:
	# Round the hut, not through it — and never refused to a dog already standing in it,
	# which would wall the animal in for the rest of the run. The crate has always been
	# handled this way; the shed was not, and a dog that started inside the footprint (an old
	# save, or the hut growing under it) could never leave.
	if Iso.in_shed(tile.x, tile.y, Iso.SHED_KEEP) 			and not Iso.in_shed(tile_pos.x, tile_pos.y, Iso.SHED_KEEP):
		return false
	# Round the crate, not through it; and never refused to a dog already inside, which would
	# wall it in.
	if Yard.covers(crate_tile, tile, Yard.WALK_KEEP) \
			and not Yard.covers(crate_tile, tile_pos, Yard.WALK_KEEP):
		return false
	if Iso.island_fraction(tile.x, tile.y) < 1.0:
		return true
	if Iso.shore_fraction(tile.x, tile.y) < 1.0:
		return true
	# Up the outer bank's beach, as far as the washed-up rubbish goes and a little past it.
	return Iso.on_beach_at(tile, -1.0, BEACH_WALK)


func _on_land() -> bool:
	# The island's drawn edge, not its waterline: the water is seen to start where the shader
	# stops discarding it, and the dog should be swimming exactly where it is seen in water.
	if Iso.on_island_ground(tile_pos):
		return true
	# On the outer bank's sand, once it is past where the water is drawn over it.
	return Iso.on_beach_at(tile_pos, Iso.WATER_LAP_TILES, BEACH_WALK + 1.0)


## Somewhere on the grass to go and sniff.
func _somewhere_on_land() -> Vector2:
	for _try in 20:
		var angle := _rng.randf_range(0.0, TAU)
		var out := sqrt(_rng.randf()) * LAND_LIMIT
		var tile := Iso.ISLAND_CENTRE + Vector2(
			cos(angle) * Iso.ISLAND_RADIUS.x * out, sin(angle) * Iso.ISLAND_RADIUS.y * out
		)
		if _may_stand(tile):
			return tile
	return tile_pos


## A ring of disturbed water behind it, if it is off the island at all.
func _wake() -> void:
	if splash == null or _on_land():
		return
	splash.wake(self, Iso.tile_to_world(tile_pos.x, tile_pos.y), WAKE_SPAN, WAKE_EVERY)


## A paw print in the sand or the grass, every PRINT_SPACING of ground actually covered. See
## Angler._leave_print — the same idea, and for the same reason left out of the water.
func _leave_print() -> void:
	var moved := position.distance_to(_last_print_pos)
	var moved_along := position - _last_print_pos
	_last_print_pos = position
	if prints == null or not _on_land():
		return
	_dist_since_print += moved
	if _dist_since_print < PRINT_SPACING:
		return
	_dist_since_print = 0.0
	_print_left = not _print_left
	if moved_along.length_squared() < 0.0001:
		moved_along = Vector2(-1.0 if facing_left else 1.0, 0.0)
	moved_along = moved_along.normalized()
	var side := Vector2(-moved_along.y, moved_along.x) * PRINT_OFFSET \
		* (1.0 if _print_left else -1.0)
	prints.mark(self, position + side, &"paw")


func _place() -> void:
	position = Iso.tile_to_world(tile_pos.x, tile_pos.y)


## Which animation is showing, worked out from what the dog is doing rather than stored, so
## there is one place a state's picture is decided.
func _showing() -> StringName:
	match _state:
		State.SWIM_OUT, State.CARRY_BACK:
			return &"walk" if not _on_land() else &"run"
		State.WANDER:
			return &"walk"
		State.NAP:
			return &"sleep"
		State.LOUNGE:
			return &"laid"
		_:
			return &"idle"


## The sun, coarsely, for the paint keys. A shadow that swings has to repaint the dog as it
## goes, and quantised because the sun moves a hair a frame and a key that tracked it exactly
## would repaint every frame forever — which is the thing the keys exist to stop.
func _sun_key() -> int:
	return 0 if day == null else roundi(day.lean * 60.0) * 1000 + roundi(day.ink * 200.0)


func _repaint() -> void:
	var name := _showing()
	var key := hash([
		name, DogArt.frame_at(name, _age), facing_left,
		(position * 2.0).round(), not _carried.is_empty(), _state,
		roundi(_greet * 60.0), _sun_key()
	])
	if key != _painted:
		queue_redraw()


func _draw() -> void:
	var name := _showing()
	var frame := DogArt.frame_at(name, _age)
	_painted = hash([
		name, frame, facing_left, (position * 2.0).round(), not _carried.is_empty(), _state,
		roundi(_greet * 60.0), _sun_key()
	])
	if not DogArt.ready():
		if _foam != null:
			_foam.clear()
		_draw_blocked()
		return

	var swimming := not _on_land()
	var at := Vector2.ZERO
	var sink := 0.0
	if swimming:
		# Cut off at the waterline: what is under it is not drawn, so nothing has to be
		# layered over the dog to hide its legs. The body is then pushed down by exactly the
		# amount that was cut, which puts the cut itself on the tile the dog is standing on
		# — so the waterline in the picture is the waterline in the world, and the ring it
		# pushes out can be drawn around the dog rather than under it.
		at.y += sin(_age * BOB_RATE) * BOB + SINK * HEIGHT
		sink = SINK
		_draw_wake(Vector2(0.0, sin(_age * BOB_RATE) * BOB))
		# And the foam on that cut, bobbing with it: the same edge stamp is about to end the
		# picture at, so the collar can never sit beside the dog instead of round it.
		if _foam != null:
			var edge := DogArt.cut_edge(name, frame, at, HEIGHT, facing_left, sink)
			_foam.lay(edge[0], edge[1])
	else:
		if _foam != null:
			_foam.clear()
		at.y += LAND_SINK
		_draw_shadow(name, frame, Vector2(0.0, LAND_SINK))
		# Paws in the grass: the bottom row goes, and the picture moves down by it so the
		# cut sits on the ground line. The shadow above keeps whole paws.
		if Iso.on_lawn(tile_pos):
			var buried := DogArt.bury(name, frame, HEIGHT, GRASS_BURY)
			sink = buried[0]
			at.y += buried[1]

	DogArt.stamp(self, name, frame, at, HEIGHT, facing_left, sink)
	if not _carried.is_empty() and grid != null:
		_draw_stick(at)
	if _state == State.PETTED:
		_draw_hearts(1.0 - clampf(_mood_left / PET_TIME, 0.0, 1.0))
	elif _greet > 0.0:
		_draw_hearts(1.0 - clampf(_greet / GREET_TIME, 0.0, 1.0))


## The ring the swimming dog pushes out. Drawn here rather than through WaterSplash because
## it is a steady thing that follows the animal, not an event with a life of its own.
func _draw_wake(at: Vector2) -> void:
	var ring := PackedVector2Array()
	var wide := HEIGHT * 0.5 + sin(_age * BOB_RATE) * 1.2
	for i in 13:
		var angle := TAU * float(i) / 12.0
		ring.append(at + Vector2(cos(angle) * wide, sin(angle) * wide * 0.42))
	draw_polyline(ring, Color(0.86, 0.94, 0.96, 0.30), 1.3)


## The dog's shadow: its own frame, laid out on the grass away from the sun.
##
## The same `stamp` the animal itself is drawn with, so the shadow is the shape the dog is
## actually making — ears, tail, a leg mid-stride — rather than the ellipse that used to sit
## under it whatever it was doing.
##
## Without a day to ask, no shadow. A guessed sun is worse than none: it would disagree with
## every other shadow in the scene the moment one of them knew better.
func _draw_shadow(name: StringName, frame: int, at: Vector2) -> void:
	if day == null:
		return
	draw_set_transform_matrix(Shade.lying(at, day.lean, day.stretch))
	DogArt.stamp(
		self, name, frame, Vector2.ZERO, HEIGHT, facing_left, 0.0, Shade.tint(day.ink)
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## What it is bringing back, hanging from its mouth. Drawn from the piece's own def, so a dog
## carrying a bottle is carrying a bottle.
##
## Hung off the nose the sheet actually draws rather than off a guess at where the head is,
## and hung *below* it: a dog with something in its mouth carries the weight under its jaw,
## and a piece centred on the face reads as a dog wearing a bottle.
func _draw_stick(at: Vector2) -> void:
	# The last one picked up, whatever else is in there. A dog that swam out three times
	# without coming in carries one visible stick and the rest on trust: five pieces of
	# junk drawn round a twenty-two pixel head is a blob, not a mouthful.
	var held := _carried[_carried.size() - 1] if not _carried.is_empty() else -1
	if held < 0 or held >= grid.defs.size():
		return
	var def: TrashDef = grid.defs[held]
	var hold := at + DogArt.mouth(_showing(), HEIGHT, facing_left)
	hold.y += def.size.y * CARRY_SCALE * 0.4
	draw_set_transform(hold, 0.0, Vector2(CARRY_SCALE, CARRY_SCALE))
	def.stamp(self)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Two small hearts, rising and fading, while the dog is being made a fuss of — or while it
## is saying hello to somebody who has just walked up. `through` is how far through that is,
## nought to one, because the two have their own lengths.
func _draw_hearts(through: float) -> void:
	for i in 2:
		var lift := HEART_RISE * clampf(through * 1.4 - float(i) * 0.35, 0.0, 1.0)
		if lift <= 0.0:
			continue
		var fade := 1.0 - smoothstep(0.6, 1.0, through)
		var at := Vector2(-4.0 + 8.0 * float(i), -HEIGHT - 4.0 - lift)
		var ink := Color(0.95, 0.42, 0.48, fade)
		# A heart at four pixels is two lobes and a point; anything more careful than that
		# is detail nobody can see at this size.
		draw_circle(at + Vector2(-HEART_SIDE * 0.45, 0.0), HEART_SIDE * 0.55, ink)
		draw_circle(at + Vector2(HEART_SIDE * 0.45, 0.0), HEART_SIDE * 0.55, ink)
		draw_colored_polygon(
			PackedVector2Array([
				at + Vector2(-HEART_SIDE, 0.2),
				at + Vector2(HEART_SIDE, 0.2),
				at + Vector2(0.0, HEART_SIDE * 1.5)
			]),
			ink
		)


## The dog as a shape, for a run with no art. Kept for the same reason every other
## placeholder here is: assets/ can be missing and the game still has to run.
func _draw_blocked() -> void:
	var body := Rect2(Vector2(-HEIGHT * 0.5, -HEIGHT * 0.6), Vector2(HEIGHT, HEIGHT * 0.6))
	draw_rect(body, Color(0.88, 0.62, 0.24))
	draw_rect(body, Color(0.11, 0.09, 0.1), false, 1.4)
