class_name Berserker
extends Combatant
## Stage 2 villain: mobile, aggressive, high HP. Phases between charging and recovery.
##
## Berserker is the opposite of Dark Mage (stationary). He actively pursues the nearest
## hero with a charge/recovery cycle: charges 3s (pursues + attacks), then recovers 1.5s
## (stays put, can still attack). This creates rhythm to the fight and makes him a
## mechanical threat, not just a DPS check. Damage is high but attack interval is long.

@export var charge_duration := 3.0
@export var recover_duration := 1.5

## How often (seconds) the field-wide hunt goal is re-evaluated.
const HUNT_INTERVAL := 0.3

var _charge_phase := true
var _phase_timer := 0.0
var _hunt_cd := 0.0

func _configure() -> void:
	self_group = "hostiles"
	enemy_group = "heroes"
	add_to_group("villains")
	label_text = "BERSERKER"
	if _field != null:
		global_position = _field.villain_pos
	_phase_timer = charge_duration

func _process(delta: float) -> void:
	super(delta)
	if _dying:
		return

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

## Nearest living hero at any distance (hunting is field-wide, unlike detect).
func _nearest_hero() -> Combatant:
	var nearest: Combatant = null
	var best := INF
	for node in get_tree().get_nodes_in_group("heroes"):
		if not is_instance_valid(node) or node._dying:
			continue
		var dist := global_position.distance_squared_to(node.global_position)
		if dist < best:
			best = dist
			nearest = node
	return nearest
