extends Node
## Close crops of a tree, a rock and a pier's sign with their shadows, for judging whether a
## shadow meets what casts it. A probe, not a test. Desktop build, not --headless:
##
##   <godot> --path . --fixed-fps 60 res://tools/shot_props.tscn
##
## Saves `tools/last_props_{tree,tree2,rock,sign}.png` and `tools/last_props.log`.
## On a save of its own, under its own node.

const SAVE := "user://probe_props.save"
const CROP := Vector2i(420, 360)

var _lake: Node2D
var _age := 0.0
var _step := 0
var _log: FileAccess
var _shots: Array = []


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_log = FileAccess.open("res://tools/last_props.log", FileAccess.WRITE)
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	_lake = load("res://scenes/main.tscn").instantiate()
	_lake.set(&"save_path", SAVE)
	_lake.set(&"autoload_save", false)
	add_child(_lake)


func _say(line: String) -> void:
	if _log != null:
		_log.store_line(line)
		_log.flush()


## The first prop of each kind on the south bank, nearest the water: [name, world point].
func _targets() -> Array:
	var out: Array = []
	var middle := Iso.tile_to_world(Iso.CENTRE.x, Iso.CENTRE.y)
	for g: Ground in _lake.get(&"_grounds"):
		if g.layer != Ground.Layer.OUTSIDE:
			continue
		var placed: Array = g.get(&"_placed")
		var best := {}
		for i in range(0, placed.size(), 2):
			var foot: Vector2 = placed[i]
			var art: Texture2D = placed[i + 1]
			if foot.y > middle.y - 200.0:
				continue
			var t := Iso.world_to_tile(foot)
			var out_w := Ground.out_of_water(t.x, t.y)
			var path := art.resource_path
			var kind := "tree" if path.contains("Tree") else ("rock" if path.contains("Rocks") and art.get_width() > 16 else "")
			if kind.is_empty():
				continue
			if not best.has(kind) or out_w < float(best[kind][0]):
				best[kind] = [out_w, g.to_global(foot)]
		for kind: String in best:
			out.append([kind, best[kind][1]])
	# Every forest-floor plant grown at once, and the view on the one nearest the lake's
	# north middle, so the trees round it are the far bank's.
	var flora: Flora = _lake.get(&"_flora")
	var feet: PackedVector2Array = flora.get(&"_foot")
	var ages: PackedFloat32Array = flora.get(&"_age")
	var pick := Vector2.INF
	for k in feet.size():
		if flora._kind_at(Iso.world_to_tile(feet[k])) == "forest" and float(flora.get(&"_rank")[k]) < Flora.MOST:
			ages[k] = 99.0
			if feet[k].y < middle.y - 300.0 and (pick == Vector2.INF or absf(feet[k].x - middle.x) < absf(pick.x - middle.x)):
				pick = feet[k]
	flora.set(&"_age", ages)
	flora.set(&"_dirty", true)
	flora.queue_redraw()
	if pick != Vector2.INF:
		out.append(["forest", pick])
	for yard in _lake.get(&"_dropoffs"):
		var book: Dictionary = yard.call(&"_book")
		out.append(["sign", (yard as Node2D).to_global(yard.call(&"_world", book["sign_foot"], book))])
		break
	return out


func _physics_process(delta: float) -> void:
	_age += delta
	if Time.get_ticks_msec() > 90000:
		get_tree().quit(1)
		return
	match _step:
		0:
			if _age < 2.0:
				return
			_shots = _targets()
			_say("targets %s" % [_shots])
			_step = 1
			_age = 0.0
		1:
			if _shots.is_empty():
				get_tree().quit()
				return
			var at: Vector2 = _shots[0][1]
			_lake.set(&"_view_zoom", 1.5)
			_lake.call(&"_push_zoom")
			_lake.set(&"_free_view", true)
			_lake.set(&"_free_at", at)
			_lake.get(&"_camera").position = at
			if _age < 1.0:
				return
			var shot := get_viewport().get_texture().get_image()
			var scale := float(shot.get_width()) / get_viewport().get_visible_rect().size.x
			var cam: Camera2D = _lake.get(&"_camera")
			var p := (cam.get_canvas_transform() * at) * scale
			var corner := Vector2i(p) - Vector2i(CROP.x / 2, CROP.y * 2 / 3)
			corner = corner.clamp(Vector2i.ZERO, shot.get_size() - CROP)
			shot.get_region(Rect2i(corner, CROP)).save_png("res://tools/last_props_%s.png" % _shots[0][0])
			_say("%s at %s" % [_shots[0][0], at])
			_shots.pop_front()
			_age = 0.0
