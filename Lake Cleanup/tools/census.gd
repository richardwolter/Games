## Which canvas items the running game has, and which of them cost draw calls.
##
## Opens the real scene, waits for it to settle, then hides one top-level branch at a time
## and reads the frame's draw calls with it gone. The difference is that branch's share.
## Written to tools/last_census.log (print does not reach a shell on this build).
##
##   godot --path . res://tools/census.tscn
extends Node

const LOG_PATH := "res://tools/last_census.log"
const SETTLE := 60

var _main: Node2D
var _n: int = 0
var _targets: Array[CanvasItem] = []
var _at: int = -1
var _base: int = 0
var _lines: PackedStringArray = PackedStringArray()


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"autoload_save", false)
	add_child(_main)


func _draws() -> int:
	return int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))


func _collect(node: Node, depth: int) -> void:
	for child in node.get_children():
		if child is CanvasItem and (child as CanvasItem).visible:
			_targets.append(child)
		if depth < 1:
			_collect(child, depth + 1)


func _census() -> void:
	var by_kind := {}
	var all := _main.find_children("*", "CanvasItem", true, false)
	for item in all:
		var script: Script = item.get_script()
		var kind: String = script.resource_path.get_file() if script else item.get_class()
		by_kind[kind] = by_kind.get(kind, 0) + 1
	var kinds := by_kind.keys()
	kinds.sort_custom(func(a, b): return by_kind[a] > by_kind[b])
	_lines.append("canvas items %d" % all.size())
	for k in kinds.slice(0, 25):
		_lines.append("  %5d  %s" % [by_kind[k], k])


func _process(_delta: float) -> void:
	_n += 1
	if _n < SETTLE:
		return
	if _at == -1:
		_base = _draws()
		_census()
		_lines.append("draw calls, everything on: %d" % _base)
		_collect(_main, 0)
		_at = 0
		_targets[0].visible = false
		return
	# Two frames per target: the hide lands, then the frame it lands in is measured.
	if _n % 2 == 1:
		return
	var gone := _base - _draws()
	var item := _targets[_at]
	_lines.append("  %6d  %s" % [gone, _main.get_path_to(item)])
	item.visible = true
	_at += 1
	if _at >= _targets.size():
		var log := FileAccess.open(LOG_PATH, FileAccess.WRITE)
		for line in _lines:
			log.store_line(line)
		log.close()
		get_tree().quit()
		return
	_targets[_at].visible = false
