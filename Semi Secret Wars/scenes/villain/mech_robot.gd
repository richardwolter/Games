class_name MechRobot
extends Villain
## Stationary heavy-HP mech that fights back in melee if a hero gets close,
## and periodically drops a slow zone on the nearest hero (see slow_zone.gd)
## that saps movement/attack rate.
##
## Minion swarm (ranged + brute mix) comes from MinionSpawner via StageConfig,
## same as Dark Mage/Berserker; this class only owns the direct-fight + ability.

## How often (seconds) a slow zone is dropped on the nearest hero.
@export var zone_interval := 5.0
@export var zone_duration := 4.0
@export var zone_radius := 60.0
## Multiplier applied to move speed / attack rate while inside the zone.
@export var zone_slow_factor := 0.7

const SLOW_ZONE_SCRIPT := preload("res://scenes/villain/abilities/slow_zone.gd")

var _zone_cd := 0.0

func _configure() -> void:
	super()
	enemy_group = "heroes"
	_zone_cd = zone_interval

func _villain_process(delta: float) -> void:
	_zone_cd -= delta
	if _zone_cd <= 0.0:
		_zone_cd = zone_interval
		_spawn_slow_zone()

## Drops a slow zone centered on the nearest living hero (field-wide, like
## minion hunting) so the ability threatens even heroes not yet in melee.
func _spawn_slow_zone() -> void:
	var hero := _nearest_hero()
	if hero == null or get_parent() == null:
		return
	var zone := Node2D.new()
	zone.set_script(SLOW_ZONE_SCRIPT)
	zone.global_position = hero.global_position
	zone.radius = zone_radius
	zone.duration = zone_duration
	zone.slow_factor = zone_slow_factor
	get_parent().add_child(zone)
