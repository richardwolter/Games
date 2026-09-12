## The canvas the corner buttons are laid out on. F7 to show or hide; debug builds only.
##
## The decorate and upgrades buttons are a handful of pictures stacked on a face, and where
## each one goes was written as a rule — the ferry's right edge so far inside the arrow's
## left, the hut so far down the spare height. Rules are the right way to *start*, because
## they hold at any button size, and the wrong way to finish: "a little further left" is not
## a number anybody can write down. So this draws both buttons big, lets each picture be
## dragged and scaled by hand, and writes what was picked to `user://button_tune.log` as a
## dictionary to paste into `HudButtons.BAKED`.
##
## **The real drawing does the drawing.** `HudButtons.draw_upgrades`/`draw_shed` are called
## here exactly as the HUD calls them, with the lake's own sprites, and they report where each
## picture landed through `HudButtons.traced`. There is no second layout to drift from the
## first — which is the whole reason this is a panel in the game rather than a web canvas with
## the sums written out again.
##
## Everything is kept in fractions of the face (of the room, for the shed's two), so a picked
## place holds if the button is ever resized.
class_name ButtonTuner
extends CanvasLayer

const Style := preload("res://scripts/style.gd")
const HudButtons := preload("res://scripts/hud_buttons.gd")

const LOG_PATH := "user://button_tune.log"

## How much bigger than life the buttons are drawn, and the gap between them.
const ZOOM := 4.0
const GAP := 24.0

## The sizes the HUD draws them at. Read from `UiButton`, so the canvas cannot be laying out
## a button of a size that is never drawn.
const SIZES := UiButton.SIZES

## What can be taken hold of. `owner_box` is the traced rect the handle's fraction is measured
## against; `shift` marks the one that is an offset from where the rule put it rather than a
## middle of its own; `size` and `wide` are what the wheel turns, plain and with shift held.
##
## Listed in drawing order. The pick runs down it backwards, so the arrow on top of the net is
## what a click on both of them takes — hold Alt for the one underneath.
const HANDLES := [
	{"key": &"net", "owner_box": &"face_upgrades", "size": &"net_fill", "step": 0.05},
	{"key": &"boat", "owner_box": &"face_upgrades", "size": &"boat_tall", "step": 0.02},
	{"key": &"dog", "owner_box": &"face_upgrades", "size": &"dog_tall", "step": 0.02},
	{"key": &"arrow", "owner_box": &"face_upgrades", "size": &"arrow_tall", "wide": &"arrow_wide", "step": 0.02},
	{"key": &"decor", "owner_box": &"room_shed", "shift": true, "size": &"decor_scale", "step": 0.02},
	{"key": &"hut", "owner_box": &"room_shed", "size": &"hut_tall", "step": 0.02},
]

## What each size is when nobody has turned it: the rule's own number. Kept beside the
## handles rather than read off `HudButtons`' constants at the call, because the readout and
## the wheel both need it and a wheel that starts from 1.0 jumps the arrow to full height on
## its first tick.
const SIZE_RULES := {
	&"net_fill": HudButtons.NET_FILL,
	&"boat_tall": HudButtons.BOAT_TALL,
	&"dog_tall": HudButtons.SIDE_TALL * 0.9,
	&"arrow_tall": HudButtons.ARROW_TALL,
	&"arrow_wide": HudButtons.ARROW_WIDE,
	&"decor_scale": 1.0,
	&"hut_tall": HudButtons.SHED_TALL,
}

## How far an arrow key nudges: one pixel of the face, so the nudge is the smallest move that
## can show.
const NUDGE := 1.0

## The sprites the buttons draw from — the lake's own, handed over when this is built.
var sprites := {}

var _stage: Stage
var _readout: Label
var _held: StringName = &""
var _grab := Vector2.ZERO
var _picked: StringName = &""


func _ready() -> void:
	layer = 128
	var scrim := ColorRect.new()
	scrim.color = Style.scrim(Style.SCRIM_HEAVY)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	_stage = Stage.new()
	_stage.tuner = self
	_stage.scale = Vector2(ZOOM, ZOOM)
	_stage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)

	_readout = Label.new()
	_readout.add_theme_font_override(&"font", Style.font())
	_readout.add_theme_font_size_override(&"font_size", Style.TEXT_SMALL)
	_readout.add_theme_color_override(&"font_color", Style.INK)
	_readout.position = Vector2(Style.EDGE, Style.EDGE)
	_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_readout)

	get_viewport().size_changed.connect(_lay_out)
	_lay_out()


func _exit_tree() -> void:
	# The overrides are the panel's, not the game's: what is kept is what was baked.
	HudButtons.tune.clear()
	HudButtons.tracing = false


## Both buttons side by side, the pair centred on the screen.
func _lay_out() -> void:
	var up: Vector2 = SIZES.get(&"upgrades", Vector2(120.0, 100.0))
	var shed: Vector2 = SIZES.get(&"shed", Vector2(120.0, 100.0))
	var span := Vector2(up.x + GAP + shed.x, maxf(up.y, shed.y))
	var room := _stage.get_viewport_rect().size
	_stage.size = span
	# Grown about its own middle, so the corner it lands on does not have to be worked out
	# from `ZOOM` and the window stretch by hand. Stood on the bottom of the screen rather
	# than the middle of it: the readout is a dozen lines and the top is where they go.
	_stage.pivot_offset = span * 0.5
	# The drawn box runs `span * ZOOM` about `position + pivot`, so the foot of it is the
	# position plus half the unscaled height plus half the scaled one.
	_stage.position = Vector2(
		floorf((room.x - span.x) * 0.5),
		floorf(room.y - Style.EDGE - span.y * 0.5 - span.y * ZOOM * 0.5)
	)
	_stage.upgrades = Rect2(Vector2(0.0, 0.0), up)
	_stage.shed = Rect2(Vector2(up.x + GAP, 0.0), shed)
	_stage.queue_redraw()
	_show_numbers()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		match key.keycode:
			KEY_ESCAPE, KEY_F7:
				queue_free()
				get_viewport().set_input_as_handled()
				return
			KEY_S:
				_write_log()
				get_viewport().set_input_as_handled()
				return
			KEY_R:
				if key.shift_pressed:
					HudButtons.tune.clear()
				elif _picked != &"":
					_forget(_picked)
				_redraw()
				get_viewport().set_input_as_handled()
				return
			KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
				_nudge(key.keycode)
				get_viewport().set_input_as_handled()
				return

	var click := event as InputEventMouseButton
	if click != null:
		if click.button_index == MOUSE_BUTTON_LEFT:
			if click.pressed:
				_take(_stage.get_local_mouse_position(), click.alt_pressed)
			else:
				_held = &""
			get_viewport().set_input_as_handled()
			return
		if click.pressed and click.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var way := 1.0 if click.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
			_resize(_under(_stage.get_local_mouse_position(), false), way, click.shift_pressed)
			get_viewport().set_input_as_handled()
			return

	var drag := event as InputEventMouseMotion
	if drag != null and _held != &"":
		_drag_to(_stage.get_local_mouse_position())
		get_viewport().set_input_as_handled()


## The handle under a point: the last one drawn wins, or the first one if `under` is set —
## the arrow covers half the ferry, and both have to be reachable.
func _under(at: Vector2, under: bool) -> Dictionary:
	var found: Array = []
	for handle: Dictionary in HANDLES:
		var box: Rect2 = HudButtons.traced.get(handle["key"], Rect2())
		if box.size.x > 0.0 and box.has_point(at):
			found.append(handle)
	if found.is_empty():
		return {}
	return found[0] if under else found[found.size() - 1]


func _take(at: Vector2, under: bool) -> void:
	var handle := _under(at, under)
	if handle.is_empty():
		_picked = &""
		_redraw()
		return
	var key: StringName = handle["key"]
	_picked = key
	_held = key
	var box: Rect2 = HudButtons.traced[key]
	# Where in the picture it was taken hold of, so it does not jump to the cursor.
	_grab = at - (box.position + box.size * 0.5)
	_redraw()


func _drag_to(at: Vector2) -> void:
	var handle := _handle(_held)
	if handle.is_empty():
		return
	var owner_box: Rect2 = HudButtons.traced.get(handle["owner_box"], Rect2())
	if owner_box.size.x <= 0.0:
		return
	var middle := at - _grab
	if bool(handle.get("shift", false)):
		# An offset from where the rule put it: the drag's own distance, kept as a fraction.
		var was: Rect2 = HudButtons.traced[_held]
		var by := (middle - (was.position + was.size * 0.5)) / owner_box.size
		HudButtons.tune[_held] = HudButtons._at(_held, Vector2.ZERO) + by
	else:
		HudButtons.tune[_held] = (middle - owner_box.position) / owner_box.size
	_redraw()


func _nudge(code: Key) -> void:
	if _picked == &"":
		return
	var handle := _handle(_picked)
	var owner_box: Rect2 = HudButtons.traced.get(handle["owner_box"], Rect2())
	if owner_box.size.x <= 0.0:
		return
	var by := Vector2.ZERO
	match code:
		KEY_LEFT:
			by.x = -NUDGE
		KEY_RIGHT:
			by.x = NUDGE
		KEY_UP:
			by.y = -NUDGE
		_:
			by.y = NUDGE
	var rule := Vector2.ZERO
	if not bool(handle.get("shift", false)):
		var box: Rect2 = HudButtons.traced[_picked]
		rule = (box.position + box.size * 0.5 - owner_box.position) / owner_box.size
	HudButtons.tune[_picked] = HudButtons._at(_picked, rule) + by / owner_box.size
	_redraw()


func _resize(handle: Dictionary, way: float, wide: bool) -> void:
	if handle.is_empty():
		return
	var key: StringName = handle.get("wide", &"") if wide else handle.get("size", &"")
	if key == &"":
		return
	_picked = handle["key"]
	HudButtons.tune[key] = maxf(_size_of(key) + way * float(handle["step"]), 0.02)
	_redraw()


## Take a handle's overrides off again, so the rule under them comes back.
func _forget(key: StringName) -> void:
	var handle := _handle(key)
	HudButtons.tune.erase(key)
	for field: StringName in [&"size", &"wide"]:
		var name: StringName = handle.get(field, &"")
		if name != &"":
			HudButtons.tune.erase(name)


## Where a handle's picture came out, as the fraction its own numbers are kept in.
func _where(handle: Dictionary) -> Vector2:
	var box: Rect2 = HudButtons.traced.get(handle["key"], Rect2())
	var owner_box: Rect2 = HudButtons.traced.get(handle["owner_box"], Rect2())
	if box.size.x <= 0.0 or owner_box.size.x <= 0.0:
		return Vector2.ZERO
	if bool(handle.get("shift", false)):
		return HudButtons._at(handle["key"], Vector2.ZERO)
	return (box.position + box.size * 0.5 - owner_box.position) / owner_box.size


## A size as it stands: what has been turned, else what has been baked, else the rule's.
func _size_of(key: StringName) -> float:
	return HudButtons._scale(key, float(SIZE_RULES.get(key, 1.0)))


func _handle(key: StringName) -> Dictionary:
	for handle: Dictionary in HANDLES:
		if handle["key"] == key:
			return handle
	return {}


func _redraw() -> void:
	_stage.queue_redraw()
	_show_numbers()


func _show_numbers() -> void:
	var lines := PackedStringArray([
		"Button canvas — drag to move, wheel to size (shift: the arrow's width),",
		"arrows to nudge, alt-click for the one underneath.",
		"R the one picked back to its rule, shift-R all of them, S to save, Esc to close.",
		"",
	])
	for handle: Dictionary in HANDLES:
		var key: StringName = handle["key"]
		var mark := ">" if key == _picked else " "
		# Read back off what was drawn, not off the overrides, so the line says where the
		# picture actually is whether or not anybody has moved it.
		var at := _where(handle)
		var line := "%s %-6s at %.3f, %.3f" % [mark, key, at.x, at.y]
		for field: StringName in [&"size", &"wide"]:
			var name: StringName = handle.get(field, &"")
			if name != &"":
				line += "   %s %.3f" % [name, _size_of(name)]
		if not HudButtons.tune.has(key):
			line += "   (the rule's)"
		lines.append(line)
	_readout.text = "\n".join(lines)


## What has been picked, as a whole dictionary to paste over `HudButtons.BAKED`.
##
## `BAKED` and this session's moves together, not the moves alone: the panel clears its
## overrides when it closes, so a handle baked last time and left alone this time is not in
## `tune` at all, and a log of `tune` alone quietly drops it (2026-09-12 — the first save
## after a bake lost the net, the dog and the arrow).
##
## Still only what has been *moved*, though: a bake that wrote down the rule's own answer for
## everything would freeze numbers nobody chose, and the rules are what keep working when a
## button is resized.
func _write_log() -> void:
	var lines := PackedStringArray([
		"# Paste into HudButtons.BAKED. Written %s." % Time.get_datetime_string_from_system(),
		"const BAKED := {",
	])
	for handle: Dictionary in HANDLES:
		var key: StringName = handle["key"]
		if HudButtons.tune.has(key) or HudButtons.BAKED.has(key):
			var at := HudButtons._at(key, Vector2.ZERO)
			lines.append("\t&\"%s\": Vector2(%.4f, %.4f)," % [key, at.x, at.y])
		for field: StringName in [&"size", &"wide"]:
			var name: StringName = handle.get(field, &"")
			if name != &"" and (HudButtons.tune.has(name) or HudButtons.BAKED.has(name)):
				lines.append("\t&\"%s\": %.4f," % [name, _size_of(name)])
	lines.append("}")
	var text := "\n".join(lines) + "\n"
	var file := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()
	_readout.text = "Saved to %s\n\n%s" % [ProjectSettings.globalize_path(LOG_PATH), text]


## The canvas itself: both buttons drawn by the HUD's own code, with a ring round whatever is
## picked. Its own Control so the whole thing can be scaled up by `ZOOM` and the traced boxes
## still come back in one coordinate system.
class Stage extends Control:
	var tuner: ButtonTuner
	var upgrades := Rect2()
	var shed := Rect2()

	func _draw() -> void:
		if tuner == null:
			return
		HudButtons.tracing = true
		HudButtons.traced.clear()
		HudButtons.draw_upgrades(self, upgrades, false, tuner.sprites)
		HudButtons.draw_shed(self, shed, false, tuner.sprites)
		# The shed's room is the face less the band its word sits on — the two handles on that
		# button are measured against it, so the tuner needs it traced like a face. Asked for
		# rather than worked out again, or the canvas and the button disagree about where a
		# fraction of the room is.
		var face: Rect2 = HudButtons.traced.get(&"face_shed", Rect2())
		if face.size.x > 0.0:
			HudButtons.traced[&"room_shed"] = HudButtons.room_of(face)
		HudButtons.tracing = false
		var ring: Rect2 = HudButtons.traced.get(tuner._picked, Rect2())
		if ring.size.x > 0.0:
			draw_rect(ring, Style.SAFE, false, 1.0)
		# The readout reads off what was just traced, so it has to come after the draw rather
		# than with the layout — deferred, or it would be setting a Label mid-draw.
		tuner.call_deferred(&"_show_numbers")
