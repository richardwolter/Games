## One-off: renames the pieces in a save written between the sheet re-cut and the version
## that migrates it.
##
## Splitting the four welded frying pans out of the catalogue renumbered every piece after
## them, and lake.gd migrates a version 3 save through LakeScript.RECUT_RENAMES on load. A save
## written by the running game after the version went up but with the old names still in
## memory misses that: it says version 4 and holds version 3 names, and there is nothing in
## the file to tell the two apart. So this does it by hand, once, with a copy of the file
## left beside it.
##
##   godot --headless --path . --script res://tools/repair_save.gd
extends SceneTree

## lake.gd has no class_name, so the table is reached through the script itself.
const LakeScript := preload("res://scripts/lake.gd")

const SAVE := "user://lake_cleanup.save"
const BACKUP := "user://lake_cleanup.save.bak"


func _init() -> void:
	if not FileAccess.file_exists(SAVE):
		printerr("no save at %s" % SAVE)
		quit(1)
		return
	var file := FileAccess.open(SAVE, FileAccess.READ)
	var save: Dictionary = file.get_var(true)
	file.close()
	if save == null:
		printerr("could not read %s" % SAVE)
		quit(1)
		return

	var copy := FileAccess.open(BACKUP, FileAccess.WRITE)
	copy.store_var(save, true)
	copy.close()

	var moved := 0
	var finds: Array = []
	for name: String in save.get("unlocked", []) as Array:
		var renamed := _renamed(name)
		moved += 1 if renamed != name else 0
		finds.append(renamed)
	save["unlocked"] = finds
	var placed: Array = []
	for row: Dictionary in save.get("decor", []) as Array:
		var kept := row.duplicate(true)
		kept["piece"] = _renamed(String(row.get("piece", "")))
		placed.append(kept)
	save["decor"] = placed

	var out := FileAccess.open(SAVE, FileAccess.WRITE)
	out.store_var(save, true)
	out.close()
	printerr("renamed %d of %d finds; old file kept at %s" % [
		moved, finds.size(), BACKUP
	])
	quit(0)


## The same rename lake.gd does on a version 3 save, mirrored copies included.
func _renamed(name: String) -> String:
	if name.ends_with(Sheets.MIRROR_SUFFIX):
		var base := name.substr(0, name.length() - Sheets.MIRROR_SUFFIX.length())
		return String(LakeScript.RECUT_RENAMES.get(base, base)) + Sheets.MIRROR_SUFFIX
	return String(LakeScript.RECUT_RENAMES.get(name, name))
