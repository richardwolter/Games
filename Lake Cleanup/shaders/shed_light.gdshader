// The light in the shed: the sun coming in through the round window in the left wall, and
// the pools a fire or an open fridge throws on the boards. One additive quad over the room.
//
// **Smooth, but worked out once per art pixel of the room** (Richard, 2026-09-20): the three
// stacked circles this replaces read as rings, "blocky and ugly", and a gradient per screen
// pixel reads as an HD effect laid over pixel art. Every fragment is moved to the middle of
// the room's art pixel it is in before anything is measured, so the falloff is continuous
// and still sits on the furniture's own grid. No steps, no dither.
shader_type canvas_item;
render_mode blend_add, unshaded;

// The quad's size in canvas pixels, and how many of those one painted pixel of the room is.
uniform vec2 box_px = vec2(672.0, 512.0);
uniform float art_px = 2.0;

// The window: where it is on the quad, which way the light travels from it, how strong.
uniform vec2 window_at = vec2(0.0, 40.0);
uniform vec2 sun_dir = vec2(0.85, 0.52);
uniform float sun_power = 0.5;
uniform vec3 sun_tone : source_color = vec3(1.0, 0.82, 0.52);
// The shaft: half-width where it leaves the window, how fast it opens, how far it carries,
// and how round its start is.
uniform float shaft_wide = 22.0;
uniform float shaft_spread = 0.22;
uniform float shaft_long = 420.0;
// What the lit floor throws back into the rest of the room, as a share of the sun.
uniform float bounce = 0.18;

// The lit pieces: xy on the quad, z reach, w power. Pools lie on the floor, so they are
// measured squashed (`pool_squash`), wider than they are deep — and they are **in front of
// the piece, not around it** (Richard, 2026-09-20): a hearth's fire is on its front face and
// lights the boards before it, so the pool reaches `pool_ahead` times as far down the screen
// as across and falls off `pool_back` times as fast behind the piece.
//
// **The middle stays on the piece's own foot**: pushed forward instead, the brightest patch
// came away from the hearth and left a dark gap between the fire and its own light.
uniform int lamp_count = 0;
uniform vec4 lamps[8];
uniform vec3 lamp_tones[8];
uniform float pool_squash = 0.62;
uniform float pool_ahead = 1.45;
uniform float pool_back = 2.4;
uniform float pixel_fps = 8.0;


float flicker(float seed, float t) {
	// Two slow sines beating: a hearth breathes, it does not strobe.
	return 1.0 + 0.07 * sin(t * 5.3 + seed * 3.1) + 0.05 * sin(t * 8.9 + seed * 1.7);
}


void fragment() {
	vec2 at = (floor(UV * box_px / art_px) + 0.5) * art_px;
	float t = floor(TIME * pixel_fps) / pixel_fps;
	vec3 light = vec3(0.0);

	// The sun's shaft: along the light from the window, opening as it goes.
	vec2 from = at - window_at;
	vec2 dir = normalize(sun_dir);
	float along = dot(from, dir);
	float across = dot(from, vec2(-dir.y, dir.x));
	float wide = shaft_wide + max(along, 0.0) * shaft_spread;
	float beam = exp(-(across * across) / (wide * wide));
	// Soft where it enters, carried off with distance; never a hard start at the wall.
	float reach = smoothstep(-shaft_wide, shaft_wide * 1.5, along) * exp(-max(along, 0.0) / shaft_long);
	float shaft = beam * reach;
	// The room takes a little of it everywhere, more near the window's side.
	float fill = bounce * exp(-length(from) / (shaft_long * 1.4));
	light += sun_tone * sun_power * (shaft + fill);

	for (int i = 0; i < lamp_count; i++) {
		vec2 off = at - lamps[i].xy;
		off.y = off.y < 0.0 ? off.y * pool_back : off.y / pool_ahead;
		off.y /= pool_squash;
		float d = length(off) / max(lamps[i].z, 1.0);
		float pool = exp(-d * d * 3.2);
		light += lamp_tones[i] * lamps[i].w * pool * flicker(float(i), t);
	}

	COLOR = vec4(light, 1.0);
}
