class_name SpawnMarker
extends Node2D

## The tell before an enemy exists. A wave that materialises on top of you is
## not difficulty, it is a coin flip, so every spawn point is advertised for a
## beat first and the player is expected to move off it.

signal expired(marker: SpawnMarker)

## How long the marker sits there before the thing arrives. Long enough to walk
## out of, short enough that a wave still lands as a wave.
const LEAD_TIME: float = 1.1
const RADIUS: float = 40.0

var tint: Color = Color(1.0, 0.35, 0.35)
## Per-marker override of LEAD_TIME. The rampage runs on a shorter fuse -- it is
## supposed to be something you outrun, not something you clear.
var lead: float = LEAD_TIME

var _elapsed: float = 0.0


func _ready() -> void:
	# NOT a negative z_index. A child below its parent draws behind the parent's
	# own _draw, and the room paints an opaque floor rect there -- the marker was
	# being covered by the floor it is supposed to be painted on.
	z_index = 1


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	if _elapsed >= lead:
		expired.emit(self)
		queue_free()


func _draw() -> void:
	var t := clampf(_elapsed / lead, 0.0, 1.0)

	# Dark backing disc first. The floor is a near-black tint of the body part,
	# and a thin warm ring on it is exactly the contrast the eye skips over.
	draw_circle(Vector2.ZERO, RADIUS * 1.1, Color(0.0, 0.0, 0.0, 0.35))

	# Outer ring is the footprint: fixed, so the danger zone reads at a glance.
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, tint, 4.0, true)

	# Inner disc is the clock: it fills the ring, and when it touches the edge
	# the enemy is there. No number to read, no colour change to interpret.
	draw_circle(Vector2.ZERO, RADIUS * t, Color(tint.r, tint.g, tint.b, 0.45))

	# Cross hairs keep the mark visible over cover blocks and blood decals.
	var arm := RADIUS * 1.45
	var line := Color(tint.r, tint.g, tint.b, 0.65)
	draw_line(Vector2(-arm, 0.0), Vector2(arm, 0.0), line, 2.0)
	draw_line(Vector2(0.0, -arm), Vector2(0.0, arm), line, 2.0)
