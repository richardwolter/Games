extends Node
## Films the foam on the water (issue #31): the net's landing splash and the bow wave it
## pushes on the reel, cropped close, so the pixel-foam ink can be looked at rather than
## guessed. A probe, not a test: `test_lake` guards the wiring, and headless has no
## renderer, so this is also what compiles splash_foam.gdshader, splash_specks.gdshader
## and the lane in water.gdshader — read the engine log for shader errors.
##
## Run it with the desktop build, not --headless, and with --fixed-fps 60:
##
##   <godot> --path . --fixed-fps 60 res://tools/shot_foam.tscn --log-file tools/last_foam_engine.log
##
## Writes tools/last_foam_{land,crown,reel,lane}.png and tools/last_foam.log. On a save of
## its own; the player's is not touched.

const LOG_PATH := "res://tools/last_nethold.log"
const SAVE_PATH := "user://shot_nethold.save"

## When each picture is taken, in seconds after the net lands.
const SHOTS := {
	&"lying": 0.15,
	&"reel": 0.6,
}
const CROP := Vector2i(520, 360)

var _main: Node
var _net: CastNet
var _angler: Angler
var _log: FileAccess
var _frames := 0
var _landed_at := -1.0
var _age := 0.0
var _taken: Array[StringName] = []
var _thrown := false
var _suffix := ""


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE_PATH)
	_main.set(&"autoload_save", false)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	add_child(_main)


func _say(line: String) -> void:
	_log.store_line(line)
	_log.flush()


func _physics_process(delta: float) -> void:
	_frames += 1
	if _frames == 3:
		_net = _main.get_node(^"Net") as CastNet
		var hold := int(OS.get_environment("NET_HOLD")) if OS.get_environment("NET_HOLD") != "" else 4
		var art: Dictionary = _net.get(&"_art")
		var frames: Array = (art[&"land"] as Dictionary)["frames"]
		frames.resize(hold + 1)
		var open := float((frames[-1] as Dictionary)["rim"])
		for f: Dictionary in frames:
			f["ratio"] = float(f["rim"]) / open
		_suffix = "_hold%d" % hold
		_angler = _main.get_node(^"Angler") as Angler
		(_main.get_node(^"Flock") as Flock).spawning = false
		_main.call(&"_zoom_by", 1000.0)
		_main.set(&"net_range_level", 10)
		_main.call(&"_push_net_numbers")
		return
	if _frames < 30:
		return
	if not _thrown:
		_thrown = true
		var where := _water_along(Vector2(1.0, -1.0).normalized())
		_say("cast to %s, mouth %.1f" % [str(where), _net.mouth_extent()])
		if not _net.cast_to(where):
			_say("FAIL the cast was refused")
			get_tree().quit(1)
		return
	if _landed_at < 0.0:
		if _net.state == CastNet.State.REELING or _net.state == CastNet.State.SETTLED:
			_landed_at = 0.0
			_say("landed after %d frames at %s" % [_frames, str(_net.world_pos())])
		return
	_age += delta
	for name: StringName in SHOTS:
		if name in _taken or _age < float(SHOTS[name]):
			continue
		_taken.append(name)
		var shot := get_viewport().get_texture().get_image()
		var on_canvas := get_viewport().get_canvas_transform() * _net.world_pos()
		var over: Vector2 = Vector2(shot.get_size()) / get_viewport().get_visible_rect().size
		var middle := Vector2i(on_canvas * over)
		var rect := Rect2i(middle - CROP / 2, CROP).intersection(Rect2i(Vector2i.ZERO, shot.get_size()))
		shot.save_png("res://tools/last_nethold_%s%s.png" % [name, _suffix])
		_say("%s at %.2f s: net %s state %d bow push %.2f lane %d patches %d" % [
			name, _age, str(_net.world_pos()), _net.state,
			float((_net.get(&"_bow") as HullFoam).get(&"_push")),
			(_main.get(&"_lane") as Array).size(), (_main.get(&"_patches") as Array).size()])
	if _taken.size() >= SHOTS.size():
		_say("done")
		get_tree().quit()


## The farthest catchable spot from the angler along `dir`, in world units.
func _water_along(dir: Vector2) -> Vector2:
	var best := Vector2.INF
	var span := 0.5
	while span <= _net.range_tiles:
		var tile := _angler.tile_pos + dir * span
		var where := Iso.tile_to_world(tile.x, tile.y)
		# The farthest spot the marker would read green at, so the sweep takes something and
		# the lane it parts on the reel is in the picture.
		if _net.can_cast_to(where) and _net.would_catch(where):
			best = where
		span += 0.5
	return best
