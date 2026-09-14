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
const BOARDS: Array[StringName] = [&"net", &"boat", &"dog", &"market"]
const TITLES := {&"net": "The net", &"boat": "The ferry", &"dog": "The dog", &"market": "The market"}

## The market board's head is the money plate's own coin (`HudButtons.coin`), drawn from
## nothing like the plate's: the game has no picture of money, and the board sells what
## things are worth rather than a thing.
const HudButtons := preload("res://scripts/hud_buttons.gd")

## How tall a row is drawn, and how short it may be squeezed to before a board gives up
## and drops one. A board grows a row at a time until it is as tall as the window allows,
## and then the rows themselves have to give: a shop that quietly stops drawing its last two
## upgrades — which is what a fixed row height did the day the dog got two of its own — is
## worse than a shop drawn slightly tighter. Two lines tall, because a row's name sits over
## its value: three boards across a window leave no room for them side by side.
const ROW_TALL := 50.0
const ROW_LEAST := 40.0
const ROW_GAP := 6.0

## The four boards together, and the gap between them. Sized in the 1280-wide design
## frame; a narrower window shrinks all four alike. 900 held three; the market board
## (2026-09-13) took it to 1180, or a row's name and its tag met in the middle.
const BOARDS_WIDE := 1180.0
const BOARD_GAP := 44.0
const BOARD_PAD := 14.0

## The oak round each board, cut like the meter's frame (`Style.plank` and friends draw
## the wood) with a few chips out of the outer edge (`CHIPS` a side). The ribbon and sprite sit at the head of it. The sprite is the
## thing being sold — the net, the ferry, the dog — and the ribbon names it.
const FRAME := 12.0
const CHIPS := 3
const RIBBON_TALL := 36.0
const RIBBON_OVERHANG := 10.0
## How much of its slot each board's sprite fills. The net is a wide flat thing and fills
## the slot at 0.7; the ferry's region is the box round the drawn boat, and pixel art, so
## it is drawn at a whole number of pixels per art pixel and fills what that comes to.
const SPRITE_FILL := {&"net": 0.7, &"boat": 1.0, &"dog": 0.8, &"market": 0.62}

## The ferry on its board is under way: the bow wake it leaves in the lake runs beside it
## and the hull bobs a couple of pixels on a slow swell. The wake is laid exactly as the
## lake lays it — the lake lends the heading, anchor and size with the picture, in the
## picture's own pixels, and the board scales them with it.
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

const CLIP := Style.CLIP
const SPRITE_TALL := 68.0
const HEAD_GAP := 8.0

## How much of a row the price tag may take.
const TAG_SHARE := 0.34

const CLOSE_SIZE := 44.0

## The "?" in the top left corner of every row (2026-09-13): a small oak tag, like the
## price's, with the mark on it. Hovering it opens the row's blurb on a plate beside it;
## clicking it buys nothing. The row's writing starts past it.
const HELP_SIZE := 15.0
## Hung out over the plate's corner rather than set inside it (Richard, 2026-09-13): a tag
## sat in the corner took a strip off every row. Negative, so most of it is on the board.
const HELP_INSET := -6.0
const HELP_GAP := 4.0
## The blurb's plate: how wide its writing may run, its padding, and the gap off the "?".
const BLURB_WIDE := 250.0
const BLURB_PAD := 12.0
const BLURB_OFF := Vector2(10.0, 4.0)

## The legend under the shortest boards (the ferry's and the dog's, which stand in the
## middle): the weight tiers with their sell rates, the yards, the bonus and the pay rule.
## Drawn only where the room under those two boards comes to at least `LEGEND_LEAST`.
const LEGEND_GAP := 22.0
const LEGEND_PAD := 12.0
const LEGEND_LINE := 4.0
const LEGEND_LEAST := 96.0

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
## `{key, board, name, level, value, cost, afford}` — `board` is one of BOARDS.
var rows: Array = []

## What the legend under the boards says, set by the lake beside `rows`:
## `{tiers: [[name, pct]...], yards: [[name, "$n"]...], rule}`.
var legend: Dictionary = {}

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

## Every drawn row's "?" box, parallel to `_row_boxes`, and which row's is under the
## pointer, or -1.
var _help_boxes: Array[Rect2] = []
var _help_hovered: int = -1

## Where the legend stands this frame; zero-sized when there is no room for it.
var _legend_box := Rect2()

## The ferry's wake and the hull over it. Both are nodes rather than this control's own
## drawing: HullFoam is a Node2D with a shader, and a child of a Control draws after the
## Control — so the board face is painted here, then the wake, then the hull on top.
## (HullFoam sets itself behind its parent, which under a boat is right and under a board
## would bury it; the shop puts it back in front.)
var _wake: HullFoam
var _hull: Polygon2D
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
	# A polygon rather than a sprite: the hull is cut along its waterline, which is not a
	# rectangle's edge.
	_hull = Polygon2D.new()
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
	# Half the wood, because only the top plank is above the head; a board is three of these
	# side by side, so its own width is the whole width less the gaps, divided by three.
	var one := (BOARDS_WIDE - BOARD_GAP * float(BOARDS.size() - 1)) / float(BOARDS.size())
	return Style.board_wood_tall(one, FRAME) * 0.5 + RIBBON_TALL * 0.5 + BOARD_PAD + SPRITE_TALL + HEAD_GAP


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
	_legend_box = Rect2()
	if _boards.has(&"boat") and _boards.has(&"dog"):
		var under: Rect2 = _boards[&"boat"]
		var dog: Rect2 = _boards[&"dog"]
		var top_y := maxf(under.end.y, dog.end.y) + LEGEND_GAP
		var free := _table.end.y - top_y
		if free >= LEGEND_LEAST:
			_legend_box = Rect2(
				Vector2(under.position.x, top_y),
				Vector2(dog.end.x - under.position.x, minf(free, _legend_tall()))
			)
	if _close != null and _boards.has(BOARDS[BOARDS.size() - 1]):
		# Nailed to the right end of the last board's title plank, as the shed's shelf has it,
		# rather than hung in the air past that board's corner.
		var at := Style.close_on(_ribbon_of(_boards[BOARDS[BOARDS.size() - 1]]), CLOSE_SIZE)
		_close.position = at.position
		_close.size = at.size
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
		var was_help := _help_hovered
		var at := (event as InputEventMouseMotion).position
		_hovered = _row_under(at)
		_help_hovered = _help_under(at)
		if was != _hovered or was_help != _help_hovered:
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
	# The "?" is for reading, not buying: a click on it is eaten.
	if _help_under(click.position) >= 0:
		return
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


## Which row's "?" is under the pointer, or -1.
func _help_under(at: Vector2) -> int:
	for i in _help_boxes.size():
		if _help_boxes[i].has_point(at):
			return _row_index[i]
	return -1


## The "?" tag's box in the top left corner of a row's plate.
static func help_box_of(row_box: Rect2) -> Rect2:
	return Rect2(row_box.position + Vector2(HELP_INSET, HELP_INSET), Vector2(HELP_SIZE, HELP_SIZE))


func _paint_key() -> int:
	return hash([rows.hash(), legend.hash(), _hovered, _help_hovered, roundi(_sparkle * 120.0), _dog_frame])


func _draw() -> void:
	_painted = _paint_key()
	if _table.size.x <= 0.0:
		return
	# Everything behind the boards dimmed, so they are things in front of the lake rather
	# than stickers on it.
	Style.dim(self, Rect2(Vector2.ZERO, size), Style.SCRIM)
	_row_boxes.clear()
	_row_index.clear()
	_help_boxes.clear()
	for board in BOARDS:
		_draw_board(board, _boards[board])
	if _legend_box.size.y > 0.0:
		_draw_legend(_legend_box)
	if _help_hovered >= 0 and _help_hovered < rows.size():
		_draw_blurb(rows[_help_hovered])


## One board: oak frame, clean-water face, ribbon over the top edge, the sprite, the rows.
func _draw_board(board: StringName, box: Rect2) -> void:
	_draw_frame(box)
	var face := Style.board_face(box, FRAME)
	draw_rect(face.grow(1.0), Style.SEAM, true)
	draw_rect(face, Style.BOARD, true)

	# The ribbon, hung over the top of the frame and a little wider than the board, the
	# way the old painted one was. Its ends are notched like the meter's frame.
	var ribbon := _ribbon_of(box)
	# Only the last board carries the cross, so only its title makes room for one.
	var room := Style.title_room(ribbon, CLOSE_SIZE) if board == BOARDS[BOARDS.size() - 1] else Rect2()
	_draw_ribbon(ribbon, String(TITLES.get(board, "")), room)

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
		_help_boxes.append(help_box_of(line))
		_draw_row(row, line, _hovered == i, _help_hovered == i)


## The board's oak frame and its title plank. Both are drawn by `Style`, so the shop's
## boards, the settings board and the shed's shelf cannot become three woods.
func _draw_frame(box: Rect2) -> void:
	Style.board_wood(self, box, FRAME, CHIPS)


func _draw_ribbon(box: Rect2, title: String, within: Rect2 = Rect2()) -> void:
	Style.board_ribbon(self, box, title, CHIPS, Style.TEXT_HEAD, within)


## A board's title plank, hung over its top edge and a little wider than the board.
func _ribbon_of(box: Rect2) -> Rect2:
	return Rect2(
		Vector2(box.position.x - RIBBON_OVERHANG, box.position.y - RIBBON_TALL * 0.5),
		Vector2(box.size.x + RIBBON_OVERHANG * 2.0, RIBBON_TALL)
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
	if board == &"market":
		var side := slot.size.y * fill
		var coin := Rect2(middle - Vector2.ONE * side * 0.5, Vector2.ONE * side)
		_halo(coin)
		HudButtons.coin(self, coin, Color.WHITE)
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
	# Pixel art at a fraction of a pixel per art pixel drops rows; the ferry keeps to whole
	# steps.
	if board == &"boat":
		scale = maxf(floor(scale), 1.0)
	var drawn := region.size * scale
	# Never wider than the slot.
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
			var anchor: Vector2 = lent.get("anchor", region.size * 0.5)
			_wake.position = box.position + anchor * to_drawn
			_wake.half_length = float(lent.get("half_length", region.size.x * 0.5)) * to_drawn
			_wake.half_width = float(lent.get("half_width", region.size.x * 0.2)) * to_drawn
			_wake_heading = lent.get("heading", Vector2.RIGHT)
			_wake.visible = visible
			_hull.texture = sheet
			var cut: PackedVector2Array = lent.get("cut", PackedVector2Array([
				Vector2.ZERO, Vector2(region.size.x, 0.0), region.size, Vector2(0.0, region.size.y)
			]))
			_hull.polygon = cut
			var uv := PackedVector2Array()
			for at in cut:
				uv.append(region.position + at)
			_hull.uv = uv
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
func _draw_row(row: Dictionary, box: Rect2, hovered: bool, help_lit: bool) -> void:
	var afford := bool(row.get("afford", false))
	var lit := hovered and afford
	var face := Style.BOARD_ROW if afford else Style.BOARD_ROW_OFF
	if lit:
		face = Color(
			face.r * Style.HOVER_WASH.r, face.g * Style.HOVER_WASH.g, face.b * Style.HOVER_WASH.b
		)
	var ink := Style.BOARD_INK if afford else Style.BOARD_INK_DIM
	Style.plate(self, box, face)

	var tag_wide := box.size.x * TAG_SHARE
	# The "?" first, in the corner, and the writing starts past it.
	_draw_help(help_box_of(box), afford, help_lit)
	var text_at := box.position.x + maxf(HELP_INSET + HELP_SIZE + HELP_GAP, 10.0)
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
		# Both lines stop short of the tag (2026-09-13): with the next level on the value
		# line it ran under the price, and a long name's level already did. The name drops a
		# size before its level is given up, the value drops a size and is then cut with an
		# ellipsis — a line under a tag reads as a bug, a short line as a short line.
		var tag := _tag_of(box, tag_wide, String(row.get("cost", "")), Style.TEXT_BODY)
		var room := (tag.position.x if tag.size.x > 0.0 else box.end.x) - 8.0 - text_at
		# The level after the name, in the clean water's blue: `LEVEL_INK` rather than the
		# money's gold, because gold on this board is a price. Dimmed with the rest of the
		# row when it cannot be bought. Small (2026-09-13): the name is what the row is, the
		# level is a footnote to it.
		var level := String(row.get("level", ""))
		var level_wide := 0.0 if level.is_empty() else Style.measure(level, Style.TEXT_TINY).x + 6.0
		var name_size := Style.TEXT_BODY
		if Style.measure(name, name_size).x + level_wide > room:
			name_size = Style.TEXT_SMALL
		if Style.measure(name, name_size).x + level_wide > room:
			level = ""
		var took := Style.write(self, _cut_to(name, name_size, room), name_size, Vector2(text_at, first), ink)
		if not level.is_empty():
			var level_ink := Style.LEVEL_INK if afford else Style.LEVEL_INK.lerp(Style.BOARD_INK_DIM, 0.5)
			Style.write(self, level, Style.TEXT_TINY, Vector2(text_at + took.x + 6.0, first), level_ink)
		var value_size := Style.TEXT_SMALL
		if Style.measure(value, value_size).x > room:
			value_size = Style.TEXT_TINY
		if Style.measure(value, value_size).x > room:
			# The word "next" goes before any of the numbers do: "(+55%)" after the figure
			# still reads as the step, "(+5…" does not.
			value = value.replace(" next)", ")")
		Style.write(
			self, _cut_to(value, value_size, room), value_size,
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


## Where a row's price tag will stand, without drawing it: the same sum `_draw_tag` makes.
func _tag_of(box: Rect2, tag_wide: float, cost: String, height: int) -> Rect2:
	if cost.is_empty():
		return Rect2()
	var slot := Rect2(
		Vector2(box.end.x - tag_wide - 6.0, box.position.y + 8.0),
		Vector2(tag_wide, box.size.y - 16.0)
	)
	var wide := minf(Style.measure(cost, height).x + float(height) * 1.2, slot.size.x)
	return Rect2(slot.position + Vector2(slot.size.x - wide, 0.0), Vector2(wide, slot.size.y))


## A line cut to `wide` with an ellipsis, or whole if it fits.
static func _cut_to(text: String, height: int, wide: float) -> String:
	if Style.measure(text, height).x <= wide:
		return text
	var kept := text
	while kept.length() > 1 and Style.measure(kept + "…", height).x > wide:
		kept = kept.left(kept.length() - 1)
	return kept.strip_edges() + "…"


## The "?" tag: the price tag's oak, the mark in the price's ink, lit under the pointer.
func _draw_help(box: Rect2, afford: bool, lit: bool) -> void:
	var face := Style.FRAME if afford else Style.FRAME_LOW
	if lit:
		face = Color(
			face.r * Style.HOVER_WASH.r, face.g * Style.HOVER_WASH.g, face.b * Style.HOVER_WASH.b
		)
	Style.plate(self, box, face, 2.0)
	Style.write(
		self, "?", Style.TEXT_SMALL,
		Vector2(0.0, box.position.y + box.size.y * 0.5 + float(Style.TEXT_SMALL) * 0.36),
		Style.PRICE_INK if afford else Style.PRICE_INK.lerp(Style.FRAME_LOW, 0.5),
		HORIZONTAL_ALIGNMENT_CENTER, box
	)


## A row's blurb on a plate of the boards' own wood, hung off its "?" and kept inside the
## window. Drawn last, over every board.
func _draw_blurb(row: Dictionary) -> void:
	var i := _row_index.find(_help_hovered)
	if i < 0:
		return
	var anchor := _help_boxes[i]
	var title := String(row.get("name", ""))
	var lines := _wrap(String(row.get("blurb", "")), Style.TEXT_SMALL, BLURB_WIDE)
	var wide := Style.measure(title, Style.TEXT_BODY).x
	for line in lines:
		wide = maxf(wide, Style.measure(line, Style.TEXT_SMALL).x)
	var line_tall := float(Style.TEXT_SMALL) + LEGEND_LINE
	var inner := Vector2(
		wide + BLURB_PAD * 2.0,
		BLURB_PAD * 2.0 + float(Style.TEXT_BODY) + 6.0 + line_tall * float(lines.size())
	)
	# Sized so the face holds the writing whichever wood the box gets: the painted border
	# is thicker than the drawn frame, and `board_face` knows which it will be.
	var box := Rect2(
		Vector2(anchor.end.x, anchor.position.y) + BLURB_OFF, inner + Vector2(FRAME, FRAME) * 2.0
	)
	box.size += inner - Style.board_face(box, FRAME).size
	box.position.x = clampf(box.position.x, 4.0, size.x - box.size.x - 4.0)
	box.position.y = clampf(box.position.y, 4.0, size.y - box.size.y - 4.0)
	var face := Style.board_wood(self, box, FRAME, CHIPS)
	var at := face.position + Vector2(BLURB_PAD, BLURB_PAD + float(Style.TEXT_BODY) * 0.8)
	Style.write(self, title, Style.TEXT_BODY, at, Style.BOARD_INK)
	at.y += 6.0 + line_tall
	for line in lines:
		Style.write(self, line, Style.TEXT_SMALL, at, Style.BOARD_INK.lerp(Style.BOARD, 0.15))
		at.y += line_tall


## How tall the legend wants to be: the materials over their prices, the tiers, the line,
## and their padding, in the board's wood.
func _legend_tall() -> float:
	var line := float(Style.TEXT_SMALL) + LEGEND_LINE
	var inner := LEGEND_PAD * 2.0 + line * 4.0 + LEGEND_GAP_ROW * 2.0
	return inner + Style.board_wood_tall(BOARDS_WIDE * 0.5, FRAME)


## The gap between the legend's three parts.
const LEGEND_GAP_ROW := 6.0


## The legend: one plate in the boards' wood under the ferry's and the dog's. The four
## materials spread across the top with what a piece of each pays on average under them
## (in the price's gold, as a price), the tiers with their sell rates on one line below,
## and one line of explanation under it all.
func _draw_legend(box: Rect2) -> void:
	var face := Style.board_wood(self, box, FRAME, CHIPS)
	var line_tall := float(Style.TEXT_SMALL) + LEGEND_LINE
	var at := face.position + Vector2(LEGEND_PAD, LEGEND_PAD + float(Style.TEXT_SMALL) * 0.8)
	var wide := face.size.x - LEGEND_PAD * 2.0
	var yards: Array = legend.get("yards", [])
	if not yards.is_empty():
		var step := wide / float(yards.size())
		for y in yards.size():
			var pair: Array = yards[y]
			var slot := Rect2(Vector2(at.x + step * float(y), 0.0), Vector2(step, 0.0))
			Style.write(self, String(pair[0]), Style.TEXT_SMALL, Vector2(0.0, at.y), Style.BOARD_INK,
				HORIZONTAL_ALIGNMENT_CENTER, slot)
			Style.write(self, String(pair[1]), Style.TEXT_SMALL, Vector2(0.0, at.y + line_tall),
				Style.PRICE_INK, HORIZONTAL_ALIGNMENT_CENTER, slot)
		at.y += line_tall * 2.0 + LEGEND_GAP_ROW
	var tiers: Array = legend.get("tiers", [])
	if not tiers.is_empty():
		var step := wide / float(tiers.size())
		for t in tiers.size():
			var pair: Array = tiers[t]
			var x := at.x + step * float(t)
			var took := Style.write(self, String(pair[0]), Style.TEXT_SMALL, Vector2(x, at.y), Style.BOARD_INK)
			Style.write(self, String(pair[1]), Style.TEXT_SMALL, Vector2(x + took.x + 6.0, at.y), Style.LEVEL_INK)
		at.y += line_tall + LEGEND_GAP_ROW
	for line in _wrap(String(legend.get("rule", "")), Style.TEXT_SMALL, wide):
		Style.write(self, line, Style.TEXT_SMALL, at, Style.BOARD_INK.lerp(Style.BOARD, 0.15))
		at.y += line_tall


## Words folded onto lines no wider than `wide`. `Style.write` has no wrap of its own.
static func _wrap(text: String, height: int, wide: float) -> Array[String]:
	var out: Array[String] = []
	var line := ""
	for word in text.split(" ", false):
		var trial := word if line.is_empty() else line + " " + word
		if not line.is_empty() and Style.measure(trial, height).x > wide:
			out.append(line)
			line = word
		else:
			line = trial
	if not line.is_empty():
		out.append(line)
	return out


## The price, on an oak tag shrunk onto the number in the money plate's gold, so a cost
## and a purse read as one substance — and a five-figure price and a two-figure one both
## sit in the middle of their own tag rather than one rattling around a fixed box.
func _draw_tag(box: Rect2, cost: String, height: int, afford: bool, lit: bool) -> void:
	if cost.is_empty():
		return
	var span := Style.measure(cost, height)
	var wide := minf(span.x + float(height) * 1.2, box.size.x)
	var tag := Rect2(
		box.position + Vector2(box.size.x - wide, 0.0), Vector2(wide, box.size.y)
	)
	var face := Style.FRAME if afford else Style.FRAME_LOW
	if lit:
		face = Color(
			face.r * Style.HOVER_WASH.r, face.g * Style.HOVER_WASH.g, face.b * Style.HOVER_WASH.b
		)
	Style.plate(self, tag, face)
	Style.highlight(
		self, tag.position + Vector2(CLIP, 0.0), Vector2(tag.size.x - CLIP * 2.0, 0.0),
		int(tag.position.x)
	)
	Style.write(
		self, cost, height,
		Vector2(0.0, tag.position.y + tag.size.y * 0.5 + float(height) * 0.34),
		Style.PRICE_INK if afford else Style.PRICE_INK.lerp(Style.FRAME_LOW, 0.5),
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
