extends Node
## The last marked pieces going when they are netted (2026-10-05, Richard: "pieces marked at
## game end are not disappearing after being caught"). Thins a new lake to a handful of
## pieces round the island, casts the real net at each in turn and logs, after every haul,
## what the soup, the columns and the arrows still hold for that tile, plus a picture
## before and after (`tools/last_marked_{before,after}.png`, `tools/last_marked.log`).
## Desktop build, own save, under its own node.
##
##   godot --path . --fixed-fps 60 res://tools/probe_last_marked.tscn

const SAVE_PATH := "user://probe_last_marked.save"
const LOG := "res://tools/last_marked.log"
const KEEP := 12

var _main: Node
var _frames := 0
var _out: FileAccess
var _targets: Array[int] = []
var _aimed := -1
var _wait := 0


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	# The save, its backup and its temp: a missing save is read from the backup.
	for path: String in [SAVE_PATH, SAVE_PATH + ".bak", SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE_PATH)
	add_child.call_deferred(_main)
	_out = FileAccess.open(LOG, FileAccess.WRITE)


func _log(line: String) -> void:
	_out.store_line(line)
	_out.flush()


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames > 4000:
		_log("timed out")
		get_tree().quit()
		return
	if _main == null or not _main.is_inside_tree():
		return
	var grid: LakeGrid = _main.get(&"_grid")
	var net: CastNet = _main.get(&"_net")
	if grid == null or net == null:
		return
	if _frames == 40:
		_thin(grid, net)
		return
	if _frames < 120:
		return
	if _frames == 120:
		get_viewport().get_texture().get_image().save_png(
			ProjectSettings.globalize_path("res://tools/last_marked_before.png"))
		_log("marked %s" % str(grid.marked))
	if net.state != CastNet.State.IDLE:
		return
	if _wait > 0:
		_wait -= 1
		return
	if _aimed >= 0:
		_report(grid, _aimed)
		_aimed = -1
		_wait = 70
		return
	if _targets.is_empty():
		get_viewport().get_texture().get_image().save_png(
			ProjectSettings.globalize_path("res://tools/last_marked_after.png"))
		_log("done, marked now %s, pieces %d" % [str(grid.marked), grid.piece_count()])
		get_tree().quit()
		return
	_aimed = _targets.pop_front()
	var at := grid.surface_pos(_aimed)
	_log("cast at %d (stack %d) %s" % [_aimed, grid.stacks[_aimed].size(), str(at)])
	_main.call(&"_cast_at", at)


## Every stack emptied but `KEEP` single pieces within the net's reach of the angler.
func _thin(grid: LakeGrid, net: CastNet) -> void:
	var angler: Node2D = _main.get(&"_angler")
	var spot: Vector2 = (angler as Angler).shore_toward(Vector2(60.0, 47.3))
	(angler as Angler).stand_at(spot)
	_main.call(&"_push_net_numbers")
	_log("range %.1f, strength %d, angler %s, net %d" % [net.range_tiles, net.strength(),
		str((angler as Angler).tile_pos), net.state])
	var kept := 0
	_log("pieces at the thin %d" % grid.piece_count())
	# One piece every level-0 net can lift, the same on every seed.
	var light := 0
	for k in grid.defs.size():
		if grid.defs[k].tier == 0 and not grid.defs[k].keepsake and grid.defs[k].atlas != null:
			light = k
			break
	for index in grid.stacks.size():
		if grid.stacks[index].is_empty():
			continue
		var at := grid.surface_pos(index)
		if kept < KEEP and grid.dry[index] == 0 and net.in_reach(at) \
				and at.distance_to(angler.position) > 30.0:
			grid.stacks[index] = PackedInt32Array([light])
			kept += 1
			_targets.append(index)
		else:
			grid.stacks[index] = PackedInt32Array()
	_log("pieces before %d" % grid.piece_count())
	grid.set(&"_dirty", true)
	grid.queue_redraw()
	_log("kept %d" % kept)


func _report(grid: LakeGrid, index: int) -> void:
	var base: int = grid._slot_base[index]
	var span: int = grid._slot_len[index]
	var shown := 0
	if base >= 0:
		var colours: PackedColorArray = grid.get(&"_mesh_colors")
		for i in span:
			if colours[base + i].a > 0.0:
				shown += 1
	var arrows: Node = _main.get(&"_last_arrows")
	_log("  after: stack %d, base %d span %d shown %d, marked %s, arrows %d, dirty %s" % [
		grid.stacks[index].size(), base, span, shown, str(grid.marked.has(index)),
		(arrows.get(&"spots") as Array).size() if arrows != null else -1, grid.get(&"_dirty")])
