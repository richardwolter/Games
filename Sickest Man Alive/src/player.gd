class_name Player
extends CharacterBody2D

## The kid in the suit. Owns the Loadout, holds both weapons, and does nothing
## clever: every number it uses comes from a resolved stat block.

signal health_changed(current: int, maximum: int)
## Fired only on an actual hit landing. Separate from health_changed, which also
## fires when an item raises the maximum and nothing has hurt him at all.
signal damaged
signal died

const BASE_RADIUS: float = 14.0
const IFRAME_TIME: float = 0.6

## --- Dash -----------------------------------------------------------------
## A short, fast, invulnerable slide in the direction he is already committed
## to. Not a teleport: he travels the whole line, so it can be read and reacted
## to by the player being dashed past.
const DASH_SPEED: float = 900.0
const DASH_TIME: float = 0.18
## Measured from the START of the dash, so the number is "how often can I dash"
## rather than "how long after it ends".
const DASH_COOLDOWN: float = 0.7
## Invulnerability runs a hair past the movement, so arriving inside a swarm on
## the last frame is not an instant hit for having got there.
const DASH_IFRAME_PAD: float = 0.08
## Seconds between smudges. Short enough that the ghosts overlap into a streak
## rather than reading as separate copies of the kid.
const DASH_GHOST_INTERVAL: float = 0.028
## How long one smudge takes to fade out. Deliberately shorter than the dash, so
## the tail is always behind him and the trail never outlives the move by much.
const DASH_GHOST_FADE: float = 0.16
const DASH_GHOST_ALPHA: float = 0.45
const DASH_GHOST_TINT: Color = Color(0.55, 0.85, 1.0)

## Speed multiplier per attached mold clump, compounding. Two clumps leave him
## at 0.49, three at 0.34 -- slow enough to be a problem, never a stop.
const MOLD_SLOW_PER_CLUMP: float = 0.7

## The white hit blink, in RENDERED frames. One frame is the ask, and it has to
## be counted in frames rather than seconds -- 1/60th of a second as a timer is
## a coin flip over whether any frame ever samples it as on.
const HIT_FLASH_FRAMES: int = 1

## Speed above which the walk cycle plays instead of the idle sway. Well below
## any real input speed, so it only filters out knockback drift and the tail of
## a slide.
const WALK_SPEED_THRESHOLD: float = 12.0

## How fast the scalpel arm returns to guard after a swing.
const MELEE_RETURN_SPEED: float = 9.0

## Breathing room after a jam ends before another can land. See jam().
const JAM_GRACE: float = 0.45

## Resting angle for the gun arm, and how fast it drops back to it.
##
## The syringe no longer fires on its own: the player has to be actively aiming,
## which is the aim stick pushed or the fire button held. With nothing asked of
## it the arm hangs at his side like the scalpel does, so "am I shooting?" is
## answerable from the silhouette alone.
##
## Negative where the melee guard is positive: this arm is on his other side,
## and each one rests out towards the side it already lives on.
const RANGED_GUARD_ANGLE: float = -0.15
const RANGED_RETURN_SPEED: float = 8.0
## Whether the syringe is mirrored while resting, stated outright for the same
## reason MELEE_GUARD_FLIP is -- at rest the weapon sits near the sign boundary
## of the left/right test, where a hundredth of a radian would flip it.
const RANGED_GUARD_FLIP: bool = false

## Arm rotation at rest for the scalpel arm. Small and positive: positive swings
## it out to screen-left, the side that arm is already on, so it stays clear of
## the body. The blade is lifted by how it is MOUNTED, not by raising the arm --
## the arm is nearly half his height, so any angle big enough to raise the blade
## throws his hand right out to the side.
const MELEE_GUARD_ANGLE: float = 0.15

## Whether the scalpel is mirrored while at guard, so its cutting edge faces AWAY
## from the kid instead of at his own ribs. The art has its edge on the underside,
## which points inward once the blade is stood upright.
##
## Stated outright rather than derived from the blade's angle: at guard the blade
## is near vertical, which is exactly where the left/right test sits on its own
## sign boundary, so a few hundredths of a radian either way would silently turn
## the knife around.
const MELEE_GUARD_FLIP: bool = true

## Turning to face where he is running, WITHOUT mirroring the sprite. The kid is
## drawn front-on and stays that way: his left arm stays on the left, his right
## on the right, and only the head and body slide across to sell the turn.
##
## Deliberately translation only, never rotation. Rotating the rig root or the
## torso would rotate the arms with them, and both arms carry absolute world
## angles -- the gun arm tracks the cursor -- so every shot would land off by
## whatever the body was leaning at.
## --- body motion ---
## Bob, squash and sway, driven off one phase so they cannot drift apart.
##
## All three go on the RIG ROOT and nothing else. The torso is off limits: it
## carries both arms, and both arms hold absolute world angles. The root works
## because every angle read out of it is compensated in _aim_rotation.
##
## Rate is in radians per second of phase. Running is a gait -- two footfalls per
## cycle -- so the squash runs at double the bob's frequency.
const BOB_IDLE_RATE: float = 2.2
const BOB_RUN_RATE: float = 11.5
const BOB_IDLE_HEIGHT: float = 1.1   ## player-space pixels
const BOB_RUN_HEIGHT: float = 4.2
## Squash as a fraction: 0.05 means 5% shorter and 5% wider at the bottom of the
## step. Kept small on purpose -- the rig root also carries the mirror, and a
## root whose axes have different magnitudes SHEARS its rotated children, which
## the gun arm would show as a barrel that bends as he breathes.
const BOB_IDLE_SQUASH: float = 0.018
const BOB_RUN_SQUASH: float = 0.055
## Sway is the side-to-side rock; lean is the constant tilt into a run.
const BOB_IDLE_SWAY: float = 0.018   ## radians
const BOB_RUN_SWAY: float = 0.045
const RUN_LEAN: float = 0.075

## How far a resting arm swings with the gait, in radians, at a full run.
##
## Only ever added to an arm's GUARD angle -- an arm that is aiming or swinging
## has a job, and a gait wobble on top of it would put shots and blade arcs off
## by whatever the legs happened to be doing. Each arm takes the opposite sign
## from the leg on its own side, which is what a run looks like from the front:
## the limbs trade places rather than all rising together.
const ARM_RUN_SWING: float = 0.17

## --- death -----------------------------------------------------------------
## He goes down face first and carries whatever he was doing into the floor.
## The whole point is that the run ends with a piece of motion rather than with
## a sprite switching off: how far he slides is how fast he was going, and his
## face deforms by how hard he is still travelling when it is against the floor.
##
## Nothing here is an AnimationPlayer clip, for the same reason the bob is not:
## the numbers all key off live velocity, and a canned clip cannot know whether
## he was sprinting or standing still when it killed him.
const DEATH_FALL_TIME: float = 0.26
## Friction on the slide. Low enough that a full sprint carries a good body
## length, high enough that a standing death is a flop and not a glide.
const DEATH_FRICTION: float = 520.0
## The knockback from the killing blow counts double: it is the hit that put him
## down, and it should be visible in which way he goes.
const DEATH_KNOCK_WEIGHT: float = 1.4
## How flat he ends up. Prone and seen from this camera is mostly foreshortening.
const DEATH_SQUASH_Y: float = 0.34
const DEATH_SPREAD_X: float = 1.18
## How far the rig drops as he lands, in player-space pixels.
const DEATH_DROP: float = 11.0
## Tilt of the whole body as it lands, into the direction of travel.
const DEATH_TILT: float = 0.26
## Speed at which the face is fully smushed. Above this it does not get worse.
const DEATH_SMUSH_SPEED: float = 320.0
## Head deformation at full smush: flattened this much, spread wider by most of
## it, and dragged this far back along the slide, in the head's own source px.
const DEATH_SMUSH_FLATTEN: float = 0.46
const DEATH_SMUSH_SPREAD: float = 0.38
const DEATH_SMUSH_DRAG: float = 22.0
## Arms and legs sprawl. Absolute local angles, mirrored with the rig.
const DEATH_ARM_SPRAWL: float = 1.95
const DEATH_LEG_SPLAY: float = 0.4
## Blood. The smear is laid down while he is still moving, one dab per interval,
## and the pool is what spreads out from where he stops.
const DEATH_BLOOD: Color = Color(0.55, 0.04, 0.06)
const DEATH_SMEAR_INTERVAL: float = 0.035
const DEATH_SMEAR_SPEED: float = 45.0
const DEATH_POOL_SIZE: float = 30.0

const BODY_TURN_SHIFT: float = 3.2   ## rig root, in player-space pixels
const HEAD_TURN_SHIFT: float = 30.0  ## head, in source pixels (~0.105 scale)
const TURN_SPEED: float = 7.0

## Arm Mutation's grafted arms are deliberately worse than the one he was born
## with: same syringe, fired slower, weaker, and aimed by something that is not
## him. Without the penalties a stack of them is strictly better than aiming.
const EXTRA_ARM_RATE_MULT: float = 0.55
const EXTRA_ARM_DAMAGE_MULT: float = 0.7
const EXTRA_ARM_SPREAD_ADD: float = 14.0
## How fast a grafted arm swings onto its target. Low on purpose -- the lag IS
## the bad aim, and it means a mutant arm keeps shooting where the enemy was.
const EXTRA_ARM_TURN_SPEED: float = 4.0
const EXTRA_ARM_SCALE: float = 0.78

@onready var loadout: Loadout = $Loadout
@onready var weapon_ranged: WeaponRanged = $WeaponRanged
@onready var weapon_melee: WeaponMelee = $WeaponMelee
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hurt_shape: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var rig: Node2D = $Rig
@onready var rig_anim: AnimationPlayer = $Rig/AnimationPlayer
@onready var arm_ranged: Node2D = $Rig/torso/arm_r
@onready var arm_melee: Node2D = $Rig/torso/arm_l
@onready var rig_head: Node2D = $Rig/torso/head
@onready var leg_l: Node2D = $Rig/torso/leg_l
@onready var leg_r: Node2D = $Rig/torso/leg_r
@onready var arm_ranged_art: Sprite2D = $Rig/torso/arm_r/art
@onready var arm_melee_art: Sprite2D = $Rig/torso/arm_l/art
@onready var syringe: Sprite2D = $Rig/torso/arm_r/syringe_gun
@onready var scalpel: Sprite2D = $Rig/torso/arm_l/scalpel_sword
@onready var muzzle: Marker2D = $Rig/torso/arm_r/syringe_gun/Muzzle

var stats: PlayerStats
var health: int = 6

var _iframes: float = 0.0
var _hit_frames: int = 0
var _dash_time: float = 0.0       ## seconds of dash movement left
var _dash_cooldown: float = 0.0
var _dash_dir: Vector2 = Vector2.RIGHT
var _dash_ghost_timer: float = 0.0
## Mold clumps currently riding him. See attach_mold.
var _molds: Array[Node] = []
## Shadow placement, measured off the rig in _fit_shapes.
var _ground_y: float = 0.0
var _shadow_width: float = 0.0
## Each foot's resting height in player space, so a raised one can be told from
## a planted one. Captured after the rig is up, never assumed.
var _foot_rest: Dictionary = {}
var _aim: Vector2 = Vector2.RIGHT
## Seconds of weapons-locked left, and how long until he can be locked again.
## See jam().
var _jam: float = 0.0
var _jam_grace: float = 0.0
var _knock: Vector2 = Vector2.ZERO
var _rig_mat: ShaderMaterial
# Authored weapon scales, captured before anything flips them. The scalpel is
# not at scale 1, so flipping cannot just assign +-1.
var _syringe_scale: Vector2
var _scalpel_scale: Vector2
var _syringe_grip: Vector2
var _scalpel_grip: Vector2
# The angle each weapon is mounted at relative to its arm, read off the rig
# rather than assumed. Pointing an arm somewhere means rotating it by the target
# angle MINUS its weapon's mount, so re-mounting a weapon in kid_parts.json
# cannot silently throw the aim off by the difference.
var _syringe_mount: float
var _scalpel_mount: float
# Rest positions the turn offsets are measured from.
var _rig_base_x: float
var _rig_base_y: float
var _rig_base_scale_y: float
var _head_base_x: float
## Single phase behind bob, squash and sway. Advanced by a rate that depends on
## how fast he is actually moving, so the gait speeds up with him.
var _bob_phase: float = 0.0
## Smoothed 0..1 "how much of a run is this", so stopping eases the bob down
## instead of dropping it a frame after the key comes up.
var _gait: float = 0.0
## -1 facing screen-left, +1 screen-right. Holds its last value when he stops, so
## he keeps looking the way he was going instead of snapping square the instant
## the key comes up.
var _facing: float = 0.0
## Which device owns the aim. Latched rather than chosen per frame -- see
## _update_aim.
var _aim_from_stick: bool = false
## Whether the player is asking to shoot RIGHT NOW. The aim stick being pushed
## counts, and so does the fire button -- without the second one a mouse player
## has no way to express "aiming" at all and the syringe would never go off.
var _aiming: bool = false
var _last_mouse: Vector2 = Vector2.ZERO
## The part artworks that flip to face right: head, torso and both legs. NOT the
## arms -- leaving those alone is what keeps the scalpel on his left and the
## syringe on his right whichever way he is running.
var _rig_base_scale_x: float
## +1 drawn as authored (facing screen-left), -1 mirrored (facing screen-right).
## Everything the rig contains mirrors together, so the aim maths has to account
## for it -- see _aim_rotation.
var _mirror: float = 1.0
## One entry per grafted arm: the rig joint, its syringe sprite, its counter-
## mirrored artwork, the weapon that fires from it, and the direction it is
## currently pointing (which lags its target -- see EXTRA_ARM_TURN_SPEED).
var _extra_arms: Array[Dictionary] = []

## --- death state ---
var _dying: bool = false
var _death_time: float = 0.0
var _death_slide: Vector2 = Vector2.ZERO
## Speed he went down at, which is what the face smush is measured against.
var _death_speed: float = 0.0
var _smear_timer: float = 0.0
var _pooled: bool = false
var _head_base_scale: Vector2 = Vector2.ONE
var _rig_base_rotation: float = 0.0


func _ready() -> void:
	add_to_group(&"player_body")

	# The rig scene ships one ShaderMaterial, so every instance of it would share
	# the same uniforms -- tinting the player would tint every other character
	# built from the same rig. Duplicate per instance.
	_rig_mat = (rig.material as ShaderMaterial).duplicate()
	rig.material = _rig_mat

	_syringe_scale = syringe.scale
	_scalpel_scale = scalpel.scale
	_syringe_mount = syringe.rotation
	_scalpel_mount = scalpel.rotation
	_syringe_grip = syringe.position
	_scalpel_grip = scalpel.position
	_rig_base_x = rig.position.x
	_rig_base_y = rig.position.y
	_rig_base_scale_y = rig.scale.y
	_head_base_x = rig_head.position.x

	_rig_base_scale_x = rig.scale.x
	# Captured for the death fall, which deforms both away from their authored
	# values and has nothing else to lerp back from.
	_head_base_scale = rig_head.scale
	_rig_base_rotation = rig.rotation
	# Seed it, or the first frame's "did the mouse move?" test compares against
	# the origin and wrongly hands the aim to the mouse.
	_last_mouse = get_global_mouse_position()

	# Shots leave the needle, not the player's centre. Handing the weapon the
	# marker keeps it from having to know anything about the rig's shape.
	weapon_ranged.muzzle = muzzle

	# Feet at rest, for the shadow to measure lift against. Captured before any
	# animation has played, so "rest" is the authored pose and not whatever frame
	# the idle happened to be on.
	for leg: Node2D in [leg_l, leg_r]:
		if leg != null:
			_foot_rest[leg.name] = to_local(leg.global_position).y

	loadout.resolved.connect(_on_loadout_resolved)
	loadout.resolve()
	health = stats.max_health
	health_changed.emit(health, stats.max_health)


func _on_loadout_resolved(ranged: AttackStats, melee: AttackStats, player_stats: PlayerStats) -> void:
	var previous_max := stats.max_health if stats != null else 0
	stats = player_stats
	weapon_ranged.set_stats(ranged)
	weapon_melee.set_stats(melee)
	_sync_extra_arms(player_stats.extra_arms, ranged)

	# Size is a stat, not a special case. It scales the visual, the hurtbox,
	# and (through the weapon blocks) nothing else -- reach and projectile
	# size stay item-driven so "small" does not silently mean "worse".
	#
	# The shapes are measured in UNSCALED player space and inherit this scale
	# like the rig does, so shrinking keeps the hitbox on the sprite for free.
	scale = Vector2.ONE * stats.size_scale
	_fit_shapes()

	# Items recolour the player through a BLEND-op stat. The placeholder drew
	# this as a flat fill; on a six-part sprite it is one uniform on the rig
	# root, inherited by every part. This is why ART_BIBLE.md requires the suit
	# stay desaturated -- a saturated sprite would swallow the tint.
	_rig_mat.set_shader_parameter("tint", stats.tint)

	# A max_health item should hand you the extra point, not just the pip.
	if previous_max > 0 and stats.max_health > previous_max:
		health += stats.max_health - previous_max
	health = mini(health, stats.max_health)
	health_changed.emit(health, stats.max_health)


## Grows or trims the grafted arms to match the resolved stat, and hands each
## one its own degraded copy of the syringe block.
##
## Rebuilt by count, never torn down and re-made wholesale: resolve() runs on
## every pickup, and recreating the arms each time would restart their aim lag
## and pop them back to the shoulder mid-fight.
func _sync_extra_arms(count: int, ranged: AttackStats) -> void:
	while _extra_arms.size() > count:
		var dead: Dictionary = _extra_arms.pop_back()
		(dead["joint"] as Node2D).queue_free()
		(dead["weapon"] as Node).queue_free()
	while _extra_arms.size() < count:
		_extra_arms.append(_build_extra_arm(_extra_arms.size()))

	var degraded := ranged.duplicate_stats()
	degraded.attack_rate *= EXTRA_ARM_RATE_MULT
	degraded.damage *= EXTRA_ARM_DAMAGE_MULT
	degraded.spread_random += EXTRA_ARM_SPREAD_ADD
	for arm in _extra_arms:
		(arm["weapon"] as WeaponRanged).set_stats(degraded.duplicate_stats())


## A grafted arm is a copy of the arm he already has -- same artwork, same
## syringe, same muzzle marker -- hung lower on the torso and shrunk. Cloning
## the rig node rather than authoring a third arm means the mutation cannot go
## out of sync with the character art.
func _build_extra_arm(index: int) -> Dictionary:
	var joint := arm_ranged.duplicate() as Node2D
	joint.name = "arm_graft_%d" % index
	# Alternating sides, each pair hung lower than the last, so a stack of three
	# reads as a body coming apart rather than as one arm getting thicker.
	var side := 1.0 if index % 2 == 0 else -1.0
	var row := float(index / 2)
	joint.position = Vector2(
		absf(arm_ranged.position.x) * side * 0.82,
		arm_ranged.position.y + 210.0 + 190.0 * row
	)
	joint.scale = Vector2.ONE * EXTRA_ARM_SCALE
	# Behind everything the player is actually aiming with.
	joint.z_index = -2
	arm_ranged.get_parent().add_child(joint)

	var weapon := WeaponRanged.new()
	weapon.name = "WeaponGraft_%d" % index
	weapon.muzzle = joint.get_node("syringe_gun/Muzzle") as Node2D
	add_child(weapon)

	return {
		"joint": joint,
		"art": joint.get_node("art") as Sprite2D,
		"syringe": joint.get_node("syringe_gun") as Sprite2D,
		"weapon": weapon,
		"aim": Vector2.RIGHT,
	}


## Grafted arms pick their own targets: nearest enemy, tracked with a lag. They
## never read the cursor -- the whole point of the mutation is that it is not
## under his control.
func _update_extra_arms(delta: float) -> void:
	if _extra_arms.is_empty():
		return
	for arm in _extra_arms:
		var joint := arm["joint"] as Node2D
		var target := _nearest_enemy(joint.global_position)
		var aim: Vector2 = arm["aim"]
		if target != null:
			var wanted := (target.global_position - joint.global_position).normalized()
			aim = aim.slerp(wanted, minf(1.0, delta * EXTRA_ARM_TURN_SPEED)).normalized()
		arm["aim"] = aim

		joint.rotation = _aim_rotation(aim.angle(), _syringe_mount)
		_place_weapon(arm["syringe"] as Sprite2D, _syringe_scale, _syringe_grip, aim.x < 0.0)
		(arm["art"] as Sprite2D).scale.x = _mirror

		# Fires only when it has something to fire at, or a mutant arm empties
		# the syringe into a wall for the whole walk between rooms.
		if target != null:
			(arm["weapon"] as WeaponRanged).try_fire(aim)


func _nearest_enemy(from: Vector2) -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for n in get_tree().get_nodes_in_group(&"enemies"):
		if n is not Node2D:
			continue
		var d := from.distance_squared_to((n as Node2D).global_position)
		if d < best_dist:
			best_dist = d
			best = n as Node2D
	return best


## The white hit blink is counted down here and NOT in _physics_process: physics
## runs at a fixed 60Hz regardless of what the display is doing, so a "one
## physics tick" flash can be drawn twice or missed entirely. One idle frame is
## one drawn frame.
func _process(_delta: float) -> void:
	# The shadow follows the legs, and the legs are animated, so it is redrawn
	# every frame the rig is.
	queue_redraw()
	if _rig_mat == null:
		return
	_rig_mat.set_shader_parameter("flash", 1.0 if _hit_frames > 0 else 0.0)
	if _hit_frames > 0:
		_hit_frames -= 1


## The kid's shadow: one soft pool under the body, plus a smaller one under each
## foot that follows the walk cycle.
##
## The feet are what make it read. A single ellipse tracks the body fine and
## looks pasted on, because the one thing the eye checks is whether the shadow
## agrees with the legs -- and during a run they are the only parts moving
## independently. Each foot's own shadow shrinks as that foot lifts, so the gait
## shows up on the floor without anyone animating a second set of art.
##
## Read off the rig's live transforms rather than the animation clock: the run
## cycle can be retimed or replaced and this keeps working.
func _draw() -> void:
	if _shadow_width <= 0.0:
		return

	# The body pool sits under his centre of mass and eases with the bob, which
	# is the same phase the squash uses -- so he lightens on the up beat.
	var body_lift := absf(rig.position.y - _rig_base_y)
	Lighting.draw_shadow(self, Vector2(rig.position.x - _rig_base_x, _ground_y),
		_shadow_width, body_lift, 0.75)

	for leg: Node2D in [leg_l, leg_r]:
		if leg == null:
			continue
		var here := to_local(leg.global_position)
		var rest: float = _foot_rest.get(leg.name, here.y)
		# Only ever UP: a leg swinging below its rest pose is the art, not a step
		# into the floor, and letting that grow the shadow reads as sinking.
		var lift := maxf(rest - here.y, 0.0)
		Lighting.draw_shadow(self, Vector2(here.x, _ground_y),
			_shadow_width * 0.42, lift, 0.9)


## Wraps the hitbox around the kid as drawn -- torso, head and legs -- and
## deliberately NOT around the arms.
##
## The arms are the only parts that leave the silhouette: the gun arm swings a
## full circle tracking the cursor and the scalpel arm sweeps its whole arc, so
## including them would give him a hitbox that grows and shrinks with where he
## happens to be pointing. Everything from the shoulders out is free.
func _fit_shapes() -> void:
	var parts: Array[Sprite2D] = []
	for node in rig.find_children("*", "Sprite2D", true, false):
		var sprite := node as Sprite2D
		# The whole arm subtree goes, weapons included -- the scalpel is a child
		# of the arm and swings with it.
		if _is_under_arm(sprite):
			continue
		parts.append(sprite)

	var rect := SpriteFootprint.union_rect(parts, self)
	if rect.size == Vector2.ZERO:
		# Nothing measurable (a rig that failed to load). Keep the old circle
		# rather than leaving him with no collision at all.
		var circle := CircleShape2D.new()
		circle.radius = BASE_RADIUS
		hurt_shape.shape = circle
		body_shape.shape = circle.duplicate()
		return

	SpriteFootprint.apply_capsule(hurt_shape, rect)
	# The body that pushes on walls is pulled well in: a hitbox that matches the
	# art exactly is fair to be SHOT at, but against a wall it stops him a body's
	# width from the surface he can plainly see. He is drawn front-on and stands
	# on a much smaller footprint than his silhouette covers -- the shoulders and
	# the tank are not what touch the wall.
	SpriteFootprint.apply_capsule(body_shape, rect, 0.55)

	# Where he stands, for the shadow. Taken off the same measurement as the
	# hitbox so it cannot drift away from the drawn body.
	_ground_y = rect.end.y - rect.size.y * 0.04
	_shadow_width = rect.size.x * 0.72


func _is_under_arm(node: Node) -> bool:
	var n := node
	while n != null and n != rig:
		if n.name == &"arm_l" or n.name == &"arm_r" or String(n.name).begins_with("arm_graft"):
			return true
		n = n.get_parent()
	return false


func _physics_process(delta: float) -> void:
	if _dying:
		_tick_death(delta)
		return

	_iframes -= delta

	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")

	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
	if Input.is_action_just_pressed(&"dash"):
		_try_dash(input)

	if _dash_time > 0.0:
		_dash_time -= delta
		_tick_dash_ghosts(delta)
		# Knockback is deliberately dropped for the duration: the dash is the one
		# move that is supposed to go exactly where it was aimed.
		velocity = _dash_dir * DASH_SPEED
	else:
		velocity = input * stats.move_speed * mold_speed_mult() + _knock
	_knock = _knock.move_toward(Vector2.ZERO, 900.0 * delta)
	move_and_slide()

	_update_aim()

	# Rig first, so the arm has already swung to the cursor and the needle is
	# where it will actually be when the shot leaves it.
	_update_rig(delta)

	# The syringe answers to the aim input. The scalpel does NOT: it triggers on
	# proximity and turns to whatever is closest, which is what keeps him from
	# being helpless while repositioning. Putting it behind the same input would
	# make "stop aiming" mean "stop defending yourself".
	# Jammed means jammed: both weapons, not just the one that was hit. The
	# scientist's dart is a "you cannot answer for a second" and splitting it per
	# weapon would leave the scalpel covering for the syringe, which is the exact
	# thing the second is supposed to take away.
	_jam = maxf(_jam - delta, 0.0)
	_jam_grace = maxf(_jam_grace - delta, 0.0)
	if _jam <= 0.0:
		if _aiming:
			weapon_ranged.try_fire(_muzzle_aim())
		weapon_melee.try_swing(_aim)


## The death: he keeps travelling, goes down face first, and the floor takes the
## speed out of him. Three things run off one clock -- the fall, the slide and
## the smush -- and the smush is driven off the LIVE speed rather than the fall's
## progress, so his face is worst just as he lands and eases out as he stops.
func _tick_death(delta: float) -> void:
	_death_time += delta

	velocity = _death_slide
	_death_slide = _death_slide.move_toward(Vector2.ZERO, DEATH_FRICTION * delta)
	move_and_slide()
	# A wall does not stop the CLOCK, but it does stop the body, and a slide that
	# keeps its speed while pressed against a doorway would smear blood forever.
	_death_slide = _death_slide.limit_length(velocity.length())

	var fall := clampf(_death_time / DEATH_FALL_TIME, 0.0, 1.0)
	# Ease out: he drops fast and settles, which is what gravity does.
	fall = 1.0 - pow(1.0 - fall, 3.0)
	var speed := velocity.length()
	# How hard the face is being dragged, right now.
	var smush := fall * clampf(speed / DEATH_SMUSH_SPEED, 0.0, 1.0)

	# Which way he is going, in the RIG's own space -- the rig root carries the
	# mirror, so a slide to screen-left is a local +x drag when he is mirrored.
	var travel := signf(_death_slide.x) if absf(_death_slide.x) > 1.0 else signf(_facing)
	var local_travel := travel * _mirror

	# Flat on the floor: foreshortened, spread wider, dropped, tilted into the
	# direction of travel.
	rig.scale.x = _rig_base_scale_x * _mirror * lerpf(1.0, DEATH_SPREAD_X, fall)
	rig.scale.y = _rig_base_scale_y * lerpf(1.0, DEATH_SQUASH_Y, fall)
	rig.position.x = _rig_base_x + travel * BODY_TURN_SHIFT * fall
	rig.position.y = _rig_base_y + DEATH_DROP * fall
	rig.rotation = lerpf(_rig_base_rotation, DEATH_TILT * travel, fall)

	# The face. Flattened against the floor and dragged back along the slide,
	# which is the deformation doing the work -- a head that only squashes reads
	# as him ducking.
	rig_head.scale = Vector2(
		_head_base_scale.x * (1.0 + DEATH_SMUSH_SPREAD * smush),
		_head_base_scale.y * (1.0 - DEATH_SMUSH_FLATTEN * smush)
	)
	rig_head.position.x = _head_base_x + DEATH_SMUSH_DRAG * local_travel * smush
	rig_head.rotation = lerpf(rig_head.rotation, 0.22 * local_travel, minf(1.0, delta * 12.0))

	# Sprawl. Arms out to either side, legs apart -- nothing is holding itself up.
	var ease := minf(1.0, delta * 10.0)
	arm_melee.rotation = lerp_angle(arm_melee.rotation, DEATH_ARM_SPRAWL, ease)
	arm_ranged.rotation = lerp_angle(arm_ranged.rotation, -DEATH_ARM_SPRAWL, ease)
	if leg_l != null:
		leg_l.rotation = lerp_angle(leg_l.rotation, DEATH_LEG_SPLAY, ease)
	if leg_r != null:
		leg_r.rotation = lerp_angle(leg_r.rotation, -DEATH_LEG_SPLAY, ease)

	_bleed(delta, speed)


## The trail he leaves. A dab per interval while he is still travelling, then one
## pool where he comes to rest -- so the floor records the whole slide and not
## just its end. Goes through the room's blood layer like everything else's does,
## which is what makes it outlast the room.
func _bleed(delta: float, speed: float) -> void:
	var room := get_tree().get_first_node_in_group(&"room") as Room
	if room == null:
		return
	var ground := global_position + Vector2(0.0, _ground_y * 0.5)

	if speed > DEATH_SMEAR_SPEED:
		_smear_timer -= delta
		if _smear_timer <= 0.0:
			_smear_timer = DEATH_SMEAR_INTERVAL
			# Small and jittered off the line, so the trail is a smear rather
			# than a row of evenly spaced dots.
			room.spill_blood_global(ground + Vector2(randf_range(-5.0, 5.0), randf_range(-4.0, 4.0)),
				DEATH_BLOOD, randf_range(5.0, 9.0))
		return

	if _pooled:
		return
	_pooled = true
	room.spill_blood_global(ground, DEATH_BLOOD, DEATH_POOL_SIZE)
	for i in 4:
		room.spill_blood_global(ground + Vector2.from_angle(randf() * TAU) * randf_range(10.0, 34.0),
			DEATH_BLOOD, randf_range(8.0, 16.0))


## Starts a dash if one is available. Direction is the movement stick first --
## a dash is a movement move, and going where the cursor happens to be would
## make it unusable for retreating while shooting. With no stick input it falls
## back to the way he is already facing, so a standing dash is never a refusal.
func _try_dash(input: Vector2) -> void:
	if _dash_cooldown > 0.0 or _dash_time > 0.0:
		return
	var dir := input
	if dir.length_squared() < 0.01:
		dir = Vector2(_facing, 0.0) if absf(_facing) > 0.1 else _aim
	if dir.length_squared() < 0.01:
		return

	_dash_dir = dir.normalized()
	_dash_time = DASH_TIME
	_dash_cooldown = DASH_COOLDOWN
	# One invulnerability channel, shared with getting hit, so a dash cannot stack
	# on top of hit frames into a longer window than either grants.
	_iframes = maxf(_iframes, DASH_TIME + DASH_IFRAME_PAD)
	# Shots are made to pass through by ATTACKS asking whether he is intangible
	# (see Hurtbox.is_intangible), not by switching the hurtbox off. The hurtbox
	# is also what doors and pedestals detect him with, and a dash that turns it
	# off is a dash that cannot go through a doorway.
	_dash_ghost_timer = 0.0
	_spawn_dash_ghost()
	# The dash is the answer to mold. Shaking it off is not a side effect worth
	# hiding behind a stat -- it is the reason to keep a dash in reserve.
	shed_molds()


func _tick_dash_ghosts(delta: float) -> void:
	_dash_ghost_timer -= delta
	if _dash_ghost_timer <= 0.0:
		_dash_ghost_timer = DASH_GHOST_INTERVAL
		_spawn_dash_ghost()


## One smudge: a frozen copy of the rig exactly as it is drawn this frame,
## dropped into the world and faded out where it stands.
##
## The rig is duplicated rather than drawn from a stored texture because the kid
## is a six-part rig with arms at arbitrary angles -- there is no single sprite
## to copy. The clone is stripped of its AnimationPlayer so it holds the pose it
## was born in instead of running the walk cycle on its own.
func _spawn_dash_ghost() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var ghost := rig.duplicate(DUPLICATE_USE_INSTANTIATION) as Node2D
	var anim := ghost.get_node_or_null(^"AnimationPlayer")
	if anim != null:
		anim.queue_free()

	# World space, not parented to the player: the point of a trail is that it
	# stays where he was.
	parent.add_child(ghost)
	ghost.global_transform = rig.global_transform
	ghost.z_index = rig.z_index - 1

	# Its own material, or every ghost would share the player's uniforms and the
	# hit flash would strobe the whole trail.
	if ghost.material is ShaderMaterial:
		ghost.material = (ghost.material as ShaderMaterial).duplicate()
		(ghost.material as ShaderMaterial).set_shader_parameter("flash", 0.0)
		(ghost.material as ShaderMaterial).set_shader_parameter("tint", DASH_GHOST_TINT)
	ghost.modulate = Color(DASH_GHOST_TINT, DASH_GHOST_ALPHA)

	var tween := ghost.create_tween()
	tween.tween_property(ghost, ^"modulate:a", 0.0, DASH_GHOST_FADE)
	tween.tween_callback(ghost.queue_free)


func is_dashing() -> bool:
	return _dash_time > 0.0


## --- Mold ------------------------------------------------------------------
## Mold rides the player and slows him. The player owns the LIST rather than a
## slow stat, because the dash has to be able to kill exactly the things that
## are attached, and a stacked multiplier cannot be handed back its sources.
##
## Multiplicative per clump, so a second one hurts less than the first and no
## number of them can ever stop him dead.
func attach_mold(mold: Node) -> void:
	if mold not in _molds:
		_molds.append(mold)


func detach_mold(mold: Node) -> void:
	_molds.erase(mold)


func mold_speed_mult() -> float:
	_prune_molds()
	return pow(MOLD_SLOW_PER_CLUMP, _molds.size())


func mold_count() -> int:
	_prune_molds()
	return _molds.size()


func shed_molds() -> void:
	_prune_molds()
	for m in _molds.duplicate():
		if m.has_method(&"burst"):
			m.burst()
	_molds.clear()


func _prune_molds() -> void:
	var alive: Array[Node] = []
	for m in _molds:
		if is_instance_valid(m):
			alive.append(m)
	_molds = alive


## Shoved by the room itself. Same channel as knockback so it decays the same
## way, and deliberately NOT damage -- a cramp moves you, it does not hurt you.
func push(impulse: Vector2) -> void:
	_knock = impulse


## Weapons locked for `seconds`. The scientist's dart, and deliberately not
## damage: it costs the player their answer to what is coming rather than their
## health, which is the whole reason that enemy is frightening while being almost
## harmless on paper.
##
## Takes the LONGER of the two rather than adding. A crowd of them would
## otherwise stack a jam the player never gets out of, and "shot by four things
## at once" should be worse than one, not terminal.
## Takes the LONGER of the two rather than adding. A crowd of them would
## otherwise stack a jam the player never gets out of, and "shot by four things
## at once" should be worse than one, not terminal.
##
## The grace window is the other half of that promise. Without it a pair of
## scientists refreshing a one-second jam every half second is a permanent
## disarm, which is not a hazard -- it is the run being over while it is still
## running. Worst case is now a second locked, then most of a second armed.
func jam(seconds: float) -> void:
	if _jam_grace > 0.0:
		return
	_jam = maxf(_jam, seconds)
	_jam_grace = seconds + JAM_GRACE


func is_jammed() -> bool:
	return _jam > 0.0


## Twin-stick aim, from whichever device the player last actually used.
##
## Mouse and stick cannot simply be summed or preferred by magnitude: a mouse
## always reports a position, so a stick would be fighting it every frame, and a
## controller player would find the aim snapping back to wherever the pointer was
## abandoned. So the device is latched -- the stick claims it by moving, the
## mouse claims it back by moving.
##
## Releasing the stick holds the last direction rather than falling back to the
## mouse. That is the twin-stick convention: let go and he keeps covering the way
## he was pointed.
func _update_aim() -> void:
	var stick := Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down")
	var mouse_now := get_global_mouse_position()

	if mouse_now.distance_squared_to(_last_mouse) > 4.0:
		_aim_from_stick = false
	_last_mouse = mouse_now

	# Held, not latched: this is the trigger, and letting go of the stick has to
	# put the gun down. The LAST DIRECTION still latches below, so releasing
	# leaves him covering the way he was pointed rather than snapping square.
	_aiming = stick.length_squared() > 0.0 or Input.is_action_pressed(&"fire")

	if stick.length_squared() > 0.0:
		_aim_from_stick = true
		_aim = stick.normalized()
	elif not _aim_from_stick:
		var to_mouse := mouse_now - global_position
		if to_mouse.length_squared() > 4.0:
			_aim = to_mouse.normalized()


## Direction from the NEEDLE to the cursor.
##
## Shots are born at the muzzle but used to travel along the player's own centre
## line, so they left the needle on a parallel course and passed the cursor by
## the width of the offset -- worst when the target was close, which is exactly
## when it matters. Aiming from the point the shot actually starts makes the line
## pass through the cursor.
func _muzzle_aim() -> Vector2:
	# A stick gives a direction, not a point in the room, so there is nothing to
	# correct the muzzle offset against -- and nothing that needs correcting,
	# since the player is not pointing at a specific spot.
	if _aim_from_stick:
		return _aim
	var to_cursor := get_global_mouse_position() - muzzle.global_position
	# Standing on the cursor leaves no direction to speak of; keep the last one.
	if to_cursor.length_squared() < 16.0:
		return _aim
	return to_cursor.normalized()


## The rig replaces what _draw used to say. Facing is deliberately NOT expressed
## by the body: the kid always faces the viewer and the weapon carries the aim
## direction -- see ART_BIBLE.md, "Camera and facing". The old wedge pointed
## itself at the cursor because it had nothing else to communicate with.
func _update_rig(delta: float) -> void:
	# Facing first: it sets `_mirror`, and every arm angle below is computed
	# through it. Updating it afterwards left the aim a frame stale, so the arm
	# visibly whipped through the wrong side on each change of direction.
	_update_facing(delta)

	# Bob and squash before the arms are placed: they move the shoulders, and an
	# arm pointed from where the shoulder was LAST frame lags by a whole frame in
	# exactly the situation where the barrel is most visible.
	_update_body_motion(delta)

	var wanted := &"run" if velocity.length() > WALK_SPEED_THRESHOLD else &"idle"
	if rig_anim.current_animation != wanted:
		# The run is driven by hand off the bob phase and so must not also advance
		# itself -- a clip that is both seeked and playing double-steps. The idle
		# keeps its own clock: it is breathing, not a gait, and there is nothing
		# for it to stay in step with.
		rig_anim.speed_scale = 0.0 if wanted == &"run" else 1.0
		rig_anim.play(wanted)
	if wanted == &"run":
		_seek_to_phase(wanted)

	# The gun arm tracks the aim only while he is actually aiming, and eases back
	# to his side otherwise. The idle and run animations deliberately carry no
	# arm tracks, so there is nothing here to fight.
	# Aimed from the SHOULDER, not the body's centre. The shoulder is where the
	# arm actually pivots, so pointing it from anywhere else leaves the barrel
	# line and the shot line disagreeing -- the gun visibly points past what it
	# is about to hit. The joint's own position does not depend on its rotation,
	# so there is no circularity here.
	var arm_aim := _aim
	if not _aim_from_stick:
		var shoulder_to_cursor := get_global_mouse_position() - arm_ranged.global_position
		if shoulder_to_cursor.length_squared() > 16.0:
			arm_aim = shoulder_to_cursor.normalized()

	if _aiming:
		arm_ranged.rotation = _aim_rotation(arm_aim.angle(), _syringe_mount)
		# Rotating past vertical carries the weapon over with it, so aiming left
		# the syringe hangs upside down with the plunger underneath. The test is
		# on where it is AIMED, not on anything internal to the rig, so it holds
		# identically whichever way the body is turned.
		_place_weapon(syringe, _syringe_scale, _syringe_grip, arm_aim.x < 0.0)
	else:
		# The gun arm is on his screen-right, so it takes the +1 side.
		var guard := RANGED_GUARD_ANGLE + _arm_swing(1.0)
		arm_ranged.rotation = lerp_angle(arm_ranged.rotation, guard,
			minf(1.0, delta * RANGED_RETURN_SPEED))
		# Same reasoning as the scalpel's guard: restore the resting mirror only
		# once he is essentially back to rest, or the syringe flips over halfway
		# through the drop. Measured against the SWUNG guard, not the constant --
		# against the constant, a running kid never counts as "back to rest" and
		# the syringe would stay in whatever mirror the last shot left it in.
		if absf(angle_difference(arm_ranged.rotation, guard)) < 0.05:
			_place_weapon(syringe, _syringe_scale, _syringe_grip, RANGED_GUARD_FLIP)

	_update_melee_arm(delta)
	_update_extra_arms(delta)

	# The gun arm stays IN FRONT of the torso at all times. Behind, it reads fine
	# hanging at his side but disappears the moment it aims right, because it
	# swings straight behind the back-mounted tank -- the weapon the player is
	# aiming with is the last thing that should be occluded. An arm crossing in
	# front of a chest is something cartoons do constantly and nobody notices.
	arm_ranged.z_index = 2

	# The melee arm sits behind the gun arm at rest and comes over the top while
	# swinging, so the attack reads over everything else. Keyed to its own swing
	# rather than to the aim: it no longer follows the cursor, so using the aim
	# would pop a resting arm every time the cursor crossed the centre line.
	arm_melee.z_index = 3 if weapon_melee.is_swinging() else 1


## The scalpel arm hangs at his side and only moves for an actual attack. Melee
## fires on proximity rather than on aim, so tracking the cursor with it would
## have the blade waving at things it is not hitting.
## Leans the body the way he is running. The head leads and travels furthest,
## the whole rig follows by less -- which is what reads as turning rather than
## as the sprite sliding sideways.
##
## Both are position offsets on nodes the animations do not touch: the rig root,
## and the head's position (idle and run animate the head's ROTATION only). Any
## other node here would end up in a tug of war with the AnimationPlayer.
func _update_facing(delta: float) -> void:
	var moving_x := velocity.x
	if absf(moving_x) > WALK_SPEED_THRESHOLD:
		_facing = move_toward(_facing, signf(moving_x), delta * TURN_SPEED)

	# The art is a three-quarter view facing screen-LEFT, so facing right means
	# mirroring the WHOLE rig, not shuffling parts around inside it. Earlier
	# attempts mirrored individual pieces and each one broke differently: the
	# torso's cuts are asymmetric so it tore holes, and the legs flipped about
	# their own hips so they crossed. Mirroring the root is one transform, and
	# every part stays consistent with every other by construction.
	_mirror = -1.0 if _facing > 0.0 else 1.0
	rig.scale.x = _rig_base_scale_x * _mirror

	# Counter-mirror the ARM ARTWORK so it keeps the shape and shading it was
	# drawn with. The joints still mirror -- the shoulders belong wherever the
	# turned body puts them -- but the pictures hanging off them do not, because
	# a mirrored gauntlet reads as an inside-out arm.
	#
	# Flipped about the joint, deliberately, with no re-centring: the shoulder is
	# already in the right place and the arm should hang off it exactly as drawn.
	arm_ranged_art.scale.x = _mirror
	arm_melee_art.scale.x = _mirror

	# The body leans into the run. The rig-root shift is outside the mirror so it
	# follows `_facing` directly; the head's offset is INSIDE it, so it is always
	# "forward" in the rig's own space and the mirror aims it.
	rig.position.x = _rig_base_x + _facing * BODY_TURN_SHIFT
	rig_head.position.x = _head_base_x + absf(_facing) * HEAD_TURN_SHIFT


## Bob, squash and sway, all off one phase.
##
## Runs AFTER _update_facing, which owns rig.position.x and the sign of
## rig.scale.x -- this only ever multiplies magnitudes onto what facing decided,
## so the two cannot fight over the same channel.
##
## The AnimationPlayer is untouched by all of this. Idle and run animate the head
## and the legs; nothing in either of them touches the rig root, which is the
## only node here that gets written.
func _update_body_motion(delta: float) -> void:
	var speed := velocity.length()
	var target_gait := 1.0 if speed > WALK_SPEED_THRESHOLD else 0.0
	_gait = move_toward(_gait, target_gait, delta * 6.0)

	# Faster running is a faster gait, not a bigger one. Normalised against his
	# own move_speed so a speed item makes him scurry rather than lope.
	var pace := clampf(speed / maxf(stats.move_speed, 1.0), 0.0, 1.4)
	var rate := lerpf(BOB_IDLE_RATE, BOB_RUN_RATE * maxf(pace, 0.35), _gait)
	_bob_phase = fposmod(_bob_phase + delta * rate, TAU)

	var height := lerpf(BOB_IDLE_HEIGHT, BOB_RUN_HEIGHT, _gait)
	var squash := lerpf(BOB_IDLE_SQUASH, BOB_RUN_SQUASH, _gait)
	var sway := lerpf(BOB_IDLE_SWAY, BOB_RUN_SWAY, _gait)

	var bob := sin(_bob_phase)
	# Up-and-down is one cycle; the squash is TWO, because he lands twice per
	# cycle and the compression belongs on the landings.
	var press := cos(_bob_phase * 2.0)

	# absf: a bob only ever lifts him. Letting it go negative sinks him into the
	# floor on the down beat, which reads as the sprite slipping rather than as
	# weight.
	rig.position.y = _rig_base_y - absf(bob) * height

	# Volume-preserving-ish: what he loses in height he gains in width.
	rig.scale.x = _rig_base_scale_x * _mirror * (1.0 + press * squash)
	rig.scale.y = _rig_base_scale_y * (1.0 - press * squash)

	# Rock side to side, plus a constant lean into whichever way he is running.
	# Rotation sits outside the scale in the transform, so the mirror does not
	# invert it and leaning right is leaning right whichever way he faces.
	var lean := clampf(velocity.x / maxf(stats.move_speed, 1.0), -1.0, 1.0)
	rig.rotation = sin(_bob_phase) * sway + lean * RUN_LEAN * _gait


## Drives the current clip off `_bob_phase` instead of off its own clock.
##
## The clip used to free-run at its authored length while the bob's rate scaled
## with how fast he was actually moving. At his base speed that is a 0.5s clip
## against a 0.55s bob, so the legs and the body they hang off beat against each
## other on a roughly five-second cycle: he would step in time for a stride, then
## visibly float, then catch up. Faster or slower than base speed made it worse,
## because only one of the two sped up.
##
## One phase drives both, so they cannot disagree by construction -- the same
## argument the bob, squash and sway are already built on. The run is authored as
## exactly one gait cycle, and one gait cycle is TAU of phase, so the clip's own
## length is read rather than assumed and re-timing it in the editor needs no
## change here.
func _seek_to_phase(clip: StringName) -> void:
	var anim := rig_anim.get_animation(clip)
	if anim == null:
		return
	rig_anim.seek(_bob_phase / TAU * anim.length, true)


## The gait wobble for a resting arm. `side` is -1 for the arm on screen-left and
## +1 for the one on screen-right, so the two are always half a cycle apart.
##
## Cosine, not sine: the legs are authored with a foot planted at the top of the
## clip, which is phase zero, so an arm's extreme belongs there too. Scaled by
## `_gait` so it eases away with the run rather than twitching at a standstill.
func _arm_swing(side: float) -> float:
	return side * cos(_bob_phase) * ARM_RUN_SWING * _gait


## Arm rotation needed to point a weapon at `world_angle`.
##
## Mirroring the rig reflects every angle inside it about the VERTICAL axis,
## which maps an angle to `PI - angle` -- not to `-angle`. Negating alone is the
## reflection about the horizontal axis, and using it here pointed the arm at the
## vertical mirror of the cursor: correct when aiming straight up or down, and
## increasingly wrong everywhere else.
## The rig root's own tilt is subtracted out. Working the transform through,
## `Rot(r) . Mirror . Rot(theta)` renders at `r + PI - theta`, and unmirrored at
## `r + theta` -- so the sway has to come off the arm's local angle or the gun
## would rock along with the body and point wherever the breathing put it.
func _aim_rotation(world_angle: float, mount: float) -> float:
	if _mirror < 0.0:
		return PI + rig.rotation - world_angle - mount
	return world_angle - rig.rotation - mount


## Mirrors a WEAPON about its own length so it stays the right way up once its
## arm has rotated past vertical.
##
## Deliberately not the arm. Mirroring the arm negates its children's local X,
## which throws the grip to the other side of the limb -- barely visible on the
## gun arm, but the scalpel arm's pivot sits at the far edge of its image, so
## mirroring swings the whole arm across the body. The weapon runs along its own
## local X, so negating local Y flips it upright and moves nothing else.
## Orients a held weapon: `reflect` is whether the sprite must be flipped about
## its own barrel so it does not hang upside down, expressed in RENDERED terms --
## true whenever the thing it is pointing at is off to the left.
##
## The mirror inverts which scale produces that. Working the chain through,
## `Mirror(m) . Rot(phi) . Scale` equals `Rot(-phi) . diag(-sx, sy)`, so with the
## arm already rotated to `PI - angle - mount` a reflection comes out of the BASE
## scale and negating Y produces no reflection at all -- exactly backwards from
## the unmirrored case. Hence the xor.
##
## `grip` also has to move. The arm's artwork is counter-mirrored so it keeps its
## drawn shape, which puts the hand on the opposite side of the shoulder; the
## weapon is a sibling of that artwork and does not inherit the counter-mirror,
## so without this it stays behind on the old side and ends up buried under the
## arm.
func _place_weapon(weapon: Sprite2D, base_scale: Vector2, base_grip: Vector2,
		reflect: bool) -> void:
	var negate_y := reflect != (_mirror < 0.0)
	var want := Vector2(base_scale.x, -base_scale.y if negate_y else base_scale.y)
	if not weapon.scale.is_equal_approx(want):
		weapon.scale = want

	var grip_x := base_grip.x * _mirror
	if not is_equal_approx(weapon.position.x, grip_x):
		weapon.position.x = grip_x


## The angle a weapon actually appears to point at, given a local rotation inside
## the rig. Mirroring reflects about the vertical axis, which maps an angle to
## PI - angle.
func _rendered_angle(local_angle: float) -> float:
	return local_angle if _mirror > 0.0 else PI - local_angle


func _update_melee_arm(delta: float) -> void:
	# Scalpelrang: the blade is only in his hand between throws. In throw mode
	# the arc never runs, so the arm just sits at guard and the sprite carries
	# the whole read of "he has it" versus "it is out there".
	scalpel.visible = not weapon_melee.is_throwing()

	if weapon_melee.is_swinging():
		_place_weapon(scalpel, _scalpel_scale, _scalpel_grip,
			weapon_melee.swing_direction().x < 0.0)
		var t := weapon_melee.swing_t()
		var half := deg_to_rad(weapon_melee.stats.arc_degrees) * 0.5
		var base := weapon_melee.swing_direction().angle()
		# Sweep across the arc over the swing window, so the blade travels the
		# same wedge the hit query actually tests.
		var swept := base - half + half * 2.0 * t
		arm_melee.rotation = _aim_rotation(swept, _scalpel_mount)
	else:
		# Ease back to guard rather than snapping, or the arm teleports there the
		# instant the swing window closes.
		# The scalpel arm is on his screen-left, so it takes the -1 side and ends
		# up half a cycle away from the gun arm.
		var guard := MELEE_GUARD_ANGLE + _arm_swing(-1.0)
		arm_melee.rotation = lerp_angle(arm_melee.rotation, guard,
			minf(1.0, delta * MELEE_RETURN_SPEED))
		# Restore the guard's own mirroring once he is essentially back to it.
		# Derived from the guard angle rather than hardcoded, so moving the guard
		# across the body cannot leave the blade upside down. Resetting the moment
		# the swing ends would flip the blade halfway through the return.
		if absf(angle_difference(arm_melee.rotation, guard)) < 0.05:
			_place_weapon(scalpel, _scalpel_scale, _scalpel_grip, MELEE_GUARD_FLIP)

	# Invulnerability still has to read after the one-frame white is gone, so it
	# is carried by alpha rather than by another white blink -- two different
	# white flashes on the same sprite are indistinguishable from one long one.
	rig.modulate.a = 0.45 if (_iframes > 0.0 and fmod(_iframes, 0.16) < 0.08) else 1.0


func take_damage(amount: float, knockback: Vector2, statuses: Dictionary, _is_crit: bool) -> void:
	if _iframes > 0.0 or _dying:
		return

	if statuses.has("jam"):
		jam(float(statuses["jam"]))

	# A hit that carries a status and no damage is allowed to land as exactly
	# that. Falling through would floor it at one point of health -- see below --
	# and it must NOT burn the invulnerability window either: a scientist's dart
	# is not worth a free pass through the thing that is actually going to kill
	# him, in a game where getting hit costs a sixth of the run.
	if int(round(amount)) <= 0:
		_knock = knockback
		return

	_iframes = IFRAME_TIME
	_hit_frames = HIT_FLASH_FRAMES
	damaged.emit()
	_knock = knockback
	health -= maxi(int(round(amount)), 1)
	health_changed.emit(health, stats.max_health)
	if health <= 0:
		_die()


func is_dead() -> bool:
	return _dying


## Ends the run and hands the body over to _tick_death. Physics keeps running:
## the fall IS movement, and it has to collide with the room he died in --
## sliding through a wall would be a worse ending than switching him off was.
func _die() -> void:
	if _dying:
		return
	_dying = true
	died.emit()

	# Whatever was carrying him, plus the blow that landed. Both are already
	# decaying; the slide takes them over and applies its own friction.
	_death_slide = velocity + _knock * DEATH_KNOCK_WEIGHT
	_death_speed = _death_slide.length()
	_knock = Vector2.ZERO
	_dash_time = 0.0

	# Nothing on him is holding a fight any more.
	shed_molds()
	hurtbox.set_deferred(&"monitorable", false)
	hurtbox.set_deferred(&"monitoring", false)
	# The idle and run clips animate the head and legs, which the fall is about
	# to pose by hand. Left playing, they would fight it every frame.
	rig_anim.stop()
	# Full opacity: the iframe blink is a combat read, and there is no more
	# combat to read.
	rig.modulate.a = 1.0


func grant(item: Item) -> void:
	loadout.add_item(item)
