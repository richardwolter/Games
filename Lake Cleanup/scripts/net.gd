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
##
## The net and its rope throw the one sun's shadow (2026-10-02, the "one sun" pass): a flat
## shape of the rim and a thin strip under the line, on a layer of their own just over the
## water. See `ShadowLayer`.
class_name CastNet
extends Node2D

## Emitted when the net reaches the angler with a catch aboard. The lake decides what
## happens to it; the net does not know the yard exists.
signal landed(cargo: PackedInt32Array)

## A piece lifted off the tile field, the moment the mouth closes on it — not when it
## reaches the angler. The water is cleaner the instant the piece is out of it, so the
## lake reads its pollution off this rather than off the haul arriving home.
signal caught(def_index: int)

## A sweep of the mouth that lifted rubbish: where the mouth was, in world coordinates,
## how many pieces it took, and how far it reached. One per sweep, after every piece in
## it has been `caught` — the lake opens its clean patch off this rather than off the
## pieces one by one.
signal swept(at: Vector2, taken: int, hold: int, mouth: float)

## A pigeon the net closed on, in world coordinates. Paid for on the spot rather than
## carried home: a bird is not cargo, and it is certainly not going in the yard.
signal caught_bird(at: Vector2)
## The net has just come down on the water, after its landing sweep: where, and how wide its
## mouth is. What the tornado listens for (a landing on its foot is a hit).
signal touched_down(at: Vector2, mouth: float)

enum State { IDLE, FLYING, SETTLED, REELING }

## Tiles per second on the way out. Faster than any reel — the throw is not the part of
## the cast the player is meant to wait through.
const CAST_SPEED := 26.0

## Seconds between the rings a hauled net leaves behind it. Close enough that the trail
## reads as continuous disturbance and far enough apart that the rings can be told from one
## another as they spread.
## The foam the reel pushes at the mouth (issue #31, 2026-09-16, Richard: the drag's ripples
## "replaced by a foam streak", and "foam at the mouth only" — a bow wave with a short
## tail, no trail): the ferry's own HullFoam sized to the mouth. MOUTH_STREAK is how far
## back it runs, as a multiple of the mouth's half width.
const MOUTH_STREAK := 0.7
## How far out from the mouth's middle the streaks run, as a multiple of the mouth's
## extent: a little outside the rim, so the foam shows past the mesh rather than under it.
const MOUTH_FLARE := 0.7

## How close to the rod counts as home, in tiles.
const HOME_DISTANCE := 0.35

## How far past the net's width the drawn rim sits, in tiles: the thickness of the twine.
## The rim is what catches — a drawing touching it is in the net — so anything more than
## this is the net reaching further than its upgrade says.
const MOUTH_EDGE := 0.15


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
## The sweep shrinks with it (see `mouth_extent`). It used not to, on the grounds that a bag
## hanging clear of the surface makes no promise about the water — but the player reads the
## net they can see, and a haul taking pieces well outside it read as the net lying.
const HOME_SIZE := 0.42

## How much of a cast, as a fraction, is the throw rather than the haul. Only `cast_progress`
## uses it, and only the camera uses that.
const THROW_SHARE := 0.34

## How much of its width the net keeps once it is shut. The drawing and the sweep both go
## through `_purse_scale`, so the ring the player holds and the net they see stay one size.
const CLOSE_TO := 0.3

## How much tighter than the mouth itself the catch bunches as it shuts. Past the shrinking
## of the mouth, so a full net arrives as a knot of junk rather than a scale model of the
## same spread.
const CLOSE_BUNCH := 0.55

## The net is drawn by rule, not cut from a sheet (2026-10-02, `/grill-me` with Richard; look
## A off `tools/last_net_mockup.png`). `NetShape` is the shape and its constants, and
## `shaders/net_mesh.gdshader` draws the mesh per pixel of the net's own grid: tan cord a
## pixel wide, a dark pixel under it, the rim cord and its lead beads. **Retired**: the AI
## etching (`Net_Cast_spritesheet.jpg`, `Net_Closing_Drag.jpg`, `tools/slice_net.gd`,
## `net_frames.json`), downscaled 2-3x and point-sampled, which is what read washed out.

## The throw, bundle to flat: the net leaves the hand `FLY_FROM` of its open width, domed
## `FLY_DOME` of that over its rim, its rim squashed to `FLY_SQUASH` and wobbling
## `FLY_WOBBLE`, and opens to its own size and a low dome as it goes. It rises `FLY_ARC` of
## the open half-width over its path at the middle of the throw.
const FLY_FROM := 0.22
const FLY_DOME := 0.85
const FLY_SQUASH := 0.6
const FLY_WOBBLE := 0.2
const FLY_ARC := 0.5
## The dangle's clock and how much of it is left as the net opens (`NetShape.flutter`): the
## rim flaps `FLY_FLAP` radians a second and wobbles at `FLY_WOB_RATE`, both on the clock rather
## than on the distance flown, so a short throw wiggles as much as a long one; `FLY_OPEN_KEEP`
## of the flutter and the wobble are still on as it lands, and the landing settles them out.
const FLY_FLAP := 11.0
const FLY_WOB_RATE := 8.0
const FLY_OPEN_KEEP := 0.45
## On landing the dome drops from `LAND_DOME` of the half-width (never more than
## `LAND_DOME_MOST` px) to the lying net's own over `LAND_TIME`, with the rim's wobble
## settling out.
const LAND_DOME := 0.3
const LAND_DOME_MOST := 16.0
const LAND_WOBBLE := 0.09
## Under the haul the dome flattens out (by `_lean`) and a ripple runs round the rim as it
## drags, `HAUL_RIPPLE` of the mouth at full lean, travelling at `RIPPLE_RATE` radians a
## second: a net dragged over water is never still, and one that was read as held up.
const HAUL_RIPPLE := 0.035
const RIPPLE_RATE := 5.0
## How fast a hauled bag swings from side to side, radians a second.
const SWAY_RATE := 1.3
## A lucky cast's shine after its landing burst (`NetShape` has the look): the glint first
## crosses `LUCK_GLINT_FROM` s after the splash and then every `LUCK_GLINT_EVERY`; the
## finds' stars burst round the rim (`LUCK_BURST_STARS`, popping over `LUCK_STAR_LIFE`),
## sparks fly off it (`LUCK_SPARKS`), and `LUCK_TWINKLES` stars twinkle on the cord.
const LUCK_GLINT_FROM := 0.6
const LUCK_GLINT_EVERY := 1.5
const LUCK_BURST_STARS := 14
const LUCK_STAR_LIFE := 0.5
const LUCK_SPARKS := 26
const LUCK_TWINKLES := 8

## How long the landing takes to settle, in seconds.
const LAND_TIME := 0.34

## How much of the catch still shows through the mesh once the net is shut.
const CATCH_HIDDEN := 0.5
## How far round towards the back of the bag the catch settles under a full haul: a share
## of the way from where it lay to dead behind the crown.
const CATCH_BACK := 0.5

## How tightly the catch bunches in the mouth, as a fraction of it. Under 1 so the load
## reads as a clutch of junk gathered into the middle of the mesh rather than a ring of
## pieces pinned round the rim.
const CATCH_SPREAD := 0.62

## How many pieces sit in one layer of the pile. Only a scale now: the pile is packed into
## the mouth rather than stacked out of it, and this is the load at which the pieces start
## being drawn smaller to fit.
##
## Nothing climbs out of the bag. Stacking a fixed distance per row is fine for the three
## pieces the starting net holds and turns a full late-game haul into a tower of junk
## standing a net and a half above the water, which reads as a pile the net is under rather
## than a load it is carrying.
const CATCH_LAYER := 3

## How much of the mouth's area the pile may cover, counting overlap, and the share of the
## mouth the biggest single piece may span.
##
## The first is what decides how many pieces are drawn: as many of the catch as fit at the
## packed scale, so a wider net shows more and a hold of a hundred is a full bag rather than
## a hundred stamps. The rest of the catch is in there, just behind the ones drawn.
const CATCH_FILL := 1.7
const CATCH_FIT := 0.9

## How big a piece in the mouth is drawn, and the least it shrinks to when the net is full.
##
## The catch has to fit in the mouth it is drawn in, and the mouth does not grow with the
## haul — the hold does. Shrinking the pieces a little as the load grows is what keeps a
## full net looking like a full net rather than like a heap with a net somewhere under it.
const CATCH_SCALE := 0.7
const CATCH_PACKED := 0.62


## How much lean an empty net has, against a full one, and how fast the lean follows the
## pull. Eased rather than set, so a net that changes direction or speed bends into it
## instead of snapping over.
const LEAN_EMPTY := 0.45
const LEAN_EASE := 7.0

## How far past the rim a shoved piece is pushed, in world pixels. The same idea as a hull's
## `SHOVE_CLEAR`: clear of the thing, not merely touching its edge.
const SHOVE_CLEAR := 5.0

## The rope, as a chain of points hung between the rod and the net.
##
## Drawn only. Nothing in the game reads where the rope is; it is a picture of a line that
## happens to be worked out by letting a few points fall and pulling them back to length.
## That is not the physics this project banned — no bodies, no collision, nothing gameplay
## waits on — it is the cheapest way to draw string that swings, whips on the throw, and
## comes taut when the net is pulled, instead of a sine arc that only ever flattened.
##
## `ROPE_POINTS` along it, stepped `ROPE_STEP` at a time however uneven the frames are, with
## `ROPE_PASSES` of tightening per step. `ROPE_GRAVITY` is screen-down pixels per second
## squared, small because the rope is mostly lying on water; `ROPE_DRAG` is how fast the
## swing dies. A point never moves more than `ROPE_LEAP` in one step, and if either end has
## jumped further than `ROPE_JUMP` since the last frame the whole chain is laid out afresh
## along the straight line rather than allowed to catch up.
const ROPE_POINTS := 16
const ROPE_STEP := 1.0 / 120.0
const ROPE_PASSES := 4
const ROPE_GRAVITY := 220.0
const ROPE_DRAG := 2.8
const ROPE_LEAP := 30.0
const ROPE_JUMP := 200.0

## How long the rope is against the straight rod-to-net distance: a little over while the
## net flies and sits, so it hangs, easing to a hair under once the haul is on, so it pulls
## straight and the reel is seen taking line up. `ROPE_TAKE_UP` is how fast that happens.
const ROPE_SLACK := 1.07
const ROPE_TAUT := 0.995
const ROPE_TAKE_UP := 3.0

## The horn: where the hand line ends, above the net's crown, and the short bridle lines
## that run from it down to the crown ring.
##
## A cast net is not hauled by its edge. The line goes to a swivel over the gathered apex
## and a bridle fans from there onto the crown, and that is what makes the net purse when it
## is pulled. Both numbers are fractions of the **crown's width** (`CROWN_WIDE` of the
## mouth's drawn half-width), so a net drawn at any size gets a bridle in proportion to it.
## The bridle lands on a ring of the net's own shape (`NetShape.at`), so it bends with the
## net. Bridles to the far side of it draw at `BRIDLE_FAR`, as if seen through the mesh.
## `HORN_LIFT` is deliberately small. At a third of the crown's width the line met the net
## well above the apex and the whole thing read as a net being winched up from overhead
## rather than dragged across water — the horn has to sit just clear of the crown, close
## enough that the bridle is a gather and not a suspension.
const HORN_LIFT := 0.08
const HORN_MOST := 4.0
const HORN_LEAN := 0.12
## `BRIDLE_REACH` is how far out across the crown the little ropes land, as a share of its
## half-width. Well under one, by decision: the bridle gathers the very middle of
## the apex, and lines reaching the crown's own edge read as a second, smaller net drawn on
## top of the first. They are thinner than the hand line for the same reason — a bridle is
## cord where the haul line is rope.
const BRIDLES := 6
const BRIDLE_REACH := 0.42
const BRIDLE_WIDE := 1.0
const BRIDLE_FAR := 0.45
## The crown's width against the mouth's half-width: what the etching's apex measured, kept so
## the horn and the bridle sit as they did.
const CROWN_WIDE := 0.8

## The aiming marker: what a throw at the pointer would look like before it is thrown.
##
## Three readings, on two axes. Whether the throw is allowed at all is the line: solid for a
## legal cast, dashed for one the rod refuses — too far, or over the island. Whether the
## throw is worth making is the colour: green over water with something in it, red over water
## with nothing the net could lift. A refused throw gets no colour, because a verdict on a
## cast that cannot happen is noise.
##
## **The three are the palette's own** (2026-09-16, `/grill-me` with Richard, picked off
## `tools/last_cursor_mockup.png`): the pack's measured `grass_light` and its `wood`
## red-brown, each **lifted by `AIM_LIFT`**, and the lake's `foam` white — in place of the
## screen green and fire-engine red they were. The meanings do not move — green is still
## will-catch, red still nothing-to-lift, pale still out-of-range — only the swatches, so
## nobody has to relearn the marker.
##
## The lift is what makes them carry over dirty water without being invented beside the
## palette: repaint the pack and these move with it. The pale is `foam` at every strength,
## because the picked row's was within four parts in 255 of it and at `AIM_FAR_ALPHA` over
## water that is under a pixel step.
const AIM_LIFT := 1.52
const AIM_OK := Color(0.649, 0.804, 0.382)
const AIM_NO := Color(0.822, 0.357, 0.214)
const AIM_FAR := Color(0.933, 0.965, 0.984)

## How solid each of those reads. The verdict colours carry the whole point of the marker, so
## they sit well above the pale ghost this used to be.
const AIM_ALPHA := 0.8
const AIM_FAR_ALPHA := 0.55

## The backing: the same ring drawn once underneath in black, wider, at a share of whatever
## the coloured line is carrying. Palette swatches are duller than the ones they replaced and
## the ring sits on water running from soup green to clean blue, so a toned green over dirty
## water had nothing to stand on. This is the black every hole in the menus' wood is rimmed
## with (`Style.HOLE_RIM`), doing the same job: telling the drawing from what is behind it.
##
## **The one thing beyond the three swatches**, by Richard's call. Everything else about the
## marker is untouched — the 1.5 px line, the alphas, the dashes, the 48-point ellipse.
const AIM_BACK := Color(0.0, 0.0, 0.0)
const AIM_BACK_SHARE := 0.55
const AIM_BACK_WIDE := 3.5

## How far into the mouth a piece's middle is put when the pad's assist looks for a green
## spot beside it (`nearest_catch`): inside the rim, so the spot is green by a margin rather
## than on the knife edge where the next frame's swell calls it red.
const CATCH_INNER := 0.8

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

## A lucky haul (Lake._roll_luck): one tier more of lift and a few more in the bag, this
## cast only. Cleared when the net comes home. `strength()` and `room_left()` read them.
var luck_power: int = 0
var luck_hold: int = 0

## A helper net — the double cast's second net. It never plays the angler's throw or ends
## it: that gesture belongs to the first net, which is still out when this one lands.
var helper: bool = false

## Wired up by lake.gd. The net reads the tile field directly rather than asking the lake
## to fetch for it — it is the thing doing the catching.
var grid: LakeGrid
var splash: WaterSplash
## The noises. Optional — a net with no sound board still fishes.
var sfx: Sfx
var angler: Angler
## The birds. Optional — with no flock the net simply catches rubbish.
var flock: Flock

var state: int = State.IDLE
## Where the net is, in tile coordinates, and where it is heading while flying.
var tile_pos := Vector2.ZERO
var target := Vector2.ZERO
## Def indices caught this cast, dragged in behind the net.
var catch := PackedInt32Array()
## What the sweep in hand has lifted out of the water so far, as the weights its drawn
## splashes were given. Handed to the sound as one run when the sweep is over.
var _lifted: Array[float] = []

## Whether the net is allowed to reel. A thrown net pulls itself in, so this is true for
## the whole of an ordinary cast — what turns it off is the game being paused over the
## water: a panel opened mid-drag stops the net where it is and lets it go again when the
## panel closes.
var _pulling: bool = true
var _time: float = 0.0

## Fixed seed, reset every draw, so the catch scatters the same way from one frame to the
## next. A load that reshuffles itself sixty times a second is a load that is boiling.
var _scatter := RandomNumberGenerator.new()

## Where a cast started and how far it had to go, so the throw can be animated against how
## much of it is left. Set when it is thrown, the way the flock does for a bird in flight.
var _cast_from := Vector2.ZERO
var _cast_span: float = 1.0

## How long the net has been down, for the landing sequence.
var _settled_age: float = 0.0

## Where the pointer, the angler and the charm were when the idle picture was last painted.
## See `_repaint`.
var _aim_was := Vector2.INF

## Where the pad's reticle stands, in world pixels, or INF when the mouse is aiming. Set by
## the lake every frame (`Lake._pad_tick`); `aim_point` is the one place the net asks.
var pad_aim := Vector2.INF
var _idle_was := Vector2.INF

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

## How hard the net is leaning into the pull, 0 lying flat and 1 bent right over, and which
## way the rope is pulling it in world coordinates. Both eased towards where they should be
## rather than set, so the bend follows the haul instead of flicking about with it.
var _lean: float = 0.0
var _pull := Vector2.RIGHT

## The rope's points now and a step ago (that pair is the whole of its motion), the time
## banked towards the next fixed step, and how far the haul has taken the slack up, 0 to 1.
var _rope_now := PackedVector2Array()
var _rope_was := PackedVector2Array()
var _rope_bank: float = 0.0
var _rope_taut: float = 0.0


## The rope, on a layer of its own.
##
## Drawn by this node it was under the net sprite (which is drawn last, over the catch) and
## under the angler (z 9 against this node's 8) — so it vanished into the bag. On its own child
## it is always drawn after the net, and still under the figure, which hides where it starts.
class RopeLayer extends Node2D:
	var line := PackedVector2Array()
	var near := PackedVector2Array()
	var far := PackedVector2Array()

	func _draw() -> void:
		if line.size() < 2:
			return
		# Far bridles first and faint, then the near ones, then the line over the lot.
		if far.size() >= 2:
			CastNet._draw_bridle(self, far, BRIDLE_FAR)
		if near.size() >= 2:
			CastNet._draw_bridle(self, near, 1.0)
		CastNet._draw_rope(self, line)


var _rope: RopeLayer


## The mesh, on a layer of its own with the net's shader on it: the first child, so it draws
## over the catch (this node's own drawing) and under the rope, the stars and the aim.
class NetMesh extends Node2D:
	var shape: NetShape
	var origin := Vector2.ZERO
	var shown: bool = false

	func _init() -> void:
		var mat := ShaderMaterial.new()
		mat.shader = NetShape.SHADER
		material = mat

	func _draw() -> void:
		if not shown or shape == null:
			return
		shape.push(material as ShaderMaterial)
		NetShape.draw_into(self, origin, shape.w_open)


## The aiming marker, on the last layer, so nothing the net draws can hide it.
class AimLayer extends Node2D:
	var net: CastNet

	func _draw() -> void:
		if net != null:
			net._draw_aim(self)


var _mesh: NetMesh
var _aim: AimLayer


## The net's shadow and its rope's, on the water (2026-10-02, the "one sun" pass with Richard).
##
## Cheap shapes, by decision, and no second pass of the mesh shader: a net is mostly holes, so
## what it really throws is a speckle no-one would read at this size, and a faint flat shape of
## its outline says "there is something between the sun and the water here" as well as the
## speckle would. So the shadow is the rim — `NetShape.at` round `rho` 1, the very ring the
## rim cord is drawn on — filled once as a fan, at `SHADOW_FADE` of the water's ink.
##
## **Where it falls is the sun's, from how high the net is** (`Shade.drop`): in the air, from
## the height the throw's arc has lifted it (`draw_at` against `world_pos`), so the shadow
## races along the water down and to one side of a net still overhead and meets it as it lands,
## a little smaller and fainter the higher it is (`SHADOW_SHRINK`, `SHADOW_THIN`, the pigeons'
## rule); on the water, from the dome's own height, so it is just off the net's down-sun side.
## The rope is laid under the same rule point by point, its height tapering along the chain
## from the hands (`Angler.HAND_HEIGHT` of the figure) to the net's own (nought on the water,
## the arc's lift in the air), so its shadow leaves the angler's feet and meets the net's.
## The drawn sag is read as the line hanging towards the camera, not as height lost: measured
## off a straight line instead, a slack rope "lay on the water" and its shadow hid under it.
##
## On the water's tint or the land's (`Shade.On`), by where each shadow lands: a throw leaves
## the angler over the beach, and the rope's near end is always over the island.
##
## **Its own layer at an absolute z** (`SHADOW_Z`, over the water, the sand and the rubbish's
## own shadows at 3, under the floating soup at 5): the net node sorts with the angler, one
## layer under them, and a shadow drawn there could lie over the hut, over the crate or over a
## dog. Down here nothing that stands on the ground is ever under it.
class ShadowLayer extends Node2D:
	var net: CastNet
	var _was := false
	# Reused every frame, so a cast allocates nothing to throw its shadow.
	var _ring := PackedVector2Array()
	var _ring_ink := PackedColorArray()
	var _fan := PackedInt32Array()
	var _chain := PackedVector2Array()
	var _chain_ink := PackedColorArray()
	var _line := PackedVector2Array()
	var _line_ink := PackedColorArray()
	var _verts := PackedVector2Array()
	var _vert_ink := PackedColorArray()
	var _strip := PackedInt32Array()

	func _init() -> void:
		z_as_relative = false
		z_index = SHADOW_Z

	# Its own clock, the luck stars' rule: every frame a cast is out, and once more as it
	# ends, so the last shadow is cleared rather than left lying on the water.
	func _process(_delta: float) -> void:
		var on := net != null and net.state != State.IDLE
		if on or _was:
			queue_redraw()
		_was = on

	func _draw() -> void:
		if net == null:
			return
		var s := net.shape_now()
		if s == null:
			return
		_draw_net(s)
		_draw_line()

	func _draw_net(s: NetShape) -> void:
		var ground := net.world_pos()
		var lift := ground.y - net.draw_at().y
		var up := 0.0
		var height := s.h
		if net.state == State.FLYING:
			height = lift
			up = clampf(lift / maxf(FLY_ARC * net.open_extent(), 1.0), 0.0, 1.0)
		var size := 1.0 - SHADOW_SHRINK * up
		var centre := ground + Shade.drop(null, height)
		var on := Shade.On.WATER if WaterSplash.wet_at(centre) else Shade.On.LAND
		var ink := Shade.tint_on(null, on, SHADOW_FADE * (1.0 - SHADOW_THIN * up))
		var n := SHADOW_RIM
		_ring.resize(n + 1)
		var sum := Vector2.ZERO
		for i in n:
			# The rim is on the water at every stage (its dome term is nought at `rho` 1), so
			# what `at` gives here is the outline on the plane, relative to the mouth's middle.
			var p := centre + s.at(1.0, TAU * float(i) / float(n)) * size
			_ring[i + 1] = p
			sum += p
		# A fan from the outline's mean: the rim is a ray-swept loop round the mouth's middle
		# in every shape the net takes, so the fan never folds over itself and doubles up.
		_ring[0] = sum / float(n)
		if _fan.size() != n * 3:
			_fan.resize(n * 3)
			for i in n:
				_fan[i * 3] = 0
				_fan[i * 3 + 1] = i + 1
				_fan[i * 3 + 2] = (i + 1) % n + 1
		_ring_ink.resize(n + 1)
		_ring_ink.fill(ink)
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _fan, _ring, _ring_ink)

	func _draw_line() -> void:
		var rope := net._rope_now
		var n := rope.size()
		if n < 2:
			return
		# How high each end is: the hands, and the horn over the net (the throw's lift; the
		# horn's own few pixels over the crown are left out, so a net on the water is nought).
		var hand := Angler.HEIGHT * Angler.HAND_HEIGHT
		var lift := net.world_pos().y - net.draw_at().y
		var wet := Shade.tint_on(null, Shade.On.WATER, ROPE_SHADOW_FADE)
		var dry := Shade.tint_on(null, Shade.On.LAND, ROPE_SHADOW_FADE)
		_chain.resize(n)
		_chain_ink.resize(n)
		# The near end is taken off the angler's own shadow (`Angler.shadow_point`), so the
		# rope's shadow leaves the hands of the body's; what that moves the near end by is
		# eased out along the chain, so the far end still meets the net's.
		var mend := Vector2.ZERO
		if net.angler != null:
			mend = net.angler.shadow_point(rope[0]) 				- (rope[0] + Vector2(0.0, hand) + Shade.drop(null, hand))
		for i in n:
			var t := float(i) / float(n - 1)
			var height := lerpf(hand, lift, t)
			var p := rope[i] + Vector2(0.0, height) + Shade.drop(null, height) + mend * (1.0 - t)
			_chain[i] = p
			_chain_ink[i] = wet if WaterSplash.wet_at(p) else dry
		# Smoothed the rope's own way (`rope_curve`), coarser, with the tint carried along.
		# Counted first and written in place, so the arrays are only ever resized, not grown.
		var m := 1
		for i in n - 1:
			m += maxi(1, ceili(_chain[i].distance_to(_chain[i + 1]) / ROPE_SHADOW_STEP))
		_line.resize(m)
		_line_ink.resize(m)
		var at := 0
		for i in n - 1:
			var p0 := _chain[maxi(i - 1, 0)]
			var p1 := _chain[i]
			var p2 := _chain[i + 1]
			var p3 := _chain[mini(i + 2, n - 1)]
			var cuts := maxi(1, ceili(p1.distance_to(p2) / ROPE_SHADOW_STEP))
			for k in cuts:
				var t := float(k) / float(cuts)
				var t2 := t * t
				var t3 := t2 * t
				_line[at] = 0.5 * (
					2.0 * p1 + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
					+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3)
				_line_ink[at] = _chain_ink[i].lerp(_chain_ink[i + 1], t)
				at += 1
		_line[m - 1] = _chain[n - 1]
		_line_ink[m - 1] = _chain_ink[n - 1]
		CastNet._mitre(_line, ROPE_SHADOW_WIDE * 0.5, _verts)
		_vert_ink.resize(m * 2)
		for i in m:
			_vert_ink[i * 2] = _line_ink[i]
			_vert_ink[i * 2 + 1] = _line_ink[i]
		CastNet._strip_order(m, _strip)
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _strip, _verts, _vert_ink)


## The shadow's numbers (`ShadowLayer`). The net's is a share of the water's ink — a mesh is
## mostly holes — and the rope's a little more, being solid; both first guesses for Richard's
## eye. `SHADOW_RIM` points round the outline, `SHADOW_SHRINK` and `SHADOW_THIN` how much
## smaller and fainter it is at the top of the throw's arc, and `SHADOW_Z` the absolute layer.
const SHADOW_FADE := 0.35
const ROPE_SHADOW_FADE := 0.5
const ROPE_SHADOW_WIDE := 2.8
const ROPE_SHADOW_STEP := 6.0
const SHADOW_RIM := 28
const SHADOW_SHRINK := 0.3
const SHADOW_THIN := 0.4
const SHADOW_Z := 4

var _shadow: ShadowLayer


## A lucky cast's stars and sparks: the finds' own four-point star (`GlintTwinkle.draw_star`)
## and single pixels, over the mesh. Placed on the net's shape every frame, off a fixed
## seed, so a star stays on its spot of cord while it lives.
class LuckStars extends Node2D:
	var net: CastNet
	var _was := false

	func _process(_delta: float) -> void:
		var on := net != null and net._lucky_age >= 0.0
		if on or _was:
			queue_redraw()
		_was = on

	func _draw() -> void:
		if net == null or net._lucky_age < 0.0:
			return
		var s := net.shape_now()
		if s == null:
			return
		var at := net.draw_at()
		var t := net._lucky_age
		var rng := RandomNumberGenerator.new()
		rng.seed = 7151
		if t < NetShape.BURST_RUN + NetShape.BURST_FADE + LUCK_STAR_LIFE:
			for i in LUCK_BURST_STARS:
				var th := TAU * float(i) / float(LUCK_BURST_STARS) + rng.randf() * 0.3
				var born := rng.randf() * NetShape.BURST_RUN * 0.9
				var life := (t - born) / LUCK_STAR_LIFE
				if life < 0.0 or life > 1.0:
					continue
				var p := at + s.at(1.0 + 0.08 * life, th) - Vector2(0.0, 4.0 * life)
				draw_set_transform(p.round(), 0.0, Vector2.ONE)
				LakeGrid.GlintTwinkle.draw_star(self, true, sin(life * PI))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			# Sparks thrown off as the light passes, from the front round both ways.
			for i in LUCK_SPARKS:
				var th := rng.randf() * TAU
				var gone := absf(fposmod(th - PI * 0.5 + PI, TAU) - PI)
				var life := (t - gone / PI * NetShape.BURST_RUN) / NetShape.BURST_RUN
				if life < 0.0 or life > 1.0:
					continue
				var p := at + s.at(1.0 + 0.25 * life, th) - Vector2(0.0, 6.0 * life)
				draw_rect(Rect2(p.floor(), Vector2.ONE),
					Color.WHITE if life < 0.4 else NetShape.GOLD_LIT)
		if t > LUCK_GLINT_FROM:
			var phase := (t - LUCK_GLINT_FROM) / LUCK_GLINT_EVERY
			for i in LUCK_TWINKLES:
				var th := rng.randf() * TAU
				var rho := 0.55 + 0.45 * rng.randf()
				var life := fposmod(phase * 1.7 + rng.randf(), 1.0)
				var p := at + s.at(rho, th)
				draw_set_transform(p.round(), 0.0, Vector2.ONE)
				LakeGrid.GlintTwinkle.draw_star(self, life > 0.2 and life < 0.8, sin(life * PI))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


var _luck_stars: LuckStars
## Seconds since a lucky net landed, or -1: the clock its burst and glint run on.
var _lucky_age: float = -1.0

## The shine a find keeps while it is in the net (Richard, 2026-09-13): the same rim, beam
## and stars it had on the water, on the piece where the catch draws it. Three children,
## because three draw paths: the rim under everything this node draws (`show_behind_parent`,
## so the piece and the rest of the catch cover it, with shaders/rim.gdshader turning a
## green-modulated copy of the picture into gold), the beam over everything on the lake
## (the lake's own beam shader and z), and the stars over the mesh with no material at all.
## `_draw_catch` tells them where each shown find landed, every frame it draws.
const RIM_SHADER := preload("res://shaders/rim.gdshader")

class CatchShine extends Node2D:
	var grid: LakeGrid
	# What `_draw_catch` drew this frame: [def index, spot, angle, scale] per shown find.
	var finds: Array = []
	var age: float = 0.0


class CatchRim extends CatchShine:
	func _init() -> void:
		var mat := ShaderMaterial.new()
		mat.shader = RIM_SHADER
		material = mat
		show_behind_parent = true

	func _draw() -> void:
		for find: Array in finds:
			var def: TrashDef = grid.defs[find[0]]
			if def.atlas == null:
				continue
			var scale_by: float = find[3]
			# The offsets are in the piece's own frame, so at a packed scale they shrink with
			# it: a whole-lake rim on a half-size picture would be twice as thick.
			draw_set_transform(find[1], find[2], Vector2(scale_by, scale_by))
			for step: Vector2 in LakeGrid.RIM_OFFSETS:
				draw_texture_rect_region(
					def.atlas, Rect2(-def.size * 0.5 + step * LakeGrid.RIM_STEP, def.size),
					def.region, Color(0.0, 1.0, 0.0, 1.0)
				)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


class CatchBeam extends CatchShine:
	func _init() -> void:
		var mat := ShaderMaterial.new()
		mat.shader = LakeGrid.BEAM_SHADER
		material = mat
		z_as_relative = false
		z_index = 20

	# Its own clock for the breath: the net only redraws when it moves, and a beam that
	# breathed only while the bag swung would hold its breath on a landed net.
	func _process(delta: float) -> void:
		age += delta
		queue_redraw()

	func _draw() -> void:
		if grid == null:
			return
		var wide := grid.beam_width()
		for find: Array in finds:
			var def: TrashDef = grid.defs[find[0]]
			var scale_by: float = find[3]
			var at: Vector2 = find[1]
			# From the bottom of the picture, straight up the screen whatever the piece's
			# turn: the column is light, and it stands.
			var foot := at + Vector2(0.0, def.size.y * scale_by * 0.5 + LakeGrid.BEAM_SINK * 0.5)
			var tall := maxf(def.size.x, def.size.y) * scale_by * LakeGrid.BEAM_TALL
			var beat := 0.5 + 0.5 * sin(age * LakeGrid.GLINT_BREATH + float(find[0]) * 0.7)
			var glow := LakeGrid.GLINT_TINT
			glow.a = LakeGrid.BEAM_BRIGHT * (0.7 + 0.3 * beat)
			draw_rect(Rect2(foot - Vector2(wide * 0.5, tall), Vector2(wide, tall)), glow)


class CatchStars extends CatchShine:
	var _spots := {}
	var _image: Image
	# Live stars and sparks: [def index, spot, born, star (true) or spark (false)].
	var _stars: Array = []
	var _rng := RandomNumberGenerator.new()

	func _process(delta: float) -> void:
		age += delta
		var kept: Array = []
		var shown := {}
		for find: Array in finds:
			shown[find[0]] = find
		for star: Array in _stars:
			var span: float = LakeGrid.STAR_LIFE if star[3] else LakeGrid.SPARK_LIFE
			if age - float(star[2]) < span and shown.has(star[0]):
				kept.append(star)
		_stars = kept
		for find: Array in finds:
			var spots := _spots_of(find[0])
			if spots.is_empty():
				continue
			if _rng.randf() < LakeGrid.STAR_RATE * delta:
				_stars.append([find[0], spots[_rng.randi() % spots.size()], age, true])
			if _rng.randf() < LakeGrid.SPARK_RATE * delta:
				_stars.append([find[0], spots[_rng.randi() % spots.size()], age, false])
		queue_redraw()

	func _spots_of(which: int) -> PackedVector2Array:
		if _spots.has(which):
			return _spots[which]
		if _image == null and grid != null and grid.sheets != null and grid.sheets.atlas != null:
			_image = grid.sheets.atlas.get_image()
		var found := LakeGrid.GlintTwinkle.sample_spots(_image, grid.defs[which], which)
		_spots[which] = found
		return found

	func _draw() -> void:
		var shown := {}
		for find: Array in finds:
			shown[find[0]] = find
		for star: Array in _stars:
			if not shown.has(star[0]):
				continue
			var find: Array = shown[star[0]]
			var def: TrashDef = grid.defs[find[0]]
			var spot: Vector2 = star[1]
			var big: bool = star[3]
			var span: float = LakeGrid.STAR_LIFE if big else LakeGrid.SPARK_LIFE
			var life := clampf((age - float(star[2])) / span, 0.0, 1.0)
			var scale_by: float = find[3]
			# The whole picture shows in the net — no waterline cut — so a spot is simply
			# its fraction of the box, turned and scaled as the piece was drawn.
			var local := (spot - Vector2(0.5, 0.5)) * def.size * scale_by
			draw_set_transform(find[1] + local.rotated(find[2]), find[2], Vector2.ONE)
			LakeGrid.GlintTwinkle.draw_star(self, big, sin(life * PI))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


var _rim: CatchRim
var _beam: CatchBeam
var _stars: CatchStars
## The foam at the mouth while reeling. See MOUTH_STREAK.
var _bow: HullFoam


func _ready() -> void:
	position = Vector2.ZERO
	if angler != null:
		tile_pos = angler.tile_pos
	_mesh = NetMesh.new()
	_mesh.name = &"Mesh"
	add_child(_mesh)
	# Its z is absolute, so where it sits among the children changes nothing it is drawn over.
	_shadow = ShadowLayer.new()
	_shadow.name = &"Shadow"
	_shadow.net = self
	add_child(_shadow)
	_rope = RopeLayer.new()
	_rope.name = &"Rope"
	_rope.z_as_relative = false
	add_child(_rope)
	_rim = CatchRim.new()
	_rim.name = &"CatchRim"
	add_child(_rim)
	_stars = CatchStars.new()
	_stars.name = &"CatchStars"
	add_child(_stars)
	_beam = CatchBeam.new()
	_beam.name = &"CatchBeam"
	add_child(_beam)
	_bow = HullFoam.new()
	_bow.name = &"Bow"
	_bow.with_trail = false
	_bow.streak_long = MOUTH_STREAK
	add_child(_bow)
	_luck_stars = LuckStars.new()
	_luck_stars.name = &"LuckStars"
	_luck_stars.net = self
	add_child(_luck_stars)
	_aim = AimLayer.new()
	_aim.name = &"Aim"
	_aim.net = self
	add_child(_aim)


## Space left in this cast. The lake also caps this against the yard, so a full yard stops
## the net catching rather than throwing the catch away.
func room_left() -> int:
	return maxi(hold + luck_hold - catch.size(), 0)


## The heaviest tier this cast lifts: the net's own, and the lucky haul's tier on top.
func strength() -> int:
	return power + luck_power


## Is this cast a lucky one?
func lucky() -> bool:
	return luck_power > 0 or luck_hold > 0


## Is this world point a legal cast? Inside the range ring, and on the lake rather than on
## the island or the bank — a net thrown onto dry land is not a mistake worth simulating.
func can_cast_to(where: Vector2) -> bool:
	return state == State.IDLE and in_reach(where)


## Whether a throw could land here, whatever the net is doing now: in range of the angler, on
## open water. `can_cast_to` is this and an idle net; the aiming marker and the pad's assist
## ask this one, so they keep answering while a cast is out.
func in_reach(where: Vector2) -> bool:
	if angler == null:
		return false
	var tile := Iso.world_to_tile(where)
	if tile.distance_to(angler.tile_pos) > range_tiles:
		return false
	if Iso.island_fraction(tile.x, tile.y) < 1.0:
		return false
	return Iso.shore_fraction(tile.x, tile.y) < 1.0


## Whether a throw could land here from some shore of the island, after the walk the led
## cast makes (`Lake._cast_or_walk`): open water within range of the standing spot
## `Angler.shore_toward` finds for it. Read by the aim ring, which draws solid where a press
## throws; `in_reach` is still what decides a throw from where the angler stands now.
func castable_after_walk(where: Vector2) -> bool:
	if angler == null or not angler.has_method(&"shore_toward"):
		return false
	var tile := Iso.world_to_tile(where)
	if Iso.island_fraction(tile.x, tile.y) < 1.0 or Iso.shore_fraction(tile.x, tile.y) >= 1.0:
		return false
	var shore: Vector2 = angler.shore_toward(tile)
	return shore.distance_to(tile) <= range_tiles


## Throw the net.
func cast_to(where: Vector2) -> bool:
	if not can_cast_to(where):
		return false
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
	# A fresh throw is a fresh rope: laid straight from the hands to the net on the first
	# frame rather than the last cast's chain being dragged across the lake to the new one.
	_rope_now.resize(0)
	# The angler's own throw — only ever a flourish: the net still flies on this same line at
	# this same speed either way, see Angler.start_cast().
	if not helper:
		angler.start_cast()
		if sfx != null:
			sfx.play_throw()
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
	_push_bow(delta)
	_lean_into_pull(delta)
	if state == State.SETTLED or state == State.REELING:
		_settled_age += delta
	if _lucky_age >= 0.0:
		_lucky_age += delta
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
				# What the ring came down on is caught as it lands, not a frame into the haul
				# after the mouth has already slid off it. Before the splash and the sound,
				# because both say whether it caught: an empty net makes a low foam mound
				# and rings with no plumes or spray (2026-09-24, Richard), and the sound is
				# low and whole with something in the mesh, high and quieter on bare water
				# (`Sfx.play_landing`).
				var caught := _sweep(true)
				if splash != null:
					splash.splash(world_pos(), 0.45, caught)
					# The ring the landing pushes out, on top of the crown's own: this is
					# the one that is still spreading a second later.
					splash.ripple(world_pos(), mouth_extent() * 1.2)
				if sfx != null:
					sfx.play_landing(caught)
				touched_down.emit(world_pos(), mouth_extent())
				# A lucky net's burst starts on the splash (`LuckStars`, the shader's rim).
				_lucky_age = 0.0 if lucky() else -1.0
		State.REELING:
			_advance_towards(angler.tile_pos, reel_speed, delta)
			_sweep()
			# Whatever the mouth cannot lift is pushed out of its way instead, the way a hull
			# parts the rubbish it passes. Straight after the sweep, so a piece is only ever
			# shoved once the net has established it is not taking it.
			_shove_aside(delta)
			if tile_pos.distance_to(angler.tile_pos) < HOME_DISTANCE:
				_come_home()
		State.SETTLED:
			pass
		_:
			# Idle rides along with the angler, so the range ring and the stowed net are
			# always drawn where they are actually thrown from.
			if angler != null:
				tile_pos = angler.tile_pos
	# After the net has moved and before anything is drawn, so the rope hangs off where the
	# net is this frame rather than where it was.
	_drive_rope(delta)
	_chime_at_finds()
	_repaint()


## The chime rings on for as long as the aim marker is over a shining find, buried or
## uncovered, and the last ring finishes after it leaves (2026-09-15, Richard; `Sfx.hover_find`).
## The marker is up while a cast is out too, so this is too; not on the double cast's second
## net, which draws no marker, and not while a board is over the water and the angler is held.
## The mouth's foam: pushed while the net is reeling, gone the moment it is not. Laid at the
## mouth's own spot, pointed the way it is being pulled — towards the angler — and sized to
## the mouth it is on, so a wider net pushes a wider wave.
func _push_bow(delta: float) -> void:
	if _bow == null:
		return
	# Only a reel pushes a wave, and only a reel aims one. The moment it ends the net is in
	# the angler's hand and the wave is dropped where it was — it used to fall back to a
	# heading of dead right at the net's home, which is the angler, and ease out from
	# there: a streak of foam pointing east beside the player after every haul (Richard,
	# 2026-09-17).
	if state != State.REELING or angler == null:
		_bow.drop()
		return
	var at := world_pos()
	var extent := mouth_extent()
	var heading := Vector2.ZERO
	if angler.position.distance_squared_to(at) > 0.01:
		heading = (angler.position - at).normalized()
	# The wave's bow sits on the mouth's leading rim, not its middle: the streaks run back
	# from there along the rim's sides, drawn behind the net so what shows is the water
	# parting round the front of it. Laid at the middle, the whole wave was under the mesh.
	# With no heading to speak of (the mouth is on the angler) the wave stays where it was.
	if heading != Vector2.ZERO:
		_bow.position = at + Vector2(heading.x, heading.y * 0.5) * extent * 0.5
	_bow.half_length = extent * 0.5
	_bow.half_width = extent * MOUTH_FLARE
	_bow.lay(heading, 1.0, delta)


func _chime_at_finds() -> void:
	if helper or sfx == null or grid == null or angler == null or not angler.can_walk:
		return
	var pointer := aim_point()
	var mouth := open_extent()
	var over := -1
	for find: Vector2i in grid.shining_finds():
		if _touches(pointer, mouth, grid.surface_pos(find.x), grid.footprint(find.x)):
			over = find.x
			break
	sfx.hover_find(over >= 0)


## Ask for a repaint, but not while the idle picture is standing still.
##
## Every other state animates — the net flies, the mouth shuts, the catch rides up the line
## — so those redraw every frame and should. Idle draws a range ring round the angler and a
## ghost mouth under the pointer, and neither of those moves unless the angler or the mouse
## does. Standing on the dock deciding where to cast is the most common thing in the game,
## and it used to repaint the ring sixty times a second.
func _repaint() -> void:
	if state == State.IDLE:
		var aim := aim_point()
		if aim.is_equal_approx(_aim_was) and tile_pos.is_equal_approx(_idle_was):
			return
		_aim_was = aim
		_idle_was = tile_pos
	queue_redraw()


## The bend, eased towards where the haul says it should be.
##
## Two things are followed: which way the rope is pulling, and how hard the net is resisting
## it. A full net bends further than an empty one, because what bends a net is what is in it.
## Anything that is not a haul lets the bend fall back out, so a net let go of on the water
## settles rather than staying bent around a pull nobody is making.
func _lean_into_pull(delta: float) -> void:
	var ease := 1.0 - exp(-LEAN_EASE * delta)
	if state != State.REELING or angler == null:
		_lean = lerpf(_lean, 0.0, ease)
		return
	var pull := Iso.tile_to_world(angler.tile_pos.x, angler.tile_pos.y) - world_pos()
	if pull.length_squared() > 0.001:
		_pull = _pull.lerp(pull.normalized(), ease).normalized()
	var load := clampf(float(catch.size()) / maxf(float(hold), 1.0), 0.0, 1.0)
	_lean = lerpf(_lean, lerpf(LEAN_EMPTY, 1.0, load), ease)


## Push aside what the cast is not taking.
##
## Only the refusals: a piece too heavy for this net, or anything at all once the hold is
## full. Whatever the mouth is about to catch is caught rather than shoved, so nothing is
## ever seen being knocked out of the way and then picked up anyway.
##
## The push is outwards from the middle of the mouth rather than along the haul, because
## that is the one direction that always clears it — a piece dead ahead is parted to a side
## picked off its tile, the same trick the hulls use so a row of them does not all go one way.
func _shove_aside(delta: float) -> void:
	if grid == null:
		return
	var at := world_pos()
	var mouth := mouth_extent()
	var pushed := _reach(at, mouth, strength(), 0, true)
	if room_left() <= 0:
		# Nothing is being taken, so everything the mouth meets is in its way.
		pushed.append_array(_reach(at, mouth, strength()))
	var clear := 1.0 + SHOVE_CLEAR / maxf(mouth, 1.0)
	for index in pushed:
		var rel := grid.surface_pos(index) - at
		# Measured where the mouth is a unit circle, so "out of the net" is one number.
		var norm := Vector2(rel.x / maxf(mouth, 1.0), rel.y / maxf(mouth * 0.5, 1.0))
		var out := norm.length()
		if out >= clear:
			continue
		var way := norm / out if out > 0.05 else _side_of(index)
		var want := Vector2(way.x * mouth, way.y * mouth * 0.5) * (clear - out)
		grid.shove_to(index, want, delta)


## Which way a piece sitting under the middle of the mouth is parted, from its own tile, so
## the choice is the same every frame and neighbours do not all go the same way.
func _side_of(index: int) -> Vector2:
	var tile := grid.tile_of(index)
	return Vector2(1.0, 0.0) if (tile.x + tile.y) % 2 == 0 else Vector2(-1.0, 0.0)


func _advance_towards(to: Vector2, speed: float, delta: float) -> void:
	var gap := to - tile_pos
	var step := speed * delta
	if gap.length() <= step:
		tile_pos = to
		return
	tile_pos += gap.normalized() * step


## One frame of sweeping.
##
## Passes over the same tiles, in the order a net actually closes. The birds sitting on the
## water go first, because a bird is on top of everything by definition and costs the cast
## nothing. Then everything floating, across the whole width of the mouth. Only once there
## is nothing left on the surface does it bite into what is underneath, and then the layer
## under that, until the bag is full — which is what makes a cast read as scooping a patch
## clean rather than picking one thing off each tile it crosses. Never past a piece too
## heavy to lift: a cast cannot pull a bag out from under a fridge.
##
## Nearest first within each pass, so the mouth closes from the middle out.
##
## Returns whether it took anything at all, a bird and a charm included. What it lifted out
## of the water is heard once for the whole sweep, not piece by piece: a `landing` is a
## swell and the water draining after it (`Sfx.play_lifted`), a grab on the way home is a
## plip (`Sfx.play_grab`).
func _sweep(landing: bool = false) -> bool:
	if grid == null:
		return false
	var at := world_pos()
	var mouth := mouth_extent()
	var took := false
	_lifted.clear()

	# Every bird sat inside the mouth, without exception: a perched pigeon is on top of
	# everything, the hold has no say in it, and one left bobbing inside the ring the player
	# just closed reads as the net passing through it.
	if flock != null:
		for perched in _birds_touched(at, mouth):
			took = true
			caught_bird.emit(flock.take(perched))

	# Only the rubbish is limited by what the net can hold. A bird is lifted off the surface
	# by a net that is already full, which is why the hold is not checked until here.
	var before := catch.size()
	# Layer after layer until the bag is full or the mouth has nothing left it can lift: a net
	# that lands on a pile takes the pile, rather than its top two layers with the rest
	# floating up behind it (2026-10-03, Richard). Asked again for each layer: what a take
	# uncovers is a new piece, and one the mouth now touches is in. **And a tile it has taken
	# from stays in**: the piece under a take is rolled a new drift and starts `EMERGE_DROP`
	# low to rise into view, so asked of its drawing alone it often fell out of the ring it
	# was under and floated up behind the net. The column under a piece the net closed on is
	# under the net. Ends because every pass that goes round again took a piece.
	var dug := {}
	while room_left() > 0:
		var layer := _reach(at, mouth, strength())
		for index: int in dug:
			if not layer.has(index) and grid.reachable_slot(index, 1, strength()) >= 0:
				layer.append(index)
		if _take_from(layer, dug) == 0:
			break
	if sfx != null and not _lifted.is_empty():
		if landing:
			sfx.play_lifted(_lifted)
		else:
			sfx.play_grab(_lifted)
	if catch.size() > before:
		took = true
		swept.emit(at, catch.size() - before, hold + luck_hold, mouth)
	return took


## Does a drawing — an ellipse at `centre` with half-extents `half`, in world pixels — touch a
## mouth `mouth` world pixels across its long half, lying at `at`?
##
## The whole of what "inside the ring" means, for the catch and for the aiming marker alike.
## A piece is in the net when any of its drawing is, not when its tile is: the tile is a
## cell the player never sees, and a sofa hanging half into the ring is a sofa in the ring.
##
## Worked with the plane's height doubled, where the mouth is a circle, so the question is
## only how close the drawing's nearest point comes to the mouth's middle.
static func _touches(at: Vector2, mouth: float, centre: Vector2, half: Vector2) -> bool:
	var a := maxf(half.x, 0.001)
	var b := maxf(half.y * 2.0, 0.001)
	# The mouth's middle as seen from the drawing's, folded into one quarter of it.
	var px := absf(at.x - centre.x)
	var py := absf(at.y - centre.y) * 2.0
	if (px * px) / (a * a) + (py * py) / (b * b) <= 1.0:
		return true
	# The nearest point on the drawing's rim, walked towards in a few fixed-point steps.
	# Three is plenty at the sizes on this lake: the answer is a pixel test, not a proof.
	var tx := 0.70710678
	var ty := 0.70710678
	for i in 3:
		var ex := (a * a - b * b) * tx * tx * tx / a
		var ey := (b * b - a * a) * ty * ty * ty / b
		var rim := Vector2(a * tx - ex, b * ty - ey).length()
		var qx := px - ex
		var qy := py - ey
		var q := maxf(Vector2(qx, qy).length(), 0.000001)
		tx = clampf((qx * rim / q + ex) / a, 0.0, 1.0)
		ty = clampf((qy * rim / q + ey) / b, 0.0, 1.0)
		var t := maxf(Vector2(tx, ty).length(), 0.000001)
		tx /= t
		ty /= t
	return Vector2(px - a * tx, py - b * ty).length() <= mouth


## The tiles whose top piece a mouth at `at` touches and a net of `strength` can lift, nearest
## drawing first. `most` stops looking once that many are found; 0 finds them all.
##
## Tiles only narrow the search. Everything within the mouth plus the furthest any drawing can
## stand off its tile is a candidate, and each candidate is kept on its drawing alone.
## `refused` turns it around: the tiles holding something this net will *not* take, which is
## what the haul shoves aside.
func _reach(
	at: Vector2, mouth: float, strength: int, most: int = 0, refused: bool = false
) -> Array[int]:
	var out: Array[int] = []
	if grid == null:
		return out
	var centre := Iso.world_to_tile(at)
	var bound := mouth / Iso.tile_circle_extent(1.0) + grid.footprint_reach()
	var span := int(ceil(bound)) + 1
	var cx := int(floor(centre.x))
	var cy := int(floor(centre.y))
	for ty in range(maxi(cy - span, 0), mini(cy + span + 1, Iso.ROWS)):
		for tx in range(maxi(cx - span, 0), mini(cx + span + 1, Iso.COLS)):
			if Vector2(float(tx) + 0.5, float(ty) + 0.5).distance_to(centre) > bound:
				continue
			var index := grid.index_of(tx, ty)
			var liftable := grid.reachable_slot(index, 1, strength) >= 0
			if refused:
				if liftable or grid.top_slot(index) < 0:
					continue
			elif not liftable:
				continue
			if not _touches(at, mouth, grid.surface_pos(index), grid.footprint(index)):
				continue
			out.append(index)
			if most > 0 and out.size() >= most:
				return out
	# Nearest first, measured to where each piece is drawn, so the mouth closes from the
	# middle out and the order does not jump as the net crosses a tile edge.
	out.sort_custom(
		func(p: int, q: int) -> bool:
			return grid.surface_pos(p).distance_squared_to(at) < grid.surface_pos(q).distance_squared_to(at)
	)
	return out


## The perched birds a mouth at `at` touches, highest row first so they can be taken in turn.
func _birds_touched(at: Vector2, mouth: float) -> Array[int]:
	var out: Array[int] = []
	for i in range(flock.birds.size() - 1, -1, -1):
		if int((flock.birds[i] as Dictionary)["state"]) != Flock.State.PERCHED:
			continue
		var drawn := flock.footprint(i)
		if _touches(at, mouth, drawn[0], drawn[1]):
			out.append(i)
	return out


## One layer: every tile in turn gives up whatever is on top of it, if the net is strong
## enough to lift it and there is room left in the cast. How many it took; every tile taken
## from goes in `dug`.
func _take_from(reach: Array[int], dug: Dictionary = {}) -> int:
	var took := 0
	for index in reach:
		if room_left() <= 0:
			return took
		var k := grid.reachable_slot(index, 1, strength())
		if k < 0:
			continue
		took += 1
		dug[index] = true
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
		# Heard once for the whole sweep, not piece by piece: see `_sweep`.
		_lifted.append(weight)
	return took


func _come_home() -> void:
	_lucky_age = -1.0
	state = State.IDLE
	tile_pos = angler.tile_pos
	luck_power = 0
	luck_hold = 0
	if not helper:
		angler.end_cast()
	var lot := catch.duplicate()
	catch.resize(0)
	if not lot.is_empty():
		landed.emit(lot)


## Home this instant, catch and all, from wherever the cast had got to: the lake going to
## its menu pose under a fade. The catch is landed the ordinary way, through `landed`.
func stow() -> void:
	if state == State.IDLE:
		return
	set_pulling(false)
	_come_home()
	queue_redraw()


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


## How wide the net is against its open self, from how far it has pursed. The sweep and the
## drawing both go through this, which is what keeps the ring the player is holding and the
## net they can see the same size.
func _purse_scale() -> float:
	return lerpf(1.0, CLOSE_TO, shut)


## A picture of the net lying open, `half` px across its half-width, for anything else that
## wants to draw one: the shop board's head and the HUD's button. Rendered once by the same
## shader the lake's net is drawn with, in a viewport of its own, and handed to `done` as a
## texture the frame after. Headless (no renderer) there is nothing to hand over and `done`
## is never called.
func bake_picture(half: float, done: Callable) -> void:
	var view := SubViewport.new()
	view.transparent_bg = true
	view.disable_3d = true
	view.size = Vector2i(int(ceil(half * 2.0 + NetShape.RIM_OUT * 2.0 + 4.0)), int(ceil(half + half * NetShape.DOME + NetShape.RIM_OUT * 2.0 + 6.0)))
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	var mesh := NetMesh.new()
	mesh.shape = NetShape.lying(half)
	mesh.origin = Vector2(view.size.x * 0.5, half * NetShape.DOME + half * 0.5 + NetShape.RIM_OUT + 2.0)
	mesh.shown = true
	view.add_child(mesh)
	add_child(view)
	RenderingServer.frame_post_draw.connect(_take_picture.bind(view, done), CONNECT_ONE_SHOT)


func _take_picture(view: SubViewport, done: Callable) -> void:
	var image := view.get_texture().get_image() if view.get_texture() != null else null
	view.queue_free()
	if image == null or image.is_empty() or image.get_used_rect().size == Vector2i.ZERO:
		return
	var used := image.get_used_rect()
	done.call({"sheet": ImageTexture.create_from_image(image.get_region(used)),
		"region": Rect2(Vector2.ZERO, Vector2(used.size))})


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


## The net's shape this frame, as it is drawn: thrown, landing, lying or hauled. Null when it
## is stowed. Everything placed against the net — the mesh, the horn and its bridle, the
## catch — asks this and gets the same answer.
func shape_now() -> NetShape:
	if state == State.IDLE:
		return null
	# Once a frame: the mesh, the horn, the bridle and the catch all ask. Keyed on the lean
	# and the place as well, so anything that moves the net mid-frame gets a fresh one.
	var key := Vector4(float(Engine.get_process_frames()), _lean, tile_pos.x, tile_pos.y)
	if _shape_key == key and _shape_was != null:
		return _shape_was
	_shape_was = _shape_fresh()
	_shape_key = key
	return _shape_was


var _shape_was: NetShape
var _shape_key := Vector4.INF
## The way the last throw flew, on the plane, kept for the landing's dangle to run out along.
var _trail := Vector2(1.0, 0.0)


func _shape_fresh() -> NetShape:
	var open := open_extent()
	var s := NetShape.lying(mouth_extent())
	s.w_open = open
	s.gold = lucky()
	if _lucky_age >= 0.0:
		if _lucky_age < NetShape.BURST_RUN + NetShape.BURST_FADE:
			s.landed = _lucky_age
		if _lucky_age > LUCK_GLINT_FROM:
			s.glint = fposmod((_lucky_age - LUCK_GLINT_FROM) / LUCK_GLINT_EVERY, 1.0)
	s.pull = Vector2(_pull.x, _pull.y * 2.0).normalized()
	s.haul = _lean
	s.load = _load()
	s.sway = sin(_time * SWAY_RATE)
	match state:
		State.FLYING:
			var gone := clampf(_cast_from.distance_to(tile_pos) / _cast_span, 0.0, 1.0)
			var e := 1.0 - pow(1.0 - gone, 2.0)
			# Nothing pulls a net in the air; the last haul's lean is still easing out.
			s.haul = 0.0
			s.load = 0.0
			s.w = open * lerpf(FLY_FROM, 1.0, e)
			s.h = s.w * lerpf(FLY_DOME, NetShape.DOME, e)
			s.squash = lerpf(FLY_SQUASH, 1.0, e)
			s.wobble = FLY_WOBBLE * lerpf(1.0, FLY_OPEN_KEEP, e)
			s.wob_phase = _time * FLY_WOB_RATE
			# Dangly: the skirt streams behind the way it flies and hangs in flapping lobes.
			s.flutter = lerpf(1.0, FLY_OPEN_KEEP, e)
			s.flap = _time * FLY_FLAP
			var flying := Iso.tile_to_world(tile_pos.x, tile_pos.y) \
				- Iso.tile_to_world(_cast_from.x, _cast_from.y)
			if flying.length_squared() > 0.0001:
				s.trail = Vector2(flying.x, flying.y * 2.0).normalized()
				_trail = s.trail
		State.SETTLED, State.REELING:
			var k := clampf(_settled_age / LAND_TIME, 0.0, 1.0)
			var settle := 1.0 - pow(1.0 - k, 3.0)
			s.h = lerpf(minf(s.w * LAND_DOME, LAND_DOME_MOST), s.h, settle) * (1.0 - _lean)
			s.wobble = LAND_WOBBLE * (1.0 - settle) + HAUL_RIPPLE * _lean
			s.wob_phase = _settled_age * 9.0 * (1.0 - settle) + _time * RIPPLE_RATE
			# The throw's dangle runs out as it settles, the lobes still flapping as they drop.
			s.flutter = FLY_OPEN_KEEP * (1.0 - settle) * (1.0 - _lean)
			s.flap = _time * FLY_FLAP
			s.trail = _trail
	return s


## Where the net is drawn: on the water, lifted on an arc while it flies.
func draw_at() -> Vector2:
	var at := world_pos()
	if state == State.FLYING:
		var gone := clampf(_cast_from.distance_to(tile_pos) / _cast_span, 0.0, 1.0)
		at.y -= FLY_ARC * open_extent() * sin(PI * gone)
	return at


## Where the rope is tied to the net: the horn, hanging just over the crown — the gathered
## apex a cast net is hauled from — and leaning a little towards the rod under the haul.
##
## Four anchors were tried on the etching before this one: the top of the frame's box (a
## point in the air), that plus a guessed lean (came apart from the mesh), the rim facing
## the rod (a line tied to a hoop), and the crown with bridles all the way to the rim
## (lines across the mesh they gather). The crown is the net's own `(0, 0)` now, so it is
## wherever the shape puts it. The lift is capped at `HORN_MOST` px and goes as the haul takes
## up, so the line runs along the water to a net being dragged, not down to one hanging.
func _line_end(at: Vector2) -> Vector2:
	var s := shape_now()
	if s == null:
		return at
	var wide := CROWN_WIDE * s.w
	return (
		at + s.at(0.0, 0.0)
		- Vector2(0.0, minf(HORN_LIFT * wide, HORN_MOST) * (1.0 - _lean))
		+ _pull * HORN_LEAN * wide * _lean
	)


## The bridle: pairs of points, horn to a ring on the crown, for `BRIDLES` lines spaced round
## it. The near half in `near`, the far half in `far`, so the far ones can be drawn as if
## through the mesh. Onto the crown, never to the rim: the real bridle is short, and lives in
## the dense part of the weave.
func _bridle_points(
	at: Vector2, horn: Vector2, near: PackedVector2Array, far: PackedVector2Array
) -> void:
	var s := shape_now()
	if s == null:
		return
	var ring := CROWN_WIDE * 0.5 * BRIDLE_REACH
	var crown := s.at(0.0, 0.0)
	for i in BRIDLES:
		# Offset by half a step, so no line runs exactly along the widest points of the ring.
		var angle := TAU * (float(i) + 0.5) / float(BRIDLES)
		var on_ring := s.at(ring, angle)
		if on_ring.y >= crown.y:
			near.append(horn)
			near.append(at + on_ring)
		else:
			far.append(horn)
			far.append(at + on_ring)


## How far the mouth reaches on screen, along its long axis: the open net, pursed and brought
## down towards the rod. The one number the drawing, the sweep and the aiming marker all use,
## so what is drawn is what is caught at every frame of a cast — including the last stride,
## where the net shrinks by `HOME_SIZE` and used to go on sweeping at its full width.
func mouth_extent() -> float:
	return open_extent() * _purse_scale() * lerpf(1.0, HOME_SIZE, near)


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
	return mouth_extent() * 2.0


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



## The pointer, answered before anything is thrown: a ghost of the mouth where the cast
## would land, and — when the pointer is past what the rod can do — a second marker at the
## furthest point in that direction that would actually take, with a line joining the two.
##
## The whole point of it is that the range stops being something you learn by throwing.
func _draw_aim(on: CanvasItem) -> void:
	# The double cast's second net draws no ring: it would draw the same ring twice.
	if helper or angler == null:
		return
	var pointer := aim_point()
	# No ring on the island (2026-09-22, Richard): land is nowhere to cast, and since a
	# press there walks the angler, a dashed ring over it said "refused" about a click that
	# is not. The pointer alone. The bank and the piers keep the dashes: a press there is
	# nothing, and the dashes say so.
	var over := Iso.world_to_tile(pointer)
	if Iso.island_fraction(over.x, over.y) < 1.0:
		return
	# Solid wherever a press throws — now, or after the walk the led cast makes
	# (`castable_after_walk`); the verdict is the mouth's at that spot either way.
	var legal := in_reach(pointer) or castable_after_walk(pointer)
	# The open mouth, not the one being pursed: the ring is the next throw, which lands wide
	# open, so it must not shrink with the net coming home.
	var span := open_extent()

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
	# The backing goes down first, carrying its share of whatever the coloured line carries,
	# so the dashed out-of-range ring is backed as faintly as it is drawn.
	var back := Color(AIM_BACK.r, AIM_BACK.g, AIM_BACK.b,
		AIM_BACK_SHARE * alpha / AIM_ALPHA)
	if legal:
		on.draw_polyline(ghost, back, AIM_BACK_WIDE)
		on.draw_polyline(ghost, ink, 1.5)
	else:
		# Dashed, because a refused throw is a rule rather than a thing on the water — the
		# same reason the laid-net ghost is dashed.
		for i in 24:
			on.draw_line(ghost[i * 2], ghost[i * 2 + 1], back, AIM_BACK_WIDE)
		for i in 24:
			on.draw_line(ghost[i * 2], ghost[i * 2 + 1], ink, 1.5)


## What the player is aiming at: the pad's reticle while there is one, else the mouse.
func aim_point() -> Vector2:
	return pad_aim if pad_aim != Vector2.INF else get_global_mouse_position()


## The marker's verdict, for the pad's assist (`PadAim`), which must call green exactly what
## the marker does.
func would_catch(at: Vector2) -> bool:
	return _would_catch(at)


## The nearest spot to `at` where the marker would be green, no further than `reach` world
## pixels past where it is now, or INF. For the pad's assist (`PadAim`).
##
## Not a search over spots: over pieces. Each piece the net could lift (and each perched
## bird) has a nearest point from which the mouth covers its middle, which is on the line
## from the piece to `at`, `CATCH_INNER` of the mouth out from it — measured, like `_touches`,
## on the plane with its height doubled, where the mouth is a circle. The candidate found is
## checked with the marker's own test before it is handed back, so the pull never leads onto
## a spot the marker would call red.
##
## `heading` is where the reticle is being pushed: a spot behind it (under `ahead` of cosine)
## is passed over, so the assist can bend the aim towards something but never hold it back
## from where the player is steering. ZERO takes every direction.
func nearest_catch(at: Vector2, reach: float, heading: Vector2 = Vector2.ZERO, ahead: float = -1.0) -> Vector2:
	if grid == null or angler == null:
		return Vector2.INF
	var mouth := open_extent()
	var inner := mouth * CATCH_INNER
	var spots: Array[Vector2] = []
	var centre := Iso.world_to_tile(at)
	var bound := (reach + mouth) / Iso.tile_circle_extent(1.0) + grid.footprint_reach()
	var span := int(ceil(bound)) + 1
	var cx := int(floor(centre.x))
	var cy := int(floor(centre.y))
	for ty in range(maxi(cy - span, 0), mini(cy + span + 1, Iso.ROWS)):
		for tx in range(maxi(cx - span, 0), mini(cx + span + 1, Iso.COLS)):
			if Vector2(float(tx) + 0.5, float(ty) + 0.5).distance_to(centre) > bound:
				continue
			var index := grid.index_of(tx, ty)
			if grid.reachable_slot(index, 1, power) >= 0:
				spots.append(grid.surface_pos(index))
	if flock != null:
		for i in flock.birds.size():
			if int((flock.birds[i] as Dictionary)["state"]) == Flock.State.PERCHED:
				spots.append(flock.footprint(i)[0])

	var best := Vector2.INF
	var best_gap := INF
	for piece in spots:
		var off := at - piece
		var flat := Vector2(off.x, off.y * 2.0)
		var gap := flat.length() - inner
		if gap <= 0.0 or gap > reach or gap >= best_gap:
			continue
		var rim := flat.normalized() * inner
		var spot := piece + Vector2(rim.x, rim.y * 0.5)
		if heading != Vector2.ZERO and (spot - at).normalized().dot(heading) < ahead:
			continue
		if not in_reach(spot) or not _would_catch(spot):
			continue
		best = spot
		best_gap = gap
	return best


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
	# The open mouth: the net lands open and only purses on the way home, so what the ring is
	# drawn at is what would close over this spot. Same test as the sweep, same drawings.
	var mouth := open_extent()
	if flock != null and not _birds_touched(pointer, mouth).is_empty():
		return true
	return not _reach(pointer, mouth, power, 1).is_empty()


## The edge of what the angler can reach, at `strength` of full visibility.
##
## A filled area, a dashed rim, and ticks standing off it. All three because one is not
## enough: the fill says which side is water once the island has bitten a crescent out of
## the shape, the dashes say the line is a rule rather than a thing floating there, and the
## ticks give the rule a direction.
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


## Hand the rope layer this frame's rope and bridle. An empty line takes the lot away.
func _lay_rope(
	line: PackedVector2Array,
	near: PackedVector2Array = PackedVector2Array(),
	far: PackedVector2Array = PackedVector2Array()
) -> void:
	if _rope == null:
		return
	_rope.near = near
	_rope.far = far
	# Level with this node, always: being its child still draws it after the net sprite, and
	# the angler (z 9) is drawn over it whichever way they face. The rope starts inside the
	# figure's outline, so the body hides its cut end and it reads as coming out of the hands.
	# Drawn over the figure, that square end showed on the front of the body.
	_rope.z_index = z_index
	_rope.line = line
	_rope.queue_redraw()


## Move the rope on by one frame: pin its ends to the hands and the rim, let it fall and
## swing in fixed steps, and pull it back to length.
##
## Its length is the one thing gameplay tells it. Out on the water the rope is a little
## longer than the gap it spans and hangs; under the haul it is eased down to a hair under
## the gap, so it straightens and the reel is seen taking line up — the slack going out is
## the pull starting, which is what a line does.
func _drive_rope(delta: float) -> void:
	if state == State.IDLE or angler == null:
		_rope_now.resize(0)
		_rope_taut = 0.0
		return
	var head := angler.rod_tip()
	var foot := _line_end(draw_at())
	if (
		_rope_now.size() != ROPE_POINTS
		or _rope_now[0].distance_to(head) > ROPE_JUMP
		or _rope_now[ROPE_POINTS - 1].distance_to(foot) > ROPE_JUMP
	):
		_seed_rope(head, foot)
	var ease := 1.0 - exp(-ROPE_TAKE_UP * delta)
	_rope_taut = lerpf(_rope_taut, 1.0 if state == State.REELING else 0.0, ease)
	var rest := (
		head.distance_to(foot) * lerpf(ROPE_SLACK, ROPE_TAUT, _rope_taut)
		/ float(ROPE_POINTS - 1)
	)
	# Fixed steps, banked: a long frame runs several, a short one may run none, and the rope
	# behaves the same either way. Capped so a stall does not spend the next frame catching up.
	_rope_bank += minf(delta, 0.1)
	while _rope_bank >= ROPE_STEP:
		_rope_bank -= ROPE_STEP
		_rope_tick(head, foot, rest)
	# Pinned again after the steps, so the drawn ends are this frame's whatever the banking did.
	_rope_now[0] = head
	_rope_now[ROPE_POINTS - 1] = foot


## Lay the rope out straight between its ends, still. What a new cast starts from.
func _seed_rope(head: Vector2, foot: Vector2) -> void:
	_rope_now.resize(ROPE_POINTS)
	_rope_was.resize(ROPE_POINTS)
	for i in ROPE_POINTS:
		_rope_now[i] = head.lerp(foot, float(i) / float(ROPE_POINTS - 1))
		_rope_was[i] = _rope_now[i]
	_rope_bank = 0.0


## One fixed step of the rope: each free point keeps most of last step's motion and falls a
## little, then every link is pulled back towards `rest` a few times over, the pinned ends
## taking none of the correction and their neighbours all of it.
func _rope_tick(head: Vector2, foot: Vector2, rest: float) -> void:
	var last := ROPE_POINTS - 1
	var keep := exp(-ROPE_DRAG * ROPE_STEP)
	var fall := Vector2(0.0, ROPE_GRAVITY * ROPE_STEP * ROPE_STEP)
	for i in range(1, last):
		var here := _rope_now[i]
		var moved := ((here - _rope_was[i]) * keep).limit_length(ROPE_LEAP)
		_rope_was[i] = here
		_rope_now[i] = here + moved + fall
	_rope_now[0] = head
	_rope_now[last] = foot
	for pass_ in ROPE_PASSES:
		for i in last:
			var a := _rope_now[i]
			var b := _rope_now[i + 1]
			var gap := b - a
			var length := gap.length()
			if length < 0.0001:
				continue
			var share := gap * ((length - rest) / length)
			var wa := 0.0 if i == 0 else 1.0
			var wb := 0.0 if i + 1 == last else 1.0
			var total := wa + wb
			if total <= 0.0:
				continue
			_rope_now[i] = a + share * (wa / total)
			_rope_now[i + 1] = b - share * (wb / total)


## Draw bridle lines — pairs of points — onto `on`: the rope's edge and core, thinner, no
## twist, at `fade` of the rope's own solidity.
static func _draw_bridle(on: CanvasItem, pairs: PackedVector2Array, fade: float) -> void:
	var edge := Color(ROPE_EDGE.r, ROPE_EDGE.g, ROPE_EDGE.b, ROPE_EDGE.a * fade)
	var core := Color(ROPE_CORE.r, ROPE_CORE.g, ROPE_CORE.b, ROPE_CORE.a * fade)
	on.draw_multiline(pairs, edge, BRIDLE_WIDE)
	on.draw_multiline(pairs, core, BRIDLE_WIDE * 0.5)


## How far apart the drawn rope's points are, in world pixels, along the smooth curve.
const ROPE_DRAW_STEP := 3.0


## The chain's points as a smooth curve (centripetal-free uniform Catmull-Rom, ends doubled
## so it starts and stops on them), sampled about every `ROPE_DRAW_STEP`. Passes through
## every chain point, so the ends stay on the rod tip and the crown.
static func rope_curve(points: PackedVector2Array) -> PackedVector2Array:
	var n := points.size()
	if n < 3:
		return points
	var out := PackedVector2Array()
	for i in n - 1:
		var p0 := points[maxi(i - 1, 0)]
		var p1 := points[i]
		var p2 := points[i + 1]
		var p3 := points[mini(i + 2, n - 1)]
		var cuts := maxi(1, ceili(p1.distance_to(p2) / ROPE_DRAW_STEP))
		for k in cuts:
			var t := float(k) / float(cuts)
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * (
				2.0 * p1 + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
				+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3))
	out.append(points[n - 1])
	return out


## A line `wide` across down `line`, as one triangle strip whose every joint is mitred (the
## miter held to `ROPE_MITER_MOST` widths on a hairpin), capped with a disc at each end.
static func _rope_strip(on: CanvasItem, line: PackedVector2Array, wide: float, colour: Color) -> void:
	var n := line.size()
	if n < 2:
		return
	var half := wide * 0.5
	var verts := PackedVector2Array()
	_mitre(line, half, verts)
	var indices := PackedInt32Array()
	_strip_order(n, indices)
	var colours := PackedColorArray()
	colours.resize(n * 2)
	colours.fill(colour)
	RenderingServer.canvas_item_add_triangle_array(on.get_canvas_item(), indices, verts, colours)
	on.draw_circle(line[0], half, colour)
	on.draw_circle(line[n - 1], half, colour)


## The two edges of a strip `half` either side of `line`, into `verts` (two a point, left
## then right), every joint mitred. What the rope and its shadow (`ShadowLayer`) are both cut
## from; `verts` is resized, so a caller that keeps one array allocates nothing.
static func _mitre(line: PackedVector2Array, half: float, verts: PackedVector2Array) -> void:
	var n := line.size()
	verts.resize(n * 2)
	for i in n:
		var before := (line[i] - line[maxi(i - 1, 0)]).normalized()
		var after := (line[mini(i + 1, n - 1)] - line[i]).normalized()
		if before == Vector2.ZERO:
			before = after
		if after == Vector2.ZERO:
			after = before
		var tangent := (before + after).normalized()
		if tangent == Vector2.ZERO:
			tangent = after
		var normal := Vector2(-tangent.y, tangent.x)
		var fit := normal.dot(Vector2(-after.y, after.x))
		var reach := half / maxf(absf(fit), 1.0 / ROPE_MITER_MOST)
		verts[i * 2] = line[i] + normal * reach
		verts[i * 2 + 1] = line[i] - normal * reach


## The triangles of a strip of `n` points cut by `_mitre`, into `indices`. The same for every
## strip of that length, so a kept array is only rewritten when the length changes.
static func _strip_order(n: int, indices: PackedInt32Array) -> void:
	var want := maxi(n - 1, 0) * 6
	if indices.size() == want:
		return
	indices.resize(want)
	for i in n - 1:
		var a := i * 2
		indices[i * 6] = a
		indices[i * 6 + 1] = a + 1
		indices[i * 6 + 2] = a + 3
		indices[i * 6 + 3] = a
		indices[i * 6 + 4] = a + 3
		indices[i * 6 + 5] = a + 2


## How far a mitred joint may reach, in half-widths, before a hairpin is cut short.
const ROPE_MITER_MOST := 3.0


## Draw the rope along `line` onto `on`: the edge, the core inside it, then a twist mark every
## ROPE_PITCH pixels, slanted across the rope the same way all the way along.
static func _draw_rope(on: CanvasItem, points: PackedVector2Array) -> void:
	# Drawn through a smooth curve rather than the chain's own points: straight between them,
	# every bend was a corner, and `draw_polyline` draws no joints, so the thick line's outer
	# edges parted at each one. Discs at every drawn point fill what is left of a joint.
	#
	# Each of the two is one mitred strip, its joints closed by construction, with a disc at
	# either end only (2026-09-26): a disc at every drawn point — six hundred of them on a
	# rope thrown to the end of the range — was most of what the rope cost a frame.
	var line := rope_curve(points)
	_rope_strip(on, line, ROPE_WIDE, ROPE_EDGE)
	_rope_strip(on, line, ROPE_WIDE - 1.6, ROPE_CORE)
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


## The line, the net, and whatever is being dragged in it. The mesh and the aim ring are
## children (`NetMesh`, `AimLayer`), told here what to draw; this node draws the catch, which
## goes under the mesh.
func _draw() -> void:
	if _aim != null:
		_aim.queue_redraw()
	if angler == null:
		return

	# No range ring. It was a pale dashed circle round the angler at all times, and a marking
	# the player stands inside every second of the game stops being information and becomes
	# scenery. What can be reached is still shown, at the moment it is being asked: see
	# `_draw_aim`.
	var s := shape_now()
	if s == null:
		_lay_rope(PackedVector2Array())
		_shine([])
		if _mesh != null:
			_mesh.shown = false
			_mesh.queue_redraw()
		return

	var at := draw_at()

	# The rope, as `_drive_rope` left it this frame: from the hands to the horn over the net,
	# and the bridle from the horn down to the crown.
	var near := PackedVector2Array()
	var far := PackedVector2Array()
	if _rope_now.size() >= 2:
		_bridle_points(at, _rope_now[_rope_now.size() - 1], near, far)
	_lay_rope(_rope_now, near, far)

	# The catch always goes under the net: the whole read of a netted load is that the junk
	# is inside the mesh.
	_draw_catch(at, mouth_extent(), s)
	if _mesh != null:
		_mesh.shape = s
		_mesh.origin = at
		_mesh.shown = true
		_mesh.queue_redraw()


## How full the cast is, 0 to 1. What the bag's sag and spread, the lean and the purse bend on.
func _load() -> float:
	return clampf(float(catch.size()) / maxf(float(hold), 1.0), 0.0, 1.0)


## What it has caught, riding in the mouth.
##
## Scattered into a clutch rather than spaced evenly round the rim: junk dragged through
## water gathers, and an even ring reads as a diagram of a catch instead of a catch. As the
## net shuts the clutch is pulled tighter and fades a little, and the mesh in front of it does
## the rest. Every spot is laid out on the net's own shape, so the load rides in the bag as
## it bends, settling towards the back of it under the haul (`CATCH_BACK`). Drawn back to
## front, so near pieces overlap far ones.
func _draw_catch(at: Vector2, mouth: float, shape: NetShape) -> void:
	var shining: Array = []
	if catch.is_empty() or grid == null:
		_shine(shining)
		return
	_scatter.seed = 20707
	# As many of the catch as the mouth has room for, drawn smaller as the load grows: a bag
	# with forty things in it is a full bag, not forty stamps, and a wider net shows more of
	# what it is carrying because there is more net to see it through.
	var shown := _shown_count(mouth)
	var packed := CATCH_SCALE * clampf(
		sqrt(float(CATCH_LAYER * 2) / float(maxi(shown, 1))), CATCH_PACKED, 1.0
	)
	# The last ones in, so a cast that is still catching visibly gathers rather than freezing
	# on whatever it happened to take first.
	var first := catch.size() - shown
	var spots: Array[Vector2] = []
	var sizes: Array[float] = []
	for i in shown:
		var half: Vector2 = grid.defs[catch[first + i]].size * packed * 0.5
		# Nothing is drawn wider than the bag holding it. A sofa in a starting net is a sofa
		# the net is visibly straining around, not a sofa with a net painted behind it.
		var fit := minf(
			1.0,
			minf(
				mouth * CATCH_FIT / maxf(half.x, 0.001),
				mouth * 0.5 * CATCH_FIT / maxf(half.y, 0.001)
			)
		)
		half *= fit
		var angle := _scatter.randf_range(0.0, TAU)
		# Square-rooted, so the scatter is even over the area rather than crowding the
		# middle, and then pulled in: the mesh gathers what is in it.
		var out := sqrt(_scatter.randf()) * CATCH_SPREAD * lerpf(1.0, CLOSE_BUNCH, shut)
		# Scattered over what is left of the mouth once this piece's own size is taken off it,
		# so the whole drawing stays inside the rim however big the piece is. That is the
		# difference between junk in a net and junk cutting through one.
		var lying := Vector2(
			cos(angle) * maxf(mouth - half.x, 0.0),
			sin(angle) * maxf(mouth * 0.5 - half.y, 0.0)
		) * out
		spots.append(at + _on_shape(shape, lying))
		sizes.append(packed * fit)
	var order: Array[int] = []
	for i in shown:
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return spots[a].y < spots[b].y)
	var seen := lerpf(1.0, CATCH_HIDDEN, shut)
	for i in order:
		var turn := _scatter.randf_range(-0.22, 0.22)
		draw_set_transform(spots[i], turn, Vector2(sizes[i], sizes[i]))
		var def := grid.defs[catch[first + i]]
		def.stamp_iso(self, Color(1.0, 1.0, 1.0, seen))
		if def.keepsake:
			shining.append([catch[first + i], spots[i], turn, sizes[i]])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_shine(shining)


## Where a spot `lying` off the middle of a net lying flat ends up on `shape`: read back
## onto the net as (rho, theta), turned towards the back of the bag by the haul, and laid out
## again.
func _on_shape(shape: NetShape, lying: Vector2) -> Vector2:
	var plane := Vector2(lying.x, lying.y * 2.0)
	var rho := plane.length() / maxf(shape.w, 0.001)
	var heading := atan2(shape.pull.y, shape.pull.x)
	var phi := wrapf(atan2(plane.y, plane.x) - heading, 0.0, TAU)
	phi = PI + (phi - PI) * (1.0 - CATCH_BACK * shape.haul)
	return shape.at(rho, heading + phi)


## Hand the shown finds to the shine layers. The rim and the beam redraw with this node;
## the stars run their own clock and redraw themselves.
func _shine(shining: Array) -> void:
	if _rim == null:
		return
	for layer: CatchShine in [_rim, _beam, _stars]:
		layer.grid = grid
		layer.finds = shining
	_rim.queue_redraw()
	_beam.queue_redraw()
	_beam.set_process(not shining.is_empty())
	_stars.set_process(not shining.is_empty())
	if shining.is_empty():
		_stars.queue_redraw()


## How many of the catch are drawn: as many as cover `CATCH_FILL` of the mouth's area at the
## packed scale, never more than are aboard and never fewer than one.
##
## Measured rather than fixed, because the two things it depends on both move: the mouth
## grows with every width upgrade, and what is in it is a different size every cast.
func _shown_count(mouth: float) -> int:
	if catch.is_empty() or grid == null:
		return 0
	var room := PI * mouth * (mouth * 0.5) * CATCH_FILL
	var each := 0.0
	for i in catch.size():
		var drawn: Vector2 = grid.defs[catch[i]].size * CATCH_SCALE * CATCH_PACKED
		each += drawn.x * drawn.y
	each = maxf(each / float(catch.size()), 1.0)
	return clampi(int(room / each), 1, catch.size())
