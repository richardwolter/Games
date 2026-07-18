class_name FogOfWar
extends Node2D
## Fog of war overlay: heroes reveal the field as they explore it.
##
## Visual only — combat, targeting, and AI are untouched (GDD balance was tuned
## without vision limits). Two layers of hiding:
##   1. Terrain: a low-res "explored" grid covering the notebook page. Cells a
##      hero has ever been within vision_radius of stay revealed for the run
##      (classic RTS explored-stays-visible). Unexplored cells render as a
##      pencil-shaded grey wash (fog_of_war.gdshader) over the world.
##   2. Units: hostiles and villains are only visible while inside a living
##      hero's *current* vision bubble — explored-but-unwatched ground shows
##      terrain, not enemies.
##
## Draws at z_index 20: above the field and units, below the DeployController
## (z 40) so the deploy zone reads on top of the fog while scouting, and below
## the HUD CanvasLayer.

## How far each hero sees, in world px (provisional, see BALANCE.md).
@export var vision_radius := 400.0
## Explored-grid cell size in world px. Low res + linear filtering gives the
## soft hand-drawn fog edge; smaller cells cost more per reveal stamp.
@export var cell_size := 32.0
@export var fog_color := Color(0.36, 0.35, 0.33)
## Fog opacity over unexplored ground (<1 so the page faintly shows through,
## like heavy pencil shading rather than ink).
@export var fog_alpha := 0.88
## Softer wash over explored-but-not-currently-visible ground so it reads
## between clear (live hero vision) and full fog (unexplored).
@export var memory_alpha := 0.30
## Seconds between explored-grid reveal stamps (unit visibility is per-frame).
@export var reveal_interval := 0.15

var _field: StageField
var _img: Image
var _tex: ImageTexture
var _grid_size := Vector2i.ZERO
var _origin := Vector2.ZERO
var _reveal_cd := 0.0
# Cells stamped as currently-visible last tick, so only they need their G
# channel cleared instead of sweeping the whole grid.
var _visible_cells: Array[Vector2i] = []

func _ready() -> void:
	z_index = 20
	_field = get_tree().get_first_node_in_group("field")
	# Cover the whole notebook page (field blob + the page border that
	# StageField._draw_page uses).
	var half := _field.field_radius + _field.page_margin
	_origin = -half
	_grid_size = Vector2i((half * 2.0 / cell_size).ceil()) + Vector2i.ONE
	# R = ever explored, G = inside a hero's current vision bubble this tick.
	_img = Image.create(_grid_size.x, _grid_size.y, false, Image.FORMAT_RG8)
	_img.fill(Color.BLACK)
	_tex = ImageTexture.create_from_image(_img)

	var sprite := Sprite2D.new()
	sprite.texture = _tex
	sprite.centered = false
	sprite.position = _origin
	sprite.scale = Vector2(cell_size, cell_size)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scenes/battlefield/fog_of_war.gdshader")
	mat.set_shader_parameter("fog_color", fog_color)
	mat.set_shader_parameter("fog_alpha", fog_alpha)
	mat.set_shader_parameter("memory_alpha", memory_alpha)
	sprite.material = mat
	add_child(sprite)

	# Home base starts revealed so the deploy anchor isn't a blind spot.
	_stamp(_field.default_hero_spawn, true)
	_tex.update(_img)

func _process(delta: float) -> void:
	var heroes := _living_heroes()
	_reveal_cd -= delta
	if _reveal_cd <= 0.0:
		_reveal_cd = reveal_interval
		for cell in _visible_cells:
			_img.set_pixel(cell.x, cell.y, Color(1.0, 0.0, 0.0))
		_visible_cells.clear()
		for h in heroes:
			_stamp(h.global_position)
		_tex.update(_img)
	# Unit visibility every frame so spawned minions never flash before the
	# next reveal tick.
	var r2 := vision_radius * vision_radius
	for group in ["hostiles", "villains"]:
		for u in get_tree().get_nodes_in_group(group):
			if not is_instance_valid(u):
				continue
			var seen := false
			for h in heroes:
				if h.global_position.distance_squared_to(u.global_position) <= r2:
					seen = true
					break
			u.visible = seen

func _living_heroes() -> Array:
	var out := []
	for h in get_tree().get_nodes_in_group("heroes"):
		if is_instance_valid(h) and not h._dying:
			out.append(h)
	return out

## Mark every grid cell within vision_radius of a world point as explored (R)
## and, unless explored_only, currently visible (G).
func _stamp(world_pos: Vector2, explored_only := false) -> void:
	var c := (world_pos - _origin) / cell_size
	var r := vision_radius / cell_size
	var r2 := r * r
	var col := Color(1.0, 0.0, 0.0) if explored_only else Color(1.0, 1.0, 0.0)
	for y in range(maxi(0, int(c.y - r)), mini(_grid_size.y, int(c.y + r) + 2)):
		for x in range(maxi(0, int(c.x - r)), mini(_grid_size.x, int(c.x + r) + 2)):
			if Vector2(x + 0.5, y + 0.5).distance_squared_to(c) <= r2:
				_img.set_pixel(x, y, col)
				if not explored_only:
					_visible_cells.append(Vector2i(x, y))
