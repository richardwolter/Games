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
const CAST_UP := Vector2(-2.8, -2.8)
const CAST_DOWN := Vector2(3.2, 3.2)
## How much of the lake is cleaned, and how far round each landing the soup is kept.
const CAST_CLEAN := 0.86
## The still differs from the clip (2026-10-02, Richard: not the exact same scene): a dirtier
## lake, pools laid out off another noise, a smaller hold and less money.
const STILL_CLEAN := 0.74
const STILL_SEED := 23
const STILL_HOLD := 4
const STILL_MONEY := 12730.0
const CAST_KEEP := 3.6
## The wildlife's share: some life on the clean water, not a crowd.
const CAST_LIFE := 0.3

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
	_main.set(&"net_width_level", 14 if west else 18)
	_main.call(&"_push_net_numbers")
	_hide_boats()
	_pack()
	_stand(_m(CAST_STAND), _m(ACROSS))
	var land := _angler.tile_pos + _m(ACROSS).normalized() * CAST_TILES
	thin_seed = 11 if west else STILL_SEED
	_main.set(&"net_hold_level", 6 if west else STILL_HOLD)
	_main.set(&"sludge", 18450.0 if west else STILL_MONEY)
	_main.call(&"_push_net_numbers")
	_thin(CAST_CLEAN if west else STILL_CLEAN,
			[land + CAST_UP, land + CAST_DOWN, land, _dog_stick()], CAST_KEEP)
	_drop_finds()
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
const PIER_HOLD := 14


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
	_main.set(&"cargo_level", 6)
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
		_shoot(3, 24)


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
	if k == -30:
		var flora: Flora = _main.get(&"_flora")
		var wild: Wildlife = _main.get(&"_wildlife")
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
		_shoot(1, CLIP_FRAMES)
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
