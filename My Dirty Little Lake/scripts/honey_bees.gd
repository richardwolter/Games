## The bees round the angler while honey is running (2026-10-16, `/grill-me` with Richard;
## `Lake.HONEY_TIME`). **A buzzing escort** (2026-10-18, Richard's pick 3C off
## `tools/hive_look/last_honey.png`): every bee on a loop of its own (`ESCORT`: its own
## radius, height, speed, way round and tilt), so they cross, overtake and dip like real bees
## round a jar rather than wheeling round together. The bee is the lake's round bee
## (`BeeArt` `mini_fly`, the picked bee A) at one art px a world px.
##
## **Never on him**: every bee is kept `CLEAR` art px off the angler's own pixels (the frame he
## is drawn in this frame, read off his sheet and grown, `_mask_of`), pushed straight out from
## his chest until it is clear. A bee on his silhouette reads as something stuck to him.
##
## **How many is how long is left**: `ceil(BEES * left / Lake.HONEY_TIME)`, at most
## `BEES_MOST`, so a window just eaten buzzes with five and one running out thins to a single
## bee before it goes. The loops leave from the last one in `ESCORT` down; a bee leaving flies
## off up and out rather than blinking away.
##
## **A child of the angler**, so it walks with him, is sorted with him and is switched off
## with him under the settings pause (`Lake._world_frozen` holds the angler). A bee on the
## half of its loop up the screen is behind him and a step darker (`BEHIND`); the half down
## the screen is in front (`Front`, this node's child). **The back half is a second child of
## the angler, not of this node** (`HoneyBeesBack`, `show_behind_parent`): the flag puts a node
## behind its own parent, and this node draws nothing of the angler, so a back layer under it
## was drawn over his figure all the same. Drawing only: nothing reads a bee.
class_name HoneyBees
extends Node2D

## Bees at a full window, and the most there may be (an eaten jar on top of a running one).
## Five, down from eight (2026-10-19, Richard: fewer bees in general).
const BEES := 5
const BEES_MOST := 5
## Each escort bee's own loop, in world px off his feet: radius across, radius up and down,
## height over the feet, speed (its sign the way round), tilt, and where on the loop it
## starts. Loose and uneven on purpose (the sheet's own eight); the first are the last to go.
const ESCORT := [
	[30.0, 7.0, 30.0, 1.7, 0.08, PI], [28.0, 8.0, 20.0, -2.1, -0.06, 0.30],
	[34.0, 9.0, 14.0, 1.3, 0.05, 3.60], [24.0, 6.0, 37.0, -1.6, 0.0, 5.90],
	[36.0, 10.0, 8.0, 1.1, -0.05, 0.15], [18.0, 5.0, 10.0, -2.6, 0.08, 1.90],
	[26.0, 8.0, 20.0, 1.5, -0.08, 2.20], [40.0, 12.0, 24.0, -1.0, 0.04, 5.50],
]
## The buzz on top of the loop: a whole pixel up and down at this rate.
const BUZZ := 8.0
## How many world px clear of his outline a bee stays, and where it is pushed out from (his
## chest, this far over his feet). At most `CLEAR_MOST` px of pushing.
const CLEAR := 3
const CHEST := 22.0
const CLEAR_MOST := 40
const MASK_PAD := 6
## A bee behind him is a step darker.
const BEHIND := Color(0.84, 0.82, 0.80)
## How long a bee takes to fly off when the count drops, and how far up it goes.
const LEAVE := 0.7
const LEAVE_UP := 40.0
## The wings' beat: frames a second of `mini_fly`.
const FLAP := 12.0

## Seconds of honey left, set by the lake every frame.
var left := 0.0

## Live bees: `{slot, leave, at, behind, left}` (`leave` -1 while it escorts).
var _bees: Array[Dictionary] = []
var _clock := 0.0
## Whether the last frame drew anything: one more redraw clears the last bee away.
var _drawn := false
var _back: Layer
var _front: Layer
## The angler's sheet as an image, and his frames grown by `CLEAR`, keyed on the region.
var _sheet_image: Image
var _masks := {}
## The frame he is drawn in this frame (`Angler._frame`), asked once a frame.
var _shown := {}


## One half of the escort, drawn by the bees node.
class Layer extends Node2D:
	var bees: HoneyBees
	var behind := false

	func _draw() -> void:
		if bees != null:
			bees.draw_half(self, behind)


func _ready() -> void:
	# Behind the angler's own drawing, so it hangs off him beside this node. Deferred: the
	# angler may still be setting up his children when this one is readied.
	_back = Layer.new()
	_back.name = &"HoneyBeesBack"
	_back.bees = self
	_back.behind = true
	_back.show_behind_parent = true
	get_parent().add_child.call_deferred(_back)
	_front = Layer.new()
	_front.name = &"Front"
	_front.bees = self
	add_child(_front)


func _exit_tree() -> void:
	if is_instance_valid(_back) and not _back.is_queued_for_deletion():
		_back.queue_free()


## The layer drawing the half of the escort behind the angler. The harness asks.
func back_layer() -> Node2D:
	return _back


## How many bees a window this long wants.
static func wanted(seconds: float) -> int:
	if seconds <= 0.0:
		return 0
	return mini(ceili(float(BEES) * seconds / Lake.HONEY_TIME), BEES_MOST)


## How many are escorting now (not counting those flying off). The harness asks.
func orbiting() -> int:
	var n := 0
	for bee: Dictionary in _bees:
		if float(bee["leave"]) < 0.0:
			n += 1
	return n


func _process(delta: float) -> void:
	_clock += delta
	_shown = {}
	var angler := get_parent()
	if not _bees.is_empty() or left > 0.0:
		if angler is Angler:
			var sunk: float = angler.call(&"_wading")
			_shown = angler.call(&"_frame", sunk, 0.0 if sunk > 0.0 else Angler.LAND_SINK, true)
	var want := wanted(left)
	var taken := {}
	for bee: Dictionary in _bees:
		if float(bee["leave"]) < 0.0:
			taken[int(bee["slot"])] = true
	# The lowest free loops come first; the highest loops leave first.
	var slot := 0
	while taken.size() < want and slot < ESCORT.size():
		if not taken.has(slot):
			taken[slot] = true
			_bees.append({"slot": slot, "leave": -1.0, "at": Vector2.ZERO, "behind": false, "left": false})
		slot += 1
	while taken.size() > want:
		var top := -1
		for s: int in taken.keys():
			top = maxi(top, s)
		taken.erase(top)
		for bee: Dictionary in _bees:
			if int(bee["slot"]) == top and float(bee["leave"]) < 0.0:
				bee["leave"] = 0.0
	for i in range(_bees.size() - 1, -1, -1):
		var bee := _bees[i]
		if float(bee["leave"]) >= 0.0:
			bee["leave"] = float(bee["leave"]) + delta
			if float(bee["leave"]) >= LEAVE:
				_bees.remove_at(i)
				continue
		_place(bee)
	if not _bees.is_empty() or _drawn:
		if is_instance_valid(_back):
			_back.queue_redraw()
		_front.queue_redraw()
	_drawn = not _bees.is_empty()


## Where a bee is this frame, relative to the angler's feet in whole world px, whether it is
## behind him and which way it faces: on its loop, then pushed clear of his outline.
func _place(bee: Dictionary) -> void:
	var i := int(bee["slot"])
	var loop: Array = ESCORT[i]
	var a := _clock * float(loop[3]) + float(loop[5])
	var at := Vector2(
		cos(a) * float(loop[0]),
		-float(loop[2]) + sin(a) * float(loop[1]) + cos(a) * float(loop[0]) * float(loop[4]) * 0.3
			+ roundf(sin(_clock * BUZZ + float(i) * 1.3))
	)
	bee["behind"] = sin(a) < 0.0
	bee["left"] = -sin(a) * float(loop[3]) < 0.0
	var gone := float(bee["leave"])
	if gone >= 0.0:
		var k := gone / LEAVE
		at += Vector2(signf(cos(a)) * 30.0 * k, -LEAVE_UP * k * k)
	bee["at"] = _clear_of_him(at.round())


## Push a bee at `at` (off his feet) straight out from his chest until none of it is on his
## outline grown by `CLEAR`.
func _clear_of_him(at: Vector2) -> Vector2:
	var angler := get_parent()
	var shown := _shown
	if shown.is_empty():
		return at
	var scale: float = shown["scale"]
	var mask := _mask_of(angler, shown["region"] as Rect2, scale)
	if mask == null:
		return at
	var box: Rect2 = shown["box"]
	# Straight out from his chest.
	var out := at - Vector2(0.0, -CHEST)
	out = out.normalized() if out.length_squared() > 0.01 else Vector2.RIGHT
	for k in CLEAR_MOST:
		var here := (at + out * float(k)).round()
		if not _touches(mask, box, scale, here):
			return here
	return at


## Whether a bee with its body's middle at `here` lands on the grown mask: its body is about
## eight by seven pixels round that middle.
static func _touches(mask: BitMap, box: Rect2, scale: float, here: Vector2) -> bool:
	var size := mask.get_size()
	for dy in [-3, 0, 3]:
		for dx in [-4, 0, 4]:
			var p := ((here + Vector2(dx, dy) - box.position) / scale).floor() + Vector2(MASK_PAD, MASK_PAD)
			if p.x >= 0 and p.y >= 0 and p.x < size.x and p.y < size.y and mask.get_bitv(Vector2i(p)):
				return true
	return false


## His frame `region` as a mask of his own pixels grown by `CLEAR` world px, padded
## `MASK_PAD` source px all round so the growth is not cut off at the frame's edge: read off
## his sheet once, kept per region.
func _mask_of(angler: Node, region: Rect2, scale: float) -> BitMap:
	if _masks.has(region):
		return _masks[region]
	if _sheet_image == null:
		var sheet: Variant = angler.get(&"_sheet")
		if not (sheet is Texture2D):
			return null
		_sheet_image = (sheet as Texture2D).get_image()
		if _sheet_image == null:
			return null
		if _sheet_image.is_compressed():
			_sheet_image.decompress()
		_sheet_image.convert(Image.FORMAT_RGBA8)
	var cut := Rect2i(region)
	var padded := Image.create(cut.size.x + MASK_PAD * 2, cut.size.y + MASK_PAD * 2, false, Image.FORMAT_RGBA8)
	padded.blit_rect(_sheet_image, cut, Vector2i(MASK_PAD, MASK_PAD))
	var mask := BitMap.new()
	mask.create_from_image_alpha(padded, 0.1)
	mask.grow_mask(maxi(ceili(float(CLEAR) / scale), 1), Rect2i(Vector2i.ZERO, mask.get_size()))
	_masks[region] = mask
	return mask


## Draw the bees on one side of the angler, snapped to the world's grid, in the frame of `on`
## (either layer: they hang off different parents).
func draw_half(on: Node2D, behind: bool) -> void:
	var feet := global_position
	var origin := on.global_position
	for bee: Dictionary in _bees:
		if bool(bee["behind"]) != behind:
			continue
		var world := (feet + (bee["at"] as Vector2)).floor()
		var frame := int(_clock * FLAP + float(int(bee["slot"])) * 2.0)
		BeeArt.stamp(on, &"mini_fly", frame, world - origin, bool(bee["left"]), 1.0, 0,
			BEHIND if behind else Color.WHITE)
