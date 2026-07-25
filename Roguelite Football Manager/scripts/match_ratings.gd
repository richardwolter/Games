class_name MatchRatings
extends RefCounted

## Milestone 20: single home for every derived match rating. Each rating is a
## formula over the existing 5 Player stats (Speed/Strength/Kick/Passing/
## Stamina) — position-adjusted via PositionCompatibility and scaled by the
## player's in-match Condition. No new stored attributes: "derive from the 5
## stats" (Designer decision, M20). These blends previously lived as scattered
## constants inside MatchDecisionEngine (DEFENSE_*/RETENTION_* weights); they
## are centralized here so every contest reads the same named rating.
## See BALANCE.md "Derived Match Ratings".

## Tackle/defensive-duel blend (also used for pass interception).
const DEFENSE_STRENGTH_WEIGHT := 0.6
const DEFENSE_SPEED_WEIGHT := 0.4
## Ball-retention blend for a carrier resisting a tackle.
const RETENTION_STRENGTH_WEIGHT := 0.5
const RETENTION_SPEED_WEIGHT := 0.3
const RETENTION_PASSING_WEIGHT := 0.2

const CONDITION_FLOOR_MULTIPLIER := LiveMatchState.CONDITION_FLOOR_MULTIPLIER
const STARTING_CONDITION := LiveMatchState.STARTING_CONDITION

## In-match fatigue → effective-stat multiplier: full condition = 1.0, zero
## condition floors at CONDITION_FLOOR_MULTIPLIER (never fully useless).
static func condition_multiplier(condition: float) -> float:
	return CONDITION_FLOOR_MULTIPLIER + (1.0 - CONDITION_FLOOR_MULTIPLIER) * (condition / STARTING_CONDITION)

## Position-adjusted single stat (NOT condition-scaled) — thin wrapper over
## PositionCompatibility so callers don't reach into the multiplier table.
static func effective_stat(player: Player, slot: Formation.SlotCategory, stat_name: String) -> float:
	return PositionCompatibility.get_effective_stats(player, slot).get(stat_name, 0.0)

## Condition-scaled, position-adjusted single stat.
static func stat(player: Player, slot: Formation.SlotCategory, stat_name: String, condition: float) -> float:
	return effective_stat(player, slot, stat_name) * condition_multiplier(condition)

## --- Named composite ratings (all condition-scaled, position-adjusted) ---

## Defensive/tackle strength: winning the ball off a carrier or in a duel.
static func tackling(player: Player, slot: Formation.SlotCategory, condition: float) -> float:
	var s: Dictionary = PositionCompatibility.get_effective_stats(player, slot)
	return (s["strength"] * DEFENSE_STRENGTH_WEIGHT + s["speed"] * DEFENSE_SPEED_WEIGHT) * condition_multiplier(condition)

## Ball retention: a carrier's ability to keep the ball under a challenge.
static func retention(player: Player, slot: Formation.SlotCategory, condition: float) -> float:
	var s: Dictionary = PositionCompatibility.get_effective_stats(player, slot)
	return (s["strength"] * RETENTION_STRENGTH_WEIGHT + s["speed"] * RETENTION_SPEED_WEIGHT
		+ s["passing"] * RETENTION_PASSING_WEIGHT) * condition_multiplier(condition)

## Finishing quality (shooting) — Kick.
static func finishing(player: Player, slot: Formation.SlotCategory, condition: float) -> float:
	return stat(player, slot, "kick", condition)

## Passing accuracy — Pass.
static func passing_skill(player: Player, slot: Formation.SlotCategory, condition: float) -> float:
	return stat(player, slot, "passing", condition)

## Decision quality / composure — derived from Pass (used to scale decision
## noise and penalty conversion). Kept separate from passing_skill so later
## milestones can reweight it without touching pass accuracy.
static func composure(player: Player, slot: Formation.SlotCategory, condition: float) -> float:
	return stat(player, slot, "passing", condition)

## Goalkeeper shot-stopping — Strength (the keeper stat the shot contest uses).
static func keeper_rating(player: Player, slot: Formation.SlotCategory, condition: float) -> float:
	return stat(player, slot, "strength", condition)
