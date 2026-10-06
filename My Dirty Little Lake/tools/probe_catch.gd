extends Node
## Headless probe: how much a maxed net catches per cast, and why not more.
##
## Every net track at its cap, the lake fresh (or thinned by PROBE_THIN, a share removed at
## random), the angler on a shore, casts at spread spots in range. Per cast it logs the hold,
## what the landing sweep took, what came home, and how many tiles under the open mouth held
## anything liftable at landing. tools/last_probe_catch.log. Own save path, nothing written.

var _main: Node
var _grid: Node
var _net: CastNet
var _log: FileAccess
var _spots: Array[Vector2] = []
var _cast: int = -1
var _before_land: int = 0
var _landed_at: int = -1
var _under: Dictionary = {}
var _frames: int = 0
var _started_ms: int = 0


func _ready() -> void:
	_started_ms = Time.get_ticks_msec()
	_log = FileAccess.open("res://tools/last_probe_catch.log", FileAccess.WRITE)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"autoload_save", false)
	_main.set(&"save_path", "user://probe_catch.save")
	add_child(_main)
	_grid = _main.get_node(^"Grid")
	for key in [&"net_width", &"net_hold", &"net_strength", &"net_range", &"reel"]:
		var track: UpgradeTrack = _main.get(&"_upgrades")[key]
		_main.set(StringName(String(key) + "_level"), track.level_cap)
	_main.call(&"_push_net_numbers")
	var thin := float(OS.get_environment("PROBE_THIN")) if OS.get_environment("PROBE_THIN") != "" else 0.0
	if thin > 0.0:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for index in _grid.stacks.size():
			for k in range(_grid.stacks[index].size() - 1, -1, -1):
				if rng.randf() < thin:
					_grid.stacks[index].remove_at(k)
		_grid._rebuild()
	_net = _main.get(&"_net")
	_net.landed.connect(_on_landed)
	var angler: Node2D = _main.get(&"_angler")
	angler.stand_at(angler.shore_toward(Iso.ISLAND_CENTRE + Vector2(1.0, 1.0) * 20.0))
	for k in 24:
		var dir := Vector2.RIGHT.rotated(TAU * k / 24.0)
		for frac in [0.45, 0.7, 0.92]:
			var at: Vector2 = angler.position + Vector2(dir.x, dir.y * 0.5) * Iso.tile_circle_extent(_net.range_tiles) * frac
			if _net.in_reach(at):
				_spots.append(at)
	if OS.get_environment("PROBE_PILE") == "1":
		_spots = _spots.slice(0, 6)
	_w("hold %d  power %d  radius %.2f  range %.1f  mouth %.1f px  thin %.2f  spots %d" % [
		_net.hold, _net.strength(), _net.radius, _net.range_tiles, _net.open_extent(), thin, _spots.size()])


func _w(line: String) -> void:
	_log.store_line(line)
	_log.flush()


## Tiles the open mouth touches whose top is liftable, and how many pieces they hold in all.
func _count_under(at: Vector2) -> Dictionary:
	var tops: Array[int] = _net._reach(at, _net.open_extent(), _net.strength())
	var all_pieces := 0
	var liftable_deep := 0
	for index in tops:
		all_pieces += (_grid.stacks[index] as Array).size()
		for k in (_grid.stacks[index] as Array).size():
			if _grid.defs[_grid.stacks[index][k]].tier <= _net.strength():
				liftable_deep += 1
	return {"tiles": tops.size(), "pieces": all_pieces, "liftable": liftable_deep}


## PROBE_PILE=1: the whole lake emptied but for a square of tiles `half` either side of the
## spot's tile, nine deep in the lightest rubbish: the deep, tight pile a landing used to
## skim two layers off.
func _lay_pile(at: Vector2, half: int) -> void:
	var light := -1
	for d in _grid.defs.size():
		if not _grid.defs[d].keepsake and _grid.defs[d].tier == 0:
			light = d
			break
	for index in _grid.stacks.size():
		_grid.stacks[index].resize(0)
	var tile := Iso.world_to_tile(at)
	for dy in range(-half, half + 1):
		for dx in range(-half, half + 1):
			var index: int = _grid.index_of(int(tile.x) + dx, int(tile.y) + dy)
			for k in 9:
				_grid.stacks[index].append(light)
	_grid._rebuild()


func _process(_delta: float) -> void:
	_frames += 1
	if Time.get_ticks_msec() - _started_ms > 240000:
		_w("wall clock out")
		get_tree().quit()
		return
	if _net.state == CastNet.State.IDLE:
		_cast += 1
		if _cast >= _spots.size():
			_w("done")
			get_tree().quit()
			return
		var at := _spots[_cast]
		if OS.get_environment("PROBE_PILE") == "1":
			_lay_pile(at, (1 + _cast % 3) if OS.get_environment("PROBE_RADIUS") == "" else 0)
		_under = _count_under(at)
		_landed_at = -1
		_main._push_net_numbers()
		if OS.get_environment("PROBE_RADIUS") != "":
			_net.radius = float(OS.get_environment("PROBE_RADIUS"))
			_under = _count_under(at)
		_net.luck_power = 0
		_net.luck_hold = 0
		_net.cast_to(at)
		return
	if _landed_at < 0 and _net.state != CastNet.State.FLYING:
		_landed_at = _net.catch.size()


func _on_landed(cargo: PackedInt32Array) -> void:
	_w("cast %2d  under: %3d tiles %4d pieces %4d liftable  landing took %3d  home %3d / %d" % [
		_cast, _under["tiles"], _under["pieces"], _under["liftable"], _landed_at, cargo.size(), _net.hold])
