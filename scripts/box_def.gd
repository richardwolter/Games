## A booster pack tier. Costs money, hands back `piece_count` random pieces from
## `pool`.
##
## The deal the player is weighing: the shop sells exactly the piece you want at
## its listed price, while a booster gives you more value per dollar but picks for
## you. So a tier should always be priced *below* the average pool piece times
## `piece_count` — otherwise there's no reason to ever gamble.
##
## The class is still BoxDef and the files are still *_box.tres: the rename is a
## wording change, and renaming the resources would break every save that stores a
## def by path.
class_name BoxDef
extends Resource

@export var display_name: String = "Bronze Booster"
@export var price: int = 30
## How many pieces come out. Every box gives at least one.
@export var piece_count: int = 3

@export var pool: Array[ObjectDef] = []
## Relative roll weights, parallel to `pool`. Missing entries count as 1.0.
@export var weights: PackedFloat32Array = PackedFloat32Array()

@export var color: Color = Color("c08040")

## The pack itself, shown in the shop. Left empty the row is just its tier
## colour, which is what every tier looked like before the packs were drawn — so
## a new tier still works the day it is added and gets its picture later.
##
## `color` stays load-bearing either way: it paints the row the pack sits on and
## tints the opening flourish, so the two want to agree.
@export var art: Texture2D = null


## Average shop value of one roll, used to sanity-check pricing and to show the
## player what the tier is worth without spoiling the individual odds.
func expected_value() -> int:
	if pool.is_empty():
		return 0
	var total_weight := 0.0
	var total_value := 0.0
	for i in pool.size():
		var w := _weight_at(i)
		total_weight += w
		total_value += w * float(pool[i].price)
	if total_weight <= 0.0:
		return 0
	return roundi(total_value / total_weight * float(piece_count))


## Roll the contents. Returns one ObjectDef per piece, duplicates allowed —
## opening a gold box and getting three of the same girder is a legitimate,
## and quite good, outcome.
func roll() -> Array[ObjectDef]:
	var out: Array[ObjectDef] = []
	if pool.is_empty():
		return out
	for i in maxi(piece_count, 1):
		out.append(_roll_one())
	return out


func _roll_one() -> ObjectDef:
	var total := 0.0
	for i in pool.size():
		total += _weight_at(i)

	var ticket := randf() * total
	for i in pool.size():
		ticket -= _weight_at(i)
		if ticket <= 0.0:
			return pool[i]
	return pool[pool.size() - 1]


func _weight_at(index: int) -> float:
	return weights[index] if index < weights.size() else 1.0
