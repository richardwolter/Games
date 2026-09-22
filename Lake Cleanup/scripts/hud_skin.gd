## The drawn HUD: the pollution meter and the three wooden buttons.
##
## One node draws the lot and takes the clicks for it, the way the flock and the splashes
## do. The three buttons are drawn wood (`hud_buttons.gd`) carrying the game's own sprites,
## lent by the lake into `sprites`; they were painted plaques off a sheet until 2026-09-11.
##
## The meter is the one thing here that is assembled rather than drawn: four sheets of art
## (`assets/ui/meter/`) stacked as child nodes, the water between them a shader that slides
## the filth-to-clean seam and rocks both sheets so the water moves. It went that way
## because the art is pixel art and wants a nearest filter of its own, and because the water
## has to keep moving between readings — the rest of this node only repaints when a figure
## changes. See `_build_meter`.
class_name HudSkin
extends Control

const Style := preload("res://scripts/style.gd")
const HudButtons := preload("res://scripts/hud_buttons.gd")

## How fast the drawn waterline chases the real one, as a fraction of the gap a second. The
## lake cleans up a piece at a time and the meter would tick; sliding it is the whole reason
## the reading is animated rather than set.
const METER_EASE := 2.2

## How fast the money on the plate runs up to what has been earned, as a fraction of the gap
## a second, and the least it may move — without a floor the last few coins take longer than
## the first thousand.
const MONEY_RUN := 6.0
const MONEY_LEAST := 12.0

## How long a payment keeps the plate lit, in seconds, and how far the **coin** swells and
## the figure brightens at the moment it lands. Small: this happens every time a boat
## unloads, and a HUD that leaps about on every sale is one the player learns to stop looking
## at. The swell is the coin's alone; the plate and its border stand still.
const SHINE_TIME := 0.55
const SHINE_SWELL := 0.1
const SHINE_LIFT := 0.55

## The meter's art: the four sheets, all the same size and aligned, and where inside them the
## frame and the water's track fall (measured off the sheets' alpha). Drawn at
## `METER_SCALE` times its art on a 1080-line window and in proportion on any other,
## nearest-filtered. Not snapped to a pixel step: the size was settled by eye (3x, 1.5x,
## then a third up from that, then cut back by an eighth on 2026-09-16 with the rest of the
## HUD), and a snap would undo the settling.
const METER_ART := "res://assets/ui/meter/"
const METER_SHEET := Vector2(290.0, 94.0)
const METER_FRAME := Rect2(83.0, 24.0, 188.0, 49.0)
const METER_TRACK := Rect2(91.0, 37.0, 170.0, 26.0)
const METER_CIRCLE := Rect2(11.0, 1.0, 85.0, 87.0)
## Where both water sheets are fully opaque, in art pixels. Their ends and edges are soft
## and part-transparent; the shader never samples outside this, or the drift shows the
## screen through the gap between the circle and the water.
const METER_OPAQUE := Rect2(97.0, 40.0, 161.0, 19.0)
const METER_SCALE := 1.7
const METER_SCALE_LINES := 1080.0

## How wide the filth-to-clean blend is, as a fraction of the track. Narrowed near the ends
## (see `_show_meter`) so a nearly-clean lake keeps its last sliver of filth and a full one
## does not fade off the left of its own track.
const METER_FEATHER := 0.14

## The buttons, in screen pixels. Not squares any more: the upgrades button is wide enough
## for the ferry and the dog to flank its arrow, the shed's for the finds to stand behind
## the hut, and the money plate is as wide as the stock plate over it and as tall as its
## coin — two slabs of one width read as a pair, where a square under a slab read as
## lopsided.
const UPGRADES_SIZE := Vector2(120.0, 100.0)
const SHED_SIZE := Vector2(120.0, 100.0)
const MONEY_TALL := 56.0

## Gaps: around the whole thing, and between the buttons.
const EDGE := Style.EDGE
const GAP := Style.GAP

## The stock readout: where it sits and how big it is. The meter's border round the recycle
## box's own brown, the box's blue recycle mark on the left, a small label, and the count on
## a sunken panel the colour of the box's hollow — so the number reads as what is in that
## box. Tall enough that the border's own planks leave a face worth reading (2026-09-12):
## the plate was 34 and the wood alone is 30.
##
## `STOCK_TEXT` is the count's height as a fraction of that face, and the label a rung under
## it (`STOCK_LABEL_SHARE`) — the money plate's own rule, so the one number that shrinks the
## plate shrinks its writing and its width with it. Written down, the two sizes stayed put
## while the plate came in and the reading ran off its own panel.
const STOCK_TALL := 54.0
const STOCK_TEXT := 0.72
const STOCK_LABEL_SHARE := 0.8
const STOCK_MARK_PAD := 6.0
## "Waiting", not "In stock" (2026-09-17): the crate has no cap — `Store.held` is an
## unbounded list and `CRATE_FULL` only decides how high the heap draws — so this is a
## **backlog**, pieces waiting for a ferry, not a balance. Drawn on the same plate as the
## money and labelled "In stock" it read as a second purse. The word is the whole fix, by
## decision: the number rising is the clearest sign the fleet cannot keep up, but saying so
## with a trend mark is a fleet readout, and that was left out of this pass.
const STOCK_LABEL := "Waiting"

## How the count runs toward the true one when it changes — as a fraction of the gap a
## second, and the least it may move — and how long the glow behind it lasts after it lands.
## Both directions: a sale ticks it down as a catch ticks it up.
const STOCK_RUN := 5.0
const STOCK_LEAST := 6.0
const STOCK_GLOW := 0.5

## The label the plate is measured against, rather than the one it happens to be showing.
## Measured, because 168 fixed pixels was a guess against a font the HUD no longer uses and
## the reading ran off the end of its own plate; measured against a five-figure count rather
## than the live one, because a plate that changed width every time a piece was sold would
## be a plate that moved while being read.
const STOCK_SAMPLE := "99999"

## What the upgrades button calls itself, under the count's badge.
const UPGRADES_LABEL := "Upgrades"
const STOCK_PAD := 10.0

## The sprites the buttons carry, lent by the lake — see `hud_buttons.gd` for the keys.
var sprites := {}:
	set(v):
		sprites = v
		queue_redraw()

## Emitted when the buttons are pressed. The lake decides what a shed is.
signal shed_pressed
signal upgrades_pressed

## What the HUD is showing. Set by the lake every frame; the meter eases towards `pollution`
## rather than snapping to it, and the money counts up to whatever it is given.
var pollution: float = 1.0
var money: float = 0.0
## How much is waiting in the yard for the ferry.
var stock: int = 0

## How many upgrades can be paid for right now. Drawn as a tag under the upgrades button:
## the money plate says what the player has and the shop says what things cost, and this is
## the one line that puts those two together without the shop being open.
var available: int = 0:
	set(value):
		# A rise starts the pulse; a fall or a hold does not, and the first reading of a
		# sitting only sets the mark — a load is not something turning affordable.
		_mark(&"upgrades", value)
		available = value

## How many finds wait at the pump, unwashed. A rise pulses the decorate button (Richard,
## 2026-09-22: "nothing happened to the decoration button when something was caught"), the
## same way a rise in `available` pulses the upgrades button.
var waiting: int = 0:
	set(value):
		_mark(&"shed", value)
		waiting = value

## The pulses on the two picture buttons, by name: what is left of each (1 fresh, 0 done),
## and the count it last saw. A pulse fires only when its count rises (Richard, 2026-09-22:
## not a steady loop — something is affordable most of the run), breathes `PULSE_BEATS`
## times over `PULSE_TIME`, fades out on its own, and is cut short by a hover on its button
## or by that button's board opening (`hush_pulse`).
## `_pulses` is the envelope (1 at the burst, easing down), `_clocks` the seconds since the
## burst (the wave runs on it), `_unseen` whether the board has been opened since. **After
## the burst the pulse does not stop** (Richard, 2026-09-22): it settles to `PULSE_IDLE` and
## keeps breathing there until the player opens that board, which is what puts it out. A
## hover no longer does — the player has not seen what is pending until the board is up.
var _pulses := {&"upgrades": 0.0, &"shed": 0.0}
var _clocks := {&"upgrades": 0.0, &"shed": 0.0}
var _unseen := {&"upgrades": false, &"shed": false}
var _marks := {&"upgrades": -1, &"shed": -1}
const PULSE_TIME := 4.0
const PULSE_BEATS := 3.5
## Where the envelope settles after the burst, and how many beats a second it breathes there.
const PULSE_IDLE := 0.45
const PULSE_IDLE_RATE := PULSE_BEATS / PULSE_TIME


func _mark(name: StringName, value: int) -> void:
	if int(_marks[name]) >= 0 and value > int(_marks[name]):
		_pulses[name] = 1.0
		_clocks[name] = 0.0
		_unseen[name] = true
	_marks[name] = value

## A line under the meter, or empty for nothing. Used for the one thing the meter cannot
## say: that the lake reads clean and is not.
var hint: String = ""

## The siege's readouts, or an empty dictionary in the first lake — which is what keeps
## every line of the block below out of that game. Filled in by siege.gd with `health`,
## `shield`, `wave`, `note`, and the three effect clocks `ammo`, `fire` and `ice`.
var siege := {}

## How the siege block is laid out: its width, the height of one bar, the gap between the
## things in it, and how far under the stock plate it starts.
const SIEGE_WIDE := 210.0
const SIEGE_BAR := 16.0
const SIEGE_GAP := 6.0
const SIEGE_PIP := 13.0

## The figure actually on the plate, and how brightly it is still lit from the last payment.
var _shown_money: float = 0.0

## The stock figure as drawn, running toward `stock`, and how much glow it has left.
var _shown_stock: float = 0.0
var _stock_glow: float = 0.0
var _shine: float = 0.0

var _shown: float = 1.0

## The meter's nodes, built once in `_build_meter`: the water sheet with its shader, the
## garbage circle and the frame over it, and the face that writes the figure over the lot.
## Null when the art is missing, and then there is no meter — the lake keeps its plain label.
var _meter_water: TextureRect
var _meter_circle: TextureRect
var _meter_frame: MeterFrame
var _meter_face: MeterFace
var _meter_shader: ShaderMaterial

## Screen boxes worked out in `_notification` when the size changes, so a click and a
## drawing cannot disagree about where a button is. `_meter_box` is the whole sheet on
## screen; `_meter_frame_box` the wooden frame inside it, which is what a line over the
## meter centres on.
var _meter_box := Rect2()
var _meter_frame_box := Rect2()
var _shed_box := Rect2()
var _upgrades_box := Rect2()
var _money_box := Rect2()
var _stock_box := Rect2()
var _hovered := &""

## What the last painted picture was made of. See `_paint_key`.
var _painted: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# The buttons wear the meter's painted border, which is pixel art and wants its own filter.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_meter()
	_shown = pollution
	_show_meter()
	_lay_out()
	resized.connect(_lay_out)


## Where everything sits: the meter in the bottom left corner, the two buttons in the top
## right, and the money over on the left under the yard's readout.
##
## The money is not a button and does not belong in a row of them. It is a readout, and the
## other readout on screen is the yard count in the top left — so it goes with that one,
## where the eye already goes to ask how the run is doing.
func _lay_out() -> void:
	var wide := size.x
	var scale := meter_scale(size.y)
	var span := METER_SHEET * scale
	# Bottom left, with the garbage circle's own edge (not the sheet's) sitting EDGE in from
	# the corner: the sheet has empty room round the art, and the room is not the meter.
	var circle_left := METER_CIRCLE.position.x * scale
	var circle_bottom := (METER_SHEET.y - METER_CIRCLE.end.y) * scale
	_meter_box = Rect2(
		floorf(EDGE - circle_left), floorf(size.y - EDGE - span.y + circle_bottom), span.x, span.y
	)
	_meter_frame_box = Rect2(
		_meter_box.position + METER_FRAME.position * scale, METER_FRAME.size * scale
	)
	if _meter_frame != null:
		# The built frame is the wooden box alone, not the whole sheet: it is drawn at the
		# size the wood occupies, and `_build_border` fills the rest.
		_meter_frame.position = _meter_frame_box.position.floor()
		_meter_frame.size = _meter_frame_box.size.floor()
		_meter_frame.sheet_box = _meter_box
		_meter_frame.queue_redraw()
	for sheet: TextureRect in [_meter_water, _meter_circle]:
		if sheet != null:
			sheet.position = _meter_box.position
			sheet.size = _meter_box.size
	if _meter_face != null:
		_meter_face.position = _meter_box.position
		_meter_face.size = _meter_box.size
		_meter_face.track = Rect2(METER_TRACK.position * scale, METER_TRACK.size * scale)
		_meter_face.queue_redraw()
	# Along the top edge, on the same line the stock plate starts on over on the left, rather
	# than hung under the meter. The right-hand corner is theirs now that Settings has gone
	# to the bottom of the screen, and a row that starts at the same height on both sides
	# reads as one band across the top instead of as three separate corners.
	var right := wide - EDGE - UPGRADES_SIZE.x
	_upgrades_box = Rect2(Vector2(right, EDGE), UPGRADES_SIZE)
	_shed_box = Rect2(Vector2(right - SHED_SIZE.x - GAP, EDGE), SHED_SIZE)
	# Measured against the face the border leaves, then grown by the wood on both sides.
	var stock_face := _stock_face_tall()
	var stock_wide := (
		float(Style.BORDER_WALL * 2) + STOCK_PAD * 2.0 + (stock_face - STOCK_MARK_PAD * 2.0)
		+ STOCK_MARK_PAD + Style.measure(STOCK_LABEL, _stock_label_size()).x + STOCK_MARK_PAD
		+ Style.measure(STOCK_SAMPLE, _stock_count_size()).x + 12.0
	)
	_stock_box = Rect2(EDGE + 2.0, EDGE, stock_wide, STOCK_TALL)
	# The same width as the stock plate, under it: two slabs of one width.
	_money_box = Rect2(
		_stock_box.position.x, _stock_box.position.y + STOCK_TALL + GAP, stock_wide, MONEY_TALL
	)
	queue_redraw()


func _process(delta: float) -> void:
	var wanted := clampf(pollution, 0.0, 1.0)
	if not is_equal_approx(_shown, wanted):
		_shown = lerpf(_shown, wanted, clampf(METER_EASE * delta, 0.0, 1.0))
		if absf(_shown - wanted) < 0.0005:
			_shown = wanted
		_show_meter()

	# The figure runs up to what has been earned rather than jumping to it, and being paid
	# lights the plate for a moment. A sale is the one thing in this game that happens all at
	# once and out of sight — the boat is somewhere else when it lands — so it wants saying.
	# The stock count runs toward the true one, up or down, and glows while it is moving.
	var goal := float(stock)
	if not is_equal_approx(_shown_stock, goal):
		var step := maxf(absf(goal - _shown_stock) * STOCK_RUN, STOCK_LEAST) * delta
		_shown_stock = move_toward(_shown_stock, goal, step)
		_stock_glow = 1.0
	else:
		_stock_glow = maxf(_stock_glow - delta / STOCK_GLOW, 0.0)
	_shine = maxf(_shine - delta / SHINE_TIME, 0.0)
	for name: StringName in _pulses:
		var floor_at := PULSE_IDLE if bool(_unseen[name]) else 0.0
		_pulses[name] = maxf(float(_pulses[name]) - delta / PULSE_TIME, floor_at)
		if float(_pulses[name]) > 0.0:
			_clocks[name] = float(_clocks[name]) + delta
	if money > _shown_money:
		_shine = 1.0
		_shown_money = minf(
			_shown_money + maxf((money - _shown_money) * MONEY_RUN, MONEY_LEAST) * delta,
			money
		)
	elif money < _shown_money:
		# Spending is not a thing to celebrate, and a price the player just agreed to needs
		# no announcing. It simply drops.
		_shown_money = money
	_repaint()


## Whether the pointer is on one of the two picture buttons: the lake's edge scroll asks, so a
## hand going for a corner button does not slide the view out from under itself.
func over_button() -> bool:
	return _under(get_local_mouse_position()) != &""


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var was := _hovered
		_hovered = _under((event as InputEventMouseMotion).position)
		if was != _hovered:
			if _hovered != &"":
				Sfx.ui(&"ui_hover")
			queue_redraw()
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	match _under(click.position):
		&"shed":
			shed_pressed.emit()
			accept_event()
		&"upgrades":
			# The shed's door is its own sound (`Lake._set_shed`); the upgrades are a click.
			Sfx.ui(&"ui_click")
			upgrades_pressed.emit()
			accept_event()


## Which button, if any, is under a point. The money button is a readout rather than a
## control, so it is not offered.
func _under(at: Vector2) -> StringName:
	if _shed_box.has_point(at):
		return &"shed"
	if _upgrades_box.has_point(at):
		return &"upgrades"
	return &""


## Ask for a repaint, but only when the picture would come out different.
##
## The HUD used to end every `_process` with a bare `queue_redraw()`, which meant it
## reformatted and re-measured every string on it sixty times a second to draw the same
## plate again. Nothing here moves on its own — the meter and the money run to a figure and
## then stop — so the honest trigger is "a number I draw from has changed", and between
## sales that is nobody.
func _repaint() -> void:
	if _painted != _paint_key():
		queue_redraw()


## Everything the picture is made of, in one number. Quantised where it is eased, so a
## figure creeping through the sixth decimal does not count as a change.
func _paint_key() -> int:
	return hash([
		roundi(_shown * 4096.0), roundi(_shown_money * 64.0), roundi(_shine * 255.0),
		roundi(_shown_stock * 16.0), roundi(_stock_glow * 255.0), roundi(pulse_amount(&"upgrades") * 64.0), roundi(pulse_amount(&"shed") * 64.0),
		stock, available, hint, _hovered, siege.hash()
	])


func _draw() -> void:
	_painted = _paint_key()
	# The coin swells a little while the plate is lit, about its own middle and inside the
	# wood — the plate itself does not move. See `HudButtons.draw_money`.
	# Warmed rather than blown out: the coin is already the brightest thing on the plate, and
	# multiplying it half again pushes it past white and out the other side into green.
	_draw_money(
		_money_box, Color.WHITE.lerp(Style.SHINE_WASH, _ease_shine()),
		1.0 + SHINE_SWELL * _ease_shine()
	)
	# A hovered button lifts a pixel and brightens, which is the whole of the feedback. It
	# is a wooden sign, not a web page.
	# A pulsing button swells a few whole pixels and its glow is drawn under it, so the
	# wood covers the glow's inside and nothing on the face is tinted.
	HudButtons.pulse(self, _lifted(_shed_box, &"shed"), pulse_amount(&"shed"))
	HudButtons.draw_shed(self, _lifted(_shed_box, &"shed"), _hovered == &"shed", sprites)
	HudButtons.pulse(self, _lifted(_upgrades_box, &"upgrades"), pulse_amount(&"upgrades"))
	HudButtons.draw_upgrades(self, _lifted(_upgrades_box, &"upgrades"), _hovered == &"upgrades", sprites)
	_draw_stock()
	_draw_available()
	# The hint is its own node over the meter's sheets. See `HintLine`.
	_place_hint()
	if not siege.is_empty():
		_draw_siege()


## A line of plain text over the meter. No plate behind it: it is a note about the lake, and
## it belongs on the lake. Over rather than under because the meter sits on the bottom edge
## of the screen.
##
## **A node of its own, added after the meter's sheets** (2026-09-17, Richard: the line was
## showing behind the meter). It was written in this Control's own `_draw`, and the meter is
## four child TextureRects — children draw over their parent, so wherever the two met the
## wood won. And they met: the line was hung off the *frame's* top, while the garbage
## circle beside the frame stands a good way higher. So two things, either of which would
## have done: the line is drawn last, over every sheet, and it sits on the bar's top plank
## beside the circle (`hint_span`, `HINT_LIFT`) rather than over it.
class HintLine extends Control:
	var text := ""
	## Where the glyphs' baseline goes, and the box the line is centred on.
	var baseline := 0.0
	var across := Rect2()

	func _draw() -> void:
		if text.is_empty():
			return
		Style.write(
			self, text, Style.TEXT_BODY, Vector2(0.0, baseline),
			Style.GOLD.lerp(Style.INK, 0.5), HORIZONTAL_ALIGNMENT_CENTER, across
		)


var _hint_line: HintLine


## How far over the frame's top plank the line's baseline sits, in screen px. Tight, so
## the line reads as the meter's own caption rather than as a note floating over the lake.
##
## Zero, measured on `tools/last_pieces_left.png`: the face's capitals stop a few pixels
## short of their own baseline, and that is all the air the line wants. At 4 the ink stood
## ten screen pixels off the wood on 1080p and read as floating.
const HINT_LIFT := 0.0


## The stretch of the meter the line is centred on: the wooden bar clear of the garbage
## circle, from the circle's right edge to the frame's. **Not the whole meter and not the
## circle's top** (2026-09-17, Richard, second pass: hung over the circle it stood a long way
## above the bar and off to the left of it, dislocated from the thing it is about). The
## circle stands higher than the bar, so the line goes beside it, not over it.
func hint_span() -> Rect2:
	var scale := _meter_box.size.y / METER_SHEET.y
	var left := _meter_box.position.x + METER_CIRCLE.end.x * scale
	return Rect2(left, _meter_frame_box.position.y, _meter_frame_box.end.x - left, _meter_frame_box.size.y)


## The box the hint's glyphs take, on screen, or an empty one when nothing is said. Asked by
## the harness, so the check that keeps the line off the meter measures this layout.
func hint_box() -> Rect2:
	if hint.is_empty():
		return Rect2()
	var face := Style.font()
	var span := face.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1.0, Style.TEXT_BODY)
	var base := _hint_baseline()
	var across := hint_span()
	var left := across.position.x + (across.size.x - span.x) * 0.5
	return Rect2(left, base - face.get_ascent(Style.TEXT_BODY), span.x,
		face.get_ascent(Style.TEXT_BODY))


## The baseline, not the descender line, is what sits HINT_LIFT over the plank: the game's
## face sets everything in capitals, so the room a descender would want is empty, and
## leaving it lifted the line a dozen pixels clear of the wood it is supposed to sit on.
func _hint_baseline() -> float:
	return floorf(_meter_frame_box.position.y - HINT_LIFT)


func _place_hint() -> void:
	if _hint_line == null:
		_hint_line = HintLine.new()
		_hint_line.name = &"HintLine"
		_hint_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hint_line.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_hint_line)
	# Last among the children, whatever was added since: over every sheet of the meter.
	move_child(_hint_line, get_child_count() - 1)
	_hint_line.size = size
	_hint_line.text = hint
	_hint_line.baseline = _hint_baseline()
	_hint_line.across = hint_span()
	_hint_line.queue_redraw()


## What is happening to the shed, and what the player is holding.
##
## Two bars and a row of pips, under the money plate: the shed's health, the shield stacked
## in front of it, and one pip per live effect counting itself down. Drawn from flat rects
## rather than from the sheet, because the sheet is a painting of a fishing game and there
## is no plate in it for this.
func _draw_siege() -> void:
	var left := _money_box.position.x
	var top := _money_box.position.y + _money_box.size.y + GAP * 2.0

	var wave := int(siege.get("wave", 1))
	var waves := int(siege.get("waves", 0))
	var counted := "Wave %d" % wave if waves <= 0 else "Wave %d of %d" % [wave, waves]
	var note := String(siege.get("note", ""))
	var head := counted if note.is_empty() else "%s  —  %s" % [counted, note]
	# A big wave is named in its own colour, so the warning is not one more line of text to
	# read but a thing that has visibly changed.
	Style.write(
		self,
		head,
		Style.TEXT_SMALL,
		Vector2(left, top),
		Style.DANGER.lerp(Style.INK, 0.55) if bool(siege.get("big", false)) else Style.INK
	)
	top += SIEGE_GAP + 8.0

	_bar(
		Rect2(left, top, SIEGE_WIDE, SIEGE_BAR), float(siege.get("health", 1.0)),
		Style.DANGER, "Shed"
	)
	top += SIEGE_BAR + SIEGE_GAP
	_bar(
		Rect2(left, top, SIEGE_WIDE, SIEGE_BAR), float(siege.get("shield", 0.0)),
		Style.COOL, "Shield"
	)
	top += SIEGE_BAR + SIEGE_GAP + 2.0

	# One pip per thing that is currently true, in the order of the charms themselves.
	var pips := [
		[float(siege.get("ammo", 0.0)), CharmField.KIND_COLOURS[CharmField.Kind.AMMO]],
		[float(siege.get("fire", 0.0)), CharmField.KIND_COLOURS[CharmField.Kind.FIRE]],
		[float(siege.get("ice", 0.0)), CharmField.KIND_COLOURS[CharmField.Kind.ICE]],
	]
	var at := left
	for pip: Array in pips:
		var left_for := float(pip[0])
		if left_for <= 0.0:
			continue
		var tint: Color = pip[1]
		draw_circle(Vector2(at + SIEGE_PIP * 0.5, top + SIEGE_PIP * 0.5), SIEGE_PIP * 0.5, tint)
		Style.write(
			self,
			"%ds" % ceili(left_for),
			Style.TEXT_SMALL,
			Vector2(at + SIEGE_PIP + 4.0, top + SIEGE_PIP)
		)
		at += SIEGE_PIP + 32.0


## One labelled bar, filled left to right. The pollution meter, the shed's health and the
## shield in front of it are the same object, so they are the same helper.
func _bar(box: Rect2, fill: float, tint: Color, label: String) -> void:
	Style.bar(self, box, fill, tint, label)


## The meter's nodes. Four sheets over one another: the murky water (with the shader that
## blends the clean water into it), the frame, the garbage circle, and a face for the figure.
## Children rather than `draw_texture_rect` calls because they need a nearest filter and the
## rest of this node does not, and because the shader keeps the water moving on its own
## between readings without this node repainting.
##
## Any sheet missing means no meter at all rather than a meter with a hole in it.
func _build_meter() -> void:
	var murky := Art.texture(METER_ART + "Murky_Water.png")
	var clean := Art.texture(METER_ART + "Clean_Water.png")
	var circle := Art.texture(METER_ART + "Garbage_Circle.png")
	var frame := Art.texture(METER_ART + "Meter_Border.png")
	var shader := load("res://shaders/meter_water.gdshader") as Shader
	if murky == null or clean == null or circle == null or frame == null or shader == null:
		return
	_meter_shader = meter_material(shader, clean)
	_meter_water = _sheet_node(murky)
	_meter_water.material = _meter_shader
	# The frame first and the circle over it: the circle caps the frame's end, and drawn
	# under it the frame's corner showed through the bags as a splinter.
	#
	# **Built, not stamped** (2026-09-17): the sheet's own frame is drawn pre-scaled at
	# `METER_SCALE`, so its planks landed at 27 and 24 px while every other plate in the HUD
	# — whose frames `Style._build_border` crops out of *this same sheet* — landed at 16 and
	# 14. One wood at two thicknesses, side by side in the same corner. Built to the frame's
	# drawn box instead, the planks are the HUD's everywhere and the meter gains the V bites
	# every other frame has. `MeterFrame` falls back to stamping the sheet where the border
	# will not fit, so a small window keeps a frame rather than losing one.
	_meter_frame = MeterFrame.new()
	_meter_frame.sheet = frame
	_meter_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_meter_frame)
	_meter_circle = _sheet_node(circle)
	_meter_face = MeterFace.new()
	_meter_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_meter_face)
	_show_meter()


## How big the meter's art is drawn on a window this tall: `METER_SCALE` on a 1080-line
## window and in proportion on any other. Static for the loading screen's bar, which is the
## HUD's meter at the HUD's size and not a bigger drawing of it.
static func meter_scale(view_tall: float) -> float:
	return maxf(view_tall / METER_SCALE_LINES * METER_SCALE, 0.5)


## The meter's water, as a material: the clean sheet and where the track and the opaque
## water are on the sheet. Static, because the loading screen's bar is this same water in
## this same frame with no circle on its end (`MeterBar`), and two copies of these numbers
## are two meters the first time the art is re-cut.
static func meter_material(shader: Shader, clean: Texture2D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter(&"clean_tex", clean)
	material.set_shader_parameter(&"track_from", METER_TRACK.position.x / METER_SHEET.x)
	material.set_shader_parameter(&"track_to", METER_TRACK.end.x / METER_SHEET.x)
	material.set_shader_parameter(&"track_top", METER_TRACK.position.y / METER_SHEET.y)
	material.set_shader_parameter(&"track_bottom", METER_TRACK.end.y / METER_SHEET.y)
	# Texel centres of the opaque rectangle's first and last pixels, so a clamped sample
	# never lands between an opaque pixel and a soft one.
	material.set_shader_parameter(&"opaque", Vector4(
		(METER_OPAQUE.position.x + 0.5) / METER_SHEET.x,
		(METER_OPAQUE.position.y + 0.5) / METER_SHEET.y,
		(METER_OPAQUE.end.x - 0.5) / METER_SHEET.x,
		(METER_OPAQUE.end.y - 0.5) / METER_SHEET.y
	))
	return material


## Put the seam where `share` of the track is clean. The feather either side of it narrows
## near the ends, so a nearly-clean lake keeps its last sliver of filth and a full one does
## not fade off the left of its own track.
static func meter_seam(material: ShaderMaterial, share: float) -> void:
	var edge := METER_TRACK.position.x + METER_TRACK.size.x * clampf(share, 0.0, 1.0)
	var feather := minf(
		METER_TRACK.size.x * METER_FEATHER,
		maxf(minf(edge - METER_TRACK.position.x, METER_TRACK.end.x - edge) * 2.0, 1.0)
	)
	material.set_shader_parameter(&"seam", edge / METER_SHEET.x)
	material.set_shader_parameter(&"feather", feather / METER_SHEET.x)


func _sheet_node(art: Texture2D) -> TextureRect:
	var node := TextureRect.new()
	node.texture = art
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	return node


## Put the reading it is showing on the meter: the seam between filth and clean water, and
## the figure. The seam is where `_shown` falls along the track; the feather either side of
## it narrows near the ends, so a nearly-clean lake keeps its last sliver of filth and a full
## one does not fade off the left of its own track.
func _show_meter() -> void:
	if _meter_shader == null:
		return
	var share := clampf(_shown, 0.0, 1.0)
	meter_seam(_meter_shader, share)
	if _meter_face.shown != share:
		_meter_face.shown = share
		_meter_face.queue_redraw()


## The figure on the meter. The water says how the lake is doing at a glance and the number
## says whether the last hour of work moved it — a lake that is ninety-six per cent clean and
## a lake that is ninety-nine look the same on a track this long. Right-aligned, over the
## clean end, so it sits on water rather than on filth. Its own node so that it draws over
## the frame, which is a child drawn after this node's own `_draw`.
## The meter's wooden frame, built to its own drawn size rather than stamped from the sheet
## at `METER_SCALE`.
##
## `Style._build_border` makes a frame of any size out of the meter's own painted border,
## with its planks at a fixed 16 and 14 px — which is what every other plate in the HUD
## wears. Stamping the sheet scaled the planks with everything else and put 27 px of wood
## round the meter beside 16 px of the same wood round the stock plate.
##
## Where the border will not fit — a window small enough that `Style.border_fits` says no —
## it falls back to the painted sheet, drawn over the whole meter box as it always was. A
## frame at the wrong thickness beats no frame at all.
class MeterFrame extends Control:
	## The painted sheet, for the fallback only.
	var sheet: Texture2D = null
	## The whole meter's box on screen, in the parent's pixels: what the fallback stamps the
	## sheet over. The node's own rectangle is the wooden frame alone.
	var sheet_box := Rect2()

	func _draw() -> void:
		if Style.meter_frame(self, Rect2(Vector2.ZERO, size)):
			return
		if sheet != null:
			draw_texture_rect(sheet, Rect2(sheet_box.position - position, sheet_box.size), false)


class MeterFace extends Control:
	var shown: float = 1.0
	## The water's track, in this node's own pixels.
	var track := Rect2()

	func _draw() -> void:
		if track.size.x <= 0.0:
			return
		var height := Style.step(track.size.y * 0.52)
		var baseline := track.position.y + track.size.y * 0.5 + float(height) * 0.36
		Style.write(
			self,
			"%d%%" % roundi(shown * 100.0),
			height,
			Vector2(0.0, baseline),
			Style.INK,
			HORIZONTAL_ALIGNMENT_RIGHT,
			Rect2(track.position, Vector2(track.size.x - track.size.x * 0.03, track.size.y))
		)


func _lifted(box: Rect2, name: StringName) -> Rect2:
	# A pulse lifts the button the hover's way and the two stack; nothing is resized.
	box.position.y -= HudButtons.lift_by(pulse_amount(name))
	if _hovered != name:
		return box
	return Rect2(box.position - Vector2(0.0, Style.HOVER_LIFT), box.size)


## The shine, eased. Squared off at the front so it lands hard and lets go softly, which is
## the shape of being handed something.
func _ease_shine() -> float:
	return _shine * _shine


## A pulse as drawn: a slow wave, `PULSE_BEATS` a burst, under the envelope — full at the
## burst, `PULSE_IDLE` while the board is still unopened, nothing once it has been.
func pulse_amount(name: StringName) -> float:
	var left := float(_pulses.get(name, 0.0))
	if left <= 0.0:
		return 0.0
	var wave := 0.5 - 0.5 * cos(float(_clocks[name]) * TAU * PULSE_IDLE_RATE)
	return wave * left


## Put a pulse out: its board opening is the player seeing what was pending.
func hush_pulse(name: StringName) -> void:
	_pulses[name] = 0.0
	_unseen[name] = false


## Whether a pulse is running — the harness asks.
func pulsing(name: StringName) -> bool:
	return float(_pulses.get(name, 0.0)) > 0.0


## Where the coin on the money plate is, in the HUD's own coordinates: what a coin flying
## in from a sale (CoinFly) aims at. The same sum `HudButtons.draw_money` makes for the
## coin's box, so the two cannot drift.
func coin_centre() -> Vector2:
	var face := HudButtons.face_of(_money_box)
	var side := face.size.y
	var coin_box := Rect2(face.position, Vector2(side, side)).grow(-3.0)
	return coin_box.position + coin_box.size * 0.5


## A coin arrived: light the plate again, for the arrival and not only for the sum, which
## moved when the piece landed half a second earlier.
func shine() -> void:
	_shine = 1.0
	_repaint()


## What is waiting in the yard, on a strip of the money plate's own panel.
##
## Built out of the money plate's parts rather than given a plaque of its own, because it is
## the same kind of thing — a number the player checks — and the sheet has one panel drawn on
## it. Copying that keeps the two readouts obviously a pair.
## The face the border's planks leave inside the stock plate, and the two writing sizes that
## come off it. One place, because `_lay_out` measures the plate's width against them and
## `_draw_stock` writes with them: measured apart, the plate and its reading drift.
func _stock_face_tall() -> float:
	return STOCK_TALL - float(Style.BORDER_TOP + Style.BORDER_FOOT)


func _stock_count_size() -> int:
	return Style.step(_stock_face_tall() * STOCK_TEXT)


func _stock_label_size() -> int:
	return Style.step(_stock_face_tall() * STOCK_TEXT * STOCK_LABEL_SHARE)


func _draw_stock() -> void:
	var box := _stock_box
	# The meter's border round the box's own brown, the same wood the three buttons wear.
	if Style.border_fits(box):
		var face := Style.border_inset(box)
		draw_rect(face.grow(2.0), Style.BOX, true)
		Style.meter_frame(self, box)
		box = face
	else:
		Style.plank(self, box, 41, Style.BOX, Style.CLIP)
	# The recycle mark, on the left.
	var side := box.size.y - STOCK_MARK_PAD * 2.0
	var mark := Rect2(box.position + Vector2(STOCK_PAD, STOCK_MARK_PAD), Vector2(side, side))
	_draw_recycle_mark(mark)
	# The label, small and cream, after it.
	var x := mark.end.x + STOCK_MARK_PAD
	var middle := box.position.y + box.size.y * 0.5
	var label_size := _stock_label_size()
	var count_size := _stock_count_size()
	Style.write(
		self, STOCK_LABEL, label_size,
		Vector2(x, middle + float(label_size) * 0.35), Style.RIBBON_INK
	)
	x += Style.measure(STOCK_LABEL, label_size).x + STOCK_MARK_PAD
	# The count, on a sunken panel the colour of the box's hollow, in the mark's blue. The
	# panel is inset by `HudButtons.PANEL_INSET`, not five pixels: the wood takes thirty of the plate's
	# height whatever its size, so on a plate this short a generous inset is what would push
	# the reading off its own panel.
	var panel := Rect2(
		Vector2(x, box.position.y + HudButtons.PANEL_INSET),
		Vector2(box.end.x - STOCK_PAD - x, box.size.y - HudButtons.PANEL_INSET * 2.0)
	)
	draw_rect(panel.grow(1.0), Style.SEAM, true)
	draw_rect(panel, Style.BOX_HOLLOW, true)
	draw_rect(Rect2(panel.position, Vector2(panel.size.x, 1.0)), Style.SEAM, true)
	var shown := "%d" % roundi(_shown_stock)
	var glow := _stock_glow * _stock_glow
	var baseline := middle + float(count_size) * 0.35
	if glow > 0.01:
		Style.write(
			self, shown, count_size, Vector2(0.0, baseline - 1.0),
			Color(Style.BOX_BLUE_LIT.r, Style.BOX_BLUE_LIT.g, Style.BOX_BLUE_LIT.b, 0.55 * glow),
			HORIZONTAL_ALIGNMENT_CENTER, panel
		)
	Style.write(
		self, shown, count_size, Vector2(0.0, baseline),
		Style.BOX_BLUE_LIT.lerp(Style.INK, glow * 0.5),
		HORIZONTAL_ALIGNMENT_CENTER, panel
	)


## The recycle mark off the box's front: three chevron arrows chasing round a triangle,
## stamped into the plank — a round recess with a bevelled rim, and the arrows pressed into
## it with a dark line hugging their outline all the way round, the way a stamp's edge
## sinks. Drawn rather than cut from the box art, which is eleven pixels of it at an
## isometric slant.
func _draw_recycle_mark(box: Rect2) -> void:
	var middle := box.position + box.size * 0.5
	var recess := box.size.x * 0.56
	draw_circle(middle, recess + 1.5, Style.SEAM)
	draw_circle(middle, recess, Style.BOX_DEEP)
	# The rim of the recess: dark where it faces away from the light, lit where it faces it.
	draw_arc(middle, recess - 1.0, PI * 1.0, PI * 2.0, 16, Style.BOX_HOLLOW, 2.0)
	draw_arc(middle, recess - 1.0, 0.0, PI, 16, Style.BOX_LIT, 1.0)
	var shapes := _recycle_shapes(box)
	# The dark line round each arrow first, as a closed stroke: half of it lies outside the
	# fill drawn over it, and that half is the cut.
	for shape: PackedVector2Array in shapes:
		var ring := PackedVector2Array(shape)
		ring.append(shape[0])
		draw_polyline(ring, Style.SEAM, 3.0)
	for shape: PackedVector2Array in shapes:
		draw_colored_polygon(shape, Style.BOX_BLUE)


## The mark's three arms and heads as polygons, in the box given.
func _recycle_shapes(box: Rect2) -> Array:
	var middle := box.position + box.size * 0.5
	var reach := box.size.x * 0.40
	var thick := maxf(box.size.x * 0.16, 2.0)
	var out: Array = []
	for i in 3:
		var a := -PI * 0.5 + TAU * float(i) / 3.0
		var b := a + TAU / 3.0 - 0.55
		var strip := PackedVector2Array()
		var steps := 6
		for k in steps + 1:
			var t := lerpf(a, b, float(k) / float(steps))
			strip.append(middle + Vector2(cos(t), sin(t)) * (reach - thick * 0.5))
		for k in steps + 1:
			var t := lerpf(b, a, float(k) / float(steps))
			strip.append(middle + Vector2(cos(t), sin(t)) * (reach + thick * 0.5))
		out.append(strip)
		var tip := middle + Vector2(cos(b), sin(b)) * reach
		var on := Vector2(-sin(b), cos(b))
		var away := Vector2(cos(b), sin(b))
		out.append(PackedVector2Array([
			tip + on * thick * 1.3,
			tip + away * thick * 1.1,
			tip - away * thick * 1.1,
		]))
	return out




## The upgrades button's foot says **what the button is**, and the count rides a badge in its
## corner (2026-09-17).
##
## It used to read "n available" across the foot: a count with no noun — available what? —
## and the only thing in the HUD whose width moved with its own number, so the panel breathed
## in and out as the purse filled. The word is fixed now and the number has its own small
## plate, which is the convention every game uses for a count of things waiting.
##
## Still always there, zero included, which was the old rule and a good one: a badge that
## comes and goes is a thing the player has to notice the absence of. At zero it is drawn
## back rather than hidden.
func _draw_available() -> void:
	var face := HudButtons.face_of(_lifted(_upgrades_box, &"upgrades"))
	HudButtons.label(self, face, UPGRADES_LABEL)
	HudButtons.badge(self, face, str(available), available > 0, pulse_amount(&"upgrades"))


## The money plate: the coin, the sunken panel, and the live figure on it.
func _draw_money(box: Rect2, wash: Color, swell: float) -> void:
	var plate := HudButtons.draw_money(self, box, wash, swell)
	var height := Style.step(plate.size.y * 0.72)
	# The running figure, not the real one: the plate is meant to be watched climbing.
	var shown := "%d" % roundi(_shown_money)
	var baseline := plate.position.y + plate.size.y * 0.5 + float(height) * 0.35
	# Lit from behind while it is climbing, which is what turns a number going up into
	# something being handed over.
	var glow := _ease_shine()
	if glow > 0.01:
		Style.write(
			self,
			shown,
			height,
			Vector2(0.0, baseline - 1.0),
			Color(Style.GOLD.r, Style.GOLD.g, Style.GOLD.b, 0.55 * glow),
			HORIZONTAL_ALIGNMENT_CENTER,
			plate
		)
	Style.write(
		self,
		shown,
		height,
		Vector2(0.0, baseline),
		Style.GOLD.lerp(Style.INK, glow * SHINE_LIFT),
		HORIZONTAL_ALIGNMENT_CENTER,
		plate
	)
