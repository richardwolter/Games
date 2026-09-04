## The first-run walkthrough: a handful of cards pointing at the thing they are
## talking about.
##
## Shown once, when a new game starts, and never again unless the player starts
## another one. It is deliberately the cheapest kind of tutorial — read a line,
## click, next — rather than a scripted sequence that makes you perform each step
## before letting you move on. This is a physics sandbox whose whole appeal is
## messing about; a tutorial that insists you place a plank *there* would be
## teaching the opposite lesson.
##
## Each card highlights a real control by cutting a hole in the dim rather than
## drawing a picture of it, so what you read about is the thing you will click a
## second later, wherever the layout has actually put it.
class_name Tutorial
extends Control

signal finished()

## Text and what it points at. The key is looked up through the HUD; an empty key
## means the card has no target and sits in the middle of the screen.
##
## Six cards, in the order a first turn actually happens: what the goal is, where
## pieces come from, how to place them, how to fix a mistake, how to run the
## attempt, and what the run pays for. Anything past that is discoverable, and a
## seventh card is where a player starts clicking NEXT without reading.
const STEPS: Array[Dictionary] = [
	{
		"key": "",
		"title": "OBJECTIVE",
		"body": "Build a bridge across the strait and drive the truck to the far shore.",
	},
	{
		"key": "shop",
		"title": "SALVAGE SHOP",
		"body": "Buy pieces here. Each has its own weight, size, buoyancy and strength.",
	},
	{
		"key": "belt",
		"title": "PLACING PIECES",
		"body": "Click a piece to place it. Drag to move, Q and E to rotate, right-click to put it back.\nPieces do not snap together — they are held up by physics alone.",
	},
	{
		"key": "recall",
		"title": "RECALL ALL",
		"body": "Returns every placed piece to your stock. Nothing is lost.",
	},
	{
		"key": "start",
		"title": "START CROSSING",
		"body": "Sends the truck. You cannot place pieces while it is crossing.",
	},
	{
		"key": "header",
		"title": "LEVEL AND MONEY",
		"body": "You earn money for the distance the truck covers, even if it fails.\nSpend it on more pieces, then try again.",
	},
]

## Gap between a highlighted control and its card.
const CARD_GAP := 18.0
const CARD_WIDTH := 430.0
## How far the highlight ring sits outside the control it rings.
const RING_PAD := 6.0

var _hud: Node
var _step: int = 0
var _card: PanelContainer
var _title: Label
var _body: Label
var _counter: Label
var _next: Button
## The control this card points at, if any. Read every frame while drawing,
## because the dock resizes as its contextual buttons come and go.
var _target: Control = null


## `hud` supplies the controls to point at, through tutorial_anchor().
func begin(hud: Node) -> void:
	_hud = hud
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Swallows everything. A player reading card two should not be able to buy a
	# girder through the dim by accident, and a click anywhere is how you advance.
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_card()
	_show_step(0)


func _build_card() -> void:
	_card = PanelContainer.new()
	UITheme.paint(_card, PaintedBox.board(UITheme.WOOD, 3))
	_card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	_card.add_child(column)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.as_title(_title)
	_title.add_theme_color_override(&"font_color", UITheme.CREAM)
	UITheme.outline(_title, 4)
	column.add_child(_title)

	# The words go on a cream leaf, the same as the settings panel: body text on
	# bare boards is the one place in this UI where reading gets hard.
	var leaf := PanelContainer.new()
	UITheme.paint(leaf, PaintedBox.board(UITheme.CREAM, 0))
	column.add_child(leaf)

	_body = Label.new()
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override(&"font_size", UITheme.FONT_SIZE_LOUD)
	leaf.add_child(_body)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	column.add_child(row)

	# Skip first and quiet, Next last and bright: the common action should be
	# where the hand already is, and the escape hatch should be visible without
	# competing for the click.
	var skip := UITheme.plate_button("SKIP", UITheme.STEEL.darkened(0.34), Vector2(84, 34))
	skip.pressed.connect(_finish)
	row.add_child(skip)

	_counter = Label.new()
	_counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UITheme.as_caption(_counter)
	row.add_child(_counter)

	_next = UITheme.plate_button("NEXT", UITheme.AMBER, Vector2(110, 34))
	_next.pressed.connect(_advance)
	row.add_child(_next)

	UITheme.enliven(self)


func _show_step(index: int) -> void:
	if index >= STEPS.size():
		_finish()
		return
	_step = index
	var step: Dictionary = STEPS[index]
	_title.text = step["title"]
	_body.text = step["body"]
	_counter.text = "%d / %d" % [index + 1, STEPS.size()]
	_next.text = "NEXT" if index < STEPS.size() - 1 else "BUILD"

	var key: String = step["key"]
	_target = null
	if key != "" and _hud != null and _hud.has_method(&"tutorial_anchor"):
		_target = _hud.call(&"tutorial_anchor", key) as Control
	_place_card()
	queue_redraw()


## Puts the card beside its target — below if the target is in the top half of
## the screen, above if it is in the bottom — and dead centre when there is no
## target. Clamped to the screen afterwards, so a card pointing at the corner
## readout doesn't hang off the edge.
func _place_card() -> void:
	var wanted := _card.get_combined_minimum_size()
	# The viewport, not this control's own size: the first card is positioned on
	# the frame the overlay is added, before any layout pass has given it one, so
	# centring against `size` centred it on a zero rect and put the card off the
	# top-left of the screen. The overlay is full-rect, so these are the same
	# number everywhere except on that first frame.
	var screen := get_viewport_rect().size
	var where: Vector2
	if _target == null or not is_instance_valid(_target):
		where = (screen - wanted) * 0.5
	else:
		var ring := _target.get_global_rect()
		where.x = ring.get_center().x - wanted.x * 0.5
		if ring.get_center().y < screen.y * 0.5:
			where.y = ring.end.y + CARD_GAP
		else:
			where.y = ring.position.y - wanted.y - CARD_GAP
	_card.position = Vector2(
		clampf(where.x, 16.0, maxf(screen.x - wanted.x - 16.0, 16.0)),
		clampf(where.y, 16.0, maxf(screen.y - wanted.y - 16.0, 16.0))
	)
	_card.size = wanted


func _process(_delta: float) -> void:
	# The dock changes height as contextual buttons appear, and the window can be
	# resized mid-sentence, so the hole and the card follow their target rather
	# than being positioned once. Targetless cards are re-placed too, or a card
	# centred on one window size stays where it was when the window changes.
	_place_card()
	queue_redraw()


## The dim, with a hole cut for the highlighted control.
##
## Four rects around the target rather than one rect with a hole, because a
## Control cannot subtract from what it has already drawn. The upside is that the
## highlighted control is genuinely undimmed — it is the real button at full
## brightness, not a copy drawn on top.
func _draw() -> void:
	var shade := Color(UITheme.INK, 0.62)
	if _target == null or not is_instance_valid(_target):
		draw_rect(Rect2(Vector2.ZERO, size), shade)
		return

	var hole := _target.get_global_rect().grow(RING_PAD)
	draw_rect(Rect2(0, 0, size.x, hole.position.y), shade)
	draw_rect(Rect2(0, hole.end.y, size.x, size.y - hole.end.y), shade)
	draw_rect(Rect2(0, hole.position.y, hole.position.x, hole.size.y), shade)
	draw_rect(
		Rect2(hole.end.x, hole.position.y, size.x - hole.end.x, hole.size.y), shade
	)

	# A ring in the mustard the rest of the chrome uses, so it reads as "this
	# one" rather than as a selection box from another program.
	draw_rect(hole, UITheme.MUSTARD, false, 3.0)


## A click anywhere advances, which is what a player who has finished reading
## does without being told. Clicks on the card's own buttons never reach here.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_advance()
			accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.is_echo():
		return
	var key := (event as InputEventKey).keycode
	if key == KEY_ESCAPE:
		_finish()
	elif key == KEY_SPACE or key == KEY_ENTER or key == KEY_KP_ENTER:
		_advance()
	else:
		return
	get_viewport().set_input_as_handled()


func _advance() -> void:
	_show_step(_step + 1)


func _finish() -> void:
	finished.emit()
	queue_free()
