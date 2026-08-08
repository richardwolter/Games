// The strait's ground, dry and submerged alike.
//
// This is ONE shader for the shores and the seabed on purpose. They used to be
// two, and the join showed: the shore polygon's inner face and the seabed's
// outer end met along a vertical line where dusty tan changed to wet rock in a
// single pixel. Nothing about a stronger texture fixes that - the cut IS the
// palette change - so the two palettes are now the ends of one gradient and the
// strata run through the join uninterrupted.
//
// Two blends decide what a fragment looks like:
//   - `shore_mix`, from horizontal distance to the waterline. Inland is dusty
//     desert; the strait is wet rock. The crossover is wide and noise-broken.
//   - depth below the surface, which drives the sunlit crust on top and the
//     fade to unlit at the bottom.
//
// World-space like the rest: these polygons are rebuilt per level at different
// sizes, so UV-keyed detail would stretch as levels get wider.
shader_type canvas_item;

uniform float surface_y = 300.0;
// |x| beyond this is dry land. The waterline, in other words.
uniform float waterline_x = 1600.0;
// Half-width of the desert-to-rock crossover, in world units.
uniform float shore_blend = 300.0;

// Dry side: sun-baked dirt in section.
uniform vec4 crust_color : source_color = vec4(0.78, 0.66, 0.45, 1.0);
uniform vec4 sand_color : source_color = vec4(0.56, 0.46, 0.32, 1.0);
uniform vec4 sand_deep_color : source_color = vec4(0.26, 0.21, 0.16, 1.0);

// Wet side: fractured stone.
uniform vec4 rock_color : source_color = vec4(0.31, 0.29, 0.26, 1.0);
uniform vec4 rock_deep_color : source_color = vec4(0.13, 0.13, 0.13, 1.0);

uniform vec4 algae_color : source_color = vec4(0.26, 0.38, 0.26, 1.0);
// 0 for the ground body, turned up on the crust strip laid along the seabed.
uniform float algae_mix : hint_range(0.0, 1.0) = 0.0;

uniform float crust_depth = 26.0;
// 1 when the mesh carries its own depth-below-its-top-face in its vertex
// colour, which world.gd fills in for the banks.
//
// The crust is a sunlit skin on the top face of dry ground, and its depth used
// to be measured from the WATERLINE. On a flat level those are the same line and
// it worked. On a level whose far bank climbs, every fragment of the climb is
// above the waterline, so the crust term saturated across the whole hill and
// painted it one flat slab of crust colour — a pale mound with no rock in it,
// sitting next to ground that had plenty.
uniform float local_depth : hint_range(0.0, 1.0) = 0.0;
// World units per unit of that colour. MUST MATCH World.DEPTH_IN_COLOUR.
uniform float depth_in_colour = 4000.0;
// 1 for ground that is dry because it stands ABOVE THE WATERLINE rather than
// because it is beyond the bank.
//
// The wet/dry split is normally horizontal — |x| past the bank is dry — which is
// the whole truth for a strait cut between two shores. A pillar standing in the
// middle of the water is at x = 0, so by that measure every part of it is wet,
// including the head in the open air. Keyed on height instead, it is wet up to
// the waterline and dry above it, which is what a rock in water actually is.
uniform float dry_by_height : hint_range(0.0, 1.0) = 0.0;
uniform float strata_depth = 520.0;
uniform float strata_strength = 0.055;
// Kept low. An early version ran the mottling at 0.10 and the rock came out
// looking like television static resolving into smoke - stone reads as stone
// through structure (veins, strata), not through contrast.
uniform float mottle_strength = 0.035;
uniform float grit_strength = 0.055;
uniform float vein_strength = 0.10;
uniform float fade_depth = 700.0;
// 1 draws the fine rock detail, 0 skips it. Set to 0 by world.gd on the web
// build, where this shader covers most of the screen and the GPU budget is
// whatever the browser happens to give us.
uniform float detail : hint_range(0.0, 1.0) = 1.0;

varying vec2 world_pos;
// Depth below this mesh's own top face, unpacked from the vertex colour.
varying float mesh_depth;

// Cheap hash noise. No texture, no setup, and at these amplitudes the pattern's
// flaws are invisible.
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	mesh_depth = COLOR.r * depth_in_colour;
}

void fragment() {
	float below = world_pos.y - surface_y;

	// Ragged crossover. A clean smoothstep still reads as a boundary because the
	// eye finds the straight edge; wobbling it with noise hides where it is.
	float wobble = (value_noise(world_pos * 0.008) - 0.5) * shore_blend * 0.9;
	float shore_mix = smoothstep(
		waterline_x - shore_blend,
		waterline_x + shore_blend,
		abs(world_pos.x) + wobble
	);
	// The same crossover turned on its side, for rock that stands out of the
	// water rather than beside it. Wobbled by the same noise, so the tide line
	// around a pillar is as ragged as the one along the banks.
	shore_mix = mix(
		shore_mix,
		smoothstep(shore_blend * 0.25, -shore_blend * 0.25, below + wobble),
		dry_by_height
	);

	vec4 shallow = mix(rock_color, sand_color, shore_mix);
	vec4 deep = mix(rock_deep_color, sand_deep_color, shore_mix);
	vec4 col = mix(shallow, deep, smoothstep(0.0, fade_depth, below));

	// Strata. These run the full width, across the join, which is most of what
	// sells the two sides as one body of ground: the bands line up.
	float bend = value_noise(world_pos * vec2(0.004, 0.02)) * 34.0;
	float strata = sin((below + bend) * 0.055);
	col.rgb += strata * strata_strength * (1.0 - smoothstep(0.0, strata_depth, below))
		* (0.35 + 0.65 * shore_mix);

	// Mottling, everywhere but strongest in the rock.
	float patches = value_noise(world_pos * 0.012);
	float blotch = value_noise(world_pos * 0.048 + 17.0);
	col.rgb += ((patches * 0.6 + blotch * 0.4) - 0.5) * mottle_strength * 2.0;

	// The fine detail: five of this shader's nine noise lookups, and the five
	// least visible. Skipped entirely where fill rate is scarce.
	//
	// The branch is on a uniform, so it is the same for every fragment in the
	// draw and costs nothing — this is not a per-pixel decision. What it buys is
	// most of the shader: the ground covers the seabed and both shores, so it is
	// the largest surface on screen, and nine noise lookups is thirty-six sin()
	// calls on every pixel of it.
	if (detail > 0.5) {
		// Veins: dark cracks where a noise field crosses its midpoint. Thin and
		// frequent - wide, slow-wandering veins read as cracked leather, not
		// stone. Fades out inland, where the ground is dirt rather than rock.
		float v1 = value_noise(world_pos * 0.055 + 5.0) - 0.5;
		float v2 = value_noise(world_pos * 0.115 + 91.0) - 0.5;
		float veins = smoothstep(0.020, 0.0, abs(v1)) * 0.65
			+ smoothstep(0.014, 0.0, abs(v2)) * 0.35;
		col.rgb -= veins * vein_strength * (1.0 - shore_mix * 0.75);

		// Grit. Frequencies here are periods in world units - anything finer
		// than a few units averages to flat grey on screen and shimmers when the
		// camera moves, which is exactly how the first pass went wrong.
		float grit = value_noise(world_pos * 0.16) * 0.55
			+ value_noise(world_pos * 0.045) * 0.45;
		col.rgb += (grit - 0.5) * grit_strength;

		// Pebbles and dry scrub on the desert side only.
		float speck = value_noise(world_pos * 0.28 + 40.0);
		col.rgb -= smoothstep(0.86, 1.0, speck) * 0.13 * shore_mix;
	}

	// Sunlit crust along the top of the dry ground, with a broken lower edge.
	// Suppressed under water, where there is no sun to bake anything.
	//
	// Measured down from the ground's own top face where the mesh knows where
	// that is, and from the waterline otherwise — the two agree on flat ground,
	// and only the first is right on a hill.
	float from_top = mix(below, mesh_depth, local_depth);
	float crust_line = crust_depth * (0.55 + 0.9 * value_noise(world_pos * 0.02));
	float crust = (1.0 - smoothstep(0.0, crust_line, from_top)) * shore_mix;
	col = mix(col, crust_color, clamp(crust, 0.0, 1.0));

	// Algae, on the strip world.gd lays along the seabed line. Thinned out as it
	// approaches dry land so the green does not run up onto the beach.
	col = mix(col, algae_color, algae_mix * (1.0 - shore_mix));

	COLOR = vec4(col.rgb, 1.0);
}
