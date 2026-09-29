extends RefCounted
## The one look every menu, board and HUD panel wears: black pen ink on paper,
## with one spot colour (the default scarf's ochre) for what is lit or chosen.
## Built as a Theme in code so every Control in the game reads it; `strip` clears
## the per-node overrides older scenes carry so the theme can show through.
##
## Feedback, by rule: a button stands on a hard ink shadow; hovered, its paper
## takes the spot tint and its border thickens; pressed, the shadow goes and the
## face sinks onto where it was. Disabled is grey ink with no shadow.

const INK := Color(0.1, 0.1, 0.11)
const INK_SOFT := Color(0.38, 0.38, 0.4)
const INK_FAINT := Color(0.62, 0.62, 0.62)
const PAPER := Color(0.97, 0.95, 0.9)
const PAPER_DIM := Color(0.9, 0.88, 0.82)
## The spot colour. First guess: the default scarf's ochre.
const SPOT := Color(0.93, 0.66, 0.2)
const PAPER_LIT := Color(0.97, 0.87, 0.66)

const SHADOW := 3
const BORDER := 2

## Font sizes, a small ladder.
const TEXT_BIG := 26
const TEXT_HEAD := 18
const TEXT_BODY := 13
const TEXT_SMALL := 11

static var _theme: Theme


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = TEXT_BODY
	for type in ["Label", "Button", "OptionButton", "CheckBox", "PopupMenu", "LinkButton"]:
		t.set_color("font_color", type, INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_focus_color", "Button", INK)
	t.set_color("font_hover_pressed_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", INK_FAINT)
	for type in ["OptionButton"]:
		t.set_color("font_hover_color", type, INK)
		t.set_color("font_pressed_color", type, INK)
		t.set_color("font_focus_color", type, INK)
		t.set_color("font_disabled_color", type, INK_FAINT)
	t.set_color("font_hover_color", "PopupMenu", INK)
	t.set_color("font_disabled_color", "PopupMenu", INK_FAINT)

	t.set_stylebox("panel", "PanelContainer", panel())
	t.set_stylebox("panel", "Panel", panel())
	for type in ["Button", "OptionButton"]:
		t.set_stylebox("normal", type, button(PAPER, BORDER, SHADOW))
		t.set_stylebox("hover", type, button(PAPER_LIT, BORDER + 1, SHADOW))
		t.set_stylebox("pressed", type, _sunk(button(PAPER_DIM, BORDER + 1, 0)))
		t.set_stylebox("hover_pressed", type, _sunk(button(PAPER_LIT, BORDER + 1, 0)))
		t.set_stylebox("disabled", type, button(PAPER, 1, 0, INK_FAINT))
		t.set_stylebox("focus", type, _focus())
	# The accented door: spot face, the one lit thing on a board.
	t.set_type_variation("InkAccent", "Button")
	t.set_stylebox("normal", "InkAccent", button(SPOT, BORDER, SHADOW))
	t.set_stylebox("hover", "InkAccent", button(SPOT.lightened(0.15), BORDER + 1, SHADOW))
	t.set_stylebox("pressed", "InkAccent", _sunk(button(SPOT.darkened(0.1), BORDER + 1, 0)))

	var popup := panel()
	popup.shadow_size = 0
	t.set_stylebox("panel", "PopupMenu", popup)
	var lit := StyleBoxFlat.new()
	lit.bg_color = PAPER_LIT
	t.set_stylebox("hover", "PopupMenu", lit)

	# Sliders: an ink rule, the travel filled in spot, a round ink grabber.
	var rule := StyleBoxFlat.new()
	rule.bg_color = PAPER_DIM
	rule.border_color = INK
	rule.set_border_width_all(1)
	rule.content_margin_top = 3
	rule.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", rule)
	var fill := StyleBoxFlat.new()
	fill.bg_color = SPOT
	fill.border_color = INK
	fill.set_border_width_all(1)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _disc(9, PAPER))
	t.set_icon("grabber_highlight", "HSlider", _disc(10, PAPER_LIT))
	t.set_icon("grabber_disabled", "HSlider", _disc(9, PAPER_DIM))

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = PAPER_DIM
	bar_bg.border_color = INK
	bar_bg.set_border_width_all(1)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = INK
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	t.set_constant("separation", "HBoxContainer", 8)
	t.set_constant("separation", "VBoxContainer", 6)
	_theme = t
	return t


static func panel() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = INK
	sb.set_border_width_all(BORDER)
	sb.shadow_color = INK
	sb.shadow_offset = Vector2(4, 4)
	# a shadow of size 0 is not drawn at all; 1 is the least blur there is
	sb.shadow_size = 1
	sb.set_content_margin_all(10)
	return sb


static func button(face: Color, border: int, shadow: int, ink: Color = INK) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = face
	sb.border_color = ink
	sb.set_border_width_all(border)
	sb.shadow_color = ink
	sb.shadow_offset = Vector2(shadow, shadow)
	sb.shadow_size = 1 if shadow > 0 else 0
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	return sb


## Pressed: the face drops onto its own shadow.
static func _sunk(sb: StyleBoxFlat) -> StyleBoxFlat:
	sb.expand_margin_left = -SHADOW
	sb.expand_margin_right = SHADOW
	sb.expand_margin_top = -SHADOW
	sb.expand_margin_bottom = SHADOW
	return sb


static func _focus() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = SPOT
	sb.set_border_width_all(2)
	sb.expand_margin_left = 3
	sb.expand_margin_right = 3
	sb.expand_margin_top = 3
	sb.expand_margin_bottom = 3
	return sb


static func _disc(r: int, face: Color) -> ImageTexture:
	var size := r * 2 + 2
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d <= r - 1.5:
				img.set_pixel(x, y, face)
			elif d <= r:
				img.set_pixel(x, y, INK)
	return ImageTexture.create_from_image(img)


## Clears the stylebox, font-colour and font-size overrides older scenes set on
## their nodes, so the theme shows through. Leaves layout overrides alone.
static func strip(node: Node) -> void:
	if node is Control:
		var c := node as Control
		for key in ["panel", "normal", "hover", "pressed", "disabled", "focus", "background", "fill"]:
			c.remove_theme_stylebox_override(key)
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_outline_color"]:
			c.remove_theme_color_override(key)
		c.remove_theme_constant_override("outline_size")
	for child in node.get_children():
		strip(child)


## A label in the board's ink.
static func label(text: String, size: int = TEXT_BODY, soft: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if soft:
		l.add_theme_color_override("font_color", INK_SOFT)
	return l


## A heading: the words over an ink rule.
static func heading(text: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.add_child(label(text, TEXT_HEAD))
	var rule := ColorRect.new()
	rule.color = INK
	rule.custom_minimum_size = Vector2(0, 2)
	box.add_child(rule)
	return box
