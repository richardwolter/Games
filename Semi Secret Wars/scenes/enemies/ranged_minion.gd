class_name RangedMinion
extends Minion
## Stage 3 minion variant (placeholder): long attack_range simulates a
## ranged/projectile attacker (no projectile visual yet — hits on range
## like every other Combatant). Low HP, fast — a glass cannon in the swarm.
##
## Reuses the Minion AI (hunt, intercept targeting, goal-based fallback);
## stats are tuned in ranged_minion.tscn.

## Per-stage shot art, mirroring Minion.SPRITE_VARIANTS_BY_LEVEL. Only stage 2
## has bespoke projectile art (Designer, 2026-07-25); any other level keeps
## Projectile's plain line+circle, exactly as before.
const PROJECTILE_SPRITE_BY_LEVEL: Dictionary = {
	2: preload("res://assets/sprites/Berserk_Minion2_Projectile.png"),
}
## The shooter's own art, claimed exclusively from Minion.SPRITE_VARIANTS_BY_LEVEL
## so the syringe-carrying minion is the only one that fires (Designer,
## 2026-07-25). Levels without an entry keep whatever the base picked.
const SPRITE_BY_LEVEL: Dictionary = {
	2: preload("res://assets/sprites/Minion2_Berserk.png"),
}

const PROJECTILE_SPRITE_LENGTH := 30.0
## See Projectile.sprite_rotation_offset. The stage-2 droplet art reads
## tip-first toward its own source, so it needs -PI/2, not +PI/2: at +PI/2 the
## spray flew backwards, tip leading (Designer, 2026-07-25).
const PROJECTILE_SPRITE_ROTATION := -PI * 0.5

func _configure() -> void:
	super()
	# Actually fires now (Designer, 2026-07-25). This was a placeholder that
	# only simulated range by meleeing from far away — it had neither
	# is_ranged nor a projectile_scene, so the shot art shipped with stage 2
	# had nothing to fire it. attack_range/interval are unchanged, so its
	# damage cadence is the same; the difference is travel time and a visible
	# shot instead of instant contact damage.
	is_ranged = true
	projectile_scene = load("res://scenes/combat/projectile.tscn")
	# Overrides the random variant super() just picked; scale is left alone so
	# it stays sized with the rest of its stage's swarm.
	var own_sprite = SPRITE_BY_LEVEL.get(RunState.current_level, null)
	if own_sprite != null:
		sprite_texture = own_sprite

func _configure_projectile(proj: Projectile) -> void:
	var tex = PROJECTILE_SPRITE_BY_LEVEL.get(RunState.current_level, null)
	if tex != null:
		proj.sprite_texture = tex
		proj.sprite_length = PROJECTILE_SPRITE_LENGTH
		# The droplet spray is drawn pointing UP; without this it flew sideways
		# (Designer, 2026-07-25). +PI/2 aims the nozzle along the shot, so the
		# drops read as coming out of a syringe needle.
		proj.sprite_rotation_offset = PROJECTILE_SPRITE_ROTATION
