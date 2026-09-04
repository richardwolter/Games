## Turns a 3D boat model into the sheet of turned sprites the game draws.
##
## The lake is a flat 2:1 isometric plane and the ferry has to look like it is steering
## around on it, which a single picture cannot do — a boat pointed north-east and one
## pointed south-west are different pictures, not the same one flipped. So the model is
## rendered once per heading, offline, into one sheet: the game then draws a boat with a
## texture lookup instead of hauling a 3D renderer around for three hulls.
##
## The camera is the projection the rest of the game already uses. Isometric tiles here are
## twice as wide as they are tall, so the ground is seen at 30 degrees, and the model is
## turned rather than the camera: every frame therefore lines up with the same horizon.
##
## Has to run with a real window — a headless Godot has no renderer to bake with:
##   godot --path . res://tools/bake_boat.tscn
extends Node

const MODEL := "res://assets/kenney_watercraft-pack/Models/GLB format/ship-cargo-c.glb"
const OUT_PNG := "res://assets/boat_frames.png"
const OUT_JSON := "res://assets/boat_frames.json"

## How many headings are baked. Sixteen is enough that a turning ferry reads as turning
## rather than as snapping between poses, and it keeps the sheet small.
const FRAMES := 16

## One frame, in pixels. The hull is drawn about ninety pixels long in game, so this is
## comfortably above what it is scaled down to.
const FRAME := 128

## Where the light comes from and how hard, so the baked hull has a lit side and a shaded
## one and does not read as a sticker.
const SUN_ANGLE := Vector3(-50.0, -120.0, 0.0)

## The ground is seen at this angle: a 2:1 isometric plane, so the vertical is half the
## horizontal, which is thirty degrees rather than the 35.26 of a true isometric cube.
const ELEVATION := 30.0

## How much of a pixel has to be hull for it to be kept at all.
const EDGE_ALPHA := 0.5

## Which way round the world the camera stands. Matches Iso: +x tile runs down-right on
## screen, +y tile runs down-left.
const AZIMUTH := 45.0

var _viewport: SubViewport
var _pivot: Node3D
var _frames: Array[Image] = []
var _step: int = 0
var _waited: int = 0


func _ready() -> void:
	var packed := load(MODEL) as PackedScene
	if packed == null:
		printerr("could not load %s" % MODEL)
		get_tree().quit(1)
		return

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(FRAME, FRAME)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# No multisampling. Smoothed edges over a transparent background come back as a rim of
	# half-transparent dark pixels, and at the size the ferry is drawn that rim reads as a
	# grey shadow stuck to the hull. A hard edge is also closer to the pixel art it sails
	# past.
	_viewport.msaa_2d = Viewport.MSAA_DISABLED
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	add_child(_viewport)

	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	var model := packed.instantiate()
	_pivot.add_child(model)

	var extent := _model_extent(model)
	var reach := maxf(maxf(extent.size.x, extent.size.y), extent.size.z)
	# Stand the model on the middle of the pivot, so turning it turns it on the spot rather
	# than swinging it round a corner.
	model.position = -extent.get_center()

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	# Room around the hull at every angle: the diagonal is what has to fit, not the length.
	camera.size = reach * 1.5
	camera.near = 0.01
	camera.far = reach * 10.0
	var elevation := deg_to_rad(ELEVATION)
	var azimuth := deg_to_rad(AZIMUTH)
	var stand := Vector3(
		cos(elevation) * sin(azimuth), sin(elevation), cos(elevation) * cos(azimuth)
	) * reach * 3.0
	_viewport.add_child(camera)
	# Aimed after it is in the tree: look_at needs a node with a world to look through.
	camera.look_at_from_position(stand, Vector3.ZERO, Vector3.UP)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = SUN_ANGLE
	sun.light_energy = 1.15
	_viewport.add_child(sun)

	var sky := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.68, 0.74)
	env.ambient_light_energy = 0.9
	sky.environment = env
	_viewport.add_child(sky)


func _process(_delta: float) -> void:
	if _step >= FRAMES:
		return
	# A viewport needs a frame to draw and another to have drawn; taking the picture too
	# early bakes an empty sheet, which is a bug that only shows up as a missing boat.
	_waited += 1
	if _waited < 3:
		return
	_waited = 0

	_frames.append(_viewport.get_texture().get_image())
	_step += 1
	if _step < FRAMES:
		_pivot.rotation.y = TAU * float(_step) / float(FRAMES)
		return
	_write()
	get_tree().quit(0)


## The sheet: one row of frames, heading zero first, turning the way the game turns.
func _write() -> void:
	var sheet := Image.create_empty(FRAME * FRAMES, FRAME, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.0, 0.0, 0.0, 0.0))
	for i in _frames.size():
		var frame := _frames[i]
		frame.convert(Image.FORMAT_RGBA8)
		_clean_edges(frame)
		sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), Vector2i(i * FRAME, 0))
	sheet.save_png(ProjectSettings.globalize_path(OUT_PNG))

	var file := FileAccess.open(OUT_JSON, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"model": MODEL,
		"frames": FRAMES,
		"frame": FRAME,
		"elevation": ELEVATION,
		"azimuth": AZIMUTH,
	}, "\t"))
	file.close()
	printerr("baked %d frames of %s" % [_frames.size(), MODEL.get_file()])


## Throw away the half-transparent rim around a rendered frame.
##
## Even without multisampling a render leaves a fringe of partly transparent pixels where
## the hull meets nothing, and those pixels carry the dark colour they were blended with.
## Scaled down and drawn over water they are a grey outline that follows the boat around.
## Anything less than half there goes; anything more is made solid.
func _clean_edges(frame: Image) -> void:
	for y in frame.get_height():
		for x in frame.get_width():
			var pixel := frame.get_pixel(x, y)
			if pixel.a < EDGE_ALPHA:
				frame.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
			elif pixel.a < 1.0:
				frame.set_pixel(x, y, Color(pixel.r, pixel.g, pixel.b, 1.0))


## The box a model's meshes take up, in its own space.
func _model_extent(root: Node) -> AABB:
	var box := AABB()
	var first := true
	for node in _all(root):
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		var here := mesh.transform * mesh.mesh.get_aabb()
		box = here if first else box.merge(here)
		first = false
	return box


func _all(root: Node) -> Array[Node]:
	var found: Array[Node] = [root]
	for child in root.get_children():
		found.append_array(_all(child))
	return found
