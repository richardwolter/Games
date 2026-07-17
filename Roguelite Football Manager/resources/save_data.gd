class_name SaveData
extends Resource

## Snapshot of GameState for a single save slot. Lineup/captain are stored as
## indices into `squad` rather than direct references, since Resource
## serialization does not guarantee reference identity is preserved.
@export var club: ClubData = null
@export var squad: Array[Player] = []
@export var formation: Formation = null
@export var lineup_indices: Array[int] = []
@export var captain_index: int = -1
