class_name SquadGenerator
extends RefCounted

## Placeholder generation constants — see BALANCE.md.
const SQUAD_COMPOSITION := {
	Player.Position.GK: 2,
	Player.Position.CB: 4,
	Player.Position.FB: 4,
	Player.Position.DM: 2,
	Player.Position.CM: 3,
	Player.Position.CAM: 2,
	Player.Position.WING: 3,
	Player.Position.ST: 3,
}

const STAT_MIN := 15
const STAT_MAX := 55
const SECONDARY_POSITION_CHANCE := 0.25

const ADJACENT_POSITIONS := {
	Player.Position.GK: [],
	Player.Position.CB: [Player.Position.FB],
	Player.Position.FB: [Player.Position.CB, Player.Position.WING],
	Player.Position.DM: [Player.Position.CM],
	Player.Position.CM: [Player.Position.DM, Player.Position.CAM],
	Player.Position.CAM: [Player.Position.CM, Player.Position.WING],
	Player.Position.WING: [Player.Position.CAM, Player.Position.ST, Player.Position.FB],
	Player.Position.ST: [Player.Position.WING],
}

const FIRST_NAMES := [
	"Alex", "Marco", "Jordan", "Kwame", "Diego", "Sam", "Luca", "Theo",
	"Nico", "Rico", "Owen", "Kai", "Milo", "Zane", "Enzo", "Gus",
	"Rafa", "Tomas", "Idris", "Bruno",
]
const LAST_NAMES := [
	"Rivers", "Okoye", "Santos", "Novak", "Reyes", "Walsh", "Ferreira", "Kowalski",
	"Nakamura", "Dubois", "Hassan", "Bianchi", "Larsen", "Costa", "Farrell", "Meyer",
	"Silva", "Petrov", "Adeyemi", "Wolfe",
]

static func generate_squad() -> Array[Player]:
	var squad: Array[Player] = []
	for position: Player.Position in SQUAD_COMPOSITION.keys():
		var count: int = SQUAD_COMPOSITION[position]
		for i in range(count):
			squad.append(_generate_player(position))
	return squad

static func _generate_player(primary_position: Player.Position) -> Player:
	var player := Player.new()
	player.player_name = "%s %s" % [FIRST_NAMES.pick_random(), LAST_NAMES.pick_random()]
	player.positions = [primary_position]
	var candidates: Array = ADJACENT_POSITIONS.get(primary_position, [])
	if candidates.size() > 0 and randf() < SECONDARY_POSITION_CHANCE:
		player.positions.append(candidates.pick_random())
	player.speed = randi_range(STAT_MIN, STAT_MAX)
	player.strength = randi_range(STAT_MIN, STAT_MAX)
	player.kick = randi_range(STAT_MIN, STAT_MAX)
	player.passing = randi_range(STAT_MIN, STAT_MAX)
	player.stamina = randi_range(STAT_MIN, STAT_MAX)
	return player
