extends Node
## Films the main menu's background: the trailer's held shot, reframed so the island and the
## swimming dogs sit right of centre and the top-left corner is open water for the logo.
##
## One-off, by decision (2026-09-16): the picture is posed here, a frame is picked, the
## darkening is baked by `tools/bake_menu_bg.py`, and the result is committed as
## `assets/menu_lake.png`. Nothing reads this at runtime.
##
## Run it with the desktop build, not --headless (nothing renders under the dummy driver),
## at a fixed 60 fps so the settle takes the same game time however slow a frame is:
##
##   godot --path . --fixed-fps 60 res://tools/shot_menu_bg.tscn
##
## `MENU_SHIFT=520` re-frames without editing the file (world px the view moves left, which
## is how far the picture moves right). `MENU_SHOTS=3` saves that many frames a few apart,
## so a frame with the dogs well placed can be picked. Frames land in
## `tools/menu_bg/NN.png`; `tools/menu_bg/last_menu_bg.log` says what was shot.

const OUT := "res://tools/menu_bg/%02d.png"
const LOG_PATH := "res://tools/menu_bg/last_menu_bg.log"
const SAVE_PATH := "user://shot_menu_bg.save"

## The shot's clock, in frames from the pose. The zoom's rebuild and the filth map have to
## land and a thinned lake has to settle before anything is asked of it; the dogs need a
## second or two to be in the water; and the net has to fly and come down before the first
## picture is kept.
const SEND_DOGS := 20
const CAST_AT := 50
const SETTLE := 150
## Frames between kept pictures, so the dogs have swum on between two of them.
const APART := 30
## How dirty the lake is left: the share of the floating rubbish thinning takes. The
## trailer's own hold, so the menu and its last page are the same lake.
const THIN := 0.12
## Screen pixels an art pixel. The trailer's hold; past `MAX_ZOOM`, which is why it is set
## straight on the camera.
const ZOOM := 2
## World px the view is moved left of the lake's middle, which is how far the picture moves
## right on the screen. At this zoom on 1080p the view is 2880 world px wide, so this is
## about a sixth of it.
const SHIFT := 440.0

## Where the angler stands, in tiles off the island's middle, and which way the cast goes.
## The south-east beach, clear of the recycle box — at the trailer's own (2, 2) the figure
## stands behind the box and is not in the picture at all. Screen-right is +x -y; down the
## screen is +x +y.
const STAND := Vector2(4.6, 1.4)
const THROW := Vector2(1.0, 1.0)
const THROW_TILES := 13.0

var _main: Node
var _grid: LakeGrid
var _net: CastNet
var _angler: Angler
var _camera: Camera2D
var _log: FileAccess

var _frames := 0
var _shot_frame := 0
var _kept := 0
var _shots := 1
var _shift := SHIFT
var _hold := Vector2.ZERO


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/menu_bg"))
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	_say("--- shot_menu_bg start")
	if OS.get_environment("MENU_SHIFT") != "":
		_shift = float(OS.get_environment("MENU_SHIFT"))
	if OS.get_environment("MENU_SHOTS") != "":
		_shots = maxi(1, int(OS.get_environment("MENU_SHOTS")))
	_say("shift %.0f, %d shot(s)" % [_shift, _shots])
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
		_pose()
		return
	if _frames < 4:
		return
	_aim()
	if _shot_frame == SEND_DOGS:
		_send_dogs()
	if _shot_frame == CAST_AT:
		_cast()
	if _shot_frame >= SETTLE and (_shot_frame - SETTLE) % APART == 0:
		var image := get_viewport().get_texture().get_image()
		image.save_png(ProjectSettings.globalize_path(OUT % _kept))
		_say("kept %02d on frame %d" % [_kept, _shot_frame - SETTLE])
		_kept += 1
		if _kept >= _shots:
			_say("--- shot_menu_bg done")
			get_tree().quit()
			return
	_shot_frame += 1


func _setup() -> void:
	_grid = _main.get_node(^"Grid") as LakeGrid
	_net = _main.get_node(^"Net") as CastNet
	_angler = _main.get_node(^"Angler") as Angler
	_camera = _main.get_node(^"Camera") as Camera2D
	(_main.get_node(^"HUD") as CanvasLayer).visible = false
	Input.warp_mouse(Vector2(2, 2))


## The trailer's `clean_hold`: the angler on the island's south-east shore, the whole pack
## out, the lake thinned to a few clear pools, held on the lake's middle — then moved left,
## so the island and the dogs carry the right of the picture.
func _pose() -> void:
	_angler.stand_at(Iso.ISLAND_CENTRE + STAND)
	_angler.facing = THROW.normalized()
	_main.set(&"net_range_level", 14)
	_main.set(&"net_width_level", 11)
	_main.set(&"net_hold_level", 10)
	_main.call(&"_push_net_numbers")
	_pack()
	_thin(THIN, _hold_sticks(), 1.6)
	_main.set(&"_view_zoom", _main.call(&"_zoom_level", mini(ZOOM, 4)))
	_main.call(&"_push_zoom")
	_hold = Iso.tile_to_world(Iso.CENTRE.x, Iso.CENTRE.y) - Vector2(_shift, 0.0)
	_say("hold at %s (lake middle %s)" % [
			str(_hold), str(Iso.tile_to_world(Iso.CENTRE.x, Iso.CENTRE.y))])


## Hold the camera where the shot wants it, after the lake has moved it.
func _aim() -> void:
	var zoom: float = float(ZOOM) / (Lake.ART_PIXEL * float(_main.call(&"_stretch")))
	_camera.zoom = Vector2(zoom, zoom)
	# The aim ring follows the pointer; pointed a long way off the lake it is not drawn.
	_net.pad_aim = Vector2(-1.0e6, -1.0e6)
	_main.set(&"_pan", _hold - _angler.position)
	_main.set(&"_panning", true)
	_camera.position = _main.call(&"_clamped_view", _hold)
	_main.call(&"_snap_camera")


## The whole pack, each dog started fresh on the island's east beach.
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


## The cast: out along `THROW`, at the farthest castable spot within `THROW_TILES`. Held
## where it comes down, so the picture has the game's verb in it rather than a still lake.
func _cast() -> void:
	var best := Vector2.INF
	var span := 0.5
	while span <= minf(THROW_TILES, _net.range_tiles):
		var tile := _angler.tile_pos + THROW.normalized() * span
		var where := Iso.tile_to_world(tile.x, tile.y)
		if _net.can_cast_to(where):
			best = where
		span += 0.5
	if best == Vector2.INF or not _net.cast_to(best):
		_say("cast refused; angler %s state %d" % [str(_angler.tile_pos), _net.state])
		return
	_say("cast to %s" % str(best))


## Where the two swimmers go: east and south-east, out into the soup on the side the shift
## brings into the picture — and clear of where the net comes down.
func _hold_sticks() -> Array:
	var from := Iso.ISLAND_CENTRE + Vector2(2.0, -2.0)
	return [from + Vector2(1.0, -0.5).normalized() * 9.0, from + Vector2(1.0, 0.25).normalized() * 11.0]


## One dog asleep on the sand, two swimming out for their sticks.
func _send_dogs() -> void:
	var spots := _hold_sticks()
	var dogs: Array = _main.get(&"_dogs")
	var sent := 0
	for i in dogs.size():
		var dog: Node2D = dogs[i]
		if sent >= 2 or i == 0:
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
	_say("dogs sent: %d" % sent)


## Clean `share` of the lake's floating rubbish, in pools rather than a disc — the trailer's
## own `_thin`, same noise and same seed, so this is the same lake its last page holds.
func _thin(share: float, keeps: Array = [], keep_near: float = 4.5) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 11
	noise.frequency = 0.11
	noise.fractal_octaves = 3
	var values := PackedFloat32Array()
	var tiles := PackedInt32Array()
	for index in _grid.stacks.size():
		if _grid.dry[index] == 1 or _grid.stacks[index].is_empty():
			continue
		var tile := Vector2(float(index % Iso.COLS), floorf(float(index) / float(Iso.COLS)))
		var far := tile.distance_to(Iso.ISLAND_CENTRE) / 40.0
		var kept := 0.0
		for keep in keeps:
			if tile.distance_to(keep) < keep_near:
				kept = 2.0
		values.append(noise.get_noise_2d(tile.x, tile.y) + far * 0.25 + kept)
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
	_say("thinned %.0f%%: %d taken, %d left" % [share * 100.0, taken, _grid.piece_count()])
