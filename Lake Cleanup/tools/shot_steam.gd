extends "res://tools/film_trailer.gd"
## The Steam store's re-shoot (2026-10-04, `/grill-me` with Richard), on the trailer's own
## machinery: every kept frame is a JPEG in `tools/film/<shot>/`, the edit cuts the clips,
## and the still is saved as PNGs beside them. English, 1920x1080, own save, own log
## (`tools/film/last_steam.log`).
##
##   godot --path . --fixed-fps 60 res://tools/shot_steam.tscn --log-file tools/film/steam_engine.log
##
## Desktop build, not --headless. `FILM_ONLY=s_west` shoots one by name. The shots:
##
##   s_west     a single gold net thrown far off the west beach; the camera drifts out with
##              it, the bag comes home full (the count turns its pale red) and leaves a clean
##              spot behind. HUD on.
##   s_beauty   the trailer's grime to beauty (`t2_beauty`), kept from the wave's first frame.
##   s_tornado  no nets: the funnel circles the island over a mostly grimy lake with a big
##              whirl, flinging pieces as it goes; the camera follows it. HUD off.
##   s_bignet   the still: one plain net at full Width thrown north, caught mid-flight. HUD on.

const TornadoScript := preload("res://scripts/tornado.gd")

## The run the store shows (the HUD's figures).
const MONEY := 18450.0
const LIFE_SHARE := 0.3
const STEAM_APART := 70.0

# --- s_west ---------------------------------------------------------------------------------
## West on the screen is tile (-1, 1). The throw: how far, and how much of the lake is
## cleaned (almost none: the soup is what fills the bag).
const WEST := Vector2(-1.0, 1.0)
const WEST_TILES := 14.0
const WEST_CLEAN := 0.08
## What the net leaves under its mouth taken off the water, so a clean spot shows once the
## catch patch closes (the old clip's rule).
const WEST_EMPTY := 1.25
## Frames after the settle the net is thrown on; frames kept in all.
const WEST_THROW := 90
const WEST_SECONDS := 13.0
## The camera: where it rests before the throw (share of the way to the landing), the most
## it leans out with the net, the least it comes back on the haul, and how fast it eases.
const WEST_LEAN_REST := 0.25
const WEST_LEAN_OUT := 0.7
const WEST_LEAN_BACK := 0.45
const WEST_EASE := 4.0
var _west_from := Vector2.ZERO
var _west_land := Vector2.ZERO
var _west_cam := Vector2.ZERO
var _west_lean := 0.0

# --- s_beauty -------------------------------------------------------------------------------
## The wave and two seconds of the finished lake after it.
const BEAUTY_SECONDS := 12.0

# --- s_tornado ------------------------------------------------------------------------------
## Mostly grimy (2026-10-04, Richard: "around 75%").
const ORBIT_CLEAN := 0.25
## Tiles past the island's beach the funnel runs, where it starts, and one lap's seconds.
const ORBIT_OUT := 5.0
const ORBIT_FROM := 0.6
const ORBIT_LAP := 14.0
## Pieces in the whirl, topped up by hand past the event's own cap, and how often.
const ORBIT_CARRY := 60
const ORBIT_FEED_EVERY := 0.035
## Kept from this long after touchdown, for this long.
const ORBIT_KEEP_FROM := 3.5
const ORBIT_SECONDS := 14.0
## The camera sits this far above the funnel's foot, for its height.
const ORBIT_LIFT := 120.0
var _orbit_fed := 0.0
var _orbit_said := false

# --- s_bignet -------------------------------------------------------------------------------
const NORTH := Vector2(-1.0, -1.0)
const BIG_TILES := 11.0
const BIG_CLEAN := 0.74
const BIG_SEED := 23
const BIG_THROW := 60
## Mid-flight PNGs: every other frame from the throw for this many.
const BIG_SHOTS := 24
var _big_saved := 0


func _init() -> void:
	SAVE_PATH = "user://shot_steam.save"
	LOG_PATH = "res://tools/film/last_steam.log"


func _setup() -> void:
	super._setup()
	_main.set(&"net_strength_level", 3)
	_main.set(&"net_width_level", 18)
	_main.set(&"net_range_level", 10)
	_main.set(&"net_hold_level", 6)
	_main.set(&"reel_level", 8)
	_main.set(&"sludge", MONEY)
	_main.call(&"_push_net_numbers")


func _plan() -> void:
	_shots = [
		["s_west", WEST_SECONDS, _pose_west, _run_west],
		["s_beauty", BEAUTY_SECONDS, _pose_beauty, _run_beauty],
		["s_tornado", ORBIT_SECONDS, _pose_orbit, _run_orbit],
		["s_bignet", 2.0, _pose_big, _run_big],
	]
	var only := OS.get_environment("FILM_ONLY")
	if only != "":
		var names := only.split(",")
		_shots = _shots.filter(func(s: Array) -> bool: return s[0] in names)


## The beauty is kept from the wave's first frame (Richard: "start to clean up earlier"); the
## tornado from once its funnel is down and its whirl full.
func _settle_of(name: String) -> int:
	match name:
		"s_beauty":
			return SETTLE + BEAUTY_LEAD
		"s_tornado":
			return SETTLE + int(round((TornadoScript.BREW + ORBIT_KEEP_FROM) * _fps))
	return SETTLE


## The whole HUD, buttons and all, as a player sees it.
func _hud_on() -> void:
	(_main.get_node(^"HUD") as CanvasLayer).visible = true
	var skin: HudSkin = _main.get(&"_skin")
	skin.visible = true
	skin.plates_only = false


## The angler on the island's shore on `dir`'s bearing, facing out along it.
func _stand_on(dir: Vector2) -> void:
	var bearing := atan2(dir.y, dir.x)
	_angler.stand_at(Iso.world_to_tile(Iso.island_point(bearing, -0.6)))
	_angler.facing = dir.normalized()


## Life on the cleaned water: the shot's own share, every plant already grown, spread out.
func _life(k: int) -> void:
	if k == -30:
		var flora: Flora = _main.get(&"_flora")
		flora.reset()
		flora.refresh(LIFE_SHARE)
		(_main.get(&"_wildlife") as Wildlife).refresh(LIFE_SHARE, _main.get(&"_clean_tiles"), 0.7)
	if k == -29:
		_flora_grown()
	if k == -24:
		_spread_life(STEAM_APART)
	if k >= -29:
		_hold_still()


## Pigeons near `spots` (tiles) sent off: a netted one pops its head in over the shot.
func _birds_off(spots: Array) -> void:
	var flock: Flock = _main.get(&"_flock")
	for i in range(flock.birds.size() - 1, -1, -1):
		var bird: Dictionary = flock.birds[i]
		var at := Iso.world_to_tile(bird["at"])
		var to := Iso.world_to_tile(bird.get("to", bird["at"]))
		for spot: Vector2 in spots:
			if at.distance_to(spot) < 8.0 or to.distance_to(spot) < 8.0:
				flock.birds.remove_at(i)
				break


## The pack about the angler as the old clip had it: one sat, one asleep, one off fetching.
func _place_pack(dir: Vector2) -> void:
	var flip := func(v: Vector2) -> Vector2: return Vector2(v.y, v.x)
	var dogs: Array = _main.get(&"_dogs")
	for i in dogs.size():
		var dog: Node2D = dogs[i]
		dog.set(&"_mood_left", 600.0)
		match i:
			0:
				dog.set(&"tile_pos", _angler.tile_pos + flip.call(Vector2(0.0, 1.4)))
				dog.set(&"_state", 0)
			1:
				dog.set(&"tile_pos", _angler.tile_pos + flip.call(Vector2(-1.8, 0.7)))
				dog.set(&"_state", 8)
			2:
				dog.set(&"tile_pos", _angler.tile_pos + flip.call(Vector2(0.5, -0.9)))
			_:
				dog.set(&"tile_pos", Iso.ISLAND_CENTRE + flip.call(Vector2(-4.0, 2.0)))
				dog.set(&"_state", 2)


# --- s_west ---------------------------------------------------------------------------------

func _pose_west() -> void:
	_hide_boats()
	_pack()
	_levels(14, 6, 10, 8, 3)
	_main.set(&"sludge", MONEY)
	_stand_on(WEST)
	var land := _angler.tile_pos + WEST.normalized() * WEST_TILES
	thin_seed = 11
	_thin(WEST_CLEAN, [land], 4.5)
	_stock(land, 3.0, 4)
	_drop_finds()
	if not _net.touched_down.is_connected(_empty_under):
		_net.touched_down.connect(_empty_under)
	_place_pack(WEST)
	_zoom(3)
	_phase = DAY_PHASE
	_west_from = Iso.tile_to_world(_angler.tile_pos.x, _angler.tile_pos.y)
	var to := _target(WEST, WEST_TILES)
	_west_land = to if to != Vector2.INF else _west_from
	_say("  west: angler %s, landing %s (%.1f tiles), range %.1f" % [str(_angler.tile_pos),
			str(Iso.world_to_tile(_west_land)), Iso.world_to_tile(_west_land).distance_to(_angler.tile_pos),
			_net.range_tiles])
	_west_lean = WEST_LEAN_REST
	_west_cam = _west_from.lerp(_west_land, _west_lean)
	_hold = _west_cam + Vector2(0.0, 20.0)


func _run_west(f: int) -> void:
	var k := f - SETTLE
	_hud_on()
	_dress_island()
	_life(k)
	if k == -20:
		_birds_off([Iso.world_to_tile(_west_land)])
	if k == WEST_THROW:
		_cast(WEST, WEST_TILES, true, false)
		_say("  west: thrown on kept frame %d" % _kept)
	# The camera drifts out with the net and back a little with the haul, eased, so it trails.
	var want := WEST_LEAN_REST
	if k >= WEST_THROW and _net.state != CastNet.State.IDLE:
		var span := _west_from.distance_to(_west_land)
		var out := _west_from.distance_to(_net.world_pos()) / maxf(span, 1.0)
		want = clampf(out * WEST_LEAN_OUT, WEST_LEAN_REST, WEST_LEAN_OUT)
		if _net.state == CastNet.State.REELING:
			want = maxf(want, WEST_LEAN_BACK)
	elif k > WEST_THROW:
		want = WEST_LEAN_BACK
	_west_lean = lerpf(_west_lean, want, 1.0 - exp(-WEST_EASE / _fps))
	_hold = _west_from.lerp(_west_land, _west_lean) + Vector2(0.0, 20.0)
	if k > WEST_THROW and k % 30 == 0:
		var count: Node = _main.get(&"_haul_count")
		if count != null:
			_say("  west: kept %d, net %d, count %s/%s" % [_kept, _net.state, str(count.get(&"_shown_count")),
					str(count.get(&"room"))])


## Everything left on the water under a landed net's mouth, taken the way the net takes.
func _empty_under(at: Vector2, mouth: float) -> void:
	if _shots[_shot][0] != "s_west":
		return
	var reach := mouth * WEST_EMPTY
	var taken := 0
	for index in _grid.stacks.size():
		if _grid.stacks[index].is_empty() or _grid.dry[index] == 1:
			continue
		var tile: Vector2i = _grid.tile_of(index)
		var off := Iso.tile_to_world(tile.x, tile.y) - at
		if Vector2(off.x, off.y * 2.0).length() > reach:
			continue
		while not _grid.stacks[index].is_empty():
			var def_index := _grid.take(index, _grid.stacks[index].size() - 1)
			if not _grid.defs[def_index].keepsake:
				_main.call(&"_on_net_caught", def_index)
			taken += 1
	_say("  west: emptied under the net: %d (catch %d of %d)" % [taken, _net.catch.size(),
			_net.hold + _net.luck_hold])


# --- s_tornado ------------------------------------------------------------------------------

func _pose_orbit() -> void:
	_hide_boats()
	_unpack()
	_drop_finds()
	_levels(18, 6, 18, 14)
	_main.set(&"sludge", MONEY)
	thin_seed = 51
	_thin(ORBIT_CLEAN)
	_stand_on(Vector2(1.0, 1.0))
	var t: Node = _main.get(&"_tornado")
	t.call(&"start", ORBIT_FROM)
	t.set(&"_grow", ORBIT_OUT)
	t.set(&"_base", Iso.island_point(ORBIT_FROM, ORBIT_OUT))
	t.set(&"_base_was", t.get(&"_base"))
	_orbit_fed = 0.0
	_orbit_said = false
	_zoom(3)
	_phase = DAY_PHASE
	_hold = (t.call(&"base") as Vector2) - Vector2(0.0, ORBIT_LIFT)


func _run_orbit(f: int) -> void:
	_hud_off()
	var k := f - SETTLE
	_life(k)
	var t: Node = _main.get(&"_tornado")
	if not bool(t.call(&"active")):
		return
	var since: float = t.get(&"_t")
	# Round the island at a steady pace, one way, at one distance: the event's own wander
	# turns back now and then and runs in and out.
	var theta := ORBIT_FROM + TAU * maxf(since, 0.0) / ORBIT_LAP
	t.set(&"_theta", theta)
	t.set(&"_grow", ORBIT_OUT)
	if since >= 1.0 and since - _orbit_fed >= ORBIT_FEED_EVERY:
		_orbit_fed = since
		_feed_orbit(t)
	_spread_whirl(t)
	_hold = (t.call(&"base") as Vector2) - Vector2(0.0, ORBIT_LIFT)
	_angler.facing = (Iso.world_to_tile(t.call(&"base")) - _angler.tile_pos).normalized()
	_angler.call(&"_repaint")
	if not _orbit_said and _shot_frame >= _settle_of("s_tornado"):
		_orbit_said = true
		_say("  tornado: first kept frame, carrying %d, flung so far %d" % [int(t.call(&"carrying")), int(t.get(&"landed"))])
	if k % 120 == 0 and since > 0.0:
		_say("  tornado: t %.1f, carrying %d, in the air %d, landed %d" % [since, int(t.call(&"carrying")),
				(t.get(&"_flung") as Array).size(), int(t.get(&"landed"))])


## The trailer's feed, to this shot's bigger whirl.
func _feed_orbit(t: Node) -> void:
	if (t.get(&"_debris") as Array).size() >= ORBIT_CARRY:
		return
	_feed_tornado(t)


# --- s_bignet -------------------------------------------------------------------------------

func _pose_big() -> void:
	_hide_boats()
	_pack()
	_levels(20, 6, 10, 8, 3)
	_main.set(&"sludge", 12730.0)
	_stand_on(NORTH)
	var land := _angler.tile_pos + NORTH.normalized() * BIG_TILES
	thin_seed = BIG_SEED
	_thin(BIG_CLEAN, [land], 5.0)
	_drop_finds()
	_place_pack(Vector2(1.0, -1.0))
	_zoom(3)
	_phase = DAY_PHASE
	_hold = _between(NORTH, BIG_TILES, 0.5) + Vector2(0.0, 20.0)
	_big_saved = 0
	var dir := ProjectSettings.globalize_path("res://tools/film/s_bignet_png")
	DirAccess.make_dir_recursive_absolute(dir)
	for old in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(old))


func _run_big(f: int) -> void:
	var k := f - SETTLE
	_hud_on()
	_dress_island()
	_life(k)
	if k == -20:
		_birds_off([_angler.tile_pos + NORTH.normalized() * BIG_TILES])
	if k == BIG_THROW:
		_cast(NORTH, BIG_TILES)
	# The frame drawn last, every other one through the flight.
	if k > BIG_THROW and _big_saved < BIG_SHOTS and (k - BIG_THROW) % 2 == 1:
		var image := get_viewport().get_texture().get_image()
		image.save_png(ProjectSettings.globalize_path("res://tools/film/s_bignet_png/big_%02d.png" % _big_saved))
		_say("  bignet_%02d: net %d at %s" % [_big_saved, _net.state, str(Iso.world_to_tile(_net.world_pos()).round())])
		_big_saved += 1
	if _big_saved >= BIG_SHOTS:
		_end_at = _kept
