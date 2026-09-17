## The one thing drawn over everything: what the lake comes up under, and what it is changed
## behind.
##
## Three jobs, one layer (2026-09-17, the live menu; rewritten the same day after Richard's
## first look: "the fade in and out to go back to the menu is a little stiff, lets darken it
## and come back on the menu, not put a total green screen right away"):
## - **Coming up** (`open_on`). The lake's first frames compile its shaders and lay its soup
##   out, and shown raw they are a hitch and a pop — so it comes up under the loading screen
##   (`LoadingScreen`, the picture the boot scene has just been showing, its bar clean),
##   holds a few frames, takes the logo and the bar off at once, and dissolves the lake
##   that is left onto the menu.
## - **Back to the menu** (`dissolve`). The live view dims, *that dimmed frame is frozen* as
##   a picture over the screen, the world is snapped into the menu's pose behind it, and the
##   frozen frame dissolves onto the menu. A crossfade from the game to the menu: the snap
##   is never seen and no flat colour ever fills the window. Retired: the dip to the
##   splash's solid green and back, which read as the game blinking.
## - **A reload** (`to_loading`): New game over a run. The view dims and the loading screen,
##   bar filthy, comes in over it; then the boot scene takes over on that same picture.
##
## The frame is grabbed on `RenderingServer.frame_post_draw` through a one-shot connection,
## **not awaited**: an error inside a coroutine aborts silently and leaves the tree spinning,
## and nothing here needs one. A lake borrowed by a harness has no curtain at all, so none
## of this runs headless, where there is no frame to grab.
class_name Curtain
extends CanvasLayer

## Over the HUD (1), the farewell (20), the menu (30) and the click ripple (40).
const LAYER := 90
## Rendered frames the loading picture stays whole over a scene that has just come up,
## before it starts to go: the first two are the ones that compile and upload.
const HOLD_FRAMES := 4
## How long the loading picture takes to dissolve onto the menu, in seconds.
const LIFT := 0.9
## The way back to the menu: how dark the view goes before it is frozen (what is left of
## its light), how long that takes, how many frames the frozen picture is held while the
## pose behind it is drawn, and how long it takes to dissolve onto the menu.
const DIM := 0.62
const DIM_TIME := 0.35
const FROZEN_FRAMES := 2
const DISSOLVE := 0.8
## A reload: how long the loading screen takes to come in over the dimming view.
const TO_LOADING := 0.55

var _block: Control
var _frozen: TextureRect
var _dim: ColorRect
var _loading: LoadingScreen
var _tween: Tween
## Frames left before the picture on top starts to go, or under zero when none is held;
## and which picture that is.
var _held: int = -1
var _held_part: CanvasItem
var _held_time: float = 0.0
var _midway: Callable


## The project's own splash colour: what shows round the splash where the window is not the
## picture's shape, and what the loading screen stands on where its picture is missing.
static func water() -> Color:
	return ProjectSettings.get_setting(
		"application/boot_splash/bg_color", Color(0.07, 0.18, 0.055)
	) as Color


func _init() -> void:
	layer = LAYER
	name = &"Curtain"


func _ready() -> void:
	# Eats the clicks while anything of the curtain is showing. Its own node, so the three
	# pictures can stay deaf to the mouse.
	_block = Control.new()
	_block.name = &"Block"
	_block.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_block)
	_frozen = TextureRect.new()
	_frozen.name = &"Frozen"
	_frozen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frozen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frozen.stretch_mode = TextureRect.STRETCH_SCALE
	_frozen.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_frozen)
	_dim = ColorRect.new()
	_dim.name = &"Dim"
	_dim.color = Color.BLACK
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_loading = LoadingScreen.new()
	_loading.name = &"Loading"
	add_child(_loading)
	get_viewport().size_changed.connect(_fit)
	_fit()
	_clear()


func _fit() -> void:
	var box := get_viewport().get_visible_rect().size
	for part: Control in [_block, _frozen, _dim]:
		part.position = Vector2.ZERO
		part.size = box


## Nothing showing, nothing in the way.
func _clear() -> void:
	_frozen.visible = false
	_frozen.texture = null
	_dim.visible = false
	_loading.visible = false
	_block.visible = false
	visible = false
	_held = -1


## Whether anything of it is showing.
func showing() -> bool:
	return visible


## Over a scene that has just come up: the loading screen whole, its bar clean, going by
## itself once the scene under it has drawn a few frames.
func open_on() -> void:
	_kill()
	_clear()
	visible = true
	_block.visible = true
	_loading.progress = 1.0
	_loading.dress(true)
	_loading.modulate.a = 1.0
	_loading.visible = true
	_hold(_loading, HOLD_FRAMES, LIFT)


## Back to the menu: dim, freeze, `midway` behind the frozen frame, dissolve.
func dissolve(midway: Callable) -> void:
	_kill()
	_clear()
	visible = true
	_block.visible = true
	_midway = midway
	_dim.visible = true
	_dim.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_dim, ^"modulate:a", 1.0 - DIM, DIM_TIME).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(func() -> void:
		RenderingServer.frame_post_draw.connect(_freeze, CONNECT_ONE_SHOT)
	)


## The frame that has just been drawn — the view, dimmed — becomes the picture on top, and
## everything behind it is free to change.
func _freeze() -> void:
	var shot := get_viewport().get_texture().get_image()
	if shot != null and not shot.is_empty():
		_frozen.texture = ImageTexture.create_from_image(shot)
		_frozen.modulate.a = 1.0
		_frozen.visible = true
		# The dimming is in the picture now.
		_dim.visible = false
	# Deferred: this is the renderer's signal, and what `midway` does — moving hulls, freeing
	# a layer, writing the save — belongs in the tree's own turn.
	_after_freeze.call_deferred()


func _after_freeze() -> void:
	if _midway.is_valid():
		_midway.call()
	_midway = Callable()
	if _frozen.visible:
		_hold(_frozen, FROZEN_FRAMES, DISSOLVE)
	else:
		# No frame to be had (a dummy renderer): the dimming lifts instead.
		_hold(_dim, FROZEN_FRAMES, DISSOLVE)


## A reload: the view dims and the loading screen, bar filthy, comes in over it. `then` runs
## once it is whole — it is the boot scene's first frame, to the pixel.
func to_loading(then: Callable) -> void:
	_kill()
	_clear()
	visible = true
	_block.visible = true
	_dim.visible = true
	_dim.modulate.a = 0.0
	_loading.progress = 0.0
	# The lake alone comes in; the logo and the bar go on at once when it is whole, which is
	# the boot scene's first frame. See `LoadingScreen.dress`.
	_loading.dress(false)
	_loading.modulate.a = 0.0
	_loading.visible = true
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_dim, ^"modulate:a", 1.0 - DIM, DIM_TIME)
	_tween.tween_property(_loading, ^"modulate:a", 1.0, TO_LOADING).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN_OUT)
	# One callback, not two: the tween is parallel, and two after `chain()` run together.
	_tween.chain().tween_callback(func() -> void:
		_loading.dress(true)
		then.call()
	)


## Keep `part` whole for `frames` drawn frames, then take it off over `time` and clear.
func _hold(part: CanvasItem, frames: int, time: float) -> void:
	_held = frames
	_held_part = part
	_held_time = time


func _process(_delta: float) -> void:
	if _held < 0:
		return
	_held -= 1
	if _held >= 0:
		return
	# The logo and the bar go in this one frame, and only the lake dissolves: faded with it
	# they went in pieces. See `LoadingScreen.dress`.
	if _held_part == _loading:
		_loading.dress(false)
	_tween = create_tween()
	_tween.tween_property(_held_part, ^"modulate:a", 0.0, _held_time).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(_clear)


func _kill() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	if RenderingServer.frame_post_draw.is_connected(_freeze):
		RenderingServer.frame_post_draw.disconnect(_freeze)
