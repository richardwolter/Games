extends SceneTree

const Style := preload("res://scripts/style.gd")

func _init() -> void:
	var board := CreditsBoard.new()
	var out := FileAccess.open("res://tools/last_credits_wrap.log", FileAccess.WRITE)
	for wide in [460.0, 300.0, 220.0]:
		var rows: Array = board.call("_laid_out", wide)
		var lines := 0
		for row in rows:
			if not String(row["text"]).is_empty():
				lines += 1
		out.store_line("face %d -> %d rows" % [int(wide), lines])
		for row in rows:
			var text := String(row["text"])
			if text.is_empty():
				continue
			out.store_line("  %5.1f  %s" % [Style.measure(text, int(row["px"])).x, text])
	out.close()
	board.free()
	quit()
