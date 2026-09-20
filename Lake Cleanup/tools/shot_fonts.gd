extends Node
## The eight languages, drawn in the faces they will really be drawn in (issue #28,
## 2026-09-20). A probe, for Richard to judge the fonts by eye before the extraction is
## built — the question being whether Bungee for Latin and a stand-in for each of the three
## CJK scripts reads as one game.
##
## Run it with the desktop build, not `--headless`: nothing renders under the dummy driver,
## and a font that fails to load fails silently there.
##
## Two things are saved, because they answer two different questions:
##   `tools/last_font_<locale>.png` — the shop's **real** net board, the game's own
##     carpentry, at the real 1180-wide layout, with that locale's words in its rows. This
##     is where a name too long for its 87 pixels shows itself.
##   `tools/last_fonts_type.png` — all eight stacked as plain type at the real ladder sizes:
##     the settings board's widest labels and the letter's longest sentence. A face is
##     judged at length here, a layout is judged on the board above.
##
## The words come from `tools/font_samples.gd` and are **samples, not the translation**.

const Samples := preload("res://tools/font_samples.gd")
const Style := preload("res://scripts/style.gd")

const LOG_PATH := "res://tools/last_fonts.log"
## The type sheets, in the order they are drawn and saved.
const PAGES: Array[String] = ["type_a", "type_b", "weights"]

## How long to let the lake settle, and how many frames a locale gets: one to push the words
## and the face, one to let the board redraw, one to take the picture.
const SETTLE := 24

## The frame the whole game is laid out in; the window is stretched to it.
const DESIGN := Vector2(1280.0, 720.0)
const PER_LOCALE := 3

var _main: Node
var _skin: Control
var _frames := 0
var _at := -1
var _lines: PackedStringArray = []
var _sheet: Control


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_main = load("res://scenes/main.tscn").instantiate()
	# Under this node and on a save of its own — a probe parented to the root is the game,
	# which since The Front means the menu is up and the HUD is hidden.
	_main.set(&"save_path", "user://probe_fonts.save")
	add_child.call_deferred(_main)
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _main == null or not _main.is_inside_tree():
		return
	if _frames == SETTLE:
		_skin = _main.get_node(^"HUD/ShopSkin") as Control
		# The board is shown by hand rather than through `_set_menu`: with the menu open the
		# lake writes `_shop_skin.rows = _shop_rows()` **every frame**, so the sample words
		# were overwritten with English between being pushed and being photographed.
		_skin.visible = true
		_lines.append("window %s" % str(DisplayServer.window_get_size()))
		return
	if _frames < SETTLE:
		return
	var step := _frames - SETTLE - 1
	if step < 0:
		return
	var which := step / PER_LOCALE
	var phase := step % PER_LOCALE
	if which >= Samples.LOCALES.size():
		_type_sheets(step - Samples.LOCALES.size() * PER_LOCALE)
		return
	var locale: String = Samples.LOCALES[which]
	if phase == 0:
		_dress(locale)
	elif phase == 2:
		_shoot(locale)


## The locale's face and the locale's words, into the live board.
func _dress(locale: String) -> void:
	Style.set_locale(locale)
	_skin.set(&"rows", Samples.shop_rows(locale))
	_skin.set(&"titles", {&"net": String(Samples.BOARD_NET[locale])})
	# The legend is the lake's and is still English; it stands under the middle two boards,
	# which are empty here, so it is out of the crop either way.
	_skin.queue_redraw()


## The net board alone, cropped out of the window. The other three boards have no sample
## rows and stand empty; the net board is the one with the longest run of rows and no group
## heading over them, which is what a name has to fit inside.
func _shoot(locale: String) -> void:
	var boards: Dictionary = _skin.get(&"_boards")
	var box: Rect2 = boards.get(&"net", Rect2())
	var shot := get_viewport().get_texture().get_image()
	if box.size.x > 0.0:
		# The skin fills the 1280x720 design frame from its origin and the window does not,
		# so the box is scaled by the stretch rather than put through the canvas transform —
		# which on the first run returned a rect at the window's own corner.
		var k := Vector2(shot.get_size()) / DESIGN
		var on_screen := Rect2(box.position * k, box.size * k)
		# The ribbon straddles the board's top edge and the price tags hang off its right,
		# so the crop is grown rather than taken at the box.
		on_screen = on_screen.grow(30.0 * k.y)
		on_screen = on_screen.intersection(Rect2(Vector2.ZERO, Vector2(shot.get_size())))
		if on_screen.size.x >= 1.0 and on_screen.size.y >= 1.0:
			shot = shot.get_region(Rect2i(on_screen))
		_lines.append("    net board %s -> crop %s" % [str(box), str(on_screen)])
	var path := "res://tools/last_font_%s.png" % locale
	shot.save_png(ProjectSettings.globalize_path(path))
	var face := Style.font()
	var name_of: String = String(Samples.ROWS[&"net_range"][locale])
	_lines.append("%-6s %-22s face %s  '%s' at TEXT_BODY = %.1f px" % [
		locale, String(Samples.ENDONYM[locale]), _face_name(face), name_of,
		face.get_string_size(name_of, HORIZONTAL_ALIGNMENT_LEFT, -1.0, Style.TEXT_BODY).x,
	])


## Which face answered: the chain's own base, and what stands behind it. A `FontVariation`
## reports its base font's name, so the fallback is named separately or the log would say
## Bungee for all eight.
func _face_name(face: Font) -> String:
	var behind := ""
	if face is FontVariation:
		var chain: Array = (face as FontVariation).fallbacks
		if not chain.is_empty() and chain[0] != null:
			behind = " + " + (chain[0] as Font).get_font_name()
	return face.get_font_name() + behind


## The type sheets, in order: four locales, four locales, then the weight ladder. Two frames
## each — one to set the page, one to photograph it.
##
## **Four to a page, not eight.** At eight the blocks were 180 design pixels for seven lines
## of type and every sentence ran through the heading under it.
func _type_sheets(step: int) -> void:
	var page := step / 2
	if page >= PAGES.size():
		_finish()
		return
	if step % 2 == 0:
		_open_sheet()
		_sheet.page = page
		_sheet.queue_redraw()
		return
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("res://tools/last_fonts_%s.png" % PAGES[page])
	)


func _open_sheet() -> void:
	if _sheet != null:
		return
	_skin.visible = false
	var over := CanvasLayer.new()
	over.layer = 100
	add_child(over)
	_sheet = TypeSheet.new()
	# Sized by hand, not by anchors: a Control whose parent is not a Control has nothing to
	# anchor against and stays at zero, where it is culled before `_draw` reaches the screen
	# — the trap `ClickRipple` is written up for. In the design frame, not window pixels.
	_sheet.size = DESIGN
	over.add_child(_sheet)


func _finish() -> void:
	var file := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file != null:
		for line in _lines:
			file.store_line(line)
		file.close()
	get_tree().quit()


## The type sheets. A page of four locales is two columns of two, each block a locale's
## name, the settings board's widest labels and the letter's longest sentence, over the
## shop's own paper so the ink is the ink it will be read in.
##
## The last page is the **weight ladder**: the same line in each stand-in face at four
## points of the `wght` axis. A variable font opens at its lightest named instance, so
## `Style.FALLBACK_WEIGHT` is a number somebody has to choose by eye — this is what it is
## chosen on, and what shows the axis is being applied at all.
class TypeSheet:
	extends Control

	const EDGE := 30.0
	const LINE_GAP := 7.0
	const COLS := 2
	const PER_PAGE := 4
	## What the ladder tries. **Embolden, not `wght`** — the axis does not reach these faces
	## (see `Style.FALLBACK_EMBOLDEN`), so this is the knob that actually moves.
	const LADDER: Array[float] = [0.0, 0.3, 0.55, 0.8]

	var page := 0

	## Every face this page drew with, held until the page has been photographed.
	##
	## **A `draw_string` does not rasterise inside `_draw`**: it records a command that reads
	## the font when the frame is drawn. Dropping the cache at the end of `_draw` freed the
	## chains and every glyph on the page came out as .notdef — a whole sheet of tofu, twice,
	## and it looked exactly like the fallback not being wired up at all.
	var _kept: Array[Font] = []

	func _draw() -> void:
		var was := Style._locale
		_kept.clear()
		draw_rect(Rect2(Vector2.ZERO, size), Style.PAPER, true)
		if page < 2:
			_draw_locales()
		else:
			_draw_weights()
		Style._locale = was

	func _draw_locales() -> void:
		var col_wide := (size.x - EDGE * 2.0) / float(COLS)
		var block := (size.y - EDGE) / float(PER_PAGE / COLS)
		for i in PER_PAGE:
			var at_locale := page * PER_PAGE + i
			if at_locale >= Samples.LOCALES.size():
				return
			var locale: String = Samples.LOCALES[at_locale]
			Style.set_locale(locale)
			var at := Vector2(
				EDGE + col_wide * float(i % COLS),
				EDGE + block * float(i / COLS) + float(Style.TEXT_HEAD)
			)
			at.y += Style.write(
				self, "%s  ·  %s" % [locale, String(Samples.ENDONYM[locale])],
				Style.TEXT_HEAD, at, Style.PAPER_HEAD
			).y + LINE_GAP
			_kept.append(Style.font())
			for row: Dictionary in Samples.SETTINGS:
				at.y += Style.write(
					self, String(row[locale]), Style.TEXT_BODY, at, Style.PAPER_INK
				).y + LINE_GAP
			at.y += LINE_GAP
			# The sentence at the letter's own small size. `Style.write` neither wraps nor
			# clips, so a long one runs past its column — which is itself worth seeing.
			Style.write(
				self, String(Samples.SENTENCE[locale]), Style.TEXT_SMALL, at,
				Style.PAPER_SOFT
			)

	func _draw_weights() -> void:
		var at := Vector2(EDGE, EDGE + float(Style.TEXT_HEAD))
		Style.set_locale("en")
		at.y += Style.write(
			self, "How much the stand-in faces are thickened",
			Style.TEXT_HEAD, at, Style.PAPER_HEAD
		).y + LINE_GAP * 2.0
		for locale: String in ["ja", "zh_CN", "ko"]:
			Style.set_locale("en")
			at.y += Style.write(
				self, "%s  ·  %s" % [locale, String(Samples.ENDONYM[locale])],
				Style.TEXT_SMALL, at, Style.PAPER_SOFT
			).y + LINE_GAP
			for weight in LADDER:
				# The chain is rebuilt per rung: `font()` keeps one face per locale, so the
				# cache has to be dropped between rungs or every rung is the first one. What
				# it held is kept in `_kept` until the page is photographed.
				Style._fonts.clear()
				Style.FALLBACK_EMBOLDEN_OVERRIDE = weight
				Style.set_locale(locale)
				_kept.append(Style.font())
				var line := "%s  %s  %s" % [
					String(Samples.SETTINGS[1][locale]),
					String(Samples.SETTINGS[3][locale]),
					String(Samples.BOARD_NET[locale]),
				]
				var took := Style.write(self, line, Style.TEXT_BODY, at, Style.PAPER_INK)
				Style.set_locale("en")
				Style.write(
					self, "  embolden %.2f" % weight, Style.TEXT_SMALL,
					at + Vector2(420.0, 0.0), Style.PAPER_SOFT
				)
				at.y += took.y + LINE_GAP
			Style.FALLBACK_EMBOLDEN_OVERRIDE = -1.0
			Style._fonts.clear()
			Style.set_locale("en")
			_kept.append(Style.font())
			at.y += LINE_GAP * 2.0
