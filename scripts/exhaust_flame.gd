## The truck's exhaust stack, and the flame that comes out of it on CHARGE!.
##
## The pipe is part of the sprite rather than part of the truck's artwork, so the
## stack and its flame can never come apart: every cell of the sheet is drawn
## around the same pipe in the same place, which is what lets the whole thing
## hang off one node.
##
## The sheet is cut by tools/make_exhaust_flame.py out of the source clip, in
## three runs — light, burn, go out — laid left to right, top to bottom. The
## frames are built here rather than in a .tres because the layout is a grid and
## a grid is three numbers, where the resource would be thirty AtlasTextures
## nobody could check by eye.
class_name ExhaustFlame
extends AnimatedSprite2D

const SHEET := preload("res://art/exhaust_flame.png")

## The grid, and how the three runs sit in it. Must match the tool's output — it
## prints exactly these numbers when it runs.
const COLUMNS := 8
const CELL := Vector2i(105, 172)
const IGNITE_CELLS := 4
const BURN_CELLS := 16
const OUT_CELLS := 10

## Where the pipe's mouth is inside a cell, in cell pixels. The node's position
## is that point — so the truck says where its stack pokes out, and the sprite's
## own size and the flame's height stay this file's business.
const MOUTH := Vector2(52.5, 109.5)

## Playback rates, in frames per second. The source runs at 24 and the runs were
## sampled every 2 and every 3 frames, so these put the animation back at the
## speed it was drawn at.
const IGNITE_FPS := 12.0
const BURN_FPS := 8.0
const OUT_FPS := 8.0


func _ready() -> void:
	centered = false
	offset = -MOUTH
	sprite_frames = _build_frames()
	animation_finished.connect(_on_finished)
	play(&"idle")


## Light it. Runs the ignition and then holds on the burn loop until doused.
func light() -> void:
	play(&"ignite")


## Put it out. The tail carries the flame dying and the smoke after it, and ends
## on the bare pipe — which is also what `idle` is, so the hand-off is invisible.
func douse() -> void:
	if animation == &"out" or animation == &"idle":
		return
	play(&"out")


func _on_finished() -> void:
	if animation == &"ignite":
		play(&"burn")
	elif animation == &"out":
		play(&"idle")


func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	# SpriteFrames is created with a "default" animation that nothing here uses,
	# and leaving it behind means a typo'd name plays an empty animation rather
	# than erroring.
	frames.remove_animation(&"default")

	var burn_from := IGNITE_CELLS
	var out_from := IGNITE_CELLS + BURN_CELLS
	_add(frames, &"ignite", 0, IGNITE_CELLS, IGNITE_FPS, false)
	_add(frames, &"burn", burn_from, BURN_CELLS, BURN_FPS, true)
	_add(frames, &"out", out_from, OUT_CELLS, OUT_FPS, false)
	# The pipe at rest is the last cell of the tail — the one the smoke has
	# cleared from — rather than a cell of its own.
	_add(frames, &"idle", out_from + OUT_CELLS - 1, 1, 1.0, true)
	return frames


func _add(frames: SpriteFrames, name: StringName, from: int, count: int,
		fps: float, loops: bool) -> void:
	frames.add_animation(name)
	frames.set_animation_speed(name, fps)
	frames.set_animation_loop(name, loops)
	for i in count:
		var cell := from + i
		var region := AtlasTexture.new()
		region.atlas = SHEET
		region.region = Rect2(
			Vector2(cell % COLUMNS, cell / COLUMNS) * Vector2(CELL), Vector2(CELL)
		)
		frames.add_frame(name, region)
