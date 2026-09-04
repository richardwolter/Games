## The art: three packed sheets, cut into named pieces, welded into one texture.
##
## Everything drawn in this game that is not a polygon comes from here — the rubbish
## floating in the lake, the pile in the yard, the load on the ferry, and the furniture the
## player drags into the shed. It is one texture on purpose: the lake draws its whole
## visible surface as a single triangle array, and a triangle array carries exactly one
## texture. Two atlases would be two draw calls and the door open to twenty.
##
## The regions themselves are not worked out here. tools/slice_sheets.gd cuts the sheets
## offline and writes assets/pieces.json; this reads that, blits the sheets into one image,
## and offsets every region into the combined space.
class_name Sheets
extends RefCounted

const CATALOGUE := "res://assets/pieces.json"

## The furniture sheet has a second palette — the same items, drawn as if cleaned up. The
## lake shows the grimy one and the shed shows the restored one, which is the whole story
## of the game in two pictures.
const ALT_SHEET := "res://assets/TopDownHouse_FurnitureState2.png"
const ALT_KEY := "furniture"

## A block of solid white is packed into the atlas so untextured geometry — the ring of
## disturbed water each piece sits in — can be drawn by the same batch instead of needing
## a second one.
const WHITE_SIZE := 8

## What counts as a rug: covers almost all of its own box, and is bigger than a doormat.
const FLAT_FILL := 0.93
const FLAT_AREA := 900

var atlas: ImageTexture

## Piece name -> its rectangle in the atlas, in pixels.
var regions := {}

## Piece name -> its rectangle in the cleaned-up palette, where one exists. Falls back to
## the grimy region for anything that is not furniture.
var alt_regions := {}

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

	# The cleaned-up palette, laid in under the rest and indexed against the grimy sheet's
	# own regions: the two are the same picture twice.
	var alt := Art.image(ALT_SHEET)
	var alt_offset := Vector2i(0, height)
	if alt != null:
		alt.convert(Image.FORMAT_RGBA8)
		width = maxi(width, alt.get_width())
		height += alt.get_height()

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
	if alt != null:
		sheet_image.blit_rect(alt, Rect2i(Vector2i.ZERO, alt.get_size()), alt_offset)
	sheet_image.fill_rect(
		Rect2i(white_offset, Vector2i(WHITE_SIZE, WHITE_SIZE)), Color(1.0, 1.0, 1.0, 1.0)
	)

	atlas = ImageTexture.create_from_image(sheet_image)
	_size = Vector2(float(width), float(height))
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
		alt_regions[name] = region
		if alt != null and key == ALT_KEY:
			alt_regions[name] = Rect2(
				float(box[0]) + float(alt_offset.x), float(box[1]) + float(alt_offset.y),
				float(box[2]), float(box[3])
			)
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

	return not regions.is_empty()


func has(name: StringName) -> bool:
	return regions.has(String(name))


func region_of(name: StringName) -> Rect2:
	return regions.get(String(name), white) as Rect2


func alt_region_of(name: StringName) -> Rect2:
	return alt_regions.get(String(name), region_of(name)) as Rect2


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
	var box := region_of(name).size
	return Vector2i(
		maxi(int(round(box.x / float(cell))), 1), maxi(int(round(box.y / float(cell))), 1)
	)


## Does this piece lie on the floor rather than stand on it?
##
## Worked out from the art rather than written down: a rug is big and solid all the way to
## its edges, which nothing that stands on legs is. It only decides drawing order — what
## goes under what — so a wrong guess costs a rug drawn over a chair, not a rule the player
## runs into.
func lies_flat(name: StringName) -> bool:
	var box := region_of(name).size
	return fill_of(name) >= FLAT_FILL and box.x * box.y >= FLAT_AREA


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
