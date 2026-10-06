// The angler, brought into the same air as everything else on the lake.
//
// Every piece of floating rubbish goes through rubbish.gdshader, which greys it down and
// lays patchy olive filth over it. The hut, the piers and the crate are painted from
// style.gd's own muted wood. The character was the one thing on screen drawn straight off
// its sheet at full strength — a brighter, cleaner object than anything around it, which
// read as the figure being pasted on rather than standing there.
//
// This is not filth: the angler is not floating in the lake and should not look as though
// they are. It is the smallest correction that puts them in the same picture — a little
// saturation taken out, a little of the game's own brown mixed in, and the whole thing sat
// a shade under the brightness the HUD is drawn at.
//
// The numbers are uniforms rather than constants because they are a matter of taste and the
// only way to settle them is to look at the game while turning them. Their defaults mirror
// Style.FIGURE_DESAT and its neighbours, which the shed room bakes into its own copy of the
// sheet — settle them here and put the same numbers there, or the angler is one person
// outdoors and another one indoors.
shader_type canvas_item;
render_mode blend_mix;

// How far the sheet's colour is pulled toward its own brightness. The character art is more
// saturated than the lake it stands in; this is what closes most of that gap, and it does it
// without changing what colour anything is — a red shirt stays a red shirt.
uniform float desat : hint_range(0.0, 1.0) = 0.18;

// The colour the whole figure leans toward, and how far it leans. Style.WOOD, because that
// is what the hut, the crate and the piers are painted in, and a figure standing among them
// wants some of the same light on it.
uniform vec4 tone : source_color = vec4(0.47, 0.33, 0.21, 1.0);
uniform float tone_mix : hint_range(0.0, 1.0) = 0.10;

// And a shade darker. The HUD is drawn at full brightness on purpose — it is paper held up
// in front of the game — and the world underneath it should not be competing.
uniform float darken : hint_range(0.0, 1.0) = 0.05;

void fragment() {
	// COLOR arrives as the texture already sampled and already multiplied by whatever the
	// canvas item was modulated with — so this works on it in place. The first version read
	// TEXTURE itself and then multiplied the result by COLOR, which multiplied the sprite by
	// itself: the angler came out visibly darker outdoors than the same sheet drawn in the
	// shed, which is the whole reason they were two different-looking people.
	//
	// Rec. 601 luma, which is what the eye reads as brightness rather than the average of
	// the three channels: a plain average turns the skin grey before it touches the denim.
	float lit = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	vec3 col = mix(COLOR.rgb, vec3(lit), desat);
	col = mix(col, tone.rgb, tone_mix);
	// Alpha untouched. The sheet is keyed art with a hard edge, and anything done to alpha
	// here would show up as a halo on every frame of the walk.
	COLOR.rgb = col * (1.0 - darken);
}
