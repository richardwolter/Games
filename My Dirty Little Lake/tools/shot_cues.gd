extends Node
## Photographs every first-time cue card (`CueCard`, 2026-10-07): each theme at four moments
## of its entrance and settled, over the loading screen's picture of the lake, into one
## contact sheet, `tools/last_cues.png`, and the settled cards alone at full size,
## `tools/last_cues_<kind>.png`. Hints point at a stand-in plate where the lake would have
## the real one. Desktop build (nothing renders headless), `--fixed-fps 60`:
##
##     <exe> --path . --fixed-fps 60 res://tools/shot_cues.tscn
##
## No lake is made, so nothing in `user://` is touched.

const KINDS: Array[StringName] = [&"tornado", &"wildlife", &"swarm", &"honey", &"lucky", &"double", &"pigeon", &"ferry"]
const KEYS := {
	&"tornado": "TORNADO_FIRST", &"wildlife": "WILDLIFE_BACK", &"swarm": "HIVE_SWARM",
	&"honey": "HIVE_READY", &"lucky": "CUE_LUCKY", &"double": "CUE_DOUBLE",
	&"pigeon": "CUE_PIGEON", &"ferry": "CUE_FERRY",
}
## Seconds into the entrance each frame of a row is taken at; the last is the card settled.
const AGES: Array[float] = [0.05, 0.15, 0.3, 0.55, 2.0]
## Where each hint's stand-in target sits, in the design canvas.
const TARGETS := {
	&"lucky": Rect2(606.0, 300.0, 68.0, 22.0),
	&"double": Rect2(606.0, 300.0, 68.0, 22.0),
	&"pigeon": Rect2(14.0, 76.0, 150.0, 56.0),
	&"ferry": Rect2(14.0, 14.0, 150.0, 54.0),
}
const CELL := Vector2i(440, 230)

var _layer: CanvasLayer
var _card: CueCard
var _plate: ColorRect
var _kind := 0
var _shot := 0
var _frames := 0
var _sheet: Image
var _busy := false


func _ready() -> void:
	var back := TextureRect.new()
	back.texture = load("res://assets/loading_lake.png")
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	_layer = CanvasLayer.new()
	_layer.layer = 20
	add_child(_layer)
	_plate = ColorRect.new()
	_plate.color = Color(0.29, 0.20, 0.14)
	_layer.add_child(_plate)
	_card = CueCard.new()
	_layer.add_child(_card)
	_sheet = Image.create(CELL.x * AGES.size(), CELL.y * KINDS.size(), false, Image.FORMAT_RGBA8)
	_sheet.fill(Color(0.1, 0.1, 0.12))
	_begin()


func _begin() -> void:
	var kind := KINDS[_kind]
	var words := Text.of(String(KEYS[kind]))
	_plate.visible = TARGETS.has(kind)
	if TARGETS.has(kind):
		var at: Rect2 = TARGETS[kind]
		_plate.position = at.position
		_plate.size = at.size
		_card.show_hint(kind, words, at)
	else:
		_card.kind = kind
		_card.text = words
		_card.show_for(0.0, 30.0)
	_shot = 0
	_frames = 0


func _process(_delta: float) -> void:
	if _busy:
		return
	_frames += 1
	if _shot >= AGES.size() or float(_frames) / 60.0 < AGES[_shot]:
		return
	_busy = true
	await RenderingServer.frame_post_draw
	_grab()
	_busy = false


func _grab() -> void:
	var shot := get_viewport().get_texture().get_image()
	var scale := float(shot.get_height()) / get_viewport().get_visible_rect().size.y
	var box := _card.card_box()
	if TARGETS.has(KINDS[_kind]):
		box = box.merge(TARGETS[KINDS[_kind]])
	var mid := box.get_center() * scale
	var crop := Rect2i(Vector2i(mid) - CELL / 2, CELL)
	crop.position = crop.position.clamp(Vector2i.ZERO, Vector2i(shot.get_width(), shot.get_height()) - CELL)
	_sheet.blit_rect(shot, crop, Vector2i(_shot * CELL.x, _kind * CELL.y))
	if _shot == AGES.size() - 1:
		var whole := Rect2i(Vector2i((box.grow(40.0).position * scale).floor()), Vector2i((box.grow(40.0).size * scale).ceil()))
		whole = whole.intersection(Rect2i(Vector2i.ZERO, Vector2i(shot.get_width(), shot.get_height())))
		shot.get_region(whole).save_png("res://tools/last_cues_%s.png" % KINDS[_kind])
	_shot += 1
	if _shot < AGES.size():
		return
	_card.hide_hint(true)
	_kind += 1
	if _kind >= KINDS.size():
		_sheet.save_png("res://tools/last_cues.png")
		get_tree().quit()
		return
	_begin()
