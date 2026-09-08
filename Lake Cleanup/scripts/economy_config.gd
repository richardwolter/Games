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
