class_name HeroClone
extends Combatant
## Artemis's Clone ability: a temporary stand-in spawned at cast time with
## the caster's own stats, copied in by Hero._try_clone/_spawn_ultimate_clone
## before add_child(). Taunts nearby minions (Combatant.is_taunting) and
## fights back, then expires after life_span regardless of how much damage
## it's taken.
##
## Designer, 2026-07-20: the clone stays put where it's spawned instead of
## tagging along after Artemis — it's a stationary decoy/taunt, not a second
## mover. It's also confined to the caster's own lane (see `lane` +
## _lane_ok below) so it never spawns on or fights into the opposite lane.
##
## Two Duo Ultimate variants (2026-07-22, see DuoUltimates/
## Hero.cast_duo_ultimate) reuse this same scene with extra flags instead of
## new clone classes:
##  - THUNDAAR+ARTEMIS ("exploding clones"): explode_on_hit.
##  - ARTEMIS+WARDEN ("roaming clones"): aggressive_roam (+ ensnare_on_hit on
##    top, since these clones are ranged and their shots also ensnare).
## Both are OFF by default, leaving the plain Clone ability byte-identical.

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

## -- Duo Ultimate variants (2026-07-22) --------------------------------------

## ARTEMIS+WARDEN ("roaming clones"): unlike a normal clone (stays put — see
## class doc), this one behaves like a real unit, chasing and fighting nearby
## minions instead of waiting at its spawn point. Set before add_child();
## _configure() derives is_pinned/detect_range from this one flag so callers
## don't need to juggle both.
var aggressive_roam := false
## How much wider a roaming clone's detect range is vs. a normal (pinned)
## clone's copied-from-caster value — "more aggressive towards minions"
## means noticing them from farther away, not just chasing once acquired.
const AGGRESSIVE_DETECT_RANGE_MULT := 1.6

## ARTEMIS+WARDEN's roaming clones also ensnare whatever their shots land on
## (set alongside aggressive_roam, but independent — see
## _configure_projectile). Duration is boon-scalable at cast time.
var ensnare_on_hit := false
var ensnare_stun_duration := 1.0

## THUNDAAR+ARTEMIS ("exploding clones"): the first hit this clone takes
## detonates it — AoE damage to nearby enemies, then it dies immediately,
## instead of tanking hits until life_span runs out like a normal clone.
var explode_on_hit := false
var explode_radius := 0.0
var explode_damage := 0.0
var _exploded := false

func _configure() -> void:
	self_group = "heroes"
	enemy_group = "hostiles"
	is_pinned = not aggressive_roam
	# A decoy/taunt, not a real body — no paper corpse when it expires/explodes.
	leaves_corpse = false
	if aggressive_roam:
		detect_range *= AGGRESSIVE_DETECT_RANGE_MULT

func _sprite_alpha() -> float:
	return CLONE_SPRITE_ALPHA

func _process(delta: float) -> void:
	super(delta)
	if _dying:
		return
	life_span -= delta
	if life_span <= 0.0:
		# Ability-cadence pass (2026-07-24): explode_on_hit clones dealt ZERO
		# damage if nothing ever attacked them — a once-per-level Duo Ultimate
		# could whiff entirely. Detonate on expiry too so it always resolves.
		if explode_on_hit and not _exploded:
			_exploded = true
			_explode()
			return
		_die()
		return

## Shot art + ensnare-on-hit.
##
## A clone already copies its caster's stats, sprite and projectile_scene, but
## NOT the caster's shot art — so a roaming clone fired Projectile's plain
## line+circle placeholder while the real Artemis beside it fired arrows
## (Designer, 2026-07-25). Delegating to the caster's own
## Hero._configure_projectile fixes that at the source: the clone shoots
## whatever its caster shoots, and a future hero with different shot art needs
## no change here.
##
## Ensnare (ARTEMIS+WARDEN) is applied after, so it stacks on top of the art —
## see Combatant._fire_projectile / Projectile.on_hit_stun.
func _configure_projectile(proj: Projectile) -> void:
	if caster != null and is_instance_valid(caster) and caster is Hero:
		(caster as Hero)._configure_projectile(proj)
	if ensnare_on_hit:
		proj.on_hit_stun = ensnare_stun_duration

## Explode-on-hit (THUNDAAR+ARTEMIS): detonate on the first hit taken rather
## than absorbing damage like a normal clone. Runs the real damage through
## first (so it still counts as a landed hit for whatever attacked it), then
## detonates once, even if that hit was already lethal on its own.
func take_damage(amount: float, attacker: Combatant = null) -> void:
	if _exploded:
		return
	super(amount, attacker)
	if explode_on_hit:
		_exploded = true
		_explode()

func _explode() -> void:
	for node in get_tree().get_nodes_in_group(enemy_group):
		if not is_instance_valid(node) or node._dying:
			continue
		if global_position.distance_to(node.global_position) <= explode_radius:
			node.take_damage(explode_damage, self)
	_die()

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
