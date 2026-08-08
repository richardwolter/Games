## The workbench: a dock along the bottom edge holding everything you do between
## attempts, plus the result banner over the strait.
##
## Bottom rather than side because the pieces are dragged *into* the water: a
## dock leaves both shores and the whole sky clear, and the belt of owned pieces
## sits closest to where they're going.
##
## The whole dock is built in code from ui_theme.gd, so the layout and the look
## live next to each other and the scene file stays a single node. Buying is not
## here — it's in ShopMenu, opened by the one mustard button — because the
## catalogue is read occasionally and the piece belt is read constantly.
extends CanvasLayer

## Take an owned piece out of stock and into the player's hand.
signal place_requested(def: ObjectDef)
## Shift-click on a belt card: empty that card's stock into the strait in one
## go, rather than one piece at a time through the ghost-placement flow.
signal place_all_requested(def: ObjectDef)
## Forwarded from the shop menu, so main.gd still wires to one place.
signal buy_requested(def: ObjectDef)
signal box_requested(box: BoxDef)
signal next_level_requested()
## Leave the strait for the select screen. Main saves before it changes scene —
## the run is not being abandoned, just set down.
signal level_select_requested()
## Take the car off the strait and put the bridge back the way it was.
signal recall_car_requested()
## Run an attempt. Routed through Main rather than calling CrossingManager here,
## because a start may first have to undo the attempt before it.
signal start_crossing_requested()
## Copy the bridge into one of the three layout slots, or put one back.
signal save_blueprint_requested(index: int)
signal load_blueprint_requested(index: int)
## Watch the last attempt again. `record_video` also films it to a file.
signal replay_requested(record_video: bool)
## Cut a replay short — the SKIP button, or Escape.
signal replay_skip_requested()
## Experimental only. Buy a level of a salvage upgrade (SalvageUpgrades.Kind), or
## swap which truck goes out (CrossingManager.Truck). Both carry plain ints so the
## HUD does not have to know either enum's shape.
signal upgrade_requested(kind: int)
signal truck_type_requested(kind: int)

## Belt cards are square and uniform, so the row reads as a rack of parts.
const CARD_SIZE := 62
const ICON_SIZE := 26
## Height of each of the two pill slots under a belt card (recall, then buy).
const CARD_PILL_HEIGHT := 18
## How long a result banner stays up before it clears.
const BANNER_HOLD := 4.0
## The colour the lettering fills with as the crossing advances.
const CHARGE_TINT := Color("3fbf4a")
## The three painted signs on the top-right rail, and their inset from the screen
## edge.
##
## Height, not size: the kit sprites carry their own wording and their own
## proportions, and each one's width falls out of that. Kept to 26px because the
## bars are nearly five times as wide as they are tall — at the 40px the plates
## used, the three of them ate a third of the window across the top.
const CORNER_HEIGHT := 26.0
## The leaderboard sign is a shield with a bar hung off it, so it is half again
## as tall for its width. Matched on the bar rather than on the whole sprite, or
## it comes out a third narrower than the two beside it.
const SCORES_HEIGHT := 34.0
## How far the two plain bars drop so their lettering lines up with the
## leaderboard's. Its bar sits at 0.536 of the sprite's height — measured, not
## guessed, because the shield below it is what makes the sprite tall — so the
## bars are dropped by the difference between the two centres.
const BAR_DROP := SCORES_HEIGHT * 0.536 - CORNER_HEIGHT * 0.5
const SETTINGS_MARGIN := 12.0
## Gap between the three corner buttons.
const CORNER_GAP := 8.0

var _spawner: Node
var _crossing: CrossingManager
var _economy: Economy
var _inventory: Inventory
var _shop: Shop
var _levels: LevelManager
var _blueprints: Blueprints
## The experimental systems. Present on every build, but nothing that reads them
## is constructed unless Experimental.on().
var _upgrades: SalvageUpgrades
var _ropes: RopeManager
## The truck picker, the charge gauge and the rope tab. All null on a normal
## build, and every use of them is null-guarded rather than flag-checked twice.
var _truck_button: Button
var _battery_bar: ProgressBar
var _battery_panel: Control
var _rope_button: Button
var _rope_label: Label
## Rope count and allowance as the tab last showed them, so the poll is an
## integer compare. The allowance is in here because it changes with the level and
## nothing about the ropes themselves moves when it does — the tab read "0 / 1" on
## a strait that allows two.
var _rope_shown: int = -1
var _rope_limit_shown: int = -1
## The online board. A child of the HUD rather than an autoload: it is only ever
## read from the crossing panel, and its cache should live exactly as long as the
## screen that shows it.
var _boards: Leaderboard

var _shop_menu: ShopMenu
var _dock: Control
var _hints: Label
var _header_strip: PanelContainer
var _level_label: Label
var _money_label: Label
## The level's leaderboard standing, and the divider before it. Both hide
## together on a level that has never been crossed.
var _record_label: Label
var _record_rule: ColorRect
## What the pieces in the water are worth, and the divider before it. Both hide
## together while the strait is empty.
var _bridge_label: Label
var _bridge_rule: ColorRect
## The belt of owned pieces, left to right along the dock.
var _piece_belt: HBoxContainer
var _start_button: BaseButton
## The slot START sits in, kept because SAVED BUILDS is parked over it and has to
## follow it as the belt resizes.
var _start_slot: Control
## The lettering layer, and the clip that reveals it left to right.
var _start_fill: TextureRect
var _start_fill_clip: Control
## "START CROSSING" before an attempt, "CROSSING" during one.
var _sign_idle: Texture2D
var _sign_running: Texture2D
var _placed_label: Label
## Smoothed crossing progress. The raw value jumps when the car is thrown, and a
## fill that lurches backwards reads as a glitch rather than as a setback.
var _shown_progress: float = 0.0
var _remove_car_button: Button
## A TextureButton, not a Button: it is a painted sign rather than a plate.
var _next_button: BaseButton
var _banner: Label
var _banner_timer: float = 0.0
## True while an attempt is running, when nothing may be added to the bridge.
var _belt_locked: bool = false
## Set by Main for the whole length of an attempt, car spawn to bridge restored.
## The belt reads this rather than the crossing's own is_running, which goes false
## a second and a half before building is actually allowed again.
var build_locked: bool = false
## How often the per-type placed counts on the belt are re-read.
const PLACED_POLL_HZ := 6.0
var _placed_poll: float = 0.0
## Total placed as the badges last saw it, so an unchanged bridge costs nothing.
var _placed_shown: int = -1
## Kept only so the first-run walkthrough can point at them.
var _meter: Label
var _meter_timer: float = 0.0
## Longest frame since the meter last refreshed, in ms. Reset each 1Hz tick.
var _worst_frame_ms: float = 0.0
var _shop_button: BaseButton
var _recall_button: BaseButton
var _blueprints_button: BaseButton
## The three top-right buttons as one node, so a replay can hide them together.
var _corner: Control
## REPLAY, beside SAVED BUILDS. Hidden until an attempt has actually been filmed.
var _replay_button: BaseButton
## The controls that appear over a running replay, and the SAVE VIDEO button on
## it — which is missing entirely on a build with no browser to encode with.
var _replay_bar: Control
var _replay_save_button: BaseButton
## The saved-layouts panel while it is open, so its rows can be refreshed in
## place after a save without rebuilding the modal under the cursor.
var _blueprints_panel: Control
var _blueprint_rows: Array[Callable] = []
## The slot Main just filed a winning bridge into, and how big it was. Read once
## by the crossing panel and then cleared, so a panel reopened later doesn't
## claim a save that happened two crossings ago.
var _autosaved_slot: int = -1
var _autosaved_pieces: int = 0
var _root: Control
## The confirmation modal, while one is up. Escape dismisses it.
var _confirm_overlay: Control
## Rows keyed by def, so a purchase updates a count without a rebuild.
var _piece_rows: Dictionary[ObjectDef, Dictionary] = {}

## The "you can afford a booster" nudge, and the preference key that silences it.
##
## Kept as a preference rather than a save field so that turning it off stays off
## across a new game — a player who has said "I know where the shop is" has said
## it about themselves, not about that particular run.
const NUDGE_PREF := "shop_nudge_dismissed"
var _nudge: Control
var _nudge_dismissed: bool = false
## True while the player is above the price of the cheapest booster. The nudge is
## edge-triggered off this, so it appears when they cross the line and does not
## come back every frame they stay above it.
var _could_afford_box: bool = false


func build(
	spawner: Node,
	crossing: CrossingManager,
	economy: Economy,
	inventory: Inventory,
	shop: Shop,
	levels: LevelManager,
	blueprints: Blueprints,
	upgrades: SalvageUpgrades = null,
	ropes: RopeManager = null
) -> void:
	_upgrades = upgrades
	_ropes = ropes
	_spawner = spawner
	_crossing = crossing
	_economy = economy
	_inventory = inventory
	_shop = shop
	_levels = levels
	_blueprints = blueprints

	var root := Control.new()
	root.name = "UI"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The root spans the screen only so the banner can centre on it; it must not
	# swallow clicks aimed at the pieces in the water.
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.build()
	add_child(root)
	_root = root

	_dock = _build_panel()
	root.add_child(_dock)
	# After the dock, so the tab draws over it rather than under, and so the dock
	# has a rect to be placed against.
	root.add_child(_build_blueprints_button())
	root.add_child(_build_replay_button())
	root.add_child(_build_contextual())
	_place_blueprints_button.call_deferred()
	_place_contextual.call_deferred()
	_header_strip = _build_header()
	root.add_child(_header_strip)
	_corner = _build_settings_button()
	root.add_child(_corner)
	root.add_child(_build_banner())
	_hints = _build_hints()
	root.add_child(_hints)
	root.add_child(_build_meter())
	root.add_child(_build_replay_bar())

	_boards = Leaderboard.new()
	add_child(_boards)

	_shop_menu = ShopMenu.new()
	root.add_child(_shop_menu)
	_shop_menu.setup(_economy, _shop, _upgrades)
	_shop_menu.buy_requested.connect(func(def: ObjectDef) -> void: buy_requested.emit(def))
	_shop_menu.box_requested.connect(func(box: BoxDef) -> void: box_requested.emit(box))
	_shop_menu.upgrade_requested.connect(func(kind: int) -> void: upgrade_requested.emit(kind))

	if Experimental.on():
		root.add_child(_build_battery_gauge())
		root.add_child(_build_rope_tab())
		_upgrades.changed.connect(_refresh_truck_button)
		_ropes.changed.connect(_refresh_rope_tab)
		_refresh_truck_button()
		_refresh_rope_tab()

	_nudge_dismissed = Prefs.get_flag(NUDGE_PREF)

	_economy.money_changed.connect(_on_money_changed)
	_inventory.changed.connect(_refresh_pieces)
	# What's left to sell is the one input to the belt's price bars that money and
	# inventory don't cover: the last unit of a piece leaves stock at the same
	# moment it enters inventory, but only this says the shelf is now empty.
	_shop.stock_changed.connect(_refresh_buy)
	_crossing.attempt_started.connect(_on_attempt_started)
	_levels.level_loaded.connect(_on_level_loaded)

	UITheme.enliven(root)


## How far above the dock's top edge SAVED BUILDS floats, and how big the plate
## is. Deliberately smaller than anything in the dock: it sits over the strait
## rather than in the workbench, so it has to read as a tab attached to the dock
## and not as a piece of dock that came loose.
const BLUEPRINTS_GAP := 5.0
## Painted signs from the kit now, so the widths come from the artwork rather
## than from a chosen rectangle — both are set in _build_*_button() below.
const BLUEPRINTS_HEIGHT := 26.0
## REPLAY & SAVE, parked on the same strip immediately left of SAVED BUILDS. Its
## sprite is an arrow with a camera on it and is much taller for its width, so
## the two tabs match on their bar rather than on their overall height.
const REPLAY_HEIGHT := 44.0
## The painted NEXT CROSSING signpost, centred over the water above the dock.
## Bigger than the 34 it had wedged in the dock row, without becoming the
## picture: at 86 the sign was reading as scenery rather than as a control.
const NEXT_HEIGHT := 44.0
## REMOVE CAR shares that place mid-attempt. Long and shallow, the opposite
## shape, so the two never read as the same control in the same spot.
const REMOVE_CAR_SIZE := Vector2(240.0, 30.0)
## How far the contextual control floats above the hint line, and how tall that
## line of small type is.
const CONTEXTUAL_GAP := 8.0
const HINT_LINE := 18.0
var _blueprints_size := Vector2(96.0, BLUEPRINTS_HEIGHT)
var _replay_size := Vector2(76.0, REPLAY_HEIGHT)
## Whether NEXT CROSSING was up when a replay started, so leaving the replay puts
## the screen back the way it was rather than guessing.
var _next_shown: bool = false
const REPLAY_GAP := 6.0


## SAVED BUILDS, floating above START rather than sitting in the dock row.
##
## It was the widest plate in the dock and it was taking that width from the
## belt, which is the one section that actually needs it — the belt is elastic
## and every fixed control beside it is a piece the player can't see. Lifting it
## out gives the belt ~130px back and gives the two contextual plates room to
## stop competing with it.
##
## Above START specifically because it is the only control that is neither
## destructive nor a commitment: parked over the commitment, it is easy to find
## when you want it and never on the way to anything else.
func _build_blueprints_button() -> Control:
	var builds := UITheme.kit_button("btn_saved_builds", BLUEPRINTS_HEIGHT)
	_blueprints_size = UITheme.kit_size("btn_saved_builds", BLUEPRINTS_HEIGHT)
	builds.tooltip_text = "Save this bridge to a slot, or bring a saved one back"
	builds.pressed.connect(_open_blueprints)
	_blueprints_button = builds
	return builds


## Park the tab centred over the START slot, just clear of the dock.
##
## Driven off the two rects rather than off constants, because the dock's height
## and START's x both fall out of the layout — the dock centres its row, so the
## slot moves whenever the belt gains or loses a piece. Hard-coding either put
## the tab over the middle of the strait on a full belt.
func _place_blueprints_button() -> void:
	if _blueprints_button == null or _start_slot == null or _dock == null:
		return
	var slot := _start_slot.get_global_rect()
	if slot.size.x <= 0.0:
		return
	# The taller of the two tabs sets the strip, and the shorter one is centred on
	# it. REPLAY & SAVE is an arrow with a camera on it and stands half again as
	# tall as SAVED BUILDS; sharing a top or a bottom edge made the pair look like
	# one had slipped.
	var floor_y := _dock.get_global_rect().position.y - BLUEPRINTS_GAP
	_blueprints_button.size = _blueprints_size
	var tall: float = maxf(_blueprints_size.y, _replay_size.y)
	_blueprints_button.position = Vector2(
		slot.position.x + (slot.size.x - _blueprints_size.x) * 0.5,
		floor_y - tall + (tall - _blueprints_size.y) * 0.5
	)
	if _replay_button != null:
		_replay_button.size = _replay_size
		_replay_button.position = Vector2(
			_blueprints_button.position.x - REPLAY_GAP - _replay_size.x,
			floor_y - tall + (tall - _replay_size.y) * 0.5
		)


## REMOVE CAR and NEXT CROSSING: the two contextual controls, on the strait
## rather than in the dock.
##
## They share one place because at most one of them is ever up, and that place is
## the middle of the band between the dock and the hint line — the widest empty
## strip on the screen, and the one the eye is already on when an attempt ends.
## In the dock they were a 126px plate wedged between the belt and START, which
## is the worst seat in the house for the one control the game wants pressed
## after a crossing.
func _build_contextual() -> Control:
	var strip := Control.new()
	strip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Thin and wide, so it reads as a bar laid over the water rather than as a
	# button that wandered out of the dock. It appears mid-attempt, when the
	# player is watching the truck and not the chrome.
	_remove_car_button = UITheme.plate_button(
		"REMOVE CAR", UITheme.STEEL.darkened(0.34), REMOVE_CAR_SIZE
	)
	_remove_car_button.add_theme_font_size_override(
		&"font_size", UITheme.FONT_SIZE_SMALL
	)
	_remove_car_button.pressed.connect(func() -> void: recall_car_requested.emit())
	_remove_car_button.visible = false
	strip.add_child(_remove_car_button)

	# The painted signpost, pointing the way it sends you, and big: it is the
	# reward for having got across, and the only thing on screen at that moment
	# worth pressing.
	_next_button = UITheme.kit_button("btn_next_crossing", NEXT_HEIGHT)
	_next_button.pressed.connect(func() -> void: next_level_requested.emit())
	_next_button.visible = false
	strip.add_child(_next_button)
	return strip


## Centres whichever of the two is up in the band above the dock.
##
## Driven off the dock's live rect for the same reason the tabs are: the dock's
## height follows its contents, so a constant here puts the bar through the
## belt on one level and over the water on another.
func _place_contextual() -> void:
	if _dock == null or _next_button == null:
		return
	var top := _dock.get_global_rect().position.y
	if top <= 0.0:
		return
	var width := get_viewport().get_visible_rect().size.x
	# Built from the same terms the hint line is pinned with — dock, tab strip,
	# hint — rather than read off the hint's rect: this runs on the dock's resort,
	# which happens before the hints have been re-pinned, so the live rect is one
	# layout out of date and put the sign inside the dock.
	var band := (
		top
		- BLUEPRINTS_GAP
		- maxf(_blueprints_size.y, _replay_size.y)
		- 8.0
		- HINT_LINE
	)
	for button: Control in [_next_button, _remove_car_button]:
		var size := button.custom_minimum_size
		button.size = size
		button.position = Vector2(
			(width - size.x) * 0.5, band - CONTEXTUAL_GAP - size.y
		)


## REPLAY, on the same strip as SAVED BUILDS.
##
## Not in the dock and not on the crossing panel alone, because the attempt worth
## watching again is usually the one that failed — a fridge pivoting a plank into
## the water is the game working, and there is no panel after that, only a
## banner. It lives beside the other tab because both are "things about the run
## you just had" rather than things you build with.
##
## Hidden until there is something to watch, so it never offers a replay of
## nothing.
func _build_replay_button() -> Control:
	var replay := UITheme.kit_button("btn_replay_save", REPLAY_HEIGHT)
	_replay_size = UITheme.kit_size("btn_replay_save", REPLAY_HEIGHT)
	replay.tooltip_text = "Watch the last attempt again"
	replay.visible = false
	replay.pressed.connect(func() -> void: replay_requested.emit(false))
	_replay_button = replay
	return replay


## The controls over a running replay: save it, or stop watching.
##
## Bottom centre, in the space the dock has just vacated. The top belongs to the
## result banner, which is still up when a replay is started straight off the
## back of an attempt — the two were centred on the same strip and printed over
## each other.
func _build_replay_bar() -> Control:
	var bar := PanelContainer.new()
	UITheme.paint(bar, PaintedBox.sign(UITheme.SLATE))
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.position = Vector2(0, -20)
	bar.visible = false

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	bar.add_child(row)

	var label := Label.new()
	label.text = "REPLAY"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override(&"font_color", UITheme.CREAM)
	row.add_child(label)

	# Always here, even where it cannot work. Building it only on a browser meant
	# the button was missing rather than refusing, and a missing control tells the
	# player nothing — not that the feature exists, not why it isn't offered, not
	# where it would be. It goes grey with the reason in its tooltip instead, and
	# pressing it says the same thing out loud in the banner.
	var blocked := VideoCapture.unavailable_reason()
	_replay_save_button = UITheme.plate_button(
		"SAVE VIDEO",
		UITheme.GREEN if blocked.is_empty() else UITheme.STEEL.darkened(0.34),
		Vector2(118, 30)
	)
	_replay_save_button.tooltip_text = (
		"Play it again and download it as a video file" if blocked.is_empty() else blocked
	)
	_replay_save_button.pressed.connect(func() -> void: replay_requested.emit(true))
	row.add_child(_replay_save_button)

	var skip := UITheme.plate_button("SKIP", UITheme.STEEL.darkened(0.34), Vector2(74, 30))
	skip.pressed.connect(func() -> void: replay_skip_requested.emit())
	row.add_child(skip)

	_replay_bar = bar
	return bar


## Whether there is a filmed attempt to watch. Main sets this; the tab appears
## the moment a run ends and goes away when the recording does.
func set_replay_available(available: bool) -> void:
	if _replay_button != null:
		_replay_button.visible = available


## Clear the screen for a replay.
##
## Everything goes: dock, tabs, readouts, hints, banner. Partly because the
## strait is the only thing worth looking at for those few seconds, and partly
## because on the web the canvas is what gets filmed — a video of somebody's
## bridge with a piece belt and a money counter across it is a screenshot of a
## game, not a clip of a crossing.
##
## While filming, the bar goes too. It would otherwise be in the file, and a
## SAVE VIDEO button baked into the video is the one thing that cannot be edited
## out afterwards.
func enter_replay_mode(recording: bool) -> void:
	# The contextual signpost goes too, and its state is remembered rather than
	# recomputed: it is up exactly when the last attempt crossed, which is also
	# when somebody is most likely to watch the replay — so without this the
	# replay of the crossing has NEXT CROSSING standing in the middle of it.
	_next_shown = _next_button.visible
	for node: Control in [_dock, _header_strip, _corner, _hints, _blueprints_button,
			_replay_button, _next_button, _remove_car_button]:
		if node != null:
			node.visible = false
	# The banner survives an unrecorded replay: it is how a refused SAVE VIDEO
	# explains itself, and the replay is the only thing on screen to explain it
	# over. While filming it goes, along with everything else.
	_banner.visible = not recording
	_replay_bar.visible = not recording


func exit_replay_mode(replay_available: bool) -> void:
	for node: Control in [_dock, _header_strip, _corner, _hints, _banner]:
		if node != null:
			node.visible = true
	_blueprints_button.visible = true
	# REMOVE CAR is left alone: _process puts it back the moment there is a car.
	_next_button.visible = _next_shown
	_replay_bar.visible = false
	set_replay_available(replay_available)


func report_video_saved() -> void:
	_show_banner("Video saved — check your browser's downloads", UITheme.ACCENT)


func report_video_failed(reason: String) -> void:
	_show_banner(reason, UITheme.MUSTARD)


## The dock spans the bottom edge, so the whole strait — both shores and the sky
## above them — is never covered by UI. Reading order runs left to right the way
## the turn does: who you are, what you can buy, what you own, what you do.
func _build_panel() -> Control:
	var panel := PanelContainer.new()
	# Painted boards rather than a cream slab: the dock carries the START and
	# SALVAGE SHOP signs, and a flat panel behind hand-painted artwork was the one
	# place the chrome and the art visibly disagreed. Two seams only — the signs
	# are the busy thing here and the plate under them must stay quiet.
	UITheme.paint(panel, PaintedBox.board(UITheme.WOOD, 2))
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = 10
	panel.offset_right = -10
	panel.offset_bottom = -10

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)
	# The row is centred, so START slides sideways whenever the belt gains or
	# loses a piece — and the dock, being full-width, never emits resized for it.
	# Following the row's own re-sort catches that as well as window resizes.
	row.sort_children.connect(_place_blueprints_button)
	row.sort_children.connect(_place_contextual)

	row.add_child(_build_shop_button())
	row.add_child(_build_piece_belt())
	row.add_child(_build_actions())
	return panel


## The belt is the dock's one elastic section: it takes whatever width the fixed
## controls leave, and the pieces sit at its left edge.
##
## No caption above it. The cards now carry a price as well as a count, and the
## row of them needed that height more than the belt needed a label naming the
## obvious. The locked state it used to announce is already on the cards
## themselves — every one of them greys out for the length of an attempt.
func _build_piece_belt() -> Control:
	_piece_belt = HBoxContainer.new()
	_piece_belt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_piece_belt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_piece_belt.add_theme_constant_override(&"separation", 6)
	return _piece_belt


## Level and money, pinned to the top-left corner rather than living in the dock.
##
## They are a readout, not a control — you glance at them and never click them —
## so they have no business taking width away from the row of things you *do*
## click. Up here they also sit against open sky, which is the emptiest part of
## the screen at every zoom level.
func _build_header() -> Control:
	# A dark bolted plate with the two figures side by side, and no logo.
	#
	# The mark was doing nothing here — the player knows what game they are in,
	# and at 44px it took more of the strip than either number it sat beside. The
	# plate went dark for the same reason: the numbers are the content, and a
	# bright yellow field behind them made the field the loudest thing instead.
	# Level and money now sit on one line, so the strip is half as tall.
	_header_strip = PanelContainer.new()
	UITheme.paint(_header_strip, PaintedBox.sign(UITheme.SLATE))
	_header_strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_header_strip.position = Vector2(12, 12)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_header_strip.add_child(row)

	_level_label = Label.new()
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level_label.add_theme_font_size_override(&"font_size", UITheme.FONT_SIZE_TITLE)
	_level_label.add_theme_color_override(&"font_color", UITheme.CREAM)
	row.add_child(_level_label)

	# A painted divider rather than a separator constant, so the two figures read
	# as two fields on one plate instead of one run-on string.
	var rule := ColorRect.new()
	rule.color = Color(UITheme.CREAM, 0.32)
	rule.custom_minimum_size = Vector2(2, 22)
	row.add_child(rule)

	_money_label = Label.new()
	_money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_money_label.add_theme_font_size_override(&"font_size", UITheme.FONT_SIZE_TITLE)
	# Coin gold, not the cream the level uses: money is the number that changes
	# and the one the shop is spending, so it gets the only colour on the plate.
	_money_label.add_theme_color_override(&"font_color", UITheme.GOLD)
	row.add_child(_money_label)

	var record_rule := ColorRect.new()
	record_rule.color = Color(UITheme.CREAM, 0.32)
	record_rule.custom_minimum_size = Vector2(2, 22)
	row.add_child(record_rule)

	# The level's standing, so the target is on screen while you build rather than
	# only in the banner after a run. Hidden until the level has been crossed
	# once — "BEST —" on a level nobody has solved is a field with nothing in it.
	_record_label = Label.new()
	_record_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_record_label.add_theme_font_size_override(&"font_size", UITheme.FONT_SIZE_TITLE)
	_record_label.add_theme_color_override(&"font_color", UITheme.CREAM)
	_record_label.tooltip_text = "Cheapest bridge that has crossed this level"
	row.add_child(_record_label)
	_record_rule = record_rule

	var bridge_rule := ColorRect.new()
	bridge_rule.color = Color(UITheme.CREAM, 0.32)
	bridge_rule.custom_minimum_size = Vector2(2, 22)
	row.add_child(bridge_rule)

	# What the bridge on screen is worth. The leaderboard ranks a crossing by the
	# price of the pieces that made it, so this is the player's own score sitting
	# beside the one they're chasing — without it they were aiming at BEST $N with
	# no reading of where they currently stood.
	_bridge_label = Label.new()
	_bridge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bridge_label.add_theme_font_size_override(&"font_size", UITheme.FONT_SIZE_TITLE)
	_bridge_label.add_theme_color_override(&"font_color", UITheme.CREAM)
	_bridge_label.tooltip_text = (
		"Total price of the pieces in the water — this is your score.\nCheaper is better."
	)
	row.add_child(_bridge_label)
	_bridge_rule = bridge_rule
	return _header_strip


## Show the level's best bridge, or hide the field if it has never been crossed.
func _update_record_label() -> void:
	if _record_label == null or _levels == null:
		return
	var best := _levels.bridge_record()
	# Priced, because the score IS a shop price now. "BEST 240" beside a money
	# readout showing $310 was two numbers in the same units pretending not to be.
	_record_label.text = "BEST $%d" % best if best >= 0 else ""
	_record_label.visible = best >= 0
	_record_rule.visible = best >= 0


## Price up what is in the water, using the same sum Main scores a crossing with.
## Iterates the placed counts rather than the belt rows, so a piece that came out
## of a box and has no card still counts toward the bridge.
func _update_bridge_label(counts: Dictionary[ObjectDef, int]) -> void:
	if _bridge_label == null:
		return
	var value := 0
	for def: ObjectDef in counts:
		value += def.price * counts[def]
	_bridge_label.text = "BRIDGE $%d" % value
	# An empty strait has no bridge to price, and a field reading $0 is a field
	# with nothing in it — same reason BEST hides on an uncrossed level.
	_bridge_label.visible = value > 0
	_bridge_rule.visible = value > 0
	# Green while the bridge on screen would beat the level's record. Cheaper is
	# better, so this says "you are winning" without a second number to compare.
	var best: int = _levels.bridge_record() if _levels != null else -1
	_bridge_label.add_theme_color_override(
		&"font_color",
		# GREEN_TEXT, not GREEN: the plate is dark, and the solid green is a fill
		# colour that all but disappears against it.
		UITheme.GREEN_TEXT if best >= 0 and value < best else UITheme.CREAM
	)


## Opposite corner to the level/money readout, in the other patch of open sky.
## It's a control rather than a readout, so it doesn't belong beside them — and
## it's needed rarely enough that it has no business in the dock.
func _build_settings_button() -> Control:
	# A painted sign from the kit, gear and word both drawn in. The plate it
	# replaces carried a music note because a glyph would have been the one thing
	# on screen that wasn't painted; the sign settles that by being painted.
	var settings_size := UITheme.kit_size("btn_settings", CORNER_HEIGHT)
	var button := UITheme.kit_button("btn_settings", CORNER_HEIGHT)
	button.tooltip_text = "Settings"

	# Anchored with explicit offsets rather than by setting `position` on a
	# right-anchored control: position is measured from the parent's top-left, so
	# the -12 that reads as "12px in from the right edge" actually put the button
	# 12px off the left of the screen. Offsets against the right anchor are the
	# only form that means what it looks like it means.
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.offset_right = -SETTINGS_MARGIN
	button.offset_left = -SETTINGS_MARGIN - settings_size.x
	button.offset_top = SETTINGS_MARGIN + BAR_DROP
	button.offset_bottom = SETTINGS_MARGIN + BAR_DROP + settings_size.y
	button.pressed.connect(func() -> void:
		_confirm_overlay = UITheme.settings(_dock.get_parent())
	)

	# LEVELS sits immediately left of it, on the same plate and the same line.
	# Changing strait used to be reachable only from the panel that appears after
	# a crossing, which meant the one player who most wants out — somebody stuck
	# on a level they cannot solve — was the one player with no way to leave.
	var select_size := UITheme.kit_size("btn_level_selection", CORNER_HEIGHT)
	var levels := UITheme.kit_button("btn_level_selection", CORNER_HEIGHT)
	levels.tooltip_text = "Choose another strait"
	levels.anchor_left = 1.0
	levels.anchor_right = 1.0
	levels.offset_right = -SETTINGS_MARGIN - settings_size.x - CORNER_GAP
	levels.offset_left = levels.offset_right - select_size.x
	levels.offset_top = SETTINGS_MARGIN + BAR_DROP
	levels.offset_bottom = SETTINGS_MARGIN + BAR_DROP + select_size.y
	levels.pressed.connect(func() -> void: level_select_requested.emit())

	# SCORES, left of LEVELS. The board used to exist in exactly two places: the
	# panel that appears the moment you cross — which is also the moment you are
	# least interested in reading a table — and the level select screen, which
	# means leaving the strait to look at it. The number the board ranks is the
	# price of the bridge you are building right now, so it wants to be readable
	# while you are building it.
	var scores_size := UITheme.kit_size("btn_leaderboard", SCORES_HEIGHT)
	var scores := UITheme.kit_button("btn_leaderboard", SCORES_HEIGHT)
	scores.tooltip_text = "This strait's leaderboard"
	scores.anchor_left = 1.0
	scores.anchor_right = 1.0
	scores.offset_right = levels.offset_left - CORNER_GAP
	scores.offset_left = scores.offset_right - scores_size.x
	# Hung from the window's own margin, and the two plain bars are dropped by
	# BAR_DROP to line up with THIS one's bar — the shield makes this sprite
	# taller and puts its bar lower than a top-aligned bar would sit.
	scores.offset_top = SETTINGS_MARGIN
	scores.offset_bottom = SETTINGS_MARGIN + scores_size.y
	scores.pressed.connect(_open_scoreboard)

	# All three returned as one node, since the caller adds a single child.
	var corner := Control.new()
	corner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corner.add_child(button)
	corner.add_child(levels)
	corner.add_child(scores)
	return corner


## The current strait's leaderboard, on demand.
##
## Built from the same section as the crossing panel and the select screen, so
## there is one board in the game with one idea of what an empty one means. It
## never posts — there is no crossing in hand to post — it only reads.
func _open_scoreboard() -> void:
	var parts := UITheme.modal(
		_dock.get_parent(), _levels.level.display_name.to_upper(), 380.0
	)
	_confirm_overlay = parts[0] as Control
	var content := parts[1] as VBoxContainer

	if Leaderboard.has_board(_levels.index):
		UITheme.refresh_online_board(
			UITheme.online_board_section(content, _boards, _levels.index),
			_boards,
			_levels.index
		)
	else:
		var none := Label.new()
		none.text = "Leaderboard unavailable."
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.add_theme_color_override(&"font_color", UITheme.SUBTLE_TEXT)
		content.add_child(none)

	UITheme.enliven(_confirm_overlay)


## A frame-rate readout, off by default and toggled with F3.
##
## Added because "it feels laggy" and "it runs at 22fps" are different reports,
## and only the second one can be acted on. It costs one label and one string a
## second while it is showing, and nothing at all while it is not.
func _build_meter() -> Control:
	_meter = Label.new()
	_meter.visible = false
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.anchor_left = 1.0
	_meter.anchor_right = 1.0
	_meter.offset_left = -140.0
	_meter.offset_right = -12.0
	_meter.offset_top = SETTINGS_MARGIN + SCORES_HEIGHT + 6.0
	_meter.offset_bottom = _meter.offset_top + 20.0
	_meter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_meter.add_theme_font_size_override(&"font_size", UITheme.FONT_SIZE_SMALL)
	_meter.add_theme_color_override(&"font_color", UITheme.CREAM)
	UITheme.outline(_meter, 4)
	return _meter


func toggle_meter() -> void:
	if _meter != null:
		_meter.visible = not _meter.visible


## Dock art is sized to the space that already existed rather than the other way
## round: the signs shrink to fit a 102px dock instead of the dock growing to
## suit them, so the play area is unchanged.
const DOCK_ART_HEIGHT := 66.0


func _build_shop_button() -> BaseButton:
	var button := UITheme.art_button("salvage_shop", DOCK_ART_HEIGHT)
	button.tooltip_text = "Salvage Shop — buy pieces"
	button.pressed.connect(func() -> void: _shop_menu.open_menu())
	_shop_button = button
	return button


## The right end of the dock: recall, the two contextual buttons, and START.
## Recall sits immediately after the belt because it undoes what the belt does.
func _build_actions() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)

	# The placed count sits under Recall All rather than on START. It describes
	# the bridge, and Recall All is the button that acts on the bridge — next to
	# START it read as a caption for the crossing instead.
	var recall_column := VBoxContainer.new()
	recall_column.alignment = BoxContainer.ALIGNMENT_CENTER
	recall_column.add_theme_constant_override(&"separation", 1)
	row.add_child(recall_column)

	var recall := UITheme.art_button("recall_all", DOCK_ART_HEIGHT - 14.0)
	recall.tooltip_text = "Recall every placed piece back to your stock"
	recall.pressed.connect(_on_recall_pressed)
	recall_column.add_child(recall)
	_recall_button = recall

	_placed_label = Label.new()
	_placed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placed_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.as_caption(_placed_label)
	recall_column.add_child(_placed_label)

	# The truck picker, on experimental builds only. Beside the contextual slot
	# rather than next to START: it decides what START sends, which is a thing you
	# set once and then forget, not part of the press itself.
	if Experimental.on():
		_truck_button = UITheme.plate_button("DIESEL", UITheme.STEEL.darkened(0.34), Vector2(104, 0))
		_truck_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_truck_button.pressed.connect(_on_truck_pressed)
		row.add_child(_truck_button)

	# REMOVE CAR and NEXT CROSSING used to live here, in a slot of their own
	# between the belt and START. They are on the strait now, centred above the
	# dock — see _build_contextual(). Taking them out of the row also stops START
	# sliding sideways every time one of them appears.

	# The START slot is three layers in a plain Control, because the fill has to
	# go BEHIND the sign and a TextureButton draws its own texture before its
	# children — anything parented to the button would land on top of it.
	#
	#   1. the lettering, tinted green, clipped to progress   <- bottom
	#   2. the sign, with the lettering punched out of it
	#
	# Green therefore shows only through the letter holes. It cannot leak onto
	# the wood or past the plank's edge, because layer 1 is empty everywhere the
	# lettering isn't.
	_start_button = UITheme.art_button("start_crossing", DOCK_ART_HEIGHT, 190.0)
	_start_button.pressed.connect(func() -> void: start_crossing_requested.emit())
	_sign_idle = (_start_button as TextureButton).texture_normal
	_sign_running = load(UITheme.ART_DIR + "crossing.png") as Texture2D

	var slot := Control.new()
	# Wide enough for the running sign too, which is a longer plank than the
	# idle one — the slot must not resize when the texture swaps mid-crossing.
	slot.custom_minimum_size = Vector2(
		maxf(_start_button.custom_minimum_size.x, DOCK_ART_HEIGHT * 2.21),
		_start_button.custom_minimum_size.y
	)
	row.add_child(slot)
	_start_slot = slot

	_start_fill_clip = Control.new()
	_start_fill_clip.clip_contents = true
	_start_fill_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_start_fill_clip.visible = false
	slot.add_child(_start_fill_clip)

	_start_fill = UITheme.art_overlay("crossing_letters")
	_start_fill.modulate = CHARGE_TINT
	_start_fill_clip.add_child(_start_fill)

	_start_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.add_child(_start_button)
	return row


## EXPERIMENTAL — the battery truck and the rope.
##
## Everything from here to the end of this block is built only when
## Experimental.on(). It is deliberately additive: nothing above it changes shape
## on a normal build, so deleting this block and the flag is all it takes to drop
## either idea if it doesn't work out.


## For the headless check, which has to be able to prove the picker ISN'T there
## on a normal build.
func truck_button() -> Button:
	return _truck_button


func _on_truck_pressed() -> void:
	if _upgrades == null or build_locked or _crossing.is_running:
		return
	truck_type_requested.emit(
		CrossingManager.Truck.DIESEL
		if _upgrades.truck_type == CrossingManager.Truck.BATTERY
		else CrossingManager.Truck.BATTERY
	)


func _refresh_truck_button() -> void:
	if _truck_button == null or _upgrades == null:
		return
	var electric: bool = _upgrades.truck_type == CrossingManager.Truck.BATTERY
	_truck_button.text = "BATTERY" if electric else "DIESEL"
	_truck_button.tooltip_text = (
		"Battery truck — %d charge, %d per dunk. Click for the diesel."
		% [int(_upgrades.capacity()), roundi(_upgrades.splash_drain())]
		if electric else
		"Diesel truck — no charge to run out. Click for the battery one."
	)
	UITheme.repaint_plate(
		_truck_button, UITheme.ACCENT if electric else UITheme.STEEL.darkened(0.34)
	)


## The charge readout, under the level/money strip in the top-left. Only up while
## an electric truck is actually out on the strait — between attempts there is no
## charge to report, and a bar sitting at full is a bar nobody reads.
func _build_battery_gauge() -> Control:
	var panel := PanelContainer.new()
	UITheme.paint(panel, PaintedBox.sign(UITheme.SLATE))
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(12, 64)
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	panel.add_child(row)

	var label := Label.new()
	label.text = "CHARGE"
	UITheme.as_caption(label)
	row.add_child(label)

	_battery_bar = ProgressBar.new()
	_battery_bar.custom_minimum_size = Vector2(120, 14)
	_battery_bar.show_percentage = false
	_battery_bar.min_value = 0.0
	_battery_bar.max_value = 1.0
	row.add_child(_battery_bar)

	_battery_panel = panel
	return panel


## Green down to a quarter, then red — the point where the run stops being about
## the bridge and starts being about whether the truck gets there at all.
func _update_battery_gauge() -> void:
	if _battery_panel == null:
		return
	var car: Car = _crossing.car
	var live := is_instance_valid(car) and car.battery != null
	if live != _battery_panel.visible:
		_battery_panel.visible = live
	if not live:
		return
	var fraction := car.battery.fraction()
	_battery_bar.value = fraction
	_battery_bar.modulate = Color.WHITE if fraction > 0.25 else Color(1.0, 0.55, 0.5)


## ROPE, on the same strip as SAVED BUILDS and REPLAY. A toggle, not a purchase:
## arming it turns the next two clicks into a rope, and the price depends on how
## far apart those two clicks land.
func _build_rope_tab() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 2)
	column.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	# Clear of the charge gauge above it, which is painted and has a border of its
	# own — at 104 the two plates touched while a battery truck was out.
	column.position = Vector2(12, 118)

	# Still a plate: there is no rope sign in the kit, and this one is a toggle
	# whose colour carries its armed state, which painted art cannot do.
	_rope_button = UITheme.plate_button(
		"ROPE", UITheme.ACCENT.darkened(0.42), Vector2(76.0, 24.0)
	)
	_rope_button.add_theme_font_size_override(&"font_size", UITheme.FONT_SIZE_SMALL)
	_rope_button.pressed.connect(_on_rope_pressed)
	column.add_child(_rope_button)

	_rope_label = Label.new()
	UITheme.as_caption(_rope_label)
	column.add_child(_rope_label)
	return column


func _on_rope_pressed() -> void:
	if _ropes == null or build_locked:
		return
	_ropes.arming = not _ropes.arming
	_refresh_rope_tab()


func _refresh_rope_tab() -> void:
	if _rope_button == null or _ropes == null:
		return
	var armed := _ropes.arming
	_rope_button.text = "TYING" if armed else "ROPE"
	UITheme.repaint_plate(
		_rope_button, UITheme.GREEN if armed else UITheme.ACCENT.darkened(0.42)
	)
	_rope_button.disabled = build_locked
	_rope_shown = _ropes.count()
	_rope_limit_shown = _ropes.limit()
	_rope_label.text = "%d / %d ropes" % [_rope_shown, _rope_limit_shown]
	_rope_button.tooltip_text = (
		"Click two pieces to tie them together — $%.2f per unit of rope, right-click to cut one"
		% RopeManager.COST_PER_UNIT
	)


## The saved-layouts panel: three slots, each with a SAVE and a LOAD.
##
## A modal rather than three more buttons in the dock, because it is used at the
## edges of a session — before trying something drastic, and after it went wrong —
## and the dock's width belongs to the belt.
func _open_blueprints() -> void:
	if is_instance_valid(_blueprints_panel):
		return
	var built := UITheme.modal(_dock.get_parent(), "SAVED BUILDS", 420.0)
	var overlay := built[0] as Control
	var content := built[1] as VBoxContainer
	_blueprints_panel = overlay
	_confirm_overlay = overlay
	_blueprint_rows.clear()

	var blurb := Label.new()
	blurb.text = (
		"A slot remembers where your pieces were — nothing else.\n"
		+ "Loading one recalls everything first, then rebuilds from your stock."
	)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.as_heading(blurb)
	content.add_child(blurb)

	for i in Blueprints.SLOTS:
		content.add_child(_build_blueprint_row(i))

	UITheme.enliven(overlay)
	_refresh_blueprints()


func _build_blueprint_row(index: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)

	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	var save := UITheme.plate_button("SAVE", UITheme.ACCENT.darkened(0.42), Vector2(84, 34))
	save.pressed.connect(func() -> void: _on_save_slot_pressed(index))
	row.add_child(save)

	var load_button := UITheme.plate_button("LOAD", UITheme.GREEN, Vector2(84, 34))
	load_button.pressed.connect(func() -> void: _on_load_slot_pressed(index))
	row.add_child(load_button)

	# Each row knows how to redraw itself, so a save updates one line instead of
	# rebuilding the modal out from under the pointer.
	_blueprint_rows.append(func() -> void:
		var n := _blueprints.piece_count(index)
		var mine: bool = _blueprints.level_of(index) == _levels.index
		if n <= 0:
			label.text = "Slot %d — empty" % (index + 1)
			label.add_theme_color_override(&"font_color", UITheme.MUTE_TEXT)
		elif not mine:
			label.text = "Slot %d — from another strait" % (index + 1)
			label.add_theme_color_override(&"font_color", UITheme.MUTE_TEXT)
		else:
			label.text = "Slot %d — %d piece%s" % [index + 1, n, "" if n == 1 else "s"]
			label.add_theme_color_override(&"font_color", UITheme.INK)
		save.text = "SAVE" if n <= 0 else "OVERWRITE"
		# Saving an empty strait would spend a slot on nothing, and loading during
		# an attempt would drop a bridge under a moving car.
		save.disabled = build_locked or _spawner.count() <= 0
		load_button.disabled = build_locked or n <= 0 or not mine
	)
	return row


## The panel can go away without going through _close_blueprints() — Escape, the
## CLOSE button and a click on the dim all free the overlay directly — so the row
## callbacks are dropped here rather than at each of those exits.
func _refresh_blueprints() -> void:
	if not is_instance_valid(_blueprints_panel):
		_blueprints_panel = null
		_blueprint_rows.clear()
		return
	for redraw: Callable in _blueprint_rows:
		redraw.call()


func _on_save_slot_pressed(index: int) -> void:
	if _blueprints.is_empty(index):
		save_blueprint_requested.emit(index)
		_refresh_blueprints()
		return
	# Overwriting is the one irreversible thing in this panel — the layout it
	# replaces cannot be got back — so it is the one thing that asks.
	_confirm_overlay = UITheme.confirm(
		_dock.get_parent(),
		"Overwrite slot %d?\nIt holds %d pieces." % [
			index + 1, _blueprints.piece_count(index)
		],
		"OVERWRITE",
		func() -> void:
			save_blueprint_requested.emit(index)
			_refresh_blueprints()
			_confirm_overlay = _blueprints_panel
	)


## Loading throws away whatever is currently arranged, so it asks first — the
## same reason Recall All does, and it is the same loss.
func _on_load_slot_pressed(index: int) -> void:
	var placed: int = _spawner.count()
	if placed <= 0:
		_close_blueprints()
		load_blueprint_requested.emit(index)
		return
	_confirm_overlay = UITheme.confirm(
		_dock.get_parent(),
		"Load slot %d?\nThe %d pieces in the water go back to stock first." % [
			index + 1, placed
		],
		"LOAD BUILD",
		func() -> void:
			_close_blueprints()
			load_blueprint_requested.emit(index)
	)


func _close_blueprints() -> void:
	if is_instance_valid(_blueprints_panel):
		_blueprints_panel.queue_free()
	_blueprints_panel = null
	_blueprint_rows.clear()


func report_blueprint_saved(index: int, pieces: int) -> void:
	_show_banner(
		"Saved %d pieces to slot %d" % [pieces, index + 1], UITheme.ACCENT
	)


func report_bulk_placed(def: ObjectDef, placed: int) -> void:
	_show_banner(
		"Dropped %d %s into the strait" % [placed, def.display_name.to_lower()],
		UITheme.ACCENT
	)
	_refresh_placed()


## Main filed the bridge that just crossed into a slot on the player's behalf.
##
## No banner: the crossing's own banner is going up in the same frame and would
## be overwritten by this, which is the less important of the two messages. It is
## reported on the crossing panel instead, where the player is already looking.
func report_build_autosaved(index: int, pieces: int) -> void:
	_autosaved_slot = index
	_autosaved_pieces = pieces
	_refresh_blueprints()


func report_blueprint_loaded(index: int, placed: int, wanted: int) -> void:
	if placed < wanted:
		_show_banner(
			"Loaded slot %d — %d of %d pieces (the rest aren't in stock)" % [
				index + 1, placed, wanted
			],
			UITheme.MUSTARD
		)
	else:
		_show_banner("Loaded slot %d — %d pieces" % [index + 1, placed], UITheme.ACCENT)
	_refresh_placed()


## One quiet line riding just above the dock. It sits on the water rather than
## inside the panel, so it costs the dock no height at all.
func _build_hints() -> Control:
	var label := Label.new()
	label.text = "Q/E rotate  ·  F flips  ·  wheel zoom" \
		+ "  ·  right-click recalls a piece" \
		+ "  ·  shift-click a card drops the whole stack"
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Clipped rather than wrapped: on a narrow window a second line of hints would
	# climb the strait.
	label.offset_left = 12.0
	label.offset_right = -12.0
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", UITheme.FONT_SIZE_SMALL)
	label.add_theme_color_override(&"font_color", UITheme.CREAM)
	UITheme.outline(label, 4)
	return label


func _build_banner() -> Control:
	_banner = Label.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_top = 26.0
	# Two lines' worth: a result that set a distance record says so underneath.
	_banner.offset_bottom = 108.0
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_theme_font_size_override(&"font_size", 22)
	# The banner sits over sky and water, so it carries its own outline — the
	# only text in the game that isn't on a cream panel.
	UITheme.outline(_banner, 6)
	_banner.text = ""
	return _banner


## Runs the first-run walkthrough. Started by Main, and only on a brand new run.
##
## It lives inside the HUD's own root rather than on its own layer so it inherits
## the theme and sits above the dock automatically, and so the controls it points
## at are siblings whose rects it can just read.
func start_tutorial() -> void:
	var tutorial := Tutorial.new()
	# Named so _tutorial_running() can find it. The walkthrough already points at
	# the shop, and the nudge must not talk over it.
	tutorial.name = "Tutorial"
	_root.add_child(tutorial)
	tutorial.begin(self)


## The control a walkthrough card points at. Names rather than node paths,
## because the dock is built in code and its shape is not a tree the tutorial
## should have to know.
func tutorial_anchor(key: String) -> Control:
	match key:
		"shop": return _shop_button
		"belt": return _piece_belt
		"recall": return _recall_button
		"start": return _start_button
		"header": return _header_strip
		_: return null


## Every piece that can reach your inventory this level gets a row, including
## ones only a booster can produce — otherwise a Gold Booster would pay out something
## with nowhere to click.
func _on_level_loaded(level: LevelDef, index: int) -> void:
	for child: Node in _piece_belt.get_children():
		child.free()
	_piece_rows.clear()

	# "1 — The Narrows" is twice as wide as the header strip can hold, and the
	# name is decoration — the number is the thing you check. Full name on hover.
	_level_label.text = "LVL %d" % (index + 1)
	_update_record_label()
	_header_strip.tooltip_text = level.display_name
	_next_button.visible = false
	_banner.text = ""
	_shop_menu.stock_for_level(level)

	for def: ObjectDef in _placeable_defs(level):
		_piece_belt.add_child(_build_piece_card(def))
	# The belt and the shop's cards are rebuilt per level, so they need the hover
	# motion attaching again — enliven() skips anything that already has it.
	UITheme.enliven(_piece_belt)

	_on_money_changed(_economy.money)
	# The cards were just rebuilt, so the badges have nothing cached to compare to.
	_placed_shown = -1
	_refresh_pieces()


## One belt card: the sprite, a short name under it, and the owned count in the
## corner. The sprite does the identifying — a player recognises the girder they
## want by its shape long before they read the word.
func _build_piece_card(def: ObjectDef) -> Control:
	# The painted blank plate is the card; the piece's own sprite goes on top.
	# min_width pads the slot a little wider than the plate so the short name
	# underneath has somewhere to sit without crowding the plate's edge.
	var button := UITheme.art_button("piece_blank", CARD_SIZE, CARD_SIZE + 10.0)
	button.tooltip_text = "%s — %s\nShift-click to drop every one you own" % [
		def.display_name, def.descriptor()
	]
	# Shift places the whole stack at once. Read off the keyboard here rather than
	# from a gui_input handler: `pressed` is what the button, its click sound and
	# its hover motion are already wired to, and duplicating that plumbing to
	# recover one modifier would mean two paths into placing a piece.
	button.pressed.connect(func() -> void:
		if Input.is_key_pressed(KEY_SHIFT):
			place_all_requested.emit(def)
		else:
			place_requested.emit(def)
	)
	# Taking a piece out of stock is handling a piece, not pressing a menu
	# button, and it sounds like the one you get when you grab a piece already
	# in the water — which is the same action from the other direction.
	UITheme.set_click_sound(button, &"piece_click")

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 0)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	button.add_child(column)

	var icon := TextureRect.new()
	icon.texture = def.get_texture(0)
	icon.custom_minimum_size = Vector2(0, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon.texture == null:
		icon.modulate = def.color
	column.add_child(icon)

	var name_label := Label.new()
	name_label.text = _short_name(def.display_name)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Backstop for the next long name somebody adds. The card is a fixed 62px and
	# the label is centred inside it, so an oversized name does not shorten — it
	# prints straight across the cards on either side. _short_name() handles the
	# ones that exist; this makes sure the belt can never break that way again.
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override(&"font_size", UITheme.FONT_SIZE_SMALL)
	column.add_child(name_label)

	# How many of this piece are in the water, and the button that brings them all
	# back — one control, because on a card this size there is no room for both and
	# they say the same thing from two sides: "3 of these are out there" is exactly
	# what you need to know to decide whether to press "bring them back".
	#
	# It sits in a strip *under* the plate rather than on it. On the plate it lay
	# across the piece's name, and hiding the name to make room meant the belt went
	# unlabelled precisely when the most pieces were in play. The strip keeps its
	# height whether or not a bar is showing, so the dock never changes shape.
	#
	# Blue, not the dock's amber: on wood-and-mustard chrome an amber pill read as
	# part of the card's own decoration, and players were not seeing it as a button
	# at all. It is the only blue in the dock, and it means the same thing in each
	# place it appears.
	var recall_strip := _card_pill_strip(UITheme.ACCENT)
	var recall: Button = recall_strip[&"button"]
	recall.visible = false
	recall.pressed.connect(func() -> void: _on_recall_type_pressed(def))
	UITheme.set_click_sound(recall, &"piece_click")

	# And the other direction: one more of this piece, without opening the shop.
	# Buying was the most repeated action in a build and the only one that needed a
	# modal to reach. Mustard, the shop's own buy colour, so spending money looks
	# the same wherever you do it — and never blue, which in this dock means recall.
	var buy_strip := _card_pill_strip(UITheme.MUSTARD)
	var buy: Button = buy_strip[&"button"]
	buy.pressed.connect(func() -> void: buy_requested.emit(def))

	# The count is an ink pill in the top-right rather than a line of the card,
	# so a row of cards reads as sprites first and numbers second.
	var count := Label.new()
	count.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	count.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	count.position = Vector2(-4, 3)
	count.custom_minimum_size = Vector2(22, 18)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.add_theme_font_size_override(&"font_size", UITheme.FONT_SIZE_SMALL)
	count.add_theme_stylebox_override(&"normal", UITheme.pill(UITheme.INK))
	button.add_child(count)

	_piece_rows[def] = {
		&"button": button, &"count": count, &"name": name_label,
		&"recall": recall, &"buy": buy
	}

	# The card is the plate with its two strips beneath, price first: buying is the
	# one that is always available and always says something, so it sits against
	# the plate, and the recall bar — which only exists while pieces are out — hangs
	# below it rather than shoving it around as it comes and goes. Returned as one
	# column so the belt still lays out one child per piece.
	var card := VBoxContainer.new()
	card.add_theme_constant_override(&"separation", 2)
	card.add_child(button)
	card.add_child(buy_strip[&"strip"])
	card.add_child(recall_strip[&"strip"])
	return card


## One fixed-height slot under a belt card holding a single pill button.
##
## The slot keeps its height whether or not its button is showing, so the dock
## never changes shape as pieces come and go — and both strips are built the same
## way so the pair reads as two halves of one control rather than two widgets that
## happen to be stacked.
func _card_pill_strip(shade: Color) -> Dictionary:
	var strip := Control.new()
	strip.custom_minimum_size = Vector2(0, CARD_PILL_HEIGHT)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var button := Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override(&"font_size", UITheme.FONT_SIZE_SMALL)
	button.add_theme_constant_override(&"outline_size", 0)
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		var fill := shade
		if state == &"hover":
			fill = shade.lightened(0.18)
		elif state == &"pressed":
			fill = shade.darkened(0.2)
		elif state == &"disabled":
			fill = UITheme.MUTE
		button.add_theme_stylebox_override(state, UITheme.pill(fill))
	for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color"]:
		button.add_theme_color_override(state, UITheme.INK)
	button.add_theme_color_override(&"font_disabled_color", UITheme.MUTE_TEXT)
	strip.add_child(button)
	return {&"strip": strip, &"button": button}


## Bring every placed piece of one kind back to stock.
##
## Asks first, the same way Recall All does. The bar now sits at the bottom of a
## card whose top half is a plate you click to place and whose middle is a pill you
## click to buy — three targets in one column, all of them one click, and only this
## one throws away work that took minutes to arrange. There is no undo, so the
## prompt is the undo.
func _on_recall_type_pressed(def: ObjectDef) -> void:
	if build_locked:
		return
	var placed: int = _spawner.placed_counts().get(def, 0)
	if placed <= 0:
		return
	_confirm_overlay = UITheme.confirm(
		_dock.get_parent(),
		"Recall all %s?\nThey go back to your stock." % _counted(def, placed),
		"RECALL %d" % placed,
		func() -> void: _recall_type(def)
	)


## "3 wooden planks", "1 tire". Every piece name in the game takes a plain -s, so
## this stays a suffix rather than a table until one of them doesn't.
func _counted(def: ObjectDef, n: int) -> String:
	var noun := def.display_name.to_lower()
	return "%d %s" % [n, noun if n == 1 else noun + "s"]


func _recall_type(def: ObjectDef) -> void:
	# Re-checked rather than trusting the count the prompt was raised with: the
	# bridge is live physics and a piece can fall out of the world while the
	# question is on screen.
	if build_locked:
		return
	var recalled: int = _spawner.remove_all_of(def)
	if recalled <= 0:
		return
	_show_banner(
		"Recalled %s back to stock" % _counted(def, recalled), UITheme.MUSTARD
	)
	_refresh_placed()


## A belt card is 64px wide. The full name is still on the shop card and in the
## card's tooltip.
func _short_name(display_name: String) -> String:
	match display_name:
		"Wooden Plank": return "Plank"
		"Metal Beam": return "Beam"
		"Steel Girder": return "Girder"
		"Refrigerator": return "Fridge"
		# Two words at full size overran the 62px plate and printed across the
		# cards on either side of it — the labels are centred and unclipped, so a
		# long one does not truncate, it trespasses.
		"Shipping Container": return "Container"
		_: return display_name


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


func _process(delta: float) -> void:
	if _spawner == null:
		return

	# The piece count is polled, not read every frame. count() walks the whole
	# container, so at the 140 cap this was 140 node casts per rendered frame to
	# produce a label that changes when the player drops something — a few times a
	# minute. The poll below already existed for the per-type badges; the total now
	# rides the same 6 Hz cadence instead of running 10x more often beside it.
	#
	# Progress is told by the sign filling up, so putting a percentage here as well
	# would be saying the same thing twice, in the one place that is meant to
	# describe the bridge rather than the attempt.
	_placed_poll -= delta
	if _placed_poll <= 0.0:
		_placed_poll = 1.0 / PLACED_POLL_HZ
		var placed: int = _spawner.count()
		# The per-type badges are polled rather than driven by a signal, because
		# there is no "a piece was placed" signal to hang them off — a piece enters
		# the world through the spawner and reaches its resting place through
		# physics. Short-circuited when the total hasn't moved, so the common case
		# is an integer compare.
		if placed != _placed_shown or _belt_locked != build_locked:
			_placed_shown = placed
			_placed_label.text = (
				"%d piece placed" if placed == 1 else "%d pieces placed"
			) % placed
			_refresh_placed()
	# Nothing in the strait means there is nothing to test, and a run off the end of
	# the shore is just the car falling in the water — a result the player learns
	# nothing from and which still costs them the wait. The dock says so by going
	# dead rather than by refusing afterwards; Main still checks, because "placed"
	# and "actually reaching the water" are not the same thing.
	#
	# Reads the polled count rather than a fresh one, and only writes on a change:
	# setting `disabled` re-evaluates the button's style and setting tooltip_text
	# touches the tooltip cache, both every frame, for a value that is the same
	# from one minute to the next.
	var start_dead := _crossing.is_running or _placed_shown <= 0
	if start_dead != _start_button.disabled:
		_start_button.disabled = start_dead
		_start_button.tooltip_text = (
			"Put at least one piece in the water first" if _placed_shown <= 0 else ""
		)
	# The belt goes dead for the length of an attempt: you cannot add to a bridge
	# that is already being driven over. Driven from _process rather than from the
	# start/finish signals so it can never be left locked by a path that ends an
	# attempt without emitting one.
	# build_locked, not is_running: the belt has to stay dead through the linger
	# after the car stops, while the wreck is still on screen and the bridge has
	# not been put back yet. Main owns that window and sets the flag.
	if _belt_locked != build_locked:
		_belt_locked = build_locked
		_refresh_pieces()
		_refresh_blueprints()
	_update_charge(delta)
	_update_shop_nudge()
	_update_battery_gauge()
	# The rope tab tracks the build lock and the count. Compared as integers rather
	# than by formatting the label every frame — a rope is lost silently when the
	# piece it was tied to is recalled, so there is no signal to hang this on.
	if _rope_button != null and (
		_rope_button.disabled != build_locked
		or _ropes.count() != _rope_shown
		or _ropes.limit() != _rope_limit_shown
	):
		_refresh_rope_tab()
	var has_car := is_instance_valid(_crossing.car)
	if has_car != _remove_car_button.visible:
		_remove_car_button.visible = has_car

	# The dock's height follows its contents, and the contents change when the
	# contextual buttons appear, so the hint line is re-pinned rather than fixed.
	# Only when it actually moved: writing an offset queues a resort of the
	# control's anchors whether or not the number changed, and the dock's height
	# changes only when a contextual button appears.
	# Above the SAVED BUILDS tab, not level with it: the tab floats in this same
	# strip over the START end of the dock, and the hint line used to run straight
	# under it — one sentence with a button sitting in the middle of it.
	var pinned := -(
		_dock.size.y + BLUEPRINTS_GAP + maxf(_blueprints_size.y, _replay_size.y) + 8.0
	)
	if not is_equal_approx(pinned, _hints.offset_bottom):
		_hints.offset_bottom = pinned
		_hints.offset_top = pinned - 18.0

	# Worst frame in the last second, tracked every frame because that is the only
	# way to see it. Average fps hides exactly the thing being complained about: a
	# bridge that runs at 60 and stalls for 90ms when a save lands reads as "60fps".
	# One maxf per frame, and only while the meter is up.
	if _meter != null and _meter.visible:
		_worst_frame_ms = maxf(_worst_frame_ms, delta * 1000.0)

	# Once a second, not every frame: a number that changes sixty times a second
	# cannot be read, and formatting it that often is itself a cost.
	if _meter != null and _meter.visible:
		_meter_timer -= delta
		if _meter_timer <= 0.0:
			_meter_timer = 1.0
			_meter.text = _meter_text()
			_worst_frame_ms = 0.0

	if _banner_timer > 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0:
			_banner.text = ""


## The F3 readout. Two lines, because the useful question is never "what is the
## fps" — it is "which half is costing me", script or physics.
##
## worst is the number to watch while building: a hitch that lasts one frame does
## not move the average at all, and hitches are what a player actually feels.
## act/pairs answer whether the physics load is the bridge settling or the bridge
## having settled — a still bridge should be nearly all asleep.
func _meter_text() -> String:
	var process_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	return "%d fps · worst %.1fms · proc %.1f phys %.1f\n%d pieces · %d act · %d pairs · %d draws" % [
		Engine.get_frames_per_second(),
		_worst_frame_ms,
		process_ms,
		physics_ms,
		_spawner.count(),
		int(Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS)),
		int(Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
	]


## Escape backs out of a confirmation, matching the shop menu. It's consumed
## here so it can't also drop the window out of fullscreen on the way past.
func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(_confirm_overlay):
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_confirm_overlay.queue_free()
			get_viewport().set_input_as_handled()


## Drives the START button's fill from crossing progress.
##
## While a crossing runs the button becomes its own progress bar: the face darkens
## to a trough and a brighter green charges across it. Godot paints a disabled
## Button with the theme's grey `disabled` box regardless of any `normal`
## override, so the trough has to be set on that state — overriding `normal`
## alone leaves the button looking simply switched off.
func _update_charge(delta: float) -> void:
	var button := _start_button as TextureButton
	if not _crossing.is_running:
		if _start_fill_clip.visible:
			_start_fill_clip.visible = false
			button.texture_normal = _sign_idle
			_shown_progress = 0.0
		return

	if not _start_fill_clip.visible:
		_start_fill_clip.visible = true
		# The sign itself changes: "START CROSSING" is an instruction, and once
		# it has been followed the button reads simply "CROSSING".
		button.texture_normal = _sign_running
		_shown_progress = 0.0

	# Chases the real value instead of tracking it, so a car that gets flung
	# backwards drains the bar smoothly rather than snapping.
	_shown_progress = move_toward(
		_shown_progress, clampf(_crossing.progress, 0.0, 1.0), delta * 0.9
	)

	# The lettering layer is always laid out at the slot's full size, so it lines
	# up with the punched-out sign above it; only the clip that reveals it
	# changes width. Both use KEEP_ASPECT_CENTERED over the same rect, which is
	# what keeps the letters registered with their holes.
	var slot: Vector2 = _start_button.size
	_start_fill.position = Vector2.ZERO
	_start_fill.size = slot
	_start_fill_clip.position = Vector2.ZERO
	_start_fill_clip.size = Vector2(slot.x * _shown_progress, slot.y)


func _on_money_changed(_amount: int) -> void:
	_money_label.text = "$%d" % _economy.money
	# Affordability is per-card and every card has a price on it now, so the whole
	# belt changes state on any money movement, not just on a purchase.
	_refresh_buy()


## Price of the cheapest box this level sells, or 0 if it sells none.
func _cheapest_box_price() -> int:
	var level := _levels.level
	if level == null:
		return 0
	var cheapest := 0
	for box: BoxDef in level.boxes:
		if box != null and (cheapest == 0 or box.price < cheapest):
			cheapest = box.price
	return cheapest


## Points the player at the shop the first time they can afford to gamble.
##
## Playtesters were sitting on enough money for three boxes without opening the
## shop at all — the salvage sign is one painted object among several and reads as
## scenery until you have a reason to press it. Affording a box is that reason,
## and it is the moment the shop stops being a price list and starts being the way
## out of a bridge that doesn't reach.
##
## Deliberately NOT a modal. It appears while the player is building, and anything
## that steals the pointer or dims the strait at that moment would be worse than
## the problem it solves. It is a card beside the shop button that can be ignored
## indefinitely, taken up, or silenced for good.
func _update_shop_nudge() -> void:
	if _nudge_dismissed or _levels.level == null:
		return
	var price := _cheapest_box_price()
	if price <= 0:
		return

	var can_afford := _economy.money >= price
	# Not during an attempt, and not on top of the first-run walkthrough — both
	# are moments when the player is already being told where to look.
	var welcome: bool = not build_locked and not _crossing.is_running \
		and not _shop_menu.visible and not _tutorial_running()

	if can_afford and not _could_afford_box and welcome:
		_show_nudge(price)
	_could_afford_box = can_afford

	# Falling back below the price takes the card away again: the offer it is
	# making is no longer true, and a nudge that outlives its own reason is how a
	# hint becomes noise.
	if is_instance_valid(_nudge) and not can_afford:
		_dismiss_nudge()


func _tutorial_running() -> bool:
	return _root.has_node(^"Tutorial")


func _show_nudge(price: int) -> void:
	if is_instance_valid(_nudge):
		return

	var card := PanelContainer.new()
	UITheme.paint(card, PaintedBox.plate(UITheme.SLATE))
	# Anchored to the bottom-left, sitting directly above the salvage sign it is
	# talking about, so the card and its target are one object in the eye.
	card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	card.position = Vector2(14, -(_dock.size.y + 26.0))
	card.custom_minimum_size = Vector2(258, 0)
	_root.add_child(card)
	_nudge = card

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	card.add_child(column)

	var line := Label.new()
	line.text = "You can afford a Booster Pack ($%d).\nThe Salvage Shop is below." % price
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_color_override(&"font_color", UITheme.CREAM)
	UITheme.outline(line, 4)
	column.add_child(line)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	column.add_child(row)

	var open := UITheme.plate_button("OPEN SHOP", UITheme.GREEN, Vector2(0, 28))
	open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open.pressed.connect(func() -> void:
		_dismiss_nudge()
		_shop_menu.open_menu()
	)
	row.add_child(open)

	# "Don't show again" rather than a bare close, because a close button would
	# get pressed every time and teach the player nothing about how to be rid of
	# it. There is no plain dismiss: the card takes itself away as soon as the
	# money is spent, so the only reason to reach for a button here is to say
	# "never again".
	var never := UITheme.plate_button(
		"DON'T SHOW AGAIN", UITheme.STEEL.darkened(0.34), Vector2(0, 28)
	)
	never.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	never.pressed.connect(func() -> void:
		_nudge_dismissed = true
		Prefs.set_flag(NUDGE_PREF, true)
		_dismiss_nudge()
	)
	row.add_child(never)

	UITheme.enliven(card)


## For the smoke test, which has no eyes.
func nudge_visible() -> bool:
	return is_instance_valid(_nudge)


func _dismiss_nudge() -> void:
	if is_instance_valid(_nudge):
		_nudge.queue_free()
	_nudge = null


func _refresh_pieces() -> void:
	for def: ObjectDef in _piece_rows:
		var n := _inventory.count(def)
		var widgets: Dictionary = _piece_rows[def]
		var button: BaseButton = widgets[&"button"]
		button.disabled = n <= 0 or _belt_locked
		# Whether the card is dimmed is _refresh_placed()'s call, not this one's:
		# a card with none in stock but several in the water is still actionable
		# through its recall badge, and dimming it would say otherwise.
		# An owned-zero row stays in place rather than disappearing: the list
		# would otherwise reshuffle under the cursor on every purchase.
		var count: Label = widgets[&"count"]
		count.text = str(n)
		# The pill goes mustard-on-ink when you own some and flat grey when you
		# don't, so a full belt can be read at a glance without reading digits.
		count.add_theme_stylebox_override(
			&"normal", UITheme.pill(UITheme.INK if n > 0 else UITheme.MUTE)
		)
		count.add_theme_color_override(
			&"font_color", UITheme.MUSTARD if n > 0 else UITheme.MUTE_TEXT
		)
		var name_label: Label = widgets[&"name"]
		name_label.add_theme_color_override(
			&"font_color", UITheme.INK if n > 0 else UITheme.MUTE_TEXT
		)
	_refresh_buy()
	_refresh_placed()


## The price bar on every belt card. Unlike the placed counts above it, nothing
## here has to be polled — money, stock and the level's pool all announce
## themselves, so this runs only when one of them moves.
func _refresh_buy() -> void:
	var level := _levels.level
	for def: ObjectDef in _piece_rows:
		var buy: Button = _piece_rows[def][&"buy"]
		# A card exists for every piece the level can hand you, boxes included, and
		# a box's pool is not for sale at any price. Saying so on the card is the
		# only way the belt can explain a piece with no price.
		if level == null or not level.shop_pool.has(def):
			buy.text = "FROM BOX"
			buy.disabled = true
			buy.tooltip_text = "%s only comes out of a box" % def.display_name
			continue

		var left: int = _shop.remaining(def)
		if left <= 0:
			buy.text = "SOLD OUT"
			buy.disabled = true
			buy.tooltip_text = "%s is sold out this level" % def.display_name
			continue

		var affordable: bool = _economy.can_afford(def.price)
		# Same two words the shop menu uses for the same two states, so the belt is
		# not a second dialect of the one that taught them.
		buy.text = ("BUY $%d" if affordable else "NEED $%d") % def.price
		buy.disabled = not affordable or _belt_locked
		buy.tooltip_text = "Buy one %s — $%d · %d left this level" % [
			def.display_name.to_lower(), def.price, left
		]


## Updates the bottom-left badge on every belt card from what is actually in the
## strait. Locked for the length of an attempt, same as the rest of the belt.
func _refresh_placed() -> void:
	var counts: Dictionary[ObjectDef, int] = _spawner.placed_counts()
	_update_bridge_label(counts)
	for def: ObjectDef in _piece_rows:
		var widgets: Dictionary = _piece_rows[def]
		var recall: Button = widgets[&"recall"]
		var button: BaseButton = widgets[&"button"]
		var n: int = counts.get(def, 0)

		# TextureButton has no disabled stylebox to grey it out, so a card with
		# nothing to offer is dimmed directly. "Nothing to offer" means none in
		# stock AND none in the water — with pieces placed, the badge is live even
		# though the card itself can't be clicked.
		var live: bool = (_inventory.count(def) > 0 or n > 0) and not _belt_locked
		button.modulate = Color.WHITE if live else Color(1, 1, 1, 0.45)

		# The recall bar lives in its own strip under the card, not on it: sitting
		# inside the plate it covered the piece's name, and the fix of hiding the
		# name while pieces were out meant the belt lost its labels exactly when the
		# player was busiest. The strip is always there, so nothing in the dock moves
		# when a bar appears — only the bar itself comes and goes.
		recall.visible = n > 0
		if n <= 0:
			continue
		recall.text = "Recall %d" % n
		recall.disabled = build_locked
		recall.tooltip_text = "Recall %s back to your stock" % _counted(def, n)
	_refresh_blueprints()


## Recall All undoes an arrangement that can represent many minutes of fiddling,
## and it sits one button away from START, so it asks first. Nothing placed means
## nothing to lose, and it just does nothing rather than asking about it.
func _on_recall_pressed() -> void:
	var placed: int = _spawner.count()
	if placed <= 0:
		return
	_confirm_overlay = UITheme.confirm(
		_dock.get_parent(),
		"Recall all %d pieces?\nThey go back to your stock." % placed,
		"RECALL ALL",
		func() -> void: _spawner.clear_all()
	)


func _on_attempt_started() -> void:
	_banner.text = ""
	_banner_timer = 0.0


func report_crossing(
	result: int,
	progress: float,
	score: int,
	earned: int,
	bridge: int = 0,
	rank: int = 0,
	flat: bool = false
) -> void:
	var pct := roundi(progress * 100.0)
	# The record is the sentence the player is playing to hear, so it gets its own
	# line rather than being buried inside the money figure it contributed to.
	var record := ""
	if _economy.last_record_bonus > 0:
		record = "\nFURTHEST YET — record bonus $%d" % _economy.last_record_bonus
	match result:
		CrossingManager.Result.SUCCESS:
			# The banner still fires, because the panel can be dismissed and the
			# run's figures should not vanish with it.
			_update_record_label()
			_show_banner(
				"MADE IT ACROSS — score %d, earned $%d%s" % [score, earned, record],
				Color(0.55, 0.98, 0.55)
			)
			show_crossed_panel(bridge, rank, earned)
		CrossingManager.Result.DROWNED:
			_show_banner(
				"SANK at %d%% — score %d, earned $%d%s" % [pct, score, earned, record],
				Color(0.98, 0.6, 0.5)
			)
		_:
			# A truck that stopped because the charge ran out looks identical to one
			# that stopped because it was wedged, and the two call for opposite
			# fixes — a bigger battery against a better bridge.
			_show_banner(
				("FLAT BATTERY at %d%%" if flat else "STUCK at %d%%")
					% pct + " — score %d, earned $%d%s" % [score, earned, record],
				UITheme.MUSTARD
			)


## The crossing panel: what the bridge cost, where it stands, and the two things
## worth doing next.
##
## A panel rather than another banner line, because a success is the one moment
## the player has a decision to make — take the next strait, or stay and try to
## do this one cheaper. A banner cannot ask that, and the NEXT button on its own
## never said the second option existed.
func show_crossed_panel(bridge: int, rank: int, earned: int) -> void:
	var level_index := _levels.index
	# The last strait gets its heading and its closing lines folded INTO this
	# panel rather than a second card stacked on top of it. Two modals fired in
	# the same frame put the congratulations board over the scoreboard the player
	# had just earned a place on, and dismissing the top one left the bottom one
	# sitting there looking like it had failed to close.
	var finale := _levels.is_last()
	# No heading sign otherwise: the panel only appears on a crossing, so a line
	# reading STRAIT CROSSED tells the player what they just watched happen.
	var parts := UITheme.modal(
		_dock.get_parent(),
		"EVERY STRAIT CROSSED" if finale else "",
		420.0,
		"KEEP BUILDING",
		"btn_keep_building"
	)
	_confirm_overlay = parts[0] as Control
	var content := parts[1] as VBoxContainer

	if finale:
		var done := Label.new()
		done.text = "You got the truck across every strait."
		done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		done.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		done.add_theme_font_size_override(&"font_size", UITheme.FONT_SIZE_LOUD)
		content.add_child(done)

	# The money is the headline. What the bridge cost and where it places are on
	# the board below, where the number sits among the runs it is being ranked
	# against — saying "2nd place" above a board that already shows it in second
	# was the same fact twice.
	var money := Label.new()
	money.text = "Earned $%d" % earned
	money.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	money.add_theme_font_size_override(&"font_size", UITheme.FONT_SIZE_TITLE)
	money.add_theme_color_override(&"font_color", UITheme.GOLD.darkened(0.25))
	content.add_child(money)

	var cost := Label.new()
	cost.text = "Your bridge: $%d" % bridge
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.add_theme_color_override(&"font_color", UITheme.SUBTLE_TEXT)
	content.add_child(cost)

	# Where the bridge went, so the filing is something the player was told about
	# rather than something they find later. Silent when this crossing was dearer
	# than the one already in the slot — nothing was written, and saying so would
	# be a line about an event that didn't happen.
	if _autosaved_slot >= 0:
		var kept := Label.new()
		kept.text = "Saved to build slot %d (%d pieces)" % [
			_autosaved_slot + 1, _autosaved_pieces
		]
		kept.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kept.add_theme_font_size_override(&"font_size", UITheme.FONT_SIZE_SMALL)
		kept.add_theme_color_override(&"font_color", UITheme.ACCENT.darkened(0.3))
		content.add_child(kept)
		_autosaved_slot = -1

	_add_online_board(content, level_index, bridge)

	# Only offered when there is somewhere to go. On the last level the campaign
	# card takes over, and the panel is just the scoreboard.
	#
	# A painted signpost pointing right, which is where the next strait is. The
	# green plate it replaces was standing out by colour alone; the arrow says the
	# same thing by shape. Its wording is painted in, so the game calls this NEXT
	# CROSSING everywhere now rather than NEXT STRAIT.
	if not finale:
		var next := UITheme.kit_button("btn_next_crossing", 48.0)
		next.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		next.pressed.connect(func() -> void:
			_confirm_overlay.queue_free()
			next_level_requested.emit()
		)
		content.add_child(next)

	# Watching the crossing you just made is the thing people do with a crossing
	# they just made, and the panel is on screen the moment they want to. Only
	# when there is film — a crossing longer than the recorder's cap has none.
	if _replay_button != null and _replay_button.visible:
		# The painted sign carries its own camera, which is what the drawn icon was
		# doing here: breaking up a stack of buttons that were otherwise the same
		# plate with different words on it.
		var watch := UITheme.kit_button("btn_replay_save", 62.0)
		watch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		watch.tooltip_text = "Watch the attempt again, and download it as a video"
		watch.pressed.connect(func() -> void:
			_confirm_overlay.queue_free()
			replay_requested.emit(false)
		)
		content.add_child(watch)

	# The way off this panel that isn't "keep building". LEVEL SELECT used to sit
	# here too and is gone: the same control is on the corner rail behind this
	# panel, in every scene, and a second copy of it on the one panel that exists
	# to keep the run going was pointing at the door.
	var exits := HBoxContainer.new()
	exits.add_theme_constant_override(&"separation", 8)
	exits.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(exits)

	# Only at the end of the campaign. Mid-run the way out is the settings knob;
	# offering MAIN MENU after every crossing would put "stop playing" next to
	# "play the next one" on the panel that exists to keep the run going.
	if finale:
		var menu := UITheme.plate_button("MAIN MENU", UITheme.AMBER, Vector2(0, 38))
		menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		menu.pressed.connect(func() -> void:
			_confirm_overlay.queue_free()
			get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
		)
		exits.add_child(menu)


## The leaderboard, on the crossing panel: this strait, against everyone else.
##
## The only board there is now. There used to be a local table of your own past
## runs above it, which answered a different question — "is this my best bridge"
## — but asked the player to read two rankings of the same number and work out
## which one counted. The header still carries your record for the level, so the
## fact it provided has not gone anywhere.
##
## Nothing here is awaited by the panel. The section appears immediately, filled
## with whatever was cached, and the rows change under the player a moment later
## when the network answers.
func _add_online_board(content: VBoxContainer, level_index: int, bridge: int) -> void:
	if not Leaderboard.has_board(level_index):
		return

	# The callback is handed the table rather than closing over it: a lambda
	# captures by value, and at the moment this one is built the table does not
	# exist yet, so a captured reference would be null when it fired.
	var table := UITheme.online_board_section(
		content, _boards, level_index,
		func(box: VBoxContainer) -> void: _post_crossing(box, level_index, bridge)
	)

	if not Leaderboard.player_name().is_empty():
		_post_crossing(table, level_index, bridge)
		return

	# First crossing, no name yet. Ask for one — this is the moment the player has
	# something worth putting a name on, and a board of strangers' initials with
	# no way onto it is a worse introduction than a three-character question.
	#
	# Deferred so the prompt lands ON the result panel rather than racing it into
	# the same frame, and so the board behind it is already drawing.
	UITheme.refresh_online_board(table, _boards, level_index)
	_ask_initials.call_deferred(table, level_index, bridge)


## The one-time initials prompt, over the crossing panel.
##
## Declining is a real answer and costs nothing: the name field on the board
## itself is still there, so a player who says "not now" can put their initials
## in whenever they like, and will not be asked again by any crossing after this
## one — the prompt is gated on the name being empty, not on a "seen it" flag.
func _ask_initials(table: VBoxContainer, level_index: int, bridge: int) -> void:
	if not is_instance_valid(table):
		return
	UITheme.initials_prompt(_dock.get_parent(), func(initials: String) -> void:
		if initials.is_empty() or not is_instance_valid(table):
			return
		Leaderboard.set_player_name(initials)
		# The board's own field was built while the name was still empty.
		UITheme.sync_board_name(table)
		_post_crossing(table, level_index, bridge)
	)


## Send this crossing, then show the board it landed in.
##
## Sequential rather than parallel: fetching while the entry is still in flight
## reads the board without it, and the one row the player is looking for is
## their own.
func _post_crossing(table: VBoxContainer, level_index: int, bridge: int) -> void:
	UITheme.draw_online_board(table, _boards, level_index, "Posting…")
	await _boards.submit(level_index, bridge)
	if not is_instance_valid(table):
		return
	UITheme.refresh_online_board(table, _boards, level_index)


func offer_next_level() -> void:
	_next_button.visible = true


## The end of the game, for now. A card rather than a banner — see
## UITheme.congratulations().
func report_campaign_finished() -> void:
	_confirm_overlay = UITheme.congratulations(
		_dock.get_parent(),
		[
			"You got the truck across every strait.",
			"Best crossing score: %d" % _economy.best_score,
			"Money in hand: $%d" % _economy.money,
			"More water to come.",
		],
		func() -> void: get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
	)


func report_no_bridge() -> void:
	_show_banner("Build something first — drop a piece in the water", UITheme.MUSTARD)


func report_blocked() -> void:
	_show_banner("No room there — the piece won't fit", Color(0.98, 0.6, 0.5))


## The same banner, for a refusal that can say what it was. Used by the rope,
## whose reasons are all different from each other.
func report_blocked_reason(reason: String) -> void:
	_show_banner(reason, UITheme.MUSTARD)


func _show_banner(text: String, color: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override(&"font_color", color)
	_banner_timer = BANNER_HOLD
