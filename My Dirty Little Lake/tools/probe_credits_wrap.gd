## What the credits board's own rows measure, and whether they fit.
##
## Run headless: `<exe> --path . --headless --script res://tools/probe_credits_wrap.gd`.
## Writes `tools/last_credits_wrap.log`.
##
## Two things this got wrong until 2026-09-19, both of which made it measure a board the
## game never draws:
##
## 1. It was handed **board** widths (460, 300, 220) and passed them straight to `_laid_out`,
##    which takes a **face** width. The face is `Style.board_face` of the board less the
##    frame's wood — 430 at the board's own 460 — so every row was measured against 30 px
##    it does not have. The probe takes board widths and converts, the way `_lay_out` does.
## 2. It built the board with `CreditsBoard.new()` and never put it in the tree, so `_ready`
##    never ran, `_icon` stayed null and `_icon_room()` returned 0 — which is exactly the
##    row the Spotify mark stands on. The board goes into the tree here.
##
## It also reports the **height**, which is the thing a new credit actually threatens: the
## board is capped at `size.y - 40` and rows past the face's bottom are dropped silently
## (`_draw`, no `dropped_lines` counter). The smallest window the game supports is
## `Prefs.LEAST_WINDOW`, 1280x720, so 680 is the height to read the total against.
extends SceneTree

const Style := preload("res://scripts/style.gd")

## Board widths to measure, in the 1280-wide design frame. The first is the board's own
## `BOARD_WIDE`; the others are there to show where the required strings start wrapping.
const WIDTHS := [460.0, 300.0, 220.0]

## The height a board has to fit inside at the smallest supported window (720 less the
## board's own 40 px of margin).
const ROOM := 680.0


func _init() -> void:
	var board := CreditsBoard.new()
	# In the tree, or `_ready` never runs and the mark's row is measured without it.
	root.add_child(board)
	var out := FileAccess.open("res://tools/last_credits_wrap.log", FileAccess.WRITE)
	for wide: float in WIDTHS:
		var box := Rect2(Vector2.ZERO, Vector2(wide, 1000.0))
		var face := Style.board_face(box, CreditsBoard.FRAME).size.x
		var rows: Array = board.call("_laid_out", face)
		var lines := 0
		var tall := (
			Style.board_wood_tall(wide, CreditsBoard.FRAME) + CreditsBoard.BOARD_PAD * 2.0
		)
		var widest := 0.0
		for row: Dictionary in rows:
			tall += float(row["step"])
			var text := String(row["text"])
			if text.is_empty():
				continue
			lines += 1
			widest = maxf(widest, Style.measure(text, int(row["px"])).x + float(row["icon"]))
		out.store_line(
			"board %d -> face %d -> %d rows, %d px tall (of %d), widest line %d of %d"
			% [int(wide), int(face), lines, int(tall), int(ROOM), int(widest), int(face)]
		)
		if tall > ROOM:
			out.store_line("  OVER: rows past the face's bottom are dropped without a word")
		for row: Dictionary in rows:
			var text := String(row["text"])
			if text.is_empty():
				continue
			var span := Style.measure(text, int(row["px"])).x + float(row["icon"])
			out.store_line(
				"  %5.1f%s  %s" % [span, "  <-- over" if span > face else "", text]
			)
		out.store_line("")
	out.close()
	board.queue_free()
	quit()
