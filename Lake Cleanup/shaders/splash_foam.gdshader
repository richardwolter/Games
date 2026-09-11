// The white water of a splash: the crown, its ring and the drops thrown off it.
//
// Same treatment as foam.gdshader gives the collar round a floating piece, so the water
// breaking round a catch and the water lapping at a bottle read as one substance. The crown
// is drawn as flat polygons with no useful UVs, so the bubble field is laid over world
// position instead of over a quad, and the vertex alpha stands in for how thick the foam is:
// a crown fading out is foam thinning, and thinning foam comes apart into bubbles rather than
// going transparent as a sheet.
shader_type canvas_item;
render_mode blend_mix;

// The alpha a crown is at its thickest. Mirrors WaterSplash.PEAK_ALPHA, so "full strength"
// here means the crown at the height of its life rather than an alpha nothing ever reaches.
uniform float peak_alpha = 0.72;

// How big a bubble is, in world pixels, and how fast the field churns. Coarse for the same
// reason foam.gdshader's is: foam ground finer than the pixel art beside it is a grey fizz.
uniform float bubble_px = 2.6;
uniform float bubble_churn = 1.1;

varying vec2 world_pos;

// One number per bubble cell, stable for the same cell. The hash foam.gdshader uses.
float bubbles_at(vec2 cell) {
	vec2 p = fract(cell * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float t = TIME * 1.6;
	// How thick the water is here, 0 to 1, off the colour the polygon was drawn in.
	float lip = clamp(COLOR.a / peak_alpha, 0.0, 1.0);

	vec2 cell = floor(world_pos / bubble_px + vec2(-t * 0.35, t * bubble_churn));
	float grain = bubbles_at(cell);

	// Dissolved by thickness: where the crown is solid every cell survives; as it thins only
	// the cells that rolled high are kept, with a floor so the losers are not holes.
	float kept = mix(0.28, 1.0, step(grain, lip * 1.25));

	// Bubbles catching the light are whiter than the water round them.
	vec3 lit = mix(COLOR.rgb, vec3(1.0), grain * 0.4 * lip);

	COLOR = vec4(lit, COLOR.a * kept);
}
