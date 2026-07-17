extends Control

## Milestone 17: real-time clock — sim-minutes advance from accumulated real
## time instead of a fixed per-minute Timer resolving an abstract engine.
## First-pass placeholder: a full 90-minute match takes ~5 real minutes at
## 1x (90 * 3.3s), tunable via speed control below.
const SIM_SECONDS_PER_SIM_MINUTE := 3.3

@onready var header_label: Label = $MarginContainer/MainRow/Sidebar/HeaderLabel
@onready var score_label: Label = $MarginContainer/MainRow/Sidebar/ScoreLabel
@onready var minute_label: Label = $MarginContainer/MainRow/Sidebar/MinuteLabel
@onready var subs_label: Label = $MarginContainer/MainRow/Sidebar/SubsLabel
@onready var event_scroll: ScrollContainer = $MarginContainer/MainRow/MainArea/EventsPanel/EventScroll
@onready var event_list: VBoxContainer = $MarginContainer/MainRow/MainArea/EventsPanel/EventScroll/EventList
@onready var sub_panel: PanelContainer = $MarginContainer/MainRow/MainArea/SubPanel
@onready var queue_label: Label = $MarginContainer/MainRow/MainArea/SubPanel/SubVBox/QueueLabel
@onready var starter_pitch_container: VBoxContainer = $MarginContainer/MainRow/MainArea/SubPanel/SubVBox/StarterPitchContainer
@onready var bench_grid: GridContainer = $MarginContainer/MainRow/MainArea/SubPanel/SubVBox/BenchScroll/BenchGrid
@onready var confirm_sub_button: Button = $MarginContainer/MainRow/MainArea/SubPanel/SubVBox/SubButtonRow/ConfirmSubButton
@onready var cancel_sub_button: Button = $MarginContainer/MainRow/MainArea/SubPanel/SubVBox/SubButtonRow/CancelSubButton
@onready var pitch_view: Node2D = $MarginContainer/MainRow/MainArea/PitchPanel/PitchViewport/SubViewport/PitchPrototype
@onready var play_pause_button: Button = $MarginContainer/MainRow/Sidebar/ActionBox/PlayPauseButton
@onready var speed_1x_button: Button = $MarginContainer/MainRow/Sidebar/ActionBox/SpeedRow/Speed1xButton
@onready var speed_2x_button: Button = $MarginContainer/MainRow/Sidebar/ActionBox/SpeedRow/Speed2xButton
@onready var speed_4x_button: Button = $MarginContainer/MainRow/Sidebar/ActionBox/SpeedRow/Speed4xButton
@onready var substitute_button: Button = $MarginContainer/MainRow/Sidebar/ActionBox/SubstituteButton
@onready var change_formation_button: Button = $MarginContainer/MainRow/Sidebar/ActionBox/ChangeFormationButton
@onready var continue_button: Button = $MarginContainer/MainRow/Sidebar/ActionBox/ContinueButton

@onready var formation_panel: PanelContainer = $MarginContainer/MainRow/MainArea/FormationPanel
@onready var new_formation_option: OptionButton = $MarginContainer/MainRow/MainArea/FormationPanel/FormationVBox/NewFormationOption
@onready var formation_pitch_container: VBoxContainer = $MarginContainer/MainRow/MainArea/FormationPanel/FormationVBox/FormationPitchContainer
@onready var formation_pool: BenchDropArea = $MarginContainer/MainRow/MainArea/FormationPanel/FormationVBox/FormationPool
@onready var formation_pool_grid: HFlowContainer = $MarginContainer/MainRow/MainArea/FormationPanel/FormationVBox/FormationPool/FormationPoolGrid
@onready var auto_fill_formation_button: Button = $MarginContainer/MainRow/MainArea/FormationPanel/FormationVBox/FormationButtonRow/AutoFillFormationButton
@onready var confirm_formation_button: Button = $MarginContainer/MainRow/MainArea/FormationPanel/FormationVBox/FormationButtonRow/ConfirmFormationButton
@onready var cancel_formation_button: Button = $MarginContainer/MainRow/MainArea/FormationPanel/FormationVBox/FormationButtonRow/CancelFormationButton

var _match: LiveMatchState = null
var _formations: Array = []
var _pending_formation: Formation = null
var _pending_lineup: Array = []
var _was_playing_before_panel: bool = false
var _selected_outgoing_slot: int = -1
## Queued substitutions for this panel session, applied all at once on
## confirm. Each entry is {slot: int, incoming: Player}, numbered by queue
## order (index + 1) so the player can see which outgoing pairs with which
## incoming before committing.
var _pending_subs: Array = []

## Frame-by-frame simulation systems.
var _flow_engine: MatchFlowEngine = null
var _movement_system: PlayerMovementSystem = null
var _possession_system: PossessionSystem = null
## Milestone 17: real-time, position-driven decisions (replaces MatchEngine
## + PassSystem) — the single source of truth for shots/passes/tackles.
var _decision_engine: MatchDecisionEngine = null

## Goal celebration system.
var _celebration: GoalCelebrationSystem = null

## Track if we're at half-time waiting for player confirmation.
var _at_half_time_pause: bool = false

## Milestone 17: real-time clock state, replacing the fixed-tick Timer.
var _is_playing: bool = false
var _speed_multiplier: float = 1.0
var _minute_accumulator: float = 0.0

func _ready() -> void:
	var opponent: Dictionary = GameState.pending_opponent
	var home_name: String = GameState.club.club_name if GameState.club else "Home"
	_match = LiveMatchState.new(
		home_name, GameState.formation, GameState.lineup, GameState.get_bench(),
		opponent.name, opponent.formation, opponent.lineup
	)
	header_label.text = "%s vs %s" % [_match.home_name, _match.away_name]

	pitch_view.configure(_match.home_formation, _match.home_lineup, _match.away_formation, _match.away_lineup)
	_match.goal_scored.connect(_on_goal_scored)
	_match.shot_attempt.connect(_on_shot_attempt)
	_match.substitution_made.connect(_on_substitution_made)
	_match.formation_changed.connect(_on_formation_changed)

	## Initialize frame-by-frame simulation systems.
	_flow_engine = MatchFlowEngine.new()
	_movement_system = PlayerMovementSystem.new(_match.home_formation, _match.home_lineup, _match.away_formation, _match.away_lineup, _match.ball_state, pitch_view.get_grass_rect())
	_possession_system = PossessionSystem.new(_match.ball_state, _match, _movement_system)
	_decision_engine = MatchDecisionEngine.new(_match.ball_state, _match, _movement_system, _possession_system, pitch_view.get_grass_rect())
	_flow_engine.half_time_reached.connect(_on_half_time_reached)
	_decision_engine.shot_taken.connect(_on_shot_taken)
	_decision_engine.pass_started.connect(_on_pass_started)
	_match.substitution_made.connect(_on_substitution_made_movement)
	_match.formation_changed.connect(_on_formation_changed_movement)

	play_pause_button.pressed.connect(_on_play_pause_pressed)
	speed_1x_button.pressed.connect(_on_speed_1x_pressed)
	speed_2x_button.pressed.connect(_on_speed_2x_pressed)
	speed_4x_button.pressed.connect(_on_speed_4x_pressed)
	substitute_button.pressed.connect(_on_substitute_pressed)
	confirm_sub_button.pressed.connect(_on_confirm_sub_pressed)
	cancel_sub_button.pressed.connect(_on_cancel_sub_pressed)
	change_formation_button.pressed.connect(_on_change_formation_pressed)
	new_formation_option.item_selected.connect(_on_new_formation_selected)
	formation_pool.player_returned.connect(_on_formation_slot_returned)
	auto_fill_formation_button.pressed.connect(_on_auto_fill_formation_pressed)
	confirm_formation_button.pressed.connect(_on_confirm_formation_pressed)
	cancel_formation_button.pressed.connect(_on_cancel_formation_pressed)
	continue_button.pressed.connect(_on_continue_pressed)

	_formations = FormationLibrary.get_all()
	sub_panel.hide()
	formation_panel.hide()
	continue_button.hide()

	## Kickoff: home side takes it, per football convention (no MatchEngine
	## "who's favored" roll to defer to anymore) — nearest home outfield
	## player to the center circle takes it, same logic as a post-goal restart.
	_kickoff(true)

	_refresh()
	_is_playing = true

## Half-time pause — wait for player to continue.
func _on_half_time_reached() -> void:
	_at_half_time_pause = true
	_is_playing = false
	play_pause_button.text = "Play"
	var event_text = "Half Time"
	event_list.add_child(Label.new())
	event_list.get_child(-1).text = event_text


## MatchDecisionEngine resolved a shot — record it (score/events) via
## LiveMatchState, which re-emits goal_scored/shot_attempt for the existing
## pitch-view/celebration wiring below.
func _on_shot_taken(is_home: bool, shooter: Player, outcome: String) -> void:
	_match.record_shot_result(is_home, shooter, outcome)


## MatchDecisionEngine started a pass — animate the passer's strike; the
## ball's own flight is already driven every frame by BallState.
func _on_pass_started(is_home: bool, passer: Player, receiver: Player, start_pos: Vector2, end_pos: Vector2, duration: float) -> void:
	pitch_view.animate_pass(is_home, passer, receiver, start_pos, end_pos, duration)


## Update movement system on substitution.
func _on_substitution_made_movement(slot_index: int, incoming: Player, _outgoing: Player) -> void:
	_movement_system.on_substitution(true, slot_index, incoming)


## Milestone 14: Update movement system on formation change.
func _on_formation_changed_movement() -> void:
	_movement_system.on_formation_changed(true, _match.home_formation, _match.home_lineup)


func _on_goal_scored(is_home: bool, scorer: Player) -> void:
	pitch_view.play_kick(is_home, scorer)
	_start_goal_celebration(is_home, scorer)

## Goals are already fully handled by _on_goal_scored above (goal_scored
## fires alongside shot_attempt on a GOAL) — only animate here for
## near-misses, so a scored shot doesn't get double-animated.
func _on_shot_attempt(is_home: bool, shooter: Player, outcome: String) -> void:
	if outcome != "GOAL":
		pitch_view.play_shot_attempt(is_home, shooter)

func _on_substitution_made(slot_index: int, incoming: Player, _outgoing: Player) -> void:
	pitch_view.update_lineup(slot_index, incoming)

func _on_formation_changed() -> void:
	pitch_view.update_formation(_match.home_formation, _match.home_lineup)

## Start a goal celebration sequence. Simulation keeps running underneath —
## per Designer's call, a goal shouldn't halt the match, just show a brief
## celebration overlay before the conceding side kicks back off.
func _start_goal_celebration(is_home: bool, scorer: Player) -> void:
	if _celebration != null and _celebration.is_active():
		return  # Already celebrating
	_celebration = GoalCelebrationSystem.new(is_home, scorer)
	_movement_system.start_celebration(is_home, _match.ball_state.position)

## Celebration finished: snap both sides back to formation shape and hand
## the ball to the conceding side at center circle — a real kickoff restart.
func _end_goal_celebration() -> void:
	var scoring_is_home: bool = _celebration.is_home
	_celebration = null
	_movement_system.stop_celebration()
	_movement_system.reset_to_formation()
	_kickoff(not scoring_is_home)

## Places the ball at center circle and hands it to the nearest outfield
## player on the given side — used both for the match's opening kickoff and
## every restart after a goal.
func _kickoff(is_home: bool) -> void:
	var center: Vector2 = pitch_view.get_grass_rect().get_center()
	_match.ball_state.position = center
	_match.ball_state.velocity = Vector2.ZERO
	_match.ball_state.set_in_air(false)

	var kickoff_player: Player = _find_kickoff_taker(is_home, center)
	if kickoff_player != null:
		_match.ball_state.set_possession(is_home, kickoff_player)
	else:
		_match.ball_state.loose_ball()

## Nearest fielded outfield player on the given side to the center circle —
## a simple stand-in for "who takes the kickoff".
func _find_kickoff_taker(is_home: bool, center: Vector2) -> Player:
	var formation: Formation = _match.home_formation if is_home else _match.away_formation
	var lineup: Array = _match.home_lineup if is_home else _match.away_lineup
	var best_dist: float = INF
	var best_player: Player = null
	for i in lineup.size():
		var player: Player = lineup[i]
		if player == null or formation.slots[i] == Formation.SlotCategory.GK:
			continue
		var dist: float = _movement_system.get_player_position(is_home, i).distance_to(center)
		if dist < best_dist:
			best_dist = dist
			best_player = player
	return best_player

## Advance one simulated minute — condition decay, half-time/full-time
## checks. Score/events themselves come from MatchDecisionEngine's real-time
## shot events (_on_shot_taken above), not from this per-minute tick.
func _advance_one_minute() -> void:
	if _flow_engine.advance_minute():
		_match.advance_minute()
	else:
		_match.finished = true

	_refresh()

	if _match.finished:
		_is_playing = false
		play_pause_button.disabled = true
		substitute_button.disabled = true
		change_formation_button.disabled = true
		continue_button.show()


## Frame-by-frame update: drives player movement, ball physics, and match
## decisions every frame (scaled by the selected speed multiplier), plus a
## real-time clock that advances one simulated minute every
## SIM_SECONDS_PER_SIM_MINUTE of (speed-scaled) elapsed time. Celebration is
## a real-time overlay independent of the clock, so it keeps advancing even
## while play itself continues underneath.
func _process(delta: float) -> void:
	if _match == null or _match.finished or _at_half_time_pause or not _is_playing:
		return

	var scaled_delta: float = delta * _speed_multiplier

	if _celebration != null and _celebration.is_active():
		if not _celebration.update(scaled_delta):
			_end_goal_celebration()

	_decision_engine.update(scaled_delta)
	_possession_system.update(scaled_delta)
	_movement_system.update(scaled_delta)
	pitch_view.update_player_positions(_movement_system)
	pitch_view.update_ball_state(_match.ball_state)

	_minute_accumulator += scaled_delta
	while _minute_accumulator >= SIM_SECONDS_PER_SIM_MINUTE and _is_playing and not _at_half_time_pause:
		_minute_accumulator -= SIM_SECONDS_PER_SIM_MINUTE
		_advance_one_minute()

func _on_play_pause_pressed() -> void:
	## Handle half-time resume.
	if _at_half_time_pause:
		_at_half_time_pause = false
		_flow_engine.resume_from_half_time()
		## Second half: teams switch sides — home now attacks whichever end
		## it didn't attack in the first half.
		var home_attacks_right: bool = _flow_engine.is_first_half
		_movement_system.on_half_time_side_switch(home_attacks_right)
		pitch_view.set_attacking_sides(home_attacks_right)
		## Whichever side didn't take the first-half kickoff takes this one.
		_kickoff(false)
		_is_playing = true
		play_pause_button.text = "Pause"
		return

	_is_playing = not _is_playing
	play_pause_button.text = "Pause" if _is_playing else "Play"

func _on_speed_1x_pressed() -> void:
	_set_speed(1.0)

func _on_speed_2x_pressed() -> void:
	_set_speed(2.0)

func _on_speed_4x_pressed() -> void:
	_set_speed(4.0)

func _set_speed(multiplier: float) -> void:
	_speed_multiplier = multiplier
	speed_1x_button.button_pressed = is_equal_approx(multiplier, 1.0)
	speed_2x_button.button_pressed = is_equal_approx(multiplier, 2.0)
	speed_4x_button.button_pressed = is_equal_approx(multiplier, 4.0)

func _on_substitute_pressed() -> void:
	formation_panel.hide()
	_is_playing = false
	play_pause_button.text = "Play"
	_selected_outgoing_slot = -1
	_pending_subs = []
	_rebuild_sub_panel()
	sub_panel.show()

func _pending_index_for_slot(slot_index: int) -> int:
	for i in _pending_subs.size():
		if _pending_subs[i]["slot"] == slot_index:
			return i
	return -1

func _pending_index_for_incoming(player: Player) -> int:
	for i in _pending_subs.size():
		if _pending_subs[i]["incoming"] == player:
			return i
	return -1

func _pending_slots_remaining() -> int:
	return LiveMatchState.MAX_SUBS - _match.subs_used - _pending_subs.size()

## Pitch-slot layout mirroring Pre-Match Setup: click a starter slot to pick
## who comes off (shows live in-match Condition + position compat), then
## click a bench card to pick who comes on (shows their compat for that
## same slot's category and persistent fatigue). Multiple pairs can be
## queued — each is numbered in queue order — and clicking an already-queued
## player again removes it. Nothing is applied to the match until Confirm.
func _rebuild_sub_panel() -> void:
	for child in starter_pitch_container.get_children():
		child.queue_free()
	var current_row: HBoxContainer = null
	var current_category = null
	for i in _match.home_lineup.size():
		var player: Player = _match.home_lineup[i]
		if player == null:
			continue
		var category: Formation.SlotCategory = _match.home_formation.slots[i]
		if current_row == null or category != current_category:
			current_row = HBoxContainer.new()
			current_row.add_theme_constant_override("separation", 12)
			starter_pitch_container.add_child(current_row)
			current_category = category
		var slot := LineupSlot.new()
		current_row.add_child(slot)
		slot.select_mode = true
		slot.set_slot(i, category)
		slot.set_player(player)
		slot.set_condition_override(_match.get_condition(player))
		slot.set_selected(i == _selected_outgoing_slot)
		slot.set_queue_number(_pending_index_for_slot(i) + 1)
		slot.slot_selected.connect(_on_starter_slot_selected)

	for child in bench_grid.get_children():
		child.queue_free()
	var target_category = _match.home_formation.slots[_selected_outgoing_slot] if _selected_outgoing_slot != -1 else null
	for player in _match.home_bench:
		var chip := PlayerChip.new()
		chip.player = player
		chip.select_mode = true
		chip.condition_override = _match.get_condition(player)
		chip.compat_category = target_category
		chip.queue_number = _pending_index_for_incoming(player) + 1
		chip.chip_selected.connect(_on_bench_chip_selected)
		bench_grid.add_child(chip)

	confirm_sub_button.disabled = _pending_subs.is_empty()
	queue_label.text = "Queued: %d (%d remaining)" % [_pending_subs.size(), _pending_slots_remaining()]

func _on_starter_slot_selected(slot_index: int) -> void:
	var pending_index: int = _pending_index_for_slot(slot_index)
	if pending_index != -1:
		_pending_subs.remove_at(pending_index)
		_selected_outgoing_slot = -1
	elif _pending_slots_remaining() > 0:
		_selected_outgoing_slot = slot_index
	_rebuild_sub_panel()

func _on_bench_chip_selected(player: Player) -> void:
	var pending_index: int = _pending_index_for_incoming(player)
	if pending_index != -1:
		_pending_subs.remove_at(pending_index)
		_rebuild_sub_panel()
		return
	if _selected_outgoing_slot == -1 or _pending_slots_remaining() <= 0:
		return
	_pending_subs.append({"slot": _selected_outgoing_slot, "incoming": player})
	_selected_outgoing_slot = -1
	_rebuild_sub_panel()

func _on_confirm_sub_pressed() -> void:
	if _pending_subs.is_empty():
		return
	for sub in _pending_subs:
		_match.substitute(sub["slot"], sub["incoming"])
	_pending_subs = []
	_selected_outgoing_slot = -1
	sub_panel.hide()
	_refresh()

func _on_cancel_sub_pressed() -> void:
	_pending_subs = []
	_selected_outgoing_slot = -1
	sub_panel.hide()

## Reassigns the current 11 starters into a different formation's slots.
## Only the players already on the pitch can be placed here — bench players
## are not selectable, so this cannot be used to bypass the sub cap.
func _on_change_formation_pressed() -> void:
	sub_panel.hide()
	_was_playing_before_panel = _is_playing
	_is_playing = false
	play_pause_button.text = "Play"
	new_formation_option.clear()
	var current_index: int = -1
	for i in _formations.size():
		new_formation_option.add_item(_formations[i].formation_name)
		if _formations[i] == _match.home_formation:
			current_index = i
	new_formation_option.select(max(current_index, 0))
	_pending_formation = _formations[max(current_index, 0)]
	_pending_lineup = _match.home_lineup.duplicate()
	_rebuild_formation_panel()
	formation_panel.show()

func _on_new_formation_selected(index: int) -> void:
	_pending_formation = _formations[index]
	_pending_lineup = []
	for i in _pending_formation.slots.size():
		_pending_lineup.append(null)
	_rebuild_formation_panel()

func _on_formation_slot_dropped(slot_index: int, player: Player) -> void:
	var previous_index: int = _pending_lineup.find(player)
	if previous_index != -1:
		_pending_lineup[previous_index] = null
	_pending_lineup[slot_index] = player
	_rebuild_formation_panel()

func _on_formation_slot_returned(source_slot: int) -> void:
	_pending_lineup[source_slot] = null
	_rebuild_formation_panel()

## Fills only currently-empty slots with the best remaining unplaced starters
## (greedy, mirroring Pre-Match Setup's auto-fill). Only players already on
## the pitch are eligible — bench players are never placed here.
func _on_auto_fill_formation_pressed() -> void:
	var empty_slots: Array = []
	for i in _pending_lineup.size():
		if _pending_lineup[i] == null:
			empty_slots.append(i)
	if empty_slots.is_empty():
		return
	var available: Array = []
	for player in _match.home_lineup:
		if player != null and not _pending_lineup.has(player):
			available.append(player)
	while not empty_slots.is_empty() and not available.is_empty():
		var best_score: float = -1.0
		var best_slot: int = -1
		var best_player: Player = null
		for slot_index in empty_slots:
			var category: Formation.SlotCategory = _pending_formation.slots[slot_index]
			for player in available:
				var score: float = player.get_overall() * PositionCompatibility.get_best_multiplier(player, category)
				if score > best_score:
					best_score = score
					best_slot = slot_index
					best_player = player
		if best_player == null or best_score <= 0.0:
			break
		_pending_lineup[best_slot] = best_player
		empty_slots.erase(best_slot)
		available.erase(best_player)
	_rebuild_formation_panel()

func _rebuild_formation_panel() -> void:
	for child in formation_pitch_container.get_children():
		child.queue_free()
	var current_row: HBoxContainer = null
	var current_category = null
	for i in _pending_formation.slots.size():
		var category = _pending_formation.slots[i]
		if current_row == null or category != current_category:
			current_row = HBoxContainer.new()
			current_row.add_theme_constant_override("separation", 12)
			formation_pitch_container.add_child(current_row)
			current_category = category
		var slot := LineupSlot.new()
		current_row.add_child(slot)
		slot.set_slot(i, category)
		if i < _pending_lineup.size():
			slot.set_player(_pending_lineup[i])
		slot.player_dropped.connect(_on_formation_slot_dropped)

	for child in formation_pool_grid.get_children():
		child.queue_free()
	for player in _match.home_lineup:
		if player != null and not _pending_lineup.has(player):
			var chip := PlayerChip.new()
			chip.player = player
			chip.player_returned.connect(_on_formation_slot_returned)
			formation_pool_grid.add_child(chip)

	var all_filled: bool = not _pending_lineup.has(null)
	confirm_formation_button.disabled = not all_filled

func _on_confirm_formation_pressed() -> void:
	if _pending_lineup.has(null):
		return
	_match.change_formation(_pending_formation, _pending_lineup)
	formation_panel.hide()
	if _was_playing_before_panel and not _match.finished:
		_is_playing = true
		play_pause_button.text = "Pause"
	_refresh()

func _on_cancel_formation_pressed() -> void:
	formation_panel.hide()
	if _was_playing_before_panel and not _match.finished:
		_is_playing = true
		play_pause_button.text = "Pause"

func _refresh() -> void:
	score_label.text = "%d - %d" % [_match.home_score, _match.away_score]
	## Milestone 14: Use flow engine for minute display (handles HT, injury time).
	var display_min: String = _flow_engine.get_display_minute()
	minute_label.text = "Minute %s / %d'" % [display_min, LiveMatchState.MATCH_MINUTES]
	subs_label.text = "Subs used: %d/%d" % [_match.subs_used, LiveMatchState.MAX_SUBS]
	substitute_button.disabled = not _match.can_substitute()
	_rebuild_events()

func _rebuild_events() -> void:
	for child in event_list.get_children():
		child.queue_free()
	for event_text in _match.events:
		var label := Label.new()
		label.text = event_text
		event_list.add_child(label)
	await get_tree().process_frame
	event_scroll.scroll_vertical = int(event_scroll.get_v_scroll_bar().max_value)

func _on_continue_pressed() -> void:
	var result := MatchResult.new()
	result.home_name = _match.home_name
	result.away_name = _match.away_name
	result.home_score = _match.home_score
	result.away_score = _match.away_score
	GameState.last_match_result = result
	GameState.finish_match(_match)
	get_tree().change_scene_to_file("res://scenes/match_result/match_result.tscn")
