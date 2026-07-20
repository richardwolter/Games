class_name Achievements
extends RefCounted
## Cumulative career achievements (V2 grind progression) — mirrors the
## AbilityMods/Boons static-catalog pattern. Each entry unlocks one hero once a
## lifetime GameState.career counter crosses its threshold. Counters accumulate
## across every V2 run, win or lose (see GameState.record_career).
##
## First-pass thresholds — tune against real swarm throughput (BALANCE.md).

const CATALOG := {
	"swarmbreaker": {
		"name": "Swarmbreaker", "desc": "Kill 150 minions",
		"stat": "minions_killed", "threshold": 150, "unlocks_hero": "ARTEMIS",
	},
	"gatecrasher": {
		"name": "Gatecrasher", "desc": "Destroy 10 spawn gates",
		"stat": "gates_destroyed", "threshold": 10, "unlocks_hero": "WARDEN",
	},
	"giant_slayer": {
		"name": "Giant Slayer", "desc": "Deal 50% of a villain's HP in one run",
		"stat": "best_villain_damage_pct", "threshold": 0.5, "unlocks_hero": "BEACON",
	},
}

## All achievement ids.
static func ids() -> Array:
	return CATALOG.keys()

## Definition dict for an achievement id, or {} if unknown.
static func def(id: String) -> Dictionary:
	return CATALOG.get(id, {})

## The achievement id that unlocks `hero_name`, or "" if none gates it.
static func for_hero(hero_name: String) -> String:
	for id in CATALOG:
		if CATALOG[id].get("unlocks_hero", "") == hero_name:
			return id
	return ""
