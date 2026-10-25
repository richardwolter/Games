extends Node
## Films the 1000-wishlists video's wash (2026-10-25, `/grill-me` with Richard): an oak plaque
## with a brass plate reading "1000 WISHLISTS" drops onto the wash stand grimy and is hosed
## clean in real time, close on the stand, in portrait. Every frame is a JPEG in
## `tools/film/plaque/`, with the game's own sound as `sfx.wav` and `ambience.wav` under Movie
## Maker (`film_audio.gd`). `last_plaque.log` says on which kept frame the plaque lands, the
## jet starts, the chime rings and the shine ends, for the cut.
##
##   godot --path . --write-movie tools/film/_movie.avi res://tools/shot_plaque.tscn --log-file tools/film/plaque.log
##
## (with an `override.cfg` holding `editor/movie_writer/mjpeg_quality` low; the .avi is thrown
## away.) Desktop build. Under its own node, on its own save, quits on a wall clock too.
##
## The plaque is not in the game: it is drawn by `build_plaque.py` in the marketing folder
## (`2 Work/wishlist_1000/plaque.png`), and this probe lays it into the lake's own atlas as a
## find called `PLAQUE` for the session, below every sheet, so no other piece's region moves.
## The tray, the cross, the hose row, the HUD and the stand's clean figure are put away.
##
## `PLAQUE_STILL=1` makes the Steam event's picture instead (run with `--fixed-fps 60`, no
## Movie Maker): the same wash in a landscape window (1920x1080, canvas 1280x720), the stand
## moved right of the middle (`STILL_X`) to leave room for the words, and only the frames
## from the chime on saved, as PNGs, every `STILL_EVERY`, into `tools/film/plaque_still/`.

const Style := preload("res://scripts/style.gd")
const FilmAudio := preload("res://tools/film_audio.gd")
const PLAQUE := &"decor_plaque_1000"
const ART := "../Marketing/My Dirty Little Lake/2 Work/wishlist_1000/plaque.png"
const SAVE_PATH := "user://shot_plaque.save"
var _still := OS.get_environment("PLAQUE_STILL") != ""
var OUT := "res://tools/film/plaque_still" if _still else "res://tools/film/plaque"
var LOG := OUT + "/last_plaque.log"
const QUIT_AFTER_MS := 300000
## The portrait window and its canvas: one canvas px is 1.5 window px, as in every vertical.
## The still's is landscape at the same stretch.
var WINDOW := Vector2i(1920, 1080) if _still else Vector2i(1080, 1920)
var CANVAS := Vector2i(1280, 720) if _still else Vector2i(720, 1280)
## The stand's zoom, forced (a find is otherwise drawn at the zoom the largest find fits at),
## and where the pallet's foot stands down the canvas.
var ZOOM := int(OS.get_environment("PLAQUE_ZOOM")) if OS.get_environment("PLAQUE_ZOOM") != "" else (5 if _still else 8)
var GROUND := float(OS.get_environment("PLAQUE_GROUND")) if OS.get_environment("PLAQUE_GROUND") != "" else (0.8 if _still else 0.66)
## The still: where across the canvas the stand stands, how often a frame is kept from the
## chime on, and for how long after the shine.
var STILL_X := float(OS.get_environment("PLAQUE_X")) if OS.get_environment("PLAQUE_X") != "" else 0.68
const STILL_EVERY := 4
const STILL_AFTER := 60
## How dirty the lake behind looks (the meter's share left): murky, with rubbish afloat.
const LAKE_FILTH := 0.55
## The hose's level (1 to 3): wider and harder each, which sets how long the wash takes.
var HOSE := int(OS.get_environment("PLAQUE_HOSE")) if OS.get_environment("PLAQUE_HOSE") != "" else 3
## Frames (60 a second): the room opens, the first kept frame, the empty pallet, the fall,
## the pause before the jet, and the hold once the shine has ended.
const OPEN_AT := 10
const KEEP_FROM := 40
const EMPTY := 14
const FALL := 16
const BEFORE_JET := 30
const HOLD_AFTER := 300
## How far above its rest the plaque falls from, in canvas px, and its little bounce.
const FALL_FROM := 700.0
const BOUNCE := 10.0
const BOUNCE_FRAMES := 10
## The sweep: up and down, never across (2026-10-25, Richard: "sideways does not make
## sense"). The fan is wide and low, so it is carried down one column and up the next,
## columns `COL_GAP` of the fan's width apart, left to right so the 1 comes up first, at the
## pace that leaves no grime behind (a cell under the fan long enough to lose `NEED` of a
## coat); then whatever is left chased at `CHASE_PACE` canvas px a second.
const COL_GAP := 0.7
const NEED := 0.9
const CHASE_PACE := 520.0
## The jet made `BOOST` times as strong as the hose's top level (2026-10-25): the plaque is
## the size of the largest finds, a real-time wash of it is half a minute, and a sped-up
## film reads badly (Richard). The jet, the cone and the nozzle's motion are untouched; the
## grime only comes off faster under it. 1 is the game's own hose.
var BOOST := float(OS.get_environment("PLAQUE_BOOST")) if OS.get_environment("PLAQUE_BOOST") != "" else 2.9
const RETARGET_EVERY := 4
## Where the nozzle waits while the plaque falls, as a share of the canvas.
const PARK := Vector2(0.8, 0.2)

var _main: Node
var _frames := 0
var _log: FileAccess
var _started := 0
var _saved := 0
var _audio: RefCounted
var _wash: WashRoom
var _stand: WashStand
var _rest := Vector2.ZERO
var _land_at := -1
var _jet_at := -1
var _chime_at := -1
var _clean_at := -1
var _aim := Vector2.INF
var _goal := Vector2.ZERO
var _path: Array[Vector2] = []
var _pace := 300.0
## Where the jet will start, worked out once the plaque has landed: the nozzle is turned onto
## it before the water comes on, so the jet never opens on the sky.
var _start := Vector2.INF
## The backdrop's hounds, checked every frame for walking one way while facing the other.
var _hound_was := {}
var _hound_moving := 0
var _hound_backwards := 0
## Frames the jet was off the plaque, where the backdrop answers it (a coo, a bark, a bell).
var _off_piece := 0


func _ready() -> void:
	_started = Time.get_ticks_msec()
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.borderless = true
	win.size = WINDOW
	win.position = Vector2i.ZERO
	win.content_scale_size = CANVAS
	var dir := ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(dir)
	for old in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(old))
	_log = FileAccess.open(LOG, FileAccess.WRITE)
	for path in [SAVE_PATH, SAVE_PATH + ".bak", SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_audio = FilmAudio.new()
	_say("zoom %d ground %.2f hose %d boost %.1f, sound %s" % [ZOOM, GROUND, HOSE, BOOST, str(_audio.get(&"on"))])
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE_PATH)
	add_child.call_deferred(_main)


func _say(line: String) -> void:
	_log.store_line(line)
	_log.flush()


func _process(_delta: float) -> void:
	_frames += 1
	if Time.get_ticks_msec() - _started > QUIT_AFTER_MS:
		_say("wall clock ran out")
		get_tree().quit()
		return
	if _main == null or not _main.is_inside_tree():
		return
	if _frames == OPEN_AT:
		_open()
		return
	if _frames < OPEN_AT or _stand == null:
		return
	_quiet()
	if _frames < KEEP_FROM:
		_hide_piece()
		return
	var k := _frames - KEEP_FROM
	if k < EMPTY:
		_hide_piece()
	elif k < EMPTY + FALL + BOUNCE_FRAMES:
		_fall(k - EMPTY)
	if _start == Vector2.INF and k >= EMPTY + FALL + BOUNCE_FRAMES:
		_path = _columns()
		_start = _path[0]
	if k < EMPTY + FALL + BEFORE_JET:
		_stand.spray(_start if _start != Vector2.INF else _park(), false)
	elif _chime_at < 0:
		if _jet_at < 0:
			_jet_at = _saved
			_say("jet on, kept frame %d" % _saved)
		_spray()
	else:
		_stand.spray(_park(), false)
	if _chime_at < 0 and _stand.state == WashStand.State.SHINING:
		_chime_at = _saved
		# Held on the stand: the room clears a clean find away and puts the next one up.
		_wash.set(&"_on_stand", &"")
		_say("chime, kept frame %d" % _saved)
	if _clean_at < 0 and _chime_at >= 0 and _stand.state == WashStand.State.CLEAN:
		_clean_at = _saved
		_say("shine over, kept frame %d" % _saved)
	_check_hounds()
	_capture()
	if _still and _clean_at >= 0 and _saved - _clean_at >= STILL_AFTER:
		_say("frames %d" % _saved)
		get_tree().quit()
		return
	if _clean_at >= 0 and _saved - _clean_at >= HOLD_AFTER:
		_audio.finish(ProjectSettings.globalize_path(OUT))
		_say("frames %d; hound frames moving %d, backwards %d; jet off the plaque %d frames" % [
				_saved, _hound_moving, _hound_backwards, _off_piece])
		get_tree().quit()


## English, the lake murky behind with the whole pack and three hulls, the plaque laid into
## the atlas and waiting at the pump, and the room up with it on the stand.
func _open() -> void:
	TranslationServer.set_locale("en")
	Style.set_locale("en")
	_main.set(&"pollution", LAKE_FILTH)
	_main.set(&"fleet_level", 2)
	while int(_main.get(&"dog_count_level")) < 3:
		_main.set(&"dog_count_level", int(_main.get(&"dog_count_level")) + 1)
		_main.call(&"_add_dog")
	var sheets: Sheets = _main.get(&"_sheets")
	if not _lay_in(sheets):
		get_tree().quit()
		return
	var waiting: Array = _main.get(&"unwashed")
	waiting.clear()
	waiting.append(String(PLAQUE))
	_main.set(&"hose_level", HOSE)
	WashRoom.stacked = true
	WashStand.stacked = true
	WashStand.quiet = true
	_main.call(&"_set_wash", true)
	_wash = _main.get(&"_wash")
	_wash.auto_next = false
	for key in [&"_tray", &"_close", &"_hose"]:
		var node: CanvasItem = _wash.get(key)
		if node != null:
			node.visible = false
	_stand = _wash.stand()
	_say("picked %s" % str(_wash.pick(PLAQUE)))
	_thicken()
	_force_zoom()


## The plaque's picture under every sheet in the atlas, and a catalogue entry for it: one
## restored view, its title, a find of one.
func _lay_in(sheets: Sheets) -> bool:
	var path := ProjectSettings.globalize_path("res://").path_join(ART)
	var art := Image.load_from_file(path)
	if art == null:
		_say("no plaque art at %s: run build_plaque.py --pick" % path)
		return false
	art.convert(Image.FORMAT_RGBA8)
	var atlas := sheets.atlas.get_image()
	atlas.convert(Image.FORMAT_RGBA8)
	var at := Vector2i(0, atlas.get_height())
	var grown := Image.create_empty(maxi(atlas.get_width(), art.get_width()),
			atlas.get_height() + art.get_height(), false, Image.FORMAT_RGBA8)
	grown.fill(Color(0, 0, 0, 0))
	grown.blit_rect(atlas, Rect2i(Vector2i.ZERO, atlas.get_size()), Vector2i.ZERO)
	grown.blit_rect(art, Rect2i(Vector2i.ZERO, art.get_size()), at)
	sheets.atlas.set_image(grown)
	var name := String(PLAQUE)
	var region := Rect2(Vector2(at), Vector2(art.get_size()))
	sheets.regions[name] = region
	sheets.views[name] = [region] as Array[Rect2]
	sheets.alt_regions[name] = region
	sheets.roles[name] = PackedStringArray(["front"])
	sheets.copies[name] = 1
	sheets.titles[name] = "1000 Wishlists"
	sheets.scales[name] = 1.0
	sheets.wash_scales[name] = 1.0
	sheets.facings[name] = PackedInt32Array([0])
	sheets.states[name] = PackedInt32Array([0])
	sheets.lights[name] = &""
	sheets.tiers[name] = 0
	sheets.names.append(name)
	_say("plaque %s laid at %s" % [str(art.get_size()), str(at)])
	return true


## The brass under a coat nobody can read through: the stand's roll leaves most of a find
## under film, which shows what is under it, and the plate is the reveal. Every cell of the
## plate and the star is lifted into scum (over `SCUM_AT`), keeping the roll's own unevenness;
## the wood keeps its film, so the plaque's shape reads before its words do.
const PLATE := Rect2i(6, 15, 52, 32)
const STAR := Rect2i(26, 1, 11, 11)
const SCUM_FLOOR := 0.72


func _thicken() -> void:
	var grime: PackedFloat32Array = _stand.get(&"_grime")
	var cols: int = _stand.get(&"_cols")
	var total := 0.0
	for i in grime.size():
		var cell := Vector2i(i % cols, i / cols)
		if grime[i] > 0.0 and (PLATE.has_point(cell) or STAR.has_point(cell)):
			grime[i] = clampf(SCUM_FLOOR + (grime[i] - WashStand.COAT_LEAST) / (1.0 - WashStand.COAT_LEAST) * (1.0 - SCUM_FLOOR), SCUM_FLOOR + 0.01, 1.0)
		total += grime[i]
	var kept: Dictionary = _stand.get(&"_kept")
	kept[PLAQUE] = {"grime": grime, "total": total, "left": total}
	_stand.call(&"_take_kept", PLAQUE)


## The stand at `ZOOM`, its pallet built as wide as the plaque wants, the foot at `GROUND`.
func _force_zoom() -> void:
	_stand.call(&"_zoom_for_all")
	var region := _stand.get(&"_region") as Rect2
	_stand.set(&"_widest", maxf(float(_stand.get(&"_widest")), region.size.x))
	_stand.set(&"_shared_zoom", ZOOM)
	_stand.set(&"_shared_for", _stand.size)
	_stand.set(&"_pallet_tex", null)
	_stand.call(&"_fit")
	# `_fit` stands the pallet's foot at the stacked room's ground; moved to `GROUND` here.
	# Nothing fits the stand again while the room's size and middle hold still.
	var pallet: Vector2 = _stand.get(&"_pallet_at")
	var drop: float = round(_stand.size.y * GROUND) - (pallet.y + float(_stand.get(&"_pallet_size").y * ZOOM))
	_stand.set(&"_pallet_at", pallet + Vector2(0.0, drop))
	_rest = (_stand.get(&"_origin") as Vector2) + Vector2(0.0, drop)
	_stand.set(&"_origin", _rest)
	if _still:
		# The whole stand, pallet, nozzle and hose, moved across; the room keeps it centred.
		_stand.position.x = round((STILL_X - 0.5) * _stand.size.x)
	_say("stand size %s, plaque at %s, %s canvas px; pallet at %s" % [str(_stand.size),
			str(_rest), str(region.size * ZOOM), str(_stand.get(&"_pallet_at"))])


## The plaque off the top of the screen, so the pallet stands empty.
func _hide_piece() -> void:
	_stand.set(&"_origin", _rest + Vector2(0.0, -FALL_FROM * 3.0))
	_stand.set_deferred(&"shade", Vector3.ZERO)


## Falling under gravity onto the pallet, a thud, one small bounce.
func _fall(f: int) -> void:
	var y := 0.0
	if f < FALL:
		var t := float(f + 1) / float(FALL)
		y = -FALL_FROM * (1.0 - t * t)
	else:
		var b := float(f - FALL) / float(BOUNCE_FRAMES)
		y = -BOUNCE * sin(b * PI)
	if f == FALL - 1:
		_land_at = _saved
		_say("lands, kept frame %d" % _saved)
		var sound := Sfx.main()
		if sound != null:
			sound.play(&"drop_big")
	_stand.set(&"_origin", _rest + Vector2(0.0, y))
	# In the air it throws no shadow: the stand lays its shade at the piece's foot, which was
	# dragging a dark slab through the sky. Deferred, past the room's own push of the day's.
	if f < FALL:
		_stand.set_deferred(&"shade", Vector3.ZERO)
	if f == FALL + BOUNCE_FRAMES - 1:
		_stand.set(&"_origin", _rest)
	_stand.queue_redraw()


func _park() -> Vector2:
	return Vector2(_stand.size) * PARK


## Rows across the plaque, top to bottom, at the pace that cleans a row in one pass; then
## the nearest grime left until the stand says done.
func _spray() -> void:
	if _aim == Vector2.INF:
		var length := 0.0
		var from := _start
		for p in _path:
			length += from.distance_to(p)
			from = p
		var cell: float = _stand.get(&"_cell")
		var fan_tall := _stand.fan_half().y * 2.0
		var strength := _stand.jet_power() * WashStand.FAN_POWER * BOOST
		_pace = fan_tall * strength / NEED * cell
		_aim = _start
		_say("path %d points, %.0f px, pace %.0f px/s, %.1f s" % [_path.size(), length, _pace, length / _pace])
	var pace := _pace
	if _path.is_empty():
		pace = CHASE_PACE
		if _frames % RETARGET_EVERY == 0:
			_goal = _dirtiest_near(_aim)
	else:
		_goal = _path[0]
		if _aim.distance_to(_goal) < 1.0:
			_path.remove_at(0)
	_aim = _aim.move_toward(_goal, pace / 60.0)
	_stand.spray(_aim, true)
	if _stand.jet_past_piece() != Vector2.INF:
		_off_piece += 1
		if _off_piece % 5 == 1:
			_say("  off the plaque: kept %d aim %s" % [_saved, str(_aim.round())])
	if BOOST > 1.0 and float(_stand.get(&"_reach")) >= 1.0:
		var half := _stand.fan_half() * float(WashStand.FINE)
		var take := _stand.jet_power() * WashStand.FAN_POWER / 60.0 * (BOOST - 1.0)
		_stand.call(&"_wash_at", _stand.call(&"_aim_cell"), half, take)
	if _frames % 30 == 0:
		_say("  kept %d clean %.3f points left %d" % [_saved, _stand.share_clean(), _path.size()])


func _columns() -> Array[Vector2]:
	var solid: PackedByteArray = _stand.get(&"_solid")
	var cols: int = _stand.get(&"_cols")
	var rows: int = _stand.get(&"_rows")
	var cell: float = _stand.get(&"_cell")
	var origin: Vector2 = _stand.get(&"_origin")
	var half := _stand.fan_half() * float(WashStand.FINE)
	var gap := maxf(half.x * 2.0 * COL_GAP, 1.0)
	var out: Array[Vector2] = []
	var down := true
	var x := gap * 0.5
	while x - gap * 0.5 < float(cols):
		var lo := rows
		var hi := -1
		for cx in range(maxi(int(x - gap * 0.5), 0), mini(int(x + gap * 0.5) + 1, cols)):
			for cy in rows:
				if solid[cy * cols + cx] != 0:
					lo = mini(lo, cy)
					hi = maxi(hi, cy)
		if hi >= lo:
			# Past the ends by a little of the fan's height: far enough that the top and the foot
			# are washed, not so far the jet leaves the plaque and the backdrop's birds and dogs
			# take fright (they coo and bark over the hose).
			var over := half.y * 0.35
			var a := origin + Vector2(x, float(lo) - over) * cell
			var b := origin + Vector2(x, float(hi) + 1.0 + over) * cell
			if down:
				out.append_array([a, b])
			else:
				out.append_array([b, a])
			down = not down
		x += gap
	return out


func _dirtiest_near(from: Vector2) -> Vector2:
	var grime: PackedFloat32Array = _stand.get(&"_grime")
	var cols: int = _stand.get(&"_cols")
	var rows: int = _stand.get(&"_rows")
	var cell: float = _stand.get(&"_cell")
	var origin: Vector2 = _stand.get(&"_origin")
	var best := from
	var best_d := INF
	for cy in rows:
		for cx in cols:
			if grime[cy * cols + cx] <= 0.0:
				continue
			var at := origin + (Vector2(cx, cy) + Vector2(0.5, 0.5)) * cell
			var d := at.distance_squared_to(from)
			if d < best_d:
				best_d = d
				best = at
	return best


var _bark_was := 0.0


func _check_hounds() -> void:
	var bark: float = _wash.backdrop().get(&"_bark_in")
	if bark > _bark_was + 0.01:
		_say("  a hound barked: kept %d" % _saved)
	_bark_was = bark
	for dog: Object in _wash.backdrop().get(&"_dogs") as Array:
		var x: float = (dog.get(&"at") as Vector2).x
		if _hound_was.has(dog):
			var dx: float = x - float(_hound_was[dog])
			if absf(dx) > 0.2:
				_hound_moving += 1
				if (dx < 0.0) != bool(dog.get(&"left")):
					_hound_backwards += 1
					if _hound_backwards % 10 == 1:
						_say("  backwards: kept %d dx %.2f at %s to %s via %s left %s pose %s bolting %s" % [_saved, dx,
								str(dog.get(&"at")), str(dog.get(&"to")), str(dog.get(&"via")),
								str(dog.get(&"left")), str(dog.get(&"pose")), str(dog.get(&"bolting"))])
		_hound_was[dog] = x


## The HUD and the game's talk put away, every frame after the lake has had its say.
func _quiet() -> void:
	var skin: CanvasItem = _main.get(&"_skin")
	if skin != null:
		skin.visible = false
	for key in [&"_open_upgrades", &"_open_settings", &"_free_camera", &"_heavy_note", &"_coins",
			&"_hint_card", &"_moment_card"]:
		var node: CanvasItem = _main.get(key)
		if node != null:
			node.visible = false
	var pop: CanvasLayer = _main.get_node_or_null(^"Pigeon")
	if pop != null:
		pop.visible = false


func _capture() -> void:
	if _still:
		if _chime_at >= 0 and (_saved - _chime_at) % STILL_EVERY == 0:
			var shot := get_viewport().get_texture().get_image()
			shot.save_png(ProjectSettings.globalize_path(OUT).path_join("s_%04d.png" % (_saved - _chime_at)))
		_saved += 1
		return
	if _saved == 0:
		_audio.begin()
	var image := get_viewport().get_texture().get_image()
	image.save_jpg(ProjectSettings.globalize_path(OUT).path_join("f_%04d.jpg" % _saved), 0.95)
	_saved += 1
