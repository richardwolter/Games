class_name DamageVignette
extends Control

## The screen-edge blood smear on taking a hit.
##
## Deliberately NOT a centred red wash: a full-screen tint hides the thing that
## just hit you, which is the one piece of information the player needs in that
## exact moment. The smear lives around the border, leaves the middle clear, and
## is gone in two frames.
##
## Drawn rather than shaded. A vignette shader would be tidier, but this needs
## to be a different splash every time -- a shader would need a noise texture
## and a seed uniform to get there, and overlapping translucent circles get the
## smudge for nothing.

## Frames, not seconds. Asked for as frames, and at this length the difference
## matters: a 0.03s timer is one frame on a good machine and three on a bad one.
const HOLD_FRAMES: int = 2

const BLOOD: Color = Color(0.62, 0.03, 0.06)
const BLOB_COUNT: int = 30
## How far in from the edge a blob's centre may sit, as a fraction of the
## screen. Small, because the centre has to stay readable.
const INSET: float = 0.16

var _frames_left: int = 0
## [centre, radius, alpha] per blob, regenerated on every hit so no two smears
## are the same shape.
var _blobs: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Called on damage. Re-rolls the splash and shows it for HOLD_FRAMES.
func flash() -> void:
	_build_blobs()
	_frames_left = HOLD_FRAMES
	visible = true
	queue_redraw()


## The counter is spent BEFORE hiding, never in the same pass. A node's _process
## runs ahead of the draw for that same frame, so decrementing and hiding
## together costs the last frame the effect was supposed to be visible for.
func _process(_delta: float) -> void:
	if not visible:
		return
	if _frames_left <= 0:
		visible = false
		return
	_frames_left -= 1
	queue_redraw()


func _build_blobs() -> void:
	_blobs.clear()
	var view := size
	if view.x <= 0.0 or view.y <= 0.0:
		view = Vector2(get_viewport_rect().size)

	for i in BLOB_COUNT:
		# Pick an edge, then a point along it. Distributing over the whole rect
		# and rejecting the middle wastes most of the samples and still clumps.
		var edge := randi_range(0, 3)
		var along := randf()
		var depth := randf_range(0.0, INSET)
		var centre := Vector2.ZERO
		match edge:
			0: centre = Vector2(view.x * along, view.y * depth)                ## top
			1: centre = Vector2(view.x * along, view.y * (1.0 - depth))        ## bottom
			2: centre = Vector2(view.x * depth, view.y * along)                ## left
			_: centre = Vector2(view.x * (1.0 - depth), view.y * along)        ## right

		var radius := randf_range(view.y * 0.08, view.y * 0.26)
		# Corners take more than the middle of an edge, so the frame reads as a
		# vignette instead of a stripe.
		var to_corner := minf(minf(along, 1.0 - along) * 2.0, 1.0)
		var weight := lerpf(1.0, 0.45, to_corner)
		_blobs.append([centre, radius, randf_range(0.05, 0.11) * weight])


func _draw() -> void:
	for blob in _blobs:
		var centre: Vector2 = blob[0]
		var radius: float = blob[1]
		var alpha: float = blob[2]
		# Three nested discs per blob: the falloff is what makes it read as a
		# smear rather than as a circle someone drew on the screen.
		draw_circle(centre, radius, Color(BLOOD.r, BLOOD.g, BLOOD.b, alpha * 0.45))
		draw_circle(centre, radius * 0.66, Color(BLOOD.r, BLOOD.g, BLOOD.b, alpha * 0.7))
		draw_circle(centre, radius * 0.33, Color(BLOOD.r, BLOOD.g, BLOOD.b, alpha))
