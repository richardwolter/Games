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

// A waterfall landing in the strait. Zero strength is open water, which is every
// level that does not pour anything into it, and at zero every term below folds
// away to the water as it always was.
//
// Kept in the shader rather than being a second, wilder water body over the
// first: one surface with a local disturbance stays one waterline, so there is
// no seam where the calm water meets the churn.
uniform float churn_x = 0.0;
// How far from that point the churn is still felt. The falloff is smooth over
// this whole distance, so the strait grows steadily rougher as it nears the fall
// instead of stepping into a patch of rough water.
uniform float churn_reach = 0.0;
// How much taller and faster the swell gets right under the fall.
uniform float churn_strength = 0.0;

varying vec2 world_pos;

// Sum of two sines at incommensurable frequencies: long enough period that the
// swell never visibly loops, and no texture lookup.
float swell(float x, float t) {
	return sin(x * 0.011 + t) * 0.62 + sin(x * 0.029 - t * 1.7) * 0.38;
}

// 1 under the waterfall, 0 at churn_reach and beyond. Squared falloff: the water
// near a fall is violent and it calms off quickly, where a linear fade left half
// the strait mildly agitated.
float churn_at(float x) {
	if (churn_reach <= 0.0) {
		return 0.0;
	}
	float d = clamp(abs(x - churn_x) / churn_reach, 0.0, 1.0);
	float near = 1.0 - d;
	return near * near;
}

// The chop the fall itself puts on the surface: shorter wavelength and much
// faster than the swell, so it reads as water being hit rather than as weather.
float chop(float x, float t) {
	return sin(x * 0.075 - t * 5.3) * 0.6 + sin(x * 0.041 + t * 3.1) * 0.4;
}

void vertex() {
	vec2 wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	// 1 on the waterline, 0 a few units under it. The seabed vertices are far
	// below and get exactly 0.
	float on_surface = 1.0 - smoothstep(0.0, 10.0, abs(wp.y - surface_y));
	// Fade out at the banks, or the waves visibly detach from the shore.
	float inland = 1.0 - smoothstep(half_width * 0.86, half_width, abs(wp.x));
	float agitation = churn_at(wp.x) * churn_strength;
	float lift = swell(wp.x, TIME * wave_speed) * wave_amplitude * (1.0 + agitation);
	lift += chop(wp.x, TIME) * wave_amplitude * agitation * 0.8;
	lift *= on_surface * inland;
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
	// Foam thickens towards the fall as well: broken water holds air, and the band
	// widening is what makes the churn read from a long way out.
	float agitation = churn_at(world_pos.x) * churn_strength;
	float foam = 1.0 - smoothstep(0.0, foam_depth * (1.0 + agitation * 2.4), depth);
	foam *= 0.55 + 0.45 * swell(world_pos.x, TIME * wave_speed);
	foam *= 1.0 + agitation * 0.5;
	col = mix(col, foam_color, clamp(foam, 0.0, 1.0) * foam_color.a);

	COLOR = col;
}
