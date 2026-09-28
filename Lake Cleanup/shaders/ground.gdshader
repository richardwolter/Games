// The ground the lake sits in, drawn per pixel rather than per tile.
//
// One polygon per layer (the mainland ring, the island), and every pixel of it decides for
// itself what it is: which tile of the plane it lies on, whether that spot is lawn or beach,
// and which texel of the pack's own top faces it
// therefore shows. The tiles are still the pack's tiles, sampled at their own size on the
// same grid the rubbish uses — but the line between lawn and beach is a curve worked out per pixel and stepped only at art pixels, the
// same way water.gdshader cuts the island's coast. A line drawn by choosing whole tiles is a
// staircase of diamonds whatever tiles are chosen; that is what this replaces (issue #17).
//
// Everything is evaluated on the art-pixel grid (`art_pixel`, two world pixels), so every
// edge lands on the pack's own pixel size and stays there under the snapped camera.
//
// The shape functions mirror scripts/iso.gd and Ground.out_of_water. The wander noise and
// the coverage rule mirror Ground.coverage_at, which the props (trees, the beach tufts) are
// laid by: one edge, two languages, and they must move together.
shader_type canvas_item;
render_mode blend_mix;

#include "pixel.gdshaderinc"

// The sand slab's top face, one 32-column cell, its diamond's top corner on row `face_top`.
// The lawn is not sampled from the pack any more; see `blade_grass`.
uniform sampler2D sheet : filter_nearest, repeat_disable;
uniform int cell_wide = 32;
uniform int face_top = 3;

// 0 for the mainland ring, 1 for the island.
uniform int layer = 0;

uniform float tile_w = 64.0;
uniform float tile_h = 32.0;
uniform float art_pixel = 2.0;
uniform vec2 basin_centre = vec2(46.0, 46.0);
uniform vec2 basin_radius = vec2(40.0, 34.0);
uniform vec2 island_centre = vec2(46.0, 46.0);
uniform vec2 island_radius = vec2(8.0, 6.8);
// Iso.WATER_LAP_TILES: how far the drawn water is carried past the waterline.
uniform float water_lap = 0.45;
// Ground.OUTER_OUT, ISLAND_UNDER, BEACH_IN.
uniform float outer_out = 42.1;
uniform float island_under = 1.0;
uniform float beach_in = 2.6;

// Where the mainland's lawn starts, in tiles out of the water, and how the line wanders:
// how far off the ellipse it strays (tiles), how wide its bays are (world pixels), and how
// much of the stray is the finer second octave of bites out of those bays.
uniform float beach_width = 5.0;
uniform float wander_amp = 0.7;
uniform float wander_scale = 260.0;
uniform float wander_fine : hint_range(0.0, 1.0) = 0.3;
uniform float seed = 20260907.0;

// The lawn is drawn, not sampled (2026-09-28, Richard: the pack's tiles showed their seams
// and repeated one blotchy pattern a tile): a ground of the layer's mid green, a little
// low-green speckle, and thin blades one art pixel wide, two or three tall, in the low green
// with a lit tip, one in `blade_lean` of them leaning a pixel at the top. The three greens
// are steps of the layer's pack grass's own ramp (Ground.lawn_shades). `tone_levels` lays soft blotches
// over it: 0 flat, 2 one darker shade, 3 a darker and a lighter one at two scales.
uniform vec4 lawn_low : source_color = vec4(0.15, 0.28, 0.12, 1.0);
uniform vec4 lawn_mid : source_color = vec4(0.2, 0.34, 0.14, 1.0);
uniform vec4 lawn_light : source_color = vec4(0.3, 0.45, 0.2, 1.0);
uniform float blade_share = 0.06;
uniform float blade_lean = 0.2;
uniform float speckle = 0.08;
uniform int tone_levels = 0;
uniform float tone_scale = 220.0;
uniform float tone_step = 0.08;

// The blades hanging off the lawn's edge over the beach. `fringe_mode` 0 is none, 1 hangs
// them straight down the screen where the beach is below the lawn, 2 points them along the
// edge's own normal wherever it faces. Depth in art pixels; share is how many columns
// carry a blade at all.
uniform int fringe_mode = 1;
uniform float fringe_depth = 4.0;
uniform float fringe_share : hint_range(0.0, 1.0) = 0.7;
uniform vec4 fringe_dark : source_color = vec4(0.196, 0.341, 0.114, 1.0);
// One art pixel of shadow under the lawn's front edge.
// How wet the sand is, 0 dry to 1 soaked, pushed by Puddles while it rains (2026-09-25).
// Darkens the sand only; the lawn is left alone.
uniform float wet_sand : hint_range(0.0, 1.0) = 0.0;
uniform vec3 wet_ink = vec3(0.68, 0.7, 0.76);

uniform bool lip = true;
uniform vec4 lip_color : source_color = vec4(0.118, 0.275, 0.082, 1.0);

varying vec2 world_pos;

// --- the plane ---------------------------------------------------------------------------

vec2 tile_to_world(vec2 t) {
	return vec2((t.x - t.y) * tile_w * 0.5, (t.x + t.y) * tile_h * 0.5);
}

vec2 world_to_tile(vec2 p) {
	float a = p.x / (tile_w * 0.5);
	float b = p.y / (tile_h * 0.5);
	return vec2((b + a) * 0.5, (b - a) * 0.5);
}

// Mirrors Iso.shore_fraction (the waterline itself, no lap).
float shore_fraction(vec2 t) {
	vec2 d = (t - basin_centre) / basin_radius;
	float r = length(d);
	if (r < 0.0001) {
		return 0.0;
	}
	float angle = atan(d.y, d.x);
	float wobble = 1.0 + 0.09 * sin(angle * 3.0) + 0.05 * sin(angle * 5.0 + 1.3);
	return r / wobble;
}

// Mirrors Iso.island_fraction with the radii shrunk by `shrink`: Iso.island_ring_fraction.
float island_ring_fraction(vec2 t, float shrink) {
	vec2 r = island_radius - vec2(shrink);
	vec2 d = (t - island_centre) / r;
	float len = length(d);
	if (len < 0.0001) {
		return 0.0;
	}
	float angle = atan(d.y, d.x);
	float wobble = 1.0 + 0.07 * sin(angle * 3.0 + 0.7) + 0.035 * sin(angle * 5.0 - 0.4)
		+ 0.02 * sin(angle * 7.0 + 2.1);
	return len / wobble;
}

// Mirrors Ground.out_of_water: tiles out of the water, negative inside it.
float out_of_water(vec2 t) {
	vec2 d = (t - basin_centre) / basin_radius;
	float reach = length(d * basin_radius);
	float s = shore_fraction(t);
	if (s <= 0.0001) {
		return -reach;
	}
	return reach * (s - 1.0) / s;
}

// Mirrors Iso.past_shelf: tiles past the water's drawn edge round the island.
float past_shelf(vec2 t) {
	float mean = (island_radius.x + island_radius.y) * 0.5 - water_lap;
	return (island_ring_fraction(t, water_lap) - 1.0) * mean;
}

// --- lawn or beach ------------------------------------------------------------------------

// How far the lawn's line strays off its ellipse at a spot, in tiles. Two octaves of value
// noise on the screen rather than on the tile grid, so a bay is round on the screen; the
// coarse one is the bays, the fine one the bites out of them. Mirrors Ground.wander_at.
float wander(vec2 p) {
	vec2 off = vec2(seed * 0.001, seed * 0.0007);
	float coarse = blob_noise(p / max(wander_scale, 1.0) + off) - 0.5;
	float fine = blob_noise(p / max(wander_scale * 0.31, 1.0) + off * 1.7 + vec2(13.0, 7.0)) - 0.5;
	return wander_amp * 2.0 * mix(coarse, fine, wander_fine);
}

// Tiles past the lawn's line: positive on the lawn, negative on the beach. Mirrors
// Ground.coverage_at. The island's yard has a decided edge, so it does not wander.
float coverage(vec2 p) {
	vec2 t = world_to_tile(p);
	if (layer == 1) {
		float mean = (island_radius.x + island_radius.y) * 0.5;
		return (1.0 - island_ring_fraction(t, 0.0)) * mean - beach_in;
	}
	return out_of_water(t) - beach_width - wander(p);
}

// --- the sand -----------------------------------------------------------------------------

// The sand slab's texel at `p` on tile `cell`, or transparent outside its diamond.
vec4 sand_at(ivec2 cell, vec2 p) {
	vec2 centre = tile_to_world(vec2(cell) + 0.5);
	vec2 d = p - centre;
	int col = int(floor((d.x + tile_w * 0.5) / art_pixel));
	int row = face_top + int(floor((d.y + tile_h * 0.5) / art_pixel));
	ivec2 size = textureSize(sheet, 0);
	if (col < 0 || col >= cell_wide || row < 0 || row >= size.y) {
		return vec4(0.0);
	}
	return texelFetch(sheet, ivec2(col, row), 0);
}

// The blades: how far below the lawn's edge this beach pixel is, in art pixels, and how
// long the blade in its column is. Returns 0 for no blade, 1 for a blade, 2 for its tip.
int blade_at(vec2 p, float c0) {
	if (fringe_mode == 0 || fringe_depth < 0.5) {
		return 0;
	}
	float dist;
	vec2 anchor;
	if (fringe_mode == 1) {
		// Straight down: is there lawn above this pixel, and how far? The edge is a smooth
		// curve, so its distance is read off the slope over one art pixel rather than
		// searched for.
		float up = coverage(p - vec2(0.0, art_pixel));
		float slope = up - c0;
		if (slope <= 0.0001) {
			return 0;
		}
		dist = -c0 / slope;
		anchor = vec2(floor(p.x / art_pixel), seed * 0.01);
	} else {
		vec2 g = vec2(
			coverage(p + vec2(art_pixel, 0.0)) - c0,
			coverage(p + vec2(0.0, art_pixel)) - c0
		);
		float len = length(g);
		if (len <= 0.0001) {
			return 0;
		}
		dist = -c0 / len;
		// The blade belongs to the point on the edge it hangs from, so its length is rolled
		// off that point, quantised to art pixels.
		vec2 foot = p + g / len * dist * art_pixel;
		anchor = floor(foot / (art_pixel * 2.0)) + vec2(seed * 0.01);
	}
	if (dist < 0.0) {
		return 0;
	}
	float share = cell_hash(anchor + vec2(3.0, 9.0));
	if (share > fringe_share) {
		return 0;
	}
	float h = 1.0 + floor(cell_hash(anchor) * fringe_depth);
	float k = ceil(dist - 0.001);
	if (k < 1.0) {
		k = 1.0;
	}
	if (k > h) {
		return 0;
	}
	return k >= h ? 2 : 1;
}

// The blotch a lawn pixel is in, as a brightness factor.
float tone_at(vec2 p) {
	if (tone_levels < 2) {
		return 1.0;
	}
	vec2 off = vec2(seed * 0.0003, seed * 0.0005);
	float n = blob_noise(p / max(tone_scale, 1.0) + off);
	if (tone_levels == 2) {
		return n < 0.4 ? 1.0 - tone_step : 1.0;
	}
	float f = blob_noise(p / max(tone_scale * 0.45, 1.0) + off * 1.3 + vec2(7.0, 3.0));
	float m = mix(n, f, 0.35);
	if (m < 0.38) {
		return 1.0 - tone_step;
	}
	if (m > 0.62) {
		return 1.0 + tone_step;
	}
	return 1.0;
}

// The drawn lawn at `p`. A blade is rooted at its bottom pixel; walking the three rows
// below looks for one reaching up to here, its top pixel shifted by its lean.
vec3 blade_grass(vec2 p) {
	vec2 q = floor(p / art_pixel);
	vec3 col = cell_hash(q * 1.31 + vec2(2.0, 9.0)) < speckle ? lawn_low.rgb : lawn_mid.rgb;
	for (int k = 0; k < 3; k++) {
		for (int s = -1; s <= 1; s++) {
			float shift = k >= 2 ? float(s) : 0.0;
			if (k < 2 && s != 0) {
				continue;
			}
			vec2 root = vec2(q.x - shift, q.y + float(k));
			if (cell_hash(root + vec2(seed * 0.0001, 17.0)) > blade_share) {
				continue;
			}
			float lean_roll = cell_hash(root + vec2(11.0, 4.0));
			float lean = lean_roll < blade_lean ? (cell_hash(root.yx + vec2(3.0, 8.0)) < 0.5 ? -1.0 : 1.0) : 0.0;
			if (lean != shift) {
				continue;
			}
			float tall = 2.0 + floor(cell_hash(root + vec2(5.0, 23.0)) * 2.0);
			if (float(k) < tall) {
				return float(k) == tall - 1.0 ? lawn_light.rgb : lawn_low.rgb;
			}
		}
	}
	return col;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 p = (floor(world_pos / art_pixel) + 0.5) * art_pixel;
	vec2 t = world_to_tile(p);

	// What this layer covers at all. Mirrors Ground.kind_at's NONE and WATER.
	if (layer == 1) {
		if (past_shelf(t) > island_under) {
			discard;
		}
	} else {
		if (island_ring_fraction(t, 0.0) < 1.0) {
			discard;
		}
		float out_w = out_of_water(t);
		if (out_w < -1.0 - water_lap || out_w > outer_out) {
			discard;
		}
	}

	ivec2 cell = ivec2(floor(t));
	float c0 = coverage(p);
	vec3 shown;
	if (c0 > 0.0) {
		shown = blade_grass(p) * tone_at(p);
		if (lip && coverage(p + vec2(0.0, art_pixel)) <= 0.0) {
			shown = lip_color.rgb;
		}
	} else {
		int blade = blade_at(p, c0);
		if (blade == 2) {
			shown = fringe_dark.rgb;
		} else if (blade == 1) {
			shown = lawn_low.rgb * tone_at(p);
		} else {
			vec4 sand = sand_at(cell, p);
			if (sand.a < 0.5) {
				discard;
			}
			shown = sand.rgb * mix(vec3(1.0), wet_ink, wet_sand);
		}
	}
	COLOR = vec4(shown, 1.0);
}
