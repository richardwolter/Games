class_name TeamMatchState
extends Resource

## Per-team hidden state that evolves during a match.
## Drives momentum, pressure, and chance generation.

## Core match state
var possession_pct: float = 50.0  # 0-100, influenced by successful passes and territory
var territory_pct: float = 50.0  # 0-100, spatial dominance (position of ball + player concentration)
var momentum: float = 0.0  # -100 to +100, emotional/confidence swing driven by recent events

## Team characteristics (persist for the match, modified by tactical style)
var confidence: float = 50.0  # 0-100, how likely team is to take risks; affected by momentum
var organization: float = 50.0  # 0-100, defensive compactness; high press reduces this
var physical_energy: float = 100.0  # 0-100, stamina pool; drains with high-intensity play
var aggression: float = 50.0  # 0-100, likelihood of fouls/cards; modified by tactical style and momentum

## Calculated pressure (updated each periodic update by PressureSystem)
var pressure_level: float = 50.0  # 0-100, drives chance generation

## Tactical identity (set at match start or changed mid-match)
## Default must be one of TacticalSystem's 5 recognized styles below, or
## apply_modifiers() silently no-ops and the team gets zero tactical effect.
var tactical_style: String = "Possession"  # One of: "High Press", "Possession", "Counter Attack", "Park The Bus", "Long Ball"

## Recent event history (for momentum calculation and combo bonuses)
var recent_events: Array[String] = []  # Event type strings, added newest-first, pruned over time
var pass_chain_length: int = 0  # Current consecutive passes, resets on turnover/interception
var possession_time_seconds: float = 0.0  # Cumulative time this team has held the ball in the match

## Getters for easy access
func get_momentum_normalized() -> float:
	return clamp(momentum / 100.0, -1.0, 1.0)

func get_pressure() -> float:
	## Pressure combines momentum, possession, territory, and tactical style.
	## High confidence + positive momentum + possession dominance = high pressure.
	var pressure = (momentum + 100.0) * 0.25  # Momentum contributes -25 to +25
	pressure += (possession_pct / 100.0) * 25.0  # Possession contributes 0-25
	pressure += (territory_pct / 100.0) * 20.0  # Territory contributes 0-20
	return clamp(pressure, 0.0, 100.0)

func add_event(event_type: String) -> void:
	recent_events.push_front(event_type)
	# Keep only the most recent 10 events for memory efficiency
	if recent_events.size() > 10:
		recent_events.pop_back()

func add_possession_time(delta_seconds: float) -> void:
	## Called when this team has the ball during an update.
	possession_time_seconds += delta_seconds

func update_possession_pct(home_possession_time: float, away_possession_time: float) -> void:
	## Recalculate possession_pct based on total possession time.
	## This is called from LiveMatchState.update_team_states().
	var total_time = home_possession_time + away_possession_time
	if total_time > 0:
		possession_pct = (possession_time_seconds / total_time) * 100.0
	else:
		possession_pct = 50.0
