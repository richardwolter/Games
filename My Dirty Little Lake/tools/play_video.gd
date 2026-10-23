extends Node
## The vertical gameplay short (2026-10-23, `/grill-me` with Richard): a staged lake that
## Richard plays himself while Godot's Movie Maker records it, one beat a take, then cut to
## 45-60 s with a song under it in `Marketing/My Dirty Little Lake/2 Work/gameplay_short/`.
##
## Two modes, one script:
##
##   STAGE (headless, run once, again whenever the staging below changes):
##     PLAY_VIDEO_STAGE=1 godot --headless --path . res://tools/play_video.tscn
##   Reads Richard's decorated house (`user://play_decor.save`, never written), dresses a
##   lake 40% cleaned around it and writes one save a beat, `tools/film/short/staged/`,
##   plus `tools/film/short/stage.log` (what moved, which pieces the house's stage 2 sends to
##   the shelf).
##
##   PLAY (desktop, Movie Maker at 30 fps): `tools/record_video.bat`, which asks for the beat,
##   writes a throwaway `override.cfg` (the movie's 1080x1920) and runs
##     PLAY_VIDEO_BEAT=<beat> godot --path . --fixed-fps 30 --write-movie <take>.avi
##         res://tools/play_video.tscn
##   F10 quits (and closes the take). The take's save is a copy (`staged/take.save`)
##   so a beat always starts the same.
##
## The beats, each starting where the last leaves off:
##   casts    the lake, the sculpture shining at the dirty edge. Cast 1 plain, cast 2 a forced
##            double, cast 3 at the sculpture. Then on through the rest if the take goes well.
##   wash     the sculpture waiting at the pump, the angler beside it.
##   house    washed: the house open on it, the stage-up still to play.
##   tornado  the sculpture placed and the rain falling, in the house: close the door.
## Wherever the take began, putting the sculpture down starts the storm, and the first door
## shut after that brings the tornado down.
##
## What the recording is dressed as (Richard's calls): the HUD off but the haul's count over
## the angler; every game pop-up off but the find card (hints, cue cards, the pigeon's head,
## the Strength line, the coins; the find card came back after the first cut); the house's key chips and hands off (`ShedRoom.quiet`); the shelf
## and the wash tray under their rooms (`ShedRoom.stacked`, `WashRoom.stacked`); the game's own
## wooden arrow drawn into the picture, since Movie Maker does not capture the real pointer;
## the Music bus muted (the song goes under the edit). Nothing here touches `settings.cfg`.

const Style := preload("res://scripts/style.gd")
const SOURCE := "user://play_decor.save"
const STAGING := "user://play_video_stage.save"
## The staged saves and the take's copy live in the project (tools/film/ is git-ignored and
## `.gdignore`d), not in user:// (2026-10-23): a take started from the Claude app runs inside
## its package, where AppData, and with it user://, is redirected to an empty folder.
const STAGED := "res://tools/film/short/staged/play_video_%s.save"
const TAKE := "res://tools/film/short/staged/take.save"
const LOG := "res://tools/film/short/stage.log"
const BEATS := ["casts", "wash", "house", "tornado"]
## **The picture is 1080x1920 whatever the window** (2026-10-23, Richard: the monitor does not
## pivot, a portrait desktop is a sideways one): the root draws at `FRAME` (`content_scale_mode`
## viewport) and is shown scaled down in a portrait window as tall as the screen allows, and
## Movie Maker records the root. The lake lives in a SubViewport the same size whose 2D is
## `CANVAS` stretched to fill it, the vertical trailer's 720x1280 at 1.5, so every zoom stop,
## board and pixel snap is the one the game draws at that stretch.
const FRAME := Vector2i(1080, 1920)
const CANVAS := Vector2i(720, 1280)

## How much of the lake is cleaned: the meter's share left.
const LEFT := 0.6
## The cleaned water's front: distance from the island, bent by a slow noise this many tiles
## either way, so the bays are big and lobed rather than a ring.
const FRONT_WOBBLE := 12.0
const FRONT_NOISE := 0.06
const FRONT_SEED := 23
## The middle of the run (Richard's pick off the schedule; Strength 3 rather than 2 because the
## sculpture is tier 3 and the net has to lift it).
const LEVELS := {
	"net_width": 8, "net_strength": 3, "net_range": 10, "reel": 8, "net_hold": 4,
	"boat_speed": 6, "cargo": 4, "boat_volley": 1, "fleet": 2,
	"dog_fetch": 2, "dog_wait": 1, "dog_strength": 2, "dog_count": 3,
	"recycle_bonus": 2, "bird_worth": 2, "lucky_haul": 0, "double_cast": 0,
}
const HOSE := 2
## Finds waiting on the house's shelf beside the sculpture (Richard, first cut: "some
## furniture sitting waiting to be put ... to represent variety"): second copies of pieces
## already in the room, so nothing in it moves.
## The find card's middle, a share of the frame's height: over the bottom quarter a phone's feed
## draws its caption.
const FIND_CARD_AT := 0.64
const SHELF_EXTRA := ["decor_pk_armchair", "decor_pk_globe", "decor_pk_bonsai", "decor_pk_table_lamp"]
## The house's stage at 40% cleaned (`Lake.SHED_STAGE_AT`).
const HOUSE_STAGE := 2
const SCULPTURE := "decor_pk_sculpture"
## Where the sculpture floats: out from the island this way (down the screen), this far past
## where the cleaned water ends.
const FIND_DIR := Vector2(1.0, 1.0)
const FIND_PAST := 1.4
## The dirty water a net can be thrown at: tiles this far past the island's shelf. The top
## `LIGHT_SLOTS` pieces of each are kept liftable at the run's Strength, so every net fills.
const REACH := 24.0
const LIGHT_SLOTS := 6
## Where the angler stands at the start of the casts, off the island's middle.
const START := Vector2(1.6, 1.4)
## The zoom stop the lake beats open on (three screen pixels to an art pixel).
const START_ZOOM := 3
## The storm's length once it starts, and when the tornado comes after the door shuts.
const STORM := 240.0

var _stage := OS.get_environment("PLAY_VIDEO_STAGE") != ""
## `PLAY_VIDEO_DRY=1`: the whole run played by the script instead of Richard (three casts at
## the dirty edge, the sculpture washed and put down, the door shut, the tornado down), with
## `tools/film/short/dry_*.png` and `dry.log`. Proves the take's cues before a take is spent.
var _dry := OS.get_environment("PLAY_VIDEO_DRY") != ""
var _dry_step := 0
var _dry_wait := 0
var _dry_lines: Array[String] = []
## `PLAY_VIDEO_SHOT=1`: the beat's opening frame saved to tools/film/short/shot_<beat>.png
## (the wash beat with its room open), then quit. For checking the layouts.
var _shot := OS.get_environment("PLAY_VIDEO_SHOT") != ""
const SHOT_AT := 90
var _beat := OS.get_environment("PLAY_VIDEO_BEAT")
var _main: Node
var _frames := 0
var _log: Array[String] = []
var _rng := RandomNumberGenerator.new()
var _cursor: Node2D
var _throws := 0
var _net_was := 0
var _stormed := false
var _tornado_on := false
var _shed_was := false


func _ready() -> void:
	_rng.seed = 41
	if _beat == "":
		_beat = "casts"
	if _stage:
		_copy(SOURCE, STAGING)
	else:
		_beat = _beat.strip_edges().to_lower()
		if not BEATS.has(_beat) or not FileAccess.file_exists(STAGED % _beat):
			var why := "no staged save at %s for beat '%s'; run PLAY_VIDEO_STAGE=1 first" % [
					ProjectSettings.globalize_path(STAGED % _beat), _beat]
			push_error("play_video: " + why)
			OS.alert(why, "play_video")
			get_tree().quit(1)
			return
		_copy(STAGED % _beat, TAKE)
		_dress_window()
		ShedRoom.stacked = true
		ShedRoom.quiet = true
		WashRoom.stacked = true
		WashStand.stacked = true
		WashStand.quiet = true
		Trophy.middle = FIND_CARD_AT
		_hide_pointer()
	TranslationServer.set_locale("en")
	Style.set_locale("en")
	# A borrowed lake's room is pinned at stage 3; this one shows the stage the meter earned.
	# Staged at 3 (where Richard laid the room out) so nothing leaves on the load, then
	# nudged off stage 2's holes by hand (`_nudge_house`).
	Lake.force_house = 3 if _stage else HOUSE_STAGE
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", STAGING if _stage else TAKE)
	_main.set(&"autoload_save", true)
	# Under this node, not the root: the root's lake wears the menu.
	if _stage:
		add_child.call_deferred(_main)
	else:
		_frame_view().add_child.call_deferred(_main)
	# After the lake's own _process, so what is hidden here stays hidden in the frame drawn.
	process_priority = 100


func _exit_tree() -> void:
	if not _stage:
		for shape in Input.CURSOR_HELP + 1:
			Input.set_custom_mouse_cursor(null, shape as Input.CursorShape)
	ShedRoom.stacked = false
	ShedRoom.quiet = false
	WashRoom.stacked = false
	WashStand.stacked = false
	WashStand.quiet = false
	Trophy.middle = -1.0


func _copy(from: String, to: String) -> void:
	for path in [to, to + ".bak", to + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.copy_absolute(ProjectSettings.globalize_path(from), ProjectSettings.globalize_path(to))


## A portrait window as tall as the screen's usable height, in its middle, borderless; the
## root drawn at `FRAME` and scaled into it.
func _dress_window() -> void:
	var win := get_window()
	var usable := DisplayServer.screen_get_usable_rect(win.current_screen)
	var tall := usable.size.y
	var wide := int(round(float(tall) * float(FRAME.x) / float(FRAME.y)))
	win.mode = Window.MODE_WINDOWED
	win.borderless = true
	win.size = Vector2i(wide, tall)
	win.position = usable.position + Vector2i((usable.size.x - wide) / 2, 0)
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	win.content_scale_size = FRAME


## The SubViewport the lake is drawn in: `FRAME` pixels, its 2D `CANVAS` stretched over them,
## nearest-filtered like the root (`Prefs`), fed the root's input by its container.
func _frame_view() -> SubViewport:
	var box := SubViewportContainer.new()
	box.name = &"Frame"
	box.size = Vector2(FRAME)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(box)
	var view := SubViewport.new()
	view.name = &"View"
	view.size = FRAME
	view.size_2d_override = CANVAS
	view.size_2d_override_stretch = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	box.add_child(view)
	return view


## The real pointer made invisible, and the game's own arrow drawn on a layer over everything,
## where the recording can see it.
func _hide_pointer() -> void:
	var clear := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	clear.fill(Color(0, 0, 0, 0))
	var none := ImageTexture.create_from_image(clear)
	for shape in Input.CURSOR_HELP + 1:
		Input.set_custom_mouse_cursor(none, shape as Input.CursorShape)
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	_cursor = DrawnPointer.new()
	layer.add_child(_cursor)


class DrawnPointer:
	extends Node2D
	var _art: Texture2D = load(Pad.CURSOR_ART) if ResourceLoader.exists(Pad.CURSOR_ART) else null

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		# Wherever the game would hide its pointer (the pad, the nozzle), this hides too.
		if _art == null or Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
			return
		# On the root's 1080x1920, at the game's own 1.5 stretch: three pixels to the arrow's
		# art pixel, as the game's own pixels are.
		var at := (get_viewport().get_mouse_position() - Pad.CURSOR_TIP * 1.5).round()
		draw_texture_rect(_art, Rect2(at, _art.get_size() * 1.5), false)


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F10:
		get_tree().quit()


func _process(_delta: float) -> void:
	_frames += 1
	if _main == null or not _main.is_inside_tree():
		return
	if _stage:
		if _frames == 8:
			_dress_lake()
		return
	if _frames == 3:
		_start_beat()
		if _shot and _beat == "wash":
			_main.call(&"_set_wash", true)
			(_main.get(&"_wash") as WashRoom).pick(&"decor_pk_sculpture")
	if _frames >= 3:
		_quiet()
		_watch()
	if _dry and _frames >= 30:
		_dry_run()
	if _shot and _frames == SHOT_AT - 70 and _beat == "house":
		var early := get_viewport().get_texture().get_image()
		early.save_png(ProjectSettings.globalize_path("res://tools/film/short/shot_house_up.png"))
	if _shot and _frames == SHOT_AT:
		var image := get_viewport().get_texture().get_image()
		image.save_png(ProjectSettings.globalize_path("res://tools/film/short/shot_%s.png" % _beat))
		get_tree().quit()


# --- Staging ---------------------------------------------------------------------------------

func _say(line: String) -> void:
	_log.append(line)
	print(line)


func _dress_lake() -> void:
	var grid: LakeGrid = _main.get_node(^"Grid")
	_say("--- play_video stage from %s" % SOURCE)
	_say("meter at load: %.3f left, %d pieces" % [float(_main.get(&"pollution")), grid.piece_count()])
	var decor: Array = _main.get(&"decor")
	var unlocked: Array = _main.get(&"unlocked")
	var placed := Vector2i(-1, -1)
	for i in range(decor.size() - 1, -1, -1):
		if String(decor[i]["piece"]) == SCULPTURE:
			placed = Vector2i(int(decor[i]["cell"][0]), int(decor[i]["cell"][1]))
			decor.remove_at(i)
	unlocked.erase(SCULPTURE)
	_say("sculpture taken out of the room (it stood at cell %s)" % str(placed))
	_drop_finds(grid)
	_thin(grid)
	for key: String in LEVELS:
		_main.set(StringName(key + "_level"), int(LEVELS[key]))
	_main.call(&"_push_net_numbers")
	var net: CastNet = _main.get_node(^"Net")
	_say("net: range %.1f tiles, hold %d, power %d, mouth %.0f px" % [
			net.range_tiles, net.hold, int(_main.call(&"net_power")), net.mouth_extent()])
	_lighten(grid, int(_main.call(&"net_power")))
	var find_at := _float_sculpture(grid)
	_main.call(&"_latch_house")
	_say("house stage %d" % int(_main.get(&"house_stage")))
	placed = _nudge_house(decor, placed)
	var shelf: Array[String] = []
	for name: String in unlocked:
		var standing := false
		for row: Dictionary in decor:
			if String(row["piece"]) == name:
				standing = true
		if not standing:
			shelf.append(name)
	_say("on the shelf: %s" % ", ".join(shelf))
	if not _main.call(&"save_game"):
		_say("!! save failed")
	var file := FileAccess.open(STAGING, FileAccess.READ)
	var save: Dictionary = file.get_var(true)
	file.close()
	_write_beats(save, find_at, placed)
	_say("--- done")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/film/short"))
	var out := FileAccess.open(LOG, FileAccess.WRITE)
	out.store_string("\n".join(_log) + "\n")
	out.close()
	for path in [STAGING, STAGING + ".bak", STAGING + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	get_tree().quit()


## Every find in the water taken out: the sculpture is the only shine on the lake.
func _drop_finds(grid: LakeGrid) -> void:
	var dropped := 0
	for index in grid.stacks.size():
		var stack: PackedInt32Array = grid.stacks[index]
		for slot in range(stack.size() - 1, -1, -1):
			if grid.defs[stack[slot]].keepsake:
				grid.take(index, slot)
				dropped += 1
	_say("finds taken out of the water: %d" % dropped)


## The lake cleaned out from the island to `LEFT` on the meter: whole tiles emptied nearest
## first, the distance bent by a slow noise so the cleaned water ends in big lobed bays.
## Taken the way the net takes, so the meter and the filth map follow.
func _thin(grid: LakeGrid) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = FRONT_SEED
	noise.frequency = FRONT_NOISE
	noise.fractal_octaves = 3
	var order: Array = []
	for index in grid.stacks.size():
		if grid.dry[index] == 1 or grid.stacks[index].is_empty():
			continue
		var tile := Vector2(grid.tile_of(index)) + Vector2(0.5, 0.5)
		# Only the open lake: the strand along the bank is the dogs', and stays as it is.
		var tx := int(tile.x)
		var ty := int(tile.y)
		if Iso.on_strand(tx, ty):
			continue
		var far := Iso.past_shelf(tile) + noise.get_noise_2d(tile.x, tile.y) * FRONT_WOBBLE
		order.append([far, index])
	order.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var taken := 0
	var front := 0.0
	for pair: Array in order:
		if float(_main.get(&"pollution")) <= LEFT:
			break
		var index: int = pair[1]
		front = pair[0]
		while not grid.stacks[index].is_empty():
			var def_index := grid.take(index, grid.stacks[index].size() - 1)
			_main.call(&"_on_net_caught", def_index)
			taken += 1
	_say("thinned to %.3f left: %d pieces taken, the front about %.1f tiles out" % [
			float(_main.get(&"pollution")), taken, front])


## The top `LIGHT_SLOTS` of every dirty stack in reach kept liftable: a piece too heavy is
## traded for a lighter one of the same material out of the same stack's depth, or else for
## any lighter piece of that material, so the count and the meter do not move.
func _lighten(grid: LakeGrid, power: int) -> void:
	var by_kind := {}
	for i in grid.defs.size():
		var def: TrashDef = grid.defs[i]
		if def.keepsake or def.tier > power:
			continue
		if not by_kind.has(def.material):
			by_kind[def.material] = []
		by_kind[def.material].append(i)
	var traded := 0
	for index in grid.stacks.size():
		if grid.dry[index] == 1 or grid.stacks[index].is_empty():
			continue
		var tile := Vector2(grid.tile_of(index)) + Vector2(0.5, 0.5)
		if Iso.past_shelf(tile) > REACH:
			continue
		var stack: PackedInt32Array = grid.stacks[index]
		var changed := false
		for k in range(stack.size() - 1, maxi(stack.size() - 1 - LIGHT_SLOTS, -1), -1):
			var def: TrashDef = grid.defs[stack[k]]
			if def.keepsake or def.tier <= power:
				continue
			var pool: Array = by_kind.get(def.material, [])
			if pool.is_empty():
				continue
			stack[k] = pool[_rng.randi_range(0, pool.size() - 1)]
			changed = true
			traded += 1
		if changed:
			grid.stacks[index] = stack
			grid.call(&"_restamp", index)
	_say("pieces in reach made liftable: %d" % traded)


## Every piece of the room standing on one of stage 2's holes or puddles (or, after that,
## on another piece) moved to the nearest spot it may stand, `NUDGE_MOST` placement px at
## most, else left for the shelf. Richard laid the room out at stage 3 (a borrowed lake's
## room is pinned there), where the floor is whole. Also says where the sculpture's own old
## spot can be had at stage 2, for the beat that starts with it placed.
const NUDGE_MOST := 120
const NUDGE_STEP := 2


func _nudge_house(decor: Array, sculpture_at: Vector2i) -> Vector2i:
	_main.set(&"_inside_pin", HOUSE_STAGE)
	_main.call(&"_latch_house")
	var room: ShedRoom = _main.get(&"_room")
	room.decor = decor
	var gone: Array[int] = []
	for i in decor.size():
		var row: Dictionary = decor[i]
		var piece := StringName(row["piece"])
		var cell := Vector2i(int(row["cell"][0]), int(row["cell"][1]))
		var view := int(row.get("view", 0))
		if room.sheets.on_wall(piece) or room.can_place(piece, cell, view, i):
			continue
		var spot := _nearest_free(room, piece, cell, view, i)
		if spot == Vector2i(-9999, -9999):
			gone.append(i)
			_say("  to the shelf at stage %d: %s at %s (no room near)" % [HOUSE_STAGE, piece, str(cell)])
			continue
		row["cell"] = [spot.x, spot.y]
		_say("  moved at stage %d: %s %s -> %s" % [HOUSE_STAGE, piece, str(cell), str(spot)])
	for k in range(gone.size() - 1, -1, -1):
		decor.remove_at(gone[k])
	if sculpture_at.x > -1:
		var mine := StringName(SCULPTURE)
		decor.append({"piece": SCULPTURE, "cell": [sculpture_at.x, sculpture_at.y], "view": 0})
		var last := decor.size() - 1
		if not room.can_place(mine, sculpture_at, 0, last):
			var spot := _nearest_free(room, mine, sculpture_at, 0, last)
			_say("  the sculpture's old spot %s is taken at stage %d: %s" % [
					str(sculpture_at), HOUSE_STAGE, str(spot)])
			sculpture_at = spot
		decor.remove_at(last)
	return sculpture_at


func _nearest_free(room: ShedRoom, piece: StringName, cell: Vector2i, view: int, index: int) -> Vector2i:
	for reach in range(NUDGE_STEP, NUDGE_MOST + 1, NUDGE_STEP):
		var best := Vector2i(-9999, -9999)
		var best_d := INF
		for dy in range(-reach, reach + 1, NUDGE_STEP):
			for dx in range(-reach, reach + 1, NUDGE_STEP):
				if maxi(absi(dx), absi(dy)) != reach:
					continue
				var at := cell + Vector2i(dx, dy)
				if not room.can_place(piece, at, view, index):
					continue
				var d := Vector2(dx, dy).length()
				if d < best_d:
					best = at
					best_d = d
		if best_d < INF:
			return best
	return Vector2i(-9999, -9999)


## The sculpture on top of the first dirty stack out along `FIND_DIR`, `FIND_PAST` tiles past
## the cleaned water, in reach of the shore the angler would throw from. Its tile, or INF.
func _float_sculpture(grid: LakeGrid) -> Vector2:
	var def_index := -1
	for i in grid.defs.size():
		if String(grid.defs[i].piece) == SCULPTURE:
			def_index = i
	if def_index < 0:
		_say("!! no sculpture def in the lake")
		return Vector2.INF
	var dir := FIND_DIR.normalized()
	var span := 0.0
	var front := Vector2.INF
	while span < 60.0:
		var tile := Iso.ISLAND_CENTRE + dir * span
		var index := grid.index_of(int(tile.x), int(tile.y))
		if index >= 0 and grid.dry[index] == 0 and not grid.stacks[index].is_empty():
			front = tile
			break
		span += 0.25
	if front == Vector2.INF:
		_say("!! no dirty water out along %s" % str(FIND_DIR))
		return Vector2.INF
	var at := front + dir * FIND_PAST
	var index := grid.index_of(int(at.x), int(at.y))
	grid.insert(index, grid.stacks[index].size(), def_index)
	var angler: Angler = _main.get_node(^"Angler")
	var shore: Vector2 = angler.shore_toward(at)
	var net: CastNet = _main.get_node(^"Net")
	_say("sculpture afloat at tile %s (front at %s), %.1f tiles from the shore at %s, range %.1f" % [
			str(at.round()), str(front.round()), shore.distance_to(at), str(shore.round()), net.range_tiles])
	return at


## One save a beat, off the staged lake.
func _write_beats(save: Dictionary, find_at: Vector2, placed: Vector2i) -> void:
	var levels: Dictionary = save.get("levels", {})
	for key: String in LEVELS:
		levels[key] = int(LEVELS[key])
	save["levels"] = levels
	save["hose"] = HOSE
	save["sludge"] = 6400.0
	# Every first-time card already seen, every tour done: nothing talks over the play.
	var cues: Array = []
	for kind: StringName in Lake.CUE_KINDS:
		cues.append(String(kind))
	save["cues_seen"] = cues
	for flag in ["intro_done", "first_steps", "shop_tour", "decor_tour", "house_walk",
			"wildlife_seen", "camera_tip", "first_buy"]:
		save[flag] = true
	# A colony at work in the cupboard, no honey due within the take.
	save["hive"] = {"stage": Hive.Stage.BUSY, "jars": 2, "harvests": 1, "first_done": true,
		"refill_at": 1.0e9, "refill_from": 0.0, "moment_seen": true, "ready_seen": true}
	# No shower of its own: the storm comes with the tornado. The run's second tornado.
	save["rain_next"] = 1.0e9
	save["tornadoes"] = 1
	save["tornado_next"] = 2.0
	# Stage 2 earned, the room inside not yet seen mended: the door plays the stage-up.
	save["house"] = HOUSE_STAGE
	save["house_seen"] = 1
	save["unwashed"] = []
	var angler := Iso.ISLAND_CENTRE + START
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(STAGED.get_base_dir()))
	for beat: String in BEATS:
		var out := save.duplicate(true)
		var stacks: Array = out["stacks"]
		var unlocked: Array = out["unlocked"]
		unlocked.append_array(SHELF_EXTRA)
		var decor: Array = out["decor"]
		out["angler"] = angler
		if beat != "casts":
			_take_from(out, find_at)
		match beat:
			"wash":
				out["unwashed"] = [SCULPTURE]
				out["angler"] = Pump.tile + Vector2(0.9, 0.9)
			"house":
				unlocked.insert(0, SCULPTURE)
				out["angler"] = _main.call(&"_before_the_door")
			"tornado":
				unlocked.insert(0, SCULPTURE)
				decor.append({"piece": SCULPTURE, "cell": [placed.x, placed.y], "view": 0})
				out["house_seen"] = 2
				out["angler"] = _main.call(&"_before_the_door")
		var file := FileAccess.open(STAGED % beat, FileAccess.WRITE)
		file.store_var(out, true)
		file.close()
		_say("wrote %s (%d stacks)" % [STAGED % beat, stacks.size()])


## The sculpture out of the water in a beat that starts after it was caught.
func _take_from(save: Dictionary, find_at: Vector2) -> void:
	if find_at == Vector2.INF:
		return
	var grid: LakeGrid = _main.get_node(^"Grid")
	var index := grid.index_of(int(find_at.x), int(find_at.y))
	var stacks: Array = save["stacks"]
	if index < 0 or index >= stacks.size():
		return
	var stack: Array = Array(stacks[index])
	for k in range(stack.size() - 1, -1, -1):
		if String(grid.defs[int(stack[k])].piece) == SCULPTURE:
			stack.remove_at(k)
	stacks[index] = PackedInt32Array(stack) if stacks[index] is PackedInt32Array else stack


# --- The take --------------------------------------------------------------------------------

func _start_beat() -> void:
	# The song goes under the edit; the take is the game's own sound alone.
	var music := AudioServer.get_bus_index(Prefs.BUS_MUSIC)
	if music >= 0:
		AudioServer.set_bus_mute(music, true)
	# Nearer than the game's opening zoom: a phone's frame is narrow, and the pieces read.
	if _beat == "casts" or _beat == "wash":
		_main.set(&"_view_zoom", _main.call(&"_zoom_level", START_ZOOM))
		_main.call(&"_push_zoom")
	match _beat:
		"house":
			_main.call(&"_set_shed", true)
		"tornado":
			_main.call(&"_set_shed", true)
			_storm()


## The game's own talk over the play put away, every frame after the lake has had its say.
func _quiet() -> void:
	var skin: CanvasItem = _main.get(&"_skin")
	if skin != null:
		skin.visible = false
	for key in [&"_open_upgrades", &"_open_settings", &"_free_camera", &"_heavy_note", &"_coins",
			&"_hint_card", &"_moment_card"]:
		var node: CanvasItem = _main.get(key)
		if node != null:
			node.visible = false
	for path in [^"Pigeon"]:
		var layer: CanvasLayer = _main.get_node_or_null(path)
		if layer != null:
			layer.visible = false


## The take's cues: the second cast doubled, the washed sculpture at the head of the shelf,
## the storm when it is put down, the tornado when the door shuts after that.
func _watch() -> void:
	var net: CastNet = _main.get(&"_net")
	if net != null:
		if net.state == CastNet.State.FLYING and _net_was == CastNet.State.IDLE:
			_throws += 1
			if _throws == 2 and _beat == "casts":
				_double(net)
		_net_was = net.state
	var unlocked: Array = _main.get(&"unlocked")
	var at := unlocked.find(SCULPTURE)
	if at > 0:
		unlocked.remove_at(at)
		unlocked.insert(0, SCULPTURE)
	if not _stormed:
		for row: Dictionary in _main.get(&"decor") as Array:
			if String(row["piece"]) == SCULPTURE:
				_storm()
				break
	var shed_open := bool(_main.get(&"_shed_open"))
	if _stormed and not _tornado_on and _shed_was and not shed_open:
		_tornado_on = true
		var angler: Angler = _main.get_node(^"Angler")
		var from := angler.tile_pos - Iso.ISLAND_CENTRE
		var tornado: Node = _main.get(&"_tornado")
		tornado.call(&"start", atan2(from.y, from.x))
	_shed_was = shed_open


## The second net, the way `_roll_luck` throws it: beside the first, its own hold, its sound.
func _double(net: CastNet) -> void:
	var net2: CastNet = _main.get(&"_net2")
	if net2 == null or net2.state != CastNet.State.IDLE:
		return
	var spot: Vector2 = _main.call(&"_double_spot", net.target)
	if spot == Vector2.INF:
		push_warning("play_video: no spot for the double cast")
		return
	net2.cast_to(Iso.tile_to_world(spot.x, spot.y))
	var sfx: Node = _main.get(&"_sfx")
	if sfx != null:
		sfx.call(&"play_luck", false, true)


func _storm() -> void:
	_stormed = true
	var weather: Weather = _main.get(&"_weather")
	if weather != null:
		weather.storm(STORM)


# --- The dry run -----------------------------------------------------------------------------

func _dry_say(line: String) -> void:
	_dry_lines.append("%5d  %s" % [_frames, line])
	var out := FileAccess.open("res://tools/film/short/dry.log", FileAccess.WRITE)
	out.store_string("
".join(_dry_lines) + "
")
	out.close()


func _dry_shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(
			ProjectSettings.globalize_path("res://tools/film/short/dry_%s.png" % name))


## A spot on the dirty edge out along `dir` from the island: the first dirty tile, plus `past`.
func _dry_edge(dir: Vector2, past: float) -> Vector2:
	var grid: LakeGrid = _main.get_node(^"Grid")
	var span := 0.0
	while span < 60.0:
		var tile := Iso.ISLAND_CENTRE + dir.normalized() * span
		var index := grid.index_of(int(tile.x), int(tile.y))
		if index >= 0 and grid.dry[index] == 0 and not grid.stacks[index].is_empty():
			return tile + dir.normalized() * past
		span += 0.25
	return Vector2.INF


## Stand on the shore towards `tile` and throw at it, pulled in towards the angler until the
## net can reach.
func _dry_throw(tile: Vector2) -> void:
	var angler: Angler = _main.get_node(^"Angler")
	var net: CastNet = _main.get(&"_net")
	angler.stand_at(angler.shore_toward(tile))
	var at := tile
	for pull in 40:
		if net.can_cast_to(Iso.tile_to_world(at.x, at.y)):
			break
		at = at.move_toward(angler.tile_pos, 0.5)
	_main.call(&"_cast_at", Iso.tile_to_world(at.x, at.y))


func _dry_run() -> void:
	var net: CastNet = _main.get(&"_net")
	var net2: CastNet = _main.get(&"_net2")
	if _dry_wait > 0:
		_dry_wait -= 1
		return
	match _dry_step:
		0, 2:
			if net.state != CastNet.State.IDLE or net2.state != CastNet.State.IDLE:
				return
			var dir := Vector2(-1.0, -1.0) if _dry_step == 0 else Vector2(-1.0, 0.6)
			_dry_throw(_dry_edge(dir, 2.5))
			_dry_say("cast %d out along %s: state %d" % [_dry_step / 2 + 1, str(dir), net.state])
			_dry_step += 1
		1, 3:
			if net.state == CastNet.State.SETTLED or net.state == CastNet.State.REELING:
				_dry_say("  landed: %d of %d aboard, second net %s, count shown %s" % [
						net.catch.size(), net.hold + net.luck_hold,
						"flying/landed" if net2.state != CastNet.State.IDLE else "idle",
						str((_main.get(&"_haul_count") as CanvasItem).visible if _main.get(&"_haul_count") != null else false)])
				_dry_shot("cast%d" % ((_dry_step + 1) / 2))
				_dry_step += 1
				_dry_wait = 10
		4:
			if net.state != CastNet.State.IDLE or net2.state != CastNet.State.IDLE:
				return
			var grid: LakeGrid = _main.get_node(^"Grid")
			var find := Vector2.INF
			for index in grid.stacks.size():
				var stack: PackedInt32Array = grid.stacks[index]
				if not stack.is_empty() and String(grid.defs[stack[stack.size() - 1]].piece) == SCULPTURE:
					find = Vector2(grid.tile_of(index)) + Vector2(0.5, 0.5)
			_dry_say("cast 3 at the sculpture %s" % str(find))
			_dry_throw(find)
			_dry_step += 1
		5:
			if (_main.get(&"unwashed") as Array).has(SCULPTURE):
				_dry_say("  the sculpture is at the pump; finds card shown: %s" % str(
						(_main.get_node(^"Finds") as CanvasLayer).visible))
				_dry_step += 1
				_dry_wait = 60
		6:
			if net.state != CastNet.State.IDLE:
				return
			_dry_shot("find")
			_main.call(&"_set_wash", true)
			(_main.get(&"_wash") as WashRoom).pick(&"decor_pk_sculpture")
			_dry_say("wash room open, the sculpture on the stand")
			_dry_step += 1
			_dry_wait = 20
		7:
			var stand: WashStand = (_main.get(&"_wash") as WashRoom).get(&"_stand")
			stand.spray(_dry_dirtiest(stand), true)
			if stand.share_clean() > 0.5 and not FileAccess.file_exists(
					ProjectSettings.globalize_path("res://tools/film/short/dry_wash.png")):
				_dry_shot("wash")
			if (_main.get(&"unlocked") as Array).has(SCULPTURE):
				stand.spray(Vector2.ZERO, false)
				_dry_say("  washed and on the shelf")
				_dry_step += 1
				_dry_wait = 40
		8:
			_main.call(&"_wash_to_shed")
			_dry_step += 1
			_dry_wait = 90
		9:
			var unlocked: Array = _main.get(&"unlocked")
			_dry_say("house open; the shelf leads with %s; stacked %s" % [str(unlocked[0]), str(ShedRoom.stacked)])
			_dry_shot("house")
			(_main.get(&"decor") as Array).append({"piece": SCULPTURE, "cell": [50, 60], "view": 0})
			_dry_step += 1
			_dry_wait = 30
		10:
			_dry_say("put down: storm %s, rain %.2f" % [str(_stormed), Weather.now])
			_dry_shot("placed")
			_main.call(&"_set_shed", false)
			_dry_step += 1
			_dry_wait = 30
		11:
			var tornado: Node = _main.get(&"_tornado")
			_dry_say("door shut: tornado %s, hits to tame %d" % [str(tornado.call(&"active")), int(tornado.get(&"_need"))])
			_dry_step += 1
			_dry_wait = 300
		12:
			_dry_shot("tornado")
			_dry_say("--- dry run done")
			get_tree().quit()


## The nearest grime left on the stand to the middle of the piece (`shot_wash_place`'s walk).
func _dry_dirtiest(stand: WashStand) -> Vector2:
	var grime: PackedFloat32Array = stand.get(&"_grime")
	var cols: int = stand.get(&"_cols")
	var cell: float = stand.get(&"_cell")
	var origin: Vector2 = stand.get(&"_origin")
	var from := stand.piece_box().get_center()
	var best := from
	var best_d := INF
	for i in grime.size():
		if grime[i] <= 0.0:
			continue
		var at := origin + (Vector2(i % cols, i / cols) + Vector2(0.5, 0.5)) * cell
		var d := at.distance_squared_to(from)
		if d < best_d:
			best_d = d
			best = at
	return best

