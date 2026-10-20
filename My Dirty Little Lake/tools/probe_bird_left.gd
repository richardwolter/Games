extends Node
## A pigeon frame left lying on clean water (2026-10-19, Richard's screenshot). Two questions,
## asked of a flock with no lake behind it (it needs none for either):
##
## 1. Where does a bird sent away end its flight? `_send_away` sends it a fixed distance in a
##    rolled direction, and the bird is removed the frame it gets there. Sent from all over the
##    lake, how many end where they are still drawn (`_over_water` above nought)?
## 2. When the last bird goes, is the flock drawn again? A canvas item keeps its last drawing
##    until it is redrawn, so a flock that stops redrawing the frame it empties leaves its last
##    bird and that bird's shadow on the screen for good.
##
##   godot --headless --path . --fixed-fps 60 res://tools/probe_bird_left.tscn
##
## Writes no save; hangs its flock off its own node. `tools/last_probe_bird_left.log`.

const LOG := "res://tools/last_probe_bird_left.log"
const SENDS := 400

var _flock: Flock
var _log: FileAccess
var _frames := 0
var _draws := 0
var _shade_draws := 0
var _gone_at := -1
var _draws_at_gone := 0
var _shade_draws_at_gone := 0
var _last_fade := -1.0


func _ready() -> void:
	_log = FileAccess.open(LOG, FileAccess.WRITE)
	_flock = Flock.new()
	_flock.spawning = false
	add_child(_flock)
	# Counted only when there is no bird left to draw: the empty frame that wipes the last one.
	_flock.draw.connect(func() -> void: _draws += 1 if _flock.birds.is_empty() else 0)
	var shades := _flock.get_node_or_null(^"BirdShade") as CanvasItem
	if shades != null:
		shades.draw.connect(func() -> void: _shade_draws += 1 if _flock.birds.is_empty() else 0)
	_ask_where_they_end()
	# One bird, leaving from the middle of the open water, for the second question.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var at := Iso.tile_to_world(Iso.CENTRE.x + Iso.RADIUS.x * 0.55, Iso.CENTRE.y)
	var bird := _bird_at(at)
	_flock.birds.append(bird)
	_flock._send_away(bird)
	_say("one bird leaving from %s to %s, drawn at its end: %.2f" % [
		str(at.round()), str((bird["to"] as Vector2).round()), _flock._over_water(bird["to"])])


func _bird_at(at: Vector2) -> Dictionary:
	return {
		"kind": 0, "state": Flock.State.PERCHED, "tile": -1, "at": at, "from": at, "to": at,
		"travel": 1.0, "span": 1.0, "facing": 1.0, "phase": 0.0, "pose": Flock.POSE_STAND,
		"pose_for": 1.0, "rest": 5.0,
	}


func _ask_where_they_end() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261019
	var shown := 0
	var worst := 0.0
	var asked := 0
	while asked < SENDS:
		var t := Vector2(rng.randf_range(0.0, Iso.COLS), rng.randf_range(0.0, Iso.ROWS))
		if not Iso.in_lake(int(t.x), int(t.y)) or Iso.island_fraction(t.x, t.y) < 1.0:
			continue
		asked += 1
		var bird := _bird_at(Iso.tile_to_world(t.x, t.y))
		_flock._send_away(bird)
		var fade: float = _flock._over_water(bird["to"])
		if fade > 0.0:
			shown += 1
			worst = maxf(worst, fade)
	_say("sent away from %d spots on the lake: %d end their flight still drawn (worst %.2f)" % [
		asked, shown, worst])


func _physics_process(_delta: float) -> void:
	_frames += 1
	# No splats: a splat still washing off keeps the flock redrawing, which hides the case
	# the screenshot showed, a last bird going with nothing else on the water.
	_flock.droppings.clear()
	if _gone_at < 0:
		if _flock.birds.is_empty():
			_gone_at = _frames
			_draws_at_gone = _draws
			_shade_draws_at_gone = _shade_draws
		else:
			var bird: Dictionary = _flock.birds[0]
			_last_fade = _flock._over_water(_flock.shadow_ground(bird))
	elif _frames > _gone_at + 30:
		_say("last bird gone on frame %d, drawn at %.2f the frame before" % [_gone_at, _last_fade])
		_say("flock drawn with no bird left: %d times, its shadow layer %d times" % [
			_draws, _shade_draws])
		_log.close()
		get_tree().quit()
	if _frames > 3000:
		_say("timed out")
		_log.close()
		get_tree().quit(2)


func _say(line: String) -> void:
	_log.store_line(line)
	_log.flush()
