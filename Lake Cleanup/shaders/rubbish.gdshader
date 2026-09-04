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

// How filthy the lake is, 0 to 1, and what the filth on a piece looks like.
//
// Smudges, not a wash. Tinting every pixel by the same amount is the obvious way to do this
// and it does not read as dirt at all — it reads as somebody turning the brightness down,
// which is exactly what the first version looked like. Real muck is patchy: it collects in
// some places and misses others, and the clean parts next to it are what make the dirty
// parts look dirty.
//
// So the filth is laid on through a noise field, thresholded so most of a piece stays as it
// was drawn, and seeded per piece so no two are marked alike. Handed the same reading the
// water is painted with, so the junk clears up as the lake does.
uniform float grime = 1.0;
uniform vec4 grime_color : source_color = vec4(0.26, 0.28, 0.18, 1.0);
// How dark a smudge gets where it is thickest, and how much of a piece is under one at all.
uniform float grime_soak = 0.72;
uniform float grime_cover = 0.42;
// How large the patches are. Smaller is finer speckle; larger is a few big stains.
uniform float grime_grain = 5.5;

varying float grime_seed;

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

	float t = TIME * wave_speed;
	VERTEX.y += (sin(x * 0.011 + t) * 0.62 + sin(x * 0.029 - t * 1.7) * 0.38) * wave_amplitude;
	// The wander. Two slow waves at different rates, off the same anchor, so neighbouring
	// pieces are never in step and nothing in the lake travels in a straight line.
	VERTEX.x += sin(t * 0.53 + x * 0.017) * sway;
	VERTEX.y += cos(t * 0.41 + x * 0.023) * sway * 0.5;

	// Hand the fragment stage a real colour, so nothing downstream has to know about the
	// packing.
	COLOR = vec4(vec3(COLOR.b), COLOR.a);

	// The anchor doubles as the piece's identity: every corner of one piece gets the same
	// number, and no two pieces in the lake share one. That is what stops the whole basin
	// wearing the same stain in the same place.
	grime_seed = fract(x * 0.0137) * 10.0;
}

// Value noise, the cheap way: a hash at each corner of the cell and a smooth blend between
// them. Two octaves, because one alone is too regular to pass for muck.
float hash(vec2 at) {
	return fract(sin(dot(at, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 at) {
	vec2 cell = floor(at);
	vec2 into = fract(at);
	into = into * into * (3.0 - 2.0 * into);
	return mix(
		mix(hash(cell), hash(cell + vec2(1.0, 0.0)), into.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), into.x),
		into.y
	);
}

void fragment() {
	vec4 col = texture(TEXTURE, UV) * COLOR;

	// The atlas is one big sheet, so UV alone would run the pattern straight across every
	// piece on it. Offsetting by the seed gives each its own patch of the field.
	vec2 at = UV * (256.0 * grime_grain) + vec2(grime_seed * 37.0, grime_seed * 11.0);
	float muck = noise(at) * 0.65 + noise(at * 2.3 + 4.0) * 0.35;
	// Thresholded, so most of the piece is left alone and what is left reads as a stain
	// rather than as a filter.
	float stain = smoothstep(1.0 - grime_cover, 1.0 - grime_cover * 0.35, muck) * grime;
	col.rgb = mix(col.rgb, grime_color.rgb * (col.rgb + 0.35), stain * grime_soak);
	COLOR = col;
}


