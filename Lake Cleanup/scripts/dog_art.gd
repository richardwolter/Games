## The dog's pictures: one sheet, read once, drawn by whoever needs a dog.
##
## There are two dogs in this game and they are the same animal — the one that swims the
## lake and fetches, and the one asleep on the rug when the player opens the shed. They are
## driven by completely different code (one lives on the tile field, the other inside a
## drawn room) and there is no sense in each of them learning to read a sprite sheet.
##
## So the sheets live here, static, loaded on the first ask and shared from then on. What a
## caller gets is `stamp`: a frame of a named animation, standing on a point, at a height it
## chooses, facing whichever way it says.
##
## Three breeds since 2026-09-22 (Richard's pick off the Pixel Dogs pack): one cut sheet and
## one json each, under assets/dogs/. Every call takes a `breed` index into BREEDS and
## defaults to 0, the orange dog, so a caller that never heard of breeds — the shop head, the
## HUD button — draws one dog and the same one every time. The pack hands them out in order — see `Dog.breed`.
##
## No `class_name`, for the same reason style.gd has none: consumers preload it, and a global
## class is registered into an editor-written cache that a headless tool run can find stale.
extends RefCounted

## The cut sheets, by breed. tools/slice_dog.gd writes them. Index 0 is the orange dog; the
## yellow one the game shipped with until 2026-09-22 (pack sheet 22) is not among them.
const BREEDS := [2, 20, 14]
const ART := "res://assets/dogs/dog_%02d.json"

## The animations the sheet was cut into, and how long a frame of each is held.
##
## Sleeping is slow because it is breathing rather than moving; the run is quick because it
## is a gallop and a gallop drawn at a walk's rate reads as a dog in treacle.
const HELD := {
	&"idle": 0.16,
	&"sit": 0.16,
	&"laid": 0.22,
	&"run": 0.07,
	&"walk": 0.1,
	&"run2": 0.07,
	&"walk2": 0.1,
	&"sleep": 0.5,
}

## The two gaits the sheet carries, by which of the pair a dog runs on. Dogs in the odd slots
## of the pack use the second pair, so four dogs on one beach do not run in step.
const GAITS := [[&"run", &"walk"], [&"run2", &"walk2"]]

## One breed's sheet the right way round and mirrored, and its frames keyed on animation
## name — one of these per breed, in `_books`, loaded on the first ask.
##
## Mirrored as a second texture rather than drawn with a negative scale, the same as the
## angler: a flipped draw transform also flips everything else the caller is drawing in that
## pass, and a dog that turns round should not take the water with it.
##
## Every dog on these sheets is drawn facing LEFT. That is why `stamp` mirrors when it is
## told the dog is facing right and not the other way round — the untouched sheet already is
## the left-facing one.
class Book:
	var sheet: Texture2D
	var mirror: Texture2D
	var wide: float = 1.0
	var frames := {}

static var _books := {}
static var _read := {}


## Load a breed's sheet. False means no art, and every caller falls back to its own
## placeholder.
static func ready(breed: int = 0) -> bool:
	breed = clampi(breed, 0, BREEDS.size() - 1)
	if _read.has(breed):
		return _books.has(breed)
	_read[breed] = true
	var text := FileAccess.get_file_as_string(ART % int(BREEDS[breed]))
	if text.is_empty():
		return false
	var page: Variant = JSON.parse_string(text)
	if not (page is Dictionary) or not (page as Dictionary).has("sequences"):
		return false
	var image := Art.image(String((page as Dictionary)["sheet"]))
	if image == null:
		return false
	var book := Book.new()
	book.sheet = ImageTexture.create_from_image(image)
	book.wide = float(image.get_width())
	var turned := Image.create_from_data(
		image.get_width(), image.get_height(), false, image.get_format(), image.get_data()
	)
	turned.flip_x()
	book.mirror = ImageTexture.create_from_image(turned)

	var page_dict := page as Dictionary
	for name: String in page_dict["sequences"]:
		var frames: Array = []
		for cell: Dictionary in page_dict["sequences"][name]:
			var region: Array = cell["region"]
			var foot: Array = cell["foot"]
			var mouth: Array = cell.get("mouth", [0, 0])
			frames.append({
				"region": Rect2(region[0], region[1], region[2], region[3]),
				"foot": Vector2(foot[0], foot[1]),
				"mouth": Vector2(mouth[0], mouth[1]),
			})
		book.frames[StringName(name)] = frames
	if book.frames.is_empty():
		return false
	_books[breed] = book
	return true


## How many breeds there are to hand out, and which one the dog in a given pack slot wears:
## round the list in order, so the first dog is always the orange one.
static func breeds() -> int:
	return BREEDS.size()


static func breed_of(slot: int) -> int:
	return posmod(slot, BREEDS.size())


static func _book(breed: int) -> Book:
	breed = clampi(breed, 0, BREEDS.size() - 1)
	if not ready(breed):
		return null
	return _books[breed]


static func has(name: StringName, breed: int = 0) -> bool:
	var book := _book(breed)
	return book != null and book.frames.has(name)


static func _cell(name: StringName, frame: int, breed: int) -> Dictionary:
	var list: Array = _book(breed).frames[name]
	return list[posmod(frame, list.size())]


## How many frames an animation has. Zero for one the sheet does not carry.
static func length(name: StringName, breed: int = 0) -> int:
	if not has(name, breed):
		return 0
	return (_book(breed).frames[name] as Array).size()


## Which frame of an animation is showing at a given age, in seconds.
static func frame_at(name: StringName, age: float, breed: int = 0) -> int:
	var count := length(name, breed)
	if count <= 0:
		return 0
	var held := float(HELD.get(name, 0.12))
	return posmod(int(age / held), count)


## The run or the walk a dog in a given pack slot uses: the first pair for even slots, the
## second for odd. A breed missing the second pair falls back to the first.
static func gait(slot: int, walking: bool, breed: int = 0) -> StringName:
	var pair: Array = GAITS[posmod(slot, GAITS.size())]
	var name: StringName = pair[1 if walking else 0]
	if not has(name, breed):
		name = GAITS[0][1 if walking else 0]
	return name


## How tall a frame draws, as a fraction of the height the caller asks for.
##
## A sleeping dog is a third of the height of a standing one, and scaling every animation to
## the same drawn height would inflate the sleeper into a bear. So the height a caller passes
## is the height of the *standing* dog, and everything else keeps its own proportion against
## the first idle frame.
static func _scale_for(name: StringName, height: float, breed: int = 0) -> float:
	if not has(&"idle", breed):
		return 1.0
	var stand: Dictionary = (_book(breed).frames[&"idle"] as Array)[0]
	return height / maxf((stand["region"] as Rect2).size.y, 1.0)


## Draw one frame, standing on `at`.
##
## `sink` cuts the bottom off: 0 draws the whole dog, 0.4 draws the top 60 per cent of it and
## nothing below, which is how a dog in the water is a dog in the water. The cut is made in
## the region rather than by drawing something over the top, so what is underwater is not
## drawn at all and no other layer has to be ordered around it.
static func stamp(
	on: CanvasItem,
	name: StringName,
	frame: int,
	at: Vector2,
	height: float,
	facing_left: bool,
	sink: float = 0.0,
	tint: Color = Color.WHITE,
	breed: int = 0
) -> void:
	if not has(name, breed):
		return
	var book := _book(breed)
	var cell := _cell(name, frame, breed)
	var region: Rect2 = cell["region"]
	var foot: Vector2 = cell["foot"]
	var scale := _scale_for(name, height, breed)

	# The bottom of the picture comes off, and the box it is drawn in loses the same amount,
	# so what is left stays where it was rather than stretching down into the gap.
	var kept := clampf(1.0 - sink, 0.05, 1.0)
	var shown := Rect2(region.position, Vector2(region.size.x, region.size.y * kept))
	var size := shown.size * scale
	var corner := at - foot * scale

	# The sheet faces left, so the untouched pixels are the left-facing dog and it is the
	# right-facing one that has to be mirrored.
	if facing_left:
		on.draw_texture_rect_region(book.sheet, Rect2(corner, size), shown, tint)
		return
	# The mirrored sheet is the same pixels reversed, so a region on it is the original
	# region measured from the other edge.
	var flipped := Rect2(
		Vector2(book.wide - shown.position.x - shown.size.x, shown.position.y), shown.size
	)
	var back := at - Vector2((region.size.x - foot.x) * scale, foot.y * scale)
	on.draw_texture_rect_region(book.mirror, Rect2(back, size), flipped, tint)


## Where `stamp` cuts a frame, as the two ends of the cut edge: the bottom corners of the box
## it draws the kept part of the frame into. Same arguments, same arithmetic — the foam collar
## has to sit on the edge the picture actually ends at, not on a guess at the waterline.
static func cut_edge(
	name: StringName, frame: int, at: Vector2, height: float, facing_left: bool, sink: float,
	breed: int = 0
) -> Array:
	if not has(name, breed):
		return [at, at]
	var cell := _cell(name, frame, breed)
	var region: Rect2 = cell["region"]
	var foot: Vector2 = cell["foot"]
	var scale := _scale_for(name, height, breed)
	var kept := clampf(1.0 - sink, 0.05, 1.0)
	var size := Vector2(region.size.x, region.size.y * kept) * scale
	var corner := at - foot * scale
	if not facing_left:
		corner = at - Vector2((region.size.x - foot.x) * scale, foot.y * scale)
	var y := corner.y + size.y
	return [Vector2(corner.x, y), Vector2(corner.x + size.x, y)]


## What to hand `stamp` to bury the paws `rows` sheet pixels into grass: the sink fraction
## (the air under the feet plus those rows) and how far down to draw, so the cut lands on the
## ground line instead of lifting the dog.
static func bury(
	name: StringName, frame: int, height: float, rows: float, breed: int = 0
) -> Array:
	if not has(name, breed) or rows <= 0.0:
		return [0.0, 0.0]
	var cell := _cell(name, frame, breed)
	var region: Rect2 = cell["region"]
	var foot: Vector2 = cell["foot"]
	var cut := maxf(region.size.y - foot.y, 0.0) + rows
	return [cut / maxf(region.size.y, 1.0), rows * _scale_for(name, height, breed)]


## Where the dog's mouth is on a given frame, as an offset from the point it stands on.
##
## Measured, not guessed: tools/slice_dog.gd reads the jaws off every frame (the twin
## sheet's tongue for the height, the frame's own nose for the reach) and bakes them into
## the json, so the mouth rides the head through a gallop — up on the stretch, down on the
## gather — and what the dog is carrying rides with it. Until 2026-09-22 this was the first
## frame's leading edge at 0.86 of its width and 0.66 of its height, the same point whatever
## the legs were doing.
static func mouth(
	name: StringName, height: float, facing_left: bool, frame: int = 0, breed: int = 0
) -> Vector2:
	if not has(name, breed):
		return Vector2.ZERO
	var cell := _cell(name, frame, breed)
	var region: Rect2 = cell["region"]
	var foot: Vector2 = cell["foot"]
	var jaw: Vector2 = cell["mouth"]
	var scale := _scale_for(name, height, breed)
	# The mouth is measured on the left-facing sheet; mirrored, its reach is from the other
	# edge of the box.
	var reach := jaw.x - foot.x if facing_left else (region.size.x - jaw.x) - foot.x
	return Vector2(reach * scale, (jaw.y - foot.y) * scale)


## How wide and tall a frame draws, for callers that have to keep the dog clear of something.
static func span(name: StringName, height: float, breed: int = 0) -> Vector2:
	if not has(name, breed):
		return Vector2(height, height)
	var region: Rect2 = _cell(name, 0, breed)["region"]
	return region.size * _scale_for(name, height, breed)


## One frame of the dog as a picture something else can draw: the sheet and the rectangle on
## it. For the upgrades board, whose own five icons are all net parts — a row about the dog
## wants the dog on it rather than an empty square.
static func art_frame(name: StringName, frame: int, breed: int = 0) -> Dictionary:
	if not has(name, breed):
		return {}
	return {"sheet": _book(breed).sheet, "region": _cell(name, frame, breed)["region"]}
