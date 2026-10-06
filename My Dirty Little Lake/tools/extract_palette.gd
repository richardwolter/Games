## Extract the master palette from Forest Isometric Pack tiles and write
## resources/palette.tres.
##
## Run with: Godot --headless --script tools/extract_palette.gd
##
## Every color except water_clean is measured from the pack: a histogram of
## non-transparent pixels per semantic group (island lawn, mainland grass,
## sand, tree trunk, leaf litter), taking the most frequent color in each
## group rather than one global top-N — grass and leaves share colors, and a
## single ranking would let one group's frequency swallow another's.
##
## The pack has no water in it at all, so water_dirty is measured (the
## darkest, muddiest color the tileset has) and water_clean is the one
## color in the whole game that is not from the pack — new, blue, and
## deliberately the only thing that reads as "not this palette", so the
## lake turning blue as it cleans reads as the reward rather than as more
## of the same ground.
extends SceneTree

const TILE_PATH := "res://assets/Forest Isometric Pack Free/Tileset/Slice %d.png"
const TREE_PATHS := [
	"res://assets/Forest Isometric Pack Free/Trees/Tree_1.png",
	"res://assets/Forest Isometric Pack Free/Trees/Tree_2.png",
	"res://assets/Forest Isometric Pack Free/Trees/Tree_3.png",
]
const LEAF_PATH := "res://assets/Forest Isometric Pack Free/Leaves/Slice %d.png"
const LEAF_COUNT := 17

const GRASS_YARD := [1, 2, 19]     # scripts/ground.gd's island lawn slices
const GRASS_ROUGH := [18, 20, 21]  # scripts/ground.gd's mainland slices
const SAND := 67

# Trunk colors within the tree sprites: brown, distinguished from the
# canopy's greens by hue rather than by picking a fixed pixel.
const TRUNK_HUE_LO := 0.02
const TRUNK_HUE_HI := 0.10

# The one color not measured from the pack. See file header.
const WATER_CLEAN := Color("#5a86ad")

# The water's ramps and the foam, authored rather than measured: water.gdshader outputs only
# these, dithering between neighbouring steps. The dirty ramp is authored round the measured
# water_dirty, so it is not re-derived if the pack's darkest tone moves — retune by hand.
const WATER_RAMPS := {
	"water_clean_deep": Color(0.173, 0.302, 0.431),
	"water_clean_mid": Color(0.255, 0.42, 0.573),
	"water_clean_shallow": Color(0.498, 0.655, 0.776),
	"water_clean_light": Color(0.769, 0.859, 0.91),
	"water_dirty_deep": Color(0.071, 0.18, 0.055),
	"water_dirty_mid": Color(0.094, 0.227, 0.067),
	"water_dirty_shallow": Color(0.227, 0.353, 0.141),
	"water_dirty_light": Color(0.369, 0.435, 0.227),
	"water_murky_deep": Color(0.11, 0.24, 0.24),
	"water_murky_mid": Color(0.16, 0.32, 0.31),
	"water_murky": Color(0.22, 0.4, 0.38),
	"water_murky_shallow": Color(0.34, 0.5, 0.45),
	"water_murky_light": Color(0.55, 0.66, 0.58),
	# The two in-between states (2026-09-17): hazy between clean and murky, foul between
	# murky and dirty. First guesses at the midpoints of their neighbours — retune by eye.
	"water_hazy_deep": Color(0.142, 0.271, 0.336),
	"water_hazy_mid": Color(0.208, 0.37, 0.442),
	"water_hazy": Color(0.287, 0.463, 0.529),
	"water_hazy_shallow": Color(0.419, 0.578, 0.613),
	"water_hazy_light": Color(0.66, 0.76, 0.745),
	"water_foul_deep": Color(0.091, 0.21, 0.148),
	"water_foul_mid": Color(0.127, 0.274, 0.189),
	"water_foul": Color(0.169, 0.338, 0.231),
	"water_foul_shallow": Color(0.284, 0.427, 0.296),
	"water_foul_light": Color(0.46, 0.548, 0.404),
	"foam": Color(0.933, 0.965, 0.984),
	"foam_light": Color(1.0, 1.0, 1.0),
	"foam_dirty": Color(0.8, 0.82, 0.678),
	# The wash room's sky (2026-09-19): high step over low, at the day's three hours. First
	# guesses — retune by eye on tools/last_wash_room.png.
	"sky_morning_high": Color(0.62, 0.78, 0.88),
	"sky_morning_low": Color(0.86, 0.88, 0.8),
	"sky_noon_high": Color(0.49, 0.72, 0.9),
	"sky_noon_low": Color(0.72, 0.86, 0.94),
	"sky_afternoon_high": Color(0.58, 0.66, 0.8),
	"sky_afternoon_low": Color(0.93, 0.8, 0.62),
}

const OUTPUT_PATH := "res://resources/palette.tres"


func _init() -> void:
	print("=== Palette Extractor ===")

	var grass_light := _top_color(_tile_paths(GRASS_YARD))
	var grass_dark := _top_color(_tile_paths(GRASS_ROUGH))
	var sand := _top_color(_tile_paths([SAND]))
	var wood := _top_trunk_color(TREE_PATHS)
	var leaf := _top_color(_leaf_paths())
	var water_dirty := _darkest_color(_tile_paths(range(1, 68)))

	var ui_neutral := grass_light
	var ui_accent := wood

	print("\nMeasured from pack:")
	print("  grass_light: %s (island lawn, slices %s)" % [grass_light.to_html(false), GRASS_YARD])
	print("  grass_dark:  %s (mainland, slices %s)" % [grass_dark.to_html(false), GRASS_ROUGH])
	print("  sand:        %s (slice %d)" % [sand.to_html(false), SAND])
	print("  wood:        %s (tree trunks)" % wood.to_html(false))
	print("  leaf:        %s (leaf litter)" % leaf.to_html(false))
	print("  water_dirty: %s (darkest tone in tileset)" % water_dirty.to_html(false))
	print("\nNot from pack (see file header):")
	print("  water_clean: %s" % WATER_CLEAN.to_html(false))

	var colors := {
		"grass_light": grass_light,
		"grass_dark": grass_dark,
		"sand": sand,
		"wood": wood,
		"leaf": leaf,
		"water_dirty": water_dirty,
		"water_clean": WATER_CLEAN,
	}
	colors.merge(WATER_RAMPS)
	colors["ui_neutral"] = ui_neutral
	colors["ui_accent"] = ui_accent
	_write_resource(colors)
	quit()


func _tile_paths(slices) -> Array:
	var out: Array = []
	for s in slices:
		out.append(TILE_PATH % int(s))
	return out


func _leaf_paths() -> Array:
	var out: Array = []
	for i in range(1, LEAF_COUNT + 1):
		out.append(LEAF_PATH % i)
	return out


## Histogram of non-transparent pixels across a set of textures.
func _histogram(paths: Array) -> Dictionary:
	var hist := {}
	for p in paths:
		var tex := load(p) as Texture2D
		if tex == null:
			continue
		var img := tex.get_image()
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a < 0.5:
					continue
				var key := c.to_html(false)
				hist[key] = hist.get(key, 0) + 1
	return hist


func _top_color(paths: Array) -> Color:
	var hist := _histogram(paths)
	var best := ""
	var best_n := -1
	for k in hist:
		if hist[k] > best_n:
			best_n = hist[k]
			best = k
	return Color(best) if best != "" else Color.WHITE


## The most frequent color whose hue falls in the trunk's brown range,
## rather than the canopy's green.
func _top_trunk_color(paths: Array) -> Color:
	var hist := _histogram(paths)
	var best := ""
	var best_n := -1
	for k in hist:
		var c := Color(k)
		if c.h >= TRUNK_HUE_LO and c.h <= TRUNK_HUE_HI and hist[k] > best_n:
			best_n = hist[k]
			best = k
	return Color(best) if best != "" else Color.WHITE


func _darkest_color(paths: Array) -> Color:
	var hist := _histogram(paths)
	var darkest := Color.WHITE
	var darkest_v := 2.0
	for k in hist:
		var c := Color(k)
		if c.v < darkest_v:
			darkest_v = c.v
			darkest = c
	return darkest


func _write_resource(colors: Dictionary) -> void:
	var lines := [
		'[gd_resource type="Resource" script_class="Palette" load_steps=2 format=3]',
		'',
		'[ext_resource type="Script" path="res://scripts/palette.gd" id="1_palette"]',
		'',
		'[resource]',
		'script = ExtResource("1_palette")',
	]
	for name in colors:
		var c: Color = colors[name]
		lines.append("%s = Color(%s, %s, %s, 1)" % [
			name,
			String.num(c.r, 3), String.num(c.g, 3), String.num(c.b, 3)
		])
	var f := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("\n✓ Wrote %s" % OUTPUT_PATH)
