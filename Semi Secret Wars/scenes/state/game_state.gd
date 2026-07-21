extends Node
## GameState autoload — persistent META progression for the hybrid-roguelite loop.
##
## Milestone 2: retired the old persistent per-hero stat grind (flat XP-bought
## upgrades + skill-tree ability nodes, saved to user://save.json). Runs no
## longer bank permanent stats — a hero always starts a run at its flat base
## stats (see Hero._configure) and grows only through in-run boons (RunState),
## which reset every run. What persists here instead is the META layer: a
## currency earned per run, spent (in a later milestone) to unlock new heroes
## and relics into the pool. See IMPLEMENTATION_PLAN.md M2 / DECISIONS.md.
##
## Dev helper: F12 does a full reset (save + in-run state + persisted fog) and
## returns to the prep menu — see full_reset().

const SAVE_PATH := "user://save.json"
const PREP_MENU := "res://scenes/prep/prep_menu.tscn"
const BATTLEFIELD := "res://scenes/battlefield/battlefield.tscn"
const FOG_DIR := "user://fog"

## Gold awarded at run end (spent on permanent ability mods at prep). Scales with
## levels cleared this run — deeper runs pay more — with a win bonus on top and a
## floor so even a level-1 wipe pays something. First pass, tune in BALANCE.md.
const GOLD_PER_LEVEL := 10
const GOLD_WIN_BONUS := 15
const GOLD_MIN := 5

## Fraction of a kill's XP every *other* living hero banks (killer gets 100%),
## so tanks/screeners progress even without landing killing blows.
const KILL_ASSIST_SHARE := 0.5

## Save schema version. v3 = hybrid roguelite (persistent stat grind removed).
## v4 = gameplay-loop rework (run = chain of levels; gold + owned ability mods;
## stage_1_won/stage select retired). v5 = V2 grind progression (career
## achievements + ability tiers). v6 = banked_xp changed from per-hero
## Dictionary to a single shared int pool (Designer, 2026-07-19: "XP shared
## between all heroes"). v7 = Duo system (duo_pairings added — see
## duo_of/set_duo_pairings). v8 = per-hero lifetime stat tracking (hero_stats:
## kills/xp/ability hit-rate — display-only, not spendable currency, separate
## from the shared banked_xp pool). Any save below this is discarded on load —
## a clean break the Designer approved rather than migrating old data forward.
const SAVE_VERSION := 8

## Roster catalog: display order, colors. Grows as heroes are added.
const HERO_CATALOG := {
	"THUNDAAR": {"color": Color(0.29, 0.471, 0.753)},
	"ARTEMIS": {"color": Color(0.816, 0.435, 0.627)},
	"WARDEN": {"color": Color(0.25, 0.62, 0.60)},
	"BEACON": {"color": Color(0.88, 0.72, 0.30)},
}

## XP gained per hero in the current run (for the results screen — display only,
## not currency; in-run power comes from RunState's level/boon track).
var run_xp := {}
## Kill count per hero in the current run — display only (hero cards), reset
## by start_run(). See record_hero_kill.
var run_kills := {}
## Special-ability cast attempts/successful-hits per hero in the current run —
## display only (hero cards), reset by start_run(). "Successful" means the
## cast actually affected an enemy (see record_ability_result); basic attacks
## are excluded since they have no miss mechanic and would always read 100%.
var run_ability_attempts := {}
var run_ability_hits := {}

## -- Meta progression ---------------------------------------------------------

## Persistent currency spent at the ability shop on permanent per-hero mods.
var gold := 0
## Ability-mod ids bought and owned forever (AbilityMods catalog). Applied at
## spawn in Hero._apply_owned_ability_mods.
var owned_mods: Array = []
## Ability-tier ids bought and owned forever (AbilityTiers catalog —
## "<HERO>_2"/"<HERO>_3"). Tier-gates the ability flags Hero._configure sets.
## See has_tier/buy_tier.
var owned_ability_tiers: Array = []
## Heroes currently available for the party/draft. Starts with the full
## roster unlocked (Designer, 2026-07-20: need all 4 heroes day-one to test
## the Duo system — both pairing combinations and staggered deploy need 4
## live heroes). Achievement-gated unlocking (see _check_achievements) stays
## wired up underneath but is a no-op while everyone starts unlocked.
var unlocked_heroes: Array = ["THUNDAAR", "ARTEMIS", "WARDEN", "BEACON"]
## Relic ids available for the run-boon pool (scaffolding for a later
## milestone — no relics exist yet, so this stays empty).
var unlocked_relics: Array = []

## Lifetime career counters (minions_killed, gates_destroyed,
## best_villain_damage_pct, runs_played), accumulated across every run, win
## or lose. Drives Achievements hero unlocks — see record_career/record_career_max.
var career := {}

## Persistent XP currency, shared across the whole roster like gold.
## Every point of XP any hero earns banks here permanently (see add_xp) — it is
## NEVER reset by a new run starting; the only two ways it changes are being
## earned or being spent (buy_stat_upgrade) on any hero's permanent raw stat
## upgrades (StatUpgrades). Separate pool from gold, which spends on abilities.
var banked_xp := 0
## hero_name -> {stat_id: purchases int} — how many times each stat has been
## bought for that hero. Drives both StatUpgrades.cost_for's scaling and the
## stat bonus applied at spawn (Hero._apply_stat_upgrades).
var stat_purchases: Dictionary = {}

## Lifetime per-hero stats, accumulated across every run (prep-menu display —
## "Total kills", "Total XP gained", "Ability effectiveness"). hero_name ->
## {"kills": int, "xp": int, "ability_attempts": int, "ability_hits": int}.
## `xp` here is a separate running total from banked_xp — banked_xp is the
## shared spendable currency (v6, per-hero tracking removed); this is purely
## a lifetime counter for display, never spent. See record_hero_kill,
## record_ability_result, add_xp.
var hero_stats: Dictionary = {}

func _hero_stat(hero_name: String) -> Dictionary:
	if not hero_stats.has(hero_name):
		hero_stats[hero_name] = {"kills": 0, "xp": 0, "ability_attempts": 0, "ability_hits": 0}
	return hero_stats[hero_name]

## Killing-blow credit only (matches award_kill_xp's killer-gets-full-XP rule
## — assists don't count as a kill). Fires per-kill against a swarm, so no
## save here (see record_career's same reasoning); persisted by the next
## save_game() (run end, or any other persistent-state change).
func record_hero_kill(hero_name: String) -> void:
	_hero_stat(hero_name)["kills"] += 1
	run_kills[hero_name] = int(run_kills.get(hero_name, 0)) + 1

## Tracks one special-ability cast attempt and whether it actually landed on
## an enemy (Hero._try_* already computes this locally — e.g. Ensnare's `hit`,
## Rally's `buffed` — this just records it). Only call for casts that got past
## the "nothing to aim at" guard; a cast that never fires at all isn't a miss,
## it's a no-op. No save — same high-frequency reasoning as record_hero_kill.
func record_ability_result(hero_name: String, success: bool) -> void:
	var stat := _hero_stat(hero_name)
	stat["ability_attempts"] += 1
	run_ability_attempts[hero_name] = int(run_ability_attempts.get(hero_name, 0)) + 1
	if success:
		stat["ability_hits"] += 1
		run_ability_hits[hero_name] = int(run_ability_hits.get(hero_name, 0)) + 1

## -- Hero stat readouts (prep card = lifetime, battle card = current run) ----

func hero_kills_lifetime(hero_name: String) -> int:
	return int(hero_stats.get(hero_name, {}).get("kills", 0))

func hero_kills_run(hero_name: String) -> int:
	return int(run_kills.get(hero_name, 0))

func hero_xp_lifetime(hero_name: String) -> int:
	return int(hero_stats.get(hero_name, {}).get("xp", 0))

func hero_xp_run(hero_name: String) -> int:
	return int(run_xp.get(hero_name, 0))

## -1.0 when no ability has been cast yet (nothing to divide) — callers should
## show "—" rather than a misleading 0%.
func hero_ability_pct_lifetime(hero_name: String) -> float:
	var stat: Dictionary = hero_stats.get(hero_name, {})
	var attempts := int(stat.get("ability_attempts", 0))
	if attempts <= 0:
		return -1.0
	return 100.0 * int(stat.get("ability_hits", 0)) / attempts

func hero_ability_pct_run(hero_name: String) -> float:
	var attempts := int(run_ability_attempts.get(hero_name, 0))
	if attempts <= 0:
		return -1.0
	return 100.0 * int(run_ability_hits.get(hero_name, 0)) / attempts

## -- Duo pairings ---------------------------------------------------------

## Persistent Duo pairing: an Array of exactly 2 Duos, each an Array of exactly
## 2 distinct hero names covering the current 4-hero roster with no overlap.
## Set from the prep screen's Pairings panel (PrepMenu._on_pairing_chip_pressed)
## and read at deploy time to sequence the two Duos onto the field
## (DeployController/BattleManager). Empty/invalid means "not paired yet" —
## callers must check has_valid_duo_pairings before relying on it.
var duo_pairings: Array = []

## How many seconds after the first-deployed Duo lands the second Duo
## arrives. Set (and remembered run-to-run) via the deploy screen's stepper
## (DeployController) so the player can tune arrival timing across attempts —
## "play with the timer to find the best moment" — rather than re-deciding it
## fresh every run. Persisted; not reset by start_run() or a new level.
const DUO_B_DELAY_MIN := 0.0
const DUO_B_DELAY_MAX := 30.0
const DUO_B_DELAY_DEFAULT := 10.0
var duo_b_delay_seconds: float = DUO_B_DELAY_DEFAULT

## Clamps and persists a new deploy-stagger value. Saves immediately, same as
## the other prep-screen dials (buy_mod/buy_tier/set_duo_pairings) — this one
## just changes via a stepper instead of a purchase.
func set_duo_b_delay(seconds: float) -> void:
	duo_b_delay_seconds = clampf(seconds, DUO_B_DELAY_MIN, DUO_B_DELAY_MAX)
	save_game()

func _ready() -> void:
	load_game()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		full_reset()

## -- Run flow ---------------------------------------------------------------

func start_run() -> void:
	run_xp.clear()
	run_kills.clear()
	run_ability_attempts.clear()
	run_ability_hits.clear()

## Kill XP: killer banks the full value; every other living hero banks the
## assist share (rounded up), so XP flows to the whole party (BALANCE.md).
func award_kill_xp(killer: Node, amount: int) -> void:
	add_xp(killer.hero_name, amount)
	var assist := int(ceil(amount * KILL_ASSIST_SHARE))
	for h in killer.get_tree().get_nodes_in_group("heroes"):
		if h != killer and h is Hero:
			add_xp(h.hero_name, assist)

## Single chokepoint for all run XP (kills + objectives): tracks this run's
## per-hero total for the results screen and feeds the in-run level track
## (RunState), which is what actually grows a hero's power now. Every point
## also banks permanently into the shared persistent currency (banked_xp) —
## unlike run_xp/RunState's level track (which reset every run by design,
## since in-run boons are meant to be temporary), banked_xp only ever changes
## by being earned here or spent (buy_stat_upgrade), and isn't tied to which
## hero earned it — the player spends it on any hero from the STATS shop.
func add_xp(hero_name: String, amount: int) -> void:
	if amount <= 0:
		return
	run_xp[hero_name] = int(run_xp.get(hero_name, 0)) + amount
	RunState.record_xp(hero_name, amount)
	banked_xp += amount
	_hero_stat(hero_name)["xp"] += amount

## -- Meta currency / unlocks --------------------------------------------------

func award_gold(amount: int) -> void:
	gold += amount
	save_game()

## Increments gold WITHOUT saving to disk — the per-kill/per-gate drip
## (LaneSpawner) against a 50-minion swarm would thrash file I/O if it saved
## every time like award_gold() does. Flushed by the save_game() inside the
## eventual award_gold() call at BattleManager._end().
func bank_gold(amount: int) -> void:
	gold += amount

## Gold payout for a finished run: scales with levels cleared, +bonus on a win,
## never below GOLD_MIN. `levels_cleared` is how many levels the run beat.
func gold_for_run(win: bool, levels_cleared: int) -> int:
	var payout := GOLD_PER_LEVEL * maxi(levels_cleared, 0) + (GOLD_WIN_BONUS if win else 0)
	return maxi(payout, GOLD_MIN)

func has_mod(id: String) -> bool:
	return id in owned_mods

## Buys a permanent ability mod if affordable and not already owned. Returns
## true on success. Saves immediately.
func buy_mod(id: String) -> bool:
	if id in owned_mods:
		return false
	var cost := int(AbilityMods.def(id).get("cost", 0))
	if AbilityMods.def(id).is_empty() or gold < cost:
		return false
	gold -= cost
	owned_mods.append(id)
	save_game()
	return true

func is_hero_unlocked(hero_name: String) -> bool:
	return hero_name in unlocked_heroes

func unlock_hero(hero_name: String) -> void:
	if hero_name not in unlocked_heroes:
		unlocked_heroes.append(hero_name)
		save_game()

func is_relic_unlocked(id: String) -> bool:
	return id in unlocked_relics

func unlock_relic(id: String) -> void:
	if id not in unlocked_relics:
		unlocked_relics.append(id)
		save_game()

## -- Career stats / achievements ----------------------------------------------

## Increments without saving to disk — this fires per-kill/per-gate against a
## 50-minion swarm, so a save here would thrash file I/O the same way a per-kill
## award_gold() would (see bank_gold). Persisted by the eventual save_game()
## at run end, or immediately the moment an achievement unlocks a hero.
func record_career(stat: String, amount: int) -> void:
	career[stat] = int(career.get(stat, 0)) + amount
	_check_achievements()

## Like record_career, but keeps the running maximum instead of summing (e.g.
## best_villain_damage_pct across every level/run attempted).
func record_career_max(stat: String, value: float) -> void:
	if value > float(career.get(stat, 0.0)):
		career[stat] = value
		_check_achievements()

func _check_achievements() -> void:
	for id in Achievements.ids():
		var d := Achievements.def(id)
		var hero_name: String = d.get("unlocks_hero", "")
		if hero_name == "" or is_hero_unlocked(hero_name):
			continue
		if float(career.get(d.get("stat", ""), 0)) >= float(d.get("threshold", 0)):
			unlock_hero(hero_name)  # saves immediately — the achievement is safe on crash

## -- Ability tiers -------------------------------------------------------------

## Tier 1 (the signature ability — Stomp/Clone/Ensnare/Rally) is free the
## moment a hero is unlocked; tiers 2-3 are gold-gated (AbilityTiers catalog).
func has_tier(hero_name: String, tier: int) -> bool:
	if tier <= 1:
		return true
	return "%s_%d" % [hero_name, tier] in owned_ability_tiers

## Buys an ability tier if affordable, not already owned, and its prerequisite
## (the previous tier) is owned. Returns true on success. Saves immediately —
## a deliberate, infrequent player action, same as buy_mod.
func buy_tier(id: String) -> bool:
	if id in owned_ability_tiers:
		return false
	var d := AbilityTiers.def(id)
	if d.is_empty():
		return false
	if not AbilityTiers.prereq_met(id):
		return false
	var cost := int(d.get("cost", 0))
	if gold < cost:
		return false
	gold -= cost
	owned_ability_tiers.append(id)
	save_game()
	return true

## -- Raw stat upgrades ---------------------------------------------------------

func stat_purchase_count(hero_name: String, stat_id: String) -> int:
	return int(stat_purchases.get(hero_name, {}).get(stat_id, 0))

## Buys one more level of a raw stat upgrade for a hero (cost rises with prior
## purchases — see StatUpgrades.cost_for). Returns true on success. Saves
## immediately, same as buy_mod/buy_tier.
func buy_stat_upgrade(hero_name: String, stat_id: String) -> bool:
	var count := stat_purchase_count(hero_name, stat_id)
	var cost := StatUpgrades.cost_for(stat_id, count)
	if cost <= 0 or banked_xp < cost:
		return false
	banked_xp -= cost
	if not stat_purchases.has(hero_name):
		stat_purchases[hero_name] = {}
	stat_purchases[hero_name][stat_id] = count + 1
	save_game()
	return true

## -- Duo pairings -------------------------------------------------------------

## The paired partner of `hero_name`, or "" if unpaired/pairings invalid.
func duo_of(hero_name: String) -> String:
	for duo in duo_pairings:
		if not (duo is Array):
			continue
		if hero_name in duo:
			for h in duo:
				if h != hero_name:
					return h
	return ""

## Whether `hero_name` leads its Duo — a pure player choice (Designer,
## 2026-07-20: "tank always leads does not work anymore ... this should be a
## player decision"), NOT derived from role. Leader is whichever hero was
## dropped in that Duo's first (left/A) pairing slot — see
## PrepMenu._sync_party_from_slots, which builds each pair as [slot_0, slot_1]
## in drop order. False for an unpaired hero (matches Hero._duo_leader's
## "no partner = irrelevant" default).
func is_duo_leader(hero_name: String) -> bool:
	for duo in duo_pairings:
		if duo is Array and (duo as Array).size() == 2 and duo[0] == hero_name:
			return true
	return false

## True when duo_pairings is exactly 2 Duos of 2 distinct heroes each,
## together covering `roster` (order-independent) with no repeats.
func has_valid_duo_pairings(roster: Array) -> bool:
	if duo_pairings.size() != 2:
		return false
	var seen: Array = []
	for duo in duo_pairings:
		if not (duo is Array) or (duo as Array).size() != 2:
			return false
		for h in duo:
			if h in seen:
				return false
			seen.append(h)
	var sorted_seen: Array = seen.duplicate()
	sorted_seen.sort()
	var sorted_roster: Array = roster.duplicate()
	sorted_roster.sort()
	return sorted_seen == sorted_roster

## Sets the Duo pairing (see has_valid_duo_pairings for the expected shape)
## and saves immediately — a deliberate, infrequent player action, same as
## buy_mod/buy_tier. Pass [] to clear.
func set_duo_pairings(pairs: Array) -> void:
	duo_pairings = pairs
	save_game()

## -- Persistence -------------------------------------------------------------

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({
			"version": SAVE_VERSION,
			"gold": gold,
			"owned_mods": owned_mods,
			"unlocked_heroes": unlocked_heroes,
			"unlocked_relics": unlocked_relics,
			"career": career,
			"owned_ability_tiers": owned_ability_tiers,
			"banked_xp": banked_xp,
			"stat_purchases": stat_purchases,
			"duo_pairings": duo_pairings,
			"duo_b_delay_seconds": duo_b_delay_seconds,
			"hero_stats": hero_stats,
		}))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if not (data is Dictionary):
		return
	if int(data.get("version", 1)) < SAVE_VERSION:
		# Pre-v3 save (the old persistent stat grind): a clean break, not a
		# migration — Designer-approved wipe (see DECISIONS.md). Leave every
		# var at its fresh-start default.
		return
	gold = int(data.get("gold", 0))
	owned_mods = data.get("owned_mods", [])
	var saved_heroes: Variant = data.get("unlocked_heroes", null)
	if saved_heroes is Array and not (saved_heroes as Array).is_empty():
		unlocked_heroes = saved_heroes
	unlocked_relics = data.get("unlocked_relics", [])
	career = data.get("career", {})
	owned_ability_tiers = data.get("owned_ability_tiers", [])
	banked_xp = int(data.get("banked_xp", 0))
	stat_purchases = data.get("stat_purchases", {})
	duo_pairings = data.get("duo_pairings", [])
	duo_b_delay_seconds = float(data.get("duo_b_delay_seconds", DUO_B_DELAY_DEFAULT))
	hero_stats = data.get("hero_stats", {})

## Resets the in-memory persistent vars to fresh-start defaults WITHOUT deleting
## the save file.
func _reset_state_defaults() -> void:
	run_xp = {}
	run_kills = {}
	run_ability_attempts = {}
	run_ability_hits = {}
	gold = 0
	owned_mods = []
	owned_ability_tiers = []
	banked_xp = 0
	stat_purchases = {}
	duo_pairings = []
	duo_b_delay_seconds = DUO_B_DELAY_DEFAULT
	unlocked_heroes = ["THUNDAAR", "ARTEMIS", "WARDEN", "BEACON"]
	unlocked_relics = []
	career = {}
	hero_stats = {}

func reset_save() -> void:
	_reset_state_defaults()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

## Full dev reset: wipes the save (this GameState autoload), the in-run chain
## state (RunState — current_level/hp_carry/dead/levels/boons/draft), and the
## persisted per-level fog-of-war ("progress is knowledge" — a stale fog PNG
## would make a "fresh" Level 1 open pre-explored), then returns to the prep
## menu so the player always lands somewhere clean regardless of where they
## pressed F12 (mid-battle, results screen, etc). reset_save() alone used to
## be wired to F12 but only wiped this autoload — RunState and fog survived,
## so a "reset" from mid-run silently kept the old level/HP/fog state.
func full_reset() -> void:
	reset_save()
	RunState.start_run()
	RunState.party.clear()
	RunState.draft_offer.clear()
	_clear_fog_dir()
	get_tree().paused = false
	get_tree().change_scene_to_file(PREP_MENU)

func _clear_fog_dir() -> void:
	var abs_path := ProjectSettings.globalize_path(FOG_DIR)
	var dir := DirAccess.open(abs_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
