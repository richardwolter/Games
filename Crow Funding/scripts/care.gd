extends RefCounted
## Crow care rules: stamina, injuries and the four balcony stations. Pure functions
## and constants only, so tools/test_care.gd can check them without a scene.
## Every number here is a first guess (2026-09-29, unattended pass), to retune in play.

enum Station { TRIP, TRAINING, NEST, FIRST_AID }

const STATION_KEYS: Array[String] = ["trip", "training", "nest", "first_aid"]

const STAMINA_MAX := 100.0
## Stamina a crow starts with and a recruit arrives with.
const STAMINA_START := 100.0
## Each trip out and back costs this much.
const TRIP_STAMINA_COST := 12.0
## A day on the Nest gives this back.
const NEST_RESTORE := 60.0
## Any other day at home (Training, First aid) gives a little back.
const HOME_RESTORE := 15.0
## Under this, a crow is tired: loot drops and injuries get likelier.
const LOW_STAMINA := 40.0
## Chance of an injury on each trip at full stamina, and at zero stamina.
const INJURY_CHANCE_RESTED := 0.01
const INJURY_CHANCE_SPENT := 0.3
## Loot (coins and object chance) at zero stamina, as a share of a rested crow's.
const LOOT_MULT_SPENT := 0.4
## Days an injury lasts on the First-aid box (rolled 1..MAX when it happens).
const INJURY_DAYS_MIN := 1
const INJURY_DAYS_MAX := 2
## A day on the Training post grants this XP (before the Training upgrade).
const TRAINING_XP := 30


static func key_of(station: int) -> String:
	return STATION_KEYS[clampi(station, 0, STATION_KEYS.size() - 1)]


## Share of loot a crow brings home at this stamina: 1 when rested, falling
## linearly under LOW_STAMINA to LOOT_MULT_SPENT at zero.
static func loot_mult(stamina: float) -> float:
	if stamina >= LOW_STAMINA:
		return 1.0
	return lerpf(LOOT_MULT_SPENT, 1.0, clampf(stamina / LOW_STAMINA, 0.0, 1.0))


## Chance a trip injures the crow, rising as stamina falls, steeply once tired.
static func injury_chance(stamina: float) -> float:
	var spent := 1.0 - clampf(stamina / STAMINA_MAX, 0.0, 1.0)
	var tired := 1.0 - clampf(stamina / LOW_STAMINA, 0.0, 1.0)
	# gentle slope while rested, the steep part only under LOW_STAMINA
	return INJURY_CHANCE_RESTED + (INJURY_CHANCE_SPENT - INJURY_CHANCE_RESTED) * (0.25 * spent + 0.75 * tired * tired)


static func after_trip(stamina: float) -> float:
	return maxf(0.0, stamina - TRIP_STAMINA_COST)


## Stamina after a day kept at home on this station.
static func after_home_day(stamina: float, station: int) -> float:
	var gain := NEST_RESTORE if station == Station.NEST else HOME_RESTORE
	return minf(STAMINA_MAX, stamina + gain)


## Injury days left after a night; only the First-aid box heals.
static func after_heal(injury_days: int, station: int) -> int:
	if station == Station.FIRST_AID:
		return maxi(0, injury_days - 1)
	return injury_days


## Whether a crow may be put on this station.
static func can_assign(injury_days: int, station: int) -> bool:
	return not (station == Station.TRIP and injury_days > 0)
