extends Node
## Dev-tool entry point for BalanceSweep — set as the run scene to sweep the
## whole gameplay-loop-rework party-comp matrix headlessly and print a summary
## table (win rate, avg levels cleared, avg sim time, avg survivor HP% per
## party comp) once done. Full per-trial detail lands in
## BALANCE_SWEEP_RESULTS.json (see BalanceSweep). Not shipped; mirrors
## behavior_probe.tscn as a standing dev harness.

func _ready() -> void:
	await get_tree().process_frame  # let root finish setting up before add_child
	var sweep := BalanceSweep.new()
	get_tree().root.add_child(sweep)
	sweep.sweep_complete.connect(_on_sweep_complete)
	sweep.start()

func _on_sweep_complete(results: Array) -> void:
	print("\n=== BALANCE SWEEP SUMMARY (%d trials total) ===" % results.size())
	var by_comp := {}
	for r in results:
		var key: String = ",".join(r.party)
		if not by_comp.has(key):
			by_comp[key] = []
		by_comp[key].append(r)

	for key in by_comp:
		var trials: Array = by_comp[key]
		var n := trials.size()
		var total_levels_cleared := 0
		var run_completes := 0
		var timeouts := 0
		var level_clears := {}  # level -> count of trials that cleared it
		var level_sim_seconds := {}  # level -> Array of sim_seconds samples
		var level_survivor_hp := {}  # level -> Array of hp% samples (on a win)
		for r in trials:
			total_levels_cleared += int(r.levels_cleared)
			if r.run_complete:
				run_completes += 1
			for lvl_entry in r.levels:
				var lvl: int = lvl_entry.level
				if lvl_entry.outcome == "timeout":
					timeouts += 1
				if lvl_entry.outcome == "win":
					level_clears[lvl] = int(level_clears.get(lvl, 0)) + 1
					var hps: Array = level_survivor_hp.get(lvl, [])
					for h in lvl_entry.survivor_hp.values():
						hps.append(float(h))
					level_survivor_hp[lvl] = hps
				var secs: Array = level_sim_seconds.get(lvl, [])
				secs.append(float(lvl_entry.sim_seconds))
				level_sim_seconds[lvl] = secs

		print("\n-- %s (%d trials) --" % [key, n])
		print("  avg levels_cleared: %.2f / %d   run_complete_rate: %d%%   timeouts: %d" % [
			float(total_levels_cleared) / n, BalanceSweep.MAX_LEVELS,
			int(100.0 * run_completes / n), timeouts])
		for lvl in range(1, BalanceSweep.MAX_LEVELS + 1):
			var clears := int(level_clears.get(lvl, 0))
			var secs: Array = level_sim_seconds.get(lvl, [])
			var avg_secs := 0.0
			for s in secs:
				avg_secs += s
			avg_secs = avg_secs / secs.size() if not secs.is_empty() else 0.0
			var attempts := secs.size()
			if attempts == 0:
				continue
			var hp_line := ""
			var hps: Array = level_survivor_hp.get(lvl, [])
			if not hps.is_empty():
				var avg_hp := 0.0
				for h in hps:
					avg_hp += h
				hp_line = "   avg survivor HP on win: %.1f" % (avg_hp / hps.size())
			print("  L%d: clear rate %d%% (%d/%d attempts)   avg sim time %.1fs%s" % [
				lvl, int(100.0 * clears / attempts), clears, attempts, avg_secs, hp_line])
	print("\n=== full detail in BALANCE_SWEEP_RESULTS.json ===")
	get_tree().quit(0)
