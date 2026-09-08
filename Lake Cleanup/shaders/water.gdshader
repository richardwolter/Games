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

// How far the drawn water is carried past the waterline, in tiles, so it laps over the
// first of the sand instead of stopping on a tile edge.
//
// Deliberately not part of the shore maths above: those mirror Iso and must not drift from
// it, because the walking, the casting and the ferry all read the same functions. This is a
// drawing offset laid on top of them — the shore has not moved, the water is just drawn a
// little further up the beach. The polygon this shader runs on is grown to match.
uniform float shore_lap = 0.45;

// Water colors derived from master palette (scripts/palette.gd, resources/palette.tres).
// Clean lake uses water_clean (#6482a0, RGB(100, 130, 160)).
// Dirty lake blends toward water_dirty (#5c767d, RGB(92, 118, 125)).
//
// Defaults provided here; at runtime these are set by the lake script from the palette.
uniform vec4 water_clean : source_color = vec4(0.39, 0.51, 0.63, 1.0);  // #6482a0
uniform vec4 water_dirty : source_color = vec4(0.36, 0.46, 0.49, 1.0);   // #5c767d
uniform vec4 foam_color : source_color = vec4(0.96, 0.99, 1.0, 0.75);

// How hard the base colour and the scum bend toward filthy, on top of whatever `filth`
// already reads at this pixel (map-local where the map is live, `pollution` where it is
// not — see `filth` below). 1.0 leaves that reading alone; the map's own FILTH_EDGE
// already shapes it, so this is a second, optional twist on top rather than the primary
// shaping. Higher pulls blue in faster once a tile is even a little clear.
//
// Used to bend the un-mapped `pollution` value directly, which is why it used to sit at
// 6.0 — high enough to fight FILTH_BITE's own bend (lake.gd) on top of it. That compounded
// with the map live: pow(pow(0.7, 0.62), 6) reads almost spotless at 30% still in the
// water. Left low now that this reads `filth`, which is local and not pre-bent.
uniform float color_bite : hint_range(1.0, 10.0) = 1.4;

uniform float wave_speed = 1.0;
// How far the band pattern is pushed around by the warp. This is what stops it
// reading as plain stripes.
uniform float warp_strength = 26.0;
uniform float band_strength = 0.075;
// Width of the foam collar, as a fraction of the way in from the shore.
uniform float foam_band = 0.026;

// 0 clean, 1 filthy. Adds a flat scum tint on top of the depth gradient and kills the
// band contrast, so a dirty lake looks opaque as well as green — murk is a loss of
// clarity, not just a hue change.
//
// The whole lake's figure, and the fallback: what the water does where there is no map.
// Everything below reads `filth`, not this directly — see `filth` below.
uniform float pollution = 1.0;

// Filth per tile, one texel per tile of the basin, red channel only. This is what makes
// cleaning a patch of lake visible AND what colours the water: the base colour, the scum
// film and the band/glint/foam fade all read this, local, instead of the lake's whole-basin
// average — a bay just cleared reads blue while the next one over is still soup, and a
// tile never goes green just because the meter upstairs has not moved much yet.
//
// Sampled linearly, so the map's tile grid does not show through as squares: what is wanted
// is the boundary between clean and filthy water, soft, wherever the junk happens to stop.
uniform sampler2D filth_map : filter_linear, repeat_disable;
uniform vec2 filth_tiles = vec2(92.0, 92.0);
// 0 to ignore the map and shade off `pollution` alone, 1 to read it. The lake sets this
// once the map exists; without it a missing texture would read as a spotless lake.
uniform float filth_mapped : hint_range(0.0, 1.0) = 0.0;

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
	vec2 d = (tile - basin_centre) / (basin_radius + vec2(shore_lap));
	float r = length(d);
	if (r < 0.0001) {
		return 0.0;
	}
	float angle = atan(d.y, d.x);
	float wobble = 1.0 + 0.09 * sin(angle * 3.0) + 0.05 * sin(angle * 5.0 + 1.3);
	return r / wobble;
}

// Mirrors Iso.island_fraction: under 1 is on the island.
//
// Wobble raised from (0.04, 0.02) and a third term added (see iso.gd for the reasoning —
// this has to move in step with it or the shaded shore and the drawn one part ways). Still
// short of the basin's own (0.09, 0.05): a shape this small at that amplitude comes out a
// star, not a coastline.
float island_fraction(vec2 tile) {
	vec2 d = (tile - island_centre) / max(island_radius - vec2(shore_lap), vec2(0.5));
	float r = length(d);
	if (r < 0.0001) {
		return 0.0;
	}
	float angle = atan(d.y, d.x);
	float wobble = 1.0 + 0.07 * sin(angle * 3.0 + 0.7) + 0.035 * sin(angle * 5.0 - 0.4)
		+ 0.02 * sin(angle * 7.0 + 2.1);
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
	// it as well as down from the outer bank. Widened from 2.1: the old range shoaled up
	// in barely a tile, which read as a shelf dropped straight off rather than sloping —
	// the same abruptness the island's foam ring had.
	float isl = island_fraction(tile);
	d *= smoothstep(1.0, 2.6, isl);

	// How filthy this water is, here. Read before the colour so the colour can be built
	// from it: local where the map is live (a bay just cleared is blue while the next one
	// over is still soup), `pollution` where it is not.
	float local = texture(filth_map, (tile + 0.5) / filth_tiles).r;
	float filth = mix(pollution, local, filth_mapped);

	// Derive water colors from the filth here, not the lake's whole-basin average: a clean
	// bay reads blue on the spot instead of waiting for the meter upstairs to catch up.
	// Shallow water is lighter/brighter, deep water is darker.
	//
	// color_t is also what the scum below fades on: scum is a green muck film on top
	// of this gradient, and if it kept fading on raw `filth` while the gradient underneath
	// it fades on color_t, the muck would go on painting the water green for most of the
	// range regardless of how blue the water under it had already become — the two have to
	// agree on how early "clean" arrives.
	float color_t = pow(filth, color_bite);
	vec4 base_color = mix(water_clean, water_dirty, color_t);
	vec4 shallow_color = mix(base_color, vec4(1.0), 0.2);
	shallow_color.a = 0.92;
	vec4 deep_color = vec4(base_color.rgb * 0.6, 0.98);
	vec4 scum_color = mix(water_dirty, vec4(0.25, 0.36, 0.15, 1.0), color_t);

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
	col.rgb += bands * band_strength * (1.0 - filth * 0.75);

	// Glints: the sharp crests of the same pattern, and the thing that makes a flat
	// plane read as moving water rather than as painted floor. A cleaned lake takes them
	// lower down the wave and harder, so more of the surface is a crest.
	float glint = smoothstep(mix(0.86, 0.83, sparkle), 1.0, bands) * (1.0 - filth * 0.8);
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
	float scum = color_t * mix(1.0, 0.7, d);
	col.rgb = mix(col.rgb, scum_color.rgb, scum * 0.75);
	col.a = clamp(col.a + scum * 0.2, 0.0, 1.0);

	// Foam collar against the bank, wobbling so the line is not a clean stencil edge.
	float lap = 1.0 + 0.35 * sin(along * 0.02 + TIME * 1.4);
	float foam = smoothstep(1.0 - foam_band * lap, 1.0, s) * (1.0 - filth * 0.6);
	// And the same collar round the island, read from the other side: 1 on its beach, falling
	// off outward. Half again as wide as the bank's rather than exactly it — the island's
	// own wobble is smaller (it has to stay a coastline, not a star, at a shape this size),
	// so a collar the same width as the bank's still read as a hard ring where the bank's
	// did not. The extra width is what the shape can't carry on its own.
	//
	// Drawn here rather than over the tiles, so that the foam and the shoaling either side of
	// it are the same ring. Drawn on the ground it was a second ring just inside this one,
	// and two rings a few pixels apart read as a seam, not as a shore.
	float isl_foam = (1.0 - smoothstep(1.0, 1.0 + foam_band * lap * 1.5, isl))
		* (1.0 - filth * 0.6);
	foam = max(foam, isl_foam);
	col = mix(col, foam_color, clamp(foam, 0.0, 1.0) * foam_color.a);

	COLOR = col;
}
