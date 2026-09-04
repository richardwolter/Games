class_name Lighting
extends RefCounted

## One place that answers "where is the light coming from".
##
## Every room, every shadow and every vignette reads these. The whole point is
## that they agree: two shadows pointing different ways read as two different
## scenes stitched together, and no amount of detail elsewhere recovers from it.
##
## The body has no sun in it. The convention here is a soft glow from ABOVE and
## slightly to the left -- the direction the character art is already lit from
## (see ART_BIBLE) -- so shadows fall down and to the right, short, and never
## long enough to be mistaken for a second creature.

## Unit vector pointing the way light TRAVELS. Down-and-right, so it comes from
## up-and-left.
const DIRECTION: Vector2 = Vector2(0.3162, 0.9487)

## How far a shadow is thrown from the body that casts it, as a fraction of that
## body's width. Small: everything in here is standing ON the floor, and a long
## throw reads as flying.
const THROW: float = 0.16

## Shadows are an ellipse, never a circle: the floor is seen at an angle (see
## ART_BIBLE, "Camera and facing"), so a round shadow reads as a ball.
const SQUASH: float = 0.42

const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.42)
## The soft outer edge, drawn as a second larger ellipse underneath. Two flat
## ellipses cost nothing and read as a penumbra; one hard one reads as a decal.
const SHADOW_HALO: Color = Color(0.0, 0.0, 0.0, 0.16)
const HALO_SCALE: float = 1.35


## Draws a shadow onto `ci`, centred under `ground` (the point where the body
## meets the floor, in `ci`'s own space).
##
## `width` is the body's width; `lift` raises the caster off the ground, which
## SHRINKS and fades the shadow rather than moving it -- that is what sells a
## jump, a bob, or a foot in mid-stride.
static func draw_shadow(ci: CanvasItem, ground: Vector2, width: float,
		lift: float = 0.0, alpha: float = 1.0) -> void:
	if width <= 0.0:
		return
	# A lift of one body width halves the shadow. Clamped so a big hop does not
	# make it vanish entirely and leave the caster looking unanchored.
	var shrink := clampf(1.0 - lift / maxf(width, 1.0) * 0.5, 0.45, 1.0)
	var r := width * 0.5 * shrink
	var centre := ground + DIRECTION * width * THROW

	ci.draw_set_transform(centre, 0.0, Vector2(1.0, SQUASH))
	ci.draw_circle(Vector2.ZERO, r * HALO_SCALE,
		Color(SHADOW_HALO, SHADOW_HALO.a * alpha * shrink))
	ci.draw_circle(Vector2.ZERO, r,
		Color(SHADOW_COLOR, SHADOW_COLOR.a * alpha * shrink))
	ci.draw_set_transform(Vector2.ZERO)
