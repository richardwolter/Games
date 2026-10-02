// The cast net, drawn by rule (2026-10-02; scripts/net_shape.gd says why and how).
//
// The mesh comes in as (rho, theta) in UV. The vertex stage lays each point out on the
// net's shape — `shape` mirrors NetShape.at, change them together — and the fragment stage
// works out, for every pixel of the net's own grid, what is there: a strand of the diamond
// mesh, the rim cord, a lead bead, the crown's knot, the dark pixel under any of them where
// it lies on the water, or nothing.
//
// Pixels are whole pixels of the net's own frame: the fragment is moved to the middle of its
// pixel (through the derivatives of rho and theta) before anything is asked, so every screen
// pixel of one net pixel gets the same answer, and the grid travels with the net as it
// glides rather than crawling across it (the foam collars' rule).
shader_type canvas_item;

uniform float w = 40.0;
uniform float h = 6.4;
uniform vec2 pull = vec2(-1.0, 0.0);
uniform float haul = 0.0;
uniform float load = 0.0;
uniform float sway = 0.0;
uniform float squash = 1.0;
uniform float wobble = 0.0;
uniform float wob_phase = 0.0;

uniform float radial_cells = 3.3;
uniform float n_rim = 32.0;
uniform float max_lvl = 1.0;
uniform float bead_count = 28.0;
uniform float rim_out = 1.15;
uniform float min_gap = 3.5;
// How many px either side of the rim's line the cord runs: 1 is two pixels deep, a lucky
// net's 1.5 three.
uniform float rim_half = 1.0;

uniform vec4 cord : source_color = vec4(0.659, 0.486, 0.298, 1.0);
uniform vec4 cord_lit : source_color = vec4(0.8, 0.635, 0.424, 1.0);
uniform vec4 cord_back : source_color = vec4(0.455, 0.314, 0.18, 1.0);
uniform vec4 shade : source_color = vec4(0.173, 0.114, 0.067, 1.0);
uniform vec4 lead_dark : source_color = vec4(0.118, 0.125, 0.149, 1.0);
uniform vec4 lead_mid : source_color = vec4(0.306, 0.322, 0.361, 1.0);
uniform vec4 lead_lit : source_color = vec4(0.541, 0.565, 0.612, 1.0);

// A lucky cast (NetShape says why): the mesh stays tan, the rim and its beads go gold, the
// gold creeps in from the rim over `fade_cells` cells, a burst of light runs round the rim
// as it lands (`landed`, seconds since, -1 for none) and a glint sweeps the net
// (`glint`, its phase 0 to 1, -1 for none).
uniform float lucky = 0.0;
uniform float landed = -1.0;
uniform float glint = -1.0;
uniform float fade_cells = 1.6;
uniform vec4 gold_deep : source_color = vec4(0.478, 0.298, 0.071, 1.0);
uniform vec4 gold_low : source_color = vec4(0.769, 0.533, 0.133, 1.0);
uniform vec4 gold : source_color = vec4(0.941, 0.745, 0.251, 1.0);
uniform vec4 gold_lit : source_color = vec4(1.0, 0.886, 0.502, 1.0);
uniform vec4 gold_pale : source_color = vec4(1.0, 0.957, 0.769, 1.0);
uniform vec4 gold_shade : source_color = vec4(0.275, 0.157, 0.031, 1.0);

// NetShape's burst and glint numbers, again.
const float BURST_RUN = 0.4;
const float BURST_TAIL = 1.2;
const float BURST_FADE = 0.35;
const float GLINT_WIDE = 0.24;

// NetShape's constants, again.
const float LEAD_OUT = 0.35;
const float RIM_BACK = 0.2;
const float TIP_GAP = 0.1;
const float REAR = 0.85;
const float PURSE_ACROSS = 0.32;
const float PINCH = 0.55;
const float SAG = 0.22;
const float SPREAD = 0.18;
const float SWAY = 0.1;

const int NONE = 0;
const int STRAND = 1;
const int RIM = 2;
const int BEAD = 3;
const int RING = 4;
const int KNOT = 5;

varying vec2 par;
varying vec2 local;
varying float face;
varying float bounds;

vec2 shape(float rho, float theta) {
	float heading = atan(pull.y, pull.x);
	float cf = cos(theta - heading);
	float sf = sin(theta - heading);
	float front = max(cf, 0.0);
	float back = max(-cf, 0.0);
	float wob = 1.0 + wobble * sin(3.0 * theta + wob_phase) + wobble * 0.5 * sin(5.0 * theta - wob_phase);
	float mid = -RIM_BACK * haul;
	float reach_front = (1.0 - haul) + haul * (LEAD_OUT + RIM_BACK + TIP_GAP);
	float reach_back = (1.0 - haul) + haul * REAR;
	float along_r = mid + cf * (cf > 0.0 ? reach_front : reach_back) * wob;
	float across_r = (1.0 - PURSE_ACROSS * haul) * (1.0 - PINCH * haul * pow(front, 1.5))
		* (1.0 + SPREAD * load * back) * sf * wob;
	float crown_a = LEAD_OUT * haul;
	float s = pow(max(rho, 0.0), 1.0 + 0.35 * haul);
	float a = crown_a + (along_r - crown_a) * s;
	float b = across_r * s + SWAY * haul * sway * rho * rho * clamp(-cf * 0.5 + 0.5, 0.0, 1.0);
	vec2 across = vec2(-pull.y, pull.x);
	vec2 plane = (pull * a + across * b) * w;
	float z = h * pow(max(1.0 - rho, 0.0), 1.4);
	z -= SAG * w * load * sin(PI * clamp(rho, 0.0, 1.0)) * (0.35 + 0.65 * back);
	return vec2(plane.x, plane.y * 0.5 * squash - z);
}

void vertex() {
	par = UV;
	bounds = 0.0;
	if (UV.x < -0.5) {
		// The corners that only hold the draw's bounds open: shrunk to nothing.
		bounds = 1.0;
		VERTEX = vec2(0.0);
		local = VERTEX;
		face = 1.0;
	} else {
		VERTEX = shape(UV.x, UV.y);
		local = VERTEX;
		// Near face or far: the sign of the shape's screen Jacobian against a flat net's.
		float e = 0.002;
		float r0 = max(UV.x, e);
		vec2 dr = shape(r0 + e, UV.y) - shape(r0 - e, UV.y);
		vec2 dt = shape(r0, UV.y + e) - shape(r0, UV.y - e);
		face = (dr.x * dt.y - dr.y * dt.x) > 0.0 ? 1.0 : 0.0;
	}
}

// How far, in whole-pixel steps along the nearer axis, a value is from its line: what a
// one-pixel line drawn by stepping one pixel a column (or a row) covers.
float axis(vec2 g) {
	return max(max(abs(g.x), abs(g.y)), 1e-6);
}

int cls(vec2 p, vec2 gr, vec2 gt) {
	float rho = p.x;
	float th = p.y;
	float across = (rho - 1.0) / axis(gr);
	if (abs(across) < 2.5) {
		// The beads ride just outside the rim cord.
		vec2 gb = gt * bead_count / TAU;
		float t = th * bead_count / TAU;
		float along = abs(t - round(t)) / max(length(gb), 1e-6);
		if (along < 1.5 && across > -0.5 && across < 1.5) {
			return BEAD;
		}
		if (along < 2.5 && across > -1.5) {
			return RING;
		}
		if (abs(across) < rim_half) {
			return RIM;
		}
	}
	if (rho > 1.0 || rho < 0.0) {
		return NONE;
	}
	if (rho / axis(gr) < 2.0) {
		return KNOT;
	}
	float lvl = clamp(floor(-log2(max(rho, 1e-4))), 0.0, max_lvl);
	// The tuck ring over each seam where the spokes halve.
	if (lvl > 0.5 && abs(rho - exp2(-lvl)) / axis(gr) < 0.5) {
		return STRAND;
	}
	if (lvl < max_lvl - 0.5 && abs(rho - exp2(-lvl - 1.0)) / axis(gr) < 0.5) {
		return STRAND;
	}
	float k = n_rim / exp2(lvl) / TAU;
	for (int i = 0; i < 2; i++) {
		float sgn = i == 0 ? 1.0 : -1.0;
		float f = th * k + sgn * rho * radial_cells;
		vec2 g = gt * k + sgn * gr * radial_cells;
		// Thinned where the cord bunches: the screen gap to the next strand of this family.
		float gap = 1.0 / max(length(g), 1e-6);
		float every = 1.0;
		if (gap < min_gap) { every = 2.0; }
		if (gap * 2.0 < min_gap) { every = 4.0; }
		if (gap * 4.0 < min_gap) { every = 8.0; }
		float idx = round(f);
		if (mod(idx, every) < 0.5 && abs(f - idx) / axis(g) < 0.5) {
			return STRAND;
		}
	}
	return NONE;
}

// How lit the rim is at bearing `theta`: two heads of light running round from the front
// (theta = PI / 2, the near side) both ways over BURST_RUN seconds, each with a fading tail.
float burst_at(float theta) {
	if (landed < 0.0 || landed >= BURST_RUN + BURST_FADE) {
		return 0.0;
	}
	float run = min(landed / BURST_RUN, 1.0);
	float gone = abs(mod(theta - PI * 0.5 + PI, TAU) - PI);
	float behind = run * PI - gone;
	if (behind < 0.0 || behind >= BURST_TAIL) {
		return 0.0;
	}
	return (1.0 - behind / BURST_TAIL) * (1.0 - max(0.0, (landed - BURST_RUN) / BURST_FADE));
}

// The glint: a band across the net, diagonal on the screen, at its phase.
float glint_at(vec2 p) {
	if (glint < 0.0) {
		return 0.0;
	}
	float d = (p.x * 0.85 + p.y * 0.55) / max(w, 1.0);
	float centre = -1.4 + glint * 2.8;
	return pow(clamp(1.0 - abs(d - centre) / GLINT_WIDE, 0.0, 1.0), 0.7);
}

void fragment() {
	if (bounds > 0.5) {
		discard;
	}
	vec4 tint = COLOR;
	mat2 jp = mat2(dFdx(par), dFdy(par));
	mat2 jl = mat2(dFdx(local), dFdy(local));
	if (abs(determinant(jl)) < 1e-9) {
		discard;
	}
	// d(rho, theta) / d(local): columns are along local x and local y.
	mat2 dpdl = jp * inverse(jl);
	vec2 gr = vec2(dpdl[0].x, dpdl[1].x);
	vec2 gt = vec2(dpdl[0].y, dpdl[1].y);
	vec2 here = par + dpdl * (floor(local) + 0.5 - local);
	vec2 up = here - dpdl[1];
	vec2 down = here + dpdl[1];
	int c = cls(here, gr, gt);
	int above = cls(up, gr, gt);
	vec4 col;
	bool luck = lucky > 0.5;
	float shine = luck ? glint_at(floor(local) + 0.5) : 0.0;
	if (c == STRAND) {
		col = face > 0.5 ? cord : cord_back;
		if (luck) {
			float g = 1.0 - (1.0 - here.x) * radial_cells / fade_cells;
			if (g > 0.0) {
				col = mix(col, face > 0.5 ? gold : gold_low, g * 0.95);
			}
			float flash = here.x > 0.8 ? 0.7 * burst_at(here.y) * (here.x - 0.8) / 0.2 : 0.0;
			float lift = max(flash, shine);
			col = mix(col, gold_pale, min(lift * 1.4, 1.0));
			col = mix(col, vec4(1.0), max(lift - 0.7, 0.0) / 0.3);
		}
	} else if (c == RIM) {
		bool top = !(above == RIM || above == BEAD || above == RING);
		col = top ? cord_lit : cord;
		if (face < 0.5) {
			col = cord_back;
		}
		if (luck) {
			col = face < 0.5 ? gold_low : (top ? gold_lit : gold);
			col = mix(col, vec4(1.0), max(burst_at(here.y), shine));
		}
	} else if (c == KNOT) {
		col = cord_lit;
	} else if (c == BEAD) {
		float flash = luck ? max(burst_at(here.y), shine) : 0.0;
		col = luck ? mix(gold_low, vec4(1.0), flash) : lead_mid;
		if (above == RING) {
			col = luck ? mix(gold_lit, vec4(1.0), flash) : lead_lit;
		} else if (cls(down, gr, gt) == RING) {
			col = luck ? mix(gold_deep, gold_lit, flash) : lead_dark;
		}
	} else if (c == RING) {
		col = luck ? gold_shade : shade;
	} else if (above == STRAND || above == KNOT) {
		col = shade;
	} else if (above == RIM) {
		col = luck ? gold_shade : shade;
	} else {
		discard;
	}
	COLOR = col * tint;
}
