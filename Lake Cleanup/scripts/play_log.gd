## The playtest log of the player's own run: one JSON object per line in
## `user://shop_playtest.log`.
##
## Written so the progression sim (`docs/progression/build_shop.py`) can be recalibrated against
## real play (issue #23): when each level was bought and for how much, how the lake cleared, how
## many pieces stood waiting in the crate, how often the net went out, how long was spent in the
## shed. `t` is seconds of play in this run (saved with it, so a run spread over several
## sittings reads as one timeline); `at` is the wall clock. Appended to, never truncated: every
## sitting lands in the same file, told apart by the `session` lines.
##
## Only the player's own run writes here (`Lake._logs_play`: the lake on the player's own save
## path). Every harness and probe runs on a save of its own and so writes nothing.
class_name PlayLog
extends RefCounted

const PATH := "user://shop_playtest.log"
## Where lines go. A harness that wants to read lines back points this at a file of its own.
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
