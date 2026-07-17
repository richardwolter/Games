extends Node

const SAVE_PATH := "user://savegame.tres"

func has_save() -> bool:
	return ResourceLoader.exists(SAVE_PATH)

func save_game() -> void:
	var data := SaveData.new()
	data.club = GameState.club
	data.squad = GameState.squad
	data.formation = GameState.formation
	data.lineup_indices = []
	for player in GameState.lineup:
		data.lineup_indices.append(GameState.squad.find(player) if player != null else -1)
	data.captain_index = GameState.squad.find(GameState.captain) if GameState.captain != null else -1
	ResourceSaver.save(data, SAVE_PATH)

func load_game() -> bool:
	if not has_save():
		return false
	var data: SaveData = ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	GameState.club = data.club
	GameState.squad = data.squad
	GameState.formation = data.formation
	GameState.lineup = []
	for index in data.lineup_indices:
		GameState.lineup.append(GameState.squad[index] if index >= 0 else null)
	GameState.captain = GameState.squad[data.captain_index] if data.captain_index >= 0 else null
	return true
