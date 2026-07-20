class_name AbilitiesPage
extends Control
## V2's single ABILITIES page — merges two gold-spending catalogs that used to
## live on separate pages (Designer, 2026-07-19: "put abilities and ability
## shop in the same page, those use gold"): AbilityTiers (tier 2/3 unlocks,
## sequential) and AbilityMods (the 8 stat/geometry tradeoffs, independent
## purchases — see scripts/ability_mods.gd). One hero column per drafted hero:
## tier cards first, then that hero's mod cards underneath.
##
## V1 keeps its original separate UnlockShopPage (scenes/prep/unlock_shop_page.gd)
## untouched — V1 has no ability tiers to merge in.

signal closed

var _gold_label: Label
var _grid: HBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_refresh()

func _build_ui() -> void:
	var bg := PrepPage.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var title := _label("ABILITIES", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	_gold_label = _label("", 22)
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_gold_label)

	var note := _label("Tier 1 (signature ability) is free on unlock. Tiers 2-3 and the mods below are all permanent, gold-bought purchases.", 13)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	note.custom_minimum_size = Vector2(560, 0)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(note)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 520)
	root.add_child(scroll)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll.add_child(cols)
	_grid = cols

	var back := Button.new()
	back.text = "BACK"
	back.add_theme_font_size_override("font_size", 24)
	back.pressed.connect(func() -> void: closed.emit())
	root.add_child(back)

## Rebuilds the hero columns (called on load and after each purchase, since a
## buy changes gold — re-priced affordability across every card).
func _rebuild_grid() -> void:
	for child in _grid.get_children():
		child.queue_free()
	for hero_name in GameState.unlocked_heroes:
		_grid.add_child(_hero_column(hero_name))

func _hero_column(hero_name: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.custom_minimum_size = Vector2(230, 0)
	var head := _label(hero_name, 18)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	for id in AbilityTiers.for_hero(hero_name):
		col.add_child(_tier_card(id))
	var sep := HSeparator.new()
	col.add_child(sep)
	for id in AbilityMods.for_hero(hero_name):
		col.add_child(_mod_card(id))
	return col

func _tier_card(id: String) -> PanelContainer:
	var d := AbilityTiers.def(id)
	var owned := id in GameState.owned_ability_tiers
	var cost := int(d.get("cost", 0))
	var prereq_met := AbilityTiers.prereq_met(id)

	var card := _card_base(owned)
	var box: VBoxContainer = card.get_child(0)
	box.add_child(_label("Tier %d — %s" % [int(d.get("tier", 0)), d.get("name", id)], 16))
	var desc := _label(d.get("desc", ""), 13)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(desc)

	if owned:
		box.add_child(_label("● OWNED", 14))
	elif not prereq_met:
		box.add_child(_label("Requires previous tier", 13))
	else:
		box.add_child(_buy_button(cost, func() -> bool: return GameState.buy_tier(id)))
	return card

func _mod_card(id: String) -> PanelContainer:
	var d := AbilityMods.def(id)
	var owned := GameState.has_mod(id)
	var cost := int(d.get("cost", 0))

	var card := _card_base(owned)
	var box: VBoxContainer = card.get_child(0)
	box.add_child(_label(d.get("name", id), 16))
	var desc := _label(d.get("desc", ""), 13)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(desc)

	if owned:
		box.add_child(_label("● OWNED", 14))
	else:
		box.add_child(_buy_button(cost, func() -> bool: return GameState.buy_mod(id)))
	return card

func _card_base(owned: bool) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.7 if owned else 0.5)
	style.border_color = PrepPage.INK_COLOR
	style.set_border_width_all(3)
	style.set_content_margin_all(10)
	style.set_corner_radius_all(2)
	card.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	return card

func _buy_button(cost: int, buy: Callable) -> Button:
	var buy_btn := Button.new()
	buy_btn.text = "Buy — %dg" % cost
	buy_btn.add_theme_font_size_override("font_size", 14)
	buy_btn.disabled = GameState.gold < cost
	buy_btn.pressed.connect(func() -> void:
		if buy.call():
			_refresh())
	return buy_btn

func _refresh() -> void:
	_gold_label.text = "Gold: %d" % GameState.gold
	_rebuild_grid()

func _label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color("2c2c2c"))
	return l
