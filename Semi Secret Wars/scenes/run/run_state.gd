extends Node
## RunState autoload — transient per-run roguelite state (Milestone 1).
##
## Holds each hero's in-run LEVEL + XP-toward-next and the run boons picked.
## Everything here resets on start_run() and is NEVER saved to disk — that is
## the whole point of the hybrid-roguelite direction: builds are per-run and
## reset, while persistence (unlocked heroes/relics) lives in GameState / a
## future MetaState. See the design report + IMPLEMENTATION_PLAN.md.
##
## XP is fed in from GameState.add_xp (the single chokepoint for kill + objective
## XP) and still drives per-hero LEVEL/xp_to_next (shown on the battle HUD) and
## the persistent banked_xp currency (stat upgrades) — but XP no longer grants
## boons directly (Designer, 2026-07-21). Boons are offered at the START of each
## stage level instead (see BattleManager._ready).
##
## As of 2026-07-25 the only run-scoped boon pool is `duo_boons` — one pick per
## Duo, targeting that Duo's Ultimate. The per-hero pool that used to sit
## alongside it was removed with its catalog; see duo_ultimate_boons.gd for why.
## `hero_leveled` still fires on every XP level-up — nothing currently listens
## to it, kept for future HUD feedback (e.g. a "ding" effect) without needing
## to touch RunState again.

signal hero_leveled(hero_name: String)

## Flat additive XP curve per in-run level (Designer, 2026-07-21: no
## percentages/exponential growth on upgrades — a player should be able to
## predict "the next level costs 10 more than this one" without doing math).
## Replaces the old exponential curve (XP_BASE 40 * XP_GROWTH 1.35^level *
## XP_GRIND_MULT 1.8, which reached ~9,200 XP by LV10 and read as opaque).
const XP_STEP_BASE := 30.0
const XP_STEP_PER_LEVEL := 10.0
## Levels below this cost less XP, so a hero's first few HUD level-ups land
## faster (Designer, 2026-07-18: originally "boons can be more frequent on
## first heroes' levels" — boons no longer come from XP level-ups as of
## 2026-07-21, see the class doc, but the early-levels-come-faster feel is
## still worth keeping for the HUD's own pacing). Growth resumes its normal
## trajectory from EARLY_LEVEL_CAP onward — this only front-loads the curve.
const EARLY_LEVEL_CAP := 3
const EARLY_LEVEL_DISCOUNT := 0.5

## Set true by the balance sweep so level-ups never emit / never pause for a UI
## pick — keeps automated runs comparable to pre-M1 balance data and stops the
## pause from deadlocking the headless harness. The shipped game leaves it false.
var headless := false

## Which level of the run we're on (1-based). A run is a chain of levels; a win
## advances this, a loss resets the whole run to level 1 (gameplay-loop rework).
## LaneField reads it to pick which authored LevelLayout to load.
var current_level := 1
## hero_name -> {"level": int, "xp": int, "xp_to_next": int}
var levels := {}
## Duo Ultimate boons (2026-07-22): pair_id (DuoUltimates.id_for_heroes) ->
## Array[String] of picked DuoUltimateBoons ids. This is the ONLY boon pool
## now — the per-hero `boons` Dictionary was removed 2026-07-25 with the
## hero-boon catalog it fed (see duo_ultimate_boons.gd class doc). Accumulates
## across levels (never reset except by start_run); read at cast time via
## duo_boon_total, never mutated elsewhere.
var duo_boons := {}
## hero_name -> float HP a survivor carries INTO the next level (raw carryover,
## Designer decision — no heal/revive yet). Set at a level's win, read when the
## next level spawns the party. Cleared on start_run().
var hp_carry := {}
## Names of party heroes who perished earlier this run. The dead stay dead — a
## name here is skipped when the next level spawns the party. Cleared on start_run().
var dead: Array = []

## Milestone 3: the roster offered on the prep screen (subset of
## GameState.unlocked_heroes) and the party drafted from it. Both live here,
## not in GameState, so the pick is per-run and never touches the save file.
var draft_offer: Array = []
var party: Array = []

## Clear all per-run state — a FRESH run at level 1. Called from the prep menu
## when a new run is launched (NOT between chained levels, which must preserve
## levels/boons/hp/dead). Does NOT touch `headless` (a harness flag) or `party`
## (the draft pick, cleared/re-rolled by the prep screen).
func start_run() -> void:
	current_level = 1
	levels.clear()
	duo_boons.clear()
	hp_carry.clear()
	hp_carry_frac.clear()
	dead.clear()
	# Starting fresh discards any resumable run — see the persistence block at
	# the bottom of this file.
	clear_run()

## -- Run chaining: HP carryover + permadeath ---------------------------------

## Party heroes still alive to field this level (drafted minus the fallen).
func living_party() -> Array:
	return party.filter(func(h: String) -> bool: return h not in dead)

## True once an ENTIRE authored Duo (GameState.duo_pairings) has been wiped
## this run — both of its members are in `dead`. From the next level on, the
## battlefield runs as ONE lane for the surviving Duo (Designer, 2026-07-26):
## two heroes cannot hold two fronts, and the split was only ever there to
## spread a four-hero party. LaneField reads this at load and forces
## lanes_merged() for the whole level; see LaneField.single_lane.
##
## A Duo whose members were never drafted doesn't count — nobody died, so
## neither name is in `dead`. Benched heroes likewise stay out of it.
func duo_wiped() -> bool:
	for duo in GameState.duo_pairings:
		if not (duo is Array) or (duo as Array).size() != 2:
			continue
		if duo[0] in dead and duo[1] in dead:
			return true
	return false

func is_dead(hero_name: String) -> bool:
	return hero_name in dead

func mark_dead(hero_name: String) -> void:
	if hero_name not in dead:
		dead.append(hero_name)
	hp_carry.erase(hero_name)

## Store a survivor's remaining HP to carry into the next level. `max_hp` is
## kept alongside purely so the pre-deploy hero card can draw the right bar
## fill before any Hero node exists to ask (see carried_fraction) — the raw
## value stays the source of truth for the actual spawn.
func carry_hp(hero_name: String, hp: float, max_hp: float = 0.0) -> void:
	hp_carry[hero_name] = hp
	if max_hp > 0.0:
		hp_carry_frac[hero_name] = clampf(hp / max_hp, 0.0, 1.0)

## hero_name -> 0..1 HP fraction carried in, for display before spawn.
var hp_carry_frac := {}

## Carried HP as a fraction of max, or 1.0 when this hero carries nothing in
## (a fresh level-1 spawn arrives at full HP).
func carried_fraction(hero_name: String) -> float:
	return float(hp_carry_frac.get(hero_name, 1.0))

## Carried HP for a hero, or -1.0 if none (fresh spawn at full HP).
func carried_hp(hero_name: String) -> float:
	return float(hp_carry.get(hero_name, -1.0))

func _track(hero_name: String) -> Dictionary:
	if not levels.has(hero_name):
		levels[hero_name] = {"level": 0, "xp": 0, "xp_to_next": xp_needed(0)}
	return levels[hero_name]

## XP required to go from `level` to `level + 1`.
func xp_needed(level: int) -> int:
	var needed := XP_STEP_BASE + float(level) * XP_STEP_PER_LEVEL
	if level < EARLY_LEVEL_CAP:
		needed *= EARLY_LEVEL_DISCOUNT
	return int(round(needed))

## Feed run XP for a hero; emits hero_leveled once per level crossed (unless
## headless). Multiple levels from a single big XP grant each fire separately.
func record_xp(hero_name: String, amount: int) -> void:
	if amount <= 0:
		return
	var t := _track(hero_name)
	t.xp += amount
	while t.xp >= t.xp_to_next:
		t.xp -= t.xp_to_next
		t.level += 1
		t.xp_to_next = xp_needed(t.level)
		if not headless:
			hero_leveled.emit(hero_name)

func level_of(hero_name: String) -> int:
	return int(_track(hero_name).level)

## Progress toward the next level, 0..1 (for a future HUD bar).
func xp_fraction(hero_name: String) -> float:
	var t := _track(hero_name)
	return clampf(float(t.xp) / float(t.xp_to_next), 0.0, 1.0)

func add_duo_boon(pair_id: String, id: String) -> void:
	if not duo_boons.has(pair_id):
		duo_boons[pair_id] = []
	duo_boons[pair_id].append(id)

## Duo Ultimate boon ids to offer this Duo at the start of a level: all three
## of its ultimate-boost options, shuffled — a straight pick-1-of-3.
func roll_duo_offer(pair_id: String) -> Array:
	var offer := DuoUltimateBoons.for_duo(pair_id)
	offer.shuffle()
	return offer

## Sum of `value` across every owned DuoUltimateBoons entry for `pair_id`
## whose `kind` matches — e.g. duo_boon_total("ARTEMIS|BEACON", "chain_count")
## adds up every picked boon that targets chain_count (normally 0 or 1 picks,
## but stacks correctly if a boon were ever picked twice). Read by
## Hero.cast_duo_ultimate's effect methods on top of DuoUltimates.def's base
## params value — this function never touches the base catalog.
func duo_boon_total(pair_id: String, kind: String) -> float:
	var total := 0.0
	for id in duo_boons.get(pair_id, []):
		var d := DuoUltimateBoons.def(id)
		if d.get("kind", "") == kind:
			total += float(d.get("value", 0.0))
	return total

## -- Milestone 3: hero draft ---------------------------------------------------

## Re-rolls draft_offer from GameState.unlocked_heroes (called on every prep
## screen load, per IMPLEMENTATION_PLAN.md M3).
##
## Uncapped (Designer, 2026-07-19): the party cap is gone — every unlocked
## hero is offered and defaults to selected, so a player fields their whole
## roster unless they deliberately benches someone via toggle_selected. This
## reverses the 2026-07-18 "3-of-4" cap decision (DECISIONS.md); see that
## entry for the now-superseded "who do I leave out" reasoning.
func roll_draft_offer() -> void:
	draft_offer = GameState.unlocked_heroes.duplicate()
	party = party.filter(func(h: String) -> bool: return h in draft_offer)
	for hero_name in draft_offer:
		if hero_name not in party:
			party.append(hero_name)

func is_offered(hero_name: String) -> bool:
	return hero_name in draft_offer

func is_selected(hero_name: String) -> bool:
	return hero_name in party

## Select/deselect a hero for this run's party. Uncapped — see roll_draft_offer().
func toggle_selected(hero_name: String, on: bool) -> void:
	if on:
		if hero_name not in party:
			party.append(hero_name)
	else:
		party.erase(hero_name)

func selected_heroes() -> Array:
	return party.duplicate()

## -- Run persistence (Designer, 2026-07-26) -----------------------------------
## A run in flight now survives closing the game: quit after clearing a level
## and CONTINUE on the title screen drops you back into the level you had
## reached, with your Duo boons, XP, carried HP and casualties intact.
##
## This is a deliberate narrowing of the "never saved to disk" rule in the class
## doc above, NOT an abandonment of it. The rule exists so a build can't be
## re-rolled or carried between runs; it was never meant to punish someone for
## closing the window. So: the run file is written only at a level CLEAR, and
## deleted the moment the run ends by any route — completed, wiped, or
## abandoned. There is no way to reload it to undo a defeat, because a defeat
## erases it before the results screen is even readable.
##
## Kept in its own file rather than in save.json: GameState.reset_save() wipes
## that one, and a meta-progression reset is a different decision from
## discarding an in-flight run.
const RUN_SAVE_PATH := "user://run.json"
const RUN_SAVE_VERSION := 1

## True when the state currently in memory came from disk — i.e. there is a run
## to resume. Set by _load_run at boot, cleared by clear_run/start_run.
var resumable := false

func _ready() -> void:
	_load_run()

## Writes the run as it stands. Called at a level clear (BattleManager._end),
## which is the only checkpoint — mid-battle progress is deliberately not
## captured, so quitting mid-fight resumes at the start of that level rather
## than restoring a half-finished battle.
func save_run() -> void:
	var f := FileAccess.open(RUN_SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"version": RUN_SAVE_VERSION,
		"current_level": current_level,
		"levels": levels,
		"duo_boons": duo_boons,
		"hp_carry": hp_carry,
		"hp_carry_frac": hp_carry_frac,
		"dead": dead,
		"party": party,
		"draft_offer": draft_offer,
	}))
	resumable = true

## Drops the saved run. Called on every run-ending outcome — see class doc.
func clear_run() -> void:
	resumable = false
	if FileAccess.file_exists(RUN_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUN_SAVE_PATH))

func _load_run() -> void:
	if not FileAccess.file_exists(RUN_SAVE_PATH):
		return
	var f := FileAccess.open(RUN_SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if not (data is Dictionary) or int(data.get("version", 0)) != RUN_SAVE_VERSION:
		# Unreadable or from an older layout: drop it rather than resume half a
		# run. Losing one interrupted run beats restoring a broken one.
		clear_run()
		return
	current_level = int(data.get("current_level", 1))
	levels = data.get("levels", {})
	duo_boons = data.get("duo_boons", {})
	hp_carry = data.get("hp_carry", {})
	hp_carry_frac = data.get("hp_carry_frac", {})
	dead = data.get("dead", [])
	party = data.get("party", [])
	draft_offer = data.get("draft_offer", [])
	# A run with nobody in it can't be resumed into a battle — treat it as none.
	resumable = not party.is_empty()
