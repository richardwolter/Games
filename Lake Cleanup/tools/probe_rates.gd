## Measures the rates the progression sim is built on, off the real lake: what the basin holds
## and where, what a cast catches and how long it takes at given upgrade levels, how long a
## ferry run takes, what the skimmer brings up on one, and how fast the dog fetches.
##
## Probe only: it sets upgrade levels directly and reads the answers, it changes nothing in
## the game. The numbers feed the k_* constants in docs/progression/build_current.py.
##
## Run (desktop build, headless is fine, fixed fps so game time runs faster than real time):
##   <godot> --headless --path . res://tools/probe_rates.tscn --fixed-fps 60 --log-file tools/last_probe_engine.log
## Output: tools/last_probe.log, one JSON object per line, flushed per line — a run that dies
## leaves everything it measured so far.
##
## Stepped by _physics_process like test_lake, for the same reason: the `await` form stalls
## on this build.
extends Node

const LOG_PATH := "res://tools/last_probe.log"
const SAVE_PATH := "user://probe_rates.save"

## Net levels to cast at: width, strength, range, reel, hold. The first four walk the whole
## shop from bare to maxed; the rest move one track at a time around the middle one, so each
## track's own effect can be read.
const NET_CONFIGS := [
	[0, 0, 0, 0, 0], [3, 1, 3, 3, 3], [6, 2, 8, 10, 10], [13, 4, 16, 20, 22],
	[0, 2, 8, 10, 10], [13, 2, 8, 10, 10],
	[6, 0, 8, 10, 10], [6, 4, 8, 10, 10],
	[6, 2, 0, 10, 10], [6, 2, 16, 10, 10],
	[6, 2, 8, 0, 10], [6, 2, 8, 20, 10],
	[6, 2, 8, 10, 0], [6, 2, 8, 10, 22],
]
const CASTS := 8
## Where along the range each cast lands, in turn.
const CAST_REACH := [0.55, 0.8, 0.95, 0.7]

## Ferry levels: boat_speed, cargo. Loaded mixed, in the lake's own material shares
## (`_material_share`, off the census), because a real hold is mixed and a run visits every
## yard its load needs — a one-material load is a one-stop run, and measuring only those put
## the sim's ferries 2.5 times faster than play (2026-09-14).
const FERRY_CONFIGS := [[0, 3], [3, 3], [0, 6], [3, 6], [6, 6], [3, 12], [8, 12]]
const FERRY_RUNS := 2

## Skimmer level, and the load the ferry leaves with (a big number means a full hold).
## The skimmer is cut from the tree design; left empty so the phase passes straight through.
const SKIM_CONFIGS := []
const SKIM_CARGO_LEVEL := 28
const SKIM_SPEED_LEVEL := 10

## Dog levels: fetching, keenness. Each watched for DOG_SECONDS of game time.
const DOG_CONFIGS := [[0, 0], [4, 0], [4, 3]]
const DOG_SECONDS := 90.0

const WAIT_MOST := 90.0

var _main: Node2D
var _grid: LakeGrid
var _angler: Angler
var _net: CastNet
var _yard: Node
var _boat: Boat
var _dog: Node

var _clock: float = 0.0
var _frames: int = 0
var _phase: String = "boot"
var _step: String = ""
var _config: int = 0
var _round: int = 0
var _t0: float = 0.0
var _count0: int = 0
var _runs0: int = 0
var _skimmed: int = 0
var _lot: int = 0
var _material_share: Array = [0.25, 0.25, 0.25, 0.25]
var _birds: int = 0
var _birds0: int = 0
var _double_found: bool = false


func _ready() -> void:
	if FileAccess.file_exists(LOG_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG_PATH))
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_emit({"probe": "start"})
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE_PATH)
	_main.set(&"autoload_save", false)
	add_child(_main)


func _physics_process(delta: float) -> void:
	_clock += delta
	_frames += 1
	match _phase:
		"boot":
			if _frames >= 3:
				_boot()
		"net":
			_net_step()
		"ferry":
			_ferry_step()
		"skim":
			_skim_step()
		"dog":
			_dog_step()
		"done":
			pass


# ------------------------------------------------------------------ census

func _boot() -> void:
	_grid = _main.get_node(^"Grid") as LakeGrid
	_angler = _main.get_node(^"Angler") as Angler
	_net = _main.get_node(^"Net") as CastNet
	_yard = _main.get_node(^"Yard")
	_boat = _main.get_node(^"Boat") as Boat
	_dog = _main.get_node_or_null(^"Dog")
	# The flock stays on: the net phase counts the birds a cast takes without aiming at them.
	_net.caught_bird.connect(func(_at: Vector2) -> void: _birds += 1)
	if _dog != null:
		_dog.set_process(false)
	_main.call(&"_set_auto_ferry", false)
	_census()
	_phase = "net"
	_step = "aim"


func _census() -> void:
	var by_tier := {}
	var keepsakes := 0
	var strand := 0
	var dry := 0
	var tiles_used := 0
	var depth_sum := 0
	var deepest := 0
	var by_ring := {}
	var by_material := {}
	for index in _grid.stacks.size():
		var stack: PackedInt32Array = _grid.stacks[index]
		var here := 0
		var tile := _grid.tile_of(index)
		var on_strand := Iso.on_strand(tile.x, tile.y)
		var is_dry := index < _grid.dry.size() and _grid.dry[index] != 0
		var ring := int(Vector2(float(tile.x) + 0.5, float(tile.y) + 0.5).distance_to(Iso.ISLAND_CENTRE) / 2.0) * 2
		for slot in stack.size():
			var d := stack[slot]
			if d < 0:
				continue
			here += 1
			var def: TrashDef = _grid.defs[d]
			if def.keepsake:
				keepsakes += 1
				continue
			if on_strand:
				strand += 1
			if is_dry:
				dry += 1
			by_tier[def.tier] = int(by_tier.get(def.tier, 0)) + 1
			by_material[def.material] = int(by_material.get(def.material, 0)) + 1
			by_ring[ring] = int(by_ring.get(ring, 0)) + 1
		if here > 0:
			tiles_used += 1
			depth_sum += here
			deepest = maxi(deepest, here)
	var counted := 0
	for m: int in by_material:
		counted += int(by_material[m])
	for m in 4:
		_material_share[m] = float(by_material.get(m, 0)) / maxf(float(counted), 1.0)
	_emit({
		"probe": "census", "pieces": _grid.piece_count(), "by_tier": by_tier, "by_material": by_material, "keepsakes": keepsakes,
		"strand": strand, "dry": dry, "tiles_with_pieces": tiles_used,
		"mean_stack": float(depth_sum) / maxf(float(tiles_used), 1.0), "deepest": deepest,
		"by_distance_from_island_centre": by_ring,
		"lake_radius": [Iso.RADIUS.x, Iso.RADIUS.y], "island_radius": [Iso.ISLAND_RADIUS.x, Iso.ISLAND_RADIUS.y],
	})


# ------------------------------------------------------------------ net

func _set_net(levels: Array) -> void:
	_main.set(&"net_width_level", levels[0])
	_main.set(&"net_strength_level", levels[1])
	_main.set(&"net_range_level", levels[2])
	_main.set(&"reel_level", levels[3])
	_main.set(&"net_hold_level", levels[4])
	_main.call(&"_push_net_numbers")


func _net_step() -> void:
	if _config >= NET_CONFIGS.size():
		_phase = "ferry"
		_config = 0
		_round = 0
		_step = "setup"
		return
	if _step == "aim":
		if _round == 0:
			_set_net(NET_CONFIGS[_config])
		if _round >= CASTS:
			_config += 1
			_round = 0
			return
		# A different stretch of shore for every cast of every config, so no cast lands in
		# water an earlier one already swept.
		var angle := TAU * fmod(float(_config * CASTS + _round) * 0.618034, 1.0)
		var dir := Vector2(cos(angle), sin(angle))
		_stand_facing(dir)
		var reach: float = _net.range_tiles * float(CAST_REACH[_round % CAST_REACH.size()])
		var target := _angler.tile_pos + dir * reach
		var tries := 0
		while not _net.can_cast_to(Iso.tile_to_world(target.x, target.y)) and tries < 12:
			reach *= 0.9
			target = _angler.tile_pos + dir * reach
			tries += 1
		# Would a double cast have found somewhere to throw the second net? Asked before the
		# throw, as `_roll_luck` asks it, and the second net is never actually thrown.
		var second: Vector2 = _main.call(&"_double_spot", target)
		_double_found = second != Vector2.INF
		_count0 = _grid.piece_count()
		_birds0 = _birds
		_t0 = _clock
		_main.call(&"_cast_at", Iso.tile_to_world(target.x, target.y))
		if _net.state != CastNet.State.FLYING:
			_emit({"probe": "cast_refused", "config": NET_CONFIGS[_config], "round": _round, "reach": reach})
			_round += 1
			return
		_lot = int(reach * 100.0)
		_step = "reeling"
		return
	if _step == "reeling":
		if _net.state != CastNet.State.IDLE and _clock - _t0 < WAIT_MOST:
			return
		_emit({
			"probe": "cast", "config": NET_CONFIGS[_config],
			"radius": _net.radius, "power": _net.power, "range": _net.range_tiles,
			"reel": _net.reel_speed, "hold": _net.hold,
			"distance": float(_lot) / 100.0, "pieces": _count0 - _grid.piece_count(),
			"seconds": _clock - _t0, "timed_out": _net.state != CastNet.State.IDLE,
			"birds": _birds - _birds0, "double_found": _double_found,
			"birds_on_lake": ((_main.get(&"_flock") as Node).get(&"birds") as Array).size(),
		})
		_net.set_pulling(false)
		_round += 1
		_step = "aim"


func _stand_facing(dir: Vector2) -> void:
	var last := _angler.tile_pos
	var walked := 0.0
	while walked < Iso.ISLAND_RADIUS.x + 4.0:
		walked += 0.25
		var at := Iso.ISLAND_CENTRE + dir * walked
		if bool(_angler.call(&"_can_stand", at)):
			last = at
	_angler.tile_pos = last
	_angler.call(&"_place")


# ------------------------------------------------------------------ ferry

func _def_of(kind: int) -> int:
	for i in _grid.defs.size():
		if _grid.defs[i].material == kind and not _grid.defs[i].keepsake:
			return i
	return 0


func _empty_yard() -> void:
	_yard.set(&"held", PackedInt32Array())


func _load_yard(count: int, kind: int) -> void:
	for i in count:
		_yard.call(&"put", _def_of(kind))


## `count` pieces in the lake's material shares, dealt round so the hold is mixed through.
func _load_mixed(count: int) -> void:
	var owed := [0.0, 0.0, 0.0, 0.0]
	for i in count:
		var pick := 0
		for m in 4:
			owed[m] += float(_material_share[m])
			if owed[m] > owed[pick]:
				pick = m
		owed[pick] -= 1.0
		_yard.call(&"put", _def_of(pick))


func _ferry_step() -> void:
	if _config >= FERRY_CONFIGS.size():
		_phase = "skim"
		_config = 0
		_round = 0
		_step = "setup"
		return
	match _step:
		"setup":
			_main.set(&"boat_speed_level", FERRY_CONFIGS[_config][0])
			_main.set(&"cargo_level", FERRY_CONFIGS[_config][1])
			_main.set(&"skimmer_level", 0)
			_main.call(&"_push_boat_numbers")
			_step = "load"
		"load":
			if _round >= FERRY_RUNS:
				_config += 1
				_round = 0
				_step = "setup"
				return
			if _boat.is_running():
				return
			_empty_yard()
			_lot = _boat.capacity
			_load_mixed(_lot)
			_runs0 = _boat.runs_done
			_t0 = _clock
			_boat.auto_ferry = true
			_step = "run"
		"run":
			if _boat.runs_done == _runs0 and _clock - _t0 < WAIT_MOST:
				return
			_boat.auto_ferry = false
			_emit({
				"probe": "ferry_run", "levels": FERRY_CONFIGS[_config], "speed": _boat.speed,
				"capacity": _boat.capacity, "lot": _lot, "mixed": true,
				"seconds": _clock - _t0, "timed_out": _boat.runs_done == _runs0,
			})
			_round += 1
			_step = "load"


# ------------------------------------------------------------------ skimmer

func _note_skim(_def_index: int) -> void:
	_skimmed += 1


func _skim_step() -> void:
	if _config >= SKIM_CONFIGS.size():
		if _boat.skimmed.is_connected(_note_skim):
			_boat.skimmed.disconnect(_note_skim)
		_main.set(&"skimmer_level", 0)
		_main.call(&"_push_boat_numbers")
		_phase = "dog"
		_config = 0
		_step = "setup"
		return
	match _step:
		"setup":
			if _boat.is_running():
				return
			if not _boat.skimmed.is_connected(_note_skim):
				_boat.skimmed.connect(_note_skim)
			_main.set(&"skimmer_level", SKIM_CONFIGS[_config][0])
			_main.set(&"cargo_level", SKIM_CARGO_LEVEL)
			_main.set(&"boat_speed_level", SKIM_SPEED_LEVEL)
			_main.call(&"_push_boat_numbers")
			_empty_yard()
			_lot = mini(int(SKIM_CONFIGS[_config][1]), _boat.capacity)
			_load_yard(_lot, _config % 4)
			_skimmed = 0
			_runs0 = _boat.runs_done
			_t0 = _clock
			_boat.auto_ferry = true
			_step = "run"
		"run":
			if _boat.runs_done == _runs0 and _clock - _t0 < WAIT_MOST:
				return
			_boat.auto_ferry = false
			_emit({
				"probe": "skim_run", "level": SKIM_CONFIGS[_config][0], "lot": _lot,
				"capacity": _boat.capacity, "skim_hold": _boat.skim_hold, "skim_radius": _boat.skim_radius,
				"chance": _boat.skim_chance, "skimmed": _skimmed, "seconds": _clock - _t0,
				"timed_out": _boat.runs_done == _runs0,
			})
			_config += 1
			_step = "setup"


# ------------------------------------------------------------------ dog

func _dog_step() -> void:
	if _dog == null or _config >= DOG_CONFIGS.size():
		if _dog != null:
			_dog.set_process(false)
		_emit({"probe": "done", "game_seconds": _clock, "frames": _frames})
		_phase = "done"
		get_tree().quit()
		return
	match _step:
		"setup":
			_main.set(&"dog_fetch_level", DOG_CONFIGS[_config][0])
			_main.set(&"dog_wait_level", DOG_CONFIGS[_config][1])
			_main.call(&"_push_dog_numbers")
			_empty_yard()
			_count0 = _grid.piece_count()
			_t0 = _clock
			_dog.set_process(true)
			_step = "watch"
		"watch":
			if _clock - _t0 < DOG_SECONDS:
				return
			_dog.set_process(false)
			_emit({
				"probe": "dog", "levels": DOG_CONFIGS[_config], "fetch_most": _dog.get(&"fetch_most"),
				"wait_cut": _dog.get(&"wait_cut"), "seconds": _clock - _t0,
				"left_lake": _count0 - _grid.piece_count(), "in_yard": (_yard.get(&"held") as PackedInt32Array).size(),
			})
			_config += 1
			_step = "setup"


# ------------------------------------------------------------------ log

func _emit(data: Dictionary) -> void:
	var line := JSON.stringify(data)
	printerr(line)
	var f := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(line)
	f.flush()
	f.close()
