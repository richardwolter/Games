extends Node
## The letter's snapshots: the game photographing itself for its own onboarding cards.
##
## Run it with the **desktop build, not `--headless`**, at a fixed step, then reimport:
##
##   <godot> --path . --fixed-fps 60 res://tools/shot_letter_art.tscn
##   <godot> --path . --headless --import
##
## Writes the stills `scripts/letter.gd` pins to its cards into `assets/letter/`, plus a
## contact sheet (`tools/last_letter_art.png`) and a log (`tools/last_letter_art.log`).
##
## **These are baked, and baked things drift** (2026-09-19, Richard's call over drawing the
## cards in code): a repainted aim ring, lake, shop or HUD means running this again. That is
## the whole cost of the cards showing the real game, and this file is what keeps it to one
## command. They carry the game's English UI as it stands; a language pass re-shoots them.
##
## **A pose is found, not written down.** Where the ring reads green, where it reads red and
## where a find floats are asked of the net and the grid each run, so a changed fill or a
## moved island does not leave the probe photographing empty water. What it could not find
## it says in the log and leaves the old still alone. Read the log.
##
## On a save of its own and under its own node, like every probe since `shot_ending`. The
## view is held from `_process` at priority 100 — after the lake's own, which would put the
## camera and the aim back — the way `tools/film_trailer.gd` does it.

const OUT := "res://assets/letter/%s.png"
const SHEET := "res://tools/last_letter_art.png"
const LOG := "res://tools/last_letter_art.log"
const SAVE := "user://probe_letter_art.save"

## Seconds a pose is held before it is photographed: the camera's ease, the first frames of
## a board, a ring's redraw.
const HOLD := 0.9
## Crops, in window pixels at 1920x1080. The letter draws each fitted to its card, so what
## matters here is the shape and that the subject fills it.
const RING_CROP := Vector2i(300, 210)
const FIND_CROP := Vector2i(220, 250)
## The wash room's is in design pixels: it is a crop of a board, not of the world.
const WASH_CROP := Vector2i(540, 390)
const BOARD_PAD := 8.0
## A board's title plank stands over its top edge by half its height; take it whole.
const BOARD_PLANK := 17.0
const BOARD_TOP := 250.0
const ROW_PAD := 6
## `shot_shed`'s room, in cells: bookcase and fridge on the wall, paintings, table and pot,
## chairs, sofa on rug, the hearth. Kept here rather than read from that probe, since a
## probe is a scene and not a library.
const SHED_LAYOUT := [
	[&"decor_bookcase_tall", 1, -4], [&"decor_fridge", 9, -4],
	[&"decor_painting_a", 14, -3], [&"decor_painting_b", 18, -4],
	[&"decor_kitchen_counter", 22, -2], [&"decor_stove", 32, -3],
	[&"decor_big_table", 4, 8], [&"decor_flower_pot", 6, 6], [&"decor_globe", 9, 5],
	[&"decor_dining_chair", 12, 10], [&"decor_dining_chair", 14, 10],
	[&"decor_pet_bed", 24, 14], [&"decor_big_rug", 20, 6], [&"decor_sofa", 22, 8],
	[&"decor_loveseat", 34, 8], [&"decor_fireplace", 30, 2],
]
const ROW_CONTEXT := 38.0
## The whole lake from the far stop, in window pixels: its piers and a rim of bank.
const LAKE_CROP := Vector2i(1900, 1000)
var _pre := 0

var _main: Node2D
var _net: CastNet
var _grid: LakeGrid
var _angler: Angler
var _camera: Camera2D
var _log: FileAccess
var _age := 0.0
var _step := 0
## Where the view and the aim are held, in the world; INF lets the lake have them.
var _look := Vector2.INF
var _aim := Vector2.INF
var _made: Array = []


func _ready() -> void:
	process_priority = 100
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_log = FileAccess.open(LOG, FileAccess.WRITE)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/letter"))
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE)
	_main.set(&"autoload_save", false)
	add_child(_main)


func _say(line: String) -> void:
	if _log != null:
		_log.store_line(line)
		_log.flush()


## After the lake's own `_process`: put the view and the aim where the pose wants them.
func _process(_delta: float) -> void:
	if _net == null:
		return
	_net.pad_aim = _aim if _aim != Vector2.INF else Vector2(-1.0e6, -1.0e6)
	_net.queue_redraw()
	if _look == Vector2.INF:
		return
	_main.set(&"_pan", _look - _angler.position)
	_main.set(&"_panning", true)
	_camera.position = _main.call(&"_clamped_view", _look)
	_main.call(&"_snap_camera")


func _physics_process(delta: float) -> void:
	_age += delta
	# A probe's safety may not depend on the probe working.
	if Time.get_ticks_msec() > 180000:
		_say("timed out at step %d" % _step)
		get_tree().quit(1)
		return
	if _age < HOLD:
		return
	_age = 0.0
	# The welcome card's still first (2026-09-24): the fresh lake whole, from the far stop,
	# before any pose thins or moves anything.
	if _pre == 0:
		_main.set(&"_in_menu", false)
		_net = _main.get(&"_net")
		_angler = _main.get(&"_angler")
		_camera = _main.get(&"_camera")
		_hud(false)
		_main.call(&"_zoom_by", 0.001)
		_look = Iso.tile_to_world(Iso.CENTRE.x, Iso.CENTRE.y)
		_pre = 1
		return
	if _pre == 1:
		_say("lake_whole at zoom %.3f" % float(_main.get(&"_view_zoom")))
		_crop_world("lake_whole", _look, LAKE_CROP)
		_look = Vector2.INF
		_main.set(&"_panning", false)
		_main.set(&"_pan", Vector2.ZERO)
		_pre = 2
		return
	match _step:
		0:
			_net = _main.get(&"_net")
			_grid = _main.get(&"_grid")
			_angler = _main.get(&"_angler")
			_camera = _main.get(&"_camera")
			_say("window %s" % str(DisplayServer.window_get_size()))
			_main.call(&"_zoom_by", 1000.0)
			# A little reach, so there is heavy water inside the ring's range to say no to.
			_main.set(&"net_range_level", 6)
			_main.call(&"_push_net_numbers")
			_hud(false)
			_pose_ring(true)
		1:
			_crop_world("net_catch", _aim, RING_CROP)
			_pose_ring(false)
		2:
			_crop_world("net_nothing", _aim, RING_CROP)
			# Past the rod: straight out from the angler, well beyond any level-6 line.
			var out := (_aim - _angler.position).normalized()
			_aim = _angler.position + out * Iso.TILE_W * 14.0
			_look = _aim
		3:
			_crop_world("net_far", _aim, RING_CROP)
			_pose_heavy()
		4:
			_crop_world("weight_heavy", _aim, RING_CROP)
			_pose_find()
		5:
			_crop_world("decor_find", _look, FIND_CROP, Vector2(0.5, 0.68))
			_aim = Vector2.INF
			_look = Vector2.INF
			_hud(true)
			_main.set(&"_panning", false)
			_main.set(&"_pan", Vector2.ZERO)
		6:
			# The HUD's corner plates reach the boards' title planks: the shop alone. The
			# shop is on the HUD layer itself, so it is the corner skin that goes, not the layer.
			(_main.get(&"_skin") as Control).visible = false
			_main.set(&"sludge", 1500.0)
			_main.call(&"_set_menu", true)
		7:
			_shoot_shop()
			_main.call(&"_set_menu", false)
			(_main.get(&"_skin") as Control).visible = true
			_furnish_shed()
		8:
			_shoot_shed()
			_main.call(&"_set_shed", false)
			_open_wash()
		9:
			# Sprayed until the find is about half out of its coat, however long that takes:
			# the card is a before-and-after in one picture. `WASH_MOST` is the way out.
			var washing: WashRoom = _main.get(&"_wash")
			_washed_for += HOLD
			if washing.stand().share_clean() < WASH_UNTIL and _washed_for < WASH_MOST:
				return
			_say("washed to %.2f in %.1f s" % [washing.stand().share_clean(), _washed_for])
			_spraying = false
		10:
			var room: WashRoom = _main.get(&"_wash")
			var piece := room.stand().piece_box()
			# The stand's own coordinates: the piece's box is the stand's, not the room's.
			_crop_canvas("decor_wash", Rect2(
				room.stand().global_position + piece.get_center()
					- Vector2(WASH_CROP) * Vector2(0.5, 0.55),
				Vector2(WASH_CROP)
			))
			_main.call(&"_set_wash", false)
			_contact_sheet()
			if FileAccess.file_exists(SAVE):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
			_log.close()
			get_tree().quit()
			return
	_step += 1


func _hud(on: bool) -> void:
	(_main.get(&"_hud_layer") as CanvasLayer).visible = on


## Every water tile the net could be thrown at from where the angler stands, nearest first.
func _spots() -> Array:
	var here := _angler.tile_pos
	var out: Array = []
	for ty in range(int(here.y) - 12, int(here.y) + 13):
		for tx in range(int(here.x) - 12, int(here.x) + 13):
			if not Iso.in_lake(tx, ty):
				continue
			var at := Iso.tile_to_world(float(tx), float(ty))
			if _net.in_reach(at):
				out.append({"tile": Vector2i(tx, ty), "at": at,
					"far": here.distance_to(Vector2(tx, ty))})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["far"] < b["far"])
	return out


## A ring that reads green, or one that reads red, as near the angler as there is one.
func _pose_ring(green: bool) -> void:
	var best := 0
	for spot: Dictionary in _spots():
		var takes := _net.would_catch(spot["at"])
		if takes != green:
			continue
		# A green worth showing has something under it; a red worth showing is open water,
		# which is what "nothing to lift" means on a first cast.
		var index := _grid.index_of(spot["tile"].x, spot["tile"].y)
		if not green:
			if _grid.top_slot(index) >= 0:
				continue
			_aim = spot["at"]
			_look = _aim
			_say("red ring at tile %s" % str(spot["tile"]))
			return
		# The busiest green water in reach, not the nearest: by the island the fill is thin,
		# and a ring over one bottle cap in open water sells nothing.
		var busy := _crowd(spot["tile"])
		# `>=`: the spots come nearest first, so a tie goes to the one further out, where the
		# water is thicker with things.
		if _grid.top_slot(index) >= 0 and busy >= best:
			best = busy
			_aim = spot["at"]
			_look = _aim
	if green and best > 0:
		_say("green ring, %d pieces round it" % best)
		return
	_say("NO %s ring found in reach" % ("green" if green else "red"))


## How many of a tile and its eight neighbours hold something.
func _crowd(tile: Vector2i) -> int:
	var count := 0
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if not Iso.in_lake(tile.x + dx, tile.y + dy):
				continue
			if _grid.top_slot(_grid.index_of(tile.x + dx, tile.y + dy)) >= 0:
				count += 1
	return count


## A red ring over something that is there: a piece on top the net's Strength cannot lift.
func _pose_heavy() -> void:
	var power := int(_main.call(&"net_power"))
	for spot: Dictionary in _spots():
		if _net.would_catch(spot["at"]):
			continue
		var index := _grid.index_of(spot["tile"].x, spot["tile"].y)
		var top := _grid.top_slot(index)
		if top < 0:
			continue
		var def: TrashDef = _grid.defs[_grid.stacks[index][top]]
		if def.tier <= power or def.keepsake:
			continue
		_aim = spot["at"]
		_look = _aim
		_say("heavy: %s (tier %d) at tile %s" % [String(def.piece), def.tier, str(spot["tile"])])
		return
	_say("NO heavy piece found in reach")


## The find a new game floats by the island, under its beam. No ring: the card is about
## the shine.
func _pose_find() -> void:
	_aim = Vector2.INF
	for index in _grid.stacks.size():
		var top := _grid.top_slot(index)
		if top < 0:
			continue
		var def: TrashDef = _grid.defs[_grid.stacks[index][top]]
		if not def.keepsake:
			continue
		_look = _grid.surface_pos(index)
		_say("find: %s at tile %s" % [String(def.piece), str(_grid.tile_of(index))])
		return
	_say("NO floating find")


## The shop, open: the top of the net, boats and dogs boards one each, and the Strength
## row with the rows either side of it.
func _shoot_shop() -> void:
	var shop: ShopSkin = _main.get(&"_shop_skin")
	var boards: Dictionary = shop.get(&"_boards")
	for pair: Array in [[&"net", "upgrades_net"], [&"boat", "upgrades_boats"], [&"dog", "upgrades_dogs"]]:
		if not boards.has(pair[0]):
			_say("NO %s board on the shop" % pair[0])
			continue
		var box: Rect2 = boards[pair[0]]
		# The top of the board: title plank, head and the first row or two. The whole board is
		# three times as tall as a card's picture, and beside a sentence it was a strip.
		box = Rect2(box.position - Vector2(BOARD_PAD, BOARD_PLANK),
			Vector2(box.size.x + BOARD_PAD * 2.0, BOARD_TOP))
		_crop_canvas(String(pair[1]), Rect2(shop.global_position + box.position, box.size))
	var rows: Array = shop.rows
	var row_boxes: Array = shop.get(&"_row_boxes")
	var row_index: Array = shop.get(&"_row_index")
	for i in row_boxes.size():
		var row: Dictionary = rows[int(row_index[i])]
		if StringName(row.get("key", &"")) != &"net_strength":
			continue
		var box: Rect2 = row_boxes[i]
		# With the rows either side of it: alone the row is a strip three and a half times as
		# wide as it is tall, and pinned beside a photograph it took the whole card.
		_crop_canvas("weight_strength", Rect2(shop.global_position + box.position, box.size)
			.grow_individual(float(ROW_PAD), ROW_CONTEXT, float(ROW_PAD), ROW_CONTEXT))
		return
	_say("NO strength row on the shop")


## The shed, furnished the way `tools/shot_shed.gd` lays it out (the same list, in cells),
## with no dogs in it and every switchable piece on: the last card's picture of the room.
func _furnish_shed() -> void:
	var room: ShedRoom = _main.get_node(^"HUD/Shed/Pad/Lines/Room")
	var decor: Array = _main.get(&"decor")
	decor.clear()
	room.decor = decor
	for want: Array in SHED_LAYOUT:
		if room.sheets.has(want[0]):
			var at := Vector2i(int(want[1]), int(want[2])) * ShedRoom.CELL
			if not room.place(want[0], at):
				_say("shed: %s refused at %s,%s" % want)
	for k in room.decor.size():
		var row: Dictionary = room.decor[k]
		var piece := StringName(row["piece"])
		var on := room.sheets.switched(piece, int(row.get("view", 0)))
		if on >= 0 and not room.sheets.is_on(piece, int(row.get("view", 0))):
			row["view"] = on
	_main.call(&"_set_shed", true)
	room.dogs().clear()
	_say("shed furnished with %d pieces" % room.decor.size())


func _shoot_shed() -> void:
	var room: ShedRoom = _main.get_node(^"HUD/Shed/Pad/Lines/Room")
	var box: Rect2 = (room.call(&"_shed_rect") as Rect2).grow(6.0)
	_crop_canvas("decor_shed", Rect2(room.global_position + box.position, box.size))


## A find on the stand, and the jet left running on it.
func _open_wash() -> void:
	var sheets: Sheets = _main.get(&"_sheets")
	var waiting: Array = _main.get(&"unwashed")
	for name in ["decor_loveseat", "decor_lamp", "decor_pet_bed"]:
		if sheets.has(StringName(name)) and not waiting.has(name):
			waiting.append(name)
	_main.set(&"sludge", 500.0)
	_main.call(&"_set_wash", true)
	var room: WashRoom = _main.get(&"_wash")
	for name: String in waiting:
		if room.pick(StringName(name)):
			_say("washing %s" % name)
			break
	_spraying = true


const WASH_UNTIL := 0.5
const WASH_MOST := 40.0
var _washed_for := 0.0
var _spraying := false
var _sweep := 0.0


## The jet is driven from the idle tick rather than from a step, so it runs every frame
## between the steps that wait for it.
func _physics_spray(delta: float) -> void:
	if not _spraying:
		return
	var room: WashRoom = _main.get(&"_wash")
	if room == null or room.stand() == null:
		return
	_sweep += delta
	var box := room.stand().piece_box()
	# The left half only, top to bottom: half clean, half filthy is the picture.
	room.stand().spray(box.position + box.size * Vector2(
		0.08 + 0.42 * absf(sin(_sweep * 7.0)), 0.5 + 0.5 * sin(_sweep * 0.9)
	), true)


func _enter_tree() -> void:
	get_tree().physics_frame.connect(func() -> void: _physics_spray(1.0 / 60.0))


## A crop about a world point. `anchor` is where in the crop the point stands.
func _crop_world(name: String, at: Vector2, crop: Vector2i, anchor := Vector2(0.5, 0.5)) -> void:
	if at == Vector2.INF:
		_say("%-16s skipped: nothing posed" % name)
		return
	var on_canvas := _main.get_viewport().get_canvas_transform() * at
	_save(name, on_canvas, crop, anchor)


## A crop of a rectangle given in canvas (design) pixels.
func _crop_canvas(name: String, box: Rect2) -> void:
	var shot := get_viewport().get_texture().get_image()
	var scale := float(shot.get_width()) / get_viewport().get_visible_rect().size.x
	var region := Rect2i(Vector2i(box.position * scale), Vector2i(box.size * scale))
	region = region.intersection(Rect2i(Vector2i.ZERO, shot.get_size()))
	if region.size.x < 8 or region.size.y < 8:
		_say("%-16s skipped: off the window %s" % [name, str(box)])
		return
	_write(name, shot.get_region(region))


func _save(name: String, on_canvas: Vector2, crop: Vector2i, anchor: Vector2) -> void:
	var shot := get_viewport().get_texture().get_image()
	var scale := float(shot.get_width()) / get_viewport().get_visible_rect().size.x
	var corner := Vector2i(on_canvas * scale - Vector2(crop) * anchor)
	corner = corner.clamp(Vector2i.ZERO, shot.get_size() - crop)
	_write(name, shot.get_region(Rect2i(corner, crop)))


func _write(name: String, picture: Image) -> void:
	picture.convert(Image.FORMAT_RGB8)
	picture.save_png(ProjectSettings.globalize_path(OUT % name))
	_made.append({"name": name, "picture": picture})
	_say("%-16s %dx%d" % [name, picture.get_width(), picture.get_height()])


## Every still side by side on magenta, for judging the crops without opening nine files.
func _contact_sheet() -> void:
	var wide := 16
	var tall := 0
	for made: Dictionary in _made:
		var picture: Image = made["picture"]
		wide += picture.get_width() + 16
		tall = maxi(tall, picture.get_height())
	var sheet := Image.create(maxi(wide, 32), tall + 32, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.9, 0.0, 0.9))
	var x := 16
	for made: Dictionary in _made:
		var picture: Image = made["picture"]
		sheet.blit_rect(picture, Rect2i(Vector2i.ZERO, picture.get_size()), Vector2i(x, 16))
		x += picture.get_width() + 16
	sheet.save_png(ProjectSettings.globalize_path(SHEET))
