extends Node
## The island hive after the visual overhaul (2026-10-18, "Hive C": the cupboard of jars, the
## swarm's tree, the mini bees), photographed in every island state. Desktop build:
##
##   <godot> --path . --fixed-fps 60 res://tools/shot_hive_island.tscn --log-file tools/last_hive_island_engine.log
##
## Saves `tools/last_hive_island_{empty,swarm,busy,jars1,jars2,ready,ready_near,flowers}.png`
## (crops on the hive and its tree, 2x nearest) and `tools/last_hive_island.log`. On a save of
## its own, under its own node, out on a wall clock.

const Style := preload("res://scripts/style.gd")

const SAVE := "user://probe_hive_island.save"
const CROP := Vector2i(240, 170)
const ZOOM := 4
const QUIT_AFTER_MS := 90000

var _lake: Node2D
var _age := 0.0
var _step := 0
var _log: FileAccess


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	TranslationServer.set_locale("en")
	Style.set_locale("en")
	_log = FileAccess.open("res://tools/last_hive_island.log", FileAccess.WRITE)
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	Lake.force_hive = true
	_lake = load("res://scenes/main.tscn").instantiate()
	_lake.set(&"save_path", SAVE)
	_lake.set(&"autoload_save", false)
	add_child(_lake)


func _say(line: String) -> void:
	if _log != null:
		_log.store_line(line)
		_log.flush()


func _hive() -> Hive:
	return _lake.get(&"_hive")


func _crop(called: String) -> void:
	var shot := get_viewport().get_texture().get_image()
	var scale := float(shot.get_width()) / get_viewport().get_visible_rect().size.x
	var hive := _hive()
	var both := hive.picture_rect().merge(Hive.shrub_box())
	var middle := hive.get_global_transform_with_canvas() * both.get_center()
	var at := middle * scale
	var corner := Vector2i(at) - Vector2i(CROP.x / 2, CROP.y / 2)
	corner = corner.clamp(Vector2i.ZERO, shot.get_size() - CROP)
	var cut := shot.get_region(Rect2i(corner, CROP))
	cut.resize(CROP.x * ZOOM, CROP.y * ZOOM, Image.INTERPOLATE_NEAREST)
	cut.save_png("res://tools/last_hive_island_%s.png" % called)
	_say("%s: stage %d, jars %d shown %d, frame %s, level %d, mark %s, commuters %d, scale %.2f" % [
		called, hive.stage, hive.jars, hive.jars_shown(), hive.hive_frame(), hive.window_level(),
		hive.mark(), hive.commuters().size(), scale
	])


func _next() -> void:
	_step += 1
	_age = 0.0


func _physics_process(delta: float) -> void:
	_age += delta
	if Time.get_ticks_msec() > QUIT_AFTER_MS:
		_say("wall clock: quit at step %d" % _step)
		get_tree().quit(1)
		return
	var hive := _hive()
	var angler: Angler = _lake.get(&"_angler")
	match _step:
		0:
			if _age < 2.0:
				return
			angler.stand_at(Hive.tile + Vector2(1.2, 0.2))
			_say("hive tile %s position %s picture %s tree %s swarm %s half %s" % [
				Hive.tile, hive.position, hive.picture_rect(), Hive.shrub_box(), Hive.swarm_box(), Hive.half])
			var mid := Hive.tile + Hive.centre
			var lawn := true
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					lawn = lawn and Iso.on_lawn(mid + Vector2(sx * Hive.half.x, sy * Hive.half.y))
			var shed_pic: Rect2 = _lake.call(&"_shed_picture")
			var tree_foot := hive.position + Vector2(Hive.shrub_box().get_center().x, Hive.shrub_box().end.y - 1.0)
			_say("footprint on lawn %s; picture right %.0f against hut left %.0f; tree foot on lawn %s, on island %s" % [
				lawn, hive.position.x + hive.picture_rect().end.x, shed_pic.position.x,
				Iso.on_lawn(Iso.world_to_tile(tree_foot)), Iso.on_island_ground(Iso.world_to_tile(tree_foot))])
			var flora: Flora = _lake.get(&"_flora")
			var hosts := 0
			var species: PackedStringArray = flora.get(&"_species")
			var feet: PackedVector2Array = flora.get(&"_foot")
			for k in feet.size():
				if Flora.is_host(species[k]) and Iso.on_island_ground(Iso.world_to_tile(feet[k])):
					hosts += 1
			_say("island host candidates %d (the swarm wants %d)" % [hosts, Lake.SWARM_HOSTS])
			for along in [Vector2(-0.3, 0.0), Vector2(0.3, 0.0)]:
				var north := Iso.tile_to_world(Hive.tile.x + along.x, Hive.tile.y - Hive.half.y - 0.35)
				var south := Iso.tile_to_world(Hive.tile.x + along.x + 0.1, Hive.tile.y + Hive.half.y + 0.35)
				_say("walker layers north %d south %d hive z %d" % [
					int(_lake.call(&"_walker_layer", north)), int(_lake.call(&"_walker_layer", south)), hive.z_index])
			_next()
		1:
			if _age < 1.0:
				return
			_crop("empty")
			hive.moment_seen = true
			hive.set_stage(Hive.Stage.SWARM)
			_next()
		2:
			if _age < Hive.SHRUB_GROW + 0.8:
				return
			_crop("swarm")
			hive.set_stage(Hive.Stage.BUSY)
			hive.jars = 6
			hive.refill_from = hive.play_now - 30.0
			hive.refill_at = hive.play_now + 30.0
			_next()
		3:
			if _age < 1.0:
				return
			_crop("busy")
			hive.jars = 1
			_next()
		4:
			if _age < 0.3:
				return
			_crop("jars1")
			hive.jars = 2
			_next()
		5:
			if _age < 0.3:
				return
			_crop("jars2")
			hive.ready_seen = true
			hive.jars = 12
			hive.set_stage(Hive.Stage.READY)
			angler.stand_at(Hive.tile + Vector2(3.5, 1.5))
			_next()
		6:
			if _age < 1.0:
				return
			_crop("ready")
			angler.stand_at(Hive.tile + Vector2(1.2, 0.2))
			_next()
		7:
			if _age < 0.6:
				return
			_crop("ready_near")
			# Flowers to visit, off to the lower right: the stream leaves the door and comes down.
			var at := hive.position
			hive.host_spots = func() -> PackedVector2Array:
				return PackedVector2Array([at + Vector2(70, 40), at + Vector2(-40, 50), at + Vector2(90, 10)])
			hive.refresh_spots()
			hive.set_stage(Hive.Stage.BUSY)
			hive.refill_from = hive.play_now - 10.0
			hive.refill_at = hive.play_now + 60.0
			_next()
		8:
			if _age < 1.3:
				return
			_crop("flowers")
			# A clean lake, every plant grown: the flora's own bees at their flowers, and the
			# hive's commuters going to the island's real hosts.
			var grid: LakeGrid = _lake.get(&"_grid")
			# All but the far east bank: an empty lake would end the run and roll the credits.
			for index in grid.stacks.size():
				if grid.tile_of(index).x < int(Iso.CENTRE.x) + 30:
					grid.stacks[index].resize(0)
			grid._rebuild()
			_lake.call(&"_build_filth_map")
			var flora: Flora = _lake.get(&"_flora")
			flora.refresh(1.0, true)
			var ages: PackedFloat32Array = flora.get(&"_age")
			var delay: PackedFloat32Array = flora.get(&"_delay")
			for k in ages.size():
				ages[k] = delay[k] + Flora.GROW_TIME + 1.0
			flora.set(&"_age", ages)
			flora.set(&"_dirty", true)
			flora.call(&"_find_bees")
			flora.queue_redraw()
			hive.host_spots = func() -> PackedVector2Array:
				return flora.island_host_spots()
			hive.refresh_spots()
			_next()
		9:
			if _age < 1.5:
				return
			_crop("clean")
			var flora: Flora = _lake.get(&"_flora")
			var points: PackedVector2Array = flora.get(&"_bee_points")
			_say("flora bees %d, island hosts %d" % [points.size(), flora.island_hosts()])
			if not points.is_empty():
				# Crop on the bee nearest the hive.
				var best := points[0]
				for p in points:
					if p.distance_to(hive.position) < best.distance_to(hive.position):
						best = p
				var shot := get_viewport().get_texture().get_image()
				var scale := float(shot.get_width()) / get_viewport().get_visible_rect().size.x
				var on := (flora.get_global_transform_with_canvas() * best) * scale
				var box := Vector2i(160, 100)
				var corner := (Vector2i(on) - box / 2).clamp(Vector2i.ZERO, shot.get_size() - box)
				var cut := shot.get_region(Rect2i(corner, box))
				cut.resize(box.x * 6, box.y * 6, Image.INTERPOLATE_NEAREST)
				cut.save_png("res://tools/last_hive_island_flora_bees.png")
			_say("done")
			get_tree().quit(0)
