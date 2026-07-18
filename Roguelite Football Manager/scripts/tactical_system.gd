class_name TacticalSystem
extends RefCounted

## Converts tactical style + team stats into modifiers on subsystems.
## Each style changes how momentum builds, how pressure accumulates, how chances are generated.
## See BALANCE.md for the full modifier table.

## Tactical style constants
const STYLE_HIGH_PRESS = "High Press"
const STYLE_POSSESSION = "Possession"
const STYLE_COUNTER_ATTACK = "Counter Attack"
const STYLE_PARK_THE_BUS = "Park The Bus"
const STYLE_LONG_BALL = "Long Ball"

## Returns all available tactical styles
static func get_all_styles() -> Array[String]:
	return [
		STYLE_HIGH_PRESS,
		STYLE_POSSESSION,
		STYLE_COUNTER_ATTACK,
		STYLE_PARK_THE_BUS,
		STYLE_LONG_BALL
	]

## Applies tactical modifiers to a team's state.
## Called from LiveMatchState.update_team_states() each periodic update.
func apply_modifiers(team_state: TeamMatchState, home_formation: Formation, away_formation: Formation, is_home: bool) -> void:
	if team_state == null:
		return

	var style = team_state.tactical_style
	var modifier_set = _get_modifiers(style)

	## Apply organization modifier (tactical shape compactness)
	team_state.organization = clamp(team_state.organization * modifier_set.organization_multiplier, 20.0, 85.0)

	## Apply aggression modifier (likelihood of fouls/intensity)
	team_state.aggression = clamp(team_state.aggression * modifier_set.aggression_multiplier, 20.0, 80.0)

	## Apply pressure buildup rate (indirectly via confidence modifier)
	## High confidence → more confident play → builds pressure faster
	team_state.confidence = clamp(team_state.confidence * modifier_set.confidence_multiplier, 20.0, 80.0)

	## Physical energy drain modifier (some styles exhaust faster)
	## Applied during update_physical_energy() in MomentumSystem


## Returns a modifier set for the given tactical style.
func _get_modifiers(style: String) -> Dictionary:
	match style:
		STYLE_HIGH_PRESS:
			return {
				name = "High Press",
				organization_multiplier = 0.8,  # Stretched thin while pressing
				aggression_multiplier = 1.3,  # More aggressive play
				confidence_multiplier = 1.15,  # Confident in the press
				possession_multiplier = 0.85,  # Sacrifices possession for pressure
				pass_completion_multiplier = 0.9,  # Riskier passes (more interceptions)
				interception_multiplier = 1.4,  # Much better at cutting out passes
				tackle_multiplier = 1.3,  # More tackles attempted
				shot_chance_multiplier = 0.95,  # Fewer direct shots (transition-focused)
				fatigue_multiplier = 1.25,  # Exhausting style
			}

		STYLE_POSSESSION:
			return {
				name = "Possession",
				organization_multiplier = 1.1,  # Well-organized shape
				aggression_multiplier = 0.85,  # Controlled, less aggressive
				confidence_multiplier = 1.2,  # High confidence in possession
				possession_multiplier = 1.35,  # Dominates possession
				pass_completion_multiplier = 1.2,  # Safer, more accurate passes
				interception_multiplier = 0.85,  # Defensive risk of possession
				tackle_multiplier = 0.9,  # Fewer tackles (defending less)
				shot_chance_multiplier = 0.8,  # Patient buildup, fewer shots
				fatigue_multiplier = 0.9,  # Controlled pace
			}

		STYLE_COUNTER_ATTACK:
			return {
				name = "Counter Attack",
				organization_multiplier = 1.0,  # Balanced defense
				aggression_multiplier = 1.0,  # Normal intensity
				confidence_multiplier = 1.05,  # Confident in transitions
				possession_multiplier = 0.7,  # Low possession (cedes ball)
				pass_completion_multiplier = 0.95,  # Riskier direct passes
				interception_multiplier = 1.15,  # Good at winning the ball back
				tackle_multiplier = 1.1,  # Aggressive defense
				shot_chance_multiplier = 1.2,  # High-quality chances on transition
				fatigue_multiplier = 1.1,  # Explosive bursts tire players
			}

		STYLE_PARK_THE_BUS:
			return {
				name = "Park The Bus",
				organization_multiplier = 1.3,  # Extremely compact defense
				aggression_multiplier = 0.7,  # Disciplined, fewer fouls
				confidence_multiplier = 0.9,  # Defensive mindset
				possession_multiplier = 0.6,  # Cedes possession entirely
				pass_completion_multiplier = 1.1,  # Safe, backward passes
				interception_multiplier = 1.5,  # Many defensive players
				tackle_multiplier = 1.4,  # Constant defensive challenges
				shot_chance_multiplier = 0.5,  # Very few attacking chances
				fatigue_multiplier = 0.8,  # Defensive shape, less running
			}

		STYLE_LONG_BALL:
			return {
				name = "Long Ball",
				organization_multiplier = 0.95,  # Slightly chaotic
				aggression_multiplier = 1.1,  # Direct, aggressive style
				confidence_multiplier = 1.0,  # Normal confidence
				possession_multiplier = 0.75,  # Lower possession (direct play)
				pass_completion_multiplier = 0.75,  # Risky long balls
				interception_multiplier = 1.1,  # Opponents intercept more long passes
				tackle_multiplier = 1.05,  # Normal tackles
				shot_chance_multiplier = 0.9,  # Fewer direct shots, more second balls
				fatigue_multiplier = 1.05,  # Direct play has bursts
				header_multiplier = 1.5,  # Many aerial duels
			}

		_:
			# Default to balanced modifiers if style unknown
			return {
				name = "Standard",
				organization_multiplier = 1.0,
				aggression_multiplier = 1.0,
				confidence_multiplier = 1.0,
				possession_multiplier = 1.0,
				pass_completion_multiplier = 1.0,
				interception_multiplier = 1.0,
				tackle_multiplier = 1.0,
				shot_chance_multiplier = 1.0,
				fatigue_multiplier = 1.0,
			}

## Gets a descriptor string for a tactical style
static func get_style_description(style: String) -> String:
	match style:
		"High Press":
			return "Aggressive pressing throughout the pitch. High risk, high reward."
		"Possession":
			return "Dominate via ball control and patient buildup. Safe but slower."
		"Counter Attack":
			return "Defend deep, attack on transition. Efficient but rare chances."
		"Park The Bus":
			return "Compact defense, frustrate opponents. Very defensive."
		"Long Ball":
			return "Direct play bypassing midfield. Chaotic but dangerous on second balls."
		_:
			return "Unknown tactical style."
