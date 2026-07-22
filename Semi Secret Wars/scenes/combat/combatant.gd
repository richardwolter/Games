class_name Combatant
extends Node2D
## Base class for mobile combat units (heroes, minions).
##
## One self-contained node per unit — health, target acquisition, melee attacks,
## death, open-field movement, and drawing all live here so heroes and minions
## don't duplicate them. Kept node-light (no per-unit child components) so the
## model can later migrate to a bulk/data-oriented swarm system for large enemy
## counts (see DECISIONS.md). Combat *values* are exports, tuned in the unit
## scenes and mirrored in BALANCE.md.
##
## Behavior: if an enemy is within detect range, engage it (close to attack range
## and attack on cooldown); otherwise steer toward `goal`, avoiding the field's
## blocking obstacles (LaneField.steer_around). Minions set heroes as their
## enemy group, so they naturally break off to attack heroes.

signal died(who: Combatant)

@export_group("Combat")
@export var max_hp := 100.0
@export var damage := 12.0
@export var attack_interval := 0.5
@export var attack_range := 26.0
@export var detect_range := 90.0
@export var move_speed := 70.0
## XP granted to the killer when this unit dies in combat.
@export var xp_value := 0
## Chance per hit to knock the target back (0 = never). Splash damage hits
## anything of the target's own group caught in the knockback's path.
@export var knockback_chance := 0.0
@export var knockback_distance := 40.0
@export var knockback_splash_damage := 6.0
## Taunt (e.g. Artemis's Clone ability): enemies already within taunt_radius
## of this unit target it instead of their normal nearest pick. Enemies
## outside the radius are unaffected and keep pathing toward real heroes.
@export var is_taunting := false
@export var taunt_radius := 0.0
## Ranged attacks (e.g. Artemis): fires a travel-time Projectile at the
## target instead of applying damage instantly on cooldown.
@export var is_ranged := false
@export var projectile_scene: PackedScene = null
@export var projectile_speed := 500.0
## Max travel distance before an unfired-at-nothing projectile vanishes (miss).
@export var projectile_range := 600.0

@export_group("Visual")
@export var sprite_texture: Texture2D = null
## Visual-only size multiplier for sprite_texture; does not affect body_radius
## (collision/separation/knockback), only how big the art draws.
@export var sprite_scale := 1.0
@export var body_color := Color("cccccc")
@export var body_radius := 18.0
@export var outline_color := Color("2c2c2c")
@export var outline_width := 3.0
@export var bob_amplitude := 3.0
@export var bob_speed := 5.0
## White hit-flash overlay on take_damage. Off for static structures (e.g.
## LaneSpawnPoint) where the flash reads as flicker rather than a hit reaction.
@export var flash_on_hit := true
## Pinned structure (e.g. LaneSpawnPoint): skips separation and the
## obstacle/field clamp in _process entirely. Without this, a unit that
## registers itself as a dynamic_obstacle (as LaneSpawnPoint does, so other
## units steer around it) sees its own entry at distance 0 every frame and
## gets shoved body_radius*2 sideways by clamp_out_of_obstacles' zero-distance
## fallback — briefly rendering at the shoved position before being pinned
## back, a one-frame position pop.
@export var is_pinned := false

const RETARGET_INTERVAL := 0.25
const FLASH_TIME := 0.12
const DEATH_TIME := 0.2
const LUNGE_DIST := 8.0
const LUNGE_RETURN := 60.0
## Ranged units (is_ranged) back away once the target closes inside this
## fraction of attack_range, instead of standing still and letting melee
## enemies walk right up next to them — they'd rather shoot from afar than
## get cornered at point-blank. Leaves a stable no-move band between this and
## attack_range so kiting doesn't oscillate.
const RANGED_STANDOFF_FRACTION := 0.6
## Same soft paper-cutout alpha as the border decor's near-camera tree row
## (see LaneForeground.near_row_alpha) — applied to every sprite-textured unit
## so heroes/minions read as part of the same visual treatment as the
## environment art, instead of drawing fully opaque.
const SPRITE_ALPHA := 0.92

## Overridable so a subclass can draw more transparent than the norm (e.g.
## HeroClone, which needs to read as a distinct decoy rather than a second
## copy of its caster). Defaults to the shared paper-cutout alpha above.
func _sprite_alpha() -> float:
	return SPRITE_ALPHA
## Extra breathing room beyond the two bodies' radii before separation kicks in.
const SEPARATION_MARGIN := 4.0
## How fast overlapping units are pushed apart, in px/sec.
const SEPARATION_SPEED := 220.0

# Set by subclasses in _configure().
var self_group := ""
var enemy_group := ""
var label_text := ""

const GOAL_REACHED_DIST := 14.0

var hp := 0.0
## Where this unit is heading when not fighting. Vector2.INF = no goal (idle).
var goal := Vector2.INF

var attack_cooldown: float:
	get:
		return _attack_cd
var _goal_done := false
var _field: LaneField = null
var _bob := 0.0
var _bob_phase := 0.0
var _target: Combatant = null
var _attack_cd := 0.0
var _retarget_cd := 0.0
var _flash := 0.0
var _lunge := Vector2.ZERO
var _dying := false
var _death_t := 0.0
var _heading := Vector2.ZERO
var _in_lake := false
## Villain dormancy (gameplay-loop rework): while > 0 the unit stays inert at
## its lair until a hero enters this radius or it takes a hit — see is_alerted().
## 0 = not dormant, always active (heroes, minions). Set in a villain's _configure.
var villain_aggro_radius := 0.0
var _alerted := false
## Seconds remaining stunned (movement/attacks paused). 0 = not stunned.
var _stun_t := 0.0
## Seconds remaining slowed (movement/attack rate scaled by _slow_factor). 0 = not slowed.
var _slow_t := 0.0
var _slow_factor := 1.0
## Seconds remaining confused (targets own group instead of the enemy group).
## 0 = not confused. Applied by BEACON's Confuse ultimate (minions only).
var _confused_t := 0.0
## Timed party-wide buffs (e.g. objective-completion rewards); see apply_damage_boost etc.
var _dmg_boost_t := 0.0
var _dmg_boost_mult := 1.0
var _speed_boost_t := 0.0
var _speed_boost_mult := 1.0
var _atk_speed_boost_t := 0.0
var _atk_speed_boost_mult := 1.0
var _xp_boost_t := 0.0
var _xp_boost_mult := 1.0
## Absorbs the next N instances of damage entirely (e.g. objective reward shield).
var shield_charges := 0
## Brief colored ring around this unit — visual confirmation that a status
## effect (stun/slow/buff/shield) just landed on it, so ability procs read
## clearly during fast real-time play instead of only showing up as a HUD
## buff chip. Triggered automatically by the apply_* methods below; shared by
## every Combatant (heroes, minions, villains) so any future status source
## gets this for free. Last effect wins if two land the same frame — a
## legibility aid, not a stacking effect queue.
var _status_flash_t := 0.0
var _status_flash_color := Color.WHITE
const STATUS_STUN_COLOR := Color(0.65, 0.95, 1.0, 0.95)
const STATUS_SLOW_COLOR := Color(0.55, 0.45, 0.85, 0.9)
const STATUS_BUFF_COLOR := Color(0.9, 0.75, 0.25, 0.9)
const STATUS_SHIELD_COLOR := Color(0.6, 0.85, 0.95, 0.9)
const STATUS_CONFUSE_COLOR := Color(0.95, 0.4, 0.85, 0.95)
## Fixed flash length for apply_shield, which has no duration of its own
## (a charge count, not a timer) — just a short "you got shielded" pulse.
const STATUS_SHIELD_FLASH_TIME := 0.4
## Sprite art faces left by default; flips to face right when moving/aiming that way.
var _facing_x := -1.0
## Cached push-apart vector from same-group neighbors, refreshed at RETARGET_INTERVAL
## (like target acquisition) so it stays cheap with hundreds of active minions.
var _separation := Vector2.ZERO
## When true, recompute the separation vector EVERY frame instead of on the
## throttled retarget tick. Set by Hero (there are only ≤3 of them, so the cost
## is trivial) — a per-frame recompute self-limits as the overlap shrinks, so
## bodies converge to their min spacing instead of overshooting on a stale,
## oversized push and bouncing back. Minions leave this false to keep the swarm
## cheap (see DECISIONS.md swarm scaling).
var separation_per_frame := false

## Subclass hook: set self_group / enemy_group / label_text / spawn position / goal.
func _configure() -> void:
	pass

## Radius to use for hard-obstacle clamping (clamp_out_of_obstacles/clamp_inside_field).
## body_radius alone under-reports how much space a unit actually occupies
## on screen when sprite_texture draws bigger than the hitbox (draw size is
## body_radius * 2 * sprite_scale — see _draw), which reads as clipping into
## solid blockers (mountains, spawn gates) even though centers never touch.
func _collision_radius() -> float:
	if sprite_texture != null:
		return maxf(body_radius, body_radius * sprite_scale)
	return body_radius

## Subclass hook: called once when the unit reaches its goal.
func _on_goal_reached() -> void:
	pass

func _ready() -> void:
	_field = get_tree().get_first_node_in_group("field")
	_configure()
	hp = max_hp
	if self_group != "":
		add_to_group(self_group)
	_bob_phase = randf() * TAU
	# Desync retarget ticks so a big swarm's scans spread across frames.
	_retarget_cd = randf() * RETARGET_INTERVAL

## Set a new movement goal (re-arms the reached hook).
func set_goal(to: Vector2) -> void:
	goal = to
	_goal_done = false

func _process(delta: float) -> void:
	if _dying:
		_death_t -= delta
		var p := clampf(_death_t / DEATH_TIME, 0.0, 1.0)
		scale = Vector2(p, p)
		modulate.a = p
		if _death_t <= 0.0:
			queue_free()
		return

	_bob_phase += bob_speed * delta
	_bob = sin(_bob_phase) * bob_amplitude
	_attack_cd = maxf(_attack_cd - delta * _effective_atk_rate_mult(), 0.0)
	_flash = maxf(_flash - delta, 0.0)
	_lunge = _lunge.move_toward(Vector2.ZERO, LUNGE_RETURN * delta)
	_stun_t = maxf(_stun_t - delta, 0.0)
	_slow_t = maxf(_slow_t - delta, 0.0)
	_confused_t = maxf(_confused_t - delta, 0.0)
	_dmg_boost_t = maxf(_dmg_boost_t - delta, 0.0)
	_speed_boost_t = maxf(_speed_boost_t - delta, 0.0)
	_atk_speed_boost_t = maxf(_atk_speed_boost_t - delta, 0.0)
	_xp_boost_t = maxf(_xp_boost_t - delta, 0.0)
	_status_flash_t = maxf(_status_flash_t - delta, 0.0)

	_retarget_cd -= delta
	if _retarget_cd <= 0.0:
		_retarget_cd = RETARGET_INTERVAL
		_acquire_target()
		if not separation_per_frame:
			_update_separation()
	# Heroes recompute separation every frame so the push tracks the current
	# overlap and can't overshoot into a bounce (see separation_per_frame).
	if separation_per_frame:
		_update_separation()

	if _target != null and (not is_instance_valid(_target) or _target._dying):
		_target = null

	if _stun_t > 0.0:
		pass  # Stunned: skip movement/attacks this frame.
	elif _target != null:
		_engage(delta)
	else:
		_advance_goal(delta)

	var facing_dir_x := (_target.global_position.x - global_position.x) if _target != null else _heading.x
	if absf(facing_dir_x) > 0.5:
		_facing_x = signf(facing_dir_x)

	if not is_pinned:
		if _separation != Vector2.ZERO:
			global_position += _separation.limit_length(SEPARATION_SPEED * delta)

		if _field != null:
			# Steering is only a hint — hard-clamp so units never clip obstacle cores.
			global_position = _field.clamp_out_of_obstacles(global_position, _collision_radius())
			global_position = _field.clamp_inside_field(global_position, _collision_radius())
			# Poison Lake: one damage instance per entry, not a continuous drain —
			# fire a single hit on the outside→inside transition, then stay quiet
			# until the unit fully exits and re-enters. Makes clipping a lake a
			# minor, avoidable cost instead of a death sentence for anything that
			# lingers.
			var was_in_lake := _in_lake
			_in_lake = _field.in_lake(global_position)
			if _in_lake and not was_in_lake:
				_take_hazard_damage(_field.lake_damage)

	queue_redraw()

func take_damage(amount: float, attacker: Combatant = null) -> void:
	if _dying:
		return
	if shield_charges > 0:
		shield_charges -= 1
		if flash_on_hit:
			_flash = FLASH_TIME
		return
	hp -= amount
	if flash_on_hit:
		_flash = FLASH_TIME
	_alerted = true  # a dormant villain wakes the instant it's struck (e.g. ranged poke)
	if hp <= 0.0:
		if attacker != null and is_instance_valid(attacker):
			attacker._on_kill(self)
		_die()

## Hazard damage (Poison Lake): steady HP drain — no hit flash, no killer credit.
func _take_hazard_damage(amount: float) -> void:
	if _dying:
		return
	hp -= amount
	if hp <= 0.0:
		_die()

## Subclass hook: called when this unit lands a killing blow.
func _on_kill(_victim: Combatant) -> void:
	pass

## Villain dormancy gate: true once a hero has entered villain_aggro_radius, or
## the unit has been hit (take_damage latches _alerted). Non-dormant units
## (villain_aggro_radius == 0) are always alerted. Latches — never goes back to
## sleep. Villains call this in _process to stay inert at their lair until the
## party closes in (fixed-lair reactive design).
func is_alerted() -> bool:
	if _alerted:
		return true
	if villain_aggro_radius <= 0.0:
		_alerted = true
		return true
	var r2 := villain_aggro_radius * villain_aggro_radius
	for h in get_tree().get_nodes_in_group("heroes"):
		if is_instance_valid(h) and not h._dying \
				and global_position.distance_squared_to(h.global_position) <= r2:
			_alerted = true
			return true
	return false

## Pauses this unit's movement/attacks for `duration` seconds (e.g. Thundaar's
## upgraded Stomp). Only extends the stun, never shortens an existing one.
func apply_stun(duration: float) -> void:
	if _dying:
		return
	_stun_t = maxf(_stun_t, duration)
	_status_flash_t = maxf(_status_flash_t, duration)
	_status_flash_color = STATUS_STUN_COLOR

## Scales this unit's effective move speed and attack rate by `factor` for
## `duration` seconds (e.g. Stage 3 Mech Robot's slow zone). Only extends the
## slow, never shortens or weakens an existing one already in effect.
func apply_slow(duration: float, factor: float) -> void:
	if _dying:
		return
	if _slow_t <= 0.0 or factor < _slow_factor:
		_slow_factor = factor
	_slow_t = maxf(_slow_t, duration)
	_status_flash_t = maxf(_status_flash_t, duration)
	_status_flash_color = STATUS_SLOW_COLOR

## Confuses this unit for `duration` seconds — it targets and attacks its own
## group instead of the enemy group (BEACON's Confuse ultimate; minions only).
## Extend-don't-stack, like apply_slow. Clears the current target so it re-picks
## a same-group victim next scan.
func apply_confusion(duration: float) -> void:
	if _dying:
		return
	_confused_t = maxf(_confused_t, duration)
	_target = null
	_status_flash_t = maxf(_status_flash_t, duration)
	_status_flash_color = STATUS_CONFUSE_COLOR

## The group this unit currently treats as its enemies — normally enemy_group,
## but its own self_group while confused so it turns on its neighbors. Used by
## both target acquisition and projectile spawning.
func _effective_enemy_group() -> String:
	return self_group if _confused_t > 0.0 else enemy_group

## 1.0 normally; the slow factor while _slow_t is active, combined with any
## active objective attack-speed boost. Multiplies attack cooldown decay.
func _effective_atk_rate_mult() -> float:
	var m := _slow_factor if _slow_t > 0.0 else 1.0
	if _atk_speed_boost_t > 0.0:
		m *= _atk_speed_boost_mult
	return m

## 1.0 normally; the slow factor while _slow_t is active, combined with any
## active objective speed boost. Multiplies move speed (via _engage/_advance_goal).
func _effective_move_mult() -> float:
	var m := _slow_factor if _slow_t > 0.0 else 1.0
	if _speed_boost_t > 0.0:
		m *= _speed_boost_mult
	return m

## Multiplies outgoing damage while an objective damage boost is active.
func damage_mult() -> float:
	return _dmg_boost_mult if _dmg_boost_t > 0.0 else 1.0

## Multiplies XP gained while an objective XP boost is active.
func xp_mult() -> float:
	return _xp_boost_mult if _xp_boost_t > 0.0 else 1.0

## Grants (or refreshes/strengthens) a temporary damage/speed/attack-speed/XP
## buff, e.g. an objective-completion reward. Mirrors apply_slow: only extends
## the duration and only strengthens the multiplier, never weakens it.
func apply_damage_boost(duration: float, mult: float) -> void:
	_dmg_boost_mult = mult if _dmg_boost_t <= 0.0 else maxf(_dmg_boost_mult, mult)
	_dmg_boost_t = maxf(_dmg_boost_t, duration)
	_status_flash_t = maxf(_status_flash_t, duration)
	_status_flash_color = STATUS_BUFF_COLOR

func apply_speed_boost(duration: float, mult: float) -> void:
	_speed_boost_mult = mult if _speed_boost_t <= 0.0 else maxf(_speed_boost_mult, mult)
	_speed_boost_t = maxf(_speed_boost_t, duration)
	_status_flash_t = maxf(_status_flash_t, duration)
	_status_flash_color = STATUS_BUFF_COLOR

func apply_atk_speed_boost(duration: float, mult: float) -> void:
	_atk_speed_boost_mult = mult if _atk_speed_boost_t <= 0.0 else maxf(_atk_speed_boost_mult, mult)
	_atk_speed_boost_t = maxf(_atk_speed_boost_t, duration)
	_status_flash_t = maxf(_status_flash_t, duration)
	_status_flash_color = STATUS_BUFF_COLOR

func apply_xp_boost(duration: float, mult: float) -> void:
	_xp_boost_mult = mult if _xp_boost_t <= 0.0 else maxf(_xp_boost_mult, mult)
	_xp_boost_t = maxf(_xp_boost_t, duration)
	_status_flash_t = maxf(_status_flash_t, duration)
	_status_flash_color = STATUS_BUFF_COLOR

## Absorbs the next `count` instances of damage entirely (e.g. objective reward shield).
func apply_shield(count: int) -> void:
	shield_charges += count
	_status_flash_t = maxf(_status_flash_t, STATUS_SHIELD_FLASH_TIME)
	_status_flash_color = STATUS_SHIELD_COLOR

## Shoves this unit back along `direction`, damaging any of its own group
## caught in the knockback's path (e.g. minions punting into other minions).
func apply_knockback(direction: Vector2, distance: float, splash_damage: float, source: Combatant) -> void:
	if _dying:
		return
	var from := global_position
	var to := from
	# Pinned structures (e.g. LaneSpawnPoint) skip displacement entirely — same
	# contract as the general per-frame clamp below in _process. Without this,
	# clamp_out_of_obstacles still ran on `to` even when distance was forced to
	# 0 by a caller, and a pinned point is registered as its OWN dynamic_obstacle
	# at that exact position, so the zero-distance self-collision fallback
	# shoved it body_radius*2 sideways for that one write — a one-frame
	# position pop that read as the sprite blinking a duplicate beside itself.
	if not is_pinned:
		to = from + direction * distance
		if _field != null:
			to = _field.clamp_out_of_obstacles(to, _collision_radius())
			to = _field.clamp_inside_field(to, _collision_radius())
		global_position = to
	if self_group == "":
		return
	for node in get_tree().get_nodes_in_group(self_group):
		if node == self or not is_instance_valid(node) or node._dying:
			continue
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(node.global_position, from, to)
		if node.global_position.distance_to(closest) <= body_radius + node.body_radius:
			node.take_damage(splash_damage, source)

func _die() -> void:
	if _dying:
		return
	_dying = true
	_death_t = DEATH_TIME
	if self_group != "":
		remove_from_group(self_group)
	_spawn_death_particles()
	died.emit(self)

## One-shot burst tinted to this unit's body color, added as a sibling so it
## keeps playing after this node's queue_free() at the end of the death fade.
func _spawn_death_particles() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var burst := CPUParticles2D.new()
	burst.global_position = global_position
	burst.emitting = false
	burst.one_shot = true
	burst.amount = 14
	burst.lifetime = 0.5
	burst.explosiveness = 1.0
	burst.direction = Vector2.UP
	burst.spread = 180.0
	burst.gravity = Vector2(0, 260)
	burst.initial_velocity_min = 60.0
	burst.initial_velocity_max = 140.0
	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 4.0
	burst.color = body_color
	parent.add_child(burst)
	burst.emitting = true
	var t := get_tree().create_timer(burst.lifetime + 0.1)
	t.timeout.connect(burst.queue_free)
	_spawn_ground_splash(parent)

## Fading blob left on the ground under a death burst, so the particles read
## as having splattered rather than just vanishing in midair.
func _spawn_ground_splash(parent: Node) -> void:
	var splash := Polygon2D.new()
	var pts := PackedVector2Array()
	var point_count := 10
	for i in point_count:
		var ang := TAU * float(i) / point_count
		var r := body_radius * randf_range(0.6, 1.1)
		pts.append(Vector2(cos(ang) * r, sin(ang) * r * 0.5))
	splash.polygon = pts
	splash.color = body_color
	splash.color.a = 0.55
	splash.global_position = global_position
	parent.add_child(splash)
	parent.move_child(splash, 0)
	var tw := splash.create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(splash, "modulate:a", 0.0, 0.8)
	tw.tween_callback(splash.queue_free)

## Scoring hook for _acquire_target: lower score = more preferred. The base
## Combatant scores purely by squared distance (nearest wins), which is exactly
## the old behavior — minions, guardians, the villain, and HeroClone all keep
## it. Hero overrides this to fold in focus-fire / execute / threat / role
## preferences among the candidates within detect_range.
func _target_score(_node: Combatant, dist_sq: float) -> float:
	return dist_sq

## Lane filter hook (Hero overrides this to restrict candidates to its own
## lane — see LaneField.clamp_to_lane doc). No-op for every other Combatant.
func _lane_ok(_node: Combatant) -> bool:
	return true

func _acquire_target() -> void:
	var best_target: Combatant = null
	# Squared distances: heroes scan the whole swarm, so skip per-candidate sqrt.
	var range_sq := detect_range * detect_range
	var best_score := INF
	var taunter: Combatant = null
	var taunter_best := INF
	# While confused, hunt own group instead of the enemy group (BEACON Confuse).
	var confused := _confused_t > 0.0
	for node in get_tree().get_nodes_in_group(_effective_enemy_group()):
		if node == self or not is_instance_valid(node) or node._dying or not _lane_ok(node):
			continue
		var dist := global_position.distance_squared_to(node.global_position)
		# Taunt only overrides targeting for enemies already within the
		# taunting unit's own taunt_radius; farther enemies are untouched.
		# Confused units ignore taunts — they're busy fighting their own kind.
		if not confused and node.is_taunting and dist <= node.taunt_radius * node.taunt_radius and dist < taunter_best:
			taunter_best = dist
			taunter = node
		if dist <= range_sq:
			var score := _target_score(node, dist)
			if score < best_score:
				best_score = score
				best_target = node
	_target = taunter if taunter != null else best_target

## Pushes overlapping same-group neighbors apart (e.g. a pile of minions
## crowding the same hero, or heroes bunched at deploy) so bodies don't stack.
## Cross-group overlap (melee contact) is left alone — that's expected.
func _update_separation() -> void:
	_separation = Vector2.ZERO
	if self_group == "":
		return
	# Only push apart while idle/repositioning — mid-fight overlap is expected
	# and acceptable (melee bodies naturally cluster on a target), and pushing
	# through it is what read as heroes shoving each other around in combat.
	if _target != null:
		return
	for node in get_tree().get_nodes_in_group(self_group):
		if node == self or not is_instance_valid(node) or node._dying:
			continue
		# Pinned units (LaneSpawnPoint, HeroClone) have no collision at all —
		# they don't push others around any more than they can be pushed.
		if "is_pinned" in node and node.is_pinned:
			continue
		var diff: Vector2 = global_position - node.global_position
		var min_dist: float = body_radius + node.body_radius + SEPARATION_MARGIN
		var d := diff.length()
		if d < 0.001:
			diff = Vector2.RIGHT.rotated(randf() * TAU)
			d = 0.001
		if d < min_dist:
			_separation += diff / d * (min_dist - d)

func _engage(delta: float) -> void:
	var to_target := _target.global_position - global_position
	var dist := to_target.length()
	# Pinned units (e.g. HeroClone) never approach or kite — is_pinned's contract
	# is "never moves" everywhere else in this file, but this was the one path
	# that missed the guard: a pinned unit with a target outside attack_range
	# would still chase it here, visibly drifting off its spawn point whenever
	# a minion wandered just out of reach.
	if is_pinned:
		pass
	elif dist > attack_range:
		global_position += _steer(to_target.normalized(), delta) * move_speed * _effective_move_mult() * delta
	elif is_ranged and not _target.is_pinned and dist < attack_range * RANGED_STANDOFF_FRACTION:
		# Kite: keep shooting (below) while backing off, rather than freezing
		# in place and letting the enemy close to melee range regardless.
		# Excludes pinned targets (e.g. LaneSpawnPoint, is_pinned=true, never
		# moves) — retreating from a target that can never close the gap back
		# just re-triggers the dist > attack_range approach every other cycle,
		# and steer_around's obstacle avoidance turns that oscillation into a
		# slow orbit around the structure instead of a stable stand-off.
		global_position += _steer(-to_target.normalized(), delta) * move_speed * _effective_move_mult() * delta
	if dist <= attack_range and _attack_cd <= 0.0:
		_lunge = to_target.normalized() * LUNGE_DIST
		var victim := _target
		_attack_cd = attack_interval
		if is_ranged and projectile_scene != null:
			_fire_projectile(victim)
		else:
			victim.take_damage(damage * damage_mult(), self)
			if knockback_chance > 0.0 and not victim._dying and randf() < knockback_chance:
				victim.apply_knockback(to_target.normalized(), knockback_distance, knockback_splash_damage, self)

func _fire_projectile(victim: Combatant) -> void:
	var proj: Projectile = projectile_scene.instantiate()
	proj.damage = damage * damage_mult()
	proj.attacker = self
	proj.target = victim
	proj.enemy_group = _effective_enemy_group()
	proj.speed = projectile_speed
	proj.max_range = projectile_range
	proj.color = body_color
	proj.global_position = global_position
	get_parent().add_child(proj)

func _advance_goal(delta: float) -> void:
	if _goal_done or goal == Vector2.INF or move_speed <= 0.0:
		return
	var to_goal := goal - global_position
	if to_goal.length() <= GOAL_REACHED_DIST:
		_goal_done = true
		_on_goal_reached()
		return
	global_position += _steer(to_goal.normalized(), delta) * move_speed * _effective_move_mult() * delta

## Desired direction adjusted to avoid the field's blocking obstacles, then
## eased against the previous heading so corrections read as smooth arcs
## instead of frame-to-frame jitter.
func _steer(desired: Vector2, delta: float) -> Vector2:
	if _field != null:
		desired = _field.steer_around(global_position, desired, _collision_radius() + 8.0)
	if desired.length() < 0.01:
		return desired
	if _heading == Vector2.ZERO:
		_heading = desired
	else:
		_heading = _heading.slerp(desired, clampf(delta * 10.0, 0.0, 1.0)).normalized()
	return _heading

func _draw() -> void:
	var offset := Vector2(0.0, -_bob) + _lunge
	# Units with sprite art carry their own paper-cutout backing baked into the
	# image, so only draw the plain circle+outline backing as a fallback for
	# units without sprite art (radius still matches body_radius for hit-testing).
	if sprite_texture == null:
		draw_circle(offset, body_radius, body_color)
		draw_arc(offset, body_radius, 0.0, TAU, 24, outline_color, outline_width, true)
	if sprite_texture != null:
		var diameter := body_radius * 2.0 * sprite_scale
		var tex_size := sprite_texture.get_size()
		var scale_factor := diameter / maxf(tex_size.x, tex_size.y)
		var draw_size := tex_size * scale_factor
		# Art faces left by default; turn in place on its own axis when facing right.
		draw_set_transform(offset, 0.0, Vector2(-_facing_x, 1.0))
		draw_texture_rect(sprite_texture, Rect2(-draw_size * 0.5, draw_size), false, Color(1.0, 1.0, 1.0, _sprite_alpha()))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _in_lake:
		draw_circle(offset, body_radius, Color(0.45, 0.85, 0.35, 0.3))
	if _flash > 0.0:
		draw_circle(offset, body_radius, Color(1.0, 1.0, 1.0, (_flash / FLASH_TIME) * 0.7))
	if _status_flash_t > 0.0:
		draw_arc(offset, body_radius + 5.0, 0.0, TAU, 24, _status_flash_color, 3.0, true)
	if hp < max_hp and not _dying:
		_draw_health_bar(offset)
	if label_text != "":
		var font := ThemeDB.fallback_font
		var fs := 15
		var tw := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, offset + Vector2(-tw * 0.5, -body_radius - 16.0), label_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, outline_color)

func _draw_health_bar(offset: Vector2) -> void:
	var w := body_radius * 2.0
	var h := 4.0
	var top_left := offset + Vector2(-w * 0.5, -body_radius - 10.0)
	var frac := clampf(hp / max_hp, 0.0, 1.0)
	draw_rect(Rect2(top_left, Vector2(w, h)), Color(0.0, 0.0, 0.0, 0.5), true)
	var fill := Color(0.8, 0.2, 0.2).lerp(Color(0.3, 0.8, 0.3), frac)
	draw_rect(Rect2(top_left, Vector2(w * frac, h)), fill, true)
