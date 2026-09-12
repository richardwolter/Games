## The three corner buttons — money, shed, upgrades — drawn in the boards' wood.
##
## They were painted plaques off `assets/ui.png` and `assets/buttons.png` until 2026-09-11:
## a picture in one style beside a shop, a settings board and a shelf drawn in another. Now
## each is the boards' own oak frame round a dark `BOARD` face, and what is on the face is
## the game's own art rather than a painting of it — the ferry, the net and the dog the
## upgrades sell, the hut and the finds the shed holds. The coin is the one thing drawn
## from nothing, because the game has no coin: money here is a figure, not an object.
##
## Static and stateless: HudSkin draws two of these where it lays them out, and the shed's
## copy of the upgrades button (`UiButton`) draws the same one from the same function, so
## the button is one button wherever it turns up. The sprites come in a dictionary the lake
## fills (`Lake._lend_button_art`): `net` and `boat` as `{sheet, region}`, `shed` as a
## texture, `decor` as a list of `{sheet, region}`. A missing entry is skipped, and the
## button still draws its frame and its arrow — the game runs with the art missing rather
## than failing to load, the same bargain every sheet strikes.
##
## No `class_name`, for the reason `style.gd` gives: preloaded, so a headless tool run
## cannot hit a stale class cache.
extends RefCounted

const Style := preload("res://scripts/style.gd")
## Preloaded under its own name rather than reached as the global `DogArt`: this script has
## no `class_name`, and from one the global class is not in scope on a headless tool run.
const Dogs := preload("res://scripts/dog_art.gd")

## The oak round a button and how many bites it takes per side. Thinner than a board's
## frame: a button is a small thing, and twelve pixels of wood round a sixty-pixel face
## would be a frame with a picture as an afterthought.
const FRAME := 7.0
const CHIPS := 1

## The upgrades button. The net fills the face behind everything, dimmed so it reads as a
## backdrop; the ferry stands to the left of the arrow and the dog to the right, both inside
## the arrow's own edges so neither crosses it; the arrow is drawn last and over the lot, the
## biggest and brightest thing there. The dog is drawn by `DogArt` (`Dogs` here).
const NET_FILL := 1.05
const NET_DIM := Color(0.55, 0.62, 0.66)
const SIDE_TALL := 0.52
const BOAT_TALL := 0.64
const BOAT_LIFT := 0.12
const SIDE_IN := 0.04
const ARROW_TALL := 0.78
const ARROW_WIDE := 0.52
const ARROW_HEAD := 0.5
const ARROW_SHAFT := 0.42

## The shed button: the finds cover the face behind the hut, in two overlapping rows — the
## tall pieces along the back, the low ones in front of them — and the hut stands centred
## over the lot with the word across its foot. Fixed, by decision (2026-09-11): a button
## that showed the player's own finds would be bare for the first hour, and it is the way
## in, not a shelf.
##
## `DECOR_OVER` is how much of its neighbour each find laps, so the row closes up rather than
## standing in spaced slots: a backdrop with gaps in it reads as a row of objects, and the
## point of this one is to be a wall of furniture.
const DECOR_BACK := 0.62
const DECOR_FRONT := 0.44
const DECOR_OVER := 0.3
const DECOR_DIM := Color(0.82, 0.86, 0.88)
const SHED_TALL := 0.8
const SHED_LABEL := "Decorate"

## The coin: a disc in the money's gold with a deeper rim, a paler crescent where the light
## catches it, and a ring struck into it a little in from the edge.
const COIN_RIM := 2.0
const COIN_RING := 0.72
const COIN_GLINT := Color(1.0, 0.94, 0.72)


## The wood and the face. Returns the face, which is where the contents go.
static func board(on: CanvasItem, box: Rect2, hovered: bool) -> Rect2:
	Style.board_frame(on, box, FRAME, CHIPS)
	var face := box.grow(-FRAME)
	var fill := Style.BOARD
	if hovered:
		fill = Color(fill.r * Style.HOVER_WASH.r, fill.g * Style.HOVER_WASH.g, fill.b * Style.HOVER_WASH.b)
	on.draw_rect(face, fill, true)
	return face


## A sprite fitted into a box: scaled to fit the box's height (or width, if it is the
## tighter), and stood on the box's bottom edge centred on its middle. `fill` over one lets
## it run past the box; the caller is saying it does not mind.
static func fit(on: CanvasItem, art: Dictionary, box: Rect2, fill: float, tint: Color, stand: bool = true, flip: bool = false) -> Rect2:
	var sheet: Texture2D = art.get("sheet")
	if sheet == null:
		return Rect2()
	var region: Rect2 = art["region"]
	if region.size.x <= 0.0 or region.size.y <= 0.0:
		return Rect2()
	var scale := minf(box.size.x / region.size.x, box.size.y / region.size.y) * fill
	var drawn := region.size * scale
	var at := Vector2(box.position.x + (box.size.x - drawn.x) * 0.5, 0.0)
	at.y = box.end.y - drawn.y if stand else box.position.y + (box.size.y - drawn.y) * 0.5
	var rect := Rect2(at, drawn)
	# A negative width is how a drawn rect mirrors its picture.
	var shown := Rect2(at + Vector2(drawn.x, 0.0), Vector2(-drawn.x, drawn.y)) if flip else rect
	on.draw_texture_rect_region(sheet, shown, region, tint)
	return rect


## The upgrades button. `hovered` lifts and lights it; `wash` is the caller's own tint on
## top of that, white for none.
static func draw_upgrades(on: CanvasItem, box: Rect2, hovered: bool, sprites: Dictionary) -> void:
	var face := board(on, box, hovered)
	var tint := Style.HOVER_WASH if hovered else Color.WHITE
	# The net, behind, filling the face and dimmed into it. Clipped to the face by drawing
	# it centred rather than stood, so an over-fill spills evenly rather than out of the top.
	if sprites.has("net"):
		var net_tint := Color(NET_DIM.r * tint.r, NET_DIM.g * tint.g, NET_DIM.b * tint.b)
		fit(on, sprites["net"], face, NET_FILL, net_tint, false)
	# The ferry to the left of the arrow, a little up off the foot; the dog to the right.
	# Both mirrored from how their sheets face, so they look outwards. Each is kept inside
	# the arrow's own edge, so the arrow stands clear of them rather than on top of them.
	var side_tall := face.size.y * SIDE_TALL
	var foot := face.end.y - face.size.y * 0.08
	var arrow_half := face.size.x * ARROW_WIDE * 0.5
	var mid := face.position.x + face.size.x * 0.5
	var lane := maxf(mid - arrow_half - face.position.x - face.size.x * SIDE_IN, 1.0)
	if sprites.has("boat"):
		var boat_tall := face.size.y * BOAT_TALL
		var slot := Rect2(
			Vector2(face.position.x + face.size.x * SIDE_IN, foot - face.size.y * BOAT_LIFT - boat_tall),
			Vector2(lane, boat_tall)
		)
		fit(on, sprites["boat"], slot, 1.0, tint, true, true)
	if Dogs.has(&"idle"):
		var dog_tall := side_tall * 0.9
		# Shrunk if it would not fit its lane: the dog is wider than it is tall, and the lane
		# beside the arrow is the narrow measurement.
		var span := Dogs.span(&"idle", dog_tall)
		if span.x > lane:
			dog_tall *= lane / span.x
		var dog_foot := Vector2(mid + arrow_half + lane * 0.5, foot)
		Dogs.stamp(on, &"idle", 0, dog_foot, dog_tall, false, 0.0, tint)
	arrow(on, face, tint)


## The green arrow: a black-ringed block arrow pointing up, in the game's own `SAFE`
## green, a lit edge along its left and a shaded one down its right so it stands off the
## face rather than lying flat on it.
static func arrow(on: CanvasItem, face: Rect2, tint: Color) -> void:
	var tall := floorf(face.size.y * ARROW_TALL)
	var wide := floorf(face.size.x * ARROW_WIDE)
	var head := floorf(tall * ARROW_HEAD)
	var shaft := floorf(wide * ARROW_SHAFT)
	var mid := floorf(face.position.x + face.size.x * 0.5)
	var top := floorf(face.position.y + (face.size.y - tall) * 0.5)
	var shape := PackedVector2Array([
		Vector2(mid, top),
		Vector2(mid + wide * 0.5, top + head),
		Vector2(mid + shaft * 0.5, top + head),
		Vector2(mid + shaft * 0.5, top + tall),
		Vector2(mid - shaft * 0.5, top + tall),
		Vector2(mid - shaft * 0.5, top + head),
		Vector2(mid - wide * 0.5, top + head),
	])
	var green := Color(Style.SAFE.r * tint.r, Style.SAFE.g * tint.g, Style.SAFE.b * tint.b)
	# The ring: the same shape drawn a pixel bigger about its middle, in black, under it.
	var centre := Vector2(mid, top + tall * 0.5)
	var ring := PackedVector2Array()
	for point in shape:
		ring.append(centre + (point - centre) * Vector2((wide + 3.0) / wide, (tall + 3.0) / tall))
	on.draw_colored_polygon(ring, Style.HOLE_RIM)
	on.draw_colored_polygon(shape, green)
	# Lit along the left slope and shaft, shaded down the right, one pixel each.
	var lit := green.lightened(0.3)
	var deep := green.darkened(0.3)
	on.draw_polyline(PackedVector2Array([shape[6] + Vector2(1.0, 0.0), shape[0] + Vector2(0.0, 1.0)]), lit, 1.0)
	on.draw_polyline(PackedVector2Array([shape[5] + Vector2(1.0, 1.0), shape[4] + Vector2(1.0, -1.0)]), lit, 1.0)
	on.draw_polyline(PackedVector2Array([shape[0] + Vector2(0.0, 1.0), shape[1] + Vector2(-1.0, 0.0)]), deep, 1.0)
	on.draw_polyline(PackedVector2Array([shape[2] + Vector2(-1.0, 1.0), shape[3] + Vector2(-1.0, -1.0)]), deep, 1.0)
	on.draw_polyline(PackedVector2Array([shape[4] + Vector2(1.0, -1.0), shape[3] + Vector2(-1.0, -1.0)]), deep, 1.0)


## The shed button: the finds behind, the hut centred in front, the word across the foot.
static func draw_shed(on: CanvasItem, box: Rect2, hovered: bool, sprites: Dictionary) -> void:
	var face := board(on, box, hovered)
	var tint := Style.HOVER_WASH if hovered else Color.WHITE
	var label_tall := floorf(face.size.y * 0.2)
	var room := Rect2(face.position, Vector2(face.size.x, face.size.y - label_tall))
	var decor: Array = sprites.get("decor", [])
	if not decor.is_empty():
		var dim := Color(DECOR_DIM.r * tint.r, DECOR_DIM.g * tint.g, DECOR_DIM.b * tint.b)
		# The back row takes the first half of the list and stands on the room's middle; the
		# front row takes the rest and stands on its foot, lapping over the row behind.
		var split := int(ceil(float(decor.size()) * 0.5))
		_decor_row(on, decor.slice(0, split), room, DECOR_BACK, room.position.y + room.size.y * 0.72, dim)
		_decor_row(on, decor.slice(split), room, DECOR_FRONT, room.end.y, dim)
	var hut: Texture2D = sprites.get("shed")
	if hut != null:
		var tall := room.size.y * SHED_TALL
		var slot := Rect2(Vector2(room.position.x, room.end.y - tall), Vector2(room.size.x, tall))
		fit(on, {"sheet": hut, "region": Rect2(Vector2.ZERO, hut.get_size())}, slot, 1.0, tint)
	label(on, Rect2(Vector2(face.position.x, face.end.y - label_tall), Vector2(face.size.x, label_tall)), SHED_LABEL)


## One row of finds across a box, each as tall as `tall` of it, stood on `baseline`, spaced
## so every one laps `DECOR_OVER` of its neighbour and the row leaves no gaps.
static func _decor_row(on: CanvasItem, row: Array, box: Rect2, tall: float, baseline: float, dim: Color) -> void:
	if row.is_empty():
		return
	var height := box.size.y * tall
	var stride := box.size.x / float(row.size())
	for i in row.size():
		var slot := Rect2(
			Vector2(box.position.x + stride * float(i) - stride * DECOR_OVER * 0.5, baseline - height),
			Vector2(stride * (1.0 + DECOR_OVER), height)
		)
		fit(on, row[i], slot, 1.0, dim)


## The word across the foot of a button, on a sunken panel. The same panel the upgrades
## button writes its count on, because they are a pair.
static func label(on: CanvasItem, box: Rect2, text: String) -> void:
	var plate := Rect2(box.position + Vector2(4.0, 1.0), box.size - Vector2(8.0, 4.0))
	Style.plate(on, plate, Style.BOARD.darkened(0.35), 2.0)
	var height := Style.step(plate.size.y * 0.8)
	var wide := Style.measure(text, height).x
	if wide > plate.size.x:
		height = maxi(8, int(float(height) * plate.size.x / wide))
	Style.write(
		on, text, height,
		Vector2(0.0, plate.position.y + plate.size.y * 0.5 + float(height) * 0.35),
		Style.INK, HORIZONTAL_ALIGNMENT_CENTER, plate
	)


## The money plate: the coin on the left, and the sunken panel the figure is written on
## filling the rest. Returns the panel. `wash` is the payment's shine on the coin.
static func draw_money(on: CanvasItem, box: Rect2, wash: Color) -> Rect2:
	var face := board(on, box, false)
	var side := face.size.y
	var coin_box := Rect2(face.position, Vector2(side, side))
	coin(on, coin_box.grow(-3.0), wash)
	var panel := Rect2(
		Vector2(coin_box.end.x + 2.0, face.position.y + 5.0),
		Vector2(face.end.x - coin_box.end.x - 7.0, face.size.y - 10.0)
	)
	Style.plate(on, panel, Style.BOARD.darkened(0.35), 2.0)
	return panel


static func coin(on: CanvasItem, box: Rect2, wash: Color) -> void:
	var centre := box.position + box.size * 0.5
	var r := minf(box.size.x, box.size.y) * 0.5
	var gold := Color(Style.GOLD.r * wash.r, Style.GOLD.g * wash.g, Style.GOLD.b * wash.b)
	var deep := Color(Style.GOLD_DEEP.r * wash.r, Style.GOLD_DEEP.g * wash.g, Style.GOLD_DEEP.b * wash.b)
	on.draw_circle(centre, r + 1.0, Style.HOLE_RIM)
	on.draw_circle(centre, r, deep)
	on.draw_circle(centre, r - COIN_RIM, gold)
	# The ring struck into the face, and the crescent of light on its upper left.
	on.draw_arc(centre, r * COIN_RING, 0.0, TAU, 24, deep, 1.0)
	on.draw_arc(centre, r - COIN_RIM - 1.0, PI * 1.05, PI * 1.55, 12, COIN_GLINT, 2.0)
