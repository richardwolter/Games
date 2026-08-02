## One level: how wide the strait is, and what the shop will sell you for it.
##
## Geometry is a handful of numbers rather than hand-placed nodes, so World can
## rebuild the strait at any width and a new level is just a new .tres.
class_name LevelDef
extends Resource

@export var display_name: String = "Level"

## The water spans -half_width .. +half_width. Everything else — shores, walls,
## camera limits, car start, goal line — is derived from this.
@export var half_width: float = 1600.0
## Deepest point of the seabed, below the water surface. Deeper water means a
## sunk piece is gone for good rather than becoming a foundation.
@export var max_depth: float = 600.0

## Scenery behind the strait. Left empty the level keeps the default sunset, so
## adding a level costs nothing until it wants its own view.
##
## The horizon fraction has to come with the picture: every backdrop puts its
## waterline somewhere different, and it is the one number Backdrop needs to weld
## the painting to the water rather than float it.
@export var backdrop: Texture2D = null
@export_range(0.0, 1.0) var backdrop_horizon: float = 0.55

## What the shop offers, and how many of each. This is the variety constraint:
## a level that only stocks two girders can't be solved with girders alone.
@export var shop_pool: Array[ObjectDef] = []
## Units available this level, parallel to `shop_pool`. Missing entries are
## treated as unlimited, which is almost never what you want.
@export var shop_stock: PackedInt32Array = PackedInt32Array()

## Box tiers on sale. Boxes have no stock limit — they're the pressure valve
## once the shop's good pieces are sold out.
@export var boxes: Array[BoxDef] = []


func stock_for(index: int) -> int:
	return shop_stock[index] if index < shop_stock.size() else 99


## Left shore surface, where the car starts its run-up. Y is the surface itself —
## the crossing manager lifts the car by its own ride height.
func car_start() -> Vector2:
	return Vector2(-half_width - 1000.0, 300.0)


## Chassis past here has landed on the far shore.
func goal_x() -> float:
	return half_width + 80.0
