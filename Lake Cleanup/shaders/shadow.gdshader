// The shadows the floating rubbish throws on the water.
//
// Same bargain as rubbish.gdshader: the geometry is built once per rebuild and the movement
// happens here, so a basin of eighteen thousand shadows costs the CPU nothing per frame.
//
// It takes the wander AND the bob, so the shadow is pinned to the piece. It used to leave
// the bob out, on the theory that a shadow lifting with the thing casting it reads as a
// sticker; on the pixel-art water the opposite was the tell — a piece heaving on the swell
// over a shadow that stayed put read as two things moving separately. Every term mirrors
// rubbish.gdshader exactly, like foam.gdshader; if one drifts, the shadow swims off the piece.
shader_type canvas_item;
render_mode blend_mix;

// Mirrors LakeGrid.SWAY, LakeGrid.WAVE_SPEED, LakeGrid.WAVE_AMPLITUDE and
// LakeGrid.ANCHOR_SPAN. If any drifts from its twin in rubbish.gdshader, the shadows stop
// travelling with the rubbish.
uniform float sway = 3.2;
uniform float wave_speed = 1.0;
uniform float wave_amplitude = 5.0;
uniform float anchor_span = 8192.0;

// What a shadow is drawn in, alpha included. Held here rather than in the vertex colours
// because those carry the anchor instead.
uniform vec4 shade : source_color = vec4(0.03, 0.08, 0.11, 0.16);

// How far the silhouette's edge is blurred, in source texels. The art is squashed to half
// its height here and drawn at twice its size, and its hard pixel edge came out as a
// staircase of blocks under every piece — a shadow on water is soft at the edge, since the
// water under it is not flat. A cross of four taps either side of the centre.
uniform float soften = 1.2;

void vertex() {
	// The piece's anchor x, packed into red and green as one sixteen-bit number by
	// LakeGrid.pack_anchor. Per piece, not per vertex: every corner of one shadow reads the
	// same anchor, so a shadow slides whole instead of being sheared as the wave crosses it.
	float high = floor(COLOR.r * 255.0 + 0.5);
	float low = floor(COLOR.g * 255.0 + 0.5);
	float x = (high * 256.0 + low) / 65535.0 * anchor_span - anchor_span * 0.5;

	// The top anchor value is reserved for a piece lying on the beach, whose shadow stays put
	// like the piece does. See LakeGrid.DRY_ANCHOR.
	if (high < 255.0 || low < 255.0) {
		float t = TIME * wave_speed;
		VERTEX.y += (sin(x * 0.011 + t) * 0.62 + sin(x * 0.029 - t * 1.7) * 0.38) * wave_amplitude;
		VERTEX.x += sin(t * 0.53 + x * 0.017) * sway;
		VERTEX.y += cos(t * 0.41 + x * 0.023) * sway * 0.5;
	}
}

void fragment() {
	// The piece's own art, kept only for its alpha: the shape is the sprite's, the colour is
	// the uniform's. That is what makes a shadow the shape of the thing above it without a
	// second copy of the art or an outline anybody had to draw.
	vec2 d = TEXTURE_PIXEL_SIZE * soften;
	float a = texture(TEXTURE, UV).a * 2.0
		+ texture(TEXTURE, UV + vec2(d.x, 0.0)).a
		+ texture(TEXTURE, UV - vec2(d.x, 0.0)).a
		+ texture(TEXTURE, UV + vec2(0.0, d.y)).a
		+ texture(TEXTURE, UV - vec2(0.0, d.y)).a;
	COLOR = vec4(shade.rgb, shade.a * a / 6.0);
}
