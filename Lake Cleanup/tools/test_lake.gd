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
const TEST_FERRY_SPEED := 60.0

var _main: Node2D
var _grid: LakeGrid
var _boat: Boat
var _angler: Angler
var _net: CastNet
var _yard: Yard

var _stage: int = 0
var _in_stage: int = 0
var _ran: int = 0
var _failed: int = 0

var _walk_from := Vector2.ZERO
var _pieces_before: int = 0
var _filth_before: float = 1.0
var _sludge_before: float = 0.0
var _gesture_checked: bool = false
var _flock: Flock
var _rebuilds_before: int = 0
var _skim_kind: int = 0
var _skimmed_kinds: Array[int] = []


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
			_stage_skimmer()
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
		_:
			pass


func _advance() -> void:
	_stage += 1
	_in_stage = 0


## A tile of genuinely deep water within casting distance of the island's south side.
## Not the basin's middle any more — the island stands there.
func _deep_tile() -> int:
	return _grid.index_of(
		int(Iso.CENTRE.x), int(Iso.CENTRE.y + Iso.ISLAND_RADIUS.y + 4.0)
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
	_check(_boat.skim_radius < 0, "it has no skimmer fitted",
		"radius %d" % _boat.skim_radius)

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

	# Held at the dock for the casting and yard-cap stages, which need the yard to stay
	# where they put it. Switched back on in _stage_ferry, which is what tests the toggle.
	_main.call(&"_set_auto_ferry", false)
	_check(not _boat.auto_ferry, "the ferry can be told to stay put", "")
	_advance()


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
	if _in_stage == 1:
		_main.set(&"sludge", 1000.0)
		_check(not _boat.is_running(),
			"a ferry told to stay put has not moved all this time", "")
		_main.call(&"_set_auto_ferry", true)
		_boat.speed = TEST_FERRY_SPEED
		_sludge_before = float(_main.get(&"sludge"))
		_pieces_before = _yard.held.size()
		_check(_pieces_before > 0, "there is a load waiting", "%d pieces" % _pieces_before)
		return
	if _in_stage < 4:
		return
	if _in_stage == 4:
		_check(_boat.is_running(), "the ferry sets off on its own",
			"it is %s" % _boat.status_line())
		# Out of the yard, not yet aboard: the lot is thrown to the hold one piece at a time
		# (`Boat.stow`), so `cargo` fills over the next frames. The sale below is what proves
		# it arrived.
		_check(_yard.held.size() < _pieces_before,
			"loading took the catch out of the yard",
			"%d aboard, %d left in the yard" % [_boat.cargo.size(), _yard.held.size()])
		return
	if _boat.runs_done < 1 and _in_stage < 500:
		return
	_check(_boat.runs_done == 1, "the ferry completed a run", "after %d frames" % _in_stage)
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


## The skimmer: off until it is bought, then fishing on the way — for the material it is
## delivering, and only some of what it goes over.
func _stage_skimmer() -> void:
	if _in_stage == 1:
		_main.set(&"sludge", 100000.0)
		for i in 3:
			_main.call(&"_buy", &"skimmer")
		_check(_boat.skim_radius == 2, "buying the skimmer widens it",
			"radius %d" % _boat.skim_radius)
		_check(_boat.skim_chance > 0.0 and _boat.skim_chance < 1.0,
			"the skimmer is a chance, not a certainty",
			"%.0f%%" % (_boat.skim_chance * 100.0))
		_check(_boat.skim_hold > 0, "the skimmer has deck space of its own",
			"+%d" % _boat.skim_hold)
		_check(_boat.skim_depth > 1, "it digs past the top of a stack for its material",
			"%d slots" % _boat.skim_depth)

		# One material only, so every single thing the skimmer brings up on this run has
		# to be that material or the filter is broken.
		_skim_kind = TrashDef.Kind.WOOD
		for i in 4:
			_yard.put(_def_of(_skim_kind))
		# Wound right up, so the run finishes inside the harness's frame budget and the
		# sample of what it catches is big enough to mean something.
		_boat.skim_chance = 1.0
		_boat.skim_power = 4
		_boat.speed = TEST_FERRY_SPEED * 0.3
		_boat.skimmed.connect(_note_skimmed)
		_skimmed_kinds.clear()
		_pieces_before = _grid.piece_count()
		_filth_before = float(_main.get(&"pollution"))
		return
	if _boat.runs_done < 2 and _in_stage < 900:
		return
	_boat.skimmed.disconnect(_note_skimmed)
	_check(_boat.runs_done == 2, "the ferry ran again", "after %d frames" % _in_stage)
	_check(_grid.piece_count() < _pieces_before,
		"the skimmer cleared water on the way past",
		"%d -> %d pieces" % [_pieces_before, _grid.piece_count()])
	_check(not _skimmed_kinds.is_empty(), "it brought something up",
		"%d pieces" % _skimmed_kinds.size())

	var wrong := 0
	for kind: int in _skimmed_kinds:
		if kind != _skim_kind:
			wrong += 1
	_check(wrong == 0, "it only fished for what it was delivering",
		"%d of %d were not %s" % [
			wrong, _skimmed_kinds.size(), TrashDef.KIND_NAMES[_skim_kind]
		])
	_check(float(_main.get(&"pollution")) < _filth_before,
		"skimmed rubbish counts as out of the lake",
		"%.5f -> %.5f" % [_filth_before, float(_main.get(&"pollution"))])
	_advance()


## The fleet: a second hull is a second boat in the water, wired up the same as the first
## and moored somewhere else.
func _stage_fleet() -> void:
	var net_price := float(_main.call(&"cost_of", &"net_width"))
	_main.set(&"sludge", 100000.0)
	var before := _main.get(&"_boats").size() as int
	var price := float(_main.call(&"cost_of", &"fleet"))
	_check(price > net_price * 4.0, "an extra hull is the expensive one",
		"%.0f" % price)
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
	_check(second.rng_seed != _boat.rng_seed, "each hull rolls its own skimmer",
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
	_main.call(&"_buy", &"sell_3")
	var sell_was: int = (_main.get(&"sell_levels") as PackedInt32Array)[3]
	var pieces := _grid.piece_count()
	var sludge_was := float(_main.get(&"sludge"))
	var width_was := int(_main.get(&"net_width_level"))
	var yard_was := _yard.held.size()
	var hulls_was := (_main.get(&"_boats") as Array).size()

	_check(bool(_main.call(&"save_game")), "the run writes itself out", "")
	_check(bool(_main.call(&"has_save")), "there is a save on disk", "")

	# Spend and catch after saving, so a load that did nothing would be caught.
	_main.set(&"sludge", 0.0)
	_main.set(&"net_width_level", 0)
	_main.set(&"sell_levels", PackedInt32Array([0, 0, 0, 0, 0]))
	_yard.held.resize(0)
	_grid.take(_deep_tile(), 0)

	_check(bool(_main.call(&"load_game")), "and reads itself back", "")
	_check(is_equal_approx(float(_main.get(&"sludge")), sludge_was), "the purse came back",
		"%.0f" % float(_main.get(&"sludge")))
	_check(int(_main.get(&"net_width_level")) == width_was, "the upgrades came back",
		"net width %d" % int(_main.get(&"net_width_level")))
	_check((_main.get(&"sell_levels") as PackedInt32Array)[3] == sell_was and sell_was > 0,
		"and the market's tracks with them",
		"heavy pieces %d" % (_main.get(&"sell_levels") as PackedInt32Array)[3])
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
	for key in ["sell_0", "sell_1", "sell_2", "sell_3", "sell_4",
			"recycle_bonus", "bird_worth", "lucky_haul", "double_cast"]:
		if not tracks.has(StringName(key)):
			missing.append(key)
	_check(missing.is_empty(), "every market and luck track loads", ", ".join(missing))
	var boards := {}
	for row: Dictionary in _main.call(&"_shop_rows") as Array:
		boards[row["board"]] = int(boards.get(row["board"], 0)) + 1
	_check(int(boards.get(&"market", 0)) == 7, "the market board has seven rows",
		"%d" % int(boards.get(&"market", 0)))
	_check(int(boards.get(&"net", 0)) == 7, "and the net's board has seven",
		"%d" % int(boards.get(&"net", 0)))

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
		if not String(row.get("level", "")).begins_with("Lvl "):
			no_level.append(String(row["key"]))
		if String(row["cost"]) != "Max" and not value.ends_with(" next)"):
			no_next.append("%s: %s" % [row["key"], value])
	_check(decimals.is_empty(), "no row's value carries a decimal", ", ".join(decimals))
	_check(no_next.is_empty(), "every unmaxed row says what the next level buys", ", ".join(no_next))
	_check(no_blurb.is_empty(), "every row has a blurb for its ?", ", ".join(no_blurb))
	_check(no_level.is_empty(), "every row has its level as its own field", ", ".join(no_level))
	var width_row := ""
	for row: Dictionary in _main.call(&"_shop_rows") as Array:
		if row["key"] == &"net_width":
			width_row = String(row["value"])
	_check(width_row.begins_with("+0%"), "a scaling track at level 0 reads as +0%", width_row)
	var legend: Dictionary = _main.call(&"_shop_legend")
	_check((legend.get("tiers", []) as Array).size() == 5 and (legend.get("yards", []) as Array).size() == 4,
		"the legend lists five tiers and four yards", str(legend))
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
	var row_box := Rect2(100.0, 100.0, 300.0, 50.0)
	var help: Rect2 = skin.call(&"help_box_of", row_box)
	_check(help.position.x < row_box.position.x + 8.0 and help.position.y < row_box.position.y + 8.0
		and help.end.x > row_box.position.x and help.end.y > row_box.position.y and help.size.x <= 20.0,
		"the ? hangs over a row's top left corner", str(help))
	var priced := true
	for pair: Array in legend.get("yards", []):
		priced = priced and String(pair[1]).begins_with("$") and not "." in String(pair[1])
	_check(priced, "each material in the legend carries a whole-dollar average", str(legend.get("yards", [])))
	var folded: Array = skin.call(&"_wrap", "one two three four five six seven eight nine ten", 13, 60.0)
	_check(folded.size() > 1, "a blurb wraps onto lines", str(folded))

	_main.set(&"sludge", 100000.0)
	var plain_2 := float(_main.call(&"tier_pay", 2))
	var plain_3 := float(_main.call(&"tier_pay", 3))
	_check(is_equal_approx(plain_2, 1.0), "pieces sell at par to begin with", "%.2f" % plain_2)
	_main.call(&"_buy", &"sell_2")
	_check(float(_main.call(&"tier_pay", 2)) > plain_2, "a tier's track raises its pay",
		"%.2f" % float(_main.call(&"tier_pay", 2)))
	_check(is_equal_approx(float(_main.call(&"tier_pay", 3)), plain_3),
		"and no other tier's", "%.2f" % float(_main.call(&"tier_pay", 3)))

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
	# The shop the player sees is the drawn board, not the panel of buttons behind it: the
	# panel is kept in the tree for its numbers and is deliberately never shown.
	var shop := _main.get_node(^"HUD/ShopSkin") as Control
	_check(not settings.visible, "the settings panel starts closed", "")
	var shop_panel := _main.get_node(^"HUD/Shop") as Control
	# The settings are a drawn board (SettingsSkin) now, not a panel of buttons, and saving
	# is automatic: no save or load signal off it, and no SaveNow button anywhere in the
	# shop. The quit is the one button that writes a save on purpose.
	_check(not settings.has_signal(&"save_pressed") and not settings.has_signal(&"load_pressed")
		and settings.has_signal(&"quit_pressed")
		and shop_panel.find_child("SaveNow", true, false) == null,
		"saving is automatic: no save or load button anywhere", "")

	_press_escape()
	_check(settings.visible, "escape opens the settings", "")
	_check(not _angler.can_walk, "the angler stays put while it is open", "")
	_press_escape()
	_check(not settings.visible, "escape closes it again", "")
	_check(_angler.can_walk, "and the angler is free again", "")

	# The shed and the settings are one screen or the other, never both.
	_main.call(&"_set_settings", true)
	_main.call(&"_set_menu", true)
	_check(shop.visible and not settings.visible,
		"opening the shed puts the settings away", "")
	_press_escape()
	_check(not shop.visible and not settings.visible,
		"escape backs out of the shed first", "")
	var mode := DisplayServer.window_get_mode()
	var really_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN 		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	_check(bool(_main.call(&"_is_fullscreen")) == really_full,
		"the fullscreen box reads the real window", "")

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
	_advance()


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

	# Where they lie: the pet bed afloat in the first band past the shelf, the rest spread
	# FIND_APART from each other (the darts' fallback may put a late one closer).
	var first_tile := -1
	var lie: Array[Vector2] = []
	for index in _grid.stacks.size():
		var stack: PackedInt32Array = _grid.stacks[index]
		for k in stack.size():
			var def: TrashDef = _grid.defs[stack[k]]
			if not def.keepsake:
				continue
			if def.piece == Lake.FIRST_FIND:
				first_tile = index
				_check(k == stack.size() - 1, "the pet bed is on top of its stack",
					"slot %d of %d" % [k, stack.size()])
			else:
				lie.append(Vector2(_grid.tile_of(index)))
	_check(first_tile >= 0, "the pet bed is in the lake", "")
	if first_tile >= 0:
		var out := Iso.past_shelf(Vector2(_grid.tile_of(first_tile)))
		var near := Iso.SHELF_TILES + Iso.SHELF_CLEAR
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

	# Proportion: a bed is bigger than a mug in the lake too, not normalised to it.
	var smallest := 1e9
	var largest := 0.0
	var biggest_art := 0.0
	var biggest_drawn := 0.0
	for def: TrashDef in _grid.defs:
		var longest := maxf(def.size.x, def.size.y)
		smallest = minf(smallest, longest)
		largest = maxf(largest, longest)
		var art := maxf(def.region.size.x, def.region.size.y)
		if art > biggest_art:
			biggest_art = art
			biggest_drawn = longest
	_check(largest > smallest * 2.0, "the big things are drawn bigger than the small ones",
		"%.0f px against %.0f px" % [largest, smallest])
	_check(is_equal_approx(biggest_drawn, largest),
		"and the biggest picture is the biggest thing on the water", "")

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
		# And it is in the same place: the near corner of those walls, straight off the
		# picture, against the line the walking rule stops at.
		var stands := Iso.shed_centre()
		var drawn := Iso.tile_to_world(stands.x, stands.y).y 			+ (float(deep + 1) - float(hut.get_height()) * (1.0 - Iso.SHED_ART_GROUND)) * scale
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
	# them on offer to the skimmer.
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
		# Dig straight to it with a net strong enough for anything, then ask again as the
		# boat does. The boat must come away with nothing.
		var depth := _grid.stacks[keepsake_tile].size()
		_check(_grid.reachable_slot(keepsake_tile, depth, 9) >= 0,
			"the net can reach a find", "")
		var to_boat := _grid.reachable_slot(keepsake_tile, depth, 9, -1, false)
		var boat_got_one := false
		if to_boat >= 0:
			boat_got_one = _grid.defs[_grid.stacks[keepsake_tile][to_boat]].keepsake
		_check(not boat_got_one, "the skimmer leaves the finds alone", "")
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
	var unlocked: Array = _main.get(&"unlocked")
	unlocked.clear()
	_yard.held.resize(0)
	_main.call(&"_on_net_landed", PackedInt32Array([find_index, find_index]))
	_check(unlocked.size() == 1 and String(unlocked[0]) == String(find.piece),
		"a find is kept, once, however many turn up",
		"%d kept" % unlocked.size())
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
		for attempt in wanted + 1:
			_main.call(&"_on_net_landed", PackedInt32Array([many_index]))
		var held := 0
		for kept: String in unlocked:
			if kept == many:
				held += 1
		_check(held == wanted, "a find that comes in fours is kept four times and no more",
			"%s: %d kept of %d" % [many, held, wanted])

		# And the shelf counts them rather than matching by name: standing one chair down
		# must not take the other three off the list with it.
		var many_decor: Array = _main.get(&"decor")
		many_decor.clear()
		room.unlocked = unlocked as Array[String]
		room.decor = many_decor
		var before := room.in_store().size()
		room.place(StringName(many), Vector2i(1, 1))
		_check(room.in_store().size() == before - 1,
			"and standing one of them down leaves the rest on the shelf",
			"%d listed, %d after one was placed" % [before, room.in_store().size()])
		many_decor.clear()
		unlocked.clear()
		_main.call(&"_on_net_landed", PackedInt32Array([find_index]))

	# The room.
	var decor: Array = _main.get(&"decor")
	decor.clear()
	room.unlocked = unlocked as Array[String]
	room.decor = decor
	var piece := StringName(find.piece)
	var span := room.span_of(piece)
	_check(room.in_store().size() == 1, "the find shows up in the inventory", "")
	_check(room.place(piece, Vector2i(1, 1)), "it can be put down on the floor", "")
	_check(room.in_store().is_empty(), "and leaves the inventory once it is out", "")
	_check(room.can_place(piece, Vector2i(1, 1)),
		"and something else may be stood on top of it — a chair belongs on a rug", "")
	_check(not room.can_place(piece, Vector2i(ShedRoom.COLS - span.x + 1, 1)),
		"and nothing can be stood off the edge of the floor", "")
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
			var art := sheets.view_region_of(StringName(name), view).size
			var cells := room.span_of(StringName(name), view)
			var off := maxf(
				absf(float(cells.x * ShedRoom.CELL) - art.x),
				absf(float(cells.y * ShedRoom.CELL) - art.y)
			)
			if off > worst:
				worst = off
				worst_name = "%s/%s" % [name, sheets.role_of(StringName(name), view)]
	_check(worst <= float(ShedRoom.CELL), "a footprint fits the thing standing in it",
		"%s is %.0f px out of %d" % [worst_name, worst, ShedRoom.CELL])

	# Every set is a set of something: a piece with more than one face has to say which
	# verb turns it, or the shed has art it cannot show. The authored table in
	# tools/decor_sets.json is where that is said, and this is the gate on it.
	var mute := ""
	for name: String in sheets.names:
		if sheets.view_count(StringName(name)) > 1 				and sheets.kind_of(StringName(name)) == Sheets.Set.SINGLE:
			mute = name
			break
	_check(mute.is_empty(), "every piece with more than one face says what turns it", mute)

	# And the two verbs are exclusive: R turns a chair and E works a switch, and a piece
	# that answered both would answer whichever was asked first.
	var both := ""
	for name: String in sheets.names:
		if sheets.turnable(StringName(name)) and sheets.switchable(StringName(name)):
			both = name
			break
	_check(both.is_empty(), "and nothing is both turned and switched", both)

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
		var press := InputEventKey.new()
		press.keycode = KEY_R
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
		room.place(StringName(rug), Vector2i(1, 1))
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
	_check(
		int((decor[0] as Dictionary)["cell"][0]) == 2
		and int((decor[0] as Dictionary)["cell"][1]) == 3,
		"and everything is where it was put", str((decor[0] as Dictionary)["cell"])
	)
	_check(not unlocked.has("no_such_piece"),
		"a find the catalogue no longer knows is dropped rather than kept", "")
	_advance()


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

	var rows: Array = _flock.get(&"_rows")
	_check(rows.size() > 0, "the chosen birds loaded", "%s" % str(rows))

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

	_flock.spawning = false
	_advance()


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
		# And now it really is empty, with the same float dust on the meter.
		var stack := _grid.stacks[_deep_tile()]
		stack.resize(0)
		_grid.stacks[_deep_tile()] = stack
		_main.set(&"_clean_check_in", 0.0)
		return
	if _in_stage < 80:
		return
	_check(_grid.piece_count() == 0, "the lake is empty", "")
	_check(bool(_main.get(&"_cleaned")),
		"an empty lake ends the run even with dust left on the meter", "")
	_check(is_zero_approx(float(_main.get(&"pollution"))),
		"and the meter is put to zero rather than left near it",
		"%.6f" % float(_main.get(&"pollution")))
	_check(_main.get_node_or_null(^"Farewell") != null,
		"the closing words are on screen", "")
	_check(not _angler.can_walk, "which holds the angler where they stand", "")
	_check(_main.call(&"_last_pieces_line") == "",
		"and the note about leftovers is gone", "")
	_advance()


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
	for step in 200:
		day.phase = float(step) / 200.0
		day.call(&"_settle")
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
		var over := _main.get_node_or_null(^"Farewell")
		if over != null:
			_main.call(&"_drop_farewell")
			over.free()
		_main.set(&"_farewell_shown", true)
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
	if _in_stage < 40:
		return
	_check(bool(_main.get(&"_cleaned")), "the ending catches up a frame later", "")
	_check(_main.get_node_or_null(^"Farewell") != null,
		"and the words the run was owed are on screen", "")
	# Said once already, and said again: the way off the lake is a door on this screen,
	# so a finished lake that showed its ending last week and refuses to show it again is a
	# lake with nothing to do on it and no way off it. The door is the menu's (2026-09-12);
	# the siege is set aside and the onward door with it.
	_check(bool(_main.get(&"_farewell_shown")),
		"a lake that was already finished offers its ending again", "")
	var farewell: Node = _main.get(&"_farewell")
	_check(farewell != null and farewell.has_signal(&"to_menu")
		and farewell.is_connected(&"to_menu", Callable(_main, &"_quit")),
		"and it carries the door back to the menu", "")
	_check(String(_main.call(&"_next_scene")) == "",
		"and no door on to a siege", "%s" % _main.call(&"_next_scene"))
	_advance()


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
	_finish()


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


func _note_skimmed(def_index: int) -> void:
	_skimmed_kinds.append(_grid.defs[def_index].material)


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
