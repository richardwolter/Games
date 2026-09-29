@tool
extends Node2D
const Text = preload("res://scripts/text.gd")
## A single crow character: pen-and-ink sprite rigs (perched and flying), stats, balcony loitering, and fly out/back motion.

const TIER_NAMES: Array[String] = [Text.TIER_NEWBIE, Text.TIER_APPRENTICE, Text.TIER_ROOKIE, Text.TIER_PRO, Text.TIER_MASTER]
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
var status := Text.STATUS_RESTING
var is_out := false
var perch := Vector2.ZERO
var carrying := false
var loitering := false
# Care (scripts/care.gd): stamina drains on trips, an injury keeps the crow off
# trips until the First-aid box heals it. station is a care.gd Station value.
var stamina := 100.0
var injury_days := 0
var station := 0
var day_injured := false
var day_stamina_from := 100.0

const BODY_TEX := preload("res://art/crows/crow_body.png")
const WING_TEX := preload("res://art/crows/crow_wing.png")
const HEAD_TEX := preload("res://art/crows/crow_head.png")
const TAIL_TEX := preload("res://art/crows/crow_tail.png")
const SCARF_TEX := preload("res://art/crows/crow_scarf.png")
const FLY_BODY_TEX := preload("res://art/crows/fly_body.png")
const ARM_TEX := preload("res://art/crows/wing_arm.png")
const HAND_TEX := preload("res://art/crows/wing_hand.png")
# Perched rig, from art/crows/crow_parts.json (source pixels of crow.png).
const WING_OFFSET := Vector2(146, 196)
const WING_PIVOT := Vector2(254, 29)
const HEAD_OFFSET := Vector2(301, 0)
const HEAD_PIVOT := Vector2(139, 195)
const TAIL_OFFSET := Vector2(0, 587)
const TAIL_PIVOT := Vector2(165, 53)
const SCARF_OFFSET := Vector2(354, 157)
const SCARF_KNOT := Vector2(95, 55)
const SPRITE_FEET := Vector2(330, 944)
const BEAK_TIP := Vector2(625, 112)
# Flight rig (crow_parts.json "flight"): body plus a two-piece spread wing.
const FLY_ANCHOR := Vector2(430, 230)
const FLY_SHOULDER := Vector2(445, 140)
const FLY_SCARF := Vector2(705, 170)
const FLY_BEAK := Vector2(862, 105)
const ARM_PIVOT := Vector2(18, 83)
const ARM_WRIST := Vector2(338, 108)
const HAND_PIVOT := Vector2(18, 108)
const SPRITE_HEIGHT := 46.0
# The old flat crow's belly sat ~11 px below its origin; the feet go there.
const FEET_Y := 11.0
const SPRITE_SCALE := SPRITE_HEIGHT / 944.0
# Crows fly with steady, shallow "rowing" beats and rarely soar: the stroke runs
# from above the back to well below the belly, about 3.5 beats a second.
const WINGBEAT_HZ := 3.5
const STROKE_MID := deg_to_rad(-10.0)
const STROKE_AMP := deg_to_rad(52.0)
# The hand trails the arm and folds on the upstroke (the wrist flexes).
const HAND_LAG := 0.7
# One crow wing is about as long as the body; the cut wing needs scaling up to match.
const WING_SCALE := 1.55
# The generated flight body is chunkier than the perched crow; stretch it to the
# same long, lean build (Richard, 2026-09-26: flying crows looked fat and short).
const FLY_BODY_STRETCH := Vector2(1.25, 0.8)
# Which edge of the cut wing faces forward. -1 puts the fringed flight-feather
# edge on the inside (Richard, 2026-09-26: feathers were on the wrong edge).
const WING_CHORD_FLIP := -1.0
const HOP_TIME := 0.5
const HOP_HEIGHT := 9.0

var _tween: Tween
var _time := 0.0
var _wing_phase := 0.0
var _flying := false
var _flight_t := 0.0
# Trips go INTO the city: the crow shrinks with distance on the way out and fades
# as it drops among the rooftops, and comes back the same way in reverse.
const CITY_DEPTH := 0.22
var _depth_from := 1.0
var _depth_to := 1.0
var _loiter_target := 0.0
var _loiter_timer := 0.0
# perched idle: head snaps to a new look and holds, tail flicks, hops with a crouch
var _head_angle := 0.0
var _head_target := 0.0
var _head_timer := 0.0
var _tail_flick := 0.0
var _hop_t := -1.0
var _hop_from := 0.0

func _ready() -> void:
	luck = base_luck
	# the sprite is drawn at ~5% of its source size; mipmaps keep the ink from shimmering
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	if _flying:
		_wing_phase += delta * TAU * WINGBEAT_HZ
	elif not Engine.is_editor_hint():
		_idle_step(delta)
		if loitering:
			_loiter_step(delta)
	queue_redraw()

func set_loiter(enabled: bool) -> void:
	loitering = enabled
	if not enabled:
		_end_hop()

# Bird heads move in quick snaps and then hold still, so the head eases fast
# towards a target that changes every second or two; the tail gets a sharp flick
# now and then, the way crows pump their tails.
func _idle_step(delta: float) -> void:
	_head_timer -= delta
	if _head_timer <= 0.0:
		_head_timer = randf_range(0.6, 2.4)
		_head_target = deg_to_rad(randf_range(-9.0, 12.0))
		if randf() < 0.3:
			_tail_flick = 1.0
	_head_angle = lerpf(_head_angle, _head_target, 1.0 - exp(-delta * 18.0))
	_tail_flick = move_toward(_tail_flick, 0.0, delta * 4.0)
	if _hop_t >= 0.0:
		_hop_t += delta / HOP_TIME
		if _hop_t >= 1.0:
			_end_hop()
		else:
			position.y = _hop_from - _hop_lift(_hop_t)

# 0-0.25 crouch, 0.25-0.8 airborne, 0.8-1 land and absorb.
func _hop_lift(t: float) -> float:
	if t < 0.25 or t > 0.8:
		return 0.0
	return sin((t - 0.25) / 0.55 * PI) * HOP_HEIGHT

func _hop_squash(t: float) -> float:
	if t < 0.0:
		return 0.0
	if t < 0.25:
		return sin(t / 0.25 * PI) * 0.08
	if t > 0.8:
		return sin((t - 0.8) / 0.2 * PI) * 0.06
	return -0.05

func _end_hop() -> void:
	if _hop_t >= 0.0:
		position.y = _hop_from
	_hop_t = -1.0

func _loiter_step(delta: float) -> void:
	_loiter_timer -= delta
	if _loiter_timer <= 0.0:
		_loiter_timer = randf_range(1.2, 3.6)
		_loiter_target = randf_range(-48.0, 48.0)
		if randf() < 0.5:
			facing = -facing
		if randf() < 0.65 and _hop_t < 0.0:
			_hop_from = position.y
			_hop_t = 0.0
	# a hop carries the crow further along the rail than a walk
	var speed := 30.0 if _hop_t < 0.0 else 70.0
	position.x = move_toward(position.x, perch.x + _loiter_target, delta * speed)

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
	day_injured = false
	day_stamina_from = stamina
	day_xp = 0
	day_objects = 0
	day_value = 0

func fly_out(target: Vector2, duration: float) -> Tween:
	is_out = true
	status = Text.STATUS_FLYING_OUT
	_depth_from = 1.0
	_depth_to = CITY_DEPTH
	_start_flight(target, duration, 90.0, func() -> void:
		status = Text.STATUS_OUT
		visible = false
	)
	return _tween

func fly_back(target: Vector2, duration: float) -> Tween:
	is_out = false
	status = Text.STATUS_RETURNING
	carrying = true
	_depth_from = CITY_DEPTH
	_depth_to = 1.0
	visible = true
	_start_flight(target, duration, 90.0, func() -> void:
		status = Text.STATUS_RESTING
		carrying = false
		_flying = false
		scale = Vector2.ONE
		modulate.a = 1.0
		queue_redraw()
	)
	return _tween

func _start_flight(target: Vector2, duration: float, arc: float, on_done: Callable) -> void:
	_flying = true
	_end_hop()
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	var start := global_position
	if absf(target.x - start.x) > 4.0:
		facing = 1 if target.x > start.x else -1
	_tween.tween_method(_flight_step.bind(start, target, arc), 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.finished.connect(on_done)

func _flight_step(t: float, start: Vector2, target: Vector2, arc: float) -> void:
	_flight_t = t
	# climb off the rail first, then descend into the rooftops (or the reverse)
	global_position = start.lerp(target, t) + Vector2(0, -sin(t * PI) * arc)
	var depth := lerpf(_depth_from, _depth_to, smoothstep(0.0, 1.0, t))
	scale = Vector2(depth, depth)
	# out of sight while down among the buildings
	var into_city := t if _depth_to < _depth_from else 1.0 - t
	modulate.a = 1.0 - smoothstep(0.72, 1.0, into_city)

func _draw() -> void:
	if _flying:
		_draw_flying()
	else:
		_draw_perched()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# Pen-and-ink parts cut from art/crows/crow.png (tools/split_crow.py). Offsets are
# source pixels; SPRITE_SCALE maps them to world units, origin at the feet.
func _draw_perched() -> void:
	var f := Vector2(float(facing), 1.0)
	var breathe := sin(_time * 2.2) * 0.012
	var squash := _hop_squash(_hop_t)
	var sc := f * SPRITE_SCALE * Vector2(1.0 + squash * 0.6, 1.0 - squash + breathe)
	var root := Transform2D(0.0, sc, 0.0, Vector2(0, FEET_Y)) * Transform2D(0.0, -SPRITE_FEET)
	# tail flicks up about the rump
	var tail_rot := -_tail_flick * deg_to_rad(9.0)
	draw_set_transform_matrix(root * _pivot(TAIL_OFFSET, TAIL_PIVOT, tail_rot))
	draw_texture(TAIL_TEX, Vector2.ZERO)
	draw_set_transform_matrix(root)
	draw_texture(BODY_TEX, Vector2.ZERO)
	# wings lift a little off the back while hopping, for balance
	var wing_rot := 0.0
	if _hop_t >= 0.0:
		wing_rot = -sin(clampf(_hop_t, 0.0, 1.0) * PI) * 0.35
	draw_set_transform_matrix(root * _pivot(WING_OFFSET, WING_PIVOT, wing_rot))
	draw_texture(WING_TEX, Vector2.ZERO)
	var head_xf := root * _pivot(HEAD_OFFSET, HEAD_PIVOT, _head_angle)
	draw_set_transform_matrix(head_xf)
	draw_texture(HEAD_TEX, Vector2.ZERO)
	# scarf is drawn white and tinted per crow - the one spot colour
	draw_set_transform_matrix(root * _pivot(SCARF_OFFSET, SCARF_KNOT, _head_angle * 0.4))
	draw_texture(SCARF_TEX, Vector2.ZERO, scarf_color)
	if carrying:
		draw_set_transform(head_xf * (BEAK_TIP - HEAD_OFFSET), 0.0, Vector2.ONE)
		draw_circle(Vector2.ZERO, 2.6, Color(0.98, 0.83, 0.25))

# Side view of a flapping wing: the span swings through the stroke plane, so on
# screen the wing shows as its length times sin(stroke angle) - long above the
# back at the top of the upstroke, edge-on as it passes level, long below the
# belly at the bottom of the downstroke.
func _draw_flying() -> void:
	var f := Vector2(float(facing), 1.0)
	var stroke := STROKE_MID + STROKE_AMP * sin(_wing_phase)
	var hand_stroke := STROKE_MID + STROKE_AMP * 1.1 * sin(_wing_phase - HAND_LAG)
	# flare on landing: body pitches up and the wings hold high to brake
	var flare := 0.0 if is_out else smoothstep(0.82, 1.0, _flight_t)
	stroke = lerpf(stroke, deg_to_rad(30.0), flare)
	hand_stroke = lerpf(hand_stroke, deg_to_rad(35.0), flare)
	var pitch := (-deg_to_rad(4.0) - flare * deg_to_rad(24.0)) * f.x
	# the body rises on each downstroke
	var lift := cos(_wing_phase) * 1.2
	var root := Transform2D(pitch, f * SPRITE_SCALE * FLY_BODY_STRETCH, 0.0, Vector2(0, -20.0 + lift)) * Transform2D(0.0, -FLY_ANCHOR)
	# far wing first, behind the body, darker and a touch further back
	_draw_wing(root * Transform2D(0.0, Vector2(-40, -20)) * _unstretch(), stroke, hand_stroke, Color(0.55, 0.55, 0.58))
	draw_set_transform_matrix(root)
	draw_texture(FLY_BODY_TEX, Vector2.ZERO)
	# scarf streams back from the throat
	draw_set_transform_matrix(root * _pivot(FLY_SCARF - SCARF_KNOT, SCARF_KNOT, 1.0 + sin(_time * 9.0) * 0.12))
	draw_texture(SCARF_TEX, Vector2.ZERO, scarf_color)
	_draw_wing(root * _unstretch(), stroke, hand_stroke, Color.WHITE)
	if carrying:
		draw_set_transform(root * FLY_BEAK, 0.0, Vector2.ONE)
		draw_circle(Vector2.ZERO, 2.6, Color(0.98, 0.83, 0.25))

func _draw_wing(root: Transform2D, stroke: float, hand_stroke: float, tint: Color) -> void:
	var arm_len := _projected(stroke)
	# the wrist flexes on the way up, so the hand shows shorter then
	var folding := 0.65 if cos(_wing_phase - HAND_LAG) > 0.0 else 1.0
	var hand_len := _projected(hand_stroke) * folding
	var arm_local := Transform2D(_wing_dir(arm_len), Vector2(absf(arm_len), _chord(arm_len)) * WING_SCALE, 0.0, FLY_SHOULDER) * Transform2D(0.0, -ARM_PIVOT)
	draw_set_transform_matrix(root * arm_local)
	draw_texture(ARM_TEX, Vector2.ZERO, tint)
	var wrist := arm_local * ARM_WRIST
	var hand_local := Transform2D(_wing_dir(hand_len) + 0.15 * signf(hand_len), Vector2(absf(hand_len), _chord(hand_len)) * WING_SCALE, 0.0, wrist) * Transform2D(0.0, -HAND_PIVOT)
	draw_set_transform_matrix(root * hand_local)
	draw_texture(HAND_TEX, Vector2.ZERO, tint)

# The wing points up-and-back on the upstroke and down-and-back on the downstroke,
# never forward: the span always trails the shoulder a little.
func _wing_dir(projected: float) -> float:
	return -PI * 0.5 - 0.35 if projected > 0.0 else PI * 0.5 + 0.35

# Mirror across the span on the upstroke so the same edge stays at the front
# on both strokes; WING_CHORD_FLIP picks which edge that is.
func _chord(projected: float) -> float:
	return (-1.0 if projected > 0.0 else 1.0) * WING_CHORD_FLIP

# Wing transforms are built in body pixels; this cancels the body stretch around
# the shoulder so the wing keeps its own proportions.
func _unstretch() -> Transform2D:
	var inv := Vector2(1.0 / FLY_BODY_STRETCH.x, 1.0 / FLY_BODY_STRETCH.y)
	return Transform2D(0.0, FLY_SHOULDER) * Transform2D(0.0, inv, 0.0, Vector2.ZERO) * Transform2D(0.0, -FLY_SHOULDER)

# Keeps a sliver of wing visible edge-on instead of collapsing to nothing.
func _projected(angle: float) -> float:
	var s := sin(angle)
	if absf(s) < 0.12:
		return 0.12 if s >= 0.0 else -0.12
	return s

func _pivot(offset: Vector2, pivot: Vector2, angle: float) -> Transform2D:
	return Transform2D(angle, offset + pivot) * Transform2D(0.0, -pivot)
