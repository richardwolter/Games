## The angler: the player, standing on the island.
##
## The whole game is cast from wherever this character happens to be, so walking is not
## flavour — the north shore of the lake is only fishable from the north side of the
## island, and every step is a decision about what water is in range.
##
## Kept in tile coordinates and projected for drawing, the same as the boat, so "how far
## the net reaches" stays one number in tile units rather than a pixel distance that has
## to be converted at every use. There is no physics and no collision shape: staying on
## land is a question asked of Iso.island_fraction before each step, which is cheaper and
## cannot ever wedge the character inside geometry.
class_name Angler
extends Node2D

## Tiles per second. Unhurried, not slow: where you stand is a decision and it should cost
## something to change, but the island is only nine tiles across and at the old 3.2 that
## decision cost more waiting than thinking.
const WALK_SPEED := 5.4

## How long it takes to reach WALK_SPEED from a standstill, and to shed it again, in seconds.
##
## Instant used to read like a cursor rather than a person: the boots were at full speed on
## the frame a key went down and dead stopped on the frame it came up. A tenth of a second of
## give either way is short enough that placing the angler for a cast still feels immediate,
## and long enough that starting and stopping reads as a body with some heft to move.
const ACCEL_TIME := 0.12
const ACCEL := WALK_SPEED / ACCEL_TIME

## How far out the character may walk past the waterline, in world pixels.
##
## Barely any: the last step off the beach wets the boots and no more. The water is drawn to
## a line a little inside this one, so six pixels past the island's own outline puts the
## angler at the water rather than in it.
##
## Pixels, not a fraction of the island's radius as it used to be. A fraction is a different
## distance at every angle once the projection has stretched one diagonal against the other:
## at 1.06 the angler could paddle four tenths of a tile out on the eastern shore and barely
## a tenth on the northern one, and the bigger the island got the worse the gap. See
## `Iso.past_island`.
const WALK_LIMIT := 6.0

## How much of the figure the water swallows once it is past the waterline, in source pixels
## at the far end of that step out.
##
## Knee deep is a fact about the picture, not about the walking rule: the boots have to
## disappear into the surface or the angler is standing on the water. Taken off the bottom of
## the drawn sprite rather than by sinking it, so the head stays where the walk cycle put it
## and only the legs go under. Nine of the figure's twenty source pixels: knee deep, which
## takes the boots, the ankles and most of the shin and leaves the stride still readable above
## the water.
const WADE_SINK := 9.0

## How far the figure's feet sink into dry ground, in screen pixels. Small: this is the
## difference between standing on a tile and standing on top of it, not a second wade.
##
## Pixels rather than source pixels off the sheet, unlike WADE_SINK — that one cuts the art
## itself so the waterline lands on a whole source pixel; this one only moves where the whole
## picture is drawn, so it costs nothing to keep it a fraction of a screen pixel.
const LAND_SINK := 2.0

## How many source pixels of the ground under a walking step the boots leave a print in, in
## world pixels, and how far to the side of the last one the next one lands.
##
## Spaced by distance rather than by frame or by time, so a print lands the same distance
## apart whether the angler is easing up to speed or already at it. The offset alternates a
## print from each boot, the same distance either way, so the trail reads as two feet and not
## one dragged foot.
const PRINT_SPACING := 15.0
const PRINT_OFFSET := 3.0

## The lake's own splash system, handed over by the level. Null until then, and everything
## that uses it says so — the angler walks the same whether or not the water is drawn.
var splash: WaterSplash

## The island's trail of footprints, handed over the same way. Null until then, and walking
## works the same either way — the marks are a nicety, not a thing the walk depends on.
var prints: Footprints

## The rings of water round the ankles of somebody standing in the shallows: how many are
## in the air at once, how long each takes to spread and fade, how wide it gets, and how
## often the drawing is asked to move them on.
##
## Drawn rather than thrown at the splash system, which is for the net: a splash is an event
## and this is a state — the water is disturbed for as long as the boots are in it, and that
## is a ring or two spreading and going again, forever, for nothing.
const RIPPLE_RINGS := 2
const RIPPLE_PERIOD := 1.7
const RIPPLE_FROM := 7.0
const RIPPLE_TO := 30.0
const RIPPLE_STEP := 0.05

## The wake left by wading: how wide a ring, and how often one is shed while moving.
##
## The rings above are what standing in water looks like; this is what moving through it
## looks like, and it is the same trail the net leaves when it is dragged home — see
## `WaterSplash.wake`. Shed by time rather than by distance, which is the water's own rule
## and not this file's business.
const WAKE_SPAN := 16.0
const WAKE_EVERY := 0.15

## How tall the figure draws, in pixels — asked for rather than promised. The drawing is
## scaled by whole source pixels (see `_draw`), so what comes out is the nearest whole
## multiple of the 20px figure inside the cell: forty.
##
## It was 34, which is 1.7 of those twenty pixels. Godot filters canvas textures bilinearly
## unless told otherwise, and 1.7 of a pixel means some source pixels land on two screen
## pixels and some on one, in a beat all the way down the figure — which is why the angler
## read as soft and slightly out of focus while the rubbish floating past it, drawn at one to
## one, read as sharp.
const HEIGHT := 40.0

## The cut sheets. tools/slice_character.gd writes them.
const ART := "res://assets/character.json"

## What takes the raw sheet's colour down into the game's own. Its numbers are uniforms, so
## they can be turned while the game is running.
const TONE := "res://shaders/figure.gdshader"

## How much the side view is favoured over the front and back ones. Under 1, so a walk has
## to be close to straight up or down the screen before it stops being a walk across it.
##
## Without it the four diagonals land almost exactly on the boundary — the projection makes
## a diagonal step very nearly equal parts across and into the view — so the figure flickers
## between two rows on every frame that floating point rounds the other way. That is the dead
## band: not a direction with no sprite, but two sprites arguing over one direction.
const SIDE_FAVOUR := 0.5

## Seconds a frame is held, standing and walking. Walking is quicker because it is: the
## sheet is a six-frame stride and it has to keep up with the feet.
const IDLE_FRAME := 0.24
const WALK_FRAME := 0.1

## The straw hat: the picture of it, how wide it is drawn against the figure's height, and how
## far below the top of the head its brim sits.
##
## Worn rather than painted into the sheet, because the sheet is six frames of a stride in
## three views and a hat added to it is eighteen small paintings that have to agree with each
## other. This is one picture that rides the head it is measured off — see `_draw_hat` — so it
## keeps its place through a walk cycle nobody had to repaint.
##
## It was drawn out of polygons here until Richard painted one. tools/slice_hat.gd takes his
## page, keys it, and puts the blocks back down to one pixel each.
const HAT_ART := "res://assets/straw_hat.png"
const HAT_WIDE := 0.70
const HAT_SIT := 0.375

## How far the hat leans the way the angler is looking, as a fraction of HEIGHT. Only the
## side view: from the front and the back a hat sits square, and a straw hat worn at a slant
## on a twelve-pixel head reads as a hat falling off.
const HAT_LEAN := 0.0

## How far the hat is lifted off its brim line in each view, in source pixels. Positive puts
## it lower.
##
## Sideways it needed nothing at all — the head mark the slicer writes per frame is where the
## hat goes, and every hand-set sideways nudge tried here was undoing an error that was not
## there. What the side view does want is a pixel of lift: the head is turned, so the brim
## crosses it higher than it does head-on. Placed on the drawn frames rather than reasoned
## about, and the rig that placed them is in Claude outputs/hat_lab.html.
const HAT_LIFT_FRONT := 0.0
const HAT_LIFT_BACK := 0.0
const HAT_LIFT_SIDE := -1.0

## Straw, for the blocked-in figure only: with no art at all there is no hat picture either,
## and a hat is the one thing that separates the placeholder from a post.
const HAT_STRAW := Color(0.87, 0.71, 0.38)


## Where the angler stands, in tile coordinates. Just south of the shed rather than in the
## middle of the island, because the middle of the island is now where the shed is.
var tile_pos := Vector2(Iso.ISLAND_CENTRE.x + 1.3, Iso.ISLAND_CENTRE.y + 1.3)

## Which way they are turned, on the plane. It picks which of the drawn views is shown, and
## it is where a cast leaves from.
var facing := Vector2(0.0, 1.0)

## Set false while the shop is open, so walking does not happen behind the panel.
var can_walk: bool = true

## Where the yard crate stands, in tiles, or INF for a scene with no crate in it. Set by the
## lake once the yard has been put down.
##
## The dog used to be in here too, as a thing to keep out of. It is not any more: an animal
## that wanders about the island and pushes back is an animal in the way, and the island is
## small. It can be walked through.
var crate_tile := Vector2.INF

## How near the middle of the crate a walker may get, in tiles. The box is about 1.3 tiles
## across on the plane, so this is its own footprint and no more.
const CRATE_KEEP := 0.7

var _time: float = 0.0
var _step: float = 0.0

## Tiles a second, eased towards WALK_SPEED (or zero) rather than snapped to it. See
## ACCEL_TIME.
var _speed: float = 0.0

## Bookkeeping for the footprint trail: where the last mark was drawn from, how far the boots
## have come since, and which foot is due next.
var _last_print_pos := Vector2.ZERO
var _dist_since_print: float = 0.0
var _print_left: bool = false

## Which frame was last painted, so a frame that has not turned over is not painted twice.
var _painted: int = 0

## Pose name -> its frames, each `{region, ink}`. Empty when the art is missing, which drops
## the whole node back to the blocked-in figure it was drawn as before there was any.
## The sheet, and the same sheet turned over.
##
## A second texture rather than a flip at draw time. Both ways of asking for one — a
## destination rectangle with a negative width, and a canvas transform scaled by minus one —
## went through without complaint and drew the sprite exactly as it was, so the angler faced
## the same way whichever direction they walked. A mirrored copy of a 192 by 192 sheet costs
## nothing and cannot quietly not happen.
var _sheet: Texture2D
var _mirror: Texture2D

## The hat. Its own picture, so it is not cut from the character sheet and not redrawn per
## frame; null when the file is missing, and then the angler goes bare-headed rather than the
## game falling over.
var _hat: Texture2D
var _sheet_wide: float = 0.0
var _poses := {}

## How tall the figure draws inside its cell and where its feet sit in it, taken once from
## one frame and used for every frame.
##
## Once, not per frame, and this is the whole of why the figure used to jump about. The
## drawing breathes inside its cell — nineteen pixels tall on one frame and twenty on the
## next, six from the top on one and seven on another — so scaling each frame to its own ink
## made the angler pulse in size and shift on the spot every time the frame changed. The cell
## is what holds an animation still. Measuring past it throws that away.
var _stand_tall: float = 20.0
var _stand_foot: float = 26.0


func _ready() -> void:
	# Nearest, and only here. The figure is magnified — two screen pixels per pixel of art —
	# and a filter that blends between them throws away exactly what makes it pixel art. Not
	# set on the project: the piers are drawn at four tenths of their size and the hut at half
	# of its, and nearest on a shrink with no mipmaps sets both of them crawling.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_wear_tone()
	_load_art()
	stand_at(tile_pos)


## Put the angler in the same air as the rest of the lake. See shaders/figure.gdshader.
func _wear_tone() -> void:
	var shader := load(TONE) as Shader
	if shader == null:
		return
	var worn := ShaderMaterial.new()
	worn.shader = shader
	material = worn


## Put the angler somewhere, and make sure it is somewhere they can be.
##
## Setting `tile_pos` on its own is not enough and was the whole of a bug: loading a save
## moved the angler without moving the drawn figure, so it stood at the spawn until the
## first step and then jumped across the island to catch up. It also has to be a legal
## place — a save written before the shed was there puts them in the middle of it.
func stand_at(tile: Vector2) -> void:
	tile_pos = _nearest_standing(tile)
	_place()
	_last_print_pos = position


## The nearest spot to this one that is on the grass and not inside the shed, found by
## walking out from the island's middle the way the asked-for spot already leans. Anywhere
## legal is returned untouched.
func _nearest_standing(tile: Vector2) -> Vector2:
	if Iso.past_island(tile) < WALK_LIMIT and not Iso.in_shed(tile.x, tile.y, Iso.SHED_KEEP):
		return tile
	var away := tile - Iso.ISLAND_CENTRE
	# Dead centre has no direction to lean; south-east is where the door faces.
	if away.length_squared() < 0.0001:
		away = Vector2(1.0, 1.0)
	away = away.normalized()
	for step in 60:
		var out := Iso.ISLAND_CENTRE + away * (0.1 * float(step))
		if Iso.past_island(out) < WALK_LIMIT and not Iso.in_shed(out.x, out.y, Iso.SHED_KEEP):
			return out
	return tile


## Read the cut sheets. False means no art and the placeholder stands in, the same bargain
## the net and the flock strike with theirs.
func _load_art() -> bool:
	var text := FileAccess.get_file_as_string(ART)
	if text.is_empty():
		return false
	var book: Dictionary = JSON.parse_string(text)
	if book == null or not book.has("poses"):
		return false
	var image := Art.image(book["sheet"])
	if image == null:
		return false
	_sheet = ImageTexture.create_from_image(image)
	_sheet_wide = float(image.get_width())
	var turned := Image.create_from_data(
		image.get_width(), image.get_height(), false, image.get_format(), image.get_data()
	)
	turned.flip_x()
	_mirror = ImageTexture.create_from_image(turned)
	_hat = Art.texture(HAT_ART)

	for name: String in book["poses"]:
		var frames: Array = []
		for cell: Dictionary in book["poses"][name]:
			var region: Array = cell["region"]
			var ink: Array = cell["ink"]
			frames.append({
				"region": Rect2(region[0], region[1], region[2], region[3]),
				"ink": Rect2(ink[0], ink[1], ink[2], ink[3]),
				# Where this frame's head is across its cell, in source pixels. See
				# tools/slice_character.gd.
				"head": float(cell.get("head", 0.0)),
			})
		_poses[StringName(name)] = frames

	# The one frame everything is registered against: the angler standing still, facing the
	# camera. Any frame would do — that is the point of them sharing a grid — and a named one
	# is easier to go and look at than "the first one that happened to load".
	if _poses.has(&"idle_front"):
		var ink: Rect2 = ((_poses[&"idle_front"] as Array)[0] as Dictionary)["ink"]
		_stand_tall = maxf(ink.size.y, 1.0)
		_stand_foot = ink.position.y + ink.size.y
	return not _poses.is_empty()


## Where the line is drawn from and where the net comes home to, in world space.
##
## Still called the rod tip, and there is still no rod: the sprite holds nothing, and drawing
## one over it put a stick through the figure that read as part of the character being wrong.
## The line has to leave from somewhere in front of them either way, and this is that point.
func rod_tip() -> Vector2:
	return position + Vector2(facing.x - facing.y, (facing.x + facing.y) * 0.5).normalized() \
		* 16.0 + Vector2(0.0, -HEIGHT * 0.72)


func _place() -> void:
	position = Iso.tile_to_world(tile_pos.x, tile_pos.y)


func _process(delta: float) -> void:
	_time += delta

	# The arrows and WASD both feed these, which is what the walk_* actions are for. See
	# the [input] block in project.godot.
	var push := Vector2.ZERO
	if can_walk:
		push = Vector2(
			Input.get_axis(&"walk_left", &"walk_right"),
			Input.get_axis(&"walk_up", &"walk_down")
		)
	if push == Vector2.ZERO:
		_step = 0.0
		_speed = move_toward(_speed, 0.0, ACCEL * delta)
		_repaint()
		return

	# Read in screen space and turned into tile space, so "press right" walks right on
	# screen rather than along a diagonal the player cannot see.
	var step := Iso.world_to_tile(push.normalized() * Iso.TILE_W).normalized()
	facing = step
	_speed = move_toward(_speed, WALK_SPEED, ACCEL * delta)
	var wanted := tile_pos + step * _speed * delta
	if _can_stand(wanted):
		tile_pos = wanted
	else:
		# Blocked head-on. Try each axis alone, so walking into the shore slides along it
		# instead of sticking — the island is a wobbly ellipse and a hard stop on it feels
		# like a bug every time.
		var slide_x := tile_pos + Vector2(step.x, 0.0) * _speed * delta
		var slide_y := tile_pos + Vector2(0.0, step.y) * _speed * delta
		if _can_stand(slide_x):
			tile_pos = slide_x
		elif _can_stand(slide_y):
			tile_pos = slide_y
	_step += delta
	_wake()
	_place()
	_leave_print()
	_repaint()


## How many source pixels of the figure are under water where it is standing, whole pixels.
##
## Nothing until the waterline and the full depth at the end of the step past it, which is as
## far out as `WALK_LIMIT` lets anyone go.
func _wading() -> float:
	var out := Iso.past_island(tile_pos)
	if out <= 0.0:
		return 0.0
	var into := clampf(out / maxf(WALK_LIMIT, 0.0001), 0.0, 1.0)
	return roundf(into * WADE_SINK)


## A ring of disturbed water behind the boots, if they are in the water at all.
func _wake() -> void:
	if splash == null or Iso.past_island(tile_pos) <= 0.0:
		return
	splash.wake(self, Iso.tile_to_world(tile_pos.x, tile_pos.y), WAKE_SPAN, WAKE_EVERY)


## A boot print in the sand or the grass, every PRINT_SPACING of ground actually covered.
##
## On dry land only — the water already answers "somebody just walked through here" with the
## ripples and the wake, and a print left on top of those would be one more mark nobody reads
## twice.
func _leave_print() -> void:
	var moved := position.distance_to(_last_print_pos)
	_last_print_pos = position
	if prints == null or Iso.past_island(tile_pos) > 0.0:
		return
	_dist_since_print += moved
	if _dist_since_print < PRINT_SPACING:
		return
	_dist_since_print = 0.0
	_print_left = not _print_left
	var on_screen := Vector2(facing.x - facing.y, (facing.x + facing.y) * 0.5)
	if on_screen.length_squared() < 0.0001:
		on_screen = Vector2(1.0, 0.0)
	on_screen = on_screen.normalized()
	var side := Vector2(-on_screen.y, on_screen.x) * PRINT_OFFSET * (1.0 if _print_left else -1.0)
	prints.mark(self, position + side, &"boot")


## Somewhere the angler may be: on the grass, and not inside the shed.
##
## The shed is the only solid thing on the island, and it is checked here rather than by any
## collision shape for the same reason the shore is — there is no physics in this game, and
## a question asked before each step cannot wedge the character inside anything.
func _can_stand(at: Vector2) -> bool:
	if Iso.past_island(at) >= WALK_LIMIT:
		return false
	# Not through the crate, and only just: a box a tile and a third across, with a keep-out
	# barely wider than its own planks. Enforced the way the hut is — on somebody who is not
	# standing in it already.
	if crate_tile != Vector2.INF and tile_pos.distance_to(crate_tile) >= CRATE_KEEP:
		if at.distance_to(crate_tile) < CRATE_KEEP:
			return false
	# Standing inside it already — an old save, or the shed being moved under them — means
	# every step out is also a step through, and refusing those leaves them walled in
	# forever. So the rule is only enforced on someone who is outside it.
	if Iso.in_shed(tile_pos.x, tile_pos.y, Iso.SHED_KEEP):
		return true
	return not Iso.in_shed(at.x, at.y, Iso.SHED_KEEP)


## Which of the three drawn views the angler is turned to, and whether it wants mirroring.
##
## Worked out in screen space rather than tile space. The player sees a plane at an angle and
## the sheet is drawn for a screen: what matters is whether the angler is walking across the
## view or into it, which is a question about the projected direction and not about the tiles
## underneath. There is only one side row, so one of the two ways along it is mirrored —
## which is why this answers with a name and a mirror rather than a compass point.
func _view() -> Array:
	var on_screen := Vector2(facing.x - facing.y, (facing.x + facing.y) * 0.5)
	if absf(on_screen.x) >= absf(on_screen.y) * SIDE_FAVOUR:
		# The row is drawn facing right, so it is a leftward walk that gets mirrored.
		#
		# Settled by looking at the game rather than at the sheet. Two goes at measuring it —
		# where the skin sits against the middle of the figure, and again against the middle
		# of just the head — both said the drawing faced left, and both were wrong: at twelve
		# pixels across, the hands are as much skin as the face is and a fringe weighs as
		# much as a nose. The thing being measured was too small to hold the answer.
		return [&"side", on_screen.x < 0.0]
	return [&"front" if on_screen.y > 0.0 else &"back", false]


## The angler, drawn from the sheets. Feet at the origin, so the figure stands on its tile
## rather than hovering over it, and scaled by how tall it draws rather than by its cell —
## the cell is mostly air and scaling to it would make the angler a different size the moment
## the art was redrawn with more headroom.
## Repaint only when a different frame of the angler would come out.
##
## Walking moves the node, and moving a node is not redrawing it: what changes in the
## picture is which frame of the walk or idle cycle is showing, and that turns over a
## handful of times a second, not sixty. Standing still it turns over slower still.
func _repaint() -> void:
	var key := _paint_key()
	if key != _painted:
		queue_redraw()


## Which frame of which pose is currently showing, as one number.
func _paint_key() -> int:
	var walking := _step > 0.0
	var held := WALK_FRAME if walking else IDLE_FRAME
	# How deep the boots are is part of the picture too: stepping into the shallows changes
	# what is drawn without changing which frame it is, and while they are in the water the
	# rings round them move on their own clock.
	var sunk := _wading()
	var rings := int(_time / RIPPLE_STEP) if sunk > 0.0 else 0
	return hash([walking, _view()[0], int(_time / held), sunk, rings])


## Rings of disturbed water round the feet, while any of the figure is under the surface.
##
## Flattened the same two to one as everything else lying on this plane, so a ring reads as a
## circle on the water rather than as a hoop standing up out of it. They spread and fade with
## how deep the boots are: a toe in the shallows barely marks the water and a step further out
## is a bootful.
func _draw_ripples(sunk: float) -> void:
	if sunk <= 0.0:
		return
	var deep := clampf(sunk / WADE_SINK, 0.0, 1.0)
	for i in RIPPLE_RINGS:
		var out := fposmod(
			_time / RIPPLE_PERIOD + float(i) / float(RIPPLE_RINGS), 1.0
		)
		var wide := lerpf(RIPPLE_FROM, RIPPLE_TO, out) * deep
		var fade := (1.0 - out) * 0.5 * deep
		if fade <= 0.01 or wide <= 1.0:
			continue
		_ring(Vector2.ZERO, Vector2(wide, wide * 0.5), Color(0.86, 0.94, 0.97, fade))


## One flat ellipse, drawn as an outline. Sixteen sides: on a ring thirty pixels across that
## is a step of about six pixels, which is under the size the water itself is drawn at.
func _ring(at: Vector2, extent: Vector2, colour: Color) -> void:
	var points := _oval(at, extent)
	points.append(points[0])
	draw_polyline(points, colour, 1.0)


func _draw() -> void:
	_painted = _paint_key()
	var sunk := _wading()
	# How far the figure sits into the ground it is standing on: LAND_SINK on dry land, nothing
	# once the boots are in the water — WADE_SINK already does that job there, by cutting the
	# picture down instead of moving it.
	var land_shift := 0.0 if sunk > 0.0 else LAND_SINK

	# The shadow, which is what puts them on the ground on a plane seen at an angle. Drawn
	# whether or not the art loaded: it is the contact point, not the figure. Tightened in a
	# little on the step, the same squash a boot planting down puts into a footprint — a shadow
	# that never moves under a figure that is visibly walking is the tell that it is a painted
	# disc rather than a shadow.
	var squash := 1.0 - 0.1 * absf(sin(_step * 11.0)) if _step > 0.0 else 1.0
	_blot(
		Vector2(0.0, land_shift), Vector2(14.0, 7.0) * squash, Color(0.0, 0.0, 0.0, 0.32)
	)

	# And the water they have disturbed, over the shadow and under the figure — the rings are
	# on the surface the boots are in, not on the boots.
	_draw_ripples(sunk)

	if _poses.is_empty():
		_draw_blocked()
		return

	var view := _view()
	var walking := _step > 0.0
	var pose: StringName = StringName(
		"%s_%s" % ["walk" if walking else "idle", view[0]]
	)
	if not _poses.has(pose):
		_draw_blocked()
		return
	var frames: Array = _poses[pose]
	var held := WALK_FRAME if walking else IDLE_FRAME
	var frame: Dictionary = frames[posmod(int(_time / held), frames.size())]
	var region: Rect2 = frame["region"]

	# Placed by the cell, not by what is drawn in it: the cell's middle over the origin and
	# its foot line on it. Every frame then lands where the artist put it, which is what the
	# grid is for.
	#
	# Whole source pixels only. HEIGHT says how big the angler should be and this says how big
	# it can be — the nearest whole number of screen pixels per pixel of art — so nothing, not
	# a change to HEIGHT nor a re-slice that measures the figure a pixel shorter, can quietly
	# put the blur back.
	var scale := maxf(1.0, roundf(HEIGHT / _stand_tall))

	# In the shallows, the bottom of the picture is under the surface. Whole source pixels, so
	# the cut lands on the same grid the figure is drawn on and the waterline does not crawl up
	# the boot half a pixel at a time.
	if sunk > 0.0:
		region = Rect2(region.position, Vector2(region.size.x, maxf(region.size.y - sunk, 1.0)))

	var size := region.size * scale
	var box := Rect2(
		Vector2(-size.x * 0.5, -_stand_foot * scale + land_shift), size
	)

	# One side row for two directions, so the other one comes off the turned-over sheet. The
	# frame is at the mirrored place in it — as far from the right edge as it was from the
	# left — and the box it goes in does not move, because it is centred on the angler.
	if bool(view[1]):
		draw_texture_rect_region(
			_mirror, box,
			Rect2(
				Vector2(_sheet_wide - region.position.x - region.size.x, region.position.y),
				region.size
			)
		)
	else:
		draw_texture_rect_region(_sheet, box, region)

	# Over the figure, and after it, because it is worn rather than drawn into the sheet.
	_draw_hat(box, frame["ink"], float(frame["head"]), scale, view)


## A length rounded onto the figure's own pixel grid.
##
## The hat is drawn rather than painted into the sheet, so nothing stops it having edges half
## a pixel thick and corners between pixels. Against a figure drawn honestly at two screen
## pixels per pixel of art, that is what would look wrong — a smooth shape sitting on pixel
## art. Every measurement of the hat goes through here, so its steps are the same size as the
## steps in the sprite under it.
func _on_grid(px: float, scale: float) -> float:
	return roundf(px / scale) * scale


## The straw hat, sat on whatever the head is doing this frame.
##
## The height it goes at comes off the frame's own ink box rather than off the cell: the
## drawing breathes inside its cell — that is the whole of the walk cycle's bob — and a hat
## pinned to the cell would hover above a bobbing head. The figure's size still comes from
## the cell, so this is not the pulsing `_stand_tall` guards against; only the one line the
## hat sits on follows the ink.
func _draw_hat(box: Rect2, ink: Rect2, head_at: float, scale: float, view: Array) -> void:
	if _hat == null:
		return
	# `ink` is measured inside its own cell, not on the sheet — see tools/slice_character.gd,
	# which subtracts the cell's corner before writing it. Taking it for a sheet coordinate
	# and subtracting that corner a second time put the hat a whole sheet-row above the
	# angler, floating out over the lake.
	var head := box.position.y + ink.position.y * scale
	# Over the head the slicer measured, not over the middle of the cell and not over the
	# middle of the ink.
	#
	# Three things were tried before this. The ink box's middle, which an outstretched arm or
	# a leg mid-stride drags off the head. The cell's middle, which is right from the front and
	# a pixel out from the back and the side. And a hand-set nudge, which cannot be right for
	# both at once — it centred the side views by pushing the front ones off. The sheet knows
	# where the head is; tools/slice_character.gd now writes it down per frame.
	#
	# Already in source pixels, so it is on the grid by construction. Mirrored with the sprite,
	# because the head goes the other way when the sheet is turned over.
	var middle := head_at * scale * (-1.0 if bool(view[1]) else 1.0)
	if StringName(view[0]) == &"side":
		middle += _on_grid(HEIGHT * HAT_LEAN, scale) * (-1.0 if bool(view[1]) else 1.0)

	# Sized off the figure and snapped to its pixels, so the hat is drawn at a whole number of
	# screen pixels per pixel of hat — the same bargain the character sheet gets, and the whole
	# reason the picture was cut down to its own grid by tools/slice_hat.gd.
	var art := _hat.get_size()
	var wide := maxf(scale, _on_grid(HEIGHT * HAT_WIDE, scale))
	var span := Vector2(wide, _on_grid(wide * art.y / maxf(art.x, 1.0), scale))
	# Hung by its brim rather than by its top: the brim is the line that has to sit on the
	# head, and how tall the crown is above it is the hat's business.
	var line := head + _on_grid(HEIGHT * HAT_SIT, scale) + lift_of(view) * scale
	draw_texture_rect(_hat, Rect2(Vector2(middle - span.x * 0.5, line - span.y), span), false)


## The lift for a view, in source pixels. Static and public: the shed draws the same hat on
## the same figure and reads it from here rather than keeping a second copy that can drift.
static func lift_of(view: Array) -> float:
	match StringName(view[0]):
		&"back":
			return HAT_LIFT_BACK
		&"side":
			return HAT_LIFT_SIDE
	return HAT_LIFT_FRONT


## The figure as it was blocked in before there were any sprites of it: kept because the art
## can be missing, and a game that will not run without its assets is a game with a fuse in
## it. Its rod went with the sprite's.
func _draw_blocked() -> void:
	var ink := Color(0.11, 0.09, 0.1)
	var bob := sin(_step * 11.0) * (2.0 if _step > 0.0 else 0.0)

	var legs := Rect2(-4.0, -HEIGHT * 0.46 + bob, 8.0, HEIGHT * 0.46)
	draw_rect(legs, Color(0.26, 0.30, 0.38))
	var body := Rect2(-7.0, -HEIGHT * 0.86 + bob, 14.0, HEIGHT * 0.42)
	draw_rect(body, Color(0.82, 0.52, 0.24))
	draw_rect(body, ink, false, 1.4)
	var head := Rect2(-5.0, -HEIGHT * 1.06 + bob, 10.0, HEIGHT * 0.21)
	draw_rect(head, Color(0.90, 0.76, 0.60))
	draw_rect(head, ink, false, 1.4)
	# A hat, because at this size the one thing that separates a person from a post is a
	# silhouette that is wider at the top.
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-9.0, -HEIGHT * 1.06 + bob), Vector2(9.0, -HEIGHT * 1.06 + bob),
			Vector2(5.0, -HEIGHT * 1.18 + bob), Vector2(-5.0, -HEIGHT * 1.18 + bob)
		]),
		HAT_STRAW
	)



## The shadow under the figure: a flat ellipse lying on the plane.
##
## It was four points — a diamond, the shape of a tile — which is right for a tile and wrong
## for a person: nothing about a standing figure has corners, and at twenty pixels across the
## two straight edges facing the camera read as a square patch of dirt rather than as shade.
## The same two-to-one flattening either way, so it still lies on the ground.
func _blot(at: Vector2, extent: Vector2, colour: Color) -> void:
	draw_colored_polygon(_oval(at, extent), colour)


## A flat ellipse as points, going round once. Sixteen sides: at the sizes anything here is
## drawn that is a step of a few pixels, which is finer than the art it sits under.
func _oval(at: Vector2, extent: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 16:
		var angle := TAU * float(i) / 16.0
		points.append(at + Vector2(cos(angle) * extent.x * 0.5, sin(angle) * extent.y * 0.5))
	return points
