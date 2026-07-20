class_name Villain
extends Combatant
## Shared base for every stage villain — the "beatable HP target, dormant
## until approached" behavior every villain builds on. Handles the common
## _configure() boilerplate (group/label/position/aggro radius) and the
## alert-gate on _process, so each concrete villain (DarkMage, Berserker,
## MechRobot) only implements its own behavior.

@export var villain_name := "VILLAIN"
## Dormant at the lair until a hero comes within this radius (just inside fog
## vision so it's visible the moment it wakes). See Combatant.is_alerted().
@export var aggro_radius := 350.0

func _configure() -> void:
	self_group = "hostiles"
	add_to_group("villains")
	label_text = villain_name
	if _field != null:
		global_position = _field.villain_pos
	villain_aggro_radius = aggro_radius

func _process(delta: float) -> void:
	if _dying:
		super(delta)  # let the death fade finish
		return
	# Dormant at the lair until the party closes in.
	if not is_alerted():
		return
	super(delta)
	_villain_process(delta)

## Override in a subclass for behavior that only runs once alerted (and not
## dying) — called every frame after the shared engage/movement step above.
func _villain_process(_delta: float) -> void:
	pass

## Nearest living hero at any distance — kiting/hunting/ability targeting is
## field-wide, unlike detect_range (which only gates melee engagement).
func _nearest_hero() -> Combatant:
	var nearest: Combatant = null
	var best := INF
	for node in get_tree().get_nodes_in_group("heroes"):
		if not is_instance_valid(node) or node._dying:
			continue
		var dist := global_position.distance_squared_to(node.global_position)
		if dist < best:
			best = dist
			nearest = node
	return nearest
