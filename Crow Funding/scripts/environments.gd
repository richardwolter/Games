extends RefCounted
## The cities the balcony can look over. Visual only: loot, economy and saves are
## shared. The choice lives in the Settings autoload; City, Sky and Balcony read it
## through current() and redraw on Settings.environment_changed.

const CLASSIC := "classic"
const MODERN := "modern"
const IDS: Array[String] = [CLASSIC, MODERN]
const NAMES := {CLASSIC: "Old Town", MODERN: "Downtown"}


## The active environment id. @tool scripts run in the editor, where autoloads
## are absent, so this falls back to the classic city there.
static func current(from: Node) -> String:
	var settings := from.get_node_or_null("/root/Settings")
	if settings == null:
		return CLASSIC
	return settings.environment


## Connects `callable` to environment switches, if the Settings autoload exists.
static func watch(from: Node, callable: Callable) -> void:
	var settings := from.get_node_or_null("/root/Settings")
	if settings != null and not settings.environment_changed.is_connected(callable):
		settings.environment_changed.connect(callable)
