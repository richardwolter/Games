## Master palette extracted from Forest Isometric Pack.
##
## Single source of truth for all visual color decisions: water, UI, asset
## recoloring, floor, everything. Populated by tools/extract_palette.gd.
class_name Palette
extends Resource

const PATH := "res://resources/palette.tres"

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

## Water colors: dirty (pollution=1.0) and clean (pollution=0.0). Each is the middle step of
## its ramp below.
@export var water_dirty: Color = Color.WHITE
@export var water_clean: Color = Color.WHITE

## The water's ramps, deepest to lightest. water.gdshader outputs only these: a depth, band or
## glint value picks a step, and in-between values are dithered between two neighbouring steps
## rather than blended. The clean ramp is authored round water_clean; the dirty one round the
## measured water_dirty, its top steps doubling as the scum film.
@export var water_clean_deep: Color = Color.WHITE
@export var water_clean_mid: Color = Color.WHITE
@export var water_clean_shallow: Color = Color.WHITE
@export var water_clean_light: Color = Color.WHITE
@export var water_dirty_deep: Color = Color.WHITE
@export var water_dirty_mid: Color = Color.WHITE
@export var water_dirty_shallow: Color = Color.WHITE
@export var water_dirty_light: Color = Color.WHITE
## The murky state between them: a bay part-way cleaned.
@export var water_murky_deep: Color = Color.WHITE
@export var water_murky_mid: Color = Color.WHITE
@export var water_murky: Color = Color.WHITE
@export var water_murky_shallow: Color = Color.WHITE
@export var water_murky_light: Color = Color.WHITE
## The two states between those three: hazy (clean to murky) and foul (murky to dirty), so a
## bay lightens a shade at a time as its stacks come up rather than in two jumps.
@export var water_hazy_deep: Color = Color.WHITE
@export var water_hazy_mid: Color = Color.WHITE
@export var water_hazy: Color = Color.WHITE
@export var water_hazy_shallow: Color = Color.WHITE
@export var water_hazy_light: Color = Color.WHITE
@export var water_foul_deep: Color = Color.WHITE
@export var water_foul_mid: Color = Color.WHITE
@export var water_foul: Color = Color.WHITE
@export var water_foul_shallow: Color = Color.WHITE
@export var water_foul_light: Color = Color.WHITE

## Foam: the body, its bright bubble cores, and what foam on filthy water goes to.
@export var foam: Color = Color.WHITE
@export var foam_light: Color = Color.WHITE
@export var foam_dirty: Color = Color.WHITE

## Wood/tree colors.
@export var wood: Color = Color.WHITE

## Leaf/undergrowth color.
@export var leaf: Color = Color.WHITE

## UI neutral (used for buttons, frames, text backgrounds).
@export var ui_neutral: Color = Color.WHITE
@export var ui_accent: Color = Color.WHITE


## The master palette, or null if the file is missing.
static func master() -> Palette:
	return load(PATH) as Palette


## Give a foam material (foam.gdshader, hull_foam.gdshader) the palette's foam swatches,
## keeping the alpha the caller chose — that alpha is how much of the foam is dithered in.
## Leaves the material alone if the palette file is missing.
static func dress_foam(material: ShaderMaterial, alpha: float) -> void:
	var palette := master()
	if palette == null:
		return
	var body := palette.foam
	body.a = alpha
	material.set_shader_parameter(&"foam", body)
	material.set_shader_parameter(&"foam_core", palette.foam_light)


## Get a named color from the palette.
func get_color(name: String) -> Color:
	return colors.get(name, Color.WHITE)


## Set a named color.
func set_color(name: String, color: Color) -> void:
	colors[name] = color
