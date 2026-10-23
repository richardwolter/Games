## The pour: the harvest's last step, honey out of the bucket into three jars (2026-09-30, the
## beehive; the second pass, Richard, off `tools/hive_mockup2.py` `room_pour`).
##
## The uncapping's own oak bucket stands on the bottling stand, **its level where the uncapping
## left it** (`HiveRoom.honey`), with a brass tap low on its front over an empty jar. **The
## tap's lever is the control**: a brass bar with an oak grip on the tap's pivot, standing up
## shut. **Hold on it** (the left button on the lever, or on the pad A or RT) and it turns
## sideways, the tap opens and honey runs — thicker the further it has turned — and **let go
## and it springs shut** with a little overshoot. No arrow, no wheel.
##
## The stream is gooey: its head falls from the spout under gravity, it narrows as it falls and
## wobbles, and where it lands it flares into the honey in the jar, heaps a mound and folds into
## the surface; shut, its tail parts from the spout as a thread and falls in after. **Fill it to
## the dashed line and let go**: at or over `DONE_AT` the jar is done — its gingham lid drops on
## with a pop and stars, it hops along to the fence shelf, and the next empty slides in under
## the tap. Over the top it crowns and runs down the glass; **no penalty**. Three jars finish the
## step, the bucket drawn down as they fill, its honey sinking inside it and leaving a tide mark.
##
## **The look is the pour sheet's option B** (2026-10-18, the hive's visual overhaul,
## `tools/hive_look/last_pour.png`): the stand built as a hive (a coral cover over two sky-blue
## supers, the jars on its landing board), the finished jars to a blue plank on a stake fence,
## and a prize rosette with the crown on its boss pinned on the middle jar at the end; **with
## the uncap's oak bucket**, so one bucket runs through both steps. The wood, the tap, the
## lever's turns and the rosette are `HiveKitchenArt`'s; **the jars are `HoneyPot`'s room jar**,
## the one pot the game draws everywhere, its honey level baked (`room_back<k>`) and only the
## crown over the brim, the stream and its folds drawn here, inside the glass's own spans.
##
## **Harness hooks, never gated on `awake`**: `pour(seconds)` (the lever held open that long),
## `release()`, `jars_done()`, `fill()`, `lever_open()` and `settle()`. The glug is the step's
## own player, `Glug`, on SFX.
class_name HiveStepPour
extends HiveStep

const JARS := 3
## A few loose bees in the air behind the stand (`HiveStep.wanderers`), after the honey.
const AIR := 6
const AIR_BOX := Rect2(20.0, 20.0, 600.0, 150.0)
## A full-open tap fills this share of a jar a second.
const RATE := 0.42
## Let go at or over this and the jar is done; the line is HoneyPot's (`line_fill`, 0.86);
## honey crowns past 1 and stops rising at `CROWN_MOST`.
const DONE_AT := 0.7
const CROWN_MOST := 1.14

## Where things stand, painted pixels, the builder's layout (`assets/hive_kitchen.json`
## `pour`); these are its numbers, for a run before the json.
const BUCKET_FOOT := Vector2(246.0, 219.0)
const GATE_TOP := Vector2(259.0, 206.0)
const JAR_FEET := Vector2(259.0, 283.0)
const WAIT_FEET := Vector2(225.0, 283.0)
const SLOTS: Array[Vector2] = [Vector2(346.0, 265.0), Vector2(384.0, 265.0), Vector2(422.0, 265.0)]
## The room jar's canvas: its feet anchor, the rows the honey fills (top, bottom) and the neck.
const POT_FEET := Vector2(13.0, 41.0)
const POT_ROWS := Vector2i(13, 39)
const POT_NECK := 9

## The lever: its bar and grip (the builder's `pour_art.LEVER_*`), how fast it turns under the
## hand, and the spring that shuts it (stiffness, damping) with its overshoot.
const LEVER_LONG := 22.0
const LEVER_ARM := 14.0
const OPEN_EASE := 7.0
const SPRING_K := 260.0
const SPRING_DAMP := 14.0
## A press within this of the lever's grip (or its bar) takes it.
const GRAB_REACH := 14.0
## The shut lever asks to be held: its cue frame (a glint, wobble ticks) shows this share of
## every `CUE_EVERY` seconds while nothing has been poured.
const CUE_EVERY := 1.1
const CUE_SHARE := 0.55

## The stream: its widest at the spout (full open) and narrowest, its fall, and how its
## wobble grows as it falls.
const WIDE_MOST := 6.0
const WIDE_LEAST := 3.0
const FALL := 520.0
const WOBBLE := 1.0
## Where it lands it flares into the honey over its last `FLARE` rows, `FLARE_WIDE` px wider.
const FLARE := 3.0
const FLARE_WIDE := 4.0
## The folds where it lands: one every this while it pours, living this long.
const COIL_EVERY := 0.09
const COIL_LIFE := 0.7
## The mound where the stream lands and each fold's humps, painted px tall, and how far a
## fold's swirl sinks under the surface over its life.
const MOUND_TALL := 2.0
const FOLD_TALL := 2.0
const SINK_DEEP := 6.0

## A done jar: the lid falls on over `LID_TIME` from `LID_FROM` up, then it hops to the shelf
## over `SLIDE`; the next slides in over `SLIDE_IN`.
const LID_TIME := 0.2
const LID_FROM := 14.0
const SLIDE := 0.5
const SLIDE_IN := 0.45
const HOP := 8.0
const FINALE_WAIT := 1.2  # A third off (2026-10-23, Richard's QA run: the endings were slow); was 1.8.
## The shared ending over the three jars on the shelf (`HiveStep.payoff`, no crown in the air:
## the crown is on the rosette), and the rosette dropping onto the middle jar with a bounce.
const FINALE_WIDE := 100.0
const ROSETTE_DROP := 0.5
const ROSETTE_FALL := 40.0
## The rosette's boss stands this far under the jar's top (the mockup's own place).
const ROSETTE_DOWN := 19.0
const STAR_LIFE := 0.7
const GLUG_DB := -14.0
const GLUG_FADE := 0.08
## The contact shadows under the stand, the bench and the bucket, in the one ink every shadow
## on land takes (`Shade.tint_on`), nudged along the sun from `CONTACT_RISE` painted px up.
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
var _poured_any := false
## The jar in hand's slide in (0..1), the done jar's lid and slide (seconds, or negative).
var _in := 1.0
var _lid_age := -1.0
## The stream: head and tail below the spout, their speeds.
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

## The layout, read once from the json (`_lay`).
var _laid := false
var _bucket_foot := BUCKET_FOOT
var _gate_top := GATE_TOP
var _jar_feet := JAR_FEET
var _wait_feet := WAIT_FEET
var _slots: Array[Vector2] = SLOTS.duplicate()
var _mouth := BUCKET_FOOT + Vector2(0.0, -53.0)
var _bucket_inner := Vector2(26.0, 6.8)
var _foot_half := Vector2(28.0, 7.0)
var _taper := 2.0
var _levels := 24
var _line_fill := 0.86
var _spans := {}


func _ready() -> void:
	_glug = AudioStreamPlayer.new()
	_glug.name = &"Glug"
	_glug.bus = Prefs.BUS_SFX
	_glug.volume_db = Prefs.BUS_SILENT
	_glug.stream = HiveSounds.loop_stream(&"hive_pour")
	add_child(_glug)
	_lay()


func begin() -> void:
	super.begin()
	_lay()
	_roll.seed = 5301
	_turn = 0.0
	_turn_v = 0.0
	_held = false
	_by_hook = 0.0
	_fill = 0.0
	_jars_done = 0
	_poured_any = false
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


func _lay() -> void:
	if _laid:
		return
	_laid = true
	var d := HiveKitchenArt.data(&"pour")
	if not d.is_empty():
		_bucket_foot = HiveKitchenArt.vec(d.get("bucket_foot", [BUCKET_FOOT.x, BUCKET_FOOT.y]))
		_gate_top = HiveKitchenArt.vec(d.get("gate_top", [GATE_TOP.x, GATE_TOP.y]))
		_jar_feet = HiveKitchenArt.vec(d.get("jar_feet", [JAR_FEET.x, JAR_FEET.y]))
		_wait_feet = HiveKitchenArt.vec(d.get("wait_feet", [WAIT_FEET.x, WAIT_FEET.y]))
		var slots: Variant = d.get("slots", [])
		if slots is Array and (slots as Array).size() >= JARS:
			_slots.clear()
			for s: Variant in slots:
				_slots.append(HiveKitchenArt.vec(s))
	var b := HiveKitchenArt.data(&"bucket")
	_mouth = _bucket_foot + HiveKitchenArt.vec(b.get("foot_to_mouth", [0, -53]))
	_bucket_inner = HiveKitchenArt.vec(b.get("inner", [26.0, 6.8]))
	_foot_half = HiveKitchenArt.vec(b.get("foot_half", [28.0, 7.0]))
	_taper = float(b.get("taper", 2.0))
	_levels = maxi(int(b.get("levels", 24)), 1)
	var g := HoneyPot.geometry(&"room")
	_line_fill = float(g.get("line_fill", 0.86))
	var spans: Variant = g.get("spans", {})
	_spans = spans if spans is Dictionary else {}


# --- the harness's hooks ------------------------------------------------------------------

## The lever held full open for `seconds`, filling the jar under the tap at once. Returns the
## jar's fill.
func pour(seconds: float) -> float:
	_settle_moves()
	_turn = 1.0
	_by_hook = 1.2
	_head = _drop()
	_tail = 0.0
	_fill = minf(_fill + RATE * seconds, CROWN_MOST)
	_poured_any = true
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

## The tap's top left, painted px: its `top` anchor on the bucket's front.
func _gate_tl() -> Vector2:
	return _gate_top - HiveKitchenArt.anchor(&"gate", &"top")


func _pivot() -> Vector2:
	return _gate_tl() + HiveKitchenArt.anchor(&"gate", &"pivot")


func _spout() -> Vector2:
	return _gate_tl() + HiveKitchenArt.anchor(&"gate", &"spout")


## The lever's direction: straight up shut, turned a quarter to the right open.
func _lever_dir() -> Vector2:
	return Vector2.from_angle(-PI * 0.5 + _turn * PI * 0.5)


func _grip_at() -> Vector2:
	return _pivot() + _lever_dir() * (LEVER_ARM + (LEVER_LONG - LEVER_ARM) * 0.5)


## How far the stream falls from the spout to the honey in the jar.
func _drop() -> float:
	return _surface_y() - _spout().y


func _judge() -> bool:
	if _fill < DONE_AT or _lid_age >= 0.0:
		return false
	_lid_age = 0.0
	HiveStep.sound(&"hive_pop")
	var top := _jar_feet + Vector2(0.0, -POT_FEET.y - 4.0)
	for k in 8:
		_stars.append({"at": top + Vector2(_roll.randf_range(-20.0, 20.0), _roll.randf_range(-14.0, 12.0)),
			"age": -_roll.randf_range(0.0, 0.2), "arm": 1 + _roll.randi() % 3})
	return true


## Everything still moving put where it is going: a done jar on the shelf, the next under the
## tap, the stream gone.
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
		var mid := _slots[1]
		payoff(mid + Vector2(0.0, -POT_FEET.y * 0.5), FINALE_WIDE, false)
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
			_poured_any = true
			_coil_clock -= delta
			if _coil_clock <= 0.0:
				_coil_clock = COIL_EVERY
				_coils.append({"age": 0.0, "w": 5.0 + 5.0 * open + _roll.randf_range(-1.0, 1.0),
					"x": _roll.randf_range(-1.0, 1.0)})
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

## The honey's top row in the room jar's canvas for a fill (HoneyPot's own rounding): up to the
## neck's foot, and over 1 it holds there while the crown heaps above.
static func _surface_row(f: float) -> int:
	return roundi(float(POT_ROWS.y) - float(POT_ROWS.y - POT_ROWS.x) * clampf(f, 0.0, 1.0))


## The honey's surface in the jar under the tap, painted pixels: over the brim, the crown's top.
func _surface_y() -> float:
	if _fill > 1.0:
		return _jar_feet.y - POT_FEET.y + float(POT_NECK) - _crown_tall(_fill)
	return _jar_feet.y - POT_FEET.y + float(_surface_row(_fill))


## How many rows the crown stands over the neck for a fill over 1.
static func _crown_tall(f: float) -> float:
	if f <= 1.0:
		return 0.0
	return 1.0 + roundf(clampf((f - 1.0) / (CROWN_MOST - 1.0), 0.0, 1.0) * 3.0)


## The glass's inside across row `y` of the jar's canvas: (left, right), or empty.
func _span_of(y: int) -> Vector2i:
	var s: Variant = _spans.get(str(y), [])
	if s is Array and (s as Array).size() >= 2:
		return Vector2i(int(s[0]), int(s[1]))
	if y < POT_NECK:
		return _span_of(POT_NECK) + Vector2i(-1, 1)
	if y <= 40:
		return Vector2i(1, 24)
	return Vector2i(0, -1)


## The room jar at `feet` (painted px): its glass behind with the honey at `f`, then `between`
## (the stream and its folds, inside the glass), then the mouth or the label and lid, the glass
## in front and the fill line. Over the brim, the crown is drawn on top.
func _draw_jar(feet: Vector2, f: float, sealed: bool, lid_up: float, lid_alpha: float,
		line := false, between := Callable()) -> void:
	var at := to_canvas(feet.floor())
	HoneyPot.draw(self, StringName("room_back%d" % HoneyPot.room_level(f)), at, HiveArt.PIXEL)
	if between.is_valid():
		between.call()
	if not sealed:
		HoneyPot.draw(self, &"room_mouth", at, HiveArt.PIXEL)
	HoneyPot.draw(self, &"room_front", at, HiveArt.PIXEL)
	if line:
		HoneyPot.draw(self, &"room_line", at, HiveArt.PIXEL)
	if f > 1.0:
		_fill_neck(feet.floor())
		_draw_crown(feet.floor(), f)
	if sealed:
		HoneyPot.draw(self, &"room_label", at, HiveArt.PIXEL)
		if lid_alpha > 0.0:
			HoneyPot.draw(self, &"room_lid", at - Vector2(0.0, roundf(lid_up) * HiveArt.PIXEL),
				HiveArt.PIXEL, Color(1.0, 1.0, 1.0, lid_alpha))


## Over the brim the honey fills the neck and shoulder too, inside the glass's own spans, in
## the honey's ramp (lit at the left, a step darker at the right), so the crown sits on honey.
## Drawn over the glass's front: its shoulder bands are part see-through and greyed the honey.
func _fill_neck(feet: Vector2) -> void:
	var tl := feet - POT_FEET
	for y in range(POT_NECK, POT_ROWS.x + 1):
		var span := _span_of(y)
		for x in range(span.x + 1, span.y):
			var u := float(x - span.x) / maxf(float(span.y - span.x), 1.0)
			var ink := HiveArt.HONEY_LIGHT if u < 0.2 else (HiveArt.HONEY if u < 0.8 else HiveArt.HONEY_MID)
			_box(tl + Vector2(x, y), Vector2.ONE, ink)


## Over the top: the honey heaps over the neck as a dome on the glass's own neck span and runs
## down the outside of the glass, both in the honey's ramp, the dome's middle lit.
func _draw_crown(feet: Vector2, f: float) -> void:
	var over := clampf((f - 1.0) / (CROWN_MOST - 1.0), 0.0, 1.0)
	var tl := feet - POT_FEET
	var neck := _span_of(POT_NECK)
	var mid := (float(neck.x) + float(neck.y)) * 0.5
	var half := (float(neck.y - neck.x) + 1.0) * 0.5 + over * 1.5
	var tall := _crown_tall(f)
	for k in int(tall) + 1:
		var y := float(POT_NECK) - float(k)
		var u := float(k) / (tall + 0.5)
		var w := half * sqrt(maxf(1.0 - u * u, 0.0))
		var l := roundf(mid - w)
		var r := roundf(mid + w)
		for x in range(int(l), int(r) + 1):
			var ink := HiveArt.HONEY
			if x == int(l) or x == int(r):
				ink = HiveArt.HONEY_MID
			elif k == int(tall):
				ink = HiveArt.HONEY_LIGHT
			elif x < mid - 1.0 and x > l + 1.0:
				ink = HiveArt.HONEY_SHINE if k >= 1 else HiveArt.HONEY_LIGHT
			_box(tl + Vector2(x, y), Vector2.ONE, ink)
	# The runs down the outside: off the dome's ends, over the shoulder, down the glass.
	for side: int in [0, 1]:
		var row := _span_of(POT_NECK + 4)
		var x := float(row.x - 1) if side == 0 else float(row.y + 1)
		var long := 3.0 + over * (10.0 + 6.0 * side)
		HiveArt.drip(self, to_canvas(tl + Vector2(x, float(POT_NECK) + 2.0)), long)


# --- drawing ------------------------------------------------------------------------------

func _draw() -> void:
	var ink := Shade.tint_on(null, Shade.On.LAND)
	_draw_shades(ink)
	draw_wanderers()
	# The fence shelf, behind everything at the bottling stand.
	HiveKitchenArt.draw(self, &"bench", to_canvas(HiveKitchenArt.at(&"bench")))
	# The stand, the bucket on it with its level, the tap and its lever.
	HiveKitchenArt.draw(self, &"stand", to_canvas(HiveKitchenArt.at(&"stand")))
	HiveKitchenArt.draw(self, &"bucket_rope", to_canvas(_bucket_foot), &"foot")
	HiveKitchenArt.draw(self, &"bucket_open", to_canvas(_bucket_foot), &"foot")
	_draw_level()
	HiveKitchenArt.draw(self, &"gate", to_canvas(_gate_tl()))
	_draw_lever()
	# The jars already done on the shelf (gold-rimmed while the payoff plays).
	var on_board := _jars_done + (1 if _lid_age >= LID_TIME + SLIDE else 0)
	for k in mini(on_board, JARS):
		if _finale >= 0.0:
			HoneyPot.draw(self, &"room_payoff", to_canvas(_slots[k]), HiveArt.PIXEL)
		else:
			_draw_jar(_slots[k], _line_fill, true, 0.0, 1.0)
	# The empty waiting on the landing board, unless the last is already under the tap.
	if _jars_done + 1 < JARS:
		_draw_jar(_wait_feet, 0.0, false, 0.0, 0.0)
	# The jar in hand, the stream running inside its glass.
	if _jars_done < JARS:
		if _lid_age >= 0.0:
			var t := clampf(_lid_age / LID_TIME, 0.0, 1.0)
			var slide := clampf((_lid_age - LID_TIME) / SLIDE, 0.0, 1.0)
			var e := 1.0 - pow(1.0 - slide, 3.0)
			var to := _slots[mini(_jars_done, JARS - 1)]
			var at := _jar_feet.lerp(to, e) + Vector2(0.0, -sin(e * PI) * HOP)
			_draw_jar(at, _fill, true, (1.0 - t * t) * LID_FROM, t)
		else:
			var e := 1.0 - pow(1.0 - _in, 3.0)
			var at := _wait_feet.lerp(_jar_feet, e) + Vector2(0.0, -sin(e * PI) * HOP * 0.5)
			_draw_jar(at, _fill, false, 0.0, 0.0, _in >= 1.0, _draw_in_jar if _in >= 1.0 else Callable())
	# The stream above the jar's neck, over its glass, so it is one rope from the spout down.
	_draw_stream(false)
	if _turn < 0.05 and _head <= 0.5 and (_poured_any or _jars_done > 0):
		HiveKitchenArt.draw(self, &"bead", to_canvas(_spout() + Vector2(0.0, 1.0)), &"top")
	_draw_rosette()
	_draw_bees()
	for s: Dictionary in _stars:
		var t := float(s["age"])
		if t < 0.0:
			continue
		var bright := sin(clampf(t / STAR_LIFE, 0.0, 1.0) * PI)
		HiveArt.star(self, to_canvas(s["at"]), int(roundf(float(s["arm"]) * bright)), bright)
	draw_payoff()


func _draw_shades(ink: Color) -> void:
	var nudge := Shade.drop(null, CONTACT_RISE)
	var sb: Array = HiveKitchenArt.data(&"pour").get("stand_box", [198, 217, 306, 296])
	var bb: Array = HiveKitchenArt.data(&"pour").get("bench_box", [326, 216, 442, 294])
	_ellipse(Vector2((float(sb[0]) + float(sb[2])) * 0.5, float(sb[3]) - 1.0) + nudge,
		Vector2((float(sb[2]) - float(sb[0])) * 0.5 + 6.0, 4.0), ink)
	_ellipse(Vector2((float(bb[0]) + float(bb[2])) * 0.5, float(bb[3]) - 1.0) + nudge,
		Vector2((float(bb[2]) - float(bb[0])) * 0.5 + 4.0, 3.0), ink)


## What the jar under the tap holds besides its baked honey: the stream inside the glass and
## where it lands, a step dimmer behind the glass.
func _draw_in_jar() -> void:
	_draw_stream(true)
	_draw_coils()


## The lever off the tap's pivot: the baked turn nearest its own, and while nothing has been
## poured the shut lever now and then wears its cue (a glint on the knob, wobble ticks).
func _draw_lever() -> void:
	var turns := HiveKitchenArt.lever_turns()
	var best := 0
	var gap := INF
	for k in turns.size():
		var g := absf(float(turns[k]) - _turn)
		if g < gap:
			gap = g
			best = k
	var name := StringName("lever%d" % best)
	var shut := absf(_turn) < 0.03 and not _held
	if shut and not _poured_any and _jars_done == 0 and awake() \
			and fposmod(age, CUE_EVERY) < CUE_EVERY * CUE_SHARE:
		name = &"lever_cue"
	HiveKitchenArt.draw(self, name, to_canvas(_pivot()), &"pivot")


## The bucket's honey: the baked level nearest the honey left, sinking inside it as the jars
## fill, over the film it left where it stood when the step began; scraped out once poured.
func _draw_level() -> void:
	var used := (float(_jars_done) + clampf(_fill, 0.0, 1.0)) / float(JARS)
	var level := clampf(_start_level * (1.0 - used), 0.0, 1.0)
	var step := roundi(level * _levels)
	var start := clampi(roundi(_start_level * _levels), 1, _levels)
	var at := to_canvas(_bucket_foot)
	if step < start:
		HiveKitchenArt.draw(self, StringName("tide%d" % start), at, &"foot")
	if step <= 0:
		HiveKitchenArt.draw(self, &"pool_scraped", at, &"foot")
		return
	HiveKitchenArt.draw(self, StringName("pool%d" % step), at, &"foot")
	# The draw-off: a dimple in the surface over the tap while it pours.
	if _turn > 0.1:
		var s := _surface(step)
		var y := floorf(s.position.y + 1.0)
		var w := 3.0 + 3.0 * clampf(_turn, 0.0, 1.0)
		for x in range(int(s.position.x + 4.0 - w), int(s.position.x + 4.0 + w) + 1):
			if _on_pool(x, y, step):
				_box(Vector2(x, y), Vector2.ONE, HiveArt.HONEY_MID)


## The honey's surface for a ladder step (the builder's `pour_art._honey_geometry`).
func _surface(step: int) -> Rect2:
	var level := float(step) / float(_levels)
	var ix := _bucket_inner.x
	var iy := _bucket_inner.y
	var sx := (ix - 0.5) * (0.94 - 0.26 * (1.0 - level)) - _taper * (1.0 - level)
	var sy := iy * sx / ix
	var sx0 := (ix - 0.5) * 0.68 - _taper
	var sy0 := iy * sx0 / ix
	var cy := _mouth.y - 1.0 + pow(1.0 - level, 1.5) * (iy + sy0 + 1.0)
	return Rect2(Vector2(_mouth.x, cy), Vector2(sx, sy))


static func _in_ell(x: float, y: float, middle: Vector2, half: Vector2) -> bool:
	if half.x <= 0.0 or half.y <= 0.0:
		return false
	var dx := (x + 0.5 - middle.x) / half.x
	var dy := (y + 0.5 - middle.y) / half.y
	return dx * dx + dy * dy < 1.0


func _on_pool(x: float, y: float, step: int) -> bool:
	var s := _surface(step)
	return _in_ell(x, y, _mouth, _bucket_inner) and _in_ell(x, y + 1.0, _mouth, _bucket_inner) \
		and _in_ell(x, y, s.position, s.size)


## The stream: thick off the spout and narrowing, a lit streak down it, wobbling as it falls;
## shut, what is left falls as a thinning thread. Drawn in two passes, the rows over the jar's
## neck (`inside` false) and the rows inside the glass a step dimmer (`inside` true), where its
## last rows flare into the honey.
func _draw_stream(inside: bool) -> void:
	if _head <= 0.5:
		return
	var spout := _spout()
	var open := clampf(_turn, 0.0, 1.0)
	var wide := lerpf(WIDE_LEAST, WIDE_MOST, open)
	if _tail > 0.0:
		wide = minf(wide, 3.0)
	var neck := _jar_feet.y - POT_FEET.y + float(POT_NECK) + 1.0
	var drop := maxf(_drop(), 1.0)
	var landed := _head >= drop - 0.5 and _tail <= 0.0
	var from := int(_tail)
	var to := int(_head)
	for y in range(from, to):
		var row := spout.y + y
		if (row >= neck) != inside:
			continue
		var t := float(y) / drop
		var w := maxf(wide * (1.0 - 0.4 * pow(t, 0.6)), 2.0)
		if _tail > 0.0:
			w = maxf(2.0, w * (1.0 - float(y - from) / maxf(float(to - from), 1.0) * 0.5))
		var wob := roundf(sin(y * 0.15 + age * 6.0) * WOBBLE * t * t)
		var left := drop - float(y)
		if landed and left <= FLARE:
			var u := 1.0 - left / FLARE
			_soft_row(spout.x + wob, row, w + u * u * FLARE_WIDE)
			continue
		_rope_row(spout.x + wob, row, w, inside)


func _rope_row(cx: float, y: float, w: float, dim := false) -> void:
	var l := roundf(cx - w * 0.5)
	var r := roundf(cx + w * 0.5) - 1.0
	var span := r - l
	var deep := HiveArt.HONEY_DEEP
	var mid := HiveArt.HONEY_DEEP if dim else HiveArt.HONEY_MID
	var body := HiveArt.HONEY_MID if dim else HiveArt.HONEY
	var light := HiveArt.HONEY if dim else HiveArt.HONEY_LIGHT
	var shine := HiveArt.HONEY_LIGHT if dim else HiveArt.HONEY_SHINE
	if span < 1.0:
		_box(Vector2(l, y), Vector2(2.0, 1.0), mid)
		return
	_box(Vector2(l, y), Vector2(span + 1.0, 1.0), body)
	_box(Vector2(l, y), Vector2(maxf(ceilf(span * 0.25), 1.0), 1.0), mid)
	_box(Vector2(l + ceilf(span * 0.3), y), Vector2(maxf(ceilf(span * 0.2), 1.0), 1.0), shine)
	_box(Vector2(l + ceilf(span * 0.5), y), Vector2(maxf(ceilf(span * 0.2), 1.0), 1.0), light)
	_box(Vector2(l, y), Vector2.ONE, deep)
	_box(Vector2(r, y), Vector2.ONE, deep)


## A row of the stream where it meets the honey: the surface's own top colours, no dark edge,
## held inside the glass, so the stream and the honey have no seam between them.
func _soft_row(cx: float, y: float, w: float) -> void:
	var tl := (_jar_feet - POT_FEET).floor()
	var span := _span_of(int(y - tl.y))
	var lo := tl.x + float(span.x) + 1.0
	var hi := tl.x + float(span.y) - 1.0
	var l := maxf(roundf(cx - w * 0.5), lo)
	var r := minf(roundf(cx + w * 0.5), hi)
	if r < l:
		return
	_box(Vector2(l, y), Vector2(r - l + 1.0, 1.0), HiveArt.HONEY_LIGHT)
	var s := r - l
	if s >= 3.0:
		_box(Vector2(l + ceilf(s * 0.3), y), Vector2(maxf(ceilf(s * 0.25), 1.0), 1.0), HiveArt.HONEY_SHINE)


## Where the stream meets the honey in the jar, in the honey itself: a low mound in the
## surface's own light where the stream lands, each fold of the rope a pair of humps sliding
## out along the surface and settling into it, and what it folded under sinking as a darker
## swirl. Everything held inside the glass's own spans (HoneyPot's).
func _draw_coils() -> void:
	if _in < 1.0 or _lid_age >= 0.0 or _fill <= 0.0 or _fill > 1.0:
		return
	var tl := (_jar_feet - POT_FEET).floor()
	var y := floorf(_surface_y())
	var x := _spout().x
	var row := _span_of(int(y - tl.y))
	if row.y < row.x:
		return
	var left := tl.x + float(row.x) + 1.0
	var right := tl.x + float(row.y) - 1.0
	if _head > 0.5 and _tail <= 0.0:
		var half := lerpf(WIDE_LEAST, WIDE_MOST, clampf(_turn, 0.0, 1.0)) * 0.5 + FLARE_WIDE * 0.5 + 1.0
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
			_box(Vector2(hx, y), Vector2(2.0, 1.0), _ink(HiveArt.HONEY_MID, 1.0 - k))
		var sink := Vector2(floorf(x + float(c["x"]) + sin(k * 5.0 + float(c["w"])) * 2.0), floorf(y + 2.0 + k * SINK_DEEP))
		var under := _span_of(int(sink.y - tl.y))
		if under.y >= under.x and sink.x >= tl.x + under.x + 1 and sink.x + 1.0 <= tl.x + under.y - 1:
			_box(sink, Vector2(2.0, 1.0), _ink(HiveArt.HONEY_MID, 0.8 * (1.0 - k)))


## The payoff on the jars: the prize rosette with the crown on its boss drops onto the middle
## jar with a bounce and stays (the sheet's option B).
func _draw_rosette() -> void:
	if _finale < 0.0:
		return
	var mid := _slots[1]
	var boss := mid + Vector2(1.0, -POT_FEET.y + ROSETTE_DOWN)
	var t := clampf(_finale / ROSETTE_DROP, 0.0, 1.0)
	var fall := (1.0 - HiveStep._bounce(t)) * ROSETTE_FALL
	var come := clampf(_finale / 0.1, 0.0, 1.0)
	HiveKitchenArt.draw(self, &"rosette", to_canvas((boss - Vector2(0.0, fall)).floor()), &"boss", come)


## The bees drawn to the bottling: one resting on the bucket's rim, one walking in at the
## stand's entrance slot (the stand is a hive).
func _draw_bees() -> void:
	var rim := Vector2(_mouth.x - _bucket_inner.x + 8.0, _mouth.y - _bucket_inner.y - 3.0).floor()
	BeeArt.animate(self, &"worker_rest", age, to_canvas(rim), false, HiveArt.PIXEL)
	var ent := HiveKitchenArt.vec(HiveKitchenArt.data(&"pour").get("entrance", [286, 279]))
	BeeArt.animate(self, &"worker_walk", age + 0.3, to_canvas(ent), true, HiveArt.PIXEL)


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
