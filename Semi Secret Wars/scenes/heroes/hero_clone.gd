class_name HeroClone
extends Combatant
## Artemis's Clone ability: a temporary stand-in spawned at cast time with
## the caster's own stats, copied in by Hero._try_clone before add_child().
## Taunts nearby minions (Combatant.is_taunting) and fights back, then
## expires after life_span regardless of how much damage it's taken.

@export var life_span := 2.0

## Artemis herself; the clone tags along beside her (see follow_offset)
## instead of standing still, so it reads as sticking with the party.
var caster: Combatant = null
var follow_offset := Vector2.ZERO

## Copies its caster's role (set by Hero._try_clone) so it has the same shape
## as a real party member (e.g. ROLE_COLORS lookups) instead of erroring as a
## missing property.
var role := "TANK"

## How often (seconds) the follow-goal is refreshed, matching the pattern
## used for the hero->villain push-goal: goal is a one-shot snapshot, so a
## moving target needs periodic re-set_goal, not just a live position.
const FOLLOW_TRACK_INTERVAL := 0.3
var _follow_track_cd := 0.0

func _configure() -> void:
	self_group = "heroes"
	enemy_group = "hostiles"

func _process(delta: float) -> void:
	super(delta)
	if _dying:
		return
	life_span -= delta
	if life_span <= 0.0:
		_die()
		return
	if caster != null and is_instance_valid(caster):
		_follow_track_cd -= delta
		if _follow_track_cd <= 0.0:
			_follow_track_cd = FOLLOW_TRACK_INTERVAL
			set_goal(caster.global_position + follow_offset)
