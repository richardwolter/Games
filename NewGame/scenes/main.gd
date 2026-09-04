extends Node

## MVP hub: boots straight into the first course. Menu/track-select/upgrade
## screens plug in here once built — this is the single wiring point.

const FIRST_COURSE := "res://scenes/track/track_1_course_1.tscn"

func _ready() -> void:
	_load_course(FIRST_COURSE)

func _load_course(path: String) -> void:
	var course: Node = load(path).instantiate()
	add_child(course)
