## The water pump beside the hut: where a find is washed before it can go in the shed.
##
## Issue #37 (`/grill-me` with Richard, 2026-09-18). A front-on painting on the island's
## lawn, the third after the hut and the crate, and dressed the way they are: blades along
## its bottom line (`Skirt.hem`) and a shadow swept off its silhouette (`Shade.Cast`), for
## the reasons written down at both. The picture is `tools/build_pump.py`'s.
##
## **It is the third thing on the island a walker goes round**, and the first the walkers
## find for themselves: where it stands is a static here (`tile`), the way `Dog.pack` and
## `Dog.claims` are, because it is a fact about the lake and not about any one walker.
## `covers` is the crate's own rule — a square in tile space, so its faces are tile axes and
## a walker slides along one. With no pump in the tree nothing is covered.
class_name Pump
extends Node2D

const ART := "res://assets/pump.png"
const CONTRACT := "res://assets/pump.json"

## World pixels to a painted one: the lake's own sprite scale, a whole art pixel.
const ART_SCALE := 2.0
## Half the square it stands on, in tiles, and how much wider a pair of boots keeps off it.
const FOOT_HALF := 0.32
const WALK_KEEP := 0.12
const SKIRT_SEED := 3707
const SKIRT_BLADES := Vector2i(1, 2)

## Where the pump stands, in tiles, or INF when there is none.
static var tile := Vector2.INF

var day: DayCycle
## The angler is close enough to work it: the hut's own lamp, over the pump instead.
var lit := false

var _art: Texture2D
var _ground := 0.1
var _skirt: Skirt.Patch
var _cast: Shade.Cast


## Whether a tile-space point is on the pump's square, grown by `grow`.
static func covers(at: Vector2, grow: float = 0.0) -> bool:
	if tile == Vector2.INF:
		return false
	var off := at - tile
	return absf(off.x) < FOOT_HALF + grow and absf(off.y) < FOOT_HALF + grow


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art = Art.texture(ART)
	var text := FileAccess.get_file_as_string(CONTRACT)
	var contract: Variant = JSON.parse_string(text) if not text.is_empty() else null
	if contract is Dictionary:
		_ground = float((contract as Dictionary).get("ground", _ground))


func _exit_tree() -> void:
	tile = Vector2.INF


func _process(_delta: float) -> void:
	# The sun moves; the shadow is only re-laid when it has stepped (`Shade.SWEEP_STEP`).
	if day != null:
		queue_redraw()


## How wide the picture is drawn, in world pixels. What a walker has to be inside to count
## as behind it.
func drawn_wide() -> float:
	if _art == null:
		return FOOT_HALF * 2.0 * Iso.TILE_W
	return _art.get_size().x * ART_SCALE


func _box() -> Rect2:
	var size := _art.get_size() * ART_SCALE
	return Rect2(Vector2(-size.x * 0.5, -size.y * (1.0 - _ground)), size)


func _draw() -> void:
	if _art == null:
		# No picture: a post, so there is still something to walk up to.
		draw_rect(Rect2(-5.0, -34.0, 10.0, 34.0), Color(0.25, 0.3, 0.33))
		return
	var box := _box()
	if day != null:
		if _cast == null:
			_cast = Shade.Cast.new()
			_cast.name = &"PumpShade"
			add_child(_cast)
		_cast.lay(Art.image(ART), box, day.lean, day.stretch, _ground, day.ink)
	draw_texture_rect(_art, box, false)
	if _skirt == null:
		_skirt = Skirt.hem(Art.image(ART), box, SKIRT_SEED, PackedVector2Array(), SKIRT_BLADES)
	_skirt.over(self)
	if lit:
		var over := Vector2(0.0, box.position.y - 10.0)
		draw_circle(over, 7.0, Color(1.0, 0.92, 0.62, 0.9))
		draw_circle(over, 12.0, Color(1.0, 0.92, 0.62, 0.25))
