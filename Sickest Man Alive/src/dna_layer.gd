class_name DnaLayer
extends Node2D

## The DNA lying on one room's floor.
##
## Sibling of BloodLayer, and the same trick: the array is MapData's, held by
## reference, so what is on the floor is what the run remembers. The difference
## is that motes are also REMOVED -- picking one up has to delete the run's
## record of it, or it would be back on the next visit.

signal collected(value: int)

## Above this many motes, the oldest are merged into one worth the sum rather
## than dropped. A rampage room can bury the floor, and every mote is a node with
## a _process -- but losing DNA to a cap would be a payout bug, not a visual one.
const CAP: int = 60

## Motes as the run stores them: {"p": Vector2, "v": int}. MapData's own array.
var motes: Array = []

## Whether this floor's DNA comes to the player on its own. Held on the LAYER
## rather than only pushed onto the motes, so a mote dropped after the room went
## quiet -- or one loaded back in on a return visit -- inherits it instead of
## being the one scrap that still has to be walked over.
var _magnet: bool = false


## Takes the run's existing motes for this room and puts them back where they
## were left. Called before anything can die, so fresh drops land on top.
func load_motes(existing: Array) -> void:
	motes = existing
	for child in get_children():
		child.queue_free()
	for m: Dictionary in motes:
		_spawn_node(m, false)


## Drops a fresh mote, which scatters off the body it came from.
func drop(pos: Vector2, value: int) -> void:
	if value <= 0:
		return
	var record := {"p": pos, "v": value}
	motes.append(record)
	_spawn_node(record, true)
	_enforce_cap()


## Turns the floor's DNA into something that comes to you. One way only: a room
## that has been cleared does not go back to being contested.
func set_magnet(value: bool) -> void:
	if not value or _magnet:
		return
	_magnet = true
	set_process(true)
	for child in get_children():
		var mote := child as DnaMote
		if mote != null:
			mote.magnetise()


## Works out where this floor's DNA should be flying, once per frame, and hands
## the same answer to every mote.
##
## The in-the-room test is the point of it. A room is freed when it is left, but
## not until the end of the frame, and the player is already standing in the next
## one by then -- so the motes spent their last frame homing on a player through
## a wall, dragging the run's record of where that DNA lies along with them. DNA
## left behind stays where it was left.
func _process(_delta: float) -> void:
	if not _magnet:
		return
	var target := Vector2.INF
	var player := get_tree().get_first_node_in_group(&"player_body") as Node2D
	var room := get_parent() as Room
	if player != null and room != null and room.contains_world_point(player.global_position):
		# A corpse does not go shopping, and does not attract either -- same
		# reasoning as DnaMote._try_pickup, and without it the run's payout
		# counts DNA hoovered up by a body on its death slide.
		if not (player.has_method(&"is_dead") and player.is_dead()):
			target = player.global_position
	for child in get_children():
		var mote := child as DnaMote
		if mote != null:
			mote.set_magnet_target(target)


func _spawn_node(record: Dictionary, fresh: bool) -> void:
	var mote := DnaMote.new()
	mote.record = record
	mote.value = int(record.get("v", 1))
	mote.position = record.get("p", Vector2.ZERO)
	mote.collected.connect(_on_collected.bind(record))
	add_child(mote)
	if fresh:
		mote.scatter()
	if _magnet:
		mote.magnetise()


func _on_collected(value: int, record: Dictionary) -> void:
	# By identity, not by value: Array.erase compares Dictionaries by reference,
	# and two motes of the same worth in the same spot are a real possibility. A
	# mote that ever rebuilt its record instead of holding the original would
	# silently duplicate itself on the next visit to the room.
	motes.erase(record)
	collected.emit(value)


## Folds the oldest motes into a single fat one when the floor gets crowded. The
## DNA is conserved; only the node count is not.
func _enforce_cap() -> void:
	if motes.size() <= CAP:
		return
	var merged := 0
	var where: Vector2 = motes[0].get("p", Vector2.ZERO)
	while motes.size() > CAP:
		var oldest: Dictionary = motes.pop_front()
		merged += int(oldest.get("v", 0))
		for child in get_children():
			var mote := child as DnaMote
			# is_same, not ==: identity is the whole contract here, and two motes
			# dropped in the same spot for the same value are equal by value.
			if mote != null and is_same(mote.record, oldest):
				mote.queue_free()
				break
	if merged > 0:
		var record := {"p": where, "v": merged}
		motes.push_front(record)
		_spawn_node(record, false)
