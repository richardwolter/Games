class_name SkillTreePage
extends Control
## Per-hero skill tree page, opened from a prep-menu hero card.
##
## Shared tree shape for every hero: four stat branches (linear chains of
## BRANCH_CAP nodes, only the chain-next node buyable) plus two hero-flavored
## ability nodes gated by total points spent (GameState.ABILITY_NODES).
## Built in code like PrepMenu; emits `closed` for the prep menu to restore
## itself.

signal closed

const STATS := ["max_hp", "damage", "attack_speed", "move_speed"]

## Hero-flavored names/blurbs for the shared passive/active ability nodes.
## Wording matches hero.gd's ability comments — no invented mechanics.
const ABILITY_INFO := {
	"THUNDAAR": {
		"base": {"name": "Stomp", "blurb": "Unlocks Stomp: auto-cast AoE knockback"},
		"passive": {"name": "Stomp Stun", "blurb": "Stomp also stuns enemies it hits"},
		"active": {"name": "Shockwave", "blurb": "Auto-cast line blast in front of him"},
	},
	"ARTEMIS": {
		"base": {"name": "Clone", "blurb": "Unlocks Clone: auto-cast taunting decoy"},
		"passive": {"name": "Clone Boost", "blurb": "Clones deal +50% damage"},
		"active": {"name": "Dash", "blurb": "Auto-cast dash into enemy clusters"},
	},
}

var hero_name := ""

var _xp_label: Label
var _points_label: Label
## _branch_buttons[stat] = Array[Button] (index = node in the chain).
var _branch_buttons := {}
## _ability_buttons[id] = {"button": Button, "req": Label}.
var _ability_buttons := {}

func _init(hero: String) -> void:
	hero_name = hero

func _ready() -> void:
	# set_anchors_preset alone keeps the current (zero) size via offsets when
	# the node is already inside the tree — set offsets too.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_refresh()

func _build_ui() -> void:
	var bg := PrepMenu.PrepPage.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_theme_constant_override("separation", 14)
	add_child(root)

	# Header: name + banked XP / points spent.
	var title := _label("%s — SKILL TREE" % hero_name, 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 40)
	root.add_child(header)
	_xp_label = _label("", 20)
	header.add_child(_xp_label)
	_points_label = _label("", 20)
	header.add_child(_points_label)

	# Branch columns.
	var columns := HBoxContainer.new()
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	columns.add_theme_constant_override("separation", 24)
	root.add_child(columns)
	for stat in STATS:
		columns.add_child(_build_branch_column(stat))
	columns.add_child(_build_ability_column())

	var back := Button.new()
	back.text = "BACK"
	back.add_theme_font_size_override("font_size", 24)
	back.pressed.connect(func() -> void: closed.emit())
	root.add_child(back)

func _build_branch_column(stat: String) -> PanelContainer:
	var card := _card()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)

	var head := _label(GameState.UPGRADES[stat].label, 18)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)

	var buttons := []
	for i in GameState.BRANCH_CAP:
		if i > 0:
			var link := _label("|", 10)
			link.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(link)
		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 0)
		b.pressed.connect(_on_buy_node.bind(stat))
		box.add_child(b)
		buttons.append(b)
	_branch_buttons[stat] = buttons
	return card

func _build_ability_column() -> PanelContainer:
	var card := _card()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	var head := _label("Abilities", 18)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)

	var info: Dictionary = ABILITY_INFO.get(hero_name, {})
	for id in GameState.ABILITY_NODES:
		var node_info: Dictionary = info.get(id, {"name": id.capitalize(), "blurb": ""})
		var b := Button.new()
		b.custom_minimum_size = Vector2(170, 0)
		b.pressed.connect(_on_buy_ability.bind(id))
		box.add_child(b)
		var blurb := _label(node_info.blurb, 12)
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD
		blurb.custom_minimum_size = Vector2(170, 0)
		box.add_child(blurb)
		var req := _label("", 12)
		box.add_child(req)
		_ability_buttons[id] = {"button": b, "req": req, "name": node_info.name}
	return card

func _on_buy_node(stat: String) -> void:
	if GameState.buy(hero_name, stat):
		_refresh()

func _on_buy_ability(id: String) -> void:
	if GameState.buy_ability(hero_name, id):
		_refresh()

func _refresh() -> void:
	var xp := GameState.xp_of(hero_name)
	_xp_label.text = "XP: %d" % xp
	_points_label.text = "Points spent: %d" % GameState.level_of(hero_name)

	for stat in _branch_buttons:
		var owned := GameState.owned(hero_name, stat)
		var next_cost := GameState.cost(hero_name, stat)
		var buttons: Array = _branch_buttons[stat]
		for i in buttons.size():
			var b: Button = buttons[i]
			if i < owned:
				b.text = "● owned"
				b.disabled = true
			elif i == owned:
				b.text = "○ %d XP" % next_cost
				b.disabled = xp < next_cost
			else:
				b.text = "·"
				b.disabled = true

	for id in _ability_buttons:
		var ui: Dictionary = _ability_buttons[id]
		var b: Button = ui.button
		var req: Label = ui.req
		var cost := GameState.ability_cost(id)
		if GameState.ability_owned(hero_name, id):
			b.text = "● %s" % ui.name
			b.disabled = true
			req.text = ""
		else:
			b.text = "○ %s — %d XP" % [ui.name, cost]
			b.disabled = not GameState.ability_available(hero_name, id)
			if not GameState.ability_unlocked(hero_name, id):
				var need := int(GameState.ABILITY_NODES[id].requires_points)
				var prereq: String = {"passive": " + base", "active": " + passive"}.get(id, "")
				req.text = "needs %d points" % need + prereq
			else:
				req.text = ""

func _card() -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.6)
	style.border_color = PrepMenu.INK_COLOR
	style.set_border_width_all(3)
	style.set_content_margin_all(12)
	style.set_corner_radius_all(2)
	card.add_theme_stylebox_override("panel", style)
	return card

func _label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color("2c2c2c"))
	return l
