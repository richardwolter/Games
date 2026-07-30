class_name Berserker
extends Villain
## Mobile, aggressive, high HP. Pursues relentlessly — no phases.
##
## Berserker is the opposite of Dark Mage (stationary). He walks down the
## nearest hero and hits hard on a slow, telegraphed swing.
##
## The charge/recover cycle was removed 2026-07-26 (Designer): he used to freeze
## in place for a recovery beat between charges, which is the only reason his
## raw numbers were tuned as high as they were. What used to keep him fair was
## that rhythm; what keeps him fair now is speed and damage, both rebalanced for
## the removal — see berserker.tscn for the arithmetic. His leash (below) is now
## the thing that defines where the fight happens, so tune leash_radius before
## reaching for move_speed if he feels inescapable.

## Hand-drawn villain art (Designer, 2026-07-25), same papercut treatment as
## DarkMage1 — see Hero.HERO_SPRITES for the pipeline note.
const SPRITE := preload("res://assets/sprites/Berserk_Villain_Color.png")

## How often (seconds) the field-wide hunt goal is re-evaluated.
const HUNT_INTERVAL := 0.3

## -- Shoving his own swarm (Designer, 2026-07-26) ------------------------------
## "Instead of hitting minions he just pushes them aside." He never damaged them
## — his enemy_group is "heroes" and the thrown boulders are narrowed to heroes
## too, so nothing had to be taken away. What he DID do was wade through his own
## swarm as if it weren't there: Combatant._update_separation skips every unit
## that has a target (see its doc), which in a real fight is all of them, so the
## Berserker and a dozen minions simply overlapped.
##
## He now displaces THEM rather than being slowed or hidden by them, which is
## what a brute walking through his own mob should look like. Deliberately
## one-directional: the minions move, he does not, so his charge line never
## bends around his own side.
const SHOVE_SPEED := 260.0
## Extra clearance past the two bodies touching, so a shoved minion ends up
## visibly out of his way rather than scraping along his edge.
const SHOVE_MARGIN := 10.0

## -- Lair leash (Designer, 2026-07-26) ----------------------------------------
## He now holds his ground near the lair instead of chasing a hero across the
## whole lane. Same fixed-lair reasoning as the Dark Mage's leash: a villain
## that follows the party backwards drags the fight away from the objective and
## resets whatever progress the push had made.
##
## Wider than the Dark Mage's 520 because the Berserker is a melee threat and
## still has to be able to reach someone — the leash is meant to define his
## territory, not pin him to a spot. The thrown boulders below are what let him
## keep pressuring heroes who stay outside it.
@export var leash_radius := 700.0
## The LAIR STRUCTURE itself (LaneField.lair_pos), not where he spawns.
##
## Was his spawn position until 2026-07-28 (Designer: "bring the berserk a bit
## closer to his lair, we can't even see it when battle happens"). Spawn sits
## VILLAIN_LAIR_OFFSET (300px) in FRONT of the lair, so anchoring the leash
## there let him hold ground 300 + leash_radius = 1000px away from the
## structure. The camera frames 1920/zoom world px — ±960 at default zoom — so
## the lair fell off the edge of the screen exactly when the fight reached the
## far end of his territory.
##
## Anchoring to the structure pulls that worst case to leash_radius (700), which
## fits inside the ±960 half-view, so the lair stays on screen for the whole
## fight. leash_radius itself is deliberately untouched — his territory is the
## same SIZE, it is just centred on the thing it was always described as being
## centred on. Tighten that export if you want the fight held closer still.
##
## Falls back to his spawn position (the old behaviour) if the field is somehow
## missing, so a scene opened without a LaneField still leashes to something
## sane instead of the origin.
var _lair := Vector2.ZERO

## -- Thrown boulders (Designer, 2026-07-26) -----------------------------------
## Smaller cousins of the lane-rolling boulder, aimed at a hero. Reuses
## RollingBoulder wholesale: it already pierces (it damages everything it
## overlaps and keeps going, with one hit per victim), which is exactly the
## behaviour asked for — so the throw is a retune of an existing object, not a
## new projectile type.
##
## Narrowed to "heroes" unlike the environmental roll, which deliberately mows
## down his own swarm too: this one is his attack, and a villain whose ranged
## option kills his own minions would fight against the level's own pressure.
const BOULDER_SCRIPT := preload("res://scenes/hazards/rolling_boulder.gd")
@export var boulder_interval := 3.2
## Roughly a third of the lane boulder's 95 — "smaller boulders".
@export var boulder_radius := 34.0
@export var boulder_damage := 14.0
@export var boulder_speed := 330.0
## Only thrown at heroes beyond melee reach; inside that he just swings, which
## hits harder. Capped so he can't snipe across the whole lane.
@export var boulder_min_range := 140.0
@export var boulder_max_range := 900.0

var _hunt_cd := 0.0
var _boulder_cd := 0.0

## -- Roar (Designer, 2026-07-26) ----------------------------------------------
## Plays once when the party first wakes him, and on his melee swings after
## that. Rate-limited on its own clock rather than firing every swing: at a
## 1.1s attack_interval an unlimited roar would be a continuous loop for the
## whole fight.
const ROAR_SOUND: AudioStream = preload("res://assets/Sounds/Berserk_Roar.mp3")
const ROAR_VOLUME_DB := -4.0
const ROAR_GAP := 6.0
var _roar_cd := 0.0
var _roared_on_wake := false

func _configure() -> void:
	super()
	enemy_group = "heroes"
	sprite_texture = SPRITE
	# 2.6 x1.49 padding compensation for the colored art (2026-07-25) — see
	# Hero.SPRITE_SCALE_MULT. Keeps him the size he already was on screen.
	sprite_scale = 3.87
	# This art is drawn facing right, unlike every other unit in the game
	# (Designer, 2026-07-25) — see Combatant.sprite_faces_right.
	sprite_faces_right = true
	# super() has already placed him on _field.villain_pos, 300px in front of the
	# lair. Leash to the STRUCTURE rather than that spawn point — see _lair.
	_lair = _field.lair_pos if _field != null else global_position
	_boulder_cd = boulder_interval

func _villain_process(delta: float) -> void:
	# Villain._process gates this on is_alerted(), which latches — so the first
	# tick here IS the moment the party wakes him. Same hook the Dark Mage's
	# teleport sting uses.
	if not _roared_on_wake:
		_roared_on_wake = true
		_roar()
	_roar_cd = maxf(_roar_cd - delta, 0.0)
	_tick_boulders(delta)
	_shove_swarm(delta)

	# Field-wide hunt: with no hero in detect range, charge toward the nearest
	# living hero anyway (minions do the same) so he actually joins the battle.
	if _target == null:
		_hunt_cd -= delta
		if _hunt_cd <= 0.0:
			_hunt_cd = HUNT_INTERVAL
			var hero := _nearest_hero()
			if hero != null:
				# Clamped to his territory — he'll walk to the edge of the leash
				# toward a distant hero and hold there, rather than following
				# the party back down the lane.
				set_goal(_clamp_to_leash(hero.global_position))
			else:
				goal = Vector2.INF

## Overridden purely for the leash clamp (see below) — the phase check this used
## to open with is gone with the recovery beat.
func _engage(delta: float) -> void:
	var to_target := _target.global_position - global_position
	var dist := to_target.length()
	if dist > attack_range:
		global_position += _steer(to_target.normalized(), delta) * move_speed * delta
		# The leash applies to the CHASE too, not just the hunt goal — _engage
		# moves him directly, so clamping only the goal would let a hero he has
		# already acquired tow him out of his territory anyway.
		global_position = _clamp_to_leash(global_position)
	elif _attack_cd <= 0.0:
		_lunge = to_target.normalized() * LUNGE_DIST
		_target.take_damage(damage, self)
		_attack_cd = attack_interval
		_roar()

## Pushes any of his own minions he is standing on out from under him — see the
## SHOVE_SPEED block. No damage, no stun: they are his own side, they just get
## out of the way.
func _shove_swarm(delta: float) -> void:
	for node in get_tree().get_nodes_in_group(self_group):
		if node == self or not is_instance_valid(node) or node._dying:
			continue
		# Same exclusion Combatant._update_separation uses: pinned bodies
		# (LaneSpawnPoint) have no collision and are scenery as far as movement
		# is concerned.
		if "is_pinned" in node and node.is_pinned:
			continue
		var min_dist: float = body_radius + node.body_radius + SHOVE_MARGIN
		var diff: Vector2 = node.global_position - global_position
		var d := diff.length()
		if d >= min_dist:
			continue
		if d < 0.001:
			diff = Vector2.RIGHT.rotated(randf() * TAU)
			d = 0.001
		var pushed: Vector2 = node.global_position \
				+ (diff / d) * minf(min_dist - d, SHOVE_SPEED * delta)
		# Shoved along the lane, not out of it — a minion pushed past the lane
		# edge would be walking outside the playable band.
		if _field != null and "lane" in node:
			pushed = _field.clamp_to_lane(pushed, node.lane)
		node.global_position = pushed

## Clamps a point to within leash_radius of the lair — same helper the Dark
## Mage uses for the same reason.
func _clamp_to_leash(p: Vector2) -> Vector2:
	var off := p - _lair
	if off.length() > leash_radius:
		return _lair + off.normalized() * leash_radius
	return p

func _roar() -> void:
	if _roar_cd > 0.0:
		return
	_roar_cd = ROAR_GAP
	BattleSfx.play_clip(self, ROAR_SOUND, 0.0, 0.0, ROAR_VOLUME_DB)

## Hurls a smaller boulder at the nearest hero that's out of melee reach. This
## is what stops the leash turning him into a non-threat: a party that simply
## stands outside his territory now takes piercing rocks for it.
func _tick_boulders(delta: float) -> void:
	if RunState.headless:
		return
	_boulder_cd -= delta
	if _boulder_cd > 0.0:
		return
	var hero := _nearest_hero()
	if hero == null:
		return
	var to_hero := hero.global_position - global_position
	var dist := to_hero.length()
	if dist < boulder_min_range or dist > boulder_max_range:
		return
	_boulder_cd = boulder_interval
	_throw_boulder(to_hero.normalized(), dist)

func _throw_boulder(dir: Vector2, dist: float) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var boulder: Node2D = BOULDER_SCRIPT.new()
	boulder.radius = boulder_radius
	boulder.damage = boulder_damage
	boulder.speed = boulder_speed
	boulder.direction = dir
	boulder.hit_groups = ["heroes"]
	boulder.attacker = self
	# Overshoots the target so it keeps going THROUGH the hero it was aimed at
	# — the piercing part only reads if the rock outlives its first victim.
	boulder.max_travel = dist + boulder_max_range * 0.5
	parent.add_child(boulder)
	# Launched from his edge rather than his centre, so it doesn't appear to
	# spawn inside his own sprite.
	boulder.global_position = global_position + dir * (body_radius + boulder_radius)
	_roar()
