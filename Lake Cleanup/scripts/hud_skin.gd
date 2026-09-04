## The drawn HUD: the pollution meter and the three wooden buttons.
##
## One node draws the lot and takes the clicks for it, the way the flock and the splashes
## do. The alternative was four scene nodes with four textures, and the textures are cut out
## of a sheet at runtime — the same bargain the net and the pigeons strike, so that the game
## runs with the art missing rather than failing to load.
##
## The meter is the reason this is drawn rather than assembled. It has to read at any
## pollution, and the art is one picture of it reading seventy-two per cent — so the bar is
## rebuilt every frame out of two slices of that picture: the dirty part up to the
## waterline, the clean lake after it. tools/slice_ui.gd measures where the art's own
## waterline is, which is the one number that makes the rest of it possible.
class_name HudSkin
extends Control

const ART := "res://assets/ui.json"

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

## How wide the meter is drawn, as a fraction of the window, and the widest it may get in
## pixels. Its height follows from the art's own proportions — it is a long thin sign and
## stretching it to a height would squash it.
const METER_SHARE := 0.52
const METER_WIDEST := 900.0

## The side of a button, in screen pixels, and how much bigger the money plate is than the
## two that are actually buttons. It is the number the player checks before every purchase
## and it carries a figure that has to be read, not just recognised.
const BUTTON_SIDE := 84.0
const MONEY_SIDE := 116.0

## How much of the art's dirty half may be copied into the bar. Short of the waterline on
## purpose: the last of it carries the reading the art was drawn at — a painted "75%" — and
## stretching that across the bar puts a wrong and unmoving number on every reading of it.
const DIRTY_USABLE := 0.64

## Gaps: around the whole thing, and between the buttons.
const EDGE := 18.0
const GAP := 10.0

## The stock readout: where it sits, how big it is, and how much of the money plate's own
## dark panel is copied to make its background.
##
## Built out of the money plate's parts rather than given a plaque of its own, because it is
## the same kind of thing — a number the player checks — and the sheet has one panel drawn on
## it. Copying that keeps the two readouts obviously a pair.
const STOCK_TALL := 30.0
const STOCK_WIDE := 168.0
const STOCK_TEXT := 0.56

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

## The figure actually on the plate, and how brightly it is still lit from the last payment.
var _shown_money: float = 0.0
var _shine: float = 0.0

var _sheet: Texture2D
var _pieces := {}
## Where the art's own waterline falls, 0 to 1 across the water box.
var _art_shown: float = 0.72

var _shown: float = 1.0

## Screen boxes worked out in `_notification` when the size changes, so a click and a
## drawing cannot disagree about where a button is.
var _meter_box := Rect2()
var _shed_box := Rect2()
var _upgrades_box := Rect2()
var _money_box := Rect2()
var _stock_box := Rect2()
var _hovered := &""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_art()
	_shown = pollution
	_lay_out()
	resized.connect(_lay_out)


## Read the cut sheet. False means no art, and the HUD draws nothing at all rather than
## boxes — the lake keeps its plain labels either way.
func _load_art() -> bool:
	var text := FileAccess.get_file_as_string(ART)
	if text.is_empty():
		return false
	var book: Dictionary = JSON.parse_string(text)
	if book == null or not book.has("pieces"):
		return false
	_sheet = Art.texture(book["sheet"])
	if _sheet == null:
		return false

	for name: String in book["pieces"]:
		var piece: Dictionary = book["pieces"][name]
		var box: Array = piece["region"]
		var kept := {"region": Rect2(box[0], box[1], box[2], box[3])}
		if piece.has("water"):
			var water: Array = piece["water"]
			# Held as an offset inside the piece, so the piece can be drawn anywhere.
			kept["water"] = Rect2(
				water[0] - box[0], water[1] - box[1], water[2], water[3]
			)
			_art_shown = float(piece["shown"])
		_pieces[StringName(name)] = kept
	return true


## Where everything sits: the meter across the top, the two buttons under its right-hand
## end, and the money over on the left under the yard's readout.
##
## The money is not a button and does not belong in a row of them. It is a readout, and the
## other readout on screen is the yard count in the top left — so it goes with that one,
## where the eye already goes to ask how the run is doing.
func _lay_out() -> void:
	var wide := size.x
	if _pieces.has(&"meter"):
		var art: Rect2 = (_pieces[&"meter"] as Dictionary)["region"]
		var span := minf(minf(wide * METER_SHARE, METER_WIDEST), wide - EDGE * 2.0)
		_meter_box = Rect2(
			(wide - span) * 0.5, EDGE, span, span * art.size.y / art.size.x
		)
	var row := _meter_box.position.y + _meter_box.size.y + GAP
	var right := wide - EDGE - BUTTON_SIDE
	_upgrades_box = Rect2(right, row, BUTTON_SIDE, BUTTON_SIDE)
	_shed_box = Rect2(right - BUTTON_SIDE - GAP, row, BUTTON_SIDE, BUTTON_SIDE)
	_stock_box = Rect2(EDGE + 2.0, EDGE, STOCK_WIDE, STOCK_TALL)
	_money_box = Rect2(
		EDGE + 2.0, _stock_box.position.y + STOCK_TALL + GAP, MONEY_SIDE, MONEY_SIDE
	)
	queue_redraw()


func _process(delta: float) -> void:
	var wanted := clampf(pollution, 0.0, 1.0)
	if not is_equal_approx(_shown, wanted):
		_shown = lerpf(_shown, wanted, clampf(METER_EASE * delta, 0.0, 1.0))
		if absf(_shown - wanted) < 0.0005:
			_shown = wanted

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
	queue_redraw()


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


func _draw() -> void:
	if _sheet == null:
		return
	_draw_meter()
	# The money plate swells a little while it is lit, about its own middle so it grows into
	# the space around it rather than sliding off its corner.
	var swell := 1.0 + SHINE_SWELL * _ease_shine()
	var lit := Rect2(
		_money_box.position - _money_box.size * (swell - 1.0) * 0.5,
		_money_box.size * swell
	)
	# Warmed rather than blown out: the coin is already the brightest thing on the plate, and
	# multiplying it half again pushes it past white and out the other side into green.
	_draw_button(&"money", lit, Color.WHITE.lerp(Color(1.22, 1.16, 1.02), _ease_shine()))
	_draw_button(&"shed", _shed_box)
	_draw_button(&"upgrades", _upgrades_box)
	_draw_money(lit)
	_draw_stock()


## The meter, rebuilt at the reading it is showing.
##
## Three draws. The whole picture goes down first, which puts the frame, the lettering and
## the icons on screen. Then the clean lake — a slab copied from the far right of the art's
## own water — is stretched over everything to the right of the waterline, and then the
## dirty water is stretched over everything to the left of it. Both slabs come from the part
## of the art that is unambiguously one thing or the other, so neither carries a piece of the
## divider along with it.
func _draw_meter() -> void:
	if not _pieces.has(&"meter"):
		return
	var piece: Dictionary = _pieces[&"meter"]
	var art: Rect2 = piece["region"]
	draw_texture_rect_region(_sheet, _meter_box, art)
	if not piece.has("water"):
		return

	var water: Rect2 = piece["water"]
	var scale := _meter_box.size.x / art.size.x
	var box := Rect2(
		_meter_box.position + water.position * scale, water.size * scale
	)
	var edge := box.position.x + box.size.x * _shown

	# The clean end, taken from the last of the art's own lake so the boat is not in it.
	var clean := Rect2(
		art.position.x + water.position.x + water.size.x - water.size.x * 0.03,
		art.position.y + water.position.y,
		water.size.x * 0.03, water.size.y
	)
	if edge < box.position.x + box.size.x:
		draw_texture_rect_region(
			_sheet,
			Rect2(edge, box.position.y, box.position.x + box.size.x - edge, box.size.y),
			clean
		)
	# The dirty end, taken from the art's own filth, stretched to the reading. Stretching
	# rather than clipping keeps the lettering and the rubbish in it at every reading, which
	# is what stops a cleaner lake reading as an emptier picture.
	if edge > box.position.x:
		var dirty := Rect2(
			art.position.x + water.position.x,
			art.position.y + water.position.y,
			water.size.x * _art_shown * DIRTY_USABLE, water.size.y
		)
		draw_texture_rect_region(
			_sheet, Rect2(box.position, Vector2(edge - box.position.x, box.size.y)), dirty
		)


func _draw_button(name: StringName, box: Rect2, wash: Color = Color.WHITE) -> void:
	if not _pieces.has(name):
		return
	var art: Rect2 = (_pieces[name] as Dictionary)["region"]
	# A hovered button lifts a pixel and brightens, which is the whole of the feedback. It
	# is a wooden sign, not a web page.
	var lift := Vector2(0.0, -2.0) if _hovered == name else Vector2.ZERO
	var tint := Color(1.12, 1.12, 1.12) if _hovered == name else wash
	draw_texture_rect_region(_sheet, Rect2(box.position + lift, box.size), art, tint)


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
	var art: Rect2 = (_pieces[&"money"] as Dictionary)["region"]
	# The clean left end of the plate, stretched: the rest of it has the artist's figures
	# painted on it, the same trap the shop's rows fell into.
	var slab := Rect2(
		art.position + Vector2(PLATE.position.x, PLATE.position.y) * art.size,
		Vector2(PLATE_CLEAR, PLATE.size.y) * art.size
	)
	draw_texture_rect_region(_sheet, _stock_box, slab)

	var font := get_theme_default_font()
	var height := int(_stock_box.size.y * STOCK_TEXT)
	var shown := "Items in stock  %d" % stock
	var span := font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1.0, height)
	draw_string(
		font,
		_stock_box.position + Vector2(
			(_stock_box.size.x - span.x) * 0.5,
			_stock_box.size.y * 0.5 + float(height) * 0.35
		),
		shown, HORIZONTAL_ALIGNMENT_LEFT, -1.0, height, Color(1.0, 0.95, 0.82)
	)


## The live figure on the money plate.
##
## The art has a number painted on it, so a patch of the plate's own colour goes over that
## first. Read out of the sheet rather than written down here: the plate is flat, and
## sampling it means the number sits on the same brown whatever the art is repainted to.
func _draw_money(box: Rect2) -> void:
	if not _pieces.has(&"money"):
		return
	var art: Rect2 = (_pieces[&"money"] as Dictionary)["region"]
	var plate := Rect2(
		box.position + Vector2(PLATE.position.x, PLATE.position.y) * box.size,
		Vector2(PLATE.size.x, PLATE.size.y) * box.size
	)
	var ink := Rect2(
		art.position + Vector2(PLATE.position.x, PLATE.position.y) * art.size,
		Vector2(PLATE_CLEAR, PLATE.size.y) * art.size
	)
	draw_texture_rect_region(_sheet, plate, ink)

	var font := get_theme_default_font()
	var height := clampf(plate.size.y * 0.72, 8.0, 28.0)
	# The running figure, not the real one: the plate is meant to be watched climbing.
	var shown := "%d" % roundi(_shown_money)
	var span := font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(height))
	var at := plate.position + Vector2(
		(plate.size.x - span.x) * 0.5, plate.size.y * 0.5 + height * 0.35
	)
	# Lit from behind while it is climbing, which is what turns a number going up into
	# something being handed over.
	var glow := _ease_shine()
	if glow > 0.01:
		draw_string(
			font, at + Vector2(0.0, -1.0), shown, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			int(height), Color(1.0, 0.88, 0.45, 0.55 * glow)
		)
	draw_string(
		font, at, shown, HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(height),
		Color(1.0, 0.95, 0.82).lerp(Color(1.0, 1.0, 0.92), glow * SHINE_LIFT)
	)
