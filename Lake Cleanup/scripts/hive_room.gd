## The hive room: what opens when the angler works the hive (2026-09-30, the beehive
## sidequest; `docs/hive/contract.md` section 6, approved off `tools/last_hive_mockup_room.png`).
##
## **Outdoors, like the wash room, and built the same way**: the wash room's own
## `WashBackdrop` behind everything — the view from the island, the lake still running on
## it, the pack and the pigeons still about — veiled less than the wash room veils it
## (`DARKEN` 0.82 against its 0.66: here the pieces are what is looked at, not grime that has
## to read against the lawn) and its far bank slid along (`BANK_OFFSET`), so the trees behind
## the hive are not the ones behind the pump. Over it, one step at a time, the step's own
## scene; over that the room's two pieces of furniture, drawn on the art grid the steps use:
## - **the step plank** at the top: oak, one comb cell a step of *this visit's* plan — lit
##   for the step in hand, filling with honey from the bottom when it is done — joined by a
##   line that turns honey behind the player, each cell with its name under it;
## - **the hint card** at the foot: the letter's paper, the verb in the head ink, and the
##   prompt for the device in hand on its left. It swaps its words with a quick fade.
## And the close cross, top right, last, so nothing a step draws can cover it.
##
## **The plan is the hive's** (`Hive.plan`): a new colony is caught, smoked and crowned (three steps),
## a later harvest two. The room runs it — each step instanced, begun, waited on — and tells
## the lake only two things, each **the moment it is true**: `swarm_caught` once the catch is
## done, `harvested` once the last step is. **Closing half way keeps what was said and
## nothing else**: a swarm caught stays caught, and a harvest is counted only on `harvested`.
## Nothing here is saved and nothing costs anything.
##
## **The steps are loaded by path when they are needed, not preloaded** (`STEP_NAMES`): a
## preload is a parse-time dependency, and a step with a mistake in it would take the room,
## and the lake that builds the room, down with it. A step that will not load is passed over
## with its cell filled and a warning, so the rest of a visit still runs.
##
## Lent by the lake, as for the wash room: the day, the meter, the pack, the fleet, the
## rubbish and the flock for the backdrop, and the hive for the plan. Holds no state of the
## lake's.
class_name HiveRoom
extends Control

const Style := preload("res://scripts/style.gd")

signal close_asked
## The catch step is done: the lake turns the hive READY and gives it its paint back.
signal swarm_caught
## A harvest's last step is done: the lake adds the jars.
signal harvested
## A new colony's last step (the queen found) is done: the lake sets it making its first honey.
signal settled

## Each step's name and the script that plays it.
const STEP_NAMES := {
	&"catch": "res://scripts/hive_step_catch.gd",
	&"smoke": "res://scripts/hive_step_smoke.gd",
	&"queen": "res://scripts/hive_step_queen.gd",
	&"uncap": "res://scripts/hive_step_uncap.gd",
	&"pour": "res://scripts/hive_step_pour.gd",
}
## The whole ceremony in order: the plan when there is no hive to ask (a spike, a probe).
const STEP_ORDER: Array[StringName] = [&"catch", &"smoke", &"queen"]
## The settle between two steps, after the cell has filled.
const BETWEEN := 0.7
## After the last step: the done card up, and then `close_asked` by itself.
const DONE_HOLD := 2.2
## A done cell fills with honey from its foot over this long.
const PIP_FILL := 0.3

## The view behind: veiled less than the wash room's, the far bank slid along.
const DARKEN := 0.82
const BANK_OFFSET := 150.0

## The plank, in painted pixels of the art grid (the mockup's `pips_art`): a cell every
## `PIP_SPACING`, the plank that wide a cell plus `PLANK_PAD`, its wood from `PLANK_TOP` down
## `PLANK_TALL` rows, the cells' middles on `PIP_Y`, the joining line on `LINE_Y`, the names'
## tops on `LABEL_Y`.
const PIP_SPACING := 42
const PLANK_PAD := 8
const PLANK_TOP := 1
const PLANK_TALL := 38
const PIP_Y := 14
const LINE_Y := 13
const LABEL_Y := 23
## How many grain dashes the plank carries, off a fixed seed so it is the same plank every
## visit of the same length.
const GRAIN := 26
const GRAIN_SEED := 2
## A step not reached yet: the ribbon's cream taken down towards the wood, the mockup's own.
const TODO_INK := Color(206 / 255.0, 170 / 255.0, 150 / 255.0)

## The hint card, in painted pixels: its top and height, the room its words leave either
## side (`CARD_ROOM`: the prompt's 28 on the left and 10 on the right), where the prompt sits
## in it and where the words start.
const CARD_Y := 318
const CARD_TALL := 28
const CARD_ROOM := 38
const ICON_AT := Vector2(6.0, 6.0)
const WORDS_AT := 28
## A done card has no prompt and centres its words, `CARD_BARE` a side.
const CARD_BARE := 10
## The words, in canvas pixels: the rung they want and the least they may fall to, and the
## width past which they fall (the translations' own `_size`/`_least`/`_width`).
const HINT_SIZE := Style.TEXT_HEAD
const HINT_LEAST := 16
const HINT_WIDE := 600.0
## How long the card takes to fade out, and back in, when its words change.
const CARD_FADE := 0.12
const CARD_SHADOW := Color(0.0, 0.0, 0.0, 90 / 255.0)

## The close cross: its top left on the art grid (painted pixels), and its side in canvas
## pixels — the mockup's 22-pixel plank in the top right corner.
const CLOSE_AT := Vector2(609.0, 3.0)
const CLOSE_SIDE := 44.0

## The payoffs: a few stars off a cell as it fills, a burst over the whole plank at the end.
const STAR_LIFE := 0.7
const STAR_ARM := 2
const PIP_STARS := 4
const DONE_STARS := 16

enum Phase { IDLE, STEP, BETWEEN, DONE }

## Lent by the lake, as for the wash room. All optional: with none the backdrop is a late
## morning over a filthy lake, and the plan is the whole ceremony.
var day: DayCycle
var filth_left := Callable()
var pack_size := Callable()
var fleet_size := Callable()
var rubbish: Array = []
var flock: Flock
var hive: Hive
## The bucket's honey, 0..1: the uncapping fills it and the pour draws it down, so the level
## carries from the one step to the next (the second pass, 2026-09-30). Set to full when a
## visit's pour has no uncapping before it.
var honey := 0.0

var _backdrop: WashBackdrop
var _host: Control
var _overlay: Overlay
var _close: CloseButton
var _plan: Array[StringName] = []
var _phase := Phase.IDLE
var _index := -1
var _step: HiveStep = null
var _wait := 0.0
var _close_sent := false
## How many steps of the plan are done, and how full each cell is (0 to 1).
var _done_count := 0
var _fill: Array[float] = []
var _grain: Array[Rect2] = []
## The words on the card now and the words it is fading to: a step's name, `&"done"`, or
## `&""` for no card.
var _card_shown := &""
var _card_want := &""
var _card_alpha := 0.0
## `{at, age, life, arm}`, canvas pixels.
var _stars: Array[Dictionary] = []
var _roll := RandomNumberGenerator.new()
var _prompts := {}
var _pending_open := false


func _ready() -> void:
	# Walked with the pad's stick (scripts/pad.gd, `pad_focus` below).
	add_to_group(Pad.FOCUS_GROUP)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_roll.randomize()
	for tile: String in ["mouse_click", "pad_a", "pad_rt"]:
		var path := FirstSteps.PROMPTS % tile
		if ResourceLoader.exists(path):
			_prompts[tile] = load(path)
	_backdrop = WashBackdrop.new()
	_backdrop.name = &"Backdrop"
	_backdrop.darken = DARKEN
	_backdrop.bank_offset = BANK_OFFSET
	add_child(_backdrop)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_host = Control.new()
	_host.name = &"Steps"
	_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_host)
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay = Overlay.new()
	_overlay.name = &"Overlay"
	_overlay.room = self
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_close = CloseButton.new()
	_close.name = &"Close"
	_close.pressed.connect(func() -> void: close_asked.emit())
	add_child(_close)
	resized.connect(_lay_out)
	_lay_out()
	if _pending_open:
		_pending_open = false
		open(true)


## The room coming up, or going away. Up, the backdrop is lent what it shows the way
## `WashRoom.open` lends it, the plan is asked of the hive and the first step begins. Down,
## the step in hand is dropped where it stands: nothing it did is kept but what was already
## said (`swarm_caught`, `harvested`).
func open(up: bool) -> void:
	visible = up
	if not is_node_ready():
		_pending_open = up
		return
	if not up:
		_drop_step()
		_phase = Phase.IDLE
		_index = -1
		_stars.clear()
		_card_shown = &""
		_card_want = &""
		return
	if filth_left.is_valid():
		_backdrop.filth = float(filth_left.call())
	if pack_size.is_valid():
		_backdrop.pack = int(pack_size.call())
	if fleet_size.is_valid():
		_backdrop.fleet = int(fleet_size.call())
	_backdrop.rubbish = rubbish
	if flock != null:
		_backdrop.bird_sheet = flock.sheet()
		_backdrop.bird_kinds = flock.kinds()
	_backdrop.reset()
	_drop_step()
	_plan.clear()
	if hive != null:
		_plan.assign(hive.plan())
	else:
		_plan.assign(STEP_ORDER)
	_fill.clear()
	_fill.resize(_plan.size())
	_fill.fill(0.0)
	_done_count = 0
	_close_sent = false
	honey = 0.0
	_stars.clear()
	_card_shown = &""
	_card_want = &""
	_card_alpha = 0.0
	_lay_grain()
	_lay_out()
	if _plan.is_empty():
		_phase = Phase.IDLE
		_index = -1
		return
	_start(0)


## The step in hand's name, or `&""` once the plan is done or when nothing is up. Between
## two steps it is still the one just finished.
func step_name() -> StringName:
	if (_phase == Phase.STEP or _phase == Phase.BETWEEN) and _index >= 0 and _index < _plan.size():
		return _plan[_index]
	return &""


## This visit's plan.
func plan() -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(_plan)
	return out


## The step in hand, or null. Between two steps it is the one just finished, still drawn.
func step() -> HiveStep:
	return _step


## Where the plan has got to: its index, and whether the done card is up.
func index() -> int:
	return _index


func is_done() -> bool:
	return _phase == Phase.DONE


## How many of this visit's steps are done.
func steps_done() -> int:
	return _done_count


func backdrop() -> WashBackdrop:
	return _backdrop


## The words the card is showing, or fading to: what a harness reads to prove the card is
## not the raw key.
func hint_text() -> String:
	var key := _card_want if _card_want != &"" else _card_shown
	return _hint_of(key)


## The canvas pixels of the art grid's top left: 640x360 painted pixels centred in the room,
## held on a whole painted pixel so `HiveArt.snap` is the grid's own.
func origin() -> Vector2:
	return HiveArt.snap((size - HiveArt.GRID * HiveArt.PIXEL) * 0.5)


## For the harness: finish the step in hand at once, the way its own last move would. Between
## two steps the next one is begun first and finished, so each call finishes exactly one
## step. False when there was nothing to finish.
func skip_step() -> bool:
	if _phase == Phase.BETWEEN:
		_start(_index + 1)
	if _phase != Phase.STEP or _step == null:
		return false
	_step.done_once()
	return true


func _start(at: int) -> void:
	_drop_step()
	if at >= _plan.size():
		_finish_plan()
		return
	_index = at
	_phase = Phase.STEP
	var what := _plan[at]
	_card_want = what
	var made := _make_step(what)
	if made == null:
		push_warning("HiveRoom: step %s would not load; passed over" % what)
		_on_step_finished(at)
		return
	_step = made
	_step.room = self
	_step.name = StringName("Step_" + String(what))
	_host.add_child(_step)
	_step.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_step.finished.connect(_on_step_finished.bind(at))
	_step.begin()


## A step's script, instanced, or null when it is missing, broken or not a step.
func _make_step(what: StringName) -> HiveStep:
	var path: String = STEP_NAMES.get(what, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var script := load(path) as Script
	if script == null or not script.can_instantiate():
		return null
	var made: Object = script.new()
	var as_step := made as HiveStep
	if as_step == null and made is Node:
		(made as Node).free()
	return as_step


func _drop_step() -> void:
	if _step == null:
		return
	if is_instance_valid(_step):
		if _step.get_parent() != null:
			_step.get_parent().remove_child(_step)
		_step.queue_free()
	_step = null


func _on_step_finished(at: int) -> void:
	if at != _index or _phase != Phase.STEP:
		return
	_done_count = maxi(_done_count, at + 1)
	_burst(_pip_centre(at), PIP_STARS, 10.0)
	if _plan[at] == &"catch":
		swarm_caught.emit()
	if at >= _plan.size() - 1:
		_finish_plan()
		return
	_phase = Phase.BETWEEN
	_wait = PIP_FILL + BETWEEN


## The last step is done: the lake is told at once, so a close in the next breath still
## counts the harvest. Then the done card, the stars over the plank, the flourish, and the
## room closes itself after `DONE_HOLD`. The last step stays drawn behind the card.
func _finish_plan() -> void:
	_phase = Phase.DONE
	_wait = DONE_HOLD
	# A new colony's visit ends on the queen, a harvest on the pour: each tells the lake its own
	# news and has its own card.
	if _plan.has(&"pour"):
		_card_want = &"done"
		harvested.emit()
	else:
		_card_want = &"settled"
		settled.emit()
	var box := _plank_box()
	for k in DONE_STARS:
		_stars.append({
			"at": Vector2(
				_roll.randf_range(box.position.x, box.end.x),
				_roll.randf_range(box.position.y - 8.0, box.end.y + 8.0)
			),
			"age": -_roll.randf_range(0.0, 0.5), "life": STAR_LIFE,
			"arm": 2 + _roll.randi() % 2,
		})
	HiveStep.sound(&"hive_done")


func _process(delta: float) -> void:
	if not visible:
		return
	if day != null:
		if absf(_backdrop.sun - day.sun) > 0.002:
			_backdrop.sun = day.sun
		if not _backdrop.tint.is_equal_approx(day.tint):
			_backdrop.tint = day.tint
		_backdrop.shade = Vector3(day.lean, day.stretch, day.ink)
	if _phase == Phase.BETWEEN:
		_wait -= delta
		if _wait <= 0.0:
			_start(_index + 1)
	elif _phase == Phase.DONE and not _close_sent:
		_wait -= delta
		if _wait <= 0.0:
			_close_sent = true
			close_asked.emit()
	for k in mini(_done_count, _fill.size()):
		_fill[k] = minf(_fill[k] + delta / PIP_FILL, 1.0)
	# The card: fade out, take the new words, fade in.
	if _card_shown != _card_want:
		_card_alpha -= delta / CARD_FADE
		if _card_alpha <= 0.0 or _card_shown == &"":
			_card_alpha = 0.0
			_card_shown = _card_want
	elif _card_shown != &"":
		_card_alpha = minf(_card_alpha + delta / CARD_FADE, 1.0)
	var kept: Array[Dictionary] = []
	for star: Dictionary in _stars:
		star["age"] = float(star["age"]) + delta
		if float(star["age"]) < float(star["life"]):
			kept.append(star)
	_stars = kept
	_overlay.queue_redraw()


func _lay_out() -> void:
	if _close == null:
		return
	_close.position = origin() + CLOSE_AT * HiveArt.PIXEL
	_close.size = Vector2(CLOSE_SIDE, CLOSE_SIDE)


func _burst(at: Vector2, count: int, spread: float) -> void:
	for k in count:
		_stars.append({
			"at": at + Vector2(_roll.randf_range(-spread, spread), _roll.randf_range(-spread, spread)),
			"age": -_roll.randf_range(0.0, 0.15), "life": STAR_LIFE, "arm": STAR_ARM,
		})


## The grain dashes along the plank, in painted pixels from its top left, rolled off a fixed
## seed for this plan's width.
func _lay_grain() -> void:
	_grain.clear()
	var wide := PIP_SPACING * _plan.size() + PLANK_PAD
	if wide <= 14:
		return
	var roll := RandomNumberGenerator.new()
	roll.seed = GRAIN_SEED
	for k in GRAIN:
		_grain.append(Rect2(
			roll.randi_range(2, wide - 12), roll.randi_range(6, 33), roll.randi_range(4, 12), 1
		))


## The plank's wood, in canvas pixels.
func _plank_box() -> Rect2:
	var wide := PIP_SPACING * _plan.size() + PLANK_PAD
	var left := floori(HiveArt.GRID.x * 0.5) - wide / 2
	return Rect2(
		origin() + Vector2(left - 1, PLANK_TOP) * HiveArt.PIXEL,
		Vector2(wide + 2, PLANK_TALL) * HiveArt.PIXEL
	)


## A cell's middle, in canvas pixels.
func _pip_centre(at: int) -> Vector2:
	var count := _plan.size()
	var across := HiveArt.GRID.x * 0.5 + float(int((float(at) - float(count - 1) * 0.5) * PIP_SPACING))
	return origin() + Vector2(across, PIP_Y) * HiveArt.PIXEL


func _hint_of(key: StringName) -> String:
	if key == &"":
		return ""
	return Text.of("HIVE_HINT_" + String(key).to_upper())


## The prompt for the device in hand: the mouse's click, or on the pad A for the queen (a
## click to find her) and RT for the rest (held or pumped). None on the done card.
func _prompt_of(key: StringName) -> Texture2D:
	if key == &"done" or key == &"settled" or key == &"":
		return null
	var tile := "mouse_click"
	if Pad.is_pad():
		tile = "pad_a" if key == &"queen" else "pad_rt"
	return _prompts.get(tile) as Texture2D


## Words and whether each is in the head ink: the words between asterisks are.
static func marked(text: String) -> Array:
	var out: Array = []
	var parts := text.split("*")
	for k in parts.size():
		if not parts[k].is_empty():
			out.append([parts[k], k % 2 == 1])
	return out


## The plank, the card and the stars, drawn by the overlay on the room's own coordinates.
func _draw_overlay(ci: CanvasItem) -> void:
	if not _plan.is_empty():
		_draw_plank(ci)
	if _card_shown != &"" and _card_alpha > 0.0:
		_draw_card(ci, _card_shown, _card_alpha)
	for star: Dictionary in _stars:
		var age := float(star["age"])
		if age < 0.0:
			continue
		var t := clampf(age / float(star["life"]), 0.0, 1.0)
		var bright := sin(t * PI)
		HiveArt.star(ci, star["at"], int(roundf(float(star["arm"]) * bright)), bright)


func _draw_plank(ci: CanvasItem) -> void:
	var grain := HiveArt.PIXEL
	var box := _plank_box()
	var cell := func(x: float, y: float, w: float, h: float, ink: Color) -> void:
		ci.draw_rect(Rect2(box.position + Vector2(x, y) * grain, Vector2(w, h) * grain), ink)
	var wide := box.size.x / grain - 2.0
	# The wood, its corners left off: a deep rim, the face, a lit top, a low foot, grain.
	cell.call(1.0, 0.0, wide, 1.0, Style.FRAME_DEEP)
	cell.call(1.0, PLANK_TALL - 1.0, wide, 1.0, Style.FRAME_DEEP)
	cell.call(0.0, 1.0, 1.0, PLANK_TALL - 2.0, Style.FRAME_DEEP)
	cell.call(wide + 1.0, 1.0, 1.0, PLANK_TALL - 2.0, Style.FRAME_DEEP)
	cell.call(1.0, 1.0, wide, PLANK_TALL - 2.0, Style.FRAME)
	cell.call(1.0, 1.0, wide, 2.0, Style.FRAME_LIT)
	cell.call(1.0, PLANK_TALL - 4.0, wide, 3.0, Style.FRAME_LOW)
	for dash: Rect2 in _grain:
		cell.call(1.0 + dash.position.x, dash.position.y - 1.0, dash.size.x, dash.size.y, Style.FRAME_LOW)
	# The joining lines, honey behind the player.
	var count := _plan.size()
	for k in count - 1:
		var from := _pip_centre(k)
		var to := _pip_centre(k + 1)
		var ink := HiveArt.HONEY_LIGHT if k < _done_count else Style.FRAME_LOW
		ci.draw_rect(Rect2(
			Vector2(from.x + 9.0 * grain, origin().y + LINE_Y * grain),
			Vector2(to.x - from.x - 18.0 * grain, grain)
		), ink)
	# The cells, and their names under them.
	var face := Style.font()
	for k in count:
		var middle := _pip_centre(k)
		var now := k == _index and _phase == Phase.STEP
		if now:
			_draw_pip(ci, &"pip_now", middle, HiveArt.HONEY_SHINE)
		elif k < _done_count:
			var full := _fill[k] if k < _fill.size() else 1.0
			if full < 1.0:
				_draw_pip(ci, &"pip_todo", middle, HiveArt.WAX)
			_draw_pip_fill(ci, middle, full)
		else:
			_draw_pip(ci, &"pip_todo", middle, HiveArt.WAX)
		var label := Text.of("HIVE_STEP_" + String(_plan[k]).to_upper()).to_upper()
		var size_px := Style.TEXT_SMALL
		if face.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px).x > PIP_SPACING * grain - 4.0:
			size_px = Style.TEXT_TINY
		var span := face.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px).x
		var base := Vector2(
			roundf(middle.x - span * 0.5),
			origin().y + LABEL_Y * grain + face.get_ascent(size_px)
		)
		var ink := TODO_INK
		if now:
			ink = Style.GOLD
		elif k < _done_count:
			ink = Style.RIBBON_INK
		ci.draw_string(face, base + Vector2(1.0, 2.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px, Style.FRAME_DEEP)
		ci.draw_string(face, base, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px, ink)


## A cell off the sheet on its middle, or a square in its colour with no sheet.
func _draw_pip(ci: CanvasItem, piece: StringName, middle: Vector2, stand_in: Color) -> void:
	if HiveArt.has(piece):
		HiveArt.draw(ci, piece, middle, &"c")
		return
	var half := Vector2(6.0, 6.0) * HiveArt.PIXEL
	ci.draw_rect(Rect2(middle - half, half * 2.0), HiveArt.OUT)
	ci.draw_rect(Rect2(middle - half, half * 2.0).grow(-HiveArt.PIXEL), stand_in)


## A done cell, filled from its foot up to `full` of its height.
func _draw_pip_fill(ci: CanvasItem, middle: Vector2, full: float) -> void:
	if full <= 0.0:
		return
	if not HiveArt.has(&"pip_done"):
		var half := Vector2(6.0, 6.0) * HiveArt.PIXEL
		var box := Rect2(middle - half, half * 2.0).grow(-HiveArt.PIXEL)
		var tall := snappedf(box.size.y * full, HiveArt.PIXEL)
		ci.draw_rect(Rect2(box.position.x, box.end.y - tall, box.size.x, tall), HiveArt.HONEY)
		return
	if full >= 1.0:
		HiveArt.draw(ci, &"pip_done", middle, &"c")
		return
	var cut := HiveArt.size(&"pip_done")
	var rows := ceilf(cut.y * full)
	var top := middle - HiveArt.anchor(&"pip_done", &"c") * HiveArt.PIXEL
	HiveArt.draw_region(
		ci, &"pip_done",
		Rect2(top + Vector2(0.0, (cut.y - rows) * HiveArt.PIXEL), Vector2(cut.x, rows) * HiveArt.PIXEL),
		Rect2(0.0, cut.y - rows, cut.x, rows)
	)


## The paper card at the foot: its size follows its words, the head word in the head ink, no
## shade under any of it (ink on paper; `draw_string`, not `Style.write`).
func _draw_card(ci: CanvasItem, key: StringName, alpha: float) -> void:
	var text := _hint_of(key)
	if text.is_empty():
		return
	var face := Style.font()
	var parts := marked(text)
	var size_px := HINT_SIZE
	var wide := _words_wide(face, parts, size_px)
	if wide > HINT_WIDE:
		size_px = HINT_LEAST
		wide = _words_wide(face, parts, size_px)
	var grain := HiveArt.PIXEL
	var icon := _prompt_of(key)
	var words_px := ceili(wide / grain)
	var card_w := words_px + (CARD_ROOM if icon != null else CARD_BARE * 2)
	var left := floori(HiveArt.GRID.x * 0.5) - card_w / 2
	var box := Rect2(origin() + Vector2(left, CARD_Y) * grain, Vector2(card_w, CARD_TALL) * grain)
	var fade := func(ink: Color) -> Color:
		return Color(ink.r, ink.g, ink.b, ink.a * alpha)
	ci.draw_rect(Rect2(box.position + Vector2(1.0, 2.0) * grain, box.size), fade.call(CARD_SHADOW))
	ci.draw_rect(box.grow(grain), fade.call(FirstSteps.NOTE_OUTER))
	ci.draw_rect(box, fade.call(Style.PAPER))
	ci.draw_rect(Rect2(box.position.x, box.end.y - 2.0 * grain, box.size.x, 2.0 * grain), fade.call(Style.PAPER_EDGE))
	var x := box.position.x + CARD_BARE * grain
	if icon != null:
		ci.draw_texture_rect(
			icon, Rect2(box.position + ICON_AT * grain, icon.get_size() * grain), false,
			Color(1.0, 1.0, 1.0, alpha)
		)
		x = box.position.x + WORDS_AT * grain
	var middle := box.position.y + CARD_TALL * 0.5 * grain
	var base := roundf(middle + (face.get_ascent(size_px) - face.get_descent(size_px)) * 0.5)
	for part: Array in parts:
		var words: String = part[0]
		var ink := Style.PAPER_HEAD if bool(part[1]) else Style.PAPER_INK
		ci.draw_string(face, Vector2(roundf(x), base), words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px, fade.call(ink))
		x += face.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px).x


static func _words_wide(face: Font, parts: Array, size_px: int) -> float:
	var wide := 0.0
	for part: Array in parts:
		wide += face.get_string_size(String(part[0]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px).x
	return wide


## The pad (`scripts/pad.gd`): while a step has the stick it is the step's; otherwise — the
## done card up, or a step that says so — the close cross is the one stop. Between two steps
## the stick stays the finished step's, so an A pressed in the settle does not land on the
## cross and close the room.
func pad_free() -> bool:
	if _step == null or not is_instance_valid(_step):
		return false
	if _phase != Phase.STEP and _phase != Phase.BETWEEN:
		return false
	return _step.pad_free()


## What A would act on while the step has the stick: the step's own, in the room's pixels
## (the step fills the room from its top left, so its pixels are the room's).
func pad_mark() -> Rect2:
	if pad_free():
		return _step.pad_mark()
	return Rect2()


func pad_focus() -> Array:
	if pad_free() or _close == null or not _close.visible:
		return []
	return [{"box": _close.get_rect(), "key": &"close", "first": true}]


## The overlay: its own control only so it can draw over the step and let every click through
## to it. It draws off the room's own numbers.
class Overlay:
	extends Control

	var room: HiveRoom

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if room != null:
			room._draw_overlay(self)
