extends "res://tools/film_trailer.gd"
## Renders the key art the Steam capsules and library art are cut from (2026-10-02): the lake
## with no HUD, the west of it cleaned and alive, the east still soup, the angler on the
## island's east beach throwing into the soup with a dog beside him. Saves a burst of
## 1920x1080 PNGs per zoom level to `Marketing/My Dirty Little Lake/source/keyart/`, where
## `source/capsules_v2.py` reads them. The capsules are cut at whole-pixel ratios off these,
## so the pixel art stays sharp.
##
##   godot --path . --fixed-fps 60 res://tools/shot_keyart.tscn --log-file tools/film/keyart_engine.log
##
## Desktop build, not --headless. On a save of its own, under its own node (the trailer's
## rules). `FILM_ONLY=split_z2` re-shoots by name. Run `tall_z2` on its own
## (`FILM_ONLY=tall_z2`): the shots share one lake, so a run after a split inherits its clearing.

const KEYART := "res://../Marketing/My Dirty Little Lake/source/keyart"
const BURST := 12
const BURST_GAP := 4
## How far past the island's middle, in world px across the screen, the clean water reaches;
## the edge wanders by `SPLIT_WOBBLE` over `SPLIT_CELL`-tile blobs.
const SPLIT_AT := -120.0
const SPLIT_WOBBLE := 260.0
## Where the angler stands and how far he throws.
const STAND := Vector2(3.9, -3.3)
const THROW := 6.0
## The tall shot: where the angler stands on the south beach, how the clean water's edge
## runs (world px below the island's middle).
const TALL_STAND := Vector2(5.6, 2.6)
const TALL_SPLIT := 60.0
var _throw_dir := ACROSS

var _burst_from := -1
var _saved := 0


func _init() -> void:
	SAVE_PATH = "user://shot_keyart.save"
	LOG_PATH = "res://tools/film/last_keyart.log"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_dir())
	super._ready()


func _dir() -> String:
	return ProjectSettings.globalize_path(KEYART).simplify_path()


func _plan() -> void:
	_shots = []
	for level in [2, 3]:
		_shots.append(["split_z%d" % level, 0.0, _pose_split.bind(level), _run_split])
	# The tall formats: clean water above the island for the logo, the cast going down the
	# screen into the soup below it.
	_shots.append(["tall_z2", 0.0, _pose_tall.bind(2), _run_split])
	var only := OS.get_environment("FILM_ONLY")
	if only != "":
		var names := only.split(",")
		_shots = _shots.filter(func(s: Array) -> bool: return s[0] in names)


func _pose_split(level: int) -> void:
	_hide_boats()
	_unpack()
	_pack()
	_main.set(&"net_width_level", 8)
	_main.set(&"net_hold_level", 6)
	_main.call(&"_push_net_numbers")
	_throw_dir = ACROSS
	_stand(STAND, ACROSS)
	_clear(func(at: Vector2, island: Vector2) -> float: return at.x - (island.x + SPLIT_AT))
	_zoom(level)
	var island := Iso.tile_to_world(Iso.ISLAND_CENTRE.x, Iso.ISLAND_CENTRE.y)
	_hold = island + Vector2(140.0 if level == 2 else 260.0, 10.0)
	# Two dogs by the angler, the rest out of the shot at the far end of the island.
	var dogs: Array = _main.get(&"_dogs")
	for i in dogs.size():
		var dog: Node2D = dogs[i]
		var spot := _angler.tile_pos + (Vector2(-1.1, -0.4) if i == 0 else Vector2(-0.4, 1.0))
		if i > 1:
			spot = Iso.ISLAND_CENTRE + Vector2(-2.0 - i, 1.0)
		dog.set(&"tile_pos", spot)
		dog.set(&"_state", 1 if i != 1 else 2)
		dog.set(&"_mood_left", 600.0)
	var day: DayCycle = _main.get(&"_day")
	day.phase = 0.35


func _run_split(f: int) -> void:
	var wild: Wildlife = _main.get(&"_wildlife")
	var flora: Flora = _main.get(&"_flora")
	var k := f - SETTLE
	if k == -20:
		wild.set(&"_brood_in", 1.0e9)
	if k >= -20 and k % 15 == 0:
		flora.refresh(0.9)
		wild.refresh(0.9, _main.get(&"_clean_tiles"), 1.0)
		(_main.get(&"_fish") as Node).call(&"refresh", 0.9, _main.get(&"_clean_tiles"))
	if k >= 0 and k <= 200 and k % 20 == 0:
		_frog_in_view(wild)
	if k in [0, 20, 40, 60, 80, 100, 120]:
		_brood_in_view(wild)
	if k == 300:
		_cast(_throw_dir, THROW)
	if k == 300 + 10:
		_say("  %s: frogs %d broods %d" % [_shots[_shot][0], wild.frog_count(), wild.brood_count()])
		_burst_from = _shot_frame
		_saved = 0


func _pose_tall(level: int) -> void:
	_hide_boats()
	_unpack()
	_pack()
	_main.set(&"net_width_level", 8)
	_main.call(&"_push_net_numbers")
	_throw_dir = DOWN
	_stand(TALL_STAND, DOWN)
	_clear(func(at: Vector2, island: Vector2) -> float: return at.y - (island.y + TALL_SPLIT))
	_zoom(level)
	_hold = Iso.tile_to_world(Iso.ISLAND_CENTRE.x, Iso.ISLAND_CENTRE.y) + Vector2(0.0, 40.0)
	var dogs: Array = _main.get(&"_dogs")
	for i in dogs.size():
		var dog: Node2D = dogs[i]
		var spot := _angler.tile_pos + (Vector2(-1.2, 0.2) if i == 0 else Vector2(0.3, -1.2))
		if i > 1:
			spot = Iso.ISLAND_CENTRE + Vector2(-3.0, -1.5 * i)
		dog.set(&"tile_pos", spot)
		dog.set(&"_state", 1 if i != 1 else 2)
		dog.set(&"_mood_left", 600.0)
	var day: DayCycle = _main.get(&"_day")
	day.phase = 0.35


## Every floating piece on the clean side of a wandering line (`side` under zero) is taken,
## the way the net takes, so the meter, the filth map and the life that follows it agree.
func _clear(side: Callable) -> void:
	_noise.seed = 5
	_noise.frequency = 0.07
	var island := Iso.tile_to_world(Iso.ISLAND_CENTRE.x, Iso.ISLAND_CENTRE.y)
	var taken := 0
	for index in _grid.stacks.size():
		if _grid.stacks[index].is_empty():
			continue
		var tile := Vector2(float(index % Iso.COLS), floorf(float(index) / float(Iso.COLS)))
		var at := Iso.tile_to_world(tile.x, tile.y)
		if float(side.call(at, island)) > _noise.get_noise_2d(tile.x, tile.y) * SPLIT_WOBBLE:
			continue
		while not _grid.stacks[index].is_empty():
			var def_index := _grid.take(index, _grid.stacks[index].size() - 1)
			if not _grid.defs[def_index].keepsake:
				_main.call(&"_on_net_caught", def_index)
			taken += 1
	_say("  cleared: %d taken" % taken)


func _next() -> void:
	_burst_from = -1
	_saved = 0
	super._next()


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
	if _burst_from >= 0 and (_shot_frame - _burst_from) % BURST_GAP == 0:
		var image := get_viewport().get_texture().get_image()
		image.save_png(_dir().path_join("%s_%02d.png" % [shot[0], _saved]))
		_saved += 1
		if _saved >= BURST:
			_say("%s: %d frames" % [shot[0], _saved])
			_next()
			return
	_shot_frame += 1
