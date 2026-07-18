class_name Hero
extends Combatant
## Placeholder party hero (e.g. Thundaar, Artemis).
##
## Spawned by BattleManager from the prep-screen party config at the field's
## hero-spawn funnel. Behavior follows the assigned battlefield priority
## (GDD §11), moving freely across the open field (steering around obstacles):
##  - CAPTURE_OBJECTIVES — head to the nearest uncaptured objective's general
##    area (fuzzed — exact spot unknown until within view range), search
##    until spotted, hold until captured, then repeat for any remaining
##    uncaptured objectives; once all are captured, fall through to the
##    villain push (Designer decision, see DECISIONS.md).
##  - ATTACK_VILLAIN   — default: push straight for the villain, staying
##    locked onto him even as he kites (detect range widened past his flee
##    distance), only trading blows with minions that wander into that
##    same range.
## Purchased upgrades (GameState) apply on spawn.

@export var hero_name := "HERO"
## Small offset so party members stand side by side, not overlapping.
@export var lateral := Vector2.ZERO
@export var priority := "ATTACK_VILLAIN"

## Formation bonuses (proximity-based role interactions)
const FORMATION_SAME_ROLE_DIST := 150.0
const FORMATION_SAME_ROLE_DAMAGE := 1.1
const FORMATION_OPPOSITE_ROLE_DIST := 200.0
const FORMATION_OPPOSITE_ROLE_TANK_HP := 1.15
const FORMATION_OPPOSITE_ROLE_BURST_DAMAGE := 1.15
const FORMATION_MIXED_TRIO_DIST := 180.0
const FORMATION_MIXED_TRIO_COOLDOWN := 0.05

## Thundaar's Stomp: auto-casts on cooldown whenever an enemy is in range,
## hitting everything within STOMP_RADIUS for damage + knockback.
const STOMP_COOLDOWN := 3.5
const STOMP_RADIUS := 70.0
const STOMP_DAMAGE := 26.0
const STOMP_KNOCKBACK := 100.0
## Ring VFX: how long the expanding-shockwave draw lasts after a landed stomp.
const STOMP_FLASH_TIME := 0.25
const STOMP_FLASH_COLOR := Color(1.0, 0.85, 0.3, 0.9)

## Artemis's Clone: auto-casts on cooldown, spawning a temporary copy of
## herself (see HeroClone) that taunts and fights back for CLONE_DURATION.
const CLONE_SCENE := preload("res://scenes/heroes/hero_clone.tscn")
const CLONE_COOLDOWN := 8.0
const CLONE_DURATION := 2.0
const CLONE_TAUNT_RADIUS := 90.0
## Spawn offset so the clone appears beside Artemis (toward her facing) instead
## of stacked exactly on top of her, where it's indistinguishable at a glance.
const CLONE_SPAWN_OFFSET := 40.0

## How often (seconds) the villain push-goal is refreshed while chasing him,
## so heroes follow his kiting/teleports instead of beelining a stale point.
const VILLAIN_TRACK_INTERVAL := 0.3
## Once the villain has entered detect/attack range at least once, heroes
## get more aggressive about following him — re-aiming this much more often
## so he can't shake them by kiting/teleporting just past the old interval's
## staleness window.
const VILLAIN_SPOTTED_TRACK_INTERVAL := 0.1

## Rally-to-ally: while on objective duty (not yet pushing the villain) with
## no threat in sight, a hero heads toward the nearest ally that IS currently
## fighting something, instead of wandering its own objective search pattern.
## Never applies to the villain push itself (ATTACK_VILLAIN, or CAPTURE_OBJECTIVES
## once _pushed_on) — that priority already has its own live-tracked goal.
const RALLY_CHECK_INTERVAL := 0.5
var _rally_cd := 0.0
## True while the current goal is a rally toward a fighting ally rather than
## the objective search pattern, so _on_goal_reached doesn't overwrite it with
## a fresh random search point the instant it's reached.
var _rallying := false

## Detect range while actively pushing the villain (ATTACK_VILLAIN, and
## CAPTURE_OBJECTIVES once its objectives are done). Must clear the villain's
## own flee_distance (see villain.gd) with margin, otherwise he kites just
## outside detect range and _acquire_target keeps dropping him as _target
## before a hero ever gets close enough to land a hit.
const VILLAIN_ENGAGE_RANGE := 320.0

## CAPTURE_OBJECTIVES search behavior: the hero only knows the objective's
## general area (a point randomized within this radius of the true spot) and
## must wander within view range of it before locking onto the exact position.
## Fuzz is kept <= view radius so any picked search point already lies within
## spotting range — otherwise a re-pick can land outside view range of the
## last one, sending the hero on an unbounded random walk that never closes in.
const OBJECTIVE_SEARCH_FUZZ := 120.0
const OBJECTIVE_VIEW_RADIUS := 150.0

## Abilities are bought as skill-tree nodes (GameState.ABILITY_NODES);
## point milestones and costs live there, not here.
const STOMP_STUN_DURATION := 0.5
const CLONE_DAMAGE_BOOST := 1.5  ## +50%, passive tree node.

## Thundaar's Shockwave (LV20 unlock): auto-casts on its own cooldown,
## a wide line in front of him hitting everything within its reach.
const SHOCKWAVE_COOLDOWN := 5.0
const SHOCKWAVE_RANGE := 180.0
const SHOCKWAVE_HALF_WIDTH := 60.0
const SHOCKWAVE_DAMAGE := 40.0
const SHOCKWAVE_KNOCKBACK := 80.0

## Artemis's Dash (LV20 unlock): auto-casts on its own cooldown, dashing
## toward the nearest minion cluster and hitting up to DASH_MAX_TARGETS
## enemies along the way for escalating damage.
const DASH_COOLDOWN := 6.0
const DASH_RANGE := 220.0
const DASH_RADIUS := 40.0
const DASH_MAX_TARGETS := 5
const DASH_BONUS_PER_TARGET := 3.0

## Synergy system: two-hero bonuses when both alive and within this distance.
const SYNERGY_DISTANCE := 200.0
const SYNERGY_DAMAGE_MULT := 1.15
const SYNERGY_COOLDOWN_REDUCTION := 0.3
const SYNERGY_XP_MULT := 1.25

## Lone Wolf: a single-hero roster has no ally to split aggro/damage with, so
## it gets a standing compensation buff instead (a permanent stat bump, set
## once at spawn from roster size — unlike synergy, this doesn't fluctuate
## with a nearby ally, since a solo roster never has one). Makes solo runs
## a possible (not guaranteed) win instead of never closing the gap; see
## BALANCE.md "Comprehensive sweep" / "Lone Wolf" for the sweep that showed
## solo never won within the standardized 60s test window pre-buff.
const LONE_WOLF_HP_MULT := 1.8
const LONE_WOLF_DAMAGE_MULT := 1.75
const LONE_WOLF_COOLDOWN_REDUCTION := 0.4

## Hero-specific base stats and scaling (applied in _configure before upgrades).
const HERO_STATS: Dictionary = {
	"THUNDAAR": {
		"base_hp": 120,
		"base_damage": 10,
		"hp_scale": 20,
		"damage_scale": 1.5,
		"attack_speed_scale": 0.97,
		"attack_interval": 0.7,
		"move_speed": 75,
	},
	"ARTEMIS": {
		"base_hp": 65,
		"base_damage": 6,
		"hp_scale": 12,
		"damage_scale": 2.5,
		"attack_speed_scale": 0.93,
		"move_speed": 115,
	},
}

## Artemis: ranged attacker — fires an arrow (Projectile) instead of melee,
## with a much longer attack_range and faster base attack_interval than the
## shared hero.tscn default (0.5s / 26px), traded for lower HP/damage above.
const ARTEMIS_PROJECTILE_SCENE := preload("res://scenes/combat/projectile.tscn")
const ARTEMIS_ATTACK_INTERVAL := 0.32
const ARTEMIS_ATTACK_RANGE := 160.0

## Fixed role per hero (TANK, BURST, CONTROL) — set in _configure based on hero_name.
var role := "CONTROL"

var _objective: Node2D = null
var _objective_spotted := false
var _pushed_on := false
var _ability_cd := 0.0
var _stomp_flash_t := 0.0
var _villain_track_cd := 0.0
## Set once the villain has come within detect range at least once (i.e. the
## hero has actually seen/engaged him), so tracking can get more aggressive.
var _villain_spotted := false
var _base_damage := 0.0
var _synergy_damage_mult := 1.0
var _synergy_cooldown_reduction := 0.0
## Run-scoped XP multiplier from the "Fortune" boon (RunState). Permanent for
## the current run; stacks multiplicatively with the timed objective XP boost.
var _run_xp_mult := 1.0
## Cached once at spawn: true when this hero is the only one in the roster
## (never flips mid-run, unlike synergy's live ally-adjacency check).
var _is_lone_wolf := false
## Formation bonuses (recomputed each frame based on nearby hero roles)
var _formation_hp_mult := 1.0
var _formation_damage_mult := 1.0
var _formation_cooldown_reduction := 0.0
## Which specific formation bonus is active (for HUD display; multiple mults
## above can come from different sources, so these disambiguate for the panel).
var _formation_same_role_active := false
var _formation_opposite_tank_active := false
var _formation_opposite_burst_active := false
var _formation_trio_active := false
## Max HP before the opposite-role GUARD+ bonus, captured once at spawn so the
## proximity-driven bonus has a stable amount to add/remove from as allies
## move in and out of range (rather than compounding off a moving target).
var _base_max_hp := 0.0
## Extra max HP currently granted by GUARD+; tracked so entering/leaving range
## adjusts both max_hp and hp by exactly this amount, preserving true damage
## taken instead of free-healing or hard-clamping HP away.
var _formation_bonus_hp := 0.0
## Level gates cached at spawn (level doesn't change mid-battle).
var _base_unlocked := false
var _passive_unlocked := false
var _active_unlocked := false
var _second_ability_cd := 0.0

## Seconds until the hero's special ability (Stomp/Clone) is ready; 0 = ready.
var ability_cooldown: float:
	get:
		return maxf(_ability_cd, 0.0)

## Full cooldown duration for this hero's ability (HUD fill-fraction display).
func ability_cooldown_max() -> float:
	match hero_name:
		"THUNDAAR": return STOMP_COOLDOWN
		"ARTEMIS": return CLONE_COOLDOWN
		_: return 1.0

## Currently active synergy/formation buffs, for the hero panel's buff row.
## Each entry is {text: String, color: Color}; empty when nothing is active.
func active_buffs() -> Array:
	var buffs: Array = []
	if _is_lone_wolf:
		if _synergy_damage_mult > 1.0:
			buffs.append({"text": "LONE WOLF", "color": Color("9b59b6")})
	elif _synergy_damage_mult > 1.0:
		buffs.append({"text": "SYNERGY", "color": Color("6fa8dc")})
	if _formation_same_role_active:
		buffs.append({"text": "ROLE DMG+", "color": Color("e08a3e")})
	if _formation_opposite_tank_active:
		buffs.append({"text": "GUARD+", "color": Color("5c9a5c")})
	if _formation_opposite_burst_active:
		buffs.append({"text": "BURST+", "color": Color("c0392b")})
	if _formation_trio_active:
		buffs.append({"text": "TRIO CD", "color": Color("d4c04a")})
	if _dmg_boost_t > 0.0:
		buffs.append({"text": "DMG+", "color": Color("c0392b")})
	if _speed_boost_t > 0.0:
		buffs.append({"text": "SPD+", "color": Color("4aa3df")})
	if _atk_speed_boost_t > 0.0:
		buffs.append({"text": "ATK SPD+", "color": Color("e0b03e")})
	if _xp_boost_t > 0.0:
		buffs.append({"text": "XP+", "color": Color("6fcf6f")})
	if shield_charges > 0:
		buffs.append({"text": "SHIELD x%d" % shield_charges, "color": Color("9bd1e5")})
	return buffs

func _configure() -> void:
	self_group = "heroes"
	enemy_group = "hostiles"
	label_text = hero_name
	# Set fixed role based on hero name.
	match hero_name:
		"THUNDAAR": role = "TANK"
		"ARTEMIS": role = "BURST"
	# Apply hero-specific base stats and scaling.
	if hero_name in HERO_STATS:
		var stats: Dictionary = HERO_STATS[hero_name] as Dictionary
		var base_hp_val: float = stats.get("base_hp", 100.0) as float
		var base_dmg_val: float = stats.get("base_damage", 10.0) as float
		var hp_scale_val: float = stats.get("hp_scale", 15.0) as float
		var dmg_scale_val: float = stats.get("damage_scale", 2.0) as float
		max_hp = float(base_hp_val)
		damage = float(base_dmg_val)
		var hp_bonus: float = GameState.bonus_max_hp(hero_name) * (float(hp_scale_val) / 15.0)
		var dmg_bonus: float = GameState.bonus_damage(hero_name) * (float(dmg_scale_val) / 2.0)
		max_hp += hp_bonus
		damage += dmg_bonus
		# Set attack interval and move speed from hero stats.
		if stats.has("attack_interval"):
			attack_interval = (stats["attack_interval"] as float) * pow(stats["attack_speed_scale"] as float, GameState.owned(hero_name, "attack_speed"))
		else:
			attack_interval *= pow(stats["attack_speed_scale"] as float, GameState.owned(hero_name, "attack_speed"))
		if stats.has("move_speed"):
			move_speed = stats["move_speed"] as float
		if hero_name == "ARTEMIS":
			attack_interval = ARTEMIS_ATTACK_INTERVAL * pow(float(stats["attack_speed_scale"]), GameState.owned(hero_name, "attack_speed"))
			attack_range = ARTEMIS_ATTACK_RANGE
			is_ranged = true
			projectile_scene = ARTEMIS_PROJECTILE_SCENE
	else:
		max_hp += GameState.bonus_max_hp(hero_name)
		damage += GameState.bonus_damage(hero_name)
		attack_interval *= GameState.attack_interval_mult(hero_name)
	_is_lone_wolf = GameState.selected_heroes().size() == 1
	if _is_lone_wolf:
		max_hp *= LONE_WOLF_HP_MULT
	_base_max_hp = max_hp
	_base_damage = damage
	move_speed += GameState.bonus_move_speed(hero_name)
	# Ability unlocks: bought explicitly on the skill tree.
	_base_unlocked = GameState.ability_owned(hero_name, "base")
	_passive_unlocked = GameState.ability_owned(hero_name, "passive")
	_active_unlocked = GameState.ability_owned(hero_name, "active")
	# Spawn at the funnel; default goal is the villain's corner.
	global_position = _field.hero_spawn + lateral
	set_goal(_field.villain_pos + lateral)
	# Priority-specific behavior.
	match priority:
		"ATTACK_VILLAIN":
			# Push straight for the villain and stay locked on regardless of
			# his kiting (see VILLAIN_ENGAGE_RANGE); only fights minions that
			# wander within that same range, so it still reads as "fights
			# what's in the way" rather than roaming for stragglers.
			detect_range = VILLAIN_ENGAGE_RANGE
		"CAPTURE_OBJECTIVES":
			# Tight engagement range while on objective duty: this hero is on a
			# mission to the objective, not free to get dragged off chasing
			# every minion that wanders within normal detect range.
			detect_range = attack_range * 1.3
			_objective = _nearest_uncaptured_objective(global_position)
			if _objective != null:
				# The hero only knows the objective's general area until it's
				# close enough to spot it — head to a fuzzed point nearby and
				# search from there rather than beelining the exact spot.
				_pick_objective_search_point()
			else:
				# No objectives left uncaptured at spawn: skip straight to the
				# villain push with the same wide engage range as ATTACK_VILLAIN.
				_pushed_on = true
				detect_range = VILLAIN_ENGAGE_RANGE

func _process(delta: float) -> void:
	# Update synergy state before calling super (which applies combat).
	_update_synergy()
	_update_formation()
	super(delta)
	if _dying:
		return
	_stomp_flash_t = maxf(_stomp_flash_t - delta, 0.0)

	# Ranged heroes (Artemis) can lock onto a minion from well outside melee
	# range and then never move again — super() only calls _advance_goal when
	# there's no target, so a stationary ranged hero would snipe that minion
	# forever and never close in enough to bring the villain within
	# detect_range. While actively pushing the villain, keep closing toward
	# him even mid-fight, same as a melee hero is forced to by walking up to
	# its target.
	if is_ranged and _stun_t <= 0.0 and _target != null and not _target.is_in_group("villains") \
			and (_objective == null or _pushed_on):
		_advance_goal(delta)

	# Capture priority: still searching for the objective (hasn't spotted the
	# exact spot yet) — check whether it's now within view.
	if _objective != null and not _objective_spotted and not _pushed_on:
		if global_position.distance_to(_objective.global_position) <= OBJECTIVE_VIEW_RADIUS:
			_objective_spotted = true
			# No lateral offset here: lateral spaces heroes out for the long
			# villain push, but the objective is a small fixed point — adding
			# it can push the goal outside capture_radius, parking the hero
			# beside the marker instead of on it.
			set_goal(_objective.global_position)

	# Capture priority: once the current objective is taken, move on to the
	# next uncaptured one (if any); only push to the villain once none remain.
	if not _pushed_on and _objective != null and _objective.is_captured:
		var next_objective := _nearest_uncaptured_objective(global_position)
		if next_objective != null:
			_objective = next_objective
			_objective_spotted = false
			_pick_objective_search_point()
		else:
			_pushed_on = true
			detect_range = VILLAIN_ENGAGE_RANGE
			set_goal(_field.villain_pos + lateral)

	# Rally-to-ally: still on objective duty (haven't pushed to the villain
	# yet) with no threat currently in sight — head toward whichever ally is
	# actively fighting something instead of wandering alone.
	if priority == "CAPTURE_OBJECTIVES" and not _pushed_on and _target == null:
		_rally_cd -= delta
		if _rally_cd <= 0.0:
			_rally_cd = RALLY_CHECK_INTERVAL
			var ally := _find_engaged_ally()
			if ally != null:
				_rallying = true
				set_goal(ally.global_position)
			elif _rallying:
				# The ally we were rallying to stopped fighting (or died) —
				# resume the normal objective search pattern.
				_rallying = false
				if _objective != null and not _objective_spotted:
					_pick_objective_search_point()
				elif _objective != null:
					set_goal(_objective.global_position)
	elif _rallying:
		_rallying = false

	# While pushing toward the villain (not holding at an uncaptured
	# objective), keep re-aiming at his live position so kiting/teleports
	# don't leave heroes marching on his original spawn point.
	if _objective == null or _pushed_on:
		if not _villain_spotted and global_position.distance_to(_field.villain_pos) <= detect_range:
			_villain_spotted = true
		_villain_track_cd -= delta
		if _villain_track_cd <= 0.0:
			_villain_track_cd = VILLAIN_SPOTTED_TRACK_INTERVAL if _villain_spotted else VILLAIN_TRACK_INTERVAL
			set_goal(_field.villain_pos + lateral)

	if _base_unlocked:
		_ability_cd -= delta
		if _ability_cd <= 0.0:
			match hero_name:
				"THUNDAAR":
					_try_stomp()
				"ARTEMIS":
					_try_clone()

	if _active_unlocked:
		_second_ability_cd -= delta
		if _second_ability_cd <= 0.0:
			match hero_name:
				"THUNDAAR":
					_try_shockwave()
				"ARTEMIS":
					_try_dash()

## Closest uncaptured objective to `from` (e.g. this hero's spawn point).
func _nearest_uncaptured_objective(from: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for o in get_tree().get_nodes_in_group("objectives"):
		if o.is_captured:
			continue
		var d := from.distance_squared_to(o.global_position)
		if d < best_d:
			best_d = d
			best = o
	return best

## Heads toward a random point within OBJECTIVE_SEARCH_FUZZ of the (not yet
## spotted) objective's true position, so the hero searches its general area
## instead of beelining the exact spot.
func _pick_objective_search_point() -> void:
	if _objective == null:
		return
	var offset := Vector2(
		randf_range(-OBJECTIVE_SEARCH_FUZZ, OBJECTIVE_SEARCH_FUZZ),
		randf_range(-OBJECTIVE_SEARCH_FUZZ, OBJECTIVE_SEARCH_FUZZ))
	set_goal(_objective.global_position + offset)

## Subclass hook (Combatant): reached the current goal. While still searching
## for an unspotted objective, keep wandering with a fresh nearby point.
func _on_goal_reached() -> void:
	if _rallying:
		return
	if _objective != null and not _objective_spotted and not _pushed_on:
		_pick_objective_search_point()

## Nearest live ally hero currently engaged with an enemy (has a target),
## for the rally-to-ally mechanic. Null if no ally is fighting anything.
func _find_engaged_ally() -> Combatant:
	var best: Combatant = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("heroes"):
		if node == self or not is_instance_valid(node) or node._dying:
			continue
		if node._target == null or not is_instance_valid(node._target) or node._target._dying:
			continue
		var d := global_position.distance_squared_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best

## All heroes target the villain over any minion whenever he's within their
## detect_range, so a hero standing on top of him doesn't get pulled off onto
## whichever minion happens to be a step closer.
func _acquire_target() -> void:
	for node in get_tree().get_nodes_in_group("villains"):
		if not is_instance_valid(node) or node._dying:
			continue
		if global_position.distance_squared_to(node.global_position) <= detect_range * detect_range:
			_target = node
			return
	super()

## Apply synergy damage multiplier to actual damage dealt.
func _engage(delta: float) -> void:
	var scaled_damage := damage * _synergy_damage_mult * _formation_damage_mult * damage_mult()
	var original_damage := damage
	damage = scaled_damage
	super(delta)
	damage = original_damage

## Stomp: hits every enemy within STOMP_RADIUS for damage + knockback.
## Only starts its cooldown once it actually lands (an enemy was in range),
## so it fires the moment one wanders close rather than on a fixed timer.
func _try_stomp() -> void:
	if _target == null:
		return
	var hit := false
	for node in get_tree().get_nodes_in_group(enemy_group):
		if not is_instance_valid(node) or node._dying:
			continue
		var to_node: Vector2 = node.global_position - global_position
		if to_node.length() <= STOMP_RADIUS:
			hit = true
			node.take_damage(STOMP_DAMAGE * _synergy_damage_mult * _formation_damage_mult * damage_mult(), self)
			if is_instance_valid(node) and not node._dying:
				node.apply_knockback(to_node.normalized(), STOMP_KNOCKBACK, 0.0, self)
				if _passive_unlocked:
					node.apply_stun(STOMP_STUN_DURATION)
	if hit:
		var cooldown := STOMP_COOLDOWN - _synergy_cooldown_reduction - _formation_cooldown_reduction
		_ability_cd = maxf(cooldown, 0.1)
		_stomp_flash_t = STOMP_FLASH_TIME

## Draws the expanding shockwave ring on top of the base Combatant art while a
## landed stomp's flash timer is running.
func _draw() -> void:
	super()
	if _stomp_flash_t <= 0.0:
		return
	var p := 1.0 - _stomp_flash_t / STOMP_FLASH_TIME
	var ring_color := STOMP_FLASH_COLOR
	ring_color.a *= 1.0 - p
	draw_arc(Vector2.ZERO, STOMP_RADIUS * p, 0.0, TAU, 32, ring_color, 4.0, true)

## Clone: spawns a temporary copy of Artemis's current stats that taunts
## and fights back for CLONE_DURATION, then expires (see HeroClone).
func _try_clone() -> void:
	if _target == null:
		return
	var clone := CLONE_SCENE.instantiate()
	clone.label_text = hero_name + " Clone"
	clone.max_hp = max_hp
	var clone_damage_mult := _synergy_damage_mult * _formation_damage_mult * damage_mult() * (CLONE_DAMAGE_BOOST if _passive_unlocked else 1.0)
	clone.damage = damage * clone_damage_mult
	clone.attack_interval = attack_interval
	clone.attack_range = attack_range
	clone.is_ranged = is_ranged
	clone.projectile_scene = projectile_scene
	clone.projectile_speed = projectile_speed
	clone.detect_range = detect_range
	clone.knockback_chance = knockback_chance
	clone.knockback_distance = knockback_distance
	clone.knockback_splash_damage = knockback_splash_damage
	clone.move_speed = move_speed
	clone.body_radius = body_radius
	clone.sprite_texture = sprite_texture
	clone.sprite_scale = sprite_scale
	clone.body_color = body_color
	clone.is_taunting = true
	clone.taunt_radius = CLONE_TAUNT_RADIUS
	clone.life_span = CLONE_DURATION
	clone.caster = self
	clone.role = role
	clone.follow_offset = Vector2(_facing_x, 0.0) * CLONE_SPAWN_OFFSET
	get_parent().add_child(clone)
	clone.global_position = global_position + clone.follow_offset
	var cooldown := CLONE_COOLDOWN - _synergy_cooldown_reduction - _formation_cooldown_reduction
	_ability_cd = maxf(cooldown, 0.1)

## Shockwave (LV20 unlock, Thundaar): a wide line in front of him, hitting
## everything within SHOCKWAVE_RANGE / SHOCKWAVE_HALF_WIDTH for heavy damage
## and knockback. Auto-casts toward the current target's direction.
func _try_shockwave() -> void:
	if _target == null:
		return
	var dir := (_target.global_position - global_position).normalized()
	var hit := false
	for node in get_tree().get_nodes_in_group(enemy_group):
		if not is_instance_valid(node) or node._dying:
			continue
		var to_node: Vector2 = node.global_position - global_position
		var forward := to_node.dot(dir)
		if forward < 0.0 or forward > SHOCKWAVE_RANGE:
			continue
		var lateral_dist := (to_node - dir * forward).length()
		if lateral_dist > SHOCKWAVE_HALF_WIDTH:
			continue
		hit = true
		node.take_damage(SHOCKWAVE_DAMAGE * _synergy_damage_mult * _formation_damage_mult * damage_mult(), self)
		if is_instance_valid(node) and not node._dying:
			node.apply_knockback(dir, SHOCKWAVE_KNOCKBACK, 0.0, self)
	if hit:
		_second_ability_cd = maxf(SHOCKWAVE_COOLDOWN - _synergy_cooldown_reduction - _formation_cooldown_reduction, 0.1)

## Dash (LV20 unlock, Artemis): dashes toward the nearest cluster of enemies,
## hitting up to DASH_MAX_TARGETS along the way with escalating damage per
## target (rewards diving into a pack rather than picking off stragglers).
func _try_dash() -> void:
	if _target == null:
		return
	var to_target := _target.global_position - global_position
	if to_target.length() > DASH_RANGE:
		return
	var dir := to_target.normalized()
	var hit_count := 0
	var candidates: Array[Combatant] = []
	for node in get_tree().get_nodes_in_group(enemy_group):
		if not is_instance_valid(node) or node._dying:
			continue
		var to_node: Vector2 = node.global_position - global_position
		var forward := to_node.dot(dir)
		if forward < 0.0 or forward > DASH_RANGE:
			continue
		var lateral_dist := (to_node - dir * forward).length()
		if lateral_dist <= DASH_RADIUS:
			candidates.append(node)
	candidates.sort_custom(func(a, b):
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
	for node in candidates:
		if hit_count >= DASH_MAX_TARGETS:
			break
		var bonus_damage := damage + DASH_BONUS_PER_TARGET * hit_count
		node.take_damage(bonus_damage * _synergy_damage_mult * _formation_damage_mult * damage_mult(), self)
		hit_count += 1
	if hit_count > 0:
		global_position = global_position.move_toward(_target.global_position, DASH_RANGE * 0.5)
		_second_ability_cd = maxf(DASH_COOLDOWN - _synergy_cooldown_reduction - _formation_cooldown_reduction, 0.1)

## Check synergy: if another living hero is nearby, apply bonuses.
func _update_synergy() -> void:
	var has_ally := false
	for node in get_tree().get_nodes_in_group("heroes"):
		if node != self and is_instance_valid(node) and not node._dying:
			if global_position.distance_to(node.global_position) <= SYNERGY_DISTANCE:
				has_ally = true
				break
	if has_ally:
		_synergy_damage_mult = SYNERGY_DAMAGE_MULT
		_synergy_cooldown_reduction = SYNERGY_COOLDOWN_REDUCTION
	elif _is_lone_wolf:
		_synergy_damage_mult = LONE_WOLF_DAMAGE_MULT
		_synergy_cooldown_reduction = LONE_WOLF_COOLDOWN_REDUCTION
	else:
		_synergy_damage_mult = 1.0
		_synergy_cooldown_reduction = 0.0

## Check formation bonuses: calculate role-based bonuses based on nearby heroes.
func _update_formation() -> void:
	_formation_hp_mult = 1.0
	_formation_damage_mult = 1.0
	_formation_cooldown_reduction = 0.0
	_formation_same_role_active = false
	_formation_opposite_tank_active = false
	_formation_opposite_burst_active = false
	_formation_trio_active = false

	var nearby_heroes = []
	var same_role_count = 0
	var opposite_role_found = false

	for node in get_tree().get_nodes_in_group("heroes"):
		if node != self and is_instance_valid(node) and not node._dying:
			nearby_heroes.append(node)

	# Check for same-role cluster (2+ of same role within 150px)
	for hero in nearby_heroes:
		if global_position.distance_to(hero.global_position) <= FORMATION_SAME_ROLE_DIST:
			if hero.role == role:
				same_role_count += 1

	if same_role_count >= 1:  # At least one other of same role nearby
		_formation_damage_mult = FORMATION_SAME_ROLE_DAMAGE
		_formation_same_role_active = true

	# Check for opposite-role pairing within 200px
	for hero in nearby_heroes:
		if global_position.distance_to(hero.global_position) <= FORMATION_OPPOSITE_ROLE_DIST:
			var is_opposite = false
			if role == "TANK" and hero.role == "BURST":
				is_opposite = true
			elif role == "BURST" and hero.role == "TANK":
				is_opposite = true

			if is_opposite:
				opposite_role_found = true
				if role == "TANK":
					_formation_hp_mult = FORMATION_OPPOSITE_ROLE_TANK_HP
					_formation_opposite_tank_active = true
				elif role == "BURST":
					_formation_damage_mult = FORMATION_OPPOSITE_ROLE_BURST_DAMAGE
					_formation_opposite_burst_active = true
				break

	# Check for mixed trio (3+ heroes with different roles within 180px)
	if nearby_heroes.size() >= 2:
		var role_set: Array[String] = [role]
		var mixed_in_range = 1
		for hero in nearby_heroes:
			if global_position.distance_to(hero.global_position) <= FORMATION_MIXED_TRIO_DIST:
				if not role_set.has(hero.role):
					role_set.append(hero.role)
				mixed_in_range += 1
		if role_set.size() >= 3 and mixed_in_range >= 3:
			_formation_cooldown_reduction = FORMATION_MIXED_TRIO_COOLDOWN
			_formation_trio_active = true

	# Apply GUARD+ to max_hp/hp by the exact delta so entering/leaving range
	# adds or removes only the bonus amount, never touching real damage taken.
	var target_bonus_hp := _base_max_hp * (_formation_hp_mult - 1.0)
	if not is_equal_approx(target_bonus_hp, _formation_bonus_hp):
		var delta := target_bonus_hp - _formation_bonus_hp
		_formation_bonus_hp = target_bonus_hp
		max_hp += delta
		hp = clampf(hp + delta, 1.0, max_hp)

## Killing blows earn XP (banked immediately — kept even on a wipe); the rest
## of the party banks an assist share so tanks/screeners progress too.
## Synergy multiplier: both heroes earn bonus XP when in range.
func _on_kill(victim: Combatant) -> void:
	var xp_amount := victim.xp_value
	# Synergy multiplier (also catches Lone Wolf's compensation buff, since
	# both are mutually-exclusive states that raise _synergy_damage_mult above 1.0).
	if _synergy_damage_mult > 1.0:
		xp_amount = int(xp_amount * SYNERGY_XP_MULT)
	xp_amount = int(xp_amount * xp_mult() * _run_xp_mult)
	GameState.award_kill_xp(self, xp_amount)

## Applies a run boon (RunState / Boons catalog) live to this hero. Boons are
## direct base-stat changes so they compose with the synergy/formation
## multipliers already applied in _engage and the ability functions. Permanent
## for the current run; reset when the next run spawns a fresh hero.
func apply_run_boon(id: String) -> void:
	var d := Boons.def(id)
	if d.is_empty():
		return
	match d.get("kind", ""):
		"damage_mult":
			damage *= float(d.value)
			_base_damage = damage
		"max_hp_mult":
			var new_max: float = max_hp * float(d.value)
			var gain: float = new_max - max_hp
			max_hp = new_max
			# Keep the GUARD+ formation base in sync (it derives its bonus from
			# _base_max_hp) and heal by exactly the amount gained.
			_base_max_hp += gain
			hp = minf(hp + gain, max_hp)
		"atk_interval_mult":
			attack_interval *= float(d.value)
		"move_speed_mult":
			move_speed *= float(d.value)
		"xp_mult":
			_run_xp_mult *= float(d.value)
		"ferocity":
			damage *= float(d.get("dmg", 1.0))
			_base_damage = damage
			attack_interval *= float(d.get("atk", 1.0))
