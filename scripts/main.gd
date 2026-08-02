## Wires the game together. Systems talk through here rather than reaching across
## the tree for each other.
extends Node2D

## How long the wreckage stays on screen before the bridge is put back.
const REPLAY_LINGER := 1.5

@onready var _world: Node2D = $World
@onready var _spawner: Node = $Construction/ObjectSpawner
@onready var _manipulator: Node2D = $Construction/ObjectManipulator
@onready var _crossing: CrossingManager = $Crossing
@onready var _economy: Economy = $Economy
@onready var _inventory: Inventory = $Inventory
@onready var _shop: Shop = $Shop
@onready var _levels: LevelManager = $Levels
@onready var _camera: Camera2D = $World/Camera
@onready var _hud: CanvasLayer = $HUD

## The player's saved layouts. Made here rather than placed in main.tscn because
## it holds nothing but data and has no scene presence to configure.
var _blueprints := Blueprints.new()

## The bridge as it stood when the current attempt began.
var _pre_crossing_layout: Array[Dictionary] = []
## True from the moment a car spawns until the bridge has been put back.
##
## The manipulator is locked for exactly this window, so building and attempting
## can never overlap. Mirrored through the setter rather than at each of the four
## places this flips, because a path that cleared the flag and forgot the lock
## would leave the strait permanently untouchable.
var _attempt_active: bool = false:
	set(value):
		_attempt_active = value
		if _manipulator != null:
			_manipulator.locked = value
		if _hud != null:
			_hud.build_locked = value
## Set by the headless checks, which must not write over a real save.
var _testing: bool = false


func _ready() -> void:
	_blueprints.name = "Blueprints"
	add_child(_blueprints)

	_shop.setup(_economy, _inventory)
	_levels.setup(_world, _shop, _economy, _inventory, _spawner, _crossing)
	_hud.build(_spawner, _crossing, _economy, _inventory, _shop, _levels, _blueprints)

	_hud.save_blueprint_requested.connect(_on_save_blueprint)
	_hud.load_blueprint_requested.connect(_on_load_blueprint)

	_hud.buy_requested.connect(_shop.buy)
	_hud.box_requested.connect(_shop.buy_box)
	_hud.place_requested.connect(_on_place_requested)
	_hud.recall_car_requested.connect(_on_recall_car_requested)
	_hud.start_crossing_requested.connect(_on_start_crossing_requested)
	_hud.next_level_requested.connect(_levels.advance)

	_manipulator.water = $World/Water
	_manipulator.delete_requested.connect(_spawner.remove)
	_manipulator.release_blocked.connect(_hud.report_blocked)
	_spawner.object_removed.connect(_inventory.add.bind(1))
	_crossing.attempt_started.connect(_on_crossing_started)
	_crossing.attempt_finished.connect(_on_crossing_finished)
	_levels.campaign_finished.connect(_hud.report_campaign_finished)
	_levels.level_loaded.connect(_on_level_loaded)

	var args := OS.get_cmdline_user_args()
	_testing = args.has("--smoke") or args.has("--carcheck")

	_load_or_start()

	# Connected only after the restore, so the level load inside _load_or_start()
	# can't autosave its blank slate over the file it's about to read.
	if not _testing:
		_shop.stock_changed.connect(request_save)
		_blueprints.changed.connect(request_save)
		_levels.level_loaded.connect(func(_lv: LevelDef, _i: int) -> void: save_now())
		_manipulator.released.connect(func(_obj: BridgeObject) -> void: request_save())
		_spawner.object_removed.connect(func(_def: ObjectDef) -> void: request_save())

	if args.has("--smoke"):
		_run_smoke_test()
	elif args.has("--carcheck"):
		_run_car_check()


## Resume where the player left off, or start a fresh run if there's no save.
##
## The level must be loaded first: that builds the world, refills the shop and
## empties the strait, all of which the save then overwrites with what was
## actually left. Doing it the other way round would wipe the restored state.
func _load_or_start() -> void:
	var data := {} if _testing else SaveGame.load_data()
	if data.is_empty():
		_levels.load_level(0)
		# No save means this is somebody's first turn, so teach it. Tied to the
		# absence of a save rather than to a "seen it" flag on purpose: the flag
		# would have to live outside the save to be worth anything, and then
		# starting a new game a month later would drop you in cold.
		#
		# Not during the headless checks, which have no way to dismiss it and
		# would sit behind the overlay pressing buttons that never get the click.
		if not _testing:
			_hud.start_tutorial()
		return
	_levels.load_level(int(data.get("level", 0)))
	SaveGame.apply(data, _levels, _economy, _inventory, _shop, _spawner, _blueprints)


## Ask for a save soon rather than right now.
##
## A save walks every placed piece, stringifies the lot and writes it to disk, and
## it was wired to fire on every single drop and every recall. Building a bridge
## is dozens of those in a row, each one a synchronous write on the main thread —
## which is precisely the hitch you feel while placing pieces, and it grows with
## the size of the bridge, so it gets worse exactly as the level gets busier.
##
## Coalescing them costs nothing that matters: the flush lands well inside a
## second, and every path that could actually lose progress — a level change, a
## finished attempt, quitting — still calls save_now() directly. The worst case is
## a crash in the half-second after a drop, which loses one plank's position.
const SAVE_DELAY := 0.5

var _save_due: float = -1.0


func request_save() -> void:
	if _testing:
		return
	_save_due = SAVE_DELAY


func _process(delta: float) -> void:
	if _save_due < 0.0:
		return
	_save_due -= delta
	if _save_due <= 0.0:
		_save_due = -1.0
		save_now()


## Saving is automatic and silent. It happens after anything that would hurt to
## repeat — a purchase, a level change, a banked attempt — and on the way out,
## rather than on a timer, so the file is never a few seconds stale.
func save_now() -> void:
	# Whatever prompted the pending save is included in this one.
	_save_due = -1.0
	# The one place this check belongs, and it was missing from it.
	#
	# It used to be at every *caller* instead — request_save(), _exit_tree(), the
	# crossing settle — which held right up until _notification() called this
	# directly on the window's close button. A test run then wrote the state it had
	# driven the game into over a real player's save, and there is no undo for that.
	# A guard on the callers is a guard you can forget to add; a guard here cannot
	# be routed around, and every path that writes the file goes through here.
	if _testing:
		return
	# Mid-attempt the strait is full of wreckage the player never built. The
	# layout worth keeping is the one they pressed START with.
	var bridge: Array[Dictionary] = (
		_pre_crossing_layout if _attempt_active else _spawner.snapshot()
	)
	SaveGame.save(
		SaveGame.capture(_levels, _economy, _inventory, _shop, bridge, _blueprints)
	)


## Covers the window's close button and Alt-F4. _exit_tree() catches the rest,
## including a quit from the pause menu and the editor's stop button.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_now()


func _exit_tree() -> void:
	# The headless checks deliberately drive the game into odd states, and must
	# not leave a save behind that a later run would resume from.
	if _testing:
		return
	save_now()


## Drives the car along an empty shore with no bridge at all, reporting where it
## gets to. The baseline for every other number in the game: if the car can't
## reach the water under its own power, no score is meaningful.
## Run with:  godot --headless --quit-after 1200 -- --carcheck
func _run_car_check() -> void:
	_crossing.start_crossing()
	for i in 12:
		await get_tree().create_timer(0.5).timeout
		if not is_instance_valid(_crossing.car):
			break
		var p := _crossing.car.chassis.global_position
		print("t=%.1f  x=%.0f  y=%.0f  progress=%.2f  running=%s" % [
			(i + 1) * 0.5, p.x, p.y, _crossing.progress, _crossing.is_running
		])


## The prototype has no menus, so fullscreen needs a keyboard escape hatch or you
## can't get at the editor. F11 toggles, Escape drops to a window.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.is_echo()):
		return
	var key := (event as InputEventKey).keycode
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	if UITheme.is_fullscreen_key(key):
		UITheme.toggle_fullscreen()
		get_viewport().set_input_as_handled()
	elif key == KEY_F3:
		_hud.toggle_meter()
		get_viewport().set_input_as_handled()
	elif key == KEY_ESCAPE and full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		get_viewport().set_input_as_handled()


## Placing costs an item from stock, not money — the money was spent buying it.
## The piece arrives at the cursor already held, so it never lands on a pile:
## every object enters the world through the same ghost-placement flow.
func _on_place_requested(def: ObjectDef) -> void:
	# Not while the car is on the strait. A piece placed mid-attempt drops into a
	# bridge that is already being driven over and is the one input that can turn
	# a run into nonsense — and worse, it is not in _pre_crossing_layout, so the
	# restore afterwards would quietly delete it. The belt is dimmed to match, so
	# this branch is a backstop rather than the thing the player runs into.
	# _attempt_active rather than is_running: the window that has to be closed runs
	# past the finish, through the linger while the wreck is on screen, until the
	# bridge has actually been put back. A piece placed in there isn't in
	# _pre_crossing_layout and the restore would quietly delete it.
	if _attempt_active or _crossing.is_running:
		return
	if _spawner.is_full():
		return
	if not _inventory.take(def):
		return
	# Spawn into the middle of what the player is looking at, not under the cursor
	# — the cursor is on the shop button they just clicked. The piece hovers there
	# until they move the mouse into the world, then it comes to hand.
	var park := _camera.get_screen_center_position() + Vector2(0, -160)
	var obj: BridgeObject = _spawner.spawn(def, park)
	_manipulator.grab_object(obj, true)


## A level change cancels any pending restore. Without this, changing level during
## the post-attempt linger would rebuild the old level's bridge in the new strait.
func _on_level_loaded(_level: LevelDef, _index: int) -> void:
	var audio := get_node_or_null(^"/root/Audio")
	if audio != null:
		audio.set_level_music(_index)
	_attempt_active = false
	_pre_crossing_layout.clear()
	_camera.stop_following()
	# Saved layouts don't survive a level change. A span shaped for one strait is
	# meaningless in a wider one, and the pieces it was built from went back to the
	# shop along with the rest of the level's inventory — so every slot would load
	# as an empty strait. Cleared here rather than filtered at the point of use, so
	# the panel never shows three rows that can't be pressed.
	_blueprints.clear_all()


## Every attempt starts from the bridge the player built, never from the state
## the last one left behind.
##
## The window that matters is the REPLAY_LINGER after a crossing ends, while the
## wreckage is still on screen and the restore has not fired yet. START is live
## again by then, and pressing it used to run the new attempt over the rubble —
## and, far worse, _on_crossing_started would snapshot that rubble as the layout
## to restore, so the bridge the player actually built was gone for good.
##
## Undoing first makes a second press mean "try that again", which is the only
## thing it can sensibly mean.
func _on_start_crossing_requested() -> void:
	# Checked before anything is stashed or reset, so a refused start leaves the
	# strait exactly as the player left it.
	if not _bridge_in_water():
		_hud.report_no_bridge()
		return
	# Before the snapshot, not after: a piece still in hand is parented alongside
	# the placed ones, so leaving it there would snapshot a piece the player never
	# put down and hand it back as part of the bridge.
	_manipulator.stash_held()
	if _attempt_active:
		_crossing.reset()
		_camera.stop_following()
		_spawner.restore(_pre_crossing_layout)
		_attempt_active = false
	_crossing.start_crossing()


## Is there at least one piece actually down in the strait?
##
## The gate on starting a crossing. Driving off the end of an empty shore is not
## an attempt — nothing was built, so nothing is being tested — and it used to be
## the single easiest thing to do by accident, because START is the biggest and
## brightest control in the dock and it worked on an empty strait.
##
## A piece still in hand doesn't count: it hasn't been put anywhere yet, and
## pressing START would stash it back to stock a frame later.
func _bridge_in_water() -> bool:
	var water := _manipulator.water as WaterBody
	for node: Node in get_tree().get_nodes_in_group(&"bridge_objects"):
		var obj := node as BridgeObject
		if obj == null or obj.is_queued_for_deletion() or obj == _manipulator.held:
			continue
		if water == null or water.touches(obj):
			return true
	return false


## Taking the car off is an abort, not a result: it undoes the attempt entirely,
## bridge included, so the player gets back the span they pressed START with.
## Clearing _attempt_active also cancels the linger restore if one is pending.
func _on_recall_car_requested() -> void:
	_crossing.reset()
	_camera.stop_following()
	if _attempt_active:
		_spawner.restore(_pre_crossing_layout)
		_attempt_active = false


## Copy the bridge as it stands into a slot.
##
## Mid-attempt it stores the layout the player pressed START with, for the same
## reason the autosave does: the pieces on screen are halfway through being
## knocked apart and nobody wants that back.
func _on_save_blueprint(index: int) -> void:
	var bridge: Array[Dictionary] = (
		_pre_crossing_layout if _attempt_active else _spawner.snapshot()
	)
	_blueprints.store(index, _levels.index, bridge)
	_hud.report_blueprint_saved(index, bridge.size())


## Put a saved layout back in the water.
##
## Every piece in the strait is recalled to stock first, then the layout is
## rebuilt out of that stock. That ordering is what makes the operation safe:
## nothing is created and nothing is destroyed, the pieces just move. If the
## player has since spent pieces elsewhere — sold nothing, but a level's stock is
## fixed — anything that can't be paid for is simply left out, and the count in
## the banner says how much of the layout came back.
func _on_load_blueprint(index: int) -> void:
	if _attempt_active or _crossing.is_running:
		return
	var data := _blueprints.slot(index)
	if data.is_empty() or int(data.get("level", -1)) != _levels.index:
		return

	# A piece in hand would otherwise be left hovering over a bridge it isn't part
	# of, and would be dropped into the middle of the restored span.
	_manipulator.stash_held()
	# Refunds every placed piece, so the stock below is the full pool.
	_spawner.clear_all()

	var layout: Array[Dictionary] = []
	for entry: Dictionary in (data["bridge"] as Array):
		if _inventory.take(entry[&"def"] as ObjectDef):
			layout.append(entry)
	_spawner.restore(layout)

	var wanted: int = (data["bridge"] as Array).size()
	_hud.report_blueprint_loaded(index, layout.size(), wanted)
	if not _testing:
		save_now()


func _on_crossing_started() -> void:
	_pre_crossing_layout = _spawner.snapshot()
	_attempt_active = true
	_camera.follow(_crossing.car.chassis)


## An attempt is a test, not a commitment: whatever the car knocked apart gets put
## back so the player can adjust one plank instead of rebuilding the span.
func _on_crossing_finished(result: CrossingManager.Result, progress: float) -> void:
	var succeeded := result == CrossingManager.Result.SUCCESS
	var first_clear := succeeded and _levels.mark_cleared()
	var settled := _economy.settle_attempt(succeeded, progress, first_clear)
	_hud.report_crossing(result, progress, settled[0], settled[1])
	if succeeded and not _levels.is_last():
		_hud.offer_next_level()
	elif succeeded:
		_hud.report_campaign_finished()
	if not _testing:
		save_now()

	await get_tree().create_timer(REPLAY_LINGER).timeout
	# Another attempt — or a level change — may have happened during the linger.
	if _crossing.is_running or not _attempt_active:
		return
	_crossing.reset()
	_camera.stop_following()
	_spawner.restore(_pre_crossing_layout)
	_attempt_active = false


## Headless sanity check: buy out a level's shop, gamble on a box, place the lot,
## let it settle, and drive off the end of the unfinished bridge. Catches the
## physics or the wiring blowing up without needing a human at the window.
## Run with:  godot --headless --quit-after 6000 -- --smoke
func _run_smoke_test() -> void:
	_economy.add(2000)
	var level := _levels.level

	# An empty strait must refuse to start. Checked first, while it is genuinely
	# empty, because everything below fills it.
	assert(not _bridge_in_water(), "empty strait reported a bridge")
	_on_start_crossing_requested()
	assert(not _crossing.is_running, "START ran with nothing in the water")

	for def: ObjectDef in level.shop_pool:
		while _shop.remaining(def) > 0 and _economy.can_afford(def.price):
			assert(_shop.buy(def), "shop refused an affordable, in-stock piece")
	assert(not _shop.buy(level.shop_pool[0]), "shop sold past its stock limit")

	for box: BoxDef in level.boxes:
		assert(_shop.buy_box(box), "box purchase failed with money in hand")
	print("bought stock=%d money=%d" % [_inventory.total(), _economy.money])

	# Headless has no cursor, so placing everything through the normal flow would
	# stack the lot on the origin and explode. Spread them along the strait
	# instead — the grab/release path is still what's under test.
	const COLUMNS := 10
	const ROWS := 2
	var area: Rect2 = _world.build_area()
	var step := (area.size.x - 400.0) / float(COLUMNS)
	var lane := 0
	for def: ObjectDef in _placeable_defs(level):
		for i in _inventory.count(def):
			if lane >= COLUMNS * ROWS:
				break
			_on_place_requested(def)
			if _manipulator.held == null:
				continue
			_manipulator.held.position = Vector2(
				area.position.x + 200.0 + (lane % COLUMNS) * step,
				-200.0 - floorf(lane / float(COLUMNS)) * 300.0
			)
			_manipulator.release(true)
			lane += 1
	print("placed=%d stock_after=%d" % [_spawner.count(), _inventory.total()])

	await get_tree().create_timer(4.0).timeout
	for obj: BridgeObject in get_tree().get_nodes_in_group(&"bridge_objects"):
		var p := obj.global_position
		assert(is_finite(p.x) and is_finite(p.y), "non-finite position")

	assert(_bridge_in_water(), "a strait full of pieces reported no bridge")

	# Right-clicking a piece takes exactly that piece back, without picking it up.
	var pieces: Array = get_tree().get_nodes_in_group(&"bridge_objects")
	var target := pieces[0] as BridgeObject
	var before_count: int = _spawner.count()
	var before_stock: int = _inventory.count(target.def)
	assert(
		_manipulator.call(&"_recall_at", target.global_position),
		"right-click found no piece where one is"
	)
	assert(_spawner.count() == before_count - 1, "right-click recall took the wrong number")
	assert(
		_inventory.count(target.def) == before_stock + 1,
		"right-click recall didn't refund the piece"
	)
	assert(_manipulator.held == null, "right-click recall picked the piece up")

	var placed_before: int = _spawner.count()
	_crossing.start_crossing()
	var outcome: Array = await _crossing.attempt_finished
	print("crossing result=%d progress=%.2f money=%d best=%d" % [
		outcome[0], outcome[1], _economy.money, _economy.best_score
	])

	# The bridge must survive the attempt: same pieces, no refunds, no charges.
	var stock_before: int = _inventory.total()
	await get_tree().create_timer(REPLAY_LINGER + 0.5).timeout
	print("restored placed=%d/%d stock=%d/%d" % [
		_spawner.count(), placed_before, _inventory.total(), stock_before
	])
	assert(_spawner.count() == placed_before, "bridge not restored after crossing")
	assert(_inventory.total() == stock_before, "restore leaked pieces into stock")

	# Recalling one material must take exactly that material and refund exactly it.
	# Run here, on the restored bridge, because it is about to be cleared anyway.
	var by_def: Dictionary[ObjectDef, int] = _spawner.placed_counts()
	assert(not by_def.is_empty(), "nothing placed to recall by type")
	var one_kind: ObjectDef = by_def.keys()[0]
	var kind_placed: int = by_def[one_kind]
	var kind_stock: int = _inventory.count(one_kind)
	var total_placed: int = _spawner.count()
	var recalled: int = _spawner.remove_all_of(one_kind)
	print("recalled type=%s n=%d" % [one_kind.display_name, recalled])
	assert(recalled == kind_placed, "recall-by-type took the wrong number")
	assert(
		_inventory.count(one_kind) == kind_stock + kind_placed,
		"recall-by-type didn't refund what it took"
	)
	assert(
		_spawner.placed_counts().get(one_kind, 0) == 0,
		"recall-by-type left some of its own kind behind"
	)
	assert(
		_spawner.count() == total_placed - kind_placed,
		"recall-by-type took pieces of another kind"
	)

	# A saved layout must survive a round trip through a wiped strait: same pieces
	# back in the same places, and nothing conjured or lost on the way.
	var saved_placed: int = _spawner.count()
	var saved_stock: int = _inventory.total()
	_on_save_blueprint(0)
	assert(_blueprints.piece_count(0) == saved_placed, "blueprint stored the wrong count")
	_spawner.clear_all()
	assert(_spawner.count() == 0, "clear_all left pieces behind")
	_on_load_blueprint(0)
	print("blueprint reloaded placed=%d/%d stock=%d/%d" % [
		_spawner.count(), saved_placed, _inventory.total(), saved_stock
	])
	assert(_spawner.count() == saved_placed, "blueprint didn't restore every piece")
	assert(_inventory.total() == saved_stock, "blueprint load leaked or ate stock")

	# And through the file, which is the whole point of a slot outliving a session.
	var round_trip := Blueprints.new()
	round_trip.from_json(_blueprints.to_json())
	assert(
		round_trip.piece_count(0) == saved_placed,
		"blueprint didn't survive the save/load round trip"
	)
	round_trip.free()

	# The panel is built in code from live state, so opening it is the only way to
	# find out that it builds. Reached by name because it is the HUD's own business
	# how it is opened, and this check has no cursor to press the dock button with.
	_hud.call(&"_open_blueprints")
	_hud.call(&"_refresh_blueprints")
	_hud.call(&"_close_blueprints")
	print("blueprint panel opened and closed")

	# The shop nudge must actually appear: there is money in hand and boxes on
	# sale, so a silent no-show would mean it never fires for a real player either.
	assert(_hud.nudge_visible(), "shop nudge never appeared with money for a box")

	_spawner.clear_all()
	print("recalled stock=%d" % _inventory.total())

	# Levels must be able to widen without the geometry or the shop going stale.
	_levels.load_level(1)
	print("level=%s placed=%d stock=%d shop_plank=%d" % [
		_levels.level.display_name, _spawner.count(), _inventory.total(),
		_shop.remaining(_levels.level.shop_pool[0])
	])
	assert(_spawner.count() == 0, "level load left pieces in the strait")
	assert(_inventory.total() == 0, "level load carried inventory over")
	assert(_economy.best_score == 0, "level load kept the old best score")

	# Every level must build, and its course must sit inside its own world.
	for i in _levels.levels.size():
		_levels.load_level(i)
		var box: Rect2 = _world.escape_bounds()
		var start: Vector2 = _levels.level.car_start()
		print("%s  half_width=%.0f  start=%.0f  goal=%.0f" % [
			_levels.level.display_name, _levels.level.half_width,
			start.x, _levels.level.goal_x()
		])
		assert(_world.build_area().size.x > 0.0, "level built an empty build area")
		assert(box.has_point(Vector2(_levels.level.goal_x(), 300.0)), "goal outside world")


func _placeable_defs(level: LevelDef) -> Array[ObjectDef]:
	var out: Array[ObjectDef] = []
	for def: ObjectDef in level.shop_pool:
		if not out.has(def):
			out.append(def)
	for box: BoxDef in level.boxes:
		for def: ObjectDef in box.pool:
			if not out.has(def):
				out.append(def)
	return out
