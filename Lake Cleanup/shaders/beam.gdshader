// The column of light standing over a find: Fortnite's loot beam, on the lake.
//
// Drawn on one quad per find by LakeGrid.GlintBeam, UV (0,0) at the top-left and (1,1) at
// the bottom-right, so the foot of the column is UV.y = 1 and its top is UV.y = 0. Brightest
// at the foot and gone by the top; soft at both sides; faint vertical streaks drift upward
// inside it so the light reads as rising rather than as a painted stripe.
//
// Carries no colour or brightness of its own: the caller passes both through draw_rect's
// modulate, which arrives here as COLOR. One shader serves every beam, buried or uncovered,
// without a uniform to update per find.
shader_type canvas_item;
render_mode blend_add;

#include "pixel.gdshaderinc"

// How far in from each side the column is at full strength (0 = a hard-edged bar,
// 1 = a soft spike). How steeply it fades toward the top. How strong the streaks are
// against the body and how fast they climb.
uniform float soft_side : hint_range(0.0, 1.0) = 0.75;
uniform float fade_up : hint_range(0.5, 4.0) = 1.7;
uniform float streak : hint_range(0.0, 1.0) = 0.35;
uniform float climb = 0.6;

// The beam's own screen x, so two beams side by side do not carry the same streaks.
varying float phase;

void vertex() {
	phase = VERTEX.x * 0.013;
}

void fragment() {
	float across = abs(UV.x - 0.5) * 2.0;
	float side = 1.0 - smoothstep(1.0 - soft_side, 1.0, across);
	float tall = pow(clamp(UV.y, 0.0, 1.0), fade_up);
	// Streaks: thin bright threads a fraction of the width apart, scrolling up. Value noise
	// stretched tall so a thread is a line, not a blob.
	float thread = blob_noise(vec2(UV.x * 9.0 + phase, UV.y * 2.5 - TIME * climb));
	float lines = smoothstep(0.55, 0.95, thread);
	float body = (1.0 - streak) + streak * lines;
	COLOR = vec4(COLOR.rgb, COLOR.a * side * tall * body);
}
