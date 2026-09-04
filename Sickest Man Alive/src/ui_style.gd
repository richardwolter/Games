class_name UIStyle
extends Object

## The look of the menus, in one place.
##
## The game itself has no theme and no font asset -- the HUD is hand-placed
## Labels and everything else is drawn in `_draw`. Rather than introduce a Theme
## resource for two screens, this is a set of factory functions: the prep menu
## and the results panel both build their widgets through here, so they cannot
## drift apart, and there is exactly one place to change when the game does get
## a proper font.

const BG: Color = Color(0.07, 0.05, 0.07)
const PANEL: Color = Color(0.13, 0.10, 0.13)
const BORDER: Color = Color(0.42, 0.25, 0.32)
const INK: Color = Color(0.94, 0.92, 0.93)
const DIM: Color = Color(0.62, 0.58, 0.62)
## DNA is the one thing on these screens that is a number you care about, so it
## gets the one colour nothing else uses -- the same green the motes are drawn in.
const DNA: Color = Color(0.62, 1.0, 0.78)
const DANGER: Color = Color(0.92, 0.42, 0.38)

const SIZE_TITLE: int = 44
const SIZE_HEAD: int = 26
const SIZE_BODY: int = 18
const SIZE_SMALL: int = 15

const PAD: int = 12


static func label(text: String, size: int = SIZE_BODY, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func wrapped(text: String, size: int = SIZE_SMALL, color: Color = DIM) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func button(text: String, on_press: Callable, size: int = SIZE_BODY) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_ALL
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b


## A bordered card. Used for the results box and for every item row, so the two
## screens read as the same object at different sizes.
static func panel(bg: Color = PANEL, border: Color = BORDER, pad: int = PAD) -> PanelContainer:
	var p := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	box.content_margin_left = pad
	box.content_margin_right = pad
	box.content_margin_top = pad
	box.content_margin_bottom = pad
	p.add_theme_stylebox_override("panel", box)
	return p


static func spacer(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0.0, float(height))
	return c


## Fills the whole parent with the background colour. Every screen needs one, and
## without it the menus render over whatever the previous scene left behind.
static func backdrop(color: Color = BG) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
