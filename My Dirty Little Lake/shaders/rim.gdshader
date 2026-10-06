// A find's gold rim, on a picture drawn by a CanvasItem rather than in the rubbish soup:
// the net's catch. The caller draws the find's own region again, offset a pixel each way,
// under the piece, with a modulate of pure green — a colour no real picture is drawn in —
// and this turns that copy into a flat gold silhouette cut by the art's alpha. Anything
// drawn in any other modulate passes through untouched, so one material serves the node.
//
// Same gold and same fade as rubbish.gdshader's rim: retune both together.
shader_type canvas_item;

uniform vec3 rim_gold : source_color = vec3(1.0, 0.84, 0.35);
uniform float rim_fade : hint_range(0.0, 1.0) = 1.0;

varying flat float rim;

void vertex() {
	rim = (COLOR.r < 0.01 && COLOR.g > 0.99) ? 1.0 : 0.0;
	if (rim > 0.5) {
		COLOR = vec4(1.0);
	}
}

void fragment() {
	if (rim > 0.5) {
		COLOR = vec4(rim_gold, COLOR.a * rim_fade);
	}
}
