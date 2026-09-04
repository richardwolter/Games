## Owns every rope in the strait: placing them, pricing them, cutting them, and
## putting them back after an attempt.
##
## Ropes are rationed rather than priced out of reach. One per campaign level —
## two on the second strait, three on the third — so a rope is always a decision
## about WHERE it goes rather than how many to buy. The price on top is what stops
## a player stretching one across the whole strait for free; it is charged by the
## unit of length, so a short tie between two touching pieces is nearly free and a
## span across open water costs like the pieces would have.
##
## Placed with two clicks, on any part of any piece's collision shape. Nothing
## snaps, nothing is validated beyond "that is a piece": tying a fridge to a tyre
## at a ridiculous angle is allowed, and finding out what it does is the point.
class_name RopeManager
extends Node2D

## A rope was placed, cut, cleared or restored — anything that changes what is in
## the strait or what it cost.
signal changed()
## Tried to place one somewhere it can't go. Carries the sentence to show.
signal placement_failed(reason: String)

const ROPE_SCRIPT := preload("res://scripts/rope.gd")

## Dollars per world unit of rope. A 200-unit tie is $50, against a plank at $18
## and a girder in the hundreds — enough that roping a whole bridge together is a
## real alternative use of the money rather than a free improvement.
const COST_PER_UNIT := 0.25
## Below this the two anchors are effectively the same point and the joint has
## nothing to act along.
const MIN_LENGTH := 24.0
## A rope longer than this is a bridge, and one nobody has to build.
const MAX_LENGTH := 1400.0

var economy: Economy = null
var levels: LevelManager = null
## The manipulator, for its piece-under-the-cursor query. Reused rather than
## copied: there must be exactly one definition of "the piece you are pointing at".
var manipulator: Node2D = null

## Rope mode. While armed the manipulator stands down entirely — clicks tie ropes
## instead of picking pieces up.
var arming: bool = false:
	set(value):
		if arming == value:
			return
		arming = value
		cancel_pending()
		queue_redraw()

## Mirrors Main._attempt_active. The strait is not the player's to touch during an
## attempt, and a rope tied mid-crossing would not be in the layout the restore is
## about to reinstate.
var locked: bool = false:
	set(value):
		locked = value
		if locked:
			arming = false

## The first end, while the player is part-way through placing one.
var _pending: BridgeObject = null
var _pending_offset: Vector2 = Vector2.ZERO


## How many ropes this strait allows. Level 1 gets one, level 2 gets two.
func limit() -> int:
	return (levels.index + 1) if levels != null else 1


func ropes() -> Array[Rope]:
	var out: Array[Rope] = []
	for child: Node in get_children():
		var rope := child as Rope
		if rope != null and not rope.is_queued_for_deletion():
			out.append(rope)
	return out


func count() -> int:
	return ropes().size()


## What the whole set of ropes cost, for the leaderboard's bridge price. A roped
## bridge is strictly better than the same bridge without, so leaving ropes out of
## the price would put every roped run above every honest one.
func total_cost() -> int:
	var total := 0
	for rope: Rope in ropes():
		total += rope.cost
	return total


func cost_for(length: float) -> int:
	return maxi(ceili(length * COST_PER_UNIT), 1)


## True while the first end is placed and the second is not.
func has_pending() -> bool:
	return is_instance_valid(_pending)


func cancel_pending() -> void:
	_pending = null
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not arming or locked:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			try_point(get_global_mouse_position())
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			# Right-click backs out of a half-placed rope, or cuts the one under the
			# cursor — the same shape as the manipulator's right-click, which puts
			# back the piece in hand or else the one being pointed at.
			if has_pending():
				cancel_pending()
			else:
				var rope := rope_at(get_global_mouse_position())
				if rope != null:
					remove_rope(rope)
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not (event as InputEventKey).echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE and has_pending():
			cancel_pending()
			get_viewport().set_input_as_handled()


## One click while rope mode is armed.
func try_point(world: Vector2) -> void:
	var piece := _piece_at(world)
	if piece == null:
		placement_failed.emit("Click a piece to tie the rope to")
		return

	if not has_pending():
		_pending = piece
		_pending_offset = piece.to_local(world)
		queue_redraw()
		return

	if piece == _pending:
		placement_failed.emit("A rope has to reach a second piece")
		return

	var from := _pending.to_global(_pending_offset)
	var length := from.distance_to(world)
	# Checked before the money, so a player who can't afford it hears about the
	# reason they could have fixed first.
	if length < MIN_LENGTH:
		placement_failed.emit("Those two points are too close together")
		return
	if length > MAX_LENGTH:
		placement_failed.emit("That rope is too long")
		return
	if count() >= limit():
		placement_failed.emit("No rope left — this strait allows %d" % limit())
		return

	var price := cost_for(length)
	if economy == null or not economy.can_afford(price):
		placement_failed.emit("A rope that long costs $%d" % price)
		return
	economy.spend(price)

	_add_rope(_pending, piece, _pending_offset, piece.to_local(world), length, price)
	cancel_pending()
	UITheme.play(&"piece_release")
	changed.emit()


func _add_rope(
	a: BridgeObject,
	b: BridgeObject,
	a_offset: Vector2,
	b_offset: Vector2,
	length: float,
	price: int
) -> Rope:
	var rope := Rope.new()
	rope.setup(a, b, a_offset, b_offset, length, price)
	add_child(rope)
	return rope


## Cut a rope and hand the money back. A full refund on purpose: a rope in the
## wrong place is a mistake the player should be able to take back, and the thing
## being tested here is where ropes go, not how carefully they are bought.
func remove_rope(rope: Rope) -> void:
	if not is_instance_valid(rope) or rope.is_queued_for_deletion():
		return
	if economy != null:
		economy.add(rope.cost)
	rope.queue_free()
	UITheme.play(&"piece_click")
	changed.emit()


## The rope nearest a point, within a few pixels of it. Ropes have no collision,
## so this is the only way to point at one.
func rope_at(world: Vector2, tolerance: float = 12.0) -> Rope:
	var best: Rope = null
	var best_distance := tolerance
	for rope: Rope in ropes():
		var ends := rope.endpoints()
		if ends.is_empty():
			continue
		var near := Geometry2D.get_closest_point_to_segment(world, ends[0], ends[1])
		var distance := near.distance_to(world)
		if distance <= best_distance:
			best_distance = distance
			best = rope
	return best


## Drop any rope whose piece has gone. Called after anything that can remove
## pieces — the alternative is a joint pointing at a freed body.
func prune() -> void:
	var lost := false
	for rope: Rope in ropes():
		if not rope.alive():
			# No refund. The rope did not fail; the thing it was tied to was taken
			# away, and refunding here would make "recall a piece" a way of getting
			# rope money back for free.
			rope.queue_free()
			lost = true
	if lost:
		changed.emit()


## Every rope is thrown away. Used on a level change and when a saved layout
## replaces the bridge — in both cases the pieces the ropes were tied to are
## about to stop existing.
func clear_all() -> void:
	var had := false
	for rope: Rope in ropes():
		rope.queue_free()
		had = true
	if had:
		changed.emit()


## Ropes as plain data, keyed by the uid of the piece at each end. For the
## pre-crossing snapshot, where the bodies themselves are about to be freed and
## rebuilt.
func snapshot() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for rope: Rope in ropes():
		if not rope.alive():
			continue
		out.append({
			&"a": rope.a.uid,
			&"b": rope.b.uid,
			&"a_offset": rope.a_offset,
			&"b_offset": rope.b_offset,
			&"rest": rope.rest,
			&"cost": rope.cost,
		})
	return out


## Puts the ropes back onto the freshly restored pieces. `by_uid` maps the uid a
## snapshot recorded onto the body that now carries it — ObjectSpawner.restore
## keeps the uids, which is the whole reason they exist.
func restore(snap: Array[Dictionary], by_uid: Dictionary) -> void:
	for rope: Rope in ropes():
		rope.free()

	for entry: Dictionary in snap:
		var a := by_uid.get(entry[&"a"], null) as BridgeObject
		var b := by_uid.get(entry[&"b"], null) as BridgeObject
		# A piece that didn't come back takes its ropes with it rather than leaving
		# a joint hanging off one end.
		if a == null or b == null:
			continue
		_add_rope(
			a, b,
			entry[&"a_offset"] as Vector2,
			entry[&"b_offset"] as Vector2,
			entry[&"rest"] as float,
			int(entry.get(&"cost", 0))
		)
	changed.emit()


## For the save file, where a uid means nothing: ropes are written as indices into
## the same bridge array being written beside them.
##
## `bridge` must be the array SaveGame is about to serialise, AFTER its own
## filtering — a piece whose .tres has gone is dropped from that array, and an
## index taken before the drop would reconnect the rope to whatever slid into its
## place.
func to_json(bridge: Array[Dictionary]) -> Array:
	var index_of := {}
	for i: int in bridge.size():
		index_of[bridge[i].get(&"uid", 0)] = i

	var out := []
	for rope: Rope in ropes():
		if not rope.alive():
			continue
		var a: Variant = index_of.get(rope.a.uid, -1)
		var b: Variant = index_of.get(rope.b.uid, -1)
		if int(a) < 0 or int(b) < 0:
			continue
		out.append({
			"a": a, "b": b,
			"ax": rope.a_offset.x, "ay": rope.a_offset.y,
			"bx": rope.b_offset.x, "by": rope.b_offset.y,
			"rest": rope.rest,
			"cost": rope.cost,
		})
	return out


## `by_index` maps a position in the SAVED bridge array onto the piece that was
## rebuilt from it. A dictionary rather than a plain list because bridge_from_json
## can drop an entry — a piece with a non-finite position, or one whose .tres has
## been deleted — and every rope after the gap would otherwise be tied one piece
## along.
func from_json(raw: Variant, by_index: Dictionary) -> void:
	for rope: Rope in ropes():
		rope.free()

	if raw is not Array:
		return
	for item: Variant in (raw as Array):
		if item is not Dictionary:
			continue
		var entry := item as Dictionary
		var ai := int(entry.get("a", -1))
		var bi := int(entry.get("b", -1))
		# A hand-edited or half-migrated save can point anywhere, and a piece the
		# restore dropped simply isn't in the map. One missing rope is a far cheaper
		# outcome than a joint tied to the wrong piece.
		var a := by_index.get(ai, null) as BridgeObject
		var b := by_index.get(bi, null) as BridgeObject
		if a == null or b == null or ai == bi:
			continue
		var a_offset := Vector2(float(entry.get("ax", 0.0)), float(entry.get("ay", 0.0)))
		var b_offset := Vector2(float(entry.get("bx", 0.0)), float(entry.get("by", 0.0)))
		var rest := float(entry.get("rest", 0.0))
		if not (
			is_finite(a_offset.x) and is_finite(a_offset.y)
			and is_finite(b_offset.x) and is_finite(b_offset.y)
			and is_finite(rest)
		):
			continue
		_add_rope(a, b, a_offset, b_offset, rest, int(entry.get("cost", 0)))
	changed.emit()


func _piece_at(world: Vector2) -> BridgeObject:
	if manipulator == null:
		return null
	return manipulator.piece_at(world)


## The half-placed rope, drawn from its first knot to the cursor so the player can
## see what they are about to pay for before they pay for it.
func _process(_delta: float) -> void:
	if arming and has_pending():
		queue_redraw()


func _draw() -> void:
	if not arming or not has_pending():
		return
	var from := to_local(_pending.to_global(_pending_offset))
	var to := to_local(get_global_mouse_position())
	draw_line(from, to, Rope.COLOR.lerp(Color.WHITE, 0.3), Rope.THICKNESS, true)
	draw_circle(from, Rope.THICKNESS * 1.6, Rope.COLOR)
