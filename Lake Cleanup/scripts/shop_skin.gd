## The upgrades boards: the drawn shop, four boards side by side.
##
## One board each for the net, the boats, the dogs and luck, so the shop reads as four
## things with prices on them rather than one list of seventeen buttons. Everything is
## drawn here from `Style` — the frames, the ribbons, the rows, the tags — in the pollution
## meter's own colours (`Style.BOARD*`, murky water on oak); the painted shop sheet this
## replaced was a picture of one board with five rows and had to be papered over for every
## row it was not drawn with.
##
## Rows are grouped by what they change (`GROUPS`), each row carries a rail holding its "?"
## over its level, and the pricing plate under the middle two boards marks which material
## the recycle bonus is on. See "The Shop Reads" in CLAUDE.md for why each of those is the
## way it is.
##
## The lake owns what an upgrade is and what it costs; this owns where it sits and what it
## looks like, and says which one was clicked. Same split as the HUD skin.
class_name ShopSkin
extends Control

const Style := preload("res://scripts/style.gd")
const DogArt := preload("res://scripts/dog_art.gd")

## The boards, in the order they stand, and what each is called.
const BOARDS: Array[StringName] = [&"net", &"boat", &"dog", &"luck"]
## No "The" (2026-09-17): four boards standing side by side are already a list, and the
## article is a word every translation would have to carry for nothing.
const TITLES := {&"net": "Net", &"boat": "Boats", &"dog": "Dogs", &"luck": "Luck"}

## Which rows sit under which heading on each board, in reading order. `UPGRADE_ORDER` is
## the order the tracks load in, which is not a reading order; this is.
##
## A board with one group draws no heading — one heading over everything says nothing — so
## the net's five rows run on as they did. `Lake._shop_rows` gives every row a `board`; a
## row whose key is missing here is drawn after the groups rather than dropped.
const GROUPS := {
	&"net": [
		["", [&"net_strength", &"net_width", &"net_range", &"reel", &"net_hold"]],
	],
	&"boat": [
		["The run", [&"boat_speed", &"cargo", &"boat_volley"]],
		["The fleet", [&"fleet"]],
	],
	&"dog": [
		["The pack", [&"dog_count", &"dog_strength"]],
		["The trip", [&"dog_fetch", &"dog_wait"]],
	],
	&"luck": [
		["On a cast", [&"lucky_haul", &"double_cast"]],
		["At the yards", [&"recycle_bonus", &"bird_worth"]],
	],
}

## A group's heading and the carved rule beside it.
const GROUP_TALL := 20.0
const GROUP_GAP := 4.0

## The luck board's head is the money plate's own coin (`HudButtons.coin`), drawn from
## nothing like the plate's: the game has no picture of money, and the board sells odds and
## bonuses rather than a thing.
const HudButtons := preload("res://scripts/hud_buttons.gd")
const LakeGrid := preload("res://scripts/lake_grid.gd")

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
const SPRITE_FILL := {&"net": 0.7, &"boat": 1.0, &"dog": 0.8, &"luck": 0.62}

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

## The rail down the left of every row (2026-09-17), carrying the "?" over the level. See
## `_draw_rail`. It replaces the 15px oak tag the "?" used to be, hung on the row's corner.
const RAIL_WIDE := 26.0
const RAIL_GAP := 8.0

## What an unaffordable row's writing is inked in, in place of `Style.BOARD_INK_DIM`. That
## reads 2.19:1 on the off face, and 1.82:1 once the value's old quarter-lerp towards the
## face was applied; this reads 5.01:1 for both lines. The row's state is carried by the
## price tag and the lit edge instead, which is what the writing was being asked to do.
##
## The swatch lives in `Style` as `BOARD_INK_SOFT`: the settings board took the same fix on
## the same day and two files writing one colour down is how two colours start. The shed's
## shelf still inks in `BOARD_INK_DIM` and is owed the same pass.
const INK_DIM := Style.BOARD_INK_SOFT
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

## The recycle bonus's glitter on the plate: how many stars and the roll they sit at.
const BONUS_STARS := 5
const BONUS_STAR_SEED := 0x5eed
## Air between the lit panel's edge and the boosted material's name and figure.
const BONUS_PAD := 6.0
## The gap between the first board's foot and the purse hung under it while the shop is up.
const PURSE_GAP := 14.0
## The panel's wider sides: the stars stand in them, beside the words rather than over them.
const BONUS_SIDE := 22.0

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

## What each board is called, and what each group heading reads, set by the lake beside
## `rows`. **Both are words**, so both are the lake's to hand over once there is more than
## one language (issue #28) — `TITLES` and the headings in `GROUPS` are the English defaults
## and where the layout's own reading order lives, not the strings a player sees.
## `headings` maps a heading as `GROUPS` spells it to what to draw; a heading it does not
## hold draws as written.
var titles: Dictionary = TITLES
var headings: Dictionary = {}

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

# The tour (2026-09-22, `/grill-me` with Richard, issue #24): the first time a new game opens
# the shop, six paper cards walk it, one at a time. Everything is dimmed but the thing a card
# is about, a click (A) goes on, "Skip" ends it, and nothing can be bought while it is up.
# The lake decides when it starts and saves that it is over (`Lake._shop_tour_done`); this
# owns where each card points and what a click does. Picked off
# `tools/last_shop_tour_mockup.png`.
#
# What each card points at: a board, a group's rows by its heading in `GROUPS`, or the
# pricing plate (`&"legend"`).
const TOUR := [
	[&"net", "Your net can be upgraded to catch more objects, higher tiers and for faster cast and reel."],
	["On a cast", "You can also increase your net luck and double cast chance."],
	[&"boat", "Boats are essential for money making, make sure to keep them upgraded."],
	[&"dog", "Dogs will help bring objects to the recycle box."],
	["At the yards", "You can make more money by giving a bonus to recycling, and catching pigeons earn more."],
	[&"legend", "You can check the materials average price here, and which recycle has a bonus."],
]
const TOUR_DIM := Color(0.0, 0.0, 0.0, 0.58)
const TOUR_OUTLINE := Color(1.0, 1.0, 1.0, 0.9)
## Between the target and its card, in canvas pixels.
const TOUR_GAP := 20.0
const TOUR_CONTINUE := "Continue"
const TOUR_SKIP := "Skip"

## The card showing, or -1 for no tour.
var tour: int = -1
## Whether the prompt on the card is the pad's A rather than the mouse.
var tour_pad := false
## The tour is over: `skipped` if "Skip" ended it.
signal tour_ended(skipped: bool)

var _group_boxes := {}
## Drawn last and on top: the ferry, the net and the dog heads are child nodes and would
## draw over anything the board draws itself, the dimming and the card included.
var _tour_layer: Control
var _tour_skip := Rect2()
var _prompt_mouse: Texture2D = load("res://assets/ui/prompts/mouse_click.png") if ResourceLoader.exists("res://assets/ui/prompts/mouse_click.png") else null
var _prompt_a: Texture2D = load("res://assets/ui/prompts/pad_a.png") if ResourceLoader.exists("res://assets/ui/prompts/pad_a.png") else null
var _prompt_arrow: Texture2D = load("res://assets/ui/prompts/arrow_up.png") if ResourceLoader.exists("res://assets/ui/prompts/arrow_up.png") else null


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


## The luck board's coin is tossed (2026-09-20, Richard: "the coin should be animated, maybe
## a flip"). It rests face on, and every `TOSS_EVERY` seconds (rolled, so it has no beat), and
## whenever a row on its board is bought, it hops `TOSS_HOP` and turns `TOSS_TURNS` whole
## times on the way, landing on the face it left. **Tossed, not spinning**: the ferry bobs
## and the dog breathes beside it, and a coin turning for ever is the busiest thing on the
## shop. The board redraws only while the coin is in the air.
const TOSS_EVERY := Vector2(3.0, 5.0)
const TOSS_TIME := 0.85
const TOSS_TURNS := 2.0
const TOSS_HOP := 12.0

var _toss_age := -1.0
var _toss_in := 2.0
var _toss_rng := RandomNumberGenerator.new()


func toss_coin() -> void:
	if _toss_age < 0.0:
		_toss_age = 0.0


## How far through a toss the coin is, 0 to 1, or -1 at rest.
func toss_share() -> float:
	return -1.0 if _toss_age < 0.0 else clampf(_toss_age / TOSS_TIME, 0.0, 1.0)


## The cosine of the coin's turn and how far it has hopped, at a share of the toss.
static func toss_pose(share: float) -> Vector2:
	if share < 0.0:
		return Vector2(1.0, 0.0)
	return Vector2(cos(TAU * TOSS_TURNS * share), 4.0 * share * (1.0 - share) * TOSS_HOP)


func _drive_toss(delta: float) -> void:
	if _toss_age >= 0.0:
		_toss_age += delta
		if _toss_age >= TOSS_TIME:
			_toss_age = -1.0
			_toss_in = _toss_rng.randf_range(TOSS_EVERY.x, TOSS_EVERY.y)
		queue_redraw()
		return
	_toss_in -= delta
	if _toss_in <= 0.0:
		toss_coin()


## Light up the sprite of the board whose upgrade has just been bought. Called by the lake
## when a purchase actually lands, so a click that could not be afforded sparkles at nobody.
func cheer(key: StringName) -> void:
	_sparkling = _board_of(key)
	_sparkle = SPARKLE_TIME
	if _sparkling == &"luck":
		toss_coin()
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


## The four boards in a row, each as tall as its rows and headings come to, tops aligned.
##
## Sized to the content rather than to the window: the dog's board has four rows and is four
## rows tall, the net's five and five. The tallest of them decides how tall a row may be, so
## a squeeze lands on all four alike and the rows still line up across them.
##
## The pricing plate is **not** held inside the tallest board's height (2026-09-17). It was,
## and that is why it used to fit only while the net board stood three rows taller than the
## middle two — a gap the grouping closes. It hangs below that line now, and the block of
## boards and plate together is what gets centred.
func _lay_out() -> void:
	var most := 1
	for board in BOARDS:
		most = maxi(most, _count(board))
	var headings := 0
	for board in BOARDS:
		headings = maxi(headings, _headings_of(board))
	var spare := _head_tall() + float(most - 1) * ROW_GAP + BOARD_PAD + FRAME 		+ float(headings) * (GROUP_TALL + GROUP_GAP)
	var room := (size.y - 40.0 - spare) / float(most)
	_row_tall = clampf(room, ROW_LEAST, ROW_TALL)
	var tallest := minf(spare + float(most) * _row_tall, size.y - 40.0)

	var wide := minf(BOARDS_WIDE, size.x - 40.0)
	var each := (wide - BOARD_GAP * float(BOARDS.size() - 1)) / float(BOARDS.size())
	var talls := {}
	for board in BOARDS:
		talls[board] = minf(_board_tall(board), tallest)
	var middle_foot := 0.0
	if _mid_boards().size() == 2:
		for board in _mid_boards():
			middle_foot = maxf(middle_foot, float(talls[board]))
	var block := tallest
	if middle_foot > 0.0:
		block = maxf(block, middle_foot + LEGEND_GAP + _legend_tall())
	block = minf(block, size.y - 40.0)
	var top := floorf((size.y - block) * 0.5)
	var left := floorf((size.x - wide) * 0.5)
	_table = Rect2(left, top, wide, block)
	_boards.clear()
	for i in BOARDS.size():
		_boards[BOARDS[i]] = Rect2(
			floorf(left + (each + BOARD_GAP) * float(i)), top, floorf(each), float(talls[BOARDS[i]])
		)
	_legend_box = Rect2()
	var mid := _mid_boards()
	if mid.size() == 2:
		var one: Rect2 = _boards[mid[0]]
		var two: Rect2 = _boards[mid[1]]
		var top_y := top + middle_foot + LEGEND_GAP
		var free := _table.end.y - top_y
		if free >= LEGEND_LEAST:
			_legend_box = Rect2(
				Vector2(one.position.x, top_y),
				Vector2(two.end.x - one.position.x, minf(free, _legend_tall()))
			)
	if _close != null and _boards.has(BOARDS[BOARDS.size() - 1]):
		# Nailed to the right end of the last board's title plank, as the shed's shelf has it,
		# rather than hung in the air past that board's corner.
		var at := Style.close_on(_ribbon_of(_boards[BOARDS[BOARDS.size() - 1]]), CLOSE_SIZE)
		_close.position = at.position
		_close.size = at.size
	queue_redraw()


## The two boards the pricing plate stands under: the middle pair, whichever they are, so
## the plate follows `BOARDS` rather than naming two of them a second time.
func _mid_boards() -> Array[StringName]:
	if BOARDS.size() < 4:
		return []
	return [BOARDS[1], BOARDS[2]]


## How many headings a board draws. A board with one group draws none.
func _headings_of(board: StringName) -> int:
	var groups: Array = GROUPS.get(board, [])
	if groups.size() < 2:
		return 0
	var n := 0
	for group: Array in groups:
		if not String(group[0]).is_empty():
			n += 1
	return n


## How tall a board comes out: its head, its headings, and its rows.
func _board_tall(board: StringName) -> float:
	var count := maxi(_count(board), 1)
	return _head_tall() + float(_headings_of(board)) * (GROUP_TALL + GROUP_GAP) 		+ float(count) * _row_tall + float(count - 1) * ROW_GAP + BOARD_PAD + FRAME


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
		_drive_toss(delta)
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
	if tour >= 0:
		_tour_input(event)
		return
	if event is InputEventMouseMotion:
		var was := _hovered
		var was_help := _help_hovered
		var at := (event as InputEventMouseMotion).position
		_hovered = _row_under(at)
		_help_hovered = _help_under(at)
		if was != _hovered or was_help != _help_hovered:
			if (_hovered >= 0 and _hovered != was) or (_help_hovered >= 0 and _help_hovered != was_help):
				Sfx.ui(&"ui_hover")
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
	# The "?" is for reading, not buying: a click on it is eaten. A row itself makes no click:
	# a purchase is heard as the purchase, and one that cannot be afforded is silent.
	if _help_under(click.position) >= 0:
		Sfx.ui(&"ui_click")
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


## The rail's box down the left of a row's plate.
static func rail_of(row_box: Rect2) -> Rect2:
	return Rect2(row_box.position, Vector2(RAIL_WIDE, row_box.size.y))


## What the "?" answers to: the rail's top half. Its own box rather than the whole rail, so
## the level's figure is not a button.
static func help_box_of(row_box: Rect2) -> Rect2:
	var rail := rail_of(row_box)
	return Rect2(rail.position, Vector2(rail.size.x, rail.size.y * 0.5))


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
	_group_boxes.clear()
	for board in BOARDS:
		_draw_board(board, _boards[board])
	if _legend_box.size.y > 0.0:
		_draw_legend(_legend_box)
	if _help_hovered >= 0 and _help_hovered < rows.size() and tour < 0:
		_draw_blurb(rows[_help_hovered])
	if tour >= 0:
		_ensure_tour_layer()
	if _tour_layer != null:
		_tour_layer.queue_redraw()


## One board: oak frame, clean-water face, ribbon over the top edge, the sprite, the rows.
func _draw_board(board: StringName, box: Rect2) -> void:
	_draw_frame(box)
	var face := Style.board_face(box, FRAME)
	draw_rect(face.grow(1.0), Style.SEAM, true)
	draw_rect(face, Style.PAPER, true)

	# The ribbon, hung over the top of the frame and a little wider than the board, the
	# way the old painted one was. Its ends are notched like the meter's frame.
	var ribbon := _ribbon_of(box)
	# Only the last board carries the cross, so only its title makes room for one.
	var room := Style.title_room(ribbon, CLOSE_SIZE) if board == BOARDS[BOARDS.size() - 1] else Rect2()
	_draw_ribbon(ribbon, String(titles.get(board, TITLES.get(board, ""))), room)

	# The sprite, fitted into its slot at its own proportions.
	var slot := Rect2(
		Vector2(face.position.x, box.position.y + RIBBON_TALL * 0.5 + BOARD_PAD),
		Vector2(face.size.x, SPRITE_TALL)
	)
	# The head stands in a window of the boards' old dark water: the ferry's foam, the net's
	# black and the coin were all picked against it, and white foam on cream is nothing.
	Style.plate(self, slot.grow_individual(-BOARD_PAD, 0.0, -BOARD_PAD, 0.0), Style.BOARD, 3.0)
	_draw_sprite(board, slot)
	if _sparkle > 0.0 and board == _sparkling:
		_draw_sparkle(slot)

	# The rows, in the order `GROUPS` reads them, under their headings.
	var left := face.position.x + BOARD_PAD
	var wide := face.size.x - BOARD_PAD * 2.0
	var y := slot.end.y + HEAD_GAP
	var heads := _headings_of(board) > 0
	for i in _ordered(board):
		if i < 0:
			# A heading, keyed by the group it opens: the index is minus its group, less one.
			var heading: String = String((GROUPS[board][-i - 1] as Array)[0])
			if not heads or heading.is_empty():
				continue
			_draw_group(heading, Rect2(left, y, wide, GROUP_TALL))
			_group_boxes[heading] = Rect2(left, y, wide, GROUP_TALL)
			y += GROUP_TALL + GROUP_GAP
			continue
		var line := Rect2(left, y, wide, _row_tall)
		if line.end.y > face.end.y - BOARD_PAD + 1.0:
			break
		y += _row_tall + ROW_GAP
		_row_boxes.append(line)
		_row_index.append(i)
		_grow_group(board, i, line)
		_help_boxes.append(help_box_of(line))
		_draw_row(rows[i], line, _hovered == i, _help_hovered == i)


## What a board draws, in order: a group's heading as `-group - 1`, then that group's rows
## as their indices into `rows`. A row on this board that no group claims comes last, so a
## track added to `TRACKS` without a line in `GROUPS` still appears.
func _ordered(board: StringName) -> Array[int]:
	var out: Array[int] = []
	var taken := {}
	var groups: Array = GROUPS.get(board, [])
	for g in groups.size():
		out.append(-g - 1)
		for key in (groups[g] as Array)[1]:
			for i in rows.size():
				var row: Dictionary = rows[i]
				if StringName(row.get("key", "")) != key:
					continue
				if StringName(row.get("board", "")) != board:
					continue
				out.append(i)
				taken[i] = true
				break
	for i in rows.size():
		if not taken.has(i) and StringName(rows[i].get("board", "")) == board:
			out.append(i)
	return out


## A group's heading: the words in the clean water's blue, and a carved rule running from
## them to the board's far edge, so the heading reads as a lid on what is under it.
func _draw_group(heading: String, box: Rect2) -> void:
	var base := box.position.y + box.size.y * 0.5 + float(Style.TEXT_SMALL) * 0.36
	var took := Style.write(
		self, String(headings.get(heading, heading)), Style.TEXT_SMALL,
		Vector2(box.position.x, base), Style.PAPER_HEAD
	)
	var from := box.position.x + took.x + 8.0
	if from >= box.end.x - 4.0:
		return
	var mid := box.position.y + box.size.y * 0.5
	draw_line(Vector2(from, mid), Vector2(box.end.x, mid), Style.PAPER_RULE, 2.0)
	draw_line(Vector2(from, mid + 1.0), Vector2(box.end.x, mid + 1.0), Style.PAPER_EDGE, 1.0)


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
	if board == &"luck":
		var side := slot.size.y * fill
		var coin := Rect2(middle - Vector2.ONE * side * 0.5, Vector2.ONE * side)
		_halo(coin)
		var pose := toss_pose(toss_share())
		coin.position.y -= roundf(pose.y)
		HudButtons.coin_turned(self, coin, Color.WHITE, pose.x)
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
## The rows that change what the game is rather than how fast it goes, and so lead their
## board and wear a gold rim with a star on its corner (2026-09-20, Richard: Strength
## "visually differentiated, and come to the top of net upgrades"). A tier of Strength roughly
## triples income and opens rubbish nothing else can lift; it read as one row in five.
##
## **Gold on this board is a price**, and that was weighed: the rim is a line round the plate
## and not writing on it, the price keeps its tag, and a row that cannot be bought wears the
## rim drawn back the way its "?" is. One row only, or the rim says nothing.
##
## **Retired, by decision**: a four-point gold star on the plate's corner. The top right
## corner is the price tag's, which reaches within a few pixels of the plate, and the top
## left is the rail's, where it sat on the "?". The rim in `Style.GOLD` reads on its own;
## in `PRICE_INK`, the tag's pale gold, it read as a cream line on the cream face.
const FEATURED: Array[StringName] = [&"net_strength"]


func _draw_featured(box: Rect2, afford: bool) -> void:
	var gold := Style.GOLD if afford else Style.GOLD.lerp(Style.FRAME_LOW, 0.45)
	for inset: float in [1.0, 2.0]:
		var ring := Style.clipped(box.grow(-inset), Style.CLIP)
		ring.append(ring[0])
		draw_polyline(ring, gold, 1.0)


func _draw_row(row: Dictionary, box: Rect2, hovered: bool, help_lit: bool) -> void:
	var afford := bool(row.get("afford", false))
	var lit := hovered and afford
	var face := Style.BOARD_ROW if afford else Style.BOARD_ROW_OFF
	if lit:
		face = Color(
			face.r * Style.HOVER_WASH.r, face.g * Style.HOVER_WASH.g, face.b * Style.HOVER_WASH.b
		)
	var ink := Style.BOARD_INK if afford else INK_DIM
	Style.plate(self, box, face)
	# A row you can buy carries the lit edge along its top; one you cannot does not. The two
	# faces are 1.30:1 apart in luminance, so told apart by hue alone they are one face to a
	# red-green colourblind player. This is the second channel.
	if afford:
		Style.lit_edge(self, box, face)
	_draw_rail(rail_of(box), row, afford, help_lit)
	# After the rail: the star stands on the rail's own dark corner, and the rail's plate
	# would draw over it the other way round.
	if FEATURED.has(StringName(row.get("key", ""))):
		_draw_featured(box, afford)
	var text_at := box.position.x + RAIL_WIDE + RAIL_GAP

	var tag_wide := box.size.x * TAG_SHARE
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
		# Both lines stop short of the tag: a line under a price reads as a bug, a short line
		# as a short line. The name drops a size and is then cut; so is the value.
		var tag := _tag_of(box, tag_wide, String(row.get("cost", "")), Style.TEXT_BODY)
		var room := (tag.position.x if tag.size.x > 0.0 else box.end.x) - 8.0 - text_at
		var name_size := Style.TEXT_BODY
		if Style.measure(name, name_size).x > room:
			name_size = Style.TEXT_SMALL
		Style.write(self, _cut_to(name, name_size, room), name_size, Vector2(text_at, first), ink)
		var value_size := Style.TEXT_SMALL
		if Style.measure(value, value_size).x > room:
			value_size = Style.TEXT_TINY
		# The value is written in the row's own ink, not a quarter of the way back into the
		# face. That lerp put the line at 1.82:1 on an unaffordable row, under every contrast
		# floor there is; the size ladder already says which of the two lines is the heading.
		Style.write(
			self, _cut_to(value, value_size, room), value_size,
			Vector2(text_at, first + 6.0 + float(Style.TEXT_SMALL) * 0.62), ink
		)
	_draw_tag(
		Rect2(
			Vector2(box.end.x - tag_wide - 6.0, box.position.y + 8.0),
			Vector2(tag_wide, box.size.y - 16.0)
		),
		String(row.get("cost", "")), Style.TEXT_BODY, afford, lit
	)


## The rail: one sunk column down the left of a row, the "?" in its top half and the level's
## figure in its bottom.
##
## "Lvl 20" on the name line cost 47px of a row's 108 — 43% of its writing — for something
## this file's own comment calls a footnote, and the "?" hung on the row's corner was the
## smallest target on the board. Stacked in a rail they cost one narrow column and both grow
## a hit box. The figure goes bare: "Lvl" is a word the row does not need and a translation
## would have to carry, and the rail is what says the figure is a level.
func _draw_rail(box: Rect2, row: Dictionary, afford: bool, help_lit: bool) -> void:
	var face := Style.BOARD.lerp(Style.SEAM, 0.25)
	if help_lit:
		face = Color(
			face.r * Style.HOVER_WASH.r, face.g * Style.HOVER_WASH.g, face.b * Style.HOVER_WASH.b
		)
	Style.plate(self, box, face, 2.0)
	var half := box.size.y * 0.5
	Style.write(
		self, "?", Style.TEXT_SMALL,
		Vector2(0.0, box.position.y + half * 0.5 + float(Style.TEXT_SMALL) * 0.36),
		Style.PRICE_INK if afford else Style.PRICE_INK.lerp(Style.FRAME_LOW, 0.35),
		HORIZONTAL_ALIGNMENT_CENTER, Rect2(box.position, Vector2(box.size.x, half))
	)
	var level := String(row.get("level", ""))
	if level.is_empty():
		return
	Style.write(
		self, level, Style.TEXT_TINY,
		Vector2(0.0, box.position.y + half * 1.5 + float(Style.TEXT_TINY) * 0.36),
		Style.LEVEL_INK, HORIZONTAL_ALIGNMENT_CENTER,
		Rect2(Vector2(box.position.x, box.position.y + half), Vector2(box.size.x, half))
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
	Style.write(self, title, Style.TEXT_BODY, at, Style.PAPER_HEAD)
	at.y += 6.0 + line_tall
	for line in lines:
		Style.write(self, line, Style.TEXT_SMALL, at, Style.PAPER_INK)
		at.y += line_tall


## How tall the legend wants to be: the materials over their prices, the tiers, the line,
## and their padding, in the board's wood.
func _legend_tall() -> float:
	var line := float(Style.TEXT_SMALL) + LEGEND_LINE
	# Five lines: the materials over their prices, the bonus's own line, and two of rule.
	var inner := LEGEND_PAD * 2.0 + line * 5.0 + LEGEND_GAP_ROW * 2.0
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
	var bonus: Dictionary = legend.get("bonus", {})
	var boosted := int(bonus.get("kind", -1))
	# Figures stand on a plate, words on the paper: the price's gold and the lit yard were
	# picked against the dark face and gold on cream is 1.6:1.
	# Its foot is the line the rule's own first line stands on, less that line's own reach
	# above its baseline: measured off `at.y`'s walk rather than guessed, or the plate runs
	# under the sentence and cuts it in half.
	var plate_top := face.position.y + LEGEND_PAD * 0.5
	var plate_foot := at.y + line_tall * 3.0 + LEGEND_GAP_ROW - float(Style.TEXT_SMALL) - 4.0
	Style.plate(self, Rect2(
		Vector2(face.position.x + LEGEND_PAD * 0.5, plate_top),
		Vector2(face.size.x - LEGEND_PAD, plate_foot - plate_top)
	), Style.BOARD, 3.0)
	if not yards.is_empty():
		var step := wide / float(yards.size())
		for y in yards.size():
			var pair: Array = yards[y]
			var slot := Rect2(Vector2(at.x + step * float(y), 0.0), Vector2(step, 0.0))
			var lit := bonus_panel(
				_ink_box(String(pair[0]), slot, at.y), _ink_box(String(pair[1]), slot, at.y + line_tall),
				Rect2(Vector2(slot.position.x, plate_top), Vector2(step, plate_foot - plate_top))
			)
			if y == boosted:
				_light_yard(lit)
			Style.write(self, String(pair[0]), Style.TEXT_SMALL, Vector2(0.0, at.y), Style.BOARD_INK,
				HORIZONTAL_ALIGNMENT_CENTER, slot)
			# The figure is already the boosted one for the boosted kind: `_mean_pay_of` goes
			# through `piece_pay`, which multiplies it. Nothing here recomputes it.
			Style.write(self, String(pair[1]), Style.TEXT_SMALL, Vector2(0.0, at.y + line_tall),
				Style.PRICE_INK if y != boosted else Style.PRICE_INK * Style.HOVER_WASH,
				HORIZONTAL_ALIGNMENT_CENTER, slot)
			if y == boosted:
				_bonus_glitter(lit, _ink_box(String(pair[0]), slot, at.y).merge(
					_ink_box(String(pair[1]), slot, at.y + line_tall)))
		at.y += line_tall * 2.0 + LEGEND_GAP_ROW
	# The bonus's line is reserved whether or not one is running: a plate that grows a line
	# every thirty seconds re-centres the whole shop every thirty seconds.
	if not bonus.is_empty():
		Style.write(
			self, "Bonus yard: %s for %ds" % [String(bonus.get("pct", "")), int(bonus.get("seconds", 0))],
			Style.TEXT_SMALL, Vector2(0.0, at.y), Style.PRICE_INK,
			HORIZONTAL_ALIGNMENT_CENTER, Rect2(Vector2(at.x, 0.0), Vector2(wide, 0.0))
		)
	at.y += line_tall
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
		Style.write(self, line, Style.TEXT_SMALL, at, Style.PAPER_INK)
		at.y += line_tall


## Where a centred line of legend text actually puts ink: its measured width centred in the
## slot, from the font's ascent over the baseline to its descent under it.
func _ink_box(text: String, slot: Rect2, baseline: float) -> Rect2:
	var span := Style.measure(text, Style.TEXT_SMALL)
	var face := Style.font()
	var up := face.get_ascent(Style.TEXT_SMALL)
	return Rect2(
		Vector2(slot.position.x + (slot.size.x - span.x) * 0.5, baseline - up),
		Vector2(span.x, up + face.get_descent(Style.TEXT_SMALL))
	)


## The boosted material's lit panel (2026-09-24, Richard: it was cut and out of place). It
## used to be the whole slot less four pixels, at a height guessed off the line spacing, so
## it ran off the dark plate at the top and hung past the figure at the foot. Now it is the
## name and the figure together, `BONUS_PAD` over and under and `BONUS_SIDE` either side, held inside the slot and the plate.
static func bonus_panel(name_box: Rect2, figure_box: Rect2, room: Rect2) -> Rect2:
	var want := name_box.merge(figure_box).grow_individual(BONUS_SIDE, BONUS_PAD, BONUS_SIDE, BONUS_PAD)
	var inner := room.grow(-2.0)
	var top := maxf(want.position.y, inner.position.y)
	var foot := minf(want.end.y, inner.end.y)
	var left := maxf(want.position.x, inner.position.x)
	var right := minf(want.end.x, inner.end.x)
	return Rect2(Vector2(left, top), Vector2(right - left, foot - top)).abs()


## The lit panel behind the boosted material: the row's own affordable face and the lit edge
## it carries, so "this one is live" is said in the language the rows already say it in.
func _light_yard(box: Rect2) -> void:
	Style.plate(self, box, Style.BOARD_ROW, 2.0)
	Style.lit_edge(self, box, Style.BOARD_ROW)


## The glitter over it: the same four-point gold stars `Dropoff.Shine` puts on the boosted
## yard's box out at the pier, so the plate and the lake say it with one mark. In the panel's
## side margins only (`bonus_star_at`) — a star sitting in a price reads as a glyph. Fixed spots off one seed: a plate that twinkles is a
## plate that redraws every frame, and this one is behind a menu.
func _bonus_glitter(box: Rect2, words: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = BONUS_STAR_SEED
	for i in BONUS_STARS:
		var at := bonus_star_at(box, words, i % 2 == 0, rng.randf(), rng.randf())
		draw_set_transform(at.floor(), 0.0, Vector2.ONE)
		LakeGrid.GlintTwinkle.draw_star(self, i % 2 == 0, 0.55 + rng.randf() * 0.45)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Where a star stands on the lit panel: in the side margins `BONUS_SIDE` leaves beside the
## name and the figure, alternating sides, held a star's reach in from every edge. On the
## top edge, where they were, they crossed the dark plate's top onto the paper and sat on
## the name (2026-09-24). `across` and `down` are 0..1; `words` is the name and figure's box.
static func bonus_star_at(panel: Rect2, words: Rect2, left: bool, across: float, down: float) -> Vector2:
	var reach := LakeGrid.STAR_PIXEL * (float(LakeGrid.STAR_ARM) + 0.5)
	var from := panel.position.x + reach if left else words.end.x + reach
	var to := words.position.x - reach if left else panel.end.x - reach
	var top := panel.position.y + reach
	var foot := maxf(panel.end.y - reach, top)
	return Vector2(lerpf(from, maxf(to, from), across), lerpf(top, foot, down)).floor()


## Where the purse stands while the shop is up (2026-09-24, Richard: "money should be shown on
## upgrade menu"). The HUD's own money plate sits under the first board, so it is hung here
## instead: under the first board, centred on it, in the room between its foot and the
## pricing plate's side. `wanted` is the plate's own size. Empty until the boards are laid.
func purse_box(wanted: Vector2) -> Rect2:
	var first := Rect2()
	for box: Rect2 in _boards.values():
		if first.size.x <= 0.0 or box.position.x < first.position.x:
			first = box
	if first.size.x <= 0.0:
		return Rect2()
	return Rect2(
		Vector2(first.position.x + (first.size.x - wanted.x) * 0.5, first.end.y + PURSE_GAP).round(),
		wanted
	)
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


## Stretch the box of the group this row belongs to down over the row.
func _grow_group(board: StringName, index: int, line: Rect2) -> void:
	var key := StringName(rows[index].get("key", ""))
	for group: Array in GROUPS.get(board, []):
		if key in (group[1] as Array) and _group_boxes.has(group[0]):
			_group_boxes[group[0]] = (_group_boxes[group[0]] as Rect2).merge(line)
			return


## What the card showing is about, in this control's pixels, or an empty rect.
func tour_target() -> Rect2:
	if tour < 0 or tour >= TOUR.size():
		return Rect2()
	var at: Variant = TOUR[tour][0]
	if at is StringName:
		if at == &"legend":
			return _legend_box
		return _boards.get(at, Rect2())
	return (_group_boxes.get(at, Rect2()) as Rect2).grow(4.0)


## A click during the tour: "Skip" ends it, anything else goes on. Nothing is bought and
## nothing hovers; the way out (a click off the boards) is not a way out while it is up —
## the cross and Escape still are.
func _tour_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	Sfx.ui(&"ui_click")
	if _tour_skip.has_point(click.position):
		tour = -1
		tour_ended.emit(true)
	else:
		tour_next()
	queue_redraw()


## The next card, or the end.
func tour_next() -> void:
	if tour < 0:
		return
	tour += 1
	if tour >= TOUR.size():
		tour = -1
		tour_ended.emit(false)
	queue_redraw()


## The dimming with the target cut out of it, its outline, the arrow on its top edge and
## the paper card beside it: the recycle note's card (`FirstSteps`), with the count, "Skip"
## and the prompt to go on.
func _draw_tour() -> void:
	if _tour_layer == null:
		return
	var target := tour_target()
	var view := Rect2(Vector2.ZERO, size)
	if target.size.x <= 0.0:
		_tour_layer.draw_rect(view, TOUR_DIM, true)
		target = Rect2(size * 0.5, Vector2.ZERO)
	else:
		_tour_layer.draw_rect(Rect2(0.0, 0.0, size.x, target.position.y), TOUR_DIM, true)
		_tour_layer.draw_rect(Rect2(0.0, target.end.y, size.x, size.y - target.end.y), TOUR_DIM, true)
		_tour_layer.draw_rect(Rect2(0.0, target.position.y, target.position.x, target.size.y), TOUR_DIM, true)
		_tour_layer.draw_rect(Rect2(target.end.x, target.position.y, size.x - target.end.x, target.size.y), TOUR_DIM, true)
		_tour_layer.draw_rect(target, TOUR_OUTLINE, false, 2.0)
	var px := _prompt_px()
	if _prompt_arrow != null and target.size.x > 0.0:
		var a := _prompt_arrow.get_size() * px
		var corner := Vector2(target.get_center().x - a.x * 0.5, target.position.y - a.y - 2.0).round()
		_tour_layer.draw_set_transform(corner + Vector2(0.0, a.y), 0.0, Vector2(1.0, -1.0))
		_tour_layer.draw_texture_rect(_prompt_arrow, Rect2(Vector2.ZERO, a), false)
		_tour_layer.draw_set_transform(Vector2.ZERO)
	var face := Style.font()
	var size_px := FirstSteps.NOTE_SIZE
	var wide := FirstSteps.NOTE_WIDE
	var pad := FirstSteps.NOTE_PAD
	var lines := FirstSteps._wrap(String(TOUR[tour][1]), face, size_px, wide - pad.x * 2.0)
	var line_tall := face.get_height(size_px) + 1.0
	var icon := _prompt_a if tour_pad else _prompt_mouse
	var icon_size := icon.get_size() * px if icon != null else Vector2.ZERO
	var foot_tall := maxf(line_tall, icon_size.y)
	var tall := pad.y * 2.0 + line_tall * float(lines.size() + 1) + 4.0 + foot_tall
	var card := Rect2(Vector2.ZERO, Vector2(wide, tall).round())
	# Beside the target on whichever side has room; the plate, which fills the foot, above.
	if TOUR[tour][0] is StringName and TOUR[tour][0] == &"legend":
		card.position = Vector2(target.get_center().x - wide * 0.5, target.position.y - tall - TOUR_GAP * 2.0)
	elif target.end.x + TOUR_GAP + wide <= size.x - 4.0 and target.get_center().x < size.x * 0.5:
		card.position = Vector2(target.end.x + TOUR_GAP, target.position.y + target.size.y * 0.2)
	else:
		card.position = Vector2(target.position.x - TOUR_GAP - wide, target.position.y + 10.0)
	card.position.x = clampf(card.position.x, 4.0, size.x - card.size.x - 4.0)
	card.position.y = clampf(card.position.y, 4.0, size.y - card.size.y - 4.0)
	card.position = card.position.round()
	_tour_layer.draw_rect(card.grow(FirstSteps.NOTE_RIM + 1.0), FirstSteps.NOTE_OUTER, true)
	_tour_layer.draw_rect(card, Style.PAPER, true)
	_tour_layer.draw_rect(card.grow(-1.0), Style.PAPER_EDGE, false, FirstSteps.NOTE_RIM)
	var ascent := face.get_ascent(size_px)
	var inner := card.grow_individual(-pad.x, -pad.y, -pad.x, -pad.y)
	_tour_layer.draw_string(face, Vector2(inner.position.x, inner.position.y + ascent), "%d/%d" % [tour + 1, TOUR.size()],
		HORIZONTAL_ALIGNMENT_RIGHT, inner.size.x, size_px, Style.PAPER_SOFT)
	var y := inner.position.y + line_tall + ascent
	for line in lines:
		_tour_layer.draw_string(face, Vector2(card.position.x, y), line, HORIZONTAL_ALIGNMENT_CENTER, card.size.x,
			size_px, Style.PAPER_INK)
		y += line_tall
	var foot_mid := inner.end.y - foot_tall * 0.5
	var base := foot_mid + ascent * 0.5 - 1.0
	var skip_wide := face.get_string_size(TOUR_SKIP, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px).x
	_tour_layer.draw_string(face, Vector2(inner.position.x, base), TOUR_SKIP, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px, Style.PAPER_SOFT)
	_tour_skip = Rect2(inner.position.x - 4.0, foot_mid - foot_tall * 0.5 - 2.0, skip_wide + 8.0, foot_tall + 4.0)
	var icon_at := Vector2(inner.end.x - icon_size.x, foot_mid - icon_size.y * 0.5).round()
	if icon != null:
		_tour_layer.draw_texture_rect(icon, Rect2(icon_at, icon_size), false)
	var go_wide := face.get_string_size(TOUR_CONTINUE, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px).x
	_tour_layer.draw_string(face, Vector2(icon_at.x - 4.0 - go_wide, base), TOUR_CONTINUE, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px, Style.PAPER_INK)


## Canvas pixels to one of the prompt pack's: `FirstSteps.PROMPT_PX` physical ones.
func _prompt_px() -> float:
	var canvas := get_viewport_rect().size.y
	var window := float(get_window().size.y) if get_window() != null else canvas
	return FirstSteps.PROMPT_PX * canvas / maxf(window, 1.0)


func _ensure_tour_layer() -> void:
	if _tour_layer != null:
		move_child(_tour_layer, get_child_count() - 1)
		return
	_tour_layer = Control.new()
	_tour_layer.name = &"Tour"
	_tour_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tour_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_tour_layer)
	_tour_layer.draw.connect(func() -> void:
		if tour >= 0 and tour < TOUR.size():
			_draw_tour()
	)
