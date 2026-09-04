## The full title lockup: STRAIT / ACROSS in outlined slab type, sitting above a
## bridge of real game sprites with the car halfway across it.
##
## The bridge is built from the actual art/*.png the shop sells, not a drawing of
## them — so the logo is always made of pieces the player will recognise, and it
## can never drift from the art style, because it *is* the art.
##
## Everything scales from `unit`, so the same node serves the title screen at
## full size and anywhere else (a pause overlay, a level-complete card) small.
@tool
class_name LogoTitle
extends Control

## Cap height of the word STRAIT. Every other measurement is a multiple.
@export var unit: float = 78.0:
	set(value):
		unit = value
		_relayout()

## The pieces the bridge is drawn from, left to right, as
## [texture path, width in units, height in units, vertical offset in units].
## Deliberately mismatched — a tidy row of identical planks would sell the wrong
## game.
const SPAN := [
	["res://art/plank.png", 1.9, 0.20, 0.06],
	["res://art/crate.png", 0.62, 0.62, 0.00],
	["res://art/tire.png", 0.50, 0.50, 0.10],
	["res://art/barrel.png", 0.55, 0.55, -0.02],
	["res://art/beam.png", 2.1, 0.22, 0.08],
]

var _strait: Label
var _across: Label
var _car: TextureRect
var _pieces: Array[TextureRect] = []


func _ready() -> void:
	if _strait == null:
		_build()
	_relayout()


func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	for entry: Array in SPAN:
		var piece := TextureRect.new()
		piece.texture = load(entry[0]) as Texture2D
		piece.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		piece.stretch_mode = TextureRect.STRETCH_SCALE
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(piece)
		_pieces.append(piece)

	_car = TextureRect.new()
	_car.texture = load("res://art/car.png") as Texture2D
	_car.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_car.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_car.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_car)

	# The type goes on last so it sits over the car, which is what makes the
	# lockup read as one object instead of a caption above a picture.
	_strait = _word("STRAIT", UITheme.MUSTARD)
	_across = _word("ACROSS", UITheme.CREAM)


func _word(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", UITheme.INK)
	add_child(label)
	return label


func _relayout() -> void:
	if _strait == null:
		return
	var width := unit * 6.4
	custom_minimum_size = Vector2(width, unit * 3.4)

	# The sprites sit behind and below the words: the bridge line runs across the
	# lower third, the car rides on it, the words cover the upper two thirds.
	var deck := unit * 2.5
	var x := 0.0
	for i in _pieces.size():
		var entry: Array = SPAN[i]
		var size := Vector2(unit * entry[1], unit * entry[2])
		_pieces[i].size = size
		_pieces[i].position = Vector2(x, deck + unit * entry[3])
		x += size.x * 0.92

	# One pass to centre the span, now that its true width is known.
	var offset := (width - x) * 0.5
	for piece: TextureRect in _pieces:
		piece.position.x += offset

	var car_width := unit * 1.5
	_car.size = Vector2(car_width, car_width * 0.5)
	_car.position = Vector2((width - car_width) * 0.5, deck - unit * 0.46)

	_set_word(_strait, unit, 0.0, unit * 0.10)
	_set_word(_across, unit * 0.62, unit * 1.12, unit * 0.24)


func _set_word(label: Label, size: float, y: float, spacing: float) -> void:
	label.add_theme_font_size_override(&"font_size", roundi(size))
	# The outline is what gives the default font the sticker weight the sprites
	# have. It scales with the type or it stops matching at small sizes.
	label.add_theme_constant_override(&"outline_size", maxi(roundi(size * 0.18), 2))
	label.add_theme_constant_override(&"font_spacing_glyph", roundi(spacing))
	label.position = Vector2(0, y)
	label.size = Vector2(custom_minimum_size.x, size * 1.3)
