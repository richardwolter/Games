// The pollution meter's water: the murky sheet and the clean sheet, both drawn over the
// whole of the meter's art, the filth filling the track from the garbage-circle end and the
// clean water from the other, washing into each other across a feather that slides left as
// the lake is cleaned. Both sheets drift a pixel or two sideways so the water reads as water
// and not as a fill bar painted blue.
//
// TEXTURE is the murky sheet (it is the TextureRect's texture); the clean sheet comes in as
// a uniform. Every x here is a fraction of the sheet's width. Left of the track, under the
// garbage circle, the track's first column is stretched out (`leak`), so the water runs
// in behind the circle and its edge never shows a gap.
shader_type canvas_item;
render_mode blend_mix;

uniform sampler2D clean_tex : filter_nearest;

// Where the seam sits and how wide its blend is, as fractions of the sheet's width; the
// track's two ends, likewise, so a drifted sample never reaches the transparent margin
// behind the frame.
uniform float seam = 0.5;
uniform float feather = 0.08;
uniform float track_from = 0.31;
uniform float track_to = 0.9;
// How far left of the track the water is stretched, as a fraction of the width: the
// track's first column repeated under the garbage circle, so that however the sheets
// drift there is water behind the circle's edge and never the screen.
uniform float leak = 0.06;

// How far each sheet wanders, in fractions of the width, and how fast. Small: the sheets
// are not tileable, so they rock back and forth rather than scroll off one end.
uniform float murky_drift = 0.01;
uniform float clean_drift = 0.008;
uniform float murky_rate = 0.5;
uniform float clean_rate = 0.35;

void fragment() {
	vec2 texel = TEXTURE_PIXEL_SIZE;
	float x = UV.x;
	bool in_track = x >= track_from - leak && x <= track_to;
	float last = track_to - texel.x;

	vec2 murky_at = UV;
	vec2 clean_at = UV;
	if (in_track) {
		murky_at.x = clamp(x + sin(TIME * murky_rate) * murky_drift, track_from, last);
		clean_at.x = clamp(x + sin(TIME * clean_rate + 1.7) * clean_drift, track_from, last);
	}
	vec4 murky = texture(TEXTURE, murky_at);
	vec4 clean = texture(clean_tex, clean_at);

	float through = smoothstep(seam - feather * 0.5, seam + feather * 0.5, x);
	if (!in_track) {
		through = 0.0;
	}
	// The clean sheet lies over the murky one by its own alpha rather than replacing it:
	// it is painted a row shorter top and bottom and with a rounded left end, and a
	// straight swap showed the screen through those pixels once the seam reached them.
	COLOR = mix(murky, clean, through * clean.a);
}
