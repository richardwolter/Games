## The daylight over the lake: what time it is, what colour the light is, and which way the
## shadows fall.
##
## One owner for all three, because they are one thing. The tint is multiplied over the
## world, the sun vector is handed to everything that draws a shadow, and the water shader
## takes both so its glints move with the sun instead of sitting where they were painted.
##
## Nothing here touches the game. The clock does not spawn rubbish, pay the player or hurry
## the ferry — the lake looks different and plays exactly the same, which is the whole point
## of a cycle the player did not ask for and cannot lose anything to.
##
## Real seconds rather than progress: `pollution` already has the water clearing as its
## readout, and a second thing keyed to the same number would say the same thing twice.
class_name DayCycle
extends Node

const CONFIG_PATH := "res://resources/day.tres"

## Where in the loop the day is, 0 at first light and 1 back at it.
##
## A run opens at 0.35 rather than at 0: phase 0 is first light, which is the dimmest the
## day gets short of the trough, so the game used to open at dusk and spend its first four
## minutes getting brighter. 0.35 is late morning — near full light, still climbing, so the
## opening minutes warm rather than fade. Not noon (0.45) by decision: start at the peak and
## the only direction the light can go is down.
##
## Nothing saves or restores this. Every run opens at the same hour, which is what makes it
## a mood rather than a clock the player is being asked to track.
var phase: float = 0.35

## The colour the world is multiplied by, sampled from the config's gradient.
var tint := Color.WHITE

## How far a shadow leans off its caster, as a multiple of the caster's own height, and how
## long it is drawn against that height. Both come off the sun's height in the sky, which is
## what `_height` works out from the phase.
var lean: float = 0.0
var stretch: float = 1.0

## How dark a shadow is drawn, as an alpha.
var ink: float = 0.3

var _config: DayConfig
var _tint_ramp: Gradient


func _ready() -> void:
	_config = load(CONFIG_PATH) as DayConfig
	if _config == null:
		# A missing resource is a plain day, not a crash and not a black lake. The rest of
		# the game asks this for numbers every frame and none of them may come back null.
		push_warning("DayCycle: no %s, running on defaults" % CONFIG_PATH)
		_config = DayConfig.new()
	_tint_ramp = _config.tint if _config.tint != null else DayConfig.default_tint()
	_settle()


func _process(delta: float) -> void:
	phase = fposmod(phase + delta / maxf(_config.cycle_seconds, 1.0), 1.0)
	_settle()


## How high the sun is, 0 at either end of the day and 1 at noon.
##
## Noon is not the middle of the loop: the trough is at the end, so the daylight half runs
## from 0 to `trough_at` and the sun is highest halfway through that.
func _height() -> float:
	var day := maxf(_config.trough_at, 0.01)
	if phase >= day:
		return 0.0
	# A sine rather than a triangle, so the sun slows at the top of its arc the way it does
	# in the sky, and the shadows spend longer being short than being any one length.
	return sin(phase / day * PI)


func _settle() -> void:
	var high := _height()
	tint = _tint_ramp.sample(phase)
	if phase >= _config.trough_at:
		# The trough. Dimmed on top of whatever the gradient says, and dimmed on a curve
		# that comes down and back up rather than in a step, so the bottom of the loop is a
		# slow blink and not a light switch.
		var through := (phase - _config.trough_at) / maxf(1.0 - _config.trough_at, 0.001)
		var dip := sin(through * PI) * _config.trough_dip
		tint = tint.darkened(dip)
	# Which side of noon the sun is on, -1 to 1 across the daylight half.
	var side := 0.0
	var day := maxf(_config.trough_at, 0.01)
	if phase < day:
		side = clampf(phase / day, 0.0, 1.0) * 2.0 - 1.0
	stretch = lerpf(_config.stretch_ends, _config.stretch_noon, high)
	# The lean comes off the stretch rather than being set beside it. `slant` is the bearing
	# — how far sideways per unit down the screen — and the shadow's own drawn length is
	# `stretch * 0.5`, so the two multiplied are a shadow that keeps its direction all day
	# and only changes length. Set independently they drifted apart, and a shadow thrown four
	# times further sideways than it was long came away from the thing casting it.
	#
	# Negative: the sun is in the southeast, so the shadow falls to the left.
	var slant := lerpf(
		_config.slant_noon,
		_config.slant_dusk if side > 0.0 else _config.slant_dawn,
		absf(side)
	)
	lean = -absf(slant) * stretch * 0.5
	ink = lerpf(_config.ink_ends, _config.ink_noon, high)
