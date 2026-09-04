class_name Enemy
extends CharacterBody2D

## Prototype enemy: a bacterium that walks at you and hurts on contact.
## It is deliberately dumb. The slice is testing whether builds read, not
## whether AI is interesting.

## How this creature fights. The scene is shared, so the behaviour is data:
## a spawner picks art and behaviour together, and nothing else changes.
enum Behavior {
	## Walks you down and hurts on contact, but not in a straight line -- see
	## `_attention_point`.
	CHASER,
	## Hangs at range and spits. Slow shots, long reach, never off-screen.
	SPITTER,
	## Stands still, telegraphs, then throws itself in a straight line and has to
	## breathe afterwards. Dangerous in the second it moves, free the rest of the
	## time -- the fight is with its rhythm, not its speed.
	CHARGER,
	## Ignores the player entirely and wanders the room on a drifting curve. It
	## is traffic, not a threat: something to be shot around and bumped into.
	WANDERER,
	## Panicking. Bolts in short bursts, mostly away from the player, and fires
	## wild while it runs. The shots barely scratch anything -- what they do is
	## jam whoever they land on, so it is dangerous for what it takes away rather
	## than for what it deals.
	SKITTER,
	## An aerosol can, upright, waddling about the room. Every so often it topples
	## onto its side, rolls across the floor in a straight line, stands back up
	## and sprays. The roll is the dangerous part and the only part -- see
	## RollPhase for what the cycle is and why it is shaped this way.
	ROLLER,
}

## The can's cycle. It is only a threat while it is on its side, which is the
## whole design: a hazard that is always dangerous is a hazard you cannot do
## anything about, and this one announces every roll by lying down first.
enum RollPhase {
	## Upright, waddling slowly. Harmless -- it is a can walking.
	WALK,
	## Toppling. Stationary, brief, and the entire warning that a roll is coming.
	TIP,
	## On its side and travelling. Crushes the player, barges other creatures.
	ROLL,
	## Getting back up. Stationary, and the beat that says the roll is over.
	RISE,
	## Upright and venting. This is where the fumes come from -- laying them
	## while rolling drew a wall across the room behind it, which turned a thing
	## you dodge into a thing that partitions the floor.
	SPRAY,
}

## --- Charger ---------------------------------------------------------------
## Windup is deliberately long enough to walk out of: the whole enemy is a
## question of whether you moved before it committed.
@export var charge_windup: float = 0.55
## Long enough to cross most of a room. The slide is the enemy -- a short one
## reads as a lunge you can stand next to and wait out.
@export var charge_time: float = 0.62
@export var charge_rest: float = 1.2
## Multiplied onto move_speed for the charge itself.
@export var charge_speed_mult: float = 6.0
## Won't start winding up further out than this, so it does not spend the whole
## room charging at a player it can never reach. Kept a little above the slide's
## actual reach (speed x charge_time, about 320px at the spawn defaults), since
## it creeps forward through the rest phase as well.
@export var charge_range: float = 420.0

## --- Wanderer --------------------------------------------------------------
## How sharply the drift curves, in radians per second.
@export var wander_turn: float = 1.8
## Seconds between fresh random turns laid over the curve.
@export var wander_retarget: float = 1.4

## --- Skitter (the scientist) -----------------------------------------------
## It is frightened, not tactical. Movement is short bolts with pauses between
## them, aimed mostly away from the player but rerolled often enough that it
## never commits to a clean retreat -- a scared thing does not path.
@export var skitter_burst: float = 0.34
@export var skitter_rest_min: float = 0.12
@export var skitter_rest_max: float = 0.5
## How much of its run is "away from the player" versus pure panic. At 0 it is a
## wanderer; at 1 it is a clean retreat and trivially cornered.
@export var skitter_flee_bias: float = 0.55
## Degrees either side of the player its shots may land. Wide: it is not aiming,
## it is firing in roughly the right direction with its eyes shut.
@export var skitter_spray: float = 62.0
## How many directions it will try before giving up and running for the middle,
## and how far ahead each one is tested. The look-ahead covers most of a burst,
## so it cannot commit to a heading that is clear for one frame and a wall for
## the rest of it.
const SKITTER_TRIES: int = 6
const SKITTER_LOOKAHEAD: float = 86.0

## --- Roller (the spray can) ------------------------------------------------
## How long each phase of the cycle lasts. The two short ones are the tipping
## and the standing up, and they are deliberately readable rather than snappy:
## the topple IS the telegraph, and a can that goes over in three frames is a
## charger with no windup.
@export var roll_walk_time: float = 1.7
@export var roll_tip_time: float = 0.3
@export var roll_time: float = 1.45
@export var roll_rise_time: float = 0.36
@export var roll_spray_time: float = 1.15
## Speed of the two moving phases, as multipliers on move_speed. Walking is a
## shuffle -- it has no legs -- and the roll is the only time it is quick.
@export var roll_walk_mult: float = 0.42
@export var roll_speed_mult: float = 2.1
## How long a puff of fumes lingers, and how far apart they are laid down while
## it is venting.
@export var roll_fume_life: float = 5.0
@export var roll_fume_interval: float = 0.16
## What it does to other creatures it runs into. It is a metal cylinder and they
## are not -- nothing else in the bestiary moves anything but the player.
@export var roll_shove: float = 900.0
@export var roll_shove_range: float = 96.0
## The can is DRAWN rather than textured. There is no aerosol in the sprite
## sheet, and a cylinder is one of the few shapes that is honestly cheaper as
## geometry than as a picture -- it is two rounded caps and a body, and it has to
## be tinted and re-proportioned per row anyway.
##
## Width and height on screen. Everything else about the can is derived from
## these, so a bigger one is one number.
@export var can_size: Vector2 = Vector2(76.0, 170.0)
@export var can_body: Color = Color(0.72, 0.76, 0.80)
@export var can_cap: Color = Color(0.30, 0.62, 0.44)
## How many bands are painted around the barrel. Enough that one is always in
## view while it rolls, few enough that they stay separable at speed.
const CAN_BANDS: int = 5

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/projectile.tscn")

@export var behavior: Behavior = Behavior.CHASER

## --- Chaser wander ---------------------------------------------------------
## The chaser steers at a point that circles the player and breathes in and out
## of them, so a pack of them fans and weaves instead of stacking into one
## conga line. The point is never further off the player than
## `attention_radius`, and it collapses onto them at close range, so the walk is
## crooked at distance and dead straight once it matters.
@export var attention_radius: float = 120.0
## Seconds for the attention point to complete one in-and-out breath.
@export var attention_period: float = 1.6
## Radians per second the point orbits the player.
@export var attention_orbit_speed: float = 2.2
## Distance at which the wander is fully gone. Inside this the enemy commits.
@export var attention_commit_range: float = 90.0

## --- Spitter ---------------------------------------------------------------
@export var shot_stats: AttackStats
## Won't fire further than this, and walks in until it can.
@export var shot_range: float = 520.0
## Backs off below this, so it never turns into a contact enemy by accident.
@export var standoff_range: float = 300.0
@export var shot_interval: float = 2.0
## Extra screen margin the enemy must be inside before it may fire. Being shot
## by something you cannot see is the complaint this exists to prevent, and the
## margin covers the frame where it is half in.
const ON_SCREEN_MARGIN: float = 24.0

@export var max_health: float = 12.0
@export var move_speed: float = 90.0
@export var contact_damage: float = 1.0
@export var radius: float = 13.0
@export var body_color: Color = Color(1.0, 1.0, 1.0)

## Emission, for a creature whose own colour would otherwise lose it against the
## floor. `body_color` multiplies the sprite, so it can only ever darken -- there
## is no value of it that makes something glow. This adds light on top, and also
## paints the halo around the body in _draw.
##
## Off for everything in the bestiary but the scientist, which is drawn in the
## kid's own drained colours and is invisible in a dark organ without it.
@export var glow_color: Color = Color(0.0, 0.0, 0.0)
@export_range(0.0, 1.0) var glow_amount: float = 0.0
## How far the halo reaches past the body, as a fraction of its own size, and how
## much it breathes. The pulse is what separates "this thing is lit" from "this
## thing has a circle behind it".
const GLOW_REACH: float = 0.85
const GLOW_PULSE: float = 0.18
const GLOW_PULSE_RATE: float = 2.6

## Which way the ARTWORK is drawn facing: -1 drawn looking screen-left, +1
## screen-right, 0 drawn front-on and never mirrored.
##
## Declared per creature rather than assumed, because the sheet is not
## consistent: most of the bestiary is drawn looking screen-right, but the
## parasite and the white cell look left. Mirror everything by one rule and half
## of them crawl at you backwards.
##
## The default is -1 for the white cell, which sets this nowhere. Every creature
## the bestiary spawns states its own.
@export var art_facing: float = -1.0

## On-screen height. Like the player, the sprite is drawn much larger than the
## hurtbox -- `radius` is tuned for how the fight feels, not for how big the
## thing looks, and the art has no business changing it.
@export var sprite_height: float = 74.0

## How white a hit flash goes. Full white is right for a 74px grub; on a body
## the size of the boss the same value turns the whole screen into a lamp every
## time you land a shot, and you land a lot of shots on a boss.
@export_range(0.0, 1.0) var flash_strength: float = 0.45

## What this creature is worth in DNA when it dies. Left at 0 means "decide from
## my size", which is what the whole bestiary does -- a row that wants a fat
## little elite sets it outright. See DnaBalance for the values and for what the
## economy they add up to is supposed to feel like.
@export var dna_value: int = 0

## Big things resist the cold instead of stopping dead in it. Declared rather
## than inferred from health or radius, so a fast little elite can be tagged
## small on purpose.
@export var is_large: bool = false

## Damage only starts showing below this much health, so a healthy enemy is
## completely clean and the first crack actually means something.
const CRACK_THRESHOLD: float = 0.6

const POISON_TINT: Color = Color(0.6, 0.2, 0.8)
const FREEZE_TINT: Color = Color(0.45, 0.8, 1.0)

## --- freeze ---------------------------------------------------------------
## Freeze is a SLOW that occasionally locks, rather than a lock every time.
##
## Stopping a small enemy dead is not a status, it is a delete, and a weapon that
## deletes on every hit stops being a build choice and becomes the only one. As a
## slow it does the same job -- it buys the player space -- while leaving the
## thing on the floor still coming, which is what the fight is made of.
##
## The lock is kept as a rare bonus rather than removed outright because the
## freeze-solid moment is the read that sells the status. Scaled by potency, so
## stacking nitrogen buys better odds as well as a deeper slow.
const FREEZE_LOCK_CHANCE: float = 0.12
const FREEZE_LOCK_CHANCE_MAX: float = 0.4
## Slow per point of potency, and the most a stack can ever slow something to.
## Floored well above zero: a 95% slow is a lock wearing a different name.
const CHILL_SLOW: float = 0.35
const CHILL_FLOOR: float = 0.3
## The same for anything large. A boss is never locked at all, however the roll
## came out -- a boss that can be perma-frozen is a boss that is not a fight.
const CHILL_LARGE_SLOW: float = 0.3
const CHILL_LARGE_FLOOR: float = 0.3
## How long the two outcomes last. The lock runs short for the reason it always
## did; the slow is allowed to run longer because it is the weaker of the two.
const FREEZE_LOCK_TIME: float = 0.7
const FREEZE_LOCK_TIME_PER: float = 0.5
const FREEZE_SLOW_TIME: float = 2.2
const FREEZE_SLOW_TIME_PER: float = 0.6

@onready var hurt_shape: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var art: Sprite2D = $Art

var health: float
var _mat: ShaderMaterial

var _knock: Vector2 = Vector2.ZERO
var _hit_flash: float = 0.0
var _hit_flash_len: float = 0.12
## status id -> [potency, seconds_left]
var _statuses: Dictionary = {}  # String id -> [potency, seconds_left]
var _poison_tick: float = 0.0

## --- mourning --------------------------------------------------------------
## Once the player is dead every creature in the room stops fighting and crowds
## the body. Nothing is left to threaten, and a swarm that keeps chasing a corpse
## it is standing on reads as the game having failed to notice.
##
## Each one takes a slot on a ring around the body, picked once, so the crowd
## forms a rough circle instead of a heap. The ring is loose and they lean in and
## out of it, because a perfect circle of monsters looks choreographed.
const MOURN_GAP_MIN: float = 34.0
const MOURN_GAP_MAX: float = 96.0
const MOURN_SPEED: float = 0.55
const MOURN_LEAN: float = 9.0

var _mourn: Node2D = null
var _mourn_angle: float = 0.0
var _mourn_radius: float = 0.0

var _brain_time: float = 0.0
## Per-instance so two chasers spawned in the same frame do not weave in unison.
var _attention_phase: float = 0.0
var _orbit_phase: float = 0.0
var _shot_timer: float = 0.0
## Charger phase: 0 resting//waiting, 1 winding up, 2 charging. Kept as a timer
## plus a phase rather than a state machine class -- three states with one
## transition each does not need one.
var _charge_phase: int = 0
var _charge_timer: float = 0.0
var _charge_dir: Vector2 = Vector2.RIGHT
## Wanderer heading, turned rather than re-picked, so the path is a drift.
var _wander_dir: Vector2 = Vector2.RIGHT
var _wander_turn_sign: float = 1.0
var _wander_timer: float = 0.0
## Skitter: which way this burst is going, whether it is running right now, and
## how long is left of whichever of the two it is doing.
var _skitter_dir: Vector2 = Vector2.ZERO
var _skitter_running: bool = false
var _skitter_timer: float = 0.0
## How long this burst has been making no progress. See _skitter_move.
var _skitter_stuck: float = 0.0
## Roller: its heading, its fume clock, and how long it has been getting nowhere.
var _roll_dir: Vector2 = Vector2.ZERO
var _fume_timer: float = 0.0
var _roll_stuck: float = 0.0
## How far round the can has tumbled. Advanced by DISTANCE travelled rather than
## by time, so a chilled can slows its spin instead of spinning on the spot.
var _roll_spin: float = 0.0
## Where in the walk-tip-roll-rise-spray cycle it is, and how long is left of it.
var _roll_phase: RollPhase = RollPhase.WALK
var _roll_timer: float = 0.0
## How far over the can is: 0 standing, 1 flat on its side. Drives the drawing
## only -- the behaviour reads the phase.
var _lie: float = 0.0
## Clock for the upright waddle.
var _waddle: float = 0.0
## Last direction it MEANT to travel, as a sign. Holds its value when it stops.
var _face_x: float = 0.0
## Shadow placement, measured off the sprite in _fit_shapes.
var _ground_offset: float = 0.0
var _shadow_width: float = 0.0


func _ready() -> void:
	# The BODY, as distinct from the hurtbox that sits in "enemies". Anything
	# that has to move an enemy rather than hurt it wants this one.
	add_to_group(&"enemy_bodies")
	health = max_health
	_attention_phase = randf() * TAU
	_orbit_phase = randf() * TAU
	# Randomised so a group of spitters does not volley on one beat.
	_shot_timer = shot_interval * randf()
	_wander_dir = Vector2.from_angle(randf() * TAU)
	_wander_turn_sign = 1.0 if randf() < 0.5 else -1.0
	_charge_timer = charge_rest * randf()

	# Per-instance material, or every enemy on the floor would crack, flash and
	# turn purple together -- they share one scene, and therefore one resource.
	_mat = (art.material as ShaderMaterial).duplicate()
	art.material = _mat
	_mat.set_shader_parameter("tint", body_color)
	_mat.set_shader_parameter("glow_tint", glow_color)
	_mat.set_shader_parameter("glow_amount", glow_amount)

	if behavior == Behavior.ROLLER:
		# Nothing to show and nothing to measure: the can is drawn in _draw, so
		# the sprite is switched off and the shapes are taken from can_size.
		art.visible = false
		_roll_timer = roll_walk_time * randf_range(0.4, 1.0)
		_waddle = randf() * TAU
		_fit_can()
		return

	if art.texture != null:
		art.scale = Vector2.ONE * (sprite_height / float(art.texture.get_height()))
	_fit_shapes()


## The same job _fit_shapes does, for the one creature that has no sprite to
## measure. Stated rather than derived, and centred on the origin the way an
## unoffset Sprite2D would be, so everything downstream -- shadow, contact range,
## the capsules -- reads the same numbers it always did.
func _fit_can() -> void:
	var rect := Rect2(-can_size * 0.5, can_size)
	SpriteFootprint.apply_capsule(hurt_shape, rect)
	# Pulled in like every other body: what the can pushes walls with is the
	# cylinder, not the nozzle and the rim.
	SpriteFootprint.apply_capsule(body_shape, rect, 0.72)
	radius = minf(rect.size.x, rect.size.y) * 0.5
	_ground_offset = rect.end.y - rect.size.y * 0.08
	_shadow_width = rect.size.x * 0.9


## Wraps both shapes around the creature that is actually drawn. The authored
## `radius` was a single number for two very differently shaped sprites -- a
## round virus and a long grub -- so one of them was always wrong.
##
## `radius` is kept, but re-derived: it is the contact-damage range, and that has
## to track the body or the enemy hurts you from a gap you can see through.
func _fit_shapes() -> void:
	var rect := SpriteFootprint.local_rect(art, self)
	if rect.size == Vector2.ZERO:
		return
	SpriteFootprint.apply_capsule(hurt_shape, rect)
	# The body that pushes against walls is pulled well in, for the same reason
	# the player's is: the drawn silhouette is spikes, tendrils and a cap, and
	# none of those are what stands on the floor. Still generous enough that a
	# creature walking straight at you does not snag on a doorway.
	SpriteFootprint.apply_capsule(body_shape, rect, 0.6)
	radius = minf(rect.size.x, rect.size.y) * 0.5
	# Where the creature meets the floor, and how wide it is there. Measured
	# once here rather than per frame in _draw: the sprite does not change shape.
	_ground_offset = rect.end.y - rect.size.y * 0.08
	_shadow_width = rect.size.x * 0.78


func _physics_process(delta: float) -> void:
	_hit_flash = maxf(_hit_flash - delta, 0.0)
	_tick_statuses(delta)

	_brain_time += delta

	# The wanderer is the one behaviour that does not care where the player is,
	# so it runs whether or not there is one to find.
	if behavior == Behavior.WANDERER:
		_step_wander(delta)

	var target := _find_player()

	# Checked here rather than pushed out by whatever killed the player, so a
	# creature that spawns after the death joins the crowd on its first frame
	# instead of charging a body nobody is driving.
	if target != null and target.has_method(&"is_dead") and target.is_dead():
		if _mourn == null:
			_begin_mourn(target)
	if _mourn != null and is_instance_valid(_mourn):
		_step_mourn(delta)
		return

	var desired := Vector2.ZERO
	if behavior == Behavior.WANDERER:
		desired = _wander_dir * move_speed * chill_factor()
	elif behavior == Behavior.ROLLER:
		# The one behaviour that does not consult the player at all AND is still
		# a threat. It is a can rolling across a floor; it does not know he is
		# there, which is exactly why it is frightening.
		desired = _roller_move(delta) * chill_factor()
	elif target != null:
		match behavior:
			Behavior.SPITTER:
				desired = _spitter_move(target) * move_speed * chill_factor()
				_tick_spit(delta, target)
			Behavior.CHARGER:
				desired = _charger_move(delta, target) * chill_factor()
			Behavior.SKITTER:
				desired = _skitter_move(delta, target) * move_speed * chill_factor()
				_tick_skitter_shot(delta, target)
			_:
				desired = _chaser_move(target) * move_speed * chill_factor()

	# Latched off INTENT, not off the body: knockback and wall slides push the
	# velocity around, and a creature shoved sideways has not changed its mind
	# about where it is going.
	var face_source := desired
	if behavior == Behavior.CHARGER and _charge_phase == 1 and target != null:
		# Winding up it is not moving at all, but it is very much aimed.
		face_source = target.global_position - global_position
	if absf(face_source.x) > 4.0:
		_face_x = signf(face_source.x)

	# Contact damage is opt-out through the stat: the wanderer is set to 0 and so
	# is simply in the way, which is the whole point of it.
	if target != null and _contact_now() > 0.0 \
			and global_position.distance_to(target.global_position) < radius + 16.0:
		target.take_damage(_contact_now(), (target.global_position - global_position).normalized() * 220.0, {}, false)

	velocity = desired + _knock
	_knock = _knock.move_toward(Vector2.ZERO, 1200.0 * delta)
	move_and_slide()
	_update_art()


## Picks this creature's place in the crowd. Angle is random per instance and
## the ring sits just outside its own body, so a big thing stands further back
## than a grub and the circle does not close into a pile.
func _begin_mourn(body: Node2D) -> void:
	_mourn = body
	_mourn_angle = randf() * TAU
	_mourn_radius = radius + randf_range(MOURN_GAP_MIN, MOURN_GAP_MAX)
	# Whatever it was mid-way through doing, it is not doing it now.
	_charge_phase = 0
	_charge_timer = charge_rest


## Walk to the slot, then stand there and breathe, facing the body. Slow: the
## whole read is that the fight is over.
func _step_mourn(delta: float) -> void:
	var slot := _mourn.global_position \
		+ Vector2.from_angle(_mourn_angle) * (_mourn_radius + sin(_brain_time * 1.1 + _orbit_phase) * MOURN_LEAN)
	var to_slot := slot - global_position
	var desired := Vector2.ZERO
	# Dead band, or twenty bodies jitter against each other on the spot forever.
	if to_slot.length() > 6.0:
		desired = to_slot.normalized() * move_speed * MOURN_SPEED * chill_factor()

	# Faces inward once parked, so the ring is looking AT him rather than
	# whichever way each one happened to arrive.
	var face_source := to_slot if desired != Vector2.ZERO else (_mourn.global_position - global_position)
	if absf(face_source.x) > 4.0:
		_face_x = signf(face_source.x)

	velocity = desired + _knock
	_knock = _knock.move_toward(Vector2.ZERO, 1200.0 * delta)
	move_and_slide()
	_update_art()


## Rest, wind up, commit, rest again. The direction is locked when the windup
## ENDS, not while it runs -- a charge that tracks you through its own telegraph
## is a homing missile with extra steps, and there would be nothing to dodge.
##
## Returns a velocity, not a unit vector: the charge has its own speed, and the
## other two phases have none at all.
func _charger_move(delta: float, target: Node2D) -> Vector2:
	_charge_timer -= delta
	match _charge_phase:
		1:
			if _charge_timer <= 0.0:
				_charge_phase = 2
				_charge_timer = charge_time
				_charge_dir = (target.global_position - global_position).normalized()
			# Braced, not drifting. Standing still IS the tell.
			return Vector2.ZERO
		2:
			if _charge_timer <= 0.0:
				_charge_phase = 0
				_charge_timer = charge_rest
				return Vector2.ZERO
			return _charge_dir * move_speed * charge_speed_mult
		_:
			if _charge_timer <= 0.0 \
					and global_position.distance_to(target.global_position) <= charge_range:
				_charge_phase = 1
				_charge_timer = charge_windup
			# Creeps while it recovers, so a resting one is not a statue.
			return (target.global_position - global_position).normalized() * move_speed * 0.25


## The wanderer's heading: a constant turn in one direction, with a fresh random
## turn rate every `wander_retarget` seconds. That combination is what reads as
## a weird organic path rather than as either a circle or a drunkard's walk.
##
## Room walls are handled by move_and_slide, and the heading is reflected off
## whatever it slid along, so it does not grind along a wall forever.
func _step_wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = wander_retarget * (0.6 + randf() * 0.8)
		_wander_turn_sign = 1.0 if randf() < 0.5 else -1.0
	_wander_dir = _wander_dir.rotated(wander_turn * _wander_turn_sign * delta).normalized()

	# Bounced off the wall it just hit, using the collision from LAST frame's
	# move_and_slide -- the heading is what steers, so it is what has to turn
	# around.
	if get_slide_collision_count() > 0:
		var n := get_slide_collision(0).get_normal()
		if _wander_dir.dot(n) < 0.0:
			_wander_dir = _wander_dir.bounce(n).normalized()


## Where the chaser thinks the player is. It orbits the real player and breathes
## in and out of them, and the whole offset is scaled down by how close the enemy
## already is -- so the path curves while it is crossing the room and straightens
## out into a real attack before it arrives. It cannot circle forever: the offset
## is bounded and vanishes inside `attention_commit_range`.
func _attention_point(target: Node2D) -> Vector2:
	var to_target := target.global_position - global_position
	var dist := to_target.length()
	if dist <= attention_commit_range:
		return target.global_position

	# 0 at the commit range, 1 once the enemy is a couple of radii further out.
	var closeness := clampf(
		(dist - attention_commit_range) / maxf(attention_radius, 1.0), 0.0, 1.0
	)
	# Breathes through zero, so the point passes through the player twice a
	# period rather than only ever hovering beside them.
	var breath := sin(_brain_time * TAU / maxf(attention_period, 0.05) + _attention_phase)
	var angle := _orbit_phase + _brain_time * attention_orbit_speed
	return target.global_position \
		+ Vector2.from_angle(angle) * attention_radius * breath * closeness


func _chaser_move(target: Node2D) -> Vector2:
	return (_attention_point(target) - global_position).normalized()


## Spitter footwork: close to `shot_range`, back off inside `standoff_range`,
## and strafe in the band between the two so it is not a stationary turret.
## Panic, as a movement. Bolts for `skitter_burst` seconds, stands still for a
## moment, then picks a fresh direction and bolts again.
##
## The direction is mostly away from the player and partly random, so it is
## neither a clean retreat -- which would back into a wall and stay there -- nor
## a pure wander, which would have it running cheerfully into him. Rerolled every
## burst rather than steered continuously: something that corrects its heading
## while it runs looks like it has a plan.
func _skitter_move(delta: float, target: Node2D) -> Vector2:
	_skitter_timer -= delta
	if _skitter_timer <= 0.0:
		if _skitter_running:
			_skitter_running = false
			_skitter_timer = randf_range(skitter_rest_min, skitter_rest_max)
		else:
			_skitter_running = true
			_skitter_timer = skitter_burst
			_skitter_dir = _pick_skitter_dir(target)
	if not _skitter_running:
		return Vector2.ZERO

	# Bail out of a burst that has stopped going anywhere. Fleeing straight at a
	# wall used to run the full burst against it and then reroll into the same
	# quadrant, over and over -- so a scientist backed into a corner stayed there
	# grinding, which is neither scared nor threatening, just broken. Measured on
	# actual travel, so it catches cover and other bodies too, not only walls.
	if velocity.length() < move_speed * 0.3:
		_skitter_stuck += delta
		if _skitter_stuck > 0.15:
			_skitter_stuck = 0.0
			_skitter_dir = _pick_skitter_dir(target)
	else:
		_skitter_stuck = 0.0
	return _skitter_dir


## A direction to bolt in: mostly away from the player, partly panic, and never
## into a wall if there is any option that is not.
##
## Candidates are rejected by looking ahead rather than by steering away from
## anything. A scared thing does not follow a wall to its end -- it tries a way
## out, finds it blocked, and tries another, which is what the retry loop is.
func _pick_skitter_dir(target: Node2D) -> Vector2:
	var away := (global_position - target.global_position).normalized()
	if away == Vector2.ZERO:
		away = Vector2.from_angle(randf() * TAU)
	var room := get_parent() as Room
	var first := Vector2.ZERO

	for i in SKITTER_TRIES:
		var panic := Vector2.from_angle(randf() * TAU)
		var candidate := away.lerp(panic, 1.0 - skitter_flee_bias).normalized()
		if room == null:
			return candidate
		if first == Vector2.ZERO:
			first = candidate
		# Far enough ahead to cover a whole burst, so it does not commit to a
		# direction that is clear for one frame and a wall for the rest of it.
		var ahead := global_position + candidate * (radius + SKITTER_LOOKAHEAD)
		if room.contains_world_point(ahead):
			return candidate

	# Every way it fancied is into something. Head for the middle of the room --
	# the one direction that is always open from anywhere along an edge, and the
	# reading is right too: cornered, it breaks cover across the floor.
	if room != null:
		var middle := room.to_global(room.interior * 0.5) - global_position
		if middle.length_squared() > 1.0:
			return middle.normalized()
	return first if first != Vector2.ZERO else away


## The wild shot. Fired on the spitter's own timer and through the same range and
## on-screen rules, but aimed anywhere inside a wide cone rather than at him --
## the danger is the volume of darts in the air, not any one of them.
func _tick_skitter_shot(delta: float, target: Node2D) -> void:
	if shot_stats == null:
		return
	_shot_timer -= delta * chill_factor()
	if _shot_timer > 0.0:
		return
	if global_position.distance_to(target.global_position) > shot_range:
		return
	if not _is_on_screen():
		return
	_shot_timer = shot_interval
	var stats := shot_stats.duplicate_stats()
	stats.lifetime = maxf(stats.lifetime, shot_range / maxf(stats.speed, 1.0))
	var aim := (target.global_position - global_position).normalized()
	aim = aim.rotated(deg_to_rad(randf_range(-skitter_spray, skitter_spray)))
	var p := PROJECTILE_SCENE.instantiate() as Projectile
	# Hunting the PLAYER, like any other enemy shot. That its damage is near zero
	# is a property of the stat block, not of who it is looking for -- see the
	# scientist's row in Room.BESTIARY.
	p.setup(stats, aim, &"player")
	p.global_position = global_position
	get_tree().current_scene.add_child(p)


## Rolls. There is no target in this at all: it picks a heading once and keeps
## it, turning only when it runs out of room.
##
## Bounced off the room rather than killed by it, because a can that dies at the
## first wall is a hazard that clears itself. The bounce is off the room's
## outline, not off the collision it is already sliding along -- a body that has
## been stopped by a wall has a velocity that says nothing about which way the
## wall faced.
func _roller_move(delta: float) -> Vector2:
	if _roll_dir == Vector2.ZERO:
		_roll_dir = _pick_roll_dir()

	_roll_timer -= delta
	if _roll_timer <= 0.0:
		_advance_roll_phase()

	# How far over it is, 0 upright and 1 flat. Driven off the phase clock rather
	# than eased toward a target, so the topple always takes exactly as long as
	# the phase it belongs to and the drawing cannot fall behind the behaviour.
	match _roll_phase:
		RollPhase.TIP:
			_lie = 1.0 - clampf(_roll_timer / maxf(roll_tip_time, 0.001), 0.0, 1.0)
		RollPhase.ROLL:
			_lie = 1.0
		RollPhase.RISE:
			_lie = clampf(_roll_timer / maxf(roll_rise_time, 0.001), 0.0, 1.0)
		_:
			_lie = 0.0

	if _roll_phase == RollPhase.SPRAY:
		_lay_fumes(delta)

	# Everything below is the rolling phase only. Standing up, toppling and
	# venting are all done from a standstill: the can has to be somewhere the
	# player can see it stop, or the cycle is not readable.
	if _roll_phase != RollPhase.ROLL:
		if _roll_phase == RollPhase.WALK:
			return _walk_roller(delta)
		return Vector2.ZERO

	_steer_roll(delta)
	# Rolling without slipping: a can of this width turns once per its own
	# circumference of travel, which is what makes the spin agree with the speed.
	_roll_spin += velocity.length() * delta / maxf(can_size.x * 0.5, 1.0)
	_shove_neighbours()
	return _roll_dir * move_speed * roll_speed_mult


## The upright shuffle. Slow, and it wanders rather than heading anywhere -- a
## can that walked purposefully at the player would be a chaser wearing a hat.
func _walk_roller(delta: float) -> Vector2:
	_waddle += delta
	if not _ahead_clear(_roll_dir, radius + 30.0):
		_roll_dir = _pick_roll_dir()
	# Weaves as it waddles, because it is balancing on a rim and should look it.
	var sway := _roll_dir.rotated(sin(_waddle * 5.5) * 0.35)
	return sway * move_speed * roll_walk_mult


## Keeps a roll inside the room and out of whatever it has jammed itself against.
func _steer_roll(delta: float) -> void:
	# Stuck: it has been pushed into something and is not making progress. Turn,
	# rather than grind. Measured on ACTUAL travel, so it catches a corner the
	# outline test does not know about -- a cover blob, another creature, a plug.
	if velocity.length() < move_speed * roll_speed_mult * 0.25:
		_roll_stuck += delta
		if _roll_stuck > 0.3:
			_roll_stuck = 0.0
			_roll_dir = _roll_dir.rotated(randf_range(PI * 0.55, PI * 1.45))
	else:
		_roll_stuck = 0.0

	if not _ahead_clear(_roll_dir, radius + 24.0):
		var room := get_parent() as Room
		if room != null:
			# Reflected off the line back to the room's middle, which is the
			# cheapest stand-in for the wall's normal and is right for anything
			# that is not a corner.
			var inward := (room.to_global(room.interior * 0.5) - global_position).normalized()
			if inward != Vector2.ZERO:
				_roll_dir = _roll_dir.bounce(inward.orthogonal()).normalized()


func _ahead_clear(dir: Vector2, distance: float) -> bool:
	var room := get_parent() as Room
	if room == null:
		return true
	return room.contains_world_point(global_position + dir * distance)


## Somewhere it can actually go. Falls back to the middle of the room, which is
## open from anywhere along an edge.
func _pick_roll_dir() -> Vector2:
	for i in 6:
		var candidate := Vector2.from_angle(randf() * TAU)
		if _ahead_clear(candidate, radius + 60.0):
			return candidate
	var room := get_parent() as Room
	if room != null:
		var middle := room.to_global(room.interior * 0.5) - global_position
		if middle.length_squared() > 1.0:
			return middle.normalized()
	return Vector2.from_angle(randf() * TAU)


## Walk, topple, roll, stand, vent, repeat. A fresh heading is chosen as it goes
## over rather than while it is down, so the direction it rolls is settled before
## the roll starts and the topple is an honest warning of where it is going.
func _advance_roll_phase() -> void:
	match _roll_phase:
		RollPhase.WALK:
			_roll_phase = RollPhase.TIP
			_roll_timer = roll_tip_time
			_roll_dir = _pick_roll_dir()
		RollPhase.TIP:
			_roll_phase = RollPhase.ROLL
			_roll_timer = roll_time
		RollPhase.ROLL:
			_roll_phase = RollPhase.RISE
			_roll_timer = roll_rise_time
		RollPhase.RISE:
			_roll_phase = RollPhase.SPRAY
			_roll_timer = roll_spray_time
			# Vents immediately on standing rather than after one interval, so
			# the first puff lands on the beat it stands up.
			_fume_timer = 0.0
		_:
			_roll_phase = RollPhase.WALK
			_roll_timer = roll_walk_time
			_roll_dir = _pick_roll_dir()


## The can is only dangerous to touch while it is on its side. Upright it is
## something in the room; rolling it is a thing that will run you over.
func _contact_now() -> float:
	if behavior == Behavior.ROLLER and _roll_phase != RollPhase.ROLL:
		return 0.0
	return contact_damage


## Drops the trail. One puff every `roll_fume_interval` rather than per frame, so
## the vent is a cluster of clouds to thread rather than one solid disc.
func _lay_fumes(delta: float) -> void:
	_fume_timer -= delta
	if _fume_timer > 0.0:
		return
	_fume_timer = roll_fume_interval
	var room := get_parent() as Room
	if room == null:
		return
	# Thrown out to one side rather than dropped underneath: it is spraying, not
	# leaking, and a puff centred on the can is hidden by it.
	var vent := Vector2.from_angle(randf() * TAU) * randf_range(10.0, can_size.y * 0.55)
	room.drop_fumes(position + Vector2(0.0, _ground_offset * 0.4) + vent, roll_fume_life)


## Barges other creatures out of the way. The only thing in the bestiary that
## moves anything but the player: it is a pressurised metal cylinder and they are
## made of protein, and a can that politely collided with a grub would read as
## much lighter than it looks.
func _shove_neighbours() -> void:
	for n in get_tree().get_nodes_in_group(&"enemy_bodies"):
		var other := n as Node2D
		if other == null or other == self or not other.has_method(&"push"):
			continue
		var away := other.global_position - global_position
		var dist := away.length()
		if dist > roll_shove_range or dist < 0.001:
			continue
		# Falls off with distance, so a creature clipped by the edge is nudged
		# and one run over squarely is thrown.
		other.push(away / dist * roll_shove * (1.0 - dist / roll_shove_range))


func _spitter_move(target: Node2D) -> Vector2:
	var to_target := target.global_position - global_position
	var dist := to_target.length()
	if dist < 0.001:
		return Vector2.ZERO
	var dir := to_target / dist
	if dist > shot_range:
		return dir
	if dist < standoff_range:
		return -dir
	# Which way it strafes is fixed per instance by the orbit phase, so it does
	# not jitter left-right on the spot.
	var side := 1.0 if sin(_orbit_phase) >= 0.0 else -1.0
	return dir.orthogonal() * side * 0.6


func _tick_spit(delta: float, target: Node2D) -> void:
	if shot_stats == null:
		return
	# Cold slows the spit as well as the legs, same as the boss.
	_shot_timer -= delta * chill_factor()
	if _shot_timer > 0.0:
		return
	if global_position.distance_to(target.global_position) > shot_range:
		return
	if not _is_on_screen():
		return
	_shot_timer = shot_interval
	_fire_spit(target)


func _fire_spit(target: Node2D) -> void:
	var stats := shot_stats.duplicate_stats()
	# Long reach is bought with lifetime, not speed: the shot has to stay slow
	# enough to walk out of, and `shot_range` is the number that was tuned.
	stats.lifetime = maxf(stats.lifetime, shot_range / maxf(stats.speed, 1.0))
	var p := PROJECTILE_SCENE.instantiate() as Projectile
	p.setup(stats, (target.global_position - global_position).normalized(), &"player")
	p.global_position = global_position
	get_tree().current_scene.add_child(p)


## True when the enemy itself is inside the visible frame. Checked on the
## shooter rather than the player, because the rule is about where the shot
## comes from -- an unseen thing firing out of the dark is the bad case.
func _is_on_screen() -> bool:
	var vp := get_viewport()
	if vp == null:
		return false
	var screen_pos := get_global_transform_with_canvas().origin
	return vp.get_visible_rect().grow(-ON_SCREEN_MARGIN).has_point(screen_pos)


## The charger's telegraph: a ring that collapses onto the body as the windup
## runs out, so "it goes NOW" is readable without counting frames.
##
## Drawn on the enemy rather than left to the pose. A braced fungus and a resting
## one differ by very little at 88px on a busy floor, and the whole creature is a
## question of whether the player moved in time.
func _draw() -> void:
	# One flat ellipse under the body, sized off the measured footprint so it
	# tracks whatever creature the sprite happens to be. Deliberately not
	# animated: enemies here have no legs to speak of and a shadow that breathes
	# on twenty bodies at once is noise, not depth.
	if behavior == Behavior.ROLLER:
		# The footprint changes with the pose: standing, the can covers its own
		# width; flat, it covers its whole length. A shadow that stayed the
		# upright size while the body lay down was the clearest tell that the
		# thing on the floor was a sprite doing a trick.
		Lighting.draw_shadow(self, Vector2(0.0, _ground_offset),
			lerpf(_shadow_width, can_size.y * 0.92, _lie))
	else:
		Lighting.draw_shadow(self, Vector2(0.0, _ground_offset), _shadow_width)

	# Before the sprite, which is a CHILD -- a parent's own _draw runs first, so
	# this lands behind the body rather than washing over it. Same trick the
	# shadow above is already relying on.
	if glow_amount > 0.0:
		_draw_glow()

	if behavior == Behavior.ROLLER:
		_draw_can()
		return

	if behavior != Behavior.CHARGER or _charge_phase != 1:
		return
	var t := 1.0 - clampf(_charge_timer / maxf(charge_windup, 0.01), 0.0, 1.0)
	draw_arc(Vector2.ZERO, radius + 22.0 * (1.0 - t), 0.0, TAU, 28,
		Color(1.0, 0.95, 0.7, 0.35 + 0.5 * t), 2.5)


## The halo. Three rings rather than one disc: a single translucent circle reads
## as a coin behind the body, and stacking a small bright one inside a wide faint
## one is what gives it a soft edge and no visible rim.
##
## Breathes on its own clock, deliberately not on the gait or the shot timer --
## it is the thing giving off light, not the thing doing something.
func _draw_glow() -> void:
	var r := maxf(sprite_height, 1.0) * 0.5
	var pulse := 1.0 + GLOW_PULSE * sin(_brain_time * GLOW_PULSE_RATE)
	var reach := r * (1.0 + GLOW_REACH) * pulse
	draw_circle(Vector2.ZERO, reach, Color(glow_color, 0.10 * glow_amount))
	draw_circle(Vector2.ZERO, reach * 0.66, Color(glow_color, 0.16 * glow_amount))
	draw_circle(Vector2.ZERO, reach * 0.38, Color(glow_color, 0.22 * glow_amount))


## The aerosol can, as geometry. Tumbling end over end while it travels, which is
## the only thing that says "this is rolling at you" rather than "this is sliding
## at you" -- a cylinder that keeps its label upright reads as a lift, not a roll.
## The can, upright or on its side or somewhere between.
##
## Drawn in a local frame whose +Y is the can's own long axis, so there is one
## description of the can and the pose is entirely in the transform. Upright that
## frame is unrotated; flat, it is turned so the long axis lies ACROSS the
## direction of travel -- which is what a can on a table does, because that is
## the only axis it can roll about.
##
## The body never spins on screen. It used to rotate about its own centre, which
## is a can pirouetting on its base rather than rolling: the giveaway was that it
## looked identical travelling in any direction. What turns is the SURFACE -- the
## bands wrap around the barrel and slide across it -- and that is the whole read
## of "this is rolling towards me".
func _draw_can() -> void:
	var r := can_size.x * 0.5
	var l := can_size.y * 0.5

	var perp := _roll_dir.orthogonal()
	if perp == Vector2.ZERO:
		perp = Vector2.RIGHT
	# Local +Y already points at PI/2, so this is the turn that takes the long
	# axis onto the roll's cross-axis.
	var tilt := lerp_angle(0.0, perp.angle() - PI * 0.5, _lie)
	# The upright wobble, faded out as it goes over -- something balancing on a
	# rim should look like it is, and something lying down has nothing to wobble.
	tilt += sin(_waddle * 5.5) * 0.12 * (1.0 - _lie)
	# Sinks as it topples: lying down, its middle is a radius off the floor
	# rather than half its length.
	draw_set_transform(Vector2(0.0, (l - r) * _lie * 0.55), tilt, Vector2.ONE)

	draw_rect(Rect2(-r, -l * 0.78, r * 2.0, l * 1.78), can_body)
	# Rounded ends, so the silhouette is a cylinder from any angle rather than a
	# box that happens to be tall.
	draw_circle(Vector2(0.0, l * 0.98), r, can_body.darkened(0.2))
	draw_circle(Vector2(0.0, -l * 0.78), r, can_body.lightened(0.12))
	# The spray head. The one part that says what this cylinder is, so it stays
	# proud of the body and keeps its own colour at any pose.
	draw_rect(Rect2(-r * 0.62, -l, r * 1.24, l * 0.26), can_cap)
	draw_rect(Rect2(-r * 0.2, -l * 1.14, r * 0.4, l * 0.18), can_cap.lightened(0.15))

	# The bands, wrapped around the barrel. A band sitting at angle `theta` on a
	# cylinder is seen at `r * sin(theta)` across it and is hidden altogether
	# once it has gone round the back, which is the `cos <= 0` test -- so they
	# bunch up and vanish at the edges exactly as paint on a real can would.
	var band := can_cap.darkened(0.3)
	for i in CAN_BANDS:
		var theta := _roll_spin + TAU * float(i) / float(CAN_BANDS)
		var facing := cos(theta)
		if facing <= 0.0:
			continue
		var across := r * sin(theta)
		draw_line(Vector2(across, -l * 0.7), Vector2(across, l * 0.9),
			Color(band, facing), 1.0 + 3.0 * facing)
	draw_set_transform(Vector2.ZERO)


## Shoved by something that is not an attack -- a cramping wall, for now.
## Reuses the knockback channel, so it decays exactly like being hit does.
func push(impulse: Vector2) -> void:
	_knock = impulse


func _update_art() -> void:
	# The shadow is static, but the telegraph ring is not, and neither is a
	# tumbling can. Both live in the same _draw, and only these two have any
	# reason to keep redrawing.
	if behavior == Behavior.CHARGER or behavior == Behavior.ROLLER or glow_amount > 0.0:
		queue_redraw()
	_mat.set_shader_parameter("damage", _damage_ratio())
	# Fades out over the window instead of switching off, so a fast weapon reads
	# as a stream of taps rather than a strobe.
	_mat.set_shader_parameter("flash", flash_strength * (_hit_flash / _hit_flash_len))
	# One status colour channel, so frozen wins over poisoned: being unable to
	# move is the more urgent thing for the player to read off the sprite.
	if _statuses.has("freeze"):
		_mat.set_shader_parameter("status_tint", FREEZE_TINT)
		# A lock and a slow are now different things and have to look it, or the
		# player cannot tell "it stopped" from "it is wading" until they have
		# watched it for a second -- which is a second spent not deciding.
		_mat.set_shader_parameter("status_amount", 0.65 if is_frozen() else 0.32)
	elif _statuses.has("poison"):
		_mat.set_shader_parameter("status_tint", POISON_TINT)
		_mat.set_shader_parameter("status_amount", 0.5)
	else:
		_mat.set_shader_parameter("status_amount", 0.0)

	# Face the way it is going: the eye leads, always. Driven off `_face_x`, which
	# holds the last direction it MEANT to go, so a charger braced mid-windup and
	# a spitter backing off both keep looking at the player instead of snapping
	# square whenever their velocity passes through zero.
	if art_facing != 0.0 and _face_x != 0.0:
		art.scale.x = absf(art.scale.x) * (1.0 if _face_x == art_facing else -1.0)


## Damage as the shader wants it: 0 until the enemy is genuinely hurt, then
## ramping to 1 at death. Mapping health straight through would put hairline
## cracks on something that has taken a single graze, and the cracks are meant to
## be the "this one is nearly done" signal that replaced the shrinking core.
func _damage_ratio() -> float:
	var frac := clampf(health / maxf(max_health, 0.001), 0.0, 1.0)
	if frac >= CRACK_THRESHOLD:
		return 0.0
	return (CRACK_THRESHOLD - frac) / CRACK_THRESHOLD


## Movement multiplier from the freeze status. Normally a wade; on a lucky roll,
## a full stop. Potency stacks, so more nitrogen bites deeper without a stack
## ever reaching zero on its own.
##
## Large things ignore the lock entirely and only ever wade, which is the same
## deal a boss got before any of this and for the same reason.
func chill_factor() -> float:
	if not _statuses.has("freeze"):
		return 1.0
	var potency: float = _statuses["freeze"][0]
	if is_large:
		return clampf(1.0 - CHILL_LARGE_SLOW * potency, CHILL_LARGE_FLOOR, 1.0)
	if is_frozen():
		return 0.0
	return clampf(1.0 - CHILL_SLOW * potency, CHILL_FLOOR, 1.0)


func is_mourning() -> bool:
	return _mourn != null and is_instance_valid(_mourn)


## Locked solid, not merely chilled. The distinction matters to anything asking
## "can this thing act at all", so the name keeps the stronger meaning and being
## slowed answers false.
func is_frozen() -> bool:
	if not _statuses.has("freeze"):
		return false
	var entry: Array = _statuses["freeze"]
	return entry.size() > 2 and bool(entry[2])


func _find_player() -> Node2D:
	var list := get_tree().get_nodes_in_group(&"player_body")
	return list[0] as Node2D if list.size() > 0 else null


func _tick_statuses(delta: float) -> void:
	if _statuses.is_empty():
		return
	_poison_tick -= delta
	var expired: Array[String] = []
	for id: String in _statuses:
		var entry: Array = _statuses[id]
		entry[1] -= delta
		if entry[1] <= 0.0:
			expired.append(id)
	if _poison_tick <= 0.0:
		_poison_tick = 0.5
		if _statuses.has("poison"):
			_apply_health_loss(_statuses["poison"][0] * 0.5)
	for id in expired:
		_statuses.erase(id)


func take_damage(amount: float, knockback: Vector2, statuses: Dictionary, is_crit: bool) -> void:
	_knock = knockback
	_hit_flash_len = 0.12 if not is_crit else 0.2
	_hit_flash = _hit_flash_len
	for id: String in statuses:
		# Reapplying refreshes duration and takes the stronger potency.
		var potency: float = statuses[id]
		if _statuses.has(id):
			potency = maxf(potency, _statuses[id][0])
		var duration := 3.0
		if id == "freeze":
			# Rolled per application, not once per status: "small chance of
			# freezing" has to mean a chance on every hit, or a stream weapon
			# would settle the question on its first shot and every shot after
			# would be decided by it. Re-rolling also means an unlucky slow can
			# turn into a lock while it is still running.
			var odds := minf(FREEZE_LOCK_CHANCE * potency, FREEZE_LOCK_CHANCE_MAX)
			var locked := randf() < odds
			duration = FREEZE_LOCK_TIME + FREEZE_LOCK_TIME_PER * potency if locked \
				else FREEZE_SLOW_TIME + FREEZE_SLOW_TIME_PER * potency
			# A lock in progress is never downgraded by a later unlucky hit --
			# that would read as the ice giving out for no reason.
			if is_frozen():
				locked = true
			_statuses[id] = [potency, duration, locked]
			continue
		_statuses[id] = [potency, duration]
	_apply_health_loss(amount)


func _apply_health_loss(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		_spill_blood()
		_drop_dna()
		queue_free()


## Scatters this creature's worth across the floor as motes. Broken into several
## rather than dropped as one token: DNA has to be something you walk THROUGH,
## and the trail is what makes clearing a room feel paid for.
func _drop_dna() -> void:
	var room := get_parent() as Room
	if room == null:
		return
	var ground := position + Vector2(0.0, _ground_offset * 0.5)
	var left := dna_value if dna_value > 0 \
		else (DnaBalance.LARGE if is_large else DnaBalance.SMALL)
	while left > 0:
		var chunk := mini(left, DnaBalance.MOTE_MAX_VALUE)
		room.drop_dna(ground, chunk)
		left -= chunk


## What this creature leaves behind. Its own colour, deepened: a pool is the
## same fluid seen thick and wet, so a green thing bleeds green and the floor
## after a fight reads as an inventory of what was in the room.
##
## Sized off the measured footprint rather than off health, because the pool is
## a body's worth of fluid and a small elite is still a small body. Large things
## throw a couple of extra splats around the main one -- one giant circle reads
## as a puddle painted on, several overlapping ones read as something burst.
func _spill_blood() -> void:
	var room := get_parent() as Room
	if room == null:
		return
	# On the floor under it, not at its middle: `_ground_offset` is where the
	# sprite meets the ground and is what everything else on this creature (its
	# shadow) is already anchored to.
	var ground := position + Vector2(0.0, _ground_offset * 0.5)
	var col := body_color.darkened(0.15)
	room.spill_blood(ground, col, radius * 1.7)
	if is_large:
		for i in 3:
			room.spill_blood(ground + Vector2.from_angle(randf() * TAU) * radius * randf_range(0.8, 1.6),
				col, radius * randf_range(0.7, 1.2))


## Swaps in a different creature. Called before the node enters the tree, so it
## must not touch `art` -- the @onready has not run yet.
func set_art(texture: Texture2D) -> void:
	if texture == null:
		return
	if is_node_ready():
		art.texture = texture
		art.scale = Vector2.ONE * (sprite_height / float(texture.get_height()))
		# A different creature is a different shape, so the hitbox is re-measured
		# rather than kept from whatever the scene shipped with.
		_fit_shapes()
	else:
		# Stash it on the node itself; _ready reads whatever the sprite holds.
		($Art as Sprite2D).texture = texture
