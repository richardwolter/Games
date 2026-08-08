## The Salvage Shop: buying happens here and nowhere else.
##
## It's a modal over a dimmed strait rather than a permanent panel because
## shopping and building are separate moments — you buy a handful of pieces, then
## you spend a long time arranging them. Keeping the catalogue on screen during
## the arranging would cost width for something you look at once a minute.
##
## Cards are rebuilt on every level load, because the pool and the stock limits
## are per level. Prices and affordability are refreshed in place, because those
## change on every purchase.
class_name ShopMenu
extends Control

signal buy_requested(def: ObjectDef)
signal box_requested(box: BoxDef)
## Experimental only: a level of a SalvageUpgrades.Kind. Carried as an int so the
## menu doesn't have to know the enum.
signal upgrade_requested(kind: int)
signal closed()

## Starting column count. The grid widens rather than growing a third row, so
## the menu's height stays predictable no matter what a level stocks.
const COLUMNS := 4
## The grid is always this many rows deep at most. Two rows of cards, a header
## and the box strip is what fits in 720p without scrolling.
## Kept only as the floor for the frame's width; the row count itself now falls
## out of how many cards fit across the viewport.
const ROWS := 2
## Cards are as wide as they can be while still standing in one row.
##
## The project stretches with a fixed 1280-unit canvas, so going fullscreen buys
## no extra width at all — 1280 is the whole budget on every monitor, and the
## band above the dock is about 560 units tall. A fixed 190 meant seven pieces
## became two rows, 762 units tall, which then had to be scaled to 0.73 to fit:
## a nominally 190px card rendering at 140 with 12px lettering. Narrowing the
## card to fit one row and NOT scaling is the better trade in every direction —
## the type stays the size it says it is.
const CARD_MIN := 152
const CARD_MAX := 190
## Gap between cards, and between boxes.
const GRID_GAP := 14
## The booster card: how tall its pack picture is, and how wide the card is.
##
## Deliberately narrower than a piece card. A pack is a tall portrait and the
## card carries almost no text now, so it wants height rather than width — and at
## this width all four tiers stand across the 1280 canvas in one line with the
## flow container never having to wrap them.
const PACK_HEIGHT := 132.0
const BOX_CARD_WIDTH := 132.0
## Height of the sprite well at the top of each card. This is the card's whole
## job — you pick a girder out of the shop by its shape — so it took most of the
## height the single row freed up.
const ART_HEIGHT := 66
## The painted SALVAGE SHOP sign at the top of the header.
const TITLE_ART_HEIGHT := 58.0
## Card lettering, sized to be read rather than to fit. The detail lines carry
## the traits and the stock count, which are what a player is actually comparing
## between cards, so they sit only one step under the name.
const NAME_SIZE := 17
const DETAIL_SIZE := 14
## Space kept clear at the bottom for the dock and at the top for the readouts.
## The dock's height follows its contents, so this is the tallest it gets plus a
## little air rather than a measurement taken at runtime.
const DOCK_RESERVE := 130.0
const TOP_RESERVE := 14.0

var _economy: Economy
var _shop: Shop
## The experimental truck upgrades. Null on a normal build, and the row that
## shows them is then never built.
var _upgrades: SalvageUpgrades
## The BUY on each upgrade, and the line under it saying what it does next.
var _upgrade_rows: Dictionary[int, Dictionary] = {}

var _frame: PanelContainer
## This level's catalogue, kept so the grid can be reflowed without rebuilding.
var _pool: Array[ObjectDef] = []
var _card_width: int = CARD_MAX
var _money_label: Label
var _grid: GridContainer
var _box_column: VBoxContainer
## Per-card widgets that need refreshing when money or stock changes.
var _cards: Dictionary[ObjectDef, Dictionary] = {}
var _box_buttons: Dictionary[BoxDef, Button] = {}
## The strip under the header that reports what a box just paid out.
var _flash: Label


func setup(economy: Economy, shop: Shop, upgrades: SalvageUpgrades = null) -> void:
	_economy = economy
	_shop = shop
	_upgrades = upgrades
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	# Hidden the menu must not eat clicks meant for the strait; open it must eat
	# all of them, including on the dimmed area outside the panel.
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_chrome()

	# Clicking the dimmed strait around the panel closes the shop, the same as
	# the X and Escape. The dim is already there to say "this is modal"; making
	# it clickable is what most players will try first.
	UITheme.dismiss_on_outside_click(self, _frame, close_menu)

	_economy.money_changed.connect(func(_amount: int) -> void: _refresh())
	_shop.stock_changed.connect(_refresh)
	if _upgrades != null:
		_upgrades.changed.connect(_refresh)
	_shop.box_opened.connect(_on_box_opened)
	_shop.purchase_failed.connect(_on_purchase_failed)


func _build_chrome() -> void:
	var dim := ColorRect.new()
	dim.color = Color(UITheme.INK, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Transparent to the mouse, so a click on the dimmed strait reaches this menu
	# and closes it. A ColorRect stops input by default.
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	# A CenterContainer rather than a centre anchor preset: the frame's height
	# depends on how many cards the level stocks, and only a container recentres
	# it when that minimum size changes.
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Centred on the strait, not on the screen. The dock owns the bottom of the
	# window, so a panel centred on the full rect hangs its last row of BUY
	# buttons behind the dock — which at fullscreen, where there is plenty of
	# room, still read as the menu being cut off at the bottom.
	centre.offset_bottom = -DOCK_RESERVE
	centre.offset_top = TOP_RESERVE
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	var frame := PanelContainer.new()
	_frame = frame
	# Painted crate boards, matching the SALVAGE SHOP sign on the dock that opens
	# this. The menu already tried to read as "that button expanded" by borrowing
	# its accent colour; with the boards it borrows the material too, which is the
	# part that was doing the work on the sign.
	#
	# NOT the kit's SALVAGE SHOP frame, which was tried here and cannot hold this
	# panel: the title is painted across its top rail, and at seven cards this
	# panel is five times the width the artwork was drawn at, so the lettering
	# stretched with the rail. Its scrap-metal frame has the same problem in a
	# different place — the pipework in its middle stretched into streaks. Either
	# needs the shop to be roughly the width it was drawn at, or the header cut
	# out as a sprite of its own.
	UITheme.paint(frame, PaintedBox.board(UITheme.WOOD, 5))
	# A floor, not a cap: a level stocking more than COLUMNS * ROWS pieces widens
	# the grid past this and the frame follows.
	frame.custom_minimum_size = Vector2(
		COLUMNS * CARD_MIN + (COLUMNS - 1) * GRID_GAP + 44, 0
	)
	centre.add_child(frame)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 8)
	frame.add_child(column)

	column.add_child(_build_header())

	_flash = Label.new()
	_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Sits on bare boards, so it carries its own outline the same way the banner
	# over the strait does.
	UITheme.outline(_flash, 4)
	_flash.add_theme_font_size_override(&"font_size", UITheme.FONT_SIZE_LOUD)
	_flash.text = ""
	column.add_child(_flash)

	# Nothing here scrolls. The whole catalogue has to be comparable at a glance
	# — that is the decision the menu exists to support — and a scrollbar hides
	# exactly the piece you were about to weigh against the one on screen.
	# stock_for_level() reflows the grid to keep it to ROWS rows instead.
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 6)
	column.add_child(body)

	# Boosters first, catalogue second. They were at the foot of the panel, under
	# two rows of cards, which is where a player's eye arrives last and often not
	# at all — and the gamble is the more interesting of the two purchases and the
	# one that gets you out of a stuck level. It is also the shorter section, so
	# putting it on top costs the pieces nothing: the grid still gets every row it
	# asked for, just lower down.
	# The truck upgrades, on an experimental build. Built here rather than in
	# stock_for_level(), which is rebuilt on every level load — these are the one
	# thing in the shop that is not per level, and rebuilding them with the
	# catalogue would say the opposite.
	if _upgrades != null and Experimental.on():
		body.add_child(_build_upgrade_row())

	_box_column = VBoxContainer.new()
	_box_column.add_theme_constant_override(&"separation", 6)
	body.add_child(_box_column)

	body.add_child(_heading("PIECES"))
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override(&"h_separation", GRID_GAP)
	_grid.add_theme_constant_override(&"v_separation", GRID_GAP)
	body.add_child(_grid)


func _build_header() -> Control:
	var strip := PanelContainer.new()
	# The dark plate the level readout uses, so the menu's header and the game's
	# header are the same object. The blue tin sign is gone: the title is now the
	# painted SALVAGE SHOP artwork itself, and a coloured field behind painted
	# artwork only ever fights it.
	UITheme.paint(strip, PaintedBox.sign(UITheme.SLATE))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	strip.add_child(row)

	# The literal sign off the dock button that opened this, rather than a drawn
	# mark plus the words. It already says SALVAGE SHOP in the game's own hand —
	# setting the same words again in the UI font said it twice, in two voices.
	var title := UITheme.art_image("salvage_shop", TITLE_ART_HEIGHT)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	_money_label = Label.new()
	_money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_money_label.add_theme_font_size_override(&"font_size", UITheme.FONT_SIZE_TITLE)
	_money_label.add_theme_color_override(&"font_color", UITheme.GOLD)
	row.add_child(_money_label)

	# A plain capital X, not "✕" (U+2715). The project ships no font file, so every
	# control renders in Godot's built-in default — a subset of Open Sans that has
	# no multiplication-X in it, and the button came out as an empty tofu box.
	# Same trap painted_box.gd hit with U+266A. Anything outside basic Latin has to
	# be drawn rather than typed here.
	var close := UITheme.plate_button("X", UITheme.STEEL.darkened(0.34), Vector2(40, 30))
	close.tooltip_text = "Close the shop"
	close.pressed.connect(close_menu)
	row.add_child(close)
	return strip


## Card detail lines. Bigger and darker than UITheme.as_heading(), which is tuned
## for labels you are meant to skim past — on a card that has shrunk, the traits
## and the stock count are the reading matter.
func _as_detail(label: Label) -> void:
	label.add_theme_font_size_override(&"font_size", DETAIL_SIZE)
	label.add_theme_color_override(&"font_color", UITheme.SUBTLE_TEXT.darkened(0.25))


## Section headings sit straight on the boards, not inside a card, so they take
## the on-wood treatment rather than the on-cream one.
func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	UITheme.as_caption(label)
	# One step up from the caption default: these are the only labels naming the
	# two halves of the catalogue, and at 11px on boards they were decoration.
	label.add_theme_font_size_override(&"font_size", DETAIL_SIZE)
	return label


## Rebuild the catalogue for a level. Called on every level load.
func stock_for_level(level: LevelDef) -> void:
	for child: Node in _grid.get_children():
		child.free()
	for child: Node in _box_column.get_children():
		child.free()
	_cards.clear()
	_box_buttons.clear()

	var pool: Array[ObjectDef] = []
	for def: ObjectDef in level.shop_pool:
		if not pool.has(def):
			pool.append(def)

	# Spend width before height. The frame's width follows the grid, and the
	# CenterContainer keeps it centred as that changes.
	_pool = pool
	_reflow()
	for def: ObjectDef in pool:
		_grid.add_child(_build_card(def))

	if not level.boxes.is_empty():
		_box_column.add_child(_heading("BOOSTER PACKS"))
		# Boosters side by side, not stacked. Three stacked rows cost 242px of
		# height — a quarter of the panel — to say three short things that fit
		# side by side in width the panel already had.
		#
		# A flow rather than a fixed row, because level 4 sells four tiers and four
		# will not fit across 1280 once each carries its pack picture. Flowing puts
		# them on two lines there and leaves every earlier level's single line
		# exactly as it was.
		var boxes := HFlowContainer.new()
		boxes.add_theme_constant_override(&"h_separation", GRID_GAP)
		boxes.add_theme_constant_override(&"v_separation", GRID_GAP)
		# Centred, because the packs are narrow and the frame is as wide as the
		# piece grid — left-aligned, one or two tiers sit in the corner of a mostly
		# empty strip and read as the row having failed to fill.
		boxes.alignment = FlowContainer.ALIGNMENT_CENTER
		_box_column.add_child(boxes)
		for box: BoxDef in level.boxes:
			boxes.add_child(_build_box_row(box))

	_flash.text = ""
	_refresh()
	UITheme.enliven(self)


## How many cards go across, decided by how much width the screen actually has.
##
## A fixed column count was the whole problem: on a 1280 window seven pieces
## became two rows and the panel needed 910px of height, and on a fullscreen
## 1920 it *still* became two rows and left a third of the screen empty either
## side. Measuring the viewport means a wide screen genuinely spends its width —
## the catalogue goes across in one row and the panel is half as tall.
##
## Floored at COLUMNS so a level stocking two pieces still gets a panel wide
## enough to hang the header's sign and money readout on.
func _preferred_columns(count: int) -> int:
	var by_width: int = maxi(
		int((_room() + GRID_GAP) / float(_card_width + GRID_GAP)), 1
	)
	return clampi(count, COLUMNS, maxi(by_width, COLUMNS))


## Width the grid has to play with. The 104 is the frame's own painted margins
## (44) plus the clearance the fit-scaler keeps at the screen edges (32 each
## side, halved here since it is measured off the full width) — without taking
## those off, the grid sizes itself to a frame slightly wider than the screen and
## the scaler then shrinks everything by a few percent for no reason.
func _room() -> float:
	return maxf(get_viewport_rect().size.x - 104.0, float(CARD_MIN))


## Sets the card width, the grid's shape and the frame's width from the current
## viewport. Called on every level load and on every open, because the window can
## change between the two.
func _reflow() -> void:
	if _frame == null:
		return
	var count: int = _pool.size()
	if count > 0:
		# The widest card that still lets the whole catalogue stand in one row.
		# Past CARD_MIN it stops narrowing and takes a second row instead — below
		# that a card is too cramped to carry a sprite and four lines of text.
		_card_width = clampi(
			int((_room() - float(count - 1) * GRID_GAP) / float(count)),
			CARD_MIN, CARD_MAX
		)
	_grid.columns = _preferred_columns(count)
	# Existing cards were built at the previous width, so they are re-pinned
	# rather than rebuilt — a rebuild here would drop the hover motion and the
	# refresh state with it.
	for widgets: Dictionary in _cards.values():
		var card: PanelContainer = widgets[&"card"]
		card.custom_minimum_size.x = _card_width
	_frame.custom_minimum_size.x = (
		_grid.columns * _card_width + (_grid.columns - 1) * GRID_GAP + 44
	)


func _build_card(def: ObjectDef) -> Control:
	var card := PanelContainer.new()
	# Cream boards: the card is a tag pinned to the crate, so it wants the same
	# painted edge and top light as everything else — just no grain or bolts,
	# which at card size would be louder than the piece's own sprite.
	UITheme.paint(card, PaintedBox.board(UITheme.CREAM, 0))
	card.custom_minimum_size = Vector2(_card_width, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 3)
	card.add_child(column)

	# The sprite sits in a recessed well so pieces with pale artwork (the fridge)
	# don't dissolve into the card.
	var well := PanelContainer.new()
	var well_box := PaintedBox.board(UITheme.CREAM_DIM, 0)
	well_box.radius = UITheme.RADIUS
	well_box.set_margins(6, 4)
	well.add_theme_stylebox_override(&"panel", well_box)
	well.custom_minimum_size = Vector2(0, ART_HEIGHT)
	column.add_child(well)

	var art := TextureRect.new()
	art.texture = def.get_texture(0)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2(0, ART_HEIGHT - 12)
	# A def with no artwork still needs a readable card, so fall back to the flat
	# colour the piece is drawn with in the world.
	if art.texture == null:
		art.modulate = def.color
		art.texture = _swatch(def.color)
	well.add_child(art)

	var name_label := Label.new()
	name_label.text = def.display_name
	name_label.add_theme_font_size_override(&"font_size", NAME_SIZE)
	# Names run to "Refrigerator" at 156px, so a long one wraps rather than being
	# clipped by the card it names.
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(name_label)

	var traits := Label.new()
	traits.text = def.descriptor()
	_as_detail(traits)
	traits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(traits)

	var stock := Label.new()
	_as_detail(stock)
	column.add_child(stock)

	var buy := Button.new()
	buy.custom_minimum_size = Vector2(0, 36)
	buy.add_theme_font_size_override(&"font_size", DETAIL_SIZE + 1)
	buy.pressed.connect(func() -> void: buy_requested.emit(def))
	column.add_child(buy)

	_cards[def] = {&"card": card, &"stock": stock, &"buy": buy, &"art": art}
	return card


## One booster tier, built the same way a piece card is: the goods, then what
## they cost.
##
## The packs are drawn objects with their own tier name and their own metal on
## them, so the panel says almost nothing. It used to be a full-width coloured bar
## carrying the tier name in outlined caps and a line of value arithmetic, with a
## thumbnail alongside — which put the loudest thing on the screen next to the one
## element that was already doing the job. The bar is gone, the name is gone (it
## is printed on the pack), the expected-value line is gone, and what is left is
## the pack at four times the size on a lit tier-coloured well.
func _build_box_row(box: BoxDef) -> Control:
	var card := PanelContainer.new()
	UITheme.paint(card, PaintedBox.board(UITheme.CREAM, 0))
	card.custom_minimum_size = Vector2(BOX_CARD_WIDTH, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 3)
	card.add_child(column)

	# The well is tinted with the tier colour rather than the cards' dim cream:
	# it is the only colour left on the card now that the bar has gone, and a
	# bright ground behind foil and brushed metal is what makes them read as foil
	# and brushed metal rather than as grey paper.
	var well := PanelContainer.new()
	var well_box := PaintedBox.board(box.color.lerp(UITheme.CREAM, 0.45), 0)
	well_box.radius = UITheme.RADIUS
	well_box.set_margins(6, 4)
	well.add_theme_stylebox_override(&"panel", well_box)
	well.custom_minimum_size = Vector2(0, PACK_HEIGHT)
	column.add_child(well)

	if box.art != null:
		var pack := TextureRect.new()
		pack.texture = box.art
		pack.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pack.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pack.custom_minimum_size = Vector2(0, PACK_HEIGHT - 10)
		well.add_child(pack)
	else:
		# No artwork yet: name the tier, since nothing else on the card does.
		var fallback := Label.new()
		fallback.text = box.display_name.to_upper()
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		well.add_child(fallback)

	# The one fact the pack itself cannot show. Not "about $51 of shop value" —
	# that asked the player to do arithmetic to decide whether to gamble, and the
	# gamble is meant to be a shrug, not a calculation.
	var count := Label.new()
	count.text = "%d random pieces" % box.piece_count
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.as_caption(count)
	column.add_child(count)

	var buy := Button.new()
	buy.custom_minimum_size = Vector2(0, 34)
	buy.add_theme_font_size_override(&"font_size", DETAIL_SIZE + 1)
	buy.pressed.connect(func() -> void: box_requested.emit(box))
	column.add_child(buy)
	_box_buttons[box] = buy
	return card


## EXPERIMENTAL — the battery truck's two upgrades.
##
## The first things in the shop that stay bought: a piece is spent and an upgrade
## isn't, and both being on the same counter is the point. Levelled rather than
## priced per unit, so what the player reads is "two more dunks" rather than a
## percentage.
func _build_upgrade_row() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	column.add_child(_heading("TRUCK UPGRADES"))

	var row := HFlowContainer.new()
	row.add_theme_constant_override(&"h_separation", GRID_GAP)
	row.add_theme_constant_override(&"v_separation", GRID_GAP)
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	column.add_child(row)

	row.add_child(_build_upgrade_card(
		SalvageUpgrades.Kind.CAPACITY,
		"BATTERY",
		"How long the electric truck can run before it stops."
	))
	row.add_child(_build_upgrade_card(
		SalvageUpgrades.Kind.SEALING,
		"WATER SEALING",
		"How much charge a dunk in the strait costs."
	))
	return column


func _build_upgrade_card(kind: int, title: String, blurb: String) -> Control:
	var card := PanelContainer.new()
	UITheme.paint(card, PaintedBox.board(UITheme.CREAM, 0))
	card.custom_minimum_size = Vector2(CARD_MIN + 40, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 3)
	card.add_child(column)

	var name_label := Label.new()
	name_label.text = title
	name_label.add_theme_font_size_override(&"font_size", NAME_SIZE)
	column.add_child(name_label)

	var about := Label.new()
	about.text = blurb
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_as_detail(about)
	column.add_child(about)

	var level := Label.new()
	_as_detail(level)
	column.add_child(level)

	var effect := Label.new()
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_as_detail(effect)
	column.add_child(effect)

	var buy := Button.new()
	buy.custom_minimum_size = Vector2(0, 34)
	buy.add_theme_font_size_override(&"font_size", DETAIL_SIZE + 1)
	buy.pressed.connect(func() -> void: upgrade_requested.emit(kind))
	column.add_child(buy)

	_upgrade_rows[kind] = {&"card": card, &"level": level, &"effect": effect, &"buy": buy}
	return card


func _refresh_upgrades() -> void:
	if _upgrades == null:
		return
	for kind: int in _upgrade_rows:
		var widgets: Dictionary = _upgrade_rows[kind]
		var level: Label = widgets[&"level"]
		var effect: Label = widgets[&"effect"]
		var buy: Button = widgets[&"buy"]
		var at := _upgrades.level_of(kind as SalvageUpgrades.Kind)
		var cost := _upgrades.cost_of(kind as SalvageUpgrades.Kind)

		level.text = "Level %d of %d" % [at, SalvageUpgrades.MAX_LEVEL]
		effect.text = _upgrades.effect_of(kind as SalvageUpgrades.Kind)
		if cost < 0:
			buy.text = "MAXED"
			buy.disabled = true
		else:
			var affordable := _economy.can_afford(cost)
			buy.text = ("UPGRADE  $%d" if affordable else "NEED $%d") % cost
			buy.disabled = not affordable
		_set_buy_style(buy)
		var card: PanelContainer = widgets[&"card"]
		card.modulate = Color.WHITE if not buy.disabled else Color(1, 1, 1, 0.55)


## A 1x1 texture, so a def with no artwork can still use the TextureRect path.
func _swatch(color: Color) -> Texture2D:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, color)
	return ImageTexture.create_from_image(image)


func _refresh() -> void:
	if _economy == null:
		return
	_money_label.text = "$%d" % _economy.money

	for def: ObjectDef in _cards:
		var left := _shop.remaining(def)
		var affordable := _economy.can_afford(def.price)
		var widgets: Dictionary = _cards[def]
		var stock: Label = widgets[&"stock"]
		var buy: Button = widgets[&"buy"]

		stock.text = "sold out" if left <= 0 else "%d left" % left
		# The plate on the pipe states the reason it can't be pressed, so a
		# disabled card never needs a tooltip to explain itself. The word BUY is
		# painted into the pipe and stays put; only the plate changes.
		buy.disabled = left <= 0 or not affordable
		# The button states the reason it can't be pressed, so a disabled card
		# never needs a tooltip to explain itself.
		if left <= 0:
			buy.text = "SOLD OUT"
		elif not affordable:
			buy.text = "NEED $%d" % def.price
		else:
			buy.text = "BUY  $%d" % def.price
		_set_buy_style(buy)
		# Unaffordable and sold-out cards fade so the row you *can* act on pops.
		var card: PanelContainer = widgets[&"card"]
		card.modulate = Color.WHITE if not buy.disabled else Color(1, 1, 1, 0.55)

	_refresh_upgrades()

	for box: BoxDef in _box_buttons:
		var button := _box_buttons[box]
		button.disabled = not _economy.can_afford(box.price)
		button.text = "$%d" % box.price
		_set_buy_style(button)


## Green means "this spends money and will work". Disabled buttons keep the
## theme's grey, so the colour alone carries the affordability read.
##
## The kit's painted BUY pipe was tried here and taken back out: at card width
## the pipe is a thin bar, the price needed a plate bolted over one end to be
## readable at all, and the three states this button carries — affordable, too
## dear, sold out — have nowhere to go on a sprite with one word painted into it.
func _set_buy_style(button: Button) -> void:
	if button.disabled:
		button.remove_theme_stylebox_override(&"normal")
		button.remove_theme_stylebox_override(&"hover")
		button.remove_theme_stylebox_override(&"pressed")
		button.remove_theme_color_override(&"font_color")
		return
	button.add_theme_stylebox_override(&"normal", UITheme.box(UITheme.GREEN))
	button.add_theme_stylebox_override(&"hover", UITheme.box(UITheme.GREEN.lightened(0.2)))
	button.add_theme_stylebox_override(&"pressed", UITheme.box(UITheme.GREEN.darkened(0.15)))
	for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color"]:
		button.add_theme_color_override(state, Color.WHITE)


func open_menu() -> void:
	visible = true
	_flash.text = ""
	_reflow()
	_refresh()


## Scales the whole frame down so it always fits the band above the dock.
##
## Run every frame the menu is open, rather than once after a deferred measure.
## The one-shot version is what kept letting the panel hang off the bottom: it
## measured a single frame after a rebuild, and any later change to the frame's
## minimum size — a card's text wrapping once it finally had a width, the window
## being resized or going fullscreen, the box strip arriving — happened after the
## only measurement was taken and was never accounted for. Re-measuring is a
## min-size query and a compare, so there is nothing to save by being clever
## about when it runs.
##
## Scaling rather than scrolling: the whole catalogue has to be comparable at a
## glance, which is what the no-scrollbar rule exists to protect. Floored at 0.55
## — below that the type stops being readable and shrinking further would trade
## one unusable menu for another.
func _process(_delta: float) -> void:
	if not visible or _frame == null:
		return
	var wanted := _frame.get_combined_minimum_size()
	if wanted.x <= 0.0 or wanted.y <= 0.0:
		return
	# The same band the panel is centred in — measuring against the whole window
	# would let it scale to a size that then still runs behind the dock.
	var room := Vector2(size.x - 32.0, size.y - DOCK_RESERVE - TOP_RESERVE - 16.0)
	var fit: float = clampf(minf(room.x / wanted.x, room.y / wanted.y), 0.55, 1.0)
	# The CenterContainer positions the frame from its UNSCALED rect, so the pivot
	# decides where the shrink pulls the panel towards. Centred horizontally, since
	# the frame is never wider than the band and the container's centring is
	# therefore honest on that axis.
	#
	# Pinned to the TOP vertically, which a centred pivot got wrong the moment a
	# level stocked enough to matter. Once the unscaled frame is taller than the
	# band, the container has nowhere to centre it and parks it at the top instead
	# — and a centre pivot then lowers the shrunken panel by half of what it just
	# saved, putting the last row of BUY buttons back off the bottom of the screen.
	# That is exactly what level 4's nine pieces and four booster tiers did: 919
	# units of panel, correctly scaled to 560, and still hanging past the edge.
	# Pinning the top means the space the scale frees is always space at the
	# bottom, where the dock is.
	_frame.pivot_offset = Vector2(_frame.size.x * 0.5, 0.0)
	if not is_equal_approx(_frame.scale.x, fit):
		_frame.scale = Vector2(fit, fit)


func close_menu() -> void:
	visible = false
	closed.emit()


func _on_box_opened(box: BoxDef, contents: Array[ObjectDef]) -> void:
	var names := PackedStringArray()
	for def: ObjectDef in contents:
		names.append(def.display_name)
	# Cream, not ink: an ink-outlined ink label on ink-outlined boards is a hole.
	_show_flash("%s: %s" % [box.display_name, ", ".join(names)], UITheme.CREAM)


func _on_purchase_failed(reason: String) -> void:
	_show_flash(reason, UITheme.DANGER)


func _show_flash(text: String, color: Color) -> void:
	_flash.text = text
	_flash.add_theme_color_override(&"font_color", color)


## Escape closes the menu. Handled here rather than in main so the key only means
## "close the shop" while the shop is actually up.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			close_menu()
			get_viewport().set_input_as_handled()
