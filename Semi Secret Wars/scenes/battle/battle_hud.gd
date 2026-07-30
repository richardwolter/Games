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

## Second-Duo-wave arrival countdown chip — built in code (no .tscn node for
## it) since it's new and small; polls BattleManager.duo_b_seconds_remaining()
## every frame so the player can watch the timer against the live fight.
var _duo_b_label: RichTextLabel

## Duo Ultimate activation bar (2026-07-22) — the "DUO Cards UI" ACTIVATE
## buttons live on. Built in code like _duo_b_label; see duo_ultimate_bar.gd.
var _duo_ultimate_bar: DuoUltimateBar

## pair_id -> that Duo's REFOCUS Button, which lives inside the Duo's own hero
## card group (Designer, 2026-07-29: the refocus belongs on the hero cards, and
## the two members of a Duo share one card rather than being clicked
## individually). Built by setup_heroes, state-refreshed every frame — see
## _refresh_refocus_buttons and focus_ping.gd.
var _refocus_buttons: Dictionary = {}
## The party setup_heroes was last called with, so the panels can be rebuilt into
## fresh Duo groups after the start-of-level reshuffle changes the pairings.
var _party_names := PackedStringArray()
## Inner padding on a Duo group's border. Deliberately tight: the group wraps two
## full hero cards plus a button in a column that has to fit under the villain
## readout without pushing the second Duo off the bottom of the screen.
const DUO_GROUP_MARGIN := 6
## The centered REFOCUS button: wide enough for its longest state text
## ("CLICK A SPOT") on one line, and deliberately far short of the 330px card
## width so it reads as a small shared control rather than a third row of card.
const REFOCUS_BUTTON_WIDTH := 168.0
## Vertical padding on it, against UIStyle.COMPACT_BUTTON_PAD_Y's 12 — see the
## vertical-budget note on _build_duo_group.
const REFOCUS_BUTTON_PAD_Y := 4.0
## Spent-refocus fade, matching the Ultimate card's send-off exactly
## (DuoUltimateBar.SPENT_ALPHA / _play_spend): the button pops, then drops to a
## ghost that no longer competes for attention or covers the view.
const REFOCUS_SPENT_ALPHA := 0.12
const REFOCUS_POP_TIME := 0.18
const REFOCUS_FADE_TIME := 0.9
## pair_ids whose spend animation has already run, so the every-frame refresh
## fires it exactly once.
var _refocus_spent_shown: Dictionary = {}

## Centre-screen flash announcing a Duo Ultimate activation, so the player can't
## miss that it fired (Designer, 2026-07-29). Held for BANNER_HOLD then faded
## out; independent of the objective-buff banner, which is a countdown readout
## rather than a one-shot event.
var _ultimate_banner: Label
const BANNER_HOLD := 2.0
const BANNER_FADE := 0.7

func _ready() -> void:
	_villain_hp_label = get_node(villain_hp_label_path)
	_villain_hp_bar = get_node(villain_hp_bar_path)
	_hero_panels_root = get_node(hero_panels_root_path)
	_objective_label = get_node(objective_label_path)
	_objective_bar = get_node(objective_bar_path)
	_objective_panel = get_node_or_null(objective_panel_path)
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
	_build_settings_button(back_btn)
	_emphasize_resource_panels()
	_build_duo_b_label()
	_build_duo_ultimate_bar()
	_build_ultimate_banner()

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

## ABANDON RUN + SETTINGS, both moved to the TOP-RIGHT corner (Designer,
## 2026-07-26). They used to sit top-left where they crowded the hero panels
## and the deploy band; the right edge below the villain panel is otherwise
## empty and reads as the "menu" corner.
##
## SETTINGS is built here rather than authored into battlefield.tscn so both
## buttons' layout lives in one place. Both anchor to the top-right and grow
## leftward, so neither depends on the design canvas width being 1920.
const MENU_BUTTON_WIDTH := 214.0
const MENU_BUTTON_HEIGHT := 56.0
const MENU_BUTTON_MARGIN := 16.0
## Clear of the villain HP panel, which occupies the top-right down to ~y90.
const MENU_BUTTON_TOP := 100.0

func _build_settings_button(back_btn: Button) -> void:
	_place_menu_button(back_btn, 0)
	var btn := UIStyle.button("SETTINGS", UIStyle.SIZE_SMALL, _on_settings_pressed)
	# Reachable during a level-up pick, which pauses the tree — same reason the
	# abandon button opts out of pausing.
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(btn)
	_place_menu_button(btn, 1)

## Pins a menu button to the top-right corner, `row` steps down from the top.
func _place_menu_button(btn: Control, row: int) -> void:
	btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btn.offset_right = -MENU_BUTTON_MARGIN
	btn.offset_left = btn.offset_right - MENU_BUTTON_WIDTH
	btn.offset_top = MENU_BUTTON_TOP + float(row) * (MENU_BUTTON_HEIGHT + 8.0)
	btn.offset_bottom = btn.offset_top + MENU_BUTTON_HEIGHT

func _on_settings_pressed() -> void:
	SettingsPanel.toggle(self)

## Escape opens/closes Settings mid-battle. SettingsPanel consumes Escape while
## it's up (so the key closes it rather than re-firing this), and ConfirmPanel
## does the same for the BACK TO MENU prompt.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_settings_pressed()

func _build_duo_ultimate_bar() -> void:
	_duo_ultimate_bar = DuoUltimateBar.new()
	add_child(_duo_ultimate_bar)
	_duo_ultimate_bar.build_cards()

## Re-derive the Ultimate cards AND the Duo hero-card groups from
## GameState.duo_pairings. Called by BattleManager once the start-of-level Duo
## reshuffle is confirmed — both are keyed by pair id, so both go stale when the
## pairing changes. Rebuilding the hero panels is safe here specifically because
## the reshuffle resolves before deploy: no Hero exists yet, so the panels hold
## nothing but the pre-deploy display they re-derive every frame anyway.
func rebuild_duo_ultimate_bar() -> void:
	if _duo_ultimate_bar != null:
		_duo_ultimate_bar.rebuild_cards()
	setup_heroes(_party_names)

func _build_ultimate_banner() -> void:
	_ultimate_banner = UIStyle.centered_label("", UIStyle.SIZE_HEADING, UIStyle.GOLD)
	_ultimate_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	# Below the second-Duo countdown chip at y 96 so the two never overlap.
	_ultimate_banner.position.y = 150.0
	_ultimate_banner.visible = false
	add_child(_ultimate_banner)

## One-shot "the Ultimate fired" flash: a scale pop, a hold, then a fade out.
## Called by BattleManager.activate_ultimate. `pair_id` is the "A|B" pair, shown
## so the player knows WHICH Duo just spent its Ultimate.
func show_ultimate_used(pair_id: String, ultimate_name: String) -> void:
	if _ultimate_banner == null:
		return
	_ultimate_banner.text = "%s\nULTIMATE — %s" % [
			pair_id.replace("|", " + "), ultimate_name]
	_ultimate_banner.visible = true
	_ultimate_banner.modulate.a = 1.0
	# The text just changed, so the label's size is a frame stale — resize now,
	# otherwise both the anchor centring and the pivot below use the old box.
	_ultimate_banner.reset_size()
	# Pivot at the label's own centre so the pop grows both ways, not rightward.
	_ultimate_banner.pivot_offset = _ultimate_banner.size * 0.5
	_ultimate_banner.scale = Vector2(0.7, 0.7)
	var tween := create_tween()
	tween.tween_property(_ultimate_banner, "scale", Vector2.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(BANNER_HOLD)
	tween.tween_property(_ultimate_banner, "modulate:a", 0.0, BANNER_FADE)
	tween.tween_callback(func() -> void: _ultimate_banner.visible = false)

func _build_duo_b_label() -> void:
	_duo_b_label = UIStyle.numeric_label("", UIStyle.SIZE_SUBHEAD, UIStyle.DUO_A, true)
	_duo_b_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_duo_b_label.position.y = 96.0
	_duo_b_label.visible = false
	add_child(_duo_b_label)

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
	_update_duo_b_countdown()
	_duo_ultimate_bar.refresh()
	_refresh_refocus_buttons()


func _update_duo_b_countdown() -> void:
	var bm := get_tree().get_first_node_in_group("battle_manager")
	var remaining: float = bm.duo_b_seconds_remaining() if bm != null else -1.0
	_duo_b_label.visible = remaining > 0.0
	if remaining > 0.0:
		UIStyle.set_numeric_text(_duo_b_label, "2ND DUO ARRIVES IN %ds" % int(ceil(remaining)))

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
## group holding both members' cards plus the single REFOCUS button they share
## (Designer, 2026-07-29). A hero in the party but not in any valid pairing still
## gets a plain ungrouped card, so a broken/absent pairing can never make a hero
## invisible on the HUD.
##
## Idempotent — clears whatever is there first, so it doubles as the rebuild path
## after the start-of-level Duo reshuffle (see rebuild_duo_ultimate_bar).
func setup_heroes(hero_names: PackedStringArray) -> void:
	_party_names = hero_names
	for child in _hero_panels_root.get_children():
		_hero_panels_root.remove_child(child)
		child.free()
	_hero_panels.clear()
	_refocus_buttons.clear()
	_refocus_spent_shown.clear()

	var grouped := {}
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
		_hero_panels_root.add_child(_build_duo_group(
				DuoUltimates.id_for_heroes(pair[0], pair[1]), members))
		for h in members:
			grouped[h] = true

	for hero_name in hero_names:
		if hero_name in grouped:
			continue
		_hero_panels_root.add_child(_build_hero_panel(hero_name))

## One Duo's shared card: a bordered group in that Duo's accent, holding both
## members' hero cards with the Duo's single REFOCUS button centered BETWEEN them
## — the position that reads as "this belongs to the pair" rather than to either
## hero (Designer, 2026-07-29).
##
## Its vertical cost is paid for elsewhere, because four hero cards plus two
## button rows overrun the 1080 canvas by ~46px as measured: the button carries
## tighter vertical padding than a standard compact button (REFOCUS_BUTTON_PAD_Y),
## the hero card's own margins were trimmed, and HeroPanelsRoot starts 10px
## higher. If any of those three drift back, the bottom card goes off screen.
func _build_duo_group(pair_id: String, members: PackedStringArray) -> PanelContainer:
	var group := PanelContainer.new()
	var accent: Color = UIStyle.DUO_A if _refocus_buttons.is_empty() else UIStyle.DUO_B
	group.add_theme_stylebox_override("panel",
			UIStyle.card(accent, DUO_GROUP_MARGIN, _refocus_buttons.size()))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	group.add_child(box)

	# Button between the two cards. With a member dead there is only one card, so
	# it lands under it — still inside the same Duo border either way.
	for i in members.size():
		box.add_child(_build_hero_panel(members[i]))
		if i == 0:
			box.add_child(_build_refocus_row(pair_id))
	if members.size() == 1:
		box.add_child(_build_refocus_row(pair_id))
	return group

## The centered REFOCUS button on its own row. Bound to the pair, not to a hero:
## either member's card can be missing (dead) and the surviving one still
## commands the Duo's refocus.
func _build_refocus_row(pair_id: String) -> CenterContainer:
	var center := CenterContainer.new()
	var button := UIStyle.compact_button("REFOCUS", UIStyle.SIZE_TINY,
			_on_refocus_pressed.bind(pair_id), _refocus_buttons.size())
	button.custom_minimum_size = Vector2(REFOCUS_BUTTON_WIDTH, 0)
	# Slimmer than UIStyle's compact metrics: this row is pure overhead in the
	# tightest vertical budget on screen. Every state stylebox has to be trimmed,
	# not just "normal", or the button would change height on hover.
	#
	# has_theme_stylebox_override is not optional: get_theme_stylebox falls back to
	# the project THEME's shared StyleBox when there is no override, and editing
	# that would silently re-pad every button in the game.
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		if not button.has_theme_stylebox_override(state):
			continue
		var sb := button.get_theme_stylebox(state)
		if sb is StyleBoxFlat:
			sb.content_margin_top = REFOCUS_BUTTON_PAD_Y
			sb.content_margin_bottom = REFOCUS_BUTTON_PAD_Y
	center.add_child(button)
	_refocus_buttons[pair_id] = button
	return center

func _build_hero_panel(hero_name: String) -> Control:
	var panel = hero_panel_scene.instantiate()
	panel.hero_name = hero_name
	panel.clicked.connect(_on_hero_panel_clicked)
	_hero_panels[hero_name] = panel
	return panel

func _on_refocus_pressed(pair_id: String) -> void:
	var ping := get_tree().get_first_node_in_group("focus_ping")
	if ping != null:
		ping.arm(pair_id)

## Four states on the shared REFOCUS button: "REFOCUS" (ready), "CLICK A SPOT"
## (armed, waiting on the battlefield click), a live countdown while the marker
## is on the field, and "REFOCUSED" once it has expired — at which point the
## button fades away like a spent Ultimate card. Disabled before the FocusPing
## exists at all (i.e. during deploy).
func _refresh_refocus_buttons() -> void:
	var ping := get_tree().get_first_node_in_group("focus_ping")
	for pair_id in _refocus_buttons:
		var button: Button = _refocus_buttons[pair_id]
		if ping == null:
			button.disabled = true
			continue
		var remaining: float = ping.seconds_remaining(pair_id)
		var used: bool = ping.is_used(pair_id)
		button.disabled = used
		if remaining > 0.0:
			button.text = "FOCUSED  %.1fs" % remaining
		elif used:
			button.text = "REFOCUSED"
			# Fades on EXPIRY, not on the click that spent it: the countdown is
			# live information the player is watching, so it has to stay readable
			# until the rally window actually closes.
			if not _refocus_spent_shown.get(pair_id, false):
				_refocus_spent_shown[pair_id] = true
				_play_refocus_spent(button)
		elif ping.is_armed(pair_id):
			button.text = "CLICK A SPOT"
		else:
			button.text = "REFOCUS"

## Pop-then-fade send-off for a spent refocus, the same gesture DuoUltimateBar
## gives a spent Ultimate card. Goes fully inert too: a disabled Button still
## emits mouse_entered, which would keep firing UIStyle's hover wiggle on an
## almost-invisible control.
func _play_refocus_spent(button: Button) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.pivot_offset = button.size * 0.5
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2(1.06, 1.06), REFOCUS_POP_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, REFOCUS_POP_TIME)
	tween.tween_property(button, "modulate:a", REFOCUS_SPENT_ALPHA, REFOCUS_FADE_TIME)

## Panel click: toggle the battle camera's follow lock onto that hero.
func _on_hero_panel_clicked(hero_name: String) -> void:
	var cam = get_tree().get_first_node_in_group("battle_camera")
	if cam == null:
		return
	for h in get_tree().get_nodes_in_group("heroes"):
		if h is Hero and h.hero_name == hero_name:
			cam.focus_on(h)
			return

func _update_villain_hp() -> void:
	if not is_instance_valid(_villain):
		_villain = null
		var villains = get_tree().get_nodes_in_group("villains")
		if not villains.is_empty():
			_villain = villains[0]
			_villain_seen = true

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
		elif bm != null and bm.has_method("is_hero_incoming") and bm.is_hero_incoming(hero_name):
			panel.set_incoming(bm.duo_b_seconds_remaining())
			panel.set_focused(false)
		else:
			panel.set_ko()
			panel.set_focused(false)
