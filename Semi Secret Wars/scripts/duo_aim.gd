class_name DuoAim
## Picks the direction a linear Duo Ultimate should sweep (Designer,
## 2026-07-26). Shared by StompWave ("Seismic Advance") and PlantTrail
## ("Verdant Path"), which both lay a row of evenly spaced damage circles out
## from the caster and, until now, always fired straight down the lane (+X)
## regardless of where anything actually was.
##
## Both effects have the SAME geometry — circle `i` sits at
## `origin + dir * spacing * i`, for `count` circles of `radius` — so one
## scorer serves both. Anything else that grows a straight line of hitboxes can
## use it too.
##
## Scoring counts every (circle, target) overlap rather than unique targets, so
## a direction that sweeps a dense column is rated above one that clips the
## same number of scattered enemies once each — which is exactly what "best
## possible outcome" means for a marching effect.

## Directions tried, evenly spaced around the full circle. The full 360 is
## deliberate: if the swarm has flowed in behind the party, the best stomp is a
## backwards one, and the whole point of this pass is that the effect stops
## being blind to that. 24 samples = one every 15 degrees, comfortably finer
## than the effects' own circle radii can resolve.
const SAMPLE_COUNT := 24

## Relative worth of what a circle can cover. A spawn point is worth several
## minions because killing it stops the ones that haven't spawned yet, and the
## villain outranks both because it alone ends the level (see
## BattleManager._check_win). These are deliberately coarse — the ordering is
## what matters, not the exact ratios.
const MINION_WEIGHT := 1.0
const SPAWN_POINT_WEIGHT := 3.0
const VILLAIN_WEIGHT := 5.0

## The aim direction, as a unit vector. Falls back to lane-forward (+X, the
## established deploy -> villain direction) when there's nothing to aim at, and
## ties resolve to it as well — so with no better option the effect behaves
## exactly as it did before this existed.
static func best_direction(caster: Hero, origin: Vector2, spacing: float,
		count: int, radius: float) -> Vector2:
	if caster == null or not is_instance_valid(caster) or count <= 0:
		return Vector2.RIGHT
	var targets := _targets(caster)
	if targets.is_empty():
		return Vector2.RIGHT
	# Seeded with lane-forward and beaten only by a STRICTLY higher score, so a
	# tie keeps the old behavior.
	var best_dir := Vector2.RIGHT
	var best_score := _score(Vector2.RIGHT, origin, spacing, count, radius, targets)
	for i in SAMPLE_COUNT:
		var angle := TAU * float(i) / float(SAMPLE_COUNT)
		var dir := Vector2(cos(angle), sin(angle))
		var score := _score(dir, origin, spacing, count, radius, targets)
		if score > best_score:
			best_score = score
			best_dir = dir
	return best_dir

## Everything the caster could legitimately hit, as {pos, weight} pairs.
##
## Filtered by the SAME rules the effects use when they actually deal damage
## (caster.enemy_group membership, alive, and caster._lane_ok) — if aiming
## counted a target the damage pass then skips, the effect would confidently
## fire at something it cannot hurt.
static func _targets(caster: Hero) -> Array:
	var out: Array = []
	for node in caster.get_tree().get_nodes_in_group(caster.enemy_group):
		if not is_instance_valid(node) or node._dying or not caster._lane_ok(node):
			continue
		var weight := MINION_WEIGHT
		if node is LaneSpawnPoint:
			weight = SPAWN_POINT_WEIGHT
		elif node is Villain:
			# A dormant villain is not a threat yet and shouldn't pull an
			# Ultimate away from the swarm actually attacking the party; it
			# still counts as an ordinary body so a sweep that happens to
			# cross it isn't undervalued.
			weight = VILLAIN_WEIGHT if node.is_alerted() else MINION_WEIGHT
		out.append({"pos": node.global_position, "weight": weight})
	return out

## Total weight covered by the whole line of circles, counting a target once
## per circle that reaches it.
static func _score(dir: Vector2, origin: Vector2, spacing: float, count: int,
		radius: float, targets: Array) -> float:
	var total := 0.0
	var r2 := radius * radius
	for i in count:
		var at := origin + dir * spacing * float(i)
		for t in targets:
			if at.distance_squared_to(t["pos"]) <= r2:
				total += float(t["weight"])
	return total

## -- Point placement ----------------------------------------------------------

## The best spot within `max_range` of `origin` to drop something that acts on
## whatever is within `presence_radius` of it — used to place clones somewhere
## that matters instead of beside the caster (Designer, 2026-07-26).
##
## Same target weights as the sweep scorer above, so a clone prefers a spawn
## point or an alerted villain to an equivalent knot of minions.
##
## Returns `origin` unchanged when there is nothing worth walking toward, which
## keeps the old beside-the-caster behavior as the floor. The caller is
## expected to add its own per-clone offset on top of the returned anchor —
## this picks WHERE the group should be, not how its members fan out.
const SPOT_RINGS := [0.4, 0.7, 1.0]
const SPOT_ANGLES := 12

static func best_spot(caster: Hero, origin: Vector2, max_range: float,
		presence_radius: float) -> Vector2:
	if caster == null or not is_instance_valid(caster) or max_range <= 0.0:
		return origin
	var targets := _targets(caster)
	if targets.is_empty():
		return origin
	var best := origin
	# Seeded with the caster's own position and beaten only by a strictly
	# better score, so a spawn that gains nothing stays where it always was.
	var best_score := _spot_score(origin, presence_radius, targets)
	for ring in SPOT_RINGS:
		for i in SPOT_ANGLES:
			var angle := TAU * float(i) / float(SPOT_ANGLES)
			var p: Vector2 = origin + Vector2(cos(angle), sin(angle)) * (max_range * float(ring))
			if not _spot_valid(caster, p):
				continue
			var score := _spot_score(p, presence_radius, targets)
			if score > best_score:
				best_score = score
				best = p
	return best

## Rejects candidates a unit could not sensibly stand on: outside the field
## ellipse, in the Poison Lake, or inside an obstacle. Mirrors the checks
## DarkMage._find_teleport_spot makes for the same reason — a clone dropped
## into the lake starts dying immediately and taunts nothing.
static func _spot_valid(caster: Hero, p: Vector2) -> bool:
	var field = caster._field
	if field == null:
		return true
	if (p / field.field_radius).length_squared() > 1.0:
		return false
	if field.in_lake(p):
		return false
	for o in field.obstacles:
		if p.distance_to(Vector2(o.x, o.y)) < o.z + caster.body_radius:
			return false
	return true

static func _spot_score(at: Vector2, presence_radius: float, targets: Array) -> float:
	var total := 0.0
	var r2 := presence_radius * presence_radius
	for t in targets:
		if at.distance_squared_to(t["pos"]) <= r2:
			total += float(t["weight"])
	return total
