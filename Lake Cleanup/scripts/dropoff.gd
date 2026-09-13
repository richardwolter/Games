## A yard on the shore that buys one material.
##
## There are four of them, spaced around the bank, and between them they are the reason
## the ferry has a route rather than a destination. A hold with plastic and metal in it is
## two stops; a hold with one of everything is a lap of the lake.
##
## The node draws itself and knows what it takes. It holds no stock and no money — the
## boat arrives, the lake pays, and the yard is a place rather than a system. What it does
## hold (2026-09-13) is a picture of the last delivery: the pieces the ferry lands heap up
## inside the box the way the island's crate fills, and sink away again while the ferry is
## gone (`put`, `_drain`). Bought, not stock — nothing reads the heap — and not saved.
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
##
## The yard's name is on a sign (2026-09-13): the builder paints the post and a bare plank
## (`sign`, `sign_foot`, `sign_cut` in the json) and this node writes the name on it every
## draw, through `tr()`, so a translation changes the sign without a repaint. The sign is a
## billboard on a post, so its shadow is `Shade.lying` from the post's foot, like the
## angler's — not the sweep the box gets. The material's emblem carved into the box's lit
## face is baked; nothing here knows about it.
## The old front-on paintings (Piers_Asset_Sheet.jpg, tools/slice_piers.gd) are retired.
class_name Dropoff
extends Node2D

const Style := preload("res://scripts/style.gd")

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

## The post's width on screen, in world px, when the sheet does not say. The sheet records
## each post as [middle column, bottom row, width] in painted px, and the width is what the
## sand is sized to.
const POST_WIDE := 6.0

## The heap in the box: the ferry's last delivery, drawn inside it and sinking away again.
## `DRAIN_HOLD` seconds after the last piece lands the pile starts to go, one piece every
## `DRAIN_EVERY`, so a full box is about gone by the time the ferry is back — a readout of
## the last run, not a wall of junk by the third.
##
## Drawn the island crate's way (Yard._draw_heap) but not at its numbers. That crate starts
## its heap sunk behind the near walls (HEAP_FLOOR 0.55 of the walls) and lets it climb
## into view as the yard fills, which is right for a store that holds the whole run's
## catch. A delivery here is a handful — four to six pieces early on — and at the crate's
## floor a handful is entirely behind the wall, so the box never looked any different for
## being filled (found on the probe, 2026-09-13). So the floor is higher (HEAP_FLOOR, of
## BOX_TALL, the walls at this sheet's scale), the scatter is held to the middle of the
## mouth where the near rim is lowest (HEAP_SCATTER of the mouth's half-axes), and the pile
## steps up every HEAP_LAYER pieces by HEAP_STEP world px, so the first piece shows over
## the rim and the rest heap up from there. HEAP_CLIMB is how far `drop_point` rises over
## the fill; the pieces are drawn at HEAP_SIZE, four fifths of the island's 0.62, because
## this box is four fifths of that one.
const DRAIN_HOLD := 3.0
const DRAIN_EVERY := 0.6
const BOX_TALL := (Yard.ART_GROUND - Yard.ART_TOP) * ART_SCALE
const HEAP_FLOOR := 0.72
const HEAP_CLIMB := 0.5
const HEAP_SCATTER := 0.45
const HEAP_DRAWN := 20
const HEAP_SIZE := 0.5
const HEAP_LAYER := 4
const HEAP_STEP := 4.8

## The name on the sign: the size it is set at in world px, stepped down until it fits the
## plank less SIGN_PAD each side, never under SIGN_LEAST on the screen, and its ink — the
## ribbons' cream, which is what lettering on this game's wood is. Set at the zoom's own
## size rather than scaled through it (`_draw_sign`), so the glyphs are rasterised at the
## pixels they land on instead of being shrunk from a bigger drawing.
const SIGN_TEXT := 18.0
const SIGN_LEAST := 6
const SIGN_PAD := 3.0
const SIGN_INK := Style.RIBBON_INK

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

## The heap: def indices landed here, oldest first, and the drain's two clocks — how long
## since the last piece came down, and how far into the next piece's going the drain is.
var _held := PackedInt32Array()
var _since_landed := 0.0
var _drain_clock := 0.0
## The box's two near walls and rim, cut from the sheet's own box (emblem and all, which is
## why it is not cut from Recycle_Box.png), drawn again over the heap so the catch is inside
## the box rather than stuck on its face. Made the first time it is needed.
var _front: Texture2D
var _heap_rng := RandomNumberGenerator.new()


func kind_name() -> String:
	return TrashDef.KIND_NAMES[kind]


## What the plank says: the material's name through the translation server, so a language
## file with an entry for "Plastic" changes the sign without touching the sheet.
func sign_text() -> String:
	return tr(kind_name())


## A piece the ferry landed here: onto the heap. The lake pays for it; this only shows it.
func put(def_index: int) -> void:
	_held.append(def_index)
	_since_landed = 0.0
	_drain_clock = 0.0
	queue_redraw()


## How many pieces are in the box right now.
func held_count() -> int:
	return _held.size()


## How full the box looks, 0 to 1. Past CRATE_FULL the heap simply stops rising.
func fill() -> float:
	return clampf(float(_held.size()) / float(Yard.CRATE_FULL), 0.0, 1.0)


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


## Where a piece landed off a ferry should come down: into the box's mouth, on the heap.
##
## The json's `drop` is the middle of the mouth. The heap's top starts HEAP_FLOOR of the
## walls up from the ground — that much below the mouth's middle, just behind the near
## rim — and climbs HEAP_CLIMB of the walls as the box fills, to a little proud of the rim:
## the island crate's rule (Yard.drop_point) at this box's numbers. It used to be the box's
## ground point (2026-09-12), and every delivery came down on the box's bottom edge.
func drop_point() -> Vector2:
	var book := _book()
	if book.is_empty():
		return place() + Vector2(0.0, -12.0)
	return _world(book["drop"], book) + Vector2(
		0.0, BOX_TALL * ((1.0 - HEAP_FLOOR) - HEAP_CLIMB * fill())
	)


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
			# The middle of the post, not its left edge: `_world` gives the top-left corner
			# of the foot pixel, and a mound centred there sits half an art pixel left of
			# the pole and leaves a column of wood showing down its right side.
			var wide := (float(post[2]) if (post as Array).size() > 2 else POST_WIDE / ART_SCALE) * ART_SCALE
			var at := _world(post, book) + Vector2(ART_SCALE * 0.5, 0.0)
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
				_mounds.append(Skirt.mound(at, wide, 9101 + kind * 131 + i))
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


func _process(delta: float) -> void:
	_drain(delta)
	if _under == null:
		return
	# The water moves under the jetty every frame: the wet shadow and the collars with it.
	var rise := swell()
	for i in _collars.size():
		_collars[i].position = _collar_feet[i] + Vector2(0.0, rise)
	_under.queue_redraw()
	if day != null:
		queue_redraw()


## The heap sinking away while the ferry is gone: nothing until DRAIN_HOLD after the last
## piece landed, then one piece every DRAIN_EVERY, oldest first. Time-based rather than
## tied to the ferry's state, so a second hull unloading here while the first is away
## simply tops the heap up and restarts the hold.
func _drain(delta: float) -> void:
	if _held.is_empty():
		return
	_since_landed += delta
	if _since_landed < DRAIN_HOLD:
		return
	_drain_clock += delta
	var gone := 0
	while _drain_clock >= DRAIN_EVERY and not _held.is_empty():
		_drain_clock -= DRAIN_EVERY
		_held.remove_at(0)
		gone += 1
	if gone > 0:
		queue_redraw()


func _draw() -> void:
	var book := _book()
	if book.is_empty():
		_draw_blocked()
		return
	if day != null and _box_cast != null and _box_image != null:
		# The box stands on the deck: its shadow is swept from its base there, the way the
		# island's crate is swept from its own (Yard._draw), so the two crates cast alike.
		_box_cast.lay(
			_box_image, _box_rect(book), day.lean, day.stretch,
			1.0 - Yard.ART_GROUND / float(maxi(_box_image.get_height(), 1)), day.ink
		)
	draw_texture_rect_region(_sheet, _frame(book), _rect(book["region"]))
	_draw_heap(book)
	_draw_sign(book)


## Where the box is drawn, in world px.
func _box_rect(book: Dictionary) -> Rect2:
	var box := _rect(book["box"])
	var frame := _frame(book)
	return Rect2(frame.position + box.position * ART_SCALE, box.size * ART_SCALE)


## The catch in the box: the island crate's heap (Yard._draw_heap) at this box's size.
## Scattered inside the mouth's diamond and stacked upward as it fills, drawn back to front,
## then the box's near walls over the top of it, which is what puts the heap inside.
func _draw_heap(book: Dictionary) -> void:
	if grid == null or _held.is_empty() or not book.has("box"):
		return
	var ground := _world(book["box_ground"], book)
	var mouth := Vector2(32.0, 16.0) * ART_SCALE
	# Fixed seed: the pile's scatter should not reshuffle itself every time a piece lands.
	_heap_rng.seed = 90210 + kind
	var count := mini(_held.size(), HEAP_DRAWN)
	var floor_at := ground.y - BOX_TALL * HEAP_FLOOR
	var spots: Array[Vector2] = []
	for i in count:
		var angle := _heap_rng.randf_range(0.0, TAU)
		var reach := sqrt(_heap_rng.randf()) * HEAP_SCATTER
		spots.append(Vector2(
			ground.x + cos(angle) * mouth.x * 0.5 * reach,
			floor_at + sin(angle) * mouth.y * 0.5 * reach - float(i / HEAP_LAYER) * HEAP_STEP
		))
	spots.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)
	for i in count:
		draw_set_transform(spots[i], _heap_rng.randf_range(-0.2, 0.2), Vector2(HEAP_SIZE, HEAP_SIZE))
		grid.defs[_held[i]].stamp_iso(self)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var front := _front_cut(book)
	if front != null:
		draw_texture_rect(front, _box_rect(book), false)


## The near walls of this yard's own box, cut off the sheet the first time they are asked
## for: Yard's cut, so the two boxes hide their heaps behind the same rim.
func _front_cut(book: Dictionary) -> Texture2D:
	if _front == null and _sheet != null:
		var image := _sheet.get_image()
		if image != null:
			var region := _rect(book["region"])
			var box := _rect(book["box"])
			_front = Yard._cut_front(image.get_region(Rect2i(region.position + box.position, box.size)))
	return _front


## The sign: its shadow laid down from the post's foot, then the name on the plank.
func _draw_sign(book: Dictionary) -> void:
	if not book.has("sign"):
		return
	var frame := _frame(book)
	if day != null and book.has("sign_cut") and book.has("sign_foot"):
		# A billboard on a post lies down from its foot, sheared, like the angler does —
		# the sweep is for solids that end in a V. Drawn by this node rather than `Under`,
		# so it falls across the deck top and the box the way a shadow on the deck does.
		var at := _world(book["sign_foot"], book)
		draw_set_transform_matrix(Shade.lying(at, day.lean, day.stretch))
		draw_texture_rect_region(
			_sheet, Rect2(frame.position - at, frame.size), _rect(book["sign_cut"]),
			Shade.tint(day.ink)
		)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# The name, rasterised at the size it lands on the screen at: the drawing is done in
	# screen pixels under a transform that undoes the zoom, so the glyphs are the font's own
	# at that size rather than a bigger drawing shrunk through the camera. The zoom is read
	# off this node's own path to the screen, stretch and all.
	var plank := _rect(book["sign"])
	var board := Rect2(frame.position + plank.position * ART_SCALE, plank.size * ART_SCALE)
	var text := sign_text()
	var zoom := 1.0
	if is_inside_tree():
		zoom = maxf(
			get_global_transform_with_canvas().get_scale().x
			* get_viewport().get_final_transform().get_scale().x,
			0.01
		)
	var room := (board.size.x - SIGN_PAD * 2.0) * zoom
	var size_px := maxi(roundi(SIGN_TEXT * zoom), SIGN_LEAST)
	while size_px > SIGN_LEAST and Style.measure(text, size_px).x > room:
		size_px -= 1
	draw_set_transform(board.position, 0.0, Vector2.ONE / zoom)
	var box := Rect2(Vector2.ZERO, board.size * zoom)
	# The baseline sits a little under the plank's middle, the money plate's own rule for a
	# figure on a slab.
	Style.write(
		self, text, size_px, Vector2(0.0, box.size.y * 0.5 + float(size_px) * 0.35),
		SIGN_INK, HORIZONTAL_ALIGNMENT_CENTER, box
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
		draw_texture_rect_region(Dropoff._sheet, frame, Dropoff._rect(book["under"]))
		# The sand before the shadow, the posts before the sand: the sand is heaped against
		# a pole, so it covers the pole's own bottom row, and it is ground, so the pier's
		# shadow falls on it. Drawn after the shadow it stood out in full daylight colour
		# inside the shade the platform throws — a handful of bright grains on dark sand.
		for mound in yard._mounds:
			mound.over(self)
		if yard.day == null:
			return
		var day := yard.day
		var up := float(book["deck_up"]) * Dropoff.ART_SCALE
		# A point `up` above the ground lands this far from the ground point (Shade.lying's
		# transform on a point at that height); the deck top's silhouette is drawn `up`
		# above its footprint, so the footprint is that much lower first.
		var slide := Vector2(day.lean * up, day.stretch * 0.5 * up + up)
		# Over the posts as well as the ground, and rightly: a post stands under the deck
		# and is in the deck's own shade.
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
