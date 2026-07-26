class_name PlantTrail
extends Node2D
## THUNDAAR+WARDEN Duo Ultimate ("Verdant Path", see DuoUltimates/
## Hero.cast_duo_ultimate): lays plant_count plant markers lane-forward
## (+X — see StompWave doc) from the cast point, spaced plant_spacing apart.
## Every tick_interval seconds, any enemy within plant_radius of ANY plant
## takes tick_damage and gets ensnared (apply_stun) for ensnare_duration.
## Frees itself once trail_lifetime elapses.

var caster: Hero = null
var plant_count := 5
var plant_spacing := 60.0
var plant_radius := 50.0
var tick_damage := 6.0
var tick_interval := 1.0
var ensnare_duration := 1.0
var trail_lifetime := 8.0

## Local offsets from this node's own (fixed) global_position — computed once
## at spawn, so hit-testing/drawing never need a global<->local conversion.
var _plant_offsets: Array[Vector2] = []
var _tick_cd := 0.0
var _life_t := 0.0
var _flash_t := 0.0
const FLASH_TIME := 0.3
const FLASH_COLOR := Color(0.3, 0.8, 0.35, 0.85)
const PLANT_MARK_RADIUS := 10.0
const PLANT_MARK_COLOR := Color(0.35, 0.55, 0.25, 0.55)

## Cast SFX (Designer, 2026-07-25): the whole file, twice back to back.
const CAST_SOUND := preload("res://assets/Sounds/Verdant_Break.mp3")
const CAST_SOUND_PLAYS := 2

func _ready() -> void:
	BattleSfx.play_repeats(self, CAST_SOUND, CAST_SOUND_PLAYS)
	for i in plant_count:
		_plant_offsets.append(Vector2.RIGHT * plant_spacing * float(i))
	_life_t = trail_lifetime

func _process(delta: float) -> void:
	_flash_t = maxf(_flash_t - delta, 0.0)
	queue_redraw()
	_life_t -= delta
	if _life_t <= 0.0:
		queue_free()
		return
	_tick_cd -= delta
	if _tick_cd > 0.0:
		return
	_tick_cd = tick_interval
	_tick()

func _tick() -> void:
	if caster == null or not is_instance_valid(caster):
		return
	var dmg := tick_damage * caster._duo_damage_mult * caster.damage_mult()
	var hit := false
	for node in get_tree().get_nodes_in_group(caster.enemy_group):
		if not is_instance_valid(node) or node._dying or not caster._lane_ok(node):
			continue
		for offset in _plant_offsets:
			if node.global_position.distance_to(global_position + offset) <= plant_radius:
				hit = true
				node.take_damage(dmg, caster)
				if is_instance_valid(node) and not node._dying:
					node.apply_stun(ensnare_duration)
				break
	if hit:
		_flash_t = FLASH_TIME

## Hand-drawn plant art marking each node of the trail (Designer, 2026-07-25),
## replacing the plain filled circle the trail used as a placeholder.
const PLANT_ART := preload("res://assets/sprites/Verdant_Path_Color.png")
## draw_burst fits the whole texture; the colored art's drawing covers only
## 41% of its canvas where the original covered 87%. Same compensation idea as
## LaneField.ART_PAD_COMPENSATION — without it the plants would draw at less
## than half the size the Designer just sized them to.
const PLANT_ART_PAD := 2.14

func _draw() -> void:
	for offset in _plant_offsets:
		# The plant itself is persistent (full alpha); the tick pulse expands
		# over it to the real damage radius whenever the trail bites.
		# 2.6 -> 5.2 -> 7.8 across two Designer passes (2026-07-25). The second
		# pass also scaled the damage/ensnare radius by the same 1.5x (see
		# DuoUltimates "plant_radius"), so art and hitbox stay honest.
		BattleFX.draw_burst(self, PLANT_ART, offset,
				PLANT_MARK_RADIUS * 7.8 * PLANT_ART_PAD, 1.0)
		if _flash_t > 0.0:
			var p := 1.0 - _flash_t / FLASH_TIME
			BattleFX.draw_burst(self, PLANT_ART, offset,
					plant_radius * 2.0 * p * PLANT_ART_PAD, 1.0 - p)
