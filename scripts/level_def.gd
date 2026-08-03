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

## What the ground is made of. Purely cosmetic — the shader swaps palettes, the
## collision shape is identical whichever is chosen. CONCRETE is the city look, a
## poured channel rather than a natural strait; DIRT is the graded earth of a
## track out of town, between the two.
enum Ground { ROCK, CONCRETE, DIRT }
@export var ground: Ground = Ground.ROCK

## How much lives in the water, as three steps rather than a flag: a channel can
## be too built-up for kelp and fish and still grow moss on its stones, which is
## most of what stops bare ground reading as sterile. Birds are unaffected — they
## belong to the sky, not the strait.
##
##   NONE  nothing at all
##   MOSS  the algae crust along the seabed, and no plants or fish
##   FULL  moss, seabed plants and fish
enum Life { NONE, MOSS, FULL }
@export var life: Life = Life.FULL

## What the shop offers, and how many of each. This is the variety constraint:
## a level that only stocks two girders can't be solved with girders alone.
@export var shop_pool: Array[ObjectDef] = []
## Units available this level, parallel to `shop_pool`. Missing entries are
## treated as unlimited, which is almost never what you want.
@export var shop_stock: PackedInt32Array = PackedInt32Array()

## Multiplier on everything an attempt pays except the per-attempt floor: the
## score payout, the distance record, and the completion bonus.
##
## This is what a level is worth, and it is level design rather than economy
## tuning. Level 1 is a narrow ditch cleared with four planks; paying it the same
## as a 2800-wide strait would hand the player level 2's whole shop before they
## have seen level 2. Keeping the floor unscaled means a broke player on a cheap
## level still climbs out at the usual rate.
@export var reward_scale: float = 1.0

## What every attempt on this level pays regardless of how it went, overriding
## Economy.attempt_floor. -1 keeps the global figure.
##
## It is exempt from reward_scale on purpose. A cheap level scales its rewards
## down precisely so a clear can't fund the next level, but the per-attempt money
## is not a reward for doing well — it is the promise that trying again always
## buys something. Scaling it would take that promise away from exactly the level
## where a player has the least to spend.
@export var attempt_floor: int = -1

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
