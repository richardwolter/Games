class_name EndingReel
extends Control
## The ending filmed (2026-10-12, `/grill-me` with Richard): one round window beside the
## closing words and the credits, showing the player's own cleaned lake live, cutting
## between nature shots on Habibs' bars and hopping sides on every cut.
##
## A `SubViewport` sharing the lake's `World2D` with a camera of its own, so what is in the
## bubble is the real lake as it stands, not a film. The HUD and the farewell are on
## CanvasLayers, which belong to the root viewport and not to the world, so they are not in
## it. Drawn only: nothing in the lake reads the reel back.
##
## A shot is a subject found off the lake (`_find`), followed for the shot's length. The list
## falls through: a subject that is not there is skipped; with nothing found the shot before
## carries on. A subject that goes away mid-shot leaves the camera where it was.

const Iso := preload("res://scripts/iso.gd")

## The shot list, in order. Each pick starts from the one after the last.
## No angler and no house (2026-10-12, Richard: "just dogs and nature"); a grown pad or
## flower is the shot the list falls to.
const SHOTS: Array[StringName] = [
	&"frog", &"dogs", &"duck", &"fish", &"bees", &"capy", &"peacock", &"turtle",
	&"songbird", &"dogs", &"bunny", &"fox", &"wolf", &"snake", &"plants",
]
## Beats a shot holds (Richard: a cut every four beats).
const SHOT_BEATS := 4
## The bubble's diameter, a share of the window's height.
const SIZE := 0.3
## Its near edge's gap from the window's side, a share of the width, and its middle down.
const SIDE_GAP := 0.03
const DOWN_AT := 0.5
## The camera's zoom inside the bubble.
const ZOOM := 3.0
## How fast the camera follows its subject (seconds to close most of the gap).
const FOLLOW := 0.12
## How far up from its feet the camera aims, world px: the middle of what is drawn.
const AIM_UP := 4.0
const DOG_UP := 14.0
## Beats the iris takes to close before a cut and to open after it.
const IRIS_BEATS := 0.25
## The circle's edge is cut on this many canvas px, so it steps like the art.
const EDGE_STEP := 3.0
## How long the bubble takes to come in once the words are up.
const COME_IN := 1.2

var lake: Node
var side := 0
var fade := 0.0
var shot: StringName = &""
var shots_taken := 0

var _view: SubViewport
var _cam: Camera2D
var _pic: TextureRect
var _mat: ShaderMaterial
var _subject: Variant = null
var _block := -1
var _pick := 0
var _zoom_to := ZOOM
var _stretch := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view = SubViewport.new()
	_view.name = &"Film"
	_view.transparent_bg = false
	_view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_view.world_2d = get_viewport().world_2d
	add_child(_view)
	_cam = Camera2D.new()
	_cam.zoom = Vector2(ZOOM, ZOOM)
	_view.add_child(_cam)
	_cam.make_current()
	_pic = TextureRect.new()
	_pic.texture = _view.get_texture()
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pic.stretch_mode = TextureRect.STRETCH_SCALE
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/ending_bubble.gdshader")
	_pic.material = _mat
	add_child(_pic)
	_lay_out()
	_cut(true)


## Where the bubble stands this frame, in the parent's canvas.
func bubble_rect() -> Rect2:
	var win := get_viewport_rect().size
	var d := roundf(win.y * SIZE)
	var x := win.x * SIDE_GAP if side == 0 else win.x * (1.0 - SIDE_GAP) - d
	return Rect2(Vector2(roundf(x), roundf(win.y * DOWN_AT - d * 0.5)), Vector2(d, d))


func _lay_out() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	var r := bubble_rect()
	_pic.position = r.position
	_pic.size = r.size
	# Rendered at the window's own pixels, so the art keeps its whole-pixel steps.
	var stretch := get_viewport().get_screen_transform().get_scale().x
	var px := Vector2i(maxi(16, int(r.size.x * stretch)), maxi(16, int(r.size.y * stretch)))
	if _view.size != px:
		_view.size = px
	# The zooms are the lake's own, in canvas px a world px; the film is rendered at the
	# window's pixels, so they are carried through the stretch.
	_stretch = stretch
	_mat.set_shader_parameter(&"edge_step", EDGE_STEP / r.size.x)


func _process(delta: float) -> void:
	# In once the words are up, out with them.
	var words: float = get_parent().get(&"_shown") if get_parent() != null else 1.0
	fade = move_toward(fade, 1.0 if words >= 1.0 else minf(fade, words), delta / COME_IN)
	var block := int(floor(_beat() / float(SHOT_BEATS)))
	if _block < 0:
		_block = block
	elif block != _block:
		_block = block
		_cut(false)
	_follow(delta)
	_cam.zoom = Vector2.ONE * _zoom_to * _stretch
	_lay_out()
	var into := fposmod(_beat(), float(SHOT_BEATS))
	var iris := clampf(into / IRIS_BEATS, 0.0, 1.0)
	iris = minf(iris, clampf((float(SHOT_BEATS) - into) / IRIS_BEATS, 0.0, 1.0))
	_mat.set_shader_parameter(&"iris", iris)
	_mat.set_shader_parameter(&"alpha", fade)


## The song's beat, or the clock if no station is up (a harness).
func _beat() -> float:
	var music := MusicStation.main()
	if music != null:
		return music.beat_clock()
	return Time.get_ticks_msec() / 1000.0 * 144.0 / 60.0


## The next shot: the next subject the lake has, the camera put straight on it.
func _cut(first: bool) -> void:
	if not first:
		side = 1 - side
	for i in SHOTS.size():
		var name: StringName = SHOTS[(_pick + i) % SHOTS.size()]
		var found: Variant = _find(name)
		if found != null:
			shot = name
			_subject = found
			_pick = (_pick + i + 1) % SHOTS.size()
			break
	shots_taken += 1
	_zoom_to = ZOOM
	var at: Variant = _where(_subject)
	if at != null:
		_cam.position = at


func _follow(delta: float) -> void:
	var at: Variant = _where(_subject)
	if at == null:
		return
	var k := 1.0 - exp(-delta / FOLLOW)
	_cam.position = _cam.position.lerp(at, k)


## A subject's world position now, or null if it has gone.
static func _where(subject: Variant) -> Variant:
	if subject is Vector2:
		return subject
	if subject is Node2D:
		if not is_instance_valid(subject):
			return null
		return (subject as Node2D).global_position - Vector2(0.0, DOG_UP)
	if subject is Dictionary:
		var at: Variant = (subject as Dictionary).get("at")
		if not at is Vector2:
			return null
		var up := AIM_UP
		var kind: Variant = (subject as Dictionary).get("kind")
		if kind is StringName and Wildlife.KINDS.has(kind):
			up = float(Wildlife.KINDS[kind]["tall"]) * 0.5
		return at - Vector2(0.0, up + float((subject as Dictionary).get("alt", 0.0)))
	return null


## The subject a shot follows, or null when the lake has none.
func _find(name: StringName) -> Variant:
	var wild: Wildlife = lake.get(&"_wildlife") if lake != null else null
	match name:
		&"plants":
			var fl: Flora = lake.get(&"_flora") if lake != null else null
			if fl == null:
				return null
			var pads := fl.pad_spots()
			return pads[randi() % pads.size()] if not pads.is_empty() else null
		&"dogs":
			for d in Dog.pack:
				if is_instance_valid(d) and d.visible:
					return d
			return null
		&"fish":
			var fish: Fish = lake.get(&"_fish") if lake != null else null
			if fish == null or fish._schools.is_empty():
				return null
			return fish._schools[randi() % fish._schools.size()]
		&"bees":
			var flora: Flora = lake.get(&"_flora") if lake != null else null
			if flora == null or flora._bee_points.is_empty():
				return null
			return flora._bee_points[0]
	if wild == null:
		return null
	var pool: Array = []
	match name:
		&"frog":
			pool = wild._frogs.filter(func(f): return int(f["state"]) != Wildlife.Frog.SWIM)
		&"turtle":
			pool = wild._turtles
		&"duck":
			pool = wild._broods.filter(func(b): return int(b["state"]) != Wildlife.Brood.FLY_IN \
				and int(b["state"]) != Wildlife.Brood.TAKE_OFF)
		&"songbird":
			pool = wild._birds.filter(func(b): return float(b.get("alt", 0.0)) <= 0.0)
		_:
			pool = wild._critters_on_land.filter(func(c): return c["kind"] == name)
	# Only what is there to be seen: an animal still fading in or out is no shot.
	pool = pool.filter(func(a): return float(a.get("fade", 1.0)) > 0.6)
	if pool.is_empty():
		return null
	return pool[randi() % pool.size()]
