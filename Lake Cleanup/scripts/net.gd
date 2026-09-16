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

## A sweep of the mouth that lifted rubbish: where the mouth was, in world coordinates,
## how many pieces it took, and how far it reached. One per sweep, after every piece in
## it has been `caught` — the lake opens its clean patch off this rather than off the
## pieces one by one.
signal swept(at: Vector2, taken: int, hold: int, mouth: float)

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

## How far past the net's width the drawn rim sits, in tiles: the thickness of the twine.
## The rim is what catches — a drawing touching it is in the net — so anything more than
## this is the net reaching further than its upgrade says.
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
## The sweep shrinks with it (see `mouth_extent`). It used not to, on the grounds that a bag
## hanging clear of the surface makes no promise about the water — but the player reads the
## net they can see, and a haul taking pieces well outside it read as the net lying.
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

## How far a throw steps while looking for the first place along it that a cast stops being
## legal, in tiles. `_reach_along` walks in these, and the aiming marker is what it feeds.
const RING_STEP := 0.2

## The hauled net is drawn as a bending sheet rather than a rigid picture: this is how many
## quads across and down it is cut into.
##
## Six by four is enough to bend smoothly at the size a net is drawn on this lake and cheap
## enough to lay out every frame — one triangle array, one draw call, like everything else
## here that moves.
const WARP_COLS := 6
const WARP_ROWS := 4

## How far the rim tips and how far the belly trails, as fractions of how tall the frame is
## drawn, at full lean.
##
## Tip and trail together are the whole of "it is being dragged". The rim nearest the rod
## lifts towards the rope while the loaded body lags behind it — a net pulled through water
## leads with its near edge, and one that only shrank read as a picture being scaled.
const LEAN_TIP := 0.22
const LEAN_TRAIL := 0.18

## How much lean an empty net has, against a full one, and how fast the lean follows the
## pull. Eased rather than set, so a net that changes direction or speed bends into it
## instead of snapping over.
const LEAN_EMPTY := 0.45
const LEAN_EASE := 7.0

## How deep the loaded belly sags and how far it spreads, as fractions of the drawn frame.
## Both run on how full the hold is: an empty net is taut, a full one hangs heavy.
const BULGE_DEEP := 0.34
const BULGE_WIDE := 0.14

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
const ROPE_POINTS := 11
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
## is pulled. Both numbers are fractions of the **crown's own width** (`tools/slice_net.gd`
## measures it, see `_crown`), not of the frame: the crown is where the rope belongs and the
## crown is what the rope should be scaled against, so a net drawn at any size gets a bridle
## in proportion to the ring it is tied to.
##
## `BRIDLE_SQUASH` flattens the ring the bridles land on, because the crown is a circle seen
## from above at the same angle as everything else here. Bridles to the far side of it draw
## at `BRIDLE_FAR`, as if seen through the mesh.
## `HORN_LIFT` is deliberately small. At a third of the crown's width the line met the net
## well above the apex and the whole thing read as a net being winched up from overhead
## rather than dragged across water — the horn has to sit just clear of the crown, close
## enough that the bridle is a gather and not a suspension.
const HORN_LIFT := 0.08
const HORN_LEAN := 0.12
## `BRIDLE_REACH` is how far out across the crown the little ropes land, as a share of its
## measured half-width. Well under one, by decision: the bridle gathers the very middle of
## the apex, and lines reaching the crown's own edge read as a second, smaller net drawn on
## top of the first. They are thinner than the hand line for the same reason — a bridle is
## cord where the haul line is rope.
const BRIDLES := 6
const BRIDLE_REACH := 0.42
const BRIDLE_WIDE := 1.0
const BRIDLE_FAR := 0.45
const BRIDLE_SQUASH := 0.25

## Where the crown sits and how wide it is when the art does not say — the middle of the
## frame's top edge, and a little under half its width. Only reached with a `net_frames.json`
## cut before crowns were measured; the game still runs, the rope still ties on.
const CROWN_FALLBACK := Vector3(0.5, 0.06, 0.4)

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

## Where the pad's reticle stands, in world pixels, or INF when the mouse is aiming. Set by
## the lake every frame (`Lake._pad_tick`); `aim_point` is the one place the net asks.
var pad_aim := Vector2.INF
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

## How hard the net is leaning into the pull, 0 lying flat and 1 bent right over, and which
## way the rope is pulling it in world coordinates. Both eased towards where they should be
## rather than set, so the bend follows the haul instead of flicking about with it.
var _lean: float = 0.0
var _pull := Vector2.RIGHT

## The triangles of the warped sheet, in the order its points are laid out. The points move
## every frame; how they are joined up never does.
var _warp_faces := PackedInt32Array()

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


func _ready() -> void:
	position = Vector2.ZERO
	if angler != null:
		tile_pos = angler.tile_pos
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
			# Where the apex is in this frame and how wide it runs, as fractions of the
			# frame's own box, so it survives the frame being drawn at any size.
			var crown := CROWN_FALLBACK
			if cell.has("crown_x"):
				crown = Vector3(
					(float(cell["crown_x"]) - region.position.x) / maxf(region.size.x, 1.0),
					(float(cell["crown_y"]) - region.position.y) / maxf(region.size.y, 1.0),
					float(cell["crown_w"]) / maxf(region.size.x, 1.0)
				)
			frames.append({
				"region": region,
				"crown": crown,
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
	return maxi(hold + luck_hold - catch.size(), 0)


## The heaviest tier this cast lifts: the net's own, and the lucky haul's tier on top.
func strength() -> int:
	return power + luck_power


## Is this cast a lucky one?
func lucky() -> bool:
	return luck_power > 0 or luck_hold > 0


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
	_burn_down(delta)
	_lean_into_pull(delta)
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
					sfx.play_net_splash()
				# What the ring came down on is caught as it lands, not a frame into the haul
				# after the mouth has already slid off it.
				_sweep()
		State.REELING:
			_advance_towards(angler.tile_pos, reel_speed, delta)
			_sweep()
			# Whatever the mouth cannot lift is pushed out of its way instead, the way a hull
			# parts the rubbish it passes. Straight after the sweep, so a piece is only ever
			# shoved once the net has established it is not taking it.
			_shove_aside(delta)
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
	# After the net has moved and before anything is drawn, so the rope hangs off where the
	# net is this frame rather than where it was.
	_drive_rope(delta)
	_chime_at_finds()
	_repaint()


## The chime rings on for as long as the aim marker is over a shining find, buried or
## uncovered, and the last ring finishes after it leaves (2026-09-15, Richard; `Sfx.hover_find`).
## The marker is up while a cast is out too, so this is too; not on the double cast's second
## net, which draws no marker, and not while a board is over the water and the angler is held.
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
		sfx.play_net_splash()
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
	var at := world_pos()
	var mouth := mouth_extent()

	# Every bird sat inside the mouth, without exception: a perched pigeon is on top of
	# everything, the hold has no say in it, and one left bobbing inside the ring the player
	# just closed reads as the net passing through it.
	if flock != null:
		for perched in _birds_touched(at, mouth):
			caught_bird.emit(flock.take(perched))

	# Charms, on the same terms as the birds: on top of everything, free to lift, and gone
	# from the water the instant the mouth passes over them. They are the whole reason the
	# second lake is worth casting into, so nothing about the net's strength or its hold
	# gets a say in whether one is picked up.
	if charms != null:
		for i in range(charms.charms.size() - 1, -1, -1):
			if not charms.is_up(charms.charms[i]):
				continue
			var drawn := charms.footprint(i)
			if not _touches(at, mouth, drawn[0], drawn[1]):
				continue
			var kind := charms.take(i)
			if splash != null:
				splash.splash(_within_mouth(drawn[0]), 0.4)
			if sfx != null:
				# The same weight the drawn splash is given: a charm comes out of the water
				# like anything else, and the knock that used to stand in for it is cut.
				sfx.play_splash(0.4)
			caught_charm.emit(kind)

	# Only the rubbish is limited by what the net can hold. A bird and a charm are lifted
	# off the surface by a net that is already full, which is why the hold is not checked
	# until here: a cast that swept over a charm and left it floating because it had three
	# lumps of tar in it would read as the net being broken.
	if room_left() <= 0:
		return
	# Asked again for each layer: what a take uncovers is a new piece at a new size and pose,
	# and whether the mouth touches it is a new question.
	var before := catch.size()
	for layer in SWEEP_LAYERS:
		_take_from(_reach(at, mouth, strength()))
	if catch.size() > before:
		swept.emit(at, catch.size() - before, hold + luck_hold, mouth)


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
## enough to lift it and there is room left in the cast.
func _take_from(reach: Array[int]) -> void:
	for index in reach:
		if room_left() <= 0:
			return
		var k := grid.reachable_slot(index, 1, strength())
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


func _come_home() -> void:
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


## Where the rope is tied to the net: the horn, hanging over the crown — the gathered apex
## the drawing itself shows the net being hauled from.
##
## Four anchors have been tried and this is the one the picture asked for all along. It ended
## at the top of the frame's box (a point in the air above a net lying flat); then at that
## plus a guess at the lean (which came apart from the mesh the moment the net bent); then on
## the rim at the edge facing the rod (on the net at last, but a line tied to one point of a
## hoop); and now over the crown, with `_bridle_points` fanning onto the crown ring.
func _line_end(at: Vector2) -> Vector2:
	var laid := _crown_frame()
	if laid.is_empty():
		return at
	var size: Vector2 = laid[0]
	var crown: Vector3 = laid[2]
	var wide := crown.z * size.x
	return (
		_warp_point(at, size, float(laid[1]), crown.x, crown.y)
		- Vector2(0.0, HORN_LIFT * wide)
		+ _pull * HORN_LEAN * wide * _lean
	)


## The bridle: pairs of points, horn to crown ring, for `BRIDLES` lines spaced round it. The
## near half in `near`, the far half in `far`, so the far ones can be drawn as if through the
## mesh. Empty with no art.
##
## Onto the crown, never to the rim. A line from the apex to the edge of the net is a line
## drawn straight across the mesh — the thing it is supposed to be gathering — and at any
## size the net is drawn it crosses most of the picture. The real bridle is short, and lives
## in the dense part of the weave.
##
## Every point goes through `_warp_point`, so the bridle bends with the net it is tied to.
func _bridle_points(
	at: Vector2, horn: Vector2, near: PackedVector2Array, far: PackedVector2Array
) -> void:
	var laid := _crown_frame()
	if laid.is_empty():
		return
	var size: Vector2 = laid[0]
	var hang := float(laid[1])
	var crown: Vector3 = laid[2]
	var half := crown.z * 0.5 * BRIDLE_REACH
	# Flattened the way everything on this plane is, and converted into the frame's own
	# coordinates: a fraction of the width across, of the height down.
	var drop := half * BRIDLE_SQUASH * size.x / maxf(size.y, 1.0)
	for i in BRIDLES:
		# Offset by half a step, so no line sits exactly on the widest points of the ring,
		# where it would lie along the drawn cord of the mesh itself.
		var angle := TAU * (float(i) + 0.5) / float(BRIDLES)
		var lean := sin(angle)
		var on_ring := _warp_point(
			at, size, hang, crown.x + cos(angle) * half, crown.y + lean * drop
		)
		if lean >= 0.0:
			near.append(horn)
			near.append(on_ring)
		else:
			far.append(horn)
			far.append(on_ring)


## The frame the rope is being tied to, as `[size, hang, crown]`, or empty with no art. Both
## the horn and its bridle ask for this, and they have to be given the same answer.
func _crown_frame() -> Array:
	var pose := _pose()
	if pose[0] == &"":
		return []
	var index := _frame_at(pose[0], pose[1])
	var box := _frame_box(pose[0], index, _draw_span())
	var frame: Dictionary = (_art[pose[0]] as Dictionary)["frames"][index]
	return [box[0], float(box[1]), frame["crown"] as Vector3]


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
	var pointer := aim_point()
	var legal := in_reach(pointer)
	# The open mouth, not the one being pursed: the ring is the next throw, which lands wide
	# open, so it must not shrink with the net coming home.
	var span := open_extent()

	# A lit net has two casts in it, so the preview shows both: the mouth this click would
	# scoop with, and inside it the patch the other button would leave burning. Neither
	# replaces the other, because neither action replaces the other.
	if legal and enchanted() and state == State.IDLE:
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
	# The backing goes down first, carrying its share of whatever the coloured line carries,
	# so the dashed out-of-range ring is backed as faintly as it is drawn.
	var back := Color(AIM_BACK.r, AIM_BACK.g, AIM_BACK.b,
		AIM_BACK_SHARE * alpha / AIM_ALPHA)
	if legal:
		draw_polyline(ghost, back, AIM_BACK_WIDE)
		draw_polyline(ghost, ink, 1.5)
	else:
		# Dashed, because a refused throw is a rule rather than a thing on the water — the
		# same reason the laid-net ghost is dashed.
		for i in 24:
			draw_line(ghost[i * 2], ghost[i * 2 + 1], back, AIM_BACK_WIDE)
		for i in 24:
			draw_line(ghost[i * 2], ghost[i * 2 + 1], ink, 1.5)


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
	var foot := _line_end(world_pos())
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
		_shine([])
		_draw_aim()
		return

	var at := world_pos()
	var mouth := mouth_extent()
	var pose := _pose()
	var drawn: StringName = pose[0]

	# The rope, as `_drive_rope` left it this frame: from the hands to the horn over the net,
	# and the bridle from the horn down to the rim.
	var near := PackedVector2Array()
	var far := PackedVector2Array()
	if _rope_now.size() >= 2:
		_bridle_points(at, _rope_now[_rope_now.size() - 1], near, far)
	_lay_rope(_rope_now, near, far)

	# The catch always goes under the net, open mouth or closed bag. The whole read of a
	# netted load is that the junk is inside the mesh, and junk drawn over the mesh is junk
	# sitting on top of a picture of a net — which is what a landed net used to look like.
	# The drawing is a line net over a keyed mask, so what is behind it still shows through.
	#
	# Up into the body of the bag rather than down past its weights: the junk is what the
	# net is holding, so it belongs in the tube above the rim it hangs from.
	# And it rides in the belly, which is not where it was drawn before: the bag now bends
	# away from the pull and sags under what is in it, and a load left hanging in the middle
	# of the frame would be a load hanging outside the net holding it.
	_draw_catch(
		at - Vector2(0.0, _frame_height() * CATCH_INSIDE * shut) + _belly(),
		mouth
	)
	if drawn != &"":
		_draw_net(drawn, pose[1], at, mouth, ink)
	else:
		_draw_mesh(at, mouth, ink)

	# The aim stays up while the cast is out (Richard, 2026-09-14): the next throw is being
	# lined up while this one comes home, and with a pad the ring is the only pointer there
	# is. Over the net, so the net cannot hide it. Not on the double cast's second net, which
	# would draw the same ring twice.
	if not helper:
		_draw_aim()


## How full the cast is, 0 to 1. What the bulge, the lean and the purse all bend on.
func _load() -> float:
	return clampf(float(catch.size()) / maxf(float(hold), 1.0), 0.0, 1.0)


## Where the inside of the bag has moved to: back against the pull, and down under the load.
## The catch is placed against this rather than against the middle of the frame.
func _belly() -> Vector2:
	var tall := _frame_height()
	return (
		-_pull * LEAN_TRAIL * tall * _lean * 0.6
		+ Vector2(0.0, BULGE_DEEP * tall * _load() * 0.45)
	)


## The net itself. One frame of whichever sequence it is in, tinted to the lake's ink: the
## sheets are line drawings keyed to a mask, so the colour is the game's rather than the
## paper's.
func _draw_net(name: StringName, through: float, at: Vector2, mouth: float, ink: Color) -> void:
	var tint := Color(ink.r, ink.g, ink.b, 0.92)
	# A lucky cast is drawn in the finds' gold, so the roll is seen on the net itself.
	if lucky():
		tint = LakeGrid.GLINT_TINT.lerp(tint, 0.35)
	# A net in the air is a picture; a net in the water is a thing being pulled. Only the
	# second one bends, and only once there is something to bend it.
	if state == State.FLYING or (_lean <= 0.001 and _load() <= 0.001):
		_draw_frame(name, through, at, _draw_span(), tint)
		return
	_draw_warped(name, through, at, _draw_span(), tint)


## The net as a bending sheet: the frame cut into quads whose corners are moved, laid out as
## one triangle array.
##
## Three things move them, and each says something the flat picture could not. The rim tips
## towards the rope, so the net leads with the edge being pulled. The body trails behind it,
## because water does not let a loaded bag keep up with the line. And the belly sags and
## spreads with the load, which is the only thing on screen that says a net is full before
## its catch is looked at.
##
## The picture itself is untouched — this is the landed net, the one the cast has been
## showing since the splash, not the drag sheet (see the note on that above).
func _draw_warped(name: StringName, through: float, at: Vector2, span: float, tint: Color) -> void:
	var index := _frame_at(name, through)
	var box := _frame_box(name, index, span)
	var size: Vector2 = box[0]
	var hang := float(box[1])
	var region: Rect2 = (_art[name] as Dictionary)["frames"][index]["region"]
	var sheet := _sheet.get_size()

	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	var colours := PackedColorArray()
	for row in WARP_ROWS + 1:
		var v := float(row) / float(WARP_ROWS)
		for col in WARP_COLS + 1:
			var u := float(col) / float(WARP_COLS)
			points.append(_warp_point(at, size, hang, u, v))
			uvs.append(
				(region.position + Vector2(u * region.size.x, v * region.size.y)) / sheet
			)
			colours.append(tint)

	RenderingServer.canvas_item_add_triangle_array(
		get_canvas_item(), _warp_faces_of(), points, colours, uvs,
		PackedInt32Array(), PackedFloat32Array(), _sheet.get_rid()
	)


## One point of the bending sheet: where the frame's (`u` across, `v` down) lands once the
## lean and the load have moved it, for a frame `size` big whose rim sits `hang` of the way
## down it, centred on `at`.
##
## The mesh and the rope's anchor both come through here, and that is the whole reason it is
## a function of its own: a rope tied to a rim worked out by any other maths comes untied the
## moment the net bends.
func _warp_point(at: Vector2, size: Vector2, hang: float, u: float, v: float) -> Vector2:
	var load := _load()
	var tip := LEAN_TIP * size.y * _lean
	var trail := LEAN_TRAIL * size.y * _lean
	var sag := BULGE_DEEP * size.y * load
	var widen := BULGE_WIDE * size.x * load
	# 0 at the rim, 1 at the bottom of the frame: how much of the bag's body this point is.
	var deep := clampf((v - hang) / maxf(1.0 - hang, 0.001), 0.0, 1.0)
	var across := (u - 0.5) * 2.0
	var p := at + Vector2(across * size.x * 0.5, (v - hang) * size.y)
	# The rim tips: the side the rope is on lifts, the far side settles into the water.
	# Fading with depth, because it is the rim being lifted and not the whole bag.
	p.y -= tip * across * signf(_pull.x) * (1.0 - deep * 0.65)
	# The body lags behind the pull.
	p += -_pull * trail * deep
	# And hangs heavier and wider the fuller it is, deepest in the middle.
	p.y += sag * deep * sin(PI * u)
	p.x += widen * across * deep
	return p


## How the warped sheet's points are joined into triangles. Worked out once: the points move
## every frame, the weave does not.
func _warp_faces_of() -> PackedInt32Array:
	if not _warp_faces.is_empty():
		return _warp_faces
	for row in WARP_ROWS:
		for col in WARP_COLS:
			var a := row * (WARP_COLS + 1) + col
			var b := a + 1
			var c := a + WARP_COLS + 1
			_warp_faces.append_array(PackedInt32Array([a, c, b, b, c, c + 1]))
	return _warp_faces


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
		spots.append(at + Vector2(
			cos(angle) * maxf(mouth - half.x, 0.0),
			sin(angle) * maxf(mouth * 0.5 - half.y, 0.0)
		) * out)
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
