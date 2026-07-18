extends Node
## GameState autoload — persistent hero progression for the incremental loop.
##
## Holds each hero's banked XP and purchased upgrades, saved to user://save.json
## between runs (and on every purchase). XP is the currency: players spend it
## directly on stat upgrades with rising costs — no automatic level bumps (see
## DECISIONS.md "Progression is player-directed"). Values mirror BALANCE.md.
##
## Dev helper: F12 wipes the save and reloads the battle.

const SAVE_PATH := "user://save.json"

## Upgrade catalog: cost_base rises by cost_growth per owned copy.
## effect_per describes one purchase (interval is multiplicative).
const UPGRADES := {
	"max_hp": {"label": "Max HP", "cost_base": 30, "effect_per": 15.0},
	"damage": {"label": "Damage", "cost_base": 42, "effect_per": 2.0},
	"attack_speed": {"label": "Attack Speed", "cost_base": 36, "effect_per": 0.95},
	"move_speed": {"label": "Move Speed", "cost_base": 24, "effect_per": 6.0},
}
const COST_GROWTH := 1.25
## Skill tree: each stat branch is a linear chain capped at this many nodes.
const BRANCH_CAP := 10
## Ability nodes on the skill tree, bought explicitly with XP once enough
## total branch points are spent (replaces the old automatic LV15/LV20 gates).
## "base" unlocks the hero's signature ability (Stomp/Clone) itself; "passive"
## additionally requires "base" owned; "active" additionally requires
## "passive" owned. Costs are a first-pass guess — flagged for tuning in
## BALANCE.md.
const ABILITY_NODES := {
	"base": {"cost": 75, "requires_points": 5},
	"passive": {"cost": 150, "requires_points": 15},
	"active": {"cost": 250, "requires_points": 20},
}
## Save schema version. v2 = skill tree (fresh start: pre-tree upgrades are
## discarded on load; banked XP is kept).
const SAVE_VERSION := 2
## Fraction of a kill's XP every *other* living hero banks (killer gets 100%),
## so tanks/screeners progress even without landing killing blows.
const KILL_ASSIST_SHARE := 0.5

## Roster catalog: display order, colors. Grows as heroes are added.
const HERO_CATALOG := {
	"THUNDAAR": {"color": Color(0.29, 0.471, 0.753)},
	"ARTEMIS": {"color": Color(0.816, 0.435, 0.627)},
}

## Battlefield priorities a hero can be assigned pre-battle (GDD §11).
## SUPPORT_ALLIES is deferred until support abilities exist (see DECISIONS.md).
const PRIORITIES := {
	"CAPTURE_OBJECTIVES": "Capture Objectives",
	"ATTACK_VILLAIN": "Attack Villain",
}

## heroes[name] = {"xp": int, "upgrades": {stat: int}}
var heroes := {}
## party[name] = {"selected": bool, "priority": String} — set on the prep screen.
## (role is now fixed per hero and set in Hero._configure, not here)
var party := {}
## XP gained per hero in the current run (for the results screen).
var run_xp := {}
## Progression: has the player beaten Stage 1 (unlocks Stage 2)?
var stage_1_won := false
## Transient stage selection for the next battle ("" = scene default).
## Set by the stage-select UI (upcoming) and balance tests; not persisted.
var stage_override := ""

func _ready() -> void:
	load_game()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		reset_save()
		get_tree().reload_current_scene()

## -- Run flow ---------------------------------------------------------------

func start_run() -> void:
	run_xp.clear()

## -- Party / priorities -------------------------------------------------------

func party_of(hero_name: String) -> Dictionary:
	if not party.has(hero_name):
		party[hero_name] = {"selected": true, "priority": "ATTACK_VILLAIN"}
	return party[hero_name]

func set_selected(hero_name: String, selected: bool) -> void:
	party_of(hero_name).selected = selected

func set_priority(hero_name: String, priority: String) -> void:
	party_of(hero_name).priority = priority

func selected_heroes() -> Array:
	var out := []
	for hero_name in HERO_CATALOG:
		if party_of(hero_name).selected:
			out.append(hero_name)
	return out

## Kill XP: killer banks the full value; every other living hero banks the
## assist share (rounded up), so XP flows to the whole party (BALANCE.md).
func award_kill_xp(killer: Node, amount: int) -> void:
	add_xp(killer.hero_name, amount)
	var assist := int(ceil(amount * KILL_ASSIST_SHARE))
	for h in killer.get_tree().get_nodes_in_group("heroes"):
		if h != killer and h is Hero:
			add_xp(h.hero_name, assist)

func add_xp(hero_name: String, amount: int) -> void:
	if amount <= 0:
		return
	var h := _hero(hero_name)
	h.xp += amount
	run_xp[hero_name] = int(run_xp.get(hero_name, 0)) + amount
	# Feed the roguelite in-run level track (Milestone 1). This is the single
	# chokepoint for both kill and objective XP, so RunState sees every gain.
	RunState.record_xp(hero_name, amount)

## -- Upgrades ---------------------------------------------------------------

func owned(hero_name: String, stat: String) -> int:
	return int(_hero(hero_name).upgrades.get(stat, 0))

func cost(hero_name: String, stat: String) -> int:
	var base := int(UPGRADES[stat].cost_base)
	return int(ceil(base * pow(COST_GROWTH, owned(hero_name, stat))))

func xp_of(hero_name: String) -> int:
	return int(_hero(hero_name).xp)

func buy(hero_name: String, stat: String) -> bool:
	var h := _hero(hero_name)
	var c := cost(hero_name, stat)
	if h.xp < c or owned(hero_name, stat) >= BRANCH_CAP:
		return false
	h.xp -= c
	h.upgrades[stat] = owned(hero_name, stat) + 1
	save_game()
	return true

## -- Skill tree ability nodes -------------------------------------------------

func ability_owned(hero_name: String, id: String) -> bool:
	return id in (_hero(hero_name).abilities as Array)

func ability_cost(id: String) -> int:
	return int(ABILITY_NODES[id].cost)

## Prerequisites met (points milestone + chain order), ignoring XP.
func ability_unlocked(hero_name: String, id: String) -> bool:
	if level_of(hero_name) < int(ABILITY_NODES[id].requires_points):
		return false
	if id == "passive" and not ability_owned(hero_name, "base"):
		return false
	if id == "active" and not ability_owned(hero_name, "passive"):
		return false
	return true

func ability_available(hero_name: String, id: String) -> bool:
	return not ability_owned(hero_name, id) \
			and ability_unlocked(hero_name, id) \
			and xp_of(hero_name) >= ability_cost(id)

func buy_ability(hero_name: String, id: String) -> bool:
	if not ability_available(hero_name, id):
		return false
	var h := _hero(hero_name)
	h.xp -= ability_cost(id)
	(h.abilities as Array).append(id)
	save_game()
	return true

## Total purchases — the hero's effective "level" for display.
func level_of(hero_name: String) -> int:
	var total := 0
	for stat in _hero(hero_name).upgrades:
		total += int(_hero(hero_name).upgrades[stat])
	return total

## -- Stat application (used by Hero on spawn) --------------------------------

func bonus_max_hp(hero_name: String) -> float:
	return owned(hero_name, "max_hp") * float(UPGRADES.max_hp.effect_per)

func bonus_damage(hero_name: String) -> float:
	return owned(hero_name, "damage") * float(UPGRADES.damage.effect_per)

func attack_interval_mult(hero_name: String) -> float:
	return pow(float(UPGRADES.attack_speed.effect_per), owned(hero_name, "attack_speed"))

func bonus_move_speed(hero_name: String) -> float:
	return owned(hero_name, "move_speed") * float(UPGRADES.move_speed.effect_per)

## -- Persistence -------------------------------------------------------------

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"version": SAVE_VERSION, "heroes": heroes, "party": party, "stage_1_won": stage_1_won}))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		heroes = data.get("heroes", {})
		party = data.get("party", {})
		stage_1_won = data.get("stage_1_won", false)
		# Pre-skill-tree save (v1): fresh start — keep banked XP, drop the old
		# flat upgrade purchases so everything is re-bought on the tree.
		if int(data.get("version", 1)) < SAVE_VERSION:
			for hero_name in heroes:
				heroes[hero_name].upgrades = {}
				heroes[hero_name].abilities = []

func reset_save() -> void:
	heroes = {}
	party = {}
	run_xp = {}
	stage_1_won = false
	stage_override = ""
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func _hero(hero_name: String) -> Dictionary:
	if not heroes.has(hero_name):
		heroes[hero_name] = {"xp": 0, "upgrades": {}, "abilities": []}
	elif not heroes[hero_name].has("abilities"):
		# Entries written directly (balance_sweep) or from older data.
		heroes[hero_name].abilities = []
	return heroes[hero_name]
