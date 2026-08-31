// Lake surface, seen isometrically.
//
// The water is one filled polygon covering the whole basin, so every pixel of it is
// surface — there is no cross-section to shade any more. Depth is not a screen
// coordinate here; it is a property of the tile under the pixel, so the fragment
// shader inverts the isometric projection and asks the same shore function the
// geometry and the tile depths use. That is what keeps the shaded shallows welded to
// the drawn shore.
//
// Everything is driven by WORLD position, not UV: the polygon's outline is generated
// in code, so its UVs are not something to key an effect to.
//
// Three effects, cheapest first:
//   - a depth gradient from the shore function, so the shallows read as shallow
//   - domain-warped bands, the moving surface texture
//   - foam along the waterline, strongest where the water is thinnest
//
// There is no vertex ripple. Seen from above, a displaced waterline would only move
// the rim of the polygon, and the surface motion the eye actually wants is in the
// bands and the glints — which cost nothing extra.
shader_type canvas_item;
render_mode blend_mix;

// Must match scripts/iso.gd. If these drift, the shaded shore and the drawn shore
// separate visibly, which is a loud enough failure to catch.
uniform float tile_w = 64.0;
uniform float tile_h = 32.0;
uniform vec2 basin_centre = vec2(46.0, 46.0);
uniform vec2 basin_radius = vec2(40.0, 34.0);

// The island in the middle. The water polygon still spans it — the island's own shapes
// are drawn on top — but the shading has to know it is there, or the deepest, darkest
// water would show through around a beach that is supposed to be shallow.
uniform vec2 island_centre = vec2(46.0, 46.0);
uniform vec2 island_radius = vec2(4.6, 3.9);

uniform vec4 shallow_color : source_color = vec4(0.24, 0.55, 0.66, 0.92);
uniform vec4 deep_color : source_color = vec4(0.05, 0.16, 0.28, 0.98);
uniform vec4 foam_color : source_color = vec4(0.72, 0.88, 0.92, 0.55);

uniform float wave_speed = 1.0;
// How far the band pattern is pushed around by the warp. This is what stops it
// reading as plain stripes.
uniform float warp_strength = 26.0;
uniform float band_strength = 0.075;
// Width of the foam collar, as a fraction of the way in from the shore.
uniform float foam_band = 0.055;

// 0 clean, 1 filthy. Adds a flat scum tint on top of the depth gradient and kills the
// band contrast, so a dirty lake looks opaque as well as brown — murk is a loss of
// clarity, not just a hue change.
uniform float pollution = 1.0;
uniform vec4 scum_color : source_color = vec4(0.35, 0.31, 0.16, 1.0);

// 0 for a lake with work left in it, 1 for one that has none. The reward for finishing:
// the crests the water already has are let go wider and brighter, and a second, much
// finer pattern is switched on over them so the surface breaks into points of light
// rather than simply glowing harder. It is the same water, catching the sun at last.
uniform float sparkle : hint_range(0.0, 1.0) = 0.0;

varying vec2 world_pos;

// The inverse projection, mirroring Iso.world_to_tile.
vec2 world_to_tile(vec2 p) {
	float a = p.x / (tile_w * 0.5);
	float b = p.y / (tile_h * 0.5);
	return vec2((b + a) * 0.5, (b - a) * 0.5);
}

// Mirrors Iso.shore_fraction: 0 in the middle, 1 on the waterline.
float shore_fraction(vec2 tile) {
	vec2 d = (tile - basin_centre) / basin_radius;
	float r = length(d);
	if (r < 0.0001) {
		return 0.0;
	}
	float angle = atan(d.y, d.x);
	float wobble = 1.0 + 0.09 * sin(angle * 3.0) + 0.05 * sin(angle * 5.0 + 1.3);
	return r / wobble;
}

// Mirrors Iso.island_fraction: under 1 is on the island.
float island_fraction(vec2 tile) {
	vec2 d = (tile - island_centre) / island_radius;
	float r = length(d);
	if (r < 0.0001) {
		return 0.0;
	}
	float angle = atan(d.y, d.x);
	float wobble = 1.0 + 0.11 * sin(angle * 3.0 + 0.7) + 0.06 * sin(angle * 5.0 - 0.4);
	return r / wobble;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 tile = world_to_tile(world_pos);
	float s = clamp(shore_fraction(tile), 0.0, 1.0);
	// Mirrors Iso.depth_at: 0 at the bank, 1 over the deepest water.
	float d = sqrt(max(1.0 - s, 0.0));
	// The island stands in the deepest part of the basin, so the water has to shoal up to
	// it as well as down from the outer bank.
	float isl = island_fraction(tile);
	d *= smoothstep(1.0, 2.1, isl);

	vec4 col = mix(shallow_color, deep_color, smoothstep(0.15, 0.85, d));

	// Bands, warped in phase rather than in position — pushing the pattern around by a
	// function of the other axis is exactly "bend these lines", and it costs one term.
	// Run against the isometric grain rather than screen-horizontally, so the surface
	// reads as lying down.
	float along = world_pos.x * 0.5 + world_pos.y;
	float across = world_pos.y * 2.0 - world_pos.x * 0.5;
	float warp = sin(along * 0.006 - TIME * 0.35) * warp_strength;
	float streak = sin((across + warp) * 0.02 + TIME * 0.5);
	// Second layer, finer and drifting the other way, to break up the first.
	float fine = sin((across - warp * 0.6) * 0.055 - TIME * 0.9);
	float bands = streak * 0.7 + fine * 0.3;
	// Bands fade with filth: in a polluted lake, light does not get far at all.
	col.rgb += bands * band_strength * (1.0 - pollution * 0.75);

	// Glints: the sharp crests of the same pattern, and the thing that makes a flat
	// plane read as moving water rather than as painted floor. A cleaned lake takes them
	// lower down the wave and harder, so more of the surface is a crest.
	float glint = smoothstep(mix(0.86, 0.83, sparkle), 1.0, bands) * (1.0 - pollution * 0.8);
	col.rgb += glint * (0.22 + sparkle * 0.06);

	// And, on a finished lake, the glitter: two fast waves crossed at an angle and cut off
	// near their peaks, which is a scatter of moving points rather than a sheen. Costs
	// nothing while sparkle is zero — the term is multiplied out.
	if (sparkle > 0.001) {
		float spark = sin(along * 0.19 + TIME * 2.3) * sin(across * 0.23 - TIME * 1.7);
		float grain = sin(along * 0.41 - TIME * 3.1) * sin(across * 0.37 + TIME * 2.6);
		// Cut very near the peak, so what survives is a scatter of small points rather than
		// a wash: this is light off wavelets, and wavelets are mostly not catching it.
		float points = smoothstep(0.962, 0.998, spark * 0.6 + grain * 0.4);
		// Thinned in the shallows: the shore is where the light is already brightest and
		// the collar of foam is about to be drawn over it.
		col.rgb += points * sparkle * 1.05 * mix(0.5, 1.0, d);
	}

	// Scum. Strongest in the shallows where the muck collects, and it takes opacity
	// with it.
	float scum = pollution * mix(1.0, 0.7, d);
	col.rgb = mix(col.rgb, scum_color.rgb, scum * 0.75);
	col.a = clamp(col.a + scum * 0.2, 0.0, 1.0);

	// Foam collar against the bank, wobbling so the line is not a clean stencil edge.
	float lap = 1.0 + 0.35 * sin(along * 0.02 + TIME * 1.4);
	float foam = smoothstep(1.0 - foam_band * lap, 1.0, s) * (1.0 - pollution * 0.6);
	// And the same collar around the island, read from the other side: 1 on its beach,
	// falling off outward.
	float isl_foam = (1.0 - smoothstep(1.0, 1.0 + foam_band * 4.0 * lap, isl))
		* (1.0 - pollution * 0.6);
	foam = max(foam, isl_foam);
	col = mix(col, foam_color, clamp(foam, 0.0, 1.0) * foam_color.a);

	COLOR = col;
}
