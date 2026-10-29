extends Node
## Films the hive room's ASMR short (2026-10-29, `/grill-me` with Richard): three moments,
## each driven by script the way a player would work it, for a vertical social video cut in
## the marketing folder (`2 Work/hive_asmr/build_hive_asmr.py`).
##
## - `smoke`: the smoker drifts in, pumps on the top of the beard until its bees fold their
##   wings and doze, moves down and quiets the middle band, then rests smouldering. The
##   entrance is never smoked, so the room's ending (rays, crown) never plays.
## - `uncap`: the hot knife drawn down the first face at the pace that never strains, the
##   honey running off into the flume and the bucket, the frame turning, a little of the
##   second face.
## - `pour`: the lever held until each jar reaches the line, let go, the lid pops on and the
##   next jar slides in. Two jars; the third is let go short of the line, so it is never done
##   and the rosette never drops.
##
## The room's plank, hint card and close cross are hidden every frame. Every frame of a shot
## is the whole 1920x1080 window as a JPEG in `tools/film/hive_asmr/<shot>/`; the cut crops
## the portrait close-up out of it and blows it up twice, nearest, so one art pixel is six
## pixels of the final video. Under Godot's Movie Maker the game's own sound is recorded per
## shot as `sfx.wav` and `ambience.wav` (`film_audio.gd`), from the shot's first kept frame.
## `last_hive_asmr.log` in that folder says what happened on which kept frame.
##
##   godot --path . --write-movie tools/film/_movie.avi res://tools/shot_hive_asmr.tscn --log-file tools/film/hive_asmr.log
##
## (with an `override.cfg` holding `editor/movie_writer/mjpeg_quality` low; the .avi is thrown
## away.) Desktop build. Under its own node, on its own save, quits on a wall clock too.
## `HIVE_ASMR_ONLY=uncap` films one shot (the pour always follows a cut so the bucket is full).

const Style := preload("res://scripts/style.gd")
const FilmAudio := preload("res://tools/film_audio.gd")
const SAVE_PATH := "user://shot_hive_asmr.save"
const OUT := "res://tools/film/hive_asmr"
## Under Movie Maker a whole-window JPEG a frame runs at a few frames a second.
const QUIT_AFTER_MS := 1200000
const WINDOW := Vector2i(1920, 1080)
const CANVAS := Vector2i(1280, 720)
## How clean the lake behind looks (the meter's share left): late game, clear water.
const LAKE_FILTH := 0.12

## Frames (60 a second). The room opens, the step is waited on, and a shot is kept for its
## length from the frame it starts.
const OPEN_AT := 20
const SMOKE_FRAMES := 720
const UNCAP_FRAMES := 840
const POUR_FRAMES := 900

## The smoke: where the nozzle rests (painted px, off the middle band, out of reach), where it
## sits to smoke each band (off the band's middle), how long it takes to glide between, and
## how long it pumps on each band.
const SMOKE_REST := Vector2(98.0, 22.0)
const SMOKE_ON := Vector2(62.0, 8.0)
const SMOKE_GLIDE := 0.9
const SMOKE_PUMP := 2.6
const SMOKE_START := 0.8

## The knife: the pace it is drawn down (painted px a second; the step's cap is 55 and it
## strains past 10 ahead of the blade), when it starts, and how long the honey runs before the
## second face is started.
const KNIFE_PACE := 42.0
const KNIFE_FROM := 0.7
const SECOND_FACE_AFTER := 3.6

## The pour: the pause before each jar, and the fill it is let go at (the line is 0.86). The
## last jar is let go short of done (`POUR_LAST_TO`, under the step's 0.7), so the honey still
## runs under the end card and the step's ending (the rosette, the crown) never plays.
const POUR_PAUSE := 0.55
const POUR_TO := 0.87
const POUR_JARS := 3
const POUR_LAST_TO := 0.62

var _main: Node
var _frames := 0
var _log: FileAccess
var _started := 0
var _audio: RefCounted
var _only := OS.get_environment("HIVE_ASMR_ONLY")

## Which shot is up, the frame it began on, its kept frames, and its folder.
var _shot := &""
var _shot_from := -1
var _saved := 0
var _dir := ""
var _queue: Array[StringName] = []

## The smoke's own state: the band being worked, where the nozzle is and is going.
var _smoke_t := 0.0
var _nozzle := Vector2.ZERO
## The uncap's: the face the probe is on and when the first face finished.
var _face_done_at := -1.0
var _uncap_t := 0.0
## The pour's: jars let go, when the last let-go was, and whether the lever is held.
var _poured := 0
var _pour_t := 0.0
var _pour_wait := 0.0
var _holding := false


func _ready() -> void:
	_started = Time.get_ticks_msec()
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.borderless = true
	win.size = WINDOW
	win.position = Vector2i.ZERO
	win.content_scale_size = CANVAS
	var root := ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(root)
	_log = FileAccess.open(OUT + "/last_hive_asmr.log", FileAccess.WRITE)
	for path in [SAVE_PATH, SAVE_PATH + ".bak", SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_audio = FilmAudio.new()
	if _only == "" or _only == "smoke":
		_queue.append(&"smoke")
	if _only == "" or _only == "uncap" or _only == "pour":
		_queue.append(&"uncap")
	if _only == "" or _only == "pour":
		_queue.append(&"pour")
	_say("shots %s, sound %s" % [str(_queue), str(_audio.get(&"on"))])
	Lake.force_hive = true
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE_PATH)
	_main.set(&"autoload_save", false)
	add_child.call_deferred(_main)


func _say(line: String) -> void:
	_log.store_line(line)
	_log.flush()


func _hive() -> Hive:
	return _main.get(&"_hive")


func _room() -> HiveRoom:
	return _main.get(&"_hive_room")


func _process(delta: float) -> void:
	_frames += 1
	if Time.get_ticks_msec() - _started > QUIT_AFTER_MS:
		_say("wall clock ran out in %s" % _shot)
		get_tree().quit(1)
		return
	if _main == null or not _main.is_inside_tree():
		return
	if _frames == OPEN_AT:
		_dress()
		_next_room()
		return
	if _frames < OPEN_AT:
		return
	var room := _room()
	if room == null:
		return
	_quiet(room)
	var step := room.step()
	if _shot == &"":
		_wait_for_shot(room)
		return
	if step == null or room.step_name() != _shot:
		_say("%s: the room moved on to '%s' at kept frame %d" % [_shot, room.step_name(), _saved])
		_end_shot()
		return
	match _shot:
		&"smoke":
			_drive_smoke(step, delta)
		&"uncap":
			_drive_uncap(step, delta)
		&"pour":
			_drive_pour(step, delta)
	_capture()
	var length := SMOKE_FRAMES if _shot == &"smoke" else (UNCAP_FRAMES if _shot == &"uncap" else POUR_FRAMES)
	if _saved >= length:
		_end_shot()


## English, a clean lake behind with the pack and the fleet out, the island's hive set to the
## stage the next shot needs.
func _dress() -> void:
	TranslationServer.set_locale("en")
	Style.set_locale("en")
	_main.set(&"pollution", LAKE_FILTH)
	_main.set(&"fleet_level", 2)
	while int(_main.get(&"dog_count_level")) < 3:
		_main.set(&"dog_count_level", int(_main.get(&"dog_count_level")) + 1)
		_main.call(&"_add_dog")
	var skin: CanvasItem = _main.get(&"_skin")
	_say("lake dressed: %d dogs, fleet %d, viewport %s" % [int(_main.get(&"dog_count_level")) + 1,
			int(_main.call(&"fleet_size")), str(get_viewport().get_visible_rect().size)])
	if skin != null:
		skin.visible = false


## Opens the room on the stage the next shot in the queue wants.
func _next_room() -> void:
	if _queue.is_empty():
		_say("all shots done")
		get_tree().quit()
		return
	var hive := _hive()
	var want: StringName = _queue[0]
	if want == &"smoke":
		hive.jars = 0
		hive.harvests = 0
		hive.first_done = false
		hive.moment_seen = true
		hive.set_stage(Hive.Stage.SETTLE)
	elif want == &"uncap":
		hive.jars = 0
		hive.harvests = 1
		hive.first_done = true
		hive.ready_seen = true
		hive.set_stage(Hive.Stage.READY)
	if want != &"pour":
		_main.call(&"_set_hive_room", false)
		_main.call(&"_set_hive_room", true)
		_say("room opened for %s: plan %s, origin %s" % [want, str(_room().plan()), str(_room().origin())])


## Waits for the step the queue wants to be up, then starts its shot.
func _wait_for_shot(room: HiveRoom) -> void:
	if _queue.is_empty():
		return
	var want: StringName = _queue[0]
	var step := room.step()
	if step == null or room.step_name() != want:
		return
	_queue.remove_at(0)
	if _only == "pour" and want == &"uncap":
		# The bucket filled by the cut, unfilmed, and on to the pour.
		step.call(&"settle")
		_say("uncap settled unfilmed, honey %.2f" % room.honey)
		return
	_shot = want
	_shot_from = _frames
	_saved = 0
	_dir = ProjectSettings.globalize_path(OUT).path_join(String(want))
	DirAccess.make_dir_recursive_absolute(_dir)
	for old in DirAccess.get_files_at(_dir):
		DirAccess.remove_absolute(_dir.path_join(old))
	_smoke_t = 0.0
	_uncap_t = 0.0
	_face_done_at = -1.0
	_pour_t = 0.0
	_pour_wait = 0.0
	_poured = 0
	_holding = false
	if want == &"smoke":
		_nozzle = HiveStepSmoke.RINGS[1] + SMOKE_REST
		_aim_smoker(step, _nozzle)
	_say("%s starts on frame %d, honey %.2f" % [want, _frames, room.honey])


func _end_shot() -> void:
	_audio.finish(_dir)
	_say("%s ends: %d kept frames" % [_shot, _saved])
	var room := _room()
	var was := _shot
	_shot = &""
	if was == &"uncap" and room != null and room.step_name() == &"uncap":
		# Cut through and every drop in the bucket: the pour starts on a full bucket. (A cut
		# that finished on its own has already handed over to the pour.)
		room.step().call(&"settle")
		_say("uncap settled, honey %.2f" % room.honey)
		return
	if was == &"smoke" or was == &"pour":
		_next_room()


# --- the smoke ----------------------------------------------------------------------------

func _aim_smoker(step: HiveStep, nozzle: Vector2) -> void:
	step.call(&"aim", nozzle - HiveArt.anchor(&"smoker", &"nozzle") + HiveArt.anchor(&"smoker", &"bellows"))


## Rest, glide up to the top band, pump it quiet, glide to the middle band, pump it quiet,
## glide back to rest and smoulder. Positions eased, so the smoker never jumps.
func _drive_smoke(step: HiveStep, delta: float) -> void:
	_smoke_t += delta
	var rings := HiveStepSmoke.RINGS
	var rest := rings[1] + SMOKE_REST
	var top := rings[0] + SMOKE_ON
	var middle := rings[1] + SMOKE_ON
	var t := _smoke_t - SMOKE_START
	var goal := rest
	var pump := false
	var a := SMOKE_GLIDE
	var b := a + SMOKE_PUMP
	var c := b + SMOKE_GLIDE * 0.7
	var d := c + SMOKE_PUMP
	var e := d + SMOKE_GLIDE
	if t < 0.0:
		goal = rest
	elif t < a:
		goal = rest.lerp(top, _ease(t / a))
	elif t < b:
		goal = top
		pump = true
	elif t < c:
		goal = top.lerp(middle, _ease((t - b) / (c - b)))
	elif t < d:
		goal = middle
		pump = true
	elif t < e:
		goal = middle.lerp(rest, _ease((t - d) / (e - d)))
	# A breath of sway on the hand, so the smoker is never quite still.
	var sway := Vector2(sin(_smoke_t * 1.7), sin(_smoke_t * 2.3 + 0.6) * 0.6) * 1.2
	_nozzle = goal + sway
	_aim_smoker(step, _nozzle)
	if pump:
		step.call(&"hold", 0.1)
	if int(_smoke_t * 60.0) % 30 == 0:
		_say("  smoke kept %d: calm %.2f %.2f %.2f, stop %d" % [_saved, step.call(&"calm", 0),
				step.call(&"calm", 1), step.call(&"calm", 2), step.call(&"stop_now")])


static func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


# --- the uncap ----------------------------------------------------------------------------

## The knife drawn down at `KNIFE_PACE`, a little under the cap, so it glides and never
## strains. Once a face is through, the honey runs a while and the second face is started.
func _drive_uncap(step: HiveStep, delta: float) -> void:
	_uncap_t += delta
	var faces: int = step.call(&"faces_done")
	if faces >= 1 and _face_done_at < 0.0:
		_face_done_at = _uncap_t
		_say("  first face through: kept %d" % _saved)
	var phase: int = step.get(&"_phase")
	if phase != HiveStepUncap.Phase.CUT:
		return
	var go := _uncap_t >= KNIFE_FROM
	if faces >= 1:
		go = _uncap_t - _face_done_at >= SECOND_FACE_AFTER
	if not go:
		return
	var want: float = step.get(&"_want")
	var knife: float = step.get(&"_knife")
	step.set(&"_want", maxf(want, knife) + KNIFE_PACE * delta)
	if _saved % 30 == 0:
		_say("  uncap kept %d: knife %.1f strain %.2f bucket %.2f" % [_saved, knife,
				float(step.get(&"_strain")), float(step.call(&"bucket_level"))])


# --- the pour -----------------------------------------------------------------------------

## Each jar: a pause while it settles in, the lever held until the honey reaches the line,
## then let go; the lid drops, the jar hops away, the next slides in.
func _drive_pour(step: HiveStep, delta: float) -> void:
	_pour_t += delta
	var busy: bool = float(step.get(&"_lid_age")) >= 0.0 or float(step.get(&"_in")) < 1.0
	if _poured >= POUR_JARS:
		return
	if _holding:
		step.set(&"_by_hook", 0.2)
		if float(step.call(&"fill")) >= (POUR_LAST_TO if _poured == POUR_JARS - 1 else POUR_TO):
			_holding = false
			var done: bool = step.call(&"release")
			_poured += 1
			_pour_wait = 0.0
			_say("  jar %d let go at %.2f, done %s: kept %d" % [_poured, float(step.call(&"fill")), str(done), _saved])
		return
	if busy:
		_pour_wait = 0.0
		return
	_pour_wait += delta
	if _pour_wait >= POUR_PAUSE:
		_holding = true
		_say("  jar %d lever held: kept %d" % [_poured + 1, _saved])


# --- the room ------------------------------------------------------------------------------

## The plank, the hint card and the close cross put away, every frame.
func _quiet(room: HiveRoom) -> void:
	for key in [&"_overlay", &"_close"]:
		var node: CanvasItem = room.get(key)
		if node != null:
			node.visible = false
	var skin: CanvasItem = _main.get(&"_skin")
	if skin != null:
		skin.visible = false


func _capture() -> void:
	if _saved == 0:
		_audio.begin()
	var image := get_viewport().get_texture().get_image()
	image.save_jpg(_dir.path_join("f_%04d.jpg" % _saved), 0.95)
	_saved += 1
