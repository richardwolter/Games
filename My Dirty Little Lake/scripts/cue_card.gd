class_name CueCard
extends Control
## The card that says something has just happened for the first time (2026-10-07,
## `/grill-me` with Richard): a tornado, the first animal back, the swarm, the honey, a lucky
## or double cast, a pigeon's money, the ferries waiting for a full load.
##
## **One pattern, a theme each.** Every card is the recycle note's paper with a coloured tab
## down its left edge holding a small whole-pixel icon (`_icon`), its words wrapped on the
## paper, and the words between asterisks in the string written in the theme's ink over a
## ragged highlighter swipe in its pale tint — the letter's `*marked*` rule, so a translation
## carries its own keywords. What changes per theme is the colour, the icon and the way the
## card comes in (`entrance`): the tornado swirls, the lucky cast pops in a burst of the
## finds' stars, the double cast's ghost copy slides in and merges, the pigeon card hops, the
## ferry's glides in on the swell, the wildlife's grows up out of its foot, the swarm's buzzes
## in, the honey's drops and hangs a drip. The trailer's captions did the same thing to
## letters (`marketing/.../trailer/captions.py`); here it is a whole card, and once it has
## landed it holds still bar its icon, which keeps a small loop.
##
## Two ways up:
## - **a moment** (`show_for`): low and centred in the window over a glide the lake is
##   running, clicks passing through, gone after `hold`. `MomentCard` is this.
## - **a hint** (`show_hint`): beside a target on the HUD with an arrow at it, the game
##   running under it; a click on its paper closes it (`closed`), everything else passes
##   through. The lake times it and moves its target.
##
## Draws only; nothing here is saved.

const Style := preload("res://scripts/style.gd")
const HudButtons := preload("res://scripts/hud_buttons.gd")

signal closed

## How far down the window a moment's card stands: the thing it is about is in the middle.
const DOWN := 0.78
const RIM := 2.0
const OUTER := Color(0.235, 0.165, 0.118)
const FADE := 0.35
## The tab down the left edge, design px, and the size of one icon pixel on it.
const TAB_MOMENT := 44.0
const TAB_HINT := 34.0
const CELL_MOMENT := 3.0
const CELL_HINT := 2.0
const PAD_MOMENT := Vector2(18.0, 10.0)
const PAD_HINT := Vector2(10.0, 8.0)
const WIDE_HINT := 236.0
const WIDE_MOMENT_MOST := 760.0
const LINE_GAP := 2.0
## The entrance: a spring (the trailer's) and how long its flourish lasts.
const SPRING_W := 15.0
const SPRING_Z := 0.42
const ENTER := 0.6
const FX_LONG := 1.3
## The keywords' swipes run in one after another once the card has landed.
const SWIPE_AFTER := 0.32
const SWIPE_TIME := 0.18
## How far the arrow stands off the target and how far it bobs.
const ARROW_GAP := 6.0
const ARROW_BOB := 3.0
const GAP := 14.0

## Each theme: `band` the tab, `mark` the highlighter, `ink` the keywords (all three clear
## 4.5:1 for the ink, on the paper and on the mark: `test_lake` measures them), `icon` and
## `entrance`. `stripes` on the swarm's tab is the bee's own coat.
const THEMES := {
	&"tornado": {"band": Color(0.36, 0.42, 0.58), "mark": Color(0.68, 0.76, 0.92),
		"ink": Color(0.10, 0.15, 0.33), "icon": &"funnel", "entrance": &"swirl"},
	&"wildlife": {"band": Color(0.36, 0.58, 0.26), "mark": Color(0.72, 0.88, 0.48),
		"ink": Color(0.10, 0.26, 0.04), "icon": &"sprout", "entrance": &"sprout"},
	&"swarm": {"band": Color(0.90, 0.68, 0.16), "mark": Color(1.0, 0.80, 0.30),
		"ink": Color(0.30, 0.16, 0.0), "icon": &"bee", "entrance": &"buzz", "stripes": true},
	&"honey": {"band": Color(0.86, 0.50, 0.10), "mark": Color(1.0, 0.72, 0.36),
		"ink": Color(0.36, 0.14, 0.0), "icon": &"jar", "entrance": &"drip"},
	&"lucky": {"band": Color(0.84, 0.62, 0.16), "mark": Color(1.0, 0.84, 0.28),
		"ink": Color(0.33, 0.19, 0.0), "icon": &"star", "entrance": &"pop"},
	&"double": {"band": Color(0.42, 0.36, 0.64), "mark": Color(0.78, 0.72, 0.96),
		"ink": Color(0.22, 0.10, 0.42), "icon": &"nets", "entrance": &"ghost"},
	&"pigeon": {"band": Color(0.46, 0.48, 0.56), "mark": Color(1.0, 0.82, 0.36),
		"ink": Color(0.32, 0.17, 0.0), "icon": &"coin", "entrance": &"hop"},
	&"ferry": {"band": Color(0.22, 0.48, 0.62), "mark": Color(0.60, 0.82, 0.94),
		"ink": Color(0.02, 0.21, 0.34), "icon": &"boat", "entrance": &"sail"},
}
## The icons that are drawn from rows of letters, one letter a pixel. `k` is the outline,
## `w` white, `p` the paper, `y` gold, `o` deep gold, `g` green, `G` deep green, `b` the
## lake's blue, `d` the tab's own colour darkened, `.` nothing.
const ROWS := {
	&"sprout": [
		".kk...kk.",
		"kggk.kggk",
		"kgGgkgGgk",
		".kgGkGgk.",
		"..kkgkk..",
		"....g....",
		"....G....",
		"..kkGkk..",
		".kddddddk",
	],
	&"bee": [
		"..kk.kk...",
		".kwwkwwk..",
		".kwwkwwk..",
		"..kkkkkk..",
		".kykkykyk.",
		"kyykyykykk",
		".kykkykyk.",
		"..kkkkkk..",
	],
	&"jar": [
		".kkkkkkk.",
		".kwpwpwk.",
		"kkkkkkkkk",
		"kpyyyyypk",
		"kpyoyyypk",
		"kpyyyyypk",
		"kpyyyoypk",
		"kpyyyyypk",
		".kkkkkkk.",
	],
	&"net": [
		"..kkk..",
		".kw.wk.",
		"kw.w.wk",
		"k.w.w.k",
		"kw.w.wk",
		".kw.wk.",
		"..kkk..",
	],
	&"boat": [
		".....k.....",
		"....kwk....",
		"....kwwk...",
		"....kwwwk..",
		"....kwwwwk.",
		"....kbwwwwk",
		"....k......",
		"kkkkkkkkkkk",
		".kyyyyyyyk.",
		"..kkkkkkk..",
	],
}

var text := ""
## Which theme the card wears: a key of `THEMES`.
var kind: StringName = &"tornado"
## A hint's target, in this control's pixels; empty for a moment.
var target := Rect2()

var _hint := false
var _clock := -1.0
var _delay := 0.0
var _hold := 0.0
var _closing := -1.0
var _card := Rect2()
var _arrow: Texture2D = _load_arrow()


static func _load_arrow() -> Texture2D:
	var path := "res://assets/ui/prompts/arrow_up.png"
	return load(path) if ResourceLoader.exists(path) else null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fit()
	get_viewport().size_changed.connect(_fit)
	set_process(false)


## Sized by hand: a Control on a CanvasLayer has no parent rect to anchor to.
func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


## A moment's card: up after `delay` seconds, for `hold` seconds, then gone.
func show_for(delay: float, hold: float) -> void:
	_hint = false
	target = Rect2()
	_delay = delay
	_hold = hold
	_closing = -1.0
	_clock = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = true
	set_process(true)
	queue_redraw()


## A hint's card, from its entrance: the lake keeps `target` up to date and says when it goes.
func show_hint(of: StringName, words: String, at: Rect2) -> void:
	_hint = true
	kind = of
	text = words
	target = at
	_delay = 0.0
	_hold = INF
	_closing = -1.0
	_clock = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = true
	set_process(true)
	queue_redraw()


## Take a hint down: it fades over `FADE`, or at once.
func hide_hint(at_once: bool = false) -> void:
	if not _hint or _clock < 0.0:
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if at_once:
		_clock = -1.0
		set_process(false)
		queue_redraw()
	elif _closing < 0.0:
		_closing = 0.0


## Whether the card is on the screen: the harness asks.
func showing() -> bool:
	if _clock < 0.0:
		return false
	if _hint:
		return _closing < 0.0
	return _clock >= _delay and _clock < _delay + _hold + FADE


## How far into its entrance the card is (seconds since it went up), -1 when it is not up.
func age() -> float:
	return _clock - _delay if _clock >= _delay else -1.0


## Where the card's paper is drawn, settled: the harness and the click ask.
func card_box() -> Rect2:
	return _card


func _process(delta: float) -> void:
	_clock += delta
	if _closing >= 0.0:
		_closing += delta
		if _closing >= FADE:
			_clock = -1.0
			_closing = -1.0
			set_process(false)
	elif not _hint and _clock >= _delay + _hold + FADE:
		_clock = -1.0
		set_process(false)
	queue_redraw()


## Only the paper takes a click, and only a hint's.
func _has_point(point: Vector2) -> bool:
	return _hint and _closing < 0.0 and _card.grow(RIM + 1.0).has_point(point)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	Sfx.ui(&"ui_close")
	closed.emit()


# --------------------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------------------

func _draw() -> void:
	_card = Rect2()
	if _clock < _delay or text.is_empty():
		return
	var t := _clock - _delay
	var alpha := 1.0
	if _hint:
		if _closing >= 0.0:
			alpha = 1.0 - clampf(_closing / FADE, 0.0, 1.0)
	else:
		alpha = clampf((_hold + FADE - t) / FADE, 0.0, 1.0)
	if alpha <= 0.0:
		return
	var look: Dictionary = THEMES.get(kind, THEMES[&"tornado"])
	var px := Style.TEXT_SMALL if _hint else Style.TEXT_HEAD
	var tab := TAB_HINT if _hint else TAB_MOMENT
	var pad := PAD_HINT if _hint else PAD_MOMENT
	var wide := WIDE_HINT if _hint else minf(WIDE_MOMENT_MOST, size.x - 80.0 - tab - pad.x * 2.0)
	var rows := lay_out(text, px, wide)
	if not _hint and rows.size() > 2:
		px = Style.TEXT_BODY
		rows = lay_out(text, px, wide)
	# Lines evened out: the narrowest width that keeps the same number of rows, so a hint
	# never ends on one word alone.
	if _hint and rows.size() > 1:
		var narrow := wide
		while narrow > 80.0 and lay_out(text, px, narrow - 8.0).size() == rows.size():
			narrow -= 8.0
		rows = lay_out(text, px, narrow)
	var line_tall := Style.font().get_height(px) + LINE_GAP
	var text_size := Vector2(minf(_widest(rows, px), wide), line_tall * float(rows.size()) - LINE_GAP)
	var card_size := Vector2(tab + pad.x * 2.0 + text_size.x, maxf(text_size.y + pad.y * 2.0, tab))
	var card := Rect2(_card_at(card_size), card_size)
	card.position = card.position.round()
	card.size = card.size.round()
	_card = card
	modulate.a = alpha
	# The entrance moves the whole card about its middle.
	var pose := _pose(look[&"entrance"], t, card)
	if look[&"entrance"] == &"ghost" and t < ENTER:
		var s := spring(t)
		for side: float in [-1.0, 1.0]:
			var ghost := Vector2(side * 70.0 * (1.0 - s), 0.0)
			draw_set_transform(card.get_center() + ghost, 0.0, Vector2.ONE)
			_draw_card(card, look, rows, px, line_tall, pad, tab, t, 0.45)
		draw_set_transform(Vector2.ZERO)
		_draw_fx(look, t, card)
	else:
		draw_set_transform(card.get_center() + pose["at"], pose["turn"], pose["scale"])
		_draw_card(card, look, rows, px, line_tall, pad, tab, t, 1.0)
		draw_set_transform(Vector2.ZERO)
		_draw_fx(look, t, card)
	if _hint and target.size.x > 0.0 and t > ENTER * 0.5:
		_draw_arrow(card, t)


## The card itself, drawn about its own middle (the caller has set the transform).
func _draw_card(card: Rect2, look: Dictionary, rows: Array, px: int, line_tall: float,
		pad: Vector2, tab: float, t: float, alpha: float) -> void:
	var box := Rect2(-card.size * 0.5, card.size)
	var band: Color = look[&"band"]
	draw_rect(box.grow(RIM + 1.0), Color(OUTER, alpha), true)
	draw_rect(box, Color(Style.PAPER, alpha), true)
	draw_rect(box.grow(-1.0), Color(Style.PAPER_EDGE, alpha), false, RIM)
	# The tab: the theme's colour down the left edge, lit along its top, a dark seam where it
	# meets the paper.
	var strip := Rect2(box.position, Vector2(tab, box.size.y))
	draw_rect(strip, Color(band, alpha), true)
	if look.get(&"stripes", false):
		var dark := band.darkened(0.72)
		var clear := Rect2(strip.get_center() - Vector2(13.0, 12.0) * (CELL_HINT if _hint else CELL_MOMENT) * 0.5,
			Vector2(13.0, 12.0) * (CELL_HINT if _hint else CELL_MOMENT))
		var y := strip.position.y
		var row := 0
		while y < strip.end.y:
			# A bee's coat: dark bands slanting down the tab, two px rows stepped one px.
			for x in range(int(strip.size.x)):
				if posmod(x + row, 10) < 4 and not clear.has_point(Vector2(strip.position.x + float(x), y)):
					draw_rect(Rect2(strip.position.x + float(x), y, 1.0, 2.0), Color(dark, alpha * 0.55), true)
			y += 2.0
			row += 2
	draw_rect(Rect2(strip.position, Vector2(strip.size.x, 2.0)), Color(band.lightened(0.3), alpha), true)
	draw_rect(Rect2(strip.end.x - 2.0, strip.position.y, 2.0, strip.size.y), Color(band.darkened(0.35), alpha), true)
	_draw_icon(look, strip, t, alpha)
	# The words: centred on what the tab leaves, each row's keywords swiped first.
	var face := Style.font()
	var ascent := face.get_ascent(px)
	var inner := Rect2(strip.end.x + pad.x, box.position.y, box.size.x - tab - pad.x * 2.0, box.size.y)
	var y0 := inner.position.y + (inner.size.y - (line_tall * float(rows.size()) - LINE_GAP)) * 0.5
	var swipe := 0
	for r in rows.size():
		var row: Array = rows[r]
		var span := _row_wide(row, px)
		var x := floorf(inner.position.x + (inner.size.x - span) * 0.5)
		var base := floorf(y0 + float(r) * line_tall + ascent)
		var at_x := x
		for unit: Dictionary in row:
			if bool(unit["space"]):
				at_x += Style.measure(" ", px).x
			var w := Style.measure(String(unit["text"]), px).x
			if bool(unit["marked"]):
				var grow := clampf((t - SWIPE_AFTER - float(swipe) * SWIPE_TIME * 0.6) / SWIPE_TIME, 0.0, 1.0)
				_swipe(Rect2(at_x - 2.0, base - ascent * 0.48, w + 4.0, ascent * 0.48 + 3.0),
					look[&"mark"], grow, swipe, alpha)
				swipe += 1
			at_x += w
		at_x = x
		for unit: Dictionary in row:
			if bool(unit["space"]):
				at_x += Style.measure(" ", px).x
			var ink: Color = look[&"ink"] if bool(unit["marked"]) else Style.PAPER_INK
			Glyphs.draw_line(self, face, Vector2(at_x, base), String(unit["text"]), px, Color(ink, alpha))
			at_x += Style.measure(String(unit["text"]), px).x


## A highlighter's stroke under a keyword: whole-pixel rows, each end ragged by its own
## hash, wiped in from the left as `grow` goes 0 to 1.
func _swipe(box: Rect2, ink: Color, grow: float, which: int, alpha: float) -> void:
	if grow <= 0.0:
		return
	var rows := int(box.size.y / 2.0)
	for r in rows:
		var h := hash(Vector2i(which, r))
		var left := float(posmod(h, 3)) - 1.0
		var right := float(posmod(h >> 3, 4)) - 1.0
		var x0 := box.position.x + left
		var x1 := lerpf(x0, box.end.x + right, grow)
		draw_rect(Rect2(roundf(x0), box.position.y + float(r) * 2.0, roundf(x1 - x0), 2.0), Color(ink, alpha), true)


## The arrow from the card to its target, bobbing towards it.
func _draw_arrow(card: Rect2, t: float) -> void:
	if _arrow == null:
		return
	var side := _side()
	var a := _arrow.get_size() * 2.0
	var bob := roundf(sin(t * TAU / 1.1) * ARROW_BOB)
	var tip: Vector2
	var turn := 0.0
	match side:
		&"right":
			tip = Vector2(target.end.x + ARROW_GAP - bob, target.get_center().y)
			turn = -PI * 0.5
		&"below":
			tip = Vector2(target.get_center().x, target.end.y + ARROW_GAP - bob)
			turn = 0.0
		_:
			tip = Vector2(target.get_center().x, target.position.y - ARROW_GAP + bob)
			turn = PI
	# The texture points up with its tip on its top edge: turned about the tip.
	draw_set_transform(tip.round(), turn, Vector2.ONE)
	draw_texture_rect(_arrow, Rect2(Vector2(-a.x * 0.5, 0.0), a), false)
	draw_set_transform(Vector2.ZERO)


## Which side of the target a hint stands on: right of a plate in the top-left corner,
## under anything else near the top, over the rest (the count over the angler).
func _side() -> StringName:
	if target.position.x < size.x * 0.3 and target.position.y < size.y * 0.35:
		return &"right"
	if target.get_center().y < size.y * 0.35:
		return &"below"
	return &"above"


func _card_at(card: Vector2) -> Vector2:
	if not _hint or target.size.x <= 0.0:
		return Vector2(size.x * 0.5 - card.x * 0.5, size.y * DOWN - card.y * 0.5)
	var reach := (_arrow.get_size().y * 2.0 if _arrow != null else 16.0) + ARROW_GAP + GAP * 0.5
	var at: Vector2
	match _side():
		&"right":
			at = Vector2(target.end.x + reach, target.get_center().y - card.y * 0.5)
		&"below":
			at = Vector2(target.get_center().x - card.x * 0.5, target.end.y + reach)
		_:
			at = Vector2(target.get_center().x - card.x * 0.5, target.position.y - reach - card.y)
	at.x = clampf(at.x, 8.0, size.x - card.x - 8.0)
	at.y = clampf(at.y, 8.0, size.y - card.y - 8.0)
	return at


# --------------------------------------------------------------------------------------
# The entrances and their flourishes
# --------------------------------------------------------------------------------------

## A damped spring from 0 to 1, overshooting once: the trailer's captions' own.
static func spring(t: float) -> float:
	if t <= 0.0:
		return 0.0
	var wd := SPRING_W * sqrt(1.0 - SPRING_Z * SPRING_Z)
	return 1.0 - exp(-SPRING_Z * SPRING_W * t) * (cos(wd * t) + SPRING_Z / sqrt(1.0 - SPRING_Z * SPRING_Z) * sin(wd * t))


## Where the card is, how it is turned and scaled `t` seconds into its entrance.
func _pose(entrance: StringName, t: float, card: Rect2) -> Dictionary:
	var s := spring(t)
	var out := {"at": Vector2.ZERO, "turn": 0.0, "scale": Vector2.ONE}
	if t >= ENTER * 2.0:
		return out
	match entrance:
		&"swirl":
			out["turn"] = -0.7 * (1.0 - s)
			out["scale"] = Vector2.ONE * lerpf(0.4, 1.0, s)
		&"pop":
			out["scale"] = Vector2.ONE * maxf(s, 0.0)
		&"hop":
			# Dropped from above, two bounces, squashed on each landing.
			var fall := clampf(t / 0.22, 0.0, 1.0)
			var bounce := absf(sin((t - 0.22) * 11.0)) * exp(-(t - 0.22) * 6.0) if t > 0.22 else 0.0
			out["at"] = Vector2(0.0, -60.0 * (1.0 - fall * fall) - 16.0 * bounce)
			var squash := exp(-maxf(t - 0.22, 0.0) * 14.0) * 0.18 if t > 0.22 else 0.0
			out["scale"] = Vector2(1.0 + squash, 1.0 - squash)
		&"sail":
			out["at"] = Vector2(-110.0 * (1.0 - s), sin(t * 9.0) * 5.0 * exp(-t * 2.5))
			out["turn"] = sin(t * 9.0) * 0.05 * exp(-t * 2.5)
		&"sprout":
			# Grows up out of its own foot.
			var grow := maxf(s, 0.02)
			out["scale"] = Vector2(lerpf(0.85, 1.0, minf(s, 1.0)), grow)
			out["at"] = Vector2(0.0, card.size.y * 0.5 * (1.0 - grow))
		&"buzz":
			out["at"] = Vector2(90.0 * (1.0 - s), sin(t * 34.0) * 6.0 * (1.0 - minf(s, 1.0)))
		&"drip":
			out["at"] = Vector2(0.0, -70.0 * (1.0 - s))
			out["scale"] = Vector2(1.0 - 0.12 * (1.0 - s), 1.0 + 0.2 * (1.0 - s))
		_:
			out["scale"] = Vector2.ONE * s
	return out


## The flourish round the card: drawn in the window's pixels, off fixed hashes, so nothing
## about it is kept between frames.
func _draw_fx(look: Dictionary, t: float, card: Rect2) -> void:
	var c := card.get_center()
	var half := card.size * 0.5
	match look[&"entrance"]:
		&"swirl":
			# Wind specks winding in round the card, anticlockwise like the funnel.
			if t < FX_LONG:
				var k := t / FX_LONG
				for i in 16:
					var ang := float(i) * TAU / 16.0 - t * 5.0
					var r := lerpf(1.6, 1.08, k) + 0.12 * sin(float(i) * 2.3)
					var at := c + Vector2(cos(ang) * half.x * r, sin(ang) * half.y * r * 1.4)
					_dot(at, 2.0, Color(1.0, 1.0, 1.0, 0.85 * (1.0 - k)))
					_dot(at + Vector2(sin(ang), -cos(ang)) * 3.0, 2.0, Color(0.8, 0.86, 0.95, 0.5 * (1.0 - k)))
		&"pop":
			# The finds' four-point stars bursting off the edge, then one twinkling now and again.
			if t < FX_LONG:
				var k := t / FX_LONG
				for i in 10:
					var ang := float(i) * TAU / 10.0 + 0.3
					var out := Vector2(cos(ang) * (half.x + 8.0 + 34.0 * k), sin(ang) * (half.y + 6.0 + 22.0 * k))
					_star(c + out, 2.0, 3 if i % 2 else 2, Color(1.0, 0.86, 0.32, 1.0 - k))
			var beat := fmod(t, 1.6)
			if t > ENTER and beat < 0.5:
				var which := int(t / 1.6)
				var corner := Vector2(-1.0 if which % 2 else 1.0, -1.0 if which % 3 else 1.0)
				_star(c + corner * (half + Vector2(-4.0, -2.0)), 2.0, 2 + int(sin(beat / 0.5 * PI) * 1.9),
					Color(1.0, 0.92, 0.55, sin(beat / 0.5 * PI)))
		&"hop":
			# Two grey feathers knocked off by the landing, rocking down.
			if t > 0.22 and t < FX_LONG + 0.4:
				var k := (t - 0.22) / (FX_LONG + 0.18)
				for i in 3:
					var side := -1.0 if i % 2 else 1.0
					var at := c + Vector2(side * (half.x * 0.6 + 18.0 * k + float(i) * 6.0) + sin(t * 7.0 + float(i)) * 5.0,
						-half.y - 4.0 + 40.0 * k)
					_dot(at, 2.0, Color(0.72, 0.74, 0.8, 1.0 - k))
					_dot(at + Vector2(2.0, 2.0), 2.0, Color(0.55, 0.57, 0.64, 1.0 - k))
		&"sail":
			# Foam left behind along the card's foot as it glides in.
			if t < FX_LONG:
				var k := t / FX_LONG
				for i in 12:
					var x := c.x - half.x - float(i) * 9.0 * (1.0 - k) + float(i) * 4.0
					var y := c.y + half.y + 3.0 + float(posmod(hash(i), 3))
					_dot(Vector2(x, y), 2.0, Color(1.0, 1.0, 1.0, (0.9 - float(i) * 0.06) * (1.0 - k)))
		&"sprout":
			# Leaf pixels springing off the top edge.
			if t < FX_LONG:
				var k := t / FX_LONG
				for i in 8:
					var x := c.x - half.x + (float(i) + 0.5) * card.size.x / 8.0
					var y := c.y - half.y - 4.0 - 20.0 * sin(minf(k * 1.6, 1.0) * PI) * (0.6 + 0.4 * float(posmod(hash(i), 3)) / 2.0)
					_dot(Vector2(x, y), 2.0, Color(0.48, 0.74, 0.30, 1.0 - k))
		&"buzz":
			# Three bees darting round the card and off.
			if t < FX_LONG + 0.4:
				var k := t / (FX_LONG + 0.4)
				for i in 3:
					var ang := t * (6.0 + float(i)) + float(i) * 2.1
					var at := c + Vector2(cos(ang) * (half.x + 10.0 + 60.0 * k * k), sin(ang * 1.7) * (half.y + 6.0))
					var a := 1.0 - k
					_dot(at, 2.0, Color(0.95, 0.75, 0.16, a))
					_dot(at + Vector2(2.0, 0.0), 2.0, Color(0.1, 0.08, 0.06, a))
					_dot(at + Vector2(0.0, -2.0), 2.0, Color(1.0, 1.0, 1.0, a * 0.8))
		&"drip":
			# A drop of honey gathering under the card's foot and falling.
			var loop := fmod(maxf(t - 0.3, 0.0), 2.4)
			var foot := Vector2(c.x + half.x * 0.42, c.y + half.y + RIM + 1.0)
			var gold := Color(0.92, 0.62, 0.12)
			if loop < 1.4:
				var hang := floorf(loop / 1.4 * 4.0)
				draw_rect(Rect2(foot.x, foot.y, 2.0, 2.0 + hang * 2.0), gold, true)
				draw_rect(Rect2(foot.x - 1.0, foot.y + hang * 2.0, 4.0, 3.0), gold, true)
			else:
				var fall := (loop - 1.4) / 1.0
				draw_rect(Rect2(foot.x, foot.y, 2.0, 2.0), gold, true)
				draw_rect(Rect2(foot.x - 1.0, foot.y + 10.0 + fall * fall * 70.0, 4.0, 4.0), Color(gold, 1.0 - fall), true)


func _dot(at: Vector2, side: float, ink: Color) -> void:
	if ink.a > 0.0:
		draw_rect(Rect2(at.round(), Vector2(side, side)), ink, true)


## A four-point star of whole pixels: a plus with `arm` pixels each way and a pale heart.
func _star(at: Vector2, pixel: float, arm: int, ink: Color) -> void:
	if ink.a <= 0.0 or arm <= 0:
		return
	var o := at.round()
	for i in range(-arm, arm + 1):
		draw_rect(Rect2(o + Vector2(float(i), 0.0) * pixel, Vector2(pixel, pixel)), ink, true)
		draw_rect(Rect2(o + Vector2(0.0, float(i)) * pixel, Vector2(pixel, pixel)), ink, true)
	draw_rect(Rect2(o, Vector2(pixel, pixel)), Color(1.0, 1.0, 1.0, ink.a), true)


# --------------------------------------------------------------------------------------
# The icons
# --------------------------------------------------------------------------------------

## The icon in the middle of the tab, keeping its small loop once the card has landed.
func _draw_icon(look: Dictionary, strip: Rect2, t: float, alpha: float) -> void:
	var cell := CELL_HINT if _hint else CELL_MOMENT
	var icon: StringName = look[&"icon"]
	var band: Color = look[&"band"]
	var mid := strip.get_center() + Vector2(-1.0, 0.0)
	match icon:
		&"funnel":
			# Rows narrowing down to a point, each slid round by the spin, dark and pale by turns.
			var widths := [11, 9, 8, 7, 6, 5, 4, 3, 2, 2]
			var top := mid - Vector2(0.0, float(widths.size()) * cell * 0.5)
			for r in widths.size():
				var w: int = widths[r]
				var shift := roundf(sin(t * 7.0 - float(r) * 0.9) * (1.0 + float(r) * 0.12))
				var x0 := mid.x - float(w) * cell * 0.5 + shift * cell
				var y := top.y + float(r) * cell
				draw_rect(Rect2(x0 - cell, y, (float(w) + 2.0) * cell, cell), Color(0.08, 0.08, 0.12, alpha), true)
				draw_rect(Rect2(x0, y, float(w) * cell, cell),
					Color(Color(0.94, 0.95, 0.98) if r % 2 == 0 else Color(0.70, 0.76, 0.86), alpha), true)
		&"star":
			var twinkle := 3 + int(round(0.5 + 0.5 * sin(t * 4.0)))
			_star_cells(mid, cell, twinkle + 1, Color(0.18, 0.11, 0.0, alpha))
			_star_cells(mid, cell, twinkle, Color(1.0, 0.86, 0.32, alpha))
			draw_rect(Rect2((mid - Vector2(cell, cell) * 0.5).round(), Vector2(cell, cell)), Color(1.0, 1.0, 1.0, alpha), true)
		&"nets":
			# Two nets, the copy behind in a paler cord, swinging apart and back.
			var swing := roundf(sin(t * 3.0) * 1.0)
			var back: Array = []
			for row: String in ROWS[&"net"]:
				back.append(row.replace("w", "l"))
			_draw_rows(back, mid + Vector2(-3.0 + swing, -2.0) * cell, cell, band, alpha)
			_draw_rows(ROWS[&"net"], mid + Vector2(3.0 - swing, 2.0) * cell, cell, band, alpha)
		&"coin":
			var turn := 0.5 + 0.5 * cos(t * 3.2)
			var side := cell * 9.0
			HudButtons.coin_turned(self, Rect2(mid - Vector2(side, side) * 0.5, Vector2(side, side)),
				Color(1.0, 1.0, 1.0, alpha), turn)
		&"boat":
			var bob := roundf(sin(t * 3.0) * 0.8)
			_draw_rows(ROWS[&"boat"], mid + Vector2(0.0, bob * cell), cell, band, alpha)
		&"sprout":
			_draw_rows(ROWS[&"sprout"], mid, cell, band, alpha, roundf(sin(t * 2.4)))
		&"bee":
			var rows: Array = ROWS[&"bee"].duplicate()
			# The wings beat: every other tick they are folded down to a line.
			if int(t * 14.0) % 2 == 1:
				rows[0] = ".........."
				rows[1] = "..kkkkkk.."
				rows[2] = ".kwwwwwwk."
			_draw_rows(rows, mid + Vector2(0.0, roundf(sin(t * 5.0)) * cell), cell, band, alpha)
		&"jar":
			_draw_rows(ROWS[&"jar"], mid, cell, band, alpha)


## A plus-star in cells about `mid`.
func _star_cells(mid: Vector2, cell: float, arm: int, ink: Color) -> void:
	var o := (mid - Vector2(cell, cell) * 0.5).round()
	for i in range(-arm, arm + 1):
		var reach := 0 if absi(i) > 1 else 1
		for j in range(-reach, reach + 1):
			draw_rect(Rect2(o + Vector2(float(i), float(j)) * cell, Vector2(cell, cell)), ink, true)
			draw_rect(Rect2(o + Vector2(float(j), float(i)) * cell, Vector2(cell, cell)), ink, true)


## An icon drawn from rows of letters, centred on `mid`; `sway` slides the top half of the
## rows that many cells sideways (the sprout's leaves in a breeze).
func _draw_rows(rows: Array, mid: Vector2, cell: float, band: Color, alpha: float, sway: float = 0.0) -> void:
	var tall := rows.size()
	var wide := 0
	for row: String in rows:
		wide = maxi(wide, row.length())
	var origin := (mid - Vector2(float(wide), float(tall)) * cell * 0.5).round()
	for r in tall:
		var row: String = rows[r]
		var shift := sway if r * 2 < tall else 0.0
		for i in row.length():
			var ch := row[i]
			if ch == ".":
				continue
			var ink := _letter_ink(ch, band)
			draw_rect(Rect2(origin + Vector2(float(i) + shift, float(r)) * cell, Vector2(cell, cell)), Color(ink, alpha), true)


static func _letter_ink(ch: String, band: Color) -> Color:
	match ch:
		"k": return Color(0.08, 0.06, 0.06)
		"w": return Color(0.97, 0.97, 0.94)
		"p": return Style.PAPER
		"y": return Color(0.98, 0.78, 0.22)
		"o": return Color(0.80, 0.50, 0.08)
		"g": return Color(0.82, 0.96, 0.58)
		"G": return Color(0.58, 0.86, 0.32)
		"b": return Color(0.30, 0.56, 0.86)
		"d": return band.darkened(0.45)
		"l": return band.lightened(0.45)
	return Color.MAGENTA


# --------------------------------------------------------------------------------------
# The words
# --------------------------------------------------------------------------------------

## Marked-up text laid out in rows of units `{text, marked, space}` no wider than `wide`:
## the letter's `*marked*` words (`Letter._tokens`), a newline starting a row, and a word too
## wide to stand on a row alone broken into its letters — Japanese, Chinese and Korean carry
## few spaces or none, and a line of them is one "word".
static func lay_out(marked_text: String, px: int, wide: float) -> Array:
	var rows: Array = []
	var row: Array = []
	var row_wide := 0.0
	var space := Style.measure(" ", px).x
	for word: Dictionary in Letter._tokens(marked_text):
		if bool(word["para"]) and not row.is_empty():
			rows.append(row)
			row = []
			row_wide = 0.0
		var units: Array = []
		for seg: Array in word["segs"]:
			units.append({"text": String(seg[0]), "marked": bool(seg[1]), "space": false})
		var whole := 0.0
		for unit: Dictionary in units:
			whole += Style.measure(String(unit["text"]), px).x
		if whole > wide:
			# Broken into letters, each its own unit, joined with no space.
			var letters: Array = []
			for unit: Dictionary in units:
				for ch in String(unit["text"]):
					letters.append({"text": ch, "marked": unit["marked"], "space": false})
			units = letters
		var first := true
		for unit: Dictionary in units:
			var w := Style.measure(String(unit["text"]), px).x
			var lead := space if (first and not row.is_empty() and whole <= wide) else 0.0
			if not row.is_empty() and row_wide + lead + w > wide:
				rows.append(row)
				row = []
				row_wide = 0.0
				lead = 0.0
			var placed: Dictionary = unit.duplicate()
			placed["space"] = lead > 0.0
			row.append(placed)
			row_wide += lead + w
			first = false
	if not row.is_empty():
		rows.append(row)
	return rows


## Every unit's words as one string, the row's plain text: the harness reads it.
static func plain(rows: Array) -> String:
	var out := PackedStringArray()
	for row: Array in rows:
		var line := ""
		for unit: Dictionary in row:
			line += (" " if bool(unit["space"]) else "") + String(unit["text"])
		out.append(line)
	return "\n".join(out)


static func _row_wide(row: Array, px: int) -> float:
	var w := 0.0
	for unit: Dictionary in row:
		if bool(unit["space"]):
			w += Style.measure(" ", px).x
		w += Style.measure(String(unit["text"]), px).x
	return w


static func _widest(rows: Array, px: int) -> float:
	var w := 0.0
	for row: Array in rows:
		w = maxf(w, _row_wide(row, px))
	return w
