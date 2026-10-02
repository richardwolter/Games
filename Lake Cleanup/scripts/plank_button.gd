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

## The free camera's mark: a video icon (a box with a wedge on its right) with a padlock over
## its bottom-right corner, shut while the view follows the angler and open while it is
## pinned. All shares of the face's shorter side; chamfered, like the gear's square cuts.
## First guesses.
const CAMERA_BODY := Vector2(0.62, 0.5)
const CAMERA_CUT := 0.07
const CAMERA_WEDGE := 0.26
const CAMERA_WEDGE_GAP := 0.03
const CAMERA_WEDGE_NARROW := 0.16
const CAMERA_WEDGE_WIDE := 0.44
const CAMERA_SHIFT := Vector2(0.0, 0.0)
const LOCK_BODY := Vector2(0.36, 0.28)
const LOCK_AT := Vector2(0.66, 0.6)
const LOCK_SHACKLE := Vector2(0.24, 0.18)
const LOCK_STROKE := 0.08
const LOCK_LIFT := 0.1

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


## The free camera's mark: a video icon with a padlock on its corner. `lit` is free mode, so
## a lit button wears the lock open and the clean water's blue; unlit, the view follows the
## angler and the lock is shut. On whole pixels, the black rim one pixel all round, the
## keyhole a hole in the button's own face like the gear's hub.
func _draw_camera(face: Rect2, behind: Color) -> void:
	var ink := Style.ON_WATER if lit else Style.RIBBON_INK
	var side := minf(face.size.x, face.size.y)
	var middle := (face.position + face.size * 0.5 + CAMERA_SHIFT * side).round()
	var body_size := (CAMERA_BODY * side).round()
	var wedge := roundf(CAMERA_WEDGE * side)
	var gap := maxf(1.0, roundf(CAMERA_WEDGE_GAP * side))
	var whole := body_size.x + gap + wedge
	var body := Rect2(
		(middle - Vector2(whole * 0.5, body_size.y * 0.5)).round(), body_size
	)
	var cut := maxf(1.0, roundf(CAMERA_CUT * side))
	var cy := body.position.y + body.size.y * 0.5
	var near := body.end.x + gap
	var tip := near + wedge
	var narrow := roundf(CAMERA_WEDGE_NARROW * side)
	var wide := roundf(CAMERA_WEDGE_WIDE * side)
	draw_colored_polygon(_chamfered(body.grow(1.0), cut + 1.0), Style.HOLE_RIM)
	draw_colored_polygon(_wedge(near - 1.0, tip + 1.0, cy, narrow + 1.0, wide + 1.0), Style.HOLE_RIM)
	draw_colored_polygon(_chamfered(body, cut), ink)
	draw_colored_polygon(_wedge(near, tip, cy, narrow, wide), ink)
	_draw_lock(face, side, ink, behind)


## The padlock over the camera's corner. Shut: both legs of the shackle in the body. Open:
## the shackle lifted `LOCK_LIFT` with its right leg clear of the body.
func _draw_lock(face: Rect2, side: float, ink: Color, behind: Color) -> void:
	var centre := face.position + face.size * 0.5 + LOCK_AT * side
	var size := (LOCK_BODY * side).round()
	var body := Rect2((centre - size * 0.5).round(), size)
	var stroke := maxf(2.0, roundf(LOCK_STROKE * side))
	var span := roundf(LOCK_SHACKLE.x * side)
	var tall := roundf(LOCK_SHACKLE.y * side)
	var lift := roundf(LOCK_LIFT * side) if lit else 0.0
	var left := roundf(body.position.x + (body.size.x - span) * 0.5)
	var top := body.position.y - tall - lift
	var bars: Array[Rect2] = [
		Rect2(left, top, span, stroke),
		Rect2(left, top, stroke, tall + lift + 1.0),
	]
	var right_foot := body.position.y + 1.0 if not lit else body.position.y - lift * 0.5
	bars.append(Rect2(left + span - stroke, top, stroke, right_foot - top))
	for bar in bars:
		draw_rect(bar.grow(1.0), Style.HOLE_RIM, true)
	draw_rect(body.grow(1.0), Style.HOLE_RIM, true)
	for bar in bars:
		draw_rect(bar, ink, true)
	draw_rect(body, ink, true)
	var hole := Vector2(maxf(2.0, roundf(side * 0.05)), maxf(3.0, roundf(side * 0.08)))
	draw_rect(Rect2((body.position + (body.size - hole) * 0.5).round(), hole), behind, true)


func _chamfered(box: Rect2, cut: float) -> PackedVector2Array:
	var a := box.position
	var b := box.end
	return PackedVector2Array([
		Vector2(a.x + cut, a.y), Vector2(b.x - cut, a.y), Vector2(b.x, a.y + cut),
		Vector2(b.x, b.y - cut), Vector2(b.x - cut, b.y), Vector2(a.x + cut, b.y),
		Vector2(a.x, b.y - cut), Vector2(a.x, a.y + cut),
	])


## The video icon's wedge: narrow where it meets the body, wide at its right end.
func _wedge(near: float, tip: float, cy: float, narrow: float, wide: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(near, cy - narrow * 0.5), Vector2(tip, cy - wide * 0.5),
		Vector2(tip, cy + wide * 0.5), Vector2(near, cy + narrow * 0.5),
	])


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
