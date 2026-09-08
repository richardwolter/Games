## Master palette extracted from Forest Isometric Pack.
##
## Single source of truth for all visual color decisions: water, UI, asset
## recoloring, floor, everything. Populated by tools/extract_palette.gd.
class_name Palette
extends Resource

## Named colors. Keys are semantic (e.g. "grass_dark", "water_clean", "sand"),
## values are Color objects. Populated from tile histogram at generation time.
var colors: Dictionary = {}

## Raw histogram of all pixels in the pack (color -> count). Sorted by frequency.
var histogram: Dictionary = {}

## Dominant grass color (most frequent from grass tiles).
@export var grass_light: Color = Color.WHITE
@export var grass_dark: Color = Color.WHITE

## Sand color (from sand tiles).
@export var sand: Color = Color.WHITE

## Water colors: dirty (pollution=1.0) and clean (pollution=0.0).
@export var water_dirty: Color = Color.WHITE
@export var water_clean: Color = Color.WHITE

## Wood/tree colors.
@export var wood: Color = Color.WHITE

## Leaf/undergrowth color.
@export var leaf: Color = Color.WHITE

## UI neutral (used for buttons, frames, text backgrounds).
@export var ui_neutral: Color = Color.WHITE
@export var ui_accent: Color = Color.WHITE



## Get a named color from the palette.
func get_color(name: String) -> Color:
	return colors.get(name, Color.WHITE)


## Set a named color.
func set_color(name: String, color: Color) -> void:
	colors[name] = color
