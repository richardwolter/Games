## The end of the run: the lake is empty, and this says so.
##
## Drawn rather than built out of Labels, for the same reason the shop board and the HUD are
## drawn — the game writes its own text everywhere else, and a centred pair of Label nodes
## with a StyleBox behind them would be the one screen that came from a different game. It
## also means the words are sized off the window rather than off a font size chosen for one
## resolution, which matters here: this is the last thing a player sees, and it should not
## be a caption on a phone and a wall of text on a monitor.
##
## Owns its own fade and its own dismissal. The lake underneath is still running and still
## sparkling; this is a note laid over it, not a scene change.
##
## **And it rolls the credits** (2026-09-16, Richard): a cleaned lake is the end of the game,
## so the same words `CreditsBoard` holds climb up under the message and off the top, and
## what is left afterwards is the two lines over the clean water. The words themselves do not
## move — the roll passes behind them — because they are what the ending says and a line that
## scrolls away is a line somebody missed.
##
## The rows are laid out here rather than borrowed from the board: the board is a plate of
## wood with a face to wrap against, and this is open water with the whole window to use. The
## strings, the headings and the Spotify mark's rules are the board's and are read from it, so
## a credit added there is added here.
class_name Farewell
extends Control

## The words. Two lines because they are two thoughts: what the player did, and goodbye.
static var LINES: Array:
	get: return [Text.END_LINE_1, Text.END_LINE_2]

## The padding around the door's label. Its text size comes off the shared ladder.
const ONWARD_PAD := Vector2(34.0, 16.0)
## How far below the second line the door sits, as a multiple of its own text size.
const ONWARD_DROP := 3.2

const Style := preload("res://scripts/style.gd")

## The roll: how long the credits take to climb the whole way, and how much faster a click
## runs them off. Long enough to read at a walk, short enough that the ending is not a
## corridor; the skip is what anybody who has read them once will use.
const ROLL_TIME := 26.0
const ROLL_SKIP := 9.0
## How far under the window the roll starts and how far over the top it goes before it is
## done, as fractions of the window's height. A credit is not finished the instant its
## baseline leaves the glass.
const ROLL_BELOW := 0.08
const ROLL_ABOVE := 0.12
## How wide the roll's text may be, as a fraction of the window. The credits carry required
## wordings that may not be shortened, so they wrap rather than shrink — the same rule the
## board follows.
const ROLL_WIDE := 0.7
## How much of itself a credit keeps while it is passing behind the message, and how far
## either side of the message it takes to get there.
##
## The words do not move and the roll goes under them, so the two cross. Drawn at full
## strength the crossing is two lines of lettering in the same place and neither can be
## read; at nothing the roll blinks out and back, which is worse. It dims instead, the way
## anything passing behind something else does.
const ROLL_BEHIND := 0.15
const ROLL_BEHIND_SOFT := 46.0

## The gap after a whole credit, after a wrapped row of one, and for a blank line: the
## board's own three numbers, so the two read the same.
const ROLL_GAP := 8.0
const ROLL_WRAP_GAP := 2.0
const ROLL_BLANK := 12.0

## How long the words take to arrive, and how long they take to go once dismissed. Slow in,
## because it is the end of a long job and the end of a long job is not a pop-up; quicker
## out, because by then the player has decided.
## Two seconds longer than it was (2026-09-16, Richard: the shimmer can last two seconds
## longer as the message fades in). The lake underneath is live and lighting up the whole
## time, and the wash over it eases in with the words — so a slower fade is more clean water
## before the ending is written over it, which is what was asked for. Since 2026-09-18 this
## fade is the only breath there is: the two-second beat in front of it (`Lake.ENDING_BEAT`)
## and its struck note are gone, and the words start arriving as the last piece lands.
const FADE_IN := 3.6
const FADE_OUT := 0.5

## Nothing may be dismissed for this long. A player whose last catch happened under the
## cursor would otherwise click the screen away before reading a word of it.
const SETTLE := 0.6

## The gap between the lines, as a fraction of the first one's size. The sizes themselves
## come off the shared ladder.
const GAP := 1.5

## Where the message's block sits down the window, as a fraction of it.
##
## **The middle** (2026-09-16, Richard): it used to sit at 0.60, a little below, because the
## middle is where the island is and the words are about the island. With the credits
## climbing under them the low block left the roll a short screen to cross and a long one to
## wait in, so the words moved up and the roll got the room. One number, read by the message
## and by the band the roll dims in, or the two would drift.
const BLOCK_AT := 0.5

## How dark the lake goes behind the words. Enough to read against, nowhere near enough to
## hide what the player has just finished — the sparkle is the other half of this ending.
const WASH := Style.SCRIM

## Emitted once the screen has faded out and is on its way to being freed, so the lake can
## give the angler their legs back.
signal dismissed

## Emitted when the player takes the door back to the main menu (2026-09-12). Always
## drawn: a finished lake has to lead somewhere, and clicking the words away to keep
## fishing an empty lake is the other choice, not the only one.
signal to_menu

static var MENU_LABEL: String:
	get: return Text.END_BACK

## The words actually shown. Defaults to LINES, and is set to something else by a level
## whose ending is not the cleaned lake.
var lines: Array = []

var _font: Font
## 0 to 1 on the way in, and back to 0 on the way out.
var _shown: float = 0.0
var _leaving: bool = false
var _age: float = 0.0
## Where the menu door was last drawn, so a click is tested against what the player saw.
var _menu_rect := Rect2()
var _menu_hot: bool = false
## The demo's ending (2026-10-09) also offers the store page, a door left of the menu's.
var wishlist: bool = false
## The home door reads "Back to lake" and only closes the words (the demo's ending).
var lake_door: bool = false
var _wish_rect := Rect2()
var _wish_hot: bool = false

## The credit roll: whether it is running, how far up it has climbed in pixels, whether a
## click has told it to hurry, and the rows themselves. Empty until `roll_credits`.
var _rolling: bool = false
var _roll_at: float = 0.0
var _roll_fast: bool = false
var _roll_rows: Array[Dictionary] = []
var _roll_tall: float = 0.0
## Spotify's mark, beside the row `CreditsBoard` names. Its own node at a linear filter,
## because it is a vector mark and may not be redrawn or distorted; the rest of this screen
## is drawn.
var _icon: TextureRect


func _ready() -> void:
	# Walked with the pad's stick (scripts/pad.gd, `pad_focus` below).
	add_to_group(Pad.FOCUS_GROUP)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	_font = Style.font()
	# Sized by hand rather than by anchors: the parent is a CanvasLayer, and a Control whose
	# parent is not a Control is not laid out by anyone. It has to keep up with the window
	# itself.
	_make_icon()
	_fill()
	get_viewport().size_changed.connect(_fill)
	if _rolling:
		_lay_out_roll()


## Cover the window, whatever shape it currently is.
func _fill() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	if _rolling:
		_lay_out_roll()


func _process(delta: float) -> void:
	_age += delta
	var rate := 1.0 / (FADE_OUT if _leaving else FADE_IN)
	_shown = move_toward(_shown, 0.0 if _leaving else 1.0, rate * delta)
	_roll(delta)
	queue_redraw()
	if _leaving and _shown <= 0.0:
		set_process(false)
		# The layer it was given is its own, so it takes that with it.
		var over := get_parent()
		if over is CanvasLayer:
			over.queue_free()
		else:
			queue_free()


## Start the credits climbing. Called before the screen is added to the tree, by a level
## whose ending is the end of the game.
func roll_credits() -> void:
	_rolling = true
	_roll_at = 0.0
	if is_node_ready():
		_lay_out_roll()


## Whether the credits are still on their way up. The doors are not drawn while they are:
## the roll would climb straight over them, and a plaque under a moving credit is a plaque
## nobody can aim at.
func rolling() -> bool:
	return _rolling


## Hurry the roll off. What a click does while it is running; a click after that dismisses
## the screen as it always did.
func skip_roll() -> void:
	_roll_fast = true


## One frame of the climb. The travel is the window plus everything the roll is made of, so
## the last credit is over the top before it stops rather than blinking out at the edge.
##
## Held until the message is up: the words are what the ending says, and a credit arriving
## while they are still a third of the way in reads as the roll having started without them.
func _roll(delta: float) -> void:
	if _rolling and not _leaving and _shown >= 1.0:
		var travel := size.y * (1.0 + ROLL_BELOW + ROLL_ABOVE) + _roll_tall
		var pace := travel / ROLL_TIME
		_roll_at += pace * (ROLL_SKIP if _roll_fast else 1.0) * delta
		if _roll_at >= travel:
			_rolling = false
			_roll_fast = false
	# Every frame, including the ones that did not move the roll: the mark has to be put
	# away when the roll ends, when the screen leaves, and while the words are still fading.
	_place_icon()


## Spotify's mark on the row it belongs to, moved here in the frame rather than in `_draw`.
##
## Placed from the draw it jittered as it climbed (2026-09-16, Richard): a child node's
## position set while its parent is filling its own draw list lands a frame late, and not
## always the same frame late, so the mark shivered against the name beside it.
##
## That was not the whole of it. The font is imported with `subpixel_positioning`, so a
## glyph lands on a **fraction-of-a-pixel grid** while a node's position is continuous: the
## name stepped, the mark slid, and the gap between them opened and closed every few frames.
## Leaving the mark unsnapped made that worse rather than better. **Both are put on the
## row's own whole pixel** now (`_roll_row_y`) — the text's baseline and the mark's box off
## the same rounded number — so whatever the rasteriser does with the glyphs, the two move
## as one thing. A roll that steps in whole pixels is right for this game anyway.
func _place_icon() -> void:
	if _icon == null:
		return
	if not _rolling or _roll_rows.is_empty():
		_icon.visible = false
		return
	var fade := 1.0 - pow(1.0 - _shown, 3.0)
	var y := _roll_top()
	for row in _roll_rows:
		var step := float(row["step"])
		var px := int(row["px"])
		if px > 0 and float(row["icon"]) > 0.0:
			var mark := roundf(_icon_size(px))
			var top := _roll_row_y(y)
			if top > -step and top < size.y + step:
				_icon.position = Vector2(
					roundf(_roll_start(row, String(row["text"]), px) - _icon_room(px)),
					top + roundf((float(px) - mark) * 0.5)
				)
				_icon.size = Vector2(mark, mark)
				_icon.modulate.a = fade * _roll_clear(top, float(px))
				_icon.visible = true
			else:
				_icon.visible = false
			return
		y += step
	_icon.visible = false


## The rows the roll is made of, wrapped to `ROLL_WIDE` of the window: the text, its size,
## whether it is a heading, the room the mark wants on it, and how far down to step after it.
##
## `CreditsBoard`'s own strings and its own headings, so the two cannot drift.
func _lay_out_roll() -> void:
	_roll_rows = []
	_roll_tall = 0.0
	var wide := size.x * ROLL_WIDE
	for text: String in CreditsBoard.LINES:
		if text.is_empty():
			_roll_rows.append({"text": "", "px": 0, "head": false, "icon": 0.0, "step": ROLL_BLANK})
			_roll_tall += ROLL_BLANK
			continue
		var head: bool = text in CreditsBoard.HEADS
		var px := Style.TEXT_HEAD if head else Style.TEXT_BODY
		var room := _icon_room(px) if text == CreditsBoard.ICON_LINE else 0.0
		var rows := _wrap(text, px, wide - room)
		for i in rows.size():
			var last := i == rows.size() - 1
			var step := float(px) + (ROLL_GAP if last else ROLL_WRAP_GAP)
			_roll_rows.append({
				"text": rows[i],
				"px": px,
				"head": head,
				"icon": room if i == 0 else 0.0,
				"step": step,
			})
			_roll_tall += step


## How much room the Spotify mark wants on its row, the mark and its gap together.
func _icon_room(px: int) -> float:
	return _icon_size(px) + CreditsBoard.ICON_GAP


## The mark is sized against the row it stands beside rather than at a fixed number of
## pixels: this screen is sized off the window, and a mark that did not follow would be a
## postage stamp on a monitor and a billboard on a laptop.
func _icon_size(px: int) -> float:
	return float(px) * (CreditsBoard.ICON_SIZE / float(Style.TEXT_BODY))


## One credit broken into the rows it is drawn as. Greedy on spaces; a single word too wide
## is left long rather than cut, because none of these strings may be shortened.
func _wrap(text: String, px: int, wide: float) -> PackedStringArray:
	var rows := PackedStringArray()
	var row := ""
	for word in text.split(" ", false):
		var tried := word if row.is_empty() else row + " " + word
		if not row.is_empty() and Style.measure(tried, px).x > wide:
			rows.append(row)
			row = word
		else:
			row = tried
	rows.append(row)
	return rows


## Spotify's mark as its own node, on the board's own terms: their file, their colours,
## their shape, at a linear filter. Missing art is no mark and no gap — the row simply
## reads as the name.
func _make_icon() -> void:
	var art := load(CreditsBoard.ICON_PATH) as Texture2D
	if art == null:
		return
	_icon = TextureRect.new()
	_icon.texture = art
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_SCALE
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.visible = false
	add_child(_icon)


## The credits, climbing. Drawn under the message. `Style.write` lays its own shadow, which
## is what lets pale letters cross bright water. Spotify's mark is a child node and is moved
## by `_place_icon` in the frame, not here.
func _draw_roll(fade: float) -> void:
	if not _rolling or _roll_rows.is_empty():
		return
	var y := _roll_top()
	for row in _roll_rows:
		var step := float(row["step"])
		var px := int(row["px"])
		var top := _roll_row_y(y)
		if px > 0 and top > -step and top < size.y + step:
			var head: bool = bool(row["head"])
			var tone := Style.RIBBON_INK if head else Style.INK
			var ink := Color(tone.r, tone.g, tone.b, fade)
			var text := String(row["text"])
			var start := roundf(_roll_start(row, text, px))
			var clear := _roll_clear(top, float(px))
			var base := top + float(px)
			Style.write(
				self, text, px, Vector2(start, base),
				Color(ink.r, ink.g, ink.b, 1.0), HORIZONTAL_ALIGNMENT_LEFT,
				Rect2(start, base, size.x, 1.0), fade * clear
			)
		y += step


## The band the message stands in, top and bottom. The same arithmetic `_draw` lays the two
## lines out with, kept in one place so the roll dims over exactly the rows the words cover
## rather than over a guess at where they are.
func _message_band() -> Vector2:
	var first := float(Style.TEXT_TITLE)
	var block := first + first * GAP
	var top := size.y * BLOCK_AT - block * 0.5
	return Vector2(top, top + block + float(Style.TEXT_HEAD))


## How much of itself a credit row keeps at this height: all of it clear of the message,
## `ROLL_BEHIND` of it inside, and an ease of `ROLL_BEHIND_SOFT` between the two.
func _roll_clear(top: float, tall: float) -> float:
	var band := _message_band()
	var gap := maxf(band.x - (top + tall), top - band.y)
	if gap >= ROLL_BEHIND_SOFT:
		return 1.0
	if gap <= 0.0:
		return ROLL_BEHIND
	return lerpf(ROLL_BEHIND, 1.0, gap / ROLL_BEHIND_SOFT)


## Where the roll's first row stands this frame, before any row's own rounding.
func _roll_top() -> float:
	return size.y * (1.0 + ROLL_BELOW) - _roll_at


## A row's top on a whole pixel. The one place the roll's height is quantised, asked by the
## writing and by Spotify's mark alike — see `_place_icon` for why they have to agree.
func _roll_row_y(y: float) -> float:
	return roundf(y)


## Where a row starts, so that the mark, its gap and the writing are centred on the window
## as one and a line carrying the mark is not pushed off centre by it.
func _roll_start(row: Dictionary, text: String, px: int) -> float:
	var span := Style.measure(text, px).x
	return (size.x - span - float(row["icon"])) * 0.5 + float(row["icon"])


func _home_label() -> String:
	return Text.DEMO_BACK_LAKE if lake_door else MENU_LABEL


## The player has taken the door home. Fades out like the others; the lake changes scene.
func take_menu() -> void:
	if _leaving or _age < SETTLE:
		return
	_leaving = true
	if lake_door:
		dismissed.emit()
		return
	to_menu.emit()


## The player has read it. Called by the click, and safe to call twice.
func dismiss() -> void:
	if _leaving or _age < SETTLE:
		return
	_leaving = true
	dismissed.emit()


func _gui_input(event: InputEvent) -> void:
	var moved := event as InputEventMouseMotion
	if moved != null:
		var home := not _rolling and _menu_rect.has_point(moved.position)
		var wish := not _rolling and _wish_rect.has_point(moved.position)
		if home != _menu_hot or wish != _wish_hot:
			if (home and not _menu_hot) or (wish and not _wish_hot):
				Sfx.ui(&"ui_hover")
			_menu_hot = home
			_wish_hot = wish
			queue_redraw()
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	# The door is a rectangle inside the screen, and the screen is dismissed by clicking
	# anywhere else on it. Testing the door first is what keeps the two apart.
	if not _rolling and _menu_rect.has_point(click.position):
		Sfx.ui(&"ui_click")
		take_menu()
		return
	if not _rolling and _wish_rect.has_point(click.position):
		Sfx.ui(&"ui_click")
		open_store()
		return
	# While the credits are climbing, a click runs them off rather than closing the screen:
	# a player who clicks to skip the roll has not asked to leave the lake yet, and the
	# doors are not even drawn until the roll is done.
	if _rolling:
		Sfx.ui(&"ui_click")
		skip_roll()
		return
	if not _leaving and _age >= SETTLE:
		Sfx.ui(&"ui_close")
	dismiss()


func _draw() -> void:
	if _font == null or _shown <= 0.0:
		return
	# Eased so the words do not arrive at a constant rate, which reads as a machine doing
	# it. In fast, then a long settle.
	var fade := 1.0 - pow(1.0 - _shown, 3.0)
	Style.dim(self, Rect2(Vector2.ZERO, size), WASH, fade)
	# Under the message, which is drawn over it: the roll passes behind the words rather
	# than pushing them about.
	_draw_roll(fade)

	var first := float(Style.TEXT_TITLE)
	var second := float(Style.TEXT_HEAD)
	var ink := Color(Style.INK.r, Style.INK.g, Style.INK.b, fade)
	var shade := Color(Style.SHADE.r, Style.SHADE.g, Style.SHADE.b, Style.SHADE.a * fade)

	# The pair is centred as a block rather than each line on its own row, so the gap
	# between them belongs to the words and not to the window.
	var block := first + first * GAP
	# A little below the middle, because the middle is where the island is and the island is
	# the thing the sentence is about. The words sit on open water under it.
	var top := size.y * BLOCK_AT - block * 0.5
	# Lifted a little as it arrives: the words settle onto the lake rather than appearing
	# on it.
	top += (1.0 - fade) * size.y * 0.03
	var said := lines if not lines.is_empty() else LINES
	_line(String(said[0]), int(first), top + first, ink, shade)
	var second_baseline := top + first + first * GAP
	_line(String(said[1]), int(second), second_baseline, ink, shade)
	var under := second_baseline
	# The doors wait for the roll: a plaque under a climbing credit is one nobody can aim at,
	# and the credits pass over exactly the band they stand in.
	if _rolling:
		_menu_rect = Rect2()
		_wish_rect = Rect2()
		return
	_draw_menu_door(under, float(Style.TEXT_BODY), fade, shade)


## The way home: a box under the words, in the frame's deep brown rather than the danger's
## red.
func _draw_menu_door(under: float, height: float, fade: float, shade: Color) -> void:
	var box := Vector2(Style.measure(_home_label(), int(height)).x, height) + ONWARD_PAD * 2.0
	var top := under + height * ONWARD_DROP
	if not wishlist:
		_wish_rect = Rect2()
		_menu_rect = Rect2(Vector2((size.x - box.x) * 0.5, top), box)
		_door(_menu_rect, _home_label(), height, _menu_hot, fade, shade)
		return
	var wish := Vector2(Style.measure(Text.DEMO_WISHLIST, int(height)).x, height) + ONWARD_PAD * 2.0
	var gap := height * 1.5
	var left := (size.x - wish.x - gap - box.x) * 0.5
	_wish_rect = Rect2(Vector2(left, top), wish)
	_menu_rect = Rect2(Vector2(left + wish.x + gap, top), box)
	_door(_wish_rect, Text.DEMO_WISHLIST, height, _wish_hot, fade, shade)
	_door(_menu_rect, _home_label(), height, _menu_hot, fade, shade)


func _door(rect: Rect2, label: String, height: float, hot: bool, fade: float, shade: Color) -> void:
	var lit := 0.22 if hot else 0.12
	var face := Style.FRAME_DEEP
	Style.plaque(self, rect, Color(face.r, face.g, face.b, minf(1.0, 0.55 + lit)), fade)
	Style.write(
		self, label, int(height), Vector2(rect.position.x, rect.position.y + ONWARD_PAD.y + height * 0.82),
		Color(Style.INK.r, Style.INK.g, Style.INK.b, 1.0), HORIZONTAL_ALIGNMENT_CENTER,
		Rect2(rect.position.x, 0.0, rect.size.x, 1.0), fade
	)


## The demo's store page. The screen stays up, so the player can still take the menu door.
func open_store() -> void:
	OS.shell_open(Demo.STORE_URL)


## One line, centred, with a shadow under it. The shadow is what lets pale text sit over
## bright water without a panel behind it.
func _line(text: String, height: int, baseline: float, ink: Color, shade: Color) -> void:
	Style.write(
		self, text, height, Vector2(0.0, baseline),
		Color(ink.r, ink.g, ink.b, 1.0), HORIZONTAL_ALIGNMENT_CENTER,
		Rect2(0.0, baseline, size.x, 1.0), ink.a
	)


## The ending for the pad's stick. While the credits climb, one stop over the whole screen
## and no ring (A runs them off, as a click does); after, the doors under the words.
func pad_focus() -> Array:
	if _leaving:
		return []
	if _rolling:
		return [{"box": Rect2(Vector2.ZERO, size), "key": &"skip", "ring": false}]
	var out: Array = []
	if _wish_rect.size != Vector2.ZERO:
		out.append({"box": _wish_rect, "key": &"wish", "first": true})
	if _menu_rect.size != Vector2.ZERO:
		out.append({"box": _menu_rect, "key": &"menu", "first": _wish_rect.size == Vector2.ZERO})
	# The other answer, keep fishing, is a click anywhere off the door: a stop over the
	# closing words, so a pad-only player has both (issue #33 audit).
	var band := _message_band()
	out.append({"box": Rect2(size.x * 0.25, band.x, size.x * 0.5, band.y - band.x), "key": &"stay"})
	return out


## Escape and the pad's B: run the credits off if they are climbing, else keep fishing.
func back() -> void:
	if _rolling:
		skip_roll()
	else:
		dismiss()
