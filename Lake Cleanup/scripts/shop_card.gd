extends Control
## A shop board's head card as a small scene of the game (2026-09-26, `/grill-me` with
## Richard): the net over filthy water full of rubbish, the ferry on clean water, the four
## dogs running over a strip of lawn by the lake, and the luck board's coin between the
## recycle box catching pieces and the pigeon's head sliding in off the edge.
##
## Drawn only, nothing read back. One node a board, a child of `ShopSkin` kept **first** in
## its children, so the ferry's hull and wake and the net's mesh and collar (the skin's own
## nodes) draw over the scene. `clip_contents` is what lets a dog or the pigeon's head run
## past the card's edge. Always moving, by decision ("alive is the point"); every speed and
## count here is a first guess for Richard's eye.

## Which scene: &"net", &"boat", &"dog", &"luck".
var kind: StringName = &""
## The lake's rubbish as `{sheet, region}` rows, lent by `Lake` (the wash room's list).
var rubbish: Array = []
## The pieces the net lies over, drawn by the card so the mesh node covers them.
var catch: Array = []
## Where the catch lies, as fractions of the net's drawn box about its middle, and that box.
var catch_at: Array = []
var catch_box := Rect2()
var catch_scale := 2.0
const DogArt := preload("res://scripts/dog_art.gd")
const HudButtons := preload("res://scripts/hud_buttons.gd")

## The skin, for the coin's toss.
var skin: Node = null

## Art pixel: every scene is drawn on this grid.
const PIXEL := 2.0
## Rubbish afloat on the net's filthy card and on the ferry's clean one.
## Six on the net's card (2026-09-27, was sixteen): the net is what the card is about. The
## boats' card carries none now, water and ferry only.
const DIRTY_PIECES := 6
const CLEAN_PIECES := 0
## How much the water behind the net is lifted towards its lightest step, so the black mesh
## stands off it (2026-09-27).
const NET_WATER_LIFT := 0.45
## The luck box's heap: what it starts with, and the most it grows to before starting over.
const HEAP_START := 4
const HEAP_MOST := 9
## The dogs' strip: far bank, lake band, lawn, as shares of the card's height.
const BANK_TO := 0.26
const LAKE_TO := 0.50
## A dog's run: pixels a second, and the wait off frame before it comes back.
const DOG_SPEED := Vector2(70.0, 120.0)
const DOG_WAIT := Vector2(0.4, 2.6)
const DOG_TALL := Vector2(15.0, 21.0)
## The luck card: a piece into the box every `DROP_EVERY`, taking `DROP_FLIGHT`; the head
## in, held and out over `HEAD_EVERY`.
const DROP_EVERY := 1.5
const DROP_FLIGHT := 0.6
const HEAD_EVERY := 6.0
const HEAD_IN := 0.35
const HEAD_HOLD := 1.4
const HEAD_LEAN := 54.0
const BOX_ART := "res://assets/Recycle_Box.png"
## The box art's mouth: its middle row, measured from the top (`Dropoff.BOX_TOP`).
const BOX_MOUTH := 8.0
const BOX_SCALE := 1.5

var _time := 0.0
var _roll := RandomNumberGenerator.new()
var _spots: Array = []
var _dogs: Array = []
var _box: Texture2D
var _box_front: Texture2D
var _head: Texture2D
var _ramp_dirty: Array = []
var _ramp_clean: Array = []
var _grass: Array = []
var _bank: Array = []


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_roll.seed = hash(kind)
	var pal := Palette.master()
	if pal != null:
		_ramp_dirty = [pal.water_dirty_deep, pal.water_dirty_mid, pal.water_dirty_shallow, pal.water_dirty_light]
		_ramp_clean = [pal.water_clean_deep, pal.water_clean_mid, pal.water_clean_shallow, pal.water_clean_light]
		_grass = [pal.grass_dark, pal.grass_light]
		_bank = [pal.grass_dark.darkened(0.45), pal.grass_dark.darkened(0.25), pal.sand]
	else:
		_ramp_dirty = [Color(0.16, 0.2, 0.1), Color(0.22, 0.28, 0.12), Color(0.3, 0.36, 0.16), Color(0.4, 0.46, 0.22)]
		_ramp_clean = [Color(0.1, 0.3, 0.5), Color(0.15, 0.4, 0.6), Color(0.25, 0.55, 0.7), Color(0.5, 0.75, 0.85)]
		_grass = [Color(0.2, 0.4, 0.15), Color(0.35, 0.55, 0.2)]
		_bank = [Color(0.08, 0.2, 0.08), Color(0.12, 0.28, 0.1), Color(0.8, 0.7, 0.5)]
	if ResourceLoader.exists(BOX_ART):
		_box = load(BOX_ART)
		_box_front = Yard._cut_front(Art.image(BOX_ART))
	if ResourceLoader.exists(PigeonPop.ART):
		_head = load(PigeonPop.ART)
	for i in 24:
		_spots.append({"x": _roll.randf(), "y": _roll.randf(), "kind": _roll.randi(), "phase": _roll.randf() * TAU})
	for slot in DogArt.BREEDS.size():
		_dogs.append(_new_run(slot, true))


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	if kind == &"dog":
		_step_dogs(delta)
	queue_redraw()


func _draw() -> void:
	var box := Rect2(Vector2.ZERO, size)
	match kind:
		&"net":
			_draw_water(box, _lifted(_ramp_dirty), true)
			_draw_afloat(box, DIRTY_PIECES)
			_draw_catch()
		&"boat":
			_draw_water(box, _ramp_clean, false)
		&"dog":
			_draw_strip(box)
		&"luck":
			_draw_luck(box)


## The net's water, each step lifted towards the lightest so the black mesh reads on it.
func _lifted(ramp: Array) -> Array:
	var out: Array = []
	for c: Color in ramp:
		out.append(c.lerp(ramp[3], NET_WATER_LIFT))
	return out


## Flat bands of a four-step ramp, deep at the top (far) to shallow at the foot, with
## short streaks one step up drifting sideways and blinking in and out — the wash room's
## water in miniature. Dirty water also carries scum blotches.
func _draw_water(box: Rect2, ramp: Array, scum: bool) -> void:
	draw_rect(box, ramp[0], true)
	var bands := 5
	for b in bands:
		var t := float(b) / float(bands)
		var y := _snap(box.position.y + box.size.y * (0.18 + t * 0.82))
		var shade: Color = ramp[mini(1 + int(t * 2.0), 2)]
		draw_rect(Rect2(box.position.x, y, box.size.x, box.end.y - y), shade.lerp(ramp[0], 0.5 - t * 0.4), true)
	var step := floorf(_time * 8.0) / 8.0
	for i in 18:
		var s: Dictionary = _spots[i]
		var speed := 4.0 + 6.0 * float(s["y"])
		var x := fposmod(float(s["x"]) * box.size.x + step * speed, box.size.x + 30.0) - 15.0
		var y := box.size.y * (0.1 + 0.85 * float(s["y"]))
		var on := sin(step * 1.3 + float(s["phase"])) > -0.3
		if not on:
			continue
		var wide := _snap(6.0 + 10.0 * float(s["x"]))
		draw_rect(Rect2(box.position.x + _snap(x), box.position.y + _snap(y), wide, PIXEL), ramp[3] if not scum else ramp[2], true)
	if scum:
		var foam := Color(0.55, 0.55, 0.36, 0.55)
		var pal := Palette.master()
		if pal != null:
			foam = Color(pal.foam_dirty, 0.6)
		for i in range(18, 24):
			var s: Dictionary = _spots[i]
			var at := Vector2(float(s["x"]) * box.size.x, box.size.y * float(s["y"]))
			at.x = fposmod(at.x + step * 3.0, box.size.x)
			at += box.position
			for k in 5:
				var off := Vector2(float((k * 7 + i) % 5) - 2.0, float((k * 3 + i) % 3) - 1.0) * PIXEL
				draw_rect(Rect2((at + off).snapped(Vector2.ONE * PIXEL), Vector2.ONE * PIXEL), foam, true)


## Rubbish afloat: the lake's own sprites, bobbing a pixel on a stepped clock, their feet
## cut a pixel into the water.
func _draw_afloat(box: Rect2, count: int) -> void:
	if rubbish.is_empty():
		return
	var step := floorf(_time * 4.0)
	var order: Array = []
	for i in mini(count, _spots.size()):
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return float(_spots[a]["y"]) < float(_spots[b]["y"]))
	for i: int in order:
		var s: Dictionary = _spots[i]
		var art: Dictionary = rubbish[int(s["kind"]) % rubbish.size()]
		var region: Rect2 = art["region"]
		var drawn := region.size * PIXEL
		var bob := PIXEL if int(step + i) % 2 == 0 else 0.0
		var at := Vector2(
			_snap(float(s["x"]) * (box.size.x - drawn.x)),
			_snap(box.size.y * (0.15 + 0.75 * float(s["y"])) - drawn.y * 0.5) + bob
		)
		draw_texture_rect_region(art["sheet"], Rect2(at, drawn), region)


func _draw_catch() -> void:
	var here := catch_box.position + catch_box.size * 0.5 - position
	for i in mini(catch.size(), catch_at.size()):
		var piece: Dictionary = catch[i]
		var art: Rect2 = piece["region"]
		var drawn := art.size * catch_scale
		var at := here + (catch_at[i] as Vector2) * catch_box.size - drawn * 0.5
		draw_texture_rect_region(piece["sheet"], Rect2(at, drawn), art)


## The dogs' strip: a far bank of dark trees on sand, a band of clean lake (no ferry since
## 2026-09-27), and the lawn the four dogs run across.
func _draw_strip(box: Rect2) -> void:
	var bank_to := _snap(box.size.y * BANK_TO)
	var lake_to := _snap(box.size.y * LAKE_TO)
	draw_rect(Rect2(0.0, 0.0, box.size.x, bank_to), _bank[0], true)
	# Tree crowns: stepped bumps along the top, two tones.
	var x := 0.0
	var k := 0
	while x < box.size.x:
		var wide := _snap(10.0 + float((k * 37) % 9) * 2.0)
		var tall := _snap(6.0 + float((k * 53) % 7) * 2.0)
		draw_rect(Rect2(x, bank_to - tall - PIXEL * 2.0, wide, tall), _bank[1], true)
		draw_rect(Rect2(x + PIXEL, bank_to - tall - PIXEL * 2.0, PIXEL * 2.0, PIXEL), _grass[0], true)
		x += wide - PIXEL
		k += 1
	draw_rect(Rect2(0.0, bank_to - PIXEL * 2.0, box.size.x, PIXEL * 2.0), _bank[2], true)
	_draw_water(Rect2(0.0, bank_to, box.size.x, lake_to - bank_to), _ramp_clean, false)
	draw_rect(Rect2(0.0, lake_to, box.size.x, PIXEL * 2.0), _bank[2], true)
	draw_rect(Rect2(0.0, lake_to + PIXEL * 2.0, box.size.x, box.size.y), _grass[1], true)
	for i in 14:
		var s: Dictionary = _spots[i]
		var at := Vector2(float(s["x"]) * box.size.x, lake_to + PIXEL * 3.0 + float(s["y"]) * (box.size.y - lake_to))
		draw_rect(Rect2(at.snapped(Vector2.ONE * PIXEL), Vector2(PIXEL, PIXEL * 2.0)), _grass[0], true)
	var order: Array = _dogs.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["y"]) < float(b["y"]))
	for dog: Dictionary in order:
		if float(dog["wait"]) > 0.0:
			continue
		var slot := int(dog["slot"])
		var breed := slot
		var pose: StringName = DogArt.gait(slot, false, breed)
		var foot := Vector2(_snap(float(dog["x"])), lake_to + (box.size.y - lake_to) * float(dog["y"]))
		var shade := Color(0.0, 0.0, 0.0, 0.25)
		draw_rect(Rect2(foot.x - float(dog["tall"]) * 0.45, foot.y - PIXEL, float(dog["tall"]) * 0.9, PIXEL * 2.0), shade, true)
		DogArt.stamp(
			self, pose, DogArt.frame_at(pose, float(dog["age"]), breed), foot,
			float(dog["tall"]), float(dog["way"]) < 0.0, 0.0, Color.WHITE, breed
		)


func _step_dogs(delta: float) -> void:
	for i in _dogs.size():
		var dog: Dictionary = _dogs[i]
		if float(dog["wait"]) > 0.0:
			dog["wait"] = float(dog["wait"]) - delta
			continue
		dog["x"] = float(dog["x"]) + float(dog["way"]) * float(dog["speed"]) * delta
		dog["age"] = float(dog["age"]) + delta
		var gone := float(dog["x"]) < -60.0 or float(dog["x"]) > size.x + 60.0
		if gone:
			_dogs[i] = _new_run(int(dog["slot"]), false)


func _new_run(slot: int, first: bool) -> Dictionary:
	var way := 1.0 if _roll.randf() < 0.5 else -1.0
	var y := _roll.randf_range(0.55, 1.0)
	return {
		"slot": slot, "way": way, "y": y,
		# The first runs start somewhere across the card, so it is never empty when opened.
		"x": _roll.randf_range(20.0, 280.0) if first else (-40.0 if way > 0.0 else maxf(size.x, 300.0) + 40.0),
		"speed": _roll.randf_range(DOG_SPEED.x, DOG_SPEED.y),
		"tall": lerpf(DOG_TALL.x, DOG_TALL.y, (y - 0.55) / 0.45),
		"age": _roll.randf() * 2.0,
		"wait": 0.0 if first else _roll.randf_range(DOG_WAIT.x, DOG_WAIT.y),
	}


## The luck card: murky water under all three, the box on the left catching a piece every
## `DROP_EVERY`, the coin tossing in the middle, the pigeon's head leaning in off the right
## edge every `HEAD_EVERY`, the way it pops in on the lake.
func _draw_luck(box: Rect2) -> void:
	_draw_water(box, _ramp_clean, false)
	var middle := box.size * 0.5
	# The box.
	if _box != null:
		var drawn := Vector2(_box.get_width(), _box.get_height()) * BOX_SCALE
		var at := Vector2(_snap(box.size.x * 0.2 - drawn.x * 0.5), _snap(box.size.y - drawn.y - PIXEL * 2.0))
		var mouth := at + Vector2(drawn.x * 0.5, BOX_MOUTH * BOX_SCALE)
		# The box whole, then the heap inside it, then the piece dropping in, then the near
		# walls cut off the art over all of it — Dropoff's front cut — so what is caught is
		# in the box rather than behind it (2026-09-27).
		draw_texture_rect(_box, Rect2(at, drawn), false)
		var drops := int(floorf(_time / DROP_EVERY))
		var t := fposmod(_time, DROP_EVERY) / DROP_FLIGHT
		if not rubbish.is_empty():
			var landed := drops if t >= 1.0 else drops - 1
			var heap := HEAP_START + posmod(landed + 1, HEAP_MOST - HEAP_START + 1)
			for k in heap:
				var art: Dictionary = rubbish[(k * 5 + 3) % rubbish.size()]
				var region: Rect2 = art["region"]
				var size_px := region.size * PIXEL * 0.8
				var spot := mouth + Vector2(
					(float((k * 37) % 11) / 10.0 - 0.5) * drawn.x * 0.45,
					BOX_SCALE * (5.0 - float(k) * 0.5)
				)
				draw_texture_rect_region(art["sheet"], Rect2((spot - size_px * 0.5).snapped(Vector2.ONE * PIXEL), size_px), region)
			# The piece in the air, arcing in from off the left edge and down into the heap.
			if t < 1.0:
				var art: Dictionary = rubbish[drops % rubbish.size()]
				var region: Rect2 = art["region"]
				var into := mouth + Vector2(0.0, BOX_SCALE * 4.0)
				var from := Vector2(-10.0, mouth.y - 10.0)
				var p := from.lerp(into, t) - Vector2(0.0, sin(t * PI) * box.size.y * 0.5)
				var size_px := region.size * PIXEL
				draw_texture_rect_region(art["sheet"], Rect2((p - size_px * 0.5).snapped(Vector2.ONE * PIXEL), size_px), region)
		if _box_front != null:
			draw_texture_rect(_box_front, Rect2(at, drawn), false)
	# The coin.
	if skin != null and skin.has_method(&"toss_share"):
		var side := box.size.y * 0.62
		var coin := Rect2(middle - Vector2.ONE * side * 0.5, Vector2.ONE * side)
		var pose: Vector2 = skin.call(&"toss_pose", skin.call(&"toss_share"))
		coin.position.y -= roundf(pose.y)
		HudButtons.coin_turned(self, coin, Color.WHITE, pose.x)
	# The head: in over `HEAD_IN`, held, out.
	if _head != null:
		var t := fposmod(_time, HEAD_EVERY)
		var out := t - HEAD_IN - HEAD_HOLD
		var share := 0.0
		if t < HEAD_IN:
			share = t / HEAD_IN
		elif out < HEAD_IN:
			share = 1.0 if out < 0.0 else 1.0 - out / HEAD_IN
		share = smoothstep(0.0, 1.0, share)
		if share > 0.0:
			var tall := box.size.y * 0.95
			var drawn := Vector2(_head.get_width(), _head.get_height()) * tall / float(_head.get_height())
			# Faces left as painted; leant so its cut neck lies against the right edge.
			var centre := Vector2(box.size.x + drawn.x * 0.35 - drawn.x * 0.62 * share, box.size.y * 0.55)
			draw_set_transform(centre.round(), deg_to_rad(-HEAD_LEAN), Vector2.ONE)
			draw_texture_rect(_head, Rect2(-drawn * 0.5, drawn), false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _snap(v: float) -> float:
	return floorf(v / PIXEL) * PIXEL
