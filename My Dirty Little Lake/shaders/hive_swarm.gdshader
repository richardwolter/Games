// The swarm in the hive room's catch step, drawn as one living cloud (2026-10-18, the hive's
// visual overhaul; tools/hive_look/catch_mockup.py `_lay` and `_ring_outline`).
//
// On the CanvasGroup the clumps' bees are drawn into: every bee is bee A off assets/bees.png,
// each with its own black outline, and a clump of them laid a bee's width apart is a black
// lattice. The mockup's rule, per pixel of the group: one ink outline round the whole cloud's
// silhouette (a pixel with open air beside it), and where a bee's outline falls on another bee
// inside the cloud, the soft brown where two bees touch instead. Read on the art grid: `art_px`
// is how many screen pixels one painted pixel is, so a neighbour is one painted pixel off.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float art_px = 3.0;
uniform vec4 ink : source_color = vec4(0.0941, 0.0706, 0.0667, 1.0);
uniform vec4 soft : source_color = vec4(0.5, 0.3, 0.1, 1.0);

float alpha_at(vec2 uv) {
	return textureLod(screen_texture, uv, 0.0).a;
}

// Whether a pixel is in the cloud: a bee is drawn there, or it is a small hole between bees
// (closed in on all four sides within `HOLE` painted pixels), which the mockup fills with the
// soft brown rather than leaving the sky showing through.
const int HOLE = 3;

bool closed_in(vec2 uv, vec2 step_uv) {
	bool l = false;
	bool r = false;
	bool u = false;
	bool d = false;
	for (int k = 1; k <= HOLE; k++) {
		float f = float(k);
		l = l || alpha_at(uv - vec2(step_uv.x * f, 0.0)) > 0.5;
		r = r || alpha_at(uv + vec2(step_uv.x * f, 0.0)) > 0.5;
		u = u || alpha_at(uv - vec2(0.0, step_uv.y * f)) > 0.5;
		d = d || alpha_at(uv + vec2(0.0, step_uv.y * f)) > 0.5;
	}
	return l && r && u && d;
}

bool inside(vec2 uv, vec2 step_uv) {
	return alpha_at(uv) > 0.5 || closed_in(uv, step_uv);
}

void fragment() {
	vec2 step_uv = SCREEN_PIXEL_SIZE * art_px;
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	bool drawn = c.a > 0.5;
	if (!drawn && !closed_in(SCREEN_UV, step_uv)) {
		discard;
	}
	vec3 rgb = drawn ? c.rgb / c.a : soft.rgb;
	bool edge = !inside(SCREEN_UV + vec2(step_uv.x, 0.0), step_uv)
		|| !inside(SCREEN_UV - vec2(step_uv.x, 0.0), step_uv)
		|| !inside(SCREEN_UV + vec2(0.0, step_uv.y), step_uv)
		|| !inside(SCREEN_UV - vec2(0.0, step_uv.y), step_uv);
	if (edge) {
		rgb = ink.rgb;
	} else if (drawn && distance(rgb, ink.rgb) < 0.05) {
		rgb = soft.rgb;
	}
	COLOR = vec4(rgb, 1.0) * COLOR;
}
