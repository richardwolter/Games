## Distant scenery behind the strait.
##
## Earlier versions drew this in screen space and re-derived its position from
## the camera every frame, so it slid and rescaled as you panned and zoomed —
## the terrain moved one way, the mountains another. Any parallax at all reads
## as the background being unglued from the world at these zoom ranges.
##
## So it is now a plain world-space sprite: painted once to exactly cover the
## camera's limit rect, with its horizon on the water surface, and then never
## touched again. It moves with the terrain because it *is* part of the terrain.
class_name Backdrop
extends Sprite2D

## Where the painted horizon sits in the texture, top to bottom.
@export_range(0.0, 1.0) var horizon_frac: float = 0.55

## Extra magnification, applied about the painted horizon. 1.0 is the exact fit:
## the backdrop covers the camera's bounds and nothing more. Above that the
## scenery grows while its horizon stays welded to the water, so the range reads
## bigger and the sun climbs the screen, at the cost of cropping the top of the
## sky. Only ever raise it - below 1.0 the bounds stop being covered and the
## backdrop's edge comes into view.
@export_range(1.0, 3.0) var horizon_zoom: float = 1.4


func _ready() -> void:
	centered = true


## Stretch to cover `rect` (the camera's travel bounds) with the painted horizon
## sitting at `surface_y`. Scaled per-axis: covering the bounds with no visible
## edge matters more than preserving the texture's aspect.
func fit_to(rect: Rect2, surface_y: float) -> void:
	if texture == null:
		return
	var tex := Vector2(texture.get_width(), texture.get_height())
	var above: float = maxf(surface_y - rect.position.y, 1.0)
	var below: float = maxf(rect.end.y - surface_y, 1.0)

	# Uniform zoom on both axes: stretching only the sky would smear the range
	# vertically, and the extra width is free — it just means more of the
	# panorama sits outside the bounds, which nobody ever sees.
	var z: float = maxf(horizon_zoom, 1.0)
	var scale_x: float = rect.size.x / tex.x * z
	# One scale has to satisfy both halves, so take whichever needs more.
	var scale_y: float = maxf(
		above / maxf(horizon_frac * tex.y, 1.0),
		below / maxf((1.0 - horizon_frac) * tex.y, 1.0)
	) * z

	scale = Vector2(scale_x, scale_y)
	# Offset from the sprite's centre to its painted horizon.
	var horizon_offset: float = (horizon_frac - 0.5) * tex.y * scale_y
	position = Vector2(rect.position.x + rect.size.x * 0.5, surface_y - horizon_offset)
