## Reads a save file and says what is actually in it.
##
## For the one question a player cannot answer by looking at the game: the meter says the
## lake is clean, so why has nothing happened? The answer is always one of three things —
## the file is from an older build and was never loaded at all, the closing words have
## already been shown once, or there is something still in the water that the meter is too
## coarse to show. This prints all three.
##
##   godot --headless --path . res://tools/inspect_save.tscn --quit-after 5
extends Node

const OUT_PATH := "res://tools/last_save_report.log"

const FILES := [
	"user://lake_cleanup.save",
	"user://lake_cleanup_siege.save",
]


func _ready() -> void:
	var lines: Array[String] = []
	lines.append("--- save report")
	lines.append("user:// is %s" % ProjectSettings.globalize_path("user://"))
	for path: String in FILES:
		lines.append_array(_report(path))
	var text := "\n".join(lines)
	print(text)
	var file := FileAccess.open(ProjectSettings.globalize_path(OUT_PATH), FileAccess.WRITE)
	if file != null:
		file.store_string(text + "\n")
		file.close()
	get_tree().quit()


func _report(path: String) -> Array[String]:
	var out: Array[String] = []
	out.append("")
	out.append("%s" % path)
	if not FileAccess.file_exists(path):
		out.append("  no such file")
		return out
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		out.append("  could not be opened")
		return out
	var raw: Variant = file.get_var(true)
	file.close()
	var save := raw as Dictionary
	if save == null:
		out.append("  not a save this build understands")
		return out

	var version := int(save.get("version", 0))
	out.append("  version %d (this build writes %d)%s" % [
		version, 3, "  <-- would be REFUSED on load" if version != 3 else ""
	])
	out.append("  seed %d, level %s" % [
		int(save.get("seed", 0)), String(save.get("level", "(none written)"))
	])
	out.append("  farewell already shown: %s" % str(bool(save.get("farewell", false))))
	out.append("  money %.0f, caught %d, sold %d" % [
		float(save.get("sludge", 0.0)), int(save.get("caught", 0)),
		int(save.get("sold_count", 0))
	])

	if save.has("wave"):
		out.append("  siege: wave %d of %d, phase %d (0 gather, 1 fight, 2 won, 3 lost)" % [
			int(save.get("wave", 0)), 6, int(save.get("phase", 0))
		])
		out.append("  siege: shed %.1f, shield %.1f, ammo %.1fs, box %s" % [
			float(save.get("shed_health", 0.0)), float(save.get("shield", 0.0)),
			float(save.get("ammo_for", 0.0)),
			str(save.get("box", PackedInt32Array()))
		])

	var stacks: Array = save.get("stacks", []) as Array
	var pieces := 0
	var tiles_with := 0
	for stack: PackedInt32Array in stacks:
		if stack.is_empty():
			continue
		tiles_with += 1
		pieces += stack.size()
	out.append("  %d tiles saved, %d still holding something, %d pieces in the water" % [
		stacks.size(), tiles_with, pieces
	])
	out.append("  yard holds %d, %d aboard the fleet" % [
		(save.get("yard_held", PackedInt32Array()) as PackedInt32Array).size(),
		(save.get("afloat", PackedInt32Array()) as PackedInt32Array).size()
	])
	if pieces == 0:
		out.append("  -> the lake in this file is empty: the ending should fire on load")
	else:
		out.append("  -> the lake in this file is NOT empty: the ending is right not to fire")
	return out
