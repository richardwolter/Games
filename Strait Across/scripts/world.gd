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
## Ceiling height, i.e. how far above the highest shore you can hold a piece. On a
## level with a lifted far shore the whole ceiling moves up with it, so the room to
## work in above the landing is the same as on a flat level.
const HEADROOM := 1220.0
## Flat ground kept beyond the top of a climb, so the truck lands on a plateau
## rather than on the crest itself.
const SLOPE_PLATEAU := 700.0
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

## World units per unit of vertex colour, for the depth a bank's mesh carries to
## the ground shader. Colour channels are clamped to 0..1, and a bank is over two
## thousand units deep, so the depth is divided by this going in and multiplied by
## it again in the shader. ground.gdshader has to agree with this number.
const DEPTH_IN_COLOUR := 4000.0

## Vertical spacing of a pillar's silhouette vertices. Fine enough to carry a
## crevice, coarse enough that the convex decomposition of the collision polygon
## stays cheap — the same trade the seabed makes.
const PILLAR_STEP := 34.0
## Peak-to-peak relief on a pillar's face, in world units. This IS collision:
## pieces catch on the ledges, so it is kept well under the pillar's own width.
const PILLAR_RELIEF := 44.0
## How far a pillar's foot is buried below the seabed line, so it reads as rock
## the strait was cut around rather than as a column stood on the floor.
const PILLAR_ROOT := 220.0

## How thick the cave roof is drawn. Only its underside is ever seen, so this is
## just enough rock that the band above the strait never runs out before the
## camera's top limit does.
const ROOF_THICKNESS := 1400.0
## Peak-to-peak relief on the roof's underside. Like the pillar's, this IS
## collision. It only ever adds rock UPWARD, away from the strait: the lowest
## point of the roof has to stay the ceiling plane the player is already stopped
## at, or there is rock hanging below a wall they cannot drag a piece through.
const ROOF_RELIEF := 190.0
## Horizontal spacing of the roof's underside vertices.
const ROOF_STEP := 46.0
## How much rock the camera is allowed to see above the ceiling plane. Without
## this the view stops exactly at the underside and the roof is a hard edge along
## the top of the screen rather than something the strait is inside of.
const ROOF_VIEW := 420.0
## How far a stalactite is buried up into the roof, for the same reason a pillar's
## foot is buried in the seabed: a visible seam reads as two objects.
const ROOF_ROOT := 180.0
## Depth the roof and its stalactites are painted at, on top of their own.
##
## The ground shader lightens towards a mesh's exposed face, because on a bank
## that face is the sunlit top. A cave roof's exposed face is its underside, and
## light does not reach it: painted at its true depth of zero the whole lid came
## out the pale tan of a beach, which is the one colour a cave cannot be. Pushing
## it past the shader's fade_depth hands back the dark rock underneath.
const ROOF_GLOOM := 640.0

## What a fully planted, fully stocked strait looks like. The scene's own values,
## named here because a level's plant_density and fish_density are shares OF
## these — reading them off the node at runtime would mean the first level to
## scale them down became the new full.
const FLORA_DENSITY := 0.8
const FISH_DENSITY := 1.6

## Spacing of the seabed's vertices. Fine enough to carry the roughness, coarse
## enough that the collision polygon's convex decomposition stays cheap.
const SEABED_STEP := 40.0
## Peak-to-peak height of the rock roughness, in world units. This DOES change
## collision - pieces catch on the ridges - so it is kept well under the height
## of the smallest piece.
const SEABED_ROUGHNESS := 46.0

## Thickness of the algae strip laid along the top face of the rock.
const ALGAE_DEPTH := 20.0

## Grip of the ground itself. Both used to be left unset, which meant the run-up
## and the seabed silently ran on the engine default while every bridge piece
## carried an authored number — so the one surface the player cannot choose was
## the one nobody had decided on.
##
## The shore is deliberately the grippiest thing in the game. The truck has to
## pull away and climb the far bank the same way every attempt, or the bridge
## stops being what is being tested. All the tuning pressure belongs on the
## pieces in between.
const SHORE_FRICTION := 1.0
## Slightly less, and it matters rarely — a piece that has sunk sits on this.
const SEABED_FRICTION := 0.9

## One shader for shore and seabed both: the join between two different ones was
## itself the seam. See shaders/ground.gdshader.
const GROUND_SHADER := preload("res://shaders/ground.gdshader")
## Preloaded rather than reached by class name, matching the shader above: the
## headless tools run scenes without the editor's class cache, and there a script
## known only by its class_name is a parse error.
const WATERFALL := preload("res://scripts/waterfall.gd")

@onready var water: Area2D = $Water
# Untyped: the camera script has no class_name and `refit()` is its own method.
@onready var camera := $Camera

var _half_width: float = 1600.0
var _max_depth: float = 600.0
## Height of the far shore's top above the waterline. 0 on a flat level.
var _far_lift: float = 0.0
## Horizontal distance that lift is spread over. 0 on a flat level.
var _slope_run: float = 0.0
## How far inland the banks reach. SHORE_RUN, unless a climb needs more room.
var _shore_run: float = SHORE_RUN
## Height of the near shore's lip above the waterline, and the run it climbs over.
## Both 0 on a level without a launch ramp.
var _near_rise: float = 0.0
var _near_ramp_run: float = 0.0
## Height of the cave roof above the highest ground, or 0 for open sky. When set
## it stands in for HEADROOM everywhere, so the roof and the invisible ceiling the
## player already had are the same plane.
var _roof: float = 0.0
## Noise for the roof's underside, kept between calls and dropped on every build
## so a new level re-seeds it. Null until the first level with a roof asks.
var _roof_noise: FastNoiseLite = null
var _ground: LevelDef.Ground = LevelDef.Ground.ROCK
var _life: LevelDef.Life = LevelDef.Life.FULL
var _plant_density: float = 1.0
var _fish_density: float = 1.0
## The scene's own backdrop, remembered on first build so a level that sets one
## can be followed by a level that doesn't.
var _default_backdrop: Texture2D = null
var _default_horizon: float = 0.55


func build(level: LevelDef) -> void:
	_half_width = level.half_width
	_max_depth = level.max_depth
	_far_lift = maxf(level.far_shore_lift, 0.0)
	_slope_run = level.far_slope_run()
	_near_rise = maxf(level.near_ramp_rise, 0.0)
	_near_ramp_run = maxf(level.near_ramp_run, 0.0) if _near_rise > 0.0 else 0.0
	# The near bank has to reach behind the truck's spawn, which a ramp pushes back.
	_shore_run = maxf(SHORE_RUN, _slope_run + SLOPE_PLATEAU)
	_shore_run = maxf(_shore_run, _near_ramp_run + LevelDef.NEAR_RUNUP + 200.0)
	_roof = maxf(level.cave_roof, 0.0)
	_roof_noise = null
	_ground = level.ground
	_life = level.life
	_plant_density = clampf(level.plant_density, 0.0, 1.0)
	_fish_density = clampf(level.fish_density, 0.0, 1.0)

	for child: Node in $Terrain.get_children():
		child.free()  # Immediate: we're about to add replacements at the same spot.

	# Before _frame_camera(), which is what fits the backdrop to the new bounds.
	_dress_backdrop(level)
	_build_shore(-_half_width, -_half_width - _shore_run, false)
	_build_shore(_half_width, _half_width + _shore_run, true)
	_build_seabed()
	_build_pillar(level)
	_build_roof()
	_build_stalactite(level)
	_build_seabed_prop(level)
	_shape_water()
	# After the water: the fall's churn is a parameter on the water's own shader,
	# and its push is a setting on the water body.
	_build_waterfall(level)
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
	# An empty box is how Birds is told to hold nothing, and a roofed level is the
	# one case that wants it: gulls circling under a cave ceiling read as a bug.
	$Birds.populate(
		Rect2() if _roof > 0.0 else Rect2(
			Vector2(camera.limit_left, camera.limit_top),
			Vector2(camera.limit_right - camera.limit_left, SURFACE_Y - camera.limit_top)
		),
		seed_value
	)
	# An empty bed is how both wildlife nodes are told to hold nothing: they clear
	# what they have and return, so a concrete channel comes back empty even when
	# the previous level was full of fish.
	# A level that wants no fish gets the same empty bed a concrete channel gets,
	# rather than a school of zero: populate() clears what it holds and returns.
	var bed := _seabed_points() if _life == LevelDef.Life.FULL \
		and _fish_density > 0.0 else PackedVector2Array()
	$Fish.density = FISH_DENSITY * _fish_density
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


## One bank, built from its own top line rather than as a rectangle, so a shore
## that rises is one continuous piece of ground instead of a step.
##
## `rising` is the far bank of a lifted level: its top starts at the waterline,
## where the seabed already arrives, and climbs inland to the level's full lift.
## Everything is world-space — the ground shader reads world coordinates to decide
## wet from dry, so the body sits at the origin and the polygon carries the shape.
func _build_shore(inner_x: float, outer_x: float, rising: bool) -> void:
	var floor_y := SURFACE_Y + _max_depth + 400.0 + DEEP_MARGIN

	var top := PackedVector2Array()
	var steps := maxi(int(_shore_run / SEABED_STEP), 8)
	for i in steps + 1:
		var x: float = lerpf(inner_x, outer_x, float(i) / float(steps))
		top.append(Vector2(x, _shore_top_y(x) if rising else _near_top_y(x)))

	var outline := PackedVector2Array(top)
	outline.append(Vector2(outer_x, floor_y))
	outline.append(Vector2(inner_x, floor_y))
	# The bank has to be wound the same way whichever side it is on, or the convex
	# decomposition gets a polygon turned inside out.
	if inner_x > outer_x:
		outline.reverse()

	var body := StaticBody2D.new()
	body.physics_material_override = _ground_physics(SHORE_FRICTION)
	$Terrain.add_child(body)

	var shape := CollisionPolygon2D.new()
	shape.polygon = outline
	body.add_child(shape)

	var visual := Polygon2D.new()
	visual.color = Color.WHITE  # ground.gdshader writes COLOR outright.
	visual.polygon = outline
	# Each vertex carries how far it sits below this bank's own top face, which is
	# the only way the shader can put the sunlit crust on the top of a hill
	# rather than at the waterline.
	#
	# Carried in the vertex COLOUR, scaled by DEPTH_IN_COLOUR. UV was the obvious
	# channel and does not work: a Polygon2D with no texture does not deliver its
	# uv array to the shader, so every fragment read UV.y as zero and the hill
	# stayed one flat slab. The colour is free instead — ground.gdshader writes
	# COLOR outright in fragment(), so nothing else is reading it.
	var tint := PackedColorArray()
	for point: Vector2 in outline:
		var top_y: float = _shore_top_y(point.x) if rising else _near_top_y(point.x)
		tint.append(Color((point.y - top_y) / DEPTH_IN_COLOUR, 0.0, 0.0, 1.0))
	visual.vertex_colors = tint

	var mat := _ground_material()
	mat.set_shader_parameter("local_depth", 1.0)
	visual.material = mat
	body.add_child(visual)


## Height of the far bank at a horizontal position: the waterline at the water's
## edge, climbing to the full lift over the slope's run and flat from there on.
##
## Smoothstep rather than a straight ramp because the two ends are what sell it as
## ground: a linear slope meets the water and the plateau at hard creases, and a
## truck hitting the toe of it at speed launches off the crease. This rolls into
## both. The grade is fixed, so a bigger lift makes a longer hill, not a steeper
## one — the climb should be a longer test of the bridge's approach, never a wall
## the truck simply cannot get up.
func _shore_top_y(x: float) -> float:
	if _far_lift <= 0.0:
		return SURFACE_Y
	var t: float = clampf((x - _half_width) / maxf(_slope_run, 1.0), 0.0, 1.0)
	return SURFACE_Y - _far_lift * smoothstep(0.0, 1.0, t)


## Height of the near bank at a horizontal position: flat until the ramp's foot,
## then climbing to the lip that sits exactly at the water's edge.
##
## Quadratic rather than the far bank's smoothstep, because only one of the two
## ends wants rounding. The foot has to be flat or the truck trips into the ramp
## at speed; the lip has to be the ramp's steepest point, since that is the angle
## the truck leaves at, and smoothing it would level the launch off to nothing.
func _near_top_y(x: float) -> float:
	if _near_rise <= 0.0 or _near_ramp_run <= 0.0:
		return SURFACE_Y
	var t: float = clampf((x + _half_width + _near_ramp_run) / _near_ramp_run, 0.0, 1.0)
	return SURFACE_Y - _near_rise * t * t


## The highest ground on the level, above the waterline. Either bank can be the
## one that is up, so the ceiling and the build box ask this rather than assuming
## it is the far one.
func _high_ground() -> float:
	return maxf(_far_lift, _near_rise)


## Top of the world: HEADROOM above the highest ground, which on a lifted level is
## the far bank rather than the waterline. Everything that used to say
## `SURFACE_Y - HEADROOM` asks this instead, so the ceiling, the walls, the build
## box and the camera cannot disagree about where the top is.
func _ceiling_y() -> float:
	return SURFACE_Y - _high_ground() - _headroom()


## How much room there is above the highest ground. HEADROOM on an open level,
## and the roof's own height in a cave — asked for rather than assumed, so the
## build box, the walls, the camera and the rock all shorten together.
func _headroom() -> float:
	return _roof if _roof > 0.0 else HEADROOM


## Grip for a piece of ground. Ground never bounces — a truck rebounding off the
## bank would read as a bug, not as physics.
func _ground_physics(friction: float) -> PhysicsMaterial:
	var pm := PhysicsMaterial.new()
	pm.friction = friction
	pm.bounce = 0.0
	return pm


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
	body.physics_material_override = _ground_physics(SEABED_FRICTION)
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
	# The level's own share is applied on top, so a strait can be sparsely planted
	# without being bare. Set before build(), which reads it while walking the bed.
	$Flora.density = FLORA_DENSITY * _plant_density
	$Flora.build(
		bed if _life == LevelDef.Life.FULL else PackedVector2Array(),
		noise_seed_for_level(),
		SURFACE_Y
	)


## A rock pillar standing in the middle of the strait, if the level asks for one.
##
## Built as GROUND, not as a prop: same polygon-and-shader recipe as the banks
## and the seabed, same palette, same veins and grit, and the same crust baked
## along its head where it stands in the sun. That is what makes it read as part
## of the strait rather than as an object dropped into it — a sprite would have
## to be redrawn for every biome, and would still be a different material from
## the rock it is standing on.
##
## The two sides are generated independently from the level's own noise, so the
## silhouette is never symmetrical and never smooth: that is where the crevices
## come from. The shader's veins draw the cracks on the face.
func _build_pillar(level: LevelDef) -> void:
	if level.pillar_width <= 0.0:
		return

	var at_x: float = clampf(level.pillar_at, -1.0, 1.0) * _half_width
	var head_y := SURFACE_Y - level.pillar_rise
	# Down to the seabed and then well past it, so the pillar is rooted in the
	# floor rather than balanced on top of it. A rock that meets the ground in a
	# visible seam reads as two objects. Asked for at the pillar's own x, or one
	# standing off-centre would be rooted at the depth of the middle and left
	# hanging over the shelf it actually stands on.
	var foot_y := _seabed_y_at(at_x) + PILLAR_ROOT

	var noise := FastNoiseLite.new()
	noise.seed = noise_seed_for_level() + 4801
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 1.0 / 190.0
	noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	noise.fractal_octaves = 3

	var steps := maxi(int((foot_y - head_y) / PILLAR_STEP), 6)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / float(steps)
		var y: float = lerpf(head_y, foot_y, t)
		# Flares towards the foot, on a curve rather than a straight taper: rock
		# spreads where it meets the bed and stands nearly plumb above that.
		var half: float = level.pillar_width * 0.5 \
			* lerpf(1.0, maxf(level.pillar_flare, 1.0), t * t)
		# A tapered head closes to a tip instead of ending in a face, which is the
		# difference between a rock somebody could bridge from and a stalagmite.
		# Never quite to zero: a polygon that meets itself is a degenerate shape
		# the collision decomposition has to be handed anyway.
		if level.pillar_taper > 0.0:
			half *= lerpf(0.06, 1.0, smoothstep(0.0, level.pillar_taper, t))
		# Fade the roughness out at the very top, so the head is a face somebody
		# could land a bridge on rather than a row of spikes, and at the very
		# bottom, where it is buried in the seabed anyway.
		var edge: float = smoothstep(0.0, 0.12, t) * smoothstep(0.0, 0.06, 1.0 - t)
		left.append(Vector2(
			at_x - half - _pillar_relief(noise, y, 0.0) * edge, y
		))
		right.append(Vector2(
			at_x + half + _pillar_relief(noise, y, 517.0) * edge, y
		))

	var outline := PackedVector2Array()
	for point: Vector2 in left:
		outline.append(point)
	for i in range(right.size() - 1, -1, -1):
		outline.append(right[i])

	var body := StaticBody2D.new()
	body.name = "Pillar"
	body.physics_material_override = _ground_physics(SHORE_FRICTION)
	$Terrain.add_child(body)

	var shape := CollisionPolygon2D.new()
	shape.build_mode = CollisionPolygon2D.BUILD_SOLIDS
	shape.polygon = outline
	body.add_child(shape)

	var visual := Polygon2D.new()
	visual.color = Color.WHITE  # ground.gdshader writes COLOR outright.
	visual.polygon = outline
	# Depth below the pillar's own head, so the crust caps it the way it caps a
	# bank. Without this the crust would be measured from the waterline and the
	# whole standing part would come out one flat slab — the same fault the
	# lifted bank had.
	var tint := PackedColorArray()
	for point: Vector2 in outline:
		tint.append(Color((point.y - head_y) / DEPTH_IN_COLOUR, 0.0, 0.0, 1.0))
	visual.vertex_colors = tint

	var mat := _ground_material()
	mat.set_shader_parameter("local_depth", 1.0)
	# Wet below the waterline, dry above it. The shader's usual test is |x| past
	# the bank, and a pillar stands inside the strait wherever it is put — wet by
	# that measure all the way to its head, which is standing in the open air.
	mat.set_shader_parameter("dry_by_height", 1.0)
	visual.material = mat
	body.add_child(visual)


## One side's departure from the pillar's nominal width at a given height.
##
## Always positive — it only ever adds rock — because a pillar whose sides can
## bite inwards pinches itself in two at the waist. The second, sharper term is
## what makes the crevices: a ridged noise raised to a power spends most of its
## range near zero and then jumps, so the face is mostly gentle with occasional
## deep clefts rather than uniformly lumpy.
func _pillar_relief(noise: FastNoiseLite, y: float, offset: float) -> float:
	var broad: float = noise.get_noise_1d(y + offset) * PILLAR_RELIEF
	var cleft: float = noise.get_noise_1d(y * 3.1 + offset + 2000.0)
	return broad + pow(maxf(cleft, 0.0), 3.0) * PILLAR_RELIEF * 2.4


## The rock lid over the strait, if the level asks for one.
##
## Same ground recipe as the banks and the pillar, hung the other way up. The
## underside is the only face anybody sees, so that is the one carrying the
## noise; everything above it is filler that runs past the top of the camera.
##
## Depth for the shader is measured DOWN from the underside, not from the
## waterline: rock gets darker the further into it you look, and in a roof
## "further in" is upward. Without that the whole slab comes out one flat tone,
## which is the same fault the lifted bank and the pillar both had.
func _build_roof() -> void:
	if _roof <= 0.0:
		return

	var left_x := -_half_width - _shore_run - 200.0
	var right_x := _half_width + _shore_run + 200.0
	var top_y := _ceiling_y() - ROOF_THICKNESS

	var outline := PackedVector2Array()
	var tint := PackedColorArray()
	var steps := maxi(int((right_x - left_x) / ROOF_STEP), 8)
	for i in steps + 1:
		var x: float = lerpf(left_x, right_x, float(i) / float(steps))
		var y := _roof_y_at(x)
		outline.append(Vector2(x, y))
		tint.append(_gloom(0.0))
	outline.append(Vector2(right_x, top_y))
	tint.append(_gloom(_ceiling_y() - top_y))
	outline.append(Vector2(left_x, top_y))
	tint.append(_gloom(_ceiling_y() - top_y))

	var body := StaticBody2D.new()
	body.name = "Roof"
	body.physics_material_override = _ground_physics(SHORE_FRICTION)
	$Terrain.add_child(body)

	var shape := CollisionPolygon2D.new()
	shape.build_mode = CollisionPolygon2D.BUILD_SOLIDS
	shape.polygon = outline
	body.add_child(shape)

	body.add_child(_rock_visual(outline, tint))


## Underside of the roof at a given x. Never below the ceiling plane — see
## ROOF_RELIEF.
##
## The noise is built once per level rather than per vertex: the stalactite asks
## this too, and it is called a few hundred times a build.
func _roof_y_at(x: float) -> float:
	if _roof_noise == null:
		_roof_noise = FastNoiseLite.new()
		_roof_noise.seed = noise_seed_for_level() + 9301
		_roof_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		_roof_noise.frequency = 1.0 / 260.0
		_roof_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
		_roof_noise.fractal_octaves = 3
	return _ceiling_y() - absf(_roof_noise.get_noise_1d(x)) * ROOF_RELIEF


## A rock spike hanging from that roof, if the level asks for one.
##
## The pillar's polygon walk, inverted: widest where it meets the roof, tapering
## to a tip at the bottom, roughened down both sides from the level's own noise.
## Rooted up inside the slab so the two read as one piece of rock.
func _build_stalactite(level: LevelDef) -> void:
	if _roof <= 0.0 or level.stalactite_width <= 0.0:
		return

	var at_x: float = clampf(level.stalactite_at, -1.0, 1.0) * _half_width
	var root_y := _roof_y_at(at_x) - ROOF_ROOT
	var tip_y := _ceiling_y() + maxf(level.stalactite_drop, 40.0)

	var noise := FastNoiseLite.new()
	noise.seed = noise_seed_for_level() + 6607
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 1.0 / 190.0
	noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	noise.fractal_octaves = 3

	var steps := maxi(int((tip_y - root_y) / PILLAR_STEP), 6)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / float(steps)  # 0 at the roof, 1 at the tip.
		var y: float = lerpf(root_y, tip_y, t)
		# Squared, so it holds most of its width for most of the drop and then
		# closes quickly — a spike, rather than a cone.
		var half: float = level.stalactite_width * 0.5 * (1.0 - t * t)
		# Roughness out of the tip as well as out of the root: a few units of
		# noise on a point that is nearly closed is a burr, not a crevice.
		var edge: float = smoothstep(0.0, 0.10, t) * smoothstep(0.0, 0.25, 1.0 - t)
		left.append(Vector2(at_x - half - _pillar_relief(noise, y, 0.0) * edge, y))
		right.append(Vector2(at_x + half + _pillar_relief(noise, y, 517.0) * edge, y))

	var outline := PackedVector2Array()
	for point: Vector2 in left:
		outline.append(point)
	for i in range(right.size() - 1, -1, -1):
		outline.append(right[i])

	var tint := PackedColorArray()
	for point: Vector2 in outline:
		tint.append(_gloom(tip_y - point.y))

	var body := StaticBody2D.new()
	body.name = "Stalactite"
	body.physics_material_override = _ground_physics(SHORE_FRICTION)
	$Terrain.add_child(body)

	var shape := CollisionPolygon2D.new()
	shape.build_mode = CollisionPolygon2D.BUILD_SOLIDS
	shape.polygon = outline
	body.add_child(shape)

	body.add_child(_rock_visual(outline, tint))


## A vertex colour for hanging rock: its own depth into the mesh, plus the gloom
## that keeps a cave from being lit like a beach.
func _gloom(depth: float) -> Color:
	return Color((depth + ROOF_GLOOM) / DEPTH_IN_COLOUR, 0.0, 0.0, 1.0)


## The drawn half of a piece of hanging rock: the ground shader, told to take its
## depth from the mesh rather than from the waterline, and to stay dry.
##
## Shared by the roof and the stalactite because they are the same material and
## because getting either of those two flags wrong is invisible until the level
## is on screen — a roof shaded as if it were underwater is a green ceiling.
func _rock_visual(outline: PackedVector2Array, tint: PackedColorArray) -> Polygon2D:
	var visual := Polygon2D.new()
	visual.color = Color.WHITE  # ground.gdshader writes COLOR outright.
	visual.polygon = outline
	visual.vertex_colors = tint
	var mat := _ground_material()
	mat.set_shader_parameter("local_depth", 1.0)
	# The shader picks its colours from two things, and for hanging rock both of
	# them answer the wrong question.
	#
	# It takes light-to-dark from how far BELOW the waterline a fragment is: rock
	# a thousand units up is as far from the water as it gets, so the lid came out
	# the palest colour in the palette. And it takes rock-or-sand from which side
	# of the waterline the fragment is on, so the whole roof was scored as dry
	# bank — beach, overhead, in a cave.
	#
	# Both are switched off rather than worked around. A waterline the mesh can
	# never be past keeps it on the rock palette, and collapsing that palette onto
	# its own deep end paints it at the far end of the light range everywhere.
	# What is left is unlit stone with the strata and veins still in it, which is
	# what a cave roof is.
	mat.set_shader_parameter("dry_by_height", 0.0)
	mat.set_shader_parameter("waterline_x", 1.0e9)
	mat.set_shader_parameter("rock_color", _shader_value(mat, "rock_deep_color"))
	mat.set_shader_parameter("crust_depth", 0.0)
	visual.material = mat
	return visual


## A shader parameter's current value, falling back to the shader's own default
## when the material has not overridden it. _ground_material() only sets the
## parameters a biome changes, so asking a ROCK level for its deep colours comes
## back null without this.
func _shader_value(mat: ShaderMaterial, name: String) -> Variant:
	var value: Variant = mat.get_shader_parameter(name)
	if value != null:
		return value
	return RenderingServer.shader_get_parameter_default(mat.shader.get_rid(), name)


## The level's one big seabed object, if it has one: drawn, and solid.
##
## Sized by the WATER COLUMN rather than by a scale in the level file. The thing
## has to stand on the floor and stop just under the surface, and both of those
## move with the level's depth and its seabed profile — a fixed scale would be
## right on one level and either buried or sticking out of the water on the next.
## So the height is taken from the gap between the two and the picture is fitted
## to it, which also means the level designer places it by saying WHERE, not how
## big.
func _build_seabed_prop(level: LevelDef) -> void:
	if level.seabed_prop == null:
		return
	var texture := level.seabed_prop
	var art := Vector2(texture.get_width(), texture.get_height())
	if art.x <= 0.0 or art.y <= 0.0:
		return

	var x: float = clampf(level.seabed_prop_at, -1.0, 1.0) * _half_width
	var floor_y := _seabed_y_at(x)
	var top_y := SURFACE_Y + maxf(level.seabed_prop_clearance, 0.0)
	# The water column, then whatever fraction of it the level wants. Shrinking
	# happens here rather than by scaling the node, so the base stays on the
	# floor and only the top comes down.
	var height := (floor_y - top_y) * clampf(level.seabed_prop_scale, 0.1, 1.0)
	if height <= 0.0:
		push_warning("Seabed prop has no room to stand in; skipped.")
		return
	var size := Vector2(art.x / art.y * height, height)

	var prop := Node2D.new()
	prop.name = "SeabedProp"
	# Its own base sits on the floor, so the node is positioned by the CENTRE of
	# the box the picture fills.
	prop.position = Vector2(x, floor_y - height * 0.5)
	# No z_index of its own. Added to Terrain AFTER the seabed, so it draws over
	# the rock it stands on, and left on the default layer so a piece leaning
	# against it is not painted over by it. The water's own tint sits at 10 and
	# still washes over the lot, which is what makes it read as underwater.
	$Terrain.add_child(prop)

	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	sprite.scale = size / art
	prop.add_child(sprite)

	if level.seabed_prop_polygon.size() < 3:
		push_warning("Seabed prop has no collision polygon; it is scenery only.")
		return

	var body := StaticBody2D.new()
	# Slippery, and it does not bounce. This is drowned wood under a rock crust:
	# a deck built on it should be able to slide off, and a piece that pings off
	# it would read as rubber.
	body.physics_material_override = _ground_physics(0.6)
	prop.add_child(body)

	var outline := PackedVector2Array()
	for point: Vector2 in level.seabed_prop_polygon:
		outline.append(point * size)
	var shape := CollisionPolygon2D.new()
	# The traced outline is concave — a trunk on a wide base — and SOLID is what
	# makes CollisionPolygon2D decompose it rather than treat it as a hollow ring.
	shape.build_mode = CollisionPolygon2D.BUILD_SOLIDS
	shape.polygon = outline
	body.add_child(shape)


## Where the seabed's top face sits at one x, roughness included — the same line
## the floor is actually built from, sampled rather than recomputed, so a prop
## cannot end up hovering over it or buried in it.
func _seabed_y_at(x: float) -> float:
	var bed := _seabed_points()
	if bed.is_empty():
		return SURFACE_Y + _max_depth
	var best := bed[0]
	for point: Vector2 in bed:
		if absf(point.x - x) < absf(best.x - x):
			best = point
	return best.y


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


## How far out from the cliff face the fall's column stands, as a fraction of the
## face's run. Far enough out that the water is clear of the rock and reads as
## falling in front of it, close enough that it is obviously coming off this bank.
const FALL_STANDOFF := 0.35


## The waterfall off the far cliff, if the level asks for one: the drawn column,
## the churn on the water it lands in, and the current that churn implies.
##
## All three are set from the same x, so there is no way for the picture and the
## physics to end up describing different waterfalls.
func _build_waterfall(level: LevelDef) -> void:
	var mat := ($Water/Visual as Polygon2D).material as ShaderMaterial

	if level.waterfall_width <= 0.0 or _far_lift <= 0.0:
		if mat != null:
			mat.set_shader_parameter("churn_reach", 0.0)
			mat.set_shader_parameter("churn_strength", 0.0)
		(water as WaterBody).current_strength = 0.0
		(water as WaterBody).current_reach = 0.0
		return

	var at_x := _half_width + _slope_run * FALL_STANDOFF
	var fall := WATERFALL.new()  # Untyped: class_name Waterfall is not in scope headless.
	fall.name = "Waterfall"
	# In front of the terrain and the flora, behind the fish and the water overlay:
	# the fall pours down the face of the rock, so being drawn behind that rock
	# would hide it completely.
	fall.z_index = 2
	fall.z_as_relative = false
	fall.position = Vector2(at_x, 0.0)
	# Off the lip of the face at this point, not off the clifftop inland — the
	# water leaves the rock where the rock ends.
	fall.top_y = _shore_top_y(at_x)
	fall.surface_y = SURFACE_Y
	fall.width = level.waterfall_width
	fall.lean = level.waterfall_width * 0.6
	$Terrain.add_child(fall)

	if mat != null:
		mat.set_shader_parameter("churn_x", at_x - fall.lean)
		mat.set_shader_parameter("churn_reach", level.waterfall_reach)
		mat.set_shader_parameter("churn_strength", 1.0)

	var body := water as WaterBody
	body.current_strength = level.waterfall_push
	body.current_origin_x = at_x - fall.lean
	body.current_reach = level.waterfall_reach


## Invisible box the player can't drag a piece out of. Sits just outside the
## water so a piece can still be nudged flush against either shore.
func _shape_bounds() -> void:
	var left_x := -_half_width - 20.0
	var right_x := _far_edge_x() + 20.0
	var wall_height := SURFACE_Y - _ceiling_y() + 20.0
	var wall := RectangleShape2D.new()
	wall.size = Vector2(40, wall_height)
	var wall_y := SURFACE_Y - wall_height * 0.5 + 10.0

	var left: CollisionShape2D = $Bounds/LeftWall
	left.shape = wall
	left.position = Vector2(left_x, wall_y)

	var right: CollisionShape2D = $Bounds/RightWall
	right.shape = wall
	right.position = Vector2(right_x, wall_y)

	var ceiling := RectangleShape2D.new()
	ceiling.size = Vector2(right_x - left_x + 40.0, 40)
	var top: CollisionShape2D = $Bounds/Ceiling
	top.shape = ceiling
	top.position = Vector2((left_x + right_x) * 0.5, _ceiling_y())

	# The outline traces the ground it stands on: down to the water on the near
	# side, down to the clifftop on the far one.
	$Bounds/Visual.points = PackedVector2Array([
		Vector2(-_half_width, SURFACE_Y - _near_rise),
		Vector2(-_half_width, _ceiling_y()),
		Vector2(_far_edge_x(), _ceiling_y()),
		Vector2(_far_edge_x(), SURFACE_Y - _far_lift),
	])


## Camera is bounded to the built world: the shores' outer edges, the build
## ceiling, and the seabed floor. Previously it ran several hundred units past
## all of those, so panning out found empty space beyond the terrain.
func _frame_camera() -> void:
	camera.position = Vector2(0, SURFACE_Y)
	# Shores run SHORE_RUN inland from each bank, so this is the terrain's edge.
	camera.limit_left = roundi(-_half_width - _shore_run)
	camera.limit_right = roundi(_half_width + _shore_run)
	# Ceiling the player can hold a piece at, and the floor the seabed is drawn to.
	# In a cave the view goes a little past the ceiling, or the roof's underside is
	# the top row of pixels and the strait reads as cut off rather than enclosed.
	camera.limit_top = roundi(_ceiling_y() - (ROOF_VIEW if _roof > 0.0 else 0.0))
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


## Outer edge of the far shore — the last ground the truck can be standing on.
func shore_edge_x() -> float:
	return _half_width + _shore_run


## Far end of the buildable strait: the water's edge on a flat level, the top of
## the cliff on a lifted one.
##
## The face has to be INSIDE the box the player works in. A cliff the pieces stop
## short of is a wall the player can only look at — the whole point of lifting the
## far bank is that the bridge has to be built up against it and over its lip.
func _far_edge_x() -> float:
	return _half_width + _slope_run


## Box the construction systems may operate in: inside the walls, above the floor.
func build_area() -> Rect2:
	var left := -_half_width + 60.0
	return Rect2(
		Vector2(left, _ceiling_y() + 60.0),
		Vector2(_far_edge_x() - 60.0 - left, _headroom() + _high_ground() + _max_depth - 120.0)
	)


## Generous box outside the walls. A piece that tunnels out of the world is
## refunded rather than silently lost.
func escape_bounds() -> Rect2:
	return Rect2(
		Vector2(-_half_width - 300.0, _ceiling_y() - 300.0),
		Vector2(_far_edge_x() + 300.0 + _half_width + 300.0,
			_headroom() + _far_lift + _max_depth + 900.0)
	)
