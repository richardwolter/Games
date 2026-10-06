// The plants move with the water (2026-10-02, Richard: "the sway should be with the water,
// not wind"). One swell for the whole lake, the rubbish's own (rubbish.gdshader, mirrored by
// LakeGrid._swell) on the lake's own clock:
//
//   - a plant afloat (a lily pad, an open-water bed, a reed standing in the lake) rises and
//     falls and wanders on it exactly as a piece of rubbish beside it does;
//   - a plant on land leans its top whole art pixels one way and the other with the swell at
//     its foot, so a lean runs across the lawn and the beach in the water's rhythm. Only the
//     top corners move: on a nearest-sampled picture that is a pixel-art shear, rows stepping
//     over, not a slide.
//
// Packed like the rubbish soup: the plant's foot x in the red and green (LakeGrid.pack_anchor),
// what the corner does in the blue — 1 afloat, 0.5 a land plant's top corner, 0 its foot —
// and what the vertex is in the alpha: 1 the plant itself, and one of three bands for its
// shadow (Flora.SHADE_LAND / SHADE_WATER / SHADE_BED), which also says the surface the shadow
// falls on. Any other alpha is not packed and keeps its colour.
//
// One sun (2026-10-02): a shadow corner is drawn in the ink of its surface, a uniform pushed
// every frame (Flora.shade_skin), so the overcast and the lightning reach a batch that is only
// laid out again when the sun has moved. And it moves with its plant: a shadow is the picture
// laid along the sun (Shade.cast), so the far end of it is the plant's top, and a top that
// leans `step` px sideways moves its shadow's far end `step` px along the picture's own width
// as it lies on the ground — `shadow_across`, that axis, pushed when the batch is laid. A
// shadow of something afloat rides the swell with it.
//
// The wood (2026-10-05, Richard, option D): two more roles in the blue, the ground's trees'.
//   - 0.375, WIND: an old Forest tree's top corner. It leans whole art pixels on the wind,
//     not on the swell: a slow wave running across the wood (`wind_clock`, pushed by Ground,
//     quicker in a storm). Its shadow's far end moves with it, as a plant's does.
//   - 0.125, FRAMES: every corner of one of Toffeecraft's animated trees, or of its shadow.
//     The tree's 16 frames lie side by side in the atlas `tree_stride` texels apart, and the
//     corner's uv is moved to the frame the clock is on, offset by a phase hashed off the
//     packed x (Ground jitters each tree's x by under a pixel so trees in one column of the
//     grid do not sway in step). The geometry does not move.
shader_type canvas_item;

global uniform float lake_clock;
uniform float wave_amplitude = 5.0;
uniform float wave_speed = 1.0;
uniform float sway = 3.2;
uniform float anchor_span = 8192.0;
// World px to one art px, and how far a land plant's top leans at the swell's crest, in
// art px. Rounded to whole art px.
uniform float art_pixel = 2.0;
uniform float lean = 1.4;
// The shadows' inks, by surface (Shade.tint_on), and where a picture's width lies on the
// ground under the sun the batch was laid for (the x axis of Shade.cast). Plain vec4s, not
// source_color: they are the same raw colours a vertex would have carried.
uniform vec4 land_ink = vec4(0.04, 0.06, 0.09, 0.3);
uniform vec4 water_ink = vec4(0.04, 0.06, 0.09, 0.63);
uniform vec4 bed_ink = vec4(0.04, 0.06, 0.09, 0.42);
uniform vec2 shadow_across = vec2(1.0, 0.0);
// The wood's wind: Ground's clock, how many art px an old tree's top leans at a gust, how fast
// the gust runs, and the animated trees' frames.
uniform float wind_clock = 0.0;
uniform float wind_lean = 1.0;
uniform float wind_speed = 2.2;
uniform float tree_fps = 8.0;
uniform float tree_frames = 16.0;
uniform float tree_stride = 44.0;

void vertex() {
	float flag = COLOR.a;
	bool plant = flag > 0.99;
	// Which shadow, by its alpha band: 0 land, 1 water, 2 the lakebed, -1 not a shadow.
	int shade = -1;
	if (!plant) {
		if (abs(flag - 0.5) < 0.06) {
			shade = 0;
		} else if (abs(flag - 0.25) < 0.06) {
			shade = 1;
		} else if (abs(flag - 0.75) < 0.06) {
			shade = 2;
		}
	}
	if (plant || shade >= 0) {
		float high = floor(COLOR.r * 255.0 + 0.5);
		float low = floor(COLOR.g * 255.0 + 0.5);
		float x = (high * 256.0 + low) / 65535.0 * anchor_span - anchor_span * 0.5;
		float t = lake_clock * wave_speed;
		float swell = sin(x * 0.011 + t) * 0.62 + sin(x * 0.029 - t * 1.7) * 0.38;
		if (abs(COLOR.b - 0.125) < 0.06) {
			float phase = fract(sin(x * 12.9898) * 43758.5453);
			float frame = mod(floor(wind_clock * tree_fps + phase * tree_frames), tree_frames);
			UV.x += frame * tree_stride * TEXTURE_PIXEL_SIZE.x;
		} else if (abs(COLOR.b - 0.375) < 0.06) {
			float gust = sin(wind_clock * wind_speed - x * 0.004) * 0.7
				+ sin(wind_clock * wind_speed * 0.43 - x * 0.0017 + 1.3) * 0.3;
			float step = round(gust * wind_lean) * art_pixel;
			if (plant) {
				VERTEX.x += step;
			} else {
				VERTEX += shadow_across * step;
			}
		} else if (COLOR.b > 0.75) {
			VERTEX.y += swell * wave_amplitude;
			VERTEX.x += sin(t * 0.53 + x * 0.017) * sway;
			VERTEX.y += cos(t * 0.41 + x * 0.023) * sway * 0.5;
		} else if (COLOR.b > 0.25) {
			float step = round(swell * lean) * art_pixel;
			if (plant) {
				VERTEX.x += step;
			} else {
				VERTEX += shadow_across * step;
			}
		}
		if (plant) {
			COLOR = vec4(1.0);
		} else if (shade == 0) {
			COLOR = land_ink;
		} else if (shade == 1) {
			COLOR = water_ink;
		} else {
			COLOR = bed_ink;
		}
	}
}
