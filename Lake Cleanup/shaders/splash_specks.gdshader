// The ring of specks a splash throws across the surface (Water_Splash_Particles.png).
//
// The sheet is drawn in dark green, which over the lake read as muck rather than as water.
// Only its shape is kept: every speck is drawn in the same white the ripples are, at the
// sheet's own alpha times the burst's.
shader_type canvas_item;
render_mode blend_mix;

// Mirrors WaterSplash.FOAM.
uniform vec4 ink : source_color = vec4(0.93, 0.98, 1.0, 1.0);

void fragment() {
	// COLOR arrives as texture times modulate, so its alpha is the speck's shape at the
	// burst's strength already.
	COLOR = vec4(ink.rgb, COLOR.a);
}
