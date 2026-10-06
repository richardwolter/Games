extends Node
## The plates the tree-and-flora mockup is laid on (2026-10-05, `/grill-me` with Richard):
## a nearly cleaned lake, the plants grown, seen from four spots. Each spot is saved twice —
## as the game draws it (`now`), and with the bank's props, the flora and the animals taken
## away (`bare`) — plus a mask of what ground is under every 4 screen pixels, and where the
## game itself put every tree, rock, tuft and plant in view. `tools/flora_mockup.py` lays the
## pack art at those very spots, so the mockup's wood is the game's wood with new pictures.
## A probe, not a test. Desktop build, not --headless:
##
##   <godot> --path . --fixed-fps 60 res://tools/shot_flora_base.tscn
##
## Writes `tools/flora_look/base_<view>_{now,bare,mask}.png` and `base_<view>.json`.
## On a save of its own, under its own node.

const SAVE := "user://probe_flora_base.save"
var OUT := "res://tools/flora_look/%s_" % OS.get_environment("FLORA_TAG") + "%s" 	if OS.get_environment("FLORA_TAG") != "" else "res://tools/flora_look/base_%s"
## `FLORA_FILM=1`: the near north view filmed while it waits, a frame every 4 ticks, into
## tools/flora_look/film/, to see the wood sway.
## Frames for the plants to grow in once the lake is emptied.
const GROW := 600
## Mask cell, in screen pixels.
const CELL := 4

var _lake: Node2D
var _frames := 0
var _views: Array = []
var _at := 0
var _phase := 0
var _wait := 0


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/flora_look"))
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	_lake = load("res://scenes/main.tscn").instantiate()
	_lake.set(&"save_path", SAVE)
	_lake.set(&"autoload_save", false)
	add_child.call_deferred(_lake)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if Time.get_ticks_msec() > 240000:
		get_tree().quit(1)
		return
	if _lake == null or not _lake.is_inside_tree() or _frames < 6:
		return
	if _frames == 6:
		_empty()
		_views = _make_views()
		get_viewport().warp_mouse(Vector2(8.0, 8.0))
		return
	if _frames < 6 + GROW:
		return
	if _at >= _views.size():
		get_tree().quit()
		return
	var v: Dictionary = _views[_at]
	match _phase:
		0:
			_set_bare(false)
			_aim(v["at"], v["zoom"])
			_wait = _frames + 90
			_phase = 1
		1:
			_aim(v["at"], v["zoom"])
			if OS.get_environment("FLORA_FILM") != "" and v["name"] == "north_near" and _frames % 4 == 0:
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/flora_look/film"))
				get_viewport().get_texture().get_image().get_region(Rect2i(640, 100, 640, 360)).save_png(
					"res://tools/flora_look/film/f_%03d.png" % (_frames / 4))
			if _frames < _wait:
				return
			_shoot(v["name"] + "_now")
			_write_layout(v)
			_set_bare(true)
			_wait = _frames + 4
			_phase = 2
		2:
			_aim(v["at"], v["zoom"])
			if _frames < _wait:
				return
			_shoot(v["name"] + "_bare")
			_write_mask(v["name"])
			_phase = 0
			_at += 1


## Everything but a few pools of soup lifted, the way `shot_nature` cleans.
func _empty() -> void:
	var grid: LakeGrid = _lake.get(&"_grid")
	for index in grid.stacks.size():
		if grid.stacks[index].is_empty():
			continue
		var tile := grid.tile_of(index)
		var h := sin(float(tile.x) * 12.9898 + float(tile.y) * 78.233) * 43758.5453
		if (h - floor(h)) >= 0.04:
			grid.stacks[index] = PackedInt32Array()
	grid._rebuild()
	grid.queue_redraw()
	_lake._build_filth_map()


func _make_views() -> Array:
	var north := _shore_at(true)
	var south := _shore_at(false)
	return [
		{"name": "north", "at": north + Vector2(0.0, -120.0), "zoom": 0.67},
		{"name": "north_near", "at": north + Vector2(0.0, -90.0), "zoom": 1.0},
		{"name": "south", "at": south + Vector2(0.0, 100.0), "zoom": 0.67},
		{"name": "isle", "at": Iso.tile_to_world(Iso.ISLAND_CENTRE.x, Iso.ISLAND_CENTRE.y) + Vector2(-140.0, 40.0), "zoom": 0.67},
	]


## The bank's waterline at the top (or bottom) of the screen, in world pixels.
func _shore_at(top: bool) -> Vector2:
	var best := Vector2.ZERO
	var first := true
	for k in 720:
		var a := TAU * float(k) / 720.0
		var t := Iso.basin_point(a, 1.0)
		var w := Iso.tile_to_world(t.x, t.y)
		if first or (top and w.y < best.y) or (not top and w.y > best.y):
			best = w
			first = false
	return best


func _aim(at: Vector2, zoom: float) -> void:
	_lake.set(&"_view_zoom", zoom)
	_lake.call(&"_push_zoom")
	_lake.set(&"_free_view", true)
	_lake.set(&"_free_at", at)
	(_lake.get(&"_camera") as Camera2D).position = at


func _set_bare(bare: bool) -> void:
	for net_name in [&"_net", &"_net2"]:
		var net: Node = _lake.get(net_name)
		if net is CanvasItem:
			(net as CanvasItem).visible = false
	var hud := _lake.find_child("HUD", false, false)
	if hud is CanvasLayer:
		(hud as CanvasLayer).visible = false
	for name in [&"_flora", &"_wildlife", &"_fish", &"_flock"]:
		var n: Node = _lake.get(name)
		if n is CanvasItem:
			(n as CanvasItem).visible = not bare
	for b: Boat in _lake.get(&"_boats"):
		b.visible = not bare
	for g: Ground in _lake.get(&"_grounds"):
		if g.layer != Ground.Layer.OUTSIDE:
			continue
		if bare:
			g.set_meta(&"keep_props", g.get(&"_props"))
			g.set(&"_props", {})
		elif g.has_meta(&"keep_props"):
			g.set(&"_props", g.get_meta(&"keep_props"))
			g.remove_meta(&"keep_props")
		g.set(&"_placed", [])
		g.queue_redraw()


func _scale() -> float:
	return float(get_viewport().get_texture().get_width()) / get_viewport().get_visible_rect().size.x


func _to_screen(world: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * (get_viewport().get_canvas_transform() * world)


func _shoot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png((OUT % name) + ".png")


## Where the game put every bank prop and every plant that is up, in image pixels, with
## image pixels per world pixel, so the mockup can stand new pictures on the same feet.
func _write_layout(v: Dictionary) -> void:
	var size := Vector2(get_viewport().get_texture().get_size())
	var room := Rect2(Vector2(-200.0, -100.0), size + Vector2(400.0, 500.0))
	var cam: Camera2D = _lake.get(&"_camera")
	var props: Array = []
	for g: Ground in _lake.get(&"_grounds"):
		var placed: Array = g.get(&"_placed")
		for i in range(0, placed.size(), 2):
			var foot: Vector2 = g.to_global(placed[i])
			var p := _to_screen(foot)
			if not room.has_point(p):
				continue
			var art: Texture2D = placed[i + 1]
			var t := Iso.world_to_tile(foot)
			props.append({
				"x": p.x, "y": p.y, "art": art.resource_path.get_file(),
				"dir": art.resource_path.get_base_dir().get_file(),
				"layer": "island" if g.layer == Ground.Layer.ISLAND else "bank",
				"out": Ground.out_of_water(t.x, t.y),
			})
	var plants: Array = []
	var flora: Flora = _lake.get(&"_flora")
	var feet: PackedVector2Array = flora.get(&"_foot")
	var ages: PackedFloat32Array = flora.get(&"_age")
	var species: PackedStringArray = flora.get(&"_species")
	var ranks: PackedFloat32Array = flora.get(&"_rank")
	for k in feet.size():
		var p := _to_screen(flora.to_global(feet[k]))
		if not room.has_point(p):
			continue
		var t := Iso.world_to_tile(flora.to_global(feet[k]))
		plants.append({
			"x": p.x, "y": p.y, "species": species[k], "kind": flora._kind_at(t),
			"grown": ages[k] > 0.0, "rank": ranks[k],
		})
	var data := {
		"view": v["name"], "zoom": v["zoom"],
		"px_per_world": (get_viewport().get_final_transform() * get_viewport().get_canvas_transform()).x.x,
		"final": str(get_viewport().get_final_transform()), "scale": _scale(),
		"cam_xform": str(cam.get_canvas_transform()), "view_xform": str(get_viewport().get_canvas_transform()),
		"size": [size.x, size.y], "cell": CELL,
		"props": props, "plants": plants,
	}
	var f := FileAccess.open((OUT % v["name"]) + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify(data, " "))
	f.close()


## What ground each CELL of the picture is: R 0 off / 1 water / 2 island sand / 3 island
## lawn / 4 bank sand / 5 bank lawn (times 40), G tiles out of the water times 4 plus 128.
func _write_mask(name: String) -> void:
	var size := get_viewport().get_texture().get_size()
	var w := size.x / CELL
	var h := size.y / CELL
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var back := (get_viewport().get_final_transform() * get_viewport().get_canvas_transform()).affine_inverse()
	var grounds: Array = _lake.get(&"_grounds")
	for y in h:
		for x in w:
			var world := back * Vector2((x + 0.5) * CELL, (y + 0.5) * CELL)
			var t := Iso.world_to_tile(world)
			var kind := 1
			for g: Ground in grounds:
				var k := g.kind_at(t.x, t.y)
				if k == Ground.Kind.SAND or k == Ground.Kind.GRASS:
					var isle := g.layer == Ground.Layer.ISLAND
					kind = (2 if isle else 4) + (1 if k == Ground.Kind.GRASS else 0)
					break
			var out := Ground.out_of_water(t.x, t.y)
			img.set_pixel(x, y, Color8(kind * 40, clampi(int(out * 4.0 + 128.0), 0, 255), 0))
	img.save_png((OUT % name) + "_mask.png")
