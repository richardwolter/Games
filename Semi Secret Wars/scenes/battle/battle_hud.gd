class_name BattleHUD
extends CanvasLayer
## Displays live battle state: villain HP, hero panels, objective progress, farm XP.

@export var villain_hp_label_path: NodePath = "VillainHPLabel"
@export var villain_hp_bar_path: NodePath = "VillainHPBar"
@export var hero_panels_root_path: NodePath = "HeroPanelsRoot"
@export var objective_label_path: NodePath = "ObjectiveLabel"
@export var objective_bar_path: NodePath = "ObjectiveBar"
## The panel wrapping the objective label + bar — hidden entirely on levels
## that author no objectives (all current lanes), so the HUD doesn't carry a
## dead panel; get_node_or_null keeps it optional.
@export var objective_panel_path: NodePath = "ObjectivePanel"
@export var run_xp_label_path: NodePath = "RunXPLabel"
## Live gold drip (GameState.bank_gold — per-kill/per-gate payouts land
## mid-battle); get_node_or_null keeps this optional.
@export var gold_label_path: NodePath = "GoldPanel/GoldLabel"
@export var timer_label_path: NodePath = "TimerPanel/TimerLabel"
@export var buff_panel_path: NodePath = "ObjectiveBuffPanel"
@export var buff_label_path: NodePath = "ObjectiveBuffPanel/BuffLabel"
@export var back_button_path: NodePath = "BackButton"

var hero_panel_scene: PackedScene

var _villain_hp_label: RichTextLabel
var _villain_hp_bar: ProgressBar
var _villain: Node
var _villain_seen := false
## The panel wrapping the villain readout, hidden until first contact — see
## _check_villain_contact.
var _villain_panel: Control
var _villain_revealed := false
var _hero_panels_root: Node
var _objective_label: RichTextLabel
var _objective_bar: ProgressBar
var _objective_panel: Control
var _run_xp_label: RichTextLabel
var _gold_label: RichTextLabel
var _timer_label: RichTextLabel
var _elapsed := 0.0
var _hero_panels: Dictionary = {}  # hero_name -> panel_node

var _buff_panel: Control
var _buff_label: RichTextLabel
## Countdown driving the objective-buff banner; independent of the actual
## hero buff timers (which can be refreshed/stacked across heroes), so it
## always reflects the single reward just granted.
var _buff_text := ""
var _buff_color := Color.WHITE
var _buff_t := 0.0
var _buff_duration := 0.0

## DUO CONTROL (Designer, 2026-07-30) — one small panel carrying BOTH Duos'
## REFOCUS and ULTIMATE buttons. Replaces two separate UIs: the per-Duo REFOCUS
## button that used to sit inside each hero-card group here, and the standalone
## Duo Ultimate card bar. Built in code; see duo_control_bar.gd.
var _duo_control: DuoControlBar

## Inner padding on a Duo group's border. Deliberately tight: the group wraps two
## full hero cards in a column that has to fit under the villain readout without
## pushing the second Duo off the bottom of the screen.
const DUO_GROUP_MARGIN := 6


func _ready() -> void:
	_villain_hp_label = get_node(villain_hp_label_path)
	_villain_hp_bar = get_node(villain_hp_bar_path)
	# VillainPanel, two levels up from the label (panel -> VBox -> label). Walked
	# rather than exported so battlefield.tscn needs no new NodePath property.
	_villain_panel = _villain_hp_label.get_parent().get_parent() as Control
	if _villain_panel != null:
		_villain_panel.visible = false
	_hero_panels_root = get_node(hero_panels_root_path)
	_objective_label = get_node(objective_label_path)
	_objective_bar = get_node(objective_bar_path)
	_objective_panel = get_node_or_null(objective_panel_path)
	# Hidden HERE, not just in _update_objective (Designer, 2026-07-30: "a strange
	# UI leftover on the bottom of the screen (a grey bar)" behind the reDuo
	# overlay). It is authored visible in battlefield.tscn and only gets hidden by
	# _process — which never runs before the start-of-level overlays pause the
	# tree, so on every level with no objectives (all of them, currently) an empty
	# panel sat at the bottom of the screen through the whole pre-battle flow.
	if _objective_panel != null:
		_objective_panel.visible = false
	_run_xp_label = get_node(run_xp_label_path)
	_gold_label = get_node_or_null(gold_label_path)
	_timer_label = get_node(timer_label_path)
	_buff_panel = get_node(buff_panel_path)
	_buff_label = get_node(buff_label_path)
	_make_readouts_numeric()
	var back_btn: Button = get_node(back_button_path)
	# Authored in battlefield.tscn rather than built by UIStyle.button, so the
	# click sound and hover wiggle both have to be added by hand here. The sound
	# goes on before _on_back_pressed for the connection-order reason in
	# UIStyle.add_click_sound's doc.
	UIStyle.add_click_sound(back_btn)
	back_btn.pressed.connect(_on_back_pressed)
	# Clickable at ANY point in the battle (Designer, 2026-07-26). The tree
	# pauses for a level-up/boon pick and for the confirm prompt itself, and a
	# paused Button stops receiving input — so this one opts out of pausing.
	# Its own CanvasLayer/HUD parent keeps default process mode; only the
	# button needs to stay live.
	back_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	UIStyle.add_hover_wiggle(back_btn)
	_emphasize_resource_panels()
	_build_top_left_cluster(back_btn)
	_build_duo_control()
	_build_card_hint()

## Gold and XP are the two numbers a run is actually played for, and they were
## reading as ordinary HUD text (Designer, 2026-07-26). Both get an accent
## border and a size step up, matching the emphasis the prep menu gives the
## same two values. Applied in code rather than in battlefield.tscn so the
## treatment stays defined in one place alongside the prep-menu version.
## The colours and size come from UIStyle's currency block, the same source the
## prep menu, abilities page, stats page and results screen now read — so the
## two numbers look identical on every screen that shows them.
func _emphasize_resource_panels() -> void:
	_style_resource_panel(_gold_label, UIStyle.GOLD_COLOR)
	_style_resource_panel(_run_xp_label, UIStyle.XP_COLOR)

func _style_resource_panel(label: RichTextLabel, accent: Color) -> void:
	if label == null:
		return
	UIStyle.make_numeric(label, UIStyle.SIZE_CURRENCY, accent)
	var panel := label.get_parent() as PanelContainer
	if panel != null:
		panel.add_theme_stylebox_override("panel", UIStyle.card(accent, 10))

## Every HUD readout is a RichTextLabel so its digits can be bolded per-glyph
## (Designer, 2026-07-26 — DrawFont's "g" and "9" are nearly the same shape).
## The font size that used to live on each node in battlefield.tscn is applied
## here instead, since a RichTextLabel needs it under a different theme key
## (normal_font_size) and needs the bold face wired up besides.
##
## Gold and XP are deliberately absent: _emphasize_resource_panels does the same
## job for those two with their own accent colour.
const HUD_READOUT_SIZE := 26

func _make_readouts_numeric() -> void:
	UIStyle.make_numeric(_villain_hp_label, HUD_READOUT_SIZE)
	UIStyle.make_numeric(_objective_label, HUD_READOUT_SIZE)
	# Timer and buff banner were horizontal_alignment=1 as Labels; centering is
	# part of the text for a RichTextLabel, hence the flag.
	UIStyle.make_numeric(_timer_label, HUD_READOUT_SIZE, UIStyle.INK, true)
	UIStyle.make_numeric(_buff_label, HUD_READOUT_SIZE, UIStyle.INK, true)

## The whole top-left corner is ONE row: XP, GOLD, ABANDON RUN, SETTINGS
## (Designer, 2026-07-30). The four used to be scattered — XP at x16 and GOLD at
## x300 with 280px of empty paper between them, ABANDON RUN on a second line
## under them, and SETTINGS pinned to the opposite corner entirely. Grouping them
## makes one "your run's state and the way out" cluster and frees the whole top
## strip in between.
##
## Built by reparenting the authored panels into an HBoxContainer rather than by
## re-offsetting each: a PanelContainer sizes to its own text ("GOLD: 12" vs
## "GOLD: 1240"), so any hardcoded x for the panel beside it is wrong as soon as
## the number grows a digit. The box re-flows instead.
const CLUSTER_MARGIN := Vector2(16.0, 10.0)
const CLUSTER_SEPARATION := 10

func _build_top_left_cluster(back_btn: Button) -> void:
	var settings_btn := UIStyle.button("SETTINGS", UIStyle.SIZE_SMALL, _on_settings_pressed)
	# Reachable during a level-up pick, which pauses the tree — same reason the
	# abandon button opts out of pausing.
	settings_btn.process_mode = Node.PROCESS_MODE_ALWAYS

	var row := HBoxContainer.new()
	row.position = CLUSTER_MARGIN
	row.add_theme_constant_override("separation", CLUSTER_SEPARATION)
	# Mouse-transparent itself so the empty space between chips never eats a click
	# meant for the battlefield; the two buttons keep their own filters.
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	# The two currency chips are taller than the buttons, so the buttons centre
	# against them rather than stretching to match.
	for chip in [_panel_of(_run_xp_label), _panel_of(_gold_label)]:
		if chip == null:
			continue
		chip.get_parent().remove_child(chip)
		chip.position = Vector2.ZERO
		row.add_child(chip)
	for btn in [back_btn, settings_btn]:
		if btn.get_parent() != null:
			btn.get_parent().remove_child(btn)
		# The .tscn pins ABANDON RUN with explicit offsets; inside a container
		# those fight the layout, so both buttons go back to plain sizing.
		btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(btn)

## The PanelContainer wrapping a HUD readout, or null — the chips are authored as
## label-inside-panel in battlefield.tscn and the HUD only keeps the label.
func _panel_of(label: RichTextLabel) -> PanelContainer:
	if label == null:
		return null
	return label.get_parent() as PanelContainer

func _on_settings_pressed() -> void:
	SettingsPanel.toggle(self)

## Escape opens/closes Settings mid-battle. SettingsPanel consumes Escape while
## it's up (so the key closes it rather than re-firing this), and ConfirmPanel
## does the same for the BACK TO MENU prompt.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_settings_pressed()

func _build_duo_control() -> void:
	_duo_control = DuoControlBar.new()
	add_child(_duo_control)

## Gap between the bottom hero card and the Hero Control panel — close enough
## that the controls read as belonging to the cards above them, not as a separate
## panel parked at the bottom of the screen (Designer, 2026-07-30).
const GAP_BELOW_CARDS := 10.0
## Never let the panel run off the bottom of the 1080 design canvas, however tall
## the card column gets (four cards in two Duo groups is the worst case).
const DUO_CONTROL_MAX_Y := 890.0

## Keeps the panel pinned under the card column. Done every frame rather than
## once at build time because the column's height CHANGES mid-battle: a Duo group
## drops a card when a hero falls, and the cards themselves only get their real
## size after the container has laid out, which is a frame later than _ready.
## Cheap — an early-out compare, no work when nothing moved.
func _place_duo_control() -> void:
	if _duo_control == null or _hero_panels_root == null:
		return
	var root := _hero_panels_root as Control
	if root == null:
		return
	var y := minf(root.position.y + root.size.y + GAP_BELOW_CARDS, DUO_CONTROL_MAX_Y)
	if not is_equal_approx(_duo_control.position.y, y):
		_duo_control.position.y = y

## NOTE: rebuild_duo_ui() — which re-derived the DUO CONTROL rows and the
## hero-card groups after a mid-run pairing change — was removed on 2026-07-30
## with the Duo reshuffle mechanic itself (see BattleManager). Pairings are fixed
## at prep for the whole run now, so both are built once and can't go stale.

## Caption over the hero cards (Designer, 2026-07-30) telling the player what
## clicking one does — the camera lock (_on_hero_panel_clicked) is otherwise an
## undiscoverable feature, since a card doesn't look like a button.
##
## Sits in the gap between the top-left resource/menu row and HeroPanelsRoot's
## y130, at the cards' own x, so it reads as a label ON the column rather than as
## another HUD readout.
##
## Given a bordered gold chip on its own (Designer, 2026-07-30: "give more visual
## clarity to card hint") — as plain muted ink it disappeared into the paper
## background it sits on, which is exactly the failure mode the instruction on the
## prep pairing panel had. Gold is this UI's "do something here" colour, it
## matches the FOCUS_COLOR the card's name turns when the lock is on, and the
## border gives the text an edge to read against over the drawn battlefield.
const CARD_HINT_POSITION := Vector2(16.0, 88.0)
const CARD_HINT_WIDTH := 330.0

func _build_card_hint() -> void:
	var chip := PanelContainer.new()
	chip.position = CARD_HINT_POSITION
	chip.custom_minimum_size = Vector2(CARD_HINT_WIDTH, 0)
	chip.add_theme_stylebox_override("panel", UIStyle.card(FOCUS_HINT_COLOR, 6))
	# Purely a caption: it must never eat a click meant for the card under it.
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := UIStyle.centered_label("Click on DUO to lock camera",
			UIStyle.SIZE_SMALL, FOCUS_HINT_COLOR)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(label)
	add_child(chip)

## Same gold HeroPanelUI.FOCUS_COLOR turns a locked hero's name — the hint and
## the thing it points at share one colour.
const FOCUS_HINT_COLOR := UIStyle.GOLD

## NOTE: the centre-screen "ULTIMATE — <name>" flash (built here, fired by
## BattleManager.activate_ultimate) was removed on 2026-07-30 at the Designer's
## call. It was added on 2026-07-29 because the activation was easy to miss, but
## a heading-sized banner mid-screen covered the very cast it was announcing. The
## feedback that remains: the cast FX and its sound on the field, and the DUO
## CONTROL button popping and fading to USED.

## Leaving mid-battle ABANDONS the run: nothing about this level is banked (no
## gold payout, no level advance — BattleManager._end never runs), and run
## state is reset when the next run starts. That's destructive enough to ask
## first (Designer, 2026-07-26).
func _on_back_pressed() -> void:
	ConfirmPanel.ask(self, "ABANDON RUN?",
			"Leaving now ends this run. All XP collected and gold are lost.",
			"ABANDON", _leave_to_prep)

func _leave_to_prep() -> void:
	# Abandoning is one of the run-ending outcomes, so the resumable save goes
	# with it — otherwise CONTINUE would offer to resume the run the player just
	# chose to throw away. start_run() clears the file itself (see RunState).
	RunState.start_run()
	# Unpause first: a prompt answered while a boon pick had the tree paused
	# would otherwise carry that pause into the prep menu, freezing it.
	get_tree().paused = false
	get_tree().change_scene_to_file(GameState.PREP_MENU)

func _process(delta: float) -> void:
	_update_villain_hp()
	_update_run_xp()
	_update_gold()
	_update_objective()
	_update_hero_panels()
	_update_timer(delta)
	_update_objective_buff(delta)
	_duo_control.refresh()
	_place_duo_control()

## Shows the objective-completion reward banner with a live countdown.
## `duration` <= 0 means an instant/permanent grant (e.g. the shield charges)
## shown briefly rather than counted down.
func show_objective_buff(text: String, color: Color, duration: float) -> void:
	_buff_text = text
	_buff_color = color
	_buff_duration = maxf(duration, 2.0)
	_buff_t = _buff_duration
	_buff_panel.visible = true
	_update_objective_buff(0.0)

func _update_objective_buff(delta: float) -> void:
	if _buff_t <= 0.0:
		return
	_buff_t = maxf(_buff_t - delta, 0.0)
	var secs := int(ceil(_buff_t))
	UIStyle.set_numeric_text(_buff_label, "BUFF: %s  %d:%02d" % [_buff_text, secs / 60, secs % 60])
	_buff_label.modulate = _buff_color
	if _buff_t <= 0.0:
		_buff_panel.visible = false

## Builds the party's hero cards, grouped by Duo: each pairing gets one bordered
## group holding both members' cards (Designer, 2026-07-29 — the two members of a
## Duo share one card rather than being read individually). A hero in the party
## but not in any valid pairing still gets a plain ungrouped card, so a
## broken/absent pairing can never make a hero invisible on the HUD.
##
## The Duo's REFOCUS button used to live inside this group; it moved to the
## DUO CONTROL panel on 2026-07-30 — see _build_duo_control.
##
## Idempotent — clears whatever is there first, so calling it again is safe even
## though BattleManager only ever calls it once per level now.
func setup_heroes(hero_names: PackedStringArray) -> void:
	for child in _hero_panels_root.get_children():
		_hero_panels_root.remove_child(child)
		child.free()
	_hero_panels.clear()

	var grouped := {}
	var duo_index := 0
	for pair in GameState.duo_pairings:
		if not (pair is Array) or (pair as Array).size() != 2:
			continue
		# Only the members who actually made it to this level (the other may be
		# dead — RunState.living_party is what we're handed).
		var members := PackedStringArray()
		for h in pair:
			if h in hero_names:
				members.append(h)
		if members.is_empty():
			continue
		_hero_panels_root.add_child(_build_duo_group(duo_index, members))
		duo_index += 1
		for h in members:
			grouped[h] = true

	for hero_name in hero_names:
		if hero_name in grouped:
			continue
		_hero_panels_root.add_child(_build_hero_panel(hero_name))

## One Duo's shared card: a bordered group in that Duo's accent holding both
## members' hero cards. `duo_index` is 0 for the first group built and 1 for the
## second — it picks the accent and the hand-drawn wobble variant, and used to be
## implied by the refocus-button count before those buttons moved out.
##
## The vertical budget here is tight: four hero cards overran the 1080 canvas
## before the hero card's own margins were trimmed and HeroPanelsRoot was moved
## 10px higher. Losing the two REFOCUS rows to DUO CONTROL bought that back with
## room to spare, but if the card margins drift the bottom card goes off screen.
func _build_duo_group(duo_index: int, members: PackedStringArray) -> PanelContainer:
	var group := PanelContainer.new()
	var accent: Color = UIStyle.DUO_A if duo_index == 0 else UIStyle.DUO_B
	group.add_theme_stylebox_override("panel",
			UIStyle.card(accent, DUO_GROUP_MARGIN, duo_index))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	group.add_child(box)

	for member in members:
		box.add_child(_build_hero_panel(member))
	return group

func _build_hero_panel(hero_name: String) -> Control:
	var panel = hero_panel_scene.instantiate()
	panel.hero_name = hero_name
	panel.clicked.connect(_on_hero_panel_clicked)
	_hero_panels[hero_name] = panel
	return panel

## Panel click: toggle the battle camera's follow lock onto that hero.
func _on_hero_panel_clicked(hero_name: String) -> void:
	var cam = get_tree().get_first_node_in_group("battle_camera")
	if cam == null:
		return
	for h in get_tree().get_nodes_in_group("heroes"):
		if h is Hero and h.hero_name == hero_name:
			cam.focus_on(h)
			return

## How close a hero has to get to the villain to count as "in contact" and reveal
## the readout. Generous — a little past the villain's own detect range, so the
## panel is already up by the time the two are actually trading blows rather than
## appearing mid-swing.
const VILLAIN_REVEAL_DIST := 340.0

## True once the party has met the villain: either somebody got close enough, or
## he has taken damage (a ranged opener or an Ultimate can land from outside
## VILLAIN_REVEAL_DIST). Latched — the panel never hides again once shown, since
## the fight is on from that point on.
func _check_villain_contact() -> void:
	if _villain_revealed or _villain == null or not is_instance_valid(_villain):
		return
	if _villain.hp < _villain.max_hp:
		_villain_revealed = true
		return
	for h in get_tree().get_nodes_in_group("heroes"):
		if h is Node2D and h.global_position.distance_to(_villain.global_position) \
				<= VILLAIN_REVEAL_DIST:
			_villain_revealed = true
			return

func _update_villain_hp() -> void:
	if not is_instance_valid(_villain):
		_villain = null
		var villains = get_tree().get_nodes_in_group("villains")
		if not villains.is_empty():
			_villain = villains[0]
			_villain_seen = true

	_check_villain_contact()
	# Hidden until the party meets him (Designer, 2026-07-30): a health bar for
	# somebody the player hasn't reached yet is a spoiler and a distraction, and
	# the villain's own reveal is worth more than the warning (the same reason
	# HowToPlayPanel shows him as a "?"). Once revealed it stays up, including
	# after he dies so the DEFEATED line can be read.
	if _villain_panel != null:
		_villain_panel.visible = _villain_revealed

	if _villain == null:
		if _villain_seen:
			UIStyle.set_numeric_text(_villain_hp_label, "VILLAIN: DEFEATED")
			_villain_hp_bar.value = 0.0
		return

	var pct = int(round(100.0 * _villain.hp / _villain.max_hp))
	var villain_name = _villain.label_text if _villain.label_text != "" else "VILLAIN"
	UIStyle.set_numeric_text(_villain_hp_label, "%s HP: %d%%" % [villain_name, pct])
	_villain_hp_bar.value = float(_villain.hp) / _villain.max_hp

func _update_run_xp() -> void:
	var total = 0
	for x in GameState.run_xp.values():
		total += int(x)
	UIStyle.set_numeric_text(_run_xp_label, "XP: %d" % total)

## Live gold total, so the per-kill/per-gate drip (GameState.bank_gold) is
## visible as it happens rather than only showing up back at prep.
func _update_gold() -> void:
	if _gold_label == null:
		return
	UIStyle.set_numeric_text(_gold_label, "GOLD: %d" % GameState.gold)

func _update_objective() -> void:
	var objs = get_tree().get_nodes_in_group("objectives")
	if _objective_panel != null:
		_objective_panel.visible = not objs.is_empty()
	if objs.is_empty():
		UIStyle.set_numeric_text(_objective_label, "")
		return

	# Bar tracks whichever objective is furthest along, so progress on any
	# one of them is visible even while the other sits untouched.
	var lead = objs[0]
	for o in objs:
		if o.progress > lead.progress:
			lead = o
	_objective_bar.value = lead.progress

	var lines: Array[String] = []
	for i in objs.size():
		var o = objs[i]
		var tag := "OBJ %d" % (i + 1) if objs.size() > 1 else "OBJECTIVE"
		if o.is_captured:
			lines.append("%s: CAPTURED" % tag)
		elif o.contested:
			lines.append("%s: CONTESTED %d%%" % [tag, int(o.progress * 100.0)])
		else:
			lines.append("%s: %d%%" % [tag, int(o.progress * 100.0)])
	UIStyle.set_numeric_text(_objective_label, "\n".join(lines))

## Wall-clock time spent on the battlefield this run, MM:SS.
func _update_timer(delta: float) -> void:
	_elapsed += delta
	var total_seconds := int(_elapsed)
	UIStyle.set_numeric_text(_timer_label, "%02d:%02d" % [total_seconds / 60, total_seconds % 60])

func _update_hero_panels() -> void:
	var alive := {}
	for h in get_tree().get_nodes_in_group("heroes"):
		if h is Hero:
			alive[h.hero_name] = h

	# Followed hero (if any) so panels can mirror the camera lock, including
	# when the lock is broken camera-side (manual pan, hero death).
	var followed: Node2D = null
	var cam = get_tree().get_first_node_in_group("battle_camera")
	if cam != null:
		followed = cam.follow_target()

	var bm := get_tree().get_first_node_in_group("battle_manager")

	for hero_name in _hero_panels:
		var panel = _hero_panels[hero_name]
		if hero_name in alive:
			var h = alive[hero_name]
			# No level/intent line any more (Designer, 2026-07-26) — the card's top
			# row is the hero's portrait and name.
			panel.update_display(hero_name, h.hp, h.max_hp, h.ability_cooldown, h.ability_cooldown_max(), h.active_buffs(), h.ability_name(), h.second_ability_name(), h.second_ability_cooldown, h.second_ability_cooldown_max(), GameState.hero_kills_run(hero_name), GameState.hero_xp_run(hero_name))
			panel.set_focused(followed == h)
		elif bm != null and bm.has_method("is_deploy_phase") and bm.is_deploy_phase():
			# Nobody has spawned yet — show the card the player will be looking
			# at all battle rather than a row of DOWN panels (Designer,
			# 2026-07-26).
			panel.set_predeploy(hero_name,
					RunState.carried_fraction(hero_name),
					Hero.ability_name_for(hero_name),
					GameState.hero_kills_run(hero_name), GameState.hero_xp_run(hero_name))
			panel.set_focused(false)
		else:
			panel.set_ko()
			panel.set_focused(false)
