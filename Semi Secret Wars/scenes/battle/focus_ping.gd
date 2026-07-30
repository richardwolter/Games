class_name FocusPing
extends Node2D
## The player's one in-battle command verb: a per-Duo "refocus here" marker.
##
## Each Duo gets exactly ONE refocus per level (Designer, 2026-07-29). Using it
## is two clicks: press the REFOCUS button on that Duo's card (BattleHUD's
## duo-grouped hero panels, which call arm()) to arm it, then left-click a spot
## on the battlefield — empty ground, a knot of minions, the villain, anywhere
## inside the field ellipse. Right-click (or re-pressing the button) cancels an
## ARMED refocus without spending it.
##
## A placed marker lives for DURATION seconds and then expires (Designer,
## 2026-07-29: "make it have a 5 second time to expire it, so Heroes dont just
## stand on the focused spot"). It's a rally order, not a new home: long enough
## to pull the Duo across the field and commit their fire, short enough that they
## go back to fighting on their own judgement instead of camping the spot for the
## rest of the level. The charge is spent either way — expiry never refunds it.
##
## Only that Duo's two heroes react to their own marker: free (untargeted)
## members walk to it (Hero's goal override) and their target selection prefers
## enemies near it (Hero._target_score). The other Duo keeps fighting on its own
## judgement — so the battle stays mostly off the player's hands while each Duo
## can be committed once to a spot: a threat to crush, an objective to rush, a
## retreat to cover.
##
## In group "focus_ping" so heroes query it each frame; created once the first
## wave lands (BattleManager._flush_pending_deploy) so its clicks can never
## collide with the deploy-placement clicks.

## Visual ring radius (world px). Also the "this ping is on the villain" test
## radius — see Hero._ping_targets_villain.
const PING_RADIUS := 90.0
## How close an enemy must be to a marker to get the targeting bonus. Also read
## by Hero._focus_ping_bonus via influence_radius().
const INFLUENCE_RADIUS := 320.0
## Ring pulse period (seconds) for the "still active" breathing animation.
const PULSE_PERIOD := 1.4
## How long a placed marker stays live before expiring, in seconds.
const DURATION := 5.0

## pair_id -> world position of that Duo's LIVE marker. Presence in this
## dictionary IS the "has an active ping" test; the entry is dropped the moment
## the marker expires (see _process).
var _pings: Dictionary = {}
## pair_id -> seconds of life left on that Duo's live marker. Same key set as
## _pings, always — both are written and cleared together.
var _timers: Dictionary = {}
## pair_id -> true once that Duo has spent its one refocus. Distinct from _pings
## only in intent — kept separate so a future "cancel a placed marker" would not
## silently refund the charge.
var _used: Dictionary = {}
## pair_id currently armed and waiting for the player's battlefield click, or ""
## when nothing is armed. Only one Duo can be armed at a time.
var _armed := ""
## Free-running clock driving the idle pulse animation (see _draw).
var _pulse_t := 0.0
var _field: LaneField

func _ready() -> void:
	add_to_group("focus_ping")
	# Above the fog (z 20), below the HUD CanvasLayer. Deploy (z 40) is gone by
	# the time this exists (created once the first wave lands).
	z_index = 30
	_field = get_tree().get_first_node_in_group("field")

## -- Queried by DuoFocusBar (chip state) --------------------------------------

## Arms `pair_id` for the next battlefield click. Re-arming the already-armed
## Duo disarms it (the chip doubles as a cancel). No-op once spent.
func arm(pair_id: String) -> void:
	if is_used(pair_id):
		return
	_armed = "" if _armed == pair_id else pair_id

func is_armed(pair_id: String) -> bool:
	return _armed == pair_id

func is_used(pair_id: String) -> bool:
	return _used.get(pair_id, false)

## Seconds left on `pair_id`'s live marker, or 0.0 if it has none (never placed,
## or already expired). Drives the countdown on the Duo card's REFOCUS button.
func seconds_remaining(pair_id: String) -> float:
	return _timers.get(pair_id, 0.0)

## -- Queried by Hero (per-frame AI) ------------------------------------------

## True when `hero_name`'s Duo has a marker on the field.
func has_active_ping(hero_name: String) -> bool:
	return _pings.has(_pair_of(hero_name))

## Where `hero_name`'s Duo marker sits. Only meaningful when has_active_ping is
## true; Vector2.INF otherwise so a stray caller lands nowhere real.
func ping_pos(hero_name: String) -> Vector2:
	return _pings.get(_pair_of(hero_name), Vector2.INF)

func influence_radius() -> float:
	return INFLUENCE_RADIUS

## pair_id for a hero, or "" if unpaired/pairings invalid (which matches no
## entry in _pings, so an unpaired hero simply never has a marker).
func _pair_of(hero_name: String) -> String:
	var partner := GameState.duo_of(hero_name)
	if partner == "":
		return ""
	return DuoUltimates.id_for_heroes(hero_name, partner)

## -- Input / drawing ---------------------------------------------------------

func _process(delta: float) -> void:
	if _pings.is_empty() and _armed == "":
		return
	# Age every live marker and retire the ones that ran out. Collected first
	# rather than erased mid-iteration.
	var expired: Array[String] = []
	for pair_id in _timers:
		_timers[pair_id] = _timers[pair_id] - delta
		if _timers[pair_id] <= 0.0:
			expired.append(pair_id)
	for pair_id in expired:
		_timers.erase(pair_id)
		_pings.erase(pair_id)
	_pulse_t = fmod(_pulse_t + delta, PULSE_PERIOD)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if _armed == "":
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		# Cancels the arming without spending the Duo's one refocus.
		get_viewport().set_input_as_handled()
		_armed = ""
		queue_redraw()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	var world: Vector2 = get_canvas_transform().affine_inverse() * event.position
	# Ignore clicks off the field ellipse (e.g. panning past the page edge) —
	# the refocus stays armed so a misclick costs nothing.
	if _field != null and (world / _field.field_radius).length_squared() > 1.0:
		return
	get_viewport().set_input_as_handled()
	_pings[_armed] = world
	_timers[_armed] = DURATION
	_used[_armed] = true
	_armed = ""
	_pulse_t = 0.0
	queue_redraw()

## Duo accent for a pair_id — first Duo gold, second navy, matching the colours
## the HUD already uses for the two Duos everywhere else.
func _pair_color(pair_id: String) -> Color:
	for i in GameState.duo_pairings.size():
		var duo = GameState.duo_pairings[i]
		if duo is Array and (duo as Array).size() == 2 \
				and DuoUltimates.id_for_heroes(duo[0], duo[1]) == pair_id:
			return UIStyle.DUO_A if i == 0 else UIStyle.DUO_B
	return UIStyle.DUO_A

func _draw() -> void:
	# Breathing pulse, shared by every marker on the field.
	var a: float = 0.5 + 0.5 * sin(_pulse_t / PULSE_PERIOD * TAU)
	for pair_id in _pings:
		_draw_marker(_pings[pair_id], _pair_color(pair_id), a,
				_timers.get(pair_id, 0.0) / DURATION)

## One marker. `life` is the fraction of DURATION left, drawn as a ring that
## drains clockwise from the top — the player can see how much rally time is
## left without reading the button, and the whole thing dims as it runs out so
## an expiring order stops competing with the fight for attention.
func _draw_marker(p: Vector2, accent: Color, a: float, life: float) -> void:
	life = clampf(life, 0.0, 1.0)
	var col := Color(accent, (0.55 + 0.3 * a) * (0.35 + 0.65 * life))
	var r := PING_RADIUS * (0.9 + 0.1 * a)
	# Track ring at low alpha, with the remaining life drawn over it.
	draw_arc(p, r, 0.0, TAU, 44, Color(accent, 0.18), 4.0, true)
	draw_arc(p, r, -PI * 0.5, -PI * 0.5 + TAU * life, 44, col, 5.0, true)
	draw_arc(p, r * 0.45, 0.0, TAU, 28, col, 3.0, true)
	draw_line(p + Vector2(-r, 0.0), p + Vector2(r, 0.0), col, 2.0, true)
	draw_line(p + Vector2(0.0, -r), p + Vector2(0.0, r), col, 2.0, true)
