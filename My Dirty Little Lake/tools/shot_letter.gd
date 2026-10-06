extends Node
## The new game's arrival and the four letter cards, photographed.
##
## Run it with the **desktop build, not `--headless`**, at a fixed step:
## `<exe> --path . --fixed-fps 60 tools/shot_letter.tscn`. Headless has no renderer, so the
## board's `_draw` — and the `dropped_lines` it counts — never runs, and `test_lake` can
## only ask the layout's arithmetic. This is what reads the drawing.
##
## **Its own save path, and a file that does not exist**: the arrival only plays for a run
## nobody has played, and a probe may never hand the player back a lake it started over.
## `Lake.force_front` wears the menu although the lake is borrowed and `Lake.force_intro`
## lets the arrival play although it is; without the second, a borrowed lake is marked as
## having seen the intro and sails nothing (see `Lake._raise_front`).
##
## Under this node, not the tree root — `tools/shot_shed.gd` and `tools/shot_ending.gd` both
## learned what happens otherwise.

const SHOT := "res://tools/last_letter_%s.png"
const LOG := "res://tools/last_letter.log"
const SAVE := "user://lake_cleanup_shot_letter.save"

## Frames to let the lake build before the glide is asked for.
const SETTLE := 40
## How long to give the whole arrival before calling it stuck, in frames at 60.
const PATIENCE := 3600

var _main: Node
var _letter: Letter
var _log: FileAccess
var _frames := 0
var _armed := false
var _seen := {}
var _card := -1
var _busy := false
## Frames to let a turned page be drawn before it is photographed.
const TURN_SETTLE := 4
var _wait := TURN_SETTLE


func _ready() -> void:
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE)
	_main.set(&"force_front", true)
	Lake.force_intro = true
	add_child(_main)
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _main == null or not _main.is_inside_tree() or _busy:
		return
	if _frames == SETTLE:
		_log = FileAccess.open(LOG, FileAccess.WRITE)
		_say("window  %s" % str(DisplayServer.window_get_size()))
		_say("intro   done=%s" % str(_main.get(&"_intro_done")))
		# Continue, as the plank does it: the menu goes and the arrival sets off with it.
		_main.call(&"_begin_glide")
		_armed = true
		return
	if not _armed:
		return
	if _frames > SETTLE + PATIENCE:
		_say("stuck at arrive=%d" % int(_main.get(&"_arrive")))
		_finish()
		return
	var arrive := int(_main.get(&"_arrive"))
	var hull := (_main.get(&"_boats") as Array)[0] as Boat
	# The hull crossing the water, still out on it.
	if arrive == 1 and not _seen.has("sailing") \
			and hull.tile_pos.distance_to(hull.dock) < 12.0:
		_seen["sailing"] = true
		_shoot("sailing", "hull %.1f tiles out, angler %s" % [
			hull.tile_pos.distance_to(hull.dock), str((_main.get(&"_angler") as Node2D).visible)
		])
		return
	# Ashore and walking up to the shed.
	if arrive == 2 and not _seen.has("walking"):
		_seen["walking"] = true
		_shoot("walking", "led to %s, dogs out %d" % [
			str((_main.get(&"_angler") as Node).get(&"walk_to")),
			(_main.get(&"_dogs") as Array).size()
		])
		return
	if not bool(_main.get(&"_letter_open")):
		return
	if _letter == null:
		_letter = _main.get(&"_letter") as Letter
		_say("board   wants %.0f tall of the %.0f a 720 window leaves"
			% [_letter.wanted_tall(), 680.0])
		_card = 0
		_letter.page = 0
		_letter.call(&"_lay_out")
		_wait = TURN_SETTLE
	if _card >= Letter.CARDS.size():
		_finish()
		return
	# A page turned is a redraw, and a redraw is not the frame the capture lands on. Given
	# a couple of frames, what is saved is the card that was asked for; taken on the turn,
	# all four pictures came out as card one.
	_wait -= 1
	if _wait > 0:
		return
	var card: Dictionary = Letter.CARDS[_card]
	_shoot("card_%s" % String(card.get("title", card["head"])).to_lower().replace(" ", "_"), "%-12s page %d  dropped %d  door %s" % [
		String(card["head"]), _letter.page, _letter.dropped_lines,
		str((_letter.get(&"_door") as Control).visible)
	])


func _say(line: String) -> void:
	if _log == null:
		return
	_log.store_line(line)
	_log.flush()


## One picture, written after a drawn frame so what is saved is what was described.
func _shoot(name: String, line: String) -> void:
	_busy = true
	await RenderingServer.frame_post_draw
	var shot := get_viewport().get_texture().get_image()
	shot.save_png(ProjectSettings.globalize_path(SHOT % name))
	_say("%-14s %s" % [name, line])
	_busy = false
	if _card >= 0:
		_card += 1
		_wait = TURN_SETTLE
		if _card < Letter.CARDS.size():
			_letter.page = _card
			_letter.call(&"_lay_out")


func _finish() -> void:
	if _log != null:
		_log.close()
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	get_tree().quit()
