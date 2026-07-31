class_name DuoControlBar
extends PanelContainer
## DUO CONTROL — the single in-battle command panel (Designer, 2026-07-30):
## every player verb for BOTH Duos in one small box, instead of the two separate
## UIs it replaced.
##
## Before this, the two commands lived apart: REFOCUS sat inside each Duo's hero
## card group on the left (BattleHUD._build_refocus_row) and the Ultimate lived
## on its own bottom-right stack of 310px cards (DuoUltimateBar, deleted with
## this). Between them they covered a lot of battlefield for two buttons per Duo,
## and the player had to look in two places to command one Duo.
##
## Layout: one compact row per Duo — the Duo's name tag in its accent colour,
## then its REFOCUS and ULTIMATE buttons side by side. Both buttons are the same
## small size, because they are the same KIND of thing: one use, this level, on
## your call.
##
## Built in code (no .tscn) and positioned with a plain fixed offset — see
## BAR_POSITION. An anchor-preset + grow-direction approach was tried for the bar
## this replaced and never appeared on screen at all, so this avoids that class of
## math entirely.
##
## Refreshed every frame by BattleHUD._process -> refresh().

## Bottom of the LEFT column, under the hero cards (Designer, 2026-07-30: "bring
## hero control also to the left of the player UI, leaving all clear visibility
## on the middle and right"). Every piece of player UI now lives down the left
## edge — resources and menu buttons on top, hero cards below them, this at the
## foot — so the middle and right of the lane are pure battlefield.
##
## x matches HeroPanelsRoot's 16 in battlefield.tscn so the panel lines up with
## the card column above it. The y here is only a STARTING value — BattleHUD
## moves the panel to sit right under the real bottom of the card column every
## frame (see BattleHUD._place_duo_control and GAP_BELOW_CARDS). It was parked
## near the bottom edge at first, which left a gap of dead paper between the
## cards and their own controls (Designer, 2026-07-30: "bring hero control up
## closer to heroes cards, its too near the edge") — and the card column's height
## is not knowable here anyway, since it shrinks as heroes die.
const BAR_POSITION := Vector2(16.0, 700.0)
## Matches the hero cards' own width so the left column reads as one stack rather
## than a panel of a different size parked under it.
const BAR_WIDTH := 330.0
## Both command buttons on a row share this width, so the two columns line up
## down the panel regardless of their current state text ("CLICK A SPOT",
## "UNAVAILABLE", a live countdown).
const BUTTON_WIDTH := 128.0

## Accent for the Ultimate button and the panel border — an Ultimate is a
## highlight element, same family as the boon picks on LevelUpScreen.
const ACCENT := UIStyle.GOLD

## Alpha a spent control fades to. Not zero: a ghost keeps the panel's layout
## from jumping and still reads as "that was here and is gone", while being far
## too faint to obstruct the battlefield behind it (Designer, 2026-07-29: "make
## the whole Ultimate Card almost invisible after usage").
const SPENT_ALPHA := 0.12
## Pop-then-fade timing for a spent control's send-off.
const SPEND_POP_TIME := 0.18
const SPEND_FADE_TIME := 0.9

## pair_id -> Button, one dictionary per command.
var _ultimate_buttons: Dictionary = {}
var _refocus_buttons: Dictionary = {}
## pair_ids whose spend animation has already run, per command — refresh() runs
## every frame and must fire each exactly once.
var _ultimate_spent_shown: Dictionary = {}
var _refocus_spent_shown: Dictionary = {}

var _rows: VBoxContainer

func _ready() -> void:
	position = BAR_POSITION
	custom_minimum_size = Vector2(BAR_WIDTH, 0)
	add_theme_stylebox_override("panel", UIStyle.card(ACCENT, 8))
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	add_child(_rows)
	_rows.add_child(UIStyle.centered_label("DUO CONTROL", UIStyle.SIZE_TINY, UIStyle.INK_MUTED))
	build_rows()

## One row per Duo pairing — called once by BattleHUD as soon as
## GameState.duo_pairings is settled for this level. Safe with no valid pairings
## (e.g. a stale/empty save): simply builds zero rows.
func build_rows() -> void:
	for pair in GameState.duo_pairings:
		if not (pair is Array) or (pair as Array).size() != 2:
			continue
		var pair_id := DuoUltimates.id_for_heroes(pair[0], pair[1])
		_rows.add_child(_build_row(pair_id, pair[0], pair[1]))

## NOTE: rebuild_rows() existed because the start-of-level Duo reshuffle settled
## GameState.duo_pairings after this panel had already been built, leaving it
## offering the Ultimates of a pairing the player had just changed away from
## (Designer, 2026-07-28). That mechanic was removed on 2026-07-30 — pairings are
## fixed at prep for the whole run — so the rows are built once and can never go
## stale.

## A Duo's whole command set on one line: who they are, then what you can order.
## The Duo tag takes the same DUO_A/DUO_B accents FocusPing paints that Duo's
## marker in, so the row and the ring on the field read as the same Duo.
func _build_row(pair_id: String, hero_a: String, hero_b: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)

	var accent: Color = UIStyle.DUO_A if _refocus_buttons.is_empty() else UIStyle.DUO_B
	col.add_child(UIStyle.centered_label("%s + %s" % [hero_a, hero_b],
			UIStyle.SIZE_TINY, accent))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	col.add_child(row)

	# No hover tooltips on either button (Designer, 2026-07-30). The Ultimate's
	# name and description used to pop up over the ULTIMATE button; the player
	# chose this pairing for that Ultimate at prep, saw it named on the boon pick
	# at the start of the level, and gets a centre-screen banner naming it again
	# when it fires — a fourth telling, on hover, mid-fight, was noise over the
	# battlefield.
	var refocus := _command_button("REFOCUS", _on_refocus_pressed.bind(pair_id))
	row.add_child(refocus)
	_refocus_buttons[pair_id] = refocus

	var ultimate := _command_button("ULTIMATE", _on_activate_pressed.bind(pair_id))
	row.add_child(ultimate)
	_ultimate_buttons[pair_id] = ultimate
	return col

## A fixed-width compact button. Variant is seeded off the row count so the
## hand-drawn wobble differs between the two Duos' controls.
func _command_button(text: String, cb: Callable) -> Button:
	var b := UIStyle.compact_button(text, UIStyle.SIZE_TINY, cb, _refocus_buttons.size())
	b.custom_minimum_size = Vector2(BUTTON_WIDTH, 0)
	return b

func _on_refocus_pressed(pair_id: String) -> void:
	var ping := get_tree().get_first_node_in_group("focus_ping")
	if ping != null:
		ping.arm(pair_id)

func _on_activate_pressed(pair_id: String) -> void:
	var bm := get_tree().get_first_node_in_group("battle_manager")
	if bm != null:
		bm.activate_ultimate(pair_id)

## Called every frame by BattleHUD._process.
func refresh() -> void:
	_refresh_ultimates()
	_refresh_refocus()

## Three Ultimate states: ULTIMATE (usable now), USED (already activated this
## level), UNAVAILABLE (unused, but nobody from the Duo is currently spawned and
## alive to cast it). A newly used button also kicks off its one-shot spend
## animation.
func _refresh_ultimates() -> void:
	var bm := get_tree().get_first_node_in_group("battle_manager")
	for pair_id in _ultimate_buttons:
		var button: Button = _ultimate_buttons[pair_id]
		if bm == null:
			button.disabled = true
			continue
		var used: bool = bm.is_ultimate_used(pair_id)
		button.disabled = not bm.can_activate_ultimate(pair_id)
		if used:
			button.text = "USED"
			if not _ultimate_spent_shown.get(pair_id, false):
				_ultimate_spent_shown[pair_id] = true
				_play_spend(button)
		elif not button.disabled:
			button.text = "ULTIMATE"
		else:
			button.text = "UNAVAILABLE"

## Four REFOCUS states: "REFOCUS" (ready), "CLICK A SPOT" (armed, waiting on the
## battlefield click), a live countdown while the marker is on the field, and
## "REFOCUSED" once it has expired — at which point the button fades away like a
## spent Ultimate. Disabled before the FocusPing exists at all (i.e. during
## deploy).
func _refresh_refocus() -> void:
	var ping := get_tree().get_first_node_in_group("focus_ping")
	for pair_id in _refocus_buttons:
		var button: Button = _refocus_buttons[pair_id]
		if ping == null:
			button.disabled = true
			continue
		var remaining: float = ping.seconds_remaining(pair_id)
		var used: bool = ping.is_used(pair_id)
		button.disabled = used
		if remaining > 0.0:
			button.text = "%.1fs" % remaining
		elif used:
			button.text = "REFOCUSED"
			# Fades on EXPIRY, not on the click that spent it: the countdown is
			# live information the player is watching, so it has to stay readable
			# until the rally window actually closes.
			if not _refocus_spent_shown.get(pair_id, false):
				_refocus_spent_shown[pair_id] = true
				_play_spend(button)
		elif ping.is_armed(pair_id):
			button.text = "CLICK A SPOT"
		else:
			button.text = "REFOCUS"

## A spent control's send-off: a quick scale pop (so the eye catches WHICH
## command was spent, alongside the centre-screen banner BattleHUD flashes for an
## Ultimate) and then a fade to a barely-there ghost. Goes fully inert too: a
## disabled Button still emits mouse_entered, which would keep firing UIStyle's
## hover wiggle on an almost-invisible control.
func _play_spend(button: Button) -> void:
	if not is_instance_valid(button):
		return
	button.disabled = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Pivot at the button's centre so the pop grows both ways rather than out of
	# its top-left corner.
	button.pivot_offset = button.size * 0.5
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2(1.06, 1.06), SPEND_POP_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, SPEND_POP_TIME)
	tween.tween_property(button, "modulate:a", SPENT_ALPHA, SPEND_FADE_TIME)
