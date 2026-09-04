class_name Hurtbox
extends Area2D

## Attacks look for Area2D nodes in a group and call take_damage on them.
## Bodies want to be CharacterBody2D for movement, so this forwards.
## Keeping the forward in one place means an attack never needs to know
## whether it hit a player, an enemy, or a destructible.

@export var owner_path: NodePath = ^".."

var _body: Node


func _ready() -> void:
	_body = get_node_or_null(owner_path)


## Whether attacks should pass straight through this frame -- the dash's
## invulnerability, and anything later that wants the same thing.
##
## Asked by the ATTACK before it commits, so an intangible target does not eat a
## shot's pierce budget or delete it on contact. It is a separate question from
## take_damage refusing: that one has already spent the projectile.
func is_intangible() -> bool:
	return _body != null and _body.has_method(&"is_dashing") and _body.is_dashing()


func take_damage(amount: float, knockback: Vector2, statuses: Dictionary, is_crit: bool) -> void:
	if _body != null and _body.has_method(&"take_damage"):
		_body.take_damage(amount, knockback, statuses, is_crit)
