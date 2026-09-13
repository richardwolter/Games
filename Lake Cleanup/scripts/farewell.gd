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
class_name Farewell
extends Control

## The words. Two lines because they are two thoughts: what the player did, and goodbye.
const LINES := [
	"You have cleaned your lake and can now live in peace.",
	"Thanks for playing!",
]

## And under them, the door out of the peace. Only drawn when the screen is given one — the
## end of the last level is still an end, and should not be a corridor.
const ONWARD_HINT := "Something is stirring in the water."
const ONWARD_LABEL := "Face it"

## The padding around the door's label. Its text size comes off the shared ladder.
const ONWARD_PAD := Vector2(34.0, 16.0)
## How far below the second line the door sits, as a multiple of its own text size.
const ONWARD_DROP := 3.2

const Style := preload("res://scripts/style.gd")

## How long the words take to arrive, and how long they take to go once dismissed. Slow in,
## because it is the end of a long job and the end of a long job is not a pop-up; quicker
## out, because by then the player has decided.
const FADE_IN := 1.6
const FADE_OUT := 0.5

## Nothing may be dismissed for this long. A player whose last catch happened under the
## cursor would otherwise click the screen away before reading a word of it.
const SETTLE := 0.6

## The gap between the lines, as a fraction of the first one's size. The sizes themselves
## come off the shared ladder.
const GAP := 1.5

## How dark the lake goes behind the words. Enough to read against, nowhere near enough to
## hide what the player has just finished — the sparkle is the other half of this ending.
const WASH := Style.SCRIM

## Emitted once the screen has faded out and is on its way to being freed, so the lake can
## give the angler their legs back.
signal dismissed

## Emitted when the player takes the door onward instead of closing the screen. The lake
## does the scene change; this only says which of the two was clicked.
signal onward

## Emitted when the player takes the door back to the main menu (2026-09-12). Always
## drawn: a finished lake has to lead somewhere, and clicking the words away to keep
## fishing an empty lake is the other choice, not the only one.
signal to_menu

const MENU_LABEL := "Back to menu"

## The words actually shown. Defaults to LINES, and is set to something else by a level
## whose ending is not the cleaned lake.
var lines: Array = LINES

var _font: Font
## 0 to 1 on the way in, and back to 0 on the way out.
var _shown: float = 0.0
var _leaving: bool = false
var _age: float = 0.0
## Whether there is anywhere to go on to, and where the button was last drawn so a click
## can be tested against the same rectangle the player was looking at.
var _has_onward: bool = false
var _onward_rect := Rect2()
var _onward_hot: bool = false
var _menu_rect := Rect2()
var _menu_hot: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	_font = Style.font()
	# Sized by hand rather than by anchors: the parent is a CanvasLayer, and a Control whose
	# parent is not a Control is not laid out by anyone. It has to keep up with the window
	# itself.
	_fill()
	get_viewport().size_changed.connect(_fill)


## Cover the window, whatever shape it currently is.
func _fill() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func _process(delta: float) -> void:
	_age += delta
	var rate := 1.0 / (FADE_OUT if _leaving else FADE_IN)
	_shown = move_toward(_shown, 0.0 if _leaving else 1.0, rate * delta)
	queue_redraw()
	if _leaving and _shown <= 0.0:
		set_process(false)
		# The layer it was given is its own, so it takes that with it.
		var over := get_parent()
		if over is CanvasLayer:
			over.queue_free()
		else:
			queue_free()


## Offer the way on. Called before the screen is added to the tree.
func offer_onward() -> void:
	_has_onward = true
	mouse_default_cursor_shape = Control.CURSOR_ARROW


## The player has taken the door. Fades the same way a dismissal does, so the words leave
## the lake rather than being cut off it, and the lake changes scene when they have.
func take_onward() -> void:
	if _leaving or _age < SETTLE:
		return
	_leaving = true
	onward.emit()


## The player has taken the door home. Fades out like the others; the lake changes scene.
func take_menu() -> void:
	if _leaving or _age < SETTLE:
		return
	_leaving = true
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
		var over := _has_onward and _onward_rect.has_point(moved.position)
		var home := _menu_rect.has_point(moved.position)
		if over != _onward_hot or home != _menu_hot:
			_onward_hot = over
			_menu_hot = home
			queue_redraw()
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	# The door is a rectangle inside the screen, and the screen is dismissed by clicking
	# anywhere else on it. Testing the door first is what keeps the two apart.
	if _has_onward and _onward_rect.has_point(click.position):
		take_onward()
		return
	if _menu_rect.has_point(click.position):
		take_menu()
		return
	dismiss()


func _draw() -> void:
	if _font == null or _shown <= 0.0:
		return
	# Eased so the words do not arrive at a constant rate, which reads as a machine doing
	# it. In fast, then a long settle.
	var fade := 1.0 - pow(1.0 - _shown, 3.0)
	Style.dim(self, Rect2(Vector2.ZERO, size), WASH, fade)

	var first := float(Style.TEXT_TITLE)
	var second := float(Style.TEXT_HEAD)
	var ink := Color(Style.INK.r, Style.INK.g, Style.INK.b, fade)
	var shade := Color(Style.SHADE.r, Style.SHADE.g, Style.SHADE.b, Style.SHADE.a * fade)

	# The pair is centred as a block rather than each line on its own row, so the gap
	# between them belongs to the words and not to the window.
	var block := first + first * GAP
	# A little below the middle, because the middle is where the island is and the island is
	# the thing the sentence is about. The words sit on open water under it.
	var top := size.y * 0.60 - block * 0.5
	# Lifted a little as it arrives: the words settle onto the lake rather than appearing
	# on it.
	top += (1.0 - fade) * size.y * 0.03
	_line(String(lines[0]), int(first), top + first, ink, shade)
	var second_baseline := top + first + first * GAP
	_line(String(lines[1]), int(second), second_baseline, ink, shade)
	var under := second_baseline
	if _has_onward:
		_draw_onward(under, float(Style.TEXT_BODY), fade, shade)
		under = _onward_rect.end.y
	_draw_menu_door(under, float(Style.TEXT_BODY), fade, shade)


## The way home: a box under the words, in the frame's deep brown rather than the danger's
## red. Set the same way the onward door is, so the two are one kind of thing when both
## show.
func _draw_menu_door(under: float, height: float, fade: float, shade: Color) -> void:
	var wide := Style.measure(MENU_LABEL, int(height)).x
	var box := Vector2(wide, height) + ONWARD_PAD * 2.0
	_menu_rect = Rect2(Vector2((size.x - box.x) * 0.5, under + height * ONWARD_DROP), box)
	var lit := 0.22 if _menu_hot else 0.12
	var face := Style.FRAME_DEEP
	Style.plaque(self, _menu_rect, Color(face.r, face.g, face.b, minf(1.0, 0.55 + lit)), fade)
	_line(
		MENU_LABEL, int(height),
		_menu_rect.position.y + ONWARD_PAD.y + height * 0.82,
		Color(Style.INK.r, Style.INK.g, Style.INK.b, fade), shade
	)


## The way on: a line of warning, and a box under it to click. Drawn rather than built from
## a Button for the same reason the rest of this screen is — one screen from a different
## game is one too many.
func _draw_onward(under: float, height: float, fade: float, shade: Color) -> void:
	var warn := Color(Style.GOLD.r, Style.GOLD.g, Style.GOLD.b, fade * 0.9)
	_line(ONWARD_HINT, int(height), under + height * 1.9, warn, shade)

	var wide := Style.measure(ONWARD_LABEL, int(height)).x
	var box := Vector2(wide, height) + ONWARD_PAD * 2.0
	_onward_rect = Rect2(
		Vector2((size.x - box.x) * 0.5, under + height * ONWARD_DROP), box
	)
	var lit := 0.22 if _onward_hot else 0.12
	var face := Style.DANGER.darkened(0.5)
	Style.plaque(self, _onward_rect, Color(face.r, face.g, face.b, minf(1.0, 0.55 + lit)), fade)
	_line(
		ONWARD_LABEL, int(height),
		_onward_rect.position.y + ONWARD_PAD.y + height * 0.82,
		Color(Style.INK.r, Style.INK.g, Style.INK.b, fade), shade
	)


## One line, centred, with a shadow under it. The shadow is what lets pale text sit over
## bright water without a panel behind it.
func _line(text: String, height: int, baseline: float, ink: Color, shade: Color) -> void:
	Style.write(
		self, text, height, Vector2(0.0, baseline),
		Color(ink.r, ink.g, ink.b, 1.0), HORIZONTAL_ALIGNMENT_CENTER,
		Rect2(0.0, baseline, size.x, 1.0), ink.a
	)
