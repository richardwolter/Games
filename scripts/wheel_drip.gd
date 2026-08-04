## Water running off a tyre that has been through the strait.
##
## The truck crosses on a bridge that is half in the water, so its wheels spend
## most of a run dipping in and out. Before this they came out perfectly dry,
## which quietly undid the splash they made going in — the water had an effect on
## the truck for exactly one frame and then forgot about it.
##
## A tyre picks up water the moment any part of it is under the line, and keeps
## shedding it for a second or so after it comes out. That trailing part is the
## whole point: a wheel dripping while it is in the water is invisible, and a
## wheel that stops the instant it leaves is a switch rather than a wet tyre.
##
## One of these per wheel, driven per frame. Works off positions rather than
## velocities so the same class serves the live truck and the replay's puppet of
## it — a puppet wheel is written to, not simulated, and has no velocity to read.
class_name WheelDrip
extends RefCounted

## Seconds for a soaked tyre to run dry. Long enough to still be dripping a
## couple of plank-widths past the water, short enough that a truck that made it
## across is dry by the time it is being congratulated.
const DRY_SECONDS := 1.7

## Drops a second off a fully soaked tyre. Deliberately sparse — this is a
## trickle, and a tyre throwing a curtain of water reads as a burst pipe.
const DRIPS_PER_SECOND := 16.0

## How much of the wheel's own motion a drop inherits. Well under 1: the water is
## leaving the tyre, not travelling with it, and drops that keep pace look welded
## on.
const CARRY := 0.32

## Below this spin, in radians a second, a wet tyre sheds nothing. Water comes
## off a tyre because the tyre is throwing it off; a truck sitting still in the
## shallows should sit there wet, not drizzle. Low enough that a wheel merely
## turning over still trickles — it is "is it turning", not "is it fast".
const MIN_SPIN := 1.2

var _wheel: Node2D
var _radius: float
var _wetness: float = 0.0
var _last_pos: Vector2 = Vector2.INF
var _last_rot: float = 0.0
var _seen: bool = false


func _init(wheel: Node2D, radius: float) -> void:
	_wheel = wheel
	_radius = radius


## Soak, dry, and shed. Call once per rendered frame.
func update(delta: float, water: WaterBody) -> void:
	if delta <= 0.0 or water == null or water.splash == null:
		return
	if not is_instance_valid(_wheel) or not _wheel.visible:
		return

	var pos := _wheel.global_position
	var rot := _wheel.global_rotation
	# First frame has nothing to measure against, and a velocity taken from
	# Vector2.INF is not a number.
	var velocity := Vector2.ZERO if not _seen else (pos - _last_pos) / delta
	# Off the frame-to-frame angle rather than off angular_velocity, so the same
	# reading works for the replay's puppet wheels — those are written to, not
	# simulated, and have no velocity of any kind. Through angle_difference, or a
	# wheel crossing PI reads as a spin of several hundred rad/s.
	var spin := 0.0 if not _seen else absf(angle_difference(_last_rot, rot)) / delta
	_last_pos = pos
	_last_rot = rot
	_seen = true

	# Any part of the tyre in the water counts. Waiting for the axle would mean a
	# wheel rolling along a plank at the waterline — the commonest case there is —
	# never getting wet at all.
	#
	# contains_point rather than a depth test: the shores are level with the
	# surface, so "below the waterline" is true of dry land too, and the truck
	# dripped all the way along the shore before it reached any water.
	if water.contains_point(pos + Vector2(0.0, _radius)):
		_wetness = 1.0
	else:
		_wetness = maxf(_wetness - delta / DRY_SECONDS, 0.0)
	# Wet but not turning: the water stays on the tyre. Checked after the soak so a
	# wheel that stops in the water still comes out loaded and drips the moment it
	# starts turning again.
	if _wetness <= 0.0 or spin < MIN_SPIN:
		return

	# Fractional rate carried as a probability rather than an accumulator: at one
	# drop every sixteenth of a second there is no visible difference, and a
	# counter would have to be reset every time the wheel dried out.
	if randf() > _wetness * DRIPS_PER_SECOND * delta:
		return

	# Off the lower half of the tyre, weighted towards the bottom, so the water
	# leaves the rubber where it would actually run off.
	var angle := PI * 0.5 + randf_range(-1.0, 1.0)
	var from := pos + Vector2.from_angle(angle) * _radius * randf_range(0.86, 1.0)
	water.splash.drip(
		from,
		velocity * CARRY + Vector2(randf_range(-22.0, 22.0), randf_range(15.0, 70.0)),
		_radius * randf_range(0.055, 0.105),
		randf_range(0.5, 1.0)
	)
