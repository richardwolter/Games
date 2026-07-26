class_name SpriteFootprint
extends RefCounted
## Derives an OVAL collision footprint from a sprite's actual drawn pixels
## (Designer, 2026-07-25).
##
## Before this, everything collided as a circle whose diameter spanned the
## sprite's LONGEST image edge — transparent margin included. Two consequences:
## a tall character's collision width was set by his height (Thundaar's circle
## was ~1.4x wider than he is), and a padded export like the berserk minion's
## (59% empty on its long edge) paid for all that empty space on the field.
##
## The oval instead hugs the opaque art, so collision tracks the drawing.
##
## Ellipses take part in the existing circle-vs-circle math via `radius_toward`
## rather than any new solver — the same trick LaneField already uses for the
## elliptical Poison Lake (see _lake_radius_toward).

## How much of the art the oval wraps. Below 1.0 it sits inside the art's
## bounding box — "covers most of the sprite, but not all". Raising this makes
## every unit and obstacle fatter, so it is a real balance knob, not a visual.
const COVERAGE := 0.85

## Opaque bounds per texture. Scanning is far too slow to redo per unit with a
## 50-minion swarm on screen, and a texture's bounds never change at runtime.
static var _bounds_cache := {}

## Tight bounds of a texture's non-transparent pixels, in texture pixel space.
## Returns a zero-size Rect2 if the image can't be read.
static func opaque_rect(tex: Texture2D) -> Rect2:
	if tex == null:
		return Rect2()
	var key := tex.get_rid().get_id()
	if _bounds_cache.has(key):
		return _bounds_cache[key]
	var rect := Rect2()
	var img := tex.get_image()
	if img != null:
		if img.is_compressed():
			# get_used_rect needs raw pixels; imported PNGs may arrive compressed.
			if img.decompress() != OK:
				img = null
		if img != null:
			rect = Rect2(img.get_used_rect())
	_bounds_cache[key] = rect
	return rect

## Oval semi-axes for art drawn so its LONGEST image edge spans `long_extent`
## — the sizing convention shared by Combatant._draw and
## LaneField._draw_obstacle_sprite.
static func radii_for(tex: Texture2D, long_extent: float,
		coverage: float = COVERAGE) -> Vector2:
	var fallback := Vector2(long_extent, long_extent) * 0.5
	if tex == null:
		return fallback
	var tex_size := tex.get_size()
	var long_edge := maxf(tex_size.x, tex_size.y)
	if long_edge <= 0.0:
		return fallback
	var opaque := opaque_rect(tex)
	if opaque.size.x <= 0.0 or opaque.size.y <= 0.0:
		return fallback
	var k := long_extent / long_edge
	return opaque.size * k * 0.5 * coverage

## Radius of an axis-aligned ellipse in the direction `dir`, so an oval can be
## used anywhere a circle radius was expected.
static func radius_toward(radii: Vector2, dir: Vector2) -> float:
	if radii.x <= 0.0 or radii.y <= 0.0:
		return maxf(radii.x, radii.y)
	var d := dir.normalized()
	if d.length_squared() < 0.5:
		return maxf(radii.x, radii.y)
	var ry_cos := radii.y * d.x
	var rx_sin := radii.x * d.y
	var denom := sqrt(ry_cos * ry_cos + rx_sin * rx_sin)
	if denom < 0.0001:
		return maxf(radii.x, radii.y)
	return (radii.x * radii.y) / denom
