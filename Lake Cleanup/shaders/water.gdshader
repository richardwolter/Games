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
// Pixel art (see pixel.gdshaderinc). The water is drawn, not rendered:
//   - every effect is worked out once per `foam_pixel` cell of world space, the art's own
//     pixel size, so nothing has an edge finer than the sprites beside it
//   - the only colours out are the palette's three water ramps, the foam swatches and the
//     grime. Depth, bands and sparkle all add up to a position on a ramp, rounded to
//     the nearest step: solid areas with hard edges, never a dither. Per-pixel dither read as
//     grain on open water, left lone green pixels in cleaned bays, and shimmered under a
//     moving camera. Clean, murky and dirty are the same idea one level up — two cutoffs on
//     the local filth — and the filth map's blur keeps those contours the size of bays
//   - pattern animation ticks at `pixel_fps`
//
// Three effects, cheapest first:
//   - a depth gradient from the shore function, so the shallows read as shallow
//   - domain-warped bands, the moving surface texture
//   - a foam line along both shores: a ragged lip on the sand, a wash that runs up and
//     draws back, and loose bubbles between — see shore_foam()
//
// There is no vertex ripple. Seen from above, a displaced waterline would only move
// the rim of the polygon, and the surface motion the eye actually wants is in the
// bands — which cost nothing extra.
//
// There are no glints either, by decision. The crests of the bands used to be lifted two
// steps to the palette's light step, and on clean water that was a set of pale strips
// running across the lake. Taken out; the light step is now the scum's film on filthy
// water and the sparkle's points on a finished lake, nothing else.
shader_type canvas_item;
render_mode blend_mix;

#include "res://shaders/pixel.gdshaderinc"

// Must match scripts/iso.gd. If these drift, the shaded shore and the drawn shore
// separate visibly, which is a loud enough failure to catch.
uniform float tile_w = 64.0;
uniform float tile_h = 32.0;
uniform vec2 basin_centre = vec2(46.0, 46.0);
uniform vec2 basin_radius = vec2(40.0, 34.0);

// The island in the middle. The water polygon spans it, and this shader discards its
// pixels inside the island's curve (see fragment()), which is what makes that curve the
// island's coast: the sand is drawn under the water, the same as the bank's, and the
// water's edge is the edge that is seen rather than the tiles' own staircase. The shading
// also has to know it is there, or the deepest, darkest water would show through around
// a beach that is supposed to be shallow.
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

// The water's three ramps, deepest to lightest, from the master palette (scripts/palette.gd,
// resources/palette.tres). The lake script sets every one of these from the palette at
// runtime; the defaults here are the palette's values, so a material with none set still
// draws the right water.
//
// Step 0 deep, 1 mid, 2 the palette's base colour, 3 shallow, 4 light (the scum's pale film
// on filthy water, the sparkle's points on a finished lake).
uniform vec4 water_clean_deep : source_color = vec4(0.173, 0.302, 0.431, 1.0);
uniform vec4 water_clean_mid : source_color = vec4(0.255, 0.42, 0.573, 1.0);
uniform vec4 water_clean : source_color = vec4(0.353, 0.525, 0.678, 1.0);
uniform vec4 water_clean_shallow : source_color = vec4(0.498, 0.655, 0.776, 1.0);
uniform vec4 water_clean_light : source_color = vec4(0.769, 0.859, 0.91, 1.0);
uniform vec4 water_dirty_deep : source_color = vec4(0.071, 0.18, 0.055, 1.0);
uniform vec4 water_dirty_mid : source_color = vec4(0.094, 0.227, 0.067, 1.0);
uniform vec4 water_dirty : source_color = vec4(0.118, 0.275, 0.082, 1.0);
uniform vec4 water_dirty_shallow : source_color = vec4(0.227, 0.353, 0.141, 1.0);
uniform vec4 water_dirty_light : source_color = vec4(0.369, 0.435, 0.227, 1.0);
uniform vec4 water_murky_deep : source_color = vec4(0.11, 0.24, 0.24, 1.0);
uniform vec4 water_murky_mid : source_color = vec4(0.16, 0.32, 0.31, 1.0);
uniform vec4 water_murky : source_color = vec4(0.22, 0.4, 0.38, 1.0);
uniform vec4 water_murky_shallow : source_color = vec4(0.34, 0.5, 0.45, 1.0);
uniform vec4 water_murky_light : source_color = vec4(0.55, 0.66, 0.58, 1.0);

// Where the water changes state, on the bent local filth (`color_t` below): clean under
// `murky_at`, dirty from `dirty_at`, murky between.
uniform float murky_at : hint_range(0.0, 1.0) = 0.3;
uniform float dirty_at : hint_range(0.0, 1.0) = 0.65;

// What keeps those two cutoffs from drawing as rings. `murk_blotch` is how wide a patch of
// murk is, in world pixels with the isometric squash taken out. `murk_wobble` is how far, in
// filth, a patch pushes the water either side of where the map says it is: the edges wander
// and breathe, and a little of each state spills across into the next. Two noises — a slow
// broad one that bends the contour, a finer one that breaks it — or the edge is wavy but
// still one line. `state_spread` staggers the flip by shade: the dark troughs of the wave
// bands go over to the filthier ramp a little before the bright crests, so the boundary is
// a band of moving streaks rather than a line every colour changes on together.
//
// These were taken out once (the map is a distance from the rubbish now, and at 0.28 wobble
// the blotches put green over water with nothing on it and blue under floating junk) and
// put back at less than half that, by decision: with the cutoffs read off the map alone the
// contours round the island sat dead still while the bands rippled across them, and a ring
// that does not move reads as paint. The spill at this strength is a few pixels.
uniform float murk_blotch = 48.0;
uniform float murk_wobble : hint_range(0.0, 0.5) = 0.1;
uniform float state_spread : hint_range(0.0, 0.5) = 0.1;

// Foam's body on clean water and what it goes to on filthy water, palette `foam` and
// `foam_dirty`. The alpha is how solid the foam is laid over the water.
uniform vec4 foam_color : source_color = vec4(0.933, 0.965, 0.984, 0.75);
uniform vec4 foam_dirty : source_color = vec4(0.8, 0.82, 0.678, 1.0);

// The size of one pixel of water on screen, in world units, and so the grid every effect here
// is worked out on. The pack is drawn at two world pixels a source pixel, and anything finer
// than that is a fizz laid over pixel art rather than part of it.
uniform float foam_pixel = 2.0;
// How many times a second the water's pattern moves on.
uniform float pixel_fps = 8.0;

// How hard the ramp choice bends toward filthy, on top of whatever `filth` already reads at
// this pixel (map-local where the map is live, `pollution` where it is not — see `filth`
// below). 1.0 leaves that reading alone; the map's own FILTH_EDGE already shapes it, so this
// is a second, optional twist on top rather than the primary shaping. Higher pulls blue in
// faster once a tile is even a little clear.
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
// How many ramp steps the bands move the water either way at their crest and trough. Under
// one keeps them a dithered shimmer between neighbouring steps rather than stripes of a
// different colour.
uniform float band_steps = 0.7;
// The least the bands swing the shade on foul water, in steps. Over half, or the swing
// never crosses a step and foul water sits still.
uniform float dirty_bands = 0.55;

// The foam line against the sand, all in tiles measured in from the edge the water is drawn
// to. `foam_lip` is how deep the solid lip is on average, `foam_wash` how far past it the
// wash line runs out at the bottom of its surge, and `foam_line` how thick that wash line
// and each row of bubbles is.
uniform float foam_lip = 0.28;
uniform float foam_wash = 0.55;
uniform float foam_line = 0.09;

// The island's coast laps. Its drawn edge is carried up the beach on a slow wave travelling
// round the shore, so the coastline breathes instead of sitting still on one curve. `coast_wave`
// is how far it runs at the crest, in tiles; `coast_waves` how many waves fit round the island;
// `coast_wave_speed` how fast they travel, on top of `wave_speed`.
//
// Drawing only, and outward only. `coast_lap` returns 0 to `coast_wave` and is never negative,
// so the drawn water only ever covers more of the island than the curve Iso holds, never less.
//
// This is the one place the shader's shore and Iso's deliberately part company, and the reason
// is that they cannot agree: Iso is static and has no time to carry, and mirroring a wave into
// it would make the ground under a walker's feet dry and wet again several times a second.
// Outward-only is what makes the divergence safe — the paint covers sand the code calls dry,
// and never exposes water the code calls wet, so the angler and the dog stay dry-correct by a
// line that does not move. `shore_lap` above is still mirrored (Iso.WATER_LAP_TILES); this is
// not, by decision.
//
// The foam is left on the static line — see shore_foam's caller. Its lip is `step(dist, lip_w)`
// with no lower bound, so it is already being drawn under the sand: water running up the beach
// uncovers lip rather than covering it, and the band simply reads wider at a crest and
// narrower in a trough. That is the wave, in the foam's own style, for nothing.
uniform float coast_wave = 0.18;
uniform float coast_waves = 3.0;
uniform float coast_wave_speed = 0.35;

// The grime caught along the outer bank: what colour it is and how solid, and how far out from
// the bank's edge it reaches at most, in tiles. Scaled by the water's filth, so it goes as
// that stretch of shore is cleaned. Drawn only where the water is in its dirty state, as a
// solid swatch — the alpha is not used.
uniform vec4 grime_color : source_color = vec4(0.27, 0.30, 0.17, 0.7);
uniform float grime_reach = 1.1;

// 0 clean, 1 filthy. Moves the water onto the dirty ramp and kills the band contrast, so a
// dirty lake looks opaque as well as green — murk is a loss of clarity, not just a hue change.
//
// The whole lake's figure, and the fallback: what the water does where there is no map.
// Everything below reads `filth`, not this directly — see `filth` below.
uniform float pollution = 1.0;

// Filth per tile, one texel per tile of the basin, red channel only. This is what makes
// cleaning a patch of lake visible AND what colours the water: the ramp choice, the band/
// glint/foam fade all read this, local, instead of the lake's whole-basin average — a bay just
// cleared reads blue while the next one over is still soup, and a tile never goes green just
// because the meter upstairs has not moved much yet.
//
// Sampled linearly, so the map's tile grid does not show through as squares: what is wanted
// is the boundary between clean and filthy water, soft, wherever the junk happens to stop.
// The value is only ever compared against the two cutoffs, so soft here means a smooth contour.
uniform sampler2D filth_map : filter_linear, repeat_disable;
uniform vec2 filth_tiles = vec2(92.0, 92.0);
// 0 to ignore the map and shade off `pollution` alone, 1 to read it. The lake sets this
// once the map exists; without it a missing texture would read as a spotless lake.
uniform float filth_mapped : hint_range(0.0, 1.0) = 0.0;

// The clean patches: a glimpse of the cleaned lake where a net has just closed. Each is
// (x, y) world centre, (z) radius in world px along the long axis, (w) how open it is,
// 1 at the moment of the catch down to 0 gone (the lake eases that). `patch_seeds` is a
// roll per patch, so two catches on the same spot are two shapes.
//
// Not a disc and not the net's ring. The plane is domain-warped by a noise rolled off the
// seed before the distance is measured (`patch_warp`, a fraction of the radius), so the
// outline is curved lobes and inlets rather than a circle — the trick that makes the
// murk's own blotches read as water. A fresh patch is clear right through: the threshold
// starts under the field's floor. As it closes the threshold climbs through a *ridged*
// noise on the warped plane — the grime comes back first along the ridge lines, as curved
// threads that thicken and run into each other, and the last clean water is the ground
// between them near the middle. That is the grime gathering, not a ring shrinking.
// Inside, the filth is taken to zero before the cutoffs read it, so the patch inherits the
// stepped ramps, the blotch wobble and the shade stagger like any clean bay, rather than
// being a colour laid over the water. A transient lie, by decision: the map says what is
// still in the water, the patch says what has just left it.
//
// `patch_blotch` is the noise's cell size in world px on the plane; `patch_shape` is how
// much the threads cut into the disc (0 a plain disc, 1 all lines); `patch_top` is where
// the threshold ends up (over the field's highest value, or the middle never closes);
// `patch_soft` the edge's softness in field units.
// Sizes mirror Lake.PATCHES and Lake.LANE_POINTS; the lake packs exactly that many.
uniform vec4 patches[14];
uniform float patch_seeds[14];
// The lane a reel with a catch aboard parts through the grime: a chain of small patches
// laid along the mouth's path, one roll per reel, closing the same way a patch does. Subtle
// by decision (2026-09-16, Richard: "very subtle but noticeable") — narrower than the
// mouth, and only ever a hint of blue in the wake.
uniform vec4 lane[24];
uniform float lane_seed = 0.5;
uniform float patch_blotch = 20.0;
uniform float patch_warp : hint_range(0.0, 1.0) = 0.5;
uniform float patch_shape : hint_range(0.0, 1.0) = 4;
uniform float patch_top = 1.8;
uniform float patch_soft = 0.42;

// 0 for a lake with work left in it, 1 for one that has none. The reward for finishing:
// the crests the water already has are let go wider and brighter, and a second, much
// finer pattern is switched on over them so the surface breaks into points of light
// rather than simply glowing harder. It is the same water, catching the sun at last.
uniform float sparkle : hint_range(0.0, 1.0) = 0.0;

// The tease of that sparkle on a lake with work left in it: rare single art-pixel pops of
// the top step on clean water, more of them the cleaner the whole lake is. Nothing while
// `glint` is zero. One pop per `glint_cell` art pixels square at most, `glint_rate` the
// odds of a cell popping on a given tick, ticks at `glint_fps`.
uniform float glint : hint_range(0.0, 1.0) = 0.0;
uniform float glint_cell = 14.0;
uniform float glint_rate = 0.09;
uniform float glint_fps = 5.0;

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

// How far up the island's beach the water is reaching at this angle round it, in tiles: 0 at
// the trough, `coast_wave` at the crest, never negative. See the uniforms for why it only
// ever runs one way.
//
// Whole waves per lap, so the ring closes on itself where atan() wraps from pi to minus pi —
// the same rule shore_foam's cells and tears follow, and the same reason. Two terms beating
// against each other rather than one: a single travelling sine reads as a scalloped border
// turning on the spot, which is a pattern, not water.
float coast_lap(float angle, float clock, float lobes) {
	float t = clock * wave_speed * coast_wave_speed;
	float drift = max(round(lobes * 0.37), 1.0);
	float s = sin(angle * lobes + t + sin(angle * drift - t * 0.31) * 1.6) * 0.5 + 0.5;
	return max(coast_wave, 0.0) * s;
}

// How many waves fit round a shore of this mean radius, as a whole number.
//
// `coast_waves` is the count round the island, and every other shore gets the count that keeps
// the same wavelength: the bank's mean is about five times the island's, so it gets about five
// times as many. The same count round both instead would make one wave on the bank some eighty
// tiles long, which reads as the coast not moving at all — the island is the shore the number
// was tuned on, so it is the one that holds it.
float coast_lobes(float mean) {
	float isl = max((island_radius.x + island_radius.y) * 0.5 - shore_lap, 0.5);
	return max(round(coast_waves * mean / isl), 1.0);
}

// One random number per cell, the same every time for the same cell.
float foam_hash(vec2 cell) {
	return cell_hash(cell);
}

// One step of one ramp: `step_at` 0 (deep) to 4 (light), `state` 0 clean, 1 murky, 2 dirty.
vec3 ramp(float step_at, float state) {
	vec3 clean_c;
	vec3 murky_c;
	vec3 dirty_c;
	if (step_at < 0.5) {
		clean_c = water_clean_deep.rgb;
		murky_c = water_murky_deep.rgb;
		dirty_c = water_dirty_deep.rgb;
	} else if (step_at < 1.5) {
		clean_c = water_clean_mid.rgb;
		murky_c = water_murky_mid.rgb;
		dirty_c = water_dirty_mid.rgb;
	} else if (step_at < 2.5) {
		clean_c = water_clean.rgb;
		murky_c = water_murky.rgb;
		dirty_c = water_dirty.rgb;
	} else if (step_at < 3.5) {
		clean_c = water_clean_shallow.rgb;
		murky_c = water_murky_shallow.rgb;
		dirty_c = water_dirty_shallow.rgb;
	} else {
		clean_c = water_clean_light.rgb;
		murky_c = water_murky_light.rgb;
		dirty_c = water_dirty_light.rgb;
	}
	if (state < 0.5) {
		return clean_c;
	}
	return state < 1.5 ? murky_c : dirty_c;
}

// How much foam is on the water at one spot near a shore, 0 to 1.
//
// `dist` is how far into the water the spot is, in tiles — negative is under the sand. `angle`
// is where round the shore it is, and `mean` is that shore's mean radius in tiles, which sets
// how many waves and cells fit round it: the same count round the island and round the bank
// would be pixels on one and tiles on the other. `clock` is the stepped time.
//
// Everything that varies round the shore does so in whole waves or whole cells per lap, so the
// ring closes on itself with no seam where atan() wraps from pi to minus pi.
//
// Three parts, and hard steps rather than smooth ramps for all of them — this sits against
// pixel-art sand, and a soft gradient there is what read as a flat, blurred separation:
//   - the lip, solid on the sand side, ragged and breaking into bubbles on the water side
//   - the wash, a thin broken line that surges out from the lip and runs back up to it
//   - flecks left behind between the two, thinning out as they get further from the sand
//
// `murk` is the state of the water it lies on, 0 clean to 2 dirty: murk keeps the lip but
// breaks up the wash and loses the flecks, so a filthy bank has a line of scum along it
// rather than a clean lake's fizz. Whole segments and bubbles are dropped, never faded.
float shore_foam(float dist, float angle, float mean, float wide, float clock, float murk) {
	float t = clock * wave_speed;
	float round_t = angle / TAU + 0.5;

	// The tear along the lip: two waves beating so it never reads as a scallop border.
	float tear = sin(angle * round(mean * 2.2) + t * 0.9) * 0.55
		+ sin(angle * round(mean * 5.3) - t * 1.3) * 0.45;
	float lip_w = foam_lip * wide * (0.8 + tear * 0.4);

	// About two cells a tile round the shore for the wash's segments, twice that for bubbles.
	float cells = max(round(mean * 12.0), 12.0);
	float along = mod(floor(round_t * cells * 2.0), cells * 2.0);
	float row = floor(dist / (foam_line * wide) - t * 0.5);
	float grain = foam_hash(vec2(along, row));

	// The lip. Its last third, on the water side, keeps only the bubbles that rolled high.
	float lip = step(dist, lip_w);
	lip *= mix(1.0, step(0.35 + murk * 0.2, grain), step(lip_w * 0.66, dist));

	// The wash: out at the bottom of the surge, back onto the lip at the top. Phase drifts
	// round the shore so the whole bank is not breathing in time.
	float surge = sin(t * 0.8 + sin(angle * round(mean * 0.19)) * 2.0 + angle * round(mean * 0.6))
		* 0.5 + 0.5;
	float wash_at = lip_w + foam_wash * wide * surge;
	float wash = step(abs(dist - wash_at), foam_line * wide * 0.5);
	// Broken into segments, and fainter the further out it has run.
	float segment = foam_hash(vec2(mod(floor(round_t * cells), cells), 7.0));
	wash *= step(0.3 + murk * 0.25, segment) * mix(1.0, 0.45, surge);

	// What the wash leaves behind as it draws back.
	float between = step(lip_w, dist) * step(dist, wash_at);
	float reach = clamp((dist - lip_w) / max(wash_at - lip_w, 0.001), 0.0, 1.0);
	float fleck = between * step(0.84 + reach * 0.12 + murk * 0.1, grain);

	return max(lip, max(wash * 0.75, fleck * 0.6));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// How clear one patch leaves the water at `px`: 0 untouched, 1 clean. `patch` is (x, y)
// world centre, (z) radius along the long axis, (w) how open; `seed` its roll. The 2:1
// squash is taken out first, where a mouth is a circle. See `patches` above for the shape.
float patch_clear(vec4 patch, float seed_roll, vec2 px) {
	if (patch.w <= 0.0) {
		return 0.0;
	}
	vec2 off = vec2(px.x - patch.x, (px.y - patch.y) * 2.0);
	// Well outside the reach even after the warp has pulled it about: skip.
	if (length(off) > patch.z * (1.0 + patch_warp)) {
		return 0.0;
	}
	vec2 seed = vec2(seed_roll * 37.1, seed_roll * 91.7);
	vec2 at = off / max(patch_blotch, 1.0) + seed;
	// Bend the plane, then measure: lobes and inlets, no circle.
	vec2 warp = vec2(blob_noise(at * 0.55 + vec2(11.3, 5.9)),
		blob_noise(at * 0.55 + vec2(23.7, 17.1))) - 0.5;
	vec2 bent = off + warp * 2.0 * patch_warp * patch.z;
	float d = length(bent) / max(patch.z, 1.0);
	if (d >= 1.0) {
		return 0.0;
	}
	// Ridged noise on the bent plane: 1 along the ridge lines, 0 away from them.
	vec2 line_at = bent / max(patch_blotch, 1.0) + seed;
	float n = blob_noise(line_at) * 0.6 + blob_noise(line_at * 2.1 + vec2(4.7, 1.3)) * 0.4;
	float lines = 1.0 - abs(n * 2.0 - 1.0);
	// The field: the disc falling off to its rim, cut low along the lines, so the
	// threshold reaches them first.
	float field = (1.0 - d) * mix(1.0, 1.6 - lines * 1.4, patch_shape);
	// The threshold climbs as the patch closes, from under the floor (a fresh patch is
	// clear right through) to over the top.
	float close = mix(-patch_soft, patch_top, 1.0 - patch.w);
	return smoothstep(close, close + patch_soft, field);
}

void fragment() {
	// The pixel this fragment belongs to, and everything below is worked out at its middle.
	vec2 cell = floor(world_pos / foam_pixel);
	vec2 px = (cell + 0.5) * foam_pixel;
	float clock = stepped_time(TIME, pixel_fps);

	vec2 tile = world_to_tile(px);
	// The island: no water inside its curve. That curve is the coast — Iso.past_shelf is the
	// same one in GDScript. Decided per foam_pixel cell like everything else here, so the edge
	// is pixel art too.
	//
	// `coast_lap` then carries the drawn edge up the beach and back on a slow wave. Drawing
	// only: the curve Iso holds has not moved, and the lap is never negative, so the angler and
	// the dog are still dry everywhere this used to discard — the water just washes over them.
	vec2 isl_d = tile - island_centre;
	float isl_mean = max((island_radius.x + island_radius.y) * 0.5 - shore_lap, 0.5);
	float lap = coast_lap(atan(isl_d.y, isl_d.x), clock, coast_lobes(isl_mean)) / isl_mean;
	if (island_fraction(tile) < 1.0 - lap) {
		discard;
	}

	// The outer bank, the same wave read from the other side. Outward is away from the middle
	// here, so this threshold rises where the island's fell.
	//
	// The bank's edge is carved here rather than by the polygon's rim, which is the whole
	// change: the water is drawn a good way past the waterline now (Lake.WATER_RIM) and this
	// cuts it back to wherever the wave has run to. Grow one without the other and either the
	// crest is clipped flat by the rim or the surplus is left standing on the sand.
	vec2 bank_d = (tile - basin_centre) / (basin_radius + vec2(shore_lap));
	float bank_mean = (basin_radius.x + basin_radius.y) * 0.5 + shore_lap;
	float bank_lap = coast_lap(atan(bank_d.y, bank_d.x), clock, coast_lobes(bank_mean)) / bank_mean;
	if (shore_fraction(tile) > 1.0 + bank_lap) {
		discard;
	}
	float s = clamp(shore_fraction(tile), 0.0, 1.0);
	// Mirrors Iso.depth_at: 0 at the bank, 1 over the deepest water.
	float d = sqrt(max(1.0 - s, 0.0));
	// The island stands in the deepest part of the basin, so the water has to shoal up to
	// it as well as down from the outer bank. Widened from 2.1: the old range shoaled up
	// in barely a tile, which read as a shelf dropped straight off rather than sloping —
	// the same abruptness the island's foam ring had.
	float isl = island_fraction(tile);
	d *= smoothstep(1.0, 2.6, isl);

	// How filthy this water is, here: local where the map is live (a bay just cleared is blue
	// while the next one over is still soup), `pollution` where it is not.
	float local = texture(filth_map, (tile + 0.5) / filth_tiles).r;
	float filth = mix(pollution, local, filth_mapped);
	// The clean patches and the reel's lane, on the plane.
	float patched = 0.0;
	for (int i = 0; i < 14; i++) {
		patched = max(patched, patch_clear(patches[i], patch_seeds[i], px));
	}
	for (int i = 0; i < 24; i++) {
		patched = max(patched, patch_clear(lane[i], lane_seed, px));
	}
	filth *= 1.0 - patched;

	// Which ramp this pixel reads from: clean under `murky_at`, dirty from `dirty_at`, murky
	// between. A bay being cleaned shrinks from green to a murky ring, then goes blue.
	//
	// color_t is also what the grime and the dirty foam go on, so all three agree on where
	// the water changes state.
	float color_t = pow(filth, color_bite);

	// Position on the ramp: the shallows up at step 3, the deep water down at step 0.
	float shade = mix(3.0, 0.0, smoothstep(0.15, 0.85, d));

	// Bands, warped in phase rather than in position — pushing the pattern around by a
	// function of the other axis is exactly "bend these lines", and it costs one term.
	// Run against the isometric grain rather than screen-horizontally, so the surface
	// reads as lying down.
	float along = px.x * 0.5 + px.y;
	float across = px.y * 2.0 - px.x * 0.5;
	float warp = sin(along * 0.006 - clock * 0.35) * warp_strength;
	float streak = sin((across + warp) * 0.02 + clock * 0.5);
	// Second layer, finer and drifting the other way, to break up the first.
	float fine = sin((across - warp * 0.6) * 0.055 - clock * 0.9);
	float bands = streak * 0.7 + fine * 0.3;
	// Bands fade with filth: in a polluted lake, light does not get far at all. Not to
	// nothing, though: below half a step the swing never crosses a step and the water sits
	// dead still, which is what foul water round the island did while the cleaner water
	// outside it kept moving. `dirty_bands` is the floor.
	shade += bands * max(band_steps * (1.0 - filth * 0.75), dirty_bands);

	// And, on a finished lake, the glitter: two fast waves crossed at an angle and cut off
	// near their peaks, which is a scatter of moving points rather than a sheen. Costs
	// nothing while sparkle is zero — the term is multiplied out.
	if (sparkle > 0.001) {
		float spark = sin(along * 0.19 + clock * 2.3) * sin(across * 0.23 - clock * 1.7);
		float grain = sin(along * 0.41 - clock * 3.1) * sin(across * 0.37 + clock * 2.6);
		// Cut very near the peak, so what survives is a scatter of small points rather than
		// a wash: this is light off wavelets, and wavelets are mostly not catching it.
		float points = smoothstep(0.962, 0.998, spark * 0.6 + grain * 0.4);
		// Thinned in the shallows: the shore is where the light is already brightest and
		// the collar of foam is about to be drawn over it.
		shade += points * sparkle * 4.0 * mix(0.5, 1.0, d);
	}

	// The glints: a lake coming clean catches the light now and then, well before it is
	// finished. Only on water the map calls clean, so a pop never lands in the soup.
	if (glint > 0.001 && filth < murky_at) {
		vec2 gcell = floor(cell / glint_cell);
		float tick = floor(TIME * glint_fps);
		float roll = cell_hash(gcell + vec2(tick * 17.3, tick * 5.9));
		if (roll < glint * glint_rate) {
			vec2 inner = cell - gcell * glint_cell;
			vec2 spot = floor(vec2(
				cell_hash(gcell * 1.7 + vec2(tick, 3.0)),
				cell_hash(gcell * 2.3 - vec2(5.0, tick))
			) * glint_cell);
			if (inner.x == spot.x && inner.y == spot.y) {
				shade += 4.0;
			}
		}
	}

	// Onto the nearest step: solid areas, hard edges.
	float step_at = clamp(floor(shade + 0.5), 0.0, 4.0);

	// The murk, drifting: patches that push this water up or down the filth before the
	// cutoffs read it. Flat on the water (the 2:1 squash taken out), crawling along the iso
	// grain on the stepped clock. Centred on zero, so where the map is well inside one state
	// nothing changes and the wobble lives only along the edges.
	vec2 murk_at = vec2(px.x, px.y * 2.0) / max(murk_blotch, 1.0);
	murk_at += vec2(clock * 0.05, clock * 0.025);
	float broad = blob_noise(murk_at * 0.5 + vec2(7.3, 2.1)) - 0.5;
	float narrow = blob_noise(murk_at * 1.7 - vec2(3.9, 5.4)) - 0.5;
	float murk = (broad * 0.6 + narrow * 0.4) * 2.0 * murk_wobble;
	float state_t = clamp(color_t + murk, 0.0, 1.0);
	// Which ramp, staggered by the shade: deep water (0) flips earliest, light (4) latest, on
	// the shade before it is rounded so the mix runs finer than the steps do.
	float lean = (shade - 2.0) * 0.5 * state_spread;
	float state = step(murky_at + lean, state_t) + step(dirty_at + lean, state_t);
	vec3 col = ramp(step_at, state);

	// The foam line along both shores.
	vec2 foam_tile = tile;

	// The bank: distance in from the edge the water polygon is drawn to, in tiles. The shore's
	// wobble is left out of the conversion — it bends the width by a few percent either way,
	// which is exactly the unevenness a shoreline wants anyway.
	// Measured off the static line, not the lapped one, for the same reason the island's is:
	// the lip is solid for every `dist` below `foam_lip`, negative included, so the wave running
	// up the beach uncovers foam instead of sliding out from under it. `bank_d` and `bank_mean`
	// are the ones the discard above already worked out.
	float bank_in = (1.0 - shore_fraction(foam_tile)) * bank_mean;
	float foam = shore_foam(bank_in, atan(bank_d.y, bank_d.x), bank_mean, 1.0, clock, state);

	// Grime along the outer bank: blotches of scum caught in the shallowest water, under the
	// foam. Driven by this water's own filth, so it goes as the washed-up rubbish is fetched
	// away. Blotches rather than a band, in 4-pixel cells, so it reads as muck lying on the
	// water rather than a darker stripe drawn along the shore.
	vec2 grime_at = vec2(px.x, px.y * 2.0);
	float grime_cell = foam_hash(floor(grime_at / 4.0));
	float grime_patch = foam_hash(floor(grime_at / 22.0) + vec2(5.0, 3.0));
	float grime_band = step(bank_in, grime_reach * (0.5 + grime_patch * 0.8));
	float grime = grime_band * step(0.35, grime_cell) * step(0.3, grime_patch) * step(1.5, state);
	col = mix(col, grime_color.rgb, grime);

	// The island, read from the other side: outward from its beach. The same width as the
	// bank's now that the island's sand is under the water too — it was half again as wide
	// while the tiles were drawn over the water with a stepped edge, to cover their corners.
	//
	// Measured off the static curve, not the lapped one, by decision: the lip is solid for
	// every `dist` below `foam_lip`, negative included, so it is already drawn under the sand.
	// A wave running up the beach therefore uncovers foam instead of sliding out from under it,
	// and the band widens and narrows with the water at no cost. `isl_d` and `isl_mean` are the
	// ones the discard above already worked out.
	float isl_out = (island_fraction(foam_tile) - 1.0) * isl_mean;
	foam = max(foam, shore_foam(isl_out, atan(isl_d.y, isl_d.x), isl_mean, 1.0, clock, state));

	// There used to be loose foam out on the open lake here — short white streaks riding the
	// swell. Taken out by decision: white lines running through clean water read as a
	// distraction rather than as weather.

	// Dirty water keeps its foam, it just goes the colour of what it is churning: foam that
	// faded out with the filth left the filthy lake, the one the player starts on, with no
	// shoreline at all. The tint follows the state under it in three steps, so a streak
	// crossing from clean into murk into filth changes colour where the water does.
	vec3 foam_rgb = mix(foam_color.rgb, foam_dirty.rgb, state * 0.5);
	col = mix(col, foam_rgb, clamp(foam, 0.0, 1.0) * foam_color.a * (1.0 - filth * 0.25));

	COLOR = vec4(col, 1.0);
}
