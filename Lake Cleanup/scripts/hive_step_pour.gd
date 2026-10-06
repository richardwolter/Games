## The pour: the harvest's last step, honey out of the bucket into three jars (2026-09-30, the
## beehive; the second pass, Richard, off `tools/hive_mockup2.py` `room_pour`).
##
## The uncapping's own bucket stands on the bottling table at the top of the room, **its level
## where the uncapping left it** (`HiveRoom.honey`), with a brass gate under the table over an
## empty jar. **The gate's lever is the control**: a brass bar with a wooden grip on the gate's
## pivot, standing up shut. **Hold on it** (the left button on the lever, or on the pad A or RT)
## and it turns sideways, the gate opens and honey runs — thicker the further it has turned —
## and **let go and it springs shut** with a little overshoot. No arrow, no wheel.
##
## The stream is gooey: its head falls from the spout under gravity, it narrows as it falls and
## wobbles, it folds into coils where it lands on the honey in the jar; shut, its tail parts
## from the spout as a thread and falls in after. The jar fills with a meniscus climbing the
## glass. **Fill it to the dashed line and let go**: at or over `DONE_AT` the jar is done — its
## small gingham lid drops on with a pop and stars, it slides along to the board, and the next
## empty slides in under the gate. Over the top it crowns and runs down the glass; **no
## penalty**. Three jars finish the step, the bucket drawn down as they fill.
##
## **The jars are the builder's `jar2_*` layers**: the glass's tint behind, the honey drawn over
## it a painted-pixel row at a time inside the glass (`_span_of`, the builder's own body), the
## edge and highlights in front, then the label and the lid.
##
## **Harness hooks, never gated on `awake`**: `pour(seconds)` (the lever held open that long),
## `release()`, `jars_done()`, `fill()`, `lever_open()` and `settle()`. The glug is the step's
## own player, `Glug`, on SFX.
class_name HiveStepPour
extends HiveStep

const JARS := 3
## A few loose bees in the air behind the table (`HiveStep.wanderers`), after the honey.
const AIR := 6
const AIR_BOX := Rect2(20.0, 20.0, 600.0, 150.0)
## A full-open gate fills this share of a jar a second.
const RATE := 0.42
## Let go at or over this and the jar is done; the line is drawn at `LINE_AT`; honey crowns
## past 1 and stops rising at `CROWN_MOST`.
const DONE_AT := 0.7
const LINE_AT := 0.86
const CROWN_MOST := 1.14

## Where things stand, painted pixels: the table's top middle, the jar under the gate's feet,
## the empty waiting on the lawn and the board's slots.
const TABLE_TOP := Vector2(320.0, 146.0)
const JAR_FEET := Vector2(320.0, 288.0)
const WAIT_FEET := Vector2(208.0, 288.0)
const BOARD := Rect2(392.0, 288.0, 150.0, 6.0)
const SLOTS: Array[float] = [414.0, 460.0, 506.0]
## The jar's body on its canvas (the builder's `JAR2_*`), and the canvas's feet anchor.
const JAR_W := 34
const JAR_H := 44
const JAR_TOP := 10
const JAR_FEET_AT := Vector2(19.0, 55.0)

## The lever: its length and grip, how fast it turns under the hand, and the spring that
## shuts it (stiffness, damping) with its overshoot.
const LEVER_LONG := 32.0
const GRIP_LONG := 12.0
const OPEN_EASE := 7.0
const SPRING_K := 260.0
const SPRING_DAMP := 14.0
## A press within this of the lever's grip (or its bar) takes it.
const GRAB_REACH := 18.0

## The stream: its widest at the spout (full open) and narrowest, its fall, and how its
## wobble grows as it falls.
const WIDE_MOST := 11.0
const WIDE_LEAST := 3.0
const FALL := 520.0
const WOBBLE := 1.2
## The coils where it lands: one every this while it pours, living this long.
const COIL_EVERY := 0.09
const COIL_LIFE := 0.7
## The mound where the stream lands and each fold's humps, painted px tall, and how far a
## fold's swirl sinks under the surface over its life.
const MOUND_TALL := 2.0
const FOLD_TALL := 2.0
const SINK_DEEP := 7.0
## How far down inside the bucket the honey's surface is once it is all poured, painted px:
## the bucket empties as the jars fill (2026-10-04, Richard), the surface sinking inside it.
const POOL_DEEP := 12.0

## A done jar: the lid falls on over `LID_TIME` from `LID_FROM` up, then it slides to the
## board over `SLIDE`; the next slides in over `SLIDE_IN`.
const LID_TIME := 0.2
const LID_FROM := 14.0
const SLIDE := 0.5
const SLIDE_IN := 0.45
const HOP := 5.0
const FINALE_WAIT := 1.8
## The shared ending over the three jars on the board (`HiveStep.payoff`).
const FINALE_AT := Vector2(460.0, 262.0)
const FINALE_WIDE := 110.0
const STAR_LIFE := 0.7
const GLUG_DB := -14.0
const GLUG_FADE := 0.08

const WOOD := Color(120 / 255.0, 84 / 255.0, 56 / 255.0)
const WOOD_HI := Color(150 / 255.0, 110 / 255.0, 76 / 255.0)
const WOOD_LO := Color(90 / 255.0, 60 / 255.0, 40 / 255.0)
const BRASS_LIT := Color(252 / 255.0, 222 / 255.0, 128 / 255.0)
const BRASS := Color(216 / 255.0, 166 / 255.0, 62 / 255.0)
const BRASS_SHADE := Color(160 / 255.0, 112 / 255.0, 38 / 255.0)
## The shadow on the lawn under what stands in this step: a contact ellipse in the one ink
## every shadow on land takes (`Shade.tint_on`, 2026-10-02, one sun), nudged along the sun
## (`Shade.drop`) as if from `CONTACT_RISE` painted px up, so it falls down and to the left
## like every other shadow on the island. Kept an ellipse and kept flat, by decision: the
## step is seen from eye height over the lawn, where a footprint is a thin band, and a
## silhouette cast off the close-up would be the one shadow in the room not lying on it.
const CONTACT_RISE := 4.0

var _roll := RandomNumberGenerator.new()
## The lever's turn, 0 shut to 1 sideways (open), and its speed for the spring.
var _turn := 0.0
var _turn_v := 0.0
var _held := false
var _by_hook := 0.0
var _was_down := false
var _fill := 0.0
var _jars_done := 0
## The jar in hand's slide in (0..1), the done jar's lid and slide (seconds, or negative).
var _in := 1.0
var _lid_age := -1.0
var _leaving_from := Vector2.ZERO
## The stream: head and tail below the spout, their speeds, whether it is joined to the gate.
var _head := 0.0
var _tail := 0.0
var _head_v := 0.0
var _tail_v := 0.0
var _coils: Array[Dictionary] = []
var _coil_clock := 0.0
var _stars: Array[Dictionary] = []
var _start_level := 1.0
var _finale := -1.0
var _glug: AudioStreamPlayer
var _glug_level := 0.0


func _ready() -> void:
	_glug = AudioStreamPlayer.new()
	_glug.name = &"Glug"
	_glug.bus = Prefs.BUS_SFX
	_glug.volume_db = Prefs.BUS_SILENT
	_glug.stream = HiveSounds.loop_stream(&"hive_pour")
	add_child(_glug)


func begin() -> void:
	super.begin()
	_roll.seed = 5301
	_turn = 0.0
	_turn_v = 0.0
	_held = false
	_by_hook = 0.0
	_fill = 0.0
	_jars_done = 0
	_in = 1.0
	_lid_age = -1.0
	_head = 0.0
	_tail = 0.0
	_head_v = 0.0
	_tail_v = 0.0
	_coils.clear()
	_stars.clear()
	_finale = -1.0
	_start_level = room.honey if room != null and room.honey > 0.05 else 1.0
	wanderers(AIR, AIR_BOX, 5307)


# --- the harness's hooks ------------------------------------------------------------------

## The lever held full open for `seconds`, filling the jar under the gate at once. Returns the
## jar's fill.
func pour(seconds: float) -> float:
	_settle_moves()
	_turn = 1.0
	_by_hook = 1.2
	_head = _drop()
	_tail = 0.0
	_fill = minf(_fill + RATE * seconds, CROWN_MOST)
	return _fill


## Let go: the lever springs shut and the jar is judged. True when it was done.
func release() -> bool:
	_by_hook = 0.0
	_held = false
	if _jars_done >= JARS:
		_finish_now()
		return true
	var done := _judge()
	_settle_moves()
	if _jars_done >= JARS:
		_finish_now()
	return done


func jars_done() -> int:
	return _jars_done


func fill() -> float:
	return _fill


func lever_open() -> float:
	return _turn


func settle() -> void:
	while _jars_done < JARS:
		pour(3.0)
		release()
	_finish_now()


# --- the play -----------------------------------------------------------------------------

func _gate_tl() -> Vector2:
	return TABLE_TOP + Vector2(0.0, 7.0) - HiveArt.anchor(&"gate", &"pivot") + Vector2(0.0, 3.0)


func _pivot() -> Vector2:
	return _gate_tl() + HiveArt.anchor(&"gate", &"pivot") + Vector2(0.0, 4.0)


func _spout() -> Vector2:
	return _gate_tl() + HiveArt.anchor(&"gate", &"spout")


## The lever's direction: straight up shut, turned a quarter to the right open.
func _lever_dir() -> Vector2:
	return Vector2.from_angle(-PI * 0.5 + _turn * PI * 0.5)


func _grip_at() -> Vector2:
	return _pivot() + _lever_dir() * (LEVER_LONG - GRIP_LONG * 0.5)


## How far the stream falls from the spout to the honey in the jar.
func _drop() -> float:
	return _surface_y() - _spout().y


func _judge() -> bool:
	if _fill < DONE_AT or _lid_age >= 0.0:
		return false
	_lid_age = 0.0
	_leaving_from = JAR_FEET
	HiveStep.sound(&"hive_pop")
	var top := JAR_FEET + Vector2(0.0, -JAR_H - 4.0)
	for k in 8:
		_stars.append({"at": top + Vector2(_roll.randf_range(-24.0, 24.0), _roll.randf_range(-16.0, 12.0)),
			"age": -_roll.randf_range(0.0, 0.2), "arm": 1 + _roll.randi() % 3})
	return true


## Everything still moving put where it is going: a done jar on the board, the next under the
## gate, the stream gone.
func _settle_moves() -> void:
	if _lid_age >= 0.0:
		_hand_off()
	_in = 1.0
	_head = 0.0
	_tail = 0.0


func _hand_off() -> void:
	_lid_age = -1.0
	_jars_done += 1
	_fill = 0.0
	_in = 0.0
	if _jars_done >= JARS:
		_finale = 0.0
		payoff(FINALE_AT, FINALE_WIDE)
		HiveStep.sound(&"hive_crown")


func _finish_now() -> void:
	_jars_done = JARS
	_lid_age = -1.0
	_finale = FINALE_WAIT
	done_once()


func _process(delta: float) -> void:
	var busy := _lid_age >= 0.0 or _in < 1.0 or _jars_done >= JARS
	var down := is_inside_tree() and awake() and tool_down() and not busy
	if is_inside_tree():
		pad_move(delta)
	if down and not _was_down:
		# A press takes the lever when it is on it; the pad's A takes it wherever the pointer is.
		_held = Pad.is_pad() or art_mouse().distance_to(_grip_at()) <= GRAB_REACH \
			or _near_bar(art_mouse())
	if not down:
		_held = false
	_was_down = down
	if _by_hook > 0.0:
		_by_hook -= delta
	var want := 1.0 if (_held or _by_hook > 0.0) else 0.0
	if want > 0.0:
		_turn = lerpf(_turn, want, 1.0 - exp(-OPEN_EASE * delta))
		_turn_v = 0.0
	else:
		_turn_v += (-SPRING_K * _turn - SPRING_DAMP * _turn_v) * delta
		_turn += _turn_v * delta
		if absf(_turn) < 0.002 and absf(_turn_v) < 0.02:
			_turn = 0.0
			_turn_v = 0.0
	var open := clampf(_turn, 0.0, 1.0)
	if not _held and _by_hook <= 0.0 and _was_released_open():
		_judge()
	# The stream: while open its head falls to the honey and the jar fills; shut, the tail
	# parts from the spout and falls in after.
	var drop := _drop()
	if open > 0.05 and not busy:
		_tail = 0.0
		_tail_v = 0.0
		_head_v += FALL * delta
		_head = minf(_head + _head_v * delta, drop)
		if _head >= drop - 0.5:
			var poured := RATE * open * open * delta
			_fill = minf(_fill + poured, CROWN_MOST)
			_coil_clock -= delta
			if _coil_clock <= 0.0:
				_coil_clock = COIL_EVERY
				_coils.append({"age": 0.0, "w": 6.0 + 8.0 * open + _roll.randf_range(-1.0, 1.0),
					"x": _roll.randf_range(-1.5, 1.5)})
	elif _head > 0.0:
		_tail_v += FALL * delta
		_tail += _tail_v * delta
		if _tail >= _head:
			_head = 0.0
			_tail = 0.0
			_head_v = 0.0
			_tail_v = 0.0
	if _lid_age >= 0.0:
		_lid_age += delta
		if _lid_age >= LID_TIME + SLIDE:
			_hand_off()
	if _in < 1.0:
		_in = minf(_in + delta / SLIDE_IN, 1.0)
	if _finale >= 0.0:
		_finale += delta
		if _finale >= FINALE_WAIT:
			done_once()
	var kept: Array[Dictionary] = []
	for c: Dictionary in _coils:
		c["age"] = float(c["age"]) + delta
		if float(c["age"]) < COIL_LIFE:
			kept.append(c)
	_coils = kept
	var stars: Array[Dictionary] = []
	for s: Dictionary in _stars:
		s["age"] = float(s["age"]) + delta
		if float(s["age"]) < STAR_LIFE:
			stars.append(s)
	_stars = stars
	_drive_glug(delta, open)


var _open_was := false


## Whether the lever has just been let go after pouring: the moment the jar is judged.
func _was_released_open() -> bool:
	var open_now := _turn > 0.3
	var let_go := _open_was and not open_now
	_open_was = open_now
	return let_go


func _near_bar(p: Vector2) -> bool:
	var a := _pivot()
	var b := _pivot() + _lever_dir() * LEVER_LONG
	var t := clampf((p - a).dot(b - a) / maxf((b - a).length_squared(), 0.001), 0.0, 1.0)
	return p.distance_to(a.lerp(b, t)) <= GRAB_REACH * 0.6


func _drive_glug(delta: float, open: float) -> void:
	if _glug == null or _glug.stream == null:
		return
	var want := open if _head > 0.0 and _tail <= 0.0 else 0.0
	_glug_level = move_toward(_glug_level, want, delta / GLUG_FADE)
	if _glug_level <= 0.0:
		if _glug.playing:
			_glug.stop()
		return
	if not _glug.playing:
		_glug.play()
	_glug.volume_db = lerpf(Prefs.BUS_SILENT, GLUG_DB, sqrt(_glug_level))
	_glug.pitch_scale = 0.9 + 0.3 * clampf(_fill, 0.0, 1.0)


# --- the jar ------------------------------------------------------------------------------

## The honey's surface in the jar under the gate, painted pixels (the builder's own rule).
func _surface_y() -> float:
	var top := JAR_FEET.y - JAR_FEET_AT.y + JAR_TOP
	return top + JAR_H - 2.0 - (JAR_H - 12.0) * _fill


## The glass's inside across row `y` of the jar's canvas: [left, right], or empty.
static func _span_of(y: int) -> Vector2i:
	var t := JAR_TOP
	if y < t + 4 or y > t + JAR_H:
		return Vector2i(0, -1)
	var left := 1.0
	if y < t + 9:
		left = 5.0 - (y - (t + 4)) * 4.0 / 5.0
	elif y > t + JAR_H - 3:
		left = 1.0 + (y - (t + JAR_H - 3))
	return Vector2i(int(ceilf(left)) + 1, JAR_W - int(ceilf(left)) - 1)


## A jar: glass behind, honey `f` full, glass in front, and the label and lid when `sealed`
## (the lid dropping `lid_up` pixels above its place).
func _draw_jar(feet: Vector2, f: float, sealed: bool, lid_up: float, lid_alpha: float) -> void:
	var tl := (feet - JAR_FEET_AT).floor()
	_ellipse(
		feet + Vector2(0.0, -1.0) + Shade.drop(null, CONTACT_RISE), Vector2(18.0, 3.0),
		Shade.tint_on(null, Shade.On.LAND)
	)
	HiveArt.draw(self, &"jar2_back", to_canvas(tl))
	if f > 0.0:
		var surface := int(JAR_TOP + JAR_H - 2 - (JAR_H - 12) * minf(f, 1.0))
		for y in range(JAR_TOP + 4, JAR_TOP + JAR_H + 1):
			var span := _span_of(y)
			if span.y < span.x:
				continue
			for x in range(span.x, span.y + 1):
				var climb := 2 if x in [2, JAR_W - 2] else (1 if x in [3, JAR_W - 3] else 0)
				if y < surface - climb:
					continue
				var ink := HiveArt.HONEY
				if y <= surface - climb + 1:
					ink = HiveArt.HONEY_SHINE if (x > 8 and x < JAR_W - 10) else HiveArt.HONEY_LIGHT
				else:
					var d := float(y - surface) / maxf(float(JAR_TOP + JAR_H - surface), 1.0)
					ink = HiveArt.HONEY_LIGHT if d < 0.12 else (HiveArt.HONEY if d < 0.55 else HiveArt.HONEY_MID)
					if x < 5:
						ink = HiveArt.HONEY_MID
					elif y >= JAR_TOP + JAR_H - 1:
						ink = HiveArt.HONEY_DEEP
				draw_rect(Rect2(to_canvas(tl + Vector2(x, y)), Vector2.ONE * HiveArt.PIXEL), ink)
	HiveArt.draw(self, &"jar2_front", to_canvas(tl))
	if f > 1.0:
		# Over the top: a crown of honey bulging over the neck and running down the glass.
		var over := (f - 1.0) / (CROWN_MOST - 1.0)
		var neck := tl + Vector2(JAR_W * 0.5 + 2.0, JAR_TOP + 1.0)
		_blob(neck, Vector2(8.0 + over * 4.0, 2.0 + over * 3.0))
		for k in 2:
			var run := tl + Vector2(6.0 + k * 22.0, JAR_TOP + 3.0)
			HiveArt.drip(self, to_canvas(run), 4.0 + over * 16.0 * (0.6 + k * 0.4))
	if sealed:
		HiveArt.draw(self, &"jar2_label", to_canvas(tl))
		if lid_alpha > 0.0:
			HiveArt.draw(self, &"jar2_lid", to_canvas(tl + Vector2(0.0, -roundf(lid_up))), &"", false, lid_alpha)


# --- drawing ------------------------------------------------------------------------------

func _draw() -> void:
	draw_wanderers()
	# The table, the bucket on it with its level, the gate and its lever.
	_ellipse(
		Vector2(320.0, 300.0) + Shade.drop(null, CONTACT_RISE), Vector2(75.0, 6.0),
		Shade.tint_on(null, Shade.On.LAND)
	)
	HiveArt.draw(self, &"table", to_canvas(TABLE_TOP), &"top")
	HiveArt.draw(self, &"bucket", to_canvas(TABLE_TOP + Vector2(0.0, 1.0)), &"feet")
	_draw_level()
	HiveArt.draw(self, &"gate", to_canvas(_gate_tl()))
	_draw_lever()
	# The board and the jars already done on it.
	_box(BOARD.position + Vector2(-6.0, 0.0), Vector2(BOARD.size.x, 6.0), WOOD_HI)
	_box(BOARD.position + Vector2(-6.0, 5.0), Vector2(BOARD.size.x, 3.0), WOOD_LO)
	var on_board := _jars_done + (1 if _lid_age >= LID_TIME + SLIDE else 0)
	for k in mini(on_board, JARS):
		_draw_jar(Vector2(SLOTS[k], BOARD.position.y), 0.88, true, 0.0, 1.0)
	# The empty waiting on the lawn, unless the last is already under the gate.
	if _jars_done + 1 < JARS:
		_draw_jar(WAIT_FEET, 0.0, false, 0.0, 0.0)
	# The stream behind the jar's glass, then the jar in hand.
	_draw_stream()
	if _jars_done < JARS:
		if _lid_age >= 0.0:
			var t := clampf(_lid_age / LID_TIME, 0.0, 1.0)
			var slide := clampf((_lid_age - LID_TIME) / SLIDE, 0.0, 1.0)
			var e := 1.0 - pow(1.0 - slide, 3.0)
			var to := Vector2(SLOTS[mini(_jars_done, JARS - 1)], BOARD.position.y)
			var at := JAR_FEET.lerp(to, e) + Vector2(0.0, -sin(e * PI) * HOP)
			_draw_jar(at, _fill, true, (1.0 - t * t) * LID_FROM, t)
		else:
			var e := 1.0 - pow(1.0 - _in, 3.0)
			var at := WAIT_FEET.lerp(JAR_FEET, e) + Vector2(0.0, -sin(e * PI) * HOP)
			_draw_jar(at, _fill, false, 0.0, 0.0)
			if _in >= 1.0:
				_draw_line()
	_draw_coils()
	for s: Dictionary in _stars:
		var t := float(s["age"])
		if t < 0.0:
			continue
		var bright := sin(clampf(t / STAR_LIFE, 0.0, 1.0) * PI)
		HiveArt.star(self, to_canvas(s["at"]), int(roundf(float(s["arm"]) * bright)), bright)
	draw_payoff()


## The bucket's honey: its surface sinking inside the bucket as the jars fill, clipped to the
## mouth, the whole mouth while it is full and a crescent at its foot near the end (the uncap
## step's own picture of a level). It used to sit at the brim and move three pixels.
func _draw_level() -> void:
	var used := (float(_jars_done) + clampf(_fill, 0.0, 1.0)) / float(JARS)
	var level := clampf(_start_level * (1.0 - used), 0.0, 1.0)
	if level <= 0.002:
		return
	var mouth := TABLE_TOP + Vector2(0.0, 1.0) - HiveArt.anchor(&"bucket", &"feet") + HiveArt.anchor(&"bucket", &"mouth")
	var half := HiveArt.anchor(&"bucket", &"half") if HiveArt.knows(&"bucket") else Vector2(48.0, 6.0)
	half -= Vector2(1.0, 0.0)
	var surface := mouth + Vector2(0.0, (1.0 - level) * POOL_DEEP)
	for y in range(floori(mouth.y - half.y), ceili(mouth.y + half.y) + 1):
		var a := _row_of(mouth, half, y)
		var b := _row_of(surface, half, y)
		var l := maxf(a.x, b.x)
		var r := minf(a.y, b.y)
		if r <= l:
			continue
		var dy := float(y) + 0.5 - surface.y
		var ink := HiveArt.HONEY
		if dy < -half.y * 0.55:
			ink = HiveArt.HONEY_LIGHT
		elif dy > half.y * 0.45:
			ink = HiveArt.HONEY_MID
		_box(Vector2(l, y), Vector2(r - l, 1.0), ink)
		_box(Vector2(l, y), Vector2.ONE, HiveArt.HONEY_DEEP)
		_box(Vector2(r - 1.0, y), Vector2.ONE, HiveArt.HONEY_DEEP)
	# The draw-off: a dimple in the surface over the gate while it pours.
	if _turn > 0.1:
		var dimple := Vector2(surface.x, surface.y + 1.0)
		var d := _row_of(dimple, Vector2(6.0 * _turn, 1.5), int(dimple.y))
		var m := _row_of(mouth, half, int(dimple.y))
		var l := maxf(d.x, m.x)
		var r := minf(d.y, m.y)
		if r > l:
			_box(Vector2(l, floorf(dimple.y)), Vector2(r - l, 1.0), HiveArt.HONEY_MID)


## Where an ellipse's row `y` runs, as (left, right); empty (right <= left) off it.
static func _row_of(middle: Vector2, half: Vector2, y: int) -> Vector2:
	var dy := (float(y) + 0.5 - middle.y) / half.y
	if absf(dy) >= 1.0:
		return Vector2.ZERO
	var w := half.x * sqrt(1.0 - dy * dy)
	return Vector2(roundf(middle.x - w), roundf(middle.x + w))


## The lever: a brass bar off the gate's pivot, a wooden grip at its end, turned `_turn` of a
## quarter from upright.
func _draw_lever() -> void:
	var p := _pivot()
	var dir := _lever_dir()
	var side := dir.orthogonal()
	# Laid a painted pixel at a time along its length, three wide, inked round.
	for pass_k in 2:
		for s in range(0, int(LEVER_LONG * 2.0) + 1):
			var along := s * 0.5
			var grip := along > LEVER_LONG - GRIP_LONG
			var half := 2.5 if grip else 1.5
			for w in range(-3, 4):
				var off := w * 0.5
				if absf(off) > half + 0.5:
					continue
				var at := p + dir * along + side * off
				if pass_k == 0:
					# The ink: every pixel the bar covers, pushed a pixel out to its side.
					_box((at + side * signf(off + 0.01)).floor(), Vector2.ONE, HiveArt.OUT)
					continue
				if absf(off) > half:
					continue
				var ink: Color
				if grip:
					ink = WOOD_HI if off < -0.8 else (WOOD if off < 0.8 else WOOD_LO)
				else:
					ink = BRASS_LIT if off < -0.4 else (BRASS if off < 0.6 else BRASS_SHADE)
				_box(at.floor(), Vector2.ONE, ink)
	# The pivot's boss.
	_ellipse(p, Vector2(3.5, 3.5), HiveArt.OUT)
	_ellipse(p, Vector2(2.5, 2.5), BRASS_SHADE)
	_box(p + Vector2(-1.0, -1.0), Vector2(2.0, 1.0), BRASS_LIT)


## The stream: thick off the spout and narrowing, a lit streak down it, wobbling as it falls;
## shut, what is left falls as a thinning thread.
func _draw_stream() -> void:
	if _head <= 0.5:
		return
	var spout := _spout()
	var open := clampf(_turn, 0.0, 1.0)
	var wide := lerpf(WIDE_LEAST, WIDE_MOST, open)
	if _tail > 0.0:
		wide = minf(wide, 3.0)
	var from := int(_tail)
	var to := int(_head)
	for y in range(from, to):
		var t := float(y) / maxf(_drop(), 1.0)
		var w := maxf(wide * (1.0 - 0.45 * pow(t, 0.6)), 2.0)
		if _tail > 0.0:
			w = maxf(2.0, w * (1.0 - float(y - from) / maxf(float(to - from), 1.0) * 0.5))
		var wob := roundf(sin(y * 0.2 + age * 6.0) * WOBBLE * t)
		_rope_row(spout.x + wob, spout.y + y, w)


func _rope_row(cx: float, y: float, w: float) -> void:
	var l := roundf(cx - w * 0.5)
	var r := roundf(cx + w * 0.5) - 1.0
	var span := r - l
	if span < 1.0:
		_box(Vector2(l, y), Vector2(2.0, 1.0), HiveArt.HONEY_MID)
		return
	_box(Vector2(l, y), Vector2(span + 1.0, 1.0), HiveArt.HONEY)
	_box(Vector2(l, y), Vector2(maxf(ceilf(span * 0.25), 1.0), 1.0), HiveArt.HONEY_MID)
	_box(Vector2(l + ceilf(span * 0.3), y), Vector2(maxf(ceilf(span * 0.2), 1.0), 1.0), HiveArt.HONEY_SHINE)
	_box(Vector2(l + ceilf(span * 0.5), y), Vector2(maxf(ceilf(span * 0.2), 1.0), 1.0), HiveArt.HONEY_LIGHT)
	_box(Vector2(l, y), Vector2.ONE, HiveArt.HONEY_DEEP)
	_box(Vector2(r, y), Vector2.ONE, HiveArt.HONEY_DEEP)


## Where the stream meets the honey in the jar, in the honey itself (2026-10-04, Richard:
## "should feel more integrated and seamless"; it was rings floating over the surface): a low
## mound in the surface's own light where the stream lands, each fold of the rope a pair of
## humps sliding out along the surface and settling into it, and what it folded under sinking
## as a darker swirl. Everything held inside the glass.
func _draw_coils() -> void:
	if _in < 1.0 or _lid_age >= 0.0 or _fill <= 0.0:
		return
	var tl := (JAR_FEET - JAR_FEET_AT).floor()
	var y := floorf(_surface_y())
	var x := _spout().x
	var row := _span_of(int(y - tl.y))
	if row.y < row.x:
		return
	var left := tl.x + row.x
	var right := tl.x + row.y
	if _head > 0.5 and _tail <= 0.0:
		var half := lerpf(WIDE_LEAST, WIDE_MOST, clampf(_turn, 0.0, 1.0)) * 0.8 + 1.0
		for px in range(int(x - half), int(x + half) + 1):
			if px < left or px > right:
				continue
			var u := absf(px - x) / half
			var lift := int(roundf((1.0 - u * u) * MOUND_TALL))
			for h in lift:
				_box(Vector2(px, y - 1.0 - h), Vector2.ONE, HiveArt.HONEY_SHINE if h == lift - 1 else HiveArt.HONEY_LIGHT)
	for c: Dictionary in _coils:
		var k := clampf(float(c["age"]) / COIL_LIFE, 0.0, 1.0)
		var spread := float(c["w"]) * (0.3 + 0.7 * k)
		var tall := int(roundf((1.0 - k) * FOLD_TALL))
		for side: float in [-1.0, 1.0]:
			var hx := floorf(x + float(c["x"]) + side * spread * 0.5)
			if hx < left or hx > right - 1.0:
				continue
			for h in tall:
				_box(Vector2(hx, y - 1.0 - h), Vector2(2.0, 1.0), HiveArt.HONEY_SHINE if h == tall - 1 else HiveArt.HONEY_LIGHT)
		var sink := Vector2(floorf(x + float(c["x"]) + sin(k * 5.0 + float(c["w"])) * 2.0), floorf(y + 2.0 + k * SINK_DEEP))
		var under := _span_of(int(sink.y - tl.y))
		if under.y >= under.x and sink.x >= tl.x + under.x and sink.x + 1.0 <= tl.x + under.y:
			_box(sink, Vector2(2.0, 1.0), _ink(HiveArt.HONEY_MID, 0.8 * (1.0 - k)))


## The gold dashed line at `LINE_AT` of the jar, glowing as the honey nears it.
func _draw_line() -> void:
	var top := JAR_FEET.y - JAR_FEET_AT.y + JAR_TOP
	var y := floorf(top + JAR_H - 2.0 - (JAR_H - 12.0) * LINE_AT)
	var near := clampf(1.0 - absf(_fill - LINE_AT) / 0.25, 0.0, 1.0)
	if near > 0.0:
		_box(Vector2(JAR_FEET.x - 25.0, y - 2.0), Vector2(50.0, 5.0), _ink(HiveArt.GOLD, 0.25 * near))
	var x := JAR_FEET.x - 25.0
	while x < JAR_FEET.x + 25.0:
		_box(Vector2(x, y), Vector2(2.0, 1.0), HiveArt.GOLD)
		x += 4.0


func _blob(middle: Vector2, half: Vector2) -> void:
	_ellipse(middle, half + Vector2.ONE, HiveArt.HONEY_DEEP)
	_ellipse(middle, half, HiveArt.HONEY)
	_ellipse(middle + Vector2(-half.x * 0.3, -half.y * 0.3), half * 0.45, HiveArt.HONEY_LIGHT)


func _ellipse(middle: Vector2, half: Vector2, ink: Color) -> void:
	if half.x <= 0.0 or half.y <= 0.0:
		return
	var top := floori(middle.y - half.y)
	for y in range(top, ceili(middle.y + half.y) + 1):
		var dy := (y + 0.5 - middle.y) / half.y
		if absf(dy) >= 1.0:
			continue
		var w := half.x * sqrt(1.0 - dy * dy)
		var from := roundf(middle.x - w)
		_box(Vector2(from, y), Vector2(maxf(roundf(middle.x + w) - from, 1.0), 1.0), ink)


func _box(p: Vector2, s: Vector2, color: Color) -> void:
	if color.a <= 0.0 or s.x <= 0.0 or s.y <= 0.0:
		return
	draw_rect(Rect2(to_canvas(p.floor()), s * HiveArt.PIXEL), color)


static func _ink(c: Color, alpha: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * clampf(alpha, 0.0, 1.0))
