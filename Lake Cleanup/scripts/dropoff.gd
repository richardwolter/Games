## A yard on the shore that buys one material.
##
## There are four of them, spaced around the bank, and between them they are the reason
## the ferry has a route rather than a destination. A hold with plastic and metal in it is
## two stops; a hold with one of everything is a lap of the lake.
##
## The node draws itself and knows what it takes. It holds no stock and no money — the
## boat arrives, the lake pays, and the yard is a place rather than a system.
##
## The picture is a jetty of planks on posts running JETTY_OUT tiles from the waterline into
## the lake, with a platform on the sand behind it carrying the recycle box, built as
## isometric pixel art by tools/build_piers.py (2026-09-12) and laid **into** the tile plane:
## the deck is a 2:1 diamond on the grid, not a front-on painting standing on it. The four
## banks face four ways, so the sheet holds four drawings and nothing is mirrored. Everything
## about where the picture meets the world — the waterline point, the decks' outlines, the
## posts' feet, where a delivery lands — is read from the sheet's json, never measured off
## the picture at runtime.
##
## What the lake adds round the picture, none of it baked into the sheet:
##   * the sun's shadow: a flat slab's shadow is its own footprint slid along the day's lean
##     by the deck's height, so the two decks are filled as polygons in the day's ink, the
##     jetty's over water at the hull's gain (SHADE_GAIN, see Boat) because the day's ink is
##     set for sand; the box on the platform is a billboard and is laid down by Shade.lying
##     from its foot like the hut;
##   * foam: a WaterlineFoam collar at the foot of every post that stands in the water;
##   * sand: Skirt.spill grains at the foot of every post on the beach, drawn under the deck.
## Wet or dry is measured against the lake at runtime, because the coast curves and the
## jetty does not.
## The old front-on paintings (Piers_Asset_Sheet.jpg, tools/slice_piers.gd) are retired.
class_name Dropoff
extends Node2D

## The sheet of the four yards and its book, both written by tools/build_piers.py.
const ART := "res://assets/piers.json"

## World px per painted px. The sheet is drawn at 2.0 like every sprite in the lake
## (Lake.ART_PIXEL); the json's numbers are painted px and are scaled by this on the way in.
const ART_SCALE := 2.0

## How far the jetty runs out from the waterline, in tiles. Must match the builder's
## JETTY_OUT — the berth is placed off it, and a berth past the end of the drawn jetty is a
## ferry tied up to nothing.
const JETTY_OUT := 3.0

## How far to the side of the jetty's centreline the ferry lies when it is tied up, in tiles:
## half the jetty, half a hull's beam, and a gap. On the camera's side of the jetty always,
## so the hull (z 12) drawn over the pier (z 6) is the hull in front of it.
const BERTH_ASIDE := 1.3

## How far out along the jetty the ferry lines up before coming in, in tiles, so it arrives
## running alongside the jetty rather than nosing into it from wherever it was — the same
## thing Boat._dock_approach does for the island's dock.
const APPROACH := 2.5

## The shadow over water: the day's ink is set for sand and grass and cannot be seen on the
## lake, so the jetty's shadow takes Boat's gain and cap.
const SHADE_GAIN := 3.0
const SHADE_MOST := 0.7

## The foam collar at a post: half its width in world px. A little wider than the post
## (6 px) so the froth shows past its sides.
const POST_COLLAR := 5.0

## The sand a post on the beach has worn: how far the grains spill, in tiles, and how many.
const SPILL_REACH := Vector2(0.45, 0.4)
const SPILL_GRAINS := 14

## Which of TrashDef.Kind this one buys.
var kind: int = TrashDef.Kind.PLASTIC

## Where the boat ties up, in tile coordinates: alongside the end of the jetty.
var berth := Vector2.ZERO

## Where the jetty leaves the bank, in tile coordinates: the drawn waterline on the yard's
## bearing. The picture's anchor lands here.
var foot := Vector2.ZERO

## Which way the jetty runs, as a unit tile vector towards the lake, and which way is the
## camera's side of it. Both cardinal: the four yards sit on the four cardinal banks, where
## the way to the middle of the lake is a tile axis, and the sheet was drawn for exactly
## those four.
var axis := Vector2(0.0, -1.0)
var aside := Vector2(1.0, 0.0)

## The yard's colour. The ferry reads it to say which stop it is sailing to, and the drawn
## fallback paints its crates with it.
var tint := Color(0.7, 0.7, 0.7)

## The day, for the shadow. Set by the lake; no day, no shadow.
var day: DayCycle

## The sheet, read once for all four yards rather than once each.
static var _sheet: Texture2D
static var _pieces := {}
static var _read := false

var _collars: Array[WaterlineFoam] = []
var _spills: Array[Skirt.Patch] = []
var _dressed := false


func kind_name() -> String:
	return TrashDef.KIND_NAMES[kind]


## Put the yard on its bank: `angle` round the basin, `lap` the tiles the drawn water runs
## past Iso's waterline (Lake.SHORE_LAP). Works out the foot, the axis, the camera side and
## the berth from that one bearing, so they cannot disagree.
func moor(angle: float, lap: float) -> void:
	var out := Vector2(cos(angle), sin(angle))
	foot = Iso.basin_point(angle, 1.0) + out * lap
	# Snapped to the tile axis the bearing is nearest: the sheet holds the four cardinal
	# drawings, and a jetty drawn along an axis has to run along it.
	axis = -Vector2(roundf(out.x), roundf(out.y))
	if axis.length_squared() < 0.5:
		axis = -out.normalized()
	axis = axis.normalized()
	var across := Vector2(-axis.y, axis.x)
	# Towards the camera, which on this plane is down the screen.
	aside = across if Iso.tile_to_world(across.x, across.y).y > 0.0 else -across
	berth = foot + axis * JETTY_OUT + aside * BERTH_ASIDE


## Where the ferry lines up before coming in: out along the jetty from the berth.
func approach() -> Vector2:
	return berth + axis * APPROACH


## The picture's anchor in world px: where the jetty meets the water.
func place() -> Vector2:
	return Iso.tile_to_world(foot.x, foot.y)


## Where a piece landed off a ferry should come down: in the box on the platform.
func drop_point() -> Vector2:
	var book := _book()
	if book.is_empty():
		return place() + Vector2(0.0, -12.0)
	return _world(book["drop"], book)


func _ready() -> void:
	_dress()


## The collars and the spills, once: the posts do not move.
func _dress() -> void:
	if _dressed:
		return
	_dressed = true
	var book := _book()
	if book.is_empty():
		return
	# Wet or dry is decided here against the lake, not read off the sheet: the builder
	# marks the jetty's posts wet and the platform's dry, but the coast is a curve and the
	# jetty is straight, so the pair at the water's edge can stand either side of it
	# depending on the bank. A post past the drawn edge froths; one short of it wears sand.
	var edge := Iso.shore_fraction(foot.x, foot.y)
	var i := 0
	for list: StringName in [&"posts_wet", &"posts_dry"]:
		for post: Variant in book[list]:
			var at := _world(post, book)
			var tile := Iso.world_to_tile(at)
			if Iso.shore_fraction(tile.x, tile.y) < edge:
				var collar := WaterlineFoam.new()
				collar.position = at
				add_child(collar)
				collar.lay(Vector2(-POST_COLLAR, 0.0), Vector2(POST_COLLAR, 0.0))
				_collars.append(collar)
			else:
				_spills.append(Skirt.spill(at, SPILL_REACH, SPILL_GRAINS, 9101 + kind * 131 + i))
			i += 1


## A json point (painted px in the piece's region) as a world point.
func _world(point: Variant, book: Dictionary) -> Vector2:
	var anchor: Array = book["anchor"]
	return place() + Vector2(
		float(point[0]) - float(anchor[0]), float(point[1]) - float(anchor[1])
	) * ART_SCALE


## This yard's entry in the sheet's book, or an empty dictionary when there is no art.
func _book() -> Dictionary:
	if not _load_art():
		return {}
	var key := StringName(kind_name().to_lower())
	return _pieces.get(key, {})


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
		if piece is Dictionary and (piece as Dictionary).has("region"):
			_pieces[StringName(name)] = piece
	return true


func _process(_delta: float) -> void:
	# The shadow moves with the sun.
	if day != null:
		queue_redraw()


func _draw() -> void:
	var book := _book()
	if book.is_empty():
		_draw_blocked()
		return
	for spill in _spills:
		spill.behind(self)
	if day != null:
		_draw_shadow(book)
	var region: Array = book["region"]
	var rect := Rect2(float(region[0]), float(region[1]), float(region[2]), float(region[3]))
	var anchor: Array = book["anchor"]
	var at := place() - Vector2(float(anchor[0]), float(anchor[1])) * ART_SCALE
	draw_texture_rect_region(_sheet, Rect2(at, rect.size * ART_SCALE), rect)


## The sun's shadow: each deck's footprint slid along the lean by its height, and the box
## laid down from its foot.
func _draw_shadow(book: Dictionary) -> void:
	var up := float(book["deck_up"]) * ART_SCALE
	# A point `up` above the ground lands this far from the ground point (Shade.lying's
	# transform on a point at that height).
	var slide := Vector2(day.lean * up, day.stretch * 0.5 * up)
	var on_water := Shade.tint(minf(day.ink * SHADE_GAIN, SHADE_MOST))
	var on_sand := Shade.tint(day.ink)
	for key: StringName in [&"jetty", &"platform"]:
		var outline := PackedVector2Array()
		for point: Variant in book[key]:
			# The json outline is the deck top, drawn `up` above the plane; its footprint is
			# that much lower on screen.
			outline.append(_world(point, book) + Vector2(0.0, up) + slide)
		draw_colored_polygon(outline, on_water if key == &"jetty" else on_sand)
	if not book.has("box"):
		return
	# The box stands on the platform's deck, so its shadow starts from its foot on that deck
	# and carries the deck's own slide.
	var box: Array = book["box"]
	var region: Array = book["region"]
	var drop: Array = book["drop"]
	var root := _world(drop, book) + slide
	var corner := Vector2(float(box[0]) - float(drop[0]), float(box[1]) - float(drop[1])) * ART_SCALE
	var size := Vector2(float(box[2]), float(box[3])) * ART_SCALE
	draw_set_transform_matrix(Shade.lying(root, day.lean, day.stretch))
	draw_texture_rect_region(
		_sheet, Rect2(corner, size),
		Rect2(float(region[0]) + float(box[0]), float(region[1]) + float(box[1]),
			float(box[2]), float(box[3])),
		on_sand
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The yard as it was drawn before there was art for it: planks out over the water, a crate
## on the bank. Kept whole, because a missing sheet should cost the picture and not the
## place — the same bargain the shed and the HUD strike.
func _draw_blocked() -> void:
	var ink := Color(0.11, 0.09, 0.1)
	var across := Vector2(-axis.y, axis.x) * 0.5
	var deck := PackedVector2Array()
	for corner: Vector2 in [
		foot - across, foot + axis * JETTY_OUT - across,
		foot + axis * JETTY_OUT + across, foot + across,
	]:
		deck.append(Iso.tile_to_world(corner.x, corner.y))
	draw_colored_polygon(deck, Color(0.55, 0.42, 0.28))
	var closed := deck.duplicate()
	closed.append(deck[0])
	draw_polyline(closed, ink, 1.6)
	# A crate in the yard's colour on the bank. The place that buys metal should look like a
	# place full of metal.
	var landward := foot - axis * 1.0
	var spot := Iso.tile_to_world(landward.x, landward.y) + Vector2(-12.0, -16.0)
	draw_rect(Rect2(spot, Vector2(24.0, 18.0)), tint)
	draw_rect(Rect2(spot, Vector2(24.0, 18.0)), ink, false, 1.4)
