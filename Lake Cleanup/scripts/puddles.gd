## Puddles on the island while it rains (2026-09-25, see `Weather`).
##
## A few spots of the island's ground, found once off its own layout, fill as a shower goes on
## and dry out after it. Each is a blob of whole art pixels in the clean water's own ramp, and
## what stands beside one — the angler, the dogs, the hut, the pump — is drawn again in it
## upside down (`Mirror`, clipped to the puddles by `clip_children`), flaring white with the
## lightning. Nothing is saved: a load is dry ground.
class_name Puddles
extends Node2D

## How many, how big at their fullest (tiles across the plane, before the 2:1), and how far
## apart and off the island's things they are laid.
const COUNT := 3
const SIZE := Vector2(1.3, 2.2)
const APART := 4.5
const OFF_WATER := 40.0
const OFF_SHED := 0.8
const OFF_CRATE := 0.6

## Seconds of full rain to fill, and seconds to dry after it stops.
const FILL := 35.0
const DRY := 60.0

## Whole art pixels.
const PIXEL := 2.0

## How strongly what stands beside a puddle shows in it.
const MIRROR_ALPHA := 0.42
const MIRROR_TINT := Color(0.7, 0.82, 1.0)

## What the hut's picture is, for its reflection: Lake hands {texture, rect} per thing.
var statics: Callable
## The walkers: Array of nodes with `reflect_on(CanvasItem)`.
var walkers: Callable
var crate_tile := Vector2.INF

var wet: float = 0.0

## The sand: how wet it is (darkens it through `Ground.set_wet`), and the dark spot each drop
## leaves on it before the whole beach catches up. Seconds to soak, to dry, and how long a
## spot shows.
var sand_wet: float = 0.0
var grounds: Array = []
const SOAK := 25.0
const SAND_DRY := 90.0
const MARK_LIFE := 7.0
const MARKS_MOST := 600
var _marks := PackedVector2Array()
var _mark_age := PackedFloat32Array()
var _mark_ink: Color
var _pushed_wet := -1.0
var _flash: float = 0.0
var _spots := PackedVector2Array()
var _sizes := PackedFloat32Array()
## Each puddle's cells, laid once: where (world px) and how wet the ground must be before that
## cell holds water (0 the middle, 1 the fullest edge). Growing and drying just move the line.
var _cells: Array[PackedVector2Array] = []
var _reach: Array[PackedFloat32Array] = []

## The shape: a few overlapping lobes, their edge pushed in and out by a coarse noise, so a
## puddle is a spill with bays and arms rather than an oval. `LOBES` how many, `WOBBLE` how
## far the noise moves the edge, `WOBBLE_CELL` how coarse (art px).
const LOBES := Vector2i(3, 6)
const WOBBLE := 0.45
const WOBBLE_CELL := 5.0
var _ripples: Array = []
var _body: Color
var _deep: Color
var _rim: Color
var _mirror: Mirror


class Mirror extends Node2D:
	var owner_puddles: Puddles

	func _draw() -> void:
		owner_puddles.draw_reflections(self)


func _ready() -> void:
	clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var palette := Palette.master()
	if palette != null:
		# Rain water on the ground, not a pond: the clean ramp let see-through so the ground
		# it lies on darkens it rather than it being painted blue over the top.
		_body = Color(palette.water_clean_light, 0.85)
		_deep = Color(palette.water_clean_mid, 0.7)
		_rim = palette.water_clean_light
	else:
		_body = Color(0.45, 0.6, 0.7)
		_deep = Color(0.35, 0.5, 0.62)
		_rim = Color(0.7, 0.8, 0.85)
	_mark_ink = Color(palette.sand * Color(0.62, 0.6, 0.62), 0.9) if palette != null 		else Color(0.45, 0.4, 0.32, 0.9)
	_mirror = Mirror.new()
	_mirror.owner_puddles = self
	_mirror.modulate = Color(MIRROR_TINT, MIRROR_ALPHA)
	add_child(_mirror)
	_lay()


## The spots: darts over the island from a fixed seed, kept on dry ground, off the water's
## edge, off the hut, the crate and the pump, and apart from each other.
func _lay() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90125
	var centre := Iso.ISLAND_CENTRE
	for _try in 600:
		if _spots.size() >= COUNT:
			break
		var t := centre + Vector2(
			rng.randf_range(-Iso.ISLAND_RADIUS.x, Iso.ISLAND_RADIUS.x),
			rng.randf_range(-Iso.ISLAND_RADIUS.y, Iso.ISLAND_RADIUS.y)
		)
		if not may_lie(t):
			continue
		var clear := true
		for other in _spots:
			if other.distance_to(t) < APART:
				clear = false
				break
		if not clear:
			continue
		_spots.append(t)
		_sizes.append(rng.randf_range(SIZE.x, SIZE.y))
		_shape(_spots.size() - 1, rng)


## One puddle's cells: lobes scattered about the spot, each cell's reach its nearest lobe's
## scaled distance bent by the noise, dropped where the ground may not hold a puddle.
func _shape(k: int, rng: RandomNumberGenerator) -> void:
	var size := _sizes[k]
	var lobes: Array[Vector3] = []
	for _i in rng.randi_range(LOBES.x, LOBES.y):
		var off := Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5)) * size
		lobes.append(Vector3(off.x, off.y, rng.randf_range(0.3, 0.6) * size))
	lobes[0] = Vector3(0.0, 0.0, 0.55 * size)
	var middle := Iso.tile_to_world(_spots[k].x, _spots[k].y)
	var span := size * Iso.TILE_W
	var cols := int(ceil(span / PIXEL))
	var rows := int(ceil(span * 0.5 / PIXEL))
	var cells := PackedVector2Array()
	var reach := PackedFloat32Array()
	for gy in range(-rows, rows + 1):
		for gx in range(-cols, cols + 1):
			var at := (middle + Vector2(gx, gy) * PIXEL).snapped(Vector2(PIXEL, PIXEL))
			var t := Iso.world_to_tile(at)
			var best := INF
			for lobe in lobes:
				var d := (t - _spots[k] - Vector2(lobe.x, lobe.y)).length() / lobe.z
				best = minf(best, d)
			best *= 1.0 + WOBBLE * (_noise(k, float(gx) / WOBBLE_CELL, float(gy) / WOBBLE_CELL) - 0.5)
			if best > 1.0 or not may_lie(t):
				continue
			cells.append(at)
			reach.append(best)
	_cells.append(cells)
	_reach.append(reach)


## Smooth value noise on a coarse grid, 0 to 1.
func _noise(k: int, x: float, y: float) -> float:
	var ix := floori(x)
	var iy := floori(y)
	var fx := smoothstep(0.0, 1.0, x - ix)
	var fy := smoothstep(0.0, 1.0, y - iy)
	var top := lerpf(_hash(k, ix, iy), _hash(k, ix + 1, iy), fx)
	var low := lerpf(_hash(k, ix, iy + 1), _hash(k, ix + 1, iy + 1), fx)
	return lerpf(top, low, fy)


## Could a puddle lie on this tile spot.
func may_lie(t: Vector2) -> bool:
	# On the grass only (Richard): sand drinks the rain and darkens instead (`sand_wet`).
	if not Iso.on_lawn(t) or Iso.past_water(t) > -OFF_WATER:
		return false
	if Iso.in_shed(t.x, t.y, OFF_SHED):
		return false
	if crate_tile != Vector2.INF and Yard.covers(crate_tile, t, OFF_CRATE):
		return false
	if Pump.tile != Vector2.INF and Pump.covers(t, OFF_CRATE):
		return false
	return true


func spots() -> PackedVector2Array:
	return _spots


## One weather frame: fill under rain, dry without it, and remember the flash.
func tick(rain: float, flash: float, delta: float) -> void:
	var was := wet
	if rain > 0.3:
		wet = minf(wet + delta * rain / FILL, 1.0)
	else:
		wet = maxf(wet - delta / DRY, 0.0)
	if rain > 0.3:
		sand_wet = minf(sand_wet + delta * rain / SOAK, 1.0)
	else:
		sand_wet = maxf(sand_wet - delta / SAND_DRY, 0.0)
	if absf(sand_wet - _pushed_wet) > 0.01 or (sand_wet == 0.0 and _pushed_wet != 0.0):
		_pushed_wet = sand_wet
		for ground in grounds:
			if is_instance_valid(ground):
				ground.set_wet(sand_wet)
	var marks_were := _marks.size()
	var m := 0
	while m < _marks.size():
		_mark_age[m] += delta
		if _mark_age[m] >= MARK_LIFE:
			_marks.remove_at(m)
			_mark_age.remove_at(m)
			continue
		m += 1
	var flashed := flash != _flash
	_flash = flash
	var i := 0
	while i < _ripples.size():
		_ripples[i][1] += delta
		if _ripples[i][1] > 0.45:
			_ripples.remove_at(i)
			continue
		i += 1
	visible = wet > 0.0 or not _marks.is_empty()
	if visible and (was != wet or flashed or not _ripples.is_empty() or marks_were > 0):
		queue_redraw()
	if visible:
		_mirror.queue_redraw()


## A drop landing on the island: a ring if it fell in a puddle.
func hit(at: Vector2) -> void:
	var sand := Iso.world_to_tile(at)
	if not Iso.on_lawn(sand) and _marks.size() < MARKS_MOST:
		_marks.append(at)
		_mark_age.append(0.0)
		visible = true
	if wet <= 0.05 or _ripples.size() > 40:
		return
	var t := Iso.world_to_tile(at)
	for k in _spots.size():
		if _spots[k].distance_to(t) < _sizes[k] * wet * 0.6:
			_ripples.append([at, 0.0])
			return


func _draw() -> void:
	var cell := Vector2(PIXEL, PIXEL)
	var body := _body.lerp(Color.WHITE, _flash * 0.6)
	# The drops' spots on the sand, fading as the beach darkens under them.
	for i in _marks.size():
		var fade := 1.0 - _mark_age[i] / MARK_LIFE
		var ink := Color(_mark_ink, _mark_ink.a * fade * (1.0 - sand_wet * 0.6))
		draw_rect(Rect2(_marks[i].snapped(cell), cell), ink)
	for k in _cells.size():
		var cells := _cells[k]
		var reach := _reach[k]
		for i in cells.size():
			if reach[i] <= wet:
				draw_rect(Rect2(cells[i], cell), body)
	for ring: Array in _ripples:
		var age: float = ring[1]
		var span := 3.0 + age * 18.0
		var ink := Color(_rim, 0.8 * (1.0 - age / 0.45))
		for step in 12:
			var angle := TAU * float(step) / 12.0
			var at: Vector2 = ring[0] + Vector2(cos(angle), sin(angle) * 0.5) * span
			draw_rect(Rect2(at.snapped(cell), cell), ink)


func _hash(k: int, x: int, y: int) -> float:
	var h := hash(Vector3i(k * 7919 + x, y, k))
	return float(h % 1000) / 1000.0


## What stands by the puddles, upside down about its own feet. Called from the clipped child,
## so only what falls inside a puddle shows.
func draw_reflections(on: CanvasItem) -> void:
	if statics.is_valid():
		for item: Dictionary in statics.call():
			var tex: Texture2D = item.get("texture")
			var box: Rect2 = item.get("rect")
			if tex == null:
				continue
			on.draw_set_transform(Vector2(0.0, box.end.y * 2.0), 0.0, Vector2(1.0, -1.0))
			on.draw_texture_rect(tex, box, false)
	if walkers.is_valid():
		for walker: Node2D in walkers.call():
			if is_instance_valid(walker) and walker.visible and walker.has_method(&"reflect_on"):
				on.draw_set_transform(walker.position, 0.0, Vector2(1.0, -1.0))
				walker.call(&"reflect_on", on)
	on.draw_set_transform(Vector2.ZERO)
