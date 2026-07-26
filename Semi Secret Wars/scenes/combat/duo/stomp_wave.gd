class_name StompWave
extends Node2D
## THUNDAAR+BEACON Duo Ultimate ("Seismic Advance", see DuoUltimates/
## Hero.cast_duo_ultimate): marches in discrete steps, damaging + stunning
## everything within step_radius of each step point. Self-contained: frees
## itself once every step has landed and its flash has faded.
##
## The march direction is chosen at cast time by DuoAim (Designer, 2026-07-26)
## — it used to be hard-wired to lane-forward (+X), which meant the Ultimate
## stomped down an empty lane whenever the fight had drifted off that axis.
## With nothing worth aiming at, DuoAim still returns +X, so the old behavior
## is the floor rather than something that was replaced.

var caster: Hero = null
var step_count := 4
var step_interval := 0.35
var step_distance := 80.0
var step_radius := 90.0
var step_damage := 30.0
var step_stun := 0.8

## Locked in once, in _ready — NOT re-evaluated per step. A wave that re-aimed
## as it went would curve after whatever survived it, which reads as a homing
## effect rather than a shockwave travelling in a straight line.
var _dir := Vector2.RIGHT

var _steps_done := 0
var _step_cd := 0.0
var _flash_t := 0.0
const FLASH_TIME := 0.25
## EMBER, lifted — the same tunic orange Thundaar is drawn in.
const FLASH_COLOR := Color(0.90, 0.42, 0.18, 0.9)

## Per-step impact SFX (Designer, 2026-07-26). Clip, takes and the shout-region
## exclusion all live on Hero (SEISMIC_POUND_SOUND / seismic_pound_start) so the
## solo Stomp and this Ultimate can't drift apart.
##
## Shorter and quieter than the solo stomp's: several of these overlap in a
## sequence, so each needs to clear out of the way of the next and the stack
## must not pile up into a wall.
const STEP_POUND_DURATION := 0.55
const STEP_POUND_VOLUME_DB := -9.0

## global_position is assigned by the caster AFTER add_child (see
## Hero._cast_stomp_wave), so aiming has to happen here rather than in _ready —
## at _ready time this node is still sitting at the origin.
func _start() -> void:
	_dir = DuoAim.best_direction(caster, global_position, step_distance, step_count, step_radius)

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
	global_position += _dir * (step_distance if _steps_done > 0 else 0.0)
	_steps_done += 1
	_flash_t = FLASH_TIME
	# One pound per step, un-rate-limited: the marching rhythm IS this Ultimate,
	# so unlike Thundaar's solo Stomp (5s gap) every step is heard. Cut shorter
	# than the full take because steps land every step_interval (0.35s by
	# default) — at full length four of them would be ringing at once and the
	# sequence would smear into noise instead of reading as separate impacts.
	BattleSfx.play_clip(self, Hero.SEISMIC_POUND_SOUND, Hero.seismic_pound_start(),
			STEP_POUND_DURATION, STEP_POUND_VOLUME_DB)
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
const STOMP_BURST := preload("res://assets/sprites/Stomp_Circle_Color.png")

func _draw() -> void:
	if _flash_t > 0.0:
		var p := 1.0 - _flash_t / FLASH_TIME
		# Hero.STOMP_BURST_PAD — padding compensation for the colored art, kept
		# identical so both stomp VFX read at the same size.
		BattleFX.draw_burst(self, STOMP_BURST, Vector2.ZERO,
				step_radius * 2.0 * p * Hero.STOMP_BURST_PAD, 1.0 - p)
