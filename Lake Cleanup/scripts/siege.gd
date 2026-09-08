## The second lake: the same basin, gone bad.
##
## The player cleaned this water once. It came back — thicker than before, and this time
## with something living in it. The verbs do not change: the angler still stands on the
## island and still throws a net at the lake. What changes is what the net is for.
##
## The four yards on the bank have stopped buying. They fabricate now, one charm each:
## ammo, shield, fire and ice. They push those out onto the water, the player nets them in,
## and they queue in a box beside the yard that fires them off in the order they were
## caught. Ammo puts purified water in the boats' and the shed's guns. Shield piles up on
## the shed. Fire and ice go into the net itself, which then stops being a drag and starts
## being something you place: an enchanted cast stays where it lands and burns or freezes
## whatever swims through it.
##
## This is a scene inherited from the lake and a script extending it, not a second copy of
## either. Everything below is what a level is allowed to change — the field it is built
## from, what the ending means, what goes in the save, and what the keys do first. The HUD,
## the shop, the shed, the ferry and the net all come across untouched.
extends "res://scripts/lake.gd"

## A different lake from the same basin. The seed is written into the save and checked on
## load, so a siege save and a cleanup save can never be read into one another.
const SIEGE_SEED := 20260904

## Its own file, so finishing the first lake is not overwritten by losing the second one.
const SIEGE_SAVE_PATH := "user://lake_cleanup_siege.save"

## Where the run before this one is read from, for the purse and the upgrades. Read only,
## and only once, at the first frame of a fresh siege.
const CARRY_FROM := "user://lake_cleanup.save"

## The siege runs in two beats, over and over: a gap with nothing in the water, then a
## wave. The gap is where the shed is patched, the box is fed and the shop is open, so it
## is not dead time — it is the half of the loop the player spends preparing.
enum Phase { GATHER, FIGHT, WON, LOST }

## Seconds of quiet before the first wave, and before each one after it.
const FIRST_GAP := 20.0
const WAVE_GAP := 16.0

## A wave: how many blobs the first one is, how many each one after it adds, and how long
## they take to all be in the water. Spread out rather than dropped in at once, so a wave
## is something arriving rather than something appearing.
const WAVE_BASE := 4
const WAVE_MORE := 2
const WAVE_SPAWN := 9.0

## Every so often the lake sends a proper one, half again as many as the count says.
##
## Twelve waves of the same shape is a chore however hard the numbers get. A big one every
## fourth is what gives the run a rhythm: three you can handle standing where you are, and
## then one you have to prepare for.
const WAVE_BIG_EVERY := 4
const WAVE_BIG := 1.5

## How many waves have to be held to win.
const WAVES_TO_WIN := 12

## How fast the shed patches itself between waves, in points a second. Slow: it is meant to
## take the edge off a bad wave, not to undo one.
const REPAIR_RATE := 3.5

## How long one charm's effect runs, in seconds. All longer than the box's own interval, so
## a well-fed box has several of them live at once and fire and ice end up on the net
## together — which is exactly what stacking is supposed to feel like.
const AMMO_TIME := 10.0
const FIRE_TIME := 12.0
const ICE_TIME := 12.0

## What a lit net does per second to everything standing in it: fire takes health, ice
## takes speed. Ice is a fraction rather than a rate — it is a state, not damage.
const FIRE_BURN := 16.0
const ICE_CHILL := 0.85

## How far the box sits from the yard, in world pixels. Beside it rather than under it, so
## the two crates read as a working corner instead of as one crate drawn twice.
const BOX_OFFSET := Vector2(-104.0, 30.0)

## How often the fleet is given fresh orders, in seconds, and how far off a monster a hull
## tries to sit. The stand-off is well inside the guns' range, so a boat on station is a
## boat shooting rather than a boat still on its way.
const STEER_EVERY := 0.6
const STANDOFF := 5.0

## How far in from its own pier a yard pushes its charms, in tiles. Far enough to be in
## open water, near enough that the pier is obviously where it came from.
const SPOUT_OUT := 2.4

var _swarm: SludgeSwarm
var _charms: CharmField
var _box: CharmBox
var _volley: Volley
var _ward: Ward
var _laid: LaidNet
var _defeat: Defeat

## Which wave is next or running, and where in the beat the siege is.
var wave: int = 1
var _phase: int = Phase.GATHER
var _phase_in: float = FIRST_GAP
var _to_spawn: int = 0
var _spawn_in: float = 0.0

## Seconds of ammo left in the guns, and until the fleet is told where to go next.
var _ammo_for: float = 0.0
var _steer_in: float = 0.0

## A siege read off disk before there was anything to read it into.
##
## The lake loads the save in its own _ready, and the siege's own parts cannot be built
## until that _ready has finished making the grid and the yard they hang off. So a save
## arriving at startup is put here and applied the moment the parts exist. A save loaded any
## other time — the key, the button — lands on parts that are already there and is applied
## on the spot.
var _pending := {}


func _ready() -> void:
	# Before the parent, because the parent loads the save in its own _ready.
	if save_path == SAVE_PATH:
		save_path = SIEGE_SAVE_PATH
	# A siege with no save of its own is a first arrival, and so is one walked into through
	# the settings door: both start empty and both are owed the upgrades the first lake was
	# left with. The flag is read before the parent, which is where it is cleared.
	var fresh := autoload_save and (start_fresh or not FileAccess.file_exists(save_path))
	super()
	_build_siege()
	if not _pending.is_empty():
		_apply_siege(_pending)
		_pending = {}
	if fresh:
		_carry_over()


## Everything the siege adds to the lake, built in code and wired by hand, the way the
## flock and the splashes already are. No scenes: a monster, a charm and a shot are rows in
## arrays, and the nodes below are the four things that own those arrays.
func _build_siege() -> void:
	_ward = Ward.new()
	_ward.name = &"Ward"
	# Above the island and the hut, below the boats: the dome is over the shed, and a ferry
	# passing in front of the island still passes in front of it.
	_ward.z_index = 10
	_ward.z_as_relative = false
	_ward.position = Iso.tile_to_world(Iso.ISLAND_CENTRE.x, Iso.ISLAND_CENTRE.y)
	_ward.sfx = _sfx
	_ward.fell.connect(_on_shed_fell)
	add_child(_ward)

	_swarm = SludgeSwarm.new()
	_swarm.name = &"Swarm"
	# On the water, above the rubbish and below the splashes: a monster is a thing floating
	# on the lake, and the water it throws up goes over it.
	_swarm.z_index = 6
	_swarm.z_as_relative = false
	_swarm.grid = _grid
	_swarm.sfx = _sfx
	_swarm.splash = _splash
	_swarm.struck.connect(_on_struck)
	_swarm.died.connect(_on_blob_died)
	add_child(_swarm)

	_charms = CharmField.new()
	_charms.name = &"Charms"
	_charms.z_index = 6
	_charms.z_as_relative = false
	_charms.grid = _grid
	_charms.sfx = _sfx
	_charms.splash = _splash
	_charms.making = false
	_charms.spouts = _spouts()
	add_child(_charms)

	_box = CharmBox.new()
	_box.name = &"Box"
	_box.z_index = 4
	_box.z_as_relative = false
	_box.position = _yard.position + BOX_OFFSET
	_box.fired.connect(_on_charm_fired)
	add_child(_box)

	_laid = LaidNet.new()
	_laid.name = &"LaidNets"
	# On the water with the monsters, under the splashes: a net left on the lake is on the
	# lake, and what the burning throws up goes over it.
	_laid.z_index = 6
	_laid.z_as_relative = false
	_laid.sfx = _sfx
	_laid.splash = _splash
	add_child(_laid)

	_volley = Volley.new()
	_volley.name = &"Volley"
	# Over the boats that fire it.
	_volley.z_index = 13
	_volley.z_as_relative = false
	_volley.swarm = _swarm
	_volley.splash = _splash
	_volley.sfx = _sfx
	_volley.boats = _boats
	add_child(_volley)

	# The net learns about the charms, and the box learns what the net brings in. That pair
	# of lines is the whole of the second lake's loop.
	_net.charms = _charms
	_net.caught_charm.connect(_on_charm_caught)
	_net.left_behind.connect(_on_net_left)


## Every hull, kitted out as the lake kits it out, and then sent out on patrol.
##
## There is nothing to ferry in this lake, so a fleet left to the ferry's own logic sits at
## the dock all siege. The guns ammo loads are on these hulls: where they are is the whole
## of what they are worth, so they circle the island instead, wave or no wave.
func _fit_out(boat: Boat, index: int) -> void:
	super(boat, index)
	boat.patrol = true


## Where each yard pushes its charms out from: just off its own pier, in open water.
func _spouts() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for spot: Dropoff in _dropoffs:
		var inward := (Iso.CENTRE - spot.berth).normalized()
		var at := spot.berth + inward * SPOUT_OUT
		# A pier whose water is somehow not water gets its charms at the berth itself
		# rather than nowhere at all.
		out.append(at if Iso.in_lake(int(at.x), int(at.y)) else spot.berth)
	return out


## Which lake this is.
func _level_seed() -> int:
	return SIEGE_SEED


func level_name() -> String:
	return "siege"


## The last level. Its ending is an ending.
func _next_scene() -> String:
	return ""


## Nothing floats on this lake but what its yards make.
##
## The basin starts empty. It was seeded with grades of muck, and that turned the siege
## into two games being played at once: a fight, and a fishing trip through eighteen
## thousand pieces of grey rubbish that nobody buys any more. The only things on this water
## are ammo, shield, fire and ice, so a cast is always aimed at one of them.
func _fills_the_lake() -> bool:
	return false


## The catalogue is still here for anything that needs a piece to point at, but nothing is
## laid down from it.
func _all_defs() -> Array[TrashDef]:
	var all := _sludge_defs()
	_dress(all)
	return all


## Six grades of muck, sorted the way the fill wants them: light skin on top, heavy clots
## at the bottom of a stack. Tiers run past what an unupgraded net can lift, so the first
## thing a returning player notices is that their old net bounces off the deep stuff.
func _sludge_defs() -> Array[TrashDef]:
	var p := TrashDef.Kind.PLASTIC
	var w := TrashDef.Kind.TIMBER
	var m := TrashDef.Kind.METAL
	var r := TrashDef.Kind.RUBBER
	return [
		_def("Scum", p, Vector2(16.0, 9.0), 2.6, 0.5, 0.15, 0,
			Color(0.30, 0.34, 0.26)),
		_def("Slick", r, Vector2(20.0, 10.0), 2.2, 0.8, 0.25, 0,
			Color(0.20, 0.22, 0.20)),
		_def("Weed", w, Vector2(18.0, 14.0), 1.7, 1.4, 0.6, 1,
			Color(0.22, 0.30, 0.22)),
		_def("Sludge", p, Vector2(19.0, 16.0), 1.2, 2.4, 1.1, 2,
			Color(0.17, 0.20, 0.16)),
		_def("Clot", m, Vector2(21.0, 18.0), 0.7, 3.6, 2.2, 3,
			Color(0.13, 0.15, 0.13)),
		_def("Tar", r, Vector2(22.0, 19.0), 0.35, 5.0, 3.4, 4,
			Color(0.08, 0.09, 0.09)),
	]


func _process(delta: float) -> void:
	super(delta)
	_run_waves(delta)
	_run_effects(delta)
	_steer_the_fleet(delta)
	pollution = _how_bad_it_is()


## Point the hulls at the fight.
##
## The boats do not know what a monster is, and should not — a boat is a hull with a gun on
## it and a lake to cross. This is the part that knows: it hands each hull a piece of water
## worth being on, and moves it as the fight moves.
##
## One hull to a monster where it can be managed, nearest first, and a hull that has been
## given a target the others already took goes for the next one out. A fleet that all picks
## the same blob is one boat with three hulls.
func _steer_the_fleet(delta: float) -> void:
	_steer_in -= delta
	if _steer_in > 0.0:
		return
	_steer_in = STEER_EVERY

	var taken: Array[int] = []
	for boat: Boat in _boats:
		if not boat.patrol:
			continue
		var quarry := _quarry_for(boat, taken)
		if quarry < 0:
			# Nothing left to hunt: back to its own business, wandering the basin.
			boat.patrol_at = Vector2.INF
			continue
		taken.append(quarry)
		boat.patrol_at = _stand_off(boat, _swarm.tile_of(quarry))


## The nearest blob this hull is allowed to take. Ones the fleet has already claimed are
## skipped, unless everything has been claimed — three hulls and one monster left should
## still be three hulls going for it.
func _quarry_for(boat: Boat, taken: Array[int]) -> int:
	var best := -1
	var closest := INF
	var fallback := -1
	var fallback_gap := INF
	for i in _swarm.blobs.size():
		var blob: Dictionary = _swarm.blobs[i]
		if int(blob["state"]) == SludgeSwarm.State.DYING:
			continue
		var gap := (blob["tile"] as Vector2).distance_to(boat.tile_pos)
		if gap < fallback_gap:
			fallback_gap = gap
			fallback = i
		if taken.has(i):
			continue
		if gap < closest:
			closest = gap
			best = i
	return best if best >= 0 else fallback


## Where to sit to shoot at something: short of it, on its near side, and on water.
##
## Short of it on purpose. A hull that steers into what it is shooting at ends up parked on
## top of a monster with its gun pointing through it, and a boat that has to reach its
## target before it is useful spends the whole wave arriving.
func _stand_off(boat: Boat, quarry: Vector2) -> Vector2:
	var from := boat.tile_pos
	var toward := quarry - from
	if toward.length() < 0.001:
		return quarry
	var at := quarry - toward.normalized() * STANDOFF
	# Beached: the monster is close in to the island or the bank, so sit off it sideways
	# instead of behind it.
	if not Iso.in_lake(int(at.x), int(at.y)):
		var across := Vector2(-toward.y, toward.x).normalized() * STANDOFF
		var port := quarry + across
		if Iso.in_lake(int(port.x), int(port.y)):
			return port
		var starboard := quarry - across
		if Iso.in_lake(int(starboard.x), int(starboard.y)):
			return starboard
		return quarry
	return at


## What the meter reads during a siege.
##
## There is no rubbish in this water to count, and a meter pinned at nothing would say the
## lake was fine while something was eating the shed. So it reads the siege instead: black
## at the start, clearing a little with every wave held, and darkening again while there is
## something in the water. It is the same number the shader takes, so the lake itself gets
## murkier when the swarm is out and lifts when it has been beaten back.
func _how_bad_it_is() -> float:
	if _phase == Phase.WON:
		return 0.0
	var held := float(maxi(wave - 1, 0)) / float(maxi(WAVES_TO_WIN, 1))
	var swimming := clampf(float(_swarm.alive()) * 0.06, 0.0, 0.3)
	return clampf(0.55 + 0.45 * (1.0 - held) - 0.25 * held + swimming, 0.15, 1.0)


## How dirty the water is drawn, everywhere, with nothing floating on it to work it out
## from. The first lake reads its filth off the rubbish tile by tile; this one has no
## rubbish, so the whole basin is simply foul and the map is flat.
const FILTH_EVERYWHERE := 0.82


## The map the water shader reads. Flat, for the reason above: a map built from an empty
## field is a map of nothing, which draws a siege on clear blue holiday water.
func _build_filth_map() -> void:
	var cols := Iso.COLS
	var rows := Iso.ROWS
	var pixels := PackedByteArray()
	pixels.resize(cols * rows)
	pixels.fill(int(round(FILTH_EVERYWHERE * 255.0)))
	if _filth_map == null:
		_filth_map = Image.create_from_data(cols, rows, false, Image.FORMAT_R8, pixels)
		_filth_texture = ImageTexture.create_from_image(_filth_map)
	else:
		_filth_map.set_data(cols, rows, false, Image.FORMAT_R8, pixels)
		_filth_texture.update(_filth_map)
	if _water_material != null:
		_water_material.set_shader_parameter(&"filth_map", _filth_texture)
		_water_material.set_shader_parameter(&"filth_tiles", Vector2(cols, rows))
		_water_material.set_shader_parameter(&"filth_mapped", 1.0)


## A siege has no last piece to fish out, so it has no cleaning to finish. The water is
## empty by design here and would otherwise report itself finished on the first frame.
func _look_for_the_end(_delta: float) -> void:
	pass


## The beat: quiet, wave, quiet, wave. Nothing here decides how hard a wave is beyond its
## number — the wave's own size, the blobs' health and how fast the yards fabricate all
## read that number for themselves.
func _run_waves(delta: float) -> void:
	if _phase == Phase.WON or _phase == Phase.LOST:
		return
	_charms.wave = wave
	match _phase:
		Phase.GATHER:
			# The yards work through the gap as well as through the fight: the point of the
			# quiet is to arrive at the wave with a full box.
			_charms.making = true
			_ward.repair(REPAIR_RATE * delta)
			_phase_in -= delta
			if _phase_in <= 0.0:
				_start_wave()
		Phase.FIGHT:
			if _to_spawn > 0:
				_spawn_in -= delta
				if _spawn_in <= 0.0:
					_spawn_in = WAVE_SPAWN / float(maxi(_wave_size(), 1))
					if _swarm.add_blob(wave):
						_to_spawn -= 1
			elif _swarm.alive() == 0:
				_end_wave()


## How many waves the siege is, for the HUD and for anything else that wants to say where
## the player is in it.
func waves_to_win() -> int:
	return WAVES_TO_WIN


## Is this one of the big ones?
func is_big_wave(which: int = -1) -> bool:
	var w := which if which > 0 else wave
	return w % WAVE_BIG_EVERY == 0


func _wave_size() -> int:
	var count := WAVE_BASE + WAVE_MORE * (wave - 1)
	return int(round(float(count) * (WAVE_BIG if is_big_wave() else 1.0)))


func _start_wave() -> void:
	_phase = Phase.FIGHT
	_to_spawn = _wave_size()
	_spawn_in = 0.0
	if _sfx != null:
		_sfx.play_horn()


func _end_wave() -> void:
	if wave >= WAVES_TO_WIN:
		_win()
		return
	wave += 1
	_phase = Phase.GATHER
	_phase_in = WAVE_GAP
	if _sfx != null:
		_sfx.play_chime()
	# The moment a wave is held is worth keeping without waiting for the autosave.
	save_game()


## The three things that are true for a while: the guns being loaded, the net being lit,
## and what a lit net lying on the water does to whatever swims into it.
func _run_effects(delta: float) -> void:
	_ammo_for = maxf(_ammo_for - delta, 0.0)
	# Ammo is ammo whenever it was caught. Guns that stopped working between waves would
	# make the last charm of a fight worthless, which is a reason not to catch it.
	_volley.armed = _ammo_for > 0.0

	if _laid.nets.is_empty():
		return
	# Every net the player has left out, each doing its own work. The radius each was laid
	# with is the radius it is drawn at, so what is burning and what looks like it is
	# burning are the same circle.
	for net: Dictionary in _laid.nets:
		if float(net["sink"]) > 0.0:
			continue
		_swarm.soak(
			net["tile"], float(net["radius"]),
			FIRE_BURN if bool(net["fire"]) else 0.0,
			ICE_CHILL if bool(net["ice"]) else 0.0,
			delta
		)


## A lit cast has landed. The net is already back in the angler's hands; what was thrown
## stays out there and belongs to the swarm's problems now.
func _on_net_left(tile: Vector2, radius: float, fire: bool, ice: bool) -> void:
	_laid.lay(tile, radius, fire, ice)


## A blow landed on the shed.
func _on_struck(damage: float) -> void:
	_ward.take(damage)


## Something died. Killing things is the siege's other economy, alongside the muck the
## ferry still sells.
func _on_blob_died(at: Vector2, bounty: float) -> void:
	sludge += bounty
	if _splash != null:
		_splash.ripple(at, 26.0)


## The net brought a charm in. Straight into the box, and if the box is full the player is
## told by the charm bouncing rather than by a message: it goes back on the water where
## they caught it.
func _on_charm_caught(kind: int) -> void:
	if _box.put(kind):
		return
	_charms.add_charm(kind, _net.tile_pos)


## A slot went off. This is the whole of what the four charms mean.
func _on_charm_fired(kind: int) -> void:
	match kind:
		CharmField.Kind.AMMO:
			_ammo_for += AMMO_TIME
		CharmField.Kind.SHIELD:
			_ward.add_shield()
		CharmField.Kind.FIRE:
			_net.enchant(CastNet.Charm.FIRE, FIRE_TIME)
		CharmField.Kind.ICE:
			_net.enchant(CastNet.Charm.ICE, ICE_TIME)


## Cleaning the lake is no longer an ending. It is a very good afternoon, and the water
## still has things in it that want the shed.
func _on_lake_cleaned() -> void:
	if _sparkle_at < 1.0:
		_sparkle_at = 1.0


## Held all six. The same closing screen as the first lake, with the words that belong to
## this one and no door out the far side: this is the end of the game.
func _win() -> void:
	_phase = Phase.WON
	_laid.clear()
	_moor_the_fleet()
	_charms.making = false
	_box.running = false
	_volley.armed = false
	if _sfx != null:
		_sfx.play_chime()
	_show_farewell()
	if _farewell != null:
		_farewell.lines = [
			"The water goes quiet, and the shed is still standing.",
			"Thanks for holding the lake!",
		]
	save_game()


## The shed is gone.
func _on_shed_fell() -> void:
	if _phase == Phase.LOST:
		return
	_phase = Phase.LOST
	_charms.making = false
	_box.running = false
	_volley.armed = false
	_swarm.blobs.clear()
	_laid.clear()
	_moor_the_fleet()
	_show_defeat()


func _show_defeat() -> void:
	if _defeat != null:
		return
	_defeat = Defeat.new()
	_defeat.again.connect(_siege_again)
	_defeat.back.connect(_back_to_lake)
	var over := CanvasLayer.new()
	over.name = &"Defeat"
	over.layer = 20
	over.add_child(_defeat)
	add_child(over)
	_hold_the_angler()


## Another go at the siege. The siege's own save goes, the first lake's does not: what was
## earned there was earned, and losing the shed does not take it back.
func _siege_again() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	_wiping = true
	get_tree().reload_current_scene()


## The siege is level two, so its door in the settings leads back to the first lake.
func _other_level_scene() -> String:
	return "res://scenes/main.tscn"


func _other_level_name() -> String:
	return "Back to the clean-up  (level 1)"


func _back_to_lake() -> void:
	_wiping = true
	get_tree().change_scene_to_file("res://scenes/main.tscn")


## The angler stands still while the defeat screen is up, on top of everything the lake
## already freezes them for.
func _hold_the_angler() -> void:
	super()
	if _defeat != null:
		_angler.can_walk = false
		_net.set_pulling(false)


## Call the fleet in. There is nothing left to cover once the siege is over either way, and
## boats going round and round behind a closing screen are a game that has not noticed it
## has finished.
func _moor_the_fleet() -> void:
	for boat: Boat in _boats:
		boat.patrol = false
		boat.patrol_at = Vector2.INF


## The siege's own readouts, handed to the HUD alongside the meter and the purse.
func _update_hud() -> void:
	super()
	_skin.siege = {
		"health": _ward.health_left(),
		"shield": _ward.shield_left(),
		"wave": wave,
		"waves": WAVES_TO_WIN,
		"big": is_big_wave(),
		"note": _wave_note(),
		"ammo": _ammo_for,
		"fire": _net.charm_for(CastNet.Charm.FIRE),
		"ice": _net.charm_for(CastNet.Charm.ICE),
	}


func _wave_note() -> String:
	match _phase:
		Phase.GATHER:
			# Warned rather than surprised: a big wave is worth spending the gap getting
			# ready for, and a player who cannot see it coming cannot spend it.
			var soon := " — a big one" if is_big_wave() else ""
			return "%ds%s" % [ceili(maxf(_phase_in, 0.0)), soon]
		Phase.FIGHT:
			return "%d in the water" % (_swarm.alive() + _to_spawn)
		Phase.WON:
			return "held"
		_:
			return "the shed is down"


func _save_extra(save: Dictionary) -> void:
	save["wave"] = wave
	save["phase"] = _phase
	save["phase_in"] = _phase_in
	save["shed_health"] = _ward.health
	save["shield"] = _ward.shield
	save["box"] = _box.slots
	save["ammo_for"] = _ammo_for


## Read the siege back.
##
## The swarm is not restored blob by blob. A wave is re-formed from its number instead: the
## exact position of a monster mid-swim is not what the player was keeping, and a save that
## puts eleven of them back a stride from the shed is a save that loses the game for them
## on load.
func _load_extra(save: Dictionary) -> void:
	# Nothing to put it in yet: this is the save the lake read during its own _ready, and
	# the swarm, the box and the shed's ward are built a few lines later.
	if _ward == null:
		_pending = save.duplicate(true)
		return
	_apply_siege(save)


func _apply_siege(save: Dictionary) -> void:
	wave = maxi(int(save.get("wave", 1)), 1)
	_phase = int(save.get("phase", Phase.GATHER))
	_ward.health = clampf(float(save.get("shed_health", Ward.HEALTH)), 0.0, Ward.HEALTH)
	_ward.shield = clampf(float(save.get("shield", 0.0)), 0.0, Ward.SHIELD_MAX)
	_box.slots = PackedInt32Array(save.get("box", PackedInt32Array()))
	_ammo_for = maxf(float(save.get("ammo_for", 0.0)), 0.0)
	# Whatever it was in the middle of, it comes back as the quiet before that wave.
	if _phase == Phase.FIGHT:
		_phase = Phase.GATHER

	# A siege that was won under a shorter siege.
	#
	# The run was six waves and is twelve. A save written at the end of the old one says
	# "won", and won is a phase in which nothing happens at all — no gap, no wave, no
	# spawning — so the lake simply sat there and wave seven never came. If there is more
	# siege than the save thought there was, there is more siege: the fight picks up at the
	# next wave and the ending waits until it has actually been earned.
	if _phase == Phase.WON and wave < WAVES_TO_WIN:
		wave = mini(wave + 1, WAVES_TO_WIN)
		_phase = Phase.GATHER

	if _phase == Phase.GATHER:
		_phase_in = maxf(float(save.get("phase_in", WAVE_GAP)), WAVE_GAP * 0.5)
	elif _phase == Phase.WON:
		# Held the lot, and opened again. The closing words are shown every time a finished
		# run is opened, for the same reason the first lake's are: they carry the only
		# acknowledgement the run gets, and hiding them behind "you have already seen this"
		# leaves a player on a lake with nothing to do and nothing to read.
		_win()
	elif _phase == Phase.LOST:
		_show_defeat()


## Bring the last run's standing across into this one.
##
## Read out of the first lake's save by hand rather than through load_game, which would
## refuse it — the seed guard is doing exactly its job. Only what the player earned comes
## over: the purse, the nine upgrade tracks, the finds and where they were put in the shed,
## and the audio settings. The field, the yard, the fleet's cargo and the meter are this
## lake's own business.
func _carry_over() -> void:
	if not FileAccess.file_exists(CARRY_FROM):
		return
	var file := FileAccess.open(CARRY_FROM, FileAccess.READ)
	if file == null:
		return
	var raw: Variant = file.get_var(true)
	file.close()
	var save := raw as Dictionary
	if save == null:
		return

	sludge = float(save.get("sludge", 0.0))
	var levels := save.get("levels", {}) as Dictionary
	net_width_level = _saved_level(levels, &"net_width")
	net_strength_level = _saved_level(levels, &"net_strength")
	net_range_level = _saved_level(levels, &"net_range")
	reel_level = _saved_level(levels, &"reel")
	net_hold_level = _saved_level(levels, &"net_hold")
	boat_speed_level = _saved_level(levels, &"boat_speed")
	cargo_level = _saved_level(levels, &"cargo")
	skimmer_level = _saved_level(levels, &"skimmer")

	unlocked.clear()
	for name: String in save.get("unlocked", []) as Array:
		if _sheets == null or _sheets.has(StringName(name)):
			unlocked.append(name)
	decor.clear()
	for row: Dictionary in save.get("decor", []) as Array:
		if not unlocked.has(String(row.get("piece", ""))):
			continue
		decor.append(row.duplicate())
	if _room != null:
		_room.unlocked = unlocked
		_room.decor = decor

	var wanted := mini(int(levels.get("fleet", 0)), MAX_BOATS - 1)
	while fleet_level < wanted:
		fleet_level += 1
		_add_boat()

	_music_level.value = clampf(float(save.get("music_level", _music_level.value)), 0.0, 1.0)
	_music_on.button_pressed = bool(save.get("music", true))
	_sfx_level.value = clampf(float(save.get("sfx_level", _sfx_level.value)), 0.0, 1.0)
	_sfx_on.button_pressed = bool(save.get("sfx", true))
	_push_music()
	_push_sfx()

	_push_net_numbers()
	_push_boat_numbers()
