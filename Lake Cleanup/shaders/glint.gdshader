// The glow under a find, buried or not. A flat draw_circle reads as a coin lying on the
// water; this is meant to read as light coming up through it instead — bright at the
// centre, gone well before the edge of the quad it is drawn on.
//
// Carries no colour or alpha of its own: GlintLayer passes both in through draw_rect's
// modulate, which arrives here as COLOR. So one shader serves every find at once, buried
// or uncovered, faint or bright, without a uniform to update per piece.
shader_type canvas_item;

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float angle = atan(c.y, c.x);
	// The reach wobbles with angle rather than holding one radius all the way round, so
	// the light reads as spilling unevenly off the object instead of a disc laid under
	// it. Two frequencies beating against each other keep the wobble from looking like a
	// deliberate N-pointed shape the way a single sine would.
	float wobble = 1.0 + 0.22 * sin(angle * 3.0) + 0.12 * sin(angle * 5.0 + 1.7);
	float d = length(c) / wobble;
	// Sharpened past a plain falloff: a light source is a point, not a disc with soft
	// edges, and pow() pulls the bright middle in tighter without moving the outer reach.
	float glow = pow(clamp(1.0 - d, 0.0, 1.0), 2.2);
	COLOR = vec4(COLOR.rgb, COLOR.a * glow);
}
