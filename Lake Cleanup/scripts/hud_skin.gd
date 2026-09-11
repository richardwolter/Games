## The drawn HUD: the pollution meter and the three wooden buttons.
##
## One node draws the lot and takes the clicks for it, the way the flock and the splashes
## do. The alternative was four scene nodes with four textures, and the textures are cut out
## of a sheet at runtime — the same bargain the net and the pigeons strike, so that the game
## runs with the art missing rather than failing to load.
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

## The books of cut pieces, in the order they are read. The first is the original sheet, the
## second the repainted money and upgrades plaques; a piece named in a later book replaces
## the one before it, so a repaint is a file added here rather than a sheet re-cut.
const ART := ["res://assets/ui.json", "res://assets/buttons.json"]

## How fast the drawn waterline chases the real one, as a fraction of the gap a second. The
## lake cleans up a piece at a time and the meter would tick; sliding it is the whole reason
## the reading is animated rather than set.
const METER_EASE := 2.2

## How fast the money on the plate runs up to what has been earned, as a fraction of the gap
## a second, and the least it may move — without a floor the last few coins take longer than
## the first thousand.
const MONEY_RUN := 6.0
const MONEY_LEAST := 12.0

## How long a payment keeps the plate lit, in seconds, and how far the coin swells and the
## figure brightens at the moment it lands. Small: this happens every time a boat unloads,
## and a HUD that leaps about on every sale is one the player learns to stop looking at.
const SHINE_TIME := 0.55
const SHINE_SWELL := 0.1
const SHINE_LIFT := 0.55

## The meter's art: the four sheets, all the same size and aligned, and where inside them the
## frame and the water's track fall (measured off the sheets' alpha). Drawn at
## `METER_SCALE` times its art on a 1080-line window and in proportion on any other,
## nearest-filtered. Not snapped to a pixel step: the size was settled by eye (3x, 1.5x,
## then a third up from that), and a snap would undo the settling.
const METER_ART := "res://assets/ui/meter/"
const METER_SHEET := Vector2(290.0, 94.0)
const METER_FRAME := Rect2(83.0, 24.0, 188.0, 49.0)
const METER_TRACK := Rect2(91.0, 37.0, 170.0, 26.0)
const METER_SCALE := 1.95
const METER_SCALE_LINES := 1080.0

## How wide the filth-to-clean blend is, as a fraction of the track. Narrowed near the ends
## (see `_show_meter`) so a nearly-clean lake keeps its last sliver of filth and a full one
## does not fade off the left of its own track.
const METER_FEATHER := 0.14

## The side of a button, in screen pixels, and how much bigger the money plate is than the
## two that are actually buttons. It is the number the player checks before every purchase
## and it carries a figure that has to be read, not just recognised.
const BUTTON_SIDE := 84.0
const MONEY_SIDE := 116.0

## Gaps: around the whole thing, and between the buttons.
const EDGE := Style.EDGE
const GAP := Style.GAP

## The stock readout: where it sits, how big it is, and how much of the money plate's own
## dark panel is copied to make its background.
##
## Built out of the money plate's parts rather than given a plaque of its own, because it is
## the same kind of thing — a number the player checks — and the sheet has one panel drawn on
## it. Copying that keeps the two readouts obviously a pair.
const STOCK_TALL := 30.0
const STOCK_TEXT := 0.56

## The label the plate is measured against, rather than the one it happens to be showing.
## Measured, because 168 fixed pixels was a guess against a font the HUD no longer uses and
## the reading ran off the end of its own plate; measured against a five-figure count rather
## than the live one, because a plate that changed width every time a piece was sold would
## be a plate that moved while being read.
const STOCK_SAMPLE := "Items in stock  99999"
const STOCK_PAD := 18.0

## The count written across the foot of the upgrades plaque: where its panel sits inside the
## plaque as fractions of it, and how big the lettering is against that panel's height.
##
## Placed to match the money plate rather than measured off the art, because matching it is
## the point — the two plaques hang in the same band of the screen and a reading in a
## different place on each would read as two unrelated things.
const AVAILABLE_PLATE := Rect2(0.09, 0.715, 0.82, 0.16)
const AVAILABLE_TEXT := 0.8

## The smallest the count may be lettered at. The plaque is eighty-odd pixels on a side and
## "9 available" set to its panel's height would run off both ends of it, so the words are
## shrunk to fit — but only so far, and under this they would be a smudge rather than a
## reading.
const AVAILABLE_LEAST := 8

## Where the money plate sits inside the money button, as fractions of it, and how far in
## from its left edge is a good place to read its own colour from. Measured off the art —
## the plate is a flat dark panel with the figures sitting on it, so a patch of it copied
## over the baked-in number is an honest way to make room for a live one.
const PLATE := Rect2(0.085, 0.775, 0.83, 0.165)
const PLATE_CLEAR := 0.03

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
var available: int = 0

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
var _shine: float = 0.0

var _sheet: Texture2D
var _pieces := {}

var _shown: float = 1.0

## The meter's nodes, built once in `_build_meter`: the water sheet with its shader, the
## garbage circle and the frame over it, and the face that writes the figure over the lot.
## Null when the art is missing, and then there is no meter — the lake keeps its plain label.
var _meter_water: TextureRect
var _meter_circle: TextureRect
var _meter_frame: TextureRect
var _meter_face: MeterFace
var _meter_shader: ShaderMaterial

## Screen boxes worked out in `_notification` when the size changes, so a click and a
## drawing cannot disagree about where a button is. `_meter_box` is the whole sheet on
## screen; `_meter_frame_box` the wooden frame inside it, which is what a line under the
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
	_load_art()
	_build_meter()
	_shown = pollution
	_show_meter()
	_lay_out()
	resized.connect(_lay_out)


## Read the cut sheets. False means no art at all, and the HUD draws nothing rather than
## boxes — the lake keeps its plain labels either way.
##
## Each piece carries the texture it was cut from rather than every piece sharing one, so a
## repainted plaque can arrive on a sheet of its own without the rest being redrawn to match.
func _load_art() -> bool:
	for path: String in ART:
		_read_book(path)
	return not _pieces.is_empty()


## One book of pieces, added over whatever is already loaded. A missing or broken book is
## simply skipped: the first one is the whole HUD and the second is two repainted plaques,
## and either should be able to go missing without taking the other with it.
func _read_book(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return
	var book: Dictionary = JSON.parse_string(text)
	if book == null or not book.has("pieces"):
		return
	var sheet := Art.texture(book["sheet"])
	if sheet == null:
		return
	if _sheet == null:
		_sheet = sheet

	for name: String in book["pieces"]:
		var piece: Dictionary = book["pieces"][name]
		var box: Array = piece["region"]
		# The meter piece's own "water"/"shown" fields (where its baked waterline used to
		# fall) went with the baked meter art — the meter has its own sheets now
		# (`_build_meter`), so they are no longer kept.
		var kept := {"region": Rect2(box[0], box[1], box[2], box[3]), "sheet": sheet}
		# Where the blank panel a live figure is written on sits inside the plaque, as
		# fractions of it. Measured by the slicer; a piece without one is old art with a
		# number painted on it, and the plate is patched over instead. See `_plate_of`.
		if piece.has("plate"):
			var plate: Array = piece["plate"]
			kept["plate"] = Rect2(plate[0], plate[1], plate[2], plate[3])
		_pieces[StringName(name)] = kept


## Where everything sits: the meter across the top, the two buttons under its right-hand
## end, and the money over on the left under the yard's readout.
##
## The money is not a button and does not belong in a row of them. It is a readout, and the
## other readout on screen is the yard count in the top left — so it goes with that one,
## where the eye already goes to ask how the run is doing.
func _lay_out() -> void:
	var wide := size.x
	var scale := maxf(size.y / METER_SCALE_LINES * METER_SCALE, 0.5)
	var span := METER_SHEET * scale
	# Centred on the frame, not on the sheet: the garbage circle hangs off the frame's left
	# end and the sheet has room for it, so centring the sheet puts the frame right of middle.
	var frame_middle := (METER_FRAME.position.x + METER_FRAME.size.x * 0.5) * scale
	_meter_box = Rect2(floorf(wide * 0.5 - frame_middle), EDGE, span.x, span.y)
	_meter_frame_box = Rect2(
		_meter_box.position + METER_FRAME.position * scale, METER_FRAME.size * scale
	)
	for sheet: TextureRect in [_meter_water, _meter_circle, _meter_frame]:
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
	var right := wide - EDGE - BUTTON_SIDE
	_upgrades_box = Rect2(right, EDGE, BUTTON_SIDE, BUTTON_SIDE)
	_shed_box = Rect2(right - BUTTON_SIDE - GAP, EDGE, BUTTON_SIDE, BUTTON_SIDE)
	var stock_wide := Style.measure(
		STOCK_SAMPLE, Style.step(STOCK_TALL * STOCK_TEXT)
	).x + STOCK_PAD * 2.0
	_stock_box = Rect2(EDGE + 2.0, EDGE, stock_wide, STOCK_TALL)
	# Centred under the stock plate rather than sharing its left edge: they are two different
	# widths (a wide slab and a square plate), and a shared left edge left their right edges,
	# and the whole pair, looking lopsided.
	_money_box = Rect2(
		_stock_box.position.x + (stock_wide - MONEY_SIDE) * 0.5,
		_stock_box.position.y + STOCK_TALL + GAP, MONEY_SIDE, MONEY_SIDE
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
	_shine = maxf(_shine - delta / SHINE_TIME, 0.0)
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


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var was := _hovered
		_hovered = _under((event as InputEventMouseMotion).position)
		if was != _hovered:
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
		stock, available, hint, _hovered, siege.hash()
	])


func _draw() -> void:
	_painted = _paint_key()
	if _sheet == null:
		return
	# The money plate swells a little while it is lit, about its own middle so it grows into
	# the space around it rather than sliding off its corner.
	var swell := 1.0 + SHINE_SWELL * _ease_shine()
	var lit := Rect2(
		_money_box.position - _money_box.size * (swell - 1.0) * 0.5,
		_money_box.size * swell
	)
	# Warmed rather than blown out: the coin is already the brightest thing on the plate, and
	# multiplying it half again pushes it past white and out the other side into green.
	_draw_button(&"money", lit, Color.WHITE.lerp(Style.SHINE_WASH, _ease_shine()))
	_draw_button(&"shed", _shed_box)
	_draw_button(&"upgrades", _upgrades_box)
	_draw_money(lit)
	_draw_stock()
	_draw_available()
	if not hint.is_empty():
		_draw_hint()
	if not siege.is_empty():
		_draw_siege()


## A line of plain text under the meter, centred on it. No plate behind it: it is a note
## about the lake, and it belongs on the lake.
func _draw_hint() -> void:
	var height := Style.TEXT_BODY
	Style.write(
		self,
		hint,
		height,
		Vector2(0.0, _meter_box.position.y + _meter_box.size.y + GAP + float(height)),
		Style.GOLD.lerp(Style.INK, 0.5),
		HORIZONTAL_ALIGNMENT_CENTER,
		_meter_frame_box
	)


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
## blends the clean water into it), the garbage circle, the frame, and a face for the figure.
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
	_meter_shader = ShaderMaterial.new()
	_meter_shader.shader = shader
	_meter_shader.set_shader_parameter(&"clean_tex", clean)
	_meter_shader.set_shader_parameter(&"track_from", METER_TRACK.position.x / METER_SHEET.x)
	_meter_shader.set_shader_parameter(&"track_to", METER_TRACK.end.x / METER_SHEET.x)
	_meter_water = _sheet_node(murky)
	_meter_water.material = _meter_shader
	_meter_circle = _sheet_node(circle)
	_meter_frame = _sheet_node(frame)
	_meter_face = MeterFace.new()
	_meter_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_meter_face)
	_show_meter()


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
	var edge := METER_TRACK.position.x + METER_TRACK.size.x * share
	var feather := minf(
		METER_TRACK.size.x * METER_FEATHER,
		maxf(minf(edge - METER_TRACK.position.x, METER_TRACK.end.x - edge) * 2.0, 1.0)
	)
	_meter_shader.set_shader_parameter(&"seam", edge / METER_SHEET.x)
	_meter_shader.set_shader_parameter(&"feather", feather / METER_SHEET.x)
	if _meter_face.shown != share:
		_meter_face.shown = share
		_meter_face.queue_redraw()


## The figure on the meter. The water says how the lake is doing at a glance and the number
## says whether the last hour of work moved it — a lake that is ninety-six per cent clean and
## a lake that is ninety-nine look the same on a track this long. Right-aligned, over the
## clean end, so it sits on water rather than on filth. Its own node so that it draws over
## the frame, which is a child drawn after this node's own `_draw`.
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


func _draw_button(name: StringName, box: Rect2, wash: Color = Color.WHITE) -> void:
	if not _pieces.has(name):
		return
	var piece: Dictionary = _pieces[name]
	var art: Rect2 = piece["region"]
	# A hovered button lifts a pixel and brightens, which is the whole of the feedback. It
	# is a wooden sign, not a web page.
	var lift := Vector2(0.0, -Style.HOVER_LIFT) if _hovered == name else Vector2.ZERO
	var tint := Style.HOVER_WASH if _hovered == name else wash
	draw_texture_rect_region(piece["sheet"], Rect2(box.position + lift, box.size), art, tint)


## Where a plaque's writing panel is, as fractions of the plaque. The slicer measures it on
## the sheets that have one; the older art is a painting with a number already on it, and
## PLATE is where that painted number sits.
func _plate_of(name: StringName) -> Rect2:
	var piece: Dictionary = _pieces.get(name, {})
	return piece.get("plate", PLATE)


## The shine, eased. Squared off at the front so it lands hard and lets go softly, which is
## the shape of being handed something.
func _ease_shine() -> float:
	return _shine * _shine


## What is waiting in the yard, on a strip of the money plate's own panel.
##
## Built out of the money plate's parts rather than given a plaque of its own, because it is
## the same kind of thing — a number the player checks — and the sheet has one panel drawn on
## it. Copying that keeps the two readouts obviously a pair.
func _draw_stock() -> void:
	if not _pieces.has(&"money"):
		return
	var piece: Dictionary = _pieces[&"money"]
	var art: Rect2 = piece["region"]
	var plate := _plate_of(&"money")
	# The clean left end of the plate, stretched: on the older art the rest of it has the
	# artist's figures painted on it, the same trap the shop's rows fell into.
	var slab := Rect2(
		art.position + Vector2(plate.position.x, plate.position.y) * art.size,
		Vector2(PLATE_CLEAR, plate.size.y) * art.size
	)
	draw_texture_rect_region(piece["sheet"], _stock_box, slab)

	var height := Style.step(_stock_box.size.y * STOCK_TEXT)
	Style.write(
		self,
		"Items in stock  %d" % stock,
		height,
		Vector2(0.0, _stock_box.position.y + _stock_box.size.y * 0.5 + float(height) * 0.35),
		Style.INK,
		HORIZONTAL_ALIGNMENT_CENTER,
		_stock_box
	)


## How many upgrades the player can afford, written across the foot of the upgrades plaque.
##
## The same lettering, and the same place on the plaque, as the figure on the money plate:
## they are a pair, and the money one is the number this one is measured against. White
## rather than that one's gold — gold in this game is money, and this is a count of things,
## not a sum. The plaque has no blank panel painted into it the way the money one does, so a
## sunken panel in the game's own wood is drawn under the words to sit them on.
##
## Always there, zero included: a panel that comes and goes is a thing the player has to
## notice the absence of, and "0 available" is the answer to the question they are asking
## when they look at it.
func _draw_available() -> void:
	if not _pieces.has(&"upgrades"):
		return
	var plate := Rect2(
		_upgrades_box.position + AVAILABLE_PLATE.position * _upgrades_box.size,
		AVAILABLE_PLATE.size * _upgrades_box.size
	)
	# The panel rides the button's own hover lift, or it would come unstuck from the sign it
	# is painted on the moment the cursor crossed it.
	if _hovered == &"upgrades":
		plate.position.y -= Style.HOVER_LIFT
	Style.plaque(self, plate, Style.WOOD_DEEP)
	# Set to the panel's height and then shrunk to its width if the words are too long for
	# it — not stepped onto the game's ladder of text sizes, because every rung of that
	# ladder is wider than this panel.
	var label := "%d available" % available
	var height := maxi(AVAILABLE_LEAST, int(plate.size.y * AVAILABLE_TEXT))
	var wide := Style.measure(label, height).x
	if wide > plate.size.x:
		height = maxi(AVAILABLE_LEAST, int(float(height) * plate.size.x / wide))
	Style.write(
		self,
		label,
		height,
		Vector2(0.0, plate.position.y + plate.size.y * 0.5 + float(height) * 0.35),
		Style.INK,
		HORIZONTAL_ALIGNMENT_CENTER,
		plate
	)


## The live figure on the money plate.
##
## The art has a number painted on it, so a patch of the plate's own colour goes over that
## first. Read out of the sheet rather than written down here: the plate is flat, and
## sampling it means the number sits on the same brown whatever the art is repainted to.
func _draw_money(box: Rect2) -> void:
	if not _pieces.has(&"money"):
		return
	var piece: Dictionary = _pieces[&"money"]
	var art: Rect2 = piece["region"]
	var panel := _plate_of(&"money")
	var plate := Rect2(
		box.position + panel.position * box.size, panel.size * box.size
	)
	# Only where the art has a number painted on it. The repainted plaque leaves the panel
	# blank for this, and patching a blank panel with a strip of itself only risks a seam.
	if not piece.has("plate"):
		var ink := Rect2(
			art.position + panel.position * art.size,
			Vector2(PLATE_CLEAR, panel.size.y) * art.size
		)
		draw_texture_rect_region(piece["sheet"], plate, ink)

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
