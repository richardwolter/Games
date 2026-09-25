extends Node
## Films the shots the trailer is cut from: opens the lake on a real 1080p window, poses each
## shot (how clean the water is, where the angler stands, how wide the net is, how many hulls
## and dogs), and dumps every rendered frame as a JPEG so the edit can pick its cuts on the
## song's beat. The cut itself is `marketing/My Dirty Little Lake/trailer/build_trailer.py`.
##
## Run it with the desktop build, not --headless (nothing renders under the dummy driver),
## at a fixed 60 fps so game time is one sixtieth a frame however long a frame takes to save:
##
##   godot --path . --fixed-fps 60 res://tools/film_trailer.tscn
##
## `FILM_ONLY=walkout,dogs` re-shoots a few by name. Frames land in tools/film/<shot>/,
## the shot's own folder emptied first; tools/film/last_film.log says what was shot.
##
## Every shot holds the camera by hand (`_hold`) after the lake has had its say, so the
## follow, the cast look-in and the way home never move the view: the drift the trailer wants
## is put on in the edit, where it can be retuned without a re-shoot.

const SAVE_PATH := "user://film_trailer.save"
const OUT := "res://tools/film/%s/%05d.jpg"
const LOG_PATH := "res://tools/film/last_film.log"
const JPG_QUALITY := 0.94
## Frames the lake is given after a shot is posed before the first frame is kept: the zoom's
## rebuild and the filth map have to land, and a thinned lake has to settle.
const SETTLE := 40
## Tiles round a coming cast's landing spot that thinning leaves foul.
const KEEP_NEAR := 4.5
## Frames the walk-out starts before the first kept frame, so the angler is already
## striding when the trailer fades in.
const WALK_LEAD := 4
## The find on the wash stand, how long one sweep of the jet takes, and how many sweeps
## it takes to work down the picture.
const WASH_PIECE := "decor_sofa"
const WASH_SWEEP := 0.9
const WASH_ROWS := 7.0
## Frames a posed shot is given before its first kept frame, where the default is short:
## the wildlife has to arrive.
const SETTLE_LONG := {}
## Kept frames the wildlife shot sends a brood in on.
const WILD_BROODS := [0, 45, 100, 160, 230]

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

var _frames := 0
var _shots: Array = []
var _shot := -1
var _shot_frame := 0
var _kept := 0
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
var _rng := RandomNumberGenerator.new()


## The shot list. Each: name, seconds kept, setup, and a per-frame pose (frames since the
## shot was posed, counting the settle).
func _plan() -> void:
	_shots = [
		# The opening: from beside the box, down the beach to the water's edge, and the first
		# cast, short and narrow. The walk stops at the edge rather than pushing on it.
		["walkout", 8.0, func() -> void:
			_zoom(5)
			_main.set(&"net_width_level", 0)
			_angler.stand_at(Iso.ISLAND_CENTRE + Vector2(-5.2, -2.6))
			_angler.facing = DOWN.normalized()
			_free(),
		func(f: int) -> void:
			var edge := Iso.past_water(_angler.tile_pos) > -6.0
			_walk(f >= SETTLE - WALK_LEAD and f < SETTLE + 300 and not edge)
			if f >= SETTLE - WALK_LEAD and edge and not _walked:
				_walked = true
				_say("  walkout: at the edge on frame %d, angler %s" % [f - SETTLE, str(_angler.tile_pos)])
			if _walked and f == _walked_at + 20:
				_cast(DOWN, 4.0)
			if _walked and _walked_at < 0:
				_walked_at = f],
		# The lake still dirty, a few clear pools, held for the logo (Richard: a much dirtier
		# lake at the end). Thinning only ever cleans, so this and the ferries come first.
		["clean_hold", 8.5, func() -> void:
			_stand(Vector2(2.0, 2.0), DOWN)
			_pack()
			_thin(0.12, _hold_sticks(), 1.6)
			_zoom(2)
			_hold = Iso.tile_to_world(Iso.CENTRE.x, Iso.CENTRE.y),
		func(f: int) -> void:
			if f == SETTLE - 10:
				_send_dogs(_hold_sticks(), 2)
			if f % 60 == 0:
				var dogs: Array = _main.get(&"_dogs")
				var line := ""
				for dog in dogs:
					line += " %d@%s" % [dog.get(&"_state"), str((dog.get(&"tile_pos") as Vector2).round())]
				_say("  hold %d: dogs%s" % [f - SETTLE, line])],
		# The fleet: four hulls, a box full for all of them, the camera on the first hull
		# from its berth to the pier and back.
		["ferries", 30.0, func() -> void:
			_unpack()
			_main.set(&"net_width_level", 0)
			_thin(0.15)
			_fleet()
			_zoom(3)
			_stand(Vector2(0.0, 3.0), DOWN)
			_follow = _main.get(&"_boats")[0],
		func(_f: int) -> void:
			pass],
		# The wash room: the sofa on the stand, sprayed at real speed, a raster down the
		# picture that never leaves it and never finishes (2026-09-24, Richard's pick).
		["wash", 6.0, func() -> void:
			_follow = null
			_hold = Vector2.INF
			var waiting: Array = _main.get(&"unwashed")
			waiting.clear()
			waiting.append(WASH_PIECE)
			_main.set(&"sludge", 1000.0)
			(_main.get_node(^"HUD") as CanvasLayer).visible = true
			_main.call(&"_set_wash", true)
			_hide_hud_buttons()
			var room: WashRoom = _main.get(&"_wash")
			# The tray and the cross are the room's UI, not the washing (Richard, 2026-09-24).
			(room.get(&"_tray") as CanvasItem).visible = false
			(room.get(&"_close") as CanvasItem).visible = false
			_say("  wash: picked %s: %s" % [WASH_PIECE, str(room.pick(StringName(WASH_PIECE)))]),
		func(f: int) -> void:
			var room: WashRoom = _main.get(&"_wash")
			if room == null or f < SETTLE - 20:
				return
			_hide_hud_buttons()
			var box := room.stand().piece_box()
			var t := float(f - SETTLE + 20) / 60.0
			# Back and forth across the picture, a row every sweep, working down it.
			var sweep := t / WASH_SWEEP
			var across := absf(fmod(sweep, 2.0) - 1.0)
			var down := clampf(0.12 + 0.8 * t / (WASH_SWEEP * WASH_ROWS), 0.12, 0.92)
			room.stand().spray(box.position + box.size * Vector2(0.1 + 0.8 * across, down), true)
			if f % 60 == 0:
				_say("  wash %d: clean %.2f" % [f - SETTLE, room.stand().share_clean()])],
		# The pigeons: a few fly in and sit on the rubbish out along one bank, the net comes
		# down on them, and the head pops in with what they paid. Forced: the pop is a coin
		# toss in play (`Lake.POP_ODDS`), rolled here off a seed that comes up heads.
		["pigeon", 8.0, func() -> void:
			_zoom(5)
			_main.set(&"net_width_level", 4)
			_stand(Vector2(3.6, -3.6), ACROSS)
			_thin(0.3, [_angler.tile_pos + ACROSS.normalized() * 6.0])
			_perch_birds(ACROSS, 6.0)
			_free(),
		func(f: int) -> void:
			if f == SETTLE + 150:
				_force_pop()
				_cast(ACROSS, 6.0)
			if f == SETTLE + 150 + 40:
				_say("  pigeon: %d caught" % int(_main.get(&"birds_caught")))],
		["cast_3", 5.0, func() -> void:
			_hide_boats()
			_zoom(6)
			_main.set(&"net_width_level", 9)
			_stand(Vector2(-3.6, 3.6), LEFT)
			_thin(0.5, [_angler.tile_pos + LEFT.normalized() * 8.0])
			_free(),
		func(f: int) -> void:
			if f == SETTLE + 36:
				_cast(LEFT, 8.0)],
		["cast_5", 6.0, func() -> void:
			_hide_boats()
			_zoom(6)
			_main.set(&"net_width_level", 20)
			_stand(Vector2(3.6, -3.6), ACROSS)
			_thin(0.85, [_angler.tile_pos + ACROSS.normalized() * 13.0] + _dog_sticks())
			_free(),
		func(f: int) -> void:
			if f == SETTLE + 36:
				_cast(ACROSS, 13.0, true)],
		# The pack on the east beach, well away from the box: idling, and running to the
		# water for sticks.
		["dogs", 12.0, func() -> void:
			_hide_boats()
			_follow = null
			_stand(Vector2(3.4, -3.4), ACROSS)
			_pack()
			_zoom(6)
			_hold = Iso.tile_to_world(_angler.tile_pos.x, _angler.tile_pos.y) + Vector2(0.0, -20.0),
		func(f: int) -> void:
			if f == SETTLE - 10:
				_send_dogs()],
		# The wildlife coming back (2026-09-24, Richard: "seen growing and coming into the
		# scene, more frogs and ducks"). The lake is emptied before the shot, then flora and
		# wildlife are wiped and handed a clean share that climbs over the kept frames, so the
		# plants sprout on screen; extra frogs swim in to the shore in view, and broods fly in
		# from a short way off and land in it.
		["wildlife", 9.0, func() -> void:
			_follow = null
			_unpack()
			_hide_boats()
			_stand(Vector2(-2.0, 2.0), LEFT)
			_thin(0.97, [], 0.0)
			_zoom(4)
			_hold = Iso.tile_to_world(Iso.ISLAND_CENTRE.x - 4.0, Iso.ISLAND_CENTRE.y + 5.0),
		func(f: int) -> void:
			var wild: Wildlife = _main.get(&"_wildlife")
			var flora: Flora = _main.get(&"_flora")
			var k := f - SETTLE
			if k == -5:
				flora.reset()
				wild.reset()
				wild.set(&"_brood_in", 1.0e9)
			if k < -5:
				return
			if k % 15 == 0:
				var ramp := clampf(0.05 + float(k) / 300.0, 0.05, 1.0)
				flora.refresh(ramp)
				wild.refresh(ramp, _main.get(&"_clean_tiles"))
			if k >= 20 and k <= 320 and k % 12 == 0:
				_frog_in_view(wild)
			if k in WILD_BROODS:
				_brood_in_view(wild)
			if k % 120 == 0:
				_say("  wildlife %d: frogs %d broods %d turtles %d" % [
					k, wild.frog_count(), wild.brood_count(), wild.turtle_count()])],
		# The furnished shed is not re-filmed (2026-09-24): the cut keeps the frames it has.
		# To re-shoot it, put its entry back from git history (d. 2026-09-16).
	]
	var only := OS.get_environment("FILM_ONLY")
	if only != "":
		var names := only.split(",")
		_shots = _shots.filter(func(s: Array) -> bool: return s[0] in names)


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	_say("--- film_trailer start")
	_rng.seed = 7
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE_PATH)
	_main.set(&"autoload_save", false)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	add_child(_main)
	# After the lake's own _process, so the camera written here is the one drawn.
	process_priority = 100


func _say(line: String) -> void:
	_log.store_line(line)
	_log.flush()


func _process(_delta: float) -> void:
	_frames += 1
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
				_say("  %s: net lands on kept frame %d" % [shot[0], _kept])
		_net_was = _net.state
	if _shot_frame >= _settle_of(shot[0]):
		var image := get_viewport().get_texture().get_image()
		image.save_jpg(ProjectSettings.globalize_path(OUT % [shot[0], _kept]), JPG_QUALITY)
		_kept += 1
		if _kept >= int(shot[1] * 60.0):
			_say("%s: %d frames" % [shot[0], _kept])
			_next()
			return
	_shot_frame += 1


func _setup() -> void:
	_grid = _main.get_node(^"Grid") as LakeGrid
	_net = _main.get_node(^"Net") as CastNet
	_angler = _main.get_node(^"Angler") as Angler
	_camera = _main.get_node(^"Camera") as Camera2D
	(_main.get_node(^"HUD") as CanvasLayer).visible = false
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
	_shot += 1
	if _shot >= _shots.size():
		_say("--- film_trailer done")
		get_tree().quit()
		return
	var shot: Array = _shots[_shot]
	var dir := ProjectSettings.globalize_path("res://tools/film/%s" % shot[0])
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
	(shot[2] as Callable).call()


## Hold the camera where the shot wants it, after the lake has moved it.
func _aim() -> void:
	_push_camera_zoom()
	# The aim ring follows the pointer; pointed a long way off the lake it is not drawn.
	_net.pad_aim = Vector2(-1.0e6, -1.0e6)
	var at := _hold
	if _follow != null:
		at = _follow.position
	if at == Vector2.INF:
		_main.call(&"_snap_camera")
		return
	_main.set(&"_pan", at - _angler.position)
	_main.set(&"_panning", true)
	_camera.position = _main.call(&"_clamped_view", at)
	_main.call(&"_snap_camera")


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


## Where the three fetching dogs are sent: a stick each, out from the east beach in three
## directions. Tiles, for thinning to keep and for the dogs to aim at.
func _dog_sticks() -> Array:
	var from := Iso.ISLAND_CENTRE + Vector2(3.4, -3.4)
	var out: Array = []
	for dir in [Vector2(1.0, -1.0), Vector2(0.2, -1.0), Vector2(1.0, -0.2)]:
		out.append(from + dir.normalized() * 6.0)
	return out


## Where the hold's two swimmers go: south-east, down and right of the island.
func _hold_sticks() -> Array:
	var from := Iso.ISLAND_CENTRE + Vector2(2.0, 2.0)
	return [from + Vector2(1.0, 0.0) * 11.0, from + Vector2(1.0, 0.35).normalized() * 12.5]


## One dog asleep on the sand, the other three swimming out for their sticks. The stick is
## the nearest floating piece to each spot; the cut ends before anyone turns for the box.
func _send_dogs(spots: Array = _dog_sticks(), swimmers: int = 3, nap_first: bool = true) -> void:
	var dogs: Array = _main.get(&"_dogs")
	var sent := 0
	for i in dogs.size():
		var dog: Node2D = dogs[i]
		if sent >= swimmers or (i == 0 and nap_first):
			dog.set(&"_state", 2 if i == 0 else 0)
			dog.set(&"_mood_left", 100.0)
			continue
		var spot: Vector2 = spots[sent % spots.size()]
		sent += 1
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
			continue
		dog.call(&"_aim_at", best)
		dog.set(&"_to_strand", false)
		dog.set(&"_trip", 0.0)
		dog.set(&"_state", 4)
	_say("  dogs sent: %d" % sent)


## Richard's own save, copied so nothing here can write over it, and loaded into the lake.
func _load_shed_save() -> void:
	var real := "user://lake_cleanup.save"
	var copy := "user://film_trailer_shed.save"
	if not FileAccess.file_exists(real):
		_say("  no save at %s" % real)
		return
	DirAccess.copy_absolute(ProjectSettings.globalize_path(real), ProjectSettings.globalize_path(copy))
	_main.set(&"save_path", copy)
	var ok: bool = _main.call(&"load_game")
	_say("  shed save loaded: %s (%d finds stood)" % [str(ok), (_main.get(&"decor") as Array).size()])


func _zoom(level: int) -> void:
	_zoom_level = level
	_main.set(&"_view_zoom", _main.call(&"_zoom_level", mini(level, 4)))
	_main.call(&"_push_zoom")
	_push_camera_zoom()


func _push_camera_zoom() -> void:
	var zoom: float = float(_zoom_level) / (Lake.ART_PIXEL * _main.call(&"_stretch"))
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
func _cast(dir: Vector2, tiles: float, lucky: bool = false) -> void:
	_main.call(&"_push_net_numbers")
	var where := _target(dir, tiles)
	if where != Vector2.INF and _net.cast_to(where):
		if lucky:
			_net.luck_power = 1
			_net.luck_hold = Lake.LUCKY_EXTRA
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
	_noise.seed = 11
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


## Four fast, roomy hulls and a box with a full load for each of them.
func _fleet() -> void:
	while _main.get(&"fleet_level") < 3:
		_main.set(&"fleet_level", _main.get(&"fleet_level") + 1)
		_main.call(&"_add_boat")
	_main.set(&"boat_speed_level", 12)
	_main.set(&"cargo_level", 8)
	_main.call(&"_push_boat_numbers")
	var yard: Node = _main.get(&"_yard")
	var boats: Array = _main.get(&"_boats")
	var want: int = boats[0].capacity * boats.size()
	var rubbish: Array = []
	for i in _grid.defs.size():
		if not _grid.defs[i].keepsake:
			rubbish.append(i)
	while yard.held.size() < want:
		yard.put(rubbish[_rng.randi_range(0, rubbish.size() - 1)])
	for boat in boats:
		boat.auto_ferry = true
		boat.patrol = false


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


## A few birds out along `dir`, flying in from a short way off so the landing is in the shot
## (the flock's own birds come from nine hundred pixels out, six seconds away).
func _perch_birds(dir: Vector2, tiles: float) -> void:
	var flock: Flock = _main.get(&"_flock")
	flock.birds.clear()
	var centre := _angler.tile_pos + dir.normalized() * tiles
	var sent := 0
	for off in [Vector2.ZERO, Vector2(0.9, 0.5), Vector2(-0.6, 0.8), Vector2(0.4, -0.9)]:
		var tile := Vector2i((centre + off).round())
		var index := tile.y * Iso.COLS + tile.x
		if index < 0 or index >= _grid.stacks.size() or _grid.stacks[index].is_empty():
			continue
		if not flock.add_bird(index):
			continue
		var bird: Dictionary = flock.birds[flock.birds.size() - 1]
		var to: Vector2 = bird["to"]
		var from := to + Vector2(-260.0 - 60.0 * sent, -140.0 + 50.0 * sent)
		bird["at"] = from
		bird["from"] = from
		bird["span"] = from.distance_to(to)
		bird["facing"] = Flock.facing_of(from, to)
		bird["rest"] = 60.0
		sent += 1
	_say("  pigeons sent: %d" % sent)


## Every head roll in the next few catches comes up heads: a seed whose first draws are all
## under `Lake.POP_ODDS`, found by trying seeds.
func _force_pop() -> void:
	var rng := RandomNumberGenerator.new()
	for seed in 10000:
		rng.seed = seed
		var heads := true
		for i in 4:
			if rng.randf() >= Lake.POP_ODDS:
				heads = false
		if heads:
			var pop_rng: RandomNumberGenerator = _main.get(&"_pop_rng")
			pop_rng.seed = seed
			return


## The fleet parked at the island blocks the casts' view; the ferries' shot is where it works.
func _hide_boats() -> void:
	for boat: Node2D in _main.get(&"_boats"):
		boat.visible = false


## The camera's middle and a radius the wildlife shot's arrivals are kept inside.
func _view_spot(reach: float) -> Vector2:
	return _hold + Vector2(randf_range(-1.0, 1.0), randf_range(-0.6, 0.6)) * reach


## One more frog, swimming in to a stretch of shore that is in the shot.
func _frog_in_view(wild: Wildlife) -> void:
	var shore: Array = wild.get(&"_shore")
	var near: Array = shore.filter(func(s: Dictionary) -> bool:
		return (s["land"] as Vector2).distance_to(_hold) < 380.0)
	if near.is_empty():
		return
	var frogs: Array = wild.get(&"_frogs")
	frogs.append(wild.call(&"_new_frog", near[_rng.randi_range(0, near.size() - 1)]))


## A brood flying in from a short way off to water in the shot.
func _brood_in_view(wild: Wildlife) -> void:
	for attempt in 20:
		var to := _view_spot(340.0)
		if not wild.call(&"_swimmable", to):
			continue
		var b: Dictionary = wild.call(&"_new_brood")
		if b.is_empty():
			return
		var from := to + Vector2(-1.0 if _rng.randf() < 0.5 else 1.0, -0.4).normalized() * 520.0
		b["from"] = from
		b["at"] = from
		b["to"] = to
		b["goal"] = to
		b["facing"] = Flock.facing_of(from, to)
		for kid: Dictionary in b["kids"]:
			kid["at"] = from
		(wild.get(&"_broods") as Array).append(b)
		return
