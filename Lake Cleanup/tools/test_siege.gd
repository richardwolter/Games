## Headless checks for the second lake: the swarm, the four charms, the box that fires
## them, the guns ammo loads, and the net with fire and ice on it.
##
## Run: Godot --headless --path <project> res://tools/test_siege.tscn --quit-after 3000
##
## Same shape as test_lake.gd, and for the same reasons: a scene stepped by
## _physics_process rather than a `--script` SceneTree with `await`, and a log file rather
## than stdout, because this Godot build's stdout does not reach a shell and a GDScript
## error aborts the run silently.
extends Node

const LOG_PATH := "res://tools/last_siege_test.log"

## The harness's own save file. The siege writes to its own file anyway, but a test run
## must not touch even that.
const SAVE_PATH := "user://test_siege.save"

var _main: Node2D
var _grid: LakeGrid
var _angler: Angler
var _net: CastNet
var _swarm: SludgeSwarm
var _charms: CharmField
var _box: CharmBox
var _volley: Volley
var _ward: Ward
var _laid: LaidNet
var _left_behind: int = 0
var _sub: int = 0
var _blows_done: bool = false
var _cold: Node2D
var _caught_lot: int = 0
var _patrol_from := Vector2.INF
var _hunted := Vector2.INF

var _stage: int = 0
var _in_stage: int = 0
var _ran: int = 0
var _failed: int = 0

var _health_before: float = 0.0
var _blob_health: float = 0.0
var _swim_from := Vector2.ZERO
var _fired: Array[int] = []
var _blows: int = 0


func _ready() -> void:
	if FileAccess.file_exists(LOG_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG_PATH))
	_log("--- test_siege start")
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_main = load("res://scenes/siege.tscn").instantiate()
	_main.set(&"save_path", SAVE_PATH)
	_main.set(&"autoload_save", false)
	add_child(_main)


func _physics_process(_delta: float) -> void:
	_in_stage += 1
	match _stage:
		0:
			if _in_stage >= 2:
				_stage_build()
		1:
			_stage_charm_cast()
		2:
			_stage_box_order()
		3:
			_stage_shield()
		4:
			_stage_swim()
		5:
			_stage_attack()
		6:
			_stage_volley()
		7:
			_stage_fire_and_ice()
		8:
			_stage_defeat()
		9:
			_stage_save()
		10:
			_stage_waves()
		11:
			_stage_cold_start()
		12:
			_stage_outgrown_win()
		_:
			pass


func _advance() -> void:
	_stage += 1
	_in_stage = 0
	# Sub-steps belong to the stage that used them.
	_sub = 0


## The siege is the lake plus five things, and the water it is fought on is muck.
func _stage_build() -> void:
	_grid = _main.get_node(^"Grid") as LakeGrid
	_angler = _main.get_node(^"Angler") as Angler
	_net = _main.get_node(^"Net") as CastNet
	_swarm = _main.get_node(^"Swarm") as SludgeSwarm
	_charms = _main.get_node(^"Charms") as CharmField
	_box = _main.get_node(^"Box") as CharmBox
	_volley = _main.get_node(^"Volley") as Volley
	_ward = _main.get_node(^"Ward") as Ward
	_laid = _main.get_node(^"LaidNets") as LaidNet

	_check(_swarm != null and _charms != null and _box != null and _volley != null
		and _ward != null and _laid != null, "the siege built its six parts", "")
	_check(_main.call(&"_level_seed") != 20260817,
		"the siege is a different lake from the cleanup", "")
	# Nothing floats on the siege but what its yards make. The first lake is the fishing
	# trip; a basin seeded with rubbish nobody buys any more would be eight thousand tiles
	# of distraction laid over a fight.
	_check(_grid.piece_count() == 0, "the water starts empty",
		"%d pieces" % _grid.piece_count())
	_check(not _grid.defs.any(func(d: TrashDef) -> bool: return d.keepsake),
		"nothing is hidden in it to find", "")

	_check(_charms.spouts.size() == 4, "there is one fabricator per yard",
		"%d spouts" % _charms.spouts.size())
	for spout: Vector2 in _charms.spouts:
		_check(Iso.in_lake(int(spout.x), int(spout.y)),
			"a fabricator pushes its charms onto water", "%s" % spout)
		break
	_check(_net.charms == _charms, "the net knows about the charms", "")

	# The fleet has nothing to ferry in this lake, so it is out on the water instead: the
	# guns ammo loads are on those hulls, and a moored gun covers the dock and nothing else.
	var fleet: Array = _main.get(&"_boats")
	_check(fleet.all(func(b: Boat) -> bool: return b.patrol),
		"every hull is out on patrol rather than moored", "%d hulls" % fleet.size())
	_check(is_equal_approx(_ward.health, Ward.HEALTH), "the shed starts whole", "")
	_check(is_zero_approx(_ward.shield), "and unshielded", "")

	# The yards are turned off for the rest of the run: charms drifting in during a check
	# about a different charm is the same kind of bug birds arriving mid-cast used to be.
	_charms.making = false
	_charms.charms.clear()
	# And the box is held: it fires its first charm within a second of getting one, which
	# would empty it again before the stage below could look in it.
	_box.running = false
	_advance()


## A charm on the water, netted, ends up in the box. The whole of the second lake's loop
## in one stage.
func _stage_charm_cast() -> void:
	if _sub == 0:
		var where := _water_near_angler()
		_check(_charms.add_charm(CharmField.Kind.FIRE, Iso.world_to_tile(where)),
			"a yard can start making a charm", "")
		_check(_charms.charms.size() == 1, "and it comes up where the yard is", "")
		# A charm is not a charm the moment it exists. The yard has to push it up through
		# the surface first, and until it is up the net passes over it.
		_check(_charms.charm_on(_grid.tile_at(where)) < 0,
			"a charm still coming up cannot be netted", "")
		_check(not _charms.is_up(_charms.charms[0]), "because it is not up yet",
			"rise %.2f" % float((_charms.charms[0] as Dictionary)["rise"]))
		_sub = 1
		return
	if _sub == 1:
		if not _charms.is_up(_charms.charms[0]) and _in_stage < 1200:
			return
		_check(_charms.is_up(_charms.charms[0]), "it surfaces on its own",
			"rise %.2f after %d frames" % [
				float((_charms.charms[0] as Dictionary)["rise"]), _in_stage
			])
		# It slid out along its pier on the way up, so where it is now is not where it was
		# started: the cast goes to where it actually is.
		var risen: Vector2 = (_charms.charms[0] as Dictionary)["tile"]
		var where := Iso.tile_to_world(risen.x, risen.y)
		_check(_charms.charm_on(_grid.tile_at(where)) == 0,
			"and then the net can see it", "tile %d" % _grid.tile_at(where))
		_main.call(&"_cast_at", where)
		_net.set_pulling(true)
		_check(_net.state == CastNet.State.FLYING, "the cast is in the air", "")
		_sub = 2
		return
	if _net.state != CastNet.State.IDLE and _in_stage < 1600:
		return
	_net.set_pulling(false)
	_check(_charms.charms.is_empty(), "the cast took the charm off the water", "")
	_check(_box.slots.size() == 1 and _box.slots[0] == CharmField.Kind.FIRE,
		"and it went into the box", "%s" % [_box.slots])
	_check(not _box.running or _box.slots.is_empty(),
		"the box was holding it rather than firing it mid-check", "")
	_box.slots.resize(0)
	_advance()


## The box is a queue: what went in first comes out first.
func _stage_box_order() -> void:
	if _in_stage == 1:
		_box.running = true
		_box.fired.connect(func(kind: int) -> void: _fired.append(kind))
		_check(_box.put(CharmField.Kind.SHIELD), "the box takes a charm", "")
		_box.put(CharmField.Kind.AMMO)
		_check(_box.slots.size() == 2, "and holds them in the order they arrived",
			"%s" % [_box.slots])
		for i in CharmBox.SLOTS:
			_box.put(CharmField.Kind.ICE)
		_check(_box.slots.size() == CharmBox.SLOTS, "the box fills up",
			"%d slots" % _box.slots.size())
		_check(not _box.put(CharmField.Kind.ICE), "and refuses what it cannot hold", "")
		return
	if _fired.size() < 2 and _in_stage < 600:
		return
	_check(_fired.size() >= 2 and _fired[0] == CharmField.Kind.SHIELD
		and _fired[1] == CharmField.Kind.AMMO,
		"the box fires in the order the charms were caught", "%s" % [_fired])
	_check(_ward.shield > 0.0, "the shield charm put a wall up",
		"%.1f" % _ward.shield)
	_check(float(_main.get(&"_ammo_for")) > 0.0, "the ammo charm loaded the guns",
		"%.1fs" % float(_main.get(&"_ammo_for")))
	_box.slots.resize(0)
	_advance()


## Shield stands in front of health, always.
func _stage_shield() -> void:
	_ward.shield = 20.0
	_ward.health = Ward.HEALTH
	_ward.take(12.0)
	_check(is_equal_approx(_ward.health, Ward.HEALTH) and is_equal_approx(_ward.shield, 8.0),
		"a blow comes off the shield first", "%.1f shield, %.1f shed" % [_ward.shield, _ward.health])
	_ward.take(20.0)
	_check(is_zero_approx(_ward.shield) and _ward.health < Ward.HEALTH,
		"and only what is left of it reaches the shed",
		"%.1f shield, %.1f shed" % [_ward.shield, _ward.health])
	_check(is_equal_approx(_ward.health, Ward.HEALTH - 12.0),
		"by exactly what got through", "%.1f" % _ward.health)
	_ward.health = Ward.HEALTH
	_advance()


## A monster swims at the island rather than wandering.
func _stage_swim() -> void:
	if _in_stage == 1:
		# The guns are unloaded first. Ammo caught two stages ago is still live, and a blob
		# quietly shot out from under a check about swimming is a confusing way to fail.
		_main.set(&"_ammo_for", 0.0)
		_swarm.blobs.clear()
		_check(_swarm.add_blob(1, 0.0), "a blob can be put on the rim", "")
		_swim_from = _swarm.tile_of(0)
		_check(Iso.in_lake(int(_swim_from.x), int(_swim_from.y)),
			"it starts on the water", "%s" % _swim_from)
		return
	if _in_stage < 60:
		return
	var now := _swarm.tile_of(0)
	_check(now.distance_to(Iso.ISLAND_CENTRE) < _swim_from.distance_to(Iso.ISLAND_CENTRE),
		"and swims towards the island",
		"%.1f -> %.1f tiles out" % [
			_swim_from.distance_to(Iso.ISLAND_CENTRE), now.distance_to(Iso.ISLAND_CENTRE)
		])
	# Ice slows it. Measured over the same number of frames rather than asserted.
	_swim_from = now
	_swarm.soak(now, 3.0, 0.0, SludgeSwarm.CHILL_SPEED, 0.016)
	_check(float((_swarm.blobs[0] as Dictionary)["chill"]) > 0.0,
		"ice sticks to what it is cast over", "")
	_advance()


## It reaches the island, stops, and starts hitting the shed.
func _stage_attack() -> void:
	if _in_stage == 1:
		_main.set(&"_ammo_for", 0.0)
		_swarm.blobs.clear()
		_swarm.add_blob(1, 0.0)
		# Put it at the shore rather than waiting out the swim: the swim is the stage above.
		var blob: Dictionary = _swarm.blobs[0]
		blob["tile"] = Iso.ISLAND_CENTRE + Vector2(0.0, Iso.ISLAND_RADIUS.y * 1.2)
		blob["chill"] = 0.0
		_blows = 0
		_swarm.struck.connect(func(_damage: float) -> void: _blows += 1)
		_health_before = _ward.health
		return
	if _blows == 0 and _in_stage < 400:
		return
	_check(int((_swarm.blobs[0] as Dictionary)["state"]) == SludgeSwarm.State.ATTACK,
		"a blob that reaches the island stops there", "")
	# Counted rather than read off the shed, because the shed patches itself between waves
	# and a blow landed and mended is still a blow landed.
	_check(_blows > 0, "and starts taking the shed down",
		"%d blows in %d frames" % [_blows, _in_stage])
	_check(not Iso.in_lake(int(Iso.ISLAND_CENTRE.x), int(Iso.ISLAND_CENTRE.y)),
		"it never climbs onto the island", "")
	_ward.health = Ward.HEALTH
	_advance()


## Ammo makes the shed and the boats shoot, and what they shoot kills.
func _stage_volley() -> void:
	if _in_stage == 1:
		_swarm.blobs.clear()
		_swarm.add_blob(1, 0.0)
		var blob: Dictionary = _swarm.blobs[0]
		blob["tile"] = Iso.ISLAND_CENTRE + Vector2(0.0, Iso.ISLAND_RADIUS.y + 3.0)
		_blob_health = float(blob["health"])
		# Whatever the box handed out earlier has to be spent first: the check below is
		# about a gun with nothing in it.
		_main.set(&"_ammo_for", 0.0)
		_volley.shots.clear()
		return
	if _in_stage == 4:
		_check(_volley.shots.is_empty(), "an unloaded gun fires nothing",
			"%d shots" % _volley.shots.size())
		_main.set(&"_ammo_for", 30.0)
		return
	if _swarm.alive() > 0 and _in_stage < 600:
		return
	_check(_swarm.alive() == 0, "loaded guns clear what comes at the shed",
		"%d left after %d frames" % [_swarm.alive(), _in_stage])
	_check(float(_main.get(&"sludge")) > 0.0, "and a kill is worth something",
		"%.0f" % float(_main.get(&"sludge")))
	_main.set(&"_ammo_for", 0.0)
	_swarm.blobs.clear()
	_advance()


## The lit net: placed rather than dragged, and both enchantments at once.
## The lit net: thrown and left, not thrown and held. The angler keeps casting.
##
## Stepped on what the net is actually doing rather than on frame numbers. A cast to nearby
## water lands in a handful of frames, and a stage that asks its questions on frame 301 asks
## them of a net that has been home for five seconds.
func _stage_fire_and_ice() -> void:
	match _sub:
		0:
			_laid.clear()
			_left_behind = 0
			_net.left_behind.connect(
				func(_t: Vector2, _r: float, _f: bool, _i: bool) -> void: _left_behind += 1
			)
			_caught_lot = 0
			_net.landed.connect(
				func(lot: PackedInt32Array) -> void: _caught_lot += lot.size()
			)
			_net.state = CastNet.State.IDLE
			_net.enchant(CastNet.Charm.FIRE, 30.0)
			_net.enchant(CastNet.Charm.ICE, 30.0)
			_check(_net.enchanted(), "the net can be lit", "")
			_check(_net.charm_for(CastNet.Charm.FIRE) > 0.0
				and _net.charm_for(CastNet.Charm.ICE) > 0.0,
				"fire and ice stack rather than replace one another", "")
			_check(_net.field_radius() <= 2.5,
				"a laid net covers a patch, not the lake",
				"%.1f tiles across" % (_net.field_radius() * 2.0))

			# An ordinary cast is still an ordinary cast with fire on the twine: it goes
			# out, it drags, it comes home. There is nothing in this water but charms, so
			# it comes home empty — what matters is that it went and came back rather than
			# being turned into a placement the player did not ask for.
			_main.call(&"_cast_at", _water_near_angler())
			_net.set_pulling(true)
			_sub = 5
		5:
			if _net.state != CastNet.State.IDLE and _in_stage < 800:
				return
			_check(_laid.working() == 0,
				"a lit net that was told to fish leaves nothing behind",
				"%d laid" % _laid.working())
			_check(_net.enchanted(), "and is still lit afterwards", "")
			_in_stage = 0
			# Now the other button. Laying is not throwing: there is no flight to watch and
			# nothing coming back, so the net is down on the frame the player asked for it.
			var down := _water_near_angler()
			_main.call(&"_cast_at", down, true)
			_check(_net.state == CastNet.State.IDLE,
				"a laying cast leaves the rod alone", "state %d" % _net.state)
			_check(_laid.working() == 1, "and the net is on the water at once",
				"%d laid" % _laid.working())
			_check(_net.catch.is_empty(), "with nothing dragged home", "")
			_patrol_from = Vector2.INF
			_in_stage = 0
			var put: Vector2 = (_laid.nets[0] as Dictionary)["tile"]
			_check(put.distance_to(Iso.world_to_tile(down)) < 0.6,
				"exactly where it was asked for",
				"%s against %s" % [put, Iso.world_to_tile(down)])
			_sub = 9
		9:
			# A patrolling hull actually goes somewhere, wave or no wave.
			if _patrol_from == Vector2.INF:
				_patrol_from = (_main.get(&"_boats")[0] as Boat).tile_pos
				return
			if _in_stage < 90:
				return
			var boat: Boat = _main.get(&"_boats")[0]
			_check(boat.tile_pos.distance_to(_patrol_from) > 1.0,
				"and it is moving while the siege runs",
				"%.1f tiles from where it was" % boat.tile_pos.distance_to(_patrol_from))
			_check(Iso.in_lake(int(boat.tile_pos.x), int(boat.tile_pos.y)),
				"on the water, where its gun is worth something", "%s" % boat.tile_pos)

			# And it hunts. Something is put in the water on the far side of the lake, and
			# the hull should be sent after it rather than going on with its rounds.
			_swarm.blobs.clear()
			_swarm.add_blob(1, fposmod(Iso.basin_angle(boat.tile_pos) + PI, TAU))
			_in_stage = 0
			_sub = 10
		10:
			# Orders go out on their own clock, in seconds of real time, so this waits for
			# them rather than asking on a chosen frame.
			var boat: Boat = _main.get(&"_boats")[0]
			if boat.patrol_at == Vector2.INF and _in_stage < 1200:
				return
			_hunted = _swarm.tile_of(0)
			_check(boat.patrol_at != Vector2.INF,
				"a hull with a monster in the lake is sent at it", "%s" % boat.patrol_at)
			if boat.patrol_at == Vector2.INF:
				_swarm.blobs.clear()
				_sub = 2
				return
			_check(boat.patrol_at.distance_to(_hunted) < 9.0,
				"to water beside the thing rather than to the far bank",
				"%.1f tiles off it" % boat.patrol_at.distance_to(_hunted))
			# Short of it: a hull that steers into what it is shooting at parks on top of it.
			_check(boat.patrol_at.distance_to(_hunted) > 1.0,
				"and stands off it rather than into it",
				"%.1f tiles off it" % boat.patrol_at.distance_to(_hunted))
			_patrol_from = boat.tile_pos
			_in_stage = 0
			_sub = 11
		11:
			var boat: Boat = _main.get(&"_boats")[0]
			var hunted := _swarm.tile_of(0)
			var now := boat.tile_pos.distance_to(hunted)
			if now >= _patrol_from.distance_to(_hunted) and _in_stage < 1200:
				return
			_check(now < _patrol_from.distance_to(_hunted), "and it closes on it",
				"%.1f -> %.1f tiles away" % [_patrol_from.distance_to(_hunted), now])
			_swarm.blobs.clear()
			_sub = 2
		2:
			# The bug this stage was written for: a lit cast used to stay in the player's
			# hands as a settled net, so nothing could be thrown until it was reeled — and a
			# lit net will not reel.
			var again := _water_near_angler()
			_check(_net.can_cast_to(again), "the angler can cast again straight away", "")
			_main.call(&"_cast_at", again, true)
			_net.set_pulling(false)
			_check(_left_behind == 2, "both casts were left behind",
				"%d of 2" % _left_behind)
			_check(_laid.working() == 2, "and both nets are out there at once",
				"%d laid" % _laid.working())
			_check(_laid.nets.size() <= LaidNet.MOST, "never more than the angler owns",
				"%d of %d" % [_laid.nets.size(), LaidNet.MOST])

			# Everything after this is about what a laid net does, so one is put over open
			# water with something standing in it. Over water, not wherever the net is — the
			# net is back in the angler's hands by now, and the angler is on the island.
			var over := Iso.world_to_tile(_water_near_angler())
			_laid.clear()
			_laid.lay(over, _net.field_radius(), true, true)
			_swarm.blobs.clear()
			_swarm.add_blob(1, 0.0)
			var blob: Dictionary = _swarm.blobs[0]
			blob["tile"] = over
			_blob_health = float(blob["health"])
			_health_before = _grid.piece_count()
			_advance()


## The defeat screen, and what it takes to get one.
func _stage_defeat() -> void:
	if _in_stage == 1:
		# Two frames of standing in the fire, then the shed is knocked over on purpose.
		return
	# A laid net burns on its own clock, in seconds of real time, so this waits for the
	# work to show rather than asking on a chosen frame.
	if _in_stage < 30:
		return
	if not _swarm.blobs.is_empty() and _blob_health <= float(
		(_swarm.blobs[0] as Dictionary).get("health", 0.0)
	) and _in_stage < 400:
		return
	if not _blows_done:
		_blows_done = true
		# It may already be dead: a laid net carrying fire kills a first-wave blob in about
		# a second and a half, and dead is the strongest form of "it took health off".
		var blob: Dictionary = _swarm.blobs[0] if not _swarm.blobs.is_empty() else {}
		var health := float(blob.get("health", -1.0))
		_check(health < _blob_health, "a left net goes on burning without its owner",
			"%.1f -> %.1f" % [_blob_health, health])
		_check(blob.is_empty() or float(blob["chill"]) > 0.0,
			"and the same cast freezes it", "")
		_net.set_pulling(false)
		_laid.clear()
		# Knocked down the way it really happens: a shed on its last point, a ring of
		# monsters mid-swing, and the swarm called off from inside one of their blows.
		_swarm.blobs.clear()
		for i in 6:
			_swarm.add_blob(1, TAU * float(i) / 6.0)
			var swinging: Dictionary = _swarm.blobs[_swarm.blobs.size() - 1]
			swinging["tile"] = Iso.ISLAND_CENTRE + Vector2(
				cos(TAU * float(i) / 6.0), sin(TAU * float(i) / 6.0)
			) * (Iso.ISLAND_RADIUS.y * 1.2)
			swinging["state"] = SludgeSwarm.State.ATTACK
			swinging["attack_in"] = 0.001
		_ward.health = 1.0
		_in_stage = 0
		return
	if _in_stage < 10:
		return
	_check(_ward.is_down(), "the shed can be knocked down", "")
	_check(_swarm.blobs.is_empty(),
		"and the swarm it was hit by is called off without taking the frame with it", "")
	_check(_main.get_node_or_null(^"Defeat") != null, "and that raises the defeat screen", "")
	_check(not _angler.can_walk, "which holds the angler where they stand", "")
	_advance()


## A siege written out and read back is the same siege.
func _stage_save() -> void:
	_main.set(&"wave", 3)
	_ward.health = 44.0
	_ward.shield = 25.0
	_box.slots = PackedInt32Array([CharmField.Kind.ICE, CharmField.Kind.AMMO])
	_check(bool(_main.call(&"save_game")), "the siege saves", "")

	_main.set(&"wave", 1)
	_ward.health = Ward.HEALTH
	_ward.shield = 0.0
	_box.slots.resize(0)
	_check(bool(_main.call(&"load_game")), "and loads again", "")
	_check(int(_main.get(&"wave")) == 3, "the wave came back",
		"wave %d" % int(_main.get(&"wave")))
	_check(is_equal_approx(_ward.health, 44.0) and is_equal_approx(_ward.shield, 25.0),
		"so did the shed and its shield", "%.1f, %.1f" % [_ward.health, _ward.shield])
	_check(_box.slots.size() == 2 and _box.slots[0] == CharmField.Kind.ICE,
		"and the queue came back in order", "%s" % [_box.slots])
	# A cleanup save must not be readable as a siege, and the seed is what says so.
	_check(int(_main.call(&"_level_seed")) != 20260817,
		"the save is stamped with this lake rather than the first one", "")
	_advance()


## The siege actually running: a wave arrives, a cleared wave hands over to the next, and
## the last one held ends the game.
##
## The stage that was missing. Everything else here checks a part; this checks that the
## parts hand over to one another, which is where a defence level goes wrong — a wave that
## cannot finish is a game with no ending, and it looks exactly like a game whose ending is
## broken.
func _stage_waves() -> void:
	match _sub:
		0:
			# A clean slate: no defeat screen left over, a whole shed, and a quiet lake.
			var over := _main.get_node_or_null(^"Defeat")
			if over != null:
				over.free()
			_main.set(&"_defeat", null)
			_ward.health = Ward.HEALTH
			_ward.set(&"_down", false)
			_swarm.blobs.clear()
			_laid.clear()
			_main.set(&"wave", 1)
			_main.set(&"_phase", 0)
			_main.set(&"_phase_in", 0.0)
			_main.call(&"_hold_the_angler")
			_sub = 1
		1:
			# The gap runs out and a wave starts putting monsters in the water.
			if int(_main.get(&"_phase")) != 1 and _in_stage < 300:
				return
			_check(int(_main.get(&"_phase")) == 1,
				"the quiet gap gives way to a wave", "phase %d" % int(_main.get(&"_phase")))
			_sub = 2
		2:
			# Every monster the wave promised has to actually arrive, or the wave can never
			# be over and the siege has no way forward.
			if int(_main.get(&"_to_spawn")) > 0 and _in_stage < 3000:
				return
			_check(int(_main.get(&"_to_spawn")) == 0,
				"a wave puts every monster it promised in the water",
				"%d never arrived, %d swimming" % [
					int(_main.get(&"_to_spawn")), _swarm.alive()
				])
			_check(_swarm.alive() > 0, "and they are out there",
				"%d swimming" % _swarm.alive())
			# Cleared the way the player would clear it.
			for i in _swarm.blobs.size():
				_swarm.hurt(i, 9999.0)
			_sub = 3
		3:
			if _swarm.alive() > 0 and _in_stage < 3000:
				return
			if int(_main.get(&"wave")) < 2 and _in_stage < 3000:
				return
			_check(int(_main.get(&"wave")) == 2, "a cleared wave hands over to the next",
				"wave %d" % int(_main.get(&"wave")))
			# Every fourth one is bigger than the count says, so the run has a shape rather
			# than a slope.
			_main.set(&"wave", 3)
			var ordinary := int(_main.call(&"_wave_size"))
			_main.set(&"wave", 4)
			var big := int(_main.call(&"_wave_size"))
			_check(big > ordinary and bool(_main.call(&"is_big_wave")),
				"and every fourth wave is a big one",
				"%d against %d" % [big, ordinary])
			_main.set(&"wave", 2)
			_check(int(_main.get(&"_phase")) == 0, "with a gap in between",
				"phase %d" % int(_main.get(&"_phase")))

			# And the last one held is the end of the game.
			_check(int(_main.call(&"waves_to_win")) >= 10,
				"the siege is a long enough run to be one",
				"%d waves" % int(_main.call(&"waves_to_win")))
			_main.set(&"wave", int(_main.call(&"waves_to_win")))
			_main.set(&"_phase", 1)
			_main.set(&"_to_spawn", 0)
			_swarm.blobs.clear()
			_sub = 4
		4:
			if int(_main.get(&"_phase")) != 2 and _in_stage < 300:
				return
			_check(int(_main.get(&"_phase")) == 2, "holding the last wave wins the siege",
				"phase %d" % int(_main.get(&"_phase")))
			_check(_main.get_node_or_null(^"Farewell") != null,
				"and the closing words are on screen", "")
			_check(_laid.nets.is_empty(),
				"with nothing still burning in an empty lake", "")
			_advance()


## Open water within casting distance of the angler, with something in it. Same problem and
## same answer as test_lake.gd: the angler stands on the island, so a point a few tiles from
## them in a straight line is as likely to be more island as it is to be lake.
func _water_near_angler() -> Vector2:
	var out := _angler.tile_pos - Iso.ISLAND_CENTRE
	if out.length() < 0.001:
		out = Vector2(0.0, 1.0)
	out = out.normalized()
	var best := Vector2.INF
	var walked := 0.0
	while walked < _net.range_tiles - 0.2:
		walked += 0.4
		var at := _angler.tile_pos + out * walked
		if Iso.island_fraction(at.x, at.y) <= 1.05 or Iso.shore_fraction(at.x, at.y) >= 0.95:
			continue
		best = Iso.tile_to_world(at.x, at.y)
	return best if best != Vector2.INF else Iso.tile_to_world(
		Iso.CENTRE.x, Iso.CENTRE.y + Iso.ISLAND_RADIUS.y + 4.0
	)


## A siege opened cold, with a save already on disk.
##
## The case every other save check here missed. Those all load into a siege that has been
## running for a while, so its swarm and its box and the shed's ward are all there to be
## written into. A player starting the game has none of that yet — the lake reads the save
## in its own _ready, and the siege's own parts are built a few lines later — so the load
## arrived at a shed that did not exist and fell over on the first line that touched it.
func _stage_cold_start() -> void:
	match _sub:
		0:
			_main.set(&"wave", 4)
			_main.set(&"_phase", 0)
			_ward.health = 51.0
			_ward.shield = 12.0
			_box.slots = PackedInt32Array([CharmField.Kind.ICE, CharmField.Kind.FIRE])
			_check(bool(_main.call(&"save_game")), "a siege in progress saves", "")

			# A second one, opened the way the game opens: the save is on disk, and it is
			# read before anything of the siege's own has been built.
			_cold = load("res://scenes/siege.tscn").instantiate()
			_cold.set(&"save_path", SAVE_PATH)
			_cold.set(&"autoload_save", true)
			add_child(_cold)
			_sub = 1
		1:
			if _in_stage < 20:
				return
			var ward := _cold.get_node_or_null(^"Ward") as Ward
			var box := _cold.get_node_or_null(^"Box") as CharmBox
			_check(ward != null and box != null,
				"a siege opened cold builds its parts", "")
			_check(int(_cold.get(&"wave")) == 4, "and the wave it was on comes back",
				"wave %d" % int(_cold.get(&"wave")))
			# At least what was saved, and not much more: the shed patches itself between
			# waves, and a few frames of that is honest.
			_check(ward != null and ward.health >= 51.0 and ward.health < 56.0
				and is_equal_approx(ward.shield, 12.0),
				"and so does the state of the shed",
				"%.1f, %.1f" % [ward.health if ward != null else -1.0,
					ward.shield if ward != null else -1.0])
			_check(box != null and box.slots.size() == 2
				and box.slots[0] == CharmField.Kind.ICE,
				"and the queue, in order",
				"%s" % [box.slots if box != null else "none"])
			_cold.set(&"autoload_save", false)
			_cold.queue_free()
			_cold = null
			_advance()


## A siege that was won under a shorter siege.
##
## The run was six waves; it is twelve. A save written at the end of the old one says "won",
## and won is a phase in which nothing happens — no gap, no wave, no spawning — so the lake
## sat there and wave seven never came. Lengthening a run must not strand the player who
## finished the old one.
func _stage_outgrown_win() -> void:
	match _sub:
		0:
			var last := int(_main.call(&"waves_to_win"))
			# Won, but only halfway through what the siege is now.
			_main.set(&"wave", maxi(last / 2, 1))
			_main.set(&"_phase", 2)
			_ward.health = Ward.HEALTH
			_ward.shield = 0.0
			_box.slots = PackedInt32Array()
			_check(bool(_main.call(&"save_game")), "a won siege saves", "")

			_cold = load("res://scenes/siege.tscn").instantiate()
			_cold.set(&"save_path", SAVE_PATH)
			_cold.set(&"autoload_save", true)
			add_child(_cold)
			_sub = 1
		1:
			if _in_stage < 20:
				return
			var last := int(_cold.call(&"waves_to_win"))
			_check(int(_cold.get(&"_phase")) == 0,
				"a run with waves left in it picks the fight back up",
				"phase %d" % int(_cold.get(&"_phase")))
			_check(int(_cold.get(&"wave")) == maxi(last / 2, 1) + 1,
				"at the wave after the one that was held",
				"wave %d of %d" % [int(_cold.get(&"wave")), last])
			_check(_cold.get_node_or_null(^"Farewell") == null,
				"and the ending waits until it has been earned", "")
			_cold.set(&"autoload_save", false)
			_cold.queue_free()

			# And a siege that really was held to the end says so, every time it is opened.
			_main.set(&"wave", last)
			_main.set(&"_phase", 2)
			_main.call(&"save_game")
			_cold = load("res://scenes/siege.tscn").instantiate()
			_cold.set(&"save_path", SAVE_PATH)
			_cold.set(&"autoload_save", true)
			add_child(_cold)
			_in_stage = 0
			_sub = 2
		2:
			if _in_stage < 20:
				return
			_check(int(_cold.get(&"_phase")) == 2,
				"a siege held to the last wave stays won",
				"phase %d" % int(_cold.get(&"_phase")))
			_check(_cold.get_node_or_null(^"Farewell") != null,
				"and says so again when it is opened", "")
			_cold.set(&"autoload_save", false)
			_cold.queue_free()
			_cold = null
			_done()
			_advance()


func _check(passed: bool, name: String, detail: String) -> void:
	_ran += 1
	if not passed:
		_failed += 1
	_log("%s %s%s" % ["ok  " if passed else "FAIL", name, "  (%s)" % detail if detail != "" else ""])


func _done() -> void:
	_log("test_siege: %d checks, %d failed" % [_ran, _failed])


func _log(line: String) -> void:
	var path := ProjectSettings.globalize_path(LOG_PATH)
	var file := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(line)
	file.close()
