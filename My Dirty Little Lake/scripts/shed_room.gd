## The inside of the shed: where everything pulled out of the lake and kept ends up.
##
## The lake is the work and this is what the work is for. Furniture is the one thing in the
## game that is not spent — a find is not sold, it is carried up the beach and put down
## somewhere, and this is the room it is put down in.
##
## One Control draws the whole screen and handles all of its input. That is deliberate: a
## drag that starts on a list and ends on a floor is one gesture, and splitting it across
## two nodes turns it into an exercise in forwarding events. The room is drawn, not built
## out of scene nodes, for the same reason the lake is.
class_name ShedRoom
extends Control

const Style := preload("res://scripts/style.gd")
const DogArt := preload("res://scripts/dog_art.gd")
const ShedShelf := preload("res://scripts/shed_shelf.gd")

## The grid things are placed on, in source pixels, and how far the room is blown up.
##
## Half the 16 px grid the art was drawn on. Furniture is not drawn to whole cells — a
## chair is twenty-seven pixels across, a stool nineteen — and snapping those to a
## sixteen-pixel grid leaves a margin of dead floor around everything. Eight is fine enough
## that a piece lands where it looks like it should and coarse enough to still snap.
##
## **Furniture is no longer placed on it** (2026-09-16, Richard: the snap is too tight to put
## a piece exactly where he wants it). A piece stands on any whole **source pixel** —
## `PLACE_COLS` x `PLACE_ROWS` of them, `CELL` to a cell — which at ZOOM 3 is a three-screen-
## pixel step instead of a twenty-four. Whole pixels and no finer: the room is pixel art, and
## a piece at half a pixel either blurs or crawls on the screen grid. No coarse snap is kept
## anywhere — no modifier, no magnet to a neighbour — by decision: one gesture, one thing.
##
## `CELL` stays the **walkers'** grid. The player and the dog move in cells (`_you_at`,
## `_dog_at`, `_feet_keep`, `REACH`, the glow radii) and `_blockers` blocks whole cells, because
## per-pixel collision is sixty-four times the entries for a difference nobody can feel. The
## two units therefore meet in a handful of places, and every one of them divides by `CELL`
## on the way: `_foot_of` and `_walker_key` (sort keys are in cells), `_blockers`, `_bed_cell`,
## `_switch_near`.
const CELL := 8
const ZOOM := 3

## The most a source pixel is ever blown up. The room fills the screen now, so the floor is
## allowed to grow into it rather than stopping at the size it was when it lived in a panel.
const ZOOM_MOST := 6

## The floor, in cells. Roughly doubled (600 -> 1176 cells) at the same aspect ratio, so more
## finds can stand at once. `_floor_rect()` below only centres the floor in whatever room is
## left after the inventory list — it does not scale or scroll a floor bigger than that space,
## so this needs an in-editor check against the panel it actually renders into: unverified
## from here.
const COLS := 42
const ROWS := 28

## The same floor in placement pixels: what `can_place` and `_drop_cell` measure against.
const PLACE_COLS := COLS * CELL
const PLACE_ROWS := ROWS * CELL

## How wide the inventory column down the right is, in pixels, and how tall one row of it
## is. A row holds one find: its picture and its name.
const LIST_WIDTH := 210
const ROW_HEIGHT := 56

## The shelf is a board of the shop's oak, standing beside the room rather than drawn into
## its wall. Frame thickness, chips per edge, the title plank's height and how far it
## overhangs the frame at each end, the pad inside the face, the gap between rows, and the
## lane the scrollbar runs down.
##
## The board grows *outwards* from the column the room already leaves free, so dressing it
## costs the floor nothing. Its right edge is clamped to the panel in `_board_rect`.
const SHELF_FRAME := 10.0
const SHELF_CHIPS := 3
const SHELF_RIBBON := 36.0
const SHELF_OVERHANG := 8.0
const SHELF_PAD := 8.0
const SHELF_ROW_GAP := 4.0
const SHELF_BAR := 8.0
const SHELF_BAR_GAP := 4.0

## Gap between the room and the list, and the margin around the lot inside the panel.
const GUTTER := 22
const MARGIN := 8.0

## How far the inventory column fades back while a find is being carried. The list sits over
## part of the floor and a player placing furniture is looking at the floor, not at the list
## they have already taken the piece out of.
const LIST_BUSY := 0.25
## The wash plank's word, with how many wait; and how far it stands under "Nothing kept
## yet." on an empty shelf, so the two are not on top of each other.
static var WASH_LABEL: String:
	get: return Text.SHELF_WASH_N
const WASH_UNDER_EMPTY := 30.0
## The gap between the last find's row and the wash plank (2026-09-24, Richard: under one
## row the plank's frame and its gold glow ran up into the row above). The plank's wood is
## a built frame that stands proud of the plain row plates, so it needs this much more air
## than a row does.
const WASH_UNDER_ROWS := 14.0


## The close cross: how big it is drawn. Where it sits on the title plank is
## `Style.close_on`, the same for every menu.
const CLOSE_SIDE := 44.0

## The dogs, when they happen to be in.
##
## Each of the pack rolls this on its own, because a dog that is always exactly where you
## left it is furniture. When one is in, it mooches from one clear patch of floor to another
## — unless there is something out with a seat authored on it, in which case it goes and
## lies on that.
##
## **Rolled per dog** (2026-09-19, issue #30, Richard's call over a count rolled once): at
## the full pack of four that leaves the room empty 4% of the time rather than 45%, so
## walking in and finding a dog stops being a find. Accepted — the player bought four dogs
## and should see them. The comment about "finding it" is the price.
const DOG_ODDS := 0.55

## The most that can be in the room at once, whatever the pack holds. `Lake.MAX_DOGS` by
## construction; written here rather than reached for because `ShedRoom` is a view of two
## arrays and knows nothing else about the lake.
const DOGS_MOST := 4

## How tall the dog draws, in floor cells, and how fast it walks across them.
##
## Set against the player rather than picked: outdoors the angler is forty pixels and the dog
## twenty-two, and this is what puts the same pair of animals in this room at the same ratio
## once the player's own height has been snapped to whole pixels of art.
const DOG_TALL := 2.75
const DOG_SPEED := 2.6

## The longest step allowed in one frame, in cells. See the delta clamp in `_process`.
const DOG_STEP_MOST := 0.6

## A dog finds its way round the furniture (2026-10-03, `/grill-me` with Richard: dogs got
## stuck walking against furniture). The floor is a grid of `PATH_RES` points a cell, each
## free where `_dog_may_stand` says a dog may stand; a walk is an A* path over it, pulled
## straight wherever the line between two of its points is clear (`PATH_LOOK`, the step the
## line is sampled at), and a dog only ever picks a spot it can reach. Other walkers are not
## on the grid: they move, so a dog slides past them and, held up `DOG_BLOCKED` seconds,
## thinks again. The lake's dogs keep their own rule (no search); the shed's clutter is what
## needs one.
const PATH_RES := 2
const PATH_LOOK := 0.2
const DOG_BLOCKED := 0.7

## How long the dog keeps doing one thing, in seconds, and how long it settles for when it
## has found the bed.
const DOG_MOOD_LEAST := 2.5
const DOG_MOOD_MOST := 7.0
const DOG_BED_SLEEP := 22.0

## The piece the dog treats as its own. The catalogue name rather than the title, so
## renaming the find in tools/decor_sets.json does not quietly take the dog's bed away.
##
## One name covers both beds: the art draws two styles and the player picks which one it
## stands as with R, so they are one find with two faces rather than two finds. See
## Sheets.Set.VARIANT.
##
## Since 2026-09-19 this is only the piece the dogs may *walk over* — `_blockers` leaves it out
## of the blocked floor. **Which pieces they lie on is `Sheets.seat_of`**, authored per view
## in tools/decor_sets.json, and the pet bed is one of four. Nothing here tests a view's
## role: the bed's views are colours and the pet bed's are shapes, so a gate on the name
## "front" would have given both beds no seat at all and taken away the one seat that
## already worked.
const DOG_BED := &"decor_pet_bed"

## How far past its host a piece set over another draws, and a walker standing in a
## piece's base after that. Both sort keys are in cells; these only decide the order among
## things at the same row, so they are small and one is bigger than the other.
const OVER_HOST := 0.01
const OVER_PIECE := 0.02
## A dog sharing the player's sofa or bed sorts this far past the player: over them, and
## still well short of the next piece down the room.
const SHARED_OVER := 0.005
## How far to either side of a piece, in cells, a walker still counts as next to it for
## drawing: about half the widest walker's drawing.
const BESIDE := 1.5

## How close the player has to stand to work a switch, in cells, and how far above the
## piece the prompt floats.
##
## A fireplace is lit by walking up to it, not by clicking it from across the room: the
## room already has a drag gesture and a second meaning for the same click is how a player
## ends up dragging the fridge every time they meant to open it.
const REACH := 3.2
const PROMPT_LIFT := 8.0

## Resting on the furniture (2026-09-29, `/grill-me` with Richard, picked off
## `tools/last_pose_mockup.png`): E at a seat sits the player on it, at a bed lies them in it,
## at a bookcase they reach up for a book and read it facing the room. Per piece, per view:
## the kind, the hips' height in the drawing's own pixels up from its bottom edge, and how far
## off the drawing's middle the player sits, in the same pixels. A view that is not listed
## offers nothing: **side views are left out by decision** (Richard, after three passes at a
## side-on sit). `front` faces the room and is drawn over the piece; `back` turns away from it,
## sits **over the seat and under the backrest** (2026-10-03, Richard; it used to be drawn
## behind the whole piece and read as standing behind it): drawn over the piece, and then the
## piece's rows from the fourth number down (the drawing's own rows from its top, by eye off
## each back view) drawn again over the player. A chair's back view draws its seat cushion
## below the backrest, and the player sits **on** it: the fifth number is where the backrest
## ends, and only the rows between are drawn over him (second pass the same day, Richard: "it
## should be between cushion and back rest"), with the hips raised to the cushion. A sofa or
## an armchair from behind is all backrest and has no fifth. The sixth is the cushion's foot:
## the player is not drawn below it, since a sitter's legs go forward under the seat. The
## basket is put down for a back sit (`build_pose_mockup.drop_basket`).
##
## The sofa's view 0 is its back and its view 2 its cushion: the catalogue's labels are the
## wrong way round for the sofa only (`SOFA_CUSHION` in the harness), and the rests follow the
## pictures, not the labels. On the sofa the player sits left of middle so a dog can have the
## other half. Numbers by eye off the mockup; retune here.
const RESTS := {
	&"decor_sofa": {0: [&"back", 10, 0, 5], 2: [&"front", 12, -10]},
	&"decor_loveseat": {0: [&"front", 13, 0], 2: [&"back", 11, 0, 6]},
	&"decor_dining_chair": {0: [&"front", 12, 0], 2: [&"back", 10, 0, 2, 9, 14]},
	&"decor_bed": {0: [&"lie", 0, 0], 1: [&"lie", 0, 0]},
	&"decor_bookcase_tall": {0: [&"read", 0, 0]},
	&"decor_bookcase_drawers": {0: [&"read", 0, 0]},
	&"decor_tiny_bookcase": {0: [&"read", 0, 0]},
	# The 0_mem0ry pack's pieces (2026-10-01): their views run front, side, back, so the
	# back is view 2 on every one. First guesses, drawn at 0.74; retune by eye.
	&"decor_pk_sofa": {0: [&"front", 11, -8], 2: [&"back", 9, 0, 5]},
	&"decor_pk_white_sofa": {0: [&"front", 11, -8], 2: [&"back", 9, 0, 6]},
	&"decor_pk_armchair": {0: [&"front", 12, 0], 2: [&"back", 10, 0, 4]},
	&"decor_pk_old_seat": {0: [&"front", 12, 0], 2: [&"back", 10, 0, 4]},
	&"decor_pk_chair": {0: [&"front", 11, 0], 2: [&"back", 18, 0, 2, 9, 18]},
	&"decor_pk_diner_chair": {0: [&"front", 11, 0], 2: [&"back", 14, 0, 2, 13, 18]},
	&"decor_pk_green_chair": {0: [&"front", 11, 0], 2: [&"back", 13, 0, 2, 10, 16]},
	&"decor_pk_wood_chair": {0: [&"front", 11, 0], 2: [&"back", 13, 0, 2, 10, 15]},
	&"decor_pk_carved_chair": {0: [&"front", 11, 0], 2: [&"back", 13, 0, 2, 12, 17]},
	&"decor_pk_diner_seat": {0: [&"front", 11, 0]},
	&"decor_pk_bed": {0: [&"lie", 0, 0], 1: [&"lie", 0, 0], 2: [&"lie", 0, 0]},
	&"decor_pk_fancy_bed": {0: [&"lie", 0, 0], 1: [&"lie", 0, 0], 2: [&"lie", 0, 0],
		3: [&"lie", 0, 0]},
	&"decor_pk_bookshelf": {0: [&"read", 0, 0]},
}
## Where the head goes on every face of every bed (2026-10-03, Richard: "mind their
## positioning and where the pillows are"), in the view's own drawn pixels, measured off the
## pack pictures by eye. A face is where the pillow is: `up` at the far end (the face-up head,
## `lie_south`), `down` behind the board nearest the camera (the back of the hat, `lie_north`),
## `west`/`east` at the left or right end of a side view (the head turned a quarter). `at` is
## the chin for up and the sides, the head's foot for down; `cover` is the bed's own picture
## drawn back over the head from there on towards the feet, so the blanket comes up to the
## chin or the near board hides the pillow; `clip` is the headboard's inner edge, which a
## sideways head is not drawn past; `feet` is where the body under the blanket ends, for its
## folds. The pack bed's view 0 is its foot end's view of the pillow end, the pillow hidden by
## the near board, and its view 2 the pillow far: its labels run the other way round from the
## fancy bed's, as the sofa's do. On the double bed the player takes one pillow, the same one
## from every side.
const LIES := {
	&"decor_bed": {
		0: {"face": &"up", "at": Vector2(11.5, 11.0), "feet": 27.0},
		1: {"face": &"up", "at": Vector2(11.5, 11.0), "feet": 27.0},
	},
	&"decor_pk_bed": {
		0: {"face": &"down", "at": Vector2(15.5, 43.0), "cover": 40.0, "feet": 12.0},
		1: {"face": &"west", "at": Vector2(20.0, 25.0), "cover": 21.0, "clip": 4.0, "feet": 55.0},
		2: {"face": &"up", "at": Vector2(15.5, 23.0), "cover": 22.0, "feet": 48.0},
	},
	&"decor_pk_fancy_bed": {
		0: {"face": &"up", "at": Vector2(15.5, 30.0), "cover": 29.0, "feet": 53.0},
		1: {"face": &"west", "at": Vector2(24.0, 22.0), "cover": 25.0, "clip": 4.0, "feet": 68.0},
		2: {"face": &"down", "at": Vector2(41.5, 48.0), "cover": 46.0, "feet": 16.0},
		3: {"face": &"east", "at": Vector2(49.0, 22.0), "cover": 49.0, "clip": 70.0, "feet": 5.0},
	},
}
## Half the width of the body's folds under the blanket, in the bed's drawn pixels.
const LIE_FOLD := 5.0
## How far above the ink's foot the hips are in each sitting strip, in the figure's own
## pixels. What `tools/build_rest_frames.py` draws: move them together.
const SIT_HIP := {&"south": 7, &"north": 8}
## Pieces a dog and the player cannot share: a dog lying on one hops off when the player sits.
## The sofa and the bed are shared, and the dog keeps to the middle of either: moved over on
## the sofa it lay on the arm (Richard, 2026-09-29: "just middle").
const SEAT_FOR_ONE := [&"decor_loveseat", &"decor_dining_chair", &"decor_pk_armchair",
	&"decor_pk_old_seat", &"decor_pk_chair", &"decor_pk_diner_chair", &"decor_pk_green_chair",
	&"decor_pk_wood_chair", &"decor_pk_carved_chair", &"decor_pk_diner_seat"]
## How many books `tools/build_rest_frames.py` draws on the reading strip, two frames each.
const BOOKS := 5
## Pieces that stand on the floor and block nothing, besides the flats and the pet bed: a
## chew toy is something to step over (Richard, 2026-09-29).
const WALK_OVER := [&"decor_chew_toy"]
## The odds a dog with nowhere to lie climbs up on the piece the player has just sat or lain
## on, when that piece has a free seat.
const JOIN_ODDS := 0.6
## The breath: seconds a cycle, and the share of it spent breathing in.
const BREATH := 2.4
const BREATH_IN := 0.35
## Lying down, seconds before the player falls asleep and the Zs come.
const SLEEP_AFTER := 6.0
## Reading: the reach up to the shelf (the petting reach from behind, `pet3_north`, the arm
## nearly straight up), then a page turned every so often.
const READ_REACH_ARM := 3
const PAGE_EVERY := 4.0
const PAGE_TIME := 0.45
## The shade the player sitting facing the room presses into the cushion: their own figure,
## shifted and darkened (Richard: "closer to the player, less round"). In the room's one ink
## since 2026-10-02 (one sun), and shifted `SIT_SHADE_REACH` source px along the room's light
## — away from the window, right and down — where it was a brown of its own two pixels right.
const SIT_SHADE_REACH := 2.0

## The light in the room (2026-09-20, Richard: "sunlight coming through the left side... no
## circled rings like current fireplace, it looks blocky and ugly"). One additive quad over
## the shed, `shaders/shed_light.gdshader`: the sun's shaft from the round window in the left
## wall, and a soft pool for every lit piece. Smooth, but worked out per art pixel of the
## room. **Retired**: three stacked `draw_circle` rings (`GLOW_RINGS`), which read as rings.
##
## A pool is a reach in cells, a power and a tone. The fridge is weaker and much whiter: an
## open fridge is a bulb in a box, not a hearth.
const LIGHT_SHADER := preload("res://shaders/shed_light.gdshader")
const LAMPS_MOST := 8
const FIRE_REACH := 9.0
const FIRE_POWER := 0.34
const FIRE_TONE := Color(1.0, 0.55, 0.2)
const FRIDGE_REACH := 4.5
const FRIDGE_POWER := 0.14
const FRIDGE_TONE := Color(0.86, 0.93, 1.0)
## A lamp: the hearth's warmth, a smaller pool and a softer one. A bulb under a shade lights
## the boards round it, not the room (2026-09-20, first guess).
const LAMP_REACH := 5.5
const LAMP_POWER := 0.22
const LAMP_TONE := Color(1.0, 0.78, 0.46)
## A lit stove: its burners and oven glow red. A small, low pool, redder than the hearth's
## and silent (2026-09-25, first guess).
const EMBER_REACH := 4.0
const EMBER_POWER := 0.2
const EMBER_TONE := Color(1.0, 0.36, 0.2)
## The window: how far down **the shed's own height** it sits on the left wall, and the shaft
## it lets in — half-width where it leaves the window, how fast it opens, and how far it
## carries, in cells. **A cone, not a band** (Richard, 2026-09-20): it opens as it crosses the
## room so it lands on the floor rather than running along the back wall, and dims with the
## distance it has come. The sun's power, its slope (how steeply the
## light falls across the room) and its tone all run morning to late afternoon on
## `DayCycle.sun`: a pale, short, steep shaft early, a long low orange one late. With no day
## handed over the room sits at `SUN_NO_DAY`. All by eye.
##
## **The window is tiny** (2026-10-02, Richard: "a cone of light coming from the center, not
## like the entire wall is the window"): the shaft leaves the window's middle `SHAFT_WIDE`
## cells wide, about the round pane itself, and opens at `SHAFT_SPREAD` into a cone. It was
## 2.4 cells wide at the wall and opened at 0.78, which lit the whole left of the room as if
## the wall were glass. The shadows obey the same cone (`SHADE_FALL_CODE`).
##
## **From the middle of the left wall, straight across** (2026-10-02, third pass, Richard: "the
## cone comes from center wall and from up. Objects on top should have shadow distorted up and
## objects down should have distorted down"): the window stands half way down the floor's left
## edge (`_window_at`), high up the wall (`WINDOW_HIGH`), and the cone's axis is level
## (`CONE_AXIS`), so it spreads up and down the room alike. It used to leave `WINDOW_DOWN` of
## the shed's height down the wall and slope down the room by the hour (`SUN_SLOPE`, retired),
## which threw every shadow down whatever side of the window its caster stood on. The hour
## still lengthens the shadows (`HOUR_REACH`) and warms the light.
const CONE_AXIS := Vector2(1.0, 0.0)
const SHAFT_WIDE := 0.6
const SHAFT_SPREAD := 0.36
const SHAFT_LONG := 34.0
const SUN_POWER := Vector2(0.30, 0.62)
## How much of the shaft is left in a full shower, and what a lightning flash adds to it.
const RAIN_SUN := 0.25
const FLASH_SUN := 1.2
const SUN_EARLY := Color(1.0, 0.93, 0.74)
const SUN_LATE := Color(1.0, 0.66, 0.34)
const SUN_HOURS := Vector2(0.15, 0.8)
const SUN_NO_DAY := 0.6
## What is laid over the lake behind the room, so the room is the lit thing on the screen:
## a warm dark rather than the boards' cold scrim.
const ROOM_SCRIM := Color(0.09, 0.055, 0.03, 0.66)
## The room's own shade, laid over the floor and the furniture under the light quad. The
## light is additive and can only brighten, so without something to lift it out of, the
## shaft reads as a pale wash rather than as sun: the room is dimmed a little and the window
## gives it back where the light falls.
const ROOM_DIM := Color(0.05, 0.03, 0.02, 0.26)


## The window is the light (2026-10-02, second pass, Richard: "the window should be what
## affects shadow, so objects closer to the light source should have a darker shadow, and
## there should be a stretch on shadows cast"). A point light, not a sun: every shadow falls
## straight away from the window (`_window_at`), and the further a caster stands from it the
## lower the light comes in and the longer its shadow is laid — `WINDOW_HIGH` cells is how
## high the window is over the floor, so a caster that far out throws a shadow as long as it
## is tall, times the hour's own lengthening (`HOUR_REACH`, morning to late afternoon), held
## between `REACH_LEAST` and `REACH_MOST`. A caster above the window throws its shadow up
## the room and one below it down (third pass): the window is in the middle of the wall, so
## nothing holds a shadow to falling down the screen any more (`AWAY_DOWN`, retired), and the
## shadows are laid by `_lay`, which lets the stretch go negative where `Shade.lying` would not.
##
## And darker near it: the group of shadows is drawn through `SHADE_FALL_CODE`, which takes
## each pixel of shadow from `NEAR_DARK` of the ink by the window to `FAR_DARK` of it
## `DARK_REACH` cells away, in `DARK_STEPS` hard steps (the shaft's own pixel-art rule).
##
## **Only inside the cone**: a shadow is light that is not getting through, and outside the
## shaft there was none to stop — only the room's bounce. So each pixel of shadow is kept by
## how far inside the shaft it lies, the shaft's own Gaussian (`SHAFT_WIDE`, `SHAFT_SPREAD`
## along `sun_dir`), down to `OUTSIDE_DARK` of itself out of it. All first guesses for
## Richard's eye.
## Kept low and close to the base (2026-10-02, fourth pass, Richard: "too stretched out and huge,
## the light isn't that strong, keep it more grounded"): the window counted twice as high, the
## longest shadow under half its caster's height, the hour moving it less. Were 8, 0.3..1.5 and
## 0.8..1.3; the dark by the window came down with them (`NEAR_DARK` 1.7 to 1.3).
const WINDOW_HIGH := 16.0
const HOUR_REACH := Vector2(0.9, 1.1)
const REACH_LEAST := 0.12
const REACH_MOST := 0.42
const NEAR_DARK := 1.3
const FAR_DARK := 0.45
const DARK_REACH := 34.0
const DARK_STEPS := 5.0
const OUTSIDE_DARK := 0.18
const SHADE_FALL_CODE := """shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec2 window_at = vec2(0.0);
uniform float near_dark = 1.7;
uniform float far_dark = 0.45;
uniform float dark_reach = 300.0;
uniform float dark_steps = 5.0;
uniform float art_px = 2.0;
uniform vec2 sun_dir = vec2(0.85, 0.52);
uniform float shaft_wide = 10.0;
uniform float shaft_spread = 0.36;
uniform float outside_dark = 0.18;
varying vec2 local;
void vertex() {
	local = VERTEX;
}
void fragment() {
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	if (c.a > 0.0001) {
		c.rgb /= c.a;
	}
	vec2 at = floor(local / art_px) * art_px;
	float far = clamp(distance(at, window_at) / dark_reach, 0.0, 1.0);
	far = floor(far * dark_steps + 0.5) / dark_steps;
	vec2 from = at - window_at;
	vec2 dir = normalize(sun_dir);
	float along = dot(from, dir);
	float across = dot(from, vec2(-dir.y, dir.x));
	float wide = shaft_wide + max(along, 0.0) * shaft_spread;
	float lit = exp(-(across * across) / (wide * wide)) * step(0.0, along);
	lit = floor(lit * dark_steps + 0.5) / dark_steps;
	COLOR *= c;
	COLOR.a = clamp(COLOR.a * mix(near_dark, far_dark, far) * mix(outside_dark, 1.0, lit), 0.0, 1.0);
}
"""
## The walkers' shadows are drawn white and inked by the group, like `Shade.Face`'s triangles:
## a sprite cannot be turned white by a modulate, so this does it.
const SILHOUETTE_CODE := "shader_type canvas_item;\nvoid fragment() {\n\tCOLOR.rgb = vec3(1.0);\n}\n"


## How wide a floorboard is, in source pixels. The boards are the room, not the grid: the
## grid is half this and drawing a line every four screen pixels reads as corduroy.
const BOARD := 16

## The room's shell art: floor and wallpaper tiles, and the wooden frame round the door
## opening. From art_source/Interior_Bed_and_Textures (psd-extract, "Shed Border" and
## "Texture" groups) — see tools/decor_sets.json for the bed pulled from the same file.
##
## "Shed Border" reads as a picture-frame moulding once its pieces are laid out at the
## relative positions the PSD's own "Shed Border Example" group draws them at (built once
## as a throwaway composite to check this): small corners and a tiled strip across the top,
## taller corners and a "down view" sill across the bottom, an open rectangle in the
## middle. That middle is the door, not a picture — this used to be read as trim for the
## floor's whole perimeter and drawn round floor_box, which was wrong; it frames the
## doorway in the wall instead.
const FLOOR_TILE := preload("res://assets/Shed_Floor_Tile.png")
const WALLPAPER_TILE := preload("res://assets/Shed_Wallpaper_Tile.png")
const BORDER_TOP_LEFT := preload("res://assets/Shed_Border_Top_Left.png")
const BORDER_TOP_RIGHT := preload("res://assets/Shed_Border_Top_Right.png")
const BORDER_BOTTOM_LEFT := preload("res://assets/Shed_Border_Bottom_Left.png")
const BORDER_BOTTOM_RIGHT := preload("res://assets/Shed_Border_Bottom_Right.png")
const BORDER_VERTICAL := preload("res://assets/Shed_Border_Vertical.png")
const BORDER_HORIZONTAL := preload("res://assets/Shed_Border_Horizontal.png")
const BORDER_SILL := preload("res://assets/Shed_Border_Baseboard.png")

## A little more than the moulding itself, so a walker stands clear of the skirting rather
## than with its heels on the line. In cells. See `_feet_keep`.
const FEET_CLEAR := 0.25
## How far a walker's feet are held off a standing piece's base, in placement pixels
## (2026-09-27): the base rectangle grown by this on every side is what blocks.
const WALK_CLEAR := 3


## How tall the back wall stands, in floor cells.
##
## In cells rather than pixels (it was `BOARD * ZOOM * WALL_GROW`, 91 px whatever the zoom,
## 2026-09-13) because furniture now stands *against* it: only a piece's base takes floor,
## and the rest of its picture rises up the wall, so the wall has to be a number of rows a
## piece can be placed in — the same at every window size, or a room saved on one screen
## would have its bookcase's top through the ceiling on another. Four rows is a fridge
## (seven cells tall, one of base) standing two rows off the wall, and the tall bookcase
## one. `_zoom()` fits the wall and the floor together into the panel.
const WALL_ROWS := 4

## The wall in placement pixels: how far above the boards a picture may rise.
const PLACE_WALL := WALL_ROWS * CELL

## The door in the back wall: how wide it is against its own height, how much of the wall it
## stands in, and where along the wall it sits.
##
## Sized off the wall rather than off the floor grid, because a door is a shape and not a
## number of cells: five cells across a forty-eight pixel wall came out wider than it was
## tall, which reads as a hatch lying on its side.
##
## The lake has the player walk up to a hut and press a key; inside, the same hut had no way
## in and no way out but a cross in the corner. The door is where they came in, and it is
## what the room is oriented around — the wall is the north side, so the door is in it.
const DOOR_WIDE := 0.7
const DOOR_TALL := 1.0
const DOOR_ALONG := 0.5

## The doorway itself, inside the frame the border moulding draws — an open, empty vent
## into the shed rather than a leaf standing shut in it.
const DOOR_OPEN := Color(0.05, 0.04, 0.05)

## How many source rows of the horizontal strip are the flat band along its top — the dark
## line and the plain wood under it — before the moulding starts on row 4. That band is
## what carries over the door as its lintel; the moulding below it stops at the jambs.
const LINTEL_ROWS := 4

## The player, indoors: the cut sheet they are drawn from, how tall they draw in cells, how
## fast they walk across them, and the longest step one frame may take.
##
## The height is what is asked for and the drawing rounds it to whole pixels of art, so this
## moves in steps: at the room's usual zoom, 3.1 cells came out as a figure forty pixels tall
## standing beside a dog thirty-eight, which is a child next to a labrador. 4.4 lands on the
## next step up and puts the two back in the proportion they have on the island.
##
## Then 4.4 read as a giant in a room whose furniture is drawn at house scale, so it went
## down by a third to 3.4; back up to 4.4 (2026-09-13, Richard: "player looks too small
## inside shed, increase 1.3x"); and to half way between, 3.9, the same day ("too big").
## At the room's usual zoom of 2 that is a figure a pixel and a half of screen to one of
## art, so the rounding is to *half* pixels now (`YOU_STEP`) — whole pixels only ever gave
## one of the two sizes Richard had already rejected. The dog stays at DOG_TALL.
##
## The same sheet the lake draws them from — four directions, idle and run — read here
## rather than borrowed off the Angler node, because that node walks an island: its rules are
## a shoreline and a hut footprint, and none of that is in this room. Frames are held for
## Angler.IDLE_FRAME and Angler.RUN_FRAME, so the figure moves the same indoors as out.
const YOU_ART := Angler.ART
const YOU_TALL := 3.9
## What the figure's scale is rounded to, in screen pixels per pixel of art.
const YOU_STEP := 0.5
const YOU_SPEED := 7.0
const YOU_STEP_MOST := 0.7

## How far the player stands in front of the door when the room opens, in cells. Just onto
## the floor: they have come through it, not out of the wall.
const YOU_ENTRY := 2.0

## How close the player and the dog may get in here, in cells: a cell is eight source pixels
## and the two of them are about two cells wide at the feet.
##
## Kept indoors only. Outside, the two walk through each other — the island is small and an
## animal that pushes back out there is an animal in the way — but a room is a room, and a dog
## you shove through the wardrobe is worse than one you have to step round.
const ROOM_PERSONAL := 1.6

## How many spots a dog looks at before settling for where it already is. Four of them and
## a player in one room, each wanting `ROOM_PERSONAL` of floor, is a lot more to miss than
## one dog was, and a dart that fails leaves the animal standing still.
const IDLE_DARTS := 32

signal changed

## The cross in the corner. The room is the whole screen now, so the way out is a button on
## the room rather than a bar of panel underneath it.
signal close_asked

## The record player: E at it lifts the lid and puts its menu up over the room
## (`RecordMenu`, 2026-09-28); closing it leaves the lid open. While the menu is up
## the room takes no input of its own.
const RECORD_PIECE := &"decor_vynil_player"
var _record: RecordMenu
## The row in `decor` whose lid the menu opened, or -1.
var _record_row := -1

## The art, and the two arrays this screen is a view of. Both are owned by lake.gd — the
## room edits `decor` in place rather than keeping a copy, so what is on screen and what
## gets saved cannot drift apart.
var sheets: Sheets
var unlocked: Array[String] = []

## The finds waiting at the pump, unwashed — the lake's own list, read for the wash plank
## on the shelf: shown only while something waits, right after the last row (and scrolling
## with them, Richard's call, 2026-09-22 — so it counts in the scroll span), or alone under
## "Nothing kept yet." when the shelf holds nothing. Clicking it asks the lake for the wash
## room (`wash_asked`): the shed goes down and the room comes up in one click.
var unwashed: Array[String] = []
signal wash_asked

## A dog in the room petted, by its slot (`Dog.slot`), at the touch: the lake keeps the
## tally for Best Pals (2026-10-06).
signal dog_petted(slot: int)

var _wash_plank: PlankButton
## The plank breathes the HUD's own pulse the first time the shelf opens with more waiting
## than it last saw (`opened`); session only, nothing saved.
var _wash_pulse: float = 0.0
var _wash_clock: float = 0.0
var _wash_unseen: bool = false
var _wash_seen: int = 0
const WASH_PULSE_TIME := 4.0
const WASH_PULSE_BEATS := 3.5
## After the burst it settles here and keeps breathing until the plank is clicked (Richard,
## 2026-09-22), the HUD's own rule.
const WASH_PULSE_IDLE := 0.45

## Piece name -> what to call it on screen. Filled in by lake.gd from the defs.
var titles := {}
var decor: Array = []
## The switchable kinds the player has worked at least once, by piece name (2026-10-02).
## Owned by the lake, which saves it, and shared by reference like `decor`. A kind not in it
## wears the pointing hand (`hand_rows`).
var switch_tried: Array[String] = []

## The cues (2026-10-02, `/grill-me` with Richard). The turn chip rides beside a carried piece
## that R would change, whole for `TURN_HINT_HOLD` from the moment it is picked up and then
## fading over `TURN_HINT_FADE`. The hand bobs over every placed switch of a kind never worked.
const TURN_HINT_HOLD := 2.0
const TURN_HINT_FADE := 0.6
const TURN_HINT_GAP := 6.0
## The hand, the angler's own (2026-10-03, Richard's pick C off `tools/last_hand_mockup.png`,
## `tools/hand_mockup.py`): the silhouette pointing down, seen from the back, the shirt's cuff
## over the top `HAND_CUFF` rows, the thumb bulging left, the curled fingers along the bottom
## right, the index finger down the left. Outlined, toned and creased by rule in `_hand_image`,
## lit from the right like every painted asset, and drawn at the furniture's grain.
const HAND := [
	"....########....",
	"...##########...",
	"...##########...",
	"...##########...",
	"..############..",
	".##############.",
	"################",
	"################",
	"################",
	".###############",
	".##############.",
	"..#####.##.##...",
	"..####..........",
	"..####..........",
	"..####..........",
	"..####..........",
	"..####..........",
	"..####..........",
	"...##...........",
]
const HAND_CUFF := 4
## The fingertip's foot, in the silhouette's own pixels.
const HAND_TIP := Vector2(3.5, 19.0)
## The angler's skin (off `assets/character.png`) and his shirt's cream, by tone.
const HAND_SKIN := {
	&"body": Color8(243, 166, 119), &"mid": Color8(228, 143, 101), &"lit": Color8(252, 198, 158),
	&"low": Color8(192, 87, 63), &"line": Color8(196, 98, 68),
}
const HAND_SHIRT := {
	&"body": Color8(236, 218, 177), &"mid": Color8(222, 202, 160), &"lit": Color8(250, 240, 214),
	&"low": Color8(185, 160, 121), &"line": Color8(150, 124, 90),
}
const HAND_INK := Color8(24, 18, 17)
const HAND_NAIL := [Color8(250, 206, 186), Color8(236, 178, 160)]
## The star winking at the fingertip, the finds' gold.
const HAND_STAR_AT := Vector2i(8, 15)
const HAND_STAR_GOLD := Color8(255, 205, 77)
const HAND_STAR_PALE := Color8(255, 245, 200)
## The soft shadow down and to the left.
const HAND_SHADE := Color(0.0, 0.0, 0.0, 0.27)
## The furniture's grain: the pack pieces are drawn at this many room pixels an art pixel
## (`build_pack_decor.py`'s SHED_SCALE).
const HAND_GRAIN := 0.74
## Four frames: how many art px up it bobs on each, how long each is held, and the star's
## arm on each (0 a single gold pixel).
const HAND_BOBS := [0, 1, 1, 0]
const HAND_HOLDS := [0.3, 0.18, 0.18, 0.3]
const HAND_ARMS := [0, 3, 2, 0]
var _hand_frames: Array[ImageTexture] = []
## Where the silhouette's (0, 0) stands in each frame's picture.
var _hand_origin := Vector2i.ZERO
## A turning arrow beside the key on the turn chip, in screen pixels of `TURN_GLYPH_PX`.
const TURN_GLYPH := [
	"..OOOO....",
	".O....O...",
	"O......O..",
	"O....O.O.O",
	"O.....OOO.",
	".O.....O..",
	"..OOO.....",
]
const TURN_GLYPH_PX := 2.0
## The hand's tip stands this many of its own pixels over the top of the piece's drawing.
const HAND_LIFT := 2.0
var _turn_hint := INF
var _carried_was: StringName = &""

## What is being dragged, as a piece name, and where it came from: the index it had in
## `decor`, or -1 when it was picked up off the inventory list.
var carrying: StringName = &""
## The pad has the shelf up: the stick walks its rows rather than the player (RB/LB).
var _pad_shelf := false

## Which face the carried piece is being held in — an index into its views. Set from the
## row it was lifted off so turning a chair, putting it down and picking it up again does
## not quietly straighten it.
var _carry_view: int = 0
var _carried_from: int = -1
var _pointer := Vector2.ZERO
var _scroll: float = 0.0
var _close: CloseButton
var _shelf: ShedShelf

## One dog in the room: where it stands in cells, what it is up to, and which seat it has
## claimed. See `_dog_think`.
##
## A class rather than a Dictionary because every field is read in `_process` and drawn in
## `_draw_dog`, and a typo in a string key would be a dog that quietly stops thinking.
class ShedDog extends RefCounted:
	var at := Vector2.ZERO
	var target := Vector2.ZERO
	var state: StringName = &"idle"
	var age: float = 0.0
	var mood: float = 0.0
	var left: bool = false
	## Which of the pack this is, and so which breed it wears and which gait pair it walks
	## on — the island dog's own rule (`Dog.slot`), so the dog asleep on the rug is the
	## same animal as the one that came in from the beach.
	var slot: int = 0
	var breed: int = 0

	## The seat this dog holds, as its key in `_seats()`, or "" for a dog on the floor.
	## Held rather than looked up each frame: a seat is claimed, and a claim is a fact about
	## the dog, not about the furniture.
	var seat: String = ""

	## Seconds before it can be petted again, and seconds left of its hearts. See
	## `Dog.PET_AGAIN`, which this shares; separate from the lake's dog of the same slot,
	## because the room's dogs are rolled fresh every time the door opens.
	var pet_cool: float = 0.0
	var hearts: float = 0.0

	## The cells this dog is allowed to stand on although something is standing there — the
	## foot of the piece whose seat it holds. Without it the sofa's own base refuses the dog
	## the cushion and `_process`'s unstick shoves it off again every frame.
	var over: Dictionary = {}

	## The way to `target`: the points still to walk, in cells, the target last. Worked out
	## when the target changes (`routed_to`), and how long the dog has been held up.
	var path: Array[Vector2] = []
	var routed_to := Vector2(INF, INF)
	var blocked: float = 0.0


## The walking grids `_path_grid` has built, by exemption, for the furniture `_grids_for`
## hashes.
var _grids: Dictionary = {}
var _grids_for: int = 0

## The dogs that are in, none to `DOGS_MOST`. Empty is a room with nobody in it.
var _dogs: Array[ShedDog] = []

## The dogs in the room, for the harness and the probe. Not for the game: nothing outside
## this file drives them.
func dogs() -> Array[ShedDog]:
	return _dogs


## How many dogs the player owns, asked of the lake each time the room opens rather than
## pushed once: the pack grows mid-run (`Lake._add_dog`), and a number read at `_ready`
## would hold the room at one dog for the whole session. The wash room's own pattern.
##
## Unset — a room with no lake behind it, which is every harness and `tools/wash_spike` —
## reads as one dog, which is what this room has always had.
var pack_size := Callable()
## The lake's day, for the sun through the window. None (every harness) is a fixed afternoon.
var day: DayCycle
var _light: ColorRect

## The room behind everything (`_paint_room`) and the shadows lying on it, both children drawn
## behind the room's own `_draw`, in that order. `_shades` holds the furniture's swept
## triangles (one `Shade.Face` for everything standing, rebuilt when the layout or the light
## steps), the piece in hand's (its own face, moved with the hand rather than rebuilt), and the
## walkers' frames.
var _floor_layer: Node2D
var _shades: CanvasGroup
var _furniture_shade: Shade.Face
var _ghost_shade: Shade.Face
var _walker_shades: Node2D
var _furniture_shade_for := ""
var _ghost_shade_for := ""
## The atlas as an image, read once, and each standing view's casting runs (`_runs_of`).
var _atlas_image: Image
var _shade_runs := {}
## The floor layer's pen while it paints, null otherwise (`_pen`).
var _pen_on: CanvasItem

var _dog_rng := RandomNumberGenerator.new()

## The seat table, and the `decor.hash()` it was built for. Memoised like `_blockers`, and for
## the same reason: `decor` is the lake's own array, edited in place while the room is open.
var _seat_table: Array = []
var _seat_table_for: int = -1

## The player in the room: where they stand in cells, which way they face, how long they
## have been walking (nought when still), and how long the room has been open — which is
## what the idle cycle is counted off.
var _you_at := Vector2.ZERO
var _you_facing := Vector2(0.0, 1.0)
var _you_step: float = 0.0
var _you_age: float = 0.0

## The sheet the player is drawn from. Loaded once, and null when the art is missing — in
## which case the room draws no player rather than a box.
var _you_sheet: Texture2D
var _you_poses := {}

## The piece the player is resting on (its key, as `_seats` keys them, "" when standing),
## what kind of rest it is, how long it has lasted and where the player stood before it, which
## is where they get up to.
var _rest_key := ""
var _rest_kind: StringName = &""
var _rest_age: float = 0.0
var _rest_from := Vector2.ZERO
## Which of the `BOOKS` came off the shelf this time.
var _read_book := 0

## How tall the figure draws inside its cell, and where its feet sit in that cell. See
## `_load_you`.
var _you_ink_tall: float = 43.0
var _you_ink_foot: float = 45.0

## Cells something is standing on, rebuilt when `decor` changes. Rugs are not in it: a dog
## may walk on a rug, and a room full of rugs it refuses to cross is a room it cannot leave.
var _blocked := {}
var _blocked_for: int = -1


func _ready() -> void:
	# Walked with the pad's stick (scripts/pad.gd, `pad_focus` below).
	add_to_group(Pad.FOCUS_GROUP)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Nearest, for the whole room. Everything drawn in here is pixel art blown up by a whole
	# number — the floor grid, the furniture, the dog, the player — and the default bilinear
	# filter softens all of it. Nothing in this screen is ever drawn smaller than it was
	# painted, which is the case nearest handles badly, so it can go on the Control itself.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process_input(false)
	_close = CloseButton.new()
	_close.name = &"CloseRoom"
	_close.tint = Style.INK
	_close.pressed.connect(func() -> void: close_asked.emit())
	add_child(_close)
	_wash_plank = PlankButton.new()
	_wash_plank.name = &"WashPlank"
	_wash_plank.visible = false
	_wash_plank.pressed.connect(func() -> void:
		_wash_pulse = 0.0
		_wash_unseen = false
		wash_asked.emit())
	add_child(_wash_plank)
	# Under the close cross but over the room, and blind to the mouse: the shelf is drawn
	# by a node of its own only so it can be faded as one, and every click on it is still
	# picked up by the room, against the same rects the shelf was handed.
	_light = ColorRect.new()
	_light.name = &"Light"
	_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lit := ShaderMaterial.new()
	lit.shader = LIGHT_SHADER
	_light.material = lit
	add_child(_light)
	_shelf = ShedShelf.new()
	_shelf.name = &"Shelf"
	_shelf.frame_thick = SHELF_FRAME
	_shelf.chips = SHELF_CHIPS
	_shelf.row_gap = SHELF_ROW_GAP
	_shelf.bar_wide = SHELF_BAR
	_shelf.bar_gap = SHELF_BAR_GAP
	_shelf.row_height = float(ROW_HEIGHT)
	_shelf.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_shelf)
	# Under the shelf and the cross, over the room's own `_draw`: light falls on the floor
	# and the furniture, not on the board standing beside them.
	move_child(_shelf, 0)
	move_child(_light, 1)
	_build_shade_layers()
	_dog_rng.randomize()
	_load_you()
	# The dog only runs while the room is on screen: it is a picture of a room, and nothing
	# in it is happening while nobody is looking at it.
	visibility_changed.connect(_room_shown)
	set_process(false)
	_record = RecordMenu.new()
	_record.name = &"RecordMenu"
	_record.visible = false
	_record.closed.connect(_record_closed)
	add_child(_record)


## The room came on screen, or went off it.
##
## Which dogs are in is rolled here rather than kept: it is decided each time the player
## opens the shed, so what is on the floor is a room walked into rather than a room left
## running. Each of the pack rolls `DOG_ODDS` on its own; see the note there about what that
## does to the odds of an empty room.
##
## Every dog that is in claims a free seat on the way, so a room with a sofa and a pet bed
## out has two dogs already lying down when the door opens rather than two dogs setting off
## towards the furniture.
func _room_shown() -> void:
	var showing := is_visible_in_tree()
	set_process(showing)
	if not showing:
		if record_up():
			_record.visible = false
			_record_closed()
		var sound := Sfx.main()
		if sound != null:
			sound.set_fireplace(false)
		return
	# Stood just inside the door, facing the room: they have walked in, not been placed.
	var door := _door_span()
	_you_at = Vector2((door.x + door.y) * 0.5, YOU_ENTRY)
	_you_facing = Vector2(0.0, 1.0)
	_you_step = 0.0
	_you_age = 0.0
	_rest_key = ""

	_dogs.clear()
	if not DogArt.ready():
		return
	for which in _pack_wanted():
		if _dog_rng.randf() >= DOG_ODDS:
			continue
		var dog := ShedDog.new()
		dog.slot = which
		dog.breed = DogArt.breed_of(which)
		# Appended before it is placed, so the one after it keeps clear of where it stands
		# and does not take the seat it has just claimed.
		_dogs.append(dog)
		# On a seat already when one is free, rather than walking over to it while the
		# player watches: the door opening is not an event the dog got up for.
		_claim_seat(dog)
		dog.at = _seat_point(dog.seat) if not dog.seat.is_empty() else _dog_somewhere(dog)
		dog.target = dog.at
		_dog_think(dog)


## How many of the pack to roll for. One when nothing has told the room otherwise.
func _pack_wanted() -> int:
	if not pack_size.is_valid():
		return 1
	return clampi(int(pack_size.call()), 1, DOGS_MOST)


func _process(delta: float) -> void:
	# One long frame is one slow frame. A hitch, or the window coming back after being
	# minimised, hands this whatever delta it likes, and speed times that is a dog that
	# jumps across the room.
	delta = minf(delta, 0.1)
	if _wash_pulse > 0.0:
		_wash_pulse = maxf(_wash_pulse - delta / WASH_PULSE_TIME, WASH_PULSE_IDLE if _wash_unseen else 0.0)
		_wash_clock += delta
		if _wash_plank != null:
			_wash_plank.pulse = wash_pulse_amount()
	_pad_tick()
	_tick_turn_hint(delta)
	_walk_you(delta)
	_carry_with_pad(delta)
	var sound := Sfx.main()
	if sound != null:
		sound.set_fireplace(_fire_lit())
	for dog in _dogs:
		_drive_dog(dog, delta)
	queue_redraw()


## One dog's frame.
func _drive_dog(dog: ShedDog, delta: float) -> void:
	dog.age += delta
	dog.mood -= delta
	dog.pet_cool = maxf(dog.pet_cool - delta, 0.0)
	dog.hearts = maxf(dog.hearts - delta, 0.0)
	# The sofa a dog is asleep on can be picked up while it sleeps, or turned to a face that
	# is nobody's seat. Give the claim up on the spot rather than leaving it holding a key
	# to furniture that is no longer there.
	if not _seat_still_there(dog):
		_drop_seat(dog)
		dog.mood = 0.0
	# Furniture can be put down on top of a dog, which leaves it standing inside a wardrobe
	# with every step out of it refused. Nobody sees it move — the piece is over it — and a
	# dog wedged in a cupboard for the rest of the session is worse than one that turns up a
	# foot to the left. A dog shoved off its seat gives the seat up with it, or it holds a
	# claim on furniture it is no longer anywhere near.
	if not _dog_may_stand(dog.at, dog.over):
		_drop_seat(dog)
		dog.at = _dog_somewhere(dog)
		dog.target = dog.at
	if dog.state == &"walk" or dog.state == &"walk2":
		if _dog_walk(dog, delta) or dog.mood <= 0.0:
			_dog_think(dog)
	elif dog.mood <= 0.0:
		_dog_think(dog)


## Read the player's cut sheet. Nothing drawn if it is missing, which is the same bargain
## every other drawn thing here strikes with its art.
func _load_you() -> void:
	var text := FileAccess.get_file_as_string(YOU_ART)
	if text.is_empty():
		return
	var book: Dictionary = JSON.parse_string(text)
	if book == null or not book.has("poses"):
		return
	var image := Art.image(book["sheet"])
	if image == null:
		return
	# Toned once, here, rather than through a material. The lake puts the angler behind
	# shaders/figure.gdshader; this room draws its floor, its furniture, the dog, the player
	# and the inventory list on one canvas item, so a material would take the whole screen
	# with it. Same arithmetic, same numbers — see Style.figure_tone.
	image = _toned(image)
	_you_sheet = ImageTexture.create_from_image(image)
	for name: String in book["poses"]:
		var frames: Array = []
		for cell: Dictionary in book["poses"][name]:
			var region: Array = cell["region"]
			var ink: Array = cell["ink"]
			var cut := Rect2(region[0], region[1], region[2], region[3])
			var frame := {"region": cut, "ink": Rect2(ink[0], ink[1], ink[2], ink[3])}
			if name.begins_with("sit_"):
				frame["axis"] = _body_axis(image, cut)
			frames.append(frame)
		_you_poses[StringName(name)] = frames

	# What the figure measures inside its cell, taken from one frame and used for every one
	# of them. Scaling a frame to its cell draws the player at the wrong size, since the cell
	# is wider than the figure. Taken once rather than per frame for the same reason player.gd
	# does: the drawing breathes inside its cell, and measuring each frame makes the figure
	# pulse.
	if _you_poses.has(&"idle_south"):
		var first: Dictionary = (_you_poses[&"idle_south"] as Array)[0]
		var ink: Rect2 = first["ink"]
		_you_ink_tall = maxf(ink.size.y, 1.0)
		_you_ink_foot = ink.position.y + ink.size.y


## Where the figure's body stands across its cell, in the cell's own pixels: the median of
## every row's middle (2026-10-03, Richard: a back sit stood off the chair's middle). Its ink
## box is not it: sitting with his back to the room the hand hangs out on one side and puts
## the box's middle a pixel and a half off the body's, which is what a narrow chair shows.
static func _body_axis(image: Image, cell: Rect2) -> float:
	var middles: Array[float] = []
	for y in range(int(cell.position.y), int(cell.end.y)):
		var low := -1
		var high := -1
		for x in range(int(cell.position.x), int(cell.end.x)):
			if image.get_pixel(x, y).a > 0.0:
				if low < 0:
					low = x
				high = x
		if low >= 0:
			middles.append(float(low + high) * 0.5 + 0.5 - cell.position.x)
	if middles.is_empty():
		return cell.size.x * 0.5
	middles.sort()
	return middles[middles.size() / 2]


## A copy of the sheet with the game's own light on it. See Style.figure_tone.
##
## Once, at load: this walks every pixel of the sheet, which is nothing done once and would
## be silly done per frame.
func _toned(art: Image) -> Image:
	var out := Image.create(art.get_width(), art.get_height(), false, Image.FORMAT_RGBA8)
	for y in art.get_height():
		for x in art.get_width():
			var pixel := art.get_pixel(x, y)
			# Cleared pixels are left cleared. The sheet is keyed art and anything written
			# into its transparent margin comes back as a halo the moment it is drawn.
			if pixel.a <= 0.0:
				out.set_pixel(x, y, pixel)
				continue
			out.set_pixel(x, y, Style.figure_tone(pixel))
	return out


## Where the door stands, in cells across the floor: its two edges. Worked back from the
## drawn width so that walking in front of the door and standing in the doorway are the same
## place, however the room is zoomed.
func _door_span() -> Vector2:
	var middle := float(COLS) * DOOR_ALONG
	var wide := _door_size().x / maxf(float(CELL) * _zoom(), 1.0)
	return Vector2(middle - wide * 0.5, middle + wide * 0.5)


## How big the door is drawn, in pixels: as tall as the wall allows, and proportioned from
## that.
func _door_size() -> Vector2:
	var wall := _wall_tall()
	var tall := wall * DOOR_TALL
	return Vector2(tall * DOOR_WIDE, tall)


## Walk the player about the room.
##
## Screen space, not tile space: this is a room seen flat on, so pressing right walks right
## and there is no projection to undo. Blocked cells are the furniture's, the same ones the
## dog is kept out of, and a refused step is tried on each axis alone so walking into the
## side of a wardrobe slides along it instead of stopping dead.
func _walk_you(delta: float) -> void:
	_you_age += delta
	# The reach to pet a dog holds the player still, as on the lake (`Angler.start_pet`).
	if _you_pet >= 0.0:
		_you_step = 0.0
		_you_pet += delta
		if _pet_dog != null and not _pet_touched and _you_pet >= Angler.PET_TOUCH:
			_pet_touched = true
			_pet_dog.hearts = Dog.PET_TIME
			_pet_dog.mood = Dog.PET_TIME
			if Sfx.main() != null:
				Sfx.main().room_sniff()
			dog_petted.emit(_pet_dog.slot)
		if _you_pet >= Angler.PET_TIME:
			_you_pet = -1.0
			_pet_dog = null
		return
	if record_up():
		_you_step = 0.0
		return
	# Resting: any walk input gets up, and so does the piece going away under the player.
	if not _rest_key.is_empty():
		_you_step = 0.0
		_rest_age += delta
		var moving := Vector2(
			Input.get_axis(&"walk_left", &"walk_right"), Input.get_axis(&"walk_up", &"walk_down")
		)
		if moving != Vector2.ZERO or _rest_row() < 0:
			stand_up()
		return
	if _pad_shelf and Pad.is_pad():
		_you_step = 0.0
		return
	var push := Vector2(
		Input.get_axis(&"walk_left", &"walk_right"),
		Input.get_axis(&"walk_up", &"walk_down")
	)
	if push == Vector2.ZERO or not carrying.is_empty():
		_you_step = 0.0
		return
	_you_step += delta
	_you_facing = push.normalized()
	var step := push.normalized() * minf(YOU_SPEED * delta, YOU_STEP_MOST)
	_you_at = _slid(_you_at, step, _you_may_stand)


## With a piece in hand on a pad, the left stick moves it (Richard, 2026-09-14). It walks the
## player the rest of the time; while carrying, the player stands still anyway (`_walk_you`),
## so the stick is free, and it is the stick the thumb is already on.
func _carry_with_pad(delta: float) -> void:
	if carrying.is_empty() or not Pad.is_pad():
		return
	Pad.move_cursor(Input.get_vector(&"walk_left", &"walk_right", &"walk_up", &"walk_down"), delta)


## May the player stand here? The floor, the furniture, and every dog in the room.
##
## The player is never let onto a seat's own cells: a dog is allowed to stand on the sofa
## it is lying on, and the person is not.
func _you_may_stand(where: Vector2) -> bool:
	if _dogs.is_empty():
		return _dog_may_stand(where)
	var pack: Array[Vector2] = []
	for dog in _dogs:
		pack.append(dog.at)
	return _clear_of_all(where, _you_at, pack)


## Which compass direction the player is showing.
##
## Flat on rather than projected, so the rule is simply which way the push leaned: mostly
## sideways is east or west, and the rest is south or north.
func _you_view() -> StringName:
	if absf(_you_facing.x) >= absf(_you_facing.y):
		return &"west" if _you_facing.x < 0.0 else &"east"
	return &"south" if _you_facing.y > 0.0 else &"north"


## The player, standing on the floor of the room. Their shadow is not drawn here: it lies on
## the floor under everything, with the furniture's (`_paint_walker_shades`).
func _draw_you(floor_box: Rect2) -> void:
	if _you_sheet == null:
		return
	if not _rest_key.is_empty() and _rest_kind != &"read":
		_draw_resting(floor_box)
		return
	var shown := _you_shown(floor_box)
	if shown.is_empty():
		return
	draw_texture_rect_region(_you_sheet, shown["box"] as Rect2, shown["region"] as Rect2)


## The standing player's frame as {"at": feet, "box": where it is drawn, "region": the cut
## off the sheet}, or empty when there is nothing to draw. One sum for the figure and for the
## shadow it throws, so the two are always the same frame.
func _you_shown(floor_box: Rect2) -> Dictionary:
	if _you_sheet == null:
		return {}
	var step := float(CELL * _zoom())
	var at := floor_box.position + _you_at * step
	var tall := YOU_TALL * step

	var walking := _you_step > 0.0
	var pose := StringName("%s_%s" % ["run" if walking else "idle", _you_view()])
	var reach := StringName("pet%d_%s" % [_you_pet_arm, _you_view()])
	var petting := _you_pet >= 0.0 and _you_poses.has(reach)
	if petting:
		pose = reach
	var reading := _rest_kind == &"read" and not _rest_key.is_empty()
	var reaching := reading and _rest_age < Angler.PET_TIME
	if reaching:
		pose = StringName("pet%d_north" % READ_REACH_ARM)
	elif reading:
		pose = &"read_south"
	if not _you_poses.has(pose):
		return {}
	var frames: Array = _you_poses[pose]
	var held := Angler.RUN_FRAME if walking else Angler.IDLE_FRAME
	var index := posmod(int(_you_age / held), frames.size())
	if petting:
		index = mini(int(_you_pet / Angler.PET_TIME * frames.size()), frames.size() - 1)
	elif reaching:
		index = mini(int(_rest_age / Angler.PET_TIME * frames.size()), frames.size() - 1)
	elif reading:
		var turning := fmod(_rest_age - Angler.PET_TIME, PAGE_EVERY) > PAGE_EVERY - PAGE_TIME
		index = mini(_read_book * 2 + (1 if turning else 0), frames.size() - 1)
	var frame: Dictionary = frames[index]
	var region: Rect2 = frame["region"]
	var ink: Rect2 = frame["ink"]
	# Scaled by how tall the figure is inside its cell, not by the cell. Whole source pixels,
	# like the lake draws them: a fraction of a pixel makes pixel art look out of focus, and
	# this room is nothing but blown-up pixel art.
	var scale := maxf(1.0, roundf(tall / _you_ink_tall / YOU_STEP) * YOU_STEP)
	# Centred on the figure's ink rather than the cell, for the reason Angler._frame gives:
	# the cells are an even split of a hand-trimmed strip and do not centre the body.
	var size := region.size * scale
	var box := Rect2(
		at - Vector2((ink.position.x + ink.size.x * 0.5) * scale, _you_ink_foot * scale), size
	)
	return {"at": at, "box": box, "region": region}


## Where the door's own empty rect sits, in screen pixels: the dark opening only, not the
## jambs either side of it. `_door_span()` is worked back from the same width, so the
## player walks in through the opening and never through a jamb. Never taller than the
## wall below the lintel band: the top of the run goes over the door, not through it.
func _door_opening(wall: Rect2) -> Rect2:
	var step := float(CELL * _zoom())
	var span := _door_span()
	var size := _door_size()
	var lintel := wall.position.y + float(LINTEL_ROWS) * _zoom()
	var tall := minf(size.y, wall.end.y - lintel)
	return Rect2(
		Vector2(wall.position.x + span.x * step, wall.end.y - tall),
		Vector2(size.x, tall)
	)


## The way in, drawn into the back wall: an open vent with a jamb down each side, not a
## leaf standing shut in it. The jambs are the frame's own vertical strip, stood outside
## the opening so they add to the door rather than narrow it, and they meet the wall's
## top run the way the wall's own sides do — with a corner piece, turned about: the run
## arrives at the left jamb from the left, which is the shape the top-right corner draws,
## and leaves the right jamb to the right, which is the top-left one. The run's moulding
## stops at those corners (`top_gap`); only its flat top band carries on between them,
## over the opening, as the lintel. Under the opening there is no moulding at all —
## floor_box's frame gaps its top run to it (see _draw()), so the way in is not closed
## off by a sill.
func _draw_door(wall: Rect2) -> void:
	if wall.size.y <= 2.0:
		return
	var zoom := _zoom()
	var opening := _door_opening(wall)
	var jamb_wide := BORDER_VERTICAL.get_width() * zoom
	var corner := BORDER_TOP_LEFT.get_size() * zoom
	var left := opening.position.x - jamb_wide
	var right := opening.end.x
	_pen().draw_rect(opening, DOOR_OPEN)
	_draw_room_frame(wall, false, Vector2(left, right + jamb_wide))
	# The lintel: the run's top band only, between the two corners.
	_tile_rect(
		BORDER_HORIZONTAL,
		Rect2(
			Vector2(opening.position.x, wall.position.y),
			Vector2(opening.size.x, float(LINTEL_ROWS) * zoom)
		)
	)
	# Jambs, from under their corners down to the wall's foot.
	_tile_run(
		BORDER_VERTICAL, Vector2(left, wall.position.y + corner.y), wall.size.y - corner.y, false
	)
	_tile_run(
		BORDER_VERTICAL,
		Vector2(right, wall.position.y + corner.y),
		wall.size.y - corner.y,
		false,
		true
	)
	_pen().draw_texture_rect(BORDER_TOP_RIGHT, Rect2(Vector2(left, wall.position.y), corner), false)
	_pen().draw_texture_rect(BORDER_TOP_LEFT, Rect2(Vector2(right, wall.position.y), corner), false)


## Where the jambs come down onto the floor's frame: the top joint upside down. The
## floor's top run stops either side of the door, and each end takes the same corner piece
## the jamb took at the top, turned about the same way (top-right under the left jamb,
## top-left under the right) and flipped upright, so the corner's strip-end rows point up
## into the jamb and its band and dark line sit at the bottom, on the run's own bottom
## line. The jambs carry on down into the run to meet them — a corner stood on the run's
## top line, stub down, read as a piece of frame facing the wrong way with the jamb
## stopping short above it.
func _draw_threshold(opening: Rect2, floor_box: Rect2) -> void:
	var zoom := _zoom()
	var jamb_wide := BORDER_VERTICAL.get_width() * zoom
	var corner := BORDER_TOP_LEFT.get_size() * zoom
	var run_tall := BORDER_HORIZONTAL.get_height() * zoom
	var left := opening.position.x - jamb_wide
	var right := opening.end.x
	var top := floor_box.position.y + run_tall - corner.y
	_tile_run(BORDER_VERTICAL, Vector2(left, floor_box.position.y), top - floor_box.position.y, false)
	_tile_run(
		BORDER_VERTICAL, Vector2(right, floor_box.position.y), top - floor_box.position.y, false, true
	)
	# Negative height flips the piece in place, the same way a negative width mirrors one.
	var upright := Vector2(corner.x, -corner.y)
	_pen().draw_texture_rect(BORDER_TOP_RIGHT, Rect2(Vector2(left, top), upright), false)
	_pen().draw_texture_rect(BORDER_TOP_LEFT, Rect2(Vector2(right, top), upright), false)


## Pick what the dog does next: go somewhere, stand about, lie down, or sleep on its bed.
##
## The bed outranks everything else when there is one out and the dog is not already on it,
## because a pet bed the dog ignores is a joke at the player's expense — they went and found
## it in the lake.
func _dog_think(dog: ShedDog) -> void:
	dog.age = 0.0
	if dog.seat.is_empty():
		_claim_seat(dog)
	if not dog.seat.is_empty():
		# A seat in the room settles it. The bed used to be a coin flip each time the dog
		# thought, so a player who had gone and found it in the lake and put it out watched
		# the animal mooch about beside it half the afternoon. If there is somewhere to lie,
		# the dog lies on it; the mooching is what a dog with no seat left gets.
		var seat := _seat_point(dog.seat)
		if dog.at.distance_to(seat) <= 0.6:
			dog.state = &"sleep"
			dog.mood = DOG_BED_SLEEP
		else:
			dog.state = DogArt.gait(dog.slot, true, dog.breed)
			dog.target = seat
			dog.mood = DOG_MOOD_MOST
		return
	var roll := _dog_rng.randf()
	dog.mood = _dog_rng.randf_range(DOG_MOOD_LEAST, DOG_MOOD_MOST)
	if roll < 0.40:
		dog.state = DogArt.gait(dog.slot, true, dog.breed)
		dog.target = _dog_somewhere(dog)
	elif roll < 0.58:
		dog.state = &"idle"
	elif roll < 0.74:
		dog.state = &"laid"
	elif roll < 0.88:
		dog.state = &"sleep"
	else:
		dog.state = &"sit" if DogArt.has(&"sit", dog.breed) else &"idle"


## One step towards the target. True once it is there, or once it is stuck.
##
## A refused step slides along the face (`_slid`, 2026-09-27) rather than stopping on an
## invisible wall; a slide that makes no ground towards the target gives up and a new target
## is picked, since a dog nosing along a wardrobe for ever reads as a bug.
func _dog_walk(dog: ShedDog, delta: float) -> bool:
	if dog.at.distance_to(dog.target) <= 0.25:
		return true
	# A new target is routed once; a target nothing leads to is given up on the spot.
	if not dog.routed_to.is_equal_approx(dog.target):
		dog.routed_to = dog.target
		dog.blocked = 0.0
		dog.path = _route(dog.at, dog.target, dog.over)
		if dog.path.is_empty():
			return true
	if dog.path.is_empty():
		return true
	# Pull the path straight: skip a corner whenever the next point is in plain sight.
	while dog.path.size() > 1 and _line_clear(dog.at, dog.path[1], dog.over):
		dog.path.remove_at(0)
	var aim: Vector2 = dog.path[0]
	var gap := aim - dog.at
	if gap.length() <= 0.12:
		dog.path.remove_at(0)
		return dog.path.is_empty()
	var step := gap.normalized() * minf(minf(DOG_SPEED * delta, DOG_STEP_MOST), gap.length())
	if absf(step.x) > 0.0001:
		dog.left = step.x < 0.0
	var others := _others_than(dog)
	others.append(_you_at)
	var from := dog.at
	var may := func(where: Vector2) -> bool:
		return _clear_of_all(where, from, others, dog.over)
	var moved := _slid(from, step, may)
	# Held up by the player or another dog: wait a moment, then think again.
	if moved.distance_to(aim) >= from.distance_to(aim) - step.length() * 0.25:
		dog.blocked += delta
		if dog.blocked >= DOG_BLOCKED:
			return true
	else:
		dog.blocked = 0.0
	dog.at = moved
	return dog.at.distance_to(dog.target) <= 0.25


## The floor's walking grid for a dog allowed to stand on `over`: an `AStarGrid2D` with a
## point solid wherever `_dog_may_stand` refuses it, and every free point labelled with the
## patch of floor it belongs to, so whether a dog can get somewhere is one comparison.
## Memoised on the furniture and the exemption; the furniture moving throws the lot away.
func _path_grid(over: Dictionary) -> Dictionary:
	var furniture := decor.hash()
	if furniture != _grids_for:
		_grids_for = furniture
		_grids.clear()
	var key := ",".join(PackedStringArray(over.keys()))
	if _grids.has(key):
		return _grids[key]
	var wide := COLS * PATH_RES
	var tall := ROWS * PATH_RES
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, wide, tall)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	var free := PackedByteArray()
	free.resize(wide * tall)
	for y in tall:
		for x in wide:
			var ok := _dog_may_stand(_grid_at(Vector2i(x, y)), over)
			free[y * wide + x] = 1 if ok else 0
			if not ok:
				grid.set_point_solid(Vector2i(x, y), true)
	# Patches of floor, by flood fill over the same eight neighbours the search walks.
	var label := PackedInt32Array()
	label.resize(wide * tall)
	label.fill(-1)
	var patch := 0
	for i in wide * tall:
		if free[i] == 0 or label[i] >= 0:
			continue
		var stack: Array[int] = [i]
		label[i] = patch
		while not stack.is_empty():
			var at: int = stack.pop_back()
			var ax := at % wide
			var ay := at / wide
			for dy: int in [-1, 0, 1]:
				for dx: int in [-1, 0, 1]:
					var nx: int = ax + dx
					var ny: int = ay + dy
					if nx < 0 or ny < 0 or nx >= wide or ny >= tall:
						continue
					var n: int = ny * wide + nx
					if free[n] == 0 or label[n] >= 0:
						continue
					# A diagonal only where both sides of the corner are free, as the search.
					if dx != 0 and dy != 0 and (free[ay * wide + nx] == 0 or free[ny * wide + ax] == 0):
						continue
					label[n] = patch
					stack.append(n)
		patch += 1
	var out := {"grid": grid, "free": free, "label": label}
	_grids[key] = out
	return out


## A grid point's place on the floor, in cells.
func _grid_at(point: Vector2i) -> Vector2:
	return (Vector2(point) + Vector2(0.5, 0.5)) / float(PATH_RES)


## The free grid point nearest a spot on the floor, or (-1, -1) if none is near.
func _grid_near(where: Vector2, paths: Dictionary) -> Vector2i:
	var wide := COLS * PATH_RES
	var tall := ROWS * PATH_RES
	var free: PackedByteArray = paths["free"]
	var mid := Vector2i((where * float(PATH_RES)).floor())
	var best := Vector2i(-1, -1)
	var best_gap := INF
	for ring in 4:
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				var point := mid + Vector2i(dx, dy)
				if point.x < 0 or point.y < 0 or point.x >= wide or point.y >= tall:
					continue
				if free[point.y * wide + point.x] == 0:
					continue
				var gap := _grid_at(point).distance_squared_to(where)
				if gap < best_gap:
					best_gap = gap
					best = point
		if best.x >= 0:
			return best
	return best


## Can a dog standing at `from` walk to `to`? Both on the same patch of floor.
func _reaches(from: Vector2, to: Vector2, over: Dictionary = {}) -> bool:
	var paths := _path_grid(over)
	var a := _grid_near(from, paths)
	var b := _grid_near(to, paths)
	if a.x < 0 or b.x < 0:
		return false
	var label: PackedInt32Array = paths["label"]
	var wide := COLS * PATH_RES
	return label[a.y * wide + a.x] == label[b.y * wide + b.x]


## The way from `from` to `to` round the furniture, in cells, `to` last; empty when there is
## none.
func _route(from: Vector2, to: Vector2, over: Dictionary = {}) -> Array[Vector2]:
	var way: Array[Vector2] = []
	if not _reaches(from, to, over):
		return way
	var paths := _path_grid(over)
	var grid: AStarGrid2D = paths["grid"]
	for point: Vector2i in grid.get_id_path(_grid_near(from, paths), _grid_near(to, paths)):
		way.append(_grid_at(point))
	way.append(to)
	return way


## Is the straight line between two spots on the floor clear of the furniture?
func _line_clear(from: Vector2, to: Vector2, over: Dictionary = {}) -> bool:
	var steps := maxi(1, ceili(from.distance_to(to) / PATH_LOOK))
	for i in range(1, steps + 1):
		if not _dog_may_stand(from.lerp(to, float(i) / float(steps)), over):
			return false
	return true


## Somewhere on the floor with nothing on it, and not on top of anybody else.
##
## The spacing is what four dogs in one room needed: the pairwise rule in `_clear_of` stops
## a dog walking *through* another, and this stops one choosing a spot a stride from where
## another is standing in the first place. Darts rather than a search, the way the island's
## own loafing spots are picked, and a crowded room falls back to where the dog already is.
func _dog_somewhere(dog: ShedDog) -> Vector2:
	var others := _others_than(dog)
	others.append(_you_at)
	# Only a spot it can walk to — unless it is not standing anywhere yet (the door has just
	# opened) or is wedged in furniture, when anywhere on the floor will do.
	var placed := _dog_may_stand(dog.at, dog.over)
	for _try in IDLE_DARTS:
		var where := Vector2(
			_dog_rng.randf_range(1.0, float(COLS) - 1.0),
			_dog_rng.randf_range(1.0, float(ROWS) - 1.0)
		)
		if not _dog_may_stand(where, dog.over) or (placed and not _reaches(dog.at, where, dog.over)):
			continue
		var room := true
		for other: Vector2 in others:
			if where.distance_to(other) < ROOM_PERSONAL:
				room = false
				break
		if room:
			return where
	return dog.at


## Where every dog but this one is standing.
func _others_than(dog: ShedDog) -> Array[Vector2]:
	var others: Array[Vector2] = []
	for other in _dogs:
		if other != dog:
			others.append(other.at)
	return others


## May a dog stand with its feet on this cell? Inside the floor, and not on furniture.
##
## `over` is the cells a particular dog is allowed to stand on although furniture is
## standing there — the foot of the piece whose seat it holds. Without it a dog sent to a
## sofa would be refused the cushion by the sofa's own base and shoved off by the unstick in
## `_drive_dog` every frame. The pet bed needs none of this: it is left out of `_blockers`
## altogether, which is why it was the only seat that ever worked.
##
## Kept named for the dog, and kept to one argument's worth of default, because the player
## reaches it through `_you_may_stand` and `test_lake` calls it by that name.
func _dog_may_stand(where: Vector2, over: Dictionary = {}) -> bool:
	var keep := _feet_keep()
	if where.x < keep.x or where.y < keep.y:
		return false
	if where.x > float(COLS) - keep.z or where.y > float(ROWS) - keep.w:
		return false
	for block: Dictionary in _blockers():
		if over.has(block["key"]):
			continue
		if (block["box"] as Rect2).has_point(where):
			return false
	return true


## How far inside the floor's own rectangle a walker's feet have to stay, in cells, as
## (left, top, right, bottom).
##
## The moulded frame is drawn inside `_floor_rect` along its outer edge, and the bound used
## to be half a cell on all four sides — narrower than the moulding is on three of them, so
## both walkers stood on the skirting and on the wall's bottom edge (2026-09-16, Richard).
## Measured off the art rather than written down, so a repainted border moves the walls with
## it: the vertical strip's width down the sides, the horizontal run's height along the top,
## the sill's along the bottom. The corner pieces are deeper than the runs and are not
## counted — a corner is a corner, and nobody walks into one on purpose.
##
## Feet only, by decision. The drawing may still rise over the wall, the way a bookcase's
## does: a room where the figure has to fit whole would lose four rows of floor at the top.
func _feet_keep() -> Vector4:
	var trim := _trim()
	return Vector4(
		trim.x / float(CELL) + FEET_CLEAR,
		trim.y / float(CELL) + FEET_CLEAR,
		trim.z / float(CELL) + FEET_CLEAR,
		trim.w / float(CELL) + FEET_CLEAR
	)


## The room's own moulding, in placement pixels, as (left, top, right, bottom). Measured off
## the art rather than written down, so a repainted border moves what stands off it.
##
## **The walkers' bound, not the furniture's** (2026-09-16, Richard: small pieces could not
## be pushed up to the top wall). Holding a *base* clear of the moulding parks a short piece
## a run's width off the wall while a tall one still looks flush against it, because a small
## piece's base is most of its picture and a wardrobe's is a strip at the bottom of one. And
## it is wrong anyway: the runs are the room's own skirting, and furniture standing against a
## wall covers the skirting. What the furniture is held inside is the floor itself — see
## `can_place`.
func _trim() -> Vector4:
	var side := float(BORDER_VERTICAL.get_width())
	return Vector4(
		side, float(BORDER_HORIZONTAL.get_height()), side, float(BORDER_SILL.get_height())
	)



## The same, against several others at once — the pack, or the pack and the player.
##
## The escape hatch is applied **per other**, not once for the whole list: a dog already
## overlapping one of the pack must not thereby be let through all of them and through the
## player as well.
func _clear_of_all(
	where: Vector2, from: Vector2, others: Array[Vector2], over: Dictionary = {}
) -> bool:
	if not _dog_may_stand(where, over):
		return false
	for other: Vector2 in others:
		if from.distance_to(other) < ROOM_PERSONAL:
			continue
		if where.distance_to(other) < ROOM_PERSONAL:
			return false
	return true


## Everywhere in the room a dog may lie down, one entry a piece.
##
## A piece offers a seat when the catalogue authors one for the face it is standing in
## (`Sheets.seat_of`) — the pet beds, the bed, and the sofa and armchair seen from the
## front. Nothing here tests the *name* of a view: the bed's faces are colours and the pet
## bed's are shapes, so "front" would have meant "neither bed".
##
## Each entry carries where the feet go (in cells), the cells the piece's own foot blocks
## (so the dog sitting there can stand on them), and a key that survives the player moving
## the furniture about — the piece and the spot it stands on, not its index in `decor`,
## which shifts the moment anything is picked up.
##
## Memoised on `decor.hash()`, like `_blockers`: `decor` is the lake's array and is edited in
## place while the room is open.
func _seats() -> Array:
	var key := decor.hash()
	if key == _seat_table_for:
		return _seat_table
	_seat_table_for = key
	_seat_table = []
	if sheets == null:
		return _seat_table
	for row: Dictionary in decor:
		var piece := StringName(row["piece"])
		var view := _row_view(row)
		var lift := sheets.seat_of(piece, view)
		if lift <= 0:
			continue
		var span := span_of(piece, view)
		var cell := Vector2i(int(row["cell"][0]), int(row["cell"][1]))
		# The seat is measured up from the picture's bottom edge; the feet stand on it.
		# In cells, because that is what walks.
		var feet := Vector2(
			float(cell.x) + float(span.x) * 0.5, float(cell.y + span.y - lift)
		) / float(CELL)
		_seat_table.append({
			"key": "%s@%d,%d" % [piece, cell.x, cell.y],
			"feet": feet,
			"over": _foot_cells(piece, view, cell),
		})
	return _seat_table


## The cells a piece's own foot stands on, as a set — what a dog lying on it is allowed to
## stand on although `_blockers` says something is there. The same walk `_blockers` does, kept
## apart from it because this is one piece and that is the whole room.
func _foot_cells(piece: StringName, _view: int, cell: Vector2i) -> Dictionary:
	return {"%s@%d,%d" % [piece, cell.x, cell.y]: true}


## Where the feet of a dog holding this seat go, in cells. The middle of the room for a seat
## that has gone — the piece was picked up while the dog was walking to it — which the next
## `_dog_think` sorts out, because the claim goes with it.
func _seat_point(key: String) -> Vector2:
	for seat: Dictionary in _seats():
		if String(seat["key"]) == key:
			return seat["feet"]
	return Vector2(float(COLS) * 0.5, float(ROWS) * 0.5)


## Take a free seat, if there is one. One dog to a seat, the way a stick in the lake is
## claimed (`Dog.claims`): not a lock on the furniture — the player may pick the sofa up
## from under a sleeping dog — but two dogs are never sent to the same cushion.
func _claim_seat(dog: ShedDog) -> void:
	var held := {}
	for other in _dogs:
		if other != dog and not other.seat.is_empty():
			held[other.seat] = true
	for seat: Dictionary in _seats():
		var key := String(seat["key"])
		if held.has(key):
			continue
		dog.seat = key
		dog.over = seat["over"]
		return


## Give a seat up: the piece has gone, or the dog has been shoved off it.
func _drop_seat(dog: ShedDog) -> void:
	dog.seat = ""
	dog.over = {}


## Has the seat this dog holds gone away — the piece picked up, or turned to a face with no
## seat on it? Asked every frame a dog is asleep on one, because the player can do that
## while it is lying there.
func _seat_still_there(dog: ShedDog) -> bool:
	if dog.seat.is_empty():
		return true
	for seat: Dictionary in _seats():
		if String(seat["key"]) == dog.seat:
			return true
	return false


## Every cell something is standing on, rebuilt only when the room's contents change.
##
## Rugs are left out on purpose — they are the floor as far as anything walking is concerned
## — and so is the pet bed, which the dog is supposed to end up on top of.
##
## Only the foot of a piece blocks. A bookcase is drawn tall because it is seen from the
## front, but the part of it standing on the boards is the bottom strip; blocking its whole
## picture put an invisible wall in the air behind every piece in the room.
##
## Pieces stand on pixels and walkers walk on cells (see `CELL`), so a base is turned into
## cells here: a cell is blocked when its **middle** is inside the base, which keeps the
## blocked floor the size of the piece rather than rounding it up to whole cells on all four
## sides. A base too small or too thin to hold any cell's middle blocks the one cell its own
## middle is in, so nothing standing on the boards is ever walked straight through.
## What the walkers may not stand in (2026-09-27, `/grill-me` with Richard; supersedes the
## 8 px cell map `_blockers`): one rectangle a standing piece, its floor base grown by
## `WALK_CLEAR` on every side, in the walkers' units (cells, as floats). Rugs, paintings, the
## pet bed and a small piece set on another block nothing; the picture above a base never
## does. Each carries the piece's key, which `ShedDog.over` holds for the seat it lies on.
func _blockers() -> Array:
	var key := decor.hash()
	if sheets == null:
		return []
	if key == _blocked_for:
		return _blocked.get("list", [])
	_blocked_for = key
	var list: Array = []
	_blocked = {"list": list}
	var grow := float(WALK_CLEAR) / float(CELL)
	for i in decor.size():
		var row: Dictionary = decor[i]
		var piece := StringName(row["piece"])
		if piece == DOG_BED or piece in WALK_OVER or sheets.lies_flat(piece) or sheets.on_wall(piece):
			continue
		# A pot on a table stands on the table, not on the floor: the table blocks for both.
		if sheets.is_small(piece) and _host_of(decor, i) >= 0:
			continue
		var view := _row_view(row)
		var span := span_of(piece, view)
		var cell := Vector2i(int(row["cell"][0]), int(row["cell"][1]))
		var base := base_of(piece, view)
		var foot := Rect2(
			Vector2(float(cell.x), float(cell.y + span.y - base)) / float(CELL),
			Vector2(float(span.x), float(base)) / float(CELL)
		).grow(grow)
		list.append({"key": "%s@%d,%d" % [piece, cell.x, cell.y], "box": foot})
	return list


## Take one step of a walk, sliding along whatever face refuses it (2026-09-27): the whole
## step, else the longer of its two axes alone that is allowed, else the other. `may` is asked
## of each candidate. Returns where the walker ends up.
func _slid(from: Vector2, step: Vector2, may: Callable) -> Vector2:
	if bool(may.call(from + step)):
		return from + step
	var along_x := from + Vector2(step.x, 0.0)
	var along_y := from + Vector2(0.0, step.y)
	var x_ok := absf(step.x) > 0.0001 and bool(may.call(along_x))
	var y_ok := absf(step.y) > 0.0001 and bool(may.call(along_y))
	if x_ok and y_ok:
		return along_x if absf(step.x) >= absf(step.y) else along_y
	if x_ok:
		return along_x
	if y_ok:
		return along_y
	return from


## The dog, on the floor, at whatever size the room is drawn.
##
## Its shadow is its own frame laid along the room's light, drawn under everything with the
## rest of the room's shadows (`_paint_walker_shades`): a dog with nothing under it hovers over
## the boards. It used to stand on a black ellipse of its own here.
func _draw_dog(floor_box: Rect2, dog: ShedDog) -> void:
	var step := CELL * _zoom()
	var at := floor_box.position + dog.at * float(step)
	var tall := DOG_TALL * float(step)
	DogArt.stamp(
		self, dog.state, DogArt.frame_at(dog.state, dog.age, dog.breed), at, tall, dog.left,
		0.0, Color.WHITE, dog.breed
	)
	if dog.hearts > 0.0:
		Dog.hearts_on(self, at, tall / Dog.HEIGHT, 1.0 - dog.hearts / Dog.PET_TIME)


## One of the things that walk about in here, drawn where the sort put it: a dog, or the
## player, whose entry carries no dog.
func _draw_walker(floor_box: Rect2, walker: Dictionary) -> void:
	var dog: ShedDog = walker["dog"]
	if dog == null:
		_draw_you(floor_box)
	else:
		_draw_dog(floor_box, dog)


## The cross, nailed to the right end of the shelf's title plank.
##
## It used to sit in the air above the inventory column. Once the board grew a title plank
## along that edge there was nothing above it to sit in, and the cross covered the title —
## so it sits *on* the plank now, and `_title_box` keeps the writing clear of it.
func _place_close() -> void:
	if _close == null:
		return
	var at := Style.close_on(_ribbon_rect(), CLOSE_SIDE)
	_close.size = at.size
	_close.position = at.position


## The stretch of the title plank the cross leaves free. Mirrored at the left end, so the
## title stays centred on the board rather than sliding off towards the far side.
func _title_box() -> Rect2:
	return Style.title_room(_ribbon_rect(), CLOSE_SIDE)


## Everything unlocked that is not already standing in the room.
## What is on the shelf: everything found, less what is already standing in the room and
## whatever is in hand.
##
## Counted rather than matched by name. The chairs come four to a set and each copy is its
## own row in `unlocked`, so "is one of these on the floor?" would empty the shelf of all
## four the moment the first one was stood down.
func in_store() -> Array[String]:
	var out := {}
	for row: Dictionary in decor:
		var name := String(row["piece"])
		out[name] = int(out.get(name, 0)) + 1
	if not carrying.is_empty():
		out[String(carrying)] = int(out.get(String(carrying), 0)) + 1
	var left: Array[String] = []
	for name: String in unlocked:
		var standing := int(out.get(name, 0))
		if standing > 0:
			out[name] = standing - 1
			continue
		left.append(name)
	return left


## Which placement pixel a point on screen falls on. Named for what it is: this is not a
## cell any more (2026-09-16 — see `CELL`), and a caller that treats it as one is out by
## eight.
func spot_at(where: Vector2) -> Vector2i:
	var floor_at := (where - _floor_origin()) / maxf(_zoom(), 0.001)
	return Vector2i(int(floor(floor_at.x)), int(floor(floor_at.y)))


## How many placement pixels a piece takes up, in the face it is standing in — which is just
## how big it is drawn (`view_size_of`, the art times the piece's own scale), rounded to
## whole pixels. No rounding to a grid any more, so a footprint *is* the object rather than
## the nearest few cells to it.
func span_of(piece: StringName, view: int = 0) -> Vector2i:
	return sheets.footprint_view(piece, view, 1) if sheets != null else Vector2i.ONE


## How many of a piece's bottom rows of pixels stand on the floor, in this face. The rest
## of the picture is height, and rises up the back wall when the piece is pushed to it.
##
## The catalogue authors a base in **cells** (`Sheets.base_of`), and for nearly everything
## it stays authored that way — a base is a rough depth, not something anybody measures to
## the pixel. So the answer is read at `CELL` and then multiplied back up, never asked for
## at a granularity of one: `bases` holds cells, and `Sheets.base_of` would hand those
## straight back as pixels.
##
## **Except where a cell is too coarse to say the thing** (2026-09-19, issue #30, Richard:
## the potted plant "has invisible pixels behind it"). A piece's whole base must stay on the
## boards (`can_place`), so the base is exactly how far the picture may *not* go up the back
## wall — and the smallest a cell can say is 8 px, which on a 23 px pot is a third of it.
## The pot stood 8 px down the floor with nothing drawn in the gap. A `base_px` says the
## same thing in the drawing's own pixels; the two are never both authored for one piece.
##
## What this is **not** is a free unit swap. The number read here is also the walker block
## (`_blockers`), the small piece's host probe (`_host_of`) and the band a walker sorts over
## (`_walker_key`), so a piece given a one- or two-pixel base blocks a single cell, finds
## its host from just above its own foot, and is never stood on. That is right for a pot
## and would be wrong for a sofa. Author a `base_px` only where the picture's contact with
## the floor really is a couple of pixels deep.
func base_of(piece: StringName, view: int = 0) -> int:
	if sheets == null:
		return CELL
	var tall := span_of(piece, view).y
	if sheets.has_base_px(piece, view):
		return clampi(sheets.base_px_of(piece, view), 1, tall)
	return clampi(sheets.base_of(piece, view, CELL) * CELL, 1, tall)


## Which face a row of `decor` is standing in. Rows written before a piece had faces, and
## rows for pieces that only ever had one, read as the first.
func _row_view(row: Dictionary) -> int:
	return int(row.get("view", 0))


## Can this piece stand with its top-left corner in this cell?
##
## The only rule is that its base has to be on the floor — the picture above the base may
## rise up the back wall, as far as the wall goes — or, for a painting, that the whole of it
## hangs on the wall. Things are deliberately allowed to overlap: an armchair belongs on a
## rug, a lamp belongs beside a table with its base tucked under the edge, and a room where
## nothing may touch anything is a spreadsheet. What stops a pile of junk is the drawing
## order, not a refusal (Richard, 2026-09-13, keeping it so) — see `_order`.
func can_place(piece: StringName, cell: Vector2i, view: int = 0, _ignore: int = -1) -> bool:
	if sheets == null:
		return false
	var span := span_of(piece, view)
	# Sideways and over the wall's top, the same bounds as ever: the floor's own rectangle,
	# and the wall above it. The moulding is not a bound — see `_trim`.
	if cell.x < 0 or cell.x + span.x > PLACE_COLS or cell.y < -PLACE_WALL:
		return false
	if sheets.on_wall(piece):
		return cell.y + span.y <= 0
	# A floor piece keeps its whole base on the floor. The rest of the picture is height and
	# rises up the wall, and a piece standing against the back wall draws over the skirting
	# the way furniture in a room does.
	return cell.y + span.y - base_of(piece, view) >= 0 and cell.y + span.y <= PLACE_ROWS


## Put a piece down, if it fits. The one way anything enters `decor`.
func place(piece: StringName, cell: Vector2i, view: int = 0) -> bool:
	if not can_place(piece, cell, view):
		return false
	decor.append({
		"piece": String(piece),
		"cell": [cell.x, cell.y],
		"view": posmod(view, sheets.view_count(piece)) if sheets != null else 0,
	})
	changed.emit()
	return true


## Turn the piece in hand, or pick the next style of it. What R does.
##
## Only while carrying: a placed piece is turned by picking it up again, which keeps one
## gesture for one thing and means a room cannot rearrange itself under the cursor.
func turn_carried() -> void:
	if carrying.is_empty() or sheets == null or not sheets.turnable(carrying):
		return
	_carry_view = sheets.turned(carrying, _carry_view)
	queue_redraw()


## The turn chip's clock: back to nought the frame a piece comes into the hands, from the
## shelf or off the floor. Turning does not restart it.
func _tick_turn_hint(delta: float) -> void:
	if carrying.is_empty():
		_turn_hint = INF
	elif _carried_was.is_empty():
		_turn_hint = 0.0
	else:
		_turn_hint += delta
	_carried_was = carrying


## How much of the turn chip is drawn, 0 to 1. Nothing when R would leave the piece in hand
## as it is: a pot has one face, and a counter turned side on may have nowhere to go.
func turn_hint_alpha() -> float:
	if carrying.is_empty() or sheets == null or _turn_hint == INF:
		return 0.0
	if sheets.turned(carrying, _carry_view) == _carry_view:
		return 0.0
	if _turn_hint <= TURN_HINT_HOLD:
		return 1.0
	return clampf(1.0 - (_turn_hint - TURN_HINT_HOLD) / TURN_HINT_FADE, 0.0, 1.0)


## A switchable kind has been worked: its hands go, every copy at once.
func _tried(piece: StringName) -> void:
	if not switch_tried.has(String(piece)):
		switch_tried.append(String(piece))


## The placed pieces wearing the hand, as indices into `decor`: every piece of a kind never
## worked that switches **in the face it stands in** (2026-10-03, Richard: a counter turned
## side on, where E does nothing, wore the hand because some other face of it switched), bar
## the one the player stands in E's reach of (the key chip is over it then). None while a
## piece is in hand, so the turn chip has the room to itself.
func hand_rows() -> Array[int]:
	var out: Array[int] = []
	if sheets == null or not carrying.is_empty() or record_up():
		return out
	var near := _switch_near()
	for i in decor.size():
		if i == near:
			continue
		var piece := StringName(decor[i]["piece"])
		if switch_tried.has(String(piece)) or sheets.switched(piece, _row_view(decor[i])) < 0:
			continue
		out.append(i)
	return out

## The reach to pet the room's dogs (2026-09-28): what the lake's angler does, drawn on the
## same sheet and aimed by `Angler.arm_toward`.
var _you_pet := -1.0
var _you_pet_arm := 0
var _pet_dog: ShedDog = null
var _pet_touched := false


## The nearest dog in reach that can be petted now, or null.
func _dog_near() -> ShedDog:
	var best: ShedDog = null
	var best_gap := REACH
	for dog in _dogs:
		if dog.pet_cool > 0.0:
			continue
		var gap := _you_at.distance_to(dog.at)
		if gap < best_gap:
			best_gap = gap
			best = dog
	return best


## Start the reach at this dog: it sits and turns to the player, the player turns to it, and
## it is petted when the hand lands (`_walk_you`). A dog lying on its seat keeps the seat.
func pet_dog(dog: ShedDog) -> void:
	dog.pet_cool = Dog.PET_AGAIN
	if dog.seat.is_empty():
		dog.state = &"sit" if DogArt.has(&"sit", dog.breed) else &"idle"
	dog.mood = Dog.PET_WAIT + Dog.PET_TIME
	dog.left = _you_at.x < dog.at.x
	var toward := dog.at - _you_at
	if toward.length_squared() > 0.0001:
		_you_facing = toward.normalized()
	var shoulder := _you_at - Vector2(0.0, YOU_TALL * Angler.PET_SHOULDER)
	var head := dog.at + Vector2((-0.35 if dog.left else 0.35) * DOG_TALL, -DOG_TALL * 0.55)
	var body := dog.at - Vector2(0.0, DOG_TALL * 0.35)
	_you_pet_arm = Angler.arm_toward(_you_view(), shoulder, [head, body])
	_you_pet = 0.0
	_pet_touched = false
	_pet_dog = dog


func petting() -> bool:
	return _you_pet >= 0.0


## The middle of a placed piece's foot, in cells, where `_switch_near` measures from.
func _switch_middle(i: int) -> Vector2:
	var row: Dictionary = decor[i]
	var piece := StringName(row["piece"])
	var span := span_of(piece, _row_view(row))
	return Vector2(
		float(int(row["cell"][0])) + float(span.x) * 0.5,
		float(int(row["cell"][1])) + float(span.y)
	) / float(CELL)


## The placed piece the player is standing close enough to work, as an index into `decor`,
## or -1. Nearest first, so two switches side by side are not a coin toss.
func _switch_near() -> int:
	if sheets == null:
		return -1
	var best := -1
	var best_gap := REACH
	for i in decor.size():
		var row: Dictionary = decor[i]
		var piece := StringName(row["piece"])
		# Asked of the view it stands in, not of the piece: the counter switches facing
		# front and does nothing turned side on, where no empty sink was drawn.
		if sheets.switched(piece, _row_view(row)) < 0:
			continue
		var span := span_of(piece, _row_view(row))
		# In cells: REACH is a walker's distance and the player stands in cells.
		var middle := Vector2(
			float(int(row["cell"][0])) + float(span.x) * 0.5,
			float(int(row["cell"][1])) + float(span.y)
		) / float(CELL)
		var gap := _you_at.distance_to(middle)
		if gap < best_gap:
			best_gap = gap
			best = i
	return best


## Switch the piece the player is standing at: light the fire, open the fridge. What E does.
##
## The footprint is left alone on purpose. Both state sets are drawn the same size in both
## faces, and re-measuring the floor under a piece the player is only looking at could
## shove it out of a room it already fits in.
## For the decoration tour: the shelf's board, the room, and the first
## placed piece that works a switch, all in this control's pixels (empty when there is none).
func shelf_box() -> Rect2:
	return _board_rect()


func room_box() -> Rect2:
	return _shed_rect()


func switch_box() -> Rect2:
	if sheets == null:
		return Rect2()
	for row: Dictionary in decor:
		var piece := StringName(row["piece"])
		if sheets.switched(piece, _row_view(row)) < 0:
			continue
		var at := Vector2(float(int(row["cell"][0])), float(int(row["cell"][1])))
		var span := Vector2(span_of(piece, _row_view(row)))
		return Rect2(_floor_origin() + at * _zoom(), span * _zoom()).grow(4.0)
	return Rect2()


## The shed's E (2026-09-28): a switch or a dog, whichever is nearer the player (Richard:
## "nearest wins"). A dog still waiting out its ten seconds is not a candidate, so beside one
## E works the switch or does nothing.
func switch_near() -> bool:
	if _you_pet >= 0.0:
		return true
	if not _rest_key.is_empty():
		stand_up()
		return true
	var at := _switch_near()
	var dog := _dog_near()
	var rest := _rest_near()
	var switch_gap := INF if at < 0 else _you_at.distance_to(_switch_middle(at))
	var dog_gap := INF if dog == null else _you_at.distance_to(dog.at)
	var rest_gap := INF if rest < 0 else _rest_gap(rest)
	if rest >= 0 and _dog_on(rest, dog):
		# The dog lying on the piece is part of it: E lies down beside it, not pets it.
		dog_gap = INF
	if rest >= 0 and rest_gap < switch_gap and rest_gap < dog_gap:
		rest_on(rest)
		return true
	if dog != null and dog_gap < switch_gap:
		pet_dog(dog)
		return true
	if at < 0:
		return false
	var row: Dictionary = decor[at]
	_tried(StringName(row["piece"]))
	if StringName(row["piece"]) == RECORD_PIECE:
		_open_record(at)
		return true
	row["view"] = sheets.switched(StringName(row["piece"]), _row_view(row))
	changed.emit()
	queue_redraw()
	return true


## Whether the record player's menu is up.
func record_up() -> bool:
	return _record != null and _record.visible


## Put the record player's menu away: the pad's switch button, the menu's own E.
func close_record() -> void:
	if record_up():
		_record.close()


## Lift the record player's lid and put its menu up.
func _open_record(at: int) -> void:
	var row: Dictionary = decor[at]
	var piece := StringName(row["piece"])
	_tried(piece)
	if not sheets.is_on(piece, _row_view(row)):
		row["view"] = sheets.switched(piece, _row_view(row))
		changed.emit()
	_record_row = at
	Sfx.ui(&"ui_click")
	_record.open()
	queue_redraw()


## The menu went away. The lid it opened stays open.
func _record_closed() -> void:
	var at := _record_row
	_record_row = -1
	if at < 0 or at >= decor.size():
		return
	# The lid stays open (Richard, 2026-09-28): the player is left playing.
	queue_redraw()


## Whether any fire in the room is burning. What the fireplace's crackle is held on.
##
## Asked of the piece's light, not of "switched on": until 2026-09-20 every switched-on piece
## that was not an open fridge counted as a fire, which was true while the fireplace and the
## fridge were the only two switches. A lamp, a full bath or a record player playing does
## not crackle.
func _fire_lit() -> bool:
	if sheets == null:
		return false
	for row: Dictionary in decor:
		var piece := StringName(row["piece"])
		if sheets.light_of(piece) == &"fire" and sheets.is_on(piece, _row_view(row)):
			return true
	return false


## Take a piece back off the floor and into the store.
func take_back(index: int) -> void:
	if index < 0 or index >= decor.size():
		return
	decor.remove_at(index)
	changed.emit()


## R turns what is in hand, E works the switch the player is standing at.
##
## Not `_gui_input`: that only ever sees a key on the Control that holds focus, and this
## room has never taken focus — it is dragged with the mouse and never typed into, so R
## and E went nowhere at all. Not the input map either, because both are room verbs:
## outside the shed the same keys mean nothing, and a placed fireplace is not something
## the lake can light.
##
## `_unhandled_key_input` runs before the lake's own `_unhandled_input`, which is what puts
## the fireplace ahead of the door: E lights the fire the player is standing at. E anywhere
## else does nothing since 2026-09-29 (Richard): only Escape and the cross leave the room.
func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or record_up():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	# The pad's B on the shelf puts the shelf away, not the room.
	if key.keycode == KEY_ESCAPE and _pad_shelf and Pad.is_pad():
		_pad_shelf = false
		Sfx.ui(&"ui_close")
		get_viewport().set_input_as_handled()
		return
	# Through the input map since 2026-09-16 (issue #26): the bind board moves these two, and
	# they are the shed's own actions rather than the lake's, because the buttons that turn a
	# piece and work a switch in here open the shed and the upgrades out there.
	if event.is_action_pressed(&"shed_rotate"):
		turn_carried()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"shed_switch") and switch_near():
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if record_up():
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		var row_was := _hovered_row() if carrying.is_empty() else -1
		_pointer = motion.position
		if carrying.is_empty() and _hovered_row() >= 0 and _hovered_row() != row_was:
			Sfx.ui(&"ui_hover")
		if not carrying.is_empty():
			queue_redraw()
		return

	var wheel := event as InputEventMouseButton
	if wheel == null:
		return
	if wheel.pressed and wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_scroll_by(ROW_HEIGHT)
		return
	if wheel.pressed and wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
		_scroll_by(-ROW_HEIGHT)
		return
	if wheel.button_index != MOUSE_BUTTON_LEFT:
		return

	_pointer = wheel.position
	# The pad's A picks a piece with one press and puts it down with the next, so the piece
	# can be steered with a stick without holding a button down. The mouse still drags.
	if wheel.device == Pad.SYNTH_DEVICE:
		if wheel.pressed:
			if carrying.is_empty():
				_pick_up()
			else:
				_put_down()
	elif wheel.pressed:
		# A piece still in hand from the shelf goes down on this press.
		if not carrying.is_empty():
			_put_down()
		else:
			_pick_up()
	elif _carried_from == -1 and not carrying.is_empty() and not _over_room(_pointer):
		# Let go of the button over the shelf itself, it stays in hand (2026-09-24, Richard:
		# one click on a row should be enough): the next press puts it down. A drag out
		# onto the floor still drops where it is let go.
		pass
	else:
		_put_down()
	queue_redraw()


## Press: lift whatever is under the cursor, off the floor or out of the list.
func _pick_up() -> void:
	if not carrying.is_empty():
		return
	var on_floor := _placed_at(_pointer)
	if on_floor >= 0:
		var row: Dictionary = decor[on_floor]
		carrying = StringName(row["piece"])
		_carry_view = _row_view(row)
		_carried_from = on_floor
		decor.remove_at(on_floor)
		changed.emit()
		Sfx.ui(&"ui_click")
		return
	var from_list := _listed_at(_pointer)
	if not from_list.is_empty():
		Sfx.ui(&"ui_click")
		carrying = StringName(from_list)
		# Out of the store it comes as drawn: front on, fire out, door shut.
		_carry_view = 0
		_carried_from = -1


## Release: stand it where the cursor is, or put it back in the store. A drop that does not
## fit is not an error — the piece simply goes back on the shelf, and the player tries
## somewhere else.
func _put_down() -> void:
	if carrying.is_empty():
		return
	var piece := carrying
	var view := _carry_view
	carrying = &""
	_carry_view = 0
	_carried_from = -1
	if _over_room(_pointer):
		var sound := Sfx.main()
		if place(piece, _drop_cell(piece, view), view) and sound != null and sheets != null:
			# A tap for the small things and the paintings, a thud for the furniture.
			sound.play_drop(sheets.place_of(piece) != Sheets.Place.FLOOR)
	else:
		# Back to the store, which is where anything not on the floor already is.
		changed.emit()


## The cell a dragged piece would land in: the piece is carried by its middle, which is
## where the cursor holds it, so the corner is half its span up and left of that.
##
## The row is then held to where the piece may go: a painting to the wall, and anything
## else so that its base is on the floor — a bookcase let go with its top over the wall
## slides down until its foot is on the boards, rather than going back on the shelf for
## being an inch too high. The columns are not held: off the side is off the side.
func _drop_cell(piece: StringName, view: int = 0) -> Vector2i:
	var span := span_of(piece, view)
	# Centred on the pointer to the nearest whole pixel (2026-09-27): the floor pixel under
	# the pointer less half the span in integers put the middle up to a pixel off it.
	var floor_at := (_pointer - _floor_origin()) / maxf(_zoom(), 0.001)
	var corner := floor_at - Vector2(span) * 0.5
	var cell := Vector2i(roundi(corner.x), roundi(corner.y))
	# Held rather than refused, on both axes (2026-09-16): a wide piece dragged up against a
	# wall used to be let go over the edge, fail `can_place` and go back to the shelf. It
	# slides along the wall instead, the way one let go too high slides down.
	cell.x = _held(cell.x, 0, PLACE_COLS - span.x)
	if sheets != null and sheets.on_wall(piece):
		cell.y = _held(cell.y, -PLACE_WALL, -span.y)
	else:
		cell.y = _held(
			cell.y, maxi(base_of(piece, view) - span.y, -PLACE_WALL), PLACE_ROWS - span.y
		)
	return cell


## Held between two bounds that may have crossed. `clampi` with a low over its high keeps
## the low, which for a piece too big for the room would put it through the far wall rather
## than against the near one; the near one is the one the hand is aiming at.
static func _held(value: int, low: int, high: int) -> int:
	return clampi(value, mini(low, high), high)


func _scroll_by(amount: float) -> void:
	var rows := in_store().size() + (1 if _wash_shown() else 0)
	var span := float(rows * ROW_HEIGHT) - _list_rect().size.y
	if _wash_shown():
		span += WASH_UNDER_EMPTY if in_store().is_empty() else WASH_UNDER_ROWS
	span = maxf(span, 0.0)
	_scroll = clampf(_scroll + amount, 0.0, span)
	queue_redraw()


## Which placed item is under a point, as an index into `decor`, or -1. Walked backwards so
## the item drawn on top is the one picked up.
func _placed_at(where: Vector2) -> int:
	if sheets == null or not _over_room(where):
		return -1
	# Topmost first, which is the order they are drawn in reverse: what the player can see
	# is what they get hold of, and a rug under a table is not what they are pointing at.
	var cell := spot_at(where)
	var order := _stacking()
	for at_index in range(order.size() - 1, -1, -1):
		var i: int = order[at_index]
		var row: Dictionary = decor[i]
		var at := Vector2i(int(row["cell"][0]), int(row["cell"][1]))
		if Rect2i(at, span_of(StringName(row["piece"]), _row_view(row))).has_point(cell):
			return i
	return -1


## The order things are drawn in, as indices into `decor`.
func _stacking() -> Array:
	var order: Array = []
	for entry: Dictionary in _order():
		if int(entry["index"]) >= 0:
			order.append(int(entry["index"]))
	return order


## Everything in the room in the order it is drawn: what hangs on the wall, then the rugs
## and mats, then everything standing from the back of the room forward, so a chair in
## front of a table overlaps it. Each entry is `{"index", "row", "layer", "key", "seq"}`;
## `extra` is the piece in hand, sorted in with index -1 so the ghost stands where the
## piece will.
##
## Three things fix the order beyond the foot row (2026-09-13, after a chair drawn through
## a desk and the dog behind its own bed):
## - Ties are broken by the order the pieces went down, later on top. `sort_custom` is
##   not stable, so two pieces on one row used to swap from frame to frame.
## - A small piece set over a big one (a pot on a table) is keyed just past its host, the
##   standing piece whose picture its base is in, so it is drawn right after the thing it
##   sits on however high up that picture it was put. With no host it is keyed by its
##   own foot like anything else.
## - The walkers are sorted in by `_walker_key`: by their feet, or just past the piece
##   whose base they are standing in — a dog on the bed is drawn on the bed, not behind
##   it, wherever on the bed it is. That replaces the old rule that only held within 1.2
##   cells of the bed's middle.
func _order(extra: Dictionary = {}) -> Array:
	var rows: Array = decor.duplicate()
	if not extra.is_empty():
		rows.append(extra)
	var entries: Array = []
	for i in rows.size():
		var row: Dictionary = rows[i]
		var piece := StringName(row["piece"])
		var view := _row_view(row)
		var layer := 2
		if sheets.on_wall(piece):
			layer = 0
		elif sheets.lies_flat(piece):
			layer = 1
		# In cells, like the walkers' own keys: the two are sorted against each other.
		var key := float(int(row["cell"][1]) + span_of(piece, view).y) / float(CELL)
		if layer == 2 and sheets.is_small(piece):
			var host := _host_of(rows, i)
			if host >= 0:
				key = _foot_of(rows[host]) + OVER_HOST
		entries.append({
			"index": i if i < decor.size() else -1,
			"row": row,
			"layer": layer,
			"key": key,
			"seq": i,
		})
	entries.sort_custom(_before)
	return entries


static func _before(a: Dictionary, b: Dictionary) -> bool:
	if int(a["layer"]) != int(b["layer"]):
		return int(a["layer"]) < int(b["layer"])
	if not is_equal_approx(float(a["key"]), float(b["key"])):
		return float(a["key"]) < float(b["key"])
	return int(a["seq"]) < int(b["seq"])


## The row a piece's picture ends on, in cells — its foot. In cells although the piece is
## placed in pixels, because this is a sort key and the walkers' keys are cells.
func _foot_of(row: Dictionary) -> float:
	return (
		float(int(row["cell"][1]) + span_of(StringName(row["piece"]), _row_view(row)).y)
		/ float(CELL)
	)


## The standing piece a small one is set over — the one whose picture holds the middle of
## the small piece's base — or -1 for a small piece standing on bare floor. The one
## furthest down the room wins where pictures overlap, since that is the one drawn last.
func _host_of(rows: Array, small: int) -> int:
	var row: Dictionary = rows[small]
	var piece := StringName(row["piece"])
	var span := span_of(piece, _row_view(row))
	var at := Vector2(
		float(int(row["cell"][0])) + float(span.x) * 0.5,
		float(int(row["cell"][1]) + span.y) - float(base_of(piece, _row_view(row))) * 0.5
	)
	var best := -1
	var best_foot := -INF
	for i in rows.size():
		if i == small:
			continue
		var other: Dictionary = rows[i]
		var name := StringName(other["piece"])
		if sheets.is_small(name) or sheets.lies_flat(name) or sheets.on_wall(name):
			continue
		var box := Rect2(
			Vector2(float(int(other["cell"][0])), float(int(other["cell"][1]))),
			Vector2(span_of(name, _row_view(other)))
		)
		if box.has_point(at) and _foot_of(other) > best_foot:
			best_foot = _foot_of(other)
			best = i
	return best


## Where a walker sorts among the furniture: by its feet, unless its feet are inside some
## standing piece's base, in which case just past that piece — it is on it, not behind it.
func _walker_key(feet: Vector2, rows: Array) -> float:
	var key := feet.y
	for row: Dictionary in rows:
		var piece := StringName(row["piece"])
		if sheets.lies_flat(piece) or sheets.on_wall(piece):
			continue
		var view := _row_view(row)
		var span := span_of(piece, view)
		# The feet are in cells and the piece in pixels: one divide, here.
		var foot := float(int(row["cell"][1]) + span.y) / float(CELL)
		var top := foot - float(base_of(piece, view)) / float(CELL)
		var left := float(int(row["cell"][0])) / float(CELL)
		var right := left + float(span.x) / float(CELL)
		# Behind a piece only with the feet past its base's back edge. Anywhere else near
		# it — in front, or standing beside it level with its base — the walker is drawn
		# over it (Richard, 2026-09-29): beside a sofa the angler was drawn under its arm.
		# "Near" is the piece's width plus `BESIDE` either side, the most of a walker's
		# drawing that can reach over it; further off, their feet decide as ever.
		if feet.x >= left - BESIDE and feet.x < right + BESIDE and feet.y >= top:
			key = maxf(key, foot + OVER_PIECE)
	return key


## Which stored piece is under a point, or "" for none.
func _listed_at(where: Vector2) -> String:
	var list := _list_rect()
	if not list.has_point(where):
		return ""
	var index := int((where.y - list.position.y + _scroll) / float(ROW_HEIGHT))
	var store := in_store()
	if index < 0 or index >= store.size():
		return ""
	return store[index]


## What a find is called, or nothing. It used to fall back to the catalogue key, which put
## "furniture_07" in the inventory — worse than no name at all, because it reads as a bug
## rather than as a thing.
func title_of(piece: String) -> String:
	if sheets != null and sheets.titles.has(piece):
		return sheets.title_of(StringName(piece))
	return String(titles.get(piece, ""))


## The floor and the wall above it: everywhere a piece may be let go of.
func _over_room(where: Vector2) -> bool:
	return _shed_rect().has_point(where)


func _floor_origin() -> Vector2:
	return _floor_rect().position


## How big a source pixel is drawn, worked out from the room rather than fixed at three.
##
## Fixed, the floor was 1008x672 whatever it was given, so in a panel narrower than that it
## ran off its own control and under the inventory column, and in a taller one it left the
## room floating. Fitted, the whole grid is always on screen and always clear of the list.
## Kept whole: this is pixel art, and a floorboard drawn at 2.4 pixels a pixel shimmers.
##
## The ceiling is ZOOM_MOST rather than ZOOM now that the room has the screen to itself
## instead of a panel inside it: at three the floor sat in the middle of a lot of nothing.
func _zoom() -> float:
	# The wall and the floor fitted together: the wall is rows of the same cells now, so
	# it is part of what has to fit, and this cannot go through `_room_rect` (which needs
	# the answer to know how much the wall takes).
	var wide := maxf(size.x - float(LIST_WIDTH + GUTTER) - MARGIN * 2.0, 1.0)
	var tall := maxf(size.y - MARGIN * 2.0, 1.0)
	var fit := clampi(mini(int(wide) / (COLS * CELL), int(tall) / ((ROWS + WALL_ROWS) * CELL)), 1, ZOOM_MOST)
	# A step down while the shelf would run under `keep_clear`, the shed's own Upgrades
	# button in the corner (2026-10-06, the Steam Deck pass): at 1280 x 800 the room steps up
	# to three, fills the window, and the button covered the shelf's title and its cross.
	while fit > 1 and _board_under_corner(float(fit)):
		fit -= 1
	return float(fit)


## The screen's corner the room must leave alone, in its own coordinates: the shed's copy of
## the Upgrades button, set by the lake. Empty, nothing is kept clear.
var keep_clear := Rect2()


## Whether the shelf, laid out at `zoom`, reaches under `keep_clear`. The same sums as
## `_floor_rect`, `_shed_rect` and `_board_rect`, which cannot be asked here because they ask
## `_zoom` themselves.
func _board_under_corner(zoom: float) -> bool:
	if not keep_clear.has_area():
		return false
	var step := CELL * zoom
	var span := Vector2(float(COLS) * step, float(ROWS) * step)
	var wall := float(WALL_ROWS * CELL) * zoom
	var room_top := wall + MARGIN
	var room_tall := maxf(size.y - wall - MARGIN * 2.0, 1.0)
	var block := span.x + GUTTER + float(LIST_WIDTH)
	var left := floorf(MARGIN + maxf(size.x - MARGIN * 2.0 - block, 0.0) * 0.5)
	var floor_top := floorf(room_top + (room_tall - span.y) * 0.5)
	var shed_top := maxf(floor_top - wall, 0.0)
	var board_left := left + span.x + GUTTER - SHELF_FRAME
	var board := Rect2(board_left, shed_top,
		minf(float(LIST_WIDTH) + SHELF_FRAME * 2.0, size.x - 2.0 - board_left),
		floor_top + span.y - shed_top)
	return board.intersects(keep_clear)


## How tall the back wall is drawn, in pixels: its rows at the room's zoom.
func _wall_tall() -> float:
	return float(WALL_ROWS * CELL) * _zoom()


## Everything the room may draw into: the control, less the strip along the top the back
## wall stands in, less the inventory column down the right.
##
## The wall used to be drawn at a negative y, above the control's own top edge, where it
## covered the two labels above it in the panel. A Control that draws outside itself cannot
## be laid out beside anything, so the wall is given room here instead.
func _room_rect() -> Rect2:
	var wall := _wall_tall()
	return Rect2(
		Vector2(MARGIN, wall + MARGIN),
		Vector2(
			maxf(size.x - float(LIST_WIDTH + GUTTER) - MARGIN * 2.0, 1.0),
			maxf(size.y - wall - MARGIN * 2.0, 1.0)
		)
	)


## The floor sits against the inventory column rather than in the middle of whatever is left
## over, so a find comes out of the list and goes down a few pixels away instead of being
## carried across an empty room to get there. The two are then centred as one block, so the
## pair is in the middle of the panel even though neither half is.
func _floor_rect() -> Rect2:
	var step := CELL * _zoom()
	var span := Vector2(float(COLS) * step, float(ROWS) * step)
	var room := _room_rect()
	var block := span.x + GUTTER + float(LIST_WIDTH)
	var left := MARGIN + maxf(size.x - MARGIN * 2.0 - block, 0.0) * 0.5
	return Rect2(
		Vector2(left, room.position.y + (room.size.y - span.y) * 0.5).floor(), span
	)


## The inventory column, squared up with the floor beside it rather than with the panel: two
## things at the same height read as one row, and the list no longer starts above the room
## and ends below it.
func _list_rect() -> Rect2:
	var board := _board_rect()
	var face := Style.board_face(board, SHELF_FRAME)
	var rows := Rect2(
		face.position + Vector2(SHELF_PAD, SHELF_PAD),
		face.size - Vector2(SHELF_PAD * 2.0 + SHELF_BAR + SHELF_BAR_GAP, SHELF_PAD * 2.0)
	)
	# The scrollbar's lane is taken whether or not there is anything to scroll, so a row
	# does not change width the moment the shelf fills up.
	return Rect2(rows.position, Vector2(maxf(rows.size.x, 1.0), maxf(rows.size.y, 1.0)))


## The shelf board itself: the column the room leaves free, grown outwards by the frame.
##
## Growing outwards rather than inwards is the whole point — the floor and the room rect are
## sized off `LIST_WIDTH` alone, so the wood costs them nothing. The gutter absorbs the left
## side; the right is clamped to the panel in case the panel is only just wide enough, and
## the rows follow the clamp because `_list_rect` is derived from this.
func _board_rect() -> Rect2:
	var shed := _shed_rect()
	var floor_box := _floor_rect()
	# Top and bottom off the shed, not off the floor: the board and the room it stands
	# beside are two pieces of furniture of the same height, and a board that started
	# below the wallpaper read as a panel bolted on rather than as a thing in the room.
	var left := floor_box.end.x + GUTTER - SHELF_FRAME
	# The title plank straddles the board's top edge and so hangs half its height above it.
	# That half is part of the shelf's outline, so it is what has to land on the shed's top
	# line — the frame starts below it. Squaring the *frame* with the shed instead left the
	# plank sticking up over the room, which is what the misalignment was.
	#
	# **The line to match is the plank's drawn wood, not the ribbon's box** (2026-09-20): the
	# painted plank is `PLANK_TALL` with its foot on the face, so it stands 14 px over the
	# board's top edge where half the box is 18, and the shelf's top sat 4 px under the
	# shed's. `shelf_lift` asks `Style` where the wood really is.
	var top := shed.position.y + shelf_lift()
	var board := Rect2(
		Vector2(left, top),
		Vector2(float(LIST_WIDTH) + SHELF_FRAME * 2.0, shed.end.y - top)
	)
	var over := board.end.x - (size.x - 2.0)
	if over > 0.0:
		board.size.x = maxf(board.size.x - over, SHELF_FRAME * 2.0 + 8.0)
	board.size.y = maxf(board.size.y, SHELF_FRAME * 2.0 + 8.0)
	return board


## How far the shelf's drawn top stands over its board's top edge: the painted plank's own
## reach where it is used, half the ribbon's box where it is not.
func shelf_lift() -> float:
	var probe := Rect2(Vector2.ZERO, Vector2(float(LIST_WIDTH), SHELF_RIBBON))
	if not Style.plank_fits(probe):
		return SHELF_RIBBON * 0.5
	return SHELF_RIBBON * 0.5 - Style.ribbon_plank(probe).position.y


## The block the shed itself draws as: the back wall standing above the floor, down to the
## floor's front edge. `_draw` builds the wall from these same two numbers.
func _shed_rect() -> Rect2:
	var floor_box := _floor_rect()
	var wall_tall := _wall_tall()
	var top := maxf(floor_box.position.y - wall_tall, 0.0)
	return Rect2(
		Vector2(floor_box.position.x, top),
		Vector2(floor_box.size.x, floor_box.end.y - top)
	)


## The title plank, straddling the top edge of the frame and hanging over each end.
func _ribbon_rect() -> Rect2:
	var board := _board_rect()
	return Rect2(
		Vector2(board.position.x - SHELF_OVERHANG, board.position.y - SHELF_RIBBON * 0.5),
		Vector2(board.size.x + SHELF_OVERHANG * 2.0, SHELF_RIBBON)
	)


## Repeats `tex` across `rect`, native size times the room's own zoom, left to right and
## top to bottom. The last tile in each row and column is cut to `rect`'s edge, drawing only
## as much of its source as fits. A Control only clips its own _draw() at its own bounds,
## not at the rect being tiled: whole last tiles used to spill a strip of wallpaper out
## past the wall's right edge and over the frame's corner there.
func _tile_rect(tex: Texture2D, rect: Rect2) -> void:
	var zoom := _zoom()
	var native := tex.get_size()
	var step := native * zoom
	if step.x <= 0.0 or step.y <= 0.0:
		return
	var cols := int(ceil(rect.size.x / step.x))
	var rows := int(ceil(rect.size.y / step.y))
	for row in rows:
		var tall := minf(step.y, rect.size.y - float(row) * step.y)
		for col in cols:
			var wide := minf(step.x, rect.size.x - float(col) * step.x)
			_pen().draw_texture_rect_region(
				tex,
				Rect2(rect.position + Vector2(float(col), float(row)) * step, Vector2(wide, tall)),
				Rect2(Vector2.ZERO, Vector2(wide, tall) / zoom)
			)


## The moulded frame round `frame`'s outer edge: four corners (top ones only when `bottom`
## is false), the horizontal strip tiled across the top run between them, the sill (the
## "down view" piece) across the bottom run (skipped when `bottom` is false), and the
## vertical strip down each side — mirrored for the right, since the source only drew the
## one side.
##
## Called twice with two different rects, back to back in _draw(): once for the back wall
## with `bottom` false, and once for floor_box with `bottom` true — the wall's own bottom
## edge would only sit on top of floor_box's top edge at the seam between them, so only one
## of the two draws it. `top_gap`, when its x is not negative, is a range in the same
## screen-x the top run skips instead of tiling across — for the wall, the door with its
## jambs, so the run stops at the door's corners; for the floor, the opening alone, so
## the frame does not close the way in off with a run of moulding (see _draw_door).
##
## Corners first, then the runs between them, and every run is cut to its own length —
## the runs used to tile in whole strips and overshoot, and the top run and the sill both
## overshot rightwards over the corners drawn before them. The left corners only ever
## looked right because the runs start there.
func _draw_room_frame(frame: Rect2, bottom: bool = true, top_gap: Vector2 = Vector2(-1.0, -1.0)) -> void:
	var tl := BORDER_TOP_LEFT.get_size() * _zoom()
	var tr := BORDER_TOP_RIGHT.get_size() * _zoom()
	var bl := BORDER_BOTTOM_LEFT.get_size() * _zoom() if bottom else Vector2.ZERO
	var br := BORDER_BOTTOM_RIGHT.get_size() * _zoom() if bottom else Vector2.ZERO

	_pen().draw_texture_rect(BORDER_TOP_LEFT, Rect2(frame.position, tl), false)
	_pen().draw_texture_rect(
		BORDER_TOP_RIGHT, Rect2(Vector2(frame.end.x - tr.x, frame.position.y), tr), false
	)
	if bottom:
		_pen().draw_texture_rect(
			BORDER_BOTTOM_LEFT, Rect2(Vector2(frame.position.x, frame.end.y - bl.y), bl), false
		)
		_pen().draw_texture_rect(BORDER_BOTTOM_RIGHT, Rect2(frame.end - br, br), false)
		# Bottom run: the sill, corner to corner.
		_tile_run(
			BORDER_SILL,
			Vector2(frame.position.x + bl.x, frame.end.y - BORDER_SILL.get_height() * _zoom()),
			frame.size.x - bl.x - br.x,
			true
		)

	# Top run: horizontal strip, corner to corner — split round the door's gap when one
	# is given, rather than tiled straight across it.
	var top_from := frame.position.x + tl.x
	var top_to := frame.end.x - tr.x
	if top_gap.x >= 0.0:
		_tile_run(BORDER_HORIZONTAL, Vector2(top_from, frame.position.y), top_gap.x - top_from, true)
		_tile_run(BORDER_HORIZONTAL, Vector2(top_gap.y, frame.position.y), top_to - top_gap.y, true)
	else:
		_tile_run(BORDER_HORIZONTAL, Vector2(top_from, frame.position.y), top_to - top_from, true)

	# Side runs: the one vertical strip, corner to corner down the left, and flipped for
	# the right — the source only holds one side, mirrored the same way a find's art is.
	_tile_run(
		BORDER_VERTICAL,
		Vector2(frame.position.x, frame.position.y + tl.y),
		frame.size.y - tl.y - bl.y,
		false
	)
	_tile_run(
		BORDER_VERTICAL,
		Vector2(frame.end.x - BORDER_VERTICAL.get_width() * _zoom(), frame.position.y + tr.y),
		frame.size.y - tr.y - br.y,
		false,
		true
	)


## One run of a border strip between two corners, tiled along its length and cut to it:
## the last strip draws only as much of its source as is left of `length`. `along_x` picks
## whether the run travels horizontally or down the side, and `flip` mirrors a vertical
## strip for the side the source art was not drawn for.
##
## `at` is the run's top-left whichever way it faces. A flipped strip is a rect with a
## negative width at that same position: the canvas flips the strip in place and does not
## move it, so shifting the rect over by its own width first (as this once did) put the
## whole right-hand run one strip outside the frame.
func _tile_run(tex: Texture2D, at: Vector2, length: float, along_x: bool, flip: bool = false) -> void:
	if length <= 0.0:
		return
	var zoom := _zoom()
	var native := tex.get_size()
	var size := native * zoom
	var step := size.x if along_x else size.y
	if step <= 0.0:
		return
	var count := int(ceil(length / step))
	for i in count:
		var offset := float(i) * step
		var keep := minf(step, length - offset)
		var pos := at + (Vector2(offset, 0.0) if along_x else Vector2(0.0, offset))
		var draw_size := Vector2(keep, size.y) if along_x else Vector2(size.x, keep)
		var src := Rect2(Vector2.ZERO, draw_size / zoom)
		if flip:
			draw_size.x = -draw_size.x
		_pen().draw_texture_rect_region(tex, Rect2(pos, draw_size), src)


## The room behind everything in it: the scrim over the lake, the back wall with its door,
## the floor and the moulding round it. Drawn by `_floor_layer`, a child behind the room's own
## `_draw`, rather than by `_draw` itself (2026-10-02, one sun): the shadows (`_shades`) have
## to lie on the floor and under every piece and walker, and a node's own drawing cannot be
## split round a child. `pen` is the layer; `_pen` hands it to the helpers that tile.
func _paint_room(pen: CanvasItem) -> void:
	if sheets == null:
		return
	_pen_on = pen
	pen.draw_rect(Rect2(-global_position, get_viewport_rect().size), ROOM_SCRIM)
	var floor_box := _floor_rect()

	# The room: a back wall standing above the floor, so the space has a direction and the
	# furniture has something to be against. Wallpapered, not flat.
	var wall_tall := _wall_tall()
	var wall := Rect2(
		Vector2(floor_box.position.x, maxf(floor_box.position.y - wall_tall, 0.0)),
		Vector2(floor_box.size.x, minf(wall_tall, floor_box.position.y))
	)
	pen.draw_rect(wall, Color(0.30, 0.26, 0.24))
	_tile_rect(WALLPAPER_TILE, wall)
	_draw_door(wall)

	# The floor: the new tile, laid both ways across the whole box. Backed by a flat fill
	# first so a box whose size does not divide evenly never shows a gap at the far edge —
	# the last row and column are cut to it.
	pen.draw_rect(floor_box, Color(0.47, 0.36, 0.26))
	_tile_rect(FLOOR_TILE, floor_box)

	# The room's walls carry on down the floor's own sides and along its front edge, the
	# same moulding as the back wall's — a second frame, floor_box's own, meeting the first
	# at the seam where wall ends and floor begins rather than replacing it. Its top run is
	# gapped to the door, jambs and all: nothing runs under the way in, and the run's two
	# ends take corner pieces under the jambs (see _draw_threshold).
	var opening := _door_opening(wall)
	var jamb_wide := BORDER_VERTICAL.get_width() * _zoom()
	_draw_room_frame(
		floor_box, true, Vector2(opening.position.x - jamb_wide, opening.end.x + jamb_wide)
	)
	_draw_threshold(opening, floor_box)
	_pen_on = null


## What the room's floor helpers draw on: the floor layer while it paints, the room otherwise.
func _pen() -> CanvasItem:
	return _pen_on if _pen_on != null else self


func _draw() -> void:
	if sheets == null:
		return
	_place_close()
	var floor_box := _floor_rect()
	# The scrim, the wall and the floor are drawn by `_floor_layer`, behind this, and the
	# room's shadows by `_shades` over them (see `_paint_room`).
	_dress_shades(floor_box)

	# The faint cell grid under a carried piece is gone (2026-09-16): it was drawn to show
	# what the drop was snapping to, and the drop snaps to whole art pixels now — a grid of
	# those is the floorboards themselves. Drawing the old eight-pixel lines would say the
	# piece lands somewhere it does not.

	_dress_light(floor_box)

	# Where the piece in hand would land, tinted by whether it may. On the boards under the
	# furniture; the piece itself is drawn in its place among them below.
	var landing := _ghost()
	if not landing.is_empty():
		var cell := Vector2i(int(landing["cell"][0]), int(landing["cell"][1]))
		var fits := can_place(carrying, cell, _carry_view)
		var at := floor_box.position + Vector2(
			float(cell.x) * _zoom(), float(cell.y) * _zoom()
		)
		draw_rect(
			Rect2(at, Vector2(span_of(carrying, _carry_view)) * _zoom()),
			Color(Style.SAFE.r, Style.SAFE.g, Style.SAFE.b, 0.20) if fits
			else Color(Style.DANGER.r, Style.DANGER.g, Style.DANGER.b, 0.20)
		)

	# What is in the room, laid down before it is stood on, with the dog and the player
	# sorted in among it rather than over the lot: each is drawn the moment the room reaches
	# something standing further down the floor than they are (see `_walker_key`), so they
	# pass behind a wardrobe and in front of a chair instead of sliding over both. The piece
	# in hand goes in the same order, as a ghost, so what the player sees is what lands.
	var ghost := _ghost()
	var rows: Array = decor.duplicate()
	if not ghost.is_empty():
		rows.append(ghost)
	# The walkers, in the order they sort among the furniture: every dog, then the player at
	# the same key, which keeps the person in front of an animal standing level with them.
	# A dog lying on the sofa or the bed the player is sitting or lying on is drawn just after
	# them, over their lap (2026-10-03, Richard): at the same key it fell under them.
	var walkers: Array = []
	var you_key := _you_key(rows) if _you_sheet != null else 0.0
	var sharing := not _rest_key.is_empty() and _rest_kind != &"read"
	for dog in _dogs:
		var key := _walker_key(dog.at, rows)
		if sharing and dog.seat == _rest_key:
			key = you_key + SHARED_OVER
		walkers.append({"key": key, "dog": dog})
	if _you_sheet != null:
		walkers.append({"key": you_key, "dog": null})
	walkers.sort_custom(func(a, b): return float(a["key"]) < float(b["key"]))
	var next_walker := 0
	for entry: Dictionary in _order(ghost):
		if int(entry["layer"]) == 2:
			while (
				next_walker < walkers.size()
				and float(entry["key"]) > float(walkers[next_walker]["key"])
			):
				_draw_walker(floor_box, walkers[next_walker])
				next_walker += 1
		var row: Dictionary = entry["row"]
		_stamp_piece(
			StringName(row["piece"]),
			floor_box.position + Vector2(
				float(int(row["cell"][0])) * _zoom(),
				float(int(row["cell"][1])) * _zoom()
			),
			_row_view(row),
			Color(1.0, 1.0, 1.0, float(row.get("ghost", 1.0)))
		)
	while next_walker < walkers.size():
		_draw_walker(floor_box, walkers[next_walker])
		next_walker += 1

	# The shade the window's light is lifted out of. Over the room and everything standing
	# in it, under the light quad, which is a child and so drawn after all of this.
	draw_rect(_shed_rect(), ROOM_DIM)
	_draw_hands(floor_box)
	_draw_prompt(floor_box)
	_dress_shelf()

	# The piece in hand off the room — over the shelf, say — follows the cursor over
	# everything. Over the room it was drawn in its place among the furniture above.
	if not carrying.is_empty() and not _over_room(_pointer):
		_stamp_piece(
			carrying,
			_pointer - sheets.view_size_of(carrying, _carry_view) * _zoom() * 0.5,
			_carry_view,
			Color(1.0, 1.0, 1.0, 0.75)
		)
	_draw_turn_hint(floor_box)


## The piece in hand as a row of `decor` would hold it, where it would land, or nothing
## when there is none or the cursor is off the room. Carries its own alpha under "ghost":
## faint when the drop will be refused.
func _ghost() -> Dictionary:
	if carrying.is_empty() or not _over_room(_pointer):
		return {}
	var cell := _drop_cell(carrying, _carry_view)
	return {
		"piece": String(carrying),
		"cell": [cell.x, cell.y],
		"view": _carry_view,
		"ghost": 0.85 if can_place(carrying, cell, _carry_view) else 0.5,
	}


## Hand the shelf what it should paint.
##
## Measured here, in the room, so the rows the player sees are the rows `_listed_at` tests
## against — one measurement, used twice, instead of two that can drift apart.
func _dress_shelf() -> void:
	if _shelf == null:
		return
	var store := in_store()
	# Faded back while something is being carried, so the floor under it can be seen and
	# aimed at. It is still there to drop onto; it is just no longer in front.
	_shelf.modulate.a = LIST_BUSY if not carrying.is_empty() else 1.0
	_shelf.board = _board_rect()
	_shelf.ribbon = _ribbon_rect()
	_shelf.title_box = _title_box()
	_shelf.list = _list_rect()
	_shelf.title = Text.SHELF_TITLE if store.is_empty() else Text.SHELF_TITLE_N % store.size()
	_shelf.atlas = sheets.atlas
	_shelf.scroll = _scroll
	_shelf.hovered = -1 if not carrying.is_empty() else _hovered_row()
	# On the pad, the shoulder that opens the shelf, at the left end of its title plank: the
	# shelf is not reached by walking, so something has to say how it is reached. Drawn by
	# the shelf, over its own plank: drawn by the room it was under the shelf, a child, and
	# had never been seen (issue #33 audit).
	_shelf.key = Binds.shown(&"zoom_in", true) if Pad.is_pad() and not _pad_shelf and carrying.is_empty() else ""
	var rows: Array[Dictionary] = []
	for piece in store:
		rows.append({
			"region": sheets.alt_region_of(StringName(piece)),
			"title": title_of(piece),
		})
	_shelf.rows = rows
	_shelf.queue_redraw()
	_dress_wash_plank(store.size())


## The wash plank: the row after the last find, in the list's own column and scroll, shown
## only while something waits at the pump and only when its whole box is on the shelf (the
## rows' own rule — a plank half off the face is a plank in mid-air). With no finds it is
## the first row, standing under "Nothing kept yet.".
func _dress_wash_plank(rows: int) -> void:
	if _wash_plank == null:
		return
	if not _wash_shown():
		_wash_plank.visible = false
		return
	var list := _list_rect()
	var top := list.position.y + float(rows) * float(ROW_HEIGHT) - _scroll
	top += WASH_UNDER_EMPTY if rows == 0 else WASH_UNDER_ROWS
	var box := Rect2(list.position.x, top, list.size.x, float(ROW_HEIGHT) - SHELF_ROW_GAP)
	_wash_plank.visible = box.position.y >= list.position.y - 0.5 and box.end.y <= list.end.y + 0.5
	_wash_plank.position = box.position
	_wash_plank.size = box.size
	_wash_plank.label = WASH_LABEL % unwashed.size()
	_wash_plank.modulate.a = _shelf.modulate.a if _shelf != null else 1.0
	_wash_plank.pulse = wash_pulse_amount()


## Whether the wash plank has anything to point at.
func _wash_shown() -> bool:
	return not unwashed.is_empty()


## The plank's box on the room, or an empty rect while it is not shown. The harness asks.
func wash_plank_box() -> Rect2:
	if _wash_plank == null or not _wash_plank.visible:
		return Rect2()
	return Rect2(_wash_plank.position, _wash_plank.size)


## The lake says the shed has just come up. More waiting at the pump than the last time
## starts the plank's pulse; the same or fewer does not.
func opened() -> void:
	_pad_shelf = false
	if unwashed.size() > _wash_seen:
		_wash_pulse = 1.0
		_wash_clock = 0.0
		_wash_unseen = true
	_wash_seen = unwashed.size()


## The wash plank's pulse as drawn, the HUD's own shape: a slow wave under a fading envelope.
func wash_pulse_amount() -> float:
	if _wash_pulse <= 0.0:
		return 0.0
	var wave := 0.5 - 0.5 * cos(_wash_clock * TAU * WASH_PULSE_BEATS / WASH_PULSE_TIME)
	return wave * _wash_pulse


## Which shelf row the pointer is over, or -1. The same arithmetic `_listed_at` picks with,
## so the row that lights up is the row that gets picked up.
func _hovered_row() -> int:
	var list := _list_rect()
	if not list.has_point(_pointer):
		return -1
	var index := int((_pointer.y - list.position.y + _scroll) / float(ROW_HEIGHT))
	return index if index >= 0 and index < in_store().size() else -1


## How far through the lit day the sun is, 0 early to 1 late.
func sun_share() -> float:
	var hour := day.sun if day != null else SUN_NO_DAY
	return clampf((hour - SUN_HOURS.x) / (SUN_HOURS.y - SUN_HOURS.x), 0.0, 1.0)


## The lit pieces as rows of {at, reach, power, tone}, `at` on the floor in canvas pixels.
## The harness asks this too, so what is checked is what is lit.
func lamps(floor_box: Rect2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if sheets == null:
		return out
	for row: Dictionary in decor:
		var piece := StringName(row["piece"])
		var light := sheets.light_of(piece)
		if light == &"" or not sheets.is_on(piece, _row_view(row)):
			continue
		var span := span_of(piece, _row_view(row))
		out.append({
			"at": floor_box.position + Vector2(
				(float(int(row["cell"][0])) + float(span.x) * 0.5) * _zoom(),
				(float(int(row["cell"][1])) + float(span.y)) * _zoom()
			),
			"reach": _pool(light).x * CELL * _zoom(),
			"power": _pool(light).y,
			"tone": _pool_tone(light),
		})
		if out.size() >= LAMPS_MOST:
			break
	return out


## Lays the light quad over the shed and tells it where the window and the lit pieces are.
## Over the furniture and the walkers: light falls on a sofa as it does on the boards.
func _dress_light(floor_box: Rect2) -> void:
	if _light == null:
		return
	var shed := _shed_rect()
	_light.position = shed.position
	_light.size = shed.size
	var lit := _light.material as ShaderMaterial
	var cell := CELL * _zoom()
	var share := sun_share()
	var tone := SUN_EARLY.lerp(SUN_LATE, share)
	if day != null:
		tone = tone * day.tint
	lit.set_shader_parameter(&"box_px", shed.size)
	lit.set_shader_parameter(&"art_px", _zoom())
	lit.set_shader_parameter(&"window_at", _window_at() - shed.position)
	# No light on the room's own planks (2026-10-08, Richard: the window's glow sat on top of
	# the left wall, "it should come from below the roof"): only inside the moulding.
	var zoom := _zoom()
	var side := BORDER_VERTICAL.get_width() * zoom
	lit.set_shader_parameter(&"inside", Vector4(
		side, BORDER_HORIZONTAL.get_height() * zoom,
		shed.size.x - side, shed.size.y - BORDER_SILL.get_height() * zoom
	))
	lit.set_shader_parameter(&"sun_dir", CONE_AXIS)
	# A shower outside (2026-09-25, `Weather`): the shaft through the window thins to a grey
	# glow, and a flash of lightning throws it in white for a moment.
	var power := lerpf(SUN_POWER.x, SUN_POWER.y, share) * lerpf(1.0, RAIN_SUN, Weather.now)
	power += Weather.flash_now * FLASH_SUN
	tone = tone.lerp(Color(0.85, 0.9, 1.0), Weather.flash_now)
	lit.set_shader_parameter(&"sun_power", power)
	lit.set_shader_parameter(&"sun_tone", Vector3(tone.r, tone.g, tone.b))
	lit.set_shader_parameter(&"shaft_wide", SHAFT_WIDE * cell)
	lit.set_shader_parameter(&"shaft_spread", SHAFT_SPREAD)
	lit.set_shader_parameter(&"shaft_long", SHAFT_LONG * cell)
	var rows := lamps(floor_box)
	var spots := PackedVector4Array()
	var tones := PackedVector3Array()
	for k in LAMPS_MOST:
		if k < rows.size():
			var at: Vector2 = rows[k]["at"] - shed.position
			var glow: Color = rows[k]["tone"]
			spots.append(Vector4(at.x, at.y, float(rows[k]["reach"]), float(rows[k]["power"])))
			tones.append(Vector3(glow.r, glow.g, glow.b))
		else:
			spots.append(Vector4.ZERO)
			tones.append(Vector3.ZERO)
	lit.set_shader_parameter(&"lamp_count", rows.size())
	lit.set_shader_parameter(&"lamps", spots)
	lit.set_shader_parameter(&"lamp_tones", tones)


## The floor layer and the shadow group, both behind the room's own drawing and first among
## the children, the floor first: children shown behind their parent draw in tree order.
func _build_shade_layers() -> void:
	_floor_layer = Node2D.new()
	_floor_layer.name = &"Floor"
	_floor_layer.show_behind_parent = true
	_floor_layer.draw.connect(func() -> void: _paint_room(_floor_layer))
	add_child(_floor_layer)
	move_child(_floor_layer, 0)
	_shades = CanvasGroup.new()
	_shades.name = &"Shades"
	_shades.show_behind_parent = true
	# Darker by the window (`SHADE_FALL_CODE`): the group's own pass, over what it composited.
	var fall := ShaderMaterial.new()
	var fall_code := Shader.new()
	fall_code.code = SHADE_FALL_CODE
	fall.shader = fall_code
	_shades.material = fall
	_furniture_shade = Shade.Face.new()
	_shades.add_child(_furniture_shade)
	_ghost_shade = Shade.Face.new()
	_shades.add_child(_ghost_shade)
	_walker_shades = Node2D.new()
	var white := ShaderMaterial.new()
	var code := Shader.new()
	code.code = SILHOUETTE_CODE
	white.shader = code
	_walker_shades.material = white
	_walker_shades.draw.connect(func() -> void: _paint_walker_shades(_walker_shades))
	_shades.add_child(_walker_shades)
	add_child(_shades)
	move_child(_shades, 1)


## Where the light comes in, in the room's own space: the round window half way down the
## floor's left edge, the point the shaft is drawn from (`window_at` in `_dress_light`).
## On the inner edge of the left wall's plank, not its outer edge (2026-10-08): the light
## comes in under the roof, so nothing of its source shows on the wall's top.
func _window_at() -> Vector2:
	var floor_box := _floor_rect()
	return Vector2(
		floor_box.position.x + BORDER_VERTICAL.get_width() * _zoom(), floor_box.get_center().y
	)


## The way a shadow falls from a caster standing at `feet` (room space): straight away from
## the window, up the room above it and down the room below it.
func _room_away(feet: Vector2) -> Vector2:
	var away := feet - _window_at()
	if away.length_squared() < 0.0001:
		return CONE_AXIS
	return away.normalized()


## A walker's frame laid down along the room's light from `feet`: `Shade.lying`'s mapping, but
## with the stretch free to be negative, so a shadow can fall up the room.
static func _lay(feet: Vector2, light: Vector2) -> Transform2D:
	return Transform2D(Vector2(1.0, 0.0), Vector2(-light.x, -light.y * 0.5), feet)


## How long a shadow is per unit of its caster's height, standing at `feet`: as far from the
## window as the window is high is a shadow as long as the caster, the hour lengthening it.
func _room_reach(feet: Vector2) -> float:
	var cell := float(CELL * _zoom())
	var out := feet.distance_to(_window_at()) / maxf(WINDOW_HIGH * cell, 1.0)
	out *= lerpf(HOUR_REACH.x, HOUR_REACH.y, sun_share())
	return clampf(out, REACH_LEAST, REACH_MOST)


## The room's light at `feet` as `Shade.lying` takes it: (lean, stretch), the lean positive
## to fall right and the stretch twice the drop down the screen, `lying` halving it.
func _room_light(feet: Vector2) -> Vector2:
	var away := _room_away(feet) * _room_reach(feet)
	return Vector2(away.x, away.y * 2.0)


## The ink of a shadow in the room: the land's, from the day.
func _room_ink() -> float:
	var sun := Shade.sun_of(day)
	return Shade.ink_on(Shade.NO_DAY_INK if sun == null else sun.ink, Shade.On.LAND)


## Brings the room's shadows up to date for this frame: the group's ink, the furniture's
## sweep when the layout, the room's size or the light has moved by `Shade.SWEEP_STEP`, the
## piece in hand's, and a redraw of the floor and the walkers, who move every frame.
func _dress_shades(floor_box: Rect2) -> void:
	if _shades == null:
		return
	_floor_layer.queue_redraw()
	_walker_shades.queue_redraw()
	_shades.self_modulate = Shade.tint(_room_ink())
	var fall := _shades.material as ShaderMaterial
	if fall != null:
		var cell := float(CELL * _zoom())
		fall.set_shader_parameter(&"window_at", _window_at())
		fall.set_shader_parameter(&"near_dark", NEAR_DARK)
		fall.set_shader_parameter(&"far_dark", FAR_DARK)
		fall.set_shader_parameter(&"dark_reach", DARK_REACH * cell)
		fall.set_shader_parameter(&"dark_steps", DARK_STEPS)
		fall.set_shader_parameter(&"art_px", float(_zoom()))
		fall.set_shader_parameter(&"sun_dir", CONE_AXIS)
		fall.set_shader_parameter(&"shaft_wide", SHAFT_WIDE * cell)
		fall.set_shader_parameter(&"shaft_spread", SHAFT_SPREAD)
		fall.set_shader_parameter(&"outside_dark", OUTSIDE_DARK)
	# Each piece's light is its own (the window is a point), so the key is the hour's step:
	# where every piece stands is already in the layout's hash.
	var hour := snappedf(sun_share(), Shade.SWEEP_STEP)
	var key := "%d|%s|%.2f" % [decor.hash(), floor_box, hour]
	if key != _furniture_shade_for:
		_furniture_shade_for = key
		var points := PackedVector2Array()
		for i in decor.size():
			_sweep_row_into(points, decor, i, floor_box.position, floor_box.position)
		_furniture_shade.points = points
		_furniture_shade.queue_redraw()
	# The piece in hand: swept at its own corner and moved, since it moves every frame; swept
	# again when where it stands has moved its light by a step.
	var ghost := _ghost()
	var ghost_key := ""
	var ghost_at := Vector2.ZERO
	if not ghost.is_empty():
		ghost_at = floor_box.position + Vector2(
			float(int(ghost["cell"][0])), float(int(ghost["cell"][1]))
		) * _zoom()
		var light := _room_light(ghost_at).snapped(Vector2.ONE * Shade.SWEEP_STEP)
		ghost_key = "%s|%d|%.2f|%.2f|%.3f" % [
			ghost["piece"], _row_view(ghost), light.x, light.y, _zoom()
		]
	if ghost_key != _ghost_shade_for:
		_ghost_shade_for = ghost_key
		var points := PackedVector2Array()
		if not ghost.is_empty():
			var rows: Array = decor.duplicate()
			rows.append(ghost)
			var corner := Vector2(float(int(ghost["cell"][0])), float(int(ghost["cell"][1])))
			_sweep_row_into(points, rows, rows.size() - 1, -corner * _zoom(), ghost_at - corner * _zoom())
		_ghost_shade.points = points
		_ghost_shade.queue_redraw()
	_ghost_shade.visible = not ghost.is_empty()
	if not ghost.is_empty():
		_ghost_shade.position = floor_box.position + Vector2(
			float(int(ghost["cell"][0])), float(int(ghost["cell"][1]))
		) * _zoom()


## One row of `rows`, swept along the room's light into `into`, its cell measured from
## `origin`. Only what stands on the floor casts: nothing hung on the wall, nothing lying flat,
## and nothing small set on a host (a pot on a table is on the table, and the table casts).
## `room_origin` is where `origin` is in the room's own space, so the light can be asked at
## the piece's foot when it is swept somewhere else (the piece in hand).
func _sweep_row_into(
	into: PackedVector2Array, rows: Array, index: int, origin: Vector2, room_origin: Vector2
) -> void:
	var row: Dictionary = rows[index]
	var piece := StringName(row["piece"])
	if sheets.on_wall(piece) or sheets.lies_flat(piece):
		return
	if sheets.is_small(piece) and _host_of(rows, index) >= 0:
		return
	var view := _row_view(row)
	var runs := _runs_of(piece, view)
	if runs.is_empty():
		return
	var art: Vector2 = runs["size"]
	var zoom := _zoom()
	var box := Rect2(
		origin + Vector2(float(int(row["cell"][0])), float(int(row["cell"][1]))) * zoom,
		sheets.view_size_of(piece, view) * zoom
	)
	var step := box.size / art
	var rise := box.size.y * (1.0 - float(runs["ground"]))
	# The light at the middle of the piece's foot, in the room's own space.
	var foot := box.position - origin + room_origin + Vector2(box.size.x * 0.5, box.size.y)
	var light := _room_light(foot)
	var drag := Vector2(light.x, light.y * 0.5) * rise
	if drag.is_zero_approx():
		return
	for run: Vector3 in runs["runs"]:
		_smear_into(
			into,
			Rect2(
				box.position + Vector2(run.x * step.x, run.y * step.y),
				Vector2(step.x, run.z * step.y)
			),
			drag
		)


## The opaque runs of one view that cast, in its art's own pixels as (column, top row,
## length): `Shade.sweep`'s rule — per column and per run, and only the columns whose lowest
## pixel is within the piece's base of the deepest row, an overhang casting nothing — worked
## out once per view and kept. `ground` is the base's share of the picture: depth, not height,
## so only the rest of the picture drags the shadow. Sweeping the pixels afresh whenever the
## light stepped would read every piece's every pixel twice; the runs make a step cheap.
func _runs_of(piece: StringName, view: int) -> Dictionary:
	var key := "%s|%d" % [piece, view]
	if _shade_runs.has(key):
		return _shade_runs[key]
	var out := {}
	if _atlas_image == null and sheets.atlas != null:
		_atlas_image = sheets.atlas.get_image()
	var region := Rect2i(sheets.view_region_of(piece, view))
	if _atlas_image == null or region.size.x <= 0 or region.size.y <= 0:
		_shade_runs[key] = out
		return out
	var art := _atlas_image.get_region(region)
	var wide := art.get_width()
	var tall := art.get_height()
	var ground := clampf(
		float(base_of(piece, view)) / float(maxi(span_of(piece, view).y, 1)), 0.0, 1.0
	)
	var foot := PackedInt32Array()
	foot.resize(wide)
	var deepest := -1
	for col in wide:
		foot[col] = -1
		for row in range(tall - 1, -1, -1):
			if art.get_pixel(col, row).a > 0.5:
				foot[col] = row
				deepest = maxi(deepest, row)
				break
	var runs: Array[Vector3] = []
	var band := maxf(float(tall) * ground, 1.0)
	if deepest >= 0:
		for col in wide:
			if foot[col] < 0 or float(deepest - foot[col]) > band:
				continue
			var top := -1
			for row in tall + 1:
				var solid := row < tall and art.get_pixel(col, row).a > 0.5
				if solid and top < 0:
					top = row
				elif not solid and top >= 0:
					runs.append(Vector3(col, top, row - top))
					top = -1
	out = {"size": Vector2(wide, tall), "ground": ground, "runs": runs}
	_shade_runs[key] = out
	return out


## One run swept: the hull of its corners and the same four moved along the drag, fanned.
## `Shade._smear`'s own, kept here so the room does not lean on another file's private.
static func _smear_into(into: PackedVector2Array, cell: Rect2, drag: Vector2) -> void:
	var both := PackedVector2Array([
		cell.position,
		cell.position + Vector2(cell.size.x, 0.0),
		cell.end,
		cell.position + Vector2(0.0, cell.size.y),
	])
	for k in 4:
		both.append(both[k] + drag)
	var hull := Geometry2D.convex_hull(both)
	if hull.size() > 1 and hull[0].is_equal_approx(hull[hull.size() - 1]):
		hull.remove_at(hull.size() - 1)
	for i in range(1, hull.size() - 1):
		into.append(hull[0])
		into.append(hull[i])
		into.append(hull[i + 1])


## The walkers' shadows, onto `pen` (the white silhouette layer in `_shades`): each one's own
## frame laid along the room's light from its feet, as the lake lays the angler's and the
## dogs'. A dog on its seat casts none here, being on the furniture rather than the floor,
## and nor does the player sitting or lying, whose shade is pressed into the cushion
## (`_draw_resting`). Reading, they stand, and cast.
func _paint_walker_shades(pen: CanvasItem) -> void:
	if sheets == null:
		return
	var floor_box := _floor_rect()
	var step := float(CELL * _zoom())
	for dog in _dogs:
		if not dog.seat.is_empty() and dog.at.distance_to(_seat_point(dog.seat)) < 0.3:
			continue
		var feet := floor_box.position + dog.at * step
		var light := _room_light(feet)
		pen.draw_set_transform_matrix(_lay(feet, light))
		DogArt.stamp(
			pen, dog.state, DogArt.frame_at(dog.state, dog.age, dog.breed), Vector2.ZERO,
			DOG_TALL * step, dog.left, 0.0, Color.WHITE, dog.breed
		)
	pen.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not _rest_key.is_empty() and _rest_kind != &"read":
		return
	var shown := _you_shown(floor_box)
	if shown.is_empty():
		return
	var at: Vector2 = shown["at"]
	var box: Rect2 = shown["box"]
	var you := _room_light(at)
	pen.draw_set_transform_matrix(_lay(at, you))
	pen.draw_texture_rect_region(
		_you_sheet, Rect2(box.position - at, box.size), shown["region"] as Rect2
	)
	pen.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A light's pool as (reach in cells, power).
func _pool(light: StringName) -> Vector2:
	match light:
		&"cold":
			return Vector2(FRIDGE_REACH, FRIDGE_POWER)
		&"warm":
			return Vector2(LAMP_REACH, LAMP_POWER)
		&"ember":
			return Vector2(EMBER_REACH, EMBER_POWER)
	return Vector2(FIRE_REACH, FIRE_POWER)


func _pool_tone(light: StringName) -> Color:
	match light:
		&"cold":
			return FRIDGE_TONE
		&"warm":
			return LAMP_TONE
		&"ember":
			return EMBER_TONE
	return FIRE_TONE


## The nudge over a switch the player is standing at. Nothing at all when they are not.
##
## The fireplace and the fridge are the only two things in the game worked by standing
## rather than clicking, so there is no chance of learning the verb anywhere else: without
## this the player walks past a fireplace they own and never finds out it lights.


## The pointing hand over every switch of a kind never worked (2026-10-02): drawn over the
## room's dim, like the key chip, so a piece further down the floor never hides it. At the
## furniture's grain (`HAND_GRAIN`), its fingertip `HAND_LIFT` over the top of the piece's
## drawing, on a four-frame loop: a pixel's bob and the star winking.
func _draw_hands(floor_box: Rect2) -> void:
	var rows := hand_rows()
	if rows.is_empty():
		return
	if _hand_frames.is_empty():
		for f in HAND_BOBS.size():
			_hand_frames.append(ImageTexture.create_from_image(_hand_image(f)))
	var frame := hand_frame(float(Time.get_ticks_msec()) * 0.001)
	var room_px := _zoom()
	var px := room_px * HAND_GRAIN
	var picture: ImageTexture = _hand_frames[frame]
	for i in rows:
		var row: Dictionary = decor[i]
		var piece := StringName(row["piece"])
		var view := _row_view(row)
		var top := floor_box.position + Vector2(
			float(int(row["cell"][0])) * room_px, float(int(row["cell"][1])) * room_px
		)
		var across := sheets.view_size_of(piece, view).x * room_px
		var tip := Vector2(top.x + across * 0.5, top.y - HAND_LIFT * px)
		# The picture's corner is the silhouette's pixel `_hand_origin`; the tip is HAND_TIP.
		var corner := tip - (HAND_TIP - Vector2(_hand_origin) + Vector2(0.0, float(HAND_BOBS[frame]))) * px
		draw_texture_rect(
			picture,
			Rect2(corner.round(), Vector2(picture.get_size()) * px), false
		)


## Which of the hand's four frames is up at `time` seconds.
static func hand_frame(time: float) -> int:
	var total := 0.0
	for hold: float in HAND_HOLDS:
		total += hold
	var at := fposmod(time, total)
	for f in HAND_HOLDS.size():
		at -= float(HAND_HOLDS[f])
		if at < 0.0:
			return f
	return HAND_HOLDS.size() - 1


## The hand's pixels on one frame, as silhouette pixel -> colour, shadow not included.
static func hand_pixels(frame: int) -> Dictionary:
	var fill := {}
	for y in HAND.size():
		var line: String = HAND[y]
		for x in line.length():
			if line[x] == "#":
				fill[Vector2i(x, y)] = true
	var px := {}
	for p: Vector2i in fill:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var n := p + Vector2i(dx, dy)
				if not fill.has(n):
					px[n] = HAND_INK
	for p: Vector2i in fill:
		var tones: Dictionary = HAND_SHIRT if p.y < HAND_CUFF else HAND_SKIN
		px[p] = tones[_hand_tone(fill, p)]
	# The cuff's foot, where it meets the hand.
	for x in range(4, 13):
		if fill.has(Vector2i(x, HAND_CUFF - 1)):
			px[Vector2i(x, HAND_CUFF - 1)] = HAND_SHIRT[&"low"]
	# The shirt's cuff turned back.
	for x in range(4, 12):
		px[Vector2i(x, 1)] = HAND_SHIRT[&"lit"]
	# The curled fingers part from each other and from the index finger, their knuckles lit.
	for p: Vector2i in [Vector2i(7, 10), Vector2i(7, 9), Vector2i(10, 10), Vector2i(13, 10)]:
		px[p] = HAND_SKIN[&"line"]
	for p: Vector2i in [Vector2i(9, 11), Vector2i(12, 11)]:
		px[p] = HAND_SKIN[&"lit"]
	# The thumb's crease, the finger's joint and its nail.
	for p: Vector2i in [Vector2i(2, 6), Vector2i(2, 7), Vector2i(3, 8)]:
		px[p] = HAND_SKIN[&"line"]
	for x in [3, 4]:
		px[Vector2i(x, 14)] = HAND_SKIN[&"mid"]
	px[Vector2i(3, 17)] = HAND_NAIL[0]
	px[Vector2i(4, 17)] = HAND_NAIL[1]
	# The star at the fingertip: a gold pixel at rest, a four-point wink on the middle frames.
	var arm: int = HAND_ARMS[frame]
	if arm == 0:
		px[HAND_STAR_AT] = HAND_STAR_GOLD
	else:
		px[HAND_STAR_AT] = HAND_STAR_PALE
		for k in range(1, arm + 1):
			for d: Vector2i in [Vector2i(k, 0), Vector2i(-k, 0), Vector2i(0, k), Vector2i(0, -k)]:
				px[HAND_STAR_AT + d] = HAND_STAR_GOLD
	return px


## Lit from the right: the right edge lit, the left and the bottom edges shaded.
static func _hand_tone(fill: Dictionary, p: Vector2i) -> StringName:
	var right := fill.has(p + Vector2i(1, 0))
	if not right or (not fill.has(p + Vector2i(1, -1)) and not fill.has(p + Vector2i(0, -1))):
		return &"lit"
	if not fill.has(p + Vector2i(-1, 0)) or not fill.has(p + Vector2i(0, 1)):
		return &"low"
	if not fill.has(p + Vector2i(-2, 0)) or not fill.has(p + Vector2i(0, 2)):
		return &"mid"
	return &"body"


## One frame as a picture, its soft shadow down and to the left under it.
func _hand_image(frame: int) -> Image:
	var px := hand_pixels(frame)
	var low := Vector2i(1 << 20, 1 << 20)
	var high := -low
	for p: Vector2i in px:
		for q: Vector2i in [p, p + Vector2i(-1, 1)]:
			low = Vector2i(mini(low.x, q.x), mini(low.y, q.y))
			high = Vector2i(maxi(high.x, q.x), maxi(high.y, q.y))
	_hand_origin = low
	var image := Image.create(high.x - low.x + 1, high.y - low.y + 1, false, Image.FORMAT_RGBA8)
	for p: Vector2i in px:
		image.set_pixelv(p + Vector2i(-1, 1) - low, HAND_SHADE)
	for p: Vector2i in px:
		image.set_pixelv(p - low, px[p])
	return image


## A small picture authored as rows of letters, one rect a pixel.
func _draw_bits(rows: Array, corner: Vector2, px: float, inks: Dictionary, alpha: float = 1.0) -> void:
	for y in rows.size():
		var line: String = rows[y]
		for x in line.length():
			var ink: Variant = inks.get(line[x])
			if ink == null:
				continue
			var colour: Color = ink
			colour.a *= alpha
			draw_rect(Rect2(corner + Vector2(float(x), float(y)) * px, Vector2(px, px)), colour)


## The turn chip beside the piece in hand (2026-10-02): the key `shed_rotate` is bound to,
## as this keyboard prints it (the pad's button in pad mode), and a turning arrow, on the key
## chip's own wood. To the right of the piece, or to its left where the right runs off.
func _draw_turn_hint(floor_box: Rect2) -> void:
	var alpha := turn_hint_alpha()
	if alpha <= 0.0:
		return
	var px := _zoom()
	var piece_size := sheets.view_size_of(carrying, _carry_view) * px
	var piece_box := Rect2(_pointer - piece_size * 0.5, piece_size)
	var ghost := _ghost()
	if not ghost.is_empty():
		piece_box = Rect2(
			floor_box.position + Vector2(float(int(ghost["cell"][0])), float(int(ghost["cell"][1]))) * px,
			piece_size
		)
	var key := Binds.shown(&"shed_rotate", Pad.is_pad())
	var key_wide := Style.measure(key, Style.TEXT_SMALL).x
	var glyph := Vector2(float((TURN_GLYPH[0] as String).length()), float(TURN_GLYPH.size())) * TURN_GLYPH_PX
	var chip := Vector2(5.0 + key_wide + 4.0 + glyph.x + 5.0, 18.0)
	var at := Vector2(piece_box.end.x + TURN_HINT_GAP, piece_box.position.y)
	if at.x + chip.x > size.x:
		at.x = piece_box.position.x - TURN_HINT_GAP - chip.x
	at = Vector2(roundf(at.x), roundf(clampf(at.y, 0.0, size.y - chip.y)))
	var box := Rect2(at, chip)
	draw_rect(box, Color(Style.WOOD.r, Style.WOOD.g, Style.WOOD.b, 0.85 * alpha))
	draw_rect(box, Color(Style.INK_DIM.r, Style.INK_DIM.g, Style.INK_DIM.b, alpha), false, 1.0)
	Style.write(
		self, key, Style.TEXT_SMALL, box.position + Vector2(5.0, 14.0), Style.INK,
		HORIZONTAL_ALIGNMENT_LEFT, Rect2(), alpha
	)
	_draw_bits(
		TURN_GLYPH,
		box.position + Vector2(5.0 + key_wide + 4.0, roundf((chip.y - glyph.y) * 0.5)),
		TURN_GLYPH_PX, {"O": Style.INK}, alpha
	)


func _draw_prompt(floor_box: Rect2) -> void:
	if _you_pet >= 0.0 or not _rest_key.is_empty():
		return
	var at := _switch_near()
	var dog := _dog_near()
	var rest := _rest_near()
	var switch_gap := INF if at < 0 else _you_at.distance_to(_switch_middle(at))
	var dog_gap := INF if dog == null else _you_at.distance_to(dog.at)
	var rest_gap := INF if rest < 0 else _rest_gap(rest)
	if rest >= 0 and _dog_on(rest, dog):
		# The dog lying on the piece is part of it: E lies down beside it, not pets it.
		dog_gap = INF
	if rest >= 0 and rest_gap < switch_gap and rest_gap < dog_gap:
		# A seat, a bed or a bookcase is what E would use: the key goes over it.
		at = rest
		dog = null
	var over := Vector2.ZERO
	if dog != null and dog_gap < switch_gap:
		# The dog is what E would pet (2026-09-28): the key goes over its head.
		var step := float(CELL * _zoom())
		over = floor_box.position + dog.at * step - Vector2(0.0, DOG_TALL * step + PROMPT_LIFT * 0.5)
	elif at < 0:
		return
	else:
		var row: Dictionary = decor[at]
		var piece := StringName(row["piece"])
		var span := span_of(piece, _row_view(row))
		over = floor_box.position + Vector2(
			(float(int(row["cell"][0])) + float(span.x) * 0.5) * _zoom(),
			float(int(row["cell"][1])) * _zoom() - PROMPT_LIFT
		)
	var side := 18.0
	var box := Rect2(over - Vector2(side, side) * 0.5, Vector2(side, side))
	var glyph := Glyphs.lone(Binds.shown(&"shed_switch", Pad.is_pad()))
	if glyph != null:
		Glyphs.draw_centred(self, glyph, box.get_center())
		return
	draw_rect(box, Color(Style.WOOD.r, Style.WOOD.g, Style.WOOD.b, 0.85))
	draw_rect(box, Style.INK_DIM, false, 1.0)
	# What the switch is actually bound to, named as this keyboard prints it — the pad's
	# button in pad mode. It said "Y" or "E" in so many words until the bind board existed.
	Style.write(
		self, Binds.shown(&"shed_switch", Pad.is_pad()), Style.TEXT_SMALL,
		box.position + Vector2(5.0, 14.0), Style.INK
	)


## One piece of furniture, in its cleaned-up palette, standing with its corner at a point,
## in whichever face it is turned to.
func _stamp_piece(
	piece: StringName, at: Vector2, view: int = 0, tint: Color = Color.WHITE
) -> void:
	var region := sheets.view_region_of(piece, view)
	draw_texture_rect_region(
		sheets.atlas, Rect2(at, sheets.view_size_of(piece, view) * _zoom()), region, tint
	)


## The pad in the shed (2026-09-26, `/grill-me` with Richard). **The room is free aim**: the
## left stick walks the player and, with a piece in hand, carries it; A picks up the placed
## piece the player stands at (ringed) and puts a carried one down; Y works a switch and X
## turns what is in hand, as before. **The shelf is a list opened with a shoulder** (RB or
## LB): the stick walks its rows, A takes one into the hands and puts the shelf away, B puts
## the shelf away.
func _pad_tick() -> void:
	if not Pad.is_pad() or not is_visible_in_tree():
		_pad_shelf = false
		return
	if carrying.is_empty() and (
			Input.is_action_just_pressed(&"zoom_in") or Input.is_action_just_pressed(&"zoom_out")):
		_pad_shelf = not _pad_shelf
		Sfx.ui(&"ui_click" if _pad_shelf else &"ui_close")
	if _pad_shelf and not carrying.is_empty():
		# Taken off the shelf: into the player's hands, out in the room.
		_pad_shelf = false
		var hands := _floor_origin() + _you_at * float(CELL) * _zoom()
		get_viewport().warp_mouse(get_global_transform_with_canvas() * hands)
		_pointer = hands


func pad_free() -> bool:
	return not _pad_shelf and not record_up()


## The shelf's rows that are on the face, the wash plank, and the close cross.
func pad_focus() -> Array:
	if not _pad_shelf:
		return []
	var out: Array = []
	var list := _list_rect()
	var store := in_store()
	for i in store.size():
		var box := Rect2(
			list.position.x, list.position.y + float(i * ROW_HEIGHT) - _scroll,
			list.size.x, float(ROW_HEIGHT) - SHELF_ROW_GAP
		)
		if box.position.y < list.position.y - 0.5 or box.end.y > list.end.y + 0.5:
			continue
		out.append({"box": box, "key": store[i], "first": out.is_empty()})
	if _wash_plank != null and _wash_plank.visible:
		out.append({"box": _wash_plank.get_rect(), "key": &"wash", "first": out.is_empty()})
	if _close != null and _close.visible:
		out.append({"box": _close.get_rect(), "key": &"close"})
	return out


func pad_scroll(step: int) -> bool:
	var was := _scroll
	_scroll_by(float(step * ROW_HEIGHT))
	return not is_equal_approx(was, _scroll)


## A in the room: pick up the piece the player stands at. A carried piece goes down through
## the pointer's own click, where the stick has carried it.
func pad_press(_key: Variant) -> bool:
	if _pad_shelf or not carrying.is_empty():
		return false
	var at := _piece_near()
	if at >= 0:
		var box := _piece_box(at)
		_pointer = box.get_center()
		get_viewport().warp_mouse(get_global_transform_with_canvas() * _pointer)
		_pick_up()
		queue_redraw()
	return true


## What A would pick up, ringed.
func pad_mark() -> Rect2:
	if _pad_shelf or not carrying.is_empty():
		return Rect2()
	var at := _piece_near()
	return _piece_box(at) if at >= 0 else Rect2()


## The placed piece nearest the player within `REACH`, as an index into `decor`, or -1.
func _piece_near() -> int:
	var best := -1
	var best_gap := REACH
	for i in decor.size():
		var row: Dictionary = decor[i]
		var span := span_of(StringName(row["piece"]), _row_view(row))
		var middle := Vector2(
			float(int(row["cell"][0])) + float(span.x) * 0.5,
			float(int(row["cell"][1])) + float(span.y)
		) / float(CELL)
		var gap := _you_at.distance_to(middle)
		if gap < best_gap:
			best_gap = gap
			best = i
	return best


func _piece_box(index: int) -> Rect2:
	var row: Dictionary = decor[index]
	var at := Vector2(float(int(row["cell"][0])), float(int(row["cell"][1])))
	var span := Vector2(span_of(StringName(row["piece"]), _row_view(row)))
	return Rect2(_floor_origin() + at * _zoom(), span * _zoom())


## Resting on the furniture (see `RESTS`). -----------------------------------------------

## What resting on this view of this piece offers, [kind, hip lift, sideways], or empty.
func rest_of(piece: StringName, view: int) -> Array:
	var views: Dictionary = RESTS.get(piece, {})
	return views.get(view, [])


## How far the player stands from a piece they might rest on, in cells: to the nearest edge of
## its footprint (2026-10-03, Richard: E did nothing beside the fancy bed). It was measured
## from the middle of the foot, the way a switch is, and a bed five cells deep could only be
## got into from its foot.
func _rest_gap(index: int) -> float:
	var row: Dictionary = decor[index]
	var piece := StringName(row["piece"])
	var view := _row_view(row)
	var span := span_of(piece, view)
	var base := base_of(piece, view)
	var foot := Rect2(
		Vector2(float(int(row["cell"][0])), float(int(row["cell"][1]) + span.y - base)) / float(CELL),
		Vector2(float(span.x), float(base)) / float(CELL)
	)
	var nearest := Vector2(
		clampf(_you_at.x, foot.position.x, foot.end.x), clampf(_you_at.y, foot.position.y, foot.end.y)
	)
	return _you_at.distance_to(nearest)


## Whether this dog is lying on the piece at `index`.
func _dog_on(index: int, dog: ShedDog) -> bool:
	if dog == null:
		return false
	var row: Dictionary = decor[index]
	return dog.seat == "%s@%d,%d" % [row["piece"], int(row["cell"][0]), int(row["cell"][1])]


## The placed piece the player is close enough to rest on, as an index into `decor`, or -1.
## Measured to the nearest edge of its footprint (`_rest_gap`).
func _rest_near() -> int:
	if sheets == null:
		return -1
	var best := -1
	var best_gap := REACH
	for i in decor.size():
		var row: Dictionary = decor[i]
		if rest_of(StringName(row["piece"]), _row_view(row)).is_empty():
			continue
		var gap := _rest_gap(i)
		if gap < best_gap:
			best_gap = gap
			best = i
	return best


## The row the player is resting on, or -1 when it has gone: picked up, or turned to a face
## with a different rest or none. Asked every frame, since the player can do both while
## sitting there.
func _rest_row() -> int:
	for i in decor.size():
		var row: Dictionary = decor[i]
		var key := "%s@%d,%d" % [row["piece"], int(row["cell"][0]), int(row["cell"][1])]
		if key != _rest_key:
			continue
		var spec := rest_of(StringName(row["piece"]), _row_view(row))
		return i if not spec.is_empty() and StringName(spec[0]) == _rest_kind else -1
	return -1


## What the player is doing on the furniture: &"front", &"back", &"lie", &"read", or &"".
func resting() -> StringName:
	return &"" if _rest_key.is_empty() else _rest_kind


## Sit, lie or read at this piece. A dog lying on a seat for one hops off; on the sofa and the
## bed it stays. A dog with nowhere to lie may come up and join the player.
func rest_on(index: int) -> void:
	var row: Dictionary = decor[index]
	var piece := StringName(row["piece"])
	var spec := rest_of(piece, _row_view(row))
	if spec.is_empty():
		return
	_rest_key = "%s@%d,%d" % [piece, int(row["cell"][0]), int(row["cell"][1])]
	_rest_kind = spec[0]
	_rest_age = 0.0
	_rest_from = _you_at
	_you_step = 0.0
	_you_facing = Vector2(0.0, -1.0) if _rest_kind == &"back" else Vector2(0.0, 1.0)
	if _rest_kind == &"read":
		_read_book = _dog_rng.randi_range(0, BOOKS - 1)
		return
	var taken := false
	for dog in _dogs:
		if dog.seat != _rest_key:
			continue
		if piece in SEAT_FOR_ONE:
			_drop_seat(dog)
			dog.state = DogArt.gait(dog.slot, true, dog.breed)
			dog.target = _dog_somewhere(dog)
			dog.mood = DOG_MOOD_MOST
		else:
			taken = true
	if taken or piece in SEAT_FOR_ONE or _dog_rng.randf() >= JOIN_ODDS:
		return
	for seat: Dictionary in _seats():
		if String(seat["key"]) != _rest_key:
			continue
		for dog in _dogs:
			if dog.seat.is_empty():
				dog.seat = _rest_key
				dog.over = seat["over"]
				dog.state = DogArt.gait(dog.slot, true, dog.breed)
				dog.target = seat["feet"]
				dog.mood = DOG_MOOD_MOST
				return


## Get up, back to where the player stood before.
func stand_up() -> void:
	if _rest_key.is_empty():
		return
	_rest_key = ""
	_you_at = _rest_from
	_you_facing = Vector2(0.0, 1.0)
	_you_age = 0.0


## Where the player sorts among the furniture: over a piece they sit or lie on, either way
## round (a back sit draws the backrest over them itself, `_draw_resting`), and by their
## feet otherwise.
func _you_key(rows: Array) -> float:
	var at := _rest_row()
	if at < 0 or _rest_kind == &"read":
		return _walker_key(_you_at, rows)
	var foot := _foot_of(decor[at])
	return foot + OVER_PIECE


## The player sitting on or lying in the piece they rest on.
func _draw_resting(floor_box: Rect2) -> void:
	var at := _rest_row()
	if at < 0:
		return
	var row: Dictionary = decor[at]
	var piece := StringName(row["piece"])
	var view := _row_view(row)
	var spec := rest_of(piece, view)
	var zoom := _zoom()
	var drawn := sheets.scale_of(piece) * zoom
	var box := Rect2(
		floor_box.position
			+ Vector2(float(int(row["cell"][0])), float(int(row["cell"][1]))) * zoom,
		sheets.view_size_of(piece, view) * zoom
	)
	var tall := YOU_TALL * float(CELL) * zoom
	var scale := maxf(1.0, roundf(tall / _you_ink_tall / YOU_STEP) * YOU_STEP)
	if _rest_kind == &"lie":
		_draw_lying(piece, view, box, drawn, scale)
		return
	var pose := &"sit_south"
	if _rest_kind == &"back":
		pose = &"sit_north"
	if not _you_poses.has(pose):
		return
	var frames: Array = _you_poses[pose]
	var index := 0
	if fmod(_rest_age, BREATH) > BREATH * (1.0 - BREATH_IN):
		index = mini(1, frames.size() - 1)
	var region: Rect2 = (frames[index] as Dictionary)["region"]
	var ink: Rect2 = (frames[0] as Dictionary)["ink"]
	var middle := box.get_center().x + float(spec[2]) * drawn
	# Sitting, the body's own axis goes on the seat's middle, not the ink box's (`_body_axis`).
	var axis: float = (frames[0] as Dictionary).get("axis", ink.position.x + ink.size.x * 0.5)
	var origin := Vector2(middle - axis * scale, 0.0)
	var hip: int = SIT_HIP[&"north" if _rest_kind == &"back" else &"south"]
	var foot := box.end.y - float(spec[1]) * drawn + float(hip) * scale
	origin.y = foot - (ink.position.y + ink.size.y) * scale
	origin = origin.round()
	var size := region.size * scale
	if _rest_kind == &"front":
		var away := _room_away(origin + size * 0.5)
		draw_texture_rect_region(
			_you_sheet, Rect2(origin + (away * SIT_SHADE_REACH).round() * scale, size), region,
			Shade.tint(_room_ink())
		)
	var shown_region := region
	var shown_size := size
	if _rest_kind == &"back" and spec.size() > 5:
		# Not below the cushion's foot: the legs go forward under the seat.
		var floor_at := box.position.y + float(int(spec[5])) * drawn
		var keep := clampf((floor_at - origin.y) / scale, 0.0, region.size.y)
		shown_region = Rect2(region.position, Vector2(region.size.x, roundf(keep)))
		shown_size = shown_region.size * scale
	draw_texture_rect_region(_you_sheet, Rect2(origin, shown_size), shown_region)
	if _rest_kind == &"back" and spec.size() > 3:
		# The backrest over the player: the piece's rows from the cut down, drawn again.
		var piece_region := sheets.view_region_of(piece, view)
		var cut := float(int(spec[3]))
		var end := piece_region.size.y if spec.size() < 5 else minf(float(int(spec[4])), piece_region.size.y)
		if cut < end:
			draw_texture_rect_region(
				sheets.atlas,
				Rect2(box.position + Vector2(0.0, cut * drawn), Vector2(box.size.x, (end - cut) * drawn)),
				Rect2(piece_region.position + Vector2(0.0, cut), Vector2(piece_region.size.x, end - cut))
			)


## Lying in bed (`LIES`): the head on the pillow, the bed's own picture drawn back over it
## from the chin (or the near board) towards the feet, a sideways head held inside the
## headboard, and two folds down the body under the blanket.
func _draw_lying(piece: StringName, view: int, box: Rect2, drawn: float, scale: float) -> void:
	var spot: Dictionary = (LIES.get(piece, {}) as Dictionary).get(view, {})
	if spot.is_empty():
		return
	var face := StringName(spot["face"])
	var pose := {&"up": &"lie_south", &"down": &"lie_north", &"west": &"lie_west",
		&"east": &"lie_east"}.get(face, &"lie_south") as StringName
	if not _you_poses.has(pose):
		return
	var frame: Dictionary = (_you_poses[pose] as Array)[0]
	var region: Rect2 = frame["region"]
	var ink: Rect2 = frame["ink"]
	var at: Vector2 = spot["at"]
	var mark := box.position + at * drawn
	# Which point of the ink goes on `at`: the chin (or the head's foot) for up and down, the
	# chin's side for a sideways head.
	var anchor := Vector2(ink.get_center().x, ink.end.y)
	if face == &"west":
		anchor = Vector2(ink.end.x, ink.get_center().y)
	elif face == &"east":
		anchor = Vector2(ink.position.x, ink.get_center().y)
	var origin := (mark - anchor * scale).round()
	var shown := Rect2(origin, region.size * scale)
	if spot.has("clip"):
		var edge := box.position.x + float(spot["clip"]) * drawn
		var keep := Rect2(Vector2(edge, -1e6), Vector2(1e7, 2e6)) if face == &"west" 			else Rect2(Vector2(-1e7, -1e6), Vector2(1e7 + edge, 2e6))
		shown = shown.intersection(keep)
	if shown.size.x > 0.0 and shown.size.y > 0.0:
		var source := Rect2(region.position + ((shown.position - origin) / scale).round(),
			(shown.size / scale).round())
		draw_texture_rect_region(_you_sheet, Rect2(origin + (source.position - region.position) * scale,
			source.size * scale), source)
	# The bed over the head from the cover line on: the blanket up to the chin, or the near
	# board in front of the pillow.
	var picture := sheets.view_region_of(piece, view)
	var cover := float(spot.get("cover", at.x if face == &"west" or face == &"east" else at.y))
	var over := Rect2(Vector2.ZERO, picture.size)
	match face:
		&"up", &"down":
			over = Rect2(Vector2(0.0, cover), Vector2(picture.size.x, picture.size.y - cover))
		&"west":
			over = Rect2(Vector2(cover, 0.0), Vector2(picture.size.x - cover, picture.size.y))
		&"east":
			over = Rect2(Vector2.ZERO, Vector2(cover, picture.size.y))
	if over.size.x > 0.0 and over.size.y > 0.0:
		draw_texture_rect_region(sheets.atlas,
			Rect2(box.position + over.position * drawn, over.size * drawn),
			Rect2(picture.position + over.position, over.size))
	_draw_blanket(box, drawn, spot, cover)
	if _rest_age >= SLEEP_AFTER:
		var top := Vector2(origin.x + ink.get_center().x * scale, origin.y + ink.position.y * scale)
		_draw_zs(top + Vector2(ink.size.x * 0.3 * scale, 0.0), scale)


## The body under the blanket: two folds along it from the cover line to the feet and a lit
## turn-down across it, in shade and light rather than a colour, so every bed wears them.
func _draw_blanket(box: Rect2, drawn: float, spot: Dictionary, cover: float) -> void:
	var face := StringName(spot["face"])
	var at: Vector2 = spot["at"]
	var feet := float(spot.get("feet", cover))
	var px := maxf(1.0, roundf(drawn))
	var shade := Color(0.0, 0.0, 0.0, 0.22)
	var lit := Color(1.0, 1.0, 1.0, 0.22)
	var side := LIE_FOLD * drawn
	if face == &"up" or face == &"down":
		var middle := box.position.x + at.x * drawn
		var from := box.position.y + minf(cover, feet) * drawn
		var to := box.position.y + maxf(cover, feet) * drawn
		if face == &"up":
			from += px * 1.5
		else:
			to -= px * 1.5
		for toward: float in [-1.0, 1.0]:
			draw_rect(Rect2(Vector2(roundf(middle + toward * side), roundf(from)),
				Vector2(px, maxf(roundf(to - from), 0.0))), shade)
		var line := box.position.y + cover * drawn - (0.0 if face == &"up" else px * 1.5)
		draw_rect(Rect2(Vector2(roundf(middle - side), roundf(line)),
			Vector2(roundf(side * 2.0) + px, px * 1.5)), lit)
	else:
		var middle := box.position.y + at.y * drawn
		var from := box.position.x + minf(cover, feet) * drawn
		var to := box.position.x + maxf(cover, feet) * drawn
		if face == &"west":
			from += px * 1.5
		else:
			to -= px * 1.5
		for toward: float in [-1.0, 1.0]:
			draw_rect(Rect2(Vector2(roundf(from), roundf(middle + toward * side)),
				Vector2(maxf(roundf(to - from), 0.0), px)), shade)
		var line := box.position.x + cover * drawn - (0.0 if face == &"west" else px * 1.5)
		draw_rect(Rect2(Vector2(roundf(line), roundf(middle - side)),
			Vector2(px * 1.5, roundf(side * 2.0) + px)), lit)


## Three Zs rising off the sleeper, a size apart, each fading in and out in turn.
func _draw_zs(from: Vector2, scale: float) -> void:
	for i in 3:
		var phase := fmod(_rest_age * 0.6 + float(i) / 3.0, 1.0)
		var at := from + Vector2(float(i) * 5.0, -float(i) * 7.0 - phase * 6.0) * scale * 0.5
		Style.write(
			self, "z", Style.TEXT_SMALL + i * 3, at.round(), Color(1.0, 1.0, 1.0, sin(phase * PI))
		)
