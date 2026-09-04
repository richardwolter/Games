class_name LaneSpawnPoint
extends Combatant
## A destructible minion spawn point on the lane (a core mechanic).
##
## Extends Combatant purely to inherit HP, damage intake, the health bar, the
## `died` signal, and — by joining the "hostiles" group heroes target — automatic
## hero-targetability. It is a STATIC STRUCTURE: no movement, no attacks, no
## separation drift. LaneSpawner instantiates one per authored spawn point and
## permanently retires it (stops its waves) when it dies.

var _spawn_at := Vector2.ZERO
## Lane ("top"/"bottom") this gate belongs to — set by LaneSpawner right after
## creation (see LevelLayout.spawn_point_lanes). Read by Hero._nearest_spawn_point
## so heroes commit to their own lane's gates.
var lane := ""

## HP this gate can never be damaged below (0 = destructible, every normal
## level). The TUTORIAL sets it: level 0 is a scripted loss (Designer,
## 2026-07-31: "they must not succeed at any circumstance"), and an escalating
## swarm alone doesn't guarantee that — a well-timed Ultimate can burst a gate
## down before the swarm has grown. Floored, the gate visibly takes damage and
## its bar drains toward the last sliver, so the Duo reads as *nearly* strong
## enough, which is the exact feeling the beat after it needs.
##
## See LaneSpawner.TUTORIAL_GATE_FLOOR for the value.
var hp_floor := 0.0

## Called by LaneSpawner before add_child(), like Minion.setup().
func setup(pos: Vector2, hp: float) -> void:
	_spawn_at = pos
	max_hp = hp

## Clamps incoming damage to what the floor allows before the base class can
## apply it — Combatant.take_damage calls _die() the moment hp hits 0, so the
## clamp cannot be done after the fact.
func take_damage(amount: float, attacker: Combatant = null) -> void:
	if hp_floor > 0.0:
		amount = minf(amount, maxf(hp - hp_floor, 0.0))
	super(amount, attacker)

func _configure() -> void:
	# "hostiles" so heroes (enemy_group == "hostiles") target and attack it.
	self_group = "hostiles"
	enemy_group = ""
	add_to_group("spawn_points")
	label_text = "SPAWN GATE"
	global_position = _spawn_at
	# Code-driven visuals (no .tscn — LaneSpawner instantiates via .new()).
	body_radius = 44.0
	body_color = Color(0.60, 0.35, 0.65)
	sprite_texture = preload("res://assets/sprites/Portal-Spawn_Color.png")
	# 2.0 x1.56 padding compensation for the colored art (2026-07-25).
	sprite_scale = 3.11
	# Static structure — no idle bob (Combatant's default sine-wave sprite offset),
	# no hit-flash (reads as flicker against the portal art, not a hit reaction),
	# and pinned (skips separation/obstacle-clamp, which would otherwise shove it
	# off _spawn_at every frame via its own self-registered dynamic_obstacle entry
	# at distance 0 — see is_pinned doc in combatant.gd).
	bob_amplitude = 0.0
	flash_on_hit = false
	is_pinned = true
	# Gate death should read as a structure blowing up, not a minion popping —
	# bigger burst plus debris shards/portal-art chunks/flash ring (see
	# scripts/battle_fx.gd BattleFX.debris_burst).
	death_fx_scale = 2.5
	death_debris = true
	# Inert structure: never moves, never attacks, never detects.
	move_speed = 0.0
	damage = 0.0
	detect_range = 0.0
	attack_range = 0.0
	goal = Vector2.INF

## A gate never drifts — override the group-separation push (which would
## otherwise shove it around as minions crowd it) to a no-op.
func _update_separation() -> void:
	_separation = Vector2.ZERO

## Belt-and-suspenders position pin. LaneSpawner registers this point as a
## dynamic_obstacle at its own position (so heroes/minions steer around it),
## but Combatant._process()'s hard clamp (clamp_out_of_obstacles) then runs
## for EVERY unit including this one — checking itself against its own
## registered obstacle entry at distance 0. The zero-distance fallback shoves
## it a full `body_radius*2` away (Vector2.RIGHT) on the very first tick,
## silently drifting the visible/attackable gate off the position obstacle
## avoidance still protects, so heroes/minions end up walking straight through
## where the gate visually is. Force position back to the authored spot every
## frame so this (and any other future clamp/knockback edge case) can't drift it.
func _process(delta: float) -> void:
	super(delta)
	global_position = _spawn_at

