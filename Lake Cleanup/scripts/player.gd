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

## How far out the character may walk past the water's drawn edge, in world pixels.
##
## A short wade: was six pixels, which only wet the boots; twenty more lets the angler step
## properly into the shallows off the beach. Measured from where the water is seen to start
## (`Iso.past_water`), not from the waterline `Iso.past_island` holds a little way out.
##
## Pixels, not a fraction of the island's radius as it used to be. A fraction is a different
## distance at every angle once the projection has stretched one diagonal against the other:
## at 1.06 the angler could paddle four tenths of a tile out on the eastern shore and barely
## a tenth on the northern one, and the bigger the island got the worse the gap. See
## `Iso.past_island`.
const WALK_LIMIT := 26.0

## How much of the figure the water swallows once it is past the waterline, in source pixels
## at the far end of that step out.
##
## Knee deep is a fact about the picture, not about the walking rule: the boots have to
## disappear into the surface or the angler is standing on the water. Taken off the bottom of
## the drawn sprite rather than by sinking it, so the head stays where the walk cycle put it
## and only the legs go under.
const WADE_SINK := 9.0

## How far the figure's feet sink into dry ground, in screen pixels. Small: this is the
## difference between standing on a tile and standing on top of it, not a second wade.
##
## Pixels rather than source pixels off the sheet, unlike WADE_SINK — that one cuts the art
## itself so the waterline lands on a whole source pixel; this one only moves where the whole
## picture is drawn, so it costs nothing to keep it a fraction of a screen pixel.
const LAND_SINK := 4.0

## Source pixels of boot hidden in the island's grass, like a shallow wade with no foam. The
## picture moves down by the same, so the cut sits on the ground. Sand keeps the boots whole,
## and so does the shadow.
const GRASS_BURY := 2.0

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

## The daylight, handed over by the level. Null anywhere there is no lake — the shed screen,
## a test — where the angler simply casts no shadow.
var day: DayCycle

## The island's trail of footprints, handed over the same way. Null until then, and walking
## works the same either way — the marks are a nicety, not a thing the walk depends on.
var prints: Footprints

## The foam where the boots cut the surface while wading. See WaterlineFoam.
var _foam: WaterlineFoam
## The foam the boots leave while wading. See STREAK_LONG.
var _streak: HullFoam
var _was_wading := false

## The foam the wading angler leaves (issue #31, 2026-09-16, the dog's rule: a streak
## behind while moving in the water, one ring on the way in). See Dog.STREAK_LONG.
const STREAK_LONG := 11.0
const STREAK_WIDE := 6.0
const ENTRY_SPAN := 30.0

## How tall the figure draws, in pixels — asked for rather than promised. The drawing is
## scaled by whole source pixels (see `_frame`), so what comes out is the nearest whole
## multiple of the figure's own height inside its cell.
##
## Whole multiples because Godot filters canvas textures bilinearly unless told otherwise, and
## a fraction of a pixel means some source pixels land on two screen pixels and some on one,
## in a beat all the way down the figure — the angler reads as soft and out of focus while the
## rubbish floating past it, drawn at one to one, reads as sharp.
const HEIGHT := 40.0

## The cut sheet. tools/slice_character.gd writes it from art_source/Character_Sprite_Sheet.psd.
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

## Seconds a frame is held: a nine-frame idle, a seventeen-frame run held for less each so it
## keeps up with the feet, and the sixteen-frame cast, looped for as long as the net is out —
## see _cast_time. Public: the shed draws the same sheet at the same pace.
const IDLE_FRAME := 0.24
const RUN_FRAME := 0.05
const CAST_FRAME := 0.04

## Where in the run cycle a foot comes down, as fractions of it: frames 3 and 10 of the
## fourteen, where the figure's head is lowest. A footstep sound fires on each (2026-09-15).
const FOOTFALLS := [0.21, 0.71]

## How far past the water's drawn edge the boots have to be before they count as in it, in
## world pixels (`step_surface`). Measured out from the edge rather than back up the beach
## (2026-09-15, Richard: "only when the player really enters water, not on foam"): the wet sand
## and the foam the coast wave runs over it are the beach, and the wade itself is only
## `WALK_LIMIT` (26 px) deep, so this leaves most of it.

## How far past the water's drawn edge the boots must be before they count as in it, in world
## pixels (`step_surface`). Measured out from the edge rather than back up the beach
## (2026-09-15, Richard: "only when the player really enters water, not on foam"): the wet sand,
## and the foam the coast wave runs over it, are the beach. The wade is `WALK_LIMIT` (26 px)
## deep, so this still leaves most of it.
const WADE_IN := 8.0

## Tiles a second under which the wading wash is not played: standing in the shallows moves no
## water, and the collar of foam round the boots already says they are in it.
const WADE_LEAST := 0.3

## Straw, for the blocked-in figure only: with no art at all the hat has to be drawn, and a
## hat is the one thing that separates the placeholder from a post.
const HAT_STRAW := Color(0.87, 0.71, 0.38)


## Where the angler stands, in tile coordinates. Just south of the shed rather than in the
## middle of the island, because the middle of the island is now where the shed is.
var tile_pos := Vector2(Iso.ISLAND_CENTRE.x + 1.3, Iso.ISLAND_CENTRE.y + 1.3)

## Which way they are turned, on the plane. It picks which of the drawn views is shown, and
## it is where a cast leaves from.
var facing := Vector2(0.0, 1.0)

## Set false while the shop is open, so walking does not happen behind the panel.
var can_walk: bool = true

## A tile the angler walks to by himself, or `Vector2.INF` for nobody leading him. Set by
## the new game's arrival (`Lake`'s arrival section, 2026-09-19, issue #24): the figure
## walks up the beach to the shed while the player's hands are held, which is exactly the
## case `can_walk` refuses — so this is read **instead of** the input, not through it.
## Cleared by the walk itself on arrival, so a caller can watch it for the end.
var walk_to := Vector2.INF
## How near counts as arrived, in tiles. A stride is about a tenth of a tile a frame, so
## anything under that would be walked past and back.
const LED_CLOSE := 0.35

## Where the yard crate stands, in tiles, or INF for a scene with no crate in it. Set by the
## lake once the yard has been put down.
##
## The dog used to be in here too, as a thing to keep out of. It is not any more: an animal
## that wanders about the island and pushes back is an animal in the way, and the island is
## small. It can be walked through.
var crate_tile := Vector2.INF

var _time: float = 0.0
var _step: float = 0.0
## The run frame the last footfall check saw, so a frame held for several draws steps once.
var _run_frame: int = -1

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

## The sheet, and pose name -> its frames, each `{region, ink}`. Empty when the art is
## missing, which drops the whole node back to the blocked-in figure. The sheet draws all four
## compass directions itself and its hat is painted in, so nothing is mirrored or worn on top.
var _sheet: Texture2D
var _poses := {}

## Seconds into the cast animation, or negative while none is playing; see start_cast().
## Counts up for the whole haul, and _pose() wraps it, so the throw repeats while the net is
## dragged home and only end_cast() drops it back to idle.
var _cast_time := -1.0

## How long a cast holds the angler still, in seconds — long enough to see the throw play
## out before the boots are free again. Tune by feel; this is a first guess.
const CAST_LOCK := 1.0

## Seconds left of that lock, or 0 once it has run out and walking is free again.
var _cast_lock := 0.0

## How tall the figure draws inside its cell and where its feet sit in it, taken once from
## one frame and used for every frame.
##
## Once, not per frame, and this is the whole of why the figure used to jump about. The
## drawing breathes inside its cell — nineteen pixels tall on one frame and twenty on the
## next, six from the top on one and seven on another — so scaling each frame to its own ink
## made the angler pulse in size and shift on the spot every time the frame changed. The cell
## is what holds an animation still. Measuring past it throws that away.
var _stand_tall: float = 43.0
var _stand_foot: float = 45.0

## The lowest foot row of each pose, in sheet pixels. What _frame registers a pose against.
var _foot_of: Dictionary = {}


func _ready() -> void:
	# Nearest, and only here. The figure is magnified — two screen pixels per pixel of art —
	# and a filter that blends between them throws away exactly what makes it pixel art. Not
	# set on the project: the hut is drawn at 1.4 world px per painted one, and nearest on a
	# fractional scale with no mipmaps sets it crawling.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_foam = WaterlineFoam.new()
	_foam.name = &"Foam"
	add_child(_foam)
	_streak = HullFoam.new()
	_streak.name = &"Streak"
	_streak.half_length = STREAK_LONG
	_streak.half_width = STREAK_WIDE
	add_child(_streak)
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
	if _wet_by(tile) < WALK_LIMIT and not Iso.in_shed(tile.x, tile.y, Iso.SHED_KEEP):
		return tile
	var away := tile - Iso.ISLAND_CENTRE
	# Dead centre has no direction to lean; south-east is where the door faces.
	if away.length_squared() < 0.0001:
		away = Vector2(1.0, 1.0)
	away = away.normalized()
	for step in 60:
		var out := Iso.ISLAND_CENTRE + away * (0.1 * float(step))
		if _wet_by(out) < WALK_LIMIT and not Iso.in_shed(out.x, out.y, Iso.SHED_KEEP):
			return out
	return tile


## How far into the water a spot is, in world pixels, or 0 on the island's drawn ground.
##
## The curve decides, because the curve is what is drawn: the water shader cuts itself out
## inside the same ring, so the boots are wet exactly where the picture shows water. (The
## tile used to decide, when the island's diamonds were drawn over the water and stuck
## their corners out past the curve.)
func _wet_by(at: Vector2) -> float:
	return maxf(Iso.past_water(at), 0.0)


## Where a blocked step goes instead: along the wall rather than into it.
##
## Walking into the edge of how far out the angler may wade used to try each tile axis alone,
## and tile axes are diagonals on screen — against most of a curved shore neither of them is
## along it, so both failed and the angler stuck fast. This takes the part of the step that
## heads out of the island away and keeps the rest, which is the way along the shore at this
## point. The curve bends away from a straight tangent, so the same slide nudged a little back
## in is tried next; the axes stay as a last resort. Anything the shed or the crate refuses
## is still refused — every candidate goes through _can_stand.
func _slide(move: Vector2) -> Vector2:
	# Against the crate, slide along the face that was hit. Its footprint is a square in tile
	# space, so a face runs along one tile axis: the axis the angler is already outside of is
	# the one being pushed into, and the other is the way along. The shore's slide below would
	# walk them round the island's curve instead, which is what made the box feel round.
	if crate_tile != Vector2.INF and Yard.covers(crate_tile, tile_pos + move, Yard.WALK_KEEP) \
			and not Yard.covers(crate_tile, tile_pos, Yard.WALK_KEEP):
		var off := tile_pos - crate_tile
		var face := Yard.FOOT_HALF + Yard.WALK_KEEP
		var along := Vector2(0.0, move.y) if absf(off.x) >= face else Vector2(move.x, 0.0)
		if along.length_squared() > 0.0000001 and _can_stand(tile_pos + along):
			return tile_pos + along
	# The pump, the crate's way: a square in tile space, slid along the face that was hit.
	if Pump.covers(tile_pos + move, Pump.WALK_KEEP) and not Pump.covers(tile_pos, Pump.WALK_KEEP):
		var from := tile_pos - Pump.tile
		var edge := Pump.FOOT_HALF + Pump.WALK_KEEP
		var by := Vector2(0.0, move.y) if absf(from.x) >= edge else Vector2(move.x, 0.0)
		if by.length_squared() > 0.0000001 and _can_stand(tile_pos + by):
			return tile_pos + by
	# And against the hut, the same way: its footprint is a rectangle in tile space now, so
	# its walls are tile axes too. Without this the shore's slide below took over and walked
	# the angler round the island's curve instead of along the wall — which is exactly what
	# made the hut feel round to walk round.
	var step := tile_pos + move
	if Iso.in_shed(step.x, step.y, Iso.SHED_KEEP) \
			and not Iso.in_shed(tile_pos.x, tile_pos.y, Iso.SHED_KEEP):
		var out_of := tile_pos - Iso.ISLAND_CENTRE
		var wall := Iso.SHED_FOOT + Vector2(Iso.SHED_KEEP, Iso.SHED_KEEP)
		var slip := Vector2(0.0, move.y) if absf(out_of.x) >= wall.x else Vector2(move.x, 0.0)
		if slip.length_squared() > 0.0000001 and _can_stand(tile_pos + slip):
			return tile_pos + slip
	# Which way is out, in tile space, off the same distance the walking limit is measured in.
	var e := 0.05
	var out := Vector2(
		Iso.past_water(tile_pos + Vector2(e, 0.0)) - Iso.past_water(tile_pos - Vector2(e, 0.0)),
		Iso.past_water(tile_pos + Vector2(0.0, e)) - Iso.past_water(tile_pos - Vector2(0.0, e))
	)
	var candidates: Array[Vector2] = []
	if out.length_squared() > 0.000001:
		out = out.normalized()
		var along := move - out * maxf(move.dot(out), 0.0)
		if along.length_squared() > 0.0000001:
			candidates.append(tile_pos + along)
			candidates.append(tile_pos + along - out * along.length() * 0.3)
	candidates.append(tile_pos + Vector2(move.x, 0.0))
	candidates.append(tile_pos + Vector2(0.0, move.y))
	for at in candidates:
		if _can_stand(at):
			return at
	return tile_pos


## Read the cut sheet. False means no art and the placeholder stands in, the same bargain
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
		# Each pose stands on its own lowest foot row: the north strips end two rows higher
		# than the south ones, and one row for all left the north figure above its shadow.
		var foot := 0.0
		for f: Dictionary in frames:
			var box: Rect2 = f["ink"]
			foot = maxf(foot, box.position.y + box.size.y)
		_foot_of[StringName(name)] = foot

	# The one frame everything is registered against: the angler standing still, facing the
	# camera. A named one is easier to go and look at than "the first one that happened to
	# load".
	if _poses.has(&"idle_south"):
		var ink: Rect2 = ((_poses[&"idle_south"] as Array)[0] as Dictionary)["ink"]
		_stand_tall = maxf(ink.size.y, 1.0)
		_stand_foot = ink.position.y + ink.size.y
	return not _poses.is_empty()


## Which compass direction the sheet should show.
##
## Worked out in screen space rather than tile space. The player sees a plane at an angle and
## the sheet is drawn for a screen: what matters is whether the angler is walking across the
## view or into it, which is a question about the projected direction and not about the tiles
## underneath.
func _view() -> StringName:
	var on_screen := Vector2(facing.x - facing.y, (facing.x + facing.y) * 0.5)
	if absf(on_screen.x) >= absf(on_screen.y) * SIDE_FAVOUR:
		return &"west" if on_screen.x < 0.0 else &"east"
	return &"south" if on_screen.y > 0.0 else &"north"


## Starts the cast animation, looped until the net is home — see _cast_time and _paint_key().
## A no-op while the art is missing: the net still flies and comes home exactly the same
## either way (see net.gd), this only decides what the angler is shown holding while it does.
func start_cast() -> void:
	if not _poses.is_empty():
		_cast_time = 0.0
		_cast_lock = CAST_LOCK


## Drops the held cast pose back to idle. Called once the net is home, so a haul that ends
## empty-handed lets go of the pose the same as one that comes back full — see net.gd's
## _come_home().
func end_cast() -> void:
	_cast_time = -1.0
	_cast_lock = 0.0


## Where the hands are, against the point the figure stands on: how far out in front of the body
## along the way it faces, in world pixels, and how high up it, as a fraction of HEIGHT.
##
## The rope leaves from here. It used to leave from sixteen pixels out at nearly shoulder
## height, which was open air beside the figure — the rope started in nothing and the gap
## between it and the angler read as a line nobody was holding. A few pixels out at the waist
## is inside the silhouette from every side, so the rope always starts on the body.
const HAND_REACH := 4.0
const HAND_HEIGHT := 0.5


## Where the rope is held and where the catch is thrown from, in world space.
##
## Still called the rod tip, and there is still no rod: the sprite holds nothing, and drawing
## one over it put a stick through the figure that read as part of the character being wrong.
## It is the hands now — see HAND_REACH.
func rod_tip() -> Vector2:
	return position + _screen_facing() * HAND_REACH + Vector2(0.0, -HEIGHT * HAND_HEIGHT)


## The way the figure faces, as a direction on the screen rather than on the tile plane.
func _screen_facing() -> Vector2:
	return Vector2(facing.x - facing.y, (facing.x + facing.y) * 0.5).normalized()


func _place() -> void:
	position = Iso.tile_to_world(tile_pos.x, tile_pos.y)


func _process(delta: float) -> void:
	_time += delta
	_push_wade()
	_wake(delta)

	# The throw itself holds the boots still — a cast that let the player walk out from
	# under it never finished playing. Input is read and thrown away rather than skipped,
	# so a held direction takes hold the instant the lock lifts instead of waiting for a
	# fresh key-down.
	if _cast_lock > 0.0:
		_cast_lock = maxf(_cast_lock - delta, 0.0)
		_step = 0.0
		_speed = move_toward(_speed, 0.0, ACCEL * delta)
		_cast_time += delta
		_repaint()
		return

	# The arrows and WASD both feed these, which is what the walk_* actions are for. See
	# the [input] block in project.godot.
	var push := Vector2.ZERO
	if walk_to != Vector2.INF:
		# Led, not driven: the push is worked out in screen space, which is what the input
		# gives and what the step below expects to be handed.
		if tile_pos.distance_to(walk_to) <= LED_CLOSE:
			walk_to = Vector2.INF
		else:
			push = (
				Iso.tile_to_world(walk_to.x, walk_to.y)
				- Iso.tile_to_world(tile_pos.x, tile_pos.y)
			).normalized()
	elif can_walk:
		push = Vector2(
			Input.get_axis(&"walk_left", &"walk_right"),
			Input.get_axis(&"walk_up", &"walk_down")
		)
	if push == Vector2.ZERO:
		_step = 0.0
		_speed = move_toward(_speed, 0.0, ACCEL * delta)
		if _cast_time >= 0.0:
			_cast_time += delta
		_repaint()
		return

	# Walking wins outright: once the angler moves, the cast is gone for the rest of this
	# haul, not merely paused. See start_cast()'s note and the plan this came out of —
	# holding the cast pose while the figure slides about with no stride under it read
	# worse than just letting it go.
	_cast_time = -1.0

	# Read in screen space and turned into tile space, so "press right" walks right on
	# screen rather than along a diagonal the player cannot see.
	var step := Iso.world_to_tile(push.normalized() * Iso.TILE_W).normalized()
	facing = step
	_speed = move_toward(_speed, WALK_SPEED, ACCEL * delta)
	var move := step * _speed * delta
	var wanted := tile_pos + move
	if _can_stand(wanted):
		tile_pos = wanted
	else:
		tile_pos = _slide(move)
	_step += delta
	_place()
	_leave_print()
	_footfall()
	_repaint()


## A footstep, on the run frames a foot comes down on, off what is under the boots: the
## shallows, the lawn, or the beach.
func _footfall() -> void:
	var frames: Array = _poses.get(StringName("run_%s" % _view()), [])
	if frames.is_empty():
		return
	var at := posmod(int(_time / RUN_FRAME), frames.size())
	if at == _run_frame:
		return
	_run_frame = at
	var down := false
	for fall: float in FOOTFALLS:
		down = down or at == int(fall * float(frames.size()))
	var sound := Sfx.main()
	if not down or sound == null:
		return
	var on := step_surface()
	# The shallows are the wading loop, not a footfall: see `_push_wade`.
	if on != &"water":
		sound.play_step(on)


## The water the boots move, held while they are moving it. Pushed every frame, including the
## frames that return early — a cast holds the feet still, and still feet move no water.
func _push_wade() -> void:
	var sound := Sfx.main()
	if sound != null:
		sound.set_wading(_speed > WADE_LEAST and step_surface() == &"water", self)


## What is under the boots, as the footstep sounds name it: the shallows, the lawn, or the
## beach. Public, so the test can ask it without walking the figure about.
##
## Wet means past the water's own edge by `WADE_IN`, not merely near it: foam running up the
## sand is still sand.
func step_surface() -> StringName:
	if Iso.past_water(tile_pos) > WADE_IN:
		return &"water"
	return &"grass" if Iso.on_lawn(tile_pos) else &"sand"


## How many source pixels of the figure are under water where it is standing, whole pixels.
##
## Nothing until the waterline and the full depth at the end of the step past it, which is as
## far out as `WALK_LIMIT` lets anyone go.
func _wading() -> float:
	var out := _wet_by(tile_pos)
	if out <= 0.0:
		return 0.0
	var into := clampf(out / maxf(WALK_LIMIT, 0.0001), 0.0, 1.0)
	return roundf(into * WADE_SINK)


## The water the boots move: one ring as they go in, and the streak behind them while they
## are moving in it. From the foam on the cut, not from the boots under it: the wake is the
## water they part.
func _wake(delta: float) -> void:
	var wading := _wet_by(tile_pos) > 0.0
	var cut := Vector2(0.0, _cut_y(_wading(), 0.0))
	if wading and not _was_wading and splash != null:
		splash.ripple(Iso.tile_to_world(tile_pos.x, tile_pos.y) + cut, ENTRY_SPAN)
	_was_wading = wading
	if _streak == null:
		return
	_streak.position = cut
	var moving := wading and _step > 0.0 and _speed > WADE_LEAST
	_streak.lay(_screen_facing(), 1.0 if moving else 0.0, delta)


## A boot print in the sand or the grass, every PRINT_SPACING of ground actually covered.
##
## On dry land only — the water already answers "somebody just walked through here" with the
## ripples and the wake, and a print left on top of those would be one more mark nobody reads
## twice.
func _leave_print() -> void:
	var moved := position.distance_to(_last_print_pos)
	_last_print_pos = position
	if prints == null or _wet_by(tile_pos) > 0.0:
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
	if _wet_by(at) >= WALK_LIMIT:
		return false
	# Not through the crate: its own square footprint, no wider. Enforced the way the hut is —
	# on somebody who is not standing in it already.
	if crate_tile != Vector2.INF and not Yard.covers(crate_tile, tile_pos, Yard.WALK_KEEP):
		if Yard.covers(crate_tile, at, Yard.WALK_KEEP):
			return false
	# Nor through the pump, on the same terms: somebody standing in it may always leave.
	if Pump.covers(at, Pump.WALK_KEEP) and not Pump.covers(tile_pos, Pump.WALK_KEEP):
		return false
	# Standing inside it already — an old save, or the shed being moved under them — means
	# every step out is also a step through, and refusing those leaves them walled in
	# forever. So the rule is only enforced on someone who is outside it.
	if Iso.in_shed(tile_pos.x, tile_pos.y, Iso.SHED_KEEP):
		return true
	return not Iso.in_shed(at.x, at.y, Iso.SHED_KEEP)


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
## The sun, coarsely, so a swinging shadow repaints the figure without repainting it every
## frame. Mirrors Dog._sun_key.
func _sun_key() -> int:
	return 0 if day == null else roundi(day.lean * 60.0) * 1000 + roundi(day.ink * 200.0)


func _paint_key() -> int:
	var walking := _step > 0.0
	# How deep the boots are is part of the picture too: stepping into the shallows changes
	# what is drawn without changing which frame it is.
	var sunk := _wading()
	var pose: Dictionary = _pose(walking)
	return hash([pose["pose"], pose["index"], sunk, _sun_key()])


## The pose and frame index showing right now: idle, run, or the cast looping for as long as
## the net is out — see start_cast() and _cast_time. Shared between _paint_key() and _draw()
## so the two can never disagree about which frame that is.
func _pose(walking: bool) -> Dictionary:
	var dir := _view()
	if _cast_time >= 0.0 and not walking:
		var pose := StringName("cast_%s" % dir)
		var frames: Array = _poses.get(pose, [])
		if not frames.is_empty():
			return {"pose": pose, "index": posmod(int(_cast_time / CAST_FRAME), frames.size())}
	if walking:
		var pose := StringName("run_%s" % dir)
		var frames: Array = _poses.get(pose, [])
		if not frames.is_empty():
			return {"pose": pose, "index": posmod(int(_time / RUN_FRAME), frames.size())}
	var pose := StringName("idle_%s" % dir)
	var frames: Array = _poses.get(pose, [])
	var index := posmod(int(_time / IDLE_FRAME), frames.size()) if not frames.is_empty() else 0
	return {"pose": pose, "index": index}


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

	# The shadow, which is what puts them on the ground on a plane seen at an angle.
	_draw_shadow(sunk, land_shift)

	# The foam on the cut, behind the figure, while any of it is under.
	if _foam != null:
		var edge := _cut_edge(sunk, land_shift)
		if edge.is_empty():
			_foam.clear()
		else:
			_foam.lay(edge[0], edge[1])

	var shown := _frame(sunk, land_shift, true)
	if shown.is_empty():
		_draw_blocked()
		return
	draw_texture_rect_region(_sheet, shown["box"] as Rect2, shown["region"] as Rect2)


## Where the wading cut ends the picture, as the two ends of that edge, or nothing on dry land.
##
## Across the body rather than the cell: the frame's ink box says how wide the figure actually
## is, and a collar the width of the cell is foam sat on open water either side of the legs.
## The height is the bottom of the box the cut frame is drawn into, which is the cut itself.
func _cut_edge(sunk: float, land_shift: float) -> Array:
	if sunk <= 0.0:
		return []
	var shown := _frame(sunk, land_shift)
	if shown.is_empty():
		return []
	var box: Rect2 = shown["box"]
	var ink: Rect2 = shown["ink"]
	var scale: float = shown["scale"]
	var y := box.end.y
	var left := box.position.x + ink.position.x * scale
	return [Vector2(left, y), Vector2(left + ink.size.x * scale, y)]


## How high the picture ends: the wading cut (where the foam lies) or, on dry land, the feet.
## The ink is centred on the origin, so the middle of the foam is straight above it.
func _cut_y(sunk: float, land_shift: float) -> float:
	if sunk <= 0.0:
		return land_shift
	var shown := _frame(sunk, land_shift)
	if shown.is_empty():
		return land_shift
	return (shown["box"] as Rect2).end.y


## Which frame is showing, and the box it goes in. Pulled out of the draw because the shadow
## and the wading foam want exactly the same answer: a shadow picked from a different frame
## than the figure is a shadow of somebody else.
func _frame(sunk: float, land_shift: float, buried := false) -> Dictionary:
	if _poses.is_empty():
		return {}

	var walking := _step > 0.0
	var chosen: Dictionary = _pose(walking)
	var frames: Array = _poses.get(chosen["pose"], [])
	if frames.is_empty():
		return {}
	var frame: Dictionary = frames[chosen["index"]]
	var region: Rect2 = frame["region"]
	var ink: Rect2 = frame["ink"]

	# Whole source pixels only, off the figure's own height rather than its cell. HEIGHT says
	# how big the angler should be and this says how big it can be, so nothing — not a change
	# to HEIGHT nor a re-slice with more headroom — can quietly put the blur back.
	var scale := maxf(1.0, roundf(HEIGHT / _stand_tall))

	# In the shallows, the bottom of the picture is under the surface. Whole source pixels, so
	# the cut lands on the same grid the figure is drawn on and the waterline does not crawl up
	# the boot half a pixel at a time.
	if sunk > 0.0:
		region = Rect2(region.position, Vector2(region.size.x, maxf(region.size.y - sunk, 1.0)))
	# On the lawn the boots go into the grass: the air under the feet and GRASS_BURY rows off
	# the bottom, and the picture drawn that much lower so what is left still meets the ground.
	var dropped := 0.0
	if buried and sunk <= 0.0 and Iso.on_lawn(tile_pos):
		var air := maxf(region.size.y - (ink.position.y + ink.size.y), 0.0)
		region = Rect2(
			region.position, Vector2(region.size.x, maxf(region.size.y - air - GRASS_BURY, 1.0))
		)
		dropped = GRASS_BURY

	# Centred on the figure, not on the cell. The cells are not authored — tools/slice_character.gd
	# only has one strip per direction to divide evenly by its frame count, and an even split
	# of a hand-trimmed strip does not land the body in the middle of what it hands back.
	# Centring on the frame's own ink box puts the same point of the body — its horizontal
	# middle — under the origin no matter where the cell cut it.
	var size := region.size * scale
	var box := Rect2(
		Vector2(
			-(ink.position.x + ink.size.x * 0.5) * scale,
			(dropped - float(_foot_of.get(chosen["pose"], _stand_foot))) * scale + land_shift
		),
		size
	)
	return {"region": region, "box": box, "scale": scale, "ink": ink}


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



## The angler's shadow: the frame they are drawn on, laid out on the ground away from the
## sun, in flat ink.
##
## It used to be an ellipse squashed a little on the step. That put a dark patch under a
## walking figure and called it a shadow; this is the figure's own outline, so it swings a
## rod when they swing a rod. Wading is deliberately included: the same cut that takes the
## boots off the picture takes them off the shadow, so what is under the water does not cast
## on top of it.
##
## No day, no shadow — see Dog._draw_shadow for why a guessed sun is worse than none.
func _draw_shadow(sunk: float, land_shift: float) -> void:
	if day == null:
		return
	var ink := Shade.tint(day.ink)
	# Rooted where the picture ends: the cut line while wading, the feet on dry land. Rooted at
	# the hidden feet, the shadow started below the foam and left a strip of water between.
	var down := Shade.lying(Vector2(0.0, land_shift), day.lean, day.stretch)
	if sunk > 0.0:
		# lying() folds about local y 0; slide the picture so the cut sits on that fold and
		# stays put, then back to where the cut is drawn.
		var cut := _cut_y(sunk, land_shift)
		down = Shade.lying(Vector2(0.0, cut), day.lean, day.stretch) 			* Transform2D(0.0, Vector2(0.0, -cut))
	var shown := _frame(sunk, land_shift)
	if shown.is_empty():
		return
	draw_set_transform_matrix(down)
	draw_texture_rect_region(_sheet, shown["box"] as Rect2, shown["region"] as Rect2, ink)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
