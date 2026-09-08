## The nets the player leaves on the water.
##
## A lit cast is not a cast that comes back. The net goes out, lands, and is left there
## burning or freezing — and the angler has another one, so the next cast can go somewhere
## else while the first is still working. That is the whole of what fire and ice buy: not a
## stronger drag, but the ability to put a patch of the lake off limits and walk away from
## it.
##
## One node owns every laid net, the way the flock owns every pigeon and the swarm owns
## every monster. A laid net is a row in an array: where it is, what is on it, and how long
## it has left.
class_name LaidNet
extends Node2D

## How many may be on the water at once. A cap rather than a cost, because the cost is
## already there — the enchantment is on a clock, and laying a net does not stop it running
## down. Past this the oldest one is taken up to make room, which reads as the angler
## having only so many nets to leave.
const MOST := 4

## How long one lies there, in seconds. Shorter than an enchantment, so a charm is several
## placements rather than one long one, and a player who wants a patch held has to keep
## going back to it.
const LIFE := 7.0

## How long it takes to sink once its time is up, and how long it takes to settle when it
## lands. Both short: this is a net on water, not a spell.
const SINK := 0.6
const LAND := 0.25

var sfx: Sfx
var splash: WaterSplash

## Every net on the water. Rows of {tile, radius, fire, ice, left, age, sink}.
var nets: Array = []

## A net was taken up early to make room for a newer one.
signal lifted(at: Vector2)


## Leave one here. `fire` and `ice` say what was on the net when it was thrown, and both
## may be true — a net carrying the two does the two.
func lay(tile: Vector2, radius: float, fire: bool, ice: bool) -> bool:
	if not fire and not ice:
		return false
	if nets.size() >= MOST:
		var oldest: Dictionary = nets[0]
		lifted.emit(Iso.tile_to_world((oldest["tile"] as Vector2).x, (oldest["tile"] as Vector2).y))
		nets.remove_at(0)
	nets.append({
		"tile": tile,
		"radius": radius,
		"fire": fire,
		"ice": ice,
		"left": LIFE,
		"age": 0.0,
		"sink": 0.0,
	})
	if splash != null:
		splash.splash(Iso.tile_to_world(tile.x, tile.y), 0.45)
	queue_redraw()
	return true


## How many are working. A net on its way down is not one of them.
func working() -> int:
	var count := 0
	for net: Dictionary in nets:
		if float(net["sink"]) <= 0.0:
			count += 1
	return count


## Take them all up at once. Used when a run ends: nets burning in an empty lake are a
## screen still doing something after the game has stopped.
func clear() -> void:
	nets.clear()
	queue_redraw()


func _process(delta: float) -> void:
	for i in range(nets.size() - 1, -1, -1):
		var net: Dictionary = nets[i]
		net["age"] = float(net["age"]) + delta
		if float(net["sink"]) > 0.0 or float(net["left"]) <= 0.0:
			net["sink"] = float(net["sink"]) + delta / SINK
			if float(net["sink"]) >= 1.0:
				nets.remove_at(i)
			continue
		net["left"] = float(net["left"]) - delta
	queue_redraw()


## What a laid net does to the water around it: a bloom for fire, a rimed disc for ice, and
## both drawn over one another when it carries the two.
##
## Drawn at exactly the radius the siege soaks at, so what looks like it is burning and what
## is burning cannot come apart.
func _draw() -> void:
	for net: Dictionary in nets:
		var at: Vector2 = net["tile"]
		var where := Iso.tile_to_world(at.x, at.y)
		var reach := Iso.tile_circle_extent(float(net["radius"]))
		# Landing and sinking are the same shape at either end of its life.
		var grown := clampf(float(net["age"]) / LAND, 0.0, 1.0)
		var fade := (1.0 - float(net["sink"])) * grown
		# The last second and a half flickers, so a net about to go out says so.
		if float(net["left"]) < 1.5 and float(net["sink"]) <= 0.0:
			fade *= 0.55 + 0.45 * absf(sin(float(net["age"]) * 9.0))
		reach *= 0.6 + 0.4 * grown
		var beat := 0.5 + 0.5 * sin(float(net["age"]) * 3.4)

		if bool(net["ice"]):
			_disc(where, reach, Color(0.55, 0.88, 1.0, 0.16 * fade))
			_ring(where, reach, Color(0.72, 0.95, 1.0, (0.45 + 0.2 * beat) * fade))
		if bool(net["fire"]):
			_disc(where, reach * (0.94 + 0.06 * beat), Color(1.0, 0.48, 0.14, 0.20 * fade))
			_ring(where, reach, Color(1.0, 0.66, 0.28, (0.5 + 0.25 * beat) * fade))
		_mesh(where, reach * 0.62, fade)


## A flat disc on the plane, at the tiles' own 2:1.
func _disc(at: Vector2, reach: float, tint: Color) -> void:
	var ring := PackedVector2Array()
	for i in 28:
		var angle := TAU * float(i) / 28.0
		ring.append(at + Vector2(cos(angle) * reach, sin(angle) * reach * 0.55))
	draw_colored_polygon(ring, tint)


func _ring(at: Vector2, reach: float, tint: Color) -> void:
	var ring := PackedVector2Array()
	for i in 29:
		var angle := TAU * float(i % 28) / 28.0
		ring.append(at + Vector2(cos(angle) * reach, sin(angle) * reach * 0.55))
	draw_polyline(ring, tint, 2.0)


## The net itself, lying open on the water: a rim and a few strands across it. Drawn rather
## than borrowed from the cast net's sheet, because those frames are a net being held and
## this one has been let go of.
func _mesh(at: Vector2, reach: float, fade: float) -> void:
	var twine := Color(0.92, 0.90, 0.82, 0.55 * fade)
	_ring(at, reach, twine)
	for i in 4:
		var angle := PI * float(i) / 4.0
		var arm := Vector2(cos(angle) * reach, sin(angle) * reach * 0.55)
		draw_line(at - arm, at + arm, Color(0.92, 0.90, 0.82, 0.28 * fade), 1.2)
