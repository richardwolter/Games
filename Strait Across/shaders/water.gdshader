// Water surface for the strait.
//
// Everything is driven by WORLD position, not UV: the water is a Polygon2D
// whose shape is rebuilt per level, so its UVs change with the strait's width
// and anything keyed to them would stretch as levels get wider.
//
// Three effects, cheapest first:
//   - a depth gradient, so the shallows near the banks read as shallow
//   - domain-warped bands under the surface, the "texture"
//   - a vertex ripple along the top edge, the actual moving waterline
//
// The ripple only displaces vertices sitting ON the surface. world.gd
// subdivides the top edge into short segments for it; the seabed edge is
// hundreds of units below and is left alone.
shader_type canvas_item;
render_mode blend_mix;

uniform float surface_y = 300.0;
uniform float max_depth = 600.0;
// Waves taper to nothing here so the waterline stays welded to both banks.
uniform float half_width = 1600.0;

uniform vec4 shallow_color : source_color = vec4(0.24, 0.55, 0.66, 0.55);
uniform vec4 deep_color : source_color = vec4(0.07, 0.18, 0.30, 0.78);
uniform vec4 foam_color : source_color = vec4(0.72, 0.88, 0.92, 0.55);

uniform float wave_amplitude = 6.0;
uniform float wave_speed = 1.0;
// How far the band pattern is pushed around by the warp. This is what stops it
// reading as plain stripes.
uniform float warp_strength = 26.0;
uniform float band_strength = 0.085;
uniform float foam_depth = 11.0;

varying vec2 world_pos;

// Sum of two sines at incommensurable frequencies: long enough period that the
// swell never visibly loops, and no texture lookup.
float swell(float x, float t) {
	return sin(x * 0.011 + t) * 0.62 + sin(x * 0.029 - t * 1.7) * 0.38;
}

void vertex() {
	vec2 wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	// 1 on the waterline, 0 a few units under it. The seabed vertices are far
	// below and get exactly 0.
	float on_surface = 1.0 - smoothstep(0.0, 10.0, abs(wp.y - surface_y));
	// Fade out at the banks, or the waves visibly detach from the shore.
	float inland = 1.0 - smoothstep(half_width * 0.86, half_width, abs(wp.x));
	float lift = swell(wp.x, TIME * wave_speed) * wave_amplitude * on_surface * inland;
	VERTEX.y += lift;
	world_pos = wp + vec2(0.0, lift);
}

void fragment() {
	float depth = world_pos.y - surface_y;
	float d = clamp(depth / max(max_depth, 1.0), 0.0, 1.0);

	vec4 col = mix(shallow_color, deep_color, smoothstep(0.0, 0.85, d));

	// Texture is wavy HORIZONTAL streaks, not a 2D blob pattern: seen from the
	// side, water reads as layered bands of light, and multiplying two sines
	// instead just gives drifting smoke.
	//
	// The warp goes into the phase rather than the position - pushing y around
	// by a function of x is exactly "bend these lines", and it costs one term.
	float warp = sin(world_pos.x * 0.008 - TIME * 0.35) * warp_strength;
	float streak = sin((world_pos.y + warp) * 0.055 + TIME * 0.5);
	// Second layer, finer and drifting the other way, to break up the first.
	float fine = sin((world_pos.y - warp * 0.6) * 0.13 - TIME * 0.9);
	float bands = streak * 0.7 + fine * 0.3;
	// Bands fade with depth: light does not reach the bottom of the strait.
	col.rgb += bands * band_strength * (1.0 - d);

	// Foam along the waterline. Modulated by the same swell so the crests are
	// brighter than the troughs.
	float foam = 1.0 - smoothstep(0.0, foam_depth, depth);
	foam *= 0.55 + 0.45 * swell(world_pos.x, TIME * wave_speed);
	col = mix(col, foam_color, clamp(foam, 0.0, 1.0) * foam_color.a);

	COLOR = col;
}
