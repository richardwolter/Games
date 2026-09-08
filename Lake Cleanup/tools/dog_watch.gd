## Watches the dog for a minute and a half and reports anything that would read as a bug.
##
## Three numbers matter. The worst step in one frame catches a teleport — it should stay
## under about a tenth of a tile at the speeds this animal moves. The longest still spell
## while it is in a moving state catches a dog wedged against something: a second is a pause,
## twenty is a bug. And the delivery count catches the whole trip working end to end, which
## is the thing that quietly stopped working twice while this was being written.
##
## Headless, because none of it is about the picture.
##
##   godot --headless --path . res://tools/dog_watch.tscn
extends Node

const RUN_SECONDS := 90.0

var _main: Node2D
var _dog: Node2D
var _was := Vector2.ZERO
var _clock: float = 0.0
var _worst_step: float = 0.0
var _worst_at: String = ""
var _still: float = 0.0
var _worst_still: float = 0.0
var _worst_still_state: int = -1
var _drops: int = 0
var _seen := {}

func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"autoload_save", false)
	add_child(_main)
	_dog = _main.get_node(^"Dog") as Node2D
	_dog.connect(&"fetched", func(_i: int) -> void: _drops += 1)
	_was = _dog.tile_pos

func _process(delta: float) -> void:
	_clock += delta
	var state := int(_dog.get(&"_state"))
	_seen[state] = float(_seen.get(state, 0.0)) + delta
	var spot: Vector2 = _dog.tile_pos
	var step := spot.distance_to(_was)
	if step > _worst_step:
		_worst_step = step
		_worst_at = "state %d, delta %.3f" % [state, delta]
	# Moving states: SWIM_OUT 4, CARRY_BACK 5, WANDER 1.
	var moving := state == 4 or state == 5 or state == 1
	if moving and step < 0.0005:
		_still += delta
		if _still > _worst_still:
			_worst_still = _still
			_worst_still_state = state
	else:
		_still = 0.0
	_was = spot
	if int(_clock) != int(_clock - delta) and int(_clock) % 5 == 0:
		print("  t=%3ds state=%d at=(%.1f,%.1f) target=(%.1f,%.1f) gap=%.1f trip=%.1f stuck=%.2f speed=%.2f" % [
			int(_clock), state, _dog.tile_pos.x, _dog.tile_pos.y,
			float(_dog.get(&"_target").x), float(_dog.get(&"_target").y),
			_dog.tile_pos.distance_to(_dog.get(&"_target")),
			float(_dog.get(&"_trip")), float(_dog.get(&"_stuck")), float(_dog.get(&"_speed"))
		])
	if _clock < RUN_SECONDS:
		return
	print("watched %.0fs" % _clock)
	print("  worst step in one frame: %.4f tiles (%s)" % [_worst_step, _worst_at])
	print("  longest still spell while moving: %.2fs (state %d)" % [_worst_still, _worst_still_state])
	print("  deliveries: %d" % _drops)
	var names := ["IDLE", "WANDER", "NAP", "LOUNGE", "SWIM_OUT", "CARRY_BACK", "DROPPING", "PETTED"]
	for i in names.size():
		print("  %-11s %5.1fs" % [names[i], float(_seen.get(i, 0.0))])
	get_tree().quit()
