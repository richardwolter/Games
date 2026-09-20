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
## `_dog_at`, `_feet_keep`, `REACH`, the glow radii) and `_taken` blocks whole cells, because
## per-pixel collision is sixty-four times the entries for a difference nobody can feel. The
## two units therefore meet in a handful of places, and every one of them divides by `CELL`
## on the way: `_foot_of` and `_walker_key` (sort keys are in cells), `_taken`, `_bed_cell`,
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
## Since 2026-09-19 this is only the piece the dogs may *walk over* — `_taken` leaves it out
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

## How close the player has to stand to work a switch, in cells, and how far above the
## piece the prompt floats.
##
## A fireplace is lit by walking up to it, not by clicking it from across the room: the
## room already has a drag gesture and a second meaning for the same click is how a player
## ends up dragging the fridge every time they meant to open it.
const REACH := 3.2
const PROMPT_LIFT := 8.0

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
## The window: how far down the back wall's height it sits on the left wall, and the shaft
## it lets in — half-width and reach in cells. The sun's power, its slope (how steeply the
## light falls across the room) and its tone all run morning to late afternoon on
## `DayCycle.sun`: a pale, short, steep shaft early, a long low orange one late. With no day
## handed over the room sits at `SUN_NO_DAY`. All by eye.
const WINDOW_DOWN := 0.55
const SHAFT_WIDE := 1.6
const SHAFT_LONG := 30.0
const SUN_POWER := Vector2(0.30, 0.62)
const SUN_SLOPE := Vector2(0.95, 0.38)
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

## Which view a STATE piece is switched on in. Both state sets are authored off-then-on.
const STATE_OFF := 0
const STATE_ON := 1

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

## The art, and the two arrays this screen is a view of. Both are owned by lake.gd — the
## room edits `decor` in place rather than keeping a copy, so what is on screen and what
## gets saved cannot drift apart.
var sheets: Sheets
var unlocked: Array[String] = []

## Piece name -> what to call it on screen. Filled in by lake.gd from the defs.
var titles := {}
var decor: Array = []

## What is being dragged, as a piece name, and where it came from: the index it had in
## `decor`, or -1 when it was picked up off the inventory list.
var carrying: StringName = &""

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

	## The seat this dog holds, as its key in `_seats()`, or "" for a dog on the floor.
	## Held rather than looked up each frame: a seat is claimed, and a claim is a fact about
	## the dog, not about the furniture.
	var seat: String = ""

	## The cells this dog is allowed to stand on although something is standing there — the
	## foot of the piece whose seat it holds. Without it the sofa's own base refuses the dog
	## the cushion and `_process`'s unstick shoves it off again every frame.
	var over: Dictionary = {}


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

var _dog_rng := RandomNumberGenerator.new()

## The seat table, and the `decor.hash()` it was built for. Memoised like `_taken`, and for
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

## How tall the figure draws inside its cell, and where its feet sit in that cell. See
## `_load_you`.
var _you_ink_tall: float = 43.0
var _you_ink_foot: float = 45.0

## Cells something is standing on, rebuilt when `decor` changes. Rugs are not in it: a dog
## may walk on a rug, and a room full of rugs it refuses to cross is a room it cannot leave.
var _blocked := {}
var _blocked_for: int = 0


func _ready() -> void:
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
	_dog_rng.randomize()
	_load_you()
	# The dog only runs while the room is on screen: it is a picture of a room, and nothing
	# in it is happening while nobody is looking at it.
	visibility_changed.connect(_room_shown)
	set_process(false)


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

	_dogs.clear()
	if not DogArt.ready():
		return
	for _which in _pack_wanted():
		if _dog_rng.randf() >= DOG_ODDS:
			continue
		var dog := ShedDog.new()
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
	if dog.state == &"walk":
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
			frames.append({
				"region": Rect2(region[0], region[1], region[2], region[3]),
				"ink": Rect2(ink[0], ink[1], ink[2], ink[3]),
			})
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
	var wanted := _you_at + step
	if _you_may_stand(wanted):
		_you_at = wanted
		return
	if absf(step.x) > 0.0001 and _you_may_stand(_you_at + Vector2(step.x, 0.0)):
		_you_at += Vector2(step.x, 0.0)
	elif absf(step.y) > 0.0001 and _you_may_stand(_you_at + Vector2(0.0, step.y)):
		_you_at += Vector2(0.0, step.y)


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


## The player, standing on the floor of the room.
func _draw_you(floor_box: Rect2) -> void:
	if _you_sheet == null:
		return
	var step := float(CELL * _zoom())
	var at := floor_box.position + _you_at * step
	var tall := YOU_TALL * step

	var ring := PackedVector2Array()
	for i in 13:
		var angle := TAU * float(i) / 12.0
		ring.append(at + Vector2(cos(angle) * tall * 0.26, sin(angle) * tall * 0.11))
	draw_colored_polygon(ring, Color(0.0, 0.0, 0.0, 0.16))

	var walking := _you_step > 0.0
	var pose := StringName("%s_%s" % ["run" if walking else "idle", _you_view()])
	if not _you_poses.has(pose):
		return
	var frames: Array = _you_poses[pose]
	var held := Angler.RUN_FRAME if walking else Angler.IDLE_FRAME
	var frame: Dictionary = frames[posmod(int(_you_age / held), frames.size())]
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
	draw_texture_rect_region(_you_sheet, box, region)


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
	draw_rect(opening, DOOR_OPEN)
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
	draw_texture_rect(BORDER_TOP_RIGHT, Rect2(Vector2(left, wall.position.y), corner), false)
	draw_texture_rect(BORDER_TOP_LEFT, Rect2(Vector2(right, wall.position.y), corner), false)


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
	draw_texture_rect(BORDER_TOP_RIGHT, Rect2(Vector2(left, top), upright), false)
	draw_texture_rect(BORDER_TOP_LEFT, Rect2(Vector2(right, top), upright), false)


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
			dog.state = &"walk"
			dog.target = seat
			dog.mood = DOG_MOOD_MOST
		return
	var roll := _dog_rng.randf()
	dog.mood = _dog_rng.randf_range(DOG_MOOD_LEAST, DOG_MOOD_MOST)
	if roll < 0.45:
		dog.state = &"walk"
		dog.target = _dog_somewhere(dog)
	elif roll < 0.65:
		dog.state = &"idle"
	elif roll < 0.85:
		dog.state = &"laid"
	else:
		dog.state = &"sleep"


## One step towards the target. True once it is there, or once it is stuck.
##
## The step is refused if the cell it would put the dog in is standing on something. Refused
## outright rather than slid along, and then a new target is picked: a dog nosing along the
## side of a wardrobe looking for a way round reads as a bug, where a dog changing its mind
## reads as a dog.
func _dog_walk(dog: ShedDog, delta: float) -> bool:
	var gap := dog.target - dog.at
	if gap.length() <= 0.25:
		return true
	var step := gap.normalized() * minf(DOG_SPEED * delta, DOG_STEP_MOST)
	if absf(step.x) > 0.0001:
		dog.left = step.x < 0.0
	var wanted := dog.at + step
	var others := _others_than(dog)
	others.append(_you_at)
	if _clear_of_all(wanted, dog.at, others, dog.over):
		dog.at = wanted
		return dog.at.distance_to(dog.target) <= 0.25
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
	for _try in IDLE_DARTS:
		var where := Vector2(
			_dog_rng.randf_range(1.0, float(COLS) - 1.0),
			_dog_rng.randf_range(1.0, float(ROWS) - 1.0)
		)
		if not _dog_may_stand(where, dog.over):
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
## `_drive_dog` every frame. The pet bed needs none of this: it is left out of `_taken`
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
	var cell := Vector2i(int(where.x), int(where.y))
	return over.has(cell) or not _taken().has(cell)


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


## The same question, asked by one of the two things that walk about in here, with the other
## one counted as furniture.
##
## Tight, like the rule outdoors: the dog is meant to be able to come and stand beside you,
## and only walking through you is refused. Enforced only on somebody not already inside the
## other — a chair put down on the pair of them, or a dog that padded up while the room was
## being rearranged, must not leave either of them pinned.
func _clear_of(where: Vector2, from: Vector2, other: Vector2, over: Dictionary = {}) -> bool:
	if not _dog_may_stand(where, over):
		return false
	if from.distance_to(other) < ROOM_PERSONAL:
		return true
	return where.distance_to(other) >= ROOM_PERSONAL


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
## Memoised on `decor.hash()`, like `_taken`: `decor` is the lake's array and is edited in
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
## stand on although `_taken` says something is there. The same walk `_taken` does, kept
## apart from it because this is one piece and that is the whole room.
func _foot_cells(piece: StringName, view: int, cell: Vector2i) -> Dictionary:
	var cells := {}
	var span := span_of(piece, view)
	var base := base_of(piece, view)
	var foot := Rect2(
		Vector2(float(cell.x), float(cell.y + span.y - base)),
		Vector2(float(span.x), float(base))
	)
	var from := Vector2i(
		int(floor(foot.position.x / float(CELL))), int(floor(foot.position.y / float(CELL)))
	)
	var to := Vector2i(
		int(floor((foot.end.x - 1.0) / float(CELL))),
		int(floor((foot.end.y - 1.0) / float(CELL)))
	)
	for cy in range(from.y, to.y + 1):
		for cx in range(from.x, to.x + 1):
			if cy >= 0:
				cells[Vector2i(cx, cy)] = true
	return cells


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
func _taken() -> Dictionary:
	var key := decor.hash()
	if key == _blocked_for:
		return _blocked
	_blocked_for = key
	_blocked = {}
	for row: Dictionary in decor:
		var piece := StringName(row["piece"])
		if piece == DOG_BED or sheets == null or sheets.lies_flat(piece) or sheets.on_wall(piece):
			continue
		var span := span_of(piece, _row_view(row))
		var cell := Vector2i(int(row["cell"][0]), int(row["cell"][1]))
		var base := base_of(piece, _row_view(row))
		var foot := Rect2(
			Vector2(float(cell.x), float(cell.y + span.y - base)),
			Vector2(float(span.x), float(base))
		)
		var found := false
		var from := Vector2i(
			int(floor(foot.position.x / float(CELL))), int(floor(foot.position.y / float(CELL)))
		)
		var to := Vector2i(
			int(floor((foot.end.x - 1.0) / float(CELL))),
			int(floor((foot.end.y - 1.0) / float(CELL)))
		)
		for cy in range(from.y, to.y + 1):
			for cx in range(from.x, to.x + 1):
				var middle := (Vector2(float(cx), float(cy)) + Vector2(0.5, 0.5)) * float(CELL)
				if not foot.has_point(middle):
					continue
				found = true
				if cy >= 0:
					_blocked[Vector2i(cx, cy)] = true
		if not found:
			var only := (foot.position + foot.size * 0.5) / float(CELL)
			if only.y >= 0.0:
				_blocked[Vector2i(int(floor(only.x)), int(floor(only.y)))] = true
	return _blocked


## The dog, on the floor, at whatever size the room is drawn.
##
## On its own shadow, the way everything else in this game that stands on a surface is: the
## room is drawn flat and a dog with nothing under it hovers over the boards.
func _draw_dog(floor_box: Rect2, dog: ShedDog) -> void:
	var step := CELL * _zoom()
	var at := floor_box.position + dog.at * float(step)
	var tall := DOG_TALL * float(step)
	var ring := PackedVector2Array()
	var wide := tall * (0.34 if dog.state == &"sleep" or dog.state == &"laid" else 0.44)
	for i in 13:
		var angle := TAU * float(i) / 12.0
		ring.append(at + Vector2(cos(angle) * wide, sin(angle) * wide * 0.42))
	draw_colored_polygon(ring, Color(0.0, 0.0, 0.0, 0.16))
	DogArt.stamp(
		self, dog.state, DogArt.frame_at(dog.state, dog.age), at, tall, dog.left
	)


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
## (`_taken`), the small piece's host probe (`_host_of`) and the band a walker sorts over
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
	_carry_view = posmod(_carry_view + 1, sheets.view_count(carrying))
	queue_redraw()


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
		if not sheets.switchable(piece):
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
func switch_near() -> bool:
	var at := _switch_near()
	if at < 0:
		return false
	var row: Dictionary = decor[at]
	row["view"] = STATE_ON if _row_view(row) == STATE_OFF else STATE_OFF
	changed.emit()
	queue_redraw()
	return true


## Whether any fire in the room is burning: a switched-on piece that is not a fridge standing
## open. What the fireplace's crackle is held on.
func _fire_lit() -> bool:
	if sheets == null:
		return false
	for row: Dictionary in decor:
		var piece := StringName(row["piece"])
		if (
			sheets.switchable(piece) and _row_view(row) == STATE_ON
			and sheets.role_of(piece, STATE_ON) != &"open"
		):
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
## the fireplace ahead of the door: E lights the fire the player is standing at, and E
## anywhere else in the room falls through to meaning "leave", the way it always has.
## Escape still leaves from anywhere, including the hearth.
func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
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
		_pick_up()
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
	var middle := spot_at(_pointer)
	var cell := middle - Vector2i(span.x / 2, span.y / 2)
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
	var rows := in_store().size()
	var span := maxf(float(rows * ROW_HEIGHT) - _list_rect().size.y, 0.0)
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
		if feet.x >= left and feet.x < right and feet.y >= top and feet.y < foot:
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
	var fit := mini(int(wide) / (COLS * CELL), int(tall) / ((ROWS + WALL_ROWS) * CELL))
	return float(clampi(fit, 1, ZOOM_MOST))


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
			draw_texture_rect_region(
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

	draw_texture_rect(BORDER_TOP_LEFT, Rect2(frame.position, tl), false)
	draw_texture_rect(
		BORDER_TOP_RIGHT, Rect2(Vector2(frame.end.x - tr.x, frame.position.y), tr), false
	)
	if bottom:
		draw_texture_rect(
			BORDER_BOTTOM_LEFT, Rect2(Vector2(frame.position.x, frame.end.y - bl.y), bl), false
		)
		draw_texture_rect(BORDER_BOTTOM_RIGHT, Rect2(frame.end - br, br), false)
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
		draw_texture_rect_region(tex, Rect2(pos, draw_size), src)


func _draw() -> void:
	if sheets == null:
		return
	_place_close()
	draw_rect(Rect2(-global_position, get_viewport_rect().size), ROOM_SCRIM)

	var floor_box := _floor_rect()

	# The room: a back wall standing above the floor, so the space has a direction and the
	# furniture has something to be against. Wallpapered, not flat.
	var wall_tall := _wall_tall()
	var wall := Rect2(
		Vector2(floor_box.position.x, maxf(floor_box.position.y - wall_tall, 0.0)),
		Vector2(floor_box.size.x, minf(wall_tall, floor_box.position.y))
	)
	draw_rect(wall, Color(0.30, 0.26, 0.24))
	_tile_rect(WALLPAPER_TILE, wall)
	_draw_door(wall)

	# The floor: the new tile, laid both ways across the whole box. Backed by a flat fill
	# first so a box whose size does not divide evenly never shows a gap at the far edge —
	# the last row and column are cut to it.
	draw_rect(floor_box, Color(0.47, 0.36, 0.26))
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
	var walkers: Array = []
	for dog in _dogs:
		walkers.append({"key": _walker_key(dog.at, rows), "dog": dog})
	if _you_sheet != null:
		walkers.append({"key": _walker_key(_you_at, rows), "dog": null})
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
	_shelf.title = "Decorate" if store.is_empty() else "Decorate  %d" % store.size()
	_shelf.atlas = sheets.atlas
	_shelf.scroll = _scroll
	_shelf.hovered = -1 if not carrying.is_empty() else _hovered_row()
	var rows: Array[Dictionary] = []
	for piece in store:
		rows.append({
			"region": sheets.alt_region_of(StringName(piece)),
			"title": title_of(piece),
		})
	_shelf.rows = rows
	_shelf.queue_redraw()


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
		if not sheets.switchable(piece) or _row_view(row) != STATE_ON:
			continue
		var fridge := sheets.role_of(piece, _row_view(row)) == &"open"
		var span := span_of(piece, _row_view(row))
		out.append({
			"at": floor_box.position + Vector2(
				(float(int(row["cell"][0])) + float(span.x) * 0.5) * _zoom(),
				(float(int(row["cell"][1])) + float(span.y)) * _zoom()
			),
			"reach": (FRIDGE_REACH if fridge else FIRE_REACH) * CELL * _zoom(),
			"power": FRIDGE_POWER if fridge else FIRE_POWER,
			"tone": FRIDGE_TONE if fridge else FIRE_TONE,
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
	lit.set_shader_parameter(&"window_at", Vector2(0.0, _wall_tall() * WINDOW_DOWN))
	lit.set_shader_parameter(&"sun_dir", Vector2(1.0, lerpf(SUN_SLOPE.x, SUN_SLOPE.y, share)))
	lit.set_shader_parameter(&"sun_power", lerpf(SUN_POWER.x, SUN_POWER.y, share))
	lit.set_shader_parameter(&"sun_tone", Vector3(tone.r, tone.g, tone.b))
	lit.set_shader_parameter(&"shaft_wide", SHAFT_WIDE * cell)
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


## The nudge over a switch the player is standing at. Nothing at all when they are not.
##
## The fireplace and the fridge are the only two things in the game worked by standing
## rather than clicking, so there is no chance of learning the verb anywhere else: without
## this the player walks past a fireplace they own and never finds out it lights.
func _draw_prompt(floor_box: Rect2) -> void:
	var at := _switch_near()
	if at < 0:
		return
	var row: Dictionary = decor[at]
	var piece := StringName(row["piece"])
	var span := span_of(piece, _row_view(row))
	var over := floor_box.position + Vector2(
		(float(int(row["cell"][0])) + float(span.x) * 0.5) * _zoom(),
		float(int(row["cell"][1])) * _zoom() - PROMPT_LIFT
	)
	var side := 18.0
	var box := Rect2(over - Vector2(side, side) * 0.5, Vector2(side, side))
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
