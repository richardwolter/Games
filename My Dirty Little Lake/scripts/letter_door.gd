## The pond the letter's "Start cleaning" door floats on (2026-10-07, `/grill-me` with
## Richard, picked A off `tools/last_door_mockup.png`): a strip of clean lake water under the
## plank and out past both its ends, reeds and cattails standing at the ends, a pad and a lily
## on the water, a bottle and a can bobbing by its corners.
##
## **The water runs behind the whole plank, not only under it** (Richard, on the mockup: the
## paper showed through the plank's bites). The built border's bites are real holes, so what
## shows through them is whatever is drawn behind the button, and that is the lake now.
##
## **Alive on the lake's own rules**: the water's bands and foam lip step at `PIXEL_FPS`, the
## pieces and the pads bob a whole art pixel on that clock, the reeds lean a whole art pixel
## at their tops on the water's rhythm (`Flora`'s sway, by rows). A hover on the door kicks
## it: two foam rings run out from under the plank, the pieces bob two art pixels and the
## reeds swing, settling over `KICK_TIME`.
##
## Drawn behind the door (a sibling before it in the tree), in design pixels, one art pixel
## to `ART` of them: the pack art at its own grain, twice the paper's.
class_name LetterDoor
extends Control

const ART := 2.0
const PIXEL_FPS := 8.0
## The pool round the door, in design px off the door's box: how far past each end it runs,
## how far down the plank its open water starts, and how far under the plank it reaches.
const REACH := 78.0
const STRIP_FROM := 30.0
const UNDER := 14.0
## What stands round it, off the door's box: [sheet, name, x, y, flip, cut, kind]. `x` is off
## the door's left edge when negative and off its right edge when positive; `y` is the foot,
## down from the door's foot. `cut` is how much of a floating piece shows over the water.
const DRESS := [
	[&"flora", "pk_reed_7", -66.0, -8.0, false, 1.0, &"reed"],
	[&"flora", "pk_reed_14", -30.0, -6.0, false, 1.0, &"reed"],
	[&"flora", "pk_reed_2", 66.0, -8.0, true, 1.0, &"reed"],
	[&"flora", "pk_reed_3", 30.0, -6.0, true, 1.0, &"reed"],
	[&"flora", "pk_pad_0", -50.0, 11.0, false, 1.0, &"float"],
	[&"flora", "lily_pink", 42.0, 12.0, false, 1.0, &"float"],
	[&"lake", "plastic_bottle1", -16.0, 9.0, false, 0.7, &"float"],
	[&"lake", "metal_can2", 16.0, 10.0, true, 0.7, &"float"],
]
## A hover's kick, and how long it takes to settle.
const KICK_TIME := 0.9
const RING_MOST := 46.0

## The door the pond is laid round, in this node's coordinates.
var door := Rect2()

var _clock := 0.0
var _kick := 0.0
var _flora: Texture2D
var _lake: Texture2D
var _regions := {}
var _water: Array[Color] = []
var _foam := Color.WHITE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_flora = load("res://assets/flora.png") as Texture2D
	_lake = load("res://assets/lake_objects.png") as Texture2D
	var flora: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/flora.json"))
	for name: String in flora:
		var full: Array = flora[name]["full"]
		_regions[&"flora/" + name] = Rect2(full[0], full[1], full[2], full[3])
	var pieces: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/pieces.json"))
	for piece: Dictionary in pieces["pieces"]:
		if String(piece.get("sheet", "")) == "lake_objects":
			var r: Array = piece["region"]
			_regions[&"lake/" + String(piece["name"])] = Rect2(r[0], r[1], r[2], r[3])
	var pal := Palette.master()
	if pal != null:
		_water = [pal.water_clean_deep, pal.water_clean_mid, pal.water_clean,
			pal.water_clean_shallow, pal.water_clean_light]
		_foam = pal.foam
	else:
		_water = [Color(0.173, 0.302, 0.431), Color(0.255, 0.42, 0.573), Color(0.353, 0.525, 0.678),
			Color(0.498, 0.655, 0.776), Color(0.769, 0.859, 0.91)]


## A hover on the door: the water answers it.
func kick() -> void:
	_kick = 1.0


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_clock += delta
	_kick = maxf(_kick - delta / KICK_TIME, 0.0)
	queue_redraw()


func _snap(v: float) -> float:
	return floorf(v / ART) * ART


func _step() -> int:
	return int(floorf(_clock * PIXEL_FPS))


func _draw() -> void:
	if door.size == Vector2.ZERO or _water.is_empty():
		return
	_draw_pool()
	_draw_rings()
	for item: Array in DRESS:
		_draw_item(item)


## The pool: behind the whole plank, then out past its ends in a strip that rounds off at
## both ends, in whole art pixels, lit along the top of the open water.
func _draw_pool() -> void:
	var step := _step()
	var left := _snap(door.position.x - REACH)
	var right := _snap(door.end.x + REACH)
	var top := _snap(door.position.y + STRIP_FROM)
	var bottom := _snap(door.end.y + UNDER)
	# Behind the plank, where only its bites show it.
	draw_rect(Rect2(door.position, Vector2(door.size.x, top - door.position.y)).grow_individual(-2.0, -2.0, -2.0, 0.0),
		_water[2], true)
	var rows := int((bottom - top) / ART)
	for r in rows:
		var y := top + float(r) * ART
		var edge := mini(r, rows - 1 - r)
		var inset := float(maxi(0, 3 - edge)) * 2.0 * ART
		var x := left + inset
		while x < right - inset:
			var cell := int(x / ART)
			var shade := _water[1]
			if r == 0:
				shade = _water[3]
			elif float(r) < float(rows) * 0.45:
				shade = _water[2]
			elif r == rows - 1:
				shade = _water[0]
			# A band of the next step up drifting along the strip, the lake's band rule.
			if r > 0 and r < rows - 1 and posmod(cell + r * 3 - step, 23) == 0:
				shade = _water[3]
			draw_rect(Rect2(x, y, ART, ART), shade, true)
			x += ART
	# A torn foam lip along the top of the open water, re-torn on the clock.
	var x := left + 6.0 * ART
	while x < right - 6.0 * ART:
		var cell := int(x / ART)
		if posmod(cell * 7 + (step / 3) * 5, 5) != 0:
			draw_rect(Rect2(x, top, ART, ART), _foam, true)
		x += ART


## A hover's foam rings, out from under the plank's two lower corners, on the water only.
func _draw_rings() -> void:
	if _kick <= 0.0:
		return
	var grow := (1.0 - _kick) * RING_MOST
	var top := _snap(door.position.y + STRIP_FROM)
	var bottom := _snap(door.end.y + UNDER)
	var ink := Color(_foam, _kick)
	for corner: Vector2 in [Vector2(door.position.x, door.end.y), Vector2(door.end.x, door.end.y)]:
		var reach := Vector2(10.0 + grow, (10.0 + grow) * 0.35)
		for i in 32:
			var at := corner + Vector2(cos(TAU * i / 32.0), sin(TAU * i / 32.0)) * reach
			at = Vector2(_snap(at.x), _snap(at.y))
			if at.y < top or at.y >= bottom or (at.x > door.position.x and at.x < door.end.x and at.y < door.end.y):
				continue
			draw_rect(Rect2(at, Vector2(ART, ART)), ink, true)


func _draw_item(item: Array) -> void:
	var key := StringName(String(item[0]) + "/" + String(item[1]))
	if not _regions.has(key):
		return
	var region: Rect2 = _regions[key]
	var sheet := _flora if item[0] == &"flora" else _lake
	var off := float(item[2])
	var foot_x := (door.position.x + off) if off < 0.0 else (door.end.x + off)
	var foot_y := door.end.y + float(item[3])
	var flip := bool(item[4])
	var cut := float(item[5])
	var size := region.size * ART
	var phase := int(absf(off))
	if item[6] == &"float":
		# A bob of a whole art pixel on the clock, two while the kick is fresh.
		var bob := 1.0 if posmod(_step() + phase, 4) < 2 else 0.0
		if _kick > 0.4:
			bob *= 2.0
		var shown := Rect2(region.position, Vector2(region.size.x, roundf(region.size.y * cut)))
		var at := Vector2(_snap(foot_x - size.x * 0.5), _snap(foot_y - shown.size.y * ART) + bob * ART)
		var dest := Rect2(at, shown.size * ART)
		# Mirrored by turning the canvas over: a negative-width rect does not flip a region.
		if flip:
			draw_set_transform(Vector2(at.x * 2.0 + dest.size.x, 0.0), 0.0, Vector2(-1.0, 1.0))
		draw_texture_rect_region(sheet, dest, shown)
		draw_set_transform(Vector2.ZERO)
		return
	# A reed, by rows: its top leans a whole art pixel with the water's rhythm, further while
	# the kick lasts, the lean easing out to nothing at its foot.
	var lean := sin(_clock * 1.6 + float(phase) * 0.37) * (1.0 + 2.0 * _kick)
	var at := Vector2(_snap(foot_x - size.x * 0.5), _snap(foot_y - size.y))
	var rows := int(region.size.y)
	for r in rows:
		var shift := roundf(lean * (1.0 - float(r) / float(rows))) * ART
		var src := Rect2(region.position + Vector2(0.0, r), Vector2(region.size.x, 1.0))
		var row_at := at + Vector2(shift, float(r) * ART)
		if flip:
			draw_set_transform(Vector2(row_at.x * 2.0 + size.x, 0.0), 0.0, Vector2(-1.0, 1.0))
			draw_texture_rect_region(sheet, Rect2(row_at, Vector2(size.x, ART)), src)
			draw_set_transform(Vector2.ZERO)
		else:
			draw_texture_rect_region(sheet, Rect2(row_at, Vector2(size.x, ART)), src)
