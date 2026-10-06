extends Node
## Opens the lake on a real window, nearly cleaned, and photographs each land animal of the
## fauna pass (2026-10-05): a bunny on the bank and one on the island, the fox, the wolf, a
## snake, a capybara pair, one swimming to the island, and the peacock with its tail fanned
## at the angler. Each is a close crop, `tools/last_fauna_<what>.png`, at three times the
## window's size, plus `tools/last_fauna.log`. Which way each faces, where its shadow falls
## and whether it stands right against the trees is judged on those.
##
## Runs on a save of its own, under its own node. Desktop build, not --headless:
##
##   godot --path . --fixed-fps 60 res://tools/shot_fauna.tscn

const SHOT := "res://tools/last_fauna_%s.png"
const LOG := "res://tools/last_fauna.log"
const SAVE_PATH := "user://shot_fauna.save"
## Frames for the animals to come out of the trees, and between shots.
const SETTLE := 2700
const HOLD := 50
const SHOTS := ["bunny", "bunny_isle", "fox", "wolf", "snake", "capy", "peacock", "behind_plant", "turtle", "turtle_swim", "capy_swim"]
var _main: Node
var _frames := 0
var _shot := -1
var _due := 0
var _target: Dictionary = {}
var _log: FileAccess


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE_PATH)
	_main.set(&"autoload_save", false)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	# Under this node, not the root: a lake hung off the root is the game and wears the menu.
	add_child.call_deferred(_main)
	_log = FileAccess.open(LOG, FileAccess.WRITE)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _main == null or not _main.is_inside_tree():
		return
	if _frames == 6:
		_clean()
		_due = _frames + SETTLE
		get_viewport().warp_mouse(Vector2(8.0, 8.0))
	if _frames < 6 or _frames != _due:
		return
	if _shot >= 0:
		_write(SHOTS[_shot])
	_shot += 1
	if _shot >= SHOTS.size():
		_log.close()
		get_tree().quit()
		return
	_aim(SHOTS[_shot])
	_due = _frames + (HOLD * 8 if SHOTS[_shot] == "capy_swim" else HOLD)


## All but a few pools emptied, the meter at nine tenths, every animal let in.
func _clean() -> void:
	var grid: LakeGrid = _main.get(&"_grid")
	for index in grid.stacks.size():
		if grid.stacks[index].is_empty():
			continue
		var tile := grid.tile_of(index)
		var h := sin(float(tile.x) * 12.9898 + float(tile.y) * 78.233) * 43758.5453
		if (h - floor(h)) >= 0.03:
			grid.stacks[index] = PackedInt32Array()
	grid._rebuild()
	grid.queue_redraw()
	_main._build_filth_map()
	var wild: Wildlife = _main.get(&"_wildlife")
	wild.refresh(_main.clean_share(), _main.get(&"_clean_tiles"), 0.95)
	wild._reckon()
	_log.store_line("clean share %.3f" % _main.clean_share())


func _first(kind: StringName, zone: String = "") -> Dictionary:
	var wild: Wildlife = _main.get(&"_wildlife")
	for c: Dictionary in wild.land_animals():
		if c["kind"] == kind and (zone == "" or c["zone"] == zone) and not c.has("lead"):
			return c
	return {}


func _aim(what: String) -> void:
	var wild: Wildlife = _main.get(&"_wildlife")
	var angler: Angler = _main.get(&"_angler")
	match what:
		"bunny":
			_target = _first(&"bunny", "bank")
		"bunny_isle":
			_target = _first(&"bunny", "isle")
		"fox", "wolf", "snake", "capy":
			_target = _first(StringName(what))
		"peacock":
			_target = _first(&"peacock")
			if not _target.is_empty():
				# The angler stood a little way in front of it, so it fans its tail.
				var at: Vector2 = _target["at"]
				angler.stand_at(Iso.world_to_tile(at + Vector2(0.0, Iso.tile_circle_extent(1.6))))
		"behind_plant":
			# A bunny stood just behind the tallest grown plant near the island: the plant is
			# drawn again over it (Flora.cover).
			_target = _first(&"bunny", "isle")
			var flora: Flora = _main.get(&"_flora")
			var quads: PackedInt32Array = flora.get(&"_quad_at")
			var feet: PackedVector2Array = flora.get(&"_foot")
			var pts: PackedVector2Array = flora.get(&"_points")
			var best := -1
			var tall := 0.0
			var mid := Iso.tile_to_world(Iso.ISLAND_CENTRE.x, Iso.ISLAND_CENTRE.y)
			for k in quads.size():
				if quads[k] < 0 or feet[k].distance_to(mid) > 900.0:
					continue
				var h := pts[quads[k] + 2].y - pts[quads[k]].y
				if h > tall:
					tall = h
					best = k
			if best >= 0 and not _target.is_empty():
				_target["at"] = feet[best] + Vector2(4.0, -4.0)
				_target["to"] = _target["at"]
				_target["state"] = Wildlife.Land.SIT
				_target["timer"] = 99.0
				_log.store_line("behind_plant: plant %d %.0f px tall" % [best, tall])
		"turtle", "turtle_swim":
			# A turtle on its sand, idling; or one put on the water off its beach, swimming in.
			_target = wild.turtles()[0] if not wild.turtles().is_empty() else {}
			if not _target.is_empty():
				var spot: Dictionary = _target["spot"]
				if what == "turtle":
					_target["at"] = spot["land"]
					wild._turtle_rest(_target)
					_target["pose"] = "idle"
					_target["timer"] = 99.0
				else:
					_target["at"] = (spot["water"] as Vector2) + (spot["normal"] as Vector2) * 60.0
					_target["to"] = spot["water"]
					_target["state"] = Wildlife.Turtle.SWIM
				_target["fade"] = 1.0
		"capy_swim":
			_target = _first(&"capy")
			if not _target.is_empty():
				var spot: Dictionary = _target["spot"]
				var isle: Dictionary = wild._isle_spot_for(spot)
				_target["at"] = spot["land"]
				_target["path"] = [isle["water"], isle["land"]]
				_target["trip"] = true
				_target["trip_to"] = "isle"
				_target["to"] = spot["water"]
				_target["state"] = Wildlife.Land.MOVE
				_target["pose"] = "idle"
				for f: Dictionary in wild._followers_of(_target):
					f["at"] = (spot["land"] as Vector2) + Vector2(12.0, 6.0)
	if _target.is_empty():
		_log.store_line("%s: none about" % what)
		return
	_main.set(&"_pan", (_target["at"] as Vector2) - angler.position)
	_main.set(&"_panning", true)


func _write(what: String) -> void:
	if _target.is_empty():
		return
	var wild: Wildlife = _main.get(&"_wildlife")
	var at: Vector2 = _target["at"]
	var frame: String = wild._turtle_frame(_target) if what.begins_with("turtle") else wild._land_frame(_target)
	_log.store_line("%s: at %s zone %s state %d frame %s wet %s" % [what, at, _target.get("zone", ""),
		int(_target["state"]), frame, _target.get("wet", false)])
	var shot := get_viewport().get_texture().get_image()
	var vp := get_viewport()
	var to_screen := vp.get_final_transform() * vp.get_canvas_transform()
	var s: Vector2 = to_screen * (at - Vector2(0.0, 12.0))
	var half := Vector2i(150, 90)
	var box := Rect2i(Vector2i(s) - half, half * 2).intersection(Rect2i(Vector2i.ZERO, shot.get_size()))
	if box.size.x < 20 or box.size.y < 20:
		return
	var crop := shot.get_region(box)
	crop.resize(box.size.x * 3, box.size.y * 3, Image.INTERPOLATE_NEAREST)
	crop.save_png(ProjectSettings.globalize_path(SHOT % what))
