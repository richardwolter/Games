## The yard behind the shed: where the catch goes, and the reason the boat exists.
##
## Rubbish pulled out of the lake is not money yet. It sits here until the ferry takes it
## to the shore and sells it.
##
## It does not fill up. It used to: the yard was a hard cap, and when it was full the net
## stopped catching until a boat had run. On paper that made the two halves of the game
## need each other, and in play it made the player stand on the bank watching a boat, which
## is not a game. The ferry earns its place by being the only thing that turns a pile into
## money, and that is enough of a reason for it to exist.
##
## The pile is drawn from what is actually in it rather than from a fill fraction, so a
## yard holding three fridges looks different from one holding three cups, and the player
## can see what is waiting to be sold without opening anything.
class_name Yard
extends Node2D

const Style := preload("res://scripts/style.gd")

## How many pieces the pile is drawn from, at most. Past this the yard is a wall of junk
## either way, and the draw cost of a late-game store is not worth paying.
const MAX_DRAWN := 24

## The recycle box art. An isometric box 32 art pixels wide: its top face is a 32x16 diamond
## centred on row 8, and it stands on a matching diamond centred on row 24, so the walls are
## 16 art pixels tall and the bottom point is the last row.
const ART := "res://assets/Recycle_Box.png"
const ART_SCALE := 2.5
const ART_TOP := 8.0
const ART_GROUND := 24.0

## How wide and deep the crate is on the plane, and how tall its walls stand. Read off the
## art, so the layering in lake.gd and the drop point agree with the picture.
const CRATE := Vector2(32.0, 16.0) * ART_SCALE
const CRATE_TALL := (ART_GROUND - ART_TOP) * ART_SCALE

## Half the crate's side in tiles. Its footprint is a square in tile space, which is exactly
## the diamond it stands on on screen, so walkers are kept off the box and nothing more.
const FOOT_HALF := CRATE.x / Iso.TILE_W * 0.5

## Where the heap sits inside the art box, and how far it climbs, as fractions of the wall
## height above the ground point. Starts sunk behind the near walls and ends a little proud
## of the rim, so a full box reads as full at a glance.
const HEAP_FLOOR := 0.55
const HEAP_CLIMB := 0.7

## The crate's shadow: how much bigger than its footprint it is drawn, and how far down the
## screen it sits. Barely either — it is a box on the ground, and the shadow is the sliver of
## it the sun does not reach rather than a halo.
const SHADOW_SPREAD := 1.0
const SHADOW_DROP := 3.0

## The grass along the box's bottom line and the sand spilling out from it. Small, by
## decision — the box is 32 art pixels tall, and a tuft that would read on the shed is a
## bush on this.
##
## The sand is a *spill*, not a patch: loose grains thinning outwards, as if the crate has
## been dragged about. There is no sand under the box on the map — it stands on the island's
## lawn — so this is the ground the box itself has worn, and nothing in `Ground` knows or
## needs to know about it.
##
## The grass is measured off the crate's own picture rather than laid on a ring round it
## (`Skirt.hem`), so it follows the V the art ends on and fills that line. Only the sand has
## a reach: it is the one of the two that is not tied to the drawing.
const SKIRT_SEED := 9051

## How tall the crate's blades stand, in art pixels — shorter than the hem's own default.
## The crate is drawn at 2.5, so one of its painted pixels is two and a half of the game's,
## and a blade sized for the shed stands a third of the way up this picture. At the default
## the tufts on the lower-left edge reached the recycle mark painted just above it.
const SKIRT_BLADES := Vector2i(1, 2)
const SPILL_REACH := Vector2(1.10, 1.10)
const SPILL_GRAINS := 26
const SPILL_SEED := 9052

## How many pieces fill it to the brim. Past this the heap simply stops rising — the crate is
## a picture of how the run is going, not a second cap on it.
const CRATE_FULL := 40

## The crate's colours: the planks, the shadowed inside, and the lines between boards.
const WOOD := Style.CRATE
const WOOD_LIT := Style.CRATE_LIT
const WOOD_DARK := Style.CRATE_DARK
const INSIDE := Style.CRATE_IN
const CRATE_INK := Style.SEAM


## Def indices waiting to be sold, oldest first. No limit: a lake's worth of rubbish can
## sit here, and the pile stops being drawn long before it stops being counted.
var held := PackedInt32Array()

## Set by lake.gd, for drawing the pieces.
var grid: LakeGrid

var _rng := RandomNumberGenerator.new()

## Set by lake.gd, for the shadow. Null means no shadow, the same as every other caster.
var day: DayCycle

## The grass round the crate and the sand spilled out of it, baked the first time it draws.
## Static, so one bake lasts the run.
var _skirt: Skirt.Patch
var _spill: Skirt.Patch

var _art: Texture2D
## The art's two near walls and front rim alone, drawn again over the heap so the catch is
## inside the box rather than stuck on its face.
var _front: Texture2D
## The sun the shadow was last drawn for.
var _sun := Vector3(INF, INF, INF)


func _ready() -> void:
	# Fixed seed: the pile's scatter should not reshuffle itself every time a piece is
	# added or sold.
	_rng.seed = 90210
	_art = Art.texture(ART)
	_front = _cut_front(Art.image(ART)) if _art != null else null
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(_delta: float) -> void:
	if day == null or _art == null:
		return
	var sun := Vector3(day.lean, day.stretch, day.ink)
	if sun.is_equal_approx(_sun):
		return
	_sun = sun
	queue_redraw()


## How far outside the footprint a walker's feet are kept, in tiles: a pair of boots is not
## a point, and without it they stood on the bottom plank.
const WALK_KEEP := 0.15


## Whether a tile-space point is on the crate standing at `crate_tile`, grown by `grow`.
static func covers(crate_tile: Vector2, at: Vector2, grow: float = 0.0) -> bool:
	var off := at - crate_tile
	return absf(off.x) < FOOT_HALF + grow and absf(off.y) < FOOT_HALF + grow


## Keep only the pixels in front of the mouth: everything below the two lower edges of the
## top diamond, with the rim line along those edges, which is what covers the heap.
static func _cut_front(image: Image) -> Texture2D:
	if image == null:
		return null
	var out := image.duplicate() as Image
	out.convert(Image.FORMAT_RGBA8)
	var mid := float(out.get_width()) * 0.5
	var mouth_low := ART_TOP * 2.0
	for y in out.get_height():
		for x in out.get_width():
			var edge := mouth_low - absf(float(x) + 0.5 - mid) * 0.5
			if float(y) + 0.5 < edge - 1.0:
				out.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
	return ImageTexture.create_from_image(out)


## Take a piece. Never refuses — kept returning a bool so callers that want to know it
## landed still read the same, and so a yard that grows a rule later has somewhere to put
## it.
func put(def_index: int) -> bool:
	held.append(def_index)
	queue_redraw()
	return true


## Load out up to `n` pieces, oldest first. The boat's loading step, and the only way
## anything leaves the yard.
func take_lot(n: int) -> PackedInt32Array:
	var count := mini(n, held.size())
	var lot := held.slice(0, count)
	held = held.slice(count)
	queue_redraw()
	return lot


## Where a piece thrown at the yard should land: inside the crate rather than on the ground
## in front of it, and higher as the crate fills.
func drop_point() -> Vector2:
	return position + Vector2(0.0, _heap_floor() - _heap_rise())


## Where the heap sits before it rises, above the ground point.
func _heap_floor() -> float:
	return -CRATE_TALL * (HEAP_FLOOR if _art != null else 0.25)


## How far the top of the heap has risen off the crate's floor.
func _heap_rise() -> float:
	var climb := HEAP_CLIMB if _art != null else 0.55
	return CRATE_TALL * climb * clampf(float(held.size()) / float(CRATE_FULL), 0.0, 1.0)


## The crate, with the catch in it.
##
## An open box drawn on the plane: the far wall and the floor first, then the heap, then the
## two near walls over the top of it, so what is in the crate is inside it rather than piled
## in front. The heap climbs as the yard fills, which makes the box a readout — a glance says
## whether the ferry is keeping up without reading a number.
func _draw() -> void:
	if _art != null:
		_draw_art()
		return
	var half := CRATE * 0.5
	var lift := Vector2(0.0, -CRATE_TALL)

	# The ground it stands on, and the inside of the box seen over the near wall. The shadow
	# is the crate's own footprint — a square on the plane, which is this diamond on screen —
	# rather than a soft pool bigger than the box: nothing else here casts one of those, and
	# a crate is a box sitting flat on the sand.
	_diamond(Vector2(0.0, SHADOW_DROP), CRATE * SHADOW_SPREAD, Color(0.0, 0.0, 0.0, 0.22))
	_ground().over(self)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0.0, -half.y), Vector2(half.x, 0.0),
			Vector2(0.0, half.y), Vector2(-half.x, 0.0)
		]),
		INSIDE
	)

	# The far two walls, standing up off the back edges.
	_wall(Vector2(-half.x, 0.0), Vector2(0.0, -half.y), lift, WOOD_DARK)
	_wall(Vector2(0.0, -half.y), Vector2(half.x, 0.0), lift, WOOD)

	if grid != null and not held.is_empty():
		_draw_heap()

	# The near two walls, over the heap, which is what puts the heap inside the box.
	_wall(Vector2(half.x, 0.0), Vector2(0.0, half.y), lift, WOOD_LIT)
	_wall(Vector2(0.0, half.y), Vector2(-half.x, 0.0), lift, WOOD)

	# And the rim, so the box has an edge at the top rather than fading into the pile.
	draw_polyline(
		PackedVector2Array([
			Vector2(0.0, -half.y) + lift, Vector2(half.x, 0.0) + lift,
			Vector2(0.0, half.y) + lift, Vector2(-half.x, 0.0) + lift,
			Vector2(0.0, -half.y) + lift
		]),
		CRATE_INK, 1.6
	)


## The recycle box from its art, standing on the node's point with its ground diamond centred
## there. The sun's shadow, then the whole box, then the heap, then the near walls cut from
## the same picture over it, which is what puts the catch inside.
func _draw_art() -> void:
	var size := _art.get_size() * ART_SCALE
	var box := Rect2(Vector2(-size.x * 0.5, -ART_GROUND * ART_SCALE), size)
	# The ground the crate has worn goes under the picture: sand is flat, and the box is
	# standing on it.
	_ground().over(self)
	if day != null:
		# Rooted at the picture's bottom row, the near corner of the diamond the crate stands
		# on, rather than at the node's point in the middle of it. Same reason the hut's is:
		# the shadow is shorter than the half-diamond, so rooted at the middle all of it lay
		# inside the crate's own outline and only a wedge on the left ever showed. See
		# Lake._draw_shed.
		draw_set_transform_matrix(
			Shade.lying(
				Vector2(0.0, box.position.y + size.y), day.lean, day.stretch
			)
		)
		draw_texture_rect(
			_art, Rect2(Vector2(-size.x * 0.5, -size.y), size), false, Shade.tint(day.ink)
		)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_texture_rect(_art, box, false)
	if grid != null and not held.is_empty():
		_draw_heap()
		if _front != null:
			draw_texture_rect(_front, box, false)
	# And the blades along the bottom line, hiding the V the crate's picture ends on.
	_grass(box).over(self)


## The crate's grass, baked once off the crate's own silhouette: one triangle array rather
## than a few hundred rects.
func _grass(box: Rect2) -> Skirt.Patch:
	if _skirt == null:
		_skirt = Skirt.hem(
			Art.image(ART), box, SKIRT_SEED, PackedVector2Array(), SKIRT_BLADES
		)
	return _skirt


## The sand it has spilled, baked the same way. All of it counts as "front" — it is flat on
## the ground and nothing of it goes behind the box.
func _ground() -> Skirt.Patch:
	if _spill == null:
		_spill = Skirt.spill(Vector2.ZERO, SPILL_REACH, SPILL_GRAINS, SPILL_SEED)
	return _spill


## One wall of the crate: the quad between an edge of the floor and the same edge lifted,
## with a couple of board lines across it.
func _wall(from: Vector2, to: Vector2, lift: Vector2, tint: Color) -> void:
	draw_colored_polygon(
		PackedVector2Array([from, to, to + lift, from + lift]), tint
	)
	for i in 2:
		var down := lift * ((float(i) + 1.0) / 3.0)
		draw_line(from + down, to + down, Color(CRATE_INK.r, CRATE_INK.g, CRATE_INK.b, 0.35), 1.0)
	draw_polyline(
		PackedVector2Array([from, to, to + lift, from + lift, from]), CRATE_INK, 1.4
	)


## The catch in the crate. Scattered inside its footprint and stacked upward as it fills,
## drawn back to front so the near pieces overlap the far ones.
func _draw_heap() -> void:
	_rng.seed = 90210
	var count := mini(held.size(), MAX_DRAWN)
	var floor_at := _heap_floor()
	var spots: Array[Vector2] = []
	for i in count:
		var angle := _rng.randf_range(0.0, TAU)
		var reach := sqrt(_rng.randf()) * 0.6
		spots.append(
			Vector2(cos(angle) * CRATE.x * 0.5, sin(angle) * CRATE.y * 0.5) * reach
			+ Vector2(0.0, floor_at - float(i / 6) * 7.0)
		)
	spots.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)
	for i in count:
		draw_set_transform(spots[i], _rng.randf_range(-0.2, 0.2), Vector2(0.62, 0.62))
		grid.defs[held[i]].stamp_iso(self)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _diamond(at: Vector2, extent: Vector2, colour: Color) -> void:
	draw_colored_polygon(
		PackedVector2Array([
			at + Vector2(0.0, -extent.y * 0.5), at + Vector2(extent.x * 0.5, 0.0),
			at + Vector2(0.0, extent.y * 0.5), at + Vector2(-extent.x * 0.5, 0.0)
		]),
		colour
	)
