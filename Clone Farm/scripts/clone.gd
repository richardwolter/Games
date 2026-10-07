## A clone: a Worker with a role. It works that role across the whole farm, picking the
## nearest bed that wants it and that no other worker is on, under the same rules as the
## farmer (walk to the bed, locked in place while working). No role: it stands idle.
## Traits come in a later slice.
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

var role := &""

var _tag: Label3D


func _ready() -> void:
	super()
	add_to_group("clones")
	_tag = Label3D.new()
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.pixel_size = 0.01
	_tag.font_size = 36
	_tag.outline_size = 8
	_tag.position.y = 1.4
	add_child(_tag)
	_refresh_tag()


func set_role(new_role: StringName) -> void:
	role = new_role
	cancel_work()
	_refresh_tag()


func _think() -> void:
	if is_working() or role == &"":
		return
	var bed := pick_bed()
	if bed != null:
		work(bed)


## The nearest bed that wants this clone's role and that no other worker is on, or null.
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
		if bed.next_task() != role or taken.has(bed):
			continue
		var d := _ground(bed.global_position - global_position).length()
		if d < best_d:
			best = bed
			best_d = d
	return best


func _refresh_tag() -> void:
	_tag.text = "%s: %s" % [name, ROLE_LABELS[role]]
