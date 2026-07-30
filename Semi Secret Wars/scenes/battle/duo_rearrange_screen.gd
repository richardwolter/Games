class_name DuoRearrangeScreen
extends CanvasLayer
## Start-of-level Duo reshuffle overlay (Designer, 2026-07-28): "players can
## re-setup their DUOs after beating a level, so they can better manage the team
## between battles". BattleManager raises one of these before deploy on every
## level after the first — see BattleManager._begin_deploy_setup.
##
## Deliberately NOT the prep screen's drag-and-drop panel. This is a click-two-
## slots-to-swap overlay: the party is fixed by this point (no roster to draft
## from), so the only operation that means anything mid-run is exchanging two
## heroes who are already placed. Reusing PrepMenu's panel would have meant
## extracting ~150 lines of working drag code to support an interaction this
## screen doesn't offer.
##
## Slot order carries meaning beyond cosmetics: index 0 of each pair is the Duo
## LEADER (GameState.is_duo_leader, read at spawn by Hero._duo_leader). So
## swapping the two members of ONE Duo is a legal, useful move — it hands
## leadership over without touching who is paired with whom.
##
## Dead heroes still occupy their slots, greyed and unselectable. They are not
## filtered out, because GameState.duo_pairings must keep its 2x2 shape for
## RunState.duo_wiped() to detect a fully-wiped Duo and collapse the field to a
## single lane. Rewriting pairings from the living only would silently break
## that.
##
## process_mode is ALWAYS so the buttons still take input while the tree is
## paused behind the overlay.

signal confirmed

## Matches LevelUpScreen — the two start-of-level overlays sit at the same depth.
const ACCENT := UIStyle.GOLD

## Flat 4-slot array, indices 0/1 = Duo A, 2/3 = Duo B. Same layout
## PrepMenu._pairing_slots uses, so the two screens describe a pairing the
## same way.
var _slots: Array = ["", "", "", ""]
## Names that may not be moved (RunState.dead) — drawn but inert.
var _locked: Array = []
## Slot index awaiting its swap partner, or -1 when nothing is selected.
var _selected := -1
var _body: VBoxContainer = null
var _done := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

## Seed from the persisted pairing. `dead_names` come from RunState.dead.
func setup(pairings: Array, dead_names: Array) -> void:
	_locked = dead_names.duplicate()
	_slots = ["", "", "", ""]
	for d in range(mini(2, pairings.size())):
		var duo = pairings[d]
		if duo is Array and (duo as Array).size() == 2:
			_slots[d * 2] = duo[0]
			_slots[d * 2 + 1] = duo[1]

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.add_theme_stylebox_override("panel", UIStyle.overlay_panel())
	add_child(panel)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 12)
	panel.add_child(_body)
	_rebuild()

## Full teardown/rebuild on every swap. The panel is four slots and two captions
## — cheap enough that keeping mutable references to each label would be more
## code than it saves, and it matches how PrepMenu rebuilds its pairing panel.
func _rebuild() -> void:
	for child in _body.get_children():
		child.queue_free()

	# Instruction leads at heading size, matching the boon overlay's ordering
	# (see LevelUpScreen.setup) so both start-of-level modals read the same way.
	_body.add_child(UIStyle.numeric_label("Rearrange your DUOs", UIStyle.SIZE_HEADING,
			UIStyle.INK, true))
	_body.add_child(UIStyle.numeric_label(_hint_text(), UIStyle.SIZE_SMALL,
			UIStyle.INK_MUTED, true))

	var boxes := HBoxContainer.new()
	boxes.alignment = BoxContainer.ALIGNMENT_CENTER
	boxes.add_theme_constant_override("separation", 32)
	_body.add_child(boxes)
	boxes.add_child(_build_duo_box(0, "DUO A"))
	boxes.add_child(_build_duo_box(1, "DUO B"))

	var confirm := UIStyle.button("START DEPLOY", UIStyle.SIZE_BODY, _on_confirm)
	confirm.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_body.add_child(confirm)

func _hint_text() -> String:
	if _selected >= 0:
		return "Pick a second hero to swap with %s." % _slots[_selected]
	return "Click two heroes to swap them. The left slot of each DUO leads."

## One Duo box: its two slots side by side, with the Ultimate that pairing
## currently unlocks underneath — so the player can see what a swap would buy
## before committing, the same reason PrepMenu shows it at draft time.
func _build_duo_box(duo_index: int, title: String) -> PanelContainer:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UIStyle.card(UIStyle.INK, 10, duo_index))

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	box.add_child(col)
	col.add_child(UIStyle.centered_label(title, UIStyle.SIZE_SMALL, UIStyle.INK))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	row.add_child(_build_slot(duo_index * 2))
	row.add_child(_build_slot(duo_index * 2 + 1))

	col.add_child(UIStyle.centered_label(_ultimate_text(duo_index),
			UIStyle.SIZE_TINY, UIStyle.INK_MUTED))
	return box

## The Duo Ultimate this pairing unlocks. Blank slots or a pair with no catalog
## entry both fall back to a dash rather than an error string — an incomplete
## Duo (a partner died) is a normal mid-run state here, unlike at prep.
func _ultimate_text(duo_index: int) -> String:
	var a: String = _slots[duo_index * 2]
	var b: String = _slots[duo_index * 2 + 1]
	if a == "" or b == "":
		return "—"
	var d := DuoUltimates.def(DuoUltimates.id_for_heroes(a, b))
	return d.get("name", "—")

func _build_slot(index: int) -> Button:
	var hero_name: String = _slots[index]
	var dead: bool = hero_name in _locked
	var label: String = hero_name if hero_name != "" else "—"
	if dead:
		label = "%s (DOWN)" % hero_name
	var btn := UIStyle.button(label, UIStyle.SIZE_SMALL, _on_slot_pressed.bind(index))
	btn.custom_minimum_size = Vector2(150, 52)
	# A downed or empty slot is inert: nothing to exchange. Disabled rather than
	# hidden so the player can still see who they lost and where they sat.
	btn.disabled = dead or hero_name == ""
	if index == _selected:
		btn.add_theme_stylebox_override("normal", UIStyle.card(ACCENT, 8, index))
	return btn

func _on_slot_pressed(index: int) -> void:
	if _selected < 0:
		_selected = index
	elif _selected == index:
		_selected = -1
	else:
		var tmp = _slots[_selected]
		_slots[_selected] = _slots[index]
		_slots[index] = tmp
		_selected = -1
	_rebuild()

## Writes the arrangement back and hands control to BattleManager. Confirming
## without touching anything is a no-op by construction: _slots was seeded from
## the persisted pairing, so it round-trips unchanged.
func _on_confirm() -> void:
	if _done:
		return
	_done = true
	GameState.set_duo_pairings([
		[_slots[0], _slots[1]],
		[_slots[2], _slots[3]],
	])
	confirmed.emit()
