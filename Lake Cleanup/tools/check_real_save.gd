## Opens the real lake against a copy of the player's own save and says whether the ending
## fires. Read-only: the copy is what is loaded and written to, never the original.
extends Node

## Which save to open, and which scene to open it in. Passed on the command line as
## `-- siege` for the second lake; the first is the default.
const FROM := "user://lake_cleanup.save"
const COPY := "user://real_save_check.save"
const SIEGE_FROM := "user://lake_cleanup_siege.save"
const SIEGE_COPY := "user://real_siege_check.save"
const OUT := "res://tools/last_real_save_check.log"

var _main: Node2D
var _frames: int = 0


func _ready() -> void:
	var siege := OS.get_cmdline_user_args().has("siege")
	var from := SIEGE_FROM if siege else FROM
	var copy_to := SIEGE_COPY if siege else COPY
	var scene := "res://scenes/siege.tscn" if siege else "res://scenes/main.tscn"
	_say("--- opening %s in %s" % [from, scene])
	var source := FileAccess.open(from, FileAccess.READ)
	if source == null:
		_say("no save to check")
		get_tree().quit()
		return
	var bytes := source.get_buffer(source.get_length())
	source.close()
	var copy := FileAccess.open(copy_to, FileAccess.WRITE)
	copy.store_buffer(bytes)
	copy.close()

	_main = load(scene).instantiate()
	_main.set(&"save_path", copy_to)
	add_child(_main)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames < 90:
		return
	var grid := _main.get_node(^"Grid") as LakeGrid
	_say("pieces in the lake: %d" % grid.piece_count())
	_say("pollution: %.6f" % float(_main.get(&"pollution")))
	_say("cleaned: %s" % str(bool(_main.get(&"_cleaned"))))
	_say("farewell shown before: %s" % str(bool(_main.get(&"_farewell_shown"))))
	_say("closing words on screen: %s" % str(_main.get_node_or_null(^"Farewell") != null))
	var ward := _main.get_node_or_null(^"Ward") as Ward
	if ward != null:
		_say("siege wave: %d" % int(_main.get(&"wave")))
		_say("shed: %.1f, shield: %.1f" % [ward.health, ward.shield])
		_say("monsters in the water: %d" % (_main.get_node(^"Swarm") as SludgeSwarm).alive())
	get_tree().quit()


func _say(line: String) -> void:
	print(line)
	var path := ProjectSettings.globalize_path(OUT)
	var file := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(line)
	file.close()
