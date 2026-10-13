shader_type canvas_item;
// The ending's bubble (scripts/ending_reel.gd): the live view cut to a circle stepped on
// whole pixels, a foam-white rim, a soft vignette, and an iris that closes before each cut.

uniform float iris : hint_range(0.0, 1.0) = 1.0;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;
// One step of the edge, as a share of the bubble's width.
uniform float edge_step = 0.01;
uniform vec4 rim : source_color = vec4(0.93, 0.96, 0.92, 1.0);
uniform float rim_wide = 0.025;
uniform float vignette = 0.45;

void fragment() {
	vec2 q = floor(UV / edge_step) * edge_step + edge_step * 0.5;
	float d = length(q - 0.5) * 2.0;
	float open = mix(0.0, 1.0, iris);
	vec4 film = texture(TEXTURE, UV);
	float v = 1.0 - vignette * smoothstep(0.55 * open, open, d);
	film.rgb *= v;
	if (d > 1.0) {
		discard;
	}
	if (d > 1.0 - rim_wide) {
		COLOR = vec4(rim.rgb, alpha);
	} else if (d > open) {
		COLOR = vec4(0.04, 0.05, 0.05, alpha);
	} else {
		COLOR = vec4(film.rgb, alpha);
	}
}
