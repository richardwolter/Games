## Shadows cast by the sun, for everything that draws itself with a sprite.
##
## There is no engine lighting here and there are no shadow nodes. A shadow is the caster's
## own frame, drawn a second time under a transform that lays it out on the ground, in flat
## ink: `draw_texture_rect_region` multiplies by the colour it is given, so a modulate of
## black with an alpha is the sprite's silhouette and nothing else. That means the same
## `stamp` call every caster already makes draws its own shadow, correct to the frame it is
## on, without a second copy of the art or a polygon anybody has to author.
##
## The old shadows were ellipses: a dark patch that sat under a walking figure without ever
## being the shape of it. This is the replacement.
class_name Shade
extends RefCounted

## The colour a shadow is drawn in before the day's own ink is applied. Not pure black —
## a shadow on grass in daylight is a darker, bluer grass, and black over a bright lake
## reads as a hole in it.
const INK := Color(0.04, 0.06, 0.09, 1.0)


## The transform that lays a sprite down on the ground, about the point it stands on.
##
## The sprite's own upright axis is mapped to a direction going away from the caster: over
## by `lean` per unit of height, and flattened by `stretch`. Because that axis is flipped in
## the process, the picture lies head-away-from-feet, which is what a cast shadow does.
##
## `at` is the caster's contact point in its own drawing space, so a caller stamps at
## Vector2.ZERO inside this and gets its shadow where its feet are.
static func lying(at: Vector2, lean: float, stretch: float) -> Transform2D:
	return Transform2D(
		Vector2(1.0, 0.0), Vector2(-lean, -maxf(stretch, 0.02) * 0.5), at
	)


## The ink a shadow is drawn in, at the strength the day says.
static func tint(ink: float) -> Color:
	return Color(INK.r, INK.g, INK.b, clampf(ink, 0.0, 1.0))
