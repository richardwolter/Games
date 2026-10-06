// The pollution meter's water: the murky sheet and the clean sheet, the filth filling the
// track from the garbage-circle end and the clean water from the other, washing into each
// other across a feather that slides left as the lake is cleaned. Both sheets drift a pixel
// or two sideways so the water reads as water and not as a fill bar painted blue.
//
// TEXTURE is the murky sheet (it is the TextureRect's texture); the clean sheet comes in as
// a uniform. Every coordinate here is a fraction of the sheet.
//
// Inside the water band (the track, plus `leak` to the left of it, in behind the circle)
// every sample is clamped to `opaque`: the rectangle where both sheets are fully opaque.
// Both are painted with soft, part-transparent ends and edges, and the circle only covers
// part of that fade — so a drift that sampled the fade showed the screen through the gap
// between circle and water, on some phases of the drift and not others. Clamped, the band
// is solid water on every frame, and the band's own alpha is forced to 1.
shader_type canvas_item;
render_mode blend_mix;

uniform sampler2D clean_tex : filter_nearest;

// Where the seam sits and how wide its blend is, as fractions of the sheet's width.
uniform float seam = 0.5;
uniform float feather = 0.08;

// The water band: the track's two ends and its top and bottom, as fractions of the sheet.
uniform float track_from = 0.31;
uniform float track_to = 0.9;
uniform float track_top = 0.39;
uniform float track_bottom = 0.67;
// How far left of the track the band runs, under the garbage circle, as a fraction of the
// width.
uniform float leak = 0.06;
// Where both sheets are fully opaque, as fractions of the sheet: x from, y from, x to,
// y to — texel centres, inclusive.
uniform vec4 opaque = vec4(0.336, 0.431, 0.888, 0.628);

// How far each sheet wanders, in fractions of the width, and how fast. Small: the sheets
// are not tileable, so they rock back and forth rather than scroll off one end.
uniform float murky_drift = 0.01;
uniform float clean_drift = 0.008;
uniform float murky_rate = 0.5;
uniform float clean_rate = 0.35;

void fragment() {
	vec2 at = UV;
	bool in_band = at.x >= track_from - leak && at.x <= track_to
		&& at.y >= track_top && at.y <= track_bottom;
	if (!in_band) {
		COLOR = texture(TEXTURE, at);
	} else {
		float y = clamp(at.y, opaque.y, opaque.w);
		vec2 murky_at = vec2(
			clamp(at.x + sin(TIME * murky_rate) * murky_drift, opaque.x, opaque.z), y
		);
		vec2 clean_at = vec2(
			clamp(at.x + sin(TIME * clean_rate + 1.7) * clean_drift, opaque.x, opaque.z), y
		);
		vec4 murky = texture(TEXTURE, murky_at);
		vec4 clean = texture(clean_tex, clean_at);
		float through = at.x < track_from
			? 0.0
			: smoothstep(seam - feather * 0.5, seam + feather * 0.5, at.x);
		COLOR = vec4(mix(murky.rgb, clean.rgb, through), 1.0);
	}
}
