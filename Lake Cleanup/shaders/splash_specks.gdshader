// The ring of specks a splash throws across the surface (Water_Splash_Particles.png).
//
// The sheet is drawn in dark green and smooth, and over the lake read as muck. Only its
// shapes and its timing are kept (issue #31, 2026-09-16): every speck is re-cut on the
// world's art-pixel grid — the texture is read once per `foam_pixel` cell, at the cell's
// middle, so the frame's soft edges land on whole pixels — and drawn in the palette's own
// foam swatches with a hard edge, the way every other foam in the lake is.
shader_type canvas_item;
render_mode blend_mix;

#include "res://shaders/pixel.gdshaderinc"

// The palette's foam, set by Palette.dress_foam.
uniform vec4 foam : source_color = vec4(0.93, 0.97, 1.0, 1.0);
uniform vec4 foam_core : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float foam_pixel = 2.0;
// Where the sheet's soft alpha becomes a speck.
uniform float edge = 0.4;

// How strong this burst is drawn: the modulate the sheet was drawn with.
varying float burst;
varying vec2 world_pos;

void vertex() {
	burst = COLOR.a;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	// Carry UV to the middle of this fragment's art-pixel cell. The quad is affine, so UV's
	// change per world unit is one matrix, read off the derivatives.
	vec2 cell = floor(world_pos / foam_pixel);
	vec2 centre = (cell + 0.5) * foam_pixel;
	mat2 d_world = mat2(dFdx(world_pos), dFdy(world_pos));
	vec2 uv = UV;
	if (abs(determinant(d_world)) > 1e-8) {
		uv += mat2(dFdx(UV), dFdy(UV)) * inverse(d_world) * (centre - world_pos);
	}
	float a = texture(TEXTURE, uv).a;
	float speck = step(edge, a);
	// The brighter cores of the sheet come out in the light swatch; the rest in the body's.
	vec3 lit = mix(foam.rgb, foam_core.rgb, step(0.8, a));
	COLOR = vec4(lit, speck * burst);
}
