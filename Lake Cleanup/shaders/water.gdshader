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
//     grime. Depth, bands, glints and sparkle all add up to a position on a ramp, rounded to
//     the nearest step: solid areas with hard edges, never a dither. Per-pixel dither read as
//     grain on open water, left lone green pixels in cleaned bays, and shimmered under a
//     moving camera. Clean, murky and dirty are the same idea one level up — two cutoffs on
//     the local filth — and the filth map's blur keeps those contours the size of bays
//   - pattern animation ticks at `pixel_fps`. The swell open foam rides keeps real TIME,
//     because the rubbish riding the same swell moves smoothly — only it is rounded to whole
//     pixels, so the foam stays on the grid as it is carried
//
// Three effects, cheapest first:
//   - a depth gradient from the shore function, so the shallows read as shallow
//   - domain-warped bands, the moving surface texture
//   - a foam line along both shores: a ragged lip on the sand, a wash that runs up and
//     draws back, and loose bubbles between — see shore_foam()
//
// There is no vertex ripple. Seen from above, a displaced waterline would only move
// the rim of the polygon, and the surface motion the eye actually wants is in the
// bands and the glints — which cost nothing extra.
shader_type canvas_item;
render_mode blend_mix;

#include "res://shaders/pixel.gdshaderinc"

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

// The water's three ramps, deepest to lightest, from the master palette (scripts/palette.gd,
// resources/palette.tres). The lake script sets every one of these from the palette at
// runtime; the defaults here are the palette's values, so a material with none set still
// draws the right water.
//
// Step 0 deep, 1 mid, 2 the palette's base colour, 3 shallow, 4 light (glints on clean water,
// the scum's pale film on filthy water).
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
// murk is, in world pixels with the isometric squash taken out — half a tile to a tile.
// `murk_wobble` is how far, in filth, a patch pushes the water either side of where the map
// says it is: at the edges that is patches of the neighbouring state spilling across, and
// inside the murky band it is patches of both blue and green, more green toward the dirty
// side. Two noises rather than one — a slow broad one that bends the contour, a finer one
// that breaks it — or the edge is wavy but still one line.
uniform float murk_blotch = 48.0;
uniform float murk_wobble : hint_range(0.0, 0.5) = 0.28;

// And the flip staggered by shade: the dark troughs of the wave bands go over to the
// filthier ramp this much filth before the bright crests do. With every step flipping at
// once the edge was one line however much it wobbled — every colour changed on it together.
// Staggered, the boundary is a band of moving streaks in which both ramps are drawn.
uniform float state_spread : hint_range(0.0, 0.5) = 0.24;

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
// How many ramp steps a full glint lifts the water, toward the light step.
uniform float glint_steps = 2.2;

// The foam line against the sand, all in tiles measured in from the edge the water is drawn
// to. `foam_lip` is how deep the solid lip is on average, `foam_wash` how far past it the
// wash line runs out at the bottom of its surge, and `foam_line` how thick that wash line
// and each row of bubbles is.
uniform float foam_lip = 0.28;
uniform float foam_wash = 0.55;
uniform float foam_line = 0.09;

// The same foam, loose out on open water: short, thin, broken streaks scattered over the lake,
// each one growing, holding and falling apart before turning up somewhere else. See open_foam().
// `open_foam_chance` is the share of cells holding one at any moment, `open_foam_cell` how big a
// cell is in world pixels (with the 2:1 squash taken out), `open_foam_thick` how thick a streak
// is in those same units, and `open_foam_life` how long one lasts, in seconds.
uniform float open_foam_chance = 5.00;
uniform float open_foam_cell = 150.0;
uniform float open_foam_thick = 3.3;
uniform float open_foam_life = 8.0;
uniform float open_foam_strength = 9.55;

// The swell the floating rubbish rides, so loose foam rides it too. Mirrors
// LakeGrid.WAVE_AMPLITUDE and LakeGrid.SWAY, like foam.gdshader and rubbish.gdshader.
uniform float swell_amplitude = 5.0;
uniform float swell_sway = 3.2;

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

// 0 for a lake with work left in it, 1 for one that has none. The reward for finishing:
// the crests the water already has are let go wider and brighter, and a second, much
// finer pattern is switched on over them so the surface breaks into points of light
// rather than simply glowing harder. It is the same water, catching the sun at last.
uniform float sparkle : hint_range(0.0, 1.0) = 0.0;

// `sun_lean` is how far over the sun is, negative one side of noon and positive the other,
// and it slides the glint band across the water so the shine is a strip lying where the sun
// is rather than an even sheen over the whole basin.
//
// There is no sun tint here any more. Glints used to be added light, which had to be the
// colour of the light adding it; they are a palette step now, and the world's daylight
// multiply tints that step like every other pixel on screen.
uniform float sun_lean = 0.0;

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

// A streak of foam out on open water, 0 to 1, at a spot already snapped to foam pixels.
//
// The lake is cut into cells, and a few of them hold one streak each, placed off the cell's
// middle so the cells never show as a grid. Worked in a space with the isometric squash taken
// out, so a streak lies flat on the water rather than standing up on the screen. Every life a
// cell rolls again — whether it holds a streak, where, which way and how bent — so the foam
// wanders about the lake rather than blinking on and off in the same places.
//
// Same language as the shore foam: hard edges, broken into segments, no gradients.
float open_foam(vec2 at, float clock) {
	vec2 plane = vec2(at.x, at.y * 2.0);
	vec2 cell = floor(plane / open_foam_cell);
	float first = foam_hash(cell + vec2(3.1, 9.7));

	// Each cell on its own clock, so the whole lake does not bloom at once.
	float cell_clock = clock / open_foam_life + first;
	float life = fract(cell_clock);
	vec2 roll = cell + vec2(floor(cell_clock) * 17.3, floor(cell_clock) * 5.9);
	if (foam_hash(roll) > open_foam_chance) {
		return 0.0;
	}
	float h_x = foam_hash(roll + vec2(1.0, 0.0));
	float h_y = foam_hash(roll + vec2(0.0, 1.0));
	float h_turn = foam_hash(roll + vec2(2.0, 3.0));
	float h_bend = foam_hash(roll + vec2(5.0, 1.0));
	float h_len = foam_hash(roll + vec2(4.0, 7.0));

	// Off the middle, but by less than a cell's half minus the longest streak, so none reaches
	// across into a neighbour and gets cut off by the cell edge.
	vec2 middle = (cell + 0.5 + (vec2(h_x, h_y) - 0.5) * 0.3) * open_foam_cell;
	vec2 local = plane - middle;
	// Mostly along the iso grain, turned a little either way, and drifting slowly as it lives.
	float turn = (h_turn - 0.5) * 0.9;
	local = mat2(vec2(cos(turn), -sin(turn)), vec2(sin(turn), cos(turn))) * local;
	local.x -= life * 6.0;

	float half_len = open_foam_cell * (0.12 + h_len * 0.13);
	// Grows from the middle out, holds, then shortens away: a crest forming and breaking.
	float grown = half_len * sin(life * PI);
	float along = abs(local.x) / max(grown, 0.001);
	if (along >= 1.0) {
		return 0.0;
	}

	// A shallow arc, thickest in the middle and drawn to a point at the ends.
	float bend = (h_bend - 0.5) * 0.02;
	float off = local.y + local.x * local.x * bend;
	float thick = open_foam_thick * sqrt(1.0 - along * along);
	float line = step(abs(off), thick);

	// Broken into segments a few foam pixels long, and thinned further as it falls apart.
	float segment = foam_hash(roll + vec2(floor(local.x / (foam_pixel * 3.0)), 11.0));
	line *= step(0.25 + max(life - 0.6, 0.0) * 1.2, segment);
	return line;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	// The pixel this fragment belongs to, and everything below is worked out at its middle.
	vec2 cell = floor(world_pos / foam_pixel);
	vec2 px = (cell + 0.5) * foam_pixel;
	float clock = stepped_time(TIME, pixel_fps);

	vec2 tile = world_to_tile(px);
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

	// Which ramp this pixel reads from: clean under `murky_at`, dirty from `dirty_at`, murky
	// between. A bay being cleaned shrinks from green to a murky ring, then goes blue.
	//
	// color_t is also what the grime and the dirty foam go on, so all three agree on where
	// the water changes state.
	float color_t = pow(filth, color_bite);

	// The murk, drifting: patches that push this water up or down the filth before the
	// cutoffs read it. Flat on the water (the 2:1 squash taken out), crawling along the iso
	// grain on the stepped clock. Centred on zero, so where the map is well inside one state
	// nothing changes and the blotching lives only along the edges and inside the murky band.
	vec2 murk_at = vec2(px.x, px.y * 2.0) / max(murk_blotch, 1.0);
	murk_at += vec2(clock * 0.05, clock * 0.025);
	float broad = blob_noise(murk_at * 0.5 + vec2(7.3, 2.1)) - 0.5;
	float narrow = blob_noise(murk_at * 1.7 - vec2(3.9, 5.4)) - 0.5;
	float murk = (broad * 0.6 + narrow * 0.4) * 2.0 * murk_wobble;
	float state_t = clamp(color_t + murk, 0.0, 1.0);

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
	// Bands fade with filth: in a polluted lake, light does not get far at all.
	shade += bands * band_steps * (1.0 - filth * 0.75);

	// Glints: the sharp crests of the same pattern, and the thing that makes a flat
	// plane read as moving water rather than as painted floor. A cleaned lake takes them
	// lower down the wave and harder, so more of the surface is a crest.
	float glint = smoothstep(mix(0.86, 0.83, sparkle), 1.0, bands) * (1.0 - filth * 0.8);
	// The sun's own strip. Where the light is coming from low and to one side, the shine on
	// the water gathers into a band under it rather than spreading evenly: this weights the
	// crests by how near they are to the line the sun is on, and flattens back to an even
	// sheen as the sun climbs to noon and `sun_lean` goes to nothing.
	float sun_line = (px.x / (tile_w * 0.5)) * -sun_lean;
	float toward = 1.0 - clamp(abs(px.y / (tile_h * 0.5) - sun_line) * 0.02, 0.0, 1.0);
	float gather = mix(1.0, 0.35 + toward * 1.25, clamp(abs(sun_lean), 0.0, 1.0));
	shade += glint * glint_steps * (1.0 + sparkle * 0.3) * gather;

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

	// Onto the nearest step: solid areas, hard edges.
	float step_at = clamp(floor(shade + 0.5), 0.0, 4.0);

	// Which ramp, staggered by the shade: deep water (0) flips earliest, light (4) latest. On
	// the shade before it is rounded, so two pixels on the same step but different sides of
	// a band still flip at different moments — the mix runs finer than the steps do.
	float lean = (shade - 2.0) * 0.5 * state_spread;
	float state = step(murky_at + lean, state_t) + step(dirty_at + lean, state_t);
	vec3 col = ramp(step_at, state);

	// The foam line along both shores.
	vec2 foam_tile = tile;

	// The bank: distance in from the edge the water polygon is drawn to, in tiles. The shore's
	// wobble is left out of the conversion — it bends the width by a few percent either way,
	// which is exactly the unevenness a shoreline wants anyway.
	vec2 bank_d = (foam_tile - basin_centre) / (basin_radius + vec2(shore_lap));
	float bank_mean = (basin_radius.x + basin_radius.y) * 0.5 + shore_lap;
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

	// The island, read from the other side: outward from its beach. Half again as wide as the
	// bank's — its tiles are drawn over the water with a stepped edge, and a lip the bank's
	// width disappears under their corners. What is under the tiles' own corners is foam too,
	// so a gap between two diamonds shows white water rather than deep blue.
	//
	// Drawn here rather than over the tiles, so that the foam and the shoaling either side of
	// it are the same ring. Drawn on the ground it was a second ring just inside this one,
	// and two rings a few pixels apart read as a seam, not as a shore.
	vec2 isl_d = foam_tile - island_centre;
	float isl_mean = max((island_radius.x + island_radius.y) * 0.5 - shore_lap, 0.5);
	float isl_out = (island_fraction(foam_tile) - 1.0) * isl_mean;
	foam = max(foam, shore_foam(isl_out, atan(isl_d.y, isl_d.x), isl_mean, 1.5, clock, state));

	// And loose out on the open lake, kept a couple of tiles clear of both shores so it never
	// tangles with the lip and the wash there.
	float open_room = step(2.0, bank_in) * step(2.5, isl_out);
	// Riding the swell: the same bob and wander rubbish.gdshader gives a floating piece, taken
	// off the lookup so the streak is carried by it. Keyed to this spot's own x where a piece
	// uses its anchor's, which is the same wave laid continuously under the whole lake.
	//
	// Real TIME, not the stepped clock: the rubbish rides this smoothly, and foam that ticked
	// behind it would jitter against every piece it passes. Rounded to whole pixels instead, so
	// the streak is carried a pixel at a time and never lands between two.
	float swell_t = TIME * wave_speed;
	vec2 swell = vec2(
		sin(swell_t * 0.53 + px.x * 0.017) * swell_sway,
		(sin(px.x * 0.011 + swell_t) * 0.62 + sin(px.x * 0.029 - swell_t * 1.7) * 0.38)
			* swell_amplitude
			+ cos(swell_t * 0.41 + px.x * 0.023) * swell_sway * 0.5
	);
	vec2 foam_at = px - floor(swell / foam_pixel + 0.5) * foam_pixel;
	// Thinned with the state of the water it lies on: a crest of white on open water is a
	// clean-water thing, and murk breaks fewer of them. Fewer, not fainter — a faint streak
	// is a smear, and the streaks are drawn either whole or not at all.
	float open_keep = step(state * 0.35, foam_hash(floor(foam_at / open_foam_cell) + vec2(2.0, 8.0)));
	foam = max(foam, open_foam(foam_at, clock) * open_foam_strength * open_room * open_keep);

	// Dirty water keeps its foam, it just goes the colour of what it is churning: foam that
	// faded out with the filth left the filthy lake, the one the player starts on, with no
	// shoreline at all. The tint follows the state under it in three steps, so a streak
	// crossing from clean into murk into filth changes colour where the water does.
	vec3 foam_rgb = mix(foam_color.rgb, foam_dirty.rgb, state * 0.5);
	col = mix(col, foam_rgb, clamp(foam, 0.0, 1.0) * foam_color.a * (1.0 - filth * 0.25));

	COLOR = vec4(col, 1.0);
}
