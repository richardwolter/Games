@tool
class_name Item
extends Resource

## An item is data, never behaviour. It owns a name, a colour for its pedestal,
## and a list of intents. If an item ever needs a script to express itself,
## the missing piece is a channel on AttackStats/PlayerStats, not a subclass.

@export var display_name: String = "Unnamed"
@export_multiline var description: String = ""
@export var pedestal_color: Color = Color.WHITE
@export var modifiers: Array[StatModifier] = []
