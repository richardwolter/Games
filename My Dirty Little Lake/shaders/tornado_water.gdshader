// Look D (a copy of look A's, so later edits to A cannot break it): the water under the spout, under the
// floating rubbish (z 3). From the bottom up: a ring of darker, disturbed water with three
// foam arms spiralling in, the boiling foam skirt with a torn white rim, a hit's torn ring and
// the collapse's rings. The cloud's and the column's shadows are not drawn here: the look
// paints them on the water's shadow layer through `Shade` (2026-10-02, one sun), and this
// shader's own copies, switched off since the port, are gone.
//
// Worked out per art pixel of the world's grid, palette swatches and alpha steps only. Rings
// tear into arcs of uneven length along a warped path, and their ends break into 2x2 clumps.
shader_type canvas_item;
render_mode blend_mix;

uniform float art = 2.0;
uniform vec2 base;
uniform float pat_t = 0.0;
uniform float spin = 0.0;
uniform float skirt_r = 50.0;
uniform float ring_r = 118.0;
uniform float skirt_keep = 1.0;
uniform float ring_keep = 1.0;
uniform float burst_r = 0.0;
uniform float burst_keep = 0.0;
uniform float spread_r = 0.0;
uniform float spread_keep = 0.0;
uniform vec4 deep : source_color;
uniform vec4 chop : source_color;
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

float clump(vec2 cell, vec2 salt) {
	return hash(floor(cell * 0.5) + salt);
}

// `top` laid over `under`.
vec4 over(vec4 top, vec4 under) {
	float a = top.a + under.a * (1.0 - top.a);
	if (a <= 0.0) {
		return vec4(0.0);
	}
	return vec4((top.rgb * top.a + under.rgb * under.a * (1.0 - top.a)) / a, a);
}

// A torn ring of foam at radius `r` (circle units: y doubled), `w` wide. The path wanders
// (two noises over the bearing, the patch's domain-warp idea) and breaks into arcs whose
// lengths come off a noise along it, so the gaps are uneven and grow as `keep` falls.
vec4 torn_ring(vec2 q, float d, float r, float w, float keep, vec2 cell, float salt) {
	if (keep <= 0.0 || r <= 1.0) {
		return vec4(0.0);
	}
	vec2 dir = q / max(d, 0.001);
	float wr = r * (1.0 + 0.2 * (noise(dir * 2.1 + vec2(salt, salt * 0.3)) - 0.5)
		+ 0.08 * (noise(dir * 5.3 + vec2(salt * 1.7, 2.0)) - 0.5));
	float off = abs(d - wr);
	if (off > w) {
		return vec4(0.0);
	}
	float n = noise(dir * max(wr, 8.0) / 26.0 + vec2(salt * 3.1, salt));
	float cut = 1.0 - keep * 0.85;
	if (n < cut) {
		return vec4(0.0);
	}
	// Near an arc's end it goes to clumps of bubbles.
	if (n < cut + 0.05 && clump(cell, vec2(salt, floor(pat_t * 8.0))) < 0.5) {
		return vec4(0.0);
	}
	vec3 col = off < w * 0.45 ? foam_hi.rgb : foam.rgb;
	return vec4(col, keep > 0.45 ? 0.88 : 0.5);
}

void fragment() {
	vec2 cell = floor(wpos / art);
	vec2 p = cell * art + art * 0.5 - base;
	vec2 q = vec2(p.x, p.y * 2.0);
	float d = length(q);
	float ang = atan(q.y, q.x);
	vec2 dir = q / max(d, 0.001);
	vec4 c = vec4(0.0);

	// The disturbed ring: the water a clear step darker, three arms of foam and chop
	// spiralling in, sliding inwards on the stepped clock.
	if (ring_keep > 0.0 && d < ring_r * 1.2) {
		float outer = ring_r * (0.84 + 0.26 * noise(dir * 1.6 + vec2(5.0, pat_t * 0.6)));
		if (d < outer) {
			float band = d / outer;
			float keep = ring_keep;
			vec4 ring = vec4(deep.rgb, band < 0.62 ? 0.62 : 0.4);
			// Counter-clockwise, and the arms slide in towards the foot as they turn
			// (2026-10-05: the lake is drawn up into it; they used to slide out).
			float flow = ang + spin * 0.55 + log(max(d, 4.0)) * 1.25;
			float arms = flow * 3.0 / 6.2831853;
			float line = fract(arms);
			float which = floor(arms);
			float dash = hash(vec2(which, floor(d / 20.0 + pat_t * 2.5)));
			if (band > 0.3 && dash > 0.28) {
				float thick = mix(0.05, 0.1, 1.0 - band);
				if (line < thick) {
					ring = vec4(band < 0.75 ? foam_hi.rgb : foam.rgb, band < 0.8 ? 0.85 : 0.55);
				} else if (line < thick + 0.035) {
					ring = vec4(chop.rgb, 0.7);
				}
			}
			// Torn at its outer edge in clumps, not a clean line.
			if (band > 0.9 && clump(cell, vec2(which, floor(pat_t * 8.0))) < 0.5) {
				ring.a *= 0.5;
			}
			if (keep < 0.6) {
				ring.a *= 0.55;
			}
			if (keep > 0.05) {
				c = over(ring, c);
			}
		}
	}

	// The skirt: a boiling disk of foam, turning, its rim torn into tongues.
	if (skirt_keep > 0.0 && d < skirt_r * 1.2) {
		float ta = ang + spin * 0.9;
		float tongue = noise(vec2(cos(ta), sin(ta)) * 2.4 + vec2(pat_t * 1.1, 0.0));
		float edge = skirt_r * (0.86 + 0.24 * tongue);
		if (d < edge) {
			float rot = spin * 0.8 + d / 16.0;
			vec2 rq = vec2(q.x * cos(rot) - q.y * sin(rot), q.x * sin(rot) + q.y * cos(rot));
			float n = noise(rq / 10.0 + vec2(0.0, pat_t * 1.2)) * 0.8 + noise(rq / 5.0 - vec2(pat_t, 0.0)) * 0.2;
			vec4 sk;
			if (d > edge - 7.0) {
				sk = vec4(clump(cell, vec2(0.0, floor(pat_t * 8.0))) > 0.4 ? foam_hi.rgb : foam.rgb, 0.92);
			} else if (n > 0.44 - 0.3 * (1.0 - d / skirt_r)) {
				sk = vec4(n > 0.6 ? foam_hi.rgb : foam.rgb, 0.9);
			} else {
				sk = vec4(chop.rgb, 0.72);
			}
			if (skirt_keep < 0.5) {
				sk.a *= 0.55;
			}
			c = over(sk, c);
		}
	}

	// A hit's ring racing out, and the collapse's two rings spreading.
	vec4 r1 = torn_ring(q, d, burst_r, 4.0 + burst_keep * 5.0, burst_keep, cell, 23.0);
	if (r1.a <= 0.0) {
		r1 = torn_ring(q, d, spread_r, 4.0 + spread_keep * 6.0, spread_keep, cell, 11.0);
	}
	if (r1.a <= 0.0) {
		r1 = torn_ring(q, d, spread_r * 0.58, 3.0 + spread_keep * 4.0, spread_keep * 0.85, cell, 17.0);
	}
	if (r1.a > 0.0) {
		c = over(r1, c);
	}
	if (c.a <= 0.0) {
		discard;
	}
	COLOR = c;
}
