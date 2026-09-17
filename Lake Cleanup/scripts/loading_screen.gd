## The loading screen: the filthy lake, the logo on it, and the meter's bare bar under that.
##
## **One picture, drawn in three places** (2026-09-17, `/grill-me` with Richard), so that
## every hand-over between them is no cut at all:
## - the engine's own splash, `assets/boot_splash.png`, which is *a photograph of this
##   control* with its bar filthy (`tools/shot_loading.tscn` takes it), held while the
##   engine starts;
## - the boot scene (`scripts/boot.gd`), where the bar cleans left to right;
## - the lake's curtain (`scripts/curtain.gd`), which holds it over the lake's first frames
##   with the bar clean and then dissolves it onto the menu.
##
## The picture is `assets/loading_lake.png`: the fresh, untouched lake filmed at the very
## view the menu holds (far stop, the lake's middle `Lake.MENU_LAKE_AT` across), so the
## loading screen dissolves into the player's own lake *in the same place* — near seamless
## on a new game, and on a run in progress a before-and-after. Filmed by
## `tools/shot_loading.tscn`; **re-film it if the menu's view, the island or the fill
## change**, and re-take the splash after.
##
## Taken down under `DARKEN` here rather than in the file, so the one number can be judged
## and retuned without re-filming: the lake as the game draws it is busy edge to edge, and
## the logo and the bar need something to stand on.
##
## **The bar is a timed sweep, not a reading, by decision** (Richard: "It doesn't matter if
## it loads too quickly"). Measured, `main.tscn` loads on a thread in 20 ms and the lake's
## own build is 0.56 s on the main thread, where nothing on screen can move — an honest bar
## would jump from filthy to clean in a frame. See `Boot.SWEEP`.
class_name LoadingScreen
extends Control

const PICTURE := "res://assets/loading_lake.png"
const LOGO := preload("res://assets/mdll_logo_stacked.png")

## What is left of the picture's light. By eye on `tools/last_loading.png`.
const DARKEN := Color(0.50, 0.55, 0.53)
## The logo's width as a share of the window's, and where down the window its middle stands.
## **Above the island, not on it**: the island is the middle of the picture, and the first
## layout stood the lockup straight over the hut. The island shows between the two.
const LOGO_WIDE := 0.46
const LOGO_AT := 0.27
## The bar: where down the window its middle stands. **Its size is the HUD meter's own**
## (`HudSkin.meter_scale`), by Richard's call on the first look — drawn at a third of the
## window's width it was the meter's art at three times its size, stretched and soft: "we
## dont need it to be bigger than how it is in the game".
const BAR_AT := 0.76

## How clean the bar reads, 0 to 1.
var progress: float = 0.0:
	set(to):
		progress = clampf(to, 0.0, 1.0)
		if _bar != null:
			_bar.share = progress

var _fill: ColorRect
var _picture: TextureRect
var _logo: TextureRect
var _bar: MeterBar


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Under the picture, and all there is where the picture is missing: the splash's own
	# colour, so a build without the art still opens on the dark water rather than on grey.
	_fill = ColorRect.new()
	_fill.name = &"Fill"
	_fill.color = Curtain.water()
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fill)

	_picture = TextureRect.new()
	_picture.name = &"Picture"
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# Covered, never stretched or padded — the engine's splash is set to Cover to match.
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_picture.self_modulate = DARKEN
	if ResourceLoader.exists(PICTURE):
		_picture.texture = load(PICTURE) as Texture2D
	add_child(_picture)
	# The fill is the fallback, not an underlay: under a picture that is fading it shows
	# through as a wash of green, which is one more layer going at its own pace.
	_fill.visible = _picture.texture == null

	_logo = TextureRect.new()
	_logo.name = &"Logo"
	_logo.texture = LOGO
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	# The lockup is a sticker with a soft rim, not pixel art.
	_logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_logo)

	_bar = MeterBar.new()
	_bar.name = &"Bar"
	_bar.share = progress
	add_child(_bar)

	# Sized by hand rather than by anchors: under a CanvasLayer or a plain Node there is no
	# parent Control to lay this out. See `Farewell._fill`.
	get_viewport().size_changed.connect(_fit)
	_fit()


func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport().get_visible_rect().size
	for part: Control in [_fill, _picture]:
		part.position = Vector2.ZERO
		part.size = size
	var wide := floorf(size.x * LOGO_WIDE)
	var tall := floorf(wide * float(LOGO.get_height()) / float(LOGO.get_width()))
	_logo.size = Vector2(wide, tall)
	_logo.position = Vector2((size.x - wide) * 0.5, size.y * LOGO_AT - tall * 0.5).floor()
	_bar.wide = floorf(HudSkin.METER_FRAME.size.x * HudSkin.meter_scale(size.y))
	_bar.position = Vector2(
		(size.x - _bar.box().x) * 0.5, size.y * BAR_AT - _bar.box().y * 0.5
	).floor()


## The logo and the bar, on or off **at once**. The screen is several pictures lying on each
## other — the lake, the lockup, the bar's water, its frame — and faded together by one
## alpha each of them fades against what is under it, so where they overlap the screen goes
## slower than where they do not: the logo and the bar hung on after the lake behind them
## had half gone, and the bar's water showed through its own wood (Richard: "the fade out to
## the main menu should remove logo and bar right away, not in pieces"). So the curtain
## takes these off in one frame and dissolves the lake alone, and puts them on in one frame
## once the lake is whole.
func dress(on: bool) -> void:
	_logo.visible = on
	_bar.visible = on


func dressed() -> bool:
	return _logo.visible and _bar.visible


## The bar, for the harness.
func bar() -> MeterBar:
	return _bar
