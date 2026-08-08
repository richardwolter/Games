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

## How far the far shore's top sits ABOVE the waterline. 0 keeps both banks level
## with the water, which is every level up to now.
##
## The near shore never moves: the truck has to start from the same familiar place
## or the run-up stops being a constant. The far bank rises straight out of the
## water as a cliff: it meets the seabed at the waterline and is at full height
## again within a couple of hundred units, so the climb is a wall standing in the
## build area, not a hill somewhere inland. It is too steep to drive — the bridge
## has to arrive at the top of it.
##
## Kept well under World.HEADROOM's worth of room; World adds this to the ceiling
## so the space above the higher bank is the same as it always was.
@export var far_shore_lift: float = 0.0

## Average grade of the cliff face, rise over run. Steep enough that no truck is
## getting up it — around 58° — but not vertical, so the rock still reads as cut
## ground and a piece leaned against it has something to sit on.
##
## Held here rather than in World because the goal line and the build box both have
## to know where the face ends, and that is decided from the level.
const FAR_SLOPE_GRADE := 1.6


## Horizontal distance the far bank takes to reach its full height. 0 when flat.
func far_slope_run() -> float:
	return far_shore_lift / FAR_SLOPE_GRADE


## How far the near shore rises above the waterline at the water's edge, and how
## much ground that rise is spread over. 0 keeps the near bank flat, which is
## every level up to now.
##
## This is a launch ramp cut into the terrain itself, not a piece placed on it:
## the near bank runs flat for the truck's usual run-up, then climbs to a lip
## exactly at the water's edge. The truck leaves the ground there. It only exists
## outside the strait, so the build area and everything in it are untouched — what
## changes is that the crossing can start in the air.
##
## The profile is flat at the foot and steepest at the lip (see World), so the
## truck rolls on without a crease to trip over and leaves at the ramp's full
## grade. Peak grade is 2 * rise / run, so the two numbers are chosen together.
@export var near_ramp_rise: float = 0.0
@export var near_ramp_run: float = 0.0

## Flat ground kept behind the ramp's foot for the truck to build speed on. The
## run-up has to stay the length it is on a flat level or the ramp would be paid
## for out of the truck's acceleration.
const NEAR_RUNUP := 1000.0

## Multiplier on the truck's drive torque and its wheel-speed cap. 1.0 is the
## truck as it drives on every level up to now.
##
## Level property rather than a truck upgrade because it is answering a level's
## geometry: a strait that ends in a climb needs the truck to arrive with momentum
## to spend, and a truck tuned for that climb would be overpowered everywhere else.
## Scaling both numbers together rather than the cap alone keeps it drivable — a
## higher top speed with the same torque only means a longer time to reach it.
@export var truck_power: float = 1.0

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

## Finer control over the same thing, for a level that wants some of one and none
## of the other. Both scale whatever `life` already allows: at FULL they are the
## level's own share of the plants and the fish, and at MOSS or NONE they change
## nothing, because there is nothing there to scale.
##
## A quarry flooded with meltwater is the case they exist for — a few weeds on the
## ledges and no fish at all reads as a pit full of water, where a full seabed
## garden reads as a river that has been there for centuries.
@export_range(0.0, 1.0) var plant_density: float = 1.0
@export_range(0.0, 1.0) var fish_density: float = 1.0

## A rock pillar standing in the middle of the strait, as its width at the
## waterline. Zero — the default — is open water, which is every level that does
## not ask for one.
##
## Not a prop: it is cut from the same ground as the banks and the seabed, by the
## same shader, so it belongs to whatever biome the level is. What it changes is
## the problem — a strait with a pillar in it is two short spans instead of one
## long one, for anybody who can reach it.
@export var pillar_width: float = 0.0
## How far its head stands above the waterline. Negative leaves it submerged,
## which makes it a hazard rather than a foundation.
@export var pillar_rise: float = 60.0
## How much wider the foot is than the head, as a multiplier. A pillar that goes
## down straight reads as a column somebody poured; rock in water is undercut at
## the top and buttressed at the bottom.
@export var pillar_flare: float = 2.2


## One large thing standing on the seabed — a drowned tree, a wreck, whatever the
## strait has in it. Solid: pieces land on it and the truck can be driven over
## it, so it is level design rather than scenery, and a level gets at most one.
##
## Left empty the strait floor is bare, which is every level that does not say
## otherwise.
@export var seabed_prop: Texture2D = null
## Its collision, in a unit box centred on zero — the same convention ObjectDef
## uses, traced by tools/trace_prop.gd. Without one the prop is a picture only,
## which is a thing the player can see and drop a plank straight through.
@export var seabed_prop_polygon: PackedVector2Array = PackedVector2Array()
## Where it stands, as a fraction of half_width. -1 is the near bank, 1 the far.
@export_range(-1.0, 1.0) var seabed_prop_at: float = -0.35
## How far its top stays under the waterline. Small, so the thing breaks the
## surface as a hazard you have to build around; never zero, or it pokes through
## the water shader and reads as a sprite laid on top of the strait.
@export var seabed_prop_clearance: float = 40.0
## Shrinks it from that full height, keeping its base on the seabed. 1.0 fills
## the water column exactly; below that it stands shorter and its top sinks away
## from the surface, which is the lever for a prop that dominates the strait when
## it is sized by depth alone.
@export_range(0.1, 1.0) var seabed_prop_scale: float = 1.0

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
	# Behind the ramp's foot, so the run-up is the same length either way.
	return Vector2(-half_width - NEAR_RUNUP - near_ramp_run, 300.0)


## Chassis past here has landed on the far shore.
##
## Past the top of the cliff, not its foot: on a lifted level the truck arrives on
## the clifftop or not at all, and reaching the rock at water level is a crash into
## a wall rather than a crossing.
func goal_x() -> float:
	return half_width + 80.0 + far_slope_run()
