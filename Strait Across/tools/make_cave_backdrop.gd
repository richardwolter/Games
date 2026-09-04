## Paints the cave backdrop for level 7.
##
##   godot --headless --script tools/make_cave_backdrop.gd
##
## Unlike every other backdrop in the game this one has no painted source. The
## others are landscapes that were generated and then cut at their shoreline (see
## tools/make_backdrop.gd); a cave interior is the one view where that pipeline
## has nothing to cut — there is no horizon, no sky, and no light to place. What
## it needs instead is depth: rock that gets darker and bluer the further back it
## is, and enough hanging and standing silhouette that the far wall is obviously
## a long way behind the strait rather than a texture behind it.
##
## That is cheap to paint arithmetically and expensive to get out of a generator,
## so it is painted here. Everything is in this one file on purpose: it is not a
## pipeline, it is one picture.
##
## The canvas is built at the aspect tools/backdrop_aspect.gd asks for at
## horizon 0.5, so there is no pad step — Backdrop.fit_to() gets a texture that
## is already the shape of level 7's camera bounds and stretches it by nothing.
## If the level's width, depth or roof height change, re-run that tool and put
## the new number in ASPECT below.
extends SceneTree

const OUT := "res://art/background_cave.png"

## From tools/backdrop_aspect.gd for level_7.tres at backdrop_horizon 0.5.
const ASPECT := 2.981
const HEIGHT := 860

## Rock at the back of the cave, and the same rock close enough to read as the
## walls either side of the strait. Everything between them is a blend on depth.
const ROCK_FAR := Color(0.105, 0.125, 0.165)
const ROCK_NEAR := Color(0.235, 0.245, 0.275)
## The dark the roof climbs into. A cave's ceiling is the one part with no light
## on it at all, and the picture needs somewhere for the eye to stop.
const VOID := Color(0.035, 0.045, 0.065)
## Standing water in the dark: greener than the rock, and nearly as dark. The
## water shader draws over this, so it only has to be the right colour where the
## shader is thin — at the waterline.
const WATER := Color(0.075, 0.135, 0.135)
const DEEP := Color(0.02, 0.045, 0.055)
## The one light in the level, thrown across the far wall from somewhere off to
## the left of the strait. Faint: it exists to give the wall a lit side and a
## dark side, which is what stops flat noise reading as fog.
const GLOW := Color(0.30, 0.34, 0.36)
const GLOW_AT := Vector2(0.34, 0.52)
const GLOW_RADIUS := 0.42


func _initialize() -> void:
	var width := int(round(float(HEIGHT) * ASPECT))
	var horizon := HEIGHT / 2
	var image := Image.create(width, HEIGHT, false, Image.FORMAT_RGBA8)

	var rock := _noise(4801, 1.0 / 90.0, FastNoiseLite.FRACTAL_FBM, 4)
	var strata := _noise(1207, 1.0 / 26.0, FastNoiseLite.FRACTAL_FBM, 2)

	for y in HEIGHT:
		for x in width:
			var u := float(x) / float(width)
			var v := float(y) / float(horizon)  # 1.0 at the waterline.
			if y < horizon:
				image.set_pixel(x, y, _wall(u, v, x, y, rock, strata))
			else:
				image.set_pixel(x, y, _water(float(y - horizon) / float(HEIGHT - horizon)))

	_hang_stalactites(image, width, horizon, rock)
	_stand_stalagmites(image, width, horizon, rock)

	image.save_png(ProjectSettings.globalize_path(OUT))
	print("wrote %s  %dx%d = %.3f" % [OUT, width, HEIGHT, float(width) / float(HEIGHT)])
	quit()


## The far wall at a point: rock, lit from one side, going black towards the
## roof.
##
## Depth is taken from height rather than from distance to the middle. In a cave
## seen from inside it, the floor of the far chamber is the nearest thing to the
## viewer and the ceiling is the furthest — so the wall lightens downward, and
## the strait's own waterline lands at its lightest point, which is what welds
## the painting to the water.
func _wall(u: float, v: float, x: int, y: int, rock: FastNoiseLite, strata: FastNoiseLite) -> Color:
	var base := VOID.lerp(ROCK_FAR, smoothstep(0.0, 0.55, v))
	base = base.lerp(ROCK_NEAR, smoothstep(0.45, 1.0, v) * 0.75)

	# Rock texture, then bedding planes on top of it. The strata noise is sampled
	# with a squashed y so it comes out as broad horizontal banding rather than
	# as blobs — the same trick the ground shader uses.
	var grain := rock.get_noise_2d(float(x), float(y)) * 0.055
	var bands := strata.get_noise_2d(float(x) * 0.08, float(y)) * 0.045
	var shade := 1.0 + grain + bands

	# One soft light on the wall, and the rest of it left dark.
	var to_light := (Vector2(u, v * 0.5) - GLOW_AT) / GLOW_RADIUS
	var lit: float = maxf(1.0 - to_light.length(), 0.0)
	lit = lit * lit * 0.5

	var out := Color(
		base.r * shade + GLOW.r * lit,
		base.g * shade + GLOW.g * lit,
		base.b * shade + GLOW.b * lit,
		1.0
	)
	return out.clamp()


## Water below the waterline: the level's own shallows colour running down into
## something nearly black. Never actually black — the water shader darkens
## whatever is behind it again, and black behind that loses the seabed.
func _water(t: float) -> Color:
	return WATER.lerp(DEEP, smoothstep(0.0, 0.75, t))


## Rock spikes hanging from the top edge, in two layers.
##
## The far layer is drawn in the wall's own colours and only slightly darker, so
## it reads as more cave behind the cave; the near layer is close to black, since
## anything that near the viewer has no light on it at all. Two layers is the
## fewest that gives the roof any depth — one is a row of teeth.
func _hang_stalactites(image: Image, width: int, horizon: int, rock: FastNoiseLite) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260814
	for layer in 2:
		var near := layer == 1
		var tint := VOID if near else ROCK_FAR.darkened(0.25)
		var reach := 0.62 if near else 0.42
		var count := 9 if near else 14
		for i in count:
			var at := int((float(i) + rng.randf_range(0.15, 0.85)) * float(width) / float(count))
			var half := int(rng.randf_range(0.012, 0.032) * float(width))
			var drop := int(rng.randf_range(0.25, 1.0) * reach * float(horizon))
			_spike(image, at, half, 0, drop, tint, rock, near)


## And the matching spikes standing up out of the water, which is the only part
## of the far chamber's floor that shows above the strait's own waterline.
func _stand_stalagmites(image: Image, width: int, horizon: int, rock: FastNoiseLite) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77014
	for layer in 2:
		var near := layer == 1
		var tint := VOID.lerp(ROCK_FAR, 0.35) if near else ROCK_FAR.lightened(0.06)
		var count := 7 if near else 11
		for i in count:
			var at := int((float(i) + rng.randf_range(0.15, 0.85)) * float(width) / float(count))
			var half := int(rng.randf_range(0.010, 0.026) * float(width))
			var rise := int(rng.randf_range(0.10, 0.34) * float(horizon))
			_spike(image, at, half, horizon - 1, -rise, tint, rock, near)


## One spike: a triangle from `base_y` towards `length` (negative points up),
## widest at the base and closing to a tip, with the same rock grain over it as
## the wall has so it does not come out as a flat cut-out.
##
## Drawn straight into the image rather than as a polygon, because a triangle
## that has to be tinted per pixel is less code as a scanline loop than as a mesh
## somebody then has to shade.
func _spike(
	image: Image, at: int, half: int, base_y: int, length: int,
	tint: Color, rock: FastNoiseLite, near: bool
) -> void:
	var steps := absi(length)
	if steps <= 1 or half <= 0:
		return
	var step := 1 if length > 0 else -1
	for i in steps:
		var y := base_y + i * step
		if y < 0 or y >= image.get_height():
			continue
		var t := float(i) / float(steps)
		# Squared, so the spike keeps its width most of the way down and then
		# closes — the silhouette of rock, not of a cone.
		var w := int(float(half) * (1.0 - t * t))
		# A little wander, so no two sides are straight and none are symmetrical.
		var lean := int(rock.get_noise_1d(float(at) + float(y) * 0.7) * float(half) * 0.35)
		for x in range(at - w + lean, at + w + lean):
			if x < 0 or x >= image.get_width():
				continue
			var grain := rock.get_noise_2d(float(x), float(y)) * (0.03 if near else 0.05)
			var edge := 1.0 if near else 0.72  # Far spikes sit back into the haze.
			image.set_pixel(x, y, image.get_pixel(x, y).lerp(
				Color(tint.r + grain, tint.g + grain, tint.b + grain, 1.0).clamp(), edge
			))


func _noise(seed_value: int, frequency: float, fractal: int, octaves: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = frequency
	noise.fractal_type = fractal as FastNoiseLite.FractalType
	noise.fractal_octaves = octaves
	return noise
