// The bow wave: a streak of foam peeling off one side of a moving boat's bow.
//
// The foam the lake's other things wear sits still on their waterline. A boat under way does
// not wear foam so much as leave it: the bow pushes the water up into a line of white that
// runs back along the hull, peels away from it and falls apart behind. So this is not a ring
// but a pair of streaks, one each side, drawn as strips with local UVs — x runs from the bow
// (0) to the tail of the streak (1), y across the strip.
//
// Same language as the rest of the lake's foam: hard edges, broken into segments, bubbles
// rather than gradients. The segments and bubbles slide back down the streak as the boat
// moves, which is what makes it read as foam being left behind rather than a line drawn on.
//
// How hard the boat is pushing — 0 stopped, 1 under way — arrives in the vertex colour's
// alpha, so every boat can share this one material and a stopping boat's wave dies away.
shader_type canvas_item;
render_mode blend_mix;

// What the foam is drawn in, alpha included. Matches LakeGrid.FOAM_COLOUR, and a little more
// solid than its FOAM_ALPHA because a streak this thin at that alpha disappears into the water.
uniform vec4 foam : source_color = vec4(0.93, 0.97, 1.0, 0.75);

// How many segments fit down a streak, how fast they slide back at full push, and how many
// bubble cells fit down it and across it.
uniform float segments = 26.0;
uniform float slide = 3.0;
uniform float bubble_down = 70.0;
uniform float bubble_across = 5.0;

varying float push;

float foam_hash(vec2 cell) {
	vec2 p = fract(cell * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

void vertex() {
	push = COLOR.a;
}

void fragment() {
	float t = TIME;
	float u = UV.x;
	float v = UV.y * 2.0 - 1.0;

	// The line wanders across its strip as it goes, so it is water rather than a ruled edge,
	// and thins towards the tail.
	float wander = sin(u * 18.0 - t * 6.0) * 0.25 + sin(u * 41.0 + t * 4.0) * 0.12;
	float thick = mix(0.9, 0.45, u);
	float line = step(abs(v - wander * 0.5), thick * 0.5);

	// Broken into segments sliding back, more broken the further back they get.
	float segment = foam_hash(vec2(floor(u * segments - t * slide * push), 1.0));
	line *= step(0.2 + u * 0.5, segment);

	// Solid at the bow, coming apart into bubbles down the streak.
	float grain = foam_hash(floor(vec2(u * bubble_down - t * slide * 2.0 * push, UV.y * bubble_across)));
	float kept = mix(1.0, step(0.3 + u * 0.4, grain), smoothstep(0.2, 0.7, u));

	// In off the bow without a hard start, and out at the tail.
	float fade = smoothstep(0.0, 0.05, u) * (1.0 - smoothstep(0.6, 1.0, u));

	vec3 lit = mix(foam.rgb, vec3(1.0), grain * 0.3);
	COLOR = vec4(lit, foam.a * line * kept * fade * push);
}
