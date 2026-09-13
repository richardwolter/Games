// The foam collar where a floating piece cuts the surface.
//
// A piece is drawn as a quad with its bottom edge taken off at the waterline, which is a
// straight cut across a sprite and reads as one. This is what is laid over that line: a
// ragged lip of white, torn along its length by noise and moving on the same clock the
// swell does, so what the eye reads is water lapping at a thing rather than a sprite
// standing in front of a picture of water.
//
// The geometry is a plain quad with local UVs — 0 to 1 across the piece and down the collar
// — so nothing here depends on the atlas.
//
// It takes the wander AND the bob, which is where it parts company with shadow.gdshader. A
// shadow does not rise with the piece throwing it: the shadow is on the water and the piece
// is what moved. The foam is the other way round — it is the line where the piece meets the
// surface, so it is pinned to the piece, and a collar that stayed put while the mug it
// belongs to rode up over it is a white ring the mug climbs out of on every wave.
//
// Every term mirrors rubbish.gdshader exactly. If one drifts, the foam swims off the cut.
//
// Pixel art (see pixel.gdshaderinc): the collar is worked out on a grid of `foam_pixel`
// squares laid in the piece's own frame, so the grid rides the swell with the piece rather
// than the foam's pixels crawling across it, and the tearing ticks at `pixel_fps`. The swell itself keeps real TIME — the piece moves smoothly, and a
// collar stepping behind it would come off its cut.
shader_type canvas_item;
render_mode blend_mix;

#include "res://shaders/pixel.gdshaderinc"

uniform float foam_pixel = 2.0;
uniform float pixel_fps = 8.0;
// The bright bubble cores. Palette `foam_light`.
uniform vec4 foam_core : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Where this fragment is in the piece's frame, before the swell moved it: world units.
varying vec2 local;

// Mirrors LakeGrid.SWAY, LakeGrid.WAVE_SPEED and LakeGrid.ANCHOR_SPAN, like every other
// shader on the floating rubbish. If one drifts, the foam parts company with the piece.
uniform float sway = 3.2;
uniform float wave_speed = 1.0;

// The lake's own clock (LakeGrid._time, pushed every frame as a global), not TIME: the
// CPU works the same swell out for splashes, birds, beams and ripples off that clock, and
// TIME runs from the engine's start while the lake's clock runs from the lake's, so the two
// were seconds apart and everything placed on a piece bobbed out of step with it.
global uniform float lake_clock;

// Mirrors LakeGrid.WAVE_AMPLITUDE. The swell it drives is rubbish.gdshader's own.
uniform float wave_amplitude = 5.0;
uniform float anchor_span = 8192.0;

// Where the waterline sits in the quad, as a fraction from its top. The collar is built
// with more room above the line than below it, for the tongues that go up the side of the
// piece, so this is nowhere near the middle. LakeGrid.FoamLayer works it out from the same
// two constants it builds the quad from.
uniform float cut_at = 0.48;

// What the foam is drawn in, alpha included. The vertex colours carry the anchor instead.
uniform vec4 foam : source_color = vec4(0.93, 0.97, 1.0, 0.5);

varying float seed;

// How many bubbles fit across a collar and down it, and how fast the field of them churns.
// Coarse on purpose: the pieces are ten pixels of pixel art, and foam ground finer than the
// art it sits against is a grey fizz rather than white water.
uniform float bubble_across = 20.0;
uniform float bubble_down = 7.0;
uniform float bubble_churn = 1.1;

// How many tongues the tear puts across a collar. Set for the ten-pixel rubbish; a wider
// collar — the ferry's hull — raises it in step with its width, or the foam comes out
// stretched.
uniform float tear_across = 12.0;

// How hard the half-ellipse below takes the foam's reach away towards the ends of the quad.
// 1 is the ellipse itself, which is right for a ten-pixel piece of rubbish — the collar is
// a short lip and it should draw up to nothing quickly. Under 1 the falloff is gentler and
// the froth carries further out to the sides before it goes, which is what a hull's length
// of waterline wants: a boat is in the water at its ends as well as its middle.
uniform float round_bite = 1.0;


// One number per cell of the bubble field, the same every time for the same cell. A hash
// rather than a texture: this is called once a fragment on a layer that can be eighteen
// thousand collars, and a sampler for it would be a texture fetch to learn a random number.
float bubbles_at(vec2 cell) {
	vec2 p = fract(cell * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

void vertex() {
	float high = floor(COLOR.r * 255.0 + 0.5);
	float low = floor(COLOR.g * 255.0 + 0.5);
	float x = (high * 256.0 + low) / 65535.0 * anchor_span - anchor_span * 0.5;
	seed = x;
	local = VERTEX;

	float t = lake_clock * wave_speed;
	// The swell, exactly as the piece rides it, so the collar sits on the cut at every point
	// of every wave rather than only at the top of one.
	VERTEX.y += (sin(x * 0.011 + t) * 0.62 + sin(x * 0.029 - t * 1.7) * 0.38) * wave_amplitude;
	VERTEX.x += sin(t * 0.53 + x * 0.017) * sway;
	VERTEX.y += cos(t * 0.41 + x * 0.023) * sway * 0.5;
}

void fragment() {
	// Snap to the pixel grid in the piece's frame, and carry UV to the middle of that cell. The
	// quad is affine, so UV's change per world unit is one matrix, read off the derivatives.
	vec2 cell = floor(local / foam_pixel);
	vec2 centre = (cell + 0.5) * foam_pixel;
	mat2 d_local = mat2(dFdx(local), dFdy(local));
	vec2 uv = UV;
	if (abs(determinant(d_local)) > 1e-8) {
		uv += mat2(dFdx(UV), dFdy(UV)) * inverse(d_local) * (centre - local);
	}

	// Across the collar: two waves beating against each other, seeded off the piece's own
	// anchor so no two pieces foam alike, and drifting so the lip is never the same shape
	// twice. Beating rather than one wave because a single sine reads as a scallop border.
	float t = stepped_time(TIME, pixel_fps) * 1.6;
	float across = uv.x * tear_across + seed * 0.05;
	float tear = sin(across + t) * 0.5 + sin(across * 2.3 - t * 0.7) * 0.5;

	// The collar curves round the ends rather than stopping at them: its reach is scaled by
	// a half-ellipse across the quad, so the foam is deepest in the middle of the piece and
	// draws up to nothing at either side. An alpha fade did this before and it read as a bar
	// going transparent — the same length of foam, dimmer at the ends. Taking the reach away
	// instead makes it a shorter lip, which is the shape of water round a thing in it.
	float round_off = pow(sqrt(max(1.0 - pow(uv.x * 2.0 - 1.0, 2.0), 0.0)), round_bite);

	// A second, faster tear for what goes up the side of the piece. Its own frequencies and
	// its own drift, so the tongues above the line are not the mirror of the lip below it —
	// which is what one shared noise looked like, and read as a stencil rather than water.
	float lift = sin(across * 1.9 - t * 1.3) * 0.5 + sin(across * 0.8 + t * 0.55) * 0.5;

	// How far the foam reaches either side of the waterline, and how solid it is there. The
	// lip is thickest where the tear is high and gone where it is low — that is the
	// raggedness — and both reaches are scaled by `round_off`, so the whole collar shortens
	// towards the ends of the piece rather than being cut off at them.
	//
	// The rise is deliberately allowed to go to nothing: where `lift` is low there is no
	// tongue at all, and the gaps between the ones there are is what stops the upper edge
	// reading as a second straight line above the first.
	float down = (0.34 + tear * 0.30) * round_off;
	float up = max(0.0, (0.14 + lift * 0.40) * round_off);

	// Distance from the waterline, in the quad's own units, and which way it lies. `cut_at`
	// is where the line sits in the quad — the quad is built with room above the cut for the
	// tongues, so it is not the middle.
	float d = uv.y - cut_at;
	float reach = d >= 0.0 ? down : up;
	float lip = 1.0 - smoothstep(reach * 0.3, max(reach, 0.001), abs(d));

	// The bubbles. `lip` on its own is a smooth ramp, which is a white smear however ragged
	// its outline is — this is what breaks the mass itself up. A field of cells, one random
	// number each, drifting slowly and seeded off the piece so no two collars carry the same
	// froth. Whole cells rather than a smooth noise, so the grain lands on something like the
	// art's own pixel size instead of dithering under it.
	vec2 bubble = floor(
		vec2(uv.x * bubble_across, uv.y * bubble_down)
		+ vec2(seed * 0.13 - t * 0.35, t * bubble_churn)
	);
	float grain = bubbles_at(bubble);

	// Dissolved by the lip rather than multiplied by it: where the foam is thick every cell
	// survives and it reads as solid white water; out towards the edges only the cells that
	// rolled high are kept, so the mass comes apart into separate bubbles instead of fading
	// out as a sheet. A floor under the dissolved part keeps the ones that lost from being
	// holes punched clean through the middle of the froth.
	float kept = mix(0.28, 1.0, step(grain, lip * 1.25));

	// And the bright cores: a bubble catching the light is whiter than the water round it,
	// and the brightest are where the foam is thickest.
	vec3 lit = mix(foam.rgb, foam_core.rgb, grain * 0.4 * lip);

	COLOR = vec4(lit, foam.a * lip * kept);
}
