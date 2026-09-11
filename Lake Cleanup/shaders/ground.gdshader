// The ground the lake sits in, drawn per pixel rather than per tile.
//
// One polygon per layer (the mainland ring, the island), and every pixel of it decides for
// itself what it is: which tile of the plane it lies on, whether that spot is lawn or beach,
// which patch of the lawn it belongs to, and which texel of the pack's own top faces it
// therefore shows. The tiles are still the pack's tiles, sampled at their own size on the
// same grid the rubbish uses — but the line between lawn and beach, and the lines between
// patches of the lawn, are curves worked out per pixel and stepped only at art pixels, the
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

// The strip of top faces: one 32-column cell per picture, the sand first and then the
// grass pool. `face_top` is the row of the strip where a cell's diamond has its top
// corner; the rows above it are the turf's overhang past the back edges of the diamond
// (the pack draws its grass bushy, leaning back over the tiles behind), and the rows
// below the diamond are not in the strip at all — the sides of the cubes are gone.
uniform sampler2D sheet : filter_nearest, repeat_disable;
uniform int cell_wide = 32;
uniform int face_top = 3;
uniform int grass_first = 4;
uniform int grass_count = 3;

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

// Patches of the lawn: how wide, in tiles, and how far a patch's middle may wander off the
// lattice as a fraction of that width. See Ground.grass_patch.
uniform float patch_size = 4.0;
uniform float patch_wander : hint_range(0.0, 0.5) = 0.42;

// The blades hanging off the lawn's edge over the beach. `fringe_mode` 0 is none, 1 hangs
// them straight down the screen where the beach is below the lawn, 2 points them along the
// edge's own normal wherever it faces. Depth in art pixels; share is how many columns
// carry a blade at all.
uniform int fringe_mode = 1;
uniform float fringe_depth = 4.0;
uniform float fringe_share : hint_range(0.0, 1.0) = 0.7;
uniform vec4 fringe_dark : source_color = vec4(0.196, 0.341, 0.114, 1.0);
// One art pixel of shadow under the lawn's front edge.
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

// --- patches ------------------------------------------------------------------------------

// Which patch of one picture a spot belongs to: the lattice cell of the nearest of a set of
// scattered points, nearest on the screen rather than in tile space. Mirrors what
// Ground._patch_of used to do per tile, now per pixel.
vec2 patch_of(vec2 p, vec2 t) {
	float size = max(patch_size, 1.0);
	vec2 home = floor(t / size);
	vec2 best = home;
	float best_d = 1e30;
	for (int dx = -1; dx <= 1; dx++) {
		for (int dy = -1; dy <= 1; dy++) {
			vec2 cell = home + vec2(float(dx), float(dy));
			vec2 jitter = vec2(
				cell_hash(cell + vec2(seed * 0.0001)) - 0.5,
				cell_hash(cell.yx + vec2(31.0, -17.0)) - 0.5
			);
			vec2 point = (cell + 0.5 + jitter * 2.0 * patch_wander) * size;
			vec2 d = p - tile_to_world(point);
			float dist = dot(d, d);
			if (dist < best_d) {
				best_d = dist;
				best = cell;
			}
		}
	}
	return best;
}

int variant_at(vec2 p, vec2 t) {
	vec2 patch = patch_of(p, t);
	float roll = cell_hash(patch * 1.7 + vec2(5.0, 11.0));
	return grass_first + int(roll * float(grass_count)) % grass_count;
}

// --- the pictures -------------------------------------------------------------------------

// The texel of picture `cell_index` that lands on screen point `p` when that picture is
// drawn on tile `cell`, or transparent where the picture has no pixel there. The picture's
// diamond is the tile's own diamond; rows above `face_top` are the overhang past its back
// edges.
vec4 texel_of(ivec2 cell, vec2 p, int cell_index) {
	vec2 centre = tile_to_world(vec2(cell) + 0.5);
	vec2 d = p - centre;
	int col = int(floor((d.x + tile_w * 0.5) / art_pixel));
	int row = face_top + int(floor((d.y + tile_h * 0.5) / art_pixel));
	ivec2 size = textureSize(sheet, 0);
	if (col < 0 || col >= cell_wide || row < 0 || row >= size.y) {
		return vec4(0.0);
	}
	return texelFetch(sheet, ivec2(cell_index * cell_wide + col, row), 0);
}

// Where, just inside tile `cell`'s diamond, the ground is that a pixel above the diamond
// hangs over: straight down from the pixel to the diamond's top edge, one art pixel in.
vec2 under_overhang(ivec2 cell, vec2 p) {
	vec2 centre = tile_to_world(vec2(cell) + 0.5);
	float dx = p.x - centre.x;
	float edge_y = centre.y - tile_h * 0.5 + abs(dx) * (tile_h / tile_w);
	return vec2(p.x, edge_y + art_pixel);
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
	int variant = variant_at(p, t);

	// The turf of the tiles in front leaning back over this one. Drawn in the order the
	// tiles used to be painted, nearest last: the tile straight in front, then the two
	// beside it. Each shows only where the ground under its own edge is lawn, so the
	// overhang follows the curve and stops where the lawn does.
	vec4 shown = vec4(0.0);
	if (c0 > -1.5) {
		ivec2 fronts[3] = {cell + ivec2(1, 1), cell + ivec2(1, 0), cell + ivec2(0, 1)};
		for (int i = 0; i < 3; i++) {
			vec4 over = texel_of(fronts[i], p, variant);
			if (over.a < 0.5) {
				continue;
			}
			if (c0 > 1.0 || coverage(under_overhang(fronts[i], p)) > 0.0) {
				shown = over;
				break;
			}
		}
	}

	if (shown.a < 0.5) {
		if (c0 > 0.0) {
			shown = texel_of(cell, p, variant);
			if (shown.a < 0.5) {
				// A hole in the turf. The pack's diamonds are solid, so this is belt and
				// braces: the same column at the widest row of the face.
				vec2 centre = tile_to_world(vec2(cell) + 0.5);
				shown = texel_of(cell, vec2(p.x, centre.y + art_pixel * 0.5), variant);
			}
			if (lip && coverage(p + vec2(0.0, art_pixel)) <= 0.0) {
				shown = lip_color;
			}
		} else {
			int blade = blade_at(p, c0);
			if (blade == 2) {
				shown = fringe_dark;
			} else if (blade == 1) {
				shown = texel_of(cell, p, variant);
			} else {
				shown = texel_of(cell, p, 0);
			}
		}
	}

	if (shown.a < 0.5) {
		discard;
	}
	COLOR = vec4(shown.rgb, 1.0);
}
