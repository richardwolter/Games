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

## Where the cut sheet and the choice of birds live. The rows in `USED` were picked off
## tools/pigeon_contact.gd's picture; with the file missing, every row flies.
const CATALOGUE := "res://assets/pigeons.json"
const USED := "res://assets/pigeons_used.json"
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

## Seconds a frame of the walk cycle is held, perched and in the air. A flying bird beats
## its wings; a perched one shuffles.
const PERCH_FRAME := 0.42
const FLY_FRAME := 0.09

## Droppings: how likely one is per second of flight, how long one lasts, and how big it
## is drawn. Perched birds go too, at a lower rate — a bird sitting still all day is what
## actually covers a lake in the stuff.
const POOP_CHANCE := 0.9
const POOP_CHANCE_PERCHED := 0.35
const POOP_LIFE := 55.0
## On open water a splat is washed off in a few seconds rather than sitting on a wave.
const POOP_LIFE_WATER := 6.0
const POOP_SIZE := 3.4

## How close overhead, in tiles, a flying bird has to pass before the angler hears its
## wings, and the shortest gap between two of them being heard. A lake with a dozen birds
## over it would otherwise be a permanent flutter.
const WINGS_NEAR := 3.2
const WINGS_GAP := 1.6

## How long a splat rides the angler before it wears off. Landing one on the player is the
## joke; making them wear it for a minute is not.
const POOP_ON_ANGLER := 6.0

enum State { FLYING, PERCHED, LEAVING }

## Emitted when a bird is taken out of the flock by the net. The lake pays for it; the
## flock does not know what a sludge is.
signal netted(at: Vector2)

## Wired up by lake.gd.
var grid: LakeGrid
var angler: Angler
## The noises. Optional — a silent flock still flies.
var sfx: Sfx

## Every bird, as a row of the flock. Small enough to be an array of dictionaries and clear
## enough to be worth it.
var birds: Array = []

## Splats, as `{at, born, on_angler}`.
var droppings: Array = []

## Set false by the harness so a test lake does not fill up with birds it did not ask for.
var spawning: bool = true

var _sheet: Texture2D
## Row index -> its three frames in the air, as atlas rectangles.
var _frames := {}

## Row index -> the same bird's standing frames. Empty for a row the sheet has none for,
## which falls back to the flight cycle.
var _still := {}
var _rows: Array[int] = []

var _time: float = 0.0
var _rethink: float = 0.0

## Whether the flock that should already be here has been put here. See `settle`.
var _settled: bool = false
var _rng := RandomNumberGenerator.new()

## When wings were last heard, on this node's own clock.
var _wings_at: float = -1000.0


func _ready() -> void:
	_rng.seed = 4242
	_load_art()


## Read the cut sheet and the choice of rows. False means no art, and the flock stays
## empty rather than drawing rectangles at the player.
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

	# The first block of each row is the three frames of a bird in the air, wings out. The
	# second is the same bird standing: a perched pigeon shuffles, it does not hover in place
	# over the mug it is sitting on, which is what drawing the flight cycle at a slower frame
	# rate looked like. Later blocks are the same again at other canvas sizes and unused.
	for cell: Dictionary in book["cells"]:
		var block := int(cell["block"])
		if int(cell["row"]) == 0 or block > 1:
			continue
		var row := int(cell["row"])
		var into := _frames if block == 0 else _still
		if not into.has(row):
			into[row] = []
		var box: Array = cell["region"]
		(into[row] as Array).append(
			Rect2(float(box[0]), float(box[1]), float(box[2]), float(box[3]))
		)

	# Read as whole numbers: JSON hands every number over as a float, and a float 7.0 is
	# not the same key as the int 7 the frames are stored under.
	var wanted: Array[int] = []
	var choice: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(USED))
	if choice != null and choice.has("rows"):
		for row: float in choice["rows"] as Array:
			wanted.append(int(row))
	for row: int in _frames:
		if wanted.is_empty() or wanted.has(row):
			_rows.append(row)
	_rows.sort()
	return not _rows.is_empty()


## How many birds the lake in front of the player can support. Read off what the grid
## actually drew last rebuild, which is exactly "floating rubbish the player can see".
func target_count() -> int:
	if grid == null or _rows.is_empty() or not spawning:
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
func perched_near(from: Vector2, radius: float) -> Array[int]:
	var out: Array[int] = []
	if grid == null:
		return out
	for i in range(birds.size() - 1, -1, -1):
		var bird: Dictionary = birds[i]
		if int(bird["state"]) != State.PERCHED:
			continue
		if Vector2(grid.tile_of(int(bird["tile"]))).distance_to(from) <= radius:
			out.append(i)
	return out


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
	if _rows.is_empty() or grid == null:
		return false
	var tile := perch if perch >= 0 else _free_perch()
	if tile < 0:
		return false
	var landing := grid.surface_pos(tile)
	# In from beyond the edge of the view, so birds arrive rather than appear.
	var from := landing + Vector2(
		_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)
	).normalized() * 900.0
	birds.append({
		"row": _rows[_rng.randi_range(0, _rows.size() - 1)],
		"state": State.FLYING,
		"tile": tile,
		"at": from,
		"from": from,
		"to": landing,
		"travel": 0.0,
		"span": maxf(from.distance_to(landing), 1.0),
		"facing": 1.0,
		"phase": _rng.randf() * 3.0,
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
	if _settled or grid == null or _rows.is_empty():
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
			bird["at"] = grid.surface_pos(tile) + Vector2(0.0, -_perch_height(tile))
			bird["phase"] = float(bird["phase"]) + delta / PERCH_FRAME
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
	return true


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
	bird["to"] = grid.surface_pos(tile)
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


## How high above the water a bird standing on a stack sits: on top of what is floating
## there rather than in it.
func _perch_height(tile: int) -> float:
	var stack := grid.stacks[tile]
	if stack.is_empty():
		return 0.0
	return grid.defs[stack[stack.size() - 1]].size.y * 0.35


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
	})


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


## The frames to draw a bird from: standing when it is sat on something, flying otherwise.
func _cycle_of(row: int, state: int) -> Array:
	if state == State.PERCHED and _still.has(row):
		return _still[row]
	return _frames[row]


func _draw() -> void:
	for splat: Dictionary in droppings:
		var life := _splat_life(splat)
		var left := clampf(1.0 - (_time - float(splat["born"])) / life, 0.0, 1.0)
		var at: Vector2 = splat["at"]
		# A splat lies on the ground, so it is drawn as a flat ellipse like everything else
		# on this plane.
		draw_circle(at, POOP_SIZE, Color(0.94, 0.94, 0.90, 0.85 * left))
		draw_circle(
			at + Vector2(POOP_SIZE * 0.6, POOP_SIZE * 0.25), POOP_SIZE * 0.55,
			Color(0.88, 0.88, 0.83, 0.7 * left)
		)

	if _sheet == null:
		return
	for bird: Dictionary in birds:
		var frames: Array = _cycle_of(int(bird["row"]), int(bird["state"]))
		var frame: Rect2 = frames[posmod(int(bird["phase"]), frames.size())]
		var at: Vector2 = bird["at"]
		var span := frame.size * SCALE
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
			# A shadow on the water under a flying bird, which is what says it is above the
			# lake rather than floating on it.
			draw_circle(ground, span.x * 0.3, Color(0.0, 0.0, 0.0, 0.16 * fade))

		var facing := float(bird["facing"])
		var box := Rect2(at - Vector2(span.x * 0.5, span.y), span)
		if facing < 0.0:
			box = Rect2(box.position + Vector2(span.x, 0.0), Vector2(-span.x, span.y))
		draw_texture_rect_region(_sheet, box, frame, Color(1.0, 1.0, 1.0, fade))
