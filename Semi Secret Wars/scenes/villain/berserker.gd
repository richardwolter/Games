class_name Berserker
extends Villain
## Mobile, aggressive, high HP. Phases between charging and recovery.
##
## Berserker is the opposite of Dark Mage (stationary). He actively pursues the nearest
## hero with a charge/recovery cycle: charges 3s (pursues + attacks), then recovers 1.5s
## (stays put, can still attack). This creates rhythm to the fight and makes him a
## mechanical threat, not just a DPS check. Damage is high but attack interval is long.

## Hand-drawn villain art (Designer, 2026-07-25), same papercut treatment as
## DarkMage1 — see Hero.HERO_SPRITES for the pipeline note.
const SPRITE := preload("res://assets/sprites/Berserk_Villain.png")

@export var charge_duration := 3.0
@export var recover_duration := 1.5

## How often (seconds) the field-wide hunt goal is re-evaluated.
const HUNT_INTERVAL := 0.3

var _charge_phase := true
var _phase_timer := 0.0
var _hunt_cd := 0.0

func _configure() -> void:
	super()
	enemy_group = "heroes"
	sprite_texture = SPRITE
	sprite_scale = 2.6
	# This art is drawn facing right, unlike every other unit in the game
	# (Designer, 2026-07-25) — see Combatant.sprite_faces_right.
	sprite_faces_right = true
	_phase_timer = charge_duration

func _villain_process(delta: float) -> void:
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		_charge_phase = not _charge_phase
		_phase_timer = charge_duration if _charge_phase else recover_duration
		if not _charge_phase:
			# Recovery: drop the hunt goal so _advance_goal doesn't keep him walking.
			goal = Vector2.INF

	# Field-wide hunt: with no hero in detect range, charge toward the nearest
	# living hero anyway (minions do the same) so he actually joins the battle.
	if _charge_phase and _target == null:
		_hunt_cd -= delta
		if _hunt_cd <= 0.0:
			_hunt_cd = HUNT_INTERVAL
			var hero := _nearest_hero()
			if hero != null:
				set_goal(hero.global_position)
			else:
				goal = Vector2.INF

## Override _engage to respect charge phases.
func _engage(delta: float) -> void:
	if not _charge_phase:
		# Recovery phase: can attack, but don't move toward target.
		var to_target := _target.global_position - global_position
		var dist := to_target.length()
		if dist <= attack_range and _attack_cd <= 0.0:
			_lunge = to_target.normalized() * LUNGE_DIST
			_target.take_damage(damage, self)
			_attack_cd = attack_interval
		return

	# Charge phase: normal engagement (move and attack).
	var to_target := _target.global_position - global_position
	var dist := to_target.length()
	if dist > attack_range:
		global_position += _steer(to_target.normalized(), delta) * move_speed * delta
	elif _attack_cd <= 0.0:
		_lunge = to_target.normalized() * LUNGE_DIST
		_target.take_damage(damage, self)
		_attack_cd = attack_interval
