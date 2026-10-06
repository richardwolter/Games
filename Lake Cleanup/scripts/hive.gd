## The old beehive on the island's lawn, left of the hut: its state, its save and its picture.
##
## The beehive sidequest (`/grill-me` with Richard, 2026-09-29; the build contract is
## `docs/hive/contract.md`, sections 3.1 and 5). A front-on painting on the lawn like the
## pump, and dressed the way the pump is — blades along its bottom line (`Skirt.hem`) and a
## shadow swept off its silhouette (`Shade.Cast`) — but **not a copy of the pump**, because
## four of the pump's assumptions do not hold here:
## - **It is two parts, a hive and a jar shelf behind it**, dealt out of one inked sprite by
##   `tools/build_hive.py`. The shelf is drawn first and the hive over it, into the same box,
##   and the pair is exactly the approved picture. Each part keeps its own `ground`, its own
##   shadow and its own grass: the shelf's feet stand several rows higher than the stand's,
##   so one `ground` for the whole picture left the shelf with no shadow and no blades.
## - **It changes picture.** Weathered, colony and full for the hive; weathered and five jar
##   counts for the shelf. `Shade.Cast.lay` caches on the box and the ground alone, so a new
##   frame in the same box would keep the old silhouette's shadow for ever. A frame change
##   therefore throws the Cast away and makes a new one.
## - **It is not centred on its foot.** The stand is near the right of the picture and the
##   shelf runs off up-left, so the box is `Rect2(-foot * ART_SCALE, size * ART_SCALE)` off
##   the json's own `foot` pixel, and everything that asks "is this inside the picture" asks
##   that real rectangle, never a half-width either side of the node.
## - **Its footprint is a rectangle offset from the tile it stands on** (`centre`, `half`,
##   measured by the builder off the stand's legs and the shelf's posts), not the pump's
##   square round its tile.
##
## And one of the pump's habits is not copied: `Pump.roof()` hands out a fresh `Image` every
## call, which misses `Weather`'s cache on every landing. Every picture here is cut once and
## kept.
##
## **Where it stands is a static** (`tile`), for the pump's reason: the walkers, the flora,
## the puddles and the wildlife ask it, and it is a fact about the lake rather than about any
## one of them. It must be set before the flora sows, which the lake does.
##
## What moves is drawn on a clock of the node's own, advanced in `_process`, so the settings
## pause (which switches the node's processing off) stops the bees where they are, and a
## probe stepping `_process` by hand gets the same picture every time.
class_name Hive
extends Node2D

const Style := preload("res://scripts/style.gd")

signal changed

## SETTLE (2026-09-30, the second pass) is a colony caught and not yet smoked and crowned:
## appended, not inserted, so the numbers a save holds keep their meaning.
enum Stage { EMPTY, SWARM, READY, BUSY, DONE, SETTLE }

const ART := "res://assets/hive.png"
const CONTRACT := "res://assets/hive.json"

## World pixels to a painted one: 1.0 since the island hive was redrawn at the hut's grain
## (2026-10-01, `build_hive.py`'s `_island_raw_hd`); 2.0 before. The json's coordinates are in
## these pixels, so they doubled with it. The shrub is the flora's sheet, at `Flora.SCALE`.
const ART_SCALE := 1.0
const SKIRT_SEED := 6203
## The pump's blade heights: a tuft the size of the hut's would stand half up the stand.
const SKIRT_BLADES := Vector2i(1, 2)
const JARS_PER := 3
const HARVESTS_MOST := 4
## How much wider a pair of boots keeps off the footprint, in tiles. The pump's number.
const WALK_KEEP := 0.12

## The steps each kind of visit plays, in order (the second pass, 2026-09-30, Richard). A
## new colony is caught, smoked and crowned, and that is the whole visit: the colony then
## makes its first honey on the refill clock. A colony caught but left before its queen was
## found (`SETTLE`) is smoked and crowned. **Every harvest, the first included**, is the
## uncapping and the pour. The crank is gone.
const PLAN_SWARM := [&"catch", &"smoke", &"queen"]
const PLAN_SETTLE := [&"smoke", &"queen"]
const PLAN_LATER := [&"uncap", &"pour"]

## How long the flowering shrub takes to come up when the swarm arrives, in seconds. It rises
## the way a Flora plant does (`Flora._lay`): the sprout first, then the full picture growing
## up out of it.
const SHRUB_GROW := 1.2
## The window's share of honey once the fourth harvest is taken: a colony that is still
## living there, making a little for itself.
const DONE_SHARE := 0.35

## The ready mark bobs this many world pixels over its spot, at this many radians a second.
const READY_BOB := 2.0
const READY_RATE := 2.4
## The key chip the mark turns into with the angler in reach: the shed room's E prompt, a
## square of wood `CHIP` world px with the bound key written on it.
const CHIP := 18.0

## Bees: the flying ones at the island's own bee (`Flora.BEE_COLOR`), one art pixel each, so
## the island has one bee and not two.
const COMMUTERS := 8
const CROWD := 6
const SWARM_SPECKS := 22
## The swarm's bees fly loose (2026-10-04, Richard: "messier, not all concentrated"): each
## circles its own spot round the cluster, out to `SWARM_REACH` world px, and now and then
## peels off on a wide loop `SWARM_PEEL` px out and comes back.
const SWARM_REACH := Vector2(26.0, 16.0)
const SWARM_PEEL := 30.0
## World px a second a commuter covers, and the least time a leg may take however close the
## flower is: a bee that turns round in a frame reads as a flicker.
const BEE_SPEED := 44.0
const BEE_LEG_LEAST := 0.8
## How far a leg bows off the straight line, world px, at its middle.
const BEE_ARC := 10.0
## How often the lent `host_spots` is asked again, and how many of the nearest it keeps.
const SPOTS_EVERY := 5.0
const SPOTS_NEAREST := 12
## With no flowers to visit, the bees loop about a spot up-left of the entrance.
const LOOP_CENTRE := Vector2(-16.0, -20.0)
const LOOP_WIDE := Vector2(26.0, 12.0)
## Where the air layer draws, absolute: over the walkers (9) and the hulls (12), like the
## wildlife's own air layer, and under the pigeons (21), which keep the sky.
const AIR_Z := 20
## One art pixel in world pixels: every bee is snapped to this grid, as Flora's are.
const PX := 2.0

## The honey the window fills with when the full frame cannot be read, and the gold of the
## ready mark when its sprite is missing. The builder's own values (`build_hive.py`).
const HONEY := Color8(238, 164, 38)
const GOLD := Color8(255, 204, 77)
const OUT := Color8(24, 18, 17)
## The pump's lamp, over the post drawn when there is no picture.
const LAMP := Color(1.0, 0.92, 0.62, 0.9)
const LAMP_GLOW := Color(1.0, 0.92, 0.62, 0.25)

## Where the hive stands, in tiles, or INF when there is none. Reset in `_exit_tree`.
static var tile := Vector2.INF
## The footprint's middle as an offset from `tile`, and its half extents, both in tiles. Read
## from the json's `foot_tiles` the first time anything asks (`contract()`); these defaults
## only stand in for a missing file.
static var centre := Vector2.ZERO
static var half := Vector2(0.45, 0.35)

static var _contract := {}
static var _contract_read := false

var day: DayCycle
## The angler is close enough to work it and there is something to do: the ready mark turns
## into the key chip (with no picture, the pump's lamp over the post).
var lit := false:
	set(value):
		if value != lit:
			lit = value
			queue_redraw()
## Set through `set_stage` or straight: either way the picture follows and `changed` fires.
var stage: Stage = Stage.EMPTY:
	set(value):
		var next := clampi(value, Stage.EMPTY, Stage.SETTLE) as Stage
		if next == stage:
			return
		var was := stage
		stage = next
		# The shrub grows in when the swarm comes, not when a save says it came long ago.
		if was == Stage.EMPTY and not _loading:
			_shrub_age = 0.0
		_redraw_all()
		if not _loading:
			changed.emit()
## Jars on the shelf, 0..12. Three a harvest; the shelf shows the nearest whole row under it.
var jars := 0:
	set(value):
		jars = clampi(value, 0, JARS_PER * HARVESTS_MOST)
		queue_redraw()
var harvests := 0
## The first-harvest ceremony has been played through.
var first_done := false
## The lake's play clock at which a BUSY hive turns READY, and when that refill began: the
## window's honey rises between the two.
var refill_at := 0.0
var refill_from := 0.0
var moment_seen := false
## The first honey's moment ("The honey is ready!") has run. Later refills are shown only in
## the world. Absent reads as not yet, which only a first READY ever asks.
var ready_seen := false
## A borrowed lake holds the arc (set by the lake; not saved).
var held := false
## The lake's play clock, pushed every second, for the window's fill.
var play_now := 0.0:
	set(value):
		play_now = value
		if stage == Stage.BUSY and window_rows() != _window_drawn:
			queue_redraw()
## Lent by the lake: grown flower heads on the island, as positions in the same space as
## this node's own `position`. With none lent, or none grown, the bees loop near the hive.
var host_spots: Callable

var _loading := false
var _clock := 0.0
var _shrub_age := SHRUB_GROW

var _sheet: Texture2D
var _sheet_image: Image
var _frames := {}
var _images := {}
var _roofs := {}
var _ground_hive := 0.3
var _ground_shelf := 0.5
var _window := Rect2i()
var _window_cols: Array = []
var _window_drawn := -1

var _flora_sheet: Texture2D
var _shrub_full := Rect2(123, 19, 15, 12)
var _shrub_sprout := Rect2(19, 51, 3, 4)

var _shelf_cast: Shade.Cast
var _hive_cast: Shade.Cast
var _shelf_cast_frame := &""
var _hive_cast_frame := &""
var _laid_lean := INF
var _wet := Color(0, 0, 0, 0)
var _laid_stretch := INF
var _shelf_skirt: Skirt.Patch
var _hive_skirt: Skirt.Patch

var _air: Air
var _spots := PackedVector2Array()
var _spots_in := 0.0

var _bee_points := PackedVector2Array()
var _bee_colors := PackedColorArray()
var _bee_indices := PackedInt32Array()


## The flying bees' own layer, at an absolute z over the walkers and the hulls: on the hive's
## z they would fly under anybody standing between the hive and the flowers.
class Air extends Node2D:
	var hive: Hive

	func _draw() -> void:
		if hive != null:
			hive.draw_air(self)


## The json, read once for the whole session, and the footprint statics filled from it.
## Every static that needs the file asks this first, so it does not matter whether the lake,
## the flora or the node itself is the first to want it.
static func contract() -> Dictionary:
	if not _contract_read:
		_contract_read = true
		var text := FileAccess.get_file_as_string(CONTRACT) if FileAccess.file_exists(CONTRACT) else ""
		var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else null
		if parsed is Dictionary:
			_contract = parsed
		var feet: Variant = _contract.get("foot_tiles")
		if feet is Dictionary:
			centre = _vec((feet as Dictionary).get("centre"), centre)
			half = _vec((feet as Dictionary).get("half"), half)
	return _contract


## Whether a tile-space point is on the footprint, grown by `grow` tiles on every side. A
## rectangle in tile space, as the crate's and the pump's are, so its faces are tile axes and
## a walker slides along one — but centred on `tile + centre`, not on `tile`.
static func covers(at: Vector2, grow: float = 0.0) -> bool:
	if tile == Vector2.INF:
		return false
	contract()
	var off := at - tile - centre
	return absf(off.x) < half.x + grow and absf(off.y) < half.y + grow


## Whether a plant standing at this tile-space point would draw into the hive's picture: its
## foot inside the picture's real rectangle, or up to `margin` world px under it or either
## side of it. The flora draws under the hive, so a flower whose foot is just in front of the
## picture still grows up into it. The flowering shrub and the swarm the node puts up later
## count as picture too: a flower behind the shrub read as painted on it.
static func hides(at: Vector2, margin: float = 6.0) -> bool:
	if tile == Vector2.INF:
		return false
	var p := Iso.tile_to_world(at.x, at.y) - Iso.tile_to_world(tile.x, tile.y)
	for box: Rect2 in [picture_box(), shrub_box(), swarm_box()]:
		if box.grow_individual(margin, 0.0, margin, margin).has_point(p):
			return true
	return false


## The whole hive-and-shelf picture, in the node's own space: the frame's box laid off its
## `foot` pixel, which is the node's origin.
static func picture_box() -> Rect2:
	var sheet := contract()
	var size := _vec(sheet.get("size"), Vector2(24.0, 24.0))
	var foot := _vec(sheet.get("foot"), Vector2(12.0, 20.0))
	return Rect2(-foot * ART_SCALE, size * ART_SCALE)


## Where the flowering shrub stands drawn, full grown, in the node's own space. `shrub_at` is
## the painted pixel of its bottom middle, as an offset from the foot pixel.
static func shrub_box() -> Rect2:
	var at := _vec(contract().get("shrub_at"), Vector2(-24.0, -26.0)) * ART_SCALE
	var size := Vector2(15.0, 12.0) * Flora.SCALE
	# The middle pixel of a 15-wide picture is its eighth; its bottom row is its last.
	return Rect2(at - Vector2(7.0 * Flora.SCALE, size.y - Flora.SCALE), size)


## Where the island swarm hangs, in the node's own space: `swarm_at` is its top middle pixel.
static func swarm_box() -> Rect2:
	var sheet := contract()
	var rect := _rect(sheet.get("swarm"), Rect2(0, 0, 9, 11))
	var at := _vec(sheet.get("swarm_at"), Vector2(-16.0, -31.0)) * ART_SCALE
	var middle := floorf(rect.size.x * 0.5)
	return Rect2(at - Vector2(middle * ART_SCALE, 0.0), rect.size * ART_SCALE)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sheet := contract()
	_sheet = Art.texture(ART)
	_sheet_image = Art.image(ART) if _sheet != null else null
	if _sheet_image != null and _sheet_image.get_format() != Image.FORMAT_RGBA8:
		_sheet_image.convert(Image.FORMAT_RGBA8)
	var frames: Variant = sheet.get("frames")
	if frames is Dictionary:
		for key: Variant in (frames as Dictionary):
			_frames[StringName(str(key))] = _rect((frames as Dictionary)[key], Rect2())
	_ground_hive = float(sheet.get("ground_hive", _ground_hive))
	_ground_shelf = float(sheet.get("ground_shelf", _ground_shelf))
	var window := _rect(sheet.get("window"), Rect2())
	_window = Rect2i(window)
	var cols: Variant = sheet.get("window_cols")
	if cols is Array:
		_window_cols = cols
	else:
		# No list of what shows: every column of the pane, top to bottom.
		for x in _window.size.x:
			_window_cols.append([_window.position.x + x, _window.position.y, _window.size.y])
	# The shrub is the flora's own picture, so a grown one reads as one of the island's.
	_flora_sheet = Art.texture(Flora.SHEET)
	if FileAccess.file_exists(Flora.TABLE):
		var table: Variant = JSON.parse_string(FileAccess.get_file_as_string(Flora.TABLE))
		if table is Dictionary and (table as Dictionary).get("shrub_flowering") is Dictionary:
			var shrub: Dictionary = (table as Dictionary)["shrub_flowering"]
			_shrub_full = _rect(shrub.get("full"), _shrub_full)
			_shrub_sprout = _rect(shrub.get("sprout"), _shrub_sprout)
	_air = Air.new()
	_air.name = &"HiveAir"
	_air.hive = self
	_air.z_index = AIR_Z
	_air.z_as_relative = false
	add_child(_air)


func _exit_tree() -> void:
	tile = Vector2.INF


func _process(delta: float) -> void:
	_clock += delta
	var moving := stage == Stage.SWARM or stage == Stage.READY or stage == Stage.SETTLE
	if stage != Stage.EMPTY and _shrub_age < SHRUB_GROW:
		_shrub_age = minf(_shrub_age + delta, SHRUB_GROW)
		moving = true
	if day != null:
		# The ink follows the rain every frame; the geometry only when the sun has stepped.
		var ink := Shade.tint_on(day, Shade.On.LAND)
		if _shelf_cast != null:
			_shelf_cast.self_modulate = ink
		if _hive_cast != null:
			_hive_cast.self_modulate = ink
		if absf(day.lean - _laid_lean) >= Shade.SWEEP_STEP \
				or absf(day.stretch - _laid_stretch) >= Shade.SWEEP_STEP:
			moving = true
	# A soaking (`Shade.wet_tint`) redraws the hive as well.
	var wet := Shade.wet_tint()
	if not wet.is_equal_approx(_wet):
		_wet = wet
		moving = true
	if moving:
		queue_redraw()
	if _flying():
		_spots_in -= delta
		if _spots_in <= 0.0:
			refresh_spots()
		_air.queue_redraw()


## Move the arc on. The picture, the shadow and the shrub follow, and `changed` fires.
func set_stage(s: Stage) -> void:
	stage = s


## Whether E at the hive has anything to open: a swarm to catch, a colony to settle, or a
## harvest waiting.
func actionable() -> bool:
	return stage == Stage.SWARM or stage == Stage.READY or stage == Stage.SETTLE


## What stands over the roof: the gold mark over anything with something to do (a swarm, a
## colony to settle, honey ready), turned into the key chip that opens the room while the angler
## is in reach (2026-10-04, Richard), or nothing.
func mark() -> StringName:
	if not actionable():
		return &""
	return &"chip" if lit else &"orb"


## The room's steps for this visit, in order. Empty when there is nothing to do.
func plan() -> Array[StringName]:
	var out: Array[StringName] = []
	if stage == Stage.SWARM:
		out.assign(PLAN_SWARM)
	elif stage == Stage.SETTLE:
		out.assign(PLAN_SETTLE)
	elif stage == Stage.READY:
		out.assign(PLAN_LATER)
	return out


func to_save() -> Dictionary:
	return {
		"stage": int(stage),
		"jars": jars,
		"harvests": harvests,
		"first_done": first_done,
		"refill_at": refill_at,
		"refill_from": refill_from,
		"moment_seen": moment_seen,
		"ready_seen": ready_seen,
	}


## Every field from the save, clamped into range, and **absent means the empty hive**: the
## opposite of the tours' "absent reads as done", by decision — a file written before the hive
## existed belongs to a run whose arc has not started. Assigned in full every time, so a load
## onto a live lake does not keep what the lake had. Emits nothing: a load is not an event.
func from_save(d: Dictionary) -> void:
	_loading = true
	var saved := clampi(roundi(_number(d, "stage", 0.0)), Stage.EMPTY, Stage.SETTLE) as Stage
	# A save from before the second pass: READY with the ceremony unplayed was a colony caught
	# and not yet crowned, which is SETTLE now. The crank kept nothing, so nothing else moves.
	if saved == Stage.READY and not _flag(d, "first_done", false):
		saved = Stage.SETTLE
	stage = saved
	_loading = false
	jars = roundi(_number(d, "jars", 0.0))
	harvests = clampi(roundi(_number(d, "harvests", 0.0)), 0, HARVESTS_MOST)
	first_done = _flag(d, "first_done", false)
	refill_at = maxf(_number(d, "refill_at", 0.0), 0.0)
	refill_from = maxf(_number(d, "refill_from", 0.0), 0.0)
	moment_seen = _flag(d, "moment_seen", false)
	ready_seen = _flag(d, "ready_seen", harvests > 0)
	# A shrub that came up long ago is simply there.
	_shrub_age = SHRUB_GROW
	_redraw_all()


## The whole drawn picture, hive and shelf, in the node's own space. Asymmetric about the
## node: what a walker must be inside, across, to count as behind it.
func picture_rect() -> Rect2:
	return picture_box()


## Whether a walker whose feet are at `at` (in the lake's space, the same as `position`) is
## behind the picture and so wants the layer under it: north of the footprint's near faces
## and inside the picture's real span across. While the shrub is up, standing north of its
## foot inside its span counts too. For the lake's `_walker_layer`.
func walker_behind(at: Vector2) -> bool:
	contract()
	var local := at - position
	var from := Iso.world_to_tile(local) - centre
	var box := picture_rect()
	if from.x < half.x and from.y < half.y and local.x > box.position.x and local.x < box.end.x:
		return true
	if stage != Stage.EMPTY:
		var shrub := shrub_box()
		if local.y < shrub.end.y and local.x > shrub.position.x and local.x < shrub.end.x:
			return true
	return false


## The frame the hive part is drawn in for this stage.
func hive_frame() -> StringName:
	match stage:
		Stage.EMPTY, Stage.SWARM:
			return &"hive_weathered"
		Stage.READY:
			return &"hive_full"
	return &"hive_colony"


## The frame the shelf is drawn in: bare and weathered until the colony moves in, then its
## jars, a row of three a harvest.
func shelf_frame() -> StringName:
	if stage == Stage.EMPTY or stage == Stage.SWARM:
		return &"shelf_weathered"
	return StringName("shelf_%d" % (jars - jars % JARS_PER))


## How full the window reads, 0..1: rising over the refill while BUSY, the colony's own
## little when DONE, full when READY (the full frame carries it), none before the colony.
func window_share() -> float:
	match stage:
		Stage.READY:
			return 1.0
		Stage.DONE:
			return DONE_SHARE
		Stage.BUSY:
			var span := refill_at - refill_from
			if span <= 0.0:
				return 1.0
			return clampf((play_now - refill_from) / span, 0.0, 1.0)
	return 0.0


## The rows of the pane the honey reaches, counted up from its bottom. The pane shows only a
## couple of pixels under the roof's gable, so the honey reads as empty, half or full.
func window_rows() -> int:
	return roundi(window_share() * float(_window.size.y))


## The landing board's lip, where the bees leave and land, in the node's own space.
func entrance_point() -> Vector2:
	var at := _vec(contract().get("entrance"), Vector2(-1.0, -1.0))
	if at.x < 0.0:
		return Vector2(0.0, -6.0)
	return _pixel_middle(at)


## The middle of the ready mark at rest, over the roof peak, in the node's own space.
func ready_point() -> Vector2:
	var at: Variant = contract().get("ready_at")
	if at is Array:
		return _pixel_middle(_vec(at, Vector2.ZERO))
	var box := picture_rect()
	return Vector2(box.get_center().x, box.position.y - 12.0)


## The ready mark's bob this moment: 0 at rest down to `-READY_BOB` at the top.
func ready_bob() -> float:
	return -READY_BOB * 0.5 * (1.0 - cos(_clock * READY_RATE))


## How far the shrub has grown in, 0..1. Nought while the hive is empty.
func shrub_grown() -> float:
	if stage == Stage.EMPTY:
		return 0.0
	return clampf(_shrub_age / SHRUB_GROW, 0.0, 1.0)


## Ask the lent `host_spots` again and keep the nearest few, in the node's own space. Called
## on a timer while the bees fly; public so a harness can ask it at once.
func refresh_spots() -> void:
	_spots_in = SPOTS_EVERY
	_spots = PackedVector2Array()
	if not host_spots.is_valid():
		return
	var got: Variant = host_spots.call()
	if not (got is PackedVector2Array):
		return
	var home := entrance_point()
	var near: Array = []
	for spot: Vector2 in (got as PackedVector2Array):
		near.append(spot - position)
	var nearer := func(a: Vector2, b: Vector2) -> bool:
		return a.distance_squared_to(home) < b.distance_squared_to(home)
	near.sort_custom(nearer)
	for k in mini(near.size(), SPOTS_NEAREST):
		_spots.append(near[k])


## Where every commuting bee is this moment, in the node's own space, before snapping. Empty
## unless the colony is in. For the harness and the probe.
func commuters() -> PackedVector2Array:
	var out := PackedVector2Array()
	if not _flying():
		return out
	for i in COMMUTERS:
		var bee := _fly(i)
		out.append(Vector2(bee.x, bee.y))
	return out


## The picture and where it is drawn, in the lake's space: a roof for the rain and a
## reflection for the puddles. The shelf and the hive composited into one image of the
## frame's size, cut once per pair of frames and handed back as the same instances every
## call, so `Weather`'s cache (keyed by the image) holds and the puddles mirror one frame and
## not the sheet.
func roof() -> Dictionary:
	if _sheet_image == null or _frames.is_empty():
		return {}
	var key := "%s|%s" % [shelf_frame(), hive_frame()]
	if not _roofs.has(key):
		var size := Vector2i(_vec(contract().get("size"), Vector2(1.0, 1.0)))
		var image := Image.create_empty(maxi(size.x, 1), maxi(size.y, 1), false, Image.FORMAT_RGBA8)
		for part: Image in [_frame_image(shelf_frame()), _frame_image(hive_frame())]:
			if part != null:
				image.blend_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), Vector2i.ZERO)
		_roofs[key] = {"image": image, "texture": ImageTexture.create_from_image(image)}
	var cached: Dictionary = _roofs[key]
	var box := picture_rect()
	return {"image": cached["image"], "texture": cached["texture"],
		"rect": Rect2(position + box.position, box.size)}


func _draw() -> void:
	if _sheet == null or _frames.is_empty():
		# No picture: a post, so there is still something to walk up to.
		draw_rect(Rect2(-5.0, -34.0, 10.0, 34.0), Color(0.55, 0.62, 0.68))
		if lit:
			_draw_lamp(Vector2(0.0, -44.0))
		return
	var box := picture_rect()
	var shelf_name := shelf_frame()
	var hive_name := hive_frame()
	if day != null:
		_lay_shades(box, shelf_name, hive_name)
	_stamp(shelf_name, box)
	_stamp(hive_name, box)
	if stage == Stage.BUSY or stage == Stage.DONE:
		_draw_window(box)
	_draw_skirts(box)
	if stage != Stage.EMPTY:
		_draw_shrub()
		if stage == Stage.SWARM:
			_draw_swarm()
	if stage == Stage.READY or stage == Stage.SETTLE:
		_draw_crowd()
	match mark():
		&"chip":
			_draw_chip()
		&"orb":
			_draw_ready()


## Draw the commuting bees on the air layer.
func draw_air(on: CanvasItem) -> void:
	if not _flying():
		return
	_bees_begin()
	var flick := int(_clock * 18.0) % 2 == 0
	for i in COMMUTERS:
		var bee := _fly(i)
		_bee(Vector2(bee.x, bee.y), bee.z, flick)
	_bees_flush(on)


func _flying() -> bool:
	return _air != null and stage != Stage.EMPTY and stage != Stage.SWARM


func _redraw_all() -> void:
	queue_redraw()
	if _air != null:
		_air.queue_redraw()


## One shadow per part, each off its own frame's pixels and its own ground. A new frame is a
## new Cast: `Cast.lay` would keep the old silhouette otherwise (it keys on box and ground).
func _lay_shades(box: Rect2, shelf_name: StringName, hive_name: StringName) -> void:
	if _shelf_cast == null or _shelf_cast_frame != shelf_name:
		_shelf_cast = _new_cast(_shelf_cast, &"HiveShelfShade")
		_shelf_cast_frame = shelf_name
	if _hive_cast == null or _hive_cast_frame != hive_name:
		_hive_cast = _new_cast(_hive_cast, &"HiveShade")
		_hive_cast_frame = hive_name
	# The land's ink (one sun, 2026-10-02): both parts stand on the island's grass.
	var ink := Shade.ink_on(day.ink, Shade.On.LAND)
	_shelf_cast.lay(_frame_image(shelf_name), box, day.lean, day.stretch, _ground_shelf, ink)
	_hive_cast.lay(_frame_image(hive_name), box, day.lean, day.stretch, _ground_hive, ink)
	_laid_lean = day.lean
	_laid_stretch = day.stretch


func _new_cast(old: Shade.Cast, called: StringName) -> Shade.Cast:
	if old != null:
		remove_child(old)
		old.queue_free()
	var made := Shade.Cast.new()
	made.name = called
	add_child(made)
	return made


func _stamp(frame: StringName, box: Rect2) -> void:
	if _frames.has(frame):
		draw_texture_rect_region(_sheet, box, _frames[frame], Shade.wet_tint())


## The honey in the window, rising from the bottom of the pane: each showing pixel takes the
## full frame's own colour at that spot, so a full pane here is the full frame's pane.
func _draw_window(box: Rect2) -> void:
	var rows := window_rows()
	_window_drawn = rows
	if rows <= 0 or _window.size.y <= 0:
		return
	var full := _frame_image(&"hive_full")
	var top := _window.position.y + _window.size.y - rows
	for col: Variant in _window_cols:
		if not (col is Array) or (col as Array).size() < 3:
			continue
		var x := int((col as Array)[0])
		var from := int((col as Array)[1])
		var to := from + int((col as Array)[2])
		for y in range(maxi(from, top), to):
			var ink := HONEY
			if full != null and x >= 0 and y >= 0 and x < full.get_width() and y < full.get_height():
				var there := full.get_pixel(x, y)
				if there.a > 0.5:
					ink = there
			draw_rect(Rect2(box.position + Vector2(x, y) * ART_SCALE, Vector2.ONE * ART_SCALE), ink * Shade.wet_tint())


## Grass along each part's own bottom line, baked once: the ground silhouette is the same in
## every frame, so the painted ones (no cobweb) stand for all of them.
func _draw_skirts(box: Rect2) -> void:
	if _shelf_skirt == null:
		var shelf := _frame_image(&"shelf_0")
		if shelf == null:
			shelf = _frame_image(shelf_frame())
		_shelf_skirt = Skirt.hem(shelf, box, SKIRT_SEED, PackedVector2Array(), SKIRT_BLADES)
	if _hive_skirt == null:
		var hive := _frame_image(&"hive_colony")
		if hive == null:
			hive = _frame_image(hive_frame())
		_hive_skirt = Skirt.hem(hive, box, SKIRT_SEED + 1, PackedVector2Array(), SKIRT_BLADES)
	_shelf_skirt.over(self)
	_hive_skirt.over(self)


## The flowering shrub, from the flora's own sheet: the sprout, then the full picture rising
## out of it, the way `Flora._lay` grows a plant.
func _draw_shrub() -> void:
	if _flora_sheet == null:
		return
	var t := shrub_grown()
	if t <= 0.0:
		return
	var full := shrub_box()
	var bottom := full.end.y
	var middle := full.position.x + 7.5 * Flora.SCALE
	var rect := _shrub_full
	var rise := 1.0
	if t < Flora.SPROUT_UNTIL:
		rect = _shrub_sprout
	else:
		var u := (t - Flora.SPROUT_UNTIL) / (1.0 - Flora.SPROUT_UNTIL)
		rise = 0.5 + 0.5 * (1.0 - (1.0 - u) * (1.0 - u))
	var w := rect.size.x * Flora.SCALE
	var h := rect.size.y * Flora.SCALE * rise
	var left := floorf((middle - w * 0.5) / PX) * PX
	draw_texture_rect_region(_flora_sheet, Rect2(left, bottom - h, w, h), rect)


## The swarm cluster hanging off the shrub, fading in as the shrub finishes, with bees
## circling it on the clock.
func _draw_swarm() -> void:
	var t := shrub_grown()
	var seen := clampf((t - Flora.SPROUT_UNTIL) / (1.0 - Flora.SPROUT_UNTIL), 0.0, 1.0)
	if seen <= 0.0:
		return
	var box := swarm_box()
	var rect := _rect(contract().get("swarm"), Rect2())
	if rect.size.x > 0.0:
		draw_texture_rect_region(_sheet, box, rect, Color(1.0, 1.0, 1.0, seen))
	_bees_begin()
	var flick := int(_clock * 18.0) % 2 == 0
	var middle := box.get_center()
	for i in SWARM_SPECKS:
		var h1 := _roll(i, 11.0)
		var h2 := _roll(i, 12.0)
		var h3 := _roll(i, 13.0)
		var h4 := _roll(i, 14.0)
		# Its own spot round the cluster, wandering, and its own loop about it.
		var spot := middle + Vector2(
			(h3 * 2.0 - 1.0) * SWARM_REACH.x + sin(_clock * (0.4 + 0.3 * h4) + h1 * 7.0) * 6.0,
			(h4 * 2.0 - 1.0) * SWARM_REACH.y + cos(_clock * (0.35 + 0.3 * h3) + h2 * 5.0) * 4.0
		)
		var a := _clock * (2.0 + h1 * 2.4) * (1.0 if h2 < 0.5 else -1.0) + h2 * TAU
		var r := 4.0 + 6.0 * h1
		# Now and then a long loop out and back, eased so it leaves and returns smoothly.
		var peel_phase := fposmod(_clock / (5.0 + 6.0 * h3) + h4, 1.0)
		var peel := sin(clampf((peel_phase - 0.7) / 0.3, 0.0, 1.0) * PI)
		r += peel * SWARM_PEEL * (0.6 + 0.4 * h2)
		var at := spot + Vector2(cos(a) * r + sin(a * 2.7) * 2.0, sin(a * 1.3) * r * 0.6)
		_bee(at, -signf(sin(a)), flick, seen)
	_bees_flush(self)


## A harvest ready: bees crowding the landing board, some walking it and some hovering just
## off it. On the hive's own layer, not the air's, because they are on the picture: over a
## walker standing in front of the hive they would be bees on the walker.
func _draw_crowd() -> void:
	_bees_begin()
	var flick := int(_clock * 18.0) % 2 == 0
	var home := entrance_point()
	for i in CROWD:
		var h1 := _roll(i, 21.0)
		var h2 := _roll(i, 22.0)
		var walking := i % 2 == 0
		var at := home + Vector2(
			(float(i) - float(CROWD - 1) * 0.5) * 3.0 + sin(_clock * (1.6 + h1) + h2 * 6.0) * 2.0,
			(-1.0 if walking else -6.0 - 3.0 * h2) + cos(_clock * (1.3 + h2) + h1 * 5.0) * 1.5
		)
		_bee(at, signf(cos(_clock * (1.6 + h1) + h2 * 6.0)), flick and not walking)
	_bees_flush(self)


## The gold mark over the roof, bobbing: the builder's sprite, or a gold disc if the sheet
## has none.
func _draw_ready() -> void:
	var at := ready_point() + Vector2(0.0, ready_bob())
	var rect := _rect(contract().get("ready"), Rect2())
	if rect.size.x > 0.0:
		draw_texture_rect_region(_sheet, Rect2(at - rect.size * ART_SCALE * 0.5, rect.size * ART_SCALE), rect)
		return
	draw_circle(at, 8.0, OUT)
	draw_circle(at, 6.0, GOLD)


## The key chip in the ready mark's place: the shed room's prompt, the interact key named as
## this keyboard prints it, or the pad's button in pad mode.
func _draw_chip() -> void:
	var at := ready_point()
	var box := Rect2((at - Vector2(CHIP, CHIP) * 0.5).floor(), Vector2(CHIP, CHIP))
	var key := Binds.shown(&"interact", Pad.is_pad())
	# A pad button is its own glyph, a button already: drawn alone, not inside a chip.
	var glyph := Glyphs.lone(key)
	if glyph != null:
		Glyphs.draw_centred(self, glyph, box.get_center(), Glyphs.prompt_px() * _world_px())
		return
	draw_rect(box, Color(Style.WOOD.r, Style.WOOD.g, Style.WOOD.b, 0.9))
	draw_rect(box, Style.INK_DIM, false, 1.0)
	var size := Style.TEXT_SMALL
	var wide := Style.measure(key, size).x
	Style.write(self, key, size, box.position + Vector2((CHIP - wide) * 0.5, 14.0), Style.INK)


## World pixels to a canvas pixel: the camera's zoom undone, so a glyph drawn here is the
## same size on the screen at every zoom stop.
func _world_px() -> float:
	return 1.0 / maxf(get_canvas_transform().get_scale().x, 0.01)


func _draw_lamp(at: Vector2) -> void:
	draw_circle(at, 7.0, LAMP)
	draw_circle(at, 12.0, LAMP_GLOW)


## Where commuter `i` is: x, y in the node's space, z the way it faces (+1 right). A leg is a
## ping-pong between the entrance and one of the nearest grown flowers, eased at both ends so
## a bee lingers at the flower and at the board, bowed off the straight line and wobbling a
## little. With no flowers, a loop about a spot up-left of the entrance.
func _fly(i: int) -> Vector3:
	var h1 := _roll(i, 1.0)
	var h2 := _roll(i, 2.0)
	var h3 := _roll(i, 3.0)
	var home := entrance_point()
	if _spots.is_empty():
		var a := _clock * (1.2 + h1 * 0.9) + h2 * TAU
		var at := home + LOOP_CENTRE + Vector2(
			cos(a) * LOOP_WIDE.x * (0.7 + 0.5 * h3), sin(a * 1.3) * LOOP_WIDE.y * (0.7 + 0.5 * h1)
		)
		return Vector3(at.x, at.y, -signf(sin(a)))
	var spot := _spots[i % _spots.size()]
	var gap := spot - home
	var leg := maxf(gap.length() / (BEE_SPEED * (0.8 + 0.4 * h1)), BEE_LEG_LEAST)
	var p := fposmod(_clock / leg + h2 * 2.0, 2.0)
	var out := p < 1.0
	var u := p if out else 2.0 - p
	var eased := u * u * (3.0 - 2.0 * u)
	var across := Vector2(-gap.y, gap.x).normalized() if gap.length() > 0.01 else Vector2.UP
	var at := home.lerp(spot, eased) \
		+ across * sin(u * PI) * BEE_ARC * (h3 * 2.0 - 1.0) \
		+ Vector2(0.0, sin(_clock * 7.0 + h1 * 9.0) * 1.5)
	var facing := signf(gap.x) * (1.0 if out else -1.0)
	return Vector3(at.x, at.y, facing)


## One bee on whole art pixels, Flora's way: the gold pixel, the dark band trailing it, and a
## pale wing pixel flicking over it.
func _bee(at: Vector2, facing: float, flick: bool, alpha: float = 1.0) -> void:
	var snapped := (at / PX).floor() * PX
	var back := Vector2(-(facing if facing != 0.0 else 1.0), 0.0) * PX
	_bee_quad(snapped, Color(Flora.BEE_COLOR, Flora.BEE_COLOR.a * alpha))
	_bee_quad(snapped + back, Color(Flora.BEE_BAND, Flora.BEE_BAND.a * alpha))
	if flick:
		_bee_quad(snapped + Vector2(0.0, -PX), Color(Flora.BEE_WING, Flora.BEE_WING.a * alpha))


func _bees_begin() -> void:
	_bee_points.resize(0)
	_bee_colors.resize(0)
	_bee_indices.resize(0)


## Every bee since `_bees_begin` in one untextured batch.
func _bees_flush(on: CanvasItem) -> void:
	if _bee_indices.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(
		on.get_canvas_item(), _bee_indices, _bee_points, _bee_colors
	)


func _bee_quad(at: Vector2, color: Color) -> void:
	var base := _bee_points.size()
	_bee_points.append(at)
	_bee_points.append(at + Vector2(PX, 0.0))
	_bee_points.append(at + Vector2(PX, PX))
	_bee_points.append(at + Vector2(0.0, PX))
	for n in 4:
		_bee_colors.append(color)
	_bee_indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))


## A frame's own pixels, cut off the sheet once and kept.
func _frame_image(frame: StringName) -> Image:
	if _images.has(frame):
		return _images[frame]
	var image: Image = null
	if _sheet_image != null and _frames.has(frame):
		var rect: Rect2 = _frames[frame]
		image = _sheet_image.get_region(Rect2i(rect))
	_images[frame] = image
	return image


## The middle of a frame pixel, in the node's space. Frame pixel `foot` has its top-left
## corner on the node's origin, so every pixel lands on the even world grid.
func _pixel_middle(at: Vector2) -> Vector2:
	return picture_rect().position + (at + Vector2(0.5, 0.5)) * ART_SCALE


static func _roll(i: int, salt: float) -> float:
	var h := sin(float(i) * 12.9898 + salt * 78.233) * 43758.5453
	return h - floorf(h)


static func _vec(value: Variant, fallback: Vector2) -> Vector2:
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	return fallback


static func _rect(value: Variant, fallback: Rect2) -> Rect2:
	if value is Array and (value as Array).size() >= 4:
		var v := value as Array
		return Rect2(float(v[0]), float(v[1]), float(v[2]), float(v[3]))
	return fallback


## A number out of a save, or `fallback` when it is missing, not a number, or not finite.
static func _number(d: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = d.get(key, fallback)
	if value is int or value is float:
		var out := float(value)
		return out if is_finite(out) else fallback
	return fallback


static func _flag(d: Dictionary, key: String, fallback: bool) -> bool:
	var value: Variant = d.get(key, fallback)
	if value is bool:
		return value
	if value is int or value is float:
		return float(value) != 0.0
	return fallback
