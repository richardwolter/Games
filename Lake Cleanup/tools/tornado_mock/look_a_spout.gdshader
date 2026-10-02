// Look A, "waterspout of foam": the spray column, the mound at its foot and the storm cloud
// it hangs from, on one quad.
//
// Every effect is worked out once per art pixel of the WORLD's grid (2 world px), like the
// lake's water and foam, so edges land on the same pixels as everything else while the base
// glides. Pattern motion (the climbing foam streaks, the tongues of the torn edges, the
// bubbles) ticks on the stepped clock the look hands in; shapes (the rope, the puffs) glide.
//
// No gradients: every colour is one of the uniforms (palette foam and clean-water swatches
// for the spray, the storm ramp for the cloud) and every alpha one of a handful of steps.
// Nothing is torn per pixel: tears and bubbles are clumps of 2x2 art pixels or noise tongues,
// so there are no lone pixels.
shader_type canvas_item;
render_mode blend_mix;

const int N = 48;
const int PUFFS = 64;

uniform float art = 2.0;
uniform vec2 base;
// The column's profile, bottom to top at even heights 0..top_h: (axis x, axis y, radius).
uniform vec3 prof[48];
uniform float top_h = 370.0;
uniform float vis_lo = 0.0;
uniform float vis_hi = 370.0;
uniform float pat_t = 0.0;
uniform float spin = 0.0;
// A hit: the column goes solid white (1) and its waist pinches (0-1) at pinch_h.
uniform float solid = 0.0;
uniform float pinch = 0.0;
uniform float pinch_h = 130.0;
uniform float mound_r = 24.0;
uniform float mound_h = 30.0;

// The cloud: each puff (x, y, radius, depth key) and (tone shift, alpha, squash, seed).
uniform vec4 puff[64];
uniform vec4 puff_b[64];
uniform int puff_n = 0;
uniform vec2 cloud_c = vec2(0.0, -370.0);
uniform float cloud_rx = 70.0;
uniform float cloud_turn = 0.0;
uniform float bolt = 0.0;

uniform vec4 s_edge : source_color;
uniform vec4 s_deep : source_color;
uniform vec4 s_shade : source_color;
uniform vec4 s_body : source_color;
uniform vec4 s_lit : source_color;
uniform vec4 s_hi : source_color;
uniform vec4 k_seam : source_color;
uniform vec4 k_dark : source_color;
uniform vec4 k_mid : source_color;
uniform vec4 k_light : source_color;
uniform vec4 k_rim : source_color;

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

vec3 tone_of(int t) {
	if (t <= 0) return k_seam.rgb;
	if (t == 1) return k_dark.rgb;
	if (t == 2) return k_mid.rgb;
	if (t == 3) return k_light.rgb;
	return k_rim.rgb;
}

// ---------------------------------------------------------------------------------------
// The cloud: a heap of cumulus puffs, each lit from the upper right in four hard steps with a
// dark seam along its lower left, the nearest puff covering the ones behind. The lower the
// puff sits in the mass, the darker; a single groove winds in over the top as the only hint
// of the spiral; lightning lifts a patch of it a step.
// ---------------------------------------------------------------------------------------

// The cloud as one field: the puffs' discs (lumpy, squashed) joined by a smooth minimum, so
// the mass reads as one cloud with billows along its silhouette, not a heap of balls.
// Returns (field, nearest puff, gap to the second nearest, alpha): field < 0 is inside.
vec4 cloud_field(vec2 p) {
	float f = 1e5;
	float d1 = 1e5;
	float d2 = 1e5;
	float near = -1.0;
	float alpha = 0.0;
	for (int i = 0; i < PUFFS; i++) {
		if (i >= puff_n) {
			break;
		}
		vec4 P = puff[i];
		vec4 B = puff_b[i];
		vec2 d = p - P.xy;
		d.y /= B.z;
		float l = length(d);
		if (l > P.z + 40.0) {
			continue;
		}
		vec2 dir = d / max(l, 0.001);
		float re = P.z * (0.9 + 0.16 * noise(dir * 1.7 + vec2(B.w * 37.0, B.w * 11.0 + pat_t * 0.4)));
		float di = l - re;
		// Smooth minimum, 9 px of blend.
		float k = 9.0;
		float h = clamp(0.5 + 0.5 * (f - di) / k, 0.0, 1.0);
		f = mix(f, di, h) - k * h * (1.0 - h);
		if (di < d1) {
			d2 = d1;
			d1 = di;
			near = float(i);
			alpha = B.y;
		} else if (di < d2) {
			d2 = di;
		}
	}
	return vec4(f, near, d2 - d1, alpha);
}

vec4 cloud(vec2 p, vec2 cell) {
	if (puff_n <= 0) {
		return vec4(0.0);
	}
	vec4 F = cloud_field(p);
	if (F.x >= 0.0 || F.y < 0.0) {
		return vec4(0.0);
	}
	vec4 B = puff_b[int(F.y)];
	float depth = -F.x;
	// The surface's slope, from the field's own gradient.
	float fx = cloud_field(p + vec2(art, 0.0)).x - F.x;
	float fy = cloud_field(p + vec2(0.0, art)).x - F.x;
	vec2 n = normalize(vec2(fx, fy) + vec2(0.0001));
	float lit = dot(n, normalize(vec2(0.62, -0.78)));
	// The mass is lit as one: its top in light, its underside in shade.
	float hm = (p.y - cloud_c.y) / (cloud_rx * 0.5);
	int t = hm < -0.9 ? 3 : (hm < -0.05 ? 2 : 1);
	t += int(round(B.x));
	// Near its edge the slope shows: lit to the upper right, shaded to the lower left.
	float rim = 1.0 - clamp(depth / 12.0, 0.0, 1.0);
	if (lit * rim > 0.3) {
		t += 1;
	} else if (lit * rim < -0.3) {
		t -= 1;
	}
	// Its outermost art pixel along the top catches the light.
	if (depth < art * 1.2 && lit > 0.2) {
		t = max(t, 3) + 1;
	}
	// Creases where one billow folds into the next: a dark line down the lower side of the
	// seam between two lobes, never on the silhouette.
	if (F.z < art * 0.9 && depth > art * 2.5 && hm > -1.6) {
		t = min(t - 1, 2);
	}
	// The spiral's hint: one groove winding in over the top of the mass.
	vec2 q = vec2(p.x - cloud_c.x, (p.y - cloud_c.y + 14.0) * 2.0) / cloud_rx;
	float ql = length(q);
	if (ql > 0.14 && ql < 0.95 && hm < 0.2 && t >= 2) {
		float v = fract((atan(q.y, q.x) - cloud_turn) / 6.2831853 + log(ql) * 0.62);
		if (v < 0.05) {
			t -= 1;
		}
	}
	// Lightning, from inside.
	if (bolt > 0.1 && noise(p / 30.0 + vec2(3.0, 1.0)) < bolt * 1.25) {
		t += 1;
	}
	return vec4(tone_of(clamp(t, 0, 4)), F.w);
}

// ---------------------------------------------------------------------------------------
// The spray column
// ---------------------------------------------------------------------------------------

// One helix of foam streaks: its angle round the tube `a`, height `h`. Returns 0 off it, 1 on
// its body, 2 on its breaking tail (bubbles). Each streak has its own twist, width, dash
// length and phase, so they read as spray torn off the water, not a screw thread.
float streak(float a, float h, float k, vec2 cell) {
	float ph = hash(vec2(k, 3.1));
	float tw = mix(0.0022, 0.0052, hash(vec2(k, 5.3)));
	float wid = mix(0.014, 0.034, hash(vec2(k, 7.7)));
	float rate = mix(0.8, 1.25, hash(vec2(k, 9.1)));
	float v = fract((a - spin * rate) / 6.2831853 + h * tw + ph);
	float off = min(v, 1.0 - v);
	if (off > wid) {
		return 0.0;
	}
	// Dashes of uneven length, climbing.
	float len = mix(22.0, 64.0, hash(vec2(k, 11.9)));
	float s = (h - pat_t * 190.0) / len + ph * 5.0;
	float seg = floor(s);
	if (hash(vec2(seg, k + 0.5)) < 0.33) {
		return 0.0;
	}
	float f = fract(s);
	// The dash's upper end breaks into bubbles.
	if (f < 0.28) {
		return clump(cell, vec2(seg, k)) > 0.5 ? 2.0 : 0.0;
	}
	return 1.0;
}

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
	// The touchdown's rope tip: thin where it is coming down.
	if (vis_lo > 0.5) {
		r *= mix(0.15, 1.0, smoothstep(vis_lo, vis_lo + 80.0, h));
	}
	// A hit pinches the waist to under half: a hard notch, an hourglass.
	r *= 1.0 - pinch * 0.66 * exp(-pow((h - pinch_h) / 20.0, 2.0));
	// The torn edge: tongues along the height on the stepped clock, left and right apart.
	float side = p.x < ax ? 0.0 : 7.0;
	float wob = noise(vec2(h / 11.0 - pat_t * 4.0, side + pat_t * 0.5));
	float re = max(r * (0.9 + 0.2 * wob), 2.0);
	float u = (p.x - ax) / re;
	float au = abs(u);
	float edge_px = (1.0 - au) * re;

	// Where it is coming apart: the top of what is left while it unravels, the tip while it
	// comes down. Torn in tongues (noise over the angle), never pixel by pixel.
	float frayed = 0.0;
	if (h > vis_hi - 26.0) {
		frayed = (h - (vis_hi - 26.0)) / 26.0;
	}
	if (vis_lo > 0.5 && h < vis_lo + 14.0) {
		frayed = max(frayed, (vis_lo + 14.0 - h) / 14.0 * 0.8);
	}

	if (au > 1.0) {
		// A few loose clumps of spray flying off the edge.
		float out_by = (au - 1.0) * re;
		vec2 rise = vec2(0.0, pat_t * 12.0);
		if (out_by < 7.0 && clump(cell + rise, vec2(side, 2.0)) > 0.9 && frayed < 0.5 && solid < 0.5) {
			return vec4(u > 0.0 ? s_hi.rgb : s_lit.rgb, 0.72);
		}
		return vec4(0.0);
	}
	if (frayed > 0.0) {
		float tear = noise(vec2(u * 3.0 + spin * 0.5, h / 7.0));
		if (tear < frayed) {
			return tear > frayed - 0.12 ? vec4(s_lit.rgb, 0.5) : vec4(0.0);
		}
	}

	// A hit: two stepped frames of solid white, hard edged, the notch showing.
	if (solid > 0.5) {
		if (u < 0.0 && edge_px < art) {
			return vec4(s_shade.rgb, 1.0);
		}
		if (u < 0.0 && edge_px < art * 3.0) {
			return vec4(s_lit.rgb, 1.0);
		}
		return vec4(s_hi.rgb, 1.0);
	}

	// Spray: see-through pale water, a lit right edge, a shaded left edge with one art pixel
	// of dark line holding the silhouette on any water.
	vec3 col = s_body.rgb;
	float a = 0.44;
	if (u < 0.0 && edge_px < art) {
		return vec4(s_edge.rgb, 0.85);
	}
	if (u < 0.0 && edge_px < art * 3.0) {
		col = s_shade.rgb;
		a = 0.62;
	}
	if (u > 0.0 && edge_px < art * 2.0) {
		col = s_hi.rgb;
		a = 0.9;
	}

	float a_front = acos(clamp(u, -1.0, 1.0));
	// The back streaks, seen faintly through the sheath.
	for (int k = 0; k < 4; k++) {
		float on = streak(-a_front, h, float(k) + 20.0, cell);
		if (on > 0.0 && au < 0.85) {
			col = s_lit.rgb;
			a = on > 1.5 ? 0.45 : 0.5;
		}
	}
	// Bubbles rising through it.
	if (au < 0.85 && clump(cell + vec2(0.0, pat_t * 16.0), vec2(3.0, 0.0)) > 0.975) {
		col = s_hi.rgb;
		a = 0.8;
	}
	// The front streaks: foam climbing round the front, brighter on the lit side.
	for (int k = 0; k < 6; k++) {
		float on = streak(a_front, h, float(k), cell);
		if (on > 0.0) {
			col = u < -0.55 ? s_lit.rgb : s_hi.rgb;
			a = on > 1.5 ? 0.72 : 0.95;
		}
	}
	return vec4(col, a);
}

// ---------------------------------------------------------------------------------------
// The spray mound: a dome of white water boiling up round the foot, its crest torn into
// tongues on the stepped clock, lit from the right.
// ---------------------------------------------------------------------------------------

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
		// The near half of its foot on the water.
		if (pow(u, 2.0) + pow(hgt / (mound_r * 0.5), 2.0) > 1.0) {
			return vec4(0.0);
		}
	} else if (hgt > top || abs(u) > 1.0) {
		// A few clumps spat off the crest.
		if (hgt < top + 10.0 && abs(u) < 1.0 && clump(cell + vec2(0.0, pat_t * 12.0), vec2(9.0, 1.0)) > 0.86) {
			return vec4(s_hi.rgb, 0.72);
		}
		return vec4(0.0);
	}
	vec3 col = s_lit.rgb;
	float a = 0.95;
	if (u > 0.25) {
		col = s_hi.rgb;
	}
	if (u < -0.5) {
		col = s_shade.rgb;
	}
	// Its crest is the brightest foam.
	if (hgt > top - art * 2.0 && hgt > 0.0) {
		col = s_hi.rgb;
	}
	// Churning: clumps of the body open onto the spray behind, a step darker.
	float g = clump(cell + vec2(spin * 3.0, pat_t * 8.0), vec2(5.0, 5.0));
	if (g < 0.16 && hgt < top - art * 2.0) {
		col = u > 0.2 ? s_lit.rgb : s_body.rgb;
		a = 0.62;
	}
	if (u < 0.0 && (1.0 - abs(u)) * mound_r < art && hgt > 0.0) {
		col = s_shade.rgb;
		a = 1.0;
	}
	return vec4(col, a);
}

void fragment() {
	vec2 cell = floor(wpos / art);
	vec2 p = cell * art + art * 0.5 - base;
	vec4 c = cloud(p, cell);
	if (c.a <= 0.0) {
		c = mound(p, cell);
	}
	if (c.a <= 0.0) {
		c = column(p, cell);
	}
	if (c.a <= 0.0) {
		discard;
	}
	COLOR = c;
}
