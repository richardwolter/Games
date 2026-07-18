shader_type canvas_item;
// Pencil-shade fog of war. The sprite's texture is the low-res explored grid
// (R channel: 1 = explored). Unexplored cells get a grey wash modulated by two
// crossing sine "hatch" stroke sets so it reads as scribbled pencil on the
// notebook page, not a flat digital overlay.

uniform vec4 fog_color : source_color = vec4(0.36, 0.35, 0.33, 1.0);
uniform float fog_alpha : hint_range(0.0, 1.0) = 0.88;
// Softer wash over explored-but-not-currently-visible ground, so the live
// hero vision bubble reads distinctly against remembered terrain.
uniform float memory_alpha : hint_range(0.0, 1.0) = 0.30;

void fragment() {
	vec2 grid = texture(TEXTURE, UV).rg;
	float explored = grid.r;
	float visible_now = grid.g;
	// Unexplored -> fog_alpha; explored but unwatched -> memory_alpha; in
	// current vision -> clear.
	float fog = mix(mix(fog_alpha, memory_alpha, explored), 0.0, visible_now);
	// Hatch in texture space scaled so strokes are ~12-20 world px wide.
	vec2 p = UV / TEXTURE_PIXEL_SIZE * 2.2;
	float h1 = 0.80 + 0.20 * sin(p.x + p.y + sin(p.y * 0.37) * 2.0);
	float h2 = 0.90 + 0.10 * sin(p.x * 0.8 - p.y * 1.1);
	COLOR = vec4(fog_color.rgb * h1 * h2, fog);
}
