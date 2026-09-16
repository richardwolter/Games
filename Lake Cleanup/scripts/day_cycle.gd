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

## Where in the loop the day is, 0 at mid morning and 1 back at it.
##
## Phase 0 is the loop's mid morning, not first light (see `_sun_at`: there is no night). A run
## opens at 0.35, late morning — near full light, still climbing, so the opening minutes warm
## rather than fade. Not noon by decision: start at the peak and the only direction the light
## can go is down.
##
## Nothing saves or restores this. Every run opens at the same hour, which is what makes it
## a mood rather than a clock the player is being asked to track.
var phase: float = 0.35

## The colour the world is multiplied by, sampled from the config's gradient.
var tint := Color.WHITE

## How far a shadow leans off its caster, as a multiple of the caster's own height, and how
## long it is drawn against that height. Both come off the sun's height in the sky, which is
## where `_sun_at` puts the sun for the phase.
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


## Where the sun is along its day, 0 at first light and 1 at dusk, for this phase.
##
## No night (2026-09-14, Richard: "night is too dark"): the loop runs the sun from `sun_from`
## (mid morning) to `sun_to` (late afternoon) over the first `turn_at` of it, and then the light
## eases back to the morning's over the rest, without passing noon on the way. The darkest the
## lake gets is late afternoon. Returns -1 while easing back; `_settle` handles that stretch.
func _sun_at() -> float:
	var turn := clampf(_config.turn_at, 0.01, 1.0)
	if phase >= turn:
		return -1.0
	return lerpf(_config.sun_from, _config.sun_to, phase / turn)


func _settle() -> void:
	var at := _sun_at()
	if at >= 0.0:
		_light_at(at)
		return
	# Easing back: late afternoon's light and shadows turn into the morning's, smoothly, the
	# shadow shortening and swinging its bearing rather than the sun running back over noon.
	var turn := clampf(_config.turn_at, 0.01, 1.0)
	var back := smoothstep(0.0, 1.0, (phase - turn) / maxf(1.0 - turn, 0.001))
	_light_at(_config.sun_to)
	var late := [tint, lean, stretch, ink]
	_light_at(_config.sun_from)
	tint = (late[0] as Color).lerp(tint, back)
	lean = lerpf(late[1], lean, back)
	stretch = lerpf(late[2], stretch, back)
	ink = lerpf(late[3], ink, back)


## The light with the sun `at` along its day (0 first light, 0.5 noon, 1 dusk).
func _light_at(at: float) -> void:
	# A sine rather than a triangle, so the sun slows at the top of its arc the way it does
	# in the sky, and the shadows spend longer being short than being any one length.
	var high := sin(clampf(at, 0.0, 1.0) * PI)
	tint = _tint_ramp.sample(at)
	# Which side of noon the sun is on, -1 to 1.
	var side := clampf(at, 0.0, 1.0) * 2.0 - 1.0
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
