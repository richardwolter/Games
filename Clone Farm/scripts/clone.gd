## A clone: a Worker with a role and traits. It works that role across the whole farm under
## the same rules as the farmer (walk up, locked in place while working). Bed roles pick the
## nearest bed that wants the role and that no other worker is on; Carregar picks up the
## nearest free crates and takes them to its destination. No role: it stands idle.
## Every MEAL_EVERY seconds it walks to the trough to eat; with the trough short it goes
## hungry. Its traits (scripts/traits.gd) change how it works, good side and bad side, and
## the bad side always shows: a bubble says when it skips a bed, chats, naps, nibbles a crate
## or tramples a plant.
class_name Clone
extends Worker

## The roles the farmer can give, in the order of the number keys 0-4; &"" is no role.
const ROLES: Array[StringName] = [&"", Bed.PLANT, Bed.WATER, Bed.HARVEST, Traits.CARRY]
const ROLE_LABELS := {
	&"": "sem função",
	Bed.PLANT: "Plantar",
	Bed.WATER: "Regar",
	Bed.HARVEST: "Colher",
	Traits.CARRY: "Carregar",
}
## After skipping a bed, the clone leaves it alone this long (so the skip reads as a skip).
const SKIP_IGNORE := 3.0
const BUBBLE_TIME := 1.5

var role := &""
## Where a Carregar clone takes its crates.
var dest: Depot = null
var traits: Array[StringName] = []
## The combined numbers of `traits` (Traits.combine), rebuilt whenever traits change.
var stats := Traits.combine([])
## Returns a number in [0, 1) for each skip roll; the harness swaps it to force an outcome.
var roll: Callable = func() -> float: return randf()
var hungry := false

var _tag: Label3D
var _bubble: Label3D
var _bubble_left := 0.0
var _ignored := {}
var _chat_wait := 0.0
var _chat_left := 0.0
var _nap_wait := 0.0
var _nap_left := 0.0
var _meal_clock := Traits.MEAL_EVERY
var _food_owed := 0.0
var _meal_due := false
var _retry_left := 0.0
var _boost_left := 0.0
var _handled := 0


func _ready() -> void:
	super()
	add_to_group("clones")
	_tag = _label(1.4, 32)
	_bubble = _label(2.3, 36)
	_bubble.modulate = Color(1.0, 0.95, 0.5)
	_bubble.visible = false
	_refresh_tag()


func set_role(new_role: StringName, new_dest: Depot = null) -> void:
	role = new_role
	dest = new_dest
	cancel_work()
	_refresh_tag()


func set_traits(names: Array[StringName]) -> void:
	traits = names
	stats = Traits.combine(traits)
	_chat_wait = stats.chat_every
	_nap_wait = stats.nap_every
	if _tag != null:
		_refresh_tag()


func move_mult() -> float:
	return stats.move


func capacity() -> int:
	return 1 + stats.capacity_bonus


## Its own speed for `task` (hunger and the Glutão meal boost included), times the cheer of
## any Animado clone nearby (not its own).
func task_speed(task: StringName) -> float:
	var speed: float = work_speed * stats.work * stats.task.get(task, 1.0)
	if hungry:
		speed *= Traits.HUNGRY_WORK
	if _boost_left > 0.0:
		speed *= stats.meal_boost
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


## Beliscador's bad side: every waste_every-th crate it harvests or picks up, it eats.
func keep_of(amount: int) -> int:
	if stats.waste_every <= 0:
		return amount
	var kept := 0
	for i in amount:
		_handled += 1
		if _handled % stats.waste_every == 0:
			say("nham! (comeu 1)")
		else:
			kept += 1
	return kept


func is_paused() -> bool:
	return _chat_left > 0.0 or _nap_left > 0.0


func is_chatting() -> bool:
	return _chat_left > 0.0


func is_napping() -> bool:
	return _nap_left > 0.0


func wants_meal() -> bool:
	return _meal_due


## Units it eats this meal (at least 1; Preguiçoso's half meals add up).
func meal_size() -> int:
	return maxi(1, floori(_food_owed))


func eat(amount: int) -> void:
	_food_owed = maxf(0.0, _food_owed - amount)
	_meal_due = false
	hungry = false
	_boost_left = stats.meal_boost_time if stats.meal_boost > 1.0 else 0.0
	say("comendo... pronto")
	_refresh_tag()


func _think() -> void:
	var delta := get_physics_process_delta_time()
	_tick_timers(delta)
	if is_paused() or is_working():
		return
	if _meal_due:
		var trough := _trough()
		if trough != null and trough.stock >= meal_size():
			work(trough)
			return
		_meal_due = false
		_retry_left = Traits.MEAL_RETRY
		if not hungry:
			hungry = true
			say("com fome!")
			_refresh_tag()
	if role == Traits.CARRY:
		_think_carry()
	elif role != &"":
		var bed := pick_bed()
		if bed != null:
			work(bed)


## Fill the hands with the nearest free crates, then take them to `dest`.
func _think_carry() -> void:
	if carrying < capacity():
		var crate := pick_crate()
		if crate != null:
			work(crate)
			return
	if carrying > 0 and dest != null:
		work(dest)


## Forte's bad side: a plant it walks over is lost.
func _after_move() -> void:
	if not stats.tramples or velocity.length() < 0.1:
		return
	for node in get_tree().get_nodes_in_group("beds"):
		var bed := node as Bed
		if bed.covers(global_position) and bed.trample():
			say("ops! pisou")


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
	var taken := _taken()
	var best: Bed = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("beds"):
		var bed := node as Bed
		if bed.next_task_for(self) != role or taken.has(bed) or _ignored.has(bed):
			continue
		var d := _ground(bed.global_position - global_position).length()
		if d < best_d:
			best = bed
			best_d = d
	return best


## The nearest crate on the ground no other worker is going for, or null.
func pick_crate() -> Crate:
	var taken := _taken()
	var best: Crate = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("crates"):
		var crate := node as Crate
		if crate.is_queued_for_deletion() or taken.has(crate):
			continue
		var d := _ground(crate.global_position - global_position).length()
		if d < best_d:
			best = crate
			best_d = d
	return best


## Shows a short line over the clone's head.
func say(text: String, seconds := BUBBLE_TIME) -> void:
	if _bubble == null:
		return
	_bubble.text = text
	_bubble.visible = true
	_bubble_left = seconds


func _taken() -> Dictionary:
	var taken := {}
	for node in get_tree().get_nodes_in_group("workers"):
		var other := node as Worker
		if other != self and other.work_place != null:
			taken[other.work_place] = true
	return taken


func _trough() -> Depot:
	var troughs := get_tree().get_nodes_in_group("troughs")
	return troughs[0] as Depot if not troughs.is_empty() else null


## Skipped beds, the bubble, meals and hunger, the Glutão boost, and the pauses: Animado
## stops for chat_time every chat_every seconds if a clone is within cheer_radius,
## Preguiçoso naps nap_time every nap_every seconds. Pauses happen even mid-task.
func _tick_timers(delta: float) -> void:
	for bed in _ignored.keys():
		_ignored[bed] -= delta
		if _ignored[bed] <= 0.0:
			_ignored.erase(bed)
	if _bubble_left > 0.0:
		_bubble_left -= delta
		_bubble.visible = _bubble_left > 0.0
	if _boost_left > 0.0:
		_boost_left -= delta
	_tick_meals(delta)
	if _chat_left > 0.0:
		_chat_left -= delta
		return
	if _nap_left > 0.0:
		_nap_left -= delta
		return
	if stats.nap_every > 0.0:
		_nap_wait -= delta
		if _nap_wait <= 0.0:
			_nap_left = stats.nap_time
			_nap_wait = stats.nap_every
			say("zzz...", stats.nap_time)
			return
	if stats.chat_every > 0.0:
		_chat_wait -= delta
		if _chat_wait <= 0.0 and _someone_to_chat_with():
			_chat_left = stats.chat_time
			_chat_wait = stats.chat_every
			say("conversando...", stats.chat_time)


## Every MEAL_EVERY seconds the clone owes `consumption` units; once it owes a whole unit it
## heads for the trough. Beliscador feeds itself and never does.
func _tick_meals(delta: float) -> void:
	if stats.no_trough:
		return
	_meal_clock -= delta
	if _meal_clock <= 0.0:
		_meal_clock = Traits.MEAL_EVERY
		_food_owed += stats.consumption
		if _food_owed >= 1.0:
			_meal_due = true
	if _retry_left > 0.0:
		_retry_left -= delta
		if _retry_left <= 0.0 and _food_owed >= 1.0:
			_meal_due = true


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
	if role == Traits.CARRY and dest != null:
		text += " > " + dest.label
	if hungry:
		text += "  (COM FOME)"
	if not traits.is_empty():
		text += "\n" + Traits.labels(traits)
	_tag.text = text
	_tag.modulate = Color(1.0, 0.6, 0.5) if hungry else Color.WHITE
