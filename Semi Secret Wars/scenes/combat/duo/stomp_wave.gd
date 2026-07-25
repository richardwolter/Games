class_name StompWave
extends Node2D
## THUNDAAR+BEACON Duo Ultimate ("Seismic Advance", see DuoUltimates/
## Hero.cast_duo_ultimate): marches lane-forward (+X, the established deploy
## -> villain direction — see BattleManager/DeployController leader-in-front
## convention) in discrete steps, damaging + stunning everything within
## step_radius of each step point. Self-contained: frees itself once every
## step has landed and its flash has faded.

var caster: Hero = null
var step_count := 4
var step_interval := 0.35
var step_distance := 80.0
var step_radius := 90.0
var step_damage := 30.0
var step_stun := 0.8

var _steps_done := 0
var _step_cd := 0.0
var _flash_t := 0.0
const FLASH_TIME := 0.25
const FLASH_COLOR := Color(1.0, 0.55, 0.2, 0.9)

func _process(delta: float) -> void:
	_flash_t = maxf(_flash_t - delta, 0.0)
	queue_redraw()
	if _steps_done >= step_count:
		if _flash_t <= 0.0:
			queue_free()
		return
	_step_cd -= delta
	if _step_cd > 0.0:
		return
	_step_cd = step_interval
	_land_step()

## The first step lands right where the Ultimate was cast (0 * step_distance
## offset); each subsequent call advances global_position further forward.
func _land_step() -> void:
	global_position += Vector2.RIGHT * (step_distance if _steps_done > 0 else 0.0)
	_steps_done += 1
	_flash_t = FLASH_TIME
	if caster == null or not is_instance_valid(caster):
		return
	var dmg := step_damage * caster._duo_damage_mult * caster.damage_mult()
	for node in get_tree().get_nodes_in_group(caster.enemy_group):
		if not is_instance_valid(node) or node._dying or not caster._lane_ok(node):
			continue
		if global_position.distance_to(node.global_position) <= step_radius:
			node.take_damage(dmg, caster)
			if is_instance_valid(node) and not node._dying:
				node.apply_stun(step_stun)

## Hand-drawn stomp burst art, shared with THUNDAAR.s own Stomp (Designer,
## 2026-07-25) — this Ultimate IS a march of stomps, so it reads as the same
## impact repeated rather than a different effect.
const STOMP_BURST := preload("res://assets/sprites/Stomp_Circle.png")

func _draw() -> void:
	if _flash_t > 0.0:
		var p := 1.0 - _flash_t / FLASH_TIME
		BattleFX.draw_burst(self, STOMP_BURST, Vector2.ZERO, step_radius * 2.0 * p, 1.0 - p)
