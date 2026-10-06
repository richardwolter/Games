// A fish seen through clean water (2026-09-30, the lakebed pass): its own colours from
// assets/fish.png, mixed a share of the way towards the water's colour over it, and faded in
// and out a whole art pixel at a time rather than through alpha — the foam's rule.
//
// Fish.gd hands both in the vertex colour: rgb is the water's colour at the fish, alpha packs
// (water share in fifteenths) * 16 + (how far in, in fifteenths).
shader_type canvas_item;

#include "res://shaders/pixel.gdshaderinc"

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float packed = floor(tint.a * 255.0 + 0.5);
	float share = floor(packed / 16.0) / 15.0;
	float shown = mod(packed, 16.0) / 15.0;
	vec2 texel = floor(UV / TEXTURE_PIXEL_SIZE);
	if (t.a < 0.5 || cell_hash(texel * 1.37 + vec2(3.1, 7.9)) >= shown) {
		discard;
	}
	COLOR = vec4(mix(t.rgb, tint.rgb, share), 1.0);
}
