class_name DarkMage
extends Villain
## Dark Mage: never attacks (summoner + HP target — see DECISIONS.md). Kites
## slowly away from the nearest hero, and every teleport_interval seconds
## blinks to a nearby clear spot and summons a fresh burst of minions around
## himself — turns him from a passive HP bag into a moving target that
## punishes standing still near him. Stats come from dark_mage.tscn.

## Kiting: he retreats from the nearest hero until this far away, then stops.
@export var flee_distance := 260.0
## How often (seconds) he blinks to a nearby spot and resummons minions.
## 20 -> 5 (Designer, 2026-07-25: harder Dark Mage). This is a large difficulty
## swing, not just a cadence tweak — see BALANCE.md's note that a chasing
## party's progress resets on every blink, and that each blink now also adds a
## fresh summon burst. Effective minion pressure is ~4x what it was.
@export var teleport_interval := 5.0
## Max distance a teleport can jump.
@export var teleport_range := 400.0
## Minions summoned around him on each teleport: a mix of ordinary swarm
## minions plus larger ones (the "big mage" variant, which
## carries its own HP/damage bump via Minion.VARIANT_OVERRIDES). Designer,
## 2026-07-25: "3 small and 1 large".
@export var teleport_minion_count := 3
@export var teleport_large_minion_count := 1

## The two stage-1 swarm variants, requested explicitly rather than left to
## Minion's random roll so the summon mix is always 3 small + 1 large.
const SMALL_MINION_ART := preload("res://assets/sprites/Minion-Dark-Mage_Color.png")
const LARGE_MINION_ART := preload("res://assets/sprites/Minion2_Dark_Mage_Color.png")
## Max distance a teleport destination may end up from the nearest hero —
## keeps him "in view" instead of vanishing off to some empty corner.
@export var teleport_fov_radius := 700.0
## Radius of the ring minions are placed on around him after a teleport.
@export var summon_radius := 90.0
@export var summon_minion_speed := 90.0
## Leash: fleeing and teleporting stay within this radius of the authored lair,
## so a chasing party's progress isn't reset by a blink across the map (fixed-lair
## rework — the old free-roaming teleport made the Dark Mage structurally
## un-catchable; see BALANCE.md).
@export var leash_radius := 520.0

## Weak ranged poke: fires a travel-time Projectile at the nearest hero every
## shoot_interval. Kept separate from Combatant's built-in engage/target system
## (enemy_group stays "") so it doesn't fight the flee-goal movement above —
## he still kites while lobbing bolts.
## 1.0 -> 0.92 (Designer, 2026-07-25: "shoot 0.08s faster").
@export var shoot_interval := 0.92
@export var shoot_damage := 4.0
@export var shoot_speed := 420.0
@export var shoot_range := 600.0

## How often (seconds) the flee goal is re-evaluated. Cheap, throttled like
## Minion/Berserker's hunt ticks.
const FLEE_INTERVAL := 0.3
const MINION_SCENE_PATH := "res://scenes/enemies/minion.tscn"
const PROJECTILE_SCENE_PATH := "res://scenes/combat/projectile.tscn"
## Same hand-drawn papercut-style art pipeline as the hero sprites (see
## Hero.HERO_SPRITES doc) — the cream torn-paper cutout + ink linework is
## baked into the source PNG itself, so wiring it in is just setting
## sprite_texture (Combatant._draw draws it with the same paper-cutout
## treatment — alpha, facing flip, ground shadow — as every other sprite unit).
## Stage 1 villain art (Designer, 2026-07-25).
const SPRITE := preload("res://assets/sprites/DarkMage_Color.png")

## Blink sting (Designer, 2026-07-26): plays once when the party first wakes
## him, then on every teleport after that. No rate limiter here, unlike the
## hero ability callouts — teleport_interval already floors the cadence at 5s
## and isn't reduced by anything, so the clip can't stack on itself.
const TELEPORT_SOUND: AudioStream = preload("res://assets/Sounds/Dark_Mage_Teleport.ogg")
## Louder than the hero ability callouts at -8 (Designer, 2026-07-26): those
## are the party's own recurring chatter, this is the villain relocating behind
## you and needs to cut through the fight.
const TELEPORT_SOUND_VOLUME_DB := -2.0

var _flee_cd := 0.0
var _teleport_cd := 0.0
var _shoot_cd := 0.0
var _minion_scene: PackedScene = null
var _projectile_scene: PackedScene = null
## The authored lair (captured before the villain starts moving); the leash
## anchors here. LaneField.villain_pos tracks his LIVE position, so we can't
## read it later as the lair.
var _lair := Vector2.ZERO
## Latches on the first _villain_process tick — see _villain_process.
var _played_alert_sound := false

func _configure() -> void:
	super()
	enemy_group = ""  # does not attack this milestone
	sprite_texture = SPRITE
	# 2.0 -> 3.0 (Designer, 2026-07-25: "Dark Mage should be 1.5x bigger").
	sprite_scale = 3.0
	_lair = global_position
	_teleport_cd = teleport_interval
	_shoot_cd = shoot_interval
	_minion_scene = load(MINION_SCENE_PATH)
	_projectile_scene = load(PROJECTILE_SCENE_PATH)

func _villain_process(delta: float) -> void:
	# Villain._process gates this method on is_alerted(), which latches, so the
	# very first tick here IS the moment the party first detects him — no extra
	# proximity check needed. (is_alerted also latches on being struck, so a
	# ranged poke that wakes him from off-screen counts as the encounter too.)
	# Can't collide with the teleport sound below: _teleport_cd starts at a full
	# teleport_interval and only ticks down while alerted.
	if not _played_alert_sound:
		_played_alert_sound = true
		BattleSfx.play_clip(self, TELEPORT_SOUND, 0.0, 0.0, TELEPORT_SOUND_VOLUME_DB)

	_teleport_cd -= delta
	if _teleport_cd <= 0.0:
		_teleport_cd = teleport_interval
		_teleport_and_summon()

	_flee_cd -= delta
	if _flee_cd <= 0.0:
		_flee_cd = FLEE_INTERVAL
		_update_flee_goal()

	_shoot_cd -= delta
	if _shoot_cd <= 0.0:
		_shoot_cd = shoot_interval
		_shoot_nearest_hero()

## Sets a retreat goal directly away from the nearest hero, once it's closer
## than flee_distance. _advance_goal (Combatant) handles the actual slow
## movement and obstacle steering; clears the goal once far enough away.
func _update_flee_goal() -> void:
	var hero := _nearest_hero()
	if hero == null:
		goal = Vector2.INF
		return
	var away := global_position - hero.global_position
	if away.length() >= flee_distance:
		goal = Vector2.INF
		return
	if away.length() < 1.0:
		away = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	# Leash the retreat to the lair area so he juke-dances near his lair instead
	# of fleeing across the whole field (which reset a chasing party's progress).
	set_goal(_clamp_to_leash(global_position + away.normalized() * flee_distance))

## Clamps a point to within leash_radius of the lair.
func _clamp_to_leash(p: Vector2) -> Vector2:
	var off := p - _lair
	if off.length() > leash_radius:
		return _lair + off.normalized() * leash_radius
	return p

## Blinks to a nearby clear spot and resummons a fresh burst of minions there.
func _teleport_and_summon() -> void:
	if _field == null:
		return
	var dest := _find_teleport_spot()
	BattleSfx.play_clip(self, TELEPORT_SOUND, 0.0, 0.0, TELEPORT_SOUND_VOLUME_DB)
	global_position = dest
	goal = Vector2.INF
	_summon_minions(dest)

## Samples candidate points: inside the field ellipse, clear of obstacles and
## the Poison Lake, within teleport_fov_radius of the nearest hero (so he
## stays visible rather than vanishing to an empty corner). Among the valid
## candidates, picks the one farthest from the nearest hero — as far away as
## he can get while staying in view. Falls back to the closest-to-in-view
## valid candidate if none satisfy the FOV bound, then to the current
## position (no jump) if nothing valid turns up at all.
func _find_teleport_spot() -> Vector2:
	var hero := _nearest_hero()
	var best_in_fov: Vector2 = global_position
	var best_in_fov_dist := -1.0
	var best_fallback: Vector2 = global_position
	var best_fallback_dist := INF
	var found_any := false
	for attempt in 20:
		var d := randf_range(teleport_range * 0.3, teleport_range)
		var a := randf() * TAU
		var p := global_position + Vector2(cos(a), sin(a)) * d
		if (p / (_field.field_radius - Vector2(body_radius, body_radius))).length_squared() > 1.0:
			continue
		# Leash: never blink outside the lair area (keeps him catchable).
		if p.distance_to(_lair) > leash_radius:
			continue
		if _field.in_lake(p):
			continue
		var clear := true
		for o in _field.obstacles:
			if p.distance_to(Vector2(o.x, o.y)) < o.z + body_radius + 20.0:
				clear = false
				break
		if not clear:
			continue
		found_any = true
		var hero_dist := p.distance_to(hero.global_position) if hero != null else 0.0
		if hero_dist <= teleport_fov_radius:
			if hero_dist > best_in_fov_dist:
				best_in_fov_dist = hero_dist
				best_in_fov = p
		elif hero_dist < best_fallback_dist:
			best_fallback_dist = hero_dist
			best_fallback = p
	if best_in_fov_dist >= 0.0:
		return best_in_fov
	if found_any:
		return best_fallback
	return global_position

## Spawns teleport_minion_count minions in a ring around `at`, same setup()
## contract MinionSpawner uses. Added as siblings (battlefield root), not
## children of the villain, so they aren't affected by his own transform.
func _summon_minions(at: Vector2) -> void:
	if _minion_scene == null or _field == null:
		return
	var total := teleport_minion_count + teleport_large_minion_count
	if total <= 0:
		return
	for i in total:
		var m := _minion_scene.instantiate()
		# The larges take the tail of the ring; everything before them is small.
		m.forced_variant = LARGE_MINION_ART if i >= teleport_minion_count else SMALL_MINION_ART
		var a := TAU * i / total
		var offset := Vector2(cos(a), sin(a)) * summon_radius
		m.setup(at + offset, _field.hero_spawn + offset, offset * 0.6, summon_minion_speed)
		get_parent().add_child(m)

## Fires a weak Projectile at the nearest hero, field-wide like the flee/summon
## targeting above (not gated by attack_range/detect_range).
func _shoot_nearest_hero() -> void:
	if _projectile_scene == null or get_parent() == null:
		return
	var hero := _nearest_hero()
	if hero == null:
		return
	var proj: Projectile = _projectile_scene.instantiate()
	proj.damage = shoot_damage
	proj.attacker = self
	proj.target = hero
	proj.enemy_group = "heroes"
	proj.speed = shoot_speed
	proj.max_range = shoot_range
	proj.color = body_color
	proj.global_position = global_position
	get_parent().add_child(proj)
