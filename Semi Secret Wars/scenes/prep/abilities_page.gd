class_name AbilitiesPage
extends Control
## The single ABILITIES page — merges two gold-spending catalogs that used to
## live on separate pages (Designer, 2026-07-19: "put abilities and ability
## shop in the same page, those use gold"): AbilityTiers (tier 2 passive
## unlock only — tier 3 was retired 2026-07-22 with the solo LV20 ultimates,
## see AbilityTiers class doc) and AbilityMods (the 8 stat/geometry
## tradeoffs, independent purchases — see scripts/ability_mods.gd). One hero
## column per drafted hero: tier card first, then that hero's mod cards
## underneath.

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
	root.add_theme_constant_override("separation", 18)
	add_child(root)

	var title := _label("ABILITIES", UIStyle.SIZE_HEADING)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	_gold_label = _label("", UIStyle.SIZE_SUBHEAD)
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_gold_label)

	var note := _label("Tier 1 (signature ability) is free on unlock. Everything below is a permanent, gold-bought purchase. Each hero's cards upgrade their signature ability; the last column upgrades your paired Duos' Ultimates. Raw stats are bought with XP on the STATS page.", UIStyle.SIZE_TINY)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	note.custom_minimum_size = Vector2(900, 0)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(note)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 640)
	root.add_child(scroll)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 28)
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll.add_child(cols)
	_grid = cols

	var back := UIStyle.button("BACK", UIStyle.SIZE_SUBHEAD)
	back.pressed.connect(func() -> void: closed.emit())
	root.add_child(back)

## Rebuilds the hero columns (called on load and after each purchase, since a
## buy changes gold — re-priced affordability across every card).
func _rebuild_grid() -> void:
	for child in _grid.get_children():
		child.queue_free()
	for hero_name in GameState.unlocked_heroes:
		_grid.add_child(_hero_column(hero_name))
	var duos := _duo_column()
	if duos != null:
		_grid.add_child(duos)

## Trailing column of permanent Duo Ultimate upgrades (DuoUltimateMods), one
## card per currently-paired Duo — the Ultimate half of the reworked shop
## (Designer, 2026-07-25). Returns null when nothing is paired yet, so the
## shop doesn't show an empty column: an Ultimate belongs to a PAIR, so there
## is nothing to sell until the player has made one at the prep screen.
func _duo_column() -> VBoxContainer:
	var pair_ids: Array[String] = []
	for pair in GameState.duo_pairings:
		if pair is Array and (pair as Array).size() == 2:
			var pid := DuoUltimates.id_for_heroes(pair[0], pair[1])
			if not DuoUltimateMods.for_duo(pid).is_empty():
				pair_ids.append(pid)
	if pair_ids.is_empty():
		return null

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(310, 0)
	var head := _label("DUO ULTIMATES", UIStyle.SIZE_BODY)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	for pid in pair_ids:
		for id in DuoUltimateMods.for_duo(pid):
			col.add_child(_duo_mod_card(id))
	return col

## One permanent Duo Ultimate upgrade card. Mirrors _mod_card, but priced and
## owned through GameState.buy_duo_mod/has_duo_mod (a separate owned-list, so
## an id can't collide with a per-hero mod).
func _duo_mod_card(id: String) -> PanelContainer:
	var d := DuoUltimateMods.def(id)
	var owned := GameState.has_duo_mod(id)
	var cost := int(d.get("cost", 0))

	var card := _card_base(owned, id.length())
	var box: VBoxContainer = card.get_child(0)
	var pair_id: String = d.get("duo", "")
	box.add_child(_label(" + ".join(pair_id.split("|")), UIStyle.SIZE_TINY))
	box.add_child(_label(d.get("name", id), UIStyle.SIZE_SMALL))
	var desc := _label(d.get("desc", ""), UIStyle.SIZE_TINY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(desc)

	if owned:
		box.add_child(UIStyle.label("● OWNED", UIStyle.SIZE_SMALL, UIStyle.GOLD))
	else:
		box.add_child(_buy_button(cost, func() -> bool: return GameState.buy_duo_mod(id)))
	return card

func _hero_column(hero_name: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(310, 0)
	var head := _label(hero_name, UIStyle.SIZE_BODY)
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

	var card := _card_base(owned, id.length())
	var box: VBoxContainer = card.get_child(0)
	box.add_child(_label("Tier %d — %s" % [int(d.get("tier", 0)), d.get("name", id)], UIStyle.SIZE_SMALL))
	var desc := _label(d.get("desc", ""), UIStyle.SIZE_TINY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(desc)

	if owned:
		box.add_child(UIStyle.label("● OWNED", UIStyle.SIZE_SMALL, UIStyle.GOLD))
	elif not prereq_met:
		box.add_child(UIStyle.label("Requires previous tier", UIStyle.SIZE_TINY, UIStyle.INK_MUTED))
	else:
		box.add_child(_buy_button(cost, func() -> bool: return GameState.buy_tier(id)))
	return card

func _mod_card(id: String) -> PanelContainer:
	var d := AbilityMods.def(id)
	var owned := GameState.has_mod(id)
	var cost := int(d.get("cost", 0))

	var card := _card_base(owned, id.length())
	var box: VBoxContainer = card.get_child(0)
	box.add_child(_label(d.get("name", id), UIStyle.SIZE_SMALL))
	var desc := _label(d.get("desc", ""), UIStyle.SIZE_TINY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(desc)

	if owned:
		box.add_child(UIStyle.label("● OWNED", UIStyle.SIZE_SMALL, UIStyle.GOLD))
	else:
		box.add_child(_buy_button(cost, func() -> bool: return GameState.buy_mod(id)))
	return card

## `variant` only picks which hand-drawn corner wobble the card gets, so a
## stacked column doesn't read as identical stamped rectangles. An owned card
## sits on more solid paper and takes the gold accent border.
func _card_base(owned: bool, variant: int = 0) -> PanelContainer:
	var card := PanelContainer.new()
	var style := UIStyle.panel(UIStyle.CARD_STRONG if owned else UIStyle.CARD,
			UIStyle.GOLD if owned else UIStyle.INK, 3, 10, variant)
	card.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	return card

func _buy_button(cost: int, buy: Callable) -> Button:
	var buy_btn := UIStyle.button("Buy — %dg" % cost, UIStyle.SIZE_SMALL)
	buy_btn.disabled = GameState.gold < cost
	buy_btn.pressed.connect(func() -> void:
		if buy.call():
			_refresh())
	return buy_btn

func _refresh() -> void:
	_gold_label.text = "Gold: %d" % GameState.gold
	_rebuild_grid()

func _label(text: String, font_size: int) -> Label:
	return UIStyle.label(text, font_size)
