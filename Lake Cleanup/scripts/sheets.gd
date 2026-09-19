## The art: several packed sheets, cut into named pieces, welded into one texture.
##
## Everything drawn in this game that is not a polygon comes from here — the rubbish
## floating in the lake, the pile in the yard, the load on the ferry, and the furniture the
## player drags into the shed. It is one texture on purpose: the lake draws its whole
## visible surface as a single triangle array, and a triangle array carries exactly one
## texture. Two atlases would be two draw calls and the door open to twenty.
##
## The regions themselves are not worked out here. tools/slice_sheets.gd cuts the rubbish
## sheets and tools/build_decor.py packs the decoration ones, both offline, both writing
## assets/pieces.json; this reads that, blits the sheets into one image, and offsets every
## region into the combined space.
class_name Sheets
extends RefCounted

const CATALOGUE := "res://assets/pieces.json"

## The lake shows a find grimy and the shed shows it restored, which is the whole story of
## the game in two pictures. Those two are no longer the same picture twice: the decoration
## art draws the grimy version once and the restored one as several views — a chair from
## the front, the side and the back — at their own sizes. So a piece carries a rectangle on
## its own sheet and a list of rectangles on the restored one, and the catalogue says which
## sheet each of those is on rather than this file assuming a parallel copy.

## A block of solid white is packed into the atlas so untextured geometry — the ring of
## disturbed water each piece sits in — can be drawn by the same batch instead of needing
## a second one.
const WHITE_SIZE := 8

## What counts as a floor covering, matched against the piece's title. The art has names, so
## there is nothing to infer: a rug is a rug because it is called one.
const FLAT_WORDS := ["rug", "mat"]

## What a set of views means, and so which verb the shed offers for it.
##
## Several sprites under one name are three different mechanics wearing the same shape, and
## nothing in the pixels tells them apart — see tools/decor_sets.json, where a person says
## which is which.
## Where a find may go in the shed. Authored per piece (Richard, 2026-09-13).
enum Place {
	## Stands on the boards. Nothing else stands where its base is, as far as the walkers
	## are concerned.
	FLOOR,
	## Hangs on the back wall and takes no floor at all: the paintings.
	WALL,
	## Stands on the floor, but may be set over a big piece and is drawn just after
	## whatever it sits on: pots, the table lamp, the clock, the chew toy, the globe.
	SMALL,
}

enum Set {
	## One view. Nothing to cycle.
	SINGLE,
	## The same piece from several sides. R turns it while it is being carried.
	ROTATE,
	## Several styles of the same thing. R picks one. Not a rotation.
	VARIANT,
	## The same piece doing two things. E toggles it where it stands.
	STATE,
}

var atlas: ImageTexture

## Piece name -> its rectangle in the atlas, in pixels.
var regions := {}

## Piece name -> its rectangle in the cleaned-up palette, where one exists. Falls back to
## the grimy region for anything that is not a decoration.
##
## The first of `views` — a piece's default face, which is what anything that does not care
## about views (the trophy shelf, an inventory row) wants.
var alt_regions := {}

## Piece name -> every restored view of it, in cycle order. One entry for a piece that has
## only the one.
##
## The order is the authored one: front, side, back, and the flipped side last where the
## art gets one, which reads as turning a chair a quarter at a time. See
## tools/decor_sets.json.
var views := {}

## Piece name -> what each view is called, alongside `views`. `on` and `off` for the
## fireplace, `shut` and `open` for the fridge, `round` and `oval` for the pet beds.
var roles := {}

## Piece name -> which Set it is, and so what R and E do with it.
var kinds := {}

## Piece name -> how many of it are hidden in the lake, and so how many the shed may hold.
## One for everything but the chairs. See tools/decor_sets.json.
var copies := {}

## Where a piece goes, and so what the shed lets it do. See tools/decor_sets.json and
## `Place`.
var places := {}

## Piece name -> how many of each view's bottom rows of cells stand on the floor, in view
## order. Empty for a piece the catalogue says nothing about; see `base_of` for the default.
var bases := {}

## Piece name -> the same thing measured in the drawing's own **pixels**, for the few pieces
## a whole cell is too coarse for (2026-09-19, issue #30). A cell is eight of these, so the
## smallest base a cell can say is a third of a pot's height, which held the pot eight
## pixels off the back wall with nothing drawn in the gap.
##
## Only where the catalogue authors one; `base_of` is still the cells for everything else,
## and the two are never both authored for one piece. Empty is "says nothing", which is why
## the accessor is a has/get pair rather than a number with a sentinel.
var bases_px := {}

## Piece name -> where a dog's feet go on each view, in the drawing's own pixels, measured
## up from the picture's bottom edge (2026-09-19, issue #30). Authored only on the views a
## dog can be drawn lying on without being cropped — a sofa seen from its back has none —
## and a piece with no seat at all is simply not a thing to lie on. See `ShedRoom`.
var seats := {}

## Piece name -> how many times bigger than painted the shed draws it. One for nearly
## everything; the bed is 1.5. The lake never reads it.
var scales := {}

## Piece name -> what to call it on screen.
##
## Baked into the catalogue by tools/build_decor.py from the authored table, rather than
## kept in a second file keyed on slicer output. A reward the game cannot name is a reward
## the player cannot want, and a name that lives next to the rectangle cannot drift from it.
var titles := {}

## Piece name -> its size on the drawing grid, in whole 16 px cells. A rounded-up hint from
## the catalogue; the shed lays out on a finer grid of its own through `footprint`.
var cells := {}

## Piece name -> how much of its own box it covers, 0 to 1. A rug is a solid rectangle and
## fills nearly all of it; a chair is mostly the gaps between its legs.
var fill := {}

## Every piece, and every piece from each sheet, in catalogue order.
var names := PackedStringArray()
var by_sheet := {}

## The solid white block, for geometry that wants a colour and no picture.
var white := Rect2()

var _size := Vector2.ONE


## Read the catalogue and build the atlas. False means the art is missing or unreadable,
## and the caller falls back to the blocked-in placeholder pieces it drew before.
func load_all() -> bool:
	var text := FileAccess.get_file_as_string(CATALOGUE)
	if text.is_empty():
		return false
	var book: Dictionary = JSON.parse_string(text)
	if book == null or not book.has("pieces"):
		return false

	# The sheets, in a fixed order, each stacked under the last.
	var sheets: Dictionary = book["sheets"]
	var keys := sheets.keys()
	keys.sort()
	var images := {}
	var offsets := {}
	var width := 0
	var height := 0
	for key: String in keys:
		var image := Art.image(String((sheets[key] as Dictionary)["file"]))
		if image == null:
			return false
		image.convert(Image.FORMAT_RGBA8)
		images[key] = image
		offsets[key] = Vector2i(0, height)
		width = maxi(width, image.get_width())
		height += image.get_height()

	var white_offset := Vector2i(0, height)
	height += WHITE_SIZE
	width = maxi(width, WHITE_SIZE)

	var sheet_image := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	sheet_image.fill(Color(0.0, 0.0, 0.0, 0.0))
	for key: String in keys:
		var image: Image = images[key]
		sheet_image.blit_rect(
			image, Rect2i(Vector2i.ZERO, image.get_size()), offsets[key] as Vector2i
		)
	sheet_image.fill_rect(
		Rect2i(white_offset, Vector2i(WHITE_SIZE, WHITE_SIZE)), Color(1.0, 1.0, 1.0, 1.0)
	)

	# The middle of the white block, not its edge: sampling on a seam picks up whatever is
	# next to it once the texture is filtered or the view is zoomed.
	white = Rect2(
		Vector2(white_offset) + Vector2.ONE * float(WHITE_SIZE) * 0.25,
		Vector2.ONE * float(WHITE_SIZE) * 0.5
	)

	var cell := float(book.get("cell", 16))
	for entry: Dictionary in book["pieces"]:
		var name := String(entry["name"])
		var key := String(entry["sheet"])
		var box: Array = entry["region"]
		var offset: Vector2i = offsets[key]
		var region := Rect2(
			float(box[0]) + float(offset.x), float(box[1]) + float(offset.y),
			float(box[2]), float(box[3])
		)
		regions[name] = region

		# The restored views, each on whatever sheet the catalogue puts it on and at its own
		# size. A piece with none — the rubbish, which is never restored — stands as itself.
		var faces: Array[Rect2] = []
		var alt_key := String(entry.get("alt_sheet", ""))
		if offsets.has(alt_key):
			var alt_offset: Vector2i = offsets[alt_key]
			for view: Array in entry.get("alt_views", []) as Array:
				faces.append(Rect2(
					float(view[0]) + float(alt_offset.x), float(view[1]) + float(alt_offset.y),
					float(view[2]), float(view[3])
				))
		if faces.is_empty():
			faces.append(region)
		views[name] = faces
		alt_regions[name] = faces[0]
		roles[name] = PackedStringArray(entry.get("alt_roles", ["front"]))
		kinds[name] = _set_of(String(entry.get("set", "SINGLE")))
		copies[name] = maxi(int(entry.get("copies", 1)), 1)
		titles[name] = String(entry.get("title", ""))
		places[name] = _place_of(String(entry.get("place", "floor")))
		scales[name] = maxf(float(entry.get("scale", 1.0)), 0.1)
		var depths := PackedInt32Array()
		for depth in entry.get("base", []) as Array:
			depths.append(maxi(int(depth), 1))
		bases[name] = depths
		var pixels := PackedInt32Array()
		for depth in entry.get("base_px", []) as Array:
			pixels.append(maxi(int(depth), 1))
		bases_px[name] = pixels
		var rests := PackedInt32Array()
		# A seat of 0 means "no seat on this view", which is how a sofa's side and back
		# faces opt out while its front opts in. So this one is floored at 0, not at 1.
		for lift in entry.get("seat", []) as Array:
			rests.append(maxi(int(lift), 0))
		seats[name] = rests

		cells[name] = Vector2i(
			maxi(int(ceil(float(box[2]) / cell)), 1), maxi(int(ceil(float(box[3]) / cell)), 1)
		)
		fill[name] = float(entry.get("fill", 1.0))
		names.append(name)
		# Read out, appended to, put back: a packed array is a value in GDScript, so
		# appending to what the dictionary hands over appends to a copy of it.
		var listed: PackedStringArray = by_sheet.get(key, PackedStringArray())
		listed.append(name)
		by_sheet[key] = listed

	atlas = ImageTexture.create_from_image(sheet_image)
	_size = Vector2(sheet_image.get_width(), sheet_image.get_height())
	return not regions.is_empty()


func has(name: StringName) -> bool:
	return regions.has(String(name))


func region_of(name: StringName) -> Rect2:
	return regions.get(String(name), white) as Rect2


func alt_region_of(name: StringName) -> Rect2:
	return alt_regions.get(String(name), region_of(name)) as Rect2


## The catalogue's word for a set, as a Set. Anything unrecognised is one view.
func _set_of(word: String) -> Set:
	match word:
		"ROTATE":
			return Set.ROTATE
		"VARIANT":
			return Set.VARIANT
		"STATE":
			return Set.STATE
		_:
			return Set.SINGLE


func _place_of(word: String) -> Place:
	match word:
		"wall":
			return Place.WALL
		"small":
			return Place.SMALL
		_:
			return Place.FLOOR


## How many times bigger than painted the shed draws a piece.
func scale_of(name: StringName) -> float:
	return float(scales.get(String(name), 1.0))


## How big one restored view is drawn in the shed, in source pixels: the art times the
## piece's scale. Every shed measurement — footprint, stamp, ghost — goes through this.
func view_size_of(name: StringName, view: int) -> Vector2:
	return view_region_of(name, view).size * scale_of(name)


func place_of(name: StringName) -> Place:
	return places.get(String(name), Place.FLOOR) as Place


## Does this piece hang on the back wall rather than stand on the floor?
func on_wall(name: StringName) -> bool:
	return place_of(name) == Place.WALL


## May this piece be set over a bigger one?
func is_small(name: StringName) -> bool:
	return place_of(name) == Place.SMALL


## How many of a view's bottom rows of cells stand on the floor; the rest of the picture
## is the piece's height, and may rise up the back wall.
##
## The catalogue's number where it gives one. Otherwise the whole picture for anything
## lying flat — a rug is all floor — and one row for everything else, which is what the
## shed assumed for every piece before the bases were authored. Never more than the view
## is tall.
##
## A handful of pieces author their base in pixels instead — see `base_px_of`. This
## function knows nothing about them: the caller asks `has_base_px` first, because `cell`
## here is a clamp granularity and not a unit, and asking this at a granularity of one
## would hand every cell-authored base back as pixels.
func base_of(name: StringName, view: int, cell: int) -> int:
	var tall := _cells_across(view_size_of(name, view), cell).y
	var depths: PackedInt32Array = bases.get(String(name), PackedInt32Array())
	if depths.is_empty():
		return tall if lies_flat(name) else mini(1, tall)
	return mini(depths[posmod(view, depths.size())], tall)


## Whether this view's base is authored in pixels rather than in cells.
func has_base_px(name: StringName, view: int) -> bool:
	var pixels: PackedInt32Array = bases_px.get(String(name), PackedInt32Array())
	return not pixels.is_empty() and pixels[posmod(view, pixels.size())] > 0


## That base, in the drawing's own pixels. Ask `has_base_px` first: an unauthored piece
## answers 0 here, and 0 is not a base.
##
## Clamped to the drawn height the way `base_of` is, and for the same reason: the number is
## authored by eye against the art, and the art can be re-cut under it.
func base_px_of(name: StringName, view: int) -> int:
	var pixels: PackedInt32Array = bases_px.get(String(name), PackedInt32Array())
	if pixels.is_empty():
		return 0
	return mini(pixels[posmod(view, pixels.size())], int(view_size_of(name, view).y))


## How far up this view's picture a dog's feet go, in the drawing's own pixels from its
## bottom edge, or 0 for a view nothing may lie on.
##
## Measured against the **drawn** size, so it already carries `scale_of` — the bed is drawn
## at 1.5 and a seat read as raw art pixels would be half again too low on it.
func seat_of(name: StringName, view: int) -> int:
	var rests: PackedInt32Array = seats.get(String(name), PackedInt32Array())
	if rests.is_empty():
		return 0
	return mini(rests[posmod(view, rests.size())], int(view_size_of(name, view).y))


## Is there any view of this piece a dog may lie on? Asked when the shed builds its seat
## table, so a piece nobody authored a seat for is never walked to.
func has_seat(name: StringName) -> bool:
	for lift in seats.get(String(name), PackedInt32Array()) as PackedInt32Array:
		if lift > 0:
			return true
	return false


## How many restored faces a piece has. One means there is nothing for R or E to do.
func view_count(name: StringName) -> int:
	var faces: Array = views.get(String(name), []) as Array
	return maxi(faces.size(), 1)


## One restored view of a piece, by index. Out-of-range wraps, so a caller can add one and
## hand it straight back without knowing how long the cycle is.
func view_region_of(name: StringName, view: int) -> Rect2:
	var faces: Array = views.get(String(name), []) as Array
	if faces.is_empty():
		return alt_region_of(name)
	return faces[posmod(view, faces.size())] as Rect2


## What one view is called: `side`, `on`, `open`, `oval`.
func role_of(name: StringName, view: int) -> StringName:
	var list: PackedStringArray = roles.get(String(name), PackedStringArray())
	if list.is_empty():
		return &"front"
	return StringName(list[posmod(view, list.size())])


func kind_of(name: StringName) -> Set:
	return kinds.get(String(name), Set.SINGLE) as Set


## How many of this find there are to net. One for anything that does not say otherwise.
func copies_of(name: StringName) -> int:
	return maxi(int(copies.get(String(name), 1)), 1)


## Can the player turn this piece while carrying it? Both R verbs, since picking a style and
## turning a chair are the same gesture from the player's side.
func turnable(name: StringName) -> bool:
	var kind := kind_of(name)
	return (kind == Set.ROTATE or kind == Set.VARIANT) and view_count(name) > 1


## Can the player switch this piece on where it stands? The fireplace and the fridge.
func switchable(name: StringName) -> bool:
	return kind_of(name) == Set.STATE and view_count(name) > 1


## What to call this piece on screen. Empty for anything with no name — the rubbish, which
## is counted rather than collected.
func title_of(name: StringName) -> String:
	return String(titles.get(String(name), ""))


func cells_of(name: StringName) -> Vector2i:
	return cells.get(String(name), Vector2i.ONE) as Vector2i


func fill_of(name: StringName) -> float:
	return float(fill.get(String(name), 1.0))


## How many cells of a given size a piece covers, rounded to the nearest rather than up.
##
## Rounding up is what a tile map does, and it is wrong for furniture: a chair 27 pixels
## across is not two whole cells wide, and rounding it up leaves a cell of dead floor
## nobody can put anything in. Rounded to nearest, a footprint is the object.
func footprint(name: StringName, cell: int) -> Vector2i:
	return _cells_across(region_of(name).size, cell)


## The same, for one restored view.
##
## The shed has to ask this rather than `footprint`: a piece's grimy sprite and its restored
## views are different pictures at different sizes now, and a sofa turned side-on is a third
## of the width it is head-on. Measuring the floor it takes up off the lake's sprite left a
## chair standing in a footprint drawn for a sofa.
func footprint_view(name: StringName, view: int, cell: int) -> Vector2i:
	return _cells_across(view_size_of(name, view), cell)


func _cells_across(box: Vector2, cell: int) -> Vector2i:
	return Vector2i(
		maxi(int(round(box.x / float(cell))), 1), maxi(int(round(box.y / float(cell))), 1)
	)


## Does this piece lie on the floor rather than stand on it?
##
## Read off the find's own name rather than guessed from the pixels: a rug drawn with a
## fringe or a hole in the middle does not fill its box, and guessing gave it a collider and
## drew it over the armchair standing on it. Anything called a rug or a mat is floor.
func lies_flat(name: StringName) -> bool:
	var title := title_of(name).to_lower()
	for word: String in FLAT_WORDS:
		if title.contains(word):
			return true
	return false


## A pixel rectangle as texture coordinates. What the batched lake surface hands the GPU.
func uv_of(box: Rect2) -> Rect2:
	return Rect2(box.position / _size, box.size / _size)


## One piece as a texture in its own right, for the HUD: buttons and inventory rows want
## something they can hand to a TextureRect rather than a rectangle they have to draw.
func texture_of(name: StringName, cleaned: bool = false) -> AtlasTexture:
	var cut := AtlasTexture.new()
	cut.atlas = atlas
	cut.region = alt_region_of(name) if cleaned else region_of(name)
	return cut
