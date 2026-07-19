class_name UnlockShopPage
extends Control
## Ability shop (gameplay-loop rework) — spends GameState.gold on PERMANENT
## per-hero ability mods (AbilityMods catalog). Each mod is bought once and owned
## forever, and carries a real downside next to its upside: the growing, quirky,
## permanently-owned kit that is the player's meta-progression (alongside the map
## knowledge the persistent fog builds). One account-wide page opened from the
## prep screen's ABILITY SHOP button; applied at spawn in Hero._apply_owned_ability_mods.

signal closed

var _gold_label: Label
var _grid: HBoxContainer

func _ready() -> void:
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
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var title := _label("ABILITY SHOP", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	_gold_label = _label("", 22)
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_gold_label)

	var note := _label("Permanent per-hero upgrades — bought once, owned forever. Each has a catch.", 13)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	note.custom_minimum_size = Vector2(520, 0)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(note)

	# One column per hero, its mods stacked beneath.
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(cols)
	_grid = cols

	var back := Button.new()
	back.text = "BACK"
	back.add_theme_font_size_override("font_size", 24)
	back.pressed.connect(func() -> void: closed.emit())
	root.add_child(back)

## Rebuilds the mod columns (called on load and after each purchase, since a buy
## changes gold — re-priced affordability across every card).
func _rebuild_grid() -> void:
	for child in _grid.get_children():
		child.queue_free()
	for hero_name in GameState.HERO_CATALOG:
		_grid.add_child(_hero_column(hero_name))

func _hero_column(hero_name: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.custom_minimum_size = Vector2(230, 0)
	var head := _label(hero_name, 18)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	for id in AbilityMods.for_hero(hero_name):
		col.add_child(_mod_card(id))
	return col

func _mod_card(id: String) -> PanelContainer:
	var d := AbilityMods.def(id)
	var owned := GameState.has_mod(id)
	var cost := int(d.get("cost", 0))

	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.7 if owned else 0.5)
	style.border_color = PrepMenu.INK_COLOR
	style.set_border_width_all(3)
	style.set_content_margin_all(10)
	style.set_corner_radius_all(2)
	card.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)

	box.add_child(_label(d.get("name", id), 16))
	var desc := _label(d.get("desc", ""), 13)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(desc)

	if owned:
		box.add_child(_label("● OWNED", 14))
	else:
		var buy := Button.new()
		buy.text = "Buy — %dg" % cost
		buy.add_theme_font_size_override("font_size", 14)
		buy.disabled = GameState.gold < cost
		buy.pressed.connect(func() -> void:
			if GameState.buy_mod(id):
				_refresh())
		box.add_child(buy)
	return card

func _refresh() -> void:
	_gold_label.text = "Gold: %d" % GameState.gold
	_rebuild_grid()

func _label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color("2c2c2c"))
	return l
