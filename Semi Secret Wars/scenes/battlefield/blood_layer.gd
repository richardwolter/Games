class_name BloodLayer
extends Node2D
## Permanent bloodstains where minions die, baked into
## a persistent per-level image on disk (same load/bake/save pattern as
## FogOfWar's explored-terrain grid) so the battlefield reads bloodier with
## every run instead of resetting clean each time. Individual death-splash
## nodes (Combatant._spawn_ground_splash) still fade as before — this is a
## separate, permanent layer underneath them.
##
## Drawn as a plain alpha-blended Sprite2D (no shader needed, unlike fog's two-
## channel wash) — placed as "Field"'s next sibling in battlefield.tscn so
## tree order alone puts it above the lane floor and below spawned units.

@export var stain_radius := 16.0
@export var stain_alpha := 0.4
@export var stain_color := Color(0.42, 0.03, 0.03)
## Resolution of the baked stain image — finer than fog's 32px cells since
## individual stains are small and want a soft round edge.
@export var cell_size := 8.0

var _field: LaneField
var _img: Image
var _tex: ImageTexture
var _origin := Vector2.ZERO
var _grid_size := Vector2i.ZERO
var _dirty := false

func _ready() -> void:
	add_to_group("blood")
	_field = get_tree().get_first_node_in_group("field") as LaneField
	if _field == null:
		return
	var half := _field.field_radius
	_origin = -half
	_grid_size = Vector2i((half * 2.0 / cell_size).ceil()) + Vector2i.ONE
	_img = Image.create(_grid_size.x, _grid_size.y, false, Image.FORMAT_RGBA8)
	_img.fill(Color(0.0, 0.0, 0.0, 0.0))
	_load()
	_tex = ImageTexture.create_from_image(_img)

	var sprite := Sprite2D.new()
	sprite.texture = _tex
	sprite.centered = false
	sprite.position = _origin
	sprite.scale = Vector2(cell_size, cell_size)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(sprite)

func _process(_delta: float) -> void:
	if _dirty:
		_tex.update(_img)
		_dirty = false

## Stamps a bloodstain at `world_pos`, alpha-blended onto whatever's already
## there so overlapping deaths darken/pool instead of just overwriting.
##
## Ink-on-paper look (2026-07-24): a single perfectly circular soft-gradient
## stain reads as a digital glow rather than ink soaking into paper. Instead,
## layer a handful of smaller overlapping lobes offset around world_pos (an
## irregular blot silhouette) plus a few tiny satellite speckles flicked
## further out (spatter), each with a harder falloff than a plain linear ramp.
func stain(world_pos: Vector2) -> void:
	if _img == null:
		return
	var lobes := randi_range(4, 6)
	for i in lobes:
		var ang := randf() * TAU
		var dist := randf_range(0.0, stain_radius * 0.35)
		var lobe_center := world_pos + Vector2(cos(ang), sin(ang)) * dist
		var lobe_r := stain_radius * randf_range(0.55, 0.9)
		_stamp_blob(lobe_center, lobe_r, stain_alpha)
	var speckles := randi_range(3, 6)
	for i in speckles:
		var ang := randf() * TAU
		var dist := stain_radius * randf_range(0.8, 2.2)
		var speck_center := world_pos + Vector2(cos(ang), sin(ang)) * dist
		var speck_r := stain_radius * randf_range(0.08, 0.22)
		_stamp_blob(speck_center, speck_r, stain_alpha * randf_range(0.5, 0.85))
	_dirty = true

## Stamps one round lobe into the baked image with a squared (harder-edged)
## falloff — steeper than a linear ramp so the edge reads as an ink boundary
## rather than a soft gradient blur.
func _stamp_blob(center: Vector2, radius: float, alpha: float) -> void:
	var c := (center - _origin) / cell_size
	var r := radius / cell_size
	var r2 := r * r
	for y in range(maxi(0, int(c.y - r)), mini(_grid_size.y, int(c.y + r) + 2)):
		for x in range(maxi(0, int(c.x - r)), mini(_grid_size.x, int(c.x + r) + 2)):
			var d2: float = Vector2(x + 0.5, y + 0.5).distance_squared_to(c)
			if d2 <= r2:
				var t := 1.0 - sqrt(d2) / r
				var falloff := t * t
				var new_col := Color(stain_color.r, stain_color.g, stain_color.b, alpha * falloff)
				_img.set_pixel(x, y, _img.get_pixel(x, y).blend(new_col))

## -- Persistence (per level, accumulates forever — see FogOfWar for the pattern) --

const BLOOD_DIR := "user://blood_v2"

func _blood_path() -> String:
	return "%s/level_%d.png" % [BLOOD_DIR, RunState.current_level]

func _load() -> void:
	if RunState.headless:
		return
	var path := _blood_path()
	if not FileAccess.file_exists(path):
		return
	var saved := Image.load_from_file(path)
	if saved == null or saved.get_size() != _img.get_size():
		return
	_img = saved

## Called by BattleManager at battle end so accumulated stains survive
## into the next visit to this level, forever (not just this run).
func save() -> void:
	if RunState.headless or _img == null:
		return
	DirAccess.make_dir_recursive_absolute(BLOOD_DIR)
	_img.save_png(_blood_path())
