## What every verb is bound to, on the keyboard and on the pad.
##
## Issue #26, decided with `/grill-me` (2026-09-16). The bind board (`controls_skin.gd`) is
## what the player sees; this is the table under it, and the one place that knows what a
## verb is called, what it is bound to by default, and how a binding is written down.
##
## **The InputMap is built from here, not from `project.godot`.** The engine's own input map
## still carries the actions — it has to, or the editor's inspector cannot see them — but
## `install()` rebuilds every bindable one from `ACTIONS` and then lays the player's
## overrides over the top. Defaults in a serialised `Object(InputEventKey, ...)` string in an
## ini file are defaults nobody can read or change; here they are a line of GDScript.
##
## **The keys are physical**, as they always were: `physical_keycode` is a hole in the
## keyboard, not a letter, so the walk keys sit under the same fingers on AZERTY and QWERTZ
## as on QWERTY. What was wrong was never the binding but the **label** — the game said
## "W/A/S/D" in so many words. `label_of` asks the OS what is printed on that hole
## (`DisplayServer.keyboard_get_label_from_physical`), so a French player is told ZQSD and a
## German one Y where we would say Z. No keyboard-layout row, by decision: there is nothing
## for the player to get wrong, and it works for every layout rather than the two we thought
## of.
##
## **Conflicts are checked inside a context, not across the whole table** (`CONTEXT_*`). The
## lake and the shed are two places with two sets of verbs, and one button meaning one thing
## in each is the design, not a mistake: E works the thing in front of you on the water and
## works a switch in the room, X opens the shed out there and turns the piece in your hands
## in here. Two actions may therefore share an event as long as they are never both live.
## Within one context a new binding **swaps** with whatever held it (Richard's call), so
## nothing is ever left unbound.
##
## The sticks are not in the table, by decision: walking and aiming are what the sticks are,
## and a stick bound to "open the shed" is a pad nobody can play with.
class_name Binds
extends RefCounted

## Where a verb is live. A binding clashes with another only if they share a context.
const CONTEXT_LAKE := &"lake"
const CONTEXT_SHED := &"shed"

## The section of `user://settings.cfg` the overrides are written to.
const SECTION := "binds"

## Every bindable verb, in the order the board lists them.
##
## `key` is the keyboard-or-mouse binding and `pad` the gamepad one — one editable event
## each, which is what the board has a column for. `extra` is events that are always on the
## action and never shown: the arrow keys beside the walk keys, and the sticks. `group` is
## only the heading the board draws above the row. `label` and `group` are keys of
## `locale/translations.csv`, read through `Text.of` where they are drawn.
const ACTIONS := [
	{
		"action": &"walk_up", "label": "VERB_WALK_UP", "group": "BIND_GROUP_MOVE",
		"contexts": [CONTEXT_LAKE, CONTEXT_SHED],
		"key": "key:87", "pad": "", "extra": ["key:4194320", "axis:1:-1"],
	},
	{
		"action": &"walk_down", "label": "VERB_WALK_DOWN", "group": "BIND_GROUP_MOVE",
		"contexts": [CONTEXT_LAKE, CONTEXT_SHED],
		"key": "key:83", "pad": "", "extra": ["key:4194322", "axis:1:1"],
	},
	{
		"action": &"walk_left", "label": "VERB_WALK_LEFT", "group": "BIND_GROUP_MOVE",
		"contexts": [CONTEXT_LAKE, CONTEXT_SHED],
		"key": "key:65", "pad": "", "extra": ["key:4194319", "axis:0:-1"],
	},
	{
		"action": &"walk_right", "label": "VERB_WALK_RIGHT", "group": "BIND_GROUP_MOVE",
		"contexts": [CONTEXT_LAKE, CONTEXT_SHED],
		"key": "key:68", "pad": "", "extra": ["key:4194321", "axis:0:1"],
	},
	{
		"action": &"cast", "label": "VERB_CAST", "group": "BIND_GROUP_NET",
		"contexts": [CONTEXT_LAKE], "key": "mouse:1", "pad": "axis:5:1", "extra": [],
	},
	{
		"action": &"interact", "label": "VERB_INTERACT", "group": "BIND_GROUP_NET",
		# One verb out on the lake and in the house (2026-10-10, Richard): the house's own
		# switch verb was folded into it. On the pad in the house, A uses and Y picks up.
		"contexts": [CONTEXT_LAKE, CONTEXT_SHED], "key": "key:69", "pad": "pad:0", "extra": [],
	},
	{
		"action": &"open_shed", "label": "VERB_OPEN_SHED", "group": "BIND_GROUP_OPEN",
		"contexts": [CONTEXT_LAKE], "key": "key:67", "pad": "pad:2", "extra": [],
	},
	{
		"action": &"open_upgrades", "label": "VERB_OPEN_UPGRADES", "group": "BIND_GROUP_OPEN",
		"contexts": [CONTEXT_LAKE], "key": "key:85", "pad": "pad:3", "extra": [],
	},
	{
		"action": &"open_settings", "label": "VERB_OPEN_SETTINGS", "group": "BIND_GROUP_OPEN",
		"contexts": [CONTEXT_LAKE], "key": "key:4194305", "pad": "pad:6", "extra": [],
	},
	{
		"action": &"zoom_in", "label": "VERB_ZOOM_IN", "group": "BIND_GROUP_VIEW",
		"contexts": [CONTEXT_LAKE], "key": "mouse:4", "pad": "pad:10", "extra": [],
	},
	{
		"action": &"zoom_out", "label": "VERB_ZOOM_OUT", "group": "BIND_GROUP_VIEW",
		"contexts": [CONTEXT_LAKE], "key": "mouse:5", "pad": "pad:9", "extra": [],
	},
	{
		"action": &"recentre", "label": "VERB_RECENTRE", "group": "BIND_GROUP_VIEW",
		"contexts": [CONTEXT_LAKE], "key": "mouse:3", "pad": "pad:8", "extra": [],
	},
	# The camera's two verbs (2026-10-06, issue #33, Richard: "no button for camera pan with
	# drag and unlock"). The pan is held: the mouse's button is dragged with, a key held moves
	# the view with the mouse, and the pad's trigger turns the right stick from the reticle
	# to the view. It shares the middle button with `recentre` by design (`SHARED`): a tap of
	# it recentres, a drag pans. The lock is the camera button beside the gear.
	{
		"action": &"camera_pan", "label": "VERB_CAMERA_PAN", "group": "BIND_GROUP_VIEW",
		"contexts": [CONTEXT_LAKE], "key": "mouse:3", "pad": "axis:4:1", "extra": [],
	},
	{
		"action": &"camera_lock", "label": "VERB_CAMERA_LOCK", "group": "BIND_GROUP_VIEW",
		"contexts": [CONTEXT_LAKE], "key": "key:76", "pad": "pad:4", "extra": [],
	},
	{
		"action": &"shed_rotate", "label": "VERB_SHED_ROTATE", "group": "BIND_GROUP_SHED",
		"contexts": [CONTEXT_SHED], "key": "key:82", "pad": "pad:2", "extra": [],
	},
]

## The pad's own buttons, which the player never rebinds: the virtual cursor's click and its
## way back out (`pad.gd`). A is `interact` and the shoulders are the zoom, so those are
## read off the table; these two are all that is left.
const FIXED := {
	&"pad_back": ["pad:1"],
	&"aim_left": ["axis:2:-1"],
	&"aim_right": ["axis:2:1"],
	&"aim_up": ["axis:3:-1"],
	&"aim_down": ["axis:3:1"],
}

## What the player has changed, action -> {"key": String, "pad": String}. Only what differs
## from the table is kept, so a default that is retuned later reaches a player who never
## touched that row.
static var _set: Dictionary = {}

## What the walking stick is called on the board. The sticks are `FIXED` and have no row, so
## this is the only place the player is told one exists.
static var STICK_NAME: String:
	get: return Text.BIND_STICK

## Xbox names: the words a pad binding falls back to where no glyph can be drawn, on an Xbox
## pad (`Glyphs.PS_NAMES` on a PlayStation one). Index is `JoyButton`.
const PAD_NAMES := {
	0: "A", 1: "B", 2: "X", 3: "Y",
	4: "Back", 5: "Guide", 6: "Start",
	7: "L3", 8: "R3", 9: "LB", 10: "RB",
	11: "D-Pad Up", 12: "D-Pad Down", 13: "D-Pad Left", 14: "D-Pad Right",
}

const AXIS_NAMES := {
	"4:1": "LT",
	"5:1": "RT",
}

const MOUSE_NAMES := {
	1: "Left click", 2: "Right click", 3: "Middle click",
	4: "Wheel up", 5: "Wheel down", 6: "Wheel left", 7: "Wheel right",
}


## The whole table as `action -> row`, built once.
static func rows() -> Array:
	return ACTIONS


static func row_of(action: StringName) -> Dictionary:
	for row: Dictionary in ACTIONS:
		if row["action"] == action:
			return row
	return {}


## What `action` is bound to on `column` ("key" or "pad") right now: the player's override
## if they have one, else the table's own.
static func bound(action: StringName, column: String) -> String:
	var over: Dictionary = _set.get(action, {})
	if over.has(column):
		return String(over[column])
	return String(row_of(action).get(column, ""))


## Bind `event` (written down, see `write`) to `action` on `column`, swapping with whatever
## else in the same context holds it. Returns the action it swapped with, or `&""`.
static func bind(action: StringName, column: String, event: String) -> StringName:
	var swapped := &""
	if not event.is_empty():
		var holder := holder_of(action, column, event)
		if holder != &"" and holder != action:
			_write(holder, column, bound(action, column))
			swapped = holder
	_write(action, column, event)
	install()
	return swapped


## Put one cell back to the table's own binding. The board's right-click, and the only way
## back to a default the capture will not take — Escape cancels a capture, so it can never
## be pressed *into* one, and `open_settings` is on Escape to begin with.
static func restore(action: StringName, column: String) -> void:
	_write(action, column, String(row_of(action).get(column, "")))
	install()


## Pairs of verbs one binding may serve at once, by design: the middle button's drag pans
## and its tap recentres. Neither takes the other's binding away.
const SHARED := {&"camera_pan": [&"recentre"], &"recentre": [&"camera_pan"]}


## Who else, in a context this action shares, is bound to `event` on this column.
static func holder_of(action: StringName, column: String, event: String) -> StringName:
	if event.is_empty():
		return &""
	var mine: Array = row_of(action).get("contexts", [])
	for row: Dictionary in ACTIONS:
		var other: StringName = row["action"]
		if other == action or other in SHARED.get(action, []):
			continue
		if bound(other, column) != event:
			continue
		for context: StringName in row["contexts"]:
			if context in mine:
				return other
	return &""


static func _write(action: StringName, column: String, event: String) -> void:
	var over: Dictionary = _set.get(action, {})
	if String(row_of(action).get(column, "")) == event:
		over.erase(column)
	else:
		over[column] = event
	if over.is_empty():
		_set.erase(action)
	else:
		_set[action] = over


## Put every row back to the table's own binding.
static func reset() -> void:
	_set.clear()
	install()


## The player's overrides, and putting a whole set back. **The harness's, so that a test that
## rebinds something can leave the player's own keys exactly as it found them** — the same
## rule the sound levels follow. Nothing in the game calls these.
static func overrides() -> Dictionary:
	return _set.duplicate(true)


static func take_overrides(set: Dictionary) -> void:
	_set = set.duplicate(true)
	install()


## Whether anything at all has been rebound.
static func changed() -> bool:
	return not _set.is_empty()


## Lay the table, and then the player's overrides, onto the engine's input map. Called at
## boot from `Prefs` and again after every bind, so what the game reads is never a second
## copy of this table that could drift from it.
static func install() -> void:
	for row: Dictionary in ACTIONS:
		var action: StringName = row["action"]
		var events: Array[String] = []
		events.append(bound(action, "key"))
		events.append(bound(action, "pad"))
		for extra: String in row["extra"]:
			events.append(extra)
		_fill(action, events, float(row.get("deadzone", 0.2)))
	for action: StringName in FIXED:
		var fixed: Array[String] = []
		for written: String in FIXED[action]:
			fixed.append(written)
		_fill(action, fixed, 0.2)


static func _fill(action: StringName, events: Array[String], deadzone: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)
	InputMap.action_set_deadzone(action, deadzone)
	InputMap.action_erase_events(action)
	for written: String in events:
		var event := read(written)
		if event != null:
			InputMap.action_add_event(action, event)


## Read the player's overrides out of the settings file.
static func load_from(cfg: ConfigFile) -> void:
	_set.clear()
	if not cfg.has_section(SECTION):
		return
	for key: String in cfg.get_section_keys(SECTION):
		# "walk_up.key" -> action, column. A key from an older build whose action is gone
		# is dropped rather than refused: a bind file is not a save file.
		var cut := key.rfind(".")
		if cut <= 0:
			continue
		var action := StringName(key.substr(0, cut))
		var column := key.substr(cut + 1)
		if row_of(action).is_empty() or not (column in ["key", "pad"]):
			continue
		var written := String(cfg.get_value(SECTION, key, ""))
		if read(written) == null and not written.is_empty():
			continue
		var over: Dictionary = _set.get(action, {})
		over[column] = written
		_set[action] = over


static func save_to(cfg: ConfigFile) -> void:
	if cfg.has_section(SECTION):
		cfg.erase_section(SECTION)
	for action: StringName in _set:
		var over: Dictionary = _set[action]
		for column: String in over:
			cfg.set_value(SECTION, "%s.%s" % [action, column], String(over[column]))


## An event as one line of text, so it can live in an ini file: `key:<physical>`,
## `mouse:<index>`, `pad:<button>` or `axis:<axis>:<sign>`.
static func write(event: InputEvent) -> String:
	var key := event as InputEventKey
	if key != null:
		return "key:%d" % (key.physical_keycode if key.physical_keycode != 0 else key.keycode)
	var click := event as InputEventMouseButton
	if click != null:
		return "mouse:%d" % click.button_index
	var button := event as InputEventJoypadButton
	if button != null:
		return "pad:%d" % button.button_index
	var motion := event as InputEventJoypadMotion
	if motion != null:
		return "axis:%d:%d" % [motion.axis, int(signf(motion.axis_value))]
	return ""


static func read(written: String) -> InputEvent:
	var parts := written.split(":")
	if parts.size() < 2:
		return null
	match parts[0]:
		"key":
			var key := InputEventKey.new()
			key.physical_keycode = int(parts[1]) as Key
			return key
		"mouse":
			var click := InputEventMouseButton.new()
			click.button_index = int(parts[1]) as MouseButton
			return click
		"pad":
			var button := InputEventJoypadButton.new()
			button.button_index = int(parts[1]) as JoyButton
			return button
		"axis":
			if parts.size() < 3:
				return null
			var motion := InputEventJoypadMotion.new()
			motion.axis = int(parts[1]) as JoyAxis
			motion.axis_value = signf(float(parts[2]))
			return motion
	return null


## What to call a binding on screen. A key is named by **what is printed on it on this
## player's keyboard**, not by the letter we bound: the binding is a hole in the keyboard and
## the label is the OS's business.
static func label_of(written: String) -> String:
	if written.is_empty():
		return "—"
	var parts := written.split(":")
	match parts[0]:
		"key":
			return key_name(int(parts[1]) as Key)
		"mouse":
			return String(MOUSE_NAMES.get(int(parts[1]), "Mouse %s" % parts[1]))
		"pad", "axis":
			# Said in the family on screen (issue #33): Cross, not A, on a PlayStation pad.
			var words := Glyphs.pad_words(written)
			if not words.is_empty():
				return words
			if parts[0] == "pad":
				return String(PAD_NAMES.get(int(parts[1]), "Pad %s" % parts[1]))
			var pair := "%s:%s" % [parts[1], parts[2]] if parts.size() > 2 else ""
			return String(AXIS_NAMES.get(pair, "Axis %s" % parts[1]))
	return "—"


## What is *always* on this action's column besides the one binding the board can edit, or
## "" where there is nothing. The walking rows are the case: the left stick moves the angler
## through their `extra` list and is not rebindable, so a pad cell reading "—" was telling the
## player the verb had no gamepad control at all.
##
## Read off the table's own `extra` rather than off a list of action names, so a verb that is
## given a stick later says so without anything here being edited.
static func standing_label(action: StringName, column: String) -> String:
	if column != "pad":
		return ""
	for event: String in row_of(action).get("extra", []):
		if event.begins_with("axis:"):
			return STICK_NAME
	return ""


## The word printed on that hole in the keyboard, through the OS's layout.
static func key_name(physical: Key) -> String:
	var shown := physical
	# Only a real display server has a keyboard layout to ask about; the harness and the
	# headless probes run under the dummy one, which answers with an error in the log.
	if DisplayServer.get_name() != "headless":
		var label := DisplayServer.keyboard_get_label_from_physical(physical)
		if label != KEY_NONE:
			shown = label
	return OS.get_keycode_string(shown)


## What an action is called on screen, for a prompt in the world: the pad's button in pad
## mode, the key otherwise. **The pad's button is its glyph** (issue #33): a token
## `Style.write` draws as the picture, or the button's words where the pack has no tile.
static func shown(action: StringName, pad: bool) -> String:
	if pad:
		return Glyphs.token(bound(action, "pad"))
	return label_of(bound(action, "key"))


## Whether this event is one the board may take for a column. The sticks are never bound
## (axes 0 to 3) and a modifier on its own is not a binding.
static func bindable(event: InputEvent, column: String) -> bool:
	if column == "pad":
		# B is the pad's way back (`FIXED`'s `pad_back`) and what cancels a capture, the
		# pad's Escape: never a binding.
		if event is InputEventJoypadButton:
			return (event as InputEventJoypadButton).button_index != JOY_BUTTON_B
		var motion := event as InputEventJoypadMotion
		return motion != null and motion.axis >= JOY_AXIS_TRIGGER_LEFT \
			and absf(motion.axis_value) >= 0.5
	if event is InputEventMouseButton:
		return true
	var key := event as InputEventKey
	if key == null:
		return false
	return not (key.physical_keycode in [
		KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_ESCAPE,
	])
