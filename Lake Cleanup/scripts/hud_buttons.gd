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

## The fallback oak round a button and how many bites it takes per side, for when the
## meter's painted border is missing. The border itself is `Style.meter_frame`, by decision
## (2026-09-11): these three sit in the same corners of the screen as the pollution meter and
## wearing its wood is what makes them read as the same object as it.
const FRAME := 7.0
const CHIPS := 1

## The upgrades button. The net fills the face behind everything, dimmed so it reads as a
## backdrop; the ferry stands in the left half of the face and the dog in the right half,
## both at a size that can be made out; the arrow is drawn last, over the middle of them.
## The dog is drawn by `DogArt` (`Dogs` here).
##
## They are not held clear of the arrow, by decision (2026-09-11): the lane between the
## arrow's edge and the face's was a couple of dozen pixels, and a ferry shrunk into it was
## a smudge. Overlapping is what "behind" looks like.
const NET_FILL := 1.05
const SIDE_TALL := 0.52
const SIDE_HALF := 0.46
const BOAT_TALL := 0.64
const BOAT_LIFT := 0.12
const SIDE_IN := 0.04
## How much of the ferry and the dog the arrow covers, as a fraction of their own width.
## Placed by their **drawn** edges rather than by a slot, because a slot centres whatever it
## is given and the ferry came out almost entirely behind the arrow.
##
## Raised from 0.13 when the button came down to the decorate one's width (2026-09-12): on a
## narrow face the lane beside the arrow is a couple of dozen pixels, and sizing them to it
## shrank both to smudges again. They keep their share of the face and lie further under the
## arrow instead — which is what standing behind something looks like.
const SIDE_UNDER := 0.3
const ARROW_TALL := 0.78
const ARROW_WIDE := 0.40
const ARROW_HEAD := 0.5
const ARROW_SHAFT := 0.42

## The shed button: the finds are scattered over the face and the hut stands in the middle
## of them, so they stick out from behind it on every side rather than standing in a band
## along the back. Fixed, by decision (2026-09-11): a button that showed the player's own
## finds would be bare for the first hour, and it is the way in, not a shelf.
##
## Each find's place is jittered off its own index — across the width, up and down within
## `DECOR_BAND`, and in size between `DECOR_LEAST` and `DECOR_MOST` — so the heap is uneven
## the way a heap is, and is the same heap every time the button is drawn.
## The fan the finds stand in round the hut (2026-09-17). `FAN_FROM`/`FAN_TO` are the ends
## of the sweep in radians, measured anticlockwise from due right with the screen's y flipped
## — so a little under the horizon on the right, up over the roof, and a little under it on
## the left. `FAN_MIDDLE` is how far down the room the fan turns about; `FAN_RADIUS` how much
## of the room's half-size it reaches at rank 0; `FAN_NEAR`/`FAN_FAR` the innermost and
## outermost rings; `FAN_WOBBLE` how far off its ring a find may sit; `FAN_STAGGER` how far
## along the sweep it may slide; `FAN_HIGH` how much of the size falloff height alone buys.
##
## First guesses, all of them: judge on `tools/shot_buttons.tscn` and retune there.
const FAN_FROM := -0.42
const FAN_TO := PI + 0.42
const FAN_MIDDLE := 0.74
const FAN_RADIUS := 1.02
const FAN_RANKS := 3
const FAN_NEAR := 0.70
const FAN_FAR := 1.0
const FAN_WOBBLE := 0.12
const FAN_STAGGER := 0.7
const FAN_HIGH := 0.8
## How wide a find's box is against its height. `fit` keeps the art's own proportions inside
## it, so this only decides how much sideways room a wide find (a sofa) gets before its width
## is what limits it.
const FAN_ASPECT := 1.4
## How much further back the far ranks are washed out than the near ones, on top of
## `DECOR_DIM`. Depth the eye reads without having to measure sizes.
const FAN_FADE := 0.4

## Retired with the band (2026-09-17): every find sat between these two fractions down the
## face, which put the whole heap in the lower 58% of it.
const DECOR_BAND := Vector2(0.42, 0.98)
const DECOR_LEAST := 0.18
const DECOR_MOST := 0.42
const DECOR_SPREAD := 0.55
const DECOR_DIM := Color(0.82, 0.86, 0.88)
const SHED_TALL := 0.78
const SHED_LABEL := "Decorate"

## The coin: a disc in the money's gold with a deeper rim, a paler crescent where the light
## catches it, and a ring struck into it a little in from the edge.
## How far the sunken reading panel is set in from the face the wood leaves, on the money
## plate and on the stock plate that copies it. Two pixels, not five (2026-09-16): the
## border's own planks take thirty of a plate's height whatever the plate's size, so on the
## shorter plates a generous inset is what drops the figure a rung.
const PANEL_INSET := 2.0

const COIN_RIM := 2.0
const COIN_RING := 0.72
const COIN_GLINT := Color(1.0, 0.94, 0.72)


# ---------------------------------------------------------------------------------------
# Where things stand
# ---------------------------------------------------------------------------------------

## Every picture on a button asks `_at` where its middle goes and `_scale` how big it is, and
## gets **the rule's own answer** unless a number has been laid over it. Three layers, first
## one wins: `tune`, which the tuner writes while it is open; `BAKED`, which is what was
## picked and kept; and the rule the constants above describe.
##
## A position is the drawn picture's **middle**, as a fraction of the face (or of the room,
## for the shed's); a scale is a fraction of the face's height, except the arrow's width and
## the net's fill, which are of the width and of the fit. Fractions, so a button drawn at
## another size puts everything in the same place.
##
## Bake by pasting what `ButtonTuner` writes to `user://button_tune.log` into `BAKED`.
##
## Laid out by hand on the canvas, 2026-09-12, and re-tuned over the new fan on 2026-09-17.
## The net rides high and a little left of the middle and is drawn a fifth over its fit; the
## ferry is bigger and well out to the left, the dog lower and out to the right; the arrow is
## a touch below centre; the tail of finds is shifted down and a little left and three
## quarters again as big, with the hut over it a shade past the room's whole height. Anything
## not named here is still the rule's.
const BAKED := {
	&"net": Vector2(0.4777, 0.2452),
	&"net_fill": 1.2000,
	&"boat": Vector2(0.1503, 0.4133),
	&"boat_tall": 0.7200,
	&"dog": Vector2(0.8106, 0.5265),
	&"arrow": Vector2(0.5019, 0.5286),
	&"decor": Vector2(0.0148, 0.1099),
	&"decor_scale": 1.7400,
	&"hut": Vector2(0.4666, 0.5029),
	&"hut_tall": 1.0200,
}

## The tuner's live overrides. Empty in a real run, so the game draws what `BAKED` and the
## rules say and pays nothing for this.
static var tune := {}

## Where each picture landed, in the drawing item's own pixels, for the tuner to hit-test
## against. Filled only while `tracing`.
static var tracing := false
static var traced := {}


static func _at(key: StringName, rule: Vector2) -> Vector2:
	if tune.has(key):
		return tune[key]
	return BAKED.get(key, rule)


static func _scale(key: StringName, rule: float) -> float:
	if tune.has(key):
		return float(tune[key])
	return float(BAKED.get(key, rule))


static func _trace(key: StringName, box: Rect2) -> void:
	if tracing:
		traced[key] = box


## The face inside a button of this size: what `board` fills and hands back, for a caller
## that needs it without drawing the button again.
static func face_of(box: Rect2) -> Rect2:
	return Style.border_inset(box) if Style.border_fits(box) else box.grow(-FRAME)


## The wood and the face. Returns the face, which is where the contents go.
##
## The face is filled before the border goes on, so the border's own nicked outer edge is
## the button's silhouette and nothing shows through behind it.
static func board(on: CanvasItem, box: Rect2, hovered: bool, fill := Style.BOARD) -> Rect2:
	if hovered:
		fill = Color(fill.r * Style.HOVER_WASH.r, fill.g * Style.HOVER_WASH.g, fill.b * Style.HOVER_WASH.b)
	var tint := Style.HOVER_WASH if hovered else Color.WHITE
	if Style.border_fits(box):
		var face := Style.border_inset(box)
		on.draw_rect(face.grow(2.0), fill, true)
		Style.meter_frame(on, box, tint)
		return face
	on.draw_rect(box.grow(-FRAME), fill, true)
	Style.board_frame(on, box, FRAME, CHIPS)
	return box.grow(-FRAME)


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
	if not flip:
		on.draw_texture_rect_region(sheet, rect, region, tint)
		return rect
	# Mirrored about the rect's own middle. A Rect2 of negative width does **not** flip a
	# `draw_texture_rect_region` — it degenerates, and the ferry drew as scraps for a day
	# before that was spotted (2026-09-12). Turn the canvas over instead.
	var middle := rect.position.x + drawn.x * 0.5
	on.draw_set_transform(Vector2(middle, 0.0), 0.0, Vector2(-1.0, 1.0))
	on.draw_texture_rect_region(
		sheet, Rect2(Vector2(-drawn.x * 0.5, rect.position.y), drawn), region, tint
	)
	on.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return rect


## How big a sprite comes out when it is fitted into a box of this size — the same sums
## `fit` does, without drawing, for a caller that has to place a sprite by its own edges.
static func span_of(art: Dictionary, room: Vector2, fill: float) -> Vector2:
	var region: Rect2 = art.get("region", Rect2())
	if region.size.x <= 0.0 or region.size.y <= 0.0:
		return Vector2.ZERO
	return region.size * (minf(room.x / region.size.x, room.y / region.size.y) * fill)


## The upgrades button. `hovered` lifts and lights it; `wash` is the caller's own tint on
## top of that, white for none.
static func draw_upgrades(on: CanvasItem, box: Rect2, hovered: bool, sprites: Dictionary) -> void:
	var face := board(on, box, hovered, Style.BUTTON_FACE)
	var tint := Style.HOVER_WASH if hovered else Color.WHITE
	# The net, behind, filling the face and dimmed into it. Clipped to the face by drawing
	# it centred rather than stood, so an over-fill spills evenly rather than out of the top.
	_trace(&"face_upgrades", face)
	if sprites.has("net"):
		# `Style.NET_INK`, the shop board's own black, so the net is one net wherever it is
		# drawn as a picture of itself. It was a pale grey dim until 2026-09-12.
		var ink := Style.NET_INK
		var net_span := span_of(sprites["net"], face.size, _scale(&"net_fill", NET_FILL))
		var net_at := _at(&"net", Vector2(0.5, 0.5))
		var net_box := Rect2(face.position + net_at * face.size - net_span * 0.5, net_span)
		fit(on, sprites["net"], net_box, 1.0, Color(ink.r * tint.r, ink.g * tint.g, ink.b * tint.b, ink.a), false)
		_trace(&"net", net_box)
	# The ferry in the left half, a little up off the foot; the dog in the right half. Both
	# mirrored from how their sheets face, so they look outwards, and both drawn before the
	# arrow, which stands over the middle of them.
	var foot := face.end.y - face.size.y * 0.08
	var half := face.size.x * SIDE_HALF
	var mid := face.position.x + face.size.x * 0.5
	var arrow_half := face.size.x * _scale(&"arrow_wide", ARROW_WIDE) * 0.5
	var arrow_mid := face.position.x + face.size.x * _at(&"arrow", Vector2(0.5, 0.5)).x
	# Sized to their share of the face, not to the lane beside the arrow: the lane decides
	# where they stand, `SIDE_UNDER` decides how much of them the arrow takes, and neither
	# decides how big they are. Each rule works out a middle, which is then what a tuned
	# position replaces — see `_at`.
	if sprites.has("boat"):
		var span := span_of(sprites["boat"], Vector2(half, face.size.y * _scale(&"boat_tall", BOAT_TALL)), 1.0)
		var rule := (Vector2(
			arrow_mid - arrow_half + span.x * SIDE_UNDER - span.x * 0.5,
			foot - face.size.y * BOAT_LIFT - span.y * 0.5
		) - face.position) / face.size
		var slot := Rect2(face.position + _at(&"boat", rule) * face.size - span * 0.5, span)
		fit(on, sprites["boat"], slot, 1.0, tint, true, true)
		_trace(&"boat", slot)
	if Dogs.has(&"idle"):
		var dog_tall := face.size.y * _scale(&"dog_tall", SIDE_TALL * 0.9)
		var dog_span := Dogs.span(&"idle", dog_tall)
		# The same rule mirrored: its left edge that far inside the arrow's right.
		var rule := (Vector2(
			arrow_mid + arrow_half - dog_span.x * SIDE_UNDER + dog_span.x * 0.5,
			foot - dog_span.y * 0.5
		) - face.position) / face.size
		var middle := face.position + _at(&"dog", rule) * face.size
		Dogs.stamp(on, &"idle", 0, Vector2(middle.x, middle.y + dog_span.y * 0.5), dog_tall, false, 0.0, tint)
		_trace(&"dog", Rect2(middle - dog_span * 0.5, dog_span))
	arrow(on, face, tint)


## The green arrow: a black-ringed block arrow pointing up, in the game's own `SAFE`
## green, a lit edge along its left and a shaded one down its right so it stands off the
## face rather than lying flat on it.
static func arrow(on: CanvasItem, face: Rect2, tint: Color) -> void:
	var tall := floorf(face.size.y * _scale(&"arrow_tall", ARROW_TALL))
	var wide := floorf(face.size.x * _scale(&"arrow_wide", ARROW_WIDE))
	var head := floorf(tall * ARROW_HEAD)
	var shaft := floorf(wide * ARROW_SHAFT)
	var where := _at(&"arrow", Vector2(0.5, 0.5))
	var mid := floorf(face.position.x + face.size.x * where.x)
	var top := floorf(face.position.y + face.size.y * where.y - tall * 0.5)
	_trace(&"arrow", Rect2(mid - wide * 0.5, top, wide, tall))
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


## The shed button: the finds scattered over the face, the hut in the middle of them, the
## word across the foot.
static func draw_shed(on: CanvasItem, box: Rect2, hovered: bool, sprites: Dictionary) -> void:
	var face := board(on, box, hovered, Style.BUTTON_FACE)
	var tint := Style.HOVER_WASH if hovered else Color.WHITE
	var room := room_of(face)
	_trace(&"face_shed", face)
	var decor: Array = sprites.get("decor", [])
	if not decor.is_empty():
		var dim := Color(DECOR_DIM.r * tint.r, DECOR_DIM.g * tint.g, DECOR_DIM.b * tint.b)
		# Back to front, so a find lower down the face laps the one behind it — and so the
		# hut, drawn after the lot, stands in front of all of them.
		var placed := _scatter(decor.size(), room)
		placed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["box"].end.y < b["box"].end.y)
		# The heap moves and grows as one. Sixteen handles would be sixteen ways to make it
		# look sown rather than heaped; what is worth moving is where the heap sits.
		var shift := _at(&"decor", Vector2.ZERO) * room.size
		var grow := _scale(&"decor_scale", 1.0)
		var whole := Rect2()
		for spot: Dictionary in placed:
			var stood: Rect2 = spot["box"]
			# Grown about its own foot, so a bigger find still stands on the ground it did.
			stood = Rect2(
				Vector2(stood.position.x + stood.size.x * (1.0 - grow) * 0.5, stood.end.y - stood.size.y * grow),
				stood.size * grow
			)
			stood.position += shift
			# Further back, further washed out: the tail's depth is read off tone as much as
			# off size, and sixteen finds at one tone is the wall this replaced.
			var back := float(spot.get("back", 0.0))
			fit(on, decor[spot["at"]], stood, 1.0, dim.lerp(Style.BUTTON_FACE, back * FAN_FADE))
			whole = stood if whole.size == Vector2.ZERO else whole.merge(stood)
		_trace(&"decor", whole)
	var hut: Texture2D = sprites.get("shed")
	if hut != null:
		var art := {"sheet": hut, "region": Rect2(Vector2.ZERO, hut.get_size())}
		var tall := room.size.y * _scale(&"hut_tall", SHED_TALL)
		var span := span_of(art, Vector2(room.size.x, tall), 1.0)
		# The rule stands it `0.62` of the spare height down the room; what that comes to is
		# the middle a tuned position replaces.
		var rule := (Vector2(
			room.position.x + room.size.x * 0.5,
			room.position.y + (room.size.y - tall) * 0.62 + tall - span.y * 0.5
		) - room.position) / room.size
		var slot := Rect2(room.position + _at(&"hut", rule) * room.size - span * 0.5, span)
		fit(on, art, slot, 1.0, tint)
		_trace(&"hut", slot)
	label(on, face, SHED_LABEL)


## Where each find stands: a fan around the hut, not a row beside it.
##
## Each find takes its place along a sweep from low on one side, up over the roof, and down
## to low on the other — a peacock's tail behind the shed (Richard, 2026-09-17). Its radius
## comes off one of `FAN_RANKS` rings so the tail has depth rather than reading as a hoop,
## its own hash shoves it off that place along the arc and across the rings, and it is drawn
## smaller the further up the sweep it sits, so the ones over the roof read as standing
## behind it. `draw_shed` sorts them by baseline, which then puts those behind the hut for
## free.
##
## **It used to be a band**: every find placed between `DECOR_BAND` 0.42 and 0.98 down the
## face, which is the lower 58% by construction — so the top of the button was bare by rule,
## the hut covered the middle, and what showed was two clumps on one baseline that read as a
## row of furniture standing in a line.
##
## Deterministic: the same tail every frame. Fitted inside the room less each find's own
## half-size, so nothing is clipped by the frame — several were.
static func _scatter(count: int, room: Rect2) -> Array:
	var out: Array = []
	var middle := room.position + room.size * Vector2(0.5, FAN_MIDDLE)
	for i in count:
		var h := hash(i * 7919 + 13)
		var t := (float(i) + 0.5) / float(count)
		# Along the sweep, shoved off its place by up to half a step so the ranks do not comb.
		var step := 1.0 / float(count)
		var along := t + (float(h % 200) / 100.0 - 1.0) * step * FAN_STAGGER
		var angle := lerpf(FAN_FROM, FAN_TO, clampf(along, 0.0, 1.0))
		# Which ring, and how far off it. Rank 0 is the near one, the last is the far one.
		var rank := float((h / 200) % FAN_RANKS) / maxf(float(FAN_RANKS - 1), 1.0)
		var reach := lerpf(FAN_NEAR, FAN_FAR, rank) + (float((h / 20000) % 100) / 100.0 - 0.5) * FAN_WOBBLE
		var spread := room.size * 0.5 * FAN_RADIUS * reach
		var at := middle + Vector2(cos(angle) * spread.x, -sin(angle) * spread.y)
		# The far ranks draw smaller, and so does anything high up the sweep: both are depth.
		var up := clampf((middle.y - at.y) / maxf(room.size.y * 0.5, 1.0), 0.0, 1.0)
		var back := maxf(rank, up * FAN_HIGH)
		var tall := room.size.y * lerpf(DECOR_MOST, DECOR_LEAST, back)
		var wide := tall * FAN_ASPECT
		# `fit` stands a find on the bottom of the box it is given, so the point on the sweep
		# is its **foot**, not its middle. Centred, every find sat half its own height low.
		var box := Rect2(Vector2(at.x - wide * 0.5, at.y - tall), Vector2(wide, tall))
		# Held inside the room by its own half-size, so a wide find at the end of the sweep
		# is moved rather than cut.
		box.position.x = clampf(box.position.x, room.position.x, room.end.x - box.size.x)
		box.position.y = clampf(box.position.y, room.position.y, room.end.y - box.size.y)
		out.append({"at": i, "box": box, "back": back})
	return out


## The word across the foot of a button, on a sunken panel — the decorate button's name, the
## upgrades button's count, and the same again on the shed's copy of that button.
##
## **One panel, drawn once** (2026-09-12). It was written out three times, and the three
## drifted: the decorate button's plate was measured off the band rather than the face and its
## lettering went through `Style.step` onto the size ladder, so "Decorate" stood taller on a
## deeper plate than "n available" did beside it. Given the **face**, not a band, because that
## is what all three callers have.
const LABEL_TALL := 14.0
const LABEL_TEXT := 0.8
const LABEL_LEAST := 8


## A count on a small plate in a button's top-right corner: how many upgrades are affordable.
##
## Its own plate rather than a word across the foot, so the caption underneath can say what
## the button *is* and stop moving. Sized to the widest count the game can ever show
## (`BADGE_SAMPLE`) rather than to the count in hand — a badge that breathes as the purse
## fills is the thing this replaced.
##
## `lit` false draws it back rather than hiding it: a badge that comes and goes is a thing
## the player has to notice the absence of, which was the old panel's rule and a good one.
const BADGE_TALL := 15.0
const BADGE_PAD := 5.0
const BADGE_INSET := 3.0
const BADGE_TEXT := 0.82
const BADGE_SAMPLE := "99"
## The pulse: how many whole pixels the badge grows at full, how many the button itself
## swells, the glow's tone and how far it reaches. **Gold, and not subtle** (Richard,
## 2026-09-22, after a pale blue rim at 0.75 read as nothing): gold on this HUD is a price,
## and this is a thing that can be bought. **No seams** (Richard, same day: three stacked
## rects of different shades were "blocky and ugly"): the glow is one halo drawn as quads
## with per-vertex colour, gold at the wood going to nothing at `GLOW_REACH`, so the falloff
## is a gradient rather than steps; and `RAYS` soft rays stand off the wood like light thrown
## from behind it, each a tapering triangle fading to nothing at its tip, its length rolled
## off its own index and breathing with the pulse.
const BADGE_SWELL := 2.0
## Two pixels, down from three (Richard, 2026-09-22: "less aggressive").
const BUTTON_SWELL := 2.0
const PULSE_TONE := Color(1.0, 0.84, 0.36)
const PULSE_RIM := 1.0
const GLOW_REACH := 10.0
const RAYS := 14
const RAY_REACH := 22.0
const RAY_WIDE := 7.0


## How many whole pixels a button grows on each side at this pulse. The callers grow the box
## they draw the whole button in, so wood, face and pictures swell together.
static func swell_by(amount: float) -> float:
	return float(roundi(amount * BUTTON_SWELL))


## The glow round a button, `amount` 0 to 1. Drawn before the button, so the wood covers the
## inside of it and nothing on the face is re-tinted.
static func pulse(on: CanvasItem, box: Rect2, amount: float) -> void:
	if amount <= 0.01:
		return
	var tone := PULSE_TONE
	var glow := amount * PULSE_RIM
	var near := Color(tone.r, tone.g, tone.b, glow * 0.7)
	var gone := Color(tone.r, tone.g, tone.b, 0.0)
	var mid := Color(tone.r, tone.g, tone.b, glow * 0.22)
	# The rays first, under the halo, out to `RAY_REACH` plus what the pulse adds.
	var centre := box.get_center()
	for i in RAYS:
		var angle := TAU * (float(i) + 0.5) / float(RAYS)
		var dir := Vector2(cos(angle), sin(angle))
		var foot := _edge_point(box.grow(2.0), dir)
		var roll := 0.7 + 0.6 * absf(sin(float(i) * 2.399 + 1.0))
		var length := (GLOW_REACH + RAY_REACH * roll) * (0.75 + 0.25 * amount)
		var half := dir.orthogonal() * RAY_WIDE * 0.5
		on.draw_polygon(
			PackedVector2Array([foot - half, foot + half, foot + dir * length]),
			PackedColorArray([mid, mid, gone])
		)
	# The halo: eight quads between the wood's edge and `GLOW_REACH` out, gold going to nothing.
	var inner := box.grow(1.0)
	var outer := box.grow(1.0 + GLOW_REACH)
	var ic := [inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]
	var oc := [outer.position, Vector2(outer.end.x, outer.position.y), outer.end, Vector2(outer.position.x, outer.end.y)]
	for k in 4:
		var n := (k + 1) % 4
		on.draw_polygon(
			PackedVector2Array([ic[k], ic[n], oc[n], oc[k]]),
			PackedColorArray([near, near, gone, gone])
		)


## Where a ray from a box's middle in `dir` leaves the box.
static func _edge_point(box: Rect2, dir: Vector2) -> Vector2:
	var half := box.size * 0.5
	var tx := half.x / maxf(absf(dir.x), 0.0001)
	var ty := half.y / maxf(absf(dir.y), 0.0001)
	return box.get_center() + dir * minf(tx, ty)


## `swell` is the pulse (0 to 1): the plate grows `BADGE_SWELL` whole pixels at full and
## its ink lifts towards the pulse's tone, about its own middle so the corner stays put.
static func badge(on: CanvasItem, face: Rect2, text: String, lit: bool, swell: float = 0.0) -> void:
	var height := maxi(LABEL_LEAST, int(BADGE_TALL * BADGE_TEXT))
	var wide := maxf(
		Style.measure(BADGE_SAMPLE, height).x, Style.measure(text, height).x
	) + BADGE_PAD * 2.0
	var plate := Rect2(
		Vector2(face.end.x - BADGE_INSET - wide, face.position.y + BADGE_INSET),
		Vector2(wide, BADGE_TALL)
	)
	var grown := float(roundi(swell * BADGE_SWELL))
	if grown > 0.0:
		plate = plate.grow(grown)
		Style.plate(on, plate.grow(1.0), PULSE_TONE.lerp(Style.BUTTON_SUNK, 1.0 - swell * PULSE_RIM), 2.0)
	Style.plate(on, plate, Style.BUTTON_SUNK if lit else Style.BUTTON_SUNK.darkened(0.25), 2.0)
	Style.write(
		on, text, height,
		Vector2(0.0, plate.position.y + (plate.size.y + float(height) * 0.62) * 0.5),
		Style.BOARD_INK if lit else Style.BOARD_INK_DIM,
		HORIZONTAL_ALIGNMENT_CENTER, plate
	)


static func label(on: CanvasItem, face: Rect2, text: String) -> void:
	var plate := Rect2(
		Vector2(face.position.x + 4.0, face.end.y - LABEL_TALL - 3.0),
		Vector2(face.size.x - 8.0, LABEL_TALL)
	)
	Style.plate(on, plate, Style.BUTTON_SUNK, 2.0)
	# Set to the plate's height and then shrunk to its width if the word is too long for it.
	# Not stepped onto the game's ladder of text sizes: every rung of that ladder is taller
	# than this plate.
	var height := maxi(LABEL_LEAST, int(plate.size.y * LABEL_TEXT))
	var wide := Style.measure(text, height).x
	if wide > plate.size.x:
		height = maxi(LABEL_LEAST, int(float(height) * plate.size.x / wide))
	Style.write(
		on, text, height,
		Vector2(0.0, plate.position.y + plate.size.y * 0.5 + float(height) * 0.35),
		Style.INK, HORIZONTAL_ALIGNMENT_CENTER, plate
	)


## What a button leaves for its pictures: the face less the band its word sits on. The one
## place that sum is done — the shed's heap, its hut and the tuner all ask.
static func room_of(face: Rect2) -> Rect2:
	return Rect2(face.position, Vector2(face.size.x, face.size.y - LABEL_TALL - 4.0))


## A panel pressed **into** the wood: a seam all round, the dark face, and a second seam
## along the top where the light cannot reach. The same panel the stock readout's count sits
## on, by decision (2026-09-12) — a figure on a raised plate read as a tile stuck on the
## button while the one beside it was cut into its board.
static func sunk(on: CanvasItem, box: Rect2, face: Color) -> void:
	on.draw_rect(box.grow(1.0), Style.SEAM, true)
	on.draw_rect(box, face, true)
	on.draw_rect(Rect2(box.position, Vector2(box.size.x, 1.0)), Style.SEAM, true)


## The money plate: the coin on the left, and the sunken panel the figure is written on
## filling the rest. Returns the panel. `wash` is the payment's shine on the coin, and
## `swell` how much bigger it is drawn for the moment a payment lands.
##
## The swell is the **coin's**, not the plate's, by decision (2026-09-12): growing the whole
## button moved its border, and a frame that breathes reads as the HUD coming loose rather
## than as money arriving. The wood stands still and the coin in it jumps.
static func draw_money(on: CanvasItem, box: Rect2, wash: Color, swell: float = 1.0) -> Rect2:
	var face := board(on, box, false)
	var side := face.size.y
	var coin_box := Rect2(face.position, Vector2(side, side)).grow(-3.0)
	# About its own middle, and never past the face the wood leaves.
	coin_box = Rect2(
		coin_box.position - coin_box.size * (swell - 1.0) * 0.5, coin_box.size * swell
	).intersection(face)
	coin(on, coin_box, wash)
	var panel := Rect2(
		Vector2(coin_box.end.x + 2.0, face.position.y + PANEL_INSET),
		Vector2(face.end.x - coin_box.end.x - 2.0 - PANEL_INSET, face.size.y - PANEL_INSET * 2.0)
	)
	sunk(on, panel, Style.BOARD.darkened(0.35))
	return panel


## The coin part-way through a flip: `turn` is the cosine of how far round it is, 1 face on,
## 0 edge on, under 0 its back. Squashed across through the canvas transform, to a **whole
## number of pixels** wide so the rim does not shimmer, with the coin's own thickness showing
## as a second disc behind the face on the side turning away. The back carries the struck
## ring and no glint: the light is on the side that faces it.
static func coin_turned(on: CanvasItem, box: Rect2, wash: Color, turn: float, edge := 2.0) -> void:
	if turn >= 0.999:
		coin(on, box, wash)
		return
	var centre := (box.position + box.size * 0.5).floor()
	var r := minf(box.size.x, box.size.y) * 0.5
	var across := maxf(roundf(r * absf(turn)), 1.0) / r
	var gold := Color(Style.GOLD.r * wash.r, Style.GOLD.g * wash.g, Style.GOLD.b * wash.b)
	var deep := Color(Style.GOLD_DEEP.r * wash.r, Style.GOLD_DEEP.g * wash.g, Style.GOLD_DEEP.b * wash.b)
	var thick := edge * (1.0 - absf(turn))
	var lean := -thick if turn >= 0.0 else thick
	on.draw_set_transform(centre + Vector2(lean, 0.0), 0.0, Vector2(across, 1.0))
	on.draw_circle(Vector2.ZERO, r + 1.0, Style.HOLE_RIM)
	on.draw_circle(Vector2.ZERO, r, deep)
	on.draw_set_transform(centre, 0.0, Vector2(across, 1.0))
	on.draw_circle(Vector2.ZERO, r + 1.0, Style.HOLE_RIM)
	on.draw_circle(Vector2.ZERO, r, deep)
	on.draw_circle(Vector2.ZERO, r - COIN_RIM, gold if turn >= 0.0 else gold.darkened(0.12))
	on.draw_arc(Vector2.ZERO, r * COIN_RING, 0.0, TAU, 24, deep, 1.0)
	if turn >= 0.0:
		on.draw_arc(Vector2.ZERO, r - COIN_RIM - 1.0, PI * 1.05, PI * 1.55, 12, COIN_GLINT, 2.0)
	on.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
