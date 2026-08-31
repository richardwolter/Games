## A yard on the shore that buys one material.
##
## There are four of them, spaced around the bank, and between them they are the reason
## the ferry has a route rather than a destination. A hold with plastic and metal in it is
## two stops; a hold with one of everything is a lap of the lake.
##
## The node draws itself and knows what it takes. It holds no stock and no money — the
## boat arrives, the lake pays, and the yard is a place rather than a system.
class_name Dropoff
extends Node2D

## Which of TrashDef.Kind this one buys.
var kind: int = TrashDef.Kind.PLASTIC

## Where the boat ties up, in tile coordinates. Just inside the waterline, so the hull has
## water under it when it arrives.
var berth := Vector2.ZERO

## The yard's colour, used for its sign and its crates. Colour is how the player tells the
## four apart from across a lake at low zoom, where a label is unreadable.
var tint := Color(0.7, 0.7, 0.7)


func kind_name() -> String:
	return TrashDef.KIND_NAMES[kind]


## Planks out over the water, crates on the bank, and a sign in the yard's own colour.
func _draw() -> void:
	var ink := Color(0.11, 0.09, 0.1)
	var at := Iso.tile_to_world(berth.x, berth.y)
	# Landward is further out from the middle of the lake, so the pier always runs from
	# the water up onto the nearest bank rather than along the shore.
	var out := (berth - Iso.CENTRE).normalized()
	var landward := Iso.tile_to_world(berth.x + out.x * 3.4, berth.y + out.y * 3.4)

	var across := Vector2(Iso.TILE_W * 0.32, 0.0)
	var deck := PackedVector2Array([
		at - across, at + across, landward + across * 1.25, landward - across * 1.25
	])
	draw_colored_polygon(deck, Color(0.55, 0.42, 0.28))
	var closed := deck.duplicate()
	closed.append(deck[0])
	draw_polyline(closed, ink, 1.6)

	# Crates in the yard's colour. The place that buys metal should look like a place full
	# of metal.
	for i in 3:
		var spot := landward + Vector2(-26.0 + 26.0 * float(i), -6.0 - 5.0 * float(i % 2))
		draw_rect(Rect2(spot, Vector2(20.0, 14.0)), tint)
		draw_rect(Rect2(spot, Vector2(20.0, 14.0)), ink, false, 1.4)

	# A post and a board, so there is one tall thing marking the stop at any zoom.
	var post := landward + Vector2(34.0, -4.0)
	draw_line(post, post + Vector2(0.0, -46.0), Color(0.42, 0.32, 0.22), 3.0)
	var board := Rect2(post + Vector2(-16.0, -62.0), Vector2(32.0, 18.0))
	draw_rect(board, tint)
	draw_rect(board, ink, false, 1.6)
