class_name DuoUltimateBar
extends VBoxContainer
## Duo Ultimate activation bar (Designer, 2026-07-22): one card per Duo
## pairing (GameState.duo_pairings), each showing that Duo's exclusive
## Ultimate name and an ACTIVATE button — the "DUO Cards UI" the manual
## Ultimate activation is triggered from. Built once by BattleHUD (in code,
## like the existing _duo_b_label/_duo_synergy_labels — no separate .tscn
## needed for a plain code-built VBoxContainer); refreshed every frame
## (BattleHUD._process -> refresh()) to grey out/relabel a card once that
## Duo's Ultimate has been used this level (BattleManager.is_ultimate_used)
## or nobody from the Duo is currently spawned+alive
## (BattleManager.can_activate_ultimate).
##
## Positioned with a plain fixed offset in the project's 1920x1080 design
## canvas — the same convention every other HUD panel uses (TimerPanel,
## VillainPanel, HeroPanelsRoot, all placed via literal offset_left/top in
## battlefield.tscn). An anchor-preset + grow-direction approach was tried
## first and the bar never appeared on screen at all, so this avoids that
## whole class of anchor/grow-direction math entirely — bottom-right corner,
## clear of the top-left hero panels and top-center Duo synergy banners.
const BAR_POSITION := Vector2(1560.0, 700.0)

## Paper/ink/borders come from UIStyle (see UIStyle.card) — the only colour
## this bar names for itself is the Ultimate accent.
const ACCENT := UIStyle.GOLD

## pair_id -> Button (the one thing refresh() needs to update per card).
var _buttons: Dictionary = {}

func _ready() -> void:
	position = BAR_POSITION
	add_theme_constant_override("separation", 10)

## Builds one card per Duo pairing — called once by BattleHUD once
## GameState.duo_pairings is settled for this level. Safe to call with no
## valid pairings (e.g. a stale/empty save): simply builds zero cards.
func build_cards() -> void:
	for pair in GameState.duo_pairings:
		if not (pair is Array) or (pair as Array).size() != 2:
			continue
		var pair_id := DuoUltimates.id_for_heroes(pair[0], pair[1])
		var d := DuoUltimates.def(pair_id)
		if d.is_empty():
			continue
		add_child(_build_card(pair_id, pair[0], pair[1], d))

func _build_card(pair_id: String, hero_a: String, hero_b: String, d: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	# Gold accent border — an Ultimate card is a highlight element, same family
	# as the boon picks on LevelUpScreen.
	card.add_theme_stylebox_override("panel", UIStyle.card(ACCENT, 8, _buttons.size()))
	card.custom_minimum_size = Vector2(310, 0)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)

	box.add_child(UIStyle.label("%s + %s" % [hero_a, hero_b], UIStyle.SIZE_SMALL))

	var name_label := UIStyle.label(d.get("name", "ULTIMATE"), UIStyle.SIZE_BODY, ACCENT)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(name_label)

	var button := UIStyle.button("ACTIVATE", UIStyle.SIZE_SMALL,
			_on_activate_pressed.bind(pair_id))
	box.add_child(button)

	_buttons[pair_id] = button
	return card

func _on_activate_pressed(pair_id: String) -> void:
	var bm := get_tree().get_first_node_in_group("battle_manager")
	if bm != null:
		bm.activate_ultimate(pair_id)

## Called every frame by BattleHUD._process. Three button states: ACTIVATE
## (usable now), USED (already activated this level), UNAVAILABLE (unused,
## but nobody from the Duo is currently spawned+alive to cast it).
func refresh() -> void:
	var bm := get_tree().get_first_node_in_group("battle_manager")
	for pair_id in _buttons:
		var button: Button = _buttons[pair_id]
		if bm == null:
			button.disabled = true
			continue
		var used: bool = bm.is_ultimate_used(pair_id)
		var available: bool = bm.can_activate_ultimate(pair_id)
		button.disabled = not available
		if used:
			button.text = "USED"
		elif available:
			button.text = "ACTIVATE"
		else:
			button.text = "UNAVAILABLE"
