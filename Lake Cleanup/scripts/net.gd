## The cast net: the only way rubbish leaves the water.
##
## Press inside your range and the net flies out to that point; keep holding and it comes
## straight back, sweeping everything within its radius toward the island; let go and it
## stops where it is. One press-drag-release is a whole cast — pressing again on a net
## left out on the water carries on reeling it. That is the whole verb, and every net upgrade buys one
## axis of it — how far you can throw, how wide it sweeps, how heavy a piece it can lift,
## how fast it comes back, and how much it can carry in one cast.
##
## No physics, like everything else here. The net is a point in tile space moved along a
## line, and what it catches is a query against the tile field.
##
## The node itself sits at the origin and everything is drawn in world coordinates: the
## net, the line to the rod, and the cluster of junk being dragged are three things at
## different places that have to stay welded together, and giving the node a position
## would mean subtracting it back out three times.
class_name CastNet
extends Node2D

## Emitted when the net reaches the angler with a catch aboard. The lake decides what
## happens to it; the net does not know the yard exists.
signal landed(cargo: PackedInt32Array)

## A piece lifted off the tile field, the moment the mouth closes on it — not when it
## reaches the angler. The water is cleaner the instant the piece is out of it, so the
## lake reads its pollution off this rather than off the haul arriving home.
signal caught(def_index: int)

## A pigeon the net closed on, in world coordinates. Paid for on the spot rather than
## carried home: a bird is not cargo, and it is certainly not going in the yard.
signal caught_bird(at: Vector2)

## A charm the net closed on, as a CharmField.Kind. Like a bird, it never becomes cargo:
## it goes straight to the box on the island the moment the mouth shuts on it.
signal caught_charm(kind: int)

## A lit cast has landed and been left there: where it is, how far it reaches, and what is
## on it. The net itself is already back in the angler's hands by the time this is heard —
## whoever is listening owns the thing on the water now.
signal left_behind(tile: Vector2, radius: float, fire: bool, ice: bool)

enum State { IDLE, FLYING, SETTLED, REELING }

## The two things that can be put on the net itself. Both at once is allowed and is the
## point: a net carrying fire and ice burns what it is already holding still.
enum Charm { FIRE, ICE }

## Tiles per second on the way out. Faster than any reel — the throw is not the part of
## the cast the player is meant to wait through.
const CAST_SPEED := 26.0

## Seconds between the rings a hauled net leaves behind it. Close enough that the trail
## reads as continuous disturbance and far enough apart that the rings can be told from one
## another as they spread.
const DRAG_RIPPLE := 0.13

## How close to the rod counts as home, in tiles.
const HOME_DISTANCE := 0.35

## How far past the swept radius the drawn rim sits, in tiles. Small: the rim is the edge
## of the mesh and the sweep is what the mesh encloses, so anything more than the thickness
## of the twine is the net promising reach it does not have.
const MOUTH_EDGE := 0.15

## How many layers deep a cast works. The net comes down from above: it closes on what is
## floating first, everywhere it can reach, and only then takes what that was sitting on.
## Each layer is a fresh pass over the top of the stacks, never a reach past a piece too
## heavy to lift — a cast cannot pull a bag out from under a fridge.
const SWEEP_LAYERS := 2

## How the net purses as it comes in: over the last `CLOSE_SHARE` of the haul, never less
## than `CLOSE_LEAST` tiles of it.
##
## A share of the throw rather than a fixed distance out. A cast net closes over the length
## of the pull, and the pull is however far it was thrown — so a fixed number of tiles is
## most of a short cast and the tail end of a long one, which is exactly backwards from how
## it reads. A net that snapped shut in the last stride would be a net doing it for the look
## of the thing.
##
## The sweep closes with it. The drawn mouth is the promise and the swept radius is what is
## kept, and the two have to be one number or the net is lying again — so a cast does its
## catching out on the water and comes home holding what it has, which is also the honest
## way round for the player: reel from where the junk is, not from your feet.
const CLOSE_SHARE := 0.85
const CLOSE_LEAST := 3.0

## Where it is finished, in tiles from the rod. Short of the rod itself rather than at it:
## a purse that only completes at the moment the net lands is a purse whose last frame is
## never seen. This leaves the net hanging shut for the last stride of the haul, which is
## the picture the whole sequence was drawn for.
const CLOSE_END := 1.4

## How much a full hold drags its heels, as extra curve on the way shut. Junk is what stops
## a purse pulling tight: a bag with six fridges in it comes in fat and gathers late, and an
## empty one draws in from the off. Gentle, because it is a lag and not a wall — too much of
## it and a loaded net spends the whole haul in its first frame.
##
## A curve rather than a ceiling. Capping how far a loaded net could close was the obvious
## way to do it and the wrong one — it stopped the animation as well as the sweep, so with
## anything in the hold the last frames could not be reached at all. This way a loaded net
## shrinks less over the whole haul, which is the point, and still shuts at the end, which
## it has to: a net does not land still open.
const LOAD_LAG := 1.3

## How big the net is drawn by the time it reaches the rod, against its size out on the
## water. Perspective, roughly: the lake is seen from a way up and a long way off, and a net
## eight feet across is a reasonable thing to be lying on the water out there and an absurd
## thing to be dangling off the end of a rod next to a person half its height.
##
## It is only the drawing. The swept radius is not touched — and it does not need to be,
## because by the time this bites the net is a bag hanging clear of the surface, and a rim
## on the water is not a promise a net out of the water is making.
const HOME_SIZE := 0.42

## How much of a cast, as a fraction, is the throw rather than the haul. Only `cast_progress`
## uses it, and only the camera uses that.
const THROW_SHARE := 0.34

## Only for the blocked-in net drawn when the art is missing: how much of its width is left
## once it is shut. With the sheets loaded this comes off the drawing instead.
const CLOSE_TO := 0.3

## How much tighter than the mouth itself the catch bunches as it shuts. Past the shrinking
## of the mouth, so a full net arrives as a knot of junk rather than a scale model of the
## same spread.
const CLOSE_BUNCH := 0.55

## The haul does not use the drag sheet.
##
## Those frames are pictures of a bag held up out of the water on a line, drawn for a game
## looking at a net from the side. Every way of laying them down — flattening them, spreading
## them, shearing them over, capping how tall they are drawn, hanging them from somewhere
## other than their rim — is a way of arguing with what the picture is of, and the net went
## on rising out of the lake as it was pulled. So the haul keeps the net the cast landed:
## the flat one lying on the water, closing by getting smaller. It is the pose the player
## has been looking at since the splash, and it is the only one that is in the lake.
##
## The sheet is still loaded and still cut. `art_sheet` lends it out, and a hauled net is
## one animation away from wanting it again.

## The drawn net. Cut from the two sheets by tools/slice_net.gd, which also measures each
## frame's rim — where the drawing is widest — because that is the line that belongs on the
## water and the width the sweep is scaled against.
const ART := "res://assets/net_frames.json"

## Which frame of each sequence is the net lying fully open on the water, and how much the
## frame is squashed towards the plane at each end of the sequence.
##
## Every other frame is measured against the open one, so a frame carries how wide it is as
## a fraction of its own sequence's open net rather than as pixels of whichever sheet it was
## drawn on — which is what lets the drag borrow its first frame from the landing.
##
## The squash is the drag's alone. Its later frames are drawn as a bag hanging off a line,
## which is what a net looks like lifted out of the water by a crane and not what one looks
## like being pulled across it. Flattening them as they close lays the bag back down on the
## surface: the rim stays where it was, and the body of the net comes down onto the plane
## with it. The landing and the throws were drawn already foreshortened and are left alone.
const SEQUENCES := {
	&"cast_far": {"open": -1, "flatten": [1.0, 1.0]},
	&"cast_near": {"open": -1, "flatten": [1.0, 1.0]},
	&"land": {"open": -1, "flatten": [1.0, 1.0]},
	&"drag": {"open": 0, "flatten": [1.0, 1.0]},
}

## Past this fraction of the rod's reach, a throw is a far one and uses the long sequence.
const FAR_THROW := 0.55

## How long the landing sequence takes to play, in seconds. It runs once and holds.
const LAND_TIME := 0.34

## How far up into the bag the catch is gathered as the net shuts, as a fraction of the
## drawn frame's height, and how much of it still shows through the mesh at the end.
##
## Up, not down. The frame hangs from its rim, and on a closed bag the rim is the ring of
## weights at the bottom — so anything pushed below that point is under the net rather than
## in it, which is what the clutch used to do. The inside of the bag is the tube above the
## weights, and that is where a load of junk actually sits.
const CATCH_INSIDE := 0.16
const CATCH_HIDDEN := 0.5

## How tightly the catch bunches in the mouth, as a fraction of it. Under 1 so the load
## reads as a clutch of junk gathered into the middle of the mesh rather than a ring of
## pieces pinned round the rim.
const CATCH_SPREAD := 0.62

## How high the pile of catch may stand out of the mouth, as a fraction of the mouth's own
## width, and how many pieces sit in one layer of it.
##
## A cap rather than a step per piece. Stacking a fixed distance per row is fine for the
## three pieces the starting net holds and turns a full late-game haul into a tower of junk
## standing a net and a half above the water, which reads as a pile the net is under rather
## than a load it is carrying. Capping the rise means a bigger haul packs tighter instead of
## climbing, which is what a bag of rubbish actually does.
const CATCH_RISE := 0.34
const CATCH_LAYER := 3

## How big a piece in the mouth is drawn, and the least it shrinks to when the net is full.
##
## The catch has to fit in the mouth it is drawn in, and the mouth does not grow with the
## haul — the hold does. Shrinking the pieces a little as the load grows is what keeps a
## full net looking like a full net rather than like a heap with a net somewhere under it.
const CATCH_SCALE := 0.7
const CATCH_PACKED := 0.62

## How far a throw steps while looking for the first place along it that a cast stops being
## legal, in tiles. `_reach_along` walks in these, and the aiming marker is what it feeds.
const RING_STEP := 0.2

## The aiming marker: what a throw at the pointer would look like before it is thrown.
##
## Three readings, on two axes. Whether the throw is allowed at all is the line: solid for a
## legal cast, dashed for one the rod refuses — too far, or over the island. Whether the
## throw is worth making is the colour: green over water with something in it, red over water
## with nothing the net could lift. A refused throw gets no colour, because a verdict on a
## cast that cannot happen is noise.
const AIM_OK := Color(0.35, 0.85, 0.45)
const AIM_NO := Color(0.92, 0.25, 0.22)
const AIM_FAR := Color(0.93, 0.94, 0.91)

## How solid each of those reads. The verdict colours carry the whole point of the marker, so
## they sit well above the pale ghost this used to be.
const AIM_ALPHA := 0.8
const AIM_FAR_ALPHA := 0.55

## Set from the lake's upgrade levels at cast time, so a cast runs on the numbers the
## player had when they paid for them.
##
## The width is a real distance in tiles rather than a count of rings. A whole-numbered
## radius steps the mouth from one tile straight to five and then to thirteen, which on
## screen is a cast that doubles in size every purchase; a fraction of a tile buys a
## noticeably wider mesh without ever swallowing the view.
var radius: float = 0.7
var power: int = 0
var range_tiles: float = 6.0
var reel_speed: float = 3.0
var hold: int = 3

## Wired up by lake.gd. The net reads the tile field directly rather than asking the lake
## to fetch for it — it is the thing doing the catching.
var grid: LakeGrid
var splash: WaterSplash
## The noises. Optional — a net with no sound board still fishes.
var sfx: Sfx
var angler: Angler
## The birds. Optional — with no flock the net simply catches rubbish.
var flock: Flock

## The charms floating on the water, when there are any. Null in the first lake, which is
## what keeps every charm-shaped branch below out of that game entirely.
var charms: CharmField

## Seconds of fire and of ice left on the net, indexed by Charm. Two independent clocks
## rather than one enchantment slot: catching ice while the net is already burning should
## give a net that does both, not a net that has forgotten how to burn.
var charm_left := PackedFloat32Array([0.0, 0.0])

var state: int = State.IDLE
## Where the net is, in tile coordinates, and where it is heading while flying.
var tile_pos := Vector2.ZERO
var target := Vector2.ZERO
## Def indices caught this cast, dragged in behind the net.
var catch := PackedInt32Array()

## Whether the net is allowed to reel. A thrown net pulls itself in, so this is true for
## the whole of an ordinary cast — what turns it off is the game being paused over the
## water: a panel opened mid-drag stops the net where it is and lets it go again when the
## panel closes.
var _pulling: bool = true
var _time: float = 0.0

## Fixed seed, reset every draw, so the catch scatters the same way from one frame to the
## next. A load that reshuffles itself sixty times a second is a load that is boiling.
var _scatter := RandomNumberGenerator.new()

## The cut sheet, and each sequence as `{frames, open}` — its frames in playing order and
## the rim width of whichever of them is the net fully open. Empty when the art is missing,
## which is what drops the whole node back to drawing the net as an ellipse.
var _sheet: Texture2D
var _art := {}

## Where a cast started and how far it had to go, so the throw can be animated against how
## much of it is left. Set when it is thrown, the way the flock does for a bird in flight.
var _cast_from := Vector2.ZERO
var _cast_span: float = 1.0

## How long the net has been down, for the landing sequence.
var _settled_age: float = 0.0

## Where the pointer, the angler and the charm were when the idle picture was last painted.
## See `_repaint`.
var _aim_was := Vector2.INF
var _idle_was := Vector2.INF
var _lit_was := false

## How far the net is pursed, 0 wide open and 1 drawn in, and how near the rod it has come
## on the same scale. Worked out once a frame and kept here, because the drawing, the swept
## radius and the wash the lake plays all ask for them and have to get the same answer.
##
## They are held rather than recomputed when the player stops pulling. A net let go of
## halfway in is a net sitting half gathered on the water — it does not spring back open,
## and it certainly does not spring back to the size it was thrown at. Both are cleared by
## the next cast, which is the thing that really does open it again.
var shut: float = 0.0
var near: float = 0.0


## The rope, on a layer of its own.
##
## Drawn by this node it was under the net sprite (which is drawn last, over the catch) and
## under the angler (z 9 against this node's 8) — so it vanished into the bag. On its own child
## it is always drawn after the net, and still under the figure, which hides where it starts.
class RopeLayer extends Node2D:
	var line := PackedVector2Array()

	func _draw() -> void:
		if line.size() >= 2:
			CastNet._draw_rope(self, line)


var _rope: RopeLayer


func _ready() -> void:
	position = Vector2.ZERO
	if angler != null:
		tile_pos = angler.tile_pos
	_rope = RopeLayer.new()
	_rope.name = &"Rope"
	_rope.z_as_relative = false
	add_child(_rope)
	_load_art()


## Read the cut sheets. False means no art, and every drawing below falls back to the
## blocked-in ellipse the net was before there were any pictures of one — the same bargain
## the flock strikes with its own sheet.
func _load_art() -> bool:
	var text := FileAccess.get_file_as_string(ART)
	if text.is_empty():
		return false
	var book: Dictionary = JSON.parse_string(text)
	if book == null or not book.has("sequences"):
		return false
	_sheet = Art.texture(book["sheet"])
	if _sheet == null:
		return false

	for name: String in book["sequences"]:
		if not SEQUENCES.has(StringName(name)):
			continue
		var frames: Array = []
		for cell: Dictionary in book["sequences"][name]:
			var box: Array = cell["region"]
			var region := Rect2(
				float(box[0]), float(box[1]), float(box[2]), float(box[3])
			)
			frames.append({
				"region": region,
				"rim": float(cell["rim_width"]),
				# Where in its own box the rim sits, as a fraction of the height. The net
				# hangs from this: on a bag pulled shut it is down at the knot, and on a
				# circle seen from above it is across the middle.
				"hang": (float(cell["rim_y"]) - region.position.y) / maxf(region.size.y, 1.0),
			})
		if frames.is_empty():
			continue
		# How wide each frame is against its own sequence's open net. Once a frame carries
		# that, it can be drawn at the right size next to a frame off the other sheet, which
		# is drawn at a different scale entirely.
		var open := float(
			(frames[int(SEQUENCES[StringName(name)]["open"])] as Dictionary)["rim"]
		)
		for frame: Dictionary in frames:
			frame["ratio"] = float(frame["rim"]) / maxf(open, 1.0)
		_art[StringName(name)] = {"frames": frames}

	_compose_drag()
	return not _art.is_empty()


## Start the haul from the net as it lies on the water, not from the drawing of a perfect
## circle.
##
## The drag sheet opens with the net seen from straight above, which is a fine picture and
## the wrong one here: the game is looking at the lake from the side, and the frame the
## player has been staring at since the cast landed is the flat one at the end of the
## landing. Beginning the pull on anything else is a jump. So the drag plays the landed net
## first and picks the sheet up from its second frame, where the mouth has started to lift.
func _compose_drag() -> void:
	if not _art.has(&"drag") or not _art.has(&"land"):
		return
	var land: Array = (_art[&"land"] as Dictionary)["frames"]
	var drag: Array = (_art[&"drag"] as Dictionary)["frames"]
	if drag.size() < 2 or land.is_empty():
		return
	var made: Array = [land[land.size() - 1]]
	for i in range(1, drag.size()):
		made.append(drag[i])
	(_art[&"drag"] as Dictionary)["frames"] = made


## Space left in this cast. The lake also caps this against the yard, so a full yard stops
## the net catching rather than throwing the catch away.
func room_left() -> int:
	return maxi(hold - catch.size(), 0)


## Put fire or ice on the net for a while. Extends whichever clock it names and leaves the
## other one alone.
func enchant(which: int, seconds: float) -> void:
	if which < 0 or which >= charm_left.size():
		return
	charm_left[which] = maxf(charm_left[which], 0.0) + seconds
	queue_redraw()


## Seconds left of one enchantment.
func charm_for(which: int) -> float:
	if which < 0 or which >= charm_left.size():
		return 0.0
	return maxf(charm_left[which], 0.0)


## How far a laid net's fire or ice reaches, in tiles.
##
## A fixed patch of water, and a small one. It was a multiple of the net's own mouth, which
## made it grow with every width upgrade until a single cast covered most of the basin and
## there was nothing to decide — a weapon that lands everywhere is not placed, it is just
## switched on. Fixed and small means the player picks the spot: across the mouth of the
## channel the swarm is using, or in front of the shed, or nowhere useful.
##
## It does not scale with net width on purpose. Width is how much rubbish a cast gathers,
## and buying a bigger scoop should not quietly turn the map off.
const FIELD_TILES := 1.7


func field_radius() -> float:
	return FIELD_TILES


## Is anything on the net? While this is true the cast is placed rather than dragged: it
## flies out, lands, and stays where it landed doing its work until it is thrown somewhere
## else. Nothing about that is a mode the player has to select — it is what having a lit
## net means.
func enchanted() -> bool:
	return charm_left[Charm.FIRE] > 0.0 or charm_left[Charm.ICE] > 0.0


## Is this world point a legal cast? Inside the range ring, and on the lake rather than on
## the island or the bank — a net thrown onto dry land is not a mistake worth simulating.
func can_cast_to(where: Vector2) -> bool:
	if state != State.IDLE or angler == null:
		return false
	var tile := Iso.world_to_tile(where)
	if tile.distance_to(angler.tile_pos) > range_tiles:
		return false
	if Iso.island_fraction(tile.x, tile.y) < 1.0:
		return false
	return Iso.shore_fraction(tile.x, tile.y) < 1.0


## Throw the net.
##
## `laying` is the difference between the two things a lit net can do. An ordinary cast is
## an ordinary cast whatever is burning on the twine: it goes out, it drags, it comes home
## with what it caught. A laying cast is the one that gets left behind. Keeping them on
## separate buttons is what stops fire and ice taking the game away from the player for
## twelve seconds at a time — the lake still has to be cleaned during a fight, and it is the
## only thing paying for the fight.
func cast_to(where: Vector2, laying: bool = false) -> bool:
	if not can_cast_to(where):
		return false
	# Laying is not throwing. There is no flight to watch and nothing coming back, so the
	# net goes down where it was asked for and the angler never leaves the rod alone: the
	# animation belongs to the cast that drags, and playing it here only delayed the thing
	# the player clicked for.
	if laying and enchanted():
		target = Iso.world_to_tile(where)
		tile_pos = target
		_leave_it_there()
		return true
	target = Iso.world_to_tile(where)
	# From the rod, not from wherever the net happens to be lying. An idle net rides the
	# angler, so for an ordinary cast these are the same point; for a lit net being thrown
	# on from where it settled, the rod is the one the throw is measured from.
	_cast_from = angler.tile_pos
	_cast_span = maxf(_cast_from.distance_to(target), 0.001)
	shut = 0.0
	near = 0.0
	tile_pos = angler.tile_pos
	catch.resize(0)
	# The angler's own throw — a no-op on the first sheet, and on the second sheet only ever
	# a flourish: the net still flies on this same line at this same speed either way, see
	# Angler.start_cast().
	angler.start_cast()
	# A cast is one gesture from the throw to the catch coming out of the water. Nothing
	# has to be held down for the second half of it.
	_pulling = true
	state = State.FLYING
	return true


## Stop the net where it is, or let it carry on. Not the throw button any more — the net
## reels itself — but the pause the panels and the endings put on it, and the second click
## that starts a net the player deliberately left sitting.
func set_pulling(pulling: bool) -> void:
	_pulling = pulling
	if pulling and state == State.SETTLED:
		state = State.REELING
	elif not pulling and state == State.REELING:
		state = State.SETTLED


## Where the net is on screen, bobbing on the same swell as everything else afloat.
func world_pos() -> Vector2:
	var at := Iso.tile_to_world(tile_pos.x, tile_pos.y)
	at.y += LakeGrid._swell(at.x, _time * LakeGrid.WAVE_SPEED) * LakeGrid.WAVE_AMPLITUDE
	return at


func _process(delta: float) -> void:
	_time += delta
	_burn_down(delta)
	if state == State.SETTLED or state == State.REELING:
		_settled_age += delta
	# Before the sweep, so what is caught this frame is caught by a net as shut as the one
	# that will be drawn at the end of it.
	match state:
		State.REELING:
			near = _home()
			shut = _purse()
		State.SETTLED:
			pass
		_:
			near = 0.0
			shut = 0.0
	match state:
		State.FLYING:
			_advance_towards(target, CAST_SPEED, delta)
			if tile_pos.distance_to(target) < 0.05:
				tile_pos = target
				# The cast is one gesture: it starts coming back the moment it lands. Only
				# a pause put on the net from outside — a panel over the water — leaves it
				# sitting there instead.
				state = State.REELING if _pulling else State.SETTLED
				_settled_age = 0.0
				if splash != null:
					splash.splash(world_pos(), 0.45)
					# The ring the landing pushes out, on top of the crown's own: this is
					# the one that is still spreading a second later.
					splash.ripple(world_pos(), mouth_extent() * 1.2)
				if sfx != null:
					sfx.play_splash(0.45)
		State.REELING:
			_advance_towards(angler.tile_pos, reel_speed, delta)
			_sweep()
			# Dragged, not carried: the water it is pulled through keeps letting go of it.
			if splash != null:
				splash.wake(self, world_pos(), mouth_extent() * 0.85, DRAG_RIPPLE)
			if tile_pos.distance_to(angler.tile_pos) < HOME_DISTANCE:
				_come_home()
		State.SETTLED:
			pass
		_:
			# Idle rides along with the angler, so the range ring and the stowed net are
			# always drawn where they are actually thrown from.
			if angler != null:
				tile_pos = angler.tile_pos
	_repaint()


## Ask for a repaint, but not while the idle picture is standing still.
##
## Every other state animates — the net flies, the mouth shuts, the catch rides up the line
## — so those redraw every frame and should. Idle draws a range ring round the angler and a
## ghost mouth under the pointer, and neither of those moves unless the angler or the mouse
## does. Standing on the dock deciding where to cast is the most common thing in the game,
## and it used to repaint the ring sixty times a second.
func _repaint() -> void:
	if state == State.IDLE:
		var aim := get_global_mouse_position()
		var lit := enchanted()
		if (
			aim.is_equal_approx(_aim_was)
			and tile_pos.is_equal_approx(_idle_was)
			and lit == _lit_was
		):
			return
		_aim_was = aim
		_idle_was = tile_pos
		_lit_was = lit
	queue_redraw()


## Put a lit net down and stand back up with an empty one.
##
## The whole of "the net is left where it was cast". What is on the water afterwards is not
## this node's business — it is a thing the siege owns and draws — and this one is free to
## be used again on the next click.
func _leave_it_there() -> void:
	var where := tile_pos
	if splash != null:
		# Sized to the patch that is about to start burning rather than to the net's mouth:
		# the water reacts to what was put down, and what was put down is a field.
		splash.splash(world_pos(), 0.45)
		splash.ripple(world_pos(), Iso.tile_circle_extent(field_radius()))
	if sfx != null:
		sfx.play_splash(0.45)
	state = State.IDLE
	# The net stays out there, but the angler is done with it — stop the looping throw.
	if angler != null:
		angler.end_cast()
	_settled_age = 0.0
	shut = 0.0
	near = 0.0
	catch.resize(0)
	tile_pos = angler.tile_pos
	left_behind.emit(
		where, field_radius(), charm_left[Charm.FIRE] > 0.0, charm_left[Charm.ICE] > 0.0
	)


## The enchantments burning down.
func _burn_down(delta: float) -> void:
	var was := enchanted()
	for which in charm_left.size():
		if charm_left[which] > 0.0:
			charm_left[which] = maxf(charm_left[which] - delta, 0.0)
	if was and not enchanted():
		queue_redraw()


func _advance_towards(to: Vector2, speed: float, delta: float) -> void:
	var gap := to - tile_pos
	var step := speed * delta
	if gap.length() <= step:
		tile_pos = to
		return
	tile_pos += gap.normalized() * step


## One frame of sweeping.
##
## Three passes over the same tiles, in the order a net actually closes. The birds sitting
## on the water go first, because a bird is on top of everything by definition and costs
## the cast nothing. Then everything floating, across the whole width of the mouth. Only
## once there is nothing left on the surface does it bite into what is underneath — which
## is what makes a cast read as scooping a patch clean rather than picking one thing off
## each tile it crosses and leaving the patch looking untouched.
##
## Nearest first within each pass, so the mouth closes from the middle out.
func _sweep() -> void:
	if grid == null:
		return
	var here := grid.tile_at(Iso.tile_to_world(tile_pos.x, tile_pos.y))
	if here < 0:
		return
	var reach := _sorted_reach(here)

	# Every bird sat inside the mouth, without exception: a perched pigeon is on top of
	# everything, the hold has no say in it, and one left bobbing inside the ring the player
	# just closed reads as the net passing through it.
	if flock != null:
		for perched in flock.perched_near(tile_pos, sweep_radius()):
			caught_bird.emit(flock.take(perched))

	# Charms, on the same terms as the birds: on top of everything, free to lift, and gone
	# from the water the instant the mouth passes over them. They are the whole reason the
	# second lake is worth casting into, so nothing about the net's strength or its hold
	# gets a say in whether one is picked up.
	if charms != null:
		for index in reach:
			var floating := charms.charm_on(index)
			if floating >= 0:
				var kind := charms.take(floating)
				if splash != null:
					splash.splash(_within_mouth(grid.surface_pos(index)), 0.4)
				if sfx != null:
					sfx.play_catch()
				caught_charm.emit(kind)

	# Only the rubbish is limited by what the net can hold. A bird and a charm are lifted
	# off the surface by a net that is already full, which is why the hold is not checked
	# until here: a cast that swept over a charm and left it floating because it had three
	# lumps of tar in it would read as the net being broken.
	if room_left() <= 0:
		return
	for layer in SWEEP_LAYERS:
		_take_from(reach)


## The tiles the mouth covers, nearest to the net first. Sorted on tile-space distance from
## where the net actually is rather than from the tile it is standing on, so the order does
## not jump as the net crosses a tile edge.
func _sorted_reach(here: int) -> Array[int]:
	var out: Array[int] = []
	for index in grid.tiles_within(here, sweep_radius()):
		out.append(index)
	var from := tile_pos
	out.sort_custom(
		func(a: int, b: int) -> bool:
			return (
				Vector2(grid.tile_of(a)).distance_squared_to(from)
				< Vector2(grid.tile_of(b)).distance_squared_to(from)
			)
	)
	return out


## One layer: every tile in turn gives up whatever is on top of it, if the net is strong
## enough to lift it and there is room left in the cast.
func _take_from(reach: Array[int]) -> void:
	for index in reach:
		if room_left() <= 0:
			return
		var k := grid.reachable_slot(index, 1, power)
		if k < 0:
			continue
		var at := grid.surface_pos(index)
		var def := grid.def_at(index, k)
		var taken := grid.take(index, k)
		catch.append(taken)
		caught.emit(taken)
		var weight := clampf(0.2 + def.size.x / 40.0, 0.0, 0.85)
		if splash != null:
			# Inside the mouth, always. A piece's drawn position carries the drift it was
			# scattered with, and a crown of water blooming outside the ring the player is
			# holding reads as the net catching things it visibly did not touch.
			splash.splash(_within_mouth(at), weight)
		if sfx != null:
			sfx.play_splash(weight)
			sfx.play_catch()


func _come_home() -> void:
	state = State.IDLE
	tile_pos = angler.tile_pos
	angler.end_cast()
	var lot := catch.duplicate()
	catch.resize(0)
	if not lot.is_empty():
		landed.emit(lot)


## How shut the net is, 0 wide open and 1 drawn in.
func closed() -> float:
	return shut


## Work it out: only on the way home, because a cast flies out and sits open and it is the
## pull that closes it.
func _purse() -> float:
	# Bent by what it is carrying, so a laden net holds its width most of the way and
	# gathers late. Measured against what the cast could hold, so full is full whether the
	# hold is three pieces or eleven.
	var load := clampf(float(catch.size()) / maxf(float(hold), 1.0), 0.0, 1.0)
	return pow(_home(), 1.0 + LOAD_LAG * load)


## How far through the last stretch of the haul the net is, 0 out on the water and 1 at the
## rod. Distance only — what the net is carrying bends how far it has pursed, but not how
## near it has got, and the drawing's own size follows the second of those.
func _home() -> float:
	if state != State.REELING or angler == null:
		return 0.0
	var gap := tile_pos.distance_to(angler.tile_pos)
	# Measured against the throw, so the mouth starts drawing in at the same point of every
	# haul rather than at the same distance from the angler's boots.
	var from := maxf(_cast_span * CLOSE_SHARE, maxf(CLOSE_LEAST, CLOSE_END + 1.0))
	var t := clampf((from - gap) / maxf(from - CLOSE_END, 0.001), 0.0, 1.0)
	# Eased, so nothing starts happening on a corner.
	return t * t * (3.0 - 2.0 * t)


## The radius the sweep is actually run at, in tiles: the net's width, less however far it
## has pursed shut.
##
## With the art loaded the shrink is read off the drawing rather than guessed. Each drag
## frame's rim was measured against the open net's, so the water the net closes over closes
## at exactly the rate the picture of it does — snapped to the frame on screen, not eased
## past it, because the whole point is that the two are the same thing.
func sweep_radius() -> float:
	return radius * _purse_scale()


## How wide the net is against its open self, from how far it has pursed. The sweep and the
## drawing both go through this, which is what keeps the ring the player is holding and the
## net they can see the same size.
func _purse_scale() -> float:
	return lerpf(1.0, CLOSE_TO, shut)


## The cut sheet, and one frame off it, for anything else that wants to draw a net.
##
## The ferry's skimmer is a net too, and it was a green quadrilateral. Lending it these
## rather than giving it a loader of its own keeps one catalogue and one texture: there is
## no second net in this game, only a second thing dragging one.
func art_sheet() -> Texture2D:
	return _sheet


## A frame by name and index, or an empty dictionary if there is no art. A negative index
## counts back from the end, so "the open one" is -1 without the caller counting frames.
func art_frame(name: StringName, index: int) -> Dictionary:
	if not _art.has(name):
		return {}
	var frames: Array = (_art[name] as Dictionary)["frames"]
	return frames[posmod(index, frames.size())]


## How far through a whole cast the net is: 0 as it leaves the rod, 1 as it comes back to
## it. One number for the gesture rather than one per state, because the camera wants to
## push in across the lot of it and does not care which half it is watching.
##
## The throw is worth a third of it and the haul the rest. A cast flies out in a moment and
## comes back over several seconds, so splitting it evenly would spend most of the push on
## the part that is already over.
func cast_progress() -> float:
	match state:
		State.FLYING:
			return THROW_SHARE * clampf(
				_cast_from.distance_to(tile_pos) / _cast_span, 0.0, 1.0
			)
		State.SETTLED, State.REELING:
			# Off the held reading, so letting go of the button does not throw the camera
			# back out to where the cast started.
			return THROW_SHARE + (1.0 - THROW_SHARE) * near
	return 0.0


## Which frame of a sequence is showing, for `through` running 0 to 1 across it.
func _frame_at(name: StringName, through: float) -> int:
	var frames: Array = (_art[name] as Dictionary)["frames"]
	return clampi(int(through * float(frames.size())), 0, frames.size() - 1)


## The sequence the net is in and how far through it is, or an empty name when there is
## nothing to draw — the net stowed, or no art to draw it with.
func _pose() -> Array:
	if _art.is_empty():
		return [&"", 0.0]
	match state:
		State.FLYING:
			var far := _cast_span > range_tiles * FAR_THROW
			var gone := _cast_from.distance_to(tile_pos) / _cast_span
			return [&"cast_far" if far else &"cast_near", clampf(gone, 0.0, 1.0)]
		State.SETTLED:
			# A net that has been hauled and let go stays as it was hauled to. Only one that
			# has never been pulled is still lying open where it landed.
			if shut > 0.001:
				return [&"land", 1.0]
			return [&"land", clampf(_settled_age / LAND_TIME, 0.0, 1.0)]
		State.REELING:
			# The landed net, held. What closing looks like is `_draw_span` bringing it in,
			# not another picture.
			return [&"land", 1.0]
	return [&"", 0.0]


## How big one frame is drawn and where the water crosses it: its size in world pixels, and
## how far down that box the surface line sits.
##
## One place, because the drawing, the line's end and the catch all have to agree about it
## and they were each working it out again. `span` is how wide the rim should end up.
func _frame_box(name: StringName, index: int, span: float) -> Array:
	var frame: Dictionary = (_art[name] as Dictionary)["frames"][index]
	var region: Rect2 = frame["region"]

	# Sized so the rim lands where the frame says it should: `span` wide at full open, and
	# whatever fraction of that this frame is drawn at. Going through the ratio rather than
	# straight from the pixels is what lets one sequence hold frames off both sheets.
	var scale := span * float(frame["ratio"]) / maxf(float(frame["rim"]), 1.0)
	var size := Vector2(region.size.x * scale, region.size.y * scale * _squash(name, index))
	return [size, float(frame["hang"])]


## Draw one frame of a sequence, with the water crossing it where `_frame_box` says.
func _draw_frame(name: StringName, through: float, at: Vector2, span: float, tint: Color) -> void:
	var index := _frame_at(name, through)
	var box := _frame_box(name, index, span)
	var size: Vector2 = box[0]
	var region: Rect2 = (_art[name] as Dictionary)["frames"][index]["region"]

	# Centred on the mouth: the mouth is what the sweep is measured from, so the drawing
	# sits over it rather than off to one side of it.
	var hang := Vector2(size.x * 0.5, size.y * float(box[1]))
	draw_texture_rect_region(_sheet, Rect2(at - hang, size), region, tint)


## How much this frame is flattened onto the plane, from its sequence's own pair.
##
## Rooted rather than run straight across, so most of the flattening has happened by the
## middle of the sequence. Those middle frames are the tall thin ones, and they are the whole
## reason for this: spread evenly, they were still standing up like a net on a hook when the
## net they belong to is being dragged over water.
func _squash(name: StringName, index: int) -> float:
	var frames: Array = (_art[name] as Dictionary)["frames"]
	var flatten: Array = SEQUENCES[name]["flatten"]
	var through := float(index) / maxf(float(frames.size() - 1), 1.0)
	return lerpf(float(flatten[0]), float(flatten[1]), sqrt(through))


## Where the line from the rod meets the net: the top of the picture, which on a hauled net
## is the top of the bag standing out of the water and on a landed one is the near edge of
## a mouth lying flat in it.
func _line_end(at: Vector2) -> Vector2:
	return at - Vector2(0.0, _frame_height() * _hang_of(_pose()))


## How tall the frame showing right now is drawn, in world pixels, and how far down it the
## water sits. Both come up wherever something has to be placed against the picture rather
## than against the lake — the top of the bag for the line, the inside of it for the catch.
func _frame_height() -> float:
	var pose := _pose()
	if pose[0] == &"":
		return 0.0
	return float(_frame_box(pose[0], _frame_at(pose[0], pose[1]), _draw_span())[0].y)


func _hang_of(pose: Array) -> float:
	if pose[0] == &"":
		return 0.0
	return float(_frame_box(pose[0], _frame_at(pose[0], pose[1]), _draw_span())[1])


## How far the mouth reaches on screen, along its long axis. Derived from the radius the
## sweep is actually run with, so the two cannot drift apart.
func mouth_extent() -> float:
	return Iso.tile_circle_extent(sweep_radius() + MOUTH_EDGE)


## The same, for a net that is wide open. What the drawing is scaled against.
##
## It has to be this one and not the shrinking one. A frame is drawn at its own rim ratio,
## and the swept radius is already that same ratio off the full width — so scaling the
## picture against the shrunken mouth applies the closing twice, and the net drew itself
## shut about four times faster than the water it was closing over.
func open_extent() -> float:
	return Iso.tile_circle_extent(radius + MOUTH_EDGE)


## How wide the drawing is laid out, rim to rim, before the frame's own ratio narrows it:
## the open mouth, brought down towards the rod as the net comes in. Everything placed
## against the picture goes through this, so the net, the line's end and the catch inside it
## all shrink together instead of coming apart at the last stride.
func _draw_span() -> float:
	return open_extent() * 2.0 * _purse_scale() * lerpf(1.0, HOME_SIZE, near)


## A point pulled inside the net's mouth, along the line from the mouth's middle. Points
## already inside come back untouched.
func _within_mouth(at: Vector2) -> Vector2:
	var centre := world_pos()
	var span := mouth_extent()
	var gap := at - centre
	# Measured in a space where the mouth is a unit circle, which is the only way to ask
	# "how far out of an ellipse is this" without solving anything.
	var out := Vector2(gap.x / span, gap.y / (span * 0.5)).length()
	if out <= 1.0:
		return at
	return centre + gap / out


## How far a throw in this direction actually gets, in tile coordinates: stepped out from
## the angler until the range runs out or the water does. `towards` need not be normalised.
##
## This is the one place that answers "how far can I throw that way", and both the ring and
## the aiming marker are built on it, so the drawn edge and the marker cannot disagree with
## each other or with `can_cast_to`.
func _reach_along(towards: Vector2) -> Vector2:
	var from := angler.tile_pos
	if towards.length_squared() < 0.000001:
		return from
	var step := towards.normalized() * RING_STEP
	var reach := from
	var out := from + step
	while out.distance_to(from) <= range_tiles:
		if Iso.island_fraction(out.x, out.y) < 1.0:
			break
		if Iso.shore_fraction(out.x, out.y) >= 1.0:
			break
		reach = out
		out += step
	return reach


## The pointer, answered before anything is thrown: a ghost of the mouth where the cast
## would land, and — when the pointer is past what the rod can do — a second marker at the
## furthest point in that direction that would actually take, with a line joining the two.
##
## The whole point of it is that the range stops being something you learn by throwing.
func _draw_aim() -> void:
	var pointer := get_global_mouse_position()
	var legal := can_cast_to(pointer)
	var span := mouth_extent()

	# A lit net has two casts in it, so the preview shows both: the mouth this click would
	# scoop with, and inside it the patch the other button would leave burning. Neither
	# replaces the other, because neither action replaces the other.
	if legal and enchanted():
		_draw_lay_ghost(pointer)

	# The mouth as it would land. One ring either way, at the pointer: an earlier version
	# added a second one out where a refused throw would have stopped, and that pale mark
	# drifting about over the island and over the angler was the white circle that had to go.
	# The refusal itself is worth showing — a click that does nothing is worse than a click
	# the game says no to.
	var tint := AIM_FAR
	var alpha := AIM_FAR_ALPHA
	if legal:
		var takes := _would_catch(pointer)
		tint = AIM_OK if takes else AIM_NO
		alpha = AIM_ALPHA
	# 48 points rather than 24: the dashes are drawn as every other segment of this same
	# ring, and a coarse circle broken in half reads as a polygon rather than as a dashed
	# line. The solid case is happy to be smoother too.
	var ghost := PackedVector2Array()
	for i in 49:
		var angle := TAU * float(i % 48) / 48.0
		ghost.append(pointer + Vector2(cos(angle) * span, sin(angle) * span * 0.5))
	var ink := Color(tint.r, tint.g, tint.b, alpha)
	if legal:
		draw_polyline(ghost, ink, 1.5)
	else:
		# Dashed, because a refused throw is a rule rather than a thing on the water — the
		# same reason the laid-net ghost is dashed.
		for i in 24:
			draw_line(ghost[i * 2], ghost[i * 2 + 1], ink, 1.5)


## Would a cast landing here bring anything home?
##
## Only what the mouth covers where it lands, not the corridor it sweeps on the way back: the
## marker is answering the question the pointer is asking, which is about this spot. A cast
## called dead can still scoop something up on the haul, and that is a gift rather than a
## broken promise.
##
## Rubbish the net is strong enough to lift, and birds. Not charms — a charm has its own pull
## on the eye and the marker turning green for one would be the game aiming for the player.
## The hold has no say either: a net with no room left is a different problem, and a red ring
## over a full patch would read as the patch being empty.
func _would_catch(pointer: Vector2) -> bool:
	if grid == null:
		return false
	var here := grid.tile_at(pointer)
	if here < 0:
		return false
	# The full width, not `sweep_radius()`: the mouth lands open and only purses on the way
	# home, so what the ring is drawn at is what would close over this spot.
	if flock != null and not flock.perched_near(Iso.world_to_tile(pointer), radius).is_empty():
		return true
	for index in grid.tiles_within(here, radius):
		if grid.reachable_slot(index, 1, power) >= 0:
			return true
	return false


## The edge of what the angler can reach, at `strength` of full visibility.
##
## A filled area, a dashed rim, and ticks standing off it. All three because one is not
## enough: the fill says which side is water once the island has bitten a crescent out of
## the shape, the dashes say the line is a rule rather than a thing floating there, and the
## ticks give the rule a direction.
## Where a laid net would go, drawn under the aim so the two readings are one picture: a
## small dashed disc in the charm's colours, the size of the patch that would actually burn.
func _draw_lay_ghost(pointer: Vector2) -> void:
	var tint := _charm_tint()
	var reach := Iso.tile_circle_extent(field_radius())
	var ring := PackedVector2Array()
	for i in 33:
		var angle := TAU * float(i % 32) / 32.0
		ring.append(pointer + Vector2(cos(angle) * reach, sin(angle) * reach * 0.55))
	draw_colored_polygon(ring, Color(tint.r, tint.g, tint.b, 0.10))
	# Dashed, so it reads as a plan rather than as something already on the water.
	for i in 16:
		var from := ring[i * 2]
		var to := ring[i * 2 + 1]
		draw_line(from, to, Color(tint.r, tint.g, tint.b, 0.75), 1.6)


## What colour the net is wearing: warm for fire, cold for ice, and the two mixed when it
## carries both.
func _charm_tint() -> Color:
	var fire := charm_left[Charm.FIRE] > 0.0
	var ice := charm_left[Charm.ICE] > 0.0
	if fire and ice:
		return Color(1.0, 0.72, 0.62)
	if fire:
		return Color(1.0, 0.60, 0.28)
	if ice:
		return Color(0.62, 0.92, 1.0)
	return AIM_OK



## The rope from the rod to the net: how thick, its colours, and how far apart the twists of
## its strands are.
##
## It was a pale 1.5 px line, which read as fishing wire — too thin to be what hauls a bag of
## junk out of a lake, and near white against water that is itself pale. A hauling rope is
## brown and has some body: a dark edge so it holds against the water and the sand, a lighter
## core, and short slanted marks across it at a steady pitch, which is the lay of the strands
## and the whole of what makes a thick line read as rope rather than as a brown wire.
const ROPE_WIDE := 3.6
const ROPE_EDGE := Color(0.24, 0.15, 0.08, 0.95)
const ROPE_CORE := Color(0.55, 0.38, 0.21, 1.0)
const ROPE_TWIST := Color(0.36, 0.23, 0.12, 1.0)
const ROPE_PITCH := 4.0


## Hand the rope layer this frame's rope. An empty line takes the rope away.
func _lay_rope(line: PackedVector2Array) -> void:
	if _rope == null:
		return
	# Level with this node, always: being its child still draws it after the net sprite, and
	# the angler (z 9) is drawn over it whichever way they face. The rope starts inside the
	# figure's outline, so the body hides its cut end and it reads as coming out of the hands.
	# Drawn over the figure, that square end showed on the front of the body.
	_rope.z_index = z_index
	_rope.line = line
	_rope.queue_redraw()


## Draw the rope along `line` onto `on`: the edge, the core inside it, then a twist mark every
## ROPE_PITCH pixels, slanted across the rope the same way all the way along.
static func _draw_rope(on: CanvasItem, line: PackedVector2Array) -> void:
	on.draw_polyline(line, ROPE_EDGE, ROPE_WIDE)
	on.draw_polyline(line, ROPE_CORE, ROPE_WIDE - 1.6)
	var half := (ROPE_WIDE - 1.6) * 0.5
	# Walked by distance rather than by segment, so the twists stay evenly spaced where the
	# sag bunches the points together and where it stretches them apart.
	var carried := ROPE_PITCH * 0.5
	var marks := PackedVector2Array()
	for i in line.size() - 1:
		var a := line[i]
		var b := line[i + 1]
		var length := a.distance_to(b)
		if length < 0.001:
			continue
		var along := (b - a) / length
		var across := Vector2(-along.y, along.x)
		var s := carried
		while s < length:
			var at := a + along * s
			# Slanted: the back end of the mark a little behind the front, on opposite sides.
			marks.append(at - across * half - along * half * 0.8)
			marks.append(at + across * half + along * half * 0.8)
			s += ROPE_PITCH
		carried = s - length
	if not marks.is_empty():
		on.draw_multiline(marks, ROPE_TWIST, 1.0)


## The range ring, the line, the net, and whatever is being dragged in it.
func _draw() -> void:
	if angler == null:
		return
	var ink := Color(0.11, 0.09, 0.1)

	# No range ring. It was a pale dashed circle round the angler at all times, and a marking
	# the player stands inside every second of the game stops being information and becomes
	# scenery — scenery that says "user interface" over a lake drawn by hand. What can be
	# reached is still shown, at the moment it is being asked: see `_draw_aim`, which marks
	# the pointer and, when the pointer is out of range, the furthest point along the way.
	if state == State.IDLE:
		_lay_rope(PackedVector2Array())
		_draw_aim()
		return

	var at := world_pos()
	var tip := angler.rod_tip()
	var mouth := mouth_extent()
	var pose := _pose()
	var drawn: StringName = pose[0]

	# The line, sagging between the rod and the net. A straight segment reads as a wire;
	# the sag is what makes it string. It ends at the top of the bag once there is one,
	# because the art draws its own hanging line up there and meeting it is free.
	var end := _line_end(at) if drawn != &"" else at
	var line := PackedVector2Array()
	# The sag is the slack line's, and a line under a haul has no slack in it: it comes taut
	# and straight the moment the player starts pulling, which is also what stops it reading
	# as a cable strung through the air over a net hanging off it.
	var sag := minf(tip.distance_to(end) * 0.12, 26.0) * (1.0 - shut)
	for i in 13:
		var t := float(i) / 12.0
		line.append(tip.lerp(end, t) + Vector2(0.0, sin(t * PI) * sag))
	_lay_rope(line)

	# The catch always goes under the net, open mouth or closed bag. The whole read of a
	# netted load is that the junk is inside the mesh, and junk drawn over the mesh is junk
	# sitting on top of a picture of a net — which is what a landed net used to look like.
	# The drawing is a line net over a keyed mask, so what is behind it still shows through.
	#
	# Up into the body of the bag rather than down past its weights: the junk is what the
	# net is holding, so it belongs in the tube above the rim it hangs from.
	_draw_catch(
		at - Vector2(0.0, _frame_height() * CATCH_INSIDE * shut),
		mouth * lerpf(1.0, HOME_SIZE, near)
	)
	if drawn != &"":
		_draw_net(drawn, pose[1], at, mouth, ink)
	else:
		_draw_mesh(at, mouth, ink)


## The net itself. One frame of whichever sequence it is in, tinted to the lake's ink: the
## sheets are line drawings keyed to a mask, so the colour is the game's rather than the
## paper's.
func _draw_net(name: StringName, through: float, at: Vector2, mouth: float, ink: Color) -> void:
	_draw_frame(name, through, at, _draw_span(), Color(ink.r, ink.g, ink.b, 0.92))


## The net as it was drawn before there were any pictures of one: an ellipse in the tiles'
## 2:1 ratio with two crossed families of strings over it. Still here because the art can
## be missing, and a game that will not run without its assets is a game with a fuse in it.
func _draw_mesh(at: Vector2, mouth: float, ink: Color) -> void:
	var rim := PackedVector2Array()
	for i in 33:
		var angle := TAU * float(i) / 32.0
		rim.append(at + Vector2(cos(angle) * mouth, sin(angle) * mouth * 0.5))
	draw_colored_polygon(rim, Color(0.30, 0.36, 0.30, 0.30))
	draw_polyline(rim, ink, 1.6)
	for i in 4:
		var t := (float(i) + 0.5) / 4.0
		var x := lerpf(-mouth, mouth, t)
		var h := sqrt(maxf(1.0 - pow(x / mouth, 2.0), 0.0)) * mouth * 0.5
		draw_line(at + Vector2(x, -h), at + Vector2(x, h), Color(0.20, 0.26, 0.22, 0.5), 1.0)


## What it has caught, riding in the mouth.
##
## Scattered into a clutch rather than spaced evenly round the rim: junk dragged through
## water gathers, and an even ring reads as a diagram of a catch instead of a catch. As the
## net shuts the clutch is pulled tighter and fades a little — the caller has already lifted
## it into the bag by then, and the mesh in front of it does the rest. Drawn back to front,
## so near pieces overlap far ones.
func _draw_catch(at: Vector2, mouth: float) -> void:
	if catch.is_empty() or grid == null:
		return
	_scatter.seed = 20707
	# The pile is packed into the mouth rather than stacked out of it: however many pieces
	# are aboard, they share the same cap of headroom and are drawn a little smaller as the
	# load grows. A haul is a bulging net, not a column.
	var layers := ceili(float(catch.size()) / float(CATCH_LAYER))
	var step := mouth * CATCH_RISE / float(maxi(layers, 1))
	var packed := CATCH_SCALE * clampf(
		sqrt(float(CATCH_LAYER * 2) / float(maxi(catch.size(), 1))), CATCH_PACKED, 1.0
	)
	var spots: Array[Vector2] = []
	for i in catch.size():
		var angle := _scatter.randf_range(0.0, TAU)
		# Square-rooted, so the scatter is even over the area rather than crowding the
		# middle, and then pulled in: the mesh gathers what is in it.
		var out := sqrt(_scatter.randf()) * CATCH_SPREAD * lerpf(1.0, CLOSE_BUNCH, shut)
		spots.append(
			at + Vector2(cos(angle) * mouth, sin(angle) * mouth * 0.5) * out
			- Vector2(0.0, float(i / CATCH_LAYER) * step)
		)
	var order: Array[int] = []
	for i in catch.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return spots[a].y < spots[b].y)
	var seen := lerpf(1.0, CATCH_HIDDEN, shut)
	for i in order:
		draw_set_transform(spots[i], _scatter.randf_range(-0.22, 0.22), Vector2(packed, packed))
		grid.defs[catch[i]].stamp_iso(self, Color(1.0, 1.0, 1.0, seen))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
