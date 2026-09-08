## The dog's pictures: one sheet, read once, drawn by whoever needs a dog.
##
## There are two dogs in this game and they are the same animal — the one that swims the
## lake and fetches, and the one asleep on the rug when the player opens the shed. They are
## driven by completely different code (one lives on the tile field, the other inside a
## drawn room) and there is no sense in each of them learning to read a sprite sheet.
##
## So the sheet lives here, static, loaded on the first ask and shared from then on. What a
## caller gets is `stamp`: a frame of a named animation, standing on a point, at a height it
## chooses, facing whichever way it says.
##
## No `class_name`, for the same reason style.gd has none: consumers preload it, and a global
## class is registered into an editor-written cache that a headless tool run can find stale.
extends RefCounted

## The cut sheet. tools/slice_dog.gd writes it.
const ART := "res://assets/dog.json"

## The animations the sheet was cut into, and how long a frame of each is held.
##
## Sleeping is slow because it is breathing rather than moving; the run is quick because it
## is a gallop and a gallop drawn at a walk's rate reads as a dog in treacle.
const HELD := {
	&"idle": 0.16,
	&"laid": 0.22,
	&"run": 0.07,
	&"walk": 0.1,
	&"sleep": 0.5,
}

## The sheet the right way round and mirrored, and the frames, keyed on animation name.
##
## Mirrored as a second texture rather than drawn with a negative scale, the same as the
## angler: a flipped draw transform also flips everything else the caller is drawing in that
## pass, and a dog that turns round should not take the water with it.
##
## Every dog on this sheet is drawn facing LEFT. That is why `stamp` mirrors when it is told
## the dog is facing right and not the other way round — the untouched sheet already is the
## left-facing dog.
static var _sheet: Texture2D
static var _mirror: Texture2D
static var _wide: float = 1.0
static var _frames := {}
static var _read := false


## Load the sheet. False means no art, and every caller falls back to its own placeholder.
static func ready() -> bool:
	if _read:
		return _sheet != null
	_read = true
	var text := FileAccess.get_file_as_string(ART)
	if text.is_empty():
		return false
	var book: Variant = JSON.parse_string(text)
	if not (book is Dictionary) or not (book as Dictionary).has("sequences"):
		return false
	var image := Art.image(String((book as Dictionary)["sheet"]))
	if image == null:
		return false
	_sheet = ImageTexture.create_from_image(image)
	_wide = float(image.get_width())
	var turned := Image.create_from_data(
		image.get_width(), image.get_height(), false, image.get_format(), image.get_data()
	)
	turned.flip_x()
	_mirror = ImageTexture.create_from_image(turned)

	var book_dict := book as Dictionary
	for name: String in book_dict["sequences"]:
		var frames: Array = []
		for cell: Dictionary in book_dict["sequences"][name]:
			var region: Array = cell["region"]
			var foot: Array = cell["foot"]
			frames.append({
				"region": Rect2(region[0], region[1], region[2], region[3]),
				"foot": Vector2(foot[0], foot[1]),
			})
		_frames[StringName(name)] = frames
	return not _frames.is_empty()


static func has(name: StringName) -> bool:
	return ready() and _frames.has(name)


## How many frames an animation has. Zero for one the sheet does not carry.
static func length(name: StringName) -> int:
	if not has(name):
		return 0
	return (_frames[name] as Array).size()


## Which frame of an animation is showing at a given age, in seconds.
static func frame_at(name: StringName, age: float) -> int:
	var count := length(name)
	if count <= 0:
		return 0
	var held := float(HELD.get(name, 0.12))
	return posmod(int(age / held), count)


## How tall a frame draws, as a fraction of the height the caller asks for.
##
## A sleeping dog is a third of the height of a standing one, and scaling every animation to
## the same drawn height would inflate the sleeper into a bear. So the height a caller passes
## is the height of the *standing* dog, and everything else keeps its own proportion against
## the first idle frame.
static func _scale_for(name: StringName, height: float) -> float:
	if not has(&"idle"):
		return 1.0
	var stand: Dictionary = (_frames[&"idle"] as Array)[0]
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
	tint: Color = Color.WHITE
) -> void:
	if not has(name):
		return
	var list: Array = _frames[name]
	var cell: Dictionary = list[posmod(frame, list.size())]
	var region: Rect2 = cell["region"]
	var foot: Vector2 = cell["foot"]
	var scale := _scale_for(name, height)

	# The bottom of the picture comes off, and the box it is drawn in loses the same amount,
	# so what is left stays where it was rather than stretching down into the gap.
	var kept := clampf(1.0 - sink, 0.05, 1.0)
	var shown := Rect2(region.position, Vector2(region.size.x, region.size.y * kept))
	var size := shown.size * scale
	var corner := at - foot * scale

	# The sheet faces left, so the untouched pixels are the left-facing dog and it is the
	# right-facing one that has to be mirrored.
	if facing_left:
		on.draw_texture_rect_region(_sheet, Rect2(corner, size), shown, tint)
		return
	# The mirrored sheet is the same pixels reversed, so a region on it is the original
	# region measured from the other edge.
	var flipped := Rect2(
		Vector2(_wide - shown.position.x - shown.size.x, shown.position.y), shown.size
	)
	var back := at - Vector2((region.size.x - foot.x) * scale, foot.y * scale)
	on.draw_texture_rect_region(_mirror, Rect2(back, size), flipped, tint)


## Where the dog's mouth is, as an offset from the point it stands on.
##
## Worked out from the frame rather than written down: the nose is the leading edge of the
## picture at about head height, which is true of every frame on this sheet whatever the legs
## are doing. Callers hang what the dog is carrying off this, so a fetched bottle swings from
## its face instead of floating beside its ribs.
static func mouth(name: StringName, height: float, facing_left: bool) -> Vector2:
	if not has(name):
		return Vector2.ZERO
	var list: Array = _frames[name]
	var cell: Dictionary = list[0]
	var region: Rect2 = cell["region"]
	var foot: Vector2 = cell["foot"]
	var scale := _scale_for(name, height)
	# The nose is at the left edge of the left-facing sheet; mirrored, it is at the right.
	# Pulled in a little from the very edge, which is the tip of the snout: what the dog is
	# holding is between its teeth, not balanced on the end of its nose.
	var reach := (region.size.x - foot.x if not facing_left else -foot.x) * 0.86
	return Vector2(reach * scale, -region.size.y * 0.66 * scale)


## How wide and tall a frame draws, for callers that have to keep the dog clear of something.
static func span(name: StringName, height: float) -> Vector2:
	if not has(name):
		return Vector2(height, height)
	var list: Array = _frames[name]
	var region: Rect2 = (list[0] as Dictionary)["region"]
	return region.size * _scale_for(name, height)
