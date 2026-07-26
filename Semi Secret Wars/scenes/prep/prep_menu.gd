class_name PrepMenu
extends Control
## The prep screen — party draft + gold/ability shop, then START into the
## lane battlefield. No priority/support-target pickers — heroes just push
## the lane.
##
## There is no separate "select party" checkbox — dragging a hero into a Duo
## slot IS the selection. A hero only deploys if it's paired (both slots of
## a Duo filled); an unplaced hero sits the run out. See _sync_party_from_slots.

var _start_button: TextureButton
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

## Hand-drawn texture replacing the plain "START RUN" button (Designer,
## 2026-07-25). Cropped tight to the drawn label's bounding box within the
## source PNG so the button isn't mostly transparent padding. Swapped to the
## coloured version 2026-07-26 — same 1590x1152 canvas, so START_RUN_REGION
## carries over; it assumes the redraw sits in the same place on that canvas.
const START_RUN_TEXTURE := preload("res://assets/Button_StartRun_Color.png")
const START_RUN_REGION := Rect2(60, 210, 1500, 640)
const START_RUN_WIDTH := 360.0
const DUO_A_COLOR := UIStyle.DUO_A
const DUO_B_COLOR := UIStyle.DUO_B
const SLOT_SIZE := Vector2(210, 100)

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
		preview.add_theme_stylebox_override("panel",
				UIStyle.panel(Color(swatch_color, 0.85), UIStyle.INK, 3, 10))
		preview.add_child(UIStyle.label(hero_name, UIStyle.SIZE_BODY))
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
	_setup_music()
	RunState.roll_draft_offer()
	_seed_pairing_slots()
	_build_ui()
	_refresh()

## The prep theme lives in prep_menu.tscn, so neither of these can be set in
## the inspector: the Music bus is created at runtime by AudioSettings, and the
## process mode matters because SettingsPanel pauses the tree — a PAUSABLE
## player would go silent the instant the player opened Settings to adjust the
## music volume (Designer, 2026-07-26: music should keep playing while you
## tweak, otherwise there's nothing to tune against).
func _setup_music() -> void:
	var music := get_node_or_null("AudioStreamPlayer2D") as AudioStreamPlayer2D
	if music == null:
		return
	music.bus = AudioSettings.BUS_MUSIC
	music.process_mode = Node.PROCESS_MODE_ALWAYS
	# Loop the theme rather than letting the screen fall silent after one pass —
	# prep is a screen players sit on. Safe to set directly on an MP3 stream;
	# only AudioStreamWAV needs the loop_begin/loop_end care BattleManager
	# documents.
	if music.stream is AudioStreamMP3:
		(music.stream as AudioStreamMP3).loop = true

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

	root.add_child(UIStyle.centered_label("SEMI-SECRET WARS", UIStyle.SIZE_HEADING))

	var meta_row := HBoxContainer.new()
	meta_row.alignment = BoxContainer.ALIGNMENT_CENTER
	meta_row.add_theme_constant_override("separation", 22)
	# Gold and banked XP are what the whole meta-progression is spent in, so
	# they get accent-bordered chips instead of plain text in a row of buttons
	# (Designer, 2026-07-26). Same treatment as the battle HUD's panels.
	_currency_label = _label("", UIStyle.SIZE_SUBHEAD)
	_currency_label.add_theme_color_override("font_color", UIStyle.GOLD)
	meta_row.add_child(_resource_chip(_currency_label, UIStyle.GOLD))
	_xp_label = _label("", UIStyle.SIZE_SUBHEAD)
	_xp_label.add_theme_color_override("font_color", UIStyle.INFO)
	meta_row.add_child(_resource_chip(_xp_label, UIStyle.INFO))
	var abilities_btn := _button("ABILITIES", UIStyle.SIZE_BODY, _open_abilities)
	meta_row.add_child(abilities_btn)
	var stats_btn := _button("STATS", UIStyle.SIZE_BODY, _open_stats)
	meta_row.add_child(stats_btn)
	meta_row.add_child(_button("SETTINGS", UIStyle.SIZE_BODY, _open_settings))
	root.add_child(meta_row)

	_hero_row = HBoxContainer.new()
	_hero_row.add_theme_constant_override("separation", 24)
	root.add_child(_hero_row)
	_rebuild_hero_row()

	_pairing_section = VBoxContainer.new()
	_pairing_section.add_theme_constant_override("separation", 8)
	root.add_child(_pairing_section)
	_rebuild_pairing_panel()

	_start_button = _texture_button(START_RUN_TEXTURE, START_RUN_REGION, _on_start)
	root.add_child(_start_button)

	# Route back to the title screen (Designer, 2026-07-26). No confirmation
	# here: prep changes (purchases, pairings) all save as they're made, so
	# leaving this screen abandons nothing — unlike the battle's version.
	var back_btn := _button("BACK TO MENU", UIStyle.SIZE_SMALL, _on_back_to_menu)
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(back_btn)


## Accent-bordered paper chip around a resource readout. The label is kept as
## a field by the caller (_refresh rewrites its text), so this only wraps it.
func _resource_chip(label: Label, accent: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UIStyle.card(accent, 10))
	chip.add_child(label)
	return chip

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

	var offered: Array = RunState.draft_offer.duplicate()

	# Drop any slot occupant that fell out of the offer (shouldn't normally
	# happen — offer only changes via unlocks — but keeps state sane).
	for i in _pairing_slots.size():
		if _pairing_slots[i] != "" and _pairing_slots[i] not in offered:
			_pairing_slots[i] = ""

	# Three columns so the panel stays short (Designer, 2026-07-26: the stacked
	# header/hint/button rows were pushing the screen past its top and bottom
	# edges): explanation left, the Duo boxes centered, status + CLEAR right.
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	_pairing_section.add_child(row)

	var explain := UIStyle.wrapped_label(
			"Drag your heroes and pick your DUOs. Each DUO has its unique ultimate ability.",
			240, UIStyle.SIZE_SMALL)
	explain.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(explain)

	var boxes := HBoxContainer.new()
	boxes.alignment = BoxContainer.ALIGNMENT_CENTER
	boxes.add_theme_constant_override("separation", 32)
	row.add_child(boxes)
	boxes.add_child(_build_duo_box(0, "DUO A", DUO_A_COLOR))
	boxes.add_child(_build_duo_box(1, "DUO B", DUO_B_COLOR))

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 8)
	side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(side)

	var unplaced := offered.filter(func(h: String) -> bool: return h not in _pairing_slots)
	side.add_child(UIStyle.wrapped_label(_pairing_hint_text(unplaced), 240, UIStyle.SIZE_SMALL))

	if _pairing_slots.count("") < 4:
		var clear_btn := _button("CLEAR PAIRING", UIStyle.SIZE_SMALL, _on_reset_pairing)
		clear_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		side.add_child(clear_btn)

func _pairing_hint_text(unplaced: Array) -> String:
	if unplaced.is_empty():
		return "Every hero is placed."
	return "Not deploying unless paired: %s" % ", ".join(unplaced)

## One Duo box: a colored-border panel labeled "DUO A"/"DUO B" containing its
## 2 DuoSlot drop targets side by side.
func _build_duo_box(duo_index: int, title: String, color: Color) -> PanelContainer:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UIStyle.card(color, 10, duo_index))

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	box.add_child(col)

	col.add_child(UIStyle.centered_label(title, UIStyle.SIZE_SMALL, color))

	var slots_row := HBoxContainer.new()
	slots_row.add_theme_constant_override("separation", 8)
	col.add_child(slots_row)
	slots_row.add_child(_build_duo_slot(duo_index, 0, color))
	slots_row.add_child(_build_duo_slot(duo_index, 1, color))

	col.add_child(_build_ultimate_label(duo_index))

	return box

## Duo Ultimate chip: only shown once both slots of this Duo are filled, since
## the Ultimate is a property of the PAIR (DuoUltimates — one exclusive entry
## per unordered hero pair). Shows the same name/desc the in-battle Duo
## Ultimate bar will show, so the player picks a pairing knowing what it
## unlocks (Designer, 2026-07-25).
##
## This replaced the named-synergy chip that used to sit here. That catalog
## (DuoSynergies) was deleted outright on 2026-07-26 once its last reader — the
## battlefield's "DUO A: <name>" banner — was removed too: the names were never
## used for anything, and all six shared one generic blurb. The generic Duo
## Bonus mechanic in Hero (DUO_* consts, _update_duo_bonus) is untouched; it
## never depended on that catalog.
func _build_ultimate_label(duo_index: int) -> Control:
	var hero_a: String = _pairing_slots[duo_index * 2]
	var hero_b: String = _pairing_slots[duo_index * 2 + 1]
	if hero_a == "" or hero_b == "":
		return Control.new()
	var d := DuoUltimates.def(DuoUltimates.id_for_heroes(hero_a, hero_b))
	if d.is_empty():
		return Control.new()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.add_child(UIStyle.centered_label("DUO ULTIMATE", UIStyle.SIZE_TINY, UIStyle.INK_MUTED))
	col.add_child(UIStyle.centered_label(d.get("name", ""), UIStyle.SIZE_SMALL, UIStyle.GOLD))
	col.add_child(UIStyle.wrapped_label(d.get("desc", ""), 400, UIStyle.SIZE_TINY, UIStyle.INK_MUTED))
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
	# Filled slots take the hero's own tint over paper; empty ones are a faint
	# dashed-looking outline so the drop target reads as "not drawn in yet".
	var style := (UIStyle.panel(Color(GameState.HERO_CATALOG[hero_name].color, 0.45),
					color, 3, 6, slot_index)
			if hero_name != ""
			else UIStyle.panel(Color(UIStyle.PAGE_SOLID, 0.35), Color(color, 0.4), 2, 6, slot_index))
	slot.add_theme_stylebox_override("panel", style)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)

	var tag_row := CenterContainer.new()
	tag_row.add_child(UIStyle.label("LEADER" if is_leader_slot else "FOLLOWER",
			UIStyle.SIZE_TINY, UIStyle.GOLD if is_leader_slot else UIStyle.INK_MUTED))
	col.add_child(tag_row)

	var center := CenterContainer.new()
	center.add_child(UIStyle.label(hero_name if hero_name != "" else "drop hero",
			UIStyle.SIZE_SMALL, UIStyle.INK if hero_name != "" else UIStyle.INK_MUTED))
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
	card.add_theme_stylebox_override("panel", UIStyle.card(UIStyle.INK, 16, hero_name.length()))
	if not offered:
		card.modulate = UIStyle.DIM

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	# The hero's real battlefield sprite, not a colour swatch — the roster and
	# the field now show literally the same drawing (UIStyle.hero_portrait).
	box.add_child(UIStyle.hero_portrait(hero_name, Vector2(110, 78)))

	box.add_child(UIStyle.centered_label(hero_name, UIStyle.SIZE_SUBHEAD))

	var role: String = Hero.ROLE_BY_HERO.get(hero_name, "")
	box.add_child(UIStyle.centered_label(role, UIStyle.SIZE_SMALL,
			Hero.ROLE_COLORS.get(role, UIStyle.INK)))
	box.add_child(UIStyle.wrapped_label(Hero.ROLE_DESCRIPTIONS.get(hero_name, ""), 210))
	box.add_child(_build_stats_block(hero_name))

	return card

## The two stat lines on their own paper block, numbers bolded (Designer,
## 2026-07-26). Both were plain tiny text sitting directly on the card, so the
## values ran together with the role blurb above them; the inset panel gives
## them an edge to read against and the embolden separates the numbers from
## their labels at a glance.
func _build_stats_block(hero_name: String) -> PanelContainer:
	var block := PanelContainer.new()
	# Slightly deeper than the card it sits on, so it reads as an inset panel
	# rather than a second card floating on the first.
	block.add_theme_stylebox_override("panel",
			UIStyle.panel(Color(UIStyle.PAGE_SOLID, 0.55), UIStyle.INK_MUTED, 2, 8,
					hero_name.length()))

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	block.add_child(col)

	col.add_child(UIStyle.rich_stat_label(_current_stats_text(hero_name), UIStyle.SIZE_TINY))
	col.add_child(UIStyle.rich_stat_label(_lifetime_stats_text(hero_name),
			UIStyle.SIZE_TINY, UIStyle.INK_MUTED))
	return block

## Lifetime totals across every run (GameState.hero_stats) — separate from
## the live per-run numbers shown on the battle hero card.
func _lifetime_stats_text(hero_name: String) -> String:
	var pct := GameState.hero_ability_pct_lifetime(hero_name)
	var abl_text := "%d%%" % int(round(pct)) if pct >= 0.0 else "—"
	# BBCode, not plain text — rendered by UIStyle.rich_stat_label so the values
	# come out bold while their labels stay light.
	return "KILLS [b]%d[/b]  ·  XP [b]%d[/b]  ·  ABL [b]%s[/b]" % [
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
	# BBCode — see _lifetime_stats_text.
	return "HP [b]%d[/b]  DMG [b]%d[/b]  ATK [b]%.2fs[/b]  SPD [b]%d[/b]" % [
		int(round(hp)), int(round(dmg)), atk_interval, int(stats.get("move_speed", 70))]

## Card for a not-yet-unlocked hero: shows the achievement gating it (name +
## live career progress) instead of the draft/priority controls. Locked heroes
## already fall out of the draft automatically (RunState.roll_draft_offer reads
## GameState.unlocked_heroes) — this card is purely informational.
func _build_locked_hero_card(hero_name: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIStyle.card(UIStyle.INK, 16, hero_name.length()))
	card.modulate = UIStyle.DIM

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	# Same portrait treatment as an unlocked card — the card-wide DIM modulate
	# above is what reads as "locked", so the silhouette still teases the art.
	box.add_child(UIStyle.hero_portrait(hero_name, Vector2(110, 78)))

	box.add_child(UIStyle.centered_label("%s — LOCKED" % hero_name, UIStyle.SIZE_BODY))

	var role: String = Hero.ROLE_BY_HERO.get(hero_name, "")
	box.add_child(UIStyle.centered_label(role, UIStyle.SIZE_SMALL,
			Hero.ROLE_COLORS.get(role, UIStyle.INK)))
	box.add_child(UIStyle.wrapped_label(Hero.ROLE_DESCRIPTIONS.get(hero_name, ""), 210))

	var ach_id := Achievements.for_hero(hero_name)
	if ach_id != "":
		var d := Achievements.def(ach_id)
		box.add_child(UIStyle.centered_label(d.get("name", ach_id), UIStyle.SIZE_SMALL, UIStyle.GOLD))
		box.add_child(UIStyle.centered_label(_achievement_progress_text(d), UIStyle.SIZE_TINY))
	return card

## "84/150 minions" style progress line for a locked hero's achievement.
func _achievement_progress_text(d: Dictionary) -> String:
	var stat: String = d.get("stat", "")
	var threshold = d.get("threshold", 0)
	var current = GameState.career.get(stat, 0)
	if stat == "best_villain_damage_pct":
		return "%d%% / %d%% villain damage" % [int(float(current) * 100.0), int(float(threshold) * 100.0)]
	return "%d / %d %s" % [int(current), int(threshold), stat.replace("_", " ")]

## Settings is a self-parenting overlay (SettingsPanel.open adds itself to the
## scene root), so unlike the ABILITIES/STATS pages it doesn't hide _main or
## need a close handler here — it draws over the prep screen and frees itself.
func _open_settings() -> void:
	SettingsPanel.toggle(self)

## Escape opens Settings, matching the title screen. Not wired to BACK TO MENU:
## Escape reaching for "leave the screen" while a player is mid-pairing would
## be the one destructive reading of the key.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_open_settings()

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

func _on_back_to_menu() -> void:
	get_tree().change_scene_to_file(GameState.TITLE_SCREEN)

func _on_start() -> void:
	RunState.start_run()
	GameState.save_game()
	get_tree().change_scene_to_file(GameState.BATTLEFIELD)

func _refresh() -> void:
	_start_button.disabled = RunState.selected_heroes().is_empty()
	_start_button.modulate = UIStyle.DIM if _start_button.disabled else Color.WHITE
	if _currency_label != null:
		_currency_label.text = "Gold: %d" % GameState.gold
	if _xp_label != null:
		_xp_label.text = "Banked XP: %d" % GameState.banked_xp

func _label(text: String, font_size: int) -> Label:
	return UIStyle.label(text, font_size)

func _button(text: String, font_size: int, cb: Callable) -> Button:
	return UIStyle.button(text, font_size, cb)

## AtlasTexture crop of `texture` at `region`, scaled to a normal button size
## (see START_RUN_TEXTURE/START_RUN_REGION doc).
func _texture_button(texture: Texture2D, region: Rect2, cb: Callable) -> TextureButton:
	return UIStyle.texture_button(texture, region, START_RUN_WIDTH, cb)
