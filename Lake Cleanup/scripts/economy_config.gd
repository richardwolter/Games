## What money comes from: what a netted pigeon pays on the spot, and what a piece pays at
## a merchant — a flat fee for anything landed, plus a cut of what its filth was worth.
##
## The flat/filth split is deliberate (see lake.gd's `_on_sold`): the flat half is why
## early, cheap pieces pay anything at all, and the filth half is why a late hold of heavy
## pieces outearns an early hold of light ones. Lives here so a money pass is a `.tres`
## edit, not a `lake.gd` edit.
class_name EconomyConfig
extends Resource

@export var piece_base_pay: float = 4.0
@export var piece_filth_pay: float = 9.0
@export var bird_bonus: float = 26.0
## How much more each weight tier pays than the one below, as a fraction of the whole: a
## tier-4 piece pays 1 + 4 * step times what its filth alone would. Heavier tiers always pay
## more than the tiers before them (2026-09-14), and test_lake guards that piece by piece.
@export var tier_pay_step: float = 0.5
