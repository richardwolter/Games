## Seaweed, coral and grass growing along the seabed.
##
## Drawn in code rather than placed as sprites: the seabed is generated per
## level and reshapes on every rebuild, so anything hand-placed would be
## floating one level later. `build()` walks the seabed line the world just
## generated and plants along it.
##
## Everything sways off a single TIME-driven phase, offset per plant, so a bed
## of kelp does not move as one sheet. The whole layer redraws each frame, which
## is affordable because it is a few hundred short polylines and no physics.
class_name SeabedFlora
extends Node2D

## Average gap between plants along the seabed, in world units.
@export var spacing: float = 62.0
## Chance a given slot actually grows something. Below 1.0 so the bed has bare
## patches instead of reading as a planted row.
@export_range(0.0, 1.0) var density: float = 0.8
@export var sway_speed: float = 0.9

## Everything down here is seen through the water overlay, which desaturates and
## blues it. These are picked to survive that - flat mid-greens go grey.
@export var kelp_color: Color = Color(0.16, 0.52, 0.33, 0.95)
@export var grass_color: Color = Color(0.40, 0.66, 0.32, 0.9)
@export var coral_color: Color = Color(0.82, 0.34, 0.42, 0.95)
@export var coral_alt_color: Color = Color(0.94, 0.62, 0.26, 0.95)

## Moss growing down onto the rock below the algae crust. Lighter than the crust
## and thinning with depth, so the rock reads as having a lit top face and a
## shaded side rather than being a flat silhouette with a green line on it.
@export var moss_color: Color = Color(0.22, 0.48, 0.26, 0.9)
@export var moss_light: Color = Color(0.46, 0.68, 0.30, 0.85)
## Blobs per 100 units of seabed, and how far down the rock they may reach.
@export var moss_density: float = 5.0
@export var moss_reach: float = 96.0

enum Kind { KELP, GRASS, CORAL }


## One speckle of moss on the rock. Static — moss doesn't sway, which is part of
## what makes the kelp beside it look like it does.
class Moss:
	var at: Vector2
	var radius: float
	var color: Color

## One plant: where it grows, how big, and its own phase so neighbours are out
## of step with each other.
class Plant:
	var kind: Kind
	var base: Vector2
	var height: float
	var width: float
	var phase: float
	var lean: float
	var color: Color
	var blades: int


## The outline every plant is drawn with, and how much wider than the stroke it
## sits. The sprites are all flat fills inside one heavy dark line, and plants
## drawn as bare polylines were the only things down there without it — they read
## as diagram strokes rather than as painted objects. Not pure ink: seen through
## the water overlay a true black plant becomes a hole.
const OUTLINE := Color(0.05, 0.14, 0.12, 0.85)
const OUTLINE_WIDTH := 3.0
## How much lighter the sunlit side of a frond is.
const SHEEN := 0.22

## Shallowest water a plant will grow in.
const MIN_DEPTH := 40.0
## Fraction of the water column above a plant that it may fill. Under 1 so even
## the tallest kelp keeps its tips below the surface.
const MAX_FILL := 0.85

## How often the swaying plants are redrawn, in times per second.
##
## Not every frame. The plants are the most expensive thing on screen — around a
## thousand polylines, each rebuilt from scratch on redraw — and they move at a
## slow drift where the difference between 60 and 30 updates a second is
## invisible. On the web build, where this all runs on one thread, halving it is
## most of a frame's work given back.
const REDRAW_HZ := 30.0

var _plants: Array[Plant] = []
var _moss: Array[Moss] = []
var _surface_y: float = -1e9
## Moss lives on its own canvas item and is drawn ONCE.
##
## It never moves, but it was being re-emitted every frame along with the plants
## simply for sharing a _draw() with them — 681 circles a frame on level 2, more
## than a third of everything the seabed cost. A separate CanvasItem keeps its
## own command buffer, so drawing it once is drawing it for good.
var _moss_layer: Node2D
var _since_redraw: float = 0.0
## Horizontal slice of the level the camera can currently see, in this node's
## local space, padded by CULL_PAD. Refreshed on each redraw.
var _view_from: float = -1e9
var _view_to: float = 1e9

## How far past the screen edge a plant is still drawn.
##
## The seabed runs the whole width of the level and the camera sees a fraction of
## it, but every plant was being rebuilt and submitted every redraw regardless —
## a thousand polylines a frame to draw the two hundred you can see. A canvas
## item is culled as a whole by its item rect, and this one's rect is the entire
## strait, so the engine could never do this for us.
##
## The pad is generous because a plant is anchored at its base and leans: culling
## exactly at the edge would pop the tips of kelp that is still half on screen.
const CULL_PAD := 260.0


func _ready() -> void:
	_moss_layer = Node2D.new()
	_moss_layer.name = "Moss"
	# Behind the plants, which grow out of it.
	_moss_layer.z_index = -1
	_moss_layer.draw.connect(_draw_moss)
	add_child(_moss_layer)
	# In case the level was built before this node was ready.
	_moss_layer.queue_redraw()


func _process(delta: float) -> void:
	if _plants.is_empty():
		return
	_since_redraw += delta
	if _since_redraw >= 1.0 / REDRAW_HZ:
		_since_redraw = 0.0
		queue_redraw()


## Plant along `bed`, the seabed polyline from the world. `seed` keeps a level's
## planting identical across rebuilds.
##
## `surface_y` is the waterline. The seabed ramps up to meet it at each bank, so
## without it kelp sprouts on the dry beach and tall fronds stand out of the
## water into the sky.
func build(bed: PackedVector2Array, plant_seed: int, surface_y: float = -1e9) -> void:
	_surface_y = surface_y
	var min_y := surface_y + MIN_DEPTH
	_plants.clear()
	_moss.clear()
	if bed.size() < 2:
		queue_redraw()
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = plant_seed
	_spread_moss(bed, min_y, rng)
	if _moss_layer != null:
		_moss_layer.queue_redraw()

	var walked := 0.0
	var next_at := rng.randf() * spacing
	for i in range(bed.size() - 1):
		var a := bed[i]
		var b := bed[i + 1]
		var seg := a.distance_to(b)
		if seg <= 0.001:
			continue
		# Steep faces are bare rock - growth needs something like a ledge.
		var slope: float = absf(b.y - a.y) / seg
		while walked + seg > next_at:
			var t: float = (next_at - walked) / seg
			var at := a.lerp(b, t)
			if rng.randf() < density and slope < 0.75 and at.y > min_y:
				_plants.append(_grow(at, rng))
			next_at += spacing * rng.randf_range(0.55, 1.6)
		walked += seg

	queue_redraw()


## Scatters moss down the rock face, thinning as it goes.
##
## Blobs rather than one polygon: moss meeting bare rock is a ragged, speckled
## edge, and any single shape drawn along the bed comes out as a band. Each blob
## also picks its colour from how deep it sits — pale near the top where the
## light is, dark further down — which is the whole "3D" effect. The rock itself
## is a flat polygon and always will be; this is what gives it a top and a side.
func _spread_moss(bed: PackedVector2Array, min_y: float, rng: RandomNumberGenerator) -> void:
	var step: float = 100.0 / maxf(moss_density, 0.1)
	var walked := 0.0
	var next_at := 0.0

	for i in range(bed.size() - 1):
		var a := bed[i]
		var b := bed[i + 1]
		var seg := a.distance_to(b)
		if seg <= 0.001:
			continue
		# Moss grows thickest where the rock is flat enough to hold it, and
		# barely at all on a face — the same rule the plants use, softened,
		# because moss can cling to more than kelp can.
		var slope: float = absf(b.y - a.y) / seg
		var hold: float = clampf(1.0 - slope * 0.8, 0.12, 1.0)

		while walked + seg > next_at:
			var t: float = (next_at - walked) / seg
			var on_rock := a.lerp(b, t)
			next_at += step * rng.randf_range(0.5, 1.6)
			if on_rock.y <= min_y or rng.randf() > hold:
				continue

			# One patch is a handful of blobs running down from the crust, each
			# smaller and darker than the last.
			var reach: float = moss_reach * rng.randf_range(0.15, 1.0) * hold
			var blobs: int = rng.randi_range(2, 6)
			for n in blobs:
				var depth: float = float(n) / float(blobs)
				var moss := Moss.new()
				moss.at = on_rock + Vector2(
					rng.randf_range(-14.0, 14.0),
					depth * reach + rng.randf_range(0.0, 8.0)
				)
				moss.radius = lerpf(11.0, 3.0, depth) * rng.randf_range(0.7, 1.3)
				# Fades out with depth as well as shrinking, so the bottom of a
				# patch dissolves into the rock instead of stopping dead.
				moss.color = moss_light.lerp(moss_color, depth)
				moss.color.a *= lerpf(1.0, 0.35, depth * depth)
				_moss.append(moss)
		walked += seg


func _grow(at: Vector2, rng: RandomNumberGenerator) -> Plant:
	var p := Plant.new()
	p.base = at
	p.phase = rng.randf() * TAU
	p.lean = rng.randf_range(-0.35, 0.35)

	var roll := rng.randf()
	if roll < 0.42:
		p.kind = Kind.KELP
		p.height = rng.randf_range(90.0, 210.0)
		p.width = rng.randf_range(7.0, 13.0)
		p.blades = rng.randi_range(3, 6)
		p.color = kelp_color
	elif roll < 0.74:
		p.kind = Kind.GRASS
		p.height = rng.randf_range(32.0, 74.0)
		p.width = rng.randf_range(3.0, 5.5)
		p.blades = rng.randi_range(5, 10)
		p.color = grass_color
	else:
		p.kind = Kind.CORAL
		p.height = rng.randf_range(34.0, 72.0)
		p.width = rng.randf_range(9.0, 16.0)
		p.blades = rng.randi_range(3, 6)
		p.color = coral_color if rng.randf() < 0.6 else coral_alt_color

	# Never taller than the water above it.
	p.height = minf(p.height, (at.y - _surface_y) * MAX_FILL)
	return p


## Runs once per level, on the moss layer, not once per frame on this one.
func _draw_moss() -> void:
	for m: Moss in _moss:
		_moss_layer.draw_circle(m.at, m.radius, m.color)


## The visible world rect, in this node's local space.
##
## Taken from the canvas transform rather than from a camera reference, so it is
## right whatever is driving the view and whatever the zoom is.
func _visible_rect() -> Rect2:
	var screen := Rect2(Vector2.ZERO, get_viewport_rect().size)
	var world: Rect2 = get_global_transform_with_canvas().affine_inverse() * screen
	return world if world.size.x > 0.0 else Rect2(-1e9, -1e9, 2e9, 2e9)


func _draw() -> void:
	var view := _visible_rect()
	_view_from = view.position.x - CULL_PAD
	_view_to = view.end.x + CULL_PAD

	var t := float(Time.get_ticks_msec()) / 1000.0 * sway_speed
	for p: Plant in _plants:
		if p.base.x < _view_from or p.base.x > _view_to:
			continue
		match p.kind:
			Kind.KELP:
				_draw_kelp(p, t)
			Kind.GRASS:
				_draw_grass(p, t)
			Kind.CORAL:
				_draw_coral(p)


## One plant stroke: the dark line, then the colour inside it, then a thin
## highlight up one edge. Three passes over the same points, which is what turns
## a polyline into something that looks drawn.
## Not antialiased, deliberately. An antialiased polyline builds a feathered
## border strip as extra geometry — roughly doubling the vertices — and there are
## about a thousand of these on screen. The art is flat cel-shading with hard ink
## edges, so the smoothing was buying nothing that matches the style anyway.
func _stroke(points: PackedVector2Array, color: Color, width: float, lit: bool = false) -> void:
	draw_polyline(points, OUTLINE, width + OUTLINE_WIDTH, false)
	draw_polyline(points, color, width, false)
	if lit and width > 4.0:
		# Offset by a third of the width, so it sits inside the stroke rather
		# than beside it — a highlight that escapes the shape reads as a second
		# frond growing alongside the first.
		var edge := PackedVector2Array()
		for p: Vector2 in points:
			edge.append(p + Vector2(-width * 0.24, 0.0))
		draw_polyline(edge, color.lightened(SHEEN), width * 0.28, false)


## A stalk bending along its length. The sway is scaled by height up the stalk,
## so the holdfast stays put and only the tip really travels - which is what
## sells it as anchored rather than sliding.
func _draw_kelp(p: Plant, t: float) -> void:
	for b in p.blades:
		var offset: float = (float(b) - float(p.blades - 1) * 0.5) * p.width * 1.6
		var h: float = p.height * (1.0 - 0.16 * float(b % 3))
		# Each frond splays a different way, or the clump reads as one flat comb.
		var splay: float = (float(b) - float(p.blades - 1) * 0.5) * 0.22
		var points := PackedVector2Array()
		var steps := 9
		for i in steps + 1:
			var f: float = float(i) / float(steps)
			# Sway scales with the plant's own height, so tall kelp arcs and
			# short kelp barely moves. A fixed amplitude made everything look
			# rigid, because 13 units of travel is nothing on a 200-unit frond.
			var bend: float = sin(t + p.phase + f * 1.9 + float(b) * 0.5) * h * 0.16 * f * f
			var curve: float = splay * h * f * f
			points.append(p.base + Vector2(offset + bend + curve + p.lean * h * f, -h * f))
		_stroke(points, p.color, maxf(p.width * (1.0 - 0.18 * float(b)), 2.5), true)
		# A bladder at the tip, the way real kelp carries its float. It is the
		# detail that most says "kelp" rather than "green line".
		if p.width > 8.0:
			var tip: Vector2 = points[points.size() - 1]
			draw_circle(tip, p.width * 0.62 + OUTLINE_WIDTH * 0.5, OUTLINE)
			draw_circle(tip, p.width * 0.62, p.color.lightened(SHEEN * 0.6))


func _draw_grass(p: Plant, t: float) -> void:
	for b in p.blades:
		var offset: float = (float(b) - float(p.blades - 1) * 0.5) * p.width * 2.2
		var h: float = p.height * randf_seeded(p.phase + float(b))
		var tip := p.base + Vector2(
			offset + sin(t * 1.4 + p.phase + float(b)) * 6.0 + p.lean * h,
			-h
		)
		var mid := p.base + Vector2(offset * 0.7 + p.lean * h * 0.3, -h * 0.55)
		# Tapered: a blade that ends as bluntly as it starts looks like a strip
		# of tape. Drawn as two strokes rather than a polygon so it can keep the
		# same outline treatment as everything else.
		var blade := PackedVector2Array([p.base + Vector2(offset, 0), mid, tip])
		_stroke(blade, p.color, p.width)
		draw_polyline(
			PackedVector2Array([mid, tip]), p.color, maxf(p.width * 0.45, 1.2), true
		)


## Coral is rigid - it is the one thing down here that does not move, which
## makes the moving things read as moving.
func _draw_coral(p: Plant) -> void:
	var foot := p.base + Vector2(0, -p.width * 0.4)
	draw_circle(foot, p.width * 1.1 + OUTLINE_WIDTH * 0.6, OUTLINE)
	draw_circle(foot, p.width * 1.1, p.color)
	for b in p.blades:
		var spread: float = (float(b) - float(p.blades - 1) * 0.5) / maxf(float(p.blades), 1.0)
		var dir := Vector2(spread * 1.5, -1.0).normalized()
		var arm_h: float = p.height * (0.7 + 0.3 * randf_seeded(p.phase + float(b) * 3.0))
		var knee := p.base + dir * arm_h * 0.55 + Vector2(spread * 8.0, 0)
		var tip := p.base + dir * arm_h
		_stroke(PackedVector2Array([p.base, knee, tip]), p.color, p.width * 0.55)
		draw_circle(tip, p.width * 0.42 + OUTLINE_WIDTH * 0.5, OUTLINE)
		draw_circle(tip, p.width * 0.42, p.color.lightened(SHEEN))


## Deterministic 0.55..1.0 from a float, so per-blade variation survives a
## rebuild without storing a value for every blade.
func randf_seeded(v: float) -> float:
	return 0.55 + 0.45 * fract(sin(v * 12.9898) * 43758.5453)


func fract(v: float) -> float:
	return v - floor(v)
