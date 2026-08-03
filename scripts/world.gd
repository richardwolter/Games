## Builds the strait for a level.
##
## The water surface is always y = 300 and the shore tops are always level with
## it, so every other system can keep treating those as fixed. What changes level
## to level is the width of the gap and how deep it is.
extends Node2D

## Water surface, in world space. Fixed — levels get wider and deeper, not higher.
const SURFACE_Y := 300.0
## How far inland each shore extends past the water's edge.
const SHORE_RUN := 1400.0
## Ceiling height, i.e. how far above the surface you can hold a piece.
const HEADROOM := 1220.0
## Spacing of the waterline's vertices. The shader's shortest wave is ~215 units
## long, so this samples it about nine times.
const SURFACE_STEP := 24.0

## Seabed cross-section, centre to edge: (fraction of half_width, fraction of
## max_depth). A shelf near each shore then a drop to the middle, so shallow
## water near the banks is buildable and the centre is not.
##
## The last entry reaches depth 0 at the bank so the floor RISES to meet the
## shore at exactly the waterline. It used to stop at 0.22, which left the shore
## standing on a vertical wall a fifth of the strait's depth high - a clean cut
## through the ground where a beach should be.
const SEABED_PROFILE: Array[Vector2] = [
	Vector2(0.0, 1.0),
	Vector2(0.19, 1.0),
	Vector2(0.30, 0.57),
	Vector2(0.56, 0.53),
	Vector2(0.69, 0.26),
	Vector2(0.81, 0.23),
	Vector2(0.90, 0.21),
	Vector2(1.0, 0.0),
]

## Rock below the seabed that exists only so the camera has somewhere to go.
##
## The camera's bottom limit used to be the bottom of the terrain, which meant
## the deepest water sat on the last row of pixels the view could reach — and the
## HUD is drawn over that row, so the one part of the strait a player needs to
## read when a piece sinks was the part covered by the toolbar. Extending the
## world below the floor gives the pan somewhere to go: drag down and the deep
## rises clear of the UI, with solid rock, not void, filling in underneath.
##
## Sized against the toolbar at the zoom levels this actually bites at, which is
## zoomed out — at 0.3 zoom this is about 1500 screen pixels of slack, and none of
## it is reachable by a piece, since build_area() still stops at max_depth.
const DEEP_MARGIN := 500.0

## Spacing of the seabed's vertices. Fine enough to carry the roughness, coarse
## enough that the collision polygon's convex decomposition stays cheap.
const SEABED_STEP := 40.0
## Peak-to-peak height of the rock roughness, in world units. This DOES change
## collision - pieces catch on the ridges - so it is kept well under the height
## of the smallest piece.
const SEABED_ROUGHNESS := 46.0

## Thickness of the algae strip laid along the top face of the rock.
const ALGAE_DEPTH := 20.0

## One shader for shore and seabed both: the join between two different ones was
## itself the seam. See shaders/ground.gdshader.
const GROUND_SHADER := preload("res://shaders/ground.gdshader")

@onready var water: Area2D = $Water
# Untyped: the camera script has no class_name and `refit()` is its own method.
@onready var camera := $Camera

var _half_width: float = 1600.0
var _max_depth: float = 600.0
var _ground: LevelDef.Ground = LevelDef.Ground.ROCK
var _life: LevelDef.Life = LevelDef.Life.FULL
## The scene's own backdrop, remembered on first build so a level that sets one
## can be followed by a level that doesn't.
var _default_backdrop: Texture2D = null
var _default_horizon: float = 0.55


func build(level: LevelDef) -> void:
	_half_width = level.half_width
	_max_depth = level.max_depth
	_ground = level.ground
	_life = level.life

	for child: Node in $Terrain.get_children():
		child.free()  # Immediate: we're about to add replacements at the same spot.

	# Before _frame_camera(), which is what fits the backdrop to the new bounds.
	_dress_backdrop(level)
	_build_shore(-_half_width - SHORE_RUN * 0.5)
	_build_shore(_half_width + SHORE_RUN * 0.5)
	_build_seabed()
	_shape_water()
	_shape_bounds()
	_frame_camera()
	# After the camera, which is what decides how much sky there is to fly in.
	_stock_wildlife()


## Birds in the sky and fish in the water, both re-seeded per level so a level
## always comes back looking like itself.
##
## Neither knows anything about the game — they are given a box to stay inside
## and left alone. The birds get the sky above the waterline; the fish get the
## seabed the flora was just planted along, so they can't swim through rock.
func _stock_wildlife() -> void:
	var seed_value := noise_seed_for_level()
	$Birds.populate(Rect2(
		Vector2(camera.limit_left, camera.limit_top),
		Vector2(camera.limit_right - camera.limit_left, SURFACE_Y - camera.limit_top)
	), seed_value)
	# An empty bed is how both wildlife nodes are told to hold nothing: they clear
	# what they have and return, so a concrete channel comes back empty even when
	# the previous level was full of fish.
	var bed := _seabed_points() if _life == LevelDef.Life.FULL else PackedVector2Array()
	$Fish.populate(bed, SURFACE_Y, _half_width, seed_value + 7)


## Swap in this level's scenery, or leave the scene's own default alone.
##
## The default is kept as the fallback rather than being duplicated into every
## level's .tres: most levels will want the sunset, and a level that forgets to
## set a backdrop should look ordinary rather than empty.
func _dress_backdrop(level: LevelDef) -> void:
	var backdrop := $Backdrop as Backdrop
	if _default_backdrop == null:
		_default_backdrop = backdrop.texture
		_default_horizon = backdrop.horizon_frac
	if level.backdrop != null:
		backdrop.texture = level.backdrop
		backdrop.horizon_frac = level.backdrop_horizon
	else:
		backdrop.texture = _default_backdrop
		backdrop.horizon_frac = _default_horizon


## Depth at a horizontal position, as a fraction of max_depth. Piecewise-linear
## down SEABED_PROFILE, which is defined for the right half and mirrored.
func _profile_depth(frac_x: float) -> float:
	var t := clampf(absf(frac_x), 0.0, 1.0)
	for i in range(1, SEABED_PROFILE.size()):
		var a := SEABED_PROFILE[i - 1]
		var b := SEABED_PROFILE[i]
		if t <= b.x:
			var span: float = maxf(b.x - a.x, 0.0001)
			return lerpf(a.y, b.y, (t - a.x) / span)
	return SEABED_PROFILE[SEABED_PROFILE.size() - 1].y


## The strait's floor, left edge to right edge. Shared by the collision polygon,
## the visual, and the water's underside, so all three agree by construction.
##
## SEABED_PROFILE is the macro shape and stays authoritative: the shelves are
## where a piece can find a foundation and the middle is where it is lost, and
## that is level design, not decoration. The noise here only roughens the line
## between those points, so the floor reads as broken rock without moving any
## shelf. The seed comes from the level's own dimensions, so a given level
## always builds the same seabed.
func _seabed_points() -> PackedVector2Array:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed_for_level()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 1.0 / 260.0
	noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.55

	var out := PackedVector2Array()
	var steps := maxi(int(_half_width * 2.0 / SEABED_STEP), 8)
	for i in steps + 1:
		var t := float(i) / float(steps)
		var x: float = lerpf(-_half_width, _half_width, t)
		var base: float = SURFACE_Y + _profile_depth(x / _half_width) * _max_depth

		# Ridged noise is 0..1 and spiky, which is the point - the strait floor
		# should be broken rock, not dunes. Centred so it cuts as well as piles.
		var rough: float = (noise.get_noise_1d(x) - 0.35) * SEABED_ROUGHNESS
		# A second, much finer pass for chipped edges between the big shapes.
		rough += noise.get_noise_1d(x * 5.7 + 1000.0) * SEABED_ROUGHNESS * 0.5
		# Fade to nothing at the banks so the floor still meets the shore walls
		# flush, and near the very centre so the deep stays reliably deep.
		var edge: float = smoothstep(0.0, 0.10, 1.0 - absf(x) / _half_width)
		out.append(Vector2(x, base + rough * edge))
	return out


func _build_shore(centre_x: float) -> void:
	var height := _max_depth + 400.0 + DEEP_MARGIN
	var half := Vector2(SHORE_RUN * 0.5, height * 0.5)

	var body := StaticBody2D.new()
	body.position = Vector2(centre_x, SURFACE_Y + height * 0.5)
	$Terrain.add_child(body)

	var rect := RectangleShape2D.new()
	rect.size = half * 2.0
	var shape := CollisionShape2D.new()
	shape.shape = rect
	body.add_child(shape)

	var visual := Polygon2D.new()
	visual.color = Color.WHITE  # ground.gdshader writes COLOR outright.
	visual.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	])
	visual.material = _ground_material()
	body.add_child(visual)


## Shared setup for every piece of ground, so the shore and the seabed cannot
## drift out of agreement about where the waterline is.
func _ground_material(algae: float = 0.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = GROUND_SHADER
	mat.set_shader_parameter("surface_y", SURFACE_Y)
	mat.set_shader_parameter("waterline_x", _half_width)
	mat.set_shader_parameter("algae_mix", algae)
	# Full rock detail everywhere. The web build ran without the veins, grit and
	# speckle for one release and the ground came out visibly flatter — not a
	# trade worth making now that the choppiness has been traced to a physics
	# controller rather than to fill rate. The `detail` uniform stays in the
	# shader as the lever to reach for if a weak machine ever needs it.
	mat.set_shader_parameter("detail", 1.0)
	match _ground:
		LevelDef.Ground.CONCRETE:
			_make_concrete(mat)
		LevelDef.Ground.DIRT:
			_make_dirt(mat)
	return mat


## Repaint the ground shader as graded earth — a dirt track's cutting rather than
## a poured channel or a natural strait.
##
## Built from the shader's dry-side palette rather than its wet one, which is the
## whole difference from concrete: dirt does not change material at the waterline,
## it just darkens, so the submerged colours here are the same browns a shade
## down. Strata stay, faintly — earth in section does have bedding, it is simply
## softer than rock's — and the veins come almost all the way out, since a cut
## bank has no cracks to speak of. The grit is pushed up instead: loose dry soil
## is the one thing here with visible texture.
func _make_dirt(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("rock_color", Color(0.54, 0.43, 0.30))
	mat.set_shader_parameter("rock_deep_color", Color(0.24, 0.19, 0.14))
	mat.set_shader_parameter("sand_color", Color(0.62, 0.50, 0.34))
	mat.set_shader_parameter("sand_deep_color", Color(0.28, 0.22, 0.16))
	mat.set_shader_parameter("crust_color", Color(0.75, 0.63, 0.43))
	mat.set_shader_parameter("strata_strength", 0.03)
	mat.set_shader_parameter("mottle_strength", 0.05)
	mat.set_shader_parameter("vein_strength", 0.03)
	mat.set_shader_parameter("grit_strength", 0.08)


## Repaint the ground shader as poured concrete.
##
## Same shader, different palette — what has to go is the structure that reads as
## stone, not the fine detail. Strata are the giveaway, since concrete has no
## bedding planes, so they're flattened; the veins stay and become cracks, the one
## rock feature concrete genuinely shares. Dry and wet sides land on nearly the
## same grey: a poured channel doesn't change material at the waterline the way a
## shore does, it just gets wet.
func _make_concrete(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("rock_color", Color(0.60, 0.60, 0.58))
	mat.set_shader_parameter("rock_deep_color", Color(0.30, 0.30, 0.30))
	mat.set_shader_parameter("sand_color", Color(0.68, 0.67, 0.64))
	mat.set_shader_parameter("sand_deep_color", Color(0.33, 0.32, 0.31))
	mat.set_shader_parameter("crust_color", Color(0.76, 0.75, 0.72))
	mat.set_shader_parameter("strata_strength", 0.0)
	mat.set_shader_parameter("mottle_strength", 0.045)
	mat.set_shader_parameter("vein_strength", 0.13)
	mat.set_shader_parameter("grit_strength", 0.045)


func _build_seabed() -> void:
	var floor_y := SURFACE_Y + _max_depth + 300.0 + DEEP_MARGIN
	var bed := _seabed_points()
	var outline := PackedVector2Array(bed)
	outline.append(Vector2(_half_width, floor_y))
	outline.append(Vector2(-_half_width, floor_y))

	var body := StaticBody2D.new()
	$Terrain.add_child(body)

	var shape := CollisionPolygon2D.new()
	shape.polygon = outline
	body.add_child(shape)

	var visual := Polygon2D.new()
	visual.color = Color.WHITE  # ground.gdshader writes COLOR outright.
	visual.polygon = outline
	visual.material = _ground_material()
	body.add_child(visual)

	if _life != LevelDef.Life.NONE:
		_build_algae_crust(bed, body)
	# Plants are the FULL step; an empty bed is how Flora is told to hold nothing.
	$Flora.build(
		bed if _life == LevelDef.Life.FULL else PackedVector2Array(),
		noise_seed_for_level(),
		SURFACE_Y
	)


## A strip hugging the seabed line. A fragment cannot know where the top face of
## the rock is - it moves with x and the rock polygon is hundreds of units deep -
## so the algae is its own thin polygon rather than a term in the shader, and
## follows the roughness for free.
func _build_algae_crust(bed: PackedVector2Array, parent: Node2D) -> void:
	var strip := PackedVector2Array(bed)
	# The lower edge wanders instead of running parallel to the rock.
	#
	# A constant-depth strip reads as a green line ruled along the seabed —
	# flat, and the one thing down there that admits the rock is a silhouette.
	# Letting the moss run deep in some places and thin to nothing in others
	# gives the rock a top face and sides: where the moss reaches down, the rock
	# is turned towards the light; where it thins, that face is turned away.
	for i in range(bed.size() - 1, -1, -1):
		strip.append(bed[i] + Vector2(0.0, ALGAE_DEPTH * _crust_depth(i)))

	var visual := Polygon2D.new()
	visual.color = Color.WHITE
	visual.polygon = strip
	visual.material = _ground_material(0.8)
	parent.add_child(visual)


## Depth multiplier for the moss at one vertex along the bed, 0.2 to ~3.5.
##
## Two sine waves of different, deliberately non-harmonic periods: one sets
## broad stretches of thick and thin, the other breaks up the edge vertex to
## vertex. Deterministic from the index, so it survives a rebuild without
## storing anything, and the same seabed always grows the same moss.
func _crust_depth(index: int) -> float:
	var i := float(index)
	var broad: float = sin(i * 0.21) * 0.5 + 0.5
	var fine: float = sin(i * 0.97 + 1.7) * 0.5 + 0.5
	# Cubed, so most of the bed carries a thin skin and the thick tongues are
	# occasional. A linear mix put moss halfway down the rock everywhere.
	return 0.2 + 3.3 * pow(broad * 0.7 + fine * 0.3, 3.0)


## Stable per level, so the seabed and everything growing on it rebuild the same
## way every time the level is loaded.
func noise_seed_for_level() -> int:
	return int(_half_width) * 31 + int(_max_depth)


## The water area covers surface down to the deepest point. Its visual traces the
## surface across the top and the seabed along the bottom, so the shallows read
## as shallow.
func _shape_water() -> void:
	water.position = Vector2.ZERO
	(water as WaterBody).surface_y = SURFACE_Y

	var rect := RectangleShape2D.new()
	rect.size = Vector2(_half_width * 2.0, _max_depth)
	water.get_node("Shape").shape = rect
	water.get_node("Shape").position = Vector2(0, SURFACE_Y + _max_depth * 0.5)

	# The top edge is subdivided rather than being a single span: water.gdshader
	# ripples the waterline in the vertex shader, and two corner vertices would
	# just tilt the whole surface. One vertex per SURFACE_STEP is enough for the
	# swell's wavelength.
	var poly := PackedVector2Array()
	var steps := maxi(int(_half_width * 2.0 / SURFACE_STEP), 2)
	for i in steps + 1:
		poly.append(Vector2(-_half_width + _half_width * 2.0 * float(i) / float(steps), SURFACE_Y))
	# Seabed comes back left-to-right, so walk it in reverse to close the ring.
	var bed := _seabed_points()
	for i in range(bed.size() - 1, -1, -1):
		poly.append(bed[i])

	var visual: Polygon2D = water.get_node("Visual")
	visual.polygon = poly
	var mat := visual.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("surface_y", SURFACE_Y)
		mat.set_shader_parameter("max_depth", _max_depth)
		mat.set_shader_parameter("half_width", _half_width)


## Invisible box the player can't drag a piece out of. Sits just outside the
## water so a piece can still be nudged flush against either shore.
func _shape_bounds() -> void:
	var wall_x := _half_width + 20.0
	var wall := RectangleShape2D.new()
	wall.size = Vector2(40, HEADROOM + 20.0)
	var wall_y := SURFACE_Y - HEADROOM * 0.5

	var left: CollisionShape2D = $Bounds/LeftWall
	left.shape = wall
	left.position = Vector2(-wall_x, wall_y)

	var right: CollisionShape2D = $Bounds/RightWall
	right.shape = wall
	right.position = Vector2(wall_x, wall_y)

	var ceiling := RectangleShape2D.new()
	ceiling.size = Vector2(_half_width * 2.0 + 80.0, 40)
	var top: CollisionShape2D = $Bounds/Ceiling
	top.shape = ceiling
	top.position = Vector2(0, SURFACE_Y - HEADROOM)

	$Bounds/Visual.points = PackedVector2Array([
		Vector2(-_half_width, SURFACE_Y),
		Vector2(-_half_width, SURFACE_Y - HEADROOM),
		Vector2(_half_width, SURFACE_Y - HEADROOM),
		Vector2(_half_width, SURFACE_Y),
	])


## Camera is bounded to the built world: the shores' outer edges, the build
## ceiling, and the seabed floor. Previously it ran several hundred units past
## all of those, so panning out found empty space beyond the terrain.
func _frame_camera() -> void:
	camera.position = Vector2(0, SURFACE_Y)
	# Shores run SHORE_RUN inland from each bank, so this is the terrain's edge.
	camera.limit_left = roundi(-_half_width - SHORE_RUN)
	camera.limit_right = roundi(_half_width + SHORE_RUN)
	# Ceiling the player can hold a piece at, and the floor the seabed is drawn to.
	camera.limit_top = roundi(SURFACE_Y - HEADROOM)
	camera.limit_bottom = roundi(SURFACE_Y + _max_depth + 300.0 + DEEP_MARGIN)
	camera.refit()

	# The backdrop paints exactly the box the camera can reach, so there is no
	# edge to find at any zoom or pan.
	#
	# DEEP_MARGIN is left out of the box on purpose. Backdrop scales itself to
	# cover whatever it is given, so counting the margin would magnify the whole
	# painting to fill 500 units of solid rock nobody can see through — and since
	# the horizon stays welded to the water, the magnification would come out of
	# the sky, hauling the scenery closer exactly as it was pushed away.
	var painted_bottom := float(camera.limit_bottom) - DEEP_MARGIN
	$Backdrop.fit_to(Rect2(
		Vector2(camera.limit_left, camera.limit_top),
		Vector2(camera.limit_right - camera.limit_left, painted_bottom - camera.limit_top)
	), SURFACE_Y)


## Box the construction systems may operate in: inside the walls, above the floor.
func build_area() -> Rect2:
	return Rect2(
		Vector2(-_half_width + 60.0, SURFACE_Y - HEADROOM + 60.0),
		Vector2(_half_width * 2.0 - 120.0, HEADROOM + _max_depth - 120.0)
	)


## Generous box outside the walls. A piece that tunnels out of the world is
## refunded rather than silently lost.
func escape_bounds() -> Rect2:
	return Rect2(
		Vector2(-_half_width - 300.0, SURFACE_Y - HEADROOM - 300.0),
		Vector2(_half_width * 2.0 + 600.0, HEADROOM + _max_depth + 900.0)
	)
