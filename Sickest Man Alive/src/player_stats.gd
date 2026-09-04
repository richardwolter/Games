@tool
class_name PlayerStats
extends Resource

## Everything about the kid in the suit that items are allowed to touch.
## Separate from AttackStats so a modifier targeting PLAYER cannot silently
## land on a weapon channel of the same name.

@export var max_health: int = 6
@export var move_speed: float = 220.0
@export var pickup_radius: float = 48.0

## The suit's whole premise. 1.0 is baseline; smaller is faster and frailer.
## Prototype treats size as a pure stat -- no traversal gating yet.
@export var size_scale: float = 1.0

## Grafted arms, each holding its own syringe that picks its own targets. One
## per stack, so the mutation keeps paying.
@export var extra_arms: int = 0

@export var tint: Color = Color(0.85, 0.95, 1.0)


func duplicate_stats() -> PlayerStats:
	return duplicate(true) as PlayerStats
