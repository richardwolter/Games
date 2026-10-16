extends "res://tools/shot_steam.gd"
## The store's stills, redone on the current build (2026-10-16, `/grill-me` with Richard):
## a new set covering the core loop, upgrades and luck, washing and the house, nature and
## events. HUD on in every still. One shot at a time, picked and critiqued by Richard.
##
##   godot --path . --fixed-fps 60 res://tools/shot_store.tscn --log-file tools/film/store_engine.log
##
## Desktop build, not --headless. `FILM_ONLY=st01` shoots one by name. Each still saves
## `SNAPS` PNGs `SNAP_EVERY` frames apart into `tools/film/store/<name>_<n>.png`, so there is
## a moment to pick from. Own save (`user://shot_store.save`), own log
## (`tools/film/last_store.log`).
##
##   st01  a new game's lake: the soup edge to edge, the neglected hut, the angler on the
##         beach with the dog beside him, the ferry at the island.
##   st02  mid-run: a big plain net landed on a thick pile up the screen and reeled home, the
##         count over the angler climbing, the line hanging in loops, the tidied hut.
##   st03  a ferry landing its hold in the wood pier's box, coins flying to the purse, a
##         second ferry coming in; the trailer's pier pose with the HUD on.
##   st04  the upgrades shop open mid-run: some rows maxed, some affordable, some greyed.
##   st05  late in a run: a gold lucky net and its double thrown together off the east
##         beach, the count over the angler in gold with its x2 tag, the cosy hut, the pack.
##   st06  the wash room: the white sofa half washed under the fan jet, the tray full of
##         finds waiting, the pack and the ferries in the view behind.
##   st09  a cleaned lake full of life: framed in turn on the capybaras, the peacock's island
##         and a duck brood, one PNG each, for Richard to pick the bay.

const SNAPS := 4
const SNAP_EVERY := 20
const STORE_DIR := "res://tools/film/store"
var _snapped := 0

# --- st01 -----------------------------------------------------------------------------------
## Where the angler stands (island-centre offset) and which way he looks; the camera sits
## this share of the way from the island's middle towards him, at zoom `ST01_ZOOM`.
const ST01_LOOK := Vector2(1.0, 1.0)
const ST01_ZOOM := 2


func _init() -> void:
	SAVE_PATH = "user://shot_store.save"
	LOG_PATH = "res://tools/film/last_store.log"


func _plan() -> void:
	_shots = [
		["st01", 1.4, _pose_st01, _run_st01],
		["st02", 6.0, _pose_st02, _run_st02],
		["st03", 16.0, _pose_st03, _run_st03],
		["st04", 3.0, _pose_st04, _run_st04],
		["st05", 8.0, _pose_st05, _run_st05],
		["st06", 30.0, _pose_st06, _run_st06],
		["st09", 40.0, _pose_st09, _run_st09],
		["st10", 30.0, _pose_st10, _run_st10],
	]
	var only := OS.get_environment("FILM_ONLY")
	if only != "":
		var names := only.split(",")
		_shots = _shots.filter(func(s: Array) -> bool: return s[0] in names)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(STORE_DIR))


func _settle_of(_name: String) -> int:
	return SETTLE + 60


## A PNG of the frame drawn last, numbered on.
func _snap_now(name: String, note: String = "") -> void:
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s_%d.png" % [STORE_DIR, name, _snapped]
	image.save_png(ProjectSettings.globalize_path(path))
	_say("  %s saved %s" % [path, note])
	_snapped += 1


## `SNAPS` PNGs of the frame drawn last, `SNAP_EVERY` apart, from the first kept frame.
func _snap_still(name: String) -> void:
	if _snapped >= SNAPS or _kept == 0 or _kept % SNAP_EVERY != 1:
		return
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s_%d.png" % [STORE_DIR, name, _snapped]
	image.save_png(ProjectSettings.globalize_path(path))
	_say("  %s saved" % path)
	_snapped += 1


# --- st01: the dirty start ------------------------------------------------------------------

func _pose_st01() -> void:
	_snapped = 0
	_unpack()
	_levels(0, 0, 0, 0, 0)
	_main.set(&"sludge", 50.0)
	_stand_on(ST01_LOOK)
	_sit_dog(Vector2(0.9, -0.6), false)
	_zoom(ST01_ZOOM)
	_phase = DAY_PHASE
	_hold = Iso.tile_to_world(Iso.ISLAND_CENTRE.x, Iso.ISLAND_CENTRE.y).lerp(
			Iso.tile_to_world(_angler.tile_pos.x, _angler.tile_pos.y), 0.4)
	_say("st01: hut stage %d, pieces %d" % [int(_main.get(&"house_stage")), _grid.piece_count()])


func _run_st01(_f: int) -> void:
	_hud_on()
	_snap_still("st01")


## A second dog sitting on the island's beach on `dir`'s bearing (tile space), looking out.
func _second_dog(dir: Vector2, left: bool) -> void:
	if _main.get(&"dog_count_level") < 1:
		_main.set(&"dog_count_level", 1)
		_main.call(&"_add_dog")
	var dog: Node2D = (_main.get(&"_dogs") as Array)[1]
	var bearing := atan2(dir.y, dir.x)
	dog.set(&"tile_pos", Iso.world_to_tile(Iso.island_point(bearing, -0.8)))
	dog.set(&"_state", Dog.State.SIT)
	dog.set(&"_mood_left", 600.0)
	dog.set(&"facing_left", left)


## The island's own plants grown in at `share` of their full density, whatever the water
## beside them says (2026-10-16, Richard: "a little bit more nature on isle"). Called on the
## frame `_life` refreshes the flora, before it snapshots what is grown.
func _isle_flora(share: float) -> void:
	var flora: Flora = _main.get(&"_flora")
	var ages: PackedFloat32Array = flora.get(&"_age")
	var ranks: PackedFloat32Array = flora.get(&"_rank")
	var grown := 0
	for k in flora.candidate_count():
		if ages[k] >= 0.0 or ranks[k] >= share * Flora.MOST:
			continue
		if not Iso.on_island_ground(flora.candidate(k)["tile"]):
			continue
		ages[k] = 1.0e6
		grown += 1
	flora.set(&"_age", ages)
	flora.set(&"_dirty", true)
	flora.queue_redraw()
	_say("  island plants grown: %d" % grown)


# --- st02: the big cast ---------------------------------------------------------------------
const ST02_DIR := Vector2(-1.0, -1.0)
const ST02_TILES := 12.0
const ST02_CLEAN := 0.3
## How thick the island's plants grow, as a share of their full density.
const ST02_ISLE := 0.9
const ST02_THROW := 30
## Snapped every `ST02_EVERY` frames from the landing, `ST02_SNAPS` of them.
const ST02_EVERY := 8
const ST02_SNAPS := 14
var _st02_landed := -1


func _pose_st02() -> void:
	_snapped = 0
	_st02_landed = -1
	_hide_boats()
	_unpack()
	_levels(18, 7, 10, 1, 3)
	_main.set(&"sludge", 3870.0)
	_stand_on(ST02_DIR)
	var land := _angler.tile_pos + ST02_DIR.normalized() * ST02_TILES
	thin_seed = 5
	_thin(ST02_CLEAN, [land], 5.5)
	_stock(land, 3.5, 3)
	_drop_finds()
	_sit_dog(Vector2(0.8, 0.6), false)
	_second_dog(Vector2(-1.0, 1.0), true)
	_zoom(3)
	_phase = DAY_PHASE
	_hold = _between(ST02_DIR, ST02_TILES, 0.5) + Vector2(0.0, 30.0)


func _run_st02(f: int) -> void:
	var k := f - SETTLE
	_hud_on()
	_dress_island()
	_life(k)
	if k == -30:
		_isle_flora(ST02_ISLE)
	if k == -20:
		_birds_off([_angler.tile_pos + ST02_DIR.normalized() * ST02_TILES])
	if k == ST02_THROW:
		_cast(ST02_DIR, ST02_TILES)
	if k > ST02_THROW and _net.state != CastNet.State.IDLE:
		var me := Iso.tile_to_world(_angler.tile_pos.x, _angler.tile_pos.y)
		_hold = _hold.lerp(me.lerp(_net.world_pos(), 0.5) + Vector2(0.0, 20.0), 0.08)
	if _st02_landed < 0 and k > ST02_THROW and _net.state == CastNet.State.REELING:
		_st02_landed = k
	if _st02_landed >= 0 and _snapped < ST02_SNAPS and (k - _st02_landed) % ST02_EVERY == 20 % ST02_EVERY and k - _st02_landed >= 20:
		_snap_now("st02", "net %d catch %d" % [_net.state, _net.catch.size()])
	if _snapped >= ST02_SNAPS:
		_end_at = _kept


# --- st03: the pier -------------------------------------------------------------------------
const ST03_EVERY := 3
const ST03_SNAPS := 16
var _st03_from := -1


func _pose_st03() -> void:
	_snapped = 0
	_st03_from = -1
	_pose_pier()


func _run_st03(f: int) -> void:
	_run_pier(f)
	_hud_on()
	if _st03_from < 0 and _pier_unloading:
		_st03_from = f
	if _st03_from >= 0 and _snapped < ST03_SNAPS and (f - _st03_from) % ST03_EVERY == 0:
		_snap_now("st03")
	if _snapped >= ST03_SNAPS:
		_end_at = _kept


# --- st04: the shop -------------------------------------------------------------------------
## Every track's level, a mid-run mix (key = the lake's level field).
const ST04_LEVELS := {
	&"net_width_level": 9, &"net_strength_level": 1, &"net_range_level": 12, &"reel_level": 20,
	&"net_hold_level": 3, &"boat_speed_level": 5, &"cargo_level": 3, &"boat_volley_level": 2,
	&"fleet_level": 1, &"dog_fetch_level": 2, &"dog_wait_level": 1, &"dog_strength_level": 1,
	&"dog_count_level": 3, &"recycle_bonus_level": 2, &"bird_worth_level": 8,
	&"lucky_haul_level": 4, &"double_cast_level": 2,
}


func _pose_st04() -> void:
	_snapped = 0
	_unpack()
	thin_seed = 9
	_thin(0.3)
	_drop_finds()
	for key: StringName in ST04_LEVELS:
		_main.set(key, ST04_LEVELS[key])
	_main.call(&"_push_net_numbers")
	_main.set(&"sludge", 2580.0)
	_zoom(3)
	_hold = Iso.tile_to_world(Iso.ISLAND_CENTRE.x, Iso.ISLAND_CENTRE.y)
	_hide_boats()
	(_main.get_node(^"HUD") as CanvasLayer).visible = true
	var skin: HudSkin = _main.get(&"_skin")
	skin.visible = true
	skin.plates_only = false
	_main.call(&"_set_menu", true)
	_phase = DAY_PHASE


func _run_st04(f: int) -> void:
	_dress_island()
	if _kept > 0 and _kept % 12 == 0 and _snapped < 12:
		_snap_now("st04")
	if _snapped >= 12:
		_main.call(&"_set_menu", false)
		_end_at = _kept


# --- st05: the gold double cast -------------------------------------------------------------
const ST05_DIR := Vector2(1.0, -1.0)
const ST05_TILES := 11.0
## The two nets' spots off the landing (tiles), one up the screen and one down it, so they
## sit side by side rather than on top of each other (2026-10-16, Richard).
const ST05_UP := Vector2(-1.6, -1.6)
const ST05_DOWN := Vector2(1.6, 1.6)
const ST05_CLEAN := 0.62
const ST05_THROW := 30
const ST05_EVERY := 5
const ST05_SNAPS := 16
var _st05_landed := -1


## `_life` at the shot's own share, and the island grown thick.
func _life_at(k: int, share: float) -> void:
	if k == -30:
		var flora: Flora = _main.get(&"_flora")
		flora.reset()
		flora.refresh(share)
		(_main.get(&"_wildlife") as Wildlife).refresh(share, _main.get(&"_clean_tiles"), 1.0 - share)
		_isle_flora(0.95)
	if k == -29:
		_flora_grown()
	if k == -24:
		_spread_life(STEAM_APART)
	if k >= -29:
		_hold_still()


func _pose_st05() -> void:
	_snapped = 0
	_st05_landed = -1
	_hide_boats()
	_pack()
	_levels(20, 8, 12, 2, 4)
	_main.set(&"lucky_haul_level", 10)
	_main.set(&"double_cast_level", 10)
	_main.set(&"sludge", 41380.0)
	_stand_on(ST05_DIR)
	var land := _angler.tile_pos + ST05_DIR.normalized() * ST05_TILES
	thin_seed = 17
	_thin(ST05_CLEAN, [land + ST05_UP, land + ST05_DOWN], 6.0)
	_stock(land + ST05_UP, 3.0, 3)
	_stock(land + ST05_DOWN, 3.0, 3)
	_drop_finds()
	_place_pack(ST05_DIR)
	_zoom(3)
	_phase = DAY_PHASE
	_hold = _between(ST05_DIR, ST05_TILES, 0.62) + Vector2(0.0, 30.0)


func _run_st05(f: int) -> void:
	var k := f - SETTLE
	_hud_on()
	_dress_island()
	_main.set(&"shed_stage_pin", 2)
	_life_at(k, ST05_CLEAN)
	if k == -20:
		_birds_off([_angler.tile_pos + ST05_DIR.normalized() * ST05_TILES])
	if k == ST05_THROW:
		_cast_pair(ST05_TILES, ST05_UP, ST05_DOWN)
	if _st05_landed < 0 and k > ST05_THROW and _net.state == CastNet.State.REELING:
		_st05_landed = k
	if k > ST05_THROW and _snapped < ST05_SNAPS and (k - ST05_THROW) % ST05_EVERY == 0:
		_snap_now("st05", "net %d catch %d" % [_net.state, _net.catch.size()])
	if _snapped >= ST05_SNAPS:
		_end_at = _kept


# --- st06: the wash room --------------------------------------------------------------------
const ST06_PIECE := &"decor_pk_white_sofa"
const ST06_WAITING := 8
## The jet sweeps the find in rows at this pace (canvas px a second), and the snaps start
## once this much of the coat is off, one every `ST06_EVERY` frames with the jet still on.
const ST06_PACE := 260.0
const ST06_FROM := 0.5
const ST06_EVERY := 6
const ST06_SNAPS := 8
var _st06_aim := Vector2.INF
var _st06_path: Array[Vector2] = []


func _pose_st06() -> void:
	_snapped = 0
	_st06_aim = Vector2.INF
	_st06_path = []
	_pack()
	while int(_main.get(&"fleet_level")) < 2:
		_main.set(&"fleet_level", int(_main.get(&"fleet_level")) + 1)
		_main.call(&"_add_boat")
	thin_seed = 21
	_thin(0.4)
	var waiting: Array = _main.get(&"unwashed")
	waiting.clear()
	waiting.append(String(ST06_PIECE))
	var sheets: Sheets = _main.get(&"_sheets")
	for name: String in sheets.names:
		if waiting.size() >= ST06_WAITING:
			break
		if name.begins_with("decor_pk_") and name != String(ST06_PIECE) and name != "decor_pk_bed":
			waiting.append(name)
	var hose := OS.get_environment("HOSE")
	_main.set(&"hose_level", int(hose) if hose != "" else 2)
	_main.set(&"sludge", 6420.0)
	_phase = DAY_PHASE
	_main.call(&"_set_wash", true)
	var wash: WashRoom = _main.get(&"_wash")
	_say("st06: picked %s" % str(wash.pick(ST06_PIECE)))


## The view behind spread out (2026-10-16, Richard): the hulls held at `ST06_HULLS` (lane,
## share across, way), the hounds resting at `ST06_DOGS` (share across, depth, facing left).
const ST06_HULLS := [[0, 0.3, -1.0], [1, 0.88, 1.0], [1, 0.43, -1.0]]
const ST06_DOGS := [[0.3, 0.55, false], [0.38, 0.0, true], [0.84, 0.15, true], [0.94, 0.75, true]]


func _st06_stage(wash: WashRoom) -> void:
	var back: WashBackdrop = wash.get(&"_backdrop")
	var hulls := back.hulls()
	for k in mini(hulls.size(), ST06_HULLS.size()):
		var hull: WashBackdrop.Hull = hulls[k]
		var at: Array = ST06_HULLS[k]
		hull.lane = int(at[0])
		hull.x = float(at[1]) * back.size.x
		hull.way = float(at[2])
		hull.wait = 0.0
	var dogs := back.dogs()
	for k in mini(dogs.size(), ST06_DOGS.size()):
		var dog: WashBackdrop.Hound = dogs[k]
		var at: Array = ST06_DOGS[k]
		dog.depth = float(at[1])
		dog.at = Vector2(float(at[0]) * back.size.x, back.call(&"_lawn_y", dog.depth))
		dog.to = dog.at
		dog.via = Vector2.INF
		dog.left = bool(at[2])
		if dog.rest <= 0.0 or dog.rest < 1000.0:
			dog.pose = &"sit" if k % 2 == 0 else &"idle"
		dog.rest = 1.0e6


## Rows down the find from its top, each across its drawn width, the nozzle sweeping.
func _st06_rows(stand: WashStand) -> Array[Vector2]:
	var solid: PackedByteArray = stand.get(&"_solid")
	var cols: int = stand.get(&"_cols")
	var rows: int = stand.get(&"_rows")
	var cell: float = stand.get(&"_cell")
	var origin: Vector2 = stand.get(&"_origin")
	var gap := maxi(int(stand.jet_radius() * float(WashStand.FINE) * 0.9), 1)
	var out: Array[Vector2] = []
	var left := true
	var y := gap / 3
	while y < rows:
		var lo := cols
		var hi := -1
		for cy in range(maxi(y - gap / 2, 0), mini(y + gap / 2 + 1, rows)):
			for cx in cols:
				if solid[cy * cols + cx] != 0:
					lo = mini(lo, cx)
					hi = maxi(hi, cx)
		if hi >= lo:
			var a := origin + (Vector2(lo, y) + Vector2(0.5, 0.5)) * cell
			var b := origin + (Vector2(hi, y) + Vector2(0.5, 0.5)) * cell
			out.append_array([a, b] if left else [b, a])
			left = not left
		y += gap
	return out


func _run_st06(f: int) -> void:
	_phase = DAY_PHASE
	(_main.get_node(^"HUD") as CanvasLayer).visible = true
	_dress_island()
	var wash: WashRoom = _main.get(&"_wash")
	if f % 60 == 0:
		_say("  st06 f %d wash %s open %s clean %.2f path %d" % [f, str(wash != null),
				str(_main.get(&"_wash_open")), wash.stand().share_clean() if wash != null else -1.0,
				_st06_path.size()])
	if wash == null:
		return
	var stand := wash.stand()
	_st06_stage(wash)
	if f < SETTLE:
		return
	if _st06_aim == Vector2.INF:
		_st06_path = _st06_rows(stand)
		if _st06_path.is_empty():
			return
		_st06_aim = _st06_path[0]
	if not _st06_path.is_empty():
		if _st06_aim.distance_to(_st06_path[0]) < 1.0:
			_st06_path.remove_at(0)
		if not _st06_path.is_empty():
			_st06_aim = _st06_aim.move_toward(_st06_path[0], ST06_PACE / 60.0)
	stand.spray(_st06_aim, true)
	var clean := stand.share_clean()
	if clean >= ST06_FROM and _snapped < ST06_SNAPS and f % ST06_EVERY == 0:
		_snap_now("st06", "clean %.2f" % clean)
	if _snapped >= ST06_SNAPS:
		_end_at = _kept


# --- st09: the clean bay --------------------------------------------------------------------
const ST09_CLEAN := 0.9
var _st09_spots: Array = []


func _pose_st09() -> void:
	_snapped = 0
	_st09_spots = []
	_hide_boats()
	_pack()
	_levels(20, 8, 12, 8, 4)
	_main.set(&"sludge", 52310.0)
	thin_seed = 29
	_thin(ST09_CLEAN)
	_drop_finds()
	_stand_on(Vector2(1.0, 1.0))
	_place_pack(Vector2(1.0, 1.0))
	_zoom(3)
	_phase = DAY_PHASE
	_hold = Iso.tile_to_world(Iso.ISLAND_CENTRE.x, Iso.ISLAND_CENTRE.y)


## The lake runs this many frames at `ST09_FAST` speed before the framing, so the bank's
## animals have walked out of the woods.
const ST09_RUN := 900
const ST09_FAST := 4.0


func _run_st09(f: int) -> void:
	var k := f - SETTLE
	_hud_on()
	_dress_island()
	_main.set(&"shed_stage_pin", 2)
	if k == -30:
		var flora: Flora = _main.get(&"_flora")
		flora.reset()
		flora.refresh(ST09_CLEAN, true)
		_isle_flora(1.0)
		_flora_grown()
		var wild: Wildlife = _main.get(&"_wildlife")
		wild.refresh(ST09_CLEAN, _main.get(&"_clean_tiles"), ST09_CLEAN, true)
		Engine.time_scale = ST09_FAST
	if k >= -29:
		_hold_still()
	if k < ST09_RUN:
		return
	if k == ST09_RUN:
		Engine.time_scale = 1.0
		_st09_stage()
	var j := k - ST09_RUN
	if j >= ST09_SETTLE and _snapped < ST09_SNAPS and (j - ST09_SETTLE) % 20 == 0:
		_snap_now("st09")
	if _snapped >= ST09_SNAPS:
		_end_at = _kept


## The bay staged round the capybara pair (2026-10-16): the pair where they are, bunnies and
## the fox on the grass either side, a duck brood on the water in front. Offsets in world px
## along the shore (`along`) and out over the water (`out`, negative is inland).
const ST09_SETTLE := 60
const ST09_SNAPS := 6
const ST09_PLACES := {
	&"capy": [[-25.0, 0.0], [30.0, -12.0]],
	&"bunny": [[-70.0, -45.0], [95.0, -60.0]],
	&"fox": [[150.0, -95.0]],
}
const ST09_DUCKS := Vector2(-60.0, 80.0)
## Frogs sat on the sand at the water's edge and turtles basking, the same offsets, `out`
## measured from the capybara; and the beach litter cleared within `ST09_TIDY` world px.
const ST09_FROGS := [[-130.0, 12.0], [40.0, 22.0], [170.0, 6.0]]
const ST09_TURTLES := [[-20.0, 28.0], [120.0, 16.0]]
const ST09_TIDY := 420.0


func _st09_stage() -> void:
	var wild: Wildlife = _main.get(&"_wildlife")
	var lead: Dictionary = {}
	for c: Dictionary in wild.get(&"_critters_on_land"):
		if c["kind"] == &"capy" and not bool(c.get("arriving", false)):
			lead = c
			break
	if lead.is_empty():
		_say("  st09: no capybara out")
		return
	var spot: Dictionary = lead["spot"]
	var out: Vector2 = spot["normal"]
	var along := Vector2(-out.y, out.x)
	# The shore point the pair lives off, on the sand: the pair is put back on it, whatever
	# trip it was on.
	var centre: Vector2 = (spot["land"] as Vector2) - out * 25.0
	var used := {&"capy": 0}
	for c: Dictionary in wild.get(&"_critters_on_land"):
		var kind: StringName = c["kind"]
		if not ST09_PLACES.has(kind) or String(c["zone"]) != "bank":
			continue
		var n := int(used.get(kind, 0))
		var places: Array = ST09_PLACES[kind]
		if n >= places.size():
			continue
		used[kind] = n + 1
		var at: Vector2 = centre + along * float(places[n][0]) + out * float(places[n][1])
		for key in ["at", "to", "home"]:
			c[key] = at
		c["arriving"] = false
		c["fade"] = 1.0
		c["path"] = []
		c["wet"] = false
		c["state"] = Wildlife.Land.SIT
		c["timer"] = 1.0e6
		c["facing"] = Flock.facing_of(at, centre)
	var broods: Array = wild.get(&"_broods")
	if not broods.is_empty():
		var b: Dictionary = broods[0]
		var water: Vector2 = centre + along * ST09_DUCKS.x + out * ST09_DUCKS.y
		for key in ["at", "to", "goal", "from"]:
			b[key] = water
		b["state"] = 1
		b["alt"] = 0.0
		b["timer"] = 1.0e6
		for kid: Dictionary in b["kids"]:
			kid["at"] = water
	var frogs: Array = wild.get(&"_frogs")
	for n in mini(frogs.size(), ST09_FROGS.size()):
		var f: Dictionary = frogs[n]
		var at: Vector2 = centre + along * float(ST09_FROGS[n][0]) + out * float(ST09_FROGS[n][1])
		f["at"] = at
		f["to"] = at
		f["from"] = at
		f["spot"] = spot
		f["land_at"] = at
		f["state"] = Wildlife.Frog.SIT
		f["on_pad"] = false
		f["timer"] = 1.0e6
		f["fade"] = 1.0
	var turtles: Array = wild.get(&"_turtles")
	for n in mini(turtles.size(), ST09_TURTLES.size()):
		var t: Dictionary = turtles[n]
		var at: Vector2 = centre + along * float(ST09_TURTLES[n][0]) + out * float(ST09_TURTLES[n][1])
		t["at"] = at
		t["to"] = at
		t["spot"] = spot
		t["state"] = Wildlife.Turtle.BASK
		t["timer"] = 1.0e6
		t["fade"] = 1.0
	for index in _grid.stacks.size():
		if _grid.stacks[index].is_empty():
			continue
		var tile: Vector2i = _grid.tile_of(index)
		if Iso.tile_to_world(tile.x, tile.y).distance_to(centre) > ST09_TIDY:
			continue
		while not _grid.stacks[index].is_empty():
			var def_index := _grid.take(index, _grid.stacks[index].size() - 1)
			if not _grid.defs[def_index].keepsake:
				_main.call(&"_on_net_caught", def_index)
	_zoom(4)
	_hold = centre + out * 30.0
	_say("  st09: staged at %s, %s" % [str(centre), str(used)])


# --- st10: the tornado ----------------------------------------------------------------------
## The trailer's tornado (funnel far off the east beach over a cleared ring, the whirl full)
## with the HUD on and the pack on the beach; its first net is snapped in flight.
const ST10_EVERY := 3
const ST10_SNAPS := 14
var _st10_thrown := -1


func _pose_st10() -> void:
	_snapped = 0
	_st10_thrown = -1
	_pose_tornado()
	_main.set(&"sludge", 23870.0)
	_pack()
	_place_pack(Vector2(1.0, -1.0))
	_zoom(2)


func _run_st10(f: int) -> void:
	_run_tornado(f)
	var t: Node = _main.get(&"_tornado")
	if bool(t.call(&"active")):
		_hold = _angler.position.lerp(t.call(&"base"), 0.5) - Vector2(0.0, 150.0)
	_hud_on()
	_dress_island()
	var k := f - SETTLE
	if _st10_thrown < 0 and _net.state == CastNet.State.FLYING:
		_st10_thrown = k
	if _st10_thrown >= 0 and _snapped < ST10_SNAPS and (k - _st10_thrown) % ST10_EVERY == 1:
		_snap_now("st10", "net %d" % _net.state)
	if _snapped >= ST10_SNAPS:
		_end_at = _kept
