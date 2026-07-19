extends Node
## RunState autoload — transient per-run roguelite state (Milestone 1).
##
## Holds each hero's in-run LEVEL + XP-toward-next and the run boons they've
## picked. Everything here resets on start_run() and is NEVER saved to disk —
## that is the whole point of the hybrid-roguelite direction: builds are
## per-run and reset, while persistence (unlocked heroes/relics) lives in
## GameState / a future MetaState. See the design report + IMPLEMENTATION_PLAN.md.
##
## XP is fed in from GameState.add_xp (the single chokepoint for kill + objective
## XP). When a hero crosses a level threshold, hero_leveled fires; BattleManager
## listens, pauses the battle, and shows the 1-of-3 boon pick (LevelUpScreen).

signal hero_leveled(hero_name: String)

## Rising XP curve per in-run level. First-pass — tune in BALANCE.md.
const XP_BASE := 40.0
const XP_GROWTH := 1.35
## How many boons are offered on each level-up.
const OFFER_SIZE := 3

## Milestone 3: max heroes fielded per run (DECISIONS.md "party cap set to
## 3-of-4" — forces a real "who do I leave out" choice at the roster's
## current size and stays meaningful as more heroes unlock later).
const PARTY_CAP := 3

## Set true by the balance sweep so level-ups never emit / never pause for a UI
## pick — keeps automated runs comparable to pre-M1 balance data and stops the
## pause from deadlocking the headless harness. The shipped game leaves it false.
var headless := false

## Which level of the run we're on (1-based). A run is a chain of levels; a win
## advances this, a loss resets the whole run to level 1 (gameplay-loop rework).
## StageField reads it to pick which authored LevelLayout to load.
var current_level := 1
## hero_name -> {"level": int, "xp": int, "xp_to_next": int}
var levels := {}
## hero_name -> Array[String] of picked boon ids (drives live effects + summary).
var boons := {}
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
	boons.clear()
	hp_carry.clear()
	dead.clear()

## -- Run chaining: HP carryover + permadeath ---------------------------------

## Party heroes still alive to field this level (drafted minus the fallen).
func living_party() -> Array:
	return party.filter(func(h: String) -> bool: return h not in dead)

func is_dead(hero_name: String) -> bool:
	return hero_name in dead

func mark_dead(hero_name: String) -> void:
	if hero_name not in dead:
		dead.append(hero_name)
	hp_carry.erase(hero_name)

## Store a survivor's remaining HP to carry into the next level.
func carry_hp(hero_name: String, hp: float) -> void:
	hp_carry[hero_name] = hp

## Carried HP for a hero, or -1.0 if none (fresh spawn at full HP).
func carried_hp(hero_name: String) -> float:
	return float(hp_carry.get(hero_name, -1.0))

func _track(hero_name: String) -> Dictionary:
	if not levels.has(hero_name):
		levels[hero_name] = {"level": 0, "xp": 0, "xp_to_next": xp_needed(0)}
	return levels[hero_name]

## XP required to go from `level` to `level + 1`.
func xp_needed(level: int) -> int:
	return int(round(XP_BASE * pow(XP_GROWTH, level)))

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

func add_boon(hero_name: String, id: String) -> void:
	if not boons.has(hero_name):
		boons[hero_name] = []
	boons[hero_name].append(id)

## Three distinct boon ids to offer on a level-up.
func roll_offer() -> Array:
	var pool := Boons.ids()
	pool.shuffle()
	return pool.slice(0, mini(OFFER_SIZE, pool.size()))

## -- Milestone 3: hero draft ---------------------------------------------------

## Re-rolls draft_offer from GameState.unlocked_heroes (called on every prep
## screen load, per IMPLEMENTATION_PLAN.md M3). Offer size is PARTY_CAP + 1 so
## there is always at least one real "who do I leave out" decision once more
## than PARTY_CAP heroes are unlocked; today's 4-hero roster offers all four.
## Carries over any previous picks that are still in the new offer, then fills
## remaining slots (up to PARTY_CAP) from the new offer so the start button
## isn't left disabled after a re-roll.
func roll_draft_offer() -> void:
	var pool: Array = GameState.unlocked_heroes.duplicate()
	pool.shuffle()
	draft_offer = pool.slice(0, mini(PARTY_CAP + 1, pool.size()))
	party = party.filter(func(h: String) -> bool: return h in draft_offer)
	for hero_name in draft_offer:
		if party.size() >= PARTY_CAP:
			break
		if hero_name not in party:
			party.append(hero_name)

func is_offered(hero_name: String) -> bool:
	return hero_name in draft_offer

func is_selected(hero_name: String) -> bool:
	return hero_name in party

## Select/deselect a hero for this run's party, capped at PARTY_CAP.
func toggle_selected(hero_name: String, on: bool) -> void:
	if on:
		if hero_name not in party and party.size() < PARTY_CAP:
			party.append(hero_name)
	else:
		party.erase(hero_name)

func selected_heroes() -> Array:
	return party.duplicate()
