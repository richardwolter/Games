class_name ClubData
extends Resource

enum BadgeShape { SHIELD, CIRCLE, DIAMOND, STAR }

@export var club_name: String = ""
@export var primary_color: Color = Color.ROYAL_BLUE
@export var secondary_color: Color = Color.WHITE
@export var badge_shape: BadgeShape = BadgeShape.SHIELD
