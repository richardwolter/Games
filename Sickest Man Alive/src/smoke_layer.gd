class_name SmokeLayer
extends Node2D

## The haze hanging in a pair of lungs that have been smoked in for years.
##
## Purely a look. It does not damage, does not block shots and does not slow
## anything down -- the lungs already carry mold as their hazard, and stacking a
## second one on the same rooms would make the airways the part of the body
## everybody routes around. What this does is tell the player which organ they
## are standing in before they read the banner.
##
## Its own node rather than a pass inside Room._draw, because it has to animate.
## Room._draw retiles every wall and repaints the floor polygon; asking for that
## sixty times a second to drift some smoke is a lot of work for some smoke.

## Puffs on the floor of the room. Enough to read as a layer rather than as a few
## clouds, few enough that they stay individually legible when one drifts across
## something the player is trying to shoot.
const PUFF_MIN: int = 14
const PUFF_MAX: int = 20

const RADIUS_MIN: float = 90.0
const RADIUS_MAX: float = 210.0

## How far a puff wanders from where it was placed, and how long one loop takes.
## Slow and small: smoke that visibly races across a room reads as wind, and
## there is no wind inside a person.
const DRIFT: float = 26.0
const DRIFT_PERIOD_MIN: float = 7.0
const DRIFT_PERIOD_MAX: float = 13.0

## Alpha of a single puff at its thickest. They overlap heavily, so this is much
## lower than the haze actually ends up looking.
const ALPHA_MIN: float = 0.045
const ALPHA_MAX: float = 0.085
## How much a puff breathes in and out of visibility over its own loop.
const PULSE: float = 0.35

const SMOKE_COLOR: Color = Color(0.78, 0.76, 0.70)

## One entry per puff: where it sits, how big, how transparent, and its own
## phase and period so no two breathe together.
var _puffs: Array[Dictionary] = []
var _time: float = 0.0


## Lays the haze out. Takes the room's seeded rng, like every other thing built
## into a room, so walking back into a lung finds the same smoke in it.
func build(rng: RandomNumberGenerator, interior: Vector2) -> void:
	_puffs.clear()
	var count := rng.randi_range(PUFF_MIN, PUFF_MAX)
	for i in count:
		_puffs.append({
			"p": Vector2(rng.randf() * interior.x, rng.randf() * interior.y),
			"r": rng.randf_range(RADIUS_MIN, RADIUS_MAX),
			"a": rng.randf_range(ALPHA_MIN, ALPHA_MAX),
			"phase": rng.randf() * TAU,
			"period": rng.randf_range(DRIFT_PERIOD_MIN, DRIFT_PERIOD_MAX),
			# Which way this one wanders. Independent of everything else, so the
			# layer as a whole has no direction and therefore no wind.
			"dir": Vector2.from_angle(rng.randf() * TAU),
		})


func _ready() -> void:
	# Above the floor and the pools, below nothing: the player and the enemies
	# are not children of the room, so they draw over this regardless. Smoke that
	# hid the fight would be a hazard, and this is not one.
	z_index = 1


func _process(delta: float) -> void:
	if _puffs.is_empty():
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	for puff: Dictionary in _puffs:
		var period: float = puff["period"]
		var t: float = _time * TAU / period + float(puff["phase"])
		var centre: Vector2 = (puff["p"] as Vector2) + (puff["dir"] as Vector2) * sin(t) * DRIFT
		var alpha: float = float(puff["a"]) * (1.0 + PULSE * sin(t * 0.7))
		var r: float = puff["r"]
		# Three rings rather than one flat disc. A single circle at this alpha
		# reads as a grey coin; stacking a smaller, denser one inside a larger,
		# fainter one is what gives it a soft middle and no edge.
		draw_circle(centre, r, Color(SMOKE_COLOR, alpha * 0.5))
		draw_circle(centre, r * 0.66, Color(SMOKE_COLOR, alpha * 0.7))
		draw_circle(centre, r * 0.34, Color(SMOKE_COLOR, alpha))
