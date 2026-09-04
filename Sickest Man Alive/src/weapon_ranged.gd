class_name WeaponRanged
extends Node2D

## The syringe. Fires automatically at whatever direction the player is aiming.
## It reads one resolved AttackStats and never looks at the item list.

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/projectile.tscn")

var stats: AttackStats
var target_group: StringName = &"enemies"

## Where shots are born. Set by Player to the rig's syringe-tip Marker2D, so the
## needle visibly fires from the needle. Left null this falls back to the
## weapon's own position, which keeps the node usable without a rig.
var muzzle: Node2D

var _cooldown: float = 0.0


func set_stats(s: AttackStats) -> void:
	stats = s


func _physics_process(delta: float) -> void:
	_cooldown -= delta


## Called by the owner every frame with the current aim direction.
func try_fire(aim: Vector2) -> void:
	if stats == null or _cooldown > 0.0 or aim == Vector2.ZERO:
		return
	_cooldown = 1.0 / maxf(stats.attack_rate, 0.01)
	_fire(aim.normalized())


func _fire(aim: Vector2) -> void:
	var count := maxi(stats.shot_count, 1)
	# Odd counts put one shot dead centre; even counts straddle the aim line.
	var step := stats.spread_degrees
	var start := -step * (count - 1) * 0.5

	var origin := muzzle.global_position if muzzle != null else global_position

	for i in count:
		# Fixed fan first, then this shot's own error. Drawn per projectile, not
		# per volley, so a wide spread reads as a spraying weapon rather than as
		# a tight group that happens to be pointed somewhere else.
		var jitter := randf_range(-stats.spread_random, stats.spread_random) * 0.5
		var angle := deg_to_rad(start + step * i + jitter)
		var p := PROJECTILE_SCENE.instantiate() as Projectile
		# Every shot gets its own copy: a projectile that lives 1.2s must not
		# see the stat block change mid-flight when an item drops.
		p.setup(stats.duplicate_stats(), aim.rotated(angle), target_group)
		p.global_position = origin
		get_tree().current_scene.add_child(p)
