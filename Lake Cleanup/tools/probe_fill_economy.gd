extends Node
## What a fresh lake holds, in money: pieces, mean pay and total value per material, and
## the share of the water in each weight tier. Written to hold the economy steady when the
## rubbish catalogue changes — run it before and after and compare `tools/last_fill_economy.log`.
##
## Headless is fine (nothing is drawn). Own save path, under its own node:
##
##   godot --path . --headless res://tools/probe_fill_economy.tscn --log-file <path>

const LOG := "res://tools/last_fill_economy.log"
const SAVE_PATH := "user://probe_fill_economy.save"

var _main: Node
var _frames := 0


func _ready() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE_PATH)
	_main.set(&"autoload_save", false)
	add_child.call_deferred(_main)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames == 6:
		_count()
		get_tree().quit()
	elif _frames > 600:
		get_tree().quit()


func _count() -> void:
	var grid: LakeGrid = _main.get(&"_grid")
	var pieces := [0, 0, 0, 0]
	var value := [0.0, 0.0, 0.0, 0.0]
	var tiers := [0, 0, 0, 0, 0]
	var kinds := {}
	var total := 0
	for stack in grid.stacks:
		for i in stack:
			var def := grid.defs[i]
			if def.keepsake:
				continue
			var m := int(def.material)
			pieces[m] += 1
			value[m] += float(_main.call(&"piece_pay", i, m))
			tiers[def.tier] += 1
			kinds[def.piece] = int(kinds.get(def.piece, 0)) + 1
			total += 1
	var out := FileAccess.open(LOG, FileAccess.WRITE)
	out.store_line("pieces %d  value %.0f" % [total, value.reduce(func(a, b): return a + b, 0.0)])
	for m in 4:
		out.store_line("material %s  pieces %d (%.3f)  mean pay %.3f  value %.0f" % [
			TrashDef.KIND_NAMES[m], pieces[m], float(pieces[m]) / total,
			value[m] / maxf(1.0, pieces[m]), value[m]])
	for t in 5:
		out.store_line("tier %d  %.3f" % [t, float(tiers[t]) / total])
	var names := kinds.keys()
	names.sort_custom(func(a, b): return kinds[a] > kinds[b])
	for n in names:
		out.store_line("  %-20s %d" % [n, kinds[n]])
