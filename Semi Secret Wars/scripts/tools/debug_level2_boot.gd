extends Node
## TEMP debug harness (2026-07-25): boots straight into LEVEL 2 with a full
## party auto-deployed, so the Berserk swarm, the syringe shooter and the
## rolling boulders can be watched without playing through level 1 or clicking
## the deploy phase. Not shipped — run it explicitly as the main scene:
##
##   Godot_v4.7.1-stable_win64.exe --path . res://scripts/tools/debug_level2.tscn
##
## Start-of-level Duo Ultimate picks still pause and wait for a click; the
## auto-deploy fires once they're drained.

const PARTY := ["THUNDAAR", "ARTEMIS", "WARDEN", "BEACON"]

var _deployed := false
## True only on the spawned copy. The main scene's ROOT is already a child of
## get_tree().root, so "am I parented to root?" can't tell the two apart —
## which is why the first attempt freed itself the moment change_scene ran and
## the auto-deploy never fired.
var _is_helper := false

func _ready() -> void:
	# Survive the change_scene below by living beside the current scene under
	# the tree root, not inside the scene being replaced. PROCESS_MODE_ALWAYS
	# so the auto-deploy still ticks while a pick screen has the tree paused.
	if not _is_helper:
		var helper: Node = get_script().new()
		helper.name = "DebugLevel2Boot"
		helper._is_helper = true
		helper.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().root.add_child.call_deferred(helper)
		return
	print("[debug_level2] harness up — booting level 2")
	GameState.start_run()
	RunState.start_run()
	RunState.party = PARTY.duplicate()
	RunState.current_level = 2
	var err := get_tree().change_scene_to_file(GameState.BATTLEFIELD)
	if err != OK:
		push_error("[debug_level2] change_scene failed: %d" % err)

func _process(_delta: float) -> void:
	if _deployed:
		return
	var manager := get_tree().get_first_node_in_group("battle_manager")
	if manager == null:
		# BattleManager isn't grouped; walk the current scene for it instead.
		manager = _find_manager(get_tree().current_scene)
	if manager == null or manager._deploy == null:
		return
	if not manager._pick_queue.is_empty() or manager._pick_screen != null:
		return
	_deployed = true
	_auto_deploy(manager)

func _find_manager(node: Node) -> Node:
	if node == null:
		return null
	if node is BattleManager:
		return node
	for child in node.get_children():
		var found := _find_manager(child)
		if found != null:
			return found
	return null

## Fires BattleManager._on_deploy_chosen directly with the whole party spread
## across the deploy band — same payload shape DeployController builds from
## clicks.
func _auto_deploy(manager: Node) -> void:
	var field: LaneField = manager._field
	var names: Array = RunState.living_party()
	var positions: Array = []
	var x: float = (field.deploy_band_x_min + field.deploy_band_x_max) * 0.5
	for i in names.size():
		# Two per lane half, staggered along x so nobody starts stacked.
		var y: float = field.lane_half_height * (-0.5 if i % 2 == 0 else 0.5)
		positions.append(Vector2(x + (i / 2) * 120.0, y))
	manager._on_deploy_chosen({
		"names": names,
		"positions": positions,
	})
	print("[debug_level2] auto-deployed %d heroes on level %d" % [names.size(), RunState.current_level])
