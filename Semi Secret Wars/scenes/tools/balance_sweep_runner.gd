extends Node
## Dev-tool entry point for BalanceSweep — set as the run scene to sweep the
## whole gameplay-loop-rework party-comp matrix headlessly and print a summary
## table (win rate, avg levels cleared, avg sim time, avg survivor HP% per
## party comp) once done. Full per-trial detail lands in
## BALANCE_SWEEP_RESULTS*.json (see BalanceSweep). Not shipped; mirrors
## behavior_probe.tscn as a standing dev harness.
##
## Runs TWO passes back to back (2026-07-19 MVP pass): a zero-mod FLOOR (what
## a fresh player with no gold spent experiences) and a WITH-MODS pass (one
## representative upside-only mod per hero — Iron Skin/Glass Arrows/Overcharge/
## Zealot, the flat power picks). This directly answers the design question
## "should L3 require at least one ability upgrade per hero to reliably clear"
## instead of silently riding on whatever GameState.owned_mods happens to be
## on load (previously the sweep-runner's own dev save state, unset by design).

## One flat-power upside pick per hero (matches ability_mods.gd's catalog).
## Downsides are currently disabled game-wide (see BALANCE.md/ability_mods.gd),
## so these are the strict-upgrade picks a player optimizing for L3 would buy.
const REPRESENTATIVE_MOD_LOADOUT := ["iron_skin", "glass_arrows", "overcharge", "zealot"]

## Priority variation was flagged (BALANCE.md 2026-07-19) as never swept — every
## prior pass silently rides on GameState's DEFAULT_PRIORITY (BEACON=SUPPORT_ALLIES,
## everyone else=ATTACK_VILLAIN). This forces the opposite extreme — every hero
## farms the swarm and never commits to the villain — to see whether priority
## choice actually moves the needle vs. the default "push" profile. Zero mods,
## so the comparison isolates priority from gold spend.
const ALT_PRIORITY_ALL_FARM := {
	"THUNDAAR": "ATTACK_MINIONS", "ARTEMIS": "ATTACK_MINIONS",
	"WARDEN": "ATTACK_MINIONS", "BEACON": "ATTACK_MINIONS",
}

var _passes: Array = [
	{"label": "ZERO MODS (floor)", "mods": [], "path": "res://BALANCE_SWEEP_RESULTS_no_mods.json"},
	{"label": "WITH MODS (1 upgrade/hero)", "mods": REPRESENTATIVE_MOD_LOADOUT, "path": "res://BALANCE_SWEEP_RESULTS_with_mods.json"},
	{"label": "ALT PRIORITY (all Attack Minions, zero mods)", "mods": [], "priority": ALT_PRIORITY_ALL_FARM, "path": "res://BALANCE_SWEEP_RESULTS_alt_priority.json"},
]
var _pass_i := 0

func _ready() -> void:
	await get_tree().process_frame  # let root finish setting up before add_child
	_run_next_pass()

func _run_next_pass() -> void:
	if _pass_i >= _passes.size():
		get_tree().quit(0)
		return
	var p: Dictionary = _passes[_pass_i]
	print("\n########## PASS %d/%d: %s ##########" % [_pass_i + 1, _passes.size(), p.label])
	var sweep := BalanceSweep.new()
	sweep.mod_loadout = p.mods
	sweep.priority_overrides = p.get("priority", {})
	sweep.results_path = p.path
	get_tree().root.add_child(sweep)
	sweep.sweep_complete.connect(_on_pass_complete.bind(sweep, p.label))
	sweep.start()

func _on_pass_complete(results: Array, sweep: Node, label: String) -> void:
	_print_summary(results, label)
	sweep.queue_free()
	_pass_i += 1
	_run_next_pass()

func _print_summary(results: Array, label: String) -> void:
	print("\n=== BALANCE SWEEP SUMMARY: %s (%d trials total) ===" % [label, results.size()])
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
		var level_survivor_hp := {}  # level -> Array of hp samples (on a win)
		var level_entry_hp := {}  # level -> Array of entry-hp samples (all attempts)
		var level_alert := {}  # level -> Array of time_to_villain_alert (>=0 only)
		var level_peak := {}  # level -> Array of peak_minions samples
		var level_hero_lvl := {}  # level -> Array of per-hero in-run levels reached
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
				# New MVP diagnostics (guarded with .get so older JSON still parses).
				var ehp: Array = level_entry_hp.get(lvl, [])
				for h in lvl_entry.get("entry_hp", {}).values():
					ehp.append(float(h))
				level_entry_hp[lvl] = ehp
				var alert: float = float(lvl_entry.get("time_to_villain_alert", -1.0))
				if alert >= 0.0:
					var al: Array = level_alert.get(lvl, [])
					al.append(alert)
					level_alert[lvl] = al
				var pk: Array = level_peak.get(lvl, [])
				pk.append(float(lvl_entry.get("peak_minions", 0)))
				level_peak[lvl] = pk
				var hl: Array = level_hero_lvl.get(lvl, [])
				for v in lvl_entry.get("hero_levels", {}).values():
					hl.append(float(v))
				level_hero_lvl[lvl] = hl

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
				hp_line = "   avg survivor HP on win: %.1f" % _avg(hps)
			print("  L%d: clear rate %d%% (%d/%d attempts)   avg sim time %.1fs%s" % [
				lvl, int(100.0 * clears / attempts), clears, attempts, avg_secs, hp_line])
			# Diagnostic line: entry HP, when/if the villain woke, swarm peak, and
			# how far heroes leveled — the numbers that say WHY a level fails, not
			# just that it did (travel death vs. depleted entry vs. under-leveled).
			var alert: Array = level_alert.get(lvl, [])
			var alert_str := "never" if alert.is_empty() \
				else "%.1fs (%d/%d woke)" % [_avg(alert), alert.size(), attempts]
			print("      entry HP %.1f   villain alert %s   peak swarm %.0f   avg hero lvl %.1f" % [
				_avg(level_entry_hp.get(lvl, [])), alert_str,
				_avg(level_peak.get(lvl, [])), _avg(level_hero_lvl.get(lvl, []))])
	print("\n=== full detail: see each pass's BALANCE_SWEEP_RESULTS_*.json ===")

## Mean of a numeric Array, 0.0 when empty (keeps the summary print branch-free).
func _avg(samples: Array) -> float:
	if samples.is_empty():
		return 0.0
	var total := 0.0
	for s in samples:
		total += float(s)
	return total / samples.size()
