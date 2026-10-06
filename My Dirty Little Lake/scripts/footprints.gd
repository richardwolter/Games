## The trail left in the sand and the grass by whoever just walked over it.
##
## One node for the whole island, the same bargain `WaterSplash` strikes for the water: a
## footprint is not a thing worth a node of its own, so every mark anybody leaves lives in one
## flat array here and is aged down and dropped in `_process`. Short-lived and shallow on
## purpose — this is a hint that somebody was just here, not a permanent path worn into the
## ground, so nothing is saved and nothing grows without bound.
##
## Kept separate per walker rather than in one shared ring: the angler and the dog are laying
## trails at the same time, and folding them into one buffer means whichever one steps more
## often crowds the other's marks out before they have had their moment.
class_name Footprints
extends Node2D

## How many marks any one walker keeps down at once. Old ones are dropped as new ones land,
## so the trail is always the last few steps and never the whole walk.
const MAX_PER_WALKER := 6

## How long one mark takes to fade out completely, in seconds.
const LIFE := 2.4

## at, life left, kind (&"boot" or &"paw"), and the width the mark fades from — kept per mark
## rather than read off a shared constant, since a boot and a paw are not the same size.
var _trails := {}


func _ready() -> void:
	set_process(false)


## Lay one mark down. `owner` only tells one walker's trail from another's — nothing about it
## is drawn — and `at` is where the mark sits, in this node's own local space.
func mark(owner: Object, at: Vector2, kind: StringName) -> void:
	var id := owner.get_instance_id()
	var trail: Array = _trails.get(id, [])
	trail.append({"at": at, "life": LIFE, "kind": kind})
	if trail.size() > MAX_PER_WALKER:
		trail.pop_front()
	_trails[id] = trail
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	var any := false
	for id: int in _trails.keys():
		var trail: Array = _trails[id]
		var i := 0
		while i < trail.size():
			trail[i]["life"] -= delta
			if trail[i]["life"] <= 0.0:
				trail.remove_at(i)
			else:
				i += 1
		if trail.is_empty():
			_trails.erase(id)
		else:
			any = true
	queue_redraw()
	if not any:
		set_process(false)


func _draw() -> void:
	for id: int in _trails.keys():
		for step: Dictionary in (_trails[id] as Array):
			var fade: float = clampf(step["life"] / LIFE, 0.0, 1.0)
			if step["kind"] == &"paw":
				_paw(step["at"], fade)
			else:
				_boot(step["at"], fade)


## A boot print: one flattened, sunk-in oval, the same shape the shadows on this plane always
## are.
func _boot(at: Vector2, fade: float) -> void:
	_oval(at, Vector2(6.0, 3.4), Color(0.0, 0.0, 0.0, 0.22 * fade))


## A paw print: a smaller pad and three toes ahead of it, loose enough at this size to read as
## a paw rather than as a smudge.
func _paw(at: Vector2, fade: float) -> void:
	var colour := Color(0.0, 0.0, 0.0, 0.20 * fade)
	_oval(at + Vector2(0.0, 0.6), Vector2(3.4, 2.2), colour)
	for dx: float in [-1.6, 0.0, 1.6]:
		_oval(at + Vector2(dx, -1.6), Vector2(1.2, 1.2), colour)


func _oval(at: Vector2, extent: Vector2, colour: Color) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var angle := TAU * float(i) / 10.0
		points.append(at + Vector2(cos(angle) * extent.x * 0.5, sin(angle) * extent.y * 0.5))
	draw_colored_polygon(points, colour)
