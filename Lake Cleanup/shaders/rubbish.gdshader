// The bob of everything floating on the lake.
//
// This exists for one reason: the swell used to be computed on the CPU, per piece, every
// frame. That meant the rubbish layer had to be rebuilt and re-submitted sixty times a
// second even when nothing in the lake had changed — and with a basin holding eighteen
// thousand pieces, "nothing changed" is the common case and the expensive one.
//
// Moving the bob here makes the geometry static. lake_grid.gd builds one triangle soup
// when the view moves or a piece is taken, and on every other frame the GPU rocks that
// same soup for free.
//
// Mirrors LakeGrid._swell exactly. If one drifts, floating rubbish stops agreeing with
// the splashes that mark where it was, which is visible immediately.
shader_type canvas_item;
render_mode blend_mix;

uniform float wave_amplitude = 5.0;
uniform float wave_speed = 1.0;

// How far a floating piece wanders off its anchor, in pixels. Rubbish on open water is not
// pinned: it turns on the surface and slides about with it, and a lake where every piece
// only ever moves straight up and down reads as a field of pegs. Mirrors LakeGrid._sway —
// the CPU needs the same number to know where a piece is for its ripple and its splash.
uniform float sway = 3.2;

// How wide a span of world the packed anchor covers, centred on zero. Mirrors
// LakeGrid.ANCHOR_SPAN.
uniform float anchor_span = 8192.0;

void vertex() {
	// The piece's own anchor position is packed into the red and green channels as one
	// sixteen-bit number, and the colour it should actually be drawn in is the grey level
	// in blue. UV cannot carry the anchor any more: the lake is drawn from an atlas now,
	// so UV is a real texture coordinate.
	//
	// The anchor has to be per piece rather than per vertex. Sampling the swell at each
	// corner shears the sprite by a pixel or so as the wave passes through it, which reads
	// as the junk breathing.
	float high = floor(COLOR.r * 255.0 + 0.5);
	float low = floor(COLOR.g * 255.0 + 0.5);
	float x = (high * 256.0 + low) / 65535.0 * anchor_span - anchor_span * 0.5;

	// The top anchor value is reserved: a piece lying on the beach, which does not float and
	// so does not move. See LakeGrid.DRY_ANCHOR.
	if (high < 255.0 || low < 255.0) {
		float t = TIME * wave_speed;
		VERTEX.y += (sin(x * 0.011 + t) * 0.62 + sin(x * 0.029 - t * 1.7) * 0.38) * wave_amplitude;
		// The wander. Two slow waves at different rates, off the same anchor, so neighbouring
		// pieces are never in step and nothing in the lake travels in a straight line.
		VERTEX.x += sin(t * 0.53 + x * 0.017) * sway;
		VERTEX.y += cos(t * 0.41 + x * 0.023) * sway * 0.5;
	}

	// Hand the fragment stage a real colour, so nothing downstream has to know about the
	// packing.
	COLOR = vec4(vec3(COLOR.b), COLOR.a);
}

// No fragment(). The grime used to be painted on here, as a per-piece noise stain; the art
// carries its own grime now (see art_source/LakeObjects.psd). Godot already hands the
// fragment stage COLOR as the vertex colour times the texture, so sampling TEXTURE again
// and multiplying squared the art: dark pieces went muddy and every soft-edged pixel went
// half see-through, letting the green water show through the rubbish.


