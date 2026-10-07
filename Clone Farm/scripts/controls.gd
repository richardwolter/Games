## The prototype's key bindings, registered in code so `project.godot` stays readable and
## the headless harness gets the same actions the game does.
class_name Controls
extends RefCounted

const BINDINGS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"interact": [KEY_E, KEY_SPACE],
	"role_0": [KEY_0, KEY_KP_0],
	"role_1": [KEY_1, KEY_KP_1],
	"role_2": [KEY_2, KEY_KP_2],
	"role_3": [KEY_3, KEY_KP_3],
	"role_4": [KEY_4, KEY_KP_4],
}


static func ensure() -> void:
	for action: String in BINDINGS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: Key in BINDINGS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
