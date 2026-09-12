## The daylight cycle's tunable numbers, in a Resource so a pass over the look of the lake
## means turning dials in the Inspector rather than editing a script.
##
## The cycle is a loop with no night in it: dawn, noon, evening, a short dim trough, dawn
## again. The trough is not night — it is the darkest point of the loop, and it exists so
## the sun has somewhere to swing back from.
##
## The sun sits in the southeast all day and only drifts. Every painted asset is lit from
## there — the shed's and the recycle box's own pixels are measurably brighter down their
## right-hand sides — so a cast shadow that swung from one side of a caster to the other
## would contradict the art for half of every loop. It drifts instead: a narrow arc, always
## throwing the shadow down and to the left, so the light moves without ever disagreeing
## with the paint. The trough's reset is a small step rather than a flip.
class_name DayConfig
extends Resource

## How long one dawn-to-dawn loop takes, in real seconds. Real time rather than progress or
## ferry runs: an incremental game is mostly watched, and the light is the thing that moves
## while nothing else is being asked of the player.
@export var cycle_seconds: float = 600.0

## Where the trough starts, as a fraction of the loop, and how far the light comes down at
## the bottom of it. The remaining fraction is the trough itself, so 0.9 is a minute of dusk
## in a ten-minute day.
@export_range(0.5, 0.99) var trough_at: float = 0.9
@export_range(0.0, 1.0) var trough_dip: float = 0.34

## The colour of the light through the loop, sampled at the phase the cycle is at. Multiplied
## over the world, so a value under white darkens and a tinted one colours: pale blue at
## first light, white at noon, amber in the evening, deep blue in the trough.
@export var tint: Gradient

## Which way a shadow points, as how far it goes sideways for every unit it goes down the
## screen. This is an angle, not a distance: how long the shadow is comes from `stretch`
## below, and `DayCycle` multiplies the two together to get the lean it hands out.
##
## Slant rather than a raw lean, by decision. The two were set independently once, and
## nothing kept them agreeing: a noon lean of 1.0 against a noon stretch of 0.42 threw the
## shed's shadow 141 px sideways while it was only 30 px long — 78 degrees off vertical, a
## flat streak lying beside a building it had come away from. Tied together, the shadow keeps
## its bearing all day and only its length changes, which is what a sun that climbs and sets
## in one quarter of the sky actually does.
##
## Always positive here; `DayCycle` applies the minus. The sun is in the southeast, so the
## shadow falls to the *left* of its caster — the side every painted asset keeps its shade
## on. Drifting down through the day is the sun moving west.
@export var slant_dawn: float = 0.5
@export var slant_noon: float = 0.35
@export var slant_dusk: float = 0.25

## How long a shadow is against the object casting it, at noon and at the ends of the day. A
## low sun throws a long shadow; an overhead one throws almost none.
@export var stretch_noon: float = 0.42
@export var stretch_ends: float = 1.35

## How dark a shadow is at noon and at the ends of the day. Low light is soft light: a dusk
## shadow is longer and fainter than a midday one, not longer and just as black.
@export var ink_noon: float = 0.34
@export var ink_ends: float = 0.16


## The gradient the cycle falls back on when the resource has none, so a missing or
## half-filled .tres is a plain day rather than a black screen.
static func default_tint() -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.18, 0.5, 0.78, 0.9, 1.0])
	g.colors = PackedColorArray([
		Color(0.72, 0.74, 0.86, 1.0),
		Color(0.94, 0.93, 0.92, 1.0),
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 0.88, 0.72, 1.0),
		Color(0.86, 0.71, 0.63, 1.0),
		Color(0.72, 0.74, 0.86, 1.0),
	])
	return g
