class_name Boss
extends Enemy

## The organ's problem. Chases like everything else, but fires rings of spit,
## which is the whole reason it exists in the slice: it proves the projectile
## scene serves enemies too, with nothing but a different target_group.

## `shot_stats`, `shot_interval` and the projectile scene now live on Enemy, so
## the small spitter and the boss fire out of one code path. The boss keeps only
## what is its own: the ring.
@export var ring_count: int = 10

## Chaos, in three separate channels rather than one "difficulty" number, so
## each can be tuned against what it actually breaks:
##
##   spin     the ring turns between volleys, so consecutive rings do not stack
##            into fixed corridors the player can stand in and ignore.
##   jitter   per-shot angular error, which frays the ring's edges.
##   speed    per-shot speed spread, which is what stops a ring arriving as one
##            clean expanding circle you can outrun by walking.
@export var ring_spin: float = 0.9          ## radians added per volley
@export var shot_jitter_degrees: float = 11.0
@export var shot_speed_spread: float = 0.35 ## fraction, either side of 1

## Every so many rings, one goes out aimed and dense instead of even. A boss
## whose pattern never changes is a metronome, and the whole fight is read off
## the gap between volleys.
@export var aimed_every: int = 3
@export var aimed_arc_degrees: float = 60.0

var _ring_timer: float = 1.0
var _rings_fired: int = 0
var _spin: float = 0.0


func _ready() -> void:
	super._ready()
	# The boss walks straight at you. The chaser's weave is a crowd behaviour --
	# on a single body this size it reads as the boss being lost.
	attention_radius = 0.0


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if shot_stats == null:
		return
	# Nothing left to shoot at. The rings keep the room lethal long after the
	# player is on the floor, which is exactly what mourning exists to stop.
	if is_mourning():
		return
	# Cold slows the guns too, not just the legs. Freezing a boss that keeps
	# firing at full rate would read as the status doing nothing.
	_ring_timer -= delta * chill_factor()
	if _ring_timer <= 0.0:
		_ring_timer = shot_interval
		_fire_ring()


func _fire_ring() -> void:
	_rings_fired += 1
	_spin += ring_spin

	# Aimed volleys are a tight fan at the player; ordinary ones are the full
	# circle. Both come out of the same loop -- an aimed burst is a ring with a
	# narrower arc and somewhere specific to point.
	var aimed := aimed_every > 0 and _rings_fired % aimed_every == 0
	var target := _find_player()
	if aimed and target == null:
		aimed = false

	var count := ring_count
	var arc := TAU
	var centre := _spin + randf() * 0.6
	if aimed:
		count = maxi(ring_count / 2, 3)
		arc = deg_to_rad(aimed_arc_degrees)
		centre = (target.global_position - global_position).angle() - arc * 0.5

	var jitter := deg_to_rad(shot_jitter_degrees)
	for i in count:
		# The full ring divides by `count` so it closes; the fan divides by
		# count-1 so both ends of the arc actually get a shot.
		var step := arc / float(count if not aimed else maxi(count - 1, 1))
		var angle := centre + step * i + randf_range(-jitter, jitter)

		var stats := shot_stats.duplicate_stats()
		stats.speed *= 1.0 + randf_range(-shot_speed_spread, shot_speed_spread)

		var p := PROJECTILE_SCENE.instantiate() as Projectile
		p.setup(stats, Vector2.from_angle(angle), &"player")
		p.global_position = global_position
		get_tree().current_scene.add_child(p)


## The drawn ring of "cilia" is gone with the placeholder it decorated -- it
## existed to make a plain circle legible as a boss. Scale and a paler tint do
## that job now, and the crack shader reports its health like any other enemy,
## just at a coarser cell size so a body this large fractures into slabs rather
## than gravel.
