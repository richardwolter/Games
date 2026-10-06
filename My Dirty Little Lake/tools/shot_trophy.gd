extends Node
## The find-caught card, photographed at three points of its life.
##
## Run it with the **desktop build, not --headless**, and at a fixed step:
## `<exe> --path . --fixed-fps 60 tools/shot_trophy.tscn`. Two reasons, one for each. The
## card wears two shaders now — `shaders/beam.gdshader` for the column of light and
## `shaders/rim.gdshader` for the gold outline — and `--headless` compiles no shader at all,
## so a broken one passes in silence; this probe is what proves they compile. And the card
## is 2.8 seconds long end to end, so which frame is which only means anything when every
## frame is the same length.
##
## **The card is left to run on its own clock.** Driving `Trophy._process` by hand to jump
## to a moment was tried and does not work: the node's own `_process` is running too, the
## two ages add, and what gets drawn is neither of them. Counting frames is the honest way.
##
## Three finds rather than one, because the card frames itself off the picture it is given
## and the grimy sprites are all different shapes: a sofa is wide and flat, a lamp tall and
## thin, and the pot small enough to be blown up to `PIECE_ZOOM`.
##
## Under this node, not the tree root: a lake whose parent is the root is the game, and the
## game opens on the main menu with its HUD hidden — which is where `tools/shot_shed.gd`
## had been quietly taking its pictures until 2026-09-19.

const SHOT := "res://tools/last_trophy_%s.png"
const LOG := "res://tools/last_trophy.log"

## Which finds to hold up, what to call the picture, and how many frames after the card
## goes up to take it. At 60 fps: the pop (`Trophy.RISE` is 0.42 s), the hold, the way out.
const SHOTS := [
	[&"decor_sofa", "pop", 15],
	[&"decor_plant_pot", "held", 80],
	[&"decor_lamp", "leaving", 160],
]

## Frames to let the lake settle before the first card goes up.
const SETTLE := 20

var _main: Node
var _trophy: Trophy
var _frames := 0
var _shot := -1
var _since := 0
## True while a picture is being taken. `_write` waits a drawn frame, and without this the
## next physics frame would start the shot after it and close the log underneath.
var _busy := false
var _log: FileAccess


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _main == null or not _main.is_inside_tree():
		return
	if _frames == SETTLE:
		_trophy = _main.get_node_or_null(^"Finds/Trophy") as Trophy
		_log = FileAccess.open(LOG, FileAccess.WRITE)
		if _trophy == null:
			_log.store_line("no Trophy under Finds — the card was not built")
			_log.flush()
			get_tree().quit()
			return
		_log.store_line("title   %s" % Trophy.TITLE)
		_log.store_line("window  %s" % str(DisplayServer.window_get_size()))
		_next()
		return
	if _frames < SETTLE or _trophy == null or _shot >= SHOTS.size() or _busy:
		return
	_since += 1
	if _since < int(SHOTS[_shot][2]):
		return
	_busy = true
	_write(String(SHOTS[_shot][1]), StringName(SHOTS[_shot][0]), _since)


## Put the next find up, or finish.
func _next() -> void:
	_shot += 1
	_since = 0
	if _shot >= SHOTS.size():
		_log.flush()
		_log.close()
		get_tree().quit()
		return
	var piece := StringName(SHOTS[_shot][0])
	_trophy.call(&"clear")
	var titles: Dictionary = (_main.get(&"_room") as ShedRoom).titles
	_trophy.show_find(piece, String(titles.get(String(piece), "")))


## The picture, and the numbers it was taken at.
##
## Everything about the card is read **before** the wait, not after: `_next` puts the next
## find up, and a line written after the wait reported that one instead — three shots that
## all said `solid 0.11`, which is the state one frame into a card rather than eighty.
func _write(name: String, piece: StringName, at: int) -> void:
	var sheets: Sheets = _trophy.sheets
	var line := "%-8s %-18s frame %3d  solid %.2f  box %s  stars %d  region %s" % [
		name, String(piece), at, float(_trophy.get(&"_solid")),
		str(_trophy.get(&"_box")), (_trophy.get(&"_stars_lit") as Array).size(),
		str(sheets.region_of(piece)) if sheets != null else "no sheets",
	]
	await RenderingServer.frame_post_draw
	var shot := get_viewport().get_texture().get_image()
	shot.save_png(ProjectSettings.globalize_path(SHOT % name))
	_log.store_line(line)
	_log.flush()
	_busy = false
	_next()
