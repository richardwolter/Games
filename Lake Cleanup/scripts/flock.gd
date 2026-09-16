## The pigeons: the only living thing on the lake, and a reason to look at it.
##
## They perch on floating rubbish, which is what makes them a mechanic rather than
## decoration — a filthy lake is covered in birds and a clean one has nowhere for them to
## stand, so the flock thins out as the player wins. A perched bird can be netted for a
## handful of sludge on the spot: no yard slot, no ferry run, just a bonus for spotting one
## and casting at it instead of at the junk it is sitting on.
##
## One node draws the whole flock, the way the lake and the shed room do. Twenty birds are
## twenty rows in an array and one `_draw`, not twenty nodes with twenty scripts.
class_name Flock
extends Node2D

## Where the cut sheet and the choice of birds live.
##
## `CATALOGUE` is the mechanical cut — every rectangle on the sheet, found by
## tools/slice_pigeons.gd. `BIRDS` is the authored half: which of those rectangles are one
## bird, and which birds fly on this lake. The two are separate for the reason
## tools/decor_sets.json is separate from the decoration sheet — gap detection finds the
## rectangles, only a person can say what they are. With `BIRDS` missing, every bird flies.
const CATALOGUE := "res://assets/pigeons.json"
const BIRDS := "res://assets/pigeon_birds.json"
const SHEET := "res://assets/Pigeons/Original Diminsions/Pigeon Sprite Sheet.png"

## How big a bird is drawn, as a multiple of its own pixels. The art is eleven pixels
## across and the lake's rubbish is drawn at twice its own size (`Lake.SPRITE_SCALE`), so
## this keeps a pigeon and a floating mug in proportion — and whole, so it sits on the art grid.
const SCALE := 2.0

## One bird per this many pieces of rubbish on screen, up to a cap. The flock is a reading
## of how dirty the water in front of the player is.
const PIECES_PER_BIRD := 260
const MOST_BIRDS := 14

## How often the flock counts itself and decides whether to call more in or send some away.
const RETHINK := 2.5

## Where a bird starts to fade as it crosses the shore, and where it is gone, as fractions of
## the lake's own edge. Just past the waterline: the bank is drawn land and a bird over it is
## fine for a moment, but nothing should be drawn out in the void past it.
const BANK_FADE := 1.0
const BANK_GONE := 1.12

## Flight, in world pixels a second, and how high a bird arcs on the way to a perch.
const FLY_SPEED := 150.0
const ARC_HEIGHT := 34.0

## How long a bird will sit before it fancies a different piece of rubbish, in seconds.
const PERCH_MIN := 6.0
const PERCH_MAX := 20.0

## Seconds a frame of the flap is held. A flying bird beats its wings.
const FLY_FRAME := 0.09

## The two poses a perched bird has, and the shuffle between them.
##
## The sheet gives each bird exactly two standing pictures: up on its legs, and sat down
## with them tucked away. That is not a cycle and it was never meant to be played as one —
## it is a bird settling and shifting its weight. So a pose is held for a stretch and then
## rolled again, mostly landing on standing. A bird lands standing, whatever it does next.
##
## Numbers by eye, to be retuned in play (2026-09-16).
const POSE_STAND := 0
const POSE_SIT := 1
const POSE_MIN := 1.2
const POSE_MAX := 3.5
const SIT_ODDS := 0.3

## Droppings: how likely one is per second of flight, and how long one lasts. Perched birds
## go too, at a lower rate — a bird sitting still all day is what actually covers a lake in
## the stuff.
const POOP_CHANCE := 0.9
const POOP_CHANCE_PERCHED := 0.35
## Roughly halved, all three (2026-09-16, Richard: they can vanish a little quicker).
const POOP_LIFE := 28.0
## On open water a splat is washed off in a few seconds rather than sitting on a wave.
const POOP_LIFE_WATER := 3.5

## A splat is a blob of whole art pixels grown off its own seed, not two circles.
##
## Every splat used to be the same pair of discs at the same offset, so a lake under a
## flock was covered in one shape repeated — which reads as a decal, not as mess. These
## are grown a cell at a time from the middle, each one different, on the art grid the
## rest of the world is drawn on (`Skirt`'s blades are made the same way and for the same
## reason). `POOP_CELLS` is the body, `POOP_SPECKS` the loose pixels flicked off it, and
## `POOP_SPECK_OUT` how far out those may land, in cells.
const POOP_PIXEL := 2.0
const POOP_CELLS := 7
const POOP_SPECKS := 3
const POOP_SPECK_OUT := 3

## The two tones a splat is drawn in: the body, and the drier cells round its edge.
const POOP_INK := Color(0.94, 0.94, 0.90, 0.85)
const POOP_INK_DRY := Color(0.86, 0.86, 0.80, 0.70)

## A flying bird's shadow, as a multiple of the day's own ink and the most it may reach.
##
## The day's ink is set for sand and grass. On the lake — darker, and darker still away
## from the island — it cannot be seen at all, which is the bargain `Boat.SHADE_GAIN`
## already strikes for the hull. Lighter than the hull's, because a pigeon is not a boat.
## By eye; retune freely.
const SHADE_GAIN := 2.4
const SHADE_MOST := 0.45

## What height takes off a shadow: at the top of its arc a bird's shadow is this much
## smaller and this much fainter than it is on the water.
const SHADE_SHRINK := 0.3
const SHADE_THIN := 0.45

## The rim on a perched bird that the net could actually reach (2026-09-16, Richard: they
## are hard to see against the lake).
##
## The find's own trick — the picture stamped again a little out on each of four sides, so
## only its edge shows past the bird drawn over it — in a pale blue-white rather than the
## finds' gold. Gold on this lake means treasure, and a pigeon is worth a handful of
## sludge, not a keepsake.
const RIM_STEP := 1.0
const RIM_OFFSETS: Array[Vector2] = [
	Vector2(-1.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, -1.0), Vector2(0.0, 1.0)
]
const RIM_TONE := Color(0.86, 0.94, 1.0)

## How close overhead, in tiles, a flying bird has to pass before the angler hears its
## wings, and the shortest gap between two of them being heard. A lake with a dozen birds
## over it would otherwise be a permanent flutter.
const WINGS_NEAR := 3.2
const WINGS_GAP := 1.6

## How long a splat rides the angler before it wears off. Landing one on the player is the
## joke; making them wear it for a minute is not.
const POOP_ON_ANGLER := 3.0

enum State { FLYING, PERCHED, LEAVING }

## Emitted when a bird is taken out of the flock by the net. The lake pays for it; the
## flock does not know what a sludge is.
signal netted(at: Vector2)

## Wired up by lake.gd.
var grid: LakeGrid
var angler: Angler
## The noises. Optional — a silent flock still flies.
var sfx: Sfx
## The daylight, for the flying birds' shadows. Without one, no shadow: a guessed sun is
## worse than none, since it would disagree with every other shadow in the scene.
var day: DayCycle
## The player's net, asked whether a perched bird is inside reach and so worth rimming.
## Optional — with no net, nothing is rimmed.
var net: CastNet

## Every bird, as a row of the flock. Small enough to be an array of dictionaries and clear
## enough to be worth it.
var birds: Array = []

## Splats, as `{at, born, on_angler}`.
var droppings: Array = []

## Set false by the harness so a test lake does not fill up with birds it did not ask for.
var spawning: bool = true

var _sheet: Texture2D

## The birds in use, each `{bird, name, fly: Array[Rect2], stand: Rect2, sit: Rect2}`. A
## bird is a bird here: its flap and its two poses are one row of this array, so nothing
## downstream can pair a white dove's wings with a street pigeon's legs.
var _kinds: Array[Dictionary] = []

var _time: float = 0.0
var _rethink: float = 0.0

## The pale rim under the perched birds the net could reach. Its own child, behind this
## node's drawing, because the rim is a shader trick and the birds themselves are not.
var _rim: BirdRim

## Whether the flock that should already be here has been put here. See `settle`.
var _settled: bool = false
var _rng := RandomNumberGenerator.new()

## When wings were last heard, on this node's own clock.
var _wings_at: float = -1000.0


func _ready() -> void:
	_rng.seed = 4242
	_load_art()
	_rim = BirdRim.new()
	_rim.name = &"BirdRim"
	_rim.flock = self
	add_child(_rim)


## Read the cut sheet and the authored birds. False means no art, and the flock stays
## empty rather than drawing rectangles at the player.
##
## The sheet is laid out by action, not by bird: a row's first block is one bird's flap,
## and its later blocks are three *other* birds standing and sitting. So the pairing cannot
## be read off the cut — it comes from `BIRDS`, by name.
func _load_art() -> bool:
	var text := FileAccess.get_file_as_string(CATALOGUE)
	if text.is_empty():
		return false
	var book: Dictionary = JSON.parse_string(text)
	if book == null or not book.has("cells"):
		return false

	_sheet = Art.texture(SHEET)
	if _sheet == null:
		return false

	var boxes := {}
	for cell: Dictionary in book["cells"]:
		var box: Array = cell["region"]
		boxes[String(cell["name"])] = Rect2(
			float(box[0]), float(box[1]), float(box[2]), float(box[3])
		)

	var chosen: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BIRDS))
	if chosen == null or not chosen.has("birds"):
		return false
	for entry: Dictionary in chosen["birds"] as Array:
		# `use` missing reads as in: a hand-written file that lists a bird at all means it.
		if not bool(entry.get("use", true)):
			continue
		if not boxes.has(String(entry["stand"])):
			continue
		var fly: Array[Rect2] = []
		for name: String in entry["fly"] as Array:
			if boxes.has(name):
				fly.append(boxes[name])
		if fly.is_empty():
			continue
		# A bird with no sit picture sits the way it stands. Every bird on this sheet has
		# one; a hand-written file need not.
		var stand: Rect2 = boxes[String(entry["stand"])]
		_kinds.append({
			"bird": int(entry.get("bird", _kinds.size() + 1)),
			"name": String(entry.get("name", "")),
			"fly": fly,
			"stand": stand,
			"sit": boxes.get(String(entry.get("sit", "")), stand),
		})
	return not _kinds.is_empty()


## The birds in use, for the harness and for anything that wants to know what is flying.
func kinds() -> Array[Dictionary]:
	return _kinds


## How many birds the lake in front of the player can support. Read off what the grid
## actually drew last rebuild, which is exactly "floating rubbish the player can see".
func target_count() -> int:
	if grid == null or _kinds.is_empty() or not spawning:
		return 0
	return mini(grid.drawn_pieces / PIECES_PER_BIRD, MOST_BIRDS)


## Is a bird sitting on this tile? Returns its index in `birds`, or -1.
func bird_on(tile: int) -> int:
	for i in birds.size():
		var bird: Dictionary = birds[i]
		if bird["state"] == State.PERCHED and int(bird["tile"]) == tile:
			return i
	return -1


## Every bird sat within `radius` tiles of a point, highest index first so a caller may
## take them all without its own indices shifting under it.
##
## Asked in tile space rather than by tile index: the net's mouth is a circle of a radius
## that changes as it purses, and the ring of tiles it covers is that circle rounded to
## whole tiles. A bird on the tile the rounding dropped was a bird sitting visibly inside
## the net that the net went straight past.
func footprint(i: int) -> Array:
	var bird: Dictionary = birds[i]
	var at: Vector2 = bird["at"]
	# No sheet: roughly a pigeon's size, so a net still catches birds with the art missing.
	var span := Vector2(16.0, 16.0) * SCALE
	if _sheet != null:
		var frame := frame_of(bird)
		if frame.size.x > 0.0:
			span = frame.size * SCALE
	# The sprite stands on `at`, so its middle is half its height above it.
	return [at - Vector2(0.0, span.y * 0.5), span * 0.5]


## Take a bird out of the flock — the net has it. Returns where it was, for the splash.
func take(index: int) -> Vector2:
	if index < 0 or index >= birds.size():
		return Vector2.ZERO
	var at: Vector2 = (birds[index] as Dictionary)["at"]
	birds.remove_at(index)
	netted.emit(at)
	queue_redraw()
	return at


## Put a bird on the water, flying in from off screen towards a perch. Used by the flock
## itself and by the harness, which does not wait around for one to wander in.
func add_bird(perch: int = -1) -> bool:
	if _kinds.is_empty() or grid == null:
		return false
	var tile := perch if perch >= 0 else _free_perch()
	if tile < 0:
		return false
	var landing := grid.perch_point(tile)
	# In from beyond the edge of the view, so birds arrive rather than appear.
	var from := landing + Vector2(
		_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)
	).normalized() * 900.0
	birds.append({
		# Picked once and kept for life: a bird does not change species mid-flight.
		"kind": _rng.randi_range(0, _kinds.size() - 1),
		"state": State.FLYING,
		"tile": tile,
		"at": from,
		"from": from,
		"to": landing,
		"travel": 0.0,
		"span": maxf(from.distance_to(landing), 1.0),
		"facing": 1.0,
		"phase": _rng.randf() * 3.0,
		"pose": POSE_STAND,
		"pose_for": _rng.randf_range(POSE_MIN, POSE_MAX),
		"rest": _rng.randf_range(PERCH_MIN, PERCH_MAX),
	})
	queue_redraw()
	return true


## Fill the lake with the birds it should already have, sitting down.
##
## The flock is built to grow: one bird called in every RETHINK seconds, each flying in from
## nine hundred pixels off screen. That is right while the game is running and wrong at the
## moment it starts — a lake thick with rubbish opened on an empty sky and took most of a
## minute to look inhabited. This is that minute, done at once: every bird the water can
## support, already perched, with its rest clock part way through so they do not all get up
## and leave together.
##
## Runs once, on the first frame the grid is there to be asked. Nothing calls it twice: after
## that the flock keeps itself up in its own time.
func settle() -> void:
	if _settled or grid == null or _kinds.is_empty():
		return
	var want := target_count()
	# Not yet: on the first frame the grid exists but has not been filled, so the lake it is
	# asked about is empty and wants no birds at all. Marking the flock settled there is how
	# it stayed empty for the whole run.
	if want <= 0:
		return
	_settled = true
	while birds.size() < want:
		if not add_bird():
			break
		var bird: Dictionary = birds[birds.size() - 1]
		# Landed rather than arriving: the flight is the part that has already happened.
		bird["state"] = State.PERCHED
		bird["at"] = bird["to"]
		bird["travel"] = 1.0
		bird["rest"] = _rng.randf_range(0.0, PERCH_MAX)
		# Part way through a pose as well, or a whole flock settles into the same one and
		# shuffles in step, which is worse than not shuffling at all.
		_roll_pose(bird)
		bird["pose_for"] = _rng.randf_range(0.0, POSE_MAX)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if grid != null:
		if not _settled:
			settle()
		_rethink -= delta
		if _rethink <= 0.0:
			_rethink = RETHINK
			_keep_up()

	for i in range(birds.size() - 1, -1, -1):
		if not _step(birds[i], delta):
			birds.remove_at(i)
	_fade_droppings(delta)
	# Nothing on the water, nothing to repaint. Birds and their mess both animate, so a
	# flock that has any is worth a frame; an empty sky over a clean lake is not.
	if not birds.is_empty() or not droppings.is_empty():
		queue_redraw()
		# The rim is a child with its own drawing, and what it draws changes as the angler
		# walks even when no bird has moved.
		_rim.queue_redraw()


## Call birds in or send them away, so the flock matches the water it is over.
func _keep_up() -> void:
	var want := target_count()
	var here := birds.size()
	if here < want:
		add_bird()
		return
	if here <= want:
		return
	# One at a time, and the ones already sitting still go first: a bird crossing the lake
	# turning round mid-flight reads as a bug.
	for bird: Dictionary in birds:
		if bird["state"] == State.PERCHED:
			_send_away(bird)
			return
	_send_away(birds[0])


func _send_away(bird: Dictionary) -> void:
	bird["state"] = State.LEAVING
	bird["tile"] = -1
	bird["from"] = bird["at"]
	bird["to"] = bird["at"] + Vector2(
		_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)
	).normalized() * 1100.0
	bird["travel"] = 0.0
	bird["span"] = maxf((bird["from"] as Vector2).distance_to(bird["to"]), 1.0)


## One bird, one frame. False means it is gone.
func _step(bird: Dictionary, delta: float) -> bool:
	match int(bird["state"]):
		State.PERCHED:
			# It rides the piece it is standing on, swell and all, which is what makes a
			# perched bird look like it is really on the water.
			var tile := int(bird["tile"])
			if grid.height_of(tile) <= 0:
				# Whatever it was standing on has been netted out from under it.
				_hop(bird)
				return true
			bird["at"] = grid.perch_point(tile)
			bird["pose_for"] = float(bird["pose_for"]) - delta
			if float(bird["pose_for"]) <= 0.0:
				_roll_pose(bird)
			bird["rest"] = float(bird["rest"]) - delta
			_maybe_poop(bird, delta, POOP_CHANCE_PERCHED)
			if float(bird["rest"]) <= 0.0:
				_hop(bird)
		State.FLYING, State.LEAVING:
			bird["phase"] = float(bird["phase"]) + delta / FLY_FRAME
			var span := float(bird["span"])
			bird["travel"] = minf(float(bird["travel"]) + FLY_SPEED * delta / span, 1.0)
			var travel := float(bird["travel"])
			var from: Vector2 = bird["from"]
			var to: Vector2 = bird["to"]
			var flat := from.lerp(to, travel)
			# Up and down again: a bird crossing a lake is not a ruler.
			bird["at"] = flat - Vector2(0.0, sin(travel * PI) * ARC_HEIGHT)
			# The sheet's birds are drawn walking left, so a bird heading right is the
			# flipped one.
			bird["facing"] = 1.0 if to.x < from.x else -1.0
			_maybe_wings(bird)
			_maybe_poop(bird, delta)
			if travel >= 1.0:
				if int(bird["state"]) == State.LEAVING:
					return false
				bird["state"] = State.PERCHED
				bird["rest"] = _rng.randf_range(PERCH_MIN, PERCH_MAX)
				# On its legs, whatever it does next: a bird that lands already sat down
				# has put its feet away in mid-air.
				bird["pose"] = POSE_STAND
				bird["pose_for"] = _rng.randf_range(POSE_MIN, POSE_MAX)
	return true


## Pick the pose a perched bird holds next, and for how long. Rolled rather than swapped,
## so standing can follow standing and the shuffle has no beat to it.
func _roll_pose(bird: Dictionary) -> void:
	bird["pose"] = POSE_SIT if _rng.randf() < SIT_ODDS else POSE_STAND
	bird["pose_for"] = _rng.randf_range(POSE_MIN, POSE_MAX)


## Off to another piece of rubbish, or away altogether when there is nothing left to sit
## on. This is how a lake being cleaned empties itself of birds without anything having to
## decide that it should.
func _hop(bird: Dictionary) -> void:
	var tile := _free_perch()
	if tile < 0:
		_send_away(bird)
		return
	bird["state"] = State.FLYING
	bird["tile"] = tile
	bird["from"] = bird["at"]
	bird["to"] = grid.perch_point(tile)
	bird["travel"] = 0.0
	bird["span"] = maxf((bird["from"] as Vector2).distance_to(bird["to"]), 1.0)


## A tile with rubbish on it, in view, that no other bird has already claimed.
##
## Sampled rather than searched: the basin holds eight thousand tiles and the flock only
## wants one of them, so it throws darts at the part of it the player is looking at and
## gives up if the water there is clear.
func _free_perch() -> int:
	var box := grid.view
	if box.size.x <= 0.0 or box.size.y <= 0.0:
		return -1
	for attempt in 24:
		var at := box.position + Vector2(
			_rng.randf() * box.size.x, _rng.randf() * box.size.y
		)
		var tile := grid.tile_at(at)
		if tile < 0 or grid.height_of(tile) <= 0:
			continue
		if Iso.island_fraction(float(grid.tile_of(tile).x), float(grid.tile_of(tile).y)) < 1.0:
			continue
		if bird_on(tile) >= 0 or _claimed(tile):
			continue
		return tile
	return -1


## Is another bird already on its way to this tile?
func _claimed(tile: int) -> bool:
	for bird: Dictionary in birds:
		if int(bird["tile"]) == tile:
			return true
	return false


## A bird passing over the angler, heard rather than seen. Tied to how close it actually
## comes, so the sound is a bird going over rather than birdsong playing somewhere.
func _maybe_wings(bird: Dictionary) -> void:
	if sfx == null or angler == null or _time - _wings_at < WINGS_GAP:
		return
	if Iso.world_to_tile(bird["at"]).distance_to(angler.tile_pos) > WINGS_NEAR:
		return
	_wings_at = _time
	sfx.play_wings()


func _maybe_poop(bird: Dictionary, delta: float, chance: float = POOP_CHANCE) -> void:
	if _rng.randf() > chance * delta:
		return
	var at: Vector2 = bird["at"]
	var flying := int(bird["state"]) != State.PERCHED
	# Where it lands, not where the bird is: a flying bird is drawn lifted off the water by
	# the arc of its flight, and asking the question at the sprite rather than under it put
	# the answer most of a tile north of the splat. On the south bank that is the difference
	# between a lake and the empty ground past it — which is what left a scatter of grey dots
	# under the map after every cast, since a cast sends birds away and they went on dropping
	# all the way out.
	var ground := at + Vector2(0.0, ARC_HEIGHT if flying else 0.0)
	var tile := Iso.world_to_tile(ground)
	# Nothing dropped where the bird itself is not drawn. See `_over_water`.
	if Iso.shore_fraction(tile.x, tile.y) >= BANK_GONE:
		return
	var on_land := Iso.island_fraction(tile.x, tile.y) <= 1.0
	var on_angler := angler != null and angler.tile_pos.distance_to(tile) < 1.0
	droppings.append({
		"at": angler.position - position if on_angler else ground,
		"born": _time,
		"on_angler": on_angler,
		"on_land": on_land,
		"cells": _smudge(),
	})


## One splat's shape: cells on the art grid, as offsets in whole art pixels, with the
## number of body cells first and the loose specks after them so `_draw` can tell the two
## tones apart without a second array.
##
## Grown rather than drawn: start on the middle cell, then take a cell already in the blob
## and add one of its four neighbours, over and over. That makes a connected lump with a
## ragged outline — a smudge — where a radius makes a disc, and no two rolls come out the
## same. The specks are flicked out beyond it, which is what stops the whole thing reading
## as one solid pebble.
func _smudge() -> Array:
	var body: Array[Vector2] = [Vector2.ZERO]
	while body.size() < POOP_CELLS:
		var from: Vector2 = body[_rng.randi_range(0, body.size() - 1)]
		var step := [
			Vector2(1.0, 0.0), Vector2(-1.0, 0.0), Vector2(0.0, 1.0), Vector2(0.0, -1.0)
		][_rng.randi_range(0, 3)] as Vector2
		var cell := from + step
		if not body.has(cell):
			body.append(cell)
	var out: Array = [body.size()]
	out.append_array(body)
	for _speck in POOP_SPECKS:
		out.append(Vector2(
			float(_rng.randi_range(-POOP_SPECK_OUT, POOP_SPECK_OUT)),
			float(_rng.randi_range(-POOP_SPECK_OUT, POOP_SPECK_OUT))
		))
	return out


## How much of a bird is drawn at this spot on the plane: all of it over the lake, none of it
## past the bank, and a short fade between the two so nothing pops.
##
## Measured at the bird's shadow rather than at the bird, because the shadow is where it
## actually is — the drawing is lifted off the water by the arc of its flight.
func _over_water(ground: Vector2) -> float:
	var tile := Iso.world_to_tile(ground)
	var out := Iso.shore_fraction(tile.x, tile.y)
	return clampf((BANK_GONE - out) / maxf(BANK_GONE - BANK_FADE, 0.001), 0.0, 1.0)


## How long this splat sticks: on the angler it wears off, on the water it washes off, on
## the island it stays until the lake forgets it.
func _splat_life(splat: Dictionary) -> float:
	if bool(splat["on_angler"]):
		return POOP_ON_ANGLER
	return POOP_LIFE if bool(splat["on_land"]) else POOP_LIFE_WATER


func _fade_droppings(_delta: float) -> void:
	for i in range(droppings.size() - 1, -1, -1):
		var splat: Dictionary = droppings[i]
		var life := _splat_life(splat)
		if _time - float(splat["born"]) > life:
			droppings.remove_at(i)
		elif bool(splat["on_angler"]) and angler != null:
			# It rides along until it wears off, which is the whole point of it.
			splat["at"] = angler.position - position + Vector2(0.0, -18.0)


## One bird's picture: the frame drawn standing on `at`, facing whichever way, in `tint`.
##
## One place, because the bird, its shadow and its rim all have to land on the same pixels —
## static and given the node to draw on, the way `DogArt.stamp` is, so the rim child draws
## through it too. `base` is a transform to draw under (the shadow's `Shade.lying`) and
## `step` an offset in the bird's own frame (the rim's).
##
## **The mirror turns the canvas over, it does not flip a rectangle.** A `Rect2` of negative
## width degenerates in `draw_texture_rect_region` rather than drawing the picture the other
## way round — the ferry lost most of its hull to exactly that for a day, see `HudButtons.fit`.
## The flock mirrored with a negative rect from the day it was written, so a bird flying east
## never turned round; a shadow and a rim built on the same rect would have gone the same way.
static func stamp(
	on: CanvasItem, sheet: Texture2D, frame: Rect2, at: Vector2, facing: float, tint: Color,
	base: Transform2D = Transform2D.IDENTITY, step: Vector2 = Vector2.ZERO,
	scale_by: float = 1.0
) -> void:
	if sheet == null:
		return
	var span := frame.size * SCALE * scale_by
	var turn := Transform2D(
		Vector2(-1.0 if facing < 0.0 else 1.0, 0.0), Vector2(0.0, 1.0), at
	)
	on.draw_set_transform_matrix(base * turn)
	on.draw_texture_rect_region(
		sheet, Rect2(step + Vector2(-span.x * 0.5, -span.y), span), frame, tint
	)
	on.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The frame a bird is showing this instant, or an empty rect with no sheet loaded.
##
## Every picture a bird can ever show comes out of its own `kind` — the flap when it is in
## the air, one of its two poses when it is down. The bug this shape exists to make
## impossible: the poses used to be read off the sheet row the flap came from, and that row
## holds three *other* birds, so a perched pigeon changed colour every frame.
func frame_of(bird: Dictionary) -> Rect2:
	if _sheet == null or _kinds.is_empty():
		return Rect2()
	var kind: Dictionary = _kinds[posmod(int(bird.get("kind", 0)), _kinds.size())]
	if int(bird["state"]) == State.PERCHED:
		return kind["sit"] if int(bird.get("pose", POSE_STAND)) == POSE_SIT else kind["stand"]
	var fly: Array = kind["fly"]
	return fly[posmod(int(bird["phase"]), fly.size())]


## Is this bird sitting still *and* inside what the net could reach? The rim's rule.
##
## `CastNet.in_reach` rather than `can_cast_to`: it answers while a cast is already out, so
## the rim does not blink off for the second and a half the net is in the water.
func catchable(bird: Dictionary) -> bool:
	if net == null or int(bird["state"]) != State.PERCHED:
		return false
	return net.in_reach(bird["at"] + position)


## The sheet, for the rim child, which draws the same frames this node does.
func sheet() -> Texture2D:
	return _sheet


func _draw() -> void:
	for splat: Dictionary in droppings:
		var life := _splat_life(splat)
		var left := clampf(1.0 - (_time - float(splat["born"])) / life, 0.0, 1.0)
		# A row put together by hand — the harness does — has no shape, and draws nothing
		# rather than bringing the frame down.
		var cells: Array = splat.get("cells", [])
		if cells.is_empty():
			continue
		# On the art grid, so a splat is made of the same pixels the world is drawn in
		# rather than lying across them at whatever fraction the bird happened to be at.
		var foot := ((splat["at"] as Vector2) / POOP_PIXEL).round() * POOP_PIXEL
		var body := int(cells[0])
		for i in range(1, cells.size()):
			var tone := POOP_INK if i <= body else POOP_INK_DRY
			draw_rect(
				Rect2(foot + (cells[i] as Vector2) * POOP_PIXEL, Vector2(POOP_PIXEL, POOP_PIXEL)),
				Color(tone.r, tone.g, tone.b, tone.a * left)
			)

	if _sheet == null:
		return
	for bird: Dictionary in birds:
		var frame := frame_of(bird)
		var at: Vector2 = bird["at"]
		var ground := Vector2(at.x, at.y + sin(float(bird["travel"]) * PI) * ARC_HEIGHT)

		# Faded out at the bank. A bird arrives from nine hundred pixels beyond the shore and
		# leaves for eleven hundred more, and every one of those pixels used to be drawn: a
		# cast that cleared enough rubbish to send three birds away put three grey specks and
		# their shadows sailing out over the bank and off into the nothing beyond it, which
		# read as the game leaking particles rather than as birds going home.
		var fade := _over_water(ground)
		if fade <= 0.0:
			continue

		if int(bird["state"]) != State.PERCHED:
			_draw_shadow(bird, frame, ground, fade)

		stamp(self, _sheet, frame, at, float(bird["facing"]), Color(1.0, 1.0, 1.0, fade))


## A flying bird's shadow on the water: its own frame again, laid out away from the sun by
## `Shade.lying`, the way the angler, the dog, the trees and the hull all cast.
##
## It used to be a black disc under the bird — the one shadow left on the lake that was not
## the shape of the thing making it, and the one that ignored the sun the rest of the world
## leans away from.
##
## Drawn from the shadow's own anchor on the water rather than from the bird, and shrunk and
## thinned by how high the arc has carried it: a shadow the same size whatever the height is
## what makes a bird look like it is sliding along the surface.
func _draw_shadow(bird: Dictionary, frame: Rect2, ground: Vector2, fade: float) -> void:
	if day == null:
		return
	var up := sin(float(bird["travel"]) * PI)
	var ink := minf(day.ink * SHADE_GAIN, SHADE_MOST) * fade * (1.0 - SHADE_THIN * up)
	if ink <= 0.002:
		return
	# Standing on the origin of the shadow's own frame: `lying` has already put that origin
	# where the bird's feet would be.
	stamp(
		self, _sheet, frame, Vector2.ZERO, float(bird["facing"]), Shade.tint(ink),
		Shade.lying(ground, day.lean, day.stretch), Vector2.ZERO,
		1.0 - SHADE_SHRINK * up
	)


## The pale rim round a perched bird the net could reach.
##
## The finds' own trick, in the finds' own shader with its gold turned down to a blue-white:
## the bird's picture stamped again a pixel out on each of four sides, behind the flock's own
## drawing, so the bird covers the middle and only the edge shows. `rim.gdshader` reads a
## modulate of pure green as "make this a flat silhouette", so the four copies come out as
## one outline rather than four tinted birds.
class BirdRim extends Node2D:
	var flock: Flock

	func _init() -> void:
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/rim.gdshader")
		mat.set_shader_parameter(
			"rim_gold", Vector3(Flock.RIM_TONE.r, Flock.RIM_TONE.g, Flock.RIM_TONE.b)
		)
		material = mat
		show_behind_parent = true

	func _draw() -> void:
		if flock == null or flock.sheet() == null:
			return
		for bird: Dictionary in flock.birds:
			if not flock.catchable(bird):
				continue
			var frame := flock.frame_of(bird)
			# Through the flock's own stamp, so the rim goes down with exactly the mirror
			# and the size the bird does — on this node, so the green reaches this node's
			# shader and not the birds themselves.
			for step: Vector2 in Flock.RIM_OFFSETS:
				Flock.stamp(
					self, flock.sheet(), frame, bird["at"], float(bird["facing"]),
					Color(0.0, 1.0, 0.0, 1.0), Transform2D.IDENTITY,
					step * Flock.RIM_STEP
				)
