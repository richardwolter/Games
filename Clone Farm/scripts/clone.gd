## A clone: a Worker with a role and traits. It works that role across the whole farm,
## picking the nearest bed that wants it and that no other worker is on, under the same
## rules as the farmer (walk to the bed, locked in place while working). No role: it stands
## idle. Its traits (scripts/traits.gd) change how it works, good side and bad side, and the
## bad side always shows: a bubble says when it skips a bed or stops to chat.
class_name Clone
extends Worker

## The roles the farmer can give, in the order of the number keys 0-3; &"" is no role.
const ROLES: Array[StringName] = [&"", Bed.PLANT, Bed.WATER, Bed.HARVEST]
const ROLE_LABELS := {
	&"": "sem função",
	Bed.PLANT: "Plantar",
	Bed.WATER: "Regar",
	Bed.HARVEST: "Colher",
}
## After skipping a bed, the clone leaves it alone this long (so the skip reads as a skip).
const SKIP_IGNORE := 3.0
const BUBBLE_TIME := 1.5

var role := &""
var traits: Array[StringName] = []
## The combined numbers of `traits` (Traits.combine), rebuilt whenever traits change.
var stats := Traits.combine([])
## Returns a number in [0, 1) for each skip roll; the harness swaps it to force an outcome.
var roll: Callable = func() -> float: return randf()

var _tag: Label3D
var _bubble: Label3D
var _bubble_left := 0.0
var _ignored := {}
var _chat_wait := 0.0
var _chat_left := 0.0


func _ready() -> void:
	super()
	add_to_group("clones")
	_tag = _label(1.4, 32)
	_bubble = _label(2.1, 36)
	_bubble.modulate = Color(1.0, 0.95, 0.5)
	_bubble.visible = false
	_refresh_tag()


func set_role(new_role: StringName) -> void:
	role = new_role
	cancel_work()
	_refresh_tag()


func set_traits(names: Array[StringName]) -> void:
	traits = names
	stats = Traits.combine(traits)
	_chat_wait = stats.chat_every
	if _tag != null:
		_refresh_tag()


func move_mult() -> float:
	return stats.move


## Its own speed for `task`, times the cheer of any Animado clone nearby (not its own).
func task_speed(task: StringName) -> float:
	var speed: float = work_speed * stats.work * stats.task.get(task, 1.0)
	var cheer := 1.0
	for node in get_tree().get_nodes_in_group("clones"):
		var other := node as Clone
		if other == self or other.stats.cheer_radius <= 0.0:
			continue
		if _ground(other.global_position - global_position).length() <= other.stats.cheer_radius:
			cheer = maxf(cheer, other.stats.cheer)
	return speed * cheer


func harvest_bonus() -> int:
	return stats.harvest_bonus


func grow_boost() -> float:
	return stats.grow_boost


func is_paused() -> bool:
	return _chat_left > 0.0


func is_chatting() -> bool:
	return _chat_left > 0.0


func _think() -> void:
	var delta := get_physics_process_delta_time()
	_tick_timers(delta)
	if is_paused() or is_working() or role == &"":
		return
	var bed := pick_bed()
	if bed != null:
		work(bed)


## Apressado's bad side: sometimes the work time runs out and the task isn't done.
func _finish_task() -> void:
	if work_place is Bed and roll.call() < stats.skip:
		_ignored[work_place] = SKIP_IGNORE
		say("pulou!")
		return
	super()


## The nearest bed that wants this clone's role, that no other worker is on and that it
## didn't just skip, or null.
func pick_bed() -> Bed:
	var taken := {}
	for node in get_tree().get_nodes_in_group("workers"):
		var other := node as Worker
		if other != self and other.work_place != null:
			taken[other.work_place] = true
	var best: Bed = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("beds"):
		var bed := node as Bed
		if bed.next_task() != role or taken.has(bed) or _ignored.has(bed):
			continue
		var d := _ground(bed.global_position - global_position).length()
		if d < best_d:
			best = bed
			best_d = d
	return best


## Shows a short line over the clone's head.
func say(text: String, seconds := BUBBLE_TIME) -> void:
	_bubble.text = text
	_bubble.visible = true
	_bubble_left = seconds


## Skipped beds, the bubble, and Animado's bad side: every chat_every seconds, if another
## clone is within cheer_radius, it stops (even mid-task) for chat_time.
func _tick_timers(delta: float) -> void:
	for bed in _ignored.keys():
		_ignored[bed] -= delta
		if _ignored[bed] <= 0.0:
			_ignored.erase(bed)
	if _bubble_left > 0.0:
		_bubble_left -= delta
		_bubble.visible = _bubble_left > 0.0
	if _chat_left > 0.0:
		_chat_left -= delta
		return
	if stats.chat_every <= 0.0:
		return
	_chat_wait -= delta
	if _chat_wait <= 0.0 and _someone_to_chat_with():
		_chat_left = stats.chat_time
		_chat_wait = stats.chat_every
		say("conversando...", stats.chat_time)


func _someone_to_chat_with() -> bool:
	for node in get_tree().get_nodes_in_group("clones"):
		var other := node as Clone
		if other != self and _ground(other.global_position - global_position).length() \
				<= stats.cheer_radius:
			return true
	return false


func _label(height: float, size: int) -> Label3D:
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.01
	label.font_size = size
	label.outline_size = 8
	label.position.y = height
	add_child(label)
	return label


func _refresh_tag() -> void:
	var text := "%s: %s" % [name, ROLE_LABELS[role]]
	if not traits.is_empty():
		text += "\n" + Traits.labels(traits)
	_tag.text = text
