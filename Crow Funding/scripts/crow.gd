@tool
extends Node2D
## A single crow character: pen-and-ink sprite parts, stats, balcony loitering, and fly out/back motion.

const TIER_NAMES: Array[String] = ["Newbie", "Apprentice", "Rookie", "Pro", "Master"]
# Cumulative XP required to REACH each tier (tier 0 costs 0 XP).
const XP_FOR_TIER: Array[int] = [0, 100, 250, 450, 700]

@export var crow_name := "Crow"
@export var scarf_color := Color(0.95, 0.72, 0.25)
@export var base_luck := 0.5
@export var facing := 1

var tier := 0
var xp := 0
var day_xp := 0
var day_objects := 0
var day_value := 0
var luck := 0.5
var status := "Resting"
var is_out := false
var perch := Vector2.ZERO
var carrying := false
var loitering := false

const BODY_TEX := preload("res://art/crows/crow_body.png")
const WING_TEX := preload("res://art/crows/crow_wing.png")
const SCARF_TEX := preload("res://art/crows/crow_scarf.png")
# From art/crows/crow_parts.json, in source pixels.
const WING_OFFSET := Vector2(146, 196)
const WING_PIVOT := Vector2(254, 29)
const SCARF_OFFSET := Vector2(361, 164)
const SPRITE_FEET := Vector2(330, 944)
const BEAK_TIP := Vector2(625, 112)
const SPRITE_HEIGHT := 46.0
# The old flat crow's belly sat ~11 px below its origin; the feet go there.
const FEET_Y := 11.0
const SPRITE_SCALE := SPRITE_HEIGHT / 944.0

var _tween: Tween
var _hop_tween: Tween
var _time := 0.0
var _wing_phase := 0.0
var _wing_speed := 0.0
var _flying := false
var _loiter_target := 0.0
var _loiter_timer := 0.0

func _ready() -> void:
	luck = base_luck
	# the sprite is drawn at ~5% of its source size; mipmaps keep the ink from shimmering
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	if _flying:
		_wing_phase += delta * _wing_speed
	elif loitering and not Engine.is_editor_hint():
		_loiter_step(delta)
	queue_redraw()

func set_loiter(enabled: bool) -> void:
	loitering = enabled
	if not enabled and _hop_tween != null and _hop_tween.is_valid():
		_hop_tween.kill()
		_hop_tween = null

func _loiter_step(delta: float) -> void:
	_loiter_timer -= delta
	if _loiter_timer <= 0.0:
		_loiter_timer = randf_range(1.2, 3.6)
		_loiter_target = randf_range(-48.0, 48.0)
		if randf() < 0.5:
			facing = -facing
		if randf() < 0.65 and _hop_tween == null:
			var p := position
			_hop_tween = create_tween()
			_hop_tween.tween_property(self, "position:y", p.y - 9.0, 0.18) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			_hop_tween.tween_property(self, "position:y", p.y, 0.22) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			_hop_tween.finished.connect(func() -> void: _hop_tween = null)
	position.x = move_toward(position.x, perch.x + _loiter_target, delta * 30.0)

func get_tier_name() -> String:
	return TIER_NAMES[tier]

func xp_floor() -> int:
	return XP_FOR_TIER[tier]

func xp_ceiling() -> int:
	if tier >= TIER_NAMES.size() - 1:
		return xp_floor() + 1
	return XP_FOR_TIER[tier + 1]

func grant_xp(amount: int) -> bool:
	xp += amount
	day_xp += amount
	var leveled := false
	while tier < TIER_NAMES.size() - 1 and xp >= XP_FOR_TIER[tier + 1]:
		tier += 1
		leveled = true
	luck = base_luck + tier * 0.1
	queue_redraw()
	return leveled

func begin_day() -> void:
	day_xp = 0
	day_objects = 0
	day_value = 0

func fly_out(target: Vector2, duration: float) -> Tween:
	is_out = true
	status = "Flying out"
	_start_flight(target, duration, 150.0, 13.0, func() -> void:
		status = "Out working"
	)
	return _tween

func fly_back(target: Vector2, duration: float) -> Tween:
	is_out = false
	status = "Returning"
	carrying = true
	_start_flight(target, duration, 46.0, 9.0, func() -> void:
		status = "Resting"
		carrying = false
		_flying = false
		queue_redraw()
	)
	return _tween

func _start_flight(target: Vector2, duration: float, arc: float, wing_speed: float, on_done: Callable) -> void:
	_flying = true
	_wing_speed = wing_speed
	if _tween and _tween.is_valid():
		_tween.kill()
	if _hop_tween != null and _hop_tween.is_valid():
		_hop_tween.kill()
		_hop_tween = null
	_tween = create_tween()
	var start := global_position
	_tween.tween_method(_flight_step.bind(start, target, arc), 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.finished.connect(on_done)

func _flight_step(t: float, start: Vector2, target: Vector2, arc: float) -> void:
	global_position = start.lerp(target, t) + Vector2(0, -sin(t * PI) * arc)

func _draw() -> void:
	var f := Vector2(float(facing), 1.0)
	var bob := 0.0
	if not _flying:
		bob = sin(_time * 2.0) * 1.3
	# Pen-and-ink parts cut from art/crows/crow.png (tools/split_crow.py). All
	# offsets are source pixels; SPRITE_SCALE maps them to world units, with the
	# origin at the feet so the crow stands on its perch.
	var root := Transform2D(0.0, f * SPRITE_SCALE, 0.0, Vector2(0, bob + FEET_Y)) * Transform2D(0.0, -SPRITE_FEET)
	draw_set_transform_matrix(root)
	draw_texture(BODY_TEX, Vector2.ZERO)
	# wing hinges at the shoulder and flaps while flying
	var wing_rot := 0.0
	if _flying:
		wing_rot = -absf(sin(_wing_phase)) * 0.9
	var shoulder := WING_OFFSET + WING_PIVOT
	draw_set_transform_matrix(root * Transform2D(wing_rot, shoulder) * Transform2D(0.0, -WING_PIVOT))
	draw_texture(WING_TEX, Vector2.ZERO)
	# scarf is drawn white and tinted per crow - the one spot colour
	draw_set_transform_matrix(root)
	draw_texture(SCARF_TEX, SCARF_OFFSET, scarf_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# carried loot (visible while returning home with a find)
	if carrying:
		draw_set_transform((BEAK_TIP - SPRITE_FEET) * SPRITE_SCALE * f + Vector2(0, bob + FEET_Y), 0.0, f)
		draw_circle(Vector2.ZERO, 2.6, Color(0.98, 0.83, 0.25))
		draw_set_transform(Vector2(0, 0), 0.0, Vector2.ONE)