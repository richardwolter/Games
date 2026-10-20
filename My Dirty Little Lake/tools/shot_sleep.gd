extends Node
## Films the angler asleep in bed in the decorated house with a dog lying beside them, the Zs
## rising, for the before/after video (2026-10-15, Richard: "jogador dormindo na cama com um
## cachorro e o zzz"). The house is Richard's own layout from `tools/play_decor.tscn` (its save
## copied, never written, its version raised the way `shot_wash_place.gd` does). Every frame is
## saved as a JPEG into `tools/film/ba_sleep/`.
##
##   godot --path . --fixed-fps 60 --write-movie tools/film/_movie.avi res://tools/shot_sleep.tscn
##
## (Movie Maker records the room's sound: see `film_audio.gd`.) Desktop build. Under its own
## node, on its own save, quits on a wall clock too.

const FilmAudio := preload("res://tools/film_audio.gd")
const Style := preload("res://scripts/style.gd")
const FROM_SAVE := "user://play_decor.save"
const SAVE_PATH := "user://shot_sleep.save"
const OUT := "res://tools/film/ba_sleep"
const LOG := "res://tools/film/last_sleep.log"
const QUIT_AFTER_MS := 180000
## Frames: the shed opens, the angler lies down, the first frame kept, how many are kept.
const OPEN_AT := 10
const LIE_AT := 16
const KEEP_FROM := 30
const KEEP := 480
## Seconds into the rest the film starts at: just short of `ShedRoom.SLEEP_AFTER`, so the eyes
## shut and the Zs start a moment in.
const REST_FROM := 1.0

var _main: Node
var _frames := 0
var _kept := 0
var _log: FileAccess
var _started := 0
var _audio: RefCounted


func _ready() -> void:
	_started = Time.get_ticks_msec()
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var dir := ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(dir)
	for old in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(old))
	_log = FileAccess.open(LOG, FileAccess.WRITE)
	for path in [SAVE_PATH, SAVE_PATH + ".bak", SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if not FileAccess.file_exists(FROM_SAVE):
		_say("no decorated house: run tools/play_decor.tscn first")
		get_tree().quit()
		return
	DirAccess.copy_absolute(ProjectSettings.globalize_path(FROM_SAVE), ProjectSettings.globalize_path(SAVE_PATH))
	_raise_version(SAVE_PATH)
	TranslationServer.set_locale("en")
	Style.set_locale("en")
	_audio = FilmAudio.new()
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE_PATH)
	_main.set(&"autoload_save", true)
	add_child.call_deferred(_main)


func _say(line: String) -> void:
	_log.store_line(line)
	_log.flush()


func _room() -> ShedRoom:
	return _main.get_node(^"HUD/Shed/Pad/Lines/Room")


func _process(_delta: float) -> void:
	_frames += 1
	if Time.get_ticks_msec() - _started > QUIT_AFTER_MS:
		_say("wall clock ran out")
		get_tree().quit()
		return
	if _main == null or not _main.is_inside_tree():
		return
	var room := _room()
	if _frames == OPEN_AT:
		room.pack_size = func() -> int: return ShedRoom.DOGS_MOST
		_main.call(&"_set_shed", true)
		for _try in 400:
			if room.dogs().size() >= ShedRoom.DOGS_MOST:
				break
			room.call(&"_room_shown")
		return
	if _frames == LIE_AT:
		_lie_down(room)
		return
	if _frames < KEEP_FROM:
		return
	if _kept == 0:
		_audio.begin()
	var image := get_viewport().get_texture().get_image()
	image.save_jpg(ProjectSettings.globalize_path(OUT + "/%05d.jpg" % _kept), 0.94)
	_kept += 1
	if _kept >= KEEP:
		_audio.finish(ProjectSettings.globalize_path(OUT))
		_say("frames %d, resting %s" % [_kept, room.resting()])
		get_tree().quit()


## The angler into the first bed in the house, a dog onto its other seat, asleep.
func _lie_down(room: ShedRoom) -> void:
	var decor: Array = room.decor
	# The double bed first: the small one is tucked into a corner.
	var order: Array = range(decor.size())
	order.sort_custom(func(x: int, y: int) -> bool:
		return String(decor[x]["piece"]) == "decor_pk_fancy_bed" and String(decor[y]["piece"]) != "decor_pk_fancy_bed")
	for i: int in order:
		var row: Dictionary = decor[i]
		var piece := StringName(row["piece"])
		var spec: Array = room.rest_of(piece, room.call(&"_row_view", row))
		if spec.is_empty() or StringName(spec[0]) != &"lie":
			continue
		var cell := Vector2i(int(row["cell"][0]), int(row["cell"][1]))
		var span: Vector2i = room.span_of(piece, room.call(&"_row_view", row))
		room.set(&"_you_at", Vector2(cell.x + span.x * 0.5, cell.y + span.y + 6) / float(ShedRoom.CELL))
		room.set(&"_you_pet", -1.0)
		room.rest_on(i)
		room.set(&"_rest_age", REST_FROM)
		var key := "%s@%d,%d" % [piece, cell.x, cell.y]
		var dogs := room.dogs()
		for dog in dogs:
			if dog.seat == key:
				dog.seat = ""
		for seat: Dictionary in room.call(&"_seats"):
			if String(seat["key"]) != key or dogs.is_empty():
				continue
			var dog: ShedRoom.ShedDog = dogs[0]
			dog.seat = key
			dog.over = seat["over"]
			dog.at = seat["feet"]
			dog.target = seat["feet"]
			dog.state = &"sleep"
			dog.mood = 60.0
			break
		_say("lying in %s at %s, resting %s" % [piece, str(cell), room.resting()])
		# Where the bed is drawn in the window, for the edit's crop.
		var origin: Vector2 = room.get_global_rect().position + (room.call(&"_floor_rect") as Rect2).position
		var zoom: float = room.call(&"_zoom")
		var scale := Vector2(get_viewport().get_texture().get_size()) / get_viewport().get_visible_rect().size
		var centre := (origin + (Vector2(cell) + Vector2(span) * 0.5) * zoom) * scale
		_say("bed centre in window px %s, span px %s" % [str(centre.round()), str((Vector2(span) * zoom * scale).round())])
		return
	_say("no bed in the house")


## The copy's saved version raised to the game's own (`shot_wash_place.gd`'s note).
func _raise_version(path: String) -> void:
	var bytes := FileAccess.get_file_as_bytes(path)
	var key := "version".to_utf8_buffer()
	for i in bytes.size() - 20:
		if bytes.slice(i, i + key.size()) != key:
			continue
		var at := i + 8
		if bytes.decode_u32(at) == 2:
			bytes.encode_u32(at + 4, Lake.SAVE_VERSION)
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_buffer(bytes)
			f.close()
		return
