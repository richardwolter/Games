## Coins flying from a sale to the money plate.
##
## The ferry sells at a pier somewhere across the lake, and the purse in the corner moved
## with nothing between the two: a piece came down into a box and a number changed. This is
## the thing between. Every piece that lands at a yard sends a coin up out of the box that
## arcs across the screen to the plate's own coin, and the plate lights as it arrives
## (HudSkin.shine). The purse itself is paid when the piece lands, as before — the coin is
## the receipt on its way, not the money.
##
## Screen space, not world space: it lives on the HUD's layer, takes the sale's world point
## through the canvas transform once when the coin sets off, and flies in the pixels the
## plate is drawn in, so it reads the same at every zoom — a delivery seen from the far end
## of the lake still pays into the corner at the same size.
##
## One node draws all of them, like the haul. A coin in the air is a row in an array.
class_name CoinFly
extends Control

## Preloaded, as every user of it does: hud_buttons.gd has no class_name.
const HudButtons := preload("res://scripts/hud_buttons.gd")
const Style := preload("res://scripts/style.gd")

## How long a coin is in the air, and how high it arcs above the straight line, in screen
## px. About the plate's shine time, so the plate stays lit from the first coin's landing
## to the last one's arrival.
const FLIGHT := 0.5
const ARC := 56.0

## The coin's size on the screen at the start and at the end: it comes up out of the box
## small and grows to about the plate's own coin as it arrives.
const SIZE_FROM := 12.0
const SIZE_TO := 22.0

## How many may be in the air at once. Past this a landing piece joins the last coin sent
## rather than sending its own: a late-game hold is a hundred pieces, and a hundred coins
## in a second is a fountain that hides the plate it is aimed at. What a coin carries is
## reported when it lands, so nothing is lost by the merge.
const MOST := 12

## A honey coin (2026-10-16, `Lake.HONEY_BONUS`): the honey's share of a catch, paid on the
## spot, flies from the catch to the plate as the sale's coin does. **A coin of its own**
## (2026-10-18, Richard's pick 4A off `tools/hive_look/last_honey.png`): struck by rule on the
## gold coin's nine widths by `tools/build_honey_coin.py` (a thick honey-deep rim, an amber
## face, a comb cell for its stamp, a bead clinging to its trailing rim), drawn at one sheet px
## a canvas px the whole way (the gold coin's 12 -> 22 px swell is something no pixel art
## survives) on whole pixels, turning through the face-to-edge frames and landing face on. It
## trails `HONEY_TRAIL` inked drops, `HONEY_TRAIL_GAP` of the flight apart along its own arc,
## each a hard alpha step fainter (the sheet's `drop_alpha`). Without the sheet it
## falls back to the gold coin washed `HONEY_WASH`.
const HONEY_SHEET := "res://assets/honey_coin.png"
const HONEY_DATA := "res://assets/honey_coin.json"
const HONEY_WASH := Color(1.0, 0.66, 0.30)
const HONEY_TRAIL := 3
const HONEY_TRAIL_GAP := 0.06
## The last stretch of the flight is drawn face on, so it lands face on.
const HONEY_LAND_FACE := 0.9

## What the honey paid, written over the catch and rising (2026-10-29, Richard: "money from
## honey pot bonus should be more clearly visible ... right now, there's like 1 coin flying"):
## "+$N" in the honey's own ink, climbing `RISE_UP` canvas px over `RISE_TIME`, in whole
## pixels, the last third fading.
const RISE_TIME := 1.3
const RISE_UP := 30.0
const RISE_INK := Color(1.0, 0.78, 0.32)
const RISE_SIZE := 16

static var _honey_tex: Texture2D
static var _honey_frame := Vector2.ZERO
static var _honey_middle := Vector2.ZERO
static var _honey_turns: Array = []
static var _honey_drops: Array[Rect2] = []
static var _honey_drop_alpha: Array = []
static var _honey_tried := false

## A coin reached the plate, carrying this many pieces' worth.
signal landed(carry: int)

## Where the plate's coin is, in this control's own coordinates. Set by the lake to the
## HUD's `coin_centre`; without it coins fly to the top left corner, which is the bug to
## look for.
var target: Callable

## Coins in the air, as `{from, to, age, carry, spin, honey}`. A coin with a negative age is
## waiting to set off (a honeyed sweep's coins leave one after another).
var _flying: Array = []
## The rising "+$N"s, as `{at, age, text}`.
var _rises: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 7707
	set_process(false)


## How many coins are in the air.
func flying() -> int:
	return _flying.size()


## How many of them are honey coins. The harness asks.
func honey_flying() -> int:
	var n := 0
	for coin: Dictionary in _flying:
		if bool(coin.get("honey", false)):
			n += 1
	return n


## A piece landed at a yard: a coin sets off from there. `from_world` is the world point;
## it is turned into screen px here and now, so a camera that pans during the flight does
## not drag the coin's start about with it. `honey` sends a honey coin, and `carry` is how
## many pieces' worth it stands for (a honeyed sweep sends one coin for its whole catch).
func fly(from_world: Vector2, honey := false, carry := 1, delay := 0.0) -> void:
	fly_from(get_viewport().get_canvas_transform() * from_world, honey, carry, delay)


## "+$N" rising over a world point: the honey's pay for one sweep.
func rise(from_world: Vector2, amount: float) -> void:
	_rises.append({
		"at": get_viewport().get_canvas_transform() * from_world, "age": 0.0,
		"text": "+" + Style.MONEY_MARK + str(maxi(roundi(amount), 1)),
	})
	set_process(true)
	queue_redraw()


## How many "+$N"s are up. The harness asks.
func rising() -> int:
	return _rises.size()


## The same, from a point already in screen pixels. Used by the pigeon that pops into the
## side of the screen: it is drawn on a CanvasLayer and has no place on the lake at all, so
## there is no world point to put through the transform.
func fly_from(from: Vector2, honey := false, carry := 1, delay := 0.0) -> void:
	if _flying.size() >= MOST:
		# Joined to the last coin of its own kind in the air, so a honey payment is never
		# swallowed by a sale's coin, nor a sale by honey; to the last of any kind if none is.
		var last: Dictionary = _flying.back()
		for i in range(_flying.size() - 1, -1, -1):
			if bool((_flying[i] as Dictionary).get("honey", false)) == honey:
				last = _flying[i]
				break
		last["carry"] = int(last["carry"]) + carry
		return
	# Last in the layer, so a coin is drawn over the purse the shop hangs (2026-09-27): the
	# purse is added after this node, and a coin behind it missed the coin it aimed at.
	var up := get_parent()
	if up != null and get_index() != up.get_child_count() - 1:
		up.move_child(self, -1)
	_flying.append({
		"from": from,
		"to": _target(),
		"age": -delay,
		"carry": carry,
		"spin": _rng.randf_range(0.6, 1.4),
		"honey": honey,
	})
	set_process(true)
	queue_redraw()


## Drop whatever is in the air, unpaid-for on screen only: the purse was paid when each piece
## landed. Used when the shed covers the lake — a coin arcing over the decoration room, towards
## a plate that is not drawn, is a receipt for something the player cannot see.
func clear() -> void:
	_flying.clear()
	_rises.clear()
	queue_redraw()


func _target() -> Vector2:
	if target.is_valid():
		return target.call()
	return Vector2.ZERO


func _process(delta: float) -> void:
	for i in range(_flying.size() - 1, -1, -1):
		var coin: Dictionary = _flying[i]
		coin["age"] = float(coin["age"]) + delta
		# Aimed where the plate is now: the shop opening mid-flight hangs the purse elsewhere.
		coin["to"] = _target()
		if float(coin["age"]) >= FLIGHT:
			landed.emit(int(coin["carry"]))
			_flying.remove_at(i)
	for i in range(_rises.size() - 1, -1, -1):
		var up: Dictionary = _rises[i]
		up["age"] = float(up["age"]) + delta
		if float(up["age"]) >= RISE_TIME:
			_rises.remove_at(i)
	if _flying.is_empty() and _rises.is_empty():
		set_process(false)
	queue_redraw()


func _draw() -> void:
	for up: Dictionary in _rises:
		var u := clampf(float(up["age"]) / RISE_TIME, 0.0, 1.0)
		var text := String(up["text"])
		var wide: float = Style.measure(text, RISE_SIZE).x
		var lift := roundf(RISE_UP * (1.0 - (1.0 - u) * (1.0 - u)))
		var at: Vector2 = (up["at"] as Vector2) + Vector2(-wide * 0.5, -lift)
		var alpha := clampf((1.0 - u) * 3.0, 0.0, 1.0)
		Style.write(self, text, RISE_SIZE, at.round(), RISE_INK, HORIZONTAL_ALIGNMENT_LEFT, Rect2(), alpha)
	for coin: Dictionary in _flying:
		if float(coin["age"]) < 0.0:
			continue
		var t := clampf(float(coin["age"]) / FLIGHT, 0.0, 1.0)
		var from: Vector2 = coin["from"]
		var to: Vector2 = coin["to"]
		var at := _arc(from, to, t)
		var turn := absf(cos(t * TAU * float(coin["spin"])))
		if bool(coin.get("honey", false)) and _honey_art():
			_draw_honey(from, to, t, turn)
			continue
		var size := lerpf(SIZE_FROM, SIZE_TO, t)
		# The coin turns over as it flies: its width narrows and widens with the spin, and it
		# lands face on.
		var wide := lerpf(maxf(size * lerpf(0.3, 1.0, turn), 3.0), size, t * t)
		draw_set_transform(at, 0.0, Vector2(wide / size, 1.0))
		HudButtons.coin(
			self, Rect2(Vector2(-size * 0.5, -size * 0.5), Vector2(size, size)),
			HONEY_WASH if bool(coin.get("honey", false)) else Color.WHITE
		)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The honey coin's sheet, read once: nine frames face to back, and the three trail drops.
static func _honey_art() -> bool:
	if not _honey_tried:
		_honey_tried = true
		if ResourceLoader.exists(HONEY_SHEET) and FileAccess.file_exists(HONEY_DATA):
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(HONEY_DATA))
			if data is Dictionary:
				var sheet := CanvasTexture.new()
				sheet.diffuse_texture = load(HONEY_SHEET)
				sheet.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				_honey_tex = sheet
				var f: Array = data.get("frame", [0, 0])
				_honey_frame = Vector2(float(f[0]), float(f[1]))
				var m: Array = data.get("middle", [0, 0])
				_honey_middle = Vector2(float(m[0]), float(m[1]))
				_honey_turns = data.get("turns", [])
				_honey_drop_alpha = data.get("drop_alpha", [])
				for r: Variant in data.get("drops", []):
					var cut: Array = r
					_honey_drops.append(Rect2(float(cut[0]), float(cut[1]), float(cut[2]), float(cut[3])))
	return _honey_tex != null and _honey_frame.x > 0.0 and not _honey_turns.is_empty()


## Which frame shows for a turn (1 face on, 0 edge on): the face-to-edge half of the sheet.
static func honey_frame_of(turn: float) -> int:
	return clampi(roundi((1.0 - clampf(turn, 0.0, 1.0)) * 4.0), 0, maxi(_honey_turns.size() - 1, 0))


## One honey coin `t` of the way and its trail, on whole screen pixels.
##
## **A sheet pixel is a whole number of screen pixels** (2026-10-19, Richard: honey coins "not
## showing properly"): drawn one sheet px a canvas px, a 1080p window's 1.5 stretch drew the
## coin's pixels one and two screen px wide by turns, ragged on the rim and crawling as it
## flew. Now `_grain` screen px a sheet px, snapped to the screen's grid. The trail follows
## the flight back along the arc, each drop fainter by the sheet's own `drop_alpha` steps
## (they were drawn whole, and pushed down and right whichever way the coin was going).
func _draw_honey(from: Vector2, to: Vector2, t: float, turn: float) -> void:
	var stretch := _screen_stretch()
	var grain := _grain(stretch)
	for k in range(mini(HONEY_TRAIL, _honey_drops.size()), 0, -1):
		var back := t - HONEY_TRAIL_GAP * float(k)
		if back <= 0.0:
			continue
		var cut: Rect2 = _honey_drops[k - 1]
		var mid := _arc(from, to, back)
		var size := cut.size * grain
		var tint := Color(1.0, 1.0, 1.0, _drop_alpha(k - 1))
		draw_texture_rect_region(_honey_tex, Rect2(_on_screen(mid - size * 0.5, stretch), size), cut, tint)
	var f := 0 if t > HONEY_LAND_FACE else honey_frame_of(turn)
	var at := _on_screen(_arc(from, to, t) - _honey_middle * grain, stretch)
	draw_texture_rect_region(
		_honey_tex, Rect2(at, _honey_frame * grain), Rect2(Vector2(_honey_frame.x * float(f), 0.0), _honey_frame)
	)


## Screen px a canvas px (the window's stretch over the 1280x720 canvas), 1 out of a tree.
func _screen_stretch() -> float:
	if not is_inside_tree():
		return 1.0
	return maxf(get_viewport().get_final_transform().get_scale().x, 0.01)


## Canvas px a honey sheet px: the whole number of screen px nearest one canvas px.
static func _grain(stretch: float) -> float:
	return maxf(roundf(stretch), 1.0) / stretch


## A canvas point put on the screen's own pixel grid.
static func _on_screen(at: Vector2, stretch: float) -> Vector2:
	return (at * stretch).round() / stretch


## A trail drop's alpha off the sheet's `drop_alpha` (0..255), the first drop whole.
static func _drop_alpha(k: int) -> float:
	if k < _honey_drop_alpha.size():
		return float(_honey_drop_alpha[k]) / 255.0
	return 1.0


## Where a coin is `t` of the way through its flight: quick off the box and easing onto the
## plate, on an arc over the straight line.
static func _arc(from: Vector2, to: Vector2, t: float) -> Vector2:
	var eased := 1.0 - (1.0 - t) * (1.0 - t)
	return from.lerp(to, eased) - Vector2(0.0, sin(t * PI) * ARC)
