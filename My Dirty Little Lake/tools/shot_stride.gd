## Films walkers crossing a pebbled strip of ground, one row each, to judge whether the feet
## stay planted at a given speed and leg cadence (2026-10-11, the walk-pacing pass).
##
## No lake: the question is feet against ground, so each row is a sand band with fixed pebbles
## and one walker crossing it sideways at `tiles` a second (a tile walked sideways on screen
## is 45.25 world px: `Iso.tile_to_world` of a unit step along (1, -1)) with a frame held
## `held` seconds. Drawn at SCALE screen px a world px.
##
##   <exe> --path . --fixed-fps 60 res://tools/shot_stride.tscn
## STRIDE_SET=angler|dogs|loops|final picks the film (final reads the shipped constants); frames go to tools/film/stride_<set>/, then
## ffmpeg makes tools/last_stride_<set>.gif.
extends Node2D

const DogArt := preload("res://scripts/dog_art.gd")

const SCALE := 2.0
const FRAMES := 300
const ROW_TALL := 104.0
const SIDEWAYS := 45.254834  # world px per tile, walking sideways on screen
const LEFT := 230.0

## [label, kind, gait, held seconds, tiles a second]
var rows: Array = []
var _set := "angler"
var _frame := 0
var _sheet: Texture2D
var _poses: Dictionary = {}
var _foot: Dictionary = {}
var _pebbles: Array = []


func _ready() -> void:
	_set = OS.get_environment("STRIDE_SET") if OS.get_environment("STRIDE_SET") != "" else "angler"
	if _set == "angler":
		# The run's planted boot moves about 2.25 art px a frame (drawn 1:1).
		for held: float in [0.035, 0.03, 0.025]:
			var match_speed := 2.25 / held / SIDEWAYS
			for k: float in [0.85, 1.0, 1.15]:
				rows.append(["run %.3fs  %.2f t/s%s" % [held, match_speed * k,
					"" if k == 1.0 else ("  -15%" if k < 1.0 else "  +15%")],
					"angler", &"run_east", held, match_speed * k])
	elif _set == "final":
		# What shipped, read off the game's own constants.
		rows.append(["angler east  %.2f t/s" % Angler.WALK_SPEED, "angler", &"run_east", Angler.RUN_FRAME, Angler.WALK_SPEED])
		rows.append(["angler west  %.2f t/s" % Angler.WALK_SPEED, "angler", &"run_west", Angler.RUN_FRAME, -Angler.WALK_SPEED])
		rows.append(["dog walk  %.2f t/s" % Dog.WALK_SPEED, "dog", &"walk", 0.1, Dog.WALK_SPEED])
		rows.append(["dog walk2  %.2f t/s" % Dog.WALK_SPEED, "dog", &"walk2", 0.1, -Dog.WALK_SPEED])
		rows.append(["dog run  %.2f t/s" % Dog.RUN_SPEED, "dog", &"run", 0.07, Dog.RUN_SPEED])
		rows.append(["dog run2  %.2f t/s" % Dog.RUN_SPEED, "dog", &"run2", 0.07, -Dog.RUN_SPEED])
	elif _set == "loops":
		# Each direction's run loop slowed to a frame every 0.09 s, standing still (speed 0),
		# and east with its repeated last three frames cut, so the seam can be judged.
		var cuts := {"now 0-13": range(14), "A 0-11": range(12), "B 1-11": range(1, 12),
			"C 0-10": range(11)}
		for cut: String in cuts:
			rows.append(["south %s  slow" % cut, "angler", &"run_south", 0.09, 0.0, cuts[cut]])
		for cut: String in ["A 0-11", "B 1-11", "C 0-10"]:
			rows.append(["south %s  0.03s" % cut, "angler", &"run_south", 0.03, 0.0, cuts[cut]])
	else:
		for t: float in [0.35, 0.45, 0.55]:
			rows.append(["walk 0.10s  %.2f t/s" % t, "dog", &"walk", 0.1, t])
		for t: float in [2.0, 2.5, 3.0]:
			rows.append(["run 0.07s  %.2f t/s" % t, "dog", &"run", 0.07, t])
		for t: float in [2.0, 2.5, 3.0]:
			rows.append(["run2 0.07s  %.2f t/s" % t, "dog", &"run2", 0.07, t])
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/character.json"))
	_sheet = load(String(data["sheet"])) if data.has("sheet") else load("res://assets/character.png")
	for pose: String in data["poses"]:
		_poses[pose] = data["poses"][pose]
		var most := 0.0
		for f: Dictionary in data["poses"][pose]:
			most = maxf(most, f["ink"][1] + f["ink"][3])
		_foot[pose] = most
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var x := 0.0
	while x < 2000.0:
		_pebbles.append([x, rng.randi_range(0, 5)])
		x += rng.randf_range(5.0, 13.0)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1600, int(ROW_TALL * rows.size()) + 20)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/film/stride_%s" % _set))
	RenderingServer.frame_post_draw.connect(_grab)


func _process(_delta: float) -> void:
	queue_redraw()


func _grab() -> void:
	if _frame > 10:
		var img := get_viewport().get_texture().get_image()
		img.save_png("res://tools/film/stride_%s/f_%04d.png" % [_set, _frame - 11])
	_frame += 1
	if _frame > FRAMES + 11:
		get_tree().quit()


func _draw() -> void:
	var t := maxf(float(_frame - 11), 0.0) / 60.0
	var font := ThemeDB.fallback_font
	var wide := 1600.0
	for i in rows.size():
		var row: Array = rows[i]
		var ground := ROW_TALL * (i + 1) - 14.0
		draw_rect(Rect2(0, ground - 30.0, wide, 44.0), Color(0.78, 0.69, 0.5))
		draw_rect(Rect2(0, ground - 30.0, wide, 1.0), Color(0.3, 0.3, 0.3))
		for p: Array in _pebbles:
			var px: float = p[0] * SCALE
			if px > wide:
				break
			var dy: float = float(p[1]) * SCALE
			draw_rect(Rect2(px, ground - 2.0 - dy, SCALE * 2.0, SCALE), Color(0.35, 0.28, 0.2))
		draw_string(font, Vector2(8, ground - 40.0), String(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
		var held: float = row[3]
		var speed: float = row[4] * SIDEWAYS * SCALE
		var span := wide - LEFT + 80.0
		var x := LEFT + fposmod(speed * t, span) - 40.0 if speed > 0.0 else LEFT + 120.0
		if speed < 0.0:
			x = wide - fposmod(-speed * t, span) + 40.0
		draw_set_transform(Vector2(x, ground), 0.0, Vector2(SCALE, SCALE))
		if row[1] == "angler":
			var frames: Array = _poses[String(row[2])]
			var order: Array = row[5] if row.size() > 5 else range(frames.size())
			var at: int = order[posmod(int(t / held), order.size())]
			var f: Dictionary = frames[at]
			draw_set_transform(Vector2.ZERO)
			draw_string(font, Vector2(x - 8.0, ground - 96.0), str(at), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.YELLOW)
			draw_set_transform(Vector2(x, ground), 0.0, Vector2(SCALE, SCALE))
			var r: Array = f["region"]
			var ink: Array = f["ink"]
			var box := Rect2(-(ink[0] + ink[2] * 0.5), -float(_foot[String(row[2])]), r[2], r[3])
			draw_texture_rect_region(_sheet, box, Rect2(r[0], r[1], r[2], r[3]))
		else:
			var n := DogArt.length(row[2])
			DogArt.stamp(self, row[2], posmod(int(t / held), n), Vector2.ZERO, Dog.HEIGHT, speed < 0.0)
		draw_set_transform(Vector2.ZERO)
