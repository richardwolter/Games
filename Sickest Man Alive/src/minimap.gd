class_name Minimap
extends Control

## Draws the floor as data, not as a second scene graph. It reads MapData and
## owns nothing, so it cannot drift out of sync with where you actually are.
##
## Origin is the body, not the player. A map that scrolls under you cannot
## read as a silhouette, and the silhouette is the whole navigation aid:
## you should know you are in a leg without reading a label.

## Sixty rooms across twenty-eight rows of body. Smaller than it was, but not
## much: below about eight pixels a cell stops reading as a room, and the fix
## for a crowded readout is the HUD layout rather than a smaller cell.
const CELL: float = 9.0
const PAD: float = 1.0

var map: MapData
var current: Vector2i = Vector2i.ZERO
## During the rampage the map stops being a record of where you have been and
## becomes a route out. These are the only cells that matter then.
var rampage: bool = false
var escapes: Array[Vector2i] = []


func set_rampage(active: bool, cells: Array[Vector2i]) -> void:
	rampage = active
	escapes = cells
	queue_redraw()


func set_map(m: MapData) -> void:
	map = m
	queue_redraw()


func set_current(cell: Vector2i) -> void:
	current = cell
	queue_redraw()


func _draw() -> void:
	if map == null:
		return
	var step := CELL + PAD
	# Anchored on the diaphragm, which sits at the middle of the body's height --
	# the head runs fourteen rows up and the feet thirteen down, so anchoring on
	# the chest would push the legs off the bottom of the panel.
	var origin := size * 0.5 - Vector2(BodyPlan.cell_of("diaphragm")) * step

	for cell: Vector2i in map.rooms:
		var info: Dictionary = map.rooms[cell]
		var p := origin + Vector2(cell) * step - Vector2(CELL, CELL) * 0.5
		var rect := Rect2(p, Vector2(CELL, CELL))

		# A road not taken is worth more on the map than a blank: it is the record
		# of a choice, so it is drawn whether or not the room was ever seen.
		if map.is_sealed_cell(cell):
			draw_rect(rect, Color(0.35, 0.10, 0.12, 0.5))
			draw_line(rect.position, rect.position + rect.size, Color(0.75, 0.35, 0.35, 0.7), 1.0)
			continue

		if not info["seen"]:
			# Unvisited parts still hold the silhouette open, faintly, so the
			# body reads as a body from the first room.
			draw_rect(rect, Color(1, 1, 1, 0.06))
			continue

		var c: Color = info["color"]
		match info["kind"] as MapData.RoomKind:
			MapData.RoomKind.BOSS:
				c = Color(0.95, 0.25, 0.3)
			MapData.RoomKind.ITEM:
				c = Color(0.5, 0.85, 1.0)
			MapData.RoomKind.START:
				c = Color(0.55, 0.95, 0.6)
			_:
				pass
		if not info["cleared"] and info["kind"] == MapData.RoomKind.COMBAT:
			c = c.darkened(0.5)

		draw_rect(rect, c)
		if cell == current:
			draw_rect(rect, Color.WHITE, false, 2.0)

	# Exits are drawn last and unconditionally -- including over parts that were
	# never entered, because "run for the mouth" is useless advice if the mouth
	# is not on the map yet.
	if rampage:
		for cell in escapes:
			var p := origin + Vector2(cell) * step - Vector2(CELL, CELL) * 0.5
			var rect := Rect2(p, Vector2(CELL, CELL)).grow(2.0)
			draw_rect(rect, Color(0.5, 1.0, 0.75), false, 2.0)
