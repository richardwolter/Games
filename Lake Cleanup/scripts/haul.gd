## Rubbish flying from wherever it was to wherever it is going next.
##
## The net used to land and the pile used to grow, with nothing in between: a cast ended
## with a number in the corner changing, and a boat was loaded by the number going back
## down. This is the half second that was missing at both ends. Every piece arcs over the
## island, spinning, and drops where it is going — which is also when the yard or the hull
## actually takes it, so what is on screen and what is counted are the same thing.
##
## One node draws all of them, like the flock and the splashes. A piece in flight is a row
## in an array, not a scene.
class_name Haul
extends Node2D

## How long one piece is in the air.
const FLIGHT := 0.62

## How high it arcs, in world pixels, and how much of that a heavy piece gives up. A fridge
## lobbed on the same lazy parabola as a cup reads as weightless.
const ARC := 74.0
const ARC_HEAVY := 0.55

## Gap between one piece leaving and the next, so a full net empties as a stream rather
## than a single clump — and the longest the whole volley may take to leave, because a
## late-game hold is a hundred pieces and a hundred times a tenth of a second is not a
## stream, it is a queue. Past that many, they go closer together instead of later.
const STAGGER := 0.09
const SPREAD := 1.1

## Shortest gap between two pops. Only enough to collapse pieces landing on the same frame
## into one sound: past that, a piece landing is a pop, and a load coming down is a run of
## them. Wider than the stagger and the run turns into an uneven half of itself, which is
## worse than either a stream or a single knock.
const POP_GAP := 0.07

## Turns a piece makes on the way over, and how big it is drawn at each end of the flight.
## It grows towards the camera at the top of the arc and settles back down.
const SPIN := 1.4
const SIZE_FROM := 0.62
const SIZE_TO := 0.78
const SIZE_PEAK := 0.24

## Emitted the moment a piece lands. Whatever it was thrown to takes it here; until then it
## belongs to nothing. `tag` is whatever the thrower passed in, which is how one node can
## serve the yard and every hull without knowing what either of them is.
signal arrived(def_index: int, tag: Variant)

## Set by lake.gd, for drawing the pieces and for the pops.
var grid: LakeGrid
var sfx: Sfx

## Pieces in the air, as `{def, from, lead, to, follow, tag, age, wait, spin, lift}`.
var _flying: Array = []

## When the last pop was heard, on the engine's own clock. A stamp rather than a countdown
## because this node stops processing the moment the air is empty, and a countdown that is
## not counted down stays where it was left — which silences the next landing, and the one
## after that, for as long as nothing happens to tick it.
var _pop_at: float = -1000.0

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 5501
	set_process(false)


## How many pieces are on their way. The lake counts these against the yard's free space,
## so a cast cannot be promised room that something already in the air is going to take.
func flying() -> int:
	return _flying.size()


## How many are on their way to one place. Cargo crossing to a hull is not about to land in
## the yard, and counting it against the yard would stop the player casting every time a
## boat loaded.
func flying_to(tag: Variant) -> int:
	var count := 0
	for piece: Dictionary in _flying:
		if piece["tag"] == tag:
			count += 1
	return count


## Throw one piece from here to there.
##
## `slot` is its place in the volley and only sets how long it waits its turn. `follow` is
## for a target that will not hold still — a boat at its berth rides the swell, and cargo
## thrown at where it was floats through the deck — in which case `to` is read as an offset
## in that node's own space. `lead` is the same for the other end: a volley leaves the
## angler over the better part of a second, and an angler who walks off in that second
## should not leave a stream of junk hanging in the air behind them. `tag` comes back with
## the piece when it lands.
func send(
	def_index: int,
	from: Vector2,
	to: Vector2,
	slot: int = 0,
	of: int = 1,
	follow: Node2D = null,
	tag: Variant = null,
	lead: Node2D = null,
	gap_scale: float = 1.0
) -> void:
	var def := grid.defs[def_index] if grid != null else null
	# Heavier things are thrown flatter. Size stands in for weight: this game has no mass.
	var heft := clampf(def.size.x / 44.0, 0.0, 1.0) if def != null else 0.0
	# A fixed target is scattered over, so a volley lands as a heap instead of a column. A
	# followed one is a stowage spot that was worked out on purpose, so it is left alone.
	var scatter := (
		Vector2.ZERO if follow != null
		else Vector2(_rng.randf_range(-26.0, 26.0), _rng.randf_range(-11.0, 11.0))
	)
	_flying.append({
		"def": def_index,
		# Held as an offset from whatever it is coming off, so it goes on coming off it.
		"from": from - lead.position if lead != null else from,
		"lead": lead,
		"to": to + scatter,
		"follow": follow,
		"tag": tag,
		"age": 0.0,
		"wait": float(slot) * _gap(of, gap_scale),
		"spin": _rng.randf_range(-SPIN, SPIN),
		"lift": ARC * lerpf(1.0, ARC_HEAVY, heft) * _rng.randf_range(0.85, 1.15),
	})
	set_process(true)
	queue_redraw()


## How long apart the pieces of a volley of `count` set off. A tenth of a second each until
## that would take too long, and then however little it takes to get them all away inside
## `SPREAD`.
##
## `gap_scale` is the Fast Sell upgrade, and it is the gap it scales, never `FLIGHT`: every
## piece keeps its own arc and they only leave closer together, so a fast ferry pours its
## hold instead of trickling it and no piece is ever drawn whizzing. The floor a maxed track
## can reach is therefore `FLIGHT` — the whole load in the air at once — which is why the
## track stops well short of zero. Only the two ferry volleys pass one; the net's throw to
## the island crate keeps the gap it always had.
static func _gap(count: int, gap_scale: float = 1.0) -> float:
	var others := maxf(float(count - 1), 1.0)
	return minf(STAGGER, SPREAD / others) * maxf(gap_scale, 0.0)


## How long a volley of `count` pieces takes to land, start to finish. Callers that have to
## wait for their load — the boat holds at the berth until it has one — ask rather than
## guess, so the wait cannot drift out of step with the flight.
static func volley_time(count: int, gap_scale: float = 1.0) -> float:
	return FLIGHT + _gap(count, gap_scale) * maxf(float(count - 1), 0.0)


## Where a piece is heading right now, in world space.
func _target_of(piece: Dictionary) -> Vector2:
	var follow: Node2D = piece["follow"]
	var to: Vector2 = piece["to"]
	return to if follow == null or not is_instance_valid(follow) else follow.position + to


## Where it is coming from right now.
##
## Read live rather than frozen at the throw, so the whole arc is anchored to the thrower.
## It damps itself: the path is a lerp from here to there, so a piece just launched swings
## fully with the angler and one about to land barely notices. What that buys is a stream
## that keeps pouring out of the player as they walk, instead of one that hangs where they
## were standing when the net came in.
func _source_of(piece: Dictionary) -> Vector2:
	var lead: Node2D = piece["lead"]
	var from: Vector2 = piece["from"]
	return from if lead == null or not is_instance_valid(lead) else lead.position + from


func _process(delta: float) -> void:
	for i in range(_flying.size() - 1, -1, -1):
		var piece: Dictionary = _flying[i]
		if float(piece["wait"]) > 0.0:
			piece["wait"] = float(piece["wait"]) - delta
			continue
		piece["age"] = float(piece["age"]) + delta
		if float(piece["age"]) >= FLIGHT:
			_pop(piece["tag"])
			arrived.emit(int(piece["def"]), piece["tag"])
			_flying.remove_at(i)
	if _flying.is_empty():
		set_process(false)
	queue_redraw()


## The knock of a piece hitting the pile, no more than once every `POP_GAP`.
##
## Landing only. It used to pop on the throw as well, which sounded like one knock, a
## half-second of nothing, and then the real run of them — the gap being the flight, which
## is silent by definition. One pop per piece, at the moment it lands, is a stream that
## matches what is on screen.
##
## **A ferry landing its hold at a pier is silent** (2026-09-16, Richard: too repetitive).
## That volley is a whole hold going into a box across the lake, several times a minute, and
## it already has a sound of its own — the run of coins to the plate, which is what the
## delivery is actually about. The angler's own throws into the crate keep the thud: that is
## the player's hand, in front of them, one cast at a time.
func _pop(tag: Variant = null) -> void:
	if sfx == null or tag is Dropoff:
		return
	var now := float(Time.get_ticks_msec()) / 1000.0
	if now - _pop_at < POP_GAP:
		return
	_pop_at = now
	sfx.play_pop()


## Where a piece is and how far along it is, or null while it is still waiting its turn.
func _at(piece: Dictionary) -> Dictionary:
	if float(piece["wait"]) > 0.0:
		return {}
	var t := clampf(float(piece["age"]) / FLIGHT, 0.0, 1.0)
	var from := _source_of(piece)
	var to := _target_of(piece)
	# Eased along the ground and parabolic in the air: the throw is quick out of the hand
	# and the landing is not.
	var flat := from.lerp(to, t * t * (3.0 - 2.0 * t))
	return {
		"t": t,
		"ground": flat,
		"at": flat - Vector2(0.0, sin(t * PI) * float(piece["lift"])),
	}


func _draw() -> void:
	if grid == null:
		return
	for piece: Dictionary in _flying:
		var step := _at(piece)
		if step.is_empty():
			continue
		var t: float = step["t"]
		var at: Vector2 = step["at"]

		# A shadow on the ground under it, shrinking as it rises. Without one a piece in
		# flight is a sprite sliding over the island rather than a thing above it.
		var shadow: Vector2 = step["ground"]
		var high := sin(t * PI)
		draw_circle(
			shadow, lerpf(13.0, 6.0, high) , Color(0.0, 0.0, 0.0, lerpf(0.22, 0.07, high))
		)

		var size := lerpf(SIZE_FROM, SIZE_TO, t) + sin(t * PI) * SIZE_PEAK
		draw_set_transform(at, float(piece["spin"]) * t * TAU * 0.25, Vector2(size, size))
		grid.defs[int(piece["def"])].stamp_iso(self)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
