extends Node
## The aim ring on the real lake (2026-10-03, `/grill-me` with Richard). Three waters (dirty,
## murky, clean: the lake thinned and emptied in two regions to make them), two net sizes
## (level 0 and a mid-run 2.4 tiles), and on each a grid drawn by `AimRing` as the game
## draws it: rows are the ring still and moments of its halos and dashes, columns are catch /
## nothing / out of range. First made to pick between candidates (A1, A2, B1, B2 off a smooth
## reference; A2 won); now the check on the pick.
##
## Saves tools/last_aim_sheet.png (rows: sizes, columns: waters), each crop as
## tools/last_aim_<water>_<size>.png, and tools/last_aim.log (water states, zoom). Own save,
## under its own node. Desktop build, not --headless:
##
##   godot --path . --fixed-fps 60 res://tools/shot_aim.tscn

const SAVE_PATH := "user://shot_aim.save"
const SHEET := "res://tools/last_aim_sheet.png"
const CROP := "res://tools/last_aim_%s_%s.png"
const LOG := "res://tools/last_aim.log"
const HOLD := 90

## Tile offsets from the lake's middle: screen-left, screen-down, screen-right.
const WATERS := {
	"dirty": Vector2(-15.0, 15.0),
	"murky": Vector2(15.0, 15.0),
	"clean": Vector2(15.0, -15.0),
}
const REGION := 15.0
const MURKY_KEEP := 0.45
const SIZES := {"small": -1.0, "mid": 2.4}


var _main: Node
var _grid: LakeGrid
var _net: CastNet
var _frames := 0
var _due := 0
var _jobs: Array = []
var _job := 0
var _overlay: Sheet
var _crops: Array[Image] = []
var _log := PackedStringArray()


## The game's ring (`AimRing`, as `CastNet._draw_aim` draws it) round one spot: still, and at
## moments of its halos (green's big and small, red's) and of the dashes' march.
class Sheet extends Node2D:
	var span := 40.0
	var title := ""
	var net: CastNet
	var rows: Array = []
	const LABEL_W := 250.0
	const HEADS := ["catch", "nothing", "out of range"]

	func cell() -> Vector2:
		return Vector2(span * 2.6 + 70.0, span * 1.3 + 50.0)

	## Local rect the sheet covers, labels included.
	func box() -> Rect2:
		var c := cell()
		var w := c.x * 3.0 + LABEL_W
		var h := c.y * float(rows.size()) + 60.0
		return Rect2(Vector2(-w * 0.5, -h * 0.5), Vector2(w, h))

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var c := cell()
		var b := box()
		var x0 := b.position.x + LABEL_W
		var y0 := b.position.y + 60.0
		draw_rect(Rect2(b.position, Vector2(b.size.x, 56.0)), Color(0, 0, 0, 0.55))
		draw_string(font, b.position + Vector2(10.0, 24.0), title, HORIZONTAL_ALIGNMENT_LEFT,
			-1.0, 20, Color.WHITE)
		for k in 3:
			draw_string(font, Vector2(x0 + c.x * float(k), b.position.y + 50.0), HEADS[k],
				HORIZONTAL_ALIGNMENT_CENTER, c.x, 16, Color.WHITE)
		var inks := [CastNet.AIM_OK, CastNet.AIM_NO, CastNet.AIM_FAR]
		for r in rows.size():
			var row: Dictionary = rows[r]
			var y := y0 + c.y * (float(r) + 0.5)
			draw_rect(Rect2(Vector2(b.position.x, y - 14.0), Vector2(LABEL_W - 10.0, 24.0)),
				Color(0, 0, 0, 0.55))
			draw_string(font, Vector2(b.position.x + 6.0, y + 4.0), row["name"],
				HORIZONTAL_ALIGNMENT_LEFT, LABEL_W - 16.0, 15, Color.WHITE)
			for k in 3:
				var at := Vector2(x0 + c.x * (float(k) + 0.5), y)
				draw_set_transform(AimRing.snap(at))
				var t: float = row.get("t", -1.0)
				if t >= 0.0 and k == 0:
					var big: bool = row.get("big", false)
					var halo := CastNet._halo(t, CastNet.HALO_POP_GROW if big
						else CastNet.HALO_OK_GROW, CastNet.HALO_POP_THICK if big
						else CastNet.HALO_THICK, CastNet.HALO_POP_ALPHA if big
						else CastNet.HALO_OK_ALPHA)
					AimRing.draw_halo(self, CastNet.halo_span(span, halo.x), inks[k], int(halo.z), halo.w, halo.y)
				elif t >= 0.0 and k == 1:
					var halo := CastNet._halo(t, CastNet.HALO_NO_GROW, CastNet.HALO_THICK,
						CastNet.HALO_NO_ALPHA)
					AimRing.draw_halo(self, CastNet.halo_span(span, halo.x), inks[k], int(halo.z), halo.w, halo.y)
				AimRing.draw_ring(self, span, k, inks[k], int(row.get("phase", 0)))
				draw_set_transform(Vector2.ZERO)


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE_PATH)
	_main.set(&"autoload_save", false)
	# Under this node, not the root: a lake under the root wears the menu.
	add_child.call_deferred(_main)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames > 4000:
		_say("timed out")
		_finish()
		return
	if _main == null or not _main.is_inside_tree():
		return
	if _frames < 6:
		return
	if _frames == 6:
		_grid = _main.get(&"_grid")
		_net = _main.get(&"_net")
		get_viewport().warp_mouse(Vector2(8.0, 8.0))
		_net.pad_aim = Vector2(-1.0e6, -1.0e6)
		(_main.get_node(^"HUD") as CanvasLayer).visible = false
		_pose_water()
		# A warm-up first: the first pan from where the lake starts lands short.
		_jobs.append(["dirty", "small"])
		for size: String in SIZES:
			for water: String in WATERS:
				_jobs.append([water, size])
		_overlay = Sheet.new()
		_overlay.net = _net
		_overlay.z_as_relative = false
		_overlay.z_index = 60
		_overlay.rows = _rows()
		_main.add_child(_overlay)
		_start_job()
		return
	if _frames != _due:
		return
	_capture()
	_job += 1
	if _job >= _jobs.size():
		_finish()
		return
	_start_job()


func _rows() -> Array:
	return [
		{"name": "ring"},
		{"name": "big halo, a third in", "t": 0.33, "big": true, "phase": 4},
		{"name": "small halo, a third in", "t": 0.33, "phase": 8},
		{"name": "halos near their end", "t": 0.8, "big": true, "phase": 11},
	]


## Thin one region to murky and empty another to clean; the third is the fresh soup.
func _pose_water() -> void:
	for index in _grid.stacks.size():
		var tile := Vector2(_grid.tile_of(index))
		var off := tile - Iso.CENTRE
		if off.distance_to(WATERS["clean"]) < REGION:
			_grid.stacks[index].resize(0)
		elif off.distance_to(WATERS["murky"]) < REGION:
			var keep := int(round(float(_grid.stacks[index].size()) * MURKY_KEEP))
			_grid.stacks[index].resize(keep)
	_grid._rebuild()
	_main.call(&"_build_filth_map")
	for water: String in WATERS:
		var tile := Vector2i((Iso.CENTRE + WATERS[water]).round())
		var states := [0, 0, 0, 0, 0]
		for dy in range(-6, 7):
			for dx in range(-6, 7):
				var index := _grid.index_of(tile.x + dx, tile.y + dy)
				if index >= 0:
					states[_grid.water_state(index)] += 1
		_say("%s at tile %s: states clean..dirty %s" % [water, tile, states])


func _start_job() -> void:
	var water: String = _jobs[_job][0]
	var size: String = _jobs[_job][1]
	var tile: Vector2 = Iso.CENTRE + WATERS[water]
	var spot := Iso.tile_to_world(tile.x, tile.y)
	var radius: float = SIZES[size]
	if radius < 0.0:
		radius = float(_main.call(&"net_radius"))
	_overlay.span = Iso.tile_circle_extent(radius + CastNet.MOUTH_EDGE)
	_overlay.title = "%s water  ·  %s net (%.1f tiles)" % [water, size, radius]
	_overlay.position = (spot / Lake.ART_PIXEL).round() * Lake.ART_PIXEL
	_overlay.queue_redraw()
	var angler: Node2D = _main.get(&"_angler")
	_main.set(&"_pan", spot - angler.position)
	_main.set(&"_panning", true)
	var stops: Array = _main.call(&"_zoom_stops")
	var best: float = stops[0]
	for stop: float in stops:
		if absf(stop - Lake.VIEW_ZOOM) < absf(best - Lake.VIEW_ZOOM):
			best = stop
	_main.set(&"_view_zoom", best)
	_main.call(&"_push_zoom")
	_due = _frames + (HOLD * 3 if _job == 0 else HOLD)


func _capture() -> void:
	if _job == 0:
		return
	var img := get_viewport().get_texture().get_image()
	var to_image := get_viewport().get_final_transform() \
		* _overlay.get_global_transform_with_canvas()
	var box := _overlay.box()
	var a := to_image * box.position
	var b := to_image * box.end
	var rect := Rect2i(Vector2i(a.floor()), Vector2i((b - a).ceil())) \
		.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var crop := img.get_region(rect)
	crop.save_png(CROP % _jobs[_job])
	_crops.append(crop)
	var cam: Camera2D = _main.get_node(^"Camera")
	_say("%s %s: crop %s of %s, camera zoom %.3f, %.2f image px an art px" % [_jobs[_job][0],
		_jobs[_job][1], rect, img.get_size(), cam.zoom.x,
		to_image.x.length() * Lake.ART_PIXEL])


func _finish() -> void:
	if not _crops.is_empty():
		var per_row := WATERS.size()
		var widths: Array[int] = []
		var heights: Array[int] = []
		for r in range(0, _crops.size(), per_row):
			var w := 0
			var h := 0
			for k in range(r, mini(r + per_row, _crops.size())):
				w += _crops[k].get_width() + 8
				h = maxi(h, _crops[k].get_height())
			widths.append(w)
			heights.append(h + 8)
		var total_h := 0
		for h in heights:
			total_h += h
		var sheet := Image.create(widths.max(), total_h, false, Image.FORMAT_RGBA8)
		sheet.fill(Color(0.08, 0.08, 0.09))
		var y := 0
		for r in heights.size():
			var x := 0
			for k in range(r * per_row, mini((r + 1) * per_row, _crops.size())):
				var crop := _crops[k]
				crop.convert(Image.FORMAT_RGBA8)
				sheet.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i(x, y))
				x += crop.get_width() + 8
			y += heights[r]
		sheet.save_png(SHEET)
		_say("sheet %dx%d" % [sheet.get_width(), sheet.get_height()])
	var f := FileAccess.open(LOG, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_log) + "\n")
		f.close()
	get_tree().quit()


func _say(line: String) -> void:
	_log.append(line)
