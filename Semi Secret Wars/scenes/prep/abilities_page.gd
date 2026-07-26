class_name AbilitiesPage
extends Control
## The ABILITIES page — a per-hero SKILL TREE (Designer, 2026-07-26), replacing
## the flat card columns this page used to show.
##
## One tree per hero, picked with the tab row at the top. A tree is:
##   - signature-ability nodes, most of them multi-rank, laid out on the grid
##     authored in SkillTree.CATALOG's `pos` and wired by its `requires`;
##   - a bottom band of 4-rank ULTIMATE nodes, drawn bigger, one per Duo this
##     hero can form. Those are shared with the partner's tree — buying a rank
##     here is the same purchase as buying it there (GameState.duo_ultimate_ranks).
##
## Nothing about the look departs from the notebook style (Designer: "do not
## copy the style, ours should be kept like current style") — nodes are the
## same UIStyle.panel cards used everywhere, connectors are ink lines, an
## affordable node takes the gold accent.
##
## ART PLACEHOLDERS. Each node reserves a square art box. With
## SkillTree.def(id).icon empty it draws the node's `glyph` letter in a wobbly
## framed box; set the icon path and the same box shows the texture instead —
## no code change needed here (see _art_box).
##
## The page owns no game rules: every price, rank cap, prerequisite and effect
## lives in SkillTree/GameState.

signal closed

## Grid cell -> pixels. Columns are wide because the design canvas is 1920 and
## a tree is only 3 columns; rows are tight because the Ultimate band pushes
## the tree to 6 rows and everything has to clear 1080 without a scroll
## (Designer, 2026-07-26: no scrolls on menus).
## INVARIANT: both pitches must stay >= the card size they carry, or cards
## authored on neighbouring cells collide. Measured in-engine 2026-07-26, a
## signature card lays out at 230x128 (bigger than NODE_SIZE — the declared
## size is a floor, contents can still ask for more), so 118 was under the row
## pitch it needed and only the current zig-zag layout hid it. Re-measure if
## the type scale or NODE_SIZE changes again.
const COL_SPACING := 300.0
const ROW_SPACING := 130.0
const NODE_SIZE := Vector2(210, 104)
const ULTIMATE_NODE_SIZE := Vector2(300, 168)
const ART_BOX := Vector2(44, 44)
## Row 0's centre line, so the top row's card doesn't hang off the canvas.
const TOP_PADDING := 60.0
const ULTIMATE_ART_BOX := Vector2(58, 58)
## The Ultimate band gets its own, wider column pitch (Designer, 2026-07-26:
## "too much overlap on ultimate upgrade cards"). Those cards are bigger than a
## signature node AND carry a third line of text, so at the signature row's
## 300px pitch neighbouring cards ran into each other. Pitch must always stay
## clear of ULTIMATE_NODE_SIZE.x — that is the actual overlap guarantee.
const ULTIMATE_COL_SPACING := 360.0
## Inner padding of a node card's stylebox (UIStyle.panel margin, below) — the
## content width every child label is sized against.
const CARD_MARGIN := 8.0
## Gap between the art box and the title stack inside a card's head row.
const HEAD_SEPARATION := 8.0

var _gold_label: Label
var _tabs: HBoxContainer
var _canvas: Control
## Hero whose tree is on screen. Defaults to the first unlocked hero.
var _hero := ""
## node_id -> Control, rebuilt every refresh; the connector _draw reads it for
## endpoint positions, so it must stay in lockstep with what's on screen.
var _nodes: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not GameState.unlocked_heroes.is_empty():
		_hero = GameState.unlocked_heroes[0]
	_build_ui()
	_refresh()

func _build_ui() -> void:
	var bg := PrepPage.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margins.add_theme_constant_override("margin_" + side, 60)
	for side in ["top", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, 30)
	add_child(margins)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margins.add_child(root)

	var title := UIStyle.centered_label("ABILITIES", UIStyle.SIZE_HEADING)
	root.add_child(title)

	_gold_label = UIStyle.centered_label("", UIStyle.SIZE_SUBHEAD)
	root.add_child(_gold_label)

	_tabs = HBoxContainer.new()
	_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	_tabs.add_theme_constant_override("separation", 14)
	root.add_child(_tabs)
	for hero_name in GameState.unlocked_heroes:
		var tab := UIStyle.button(hero_name, UIStyle.SIZE_SMALL)
		tab.pressed.connect(_on_tab_pressed.bind(hero_name))
		_tabs.add_child(tab)

	# The tree itself: a plain Control the nodes are absolutely positioned in
	# (a grid layout can't express diagonal prerequisite wiring) with the
	# connector lines drawn behind them by _draw_connectors.
	_canvas = Control.new()
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.draw.connect(_draw_connectors)
	# Nodes are centred on the canvas's live width, which is 0 until the VBox
	# has laid out — so re-place them whenever that width changes. A rebuild
	# never changes the canvas's own size (children are absolutely positioned,
	# the VBox drives the size), so this can't loop.
	_canvas.resized.connect(_rebuild_tree)
	root.add_child(_canvas)

	var back := UIStyle.button("BACK", UIStyle.SIZE_SUBHEAD)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: closed.emit())
	root.add_child(back)

func _on_tab_pressed(hero_name: String) -> void:
	_hero = hero_name
	_refresh()

func _refresh() -> void:
	_gold_label.text = "Gold: %d" % GameState.gold
	for tab in _tabs.get_children():
		# The open tree's tab reads as pressed-in; the rest stay live.
		(tab as Button).disabled = (tab as Button).text == _hero
	_rebuild_tree()

## Tears down and re-lays the open hero's tree. Called on load, on tab switch
## and after every purchase — a buy can unlock a downstream node and re-price
## affordability across the whole tree, so a full rebuild is the honest update.
func _rebuild_tree() -> void:
	for child in _canvas.get_children():
		child.queue_free()
	_nodes.clear()
	if _hero == "":
		return

	var ids := SkillTree.for_hero(_hero)
	var ultimates := SkillTree.ultimates_for_hero(_hero)
	# Tree width is fixed by the widest grid column in use, so the whole thing
	# can be centred in whatever space the page has left.
	var max_col := 0.0
	for id in ids:
		var cell: Vector2 = SkillTree.def(id).get("pos", Vector2.ZERO)
		max_col = maxf(max_col, cell.x)
	for pair_id in ultimates:
		max_col = maxf(max_col, SkillTree.ultimate_pos(_hero, pair_id).x)
	var origin_x: float = (_canvas.size.x - max_col * COL_SPACING) * 0.5

	for id in ids:
		var cell: Vector2 = SkillTree.def(id).get("pos", Vector2.ZERO)
		_add_node(id, cell, origin_x, false)
	# The Ultimate band is centred on its OWN wider pitch, not the signature
	# grid's — see ULTIMATE_COL_SPACING.
	var ult_span := float(maxi(ultimates.size() - 1, 0)) * ULTIMATE_COL_SPACING
	var ult_origin_x: float = (_canvas.size.x - ult_span) * 0.5
	for i in ultimates.size():
		var cell := Vector2(float(i), SkillTree.ULTIMATE_ROW)
		_add_node(ultimates[i], cell, ult_origin_x, true)
	_canvas.queue_redraw()

## Places one node so its CENTRE lands on the grid cell — connectors are drawn
## centre-to-centre, so anchoring by centre is what keeps a line pointing at
## the node rather than its corner.
func _add_node(id: String, cell: Vector2, origin_x: float, ultimate: bool) -> void:
	var card := _node_card(id, ultimate)
	var box: Vector2 = ULTIMATE_NODE_SIZE if ultimate else NODE_SIZE
	var pitch: float = ULTIMATE_COL_SPACING if ultimate else COL_SPACING
	var center := Vector2(origin_x + cell.x * pitch, TOP_PADDING + cell.y * ROW_SPACING)
	# custom_minimum_size, not size: a Control cannot be laid out SMALLER than
	# its contents, so forcing `size` only made the card silently grow past the
	# column pitch and collide with its neighbour. Every label inside is now
	# width-constrained to the card instead (see _node_card), so the declared
	# box IS the final box and the pitch above genuinely keeps cards apart.
	card.custom_minimum_size = box
	card.size = box
	card.position = center - box * 0.5
	_canvas.add_child(card)
	_nodes[id] = card

## Centre of a placed node, for connector endpoints.
func _node_center(id: String) -> Vector2:
	var c: Control = _nodes.get(id, null)
	return c.position + c.size * 0.5 if c != null else Vector2.ZERO

## Ink lines along every prerequisite edge, drawn behind the nodes (the canvas
## paints before its children). A satisfied edge — the prerequisite owns at
## least one rank — is gold and thicker, so a glance shows how far the tree
## has actually been opened up.
func _draw_connectors() -> void:
	for id in _nodes:
		for req in SkillTree.def(id).get("requires", []):
			if not _nodes.has(req):
				continue
			var met := GameState.skill_rank(_hero, req) > 0
			_canvas.draw_line(_node_center(req), _node_center(id),
					UIStyle.GOLD if met else UIStyle.INK_MUTED, 5.0 if met else 3.0)

## One node. Owned/affordable/locked all read off the same three facts —
## rank vs. ranks, prerequisites, gold — so the card never disagrees with what
## GameState.buy_skill_rank will actually allow.
func _node_card(id: String, ultimate: bool) -> PanelContainer:
	var d := SkillTree.def(id)
	var rank := GameState.skill_rank(_hero, id)
	var max_rank := int(d.get("ranks", 1))
	var unlocked := GameState.skill_unlocked(_hero, id)
	var maxed := rank >= max_rank
	var cost := SkillTree.cost_for(id, rank)
	var affordable := unlocked and not maxed and GameState.gold >= cost

	var card := PanelContainer.new()
	# Same wobbly notebook card as every other panel: gold border once it has
	# any rank, muted ink while still locked.
	var accent: Color = UIStyle.GOLD if rank > 0 else (UIStyle.INK if unlocked else UIStyle.INK_MUTED)
	card.add_theme_stylebox_override("panel", UIStyle.panel(
			UIStyle.CARD_STRONG if rank > 0 else UIStyle.CARD, accent,
			4 if ultimate else 3, int(CARD_MARGIN), id.length()))

	# Every child is sized against this, so nothing inside can push the card
	# wider than the column pitch. A Label's minimum width is its whole text
	# unless it wraps, which is what made the Ultimate cards overlap: names
	# like "Concussive Wave" plus the "ULTIMATE · with BEACON" line demanded
	# more width than the card was ever given.
	var full: Vector2 = ULTIMATE_NODE_SIZE if ultimate else NODE_SIZE
	var inner := full.x - CARD_MARGIN * 2.0
	var art: Vector2 = ULTIMATE_ART_BOX if ultimate else ART_BOX
	var title_width := inner - art.x - HEAD_SEPARATION

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", int(HEAD_SEPARATION))
	box.add_child(head)
	head.add_child(_art_box(d, ultimate))

	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	titles.add_child(_fitted_label(d.get("name", id), UIStyle.SIZE_SMALL, UIStyle.INK, title_width))
	if ultimate:
		# Which Duo this Ultimate belongs to — the node is shared with that
		# hero's tree, and the player has to know whose pairing it needs.
		titles.add_child(_fitted_label("ULTIMATE · with %s" %
				SkillTree.ultimate_partner(_hero, id),
				UIStyle.SIZE_TINY, UIStyle.GOLD, title_width))
	titles.add_child(_fitted_label(_pips(rank, max_rank), UIStyle.SIZE_TINY,
			UIStyle.GOLD, title_width))

	box.add_child(_fitted_label(d.get("desc", ""), UIStyle.SIZE_TINY,
			UIStyle.INK if unlocked else UIStyle.INK_MUTED, inner))

	if maxed:
		box.add_child(UIStyle.label("● MAXED", UIStyle.SIZE_TINY, UIStyle.GOLD))
	elif not unlocked:
		box.add_child(UIStyle.label("Locked", UIStyle.SIZE_TINY, UIStyle.INK_MUTED))
	else:
		var buy := UIStyle.button("Buy Lv%d — %dg" % [rank + 1, cost], UIStyle.SIZE_TINY)
		buy.disabled = not affordable
		buy.pressed.connect(func() -> void:
			if GameState.buy_skill_rank(_hero, id):
				_refresh())
		box.add_child(buy)
	return card

## A label that can never make its card wider than `width`. Wrapping is what
## does it: an un-wrapped Label reports its full text as its minimum width, so
## a long node name silently widened the card until neighbours overlapped
## (Designer, 2026-07-26).
##
## Do NOT add clip_text here. It zeroes the Label's whole minimum size — width
## AND height — so the enclosing VBox handed every label 0 height and all card
## text vanished (Designer, 2026-07-26, immediately after the overlap fix).
## Wrapping alone already caps the width, which was the only thing clipping was
## meant to add.
func _fitted_label(text: String, size: int, color: Color, width: float) -> Label:
	var l := UIStyle.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(width, 0)
	l.size_flags_horizontal = Control.SIZE_FILL
	return l

## The art placeholder (Designer, 2026-07-26: "leave placeholders for each
## node, so I can provide art later"). Draws SkillTree.def(id).icon when a
## path is set, otherwise the node's glyph letter in the same square — so the
## layout is already final and dropping art in changes nothing else.
func _art_box(d: Dictionary, ultimate: bool) -> Control:
	var box: Vector2 = ULTIMATE_ART_BOX if ultimate else ART_BOX
	var icon_path: String = d.get("icon", "")
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var tex := TextureRect.new()
		tex.texture = load(icon_path)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.custom_minimum_size = box
		return tex
	var frame := PanelContainer.new()
	frame.custom_minimum_size = box
	frame.add_theme_stylebox_override("panel",
			UIStyle.panel(UIStyle.CARD, UIStyle.INK_MUTED, 2, 2, int(box.x)))
	var glyph := UIStyle.centered_label(d.get("glyph", "?"),
			UIStyle.SIZE_SUBHEAD if ultimate else UIStyle.SIZE_SMALL, UIStyle.INK_MUTED)
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	frame.add_child(glyph)
	return frame

## Rank readout — filled dots for bought ranks, hollow for the rest.
func _pips(rank: int, max_rank: int) -> String:
	return "●".repeat(rank) + "○".repeat(maxi(max_rank - rank, 0))
