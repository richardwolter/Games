## Headless checks for the lake: how the heap is built, where the angler may stand, what
## a cast catches, the yard's hard cap, and the ferry's run.
##
## Run: Godot --headless --path <project> res://tools/test_lake.tscn --quit-after 5000
##
## The budget is frames, not seconds, and two full ferry runs are most of it. Trimming it
## does not fail a check — it silently stops the log partway, which is why it is generous.
##
## A scene stepped by _physics_process, not a `--script` SceneTree with `await` — the
## await form stalls indefinitely on this Godot build while the identical scene runs
## hundreds of frames in seconds.
##
## Results are appended to tools/last_test.log and flushed per line. The Godot build here
## is the GUI one, whose stdout does not reach a shell, and a GDScript error aborts
## silently — so a run that dies leaves the log as the only record of how far it got.
extends Node

## The drawn wood's colours, for the contrast checks in `_stage_shop_shape`. `Style` has no
## `class_name`, so it is preloaded here as every drawing script preloads it.
const Style := preload("res://scripts/style.gd")
const HudSkin := preload("res://scripts/hud_skin.gd")
const HudButtons := preload("res://scripts/hud_buttons.gd")
## What a fresh lake paid per piece at each yard, and the share of its water in each weight
## tier, before the third batch of rubbish joined (2026-09-21, `probe_fill_economy`). The
## shop is priced on these; `_check_surface` holds the fill to them.
const PAY_PRICED := [42.47, 45.06, 34.51, 38.31]
const TIER_PRICED := [0.351, 0.238, 0.161, 0.089, 0.162]
const DogArt := preload("res://scripts/dog_art.gd")

const LOG_PATH := "res://tools/last_test.log"

## Panels that are meant to swallow a click: they are what is on screen when the lake is
## not being played. The shop boards are a menu, and a menu that let clicks through onto the
## water behind it would cast the net while the player was shopping. Buttons are exempt
## everywhere — the engine's own and the drawn ones (`UiButton`, `CloseButton`).
const CLICK_EATERS := ["Shop", "ShopSkin", "Settings", "Shed", "Room", "GroundTuner"]

## The harness's own save file, so a test run never touches the player's.
const SAVE_PATH := "user://test_lake.save"

## The ferry is wound up for the tests. Its real speed is a few tiles a second, and a
## round trip at that rate is most of the frame budget this harness has.
## Idle frames the ferry stage gives the hull: enough to have set off with a part load if it
## were going to, and enough to set off with a full one. A budget, not a deadline.
##
## Idle, not drawn: `--headless` draws nothing at all, so `Engine.get_frames_drawn()` sits at
## zero for the whole run and a wait on it never ends. `_process` still runs.
const FERRY_LOOKS := 4
const FERRY_WAIT := 240

const TEST_FERRY_SPEED := 60.0

var _main: Node2D
var _grid: LakeGrid
var _boat: Boat
var _angler: Angler
var _net: CastNet
var _yard: Yard

var _stage: int = 0
var _in_stage: int = 0
## Whether the settings board was up before `_stage_settings_shape` put it up to measure it.
var _was_settings_shown: bool = false
## Whether `_stage_binds_shape` rebound something to test the hint, so it can put it back.
## Nothing in `tools/` may leave the player's own `settings.cfg` changed.
var _binds_touched: bool = false
## The player's own overrides while the stage is borrowing the board, and what the board drew
## before anything was rebound.
var _binds_before: Dictionary = {}
var _hint_on_clean: bool = false
var _ran: int = 0
var _failed: int = 0

var _walk_from := Vector2.ZERO
var _pieces_before: int = 0
var _filth_before: float = 1.0
var _sludge_before: float = 0.0
var _gesture_checked: bool = false
## The ferry stage's own little state machine. It cannot count harness frames: this node
## steps in `_physics_process` while `Boat._process` is an idle callback, and several physics
## ticks fall inside one idle frame — so a check pinned to a frame number can run before the
## hull has been asked to do anything at all, which is what "the ferry sets off on its own"
## failing on a boat that then sailed perfectly well turned out to be (2026-09-17). It waits
## on drawn frames and on the boat instead. `_ferry_step` is how far through the stage it is,
## `_ferry_mark` the drawn frame it last waited from.
var _ferry_step: int = 0
var _ferry_mark: int = 0
var _flock: Flock
var _rebuilds_before: int = 0
## The frame `_stage_ending` settled on, so the rest of that stage can be timed from it
## rather than from a frame number that a dog's delivery can push out of reach. -1 until.
var _ending_at: int = -1
## Whether that stage has seen the run end, so the wait for it happens once.
var _ending_done: bool = false


func _ready() -> void:
	if FileAccess.file_exists(LOG_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG_PATH))
	_log("--- test_lake start")
	_main = load("res://scenes/main.tscn").instantiate()
	# A save file of the harness's own, started empty: the tests are about a fresh lake,
	# and they must not read or overwrite whatever the player has been playing.
	_main.set(&"save_path", SAVE_PATH)
	_main.set(&"autoload_save", false)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	add_child(_main)


func _physics_process(_delta: float) -> void:
	_in_stage += 1
	match _stage:
		0:
			if _in_stage >= 2:
				_stage_build()
		1:
			_stage_walk()
		2:
			_stage_cast()
		3:
			_stage_reel()
		4:
			_stage_yard_cap()
		5:
			_stage_net_ring()
		6:
			_stage_draw_batch()
		7:
			_stage_dropoffs()
		8:
			_stage_ferry()
		9:
			_stage_pack()
		10:
			_stage_fleet()
		11:
			_stage_one_gesture()
		12:
			_stage_market()
		13:
			_stage_save()
		14:
			_stage_settings()
		15:
			_stage_ferry_art()
		16:
			_stage_art()
		17:
			_stage_shed()
		18:
			_stage_pigeons()
		19:
			_stage_ending()
		20:
			_stage_sun()
		21:
			_stage_ending_on_load()
		22:
			_stage_patch()
		23:
			_stage_pad()
		24:
			_stage_music()
		25:
			_stage_pointer()
		26:
			_stage_nature()
		27:
			_stage_foam()
		28:
			_stage_new_tracks()
		29:
			_stage_shop_shape()
			_stage_paper()
		30:
			_stage_settings_shape()
		31:
			_stage_binds_shape()
		32:
			_stage_wash()
		33:
			_stage_letter()
		34:
			_stage_front()
		35:
			_stage_led_cast()
		36:
			_stage_first_steps()
		_:
			pass


func _advance() -> void:
	_stage += 1
	_in_stage = 0


## A tile of genuinely deep water off the island's south side, just past the thin ring.
## Not the basin's middle any more — the island stands there.
func _deep_tile() -> int:
	return _grid.index_of(
		int(Iso.CENTRE.x), int(Iso.CENTRE.y + Iso.ISLAND_RADIUS.y + LakeGrid.RING_OUT + 4.0)
	)


## Open water with something in it, within casting distance of wherever the angler is
## standing.
##
## Every tile inside the ring is looked at, not a line of them. It used to walk one ray
## straight out from the island's middle, which worked while the lake started a step off the
## beach: now the rubbish is held clear of the island's drowned sand, and a single ray can
## easily cross nothing but empty shallows before it runs out of cast — so the harness threw
## into open water and proved nothing.
##
## The furthest such tile rather than the nearest, so the haul home is long enough to watch.
func _water_near_angler() -> Vector2:
	var reach := _net.range_tiles - 0.2
	var here := _angler.tile_pos
	var best := Vector2.INF
	var best_span := -1.0
	var fallback := Vector2.INF
	for tx in range(int(here.x - reach) - 1, int(here.x + reach) + 2):
		for ty in range(int(here.y - reach) - 1, int(here.y + reach) + 2):
			var tile := Vector2(float(tx) + 0.5, float(ty) + 0.5)
			var span := here.distance_to(tile)
			if span > reach:
				continue
			if Iso.island_fraction(tile.x, tile.y) <= 1.05:
				continue
			if Iso.shore_fraction(tile.x, tile.y) >= 0.95:
				continue
			var where := Iso.tile_to_world(tile.x, tile.y)
			if fallback == Vector2.INF:
				fallback = where
			var cell := _grid.tile_at(where)
			# Something the net can actually lift, not just something there: a starting net
			# only takes tier 0 off the top, and a stack with heavier junk on top comes home
			# empty however full it is.
			if cell >= 0 and _grid.reachable_slot(cell, 1, _net.power) >= 0 and span > best_span:
				best_span = span
				best = where
	return best if best != Vector2.INF else fallback



## The basin: filled tile by tile, deeper water holding more, sorted light over heavy, no
## bodies anywhere, and an island standing in a hole in it.
func _stage_build() -> void:
	# The bug this harness was first written for: any Control on the default filter
	# swallows the click before _unhandled_input runs. Buttons are exempt.
	var greedy: Array[String] = []
	_find_greedy_controls(_main, greedy)
	_check(greedy.is_empty(), "no Control is eating mouse input", ", ".join(greedy))

	_grid = _main.get_node(^"Grid") as LakeGrid
	_boat = _main.get_node(^"Boat") as Boat
	_angler = _main.get_node(^"Angler") as Angler
	_net = _main.get_node(^"Net") as CastNet
	_yard = _main.get_node(^"Yard") as Yard
	_flock = _main.get_node(^"Flock") as Flock
	# The flock is turned off for the rest of the harness: birds arriving in the middle of
	# a cast would be a lovely bug to chase.
	_flock.spawning = false
	# So is the dog, for the same reason and then some: it takes rubbish out of the water and
	# puts it in the yard on its own clock, which is exactly what half of these checks are
	# counting.
	var dog := _main.get_node_or_null(^"Dog")
	if dog != null:
		dog.set_process(false)

	_check(_grid.piece_count() > 1000, "the basin is filled with rubbish",
		"%d pieces over %d tiles" % [_grid.piece_count(), _grid.tile_count()])

	# No physics at all. A body anywhere means a representation crept back in.
	var found: Array[String] = []
	_collect_bodies(_main, found)
	_check(found.is_empty(), "there are no physics bodies in the scene", ", ".join(found))

	# The shore is real: dry land is empty, the deep water is deep.
	_check(_grid.height_of(_grid.index_of(1, 1)) == 0, "there is no rubbish on dry land", "")
	_check(_grid.height_of(_deep_tile()) > Iso.MAX_SLOTS / 2,
		"the deep water holds a deep stack",
		"%d slots of %d" % [_grid.height_of(_deep_tile()), Iso.MAX_SLOTS])

	# The island is a hole in the lake, not a picture laid over it.
	var island := _grid.index_of(int(Iso.ISLAND_CENTRE.x), int(Iso.ISLAND_CENTRE.y))
	_check(_grid.height_of(island) == 0, "the island holds no rubbish", "")
	_check(not Iso.in_lake(int(Iso.ISLAND_CENTRE.x), int(Iso.ISLAND_CENTRE.y)),
		"the island is not lake", "")

	# Zoom has two ends and stays between them, so the wheel can never lose the lake.
	var cam := _main.get_node(^"Camera") as Camera2D
	_main.call(&"_zoom_by", 1000.0)
	var near: float = _main.call(&"_near_zoom")
	_check(is_equal_approx(cam.zoom.x, near) and near <= Lake.MAX_ZOOM + 0.001,
		"zooming in stops at the near limit", "%.3f, near %.3f" % [cam.zoom.x, near])
	# Every zoom the wheel can land on is a whole number of screen pixels to a pixel of art,
	# or the lake's pixels shimmer as the camera moves.
	# Only where a whole level fits under the limit at all: a headless run's dummy display
	# reports a stretch near nothing, and there the zoom is held at MAX_ZOOM instead.
	var stretch: float = _main.call(&"_stretch")
	var per_art := cam.zoom.x * Lake.ART_PIXEL * stretch
	if Lake.MAX_ZOOM * Lake.ART_PIXEL * stretch >= 1.0:
		_check(absf(per_art - roundf(per_art)) < 0.001, "the near zoom is a whole pixel level",
			"%.3f screen px per art px" % per_art)
	# The far end is worked out from the window rather than written down, so it is asked of
	# the game and then checked against the basin, which is what the limit is really about:
	# the whole lake on screen (2026-09-13 — it was held in past that by `ZOOM_OUT_PULL`
	# for a while, and Richard asked for the lake back), and the wheel stopping there.
	_main.call(&"_zoom_by", 0.0001)
	var fit: float = _main.call(&"_fit_zoom")
	var far: float = _main.call(&"_far_zoom")
	_check(is_equal_approx(cam.zoom.x, far), "zooming out stops at the far limit",
		"%.3f, far %.3f (fit %.3f)" % [cam.zoom.x, far, fit])
	# The far level is at or out past the fitted zoom, except on a window too small for any
	# level to fit, where it is level one — so "the whole lake" is scaled by how far level
	# one overshoots.
	var span := Iso.basin_extent() * cam.zoom.x
	var view := _main.get_viewport_rect().size
	var shown := minf(view.x / span.x, view.y / span.y)
	var wanted := minf(1.0, fit / cam.zoom.x)
	_check(shown >= wanted - 0.01,
		"and the whole lake is on screen there",
		"%.2f of it, wanted %.2f (lake %.0fx%.0f in %.0fx%.0f)" % [
			shown, wanted, span.x, span.y, view.x, view.y
		])
	# The stops (2026-09-14): whole pixel levels, plus one half level just in from the far end
	# where the levels are a third apart or more. Asked of the rule at a 1080p stretch (1.5)
	# and a 1440p one (2.0), since a headless run's own stretch has a single stop.
	var at_1080: Array[float] = _main.call(&"_zoom_stops", 1.5)
	var halves := 0
	for stop in at_1080:
		var px := stop * Lake.ART_PIXEL * 1.5
		if absf(px - roundf(px)) > 0.001:
			halves += 1
	_check(at_1080.size() == 5 and halves == 1 and absf(at_1080[1] - 0.5) < 0.001,
		"1080p has five zoom stops, one of them the half level at 0.5",
		", ".join(PackedStringArray(at_1080.map(func(z: float) -> String: return "%.3f" % z))))
	var at_1440: Array[float] = _main.call(&"_zoom_stops", 2.0)
	var whole_1440 := true
	for stop in at_1440:
		var px := stop * Lake.ART_PIXEL * 2.0
		whole_1440 = whole_1440 and absf(px - roundf(px)) < 0.001
	_check(whole_1440, "and 1440p, already quarters apart, gets no half level",
		", ".join(PackedStringArray(at_1440.map(func(z: float) -> String: return "%.3f" % z))))
	# A wheel zoom leaves the view on the spot it zoomed about, rather than the follow easing
	# it back onto the angler (2026-09-14). Checked through the hold `_zoom_by` ends on.
	var spot := _angler.position + Vector2(300.0, 150.0)
	_main.call(&"_keep_view_at", spot)
	for i in 180:
		_main._process(1.0 / 60.0)
	_check(cam.position.distance_to(spot) < 1.0,
		"a wheel zoom keeps the view on the spot it zoomed about",
		"%.0f px off after 3 s" % cam.position.distance_to(spot))
	_main.set(&"_pan", Vector2.ZERO)
	# A drag past the edge of the ground does not wind up. The view is clamped to the
	# ground, and the pan it is dragged by has to be clamped with it, or dragging back does
	# nothing until the invisible surplus has been unwound — which at the far end of the
	# zoom, where the edge is a hand's width away, read as the sides sticking (2026-09-13).
	# Driven by hand through _process: a drag far past the edge, then a hundred pixels back.
	_main.set(&"_panning", true)
	_main.set(&"_pan", Vector2(50000.0, 0.0))
	_main._process(1.0 / 60.0)
	var at_edge: float = cam.position.x
	var pan: Vector2 = _main.get(&"_pan")
	_main.set(&"_pan", pan - Vector2(100.0, 0.0))
	_main._process(1.0 / 60.0)
	_check(absf(cam.position.x - (at_edge - 100.0)) < 1.0,
		"a drag back from past the edge moves the view at once",
		"at the edge %.0f, after 100 px back %.0f" % [at_edge, cam.position.x])
	_main.set(&"_panning", false)
	_main.set(&"_pan", Vector2.ZERO)
	_check_free_view(cam)
	cam.zoom = Vector2(0.62, 0.62)

	# The shed is a place you stand at, not a button on the screen.
	_check(not bool(_main.get(&"_menu_open")), "the shop starts closed", "")
	_check(bool(_main.call(&"_at_shed")), "the angler starts at the shed", "")
	_main.call(&"_set_menu", true)
	_check(bool(_main.get(&"_menu_open")) and not _angler.can_walk,
		"opening the shop stops the angler walking", "")
	_main.call(&"_set_menu", false)

	# The ferry is there from the first minute — catching does not pay, so a player
	# without one could never earn their way to it — but it starts slow and small.
	_check(_boat.visible, "the ferry is there from the start", "")
	_check(
		is_equal_approx(_boat.speed, float(_main.call(&"boat_speed")))
			and _boat.capacity == int(_main.call(&"boat_cargo")),
		"the starting ferry is the unupgraded one",
		"%.1f tiles/s, carries %d" % [_boat.speed, _boat.capacity])

	# The island's coast wave. It is the one place the drawn shore and Iso's are allowed to
	# disagree, and both bounds are what keep that safe:
	#   - never negative, or the water would pull back off sand Iso calls wet and the angler
	#     would be shown standing in the lake
	#   - never past the island's beach, or a crest would run onto the lawn and the shed
	_check(Lake.COAST_WAVE >= 0.0, "the coast wave only ever laps up the beach",
		"%.2f tiles" % Lake.COAST_WAVE)
	_check(Lake.COAST_WAVE < Ground.BEACH_IN, "and never reaches the lawn",
		"%.2f tiles of a %.1f-tile beach" % [Lake.COAST_WAVE, Ground.BEACH_IN])
	# Whole waves per lap, or the ring seams where atan() wraps from pi to minus pi.
	_check(is_equal_approx(Lake.COAST_WAVES, roundf(Lake.COAST_WAVES)) and Lake.COAST_WAVES >= 1.0,
		"and closes on itself round the island",
		"%.1f waves a lap" % Lake.COAST_WAVES)

	# The bank's edge is carved by the shader's discard, so the polygon has to reach past the
	# wave's crest all the way round or the rim clips it flat. Walked rather than worked out:
	# the rim adds its grow to the wobbled radius while the discard folds the lap in before the
	# wobble, and the gap between those two conventions is exactly what this is guarding.
	var bank_mean := (Iso.RADIUS.x + Iso.RADIUS.y) * 0.5 + Lake.SHORE_LAP
	var crest := 1.0 + Lake.COAST_WAVE / bank_mean
	var lapped := Iso.RADIUS + Vector2(Lake.SHORE_LAP, Lake.SHORE_LAP)
	var rim := Iso.shore_outline(Lake.WATER_RIM)
	var clipped := 0
	for i in 240:
		var angle := TAU * float(i) / 240.0
		# The same wobble shore_fraction uses, and it has to stay the same.
		var wobble := 1.0 + 0.09 * sin(angle * 3.0) + 0.05 * sin(angle * 5.0 + 1.3)
		var reach := wobble * crest
		var tile := Iso.CENTRE + Vector2(cos(angle) * lapped.x, sin(angle) * lapped.y) * reach
		if not Geometry2D.is_point_in_polygon(Iso.tile_to_world(tile.x, tile.y), rim):
			clipped += 1
	_check(clipped == 0, "the water polygon reaches past the wave's crest all the way round",
		"%d of 240 bearings fall outside the rim" % clipped)

	_check_surface()

	# Held at the dock for the casting and yard-cap stages, which need the yard to stay
	# where they put it. Switched back on in _stage_ferry, which is what tests the toggle.
	_main.call(&"_set_auto_ferry", false)
	_check(not _boat.auto_ferry, "the ferry can be told to stay put", "")
	_advance()


## What the fresh lake is showing, which is the first thing anybody sees of the game.
##
## The rules, not the numbers: `LakeGrid.SURFACE_QUOTA`, `SURFACE_APART`, `SURFACE_BAIT` and
## the two repeat weights are all by-eye knobs and are meant to move. What must hold however
## they are set is that light things float, that nothing near the island is unliftable, that
## no one kind covers the water, and that leaning the surface towards the colourful materials
## has not quietly moved what the yards are paid for.
func _check_surface() -> void:
	var span: Vector2 = _grid.get(&"_lightness_span")
	_check(span.x < span.y,
		"the depth band runs heavy at the floor and light at the surface",
		"floor end %.1f, surface end %.1f" % [span.x, span.y])

	var shown := {}
	var top_kind := [0, 0, 0, 0]
	var all_kind := [0, 0, 0, 0]
	var tiles := 0
	var pieces := 0
	var top_light := 0.0
	var floor_light := 0.0
	var deep := 0
	var ring_walls := 0
	var landmarks := 0
	var ring_tiles := 0
	var ring_deep := 0
	var ring_heavy := 0
	var ring_pale := 0
	var at: Array[Vector2i] = []
	var tops := PackedInt32Array()
	for index in _grid.stacks.size():
		var stack := _grid.stacks[index]
		for piece in stack:
			all_kind[_grid.defs[piece].material] += 1
			pieces += 1
		if stack.is_empty():
			continue
		var def := _grid.defs[stack[stack.size() - 1]]
		# The one-off finds are planted on top of a tile after the fill and are not part of
		# it: one pet bed afloat by the island is the design, not a repeat.
		if def.keepsake:
			continue
		tiles += 1
		shown[stack[stack.size() - 1]] = int(shown.get(stack[stack.size() - 1], 0)) + 1
		top_kind[def.material] += 1
		at.append(Vector2i(_grid.tile_of(index)))
		tops.append(stack[stack.size() - 1])
		if stack.size() >= 4:
			deep += 1
			top_light += def.lightness
			floor_light += _grid.defs[stack[0]].lightness
		var out := Iso.past_shelf(Vector2(_grid.tile_of(index)))
		if out < LakeGrid.OPEN_RING:
			if def.tier > 0:
				ring_walls += 1
		elif def.tier > 0 and def.lightness < 1.7:
			landmarks += 1
		if out < LakeGrid.RING_OUT:
			ring_tiles += 1
			# The finds are planted on top of the fill and are not the fill's.
			var filled := 0
			for piece in stack:
				if _grid.defs[piece].keepsake:
					continue
				filled += 1
				if _grid.defs[piece].tier > LakeGrid.RING_TIER:
					ring_heavy += 1
			if filled > LakeGrid.RING_SLOTS.y:
				ring_deep += 1
			if _grid.water_state(index) != LakeGrid.FILTH_STATES:
				ring_pale += 1

	# The band, as it actually comes out rather than as the span says it should: over the
	# deep stacks, what floats is lighter than what is lying on the floor under it.
	#
	# A trend, and a slight one — about 0.16 of lightness between the two ends. The span is
	# stretched to 0.6 by one def (`wood_box2`) and the next heaviest thing in the lake is at
	# 1.4, so the band around the floor's target lands where almost nothing lives and most
	# floor slots fall through to a uniform roll over their material. The surface end is
	# crowded and works; the floor end barely bites. That was as true before the band was put
	# the right way up, and it is the fill's business rather than the surface's, so the bar
	# here is the direction and not a size.
	_check(deep > 100 and top_light / float(deep) > floor_light / float(deep) + 0.1,
		"and the lake bears that out: what floats is lighter than what is under it",
		"top %.2f, floor %.2f over %d deep stacks"
		% [top_light / maxf(float(deep), 1.0), floor_light / maxf(float(deep), 1.0), deep])

	# The opening ring: the first casts of a new game can lift everything they can see.
	_check(ring_walls == 0, "nothing in the opening ring is too heavy for a level-0 net",
		"%d tiles show one" % ring_walls)
	# The thin ring (2026-09-22): the first ten minutes clear whole spots. Every stack inside
	# RING_OUT is RING_SLOTS deep at most and holds nothing over RING_TIER, and what the
	# ring gave up was dealt back over the rest of the lake, so the count the shop was
	# priced on is what the lake still holds.
	_check(ring_tiles > 200, "the ring round the island holds a few hundred tiles",
		"%d" % ring_tiles)
	_check(ring_deep == 0, "no stack inside the ring is deeper than the ring allows",
		"%d tiles" % ring_deep)
	_check(ring_heavy == 0, "nothing inside the ring is over the ring's tier",
		"%d pieces" % ring_heavy)
	_check(ring_pale == 0, "a fresh ring reads as dirty as the rest of the lake",
		"%d tiles lighter" % ring_pale)
	var by_depth := 0
	for ty in Iso.ROWS:
		for tx in Iso.COLS:
			if Iso.floats_here(tx, ty):
				by_depth += maxi(int(Iso.depth_at(tx, ty) * float(Iso.MAX_SLOTS)), 1)
	var planned := 0
	for index in _grid.stacks.size():
		planned += _grid.room_of(index)
	_check(planned == by_depth, "the ring's slots were dealt back over the rest of the lake",
		"%d planned against %d by depth" % [planned, by_depth])
	# The nine-deep tiles were all by the island and are the ring's now; past it the depth
	# tops out lower and the dealt-back slots put it back near the old ceiling.
	_check(_grid.deepest() >= Iso.MAX_SLOTS - 2 and _grid.deepest() <= Iso.MAX_SLOTS + 2,
		"and the deepest tile past the ring is near the depth's own ceiling",
		"%d of %d" % [_grid.deepest(), Iso.MAX_SLOTS])
	# And past it, the bait still puts the occasional heavy thing where it can be seen.
	_check(landmarks > 20, "past the ring, heavy pieces still break the surface as landmarks",
		"%d of them" % landmarks)

	# No kind covers the lake. Before the band was put the right way up, one tier-4 crate was
	# the top of every deep stack and 21% of everything shown.
	var most := 0
	var commonest := &""
	for kind: int in shown:
		if int(shown[kind]) > most:
			most = int(shown[kind])
			commonest = _grid.defs[kind].piece
	var share := float(most) / maxf(float(tiles), 1.0)
	_check(shown.size() >= 30, "most of the catalogue is showing somewhere on the surface",
		"%d kinds of %d" % [shown.size(), _grid.defs.size()])
	_check(share < 0.08, "and no one kind is more than a fourteenth of it",
		"%s on %.1f%%" % [commonest, 100.0 * share])

	# The bargain with the yards: what is *seen* leans towards the colourful materials, what
	# is *in the water* — and so what each yard is paid over a run — is where the quota put
	# it. The lean is checked as a direction only; how far it gets is a knob, and it is
	# capped by how often a material is in a stack at all (see `_surface_material`).
	for m in 4:
		var stocked := float(all_kind[m]) / maxf(float(pieces), 1.0)
		_check(absf(stocked - float(LakeGrid.MATERIAL_QUOTA[m])) < 0.02,
			"the water still holds the %s the yards were priced on"
			% TrashDef.KIND_NAMES[m].to_lower(),
			"%.1f%% against the quota's %.0f%%"
			% [100.0 * stocked, 100.0 * float(LakeGrid.MATERIAL_QUOTA[m])])
	# The money the shop was priced on (2026-09-21): when the third batch of rubbish joined,
	# each new kind's tier and pollution were picked so a yard's mean pay per piece and the
	# water's share of each weight tier stayed where they were. Measured off a fresh lake by
	# `tools/probe_fill_economy.tscn` before the batch landed. A new kind has to fit inside
	# these, or the frozen prices are being paid out of a different lake.
	var pay_by := [0.0, 0.0, 0.0, 0.0]
	var tier_by := [0, 0, 0, 0, 0]
	var counted := 0
	for stack in _grid.stacks:
		for i in stack:
			var def := _grid.defs[i]
			if def.keepsake:
				continue
			pay_by[int(def.material)] += float(_main.call(&"piece_pay", i, int(def.material)))
			tier_by[def.tier] += 1
			counted += 1
	for m in 4:
		var mean := float(pay_by[m]) / maxf(float(all_kind[m]), 1.0)
		_check(absf(mean / float(PAY_PRICED[m]) - 1.0) < 0.03,
			"a %s piece pays what the shop was priced on" % TrashDef.KIND_NAMES[m].to_lower(),
			"%.2f against %.2f" % [mean, float(PAY_PRICED[m])])
	for t in 5:
		var tier_share := float(tier_by[t]) / maxf(float(counted), 1.0)
		_check(absf(tier_share - float(TIER_PRICED[t])) < 0.02,
			"tier %d holds the share of the water it did" % t,
			"%.1f%% against %.1f%%" % [100.0 * tier_share, 100.0 * float(TIER_PRICED[t])])

	var seen_metal := float(top_kind[TrashDef.Kind.METAL]) / maxf(float(tiles), 1.0)
	var seen_rubber := float(top_kind[TrashDef.Kind.RUBBER]) / maxf(float(tiles), 1.0)
	_check(seen_metal < float(all_kind[TrashDef.Kind.METAL]) / float(pieces)
		and seen_rubber > float(all_kind[TrashDef.Kind.RUBBER]) / float(pieces),
		"but the surface leans off the greys towards the colour",
		"metal %.1f%% of the surface against %.1f%% of the water, rubber %.1f%% against %.1f%%"
		% [100.0 * seen_metal, 100.0 * float(all_kind[TrashDef.Kind.METAL]) / float(pieces),
		100.0 * seen_rubber, 100.0 * float(all_kind[TrashDef.Kind.RUBBER]) / float(pieces)])

	# The anti-repeat, measured as the rule really is: by family of look-alikes rather than by
	# kind (four cans are one can), and against each kind's own room, which is wider for a big
	# piece. It is a preference and cannot be a law — the pick comes out of the stack the tile
	# already holds, and a stack with nothing else to offer repeats. It is also asking for
	# something arithmetically impossible in places: the can family is on an eighth of the
	# surface and wants three tiles of room, which caps it nearer a fourteenth. So what is
	# guarded is what the eye would actually catch — no family covering the lake, and two of
	# a kind rarely side by side — and not a share that the rule was never going to reach.
	var where := {}
	for i in at.size():
		where[at[i]] = _grid.family_of(tops[i])
	var clan := {}
	for i in at.size():
		var head := _grid.family_of(tops[i])
		clan[head] = int(clan.get(head, 0)) + 1
	var widest := 0
	var widest_name := &""
	for head: int in clan:
		if int(clan[head]) > widest:
			widest = int(clan[head])
			widest_name = _grid.defs[head].piece
	_check(float(widest) / maxf(float(tiles), 1.0) < 0.18,
		"no family of look-alikes covers the surface",
		"%s and its like on %.1f%% of it"
		% [widest_name, 100.0 * float(widest) / maxf(float(tiles), 1.0)])

	var touching := 0
	for i in at.size():
		var head := _grid.family_of(tops[i])
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var other: Vector2i = at[i] + Vector2i(dx, dy)
				if where.has(other) and int(where[other]) == head:
					touching += 1
					dx = 2
					dy = 2
					break
	_check(float(touching) / maxf(float(tiles), 1.0) < 0.15,
		"and two of a kind are rarely side by side",
		"%.1f%% of tiles have one next door"
		% [100.0 * float(touching) / maxf(float(tiles), 1.0)])


## How far the angler has to have walked before the walking checks are made, in tiles. Past
## the shed's own range, so "they are no longer at the shed" is a fact about the walk rather
## than about how many frames the machine managed while the key was down.
const WALK_CLEAR := 4.0


## Walking: the keys move the angler, and the island's edge stops them.
func _stage_walk() -> void:
	if _in_stage == 1:
		# Both bindings on every walk action, checked against the project's own input map
		# rather than by pressing keys — the map is the thing that can silently lose one.
		for pair: Array in [
			[&"walk_left", KEY_LEFT, KEY_A], [&"walk_right", KEY_RIGHT, KEY_D],
			[&"walk_up", KEY_UP, KEY_W], [&"walk_down", KEY_DOWN, KEY_S]
		]:
			var action: StringName = pair[0]
			var bound: Array[int] = []
			for event: InputEvent in InputMap.action_get_events(action):
				var key := event as InputEventKey
				if key != null:
					bound.append(key.physical_keycode)
			_check(
				bound.has(pair[1] as int) and bound.has(pair[2] as int),
				"%s answers to both the arrow and the letter" % action,
				"%d bindings" % bound.size()
			)

		_walk_from = _angler.tile_pos
		# Across, rather than down or up. The crate is parked south-east of the middle —
		# straight down the screen from where the angler starts — and the hut is straight up
		# from it, so either of those walks wedges them against something a tile out, and
		# every check after that is really a check on the obstacle. Across is clear water.
		Input.action_press(&"walk_left")
		return
	# Held until the angler has actually got somewhere, not for a fixed count of frames. The
	# figure walks on wall-clock time and the harness counts frames, so how far ninety of them
	# carried it depended on how fast the machine was running that day: the same code walked
	# 1.3 tiles one run and 1.7 the next, and the check that it is clear of the shed sat right
	# between the two.
	var gone := _angler.tile_pos.distance_to(_walk_from)
	if gone < WALK_CLEAR and _in_stage < 600:
		return
	Input.action_release(&"walk_left")
	_check(_angler.tile_pos.distance_to(_walk_from) > 0.5, "the keys walk the angler",
		"%.2f tiles from %s" % [_angler.tile_pos.distance_to(_walk_from), str(_walk_from)])
	# The water's drawn edge plus the wade past it the walking rule allows — the last step off
	# the beach is into the shallows on purpose (Angler.WALK_LIMIT), and the drawing sinks the
	# boots into the water when it is taken. Anything beyond that is a swim.
	_check(Iso.past_water(_angler.tile_pos) <= Angler.WALK_LIMIT,
		"walking never leaves the island",
		"%.1f px past the water's edge" % Iso.past_water(_angler.tile_pos))

	# What a footstep sounds like is decided by where the boots are (2026-09-15). Asked of the
	# angler rather than heard: a step in the shallows is the wading sound, one on the lawn is
	# grass, and the beach between them is sand.
	var stood := _angler.tile_pos
	var surfaces := {}
	for out: float in [-1.5, 1.3, 3.4]:
		# Straight out from the island's middle, so the three spots are lawn, beach and water.
		var towards := (stood - Iso.ISLAND_CENTRE).normalized()
		_angler.tile_pos = stood + towards * out
		surfaces[_angler.call(&"step_surface")] = true
	_angler.tile_pos = stood
	_check(surfaces.has(&"grass") and surfaces.has(&"water"),
		"a footstep knows lawn from shallows", ", ".join(PackedStringArray(surfaces.keys())))
	_check(not bool(_main.call(&"_at_shed")), "walking off takes them away from the shed", "")
	_advance()


## Casting: refused beyond range, and it flies and settles inside it.
## Put the angler on the beach, facing open water.
##
## The island is sixteen tiles across now, and the first net reaches three and a half: from
## where a run starts, in the middle by the shed, there is no water within a cast of anybody.
## Walking to the shore is what a player does before their first throw, and this is the
## harness doing the same rather than pretending the lake comes to the island.
func _stand_on_the_shore() -> void:
	var best := _angler.tile_pos
	var best_out := -1.0
	for i in 16:
		var angle := TAU * float(i) / 16.0
		var dir := Vector2(cos(angle), sin(angle))
		var walked := 0.0
		var last := Vector2.INF
		while walked < Iso.ISLAND_RADIUS.x + 4.0:
			walked += 0.25
			var at := Iso.ISLAND_CENTRE + dir * walked
			if bool(_angler.call(&"_can_stand", at)):
				last = at
		if last != Vector2.INF and last.distance_to(Iso.ISLAND_CENTRE) > best_out:
			best_out = last.distance_to(Iso.ISLAND_CENTRE)
			best = last
	_angler.tile_pos = best
	_angler.call(&"_place")


func _stage_cast() -> void:
	if _in_stage == 1:
		_stand_on_the_shore()
		# Out past the far bank, which is well beyond any starting cast.
		var far := Iso.tile_to_world(Iso.CENTRE.x, Iso.CENTRE.y + Iso.RADIUS.y * 0.9)
		_check(not _net.can_cast_to(far), "a cast beyond range is refused", "")
		_main.call(&"_cast_at", far)
		_check(_net.state == CastNet.State.IDLE, "the refused cast left the net stowed", "")

		# On the island is not water, however close it is.
		_check(not _net.can_cast_to(Iso.tile_to_world(Iso.ISLAND_CENTRE.x, Iso.ISLAND_CENTRE.y)),
			"the island is not somewhere to cast", "")

		_pieces_before = _grid.piece_count()
		_filth_before = float(_main.get(&"pollution"))
		var near := _water_near_angler()
		_check(_net.can_cast_to(near), "water inside the ring can be cast at", "")
		_main.call(&"_cast_at", near)
		_check(_net.state == CastNet.State.FLYING, "the cast is in the air", "")
		return
	if _net.state == CastNet.State.FLYING and _in_stage < 200:
		return
	# Nothing is held down any more: a net that has finished its flight is already on its
	# way back with whatever it landed on.
	_check(_net.state == CastNet.State.REELING, "the net reels itself in from where it lands",
		"after %d frames" % _in_stage)
	var patches: Array = _main.get(&"_patches")
	_check(not patches.is_empty(), "the landing opened a clean patch at the mouth",
		"%d patches" % patches.size())
	if not patches.is_empty():
		var patch: Dictionary = patches[0]
		_check(patch["at"] is Vector2 and float(patch["radius"]) >= _net.mouth_extent(),
			"at least the mouth wide", "%.1f against %.1f" % [float(patch["radius"]), _net.mouth_extent()])
	_advance()


## Reeling: it comes home on its own; what it drags in fills the yard and cleans the lake.
## Pausing it — which is what a panel opened over the water does — stops it where it is.
func _stage_reel() -> void:
	if _in_stage == 1:
		_net.set_pulling(false)
		_check(_net.state == CastNet.State.SETTLED,
			"pausing the net leaves it where it is", "")
		_net.set_pulling(true)
		_check(_net.state == CastNet.State.REELING, "letting it go again reels it in", "")
		return
	if _net.state == CastNet.State.REELING and _in_stage < 400:
		return
	_net.set_pulling(false)
	_check(_net.state == CastNet.State.IDLE, "the net comes home",
		"after %d frames" % _in_stage)
	# The catch is thrown to the yard rather than teleported into it, so the pile is a
	# second behind the net. Waiting for the throw to land is part of the check.
	if _yard.held.is_empty() and _in_stage < 600:
		return
	_check(_yard.held.size() > 0, "the catch landed in the yard",
		"%d pieces" % _yard.held.size())
	_check(_grid.piece_count() < _pieces_before, "the catch left the lake",
		"%d -> %d pieces" % [_pieces_before, _grid.piece_count()])
	_check(float(_main.get(&"pollution")) < _filth_before, "landing a catch moved the meter",
		"%.5f -> %.5f" % [_filth_before, float(_main.get(&"pollution"))])
	# Catching cleans; only selling pays. That split is the whole reason the yard exists.
	_check(is_zero_approx(float(_main.get(&"sludge"))), "a catch is not money yet", "")
	_advance()


## The yard does not fill up any more.
##
## It used to be a hard cap that stopped the net, and this stage used to prove that. The
## cap was taken out on purpose — it made the player stand on the bank watching a boat —
## so what is checked here now is the opposite: a deep pile changes nothing about whether
## the net will go out.
func _stage_yard_cap() -> void:
	var piled := _yard.held.size()
	for i in 200:
		_yard.put(0)
	_check(_yard.held.size() == piled + 200, "the yard takes everything it is given",
		"%d pieces" % _yard.held.size())

	var where := _water_near_angler()
	_check(_net.can_cast_to(where), "that water is still in range", "")
	_main.call(&"_cast_at", where)
	_check(_net.state == CastNet.State.FLYING, "a deep pile does not stop the net", "")
	_net.state = CastNet.State.IDLE
	_net.catch.resize(0)
	_yard.held.resize(piled)
	_advance()


## The ring tells the truth: a piece is caught when its drawing touches the mouth, wherever
## its tile is, and not when it does not; the haul catches at the size the net is drawn; and
## the catch starts the frame the net lands.
func _stage_net_ring() -> void:
	var was_radius := _net.radius
	var was_power := _net.power
	var was_hold := _net.hold
	_net.state = CastNet.State.IDLE
	_net.catch.resize(0)
	_net.radius = 0.6
	_net.power = 99
	_net.hold = 99
	var mouth := _net.open_extent()

	# The widest top piece on the lake, so its drawing stands well off its own tile.
	var index := -1
	var widest := 0.0
	for cell in _grid.tile_count():
		if _grid.reachable_slot(cell, 1, 99) < 0:
			continue
		var wide := _grid.footprint(cell).x
		if wide > widest:
			widest = wide
			index = cell
	_check(index >= 0, "there is a piece to aim past", "")
	if index >= 0:
		var centre := _grid.surface_pos(index)
		var half := _grid.footprint(index)
		var grazing := centre + Vector2(mouth + half.x * 0.8, 0.0)
		var reach: Array = _net.call(&"_reach", grazing, mouth, _net.power)
		_check(reach.has(index) and centre.distance_to(grazing) > mouth,
			"a ring grazing a piece's drawing catches it, middle outside the ring or not",
			"mouth %.1f px, piece half %.1f px" % [mouth, half.x])
		var clear := centre + Vector2(mouth + half.x * 1.3, 0.0)
		reach = _net.call(&"_reach", clear, mouth, _net.power)
		_check(not reach.has(index), "a ring short of the drawing does not", "")

	# Brought home, the catch shrinks with the drawing.
	_net.near = 1.0
	_check(is_equal_approx(_net.mouth_extent() * 2.0, float(_net.call(&"_draw_span"))),
		"the hauled net catches at the size it is drawn", "")
	_net.near = 0.0

	var where := _water_near_angler()
	_check(_net.cast_to(where), "a cast at something liftable is thrown", "")
	_net.tile_pos = _net.target
	_net.call(&"_process", 0.0)
	_check(_net.state == CastNet.State.REELING and not _net.catch.is_empty(),
		"the net catches the moment it lands", "%d pieces" % _net.catch.size())

	# The bag shows what it is carrying: more of it as the load grows, and never more pieces
	# than are actually aboard.
	var few: int = _net.call(&"_shown_count", mouth)
	var many_catch := _net.catch.duplicate()
	# Far more than any mouth has room for, so the cap is what is being measured rather than
	# how much happened to be aboard.
	for i in 400:
		many_catch.append(_net.catch[0])
	_net.catch = many_catch
	var many: int = _net.call(&"_shown_count", mouth)
	_check(many > few and many < _net.catch.size(),
		"a fuller net shows more of its catch, and never more than it holds",
		"%d of %d shown, was %d" % [many, _net.catch.size(), few])
	# A wider mouth has room for more of it.
	_check(int(_net.call(&"_shown_count", mouth * 2.0)) > many,
		"and a wider net shows more still",
		"%d at twice the width" % int(_net.call(&"_shown_count", mouth * 2.0)))
	_net.catch.resize(0)

	# What it cannot lift is pushed out of the way instead of passed through.
	var heavy := -1
	for cell in _grid.tile_count():
		if _grid.top_slot(cell) >= 0 and _grid.reachable_slot(cell, 1, 0) < 0:
			heavy = cell
			break
	_check(heavy >= 0, "there is a piece too heavy for a starting net", "")
	if heavy >= 0:
		_net.power = 0
		_net.state = CastNet.State.REELING
		_net.tile_pos = Iso.world_to_tile(_grid.surface_pos(heavy))
		_grid.shove[heavy] = Vector2.ZERO
		for i in 20:
			_net.call(&"_shove_aside", 0.05)
		_check(_grid.shove[heavy].length() > 0.5,
			"a piece the net cannot lift is shoved aside",
			"%.1f px" % _grid.shove[heavy].length())
		_check(_grid.top_slot(heavy) >= 0, "and is still in the lake", "")
		_grid.shove[heavy] = Vector2.ZERO

	# The lean falls back out once nothing is pulling.
	_net.state = CastNet.State.REELING
	for i in 20:
		_net.call(&"_lean_into_pull", 0.05)
	var bent: float = _net.get(&"_lean")
	_net.state = CastNet.State.IDLE
	for i in 40:
		_net.call(&"_lean_into_pull", 0.05)
	_check(bent > 0.1 and float(_net.get(&"_lean")) < 0.02,
		"the net leans into the haul and settles when it ends",
		"%.2f while hauling, %.2f after" % [bent, float(_net.get(&"_lean"))])

	# The rope is tied to the drawn rim: when the net bends, the knot moves with it.
	_net.state = CastNet.State.REELING
	_net.catch.append(0)
	_net.tile_pos = _angler.tile_pos + Vector2(3.0, 3.0)
	var at := _net.world_pos()
	_net.set(&"_lean", 0.0)
	var flat: Vector2 = _net.call(&"_line_end", at)
	_net.set(&"_lean", 1.0)
	var bent_end: Vector2 = _net.call(&"_line_end", at)
	_net.set(&"_lean", 0.0)
	var span := float(_net.call(&"_draw_span"))
	_check(not flat.is_equal_approx(bent_end) and flat.distance_to(at) <= span,
		"the rope ends at the horn over the crown as the warp draws it, and moves when the net bends",
		"flat at %.1f px from the mouth, bent end moved %.1f px" % [
			flat.distance_to(at), flat.distance_to(bent_end)])

	# The bridle stays on the crown. Every little rope is short against the net it is tied to
	# and lands nowhere near the rim — a line from the apex to the edge is a line drawn across
	# the whole picture, which is what this is here to catch.
	var near := PackedVector2Array()
	var far := PackedVector2Array()
	_net.call(&"_bridle_points", at, flat, near, far)
	var ends := near + far
	var longest := 0.0
	var reach := 0.0
	for i in range(0, ends.size(), 2):
		longest = maxf(longest, ends[i].distance_to(ends[i + 1]))
		reach = maxf(reach, at.distance_to(ends[i + 1]))
	_check(ends.size() == CastNet.BRIDLES * 2 and far.size() > 0 and near.size() > 0,
		"the bridle is drawn on both sides of the crown",
		"%d near, %d far" % [near.size() / 2, far.size() / 2])
	_check(longest > 0.5 and longest < span * 0.4 and reach < span * 0.5,
		"and every little rope is short, staying on the crown rather than reaching the rim",
		"longest %.1f px, furthest end %.1f px from the middle, net %.1f px across" % [
			longest, reach, span])
	_net.catch.resize(0)

	# And the rope itself stays a rope for a whole cast: every point near the line between
	# the hands and the net, none flung off.
	_net.state = CastNet.State.IDLE
	_net.tile_pos = _angler.tile_pos
	# With no hold, so the cast catches nothing and leaves the yard as the later stages
	# expect it: this is a check on the rope, not on the catch.
	_net.hold = 0
	var thrown := _net.cast_to(_water_near_angler())
	var worst := 0.0
	var frames := 0
	while thrown and _net.state != CastNet.State.IDLE and frames < 600:
		_net.call(&"_process", 1.0 / 60.0)
		frames += 1
		var rope: PackedVector2Array = _net.get(&"_rope_now")
		if rope.size() < 2:
			continue
		var head := rope[0]
		var foot := rope[rope.size() - 1]
		var along := foot - head
		for p in rope:
			# Distance off the straight line between the ends.
			var t := clampf((p - head).dot(along) / maxf(along.length_squared(), 0.001), 0.0, 1.0)
			worst = maxf(worst, p.distance_to(head + along * t))
	_check(thrown and _net.state == CastNet.State.IDLE and worst < 80.0,
		"the rope hangs off the net for a whole cast without flying apart",
		"%d frames, %.1f px off the line at worst" % [frames, worst])

	_net.state = CastNet.State.IDLE
	_net.catch.resize(0)
	_net.tile_pos = _angler.tile_pos
	_angler.end_cast()
	_net.radius = was_radius
	_net.power = was_power
	_net.hold = was_hold
	_advance()


## The rubbish layer: one batch, rebuilt only when something that is not the bob has
## changed.
##
## This is the regression guard for the whole draw path. A rebuild per frame is not a
## visible bug — it is just the frame rate quietly halving on a full lake — so the count
## is checked rather than the picture.
func _stage_draw_batch() -> void:
	if _in_stage == 1:
		# The lake drives the view from the camera every frame, and the camera is still
		# easing toward the angler. Held still for this stage so the counts below are
		# measuring the batch rather than the camera.
		_main.set_process(false)
		# A view over the whole basin, which is the worst case the batch exists for.
		# Projected, the tile field is a diamond: widest across at the two side corners,
		# tallest between the top and bottom ones.
		var half_w := float(Iso.COLS) * Iso.TILE_W * 0.5 + 200.0
		var tall := float(Iso.ROWS) * Iso.TILE_H + 400.0
		_grid.set_view(Rect2(Vector2(-half_w, -200.0), Vector2(half_w * 2.0, tall)))
		_grid.set_detailed(true)
		_rebuilds_before = _grid.rebuilds
		return
	if _in_stage == 2:
		_check(_grid.rebuilds == _rebuilds_before + 1,
			"moving the view rebuilds the batch once",
			"%d rebuilds" % (_grid.rebuilds - _rebuilds_before))
		_check(_grid.drawn_pieces > 1000, "the whole basin goes into one batch",
			"%d pieces" % _grid.drawn_pieces)
		_rebuilds_before = _grid.rebuilds
		return
	if _in_stage < 40:
		# Frames passing with nothing happening. The bob is the shader's problem now.
		return
	_check(_grid.rebuilds == _rebuilds_before,
		"a still lake is not rebuilt every frame",
		"%d rebuilds over %d frames" % [_grid.rebuilds - _rebuilds_before, _in_stage])

	# Taking a piece rewrites that tile's corner of the soup rather than laying the whole
	# thing out again. This is what the net's cast and drag were hitching on: a handful of
	# pieces a second, each of them re-stamping every piece in the lake.
	var lifted := _deep_tile()
	var deep_enough := _grid.stacks[lifted].size() > 1
	_rebuilds_before = _grid.rebuilds
	_grid.take(lifted, _grid.top_slot(lifted))
	_check(deep_enough and _grid.rebuilds == _rebuilds_before,
		"taking a piece patches the batch instead of rebuilding it",
		"%d rebuilds" % (_grid.rebuilds - _rebuilds_before))
	_rebuilds_before = _grid.rebuilds

	# Zooming out far enough drops the details that are then sub-pixel.
	var detailed_pieces := _grid.drawn_pieces
	_grid.set_detailed(false)
	_grid.queue_redraw()
	_check(detailed_pieces > 0, "there was something on screen to simplify", "")
	_grid.set_detailed(true)

	# The geometry is submitted without the bob, and gameplay still asks for it with the
	# bob on. Those two have to be the same piece.
	var index := _deep_tile()
	var gap := _grid.surface_pos(index).distance_to(_grid.surface_still(index))
	_check(gap <= LakeGrid.WAVE_AMPLITUDE + 0.01,
		"the drawn anchor and the bobbing position never part by more than the swell",
		"%.2f px of %.2f" % [gap, LakeGrid.WAVE_AMPLITUDE])

	_main.set_process(true)
	_advance()


## The ferry: loads the yard, sails out, sells, and comes back.
func _stage_ferry() -> void:
	if _ferry_step == 0:
		_main.set(&"sludge", 1000.0)
		_check(not _boat.is_running(),
			"a ferry told to stay put has not moved all this time", "")
		_check(_yard.held.size() > 0, "there is a load waiting", "%d pieces" % _yard.held.size())
		# Short of a full hold, with the lake still full of rubbish: the ferry waits.
		if _yard.held.size() >= _boat.capacity:
			_yard.held.resize(_boat.capacity - 1)
		_main.call(&"_set_auto_ferry", true)
		_boat.speed = TEST_FERRY_SPEED
		_ferry_step = 1
		_ferry_mark = Engine.get_process_frames()
		return
	if _ferry_step == 1:
		# Idle frames, because those are the ones the hull is given to think in. Enough of
		# them that a boat which was going to set off with a part load would have done it.
		if Engine.get_process_frames() - _ferry_mark < FERRY_LOOKS:
			return
		_check(not _boat.is_running(), "a part load waits in the yard for a full hold",
			"%d of %d" % [_yard.held.size(), _boat.capacity])
		var filler := _yard.held[0] if not _yard.held.is_empty() else 0
		while _yard.held.size() < _boat.capacity:
			_yard.held.append(filler)
		_sludge_before = float(_main.get(&"sludge"))
		_pieces_before = _yard.held.size()
		_ferry_step = 2
		_ferry_mark = Engine.get_process_frames()
		return
	if _ferry_step == 2:
		# A budget, not a deadline: it sets off on the first idle frame after the hold comes
		# up full, and how many physics ticks that is, is the machine's business.
		if not _boat.is_running() and Engine.get_process_frames() - _ferry_mark < FERRY_WAIT:
			return
		_check(_boat.is_running(), "the ferry sets off on its own once the hold is full",
			"it is %s" % _boat.status_line())
		# Out of the yard, not yet aboard: the lot is thrown to the hold one piece at a time
		# (`Boat.stow`), so `cargo` fills over the next frames. The sale below is what proves
		# it arrived.
		_check(_yard.held.size() < _pieces_before,
			"loading took the catch out of the yard",
			"%d aboard, %d left in the yard" % [_boat.cargo.size(), _yard.held.size()])
		_ferry_step = 3
		return
	# A budget, not a deadline: how long a run takes is how far the yard is that the hold
	# happens to be bound for, and that changes with what the harness managed to haul. At
	# 500 this sat 17% off a run that really finished (414 frames), and a fill change that
	# put a different material in the yard tipped it over. This is here to stop a hang.
	if _boat.runs_done < 1 and _in_stage < 1200:
		return
	_check(_boat.runs_done == 1, "the ferry completed a run",
		"after %d frames, %s" % [_in_stage, _boat.status_line()])
	_check(not _boat.is_running() and _boat.cargo.is_empty(),
		"it is back at the dock and empty", "")
	_check(float(_main.get(&"sludge")) > _sludge_before, "selling paid out",
		"%.1f -> %.1f sludge" % [_sludge_before, float(_main.get(&"sludge"))])
	_check(int(_main.get(&"sold_count")) > 0, "the sale was counted",
		"%d sold" % int(_main.get(&"sold_count")))
	# Thrown ashore, not deducted: the yard's drop point is the box on its platform, up the
	# bank from where the jetty meets the water, so a piece coming down lands in the picture
	# rather than in the lake.
	var stops: Array = _main.get(&"_dropoffs")
	var ashore := true
	for stop: Dropoff in stops:
		# Not "above the foot on screen": on the south and west banks the platform is
		# towards the camera, below the water's edge on screen. Above the ground the box
		# stands on, and near it, is the test.
		var drop := stop.drop_point()
		var landward := stop.foot - stop.axis * 1.0
		var back := Iso.tile_to_world(landward.x, landward.y)
		if drop.y >= back.y or drop.distance_to(back) > Iso.TILE_W:
			ashore = false
	_check(ashore, "every yard takes delivery in the box on its platform", "")

	# The waterline foam wraps the hull rather than lying under it as a bar: the arc's ends
	# are the frame's own cut, so it cannot leave the hull, and its middle bows towards the
	# camera. Checked at every heading, because the cut's width is different in each.
	var wraps := true
	var fitted := true
	for index in 16:
		var arc := Boat.waterline_arc(index, 2.0)
		var line := Boat.cut_line(index)
		var ends := arc[0].distance_to(arc[arc.size() - 1])
		var sag := 0.0
		for at in arc:
			sag = maxf(sag, at.y - arc[0].y)
		if sag < ends * 0.08 or sag > ends * 0.30:
			wraps = false
		# Never wider than the cut it was fitted to.
		var span := line[line.size() - 1].x - line[0].x
		for at in arc:
			if at.x < arc[0].x - 0.01 or at.x > arc[arc.size() - 1].x + 0.01:
				fitted = false
		if absf(ends - span * 2.0) > 0.01:
			fitted = false
	_check(wraps, "the waterline foam bows round the hull at every heading", "")
	_check(fitted, "and never reaches past the frame's own cut", "")
	_advance()


## The four merchants, and the route the ferry plans between them.
func _stage_dropoffs() -> void:
	var stops: Array = _main.get(&"_dropoffs")
	_check(stops.size() == TrashDef.KIND_NAMES.size(),
		"there is one merchant per material", "%d stops" % stops.size())

	# Held in Kind order, so a material is an index into them everywhere.
	var in_order := true
	for i in stops.size():
		if (stops[i] as Dropoff).kind != i:
			in_order = false
	_check(in_order, "the merchants are held in material order", "")

	# Every berth is on open water, or the ferry would sail into the bank to reach it — and
	# so is the point it lines up at, out along the jetty.
	var all_afloat := true
	var spread := 0.0
	for i in stops.size():
		var stop := stops[i] as Dropoff
		var berth: Vector2 = stop.berth
		if Iso.shore_fraction(berth.x, berth.y) >= 1.0:
			all_afloat = false
		if Iso.shore_fraction(stop.approach().x, stop.approach().y) >= 1.0:
			all_afloat = false
		for j in stops.size():
			spread = maxf(spread, berth.distance_to((stops[j] as Dropoff).berth))
	_check(all_afloat, "every berth and its approach are in the water", "")

	# The piers are drawn from the built sheet, laid into the plane: every yard has its
	# picture, the jetty leaves the bank at the water, the berth lies beside the jetty's end
	# on the camera's side, and every post the json calls wet stands in the lake.
	var pictured := true
	var wet_posts := true
	var wet_why := ""
	var beside := true
	for stop: Dropoff in stops:
		var book: Dictionary = stop.call(&"_book")
		if book.is_empty() or not book.has("posts_wet") or (book["posts_wet"] as Array).is_empty():
			pictured = false
			continue
		for key: String in ["under", "shade_wet", "shade_dry"]:
			if not book.has(key):
				pictured = false
		# Every post the sheet lists is one the deck leaves showing, recorded as
		# [middle, bottom, width]: sand and foam hung on a post drawn under the deck land on
		# open beach a tile from any pole.
		for key: String in ["posts_wet", "posts_dry"]:
			for post: Variant in book[key]:
				if (post as Array).size() != 3 or int(post[2]) <= 0:
					pictured = false
		# Wet is decided against the lake by the yard itself: every collar it hung is past
		# the drawn water's edge, and the jetty has some. Two, not four: the sheet only
		# carries the posts the deck leaves showing, and a jetty's far row is drawn under
		# the deck that covers it.
		var edge := Iso.shore_fraction(stop.foot.x, stop.foot.y)
		var collars: Array = stop.get(&"_collars")
		if collars.size() < 2:
			wet_posts = false
			wet_why += "%s only %d collars; " % [stop.kind_name(), collars.size()]
		# The feet, not the collars themselves: a collar rides the swell, so its own position
		# crosses the drawn waterline by a thousandth twice a second and the check would
		# pass or fail on which frame it ran. The foot is where the post stands.
		for at: Vector2 in (stop.get(&"_collar_feet") as PackedVector2Array):
			var tile := Iso.world_to_tile(at)
			if Iso.shore_fraction(tile.x, tile.y) >= edge:
				wet_posts = false
				wet_why += "%s collar at %.3f past %.3f; " % [
					stop.kind_name(), Iso.shore_fraction(tile.x, tile.y), edge]
		var end := stop.foot + stop.axis * Dropoff.JETTY_OUT
		var off := stop.berth - end
		if absf(off.dot(stop.axis)) > 0.01 or Iso.tile_to_world(off.x, off.y).y <= 0.0:
			beside = false
		if absf(Iso.shore_fraction(stop.foot.x, stop.foot.y) - 1.0) > 0.05:
			beside = false
	_check(pictured, "every yard is drawn from the built sheet, posts and all", "")
	_check(wet_posts, "the jetty's posts stand in the water and wear foam", wet_why)
	_check(beside, "the berth lies beside the jetty's end, on the camera's side", "")
	_check(spread > Iso.RADIUS.x, "the merchants are spread round the lake",
		"%.1f tiles apart at the widest" % spread)

	# Every kind of rubbish has a buyer, and every buyer has something to buy.
	var per_kind := PackedInt32Array([0, 0, 0, 0])
	for def: TrashDef in _grid.defs:
		per_kind[def.material] += 1
	var covered := true
	for kind in per_kind.size():
		if per_kind[kind] == 0:
			covered = false
	_check(covered, "every material has rubbish made of it", str(per_kind))

	# A route calls at the materials aboard and nothing else.
	_boat.cargo = PackedInt32Array([
		_def_of(TrashDef.Kind.METAL), _def_of(TrashDef.Kind.PLASTIC),
		_def_of(TrashDef.Kind.METAL)
	])
	var route := _boat.plan_route()
	_check(route.size() == 2 and route.has(TrashDef.Kind.METAL)
			and route.has(TrashDef.Kind.PLASTIC),
		"the route calls at the materials aboard, once each", str(route))
	_boat.cargo.resize(0)
	_check(_boat.plan_route().is_empty(), "an empty hold has nowhere to be", "")

	# Pathing. The way home is the case that matters most — the ferry is empty, it has one
	# place to be, and a wandering return is dead time in the loop.
	# The dock is on the island's south side, so the yard due north of it is the one case
	# that genuinely has to go round. Everything else should be a straight run, and no
	# route home should be much longer than the distance it covers.
	var direct_runs := 0
	var worst_home := 0
	var worst_detour := 1.0
	var crossings := 0
	for i in stops.size():
		var berth: Vector2 = (stops[i] as Dropoff).berth
		var home: Array[Vector2] = _boat.call(&"_plan_legs", berth, _boat.dock)
		worst_home = maxi(worst_home, home.size())
		if home.size() == 1:
			direct_runs += 1
		worst_detour = maxf(
			worst_detour, _path_length(berth, home) / berth.distance_to(_boat.dock)
		)
		if not _path_misses_island(berth, home):
			crossings += 1
	# The two yards on the dock's own side of the island should be a straight run. The
	# other two have the island between them and home, so they bend — what matters there is
	# that the bend is a bend and not a lap, which is what the detour figure measures. The
	# theoretical best for the yard dead opposite the dock is about 1.09.
	_check(direct_runs >= 2, "the yards on the dock's side are a straight run home",
		"%d of 4 direct — %s" % [direct_runs, _home_report(stops)])
	_check(worst_detour < 1.35, "and the ones that go round bend rather than tour",
		"%.2f times the direct distance at worst" % worst_detour)
	# A loose bound only. Corners are not the cost — a few of them round the island read as
	# a curve, which is what a boat steering past something looks like. Distance is the
	# cost, and the check above is the one that guards it. This is here to catch the path
	# planner exploding, not to police its shape.
	_check(worst_home <= 5, "and no path home explodes into a hundred corners",
		"%d legs at worst" % worst_home)

	# And the case the bending exists for: two yards on opposite banks, with the island in
	# between.
	var east: Vector2 = (stops[TrashDef.Kind.WOOD] as Dropoff).berth
	var west: Vector2 = (stops[TrashDef.Kind.RUBBER] as Dropoff).berth
	var across: Array[Vector2] = _boat.call(&"_plan_legs", east, west)
	_check(across.size() > 1, "a run across the lake bends round the island",
		"%d legs" % across.size())
	if not _path_misses_island(east, across):
		crossings += 1
	_check(crossings == 0, "no planned path runs over the island",
		"%d of them do" % crossings)

	# The box on the pier (2026-09-13): a delivery is aimed into its mouth, heaps up inside
	# it and sinks away again while the ferry is gone; the sign is on the sheet and the
	# name is written on it at runtime.
	var aimed := true
	var signed := true
	var heaped := true
	var box_why := ""
	for stop: Dropoff in stops:
		var book: Dictionary = stop.call(&"_book")
		if book.is_empty():
			continue
		var mouth: Vector2 = stop.call(&"_world", book["drop"], book)
		var empty_at := stop.drop_point()
		# Into the mouth: on its centreline, under its middle, above the box's floor.
		if absf(empty_at.x - mouth.x) > 0.01 or empty_at.y < mouth.y \
				or empty_at.y > mouth.y + Dropoff.BOX_TALL * 0.5:
			aimed = false
			box_why += "%s aims %s at mouth %s; " % [stop.kind_name(), str(empty_at), str(mouth)]
		for key: String in ["sign", "sign_cut", "sign_foot"]:
			if not book.has(key):
				signed = false
		if stop.sign_text().is_empty():
			signed = false
		for i in 5:
			stop.put(_def_of(stop.kind))
		var full_at := stop.drop_point()
		if stop.held_count() != 5 or full_at.y >= empty_at.y:
			heaped = false
			box_why += "%s held %d, rose %.1f; " % [
				stop.kind_name(), stop.held_count(), empty_at.y - full_at.y]
		# The drain: nothing through the hold, then one every DRAIN_EVERY.
		stop.call(&"_drain", Dropoff.DRAIN_HOLD - 0.1)
		if stop.held_count() != 5:
			heaped = false
			box_why += "%s drained during the hold; " % stop.kind_name()
		stop.call(&"_drain", 0.1 + Dropoff.DRAIN_EVERY * 5.0 + 0.01)
		if stop.held_count() != 0:
			heaped = false
			box_why += "%s still holds %d after the drain; " % [stop.kind_name(), stop.held_count()]
	_check(aimed, "a delivery is aimed into the box's mouth", box_why)
	_check(signed, "every yard has a sign on the sheet and a name to write on it", "")
	_check(heaped, "the pier's box heaps up as pieces land and drains while the ferry is away",
		box_why)

	# Coins: one per landing, to the plate, merged past the cap, landing with what they carry.
	var coins: CoinFly = _main.get(&"_coins")
	var coined := coins != null
	if coined:
		var tally := [0]
		var on_land := func(carry: int) -> void: tally[0] += carry
		coins.landed.connect(on_land)
		var sent := CoinFly.MOST + 8
		for i in sent:
			coins.fly((stops[0] as Dropoff).drop_point())
		if coins.flying() != CoinFly.MOST:
			coined = false
		coins.call(&"_process", CoinFly.FLIGHT + 0.01)
		if coins.flying() != 0 or tally[0] != sent:
			coined = false
		coins.landed.disconnect(on_land)
	_check(coined, "a sale's coins fly to the plate, merged past the cap, and land with what they carry",
		"" if coins == null else "%d in the air" % coins.flying())
	_advance()


## Legs and detour home from each yard, named. When this check fails, which yard is
## misbehaving is the entire question.
func _home_report(stops: Array) -> String:
	var parts := PackedStringArray()
	for i in stops.size():
		var berth: Vector2 = (stops[i] as Dropoff).berth
		var home: Array[Vector2] = _boat.call(&"_plan_legs", berth, _boat.dock)
		parts.append("%s %d legs %.2fx" % [
			(stops[i] as Dropoff).kind_name(), home.size(),
			_path_length(berth, home) / berth.distance_to(_boat.dock)
		])
	return ", ".join(parts)


## How far a planned path actually travels, in tiles. Against the straight-line distance,
## this is the number that says whether the pathing is bending or wandering.
func _path_length(from: Vector2, legs: Array[Vector2]) -> float:
	var total := 0.0
	var at := from
	for leg: Vector2 in legs:
		total += at.distance_to(leg)
		at = leg
	return total


## Does a planned path stay off the island the whole way?
##
## Sampled rather than reasoned about: the legs are straight, the island is a wobbly
## ellipse, and walking the line is both shorter to write and harder to fool.
func _path_misses_island(from: Vector2, legs: Array[Vector2]) -> bool:
	var at := from
	for leg: Vector2 in legs:
		for i in 41:
			var point := at.lerp(leg, float(i) / 40.0)
			if Iso.island_fraction(point.x, point.y) < 1.0:
				return false
		at = leg
	return true


## The pack (2026-09-14): three more dogs may be adopted, wired like the first, sharing its
## training, and no two of them swim for the same stick.
func _stage_pack() -> void:
	_main.set(&"sludge", 1000000.0)
	var dogs: Array = _main.get(&"_dogs")
	_check(dogs.size() == 1, "one dog to begin with", "%d" % dogs.size())
	_main.call(&"_buy", &"dog_count")
	dogs = _main.get(&"_dogs")
	_check(dogs.size() == 2, "adopting puts a second dog on the island", "%d" % dogs.size())
	var pup := dogs[1] as Dog
	var first := dogs[0] as Dog
	_check(pup.is_inside_tree() and pup.grid != null and pup.angler != null and pup.day != null,
		"the new dog is wired like the first", "")
	_main.call(&"_buy", &"dog_fetch")
	_check(pup.fetch_most == first.fetch_most and pup.fetch_most == int(_main.call(&"dog_fetch")),
		"the pack shares one training", "%d / %d" % [pup.fetch_most, first.fetch_most])
	_check(not pup.tile_pos.is_equal_approx(first.tile_pos), "and stands apart", "")
	var cap := int(_main.get(&"MAX_DOGS"))
	for i in cap + 2:
		_main.call(&"_buy", &"dog_count")
	dogs = _main.get(&"_dogs")
	_check(dogs.size() == cap and int(_main.call(&"dog_count")) == cap, "the pack stops at the limit",
		"%d dogs, limit %d" % [dogs.size(), cap])
	var purse := float(_main.get(&"sludge"))
	_main.call(&"_buy", &"dog_count")
	_check(is_equal_approx(float(_main.get(&"sludge")), purse), "a full pack is not charged for another", "")
	# Claims: what one dog is swimming for, the others do not pick.
	pup.tile_pos = first.tile_pos
	var stick := int(first.call(&"_find_stick"))
	_check(stick >= 0, "there is a stick to fetch", "")
	first.call(&"_aim_at", stick)
	var others := []
	for i in 20:
		others.append(int(pup.call(&"_find_stick")))
	_check(not stick in others, "a stick one dog has claimed is not picked by another", str(others))
	first.call(&"_release")
	# The other dogs are still running and may be claiming sticks of their own; only this one's
	# claim has to be gone.
	_check(not first in (Dog.claims as Dictionary).values(), "a released claim is gone", str(Dog.claims))
	_stage_dog_delivery(first)
	_stage_dog_idle(dogs)
	_advance()


## Where the pack loafs (2026-09-16, Richard: they cluster around the box).
##
## The rule is a preference, not a wall, so this asks the rule rather than watching the
## animals: `_elbow_room` scores a spot by the worst of what it wants — clear of the crate,
## the hut and the rest of the pack — and `_somewhere_on_land` takes the first dart that
## satisfies all three.
func _stage_dog_idle(dogs: Array) -> void:
	var dog := dogs[0] as Dog
	var crate := dog.crate_tile
	var hut := Iso.shed_centre()
	# Everyone out of the way, so the two buildings are the only thing the score can see.
	# Stood still as well as moved: a dog left walking somewhere reports the spot it is
	# walking to, and the stage before this one leaves them wherever the sim got to.
	for other: Variant in dogs:
		var away := other as Dog
		away.set(&"_state", Dog.State.IDLE)
		away.tile_pos = Iso.ISLAND_CENTRE + Vector2(0.0, -20.0)
	_check(float(dog.call(&"_elbow_room", crate)) < 0.5
		and float(dog.call(&"_elbow_room", hut)) < 0.5,
		"a spot against the box or the hut scores badly",
		"crate %.2f, hut %.2f" % [
			float(dog.call(&"_elbow_room", crate)), float(dog.call(&"_elbow_room", hut))
		])
	# Somewhere on the far side of the island from both.
	var open := Iso.ISLAND_CENTRE + Vector2(-Dog.SHED_CLEAR - 1.0, -Dog.IDLE_CLEAR - 1.0)
	_check(is_equal_approx(float(dog.call(&"_elbow_room", open)), 1.0),
		"and open grass scores full marks",
		"%.2f" % float(dog.call(&"_elbow_room", open)))
	# Another dog standing on that spot spoils it.
	var pup := dogs[1] as Dog
	# Standing on it, not walking to it: `aiming_for` hands back the target of a dog that is
	# on its way somewhere, so a stale one would answer this question instead of the spot.
	pup.set(&"_state", Dog.State.IDLE)
	pup.tile_pos = open
	_check(float(dog.call(&"_elbow_room", open)) < 0.2,
		"a spot another dog is already on scores badly too",
		"%.2f" % float(dog.call(&"_elbow_room", open)))
	# And so does one another dog is walking to, which is the case that actually piles them
	# up: two dogs choosing a stride apart arrive together however far apart they chose.
	pup.tile_pos = Iso.ISLAND_CENTRE + Vector2(0.0, -20.0)
	pup.set(&"_state", Dog.State.WANDER)
	pup.set(&"_target", open)
	_check(float(dog.call(&"_elbow_room", open)) < 0.2,
		"and so does one another dog is on its way to",
		"%.2f" % float(dog.call(&"_elbow_room", open)))
	pup.set(&"_state", Dog.State.IDLE)

	# The whole pack, put on the box and asked where it would rather be. Every dog picks
	# somewhere with more room than it is standing in, and none of them picks the box.
	for other: Variant in dogs:
		var animal := other as Dog
		animal.tile_pos = crate
		animal.set(&"_state", Dog.State.IDLE)
	var tight := 0
	var near_crate := 0
	for other: Variant in dogs:
		var animal := other as Dog
		var spot: Vector2 = animal.call(&"_somewhere_on_land")
		if float(animal.call(&"_elbow_room", spot)) <= float(animal.call(&"_elbow_room", crate)):
			tight += 1
		if spot.distance_to(crate) < Dog.IDLE_CLEAR * 0.5:
			near_crate += 1
		# Taken, so the next dog has to keep clear of it.
		animal.set(&"_state", Dog.State.WANDER)
		animal.set(&"_target", spot)
	_check(tight == 0 and near_crate == 0,
		"the pack picks roomier spots than the box it delivered to",
		"%d no better, %d still at the box" % [tight, near_crate])

	# A delivery never ends with the dog standing at the crate.
	var one := dogs[0] as Dog
	one.tile_pos = crate
	one.set(&"_state", Dog.State.DROPPING)
	one.call(&"_hand_over")
	_check(int(one.get(&"_state")) != Dog.State.IDLE
		and int(one.get(&"_state")) != Dog.State.NAP
		and int(one.get(&"_state")) != Dog.State.LOUNGE,
		"and a dog that has just delivered walks off rather than settling on the box",
		"state %d" % int(one.get(&"_state")))
	_check(int(one.get(&"_state")) != Dog.State.SIT, "nor sitting down on it", "")
	_stage_dog_breeds(dogs)
	_stage_dog_manners(dogs)


## The pack's manners (2026-09-22, Richard): a dog gives way to the angler, walks slow and
## runs every land leg, bends round the buildings by their corners before touching them,
## and the pack barks per dog with no two over each other, faintly from afar.
func _stage_dog_manners(dogs: Array) -> void:
	var dog := dogs[0] as Dog
	var others: Array = dogs.slice(1)
	for o: Dog in others:
		o.set(&"_state", Dog.State.NAP)
		o.set(&"_mood_left", 1000.0)
		o.tile_pos = Iso.ISLAND_CENTRE + Vector2(-4.0, 3.0)
	_check(Dog.WALK_SPEED < 2.0 and Dog.WALK_SPEED < Dog.RUN_SPEED * 0.4,
		"the walk is a walk", "%.1f against %.1f" % [Dog.WALK_SPEED, Dog.RUN_SPEED])
	dog.tile_pos = Iso.ISLAND_CENTRE + Vector2(3.0, -1.0)
	_check(is_equal_approx(float(dog.call(&"_swim_pace")), Dog.RUN_SPEED), "the way out runs on land", "")
	dog.tile_pos = Iso.ISLAND_CENTRE + Vector2(Iso.ISLAND_RADIUS.x + 4.0, 0.0)
	_check(is_equal_approx(float(dog.call(&"_swim_pace")), Dog.SWIM_SPEED), "and swims in the water", "")
	# Round the crate and round the hut: a straight line through each, walked at running
	# pace, never touching (`_hug` never engaged, the stuck clock never started) and
	# arriving.
	var crate: Vector2 = dog.crate_tile
	for trial: Array in [
		["the crate", crate + Vector2(-3.2, 0.1), crate + Vector2(3.2, -0.1)],
		["the hut", Iso.shed_centre() + Vector2(0.1, 3.4), Iso.shed_centre() + Vector2(-0.1, -3.4)],
	]:
		dog.tile_pos = trial[1]
		dog.set(&"_state", Dog.State.IDLE)
		dog.call(&"_fresh_aim")
		dog.set(&"_speed", 0.0)
		var target: Vector2 = trial[2]
		var hugged := false
		var stuck := false
		var arrived := false
		var bent := false
		for i in 900:
			arrived = bool(dog.call(&"_step_towards", target, Dog.RUN_SPEED, 1.0 / 60.0))
			if dog.get(&"_hug_along") != Vector2.ZERO:
				hugged = true
			if float(dog.get(&"_stuck")) > 0.0:
				stuck = true
			if dog.get(&"_around") != Vector2.INF:
				bent = true
			if arrived:
				break
		_check(arrived, "a dog sent through %s arrives on the far side" % trial[0], str(dog.tile_pos))
		_check(bent, "having bent round a corner of it", "")
		_check(not hugged and not stuck, "and never touched it on the way", "hug %s stuck %s" % [hugged, stuck])
	# The nudge: a still dog beside the angler is pushed clear, the angler does not move.
	var angler: Angler = _main.get(&"_angler")
	var angler_was := angler.tile_pos
	var stood := Iso.ISLAND_CENTRE + Vector2(3.6, 1.2)
	angler.tile_pos = stood
	dog.set(&"_state", Dog.State.SIT)
	dog.set(&"_mood_left", 100.0)
	dog.tile_pos = stood + Vector2(0.2, 0.0)
	dog.set(&"_angler_was", Vector2.INF)
	for i in 30:
		dog.call(&"_give_way", 0.05)
	_check(dog.tile_pos.distance_to(stood) >= Dog.NUDGE_REACH - 0.01,
		"a dog beside a standing angler is pushed clear", "%.2f" % dog.tile_pos.distance_to(stood))
	_check(angler.tile_pos.is_equal_approx(stood), "and the angler did not move", "")
	# Walking: the push is sideways off the walk, not ahead of it.
	dog.tile_pos = stood + Vector2(0.3, 0.0)
	dog.set(&"_angler_was", stood - Vector2(0.1, 0.0))
	angler.tile_pos = stood
	dog.call(&"_give_way", 0.05)
	var moved: Vector2 = dog.tile_pos - (stood + Vector2(0.3, 0.0))
	_check(absf(moved.y) > absf(moved.x) * 4.0, "a walking angler pushes the dog sideways", str(moved))
	_check(dog.get(&"_state") == Dog.State.SIT, "and does not wake or move it on", "")
	angler.tile_pos = angler_was
	dog.set(&"_angler_was", Vector2.INF)
	# Barks: per dog, never two at once, faint from afar.
	var src := FileAccess.get_file_as_string("res://scripts/dog.gd")
	_check(src.find("static var _voice_next") < 0 and src.find("var _voice_next") >= 0,
		"the voice gap is each dog's own", "")
	_check(Dog.VOICE_GAP_MOST < 18.0, "and shorter than it was", "%.0f" % Dog.VOICE_GAP_MOST)
	_check(src.find("play(&\"bark\", FAR_DB)") >= 0 and Dog.FAR_DB < -8.0, "a far bark is played faint", "")
	if Sfx.main() != null:
		var two := dogs[1] as Dog
		dog.set(&"_voice_next", 0.0)
		two.set(&"_voice_next", 0.0)
		Dog._pack_hush = 0.0
		dog.call(&"_speak", &"bark")
		two.call(&"_speak", &"bark")
		_check(float(dog.get(&"_voice_next")) > 0.0 and is_zero_approx(float(two.get(&"_voice_next"))),
			"two dogs do not bark over each other", "")
	for o: Dog in others:
		o.set(&"_mood_left", 0.0)


## The pack's coats and gaits, the sit, and the gripped carry (2026-09-22, Richard).
##
## Breeds are fixed by slot — yellow, orange, tan-and-white, dark brown — so the rule is
## asked of the slot and of the sheets rather than of any roll. The mouth is measured off
## every frame, so a carried piece is asked to sit within a few pixels of it and to move
## with the frame; and to be drawn under the dog, since the head is what says "held".
func _stage_dog_breeds(dogs: Array) -> void:
	_check(DogArt.breeds() == 4 and DogArt.breeds() == int(_main.get(&"MAX_DOGS")),
		"four breeds, one a dog of a full pack", "%d" % DogArt.breeds())
	for b in DogArt.breeds():
		_check(DogArt.ready(b), "breed %d loads its sheet" % b, "")
		for name: StringName in [&"idle", &"sit", &"laid", &"run", &"walk", &"run2", &"walk2", &"sleep"]:
			_check(DogArt.length(name, b) >= 4, "breed %d carries %s" % [b, name],
				"%d frames" % DogArt.length(name, b))
	# The three sheets are three dogs: the first idle frame's pixels differ between them.
	var seen := {}
	for b in DogArt.breeds():
		var art := DogArt.art_frame(&"idle", 0, b)
		var image: Image = (art["sheet"] as Texture2D).get_image()
		var region: Rect2 = art["region"]
		var sum := 0
		for y in int(region.size.y):
			for x in int(region.size.x):
				sum += image.get_pixel(int(region.position.x) + x, int(region.position.y) + y).to_rgba32()
		seen[sum] = true
	_check(seen.size() == DogArt.breeds(), "and no two breeds are the same picture", str(seen.keys()))
	var slots := []
	for i in dogs.size():
		var dog := dogs[i] as Dog
		slots.append([dog.slot, dog.breed])
		_check(dog.slot == i and dog.breed == posmod(i, DogArt.breeds()),
			"dog %d wears its slot's breed" % i, str(slots))
	var coats := {}
	for i in dogs.size():
		coats[(dogs[i] as Dog).breed] = true
	_check(coats.size() == dogs.size(), "no two dogs of a full pack share a coat", str(coats.keys()))
	_check(DogArt.gait(0, false) == &"run" and DogArt.gait(1, false) == &"run2"
		and DogArt.gait(0, true) == &"walk" and DogArt.gait(1, true) == &"walk2",
		"even slots run the first gait pair, odd the second", "")
	# Sit, in the four places.
	var one := dogs[0] as Dog
	one.set(&"_state", Dog.State.SIT)
	_check(one.call(&"_showing") == &"sit", "a sitting dog shows the sit", str(one.call(&"_showing")))
	one.set(&"_state", Dog.State.DROPPING)
	_check(one.call(&"_showing") == &"sit", "a dog waiting at the crate sits", str(one.call(&"_showing")))
	one.set(&"_state", Dog.State.PETTED)
	_check(one.call(&"_showing") == &"sit", "a petted dog sits", str(one.call(&"_showing")))
	one.set(&"_state", Dog.State.WANDER)
	_check(one.call(&"_showing") == &"walk", "the first dog wanders on the first walk", str(one.call(&"_showing")))
	var two := dogs[1] as Dog
	two.set(&"_state", Dog.State.WANDER)
	_check(two.call(&"_showing") == &"walk2", "the second on the second", str(two.call(&"_showing")))
	var sits := 0
	for i in 400:
		one.tile_pos = Vector2(Iso.ISLAND_CENTRE.x - 2.0, Iso.ISLAND_CENTRE.y + 1.6)
		one.call(&"_settle")
		if int(one.get(&"_state")) == Dog.State.SIT:
			sits += 1
	_check(sits > 10, "the sit is a mood the island roll lands on", "%d of 400" % sits)
	one.set(&"_state", Dog.State.IDLE)
	# The mouth moves with the frame: over a run cycle it is not one point.
	var mouths := {}
	for f in DogArt.length(&"run"):
		mouths[DogArt.mouth(&"run", Dog.HEIGHT, true, f)] = true
	_check(mouths.size() >= 3, "the mouth rides the head through the run", str(mouths.keys()))
	var left := DogArt.mouth(&"idle", Dog.HEIGHT, true, 0)
	var right := DogArt.mouth(&"idle", Dog.HEIGHT, false, 0)
	_check(left.x < 0.0 and right.x > 0.0 and is_equal_approx(left.y, right.y),
		"the mouth is ahead of the dog whichever way it faces", "%s / %s" % [left, right])
	var span := DogArt.span(&"idle", Dog.HEIGHT)
	_check(-left.y > span.y * 0.5 and -left.y < span.y, "and at head height", "%s of %s" % [left, span])
	_check(absf(left.x) > span.x * 0.25, "and at the front of the picture", "%s of %s" % [left, span])
	# The held piece is drawn before the dog, so the head covers its back end.
	var source := FileAccess.get_file_as_string("res://scripts/dog.gd")
	_check(source.find("_draw_stick(at, name, frame)") < source.find("DogArt.stamp(self, name, frame, at"),
		"the carried piece is drawn under the dog", "")
	_check(source.find("_carry_drop") >= 0 and source.find("CARRY_LAG") >= 0,
		"and trails the mouth with a lag", "")


## The delivery (2026-09-16): whichever side of the crate the dog is already at, and round
## the box rather than into it.
func _stage_dog_delivery(dog: Dog) -> void:
	var crate := dog.crate_tile
	# Each of the four sides, asked for from just outside it. The one nearest is the one it
	# gets — the old rule handed back the same side whatever direction the dog came from.
	var sides := {
		"east": Vector2(1.0, 0.0), "west": Vector2(-1.0, 0.0),
		"south": Vector2(0.0, 1.0), "north": Vector2(0.0, -1.0),
	}
	var wrong := []
	for name: String in sides:
		var way: Vector2 = sides[name]
		dog.tile_pos = crate + way * 3.0
		var spot: Vector2 = dog.call(&"_drop_spot")
		if (spot - crate).normalized().dot(way) < 0.9:
			wrong.append(name)
		if not Iso.on_island_ground(spot) or Iso.in_shed(spot.x, spot.y, Iso.SHED_KEEP):
			wrong.append(name + " (off the grass)")
	_check(wrong.is_empty(), "the dog delivers from whichever side of the crate it is at",
		"wrong: %s" % str(wrong))
	# The far side counts as a side. It is the one towards the middle of the island, which
	# the old rule only ever offered as a last resort.
	var inward := (Iso.ISLAND_CENTRE - crate).normalized()
	dog.tile_pos = crate + inward * 3.0
	var far: Vector2 = dog.call(&"_drop_spot")
	_check((far - crate).normalized().dot(inward) > 0.6,
		"including the far side, where the box stands in front of it",
		"%.2f" % (far - crate).normalized().dot(inward))

	# Round the crate, not through it. Straight across the box, which is the trip that used
	# to leave the animal shoving at a plank.
	dog.tile_pos = crate - Vector2(2.2, 0.0)
	dog.call(&"_fresh_aim")
	var goal := crate + Vector2(2.2, 0.0)
	var inside := 0
	var got := false
	for step in 400:
		if bool(dog.call(&"_step_towards", goal, Dog.RUN_SPEED, 0.016)):
			got = true
			break
		if Yard.covers(crate, dog.tile_pos, 0.0):
			inside += 1
	_check(got and inside == 0, "it walks round the crate rather than into it",
		"arrived %s, %d frames inside the box" % [str(got), inside])
	_check(not bool(dog.call(&"_blocked")),
		"and is never reported stuck doing it", "")

	# The same, past the hut: its footprint is the other rectangle on the island.
	var hut := Iso.shed_centre()
	dog.tile_pos = hut - Vector2(2.6, 0.0)
	dog.call(&"_fresh_aim")
	var over := hut + Vector2(2.6, 0.0)
	var through := 0
	got = false
	for step in 400:
		if bool(dog.call(&"_step_towards", over, Dog.RUN_SPEED, 0.016)):
			got = true
			break
		if Iso.in_shed(dog.tile_pos.x, dog.tile_pos.y, 0.0):
			through += 1
	_check(got and through == 0, "and round the hut the same way",
		"arrived %s, %d frames in the walls" % [str(got), through])


## The fleet: a second hull is a second boat in the water, wired up the same as the first
## and moored somewhere else.
func _stage_fleet() -> void:
	_main.set(&"sludge", 100000.0)
	var before := _main.get(&"_boats").size() as int
	var price := float(_main.call(&"cost_of", &"fleet"))
	# It used to be "the expensive one", over four times a net level. The boats are forgiving
	# now (2026-09-18, issue #23): the first extra hull is 200 at most (Richard, 2026-09-14).
	_check(price <= 200.0, "the first extra hull costs 200 at most", "%.0f" % price)
	_main.call(&"_buy", &"fleet")
	var boats: Array = _main.get(&"_boats")
	_check(boats.size() == before + 1, "buying a ferry puts one in the water",
		"%d hulls" % boats.size())

	var second := boats[1] as Boat
	_check(second.is_inside_tree() and second.yard != null and second.grid != null,
		"the new hull is wired up like the first", "")
	_check(is_equal_approx(second.speed, float(_main.call(&"boat_speed"))),
		"it was bought with the upgrades already paid for",
		"%.1f tiles/s, carries %d" % [second.speed, second.capacity])
	_check(not second.dock.is_equal_approx(_boat.dock), "the fleet moors in a row",
		"%.1f apart" % second.dock.distance_to(_boat.dock))
	_check(second.rng_seed != _boat.rng_seed, "each hull rolls its own dice",
		"")

	# The cap: buying past it takes no money and puts no hull in the water.
	var cap := int(_main.get(&"MAX_BOATS"))
	_main.set(&"sludge", 1000000.0)
	for i in cap + 3:
		_main.call(&"_buy", &"fleet")
	var fleet := _main.get(&"_boats") as Array
	_check(fleet.size() == cap, "the fleet stops at the limit",
		"%d hulls, limit %d" % [fleet.size(), cap])
	var purse := float(_main.get(&"sludge"))
	_main.call(&"_buy", &"fleet")
	_check(is_equal_approx(float(_main.get(&"sludge")), purse),
		"a full fleet is not charged for another", "")

	# Hulls do not sit inside each other. Two put on the same tile, and a second pair put
	# exactly on top of each other — which has no direction to part along and is the case
	# that would loop forever if the nudge were rolled instead of worked out.
	var clear := float(_main.get(&"PART_CLEAR"))
	var one := fleet[0] as Boat
	var two := fleet[1] as Boat
	one.tile_pos = Iso.CENTRE + Vector2(3.0, 0.0)
	two.tile_pos = one.tile_pos + Vector2(0.2, 0.0)
	for i in 60:
		_main.call(&"_part_the_fleet", 1.0 / 60.0)
	_check(one.tile_pos.distance_to(two.tile_pos) > clear * 0.9,
		"two hulls in the same water push apart",
		"%.2f tiles, clearance %.2f" % [one.tile_pos.distance_to(two.tile_pos), clear])
	two.tile_pos = one.tile_pos
	for i in 60:
		_main.call(&"_part_the_fleet", 1.0 / 60.0)
	_check(one.tile_pos.distance_to(two.tile_pos) > clear * 0.9,
		"two hulls exactly on top of each other still part",
		"%.2f tiles" % one.tile_pos.distance_to(two.tile_pos))

	# And a fleet at rest stays in its row: the moorings are spread wider than the
	# clearance, so nothing pushes a moored boat off its berth.
	var berthed := true
	for i in fleet.size():
		for j in range(i + 1, fleet.size()):
			if (fleet[i] as Boat).dock.distance_to((fleet[j] as Boat).dock) < clear:
				berthed = false
	_check(berthed, "the moorings are spread wider than the clearance", "")
	_advance()


## The cast is one gesture: press throws, the same press reels it back the moment it
## lands, release stops it. No second click anywhere in that.
func _stage_one_gesture() -> void:
	if _in_stage == 1:
		_main.set(&"pollution", 1.0)
		var near := _water_near_angler()
		_main.call(&"_cast_at", near)
		_net.set_pulling(true)
		_check(_net.state == CastNet.State.FLYING, "the press throws the net", "")
		return
	if _net.state == CastNet.State.FLYING and _in_stage < 200:
		return
	if not _gesture_checked:
		_gesture_checked = true
		_check(_net.state == CastNet.State.REELING,
			"a held press reels it back without a second click",
			"it is %d" % _net.state)
		_net.set_pulling(false)
		_check(_net.state == CastNet.State.SETTLED, "letting go stops it where it is", "")
		_net.set_pulling(true)
		_check(_net.state == CastNet.State.REELING, "pressing again carries on reeling", "")
	if _net.state == CastNet.State.REELING and _in_stage < 500:
		return
	_net.set_pulling(false)
	_advance()


## The save: a run written out and read back is the same run, on the same lake.
func _stage_save() -> void:
	# Nothing afloat and something on the pile, so what comes back is what went in: a
	# hull's cargo is landed back in the yard by a load, which would muddy the count.
	for boat: Boat in _main.get(&"_boats") as Array:
		boat.cargo.resize(0)
	for i in 3:
		_yard.put(_def_of(TrashDef.Kind.PLASTIC))
	_main.set(&"sludge", 4321.0)
	_main.call(&"_buy", &"net_width")
	_main.call(&"_buy", &"bird_worth")
	var birds_was := int(_main.get(&"bird_worth_level"))
	_main.call(&"_buy", &"dog_count")
	var dogs_was := (_main.get(&"_dogs") as Array).size()
	var pieces := _grid.piece_count()
	var sludge_was := float(_main.get(&"sludge"))
	var width_was := int(_main.get(&"net_width_level"))
	var yard_was := _yard.held.size()
	var hulls_was := (_main.get(&"_boats") as Array).size()

	_check(bool(_main.call(&"save_game")), "the run writes itself out", "")
	_check(bool(_main.call(&"has_save")), "there is a save on disk", "")

	# The settings are `Prefs`' alone (2026-09-15): a save that carried its own copy handed it
	# back on load and undid whatever had been set on the menu.
	var file := FileAccess.open(_main.get(&"save_path") as String, FileAccess.READ)
	var written: Dictionary = (file.get_var(true) as Dictionary) if file != null else {}
	var settings_in_save := PackedStringArray()
	for key: String in ["music", "music_level", "sfx", "sfx_level", "fullscreen"]:
		if written.has(key):
			settings_in_save.append(key)
	_check(settings_in_save.is_empty(), "the save carries no sound or screen settings",
		", ".join(settings_in_save))
	# Spend and catch after saving, so a load that did nothing would be caught.
	_main.set(&"sludge", 0.0)
	_main.set(&"net_width_level", 0)
	_main.set(&"bird_worth_level", 0)
	_yard.held.resize(0)
	_grid.take(_deep_tile(), 0)

	# `Prefs.store` writes user://settings.cfg there and then, so a harness that sets a level
	# and walks away has changed the player's own sliders — which is exactly what "my ambience
	# was lost on restart" turned out to be (2026-09-16). What it borrows, it puts back.
	var settings := _main.get_node(^"HUD/Settings")
	var sfx_was := Prefs.sfx_level
	var ambience_was := Prefs.ambience_level
	Prefs.store(&"sfx_level", 0.42)
	Prefs.store(&"ambience_level", 0.17)

	_check(bool(_main.call(&"load_game")), "and reads itself back", "")
	_check(is_equal_approx(settings.sfx_level, 0.42)
		and is_equal_approx(settings.ambience_level, 0.17),
		"the settings come from Prefs, whatever the file says", "")
	# The mix is the buses' now (2026-09-16): the setting is not copied into `Sfx` any more,
	# it is the SFX and Ambience bus volumes, so that is what is asked.
	_check(
		is_equal_approx(
			AudioServer.get_bus_volume_db(AudioServer.get_bus_index(Prefs.BUS_SFX)),
			Prefs.volume_db(0.42, true, float(Prefs.BUS_TOP[Prefs.BUS_SFX]), Prefs.BUS_SILENT)
		)
		and is_equal_approx(
			AudioServer.get_bus_volume_db(AudioServer.get_bus_index(Prefs.BUS_AMBIENCE)),
			Prefs.volume_db(0.17, true, float(Prefs.BUS_TOP[Prefs.BUS_AMBIENCE]), Prefs.BUS_SILENT)
		),
		"and the buses are set to them", "")
	Prefs.store(&"sfx_level", sfx_was)
	Prefs.store(&"ambience_level", ambience_was)
	settings.pull_prefs()
	_check(is_equal_approx(Prefs.sfx_level, sfx_was)
		and is_equal_approx(Prefs.ambience_level, ambience_was),
		"and the harness gives the player's own levels back", "")
	_check(is_equal_approx(float(_main.get(&"sludge")), sludge_was), "the purse came back",
		"%.0f" % float(_main.get(&"sludge")))
	_check(int(_main.get(&"net_width_level")) == width_was, "the upgrades came back",
		"net width %d" % int(_main.get(&"net_width_level")))
	_check(int(_main.get(&"bird_worth_level")) == birds_was and birds_was > 0,
		"and the market's tracks with them",
		"pigeons %d" % int(_main.get(&"bird_worth_level")))
	_check((_main.get(&"_dogs") as Array).size() == dogs_was and dogs_was >= 2,
		"and the pack", "%d dogs" % (_main.get(&"_dogs") as Array).size())
	_check(_yard.held.size() == yard_was, "the yard came back",
		"%d of %d pieces" % [_yard.held.size(), yard_was])
	_check(_grid.piece_count() == pieces, "the lake came back as it was left",
		"%d of %d pieces" % [_grid.piece_count(), pieces])
	_check((_main.get(&"_boats") as Array).size() == hulls_was, "the fleet came back",
		"%d hulls" % (_main.get(&"_boats") as Array).size())
	_check(float(_main.get(&"pollution")) < 1.0 and float(_main.get(&"pollution")) > 0.0,
		"the meter was re-read from the field",
		"%.5f" % float(_main.get(&"pollution")))
	_advance()


## The market board and the net's two luck tracks (2026-09-13): every track loads; a tier's
## sell track raises that tier's pay and no other; the Recycle Bonus lands on one yard,
## shines there, pays there only and moves on when its window ends; a pigeon is worth its
## track; a lucky haul lifts a tier more and takes more, this cast only; a double cast has a
## second net, a helper, that finds a nearby spot with rubbish on it.
func _stage_market() -> void:
	var tracks: Dictionary = _main.get(&"_upgrades")
	var missing := []
	for key in ["recycle_bonus", "bird_worth", "lucky_haul", "double_cast"]:
		if not tracks.has(StringName(key)):
			missing.append(key)
	_check(missing.is_empty(), "every luck track loads", ", ".join(missing))
	var boards := {}
	for row: Dictionary in _main.call(&"_shop_rows") as Array:
		boards[row["board"]] = int(boards.get(row["board"], 0)) + 1
	# The luck board (2026-09-17): the two per-cast rolls moved off the net's board to stand
	# with the two yard bonuses, so the four boards are 5/4/4/4 instead of 7/4/4/2.
	_check(int(boards.get(&"luck", 0)) == 4, "the luck board has four rows",
		"%d" % int(boards.get(&"luck", 0)))
	_check(int(boards.get(&"net", 0)) == 5, "and the net's board has five",
		"%d" % int(boards.get(&"net", 0)))
	_check(int(boards.get(&"dog", 0)) == 4, "and the dog's board has four",
		"%d" % int(boards.get(&"dog", 0)))
	_check(int(boards.get(&"boat", 0)) == 4, "and the boats' board has four",
		"%d" % int(boards.get(&"boat", 0)))
	_check(not boards.has(&"market"), "and nothing is left on a market board", str(boards.keys()))
	# The cut tracks (2026-09-18, issue #23's scope lock): the skimmer and the five sell-by-tier
	# tracks are out of the game, not hidden in it. Nothing loads them, nothing lists them, and
	# asking to buy one takes nothing.
	var lingering := []
	for key in ["skimmer", "sell_0", "sell_1", "sell_2", "sell_3", "sell_4"]:
		if tracks.has(StringName(key)) or StringName(key) in (_main.get(&"TRACKS") as Array):
			lingering.append(key)
	_check(lingering.is_empty(), "the cut tracks are gone", ", ".join(lingering))
	_main.set(&"sludge", 100000.0)
	var purse_before := float(_main.get(&"sludge"))
	_main.call(&"_buy", &"sell_2")
	_main.call(&"_buy", &"skimmer")
	_check(is_equal_approx(float(_main.get(&"sludge")), purse_before),
		"and asking for one takes nothing", "%.0f" % float(_main.get(&"sludge")))
	# The boats run ahead of the net (2026-09-18, issue #23; supersedes "one track twice"): a
	# ferry holds two casts at every level, and its Hold is the cheaper of the two to buy.
	var hold: UpgradeTrack = tracks[&"net_hold"]
	var cargo: UpgradeTrack = tracks[&"cargo"]
	var ahead := hold.level_cap == cargo.level_cap
	var dearer := ""
	for l in hold.level_cap + 1:
		ahead = ahead and int(cargo.value(l)) >= 2 * int(hold.value(l))
		if l < hold.level_cap and cargo.cost(l) >= hold.cost(l):
			dearer += " %d" % l
	_check(ahead, "a ferry holds two casts at every level of Hold and Catch",
		"%d against %d at the top" % [int(cargo.value(cargo.level_cap)), int(hold.value(hold.level_cap))])
	_check(dearer.is_empty(), "Hold is cheaper than Catch at every level", "dearer at" + dearer)
	var width: UpgradeTrack = tracks[&"net_width"]
	_check(width.value(width.level_cap) <= 4.8 + 0.001 and width.value(0) >= 0.6 - 0.001,
		"the net's width stops at 4.8 tiles (+700%)", "%.2f" % width.value(width.level_cap))
	var caps := []
	for key: StringName in tracks:
		if (tracks[key] as UpgradeTrack).level_cap > 20:
			caps.append(String(key))
	_check(caps.is_empty(), "no track runs past 20 levels", ", ".join(caps))
	# Heavier tiers always pay more (2026-09-14): the cheapest piece of every tier pays over
	# the dearest of the tier below.
	var top_pay := {}
	var low_pay := {}
	for i in _grid.defs.size():
		var def: TrashDef = _grid.defs[i]
		if def.keepsake:
			continue
		var pay := float(_main.call(&"piece_pay", i, -1))
		top_pay[def.tier] = maxf(float(top_pay.get(def.tier, 0.0)), pay)
		low_pay[def.tier] = minf(float(low_pay.get(def.tier, INF)), pay)
	var ordered := true
	for tier in range(1, 5):
		ordered = ordered and float(low_pay.get(tier, INF)) > float(top_pay.get(tier - 1, 0.0))
	_check(ordered, "every piece of a heavier tier pays more than any of the tier below",
		"low %s top %s" % [low_pay, top_pay])

	# The rows read in percents and whole numbers (2026-09-13): no tenths anywhere, the
	# next level in brackets, a small level of its own, and a blurb for the "?".
	var decimals := []
	var no_next := []
	var no_blurb := []
	var no_level := []
	for row: Dictionary in _main.call(&"_shop_rows") as Array:
		var value := String(row["value"])
		if "." in value:
			decimals.append("%s: %s" % [row["key"], value])
		if String(row.get("blurb", "")).is_empty():
			no_blurb.append(String(row["key"]))
		# The level is the bare figure now: it stands in the row's rail, and "Lvl" is a word
		# the row does not need and a translation would have to carry.
		if not String(row.get("level", "")).is_valid_int():
			no_level.append(String(row["key"]))
		if String(row["cost"]) != "Max" and not (" %s " % _main.get(&"ARROW")) in value:
			no_next.append("%s: %s" % [row["key"], value])
	_check(decimals.is_empty(), "no row's value carries a decimal", ", ".join(decimals))
	_check(no_next.is_empty(), "every unmaxed row reads now-arrow-next", ", ".join(no_next))
	_check(no_blurb.is_empty(), "every row has a blurb for its ?", ", ".join(no_blurb))
	_check(no_level.is_empty(), "every row's level is a bare figure", ", ".join(no_level))
	# A scaling track reads as a share of its level 0 (2026-09-17), not as the rise over it:
	# `100 -> 135%`, not `+0% -> +35%`. Without the sign the old basis would have claimed
	# 3.85x where the stat is 4.85x, so the basis and the missing `+` go together.
	var width_row := ""
	for row: Dictionary in _main.call(&"_shop_rows") as Array:
		if row["key"] == &"net_width":
			width_row = String(row["value"])
	_check(width_row.begins_with("100 "), "a scaling track at level 0 reads as 100", width_row)
	_check(width_row.ends_with("%") and not "+" in width_row,
		"and carries one % at the end and no sign", width_row)
	var legend: Dictionary = _main.call(&"_shop_legend")
	_check((legend.get("tiers", []) as Array).is_empty() and (legend.get("yards", []) as Array).size() == 4,
		"the legend lists four yards and no tiers", str(legend))
	var legend_decimals := "." in str(legend.get("tiers", []))
	_check(not legend_decimals, "the legend's tier rates are percents", str(legend.get("tiers", [])))
	# The shop skin: a "?" box in every row's corner, the legend under the ferry's and the
	# dog's boards, inside the table, and the level written small.
	var skin := _main.get_node(^"HUD/ShopSkin")
	skin.set(&"rows", _main.call(&"_shop_rows"))
	skin.set(&"legend", legend)
	skin.call(&"_lay_out")
	var skin_boards: Dictionary = skin.get(&"_boards")
	var legend_box: Rect2 = skin.get(&"_legend_box")
	var table: Rect2 = skin.get(&"_table")
	_check(legend_box.size.y > 0.0, "the legend has room under the boards",
		"table %s boat %s dog %s" % [table, skin_boards.get(&"boat"), skin_boards.get(&"dog")])
	if legend_box.size.y > 0.0:
		var boat_box: Rect2 = skin_boards[&"boat"]
		var dog_box: Rect2 = skin_boards[&"dog"]
		_check(legend_box.position.y >= maxf(boat_box.end.y, dog_box.end.y)
			and legend_box.end.y <= table.end.y + 0.5
			and is_equal_approx(legend_box.position.x, boat_box.position.x)
			and is_equal_approx(legend_box.end.x, dog_box.end.x),
			"and stands under the ferry's and the dog's boards, inside the table",
			"legend %s boat %s dog %s table %s" % [legend_box, boat_box, dog_box, table])
	# The rail (2026-09-17): a column down the left of a row, the "?" answering in its top
	# half and the level's figure standing in its bottom. Both inside the plate, where the
	# old corner tag hung outside it.
	var row_box := Rect2(100.0, 100.0, 300.0, 50.0)
	var rail: Rect2 = skin.call(&"rail_of", row_box)
	_check(is_equal_approx(rail.position.x, row_box.position.x)
		and is_equal_approx(rail.position.y, row_box.position.y)
		and is_equal_approx(rail.size.y, row_box.size.y) and rail.size.x < row_box.size.x * 0.2,
		"the rail runs down the left of a row, inside it", str(rail))
	var help: Rect2 = skin.call(&"help_box_of", row_box)
	_check(is_equal_approx(help.size.x, rail.size.x)
		and is_equal_approx(help.size.y, rail.size.y * 0.5)
		and is_equal_approx(help.position.y, rail.position.y),
		"and the ? answers for its top half only", str(help))
	_check(help.size.x * help.size.y > 15.0 * 15.0,
		"which is a bigger target than the corner tag was", "%.0f px" % (help.size.x * help.size.y))
	var priced := true
	for pair: Array in legend.get("yards", []):
		priced = priced and String(pair[1]).begins_with("$") and not "." in String(pair[1])
	_check(priced, "each material in the legend carries a whole-dollar average", str(legend.get("yards", [])))
	var folded: Array = skin.call(&"_wrap", "one two three four five six seven eight nine ten", 13, 60.0)
	_check(folded.size() > 1, "a blurb wraps onto lines", str(folded))

	_main.set(&"sludge", 100000.0)
	_check(int(_main.call(&"bonus_kind")) < 0, "no yard is boosted before the bonus is bought", "")
	_main.call(&"_buy", &"recycle_bonus")
	var kind := int(_main.call(&"bonus_kind"))
	_check(kind >= 0, "the first level puts the bonus on a yard", "%d" % kind)
	var lit := 0
	var lit_kind := -1
	for stop: Dropoff in _main.get(&"_dropoffs") as Array:
		if stop.boosted:
			lit += 1
			lit_kind = stop.kind
	_check(lit == 1 and lit_kind == kind, "and that yard alone shines", "%d lit, kind %d" % [lit, lit_kind])
	var piece := _def_of(kind)
	var other := (kind + 1) % TrashDef.Kind.size()
	_check(float(_main.call(&"piece_pay", piece, kind)) > float(_main.call(&"piece_pay", piece, other)),
		"a piece sold at the boosted yard pays more than at another", "")
	_main.set(&"_bonus_left", 0.01)
	_main.call(&"_tick_bonus", 0.1)
	_check(int(_main.call(&"bonus_kind")) != kind and int(_main.call(&"bonus_kind")) >= 0,
		"when the window ends the bonus moves to another yard", "%d" % int(_main.call(&"bonus_kind")))
	_check(absf(float(_main.get(&"_bonus_left")) - Lake.BONUS_EVERY) < 0.001,
		"for a fresh window", "%.1f" % float(_main.get(&"_bonus_left")))

	var bird_was := float(_main.call(&"bird_pay"))
	_main.call(&"_buy", &"bird_worth")
	_check(float(_main.call(&"bird_pay")) > bird_was, "a pigeon is worth its track",
		"%.0f from %.0f" % [float(_main.call(&"bird_pay")), bird_was])

	var strength_was := _net.strength()
	var room_was := _net.room_left()
	_net.luck_power = 1
	_net.luck_hold = Lake.LUCKY_EXTRA
	_check(_net.strength() == strength_was + 1 and _net.room_left() == room_was + Lake.LUCKY_EXTRA,
		"a lucky haul lifts a tier more and takes more", "%d, %d" % [_net.strength(), _net.room_left()])
	_net.call(&"_come_home")
	_check(not _net.lucky() and _net.strength() == strength_was, "and is over when the net comes home", "")

	var second: CastNet = _main.get(&"_net2")
	_check(second != null and second.helper and second.state == CastNet.State.IDLE and not second.visible,
		"the double cast's net is a stowed helper", "")
	# With a longer rod than the starting one: at a 3.4-tile throw the neighbourhood of a
	# cast at the edge of the ring is mostly out of range or on the bare shelf, and a double
	# cast that finds nothing there throws nothing — by design, not a failure.
	var range_was := int(_main.get(&"net_range_level"))
	_main.set(&"net_range_level", 8)
	_main.call(&"_push_net_numbers")
	var where := _water_near_angler()
	var spot: Vector2 = _main.call(&"_double_spot", Iso.world_to_tile(where))
	if spot == Vector2.INF:
		var t := Iso.world_to_tile(where)
		var n_reach := 0
		var n_cast := 0
		var n_in := 0
		for ty in range(int(t.y) - 4, int(t.y) + 5):
			for tx in range(int(t.x) - 4, int(t.x) + 5):
				var tile := Vector2(float(tx) + 0.5, float(ty) + 0.5)
				var away := tile.distance_to(t)
				if away > Lake.DOUBLE_NEAR or away < Lake.DOUBLE_APART:
					continue
				n_in += 1
				if _grid.reachable_slot(_grid.index_of(tx, ty), 1, _net.power) >= 0:
					n_reach += 1
				if second.can_cast_to(Iso.tile_to_world(tile.x, tile.y)):
					n_cast += 1
		_log("  double_spot: in %d reach %d cast %d, power %d range %.1f angler %s target %s" % [
			n_in, n_reach, n_cast, _net.power, second.range_tiles, second.angler != null, t])
	_check(spot != Vector2.INF, "a second net finds a spot near the first", "")
	if spot != Vector2.INF:
		var away := spot.distance_to(Iso.world_to_tile(where))
		_check(away <= Lake.DOUBLE_NEAR and away >= Lake.DOUBLE_APART,
			"near it but not on it", "%.2f tiles" % away)
		_check(second.cast_to(Iso.tile_to_world(spot.x, spot.y)) and second.state == CastNet.State.FLYING,
			"and can be thrown there", "")
		second.state = CastNet.State.IDLE
		second.catch.resize(0)
	_main.set(&"net_range_level", range_was)
	_main.call(&"_push_net_numbers")
	_main.set(&"sludge", 0.0)
	_advance()


## The settings panel: its own thing, opened with Esc, and never open at the same time as
## the shed. The logbook lives in it rather than in the shop.
func _stage_settings() -> void:
	var settings := _main.get_node(^"HUD/Settings") as Control
	# The shop is the drawn board and nothing else. The panel of buttons that used to stand
	# behind it — never shown, still formatted every frame — was deleted on 2026-09-20.
	var shop := _main.get_node(^"HUD/ShopSkin") as Control
	_check(not settings.visible, "the settings panel starts closed", "")
	_check(_main.get_node_or_null(^"HUD/Shop") == null,
		"the stock shop panel is gone, not merely hidden", "")
	# The settings are a drawn board (SettingsSkin) now, not a panel of buttons, and saving
	# is automatic: no save or load signal off it. The quit is the one button that writes a
	# save on purpose.
	_check(not settings.has_signal(&"save_pressed") and not settings.has_signal(&"load_pressed")
		and settings.has_signal(&"quit_pressed"),
		"saving is automatic: no save or load button anywhere", "")

	_press_escape()
	_check(settings.visible, "escape opens the settings", "")
	_check(not _angler.can_walk, "the angler stays put while it is open", "")
	_press_escape()
	_check(not settings.visible, "escape closes it again", "")
	_check(_angler.can_walk, "and the angler is free again", "")

	# And the pad's own reading of the same press does not answer it a second time
	# (2026-09-16). `open_settings` holds Escape as well as Start, and
	# `Input.is_action_just_pressed` cannot tell which device pressed it — so the pad tick
	# used to open the board that the keyboard had just opened, and shut it in the same
	# frame. Escape looked dead. The tick is pad-mode only for that reason; here it is run
	# by hand in mouse mode, which is when a keyboard press arrives.
	var hand := get_node(^"/root/Pad")
	hand.call(&"set_mode", 0)
	_press_escape()
	_main.call(&"_pad_tick", 0.016)
	_check(settings.visible, "and the pad tick does not answer the same press", "")
	_press_escape()
	_main.call(&"_pad_tick", 0.016)
	_check(not settings.visible, "nor the press that closes it", "")

	# The shed and the settings are one screen or the other, never both.
	_main.call(&"_set_settings", true)
	_main.call(&"_set_menu", true)
	_check(shop.visible and not settings.visible,
		"opening the shed puts the settings away", "")
	_press_escape()
	_check(not shop.visible and not settings.visible,
		"escape backs out of the shed first", "")
	var mode := DisplayServer.window_get_mode()
	var really_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	_check(Prefs.is_fullscreen() == really_full,
		"the window row reads the real window", "")
	_check((Prefs.live_window_mode() == Prefs.WindowMode.WINDOWED) != really_full,
		"and names it as one of the three modes", "")

	_check_buses()
	_check_display(settings)
	_check_binds()

	# The built border has no hole down the inside of its walls. The stiles are the foot plank
	# turned on its side, a row narrower than the wall is wide, and the cut used to leave that
	# row empty — a one-pixel line of the lake down both inner edges of every menu board.
	var StyleScript := preload("res://scripts/style.gd")
	var frame: ImageTexture = StyleScript._build_border(Vector2i(200, 160))
	if frame != null:
		var pic := frame.get_image()
		var holes := 0
		var inner := Rect2i(
			StyleScript.BORDER_WALL - 1, StyleScript.BORDER_TOP,
			200 - StyleScript.BORDER_WALL * 2 + 2, 160 - StyleScript.BORDER_TOP - StyleScript.BORDER_FOOT
		)
		for y in range(inner.position.y, inner.end.y):
			for x: int in [inner.position.x, inner.end.x - 1]:
				if pic.get_pixel(x, y).a < 0.5:
					holes += 1
		_check(holes == 0, "a built border's walls have no see-through column on the inside",
			"%d holes" % holes)
		# And a ribbon's plank ends where the board's face begins, so nothing of the frame is
		# left showing under the bites along its foot.
		var ribbon := Rect2(0.0, 100.0, 300.0, 36.0)
		var wood: Rect2 = StyleScript.ribbon_plank(ribbon)
		_check(is_equal_approx(wood.end.y, 118.0 + float(StyleScript.BORDER_TOP)),
			"a ribbon's plank ends where the board's face begins", "ends at %.1f" % wood.end.y)

	# The sounds (2026-09-15): the board is the autoload, every recording it names has a file
	# behind it, the beds loop, and the lake's ambience is wanted and goes under in the shed.
	var sound := Sfx.main()
	_check(sound != null, "the sound board is the Sound autoload", "")
	if sound != null:
		var missing := PackedStringArray()
		for name: StringName in Sfx.SOUNDS:
			if (sound._streams.get(name, []) as Array).is_empty():
				missing.append(String(name))
		_check(missing.is_empty(), "every recording the sound board names is loaded",
			", ".join(missing))
		_check((sound._streams[&"step_sand"] as Array).size() > 3
			and (sound._streams[&"bark"] as Array).size() == 2
			and (sound._streams[&"sniff"] as Array).size() == 3,
			"steps, barks and sniffs come in their numbered variants", "")
		var unlooped := PackedStringArray()
		for name: StringName in Sfx.BEDS:
			var ogg := sound._first(name) as AudioStreamOggVorbis
			var wav := sound._first(name) as AudioStreamWAV
			var loops := (
				(ogg != null and ogg.loop)
				or (wav != null and wav.loop_mode == AudioStreamWAV.LOOP_FORWARD and wav.loop_end > 0)
			)
			if not loops:
				unlooped.append(String(name))
		_check(unlooped.is_empty(), "every bed is set to loop, wave file or ogg",
			", ".join(unlooped))
		_check(sound._ambience_on and not sound._ambience_duck, "the lake's ambience is wanted", "")
		_main.call(&"_set_shed", true)
		_check(sound._ambience_duck, "and goes under while the shed is open", "")
		_main.call(&"_set_shed", false)
		_check(not sound._ambience_duck, "and comes back when it closes", "")
	_advance()


## The mix is four audio buses (2026-09-16, issue #26), and every voice is on one of them:
## the sliders have one place to be, which is what a Master slider needed.
func _check_buses() -> void:
	var missing := PackedStringArray()
	for bus: StringName in [Prefs.BUS_MASTER, Prefs.BUS_MUSIC, Prefs.BUS_SFX, Prefs.BUS_AMBIENCE]:
		if AudioServer.get_bus_index(bus) == -1:
			missing.append(String(bus))
	_check(missing.is_empty(), "the four audio buses are there", ", ".join(missing))
	if not missing.is_empty():
		return
	var sent := PackedStringArray()
	for bus: StringName in [Prefs.BUS_MUSIC, Prefs.BUS_SFX, Prefs.BUS_AMBIENCE]:
		if AudioServer.get_bus_send(AudioServer.get_bus_index(bus)) != Prefs.BUS_MASTER:
			sent.append(String(bus))
	_check(sent.is_empty(), "and the three go through Master", ", ".join(sent))

	# Master at the top of its travel is 0 dB: a player who never touches it hears the mix
	# exactly as it was tuned by ear before the buses existed.
	_check(
		is_equal_approx(
			Prefs.volume_db(1.0, true, float(Prefs.BUS_TOP[Prefs.BUS_MASTER]), Prefs.BUS_SILENT),
			0.0
		),
		"a full Master slider changes nothing", ""
	)
	# And a slider at its floor mutes rather than whispers.
	var was_level := Prefs.master_level
	Prefs.preview(&"master_level", 0.0)
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index(Prefs.BUS_MASTER)),
		"a slider at the floor mutes its bus", "")
	Prefs.preview(&"master_level", was_level)
	_check(not AudioServer.is_bus_mute(AudioServer.get_bus_index(Prefs.BUS_MASTER)),
		"and comes back off the floor", "")

	var sound := Sfx.main()
	if sound != null:
		var off := PackedStringArray()
		for child in sound.get_children():
			var voice := child as AudioStreamPlayer
			if voice == null:
				continue
			if not (voice.bus in [Prefs.BUS_SFX, Prefs.BUS_AMBIENCE]):
				off.append(voice.bus)
		_check(off.is_empty(), "every lake voice is on the SFX or Ambience bus", ", ".join(off))
	var music := MusicStation.main()
	if music != null:
		var stray := 0
		for child in music.get_children():
			var song := child as AudioStreamPlayer
			if song != null and song.bus != Prefs.BUS_MUSIC:
				stray += 1
		_check(stray == 0, "and every song is on the Music bus", "%d elsewhere" % stray)


## The display rows: what each is worth, and the two rules that keep them safe — the
## resolution is windowed-only, and nothing offered is smaller than the boards need.
func _check_display(settings: Node) -> void:
	var caps: Array = settings.call(&"_choices_of", &"fps_cap")
	_check(caps.size() >= 4 and int(caps[0]) == 0,
		"the frame cap offers uncapped and a few steps", "%d steps" % caps.size())
	_check(String(settings.call(&"_choice_text", &"fps_cap", 0)) == "Uncapped"
		and String(settings.call(&"_choice_text", &"fps_cap", 60)) == "60",
		"and reads in whole frames", "")
	var modes: Array = settings.call(&"_choices_of", &"window_mode")
	_check(modes.size() == 3, "the window row offers three modes", "%d" % modes.size())
	var small := 0
	for size: Vector2i in Prefs.window_sizes():
		if size.x < Prefs.LEAST_WINDOW.x or size.y < Prefs.LEAST_WINDOW.y:
			small += 1
	_check(small == 0, "no window size is smaller than the boards need", "%d too small" % small)

	# Windowed: the resolution row is live and reads what is stored. In either fullscreen it
	# is dead and reads the monitor's own size, so picking one can never hand a screen a mode
	# it will not show.
	var live: bool = settings.call(&"_screen_row_live", &"window_size")
	_check(live == (Prefs.live_window_mode() == Prefs.WindowMode.WINDOWED),
		"the resolution row is live in a window and dead in fullscreen", "")
	_check(bool(settings.call(&"_screen_row_live", &"window_mode")),
		"the window row itself is always live", "")

	# The safeguard: only exclusive asks, and nothing answering puts it back.
	_check(settings.has_method(&"_try_window_mode") and SettingsSkin.REVERT_AFTER > 0.0,
		"an exclusive fullscreen asks to be kept", "%.0f s" % SettingsSkin.REVERT_AFTER)


## The bind table: the defaults are physical, a swap leaves nothing unbound, a context is
## allowed to share a button, and what is written down comes back.
func _check_binds() -> void:
	var was_walk := Binds.bound(&"walk_up", "key")
	var was_cast := Binds.bound(&"cast", "key")
	_check(was_walk == "key:%d" % KEY_W,
		"walking up is bound to the hole W sits in", was_walk)
	_check(not Binds.label_of(was_walk).is_empty()
		and Binds.label_of(was_walk) == Binds.key_name(KEY_W),
		"and is named by what this keyboard prints on it", Binds.label_of(was_walk))

	var found := false
	for event: InputEvent in InputMap.action_get_events(&"walk_up"):
		var key := event as InputEventKey
		if key != null and key.physical_keycode == KEY_W and key.keycode == KEY_NONE:
			found = true
	_check(found, "the input map holds it as a physical key, not a letter", "")

	# A swap: whatever held the key takes the one being given up, so nothing is left bare.
	var swapped: StringName = Binds.bind(&"walk_up", "key", was_cast)
	_check(swapped == &"cast", "binding a key another verb holds swaps the two", String(swapped))
	_check(Binds.bound(&"cast", "key") == was_walk and Binds.bound(&"walk_up", "key") == was_cast,
		"and the other verb keeps what this one had", "")
	Binds.restore(&"walk_up", "key")
	Binds.restore(&"cast", "key")
	_check(Binds.bound(&"walk_up", "key") == was_walk and Binds.bound(&"cast", "key") == was_cast,
		"a restored cell is the table's own binding again", "")

	# Two contexts may share a button: X opens the shed out there and turns a piece in here.
	_check(Binds.bound(&"open_shed", "pad") == Binds.bound(&"shed_rotate", "pad"),
		"the lake and the shed share a pad button by design", "")
	_check(Binds.holder_of(&"open_shed", "pad", Binds.bound(&"shed_rotate", "pad")) == &"",
		"and that is not counted as a clash", "")
	_check(
		Binds.holder_of(&"open_shed", "pad", Binds.bound(&"open_upgrades", "pad"))
			== &"open_upgrades",
		"while two verbs of one context are", ""
	)

	# Escape is never captured: it is what cancels a capture.
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	_check(not Binds.bindable(escape, "key"), "escape cannot be bound to anything", "")
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 1.0
	_check(not Binds.bindable(stick, "pad"), "and a stick cannot be bound either", "")
	var trigger := InputEventJoypadMotion.new()
	trigger.axis = JOY_AXIS_TRIGGER_RIGHT
	trigger.axis_value = 1.0
	_check(Binds.bindable(trigger, "pad"), "a trigger can", "")

	# Written down and read back: the overrides survive the file, and a row for an action that
	# no longer exists is dropped rather than refusing the lot.
	Binds.bind(&"open_shed", "key", "key:%d" % KEY_J)
	var cfg := ConfigFile.new()
	Binds.save_to(cfg)
	cfg.set_value(Binds.SECTION, "a_verb_we_deleted.key", "key:70")
	Binds.load_from(cfg)
	_check(Binds.bound(&"open_shed", "key") == "key:%d" % KEY_J,
		"a rebound key comes back out of the settings file", Binds.bound(&"open_shed", "key"))
	Binds.reset()
	_check(
		not Binds.changed()
			and Binds.bound(&"open_shed", "key") == String(Binds.row_of(&"open_shed")["key"]),
		"and the reset puts every row back", ""
	)


## The ferry's art: one baked frame per heading, and the right one picked for each.
func _stage_ferry_art() -> void:
	var sheet: Texture2D = _boat.call(&"_sheet")
	_check(sheet != null, "the ferry has a sheet of headings", "")
	if sheet == null:
		_advance()
		return
	var frames := int(_boat.call(&"_frame_count"))
	_check(frames >= 8 and sheet.get_width() == sheet.get_height() * frames,
		"it is one row of square frames", "%d frames of %d px" % [frames, sheet.get_height()])

	# The sheet's first frame is the boat coming at the camera: down the screen, which on
	# the plane is the tile diagonal (1, 1).
	_boat.heading = Vector2(1.0, 1.0)
	_check(int(_boat.call(&"heading_frame")) == 0,
		"the first frame is the boat coming towards the camera", "")
	# A quarter turn on: the sheet's side view, pointing left across the screen.
	_boat.heading = Vector2(-1.0, 1.0)
	_check(int(_boat.call(&"heading_frame")) == frames / 4,
		"and a quarter turn on it is drawn side on, pointing left",
		"frame %d" % int(_boat.call(&"heading_frame")))

	# Turning right round comes back to where it started, and opposite headings are
	# opposite frames.
	var wrong := 0
	var out_of_range := 0
	for i in frames * 2:
		var angle := TAU * float(i) / float(frames)
		_boat.heading = Vector2(cos(angle), sin(angle))
		var frame := int(_boat.call(&"heading_frame"))
		if frame < 0 or frame >= frames:
			out_of_range += 1
		_boat.heading = -_boat.heading
		var opposite := int(_boat.call(&"heading_frame"))
		if posmod(opposite - frame, frames) != frames / 2:
			wrong += 1
	_check(out_of_range == 0, "every heading picks a frame that exists",
		"%d did not" % out_of_range)
	_check(wrong == 0, "and a boat turned about faces the other way",
		"%d headings did not" % wrong)

	# The hull points where it is going: the screen heading is the tile heading seen
	# through the same projection as everything else.
	_boat.heading = Vector2(1.0, 0.0)
	var on_screen: Vector2 = _boat.call(&"_screen_heading")
	_check(on_screen.x > 0.0 and on_screen.y > 0.0,
		"a ferry running east is drawn heading down and right",
		"%.2f, %.2f" % [on_screen.x, on_screen.y])
	_boat.heading = Vector2(0.0, 1.0)
	on_screen = _boat.call(&"_screen_heading")
	_check(on_screen.x < 0.0 and on_screen.y > 0.0,
		"and one running south is drawn heading down and left",
		"%.2f, %.2f" % [on_screen.x, on_screen.y])

	# The load has to sit in the hold at every heading. Laying it out in screen offsets
	# instead of in tiles floats half of it off the side of a boat running north.
	var strays := 0
	var worst_heading := Vector2.ZERO
	for i in 24:
		var turn := TAU * float(i) / 24.0
		_boat.heading = Vector2(cos(turn), sin(turn))
		var along: Vector2 = _boat.call(&"_screen_heading")
		var across := Vector2(-along.y, along.x)
		for slot in Boat.HOLD_SHOWN:
			var spot: Vector2 = _boat.hold_spot(slot, Boat.HOLD_SHOWN)
			spot.y += Boat.HULL_HEIGHT * Boat.HOLD_LIFT
			if absf(spot.dot(along)) > Boat.HULL_LENGTH * 0.5 					or absf(spot.dot(across)) > Boat.HULL_WIDTH * 0.5:
				strays += 1
				worst_heading = _boat.heading
	_check(strays == 0, "the load stays inside the hull at every heading",
		"%d slots stray, worst at %s" % [strays, str(worst_heading)])
	_advance()


## The art: a catalogue that fits its sheets, an atlas built from it, every def pointed at
## a picture, and the anchor still surviving the trip through the vertex colour.
## The run cycles hold no idle frame (every strip opened on one), and every pose is
## registered so its lowest foot row lands on the ground line its shadow folds from.
func _stage_angler_sheet() -> void:
	var poses: Dictionary = _angler.get(&"_poses")
	var sheet: Texture2D = _angler.get(&"_sheet")
	if poses.is_empty() or sheet == null:
		_check(false, "the angler's sheet loaded", "no poses")
		return
	var image := sheet.get_image()
	var idle_like := 0
	for dir in ["south", "north", "east", "west"]:
		for run: Dictionary in poses.get(StringName("run_" + dir), []):
			for idle: Dictionary in poses.get(StringName("idle_" + dir), []):
				if _same_ink(image, run, idle):
					idle_like += 1
	_check(idle_like == 0, "no run frame is an idle frame", "%d are" % idle_like)
	# Nor a legs-together one: the two south frames dropped after the copy differed from the
	# nearest idle by 336 and 423 pixels, every kept one by 520 or more. Side views overlap
	# their legs by nature and sit closer, so only south is held to it.
	var nearest := INF
	for run: Dictionary in poses.get(&"run_south", []):
		for idle: Dictionary in poses.get(&"idle_south", []):
			nearest = minf(nearest, float(_ink_distance(image, run, idle)))
	_check(nearest > 470.0, "no south run frame stands like the idle",
		"nearest differs by %d pixels" % int(nearest))
	var foot_of: Dictionary = _angler.get(&"_foot_of")
	var off := 0
	for pose: StringName in poses:
		var lowest := 0.0
		for f: Dictionary in poses[pose]:
			var ink: Rect2 = f["ink"]
			lowest = maxf(lowest, ink.end.y)
		if not is_equal_approx(lowest, float(foot_of.get(pose, -1.0))):
			off += 1
	_check(off == 0, "every pose stands on its own lowest foot row", "%d do not" % off)


## Pixels that differ between two frames' ink, stood on the same feet and centred across.
func _ink_distance(image: Image, a: Dictionary, b: Dictionary) -> int:
	var ra: Rect2 = a["region"]
	var rb: Rect2 = b["region"]
	var ia: Rect2 = a["ink"]
	var ib: Rect2 = b["ink"]
	var w := int(maxf(ia.size.x, ib.size.x))
	var h := int(maxf(ia.size.y, ib.size.y))
	var count := 0
	for y in h:
		for x in w:
			var ca := _ink_at(image, ra, ia, x - (w - int(ia.size.x)) / 2, y - (h - int(ia.size.y)))
			var cb := _ink_at(image, rb, ib, x - (w - int(ib.size.x)) / 2, y - (h - int(ib.size.y)))
			if maxf(maxf(absf(ca.r - cb.r), absf(ca.g - cb.g)), maxf(absf(ca.b - cb.b), absf(ca.a - cb.a))) > 40.0 / 255.0:
				count += 1
	return count


func _ink_at(image: Image, region: Rect2, ink: Rect2, x: int, y: int) -> Color:
	if x < 0 or y < 0 or x >= int(ink.size.x) or y >= int(ink.size.y):
		return Color(0.0, 0.0, 0.0, 0.0)
	return image.get_pixel(int(region.position.x + ink.position.x) + x, int(region.position.y + ink.position.y) + y)


func _same_ink(image: Image, a: Dictionary, b: Dictionary) -> bool:
	var ra: Rect2 = a["region"]
	var rb: Rect2 = b["region"]
	var ia: Rect2 = a["ink"]
	var ib: Rect2 = b["ink"]
	if ia.size != ib.size:
		return false
	for y in int(ia.size.y):
		for x in int(ia.size.x):
			var ca := image.get_pixel(int(ra.position.x + ia.position.x) + x, int(ra.position.y + ia.position.y) + y)
			var cb := image.get_pixel(int(rb.position.x + ib.position.x) + x, int(rb.position.y + ib.position.y) + y)
			if absf(ca.a - cb.a) > 0.15 or (ca.a > 0.5 and absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.15):
				return false
	return true


func _stage_art() -> void:
	var sheets: Sheets = _main.get(&"_sheets")
	_check(sheets != null and sheets.atlas != null, "the sheets were cut and welded",
		"%d pieces" % (sheets.regions.size() if sheets != null else 0))
	if sheets == null:
		_advance()
		return

	_stage_angler_sheet()

	var atlas_size := sheets.atlas.get_size()
	var outside := 0
	for name: String in sheets.names:
		var box: Rect2 = sheets.regions[name]
		if box.position.x < 0.0 or box.position.y < 0.0 \
				or box.end.x > float(atlas_size.x) or box.end.y > float(atlas_size.y):
			outside += 1
	_check(outside == 0, "every region lies inside the atlas", "%d do not" % outside)

	# Counted by name rather than by def: a find with several copies has a def each, and
	# what has to match the planting is how many distinct finds there are.
	var undressed := 0
	var keepsake_names := {}
	for def: TrashDef in _grid.defs:
		if String(def.piece).is_empty() or def.atlas == null:
			undressed += 1
		if def.keepsake:
			keepsake_names[String(def.piece)] = true
	var keepsakes := keepsake_names.size()
	_check(undressed == 0, "every def is pointed at a picture",
		"%d are not" % undressed)
	_check(keepsakes > 0, "there are finds to find", "%d of them" % keepsakes)
	_check(not keepsake_names.has(Lake.STARTER_BED),
		"the house's own bed is not in the lake", "")

	# Where they lie: one pet bed afloat in the first band past the shelf, the early finds
	# within EARLY_OUT under nothing heavier than themselves, the rest banded by tier.
	var first_tile := -1
	var lie: Array[Vector2] = []
	var laid := {}
	var near := Iso.SHELF_TILES + Iso.SHELF_CLEAR
	var misplaced := 0
	var blocked := 0
	var banded := [0, 0, 0]
	for index in _grid.stacks.size():
		var stack: PackedInt32Array = _grid.stacks[index]
		for k in stack.size():
			var def: TrashDef = _grid.defs[stack[k]]
			if not def.keepsake:
				continue
			laid[def.piece] = int(laid.get(def.piece, 0)) + 1
			var away := Iso.past_shelf(Vector2(_grid.tile_of(index)))
			if def.piece == Lake.FIRST_FIND and k == stack.size() - 1 					and away <= near + Lake.FIRST_FIND_OUT:
				first_tile = index
				continue
			lie.append(Vector2(_grid.tile_of(index)))
			banded[0 if Lake.EARLY_FINDS.has(def.piece) else (2 if def.tier >= Lake.LATE_TIER else 1)] += 1
			if Lake.EARLY_FINDS.has(def.piece):
				if away > Lake.EARLY_OUT or def.tier > 1:
					misplaced += 1
				for above in range(k + 1, stack.size()):
					if (_grid.defs[stack[above]] as TrashDef).tier > def.tier:
						blocked += 1
			elif def.tier >= Lake.LATE_TIER:
				if away < Lake.MID_OUT:
					misplaced += 1
			elif away < Lake.EARLY_OUT or away > Lake.MID_OUT:
				misplaced += 1
	_check(misplaced <= 2, "every find lies in its band (the darts' fallback aside)",
		"%d outside; early/mid/late %s" % [misplaced, str(banded)])
	_check(blocked == 0, "no early find lies under something heavier than itself",
		"%d do" % blocked)
	_check(int(laid.get(&"decor_pet_bed", 0)) == 2 and int(laid.get(&"decor_chew_toy", 0)) == 2,
		"two pet beds and two chew toys are in the lake", str(laid.get(&"decor_pet_bed", 0)))
	_check(first_tile >= 0, "a pet bed floats on top by the island", "")
	if first_tile >= 0:
		var out := Iso.past_shelf(Vector2(_grid.tile_of(first_tile)))
		_check(out >= near and out <= near + Lake.FIRST_FIND_OUT,
			"the pet bed floats just past the island's shelf", "%.1f tiles out" % out)
		# A new game's net: power 0, throw at level 0. The bed has to be both.
		var top_def: TrashDef = _grid.defs[_grid.stacks[first_tile][_grid.stacks[first_tile].size() - 1]]
		_check(top_def.tier <= _main.net_power(),
			"the pet bed is light enough for the first net",
			"tier %d against power %d" % [top_def.tier, _main.net_power()])
		_check(out <= _main.net_range(),
			"the pet bed is inside the first net's throw",
			"%.1f tiles out, %.1f tiles of throw" % [out, _main.net_range()])
	var crowded := 0
	for i in lie.size():
		for j in range(i + 1, lie.size()):
			if lie[i].distance_to(lie[j]) < Lake.FIND_APART:
				crowded += 1
	_check(crowded <= 2, "the finds are dealt apart from each other",
		"%d pairs closer than %.0f tiles" % [crowded, Lake.FIND_APART])

	# Proportion: a bed is bigger than a mug in the lake too, not normalised to it. The
	# finds and the rubbish are two scales now (Lake.FIND_SHRINK), so the size order is
	# asked of each on its own.
	var smallest := 1e9
	var largest := 0.0
	var biggest_art := {false: 0.0, true: 0.0}
	var biggest_drawn := {false: 0.0, true: 0.0}
	var largest_of := {false: 0.0, true: 0.0}
	for def: TrashDef in _grid.defs:
		var longest := maxf(def.size.x, def.size.y)
		smallest = minf(smallest, longest)
		largest = maxf(largest, longest)
		largest_of[def.keepsake] = maxf(float(largest_of[def.keepsake]), longest)
		var art := maxf(def.region.size.x, def.region.size.y)
		if art > float(biggest_art[def.keepsake]):
			biggest_art[def.keepsake] = art
			biggest_drawn[def.keepsake] = longest
	_check(largest > smallest * 2.0, "the big things are drawn bigger than the small ones",
		"%.0f px against %.0f px" % [largest, smallest])
	_check(is_equal_approx(float(biggest_drawn[false]), float(largest_of[false])),
		"and the biggest rubbish picture is the biggest rubbish on the water", "")
	_check(is_equal_approx(float(biggest_drawn[true]), float(largest_of[true])),
		"and the biggest find picture is the biggest find on the water", "")

	# The batch is still one call, and it is textured now.
	_check(_grid.atlas_rid().is_valid(), "the lake surface draws from the atlas", "")

	# Regions are the cut itself: two that overlap are two items sharing pixels, which is
	# the failure the slicer went through three attempts to stop doing.
	var overlaps := 0
	for i in sheets.names.size():
		for j in range(i + 1, sheets.names.size()):
			var a: Rect2 = sheets.regions[sheets.names[i]]
			var b: Rect2 = sheets.regions[sheets.names[j]]
			if a.intersects(b):
				overlaps += 1
	_check(overlaps == 0, "no two pieces were cut out of the same pixels",
		"%d pairs overlap" % overlaps)

	# The hut's collision is its drawing. Iso.SHED_FOOT and Iso.SHED_ART_GROUND are both
	# measured off shed.png by hand, so nothing but this stops a re-cut of the hut leaving the
	# walking rule on the old building: a walker stopped short of one wall and standing inside
	# the opposite one. Measured here the same way they were: the walls' feet are a
	# parallelogram, and its left and right corners are the lowest row of the outermost columns
	# that reach the ground band (the eaves overhang far higher up and are not it).
	var hut := Art.image("res://assets/shed.png")
	if hut != null:
		var rows := PackedInt32Array()
		var deep := -1
		for column in hut.get_width():
			var low := -1
			for row in range(hut.get_height() - 1, -1, -1):
				if hut.get_pixel(column, row).a > 0.0:
					low = row
					break
			rows.append(low)
			deep = maxi(deep, low)
		var band := deep - int(float(hut.get_height()) * 0.3)
		var left := -1
		var right := -1
		for column in rows.size():
			if rows[column] < band:
				continue
			if left < 0:
				left = column
			right = column
		var scale := Iso.SHED_TALL / float(hut.get_height())
		var mid := Vector2(
			float(left + right) * 0.5, float(rows[left] + rows[right]) * 0.5
		)
		# The right corner off the middle, in tiles: a rectangle's corner is (+x, -y) there.
		var corner := Iso.world_to_tile(
			(Vector2(float(right), float(rows[right])) - mid) * scale
		)
		_check(
			absf(corner.x - Iso.SHED_FOOT.x) < 0.1 and absf(-corner.y - Iso.SHED_FOOT.y) < 0.1,
			"the hut's footprint is the size the hut is drawn",
			"%.2f x %.2f tiles drawn against %s" % [corner.x, -corner.y, str(Iso.SHED_FOOT)]
		)
		# (The deepest row is the one-pixel outline recolor_shed.py rings the hut with; the
		# walls end the row above it, so `deep` is used where it used to be `deep + 1`.)
		# And it is in the same place: the near corner of those walls, straight off the
		# picture, against the line the walking rule stops at.
		var stands := Iso.shed_centre()
		var drawn := Iso.tile_to_world(stands.x, stands.y).y 			+ (float(deep) - float(hut.get_height()) * (1.0 - Iso.SHED_ART_GROUND)) * scale
		var front: float = _main.call(&"_shed_front")
		_check(absf(drawn - front) < 2.0,
			"and its near wall is where the walking rule says it is",
			"%.1f px drawn against %.1f px walked" % [drawn, front])

		# Anything the picture covers and stands north of is drawn behind it. The sideways
		# limit used to be the footprint's width rather than the roof's, so a walker out past
		# the wall's corner but still under the eaves was drawn over the hut.
		var wide: float = _main.call(&"_shed_drawn_wide")
		var stood := Iso.tile_to_world(stands.x, stands.y)
		var under := Vector2(stood.x + wide * 0.45, stood.y - Iso.SHED_TALL * 0.25)
		_check(int(_main.call(&"_walker_layer", under)) == Lake.BEHIND_SHED,
			"under the hut's eaves is behind the hut", str(under))
		# And standing clear to the south of it is not. Asked as "not behind the hut" rather
		# than "in front of everything": the crate is parked straight down the screen from
		# the hut, so a point due south of one is at the other.
		var out_front := Vector2(stood.x - wide * 0.3, front + Iso.TILE_H * 2.0)
		_check(int(_main.call(&"_walker_layer", out_front)) != Lake.BEHIND_SHED,
			"and standing in front of it is not behind it", str(out_front))

	# Every visible piece is one quad and nothing else: the pale plate that used to be
	# drawn under each one read as a grey square behind every object in the lake. The one
	# thing a tile carries besides is the rim's room, on the tiles with a find in them
	# (LakeGrid.RIM_VERTS, 2026-09-13) — and only on those.
	var verts: PackedVector2Array = _grid.get(&"_mesh_points")
	var slot_base: PackedInt32Array = _grid.get(&"_slot_base")
	var rimmed := 0
	for i in slot_base.size():
		if slot_base[i] >= 0 and bool(_grid.call(&"_holds_find", i)):
			rimmed += 1
	_check(rimmed > 0, "some drawn tiles hold a find", str(rimmed))
	_check(verts.size() == _grid.drawn_pieces * 4 + rimmed * LakeGrid.RIM_VERTS,
		"a piece of rubbish is its picture and nothing else, plus a rim's room over a find",
		"%d corners for %d pieces, %d with a find" % [verts.size(), _grid.drawn_pieces, rimmed])

	# And no two of them lie the same way.
	var turns := {}
	var sizes := {}
	var mirrored := 0
	var poses := 0
	for index in _grid.tile_count():
		if _grid.stacks[index].is_empty():
			continue
		poses += 1
		turns[snappedf(_grid.tilt[index], 0.05)] = true
		sizes[snappedf(_grid.swing[index], 0.05)] = true
		mirrored += int(_grid.facing[index])
	_check(turns.size() > 8 and sizes.size() > 4,
		"the rubbish lies every which way",
		"%d angles, %d sizes over %d tiles" % [turns.size(), sizes.size(), poses])
	_check(mirrored > poses / 4 and mirrored < poses * 3 / 4,
		"and about half of it faces the other way",
		"%d of %d" % [mirrored, poses])

	# The packing the bob shader reads back out.
	var worst := 0.0
	for sample: float in [-3000.0, -12.5, 0.0, 47.25, 2944.0]:
		var packed := LakeGrid.pack_anchor(sample, 1.0, 1.0)
		worst = maxf(worst, absf(LakeGrid.unpack_anchor_x(packed) - sample))
	_check(worst < 0.2, "the anchor survives the vertex colour",
		"%.3f px at worst" % worst)

	# Every find planted in the water as many times as the catalogue asks for, and none of
	# them on offer to a sweep that is told to leave finds alone.
	#
	# It used to be one of each, flat. The chairs come four to a set now — a dining table
	# with one chair at it is not a room anybody lives in — so the number to expect is the
	# catalogue's, per name, and "one" is only still the answer for everything else.
	var counts := {}
	var keepsake_tile := -1
	var keepsake_slot := -1
	for index in _grid.tile_count():
		for k in _grid.stacks[index].size():
			var def := _grid.defs[_grid.stacks[index][k]]
			if not def.keepsake:
				continue
			counts[String(def.piece)] = int(counts.get(String(def.piece), 0)) + 1
			keepsake_tile = index
			keepsake_slot = k
	var miscounted := ""
	for name: String in counts:
		var wanted := sheets.copies_of(StringName(name))
		if int(counts[name]) != wanted:
			miscounted = "%s: %d planted, %d wanted" % [name, int(counts[name]), wanted]
			break
	var planted := 0
	for name: String in counts:
		planted += int(counts[name])
	_check(counts.size() == keepsakes and miscounted.is_empty(),
		"every find is hidden in the lake as many times as the catalogue asks",
		"%d names, %d planted%s" % [
			counts.size(), planted,
			"" if miscounted.is_empty() else " — " + miscounted
		])

	if keepsake_tile >= 0:
		# Dig straight to it with a net strong enough for anything, then ask again with the
		# finds ruled out. That sweep must come away with nothing.
		var depth := _grid.stacks[keepsake_tile].size()
		_check(_grid.reachable_slot(keepsake_tile, depth, 9) >= 0,
			"the net can reach a find", "")
		var to_boat := _grid.reachable_slot(keepsake_tile, depth, 9, -1, false)
		var boat_got_one := false
		if to_boat >= 0:
			boat_got_one = _grid.defs[_grid.stacks[keepsake_tile][to_boat]].keepsake
		_check(not boat_got_one, "a sweep with the finds ruled out leaves them alone", "")
	_advance()


## The shed: a find is kept rather than sold, and the room it goes in.
func _stage_shed() -> void:
	var room: ShedRoom = _main.get_node(^"HUD/Shed/Pad/Lines/Room")
	var sheets: Sheets = _main.get(&"_sheets")
	var find: TrashDef = null
	var find_index := -1
	for i in _grid.defs.size():
		if _grid.defs[i].keepsake:
			find = _grid.defs[i]
			find_index = i
			break
	if find == null or sheets == null:
		_check(false, "there is a find to test with", "")
		_advance()
		return

	# Landing one is what keeps it, and it must not reach the pile or a merchant.
	#
	# Kept at the pump, not on the shelf (issue #37): a find is washed before the shed will
	# have it, and the soap is paid for when it comes clean.
	var unlocked: Array = _main.get(&"unlocked")
	var unwashed: Array = _main.get(&"unwashed")
	unlocked.clear()
	unwashed.clear()
	_yard.held.resize(0)
	_main.call(&"_on_net_landed", PackedInt32Array([find_index, find_index]))
	_check(unwashed.size() == 1 and String(unwashed[0]) == String(find.piece),
		"a find is kept, once, however many turn up",
		"%d kept" % unwashed.size())
	_check(unlocked.is_empty(), "and it waits at the pump, not on the shed's shelf",
		"%d on the shelf" % unlocked.size())
	var purse_was: float = _main.get(&"sludge")
	_main.set(&"sludge", 40.0)
	_main.call(&"_on_find_washed", StringName(find.piece), 15)
	_check(unwashed.is_empty() and unlocked.size() == 1
		and String(unlocked[0]) == String(find.piece),
		"washed, it goes on the shelf and leaves the pump",
		"%d waiting, %d on the shelf" % [unwashed.size(), unlocked.size()])
	_check(is_equal_approx(float(_main.get(&"sludge")), 25.0),
		"and the soap is paid for when it comes clean", "%.0f left of 40" % float(_main.get(&"sludge")))
	_main.call(&"_on_find_washed", StringName(find.piece), 15)
	_check(unlocked.size() == 1 and is_equal_approx(float(_main.get(&"sludge")), 25.0),
		"a find that is not waiting cannot be washed twice", "")
	_main.set(&"sludge", purse_was)
	_check(_yard.held.is_empty(), "a find never joins the pile to be sold",
		"%d in the yard" % _yard.held.size())

	# A find that comes in fours comes in fours, and stops at four.
	#
	# "Kept once, however many turn up" was the rule for every find until the chairs, and it
	# is still the rule for the number the catalogue asks for — the cap just is not one any
	# more. Netting the same chair five times has to leave four on the shelf: four is a
	# dining set, five is a bug that would let a player farm one tile for furniture.
	var many := ""
	for name: String in sheets.names:
		if sheets.copies_of(StringName(name)) > 1:
			many = name
			break
	if many.is_empty():
		_check(false, "there is a find that comes in more than one", "")
	else:
		var wanted := sheets.copies_of(StringName(many))
		var many_index := -1
		for i in _grid.defs.size():
			if String(_grid.defs[i].piece) == many:
				many_index = i
				break
		unlocked.clear()
		unwashed.clear()
		for attempt in wanted + 1:
			_main.call(&"_on_net_landed", PackedInt32Array([many_index]))
		# Two of them washed and two still waiting: a copy is a copy on either list.
		for wash in 2:
			_main.call(&"_on_find_washed", StringName(many), 0)
		_main.call(&"_on_net_landed", PackedInt32Array([many_index]))
		var held := 0
		for kept: String in unlocked + unwashed:
			if kept == many:
				held += 1
		while unwashed.has(many):
			_main.call(&"_on_find_washed", StringName(many), 0)
		_check(held == wanted, "a find that comes in fours is kept four times and no more",
			"%s: %d kept of %d" % [many, held, wanted])

		# And the shelf counts them rather than matching by name: standing one chair down
		# must not take the other three off the list with it.
		var many_decor: Array = _main.get(&"decor")
		many_decor.clear()
		room.unlocked = unlocked as Array[String]
		room.decor = many_decor
		var before := room.in_store().size()
		room.place(StringName(many), Vector2i(2, 2))
		_check(room.in_store().size() == before - 1,
			"and standing one of them down leaves the rest on the shelf",
			"%d listed, %d after one was placed" % [before, room.in_store().size()])
		many_decor.clear()
		unlocked.clear()
		unwashed.clear()
		_main.call(&"_on_net_landed", PackedInt32Array([find_index]))
		_main.call(&"_on_find_washed", StringName(find.piece), 0)

	# The room.
	var inside := Vector2i(2, 2)
	var decor: Array = _main.get(&"decor")
	decor.clear()
	room.unlocked = unlocked as Array[String]
	room.decor = decor
	var piece := StringName(find.piece)
	var span := room.span_of(piece)
	_check(room.in_store().size() == 1, "the find shows up in the inventory", "")
	_check(room.place(piece, inside), "it can be put down on the floor", "")
	_check(room.in_store().is_empty(), "and leaves the inventory once it is out", "")
	_check(room.can_place(piece, inside),
		"and something else may be stood on top of it — a chair belongs on a rug", "")
	_check(not room.can_place(piece, Vector2i(ShedRoom.PLACE_COLS - span.x + 1, inside.y)),
		"and nothing can be stood off the edge of the floor", "")
	# A short piece reaches the back wall (2026-09-16, Richard: small pieces could not be
	# pushed up to it). Its base is most of its picture, so a bound that held the base clear
	# of the room's skirting parked it a run's width down the floor while a tall piece, whose
	# base is a strip, still looked flush. The rule is the floor itself: base on the boards.
	var small := &""
	for name: String in sheets.names:
		if sheets.is_small(StringName(name)):
			small = StringName(name)
			break
	if not small.is_empty():
		var small_span := room.span_of(small)
		var against := small_span.y - room.base_of(small)
		_check(room.can_place(small, Vector2i(inside.x, -against)),
			"a small piece may stand with its base against the back wall",
			"span %s base %d" % [str(small_span), room.base_of(small)])
		_check(not room.can_place(small, Vector2i(inside.x, -against - 1)),
			"and no further: its base may not go up the wall", "")
	# The pot, by name (2026-09-19, issue #30). The two checks above derive everything from
	# `base_of` and so pass whether a pixel base works or is silently dropped; this one asks
	# for the number the catalogue authored. It also asks that a cell-authored piece is
	# still a whole multiple of CELL, so the fallback cannot rot unnoticed.
	var the_pot := &"decor_plant_pot"
	if sheets.has(the_pot):
		_check(sheets.has_base_px(the_pot, 0) and room.base_of(the_pot) == 2,
			"the pot's base is the two pixels it stands on, not a whole cell",
			"%d px" % room.base_of(the_pot))
		var the_pot_span := room.span_of(the_pot)
		_check(room.can_place(the_pot, Vector2i(inside.x, -(the_pot_span.y - 2)))
			and not room.can_place(the_pot, Vector2i(inside.x, -(the_pot_span.y - 1))),
			"so it stands six pixels nearer the back wall than a cell would let it",
			"span %s" % str(the_pot_span))
	var sofa := &"decor_sofa"
	if sheets.has(sofa):
		_check(not sheets.has_base_px(sofa, 0) and room.base_of(sofa) % ShedRoom.CELL == 0,
			"and a piece with no pixel base still measures in whole cells",
			"%d px" % room.base_of(sofa))
	# Free placement (2026-09-16): the unit is one source pixel, so a piece may be nudged by
	# one — the whole point of the change. Placed at a pixel that is not a cell boundary and
	# read back unrounded.
	decor.clear()
	var nudged := Vector2i(ShedRoom.CELL + 3, ShedRoom.CELL + 5)
	_check(room.place(piece, nudged), "a piece may stand off the old eight-pixel grid", "")
	var put: Array = (decor[0] as Dictionary)["cell"]
	_check(int(put[0]) == nudged.x and int(put[1]) == nudged.y,
		"and it is kept where it was put, to the pixel", "%s" % str(put))
	var art_span := room.sheets.view_size_of(piece, 0)
	var px_span := room.span_of(piece)
	_check(
		absf(float(px_span.x) - art_span.x) <= 0.5 and absf(float(px_span.y) - art_span.y) <= 0.5,
		"and a footprint is the drawing itself, not the cells nearest to it",
		"%s against %s" % [str(px_span), str(art_span)]
	)
	decor.clear()
	room.place(piece, inside)

	# Against the wall (2026-09-13): only a piece's base takes floor, so a tall piece may
	# rise up the back wall until its base is on the boards, and no further.
	var tall := &"decor_bookcase_tall"
	if sheets.has(tall):
		var tall_span := room.span_of(tall)
		var tall_base := room.base_of(tall)
		# As far up the wall as the wall goes, or as far as keeps its base on the boards.
		var top := maxi(tall_base - tall_span.y, -ShedRoom.PLACE_WALL)
		_check(top < 0 and room.can_place(tall, Vector2i(inside.x, top)),
			"a bookcase may stand with its picture up the wall",
			"span %s base %d top %d" % [tall_span, tall_base, top])
		_check(not room.can_place(tall, Vector2i(inside.x, top - 1)),
			"but no higher than the wall, and never with its base off the floor", "")
		_check(not room.can_place(tall, Vector2i(inside.x, tall_base - tall_span.y - 1)),
			"a base off the floor is refused whatever the wall", "")
		room.place(tall, Vector2i(inside.x, top))
		var blocked: Dictionary = room.call(&"_taken")
		# The blocked map is in walker cells, the piece in pixels: the cell the foot stands
		# in is blocked, and the one a base-and-a-half above it is not.
		var foot_cell := (top + tall_span.y - 1) / ShedRoom.CELL
		var air_cell := (top + tall_span.y - 1 - tall_base - ShedRoom.CELL) / ShedRoom.CELL
		var post := inside.x / ShedRoom.CELL
		_check(
			blocked.has(Vector2i(post, foot_cell))
			and not blocked.has(Vector2i(post, air_cell)),
			"and only its base blocks the walkers",
			"foot cell %d, air cell %d, %d blocked" % [foot_cell, air_cell, blocked.size()])
		decor.clear()
	# The walkers stay on the boards (2026-09-16): the moulded frame is drawn inside the
	# floor's own rectangle and both of them used to stand on it.
	decor.clear()
	var keep: Vector4 = room.call(&"_feet_keep")
	var side := float(ShedRoom.BORDER_VERTICAL.get_width()) / float(ShedRoom.CELL)
	var head := float(ShedRoom.BORDER_HORIZONTAL.get_height()) / float(ShedRoom.CELL)
	var sill := float(ShedRoom.BORDER_SILL.get_height()) / float(ShedRoom.CELL)
	_check(keep.x >= side and keep.z >= side and keep.y >= head and keep.w >= sill,
		"the walkable floor is inset by the moulding it is drawn inside",
		"keep %s against %.2f / %.2f / %.2f" % [str(keep), side, head, sill])
	var skirting := [
		Vector2(keep.x - 0.2, 5.0), Vector2(float(ShedRoom.COLS) - keep.z + 0.2, 5.0),
		Vector2(5.0, keep.y - 0.2), Vector2(5.0, float(ShedRoom.ROWS) - keep.w + 0.2),
	]
	var stood := 0
	for where: Vector2 in skirting:
		if bool(room.call(&"_dog_may_stand", where)):
			stood += 1
	_check(stood == 0, "and a walker is refused the skirting on all four sides",
		"%d of 4 allowed" % stood)
	_check(bool(room.call(&"_dog_may_stand", Vector2(keep.x + 0.1, keep.y + 0.1)))
		and bool(room.call(&"_dog_may_stand", Vector2(
			float(ShedRoom.COLS) - keep.z - 0.1, float(ShedRoom.ROWS) - keep.w - 0.1
		))),
		"but the boards just inside it are walkable", "")
	# Feet only, by decision: the drawing still rises over the wall the way furniture does.
	_check(float(ShedRoom.ROWS) - keep.w - keep.y > ShedRoom.YOU_TALL,
		"and the room is still deeper than the figure is tall",
		"%.1f rows against %.1f" % [float(ShedRoom.ROWS) - keep.w - keep.y, ShedRoom.YOU_TALL])

	# A painting hangs on the wall and takes no floor.
	var painting := &""
	for name: String in sheets.names:
		if sheets.on_wall(StringName(name)):
			painting = StringName(name)
			break
	_check(not painting.is_empty(), "the catalogue has something that hangs on the wall", "")
	if not painting.is_empty():
		var hang := room.span_of(painting)
		_check(room.can_place(painting, Vector2i(inside.x, -hang.y)),
			"a painting may hang on the wall", "")
		_check(not room.can_place(painting, Vector2i(inside.x, 0)),
			"and not stand on the floor", "")
		_check(not room.can_place(painting, Vector2i(inside.x, -ShedRoom.PLACE_WALL - 1)),
			"and not over the top of the wall", "")
		room.place(painting, Vector2i(inside.x, -hang.y))
		var blocked: Dictionary = room.call(&"_taken")
		_check(blocked.is_empty(), "and it blocks nothing", "%d cells" % blocked.size())
		var order: Array = room.call(&"_order")
		_check(int((order[0] as Dictionary)["layer"]) == 0, "and is drawn first", "")
		decor.clear()

	# The drawing order (2026-09-13, after a chair drawn through a desk): two pieces on
	# one row keep the order they went down in, later on top, every time it is asked.
	var chair := StringName(find.piece)
	room.place(chair, Vector2i(4 * ShedRoom.CELL, 4 * ShedRoom.CELL))
	room.place(chair, Vector2i(5 * ShedRoom.CELL + 3, 4 * ShedRoom.CELL))
	var steady := true
	for again in 6:
		var order: Array = room.call(&"_stacking")
		if order != [0, 1]:
			steady = false
	_check(steady, "two pieces on one row are drawn in the order they went down", "")
	decor.clear()
	# A small piece set over a big one is drawn right after it, however high up the
	# picture it was put.
	var table := &"decor_big_table"
	var pot := &""
	for name: String in sheets.names:
		if sheets.is_small(StringName(name)):
			pot = StringName(name)
			break
	_check(not pot.is_empty(), "the catalogue has something small enough to set on a table", "")
	if not pot.is_empty() and sheets.has(table):
		var corner := 6 * ShedRoom.CELL
		room.place(table, Vector2i(corner, corner))
		var table_span := room.span_of(table)
		# The walkers' keys are in cells, the placement in pixels (see ShedRoom.CELL).
		var table_foot := float(corner + table_span.y) / float(ShedRoom.CELL)
		# Set on the table's top, so the pot's own foot is well above the table's.
		room.place(pot, Vector2i(
			corner + 8, corner + 1 - room.span_of(pot).y + room.base_of(pot)
		))
		var order: Array = room.call(&"_stacking")
		_check(order == [0, 1], "a pot set on a table is drawn after the table",
			"order %s, table foot %.2f" % [order, table_foot])
		# And a dog with its feet in the table's base is drawn over the table too.
		var in_base := table_foot - 0.5 * float(room.base_of(table)) / float(ShedRoom.CELL)
		var across := float(corner + table_span.x / 2) / float(ShedRoom.CELL)
		var over: float = room.call(&"_walker_key", Vector2(across, in_base), decor)
		_check(over > table_foot, "a walker standing in a piece's base is drawn over it",
			"key %.2f, foot %.2f" % [over, table_foot])
		var behind: float = room.call(
			&"_walker_key", Vector2(across, float(corner) / float(ShedRoom.CELL) + 0.5), decor
		)
		_check(behind < table_foot, "and one behind it is drawn behind it",
			"key %.2f" % behind)
		decor.clear()

	# The finds float smaller than the rubbish: Lake.FIND_SHRINK off SPRITE_SCALE.
	var shrunk := true
	var shrunk_detail := ""
	for def: TrashDef in _grid.defs:
		if not def.keepsake or def.region.size == Vector2.ZERO:
			continue
		var longest := maxf(def.region.size.x, def.region.size.y)
		var want := longest * Lake.SPRITE_SCALE / Lake.FIND_SHRINK
		var got := maxf(def.size.x, def.size.y)
		if got > want + 0.01 or got > Lake.SPRITE_LARGEST / Lake.FIND_SHRINK + 0.01:
			shrunk = false
			shrunk_detail = "%s draws %.1f, art %.0f" % [def.piece, got, longest]
	_check(shrunk, "a find floats at SPRITE_SCALE over FIND_SHRINK, capped in proportion",
		shrunk_detail)
	# The footprint is the object, not the tile it fits in: rounded to nearest, so a piece
	# 27 pixels across is three cells of eight and not four.
	# Measured in pixels rather than as a fraction: the smallest pieces are a few pixels
	# across and are always going to round up to the one cell nothing can be smaller than.
	#
	# Measured against the view the shed actually stands, not against the piece's picture in
	# the lake. Those were the same drawing twice until the decoration art; now a sofa is
	# 22 px on its side in the water and 49 head-on in the room, and reading the floor it
	# takes up off the wrong one of those is the bug this check exists to catch.
	var worst := 0.0
	var worst_name := ""
	for name: String in sheets.names:
		for view in sheets.view_count(StringName(name)):
			var art := sheets.view_size_of(StringName(name), view)
			var box := room.span_of(StringName(name), view)
			var off := maxf(
				absf(float(box.x) - art.x), absf(float(box.y) - art.y)
			)
			if off > worst:
				worst = off
				worst_name = "%s/%s" % [name, sheets.role_of(StringName(name), view)]
	_check(worst <= 0.5, "a footprint is the thing standing in it, to the pixel",
		"%s is %.1f px out" % [worst_name, worst])

	# Every set is a set of something: a piece with more than one face has to say which
	# verb turns it, or the shed has art it cannot show. The authored table in
	# tools/decor_sets.json is where that is said, and this is the gate on it.
	var mute := ""
	for name: String in sheets.names:
		if sheets.view_count(StringName(name)) > 1 				and sheets.kind_of(StringName(name)) == Sheets.Set.SINGLE:
			mute = name
			break
	_check(mute.is_empty(), "every piece with more than one face says what turns it", mute)

	# R and E are two axes, not two kinds (2026-09-20): the toilet turns and fills. So the
	# rule is that each verb moves along its own axis only — R never empties a bath and E
	# never turns a toilet — and that what leaves the store faces front, switched off.
	var crossed := ""
	var store_off := ""
	for name: String in sheets.names:
		var each := StringName(name)
		if sheets.face_of(each, 0) != 0 or sheets.is_on(each, 0):
			store_off = name
		for view in sheets.view_count(each):
			var e_to := sheets.switched(each, view)
			if e_to >= 0 and sheets.face_of(each, e_to) != sheets.face_of(each, view):
				crossed = "%s: E turned it" % name
			var r_to := sheets.turned(each, view)
			if r_to != view and sheets.face_of(each, r_to) == sheets.face_of(each, view):
				crossed = "%s: R did not turn it" % name
	_check(crossed.is_empty(), "R moves the face and E the state, never the other", crossed)
	_check(store_off.is_empty(), "every piece leaves the store facing front, switched off",
		store_off)

	var toilet := &"decor_toilet"
	_check(sheets.turnable(toilet) and sheets.switchable(toilet),
		"the toilet both turns and fills", "")
	var full_side := sheets.turned(toilet, sheets.switched(toilet, 0))
	_check(sheets.is_on(toilet, full_side) and sheets.face_of(toilet, full_side) == 1,
		"a full toilet turned stays full", "view %d" % full_side)
	# Pressing E changes what changed and nothing moves: both states of a face are one
	# frame (build_decor's shared_frame), or the lamp jumped sideways on every switch.
	var jumps := ""
	for name: String in sheets.names:
		var each := StringName(name)
		for view in sheets.view_count(each):
			var other := sheets.switched(each, view)
			if other >= 0 and sheets.view_size_of(each, other) != sheets.view_size_of(each, view):
				jumps = "%s: %s against %s" % [name, sheets.view_size_of(each, view),
					sheets.view_size_of(each, other)]
	_check(jumps.is_empty(), "both states of a switch share one frame", jumps)
	var toilet_faces := {}
	for view in sheets.view_count(toilet):
		toilet_faces[sheets.face_of(toilet, view)] = true
	_check(toilet_faces.size() == 3, "the toilet turns to either wall",
		"%d faces" % toilet_faces.size())

	var counter := &"decor_kitchen_counter"
	var counter_side := sheets.turned(counter, 0)
	_check(sheets.face_of(counter, counter_side) == 1,
		"an empty counter still turns to its only side view", "view %d" % counter_side)
	_check(sheets.switched(counter, counter_side) < 0,
		"and E does nothing to it side on, where no empty sink was drawn", "")
	for pair: Array in [[&"decor_fireplace", &"fire"], [&"decor_fridge", &"cold"],
			[&"decor_lamp", &"warm"], [&"decor_standing_lamp", &"warm"],
			[&"decor_bathtub", &""], [&"decor_vynil_player", &""]]:
		_check(sheets.light_of(pair[0]) == pair[1], "%s gives off '%s'" % pair,
			String(sheets.light_of(pair[0])))
	for switch: StringName in [&"decor_vynil_player", &"decor_lamp", &"decor_standing_lamp",
			&"decor_bathtub", &"decor_bath_sink"]:
		_check(sheets.switchable(switch) and not sheets.turnable(switch),
			"%s switches with E" % switch, "")
	_check(sheets.turnable(&"decor_oval_rug") and not sheets.switchable(&"decor_oval_rug"),
		"the oval rug restyles with R", "")
	_check(sheets.has(&"decor_rug") and sheets.has(&"decor_aquarium"),
		"the rug and the aquarium are finds", "")

	# A lamp lit is a pool of light and no crackle; only the hearth crackles.
	var kept_decor := room.decor.duplicate()
	room.decor.clear()
	room.decor.append({"piece": "decor_lamp", "cell": [16, 40],
		"view": sheets.switched(&"decor_lamp", 0)})
	_check(not bool(room.call(&"_fire_lit")), "a lit lamp does not crackle", "")
	_check((room.call(&"lamps", Rect2(0, 0, 400, 300)) as Array).size() == 1,
		"but it throws a pool", "")
	room.decor.append({"piece": "decor_fireplace", "cell": [80, 40],
		"view": sheets.switched(&"decor_fireplace", 0)})
	_check(bool(room.call(&"_fire_lit")), "the hearth does", "")
	room.decor.clear()
	room.decor.append_array(kept_decor)

	# R has to arrive as a key, not as a method call. The room reads keys in
	# `_unhandled_key_input` because `_gui_input` only ever sees them on the Control that
	# holds focus — and this room never takes focus, so the first cut of the turn verb was
	# wired somewhere no key could reach. Calling `turn_carried()` here would pass against
	# that bug, so the event goes through the viewport the way a player's does.
	var turner := ""
	for name: String in sheets.names:
		if sheets.turnable(StringName(name)):
			turner = name
			break
	if turner.is_empty():
		_check(false, "there is something in the catalogue that turns", "")
	else:
		_main.call(&"_set_shed", true)
		room.carrying = StringName(turner)
		room.set(&"_carry_view", 0)
		# Physical, because that is how the binds are written: the hole R sits in, not the
		# letter, so the same press turns a piece on an AZERTY keyboard.
		var press := InputEventKey.new()
		press.physical_keycode = KEY_R
		press.pressed = true
		room.get_viewport().push_input(press)
		_check(int(room.get(&"_carry_view")) == 1,
			"pressing R turns the piece in hand",
			"%s stayed on view %d" % [turner, int(room.get(&"_carry_view"))])
		room.carrying = &""
		_main.call(&"_set_shed", false)

	# Rugs go down first so the chair can stand on them.
	var rug := ""
	for name: String in sheets.names:
		if sheets.lies_flat(StringName(name)):
			rug = name
			break
	_check(not rug.is_empty(), "the art knows which of it lies flat", "")
	if not rug.is_empty():
		unlocked.append(rug)
		room.place(StringName(rug), Vector2i(2, 2))
		var stacking: Array = room.call(&"_stacking")
		var first: Dictionary = decor[stacking[0]]
		_check(String(first["piece"]) == rug, "and lays it under everything else", "")
		room.take_back(decor.size() - 1 if String(decor[-1]["piece"]) == rug else 0)
		unlocked.erase(rug)

	room.take_back(0)
	_check(decor.is_empty() and room.in_store().size() == 1,
		"taking it back puts it in the inventory", "")
	room.place(piece, Vector2i(2, 3))

	# Saved and read back, with a made-up find in the file to be dropped on the way in.
	_check(bool(_main.call(&"save_game")), "the shed writes itself out", "")
	unlocked.append("no_such_piece")
	decor.append({"piece": "no_such_piece", "cell": [9, 9]})
	_check(bool(_main.call(&"load_game")), "and reads itself back", "")
	unlocked = _main.get(&"unlocked")
	decor = _main.get(&"decor")
	_check(unlocked.size() == 1 and decor.size() == 1,
		"the room came back as it was left",
		"%d found, %d placed" % [unlocked.size(), decor.size()])
	var kept := Vector2i(2, 3)
	_check(
		int((decor[0] as Dictionary)["cell"][0]) == kept.x
		and int((decor[0] as Dictionary)["cell"][1]) == kept.y,
		"and everything is where it was put", str((decor[0] as Dictionary)["cell"])
	)
	_check(not unlocked.has("no_such_piece"),
		"a find the catalogue no longer knows is dropped rather than kept", "")

	# An older file is refused, not migrated (the version 9 shed-unit read went with 11).
	var path: String = _main.get(&"save_path")
	var reading := FileAccess.open(path, FileAccess.READ)
	var raw: Dictionary = (reading.get_var(true) as Dictionary) if reading != null else {}
	if reading != null:
		reading.close()
	_check(not raw.is_empty(), "the save file reads back as a dictionary", "")
	if not raw.is_empty():
		raw["version"] = Lake.SAVE_VERSION - 1
		var writing := FileAccess.open(path, FileAccess.WRITE)
		if writing != null:
			writing.store_var(raw, true)
			writing.close()
		_check(not bool(_main.call(&"load_game")), "an older save is refused", "")
	_check_shed_dogs(room)
	_check_trophy()
	_advance()


## The find-caught card (2026-09-19, issue #30). It had no checks of any kind before this.
##
## What can be asked headless is the shape of it: the wording, that the retired drawing is
## gone rather than merely unused, that the four shine layers are there in the order they
## have to be drawn in and wearing the right materials, and that the glitter has somewhere
## to land. What cannot be asked here is whether any of it draws — `--headless` compiles no
## shader — and that is what `tools/shot_trophy.tscn` is for.
func _check_trophy() -> void:
	var card: Trophy = _main.get(&"_trophy")
	if card == null:
		_check(false, "the find card was built", "")
		return
	_check(Trophy.TITLE == "New decoration available to wash",
		"the card says the find is waiting to be washed", Trophy.TITLE)

	# The retired drawing, gone rather than left unused: the disc, the wheel of rays and the
	# motes, and the restored sprite it used to hold up.
	var source := FileAccess.get_file_as_string("res://scripts/trophy.gd")
	var left := []
	for name in ["DISC", "RAYS", "MOTES", "_draw_shine", "_draw_motes", "alt_region_of"]:
		if source.contains(name):
			left.append(name)
	_check(left.is_empty(),
		"and the disc, the rays and the motes are gone with the restored picture",
		", ".join(left))

	# Four layers, in the one order they can be drawn in: the light, the gold outline, the
	# picture over both, the glitter over that.
	var layers: Array[String] = []
	for child in card.get_children():
		layers.append(String(child.name))
	_check(layers == ["Beam", "Rim", "Piece", "Glitter"],
		"the card draws light, rim, picture, glitter, in that order", ", ".join(layers))
	var beam := card.get_node_or_null(^"Beam")
	var rim := card.get_node_or_null(^"Rim")
	var art := card.get_node_or_null(^"Piece")
	_check(beam != null and beam.material is ShaderMaterial
		and (beam.material as ShaderMaterial).shader == LakeGrid.BEAM_SHADER,
		"the light is the lake's own beam shader", "")
	_check(rim != null and rim.material is ShaderMaterial
		and (rim.material as ShaderMaterial).shader == Trophy.RIM_SHADER,
		"and the outline is the finds' own rim shader", "")
	# The net sets `show_behind_parent` on its rim because the net draws the catch itself.
	# Here the picture is a child, so what puts the rim behind it is child order; copying
	# the flag would sink the gold under the words as well.
	_check(rim != null and not rim.show_behind_parent and art != null and art.material == null,
		"the rim is behind the picture by child order, not by a flag", "")

	# Somewhere for the glitter to land: the spots come off the grimy picture's own opaque
	# pixels, which is the sprite the card now holds up.
	var sheets: Sheets = card.sheets
	if sheets != null and sheets.atlas != null and sheets.has(&"decor_plant_pot"):
		var spots := LakeGrid.GlintTwinkle.sample_box(
			sheets.atlas.get_image(), sheets.region_of(&"decor_plant_pot"), 11
		)
		_check(spots.size() > 0,
			"and the glitter has spots to land on, off the grimy picture",
			"%d spots" % spots.size())


## The pack in the shed (2026-09-19, issue #30): up to as many dogs as the player owns, each
## lying on a seat the catalogue authored, one dog to a seat.
##
## The roll is per dog and random, so the room is opened over and over off a fixed seed
## until a full house turns up rather than being forced some other way: what is being
## guarded is the real path, `_room_shown`.
func _check_shed_dogs(room: ShedRoom) -> void:
	var sheets: Sheets = room.sheets
	if sheets == null or not sheets.has(&"decor_sofa") or not sheets.has(&"decor_pet_bed"):
		return
	# The room has to be on screen: `_room_shown` is what rolls the dogs, and it does
	# nothing at all for a room nobody is looking at. Opening it also re-points `decor` at
	# the lake's own array, so the furniture goes down after the door is open, not before.
	var was_open: bool = bool(_main.get(&"_shed_open"))
	_main.call(&"_set_shed", true)
	var decor: Array = room.decor
	# A sofa facing front (a seat) and a pet bed (a seat).
	decor.clear()
	room.place(&"decor_sofa", Vector2i(ShedRoom.CELL * 3, ShedRoom.CELL * 3), 0)
	room.place(&"decor_pet_bed", Vector2i(ShedRoom.CELL * 22, ShedRoom.CELL * 16), 0)
	var seats: Array = room.call(&"_seats")
	_check(seats.size() == 2,
		"a sofa facing front and a pet bed are two seats", "%d" % seats.size())

	# A seated dog lies on the cushion, not over the backrest (Richard, 2026-09-20). A seat
	# is where the dog's feet go and the drawing rises from there, so a lift picked for where
	# a dog would *stand* puts its body on the back of the sofa. Asked of the seats a dog sits
	# **in** — a piece a whole cell taller than the dog, which is what has a back to lie over.
	# A pet bed is two cells to the dog's one and a half and a dog on one sticks out by
	# design; there is nothing there for it to be on top of.
	var dog_tall: float = DogArt.span(&"sleep", ShedRoom.DOG_TALL).y
	for seat: Dictionary in seats:
		var key := String(seat["key"])
		var piece := StringName(key.split("@")[0])
		var tall := float(room.span_of(piece, 0).y) / float(ShedRoom.CELL)
		if tall - dog_tall < 1.0:
			continue
		var feet: Vector2 = seat["feet"]
		var top := float(int(String(key.split("@")[1]).split(",")[1])) / float(ShedRoom.CELL)
		_check(feet.y - dog_tall >= top - 0.01,
			"a dog on the %s lies on its cushion, not over its back" % piece,
			"dog top %.2f, piece top %.2f" % [feet.y - dog_tall, top])

	# The sofa turned side on is nobody's seat: a dog laid on that cushion is cut in half by
	# the backrest, which is why the seat is authored per view rather than per piece.
	decor.clear()
	room.place(&"decor_sofa", Vector2i(ShedRoom.CELL * 3, ShedRoom.CELL * 3), 1)
	_check((room.call(&"_seats") as Array).is_empty(),
		"and a sofa turned side on is no seat at all", "")

	decor.clear()
	room.place(&"decor_sofa", Vector2i(ShedRoom.CELL * 3, ShedRoom.CELL * 3), 0)
	room.place(&"decor_pet_bed", Vector2i(ShedRoom.CELL * 22, ShedRoom.CELL * 16), 0)
	var was_pack: Callable = room.pack_size
	room.pack_size = func() -> int: return 4
	var rng: RandomNumberGenerator = room.get(&"_dog_rng")
	rng.seed = 20260919
	var dogs: Array = []
	for _try in 400:
		room.call(&"_room_shown")
		dogs = room.dogs()
		if dogs.size() == ShedRoom.DOGS_MOST:
			break
	_check(dogs.size() == ShedRoom.DOGS_MOST,
		"four dogs owned puts up to four in the room", "%d" % dogs.size())
	_check(dogs.size() <= ShedRoom.DOGS_MOST, "and never more", "%d" % dogs.size())

	# One dog to a seat, and everybody else on the floor.
	var held := {}
	var seated := 0
	var twice := false
	for dog in dogs:
		if dog.seat.is_empty():
			continue
		seated += 1
		if held.has(dog.seat):
			twice = true
		held[dog.seat] = true
	_check(not twice and seated == 2,
		"the two seats take one dog each", "%d seated of %d" % [seated, dogs.size()])
	_check(dogs.size() - seated == 2,
		"and the rest lie on the floor", "%d on the floor" % (dogs.size() - seated))

	# A dog on the sofa may stand on the sofa. Its own base blocks that cell for everybody
	# else, including the player, and without the exemption the unstick in `_drive_dog`
	# would shove the animal off the cushion every frame.
	for dog in dogs:
		if dog.seat.is_empty() or not dog.seat.begins_with("decor_sofa"):
			continue
		var on := Vector2i(int(dog.at.x), int(dog.at.y))
		_check(bool(room.call(&"_dog_may_stand", dog.at, dog.over)),
			"a dog lying on the sofa may stand where it is lying", str(on))
		_check(not bool(room.call(&"_you_may_stand", dog.at)),
			"and the player may not walk onto it", str(on))
		# On it, not behind it: the walker sorts past the piece it is standing in.
		_check(float(room.call(&"_walker_key", dog.at, decor)) > dog.at.y,
			"and is drawn on the sofa rather than behind it", "")
		break
	room.pack_size = was_pack
	decor.clear()
	if not was_open:
		_main.call(&"_set_shed", false)


## The pigeons: art that fits its sheet, a flock sized by the rubbish it can stand on, a
## bird that can be netted for money, and droppings that go away again.
func _stage_pigeons() -> void:
	var book: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(Flock.CATALOGUE)
	)
	_check(book != null and book.has("cells"), "the pigeon sheet was cut", "")
	if book == null:
		_advance()
		return

	var sheet: Array = book["size"]
	var outside := 0
	var overlaps := 0
	var cells: Array = book["cells"]
	for i in cells.size():
		var a: Array = (cells[i] as Dictionary)["region"]
		var box := Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
		if box.position.x < 0.0 or box.position.y < 0.0 \
				or box.end.x > float(sheet[0]) or box.end.y > float(sheet[1]):
			outside += 1
		for j in range(i + 1, cells.size()):
			var b: Array = (cells[j] as Dictionary)["region"]
			if box.intersects(Rect2(float(b[0]), float(b[1]), float(b[2]), float(b[3]))):
				overlaps += 1
	_check(outside == 0 and overlaps == 0,
		"every bird is cut from its own pixels, inside the sheet",
		"%d outside, %d overlapping" % [outside, overlaps])

	var kinds: Array[Dictionary] = _flock.kinds()
	_check(kinds.size() > 0, "the chosen birds loaded", "%d" % kinds.size())

	# The flock is a reading of the rubbish in view, and a cleared lake keeps none of it.
	_flock.spawning = true
	_grid.drawn_pieces = Flock.PIECES_PER_BIRD * 5
	var busy := _flock.target_count()
	_grid.drawn_pieces = Flock.PIECES_PER_BIRD - 1
	var quiet := _flock.target_count()
	_grid.drawn_pieces = 0
	_check(busy > quiet and quiet == 0 and _flock.target_count() == 0,
		"the flock thins out with the rubbish",
		"%d birds over a filthy lake, %d over a clean one" % [busy, quiet])
	_grid.drawn_pieces = Flock.PIECES_PER_BIRD * 5

	# A bird put on a tile with rubbish on it, landed.
	var perch := _deep_tile()
	_check(_grid.height_of(perch) > 0, "there is something out there to perch on", "")
	_flock.birds.clear()
	_check(_flock.add_bird(perch), "a bird can be put on it", "")
	(_flock.birds[0] as Dictionary)["travel"] = 1.0
	_flock.call(&"_step", _flock.birds[0], 0.016)
	_check(_flock.bird_on(perch) == 0, "and is found sitting there", "")

	# Netting it pays on the spot: no yard slot, no ferry, and the meter does not move.
	var purse := float(_main.get(&"sludge"))
	var filth := float(_main.get(&"pollution"))
	var held := _yard.held.size()
	var caught_before := int(_main.get(&"birds_caught"))
	_net.flock = _flock
	_net.tile_pos = Iso.world_to_tile(_grid.surface_pos(perch))
	_net.radius = 1
	# No room for rubbish, so the bird is the only thing this sweep can lift: birds are taken
	# before the hold is checked (see CastNet._sweep). With room, the junk the bird sits on
	# comes up too and moves the meter, which is not what this is asking about.
	_net.hold = 0
	_net.catch.resize(0)
	_net.call(&"_sweep")
	_check(_flock.bird_on(perch) < 0 and _flock.birds.is_empty(),
		"the net takes the bird off its perch", "")
	_check(int(_main.get(&"birds_caught")) == caught_before + 1
		and float(_main.get(&"sludge")) > purse,
		"and it is paid for on the spot",
		"%.0f -> %.0f sludge" % [purse, float(_main.get(&"sludge"))])
	_check(_yard.held.size() == held, "a bird never reaches the yard",
		"%d in the yard" % _yard.held.size())
	_check(is_equal_approx(float(_main.get(&"pollution")), filth),
		"and a bird is not filth, so the meter does not move", "")

	# Droppings wear off.
	_flock.droppings.clear()
	_flock.droppings.append(
		{"at": Vector2.ZERO, "born": -Flock.POOP_LIFE * 2.0, "on_angler": false, "on_land": true}
	)
	_flock.droppings.append({"at": Vector2.ZERO, "born": 1e9, "on_angler": false, "on_land": true})
	_flock.call(&"_fade_droppings", 0.016)
	_check(_flock.droppings.size() == 1, "old droppings fade away and fresh ones stay",
		"%d left" % _flock.droppings.size())

	_stage_pigeon_look()
	_stage_net_behind()

	_flock.spawning = false
	_advance()


## The net is behind the angler wherever the angler is standing (2026-09-16).
##
## It used to be a fixed z 8 against an angler on 9, which is only true out in the open: the
## walker drops to `BEHIND_CRATE` beside the crate and `BEHIND_SHED` behind the hut, and on
## both of those the net and the whole rope were drawn over the player — the end of the rope
## showing against the figure on a cast aimed up the screen.
func _stage_net_behind() -> void:
	var stood := _angler.position
	var shed := Iso.tile_to_world(Iso.shed_centre().x, Iso.shed_centre().y)
	var where := {
		# South-east of the crate as well as of the hut: at +3 the angler is still inside
		# the crate's own footprint test and lands on the middle band.
		"in the open": Iso.tile_to_world(
			Iso.ISLAND_CENTRE.x + 4.5, Iso.ISLAND_CENTRE.y + 4.5
		),
		"behind the hut": shed - Vector2(0.0, 90.0),
		"beside the crate": _yard.position - Vector2(0.0, 40.0),
	}
	var helper := _main.get(&"_net2") as CastNet
	var over := []
	var bands := {}
	for name: String in where:
		_angler.position = where[name]
		_main.call(&"_sort_walkers")
		bands[name] = _angler.z_index
		if _net.z_index >= _angler.z_index:
			over.append("%s (net %d, angler %d)" % [name, _net.z_index, _angler.z_index])
		if helper != null and helper.z_index != _net.z_index:
			over.append("%s (the double cast's net is on its own layer)" % name)
	_check(over.is_empty(), "the net stays behind the angler wherever they stand",
		"over: %s" % str(over))
	# The three bands really are three, or the check above proves nothing.
	_check(int(bands["in the open"]) > int(bands["beside the crate"])
		and int(bands["beside the crate"]) > int(bands["behind the hut"]),
		"and the angler was actually tested on all three bands", "%s" % str(bands))
	_angler.position = stood
	_main.call(&"_sort_walkers")


## How the flock is drawn (2026-09-16): over the whole lake, standing on the piece it is
## actually sitting on, with a smudge for a splat and its own silhouette for a shadow.
func _stage_pigeon_look() -> void:
	_check(_flock.z_index > 12 and _flock.z_index > 20 and not _flock.z_as_relative,
		"the flock is drawn over the hulls, the piers and the net",
		"z %d" % _flock.z_index)
	# The rim is a shader trick and a missing shader is a silent nothing, not an error.
	var rim := _flock.get_node_or_null(^"BirdRim")
	var mat := (rim.material as ShaderMaterial) if rim != null else null
	_check(rim != null and mat != null and mat.shader != null and rim.show_behind_parent,
		"the rim's shader loaded, behind the birds it outlines", "")
	var tone = mat.get_shader_parameter("rim_gold") if mat != null else null
	_check(tone != null and Vector3(tone).z > Vector3(tone).x,
		"and it is not the finds' gold", "%s" % str(tone))

	# The perch is the drawn top of the drawn piece, not the tile's own surface point plus a
	# guess at the def's height. Asked of a leaning, resized piece, which is what every piece
	# on this lake is.
	var perch := _deep_tile()
	var def: TrashDef = _grid.defs[_grid.stacks[perch][_grid.stacks[perch].size() - 1]]
	var top := _grid.perch_point(perch)
	var water := _grid.surface_pos(perch)
	_check(top.y < water.y, "a bird's perch is above the water it floats on",
		"%.1f over %.1f" % [top.y, water.y])
	var drawn := def.size.y * _grid.swing[perch]
	var lift := water.y - top.y
	_check(lift <= drawn * 0.5 + 0.01 and lift > 0.0,
		"and no higher than the top of the picture",
		"%.1f up, picture %.1f tall" % [lift, drawn])
	# The lean is in it: a piece turned on the water carries its top sideways, and a perch
	# that ignored that is the bird standing beside the thing rather than on it.
	var was := _grid.tilt[perch]
	_grid.tilt[perch] = 0.0
	var straight := _grid.perch_point(perch)
	_grid.tilt[perch] = 0.8
	var leaned := _grid.perch_point(perch)
	_grid.tilt[perch] = was
	_check(absf(leaned.x - straight.x) > 0.5,
		"a leaning piece carries its perch over with it",
		"%.1f aside" % (leaned.x - straight.x))

	# A splat is a blob of art pixels, rolled fresh each time.
	var one: Array = _flock.call(&"_smudge")
	var two: Array = _flock.call(&"_smudge")
	_check(one.size() == Flock.POOP_CELLS + Flock.POOP_SPECKS + 1,
		"a splat is a body of cells with specks off it", "%d parts" % one.size())
	var body: Array[Vector2] = []
	for i in range(1, int(one[0]) + 1):
		body.append(one[i])
	var doubled := 0
	var joined := 0
	for i in body.size():
		for j in range(i + 1, body.size()):
			if body[i] == body[j]:
				doubled += 1
	for cell: Vector2 in body:
		if cell == Vector2.ZERO:
			joined += 1
			continue
		for step: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			if body.has(cell + step):
				joined += 1
				break
	_check(doubled == 0 and joined == body.size(),
		"its cells are all different and all touching", "%d doubled" % doubled)
	_check(str(one) != str(two), "and no two splats are the same shape", "")

	# The splat lives were roughly halved.
	_check(Flock.POOP_LIFE < 30.0 and Flock.POOP_LIFE_WATER < 4.0
		and Flock.POOP_ON_ANGLER < 4.0,
		"splats go away quicker than they did",
		"%.0f / %.1f / %.1f s" % [
			Flock.POOP_LIFE, Flock.POOP_LIFE_WATER, Flock.POOP_ON_ANGLER
		])

	# Three birds, by decision (2026-09-16), and the ones Richard picked.
	var kinds: Array[Dictionary] = _flock.kinds()
	var picked := []
	for kind: Dictionary in kinds:
		picked.append(int(kind["bird"]))
	picked.sort()
	_check(picked == [1, 3, 9], "three birds fly, and they are the three picked",
		"%s" % str(picked))

	# A bird is a bird: every picture it can show is painted in its own colours.
	#
	# This is the stage's reason to exist. The sheet is laid out by action, not by bird —
	# a row's first block is one bird's flap and its later blocks are three *other* birds
	# standing and sitting. The poses used to be read off the flying bird's own row, so a
	# perched pigeon changed species every 0.42 s. Asked of the pixels rather than of the
	# names in assets/pigeon_birds.json, or the test only proves the file agrees with
	# itself: a bird's own poses share all their colours with its flap, and the other
	# birds' share a third of them at most.
	var shot := _flock.sheet().get_image()
	# A compressed import hands back a format `get_pixel` cannot read.
	if shot.is_compressed():
		shot.decompress()
	var strays := []
	for kind: Dictionary in kinds:
		var wings := {}
		for frame: Rect2 in kind["fly"] as Array:
			for shade in _bird_tones(shot, frame):
				wings[shade] = true
		for other: Dictionary in kinds:
			for pose: String in ["stand", "sit"]:
				var share := _tone_share(_bird_tones(shot, other[pose]), wings)
				var same: bool = int(other["bird"]) == int(kind["bird"])
				if same != (share > 0.95):
					strays.append("bird %d's flap vs bird %d's %s: %.2f"
						% [int(kind["bird"]), int(other["bird"]), pose, share])
	_check(strays.is_empty(),
		"a bird's poses are its own colours, and no other bird's",
		"; ".join(strays))

	# The rim: perched and in the net's reach, and nothing else. The angler and the net are
	# put back afterwards — the stages that follow read both.
	_flock.birds.clear()
	_flock.net = _net
	_check(_flock.add_bird(perch), "a bird to rim", "")
	var bird: Dictionary = _flock.birds[0]
	bird["travel"] = 1.0
	_flock.call(&"_step", bird, 0.016)

	# A perched bird shuffles between its two poses and shows nothing else. It has two
	# pictures, not a cycle: played as one they were three different pigeons in a row.
	var own: Dictionary = kinds[posmod(int(bird["kind"]), kinds.size())]
	var standing := 0
	var sat := 0
	var wrong := 0
	for i in 4000:
		# Topped up every step: the point here is the poses, and a bird whose rest ran out
		# hops off and starts flapping, which counts as neither.
		bird["rest"] = Flock.PERCH_MAX
		_flock.call(&"_step", bird, 0.05)
		var frame := _flock.frame_of(bird)
		if frame == own["stand"]:
			standing += 1
		elif frame == own["sit"]:
			sat += 1
		else:
			wrong += 1
	_check(wrong == 0 and standing > 0 and sat > 0 and standing > sat,
		"a perched bird shuffles between its own two poses, mostly standing",
		"%d standing, %d sitting, %d neither" % [standing, sat, wrong])
	_flock.droppings.clear()
	# And it lands on its legs rather than in mid-air with its feet put away.
	bird["state"] = Flock.State.FLYING
	bird["travel"] = 1.0
	_flock.call(&"_step", bird, 0.05)
	_check(int(bird["state"]) == Flock.State.PERCHED
		and int(bird["pose"]) == Flock.POSE_STAND,
		"and it lands standing", "pose %d" % int(bird["pose"]))
	bird["rest"] = Flock.PERCH_MAX
	var stood := _angler.tile_pos
	var reach := _net.range_tiles
	_angler.tile_pos = Iso.world_to_tile(_grid.surface_pos(perch))
	_net.range_tiles = 40.0
	_check(_flock.catchable(bird), "a perched bird the net can reach is rimmed", "")
	_net.range_tiles = 0.2
	_check(not _flock.catchable(bird), "one out of range is not", "")
	_net.range_tiles = 40.0
	bird["state"] = Flock.State.FLYING
	_check(not _flock.catchable(bird), "and neither is one in the air", "")
	_flock.birds.clear()
	_angler.tile_pos = stood
	_net.range_tiles = reach

	# The head in the corner (2026-09-16): out of the meter's way, and cut by the screen's
	# own side rather than standing clear of it.
	var pop := _main.get(&"_pigeon") as PigeonPop
	var head := pop.head_box() if pop != null else Rect2()
	var skin := _main.get(&"_skin") as HudSkin
	var meter: Rect2 = skin.get(&"_meter_box") if skin != null else Rect2()
	var view := pop.get_viewport_rect().size if pop != null else Vector2.ZERO
	_check(pop != null and head.size.x > 0.0, "the pigeon head loaded", "")
	_check(not head.intersects(meter),
		"the head in the corner keeps off the pollution meter",
		"head %s, meter %s" % [str(head), str(meter)])
	_check(absf(head.get_center().y - view.y * 0.5) <= 1.0,
		"it comes in halfway down the screen",
		"%.0f of %.0f" % [head.get_center().y, view.y])
	_check(head.position.x < 0.0 and head.end.x > 0.0,
		"with its neck cut off by the side of the screen",
		"from %.0f to %.0f" % [head.position.x, head.end.x])
	# And cut right through: the far end of the neck's cut is off the edge as well, or the
	# flat of it shows on screen and the head reads as a sticker rather than as a bird
	# leaning in. Measured off the painting by the pop itself.
	var cut_at := pop.head_centre().x + pop.cut_reach() * PigeonPop.HEAD_TALL
	_check(cut_at < 0.0, "with the whole of the cut past it",
		"the cut reaches %.1f" % cut_at)
	# Leaning, not square on: at ninety degrees the head lies flat on its side.
	_check(PigeonPop.HEAD_LEAN > 0.0 and PigeonPop.HEAD_LEAN < 90.0,
		"and it leans rather than lying on its side",
		"%.0f degrees" % PigeonPop.HEAD_LEAN)

	# Every catch sends a coin, whether or not the head comes with it — and when it does, the
	# coin leaves the head rather than the water, once the head is actually there.
	var coins: CoinFly = _main.get(&"_coins")
	coins.clear()
	_check(pop.pop(7), "the head pops", "")
	_check(coins.flying() == 0, "and sends nothing while it is still off the edge",
		"%d in the air" % coins.flying())
	for i in 12:
		pop.call(&"_process", PigeonPop.RISE * 0.25)
	_check(coins.flying() == 1, "then one coin as it arrives",
		"%d in the air" % coins.flying())
	var in_air: Array = coins.get(&"_flying")
	var leaves: Vector2 = (in_air[0] as Dictionary)["from"]
	_check(pop.head_box().has_point(leaves), "and it leaves the head, not the lake",
		"%s off %s" % [str(leaves), str(pop.head_box())])
	# One head is one coin, however long it is held.
	for i in 40:
		pop.call(&"_process", PigeonPop.RISE * 0.25)
	_check(coins.flying() == 1, "one head is one coin", "%d in the air" % coins.flying())
	coins.clear()

	# And a catch that gets no head still pays, with the coin off the water. The pop is put
	# out of reach for the one call rather than rolling until the odds fall the right way.
	var kept: PigeonPop = _main.get(&"_pigeon")
	_main.set(&"_pigeon", null)
	var purse := float(_main.get(&"sludge"))
	_main.call(&"_on_bird_caught", _grid.surface_pos(perch))
	_main.set(&"_pigeon", kept)
	_check(coins.flying() == 1, "a catch with no head sends its coin off the water",
		"%d in the air" % coins.flying())
	_check(float(_main.get(&"sludge")) > purse, "and the purse is paid for it", "")
	coins.clear()


## Every opaque colour in one cut of the pigeon sheet, as a set. A bird's palette.
func _bird_tones(shot: Image, box: Rect2) -> Dictionary:
	var tones := {}
	for y in int(box.size.y):
		for x in int(box.size.x):
			var tone := shot.get_pixel(int(box.position.x) + x, int(box.position.y) + y)
			if tone.a > 0.0:
				tones[tone.to_rgba32()] = true
	return tones


## How much of one palette the other holds, 0 to 1.
func _tone_share(tones: Dictionary, within: Dictionary) -> float:
	if tones.is_empty():
		return 0.0
	var shared := 0
	for tone in tones:
		if within.has(tone):
			shared += 1
	return float(shared) / float(tones.size())


## The end of the run.
##
## The bug this stage exists for: the meter is a float that has had eighteen thousand
## subtractions done to it, so it lands a fraction above zero rather than on it. The
## ending used to be wired to that float reaching zero exactly, which it never does — a
## player who cleaned the whole lake got an empty bar and no ending. So the trigger is set
## up here the way it really arrives: a lake with nothing in it and a meter still carrying
## its dust.
func _stage_ending() -> void:
	if _in_stage == 1:
		# Nearly clean, but not: a few pieces left and a meter reading nothing. The ending
		# must not fire, and the player must be told what is left.
		for index in _grid.stacks.size():
			var stack := _grid.stacks[index]
			if not stack.is_empty():
				stack.resize(0)
				_grid.stacks[index] = stack
		_grid.insert(_deep_tile(), 0, 0)
		_grid.insert(_deep_tile(), 0, 0)
		_main.set(&"_filth_left", 0.0004 * float(_main.get(&"_filth_total")))
		_main.set(&"_clean_check_in", 0.0)
		return
	if _in_stage == 40:
		_check(not bool(_main.get(&"_cleaned")),
			"a lake with pieces left in it is not finished, whatever the meter says", "")
		_check(_main.call(&"_last_pieces_line") != "",
			"and the player is told how much is still out there",
			"%s" % _main.call(&"_last_pieces_line"))
		_check(_main.call(&"_last_pieces_line") == "2 pieces left",
			"in so many words: the count and \"pieces left\"", "%s" % _main.call(&"_last_pieces_line"))
		# Only from fifty down (2026-09-17): at fifty it shows, at fifty-one it does not.
		var was: int = _main.get(&"_left_over")
		_main.set(&"_left_over", 50)
		_check(_main.call(&"_last_pieces_line") == "50 pieces left", "it shows at fifty", "")
		_main.set(&"_left_over", 51)
		_check(_main.call(&"_last_pieces_line") == "", "and not at fifty-one", "")
		_main.set(&"_left_over", 1)
		_check(_main.call(&"_last_pieces_line") == "1 piece left", "one piece is singular", "")
		# Over the meter, not behind it (2026-09-17): the line is a node drawn after every
		# sheet of the meter, and its glyphs end above the top of the meter's ink.
		var skin: HudSkin = _main.get(&"_skin")
		skin.hint = "50 pieces left"
		skin.call(&"_place_hint")
		var line: Control = skin.get_node_or_null(^"HintLine")
		_check(line != null and line.get_index() == skin.get_child_count() - 1,
			"the pieces line is its own node, drawn after every sheet of the meter", "")
		var box: Rect2 = skin.hint_box()
		var frame: Rect2 = skin.get(&"_meter_frame_box")
		var span: Rect2 = skin.hint_span()
		_check(box.size.x > 0.0 and box.end.y <= frame.position.y
			and frame.position.y - box.end.y <= 6.0,
			"its glyphs end just over the bar's top plank: on the meter, not floating off it",
			"line ends %.1f, bar starts %.1f" % [box.end.y, frame.position.y])
		_check(box.position.x >= span.position.x and box.end.x <= span.end.x,
			"and it stands beside the garbage circle, over the bar, not over the circle",
			"line %.0f-%.0f in %.0f-%.0f" % [box.position.x, box.end.x, span.position.x, span.end.x])
		_main.set(&"_left_over", was)
		# And now it really is empty, with the same float dust on the meter.
		var stack := _grid.stacks[_deep_tile()]
		stack.resize(0)
		_grid.stacks[_deep_tile()] = stack
		# The water is empty and the last piece is still in the net's hold: the run ends
		# when the piece is put in the crate, not when it leaves the lake (2026-09-16).
		_net.catch = PackedInt32Array([0])
		_check(not bool(_main.call(&"_all_landed")),
			"a piece still in the net keeps the run going", "")
		_main.set(&"_clean_check_in", 0.0)
		return
	if _in_stage >= 41 and _ending_at < 0:
		# The dogs have been fetching all through the harness, and a dog carries a piece to
		# the crate and then leaves it in the air for `Haul.FLIGHT`. Either is a piece not
		# landed — which is the rule this stage is about, not a failure of it — so the pack
		# is let finish what it is holding and the sky is let clear before the net's hold is
		# emptied. The field is already empty, so nothing new can be picked up.
		#
		# Stopping the dogs first is what this did at its first try, and a dog stopped with
		# a piece in its mouth holds it for ever: `_all_landed` never comes true and the run
		# never ends. Stop them after, when their mouths are empty.
		var flying: Haul = _main.get(&"_haul")
		if flying != null and flying.flying_to(null) > 0:
			return
		var busy := false
		for dog in _main.get(&"_dogs"):
			if dog != null and dog.carrying() > 0:
				busy = true
		if busy:
			return
		for dog in _main.get(&"_dogs"):
			if dog != null:
				dog.set_process(false)
		# Everything after this is timed off `_ending_at` rather than off a fixed frame.
		_ending_at = _in_stage
		_check(not bool(_main.get(&"_cleaned")),
			"so an empty lake with a full net is not finished yet", "")
		_net.catch = PackedInt32Array()
		_check(bool(_main.call(&"_all_landed")),
			"and it is the moment the hold is empty that ends it", "")
		# The meter left high, as it was on any lake the dogs helped clear (2026-09-17):
		# the field is what answers, and a meter that never bottomed out must not hold the
		# ending back. And a dog's delivery moves the meter and asks at once.
		var total: float = _main.get(&"_filth_total")
		_main.set(&"_filth_left", 0.5 * total)
		_main.set(&"_clean_check_in", 99.0)
		_main.call(&"_dog_brought_back", 0)
		_check(float(_main.get(&"_filth_left")) < 0.5 * total,
			"a dog's delivery moves the meter", "%.2f of %.2f" % [_main.get(&"_filth_left"), total])
		_check(float(_main.get(&"_clean_check_in")) <= 0.0,
			"and a piece landing in the crate asks for the ending at once", "")
		return
	if _ending_at >= 0 and not _ending_done:
		# Waited for rather than counted to. `_check_cleaned` runs in `_process` and this
		# harness counts `_physics_process`, and headless catches physics up at its own rate
		# — three physics ticks can go by with no `_process` between them, which is why a
		# check written as "three frames later" failed about four runs in five. What is
		# under test is whether an empty lake ends at all, not how many frames it takes.
		if not bool(_main.get(&"_cleaned")) and _in_stage < _ending_at + 120:
			return
		_ending_done = true
		_check(bool(_main.get(&"_cleaned")),
			"an empty lake ends with the meter still high: the field answers, not the float",
			"pieces %d, landed %s, check in %.3f"
			% [_grid.piece_count(), str(_main.call(&"_all_landed")),
			float(_main.get(&"_clean_check_in"))])
		# The rest of the stage is timed from the moment it really ended.
		_ending_at = _in_stage
		return
	# Also what holds the frames between the setup and the settle: `_ending_at` is -1 until
	# the sky is clear, and every check below is timed from it.
	if _ending_at < 0 or _in_stage < _ending_at + 36:
		return
	_check(_grid.piece_count() == 0, "the lake is empty", "")
	# Nothing left to fill a hold with, so a part load goes rather than waiting for good.
	var held_was := _yard.held.duplicate()
	_yard.held = PackedInt32Array([0])
	_boat.set(&"_dry_check_in", 0.0)
	_check(_boat.ready_to_sail(0.0), "an empty lake sends a ferry off with a part load", "")
	_yard.held = held_was
	_check(bool(_main.get(&"_cleaned")),
		"an empty lake ends the run even with dust left on the meter", "")
	_check(is_zero_approx(float(_main.get(&"pollution"))),
		"and the meter is put to zero rather than left near it",
		"%.6f" % float(_main.get(&"pollution")))
	# Straight to the words and the end song (2026-09-18, Richard): no beat of clean water
	# in front of them and no struck note. The words' own slow fade is the breath.
	_check(_main.get_node_or_null(^"Farewell") != null,
		"the closing words are on screen the moment the run ends", "")
	_check(bool(_main.call(&"ending")),
		"and the end song is told to come in with them", "")
	_check(not _main.has_method(&"_count_the_beat") and _main.get(&"_ending_in") == null,
		"with no beat held in front of them", "")
	var sound_now := Sfx.main()
	_check(sound_now == null or not sound_now.has_method(&"play_found"),
		"and no bell rung over them", "")
	_check(not _angler.can_walk, "which holds the angler where they stand", "")
	var ending: Farewell = _main.get(&"_farewell")
	_check(ending != null and ending.rolling(),
		"and the credits are climbing under them", "")
	_check(ending != null and ending.get_child_count() >= 0
		and not CreditsBoard.LINES.is_empty(),
		"off the credits board's own words", "%d" % CreditsBoard.LINES.size())
	_check_credits()
	_check(_main.call(&"_last_pieces_line") == "",
		"and the note about leftovers is gone", "")
	_advance()


## The credits board's own words: every heading is a line, every line fits, and nothing is
## dropped at the smallest window the game supports.
##
## The board had no guard at all until 2026-09-19 (issue #27, the Godot line). The two
## things worth holding are not the wording — that is Richard's and the licences' — but the
## structure: a heading only means something if `HEADS` and `LINES` agree, and a credit only
## counts if it is drawn. `dropped_lines` is what says the second one.
func _check_credits() -> void:
	# Never added to the tree: nothing asked of it here needs `_ready`, and the mark's
	# reserved room is `CreditsBoard.icon_room`, which is static for exactly that reason.
	var board := CreditsBoard.new()
	board.size = Vector2(Prefs.LEAST_WINDOW)
	for head: String in CreditsBoard.HEADS:
		_check(CreditsBoard.LINES.has(head),
			"the credits heading \"%s\" is a line of the board" % head, "")
	_check(CreditsBoard.LINES.has("Made with Godot Engine")
		and CreditsBoard.HEADS.has("Tools"),
		"the engine is credited under a Tools heading", "")
	# Every name unique, so a pack cannot be thanked twice under two headings.
	var seen: Dictionary = {}
	var twice := ""
	for text: String in CreditsBoard.LINES:
		if text.is_empty():
			continue
		if seen.has(text):
			twice = text
		seen[text] = true
	_check(twice.is_empty(), "and no credit is said twice", twice)
	# The smallest window the game allows. Asked arithmetically rather than off a draw: the
	# settings board's `wanted_tall`, against the 680 a 720-high window leaves. `_draw`'s
	# own `dropped_lines` is the same fact at run time; this is the one the harness can ask
	# without waiting a frame in the middle of a stage.
	var wants: float = board.call(&"wanted_tall")
	_check(wants <= 680.0,
		"and every one of them fits the board at 1280x720", "%.0f of 680" % wants)
	board.queue_free()


## The ending of a run that was saved on its last catch and opened again.
##
## The second half of the same bug. Loading a save used to set "this run is finished" from
## the piece count alone, which is not the same fact as "the player has been thanked" — so
## a lake finished and reopened came back with the flag already set, the words still owed,
## and no way left to say them. A player who cleaned the whole basin and quit got nothing
## but a bright lake and silence.
## How far off vertical a shadow may lie before it reads as detached from its caster rather
## than cast by it. 60 degrees is a low sun with a long shadow; past that the shadow is
## mostly beside the thing instead of under it.
const SHADOW_FLATTEST := 60.0


## The sun: in the southeast all day, so every cast shadow falls to the left of its caster.
##
## The painted assets are lit from the right — the shed and the recycle box are measurably
## brighter down that side — and a lean that crossed zero would light the world from the
## northwest for half of every loop, putting every shadow on the same side as every
## highlight. So the guard is the sign over the whole cycle, not any one number: the three
## leans in day.tres are free to be retuned, and are not free to change side.
func _stage_sun() -> void:
	var day := DayCycle.new()
	add_child(day)
	var worst := -INF
	var worst_at := 0.0
	var flattest := 0.0
	var flattest_at := 0.0
	var lit := 0
	var dimmest := INF
	var dimmest_at := 0.0
	for step in 200:
		day.phase = float(step) / 200.0
		day.call(&"_settle")
		if day.tint.get_luminance() < dimmest:
			dimmest = day.tint.get_luminance()
			dimmest_at = day.phase
		if day.lean > worst:
			worst = day.lean
			worst_at = day.phase
		# How far off vertical the shadow lies. A shadow thrown much further sideways than
		# it is long comes away from the thing casting it — the shed's did, at 78 degrees,
		# when the lean and the stretch were set independently of each other.
		var off := rad_to_deg(atan2(absf(day.lean), maxf(day.stretch, 0.001) * 0.5))
		if off > flattest:
			flattest = off
			flattest_at = day.phase
		if day.ink > 0.0:
			lit += 1
	_check(worst < 0.0,
		"the sun stays in the southeast: every shadow leans left, all loop",
		"worst lean %.3f at phase %.2f" % [worst, worst_at])
	_check(flattest < SHADOW_FLATTEST,
		"and never lies so flat it comes away from its caster",
		"%.0f degrees off vertical at phase %.2f" % [flattest, flattest_at])
	_check(lit > 0, "the day is lit at all", "%d of 200 samples" % lit)
	# No night (2026-09-14): the darkest the loop gets is its late afternoon.
	var config: DayConfig = load(DayCycle.CONFIG_PATH)
	var late := config.tint.sample(config.sun_to).get_luminance()
	_check(dimmest >= late - 0.01, "there is no night: nothing in the loop is darker than late afternoon",
		"dimmest %.2f at phase %.2f, late afternoon %.2f" % [dimmest, dimmest_at, late])

	# The swept shadow, on a picture shaped like the ones that broke the sheared one: a V,
	# whose base is a single pixel at the bottom middle. A shear anchored anywhere leaves
	# every other column's shadow starting below its own base, which is the gap this
	# replaced. A sweep cannot: the drag starts at zero, so the silhouette is part of its own
	# shadow and the two share a border by construction.
	var vee := Image.create(9, 9, false, Image.FORMAT_RGBA8)
	vee.fill(Color(0, 0, 0, 0))
	for row in 9:
		for col in 9:
			if absf(float(col) - 4.0) <= float(8 - row) * 0.5:
				vee.set_pixel(col, row, Color.WHITE)
	var box := Rect2(Vector2(-18.0, -36.0), Vector2(36.0, 36.0))
	var cast := Shade.sweep(vee, box, -0.25, 0.48, 0.2)
	_check(cast.size() >= 3 and cast.size() % 3 == 0,
		"a swept shadow comes out as whole triangles", "%d points" % cast.size())
	var reach := Rect2(cast[0], Vector2.ZERO)
	for point in cast:
		reach = reach.expand(point)
	# It starts at the caster's own contact point, so there is no gap between a thing and its
	# shade. This is the property a shear cannot have on a V and the whole reason for the
	# sweep — guard it rather than the numbers, which are all free to be retuned.
	_check(reach.has_point(Vector2(box.get_center().x, box.end.y - 0.5)),
		"a swept shadow starts at the caster's own base, so no gap can open under it",
		"sweep %s against picture %s" % [reach, box])
	# It reaches past where it started, or nothing would be seen of the shadow at all. Past
	# the *contact point*, not past the whole picture: this V only touches down at its tip,
	# so its arms are overhangs and rightly cast nothing.
	var touches := Vector2(box.get_center().x, box.end.y)
	_check(reach.position.x < touches.x and reach.end.y > touches.y,
		"and reaches past the caster, down and to the left",
		"sweep %s from contact %s" % [reach, touches])
	# And nothing of it stands to the right of the picture. The drag goes down and left, so
	# anything on the right is an overhang casting onto ground a wall should have caught —
	# the hut's eaves threw shade onto the lit side of the building that way.
	_check(reach.end.x <= box.end.x + 0.5,
		"and none of it spills out on the sunlit side",
		"sweep ends at %.1f, picture at %.1f" % [reach.end.x, box.end.x])
	day.queue_free()
	# Walkers bury their feet by Iso.on_lawn; it must be the lawn Ground draws.
	var island := Ground.new()
	island.layer = Ground.Layer.ISLAND
	var disagree := 0
	for i in 64:
		var along := Iso.ISLAND_CENTRE + Vector2(float(i) * 0.15, float(i) * 0.08)
		if Iso.island_fraction(along.x, along.y) >= 1.0:
			break
		if Iso.on_lawn(along) != (island.kind_at(along.x, along.y) == Ground.Kind.GRASS):
			disagree += 1
	island.free()
	_check(disagree == 0, "feet are buried exactly where the island draws grass",
		"%d points disagree" % disagree)
	_advance()


func _stage_ending_on_load() -> void:
	if _in_stage == 1:
		# Put the closing words away and forget they were ever shown: what is being tested
		# is a finished lake arriving from disk, not one finishing in front of us.
		# Dismissed through the game's own door rather than by reaching in and nulling the
		# reference: the lake forgets the screen in _drop_farewell, and a test that forgets
		# it some other way is testing its own bookkeeping.
		_clear_farewell()
		# The ending this save is owed: an empty field and a flag that says nobody has been
		# thanked, which is a run saved on its last catch or lost to a crash before the
		# words arrived.
		_main.set(&"_farewell_shown", false)
		_main.set(&"_cleaned", false)
		_check(bool(_main.call(&"save_game")), "a finished lake can be saved", "")
		# And now something else entirely is in memory, so the load has work to do.
		_main.set(&"_cleaned", true)
		_grid.insert(_deep_tile(), 0, 0)
		_check(bool(_main.call(&"load_game")), "and read back", "")
		_check(_grid.piece_count() == 0, "the lake comes back empty",
			"%d pieces" % _grid.piece_count())
		_check(not bool(_main.get(&"_cleaned")),
			"a loaded lake has not dealt with its ending yet, finished or not", "")
		_main.set(&"_clean_check_in", 0.0)
		return
	if _in_stage == 40:
		_check(bool(_main.get(&"_cleaned")), "the ending catches up a frame later", "")
		_check(_main.get_node_or_null(^"Farewell") != null,
			"and the words the run was owed are on screen", "")
		_check(bool(_main.get(&"_farewell_shown")),
			"and the save is marked as having been thanked", "")
		var farewell: Node = _main.get(&"_farewell")
		_check(farewell != null and farewell.has_signal(&"to_menu")
			and farewell.is_connected(&"to_menu", Callable(_main, &"_quit")),
			"and it carries the door back to the menu", "")
		_check(String(_main.call(&"_next_scene")) == "",
			"and no door on to a siege", "%s" % _main.call(&"_next_scene"))
		# Now the same lake a second time, with the thanks already paid (2026-09-19). The
		# words and the roll are once per save: a continue into a finished lake is the lit
		# clean water and nothing written over it. The reason they used to come back every
		# sitting was the onward door to the siege living on that screen, and `_next_scene`
		# has returned "" since 2026-09-12.
		_clear_farewell()
		_main.set(&"_cleaned", false)
		_check(bool(_main.call(&"save_game")), "a thanked lake can be saved", "")
		_main.set(&"_cleaned", true)
		_grid.insert(_deep_tile(), 0, 0)
		_check(bool(_main.call(&"load_game")), "and read back", "")
		_main.set(&"_clean_check_in", 0.0)
		return
	if _in_stage < 80:
		return
	_check(bool(_main.get(&"_cleaned")),
		"a finished lake works its ending out again on the way back in", "")
	_check(float(_main.get(&"pollution")) == 0.0, "the meter is on the floor",
		"%f" % _main.get(&"pollution"))
	_check(_main.get_node_or_null(^"Farewell") == null
		and _main.get(&"_farewell") == null,
		"but the words and the credits are not shown a second time", "")
	_advance()


## Dismiss the closing words through the lake's own door and take the layer with them.
func _clear_farewell() -> void:
	var over := _main.get_node_or_null(^"Farewell")
	if over != null:
		_main.call(&"_drop_farewell")
		over.free()


## The clean patch a catch opens: sized to the catch, closing over PATCH_LIFE, capped.
func _stage_patch() -> void:
	var mouth := 40.0
	var reach := float(Iso.tile_circle_extent(float(_main.get(&"PATCH_REACH"))))
	_check(is_equal_approx(float(_main.call(&"patch_radius", 0, 3, mouth)), mouth),
		"a sweep that fills nothing of the hold clears just the mouth", "")
	_check(is_equal_approx(float(_main.call(&"patch_radius", 3, 3, mouth)), mouth + reach),
		"and a full hold clears the mouth plus the stain's reach", "")
	_check(float(_main.call(&"patch_radius", 1, 3, mouth)) < mouth + reach,
		"and one piece of three less than that", "")

	var patches: Array = _main.get(&"_patches")
	patches.clear()
	var life := float(_main.get(&"PATCH_LIFE"))
	var cap := int(_main.get(&"PATCHES"))
	_main.call(&"_on_net_swept", Vector2(100, 100), 1, 3, mouth, _net)
	_check(patches.size() == 1, "a sweep that took something opens a patch", "%d" % patches.size())
	_main.call(&"_on_net_swept", Vector2(120, 100), 2, 3, mouth, _net)
	_check(patches.size() == 2, "the same net sweeping on opens another",
		"%d" % patches.size())
	_check(float(patches[0]["seed"]) != float(patches[1]["seed"]),
		"with its own roll", "")
	patches.remove_at(1)
	var born := float(patches[0]["born"])
	var opening := float(_main.call(&"_patch_open", patches[0]))
	_check(opening < 0.5, "a patch opens rather than snapping open", "%.2f" % opening)
	patches[0]["born"] = born - float(_main.get(&"PATCH_IN"))
	_check(is_equal_approx(float(_main.call(&"_patch_open", patches[0])), 1.0),
		"and is fully open after PATCH_IN", "")
	patches[0]["born"] = born
	patches[0]["born"] = born - life * 0.5
	var half := float(_main.call(&"_patch_open", patches[0]))
	_check(half > 0.0 and half < 1.0, "half way through its life it is closing",
		"%.2f" % half)
	patches[0]["born"] = born - life * 1.01
	_main.call(&"_push_patches", 0.0)
	_check(patches.is_empty(), "and after PATCH_LIFE it is gone", "%d" % patches.size())

	var spare: Array[CastNet] = []
	for i in cap + 2:
		var net := CastNet.new()
		spare.append(net)
		_main.call(&"_on_net_swept", Vector2(i * 10.0, 0.0), 1, 3, mouth, net)
		_main.call(&"_push_patches", 0.001)
	_check(patches.size() == cap, "the patches are capped", "%d of %d" % [patches.size(), cap])
	var first_gone := true
	for patch in patches:
		if (patch["at"] as Vector2).x < 15.0:
			first_gone = false
	_check(first_gone, "and the oldest are the ones replaced", "")
	patches.clear()
	_main.call(&"_push_patches", 0.0)
	for net in spare:
		net.free()

	# The shader's arrays are literal sizes; the lake packs exactly PATCHES and LANE_POINTS,
	# and a mismatch drops the surplus silently (it did: 14 packed into patches[8]).
	var source: String = (load("res://shaders/water.gdshader") as Shader).code
	_check(source.contains("uniform vec4 patches[%d];" % cap),
		"the water shader holds PATCHES patches", "%d" % cap)
	var lane_cap := int(_main.get(&"LANE_POINTS"))
	_check(source.contains("uniform vec4 lane[%d];" % lane_cap),
		"and LANE_POINTS lane points", "%d" % lane_cap)
	_check(float(_main.get(&"PATCH_LIFE")) >= 4.0 and float(_main.get(&"PATCH_IN")) >= 0.4,
		"the grime gathers back slowly", "%.1f s, in over %.1f s"
		% [float(_main.get(&"PATCH_LIFE")), float(_main.get(&"PATCH_IN"))])

	# The lane: a reel with a catch aboard parts the grime along its path; an empty net,
	# or one not reeling, leaves none.
	var lane: Array = _main.get(&"_lane")
	lane.clear()
	var lane_net := CastNet.new()
	lane_net.grid = _grid
	lane_net.angler = _angler
	lane_net.state = CastNet.State.REELING
	lane_net.tile_pos = Vector2(46.0, 46.0)
	_main.call(&"_lay_lane", lane_net)
	_check(lane.is_empty(), "an empty net reeling parts no lane", "%d" % lane.size())
	lane_net.catch.append(0)
	lane_net.state = CastNet.State.FLYING
	_main.call(&"_lay_lane", lane_net)
	_check(lane.is_empty(), "nor a loaded one in flight", "%d" % lane.size())
	lane_net.state = CastNet.State.REELING
	_main.call(&"_lay_lane", lane_net)
	_check(lane.size() == 1, "a reel with a catch aboard starts a lane", "%d" % lane.size())
	_check(float(lane[0]["radius"]) < lane_net.mouth_extent(),
		"narrower than the mouth", "%.1f of %.1f" % [float(lane[0]["radius"]), lane_net.mouth_extent()])
	_main.call(&"_lay_lane", lane_net)
	_check(lane.size() == 1, "and drops nothing until it has moved", "%d" % lane.size())
	var spacing := float(_main.get(&"LANE_SPACING"))
	lane_net.tile_pos += Vector2(spacing * 1.1 / Iso.TILE_W, 0.0) * 2.0
	_main.call(&"_lay_lane", lane_net)
	_check(lane.size() == 2, "then another after LANE_SPACING", "%d" % lane.size())
	for i in lane_cap + 3:
		lane_net.tile_pos += Vector2(spacing * 1.1 / Iso.TILE_W, 0.0) * 2.0
		_main.call(&"_lay_lane", lane_net)
	_check(lane.size() == lane_cap, "capped at LANE_POINTS", "%d" % lane.size())
	lane[0]["born"] = float(lane[0]["born"]) - float(_main.get(&"LANE_LIFE")) * 1.01
	var seed_was := float(_main.get(&"_lane_seed"))
	lane_net.state = CastNet.State.IDLE
	_main.call(&"_lay_lane", lane_net)
	_main.call(&"_push_patches", 0.0)
	_check(lane.size() == lane_cap - 1, "a point past LANE_LIFE is gone", "%d" % lane.size())
	_check(float(_main.get(&"_lane_seed")) != seed_was,
		"and a reel ending rolls the next lane's shape", "")
	lane.clear()
	_main.call(&"_push_patches", 0.0)
	lane_net.free()
	_advance()


## The gamepad (issue #33): the input map, which hand is playing, the reticle and its assist,
## the camera leaning out to it, and the pointer only wanted over a board.
func _stage_pad() -> void:
	if _net.state != CastNet.State.IDLE:
		if _in_stage > 900:
			_check(false, "the net is home for the pad checks", "state %d" % _net.state)
			_finish()
		return
	var pad := get_node(^"/root/Pad")
	# The run before this one ended the lake: the closing words are up and the water is empty.
	var over := _main.get_node_or_null(^"Farewell")
	if over != null:
		_main.call(&"_drop_farewell")
		over.free()
	for pair: Array in [
		[&"walk_left", 0], [&"walk_right", 0], [&"walk_up", 1], [&"walk_down", 1],
		[&"aim_left", 2], [&"aim_right", 2], [&"aim_up", 3], [&"aim_down", 3],
		[&"cast", 5], [&"lay_net", 4],
	]:
		var found := false
		for event: InputEvent in InputMap.action_get_events(pair[0]):
			if event is InputEventJoypadMotion and (event as InputEventJoypadMotion).axis == pair[1]:
				found = true
		_check(found, "%s answers to its stick" % pair[0], "")
	for pair: Array in [
		[&"interact", JOY_BUTTON_A], [&"pad_back", JOY_BUTTON_B], [&"open_shed", JOY_BUTTON_X],
		[&"open_upgrades", JOY_BUTTON_Y], [&"open_settings", JOY_BUTTON_START],
		[&"recentre", JOY_BUTTON_RIGHT_STICK], [&"zoom_out", JOY_BUTTON_LEFT_SHOULDER],
		[&"zoom_in", JOY_BUTTON_RIGHT_SHOULDER],
		[&"shed_rotate", JOY_BUTTON_X], [&"shed_switch", JOY_BUTTON_Y],
	]:
		var found := false
		for event: InputEvent in InputMap.action_get_events(pair[0]):
			if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == pair[1]:
				found = true
		_check(found, "%s answers to its button" % pair[0], "")

	# The last hand wins, and neither a resting stick nor a nudged mouse counts.
	pad.call(&"set_mode", 0)
	var drift := InputEventJoypadMotion.new()
	drift.axis = JOY_AXIS_RIGHT_X
	drift.axis_value = 0.2
	pad.call(&"_input", drift)
	_check(int(pad.get(&"mode")) == 0, "a stick at rest does not take the game off the mouse", "")
	var shove := InputEventJoypadMotion.new()
	shove.axis = JOY_AXIS_RIGHT_X
	shove.axis_value = 0.9
	pad.call(&"_input", shove)
	_check(int(pad.get(&"mode")) == 1, "a stick pushed does", "")
	var nudge := InputEventMouseMotion.new()
	nudge.relative = Vector2(1, 0)
	pad.call(&"_input", nudge)
	_check(int(pad.get(&"mode")) == 1, "a mouse nudged a pixel does not take it back", "")

	_check(not bool(_main.call(&"pad_cursor_wanted")), "no pointer wanted on the bare lake", "")
	_main.call(&"_set_menu", true)
	_check(bool(_main.call(&"pad_cursor_wanted")), "a pointer wanted over the upgrades", "")
	_main.call(&"_set_menu", false)

	var aim: PadAim = _main.get(&"_aim")
	_main.call(&"_pad_tick", 0.016)
	_check(aim.at != Vector2.INF, "pad mode puts a reticle on the lake", "")
	_check(_net.aim_point() == aim.at and _main.call(&"aim_point") == aim.at,
		"and the marker and the cast both aim at it", "")

	# A spot short of green with green nearby, found by walking out from a liftable piece.
	var cell := _grid.tile_at(_water_near_angler())
	if cell >= 0 and _grid.reachable_slot(cell, 1, _net.power) < 0:
		_grid.insert(cell, 0, 0)
	var view := Rect2(_angler.position - Vector2(2000, 2000), Vector2(4000, 4000))
	var reach := maxf(_net.open_extent() * PadAim.REACH, Iso.tile_circle_extent(PadAim.REACH_LEAST))
	var start := Vector2.INF
	var spot := Vector2.INF
	if cell >= 0:
		var piece := _grid.surface_pos(cell)
		for ring in range(1, 12):
			for step in 16:
				var angle := TAU * float(step) / 16.0
				var tried := piece + Vector2(cos(angle), sin(angle) * 0.5) * _net.open_extent() * (1.0 + ring * 0.15)
				if _net.would_catch(tried) or not _net.can_cast_to(tried):
					continue
				var found := _net.nearest_catch(tried, reach)
				if found != Vector2.INF:
					start = tried
					spot = found
					break
			if start != Vector2.INF:
				break
	_check(start != Vector2.INF, "a spot short of green with green in reach", "")
	if start != Vector2.INF:
		_check(_net.would_catch(spot), "the spot the assist finds is green by the marker's own test", "")
		aim.at = start
		aim.step(0.1, Vector2.ZERO, view, _net)
		_check(aim.at == start, "a still stick leaves the reticle where it is, green nearby or not", "")
		var toward := (spot - start).normalized()
		var sideways := Vector2(-toward.y, toward.x)
		aim.at = start
		aim.step(0.02, sideways * 0.5, view, null)
		var bare := aim.at
		aim.at = start
		aim.step(0.02, sideways * 0.5, view, _net)
		_check(aim.pulled_to != Vector2.INF and aim.at.distance_to(spot) < bare.distance_to(spot),
			"a stick pushed past green bends the aim towards it", "")
		aim.at = start
		aim.step(0.02, -toward, view, _net)
		_check(aim.pulled_to == Vector2.INF, "but never back against the push", "")
		aim.at = spot
		aim.step(0.02, toward * 0.5, view, null)
		var free := aim.at.distance_to(spot)
		aim.at = spot
		aim.step(0.02, toward * 0.5, view, _net)
		_check(aim.over_green and aim.at.distance_to(spot) < free,
			"and over green it slows", "%.2f of %.2f" % [aim.at.distance_to(spot), free])

	# The edge pushes a reticle the view left behind, and the view never leaves the angler.
	var shown: Rect2 = _main.call(&"_visible_world_rect")
	aim.at = shown.end + Vector2(5000, 5000)
	aim.hold_in(shown, 1.0)
	_check(shown.has_point(aim.at), "the window's edge holds the reticle on screen", "")
	aim.at = _angler.position + Vector2(100000, 0)
	var framed: Vector2 = _main.call(&"_pad_framed", _angler.position)
	var half := shown.size * 0.5
	_check(absf(framed.x - _angler.position.x) <= half.x,
		"leaning out to a far reticle keeps the angler on screen", "")
	aim.at = _angler.position + Vector2(shown.size.x * 0.1, 0)
	framed = _main.call(&"_pad_framed", _angler.position)
	_check(framed.is_equal_approx(_angler.position), "and a reticle near the middle moves nothing", "")

	pad.call(&"set_mode", 0)
	_main.call(&"_pad_tick", 0.016)
	_check(aim.at == Vector2.INF and _net.pad_aim == Vector2.INF,
		"back on the mouse, the reticle is gone", "")
	_advance()


## The music station (2026-09-15): the playlist's order and its cut, the handover, the shed
## and the radio as fades over a playlist that keeps running, the end song coming and going,
## and the lake telling the autoload where the player is. Its own station, driven by hand:
## the dummy audio driver gives the players no clock.
func _stage_music() -> void:
	var music := MusicStation.new()
	music.follow_players = false
	add_child(music)
	var fade := MusicStation.FADE
	_check(music.now_playing() == &"beatgucci", "the station opens on beatgucci",
		"%s" % music.now_playing())
	var cut := float(music.call(&"_length", 0))
	_check(absf(cut - 132.0) < 0.2, "beatgucci stops at 2:12", "%.2f s" % cut)
	_run_music(music, cut - fade - 1.0)
	var g := music.gains()
	_check(is_equal_approx(float(g["beatgucci"]), 1.0) and is_zero_approx(float(g["save_me"]))
		and not music.is_playing(&"save_me"),
		"a second before the handover, only beatgucci is heard", "%s" % g)
	_run_music(music, 1.0 + fade * 0.5)
	g = music.gains()
	var out := float(g["beatgucci"])
	var into := float(g["save_me"])
	_check(is_equal_approx(out, 1.0) and into > 0.1 and into < 0.9
		and music.is_playing(&"beatgucci") and music.is_playing(&"save_me"),
		"the next song comes up under one that is still playing whole",
		"out %.2f in %.2f" % [out, into])
	_check(out * out + into * into < 1.6,
		"and the two together are no louder than about a decibel over one song",
		"%.2f" % (out * out + into * into))
	_run_music(music, fade * 0.5 - MusicStation.FADE_OUT - 0.2)
	_check(float(music.gains()["beatgucci"]) > 0.95,
		"the song on its way out is whole until its own last seconds",
		"%.3f" % float(music.gains()["beatgucci"]))
	_run_music(music, MusicStation.FADE_OUT + 0.7)
	g = music.gains()
	_check(music.now_playing() == &"save_me" and not music.is_playing(&"beatgucci")
		and is_equal_approx(float(g["save_me"]), 1.0),
		"then Save ME leads and beatgucci has stopped", "%s" % music.now_playing())
	var round_trip := float(music.call(&"_length", 1)) + float(music.call(&"_length", 2))
	_run_music(music, float(music.call(&"_length", 1)))
	_check(music.now_playing() == &"goin", "Goin comes third", "%s" % music.now_playing())
	_run_music(music, round_trip - float(music.call(&"_length", 1)))
	_check(music.now_playing() == &"beatgucci", "and the playlist goes round to beatgucci",
		"%s" % music.now_playing())

	music.indoors = true
	_run_music(music, 0.4)
	g = music.gains()
	_check(is_equal_approx(float(g["indie_boi_radio"]), 1.0)
		and is_zero_approx(float(g["beatgucci"])) and music.is_playing(&"beatgucci")
		and music.is_playing(&"indie_boi"),
		"indoors, Indie Boi through the wall, the playlist running muted under it", "%s" % g)
	music.indoors = false
	music.muffled = true
	_run_music(music, 0.4)
	g = music.gains()
	_check(is_equal_approx(float(g["beatgucci_radio"]), 1.0)
		and is_zero_approx(float(g["beatgucci"])) and is_zero_approx(float(g["indie_boi_radio"])),
		"a board open: the lake's own song through the radio", "%s" % g)
	music.muffled = false
	_run_music(music, 0.4)

	music.set_ending(true)
	_run_music(music, fade * 0.5)
	g = music.gains()
	_check(float(g["habibs"]) > 0.2 and float(g["habibs"]) < 0.9 and music.is_playing(&"habibs"),
		"the end song fades in over the playlist", "%s" % g)
	_run_music(music, fade * 0.5 + 0.2)
	var at := music.song_time()
	g = music.gains()
	_check(is_equal_approx(float(g["habibs"]), 1.0) and is_zero_approx(float(g["beatgucci"]))
		and music.is_playing(&"beatgucci"),
		"and has the whole of it, the playlist still running under", "%s" % g)
	music.set_ending(false)
	_run_music(music, fade + 0.2)
	g = music.gains()
	_check(is_zero_approx(float(g["habibs"])) and not music.is_playing(&"habibs")
		and is_equal_approx(float(g["beatgucci"]), 1.0) and music.song_time() > at,
		"closing it fades back to the playlist where it has got to", "%s" % g)
	music.queue_free()

	var station := MusicStation.main()
	_check(station != null, "the station is an autoload", "")
	if station != null:
		_main.call(&"_set_shed", true)
		_check(station.indoors and not station.muffled, "the shed tells the station", "")
		_main.call(&"_set_shed", false)
		_main.call(&"_set_settings", true)
		_check(station.muffled and not station.indoors, "so does the settings board", "")
		_main.call(&"_set_settings", false)
		_main.call(&"_set_menu", true)
		_check(station.muffled, "and the upgrades board", "")
		_main.call(&"_set_menu", false)
		_check(not station.muffled and not station.indoors, "and closing them lets go", "")

	# The board covers the lake, so the lake goes quiet behind it — all but the money.
	var sound := Sfx.main()
	if sound != null:
		_main.call(&"_set_menu", true)
		_check(sound.shopping and not sound.may_play(&"bark")
			and not sound.may_play(&"net_splash") and not sound.may_play(&"pigeon_fly"),
			"the upgrades board holds the lake's own sounds", "")
		_check(sound.may_play(&"coin") and sound.may_play(&"upgrade"),
			"the money is still heard through it", "")
		_main.call(&"_set_menu", false)
		_check(not sound.shopping and sound.may_play(&"bark"),
			"and closing the board gives the lake its noise back", "")
		_check_audio_pass(sound)
	_advance()


## The 2026-09-16 audio pass (issue #1): the knock is cut, the wading loop is shared, and a
## ferry is heard coming home as well as leaving.
func _check_audio_pass(sound: Sfx) -> void:
	_check(not sound.has_method(&"play_catch"),
		"the catch knock is gone, not quietened", "")
	_check(sound.has_method(&"play_berth"),
		"a ferry coming alongside the island has a sound of its own", "")
	_check(Sfx.BERTH_BELL_GAP > Sfx.BELL_GAP,
		"and its bell is sparser than the one it leaves on",
		"%.0f s against %.0f" % [Sfx.BERTH_BELL_GAP, Sfx.BELL_GAP])

	# One wading loop, four dogs and an angler: a boolean set by whoever pushed last would
	# be turned off by a dog on the lawn while the angler stood in the water.
	var dogs: Array = _main.get(&"_dogs")
	var dog: Dog = dogs[0] as Dog if not dogs.is_empty() else null
	sound.set_wading(false, _angler)
	sound.set_wading(true, _angler)
	sound.set_wading(true, dog)
	sound.set_wading(false, dog)
	_check(bool(sound.get(&"_wade_on")),
		"a dog leaving the water does not take the angler's wading with it", "")
	sound.set_wading(false, _angler)
	_check(not bool(sound.get(&"_wade_on")),
		"and the wash stops when the last of them is out of it", "")
	# A dog swimming out of earshot pushes no wash: there is one wading loop at one level,
	# and a bank run across the lake played it under an angler standing still.
	if dog != null and dog.angler != null:
		var dog_was := dog.tile_pos
		var speed_was: float = dog.get(&"_speed")
		var out := dog.angler.tile_pos
		var way := (Vector2(Iso.COLS, Iso.ROWS) * 0.5 - out).normalized()
		if way == Vector2.ZERO:
			way = Vector2(1.0, 0.0)
		way = -way
		var near_wet := out
		for i in 200:
			near_wet += way * 0.1
			if Iso.past_water(near_wet) > Angler.WADE_IN:
				break
		dog.set(&"_speed", 5.0)
		dog.tile_pos = near_wet
		var in_earshot := near_wet.distance_to(out) <= Dog.HEAR
		dog.call(&"_push_wade")
		_check(not in_earshot or bool(sound.get(&"_wade_on")),
			"a dog swimming beside the angler pushes the wash", "")
		dog.tile_pos = out + way * (Dog.HEAR + 8.0)
		dog.call(&"_push_wade")
		_check(Iso.past_water(dog.tile_pos) > Angler.WADE_IN and not bool(sound.get(&"_wade_on")),
			"and one swimming out of earshot pushes none", "")
		dog.tile_pos = dog_was
		dog.set(&"_speed", speed_was)
		sound.set_wading(false, dog)
	_check(dog != null and dog.has_method(&"carrying"),
		"a dog says what is in its mouth, so the ending can wait for it", "")

	# A ferry landing its hold at a pier is silent: that volley is a whole hold going into a
	# box across the lake, several times a minute, and the coins are what say it landed. The
	# angler's own throws into the island crate keep the thud.
	var haul: Haul = _main.get(&"_haul")
	var yard_here: Dropoff = (_main.get(&"_dropoffs") as Array)[0]
	# `play_pop` steps the crate thud's pitch every time it fires, so the step table is what
	# says whether it sounded at all.
	sound.set(&"_pitch_step", {})
	haul.set(&"_pop_at", -1000.0)
	haul.call(&"_pop", yard_here)
	_check(not bool((sound.get(&"_pitch_step") as Dictionary).has(&"pop")),
		"a ferry landing at a pier knocks no box", "")
	haul.set(&"_pop_at", -1000.0)
	haul.call(&"_pop", null)
	_check(bool((sound.get(&"_pitch_step") as Dictionary).has(&"pop")),
		"but the angler's own throw into the crate still does", "")

	# The crate's thud is its own recording, in three takes, one of which is played per drop
	# and never the one played last (2026-09-17). The shed's furniture thud is untouched and
	# is still its own file.
	_check(sound.call(&"_count", &"pop") == 3,
		"the crate's thud loaded its three takes", "%d" % sound.call(&"_count", &"pop"))
	_check(sound._first(&"pop") != sound._first(&"drop_big"),
		"and the shed's furniture thud is still a recording of its own", "")
	var repeated := false
	var picked := -1
	for i in 40:
		var step := int(sound.call(&"next_step", &"pop", 3))
		if step == picked:
			repeated = true
		picked = step
	_check(not repeated, "no take follows itself", "")
	# Its own name, so the room's allow-list refuses it with the rest of the lake while the
	# shed is open, and lets the furniture's own thud through.
	sound.indoors = true
	_check(not sound.may_play(&"pop"), "the crate is not heard from inside the shed", "")
	_check(sound.may_play(&"drop_big"), "but a piece set down in the room is", "")
	sound.indoors = false

	# A landing says whether it caught (2026-09-18): the net splash's ladder is split, the
	# low half for a landing that took something and the high half, quieter, for bare water.
	var lowest_empty := 100.0
	for step in Sfx.NET_SPLASH_EMPTY:
		lowest_empty = minf(lowest_empty, step)
	var highest_caught := 0.0
	for step in Sfx.NET_SPLASH_CAUGHT:
		highest_caught = maxf(highest_caught, step)
	_check(highest_caught < lowest_empty,
		"every catching landing is pitched under every empty one",
		"%.2f under %.2f" % [highest_caught, lowest_empty])
	_check(Sfx.NET_SPLASH_CAUGHT.size() >= 6 and Sfx.NET_SPLASH_EMPTY.size() >= 6,
		"and either kind has as many steps as every cast had before", "")
	_check(Sfx.EMPTY_SPLASH_DB < 0.0, "an empty landing is the quieter one", "")
	sound.set(&"_pitch_step", {})
	sound.play_landing(false)
	var steps: Dictionary = sound.get(&"_pitch_step")
	_check(steps.has(&"net_splash_empty") and not steps.has(&"net_splash_caught"),
		"a landing on bare water steps the empty ladder alone", "")
	sound.play_landing(true)
	_check(steps.has(&"net_splash_caught"), "and one that caught steps the other", "")
	var net_source := FileAccess.get_file_as_string("res://scripts/net.gd")
	var sweep_at := net_source.find("_sweep(true)")
	var landing_at := net_source.find("sfx.play_landing(")
	_check(sweep_at >= 0 and landing_at > sweep_at,
		"the landing sweeps before it sounds, so the sound knows what was caught", "")

	# The catch is answered with one swell and then water draining off the mesh: drips at
	# times of their own, rolled, so no two catches are the same and none is a row of pops
	# (2026-09-18, the second pass; the first was a counted run on a fixed beat).
	_check(not sound.has_method(&"run_length") and sound.get(&"_run") == null,
		"the counted run of splashes is gone, not loosened", "")
	_check(sound.call(&"_count", &"drip") == 4,
		"the drips loaded their four takes", "%d" % sound.call(&"_count", &"drip"))
	var one: Array[float] = [0.3]
	var bag: Array[float] = []
	for i in 24:
		bag.append(0.2 + 0.02 * float(i))
	_check(Sfx.swell_size(bag) > Sfx.swell_size(one) + 0.3 and Sfx.swell_size(bag) <= 1.0,
		"a full bag is a much bigger swell than one bottle",
		"%.2f against %.2f" % [Sfx.swell_size(bag), Sfx.swell_size(one)])
	var most := 0
	var fewest := 100
	var uneven := false
	var layouts := {}
	for cast in 30:
		_forget_catch(sound)
		sound.play_lifted(bag)
		var owed: Array = sound.get(&"_drips")
		most = maxi(most, owed.size())
		fewest = mini(fewest, owed.size())
		var waits: Array[float] = []
		for drip: Dictionary in owed:
			waits.append(float(drip["wait"]))
		waits.sort()
		layouts[str(waits)] = true
		if waits.size() >= 3 and not is_equal_approx(waits[1] - waits[0], waits[2] - waits[1]):
			uneven = true
		if cast == 0:
			_check(float(sound.get(&"_swell_wait")) >= Sfx.SWELL_AFTER.x,
				"a landing is owed one swell, behind the net's own splash", "")
	_check(most <= Sfx.DRIPS_MOST and most > fewest,
		"the drips are rolled, never more than the cap and not the same count every cast",
		"%d to %d over thirty casts" % [fewest, most])
	_check(uneven, "and they land on no beat", "")
	_check(layouts.size() > 20, "no two catches drain alike",
		"%d layouts in thirty casts" % layouts.size())
	# Two nets down together are one body of water.
	_forget_catch(sound)
	sound.play_lifted(one)
	var first_wait := float(sound.get(&"_swell_wait"))
	sound.play_lifted(bag)
	_check(is_equal_approx(float(sound.get(&"_swell_wait")), first_wait)
		and is_equal_approx(float(sound.get(&"_swell_size")), Sfx.swell_size(bag)),
		"a second net landing with the first joins its swell, as big as the bigger", "")
	for i in 10:
		sound.play_lifted(bag)
	_check((sound.get(&"_drips") as Array).size() <= Sfx.DRIPS_WAITING_MOST,
		"and the drips waiting are capped", "")
	sound.call(&"_tick_catch", Sfx.SWELL_AFTER.y + 0.01)
	_check(float(sound.get(&"_swell_wait")) < 0.0, "the swell sounds once and is spent", "")
	# A grab on the way home is a plip, never a swell, and no more than one in GRAB_GAP.
	_forget_catch(sound)
	sound.set(&"_pitch_step", {})
	sound.play_grab(bag)
	_check(float(sound.get(&"_swell_wait")) < 0.0 and (sound.get(&"_drips") as Array).is_empty(),
		"a grab on the reel owes no swell and no drips", "")
	_check((sound.get(&"_pitch_step") as Dictionary).has(&"drip"), "it plips", "")
	sound.set(&"_pitch_step", {})
	sound.play_grab(bag)
	_check(not (sound.get(&"_pitch_step") as Dictionary).has(&"drip"),
		"and a second grab inside the gap is not another", "")
	# The shop over the lake drops what was owed and queues nothing.
	_forget_catch(sound)
	sound.play_lifted(bag)
	sound.shopping = true
	sound.call(&"_tick_catch", 0.016)
	_check(float(sound.get(&"_swell_wait")) < 0.0 and (sound.get(&"_drips") as Array).is_empty(),
		"a board opening over the lake drops what was left of a catch", "")
	sound.play_lifted(bag)
	_check(float(sound.get(&"_swell_wait")) < 0.0 and (sound.get(&"_drips") as Array).is_empty(),
		"and nothing is queued behind one", "")
	sound.shopping = false
	_forget_catch(sound)

	# An empty net coming home is near silent; the load is what brings the haul up.
	var state_was: int = _net.state
	var catch_was := _net.catch.duplicate()
	_net.state = CastNet.State.REELING
	_net.catch.resize(0)
	var bare := float(_main.call(&"_net_wash"))
	_net.catch.resize(maxi(_net.hold, 1))
	var full := float(_main.call(&"_net_wash"))
	_net.catch = catch_was
	_net.state = state_was
	_check(bare > 0.0 and bare <= Lake.EMPTY_WASH and Lake.EMPTY_WASH < 0.2,
		"an empty reel is a whisper", "%.2f" % bare)
	_check(full > bare * 4.0, "and a full one is several times it", "%.2f against %.2f" % [full, bare])

	# Every recording is levelled by the builder now, so what SOUNDS holds is the mix. A
	# figure far outside the band is a take that was never rebuilt.
	var loudest := -100.0
	var quietest := 100.0
	for name: StringName in Sfx.SOUNDS:
		var db := float(Sfx.SOUNDS[name][0])
		loudest = maxf(loudest, db)
		quietest = minf(quietest, db)
	_check(loudest <= 0.0, "no sound in the mix is asked for above nought",
		"%.1f dB" % loudest)
	_check(quietest > -60.0, "and none is written down as silence", "%.1f dB" % quietest)


## Drive a hand-held station on by `seconds`, a frame at a time.
func _run_music(music: MusicStation, seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var dt := minf(0.05, left)
		music.step(dt)
		left -= dt


func _finish() -> void:
	_log("test_lake: %d checks, %d failed" % [_ran, _failed])
	_advance()
	get_tree().quit(1 if _failed > 0 else 0)


## Esc, as the game sees it.
func _press_escape() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	_main.call(&"_unhandled_input", key)


## Any def made of this material. The tests need a piece of a known kind and do not care
## which one.
func _def_of(kind: int) -> int:
	for i in _grid.defs.size():
		if _grid.defs[i].material == kind:
			return i
	return 0


func _collect_bodies(node: Node, into: Array[String]) -> void:
	if node is PhysicsBody2D or node is Area2D:
		into.append(str(node.name))
	for child in node.get_children():
		_collect_bodies(child, into)


## Walks for Controls that would intercept the click. Buttons are exempt: taking the click
## is their entire job, and the shop is built out of them.
func _find_greedy_controls(node: Node, into: Array[String]) -> void:
	var control := node as Control
	if control != null and control.mouse_filter == Control.MOUSE_FILTER_STOP \
			and not control is BaseButton and not control is Range \
			and not control is UiButton and not control is CloseButton \
			and not control is PlankButton \
			and not CLICK_EATERS.has(str(control.name)):
		into.append(str(control.name))
	for child in node.get_children():
		_find_greedy_controls(child, into)


## The free camera (2026-09-20): the toggle beside the gear pins the view, and neither a cast
## nor a step takes it back. The pointer is declared out of the window for the pinning checks
## — a headless pointer sits at the origin, which is an edge.
func _check_free_view(cam: Camera2D) -> void:
	var button: PlankButton = _main.get(&"_free_camera")
	var gear: PlankButton = _main.get(&"_open_settings")
	_check(button != null and button.mark == &"camera" and button.label.is_empty(),
		"the free camera toggle is a camera and carries no word",
		str(button.mark if button != null else &""))
	if button == null:
		return
	_check(button.size == gear.size and absf(button.position.y - gear.position.y) < 0.5
		and button.position.x + button.size.x <= gear.position.x,
		"and stands beside the gear, to its left, at the gear's size",
		"%s at %s, gear %s at %s" % [button.size, button.position, gear.size, gear.position])
	_check(not _main.get(&"_free_view") and not button.lit,
		"a session starts following, the toggle unlit", "")
	_main.set(&"_mouse_inside", false)
	var stood: Vector2 = _angler.tile_pos
	for i in 120:
		_main._process(1.0 / 60.0)
	_main.call(&"_toggle_free_view")
	_check(_main.get(&"_free_view") and button.lit, "a press turns it on and lights it", "")
	# A step and a cast both ask for the view back; neither gets it.
	var pinned := cam.position
	_angler.tile_pos = stood + Vector2(1.5, 0.0)
	_main.set(&"_pan_yielded", true)
	_main.set(&"_cast_look", Lake.CAST_LOOK)
	for i in 180:
		_main._process(1.0 / 60.0)
	_check(cam.position.distance_to(pinned) < 1.0,
		"free, the view stays put through a step and a cast",
		"%.1f px off after 3 s" % cam.position.distance_to(pinned))
	# The drag and the wheel's hold both move the pinned spot.
	var spot := pinned + Vector2(200.0, 80.0)
	_main.call(&"_keep_view_at", spot)
	for i in 60:
		_main._process(1.0 / 60.0)
	_check(cam.position.distance_to(spot) < 1.0, "a wheel zoom's hold moves the pinned spot",
		"%.1f px off" % cam.position.distance_to(spot))
	# The edges: nothing in the middle, a whole push at the very edge, each axis alone.
	var window := Vector2(1280.0, 720.0)
	var middle: Vector2 = Lake._edge_push(window * 0.5, window)
	var left: Vector2 = Lake._edge_push(Vector2(0.0, 360.0), window)
	var corner: Vector2 = Lake._edge_push(window, window)
	var inside: Vector2 = Lake._edge_push(Vector2(Lake.EDGE_MARGIN + 1.0, 360.0), window)
	_check(middle == Vector2.ZERO and inside == Vector2.ZERO
		and left.is_equal_approx(Vector2(-1.0, 0.0)) and corner.is_equal_approx(Vector2.ONE),
		"the window's edges push the view and its middle does not",
		"middle %s inside %s left %s corner %s" % [middle, inside, left, corner])
	_check((_main.call(&"_edge_scroll") as Vector2) == Vector2.ZERO,
		"and a pointer out of the window pushes nothing", "")
	# Pushed far past the ground, the pinned spot is clamped with the view.
	_main.set(&"_free_at", Vector2(90000.0, 0.0))
	for i in 5:
		_main._process(1.0 / 60.0)
	var held: Vector2 = _main.get(&"_free_at")
	_check(held.is_equal_approx(_main.call(&"_clamped_view", held)) and held.x < 90000.0,
		"the pinned spot is clamped to the ground", str(held))
	# Recentre looks at the angler and stays free.
	_main.call(&"_recentre")
	for i in 180:
		_main._process(1.0 / 60.0)
	var home: Vector2 = _main.call(&"_clamped_view", _angler.position)
	_check(_main.get(&"_free_view") and cam.position.distance_to(home) < 2.0,
		"recentre puts a free view on the angler and leaves it free",
		"%.1f px off" % cam.position.distance_to(home))
	# Off again, the follow brings the view home from wherever it was left.
	_main.call(&"_keep_view_at", home + Vector2(250.0, 0.0))
	_main.call(&"_toggle_free_view")
	_main.set(&"_cast_look", 0.0)
	for i in 240:
		_main._process(1.0 / 60.0)
	_check(not button.lit and cam.position.distance_to(home) < 2.0,
		"switched off, the view comes home to the angler",
		"%.1f px off" % cam.position.distance_to(home))
	_angler.tile_pos = stood
	_main.set(&"_pan", Vector2.ZERO)
	_main.set(&"_mouse_inside", true)


func _check(ok: bool, what: String, detail: String) -> void:
	_ran += 1
	if not ok:
		_failed += 1
	_log("%s %s%s" % ["ok  " if ok else "FAIL", what, "" if detail.is_empty() else "  (%s)" % detail])


func _log(line: String) -> void:
	printerr(line)
	var f := FileAccess.open(
		LOG_PATH,
		FileAccess.READ_WRITE if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE
	)
	if f == null:
		return
	f.seek_end()
	f.store_line(line)
	f.flush()
	f.close()


## The pointer and the aim ring (2026-09-16).
##
## The wooden arrow is one picture set once at boot, so what is guarded here is that the art
## is there, that its outline and its tip are where `Pad.CURSOR_TIP` says, and that putting
## it on does not throw. The ring's three colours are the palette's own, so they are guarded
## against the palette rather than against three numbers written down twice: repaint the pack
## and this says so.
func _stage_pointer() -> void:
	_check(ResourceLoader.exists(Pad.CURSOR_ART), "the wooden cursor's art is in the project",
		Pad.CURSOR_ART)
	var art := load(Pad.CURSOR_ART) as Texture2D
	_check(art != null, "and it loads as a texture", "")
	if art != null:
		var pic := art.get_image()
		var tip := Vector2i(Pad.CURSOR_TIP)
		_check(tip.x < pic.get_width() and tip.y < pic.get_height(),
			"the hotspot is inside the picture",
			"tip %s in %dx%d" % [tip, pic.get_width(), pic.get_height()])
		_check(pic.get_pixelv(tip).a > 0.5, "and it lands on the arrow, not beside it",
			"alpha %.2f" % pic.get_pixelv(tip).a)
		# The outline: the tip is one pixel in from each edge, so the corner it was inset
		# from is the black rim, and the corner beyond the arrow's widest row is open air.
		var rim := pic.get_pixelv(Vector2i.ZERO)
		_check(rim.a > 0.5 and rim.r < 0.1 and rim.g < 0.1 and rim.b < 0.1,
			"the arrow keeps a standard cursor's black outline", "%s" % rim)
		var wood := 0
		var black := 0
		for y in pic.get_height():
			for x in pic.get_width():
				var at := pic.get_pixel(x, y)
				if at.a < 0.5:
					continue
				if at.r < 0.1 and at.g < 0.1 and at.b < 0.1:
					black += 1
				elif at.r > at.b:
					wood += 1
		_check(wood > black and black > 0, "and it is wood inside that outline",
			"%d wood, %d rim" % [wood, black])
	# Putting it on must not throw, with or without art.
	Pad.wear_wood()
	_check(not FileAccess.file_exists("res://assets/cursor_press.png"),
		"the beaded second picture is gone, not just unused", "")

	# The click is answered by a ripple on its own layer, which is the thing a hardware
	# cursor cannot be.
	var ripples := Pad.ripples
	_check(ripples != null and ripples.get_parent() is CanvasLayer,
		"the click's ripple has a layer of its own", "")
	if ripples != null:
		_check((ripples.get_parent() as CanvasLayer).layer == Pad.RIPPLE_LAYER
			and Pad.RIPPLE_LAYER > Lake.BIRD_LAYER,
			"over everything the pointer can be over",
			"layer %d against the pigeons' %d" % [Pad.RIPPLE_LAYER, Lake.BIRD_LAYER])
		_check(ripples.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"and never in the way of what is under the pointer", "")
		# A zero-sized CanvasItem is culled before it is drawn, whatever its _draw puts out.
		_check(ripples.size.x > 0.0 and ripples.size.y > 0.0
			and ripples.size.is_equal_approx(get_viewport().get_visible_rect().size),
			"it is the size of the canvas, or nothing of it would be drawn",
			"%s against %s" % [ripples.size, get_viewport().get_visible_rect().size])
		var before: int = ripples.get(&"_splashes").size()
		ripples.splash(Vector2(120.0, 80.0))
		_check(ripples.get(&"_splashes").size() == before + 1 and ripples.is_processing(),
			"a click rings the water", "")
		# It is quick, by the ask: over well inside half a second, and gone from the list.
		var over := ClickRipple.LIFE + ClickRipple.STAGGER * float(ClickRipple.RINGS - 1)
		_check(over < 0.5, "and it is quick", "%.2f s" % over)
		for i in 60:
			ripples.call(&"_process", over / 30.0)
		_check(ripples.get(&"_splashes").is_empty() and not ripples.is_processing(),
			"the ring dies on its own and stops the redraws with it", "")
		for i in ClickRipple.MOST + 4:
			ripples.splash(Vector2(float(i), 0.0))
		_check(ripples.get(&"_splashes").size() <= ClickRipple.MOST,
			"a held button cannot grow the list without end",
			"%d of %d" % [ripples.get(&"_splashes").size(), ClickRipple.MOST])
		ripples.get(&"_splashes").clear()
	# No pointer, no ripple: pad mode on the bare lake hides the mouse. Driven through Pad's
	# own record of that, because the dummy display driver does not take a mouse mode.
	var was: int = Pad.get(&"_shown")
	Pad.set(&"_shown", Input.MOUSE_MODE_HIDDEN)
	Pad.ring_water()
	_check(ripples == null or ripples.get(&"_splashes").is_empty(),
		"nothing rings where there is no pointer to ring under", "")
	Pad.set(&"_shown", was)
	Pad.ring_water()
	_check(ripples == null or not ripples.get(&"_splashes").is_empty(),
		"and it rings again once there is", "")
	if ripples != null:
		ripples.get(&"_splashes").clear()

	var palette := Palette.master()
	_check(palette != null, "the palette the ring is toned off loads", "")
	if palette != null:
		var green := palette.grass_light * CastNet.AIM_LIFT
		var red := palette.wood * CastNet.AIM_LIFT
		_check(absf(CastNet.AIM_OK.r - green.r) < 0.01
			and absf(CastNet.AIM_OK.g - green.g) < 0.01
			and absf(CastNet.AIM_OK.b - green.b) < 0.01,
			"the ring's green is the pack's own grass, lifted", "%s" % CastNet.AIM_OK)
		_check(absf(CastNet.AIM_NO.r - red.r) < 0.01
			and absf(CastNet.AIM_NO.g - red.g) < 0.01
			and absf(CastNet.AIM_NO.b - red.b) < 0.01,
			"its red is the pack's own wood, lifted", "%s" % CastNet.AIM_NO)
		_check(CastNet.AIM_LIFT > 1.0,
			"and the lift lifts", "x%.2f" % CastNet.AIM_LIFT)
		_check(CastNet.AIM_FAR.is_equal_approx(palette.foam),
			"and its pale is the lake's own foam", "%s" % CastNet.AIM_FAR)
	var inks := [CastNet.AIM_OK, CastNet.AIM_NO, CastNet.AIM_FAR]
	var apart := true
	for i in inks.size():
		for j in range(i + 1, inks.size()):
			if (inks[i] as Color).is_equal_approx(inks[j]):
				apart = false
	_check(apart, "the three readings stay three colours", "")
	var darkest := 1.0
	for ink: Color in inks:
		darkest = minf(darkest, ink.get_luminance())
	_check(CastNet.AIM_BACK.get_luminance() < darkest,
		"the backing is darker than every colour it backs",
		"%.3f under %.3f" % [CastNet.AIM_BACK.get_luminance(), darkest])
	_check(CastNet.AIM_BACK_WIDE > 1.5 and CastNet.AIM_BACK_SHARE > 0.0
		and CastNet.AIM_BACK_SHARE <= 1.0,
		"and it is wider than the line and carries a share of it",
		"%.1f px at %.2f" % [CastNet.AIM_BACK_WIDE, CastNet.AIM_BACK_SHARE])
	_advance()


## Nature coming back (2026-09-16): the flora on the shores and the fish in the clean water
## follow the filth map and the lake's clean share, and the glint uniform follows the share.
func _stage_nature() -> void:
	var flora: Flora = _main.get(&"_flora")
	var fish: Fish = _main.get(&"_fish")
	_check(flora != null and fish != null, "the lake grew its flora and fish nodes", "")
	if flora == null or fish == null:
		_advance()
		return
	_check(flora.ready_to_grow(), "the flora sheet and table loaded and sowed candidates",
		"%d candidates" % flora.candidate_count())
	# Where the candidates stand: on the ground they say, never in the hut or the crate.
	var wrong_ground := 0
	var in_hut := 0
	var on_crate := 0
	var kinds := {}
	var crate: Vector2 = (_main.get(&"_dog") as Dog).crate_tile
	for k in flora.candidate_count():
		var c := flora.candidate(k)
		var at: Vector2 = c["tile"]
		kinds[c["kind"]] = int(kinds.get(c["kind"], 0)) + 1
		if Iso.in_shed(at.x, at.y, Iso.SHED_COVER):
			in_hut += 1
		if Yard.covers(crate, at, 0.5):
			on_crate += 1
		var kind: String = c["kind"]
		var lake_tile := Iso.in_lake(int(floor(at.x)), int(floor(at.y)))
		var wet_kind := kind == "water" or kind == "open"
		if wet_kind and not lake_tile:
			wrong_ground += 1
		if not wet_kind and Iso.on_island_ground(at) == false and Ground.out_of_water(at.x, at.y) < 0.0:
			wrong_ground += 1
	_check(in_hut == 0 and on_crate == 0, "no plant stands in the hut or on the crate",
		"hut %d crate %d" % [in_hut, on_crate])
	_check(wrong_ground == 0, "every plant stands on the ground its kind says", "%d off" % wrong_ground)
	_check(kinds.has("lawn") and kinds.has("beach") and kinds.has("water") and kinds.has("open"),
		"lawn, beach, shore-water and open-water candidates all exist", str(kinds))
	# The open-water beds keep off the yards, where the ferries come in.
	var by_yard := 0
	for k in flora.candidate_count():
		var c := flora.candidate(k)
		if c["kind"] != "open":
			continue
		for p in flora.avoid:
			if (c["tile"] as Vector2).distance_to(p) < Flora.OPEN_CLEAR - 0.8:
				by_yard += 1
	_check(not flora.avoid.is_empty() and by_yard == 0, "no open-water bed at a yard's jetty or berth",
		"%d of %d avoid points" % [by_yard, flora.avoid.size()])
	# The stages before this one emptied the lake. Fill it again, as a new game does, and
	# forget what grew: a fresh lake's share is the island's clean ring and little else.
	_grid.build(_main._all_defs(), _main._level_seed(), true)
	_main._build_filth_map()
	flora.reset()
	fish.refresh(_main.clean_share(), _main.get(&"_clean_tiles"))
	fish.schools().clear()
	var fresh: float = _main.clean_share()
	_check(fresh < 0.25, "a fresh lake's clean share is small", "%.3f" % fresh)
	_check(fish.school_count() == 0 or fresh >= Fish.TIERS[0]["at"],
		"no fish before the first tier's share", "%d schools at %.3f" % [fish.school_count(), fresh])
	_check_grime()
	# Empty the west half of the lake and rebuild the map: the share climbs, plants come
	# due beside the cleared water only, the fish arrive and stay on clean tiles.
	for index in _grid.stacks.size():
		var tile := _grid.tile_of(index)
		if tile.x < Iso.CENTRE.x and not _grid.stacks[index].is_empty():
			_grid.stacks[index].resize(0)
	_grid._rebuild()
	_main._build_filth_map()
	# Water past the stain's reach of any piece is clean, whatever the pooled share says.
	var green_over_empty := 0
	for index in _grid.stacks.size():
		var tile := _grid.tile_of(index)
		if tile.x < Iso.CENTRE.x - float(_main.get(&"FILTH_BLUR")) - 2.0 and _grid.water_state(index) != 0:
			green_over_empty += 1
	_check(green_over_empty == 0, "no grime is drawn over water with nothing near it",
		"%d tiles" % green_over_empty)
	var half: float = _main.clean_share()
	_check(half > fresh + 0.2, "clearing half the lake lifts the clean share", "%.3f -> %.3f" % [fresh, half])
	var glint: float = _water_material().get_shader_parameter(&"glint")
	_check(glint > 0.0 and glint < 1.0, "the water is told to glint, short of full", "%.3f" % glint)
	_check(float(_water_material().get_shader_parameter(&"glint_cell")) >= 20.0
		and float(_main.get(&"GLINT_MOST")) <= 0.03,
		"and sparsely", "cell %.0f, most %.2f" % [
			float(_water_material().get_shader_parameter(&"glint_cell")), float(_main.get(&"GLINT_MOST"))])
	# Early in a run a glint is rare: with three tenths of the water clean, a screen of
	# nothing but clean water (576 cells at zoom 1, five ticks a second, `glint_rate` a roll)
	# pops less than once in four seconds. The rule, whatever the two constants become.
	var early := pow(0.3, float(_main.get(&"GLINT_BITE"))) * float(_main.get(&"GLINT_MOST"))
	# The roll and the tick are the shader's own defaults, which nothing pushes: a material
	# hands back null for a parameter it was never given, so they are read off the source.
	var water_code: String = (_water_material().shader as Shader).code
	var roll := _shader_default(water_code, "glint_rate")
	var ticks := _shader_default(water_code, "glint_fps")
	_check(roll > 0.0 and ticks > 0.0, "the glint's roll and tick are in the shader", "%.3f, %.1f" % [roll, ticks])
	var early_rate := 576.0 * ticks * early * roll
	_check(early_rate < 0.25, "and rarely while most of the lake is still soup",
		"%.3f pops a second on a clean screen at 30%% clean" % early_rate)
	# And it stays a glint at the far end of the run: nine tenths clean is a handful of pops
	# a second on that screen, not a shimmer. The finished lake's sparkle is what shimmers.
	var late := pow(0.9, float(_main.get(&"GLINT_BITE"))) * float(_main.get(&"GLINT_MOST"))
	var late_rate := 576.0 * ticks * late * roll
	_check(late_rate < 8.0, "and only a handful a second when the lake is nearly clean",
		"%.1f pops a second on a clean screen at 90%% clean" % late_rate)
	_check(flora.alive_count() > 0, "plants came due beside the cleared water", "%d" % flora.alive_count())
	var foul_plants := 0
	for k in flora.candidate_count():
		var c := flora.candidate(k)
		if not bool(c["alive"]):
			continue
		var wi: int = flora._water_index[k]
		if _grid.water_state(wi) != 0:
			foul_plants += 1
	_check(foul_plants == 0, "no plant grew beside foul water", "%d" % foul_plants)
	# Let the fish reckon and swim a while.
	for i in 240:
		fish._process(1.0 / 60.0)
	_check(fish.school_count() > 0, "fish schools arrived once the share allowed", "%d" % fish.school_count())
	var foul_fish := 0
	for s: Dictionary in fish.schools():
		var at := Iso.world_to_tile(s["at"])
		var t := Vector2i(int(floor(at.x)), int(floor(at.y)))
		if not Iso.in_lake(t.x, t.y) or _grid.water_state(_grid.index_of(t.x, t.y)) != 0:
			if float(s["fade"]) > 0.05:
				foul_fish += 1
	_check(foul_fish == 0, "no school is in foul water while shown", "%d" % foul_fish)
	# A scare turns the schools and speeds them; nothing here can catch or pay.
	var before: Array = []
	for s: Dictionary in fish.schools():
		before.append([s["at"], s["heading"]])
	if not fish.schools().is_empty():
		var first: Dictionary = fish.schools()[0]
		var hit: Vector2 = (first["at"] as Vector2) + Vector2(20.0, 0.0)
		fish.scare(hit)
		_check(float(first["flee"]) > 0.0, "a landing beside a school sends it fleeing", "")
		_check((first["heading"] as Vector2).x < 0.0, "and away from the landing", str(first["heading"]))
	_check(not fish.has_method("catch") and not fish.has_method("pay"),
		"fish have no catch and no pay", "")
	_check_bees(flora)
	_check_wildlife()
	_advance()


## Bees (2026-09-22): only at grown flowers, never more than the cap, none on a fresh lake.
func _check_bees(flora: Flora) -> void:
	_check(flora.bee_count() > 0 and flora.bee_count() <= Flora.BEES_MOST,
		"bees came to the flowers on the cleared half, up to the cap", "%d" % flora.bee_count())
	var off_flower := 0
	for k: int in flora._bee_host:
		var name: String = flora._species[k]
		var host := false
		for prefix: String in Flora.BEE_HOSTS:
			if name.begins_with(prefix):
				host = true
		if not host or flora._age[k] < 0.0:
			off_flower += 1
	_check(off_flower == 0, "every bee is at a flower that has grown", "%d" % off_flower)
	for i in 480:
		flora._process(1.0 / 60.0)
	_check(not flora.pad_spots().is_empty(),
		"grown pads are offered to the frogs", "%d" % flora.pad_spots().size())


## The animals (2026-09-22): frogs, turtles, ducks, dragonflies. Ambient: no catch, no pay.
## Asked on the half-cleared lake `_stage_nature` just made.
func _check_wildlife() -> void:
	var wild: Wildlife = _main.get(&"_wildlife")
	_check(wild != null and wild.ready_to_live(), "the wildlife node is there with its art", "")
	if wild == null or not wild.ready_to_live():
		return
	_check(wild.shore_count() > 100, "shore spots found round the island and the bank", "%d" % wild.shore_count())
	var wet_land := 0
	var bad_side := 0
	for s: Dictionary in wild.get(&"_shore"):
		if wild._wet(s["land"]):
			wet_land += 1
		if not wild._wet(s["water"]):
			bad_side += 1
	_check(wet_land == 0 and bad_side == 0, "every shore spot is sand behind and water in front",
		"%d wet, %d dry" % [wet_land, bad_side])
	# A fresh lake has none of them; this one is half clean. Nobody on a dirty lake.
	var saved_stage := wild.stage
	wild.reset()
	wild.stage = 0.01
	wild._reckon()
	_check(wild.frog_count() + wild.turtle_count() + wild.brood_count() + wild.dragonfly_count() == 0,
		"no animals on a lake that is not yet clean", "")
	wild.refresh(_main.clean_share(), _main.get(&"_clean_tiles"))
	wild.set(&"_brood_in", 0.0)
	wild._reckon()
	var share: float = _main.clean_share()
	_check(wild.frog_count() == wild._want(Wildlife.FROGS_MOST) and wild.frog_count() > 0,
		"frogs come in with the clean share", "%d at %.2f" % [wild.frog_count(), share])
	_check(wild.turtle_count() > 0 and wild.dragonfly_count() > 0 and wild.brood_count() == 1,
		"turtles, dragonflies and one brood at a time", "%d %d %d" % [wild.turtle_count(), wild.dragonfly_count(), wild.brood_count()])
	_check(wild.frog_count() <= Wildlife.FROGS_MOST and wild._want(Wildlife.FROGS_MOST) <= Wildlife.FROGS_MOST,
		"never past the cap", "")
	# Only at clean shores; a brood lands only on clean water.
	var foul_home := 0
	for f: Dictionary in wild.frogs():
		if _grid.water_state(int((f["spot"] as Dictionary)["index"])) != 0:
			foul_home += 1
	for b: Dictionary in wild.broods():
		if not wild._swimmable(b["to"]):
			foul_home += 1
	_check(foul_home == 0, "frogs live by clean water and ducks land on it", "%d" % foul_home)
	# Run them a while: frogs swim in, the brood flies in and lands.
	for i in 1200:
		wild._process(1.0 / 60.0)
	var swum_home := 0
	for f: Dictionary in wild.frogs():
		if int(f["state"]) != Wildlife.Frog.SWIM:
			swum_home += 1
	_check(swum_home > 0, "frogs swim ashore and get on with sitting, croaking, hopping", "%d" % swum_home)
	var landed := 0
	for b: Dictionary in wild.broods():
		if float(b["alt"]) <= 0.0:
			landed += 1
	_check(landed > 0, "the brood came down onto the water", "%d of %d" % [landed, wild.brood_count()])
	# A frog on land that the angler walks up to jumps in; the ducks take off at a landing.
	var sitter: Dictionary = {}
	for f: Dictionary in wild.frogs():
		if int(f["state"]) == Wildlife.Frog.SIT:
			sitter = f
			break
	if not sitter.is_empty():
		wild._frog_step(sitter, 0.016, PackedVector2Array([(sitter["at"] as Vector2) + Vector2(10.0, 0.0)]))
		_check(int(sitter["state"]) == Wildlife.Frog.JUMP, "a frog jumps into the water when someone walks up", "")
		# Checked on the frame the jump ends: a frog that went in right beside its own shore
		# can reach it and climb straight out again within a second.
		for i in 120:
			if int(sitter["state"]) != Wildlife.Frog.JUMP:
				break
			wild._frog_step(sitter, 1.0 / 60.0, PackedVector2Array())
		_check(int(sitter["state"]) == Wildlife.Frog.SWIM, "and swims as a shadow once it is in", "")
	for b: Dictionary in wild.broods():
		if float(b["alt"]) <= 0.0:
			wild.scare(b["at"])
			_check(int(b["state"]) == Wildlife.Brood.TAKE_OFF, "a net landing by the ducks puts them up", "")
			break
	# The frog sheet's rows: a frog heading right looks east, one heading down looks south.
	_check(Wildlife._row_of(Vector2(1.0, 0.0)) == 2 and Wildlife._row_of(Vector2(0.0, 1.0)) == 0
		and Wildlife._row_of(Vector2(-1.0, 0.0)) == 6 and Wildlife._row_of(Vector2(0.0, -1.0)) == 4
		and Wildlife._row_of(Vector2(1.0, 1.0)) == 1 and Wildlife._row_of(Vector2(-1.0, 1.0)) == 7,
		"frogs face the way they are going", "")
	_check(not wild.has_method("catch") and not wild.has_method("pay"), "animals have no catch and no pay", "")
	_check_beat(wild)
	wild.stage = saved_stage


## The animals move to the music (2026-09-22): every song the lake plays has a measured beat
## grid, the station counts beats off it whether or not anything is audible, and a frog's hop
## lands on a beat.
func _check_beat(wild: Wildlife) -> void:
	var table = JSON.parse_string(FileAccess.get_file_as_string(MusicStation.BEATS))
	var missing := []
	for slug in MusicStation.PLAYLIST + [MusicStation.ENDING_SONG]:
		if not (table is Dictionary and (table as Dictionary).has(String(slug))):
			missing.append(slug)
	_check(missing.is_empty(), "every song the lake plays has a beat grid", str(missing))
	if not missing.is_empty():
		return
	var station := MusicStation.new()
	station.set(&"_beats", table)
	var grid: Dictionary = table[String(MusicStation.PLAYLIST[0])]
	station.set(&"_at", float(grid["offset"]) + 3.0 * 60.0 / float(grid["bpm"]))
	_check(absf(station.beat_clock() - 3.0) < 0.001 and absf(station.beat_length() - 60.0 / float(grid["bpm"])) < 0.0001,
		"the station counts beats off the song's own grid", "%.3f" % station.beat_clock())
	station.free()
	# A hop is launched early enough to land on its beat. Run on the fallback clock, which
	# only moves with the node's own time, so the frames here are all it has.
	var had: MusicStation = wild.music
	var had_threats: Callable = wild.threats
	wild.music = null
	wild.threats = Callable()
	var landings := 0
	var off_beat := 0
	var step := 1.0 / 60.0
	var slack := 2.5 * step / wild.beat_length()
	for i in 3600:
		wild._process(step)
		for f: Dictionary in wild.frogs():
			var state: int = f["state"]
			if int(f.get("test_was", -1)) == Wildlife.Frog.HOP and state != Wildlife.Frog.HOP:
				landings += 1
				var into := fposmod(wild.beat(), 1.0)
				if minf(into, 1.0 - into) > slack:
					off_beat += 1
			f["test_was"] = state
	_check(landings > 0 and off_beat == 0, "frogs' hops land on the beat",
		"%d landings, %d off the beat" % [landings, off_beat])
	# A resting turtle's head is up for the first half of every beat, down for the second.
	var t0 := {"clock": 0.0, "nod_seed": 0.0}
	var up := "_up" if fposmod(wild.beat(), 1.0) < 0.5 else ""
	_check(wild._nod(t0) == up, "a resting turtle nods up on the beat and down off it", up)
	wild.music = had
	wild.threats = had_threats


## The graded grime (2026-09-17): the water's shade follows how much rubbish an area still
## holds, in five states, so it lightens as stacks come up rather than when they are gone.
## Asked of a fresh, full lake; `_stage_nature` empties the west half straight after.
func _check_grime() -> void:
	var seen := {}
	var blue_under_junk := 0
	for index in _grid.stacks.size():
		if _grid.stacks[index].is_empty():
			continue
		if index < _grid.dry.size() and _grid.dry[index] == 1:
			continue
		var state := _grid.water_state(index)
		seen[state] = int(seen.get(state, 0)) + 1
		if state == 0:
			blue_under_junk += 1
	_check(blue_under_junk == 0, "water touching a piece never reads clean", "%d tiles" % blue_under_junk)
	# A fresh lake is filthy edge to edge since the bank's shallows are measured against
	# their own fill: the shades come from working it, not from how deep it is.
	var total_seen := 0
	for state: int in seen:
		total_seen += int(seen[state])
	_check(int(seen.get(LakeGrid.FILTH_STATES, 0)) * 2 > total_seen,
		"most of a fresh lake's rubbish lies in the dirtiest water", str(seen))
	# The bank's shallows are measured against their own fill, so full ones read as foul as a
	# full deep bay — and half fetched, lighter, rather than holding until the last piece.
	var deep := _grid.index_of(int(Iso.CENTRE.x) - 10, int(Iso.CENTRE.y))
	var shallow := _grid.index_of(int(Iso.CENTRE.x - Iso.RADIUS.x * 0.8), int(Iso.CENTRE.y))
	_check(_grid.water_state(shallow) == LakeGrid.FILTH_STATES
		and _grid.water_state(deep) == LakeGrid.FILTH_STATES,
		"a full shallow by the bank reads as dirty as a full deep bay",
		"states %d and %d" % [_grid.water_state(shallow), _grid.water_state(deep)])
	var bank_before := _grid.water_state(shallow)
	var bank_at := _grid.tile_of(shallow)
	var bank_kept := {}
	for index in _grid.stacks.size():
		var tile := _grid.tile_of(index)
		if absi(tile.x - bank_at.x) <= 4 and absi(tile.y - bank_at.y) <= 4:
			bank_kept[index] = _grid.stacks[index].duplicate()
			if tile.x % 2 == 0:
				_grid.stacks[index].resize(0)
	_main._build_filth_map()
	var bank_after := _grid.water_state(shallow)
	_check(bank_after < bank_before and bank_after >= 1,
		"a half-fetched bank is lighter, and not yet clean", "state %d -> %d" % [bank_before, bank_after])
	for index: int in bank_kept:
		_grid.stacks[index] = bank_kept[index]
	_main._build_filth_map()
	# Lift half of every stack round the deep tile: its water comes up a shade or more, is
	# still not clean, and nothing anywhere got dirtier for it.
	var before := _grid.filth.duplicate()
	var state_before := _grid.water_state(deep)
	var around := _grid.tile_of(deep)
	for index in _grid.stacks.size():
		var tile := _grid.tile_of(index)
		if absi(tile.x - around.x) <= 4 and absi(tile.y - around.y) <= 4:
			var stack := _grid.stacks[index]
			if stack.size() > 1:
				stack.resize(maxi(stack.size() / 2, 1))
	_main._build_filth_map()
	var state_after := _grid.water_state(deep)
	_check(state_after < state_before and state_after >= 1,
		"lifting half an area's rubbish lightens its water, short of clean",
		"state %d -> %d" % [state_before, state_after])
	var rose := 0
	for i in before.size():
		if _grid.filth[i] > before[i]:
			rose += 1
	_check(rose == 0, "and no water got dirtier for it", "%d tiles" % rose)
	# The floor lands a lone piece's own tile inside the first state past clean.
	var floor_t := pow(float(_main.get(&"FILTH_FLOOR")), LakeGrid.FILTH_STATE_BITE)
	_check(floor_t >= LakeGrid.FILTH_STATE_AT[0] and floor_t < LakeGrid.FILTH_STATE_AT[1],
		"the floor under a lone piece is the lightest grime", "%.3f" % floor_t)
	# The shader draws what the grid reports: both new ramps, and the same four cutoffs.
	var source: String = (_water_material().shader as Shader).code
	var cuts := "vec4(%s, %s, %s, %s)" % [
		LakeGrid.FILTH_STATE_AT[0], LakeGrid.FILTH_STATE_AT[1],
		LakeGrid.FILTH_STATE_AT[2], LakeGrid.FILTH_STATE_AT[3]]
	_check(source.contains("water_hazy_deep") and source.contains("water_foul_deep"),
		"the water shader has the hazy and the foul ramps", "")
	_check(source.contains("state_at = " + cuts), "and the grid's cutoffs are the shader's", cuts)
	# Clean means clean: the wobble and the stagger both fade out with the filth, or the
	# darkest band troughs of a finished lake draw hazy smudges with nothing under them.
	_check(source.contains("edge_live = smoothstep(0.0, state_at.x, color_t)")
		and source.contains("murk_wobble * edge_live")
		and source.contains("state_spread * edge_live"),
		"water with no filth in it has no edge to wobble or stagger", "")
	var palette := Palette.master()
	_check(palette != null and palette.water_hazy != Color.WHITE and palette.water_foul != Color.WHITE,
		"the palette carries both ramps", "")


func _water_material() -> ShaderMaterial:
	return _main.get(&"_water_material")


## A float uniform's default, read off the shader's source. -1 when it is not there.
func _shader_default(code: String, uniform_name: String) -> float:
	var found := RegEx.create_from_string(
		"uniform\\s+float\\s+%s\\b[^=;]*=\\s*([0-9.]+)" % uniform_name).search(code)
	return float(found.get_string(1)) if found != null else -1.0


## Issue #31: every disturbance on the water is foam. The splash is drawn through the foam
## shaders, a ripple is a torn band rather than a line, the reel wears a bow wave at the
## mouth in place of its ripple trail, and the dog and the angler leave a streak while
## moving in the water and push one ring only on the way in.
func _stage_foam() -> void:
	var splash := _main.get(&"_splash") as WaterSplash
	_check(splash != null, "the lake has its splash", "")
	if splash == null:
		_finish()
		return
	var rings := splash.get_node_or_null(^"Rings") as Node2D
	var specks := splash.get_node_or_null(^"Specks") as Node2D
	var crowns := splash.get_node_or_null(^"Crowns") as Node2D
	_check(rings != null and specks != null and crowns != null,
		"the splash draws rings, specks and crowns on their own parts", "")
	if rings != null and crowns != null and specks != null:
		var froth := crowns.material as ShaderMaterial
		_check(froth != null and froth.shader != null
			and froth.shader.resource_path.ends_with("splash_foam.gdshader"),
			"the crowns are drawn in the splash foam shader", "")
		_check(rings.material == crowns.material, "and the rings in the same material", "")
		var ink := specks.material as ShaderMaterial
		_check(ink != null and ink.shader != null
			and ink.shader.resource_path.ends_with("splash_specks.gdshader"),
			"the specks through their own", "")
		var palette := Palette.master()
		if palette != null and froth != null and ink != null:
			_check(froth.get_shader_parameter(&"foam") == palette.foam
				and froth.get_shader_parameter(&"foam_core") == palette.foam_light
				and ink.get_shader_parameter(&"foam") == palette.foam,
				"both wear the palette's foam swatches", "")
		_check(float(froth.get_shader_parameter(&"foam_pixel")) == Lake.ART_PIXEL,
			"on the art-pixel grid", "%s" % froth.get_shader_parameter(&"foam_pixel"))
		_check(int(rings.get_index()) < int(specks.get_index())
			and int(specks.get_index()) < int(crowns.get_index()),
			"rings under specks under crowns", "")
	var ripples: PackedFloat32Array = splash.get(&"_ripple_age")
	var ripples_was := ripples.size()
	splash.ripple(Vector2(100.0, 100.0), 20.0)
	ripples = splash.get(&"_ripple_age")
	_check(ripples.size() == ripples_was + 1 and splash.is_processing(),
		"a ripple is still one ring the water works out", "")
	var splash_source: String = (load("res://scripts/water_splash.gd") as Script).source_code
	_check(not splash_source.contains("draw_polyline") and not splash_source.contains("draw_circle"),
		"nothing in the splash is a line or a circle any more", "")
	# No two crowns alike: each carries a roll, and the roll moves the shape.
	var rolls_was := (splash.get(&"_crown_roll") as PackedFloat32Array).size()
	splash.splash(Vector2(100.0, 100.0), 0.5)
	splash.splash(Vector2(100.0, 100.0), 0.5)
	var rolls: PackedFloat32Array = splash.get(&"_crown_roll")
	_check(rolls.size() == rolls_was + 2 and rolls[rolls.size() - 1] != rolls[rolls.size() - 2],
		"every crown rolls its own shape", "")
	var straight: PackedVector2Array = splash.call(&"_plume", Vector2.ZERO, 1.0, 40.0, 20.0, 1.0)
	var leant: PackedVector2Array = splash.call(&"_plume", Vector2.ZERO, 1.0, 40.0, 20.0, 1.3)
	_check(straight.size() == leant.size() and straight != leant, "and the roll moves the plume", "")
	_check(WaterSplash.CROWN_VARY > 0.0 and WaterSplash.CROWN_VARY <= 0.5,
		"within a bit, not a different crown", "%.2f" % WaterSplash.CROWN_VARY)
	(splash.get(&"_crown_age") as PackedFloat32Array).clear()

	# The reel's bow wave.
	var bow := _net.get(&"_bow") as HullFoam
	_check(bow != null and not bow.with_trail and bow.streak_long < 1.0,
		"the net wears a short bow wave with no trail", "")
	var net_source: String = (load("res://scripts/net.gd") as Script).source_code
	_check(not net_source.contains("splash.wake("), "and sheds no ripple trail", "")
	if bow != null:
		var state_was := _net.state
		var at_was := _net.tile_pos
		_net.state = CastNet.State.REELING
		_net.tile_pos = _angler.tile_pos + Vector2(2.0, 2.0)
		for i in 30:
			_net.call(&"_push_bow", 0.05)
		_check(float(bow.get(&"_push")) > 0.9, "reeling pushes the wave up", "%.2f" % float(bow.get(&"_push")))
		_check(bow.position.distance_to(_net.world_pos()) <= _net.mouth_extent() * 0.5 + 0.01
			and bow.position.distance_to(_net.world_pos()) > 1.0, "on the mouth's leading rim", "")
		_check(is_equal_approx(bow.half_width, _net.mouth_extent() * CastNet.MOUTH_FLARE),
			"sized to the mouth", "%.1f" % bow.half_width)
		# Home is the angler's hand: the wave is gone on the spot, not eased out beside the
		# player, and nothing re-aims it on the way.
		var bow_at := bow.position
		var bow_heading: Vector2 = bow.get(&"_heading")
		_net.state = CastNet.State.IDLE
		_net.tile_pos = _angler.tile_pos
		_net.call(&"_push_bow", 0.05)
		_check(float(bow.get(&"_push")) <= 0.0, "and it is gone the moment the net is home",
			"%.2f" % float(bow.get(&"_push")))
		_check(bow.position.is_equal_approx(bow_at) and (bow.get(&"_heading") as Vector2).is_equal_approx(bow_heading),
			"never moved to the angler or turned on its way out", "")
		_net.state = state_was
		_net.tile_pos = at_was

	# The dog: one ring going in, a streak while swimming, no ring lines drawn.
	var dogs: Array = _main.get(&"_dogs")
	var dog_source: String = (load("res://scripts/dog.gd") as Script).source_code
	_check(not dog_source.contains("_draw_wake") and not dog_source.contains("splash.wake("),
		"the dog draws no ring while swimming", "")
	if not dogs.is_empty():
		var dog := dogs[0] as Dog
		var streak := dog.get(&"_streak") as HullFoam
		_check(streak != null and streak.with_trail, "the dog wears a streak with its trail", "")
		var dog_was := dog.tile_pos
		var land := Iso.ISLAND_CENTRE
		var water := land
		for i in 60:
			water += Vector2(0.25, 0.25)
			dog.tile_pos = water
			if not bool(dog.call(&"_on_land")):
				break
		dog.tile_pos = land
		dog.set(&"_was_swimming", false)
		ripples_was = (splash.get(&"_ripple_age") as PackedFloat32Array).size()
		dog.call(&"_wake", 0.016)
		_check((splash.get(&"_ripple_age") as PackedFloat32Array).size() == ripples_was,
			"a dog on land pushes no ring", "")
		dog.tile_pos = water
		dog.call(&"_wake", 0.016)
		_check((splash.get(&"_ripple_age") as PackedFloat32Array).size() == ripples_was + 1,
			"going into the water pushes one", "")
		dog.tile_pos = water + Vector2(0.1, 0.1)
		dog.call(&"_wake", 0.016)
		_check((splash.get(&"_ripple_age") as PackedFloat32Array).size() == ripples_was + 1,
			"and swimming on pushes no more", "")
		dog.tile_pos = dog_was
		dog.set(&"_was_swimming", not bool(dog.call(&"_on_land")))

	# The angler: the same rule.
	var angler_source: String = (load("res://scripts/player.gd") as Script).source_code
	_check(not angler_source.contains("_draw_ripples") and not angler_source.contains("splash.wake("),
		"the angler draws no rings round the boots", "")
	var boots := _angler.get(&"_streak") as HullFoam
	_check(boots != null and boots.with_trail, "and wears a streak with its trail", "")
	var angler_was := _angler.tile_pos
	var dry := Iso.ISLAND_CENTRE
	var wet := dry
	for i in 80:
		wet += Vector2(0.2, 0.2)
		if float(_angler.call(&"_wet_by", wet)) > 0.0:
			break
	_angler.tile_pos = dry
	_angler.set(&"_was_wading", false)
	ripples_was = (splash.get(&"_ripple_age") as PackedFloat32Array).size()
	_angler.call(&"_wake", 0.016)
	_check((splash.get(&"_ripple_age") as PackedFloat32Array).size() == ripples_was,
		"dry boots push no ring", "")
	_angler.tile_pos = wet
	_angler.call(&"_wake", 0.016)
	_check((splash.get(&"_ripple_age") as PackedFloat32Array).size() == ripples_was + 1,
		"stepping in pushes one", "")
	_angler.call(&"_wake", 0.016)
	_check((splash.get(&"_ripple_age") as PackedFloat32Array).size() == ripples_was + 1,
		"and wading on pushes no more", "")
	_angler.tile_pos = angler_was
	_angler.set(&"_was_wading", float(_angler.call(&"_wet_by", angler_was)) > 0.0)
	(splash.get(&"_ripple_age") as PackedFloat32Array).clear()
	_advance()


## Fast Sell and Strong Dogs (2026-09-17). Fast Sell tightens the gap between the pieces of
## a ferry's volley at both ends of its run and touches nothing else that throws; Strong Dogs
## raises the pack's weight tier and its mouth's width together, because tier on its own
## would open three kinds in the whole catalogue.
## The shop's shape (2026-09-17): four boards named without an article, every row's name
## unique across all of them, every row claimed by exactly one group, one value grammar, and
## the pricing plate standing under the middle two even though the boards are now level.
func _stage_shop_shape() -> void:
	var skin := _main.get_node(^"HUD/ShopSkin")
	var titles: Dictionary = skin.get(&"TITLES")
	var articled := []
	for board in titles:
		if String(titles[board]).begins_with("The "):
			articled.append(String(titles[board]))
	_check(articled.is_empty(), "no board's title carries an article", ", ".join(articled))

	var shop_rows: Array = _main.call(&"_shop_rows")
	# Two rows called "Speed" on two boards was the thing this pass set out to kill, so the
	# guard is uniqueness across the whole shop, not within a board.
	var seen := {}
	var clashes := []
	for row: Dictionary in shop_rows:
		var name := String(row["name"])
		if seen.has(name):
			clashes.append("%s: %s and %s" % [name, seen[name], row["key"]])
		seen[name] = String(row["key"])
	_check(clashes.is_empty(), "every row's name is unique across the four boards", ", ".join(clashes))

	var groups: Dictionary = skin.get(&"GROUPS")
	var claimed := {}
	var twice := []
	for board in groups:
		for group: Array in groups[board]:
			for key in group[1]:
				if claimed.has(key):
					twice.append(String(key))
				claimed[key] = board
	_check(twice.is_empty(), "no row is claimed by two groups", ", ".join(twice))
	var orphans := []
	_check_shop_purse(skin)
	_check_bonus_panel()
	for row: Dictionary in shop_rows:
		if not claimed.has(row["key"]) or claimed[row["key"]] != row["board"]:
			orphans.append(String(row["key"]))
	_check(orphans.is_empty(), "and every row is claimed by its own board's groups", ", ".join(orphans))
	_check(int(skin.call(&"_headings_of", &"net")) == 0,
		"a board with one group draws no heading", "%d" % int(skin.call(&"_headings_of", &"net")))
	for board in [&"boat", &"dog", &"luck"]:
		_check(int(skin.call(&"_headings_of", board)) == 2,
			"and the %s board draws two" % board, "%d" % int(skin.call(&"_headings_of", board)))

	var wordy := []
	for row: Dictionary in shop_rows:
		var value := String(row["value"])
		if "Lvl" in value or "next)" in value:
			wordy.append("%s: %s" % [row["key"], value])
	_check(wordy.is_empty(), "no row's value says Lvl or next", ", ".join(wordy))

	# The plate used to live in the height difference between the net board and the middle
	# two. The grouping levels them, so this is the check that it no longer depends on that.
	skin.set(&"rows", shop_rows)
	skin.set(&"legend", _main.call(&"_shop_legend"))
	skin.call(&"_lay_out")
	var skin_boards: Dictionary = skin.get(&"_boards")
	var plate: Rect2 = skin.get(&"_legend_box")
	var boat_box: Rect2 = skin_boards[&"boat"]
	var net_box: Rect2 = skin_boards[&"net"]
	_check(absf(net_box.size.y - boat_box.size.y) < 40.0,
		"the boards stand within a row of each other",
		"net %.0f boat %.0f" % [net_box.size.y, boat_box.size.y])
	_check(plate.size.y > 0.0, "and the pricing plate still has its room",
		"plate %s" % plate)
	_check(plate.position.y >= boat_box.end.y, "under the middle boards' feet", str(plate))

	# The recycle bonus, on the plate rather than in its row. It carries no price of its own:
	# `_mean_pay_of` already multiplies the boosted kind, so the yards list is the boosted
	# list, and a second figure here would be the same number written twice.
	_main.set(&"recycle_bonus_level", 1)
	_main.call(&"_move_bonus")
	var legend: Dictionary = _main.call(&"_shop_legend")
	var bonus: Dictionary = legend.get("bonus", {})
	_check(not bonus.is_empty() and int(bonus.get("kind", -1)) >= 0,
		"a live bonus reaches the pricing plate", str(bonus))
	_check(not bonus.has("pay"), "and carries no price of its own", str(bonus))
	var bonus_row := ""
	for row: Dictionary in _main.call(&"_shop_rows"):
		if row["key"] == &"recycle_bonus":
			bonus_row = String(row["value"])
	var kinds: Array = TrashDef.KIND_NAMES
	var named := false
	for kind in kinds:
		named = named or String(kind).to_lower() in bonus_row.to_lower()
	_check(not named, "and the row does not name a yard as well", bonus_row)
	_main.set(&"recycle_bonus_level", 0)

	# One shape for every value line (2026-09-17): two bare figures either side of the arrow,
	# a prefix on the first and a suffix on the last, each said once, and no nouns at all.
	var nouns := []
	var doubled := []
	var shaped := []
	for row: Dictionary in _main.call(&"_shop_rows"):
		var value := String(row["value"])
		for word in ["a cast", "aboard", "a trip", "dogs", "boats", "dog", "boat", "per", "faster"]:
			if word in value.to_lower():
				nouns.append("%s: %s" % [row["key"], value])
				break
		# Said once: a mark or a word may appear on one end of the line, never on both.
		for mark in ["%", "$", "Tier"]:
			if value.count(mark) > 1:
				doubled.append("%s: %s" % [row["key"], value])
		# Between the prefix and the suffix there is nothing but two figures and the arrow.
		var arrow := String(_main.get(&"ARROW"))
		if arrow in value:
			var bare := value.replace("Tier ", "").replace("$", "").replace("%", "").replace("s", "")
			var ends: PackedStringArray = bare.split(" %s " % arrow)
			if ends.size() != 2 or not ends[0].is_valid_int() or not ends[1].is_valid_int():
				shaped.append("%s: %s" % [row["key"], value])
	_check(nouns.is_empty(), "no value line carries a noun", ", ".join(nouns))
	_check(doubled.is_empty(), "and says its mark once, not on both ends", ", ".join(doubled))
	_check(shaped.is_empty(), "and is two bare figures either side of the arrow", ", ".join(shaped))
	var strength := ""
	var pigeons := ""
	for row: Dictionary in _main.call(&"_shop_rows"):
		if row["key"] == &"net_strength":
			strength = String(row["value"])
		if row["key"] == &"bird_worth":
			pigeons = String(row["value"])
	_check(strength.begins_with("Tier ") and strength.count("Tier") == 1,
		"a prefix binds to the first figure alone", strength)
	_check(pigeons.begins_with("$") and pigeons.count("$") == 1,
		"and so does the money mark", pigeons)

	# The HUD's cohesion pass (2026-09-17). The meter's frame is built to the wood's own box
	# rather than stamped from the sheet at `METER_SCALE`, so its planks are the 16 and 14 of
	# every other plate instead of 27 and 24.
	var hud := _main.get_node(^"HUD/Skin")
	var meter_frame: Control = hud.get(&"_meter_frame")
	var frame_box: Rect2 = hud.get(&"_meter_frame_box")
	var sheet_box: Rect2 = hud.get(&"_meter_box")
	_check(meter_frame != null and meter_frame.get_script() != null,
		"the meter's frame is a node that builds itself", str(meter_frame))
	if meter_frame != null:
		_check(absf(meter_frame.size.x - floorf(frame_box.size.x)) < 1.5
			and absf(meter_frame.size.y - floorf(frame_box.size.y)) < 1.5,
			"built to the wood's box, not the whole sheet",
			"node %s wood %s sheet %s" % [meter_frame.size, frame_box.size, sheet_box.size])
		_check(Style.border_fits(Rect2(Vector2.ZERO, meter_frame.size)),
			"and big enough for the border to be built at all", str(meter_frame.size))
	# Both picture buttons are one size, and the settings button is a gear with no word.
	_check(HudSkin.UPGRADES_SIZE == HudSkin.SHED_SIZE,
		"the two picture buttons are one size",
		"%s %s" % [HudSkin.UPGRADES_SIZE, HudSkin.SHED_SIZE])
	var gear: PlankButton = _main.get(&"_open_settings")
	_check(gear != null and gear.mark == &"gear" and gear.label.is_empty(),
		"the lake's settings button is a gear and carries no word",
		"mark %s label %s" % [gear.mark if gear != null else &"", gear.label if gear != null else ""])
	_check(gear != null and absf(gear.size.x - gear.size.y) < 1.5,
		"and is square", str(gear.size if gear != null else Vector2.ZERO))
	# The decorate button's fan: every find inside the room, and the tail wrapping the hut
	# rather than sitting in a band under it.
	var room := HudButtons.room_of(Rect2(0.0, 0.0, 120.0, 100.0))
	var fan: Array = HudButtons._scatter(16, room)
	var outside := 0
	var above := 0
	for spot: Dictionary in fan:
		var box: Rect2 = spot["box"]
		if not room.grow(0.5).encloses(box):
			outside += 1
		if box.position.y < room.position.y + room.size.y * 0.42:
			above += 1
	_check(outside == 0, "no find in the fan is clipped by the button's frame", "%d outside" % outside)
	_check(above >= 4, "and the tail reaches above the old band's ceiling", "%d of 16" % above)

	# The information pass (2026-09-17): the crate's plate says what it holds is waiting, and
	# the upgrades button's foot says what the button is with the count on a badge whose width
	# does not move with it.
	_check(HudSkin.STOCK_LABEL != "In stock",
		"the crate's plate no longer reads as a second purse", HudSkin.STOCK_LABEL)
	_check(not "available" in HudSkin.UPGRADES_LABEL.to_lower()
		and not "%d" in HudSkin.UPGRADES_LABEL,
		"the upgrades button's foot is a name, not a count", HudSkin.UPGRADES_LABEL)
	# Sized to the widest count it can ever hold, so one affordable upgrade and ninety-nine
	# draw the same plate.
	var narrow := _badge_width("1")
	var broad := _badge_width("99")
	_check(is_equal_approx(narrow, broad),
		"and the count's badge is one width at every count",
		"1 -> %.0f, 99 -> %.0f" % [narrow, broad])

	# The unaffordable row's ink. `Style.BOARD_INK_DIM` on the off face reads 2.19:1, which
	# is why the shop has its own.
	var ink: Color = skin.get(&"INK_DIM")
	_check(_contrast(ink, Style.BOARD_ROW_OFF) >= 4.5,
		"an unaffordable row's ink clears 4.5:1",
		"%.2f:1" % _contrast(ink, Style.BOARD_ROW_OFF))
	_check(_contrast(Style.BOARD_INK, Style.BOARD_ROW) >= 4.5,
		"and an affordable row's does too",
		"%.2f:1" % _contrast(Style.BOARD_INK, Style.BOARD_ROW))
	_advance()


## The final UI pass (issue #7, 2026-09-20): cream faces under dark plates, the shed's shelf
## clear of the room and level with it, the room's light, Strength leading its board, and the
## luck board's coin.
func _stage_paper() -> void:
	# What is written straight on the paper has to read on it; the plates keep their inks.
	var worst := 99.0
	for ink: Color in [Style.PAPER_INK, Style.PAPER_HEAD, Style.PAPER_SOFT]:
		worst = minf(worst, _contrast(ink, Style.PAPER))
	_check(worst >= 4.5, "every paper ink clears 4.5:1 on the paper", "%.2f" % worst)
	_check(
		Style.PAPER_INK.get_luminance() < Style.SHADE_UNDER
		and Style.BOARD_INK.get_luminance() > Style.SHADE_UNDER,
		"dark ink draws no shade and a plate's pale ink keeps it", ""
	)
	var letter := load("res://scripts/letter.gd")
	_check(letter.PAPER == Style.PAPER, "the letter's paper is the boards' paper", "")
	var confirm_src := FileAccess.get_file_as_string("res://scripts/menu_confirm.gd")
	_check(not confirm_src.contains("ROW_SAVE"), "the confirm's doors are off the pale oak", "")
	_check(_contrast(Style.WARN_INK, Style.BOARD) >= 4.5, "a warning reads on a dark door",
		"%.2f" % _contrast(Style.WARN_INK, Style.BOARD))

	var room: ShedRoom = _main.get_node(^"HUD/Shed/Pad/Lines/Room")
	room.size = Vector2(1264.0, 704.0)
	var shed: Rect2 = room.call(&"_shed_rect")
	var ribbon: Rect2 = room.call(&"_ribbon_rect")
	_check(ribbon.position.x >= shed.end.x, "the shelf's plank stands clear of the room",
		"%.0f against %.0f" % [ribbon.position.x, shed.end.x])
	if Style.plank_fits(ribbon):
		var wood := Style.ribbon_plank(ribbon)
		_check(absf(wood.position.y - shed.position.y) < 0.6,
			"the shelf's drawn top is the shed's top", "%.1f against %.1f" % [wood.position.y, shed.position.y])
	var board: Rect2 = room.call(&"_board_rect")
	_check(absf(board.end.y - shed.end.y) < 0.6, "and its foot is the shed's foot",
		"%.1f against %.1f" % [board.end.y, shed.end.y])
	var room_src := FileAccess.get_file_as_string("res://scripts/shed_room.gd")
	_check(not room_src.contains("GLOW_RINGS =") and not room_src.contains("draw_circle(middle"),
		"the ringed glow is gone rather than unused", "")
	_check(room.get_node_or_null(^"Light") != null, "the room has its light", "")
	var early := DayCycle.new()
	early.sun = 0.15
	room.day = early
	var morning := room.sun_share()
	early.sun = 0.8
	var evening := room.sun_share()
	_check(morning < 0.01 and evening > 0.99, "the window's sun follows the day",
		"%.2f then %.2f" % [morning, evening])
	room.day = _main.get(&"_day")
	early.free()

	var skin := _main.get_node(^"HUD/ShopSkin")
	var groups: Dictionary = skin.get(&"GROUPS")
	var first: StringName = (((groups[&"net"] as Array)[0] as Array)[1] as Array)[0]
	_check(first == &"net_strength", "Strength leads the net's board", String(first))
	_check((skin.get(&"FEATURED") as Array) == [&"net_strength"], "and is the one rimmed row", "")
	var rest := ShopSkin.toss_pose(-1.0)
	var top := ShopSkin.toss_pose(0.5)
	var down := ShopSkin.toss_pose(1.0)
	_check(is_equal_approx(rest.x, 1.0) and rest.y == 0.0, "the coin rests face on", "")
	_check(top.y > 8.0, "it hops when tossed", "%.1f" % top.y)
	_check(is_equal_approx(down.x, 1.0) and absf(down.y) < 0.01, "and lands on the face it left", "")
	var seen_back := false
	for k in 20:
		if ShopSkin.toss_pose(float(k) / 20.0).x < -0.5:
			seen_back = true
	_check(seen_back, "showing its back on the way", "")


## The settings board's shape (2026-09-17): one plate face under carved headings, every word
## on it clearing 4.5:1, a dead chooser drawing nothing pressable, and the whole board fitting
## in the smallest frame the game can be given.
func _stage_settings_shape() -> void:
	var board: SettingsSkin = _main.get(&"_settings")
	if _in_stage == 1:
		# Shown at the smallest frame the game can be given — height never goes under 720 —
		# and left to draw itself once, so the next tick reads the real hit boxes.
		_was_settings_shown = board.visible
		board.size = Vector2(1280.0, 720.0)
		board.visible = true
		board.queue_redraw()
		return
	var plan: Array = board.call(&"_plan")

	# One face for every row: the three section colours are not what says where a section
	# ends any more, so nothing on the board may reach for them.
	var source := FileAccess.get_file_as_string("res://scripts/settings_skin.gd")
	var reached := []
	for name in ["ROW_SOUND", "ROW_SCREEN", "ROW_SAVE", "ON_GOLD"]:
		if source.contains("Style." + name):
			reached.append(name)
	_check(reached.is_empty(),
		"the board reaches for no section colour", ", ".join(reached))

	# Headings, and Master standing above the first of them.
	var heads := []
	var before_head := ""
	for line: Dictionary in plan:
		if line["kind"] == &"head":
			if heads.is_empty():
				before_head = String(before_head)
			heads.append(String(line["label"]))
		elif heads.is_empty() and line.has("label"):
			before_head = String(line["label"])
	_check(heads.size() >= 2, "the rows are grouped under headings", ", ".join(heads))
	_check(before_head == "Master",
		"and Master leads, above the first rule", before_head)

	# No key name written into a name. The two that had one are not rebindable, so the
	# Controls board will never say them either — but a label is a name, not a sentence.
	var carrying := []
	for line: Dictionary in plan:
		if line.has("label") and String(line["label"]).contains("("):
			carrying.append(String(line["label"]))
	_check(carrying.is_empty(), "no label carries a key name", ", ".join(carrying))

	# Every ink on the board, against the face it is actually drawn on.
	var row := Style.BOARD_ROW
	var dead := row.lerp(Style.BOARD, 0.55)
	var inks := {
		"a row's label": [Style.BOARD_INK, row],
		"a chooser's value": [SettingsSkin.VALUE_INK, row],
		"a dead row's reading": [SettingsSkin.INK_SOFT, dead],
		"a heading": [Style.PAPER_HEAD, Style.PAPER],
		"a button's word": [Style.INK, SettingsSkin.BUTTON_FACE],
		"a warning's word": [SettingsSkin.WARN_INK, SettingsSkin.BUTTON_FACE],
		"a list entry": [Style.BOARD_INK, Style.BOARD],
		"the entry it is on": [Style.INK_DARK, SettingsSkin.PICKED_FACE],
	}
	var faint := []
	var worst := 99.0
	for what: String in inks:
		var pair: Array = inks[what]
		var ratio := _contrast(pair[0], pair[1])
		worst = minf(worst, ratio)
		if ratio < 4.5:
			faint.append("%s %.2f:1" % [what, ratio])
	_check(faint.is_empty(),
		"every word on the board clears 4.5:1", "worst %.2f:1  %s" % [worst, ", ".join(faint)])

	# The warning is still red: told from the plain word by hue, not only by being an ink.
	_check(SettingsSkin.WARN_INK.r - SettingsSkin.WARN_INK.b >= 0.25,
		"and the warning is still plainly red",
		"r-b %.2f" % (SettingsSkin.WARN_INK.r - SettingsSkin.WARN_INK.b))

	# A dead chooser draws nothing that can be pressed. `_lines` is what the board hit-tests
	# against, so asking it is asking the real thing — which means letting the board draw
	# itself for a frame rather than calling `_draw` by hand, which is not allowed outside a
	# draw pass.
	var live_rows := []
	for line: Dictionary in board.get(&"_lines"):
		if String(line["key"]).begins_with("window_size"):
			live_rows.append(String(line["key"]))
	var windowed: bool = Prefs.live_window_mode() == Prefs.WindowMode.WINDOWED
	if windowed:
		_check(live_rows.size() == 3,
			"a live Resolution row keeps its two arrows and its value",
			", ".join(live_rows))
	else:
		_check(live_rows.is_empty(),
			"a dead Resolution row offers nothing to press", ", ".join(live_rows))

	# And the board fits the smallest frame the game can hand it: 1280x720 is the floor, and
	# a line that does not fit is dropped. `dropped_lines` exists so that is a failure here
	# rather than "Save and go to menu" quietly missing on somebody's monitor.
	_check(int(board.get(&"dropped_lines")) == 0,
		"no line is dropped at 1280x720",
		"%d dropped, wants %.0f of %.0f"
			% [int(board.get(&"dropped_lines")), board.call(&"wanted_tall"), 720.0 - 40.0])
	_check(board.call(&"wanted_tall") <= 680.0,
		"and the board asks for no more room than it has",
		"%.0f of 680" % board.call(&"wanted_tall"))
	board.visible = _was_settings_shown
	_advance()


## The bind board's shape (2026-09-17): its two columns named, the gesture that is the only
## way back said once there is something to go back from, every word clearing 4.5:1, and the
## whole table fitting the smallest frame.
func _stage_binds_shape() -> void:
	var board: ControlsSkin = _main.get(&"_controls")
	if board == null:
		_main.call(&"_set_controls", true)
		board = _main.get(&"_controls")
	# Shown at the smallest frame the game can be given, with no override on it, and left to
	# draw itself — then again with one, so what is asked about the hint is what was drawn.
	# The player's own keys are taken down first and put back at the end.
	if _in_stage == 1:
		_binds_before = Binds.overrides()
		_binds_touched = true
		Binds.take_overrides({})
		board.size = Vector2(1280.0, 720.0)
		board.visible = true
		board.queue_redraw()
		return
	if _in_stage == 2:
		_hint_on_clean = board.hint_shown
		Binds.bind(&"interact", "key", "key:70")
		board.queue_redraw()
		return

	_check(ControlsSkin.RESET_LABEL == "Set to default",
		"the way back is called what it does", ControlsSkin.RESET_LABEL)

	# The two columns are named, and the gesture is said — but only when there is something
	# to go back from.
	var kinds := []
	for line: Dictionary in board.call(&"_plan"):
		kinds.append(String(line["kind"]))
	_check(kinds.front() == "columns",
		"the columns are named above the first group", ", ".join(kinds.slice(0, 3)))

	# The board's own drawing is what is asked, not a second layout worked out here.
	_check(not _hint_on_clean,
		"an untouched board explains no gesture nobody needs yet", str(_hint_on_clean))
	_check(board.hint_shown,
		"and says it once there is something to go back from", str(board.hint_shown))

	# The stick stands behind the walking rows, so their pad cell is not a bare dash.
	_check(Binds.standing_label(&"walk_up", "pad") == Binds.STICK_NAME,
		"a walking row's pad cell names the stick",
		Binds.standing_label(&"walk_up", "pad"))
	_check(Binds.standing_label(&"cast", "pad").is_empty(),
		"and a row with no stick behind it does not", Binds.standing_label(&"cast", "pad"))
	_check(Binds.standing_label(&"walk_up", "key").is_empty(),
		"nor does the keyboard column", Binds.standing_label(&"walk_up", "key"))

	# Every ink, against the face it is drawn on.
	var inks := {
		"a verb's name": [Style.BOARD_INK, Style.BOARD_ROW],
		"a name on a swapped row": [Style.BOARD_INK, ControlsSkin.SWAP_FACE],
		"a binding": [Style.BOARD_INK, Style.FRAME_SHADOW],
		"a cell waiting to be pressed": [Style.INK_DARK, Style.ON_GOLD],
		"a standing binding": [Style.BOARD_INK_SOFT, Style.FRAME_SHADOW],
		"the way back": [Style.INK, ControlsSkin.BUTTON_FACE],
		"the way back, with nothing to undo": [Style.BOARD_INK_SOFT, ControlsSkin.BUTTON_FACE],
		"a column's name": [Style.PAPER_HEAD, Style.PAPER],
		"the hint": [Style.PAPER_SOFT, Style.PAPER],
	}
	var faint := []
	var worst := 99.0
	for what: String in inks:
		var pair: Array = inks[what]
		var ratio := _contrast(pair[0], pair[1])
		worst = minf(worst, ratio)
		if ratio < 4.5:
			faint.append("%s %.2f:1" % [what, ratio])
	_check(faint.is_empty(),
		"every word on the bind board clears 4.5:1",
		"worst %.2f:1  %s" % [worst, ", ".join(faint)])

	# The swapped row is lifted off the plain one, or the lit edge is marking nothing.
	_check(_luminance(ControlsSkin.SWAP_FACE) > _luminance(Style.BOARD_ROW),
		"and a swapped row stands off a plain one",
		"%.4f against %.4f" % [_luminance(ControlsSkin.SWAP_FACE), _luminance(Style.BOARD_ROW)])

	_check(int(board.get(&"dropped_lines")) == 0,
		"no line is dropped at 1280x720",
		"%d dropped, wants %.0f of %.0f"
			% [int(board.get(&"dropped_lines")), board.call(&"wanted_tall"), 680.0])
	_check(board.call(&"wanted_tall") <= 680.0,
		"and the board asks for no more room than it has",
		"%.0f of 680" % board.call(&"wanted_tall"))

	# The question the foot plank asks. `Style.write` neither wraps nor clips, so a line or a
	# door label wider than the board it is on simply runs off the wood — which is how the
	# menu's own "The saved lake will be thrown away." had been overrunning by ten pixels.
	for asked: Array in [
		[MenuConfirm.BOARD_WIDE, ControlsSkin.CONFIRM_WORDS,
			ControlsSkin.CONFIRM_YES, ControlsSkin.CONFIRM_NO, "the bind board's question"],
		[MenuConfirm.BOARD_WIDE, MenuConfirm.WORDS,
			MenuConfirm.YES, MenuConfirm.NO, "the menu's own"],
	]:
		var line := float(asked[0]) - float(Style.BORDER_WALL) * 2.0 - MenuConfirm.BOARD_PAD * 2.0
		var door := (line - MenuConfirm.ROW_GAP) * 0.5
		var over := []
		if Style.measure(String(asked[1]), Style.TEXT_BODY).x > line:
			over.append("words %.0f of %.0f" % [Style.measure(String(asked[1]), Style.TEXT_BODY).x, line])
		for label: String in [String(asked[2]), String(asked[3])]:
			if Style.measure(label, Style.TEXT_BODY).x > door:
				over.append("%s %.0f of %.0f" % [label, Style.measure(label, Style.TEXT_BODY).x, door])
		_check(over.is_empty(), "%s fits its own board" % asked[4], ", ".join(over))

	if _binds_touched:
		Binds.take_overrides(_binds_before)
		_check(Binds.overrides() == _binds_before,
			"and the player's own keys are put back", str(Binds.overrides().size()))
	board.visible = false
	_main.call(&"_set_controls", false)
	_advance()


## How wide the upgrades count's badge comes out for a given count. The badge draws itself,
## so this repeats its sum rather than reading it back — the check is that the sum ignores
## the text it is given, which a drawn plate cannot be asked.
func _badge_width(text: String) -> float:
	var height := maxi(HudButtons.LABEL_LEAST, int(HudButtons.BADGE_TALL * HudButtons.BADGE_TEXT))
	return maxf(
		Style.measure(HudButtons.BADGE_SAMPLE, height).x, Style.measure(text, height).x
	) + HudButtons.BADGE_PAD * 2.0


## WCAG 2.1 relative-luminance contrast between two opaque colours.
func _contrast(a: Color, b: Color) -> float:
	var one := _luminance(a)
	var two := _luminance(b)
	return (maxf(one, two) + 0.05) / (minf(one, two) + 0.05)


func _luminance(c: Color) -> float:
	var parts := [c.r, c.g, c.b]
	var lit := []
	for v: float in parts:
		lit.append(v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4))
	return 0.2126 * float(lit[0]) + 0.7152 * float(lit[1]) + 0.0722 * float(lit[2])


## The menu over the lake (2026-09-17). The harness's lake is borrowed, so it wears no front
## of its own; the menu is raised by hand and the rules are asked of it.
##
## Waits on drawn frames and on the glide itself, never on harness frames — this node steps
## in `_physics_process` and the lake's `_process` is an idle callback, see `_ferry_step`.
var _front_step: int = 0
var _front_mark: int = 0
var _front_held: int = 0
var _front_sludge: float = 0.0


## Every piece that is out of the water and not yet sold: in the crate, in a hold, in a
## mouth, in a net, or in the air on its way to one of those. Cargo already thrown at a
## yard's box is as good as sold and is not counted.
func _pieces_in_hand() -> int:
	var total := _yard.held.size()
	for boat: Boat in _main.get(&"_boats") as Array:
		total += boat.cargo.size()
	for dog: Dog in _main.get(&"_dogs") as Array:
		total += dog.carrying()
	for net in [_net, _main.get(&"_net2")]:
		if net != null:
			total += (net as CastNet).catch.size()
	var haul := _main.get(&"_haul") as Haul
	for piece: Dictionary in haul.get(&"_flying") as Array:
		if not (piece["tag"] is Dropoff):
			total += 1
	return total


## The loading screen (2026-09-17): the game opens on the boot scene, and its bar is the
## HUD's meter with nothing on its end, at the HUD's size, swept filthy to clean.
func _check_loading() -> void:
	var first := String(ProjectSettings.get_setting("application/run/main_scene"))
	_check(first == "res://scenes/boot.tscn", "the game opens on the boot scene", first)
	var screen := LoadingScreen.new()
	add_child(screen)
	var bar := screen.bar()
	var circles := 0
	var waters := 0
	for node in bar.get_children():
		var sheet := node as TextureRect
		if sheet == null or sheet.texture == null:
			continue
		if sheet.texture.resource_path.contains("Garbage_Circle"):
			circles += 1
		if sheet.texture.resource_path.contains("Murky_Water"):
			waters += 1
	_check(circles == 0 and waters == 1 and bar.get_child_count() == 2,
		"the loading bar is the meter's water in its frame, and no garbage circle",
		"%d children, %d circles" % [bar.get_child_count(), circles])
	var skin := _main.get(&"_skin") as Control
	var hud_frame: Rect2 = skin.get(&"_meter_frame_box")
	_check(absf(bar.size.x - hud_frame.size.x) <= 1.0 and absf(bar.size.y - hud_frame.size.y) <= 1.0,
		"drawn at the HUD meter's own size, not a bigger one",
		"bar %s, hud %s" % [str(bar.size), str(hud_frame.size)])
	var rising := true
	var last := -1.0
	for i in 21:
		var at := Boot.sweep_at(Boot.SWEEP * float(i) / 20.0)
		if at < last:
			rising = false
		last = at
	_check(rising and is_zero_approx(Boot.sweep_at(0.0))
		and is_equal_approx(Boot.sweep_at(Boot.SWEEP), 1.0),
		"the sweep runs from filthy to clean and never back", "")
	# The shader's seam is where the *filth* ends, so an untouched bar has it at the far end of
	# the track and a finished one at the near end: green first, the clean water coming in
	# from the right, as on the HUD. Handed the clean share straight, the first cut swept from
	# clean to filthy; mirrored to fill left to right, the second was not the game's meter.
	var water := bar.get_node_or_null(^"Water") as TextureRect
	_check(water != null and not water.flip_h,
		"the bar's water is the HUD's way round, not mirrored", "")
	var track: Rect2 = HudSkin.METER_TRACK
	var sheet_wide: float = HudSkin.METER_SHEET.x
	screen.progress = 0.0
	_check(is_equal_approx(bar.seam(), track.end.x / sheet_wide),
		"a bar that has not started is filth from end to end", "%.3f" % bar.seam())
	screen.progress = 1.0
	_check(is_equal_approx(bar.share, 1.0) and is_equal_approx(bar.seam(), track.position.x / sheet_wide),
		"and a finished one is clean from end to end", "%.3f" % bar.seam())
	# The way out: the logo and the bar go at once and the lake alone dissolves. Faded with
	# it they went in pieces, each layer against what was under it.
	screen.dress(false)
	var picture := screen.get_node_or_null(^"Picture") as CanvasItem
	_check(not screen.dressed() and not bar.visible and picture != null and picture.visible,
		"undressed, the loading screen is the lake alone", "")
	var fill := screen.get_node_or_null(^"Fill") as CanvasItem
	_check(fill != null and not fill.visible,
		"and no flat colour lies under the picture to wash through it", "")
	screen.queue_free()
	var curtain := Curtain.new()
	add_child(curtain)
	curtain.open_on()
	var loading := curtain.get_node(^"Loading") as LoadingScreen
	var whole := loading.dressed() and loading.visible
	for i in Curtain.HOLD_FRAMES + 1:
		curtain.call(&"_process", 0.016)
	_check(whole and not loading.dressed() and loading.visible,
		"the curtain holds the screen whole, then takes the logo and the bar off in one frame", "")
	curtain.queue_free()


## The pump beside the hut and the wash room it opens (issue #37): a find waits at the pump,
## is picked off a tray if the purse covers its soap, is washed on the stand, and only then
## reaches the shed — paid for when it comes clean, and not at all if the player walks away.
## The shelf's wash plank (2026-09-22): shown only while a find waits at the pump, right
## after the last row and scrolling with them, alone under the empty line, pulsing the
## first time the shelf opens with more waiting, and swapping the shed for the wash room.
func _check_wash_plank() -> void:
	var room: ShedRoom = _main.get_node(^"HUD/Shed/Pad/Lines/Room")
	var unwashed: Array = _main.get(&"unwashed")
	var unlocked: Array = _main.get(&"unlocked")
	var shelf_was := unlocked.duplicate()
	unlocked.clear()
	room.set(&"_wash_seen", 0)
	room.set(&"_wash_pulse", 0.0)
	room.set(&"_wash_unseen", false)
	_main.call(&"_set_shed", true)
	room.call(&"_dress_shelf")
	var box: Rect2 = room.wash_plank_box()
	var list: Rect2 = room.call(&"_list_rect")
	_check(box.size.x > 0.0, "with a find waiting and nothing kept, the wash plank stands alone", str(box))
	_check(box.position.y > list.position.y + 8.0 and box.end.y <= list.end.y,
		"under the empty line and on the shelf", "%s in %s" % [box, list])
	var plank: PlankButton = room.get(&"_wash_plank")
	_check(plank.label == "Wash  1", "and says how many wait", plank.label)
	_check(room.wash_pulse_amount() == 0.0 and float(room.get(&"_wash_pulse")) > 0.0,
		"it pulses the first time the shelf opens with something waiting", str(room.get(&"_wash_pulse")))
	room.call(&"_process", 0.3)
	_check(room.wash_pulse_amount() > 0.0 and plank.pulse > 0.0, "the pulse breathes and reaches the plank", str(plank.pulse))
	# The room clamps a frame to 0.1 s (a hitch is not a dog across the room), so it is
	# walked there in short steps.
## The purse over the shop (2026-09-24): the HUD's own money plate, hung under the first
## board on a node drawn after the shop, and home again when the shop closes.
func _check_shop_purse(skin: Node) -> void:
	var hud: HudSkin = _main.get(&"_skin")
	_main.call(&"_set_menu", true)
	skin.call(&"_lay_out")
	_main.call(&"_update_hud")
	var box := hud.purse_over
	var purse: Node = hud.get(&"_purse")
	_check(box.size.x > 0.0 and purse != null and purse.visible,
		"with the shop open the purse is hung over it", str(box))
	_check(purse != null and purse.get_index() > skin.get_index(),
		"on a node drawn after the shop, so nothing of the shop covers it", "")
	var boards: Dictionary = skin.get(&"_boards")
	var clear := true
	for b: Rect2 in boards.values():
		clear = clear and not b.intersects(box)
	var legend: Rect2 = skin.get(&"_legend_box")
	_check(clear and not legend.intersects(box) and hud.get_rect().encloses(box),
		"it stands on the screen, clear of every board and the pricing plate", str(box))
	_check(box.size == hud.money_size(), "the same plate, at the corner plate's own size", "")
	_check(HudButtons.face_of(box).has_point(hud.coin_centre()), "coins aim at it there", "")
	_main.call(&"_set_menu", false)
	_check(hud.purse_over.size.x == 0.0 and not purse.visible, "and it goes home with the shop closed", "")


## The bonus's lit panel on the pricing plate (2026-09-24): it holds the name and the figure
## with room to spare, stays inside the plate, and no star lands on the words.
func _check_bonus_panel() -> void:
	var name_box := Rect2(100.0, 30.0, 60.0, 12.0)
	var figure_box := Rect2(110.0, 50.0, 40.0, 12.0)
	var room := Rect2(40.0, 20.0, 180.0, 60.0)
	var panel := ShopSkin.bonus_panel(name_box, figure_box, room)
	var words := name_box.merge(figure_box)
	_check(panel.encloses(words), "the bonus panel holds the material's name and figure", str(panel))
	_check(room.encloses(panel), "and stays inside its slot of the plate", str(panel))
	var reach := LakeGrid.STAR_PIXEL * (float(LakeGrid.STAR_ARM) + 0.5)
	var bad := []
	for i in 40:
		var at := ShopSkin.bonus_star_at(panel, words, i % 2 == 0, float(i % 7) / 6.0, float(i % 5) / 4.0)
		var star := Rect2(at - Vector2.ONE * reach, Vector2.ONE * reach * 2.0)
		if star.intersects(words) or not room.encloses(star):
			bad.append(str(at))
	_check(bad.is_empty(), "no star touches the words or leaves the plate", ", ".join(bad))


	for i in 50:
		room.call(&"_process", 0.1)
	_check(is_equal_approx(float(room.get(&"_wash_pulse")), ShedRoom.WASH_PULSE_IDLE),
		"after the burst it settles to a quieter breathing and keeps going", str(room.get(&"_wash_pulse")))
	var before := room.wash_pulse_amount()
	room.call(&"_process", 0.1)
	_check(room.wash_pulse_amount() != before or room.wash_pulse_amount() > 0.0, "still moving", str(room.wash_pulse_amount()))
	plank.pressed.emit()
	_check(float(room.get(&"_wash_pulse")) == 0.0 and room.wash_pulse_amount() == 0.0,
		"and clicking the plank is what puts it out", "")
	_main.call(&"_set_wash", false)
	_main.call(&"_set_shed", false)
	_main.call(&"_set_shed", true)
	_check(float(room.get(&"_wash_pulse")) == 0.0, "reopened with no more waiting, it does not pulse again", "")
	unwashed.append(String(unwashed[0]))
	_main.call(&"_set_shed", false)
	_main.call(&"_set_shed", true)
	_check(float(room.get(&"_wash_pulse")) > 0.0, "one more waiting, and it does", "")
	unwashed.pop_back()

	# Under the rows, and scrolling with them.
	for i in 3:
		unlocked.append(String(shelf_was[0]) if not shelf_was.is_empty() else "decor_bed")
	room.call(&"_dress_shelf")
	box = room.wash_plank_box()
	var rows := room.in_store().size()
	_check(rows == 3 and is_equal_approx(box.position.y,
			list.position.y + float(rows * ShedRoom.ROW_HEIGHT) + ShedRoom.WASH_UNDER_ROWS),
		"with finds kept it stands after the last row, clear of it", "%d rows, plank at %.0f, list at %.0f" % [rows, box.position.y, list.position.y])
	# Under one row (2026-09-24): the plank's frame and glow ran up into the row above.
	while room.in_store().size() > 1:
		unlocked.pop_back()
	room.call(&"_dress_shelf")
	box = room.wash_plank_box()
	var row_foot := list.position.y + float(ShedRoom.ROW_HEIGHT) - ShedRoom.SHELF_ROW_GAP
	_check(box.size.x > 0.0 and box.position.y - row_foot >= ShedRoom.WASH_UNDER_ROWS
			and box.end.y <= list.end.y,
		"under a single row it stands clear of the row and whole on the shelf", "%s, row foot %.0f" % [box, row_foot])
	for i in 2:
		unlocked.append(String(unlocked[0]))
	var fill := int(list.size.y / float(ShedRoom.ROW_HEIGHT)) + 2
	while room.in_store().size() < fill:
		unlocked.append(String(unlocked[0]))
	room.call(&"_dress_shelf")
	_check(room.wash_plank_box().size.x == 0.0, "on an overfull shelf it is off the face until scrolled to", "")
	room.call(&"_scroll_by", 100000.0)
	room.call(&"_dress_shelf")
	box = room.wash_plank_box()
	_check(box.size.x > 0.0 and box.end.y <= list.end.y + 0.5,
		"scrolled to the end, it is the last thing on the shelf", str(box))
	room.call(&"_scroll_by", -100000.0)

	# Nothing waiting, no plank.
	var waiting := unwashed.duplicate()
	unwashed.clear()
	room.call(&"_dress_shelf")
	_check(room.wash_plank_box().size.x == 0.0, "with nothing waiting there is no plank", "")
	unwashed.append_array(waiting)

	# The click: shed down, wash room up.
	room.call(&"_dress_shelf")
	room.wash_asked.emit()
	_check(not bool(_main.get(&"_shed_open")) and bool(_main.get(&"_wash_open")),
		"clicking it swaps the shed for the wash room", "shed %s, wash %s" % [_main.get(&"_shed_open"), _main.get(&"_wash_open")])
	_main.call(&"_set_wash", false)
	unlocked.clear()
	unlocked.append_array(shelf_was)


## The upgrades button's pulse (2026-09-22): fires when the affordable count rises, never
## on a hold or a fall, breathes, fades out on its own, and is cut by a hover or the shop.
func _check_upgrades_pulse() -> void:
	var skin := _main.get(&"_skin") as HudSkin
	skin.hush_pulse(&"upgrades")
	var now := skin.available
	skin.available = now
	_check(not skin.pulsing(&"upgrades"), "the same count again starts no pulse", "")
	skin.available = now + 1
	_check(skin.pulsing(&"upgrades") and skin.pulse_amount(&"upgrades") == 0.0, "one more affordable starts it, from nothing", str(skin.pulse_amount(&"upgrades")))
	skin.call(&"_process", 0.35)
	_check(skin.pulse_amount(&"upgrades") > 0.05, "and it breathes", str(skin.pulse_amount(&"upgrades")))
	skin.available = now
	_check(skin.pulsing(&"upgrades"), "a fall does not reset it", "")
	skin.call(&"_process", 6.0)
	_check(skin.pulsing(&"upgrades") and is_equal_approx(float((skin.get(&"_pulses") as Dictionary)[&"upgrades"]), HudSkin.PULSE_IDLE),
		"after the burst it settles to a quieter breathing and keeps going", str(skin.get(&"_pulses")))
	var box: Rect2 = skin.get(&"_upgrades_box")
	var motion := InputEventMouseMotion.new()
	motion.position = box.get_center()
	skin.call(&"_gui_input", motion)
	_check(skin.pulsing(&"upgrades"), "a hover does not put it out: the shop has not been seen", "")
	motion.position = Vector2(-50.0, -50.0)
	skin.call(&"_gui_input", motion)
	_main.call(&"_set_menu", true)
	_check(not skin.pulsing(&"upgrades") and skin.pulse_amount(&"upgrades") == 0.0, "opening the shop does", "")
	_main.call(&"_set_menu", false)
	skin.call(&"_process", 6.0)
	_check(not skin.pulsing(&"upgrades"), "and it stays out", "")
	skin.available = now + 2
	_check(skin.pulsing(&"upgrades"), "one more affordable starts it again", "")
	_main.call(&"_set_menu", true)
	_main.call(&"_set_menu", false)
	skin.available = now
	skin.hush_pulse(&"upgrades")

	# The decorate button, for a find arriving at the pump.
	var waiting := skin.waiting
	skin.waiting = waiting
	_check(not skin.pulsing(&"shed"), "the decorate button holds still while nothing new waits", "")
	skin.waiting = waiting + 1
	_check(skin.pulsing(&"shed") and not skin.pulsing(&"upgrades"),
		"a find arriving at the pump pulses the decorate button, and only it", "")
	_main.call(&"_set_shed", true)
	_check(not skin.pulsing(&"shed"), "opening the shed puts it out", "")
	_main.call(&"_set_shed", false)
	skin.waiting = waiting


func _stage_wash() -> void:
	var sheets: Sheets = _main.get(&"_sheets")
	_check(Pump.tile != Vector2.INF, "the pump stands somewhere", str(Pump.tile))
	_check(Iso.on_island_ground(Pump.tile) and not Iso.in_shed(Pump.tile.x, Pump.tile.y, 0.3),
		"on the island's ground, clear of the hut's walls", str(Pump.tile))
	_check(not Yard.covers(_angler.crate_tile, Pump.tile, 1.0), "and clear of the crate", "")
	_check(Pump.covers(Pump.tile) and not Pump.covers(Pump.tile + Vector2(1.0, 0.0)),
		"it covers its own square and no more", "")

	# Walked round, not through, and sorted behind when north of it.
	var stood := _angler.tile_pos
	_angler.tile_pos = Pump.tile + Vector2(1.0, 1.0)
	_check(not bool(_angler.call(&"_can_stand", Pump.tile)), "the angler cannot stand in it", "")
	_check(bool(_main.call(&"_at_pump")), "but beside it is close enough to work it", "")
	var pump: Node2D = _main.get(&"_pump")
	var north := Iso.tile_to_world(Pump.tile.x - 0.5, Pump.tile.y - 0.5)
	var south := Iso.tile_to_world(Pump.tile.x + 0.6, Pump.tile.y + 0.6)
	_check(int(_main.call(&"_walker_layer", north)) < pump.z_index,
		"somebody north of the pump is drawn behind it",
		"%d under %d" % [int(_main.call(&"_walker_layer", north)), pump.z_index])
	_check(int(_main.call(&"_walker_layer", south)) > pump.z_index,
		"and somebody south of it in front", "")
	_angler.tile_pos = Pump.tile + Vector2(6.0, 6.0)
	_check(not bool(_main.call(&"_at_pump")), "away from it the key is not the pump's", "")
	_angler.tile_pos = stood

	# The room.
	var find := ""
	for name: String in sheets.names:
		if WashRoom.is_find(sheets, name) and name != "decor_bed":
			find = name
			break
	var unlocked: Array = _main.get(&"unlocked")
	var unwashed: Array = _main.get(&"unwashed")
	var shelf_was := unlocked.duplicate()
	var purse_was: float = _main.get(&"sludge")
	# An empty shelf for this: the stages before it leave their own finds on it, this one's
	# among them, and "not on the shelf yet" has to mean something.
	unlocked.clear()
	unwashed.clear()
	unwashed.append(find)
	_main.set(&"sludge", 0.0)
	_main.call(&"_set_wash", true)
	var room: WashRoom = _main.get(&"_wash")
	_check(room != null and room.visible and bool(_main.call(&"_panelled")),
		"working the pump opens the wash room, and it holds the lake's hands", "")
	# What is behind the stand: the view from the pump, its water the lake's own.
	var back := room.backdrop()
	_check(back != null and back.is_painted() and back.get_index() < room.stand().get_index()
		and not room.stand().bare_room,
		"the room has a painted backdrop under the stand, and the stand draws no wall", "")
	_check(WashBackdrop.state_of(1.0) == LakeGrid.FILTH_STATES and WashBackdrop.state_of(0.0) == 0,
		"its water is the dirtiest state on a full lake and clean on an empty one", "")
	var pal := Palette.master()
	_check(back.ramp_of(0)[2] == pal.water_clean and back.ramp_of(4)[2] == pal.water_dirty
		and back.ramp_of(2)[0] == pal.water_murky_deep,
		"in the palette's own ramps", "")
	_check(is_equal_approx(back.filth, float(_main.get(&"pollution"))),
		"and it was handed the lake's meter when the room came up",
		"%.2f against %.2f" % [back.filth, float(_main.get(&"pollution"))])
	_check(back.sky_at(0.0)[0] == pal.sky_morning_high and back.sky_at(0.5)[1] == pal.sky_noon_low
		and back.sky_at(1.0)[0] == pal.sky_afternoon_high
		and pal.sky_noon_high != Color.WHITE,
		"the sky is the palette's, by the day's hour", "")
	_check(back.modulate.v < 0.95 and back.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"the whole of it is darkened behind the find, and takes no clicks", "%.2f" % back.modulate.v)
	_check(room.stand().hiss_is_recorded(), "the jet is the recording, not the built noise", "")
	# The view is alive, and answers the jet.
	var station := MusicStation.main()
	_check(station == null or station.muffled,
		"the song goes through the radio behind the wash room, as behind the shop", "")
	_check(back.dogs().size() == (_main.get(&"_dogs") as Array).size() and back.dogs().size() >= 1,
		"the pack is out on the lawn behind the stand, dog for dog", str(back.dogs().size()))
	var lawn_top := back.lake_box().end.y
	var all_on_lawn := true
	for hound in back.dogs():
	# One row on the tray sits wholly on its face, not on the frame's foot (2026-09-24).
	var tray_face := Style.board_face(room.tray_box(), WashRoom.TRAY_FRAME)
	var tray_rows := room.row_boxes()
	_check(tray_rows.size() == 1 and tray_face.encloses(tray_rows[0].grow(1.0)),
		"a single find on the tray stands inside its face", "%s in %s" % [tray_rows, tray_face])
		all_on_lawn = all_on_lawn and hound.at.y > lawn_top and hound.at.y < room.size.y * 0.9
	_check(all_on_lawn, "between the beach and the stand's feet", "")
	var was_clock := back.stepped()
	back.step(0.05)
	_check(is_equal_approx(back.stepped(), was_clock) or back.stepped() - was_clock >= 1.0 / WashBackdrop.PIXEL_FPS - 0.001,
		"what moves moves on a stepped clock", "")
	var bird := back.send_bird(true, 0.3)
	_check(bird != null, "a pigeon can be sent across, off the flock's own sheet", "")
	if bird != null:
		for k in 20:
			back.step(0.1)
		var flew := back.bird_at(bird)
		_check(flew.x > 100.0 and not bird.startled, "it flies across untroubled", str(flew))
		back.sprayed_at(flew + Vector2(200.0, 0.0))
		_check(not bird.startled, "a jet well wide of it troubles nothing", "")
		back.sprayed_at(flew)
		var height := flew.y
		for k in 5:
			back.step(0.1)
		_check(bird.startled and back.bird_at(bird).y < height - 30.0,
			"the jet on it sends it up and away", "%.0f to %.0f" % [height, back.bird_at(bird).y])
	# Which way things face is their owner's answer, never this file's guess.
	if bird != null:
		_check(back.bird_facing(bird) == Flock.facing_of(Vector2.ZERO, Vector2(1.0, 0.0))
			and Flock.facing_of(Vector2.ZERO, Vector2(1.0, 0.0)) < 0.0,
			"a pigeon heading right is handed the flock's own facing: the flipped sheet", "")
	var east: Dictionary = back.hull_art(1.0)
	var west: Dictionary = back.hull_art(-1.0)
	_check(not east.is_empty() and east["region"] != west["region"],
		"a ferry sailing right and one sailing left are different frames", "")
	var frames := 16
	_check(is_equal_approx(Boat.turn_sailing(Vector2.RIGHT),
			(float(Boat.frame_heading(Vector2(1.0, -1.0), frames)) + 0.5) / float(frames)),
		"picked by the boat's own heading rule: screen-right is tile (1, -1)", "")
	_check(back.hulls().size() == int(_main.call(&"fleet_size")),
		"as many ferries cross as the fleet holds", str(back.hulls().size()))
	back.filth = 1.0
	var full := back.flotsam_shown()
	back.filth = 0.5
	var half := back.flotsam_shown()
	back.filth = 0.0
	_check(full == WashBackdrop.RUBBISH_MOST and half < full and half > 0
		and back.flotsam_shown() == 0,
		"rubbish floats on it by the meter: a full lake's worth, thinning to none",
		"%d / %d / %d" % [full, half, back.flotsam_shown()])
	back.filth = float(_main.get(&"pollution"))
	room.call(&"_process", 0.016)
	_check(back.shade.z > 0.0 and back.shade == room.stand().shade,
		"the dogs are lent the day's shadow, the same one the stand throws", str(back.shade))
	var lanes_quick := true
	for lane: Array in WashBackdrop.BOAT_LANES:
		lanes_quick = lanes_quick and float(lane[2]) >= 30.0
	_check(lanes_quick and WashBackdrop.FOAM_ROWS.size() >= 1,
		"the ferries cross at a pace, and what floats wears a foam collar", "")
	var pup := back.dogs()[0]
	var sat := pup.at
	back.sprayed_at(sat - Vector2(0.0, 10.0))
	for k in 5:
		back.step(0.1)
	_check(pup.bolting and pup.pose == &"run" and absf(pup.at.x - sat.x) > 40.0,
		"and a dog under the jet bolts", "%.0f px" % absf(pup.at.x - sat.x))
	_check(room.stand().jet_past_piece() == Vector2.INF,
		"a jet that is off tells the backdrop nothing", "")
	var sound := Sfx.main()
	if sound != null:
		_check(not sound.may_play(&"bark") and not sound.may_play(&"pigeon_coo"),
			"the lake's own barks and coos are still shut out of the room", "")
	_check(not room.stand().bare_room and room.stand().ground_tone.v <= 1.0,
		"the stand is lent the lawn's tone for the grass at its feet", "")
	_check(WashStand.HISS_OFF_PIECE - WashStand.HISS_ON_PIECE < 0.15
		and WashStand.HISS_ON_PIECE < 1.0 and WashStand.HISS_OFF_PIECE > 1.0,
		"duller on the piece and brighter off it, narrowly", "")
	var soap := room.soap_of(StringName(find))
	var prices := {}
	for name: String in sheets.names:
		# The new game's bed washes free (the decoration tour): every other find pays.
		if WashRoom.is_find(sheets, name) and not room.free.has(name):
			prices[room.soap_of(StringName(name))] = true
	_check(room.soap_of(StringName(Lake.STARTER_BED)) == 0, "the starter bed washes free", "")
	_check(prices.size() == 3 and prices.has(5) and prices.has(10) and prices.has(15),
		"soap is 5, 10 or 15, and the catalogue has finds at all three", str(prices.keys()))
	_check(not room.pick(StringName(find)) and room.on_stand() == &"",
		"a purse that cannot cover the soap leaves the find on the tray", "")
	_main.set(&"sludge", 100.0)
	_check(room.pick(StringName(find)) and room.on_stand() == StringName(find),
		"one that can puts it on the stand", "")
	_check(is_equal_approx(float(_main.get(&"sludge")), 100.0), "and nothing is charged for picking", "")

	# Walked away from half washed: back on the tray, unpaid for.
	var stand := room.stand()
	var box := stand.piece_box()
	for k in 40:
		stand.spray(box.position + box.size * Vector2(0.5, float(k) / 40.0), true)
		stand.call(&"_process", 0.05)
	var part := stand.share_clean()
	_check(part > 0.02 and part < 0.99, "spraying it wears the coat away", "%.2f clean" % part)
	_main.call(&"_set_wash", false)
	_check(unwashed.has(find) and not unlocked.has(find)
		and is_equal_approx(float(_main.get(&"sludge")), 100.0),
		"walking away leaves it unwashed and unpaid for", "")
	_main.call(&"_set_wash", true)
	_check(room.on_stand() == &"" and stand.state == WashStand.State.EMPTY,
		"and the stand is bare when the room comes back", "")

	# The table is furniture: one size, whatever stands on it.
	var bare_top: Rect2 = stand.call(&"_stand_top")
	var tops_same := true
	for name: String in ["decor_sofa", "decor_table_lamp", find]:
		if WashRoom.is_find(sheets, name):
			stand.put(StringName(name))
			tops_same = tops_same and (stand.call(&"_stand_top") as Rect2).is_equal_approx(bare_top)
			tops_same = tops_same and float(stand.call(&"_stand_pad")) >= 1.0
	stand.clear()
	_check(tops_same, "the table is the same size under a sofa, a lamp and nothing", str(bare_top))

	# Washed right through.
	room.pick(StringName(find))
	_check(is_zero_approx(stand.share_clean()), "picked again it wears its whole coat again",
		"%.2f clean" % stand.share_clean())
	var passes := 0
	while stand.state == WashStand.State.WASHING and passes < 4000:
		var along := float(passes % 60) / 60.0
		var down := float((passes / 60) % 12) / 12.0 + 0.04
		stand.spray(box.position + box.size * Vector2(along, down), true)
		stand.call(&"_process", 0.05)
		passes += 1
	_check(stand.state != WashStand.State.WASHING, "sprayed all over, it finishes by itself",
		"%d passes, %.3f clean" % [passes, stand.share_clean()])
	for k in 60:
		stand.call(&"_process", 0.05)
	_check(unlocked.has(find) and not unwashed.has(find),
		"clean, it is on the shed's shelf and off the tray", "")
	_check(is_equal_approx(float(_main.get(&"sludge")), 100.0 - float(soap)),
		"and the soap was charged then, once", "%.0f left, soap %d" % [float(_main.get(&"sludge")), soap])

	# Saved as a name, read back as one.
	unwashed.append(find)
	_check(bool(_main.call(&"save_game")), "a find waiting at the pump is written out", "")
	unwashed.clear()
	_check(bool(_main.call(&"load_game")), "and read back", "")
	unwashed = _main.get(&"unwashed")
	_check(unwashed.size() == 1 and String(unwashed[0]) == find, "still waiting",
		str(unwashed))

	_main.call(&"_set_wash", false)
	_check_wash_plank()
	_check_upgrades_pulse()
	unwashed.clear()
	unlocked = _main.get(&"unlocked")
	unlocked.clear()
	unlocked.append_array(shelf_was)
	_main.set(&"sludge", purse_was)
	_main.call(&"save_game")
	_advance()


func _stage_front() -> void:
	var dogs: Array = _main.get(&"_dogs")
	var boats: Array = _main.get(&"_boats")
	var camera := _main.get(&"_camera") as Camera2D
	match _front_step:
		0:
			_check_loading()
			# Something of every kind in flight: a hold at sea, a stick in a mouth, a catch
			# in the net. The pose may lose none of it and may sell none of it.
			for panel in [&"_set_controls", &"_set_settings", &"_set_menu", &"_set_shed"]:
				_main.call(panel, false)
			var def := 0
			var hull := boats[0] as Boat
			hull.cargo = PackedInt32Array([def, def])
			hull.state = Boat.State.SAILING
			hull.tile_pos = hull.dock + Vector2(6.0, 6.0)
			(dogs[0] as Dog).set(&"_carried", PackedInt32Array([def]))
			_net.catch.append(def)
			_net.state = CastNet.State.REELING
			# Everything the lake has out of the water and not yet sold, wherever it is: the
			# stages before this one leave holds and mouths as they found them.
			_front_held = _pieces_in_hand()
			_front_sludge = float(_main.get(&"sludge"))
			_main.call(&"_enter_menu", false)
			_check(bool(_main.get(&"_in_menu")), "the menu goes up over the lake", "")
			var menu := _main.get(&"_menu") as MainMenu
			_check(menu != null and menu.live(), "and its doors answer", "")
			var asleep := 0
			var ashore := 0
			for dog: Dog in dogs:
				if dog.dozing and int(dog.get(&"_state")) == Dog.State.NAP:
					asleep += 1
				if bool(dog.call(&"_on_land")):
					ashore += 1
			_check(asleep == dogs.size() and ashore == dogs.size(),
				"every dog is asleep on the grass behind it",
				"%d asleep, %d ashore of %d" % [asleep, ashore, dogs.size()])
			var home := 0
			for boat: Boat in boats:
				if boat.moored and not boat.is_running() and boat.cargo.is_empty() \
						and boat.tile_pos.is_equal_approx(boat.dock):
					home += 1
			_check(home == boats.size(), "every hull is moored at its berth, hold empty",
				"%d of %d" % [home, boats.size()])
			_check(_net.state == CastNet.State.IDLE and _net.catch.is_empty(),
				"the net is home", "")
			_check(_yard.held.size() == _front_held and _front_held >= 4,
				"and the hold, the stick and the catch are all in the crate",
				"%d in hand -> %d in the crate" % [_front_held, _yard.held.size()])
			_check(is_equal_approx(float(_main.get(&"sludge")), _front_sludge),
				"nothing was sold by the pose", "")
			_check(not (_main.get(&"_hud_layer") as CanvasLayer).visible,
				"the HUD is off", "")
			_check(not _angler.can_walk, "the angler stands idle", "")
			_check(bool(_main.call(&"pad_cursor_wanted")), "the pad drives a pointer", "")
			var stops: Array = _main.call(&"_zoom_stops")
			_check(is_equal_approx(camera.zoom.x, float(stops[0])),
				"the view is the whole lake, on the far stop", "%.3f" % camera.zoom.x)
			# Continue is the run's door, and the accent is on whichever door goes in.
			var planks: Dictionary = menu.get(&"_planks")
			menu.has_run = false
			_check(not (planks[&"continue"] as Control).visible
				and (planks[&"new"] as PlankButton).accent,
				"with no run there is no Continue, and New game is the lit door", "")
			menu.has_run = true
			_check((planks[&"continue"] as Control).visible
				and (planks[&"continue"] as PlankButton).accent
				and not (planks[&"new"] as PlankButton).accent,
				"with a run Continue is there and is the lit one", "")
			# The lake reads nothing: Escape here used to mean the settings.
			var escape := InputEventKey.new()
			escape.keycode = KEY_ESCAPE
			escape.pressed = true
			_main.call(&"_unhandled_input", escape)
			_check(not bool(_main.get(&"_settings_open")),
				"Escape behind the menu does not open the lake's settings", "")
			# A full crate and a clock run out: neither may move anything behind the menu.
			for i in (boats[0] as Boat).capacity:
				_yard.put(def)
			if FileAccess.file_exists(SAVE_PATH):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
			_main.set(&"_autosave_in", 0.0)
			_front_mark = Engine.get_process_frames()
			_front_step = 1
		1:
			if Engine.get_process_frames() - _front_mark < 8:
				return
			var sailing := 0
			for boat: Boat in boats:
				if boat.is_running():
					sailing += 1
			_check(sailing == 0, "a full crate sends no ferry out from behind the menu",
				"%d sailing" % sailing)
			_check(not FileAccess.file_exists(SAVE_PATH),
				"and the autosave does not write a pose", "")
			var menu := _main.get(&"_menu") as MainMenu
			menu.call(&"_take", &"continue")
			_check(not bool(_main.get(&"_in_menu")) and float(_main.get(&"_glide")) >= 0.0,
				"Continue takes the menu off and starts the glide", "")
			var awake := 0
			for dog: Dog in dogs:
				if not dog.dozing:
					awake += 1
			var free := 0
			for boat: Boat in boats:
				if not boat.moored:
					free += 1
			_check(awake == dogs.size() and free == boats.size(),
				"the pack and the fleet are let go at once", "")
			_check(not _angler.can_walk, "but the angler's legs wait for the view to land", "")
			_front_mark = Engine.get_process_frames()
			_front_step = 2
		2:
			if float(_main.get(&"_glide")) >= 0.0:
				if Engine.get_process_frames() - _front_mark > 2400:
					_check(false, "the glide ends", "still gliding")
					_finish()
				return
			var stops: Array = _main.call(&"_zoom_stops")
			var on_stop := false
			for stop: float in stops:
				if is_equal_approx(camera.zoom.x, stop):
					on_stop = true
			# The stop nearest the play zoom. Headless has one stop (a dummy display's stretch
			# is near nothing, so every level is MAX_ZOOM), so "in from the far end" cannot be
			# asked here; that it is a stop, and the play one, can.
			var typed: Array[float] = []
			typed.assign(stops)
			var play: float = typed[Lake._nearest_stop(typed, Lake.VIEW_ZOOM)]
			_check(on_stop and is_equal_approx(camera.zoom.x, play),
				"the glide lands on a whole stop, the play one", "%.3f" % camera.zoom.x)
			_check(_angler.can_walk, "and the angler has their legs back", "")
			var skin := _main.get(&"_skin") as Control
			_check((_main.get(&"_hud_layer") as CanvasLayer).visible
				and is_equal_approx(skin.modulate.a, 1.0), "the HUD is back, whole", "")
			# And out again: no scene change, the run written once the pose is struck.
			if FileAccess.file_exists(SAVE_PATH):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
			_net.catch.append(0)
			_net.state = CastNet.State.REELING
			var held := _pieces_in_hand()
			_main.call(&"_quit")
			_check(bool(_main.get(&"_in_menu")) and _main.is_inside_tree()
				and get_tree().current_scene != null,
				"Save and go to menu raises the menu on this same lake", "")
			_check(FileAccess.file_exists(SAVE_PATH), "and writes the run", "")
			_check(_yard.held.size() == held,
				"with the net's catch in the crate, not lost to the save",
				"%d in hand -> %d in the crate" % [held, _yard.held.size()])
			_main.call(&"_begin_glide")
			_front_step = 3
		3:
			if float(_main.get(&"_glide")) >= 0.0:
				return
			_advance()


## The led cast (2026-09-22): a cast press out of reach walks the angler into reach and
## throws; one no spot on the island reaches walks to the nearest shore and stops; walk
## input, a board and a new press each end or replace it. Runs on the lake the front stage
## left playable.
var _led_step_n: int = 0
var _led_mark: int = 0
var _led_spot := Vector2.ZERO
var _led_start := Vector2.ZERO


## Water `out` tiles past the angler, straight away from the island's middle.
func _water_out(out: float) -> Vector2:
	var dir := (_angler.tile_pos - Iso.ISLAND_CENTRE).normalized()
	return Iso.tile_to_world(_angler.tile_pos.x + dir.x * out, _angler.tile_pos.y + dir.y * out)


func _stage_led_cast() -> void:
	match _led_step_n:
		0:
			if _net.state != CastNet.State.IDLE:
				if _in_stage > 2400:
					_check(false, "the net is home for the led cast", "state %d" % _net.state)
					_finish()
				return
			_stand_on_the_shore()
			_led_start = _angler.tile_pos
			# Off the far side of the island: in reach from that shore, not from this one.
			var dir := (_angler.tile_pos - Iso.ISLAND_CENTRE).normalized()
			var over: Vector2 = _angler.shore_toward(Iso.ISLAND_CENTRE - dir * 20.0)
			_led_spot = Iso.tile_to_world(
				over.x - dir.x * (_net.range_tiles - 0.6), over.y - dir.y * (_net.range_tiles - 0.6))
			_check(not _net.in_reach(_led_spot), "the spot starts out of reach", "")
			_main.call(&"_cast_or_walk", _led_spot)
			_check(_main.get(&"_led_cast") == _led_spot and bool(_main.get(&"_led_throw")),
				"a press out of reach commits a led cast with a throw owed", "")
			_check(_angler.walk_to != Vector2.INF, "and the angler is led", str(_angler.walk_to))
			_check(_net.state == CastNet.State.IDLE, "nothing is thrown yet", "")
			_led_mark = _in_stage
			_led_step_n = 1
		1:
			if _net.state == CastNet.State.IDLE:
				if _in_stage - _led_mark > 900:
					_check(false, "the walk ends in a throw", "still walking, led %s" % _main.get(&"_led_cast"))
					_finish()
				return
			_check(_net.state == CastNet.State.FLYING, "the net is thrown on arrival", "state %d" % _net.state)
			_check(_angler.tile_pos.distance_to(_led_start) > 0.5, "after a real walk",
				"%.2f tiles" % _angler.tile_pos.distance_to(_led_start))
			_check(_net.in_reach(_led_spot), "from a spot that reaches the click", "")
			_check(_main.get(&"_led_cast") == Vector2.INF and _angler.walk_to == Vector2.INF,
				"and the lead is dropped", "")
			_led_mark = _in_stage
			_led_step_n = 2
		2:
			if _net.state != CastNet.State.IDLE:
				if _in_stage - _led_mark > 2400:
					_check(false, "the net comes home", "state %d" % _net.state)
					_finish()
				return
			# Nowhere on the island reaches the far bank: the walk ends at the shore, no throw.
			var far := Iso.tile_to_world(Iso.CENTRE.x, Iso.CENTRE.y + Iso.RADIUS.y * 0.9)
			var shore: Vector2 = _angler.shore_toward(Iso.world_to_tile(far))
			_main.call(&"_cast_or_walk", far)
			_check(_main.get(&"_led_cast") == far and not bool(_main.get(&"_led_throw")),
				"a press nothing reaches walks with no throw owed", "")
			_check(_angler.walk_to == shore, "towards the shore nearest the click", str(shore))
			_led_spot = shore
			_led_mark = _in_stage
			_led_step_n = 3
		3:
			if _main.get(&"_led_cast") != Vector2.INF:
				if _in_stage - _led_mark > 1200:
					_check(false, "the shore walk ends", "still led")
					_finish()
				return
			_check(_net.state == CastNet.State.IDLE, "nothing thrown at the shore", "state %d" % _net.state)
			_check(_angler.tile_pos.distance_to(_led_spot) < Angler.LED_CLOSE + 0.5,
				"the angler stands at that shore", "%.2f off" % _angler.tile_pos.distance_to(_led_spot))
			# Water off the far side again, for the cancels: out of reach, reachable.
			var dir := (_angler.tile_pos - Iso.ISLAND_CENTRE).normalized()
			var over: Vector2 = _angler.shore_toward(Iso.ISLAND_CENTRE - dir * 20.0)
			var a := Iso.tile_to_world(
				over.x - dir.x * (_net.range_tiles - 0.6), over.y - dir.y * (_net.range_tiles - 0.6))
			var b := Iso.tile_to_world(
				over.x - dir.x * (_net.range_tiles - 1.2), over.y - dir.y * (_net.range_tiles - 1.2))
			_check(not _net.in_reach(a) and not _net.in_reach(b), "both cancel spots start out of reach", "")
			# Walk input cancels.
			_main.call(&"_cast_or_walk", a)
			var led: bool = _main.get(&"_led_cast") != Vector2.INF
			Input.action_press(&"walk_left")
			_main._process(1.0 / 60.0)
			Input.action_release(&"walk_left")
			_check(led and _main.get(&"_led_cast") == Vector2.INF and _angler.walk_to == Vector2.INF,
				"a walk key ends the lead", "")
			# A board cancels.
			_main.call(&"_cast_or_walk", a)
			led = _main.get(&"_led_cast") != Vector2.INF
			_main.call(&"_set_menu", true)
			_main._process(1.0 / 60.0)
			_check(led and _main.get(&"_led_cast") == Vector2.INF, "the shop opening ends it", "")
			_main.call(&"_set_menu", false)
			# A new press retargets.
			_main.call(&"_cast_or_walk", a)
			_main.call(&"_cast_or_walk", b)
			_check(_main.get(&"_led_cast") == b, "a second press retargets", "")
			_main.call(&"_stop_led_cast")
			# A press on the island's ground walks there; on the hut it is nothing.
			var lawn := Iso.ISLAND_CENTRE + Vector2(0.0, 3.5)
			_check(bool(_angler.call(&"_can_stand", lawn)), "the lawn spot can be stood on", str(lawn))
			_main.call(&"_cast_or_walk", Iso.tile_to_world(lawn.x, lawn.y))
			_check(_angler.walk_to == lawn and not bool(_main.get(&"_led_throw")),
				"a press on the isle walks there with no throw", str(_angler.walk_to))
			_main.call(&"_stop_led_cast")
			_main.call(&"_cast_or_walk", Iso.tile_to_world(Iso.ISLAND_CENTRE.x, Iso.ISLAND_CENTRE.y))
			_check(_main.get(&"_led_cast") == Vector2.INF and _angler.walk_to == Vector2.INF,
				"a press on the hut is nothing", "")
			# The ring: solid over water a walk reaches, dashed over water none does and over
			# the bank, none at all on the island (the source is read for the island's return).
			_check(_net.castable_after_walk(a) and not _net.in_reach(a),
				"far-side water is castable after a walk though not in reach", "")
			var bank := Iso.tile_to_world(Iso.CENTRE.x, Iso.CENTRE.y + Iso.RADIUS.y * 0.9)
			_check(not _net.castable_after_walk(bank), "the far bank's water is not", "")
			var sand := Iso.tile_to_world(Iso.CENTRE.x, Iso.CENTRE.y + Iso.RADIUS.y + 2.0)
			_check(not _net.castable_after_walk(sand) and not _net.in_reach(sand),
				"nor is the outer bank's sand", "")
			_check(not _net.castable_after_walk(Iso.tile_to_world(lawn.x, lawn.y)),
				"nor the island", "")
			var aim_src := (load("res://scripts/net.gd") as GDScript).source_code
			var draw_at := aim_src.find("func _draw_aim()")
			var island_at := aim_src.find("Iso.island_fraction(over.x, over.y) < 1.0:
		return", draw_at)
			var legal_at := aim_src.find("castable_after_walk(pointer)", draw_at)
			_check(draw_at >= 0 and island_at > draw_at and legal_at > island_at,
				"the ring draws nothing on the island and solid where a walk reaches", "")
			# A press in reach throws at once, as it always did.
			var near := _water_near_angler()
			_main.call(&"_cast_or_walk", near)
			_check(_net.state == CastNet.State.FLYING and _main.get(&"_led_cast") == Vector2.INF,
				"a press in reach is the plain throw", "state %d" % _net.state)
			_advance()


## The first steps (`scripts/first_steps.gd`): walk to the beach spot with the cast held,
## a sure-catch ring, the note after a catch, a pad's note shutting on its own, and the
## flag. Driven by hand through the lake's own step, once the led cast's net is home.
func _stage_first_steps() -> void:
	if _net.state != CastNet.State.IDLE:
		if _in_stage > 2400:
			_check(false, "the net is home for the first steps", "state %d" % _net.state)
			_finish()
		return
	_main.set(&"_steps_done", false)
	_main.call(&"_first_steps_step", 0.016)
	var steps: FirstSteps = _main.get(&"_steps")
	_check(steps != null and steps.step == FirstSteps.Step.MOVE,
		"the steps start on the walk", str(steps.step if steps != null else -1))
	if steps == null:
		_finish()
		return
	var beach: Vector2 = _main.get(&"_steps_beach")
	var water: Vector2 = _main.get(&"_steps_water")
	_check(beach != Vector2.INF and bool(_angler.call(&"_can_stand", beach)),
		"the beach spot is ground the angler can stand on", str(beach))
	_check(bool(_main.call(&"_sure_catch", water)),
		"the cast ring is a sure catch all over", str(water))
	_main.call(&"_cast_or_walk", water)
	_check(_net.state == CastNet.State.IDLE, "the cast is held on the walk", str(_net.state))
	_main.call(&"_stop_led_cast")
	_angler.tile_pos = beach
	_main.call(&"_first_steps_step", 0.016)
	_check(steps.step == FirstSteps.Step.CAST, "standing on the spot moves to the cast", "")
	_main.call(&"_on_net_swept", water, 0, 4, 20.0, _net)
	_check(steps.step == FirstSteps.Step.CAST, "an empty sweep keeps the cast step", "")
	_main.call(&"_on_net_swept", water, 1, 4, 20.0, _net)
	_check(steps.step == FirstSteps.Step.NOTE, "a catching sweep raises the note", "")
	Pad.set_mode(Pad.Mode.PAD)
	_main.call(&"_first_steps_step", 0.016)
	_check(float(_main.get(&"_steps_left")) <= 5.0, "a pad's note shuts after five seconds",
		str(_main.get(&"_steps_left")))
	Pad.set_mode(Pad.Mode.MOUSE)
	_main.call(&"_first_steps_step", 6.0)
	_check(steps.step == FirstSteps.Step.OFF and bool(_main.get(&"_steps_done")),
		"the note times out and the steps are done", "")
	_check(FirstSteps.key_tile("Z") == "key_z" and FirstSteps.key_tile("Y") == "",
		"a key with a prompt tile gets it, one without falls back", "")
	# The shop's tour: starts on the first opening, keeps its place over a close, blocks
	# buying, and ends saved.
	var shop: ShopSkin = _main.get(&"_shop_skin")
	_main.set(&"_shop_tour_done", false)
	shop.tour = -1
	_main.call(&"_set_menu", true)
	_check(shop.tour == 0, "the shop's tour starts on its first opening", str(shop.tour))
	shop.tour_next()
	shop.tour_next()
	_main.call(&"_set_menu", false)
	_main.call(&"_set_menu", true)
	_check(shop.tour == 2, "a tour closed half way picks up where it was", str(shop.tour))
	var shop_src := (load("res://scripts/shop_skin.gd") as GDScript).source_code
	_check(shop_src.find("if tour >= 0:
		_tour_input(event)
		return") >= 0,
		"nothing is bought while the tour is up", "")
	for i in ShopSkin.TOUR.size():
		shop.tour_next()
	_check(shop.tour == -1 and bool(_main.get(&"_shop_tour_done")),
		"the last card ends the tour and it is saved as done", str(shop.tour))
	_main.call(&"_set_menu", false)
	_main.call(&"_set_menu", true)
	_check(shop.tour == -1, "a finished tour is not shown again", str(shop.tour))
	_main.call(&"_set_menu", false)
	# The decoration tour: the bed at the pump, the hint giving way to the shed, the cards
	# following the rooms, a washed find walking back into the shed, and the flag.
	var bed := Lake.STARTER_BED
	_main.call(&"_bed_to_the_pump")
	_check((_main.get(&"unwashed") as Array).has(bed) and not (_main.get(&"unlocked") as Array).has(bed),
		"a new game's bed waits at the pump", "")
	var placed := false
	for row: Dictionary in _main.get(&"decor"):
		placed = placed or String(row["piece"]) == bed
	_check(not placed, "and does not stand in the shed", "")
	_main.set(&"_decor_tour_done", false)
	_main.set(&"_decor_tour", Lake.DecorTour.HINT)
	_main.call(&"_set_shed", true)
	_check(int(_main.get(&"_decor_tour")) == Lake.DecorTour.PLANK,
		"opening the shed turns the hint into the wash plank's card", str(_main.get(&"_decor_tour")))
	_main.call(&"_decor_tour_next")
	_main.call(&"_shed_to_wash")
	_check(int(_main.get(&"_decor_tour")) == Lake.DecorTour.LIST, "the wash room opens on the list's card", "")
	_main.call(&"_decor_tour_next")
	_main.call(&"_decor_tour_next")
	_check(int(_main.get(&"_decor_tour")) == Lake.DecorTour.WASHING, "then the stand's, then the washing", "")
	var purse: float = _main.get(&"sludge")
	_main.call(&"_on_find_washed", StringName(bed), 0)
	_check(is_equal_approx(float(_main.get(&"sludge")), purse), "the bed cost nothing", "")
	_main.call(&"_decor_tour_step", Lake.DECOR_BACK_AFTER + 0.1)
	_check(bool(_main.get(&"_shed_open")) and not bool(_main.get(&"_wash_open"))
		and int(_main.get(&"_decor_tour")) == Lake.DecorTour.SHELF,
		"a washed find walks the player back into the shed, on the shelf's card", "")
	_main.call(&"_decor_tour_next")
	_main.call(&"_decor_tour_next")
	_check(bool(_main.get(&"_decor_tour_done")) and int(_main.get(&"_decor_tour")) == Lake.DecorTour.OFF,
		"the room's card ends the tour, saved", "")
	_main.call(&"_set_shed", false)
	_finish()



func _stage_new_tracks() -> void:
	var tracks: Dictionary = _main.get(&"_upgrades")
	var missing := []
	for key in ["boat_volley", "dog_strength"]:
		if not tracks.has(StringName(key)):
			missing.append(key)
	_check(missing.is_empty(), "Fast Sell and Strong Dogs both load", ", ".join(missing))
	# Every track the shop sells says what it is, or the "?" on its row has nothing to show.
	var blurbs: Dictionary = _main.get(&"BLURBS")
	var unexplained := []
	for key: StringName in _main.get(&"TRACKS") as Array:
		if not blurbs.has(key):
			unexplained.append(String(key))
	_check(unexplained.is_empty(), "and every track has a blurb", ", ".join(unexplained))

	# ---- Fast Sell
	_main.set(&"boat_volley_level", 0)
	var gap_at_zero := float(_main.call(&"boat_volley_gap"))
	_check(is_equal_approx(gap_at_zero, 1.0), "an untrained ferry throws at the ordinary gap",
		"%.2f" % gap_at_zero)
	var cap: int = (tracks[&"boat_volley"] as UpgradeTrack).level_cap
	var last := gap_at_zero
	var slid := true
	for level in range(1, cap + 1):
		_main.set(&"boat_volley_level", level)
		var gap := float(_main.call(&"boat_volley_gap"))
		if gap >= last:
			slid = false
		last = gap
	_check(slid, "and every level takes more off the gap", "")
	_check(is_equal_approx(last, 0.4), "down to 40% of it at the top", "%.2f" % last)

	# The gap is what shrinks; the flight never is, so a maxed volley is the whole hold in
	# the air at once and not a teleport.
	var full := Haul.volley_time(24)
	var quick := Haul.volley_time(24, last)
	_check(quick < full, "a full hold lands sooner for it",
		"%.2f -> %.2f s" % [full, quick])
	_check(quick >= Haul.FLIGHT, "but never quicker than one piece's own arc",
		"%.2f against %.2f" % [quick, Haul.FLIGHT])
	_check(is_equal_approx(Haul.volley_time(24), full),
		"and a volley nobody scales is untouched", "%.2f s" % Haul.volley_time(24))

	# It reaches the hulls and only the hulls: the net's throw into the island crate is sent
	# without a scale, so it pours at the pace it always did.
	_main.call(&"_push_boat_numbers")
	var unpushed := 0
	for boat: Boat in _main.get(&"_boats") as Array:
		if not is_equal_approx(boat.volley_gap, last):
			unpushed += 1
	_check(unpushed == 0, "every hull is told", "%d were not" % unpushed)

	# ---- Strong Dogs
	_main.set(&"dog_strength_level", 0)
	_check(int(_main.call(&"dog_carry_tier")) == Dog.CARRY_TIER
		and is_equal_approx(float(_main.call(&"dog_carry_wide")), Dog.CARRY_WIDE),
		"an untrained dog fetches what it always did",
		"tier %d, %.0f wide" % [int(_main.call(&"dog_carry_tier")),
			float(_main.call(&"dog_carry_wide"))])
	var dog_cap: int = (tracks[&"dog_strength"] as UpgradeTrack).level_cap
	var tier_rose := true
	var wide_rose := true
	var tier_last := int(_main.call(&"dog_carry_tier"))
	var wide_last := float(_main.call(&"dog_carry_wide"))
	for level in range(1, dog_cap + 1):
		_main.set(&"dog_strength_level", level)
		var tier := int(_main.call(&"dog_carry_tier"))
		var wide := float(_main.call(&"dog_carry_wide"))
		if tier <= tier_last:
			tier_rose = false
		if wide <= wide_last:
			wide_rose = false
		tier_last = tier
		wide_last = wide
	_check(tier_rose and wide_rose, "training raises the tier and the mouth together",
		"tier %d, %.0f wide" % [tier_last, wide_last])
	_check(tier_last == 4 and is_equal_approx(wide_last, 32.0),
		"to tier 4 and 32 wide at the top", "tier %d, %.0f" % [tier_last, wide_last])

	# What that opens, asked of the catalogue rather than written down twice: every kind a
	# dog's mouth is wide enough for (2026-09-21, Richard: the width rule stays; anything
	# wider is the net's alone). Nothing is turned down for its weight at the top.
	var refused := []
	var too_heavy := []
	var taken := 0
	for def: TrashDef in _grid.defs:
		if def.keepsake:
			continue
		if def.tier <= tier_last and def.size.x <= wide_last:
			taken += 1
		elif def.tier > tier_last:
			too_heavy.append(String(def.piece))
		else:
			refused.append(String(def.piece))
	_check(taken > 50, "a strong dog will carry most of the lake", "%d kinds" % taken)
	_check(too_heavy.is_empty(), "and turns nothing down for its weight at the top",
		", ".join(too_heavy))
	_check(refused.size() < 12, "only the widest pieces are the net's alone",
		", ".join(refused))

	_main.call(&"_push_dog_numbers")
	var untold := 0
	for dog: Dog in _main.get(&"_dogs") as Array:
		if dog.carry_tier != tier_last or not is_equal_approx(dog.carry_wide, wide_last):
			untold += 1
	_check(untold == 0, "and every dog in the pack is told", "%d were not" % untold)

	# A dog looking for a stick reads the pushed numbers, so a trained pack really does pick
	# up what an untrained one walked past.
	var strong_reach := int(_main.get(&"_dogs").size())
	_check(strong_reach > 0, "the pack is in the lake", "%d dogs" % strong_reach)

	# Both levels survive a save, on the ordinary `levels` dictionary: a key a save was
	# written without reads as level 0, so no SAVE_VERSION bump was owed.
	_main.set(&"boat_volley_level", 2)
	_main.set(&"dog_strength_level", 3)
	_check(bool(_main.call(&"save_game")), "the run writes itself out again", "")
	_main.set(&"boat_volley_level", 0)
	_main.set(&"dog_strength_level", 0)
	_check(bool(_main.call(&"load_game")), "and reads itself back", "")
	_check(int(_main.get(&"boat_volley_level")) == 2
		and int(_main.get(&"dog_strength_level")) == 3,
		"with both new levels on it",
		"%d, %d" % [int(_main.get(&"boat_volley_level")),
			int(_main.get(&"dog_strength_level"))])
	_advance()


## The letter: the four onboarding cards, the pager, the room they need, and the save flag
## that decides whether a new game plays the arrival at all (2026-09-19, issue #24).
##
## The board is laid out at **1280x720**, the smallest window the game allows, because that
## is the one where a board runs out of room — the settings, bind and credits boards are
## asked the same question and for the same reason.
func _stage_letter() -> void:
	var letter := Letter.new()
	letter.size = Vector2(1280.0, 720.0)
	add_child(letter)
	letter.open()

	_check(Letter.CARDS.size() == 5, "the letter is five cards",
		"%d" % Letter.CARDS.size())
	var heads: Array = []
	var long_cards: Array = []
	for card: Dictionary in Letter.CARDS:
		heads.append(String(card["head"]))
		if card.has("text") and (letter.call(&"_rows", card) as Dictionary).is_empty():
			long_cards.append(String(card["head"]))
	_check(heads == ["", "Net", "Upgrades", "Object Tier", "Decoration"],
		"named for what each one teaches, the welcome bare", ", ".join(heads))
	_check(String(Letter.CARDS[0].get("title", "")) == "Welcome"
		and not Letter.CARDS[1].has("title"),
		"the plank says Welcome over the first card and How to play over the rest", "")
	_check(bool(Letter.CARDS[0].get("letter", false)), "and the first is set like a letter", "")
	_check(long_cards.is_empty(),
		"and none says more than the rows the board reserves", ", ".join(long_cards))
	_check(Letter.TITLE == "How to play", "the plank says what the board is", Letter.TITLE)
	_check(Letter.GREETING.contains("new owner") and Letter.GREETING.ends_with(Letter.GREETING_NAME),
		"the greeting ends on the lake's name", Letter.GREETING)
	var sizes: Array = letter.greeting_sizes()
	_check(int(sizes[1]) > int(sizes[0])
		and letter.call(&"_greeting_wide", sizes[0], sizes[1]) <= letter.text_wide(),
		"written on one line with the name a size up", "%s of %.0f" % [str(sizes), letter.text_wide()])
	# The Net card's captions say their colour in it: the ring's green and red darkened to
	# clear the paper, and the out-of-range one underlined in the soft ink.
	var net: Dictionary = Letter.CARDS[1]
	var inks: Array = []
	for snap: Array in net["snaps"]:
		inks.append(StringName(snap[2]))
	_check(inks == [&"ok", &"no", &"far"], "the net card's captions are inked by ring",
		str(inks))
	for key: StringName in [&"ok", &"no"]:
		var ink: Color = Letter.CAPTION_INKS[key]
		_check(_contrast(ink, Style.PAPER) >= 4.5, "and the %s caption clears the paper" % key,
			"%.2f:1" % _contrast(ink, Style.PAPER))
	_check(Letter.CAPTION_INKS[&"ok"].g > Letter.CAPTION_INKS[&"ok"].r
		and Letter.CAPTION_INKS[&"no"].r > Letter.CAPTION_INKS[&"no"].g,
		"green reads green and red reads red", "")
	# Heading over the sentence over the pictures, on every card but the welcome, whose lake
	# stands under the greeting and over its paragraphs (2026-09-24).
	var inside_first := (letter.get(&"_sheet") as Rect2).grow(-Letter.SHEET_PAD)
	var welcome_art := letter.call(&"_art_box", inside_first) as Rect2
	_check(not (Letter.CARDS[0]["snaps"] as Array).is_empty()
		and welcome_art.end.y <= float(letter.call(&"_head_base", inside_first)),
		"the welcome's lake stands under the greeting and over its words", "")
	letter.page = 1
	letter.call(&"_lay_out")
	var head_at := float(letter.call(&"_head_base", inside_first))
	var art_first := letter.call(&"_art_box", inside_first) as Rect2
	_check(head_at < float(letter.call(&"_text_foot", inside_first))
		and float(letter.call(&"_text_foot", inside_first)) <= art_first.position.y,
		"the heading stands over the words and the words over the pictures", "")
	letter.page = 0
	letter.call(&"_lay_out")

	# The pager: a dot a card, clamped at both ends rather than wrapping round.
	_check((letter.get(&"_dots") as Array).size() == Letter.CARDS.size(),
		"one dot a card", "")
	letter.turn(-1)
	_check(letter.page == 0, "the first card cannot be paged back off", "%d" % letter.page)
	_check(not (letter.get(&"_door") as Control).visible,
		"and carries no door: there is still something to read", "")
	for _i in Letter.CARDS.size() + 3:
		letter.turn(1)
	_check(letter.page == Letter.CARDS.size() - 1,
		"the last card is the last one", "%d" % letter.page)
	var door := letter.get(&"_door") as PlankButton
	_check(door.visible and door.label == "Start cleaning",
		"which is where the way out is, and says what it does", door.label)
	_check((letter.get(&"_close") as Control).visible,
		"the cross is there from the first card, so nobody is trapped", "")

	# Room, at the smallest window the game will draw. The credits board's own question.
	_check(letter.wanted_tall() <= 680.0, "the board fits the smallest window",
		"%.0f of 680" % letter.wanted_tall())
	# The first cut's net card ran its second line clean over both stiles: `Style.write`
	# neither wraps nor clips. Every line and caption is measured against the paper now.
	var over := letter.overruns()
	_check(over.is_empty(), "and every line and caption fits the paper", ", ".join(over))
	# Measured rather than drawn: headless has no renderer, so `_draw` — and the
	# `dropped_lines` it sets — never runs. `tools/shot_letter.tscn` is what reads that.
	var sheet := letter.get(&"_sheet") as Rect2
	var way_out := letter.get(&"_door") as Control
	var dots: Array = letter.get(&"_dots")
	_check(sheet.encloses(Rect2(way_out.position, way_out.size)),
		"with its door on the paper", "")
	var door_mid := way_out.position.x + way_out.size.x * 0.5
	var sheet_mid := sheet.position.x + sheet.size.x * 0.5
	var inside_last := sheet.grow(-Letter.SHEET_PAD)
	_check(absf(door_mid - sheet_mid) <= 1.0
		and way_out.position.y >= inside_last.end.y - Letter.PAGER_TALL - 1.0,
		"centred in the pager's row", "door %.0f sheet %.0f" % [door_mid, sheet_mid])
	_check(dots.is_empty() and (letter.get(&"_back") as Rect2).size != Vector2.ZERO
		and (letter.get(&"_on") as Rect2).size == Vector2.ZERO,
		"with no dots and no forward arrow, but the way back", "%d dots" % dots.size())
	letter.turn(-1)
	_check(letter.page == Letter.CARDS.size() - 2, "and the last card pages back", "%d" % letter.page)
	letter.page = 1
	letter.call(&"_lay_out")
	var art_early := letter.call(&"_art_box", sheet.grow(-Letter.SHEET_PAD)) as Rect2
	letter.page = Letter.CARDS.size() - 1
	letter.call(&"_lay_out")
	var art_last := letter.call(&"_art_box", sheet.grow(-Letter.SHEET_PAD)) as Rect2
	_check(is_equal_approx(art_early.end.y, art_last.end.y),
		"so the pictures reach the same foot on every card", "%.0f then %.0f" % [art_early.end.y, art_last.end.y])
	# The words that matter are marked for the head ink, and a mark never reaches the paper.
	var marked := 0
	for card: Dictionary in Letter.CARDS:
		var words: Array = Letter._tokens(String(card.get("text", "")))
		for snap: Array in card["snaps"]:
			words.append_array(Letter._tokens(String(snap[1])))
		for word: Dictionary in words:
			for seg: Array in word["segs"]:
				marked += 1 if bool(seg[1]) else 0
				if String(seg[0]).contains("*"):
					marked = -1000
	_check(marked > 0, "some words are marked for the head ink, and no asterisk is drawn", "%d" % marked)
	var tiers: Array = letter.call(&"_rows", Letter.CARDS[3])["rows"]
	_check(tiers.size() == 2 and bool(tiers[1]["para"]) and not bool(tiers[0]["para"]),
		"the tier card is two paragraphs", "%d rows" % tiers.size())
	var net_rows: Array = letter.call(&"_rows", Letter.CARDS[1])["rows"]
	var net_paras := 0
	for row: Dictionary in net_rows:
		net_paras += 1 if bool(row["para"]) else 0
	_check(net_paras == 1 and int(letter.call(&"_rows", Letter.CARDS[1])["px"]) == Style.TEXT_BODY,
		"and the net card two, at the body size", "%d rows, %d paragraphs" % [net_rows.size(), net_paras])
	_check(bool(Letter.CARDS[2].get("blurbs", false)) and not Letter.CARDS[2].has("text"),
		"the upgrades card stands each board over its own sentence", "")
	letter.page = 2
	letter.call(&"_lay_out")
	var blurb_caps: Array = letter.get(&"_captions")
	var in_a_row := blurb_caps.size() == 3
	for i in blurb_caps.size():
		var cap: Dictionary = blurb_caps[i]
		in_a_row = in_a_row and bool(cap.get("blurb", false)) \
			and (cap["box"] as Rect2).size.y > Letter.CAPTION_TALL \
			and (i == 0 or (cap["box"] as Rect2).position.x > (blurb_caps[i - 1]["box"] as Rect2).position.x)
	_check(in_a_row, "three in a row, each with rows for its words", "%d" % blurb_caps.size())

	# The pictures are the game's own photographs. A still that is not there is a probe
	# nobody re-ran, and the card would show a blank print.
	var blank := letter.missing_stills()
	_check(blank.is_empty(), "every card's snapshots have been shot and imported",
		", ".join(blank))
	var crowded := []
	for card: Dictionary in Letter.CARDS:
		var pinned: Array = card["snaps"]
		if pinned.is_empty() or pinned.size() > Letter.SNAPS_MOST:
			crowded.append(String(card["head"]))
	_check(crowded.is_empty(), "one to three to a card, the welcome's lake included",
		", ".join(crowded))
	var welcome: Array = (letter.call(&"_rows", Letter.CARDS[0]) as Dictionary).get("rows", [])
	_check(welcome.size() >= 3 and bool(welcome[welcome.size() - 1]["para"]),
		"the welcome card carries its three sentences whole, each its own paragraph",
		"%d rows" % welcome.size())
	# The greeting is the first card's, and the others give its room to their pictures.
	var inside := sheet.grow(-Letter.SHEET_PAD)
	letter.page = 0
	var first := (letter.call(&"_art_box", inside) as Rect2).size.y
	letter.page = 1
	var second := (letter.call(&"_art_box", inside) as Rect2).size.y
	_check(second >= Letter.ART_LEAST - 1.0 and second > first + 20.0,
		"the greeting's and the welcome's room goes to the pictures after the first card",
		"%.0f then %.0f" % [first, second])
	letter.queue_free()

	# The save flag. A file written before this existed has no such key, and **absent means
	# seen**: the arrival is for a new game, never for somebody's run in progress.
	_main.set(&"_intro_done", false)
	_check(bool(_main.call(&"save_game")), "the run writes itself out", "")
	var path := String(_main.get(&"save_path"))
	var file := FileAccess.open(path, FileAccess.READ)
	var save: Dictionary = file.get_var(true)
	file.close()
	_check(save.has("intro_done") and not bool(save["intro_done"]),
		"carrying the flag it was written with", "")
	save.erase("intro_done")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_var(save, true)
	file.close()
	_check(bool(_main.call(&"load_game")), "an older save reads back", "")
	_check(bool(_main.get(&"_intro_done")),
		"and a save with no such key has already seen it", "")

	# Closing the cards is what ends the arrival: the flag is written, the hull may sail and
	# the player has their legs back.
	_main.set(&"_intro_done", false)
	(_main.get(&"_boats") as Array)[0].moored = true
	# The last beat of the walk, driven the way `_process` drives it: the step raises the
	# letter itself and then has somewhere to stand.
	_main.set(&"_arrive", Lake.Arrive.WALKING)
	_main.set(&"_arrive_wait", 0.0)
	_angler.walk_to = Vector2.INF
	_main.call(&"_arrival_step")
	_check(bool(_main.get(&"_letter_open")) and not _angler.can_walk,
		"the walk ends by raising the letter, and it holds the angler", "")
	# And the step is asked again every frame the cards are up. It used to answer by
	# reopening them, which put the reader back on the first card — so the cards could not
	# be paged at all. The state it moves to is what stops that.
	var board := _main.get(&"_letter") as Letter
	board.page = 2
	_main.call(&"_arrival_step")
	_main.call(&"_arrival_step")
	_check(board.page == 2, "and does not turn the page back under the reader",
		"page %d" % board.page)
	_main.call(&"_set_letter", false)
	_check(int(_main.get(&"_arrive")) == 0 and bool(_main.get(&"_intro_done")),
		"closing them ends the arrival and writes the flag", "")
	_check(not ((_main.get(&"_boats") as Array)[0] as Boat).moored,
		"and lets the ferry go to work", "")
	_check(_angler.can_walk, "the player has their hands back", "")

	# The only way back to the cards once the intro is over.
	# The harness's lake is borrowed, so it has never raised the front and has no menu yet.
	_main.call(&"_build_menu")
	var menu := _main.get(&"_menu") as MainMenu
	var keys: Array = []
	for door_row: Dictionary in MainMenu.DOORS:
		keys.append(String(door_row["key"]))
	_check(keys.find("how") == keys.find("credits") - 1,
		"the menu's How to play plank stands above Credits", ", ".join(keys))
	_check(menu != null and menu.letter() != null, "and opens the same board", "")
	_advance()


## Clears what the sound owes a catch and the gaps that pace it, and nothing else of the
## autoload's: the lake behind the harness is still using the rest.
func _forget_catch(sound: Sfx) -> void:
	sound.set(&"_swell_wait", -1.0)
	(sound.get(&"_drips") as Array).clear()
	(sound.get(&"_last") as Dictionary).erase(&"swell")
	(sound.get(&"_last") as Dictionary).erase(&"grab")
