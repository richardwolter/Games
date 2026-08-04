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

## Films every attempt, and plays the last one back. Both made here for the same
## reason Blueprints is: neither has anything in the scene to configure.
##
## The recorder is a child of Main so it gets a physics tick of its own. It runs
## after the bodies it samples — node order in the tree decides that, and Main's
## children are processed after the world's — so each sample is the state at the
## end of the tick rather than halfway through it.
var _recorder := AttemptRecorder.new()
var _replay := ReplayPlayer.new()
## True while a replay is being filmed to a video file, so the end of playback
## knows whether there is a download to trigger.
var _replay_recording: bool = false

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
## Level index to open in the dev sandbox, or -1 for a normal run. See _ready().
var _sandbox_level: int = -1
var _sandbox_money: int = 5000


func _ready() -> void:
	_blueprints.name = "Blueprints"
	add_child(_blueprints)
	_recorder.name = "AttemptRecorder"
	add_child(_recorder)
	# Added to the world rather than to Main, so the puppets sit in the same space
	# as the terrain and the water they are being replayed over.
	_replay.name = "ReplayPlayer"
	_replay.water = $World/Water
	_world.add_child(_replay)
	_replay.finished.connect(_on_replay_finished)

	_shop.setup(_economy, _inventory)
	_levels.setup(_world, _shop, _economy, _inventory, _spawner, _crossing)
	_hud.build(_spawner, _crossing, _economy, _inventory, _shop, _levels, _blueprints)

	_hud.save_blueprint_requested.connect(_on_save_blueprint)
	_hud.load_blueprint_requested.connect(_on_load_blueprint)

	_hud.buy_requested.connect(_shop.buy)
	_hud.box_requested.connect(_shop.buy_box)
	_hud.place_requested.connect(_on_place_requested)
	_hud.place_all_requested.connect(_on_place_all_requested)
	_hud.recall_car_requested.connect(_on_recall_car_requested)
	_hud.start_crossing_requested.connect(_on_start_crossing_requested)
	_hud.next_level_requested.connect(_levels.advance)
	_hud.level_select_requested.connect(_on_level_select_requested)
	_hud.replay_requested.connect(_on_replay_requested)
	_hud.replay_skip_requested.connect(_on_replay_skip_requested)

	_manipulator.water = $World/Water
	_crossing.water = $World/Water
	_manipulator.delete_requested.connect(_spawner.remove)
	_manipulator.release_blocked.connect(_hud.report_blocked)
	_spawner.object_removed.connect(_inventory.add.bind(1))
	_crossing.attempt_started.connect(_on_crossing_started)
	_crossing.attempt_finished.connect(_on_crossing_finished)
	_levels.campaign_finished.connect(_hud.report_campaign_finished)
	_levels.level_loaded.connect(_on_level_loaded)

	var args := OS.get_cmdline_user_args()
	_testing = args.has("--smoke") or args.has("--carcheck") or args.has("--bench")

	# The persistence check needs the real save path — writing the file and reading
	# it back IS what it tests — so it redirects the slot to a scratch file instead
	# of borrowing _testing, which would switch off every write it means to check.
	for arg: String in args:
		if arg.begins_with("--savefile="):
			SaveGame.path = "user://%s" % arg.substr(11)
		elif arg == "--levelcheck":
			_check_level = 2
		elif arg.begins_with("--levelcheck="):
			_check_level = int(arg.substr(13))

	# Dev sandbox: open a level directly, with money, and leave the save alone.
	#   godot -- --sandbox=3 --money=5000
	#
	# It borrows _testing rather than adding a second flag, because what it wants
	# is exactly what _testing already guarantees: nothing written to disk. Trying
	# out level 4's pieces must not overwrite somebody's run.
	_sandbox_level = -1
	for arg: String in args:
		if arg.begins_with("--sandbox="):
			_sandbox_level = int(arg.substr(10))
			_testing = true
		elif arg.begins_with("--money="):
			_sandbox_money = int(arg.substr(8))

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
	elif args.has("--bench"):
		_run_bench()
	elif _check_level >= 0:
		_run_level_check()


## Resume where the player left off, or start a fresh run if there's no save.
##
## The level must be loaded first: that builds the world, refills the shop and
## empties the strait, all of which the save then overwrites with what was
## actually left. Doing it the other way round would wipe the restored state.
func _load_or_start() -> void:
	if _sandbox_level >= 0:
		_levels.load_level(_sandbox_level)
		_levels.unlocked = _levels.levels.size()
		_economy.add(_sandbox_money)
		return

	var data := {} if _testing else SaveGame.load_data()

	# The select screen asked for a particular strait. The save holds each level
	# separately, so this restores that one's bridge, pieces and shop if the
	# player has been there before, and leaves a clean strait if they haven't.
	var chosen := Campaign.requested_level
	Campaign.requested_level = -1
	_levels.load_level(chosen if chosen >= 0 else int(data.get("level", 0)))
	if not data.is_empty():
		SaveGame.apply(data, _levels, _economy, _inventory, _shop, _spawner, _blueprints)

	# No save means this is somebody's first turn, so teach it. Tied to the
	# absence of a save rather than to a "seen it" flag on purpose: the flag would
	# have to live outside the save to be worth anything, and then starting a new
	# game a month later would drop you in cold.
	#
	# Checked AFTER the level is loaded rather than inside a branch, which is what
	# broke it: NEW GAME deletes the save and sets Campaign.requested_level, so it
	# arrived down the "player picked a strait" path and returned before reaching
	# this — the one player guaranteed to need the walkthrough was the only one who
	# never saw it. The condition is about the save, not about how you got here.
	#
	# Not during the headless checks, which have no way to dismiss it and would sit
	# behind the overlay pressing buttons that never get the click.
	if data.is_empty() and not _testing:
		_hud.start_tutorial()


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
const SAVE_DELAY := 1.5

var _save_due: float = -1.0


func request_save() -> void:
	if _testing:
		return
	_save_due = SAVE_DELAY


func _process(delta: float) -> void:
	if _save_due < 0.0:
		return
	_save_due -= delta
	if _save_due > 0.0:
		return
	# Never while a piece is in hand. A save walks the whole bridge and writes the
	# file, and the one moment that hitch is guaranteed to be felt is mid-drag,
	# when the piece is tracking the cursor every frame. Held back until release,
	# which is itself a save trigger — so this delays the write rather than
	# skipping it.
	if _manipulator != null and _manipulator.held != null:
		return
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
	# Escape stops a replay before it does anything else, including leaving
	# fullscreen: while a replay is up it is the only thing on screen, so it is
	# the only thing Escape can sensibly mean.
	if key == KEY_ESCAPE and _replay.is_playing:
		_on_replay_skip_requested()
		get_viewport().set_input_as_handled()
	elif UITheme.is_fullscreen_key(key):
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


## How far apart shift-placed pieces are laid out, and how many go in a row
## before the next one starts above it. Wide enough that even the long beams land
## clear of each other — pieces spawned inside one another are thrown apart by
## the solver, which is the one way this could go visibly wrong.
const BULK_STEP := Vector2(150.0, -110.0)
const BULK_PER_ROW := 6


## Shift-click on a belt card: tip that card's whole stock into the strait.
##
## Placed rather than held, because a hand holds one piece: the ghost-placement
## flow is for putting a piece exactly where you want it, and the case this
## exists for is the opposite one — twenty planks bought in a batch that all have
## to come out of stock before any arranging can start, which was twenty clicks
## and twenty drags of an object you were going to move again anyway.
##
## They come down in a loose stack above the middle of the view and fall, so they
## land in a heap on whatever is under them. That is the intended result: it is a
## pile of parts to work from, not a bridge.
func _on_place_all_requested(def: ObjectDef) -> void:
	if _attempt_active or _crossing.is_running:
		return

	# A piece already in hand would be left hovering while the stack rains down
	# past it, and would then be dropped into the middle of the pile.
	_manipulator.stash_held()

	var centre := _camera.get_screen_center_position()
	var placed := 0
	while _inventory.count(def) > 0 and not _spawner.is_full():
		if not _inventory.take(def):
			break
		var col := placed % BULK_PER_ROW
		var row := placed / BULK_PER_ROW
		var at := centre + Vector2(
			(float(col) - float(BULK_PER_ROW - 1) * 0.5) * BULK_STEP.x,
			-160.0 + float(row) * BULK_STEP.y
		)
		_spawner.spawn(def, at)
		placed += 1

	if placed > 0:
		_hud.report_bulk_placed(def, placed)


## A level change cancels any pending restore. Without this, changing level during
## the post-attempt linger would rebuild the old level's bridge in the new strait.
func _on_level_loaded(_level: LevelDef, _index: int) -> void:
	var audio := get_node_or_null(^"/root/Audio")
	if audio != null:
		audio.set_level_music(_index)
	_attempt_active = false
	_pre_crossing_layout.clear()
	_camera.stop_following()
	# Saved layouts belong to the strait they were taken in — a span shaped for one
	# is meaningless in a wider one — so the arriving level starts with none, and
	# SaveGame puts that level's own slots back if it has any. Cleared here rather
	# than filtered at the point of use, so the panel never shows three rows that
	# can't be pressed.
	#
	# This used to be the end of them: the slots were saved globally, so clearing
	# them on the way out and autosaving on the way in wrote the empty set over the
	# only copy. They now live in the level's bucket and survive the round trip.
	_blueprints.clear_all()
	_auto_slot = -1
	_auto_bridge = 0

	# The film goes with the strait it was shot in. Its puppets are placed in world
	# coordinates, so replaying a run from The Narrows over The River would put a
	# bridge in mid-air and drive a truck through the water beside it.
	_stop_replay()
	_finish_replay()
	_recorder.discard()
	_hud.set_replay_available(false)


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


## The slot this level's winning bridge was filed into, and what that bridge
## cost. Both reset with the level: slots are per-level already, and a cost from
## another strait is not a number to compare against.
var _auto_slot: int = -1
var _auto_bridge: int = 0


## File the bridge that just got across into a saved-builds slot.
##
## A crossing is exactly the moment a layout becomes worth keeping, and it is
## also the moment the player is least likely to think of it — the panel is up,
## there is money on it, and NEXT STRAIT is right there. Coming back to a strait
## to beat your own price and finding the bridge that set it already in a slot is
## the whole point.
##
## An empty slot first, so this never eats a layout the player saved by hand. If
## all three are full it claims the last one and then keeps that one for the rest
## of the level — a player who has filled every slot deliberately loses at most
## one of them, not a new one per crossing.
##
## Later crossings only overwrite when they were cheaper. The slot holds "the
## best bridge that worked here", which is the same thing the leaderboard ranks;
## replacing it with the most recent crossing would let a sloppier run quietly
## delete the good one.
func _autosave_winning_build(bridge_price: int) -> void:
	if _pre_crossing_layout.is_empty():
		return

	if _auto_slot < 0:
		for i in Blueprints.SLOTS:
			if _blueprints.is_empty(i):
				_auto_slot = i
				break
		if _auto_slot < 0:
			_auto_slot = Blueprints.SLOTS - 1
	elif bridge_price >= _auto_bridge:
		return

	_auto_bridge = bridge_price
	_blueprints.store(_auto_slot, _levels.index, _pre_crossing_layout)
	_hud.report_build_autosaved(_auto_slot, _pre_crossing_layout.size())


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


## What the bridge the truck just drove onto cost, at shop prices. Lower wins.
##
## Shop price rather than an abstract tier score: it is the number the player was
## already weighing up when they bought the piece, so "I crossed it for $240" is
## a figure they can feel the size of and can go straight back to the shop and
## try to beat. A separate points scale meant every bridge had two costs, and the
## one being ranked was the one nothing else in the game mentioned.
##
## Priced from the whole layout, including pieces that came out of a booster pack
## and were never paid for at the counter. The board is ranking the bridge, not
## the receipt — and letting box pieces count as free would make the cheapest
## bridge a question of gambling luck rather than of building.
##
## Counted from the layout captured when START was pressed, not from what is in
## the water now — by the time an attempt finishes, pieces have sunk, been
## knocked into the deep or been dragged along under the wheels, and the player
## should be scored on the bridge they built rather than on the wreck it became.
func _bridge_points() -> int:
	var total := 0
	for entry: Dictionary in _pre_crossing_layout:
		var def := entry[&"def"] as ObjectDef
		if def != null:
			total += def.price
	return total


## Watch the last attempt again, optionally filming it.
##
## Nothing about the live strait is touched. The replay hides the bridge and the
## truck, puts inert copies of both on screen and drives them off the recording;
## dismissing it puts the real ones back exactly where they were. That is the
## whole reason it is a puppet show rather than a re-run — a replay must never be
## able to cost the player the bridge they built.
func _on_replay_requested(record_video: bool) -> void:
	if _crossing.is_running or not _recorder.has_recording():
		return

	# Asked to film somewhere that cannot: say why and leave whatever is on screen
	# alone. Restarting the replay to then not record it would look like the button
	# had worked, and the player would sit through the whole thing waiting for a
	# file that was never coming.
	if record_video:
		var blocked := VideoCapture.unavailable_reason()
		if not blocked.is_empty():
			_hud.report_video_failed(blocked)
			if _replay.is_playing:
				return

	# Restarting from the beginning, whether or not one was already running: the
	# SAVE VIDEO button is pressed *during* a replay, and it has to film the whole
	# thing rather than join it wherever the player happened to press.
	_stop_replay()

	# Anything in hand would hang in mid-air over the replay, since the
	# manipulator is not what gets hidden.
	_manipulator.stash_held()

	_replay_recording = record_video and VideoCapture.start()
	if record_video and not _replay_recording and VideoCapture.is_supported():
		# Supported, but the browser refused this particular attempt.
		_hud.report_video_failed("The browser refused to start recording")

	_hud.enter_replay_mode(_replay_recording)
	_replay.play(_recorder, [$Objects as Node2D, $Vehicle as Node2D])
	var target := _replay.follow_target()
	if target != null:
		_camera.follow(target)


func _on_replay_skip_requested() -> void:
	if not _replay.is_playing:
		return
	# A skipped replay produces no file. The player asked to stop watching, and
	# handing them a truncated video of the part they chose not to see is not what
	# "skip" means anywhere else.
	if _replay_recording:
		VideoCapture.cancel()
		_replay_recording = false
	_stop_replay()
	_finish_replay()


func _on_replay_finished() -> void:
	if _replay_recording:
		VideoCapture.stop_and_download("strait-across-%s" % Time.get_datetime_string_from_system(
			false, false
		).replace(":", "-"))
		_replay_recording = false
		_hud.report_video_saved()
	_stop_replay()
	_finish_replay()


## Take the puppets down and give the camera back.
##
## Split from _finish_replay so that starting a second replay can tear the first
## one down without flashing the dock back on between them.
func _stop_replay() -> void:
	if _replay.is_playing or _replay.get_child_count() > 0:
		_replay.stop()
	_camera.stop_following()


func _finish_replay() -> void:
	_hud.exit_replay_mode(_recorder.has_recording())
	# Back onto the truck if one is still out there — a replay watched during the
	# post-attempt linger should hand the camera back to the wreck it was on.
	if is_instance_valid(_crossing.car):
		_camera.follow(_crossing.car.chassis)


## Back to the select screen, with the run written down first: the strait, the
## money and the standings are all worth keeping, and the player asked to change
## levels rather than to throw anything away.
func _on_level_select_requested() -> void:
	save_now()
	# So the select screen's BACK button comes back here rather than to the menu.
	Campaign.return_to_game = true
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")


func _on_crossing_started() -> void:
	_pre_crossing_layout = _spawner.snapshot()
	_attempt_active = true
	_camera.follow(_crossing.car.chassis)
	# The previous run's film goes here rather than when the new one ends: a
	# player who presses START and immediately changes their mind should not be
	# left with a REPLAY tab pointing at a recording that no longer exists.
	_hud.set_replay_available(false)
	_recorder.start($Objects, _crossing.car)


## An attempt is a test, not a commitment: whatever the car knocked apart gets put
## back so the player can adjust one plank instead of rebuilding the span.
func _on_crossing_finished(result: CrossingManager.Result, progress: float) -> void:
	# Before anything that builds UI: the crossing panel offers a WATCH button
	# only when there is film, so the recorder has to have stopped and the HUD has
	# to know about it by the time the panel is built.
	_recorder.stop()
	_hud.set_replay_available(_recorder.has_recording())

	var succeeded := result == CrossingManager.Result.SUCCESS
	var first_clear := succeeded and _levels.mark_cleared()
	var settled := _economy.settle_attempt(succeeded, progress, first_clear)

	# The leaderboard entry, and only for a crossing that actually finished: a
	# bridge that dropped the truck at 90% cost salvage too, but it is not a
	# solution and ranking it against ones that worked would put the cheapest
	# failure at the top of the table.
	var bridge := _bridge_points()
	var rank := _levels.submit_bridge(bridge) if succeeded else 0
	# Before the panel, not after: the panel names the slot the bridge went into,
	# so the filing has to have happened by the time it is built.
	if succeeded:
		_autosave_winning_build(bridge)

	_hud.report_crossing(result, progress, settled[0], settled[1], bridge, rank)
	if succeeded and not _levels.is_last():
		_hud.offer_next_level()
	# The last strait's congratulations lives inside the crossing panel itself —
	# see Hud.show_crossed_panel(). Firing report_campaign_finished() here as well
	# stacked a second modal on top of it in the same frame.
	if not _testing:
		save_now()

	await get_tree().create_timer(REPLAY_LINGER).timeout
	# Another attempt — or a level change — may have happened during the linger.
	if _crossing.is_running or not _attempt_active:
		return
	_crossing.reset()
	# Not while a replay is up. The bridge and the truck are hidden behind the
	# puppets, so putting them back is invisible and harmless — but taking the
	# camera off the replay's truck mid-crossing is not.
	if not _replay.is_playing:
		_camera.stop_following()
	_spawner.restore(_pre_crossing_layout)
	_attempt_active = false


## Headless benchmark: fill a strait to the cap and measure what it costs.
##
##   godot --headless --quit-after 9000 res://scenes/main.tscn -- --bench --pfps=60
##
## Separate from --smoke because the two want opposite things. The smoke test
## proves the game still works and therefore goes through the real buy/place path,
## which the shop's stock limits cap at about 29 pieces — nowhere near the 140 the
## strait allows, and performance questions only start being interesting near the
## cap. This spawns straight into the world instead: no economy, no inventory,
## deterministic positions, same count every run.
##
## --pfps overrides the physics rate so the web-relevant number (60) can be taken
## on a desktop machine. Without it the desktop default of 120 is measured, which
## is the wrong figure for the build players actually run.
##
## Prints one machine-readable line so two runs can be diffed without reading prose.
func _run_bench() -> void:
	var args := OS.get_cmdline_user_args()
	var target: int = _spawner.max_objects
	for arg: String in args:
		if arg.begins_with("--pfps="):
			Engine.physics_ticks_per_second = int(arg.substr(7))
		elif arg.begins_with("--pieces="):
			target = int(arg.substr(9))

	var level := _levels.level
	var area: Rect2 = _world.build_area()
	var defs := _placeable_defs(level)
	if defs.is_empty():
		print("BENCH error=no placeable defs")
		get_tree().quit(1)
		return

	# A deterministic lattice across the strait, cycling the level's own pieces so
	# the mix is representative rather than 140 of the cheapest thing.
	const COLUMNS := 14
	var step := (area.size.x - 400.0) / float(COLUMNS)
	var spawn_start := Time.get_ticks_usec()
	for i in target:
		var def: ObjectDef = defs[i % defs.size()]
		_spawner.spawn(def, Vector2(
			area.position.x + 200.0 + (i % COLUMNS) * step,
			-200.0 - floorf(i / float(COLUMNS)) * 220.0
		))
	var spawn_ms := float(Time.get_ticks_usec() - spawn_start) / 1000.0
	print("BENCH placed=%d pfps=%d spawn_ms=%.2f" % [
		_spawner.count(), Engine.physics_ticks_per_second, spawn_ms
	])

	# Let the pile fall and settle. The interesting steady state is a bridge that
	# has stopped moving, which is also the state a player spends most time in.
	await get_tree().create_timer(8.0).timeout
	var settled := await _sample(300)

	# The restore spike, measured on its own. This is the single most expensive
	# frame in normal play: it happens on every level load, every blueprint load,
	# and after every crossing attempt, and it tears down and rebuilds the whole
	# bridge inside one frame.
	var layout: Array[Dictionary] = _spawner.snapshot()
	var restore_start := Time.get_ticks_usec()
	_spawner.restore(layout)
	var restore_ms := float(Time.get_ticks_usec() - restore_start) / 1000.0
	print("BENCH restore_ms=%.2f restored=%d" % [restore_ms, _spawner.count()])
	await get_tree().create_timer(3.0).timeout

	# Then the heaviest moment in the game: everything awake at once with the
	# truck's own bodies and joints on top.
	_crossing.start_crossing()
	var driving := await _sample(240)
	print("BENCH settled_phys_ms=%.3f settled_proc_ms=%.3f settled_act=%d settled_pairs=%d" % [
		settled[0], settled[1], int(settled[2]), int(settled[3])
	])
	print("BENCH driving_phys_ms=%.3f driving_proc_ms=%.3f driving_act=%d driving_pairs=%d" % [
		driving[0], driving[1], driving[2], driving[3]
	])
	print("BENCH worst_phys_ms=%.3f pieces=%d nodes=%d" % [
		maxf(settled[4], driving[4]),
		_spawner.count(),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
	])
	get_tree().quit()


## Mean physics/process time and physics load over `ticks` physics frames, plus
## the worst single physics frame seen. Returns
## [phys_ms, proc_ms, active, pairs, worst_phys_ms].
##
## Sampled per physics frame rather than per rendered frame because the number
## under test is the physics cost, and in headless the two rates differ.
func _sample(ticks: int) -> Array:
	var phys := 0.0
	var proc := 0.0
	var active := 0.0
	var pairs := 0.0
	var worst := 0.0
	for i in ticks:
		await get_tree().physics_frame
		var this_phys := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		phys += this_phys
		worst = maxf(worst, this_phys)
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		active += Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS)
		pairs += Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS)
	var n := float(ticks)
	return [phys / n, proc / n, active / n, pairs / n, worst]


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


## Headless persistence check: a bridge must still be there when the player comes
## back to the strait they built it in.
##
##   godot --headless --quit-after 4000 res://scenes/main.tscn -- \
##       --levelcheck --savefile=save_levelcheck.json
##
## Deliberately goes through the real file rather than through capture() alone.
## The bug this exists for lived in the difference between the two: every bucket
## was correct in memory, and the write still dropped one.
## Which leg of the check this scene is running. Static because the second leg is
## a genuine scene reload — the same thing the level select does — and that is the
## point: a returning player arrives in a brand new Main, holding nothing but the
## file.
static var _check_returning: bool = false

## Which strait the check plays, from --levelcheck=N. -1 means it isn't running.
static var _check_level: int = -1
## How much of a bridge to build before leaving. Enough to be unmistakably there,
## small enough to settle quickly.
const CHECK_PIECES := 8


func _run_level_check() -> void:
	if _check_returning:
		_finish_level_check()
		return
	SaveGame.delete()
	_levels.load_level(_check_level)
	_economy.add(4000)

	# A bridge worth missing, spread out so the pieces settle instead of exploding.
	var area: Rect2 = _world.build_area()
	var step := (area.size.x - 400.0) / 8.0
	var lane := 0
	for def: ObjectDef in _levels.level.shop_pool:
		while _shop.remaining(def) > 0 and _economy.can_afford(def.price) and lane < CHECK_PIECES:
			assert(_shop.buy(def), "shop refused an affordable piece")
			_on_place_requested(def)
			if _manipulator.held == null:
				continue
			_manipulator.held.position = Vector2(area.position.x + 200.0 + lane * step, -200.0)
			_manipulator.release(true)
			lane += 1
	var built: int = _spawner.count()
	assert(built > 0, "level check placed nothing")
	save_now()
	print("LEVELCHECK built=%d on level=%d" % [built, _levels.index])

	# Beat it and take the NEXT LEVEL button, which is the reported sequence. The
	# crossing is driven by hand rather than actually driven: what is under test is
	# what the finish does to the save, and a truck that falls short would never
	# reach it. NEXT is pressed while the replay linger is still running, because
	# that is when the button is on screen.
	# A real attempt, so the car, the signals and the linger are the live ones. It
	# does not matter whether the truck gets across: what the finish does to the
	# save is the same either way, and a bridge of eight pieces will not span this.
	await get_tree().create_timer(4.0).timeout
	_on_start_crossing_requested()
	assert(_crossing.is_running, "level check could not start a crossing")
	await _crossing.attempt_finished
	_levels.advance()
	await get_tree().create_timer(REPLAY_LINGER + 0.5).timeout
	save_now()
	print("LEVELCHECK advanced to level=%d" % _levels.index)

	# What a returning player would find. Read from disk, because that is all a
	# fresh scene has: the bucket in memory being right is not the same thing.
	var data := SaveGame.load_data()
	assert(not data.is_empty(), "level check wrote a save it cannot read back")
	var back: Array[Dictionary] = SaveGame.bridge_from_json(
		SaveGame._bucket(data, _check_level).get("bridge", [])
	)
	print("LEVELCHECK left level=%d bridge on disk=%d/%d" % [_check_level, back.size(), built])
	assert(back.size() == built, "leaving a level erased its bridge")

	# And the level moved on to must not have inherited it.
	var arrived: Array[Dictionary] = SaveGame.bridge_from_json(
		SaveGame._bucket(data, _check_level + 1).get("bridge", [])
	)
	print("LEVELCHECK next level=%d bridge on disk=%d" % [_check_level + 1, arrived.size()])
	assert(arrived.is_empty(), "the next level arrived with the last one's bridge")

	# Now actually go back, the way a player does: out to the select screen and
	# into level 3 again, which tears down this Main and builds a fresh one.
	_check_expected = built
	_check_returning = true
	# What LEVEL SELECT does, minus the screen itself: write the run down, then ask
	# for a strait. The select screen only reads the save, so skipping it changes
	# nothing about what is under test.
	save_now()
	Campaign.requested_level = _check_level
	get_tree().change_scene_to_file("res://scenes/main.tscn")


## How many pieces the strait had when we left it.
static var _check_expected: int = 0


## The returning leg. By the time this runs, _load_or_start() has already loaded
## the level and applied the save, so the strait either has the bridge back or it
## does not.
func _finish_level_check() -> void:
	await get_tree().process_frame
	print("LEVELCHECK returned to level=%d placed=%d/%d stock=%d" % [
		_levels.index, _spawner.count(), _check_expected, _inventory.total()
	])
	assert(_levels.index == _check_level, "came back to the wrong strait")
	assert(_spawner.count() == _check_expected, "the bridge was erased on the way back")
	print("LEVELCHECK ok")
	get_tree().quit()


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
