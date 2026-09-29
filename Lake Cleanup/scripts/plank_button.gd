## A button that is the meter's wood with a word on it.
##
## For the buttons that live in the scene and are placed by anchors — the settings button in
## the HUD's corner — so they are the same wood as the HUD's own, rather than a stock Button
## in a theme override. It wears the meter's built border (`Style.meter_frame`) like the
## three corner buttons, and falls back to a clipped plank where that will not fit.
##
## The word is set to the face the border leaves rather than to the whole button, so a button
## sized to its own word has no empty wood around it.
class_name PlankButton
extends Control

const Style := preload("res://scripts/style.gd")
const HudButtons := preload("res://scripts/hud_buttons.gd")

@export var label: String = "":
	set(value):
		label = value
		queue_redraw()

## A mark drawn in place of the word. The lake's settings button wears `&"gear"` and no word
## (2026-09-17, Richard: a gear is what every game uses); **the main menu's Settings plank
## keeps its word**, having the room and no convention to lean on.
##
## Drawn in code rather than fetched off a sheet, the way the close cross and the coin are:
## `assets/ui.png` has four pieces on it and none of them is a gear.
## The one door on a board that the player most often wants — the menu's Continue. It keeps
## the same wood; what changes is the face behind the word, from the boards' dark `BOARD` to
## the lighter `BOARD_ROW` an affordable shop row wears, plus the lit edge along its top.
##
## **Two channels, not one** (the shop's rule, 2026-09-17): the two faces are close in
## luminance, so told apart by hue alone they are one face to a red-green colourblind player.
## The lit edge is what carries it for them.
@export var accent: bool = false:
	set(value):
		accent = value
		queue_redraw()

@export var mark: StringName = &"":
	set(value):
		mark = value
		queue_redraw()

## A mark that is switched on: the lake's free-camera toggle. Said the settings board's way —
## the clean water's blue in place of the oak, plus the lit edge, because a colour alone is
## one channel.
## The picture a `&"flag"` mark shows: the language chooser's current flag.
var flag: Texture2D = null:
	set(value):
		flag = value
		queue_redraw()

var lit: bool = false:
	set(value):
		lit = value
		queue_redraw()

## A soft lit rim breathing round the wood, 0 to 1 — the HUD's own `HudButtons.pulse`,
## driven by whoever owns the button (the shed's wash plank, when a find has arrived at the
## pump since the shelf was last opened). The button itself keeps no clock.
var pulse: float = 0.0:
	set(value):
		if roundi(value * 64.0) != roundi(pulse * 64.0):
			queue_redraw()
		pulse = value

## How much of the face the word is set to, and how much room is left beside it.
const LABEL_SHARE := 0.78
const LABEL_PAD := 12.0

## The gear: how much of the face it fills, how many teeth, how far a tooth stands out of the
## rim, how wide a tooth is as a share of its pitch, and the hub's radius. First guesses, to
## be judged in the corner of the screen.
const GEAR_FILL := 0.76
const GEAR_TEETH := 8
const GEAR_TOOTH := 0.26
const GEAR_WIDTH := 0.46
const GEAR_HUB := 0.34

## The camera: the body's width and height as shares of the face, the viewfinder block on its
## top-left shoulder, and the lens's radius as a share of the body's height. Square cuts, like
## the gear. First guesses.
const CAMERA_WIDE := 0.74
const CAMERA_TALL := 0.46
const CAMERA_FINDER := Vector2(0.3, 0.2)
const CAMERA_LENS := 0.36

signal pressed

## Whether a press clicks. The menu's own planks turn it off and choose their sound there: New
## game and Continue play the start sound instead.
var clicks: bool = true

var _hovered: bool = false
var _held: bool = false

## A main-menu door is a tank of lake water (2026-09-26, `/grill-me` with Richard): the HUD
## meter's own painted sheet, murky, or clean in the accented door, in a rounded pool low in
## the face. The body of water rocks on a spring (`_tilt`), climbs the walls where it meets
## them, rolls small waves over the top and lets bubbles up through it. A hover jolts the wood,
## throws the water one way and squeezes a drip or two out under the door (`_drips`,
## 2026-09-27), which stretch and fall; it sloshes back and settles. Menu doors only.
var water: bool = false:
	set(value):
		water = value
		set_process(water)
		queue_redraw()

const WATER_FILL := 0.4
const WATER_PIXEL := 2.0
const CLEAN_DIM := 0.68
## The drips' colours, [body, highlight], picked off the two sheets inside `METER_OPAQUE`
## (median and 92nd percentile by brightness), the clean one taken down by `CLEAN_DIM` as the
## door's water is. Re-pick them if the meter is repainted.
const DRIP_MURKY := [Color8(27, 64, 19), Color8(55, 88, 34)]
const DRIP_CLEAN := [Color8(60, 89, 116), Color8(102, 126, 142)]
## Drips a hover squeezes out: how many, how long a stem grows, how fast a bead falls.
const DRIPS_ON_HOVER := 2
const DRIP_STEM := 7.0
const DRIP_GROW := 0.35
const DRIP_FALL := 140.0
const DRIP_GONE := 26.0
## The pool's bottom corners, as a share of the face's height.
const POOL_ROUND := 0.45
## The water climbing each wall: height in pixels, and how far in it reaches (share of width).
const MENISCUS := 3.0
const MENISCUS_IN := 0.06
## The rocking spring: stiffness, damping, the idle drive, and what a hover throws in.
const TILT_STIFF := 38.0
const TILT_DAMP := 2.6
const TILT_IDLE := 0.12
const TILT_KICK := 2.4
## Waves riding the surface.
const WAVE_IDLE := 1.2
const WAVE_KICK := 2.5
const WAVE_DECAY := 1.6
const BUBBLES := 5
const JOLT_TIME := 0.3
const JOLT_PX := 3.0
const JOLT_RATE := 55.0

static var _murky: Texture2D
static var _clean: Texture2D
## Drips as (across 0..1 of the face, age, fall distance, bead size).
var _drips: Array[Vector4] = []
var _clock: float = 0.0
var _tilt: float = 0.0
var _tilt_v: float = 0.0
var _kick: float = 0.0
var _jolt: float = 0.0
var _bubbles: Array[Vector3] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_clock = randf() * 20.0
	set_process(water)
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_clock += delta
	var drive := sin(_clock * 1.1) * TILT_IDLE * TILT_STIFF * 0.3
	_tilt_v += (-TILT_STIFF * _tilt - TILT_DAMP * _tilt_v + drive) * delta
	_tilt += _tilt_v * delta
	_kick *= exp(-WAVE_DECAY * delta)
	_jolt = maxf(0.0, _jolt - delta)
	_rise(delta)
	_drip(delta)
	queue_redraw()


## A drip grows its stem over `DRIP_GROW`, then the bead lets go and falls, fading out.
func _drip(delta: float) -> void:
	for i in range(_drips.size() - 1, -1, -1):
		var d := _drips[i]
		d.y += delta
		if d.y > DRIP_GROW:
			d.z += DRIP_FALL * (d.y - DRIP_GROW) * delta * 3.0
		if d.z > DRIP_GONE:
			_drips.remove_at(i)
			continue
		_drips[i] = d


## Bubbles as (across 0..1, up 0..1 of the water's depth, speed).
func _rise(delta: float) -> void:
	while _bubbles.size() < BUBBLES:
		_bubbles.append(Vector3(randf_range(0.12, 0.88), randf() * -1.5, randf_range(0.25, 0.6)))
	for i in _bubbles.size():
		var b := _bubbles[i]
		b.y += b.z * delta * (1.0 + _kick)
		b.x += sin(_clock * 3.0 + float(i)) * 0.01 * delta
		if b.y >= 1.0:
			b = Vector3(randf_range(0.12, 0.88), randf_range(-1.2, 0.0), randf_range(0.25, 0.6))
		_bubbles[i] = b


## Sideways shake of the wood, whole pixels, dying over `JOLT_TIME`.
func jolt_offset() -> float:
	if _jolt <= 0.0:
		return 0.0
	var left := _jolt / JOLT_TIME
	return roundf(sin((JOLT_TIME - _jolt) * JOLT_RATE) * JOLT_PX * left)


## The surface's height over the face at `x` (0..1 across), in pixels up from the face's foot.
func surface_at(face: Rect2, x: float) -> float:
	var amp := WAVE_IDLE + _kick
	var wave := sin(x * TAU * 1.6 + _clock * 2.7) * amp * 0.6
	wave += sin(x * TAU * 2.9 - _clock * 3.9) * amp * 0.35
	wave += sin(x * TAU * 0.7 + _clock * 1.3) * amp * 0.5
	var lean := _tilt * (x - 0.5) * face.size.y
	var edge := minf(x, 1.0 - x) / MENISCUS_IN
	var climb := MENISCUS * exp(-edge * edge)
	return face.size.y * WATER_FILL + wave + lean + climb


## The pool's floor: the face's foot with its two corners rounded off.
func _floor(face: Rect2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var r := face.size.y * POOL_ROUND
	for i in range(0, 7):
		var a := PI * 0.5 * float(i) / 6.0
		out.append(Vector2(face.end.x - r + sin(a) * r, face.end.y - r + cos(a) * r).round())
	out.reverse()
	for i in range(0, 7):
		var a := PI * 0.5 * float(i) / 6.0
		out.append(Vector2(face.position.x + r - sin(a) * r, face.end.y - r + cos(a) * r).round())
	return out


func _tones() -> Array:
	return DRIP_CLEAN if accent else DRIP_MURKY


func _draw_water(face: Rect2) -> void:
	if _murky == null:
		_murky = Art.texture(HudSkin.METER_ART + "Murky_Water.png")
		_clean = Art.texture(HudSkin.METER_ART + "Clean_Water.png")
	var sheet := _clean if accent else _murky
	if sheet == null:
		return
	var region := HudSkin.METER_OPAQUE
	var drift := sin(_clock * 0.5) * 0.08
	var foot := face.end.y
	var r := face.size.y * POOL_ROUND
	var steps := maxi(2, int(face.size.x / WATER_PIXEL))
	var top := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / float(steps)
		var y := foot - roundf(surface_at(face, t) / WATER_PIXEL) * WATER_PIXEL
		# The rounded floor rises into the corners; the surface never goes under it.
		var side := minf(t, 1.0 - t) * face.size.x
		var lift := 0.0
		if side < r:
			var d := r - side
			lift = r - sqrt(maxf(0.0, r * r - d * d))
		y = clampf(y, face.position.y, foot - lift - WATER_PIXEL)
		top.append(Vector2(face.position.x + face.size.x * t, y))
	var points := top.duplicate()
	var floor_pts := _floor(face)
	for p in floor_pts:
		points.append(p)
	var uvs := PackedVector2Array()
	for p in points:
		var u := (p.x - face.position.x) / face.size.x * 0.84 + 0.08 + drift
		var v := (p.y - face.position.y) / face.size.y
		uvs.append(Vector2(
			(region.position.x + region.size.x * u) / HudSkin.METER_SHEET.x,
			(region.position.y + region.size.y * v) / HudSkin.METER_SHEET.y
		))
	# The clean sheet is pale and the word is cream, so it is taken down to keep the word read.
	var tone := Color(CLEAN_DIM, CLEAN_DIM, CLEAN_DIM) if accent else Color.WHITE
	draw_polygon(points, PackedColorArray([tone]), uvs, sheet)
	# Bubbles: whole art pixels, fading in as they leave the floor, gone at the top.
	for b in _bubbles:
		if b.y < 0.0:
			continue
		var x := face.position.x + face.size.x * b.x
		var t := b.x
		var surface := foot - surface_at(face, t)
		var y := lerpf(foot - 3.0, surface + 3.0, b.y)
		var at := (Vector2(x, y) / WATER_PIXEL).floor() * WATER_PIXEL
		draw_rect(Rect2(at, Vector2(WATER_PIXEL, WATER_PIXEL)), Color(1, 1, 1, 0.25 + 0.3 * b.y), true)
	# The top of the water: a pale lip, a darker shade under it, and a glint riding the crests.
	var shade := PackedVector2Array()
	for p in top:
		shade.append(p + Vector2(0.0, WATER_PIXEL))
	draw_polyline(shade, Color(0, 0, 0, 0.18), WATER_PIXEL)
	draw_polyline(top, Color(1, 1, 1, 0.45), WATER_PIXEL)
	var glint := int(fposmod(_clock * 0.15, 1.0) * float(top.size() - 4))
	for i in range(glint, mini(glint + 3, top.size())):
		draw_rect(Rect2(top[i] - Vector2(0, WATER_PIXEL * 0.5), Vector2(WATER_PIXEL, WATER_PIXEL)), Color(1, 1, 1, 0.8), true)


## Drips under the door's foot: a stem of the liquid stretching out of the wood with a bead on
## its end, the bead letting go and falling, fading as it goes. Whole art pixels.
func _draw_drips(box: Rect2, face: Rect2) -> void:
	var tones := _tones()
	var ink := Color(0.09, 0.07, 0.07)
	for d in _drips:
		if d.y < 0.0:
			continue
		var x := roundf((face.position.x + face.size.x * d.x) / WATER_PIXEL) * WATER_PIXEL
		var top := box.end.y - WATER_PIXEL * 2.0
		var grown := clampf(d.y / DRIP_GROW, 0.0, 1.0)
		var stem := roundf(DRIP_STEM * grown * (1.0 - clampf(d.z / 8.0, 0.0, 1.0)) / WATER_PIXEL) * WATER_PIXEL
		if stem > 0.0:
			draw_rect(Rect2(x - 1.0, top, WATER_PIXEL + 2.0, stem), ink, true)
			draw_rect(Rect2(x, top, WATER_PIXEL, stem), tones[0], true)
		var bead := roundf(d.w * grown / WATER_PIXEL) * WATER_PIXEL
		if bead <= 0.0:
			continue
		var y := roundf((top + stem + d.z) / WATER_PIXEL) * WATER_PIXEL
		var fade := 1.0 - clampf(d.z / DRIP_GONE, 0.0, 1.0)
		var at := Rect2(x + WATER_PIXEL * 0.5 - bead * 0.5, y, bead, bead)
		draw_rect(at.grow(1.0), Color(ink, fade), true)
		draw_rect(at, Color(tones[0], fade), true)
		draw_rect(Rect2(at.position, Vector2(WATER_PIXEL, WATER_PIXEL)), Color(tones[1], fade), true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER or what == NOTIFICATION_MOUSE_EXIT:
		_hovered = what == NOTIFICATION_MOUSE_ENTER
		if _hovered:
			Sfx.ui(&"ui_hover")
			if water:
				_kick = WAVE_KICK
				_tilt_v += TILT_KICK * (1.0 if randf() < 0.5 else -1.0)
				_jolt = JOLT_TIME
				for _n in DRIPS_ON_HOVER:
					_drips.append(Vector4(randf_range(0.15, 0.85), -randf() * 0.2, 0.0, randf_range(3.0, 4.0)))
		if not _hovered:
			_held = false
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if click.pressed:
		_held = true
		if clicks:
			Sfx.ui(&"ui_click")
		queue_redraw()
		return
	if _held:
		_held = false
		queue_redraw()
		pressed.emit()


func _draw() -> void:
	# The glow only: a plank in a list does not swell (Richard, 2026-09-22), the HUD's
	# corner buttons do.
	var box := Rect2(Vector2.ZERO, size)
	if _held:
		box.position.y += Style.PRESS_SINK
	elif _hovered:
		box.position.y -= Style.HOVER_LIFT
	box.position.x += jolt_offset()
	var face := Style.FRAME
	if _hovered and not _held:
		face = Color(face.r * Style.HOVER_WASH.r, face.g * Style.HOVER_WASH.g, face.b * Style.HOVER_WASH.b)
	elif _held:
		face = face.darkened(0.15)
	var on := box
	var behind := Style.BOARD_ROW if accent else Style.BOARD
	HudButtons.pulse(self, box, pulse)
	# The glow reaches outside the control; a control clips nothing by default, so it shows.
	if Style.border_fits(box):
		on = Style.border_inset(box)
		draw_rect(on.grow(2.0), Style.BOARD if water else behind, true)
		if water:
			_draw_water(on.grow(2.0))
		Style.meter_frame(self, box, Style.HOVER_WASH if _hovered and not _held else Color.WHITE)
		if water:
			_draw_drips(box, on)
		if (accent or lit) and not _held:
			Style.lit_edge(self, on.grow(2.0), behind)
	else:
		Style.plank(self, box, int(global_position.x) * 7 + int(global_position.y) + 3, face, Style.CLIP)
	if not mark.is_empty():
		_draw_mark(on, behind)
		return
	if label.is_empty():
		return
	# Set to the face, and shrunk if the word is longer than the wood leaves room for.
	var height := Style.step(on.size.y * LABEL_SHARE)
	var wide := Style.measure(label, height).x
	if wide > on.size.x - LABEL_PAD:
		height = Style.step(float(height) * (on.size.x - LABEL_PAD) / wide)
	Style.write(
		self, label, height,
		Vector2(0.0, on.position.y + (on.size.y + float(height) * 0.62) * 0.5),
		Style.RIBBON_INK, HORIZONTAL_ALIGNMENT_CENTER, on
	)


## The mark on a button that carries no word. `behind` is the face the button is drawn on,
## because the gear's hub is a **hole**: filled with the oak it read as a disc of wood lying
## on the panel, which is the opposite of what a gear's middle is.
func _draw_mark(face: Rect2, behind: Color) -> void:
	if mark == &"camera":
		_draw_camera(face, behind)
		return
	if mark == &"flag":
		draw_flag(self, face, flag)
		return
	if mark != &"gear":
		return
	var middle := face.position + face.size * 0.5
	var radius := minf(face.size.x, face.size.y) * 0.5 * GEAR_FILL
	var cog := _cog(middle, radius)
	# A black rim under the cog, and the hub punched out of it in the button's own face, so the
	# gear reads as a shape cut through the button rather than a sticker laid on it.
	draw_colored_polygon(_cog(middle, radius + 1.0), Style.HOLE_RIM)
	draw_colored_polygon(cog, Style.RIBBON_INK)
	draw_circle(middle, radius * GEAR_HUB + 1.0, Style.HOLE_RIM)
	draw_circle(middle, radius * GEAR_HUB, behind)


## A flag at the largest whole-pixel scale its box allows, centred and ringed in one pixel
## of the hole rim, so a white flag (Japan's) still has an edge on a pale face. Static: the
## language board draws its flags the same way.
static func draw_flag(on: CanvasItem, box: Rect2, texture: Texture2D, fill: float = 0.78) -> void:
	if texture == null:
		return
	var art := Vector2(texture.get_size())
	var scale := maxf(1.0, floorf(minf(box.size.x * fill / art.x, box.size.y * fill / art.y)))
	var drawn := art * scale
	var at := (box.position + (box.size - drawn) * 0.5).round()
	on.draw_rect(Rect2(at - Vector2.ONE, drawn + Vector2(2.0, 2.0)), Style.HOLE_RIM, true)
	on.draw_texture_rect(texture, Rect2(at, drawn), false)


## A boxy camera: a body, a viewfinder block on its shoulder, and a lens that is a hole like
## the gear's hub. On whole pixels, so the black rim is one pixel all round.
func _draw_camera(face: Rect2, behind: Color) -> void:
	var ink := Style.ON_WATER if lit else Style.RIBBON_INK
	var side := minf(face.size.x, face.size.y)
	var middle := (face.position + face.size * 0.5).round()
	var body := Rect2(
		middle - Vector2(side * CAMERA_WIDE, side * CAMERA_TALL) * 0.5
			+ Vector2(0.0, side * CAMERA_FINDER.y * 0.5),
		Vector2(side * CAMERA_WIDE, side * CAMERA_TALL)
	)
	body = Rect2(body.position.round(), body.size.round())
	var finder := Rect2(
		body.position + Vector2(side * 0.08, -side * CAMERA_FINDER.y).round(),
		(side * CAMERA_FINDER).round() + Vector2(0.0, 1.0)
	)
	draw_rect(body.grow(1.0), Style.HOLE_RIM, true)
	draw_rect(finder.grow(1.0), Style.HOLE_RIM, true)
	draw_rect(body, ink, true)
	draw_rect(finder, ink, true)
	var lens := body.position + body.size * 0.5
	var radius := body.size.y * CAMERA_LENS
	draw_circle(lens, radius + 1.0, Style.HOLE_RIM)
	draw_circle(lens, radius, behind)


## A cog's outline:`GEAR_TEETH` teeth standing off a rim, each `GEAR_WIDTH` of its pitch
## wide, with square shoulders rather than a scalloped edge — the game's wood is all straight
## cuts and chamfers, and a soft gear beside it would read as borrowed from another game.
func _cog(middle: Vector2, radius: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var rim := radius * (1.0 - GEAR_TOOTH)
	var pitch := TAU / float(GEAR_TEETH)
	var half := pitch * GEAR_WIDTH * 0.5
	for i in GEAR_TEETH:
		var at := pitch * float(i)
		out.append(middle + Vector2(cos(at - half), sin(at - half)) * rim)
		out.append(middle + Vector2(cos(at - half), sin(at - half)) * radius)
		out.append(middle + Vector2(cos(at + half), sin(at + half)) * radius)
		out.append(middle + Vector2(cos(at + half), sin(at + half)) * rim)
		var gap := at + pitch * 0.5
		out.append(middle + Vector2(cos(gap), sin(gap)) * rim)
	return out
