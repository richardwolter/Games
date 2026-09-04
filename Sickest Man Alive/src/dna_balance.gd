class_name DnaBalance
extends Object

## What a run is worth, in one place.
##
## DNA is the between-run currency: enemies drop it, the floor holds it until it
## is walked over, and whatever was collected is banked when the run ends and
## spent in the prep menu on permanent item upgrades.
##
## These are game-feel numbers -- how much a kill is worth, what getting out is
## worth -- so they live in code where a change shows up in a diff. The PRICE of
## an upgrade is not here: it sits on UpgradeTable, because it is the knob a
## designer retunes in the authoring dock next to the upgrades it prices.
##
## Measured against the real floor, not a guess: ~49 combat cells and ~800
## enemies in a generated body, of which a run reaches most but not all.
## `tools/test_dna.gd` re-derives the bands below from actual generated maps, so
## they cannot quietly drift when the floor or the wave maths changes.
##
## The three bands, at `cost_per_level` 375 and across pickup rates from 50% to
## 90% (there is no magnet, so how much of it you actually walk over varies a
## lot):
##
##   died under half the rooms, no boss    1.0 - 1.1 upgrades
##   killed every infection, died after    2.4 - 3.0 upgrades
##   killed them and got out               4.5 - 5.3 upgrades
##
## The top two bands sit a little higher than they did when there was one
## infection, and the reason is motes rather than bonuses: a floor now holds two
## or three bosses and each one bursts for DnaBalance.BOSS. The BONUSES were
## deliberately cut to keep the gap between the bands roughly where it was --
## see BOSS_KILL_BONUS.
##
## Note what carries those ratios. Kills scale with rooms cleared, so kills alone
## put the three bands at roughly 1 : 1.6 : 1.9 -- nowhere near the spread the
## design asks for. The separation has to come from the two event bonuses, which
## is why clearing the infections out is worth a few hundred grubs and getting
## out is worth more than that. It is also what makes the bands robust: a sloppy player
## who leaves half the motes on the floor still lands in the right band.

## Per-creature drop values. Set on Enemy as `dna_value`, so a bestiary row or a
## scene can override any of them; these are only the defaults by size.
const SMALL: int = 1
const LARGE: int = 3
const BOSS: int = 40

## The largest single mote. A boss bursts into four motes rather than one fat
## one -- the drop should be something you walk THROUGH, and a single token is
## a token.
const MOTE_MAX_VALUE: int = 5

## Paid at the end of the run, per combat room actually cleared. Rewards taking
## the body apart rather than sprinting for the boss.
const ROOM_CLEAR_BONUS: int = 6

## Killing an infection, whether or not you then get out. Paid PER HEAD, and
## deliberately much smaller than the 300 it was when there was only ever one.
##
## Split into a per-head part and a completion part on purpose, and this is the
## fact a future retune needs and could not recover from the numbers: a per-head
## bonus on its own pays two-of-three bosses two thirds of the band, when the
## design says a run is not finished until every one of them is dead. The kicker
## is what makes the last one worth going back for. Between them they add up to
## roughly what the single flat bonus used to, so the middle band does not swell
## up and swallow the escape band -- which is the thing ESCAPE_BONUS exists to
## keep separate.
const BOSS_KILL_BONUS: int = 90
const ALL_BOSSES_BONUS: int = 120

## Getting out alive: a flat bonus plus a per-cleared-room kicker. The single
## biggest number in the game, on purpose -- surviving the rampage is the hardest
## thing in a run, and this bonus is the entire difference between the "killed
## the infection" band and the "finished the run" band.
const ESCAPE_BONUS: int = 425
const ESCAPE_ROOM_BONUS: int = 6

## A run that got somewhere pays for at least one upgrade however badly the motes
## were collected, so a real attempt is never worth nothing.
##
## Gated on rooms rather than granted flat, and that gate is the whole point: a
## floor with no condition makes quitting in the first room the fastest DNA in
## the game. Eight rooms is far enough in that dying there was a run.
const MIN_PAYOUT_ROOMS: int = 8
