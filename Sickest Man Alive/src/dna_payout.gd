class_name DnaPayout
extends Object

## What a finished run pays out, as a pure function of what happened in it.
##
## Separated from RunManager on purpose: a payout that can only be observed by
## playing a whole run cannot be regression-tested, and the three bands it has to
## hit (see DnaBalance) are the kind of thing that drifts silently the moment
## anything else about the game changes. `tools/test_dna.gd` asserts the bands
## against this directly.
##
## Returns the FULL breakdown, not just a number, because the results panel
## prints it line by line -- a player who cannot see where the DNA came from
## cannot tell that clearing rooms was worth doing.


## `motes` is what was actually picked up off the floor, not what dropped.
## `floor_cost` is one upgrade's price, used for the minimum a real attempt pays;
## pass 0 to disable the floor entirely.
##
## `bosses_killed` and `bosses_total` are counts and not a fraction, because the
## results panel prints "2 / 3" and a float cannot say that.
static func breakdown(motes: int, rooms_cleared: int, bosses_killed: int,
		bosses_total: int, escaped: bool, floor_cost: int = 0) -> Dictionary:
	var room_bonus := maxi(rooms_cleared, 0) * DnaBalance.ROOM_CLEAR_BONUS
	# Per head, plus a kicker for leaving none behind. See DnaBalance for why the
	# two halves exist rather than one flat number.
	var boss_bonus := maxi(bosses_killed, 0) * DnaBalance.BOSS_KILL_BONUS
	if bosses_total > 0 and bosses_killed >= bosses_total:
		boss_bonus += DnaBalance.ALL_BOSSES_BONUS
	var escape_bonus := 0
	if escaped:
		escape_bonus = DnaBalance.ESCAPE_BONUS \
			+ maxi(rooms_cleared, 0) * DnaBalance.ESCAPE_ROOM_BONUS
	var earned := maxi(motes, 0) + room_bonus + boss_bonus + escape_bonus

	# The floor for a run that got somewhere. Reported as its own line rather
	# than folded into the others, so a player can see they were topped up.
	var made_up := 0
	if floor_cost > 0 and rooms_cleared >= DnaBalance.MIN_PAYOUT_ROOMS \
			and earned < floor_cost:
		made_up = floor_cost - earned

	return {
		"motes": maxi(motes, 0),
		"room_bonus": room_bonus,
		"boss_bonus": boss_bonus,
		"escape_bonus": escape_bonus,
		"made_up": made_up,
		"total": earned + made_up,
	}


static func total(motes: int, rooms_cleared: int, bosses_killed: int,
		bosses_total: int, escaped: bool, floor_cost: int = 0) -> int:
	return breakdown(motes, rooms_cleared, bosses_killed, bosses_total,
		escaped, floor_cost)["total"]
