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
## stage_1_won/stage select retired). Any save below this is discarded on load —
## a clean break the Designer approved rather than migrating old data forward.
const SAVE_VERSION := 4

## Roster catalog: display order, colors. Grows as heroes are added.
const HERO_CATALOG := {
	"THUNDAAR": {"color": Color(0.29, 0.471, 0.753)},
	"ARTEMIS": {"color": Color(0.816, 0.435, 0.627)},
	"WARDEN": {"color": Color(0.25, 0.62, 0.60)},
	"BEACON": {"color": Color(0.88, 0.72, 0.30)},
}

## Battlefield priorities a hero can be assigned pre-battle (GDD §11).
## SUPPORT_ALLIES un-deferred in Milestone 5 now that a support hero (BEACON)
## with an ally-buff ability (Rally) exists.
const PRIORITIES := {
	"CAPTURE_OBJECTIVES": "Capture Objectives",
	"ATTACK_VILLAIN": "Attack Villain",
	"ATTACK_MINIONS": "Attack Minions",
	"SUPPORT_ALLIES": "Support Allies",
}

## party[name] = {"priority": String, "support_target": String} — set on the
## prep screen. support_target only matters while priority is SUPPORT_ALLIES:
## "" means follow the nearest living ally (default); otherwise it names one
## specific drafted hero to shadow instead.
## (role is now fixed per hero and set in Hero._configure, not here). Which
## heroes are actually fielded this run is a draft pick, not a persisted
## setting — see RunState.party (Milestone 3).
var party := {}
## XP gained per hero in the current run (for the results screen — display only,
## not currency; in-run power comes from RunState's level/boon track).
var run_xp := {}

## -- Meta progression ---------------------------------------------------------

## Persistent currency spent at the ability shop on permanent per-hero mods.
var gold := 0
## Ability-mod ids bought and owned forever (AbilityMods catalog). Applied at
## spawn in Hero._apply_owned_ability_mods.
var owned_mods: Array = []
## Heroes currently available for the party/draft. Defaults to every hero
## that exists in code today; new heroes added to HERO_CATALOG in a future
## milestone start locked out of this list until unlocked.
var unlocked_heroes: Array = HERO_CATALOG.keys()
## Relic ids available for the run-boon pool (scaffolding for a later
## milestone — no relics exist yet, so this stays empty).
var unlocked_relics: Array = []

func _ready() -> void:
	load_game()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		full_reset()

## -- Run flow ---------------------------------------------------------------

func start_run() -> void:
	run_xp.clear()

## -- Party / priorities -------------------------------------------------------

## Sensible default priority per hero (most push the villain; the support
## defaults to shadowing the party so its aura lands out of the box).
const DEFAULT_PRIORITY := {"BEACON": "SUPPORT_ALLIES"}

func party_of(hero_name: String) -> Dictionary:
	if not party.has(hero_name):
		party[hero_name] = {
			"priority": DEFAULT_PRIORITY.get(hero_name, "ATTACK_VILLAIN"),
			"support_target": "",
		}
	return party[hero_name]

func set_priority(hero_name: String, priority: String) -> void:
	party_of(hero_name).priority = priority

## Which specific ally `hero_name` should shadow while on SUPPORT_ALLIES
## priority ("" = nearest living ally, the default).
func set_support_target(hero_name: String, target: String) -> void:
	party_of(hero_name).support_target = target

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
## (RunState), which is what actually grows a hero's power now.
func add_xp(hero_name: String, amount: int) -> void:
	if amount <= 0:
		return
	run_xp[hero_name] = int(run_xp.get(hero_name, 0)) + amount
	RunState.record_xp(hero_name, amount)

## -- Meta currency / unlocks --------------------------------------------------

func award_gold(amount: int) -> void:
	gold += amount
	save_game()

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

## -- Persistence -------------------------------------------------------------

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({
			"version": SAVE_VERSION,
			"party": party,
			"gold": gold,
			"owned_mods": owned_mods,
			"unlocked_heroes": unlocked_heroes,
			"unlocked_relics": unlocked_relics,
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
	party = data.get("party", {})
	gold = int(data.get("gold", 0))
	owned_mods = data.get("owned_mods", [])
	var saved_heroes: Variant = data.get("unlocked_heroes", null)
	if saved_heroes is Array and not (saved_heroes as Array).is_empty():
		unlocked_heroes = saved_heroes
	unlocked_relics = data.get("unlocked_relics", [])

func reset_save() -> void:
	party = {}
	run_xp = {}
	gold = 0
	owned_mods = []
	unlocked_heroes = HERO_CATALOG.keys()
	unlocked_relics = []
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
