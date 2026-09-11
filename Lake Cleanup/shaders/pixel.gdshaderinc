// The pixel-art rules the lake's water and foam shaders share.
//
// Three things, and every one of them is what separates "a smooth effect drawn behind pixel
// art" from "part of the pixel art":
//   - a grid: every effect is worked out once per pixel cell, not per fragment, so its edges
//     land on the art's own pixel size (the pack is drawn at two world pixels a source pixel)
//   - a threshold: in-between values are not blended, they are dithered between two palette
//     swatches with a fixed 4x4 Bayer pattern keyed to the grid, so a fade is a pattern of
//     flat colours rather than a new colour
//   - a clock that ticks: pattern animation moves in whole frames at `pixel_fps`, the way
//     hand-animated water tiles do. Anything that has to stay welded to something moving
//     smoothly (the swell the rubbish rides) keeps real TIME — see the callers.

const float BAYER4[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

// A threshold in (0, 1) for one grid cell. `step(bayer4(cell), v)` is 1 on a share `v` of the
// cells, spread evenly, and the same cells every frame — so a slow fade never crawls.
float bayer4(vec2 cell) {
	vec2 c = mod(floor(cell), 4.0);
	return (BAYER4[int(c.y) * 4 + int(c.x)] + 0.5) / 16.0;
}

// The same pattern shifted half a period both ways. For a second decision on the same pixel
// (which ramp, as well as which step on it): reusing one threshold for both makes the two
// dithers line up into a coarser pattern than either.
float bayer4_offset(vec2 cell) {
	return bayer4(cell + vec2(2.0, 1.0));
}

// Time moved on in whole frames.
float stepped_time(float t, float fps) {
	return floor(t * fps) / max(fps, 0.001);
}
