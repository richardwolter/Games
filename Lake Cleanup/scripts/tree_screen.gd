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
## moves a node needs no positions written anywhere: rings by depth, a wedge per category, see
## `_lay_out`. Prerequisites from another category (the dog needs Iron Pull and the Second
## Ferry) are dashed and routed along the wedge borders, see `_draw_edges`.
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
const RING_FIRST := 300.0
const RING_STEP := 210.0
## Graph space: nodes on one ring are kept at least this far apart (a name is about 130 wide),
## and this far in from their wedge's edges.
const NODE_GAP := 170.0
const WEDGE_PAD := 60.0
## A ring of several nodes spreads over at least this share of its wedge, so the outer rings use
## the room they have instead of hugging the middle of it.
const RING_SPREAD := 0.8
## Radians between neighbouring categories' wedges, and the narrowest a wedge may be.
const WEDGE_GAP := 0.14
const WEDGE_LEAST := 0.35
## Points along a drawn edge.
const EDGE_STEPS := 16
## On screen, whatever the zoom: a node and a locked silhouette.
const NODE := 24.0
## The strength nodes (anything that sets `net_power`) are the tree's connectors: drawn this much
## bigger than the rest, with a thick gold rim (Richard, 2026-09-14).
const POWER_SIZE := 1.5
const POWER_RIM := 5.0
## Radius of a strength-node badge on a node it gates in another category, see `is_badge`.
const BADGE := 9.0
const HIDDEN := 13.0
const HEADER := 92.0
const ZOOM_LEAST := 0.3
const FRAME_LEAST := 0.5
## Nodes, their names and prices are drawn at this share of their size at most zoomed out, and
## grow with the zoom to full size at 1: a fixed on-screen size ran nodes into each other the
## moment the view was pulled back to see the tree's shape.
const DRAW_LEAST := 0.6
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
	"bird_worth": ["Pigeons pay", "x%.1f"],
}

var tree: UpgradeTree
## The lake's own dictionary of owned node ids, shared rather than copied.
var owned: Dictionary = {}
## Reads the purse. A callable so the screen never holds a stale number.
var money_of: Callable = func() -> float: return 0.0

var _pos: Dictionary = {}
var _layout_parent: Dictionary = {}
## Each category's wedge, as (from, to) angles.
var _wedge: Dictionary = {}
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


## Rings by depth, one wedge per category (2026-09-14, Richard: nodes too clustered, too many
## lines crossing).
##
## A node's ring is its longest path from the root, so a strength node sits one ring past the
## ring of nodes it joins, and the dog sits past Iron Pull. Each category gets a wedge as wide as
## its most crowded ring needs at `NODE_GAP` apart, and the wedges go round the circle in the
## order that keeps linked categories side by side (the dog between the net and the ferry).
## Inside a wedge each ring is laid out in order of where its parents are, so a child sits
## under its parent and siblings fan round it; that is what keeps lines from crossing.
## Positions are never written anywhere, so a tuning pass needs no layout work.
func _lay_out() -> void:
	_pos.clear()
	_layout_parent.clear()
	_wedge.clear()
	var roots := _root_ids()
	var centre := String(roots[0]) if roots.size() == 1 else ""
	var order: Array = tree.nodes.map(func(n: Dictionary) -> String: return n["id"])

	# Rings: the longest path from a root.
	var ring := {}
	for id: String in order:
		ring[id] = 0 if (tree.by_id[id]["parents"] as Array).is_empty() else -1
	var changed := true
	while changed:
		changed = false
		for id: String in order:
			var parents: Array = tree.by_id[id]["parents"]
			if parents.is_empty():
				continue
			var deepest := -1
			for p: String in parents:
				deepest = maxi(deepest, int(ring[p]))
			if deepest >= 0 and deepest + 1 > int(ring[id]):
				ring[id] = deepest + 1
				changed = true
	if centre != "":
		_pos[centre] = Vector2.ZERO

	# The nodes each category lays out, ring by ring (the centre belongs to none).
	var cats: Array = Array(tree.trees)
	var by_cat := {}
	var most_ring := 0
	for c: String in cats:
		by_cat[c] = {}
	for id: String in order:
		if id == centre:
			continue
		var c: String = tree.by_id[id]["tree"]
		var r := maxi(int(ring[id]), 1)
		most_ring = maxi(most_ring, r)
		if not (by_cat[c] as Dictionary).has(r):
			by_cat[c][r] = []
		(by_cat[c][r] as Array).append(id)

	# Wedge widths: what the most crowded ring of each category needs at its radius.
	var need := {}
	var total_need := 0.0
	for c: String in cats:
		var widest := WEDGE_LEAST
		for r: int in by_cat[c]:
			widest = maxf(widest, (float((by_cat[c][r] as Array).size() - 1) * NODE_GAP + WEDGE_PAD * 2.0) / _radius(r))
		need[c] = widest
		total_need += widest
	var room := TAU - WEDGE_GAP * float(cats.size())
	var scale := minf(1.0, room / maxf(total_need, 0.001))
	var spare := maxf(room - total_need * scale, 0.0)

	# Wedge order: the arrangement with linked categories closest together.
	var links := {}
	for id: String in order:
		var c: String = tree.by_id[id]["tree"]
		for p: String in tree.by_id[id]["parents"]:
			if p == centre:
				continue
			var pc: String = tree.by_id[p]["tree"]
			if pc != c:
				var key := "%s|%s" % ([c, pc] if c < pc else [pc, c])
				links[key] = int(links.get(key, 0)) + 1
	var best_order: Array = cats.duplicate()
	var best_cost := INF
	for perm: Array in _permutations(cats.slice(1)):
		var arrangement: Array = [cats[0]] + perm
		var cost := 0.0
		for key: String in links:
			var pair := key.split("|")
			var apart := absi(arrangement.find(pair[0]) - arrangement.find(pair[1]))
			cost += float(mini(apart, arrangement.size() - apart)) * float(links[key])
		if cost < best_cost:
			best_cost = cost
			best_order = arrangement

	# Wedges round the circle, the first centred straight up. Spare room goes in proportion to
	# need: shared evenly, a one-node chain like the pigeons took room the ferry's rings wanted.
	var widths := {}
	for c: String in cats:
		widths[c] = float(need[c]) * scale * (1.0 + spare / maxf(total_need * scale, 0.001))
	var at := -PI * 0.5 - float(widths[best_order[0]]) * 0.5
	for c: String in best_order:
		_wedge[c] = Vector2(at, at + float(widths[c]))
		at += float(widths[c]) + WEDGE_GAP

	# Rings outward: each node wants the mean angle of its parents in its own category (the
	# wedge's middle if it has none there); the ring is then spread NODE_GAP apart inside the wedge.
	var angle := {}
	for c: String in cats:
		var span: Vector2 = _wedge[c]
		for r in range(1, most_ring + 1):
			if not (by_cat[c] as Dictionary).has(r):
				continue
			var list: Array = by_cat[c][r]
			var want := {}
			for id: String in list:
				var sum := 0.0
				var count := 0
				for p: String in tree.by_id[id]["parents"]:
					if angle.has(p) and tree.by_id[p]["tree"] == c:
						sum += float(angle[p])
						count += 1
				want[id] = sum / float(count) if count > 0 else (span.x + span.y) * 0.5
			list.sort_custom(func(a: String, b: String) -> bool:
				if not is_equal_approx(float(want[a]), float(want[b])):
					return float(want[a]) < float(want[b])
				return order.find(a) < order.find(b))
			var radius := _radius(r)
			var wished: Array = list.map(func(id: String) -> float: return float(want[id]))
			var usable := (span.y - span.x) - WEDGE_PAD * 2.0 / radius
			var gap := maxf(NODE_GAP / radius, usable * RING_SPREAD / float(maxi(list.size() - 1, 1)))
			var placed := _spread(wished, gap, span.x + WEDGE_PAD / radius, span.y - WEDGE_PAD / radius)
			for i in list.size():
				var id: String = list[i]
				angle[id] = placed[i]
				_pos[id] = Vector2(cos(placed[i]), sin(placed[i])) * radius
				_layout_parent[id] = _nearest_parent(id, angle, c, float(placed[i]), centre)


func _radius(ring_index: int) -> float:
	return RING_FIRST + RING_STEP * float(ring_index - 1)


## Of a node's parents in its own category, the one closest in angle: the edge drawn solid.
## A node hanging straight off the root is laid out under the root.
func _nearest_parent(id: String, angle: Dictionary, category: String, at: float, centre: String) -> String:
	var best := ""
	var best_gap := INF
	for p: String in tree.by_id[id]["parents"]:
		if p == centre:
			if best == "":
				best = p
			continue
		if angle.has(p) and tree.by_id[p]["tree"] == category:
			var gap := absf(float(angle[p]) - at)
			if gap < best_gap:
				best_gap = gap
				best = p
	return best


## Angles as close to `want` as they can be, in order, at least `gap` apart, inside [lo, hi].
## Overlapping runs merge into blocks centred on their mean wish, the way a row of labels is
## spread without reordering; a ring too full for its wedge is squeezed evenly.
func _spread(want: Array, gap: float, lo: float, hi: float) -> Array:
	var n := want.size()
	if n == 0:
		return []
	if gap * float(n - 1) > hi - lo:
		gap = (hi - lo) / float(maxi(n - 1, 1))
	# Blocks: [count, wished centre].
	var blocks: Array = []
	for i in n:
		blocks.append([1, float(want[i])])
		while blocks.size() > 1:
			var b: Array = blocks[blocks.size() - 1]
			var a: Array = blocks[blocks.size() - 2]
			var a_end := float(a[1]) + gap * float(int(a[0]) - 1) * 0.5
			var b_start := float(b[1]) - gap * float(int(b[0]) - 1) * 0.5
			if b_start - a_end >= gap:
				break
			var count := int(a[0]) + int(b[0])
			var mean := (float(a[1]) * float(a[0]) + float(b[1]) * float(b[0])) / float(count)
			blocks.pop_back()
			blocks[blocks.size() - 1] = [count, mean]
	var out: Array = []
	for b: Array in blocks:
		var first := float(b[1]) - gap * float(int(b[0]) - 1) * 0.5
		for k in int(b[0]):
			out.append(first + gap * float(k))
	# Into the wedge: shift the whole ring in from whichever end is out, never reordering.
	var shift := 0.0
	if float(out[0]) < lo:
		shift = lo - float(out[0])
	elif float(out[n - 1]) > hi:
		shift = hi - float(out[n - 1])
	for i in n:
		out[i] = float(out[i]) + shift
	if float(out[n - 1]) > hi + 0.0001:
		for i in n:
			out[i] = lo + gap * float(i)
	return out


func _permutations(items: Array) -> Array:
	if items.size() <= 1:
		return [items.duplicate()]
	var out: Array = []
	for i in items.size():
		var rest := items.duplicate()
		var head: Variant = rest.pop_at(i)
		for tail: Array in _permutations(rest):
			out.append([head] + tail)
	return out


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


## How big nodes and their writing draw at the current zoom, see DRAW_LEAST.
func _draw_scale() -> float:
	return clampf(_zoom, DRAW_LEAST, 1.0)


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
		var reach := (NODE * (POWER_SIZE if _is_power(id) else 1.0) if _shown(id) else HIDDEN) * _draw_scale()
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


## Edges follow the rings rather than cutting across them. Within a category an edge is swept
## from the parent's angle and radius to the child's, so it bends round the circle instead of
## cutting a chord through the rings between. An edge from another category (the dog's, to Iron
## Pull and the Second Ferry) runs to the border between the two wedges, out along it, and in at
## the child, so it never crosses a wedge's nodes. Solid for the parent a node is laid out under
## and for every parent of a node that needs a count of them (each is a real way in); dashed for
## the rest.
func _draw_edges() -> void:
	for n: Dictionary in tree.nodes:
		var id: String = n["id"]
		if not _pos.has(id):
			continue
		var shown := _shown(id)
		if not shown and not _hinted(id):
			continue
		for p: String in n["parents"]:
			if not _pos.has(p) or not _shown(p) or is_badge(p, id):
				continue
			var tint := _colour(id)
			if not shown:
				tint = Color(1, 1, 1, 0.14)
			elif not tree.is_owned(owned, id):
				tint.a = 0.5
			var solid: bool = String(_layout_parent.get(id, "")) == p or int(n["requireCount"]) > 0
			var screen := PackedVector2Array()
			for point in _edge_path(p, id):
				screen.append(_screen(point))
			if solid:
				draw_polyline(screen, tint, 3.0 if tree.is_owned(owned, id) else 2.0, true)
			else:
				_dashed_path(screen, tint, 2.0)


## Graph-space points from parent to child, see `_draw_edges`.
func _edge_path(from_id: String, to_id: String) -> PackedVector2Array:
	var a: Vector2 = _pos[from_id]
	var b: Vector2 = _pos[to_id]
	var out := PackedVector2Array()
	if a.length() < 1.0:
		out.append(a)
		out.append(b)
		return out
	var from_cat: String = tree.by_id[from_id]["tree"]
	var to_cat: String = tree.by_id[to_id]["tree"]
	if from_cat == to_cat or not _wedge.has(from_cat) or not _wedge.has(to_cat):
		_sweep(out, a.length(), a.angle(), b.length(), _near_angle(b.angle(), a.angle()))
		return out
	# Across categories: round to the shared border at the parent's ring, out along the border
	# to between the two rings, then round and in to the child.
	var border := _border_between(from_cat, to_cat, a.angle())
	var ra := a.length()
	var rb := b.length()
	var mid := lerpf(ra, rb, 0.5)
	_sweep(out, ra, a.angle(), ra, border)
	_sweep(out, ra, border, mid, border)
	_sweep(out, mid, border, rb, _near_angle(b.angle(), border))
	return out


func _sweep(out: PackedVector2Array, r0: float, t0: float, r1: float, t1: float) -> void:
	for i in EDGE_STEPS + 1:
		var f := float(i) / float(EDGE_STEPS)
		var r := lerpf(r0, r1, f)
		var t := lerpf(t0, t1, f)
		out.append(Vector2(cos(t), sin(t)) * r)


## `angle` wrapped to within half a turn of `near`, so a sweep goes the short way round.
func _near_angle(angle: float, near: float) -> float:
	return near + wrapf(angle - near, -PI, PI)


## The middle of the gap between `from_cat`'s wedge and `to_cat`'s, on the side facing it,
## as an angle near `near`.
func _border_between(from_cat: String, to_cat: String, near: float) -> float:
	var own: Vector2 = _wedge[from_cat]
	var other: Vector2 = _wedge[to_cat]
	var own_mid := (own.x + own.y) * 0.5
	var other_mid := _near_angle((other.x + other.y) * 0.5, own_mid)
	var edge := own.y + WEDGE_GAP * 0.5 if other_mid > own_mid else own.x - WEDGE_GAP * 0.5
	return _near_angle(edge, near)


func _dashed_path(points: PackedVector2Array, tint: Color, width: float) -> void:
	var walked := 0.0
	for i in range(1, points.size()):
		var from := points[i - 1]
		var to := points[i]
		var length := from.distance_to(to)
		if length < 0.01:
			continue
		var way := (to - from) / length
		var at := 0.0
		while at < length:
			var phase := fmod(walked + at, 16.0)
			var run := minf(9.0 - phase, length - at) if phase < 9.0 else minf(16.0 - phase, length - at)
			if phase < 9.0:
				draw_line(from + way * at, from + way * (at + run), tint, width, true)
			at += maxf(run, 0.01)
		walked += length


func _draw_hidden(id: String) -> void:
	var at := _screen(_pos[id])
	var k := _draw_scale()
	draw_circle(at, HIDDEN * k, Color(1, 1, 1, 0.05))
	draw_arc(at, HIDDEN * k, 0.0, TAU, 32, Color(1, 1, 1, 0.22), 1.5, true)
	_text_centred("?", at + Vector2(0.0, 5.0 * k), roundi(14 * k), Color(1, 1, 1, 0.4))


func _draw_node(id: String, money: float) -> void:
	var n: Dictionary = tree.by_id[id]
	var at := _screen(_pos[id])
	var tint := _colour(id)
	var have := tree.is_owned(owned, id)
	var maxed := tree.is_maxed(owned, id)
	var price := tree.cost(owned, id) if not maxed else 0.0
	var afford := not maxed and money >= price
	var hovered := _hover == id
	var k := _draw_scale()
	var power := _is_power(id)
	var r := NODE * k * (POWER_SIZE if power else 1.0) * (1.12 if hovered else 1.0)
	if have:
		draw_circle(at, r, tint)
		draw_arc(at, r, 0.0, TAU, 40, INK, 2.0, true)
	else:
		draw_circle(at, r, PANEL)
		var ring := tint
		ring.a = 1.0 if afford else 0.45
		draw_arc(at, r, 0.0, TAU, 40, ring, 3.0 if afford else 2.0, true)
	var tags: Array = n["tags"]
	if power:
		draw_arc(at, r + POWER_RIM * 0.5 * k, 0.0, TAU, 48, Color(GOLD, 1.0 if have or afford else 0.6), POWER_RIM * k, true)
	elif tags.has("keystone"):
		draw_arc(at, r + 6.0 * k, 0.0, TAU, 40, Color(tint, 0.7), 1.5, true)
	var glyph := _glyph(String(n["name"]))
	_draw_badges(id, at, r, k)
	var glyph_size := 22 if power else 16
	_text_centred(glyph, at + Vector2(0.0, glyph_size * 0.38 * k), roundi(glyph_size * k), Color(0.05, 0.07, 0.08) if have else INK)
	_text_centred(String(n["name"]), at + Vector2(0.0, r + (18.0 + (POWER_RIM if power else 0.0)) * k), roundi((15 if power else 13) * k),
		(GOLD if power else INK) if have or afford else MUTED)
	if not maxed:
		var line := _money(price)
		if int(n["ranks"]) > 1:
			line += "  (%d/%d)" % [tree.rank_of(owned, id), int(n["ranks"])]
		_text_centred(line, at + Vector2(0.0, r + (34.0 + (POWER_RIM + 2.0 if power else 0.0)) * k), roundi(12 * k), GOLD if afford else MUTED)


## A prerequisite drawn as a badge on the node instead of an edge: a strength node gating a node
## in another category (the dog's training, the pigeons). Those edges ran as long dashed arcs
## across the whole tree and crossed each other (2026-09-14, third pass); the badge carries the
## strength node's own glyph in its gold, and the tooltip still names it.
func is_badge(parent: String, child: String) -> bool:
	return _is_power(parent) and tree.by_id[parent]["tree"] != tree.by_id[child]["tree"]


func _draw_badges(id: String, at: Vector2, r: float, k: float) -> void:
	var i := 0
	for p: String in tree.by_id[id]["parents"]:
		if not is_badge(p, id):
			continue
		var spot := at + Vector2(r * 0.78 + BADGE * k * float(i) * 1.9, -r * 0.78)
		var have := tree.is_owned(owned, p)
		draw_circle(spot, BADGE * k, GOLD if have else PANEL)
		draw_arc(spot, BADGE * k, 0.0, TAU, 24, GOLD, 2.0 * k, true)
		_text_centred(_glyph(String(tree.by_id[p]["name"])), spot + Vector2(0.0, 4.0 * k), roundi(11 * k),
			Color(0.05, 0.07, 0.08) if have else GOLD)
		i += 1


## A strength node: one that sets how heavy a piece the net can lift.
func _is_power(id: String) -> bool:
	for e: Dictionary in tree.by_id[id].get("effects", []) as Array:
		if String(e.get("stat", "")) == "net_power":
			return true
	return false


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
	var how := "click a node to buy, drag to move, wheel to zoom, right-click or Esc to close"
	if Pad.is_pad():
		how = "A on a node to buy, hold A to drag, LB/RB to zoom, B to close"
	draw_string(_font, Vector2(32.0, 76.0),
		"%s sludge   ·   %d you can buy now   ·   %s" % [_money(money), available, how],
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
		var need := int(n["requireCount"])
		if need > 0:
			var have := (n["parents"] as Array).size() - needs.size()
			lines.append(["Buy %d more of %s to reveal it." % [need - have, ", ".join(PackedStringArray(needs))], 14, MUTED])
		else:
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
		if int(n["requireCount"]) > 0:
			lines.append(["Needs any %d of %s" % [int(n["requireCount"]), ", ".join(PackedStringArray(
				(n["parents"] as Array).map(func(p: String) -> String: return String(tree.by_id[p]["name"]))))], 13, MUTED])
		elif not cross.is_empty():
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
		"lucky_odds":
			return "Lucky haul (+%d bag, lifts one tier more): %d%% → %d%% of casts" % [
				Lake.LUCKY_EXTRA, roundi(before * 100.0), roundi(after * 100.0)]
		"double_odds":
			return "Second net thrown: %d%% → %d%% of casts" % [roundi(before * 100.0), roundi(after * 100.0)]
		"recycle_bonus":
			return "Boosted yard pays +%d%% → +%d%%" % [roundi(before * 100.0), roundi(after * 100.0)]
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
