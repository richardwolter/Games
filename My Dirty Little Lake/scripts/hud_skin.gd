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
## A spend's "-X" tag: how long it lives, how far it falls in that time (a share of the
## plate's height), and how many can be up at once. First guesses.
const SPENT_LIFE := 1.4
const SPENT_FALL := 0.9
const SPENT_MOST := 4
## A warm red, lifted to read over the lake and the shop's dim alike.
const SPENT_INK := Color(0.93, 0.42, 0.34)

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
## The plate's word is `Text.HUD_WAITING`, read at draw time so a language switch shows at once.

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
## The button's word is `Text.HUD_UPGRADES`, read at draw time.
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

## The ferry bar under the Waiting plate (2026-10-15, issue #41): how far through its run the
## hull that comes home first is, 0 to 1, or -1 for no run; and with none out, how full the
## docked hull's next load is, 0 to 1, or -1. The lake sets both every frame.
var ferry_trip: float = -1.0
var ferry_fill: float = -1.0
## The bar's height, in the gap between the Waiting and money plates, and its two fills: the
## recycle mark's blue for a run, a warm amber for a hold filling at the berth.
const FERRY_BAR_TALL := 6.0
const FERRY_TRIP_INK := Style.BOX_BLUE_LIT
const FERRY_FILL_INK := Color(0.93, 0.74, 0.40)
## The little ferry riding the bar's end, so the bar says what it is about (Richard,
## 2026-10-15): the ferry's own sprite heading right (`sprites["boat_right"]`), this tall, its keel sunk this
## far into the groove, bobbing a whole pixel at `FERRY_BOB` cycles a second while a run is
## out, still at the berth.
const FERRY_BOAT_TALL := 18.0
const FERRY_BOAT_SINK := 3.0
const FERRY_BOB := 1.3
var _ferry_clock := 0.0

## The jar plate (2026-10-16, `/grill-me` with Richard; `Lake.HONEY_TIME`): the hive's jars of
## honey, eaten for a window of better pay. **A third slab in the top-left column**, under the
## money plate, in the same oak border, shown only while there is a jar to eat or a window
## running (never in the demo: the lake hands it nothing there). A click eats one
## (`honey_pressed`).
##
## **The medallion slab** (2026-10-18, Richard's pick 1A off `tools/hive_look/last_honey.png`):
## the money plate's grammar, the picture, the figure on its sunk panel, the key, and no word
## (the jar says it, and it is one string fewer in eight languages). The face is the comb's
## brown with a faint honeycomb pressed into it. Over the slab's left end, wood and all, a round
## medallion with **the honey pot** standing in its well (`HoneyPot.draw_hud`, the one jar the
## hive's rooms, the shelf and the cue card draw): lidded and full while it waits; eaten, the
## same jar with its lid off and a dipper in it, its honey the time left, and the ring round the
## well draining clockwise from twelve o'clock in gold (`_medal`). Idle the ring is an empty
## groove. The count stands on a narrow sunk panel, the eat key in a 22 px box beside it (the
## house's wood chip, or the pad's glyph alone in the same box), so the plate never moves
## between devices. The slab is only as long as those three need.
## The plate's height, the medallion's radius over the slab's left end, the count's panel.
const HONEY_TALL := MONEY_TALL
const HONEY_MEDAL := 20
const HONEY_PANEL_WIDE := 44.0
## The key's box, one size for both devices.
const HONEY_CHIP := 22.0
## The gaps: medallion to panel, panel to key, key to the right wall.
const HONEY_GAPS := Vector3(5.0, 7.0, 5.0)
## The ring: its thickness inside the medallion, and how many steps its drain is drawn in.
const HONEY_RING := 3
const HONEY_RING_STEPS := 96
## Colours: the comb's browns (the hive's honey a long way down towards the outline, mixes of
## in-game swatches), the ring's gold and its shine, the count's ink and drawn back with no jar
## left (the window still running). Both inks clear 4.5:1 on `HONEY_PANEL`.
const HONEY_OUTLINE := Color8(24, 18, 17)
const HONEY_FACE := Color8(84, 44, 15)
const HONEY_CELL := Color8(102, 51, 14)
const HONEY_CELL_DIM := Color8(93, 48, 14)
const HONEY_PANEL := Color8(57, 32, 16)
const HONEY_WELL := Color8(74, 40, 15)
const HONEY_INK := Color8(252, 204, 84)
const HONEY_INK_DIM := Color(0.68, 0.53, 0.33)

## Emitted when the jar plate is clicked. The lake decides whether a jar is eaten.
signal honey_pressed
## Jars held, seconds of honey left, and the whole window those seconds were eaten into (the
## drain is `honey_left / honey_span`). Set by the lake every frame; 0 and 0 hide the plate.
var honey_jars: int = 0
var honey_left: float = 0.0
var honey_span: float = 0.0
var _honey_box := Rect2()
## The plate's baked pictures: its comb face by size, its medallion by drain step.
var _honey_combs := {}
var _honey_medals := {}

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
## The hop (2026-10-05, pick A off `tools/last_pulse_mockup.gif`): the burst hops on each of
## its first `BURST_HOPS` beats at full height; once it has settled the button hops once
## every `IDLE_HOP_EVERY` seconds (rolled) at `IDLE_HOP` of the height, until the board is
## opened. Motes drift up off the button at `MOTES_BURST` a second in the burst and
## `MOTES_IDLE` after it.
const BURST_HOPS := 3
const IDLE_HOP := 0.6
const IDLE_HOP_EVERY := Vector2(4.0, 6.0)
const MOTES_BURST := 30.0
const MOTES_IDLE := 8.0
## Per button: seconds into an idle hop (-1 none), seconds to the next one, the motes.
var _idle_hop := {&"upgrades": -1.0, &"shed": -1.0}
var _idle_wait := {&"upgrades": 0.0, &"shed": 0.0}
var _motes := {&"upgrades": HudButtons.Motes.new(11), &"shed": HudButtons.Motes.new(23)}
var _hop_rng := RandomNumberGenerator.new()


func _mark(name: StringName, value: int) -> void:
	if int(_marks[name]) >= 0 and value > int(_marks[name]):
		_pulses[name] = 1.0
		_clocks[name] = 0.0
		_unseen[name] = true
	_marks[name] = value

## A line under the meter, or empty for nothing. Used for the one thing the meter cannot
## say: that the lake reads clean and is not.
var hint: String = ""

## The figure actually on the plate, and how brightly it is still lit from the last payment.
var _shown_money: float = 0.0
## The money as it was last frame, to tell a spend from the figure still running, and the
## "-X" tags falling off the plate: `{amount, age}`.
var _last_money: float = 0.0
var _spent: Array[Dictionary] = []

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
## Where the shop has hung the money plate while it is up; empty the rest of the time.
var purse_over := Rect2():
	set(value):
		if value == purse_over:
			return
		purse_over = value
		queue_redraw()
		if _purse != null:
			_purse.visible = value.size.x > 0.0
			_purse.queue_redraw()
var _purse: Purse
## The wash room's view of the HUD (2026-10-01, Richard: "show money and waiting UI on
## washing station"): only the money and Waiting plates, in their own corner, over the room.
## The meter, the buttons and the hint are hidden, and the skin takes no clicks, so the room
## under it answers them.
var plates_only := false:
	set(value):
		if value == plates_only:
			return
		plates_only = value
		mouse_filter = Control.MOUSE_FILTER_IGNORE if value else Control.MOUSE_FILTER_PASS
		for child in get_children():
			(child as CanvasItem).visible = not value
		_hovered = &""
		queue_redraw()
var _money_box := Rect2()
var _stock_box := Rect2()
var _hovered := &""

## What the last painted picture was made of. See `_paint_key`.
var _painted: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_purse = Purse.new()
	_purse.name = &"Purse"
	_purse.skin = self
	_purse.visible = false
	_purse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_purse.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_purse.set_anchors_preset(Control.PRESET_FULL_RECT)
	# After everything else on the HUD layer, the shop included, once the layer is built.
	get_parent().add_child.call_deferred(_purse)
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
		+ STOCK_MARK_PAD + Style.measure(Text.HUD_WAITING, _stock_label_size()).x + STOCK_MARK_PAD
		+ Style.measure(STOCK_SAMPLE, _stock_count_size()).x + 12.0
	)
	_stock_box = Rect2(EDGE + 2.0, EDGE, stock_wide, STOCK_TALL)
	# The same width as the stock plate, under it: two slabs of one width.
	_money_box = Rect2(
		_stock_box.position.x, _stock_box.position.y + STOCK_TALL + GAP, stock_wide, MONEY_TALL
	)
	# And the jar plate under that, left edge on the column's, only as long as it needs.
	_honey_box = Rect2(_money_box.position.x, _money_box.end.y + GAP, _honey_wide(), HONEY_TALL)
	queue_redraw()


## Put the meter on `pollution` at once, with no ease: for a load, where the lake is simply
## as it was left rather than being cleaned in front of the player.
func snap_meter() -> void:
	_shown = clampf(pollution, 0.0, 1.0)
	_show_meter()


func _process(delta: float) -> void:
	_ferry_clock += delta
	var wanted := clampf(pollution, 0.0, 1.0)
	# Exactly, not approximately: a sliver left over the empty lake rounds up to 1%.
	if _shown != wanted:
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
		_step_hop(name, delta)
	if money > _shown_money:
		_shine = 1.0
		_shown_money = minf(
			_shown_money + maxf((money - _shown_money) * MONEY_RUN, MONEY_LEAST) * delta,
			money
		)
	elif money < _shown_money:
		# Spent (2026-09-26, Richard): the figure runs down at the pace it runs up, and what
		# left drops off the plate as a "-X" tag. No shine: spending is not a thing to
		# celebrate. A tag is only made for money that goes while the figure is at rest, so a
		# second buy during the run adds its own tag rather than folding into the first.
		if money < _last_money:
			_spent.append({"amount": roundi(_last_money - money), "age": 0.0})
			if _spent.size() > SPENT_MOST:
				_spent.pop_front()
		_shown_money = maxf(
			_shown_money - maxf((_shown_money - money) * MONEY_RUN, MONEY_LEAST) * delta,
			money
		)
	_last_money = money
	for tag: Dictionary in _spent:
		tag["age"] = float(tag["age"]) + delta
	while not _spent.is_empty() and float(_spent[0]["age"]) >= SPENT_LIFE:
		_spent.pop_front()
	_repaint()


## The idle hop's clock and the motes for one button. The burst's hops are read straight
## off its clock (`hop_of`); only the idle ones are scheduled.
func _step_hop(name: StringName, delta: float) -> void:
	var live := float(_pulses[name]) > 0.0
	var clock := float(_clocks[name])
	var burst := live and clock < PULSE_TIME
	if live and not burst:
		if float(_idle_hop[name]) >= 0.0:
			_idle_hop[name] = float(_idle_hop[name]) + delta
			if float(_idle_hop[name]) >= _beat():
				_idle_hop[name] = -1.0
				_idle_wait[name] = _hop_rng.randf_range(IDLE_HOP_EVERY.x, IDLE_HOP_EVERY.y)
		else:
			_idle_wait[name] = float(_idle_wait[name]) - delta
			if float(_idle_wait[name]) <= 0.0:
				_idle_hop[name] = 0.0
	else:
		_idle_hop[name] = -1.0
		_idle_wait[name] = _hop_rng.randf_range(IDLE_HOP_EVERY.x, IDLE_HOP_EVERY.y) * 0.5
	var rate := 0.0
	if live:
		rate = MOTES_BURST if burst else MOTES_IDLE
	var box := _upgrades_box if name == &"upgrades" else _shed_box
	(_motes[name] as HudButtons.Motes).step(delta, rate, _lifted(box, name))


static func _beat() -> float:
	return PULSE_TIME / PULSE_BEATS


## How high a button is in its hop (0 to 1) and how squashed (0 to 1), its strength in.
func hop_of(name: StringName) -> Vector2:
	if float(_pulses.get(name, 0.0)) <= 0.0:
		return Vector2.ZERO
	var clock := float(_clocks[name])
	if clock < _beat() * BURST_HOPS:
		return HudButtons.hop_shape(fmod(clock, _beat()) / _beat())
	var t := float(_idle_hop[name])
	if t < 0.0:
		return Vector2.ZERO
	return HudButtons.hop_shape(t / _beat()) * IDLE_HOP


## Whether anything of a pulse is moving: a hop in the air or motes still drifting.
func _pulse_moving() -> bool:
	for name: StringName in _pulses:
		if hop_of(name) != Vector2.ZERO or (_motes[name] as HudButtons.Motes).alive() > 0:
			return true
	return false


## Whether the pointer is on one of the two picture buttons: the lake's edge scroll asks, so a
## hand going for a corner button does not slide the view out from under itself.
## The upgrades button's box, for a hint to point at.
func upgrades_box() -> Rect2:
	return _upgrades_box


## The decorate button's box, for the decoration tour's hint to point at.
func shed_box() -> Rect2:
	return _shed_box


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
		&"honey":
			# Taken here, so the click on the plate is never also a cast on the lake under it.
			Sfx.ui(&"ui_click")
			honey_pressed.emit()
			accept_event()


## Which button, if any, is under a point. The money button is a readout rather than a
## control, so it is not offered. The jar plate is, while it is shown.
func _under(at: Vector2) -> StringName:
	if _shed_box.has_point(at):
		return &"shed"
	if _upgrades_box.has_point(at):
		return &"upgrades"
	if honey_shown() and _honey_hit().has_point(at):
		return &"honey"
	return &""


## What a press on the jar plate covers: the plate, and while a window runs the drain hung
## under it as well, ringed seam and all. The bar reads as part of the control, so a press on
## it eats rather than falling through to the lake and throwing the net at the corner.
func _honey_hit() -> Rect2:
	if honey_left <= 0.0:
		return _honey_box
	return _honey_box.merge(honey_bar_box().grow(1.0))


## Whether the jar plate is drawn: a jar to eat or a window running, and not in the wash
## room's two-plate view.
func honey_shown() -> bool:
	return not plates_only and (honey_jars > 0 or honey_left > 0.0)


## The jar plate's box, in the skin's own pixels, or an empty one while it is not shown: what
## the first jar's hint points at, and what the harness measures.
func honey_box() -> Rect2:
	return _honey_box if honey_shown() else Rect2()


## Ask for a repaint, but only when the picture would come out different.
##
## The HUD used to end every `_process` with a bare `queue_redraw()`, which meant it
## reformatted and re-measured every string on it sixty times a second to draw the same
## plate again. Nothing here moves on its own — the meter and the money run to a figure and
## then stop — so the honest trigger is "a number I draw from has changed", and between
## sales that is nobody.
func _repaint() -> void:
	if _painted != _paint_key() or _pulse_moving():
		queue_redraw()
		if _purse != null and _purse.visible:
			_purse.queue_redraw()


## Everything the picture is made of, in one number. Quantised where it is eased, so a
## figure creeping through the sixth decimal does not count as a change.
func _paint_key() -> int:
	return hash([
		roundi(_shown * 4096.0), roundi(_shown_money * 64.0), roundi(_shine * 255.0), _spent_key(),
		roundi(_shown_stock * 16.0), roundi(_stock_glow * 255.0), roundi(pulse_amount(&"upgrades") * 64.0), roundi(pulse_amount(&"shed") * 64.0),
		stock, available, hint, _hovered, plates_only, Pad.is_pad(),
		roundi(ferry_trip * 200.0), roundi(ferry_fill * 200.0), _ferry_bob(),
		_honey_key()
	])


## The jar plate's part of the picture: the count, the drain to the pixel, and what the key
## chip says (read off the binds, not off `Binds.shown`, which asks the OS for a label).
func _honey_key() -> Array:
	if not honey_shown():
		return [false]
	return [honey_jars, roundi(_honey_share() * float(HONEY_RING_STEPS)), HoneyPot.hud_level(_honey_share()) if honey_left > 0.0 else -1,
		Binds.bound(&"eat_honey", "key"), Binds.bound(&"eat_honey", "pad"), Pad.is_pad()]


func _spent_key() -> int:
	var key := 0
	for tag: Dictionary in _spent:
		key = key * 31 + roundi(float(tag["age"]) * 60.0)
	return key


func _draw() -> void:
	_painted = _paint_key()
	if plates_only:
		_draw_money(
			self, _money_box, Color.WHITE.lerp(Style.SHINE_WASH, _ease_shine()),
			1.0 + SHINE_SWELL * _ease_shine()
		)
		_draw_stock()
		_draw_ferry_bar()
		return
	# The coin swells a little while the plate is lit, about its own middle and inside the
	# wood — the plate itself does not move. See `HudButtons.draw_money`.
	# Warmed rather than blown out: the coin is already the brightest thing on the plate, and
	# multiplying it half again pushes it past white and out the other side into green.
	# Its spend tags wait for the end: they fall across the jar plate under it (2026-10-16).
	var money: Array = []
	if not _purse_up():
		money = _draw_money(
			self, _money_box, Color.WHITE.lerp(Style.SHINE_WASH, _ease_shine()),
			1.0 + SHINE_SWELL * _ease_shine(), false
		)
	# A hovered button lifts a pixel and brightens, which is the whole of the feedback. It
	# is a wooden sign, not a web page.
	# A pulsing button hops and squashes as it lands (`hop_of`, `_lifted`): the squash is a
	# transform over the whole drawing (`HudButtons.base`), so nothing is laid out again.
	var shed := _lifted(_shed_box, &"shed")
	_squash(shed, hop_of(&"shed").y)
	HudButtons.draw_shed(self, shed, _hovered == &"shed", sprites)
	var upgrades := _lifted(_upgrades_box, &"upgrades")
	_squash(upgrades, hop_of(&"upgrades").y)
	HudButtons.draw_upgrades(self, upgrades, _hovered == &"upgrades", sprites)
	_draw_available()
	_squash(Rect2(), 0.0)
	# On the pad each button wears the button that opens it, on its top-left corner
	# (2026-10-28, Richard): the decorate button X, the upgrades button Y.
	if Pad.is_pad():
		for pair: Array in [[shed, &"open_shed"], [upgrades, &"open_upgrades"]]:
			var glyph := Glyphs.of_action(pair[1])
			if glyph != null:
				Glyphs.draw_centred(self, glyph, (pair[0] as Rect2).position + Vector2(8.0, 8.0), Glyphs.prompt_px() * 1.5)
	for name: StringName in _motes:
		(_motes[name] as HudButtons.Motes).draw(self)
	_draw_stock()
	_draw_ferry_bar()
	# After the squash is put straight: the jar is fitted with `HudButtons.fit`, which reads it.
	_draw_honey()
	if not money.is_empty():
		_draw_spent(self, money[0] as Rect2, int(money[1]), float(money[2]))
	# The hint is its own node over the meter's sheets. See `HintLine`.
	_place_hint()


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
		# A size down rather than past the bar's span (the demo's "%d upgrades left" in French
		# is 248 px at the body size, 2026-10-15).
		var px := Style.TEXT_BODY
		for step: int in [Style.TEXT_SMALL, Style.TEXT_TINY]:
			if across.size.x <= 0.0 or Style.measure(text, px).x <= across.size.x:
				break
			px = step
		Style.write(
			self, text, px, Vector2(0.0, baseline),
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


## The figure the meter writes: how much of the lake is cleaned, as a whole percent, 100 only
## when nothing is left. `shown` is the dirty share, 1 to 0.
static func cleaned_figure(shown: float) -> int:
	if shown <= 0.0:
		return 100
	return 100 - maxi(ceili(shown * 100.0 - 0.0001), 1)


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
			# The share cleaned, counting up from 0% (2026-10-15, issue #41: a demo player
			# wanted to see it go up, not down). "100%" is the finished lake and nothing else
			# (Richard, 2026-09-25): the dirty share is rounded up before it is taken off, so
			# the last half percent in the water still reads 99%. `_check_cleaned` zeroes
			# `pollution` outright, so the float dust never holds 99.
			"%d%%" % HudSkin.cleaned_figure(shown),
			height,
			Vector2(0.0, baseline),
			Style.INK,
			HORIZONTAL_ALIGNMENT_RIGHT,
			Rect2(track.position, Vector2(track.size.x - track.size.x * 0.03, track.size.y))
		)


## Squash what is drawn next about a box's foot, or put the canvas straight with nought.
func _squash(box: Rect2, squash: float) -> void:
	HudButtons.base = HudButtons.squash_about(box, squash)
	draw_set_transform_matrix(HudButtons.base)


func _lifted(box: Rect2, name: StringName) -> Rect2:
	# A hop lifts the button the hover's way and the two stack, in whole pixels.
	box.position.y -= roundf(hop_of(name).x * HudButtons.HOP_PX)
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
	var face := HudButtons.face_of(money_drawn_box())
	var side := face.size.y
	var coin_box := Rect2(face.position, Vector2(side, side)).grow(-3.0)
	return coin_box.position + coin_box.size * 0.5


## Where the money plate is drawn this frame: its corner, or the spot the shop hangs it in.
func money_drawn_box() -> Rect2:
	return purse_over if _purse_up() else _money_box


## Where the pollution meter is, in the skin's own coordinates: its hint points at it.
func meter_box() -> Rect2:
	return _meter_box


## Where the Waiting plate is, in the skin's own coordinates: the ferries' hint points at it.
func stock_box() -> Rect2:
	return _stock_box


## The money plate's own size, for the shop to find it a spot.
func money_size() -> Vector2:
	return _money_box.size


func _purse_up() -> bool:
	return purse_over.size.x > 0.0


## The money plate over the upgrades shop (2026-09-24, Richard: the player could not see
## what they had while choosing what to buy). The same plate, drawn by the same function with
## the same running figure and shine — one purse, not a second readout — on a node that stands
## after the shop in the HUD layer, so the shop's dimming and boards are under it. The shop
## says where (`ShopSkin.purse_box`); the lake sets `purse_over` while the board is up and
## clears it after. Coins in flight aim at it there, through `coin_centre`.
class Purse:
	extends Control
	var skin: HudSkin

	func _draw() -> void:
		if skin == null or not skin._purse_up():
			return
		var shine := skin._ease_shine()
		skin._draw_money(
			self, skin.purse_over, Color.WHITE.lerp(Style.SHINE_WASH, shine),
			1.0 + SHINE_SWELL * shine
		)


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


## Where the ferry bar is drawn: in the gap under the Waiting plate, inset by the plate's
## side walls so it reads as hanging off the plate rather than off the screen's edge.
func ferry_bar_box() -> Rect2:
	var y := _stock_box.end.y + (GAP - FERRY_BAR_TALL) * 0.5
	return Rect2(
		_stock_box.position.x + float(Style.BORDER_WALL), y,
		_stock_box.size.x - float(Style.BORDER_WALL * 2), FERRY_BAR_TALL
	)


## The bar: a groove sunk the way the count's panel is, filled from the left.
func _draw_ferry_bar() -> void:
	var share := ferry_trip if ferry_trip >= 0.0 else ferry_fill
	if share < 0.0:
		return
	var box := ferry_bar_box()
	draw_rect(box.grow(1.0), Style.SEAM, true)
	draw_rect(box, Style.BOX_HOLLOW, true)
	var ink := FERRY_TRIP_INK if ferry_trip >= 0.0 else FERRY_FILL_INK
	var filled := Rect2(box.position, Vector2(roundf(box.size.x * clampf(share, 0.0, 1.0)), box.size.y))
	if filled.size.x > 0.0:
		draw_rect(filled, ink, true)
		draw_rect(Rect2(filled.position, Vector2(filled.size.x, 1.0)), ink.lightened(0.3), true)
	var boat := ferry_boat_box()
	if boat.size.x > 0.0:
		HudButtons.fit(self, sprites["boat_right"], boat, 1.0, Color.WHITE, true, false)


## Where the little ferry is drawn: at the end of the fill, held inside the bar's ends, its
## keel in the groove. Empty with no bar or no sprite.
func ferry_boat_box() -> Rect2:
	var share := ferry_trip if ferry_trip >= 0.0 else ferry_fill
	if share < 0.0 or not sprites.has("boat_right"):
		return Rect2()
	var bar := ferry_bar_box()
	var span := HudButtons.span_of(sprites["boat_right"], Vector2(INF, FERRY_BOAT_TALL), 1.0).round()
	if span.x <= 0.0:
		return Rect2()
	var x := bar.position.x + roundf(bar.size.x * clampf(share, 0.0, 1.0)) - span.x * 0.5
	x = clampf(x, bar.position.x - span.x * 0.25, bar.end.x - span.x * 0.75)
	var foot := bar.position.y + FERRY_BOAT_SINK - float(_ferry_bob())
	return Rect2(Vector2(roundf(x), foot - span.y), span)


## The bob, a whole pixel up and down while a run is out.
func _ferry_bob() -> int:
	if ferry_trip < 0.0:
		return 0
	return 1 if sin(_ferry_clock * TAU * FERRY_BOB) > 0.0 else 0


## How much of the honey window is left, 1 just eaten to 0 run out.
func _honey_share() -> float:
	if honey_left <= 0.0:
		return 0.0
	return clampf(honey_left / maxf(honey_span, honey_left), 0.0, 1.0)


## The plate's width: the medallion, the count's panel, the key and the wood round them.
static func _honey_wide() -> float:
	return (1.0 + float(HONEY_MEDAL * 2) + HONEY_GAPS.x + HONEY_PANEL_WIDE + HONEY_GAPS.y
		+ HONEY_CHIP + HONEY_GAPS.z + float(Style.BORDER_WALL))


## The medallion's middle: on a pixel corner, over the slab's left end.
func _honey_medal_at(box: Rect2) -> Vector2:
	return Vector2(floorf(box.position.x) + float(HONEY_MEDAL) + 1.0,
		floorf(box.position.y) + floorf(box.size.y * 0.5))


## Where the drain is drawn: the ring round the medallion, which is part of the plate.
func honey_bar_box() -> Rect2:
	var mid := _honey_medal_at(_honey_box)
	var r := float(HONEY_MEDAL)
	return Rect2(mid - Vector2(r, r), Vector2(r, r) * 2.0)


## The jar plate: the comb face in the oak border, the medallion with the honey pot and its
## draining ring, the count on its panel and the eat key.
func _draw_honey() -> void:
	if not honey_shown():
		return
	var box := _lifted(_honey_box, &"honey")
	var hovered := _hovered == &"honey"
	var tint := Style.HOVER_WASH if hovered else Color.WHITE
	var face: Rect2
	if Style.border_fits(box):
		face = Style.border_inset(box)
		var comb := _honey_comb(face.size)
		draw_texture(comb, face.position - Vector2(2.0, 2.0), tint)
		Style.meter_frame(self, box, tint)
	else:
		face = HudButtons.board(self, box, hovered, HONEY_FACE)
	var mid := _honey_medal_at(box)
	var running := honey_left > 0.0
	var step := roundi(_honey_share() * float(HONEY_RING_STEPS)) if running else 0
	var medal := _honey_medal(step)
	draw_texture(medal, mid - Vector2(medal.get_size()) * 0.5, tint)
	# The sealed jar stands centred in the well on its body, the same pot as the cue card's.
	var feet := mid + Vector2(0.0, 9.0)
	if HoneyPot.ready():
		HoneyPot.draw_hud(self, feet, _honey_share() if running else -1.0)
	else:
		_draw_jar_cells(Rect2(mid - Vector2(10.0, 11.0), Vector2(20.0, 22.0)))
	var panel := Rect2(
		Vector2(mid.x + float(HONEY_MEDAL) + HONEY_GAPS.x, face.position.y + 2.0),
		Vector2(HONEY_PANEL_WIDE, face.size.y - 4.0)
	)
	HudButtons.sunk(self, panel, HONEY_PANEL)
	var size := Style.TEXT_HEAD
	Style.write(
		self, "%d" % honey_jars, size,
		Vector2(0.0, panel.get_center().y + float(size) * 0.35),
		HONEY_INK if honey_jars > 0 else HONEY_INK_DIM, HORIZONTAL_ALIGNMENT_CENTER, panel
	)
	var chip := Rect2(
		Vector2(panel.end.x + HONEY_GAPS.y, floorf(box.position.y + (box.size.y - HONEY_CHIP) * 0.5)),
		Vector2(HONEY_CHIP, HONEY_CHIP)
	)
	_draw_honey_chip(chip)


## The eat key in its box: the house's own key chip (`ShedRoom._draw_key`: the wood at 0.85
## over what is under it, a pale rim, the key in ink), or the pad's glyph standing alone in
## the same box in pad mode, at whole screen pixels.
func _draw_honey_chip(chip: Rect2) -> void:
	var shown := Binds.shown(&"eat_honey", Pad.is_pad())
	var glyph := Glyphs.lone(shown)
	if glyph != null:
		Glyphs.draw_centred(self, glyph, chip.get_center())
		return
	draw_rect(chip, Color(Style.WOOD.r, Style.WOOD.g, Style.WOOD.b, 0.85), true)
	draw_rect(chip.grow(-0.5), Style.INK_DIM, false, 1.0)
	var size := Style.TEXT_BODY
	if Style.measure(shown, size).x > chip.size.x - 4.0:
		size = Style.TEXT_SMALL
	Style.write(
		self, shown, size, Vector2(0.0, chip.get_center().y + float(size) * 0.36),
		Style.INK, HORIZONTAL_ALIGNMENT_CENTER, chip
	)


## The plate's face, `size` of it, grown two pixels under the wood: the comb's brown with a
## honeycomb pressed into it, hex cells six wide on rows four apart, whole pixels. Baked once.
func _honey_comb(size: Vector2) -> Texture2D:
	var key := Vector2i(size)
	if _honey_combs.has(key):
		return _honey_combs[key]
	var w := key.x
	var h := key.y
	var image := Image.create(w + 4, h + 4, false, Image.FORMAT_RGBA8)
	image.fill(HONEY_FACE)
	var hexa := [".xx.", "x..x", "x..x", ".xx."]
	for r in range(-1, h / 4 + 2):
		for c in range(-1, w / 6 + 2):
			var ox := c * 6 + (3 if posmod(r, 2) == 1 else 0)
			var oy := r * 4 - 1
			for j in hexa.size():
				var row: String = hexa[j]
				for i in row.length():
					var x := ox + i
					var y := oy + j
					if row[i] == "x" and x >= 0 and x < w and y >= 0 and y < h:
						image.set_pixel(x + 2, y + 2, HONEY_CELL_DIM)
	var tex := ImageTexture.create_from_image(image)
	_honey_combs[key] = tex
	return tex


## The medallion at drain step `step` of `HONEY_RING_STEPS` (0 is the empty groove): a disc in
## the outline over the slab's end, the well the jar stands in, and the ring round the well,
## its gold arc `step` of the way round clockwise from twelve o'clock, the leading pixel its
## shine, the drained arc a dark groove. Baked once a step.
func _honey_medal(step: int) -> Texture2D:
	if _honey_medals.has(step):
		return _honey_medals[step]
	var outer := HONEY_MEDAL
	var side := (outer + 2) * 2
	var c := float(outer + 2)
	var r_out := float(outer - 1)
	var inner := r_out - float(HONEY_RING) - 1.0
	var share := float(step) / float(HONEY_RING_STEPS)
	var image := Image.create(side, side, false, Image.FORMAT_RGBA8)
	for y in side:
		for x in side:
			var dx := float(x) + 0.5 - c
			var dy := float(y) + 0.5 - c
			var r := sqrt(dx * dx + dy * dy)
			if r >= float(outer) + 1.0:
				continue
			var col := HONEY_OUTLINE if r >= float(outer) else HONEY_FACE
			if r < inner:
				col = HONEY_WELL
			if r >= r_out - float(HONEY_RING) and r < r_out:
				var a := fposmod(atan2(dx, -dy) / TAU, 1.0)
				if a < share:
					if share - a < 0.045 and share < 0.999:
						col = HiveArt.HONEY_SHINE
					else:
						col = HiveArt.HONEY_LIGHT if dy < 0.5 else HiveArt.HONEY
				else:
					col = Style.SEAM
			elif (r >= r_out and r < r_out + 1.0) or (r >= inner and r < inner + 1.0):
				col = HONEY_OUTLINE
			image.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(image)
	_honey_medals[step] = tex
	return tex


## A jar in whole pixels, for when the hive's sheet is not there to lend one: glass, honey to
## the shoulder and a lid. Returns where it went.
func _draw_jar_cells(room: Rect2) -> Rect2:
	var cell := maxf(floorf(room.size.y / 11.0), 1.0)
	var size := Vector2(7.0, 10.0) * cell
	var at := (room.position + Vector2((room.size.x - size.x) * 0.5, room.size.y - size.y)).round()
	draw_rect(Rect2(at + Vector2(cell, 0.0), Vector2(5.0, 2.0) * cell), Style.SEAM, true)
	draw_rect(Rect2(at + Vector2(2.0, 0.5) * cell, Vector2(3.0, 1.0) * cell), Style.WOOD_PALE, true)
	draw_rect(Rect2(at + Vector2(0.0, 2.0) * cell, Vector2(7.0, 8.0) * cell), Style.SEAM, true)
	var ink := HiveArt.HONEY if honey_jars > 0 else Style.INK_DIM
	draw_rect(Rect2(at + Vector2(1.0, 3.0) * cell, Vector2(5.0, 6.0) * cell), ink, true)
	draw_rect(Rect2(at + Vector2(1.0, 3.0) * cell, Vector2(1.0, 4.0) * cell), HiveArt.HONEY_LIGHT, true)
	return Rect2(at, size)


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
		self, Text.HUD_WAITING, label_size,
		Vector2(x, middle + float(label_size) * 0.35), Style.RIBBON_INK
	)
	x += Style.measure(Text.HUD_WAITING, label_size).x + STOCK_MARK_PAD
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
	HudButtons.label(self, face, Text.HUD_UPGRADES)
	HudButtons.badge(self, face, str(available), available > 0, pulse_amount(&"upgrades"))


## What the money plate's figure is kept clear of, both ends together, in canvas px.
const MONEY_PAD := 8.0


## A sum of money as the HUD writes it: "$12345".
static func money_text(amount: int) -> String:
	return "$%d" % amount


## The largest rung at or under `height` that writes `text` inside `room`, `TEXT_TINY` at least.
static func fitted_size(text: String, height: int, room: float) -> int:
	for rung in [Style.TEXT_TITLE, Style.TEXT_HEAD, Style.TEXT_BODY, Style.TEXT_SMALL]:
		if rung <= height and Style.measure(text, rung).x <= room:
			return rung
	return Style.TEXT_TINY


## The money plate: the coin, the sunken panel, and the live figure on it, and the spend tags
## falling off it unless `tags` is false. Returns `[panel, size, baseline]` for a caller that
## draws the tags itself later (`_draw_spent`): the corner plate does, after the jar plate,
## which the tags fall across.
func _draw_money(on: CanvasItem, box: Rect2, wash: Color, swell: float, tags := true) -> Array:
	var plate := HudButtons.draw_money(on, box, wash, swell)
	# The running figure, not the real one: the plate is meant to be watched climbing. It
	# wears its "$" (2026-10-09, Richard), and drops a rung rather than run off the panel.
	var shown := money_text(roundi(_shown_money))
	var height := fitted_size(shown, Style.step(plate.size.y * 0.72), plate.size.x - MONEY_PAD)
	var baseline := plate.position.y + plate.size.y * 0.5 + float(height) * 0.35
	# Lit from behind while it is climbing, which is what turns a number going up into
	# something being handed over.
	var glow := _ease_shine()
	if glow > 0.01:
		Style.write(
			on,
			shown,
			height,
			Vector2(0.0, baseline - 1.0),
			Color(Style.GOLD.r, Style.GOLD.g, Style.GOLD.b, 0.55 * glow),
			HORIZONTAL_ALIGNMENT_CENTER,
			plate
		)
	Style.write(
		on,
		shown,
		height,
		Vector2(0.0, baseline),
		Style.GOLD.lerp(Style.INK, glow * SHINE_LIFT),
		HORIZONTAL_ALIGNMENT_CENTER,
		plate
	)
	if tags:
		_draw_spent(on, plate, height, baseline)
	return [plate, height, baseline]


## The red "-$X" tags dropping off the money plate's `plate` panel, written at `height` under
## the figure's `baseline`.
func _draw_spent(on: CanvasItem, plate: Rect2, height: int, baseline: float) -> void:
	for tag: Dictionary in _spent:
		var t := float(tag["age"]) / SPENT_LIFE
		var fall := roundf(plate.size.y * SPENT_FALL * (1.0 - pow(1.0 - t, 2.0)))
		var fade := 1.0 - t * t
		Style.write(
			on,
			"-" + money_text(int(tag["amount"])),
			Style.step(float(height) * 0.8),
			Vector2(0.0, baseline + plate.size.y * 0.75 + fall),
			Color(SPENT_INK.r, SPENT_INK.g, SPENT_INK.b, fade),
			HORIZONTAL_ALIGNMENT_CENTER,
			plate
		)
