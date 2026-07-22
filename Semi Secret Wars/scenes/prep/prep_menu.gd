class_name PrepMenu
extends Control
## The prep screen — party draft + gold/ability shop, then START into the
## lane battlefield. No priority/support-target pickers — heroes just push
## the lane.
##
## There is no separate "select party" checkbox — dragging a hero into a Duo
## slot IS the selection. A hero only deploys if it's paired (both slots of
## a Duo filled); an unplaced hero sits the run out. See _sync_party_from_slots.

var _start_button: Button
var _currency_label: Label
var _xp_label: Label
var _hero_row: HBoxContainer
var _main: VBoxContainer
var _abilities_page: AbilitiesPage
var _stats_page: StatsPage

## Duo pairing panel state. _pairing_slots is a flat 4-slot array — indices
## 0/1 are Duo A, indices 2/3 are Duo B — populated by dragging a hero card
## from _hero_row onto a DuoSlot. Every change re-derives RunState.party and
## GameState.duo_pairings from whichever Duos are fully filled — see
## _sync_party_from_slots.
var _pairing_section: VBoxContainer
var _pairing_slots: Array = ["", "", "", ""]
const DUO_A_COLOR := Color("b8860b")
const DUO_B_COLOR := Color("2c8f7a")
const SLOT_SIZE := Vector2(150, 70)

## A hero card that can be dragged onto a DuoSlot. Only the drag affordance is
## added here — selection/unlock UI stays in _build_hero_card, which builds
## one of these instead of a plain PanelContainer.
class DraggableHeroCard extends PanelContainer:
	var hero_name: String = ""
	var swatch_color: Color = Color.WHITE

	func _get_drag_data(_at_position: Vector2) -> Variant:
		if hero_name == "":
			return null
		var preview := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(swatch_color, 0.85)
		style.set_content_margin_all(10)
		preview.add_theme_stylebox_override("panel", style)
		var lbl := Label.new()
		lbl.text = hero_name
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", Color("2c2c2c"))
		preview.add_child(lbl)
		set_drag_preview(preview)
		return {"hero_name": hero_name}

## One of the 4 drop targets inside the Duo A / Duo B boxes. Reports drops and
## clicks (to clear) back to PrepMenu via injected Callables — the panel is
## fully rebuilt after either, so this class holds no display state itself.
class DuoSlot extends PanelContainer:
	var duo_index: int = 0
	var slot_index: int = 0
	var on_drop: Callable
	var on_clear: Callable

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("hero_name")

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		on_drop.call(String(data["hero_name"]), duo_index, slot_index)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			on_clear.call(duo_index, slot_index)

func _ready() -> void:
	RunState.roll_draft_offer()
	_seed_pairing_slots()
	_build_ui()
	_refresh()

## Restores the Duo layout from GameState.duo_pairings (persists across prep
## visits) into the flat slot array the drag UI reads.
func _seed_pairing_slots() -> void:
	_pairing_slots = ["", "", "", ""]
	var duos: Array = GameState.duo_pairings
	for d in range(mini(2, duos.size())):
		var duo: Array = duos[d]
		if duo.size() == 2:
			_pairing_slots[d * 2] = duo[0]
			_pairing_slots[d * 2 + 1] = duo[1]
	_sync_party_from_slots()

func _build_ui() -> void:
	var bg := PrepPage.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_theme_constant_override("separation", 16)
	add_child(root)
	_main = root

	var title := _label("SEMI-SECRET WARS", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var meta_row := HBoxContainer.new()
	meta_row.alignment = BoxContainer.ALIGNMENT_CENTER
	meta_row.add_theme_constant_override("separation", 16)
	_currency_label = _label("", 18)
	meta_row.add_child(_currency_label)
	_xp_label = _label("", 18)
	meta_row.add_child(_xp_label)
	var abilities_btn := _button("ABILITIES", 18, _open_abilities)
	meta_row.add_child(abilities_btn)
	var stats_btn := _button("STATS", 18, _open_stats)
	meta_row.add_child(stats_btn)
	root.add_child(meta_row)

	_hero_row = HBoxContainer.new()
	_hero_row.add_theme_constant_override("separation", 32)
	root.add_child(_hero_row)
	_rebuild_hero_row()

	_pairing_section = VBoxContainer.new()
	_pairing_section.add_theme_constant_override("separation", 8)
	root.add_child(_pairing_section)
	_rebuild_pairing_panel()

	_start_button = _button("START RUN", 30, _on_start)
	root.add_child(_start_button)

	var footer := _label("Level 1 — push right, destroy the spawn gates, defeat the villain      (F12 = full reset)", 15)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(footer)

func _rebuild_hero_row() -> void:
	for child in _hero_row.get_children():
		child.queue_free()
	for hero_name in GameState.HERO_CATALOG:
		if GameState.is_hero_unlocked(hero_name):
			_hero_row.add_child(_build_hero_card(hero_name))
		else:
			_hero_row.add_child(_build_locked_hero_card(hero_name))

## Duo Pairings panel: two side-by-side boxes (Duo A / Duo B), each with 2
## drop slots. Drag a hero card down from the row above onto a slot to place
## it there — that's the only way a hero joins the run (see class doc). Only
## heroes in a fully-filled Duo (both slots occupied) actually deploy; a
## hero placed alone still needs a partner.
func _rebuild_pairing_panel() -> void:
	for child in _pairing_section.get_children():
		child.queue_free()

	var header := _label("DUO PAIRINGS — drag a hero into a slot to send it into battle. Left slot leads, right slot follows.", 20)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pairing_section.add_child(header)

	var offered: Array = RunState.draft_offer.duplicate()

	# Drop any slot occupant that fell out of the offer (shouldn't normally
	# happen — offer only changes via unlocks — but keeps state sane).
	for i in _pairing_slots.size():
		if _pairing_slots[i] != "" and _pairing_slots[i] not in offered:
			_pairing_slots[i] = ""

	var boxes := HBoxContainer.new()
	boxes.alignment = BoxContainer.ALIGNMENT_CENTER
	boxes.add_theme_constant_override("separation", 24)
	_pairing_section.add_child(boxes)
	boxes.add_child(_build_duo_box(0, "DUO A", DUO_A_COLOR))
	boxes.add_child(_build_duo_box(1, "DUO B", DUO_B_COLOR))

	var unplaced := offered.filter(func(h: String) -> bool: return h not in _pairing_slots)
	var hint2 := _label(_pairing_hint_text(unplaced), 14)
	hint2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pairing_section.add_child(hint2)

	if _pairing_slots.count("") < 4:
		var center := CenterContainer.new()
		center.add_child(_button("CLEAR PAIRING", 15, _on_reset_pairing))
		_pairing_section.add_child(center)

func _pairing_hint_text(unplaced: Array) -> String:
	if unplaced.is_empty():
		return "Every hero is placed."
	return "Not deploying unless paired: %s" % ", ".join(unplaced)

## One Duo box: a colored-border panel labeled "DUO A"/"DUO B" containing its
## 2 DuoSlot drop targets side by side.
func _build_duo_box(duo_index: int, title: String, color: Color) -> PanelContainer:
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.5)
	style.border_color = color
	style.set_border_width_all(3)
	style.set_content_margin_all(10)
	box.add_theme_stylebox_override("panel", style)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	box.add_child(col)

	var label := _label(title, 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	col.add_child(label)

	var slots_row := HBoxContainer.new()
	slots_row.add_theme_constant_override("separation", 8)
	col.add_child(slots_row)
	slots_row.add_child(_build_duo_slot(duo_index, 0, color))
	slots_row.add_child(_build_duo_slot(duo_index, 1, color))

	col.add_child(_build_synergy_label(duo_index))

	return box

## Named Duo synergy chip: only shown once both slots of this Duo are filled
## (see DuoSynergies — purely presentational, the effects already run
## regardless of whether this label exists).
func _build_synergy_label(duo_index: int) -> Control:
	var hero_a: String = _pairing_slots[duo_index * 2]
	var hero_b: String = _pairing_slots[duo_index * 2 + 1]
	if hero_a == "" or hero_b == "":
		return Control.new()
	var d := DuoSynergies.def_for_heroes(hero_a, hero_b)
	if d.is_empty():
		return Control.new()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	var name_label := _label(d.get("name", ""), 15)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_label)
	var desc_label := _label(d.get("desc", ""), 11)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.custom_minimum_size = Vector2(220, 0)
	col.add_child(desc_label)
	return col

func _build_duo_slot(duo_index: int, slot_index: int, color: Color) -> DuoSlot:
	var slot := DuoSlot.new()
	slot.duo_index = duo_index
	slot.slot_index = slot_index
	slot.on_drop = _on_slot_drop
	slot.on_clear = _on_slot_clear
	slot.custom_minimum_size = SLOT_SIZE
	slot.mouse_filter = Control.MOUSE_FILTER_STOP

	var hero_name: String = _pairing_slots[duo_index * 2 + slot_index]
	# Leader/follower is a pure player choice now (Designer, 2026-07-20: "tank
	# always leads does not work anymore ... this should be a player
	# decision") — slot_index 0 (left/A) is always the Leader slot, 1 (right/B)
	# always Follower; GameState.is_duo_leader reads this same slot order back
	# from _sync_party_from_slots's [a, b] array, so this tag always matches
	# what battle will actually do. Shown on the SLOT itself (even empty), not
	# derived from which hero ends up there — labeling the slot up front is
	# the whole point: the player sees the assignment before they drag.
	var is_leader_slot := slot_index == 0
	var style := StyleBoxFlat.new()
	style.set_content_margin_all(6)
	if hero_name != "":
		style.bg_color = Color(GameState.HERO_CATALOG[hero_name].color, 0.6)
		style.border_color = color
		style.set_border_width_all(2)
	else:
		style.bg_color = Color(1, 1, 1, 0.25)
		style.border_color = Color(color, 0.4)
		style.set_border_width_all(1)
	slot.add_theme_stylebox_override("panel", style)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)

	var tag_row := CenterContainer.new()
	var tag := _label("LEADER" if is_leader_slot else "FOLLOWER", 11)
	tag.add_theme_color_override("font_color", Color("f4d35e") if is_leader_slot else Color("d6d6d6"))
	tag_row.add_child(tag)
	col.add_child(tag_row)

	var center := CenterContainer.new()
	center.add_child(_label(hero_name if hero_name != "" else "drop hero", 14))
	col.add_child(center)

	slot.add_child(col)

	return slot

## Places `hero_name` into the target slot, first clearing it from wherever
## it currently sits (drag-to-reassign, not swap — the vacated slot just goes
## empty).
func _on_slot_drop(hero_name: String, duo_index: int, slot_index: int) -> void:
	if hero_name not in RunState.draft_offer:
		return
	for i in _pairing_slots.size():
		if _pairing_slots[i] == hero_name:
			_pairing_slots[i] = ""
	_pairing_slots[duo_index * 2 + slot_index] = hero_name
	_sync_party_from_slots()
	_rebuild_pairing_panel()
	_refresh()

func _on_slot_clear(duo_index: int, slot_index: int) -> void:
	_pairing_slots[duo_index * 2 + slot_index] = ""
	_sync_party_from_slots()
	_rebuild_pairing_panel()
	_refresh()

## Single source of truth: reads _pairing_slots, decides which heroes are
## actually deploying (only those in a *fully-filled* Duo — a lone hero in an
## otherwise-empty Duo isn't fielded, it's mid-pairing), and pushes that both
## to RunState.party (drives the run/deploy/results) and GameState.duo_pairings
## (persistent Duo identity, read by battle for synergy/ultimate/behavior).
func _sync_party_from_slots() -> void:
	var duos: Array = []
	var roster: Array = []
	for d in range(2):
		var a: String = _pairing_slots[d * 2]
		var b: String = _pairing_slots[d * 2 + 1]
		if a != "" and b != "":
			duos.append([a, b])
			roster.append(a)
			roster.append(b)
	RunState.party = roster
	GameState.set_duo_pairings(duos)

func _on_reset_pairing() -> void:
	_pairing_slots = ["", "", "", ""]
	_sync_party_from_slots()
	_rebuild_pairing_panel()
	_refresh()

func _build_hero_card(hero_name: String) -> PanelContainer:
	var offered := RunState.is_offered(hero_name)
	var card := DraggableHeroCard.new()
	card.hero_name = hero_name
	card.swatch_color = GameState.HERO_CATALOG[hero_name].color
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.6)
	style.border_color = PrepPage.INK_COLOR
	style.set_border_width_all(3)
	style.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", style)
	if not offered:
		card.modulate = Color(1, 1, 1, 0.4)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	var swatch := ColorRect.new()
	swatch.color = Color(GameState.HERO_CATALOG[hero_name].color, 0.6)
	swatch.custom_minimum_size = Vector2(120, 60)
	box.add_child(swatch)

	var name_label := _label(hero_name, 22)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)

	var role: String = Hero.ROLE_BY_HERO.get(hero_name, "")
	var role_label := _label(role, 15)
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_label.add_theme_color_override("font_color", Hero.ROLE_COLORS.get(role, Color("2c2c2c")))
	box.add_child(role_label)

	var role_desc := _label(Hero.ROLE_DESCRIPTIONS.get(hero_name, ""), 12)
	role_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	role_desc.custom_minimum_size = Vector2(140, 0)
	box.add_child(role_desc)

	box.add_child(_label(_current_stats_text(hero_name), 13))

	var lifetime_label := _label(_lifetime_stats_text(hero_name), 12)
	lifetime_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lifetime_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	box.add_child(lifetime_label)

	return card

## Lifetime totals across every run (GameState.hero_stats) — separate from
## the live per-run numbers shown on the battle hero card.
func _lifetime_stats_text(hero_name: String) -> String:
	var pct := GameState.hero_ability_pct_lifetime(hero_name)
	var abl_text := "%d%%" % int(round(pct)) if pct >= 0.0 else "—"
	return "KILLS %d  ·  XP %d  ·  ABL %s" % [
		GameState.hero_kills_lifetime(hero_name), GameState.hero_xp_lifetime(hero_name), abl_text]

## Effective hero stats: base × the global base multipliers × permanent
## StatUpgrades purchases — the same formula hero.gd uses at spawn
## (_configure + _apply_stat_upgrades), so the card shows what will actually
## hit the field, and matches the STATS page's numbers.
func _current_stats_text(hero_name: String) -> String:
	var stats: Dictionary = Hero.HERO_STATS.get(hero_name, {})
	var atk_interval: float = Hero.ARTEMIS_ATTACK_INTERVAL if hero_name == "ARTEMIS" \
			else float(stats.get("attack_interval", 0.5))
	var hp_n := GameState.stat_purchase_count(hero_name, "hp")
	var dmg_n := GameState.stat_purchase_count(hero_name, "damage")
	var aspd_n := GameState.stat_purchase_count(hero_name, "attack_speed")
	var hp: float = float(stats.get("base_hp", 100)) * Hero.BASE_HP_MULT + float(StatUpgrades.def("hp").get("effect_add", 0.0)) * hp_n
	var dmg: float = float(stats.get("base_damage", 10)) * Hero.BASE_DAMAGE_MULT + float(StatUpgrades.def("damage").get("effect_add", 0.0)) * dmg_n
	atk_interval = maxf(atk_interval - float(StatUpgrades.def("attack_speed").get("effect_add", 0.0)) * aspd_n, 0.1)
	return "HP %d  DMG %d  ATK %.2fs  SPD %d" % [
		int(round(hp)), int(round(dmg)), atk_interval, int(stats.get("move_speed", 70))]

## Card for a not-yet-unlocked hero: shows the achievement gating it (name +
## live career progress) instead of the draft/priority controls. Locked heroes
## already fall out of the draft automatically (RunState.roll_draft_offer reads
## GameState.unlocked_heroes) — this card is purely informational.
func _build_locked_hero_card(hero_name: String) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.6)
	style.border_color = PrepPage.INK_COLOR
	style.set_border_width_all(3)
	style.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", style)
	card.modulate = Color(1, 1, 1, 0.4)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	var swatch := ColorRect.new()
	swatch.color = Color(GameState.HERO_CATALOG[hero_name].color, 0.6)
	swatch.custom_minimum_size = Vector2(120, 60)
	box.add_child(swatch)

	box.add_child(_label("%s — LOCKED" % hero_name, 20))

	var role: String = Hero.ROLE_BY_HERO.get(hero_name, "")
	var role_label := _label(role, 15)
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_label.add_theme_color_override("font_color", Hero.ROLE_COLORS.get(role, Color("2c2c2c")))
	box.add_child(role_label)

	var role_desc := _label(Hero.ROLE_DESCRIPTIONS.get(hero_name, ""), 12)
	role_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	role_desc.custom_minimum_size = Vector2(140, 0)
	box.add_child(role_desc)

	var ach_id := Achievements.for_hero(hero_name)
	if ach_id != "":
		var d := Achievements.def(ach_id)
		box.add_child(_label(d.get("name", ach_id), 15))
		box.add_child(_label(_achievement_progress_text(d), 13))
	return card

## "84/150 minions" style progress line for a locked hero's achievement.
func _achievement_progress_text(d: Dictionary) -> String:
	var stat: String = d.get("stat", "")
	var threshold = d.get("threshold", 0)
	var current = GameState.career.get(stat, 0)
	if stat == "best_villain_damage_pct":
		return "%d%% / %d%% villain damage" % [int(float(current) * 100.0), int(float(threshold) * 100.0)]
	return "%d / %d %s" % [int(current), int(threshold), stat.replace("_", " ")]

func _open_abilities() -> void:
	_main.visible = false
	_abilities_page = AbilitiesPage.new()
	_abilities_page.closed.connect(_close_abilities)
	add_child(_abilities_page)

func _close_abilities() -> void:
	_abilities_page.queue_free()
	_abilities_page = null
	_main.visible = true
	_refresh()

func _open_stats() -> void:
	_main.visible = false
	_stats_page = StatsPage.new()
	_stats_page.closed.connect(_close_stats)
	add_child(_stats_page)

func _close_stats() -> void:
	_stats_page.queue_free()
	_stats_page = null
	_main.visible = true
	_rebuild_hero_row()  # banked XP may have changed — refresh the card display
	_refresh()

func _on_start() -> void:
	RunState.start_run()
	GameState.save_game()
	get_tree().change_scene_to_file(GameState.BATTLEFIELD)

func _refresh() -> void:
	_start_button.disabled = RunState.selected_heroes().is_empty()
	if _currency_label != null:
		_currency_label.text = "Gold: %d" % GameState.gold
	if _xp_label != null:
		_xp_label.text = "Banked XP: %d" % GameState.banked_xp

func _label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color("2c2c2c"))
	return l

func _button(text: String, font_size: int, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.pressed.connect(cb)
	return b
