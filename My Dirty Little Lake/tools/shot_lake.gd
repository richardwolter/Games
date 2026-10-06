extends Node
## Opens the lake on a real window, lets it settle, and saves whole frames of it as the
## player sees it in play. A probe for anything that has to be judged over a real gameplay
## frame — the logo over a screenshot, the store capsules — so the frames it takes are the
## ones those want:
##
##   last_lake.png         HUD on, the view as the game opens it
##   last_lake_wide.png    HUD off, same view — the whole lake, island in the middle
##   last_lake_island.png  HUD off, one zoom level in, the island centred
##   last_lake_island_right.png  the same, the island at ISLAND_RIGHT of the frame's width
##
## The cast is posed for every frame, since the capsules want them in the picture and left
## to themselves they are as likely to be off fetching on the far bank: the dog runs in on the
## island's east beach, the first ferry lies off the south-east shore, and the angler faces
## the camera.
##
## Run it with the desktop build, not --headless: nothing renders under the dummy driver.
##
##   godot --path . res://tools/shot_lake.tscn

const SHOT := "res://tools/last_lake%s.png"
## Frames the lake is given to settle before each picture: the camera eases onto its target
## and the first rebuild after a zoom has to land.
const HOLD := 90
## Where the dog runs, in tiles off the island's middle: screen-right is +x, -y.
const DOG_AT := Vector2(4.2, -4.2)
## Where the ferry lies, in tiles off the island's middle: off the beach to the south-east.
const BOAT_AT := Vector2(9.0, 3.0)
## Which way its bow points on the plane; (1, 0) is a quartering view that shows the sail.
const BOAT_HEADING := Vector2(1.0, 0.0)

## Each shot: file suffix, HUD shown, zoom levels in from the furthest, view on the island,
## and where across the frame the island's middle lands (0.5 is centred).
const SHOTS: Array = [
	["", true, 0, false, 0.5],
	["_wide", false, 0, false, 0.5],
	["_island", false, 1, true, 0.5],
	["_island_right", false, 1, true, ISLAND_RIGHT],
]
## The capsules put the logo on the left and the island on the right.
const ISLAND_RIGHT := 0.74

var _main: Node
var _frames := 0
var _shot := 0


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_main)
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _main == null or not _main.is_inside_tree():
		return
	_pose_cast()
	if _frames == 8:
		_stage(SHOTS[0])
	if _frames < 8:
		return
	if _frames == 8 + (_shot + 1) * HOLD:
		var shot := get_viewport().get_texture().get_image()
		shot.save_png(ProjectSettings.globalize_path(SHOT % SHOTS[_shot][0]))
		_shot += 1
		if _shot >= SHOTS.size():
			get_tree().quit()
			return
		_stage(SHOTS[_shot])


## Put the lake in the state a shot wants: HUD, zoom level and where the view is looking.
##
## The view is moved the way the pier probe moves it — a pan held by a hand on the mouse —
## so the camera settles on the island and stays there rather than easing back to the angler.
func _stage(shot: Array) -> void:
	var hud := _main.get_node("HUD") as CanvasLayer
	hud.visible = shot[1]
	# The net's aiming marker follows the mouse; parked in the corner it stays out of the frame.
	Input.warp_mouse(Vector2(2, 2))
	var level: int = _main.call(&"_far_level") + shot[2]
	_main.set(&"_view_zoom", _main.call(&"_zoom_level", level))
	_main.call(&"_push_zoom")
	var angler: Node2D = _main.get(&"_angler")
	if shot[3]:
		var island := Iso.tile_to_world(Iso.CENTRE.x, Iso.CENTRE.y)
		# The camera stands left of the island by the fraction asked for, in world units at
		# this zoom, so the island lands that far across the frame.
		var zoom: float = (_main.get(&"_camera") as Camera2D).zoom.x
		var aside := Vector2((shot[4] - 0.5) * get_viewport().get_visible_rect().size.x / zoom, 0.0)
		_main.set(&"_pan", island - aside - angler.position)
		_main.set(&"_panning", true)
	else:
		_main.set(&"_pan", Vector2.ZERO)
		_main.set(&"_panning", false)


## Pose the cast, whatever their own minds say.
##
## The dog is held in CARRY_BACK on the grass, which is the state that shows the run: it
## strides towards the crate each frame and is put back, so the picture is a dog running in.
## The ferry is docked with nothing to do, so it lies where it is put. The angler's facing
## is a tile-space vector; (1, 1) projects straight down the screen.
func _pose_cast() -> void:
	var dog: Node2D = _main.get(&"_dog")
	if dog != null:
		dog.set(&"tile_pos", Iso.ISLAND_CENTRE + DOG_AT)
		dog.set(&"_state", 5)
		dog.set(&"_mood_left", 1000.0)
		dog.set(&"_trip", 0.0)
	var boats: Array = _main.get(&"_boats")
	if not boats.is_empty():
		var boat: Node2D = boats[0]
		boat.set(&"auto_ferry", false)
		boat.set(&"patrol", false)
		boat.set(&"state", 0)
		boat.set(&"tile_pos", Iso.ISLAND_CENTRE + BOAT_AT)
		boat.set(&"heading", BOAT_HEADING)
	var angler: Node2D = _main.get(&"_angler")
	if angler != null:
		angler.set(&"facing", Vector2(1.0, 1.0).normalized())
