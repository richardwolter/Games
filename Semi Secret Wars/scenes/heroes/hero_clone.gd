class_name HeroClone
extends Combatant
## Artemis's Clone ability: a temporary stand-in spawned at cast time with
## the caster's own stats, copied in by Hero._try_clone before add_child().
## Taunts nearby minions (Combatant.is_taunting) and fights back, then
## expires after life_span regardless of how much damage it's taken.
##
## Designer, 2026-07-20: the clone stays put where it's spawned instead of
## tagging along after Artemis — it's a stationary decoy/taunt, not a second
## mover. It's also confined to the caster's own lane (see `lane` +
## _lane_ok below) so it never spawns on or fights into the opposite lane.

@export var life_span := 2.0

## Artemis herself, kept only to identify the caster (e.g. for future hooks) —
## the clone no longer moves toward it (see class doc).
var caster: Combatant = null
var follow_offset := Vector2.ZERO

## Copies its caster's role (set by Hero._try_clone) so it has the same shape
## as a real party member (e.g. ROLE_COLORS lookups) instead of erroring as a
## missing property.
var role := "TANK"

## Caster's lane, copied in by Hero._spawn_clone — restricts targeting via
## _lane_ok below the same way Hero does, so a clone spawned in one lane
## never taunts/attacks across into the other.
var lane := ""

## Extra Alpha, on top of Combatant's default paper-cutout fade, distinguishes
## the clone visually from the real Artemis (Designer, 2026-07-21) at a
## glance instead of only by its stationary behavior.
const CLONE_SPRITE_ALPHA := 0.55

func _configure() -> void:
	self_group = "heroes"
	enemy_group = "hostiles"

func _sprite_alpha() -> float:
	return CLONE_SPRITE_ALPHA

func _process(delta: float) -> void:
	super(delta)
	if _dying:
		return
	life_span -= delta
	if life_span <= 0.0:
		_die()
		return

## Same lane rule as Hero._lane_ok: only engage hostiles in the clone's own
## lane, unless the candidate has no lane of its own or the lanes have
## merged/collapsed.
func _lane_ok(node: Combatant) -> bool:
	if lane == "" or _field == null:
		return true
	if global_position.x >= _field.lane_merge_x() or _field.lanes_merged():
		return true
	var node_lane := ""
	if "lane" in node:
		node_lane = node.lane
	elif "_lane" in node:
		node_lane = node._lane
	return node_lane == "" or node_lane == lane
