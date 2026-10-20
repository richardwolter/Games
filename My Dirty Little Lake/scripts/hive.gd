## The old beehive on the island's lawn, left of the hut: its state, its save and its picture.
##
## The beehive sidequest (`/grill-me` with Richard, 2026-09-29; the build contract is
## `docs/hive/contract.md`, sections 3.1 and 5), redrawn in the hive's visual overhaul
## (2026-10-18, Richard's pick "Hive C" off `tools/hive_look/last_island.png`): the hive 1.4x on
## a sky-blue painted cupboard, two shelves on each seen face, **the jars the player holds
## standing on them, one by one** (`HoneyPot`'s shelf jar at each of `jar_slots`, up to twelve).
## No separate shelf on the lawn. Beside it a young flowering tree, there from the start, which
## blossoms when the swarm comes and has the swarm hang off a bough. `tools/build_hive_island.py`
## bakes the picture and its json.
##
## A front-on painting on the lawn like the pump, and dressed the way the pump is — blades along
## its bottom line (`Skirt.hem`) and a shadow swept off its silhouette (`Shade.Cast`) — but not a
## copy of the pump, because three of the pump's assumptions do not hold here:
## - **It changes picture.** Weathered, the colony with its window at one of five levels, and
##   full (with the drip). `Shade.Cast.lay` caches on the box and the ground alone, so a new
##   silhouette in the same box would keep the old shadow for ever: weathered, colony and full
##   each get their own Cast (the colony's five levels share one outline and so one Cast).
## - **The tree is part of it**, at `tree_at` off the foot: drawn by this node, its shadow laid
##   down off its own silhouette with `Shade.cast` (a crown in the air throws its shade apart
##   from the trunk, the way the forest's trees do), the swarm's the same way.
## - **Its footprint is the cupboard's diamond**, a tile-axis square round the node (`centre`,
##   `half`, from the json), not the pump's square round its tile.
##
## And one of the pump's habits is not copied: `Pump.roof()` hands out a fresh `Image` every
## call, which misses `Weather`'s cache on every landing. Every picture here is cut once and
## kept.
##
## **The bees are `BeeArt`'s mini bee** (Richard: "Bees A"), animated, facing the way they go,
## on whole world pixels, laid out in one batch (`BeeBatch`); every one in the air throws a blot
## on the lawn under it, moved by `Shade.drop` of its height.
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

## World pixels to a painted one: 1.0, the hut's grain (since 2026-10-01). The json's
## coordinates are in these pixels: the hive, the tree, the jars and the bees all at one.
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

## How long the tree takes to blossom when the swarm arrives, in seconds (the blossom fades in
## over the bare crown; the swarm on its bough fades in over the last of it). The tree itself
## stands from the start: since the overhaul (2026-10-18) it is the swarm's tree, not a shrub
## that springs up for it.
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

## Bees: `BeeArt`'s mini bee, the round lake bee, at one world px a sheet px (the flora's are
## the same bee, so the island has one bee and not two). Real bees now, about eight px across,
## so the swarm's loose ones are a handful round the hanging mass rather than the 22 one-pixel
## specks they were; the mass itself carries the crowd.
## Five, down from eight (2026-10-19, Richard: fewer bees in general).
const COMMUTERS := 5
const CROWD := 4
const SWARM_SPECKS := 6
## Two scouts at the empty hive's door while the swarm hangs on its tree: the mockup's.
const SCOUTS := 2
## The swarm's bees fly loose (2026-10-04, Richard: "messier, not all concentrated"): each
## circles its own spot round the mass, out to `SWARM_REACH` world px, and now and then
## peels off on a wide loop `SWARM_PEEL` px out and comes back.
const SWARM_REACH := Vector2(16.0, 12.0)
const SWARM_PEEL := 22.0
## How high over the lawn a commuter is at a flower's head, and how far its leg climbs over
## the straight line between the door and the flower, world px: the colony's stream leaves the
## door upwards and comes down onto the bed from above, clear of the jars in the stand (option
## C's note). The flowers' heads stand about `FLOWER_HIGH` over their feet.
const FLOWER_HIGH := 8.0
const BEE_LIFT := 26.0
## A flying bee's blot on the lawn is 4 px wide while it flies low, 3 once it is over this
## many world px up.
const BLOT_HIGH := 22.0
## World px a second a commuter covers, and the least time a leg may take however close the
## flower is: a bee that turns round in a frame reads as a flicker.
const BEE_SPEED := 44.0
const BEE_LEG_LEAST := 0.8
## The first share of a leg out of the board that the bee spends inside the hive (not drawn).
const INSIDE := 0.12
## How far a leg bows off the straight line, world px, at its middle.
const BEE_ARC := 10.0
## How often the lent `host_spots` is asked again, and how many of the nearest it keeps.
const SPOTS_EVERY := 5.0
const SPOTS_NEAREST := 12
## With no flowers grown to visit, the bees forage these spots of lawn round the hive (world
## px off its foot, ground points): a loop over the hive's face read as a cloud stuck to it.
const IDLE_SPOTS: Array[Vector2] = [Vector2(78.0, 34.0), Vector2(-50.0, 48.0), Vector2(20.0, 64.0)]
## Where the air layer draws, absolute: over the walkers (9) and the hulls (12), like the
## wildlife's own air layer, and under the pigeons (21), which keep the sky.
const AIR_Z := 20
## Every bee stands on a whole world pixel (`BeeBatch` snaps its anchor).
const PX := 1.0

## The gold of the ready mark when its sprite is missing. The builder's own value.
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
static var half := Vector2(0.44, 0.44)

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
## The demo's hive, until its "Not in the demo" card has been asked for: the key chip stands
## over the empty hive while the angler is in reach, and nothing stands there otherwise. The
## lake sets it (`Lake._hive_tease`).
var tease := false:
	set(value):
		if value != tease:
			tease = value
			queue_redraw()
## Set through `set_stage` or straight: either way the picture follows and `changed` fires.
var stage: Stage = Stage.EMPTY:
	set(value):
		var next := clampi(value, Stage.EMPTY, Stage.SETTLE) as Stage
		if next == stage:
			return
		var was := stage
		stage = next
		# The tree blossoms when the swarm comes, not when a save says it came long ago.
		if was == Stage.EMPTY and not _loading:
			_shrub_age = 0.0
		_redraw_all()
		if not _loading:
			changed.emit()
## Jars in the cupboard, 0..12. Three a harvest, eaten one at a time since 2026-10-16
## (`Lake._eat_honey`), and **drawn one at a time** since the overhaul (2026-10-18): jar k
## stands at `jar_slots[k]` while k < jars, so the cupboard says exactly what the HUD says.
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
		if stage == Stage.BUSY and window_level() != _level_drawn:
			queue_redraw()
## Lent by the lake: grown flower heads on the island, as positions in the same space as
## this node's own `position`. With none lent, or none grown, the bees forage the lawn round it (`IDLE_SPOTS`).
var host_spots: Callable

var _loading := false
var _clock := 0.0
var _shrub_age := SHRUB_GROW

var _sheet: Texture2D
var _sheet_image: Image
var _frames := {}
var _images := {}
var _roofs := {}
var _ground_hive := 0.16
var _levels := 4
var _level_drawn := -1
var _slots: Array = []

var _hive_cast: Shade.Cast
var _hive_cast_frame := &""
var _laid_lean := INF
var _wet := Color(0, 0, 0, 0)
var _laid_stretch := INF
var _hive_skirt: Skirt.Patch

var _air: Air
var _blots: Blots
var _bees := BeeBatch.new()
var _spots := PackedVector2Array()
var _spots_in := 0.0


## The flying bees' own layer, at an absolute z over the walkers and the hulls: on the hive's
## z they would fly under anybody standing between the hive and the flowers.
class Air extends Node2D:
	var hive: Hive

	func _draw() -> void:
		if hive != null:
			hive.draw_air(self)


## The flying bees' blots on the lawn: a child drawn behind the hive's own picture, so the
## hive and the tree stand over the blot of a bee flying behind them.
class Blots extends Node2D:
	var hive: Hive

	func _draw() -> void:
		if hive != null:
			hive.draw_blots(self)


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
## a walker slides along one — centred on `tile + centre`.
static func covers(at: Vector2, grow: float = 0.0) -> bool:
	if tile == Vector2.INF:
		return false
	contract()
	var off := at - tile - centre
	return absf(off.x) < half.x + grow and absf(off.y) < half.y + grow


## Whether a plant standing at this tile-space point would draw into the hive's picture: its
## foot inside the picture's real rectangle, or up to `margin` world px under it or either
## side of it. The flora draws under the hive, so a flower whose foot is just in front of the
## picture still grows up into it. The tree and its swarm count as picture too: a flower
## behind the tree read as painted on it.
static func hides(at: Vector2, margin: float = 6.0) -> bool:
	if tile == Vector2.INF:
		return false
	var p := Iso.tile_to_world(at.x, at.y) - Iso.tile_to_world(tile.x, tile.y)
	for box: Rect2 in [picture_box(), shrub_box(), swarm_box()]:
		if box.grow_individual(margin, 0.0, margin, margin).has_point(p):
			return true
	return false


## The hive's picture (hive and cupboard), in the node's own space: the frame's box laid off
## its `foot` pixel, which is the node's origin.
static func picture_box() -> Rect2:
	var sheet := contract()
	var size := _vec(sheet.get("size"), Vector2(24.0, 24.0))
	var foot := _vec(sheet.get("foot"), Vector2(12.0, 20.0))
	return Rect2(-foot * ART_SCALE, size * ART_SCALE)


## Where the tree stands drawn, in the node's own space: `tree_at` is where its trunk's foot
## pixel lands, off the hive's foot. Named for the shrub it replaced; the lake and the flora
## ask it under that name.
static func shrub_box() -> Rect2:
	var sheet := contract()
	var at := _vec(sheet.get("tree_at"), Vector2(-74.0, -17.0))
	var foot := _vec(sheet.get("tree_foot"), Vector2(18.0, 62.0))
	var size := _vec(sheet.get("tree_size"), Vector2(56.0, 64.0))
	return Rect2((at - foot) * ART_SCALE, size * ART_SCALE)


## Where the swarm hangs on its bough, in the node's own space: the mass's own box.
static func swarm_box() -> Rect2:
	var sheet := contract()
	var px := _rect(sheet.get("swarm_px"), Rect2(27, 28, 19, 25))
	return Rect2(shrub_box().position + px.position * ART_SCALE, px.size * ART_SCALE)


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
	_levels = maxi(int(sheet.get("levels", _levels)), 1)
	var slots: Variant = sheet.get("jar_slots")
	if slots is Array:
		_slots = slots
	_blots = Blots.new()
	_blots.name = &"HiveBeeBlots"
	_blots.hive = self
	_blots.show_behind_parent = true
	add_child(_blots)
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
		if _hive_cast != null:
			_hive_cast.self_modulate = Shade.tint_on(day, Shade.On.LAND)
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
	if _blots != null and stage != Stage.EMPTY:
		_blots.queue_redraw()


## Move the arc on. The picture, the shadow and the tree follow, and `changed` fires.
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
		return &"chip" if tease and lit else &""
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
	# A tree that blossomed long ago is simply in flower.
	_shrub_age = SHRUB_GROW
	_redraw_all()


## The hive's drawn picture, in the node's own space. Asymmetric about the node: what a walker
## must be inside, across, to count as behind it.
func picture_rect() -> Rect2:
	return picture_box()


## Whether a walker whose feet are at `at` (in the lake's space, the same as `position`) is
## behind the picture and so wants the layer under it: north of the footprint's near faces
## and inside the picture's real span across. Standing north of the tree's foot inside its span
## counts too: the tree is drawn on the hive's layer. For the lake's `_walker_layer`.
func walker_behind(at: Vector2) -> bool:
	contract()
	var local := at - position
	var from := Iso.world_to_tile(local) - centre
	var box := picture_rect()
	if from.x < half.x and from.y < half.y and local.x > box.position.x and local.x < box.end.x:
		return true
	var tree := shrub_box()
	if local.y < tree.end.y and local.y > tree.position.y \
			and local.x > tree.position.x and local.x < tree.end.x:
		return true
	return false


## The frame the hive is drawn in for this stage: weathered before the colony, full (the drip
## off the board) when the honey is ready, otherwise the colony with its window at the level
## the refill has reached.
func hive_frame() -> StringName:
	match stage:
		Stage.EMPTY, Stage.SWARM:
			return &"hive_weathered"
		Stage.READY:
			return &"hive_full"
	return StringName("hive_colony%d" % window_level())


## The silhouette a frame casts and stands its grass on: the colony's five window levels are
## one outline, so they share one shadow.
func _outline_of(frame: StringName) -> StringName:
	return &"hive_colony0" if String(frame).begins_with("hive_colony") else frame


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


## The window's honey in steps (the builder bakes `levels`, 4): 0 the empty pane .. 4 full,
## each a couple of rows under a pale meniscus.
func window_level() -> int:
	return clampi(roundi(window_share() * float(_levels)), 0, _levels)


## Where jar `k` (0..11) stands: its feet pixel's middle-bottom, in the node's own space, and
## whether it is on the shaded face. Fill order is the builder's: the lit face's top shelf,
## the shaded face's top shelf, then the two bottom shelves.
func jar_slot(k: int) -> Dictionary:
	if k < 0 or k >= _slots.size() or not (_slots[k] is Array):
		return {}
	var slot: Array = _slots[k]
	return {
		"feet": picture_rect().position + Vector2(float(slot[0]), float(slot[1])) * ART_SCALE,
		"shaded": int(slot[2]) != 0 if slot.size() > 2 else false,
	}


## How many jars are drawn in the cupboard now: `jars`, but none in the weathered cupboard.
func jars_shown() -> int:
	if stage == Stage.EMPTY or stage == Stage.SWARM:
		return 0
	return mini(jars, _slots.size())


## The landing board's lip, where the bees leave and land, in the node's own space.
func entrance_point() -> Vector2:
	var at := _vec(contract().get("entrance"), Vector2(-1.0, -1.0))
	if at.x < 0.0:
		return Vector2(0.0, -6.0)
	return _pixel_middle(at)


## How high the landing board stands over the lawn under it, world px.
func entrance_high() -> float:
	return float(contract().get("entrance_high", 30.0)) * ART_SCALE


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


## How far the tree has blossomed, 0..1. Nought while the hive is empty.
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


## Where every commuting bee is this moment, in the node's own space. Empty unless the colony
## is in. For the harness and the probe.
func commuters() -> PackedVector2Array:
	var out := PackedVector2Array()
	if not _flying():
		return out
	for i in COMMUTERS:
		var bee := _fly(i, _clock)
		out.append(Vector2(bee.x, bee.y))
	return out


## The picture and where it is drawn, in the lake's space: a roof for the rain and a
## reflection for the puddles. The hive's frame with its jars, cut once per frame and jar
## count and handed back as the same instances every call, so `Weather`'s cache (keyed by the
## image) holds and the puddles mirror one frame and not the sheet.
func roof() -> Dictionary:
	if _sheet_image == null or _frames.is_empty():
		return {}
	var key := "%s|%d" % [hive_frame(), jars_shown()]
	if not _roofs.has(key):
		var size := Vector2i(_vec(contract().get("size"), Vector2(1.0, 1.0)))
		var image := Image.create_empty(maxi(size.x, 1), maxi(size.y, 1), false, Image.FORMAT_RGBA8)
		var part := _frame_image(hive_frame())
		if part != null:
			image.blend_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), Vector2i.ZERO)
		_lay_jars_into(image)
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
	var hive_name := hive_frame()
	_level_drawn = window_level()
	if day != null:
		_lay_shades(box, hive_name)
		_draw_tree_shade()
	_draw_tree()
	_stamp(hive_name, box)
	_draw_jars()
	_draw_skirts(box)
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
	_bees.clear()
	for i in COMMUTERS:
		if _inside(i, _clock):
			continue
		var bee := _fly(i, _clock)
		_bees.animate(&"mini_fly", _clock + _roll(i, 4.0), Vector2(bee.x, bee.y), bee.z < 0.0)
	_bees.flush(on)


## Every bee in the air throws a blot on the lawn under it: the ground point under the bee
## moved by `Shade.drop` of its height, in the land's ink (One Sun).
func draw_blots(on: CanvasItem) -> void:
	if stage == Stage.EMPTY:
		return
	var ink := Shade.tint_on(day, Shade.On.LAND)
	if _flying():
		for i in COMMUTERS:
			if _inside(i, _clock):
				continue
			var bee := _fly(i, _clock)
			_blot(on, Vector2(bee.x, bee.y), bee.w, ink)
	if stage == Stage.SWARM:
		var seen := _swarm_seen()
		if seen > 0.0:
			var ground := shrub_box().end.y - ART_SCALE
			for i in SWARM_SPECKS:
				var at := _swarm_bee(i)
				_blot(on, at, ground - at.y, Color(ink, ink.a * seen))
			for i in SCOUTS:
				var scout := _scout(i)
				_blot(on, Vector2(scout.x, scout.y), scout.w, ink)


## One bee's blot in whole pixels, the mockup's: four wide under a row two narrower while the bee
## flies low, three by one once it is high. The land ink laid twice over, or a blot this small
## is lost in the lawn's own dark speckle, which is the land ink's single pass already.
func _blot(on: CanvasItem, at: Vector2, high: float, ink: Color) -> void:
	if high <= 1.0:
		return
	var ground := (at + Vector2(0.0, high) + Shade.drop(day, high)).floor()
	var twice := Color(ink, 1.0 - (1.0 - ink.a) * (1.0 - ink.a))
	if high < BLOT_HIGH:
		on.draw_rect(Rect2(ground + Vector2(-2.0, 0.0), Vector2(4.0, 1.0)), twice)
		on.draw_rect(Rect2(ground + Vector2(-1.0, -1.0), Vector2(2.0, 1.0)), twice)
	else:
		on.draw_rect(Rect2(ground + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), twice)


func _flying() -> bool:
	return _air != null and stage != Stage.EMPTY and stage != Stage.SWARM


func _redraw_all() -> void:
	queue_redraw()
	if _air != null:
		_air.queue_redraw()
	if _blots != null:
		_blots.queue_redraw()


## The hive's shadow off its own frame's pixels. A new outline is a new Cast: `Cast.lay` would
## keep the old silhouette otherwise (it keys on box and ground).
func _lay_shades(box: Rect2, hive_name: StringName) -> void:
	var outline := _outline_of(hive_name)
	if _hive_cast == null or _hive_cast_frame != outline:
		_hive_cast = _new_cast(_hive_cast, &"HiveShade")
		_hive_cast_frame = outline
	# The land's ink (one sun, 2026-10-02): the hive stands on the island's grass.
	var ink := Shade.ink_on(day.ink, Shade.On.LAND)
	_hive_cast.lay(_frame_image(outline), box, day.lean, day.stretch, _ground_hive, ink)
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


## The jars on the cupboard's shelves, one `HoneyPot` shelf jar a slot, the shaded face's a
## step darker.
func _draw_jars() -> void:
	var tint := Shade.wet_tint()
	for k in jars_shown():
		var slot := jar_slot(k)
		if slot.is_empty():
			continue
		HoneyPot.draw(self, &"shelf_shade" if slot["shaded"] else &"shelf", slot["feet"], ART_SCALE, tint)


## The same jars blended into a cut image of the hive (the roof's picture).
func _lay_jars_into(image: Image) -> void:
	var count := jars_shown()
	if count <= 0:
		return
	var pot := HoneyPot.sheet()
	if pot == null:
		return
	var pot_image := pot.get_image()
	if pot_image == null:
		return
	if pot_image.get_format() != Image.FORMAT_RGBA8:
		pot_image.convert(Image.FORMAT_RGBA8)
	for k in count:
		if not (_slots[k] is Array):
			continue
		var slot: Array = _slots[k]
		var pot_name := &"shelf_shade" if (slot.size() > 2 and int(slot[2]) != 0) else &"shelf"
		var cut := Rect2i(HoneyPot.region(pot_name))
		var feet := Vector2i(HoneyPot.feet(pot_name))
		image.blend_rect(pot_image, cut, Vector2i(int(slot[0]), int(slot[1])) - feet)


## Grass along the hive's bottom line, baked once: the ground silhouette is the same in every
## colony frame (no cobweb), so it stands for all of them.
func _draw_skirts(box: Rect2) -> void:
	if _hive_skirt == null:
		var hive := _frame_image(&"hive_colony0")
		if hive == null:
			hive = _frame_image(hive_frame())
		_hive_skirt = Skirt.hem(hive, box, SKIRT_SEED + 1, PackedVector2Array(), SKIRT_BLADES)
	_hive_skirt.over(self)


## The tree: bare until the swarm comes, then its blossom fading in over the bare crown, and in
## the swarm stage the swarm on its bough fading in over the last of it. Not wet-tinted: trees
## do not get wet, by decision.
func _draw_tree() -> void:
	var box := shrub_box()
	if _frames.has(&"tree_bare"):
		draw_texture_rect_region(_sheet, box, _frames[&"tree_bare"])
	var bloom := shrub_grown()
	if bloom > 0.0 and _frames.has(&"tree_bloom"):
		draw_texture_rect_region(_sheet, box, _frames[&"tree_bloom"], Color(1.0, 1.0, 1.0, bloom))
	if stage == Stage.SWARM and _frames.has(&"tree_swarm"):
		var seen := _swarm_seen()
		if seen > 0.0:
			draw_texture_rect_region(_sheet, box, _frames[&"tree_swarm"], Color(1.0, 1.0, 1.0, seen))


## The tree's shadow, and the swarm's, laid down off their silhouettes with `Shade.cast` from
## the trunk's foot: a pixel h up throws its shade h along the sun, so the crown's and the
## hanging swarm's fall apart from the trunk's on the lawn.
func _draw_tree_shade() -> void:
	var box := shrub_box()
	var foot := _vec(contract().get("tree_at"), Vector2(-74.0, -17.0)) * ART_SCALE \
		+ Vector2(0.5, 1.0) * ART_SCALE
	var ink := Shade.tint_on(day, Shade.On.LAND)
	draw_set_transform_matrix(Shade.cast(foot, day.lean, day.stretch))
	var local := Rect2(box.position - foot, box.size)
	if _frames.has(&"tree_sil"):
		draw_texture_rect_region(_sheet, local, _frames[&"tree_sil"], ink)
	if stage == Stage.SWARM and _frames.has(&"swarm_sil"):
		var seen := _swarm_seen()
		if seen > 0.0:
			draw_texture_rect_region(_sheet, local, _frames[&"swarm_sil"], Color(ink, ink.a * seen))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## How far the swarm on its bough has faded in: over the last part of the blossom's coming.
func _swarm_seen() -> float:
	return clampf((shrub_grown() - 0.5) / 0.5, 0.0, 1.0)


## The swarm's loose bees round the hanging mass, and two scouts at the empty hive's door, on
## the hive's own layer (they are round the tree and the board, not up in the air).
func _draw_swarm() -> void:
	var seen := _swarm_seen()
	if seen <= 0.0:
		return
	_bees.clear()
	var tint := Color(1.0, 1.0, 1.0, seen)
	for i in SWARM_SPECKS:
		var at := _swarm_bee(i)
		var ahead := _swarm_bee(i, 0.04)
		_bees.animate(&"mini_fly", _clock + _roll(i, 15.0), at, ahead.x < at.x, tint)
	for i in SCOUTS:
		var scout := _scout(i)
		_bees.animate(&"mini_fly", _clock + _roll(i, 35.0), Vector2(scout.x, scout.y), scout.z < 0.0, tint)
	_bees.flush(self)


## Swarm bee `i` this moment (or `later` seconds on, to read which way it is going): its own
## spot round the mass, wandering, its own loop about it, and now and then a long loop out.
func _swarm_bee(i: int, later: float = 0.0) -> Vector2:
	var t := _clock + later
	var h1 := _roll(i, 11.0)
	var h2 := _roll(i, 12.0)
	var h3 := _roll(i, 13.0)
	var h4 := _roll(i, 14.0)
	var middle := swarm_box().get_center()
	var spot := middle + Vector2(
		(h3 * 2.0 - 1.0) * SWARM_REACH.x + sin(t * (0.4 + 0.3 * h4) + h1 * 7.0) * 4.0,
		(h4 * 2.0 - 1.0) * SWARM_REACH.y + cos(t * (0.35 + 0.3 * h3) + h2 * 5.0) * 3.0
	)
	var a := t * (1.6 + h1 * 1.8) * (1.0 if h2 < 0.5 else -1.0) + h2 * TAU
	var r := 9.0 + 6.0 * h1
	var peel_phase := fposmod(t / (5.0 + 6.0 * h3) + h4, 1.0)
	var peel := sin(clampf((peel_phase - 0.7) / 0.3, 0.0, 1.0) * PI)
	r += peel * SWARM_PEEL * (0.6 + 0.4 * h2)
	return spot + Vector2(cos(a) * r + sin(a * 2.7) * 2.0, sin(a * 1.3) * r * 0.6)


## A scout at the empty hive's door: x, y in the node's space, z the way it faces (+1 right),
## w its height over the lawn.
func _scout(i: int) -> Vector4:
	var home := entrance_point() + Vector2(-6.0 + 14.0 * float(i), -10.0 - 8.0 * float(i))
	var a := _clock * (1.3 + 0.4 * float(i)) + float(i) * 2.0
	var at := home + Vector2(cos(a) * 9.0, sin(a * 1.4) * 5.0)
	var ground := entrance_point().y + entrance_high()
	return Vector4(at.x, at.y, -signf(sin(a)), ground - at.y)


## A harvest ready, or a colony waiting to be settled: bees on the landing board, some resting
## and some hovering just off it. On the hive's own layer, not the air's, because they are on
## the picture: over a walker standing in front of the hive they would be bees on the walker.
func _draw_crowd() -> void:
	_bees.clear()
	var home := entrance_point()
	for i in CROWD:
		var h1 := _roll(i, 21.0)
		var h2 := _roll(i, 22.0)
		var walking := i % 2 == 0
		var sway := sin(_clock * (0.9 + h1) + h2 * 6.0)
		var at := home + Vector2(
			(float(i) - float(CROWD - 1) * 0.5) * 5.0 + sway * 2.0,
			-3.0 if walking else -9.0 - 3.0 * h2 + cos(_clock * (1.3 + h2) + h1 * 5.0) * 1.5
		)
		var left := cos(_clock * (0.9 + h1) + h2 * 6.0) < 0.0
		if walking:
			_bees.add(&"mini_rest0", at, left)
		else:
			_bees.animate(&"mini_fly", _clock + h1, at, left)
	_bees.flush(self)


## The gold mark over the roof, bobbing: the builder's sprite, or a gold disc if the sheet
## has none.
func _draw_ready() -> void:
	var at := ready_point() + Vector2(0.0, roundf(ready_bob()))
	var rect := _rect(contract().get("ready"), Rect2())
	if _frames.has(&"ready"):
		rect = _frames[&"ready"]
	if rect.size.x > 0.0:
		var mid := _vec(contract().get("ready_mid"), (rect.size * 0.5).floor())
		draw_texture_rect_region(_sheet, Rect2((at - (mid + Vector2(0.5, 0.5)) * ART_SCALE).round(), rect.size * ART_SCALE), rect)
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


## Where commuter `i` is at time `t`: x, y in the node's space, z the way it faces (+1 right),
## w its height over the lawn. A leg is a ping-pong between the landing board and one of the
## nearest grown flowers, eased at both ends so a bee lingers at the flower and at the board.
## Its ground track bows off the straight line; its height runs from the board's down to a
## flower head's and climbs `BEE_LIFT` over the middle, so the stream leaves the door upwards
## and comes down onto the bed from above. With no flowers, a spot of lawn (`IDLE_SPOTS`).
func _fly(i: int, t: float) -> Vector4:
	var here := _fly_at(i, t)
	var ahead := _fly_at(i, t + 0.05)
	var facing := 1.0 if ahead.x >= here.x else -1.0
	return Vector4(here.x, here.y, facing, here.z)


## Whether commuter `i` is in the hive at time `t`: the first stretch of every leg from the
## board is the bee gone in through the slot, so the door is a stream in and out rather than a
## knot of bees lingering over the window.
func _inside(i: int, t: float) -> bool:
	return _leg_u(i, t) < INSIDE


## How far along its leg commuter `i` is, 0 at the board to 1 at the flower.
func _leg_u(i: int, t: float) -> float:
	var gap := _leg_end(i) - entrance_point() - Vector2(0.0, entrance_high())
	var leg := maxf(gap.length() / (BEE_SPEED * (0.8 + 0.4 * _roll(i, 1.0))), BEE_LEG_LEAST)
	var p := fposmod(t / leg + _roll(i, 2.0) * 2.0, 2.0)
	return p if p < 1.0 else 2.0 - p


## The ground point a commuter forages at: its flower's foot, or a spot of lawn.
func _leg_end(i: int) -> Vector2:
	if not _spots.is_empty():
		return _spots[i % _spots.size()] + Vector2(0.0, FLOWER_HIGH)
	return IDLE_SPOTS[i % IDLE_SPOTS.size()]


func _fly_at(i: int, t: float) -> Vector3:
	var h1 := _roll(i, 1.0)
	var h3 := _roll(i, 3.0)
	var home := entrance_point()
	var home_high := entrance_high()
	var ground_home := home + Vector2(0.0, home_high)
	var ground_spot := _leg_end(i)
	var gap := ground_spot - ground_home
	var u := _leg_u(i, t)
	var eased := u * u * (3.0 - 2.0 * u)
	var across := Vector2(-gap.y, gap.x).normalized() if gap.length() > 0.01 else Vector2.UP
	var ground := ground_home.lerp(ground_spot, eased) + across * sin(u * PI) * BEE_ARC * (h3 * 2.0 - 1.0)
	var high := lerpf(home_high, FLOWER_HIGH + 1.0, eased) + sin(u * PI) * BEE_LIFT * (0.7 + 0.6 * h1) \
		+ sin(t * 7.0 + h1 * 9.0) * 1.5
	var at := ground - Vector2(0.0, high)
	return Vector3(at.x, at.y, high)


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
