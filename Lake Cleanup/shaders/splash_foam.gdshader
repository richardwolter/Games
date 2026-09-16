// The white water of a splash: the crown, its ring, the drops thrown off it, and the ripple
// rings the reel, the fish and a wader's first step push out.
//
// The same language as foam.gdshader gives the collar round a floating piece (issue #31,
// 2026-09-16: "replaced by our foam look"): worked out once per `foam_pixel` cell, hard
// edges, palette swatches only, broken into whole bubbles rather than faded. The shapes and
// their motion are WaterSplash's own and unchanged — this is only what they are drawn in.
//
// The crown is flat polygons with no useful UVs, so the bubble field is laid over world
// position, on the world's own art-pixel grid (the water's grid, not a moving frame: a
// splash happens in one place). The vertex alpha stands in for how thick the foam is: a
// crown fading out is foam thinning, and thinning foam comes apart into bubbles rather than
// going transparent as a sheet. Every output alpha is one of three steps — whole, a thin
// remnant, or nothing — so nothing here is a gradient.
shader_type canvas_item;
render_mode blend_mix;

#include "res://shaders/pixel.gdshaderinc"

// The alpha a crown is at its thickest. Mirrors WaterSplash.PEAK_ALPHA, so "full strength"
// here means the crown at the height of its life rather than an alpha nothing ever reaches.
uniform float peak_alpha = 0.72;

// What the foam is drawn in. The vertex colour's rgb is ignored: Palette.dress_foam sets
// these to the palette's own foam swatches, the same two every other foam in the lake uses.
uniform vec4 foam : source_color = vec4(0.93, 0.97, 1.0, 1.0);
uniform vec4 foam_core : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float foam_pixel = 2.0;
uniform float pixel_fps = 8.0;
// How big a bubble is, in world pixels — two art pixels — and how fast the field churns.
// Coarse for the same reason foam.gdshader's is: foam ground finer than the pixel art beside
// it is a grey fizz.
uniform float bubble_px = 4.0;
uniform float bubble_churn = 1.1;
// What the thin remnant of a dissolving edge is drawn at, as a share of the whole.
uniform float remnant = 0.4;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	// On the world's art-pixel grid, ticking in whole frames.
	vec2 at = floor(world_pos / foam_pixel) * foam_pixel;
	float t = stepped_time(TIME, pixel_fps) * 1.6;
	// How thick the water is here, 0 to 1, off the colour the polygon was drawn in.
	float lip = clamp(COLOR.a / peak_alpha, 0.0, 1.0);

	vec2 cell = floor(at / bubble_px + vec2(-t * 0.35, t * bubble_churn));
	float grain = cell_hash(cell);

	// Dissolved by thickness: where the foam is solid every cell survives; as it thins only
	// the cells that rolled high are kept, and what they lose is a remnant, then a hole.
	float kept = step(grain, lip * 1.25);
	float thin = step(0.35, lip);
	float a = max(kept, thin * remnant) * step(0.02, lip) * peak_alpha;

	// Bubbles catching the light are whiter than the water round them: a swatch, not a mix.
	vec3 lit = mix(foam.rgb, foam_core.rgb, step(0.72, grain) * kept);
	COLOR = vec4(lit, a);
}
