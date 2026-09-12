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
## Drawn in two layers, by decision (Richard, 2026-09-12, "objects in front of the poles
## must not clip through it"): the posts and the edge beams under the deck are drawn by
## `Under`, a child at z 4, **below** the floating rubbish (z 5), and the deck top with the
## box on it by this node at z 6, above it. A piece floating in front of a post is therefore
## drawn over the post, and a piece under the deck is still hidden by it.
##
## What the lake adds round the picture, none of it baked into the sheet:
##   * the sun's shadow: a flat slab's shadow is its own silhouette slid along the day's
##     lean by the deck's height, so the deck top's silhouette (`shade_wet` over the water,
##     `shade_dry` over the sand, from the sheet) is drawn in the day's ink under the posts,
##     the wet half at the hull's gain (SHADE_GAIN) because the day's ink is set for sand,
##     and **the wet half rides the swell**: the water is what the shadow falls on, so it
##     rises and falls with it, at the same swell the rubbish beside it bobs on
##     (LakeGrid._swell, off the grid's clock). The box on the platform is swept by
##     `Shade.Cast` like the island's crate;
##   * foam: a WaterlineFoam collar round the foot of every post that stands in the water,
##     drawn **in front** of the post and riding the same swell;
##   * sand: Skirt.mound banked over the foot of every post on the beach, drawn over it.
## Wet or dry is measured against the lake at runtime, because the coast curves and the
## jetty does not.
## The old front-on paintings (Piers_Asset_Sheet.jpg, tools/slice_piers.gd) are retired.
class_name Dropoff
extends Node2D

## The sheet of the four yards and its book, both written by tools/build_piers.py.
const ART := "res://assets/piers.json"

## The box the platform carries, for its swept shadow. The same picture the sheet pasted.
const BOX_ART := "res://assets/Recycle_Box.png"

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

## Where the posts and beams draw: under the floating rubbish (5), over the water (2).
const UNDER_LAYER := 4

## The foam collar at a post: half its width in world px. Wider than the post (6 px) so the
## froth rings it rather than hiding behind it.
const POST_COLLAR := 8.0

## The post's width on screen, in world px, for the sand banked over its foot.
const POST_WIDE := 6.0

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

## The lake's grid, for its clock: the swell the wet shadow and the collars ride. Set by the
## lake; without it the water under the pier is flat.
var grid: LakeGrid

## The sheet, read once for all four yards rather than once each.
static var _sheet: Texture2D
static var _pieces := {}
static var _read := false
static var _box_image: Image

var _under: Under
var _box_cast: Shade.Cast
var _collars: Array[WaterlineFoam] = []
var _collar_feet := PackedVector2Array()
var _mounds: Array[Skirt.Patch] = []
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


## How far the water under the jetty is up or down right now, in world px: the same swell
## the floating rubbish rides (rubbish.gdshader mirrors LakeGrid._swell), read at the
## jetty's own x so it agrees with the pieces beside it.
func swell() -> float:
	if grid == null:
		return 0.0
	return LakeGrid._swell(place().x, grid.wave_time()) * LakeGrid.WAVE_AMPLITUDE


func _ready() -> void:
	_dress()


## The under layer, the collars and the sand, once: the posts do not move.
func _dress() -> void:
	if _dressed:
		return
	_dressed = true
	var book := _book()
	if book.is_empty():
		return
	_under = Under.new()
	_under.name = &"Under"
	_under.yard = self
	_under.z_index = UNDER_LAYER
	_under.z_as_relative = false
	add_child(_under)
	if book.has("box"):
		_box_cast = Shade.Cast.new()
		_box_cast.name = &"BoxShade"
		add_child(_box_cast)
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
				# In front of the post, not behind it: a collar behind a six-pixel post is
				# a collar nobody sees. Over the posts and under the rubbish, with its parent.
				collar.z_index = 0
				_under.add_child(collar)
				collar.lay(Vector2(-POST_COLLAR, 0.0), Vector2(POST_COLLAR, 0.0))
				_collars.append(collar)
				_collar_feet.append(at)
			else:
				_mounds.append(Skirt.mound(at, POST_WIDE, 9101 + kind * 131 + i))
			i += 1


## A json point (painted px in the piece's region) as a world point.
func _world(point: Variant, book: Dictionary) -> Vector2:
	var anchor: Array = book["anchor"]
	return place() + Vector2(
		float(point[0]) - float(anchor[0]), float(point[1]) - float(anchor[1])
	) * ART_SCALE


## A json rectangle on the sheet as a Rect2.
static func _rect(box: Variant) -> Rect2:
	return Rect2(float(box[0]), float(box[1]), float(box[2]), float(box[3]))


## Where a region of the yard's size lands in the world: every layer shares the anchor.
func _frame(book: Dictionary) -> Rect2:
	var region := _rect(book["region"])
	var anchor: Array = book["anchor"]
	return Rect2(
		place() - Vector2(float(anchor[0]), float(anchor[1])) * ART_SCALE,
		region.size * ART_SCALE
	)


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
	_box_image = Art.image(BOX_ART)
	return true


func _process(_delta: float) -> void:
	if _under == null:
		return
	# The water moves under the jetty every frame: the wet shadow and the collars with it.
	var rise := swell()
	for i in _collars.size():
		_collars[i].position = _collar_feet[i] + Vector2(0.0, rise)
	_under.queue_redraw()
	if day != null:
		queue_redraw()


func _draw() -> void:
	var book := _book()
	if book.is_empty():
		_draw_blocked()
		return
	if day != null and _box_cast != null and _box_image != null:
		# The box stands on the deck: its shadow is swept from its base there, the way the
		# island's crate is swept from its own (Yard._draw), so the two crates cast alike.
		var box: Array = book["box"]
		var frame := _frame(book)
		var rect := Rect2(
			frame.position + Vector2(float(box[0]), float(box[1])) * ART_SCALE,
			Vector2(float(box[2]), float(box[3])) * ART_SCALE
		)
		_box_cast.lay(
			_box_image, rect, day.lean, day.stretch,
			1.0 - Yard.ART_GROUND / float(maxi(_box_image.get_height(), 1)), day.ink
		)
	draw_texture_rect_region(_sheet, _frame(book), _rect(book["region"]))


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


## The half of the pier that is under the deck — the shadow it throws, its posts and beams,
## and the sand banked over the dry posts' feet — drawn below the floating rubbish so a
## piece in front of a post is drawn over it. The collars are its children, in front of the
## posts. Redrawn every frame by the yard, because the wet shadow rides the swell.
class Under extends Node2D:
	var yard: Dropoff

	func _draw() -> void:
		if yard == null:
			return
		var book := yard._book()
		if book.is_empty():
			return
		var frame := yard._frame(book)
		if yard.day != null:
			var day := yard.day
			var up := float(book["deck_up"]) * Dropoff.ART_SCALE
			# A point `up` above the ground lands this far from the ground point
			# (Shade.lying's transform on a point at that height); the deck top's silhouette
			# is drawn `up` above its footprint, so the footprint is that much lower first.
			var slide := Vector2(day.lean * up, day.stretch * 0.5 * up + up)
			draw_texture_rect_region(
				Dropoff._sheet, Rect2(frame.position + slide, frame.size),
				Dropoff._rect(book["shade_dry"]), Shade.tint(day.ink)
			)
			# On the water, and moving with it.
			draw_texture_rect_region(
				Dropoff._sheet,
				Rect2(frame.position + slide + Vector2(0.0, yard.swell()), frame.size),
				Dropoff._rect(book["shade_wet"]),
				Shade.tint(minf(day.ink * Dropoff.SHADE_GAIN, Dropoff.SHADE_MOST))
			)
		draw_texture_rect_region(Dropoff._sheet, frame, Dropoff._rect(book["under"]))
		for mound in yard._mounds:
			mound.over(self)
