class_name Projectile
extends Node2D
## Fired by ranged Combatants (see Combatant.is_ranged). Aimed at the target's
## position at cast time, but travels in a straight line and can connect with
## any live enemy it touches along the way (the original target moving out of
## the path is a miss, not a magic homing correction). If nothing is hit
## within max_range, it vanishes without dealing damage.

const HIT_SOUND := preload("res://assets/Sounds/Arrow Hit.wav")
## The source file has 0.418s of blank lead-in; skip straight past it rather
## than re-encoding the asset.
const HIT_SOUND_START := 0.425

var damage := 0.0
var attacker: Combatant = null
var target: Combatant = null
var enemy_group := ""
var speed := 500.0
var max_range := 600.0
var color := Color.WHITE
## Optional sprite art (e.g. Artemis.s arrow, Warden.s plant) — null keeps the
## plain line+circle placeholder below (Dark Mage.s bolt and anything else that
## doesn.t set this). Drawn at its own native aspect ratio scaled to
## `sprite_length` along its longest edge, never stretched to a fixed box.
var sprite_texture: Texture2D = null
## Per-shot art size, overriding SPRITE_LENGTH. Different art wants different
## sizes at the same range — Artemis.s arrow is a thin dart, Warden.s plant is
## a squat blob, and one shared constant made whichever came second look wrong
## (Designer, 2026-07-25: make it proportional like the arrow). 0 = use the
## SPRITE_LENGTH default.
var sprite_length := 0.0
## Extra draw-only rotation for the art, in radians. The node itself always
## points along travel (+X local), which assumes art drawn pointing RIGHT.
## Art drawn pointing UP (the Berserk minion's droplet spray) needs +PI/2 so
## it sprays along the shot instead of sideways (Designer, 2026-07-25).
var sprite_rotation_offset := 0.0
## Optional ensnare-on-hit (ARTEMIS+WARDEN Duo Ultimate's roaming clones —
## see HeroClone.ensnare_on_hit / Combatant._configure_projectile): applies
## apply_stun for this many seconds to whatever the shot lands on. 0 = no
## extra effect (every other ranged attack in the game).
var on_hit_stun := 0.0

const RADIUS := 4.0
const LENGTH := 14.0
const HIT_MARGIN := 6.0
## Default sprite size along the longest edge (world units) — the other axis
## follows from the texture.s own aspect ratio, so a wide sprite doesn.t get
## squashed into a fixed box. Overridable per shot via `sprite_length`.
const SPRITE_LENGTH := 32.0

var _dir := Vector2.RIGHT
var _traveled := 0.0
var _field: LaneField = null

func _ready() -> void:
	_field = get_tree().get_first_node_in_group("field")
	var aim_point := global_position + Vector2.RIGHT
	if target != null and is_instance_valid(target):
		aim_point = target.global_position
	_dir = (aim_point - global_position)
	if _dir.length() < 0.01:
		_dir = Vector2.RIGHT
	else:
		_dir = _dir.normalized()
	rotation = _dir.angle()

func _process(delta: float) -> void:
	var step := speed * delta
	global_position += _dir * step
	_traveled += step
	var victim := _find_hit()
	if victim != null:
		if attacker != null and is_instance_valid(attacker):
			victim.take_damage(damage, attacker)
			if on_hit_stun > 0.0 and is_instance_valid(victim) and not victim._dying:
				victim.apply_stun(on_hit_stun)
			_play_hit_sound()
		queue_free()
		return
	# Scenery/obstacles are cover (Designer, 2026-07-28): a shot that runs into
	# a rock, boulder or spawn-point gate dies there, silently and without
	# damage — it reads as a miss, so no hit SFX. Checked after the enemy test
	# so a unit standing flush against a rock is still hittable.
	if _field != null and _field.blocks_projectile(global_position):
		queue_free()
		return
	if _traveled >= max_range:
		queue_free()

## One-shot SFX outlives this projectile (which frees itself immediately
## after), so it's parented to the tree root instead of self and cleans
## itself up on finished — see BattleManager's music loop_mode bug writeup
## for why we don't touch loop_mode/loop_end here: this is non-looping.
func _play_hit_sound() -> void:
	var player := AudioStreamPlayer.new()
	player.stream = HIT_SOUND
	player.bus = AudioSettings.BUS_SFX
	# Same root-persists-across-pause bug as Hero._on_died — see its doc.
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(player)
	player.play(HIT_SOUND_START)
	player.finished.connect(player.queue_free)

func _find_hit() -> Combatant:
	if enemy_group == "":
		return null
	for node in get_tree().get_nodes_in_group(enemy_group):
		if not is_instance_valid(node) or node._dying:
			continue
		if global_position.distance_to(node.global_position) <= node.body_radius + HIT_MARGIN:
			return node
	return null

func _draw() -> void:
	if sprite_texture != null:
		var tex_size := sprite_texture.get_size()
		var target: float = sprite_length if sprite_length > 0.0 else SPRITE_LENGTH
		var scale_factor: float = target / maxf(tex_size.x, tex_size.y)
		var draw_size := tex_size * scale_factor
		if sprite_rotation_offset != 0.0:
			draw_set_transform(Vector2.ZERO, sprite_rotation_offset, Vector2.ONE)
		draw_texture_rect(sprite_texture, Rect2(-draw_size * 0.5, draw_size), false)
		if sprite_rotation_offset != 0.0:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	draw_line(Vector2(-LENGTH * 0.5, 0.0), Vector2(LENGTH * 0.5, 0.0), color, RADIUS)
	draw_circle(Vector2(LENGTH * 0.5, 0.0), RADIUS, color)
