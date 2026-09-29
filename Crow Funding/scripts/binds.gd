extends RefCounted
## The rebindable verbs and their default keys. The InputMap is built from this
## table at boot (`install`), then from the player's overrides, which Prefs keeps
## in settings.cfg under [binds] (only what differs from the default is written,
## so a default retuned later reaches a player who never touched that row).
##
## Escape is never bound and never captured: it opens the pause menu and cancels
## a capture, so it is the one way out that cannot be lost. Keys are physical
## (a hole in the keyboard); labels ask the OS what is printed on it.

const Text = preload("res://scripts/text.gd")

## action -> [label, default physical keycode]
const ACTIONS := {
	&"dispatch": [Text.BIND_DISPATCH, KEY_SPACE],
	&"toggle_fullscreen": [Text.BIND_FULLSCREEN, KEY_F1],
	&"next_city": [Text.BIND_NEXT_CITY, KEY_F2],
}
const ORDER: Array[StringName] = [&"dispatch", &"toggle_fullscreen", &"next_city"]
## Keys the capture refuses.
const RESERVED := [KEY_ESCAPE]


static func default_key(action: StringName) -> int:
	return int(ACTIONS[action][1])


static func label_of(action: StringName) -> String:
	return str(ACTIONS[action][0])


## Fills the InputMap: every action gets exactly one key, the override if any.
static func install(overrides: Dictionary) -> void:
	for action in ORDER:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = int(overrides.get(action, default_key(action))) as Key
		InputMap.action_add_event(action, ev)


static func key_of(action: StringName) -> int:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return int((ev as InputEventKey).physical_keycode)
	return default_key(action)


static func key_name(physical: int) -> String:
	var shown := physical
	if DisplayServer.get_name() != "headless":
		shown = DisplayServer.keyboard_get_label_from_physical(physical as Key)
	if shown == 0:
		shown = physical
	return OS.get_keycode_string(shown as Key)


## Binds `action` to `physical`; whatever held that key swaps to the old key, so
## nothing is ever left unbound. Returns the new overrides.
static func rebind(overrides: Dictionary, action: StringName, physical: int) -> Dictionary:
	var out := overrides.duplicate()
	var old := key_of(action)
	for other in ORDER:
		if other != action and key_of(other) == physical:
			out[other] = old
	out[action] = physical
	return _trim(out)


static func restore(overrides: Dictionary, action: StringName) -> Dictionary:
	return rebind(overrides, action, default_key(action))


static func _trim(overrides: Dictionary) -> Dictionary:
	var out := {}
	for action in overrides:
		if ACTIONS.has(action) and int(overrides[action]) != default_key(action):
			out[action] = int(overrides[action])
	return out
