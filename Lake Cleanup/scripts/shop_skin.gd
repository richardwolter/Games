## The upgrades boards: the drawn shop, three boards side by side.
##
## One board each for the net, the ferry and the dog, so the shop reads as three things
## with prices on them rather than one list of eleven buttons. Everything is drawn here
## from `Style` — the frames, the ribbons, the rows, the tags — in the pollution meter's own
## colours (`Style.BOARD*`, murky water on oak); the painted shop sheet this replaced was a picture of one board with five rows
## and had to be papered over for every row it was not drawn with.
##
## The lake owns what an upgrade is and what it costs; this owns where it sits and what it
## looks like, and says which one was clicked. Same split as the HUD skin.
class_name ShopSkin
extends Control

const Style := preload("res://scripts/style.gd")
const DogArt := preload("res://scripts/dog_art.gd")

## The boards, in the order they stand, and what each is called.
const BOARDS: Array[StringName] = [&"net", &"boat", &"dog"]
const TITLES := {&"net": "The net", &"boat": "The ferry", &"dog": "The dog"}

## How tall a row is drawn, and how short it may be squeezed to before a board gives up
## and drops one. A board grows a row at a time until it is as tall as the window allows,
## and then the rows themselves have to give: a shop that quietly stops drawing its last two
## upgrades — which is what a fixed row height did the day the dog got two of its own — is
## worse than a shop drawn slightly tighter. Two lines tall, because a row's name sits over
## its value: three boards across a window leave no room for them side by side.
const ROW_TALL := 50.0
const ROW_LEAST := 40.0
const ROW_GAP := 6.0

## The three boards together, and the gap between them. Sized in the 1280-wide design
## frame; a narrower window shrinks all three alike.
const BOARDS_WIDE := 900.0
const BOARD_GAP := 44.0
const BOARD_PAD := 14.0

## The oak round each board, cut like the meter's frame: grain lines along each plank
## (`GRAIN_EVERY` apart, `GRAIN_LONG` at most) and a few chips out of the outer edge
## (`CHIPS` a side). The ribbon and sprite sit at the head of it. The sprite is the
## thing being sold — the net, the ferry, the dog — and the ribbon names it.
const FRAME := 12.0
const GRAIN_EVERY := 7.0
const GRAIN_LONG := 26.0
const CHIPS := 3
const RIBBON_TALL := 36.0
const RIBBON_OVERHANG := 10.0
## How much of its slot each board's sprite fills. The net is a wide flat thing and fills
## the slot at 0.7; the ferry is a small square frame with air round the hull and needs
## more than the slot to come out the size of the dog beside it.
const SPRITE_FILL := {&"net": 0.7, &"boat": 1.35, &"dog": 0.8}

## The ferry on its board is under way: the bow wake it leaves in the lake runs beside it
## and the hull bobs a couple of pixels on a slow swell. The wake is laid exactly as the
## lake lays it — the lake lends the heading, lift and size with the frame, in the frame's
## own pixels, and the board scales them with the picture.
const BOB_PX := 2.0
const BOB_HZ := 0.4

## A faint white halo behind every head, so a black net and a dark hull read against a
## dark board: stepped ellipses, outermost first, each `HALO_ALPHA` white, the outer one
## the picture grown by `HALO_GROW`.
const HALO_ALPHA := [0.006, 0.011, 0.017]
const HALO_GROW := 0.34

## The net on its board is thrown over a catch: drawn black, so the rubbish the lake lends
## (`sprites[&"catch"]`, a list of `{sheet, region}`) shows through the mesh. Where each
## piece lies, as a fraction of the net's drawn size from its middle, and how big.
const NET_INK := Color(0.08, 0.07, 0.07, 0.92)

## The net on the water wanders a pixel or two, as a floating piece does, and wears the
## lake's foam collar where it cuts the surface — how far it wanders, how fast, and where
## across the picture the waterline runs (a fraction of its height from the top).
const NET_SWAY := Vector2(2.0, 1.0)
const NET_SWAY_HZ := Vector2(0.084, 0.065)
const NET_WATERLINE := 0.78
const NET_COLLAR := 0.86
const CATCH_AT := [Vector2(-0.22, 0.05), Vector2(0.08, -0.12), Vector2(0.24, 0.14)]
const CATCH_SCALE := 2.0

## The dog on its board is the dog: it rolls idle or asleep each time the shop opens and
## plays that loop while it is up. Even odds.
const DOG_SLEEP_ODDS := 0.5

## One step cut off each corner of a row and a tag — the pixel-art round corner.
const CLIP := 3.0
const SPRITE_TALL := 68.0
const HEAD_GAP := 8.0

## How much of a row the price tag may take.
const TAG_SHARE := 0.34

const CLOSE_SIZE := 34.0

## How long the sparkle over a bought board's sprite lasts, how far it reaches, and how
## many points it is made of. Short and small on purpose: it is a receipt for a click the
## player already made, not an event.
const SPARKLE_TIME := 0.7
const SPARKLE_RISE := 40.0
const SPARKLE_POINTS := 7


## Emitted when a row is clicked and the player can afford it. The lake decides what
## happens; this does not know what an upgrade is.
signal bought(key: StringName)

## The player asking to be out of here: the corner cross, or a click on the table around
## the boards. Both mean the same thing and the lake decides what to do about it.
signal close_asked

## The rows to draw, newest set every frame by the lake. Each is
## `{key, board, name, value, cost, afford}` — `board` is one of BOARDS.
var rows: Array = []

## The picture at the head of the net and ferry boards, by board name, each `{sheet,
## region}`. Lent by the lake, which already has the ferry's baked hull and the net. The
## dog draws itself through DogArt.
var sprites := {}

## Where each board stands this frame, by board name, and the whole span they cover.
var _boards := {}
var _table := Rect2()

## How tall a row is on the boards as they stand, which is ROW_TALL until the longest
## board has more rows than the window has height for.
var _row_tall: float = ROW_TALL
var _laid_rows: int = -1

## Every drawn row's box and which entry in `rows` it is.
var _row_boxes: Array[Rect2] = []
var _row_index: Array[int] = []
var _hovered: int = -1

## The ferry's wake and the hull over it. Both are nodes rather than this control's own
## drawing: HullFoam is a Node2D with a shader, and a child of a Control draws after the
## Control — so the board face is painted here, then the wake, then the hull on top.
## (HullFoam sets itself behind its parent, which under a boat is right and under a board
## would bury it; the shop puts it back in front.)
var _wake: HullFoam
var _hull: Sprite2D
var _wake_heading := Vector2.RIGHT

## The net's foam collar, the net over it, and where the swell has them this frame. The
## net is a node for the same reason the hull is: the collar has to lie under the mesh,
## and a child draws after this control, so the mesh must be a later child still.
var _collar: WaterlineFoam
var _mesh: Sprite2D
var _sway_px := Vector2i.ZERO
var _bob_age: float = 0.0
var _bob_px: int = 0

## The dog's pose this opening, how long it has been in it, and the frame last drawn.
var _dog_pose: StringName = &"idle"
var _dog_age: float = 0.0
var _dog_frame: int = -1

## The board whose upgrade has just been bought, and how long the sparkle over its sprite
## has left to run.
var _sparkling: StringName = &""
var _sparkle: float = 0.0

## What the last painted boards were made of: the rows' own contents and whatever the
## mouse is over.
var _painted: int = 0

## The cross in the top corner. Made here rather than put in the scene because it is hung
## off the boards' own rectangle, and only this knows where that is.
var _close: CloseButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_close = CloseButton.new()
	_close.pressed.connect(func() -> void: close_asked.emit())
	add_child(_close)
	resized.connect(_lay_out)
	visibility_changed.connect(_on_shown)
	_wake = HullFoam.new()
	_wake.z_index = 0
	_wake.visible = false
	add_child(_wake)
	_hull = Sprite2D.new()
	_hull.region_enabled = true
	_hull.centered = false
	_hull.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hull.visible = false
	add_child(_hull)
	_collar = WaterlineFoam.new()
	_collar.z_index = 0
	_collar.visible = false
	add_child(_collar)
	_mesh = Sprite2D.new()
	_mesh.region_enabled = true
	_mesh.centered = false
	_mesh.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mesh.modulate = NET_INK
	_mesh.visible = false
	add_child(_mesh)
	_lay_out()


## Each time the shop comes up, the dog rolls whether it is awake.
func _on_shown() -> void:
	if not visible:
		return
	_dog_pose = &"sleep" if randf() < DOG_SLEEP_ODDS and DogArt.has(&"sleep") else &"idle"
	_dog_age = 0.0
	_dog_frame = -1
	_bob_age = 0.0
	set_process(true)


## Light up the sprite of the board whose upgrade has just been bought. Called by the lake
## when a purchase actually lands, so a click that could not be afforded sparkles at nobody.
func cheer(key: StringName) -> void:
	_sparkling = _board_of(key)
	_sparkle = SPARKLE_TIME
	set_process(true)
	queue_redraw()


func _board_of(key: StringName) -> StringName:
	for row: Dictionary in rows:
		if StringName(row.get("key", "")) == key:
			return StringName(row.get("board", ""))
	return &""


func _count(board: StringName) -> int:
	var n := 0
	for row: Dictionary in rows:
		if StringName(row.get("board", "")) == board:
			n += 1
	return n


## The head of a board: frame, ribbon, sprite and their gaps, above the first row.
func _head_tall() -> float:
	return FRAME + RIBBON_TALL * 0.5 + BOARD_PAD + SPRITE_TALL + HEAD_GAP


## The three boards in a row, each as tall as its rows come to, tops aligned.
##
## Sized to the content rather than to the window: the dog's board has two rows and is
## two rows tall, the net's five and five. The tallest of them decides how tall a row may
## be, so a squeeze lands on all three alike and the rows still line up across them.
func _lay_out() -> void:
	var most := 1
	for board in BOARDS:
		most = maxi(most, _count(board))
	var spare := _head_tall() + float(most - 1) * ROW_GAP + BOARD_PAD + FRAME
	var room := (size.y - 40.0 - spare) / float(most)
	_row_tall = clampf(room, ROW_LEAST, ROW_TALL)
	var tallest := minf(spare + float(most) * _row_tall, size.y - 40.0)

	var wide := minf(BOARDS_WIDE, size.x - 40.0)
	var each := (wide - BOARD_GAP * float(BOARDS.size() - 1)) / float(BOARDS.size())
	var top := floorf((size.y - tallest) * 0.5)
	var left := floorf((size.x - wide) * 0.5)
	_table = Rect2(left, top, wide, tallest)
	_boards.clear()
	for i in BOARDS.size():
		var count := maxi(_count(BOARDS[i]), 1)
		var tall := minf(
			_head_tall() + float(count) * _row_tall + float(count - 1) * ROW_GAP
			+ BOARD_PAD + FRAME,
			tallest
		)
		_boards[BOARDS[i]] = Rect2(
			floorf(left + (each + BOARD_GAP) * float(i)), top, floorf(each), tall
		)
	if _close != null:
		# Just outside the top right corner of the last board, where a window's close is,
		# clear of that board's ribbon.
		_close.position = Vector2(_table.end.x - CLOSE_SIZE, _table.position.y - CLOSE_SIZE - 4.0)
		_close.size = Vector2(CLOSE_SIZE, CLOSE_SIZE)
	queue_redraw()


func _process(delta: float) -> void:
	if visible:
		_bob_age += delta
		var bob := roundi(sin(_bob_age * TAU * BOB_HZ) * BOB_PX)
		if bob != _bob_px:
			_bob_px = bob
			queue_redraw()
		var sway := Vector2i(
			roundi(sin(_bob_age * TAU * NET_SWAY_HZ.x) * NET_SWAY.x),
			roundi(cos(_bob_age * TAU * NET_SWAY_HZ.y) * NET_SWAY.y)
		)
		if sway != _sway_px:
			_sway_px = sway
			queue_redraw()
		_wake.lay(_wake_heading, 1.0, delta)
	_dog_age += delta
	var frame := DogArt.frame_at(_dog_pose, _dog_age)
	if frame != _dog_frame:
		_dog_frame = frame
		queue_redraw()
	if _sparkle > 0.0:
		_sparkle = maxf(_sparkle - delta, 0.0)
		if _sparkle <= 0.0:
			_sparkling = &""
		queue_redraw()
	# The rows are set from outside, and how many there are is what the boards are sized by.
	if _laid_rows != rows.size():
		_laid_rows = rows.size()
		_lay_out()
	# Only when the boards would come out different. The lake hands over a fresh `rows`
	# every frame the menu is open, but its contents only change when a level or the purse
	# does — and repainting eleven priced rows to put back the same eleven prices is the
	# most expensive way to do nothing.
	if _painted != _paint_key():
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var was := _hovered
		_hovered = _row_under((event as InputEventMouseMotion).position)
		if was != _hovered:
			queue_redraw()
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var index := _row_under(click.position)
	if index < 0 or index >= rows.size():
		# Anywhere off the boards is the way out: the boards are things on a table, and
		# clicking the table puts them down.
		if not _on_a_board(click.position):
			accept_event()
			close_asked.emit()
		return
	accept_event()
	var row: Dictionary = rows[index]
	if bool(row.get("afford", false)):
		bought.emit(StringName(row["key"]))


func _on_a_board(at: Vector2) -> bool:
	for board: StringName in _boards:
		if (_boards[board] as Rect2).grow(RIBBON_OVERHANG).has_point(at):
			return true
	return false


## Which entry in `rows` is under the pointer, or -1.
func _row_under(at: Vector2) -> int:
	for i in _row_boxes.size():
		if _row_boxes[i].has_point(at):
			return _row_index[i]
	return -1


func _paint_key() -> int:
	return hash([rows.hash(), _hovered, roundi(_sparkle * 120.0), _dog_frame])


func _draw() -> void:
	_painted = _paint_key()
	if _table.size.x <= 0.0:
		return
	# Everything behind the boards dimmed, so they are things in front of the lake rather
	# than stickers on it.
	Style.dim(self, Rect2(Vector2.ZERO, size), Style.SCRIM)
	_row_boxes.clear()
	_row_index.clear()
	for board in BOARDS:
		_draw_board(board, _boards[board])


## One board: oak frame, clean-water face, ribbon over the top edge, the sprite, the rows.
func _draw_board(board: StringName, box: Rect2) -> void:
	_draw_frame(box)
	var face := box.grow(-FRAME)
	draw_rect(face.grow(1.0), Style.SEAM, true)
	draw_rect(face, Style.BOARD, true)

	# The ribbon, hung over the top of the frame and a little wider than the board, the
	# way the old painted one was. Its ends are notched like the meter's frame.
	var ribbon := Rect2(
		Vector2(box.position.x - RIBBON_OVERHANG, box.position.y - RIBBON_TALL * 0.5),
		Vector2(box.size.x + RIBBON_OVERHANG * 2.0, RIBBON_TALL)
	)
	_draw_ribbon(ribbon, String(TITLES.get(board, "")))

	# The sprite, fitted into its slot at its own proportions.
	var slot := Rect2(
		Vector2(face.position.x, box.position.y + RIBBON_TALL * 0.5 + BOARD_PAD),
		Vector2(face.size.x, SPRITE_TALL)
	)
	_draw_sprite(board, slot)
	if _sparkle > 0.0 and board == _sparkling:
		_draw_sparkle(slot)

	# The rows.
	var left := face.position.x + BOARD_PAD
	var wide := face.size.x - BOARD_PAD * 2.0
	var top := slot.end.y + HEAD_GAP
	var n := 0
	for i in rows.size():
		var row: Dictionary = rows[i]
		if StringName(row.get("board", "")) != board:
			continue
		var line := Rect2(left, top + (_row_tall + ROW_GAP) * float(n), wide, _row_tall)
		n += 1
		if line.end.y > face.end.y - BOARD_PAD + 1.0:
			break
		_row_boxes.append(line)
		_row_index.append(i)
		_draw_row(row, line, _hovered == i)


## The oak frame, as the meter's is drawn: a dark seam, the plank, a lit top and left
## edge, a shaded bottom and right, grain along each side, and chips out of the outer edge.
func _draw_frame(box: Rect2) -> void:
	draw_rect(box.grow(1.0), Style.SEAM, true)
	draw_rect(box, Style.FRAME, true)
	draw_rect(Rect2(box.position, Vector2(box.size.x, 2.0)), Style.FRAME_LIT, true)
	draw_rect(Rect2(box.position, Vector2(2.0, box.size.y)), Style.FRAME_LIT, true)
	draw_rect(
		Rect2(Vector2(box.position.x, box.end.y - 2.0), Vector2(box.size.x, 2.0)),
		Style.FRAME_DEEP, true
	)
	draw_rect(
		Rect2(Vector2(box.end.x - 2.0, box.position.y), Vector2(2.0, box.size.y)),
		Style.FRAME_DEEP, true
	)
	# Grain: short dark strokes running the length of each plank, staggered by a hash of
	# where they are so the four sides do not repeat each other.
	var seed := int(box.position.x) * 31 + int(box.position.y) * 17
	_grain(Rect2(box.position, Vector2(box.size.x, FRAME)), true, seed)
	_grain(Rect2(Vector2(box.position.x, box.end.y - FRAME), Vector2(box.size.x, FRAME)), true, seed + 1)
	_grain(Rect2(box.position, Vector2(FRAME, box.size.y)), false, seed + 2)
	_grain(Rect2(Vector2(box.end.x - FRAME, box.position.y), Vector2(FRAME, box.size.y)), false, seed + 3)
	# Chips: small bites out of the outer edge, dark where the wood is gone.
	for i in CHIPS:
		var along := (float(i) + 0.5 + 0.3 * float(hash(seed + i) % 5) / 5.0) / float(CHIPS)
		var wide := 6.0 + 2.0 * float(hash(seed * 3 + i) % 3)
		var deep := 3.0 + float(hash(seed * 5 + i) % 3)
		var y := box.position.y + box.size.y * along
		var x := box.position.x + box.size.x * (1.0 - along)
		_chip(Rect2(box.position.x - 1.0, y, deep, wide))
		_chip(Rect2(box.end.x + 1.0 - deep, y - wide * 0.4, deep, wide))
		if i % 2 == 0:
			_chip(Rect2(x, box.position.y - 1.0, wide, deep))
			_chip(Rect2(x - wide * 0.6, box.end.y + 1.0 - deep, wide, deep))


func _grain(plank: Rect2, across: bool, seed: int, deep: float = FRAME) -> void:
	var length := plank.size.x if across else plank.size.y
	var n := int(length / GRAIN_EVERY)
	for i in n:
		var h := hash(seed * 131 + i)
		if h % 3 == 0:
			continue
		var at := (float(i) + 0.15 + 0.7 * float(h % 7) / 7.0) * GRAIN_EVERY
		var run := 6.0 + float(h % 100) / 100.0 * (GRAIN_LONG - 6.0)
		var lane := 2.5 + float((h / 7) % int(deep - 5.0))
		var start: Vector2
		var stop: Vector2
		if across:
			start = plank.position + Vector2(at, lane)
			stop = Vector2(minf(start.x + run, plank.end.x - 2.0), start.y)
		else:
			start = plank.position + Vector2(lane, at)
			stop = Vector2(start.x, minf(start.y + run, plank.end.y - 2.0))
		draw_line(start, stop, Style.FRAME_GRAIN, 1.0)
		if h % 4 == 0:
			draw_line(start + Vector2(0.0, 1.0) if across else start + Vector2(1.0, 0.0),
				stop + Vector2(0.0, 1.0) if across else stop + Vector2(1.0, 0.0),
				Style.FRAME_LIT, 1.0)


## One bite out of the frame: the wood gone to a dark hollow with a lit lip.
func _chip(box: Rect2) -> void:
	draw_rect(box, Style.scrim(Style.SCRIM_HEAVY), true)
	draw_rect(box.grow(-1.0), Style.SEAM, true)


func _draw_ribbon(box: Rect2, title: String) -> void:
	# A plank of the same oak as the frame, over the top edge of it: seam, face, lit top
	# and left, shaded bottom and right, grain along it, chips out of its edges. Cloth was
	# tried — a bowed three-tone band, then one with tails — and read as a sticker.
	draw_rect(box.grow(1.0), Style.SEAM, true)
	draw_rect(box, Style.FRAME, true)
	draw_rect(Rect2(box.position, Vector2(box.size.x, 2.0)), Style.FRAME_LIT, true)
	draw_rect(Rect2(box.position, Vector2(2.0, box.size.y)), Style.FRAME_LIT, true)
	draw_rect(
		Rect2(Vector2(box.position.x, box.end.y - 2.0), Vector2(box.size.x, 2.0)),
		Style.FRAME_DEEP, true
	)
	draw_rect(
		Rect2(Vector2(box.end.x - 2.0, box.position.y), Vector2(2.0, box.size.y)),
		Style.FRAME_DEEP, true
	)
	var seed := int(box.position.x) * 53 + int(box.position.y) * 29 + 7
	_grain(box, true, seed, box.size.y)
	# Chips out of the top and bottom edges and one out of each end.
	for i in CHIPS:
		var along := (float(i) + 0.5 + 0.3 * float(hash(seed + i) % 5) / 5.0) / float(CHIPS)
		var wide := 6.0 + 2.0 * float(hash(seed * 3 + i) % 3)
		var deep := 3.0 + float(hash(seed * 5 + i) % 3)
		var x := box.position.x + box.size.x * along
		_chip(Rect2(x, box.position.y - 1.0, wide, deep))
		_chip(Rect2(box.end.x - box.size.x * along - wide * 0.6, box.end.y + 1.0 - deep, wide, deep))
	var y := box.position.y + box.size.y * 0.4
	_chip(Rect2(box.position.x - 1.0, y, 4.0, 8.0))
	_chip(Rect2(box.end.x - 3.0, y + 6.0, 4.0, 8.0))

	Style.write(
		self, title, Style.TEXT_HEAD,
		Vector2(0.0, box.position.y + (box.size.y + float(Style.TEXT_HEAD) * 0.62) * 0.5),
		Style.RIBBON_INK, HORIZONTAL_ALIGNMENT_CENTER, box
	)


func _draw_sprite(board: StringName, slot: Rect2) -> void:
	var fill := float(SPRITE_FILL.get(board, 1.0))
	var middle := slot.position + slot.size * 0.5
	if board == &"dog" and DogArt.has(_dog_pose):
		# Standing height is the slot's; the sleeper keeps its own proportion to that.
		var tall := slot.size.y * fill
		var span := DogArt.span(_dog_pose, tall)
		var foot := Vector2(middle.x, slot.end.y - (slot.size.y - span.y) * 0.5)
		_halo(Rect2(foot - Vector2(span.x * 0.5, span.y), span))
		DogArt.stamp(self, _dog_pose, DogArt.frame_at(_dog_pose, _dog_age), foot, tall, true)
		return
	var lent: Dictionary = sprites.get(board, {})
	var sheet: Texture2D = lent.get("sheet")
	if sheet == null:
		if board == &"boat":
			_wake.visible = false
			_hull.visible = false
		elif board == &"net":
			_collar.visible = false
			_mesh.visible = false
		return
	var region: Rect2 = lent["region"]
	var scale := minf(slot.size.x / region.size.x, slot.size.y / region.size.y) * fill
	var drawn := region.size * scale
	# Never wider than the slot: the ferry's over-fill is for its baked-in margin, not for
	# running into the frame.
	if drawn.x > slot.size.x:
		drawn *= slot.size.x / drawn.x
	var box := Rect2(middle - drawn * 0.5, drawn)
	_halo(box)
	match board:
		&"boat":
			box.position.y += float(_bob_px)
			# The wake is a node of its own; it is placed under the hull here, where the
			# hull is known, at the lake's own geometry scaled to the drawn frame.
			var to_drawn := drawn.y / maxf(float(lent.get("frame", region.size.y)), 1.0)
			_wake.position = box.position + box.size * 0.5 + Vector2(0.0, float(lent.get("lift", 0.0)) * to_drawn)
			_wake.half_length = float(lent.get("half_length", region.size.x * 0.5)) * to_drawn
			_wake.half_width = float(lent.get("half_width", region.size.x * 0.2)) * to_drawn
			_wake_heading = lent.get("heading", Vector2.RIGHT)
			_wake.visible = visible
			_hull.texture = sheet
			_hull.region_rect = region
			_hull.position = box.position
			_hull.scale = box.size / region.size
			_hull.visible = visible
		&"net":
			# The net and its catch ride the swell together; the collar is a node of its
			# own laid on the waterline across the picture, drawn after the board face.
			box.position += Vector2(_sway_px)
			var here := middle + Vector2(_sway_px)
			var cut_y := box.position.y + box.size.y * NET_WATERLINE
			var half := box.size.x * NET_COLLAR * 0.5
			_collar.position = Vector2(here.x, cut_y)
			_collar.lay(Vector2(-half, 0.0), Vector2(half, 0.0))
			_collar.visible = visible
			# The catch here, under everything; then the collar; then the net, black, over
			# both, so the foam is round the mesh and not across it.
			for i in mini(CATCH_AT.size(), (sprites.get(&"catch", []) as Array).size()):
				var piece: Dictionary = sprites[&"catch"][i]
				var art: Rect2 = piece["region"]
				var size := art.size * CATCH_SCALE
				var at := here + (CATCH_AT[i] as Vector2) * drawn - size * 0.5
				draw_texture_rect_region(piece["sheet"], Rect2(at, size), art)
			_mesh.texture = sheet
			_mesh.region_rect = region
			_mesh.position = box.position
			_mesh.scale = box.size / region.size
			_mesh.visible = visible
		_:
			draw_texture_rect_region(sheet, box, region)


## The halo behind a head: stepped ellipses of faint white, biggest and faintest first.
func _halo(box: Rect2) -> void:
	var middle := box.position + box.size * 0.5
	var steps := HALO_ALPHA.size()
	for i in steps:
		var grow := 1.0 + HALO_GROW * (1.0 - float(i) / float(steps))
		var radius := box.size * 0.5 * grow
		var ring := PackedVector2Array()
		for k in 24:
			var a := TAU * float(k) / 24.0
			ring.append(middle + Vector2(cos(a) * radius.x, sin(a) * radius.y))
		draw_colored_polygon(ring, Color(1.0, 1.0, 1.0, float(HALO_ALPHA[i])))


## One row: a clean-water plate, the name over its value on the left, the price tag on the
## right. A row the player cannot afford is drawn back rather than hidden: the point of a
## shop is knowing what is coming.
func _draw_row(row: Dictionary, box: Rect2, hovered: bool) -> void:
	var afford := bool(row.get("afford", false))
	var lit := hovered and afford
	var face := Style.BOARD_ROW if afford else Style.BOARD_ROW_OFF
	if lit:
		face = Color(
			face.r * Style.HOVER_WASH.r, face.g * Style.HOVER_WASH.g, face.b * Style.HOVER_WASH.b
		)
	var ink := Style.BOARD_INK if afford else Style.BOARD_INK_DIM
	_plate(box, face)

	var tag_wide := box.size.x * TAG_SHARE
	var text_at := box.position.x + 10.0
	var name := String(row.get("name", ""))
	var value := String(row.get("value", ""))
	# Two lines, or one centred if there is no value to say.
	if value.is_empty():
		Style.write(
			self, name, Style.TEXT_BODY,
			Vector2(text_at, box.position.y + (box.size.y + float(Style.TEXT_BODY) * 0.62) * 0.5),
			ink
		)
	else:
		var stack := float(Style.TEXT_BODY) * 0.62 + float(Style.TEXT_SMALL) * 0.62 + 6.0
		var first := box.position.y + (box.size.y - stack) * 0.5 + float(Style.TEXT_BODY) * 0.62
		Style.write(self, name, Style.TEXT_BODY, Vector2(text_at, first), ink)
		Style.write(
			self, value, Style.TEXT_SMALL,
			Vector2(text_at, first + 6.0 + float(Style.TEXT_SMALL) * 0.62),
			ink.lerp(face, 0.25)
		)
	_draw_tag(
		Rect2(
			Vector2(box.end.x - tag_wide - 6.0, box.position.y + 8.0),
			Vector2(tag_wide, box.size.y - 16.0)
		),
		String(row.get("cost", "")), Style.TEXT_BODY, afford, lit
	)


## A plate in a colour of its own, its corners clipped a step: a seam, the face, a lit edge top
## and left, a shaded one bottom and right. `Style.plaque` bevels in wood and stays square;
## these are the shop's buttons and read better softened.
func _plate(box: Rect2, face: Color) -> void:
	var bevel := Style.bevel_of(box)
	var c := CLIP
	draw_colored_polygon(_clipped(box.grow(1.0), c), Style.SEAM)
	draw_colored_polygon(_clipped(box, c), face)
	var lit := face.lightened(0.22)
	var deep := face.darkened(0.28)
	# The bevel strips stop short of the clipped corners, so the corner stays one clean cut.
	draw_rect(Rect2(box.position + Vector2(c, 0.0), Vector2(box.size.x - c * 2.0, bevel)), lit, true)
	draw_rect(Rect2(box.position + Vector2(0.0, c), Vector2(bevel, box.size.y - c * 2.0)), lit, true)
	draw_rect(
		Rect2(Vector2(box.position.x + c, box.end.y - bevel), Vector2(box.size.x - c * 2.0, bevel)),
		deep, true
	)
	draw_rect(
		Rect2(Vector2(box.end.x - bevel, box.position.y + c), Vector2(bevel, box.size.y - c * 2.0)),
		deep, true
	)


## A rectangle with one step cut off each corner: the pixel-art round corner.
func _clipped(box: Rect2, c: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(box.position.x + c, box.position.y),
		Vector2(box.end.x - c, box.position.y),
		Vector2(box.end.x, box.position.y + c),
		Vector2(box.end.x, box.end.y - c),
		Vector2(box.end.x - c, box.end.y),
		Vector2(box.position.x + c, box.end.y),
		Vector2(box.position.x, box.end.y - c),
		Vector2(box.position.x, box.position.y + c),
	])


## The price, on a clean-water tag shrunk onto the number, so a five-figure price and a two-figure
## one both sit in the middle of their own tag rather than one rattling around a fixed box.
func _draw_tag(box: Rect2, cost: String, height: int, afford: bool, lit: bool) -> void:
	if cost.is_empty():
		return
	var span := Style.measure(cost, height)
	var wide := minf(span.x + float(height) * 1.2, box.size.x)
	var tag := Rect2(
		box.position + Vector2(box.size.x - wide, 0.0), Vector2(wide, box.size.y)
	)
	_plate(tag, (Style.TAG_LIT if lit else Style.TAG) if afford else Style.BOARD)
	Style.write(
		self, cost, height,
		Vector2(0.0, tag.position.y + tag.size.y * 0.5 + float(height) * 0.34),
		Style.TAG_INK if afford else Style.BOARD_INK_DIM,
		HORIZONTAL_ALIGNMENT_CENTER, tag
	)


## A handful of four-pointed stars rising off a bought board's sprite and fading out.
##
## The stars are the same shape the game draws everywhere else: two crossed spindles, which
## read as a sparkle at eight pixels where a circle reads as a dot.
func _draw_sparkle(slot: Rect2) -> void:
	var through := 1.0 - clampf(_sparkle / SPARKLE_TIME, 0.0, 1.0)
	var out := smoothstep(0.0, 1.0, through)
	var fade := 1.0 - smoothstep(0.5, 1.0, through)
	var middle := slot.position + slot.size * 0.5
	for i in SPARKLE_POINTS:
		# Thrown out on its own bearing rather than laid out in a row: a line of identical
		# stars reads as a border.
		var turn := PI * (0.12 + 0.76 * float(i) / float(SPARKLE_POINTS - 1))
		var reach := SPARKLE_RISE * (0.55 + 0.45 * float((i * 3) % SPARKLE_POINTS)
			/ float(SPARKLE_POINTS - 1))
		var at := middle + Vector2(-cos(turn), -sin(turn)) * reach * out
		# Biggest halfway out, so each one flares and goes rather than simply shrinking.
		var flare := sin(clampf(through, 0.0, 1.0) * PI)
		var side := (3.0 + 4.0 * float(i % 3) * 0.5) * (0.45 + 0.55 * flare)
		_star(at, side, Color(Style.GOLD.r, Style.GOLD.g, Style.GOLD.b, fade))


## One four-pointed star: a tall spindle and a wide one, crossed.
func _star(at: Vector2, side: float, tint: Color) -> void:
	draw_colored_polygon(
		PackedVector2Array([
			at + Vector2(0.0, -side), at + Vector2(side * 0.34, 0.0),
			at + Vector2(0.0, side), at + Vector2(-side * 0.34, 0.0)
		]),
		tint
	)
	draw_colored_polygon(
		PackedVector2Array([
			at + Vector2(-side, 0.0), at + Vector2(0.0, -side * 0.34),
			at + Vector2(side, 0.0), at + Vector2(0.0, side * 0.34)
		]),
		tint
	)
