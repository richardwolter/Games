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
const COUNT := 6
const SIZE := Vector2(0.5, 1.0)
const APART := 2.6
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
var _flash: float = 0.0
var _spots := PackedVector2Array()
var _sizes := PackedFloat32Array()
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
		_body = Color(palette.water_clean_shallow, 0.6)
		_deep = Color(palette.water_clean_mid, 0.7)
		_rim = palette.water_clean_light
	else:
		_body = Color(0.45, 0.6, 0.7)
		_deep = Color(0.35, 0.5, 0.62)
		_rim = Color(0.7, 0.8, 0.85)
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


## Could a puddle lie on this tile spot.
func may_lie(t: Vector2) -> bool:
	if not Iso.on_island_ground(t) or Iso.past_water(t) > -OFF_WATER:
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
	var flashed := flash != _flash
	_flash = flash
	var i := 0
	while i < _ripples.size():
		_ripples[i][1] += delta
		if _ripples[i][1] > 0.45:
			_ripples.remove_at(i)
			continue
		i += 1
	visible = wet > 0.0
	if visible and (was != wet or flashed or not _ripples.is_empty()):
		queue_redraw()
	if visible:
		_mirror.queue_redraw()


## A drop landing on the island: a ring if it fell in a puddle.
func hit(at: Vector2) -> void:
	if wet <= 0.05 or _ripples.size() > 40:
		return
	var t := Iso.world_to_tile(at)
	for k in _spots.size():
		if _spots[k].distance_to(t) < _sizes[k] * wet * 0.5:
			_ripples.append([at, 0.0])
			return


func _draw() -> void:
	var cell := Vector2(PIXEL, PIXEL)
	var body := _body.lerp(Color.WHITE, _flash * 0.6)
	var deep := _deep.lerp(Color.WHITE, _flash * 0.5)
	for k in _spots.size():
		var middle := Iso.tile_to_world(_spots[k].x, _spots[k].y)
		var across := _sizes[k] * wet * Iso.TILE_W * 0.5
		var tall := across * 0.5
		var cols := int(ceil(across / PIXEL))
		var rows := int(ceil(tall / PIXEL))
		for gy in range(-rows, rows + 1):
			for gx in range(-cols, cols + 1):
				var dx := float(gx) * PIXEL / maxf(across, 1.0)
				var dy := float(gy) * PIXEL / maxf(tall, 1.0)
				# A ragged edge off a hash per cell, fixed per puddle so it does not boil.
				var ragged := 0.82 + 0.18 * _hash(k, gx, gy)
				var reach := dx * dx + dy * dy
				if reach > ragged * ragged:
					continue
				var at := (middle + Vector2(gx, gy) * PIXEL).snapped(cell)
				draw_rect(Rect2(at, cell), deep if reach < 0.35 else body)
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
