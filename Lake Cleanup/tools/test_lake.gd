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
			_stage_save()
		13:
			_stage_settings()
		14:
			_stage_ferry_art()
		15:
			_stage_art()
		16:
			_stage_shed()
		17:
			_stage_pigeons()
		18:
			_stage_ending()
		19:
			_stage_ending_on_load()
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
	# the game and then checked against the basin, which is what the limit is really about.
	#
	# Not "the whole lake fits" any more. The view is deliberately held in past that (see
	# `Lake.ZOOM_OUT_PULL`): a zoom that fits the whole basin is a zoom at which a bottle is
	# three pixels. What has to hold is that pulling back still shows most of the lake and
	# stops there — the wheel can neither lose the lake nor turn it into a map.
	_main.call(&"_zoom_by", 0.0001)
	var fit: float = _main.call(&"_fit_zoom")
	var far: float = _main.call(&"_far_zoom")
	_check(is_equal_approx(cam.zoom.x, far), "zooming out stops at the far limit",
		"%.3f, far %.3f (fit %.3f)" % [cam.zoom.x, far, fit])
	# The far level is at or out past the fitted zoom, except on a window too small for any
	# level to fit, where it is level one — so "most of the lake" is scaled by how far level
	# one overshoots.
	var span := Iso.basin_extent() * cam.zoom.x
	var view := _main.get_viewport_rect().size
	var shown := minf(view.x / span.x, view.y / span.y)
	var wanted := 1.0 / Lake.ZOOM_OUT_PULL * minf(1.0, fit / cam.zoom.x)
	_check(shown >= wanted - 0.01,
		"and most of the lake is on screen there",
		"%.2f of it, wanted %.2f (lake %.0fx%.0f in %.0fx%.0f)" % [
			shown, wanted, span.x, span.y, view.x, view.y
		])
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

	# Every berth is on open water, or the ferry would sail into the bank to reach it.
	var all_afloat := true
	var spread := 0.0
	for i in stops.size():
		var berth: Vector2 = (stops[i] as Dropoff).berth
		if Iso.shore_fraction(berth.x, berth.y) >= 1.0:
			all_afloat = false
		for j in stops.size():
			spread = maxf(spread, berth.distance_to((stops[j] as Dropoff).berth))
	_check(all_afloat, "every berth is in the water", "")
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
	var east: Vector2 = (stops[TrashDef.Kind.TIMBER] as Dropoff).berth
	var west: Vector2 = (stops[TrashDef.Kind.RUBBER] as Dropoff).berth
	var across: Array[Vector2] = _boat.call(&"_plan_legs", east, west)
	_check(across.size() > 1, "a run across the lake bends round the island",
		"%d legs" % across.size())
	if not _path_misses_island(east, across):
		crossings += 1
	_check(crossings == 0, "no planned path runs over the island",
		"%d of them do" % crossings)
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
		_skim_kind = TrashDef.Kind.TIMBER
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
	_yard.held.resize(0)
	_grid.take(_deep_tile(), 0)

	_check(bool(_main.call(&"load_game")), "and reads itself back", "")
	_check(is_equal_approx(float(_main.get(&"sludge")), sludge_was), "the purse came back",
		"%.0f" % float(_main.get(&"sludge")))
	_check(int(_main.get(&"net_width_level")) == width_was, "the upgrades came back",
		"net width %d" % int(_main.get(&"net_width_level")))
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
func _stage_art() -> void:
	var sheets: Sheets = _main.get(&"_sheets")
	_check(sheets != null and sheets.atlas != null, "the sheets were cut and welded",
		"%d pieces" % (sheets.regions.size() if sheets != null else 0))
	if sheets == null:
		_advance()
		return

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

	# Every visible piece is one quad and nothing else: the pale plate that used to be
	# drawn under each one read as a grey square behind every object in the lake.
	var verts: PackedVector2Array = _grid.get(&"_mesh_points")
	_check(verts.size() == _grid.drawn_pieces * 4,
		"a piece of rubbish is its picture and nothing else",
		"%d corners for %d pieces" % [verts.size(), _grid.drawn_pieces])

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
	# Said once already, and said again: the way on to the second lake is a door on this
	# screen, so a finished lake that showed its ending last week and refuses to show it
	# again is a lake with nothing to do on it and no way off it.
	_check(bool(_main.get(&"_farewell_shown")),
		"a lake that was already finished offers its ending again", "")
	_check(String(_main.call(&"_next_scene")) != "",
		"and it carries the door on to the next lake",
		"%s" % _main.call(&"_next_scene"))
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
