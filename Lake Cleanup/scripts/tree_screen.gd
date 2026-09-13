## The upgrade tree as a node graph, for tree test mode.
##
## Deliberately plain (Richard, 2026-09-12: "do not worry about looking like current UI, it
## should just be useful and properly represent a skill tree and its spread as you buy"). One
## canvas, the root in the middle, each category's branch fanning out in its own wedge and
## colour. Owned nodes are filled, nodes that can be bought are ringed, and one step past them
## the locked nodes show as faint question marks — so the tree visibly spreads as it is bought,
## and there is always something in sight to want.
##
## Laid out automatically from the parents in the tree file, so a tuning pass that adds or
## moves a node needs no positions written anywhere. A node whose first parent is in another
## category (the dog hangs off Bigger Bag II) is laid out in its own category's wedge from the
## root, and the real prerequisite is drawn as a dashed line — as is every second parent.
##
## Click a node to buy it, drag to pan, wheel to zoom, right-click or Escape to close.
class_name TreeScreen
extends Control

signal buy_asked(id: String)
signal close_asked

## Category colours, by the category's place in the tree file. Picked to be told apart on the
## dark backdrop, not to match the drawn boards.
const COLOURS := [Color("4fc1b7"), Color("d19a58"), Color("9d8ff0"), Color("e57aa8"), Color("86c75e"), Color("6fa8ee")]
const BACKDROP := Color(0.04, 0.06, 0.07, 0.94)
const PANEL := Color(0.09, 0.12, 0.13)
const INK := Color(0.9, 0.93, 0.92)
const MUTED := Color(0.56, 0.62, 0.6)
const GOLD := Color("e8c15a")
const SHORT := Color(0.85, 0.42, 0.38)

## Graph space: the first ring's radius and the step between rings.
const RING_FIRST := 240.0
const RING_STEP := 190.0
## On screen, whatever the zoom: a node and a locked silhouette.
const NODE := 24.0
const HIDDEN := 13.0
const HEADER := 92.0
const ZOOM_LEAST := 0.3
const FRAME_LEAST := 0.75
const ZOOM_MOST := 1.6
const TIP_WIDE := 300.0

## How the tree's stats read to a player, and how their values are written.
const STAT_TEXT := {
	"net_range": ["Cast range", "%.1f tiles"],
	"reel": ["Reel speed", "%.1f tiles/s"],
	"net_hold": ["Bag", "%d pieces"],
	"net_power": ["Lifts", "tier %d"],
	"net_radius": ["Mouth", "%.1f tiles"],
	"boats": ["Ferries", "%d"],
	"cargo": ["Ferry hold", "%d pieces"],
	"boat_speed": ["Ferry speed", "%.1f tiles/s"],
	"dog_fetch": ["Dog carries", "%d at a time"],
	"dog_reach": ["Dog swims out", "%.0f tiles"],
	"dog_strand_speed": ["Strand runs", "x%.1f pace"],
}

var tree: UpgradeTree
## The lake's own dictionary of owned node ids, shared rather than copied.
var owned: Dictionary = {}
## Reads the purse. A callable so the screen never holds a stale number.
var money_of: Callable = func() -> float: return 0.0

var _pos: Dictionary = {}
var _layout_parent: Dictionary = {}
var _zoom: float = 1.0
var _offset := Vector2.ZERO
var _hover: String = ""
var _dragging: bool = false
var _drag_moved: float = 0.0
var _moved_by_hand: bool = false
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = ThemeDB.fallback_font


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


## Called when the screen is shown: lays the tree out the first time and frames what is in sight.
func open() -> void:
	if _pos.is_empty():
		_lay_out()
	_moved_by_hand = false
	_hover = ""
	frame_shown()


## After a purchase: the tree has spread, so frame it again unless the player has moved the view.
func bought() -> void:
	if not _moved_by_hand:
		frame_shown()


func positions() -> Dictionary:
	return _pos


# ------------------------------------------------------------------ layout

func _root_ids() -> Array:
	return tree.nodes.filter(func(n: Dictionary) -> bool: return (n["parents"] as Array).is_empty()).map(
		func(n: Dictionary) -> String: return n["id"])


func _lay_out() -> void:
	_pos.clear()
	_layout_parent.clear()
	var roots := _root_ids()
	var centre := String(roots[0]) if roots.size() == 1 else ""
	var kids := {"": []}
	for n: Dictionary in tree.nodes:
		kids[n["id"]] = []
	for n: Dictionary in tree.nodes:
		var id: String = n["id"]
		if id == centre:
			continue
		var parents: Array = n["parents"]
		var up := centre
		if not parents.is_empty():
			var first: String = parents[0]
			var first_node: Dictionary = tree.by_id[first]
			var crosses: bool = first_node["tree"] != n["tree"] and not (first_node["parents"] as Array).is_empty()
			up = centre if crosses else first
		_layout_parent[id] = up
		(kids[up] as Array).append(id)
	# The root's branches grouped by category, so each category is one wedge.
	(kids[centre] as Array).sort_custom(func(a: String, b: String) -> bool:
		return tree.trees.find(tree.by_id[a]["tree"]) < tree.trees.find(tree.by_id[b]["tree"]))
	var leaves := {}
	_count_leaves(centre, kids, leaves)
	if centre != "":
		_pos[centre] = Vector2.ZERO
	_place_children(centre, -PI * 1.5, PI * 0.5, 1, kids, leaves)


func _count_leaves(id: String, kids: Dictionary, leaves: Dictionary) -> int:
	var total := 0
	for k: String in kids[id]:
		total += _count_leaves(k, kids, leaves)
	leaves[id] = maxi(total, 1)
	return leaves[id]


func _place_children(id: String, from: float, to: float, depth: int, kids: Dictionary, leaves: Dictionary) -> void:
	var list: Array = kids[id]
	var total := 0
	for k: String in list:
		total += int(leaves[k])
	var at := from
	for k: String in list:
		var span := (to - from) * float(leaves[k]) / float(maxi(total, 1))
		var angle := at + span * 0.5
		var radius := RING_FIRST + RING_STEP * float(depth - 1)
		_pos[k] = Vector2(cos(angle), sin(angle)) * radius
		_place_children(k, at, at + span, depth + 1, kids, leaves)
		at += span


# ------------------------------------------------------------------ what is in sight

func _shown(id: String) -> bool:
	return tree.is_visible(owned, id)


## Locked, but one step past something in sight: drawn as a question mark.
func _hinted(id: String) -> bool:
	if _shown(id):
		return false
	for p: String in tree.by_id[id]["parents"]:
		if _shown(p):
			return true
	return false


func frame_shown() -> void:
	var box := Rect2()
	var first := true
	for n: Dictionary in tree.nodes:
		var id: String = n["id"]
		if not (_shown(id) or _hinted(id)) or not _pos.has(id):
			continue
		if first:
			box = Rect2(_pos[id], Vector2.ZERO)
			first = false
		else:
			box = box.expand(_pos[id])
	box = box.grow(90.0)
	var room := Rect2(Vector2(0.0, HEADER), size - Vector2(0.0, HEADER)).grow(-24.0)
	if room.size.x <= 0.0 or room.size.y <= 0.0:
		return
	# Never framed smaller than FRAME_LEAST: past that the names run into each other. A tree
	# that has spread wider than the screen is framed on its middle and dragged to the rest.
	_zoom = clampf(minf(room.size.x / box.size.x, room.size.y / box.size.y), FRAME_LEAST, 1.0)
	_offset = room.get_center() - box.get_center() * _zoom


func _screen(graph: Vector2) -> Vector2:
	return _offset + graph * _zoom


func _colour(id: String) -> Color:
	var index := tree.trees.find(tree.by_id[id]["tree"])
	return COLOURS[maxi(index, 0) % COLOURS.size()]


# ------------------------------------------------------------------ input

func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		if _dragging:
			_offset += motion.relative
			_drag_moved += motion.relative.length()
			if _drag_moved > 6.0:
				_moved_by_hand = true
		_hover = _node_at(motion.position)
		accept_event()
		return
	var click := event as InputEventMouseButton
	if click == null:
		return
	accept_event()
	match click.button_index:
		MOUSE_BUTTON_LEFT:
			if click.pressed:
				_dragging = true
				_drag_moved = 0.0
				return
			_dragging = false
			if _drag_moved > 6.0:
				return
			if _close_box().has_point(click.position):
				close_asked.emit()
				return
			var id := _node_at(click.position)
			if id != "" and tree.is_buyable(owned, id):
				buy_asked.emit(id)
		MOUSE_BUTTON_RIGHT:
			if click.pressed:
				close_asked.emit()
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			if not click.pressed:
				return
			var step := 1.15 if click.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15
			var zoom := clampf(_zoom * step, ZOOM_LEAST, ZOOM_MOST)
			_offset = click.position - (click.position - _offset) * (zoom / _zoom)
			_zoom = zoom
			_moved_by_hand = true


func _node_at(at: Vector2) -> String:
	var best := ""
	var best_gap := INF
	for n: Dictionary in tree.nodes:
		var id: String = n["id"]
		if not _pos.has(id) or not (_shown(id) or _hinted(id)):
			continue
		var reach := NODE if _shown(id) else HIDDEN
		var gap := at.distance_to(_screen(_pos[id]))
		if gap <= reach + 6.0 and gap < best_gap:
			best_gap = gap
			best = id
	return best


func _close_box() -> Rect2:
	return Rect2(Vector2(size.x - 64.0, 24.0), Vector2(40.0, 40.0))


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	if tree == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP)
	var money: float = money_of.call()
	_draw_edges()
	for n: Dictionary in tree.nodes:
		var id: String = n["id"]
		if _pos.has(id) and _hinted(id):
			_draw_hidden(id)
	for n: Dictionary in tree.nodes:
		var id: String = n["id"]
		if _pos.has(id) and _shown(id):
			_draw_node(id, money)
	_draw_header(money)
	if _hover != "":
		_draw_tip(_hover, money)


func _draw_edges() -> void:
	for n: Dictionary in tree.nodes:
		var id: String = n["id"]
		if not _pos.has(id):
			continue
		var shown := _shown(id)
		if not shown and not _hinted(id):
			continue
		var parents: Array = n["parents"]
		for i in parents.size():
			var p: String = parents[i]
			if not _pos.has(p) or not _shown(p):
				continue
			var primary: bool = i == 0 and String(_layout_parent.get(id, "")) == p
			var tint := _colour(id)
			if not shown:
				tint = Color(1, 1, 1, 0.14)
			elif not tree.is_owned(owned, id):
				tint.a = 0.5
			var from := _screen(_pos[p])
			var to := _screen(_pos[id])
			if primary:
				draw_line(from, to, tint, 3.0 if tree.is_owned(owned, id) else 2.0, true)
			else:
				_dashed(from, to, tint, 2.0)


func _dashed(from: Vector2, to: Vector2, tint: Color, width: float) -> void:
	var length := from.distance_to(to)
	if length < 1.0:
		return
	var way := (to - from) / length
	var at := 0.0
	while at < length:
		var end := minf(at + 9.0, length)
		draw_line(from + way * at, from + way * end, tint, width, true)
		at += 16.0


func _draw_hidden(id: String) -> void:
	var at := _screen(_pos[id])
	draw_circle(at, HIDDEN, Color(1, 1, 1, 0.05))
	draw_arc(at, HIDDEN, 0.0, TAU, 32, Color(1, 1, 1, 0.22), 1.5, true)
	_text_centred("?", at + Vector2(0.0, 5.0), 14, Color(1, 1, 1, 0.4))


func _draw_node(id: String, money: float) -> void:
	var n: Dictionary = tree.by_id[id]
	var at := _screen(_pos[id])
	var tint := _colour(id)
	var have := tree.is_owned(owned, id)
	var maxed := tree.is_maxed(owned, id)
	var price := tree.cost(owned, id) if not maxed else 0.0
	var afford := not maxed and money >= price
	var hovered := _hover == id
	var r := NODE * (1.12 if hovered else 1.0)
	if have:
		draw_circle(at, r, tint)
		draw_arc(at, r, 0.0, TAU, 40, INK, 2.0, true)
	else:
		draw_circle(at, r, PANEL)
		var ring := tint
		ring.a = 1.0 if afford else 0.45
		draw_arc(at, r, 0.0, TAU, 40, ring, 3.0 if afford else 2.0, true)
	var tags: Array = n["tags"]
	if tags.has("keystone"):
		draw_arc(at, r + 6.0, 0.0, TAU, 40, Color(tint, 0.7), 1.5, true)
	var glyph := _glyph(String(n["name"]))
	_text_centred(glyph, at + Vector2(0.0, 6.0), 16, Color(0.05, 0.07, 0.08) if have else INK)
	_text_centred(String(n["name"]), at + Vector2(0.0, r + 18.0), 13, INK if have or afford else MUTED)
	if not maxed:
		var line := _money(price)
		if int(n["ranks"]) > 1:
			line += "  (%d/%d)" % [tree.rank_of(owned, id), int(n["ranks"])]
		_text_centred(line, at + Vector2(0.0, r + 34.0), 12, GOLD if afford else MUTED)


## Roman numerals stay whole ("II", "IV"); anything else shows its first letter.
func _glyph(name: String) -> String:
	var words := name.split(" ")
	var last := words[words.size() - 1]
	if last in ["I", "II", "III", "IV", "V", "VI"]:
		return last
	return name.substr(0, 1).to_upper()


func _draw_header(money: float) -> void:
	draw_rect(Rect2(0.0, 0.0, size.x, HEADER), Color(BACKDROP, 1.0))
	draw_line(Vector2(0.0, HEADER), Vector2(size.x, HEADER), Color(1, 1, 1, 0.08), 1.0)
	draw_string(_font, Vector2(32.0, 50.0), "Upgrade tree", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, INK)
	var available := 0
	for n: Dictionary in tree.nodes:
		var id: String = n["id"]
		if tree.is_buyable(owned, id) and money >= tree.cost(owned, id):
			available += 1
	draw_string(_font, Vector2(32.0, 76.0),
		"%s sludge   ·   %d you can buy now   ·   click a node to buy, drag to move, wheel to zoom, right-click or Esc to close" % [_money(money), available],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)
	var x := size.x - 96.0
	for i in range(tree.trees.size() - 1, -1, -1):
		var label := tree.trees[i].capitalize()
		var wide := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		x -= wide
		draw_string(_font, Vector2(x, 50.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK)
		draw_circle(Vector2(x - 12.0, 45.0), 6.0, COLOURS[i % COLOURS.size()])
		x -= 36.0
	var close := _close_box()
	draw_rect(close, PANEL)
	draw_rect(close, Color(1, 1, 1, 0.25), false, 1.0)
	var c := close.get_center()
	draw_line(c + Vector2(-8, -8), c + Vector2(8, 8), INK, 2.0, true)
	draw_line(c + Vector2(-8, 8), c + Vector2(8, -8), INK, 2.0, true)


func _draw_tip(id: String, money: float) -> void:
	var n: Dictionary = tree.by_id[id]
	var lines: Array = []  # [text, size, colour]
	if not _shown(id):
		lines.append(["Locked", 18, INK])
		var needs := (n["parents"] as Array).filter(func(p: String) -> bool: return not tree.is_owned(owned, p)).map(
			func(p: String) -> String: return String(tree.by_id[p]["name"]))
		lines.append(["Buy %s to reveal it." % " and ".join(PackedStringArray(needs)), 14, MUTED])
	else:
		lines.append([String(n["name"]), 18, _colour(id).lightened(0.2)])
		var tags: Array = n["tags"]
		if tags.has("unlock"):
			lines.append(["New system", 12, GOLD])
		elif tags.has("keystone"):
			lines.append(["Keystone", 12, GOLD])
		if n.has("desc"):
			lines.append([String(n["desc"]), 14, MUTED])
		var now := tree.stats(owned)
		var after := tree.stats_with(owned, id) if not tree.is_maxed(owned, id) else now
		for e: Dictionary in n.get("effects", []) as Array:
			var stat := String(e["stat"])
			lines.append([_effect_line(stat, float(now.get(stat, 0.0)), float(after.get(stat, 0.0))), 14, INK])
		var cross := (n["parents"] as Array).slice(1)
		if not cross.is_empty():
			lines.append(["Needs %s" % (" and " if n["requireAll"] else " or ").join(PackedStringArray(
				cross.map(func(p: String) -> String: return String(tree.by_id[p]["name"])))), 13, MUTED])
		if tree.is_maxed(owned, id):
			lines.append(["Owned", 14, _colour(id)])
		else:
			var price := tree.cost(owned, id)
			if money >= price:
				lines.append(["%s sludge  ·  click to buy" % _money(price), 14, GOLD])
			else:
				lines.append(["%s sludge  ·  %s more to go" % [_money(price), _money(price - money)], 14, SHORT])
	var tall := 16.0
	var heights: Array = []
	for line: Array in lines:
		var h := _font.get_multiline_string_size(String(line[0]), HORIZONTAL_ALIGNMENT_LEFT, TIP_WIDE, int(line[1])).y
		heights.append(h)
		tall += h + 4.0
	var mouse := get_local_mouse_position()
	var box := Rect2(mouse + Vector2(20.0, 20.0), Vector2(TIP_WIDE + 28.0, tall + 8.0))
	box.position.x = minf(box.position.x, size.x - box.size.x - 8.0)
	box.position.y = minf(box.position.y, size.y - box.size.y - 8.0)
	draw_rect(box, Color(0.07, 0.1, 0.11, 0.98))
	draw_rect(box, Color(1, 1, 1, 0.18), false, 1.0)
	var y := box.position.y + 14.0
	for i in lines.size():
		var line: Array = lines[i]
		var fsize := int(line[1])
		draw_multiline_string(_font, Vector2(box.position.x + 14.0, y + float(fsize)), String(line[0]),
			HORIZONTAL_ALIGNMENT_LEFT, TIP_WIDE, fsize, -1, line[2])
		y += float(heights[i]) + 4.0


func _effect_line(stat: String, before: float, after: float) -> String:
	match stat:
		"dog":
			return "The dog joins you on the island" if after >= 1.0 and before < 1.0 else "Dog: with you"
		"dog_wait_cut":
			return "Dog rests at most %.0f s → %.0f s" % [maxf(10.0 - before, 3.0), maxf(10.0 - after, 3.0)]
		"dog_beach":
			return "Strand runs first: %d%% → %d%% of trips" % [roundi(before * 100.0), roundi(after * 100.0)]
	var spec: Array = STAT_TEXT.get(stat, [stat.capitalize(), "%.2f"])
	var fmt := String(spec[1])
	var b := fmt % (roundi(before) if fmt.contains("%d") else before)
	var a := fmt % (roundi(after) if fmt.contains("%d") else after)
	return "%s: %s → %s" % [spec[0], b, a]


func _text_centred(text: String, at: Vector2, font_size: int, tint: Color) -> void:
	var wide := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(_font, Vector2(at.x - wide * 0.5, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)


static func _money(value: float) -> String:
	var whole := str(roundi(value))
	var out := ""
	var count := 0
	for i in range(whole.length() - 1, -1, -1):
		out = whole[i] + out
		count += 1
		if count % 3 == 0 and i > 0 and whole[i - 1] != "-":
			out = "," + out
	return out
