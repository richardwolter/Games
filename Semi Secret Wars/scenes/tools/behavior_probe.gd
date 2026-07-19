extends Node
## TEMPORARY verification harness for the priority/behavior pass — not shipped.
## Boots a real battle (all 4 roles, 3 priorities) headless and prints a compact
## PROBE: report so the new targeting/leash/role/ATTACK_MINIONS code is exercised
## end-to-end, not just parsed. Deleted after verification.

const BATTLEFIELD := "res://scenes/battlefield/battlefield.tscn"

func _ready() -> void:
	_run()

func _run() -> void:
	# Configure a party that exercises every role + priority under test.
	GameState.party.clear()
	GameState.run_xp.clear()
	RunState.current_level = 1  # level selects stage_1 config + level_1 layout
	# Focus-fire regime: all four farming the swarm, clustered at one spawn, so
	# their detect ranges overlap and focus fire can actually engage (on the
	# villain push the melee leash is too tight for pools to overlap — that run
	# was measured separately and validated leash/ATTACK_MINIONS/no-errors).
	GameState.set_priority("THUNDAAR", "ATTACK_MINIONS")
	GameState.set_priority("ARTEMIS", "ATTACK_MINIONS")
	GameState.set_priority("WARDEN", "ATTACK_MINIONS")
	GameState.set_priority("BEACON", "ATTACK_MINIONS")
	GameState.set_support_target("BEACON", "ARTEMIS")
	RunState.party = ["THUNDAAR", "ARTEMIS", "WARDEN", "BEACON"]
	RunState.headless = true

	# Instantiate the battlefield as a child rather than change_scene_to_file:
	# this node IS the main scene, and change_scene would free it mid-run,
	# orphaning this coroutine. Autoloads already live on root, so a plain
	# add_child battlefield runs fine (systems find each other by group).
	await get_tree().process_frame
	var bf: Node = load(BATTLEFIELD).instantiate()
	get_tree().root.add_child(bf)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout

	var field := get_tree().get_first_node_in_group("field")
	if field == null:
		print("PROBE: ERROR no field"); get_tree().quit(); return
	var bm = field.get_parent().get_node_or_null("BattleManager")
	if bm == null:
		print("PROBE: ERROR no BattleManager"); get_tree().quit(); return

	var positions: Array = []
	for _i in RunState.selected_heroes().size():
		positions.append(field.hero_spawn)
	bm._on_deploy_chosen(positions)
	await get_tree().process_frame

	# Report per-hero config immediately after spawn (leash / villain-lock split).
	for h in get_tree().get_nodes_in_group("heroes"):
		if h is Hero:
			print("PROBE: %s priority=%s role=%s detect_range=%.1f attack_range=%.1f pushing_villain=%s" % [
				h.hero_name, h.priority, h.role, h.detect_range, h.attack_range, str(h._is_pushing_villain())])

	# Run ~5 sim seconds, sampling targeting each tick.
	Engine.time_scale = 8.0
	var samples := 0
	var shared_target_samples := 0
	var warden_targeted_villain := false
	var warden_intents := {}
	var contact_samples := 0
	var elapsed := 0.0
	while elapsed < 20.0:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		var heroes: Array = []
		for h in get_tree().get_nodes_in_group("heroes"):
			if h is Hero and is_instance_valid(h) and not h._dying:
				heroes.append(h)
		if heroes.is_empty():
			break
		# Focus-fire signal: any two heroes sharing a live target this tick.
		samples += 1
		var targets: Array = []
		var shared := false
		var any_engaged := false
		for h in heroes:
			var t = h._target
			if t != null and is_instance_valid(t):
				any_engaged = true
				if t in targets:
					shared = true
				targets.append(t)
		if any_engaged:
			contact_samples += 1
		if shared:
			shared_target_samples += 1
		# ATTACK_MINIONS (WARDEN): must never lock the villain; intent must read farm.
		for h in heroes:
			if h.hero_name == "WARDEN":
				if h._target != null and is_instance_valid(h._target) and h._target.is_in_group("villains"):
					warden_targeted_villain = true
				var wi: String = h.current_intent()
				warden_intents[wi] = int(warden_intents.get(wi, 0)) + 1
	Engine.time_scale = 1.0

	var frac := 0.0
	if contact_samples > 0:
		frac = float(shared_target_samples) / float(contact_samples)
	print("PROBE: focus_fire shared_target_fraction=%.2f (%d shared / %d contact ticks / %d total)" % [
		frac, shared_target_samples, contact_samples, samples])
	print("PROBE: WARDEN ever_targeted_villain=%s intents=%s" % [str(warden_targeted_villain), str(warden_intents)])
	print("PROBE: DONE")
	get_tree().quit()
