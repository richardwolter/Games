// The house's inside giving way to another of its baked sets a source pixel at a time
// (scripts/house_inside.gd): a pixel is kept when its roll is under `show`, or over it when
// `flip`. One roll a whole source pixel of the room, never finer.
shader_type canvas_item;

uniform float show = 1.0;
uniform bool flip = false;
uniform vec2 origin = vec2(0.0);
uniform float px = 1.0;

varying vec2 local;

float roll(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec2 cell = floor((local - origin) / max(px, 0.0001));
	float r = roll(cell);
	bool keep = flip ? (r >= show) : (r < show);
	if (!keep) {
		discard;
	}
}
