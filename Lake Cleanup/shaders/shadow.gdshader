// The shadows the floating rubbish throws on the water.
//
// Same bargain as rubbish.gdshader: the geometry is built once per rebuild and the movement
// happens here, so a basin of eighteen thousand shadows costs the CPU nothing per frame.
//
// It takes the wander and leaves the bob. A piece rises and falls on the swell; its shadow
// does not, because a shadow that lifts with the thing casting it is what tells the eye the
// thing is a sticker rather than something floating. But a piece also slides about the
// surface, and a shadow that stays behind while the mug it belongs to drifts a few pixels
// off it is the same tell twice over. So the sway term is mirrored exactly from
// LakeGrid._sway — the same numbers rubbish.gdshader uses — and the swell term is not here
// at all.
shader_type canvas_item;
render_mode blend_mix;

// Mirrors LakeGrid.SWAY, LakeGrid.WAVE_SPEED and LakeGrid.ANCHOR_SPAN. If any of the three
// drifts from its twin in rubbish.gdshader, the shadows stop travelling with the rubbish.
uniform float sway = 3.2;
uniform float wave_speed = 1.0;
uniform float anchor_span = 8192.0;

// What a shadow is drawn in, alpha included. Held here rather than in the vertex colours
// because those carry the anchor instead.
uniform vec4 shade : source_color = vec4(0.03, 0.08, 0.11, 0.16);

void vertex() {
	// The piece's anchor x, packed into red and green as one sixteen-bit number by
	// LakeGrid.pack_anchor. Per piece, not per vertex: every corner of one shadow reads the
	// same anchor, so a shadow slides whole instead of being sheared as the wave crosses it.
	float high = floor(COLOR.r * 255.0 + 0.5);
	float low = floor(COLOR.g * 255.0 + 0.5);
	float x = (high * 256.0 + low) / 65535.0 * anchor_span - anchor_span * 0.5;

	float t = TIME * wave_speed;
	VERTEX.x += sin(t * 0.53 + x * 0.017) * sway;
	VERTEX.y += cos(t * 0.41 + x * 0.023) * sway * 0.5;
}

void fragment() {
	COLOR = shade;
}
