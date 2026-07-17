class_name OpponentLineupBuilder
extends RefCounted

## Placeholder flavor names for the auto-generated opponent — not a balance value.
const OPPONENT_NAMES := [
	"Ironside FC", "Dockside Rovers", "Granite City", "Fox Hollow United",
	"Emberfield", "Northgate Athletic", "Saltmarsh Town", "Copperhill FC",
]

## Generates a random opponent squad and greedily fills a random formation's
## lineup by picking, for each slot, the best remaining PositionCompatibility fit.
static func build() -> Dictionary:
	var squad: Array[Player] = SquadGenerator.generate_squad()
	var formation: Formation = FormationLibrary.get_all().pick_random()
	var lineup: Array = []
	lineup.resize(formation.slots.size())
	var available: Array[Player] = squad.duplicate()
	for i in formation.slots.size():
		var slot: Formation.SlotCategory = formation.slots[i]
		var best_player: Player = null
		var best_multiplier: float = -1.0
		for player in available:
			var multiplier: float = PositionCompatibility.get_best_multiplier(player, slot)
			if multiplier > best_multiplier:
				best_multiplier = multiplier
				best_player = player
		if best_player != null:
			lineup[i] = best_player
			available.erase(best_player)
	return {
		"name": OPPONENT_NAMES.pick_random(),
		"squad": squad,
		"formation": formation,
		"lineup": lineup,
	}
