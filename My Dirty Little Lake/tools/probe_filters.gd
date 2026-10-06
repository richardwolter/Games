extends Node
## Which canvas items draw smoothed (2026-10-02): the project's default texture filter is
## linear, so any node that draws a picture and does not set nearest itself — or inherit it —
## draws its pixel art blurred. Walks the whole tree once the lake is up (the menu, the HUD,
## every board) and writes each item whose effective filter is linear, grouped by script, to
## `tools/last_filters.log`. A probe, not a test: some items are linear on purpose (the logo,
## a vector mark, a frozen frame) and only a person can say which.
##
##   <godot> --path . --fixed-fps 60 res://tools/probe_filters.tscn
##
## Own save, own node.

const SAVE := "user://probe_filters.save"

var _lake: Node
var _age := 0.0
var _done := false


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	_lake = load("res://scenes/main.tscn").instantiate()
	_lake.set(&"save_path", SAVE)
	_lake.set(&"autoload_save", false)
	add_child(_lake)


func _physics_process(delta: float) -> void:
	_age += delta
	if Time.get_ticks_msec() > 60000:
		get_tree().quit(1)
		return
	if _done or _age < 3.0:
		return
	_done = true
	var groups := {}
	_walk(get_tree().root, groups)
	var out := FileAccess.open("res://tools/last_filters.log", FileAccess.WRITE)
	out.store_line("root default nearest: %s" % str(get_tree().root.canvas_item_default_texture_filter == Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST))
	var keys := groups.keys()
	keys.sort()
	for key: String in keys:
		var paths: Array = groups[key]
		out.store_line("%s  x%d" % [key, paths.size()])
		for i in mini(paths.size(), 4):
			out.store_line("    %s" % paths[i])
	out.flush()
	get_tree().quit()


func _walk(node: Node, groups: Dictionary) -> void:
	# Hidden ones too: the boards (shop, shed, wash room) are up only when opened.
	if node is CanvasItem:
		var item := node as CanvasItem
		if _effective(item) != CanvasItem.TEXTURE_FILTER_NEAREST \
				and _effective(item) != CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS:
			var script := item.get_script() as Script
			var key := (script.resource_path if script != null else "") + " (" + item.get_class() + ")"
			if not groups.has(key):
				groups[key] = []
			(groups[key] as Array).append(str(item.get_path()).replace("/root/", ""))
	for child in node.get_children():
		_walk(child, groups)


## The filter an item draws with: its own, or its parent's up to the first that sets one,
## and the viewport's default past a CanvasLayer or the root (Prefs sets the root's).
func _effective(item: CanvasItem) -> int:
	var at: Node = item
	while at is CanvasItem:
		var f := (at as CanvasItem).texture_filter
		if f != CanvasItem.TEXTURE_FILTER_PARENT_NODE:
			return f
		at = at.get_parent()
	var nearest := item.get_viewport().canvas_item_default_texture_filter \
		== Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	return CanvasItem.TEXTURE_FILTER_NEAREST if nearest else CanvasItem.TEXTURE_FILTER_LINEAR
