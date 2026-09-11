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

// Time moved on in whole frames.
float stepped_time(float t, float fps) {
	return floor(t * fps) / max(fps, 0.001);
}
