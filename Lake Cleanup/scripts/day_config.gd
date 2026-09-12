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

## How far a shadow leans, as a multiple of its own height, at the two ends of the day and at
## noon. Negative throws the shadow to the left of its caster, which is where a sun in the
## southeast puts it; all three are negative, and must stay so. The sun drifts west through
## the day, so the shadow is furthest left at dawn and least so at dusk. `test_lake` guards
## the sign over the whole loop — a positive value here lights the world from the northwest
## and every painted highlight in the game then falls on the shadowed side.
@export var lean_dawn: float = -1.3
@export var lean_noon: float = -1.0
@export var lean_dusk: float = -0.75

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
