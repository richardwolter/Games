class_name RunManager
extends Node2D

## Owns the floor and swaps rooms. The player node is a child of THIS node,
## not of any room, so travelling between rooms never touches player state,
## never loads a scene, and never needs a transition state to sit in.

## Caches per run, counting a mirrored pair as one. Raised with the floor: four
## over forty-three rooms is a long walk between pickups.
##
## Raised again once caches stopped being free. A cache is now two waves of its
## own before the pedestals rise, so more of them is more fighting rather than
## more handouts -- the old count was balanced against walking in and taking one.
const ITEM_ROOM_COUNT: int = 9
const ITEM_PATHS: PackedStringArray = [
	"res://items/rusty_needle.tres",
	"res://items/adrenaline_shot.tres",
	"res://items/hollow_point.tres",
	"res://items/split_dose.tres",
	"res://items/scalpel_grind.tres",
	"res://items/shrink_serum.tres",
	"res://items/arm_mutation.tres",
	"res://items/scalpelrang.tres",
	"res://items/broken_needle.tres",
	"res://items/liquid_nitrogen.tres",
]

## Rampage escalation. Seconds between spawns in EVERY room, halving on this
## period, with a floor so the whole floor does not become one solid wall of
## white cells. Owned here rather than in Room: the pressure is a property of
## how long the rampage has been running, so ducking into a fresh room must not
## reset it.
const RAMPAGE_START_INTERVAL: float = 3.2
const RAMPAGE_HALVING_TIME: float = 40.0
const RAMPAGE_MIN_INTERVAL: float = 0.45
## Spawns per tick. Goes up on a slower clock than the interval so the ramp has
## two distinct stages rather than one curve.
const RAMPAGE_BATCH_TIME: float = 55.0
const RAMPAGE_MAX_BATCH: int = 4

@export var run_seed: int = 0

@onready var player: Player = $Player
@onready var room_host: Node2D = $RoomHost
@onready var readout: Label = $HUD/Readout
@onready var health_label: Label = $HUD/Health
@onready var banner: Label = $HUD/Banner
@onready var minimap: Minimap = $HUD/Minimap
@onready var run_timer_label: Label = $HUD/RunTimer
@onready var dna_label: Label = $HUD/Dna
@onready var damage_vignette: DamageVignette = $HUD/DamageVignette

var map: MapData
var current_cell: Vector2i = Vector2i.ZERO
var room: Room

var _pool: Array[Item] = []
## This run's copies -> the path each was built from. See path_of.
var _paths_by_item: Dictionary = {}
## Everything the run has not put on a pedestal yet. Drained by `_stock_cache`,
## and deliberately never refilled: once it is empty the draw falls through to
## the wider tiers, which is exactly the "only repeat after the pool is
## exhausted" rule.
var _offer_bag: Array[Item] = []
var _rng := RandomNumberGenerator.new()
var _debug_next: int = 0
var _camera: Camera2D
## True when the whole room is on screen, so the camera should sit still like it
## always did rather than drift around behind the player.
var _room_fits: bool = true
## Wall-clock length of the run so far. Stopped rather than reset when the run
## ends, so the final time stays on screen to be read.
var _run_time: float = 0.0
var _run_timing: bool = true
## The endgame. Set once the last thing worth fighting is dead, never unset.
var _rampage: bool = false
var _rampage_time: float = 0.0
var _escaped: bool = false
## DNA picked up off the floor this run. Held here, not banked as it is
## collected: the payout is a single event at the end of the run, so a crash
## mid-run cannot leave half of it in the save file.
var _dna_collected: int = 0
## Latched the first time the run ends, so death and escape cannot both pay out
## and a corpse sliding into a portal is not worth two runs.
var _run_over: bool = false


func _ready() -> void:
	_build_pool()

	# The seed is exported on the scene, which is no use once the prep menu is
	# what launches the run -- there is nowhere to set an export through
	# change_scene_to_file. MetaProgress carries it across the swap so replaying
	# a specific map is still one line from anywhere.
	if MetaProgress.next_run_seed != 0:
		run_seed = MetaProgress.next_run_seed
		MetaProgress.next_run_seed = 0
	_rng.seed = run_seed if run_seed != 0 else randi()
	map = MapData.generate(_rng.seed, ITEM_ROOM_COUNT)
	_offer_bag = _pool.duplicate()
	# After the bag is filled, because the carry takes itself back out of it.
	_grant_carried()

	# Rooms used to be exactly one screen, so there was no camera at all. Lanes
	# are 1700 long against a 1280 viewport, so one is needed now -- but only
	# where it earns its keep: a room that still fits gets the old fixed view,
	# because a camera drifting around a room you can already see whole is worse
	# than no camera.
	_camera = Camera2D.new()
	_camera.name = "Camera"
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 8.0
	add_child(_camera)
	_camera.make_current()

	# With an expanding viewport the visible area is a property of the display,
	# not a constant. Whether a room fits on screen -- which decides between a
	# fixed camera and a following one -- has to be re-answered whenever that
	# area changes, or an ultrawide gets a camera chasing a room it can see all
	# of, and a resize back leaves the player able to walk off the edge.
	get_viewport().size_changed.connect(_frame_camera)

	player.health_changed.connect(_on_health_changed)
	player.damaged.connect(func() -> void: damage_vignette.flash())
	player.died.connect(func() -> void:
		_banner("YOU DIED -- the uncle was not saved")
		_end_run("died")
	)

	minimap.set_map(map)
	_enter(map.start_cell, "")
	_refresh_readout()
	var nests := PackedStringArray()
	for cell: Vector2i in map.boss_cells:
		nests.append("%s (%s)" % [map.name_of(cell),
			MapData.BossKind.keys()[map.boss_kind_of(cell)]])
	print("run seed: %d | entry: %s | infections: %s" % [
		map.seed_used, map.name_of(map.start_cell), ", ".join(nests),
	])


## Stocks one cache, the first time it is walked into. Each cache holds TWO
## items and gives up one: the choice is the room.
##
## Drawn LATE rather than at generation, because what counts as a fresh item is
## not knowable up front -- it depends on what the player has taken by the time
## they get here. Once drawn the contents are written into the map and never
## re-drawn, so leaving and coming back cannot reroll a cache.
##
## Variety before repetition, in three tiers:
##   1. items never yet OFFERED this run (`_offer_bag`),
##   2. once that is empty, anything the player does not already OWN,
##   3. and only if he owns the entire pool, whatever is left.
## So a duplicate can only ever appear once every distinct item has been seen.
##
## Mirrored caches -- the same cache on both sides of a fork -- are stocked from
## one draw, or the mirroring would just move the reroll from placement to
## contents and the choice would be a slot machine again.
## Builds this run's item pool, with whatever upgrades have been bought already
## folded in. Every item in the run comes from here.
func _build_pool() -> void:
	var table := MetaProgress.table()
	for path in ITEM_PATHS:
		var src := load(path) as Item
		if src == null:
			push_warning("Item failed to load: %s" % path)
			continue
		var copy := _upgraded_copy(src, path, MetaProgress.level_of(path), table)
		_pool.append(copy)
		_paths_by_item[copy] = path


## The path an item in this run's pool was built from.
##
## `_upgraded_copy` throws the path away and renames the copy ("<name> +2"), so
## there is no recovering it from the resource. Kept as a side table here rather
## than as a field on Item, because item.gd's own doc says an item is authored
## data and never behaviour -- a field that means nothing in the editor and is
## only filled at run time invites somebody to author it.
##
## Keyed by the copy itself, which is safe for exactly the reason _upgraded_copy
## gives: there is one copy per item per run and nothing downstream may make
## another.
func path_of(item: Item) -> String:
	return String(_paths_by_item.get(item, ""))


## Hands the player whatever they carried out of their last finished run.
##
## Granted from THIS run's pool rather than reloaded from disk, which is the
## whole reason a path is stored instead of a resource: it arrives with whatever
## upgrades have been bought since it was won, and it is the same object identity
## that `_filtered`, `Pedestal.item` and `Player.grant` all compare against.
func _grant_carried() -> void:
	var path := MetaProgress.take_carried()
	if path == "":
		return
	for it in _pool:
		if path_of(it) != path:
			continue
		player.grant(it)
		# Out of the bag as well as out of the offer tiers. `_draw_offer` already
		# skips what the player OWNS, but the bag is the "not yet offered this
		# run" list -- leaving a carried item in it makes the very first cache
		# likelier to fall through to a repeat, which is the exact thing the bag
		# exists to prevent.
		_offer_bag.erase(it)
		return
	push_warning("Carried item '%s' is not in this run's pool; dropped." % path)


## One item as this run will see it: a private copy, plus the modifiers for every
## level the player owns.
##
## The copy is not an optimisation, it is the whole safety story. `load()` is
## CACHED -- the Item it returns is the same object the editor has open and the
## same one every other `load()` of that path gets -- so appending to its
## `modifiers` would write the upgrade into the file on disk and stack it again
## on the next run. Duplicated deeply, and unconditionally even at level 0, so
## there is one rule instead of two.
##
## Exactly one copy per item per run, and nothing downstream may make another:
## `_filtered`, `Pedestal.item` and `Player.grant` all compare items by identity.
func _upgraded_copy(src: Item, path: String, level: int, table: UpgradeTable) -> Item:
	var copy := src.duplicate(true) as Item
	if level <= 0 or table == null:
		return copy
	copy.display_name = "%s +%d" % [src.display_name, level]
	var extra := table.modifiers_for(path, level)
	for i in extra.size():
		var m := extra[i].duplicate(true) as StatModifier
		# Namespaced, because the pipeline's tie-break is the id and two
		# modifiers that agree on phase, priority AND id sort arbitrarily -- which
		# is the order-dependence tools/test_pipeline.gd exists to catch. An
		# upgrade adding to a stat the base item already touches is the normal
		# case, not an edge one. "@" never appears in an authored id, so this
		# cannot collide with a hand-written one either.
		m.id = StringName("%s@u%d#%d" % [extra[i].id, level, i])
		copy.modifiers.append(m)
	return copy


func _stock_cache(cell: Vector2i) -> void:
	if not (map.rooms[cell]["items"] as Array).is_empty():
		return

	var offer: Array[Item] = []
	while offer.size() < 2:
		var pick := _draw_offer(offer)
		if pick == null:
			break
		offer.append(pick)
		_offer_bag.erase(pick)

	for twin in _mirror_cells(cell):
		map.rooms[twin]["items"] = offer


## One item for a cache being stocked, honouring the tiers above. `already` is
## what this same pedestal pair has drawn so far -- a choice between an item and
## itself is not a choice, so it is excluded at every tier.
func _draw_offer(already: Array[Item]) -> Item:
	var owned := player.loadout.items
	for candidates: Array[Item] in [
		_filtered(_offer_bag, already, owned),
		_filtered(_pool, already, owned),
		_filtered(_pool, already, [] as Array[Item]),
	]:
		if not candidates.is_empty():
			return candidates[_rng.randi_range(0, candidates.size() - 1)]
	return null


func _filtered(source: Array[Item], already: Array[Item], owned: Array[Item]) -> Array[Item]:
	var out: Array[Item] = []
	for it in source:
		if it in already or it in owned:
			continue
		out.append(it)
	return out


## A cache cell and every sibling-branch cache it was mirrored into, itself
## included. A cache on the spine is its own only member.
func _mirror_cells(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = [cell]
	var id: String = map.rooms[cell]["id"]
	for fork: Dictionary in BodyPlan.FORKS:
		for branch: String in fork["branches"]:
			var members: Array = BodyPlan.branch_cells(branch)
			var index := members.find(id)
			if index < 0:
				continue
			for other: String in fork["branches"]:
				if other == branch:
					continue
				var twin: Array = BodyPlan.branch_cells(other)
				if index < twin.size():
					out.append(BodyPlan.cell_of(twin[index]))
			return out
	return out


func _process(delta: float) -> void:
	if _run_timing:
		_run_time += delta
		_update_run_timer()
	# `_run_over` covers the death case too: the body on the floor should not
	# still be raising the spawn rate around itself.
	if _rampage and not _run_over:
		_rampage_time += delta
		_drive_rampage()
	if Input.is_action_just_pressed(&"toggle_fullscreen"):
		_toggle_fullscreen()
	if Input.is_action_just_pressed(&"debug_grant_item"):
		_grant_debug_item()
	if _camera != null and not _room_fits:
		# Camera2D's own limits do the clamping, so the view never leaves the
		# room even though the player can stand right against a wall.
		_camera.global_position = player.global_position


func _enter(cell: Vector2i, arrival_link: String) -> void:
	# Shots in flight belong to the room you left.
	for p in get_tree().get_nodes_in_group(&"projectiles"):
		p.queue_free()

	if room != null:
		room.queue_free()
		room = null

	current_cell = cell
	# Committed before the room is built, so it goes up already knowing which of
	# its doorways no longer exist.
	var before := map.forks_taken.size()
	map.commit_fork(map.rooms[cell]["id"])
	var sealed_something := map.forks_taken.size() > before
	map.mark_seen(cell)

	# Before the build, not after: Room reads the cache contents while spawning
	# its pedestals.
	if map.kind_of(cell) == MapData.RoomKind.ITEM and not map.is_cleared(cell):
		_stock_cache(cell)

	room = Room.new()
	room.name = "Room"
	room_host.add_child(room)
	room.build(map, cell, _rng, arrival_link)
	room.door_used.connect(_on_door_used)
	room.item_taken.connect(_on_item_taken)
	room.dna_collected.connect(_on_dna_collected)
	room.cleared.connect(_on_room_cleared)
	room.escaped.connect(_on_escaped)

	# The rampage is a property of the run, so a freshly built room joins it
	# already in progress at whatever intensity the clock has reached.
	if _rampage:
		_drive_rampage()
		room.set_rampage(true)
		if map.is_escape_cell(cell):
			room.add_exit_portal(map.escape_name(cell))

	# Arriving through the north door means stepping in at the north side.
	player.global_position = room.entry_point_for_link(arrival_link)
	_frame_camera()

	minimap.set_current(cell)
	# A permanent consequence with no feedback reads as a bug, so the banner says
	# what was given up instead of naming the room.
	_banner(_sealed_banner(cell) if sealed_something else _banner_for(cell))


## F11. The game boots fullscreen, and a fullscreen game with no way back to a
## window is hostile to anyone developing it or running it on a second monitor.
func _toggle_fullscreen() -> void:
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full \
		else DisplayServer.WINDOW_MODE_FULLSCREEN)


## Sets the camera up for the room just entered: fixed if the whole room is
## visible, following-but-clamped if it is not.
func _frame_camera() -> void:
	if _camera == null or room == null:
		return
	var view := Vector2(get_viewport_rect().size)
	var origin := room.global_position
	_room_fits = room.interior.x <= view.x and room.interior.y <= view.y

	_camera.limit_left = int(origin.x)
	_camera.limit_top = int(origin.y)
	_camera.limit_right = int(origin.x + room.interior.x)
	_camera.limit_bottom = int(origin.y + room.interior.y)

	# Snap on arrival either way. Smoothing across a room transition would pan
	# the camera through the wall from wherever the last room was.
	_camera.position_smoothing_enabled = false
	_camera.global_position = origin + room.interior * 0.5 if _room_fits \
		else player.global_position
	_camera.reset_smoothing()
	_camera.position_smoothing_enabled = not _room_fits


func _banner_for(cell: Vector2i) -> String:
	var part := map.name_of(cell)
	# Once the rampage is on, the room's identity matters less than whether it
	# is a way out, so that is what the banner says.
	if _rampage:
		if map.is_escape_cell(cell):
			return "%s -- THIS IS A WAY OUT" % part.to_upper()
		return "%s -- RAMPAGE, keep moving" % part
	match map.kind_of(cell):
		MapData.RoomKind.BOSS:
			return "%s -- THE INFECTION" % part.to_upper()
		MapData.RoomKind.ITEM:
			return "%s -- supply cache" % part
		MapData.RoomKind.START:
			return "%s -- entry wound" % part
		_:
			return part


## Names the branch the player just closed off. Their own room is named too --
## the choice only makes sense as this instead of that.
func _sealed_banner(cell: Vector2i) -> String:
	var fork := BodyPlan.fork_for_branch(map.rooms[cell]["id"])
	var lost: Array[String] = []
	for branch: String in fork["branches"]:
		if branch != map.rooms[cell]["id"]:
			lost.append(BodyPlan.PARTS[branch]["name"] as String)
	return "%s -- %s sealed behind you" % [map.name_of(cell), " and ".join(lost)]


func _on_door_used(link_id: String) -> void:
	# The link says where it goes. The arriving room finds the same link on its
	# own side, so which wall you come out of is never worked out here.
	var e := map.exit_by_link(current_cell, link_id)
	if e.is_empty():
		return
	_enter(e["to"], link_id)


func _on_room_cleared() -> void:
	var kind := map.kind_of(current_cell)
	if kind == MapData.RoomKind.COMBAT or kind == MapData.RoomKind.BOSS:
		map.mark_cleared(current_cell)
	if kind == MapData.RoomKind.BOSS:
		# Killing an infection is the middle of the run, not the end of it. What
		# it buys you is the right to leave -- and only once they are ALL dead.
		#
		# The count is on the banner because without it the player has no signal
		# that the run is not over, and the rampage quietly failing to start
		# afterwards reads as a bug rather than as a job unfinished.
		var left := map.boss_count() - map.bosses_killed()
		if left > 0:
			_banner("%s -- infection killed, %d still in him"
				% [map.name_of(current_cell).to_upper(), left])
		else:
			_banner("%s -- the last infection is dead"
				% map.name_of(current_cell).to_upper())
	minimap.set_current(current_cell)
	_check_rampage_trigger()


func _on_item_taken(item: Item) -> void:
	# The whole offer is spent, not just the pedestal that was touched. Leaving
	# the sibling behind would turn the choice into a delay.
	map.rooms[current_cell]["items"] = [] as Array[Item]
	map.mark_cleared(current_cell)
	player.grant(item)
	_banner("picked up: %s" % item.display_name)
	_refresh_readout()
	minimap.set_current(current_cell)


## The rampage starts once the infection is dead and most of the body has been
## fought through. Checked on every clear rather than tracked with a counter --
## MapData already knows, and a second copy of that knowledge is a second thing
## to get wrong.
func _check_rampage_trigger() -> void:
	if _rampage or not map.rampage_ready():
		return
	_rampage = true
	_rampage_time = 0.0
	minimap.set_rampage(true, map.escape_cells())
	_banner("WHITE BLOOD CELL RAMPAGE -- get out: mouth, pelvis, or your way in")
	_drive_rampage()
	room.set_rampage(true)
	if map.is_escape_cell(current_cell):
		room.add_exit_portal(map.escape_name(current_cell))


## Pushes the current intensity into whichever room the player is standing in.
func _drive_rampage() -> void:
	if room == null:
		return
	room.rampage_interval = maxf(
		RAMPAGE_MIN_INTERVAL,
		RAMPAGE_START_INTERVAL * pow(0.5, _rampage_time / RAMPAGE_HALVING_TIME)
	)
	room.rampage_batch = mini(
		1 + int(_rampage_time / RAMPAGE_BATCH_TIME), RAMPAGE_MAX_BATCH)


func _on_escaped() -> void:
	if _escaped:
		return
	_escaped = true
	var total := int(_run_time)
	_banner("OUT -- %s, %02d:%02d" % [map.escape_name(current_cell), total / 60, total % 60])
	_end_run("escaped")


## The run is over, whichever way it went. Tallies the payout, banks it, and puts
## the results panel up over the frozen body.
##
## Latched, because both endings can fire in the same breath -- a player killed
## by the last white cell as he steps into the portal must be paid once.
func _end_run(outcome: String) -> void:
	if _run_over:
		return
	_run_over = true
	_run_timing = false
	# Nothing left to drive, and nothing left to spawn on top of him while the
	# numbers are being read.
	if room != null:
		room.set_rampage(false)
	# Physics stays ON for a death: Player emits `died` at the START of the death
	# slide, and freezing here would stop him mid-air. Escaping has no animation
	# to finish, so he is parked.
	if outcome != "died":
		player.set_physics_process(false)

	var result := _tally(outcome)
	MetaProgress.last_result = result
	MetaProgress.add_dna(int(result["total"]))
	MetaProgress.save_game()
	_show_results(result)


## Everything the results panel prints. The room count comes from MapData's own
## `clear_progress`, which is the same count the rampage gate uses -- a payout
## that disagreed with the thing that let you out would be indefensible.
func _tally(outcome: String) -> Dictionary:
	var progress := map.clear_progress()
	var bosses_killed := map.bosses_killed()
	var bosses_total := map.boss_count()
	var cost := 0
	var table := MetaProgress.table()
	if table != null:
		cost = table.cost_per_level

	var result := DnaPayout.breakdown(_dna_collected, progress.x,
		bosses_killed, bosses_total, outcome == "escaped", cost)
	result["outcome"] = outcome
	result["time"] = int(_run_time)
	result["rooms_cleared"] = progress.x
	result["rooms_total"] = progress.y
	# The old singular `boss_killed` is deliberately GONE rather than kept
	# alongside these. Every reader takes it off a string key with a default, so
	# a stale copy would keep working and keep lying about a two-boss run.
	result["bosses_killed"] = bosses_killed
	result["bosses_total"] = bosses_total
	result["where"] = map.escape_name(current_cell) if outcome == "escaped" \
		else map.name_of(current_cell)
	return result


func _show_results(result: Dictionary) -> void:
	var panel := ResultsPanel.new()
	panel.name = "Results"
	add_child(panel)
	# The win-only rule lives HERE and not in the panel's own conditional, so
	# there is one place that decides whether a run earned a carry.
	var carry: Array[Dictionary] = []
	if result.get("outcome", "died") == "escaped":
		carry = _carry_options()
	panel.build(result, MetaProgress.dna, carry)
	panel.carry_chosen.connect(func(path: String) -> void:
		MetaProgress.set_carried(path)
	)
	panel.continued.connect(func() -> void:
		get_tree().change_scene_to_file(MetaProgress.SCENE_PREP)
	)


## What the player may take with them, from what they actually held this run.
##
## Unique by path: the offer's third tier can hand out an item the player already
## owns once every distinct one has been seen, so a loadout can genuinely hold
## the same item twice, and two identical rows is a picker that looks broken.
##
## Named from the BASE resource rather than from the run's copy, because the copy
## carries a "+2" suffix describing a level this item will be re-derived at next
## run anyway -- the honest label is the item, not the level it happened to be.
func _carry_options() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	for it in player.loadout.items:
		var path := path_of(it)
		if path == "" or seen.has(path):
			continue
		seen[path] = true
		var base := load(path) as Item
		if base == null:
			continue
		out.append({
			"path": path,
			"name": base.display_name,
			"color": base.pedestal_color,
		})
	return out


func _grant_debug_item() -> void:
	if _pool.is_empty():
		return
	player.grant(_pool[_debug_next % _pool.size()])
	_debug_next += 1
	_refresh_readout()


func _on_dna_collected(value: int) -> void:
	_dna_collected += value
	_refresh_dna()


func _refresh_dna() -> void:
	dna_label.text = "DNA %d" % _dna_collected


func _refresh_readout() -> void:
	readout.text = player.loadout.describe()


func _on_health_changed(current: int, maximum: int) -> void:
	health_label.text = "HP %d / %d" % [current, maximum]


func _update_run_timer() -> void:
	var total := int(_run_time)
	run_timer_label.text = "%02d:%02d" % [total / 60, total % 60]


func _banner(text: String) -> void:
	banner.text = text
