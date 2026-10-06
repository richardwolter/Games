## What money comes from: what a netted pigeon pays on the spot, and what a piece pays at
## a merchant. Lives here so a money pass is a `.tres` edit, not a `lake.gd` edit.
class_name EconomyConfig
extends Resource

## What a piece of rubbish pays, by material and weight tier: row `material` (Plastic,
## Wood, Metal, Rubber), column `tier` (0 to 4), flattened as `material * 5 + tier`.
## A kind is its art, its material and its tier, and nothing else (2026-10-01, Richard):
## every tier-2 metal pays the same. Heavier tiers always pay more than any piece of the
## tier below, across all four yards (test_lake guards it).
@export var piece_prices: PackedFloat32Array = PackedFloat32Array([
	4.0, 6.0, 8.0, 10.0, 13.0,
	4.0, 6.0, 8.0, 10.0, 13.0,
	4.0, 6.0, 8.0, 10.0, 13.0,
	4.0, 6.0, 8.0, 10.0, 13.0,
])
@export var bird_bonus: float = 26.0


func price_of(material: int, tier: int) -> float:
	return piece_prices[clampi(material, 0, 3) * 5 + clampi(tier, 0, 4)]
