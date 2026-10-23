## The record player's menu (2026-09-28, `/grill-me` with Richard): E on the record player in
## the shed lifts its lid and puts this up over the room. Which songs play out on the lake and
## which in the shed, ticked in two columns; a Sync switch under them that sends the lake's
## own song into the shed; the song playing now and a skip, under a record that turns.
##
## Drawn in the record player's own colours — the lid's mauve lining for the face, walnut
## for the case, silver for what is lit — on whole art pixels of `UNIT` design
## pixels, laid out in those pixels off the mockup it was picked from
## (`tools/build_record_menu_mockup.py`, option A).
##
## Holds no state of its own: every tick is `MusicStation`'s, which the save carries. The
## needle lifts off the record and comes back whenever the song it is playing changes —
## skipped here, or played through while the menu is up (`changes_in`).
class_name RecordMenu
extends Control

const Style := preload("res://scripts/style.gd")

signal closed

## Design pixels to one art pixel of the board.
const UNIT := 3.0
## The board in art pixels, for five songs. Each song past five makes it a row taller
## (`art()`): Loobas' two took it to seven (2026-10-12). It went 20 wider for "Movimento
## Tranquilo", which wants 172 design pixels at the rows' size (`tools/probe_record_titles.gd`).
const ART := Vector2(220, 140)
const ROWS_BASE := 5

# The pack turntable's own colours (2026-10-01): the record player in the shed is the
# 0_mem0ry one now, black and greys with a silver deck, so the board it opens is drawn in
# them. Names kept from the walnut cabinet it was: WALNUT is the dark body, LID the panels,
# AMBER the silver accent.
const OUT := Color8(8, 8, 8)
const LID := Color8(58, 58, 58)
const LID_LO := Color8(48, 48, 48)
const WALNUT := Color8(69, 69, 69)
const WALNUT_LO := Color8(33, 33, 33)
const WALNUT_HI := Color8(110, 110, 110)
const AMBER := Color8(192, 192, 192)
const AMBER_HI := Color8(218, 218, 218)
const AMBER_LO := Color8(130, 130, 130)
const CREAM := Color8(240, 240, 236)
const DIM := Color8(150, 150, 150)
const GHOST := Color8(101, 101, 101)
const VINYL := Color8(14, 14, 14)
const VINYL_HI := Color8(48, 48, 48)
const SCRIM := Color(0.0, 0.0, 0.0, 0.45)

## How the songs are written. Names, not words: not translated. The slugs are the files'
## working names; the titles are the songs' own (2026-10-13, Richard).
const TITLES := {
	&"beatgucci": "House by the Lake",
	&"save_me": "Hello World",
	&"goin": "Sanctuary",
	&"indie_boi": "This is Nice",
	&"habibs": "Memory Lane",
	&"movimento_tranquilo": "Movimento Tranquilo",
	&"tudo_que_eu_fiz": "Tudo Que Eu Fiz",
}

## The record: its middle and radius in art pixels, and how fast it turns — 33 and a third,
## stepped at the lake's own `pixel_fps` so it turns in pixel-art beats.
## The label says who made the music (2026-10-10, `/grill-me` with Richard; supersedes the grey
## label with "Nuven" curved round its top): a cherry red label, the one spot of colour on the
## grey turntable, with NUVEN in cream straight across it above the hole and a shadow a pixel
## straight down the screen. The word turns with the record. Turned by rule it broke up at the
## in-between steps, so `tools/build_record_label.py` bakes it at the first four steps of the
## turn (RotSprite letter by letter, the worst letters drawn by hand) into `LABEL_ART`; every
## other step is one of those turned by whole right angles, exact on the grid. A name, not
## translated.
##
## **The record is the song's artist's** (2026-10-12, Richard: "it should change the record
## between loobas and nuven when switching songs"): a Loobas song plays on a blue LOOBAS label
## (the clean water's ramp, `water_clean_mid`, `_deep`, `_shallow`), any other on the red
## NUVEN one (`label_for`). The record is swapped while the needle is up and over the middle
## of its crossing (`_shown_band`), never under the needle. The demo has no Loobas songs, so
## its record is always NUVEN.
const LABEL_ART := "res://assets/record_label.png"
const LABEL_R := 16
const LABEL := Color8(178, 48, 44)
const LABEL_LO := Color8(112, 26, 26)
const LABEL_HI := Color8(214, 92, 70)
const LABEL_INK := Color8(240, 232, 210)
const LOOBAS_ART := "res://assets/record_label_loobas.png"
const LOOBAS := Color8(65, 107, 146)
const LOOBAS_LO := Color8(44, 77, 110)
const LOOBAS_HI := Color8(127, 167, 198)

const DISC_AT := Vector2(52, 56)
const DISC_R := 31
const SPIN_RPS := 0.555
const SPIN_FRAMES := 16
const SPIN_FPS := 8.0

## The tonearm: its pivot, and its line as points off the pivot. The record is an album:
## one band of grooves a song, `SONGS`' order from the rim in (Movimento Tranquilo outermost, Habibs
## by the label), each band `GROOVE_OUT` to `GROOVE_IN` split one band a song with a smooth gap
## between. The needle stands still in the middle of its song's band. On a change of song it
## comes up off the record over `ARM_LIFT` seconds (the head rises `ARM_RISE` art pixels over
## its own shadow), crosses straight to the new song's band over `ARM_MOVE`, and sets down
## over `ARM_DROP` (Richard, 2026-09-28: no swing out past the rim). The record keeps
## turning through a skip (Richard, 2026-09-29: it used to spin down while the needle was up).
const ARM_PIVOT := Vector2(80, 24)
const ARM_ELBOW := Vector2(0, 26)
const ARM_TIP := Vector2(-12, 36)
const GROOVE_OUT := 30.0
const GROOVE_IN := 17.0
const GAP_TONE := Color8(10, 10, 10)
const GROOVE_TONE := Color8(36, 36, 36)
const ARM_LIFT := 0.2
const ARM_MOVE := 0.5
const ARM_DROP := 0.25
const ARM_RISE := 3.0

## The rows, the two tick columns and the switch, in art pixels.
## `SYNC_BOX` is where five songs put it; `sync_box()` moves it down a row a song past five.
const ROWS_AT := Vector2(96, 26)
const ROW := Vector2(108, 13)
const ROW_GAP := 15.0
const TICK_X := [163.0, 190.0]
const SYNC_BOX := Rect2(126, 104, 48, 16)
const NOW_BOX := Rect2(16, 98, 72, 24)
## Back and skip stand side by side under the panel, on its middle (2026-10-23, Richard's
## QA run: a way back on the list, or the same song again), so the title has the panel's
## whole width.
const BACK_BOX := Rect2(39, 126, 11, 11)
const SKIP_BOX := Rect2(54, 126, 11, 11)

## The station the ticks are read from and written to. The autoload unless set.
var music: MusicStation

var _board := Rect2()
var _close: CloseButton
var _hover := &""
## Seconds the record has turned.
var _spin := 0.0
## label art file -> its record, one picture a step of the turn.
var _discs: Dictionary = {}
## The arm's swing, 0 on the record to 1 lifted clear, and the clock of a lift under way.
var _arm := 0.0
## The band the needle stands in, an index into `SONGS`: held while the needle is up, and
## taken again once it is out past the rim, so it drops onto the new song's band.
var _band := 0
## The band the needle is crossing from, and how far across it is, 0 to 1.
var _from := 0
var _cross := 1.0
## A skip under way: the song is held and the next starts when the needle sets down.
var _skipping := false
## Which way it goes: 1 on to the next song, -1 back (`MusicStation.back`).
var _skip_way := 1
## The record's turning speed, 0 to 1.
var _speed := 1.0
var _lift := -1.0
var _seen := -1


func _ready() -> void:
	add_to_group(Pad.FOCUS_GROUP)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Over the whole window, not the shed's panel it hangs off: the room is not the screen.
	top_level = true
	get_viewport().size_changed.connect(_fit)
	_fit()
	_close = CloseButton.new()
	_close.pressed.connect(close)
	add_child(_close)
	_bake_disc()
	resized.connect(_lay_out)
	_lay_out()


func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func _station() -> MusicStation:
	return music if music != null else MusicStation.main()


## Put the menu up; the needle starts wherever the song has got to.
func open() -> void:
	visible = true
	var m := _station()
	_seen = m.changes_in(MusicStation.SHED) if m != null else -1
	_arm = 0.0
	_lift = -1.0
	_hover = &""
	queue_redraw()


func close() -> void:
	if not visible:
		return
	visible = false
	_land_skip()
	Sfx.ui(&"ui_close")
	closed.emit()


## How many art pixels taller than `ART` the board is for the songs this build offers.
static func extra() -> float:
	return maxf(0.0, MusicStation.shown().size() - ROWS_BASE) * ROW_GAP


static func art() -> Vector2:
	return ART + Vector2(0, extra())


static func sync_box() -> Rect2:
	return Rect2(SYNC_BOX.position + Vector2(0, extra()), SYNC_BOX.size)


## [art file, face, rim, lit ring round the hole] for the label a song plays on.
static func label_for(slug: StringName) -> Array:
	if MusicStation.LOOBAS.has(slug):
		return [LOOBAS_ART, LOOBAS, LOOBAS_LO, LOOBAS_HI]
	return [LABEL_ART, LABEL, LABEL_LO, LABEL_HI]


## The band whose record is on the platter: the one the needle left until it is half way
## across to the next, then the next.
func _shown_band() -> int:
	return _band if _cross >= 0.5 else _from


## The art file of the label on the platter now, for the harness.
func shown_label() -> String:
	var songs := MusicStation.shown()
	var i := _shown_band()
	return label_for(songs[i] if i >= 0 and i < songs.size() else &"")[0]


func _lay_out() -> void:
	var span := art() * UNIT
	_board = Rect2(((size - span) * 0.5).floor(), span)
	if _close != null:
		var side := 44.0
		_close.size = Vector2(side, side)
		_close.position = Vector2(_board.end.x - side * 0.75, _board.position.y - side * 0.25)


## An art-pixel box on the board, in this control's pixels.
func _box(r: Rect2) -> Rect2:
	return Rect2(_board.position + r.position * UNIT, r.size * UNIT)


func _px(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(_box(Rect2(x, y, w, h)), c)


func _edge(x: float, y: float, w: float, h: float, c: Color) -> void:
	_px(x, y, w, 1, c)
	_px(x, y + h - 1, w, 1, c)
	_px(x, y, 1, h, c)
	_px(x + w - 1, y, 1, h, c)


func _panel(r: Rect2, face: Color, lit: Color) -> void:
	_px(r.position.x, r.position.y, r.size.x, r.size.y, face)
	_edge(r.position.x, r.position.y, r.size.x, r.size.y, OUT)
	_px(r.position.x + 1, r.position.y + 1, r.size.x - 2, 1, lit)


## Every place something answers a click, by key: `tick:<place>:<slug>`, `sync`, `back`,
## `skip`.
func _targets() -> Dictionary:
	var out := {}
	for i in MusicStation.shown().size():
		var slug: StringName = MusicStation.shown()[i]
		if MusicStation.demo_locked(slug):
			continue
		var y := ROWS_AT.y + i * ROW_GAP + 3.0
		out[StringName("tick:lake:" + String(slug))] = _box(Rect2(TICK_X[0] - 3, y - 3, 13, 13))
		out[StringName("tick:shed:" + String(slug))] = _box(Rect2(TICK_X[1] - 3, y - 3, 13, 13))
	out[&"sync"] = _box(sync_box())
	out[&"back"] = _box(BACK_BOX)
	out[&"skip"] = _box(SKIP_BOX)
	return out


func _under(at: Vector2) -> StringName:
	var targets := _targets()
	for key: StringName in targets:
		if (targets[key] as Rect2).has_point(at):
			return key
	return &""


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		var now := _under(motion.position)
		if now != _hover:
			_hover = now
			if not now.is_empty():
				Sfx.ui(&"ui_hover")
			queue_redraw()
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if not _board.grow(8.0).has_point(click.position):
		close()
		return
	press(_under(click.position))


## Work one control by key. The mouse, the pad and the harness all come through here.
func press(key: StringName) -> bool:
	var m := _station()
	if m == null or key.is_empty():
		return false
	var done := false
	if key == &"sync":
		m.set_synced(not m.synced)
		done = true
	elif key == &"skip" or key == &"back":
		# The song stops as the needle comes up, and the next one only starts once the
		# needle has set down on its band (Richard, 2026-09-28). Back the same way, to the
		# song before or to the start of this one.
		if _lift >= 0.0 or _skipping:
			return false
		_skip_way = -1 if key == &"back" else 1
		var going := m.back_in(MusicStation.SHED) if _skip_way < 0 else m.next_in(MusicStation.SHED)
		var next := MusicStation.shown().find(going)
		m.hold(MusicStation.SHED)
		_skipping = true
		_from = _band
		_band = next if next >= 0 else _band
		_cross = 0.0
		_lift = 0.0
		done = true
	elif String(key).begins_with("tick:"):
		var parts := String(key).split(":")
		var place := StringName(parts[1])
		if place == MusicStation.SHED and m.synced:
			return false
		done = m.toggle(place, StringName(parts[2]))
	if done:
		Sfx.ui(&"ui_click")
	queue_redraw()
	return done


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE or event.is_action_pressed(&"interact"):
		close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	var m := _station()
	var changes := m.changes_in(MusicStation.SHED) if m != null else 0
	if _seen >= 0 and changes != _seen and _lift < 0.0:
		_lift = 0.0
		_from = _band
		_cross = 0.0
	_seen = changes
	var live := MusicStation.shown().find(m.playing_in(MusicStation.SHED)) if m != null else 0
	if live >= 0 and not _skipping:
		_band = live
	if _lift >= 0.0:
		_lift += delta
		if _lift < ARM_LIFT:
			_arm = ease(_lift / ARM_LIFT, 0.4)
			_cross = 0.0
		elif _lift < ARM_LIFT + ARM_MOVE:
			_arm = 1.0
			_cross = ease((_lift - ARM_LIFT) / ARM_MOVE, -2.0)
		elif _lift < ARM_LIFT + ARM_MOVE + ARM_DROP:
			_arm = 1.0 - ease((_lift - ARM_LIFT - ARM_MOVE) / ARM_DROP, 2.2)
			_cross = 1.0
		else:
			_arm = 0.0
			_cross = 1.0
			_lift = -1.0
			_land_skip()
	# The record keeps turning through a skip; only the needle moves.
	_spin = fmod(_spin + delta * _speed, 3600.0)
	queue_redraw()


## The needle has set down on the skipped-to song's band: play it.
func _land_skip() -> void:
	if not _skipping:
		return
	_skipping = false
	var m := _station()
	if m != null:
		if _skip_way < 0:
			m.back(MusicStation.SHED)
		else:
			m.skip(MusicStation.SHED)
		_seen = m.changes_in(MusicStation.SHED)


## Whether the needle is lifted off the record right now, for the harness.
func needle_up() -> bool:
	return _arm > 0.01


## The record, one picture a step of its turn: grooves, the red label and the name turning on it.
## Whole art pixels, baked once.
func _bake_disc() -> void:
	_discs.clear()
	for look in [label_for(&""), label_for(MusicStation.LOOBAS[0])]:
		if not _discs.has(look[0]):
			_discs[look[0]] = _bake_one(look)


func _bake_one(look: Array) -> Array[ImageTexture]:
	var out: Array[ImageTexture] = []
	var word := _label_word(look[0])
	var face: Color = look[1]
	var rim: Color = look[2]
	var ring: Color = look[3]
	var hole := DISC_R * 0.12
	var side := DISC_R * 2 + 1
	for f in SPIN_FRAMES:
		var img := Image.create(side, side, false, Image.FORMAT_RGBA8)
		for y in range(-DISC_R, DISC_R + 1):
			for x in range(-DISC_R, DISC_R + 1):
				var q := Vector2(x, y).length()
				if q > DISC_R + 0.3:
					continue
				var c := VINYL
				if q > DISC_R - 0.8:
					c = OUT
				elif q >= GROOVE_IN and q <= GROOVE_OUT:
					# A band of grooves a song with a smooth gap between each.
					var across := (GROOVE_OUT - q) / band_wide()
					var into := across - floorf(across)
					var last := MusicStation.shown().size() - 0.5
					if across > 0.5 and (into < 0.18 or into > 0.82) and across < last:
						c = GAP_TONE
					else:
						c = VINYL_HI if int(q) % 2 == 0 else GROOVE_TONE
				if q <= LABEL_R:
					c = rim if q > LABEL_R - 1.0 else face
					if q <= hole + 1.6:
						c = ring
					if word != null and q > hole:
						if label_ink(word, f, x, y):
							c = LABEL_INK
						elif label_ink(word, f, x, y - 1):
							c = rim
					if q <= hole:
						c = OUT
				img.set_pixel(x + DISC_R, y + DISC_R, c)
		out.append(ImageTexture.create_from_image(img))
	return out


## The baked word, four steps of the turn side by side, or null with no art (a bare label).
static func _label_word(path: String) -> Image:
	if not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	return tex.get_image() if tex != null else null


## Whether the name is on art pixel (x, y) off the record's middle at turn step `frame`: the
## step's quarter turn undone a right angle at a time, then looked up in that step's cell.
static func label_ink(word: Image, frame: int, x: int, y: int) -> bool:
	var cell := word.get_height()
	var step := frame % 4
	for i in frame / 4:
		var t := x
		x = y
		y = -t
	var u := step * cell + x + cell / 2
	var v := y + cell / 2
	if x < -cell / 2 or x > cell / 2 or v < 0 or v >= cell:
		return false
	return word.get_pixel(u, v).a > 0.5


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SCRIM)
	var m := _station()
	# The case and the lid's lining.
	var grow := extra()
	_px(4, 6, 212, 128 + grow, WALNUT)
	_edge(4, 6, 212, 128 + grow, OUT)
	_px(5, 7, 210, 2, WALNUT_HI)
	_px(10, 12, 200, 116 + grow, LID_LO)
	_edge(10, 12, 200, 116 + grow, OUT)
	_px(11, 13, 198, 1, LID)
	_draw_platter()
	_draw_now(m)
	_draw_rows(m)
	_draw_sync(m)


func _draw_platter() -> void:
	_px(16, 20, 72, 72, WALNUT_LO)
	_edge(16, 20, 72, 72, OUT)
	var disc: Array = _discs.get(shown_label(), [])
	if not disc.is_empty():
		# Stepped: the turn advances SPIN_FPS times a second, not every frame.
		var turn := floorf(_spin * SPIN_FPS) / SPIN_FPS * SPIN_RPS
		var f := int(floorf(turn * SPIN_FRAMES)) % SPIN_FRAMES
		var tex: ImageTexture = disc[f]
		draw_texture_rect(
			tex,
			_box(Rect2(DISC_AT - Vector2(DISC_R, DISC_R), Vector2(DISC_R * 2 + 1, DISC_R * 2 + 1))),
			false
		)
	# The arm, turned about its pivot from the old band to the new one, drawn a whole art
	# pixel at a time. Lifted, the head rises over its own shadow on the record.
	var turn := lerpf(_angle_for(band_middle(_from)), _angle_for(band_middle(_band)), _cross)
	var elbow := ARM_PIVOT + ARM_ELBOW.rotated(turn)
	var tip := ARM_PIVOT + ARM_TIP.rotated(turn)
	var rise := Vector2(0, -roundf(ARM_RISE * _arm))
	if rise.y < 0.0:
		_px(roundf(tip.x) - 2, roundf(tip.y) - 1, 4, 3, OUT)
	_arm_line(ARM_PIVOT, elbow + rise * 0.5)
	_arm_line(elbow + rise * 0.5, tip + rise)
	_px(roundf(tip.x) - 2, roundf(tip.y + rise.y) - 1, 4, 3, AMBER)
	_px(77, 21, 6, 6, AMBER_LO)
	_edge(77, 21, 6, 6, OUT)


## The arm's turn about its pivot that puts the needle this far off the record's middle.
## Searched, not solved: the arm is two segments and the answer is wanted once a frame.
func _angle_for(reach: float) -> float:
	var best := 0.0
	var best_gap := INF
	for i in 161:
		var a := -1.2 + i * 0.01
		var gap := absf((ARM_PIVOT + ARM_TIP.rotated(a)).distance_to(DISC_AT) - reach)
		if gap < best_gap:
			best_gap = gap
			best = a
	return best


## How wide a song's band is, and how far its middle is off the record's.
static func band_wide() -> float:
	return (GROOVE_OUT - GROOVE_IN) / float(MusicStation.shown().size())


static func band_middle(index: int) -> float:
	return GROOVE_OUT - (float(index) + 0.5) * band_wide()


## The band the needle stands in, and how fast the record turns, for the harness.
func band() -> int:
	return _band


func turning() -> float:
	return _speed


func _arm_line(a: Vector2, b: Vector2) -> void:
	var steps := int(ceil(a.distance_to(b)))
	for i in steps + 1:
		var p := a.lerp(b, float(i) / maxf(steps, 1))
		_px(roundf(p.x), roundf(p.y), 1, 1, CREAM)


func _draw_now(m: MusicStation) -> void:
	_panel(NOW_BOX, WALNUT, WALNUT_HI)
	var box := _box(NOW_BOX)
	Style.write(self, Text.RECORD_NOW, Style.TEXT_TINY,
		box.position + Vector2(4 * UNIT, 8 * UNIT), AMBER_HI)
	var slug := m.playing_in(MusicStation.SHED) if m != null else &""
	# The title drops a size rather than run off the panel: "Movimento Tranquilo" is 211
	# design pixels at the body size against the 192 the panel leaves.
	var title := String(TITLES.get(slug, ""))
	Style.write(self, title, _fit_size(title, (NOW_BOX.size.x - 8) * UNIT,
		[Style.TEXT_BODY, Style.TEXT_SMALL, Style.TEXT_TINY]),
		box.position + Vector2(4 * UNIT, 20 * UNIT), CREAM)
	# Skip: a wedge pointing on, a bar after it. Back: the same turned round.
	var skip := SKIP_BOX
	_panel(skip, AMBER_HI if _hover == &"skip" else AMBER, AMBER_HI)
	var x := skip.position.x
	var y := skip.position.y
	for k in 4:
		_px(x + 3 + k, y + 2 + k, 1, 7 - k * 2, OUT)
	_px(x + 8, y + 2, 1, 7, OUT)
	var back := BACK_BOX
	_panel(back, AMBER_HI if _hover == &"back" else AMBER, AMBER_HI)
	x = back.position.x
	y = back.position.y
	_px(x + 2, y + 2, 1, 7, OUT)
	for k in 4:
		_px(x + 7 - k, y + 2 + k, 1, 7 - k * 2, OUT)


func _draw_rows(m: MusicStation) -> void:
	var head := _board.position + Vector2(ROWS_AT.x + 2, ROWS_AT.y - 3) * UNIT
	Style.write(self, Text.RECORD_SONG, Style.TEXT_SMALL, head, AMBER_HI)
	for c in 2:
		var mid := _box(Rect2(TICK_X[c], 0, 7, 1))
		Style.write(self, [Text.RECORD_LAKE, Text.RECORD_SHED][c], Style.TEXT_SMALL,
			Vector2(0, head.y), AMBER_HI, HORIZONTAL_ALIGNMENT_CENTER,
			Rect2(mid.get_center().x - 40, 0, 80, 1))
	var synced := m != null and m.synced
	for i in MusicStation.shown().size():
		var slug: StringName = MusicStation.shown()[i]
		var y := ROWS_AT.y + i * ROW_GAP
		_px(ROWS_AT.x, y, ROW.x, ROW.y, LID if i % 2 else LID_LO)
		var open := m == null or m.can_pick(slug)
		var title := String(TITLES[slug])
		Style.write(self, title, _fit_size(title, (TICK_X[0] - ROWS_AT.x - 6) * UNIT,
			[Style.TEXT_SMALL, Style.TEXT_TINY]),
			_board.position + Vector2(ROWS_AT.x + 3, y + 9) * UNIT, CREAM if open else DIM)
		# A song the demo does not play says so across both tick columns (2026-10-13).
		if MusicStation.demo_locked(slug):
			var words := Text.DEMO_LOCKED
			var span := Rect2(TICK_X[0] - 3, 0, ROWS_AT.x + ROW.x - TICK_X[0] + 1, 1)
			Style.write(self, words, _fit_size(words, span.size.x * UNIT,
				[Style.TEXT_SMALL, Style.TEXT_TINY]),
				_board.position + Vector2(0, (y + 9) * UNIT), DIM, HORIZONTAL_ALIGNMENT_CENTER,
				_box(span))
			continue
		for c in 2:
			var tx: float = TICK_X[c]
			if not open:
				_lock(tx, y + 3, DIM)
				continue
			var shed := c == 1
			var on: bool = false
			if m != null:
				on = m.ticked(MusicStation.LAKE if not shed or synced else MusicStation.SHED, slug)
			var ghost := shed and synced
			var key := StringName("tick:%s:%s" % ["shed" if shed else "lake", slug])
			var face := LID_LO if ghost else WALNUT_LO
			if _hover == key and not ghost:
				face = WALNUT
			_tick(tx, y + 3, on, face, GHOST if ghost else AMBER_HI)


## The first size on the ladder at which the line fits `room` design pixels, else the last.
static func _fit_size(text: String, room: float, ladder: Array) -> int:
	for px in ladder:
		if Style.measure(text, px).x <= room:
			return px
	return ladder.back()


func _tick(x: float, y: float, on: bool, face: Color, mark: Color) -> void:
	_px(x, y, 7, 7, face)
	_edge(x, y, 7, 7, OUT)
	if on:
		for p in [Vector2(1, 3), Vector2(2, 4), Vector2(3, 5), Vector2(4, 4), Vector2(5, 3), Vector2(5, 2)]:
			_px(x + p.x, y + p.y, 1, 1, mark)


func _lock(x: float, y: float, c: Color) -> void:
	_px(x + 1, y + 3, 5, 4, c)
	_px(x + 2, y, 3, 1, c)
	_px(x + 2, y, 1, 3, c)
	_px(x + 4, y, 1, 3, c)


func _draw_sync(m: MusicStation) -> void:
	var on := m != null and m.synced
	var r := sync_box()
	_panel(r, WALNUT_HI if _hover == &"sync" else WALNUT, WALNUT_HI)
	var box := _box(r)
	Style.write(self, Text.RECORD_SYNC, Style.TEXT_SMALL, Vector2(0, box.position.y + 11 * UNIT),
		CREAM, HORIZONTAL_ALIGNMENT_CENTER, _box(Rect2(r.position.x + 2, 0, 24, 1)))
	_px(r.position.x + 27, r.position.y + 4, 17, 8, OUT)
	_px(r.position.x + 28, r.position.y + 5, 15, 6, AMBER_LO if on else WALNUT_LO)
	_px(r.position.x + (36 if on else 28), r.position.y + 5, 7, 6, AMBER_HI if on else LID)


## Walked with the pad's stick: every tick that answers, the switch, the skip, the cross.
func pad_focus() -> Array:
	var out: Array = []
	var m := _station()
	var targets := _targets()
	for key: StringName in targets:
		var s := String(key)
		if s.begins_with("tick:"):
			var parts := s.split(":")
			if m != null and not m.can_pick(StringName(parts[2])):
				continue
			if parts[1] == "shed" and m != null and m.synced:
				continue
		out.append({"box": targets[key], "key": key, "first": key == StringName("tick:lake:" + String(MusicStation.shown()[0]))})
	if _close != null:
		out.append({"box": _close.get_rect(), "key": &"close"})
	return out
