class_name MomentumSystem
extends RefCounted

## Calculates and applies momentum changes based on match events.
## Momentum represents confidence/emotional state and drives pressure.

## Base momentum decay every periodic update (every 2-5s)
const BASE_MOMENTUM_DECAY := 2.5  # Momentum decays by this amount per update (prevents permanent dominance)

## Event bonuses/penalties
const EVENT_BONUS_GOAL_SCORED := 35.0  # Large swing on scoring
const EVENT_PENALTY_GOAL_CONCEDED := -30.0  # Smaller swing on conceding (defending team is more resilient)
const EVENT_BONUS_SAVE := 8.0
const EVENT_BONUS_TACKLE := 4.0
const EVENT_BONUS_INTERCEPTION := 5.0
const EVENT_BONUS_PASS_CHAIN := 1.5  # Per consecutive pass in a chain
const EVENT_PENALTY_MISPLACED_PASS := -2.0
const EVENT_PENALTY_TURNOVER := -8.0
const EVENT_PENALTY_YELLOW_CARD := -5.0
const EVENT_PENALTY_RED_CARD := -20.0
const EVENT_PENALTY_INJURY_OWN_PLAYER := -10.0

## When momentum swings this much in one update, trigger a confidence shift
const CONFIDENCE_SWING_THRESHOLD := 25.0

func apply_decay(team_state: TeamMatchState) -> void:
	## Natural momentum decay every update — prevents one team from dominating permanently.
	team_state.momentum = move_toward(team_state.momentum, 0.0, BASE_MOMENTUM_DECAY)

func apply_event(team_state: TeamMatchState, event_type: String, magnitude_override: float = 0.0) -> float:
	## Apply a momentum change from an event. Returns the actual momentum change applied.
	## magnitude_override allows custom scaling for special events.

	var change = 0.0

	match event_type:
		"goal_scored":
			change = EVENT_BONUS_GOAL_SCORED
		"goal_conceded":
			change = EVENT_PENALTY_GOAL_CONCEDED
		"save":
			change = EVENT_BONUS_SAVE
		"tackle":
			change = EVENT_BONUS_TACKLE
		"interception":
			change = EVENT_BONUS_INTERCEPTION
		"pass_chain":
			change = EVENT_BONUS_PASS_CHAIN
		"misplaced_pass":
			change = EVENT_PENALTY_MISPLACED_PASS
		"turnover":
			change = EVENT_PENALTY_TURNOVER
		"yellow_card":
			change = EVENT_PENALTY_YELLOW_CARD
		"red_card":
			change = EVENT_PENALTY_RED_CARD
		"injury_own_player":
			change = EVENT_PENALTY_INJURY_OWN_PLAYER

	if magnitude_override != 0.0:
		change = magnitude_override

	team_state.momentum = clamp(team_state.momentum + change, -100.0, 100.0)
	team_state.add_event(event_type)

	return change

func apply_pass_chain_bonus(team_state: TeamMatchState) -> void:
	## Award momentum for every consecutive pass. Called when a pass completes.
	team_state.pass_chain_length += 1
	var chain_bonus = EVENT_BONUS_PASS_CHAIN * team_state.pass_chain_length
	team_state.momentum = clamp(team_state.momentum + chain_bonus, -100.0, 100.0)
	team_state.add_event("pass_chain")

func reset_pass_chain(team_state: TeamMatchState) -> void:
	## Called when possession is lost (turnover, interception, etc).
	team_state.pass_chain_length = 0

func update_confidence(team_state: TeamMatchState) -> void:
	## Confidence tracks momentum and drifts toward it over time.
	## A team with positive momentum becomes more confident, more likely to take risks.

	var momentum_norm = team_state.get_momentum_normalized()  # -1 to +1
	var target_confidence = 50.0 + (momentum_norm * 30.0)  # Ranges 20-80 based on momentum

	# Confidence drifts toward target but doesn't snap immediately
	team_state.confidence = move_toward(team_state.confidence, target_confidence, 2.0)

func update_organization(team_state: TeamMatchState) -> void:
	## Organization represents defensive cohesion.
	## Positive momentum = more organized defense; negative = breakdown risk.
	## Also affected by recent concessions and tactical style.

	var momentum_factor = (team_state.momentum + 100.0) * 0.15  # -100 to +100 → 0 to 30
	var base_organization = 50.0 + momentum_factor

	# Recent defensive mistakes reduce organization
	if "goal_conceded" in team_state.recent_events:
		base_organization -= 10.0

	team_state.organization = clamp(base_organization, 20.0, 85.0)

func update_physical_energy(team_state: TeamMatchState, delta_seconds: float, time_elapsed_seconds: float) -> void:
	## Physical energy drains with time and high-intensity play.
	## Drains faster with high aggression and press intensity.
	## Recovers slightly during less intense periods.

	var match_progress_ratio = clamp(time_elapsed_seconds / (90.0 * 60.0), 0.0, 1.0)
	var base_drain = 0.3 * match_progress_ratio * (delta_seconds / 60.0)  # Drains more as match progresses

	# Aggression increases drain
	if team_state.aggression > 60.0:
		base_drain *= 1.3

	team_state.physical_energy = clamp(team_state.physical_energy - base_drain, 0.0, 100.0)
