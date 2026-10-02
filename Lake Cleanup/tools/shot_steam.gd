extends "res://tools/film_trailer.gd"
## Poses the Steam store screenshots, one at a time with Richard judging each (2026-10-02),
## on the trailer's own machinery, HUD on, English, 1920x1080. Each shot saves a run of
## candidate frames to `tools/film/steam/<shot>_<n>.png` and says in
## `tools/film/steam/last_steam.log` what was happening on each.
##
##   godot --path . --fixed-fps 60 res://tools/shot_steam.tscn --log-file tools/film/steam/engine.log
##
## Desktop build, not --headless. On a save of its own, under its own node. `FILM_ONLY=cast`
## shoots one by name.

const Style := preload("res://scripts/style.gd")
const DogArt := preload("res://scripts/dog_art.gd")

const STEAM_OUT := "res://tools/film/steam/%s_%02d.png"
## A shot saves every `EVERY` frames from the frame it asks for until it has `MOST`.
const EVERY := 2
const MOST := 24

## Shot 1, the cast: where the angler stands, which way and how far the gold net goes.
const CAST_STAND := Vector2(3.9, -3.3)
const CAST_TILES := 8.5
## The two nets' landings, off the straight throw: the gold one up the screen, the double's
## down it, apart enough that the two mouths do not overlap.
const CAST_UP := Vector2(-3.4, -3.4)
const CAST_DOWN := Vector2(3.9, 3.9)
## How much of the lake is cleaned, and how far round each landing the soup is kept.
const CAST_CLEAN := 0.86
## The clip on the west beach is cast on an almost grimy lake (2026-10-02, Richard) and
## leaves a clean spot: what the net does not lift is taken off the water under its mouth as
## it lands, out to `WEST_EMPTY` of the mouth, so the honest map lightens there once the
## catch patch closes. The clip runs long enough to see it.
const WEST_CLEAN := 0.08
const WEST_EMPTY := 1.25
const WEST_CLIP_FRAMES := 250
## The still differs from the clip (2026-10-02, Richard: not the exact same scene): a dirtier
## lake, pools laid out off another noise, a smaller hold and less money.
const STILL_CLEAN := 0.74
const STILL_SEED := 23
const STILL_HOLD := 4
const STILL_MONEY := 12730.0
const CAST_KEEP := 3.6
## The wildlife's share: some life on the clean water, not a crowd.
const CAST_LIFE := 0.3
## No two animals closer than this (world px): life spread over the shot, never a crowd
## (2026-10-02, Richard).
const LIFE_APART := 70.0
## The pier's box starts with a low heap and is kept at it until the hold lands, so the
## volley is seen stacking it up (2026-10-02, Richard).
const PIER_BOX_START := 8

var _from := -1
var _saved := 0
var _every := EVERY
var _most := MOST
## A filmed shot saves every frame as a JPEG into its own folder, for a clip.
var _film := false
## The cast mirrored to the island's west beach: tile offsets swap their two axes, which is
## a mirror across the screen's vertical.
var _west := false

## Shot 1 filmed on the west beach: the frames kept, from a beat before the throw through
## the haul landing in the crate.
const CLIP_FROM := 90
const CLIP_FRAMES := 180
## The throw, in frames after the settle: late enough for the meter and the purse to have
## eased onto the thinned lake, so a looping clip does not jump.
const THROW_STILL := 40
const THROW_FILMED := 120


func _init() -> void:
	SAVE_PATH = "user://shot_steam.save"
	LOG_PATH = "res://tools/film/steam/last_steam.log"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/film/steam"))
	super._ready()


## A run well under way: the levels the HUD and the shop would show around the late game.
func _setup() -> void:
	super._setup()
	TranslationServer.set_locale("en")
	Style.set_locale("en")
	_main.set(&"net_width_level", 18)
	_main.set(&"net_range_level", 10)
	_main.set(&"net_strength_level", 3)
	_main.set(&"net_hold_level", 6)
	_main.set(&"sludge", 18450.0)
	_main.call(&"_push_net_numbers")


func _plan() -> void:
	_shots = [
		["cast", 0.0, _pose_cast.bind(false), _run_cast],
		["cast_west", 0.0, _pose_cast.bind(true), _run_cast],
		["pier", 0.0, _pose_pier, _run_pier],
		["wash", 0.0, _pose_wash, _run_wash],
		["tornado", 0.0, _pose_tornado, _run_tornado],
		["dirty", 0.0, _pose_dirty, _run_dirty],
		["beauty", 0.0, _pose_beauty, _run_beauty],
	]
	var only := OS.get_environment("FILM_ONLY")
	if only != "":
		var names := only.split(",")
		_shots = _shots.filter(func(s: Array) -> bool: return s[0] in names)


## Every find out of the water: a cast that nets one puts its card over the action.
func _drop_finds() -> void:
	var dropped := 0
	for index in _grid.stacks.size():
		var stack: Array = _grid.stacks[index]
		for slot in range(stack.size() - 1, -1, -1):
			if _grid.defs[stack[slot]].keepsake:
				_grid.take(index, slot)
				dropped += 1
	_say("  finds dropped: %d" % dropped)


## `v` mirrored to the side the cast is on.
func _m(v: Vector2) -> Vector2:
	return Vector2(v.y, v.x) if _west else v


func _pose_cast(west: bool) -> void:
	_west = west
	_film = west
	# Narrower for the clip, where the two mouths spread wider as they land.
	_main.set(&"net_width_level", 13 if west else 16)
	_main.call(&"_push_net_numbers")
	_hide_boats()
	_pack()
	_stand(_m(CAST_STAND), _m(ACROSS))
	var land := _angler.tile_pos + _m(ACROSS).normalized() * CAST_TILES
	thin_seed = 11 if west else STILL_SEED
	_main.set(&"net_hold_level", 6 if west else STILL_HOLD)
	_main.set(&"sludge", 18450.0 if west else STILL_MONEY)
	_main.call(&"_push_net_numbers")
	_thin(WEST_CLEAN if west else STILL_CLEAN,
			[land + CAST_UP, land + CAST_DOWN, land, _dog_stick()], CAST_KEEP)
	_drop_finds()
	if west:
		for net: CastNet in [_net, _main.get(&"_net2") as CastNet]:
			if net != null and not net.touched_down.is_connected(_empty_under):
				net.touched_down.connect(_empty_under)
	_zoom(3)
	_hold = _between(_m(ACROSS), CAST_TILES, 0.5) + Vector2(0.0, 20.0)
	var dogs: Array = _main.get(&"_dogs")
	for i in dogs.size():
		var dog: Node2D = dogs[i]
		dog.set(&"_mood_left", 600.0)
		match i:
			0:
				dog.set(&"tile_pos", _angler.tile_pos + _m(Vector2(0.0, 1.4)))
				dog.set(&"_state", 0)
			1:
				dog.set(&"tile_pos", _angler.tile_pos + _m(Vector2(-1.8, 0.7)))
				dog.set(&"_state", 8)
			2:
				dog.set(&"tile_pos", _angler.tile_pos + _m(Vector2(0.5, -0.9)))
			_:
				dog.set(&"tile_pos", Iso.ISLAND_CENTRE + _m(Vector2(-4.0, 2.0)))
				dog.set(&"_state", 2)


## Shot 2, the piers: a ferry coming in to the wood pier bow on and throwing its hold into
## the box, a second one on its way in behind it.
const PIER_IN := 1.2
## The second ferry comes in from the north (up the screen is tile (-1, -1)), this far off.
const PIER_NORTH := 13.0
## Frames after the settle the ferries are let go on: the meter and the purse ease onto the
## thinned lake first.
const PIER_GO := 80
## The second ferry's pace, tiles a second: under way, foam and all, but not arriving.
const PIER_SLOW := 0.8
## A big hold poured at the Loading track's top (Richard: "a huge thick line of objects").
const PIER_HOLD := 64
const PIER_VOLLEY := 4


func _pose_pier() -> void:
	_film = false
	_west = false
	_hide_boats()
	_unpack()
	thin_seed = 37
	_thin(0.5)
	_drop_finds()
	_main.set(&"sludge", 9860.0)
	while int(_main.get(&"fleet_level")) < 1:
		_main.set(&"fleet_level", int(_main.get(&"fleet_level")) + 1)
		_main.call(&"_add_boat")
	_main.set(&"boat_speed_level", 2)
	_main.set(&"cargo_level", 8)
	_main.set(&"boat_volley_level", PIER_VOLLEY)
	_main.call(&"_push_boat_numbers")
	var yard: Yard = _main.get(&"_yard")
	var rubbish: Array = []
	var wood: Array = []
	for i in _grid.defs.size():
		var def: TrashDef = _grid.defs[i]
		if def.keepsake:
			continue
		rubbish.append(i)
		if def.material == TrashDef.Kind.WOOD:
			wood.append(i)
	while yard.held.size() < 118:
		yard.put(rubbish[_rng.randi_range(0, rubbish.size() - 1)])
	var pier: Dropoff = (_main.get(&"_dropoffs") as Array)[TrashDef.Kind.WOOD]
	var out := pier.axis.normalized()
	var boats: Array = _main.get(&"_boats")
	for k in boats.size():
		var boat: Boat = boats[k]
		boat.visible = true
		boat.auto_ferry = false
		boat.patrol = false
		var hold := PackedInt32Array()
		for i in PIER_HOLD:
			hold.append(wood[_rng.randi_range(0, wood.size() - 1)])
		boat.cargo = hold
		boat.tile_pos = (
			pier.berth + out * PIER_IN if k == 0
			else pier.berth + Vector2(-1.0, -1.0).normalized() * PIER_NORTH
		)
		boat.set(&"_route", [] as Array[int])
		boat.target = TrashDef.Kind.WOOD
		boat.state = Boat.State.DOCKED
		boat.moored = true
		boat.heading = -out if k == 0 else Vector2(1.0, 1.0).normalized()
	_zoom(3)
	var box := pier.drop_point()
	var far: Vector2 = (boats[1] as Boat).tile_pos
	_hold = box.lerp(Iso.tile_to_world(far.x, far.y), 0.45) + Vector2(-60.0, 0.0)
	_say("  pier: berth %s, out %s" % [str(pier.berth), str(out)])


## A tile direction as a screen direction, unit length.
func out_screen(dir: Vector2) -> Vector2:
	return Vector2(dir.x - dir.y, (dir.x + dir.y) * 0.5).normalized()


func _run_pier(f: int) -> void:
	var k := f - SETTLE
	_dress_island()
	if k == -24:
		_spread_life(LIFE_APART)
	# The wood pier's box holds a low heap, never drained, until the hold starts landing.
	var wood_pier: Dropoff = (_main.get(&"_dropoffs") as Array)[TrashDef.Kind.WOOD]
	if _from < 0 and wood_pier.held_count() < PIER_BOX_START:
		var woods: Array = []
		for i in _grid.defs.size():
			if not _grid.defs[i].keepsake and _grid.defs[i].material == TrashDef.Kind.WOOD:
				woods.append(i)
		while wood_pier.held_count() < PIER_BOX_START:
			wood_pier.put(woods[_rng.randi_range(0, woods.size() - 1)])
	if k == -29:
		_flora_grown()
	if k >= -29:
		_hold_still()
	if k == PIER_GO:
		var pier: Dropoff = (_main.get(&"_dropoffs") as Array)[TrashDef.Kind.WOOD]
		for each: Boat in _main.get(&"_boats"):
			each.moored = false
			each.set(&"_legs", each.call(&"_plan_legs", each.tile_pos, pier.berth))
			each.state = Boat.State.SAILING
		# The one on its way stays on its way: at the fleet's pace it reached the berth while
		# the first was still unloading.
		((_main.get(&"_boats") as Array)[1] as Boat).speed = PIER_SLOW
	var boat: Boat = (_main.get(&"_boats") as Array)[0]
	if _from < 0 and k > PIER_GO and boat.state == Boat.State.UNLOADING and bool(boat.get(&"_landing")):
		_say("  pier: unloading on frame %d" % k)
		_shoot(4, 24)


## Shot 3, the wash room: the white sofa half washed, a tray of finds waiting, the hose row
## affordable, and the backdrop staged: two ferries on their two lanes, the pack resting at
## three depths on the lawn, clear of the pallet and the tray.
const SOFA := &"decor_pk_white_sofa"
const WASH_WAITING := [
	&"decor_pk_white_sofa", &"decor_pk_grandfather_clock", &"decor_pk_kitchen_counter",
	&"decor_pk_fancy_bed", &"decor_pk_globe", &"decor_pk_file_cabinet", &"decor_pk_potted_tree",
	&"decor_pk_coffee_table",
]
## How much of the coat is off when the burst starts.
const WASH_AT := 0.5
## [share across the room, depth 0 far .. 1 near, pose, faces left] for each dog.
const WASH_DOGS := [
	[0.34, 0.08, &"laid", false],
	[0.82, 0.36, &"sit", true],
	[0.93, 0.78, &"sit", true],
]
## [lane, share across the room, way] for each hull: the near one in the clear water between
## the tray and the pallet, the far one small over on the right, clear of the dogs.
const WASH_HULLS := [[0, 0.88, -1.0], [1, 0.30, 1.0]]


func _pose_wash() -> void:
	_film = false
	_follow = null
	_hold = Vector2.INF
	_unpack()
	while int(_main.get(&"dog_count_level")) < WASH_DOGS.size() - 1:
		_main.set(&"dog_count_level", int(_main.get(&"dog_count_level")) + 1)
		_main.call(&"_add_dog")
	while int(_main.get(&"fleet_level")) < 1:
		_main.set(&"fleet_level", int(_main.get(&"fleet_level")) + 1)
		_main.call(&"_add_boat")
	_main.set(&"sludge", 6240.0)
	var waiting: Array = _main.get(&"unwashed")
	waiting.clear()
	for name: StringName in WASH_WAITING:
		waiting.append(String(name))
	_main.call(&"_set_wash", true)
	var room: WashRoom = _main.get(&"_wash")
	_say("  wash: picked %s, hose %s" % [str(room.pick(SOFA)), room.hose_label()])


func _stage_backdrop(room: WashRoom) -> void:
	var back := room.backdrop()
	var hulls := back.hulls()
	for k in mini(hulls.size(), WASH_HULLS.size()):
		var plan: Array = WASH_HULLS[k]
		hulls[k].lane = int(plan[0])
		hulls[k].x = back.size.x * float(plan[1])
		hulls[k].way = float(plan[2])
		hulls[k].wait = 0.0
	var dogs := back.dogs()
	for k in mini(dogs.size(), WASH_DOGS.size()):
		var plan: Array = WASH_DOGS[k]
		var dog: WashBackdrop.Hound = dogs[k]
		dog.depth = float(plan[1])
		dog.at = Vector2(back.size.x * float(plan[0]), back.call(&"_lawn_y", dog.depth))
		dog.to = dog.at
		dog.via = Vector2.INF
		dog.pose = plan[2] if DogArt.has(plan[2], dog.breed) else &"idle"
		dog.left = bool(plan[3])
		dog.rest = 1.0e6
		dog.bolting = false


func _run_wash(f: int) -> void:
	var room: WashRoom = _main.get(&"_wash")
	if room == null or f < SETTLE - 20:
		return
	if f == SETTLE - 20:
		_say("  wash: %d hulls, %d dogs in the backdrop" % [room.backdrop().hulls().size(), room.backdrop().dogs().size()])
	(_main.get(&"_flock") as Flock).set(&"_rethink", 1.0e9)
	_stage_backdrop(room)
	var box := room.stand().piece_box()
	var t := float(f - SETTLE + 20) / 60.0
	var across := absf(fmod(t / 0.9, 2.0) - 1.0)
	# Down the picture and back up again, so the jet keeps finding grime.
	var down := 0.12 + 0.8 * absf(fmod(t / (0.9 * 7.0), 2.0) - 1.0)
	room.stand().spray(box.position + box.size * Vector2(0.1 + 0.8 * across, down), true)
	if _from < 0 and room.stand().share_clean() >= WASH_AT:
		_say("  wash: %.2f clean on frame %d" % [room.stand().share_clean(), f])
		_shoot(3, 12)


## A piece out from the beach, beside the throw, for the third dog to swim for.
func _dog_stick() -> Vector2:
	return _angler.tile_pos + _m(Vector2(2.4, 1.6))


func _run_cast(f: int) -> void:
	var k := f - SETTLE
	_dress_island()
	if k == -24:
		_spread_life(LIFE_APART)
	if k == -30:
		var flora: Flora = _main.get(&"_flora")
		var wild: Wildlife = _main.get(&"_wildlife")
		# Only the plants the shot's share asks for: the lake's own refresh, off the real
		# clean share, had the open water carpeted in pad beds.
		flora.reset()
		flora.refresh(CAST_LIFE)
		wild.refresh(CAST_LIFE, _main.get(&"_clean_tiles"), 0.7)
	var throw := THROW_FILMED if _film else THROW_STILL
	if k == throw - 78:
		_send_one_dog()
	# Before the first kept frame: the plants full grown, no pigeon where a net will land.
	if k == -29:
		_flora_grown()
		_birds_off_landings()
	if k >= -29:
		_hold_still()
	if k == throw:
		_cast_pair()
	# The net's flight, every other frame from just after the throw to past the landing; or,
	# filmed, every frame from a beat before the throw to the catch in the crate.
	if _film and k == CLIP_FROM:
		_shoot(1, WEST_CLIP_FRAMES)
	elif not _film and k == 46:
		_shoot()


## The gold net up the screen and the double down it, each at its own spot rather than
## where `_double_spot` would put the second (on top of the first, at this width).
func _cast_pair() -> void:
	_main.call(&"_push_net_numbers")
	var land := _angler.tile_pos + _m(ACROSS).normalized() * CAST_TILES
	var one := land + CAST_UP
	var two := land + CAST_DOWN
	if _net.cast_to(Iso.tile_to_world(one.x, one.y)):
		_net.luck_power = 1
		_net.luck_hold = Lake.LUCKY_EXTRA
	else:
		_say("  gold net refused at %s" % str(one))
	var net2: CastNet = _main.get(&"_net2")
	if net2 == null or not net2.cast_to(Iso.tile_to_world(two.x, two.y)):
		_say("  double net refused at %s" % str(two))


## Shot 5, the tornado (2026-10-02, Richard): a waterspout with a crowd of pieces whirling
## round it, and a big net flying at it, caught just before it lands. The lake is mostly
## cleaned (the tornado comes past `Tornado.GATE`), with the soup kept round where it comes
## down so it has pieces to lift.
const TORN_ANGLE := -0.785
const TORN_CLEAN := 0.45
## A ring of water under the funnel emptied (tiles), so the whirl reads against clean water
## on a lake that is otherwise grimy (2026-10-02, Richard: "make sure there is contrast").
const TORN_CLEAR := 6.5
## Pieces whirling round it at once: past the event's own `CARRY_MOST`, topped up by hand
## (`_feed_tornado`) from the water under it. A probe's crowd; the game keeps fourteen.
const TORN_CARRY := 56
const TORN_FEED_EVERY := 2
## Seconds after touchdown the net is thrown, and frames after the throw the burst starts.
const TORN_CAST_AT := 9.0
const TORN_SHOOT_AFTER := 4
## The whirl spread wider and lower than the event's own, so the crowd reads under the cloud:
## each carried piece's band (share of the funnel's height) and margin (px off its wall).
const TORN_BAND := Vector2(0.06, 0.62)
const TORN_MARGIN := Vector2(30.0, 150.0)
## Where the net is aimed: short of the funnel by this share of its own mouth, so the far rim
## comes down just shy of the foot rather than the mesh landing over it.
const TORN_SHORT := 0.0
## The funnel is held at one spot, tiles out past the island's beach on `TORN_ANGLE`: left to
## wander it hugged the shore and the net had nowhere to land short of it.
const TORN_OUT := 13.0
## Zoomed out to take the island, the throw and the funnel in one frame.
const TORN_ZOOM := 2
var _torn_cast := false


func _pose_tornado() -> void:
	_film = false
	_west = false
	_hide_boats()
	_unpack()
	_main.set(&"net_width_level", 18)
	_main.set(&"net_range_level", 18)
	_main.set(&"net_hold_level", 6)
	_main.set(&"sludge", 21340.0)
	_main.call(&"_push_net_numbers")
	var t: Node = _main.get(&"_tornado")
	t.call(&"start", TORN_ANGLE)
	t.set(&"_grow", TORN_OUT)
	t.set(&"_base", Iso.island_point(TORN_ANGLE, TORN_OUT))
	t.set(&"_base_was", t.get(&"_base"))
	var foot := Iso.world_to_tile(t.call(&"base"))
	thin_seed = 51
	_thin(TORN_CLEAN, [], 7.0)
	_clear_round(foot, TORN_CLEAR)
	_drop_finds()
	_angler.stand_at(Iso.world_to_tile(Iso.island_point(TORN_ANGLE, -0.6)))
	_torn_cast = false
	_zoom(TORN_ZOOM)
	_hold = _torn_frame(t)


## The camera's middle: between the angler and the funnel, lifted for its height.
func _torn_frame(t: Node) -> Vector2:
	var base: Vector2 = t.call(&"base")
	return _angler.position.lerp(base, 0.5) - Vector2(0.0, 90.0)


func _run_tornado(f: int) -> void:
	var t: Node = _main.get(&"_tornado")
	var k := f - SETTLE
	if k == -29:
		_flora_grown()
	if k >= -29:
		_hold_still()
	if not bool(t.call(&"active")):
		return
	var since: float = t.get(&"_t")
	t.set(&"_theta", TORN_ANGLE)
	t.set(&"_grow", TORN_OUT)
	_hold = _torn_frame(t)
	if since >= 1.5 and f % TORN_FEED_EVERY == 0:
		_feed_tornado(t)
	_spread_whirl(t)
	# Nothing thrown out of the whirl: a fling lands on the cleared ring and dirties it.
	t.set(&"_fling_in", 1.0e9)
	if not _torn_cast and since >= TORN_CAST_AT and _net.state == CastNet.State.IDLE:
		_angler.stand_at(Iso.world_to_tile(Iso.island_point(TORN_ANGLE, -0.6)))
		var v: Vector2 = t.get(&"_velocity")
		var foot: Vector2 = t.call(&"base") + v * 0.35
		var way := (foot - _angler.position).normalized()
		var aim := foot - way * _net.open_extent() * TORN_SHORT
		_main.call(&"_cast_at", aim)
		_torn_cast = _net.state != CastNet.State.IDLE
		if _torn_cast: _say("  tornado: cast at %s, net %d, carrying %d" % [str(aim.round()), _net.state,
				int(t.call(&"carrying"))])
		if _torn_cast:
			_torn_shot_at = f + TORN_SHOOT_AFTER
	if _torn_cast and f == _torn_shot_at:
		_shoot(2, 30)


var _torn_shot_at := -1


## Every piece on the water within `reach` tiles of `tile` taken, the way the net takes.
func _clear_round(tile: Vector2, reach: float) -> void:
	var taken := 0
	for index in _grid.stacks.size():
		if _grid.stacks[index].is_empty() or _grid.dry[index] == 1:
			continue
		if (Vector2(_grid.tile_of(index)) + Vector2(0.5, 0.5)).distance_to(tile) > reach:
			continue
		while not _grid.stacks[index].is_empty():
			var def_index := _grid.take(index, _grid.stacks[index].size() - 1)
			if not _grid.defs[def_index].keepsake:
				_main.call(&"_on_net_caught", def_index)
			taken += 1
	_say("  cleared round the funnel: %d" % taken)


## Every carried piece, the event's own included, moved once onto the probe's wider, lower
## whirl.
func _spread_whirl(t: Node) -> void:
	for d: Dictionary in t.get(&"_debris") as Array:
		if d.has("spread"):
			continue
		d["spread"] = true
		d["band"] = _rng.randf_range(TORN_BAND.x, TORN_BAND.y)
		d["margin"] = _rng.randf_range(TORN_MARGIN.x, TORN_MARGIN.y)


## One more piece off the water near the funnel's foot into its whirl, in the event's own
## form (`Tornado._lift`), past its cap. The probe quits before anything is saved.
func _feed_tornado(t: Node) -> void:
	var debris: Array = t.get(&"_debris")
	if debris.size() >= TORN_CARRY:
		return
	var base: Vector2 = t.call(&"base")
	var centre := _grid.tile_at(base)
	if centre < 0:
		return
	var here := Iso.world_to_tile(base)
	var best := -1
	var best_d := INF
	for index: int in _grid.tiles_within(centre, TORN_CLEAR + 4.0):
		var st: PackedInt32Array = _grid.stacks[index]
		if st.is_empty() or _grid.dry[index] == 1:
			continue
		var def: TrashDef = _grid.defs[st[st.size() - 1]]
		if def.keepsake or def.tier > 3:
			continue
		var d := (Vector2(_grid.tile_of(index)) + Vector2(0.5, 0.5)).distance_to(here)
		if d < best_d:
			best = index
			best_d = d
	if best < 0:
		return
	var from: Vector2 = _grid.surface_pos(best)
	var def_index: int = _grid.take(best, _grid.top_slot(best))
	_main.call(&"_on_net_caught", def_index)
	var rel := from - base
	var circ := Vector2(rel.x, rel.y * 2.0)
	debris.append({
		"def_index": def_index, "def": _grid.defs[def_index], "state": "lift", "age": 0.0,
		"angle": atan2(circ.y, circ.x), "r0": circ.length(), "radius": circ.length(),
		"height": 0.0, "band": _rng.randf_range(0.22, 0.88), "margin": _rng.randf_range(6.0, 22.0),
		"seed": _rng.randf() * TAU, "whirl": _rng.randf_range(0.75, 1.35), "rot": _grid.tilt[best],
		"spin_rate": _rng.randf_range(-5.0, 5.0),
		"scale": 1.0, "alpha": 1.0, "local": rel, "front": rel.y > 0.0, "depth": rel.y,
		"ground": rel, "from_tile": best,
	})


## Shot 7, the start (2026-10-02, Richard): the lake as a new game finds it, every piece in
## the water, at the game's farthest zoom; the angler on the island's west shore looking out
## west, idle, a dog sat beside him looking the same way.
## West on the screen is tile (-1, 1); the island's west shore lies on that bearing.
const DIRTY_WEST := Vector2(-1.0, 1.0)
const DIRTY_DOG := Vector2(0.6, -0.2)


func _pose_dirty() -> void:
	_film = false
	_west = false
	_unpack()
	_drop_finds()
	_hide_boats()
	_main.set(&"sludge", 50.0)
	var bearing := atan2(DIRTY_WEST.y, DIRTY_WEST.x)
	_angler.stand_at(Iso.world_to_tile(Iso.island_point(bearing, -1.0)))
	_angler.facing = DIRTY_WEST.normalized()
	var dog: Node2D = (_main.get(&"_dogs") as Array)[0]
	dog.set(&"tile_pos", _angler.tile_pos + DIRTY_DOG)
	_zoom(1)
	_hold = Iso.tile_to_world(Iso.CENTRE.x, Iso.CENTRE.y)


func _run_dirty(f: int) -> void:
	var k := f - SETTLE
	if not _angler.facing.is_equal_approx(DIRTY_WEST.normalized()):
		_angler.facing = DIRTY_WEST.normalized()
	# The sheet is only redrawn on a change it notices itself; a facing set from outside is not one.
	_angler.call(&"_repaint")
	var dog: Node2D = (_main.get(&"_dogs") as Array)[0]
	dog.set(&"tile_pos", _angler.tile_pos + DIRTY_DOG)
	dog.set(&"_state", Dog.State.SIT)
	dog.set(&"_mood_left", 600.0)
	dog.set(&"facing_left", true)
	if k == 20:
		_shoot(6, 6)


## The last GIF, grime to beauty (2026-10-02, Richard): the island centred, the angler idle
## beside the crate, and the lake cleaned outwards from the island in a wave while the life
## comes back, the hut mends itself through its stages (off the meter, as in play) and the
## hive takes its colony. Filmed, every frame, no HUD.
## The wave: frames it takes, and how much the key's noise bends its front (tiles).
const BEAUTY_CLEAN := 600
const BEAUTY_WOBBLE := 6.0
## The share of the lake the wave takes: the last pieces, out on the far bank and out of the
## shot, are left so the run does not end and put the farewell over the picture.
const BEAUTY_MOST := 0.97
## When the hive's colony moves in, as a share of the wave.
const BEAUTY_HIVE_AT := 0.62
## The film: frames before the wave starts, and held after it ends.
const BEAUTY_LEAD := 40
const BEAUTY_TAIL := 150
## No two animals closer than this (world px), checked every so many frames.
const BEAUTY_APART := 80.0
const BEAUTY_SPREAD_EVERY := 20
## The angler beside the crate (screen left of it), the dog at his side: tile offsets from it.
const BEAUTY_STAND := Vector2(-0.9, 0.7)
const BEAUTY_DOG := Vector2(-1.0, 1.6)
## Water plants (pads, open beds) kept to the lowest-ranked share, so the cleaned water is
## dotted with them rather than carpeted (Richard: nothing overcrowded).
const BEAUTY_PADS := 0.3
## A hen and her ducklings flying in to the south of the shot once the water there is clean
## (Richard): when in the wave, and where (world px off the island's middle). The lake's own
## broods are held off so this is the one family.
const BEAUTY_DUCKS_AT := 0.55
const BEAUTY_DUCKS := Vector2(140.0, 190.0)
var _beauty_ducks := false
var _beauty_order: Array = []
var _beauty_key: Array = []
var _beauty_next := 0


func _pose_beauty() -> void:
	_film = true
	_west = false
	_hide_boats()
	_unpack()
	_drop_finds()
	_main.set(&"shed_stage_pin", -1)
	(_main.get(&"_hive") as Hive).set_stage(Hive.Stage.EMPTY)
	var yard: Yard = _main.get(&"_yard")
	var crate := Iso.world_to_tile(yard.position)
	_angler.stand_at(crate + BEAUTY_STAND)
	_angler.facing = Vector2(1.0, 1.0).normalized()
	var dog: Node2D = (_main.get(&"_dogs") as Array)[0]
	dog.set(&"tile_pos", crate + BEAUTY_DOG)
	var rubbish: Array = []
	for i in _grid.defs.size():
		if not _grid.defs[i].keepsake:
			rubbish.append(i)
	while yard.held.size() < Yard.CRATE_FULL + 6:
		yard.put(rubbish[_rng.randi_range(0, rubbish.size() - 1)])
	# Every tile holding anything, ordered by how far out of the island it lies, the front
	# bent by a coarse noise so the clean water spreads in lobes rather than a ring.
	_noise.seed = 77
	_noise.frequency = 0.06
	var pairs: Array = []
	for index in _grid.stacks.size():
		if _grid.stacks[index].is_empty():
			continue
		var tile := Vector2(_grid.tile_of(index)) + Vector2(0.5, 0.5)
		var key := Iso.past_shelf(tile) + _noise.get_noise_2d(tile.x, tile.y) * BEAUTY_WOBBLE
		pairs.append([key, index])
	pairs.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	_beauty_order = pairs.map(func(p: Array) -> int: return p[1])
	_beauty_key = pairs.map(func(p: Array) -> float: return p[0])
	_beauty_next = 0
	_zoom(3)
	_hold = Iso.tile_to_world(Iso.ISLAND_CENTRE.x, Iso.ISLAND_CENTRE.y) + Vector2(0.0, 10.0)
	var day: DayCycle = _main.get(&"_day")
	day.phase = 0.35


func _run_beauty(f: int) -> void:
	var k := f - SETTLE
	(_main.get_node(^"HUD") as CanvasLayer).visible = false
	(_main.get(&"_day") as DayCycle).phase = 0.35
	_angler.facing = Vector2(1.0, 1.0).normalized()
	_angler.call(&"_repaint")
	var dog: Node2D = (_main.get(&"_dogs") as Array)[0]
	var crate := Iso.world_to_tile((_main.get(&"_yard") as Yard).position)
	dog.set(&"tile_pos", crate + BEAUTY_DOG)
	dog.set(&"_state", Dog.State.LOUNGE)
	dog.set(&"_mood_left", 600.0)
	dog.set(&"facing_left", true)
	if k == -10:
		_shoot(1, BEAUTY_LEAD + BEAUTY_CLEAN + BEAUTY_TAIL)
	var t := clampf(float(k - BEAUTY_LEAD) / float(BEAUTY_CLEAN), 0.0, 1.0)
	if k >= BEAUTY_LEAD:
		# Slow to start and slow to finish, so the first bay opening and the last shore
		# clearing both read.
		# Paced by distance, not by count: the count grows with the square of the reach, and
		# by count the water in the shot was clean a third of the way in. The square on the
		# clock spends the start near the island, in view, and runs off-screen at the end.
		var last := int(BEAUTY_MOST * float(_beauty_order.size())) - 1
		var reach: float = float(_beauty_key[last]) * t * t
		var upto := _beauty_next
		while upto <= last and float(_beauty_key[upto]) <= reach:
			upto += 1
		while _beauty_next < upto:
			var index: int = _beauty_order[_beauty_next]
			_beauty_next += 1
			while not _grid.stacks[index].is_empty():
				var def_index := _grid.take(index, _grid.stacks[index].size() - 1)
				if not _grid.defs[def_index].keepsake:
					_main.call(&"_on_net_caught", def_index)
	var hive: Hive = _main.get(&"_hive")
	(_main.get(&"_wildlife") as Wildlife).set(&"_brood_in", 1.0e9)
	if t >= BEAUTY_DUCKS_AT and not _beauty_ducks:
		_beauty_ducks = _duck_family()
	if t >= BEAUTY_HIVE_AT and hive.stage == Hive.Stage.EMPTY:
		hive.set_stage(Hive.Stage.BUSY)
		_say("  beauty: the colony moves in on frame %d" % k)
	if k > 0 and k % BEAUTY_SPREAD_EVERY == 0:
		_thin_crowd(BEAUTY_APART)
	_fewer_pads()
	if k > 0 and k % 120 == 0:
		for b: Dictionary in (_main.get(&"_wildlife") as Wildlife).get(&"_broods") as Array:
			_say("  brood %s at %s state %d kids %d" % [b["kind"], str((b["at"] as Vector2).round()), int(b["state"]), (b["kids"] as Array).size()])


## Water plants over `BEAUTY_PADS` of the rank put back to not due, every frame, before they
## start to grow (the lake's own refresh makes them due as it cleans).
func _fewer_pads() -> void:
	var flora: Flora = _main.get(&"_flora")
	var ages: PackedFloat32Array = flora.get(&"_age")
	var ranks: PackedFloat32Array = flora.get(&"_rank")
	var species: PackedStringArray = flora.get(&"_species")
	var table: Dictionary = flora.get(&"_table")
	var undone := false
	for k in ages.size():
		if ages[k] < 0.0 or ranks[k] < BEAUTY_PADS * Flora.MOST:
			continue
		var kind := String((table[species[k]] as Dictionary)["kind"])
		if kind == "water" or kind == "open":
			ages[k] = -1.0
			undone = true
	if undone:
		flora.set(&"_age", ages)
		flora.set(&"_dirty", true)
		flora.queue_redraw()


## A hen with ducklings flown in from off the shot to `BEAUTY_DUCKS` past the island's middle,
## staying for the rest of the film.
func _duck_family() -> bool:
	var wild: Wildlife = _main.get(&"_wildlife")
	var to := Iso.tile_to_world(Iso.ISLAND_CENTRE.x, Iso.ISLAND_CENTRE.y) + BEAUTY_DUCKS
	if not wild.call(&"_swimmable", to):
		return false
	for attempt in 40:
		var b: Dictionary = wild.call(&"_new_brood")
		if b.is_empty():
			return false
		if (b["kids"] as Array).size() < 3:
			continue
		var from := to + Vector2(520.0, -260.0)
		b["from"] = from
		b["at"] = from
		b["to"] = to
		b["goal"] = to
		b["facing"] = Flock.facing_of(from, to)
		b["timer"] = 1.0e6
		for kid: Dictionary in b["kids"]:
			kid["at"] = from
		(wild.get(&"_broods") as Array).append(b)
		_say("  beauty: ducks in, %d ducklings" % (b["kids"] as Array).size())
		return true
	return false


## `_spread_life` without the hold: the lake keeps calling life up as it cleans, and this
## only sends off what lands too close to another.
func _thin_crowd(apart: float) -> void:
	var wild: Wildlife = _main.get(&"_wildlife")
	var kept: Array[Vector2] = []
	for key in [&"_broods", &"_turtles", &"_frogs", &"_critters_on_land", &"_flies"]:
		var list: Array = wild.get(key)
		var keep: Array = []
		for a: Dictionary in list:
			var at: Vector2 = a.get("to", a["at"]) if key == &"_broods" else a["at"]
			var near := false
			for p in kept:
				if p.distance_to(at) < apart:
					near = true
					break
			if near:
				continue
			kept.append(at)
			keep.append(a)
		list.assign(keep)


## Everything left on the water under a landed net's mouth (a 2:1 ellipse `mouth` across on
## the screen, grown by `WEST_EMPTY`), taken the way the net takes: what it could not lift
## goes under its mesh and the splash, and the water there is clean once the patch closes.
func _empty_under(at: Vector2, mouth: float) -> void:
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
	_say("  emptied under the net at %s: %d" % [str(Iso.world_to_tile(at)), taken])


## The third dog off the beach for the piece by `_dog_stick`.
func _send_one_dog() -> void:
	var dogs: Array = _main.get(&"_dogs")
	if dogs.size() < 3:
		return
	var spot := _dog_stick()
	var best := -1
	var best_d := 1.0e9
	for index in _grid.stacks.size():
		if _grid.dry[index] == 1 or _grid.stacks[index].is_empty():
			continue
		var d := Vector2(_grid.tile_of(index)).distance_to(spot)
		if d < best_d:
			best_d = d
			best = index
	if best < 0:
		return
	var dog: Node2D = dogs[2]
	dog.call(&"_aim_at", best)
	dog.set(&"_to_strand", false)
	dog.set(&"_trip", 0.0)
	dog.set(&"_state", 4)


## Every plant already due shown full grown, and the set of grown plants remembered, so
## nothing sprouts on camera (Richard: "flora does not pop out of nowhere").
var _grown := PackedFloat32Array()


func _flora_grown() -> void:
	var flora: Flora = _main.get(&"_flora")
	var ages: PackedFloat32Array = flora.get(&"_age")
	for k in ages.size():
		if ages[k] >= 0.0:
			ages[k] = 1.0e6
	flora.set(&"_age", ages)
	flora.set(&"_growing", 0)
	flora.set(&"_dirty", true)
	flora.queue_redraw()
	_grown = ages


## What would change on camera without anybody doing it: plants the cleared patch makes due,
## and pigeons called in. Undone every frame of the shot.
func _hold_still() -> void:
	var flora: Flora = _main.get(&"_flora")
	var ages: PackedFloat32Array = flora.get(&"_age")
	var undone := false
	for k in ages.size():
		if ages[k] >= 0.0 and _grown[k] < 0.0:
			ages[k] = -1.0
			undone = true
	if undone:
		flora.set(&"_age", ages)
		flora.set(&"_growing", 0)
		flora.set(&"_dirty", true)
		flora.queue_redraw()
	(_main.get(&"_flock") as Flock).set(&"_rethink", 1.0e9)


## Pigeons sitting where a net will land are sent off before filming: a netted one pops its
## head in over the action. The rest of the flock stays where it is.
func _birds_off_landings() -> void:
	var flock: Flock = _main.get(&"_flock")
	var land := _angler.tile_pos + _m(ACROSS).normalized() * CAST_TILES
	var spots := [land + CAST_UP, land + CAST_DOWN, land]
	for i in range(flock.birds.size() - 1, -1, -1):
		# Where it is and where it is flying to: a bird still on its way in lands later.
		var bird: Dictionary = flock.birds[i]
		var at := Iso.world_to_tile(bird["at"])
		var to := Iso.world_to_tile(bird.get("to", bird["at"]))
		for spot: Vector2 in spots:
			if at.distance_to(spot) < 8.0 or to.distance_to(spot) < 8.0:
				flock.birds.remove_at(i)
				break
	_say("  pigeons left: %d" % flock.birds.size())
	if not flock.netted.is_connected(_on_netted):
		flock.netted.connect(_on_netted)
	_say("  landings %s" % str(spots))


func _on_netted(at: Vector2) -> void:
	_say("  netted a pigeon at tile %s" % str(Iso.world_to_tile(at)))


func _shoot(every: int = EVERY, most: int = MOST) -> void:
	_from = _shot_frame
	_saved = 0
	_every = every
	_most = most


func _next() -> void:
	_from = -1
	_saved = 0
	super._next()
	if _main != null and _main.is_inside_tree() and _shot < _shots.size():
		(_main.get_node(^"HUD") as CanvasLayer).visible = true


func _process(_delta: float) -> void:
	_frames += 1
	if Time.get_ticks_msec() > QUIT_AFTER_MS:
		_say("--- wall clock, quitting")
		get_tree().quit()
		return
	if _frames == 3:
		_setup()
		_plan()
		_next()
		return
	if _frames < 4 or _shot >= _shots.size():
		return
	var shot: Array = _shots[_shot]
	(shot[3] as Callable).call(_shot_frame)
	_aim()
	if _from >= 0 and (_shot_frame - _from) % _every == 0:
		var image := get_viewport().get_texture().get_image()
		if _film:
			var dir := ProjectSettings.globalize_path("res://tools/film/steam/%s" % shot[0])
			if _saved == 0:
				DirAccess.make_dir_recursive_absolute(dir)
				for old in DirAccess.get_files_at(dir):
					DirAccess.remove_absolute(dir.path_join(old))
			image.save_jpg(dir.path_join("f_%04d.jpg" % _saved), 0.95)
		else:
			image.save_png(ProjectSettings.globalize_path(STEAM_OUT % [shot[0], _saved]))
		var net2: CastNet = _main.get(&"_net2")
		_say("  %s_%02d: net %d, net2 %d, pigeons %d, plants %d" % [shot[0], _saved, _net.state,
				net2.state if net2 != null else -1, (_main.get(&"_flock") as Flock).birds.size(),
				int((_main.get(&"_flora") as Flora).get(&"_alive"))])
		_saved += 1
		if _saved >= _most:
			_next()
			return
	if _shot_frame > 60 * 60:
		_say("%s: gave up" % shot[0])
		_next()
		return
	_shot_frame += 1
