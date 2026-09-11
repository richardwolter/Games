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

## The grid things are placed on, in source pixels, and how far the room is blown up.
##
## Half the 16 px grid the art was drawn on. Furniture is not drawn to whole cells — a
## chair is twenty-seven pixels across, a stool nineteen — and snapping those to a
## sixteen-pixel grid leaves a margin of dead floor around everything. Eight is fine enough
## that a piece lands where it looks like it should and coarse enough to still snap.
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

## How wide the inventory column down the right is, in pixels, and how tall one row of it
## is. A row holds one find: its picture and its name.
const LIST_WIDTH := 210
const ROW_HEIGHT := 56

## Gap between the room and the list, and the margin around the lot inside the panel.
const GUTTER := 14
const MARGIN := 8.0

## How far the inventory column fades back while a find is being carried. The list sits over
## part of the floor and a player placing furniture is looking at the floor, not at the list
## they have already taken the piece out of.
const LIST_BUSY := 0.25


## The close cross: how big it is drawn, and how far above the inventory column it sits.
const CLOSE_SIDE := 34.0
const CLOSE_LIFT := 10.0

## The dog, when it happens to be in.
##
## It is in the shed about half the time the player walks in, because a dog that is always
## exactly where you left it is furniture. When it is in, it mooches from one clear patch of
## floor to another — unless there is a pet bed out, in which case it goes straight to the
## bed and stays there.
const DOG_ODDS := 0.55

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
const DOG_BED := &"decor_pet_bed"

## How many cells deep a piece's foot is — the part of it actually standing on the floor.
const BASE_CELLS := 1

## How close the player has to stand to work a switch, in cells, and how far above the
## piece the prompt floats.
##
## A fireplace is lit by walking up to it, not by clicking it from across the room: the
## room already has a drag gesture and a second meaning for the same click is how a player
## ends up dragging the fridge every time they meant to open it.
const REACH := 3.2
const PROMPT_LIFT := 8.0

## The glow a lit piece throws on the room, as a radius in cells and a colour.
##
## Drawn rather than lit: the room is one `_draw` on a Control and has no light nodes to
## hang a Light2D off. Three rings of a soft additive colour read as a glow at this scale
## and cost three `draw_circle` calls.
const GLOW_RINGS := 3
const FIRE_GLOW := Color(1.0, 0.55, 0.18, 0.13)
const FIRE_REACH := 7.0
## Weaker and much whiter: an open fridge is a bulb in a box, not a hearth.
const FRIDGE_GLOW := Color(0.86, 0.93, 1.0, 0.06)
const FRIDGE_REACH := 3.6

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

## How much taller the back wall stands than a plain board-multiple, and how the door
## opening it frames is sized against it. Both grew together — a door framed in moulding
## reads small against the wall it used to fit, so the wall grew to give it room.
## `_room_rect()` reserves the same height at the top of the panel for it, so the floor
## (and everything below it — the list, the close cross) sits that much further down the
## screen than before. Tune by feel; these are first guesses.
const WALL_GROW := 1.9

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
## Then 4.4 read as a giant in a room whose furniture is drawn at house scale, so it is down
## by a third again: 3.4 is 4.4 over 1.3, and the rounding still lands it on a clean whole
## number of screen pixels per pixel of art.
##
## The same sheet the lake draws them from — three views and a six-frame stride — read here
## rather than borrowed off the Angler node, because that node walks an island: its rules are
## a shoreline and a hut footprint, and none of that is in this room.
const YOU_ART := "res://assets/character.json"
const YOU_TALL := 3.4
const YOU_SPEED := 7.0
const YOU_STEP_MOST := 0.7

## Seconds a frame of the walk and the idle are held. The lake's own numbers, so the figure
## moves the same indoors as out.
const YOU_IDLE_FRAME := 0.24
const YOU_WALK_FRAME := 0.1

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

## The dog: whether it is in at all, where it is standing in cells, and what it is up to.
## See `_dog_think`.
var _dog_here: bool = false
var _dog_at := Vector2.ZERO
var _dog_target := Vector2.ZERO
var _dog_state: StringName = &"idle"
var _dog_age: float = 0.0
var _dog_mood: float = 0.0
var _dog_left: bool = false
var _dog_rng := RandomNumberGenerator.new()

## The player in the room: where they stand in cells, which way they face, how long they
## have been walking (nought when still), and how long the room has been open — which is
## what the idle cycle is counted off.
var _you_at := Vector2.ZERO
var _you_left: bool = false
var _you_facing := Vector2(0.0, 1.0)
var _you_step: float = 0.0
var _you_age: float = 0.0

## The sheet the player is drawn from, and the same sheet turned over for the walks that go
## the other way. Loaded once, and null when the art is missing — in which case the room
## draws no player rather than a box.
var _you_sheet: Texture2D
var _you_mirror: Texture2D
var _you_sheet_wide: float = 0.0
var _you_poses := {}

## The hat, toned to match the sheet. See `_load_you`.
var _you_hat: Texture2D

## How tall the figure draws inside its cell, and where its feet sit in that cell. See
## `_load_you`.
var _you_ink_tall: float = 20.0
var _you_ink_foot: float = 26.0

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
	_dog_rng.randomize()
	_load_you()
	# The dog only runs while the room is on screen: it is a picture of a room, and nothing
	# in it is happening while nobody is looking at it.
	visibility_changed.connect(_room_shown)
	set_process(false)


## The room came on screen, or went off it.
##
## Whether the dog is in is rolled here rather than kept: it is decided each time the player
## opens the shed, which is what makes walking in and finding it asleep on the bed feel like
## finding it rather than like checking on it.
func _room_shown() -> void:
	var showing := is_visible_in_tree()
	set_process(showing)
	if not showing:
		return
	# Stood just inside the door, facing the room: they have walked in, not been placed.
	var door := _door_span()
	_you_at = Vector2((door.x + door.y) * 0.5, YOU_ENTRY)
	_you_facing = Vector2(0.0, 1.0)
	_you_step = 0.0
	_you_age = 0.0

	_dog_here = DogArt.ready() and _dog_rng.randf() < DOG_ODDS
	if not _dog_here:
		return
	# On the bed already when there is one, rather than walking over to it while the player
	# watches: the door opening is not an event the dog got up for.
	var bed := _bed_cell()
	_dog_at = bed if bed != Vector2.INF else _dog_somewhere()
	_dog_target = _dog_at
	_dog_age = 0.0
	_dog_mood = 0.0
	_dog_think()


func _process(delta: float) -> void:
	# One long frame is one slow frame. A hitch, or the window coming back after being
	# minimised, hands this whatever delta it likes, and speed times that is a dog that
	# jumps across the room.
	delta = minf(delta, 0.1)
	_walk_you(delta)
	if not _dog_here:
		queue_redraw()
		return
	_dog_age += delta
	_dog_mood -= delta
	# Furniture can be put down on top of the dog, which leaves it standing inside a
	# wardrobe with every step out of it refused. Nobody sees it move — the piece is over it
	# — and a dog wedged in a cupboard for the rest of the session is worse than one that
	# turns up a foot to the left.
	if not _dog_may_stand(_dog_at):
		_dog_at = _dog_somewhere()
		_dog_target = _dog_at
	if _dog_state == &"walk":
		if _dog_walk(delta) or _dog_mood <= 0.0:
			_dog_think()
	elif _dog_mood <= 0.0:
		_dog_think()
	queue_redraw()


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
	# The hat goes through the same tone as the figure under it, for the same reason.
	var hat := Art.image(Angler.HAT_ART)
	if hat != null:
		_you_hat = ImageTexture.create_from_image(_toned(hat))
	_you_sheet_wide = float(image.get_width())
	var turned := Image.create_from_data(
		image.get_width(), image.get_height(), false, image.get_format(), image.get_data()
	)
	turned.flip_x()
	_you_mirror = ImageTexture.create_from_image(turned)
	for name: String in book["poses"]:
		var frames: Array = []
		for cell: Dictionary in book["poses"][name]:
			var region: Array = cell["region"]
			var ink: Array = cell["ink"]
			frames.append({
				"region": Rect2(region[0], region[1], region[2], region[3]),
				"ink": Rect2(ink[0], ink[1], ink[2], ink[3]),
				"head": float(cell.get("head", 0.0)),
			})
		_you_poses[StringName(name)] = frames

	# What the figure measures inside its cell, taken from one frame and used for every one
	# of them. The cell is mostly air — twelve pixels of character in thirty-two — so scaling
	# a frame to its cell drew the player at a third of the size they should be, which is how
	# they ended up shorter than the dog. Taken once rather than per frame for the same
	# reason player.gd does: the drawing breathes inside its cell, and measuring each frame
	# makes the figure pulse.
	if _you_poses.has(&"idle_front"):
		var first: Dictionary = (_you_poses[&"idle_front"] as Array)[0]
		var ink: Rect2 = first["ink"]
		_you_ink_tall = maxf(ink.size.y, 1.0)
		_you_ink_foot = ink.position.y + ink.size.y


## A copy of the sheet with the game's own light on it. See Style.figure_tone.
##
## Once, at load: the sheet is 192 pixels square and this walks all of it, which is nothing
## done once and would be silly done per frame.
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
	var wall := float(BOARD * ZOOM) * WALL_GROW
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
	if absf(push.x) > 0.001:
		_you_left = push.x < 0.0
	var step := push.normalized() * minf(YOU_SPEED * delta, YOU_STEP_MOST)
	var wanted := _you_at + step
	if _you_may_stand(wanted):
		_you_at = wanted
		return
	if absf(step.x) > 0.0001 and _you_may_stand(_you_at + Vector2(step.x, 0.0)):
		_you_at += Vector2(step.x, 0.0)
	elif absf(step.y) > 0.0001 and _you_may_stand(_you_at + Vector2(0.0, step.y)):
		_you_at += Vector2(0.0, step.y)


## May the player stand here? The floor, the furniture, and the dog.
func _you_may_stand(where: Vector2) -> bool:
	if not _dog_here:
		return _dog_may_stand(where)
	return _clear_of(where, _you_at, _dog_at)


## Which of the three drawn views the player is showing, and whether it wants mirroring.
##
## Flat on rather than projected, so the rule is simply which way the push leaned: mostly
## sideways is the side row, and the rest is the front or the back.
func _you_view() -> Array:
	if absf(_you_facing.x) >= absf(_you_facing.y):
		return [&"side", _you_left]
	return [&"front" if _you_facing.y > 0.0 else &"back", false]


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

	var view := _you_view()
	var walking := _you_step > 0.0
	var pose := StringName("%s_%s" % ["walk" if walking else "idle", view[0]])
	if not _you_poses.has(pose):
		return
	var frames: Array = _you_poses[pose]
	var held := YOU_WALK_FRAME if walking else YOU_IDLE_FRAME
	var frame: Dictionary = frames[posmod(int(_you_age / held), frames.size())]
	var region: Rect2 = frame["region"]
	# Scaled by how tall the figure is inside its cell, not by the cell: the cell is mostly
	# air. Placed by the cell all the same — its foot line on the spot the player stands —
	# so every frame lands where the artist put it and the walk does not bob about.
	#
	# Whole source pixels, like the lake draws them: a fraction of a pixel is what made the
	# angler look out of focus out there, and this room is nothing but blown-up pixel art.
	var scale := maxf(1.0, roundf(tall / _you_ink_tall))
	# What the figure actually comes out as, which is not what was asked for: the scale is
	# snapped to whole pixels, so a request for 49.6 draws 40. Everything hung on the figure is
	# measured against this and not against `tall` — the hat was sized against the request and
	# came out a quarter too wide for the head it sits on, which is why the angler indoors and
	# the angler outdoors were not wearing the same hat.
	var drawn := _you_ink_tall * scale
	var size := region.size * scale
	var box := Rect2(
		at - Vector2(size.x * 0.5, _you_ink_foot * scale), size
	)
	if bool(view[1]):
		draw_texture_rect_region(
			_you_mirror, box,
			Rect2(
				Vector2(_you_sheet_wide - region.position.x - region.size.x, region.position.y),
				region.size
			)
		)
	else:
		draw_texture_rect_region(_you_sheet, box, region)
	_draw_you_hat(box, frame["ink"], float(frame["head"]), scale, drawn, view)


## A length rounded onto the figure's own pixel grid, the same as the lake does it: the hat
## is drawn geometry sitting on blown-up pixel art, and smooth edges on it are what would
## look wrong.
func _on_grid(px: float, scale: float) -> float:
	return roundf(px / scale) * scale


## The straw hat, indoors.
##
## The same picture the lake hangs on the angler, off the same constants, so it is one hat the
## character wears rather than two that have to be kept looking alike. Only the size it is
## measured against changes: Angler.HEIGHT in world pixels out there, and how tall the figure
## is drawn on this floor at this zoom in here.
func _draw_you_hat(
	box: Rect2, ink: Rect2, head_at: float, scale: float, drawn: float, view: Array
) -> void:
	if _you_hat == null:
		return
	var head := box.position.y + ink.position.y * scale
	# Over the head the slicer measured, the same as the lake does it.
	var middle := (
		box.position.x
		+ box.size.x * 0.5
		+ head_at * scale * (-1.0 if bool(view[1]) else 1.0)
	)
	var art := _you_hat.get_size()
	var wide := maxf(scale, _on_grid(drawn * Angler.HAT_WIDE, scale))
	var span := Vector2(wide, _on_grid(wide * art.y / maxf(art.x, 1.0), scale))
	# The same per-view lift the lake gives it, so it is one hat in both places.
	var line := head + _on_grid(drawn * Angler.HAT_SIT, scale) + Angler.lift_of(view) * scale
	draw_texture_rect(
		_you_hat, Rect2(Vector2(middle - span.x * 0.5, line - span.y), span), false
	)


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
func _dog_think() -> void:
	_dog_age = 0.0
	var bed := _bed_cell()
	if bed != Vector2.INF:
		# A bed in the room settles it. It used to be a coin flip each time the dog thought,
		# so a player who had gone and found the bed in the lake and put it out watched the
		# animal mooch about beside it half the afternoon. If there is a bed, the dog is on
		# the bed; the mooching is what a room without one gets.
		if _dog_at.distance_to(bed) <= 0.6:
			_dog_state = &"sleep"
			_dog_mood = DOG_BED_SLEEP
		else:
			_dog_state = &"walk"
			_dog_target = bed
			_dog_mood = DOG_MOOD_MOST
		return
	var roll := _dog_rng.randf()
	_dog_mood = _dog_rng.randf_range(DOG_MOOD_LEAST, DOG_MOOD_MOST)
	if roll < 0.45:
		_dog_state = &"walk"
		_dog_target = _dog_somewhere()
	elif roll < 0.65:
		_dog_state = &"idle"
	elif roll < 0.85:
		_dog_state = &"laid"
	else:
		_dog_state = &"sleep"


## One step towards the target. True once it is there, or once it is stuck.
##
## The step is refused if the cell it would put the dog in is standing on something. Refused
## outright rather than slid along, and then a new target is picked: a dog nosing along the
## side of a wardrobe looking for a way round reads as a bug, where a dog changing its mind
## reads as a dog.
func _dog_walk(delta: float) -> bool:
	var gap := _dog_target - _dog_at
	if gap.length() <= 0.25:
		return true
	var step := gap.normalized() * minf(DOG_SPEED * delta, DOG_STEP_MOST)
	if absf(step.x) > 0.0001:
		_dog_left = step.x < 0.0
	var wanted := _dog_at + step
	if _clear_of(wanted, _dog_at, _you_at):
		_dog_at = wanted
		return _dog_at.distance_to(_dog_target) <= 0.25
	return true


## Somewhere on the floor with nothing on it.
func _dog_somewhere() -> Vector2:
	for _try in 24:
		var where := Vector2(
			_dog_rng.randf_range(1.0, float(COLS) - 1.0),
			_dog_rng.randf_range(1.0, float(ROWS) - 1.0)
		)
		if _dog_may_stand(where):
			return where
	return _dog_at


## May the dog stand with its feet on this cell? Inside the floor, and not on furniture.
func _dog_may_stand(where: Vector2) -> bool:
	if where.x < 0.5 or where.y < 0.5 or where.x > float(COLS) - 0.5 or where.y > float(ROWS) - 0.5:
		return false
	return not _taken().has(Vector2i(int(where.x), int(where.y)))


## The same question, asked by one of the two things that walk about in here, with the other
## one counted as furniture.
##
## Tight, like the rule outdoors: the dog is meant to be able to come and stand beside you,
## and only walking through you is refused. Enforced only on somebody not already inside the
## other — a chair put down on the pair of them, or a dog that padded up while the room was
## being rearranged, must not leave either of them pinned.
func _clear_of(where: Vector2, from: Vector2, other: Vector2) -> bool:
	if not _dog_may_stand(where):
		return false
	if from.distance_to(other) < ROOM_PERSONAL:
		return true
	return where.distance_to(other) >= ROOM_PERSONAL


## Where the pet bed is standing, in cells, or INF for a room without one.
func _bed_cell() -> Vector2:
	for row: Dictionary in decor:
		if StringName(row["piece"]) != DOG_BED:
			continue
		var span := span_of(DOG_BED, _row_view(row))
		return Vector2(
			float(int(row["cell"][0])) + float(span.x) * 0.5,
			float(int(row["cell"][1])) + float(span.y) * 0.5
		)
	return Vector2.INF


## Every cell something is standing on, rebuilt only when the room's contents change.
##
## Rugs are left out on purpose — they are the floor as far as anything walking is concerned
## — and so is the pet bed, which the dog is supposed to end up on top of.
##
## Only the foot of a piece blocks. A bookcase is drawn tall because it is seen from the
## front, but the part of it standing on the boards is the bottom strip; blocking its whole
## picture put an invisible wall in the air behind every piece in the room.
func _taken() -> Dictionary:
	var key := decor.hash()
	if key == _blocked_for:
		return _blocked
	_blocked_for = key
	_blocked = {}
	for row: Dictionary in decor:
		var piece := StringName(row["piece"])
		if piece == DOG_BED or (sheets != null and sheets.lies_flat(piece)):
			continue
		var span := span_of(piece, _row_view(row))
		var cell := Vector2i(int(row["cell"][0]), int(row["cell"][1]))
		var base := mini(BASE_CELLS, span.y)
		for x in span.x:
			for y in base:
				_blocked[cell + Vector2i(x, span.y - 1 - y)] = true
	return _blocked


## The dog, on the floor, at whatever size the room is drawn.
##
## On its own shadow, the way everything else in this game that stands on a surface is: the
## room is drawn flat and a dog with nothing under it hovers over the boards.
func _draw_dog(floor_box: Rect2) -> void:
	if not _dog_here:
		return
	var step := CELL * _zoom()
	var at := floor_box.position + _dog_at * float(step)
	var tall := DOG_TALL * float(step)
	var ring := PackedVector2Array()
	var wide := tall * (0.34 if _dog_state == &"sleep" or _dog_state == &"laid" else 0.44)
	for i in 13:
		var angle := TAU * float(i) / 12.0
		ring.append(at + Vector2(cos(angle) * wide, sin(angle) * wide * 0.42))
	draw_colored_polygon(ring, Color(0.0, 0.0, 0.0, 0.16))
	DogArt.stamp(
		self, _dog_state, DogArt.frame_at(_dog_state, _dog_age), at, tall, _dog_left
	)


## The cross, pinned to the top corner of the inventory column. Worked out from the same
## rectangle the list is drawn in rather than anchored to the control, so the two move
## together when the room is resized and the cross is never left out over the floor.
func _place_close() -> void:
	if _close == null:
		return
	var list := _list_rect()
	_close.size = Vector2(CLOSE_SIDE, CLOSE_SIDE)
	_close.position = Vector2(
		list.end.x - CLOSE_SIDE,
		maxf(list.position.y - CLOSE_SIDE - CLOSE_LIFT, 0.0)
	)


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


## Where a piece would stand, in cells, if it were dropped at this point on screen.
func cell_at(where: Vector2) -> Vector2i:
	var floor_at := where - _floor_origin()
	return Vector2i(
		int(floor(floor_at.x / (CELL * _zoom()))), int(floor(floor_at.y / (CELL * _zoom())))
	)


## How many cells a piece takes up, on this room's grid, in the face it is standing in.
func span_of(piece: StringName, view: int = 0) -> Vector2i:
	return sheets.footprint_view(piece, view, CELL) if sheets != null else Vector2i.ONE


## Which face a row of `decor` is standing in. Rows written before a piece had faces, and
## rows for pieces that only ever had one, read as the first.
func _row_view(row: Dictionary) -> int:
	return int(row.get("view", 0))


## Can this piece stand with its top-left corner in this cell?
##
## The only rule is that it has to be on the floor. Things are deliberately allowed to
## overlap: an armchair belongs on a rug, a lamp belongs beside a table with its base
## tucked under the edge, and a room where nothing may touch anything is a spreadsheet.
## What stops a pile of junk is the drawing order, not a refusal — rugs go down first, and
## everything else is stacked up the room from the back wall.
func can_place(piece: StringName, cell: Vector2i, view: int = 0, _ignore: int = -1) -> bool:
	if sheets == null:
		return false
	var span := span_of(piece, view)
	return cell.x >= 0 and cell.y >= 0 and cell.x + span.x <= COLS and cell.y + span.y <= ROWS


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
		var middle := Vector2(
			float(int(row["cell"][0])) + float(span.x) * 0.5,
			float(int(row["cell"][1])) + float(span.y)
		)
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
	if key.keycode == KEY_R:
		turn_carried()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_E and switch_near():
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		_pointer = motion.position
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
	if wheel.pressed:
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
		return
	var from_list := _listed_at(_pointer)
	if not from_list.is_empty():
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
	if _over_floor(_pointer):
		place(piece, _drop_cell(piece, view), view)
	else:
		# Back to the store, which is where anything not on the floor already is.
		changed.emit()


## The cell a dragged piece would land in: the piece is carried by its middle, which is
## where the cursor holds it, so the corner is half its span up and left of that.
func _drop_cell(piece: StringName, view: int = 0) -> Vector2i:
	var span := span_of(piece, view)
	var middle := cell_at(_pointer)
	return middle - Vector2i(span.x / 2, span.y / 2)


func _scroll_by(amount: float) -> void:
	var rows := in_store().size()
	var span := maxf(float(rows * ROW_HEIGHT) - (size.y - 96.0), 0.0)
	_scroll = clampf(_scroll + amount, 0.0, span)
	queue_redraw()


## Which placed item is under a point, as an index into `decor`, or -1. Walked backwards so
## the item drawn on top is the one picked up.
func _placed_at(where: Vector2) -> int:
	if sheets == null or not _over_floor(where):
		return -1
	# Topmost first, which is the order they are drawn in reverse: what the player can see
	# is what they get hold of, and a rug under a table is not what they are pointing at.
	var cell := cell_at(where)
	var order := _stacking()
	for at_index in range(order.size() - 1, -1, -1):
		var i: int = order[at_index]
		var row: Dictionary = decor[i]
		var at := Vector2i(int(row["cell"][0]), int(row["cell"][1]))
		if Rect2i(at, span_of(StringName(row["piece"]), _row_view(row))).has_point(cell):
			return i
	return -1


## The order things are drawn in: rugs and mats first, then everything else from the back
## of the room forward, so a chair standing in front of a table overlaps it.
func _stacking() -> Array:
	var order := range(decor.size())
	order.sort_custom(
		func(a: int, b: int) -> bool:
			var piece_a := StringName(decor[a]["piece"])
			var piece_b := StringName(decor[b]["piece"])
			var flat_a := sheets.lies_flat(piece_a)
			var flat_b := sheets.lies_flat(piece_b)
			if flat_a != flat_b:
				return flat_a
			var foot_a: int = int(decor[a]["cell"][1]) + span_of(piece_a, _row_view(decor[a])).y
			var foot_b: int = int(decor[b]["cell"][1]) + span_of(piece_b, _row_view(decor[b])).y
			return foot_a < foot_b
	)
	return order


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


func _over_floor(where: Vector2) -> bool:
	return _floor_rect().has_point(where)


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
	var room := _room_rect()
	var fit := mini(
		int(room.size.x) / (COLS * CELL), int(room.size.y) / (ROWS * CELL)
	)
	return float(clampi(fit, 1, ZOOM_MOST))


## Everything the room may draw into: the control, less the strip along the top the back
## wall stands in, less the inventory column down the right.
##
## The wall used to be drawn at a negative y, above the control's own top edge, where it
## covered the two labels above it in the panel. A Control that draws outside itself cannot
## be laid out beside anything, so the wall is given room here instead.
func _room_rect() -> Rect2:
	var wall := float(BOARD * ZOOM) * WALL_GROW
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
	var floor_box := _floor_rect()
	return Rect2(
		Vector2(floor_box.end.x + GUTTER, floor_box.position.y),
		Vector2(float(LIST_WIDTH), floor_box.size.y)
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
	var ink := Color(0.11, 0.09, 0.1)

	var floor_box := _floor_rect()

	# The room: a back wall standing above the floor, so the space has a direction and the
	# furniture has something to be against. Wallpapered, not flat.
	var wall_tall := float(BOARD * ZOOM) * WALL_GROW
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

	# The cells, faintly, while something is being carried: the drop is snapped, and the
	# player should be able to see what it is snapping to.
	if not carrying.is_empty():
		for col in range(1, COLS):
			var x := floor_box.position.x + float(col) * CELL * _zoom()
			draw_line(
				Vector2(x, floor_box.position.y), Vector2(x, floor_box.end.y),
				Color(1.0, 1.0, 1.0, 0.05), 1.0
			)
		for row_line in range(1, ROWS):
			var y := floor_box.position.y + float(row_line) * CELL * _zoom()
			draw_line(
				Vector2(floor_box.position.x, y), Vector2(floor_box.end.x, y),
				Color(1.0, 1.0, 1.0, 0.05), 1.0
			)

	# What the lit pieces throw on the boards. Under the furniture, so a fire washes the
	# floor in front of the hearth rather than painting over the hearth itself.
	_draw_glows(floor_box)

	# What is in the room, laid down before it is stood on. The dog goes in among them
	# rather than over the lot: it is drawn the moment the room reaches something standing
	# further back than the dog is, so it passes behind a wardrobe and in front of a chair
	# instead of sliding over both.
	var dog_drawn := not _dog_here
	var dog_foot := _dog_at.y
	# The player is sorted into the room the same way the dog is, by whose feet are further
	# down the floor. Two of them now, so the test is written once and asked twice.
	var you_drawn := _you_sheet == null
	for i: int in _stacking():
		var row: Dictionary = decor[i]
		var piece := StringName(row["piece"])
		# The bed is the exception: a dog asleep in its own basket is in the basket, so the
		# basket goes down first and the dog on top of it, whatever the feet say.
		var own_bed := piece == DOG_BED and _dog_at.distance_to(_bed_cell()) <= 1.2
		if not dog_drawn and not own_bed and not sheets.lies_flat(piece):
			var foot := float(int(row["cell"][1]) + span_of(piece, _row_view(row)).y)
			if foot > dog_foot:
				_draw_dog(floor_box)
				dog_drawn = true
		if not you_drawn and not sheets.lies_flat(piece):
			var stands := float(int(row["cell"][1]) + span_of(piece, _row_view(row)).y)
			if stands > _you_at.y:
				_draw_you(floor_box)
				you_drawn = true
		_stamp_piece(
			piece,
			floor_box.position + Vector2(
				float(int(row["cell"][0])) * CELL * _zoom(),
				float(int(row["cell"][1])) * CELL * _zoom()
			),
			_row_view(row)
		)
	if not dog_drawn:
		_draw_dog(floor_box)
	if not you_drawn:
		_draw_you(floor_box)

	_draw_prompt(floor_box)
	_draw_list(ink)

	# The piece in hand, under the cursor, tinted by whether it can go where it is.
	if not carrying.is_empty():
		var span := span_of(carrying, _carry_view)
		if _over_floor(_pointer):
			var cell := _drop_cell(carrying, _carry_view)
			var fits := can_place(carrying, cell, _carry_view)
			var at := floor_box.position + Vector2(
				float(cell.x) * CELL * _zoom(), float(cell.y) * CELL * _zoom()
			)
			draw_rect(
				Rect2(at, Vector2(span) * CELL * _zoom()),
				Color(Style.SAFE.r, Style.SAFE.g, Style.SAFE.b, 0.20) if fits
				else Color(Style.DANGER.r, Style.DANGER.g, Style.DANGER.b, 0.20)
			)
			_stamp_piece(
				carrying, at, _carry_view, Color(1.0, 1.0, 1.0, 0.85 if fits else 0.5)
			)
		else:
			_stamp_piece(
				carrying,
				_pointer - sheets.view_region_of(carrying, _carry_view).size * _zoom() * 0.5,
				_carry_view,
				Color(1.0, 1.0, 1.0, 0.75)
			)


## The store down the right: everything found and not yet standing anywhere.
func _draw_list(ink: Color) -> void:
	var list := _list_rect()
	# Faded back while something is being carried, so the floor under it can be seen and
	# aimed at. It is still there to drop onto; it is just no longer in front.
	var lit := LIST_BUSY if not carrying.is_empty() else 1.0
	draw_rect(list.grow(8.0), Style.scrim(Style.SCRIM * lit))
	draw_rect(list.grow(8.0), Color(ink.r, ink.g, ink.b, ink.a * lit), false, 1.5)

	var store := in_store()
	Style.write(
		self,
		"Shed inventory  (%d)" % store.size(),
		Style.TEXT_SMALL,
		list.position + Vector2(4.0, -10.0),
		Style.INK,
		HORIZONTAL_ALIGNMENT_LEFT,
		Rect2(),
		lit
	)
	if store.is_empty():
		Style.write(
			self,
			"Nothing kept yet.",
			Style.TEXT_SMALL,
			list.position + Vector2(8.0, 28.0),
			Style.INK_DIM,
			HORIZONTAL_ALIGNMENT_LEFT,
			Rect2(),
			lit
		)
		return

	for i in store.size():
		var top := list.position.y + float(i * ROW_HEIGHT) - _scroll
		# Whole rows only. A row that starts inside the column and ends outside it used to be
		# drawn in full, so the last one hung below the panel with its name in mid-air.
		if top < list.position.y or top + float(ROW_HEIGHT) > list.end.y:
			continue
		var box := Rect2(list.position.x, top, list.size.x, float(ROW_HEIGHT) - 4.0)
		draw_rect(box, Color(Style.WOOD_LIT.r, Style.WOOD_LIT.g, Style.WOOD_LIT.b, 0.10 * lit))
		var region := sheets.alt_region_of(StringName(store[i]))
		# Fitted into the row rather than drawn at its own size: a wardrobe and a mug both
		# have to read as one line of a list.
		var fit := minf(
			(float(ROW_HEIGHT) - 12.0) / maxf(region.size.x, region.size.y), _zoom()
		)
		draw_texture_rect_region(
			sheets.atlas,
			Rect2(box.position + Vector2(8.0, 6.0), region.size * fit), region,
			Color(1.0, 1.0, 1.0, lit)
		)
		var title := title_of(store[i])
		if not title.is_empty():
			Style.write(
				self,
				title,
				Style.TEXT_SMALL,
				box.position + Vector2(64.0, 30.0),
				Style.INK,
				HORIZONTAL_ALIGNMENT_LEFT,
				Rect2(),
				lit
			)


## The light a switched-on piece spills onto the room.
##
## Three flat circles of a low-alpha colour, largest first. A real falloff wants a gradient
## texture or a shader and this is a lamp in a shed: the rings land close enough that the
## eye reads warmth coming off the hearth, which is the whole job.
func _draw_glows(floor_box: Rect2) -> void:
	if sheets == null:
		return
	for row: Dictionary in decor:
		var piece := StringName(row["piece"])
		if not sheets.switchable(piece) or _row_view(row) != STATE_ON:
			continue
		var tint := FIRE_GLOW
		var reach := FIRE_REACH
		if sheets.role_of(piece, _row_view(row)) == &"open":
			tint = FRIDGE_GLOW
			reach = FRIDGE_REACH
		var span := span_of(piece, _row_view(row))
		var middle := floor_box.position + Vector2(
			(float(int(row["cell"][0])) + float(span.x) * 0.5) * CELL * _zoom(),
			(float(int(row["cell"][1])) + float(span.y)) * CELL * _zoom()
		)
		for ring in GLOW_RINGS:
			var out := reach * CELL * _zoom() * (1.0 - float(ring) / float(GLOW_RINGS + 1))
			draw_circle(middle, out, tint)


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
		(float(int(row["cell"][0])) + float(span.x) * 0.5) * CELL * _zoom(),
		float(int(row["cell"][1])) * CELL * _zoom() - PROMPT_LIFT
	)
	var side := 18.0
	var box := Rect2(over - Vector2(side, side) * 0.5, Vector2(side, side))
	draw_rect(box, Color(Style.WOOD.r, Style.WOOD.g, Style.WOOD.b, 0.85))
	draw_rect(box, Style.INK_DIM, false, 1.0)
	Style.write(
		self, "E", Style.TEXT_SMALL, box.position + Vector2(5.0, 14.0), Style.INK
	)


## One piece of furniture, in its cleaned-up palette, standing with its corner at a point,
## in whichever face it is turned to.
func _stamp_piece(
	piece: StringName, at: Vector2, view: int = 0, tint: Color = Color.WHITE
) -> void:
	var region := sheets.view_region_of(piece, view)
	draw_texture_rect_region(
		sheets.atlas, Rect2(at, region.size * _zoom()), region, tint
	)
