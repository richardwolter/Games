extends "res://tools/film_trailer.gd"
## Films the final game's side of the before/after video (2026-10-15, `/grill-me` with
## Richard): the two shots the trailer's film has nothing to match the prototype with, framed
## as the prototype recording is so the edit's slider can lay one over the other.
##
##   godot --path . --fixed-fps 60 res://tools/film_before_after.tscn
##
## Frames land in tools/film/<shot>/ like the trailer's, on a save and a log of their own.
## The cut is `Marketing/My Dirty Little Lake/2 Work/before_after/build_before_after.py`.

## Where the angler stands for the net shot and how far the throw goes: the prototype casts
## from the island's south shore straight down the screen.
const NET_STAND := Vector2(3.4, 3.4)
const NET_TILES := 9.0
## Each throw a little to one side of the last, so no spot is emptied.
const NET_DIRS := [Vector2(1.0, 1.0), Vector2(0.7, 1.0), Vector2(1.0, 0.7), Vector2(0.85, 1.0), Vector2(1.0, 0.85)]
var _throws := 0
## Frames between the net coming home and the next throw.
const NET_AGAIN := 50
var _net_home_at := -1


func _init() -> void:
	SAVE_PATH = "user://film_before_after.save"
	LOG_PATH = "res://tools/film/last_film_before_after.log"


func _plan() -> void:
	_shots = [
		# The whole lake at the far stop, island in the middle: a few small pools cleaned, the
		# whole pack out fetching and the fleet crossing to the piers (Richard, 2026-10-15:
		# "barcos cruzando o lago, mais cachorros e pequenas partes do lago limpos").
		["ba_lake", 16.0, func() -> void:
			_drop_finds()
			thin_seed = 37
			_thin(LAKE_CLEAN)
			_pack()
			_main.set(&"dog_fetch_level", 4)
			_main.set(&"dog_strength_level", 4)
			_main.call(&"_push_dog_numbers")
			_sail_fleet()
			_zoom(1)
			_phase = DAY_PHASE
			_hold = Iso.tile_to_world(Iso.CENTRE.x, Iso.CENTRE.y),
		func(_f: int) -> void:
			_hud_off()],
		# Casts off the island's south shore over a dirty lake, the island in the top half as
		# the prototype frames it, the count over the angler.
		["ba_net", 12.0, func() -> void:
			_unpack()
			_hide_boats()
			_drop_finds()
			_levels(6, 5, 8, 8)
			_stand(NET_STAND, DOWN)
			_dog_beside(Vector2(-1.0, 0.4))
			for dir: Vector2 in NET_DIRS:
				_stock(_angler.tile_pos + dir.normalized() * NET_TILES, 2.0, 5)
			_zoom(2)
			_phase = DAY_PHASE
			var isle := Iso.tile_to_world(Iso.ISLAND_CENTRE.x, Iso.ISLAND_CENTRE.y)
			_hold = isle + Vector2(0.0, 150.0)
			_throws = 0
			_net_home_at = -1,
		func(f: int) -> void:
			_count_only()
			var k := f - SETTLE
			if k == 20:
				_throw()
			elif k > 20 and _net.state == CastNet.State.IDLE:
				if _net_home_at < 0:
					_net_home_at = k
				elif k - _net_home_at >= NET_AGAIN:
					_net_home_at = -1
					_throw()],
	]
	var only := OS.get_environment("FILM_ONLY")
	if only != "":
		var names := only.split(",")
		_shots = _shots.filter(func(s: Array) -> bool: return s[0] in names)


## The share of the lake `ba_lake` cleans, in the trailer's noise pools.
const LAKE_CLEAN := 0.1
## Frames the lake shot runs before its first kept frame: the fleet loads at the island and
## is out on the water by then.
const LAKE_SETTLE := 420


func _settle_of(name: String) -> int:
	return LAKE_SETTLE if name == "ba_lake" else super(name)


## Four hulls, a crate heaped well past what they hold, so every one loads and sails out.
func _sail_fleet() -> void:
	while int(_main.get(&"fleet_level")) < 3:
		_main.set(&"fleet_level", int(_main.get(&"fleet_level")) + 1)
		_main.call(&"_add_boat")
	_main.set(&"boat_speed_level", 4)
	_main.set(&"cargo_level", 2)
	_main.call(&"_push_boat_numbers")
	var yard: Yard = _main.get(&"_yard")
	var rubbish: Array = []
	for i in _grid.defs.size():
		if not (_grid.defs[i] as TrashDef).keepsake:
			rubbish.append(i)
	while yard.held.size() < 160:
		yard.put(rubbish[_rng.randi_range(0, rubbish.size() - 1)])
	for boat: Boat in _main.get(&"_boats"):
		boat.visible = true
		boat.moored = false
		boat.auto_ferry = true


func _throw() -> void:
	_cast(NET_DIRS[_throws % NET_DIRS.size()], NET_TILES)
	_throws += 1
