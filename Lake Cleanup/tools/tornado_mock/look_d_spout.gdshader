// Look D: the spout column (look A's, retoned into the storm) and the foam mound at its foot,
// on one quad. The cloud and its eye are drawn by look_d.gd, over this, at z 23.
//
// Worked out once per art pixel of the WORLD's grid (2 world px), so edges land on the same
// pixels as the lake while the base glides. Pattern motion (the climbing streaks, the torn
// edges, the bubbles, the helix the tone steps follow) ticks on the stepped clock the look
// hands in; the rope's shape glides.
//
// No gradients: every colour is one of the ramp's seven real swatches (0 lightest .. 6 the
// throat) or the foam's two, every alpha one of a few steps. The column shades from spray at
// the water up into the cloud's greys in hard steps, and the step lines wind round the rope on
// the helix, so they turn with it instead of lying as flat rings.
shader_type canvas_item;
render_mode blend_mix;

const int N = 48;

uniform float art = 2.0;
uniform vec2 base;
// The column's profile, bottom to top at even heights 0..top_h: (axis x, axis y, radius).
uniform vec3 prof[48];
uniform float top_h = 300.0;
uniform float vis_lo = 0.0;
uniform float vis_hi = 300.0;
uniform float pat_t = 0.0;
uniform float spin = 0.0;
// Steps lighter: a hit (2 then 1) or a lightning flash (1).
uniform float lift = 0.0;
uniform float pinch = 0.0;
uniform float pinch_h = 110.0;
uniform float mound_r = 24.0;
uniform float mound_h = 30.0;
// The column is drawn twice: once under the cloud (`over` 0, the cells below `split_y`) and
// once over it (`over` 1, the cells at or above it), so the rope runs up the cloud's front
// face into the eye's throat. Every cell falls in exactly one of the two, so there is no seam.
uniform float split_y = -100000.0;
uniform float over = 0.0;
// Zoomed out, the rope's lit and shaded edges are this many times as thick.
uniform float bold = 1.0;

uniform vec4 r0 : source_color;
uniform vec4 r1 : source_color;
uniform vec4 r2 : source_color;
uniform vec4 r3 : source_color;
uniform vec4 r4 : source_color;
uniform vec4 r5 : source_color;
uniform vec4 r6 : source_color;
uniform vec4 foam : source_color;
uniform vec4 foam_hi : source_color;

varying vec2 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(vec2 c) {
	vec2 p = fract(c * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// A clump of 2x2 art pixels' roll: tears and bubbles use this, never a single pixel's.
float clump(vec2 cell, vec2 salt) {
	return hash(floor(cell * 0.5) + salt);
}

vec3 ramp(int t) {
	if (t <= 0) return r0.rgb;
	if (t == 1) return r1.rgb;
	if (t == 2) return r2.rgb;
	if (t == 3) return r3.rgb;
	if (t == 4) return r4.rgb;
	if (t == 5) return r5.rgb;
	return r6.rgb;
}

// One helix of streaks: its angle round the tube `a`, height `h`. Returns 0 off it, 1 on its
// body, 2 on its breaking tail (bubbles). Each streak has its own twist, width, dash length and
// phase, so they read as spray torn off the water, not a screw thread.
float streak(float a, float h, float k, vec2 cell) {
	float ph = hash(vec2(k, 3.1));
	float tw = mix(0.0022, 0.0052, hash(vec2(k, 5.3)));
	float wid = mix(0.045, 0.075, hash(vec2(k, 7.7)));
	float rate = mix(0.8, 1.25, hash(vec2(k, 9.1)));
	float v = fract((a - spin * rate) / 6.2831853 + h * tw + ph);
	float off = min(v, 1.0 - v);
	if (off > wid) {
		return 0.0;
	}
	float len = mix(22.0, 64.0, hash(vec2(k, 11.9)));
	float s = (h - pat_t * 190.0) / len + ph * 5.0;
	float seg = floor(s);
	if (hash(vec2(seg, k + 0.5)) < 0.33) {
		return 0.0;
	}
	float f = fract(s);
	if (f < 0.28) {
		return clump(cell, vec2(seg, k)) > 0.5 ? 2.0 : 0.0;
	}
	return 1.0;
}

// The tone step at height h and angle a round the front: hard bands up the height, the same
// across the whole width (no pale core in a dark sleeve), their lines wound on the helix.
// Spray-pale at the water, the clean water's shallow blue, then the cloud's three greys, then
// the eye's wall and throat at the very top, where the rope goes up into the hole.
int band_at(float h, float a) {
	float g = h / max(top_h, 1.0);
	float hel = fract((a - spin * 0.9) / 6.2831853 * 3.0 + h * 0.0045);
	float gg = g + (hel - 0.5) * 0.035;
	if (gg < 0.1) return 0;
	if (gg < 0.23) return 1;
	if (gg < 0.46) return 2;
	if (gg < 0.7) return 3;
	if (gg < 0.9) return 4;
	// Into the throat's swatch on a torn line (clumps of two art pixels, turning with the
	// rope), so the rope has no flat top where it meets the hole.
	float torn = hash(floor(vec2(a * 4.0 - spin * 2.0, h / (art * 2.0)))) - 0.5;
	if (gg + torn * 0.07 < 0.945) return 5;
	return 6;
}

// Two alpha steps only: whole (the body and its edges) and the remnant (loose clumps, fray,
// a streak's breaking tail).
const float WHOLE = 1.0;
const float REMNANT = 0.5;

vec4 column(vec2 p, vec2 cell) {
	if (vis_hi <= vis_lo + 1.0) {
		return vec4(0.0);
	}
	float h = -1.0;
	float ax = 0.0;
	float r = 0.0;
	if (p.y > prof[0].y) {
		if (p.y > prof[0].y + art) {
			return vec4(0.0);
		}
		h = 0.0;
		ax = prof[0].x;
		r = prof[0].z;
	} else {
		for (int i = 0; i < N - 1; i++) {
			float y0 = prof[i].y;
			float y1 = prof[i + 1].y;
			if (p.y <= y0 && p.y >= y1) {
				float t = (y0 - p.y) / max(y0 - y1, 0.001);
				h = mix(float(i), float(i + 1), t) / float(N - 1) * top_h;
				ax = mix(prof[i].x, prof[i + 1].x, t);
				r = mix(prof[i].z, prof[i + 1].z, t);
				break;
			}
		}
	}
	if (h < 0.0 || h < vis_lo - 1.0 || h > vis_hi + 1.0) {
		return vec4(0.0);
	}
	// The top end is torn into the throat, so the rope has no ruler-straight end in the eye.
	if (h > top_h - 14.0) {
		float up_by = (h - (top_h - 14.0)) / 14.0;
		if (clump(cell + vec2(spin * 2.0, 0.0), vec2(13.0, 3.0)) < up_by * 0.9) {
			return vec4(0.0);
		}
	}
	// The tip (coming down out of the eye, or drawn back up into it) tapers to a rope.
	if (vis_lo > 0.5) {
		r *= mix(0.15, 1.0, smoothstep(vis_lo, vis_lo + 70.0, h));
	}
	// A hit pinches the waist: a hard notch, an hourglass.
	r *= 1.0 - pinch * 0.62 * exp(-pow((h - pinch_h) / 20.0, 2.0));
	float side = p.x < ax ? 0.0 : 7.0;
	float wob = noise(vec2(h / 11.0 - pat_t * 4.0, side + pat_t * 0.5));
	float re = max(r * (0.9 + 0.2 * wob), 2.0);
	float u = (p.x - ax) / re;
	float au = abs(u);
	float edge_px = (1.0 - au) * re;
	int dl = int(lift + 0.5);

	float frayed = 0.0;
	if (vis_lo > 0.5 && h < vis_lo + 16.0) {
		frayed = (vis_lo + 16.0 - h) / 16.0 * 0.85;
	}
	float a_front = acos(clamp(u, -1.0, 1.0));
	int t0 = band_at(h, a_front);

	if (au > 1.0) {
		// Loose clumps flying off the edge, a step lighter than the rope there.
		float out_by = (au - 1.0) * re;
		vec2 rise = vec2(0.0, pat_t * 12.0);
		if (out_by < 6.0 && t0 <= 4 && clump(cell + rise, vec2(side, 2.0)) > 0.92 && frayed < 0.5) {
			int tc = max(t0 - 1 - dl, 0);
			return vec4(t0 <= 1 ? foam.rgb : ramp(tc), REMNANT);
		}
		return vec4(0.0);
	}
	if (frayed > 0.0) {
		float tear = noise(vec2(u * 3.0 + spin * 0.5, h / 7.0));
		if (tear < frayed) {
			return tear > frayed - 0.12 ? vec4(ramp(max(t0 - 1, 0)), REMNANT) : vec4(0.0);
		}
	}

	int t = t0;
	float a = WHOLE;
	int deepest = t0 >= 5 ? 6 : 5;
	// The shaded left: one art pixel a step darker holding the silhouette on any water; the lit
	// right: a step lighter, two pixels deep, the outer one two steps.
	if (u < 0.0 && edge_px < art * bold) {
		return vec4(ramp(clamp(t0 + 1 - dl, 0, deepest)), WHOLE);
	}
	if (u > 0.0 && edge_px < art * 2.0 * bold && t0 < 6) {
		t = t0 - (edge_px < art * bold ? 2 : 1);
	}
	// The back streaks, a step lighter, seen between the front ones.
	for (int k = 0; k < 4; k++) {
		float on = streak(-a_front, h, float(k) + 20.0, cell);
		if (on > 0.0 && au < 0.8) {
			t = t0 - 1;
			a = on > 1.5 ? REMNANT : WHOLE;
		}
	}
	// Bubbles rising through it.
	if (au < 0.85 && clump(cell + vec2(0.0, pat_t * 16.0), vec2(3.0, 0.0)) > 0.975) {
		t = t0 - 2;
	}
	// The front streaks (A's): climbing round the front, two steps lighter across the whole
	// face, spray-white where the rope is still water.
	bool foamy = false;
	if (t0 < 6) {
		for (int k = 0; k < 6; k++) {
			float on = streak(a_front, h, float(k), cell);
			if (on > 0.0) {
				// Up in the greys three steps, so the bands still read on the darkest body.
				t = t0 >= 3 ? t0 - 3 : t0 - 2;
				a = on > 1.5 ? REMNANT : WHOLE;
				foamy = t0 <= 1;
			}
		}
	}
	t = clamp(t - dl, 0, 6);
	if (foamy) {
		return vec4(u < -0.55 ? foam.rgb : foam_hi.rgb, a);
	}
	return vec4(ramp(t), a);
}

// The spray mound: a dome of white water boiling up round the foot, its crest torn into
// tongues on the stepped clock, lit from the right.
vec4 mound(vec2 p, vec2 cell) {
	if (mound_r < 2.0 || mound_h < 2.0) {
		return vec4(0.0);
	}
	float hgt = -p.y;
	float x = p.x - prof[0].x;
	if (hgt > mound_h * 1.4 || hgt < -mound_r * 0.6 || abs(x) > mound_r * 1.3) {
		return vec4(0.0);
	}
	float k = clamp(x / mound_r, -1.0, 1.0);
	float tongue = noise(vec2(x / 6.0 + spin * 1.2, pat_t * 3.0));
	float top = mound_h * sqrt(max(1.0 - k * k, 0.0)) * (0.72 + 0.5 * tongue);
	float u = x / mound_r;
	if (hgt < 0.0) {
		if (pow(u, 2.0) + pow(hgt / (mound_r * 0.5), 2.0) > 1.0) {
			return vec4(0.0);
		}
	} else if (hgt > top || abs(u) > 1.0) {
		if (hgt < top + 10.0 && abs(u) < 1.0 && clump(cell + vec2(0.0, pat_t * 12.0), vec2(9.0, 1.0)) > 0.86) {
			return vec4(foam_hi.rgb, REMNANT);
		}
		return vec4(0.0);
	}
	vec3 col = foam.rgb;
	float a = WHOLE;
	if (u > 0.25) {
		col = foam_hi.rgb;
	}
	if (u < -0.5) {
		col = r1.rgb;
	}
	if (hgt > top - art * 2.0 && hgt > 0.0) {
		col = foam_hi.rgb;
	}
	float g = clump(cell + vec2(spin * 3.0, pat_t * 8.0), vec2(5.0, 5.0));
	if (g < 0.16 && hgt < top - art * 2.0) {
		col = u > 0.2 ? foam.rgb : r0.rgb;
		a = REMNANT;
	}
	if (u < 0.0 && (1.0 - abs(u)) * mound_r < art && hgt > 0.0) {
		col = r2.rgb;
		a = 1.0;
	}
	return vec4(col, a);
}

void fragment() {
	vec2 cell = floor(wpos / art);
	float cy = cell.y * art + art * 0.5;
	if ((over < 0.5) == (cy < split_y)) {
		discard;
	}
	vec2 p = cell * art + art * 0.5 - base;
	vec4 c = over < 0.5 ? mound(p, cell) : vec4(0.0);
	if (c.a <= 0.0) {
		c = column(p, cell);
	}
	if (c.a <= 0.0) {
		discard;
	}
	COLOR = c;
}
