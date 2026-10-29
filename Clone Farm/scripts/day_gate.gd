## Runs while the tree is paused at the end of a day: E or Enter goes on to the next day,
## and after a failed day E, Enter or R starts a new run. H toggles the "Como jogar" card at
## any time. Everything else in the farm is paused with the tree.
class_name DayGate
extends Node

var farm: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("help"):
		farm.toggle_help()
	if not get_tree().paused:
		return
	var go := Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("confirm")
	if farm.game_over:
		if go or Input.is_action_just_pressed("restart"):
			farm.restart()
	elif go:
		farm.next_day()
