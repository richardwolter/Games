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

## How far out the character may walk, as a fraction of the island's radius. Under 1, so
## they stop on the grass rather than paddling.
const WALK_LIMIT := 0.88

## How tall the figure draws, in pixels. The sprite is scaled by how tall it actually draws
## inside its cell rather than by the cell, so this stays the one number that says how big
## the angler is however the art is redrawn.
const HEIGHT := 34.0

## The cut sheets. tools/slice_character.gd writes them.
const ART := "res://assets/character.json"

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


## Where the angler stands, in tile coordinates. Just south of the shed rather than in the
## middle of the island, because the middle of the island is now where the shed is.
var tile_pos := Vector2(Iso.ISLAND_CENTRE.x + 1.3, Iso.ISLAND_CENTRE.y + 1.3)

## Which way they are turned, on the plane. It picks which of the drawn views is shown, and
## it is where a cast leaves from.
var facing := Vector2(0.0, 1.0)

## Set false while the shop is open, so walking does not happen behind the panel.
var can_walk: bool = true

var _time: float = 0.0
var _step: float = 0.0

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
	_load_art()
	stand_at(tile_pos)


## Put the angler somewhere, and make sure it is somewhere they can be.
##
## Setting `tile_pos` on its own is not enough and was the whole of a bug: loading a save
## moved the angler without moving the drawn figure, so it stood at the spawn until the
## first step and then jumped across the island to catch up. It also has to be a legal
## place — a save written before the shed was there puts them in the middle of it.
func stand_at(tile: Vector2) -> void:
	tile_pos = _nearest_standing(tile)
	_place()


## The nearest spot to this one that is on the grass and not inside the shed, found by
## walking out from the island's middle the way the asked-for spot already leans. Anywhere
## legal is returned untouched.
func _nearest_standing(tile: Vector2) -> Vector2:
	if Iso.island_fraction(tile.x, tile.y) < WALK_LIMIT and not Iso.in_shed(tile.x, tile.y):
		return tile
	var away := tile - Iso.ISLAND_CENTRE
	# Dead centre has no direction to lean; south-east is where the door faces.
	if away.length_squared() < 0.0001:
		away = Vector2(1.0, 1.0)
	away = away.normalized()
	for step in 60:
		var out := Iso.ISLAND_CENTRE + away * (0.1 * float(step))
		if Iso.island_fraction(out.x, out.y) < WALK_LIMIT and not Iso.in_shed(out.x, out.y):
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

	for name: String in book["poses"]:
		var frames: Array = []
		for cell: Dictionary in book["poses"][name]:
			var region: Array = cell["region"]
			var ink: Array = cell["ink"]
			frames.append({
				"region": Rect2(region[0], region[1], region[2], region[3]),
				"ink": Rect2(ink[0], ink[1], ink[2], ink[3]),
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
		queue_redraw()
		return

	# Read in screen space and turned into tile space, so "press right" walks right on
	# screen rather than along a diagonal the player cannot see.
	var step := Iso.world_to_tile(push.normalized() * Iso.TILE_W).normalized()
	facing = step
	var wanted := tile_pos + step * WALK_SPEED * delta
	if _can_stand(wanted):
		tile_pos = wanted
	else:
		# Blocked head-on. Try each axis alone, so walking into the shore slides along it
		# instead of sticking — the island is a wobbly ellipse and a hard stop on it feels
		# like a bug every time.
		var slide_x := tile_pos + Vector2(step.x, 0.0) * WALK_SPEED * delta
		var slide_y := tile_pos + Vector2(0.0, step.y) * WALK_SPEED * delta
		if _can_stand(slide_x):
			tile_pos = slide_x
		elif _can_stand(slide_y):
			tile_pos = slide_y
	_step += delta
	_place()
	queue_redraw()


## Somewhere the angler may be: on the grass, and not inside the shed.
##
## The shed is the only solid thing on the island, and it is checked here rather than by any
## collision shape for the same reason the shore is — there is no physics in this game, and
## a question asked before each step cannot wedge the character inside anything.
func _can_stand(at: Vector2) -> bool:
	if Iso.island_fraction(at.x, at.y) >= WALK_LIMIT:
		return false
	# Standing inside it already — an old save, or the shed being moved under them — means
	# every step out is also a step through, and refusing those leaves them walled in
	# forever. So the rule is only enforced on someone who is outside it.
	if Iso.in_shed(tile_pos.x, tile_pos.y):
		return true
	return not Iso.in_shed(at.x, at.y)


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
func _draw() -> void:
	# Footprint, which is what puts them on the ground on a plane seen at an angle. Drawn
	# whether or not the art loaded: it is the shadow, not the figure.
	_diamond(Vector2.ZERO, Vector2(20.0, 10.0), Color(0.0, 0.0, 0.0, 0.20))

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
	var scale := HEIGHT / _stand_tall
	var size := region.size * scale
	var box := Rect2(
		Vector2(-size.x * 0.5, -_stand_foot * scale), size
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
		return
	draw_texture_rect_region(_sheet, box, region)


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
		Color(0.44, 0.36, 0.26)
	)



func _diamond(at: Vector2, extent: Vector2, colour: Color) -> void:
	draw_colored_polygon(
		PackedVector2Array([
			at + Vector2(0.0, -extent.y * 0.5), at + Vector2(extent.x * 0.5, 0.0),
			at + Vector2(0.0, extent.y * 0.5), at + Vector2(-extent.x * 0.5, 0.0)
		]),
		colour
	)
