## The tree test run's playtest log: one JSON object per line in `user://tree_playtest.log`.
##
## Written so the progression sim can be recalibrated against real play: when each node was
## bought, how the lake cleared, how often the net went out, how long was spent in the shed.
## `t` is seconds of play in this run (saved with it, so a run spread over several sittings
## reads as one timeline); `at` is the wall clock. Appended to, never truncated: every sitting
## of every tree run lands in the same file, told apart by the `session` lines.
class_name TreeLog
extends RefCounted

const PATH := "user://tree_playtest.log"
## Where lines go. The test harness points this at a file of its own, so a test run never
## writes into the player's playtest log.
static var path: String = PATH


static func write(kind: String, t: float, data: Dictionary = {}) -> void:
	var row := data.duplicate()
	row["kind"] = kind
	row["t"] = snappedf(t, 0.01)
	row["at"] = Time.get_datetime_string_from_system()
	var f := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(JSON.stringify(row))
	f.close()
