class_name DeployController
extends Node2D
## Pre-battle placement phase: click to place every drafted Duo inside
## LaneField's authored deploy band, then press START BATTLE to commit.
##
## Duo-aware (2026-07-20): heroes are placed as two waves — the whole Duo
## that deploys first, then the whole other Duo, which arrives
## `_delay_seconds` later, set on the -/+ stepper (live-persisted to
## GameState.duo_b_delay_seconds so the choice carries into the next run
## instead of resetting — the point is to let the player experiment across
## attempts and settle on a timing that reads well against how the fight
## unfolds). 0s means both Duos land together. If only one Duo is fielded (the
## other never got paired at prep), deploy collapses back to a single wave —
## no timer UI shown.
##
## This phase now runs BEFORE the Ultimate-boon picks (Designer, 2026-07-26):
## place, set the timing, press START BATTLE, and only then choose boons — with
## a delayed Duo's pick held until it actually arrives. See
## BattleManager._on_deploy_chosen / _spawn_second_wave.
##
## One click per Duo, not per hero (Designer, 2026-07-21: "no need to deploy
## each of the Duo's heroes" — pairing is already enforced everywhere else
## in battle, deploy was the one place still treating them as independent
## units): a click places every living member of the current Duo together,
## offset side-by-side around the clicked point (see PAIR_OFFSET), instead
## of asking for a separate click per hero.
##
## One-shot — there is no mid-battle respawn (Designer, 2026-07-19): a hero
## that dies mid-battle is permanently down for the run (see
## BattleManager._on_hero_died).
##
## Camera controls (wheel zoom, edge/WASD pan) stay live during placement,
## so the player can scout the lane before committing.

signal deploy_chosen(payload: Dictionary)

## Injected by BattleManager before entering the tree. Each is 0, 1, or 2
## hero names — empty when that Duo never got paired at prep.
var field: LaneField
var duo_a: Array = []
var duo_b: Array = []

## Half the left/right spacing between two paired heroes placed on the same
## click (one PAIR_OFFSET left of the click, one right of it) — comfortably
## inside the Duo chain leash (hero.gd DUO_LEASH_DIST 90) so they start well
## within it, but far enough apart to read as two distinct heroes rather
## than a stacked pair.
const PAIR_OFFSET := 35.0

## Duo A always places first now that the SWAP ORDER button is gone (Designer,
## 2026-07-26) — placement order expresses the choice, so the toggle was a
## second control for the same decision. Kept as a constant-in-spirit variable
## so _ordered_groups keeps reading in the order it always did.
var _first_is_a := true
var _delay_seconds: float = 0.0
## One click position per placed Duo group (not per hero) — see _placements_for.
var _placed: Array[Vector2] = []
var _cursor := Vector2.ZERO
var _valid := false
var _start_button: Button
var _delay_label: RichTextLabel
var _ui_layer: CanvasLayer

## True once START BATTLE has been pressed. The node deliberately outlives that
## press (Designer, 2026-07-26): the boon picks come next, and while they're up
## the placed hero sprites stay on the field marking where everyone will land —
## so the player chooses upgrades looking at their actual formation instead of
## an empty lane. Its own UI hides, input stops, and BattleManager frees it
## through finish() once every wave has really spawned.
var _committed := false
## Heroes that have now spawned for real, so their placement marker stops being
## drawn — the live unit is standing there instead.
var _spawned_names: Array = []

func _ready() -> void:
	z_index = 40
	_delay_seconds = clampf(GameState.duo_b_delay_seconds, GameState.DUO_B_DELAY_MIN, GameState.DUO_B_DELAY_MAX)
	_build_ui()

func _has_two_waves() -> bool:
	return not duo_a.is_empty() and not duo_b.is_empty()

## The full placement order: whichever Duo is "first" goes first. Each
## element is a Duo group (an Array of 1-2 hero names) placed together with
## a single click, not a single hero name.
func _ordered_groups() -> Array:
	var groups: Array = []
	for g in ([duo_a, duo_b] if _first_is_a else [duo_b, duo_a]):
		if not g.is_empty():
			groups.append(g)
	return groups

func _first_wave_count() -> int:
	# Single-wave case (one Duo never got paired at prep, or both collapsed
	# into one group): everyone deploys in the one and only wave — there's
	# no "second wave" to hold back.
	if not _has_two_waves():
		return _ordered_groups().size()
	return 1

## Per-hero placement positions for one Duo group's click position — a lone
## hero deploys exactly on the click; a pair spreads left/right around it
## (one PAIR_OFFSET to either side) so they don't spawn stacked on top of
## each other. The leader deploys in front (right, toward the villain down
## the lane); the follower deploys behind (left) — matches the leader/
## follower push dynamic already live in battle (Designer, 2026-07-21:
## "leader should be in front (right) and supporter in back (left) on
## deploy"). Falls back to group order (no swap) if neither hero in a
## same-click pair reads as a confirmed Duo leader (e.g. a stale/invalid
## pairing that _compute_duos folded into one group anyway).
func _positions_for_group(group: Array, click: Vector2) -> Array[Vector2]:
	if group.size() < 2:
		return [click] as Array[Vector2]
	var offset := Vector2(PAIR_OFFSET, 0.0)
	if GameState.is_duo_leader(group[0]):
		return [click + offset, click - offset] as Array[Vector2]
	return [click - offset, click + offset] as Array[Vector2]

## Flattened hero names/positions across every placed group, in order —
## deploy_chosen's payload (and BattleManager) still work per-hero. `clicks`
## must line up 1:1 with `groups` (e.g. a slice of _placed matching a slice
## of _ordered_groups()) — indexing _placed directly by a slice-local index
## here previously reused the FIRST wave's click positions for the second
## wave too, since a slice's local index restarts at 0.
func _flatten(groups: Array, clicks: Array[Vector2]) -> Dictionary:
	var names: Array = []
	var positions: Array = []
	for i in groups.size():
		var group: Array = groups[i]
		var group_positions: Array[Vector2] = _positions_for_group(group, clicks[i])
		for j in group.size():
			names.append(group[j])
			positions.append(group_positions[j])
	return {"names": names, "positions": positions}

## Where the deploy cluster sits in the 1920x1080 design canvas. The top of
## the screen is fully occupied by the battle HUD (RunXP/Gold at y10 left,
## TimerPanel y10 centre, VillainPanel y10 right, BackButton/SETTINGS y60, hero
## panels from y140, and BattleHUD's code-built Duo banners at y96-142) — the deploy
## controls used to be drawn as bare text at y24/64/104, straight into that
## stack, which is why they were unreadable and got covered (Designer,
## 2026-07-25). The bottom band is clear during placement.
const PANEL_BOTTOM_MARGIN := 150.0
## Above BattleHUD (its CanvasLayer is the default layer 0) but below
## LevelUpScreen's modal overlay at layer 100, so a start-of-level boon pick
## still takes precedence over the deploy chrome behind it.
const DEPLOY_LAYER := 60

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = DEPLOY_LAYER
	add_child(layer)
	_ui_layer = layer

	# One paper panel for the whole cluster. Bare ink text over the drawn
	# battlefield was the visibility problem — the notebook panel gives it a
	# background to read against, same as every other HUD element.
	var frame := PanelContainer.new()
	# Slimmer than the shared overlay_panel (margin 40 -> 14): this panel sits
	# ON the deploy band the player is trying to click into, and at full modal
	# padding it was covering too much of it (Designer, 2026-07-26). Same
	# paper/ink/wobble, just tighter.
	frame.add_theme_stylebox_override("panel", UIStyle.panel(UIStyle.PAGE, UIStyle.INK, 4, 14))
	frame.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	frame.grow_horizontal = Control.GROW_DIRECTION_BOTH
	frame.grow_vertical = Control.GROW_DIRECTION_BEGIN
	frame.position.y = -PANEL_BOTTOM_MARGIN
	# The panel overlays the field, and placement is a click on the field —
	# so the background must not eat clicks. Buttons inside still receive
	# theirs (they set their own filter), and _unhandled_input only ever sees
	# what no Control consumed.
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(frame)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(col)

	# The whole explanation of this phase, in one fixed line. The old per-Duo
	# "DEPLOYMENT — click the band to place X (1st wave, 1/2)" prompt under it
	# was removed (Designer, 2026-07-26): it restated what the cursor ghost
	# already shows, and the START BATTLE button enabling is a clearer "you are
	# done" than a line of text saying so.
	col.add_child(UIStyle.wrapped_label(
			"Deploy DUO's on designated lane — one DUO per lane. You can choose if the 2nd DUO arrives later (0s is immediate deploy).",
			760.0, UIStyle.SIZE_SMALL))

	# Single-lane levels (a Duo was wiped earlier in the run — see
	# LaneField.single_lane) play by different rules than the player has been
	# taught, so say so up front rather than letting them discover that lane
	# discipline stopped mattering.
	if field != null and field.single_lane:
		col.add_child(UIStyle.centered_label(
				"SINGLE LANE — your Duo holds the whole field", UIStyle.SIZE_SMALL, UIStyle.GOLD))

	if _has_two_waves():
		var controls := HBoxContainer.new()
		controls.alignment = BoxContainer.ALIGNMENT_CENTER
		controls.add_theme_constant_override("separation", 16)
		controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(controls)

		# The SWAP ORDER button is gone (Designer, 2026-07-26). Which Duo goes
		# first is already expressed by the order they're placed in, so the
		# button was a second control for a choice the player was making anyway.
		controls.add_child(UIStyle.button("-1s", UIStyle.SIZE_TINY, _on_delay_step.bind(-1.0)))

		_delay_label = UIStyle.numeric_label("", UIStyle.SIZE_SMALL, UIStyle.GOLD)
		_delay_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		controls.add_child(_delay_label)

		controls.add_child(UIStyle.button("+1s", UIStyle.SIZE_TINY, _on_delay_step.bind(1.0)))

		_update_delay_label()

	var start_row := CenterContainer.new()
	start_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(start_row)
	_start_button = UIStyle.button("START BATTLE", UIStyle.SIZE_BODY, _on_start_pressed)
	start_row.add_child(_start_button)

	_update_hint()

func _on_delay_step(amount: float) -> void:
	_delay_seconds = clampf(_delay_seconds + amount, GameState.DUO_B_DELAY_MIN, GameState.DUO_B_DELAY_MAX)
	GameState.set_duo_b_delay(_delay_seconds)
	_update_delay_label()

func _update_delay_label() -> void:
	UIStyle.set_numeric_text(_delay_label, "2nd Duo arrives: %ds later" % int(round(_delay_seconds)))

## One Duo per lane (Designer, 2026-07-27): the two Duos must split top/bottom,
## so a point in a lane that already holds a placed Duo is not a legal deploy
## spot. Only meaningful when two Duos are actually being fielded — on
## single_lane levels (a Duo was wiped, LaneField.single_lane) there is only one
## group to place and the lane divider no longer applies.
func _lane_taken(p: Vector2) -> bool:
	if field == null or field.single_lane or not _has_two_waves():
		return false
	var lane := field.lane_of(p)
	for placed in _placed:
		if field.lane_of(placed) == lane:
			return true
	return false

## A point is placeable if it's inside the authored deploy band AND its lane is
## still free — both gates, so the cursor ghost's red X and the click handler
## can't disagree about what's legal.
func _can_place_at(p: Vector2) -> bool:
	return field.is_valid_deploy_point(p) and not _lane_taken(p)

func _all_placed() -> bool:
	return _placed.size() >= _ordered_groups().size()

## START BATTLE only unlocks once every Duo has a spot. That enable/disable IS
## the progress readout now that the running "place X next" line is gone.
func _update_hint() -> void:
	_start_button.disabled = not _all_placed()

func _process(_delta: float) -> void:
	if field == null or not is_instance_valid(field):
		return
	if _committed:
		return  # placement is locked in; only the markers are still drawn
	_cursor = get_global_mouse_position()
	_valid = not _all_placed() and _can_place_at(_cursor)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if _committed or field == null or not is_instance_valid(field) or _all_placed():
		return
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var world: Vector2 = get_canvas_transform().affine_inverse() * event.position
		if _can_place_at(world):
			get_viewport().set_input_as_handled()
			_placed.append(world)
			_update_hint()

func _on_start_pressed() -> void:
	if not _all_placed():
		return
	var groups := _ordered_groups()
	var first_count := _first_wave_count()
	var first := _flatten(groups.slice(0, first_count), _placed.slice(0, first_count))
	var second := _flatten(groups.slice(first_count, groups.size()), _placed.slice(first_count, _placed.size()))
	# Hide the panel but stay alive — see _committed. BattleManager spawns the
	# first wave only after its boon picks resolve and calls finish() when the
	# last wave has landed.
	_committed = true
	if _ui_layer != null:
		_ui_layer.visible = false
	queue_redraw()
	deploy_chosen.emit({
		"first_names": first.names,
		"first_positions": first.positions,
		"second_names": second.names,
		"second_positions": second.positions,
		"delay": _delay_seconds,
	})

## Stops drawing markers for heroes that have now really spawned.
func mark_spawned(names: Array) -> void:
	for n in names:
		if n not in _spawned_names:
			_spawned_names.append(n)
	queue_redraw()

## Called by BattleManager once every wave is on the field.
func finish() -> void:
	queue_free()

## Ghost sprite sizing mirrors Combatant._draw()'s sprite math (hero.tscn's
## body_radius/sprite_scale defaults — heroes don't exist yet at deploy time
## to read per-instance values from) so the preview matches the spawned size.
##
## The base scale alone is NOT the spawned size: Hero._configure multiplies
## sprite_scale by its per-hero SPRITE_SCALE_MULT entry (1.55-2.34, the
## padding compensation for the *_Color art), so a ghost drawn at the raw 1.8
## came out 35-57% smaller than the hero that then walked out of it (Designer,
## 2026-07-26: "DUO deploy sprites should be the same size as real moving
## ones"). Applying the same multiplier here is what keeps the two in step;
## both sides read the one table in hero.gd, so a future art swap can't
## desync them again.
const GHOST_BODY_RADIUS := 22.0
const GHOST_SPRITE_SCALE := 1.8

func _ghost_scale(hero_name: String) -> float:
	return GHOST_SPRITE_SCALE * float(Hero.SPRITE_SCALE_MULT.get(hero_name, 1.0))

## Art faces left by default (Combatant._draw doc); heroes push right from
## deploy, so this matches Combatant's moving-right flip rather than drawing
## the unflipped, left-facing default.
const GHOST_ART_DIR := -1.0

## Draws a hero exactly as Combatant._draw would: ground shadow first, then the
## sprite over it, through the same BattleFX helpers the live unit uses. The
## ONLY thing that may differ is `alpha` — a hero being placed isn't on the
## field yet, so the cursor ghost stays translucent and pulsing. Everything
## else (size, flip, shadow shape and offset) is shared code, not a copy of the
## math, so the preview can't drift from the spawned hero again.
func _draw_hero_sprite(hero_name: String, pos: Vector2, alpha: float) -> void:
	var texture := Hero.sprite_for(hero_name)
	var scale := _ghost_scale(hero_name)
	BattleFX.draw_unit_shadow(self, texture, pos, GHOST_BODY_RADIUS, scale, alpha)
	BattleFX.draw_unit_sprite(self, texture, pos, GHOST_BODY_RADIUS, scale, GHOST_ART_DIR, alpha)

func _draw() -> void:
	var groups := _ordered_groups()
	var first_count := _first_wave_count()
	# Markers for heroes already placed, tagged with which wave they're in —
	# one click position per group, fanned out per-hero via _positions_for_group.
	for i in _placed.size():
		var group: Array = groups[i]
		var positions: Array[Vector2] = _positions_for_group(group, _placed[i])
		for j in group.size():
			# Once a hero has really spawned its marker goes — the live unit is
			# standing on that spot now, and two of it would read as a bug.
			if group[j] in _spawned_names:
				continue
			# A placed hero is drawn exactly as it will look once the battle
			# starts: full opacity, no marker ring under it (Designer,
			# 2026-07-26). The old translucent-with-a-black-ring treatment made
			# the committed placement read as a different unit from the one that
			# then spawned there; the ground shadow is what anchors it now, the
			# same as every other unit on the field.
			_draw_hero_sprite(group[j], positions[j], 1.0)
			if _has_two_waves():
				var tag := "1ST" if i < first_count else "2ND"
				var font: Font = UIStyle.font() if UIStyle.font() != null else ThemeDB.fallback_font
				var w := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
				var at := positions[j] + Vector2(-w * 0.5, 30.0)
				draw_string_outline(font, at, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, Color.BLACK)
				draw_string(font, at, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	if _all_placed():
		return
	# Ghost marker(s) under the cursor for the Duo being placed next — a
	# pulsing translucent silhouette of the hero's real sprite, so it reads
	# as "not yet real" rather than a solid double of the spawned hero.
	var current_group: Array = groups[_placed.size()]
	var current_positions: Array[Vector2] = _positions_for_group(current_group, _cursor)
	var c := (Color.WHITE if _valid else Color(0.75, 0.2, 0.2))
	var pulse := 0.35 + 0.15 * sin(Time.get_ticks_msec() / 180.0)
	draw_arc(_cursor, 40.0, 0.0, TAU, 32, c, 4.0, true)
	draw_circle(_cursor, 6.0, c)
	if not _valid:
		draw_line(_cursor + Vector2(-24, -24), _cursor + Vector2(24, 24), c, 4.0, true)
		draw_line(_cursor + Vector2(-24, 24), _cursor + Vector2(24, -24), c, 4.0, true)
	for j in current_group.size():
		# No floating hero name over the ghost: field units carry no name labels
		# (Combatant._draw, Designer 2026-07-25), and the hint line above already
		# says which Duo is being placed — so the name only existed here, on the
		# one unit that isn't real yet.
		_draw_hero_sprite(current_group[j], current_positions[j], pulse if _valid else pulse * 0.6)
