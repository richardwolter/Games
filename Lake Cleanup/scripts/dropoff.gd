## A yard on the shore that buys one material.
##
## There are four of them, spaced around the bank, and between them they are the reason
## the ferry has a route rather than a destination. A hold with plastic and metal in it is
## two stops; a hold with one of everything is a lap of the lake.
##
## The node draws itself and knows what it takes. It holds no stock and no money — the
## boat arrives, the lake pays, and the yard is a place rather than a system.
class_name Dropoff
extends Node2D

## The cut sheet of the four yards, and where each one sits on it.
const ART := "res://assets/piers.json"

## How wide a yard is drawn, in world pixels — about three tile widths, so a pier is heavier
## than the ferry tied up at it and lighter than the shed across the water.
const PIER_WIDE := 190.0

## How far down its own picture a yard meets the ground, as a fraction. All of it: the grey
## shadow the scenes were painted standing on is cleared by tools/slice_piers.gd now, so the
## bottom of the region is the feet of the posts and nothing hangs below them.
const PIER_FOOT := 1.0

## How far landward of the waterline the yard stands, in tiles. Measured from the shore
## rather than from the berth, so a yard sits on the bank with its deck ending on the lake
## line however far out the berth happens to be on that side.
const PIER_OUT := 1.6

## Which of TrashDef.Kind this one buys.
var kind: int = TrashDef.Kind.PLASTIC

## Where the boat ties up, in tile coordinates. Just inside the waterline, so the hull has
## water under it when it arrives.
var berth := Vector2.ZERO

## The yard's colour. The drawn version paints its sign and crates with it; the painted
## version has its own sign and does not need it, but the ferry still reads it to say which
## stop it is sailing to, and the fallback still needs it.
var tint := Color(0.7, 0.7, 0.7)

## The sheet, read once for all four yards rather than once each.
static var _sheet: Texture2D
static var _pieces := {}
static var _read := false


func kind_name() -> String:
	return TrashDef.KIND_NAMES[kind]


## Read the cut sheet. False means no art, and every yard falls back to the drawn version.
static func _load_art() -> bool:
	if _read:
		return _sheet != null
	_read = true
	var text := FileAccess.get_file_as_string(ART)
	if text.is_empty():
		return false
	var book: Variant = JSON.parse_string(text)
	if not (book is Dictionary) or not (book as Dictionary).has("pieces"):
		return false
	_sheet = Art.texture((book as Dictionary)["sheet"])
	if _sheet == null:
		return false
	for name: String in (book as Dictionary)["pieces"]:
		var piece: Variant = (book as Dictionary)["pieces"][name]
		if piece is Array:
			_pieces[StringName(name)] = Rect2(piece[0], piece[1], piece[2], piece[3])
	return true


## The yard, from the sheet if there is one and from flat colour if there is not.
##
## Drawn as a billboard standing on a point of the plane, the way the shed is, rather than
## laid into the isometric grid: these are front-on paintings of a dockside, and skewing one
## into a 2:1 diamond smears it into a shape nobody drew.
func _draw() -> void:
	if not _load_art() or not _pieces.has(StringName(kind_name().to_lower())):
		_draw_blocked()
		return
	var region: Rect2 = _pieces[StringName(kind_name().to_lower())]
	# Landward is further out from the middle of the lake, so a yard always stands on the
	# nearest bank rather than out in the water. Walked out from the shoreline itself, so
	# the picture stands on the bank with its side on the water rather than in it.
	var foot := Iso.shore_point(Iso.basin_angle(berth), PIER_OUT)
	var size := region.size * (PIER_WIDE / region.size.x)
	# Never mirrored. The bank the yard stands on used to decide it, so the deck ran
	# towards the water on both sides — but these are front-on paintings with the material
	# signwritten across them, and a mirrored yard is a yard with its sign written
	# backwards.
	draw_set_transform(foot, 0.0, Vector2.ONE)
	draw_texture_rect_region(
		_sheet,
		Rect2(Vector2(-size.x * 0.5, -size.y * PIER_FOOT), size),
		region
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The yard as it was drawn before there was art for it: planks over the water, crates on
## the bank, and a sign. Kept whole, because a missing sheet should cost the picture and
## not the place — the same bargain the shed and the HUD strike.
func _draw_blocked() -> void:
	var ink := Color(0.11, 0.09, 0.1)
	var at := Iso.tile_to_world(berth.x, berth.y)
	var out := (berth - Iso.CENTRE).normalized()
	var landward := Iso.tile_to_world(berth.x + out.x * 3.4, berth.y + out.y * 3.4)

	var across := Vector2(Iso.TILE_W * 0.32, 0.0)
	var deck := PackedVector2Array([
		at - across, at + across, landward + across * 1.25, landward - across * 1.25
	])
	draw_colored_polygon(deck, Color(0.55, 0.42, 0.28))
	var closed := deck.duplicate()
	closed.append(deck[0])
	draw_polyline(closed, ink, 1.6)

	# Crates in the yard's colour. The place that buys metal should look like a place full
	# of metal.
	for i in 3:
		var spot := landward + Vector2(-26.0 + 26.0 * float(i), -6.0 - 5.0 * float(i % 2))
		draw_rect(Rect2(spot, Vector2(20.0, 14.0)), tint)
		draw_rect(Rect2(spot, Vector2(20.0, 14.0)), ink, false, 1.4)

	# A post and a board, so there is one tall thing marking the stop at any zoom.
	var post := landward + Vector2(34.0, -4.0)
	draw_line(post, post + Vector2(0.0, -46.0), Color(0.42, 0.32, 0.22), 3.0)
	var board := Rect2(post + Vector2(-16.0, -62.0), Vector2(32.0, 18.0))
	draw_rect(board, tint)
	draw_rect(board, ink, false, 1.6)
