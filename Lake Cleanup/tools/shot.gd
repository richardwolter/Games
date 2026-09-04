## Runs the game for a moment and saves what it looks like.
##
## Art changes have to be looked at, and a headless test cannot look. This opens the real
## scene in a real window, lets it settle, and writes a frame to tools/shot.png.
##
##   godot --path . res://tools/shot.tscn
extends Node

const SETTLE_FRAMES := 30
const OUT_PATH := "res://tools/shot.png"

var _main: Node2D
var _frames: int = 0
var _nets: Array[CastNet] = []
var _faces: Array[Angler] = []


## Set the view zoom the way the lake does.
##
## Writing the camera directly stopped working the day the cast push went in: the lake
## multiplies the player's zoom by whatever a cast is leaning on it and writes the result
## every frame, so anything set on the camera from outside is gone by the next one.
func _set_zoom(camera: Camera2D, zoom: float) -> void:
	_main.set(&"_view_zoom", zoom)
	camera.zoom = Vector2(zoom, zoom)


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"autoload_save", false)
	add_child(_main)


## Every pose of the net at once, in a row across the water: the four sequences, each
## sampled at five points, each with a catch in it. Drawn art has to be looked at, and
## looking at one pose at a time by playing the game is not looking at it.
func _stage_nets() -> void:
	var camera := _main.get_node(^"Camera") as Camera2D
	_set_zoom(camera, 1.15)
	camera.position = Iso.tile_to_world(Iso.CENTRE.x + 13.5, Iso.CENTRE.y + 13.5)

	if not _nets.is_empty():
		return
	var grid := _main.get_node(^"Grid") as LakeGrid
	var angler := _main.get_node(^"Angler") as Angler
	var poses := [
		[&"cast_far", CastNet.State.FLYING],
		[&"cast_near", CastNet.State.FLYING],
		[&"land", CastNet.State.SETTLED],
		[&"drag", CastNet.State.REELING],
	]
	for row in poses.size():
		for step in 5:
			var net := CastNet.new()
			net.z_index = 12
			net.z_as_relative = false
			net.grid = grid
			net.angler = angler
			net.radius = 2.05
			net.hold = 6
			net.catch = PackedInt32Array([0, 1, 2, 3, 4, 5])
			_main.add_child(net)
			# Posed by hand rather than played: the state and the numbers the drawing reads
			# off it are set straight, so all twenty frames stand still together.
			net.state = poses[row][1]
			net.set(&"_settled_age", CastNet.LAND_TIME * float(step) / 4.0)
			# Laid out along the two tile axes, which on screen is a diagonal grid: five
			# poses running one way and four sequences the other, far enough apart that a
			# wide net does not sit on the one beside it.
			net.tile_pos = Vector2(
				Iso.CENTRE.x + 4.0 + float(step) * 5.0 - float(row) * 1.5,
				Iso.CENTRE.y + 4.0 + float(row) * 5.5 - float(step) * 1.0
			)
			# A throw is posed by how much of its flight is left, and a drag by how far it
			# has pursed. Both are the numbers the drawing reads, set straight rather than
			# arrived at by playing, so all twenty frames stand still together.
			var reach := net.range_tiles * (0.9 if row == 0 else 0.2)
			net.set(&"_cast_span", reach)
			net.set(&"_cast_from", net.tile_pos - Vector2(reach * float(step) / 4.0, 0.0))
			net.shut = float(step) / 4.0
			net.set_process(false)
			_nets.append(net)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 2:
		# Close in, where a piece of rubbish is a picture rather than a speck.
		var camera := _main.get_node(^"Camera") as Camera2D
		if OS.get_cmdline_user_args().has("boats"):
			# One hull per compass point, each pointing the way it is travelling, so the
			# baked headings can be checked against the direction they claim.
			_set_zoom(camera, 2.2)
			for i in 8:
				var angle := TAU * float(i) / 8.0
				var heading := Vector2(cos(angle), sin(angle))
				var boat := Boat.new()
				boat.z_index = 12
				boat.z_as_relative = false
				boat.auto_ferry = false
				_main.add_child(boat)
				# After it is in the tree: a boat's _ready parks it at its dock.
				boat.tile_pos = Iso.CENTRE + heading * 4.0
				boat.heading = heading
				boat.state = Boat.State.SAILING
				boat.grid = _main.get_node(^"Grid")
				boat.cargo = PackedInt32Array([0, 1, 2, 3, 4, 5])
				# Fitted and under way, so the skimmer's net and the wake are both in shot.
				boat.skim_radius = 2
				boat.skim_sheet = (_main.get_node(^"Net") as CastNet).art_sheet()
				boat.skim_frame = (_main.get_node(^"Net") as CastNet).art_frame(&"land", -1)
				boat.splash = _main.get_node(^"Splash")
		if OS.get_cmdline_user_args().has("close"):
			_set_zoom(camera, 4.0)
			camera.position = Iso.tile_to_world(Iso.CENTRE.x + 14.0, Iso.CENTRE.y + 14.0)
			set_process_internal(false)
		elif OS.get_cmdline_user_args().has("birds"):
			_set_zoom(camera, 5.0)
			camera.position = Iso.tile_to_world(Iso.CENTRE.x + 7.0, Iso.CENTRE.y + 7.0)
		else:
			_set_zoom(camera, 1.6)
		_main.set(&"sludge", 12450.0)
		if OS.get_cmdline_user_args().has("settings"):
			_main.call(&"_set_settings", true)
		if OS.get_cmdline_user_args().has("shed"):
			# A handful of finds, so the room has something in it to look at.
			var found: Array[String] = []
			var room := _main.get_node(^"HUD/Shed/Pad/Lines/Room") as ShedRoom
			var names: PackedStringArray = room.sheets.by_sheet["furniture"]
			for i in mini(names.size(), 14):
				found.append(names[i])
			_main.set(&"unlocked", found)
			_main.call(&"_set_shed", true)
			# A rug with things standing on it, which is the placement this pass is for.
			var rug := ""
			for name: String in names:
				if room.sheets.lies_flat(StringName(name)):
					rug = name
					break
			if not rug.is_empty():
				found.append(rug)
				room.place(StringName(rug), Vector2i(3, 5))
			room.place(StringName(found[0]), Vector2i(2, 1))
			room.place(StringName(found[3]), Vector2i(9, 2))
			room.place(StringName(found[5]), Vector2i(5, 7))
			room.place(StringName(found[8]), Vector2i(14, 9))
	if _frames == 12 and OS.get_cmdline_user_args().has("birds"):
		var flock := _main.get_node(^"Flock") as Flock
		var grid := _main.get_node(^"Grid") as LakeGrid
		# Perches picked by hand, in a ring just off the island, so the birds are in shot
		# rather than wherever the flock would have scattered them.
		for i in 12:
			var tile := grid.index_of(
				int(Iso.CENTRE.x + 5.0 + float(i % 4)), int(Iso.CENTRE.y + 5.0 + float(i / 4))
			)
			if grid.height_of(tile) > 0:
				flock.add_bird(tile)
		for bird: Dictionary in flock.birds:
			# Landed already: the interesting picture is birds sitting on the rubbish.
			bird["travel"] = 0.999
		# And left alone: the flock would otherwise start sending them away again.
		flock.set(&"_rethink", 999.0)
	if OS.get_cmdline_user_args().has("birds") and _frames > 2:
		var camera4 := _main.get_node(^"Camera") as Camera2D
		camera4.position = Iso.tile_to_world(Iso.CENTRE.x + 7.0, Iso.CENTRE.y + 7.0)
	if OS.get_cmdline_user_args().has("close") and _frames > 2:
		# The lake pulls the view back to the angler every frame; hold it out here.
		var camera2 := _main.get_node(^"Camera") as Camera2D
		camera2.position = Iso.tile_to_world(Iso.CENTRE.x + 14.0, Iso.CENTRE.y + 14.0)
	if OS.get_cmdline_user_args().has("net") and _frames > 2:
		_stage_nets()
	if OS.get_cmdline_user_args().has("face") and _frames > 2:
		# The angler in all four facings, side by side, so left and right can be compared
		# against each other rather than one at a time from memory.
		var camera3 := _main.get_node(^"Camera") as Camera2D
		_set_zoom(camera3, 9.0)
		if _frames == 3:
			var pushes := [
				Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)
			]
			for i in pushes.size():
				var who := Angler.new()
				who.z_index = 20
				who.z_as_relative = false
				who.can_walk = false
				_main.add_child(who)
				# Along the constant-height diagonal, so they stand in a row across the
				# screen, and far enough apart that there is no arguing about which is which.
				who.tile_pos = Iso.CENTRE + Vector2(
					float(i) * 1.6 - 2.4, float(i) * -1.6 + 2.4
				)
				who.facing = Iso.world_to_tile(
					(pushes[i] as Vector2).normalized() * Iso.TILE_W
				).normalized()
				who.call(&"_place")
				# Held mid-stride, so the walking rows are what gets compared.
				who.set(&"_step", 1.0)
				_faces.append(who)
			# The angler themself stands where the row is, so they are the row's middle
			# rather than a fifth figure wandering through it.
			var angler := _main.get_node(^"Angler") as Angler
			angler.tile_pos = Iso.CENTRE
			angler.call(&"_place")
		var camera5 := _main.get_node(^"Camera") as Camera2D
		camera5.position = Iso.tile_to_world(Iso.CENTRE.x, Iso.CENTRE.y)
	if OS.get_cmdline_user_args().has("shop") and _frames == 3:
		# The upgrades board, with enough money that some rows are affordable and some are
		# not — the two states are drawn differently and both want looking at.
		_main.set(&"sludge", 9000.0)
		_main.call(&"_set_menu", true)
	if OS.get_cmdline_user_args().has("ui") and _frames > 2:
		# A lake part way cleaned and a purse with something in it, so the meter is caught
		# mid-slide and the money plate has digits to fit rather than a nought.
		_main.set(&"pollution", 0.42)
		_main.set(&"sludge", 12450.0)
		var skin := _main.get_node(^"HUD/Skin")
		if _frames == 3:
			skin.set(&"_shown", 1.0)
	if _frames < SETTLE_FRAMES:
		return
	var shot := get_viewport().get_texture().get_image()
	shot.save_png(ProjectSettings.globalize_path(OUT_PATH))
	get_tree().quit(0)
