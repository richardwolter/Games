## What is behind the wash stand: the view from the pump (2026-09-19, `/grill-me` with
## Richard: "a proper background and floorground... as if I'm looking at the lake on a 1st
## person view"). Top to bottom: the sky, the far bank's trees and sand, the lake, the
## island's own sand, and its lawn running under the stand to the bottom of the window.
##
## **Two painted strips and two things drawn here.** The bank and the lawn are baked by
## `tools/build_wash_backdrop.py` out of the pack's own trees and tiles. The water between
## them and the sky over them are drawn in code, because they are the two things that are
## not always the same:
## - **The water is the player's own lake**: one of the palette's five ramps, picked by how
##   much filth the lake still holds through `LakeGrid.FILTH_STATE_AT` — the cutoffs the
##   lake's own shader steps on. Soup early, blue at the end. Flat bands, hard edges, no
##   dither; still, by decision — this is a backdrop, not a second water renderer. Set when
##   the room opens and left alone while it is up.
## - **The sky follows the day** (`DayCycle.sun`): two flat steps, lerped between the
##   palette's morning, noon and afternoon pairs. The only sky in the game.
##
## **The whole of it is darkened** (`DARKEN`, the loading screen's trick) and multiplied by
## the day's tint: the grime and the dirty spray are the water's own filthy greens, and
## against a full-strength lawn they lose the contrast the flat dark wall used to give them.
## One knob, by eye.
##
## At `PIXEL` canvas pixels to a painted one, the lake's own grain — finer than the stand's
## and the nozzle's, on purpose: what is far is fine.
##
## Holds nothing of the lake's. The room hands it `filth`, `sun` and `tint`.
class_name WashBackdrop
extends Control

const BANK_ART := "res://assets/wash_bank.png"
const LAWN_ART := "res://assets/wash_lawn.png"

const PIXEL := 2.0
## Where the near waterline stands down the window, and how tall the lake is drawn, in
## painted pixels. First guesses: judge on `tools/last_wash_room.png`.
const HORIZON := 0.52
const LAKE_TALL := 44
const DARKEN := 0.66
## How far down the bank strip the treetops are, as a share of it: where the sky ends.
const CROWNS_AT := 0.12

## The palette's name for each water state, clean to dirty — `LakeGrid.water_state`'s order.
const STATE_NAMES: Array[String] = ["clean", "hazy", "murky", "foul", "dirty"]
## The lake from the far shore to the near one: a share of its height, and the ramp's step
## (0 deep to 4 light). Shallow at both shores, deep in the middle, and the far bands thinner
## than the near ones, which is all the perspective flat water has.
const BANDS := [[0.08, 3], [0.12, 2], [0.18, 1], [0.28, 0], [0.18, 1], [0.10, 2], [0.06, 3]]
## From this state up the shore's foam line is the filthy foam.
const FOAM_DIRTY_FROM := 3
## Streaks: dashes one step up the ramp from the band they lie on, rolled once off a fixed
## seed. Longer towards the near shore.
const STREAKS := 110
const STREAK_LONG := Vector2(5.0, 34.0)
const STREAK_SEED := 4177
## What is drawn with no palette: the old room's wall.
const FALLBACK := Color(0.07, 0.13, 0.14)

## How much of the lake's filth is left, 0 to 1.
var filth := 1.0:
	set(value):
		filth = clampf(value, 0.0, 1.0)
		queue_redraw()
## Where the sun is along its day, 0 to 1 (`DayCycle.sun`), and the day's tint.
var sun := 0.3:
	set(value):
		sun = value
		queue_redraw()
var tint := Color.WHITE:
	set(value):
		tint = value
		modulate = Color(tint.r * DARKEN, tint.g * DARKEN, tint.b * DARKEN)

var _bank: Texture2D
var _lawn: Texture2D
var _palette: Palette
var _streaks: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(BANK_ART):
		_bank = load(BANK_ART)
	if ResourceLoader.exists(LAWN_ART):
		_lawn = load(LAWN_ART)
	_palette = Palette.master()
	var roll := RandomNumberGenerator.new()
	roll.seed = STREAK_SEED
	for k in STREAKS:
		# Across as a share of the window, down as a share of the lake, length as a share of
		# the way from shortest to longest.
		_streaks.append(Vector3(roll.randf(), roll.randf(), roll.randf()))
	tint = tint


## Whether both strips loaded: without them it is the old flat wall.
func is_painted() -> bool:
	return _bank != null and _lawn != null and _palette != null


## Which of the five water states a share of filth left reads as: the lake's own cutoffs.
static func state_of(share: float) -> int:
	var state := 0
	for at: float in LakeGrid.FILTH_STATE_AT:
		state += int(share >= at)
	return state


## The five steps of a state's ramp, deep to light.
func ramp_of(state: int) -> Array[Color]:
	var name := STATE_NAMES[clampi(state, 0, STATE_NAMES.size() - 1)]
	var out: Array[Color] = []
	for step: String in ["_deep", "_mid", "", "_shallow", "_light"]:
		out.append(_palette.get("water_" + name + step) as Color)
	return out


## The sky's two steps, high and low, for where the sun is.
func sky_at(at: float) -> Array[Color]:
	var out: Array[Color] = []
	for step: String in ["_high", "_low"]:
		var morning := _palette.get("sky_morning" + step) as Color
		var noon := _palette.get("sky_noon" + step) as Color
		var late := _palette.get("sky_afternoon" + step) as Color
		if at < 0.5:
			out.append(morning.lerp(noon, clampf(at / 0.5, 0.0, 1.0)))
		else:
			out.append(noon.lerp(late, clampf((at - 0.5) / 0.5, 0.0, 1.0)))
	return out


## The lake's box in this control, far shore to near.
func lake_box() -> Rect2:
	var near := snappedf(size.y * HORIZON, PIXEL)
	var tall := LAKE_TALL * PIXEL
	return Rect2(0.0, near - tall, size.x, tall)


func _draw() -> void:
	if not is_painted():
		draw_rect(Rect2(Vector2.ZERO, size), FALLBACK)
		return
	var lake := lake_box()
	var bank_tall := _bank.get_height() * PIXEL
	# The sky: the high step over the low, the low one standing on the treetops — split half
	# way down what the crowns leave showing, or the trees hide the low step altogether.
	var sky := sky_at(sun)
	var bank_top := lake.position.y - bank_tall
	var split := snappedf(maxf(bank_top + bank_tall * CROWNS_AT, 0.0) * 0.5, PIXEL)
	draw_rect(Rect2(0.0, 0.0, size.x, split), sky[0])
	draw_rect(Rect2(0.0, split, size.x, lake.position.y - split), sky[1])
	_draw_water(lake)
	_tile(_bank, bank_top)
	_tile(_lawn, lake.end.y)
	# Whatever a tall window leaves under the lawn strip: its last row, carried down.
	var lawn_end := lake.end.y + _lawn.get_height() * PIXEL
	if lawn_end < size.y:
		draw_rect(Rect2(0.0, lawn_end, size.x, size.y - lawn_end), _palette.grass_light)


func _draw_water(lake: Rect2) -> void:
	var state := state_of(filth)
	var ramp := ramp_of(state)
	var rows: Array = []
	var y := lake.position.y
	for k in BANDS.size():
		var tall := snappedf(lake.size.y * float(BANDS[k][0]), PIXEL)
		if k == BANDS.size() - 1:
			tall = lake.end.y - y
		draw_rect(Rect2(0.0, y, size.x, tall), ramp[int(BANDS[k][1])])
		rows.append([y, y + tall, int(BANDS[k][1])])
		y += tall
	for streak: Vector3 in _streaks:
		var at_y := snappedf(lake.position.y + streak.y * (lake.size.y - PIXEL), PIXEL)
		var step := 0
		for row: Array in rows:
			if at_y >= float(row[0]) and at_y < float(row[1]):
				step = int(row[2])
		# Longer the nearer it is, and nearer is further down.
		var long := lerpf(STREAK_LONG.x, STREAK_LONG.y, streak.z * (0.3 + 0.7 * streak.y))
		draw_rect(
			Rect2(
				snappedf(streak.x * size.x, PIXEL), at_y, snappedf(long * PIXEL, PIXEL), PIXEL
			),
			ramp[mini(step + 1, ramp.size() - 1)]
		)
	var foam := _palette.foam_dirty if state >= FOAM_DIRTY_FROM else _palette.foam
	draw_rect(Rect2(0.0, lake.position.y, size.x, PIXEL), foam)
	draw_rect(Rect2(0.0, lake.end.y - PIXEL, size.x, PIXEL), foam)


## A strip laid across the window at `top`, as many times as the window is wide.
func _tile(strip: Texture2D, top: float) -> void:
	var box := Vector2(strip.get_width(), strip.get_height()) * PIXEL
	var x := 0.0
	while x < size.x:
		draw_texture_rect(strip, Rect2(Vector2(x, top), box), false)
		x += box.x
