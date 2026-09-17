## The pollution meter with nothing on its end: the wooden frame and the water in it, and no
## garbage circle, no figure. The loading screen's bar (2026-09-17, Richard: "bring the
## loading meter anyways, without the garbage and circle, just the bar").
##
## The HUD's meter, not a drawing of it: the same two water sheets, the same
## `meter_water.gdshader` through `HudSkin.meter_material`, the same built frame
## (`HudSkin.MeterFrame`, `Style.meter_frame`), read off the same `METER_*` rectangles. What
## differs is what is shown of the sheet. The HUD lays the whole 290x94 sheet down and caps
## its left end with the circle; this node is **the frame's own box and clips to it**, with
## the sheet hung behind so that box lands on the node. The water band the shader runs on
## under the circle (`leak`) is cut off by the clip, and the frame's left wall — mirrored
## from its right, since that end was never painted — covers where the band starts.
##
## **It fills the way the game's meter does, right to left, by Richard's call**: it starts
## green and the clean water comes in from the right, the seam sliding left, "just like in
## the game". A mirrored bar filling left to right like a stock loading bar was built first
## and turned down — this is the lake's meter, and it cleans the way the lake's meter cleans.
## The shader's seam is where the *filth* ends, so it is handed `1 - share`: handed the clean
## share straight, the very first cut swept from clean to filthy and the splash showed a
## clean bar.
##
## `wide` sets the size; the height follows from the frame's own proportions.
class_name MeterBar
extends Control

const SHADER := "res://shaders/meter_water.gdshader"

## How much of the track is clean, 0 filthy to 1 clean, the clean water growing from the
## right as it does on the HUD.
var share: float = 0.0:
	set(to):
		share = clampf(to, 0.0, 1.0)
		if _material != null:
			HudSkin.meter_seam(_material, 1.0 - share)

## How wide the bar is drawn, in the parent's pixels.
var wide: float = 420.0:
	set(to):
		wide = to
		if is_node_ready():
			_lay_out()

var _water: TextureRect
var _frame: HudSkin.MeterFrame
var _material: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	var murky := Art.texture(HudSkin.METER_ART + "Murky_Water.png")
	var clean := Art.texture(HudSkin.METER_ART + "Clean_Water.png")
	var shader := load(SHADER) as Shader
	if murky != null and clean != null and shader != null:
		_material = HudSkin.meter_material(shader, clean)
		_water = TextureRect.new()
		_water.name = &"Water"
		_water.texture = murky
		_water.material = _material
		_water.stretch_mode = TextureRect.STRETCH_SCALE
		_water.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_water.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_water.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_water)
		HudSkin.meter_seam(_material, 1.0 - share)
	_frame = HudSkin.MeterFrame.new()
	_frame.name = &"Frame"
	_frame.sheet = Art.texture(HudSkin.METER_ART + "Meter_Border.png")
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_lay_out()


## Where the shader has been told the filth ends, as a fraction of the sheet: for the
## harness, which cannot look at a picture.
func seam() -> float:
	return -1.0 if _material == null else float(_material.get_shader_parameter(&"seam"))


## The size the bar comes out at `wide`: the frame's own proportions.
func box() -> Vector2:
	var scale := wide / HudSkin.METER_FRAME.size.x
	return (HudSkin.METER_FRAME.size * scale).floor()


func _lay_out() -> void:
	var scale := wide / HudSkin.METER_FRAME.size.x
	size = box()
	# The whole sheet, hung so the frame's box on it lands on this node.
	var sheet := Rect2(-HudSkin.METER_FRAME.position * scale, HudSkin.METER_SHEET * scale)
	if _water != null:
		_water.position = sheet.position
		_water.size = sheet.size
	_frame.position = Vector2.ZERO
	_frame.size = size
	# The fallback stamps the painted sheet; this is where that sheet lies in this node.
	_frame.sheet_box = sheet
	_frame.queue_redraw()
