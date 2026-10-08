extends Node

const Style := preload("res://scripts/style.gd")
const FilmAudio := preload("res://tools/film_audio.gd")
## Films the shots the trailer is cut from: opens the lake on a real 1080p window, poses each
## shot (how clean the water is, where the angler stands, how wide the net is, how many hulls
## and dogs), and dumps every rendered frame as a JPEG so the edit can pick its cuts on the
## song's beat. The cut itself is `marketing/My Dirty Little Lake/trailer/build_trailer.py`.
##
## Run it with the desktop build, not --headless (nothing renders under the dummy driver),
## at a fixed frame rate so game time is one frame's worth a frame however long a frame takes
## to save. The slow-motion shots are filmed at 240 and say so in `FILM_FPS`:
##
##   godot --path . --fixed-fps 60 res://tools/film_trailer.tscn
##   FILM_FPS=240 godot --path . --fixed-fps 240 res://tools/film_trailer.tscn
##
## `FILM_ONLY=t2_open,t2_dogs` shoots a few by name (see `_plan` for the three runs). Frames
## land in tools/film/<shot>/, the shot's own folder emptied first, beside `sfx.txt` (every
## sound the game started, on its kept frame: the edit mixes them under the song) and
## `pointer.txt` (where the pointer was, for the edit to draw: the capture has no hardware
## cursor); tools/film/last_film.log says what was shot.
##
## `FILM_TALL=1` films the same shots for the vertical cut (2026-10-05, `/grill-me` with
## Richard): a 1080x1920 borderless window (taller than the monitor; Windows lets a borderless
## one be, and the viewport renders all of it), its canvas 720x1280 so the stretch is 1.5 and
## every zoom level and UI size is what the landscape film had. Frames land in
## tools/film/v_<shot>/ (the shot's name less its `t2_`), the log in last_film_tall.log, and
## the landscape frames are left alone. The shop shots open a wider window for themselves
## (`TALL_SHOP_WINDOW`) so the NET and LUCK boards fill the cut's width at their own size.
##
## Every shot holds the camera by hand (`_hold`) after the lake has had its say, so the
## follow, the cast look-in and the way home never move the view: the drift the trailer wants
## is put on in the edit, where it can be retuned without a re-shoot.

## Vars, not consts, so `film_devlog.gd` films to a save and a log of its own.
var SAVE_PATH := "user://film_trailer.save"
const OUT := "res://tools/film/%s/%05d.jpg"
var LOG_PATH := "res://tools/film/last_film.log"
## A wall clock the probe quits on whatever state it is in, so a stalled run never sits on
## the lake.
const QUIT_AFTER_MS := 20 * 60 * 1000
const JPG_QUALITY := 0.94
## Frames the lake is given after a shot is posed before the first frame is kept: the zoom's
## rebuild and the filth map have to land, and a thinned lake has to settle.
const SETTLE := 40
## Tiles round a coming cast's landing spot that thinning leaves foul.
const KEEP_NEAR := 4.5
## Frames the walk-out starts before the first kept frame, so the angler is already
## striding when the trailer fades in.
const WALK_LEAD := 4
## Frames a posed shot is given before its first kept frame, where the default is short:
## the wildlife has to arrive.
const SETTLE_LONG := {}

## Where the angler stands for a cast, in tiles off the island's middle, and which way the
## throw goes. Screen-right is +x -y; down the screen is +x +y.
const DOWN := Vector2(1.0, 1.0)
const ACROSS := Vector2(1.0, -1.0)
const LEFT := Vector2(-1.0, 1.0)
const UP := Vector2(-1.0, -1.0)

var _main: Node
var _grid: LakeGrid
var _net: CastNet
var _angler: Angler
var _camera: Camera2D
var _log: FileAccess

## The vertical film (see the header).
var _tall := OS.get_environment("FILM_TALL") != ""
const TALL_WINDOW := Vector2i(1080, 1920)
const TALL_CANVAS := Vector2i(720, 1280)
## The shop shots in the vertical film: the four boards are laid out on a 1220-wide canvas
## (`ShopSkin.BOARDS_WIDE` and its margin) drawn at a stretch of 1.8, so the first two boards
## and the purse under them span about 1060 px and the edit crops 1080 of them.
const TALL_SHOP_WINDOW := Vector2i(2196, 1920)
const TALL_SHOP_CANVAS := Vector2i(1220, 1067)

var _frames := 0
var _shots: Array = []
var _shot := -1
var _shot_frame := 0
var _kept := 0
## The shot's sound, recorded per bus under Movie Maker (`film_audio.gd`).
var _audio: RefCounted
var _hold := Vector2.INF
var _follow: Node2D = null
var _zoom_level := 3
var _net_was := 0
var _walked := false
var _walked_at := -1
var _turned := false
var _stuck := 0
var _you_was := Vector2.INF
var _noise := FastNoiseLite.new()
## The noise `_thin` cleans the lake in pools off. A var, so another shot can lay its pools
## out differently.
var thin_seed := 11
var _rng := RandomNumberGenerator.new()


## The shot list (trailer v2, 2026-10-03, `/grill-me` with Richard). Each: name, seconds of
## game time kept, setup, and a per-frame pose (frames since the shot was posed, counting the
## settle). Three runs, because thinning only ever cleans and slow motion wants its own frame
## rate (`FILM_FPS`, the same number as `--fixed-fps`):
##
##   FILM_ONLY=t2_open,t2_shop1,t2_cast2,t2_shop2,t2_pier,t2_dogs          (--fixed-fps 60)
##   FILM_FPS=240 FILM_ONLY=t2_gold,t2_tornado                             (--fixed-fps 240)
##   FILM_ONLY=t2_beauty                                                   (--fixed-fps 60)
##
## At 240 every system, the shaders' clocks included, runs a quarter as far a frame, so the
## edit plays every fourth frame for real speed and every frame for slow motion.
func _plan() -> void:
	_shots = [
		# A new game's lake, every piece in the water, held still at the whole-lake zoom while
		# the edit pushes in on it (a zoom between whole pixel levels crawls in the game's
		# own camera; 2026-10-03, Richard: "looks a bit lagged"), then the game's own zoom 4
		# on the angler from the frame the push lands, and the first small net.
		["t2_open", 9.0, func() -> void:
			_unpack()
			_hide_boats()
			_drop_finds()
			_levels(2, 2, 6, 6)
			_main.set(&"sludge", 180.0)
			_stand(OPEN_STAND, ACROSS)
			_dog_beside(OPEN_DOG)
			_stock(_angler.tile_pos + ACROSS.normalized() * OPEN_TILES, 2.0, 6)
			_zoom(_t(1, 2))
			_phase = DAY_PHASE
			_open_from = Iso.tile_to_world(Iso.CENTRE.x, Iso.CENTRE.y)
			_open_to = _between(ACROSS, OPEN_TILES, 0.42),
		func(f: int) -> void:
			var k := f - SETTLE
			_count_only()
			_sit_dog(OPEN_DOG, false)
			# Held at zoom 1 for the first half of the push and at zoom 2 for the second (the
			# floating rubbish is drawn at half a screen pixel an art pixel at zoom 1, so the
			# edit's push hands over to a zoom-2 source as soon as it is past 2x), then the
			# game's own zoom 4. Where zoom 2 is held is where the edit's push is at its middle.
			var half := int(OPEN_PUSH) / 2
			if _tall and k < int(OPEN_PUSH):
				# The vertical film starts the push at zoom 2 (zoom 1's view is taller than the
				# ground), so the landscape hand-over at the middle would hand the edit a view
				# narrower than its own virtual camera. Instead the camera rides the edit's
				# virtual camera (`push_frame` in build_trailer2.py: zoom eased in its logarithm
				# by a smootherstep, place weighted by how far the view has closed) and steps to
				# zoom 3 only once the virtual zoom is past it.
				var u := maxf(float(k), 0.0) / OPEN_PUSH
				var e := u * u * u * (u * (u * 6.0 - 15.0) + 10.0)
				var z := 2.0 * pow(OPEN_ZOOM / 2.0, e)
				var w := (1.0 / z - 0.5) / (1.0 / OPEN_ZOOM - 0.5)
				_hold = _open_from.lerp(_open_to, w)
				if z >= OPEN_HANDOVER and _zoom_level < 3:
					_zoom(3)
					_say("  open: zoom 3 from kept frame %d" % _kept)
			elif _tall and k == int(OPEN_PUSH):
				_zoom(int(OPEN_ZOOM))
				_hold = _open_to
			elif _tall:
				pass
			elif k < half:
				_hold = _open_from
			elif k == half:
				_zoom(_t(2, 3))
				_hold = _open_from.lerp(_open_to, 2.0 / 3.0)
			elif k == int(OPEN_PUSH):
				_zoom(int(OPEN_ZOOM))
				_hold = _open_to
			if k in [half - 1, half + 1, int(OPEN_PUSH) - 1, int(OPEN_PUSH) + 1]:
				_say("  open: kept frame %d, camera at %s, zoom %s" % [_kept,
						str(_camera.get_screen_center_position()), str(_camera.zoom)])
			if k == OPEN_THROW:
				_cast(ACROSS, OPEN_TILES)],
		# The upgrades board over a little cleaner lake: the pointer goes to Width's tag and
		# buys it, then Catch's. The edit crops to the net's board and the purse.
		["t2_shop1", 3.6, func() -> void:
			_thin(0.12)
			_levels(2, 2, 6, 6)
			_main.set(&"sludge", 4800.0)
			_zoom(3)
			_hold = Iso.tile_to_world(Iso.ISLAND_CENTRE.x, Iso.ISLAND_CENTRE.y)
			_shop_open([&"net_width", &"net_hold"]),
		func(f: int) -> void:
			_shop_step(f - SETTLE)],
		# A wider net from the south-west beach over water a quarter cleaned.
		["t2_cast2", 6.0, func() -> void:
			_shop_close()
			_levels(8, 5, 8, 10)
			_stand(CAST2_STAND, LEFT)
			_thin(0.28, [_angler.tile_pos + LEFT.normalized() * CAST2_TILES])
			_stock(_angler.tile_pos + LEFT.normalized() * CAST2_TILES, 2.5, 5)
			_zoom(4)
			_hold = _between(LEFT, CAST2_TILES, _t(0.45, 0.58)),
		func(f: int) -> void:
			_count_only()
			if f - SETTLE == 30:
				_cast(LEFT, CAST2_TILES)],
		# The board again: Luck and Double cast, the two the gold double cast after it shows.
		["t2_shop2", 3.6, func() -> void:
			_levels(8, 5, 8, 10)
			_main.set(&"sludge", 9400.0)
			_shop_open([&"lucky_haul", &"double_cast"]),
		func(f: int) -> void:
			_shop_step(f - SETTLE)],
		# The pier: a ferry pours a big wood hold into the box, coins fly to the purse.
		["t2_pier", 10.0, func() -> void:
			_shop_close()
			_pose_pier(),
		func(f: int) -> void:
			_run_pier(f)],
		# The pack sits round the angler on the east beach, then breaks for the water one after
		# another and swims out for pieces close in (2026-10-03, Richard).
		["t2_dogs", 10.0, func() -> void:
			_hide_boats()
			_follow = null
			_stand(Vector2(3.4, -3.4), ACROSS)
			thin_seed = 37
			_thin(0.45)
			_pack()
			_main.set(&"dog_strength_level", 4)
			_main.set(&"dog_fetch_level", 4)
			_main.call(&"_push_dog_numbers")
			_plant_sticks(_near_sticks())
			_seat_pack()
			_zoom(6)
			_phase = DAY_PHASE
			var reach: Vector2 = _near_sticks()[0]
			_hold = Iso.tile_to_world(_angler.tile_pos.x, _angler.tile_pos.y).lerp(
					Iso.tile_to_world(reach.x, reach.y), 0.45),
		func(f: int) -> void:
			_hud_off()
			_run_pack(f - SETTLE)],
		# 240 fps: the gold net and the double, wide, over a lake half cleaned.
		["t2_gold", 7.0, func() -> void:
			_unpack()
			_hide_boats()
			_drop_finds()
			_levels(18, 6, 10, 14)
			_stand(GOLD_STAND, ACROSS)
			var land := _angler.tile_pos + ACROSS.normalized() * GOLD_TILES
			thin_seed = 23
			_thin(0.55, [land + GOLD_UP, land + GOLD_DOWN, land], 3.6)
			_stock(land + GOLD_UP, 3.5, 5)
			_stock(land + GOLD_DOWN, 3.5, 5)
			_zoom(3)
			_phase = DAY_PHASE
			_hold = _between(ACROSS, GOLD_TILES, _t(0.5, 0.68)) + Vector2(0.0, 20.0),
		func(f: int) -> void:
			_count_only()
			if f == _sec(GOLD_THROW):
				_cast_pair(GOLD_TILES, GOLD_UP, GOLD_DOWN)],
		# 240 fps: the storm brews, the funnel comes down off the island's beach, the net
		# hits it three times and the last net brings the whirl home.
		["t2_tornado", 26.0, func() -> void:
			_pose_tornado(),
		func(f: int) -> void:
			_run_tornado(f)],
		# Grime to beauty: the lake cleaned outwards from the island in a wave while the life
		# comes back and the hut mends, held long after for the end card. No hive colony.
		["t2_beauty", 24.0, func() -> void:
			_pose_beauty(),
		func(f: int) -> void:
			_run_beauty(f)],
	]
	var only := OS.get_environment("FILM_ONLY")
	if only != "":
		var names := only.split(",")
		_shots = _shots.filter(func(s: Array) -> bool: return s[0] in names)


func _ready() -> void:
	if _tall:
		LOG_PATH = LOG_PATH.replace(".log", "_tall.log")
		_window(TALL_WINDOW, TALL_CANVAS)
	else:
		DisplayServer.window_set_size(Vector2i(1920, 1080))
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	_say("--- film_trailer start%s" % (" (tall)" if _tall else ""))
	_rng.seed = 7
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE_PATH)
	_main.set(&"autoload_save", false)
	_fps = float(OS.get_environment("FILM_FPS")) if OS.get_environment("FILM_FPS") != "" else 60.0
	if Sfx.main() != null:
		Sfx.main().played.connect(_on_played)
	_audio = FilmAudio.new()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	add_child(_main)
	# After the lake's own _process, so the camera written here is the one drawn.
	process_priority = 100


## The window at `size`, borderless and windowed at the screen's corner, its canvas `canvas`.
func _window(size: Vector2i, canvas: Vector2i) -> void:
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.borderless = true
	win.size = size
	win.position = Vector2i.ZERO
	win.content_scale_size = canvas
	_fixed_stretch = minf(float(size.x) / float(canvas.x), float(size.y) / float(canvas.y))


## The folder a shot's frames go to.
func _dir_of(name: String) -> String:
	return ("v_" + name.trim_prefix("t2_")) if _tall else name


func _say(line: String) -> void:
	_log.store_line(line)
	_log.flush()


func _process(_delta: float) -> void:
	_frames += 1
	if Time.get_ticks_msec() > QUIT_AFTER_MS:
		_say("--- wall clock, quitting")
		get_tree().quit()
		return
	if _frames == 3:
		_setup()
		_plan()
		_next()
		return
	if _frames < 4 or _shot >= _shots.size():
		return
	var shot: Array = _shots[_shot]
	(shot[3] as Callable).call(_shot_frame)
	_aim()
	# The frame the net comes down on, for the edit to put on a downbeat.
	if _net.state != _net_was:
		if _net.state == CastNet.State.SETTLED or _net.state == CastNet.State.REELING:
			if _net_was == CastNet.State.FLYING:
				var at := _grid.tile_at(_net.world_pos())
				_say("  %s: net lands on kept frame %d, catch %d of %d, tile %s, strength %d, mouth %.0f" % [
						shot[0], _kept, _net.catch.size(), _net.hold + _net.luck_hold,
						str(Iso.world_to_tile(_net.world_pos()).round()), _net.strength(), _net.mouth_extent()])
		_net_was = _net.state
	if _shot_frame >= _settle_of(shot[0]):
		if _kept == 0 and _audio != null:
			_audio.begin()
		var image := get_viewport().get_texture().get_image()
		image.save_jpg(ProjectSettings.globalize_path(OUT % [_dir_of(shot[0]), _kept]), JPG_QUALITY)
		# The camera the saved picture was drawn with: the viewport hands back the frame drawn
		# after the last `_process`, so the camera is last frame's (the edit's push maps every
		# frame through it).
		if _camera_log != null:
			_camera_log.store_line("%d %.3f %.3f %.6f" % [_kept, _cam_was.x, _cam_was.y, _cam_scale_was])
		if _pointer_log != null:
			if _pointer_on:
				_pointer_log.store_line("%d %d %d" % [_kept, roundi(_pointer.x), roundi(_pointer.y)])
			else:
				_pointer_log.store_line("%d -" % _kept)
		_kept += 1
		if _kept >= int(shot[1] * _fps) or (_end_at >= 0 and _kept >= _end_at):
			_say("%s: %d frames" % [shot[0], _kept])
			_next()
			return
	_shot_frame += 1
	_remember_camera()


func _remember_camera() -> void:
	_cam_was = _camera.get_screen_center_position()
	_cam_scale_was = _camera.zoom.x * _stretch()


func _setup() -> void:
	_grid = _main.get_node(^"Grid") as LakeGrid
	_net = _main.get_node(^"Net") as CastNet
	_angler = _main.get_node(^"Angler") as Angler
	_camera = _main.get_node(^"Camera") as Camera2D
	(_main.get_node(^"HUD") as CanvasLayer).visible = false
	# English whatever the machine's locale: the board and the pier signs are read.
	TranslationServer.set_locale("en")
	Style.set_locale("en")
	_main.set(&"net_range_level", 6)
	_main.set(&"net_hold_level", 10)
	_main.set(&"reel_level", 6)
	_main.call(&"_push_net_numbers")
	Input.warp_mouse(Vector2(2, 2))


func _next() -> void:
	_walk(false)
	if _net != null and _net.state != CastNet.State.IDLE:
		_net.call(&"_come_home")
	# Whatever the last shot opened is shut again: the shed, the HUD.
	if _main != null and _main.is_inside_tree():
		if _main.get(&"_shed_open"):
			_main.call(&"_set_shed", false)
		(_main.get_node(^"HUD") as CanvasLayer).visible = false
		(_main.get(&"_wildlife") as Wildlife).held = false
		(_main.get(&"_skin") as HudSkin).plates_only = false
		(_main.get(&"_skin") as CanvasItem).visible = true
	_phase = -1.0
	_end_at = -1
	_pointer_on = false
	if _sfx_log != null:
		_sfx_log.close()
		_sfx_log = null
	if _audio != null and _shot >= 0 and _shot < _shots.size():
		_audio.finish(ProjectSettings.globalize_path("res://tools/film/%s" % _dir_of(_shots[_shot][0])))
	if _pointer_log != null:
		_pointer_log.close()
		_pointer_log = null
	if _camera_log != null:
		_camera_log.close()
		_camera_log = null
	_shot += 1
	if _shot >= _shots.size():
		_say("--- film_trailer done")
		get_tree().quit()
		return
	var shot: Array = _shots[_shot]
	if _tall:
		_window(TALL_WINDOW, TALL_CANVAS)
	var dir := ProjectSettings.globalize_path("res://tools/film/%s" % _dir_of(shot[0]))
	if DirAccess.dir_exists_absolute(dir):
		for old in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(old))
	else:
		DirAccess.make_dir_recursive_absolute(dir)
	_shot_frame = 0
	_kept = 0
	_walked = false
	_walked_at = -1
	_turned = false
	_stuck = 0
	_you_was = Vector2.INF
	_follow = null
	_sfx_log = FileAccess.open(dir.path_join("sfx.txt"), FileAccess.WRITE)
	_pointer_log = FileAccess.open(dir.path_join("pointer.txt"), FileAccess.WRITE)
	_camera_log = FileAccess.open(dir.path_join("camera.txt"), FileAccess.WRITE)
	(shot[2] as Callable).call()


## Hold the camera where the shot wants it, after the lake has moved it.
func _aim() -> void:
	if _phase >= 0.0:
		(_main.get(&"_day") as DayCycle).phase = _phase
	_push_camera_zoom()
	# The aim ring follows the pointer; pointed a long way off the lake it is not drawn.
	_net.pad_aim = Vector2(-1.0e6, -1.0e6)
	var at := _hold
	if _follow != null:
		at = _follow.position
	if at == Vector2.INF:
		_snap()
		return
	_main.set(&"_pan", at - _angler.position)
	_main.set(&"_panning", true)
	_camera.position = _main.call(&"_clamped_view", at)
	_snap()


## Zoom to `level` screen pixels an art pixel (on 1080p; the game's own wheel stops at 4).
## Set straight on the camera every frame: the trailer's close-ups go past MAX_ZOOM, and
## whole levels keep the art on whole pixels, which is the rule the cap was for.
## Hold or release the down key, as a real event so every reader of the action sees it.
func _walk(down: bool) -> void:
	_walk_dir(&"walk_down" if down else &"")


const WALKS: Array[StringName] = [&"walk_left", &"walk_right", &"walk_up", &"walk_down"]
var _walking: StringName = &""


## Hold one direction key and release the others (`&""` releases all).
func _walk_dir(action: StringName) -> void:
	if action == _walking:
		return
	for name in WALKS:
		var ev := InputEventAction.new()
		ev.action = name
		ev.pressed = name == action
		Input.parse_input_event(ev)
	_walking = action


func _zoom(level: int) -> void:
	_zoom_level = level
	_main.set(&"_view_zoom", _main.call(&"_zoom_level", mini(level, 4)))
	_main.call(&"_push_zoom")
	_push_camera_zoom()


func _push_camera_zoom() -> void:
	var zoom: float = float(_zoom_level) / (Lake.ART_PIXEL * _stretch())
	_camera.zoom = Vector2(zoom, zoom)


## Put the angler on the island's shore, `off` tiles from its middle, facing `dir`.
func _stand(off: Vector2, dir: Vector2) -> void:
	_angler.stand_at(Iso.ISLAND_CENTRE + off)
	_angler.facing = dir.normalized()


## The farthest castable spot along `dir` within `tiles` of the angler.
func _target(dir: Vector2, tiles: float) -> Vector2:
	var best := Vector2.INF
	var span := 0.5
	while span <= minf(tiles, _net.range_tiles):
		var tile := _angler.tile_pos + dir.normalized() * span
		var where := Iso.tile_to_world(tile.x, tile.y)
		if _net.can_cast_to(where):
			best = where
		span += 0.5
	return best


## A camera point `lean` of the way from the angler to where the cast will land.
func _between(dir: Vector2, tiles: float, lean: float) -> Vector2:
	# Off the tile, not `position`: the angler has only just been stood there and has not
	# had a frame to move its picture.
	var from := Iso.tile_to_world(_angler.tile_pos.x, _angler.tile_pos.y)
	var to := _target(dir, tiles)
	if to == Vector2.INF:
		return from
	return from.lerp(to, lean)


## Let the game's own camera have the view: follow, cast look-in and the way home.
func _free() -> void:
	_hold = Vector2.INF
	_follow = null
	_main.set(&"_pan", Vector2.ZERO)
	_main.set(&"_panning", false)


## Throw `tiles` out along `dir`. `lucky` is the gold net and the double cast beside it,
## rolled by hand rather than by the odds.
func _cast(dir: Vector2, tiles: float, lucky: bool = false, double: bool = lucky) -> void:
	_main.call(&"_push_net_numbers")
	var where := _target(dir, tiles)
	if where != Vector2.INF and _net.cast_to(where):
		if lucky:
			_net.luck_power = 1
			_net.luck_hold = Lake.LUCKY_EXTRA
		if double:
			var net2: CastNet = _main.get(&"_net2")
			var spot: Vector2 = _main.call(&"_double_spot", Iso.world_to_tile(where))
			if net2 != null and spot != Vector2.INF:
				net2.cast_to(Iso.tile_to_world(spot.x, spot.y))
			else:
				_say("  no double spot by %s" % str(where))
		return
	var probe := _angler.tile_pos + dir.normalized() * tiles
	_say("  cast refused at %s: state %d range %.1f hold %d angler %s probe %s island %.2f shore %.2f" % [
			str(where), _net.state, _net.range_tiles, _net.hold, str(_angler.tile_pos), str(probe),
			Iso.island_fraction(probe.x, probe.y), Iso.shore_fraction(probe.x, probe.y)])


## Clean `share` of the lake's floating rubbish, in pools rather than a disc: every water
## tile has a value off one blobby noise field, and the tiles under the share's quantile
## are emptied. The field is fixed, so a bigger share only grows the same pools, and what
## is left between them is spots of grime, not a ring. Taken the way the net takes, so the
## meter and the filth map follow.
func _thin(share: float, keeps: Array = [], keep_near: float = KEEP_NEAR) -> void:
	_noise.seed = thin_seed
	_noise.frequency = 0.11
	_noise.fractal_octaves = 3
	var values := PackedFloat32Array()
	var tiles := PackedInt32Array()
	for index in _grid.stacks.size():
		if _grid.dry[index] == 1 or _grid.stacks[index].is_empty():
			continue
		var tile := Vector2(float(index % Iso.COLS), floorf(float(index) / float(Iso.COLS)))
		# Nearer the island cleans first, a little: the player works outwards.
		var far := tile.distance_to(Iso.ISLAND_CENTRE) / 40.0
		# Where the next net lands stays foul, so a cast in the trailer always takes.
		var kept := 0.0
		for keep in keeps:
			if tile.distance_to(keep) < keep_near:
				kept = 2.0
		values.append(_noise.get_noise_2d(tile.x, tile.y) + far * 0.25 + kept)
		tiles.append(index)
	if tiles.is_empty():
		return
	var sorted := values.duplicate()
	sorted.sort()
	var cut := sorted[clampi(int(share * sorted.size()), 0, sorted.size() - 1)]
	var taken := 0
	for i in tiles.size():
		if values[i] > cut:
			continue
		var index := tiles[i]
		while not _grid.stacks[index].is_empty():
			var def_index := _grid.take(index, _grid.stacks[index].size() - 1)
			if not _grid.defs[def_index].keepsake:
				_main.call(&"_on_net_caught", def_index)
			taken += 1
	_say("  thinned %.0f%%: %d taken, %d left" % [share * 100.0, taken, _grid.piece_count()])


## The island as the store shows it (2026-10-02, Richard): the hut in its second look, the
## tidied one, and the crate heaped full. Cheap enough to call every frame; the crate is only
## topped up, never emptied, and hidden hulls are moored so they do not carry it off.
func _dress_island() -> void:
	_main.set(&"shed_stage_pin", 1)
	var yard: Yard = _main.get(&"_yard")
	if yard.held.size() < Yard.CRATE_FULL + 6:
		var rubbish: Array = []
		for i in _grid.defs.size():
			if not _grid.defs[i].keepsake:
				rubbish.append(i)
		while yard.held.size() < Yard.CRATE_FULL + 6:
			yard.put(rubbish[_rng.randi_range(0, rubbish.size() - 1)])
	for boat: Boat in _main.get(&"_boats"):
		if not boat.visible:
			boat.moored = true


## Nature spread out rather than heaped (2026-10-02, Richard: "it should look natural and
## spread out on the shot"): of every kind of animal, one closer than `apart` world px to one
## already kept is sent away, so no beach is a crowd of frogs and turtles. Kinds are spaced
## against every kind, not only their own.
func _spread_life(apart: float) -> void:
	var wild: Wildlife = _main.get(&"_wildlife")
	var kept: Array[Vector2] = []
	var left := 0
	for key in [&"_broods", &"_turtles", &"_frogs", &"_critters_on_land", &"_flies"]:
		var list: Array = wild.get(key)
		var keep: Array = []
		for a: Dictionary in list:
			var at: Vector2 = a.get("to", a["at"]) if key == &"_broods" else a["at"]
			var near := false
			for k in kept:
				if k.distance_to(at) < apart:
					near = true
					break
			if near:
				continue
			kept.append(at)
			keep.append(a)
		list.assign(keep)
		left += keep.size()
	wild.held = true
	_say("  life spread %.0f px: %d kept" % [apart, left])


## The pack back to the one dog, so the casts and the ferries are not full of dogs.
func _unpack() -> void:
	var dogs: Array = _main.get(&"_dogs")
	while dogs.size() > 1:
		var dog: Node = dogs.pop_back()
		dog.queue_free()
	_main.set(&"dog_count_level", 0)


## The whole pack, each dog started fresh beside the angler.
func _pack() -> void:
	while _main.get(&"dog_count_level") < 3:
		_main.set(&"dog_count_level", _main.get(&"dog_count_level") + 1)
		_main.call(&"_add_dog")
	var dogs: Array = _main.get(&"_dogs")
	for i in dogs.size():
		var dog: Node2D = dogs[i]
		dog.set(&"tile_pos", Iso.ISLAND_CENTRE + Vector2(3.4, -3.4) + Vector2(0.9, 0.9) * float(i - 1))
		dog.set(&"_state", 0)
		dog.set(&"_mood_left", 0.5 + 0.7 * float(i))


func _settle_of(name: String) -> int:
	return int(SETTLE_LONG.get(name, SETTLE))


## The HUD is up for the wash room, which lives on its layer; its buttons are not in the shot.
func _hide_hud_buttons() -> void:
	for key in [&"_open_upgrades", &"_open_settings", &"_free_camera"]:
		var node: CanvasItem = _main.get(key)
		if node != null:
			node.visible = false


## The fleet parked at the island blocks the casts' view; the ferries' shot is where it works.
func _hide_boats() -> void:
	for boat: Node2D in _main.get(&"_boats"):
		boat.visible = false
		# Moored as well as hidden (2026-10-02, Richard): a hidden hull still loaded a full
		# crate, so pieces flew to nothing and its bow spray crossed the water on its own.
		boat.set(&"moored", true)


# --- trailer v2 -----------------------------------------------------------------------------

## The frame rate the run was started at (`--fixed-fps`, said again in `FILM_FPS`), so
## seconds become frames.
var _fps := 60.0
## The hour every v2 shot is held at, so the cuts match; under nought the day runs.
var _phase := -1.0
const DAY_PHASE := 0.35
## Kept frames after which the shot ends early; under nought, its seconds decide.
var _end_at := -1
var _sfx_log: FileAccess
var _pointer_log: FileAccess
var _camera_log: FileAccess
var _cam_was := Vector2.ZERO
var _cam_scale_was := 1.0
var _pointer_on := false
var _pointer := Vector2.ZERO

const OPEN_STAND := Vector2(3.4, -3.4)
const OPEN_DOG := Vector2(-0.6, 1.0)
const OPEN_TILES := 6.0
const OPEN_ZOOM := 4.0
## Frames after the settle the push takes, and the one the first net is thrown on.
const OPEN_PUSH := 150.0
const OPEN_THROW := 136
## The virtual zoom (screen px an art px) past which the vertical film's push hands over from
## a zoom-2 source to zoom 3: a little past 3, so the source view always holds the edit's.
const OPEN_HANDOVER := 3.15
var _open_from := Vector2.ZERO
var _open_to := Vector2.ZERO

const CAST2_STAND := Vector2(-3.6, 3.6)
const CAST2_TILES := 7.5

const GOLD_STAND := Vector2(3.9, -3.3)
const GOLD_TILES := 8.5
const GOLD_UP := Vector2(-3.4, -3.4)
const GOLD_DOWN := Vector2(3.9, 3.9)
const GOLD_THROW := 1.0

## The board: frames each purchase takes, the pointer's glide to the tag inside it, and the
## click.
const SHOP_EACH := 80
const SHOP_MOVE := Vector2i(12, 46)
const SHOP_CLICK := 58
var _shop_buys: Array = []
var _shop_bought := 0.0
var _shop_from := Vector2.ZERO


## The landscape number, or the vertical film's.
func _t(wide: Variant, tall: Variant) -> Variant:
	return tall if _tall else wide


func _sec(seconds: float) -> int:
	return SETTLE + int(round(seconds * _fps))


func _levels(width: int, hold: int, reach: int, reel: int, strength: int = 4) -> void:
	_main.set(&"net_strength_level", strength)
	_main.set(&"net_width_level", width)
	_main.set(&"net_hold_level", hold)
	_main.set(&"net_range_level", reach)
	_main.set(&"reel_level", reel)
	_main.call(&"_push_net_numbers")


func _dog_beside(off: Vector2) -> void:
	var dog: Node2D = (_main.get(&"_dogs") as Array)[0]
	dog.set(&"tile_pos", _angler.tile_pos + off)


func _sit_dog(off: Vector2, left: bool) -> void:
	var dog: Node2D = (_main.get(&"_dogs") as Array)[0]
	dog.set(&"tile_pos", _angler.tile_pos + off)
	dog.set(&"_state", Dog.State.SIT)
	dog.set(&"_mood_left", 600.0)
	dog.set(&"facing_left", left)


## The HUD up for the haul's count over the angler only: the corner plates, the meter and the
## buttons hidden.
func _count_only() -> void:
	(_main.get_node(^"HUD") as CanvasLayer).visible = true
	(_main.get(&"_skin") as CanvasItem).visible = false
	_hide_hud_buttons()


func _hud_off() -> void:
	(_main.get_node(^"HUD") as CanvasLayer).visible = false


## The money and Waiting plates only, so a coin has a purse to land in.
func _plates() -> void:
	(_main.get_node(^"HUD") as CanvasLayer).visible = true
	var skin: HudSkin = _main.get(&"_skin")
	skin.visible = true
	skin.plates_only = true
	_hide_hud_buttons()


## The window's stretch, worked out from the sizes the probe set rather than read off the
## viewport each frame (2026-10-08): under Movie Maker the reading went wrong for a few frames
## while the window settled, and the game's pixel snap threw the held camera hundreds of
## pixels about (the first scene's zoom-in jumped).
var _fixed_stretch := 1.5


func _stretch() -> float:
	return _fixed_stretch


## The game's own pixel snap of the camera, on the fixed stretch.
func _snap() -> void:
	var per := _camera.zoom.x * _stretch()
	if per <= 0.0:
		return
	var drawn := (_camera.position * per).round() / per
	_camera.offset = drawn - _camera.position


func _shop_open(buys: Array) -> void:
	_hide_boats()
	_shop_buys = buys
	# The board as a run that far in has it: Strength not yet bought (the casts are filmed
	# at full strength so nothing stops their dig, which the board must not show).
	_main.set(&"net_strength_level", 0)
	_main.call(&"_push_net_numbers")
	(_main.get_node(^"HUD") as CanvasLayer).visible = true
	var skin: HudSkin = _main.get(&"_skin")
	skin.visible = true
	skin.plates_only = false
	_main.call(&"_set_menu", true)
	_pointer_on = true
	if _tall:
		_window(TALL_SHOP_WINDOW, TALL_SHOP_CANVAS)
		_pointer = Vector2(300.0, 960.0) * (float(TALL_SHOP_WINDOW.x) / float(TALL_SHOP_CANVAS.x))
	else:
		_pointer = Vector2(640.0, 600.0) * _stretch()
	_phase = DAY_PHASE


func _shop_close() -> void:
	if bool(_main.get(&"_menu_open")):
		_main.call(&"_set_menu", false)
	_pointer_on = false
	_hud_off()


## Where a row's price tag stands, in window pixels.
func _tag_of(key: StringName) -> Vector2:
	var shop: ShopSkin = _main.get(&"_shop_skin")
	for entry: Dictionary in shop.pad_focus():
		if not entry.has("at") or typeof(entry["key"]) != TYPE_INT:
			continue
		var row: Dictionary = shop.rows[int(entry["key"])]
		if StringName(row["key"]) == key:
			return (shop.get_global_transform_with_canvas() * (entry["at"] as Vector2)) * _stretch()
	return Vector2.INF


func _shop_step(k: int) -> void:
	_hide_hud_buttons()
	var shop: ShopSkin = _main.get(&"_shop_skin")
	if _tall:
		# The vertical frame is the whole window's height: the meter and the Waiting plate
		# would stand in it, and the pricing plate under LUCK and BOATS would be cut in half by
		# the edit's crop. The purse is its own node and stays.
		(_main.get(&"_skin") as CanvasItem).visible = false
		if shop.get(&"_legend_box") != Rect2():
			shop.set(&"_legend_box", Rect2())
			shop.queue_redraw()
	if k == 4:
		var boards: Dictionary = shop.get(&"_boards")
		var at := shop.get_global_transform_with_canvas()
		for name: StringName in boards:
			var r: Rect2 = at * (boards[name] as Rect2)
			_say("  board %s %d %d %d %d" % [name, r.position.x * _stretch(), r.position.y * _stretch(),
					r.size.x * _stretch(), r.size.y * _stretch()])
	var i := k / SHOP_EACH if k >= 0 else -1
	var t := k % SHOP_EACH if k >= 0 else -1
	if i < 0 or i >= _shop_buys.size():
		_move_pointer(_pointer)
		return
	var key: StringName = _shop_buys[i]
	var tag := _tag_of(key)
	if tag == Vector2.INF:
		if t == 0:
			_say("  shop: no tag for %s" % key)
		_move_pointer(_pointer)
		return
	if t == SHOP_MOVE.x:
		_shop_from = _pointer
	if t >= SHOP_MOVE.x and t <= SHOP_MOVE.y:
		var u := float(t - SHOP_MOVE.x) / float(SHOP_MOVE.y - SHOP_MOVE.x)
		_move_pointer(_shop_from.lerp(tag, 1.0 - pow(1.0 - u, 3.0)))
	else:
		_move_pointer(_pointer)
	if t == SHOP_CLICK:
		_shop_bought = float(_main.get(&"sludge"))
		_click(true)
	elif t == SHOP_CLICK + 1:
		_click(false)
	elif t == SHOP_CLICK + 4 and float(_main.get(&"sludge")) >= _shop_bought:
		_say("  shop: the click did not buy %s, buying by hand" % key)
		shop.bought.emit(key)
	elif t == SHOP_CLICK + 5:
		_say("  shop: %s bought on kept frame %d, purse %d" % [key, _kept, int(_main.get(&"sludge"))])


## The pointer to `at` (window px), as a real motion so the board's hover answers.
func _move_pointer(at: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	ev.global_position = at
	ev.relative = at - _pointer
	_pointer = at
	Input.warp_mouse(at)
	Input.parse_input_event(ev)


func _click(down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = _pointer
	ev.global_position = _pointer
	Input.parse_input_event(ev)


## Every sound the game starts while frames are being kept, on the kept frame it starts.
func _on_played(path: String, db: float, pitch: float) -> void:
	if _sfx_log == null or _shot < 0 or _shot >= _shots.size():
		return
	if _shot_frame < _settle_of(_shots[_shot][0]):
		return
	_sfx_log.store_line("%d %s %.2f %.4f" % [_kept, path, db, pitch])
	_sfx_log.flush()


## Pieces close in off the east beach for the pack: a spot each, three tiles out.
func _near_sticks() -> Array:
	var from := Iso.ISLAND_CENTRE + Vector2(3.4, -3.4)
	var out: Array = []
	for dir in [Vector2(1.0, -1.0), Vector2(0.3, -1.0), Vector2(1.0, -0.3), Vector2(0.6, -0.8)]:
		out.append(from + dir.normalized() * 3.2)
	return out


## Where each dog sits round the angler (tile offsets: either side of him and behind), and
## the kept frames it sits for before the first breaks for the water, the next `PACK_EVERY`
## after.
const PACK_SEATS := [Vector2(0.7, 0.7), Vector2(-0.7, -0.7), Vector2(-0.3, 1.2), Vector2(-1.2, 0.3)]
## Negative since 2026-10-08 (Richard: the dogs sat waiting, then moved): every dog has set
## off before the first kept frame, so the pack is running from the first frame shown.
const PACK_SIT := -40
const PACK_EVERY := 16


func _seat_pack() -> void:
	var dogs: Array = _main.get(&"_dogs")
	for i in dogs.size():
		(dogs[i] as Node2D).set(&"tile_pos", _angler.tile_pos + PACK_SEATS[i % PACK_SEATS.size()])


## Sat, facing the water, until each dog's turn; then off after its piece.
func _run_pack(k: int) -> void:
	var dogs: Array = _main.get(&"_dogs")
	var sticks := _near_sticks()
	for i in dogs.size():
		var dog: Node2D = dogs[i]
		var go := PACK_SIT + i * PACK_EVERY
		if k < go:
			dog.set(&"tile_pos", _angler.tile_pos + PACK_SEATS[i % PACK_SEATS.size()])
			dog.set(&"_state", Dog.State.SIT)
			dog.set(&"_mood_left", 600.0)
			dog.set(&"facing_left", false)
		elif k == go:
			_send_dog(dog, sticks[i % sticks.size()])


## One dog off for the floating piece nearest `spot` (tiles).
func _send_dog(dog: Node2D, spot: Vector2) -> void:
	var best := -1
	var best_d := 1.0e9
	for index in _grid.stacks.size():
		if _grid.dry[index] == 1 or _grid.stacks[index].is_empty():
			continue
		var d := Vector2(_grid.tile_of(index)).distance_to(spot)
		if d < best_d:
			best_d = d
			best = index
	if best < 0:
		return
	dog.call(&"_aim_at", best)
	dog.set(&"_to_strand", false)
	dog.set(&"_trip", 0.0)
	dog.set(&"_state", 4)
	_say("  dog off on kept frame %d" % _kept)


## The water round `centre` (tiles) stocked `per_tile` pieces deeper on every wet tile within
## `reach`, so a net landing there digs until its bag is full and comes home N/N.
func _stock(centre: Vector2, reach: float, per_tile: int) -> void:
	var pieces: Array = []
	for i in _grid.defs.size():
		if not _grid.defs[i].keepsake:
			pieces.append(i)
	var at := _grid.tile_at(Iso.tile_to_world(centre.x, centre.y))
	if at < 0:
		return
	var added := 0
	for index: int in _grid.tiles_within(at, reach):
		if _grid.dry[index] == 1:
			continue
		for n in per_tile:
			_grid.insert(index, 0, pieces[_rng.randi_range(0, pieces.size() - 1)])
			added += 1
		_grid.bump(index)
	_say("  stocked %d pieces round %s" % [added, str(centre.round())])


## Two small pieces dropped on the water at each spot, a dog's mouthful each, so the pack
## has something close in to fetch whatever the thinning left there.
func _plant_sticks(spots: Array) -> void:
	var small: Array = []
	for i in _grid.defs.size():
		var def: TrashDef = _grid.defs[i]
		if not def.keepsake and def.tier == 0:
			small.append(i)
	for spot: Vector2 in spots:
		var index := _grid.tile_at(Iso.tile_to_world(spot.x, spot.y))
		if index < 0 or _grid.dry[index] == 1:
			continue
		for n in 2:
			_grid.insert(index, _grid.height_of(index), small[_rng.randi_range(0, small.size() - 1)])
		_grid.bump(index)


## Every find in the water taken out, so no beam stands in a shot.
func _drop_finds() -> void:
	var dropped := 0
	for index in _grid.stacks.size():
		var stack: Array = _grid.stacks[index]
		for slot in range(stack.size() - 1, -1, -1):
			if _grid.defs[stack[slot]].keepsake:
				_grid.take(index, slot)
				dropped += 1
	_say("  finds dropped: %d" % dropped)


## The gold net up the screen and the double down it, each at its own spot.
func _cast_pair(tiles: float, up: Vector2, down: Vector2) -> void:
	_main.call(&"_push_net_numbers")
	var land := _angler.tile_pos + ACROSS.normalized() * tiles
	var one := land + up
	var two := land + down
	if _net.cast_to(Iso.tile_to_world(one.x, one.y)):
		_net.luck_power = 1
		_net.luck_hold = Lake.LUCKY_EXTRA
	else:
		_say("  gold net refused at %s" % str(one))
	var net2: CastNet = _main.get(&"_net2")
	if net2 == null or not net2.cast_to(Iso.tile_to_world(two.x, two.y)):
		_say("  double net refused at %s" % str(two))


# --- the pier (from the store's shot_steam.gd, 2026-10-02) -----------------------------------

const PIER_IN := 1.2
const PIER_NORTH := 13.0
const PIER_GO := 80
const PIER_SLOW := 0.8
const PIER_HOLD := 64
const PIER_VOLLEY := 4
const PIER_BOX_START := 8
const LIFE_APART := 70.0
var _grown := PackedFloat32Array()
var _pier_unloading := false


func _pose_pier() -> void:
	_hide_boats()
	_unpack()
	thin_seed = 37
	_thin(0.45)
	_drop_finds()
	_main.set(&"sludge", 9860.0)
	while int(_main.get(&"fleet_level")) < 1:
		_main.set(&"fleet_level", int(_main.get(&"fleet_level")) + 1)
		_main.call(&"_add_boat")
	_main.set(&"boat_speed_level", 2)
	_main.set(&"cargo_level", 8)
	_main.set(&"boat_volley_level", PIER_VOLLEY)
	_main.call(&"_push_boat_numbers")
	var yard: Yard = _main.get(&"_yard")
	var rubbish: Array = []
	var wood: Array = []
	for i in _grid.defs.size():
		var def: TrashDef = _grid.defs[i]
		if def.keepsake:
			continue
		rubbish.append(i)
		if def.material == TrashDef.Kind.WOOD:
			wood.append(i)
	while yard.held.size() < 118:
		yard.put(rubbish[_rng.randi_range(0, rubbish.size() - 1)])
	var pier: Dropoff = (_main.get(&"_dropoffs") as Array)[TrashDef.Kind.WOOD]
	var out := pier.axis.normalized()
	var boats: Array = _main.get(&"_boats")
	for k in boats.size():
		var boat: Boat = boats[k]
		boat.visible = true
		boat.auto_ferry = false
		boat.patrol = false
		var hold := PackedInt32Array()
		for i in PIER_HOLD:
			hold.append(wood[_rng.randi_range(0, wood.size() - 1)])
		boat.cargo = hold
		boat.tile_pos = (
			pier.berth + out * PIER_IN if k == 0
			else pier.berth + Vector2(-1.0, -1.0).normalized() * PIER_NORTH
		)
		boat.set(&"_route", [] as Array[int])
		boat.target = TrashDef.Kind.WOOD
		boat.state = Boat.State.DOCKED
		boat.moored = true
		boat.heading = -out if k == 0 else Vector2(1.0, 1.0).normalized()
	_zoom(3)
	_phase = DAY_PHASE
	var box := pier.drop_point()
	var far: Vector2 = (boats[1] as Boat).tile_pos
	_hold = box.lerp(Iso.tile_to_world(far.x, far.y), 0.45) + Vector2(-60.0, 0.0)
	_pier_unloading = false


func _run_pier(f: int) -> void:
	var k := f - SETTLE
	_plates()
	_dress_island()
	if k == -24:
		_spread_life(LIFE_APART)
	var wood_pier: Dropoff = (_main.get(&"_dropoffs") as Array)[TrashDef.Kind.WOOD]
	if not _pier_unloading and wood_pier.held_count() < PIER_BOX_START:
		var woods: Array = []
		for i in _grid.defs.size():
			if not _grid.defs[i].keepsake and _grid.defs[i].material == TrashDef.Kind.WOOD:
				woods.append(i)
		while wood_pier.held_count() < PIER_BOX_START:
			wood_pier.put(woods[_rng.randi_range(0, woods.size() - 1)])
	if k == -29:
		_flora_grown()
	if k >= -29:
		_hold_still()
	if k == PIER_GO:
		for each: Boat in _main.get(&"_boats"):
			each.moored = false
			each.set(&"_legs", each.call(&"_plan_legs", each.tile_pos, wood_pier.berth))
			each.state = Boat.State.SAILING
		((_main.get(&"_boats") as Array)[1] as Boat).speed = PIER_SLOW
	var boat: Boat = (_main.get(&"_boats") as Array)[0]
	if not _pier_unloading and k > PIER_GO and boat.state == Boat.State.UNLOADING \
			and bool(boat.get(&"_landing")):
		_pier_unloading = true
		_say("  pier: unloading on kept frame %d" % _kept)


## Every plant already due shown full grown, and remembered, so nothing sprouts on camera.
func _flora_grown() -> void:
	var flora: Flora = _main.get(&"_flora")
	var ages: PackedFloat32Array = flora.get(&"_age")
	for k in ages.size():
		if ages[k] >= 0.0:
			ages[k] = 1.0e6
	flora.set(&"_age", ages)
	flora.set(&"_growing", 0)
	flora.set(&"_dirty", true)
	flora.queue_redraw()
	_grown = ages


## Plants the cleared water makes due put back, and pigeons not called in: every frame.
func _hold_still() -> void:
	var flora: Flora = _main.get(&"_flora")
	var ages: PackedFloat32Array = flora.get(&"_age")
	var undone := false
	for k in ages.size():
		if ages[k] >= 0.0 and k < _grown.size() and _grown[k] < 0.0:
			ages[k] = -1.0
			undone = true
	if undone:
		flora.set(&"_age", ages)
		flora.set(&"_growing", 0)
		flora.set(&"_dirty", true)
		flora.queue_redraw()
	(_main.get(&"_flock") as Flock).set(&"_rethink", 1.0e9)


# --- the tornado (from shot_steam.gd), filmed whole at 240 fps -------------------------------

## Off the island's screen-right beach in the landscape film; up and to the right in the
## vertical one, so the column stands over the angler rather than beside him.
var TORN_ANGLE: float = -0.785 if OS.get_environment("FILM_TALL") == "" else -1.95
const TORN_CLEAN := 0.45
const TORN_CLEAR := 6.5
const TORN_CARRY := 56
const TORN_FEED_EVERY := 0.035
const TORN_BAND := Vector2(0.06, 0.62)
const TORN_MARGIN := Vector2(30.0, 150.0)
var TORN_OUT: float = 13.0 if OS.get_environment("FILM_TALL") == "" else 15.0
const TORN_ZOOM := 3
## Seconds into the event the first net goes (the brew is `Tornado.BREW`, then the
## touchdown), the least between throws, and how long a landed net that is not the last is
## left before it is called home for the next one.
const TORN_FIRST := 10.0
const TORN_GAP := 1.3
const TORN_HOME_AFTER := 0.35
## Seconds kept after the funnel is gone.
const TORN_AFTER := 3.0
var _torn_last_cast := -100.0
var _torn_landed_at := -1.0
var _torn_fed := 0.0
var _torn_ended := false


func _pose_tornado() -> void:
	_hide_boats()
	_unpack()
	_drop_finds()
	_levels(18, 6, 18, 14)
	_main.set(&"sludge", 21340.0)
	var t: Node = _main.get(&"_tornado")
	t.call(&"start", TORN_ANGLE)
	t.set(&"_grow", TORN_OUT)
	t.set(&"_base", Iso.island_point(TORN_ANGLE, TORN_OUT))
	t.set(&"_base_was", t.get(&"_base"))
	var foot := Iso.world_to_tile(t.call(&"base"))
	thin_seed = 51
	_thin(TORN_CLEAN, [], 7.0)
	_clear_round(foot, TORN_CLEAR)
	_angler.stand_at(Iso.world_to_tile(Iso.island_point(TORN_ANGLE, -0.6)))
	_torn_last_cast = -100.0
	_torn_landed_at = -1.0
	_torn_fed = 0.0
	_torn_ended = false
	_angler.call(&"_turn_to", foot)
	_zoom(TORN_ZOOM)
	_phase = DAY_PHASE
	_hold = _torn_frame(t)


func _torn_frame(t: Node) -> Vector2:
	var base: Vector2 = t.call(&"base")
	if _tall:
		return _angler.position.lerp(base, 0.5) - Vector2(0.0, 130.0)
	return _angler.position.lerp(base, 0.56) - Vector2(0.0, 70.0)


func _run_tornado(f: int) -> void:
	_count_only()
	var t: Node = _main.get(&"_tornado")
	var k := f - SETTLE
	if k == -29:
		_flora_grown()
	if k >= -29:
		_hold_still()
	if not bool(t.call(&"active")):
		if not _torn_ended and k > 0:
			_torn_ended = true
			_end_at = _kept + int(TORN_AFTER * _fps)
			_say("  tornado: gone on kept frame %d" % _kept)
		return
	var since: float = t.get(&"_t")
	t.set(&"_theta", TORN_ANGLE)
	t.set(&"_grow", TORN_OUT)
	_hold = _torn_frame(t)
	# Facing the funnel before every throw (2026-10-08, Richard: he stood facing away from it
	# until the cast turned him).
	if _net.state == CastNet.State.IDLE:
		_angler.call(&"_turn_to", Iso.world_to_tile(t.call(&"base")))
	if since >= 1.5 and since - _torn_fed >= TORN_FEED_EVERY:
		_torn_fed = since
		_feed_tornado(t)
	_spread_whirl(t)
	t.set(&"_fling_in", 1.0e9)
	var hits := int(t.call(&"hits"))
	# A landed net that is not the last is called home, for the next throw.
	if _net.state == CastNet.State.SETTLED or _net.state == CastNet.State.REELING:
		if _torn_landed_at < 0.0:
			_torn_landed_at = since
			_say("  tornado: net lands on kept frame %d, hits %d" % [_kept, hits])
		elif hits < 3 and since - _torn_landed_at >= TORN_HOME_AFTER:
			_net.call(&"_come_home")
	if hits < 3 and since >= TORN_FIRST and _net.state == CastNet.State.IDLE \
			and since - _torn_last_cast >= TORN_GAP:
		_angler.stand_at(Iso.world_to_tile(Iso.island_point(TORN_ANGLE, -0.6)))
		var v: Vector2 = t.get(&"_velocity")
		var foot: Vector2 = t.call(&"base") + v * 0.35
		_main.call(&"_cast_at", foot)
		if _net.state != CastNet.State.IDLE:
			_torn_last_cast = since
			_torn_landed_at = -1.0
			_say("  tornado: cast %d on kept frame %d, carrying %d" % [hits + 1, _kept,
					int(t.call(&"carrying"))])


func _clear_round(tile: Vector2, reach: float) -> void:
	var taken := 0
	for index in _grid.stacks.size():
		if _grid.stacks[index].is_empty() or _grid.dry[index] == 1:
			continue
		if (Vector2(_grid.tile_of(index)) + Vector2(0.5, 0.5)).distance_to(tile) > reach:
			continue
		while not _grid.stacks[index].is_empty():
			var def_index := _grid.take(index, _grid.stacks[index].size() - 1)
			if not _grid.defs[def_index].keepsake:
				_main.call(&"_on_net_caught", def_index)
			taken += 1
	_say("  cleared round the funnel: %d" % taken)


func _spread_whirl(t: Node) -> void:
	for d: Dictionary in t.get(&"_debris") as Array:
		if d.has("spread"):
			continue
		d["spread"] = true
		d["band"] = _rng.randf_range(TORN_BAND.x, TORN_BAND.y)
		d["margin"] = _rng.randf_range(TORN_MARGIN.x, TORN_MARGIN.y)


func _feed_tornado(t: Node) -> void:
	var debris: Array = t.get(&"_debris")
	if debris.size() >= TORN_CARRY:
		return
	var base: Vector2 = t.call(&"base")
	var centre := _grid.tile_at(base)
	if centre < 0:
		return
	var here := Iso.world_to_tile(base)
	var best := -1
	var best_d := INF
	for index: int in _grid.tiles_within(centre, TORN_CLEAR + 4.0):
		var st: PackedInt32Array = _grid.stacks[index]
		if st.is_empty() or _grid.dry[index] == 1:
			continue
		var def: TrashDef = _grid.defs[st[st.size() - 1]]
		if def.keepsake or def.tier > 3:
			continue
		var d := (Vector2(_grid.tile_of(index)) + Vector2(0.5, 0.5)).distance_to(here)
		if d < best_d:
			best = index
			best_d = d
	if best < 0:
		return
	var from: Vector2 = _grid.surface_pos(best)
	var def_index: int = _grid.take(best, _grid.top_slot(best))
	_main.call(&"_on_net_caught", def_index)
	var rel := from - base
	var circ := Vector2(rel.x, rel.y * 2.0)
	debris.append({
		"def_index": def_index, "def": _grid.defs[def_index], "state": "lift", "age": 0.0,
		"angle": atan2(circ.y, circ.x), "r0": circ.length(), "radius": circ.length(),
		"height": 0.0, "band": _rng.randf_range(0.22, 0.88), "margin": _rng.randf_range(6.0, 22.0),
		"seed": _rng.randf() * TAU, "whirl": _rng.randf_range(0.75, 1.35), "rot": _grid.tilt[best],
		"spin_rate": _rng.randf_range(-5.0, 5.0),
		"scale": 1.0, "alpha": 1.0, "local": rel, "front": rel.y > 0.0, "depth": rel.y,
		"ground": rel, "from_tile": best,
	})


# --- grime to beauty (from shot_steam.gd), no hive colony, a long tail for the end card -----

const BEAUTY_CLEAN := 600
const BEAUTY_WOBBLE := 6.0
## The wave's reach goes as the clock to this power: under 2 it spends less of its time near
## the island and clears visibly from the first frames (2026-10-03, Richard: "sooner").
const BEAUTY_PACE := 1.35
## Songbirds called in, one every so many frames, to spots in the shot, up to this many.
const BEAUTY_BIRDS := 26
const BEAUTY_BIRD_EVERY := 9
const BEAUTY_BIRD_REACH := 520.0
const BEAUTY_MOST := 0.97
const BEAUTY_LEAD := 8
const BEAUTY_APART := 80.0
const BEAUTY_SPREAD_EVERY := 20
const BEAUTY_STAND := Vector2(-0.9, 0.7)
const BEAUTY_DOG := Vector2(-1.0, 1.6)
const BEAUTY_PADS := 0.3
const BEAUTY_DUCKS_AT := 0.55
const BEAUTY_DUCKS := Vector2(140.0, 190.0)
var _beauty_ducks := false
var _beauty_order: Array = []
var _beauty_key: Array = []
var _beauty_next := 0


func _pose_beauty() -> void:
	_hide_boats()
	_unpack()
	_drop_finds()
	_main.set(&"shed_stage_pin", -1)
	(_main.get(&"_hive") as Hive).set_stage(Hive.Stage.EMPTY)
	var yard: Yard = _main.get(&"_yard")
	var crate := Iso.world_to_tile(yard.position)
	_angler.stand_at(crate + BEAUTY_STAND)
	_angler.facing = Vector2(1.0, 1.0).normalized()
	var dog: Node2D = (_main.get(&"_dogs") as Array)[0]
	dog.set(&"tile_pos", crate + BEAUTY_DOG)
	var rubbish: Array = []
	for i in _grid.defs.size():
		if not _grid.defs[i].keepsake:
			rubbish.append(i)
	while yard.held.size() < Yard.CRATE_FULL + 6:
		yard.put(rubbish[_rng.randi_range(0, rubbish.size() - 1)])
	_noise.seed = 77
	_noise.frequency = 0.06
	var pairs: Array = []
	for index in _grid.stacks.size():
		if _grid.stacks[index].is_empty():
			continue
		var tile := Vector2(_grid.tile_of(index)) + Vector2(0.5, 0.5)
		var key := Iso.past_shelf(tile) + _noise.get_noise_2d(tile.x, tile.y) * BEAUTY_WOBBLE
		pairs.append([key, index])
	pairs.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	_beauty_order = pairs.map(func(p: Array) -> int: return p[1])
	_beauty_key = pairs.map(func(p: Array) -> float: return p[0])
	_beauty_next = 0
	_beauty_ducks = false
	_zoom(3)
	_phase = DAY_PHASE
	_hold = Iso.tile_to_world(Iso.ISLAND_CENTRE.x, Iso.ISLAND_CENTRE.y) + Vector2(0.0, 10.0)


func _run_beauty(f: int) -> void:
	var k := f - SETTLE
	_hud_off()
	_angler.facing = Vector2(1.0, 1.0).normalized()
	_angler.call(&"_repaint")
	var dog: Node2D = (_main.get(&"_dogs") as Array)[0]
	var crate := Iso.world_to_tile((_main.get(&"_yard") as Yard).position)
	dog.set(&"tile_pos", crate + BEAUTY_DOG)
	dog.set(&"_state", Dog.State.LOUNGE)
	dog.set(&"_mood_left", 600.0)
	dog.set(&"facing_left", true)
	var hive: Hive = _main.get(&"_hive")
	if hive.stage != Hive.Stage.EMPTY:
		hive.set_stage(Hive.Stage.EMPTY)
	var t := clampf(float(k - BEAUTY_LEAD) / float(BEAUTY_CLEAN), 0.0, 1.0)
	if k >= BEAUTY_LEAD:
		var last := int(BEAUTY_MOST * float(_beauty_order.size())) - 1
		var reach: float = float(_beauty_key[last]) * pow(t, BEAUTY_PACE)
		var upto := _beauty_next
		while upto <= last and float(_beauty_key[upto]) <= reach:
			upto += 1
		while _beauty_next < upto:
			var index: int = _beauty_order[_beauty_next]
			_beauty_next += 1
			while not _grid.stacks[index].is_empty():
				var def_index := _grid.take(index, _grid.stacks[index].size() - 1)
				if not _grid.defs[def_index].keepsake:
					_main.call(&"_on_net_caught", def_index)
	(_main.get(&"_wildlife") as Wildlife).set(&"_brood_in", 1.0e9)
	if k > BEAUTY_LEAD and k % BEAUTY_BIRD_EVERY == 0:
		_bird_in_view()
	if t >= BEAUTY_DUCKS_AT and not _beauty_ducks:
		_beauty_ducks = _duck_family()
	if k > 0 and k % BEAUTY_SPREAD_EVERY == 0:
		_thin_crowd(BEAUTY_APART)
	_fewer_pads()
	if k == BEAUTY_LEAD:
		_say("  beauty: the wave starts on kept frame %d" % _kept)
	if k == BEAUTY_LEAD + BEAUTY_CLEAN:
		_say("  beauty: the wave ends on kept frame %d" % _kept)


## One more songbird flying in to an open spot inside the shot, until `BEAUTY_BIRDS`.
func _bird_in_view() -> void:
	var wild: Wildlife = _main.get(&"_wildlife")
	var birds: Array = wild.get(&"_birds")
	if birds.size() >= BEAUTY_BIRDS:
		return
	for attempt in 12:
		var b: Dictionary = wild.call(&"_new_bird")
		if b.is_empty():
			return
		if (b["to"] as Vector2).distance_to(_hold) < BEAUTY_BIRD_REACH:
			birds.append(b)
			return


func _fewer_pads() -> void:
	var flora: Flora = _main.get(&"_flora")
	var ages: PackedFloat32Array = flora.get(&"_age")
	var ranks: PackedFloat32Array = flora.get(&"_rank")
	var species: PackedStringArray = flora.get(&"_species")
	var table: Dictionary = flora.get(&"_table")
	var undone := false
	for k in ages.size():
		if ages[k] < 0.0 or ranks[k] < BEAUTY_PADS * Flora.MOST:
			continue
		var kind := String((table[species[k]] as Dictionary)["kind"])
		if kind == "water" or kind == "open":
			ages[k] = -1.0
			undone = true
	if undone:
		flora.set(&"_age", ages)
		flora.set(&"_dirty", true)
		flora.queue_redraw()


func _duck_family() -> bool:
	var wild: Wildlife = _main.get(&"_wildlife")
	var to := Iso.tile_to_world(Iso.ISLAND_CENTRE.x, Iso.ISLAND_CENTRE.y) + BEAUTY_DUCKS
	if not wild.call(&"_swimmable", to):
		return false
	for attempt in 40:
		var b: Dictionary = wild.call(&"_new_brood")
		if b.is_empty():
			return false
		if (b["kids"] as Array).size() < 3:
			continue
		var from := to + Vector2(520.0, -260.0)
		b["from"] = from
		b["at"] = from
		b["to"] = to
		b["goal"] = to
		b["facing"] = Flock.facing_of(from, to)
		b["timer"] = 1.0e6
		for kid: Dictionary in b["kids"]:
			kid["at"] = from
		(wild.get(&"_broods") as Array).append(b)
		_say("  beauty: ducks in on kept frame %d" % _kept)
		return true
	return false


func _thin_crowd(apart: float) -> void:
	var wild: Wildlife = _main.get(&"_wildlife")
	var kept: Array[Vector2] = []
	for key in [&"_broods", &"_turtles", &"_frogs", &"_critters_on_land", &"_flies"]:
		var list: Array = wild.get(key)
		var keep: Array = []
		for a: Dictionary in list:
			var at: Vector2 = a.get("to", a["at"]) if key == &"_broods" else a["at"]
			var near := false
			for p in kept:
				if p.distance_to(at) < apart:
					near = true
					break
			if near:
				continue
			kept.append(at)
			keep.append(a)
		list.assign(keep)
