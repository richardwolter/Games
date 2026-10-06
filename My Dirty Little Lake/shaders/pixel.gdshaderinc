// The pixel-art rules the lake's water and foam shaders share.
//
//   - a grid: every effect is worked out once per pixel cell, not per fragment, so its edges
//     land on the art's own pixel size (the pack is drawn at two world pixels a source pixel)
//   - a clock that ticks: pattern animation moves in whole frames at `pixel_fps`, the way
//     hand-animated water tiles do. Anything that has to stay welded to something moving
//     smoothly (the swell the rubbish rides) keeps real TIME — see the callers.
//
// There is no dither. It was tried: a per-pixel Bayer pattern read as grain on open water,
// left lone pixels of dirty water in cleaned bays, and shimmered under a moving camera.
// In-between values are rounded to the nearest palette step instead, as solid areas.
//
// The grid only lands on real screen pixels because the lake's camera keeps it there: zoom
// is held to whole screen pixels per art pixel and the drawn camera position is snapped
// (Lake._push_zoom, Lake._snap_camera).

// One random number per cell, the same every time for the same cell.
float cell_hash(vec2 cell) {
	vec2 p = fract(cell * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

// Smooth value noise, 0 to 1, one blob about a unit wide. Blobs rather than grain: what is
// wanted from it is patches several pixels across with soft shapes, and it is evaluated on
// the pixel grid by the caller so its edges still land on art pixels.
float blob_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = cell_hash(i);
	float b = cell_hash(i + vec2(1.0, 0.0));
	float c = cell_hash(i + vec2(0.0, 1.0));
	float d = cell_hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Time moved on in whole frames.
float stepped_time(float t, float fps) {
	return floor(t * fps) / max(fps, 0.001);
}
