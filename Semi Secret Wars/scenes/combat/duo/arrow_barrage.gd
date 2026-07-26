class_name ArrowBarrage
extends Node2D
## ARTEMIS+BEACON Duo Ultimate ("Piercing Volley", see DuoUltimates/
## Hero.cast_duo_ultimate): a SUSTAINED barrage. Every wave_interval seconds
## for `duration` seconds, it resolves a burst of up to arrow_count hits on the
## nearest enemies within hit_range, each chaining onward to up to chain_count
## further nearby enemies at chain_damage_mult of the original arrow's damage.
##
## NOT named `range` — that shadows GDScript's builtin range() and would
## break every `for i in range(...)` loop in this very script.
##
## Ability-cadence pass (2026-07-24): per-arrow damage used to be
## caster.damage (Artemis's live attack damage, ~3 effective) instead of a
## flat catalog constant like every other Duo Ultimate — the whole
## once-per-level cast dealt roughly 36 total. Now `arrow_damage`, still
## scaled by the same Duo/objective mults every other ultimate uses.
##
## Duration pass (Designer, 2026-07-25: "make it last 10s", balance-neutral):
## this used to resolve its entire damage in one instant burst. It now fires
## `_wave_count()` waves across `duration` — and arrow_damage is divided by
## that wave count, so the ultimate's TOTAL output is unchanged from the
## instant version. What changed is that the damage lands over 10s on whoever
## is nearby at each wave, instead of all at once on whoever stood there at
## cast time. The node follows its caster for the duration, so the barrage
## tracks Artemis rather than staying pinned to where she cast it.

var caster: Hero = null
var arrow_count := 6
var chain_count := 2
var chain_damage_mult := 0.5
var hit_range := 260.0
var arrow_damage := 55.0
## Total seconds the barrage keeps firing (Designer, 2026-07-25).
var duration := 10.0
## Seconds between waves. duration / this = how many waves the total damage is
## split across.
var wave_interval := 0.5

## How far a chain hop may reach from its previous link to find its next,
## not-yet-hit victim.
const CHAIN_RADIUS := 140.0

## Visual rework (Designer, 2026-07-25): the volley used to draw ONE hairline
## per hit, all appearing at once, which read as a single thin streak with no
## visible chaining. Now every hit is a real arrow that FLIES from its source to
## its victim, and each primary target is hit by a spread of ARROWS_PER_TARGET
## arrows so each wave reads as a wide stream rather than one line.
## Chain hops start only once the arrow that caused them has landed, so the
## bounce between minions is something you can actually watch.
##
## Damage is still resolved the instant a wave fires — the arrows are purely
## visual playback of an already-decided result.
const ARROW_ART := preload("res://assets/sprites/Arrow_Right.png")
const ARROW_LENGTH := 34.0
## How many arrows draw per primary target, fanned out across the stream.
const ARROWS_PER_TARGET := 3
## Half-width of the stream at its widest, perpendicular to the shot.
## 46 -> 110 (Designer, 2026-07-25: wider spread) — the fan now covers ~220px
## across, so each wave reads as a broad volley rather than a tight burst.
const STREAM_SPREAD := 110.0
## Arrow travel speed (px/sec) and the floor/ceiling on a hop's flight time.
const ARROW_SPEED := 1100.0
const MIN_FLIGHT := 0.06
const MAX_FLIGHT := 0.3
## Extra beat between an arrow landing and the chain hop it causes leaving.
const CHAIN_DELAY := 0.05
## How long a landed arrow's streak lingers before fading out.
const TRAIL_FADE := 0.25

## Cast SFX (Designer, 2026-07-25): the whole file, back to back, 5 times.
const CAST_SOUND := preload("res://assets/Sounds/Arrow_Barrage.wav")
const CAST_SOUND_PLAYS := 5

## One flying arrow: GLOBAL-space endpoints (the node moves with its caster, so
## local coords would drag already-fired arrows along with it) plus its own
## timing. `depth` is 0 for a wave's opening salvo, 1+ for chain hops.
var _arrows: Array[Dictionary] = []
var _elapsed := 0.0
var _wave_cd := 0.0
var _waves_fired := 0

func _ready() -> void:
	BattleSfx.play_repeats(self, CAST_SOUND, CAST_SOUND_PLAYS)
	_fire_wave()
	queue_redraw()

## How many waves the duration is split into (at least 1, so a zero/short
## duration still behaves like the old instant burst instead of dealing none).
func _wave_count() -> int:
	if wave_interval <= 0.0:
		return 1
	return maxi(1, int(round(duration / wave_interval)))

func _process(delta: float) -> void:
	_elapsed += delta
	_wave_cd -= delta
	if _wave_cd <= 0.0 and _waves_fired < _wave_count():
		_wave_cd = wave_interval
		_fire_wave()
	# Follow the caster so a 10s barrage tracks her instead of hanging in the
	# air where it was cast. Arrows already in flight keep their own global
	# endpoints and are unaffected.
	if caster != null and is_instance_valid(caster):
		global_position = caster.global_position
	_prune_arrows()
	# Stays alive until the last wave's arrows have finished flying and faded.
	if _waves_fired >= _wave_count() and _arrows.is_empty():
		queue_free()
		return
	queue_redraw()

## Drops arrows whose flight and trail fade are both over, so a 10s barrage
## doesn't accumulate every arrow it ever fired.
func _prune_arrows() -> void:
	var kept: Array[Dictionary] = []
	for arrow in _arrows:
		if _elapsed < float(arrow["start"]) + float(arrow["flight"]) + TRAIL_FADE:
			kept.append(arrow)
	_arrows = kept

## Resolves one wave: damage now, arrows drawn flying over the next fraction
## of a second.
func _fire_wave() -> void:
	_waves_fired += 1
	if caster == null or not is_instance_valid(caster) or caster._dying:
		return
	var candidates: Array[Combatant] = []
	for node in get_tree().get_nodes_in_group(caster.enemy_group):
		if not is_instance_valid(node) or node._dying or not caster._lane_ok(node):
			continue
		if global_position.distance_to(node.global_position) <= hit_range:
			candidates.append(node)
	candidates.sort_custom(func(a, b) -> bool:
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))

	# Split across the whole barrage so total output matches the old instant
	# burst (Designer chose balance-neutral).
	var per_arrow_damage: float = (arrow_damage / float(_wave_count())) \
			* caster._duo_damage_mult * caster.damage_mult()
	var hit_already: Array[Combatant] = []
	var arrows_fired := 0
	for primary in candidates:
		if arrows_fired >= arrow_count:
			break
		if primary in hit_already:
			continue
		primary.take_damage(per_arrow_damage, caster)
		hit_already.append(primary)
		# A wave's opening salvo: a fan of arrows toward this target, launched
		# together with a small per-arrow stagger so the stream doesn't read as
		# a single rigid wall. Each shot leaves from its own point across the
		# stream's width, so the volley spreads out from the caster rather than
		# all arrows overlapping on one line.
		var salvo_start := _elapsed + float(arrows_fired) * 0.035
		var landed := _add_salvo(global_position, primary.global_position, salvo_start)
		arrows_fired += 1

		# Chain hops: one arrow each, leaving only after the previous link's
		# arrow has landed — this is the "bouncing between minions" beat.
		var chain_from: Combatant = primary
		var hop_start := landed + CHAIN_DELAY
		for _c in chain_count:
			var next_hit := _nearest_unhit(chain_from.global_position, hit_already)
			if next_hit == null:
				break
			next_hit.take_damage(per_arrow_damage * chain_damage_mult, caster)
			hit_already.append(next_hit)
			hop_start = _add_arrow(chain_from.global_position, next_hit.global_position,
					hop_start, _c + 1, 0.0) + CHAIN_DELAY
			chain_from = next_hit

## Queues ARROWS_PER_TARGET fanned arrows from -> to. Returns the time at which
## the last of them lands.
func _add_salvo(from: Vector2, to: Vector2, start: float) -> float:
	var perp := (to - from).orthogonal().normalized() if (to - from).length() > 1.0 else Vector2.UP
	var landed := start
	for i in ARROWS_PER_TARGET:
		# -1..1 across the fan (a single arrow would sit dead center).
		var t := 0.0 if ARROWS_PER_TARGET <= 1 else (float(i) / float(ARROWS_PER_TARGET - 1)) * 2.0 - 1.0
		landed = maxf(landed, _add_arrow(from, to, start + absf(t) * 0.03, 0, t * STREAM_SPREAD, perp))
	return landed

## Queues one arrow. `spread` fans its LANDING point sideways along `perp`;
## `depth` is 0 for a salvo arrow, 1+ for chain hops. Returns the time at which
## it lands.
##
## The spread deliberately applies to the destination, not the launch point.
## Offsetting the launch point instead (as this first shipped) drew a reverse
## cone — wide at Artemis, converging on the target — which read as arrows
## flying INTO her (Designer, 2026-07-25). Every arrow now leaves her exact
## position and fans outward downrange, which is what a volley looks like.
func _add_arrow(from: Vector2, to: Vector2, start: float, depth: int, spread: float,
		perp := Vector2.ZERO) -> float:
	var flight := clampf(from.distance_to(to) / ARROW_SPEED, MIN_FLIGHT, MAX_FLIGHT)
	_arrows.append({
		"from": from,
		"to": to + perp * spread,
		"start": start,
		"flight": flight,
		"depth": depth,
	})
	return start + flight

func _nearest_unhit(from: Vector2, exclude: Array) -> Combatant:
	var best: Combatant = null
	var best_d := CHAIN_RADIUS * CHAIN_RADIUS
	for node in get_tree().get_nodes_in_group(caster.enemy_group):
		if not is_instance_valid(node) or node._dying or node in exclude or not caster._lane_ok(node):
			continue
		var d := from.distance_squared_to(node.global_position)
		if d <= best_d:
			best_d = d
			best = node
	return best

func _draw() -> void:
	for arrow in _arrows:
		var start: float = arrow["start"]
		if _elapsed < start:
			continue  # not launched yet
		var flight: float = arrow["flight"]
		# Stored global (the node moves with its caster) — convert for drawing.
		var from: Vector2 = to_local(arrow["from"])
		var to: Vector2 = to_local(arrow["to"])
		var depth: int = arrow["depth"]
		# Chain hops draw dimmer/thinner than the opening salvo so the eye reads
		# the bounce as a follow-up rather than a second full volley.
		var strength := 1.0 if depth == 0 else 0.7
		var progress := clampf((_elapsed - start) / flight, 0.0, 1.0)
		var tip := from.lerp(to, progress)
		var fade := 1.0
		if progress >= 1.0:
			# Landed: the arrow sticks where it hit and fades out, rather than
			# vanishing the instant it arrives.
			fade = clampf(1.0 - (_elapsed - start - flight) / TRAIL_FADE, 0.0, 1.0)
		# Arrow sprites only — the yellow streak lines this used to draw behind
		# each shot are gone (Designer, 2026-07-25: "not the yellow lines but
		# the actual arrow sprites").
		_draw_arrow(tip, (to - from).angle(), fade * strength, strength)

## The arrow head itself, rotated to point along its flight.
func _draw_arrow(at: Vector2, angle: float, alpha: float, size_mult: float) -> void:
	var tex_size := ARROW_ART.get_size()
	var longest := maxf(tex_size.x, tex_size.y)
	if longest <= 0.0:
		return
	var draw_size := tex_size * (ARROW_LENGTH * size_mult / longest)
	draw_set_transform(at, angle, Vector2.ONE)
	draw_texture_rect(ARROW_ART, Rect2(-draw_size * 0.5, draw_size), false,
			Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
