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

## Set true by the balance sweep so level-ups never emit / never pause for a UI
## pick — keeps automated runs comparable to pre-M1 balance data and stops the
## pause from deadlocking the headless harness. The shipped game leaves it false.
var headless := false

## hero_name -> {"level": int, "xp": int, "xp_to_next": int}
var levels := {}
## hero_name -> Array[String] of picked boon ids (drives live effects + summary).
var boons := {}

## Clear all per-run state. Called by BattleManager on battle load. Does NOT
## touch `headless` (that's a harness mode flag, set once by the sweep).
func start_run() -> void:
	levels.clear()
	boons.clear()

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
