## One upgrade track's tunable numbers: what the next level costs, and what it buys.
##
## Generalizes every purchasable track except `skimmer` (whose payoff is a chance curve,
## not this price-and-value shape) into one editable Resource, so a balance pass means
## tweaking a `.tres` in the Inspector rather than editing lake.gd.
##
## Level L's value is `curve_a + curve_b*L + curve_c*L*L`, clamped to `value_cap`, and
## rounded down when `is_integer` is set (net_hold, cargo, fleet are counts of things).
## The cost of buying the level after L (0-indexed, L = levels already owned) is
## `price_base * price_mult ^ L`.
class_name UpgradeTrack
extends Resource

@export var price_base: float = 10.0
@export var price_mult: float = 1.5
@export var level_cap: int = 10

@export var curve_a: float = 0.0
@export var curve_b: float = 1.0
@export var curve_c: float = 0.0
@export var value_cap: float = 999999.0
@export var is_integer: bool = false


## What buying the next level (the one after `level`) costs.
func cost(level: int) -> float:
	return price_base * pow(price_mult, float(mini(level, level_cap)))


## What `level` (held to the cap) is worth.
func value(level: int) -> float:
	var l := float(mini(level, level_cap))
	var v := minf(curve_a + curve_b * l + curve_c * l * l, value_cap)
	return floorf(v) if is_integer else v
