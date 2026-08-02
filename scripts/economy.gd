## Money and scoring. Money is earned only by attempting crossings and spent only
## in the shop, so the loop is: attempt → cash → better pieces → attempt.
##
## Money carries between levels. Pieces do not, which is what stops a player from
## hoarding girders on level 1 and walking level 5.
class_name Economy
extends Node

signal money_changed(amount: int)
signal score_changed(score: int)

@export var starting_money: int = 90

## Score for reaching the far shore. Distance alone can't reach this, so a
## crossing always beats a near miss.
@export var success_score: int = 1000
## Score for a failed attempt, scaled by how far the car got.
@export var distance_score: int = 700
## Money per point of *improvement* over your previous best on this level.
## Paying for improvement rather than per attempt means replaying the same
## mediocre build can't be farmed for cash.
@export var payout_per_score: float = 0.5
## Money every attempt pays regardless. It means a player who has spent
## everything on a build that can't be improved is never hard-stuck — and at 12 it
## was so far below the price of anything that being stuck took a dozen pointless
## attempts to climb out of. A run costs half a minute; the floor should buy
## something within a few of them.
@export var attempt_floor: int = 30
## Paid on top the first time a level is beaten.
@export var completion_bonus: int = 200

## Getting further than you ever have is the thing the whole game is about, and
## until now it paid exactly the same as any other attempt that happened to score
## well. It gets its own money: a flat sum for setting a record at all, plus a
## rate on how much further you pushed.
##
## Deliberately separate from the score payout rather than folded into it. The
## score is a number that goes up; a record is an event, and it should arrive as
## its own line in the banner — "you have never been this far" is the sentence the
## player is playing to hear.
@export var record_bonus: int = 45
## Per percentage point of the strait gained over the old record. Deliberately
## modest: the first attempt on a level claims the whole distance at once, so this
## rate is paid over 100 points the very first time somebody crosses.
@export var record_bonus_per_percent: float = 4.0
## Below this the "record" is measurement noise — a car that rolled 4px further
## should not set off a fanfare.
const RECORD_EPSILON := 0.005

var money: int = 0
## Best score on the level being played. LevelManager resets it.
var best_score: int = 0
## Furthest the car has ever got on this level, as a fraction of the strait.
## Tracked apart from best_score because a success scores 1000 flat, so score
## alone can't say whether an attempt went further than the last one.
var best_progress: float = 0.0
## What the last attempt paid for setting a record, or 0 if it set none. Read by
## the HUD to add a line to the result banner.
var last_record_bonus: int = 0


func _ready() -> void:
	money = starting_money
	money_changed.emit(money)


func add(amount: int) -> void:
	money += amount
	money_changed.emit(money)


func can_afford(cost: int) -> bool:
	return money >= cost


func spend(cost: int) -> bool:
	if not can_afford(cost):
		return false
	money -= cost
	money_changed.emit(money)
	return true


func reset_score() -> void:
	best_score = 0
	best_progress = 0.0
	last_record_bonus = 0
	score_changed.emit(best_score)


## Score one attempt. `progress` is the fraction of the strait crossed.
func score_for(succeeded: bool, progress: float) -> int:
	if succeeded:
		return success_score
	return roundi(distance_score * progress)


## Bank one attempt. Returns [score, money earned].
func settle_attempt(succeeded: bool, progress: float, first_clear: bool) -> Array[int]:
	var score := score_for(succeeded, progress)
	var earned := attempt_floor + roundi(maxi(score - best_score, 0) * payout_per_score)

	# The distance record, paid on top and reported separately.
	last_record_bonus = 0
	var reached := 1.0 if succeeded else clampf(progress, 0.0, 1.0)
	if reached > best_progress + RECORD_EPSILON:
		var gained_percent := (reached - best_progress) * 100.0
		last_record_bonus = record_bonus + roundi(gained_percent * record_bonus_per_percent)
		earned += last_record_bonus
	best_progress = maxf(best_progress, reached)

	if first_clear:
		earned += completion_bonus
	best_score = maxi(best_score, score)

	add(earned)
	score_changed.emit(best_score)
	return [score, earned]
