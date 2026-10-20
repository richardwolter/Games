## Many bees in one draw: `BeeArt`'s frames laid as textured quads into one triangle array.
##
## The lake's bees (the hive's swarm, crowd and commuters, and the bees at the flowers) are up
## to a hundred a frame, each its own frame of `assets/bees.png`, half of them mirrored. Drawn
## one by one through `BeeArt.draw` a mirrored bee is a `draw_primitive`, which breaks the
## batch; here every bee is four corners with its texture coordinates (swapped across for a bee
## facing left), so the whole lot is one `canvas_item_add_triangle_array` off the sheet, the
## way the flora and the props are drawn.
##
## `at` is the body's middle (BeeArt's anchor) and is snapped to whole world pixels, so a bee
## never stands between two: the sheet is pixel art at one world px a px on the island.
class_name BeeBatch
extends RefCounted

var _points := PackedVector2Array()
var _uvs := PackedVector2Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()


func clear() -> void:
	_points.resize(0)
	_uvs.resize(0)
	_colors.resize(0)
	_indices.resize(0)


func is_empty() -> bool:
	return _indices.is_empty()


## One bee: frame `name`, its body's middle on `at` (snapped to the whole pixel), mirrored when
## `left`, `scale` world px a sheet px.
func add(name: StringName, at: Vector2, left := false, tint := Color.WHITE, scale := 1.0) -> void:
	var sheet := BeeArt.sheet()
	if sheet == null or not BeeArt.has(name) or tint.a <= 0.0:
		return
	var cut := BeeArt.region(name)
	var mark := BeeArt.anchor(name, left)
	var corner := at.floor() - mark * scale
	var size := cut.size * scale
	var whole := Vector2(sheet.get_size())
	var u0 := cut.position.x / whole.x
	var u1 := cut.end.x / whole.x
	var v0 := cut.position.y / whole.y
	var v1 := cut.end.y / whole.y
	if left:
		var swap := u0
		u0 = u1
		u1 = swap
	var base := _points.size()
	_points.append(corner)
	_points.append(corner + Vector2(size.x, 0.0))
	_points.append(corner + size)
	_points.append(corner + Vector2(0.0, size.y))
	_uvs.append(Vector2(u0, v0))
	_uvs.append(Vector2(u1, v0))
	_uvs.append(Vector2(u1, v1))
	_uvs.append(Vector2(u0, v1))
	for n in 4:
		_colors.append(tint)
	_indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))


## A bee by animation and age (`&"mini_fly"`, seconds): the frame `BeeArt.frame_at` picks.
func animate(anim: StringName, age: float, at: Vector2, left := false, tint := Color.WHITE, scale := 1.0) -> void:
	add(BeeArt.frame_name(anim, BeeArt.frame_at(anim, age)), at, left, tint, scale)


## Everything added since `clear`, in one draw on `on`'s canvas item.
func flush(on: CanvasItem) -> void:
	var sheet := BeeArt.sheet()
	if _indices.is_empty() or sheet == null or on == null:
		return
	RenderingServer.canvas_item_add_triangle_array(
		on.get_canvas_item(), _indices, _points, _colors, _uvs,
		PackedInt32Array(), PackedFloat32Array(), sheet.get_rid()
	)
