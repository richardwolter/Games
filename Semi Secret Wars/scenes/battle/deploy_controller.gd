class_name DeployController
extends Node2D
## Pre-battle placement phase: click to place every drafted Duo inside
## LaneField's authored deploy band, then press START BATTLE to commit.
##
## Duo-aware (2026-07-20): heroes are placed as two waves — the whole Duo
## that deploys first, then the whole other Duo, which arrives
## `_delay_seconds` later. The player picks BOTH which Duo goes first (SWAP
## ORDER, locked once placement starts) and how many seconds separate them
## (the -/+ stepper, live-persisted to GameState.duo_b_delay_seconds so the
## choice carries into the next run instead of resetting — the point is to
## let the player experiment across attempts and settle on a timing that
## reads well against how the fight unfolds). If only one Duo is fielded
## (the other never got paired at prep), deploy collapses back to a single
## wave — no swap/timer UI shown.
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

var _first_is_a := true
var _delay_seconds: float = 0.0
## One click position per placed Duo group (not per hero) — see _placements_for.
var _placed: Array[Vector2] = []
var _cursor := Vector2.ZERO
var _valid := false
var _hint: Label
var _start_button: Button
var _swap_button: Button
var _delay_label: Label

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
## TimerPanel y10 centre, VillainPanel y10 right, BackButton y60, hero panels
## from y110, and BattleHUD's code-built Duo banners at y96-142) — the deploy
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

	# One paper panel for the whole cluster. Bare ink text over the drawn
	# battlefield was the visibility problem — the notebook panel gives it a
	# background to read against, same as every other HUD element.
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UIStyle.overlay_panel())
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
	col.add_theme_constant_override("separation", 14)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(col)

	_hint = UIStyle.centered_label("", UIStyle.SIZE_SUBHEAD)
	col.add_child(_hint)

	if _has_two_waves():
		var controls := HBoxContainer.new()
		controls.alignment = BoxContainer.ALIGNMENT_CENTER
		controls.add_theme_constant_override("separation", 16)
		controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(controls)

		_swap_button = UIStyle.button("", UIStyle.SIZE_SMALL, _on_swap_pressed)
		controls.add_child(_swap_button)

		controls.add_child(UIStyle.button("-1s", UIStyle.SIZE_SMALL, _on_delay_step.bind(-1.0)))

		_delay_label = UIStyle.label("", UIStyle.SIZE_BODY, UIStyle.GOLD)
		_delay_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		controls.add_child(_delay_label)

		controls.add_child(UIStyle.button("+1s", UIStyle.SIZE_SMALL, _on_delay_step.bind(1.0)))

		_update_swap_button()
		_update_delay_label()

	var start_row := CenterContainer.new()
	start_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(start_row)
	_start_button = UIStyle.button("START BATTLE", UIStyle.SIZE_SUBHEAD, _on_start_pressed)
	start_row.add_child(_start_button)

	_update_hint()

func _on_swap_pressed() -> void:
	if not _placed.is_empty():
		return  # order locks the moment placement starts
	_first_is_a = not _first_is_a
	_update_swap_button()
	_update_hint()

func _update_swap_button() -> void:
	_swap_button.text = "1ST: DUO A (swap)" if _first_is_a else "1ST: DUO B (swap)"
	_swap_button.disabled = not _placed.is_empty()

func _on_delay_step(amount: float) -> void:
	_delay_seconds = clampf(_delay_seconds + amount, GameState.DUO_B_DELAY_MIN, GameState.DUO_B_DELAY_MAX)
	GameState.set_duo_b_delay(_delay_seconds)
	_update_delay_label()

func _update_delay_label() -> void:
	_delay_label.text = "2nd Duo arrives: %ds later" % int(round(_delay_seconds))

func _all_placed() -> bool:
	return _placed.size() >= _ordered_groups().size()

func _update_hint() -> void:
	_start_button.disabled = not _all_placed()
	var groups := _ordered_groups()
	if _all_placed():
		_hint.text = "All heroes placed — press START BATTLE"
	else:
		var current: Array = groups[_placed.size()]
		var label := " + ".join(current)
		var wave := "1st wave" if _placed.size() < _first_wave_count() else "2nd wave"
		_hint.text = "DEPLOYMENT — click the band to place %s (%s, %d/%d)" % \
				[label, wave, _placed.size() + 1, groups.size()]

func _process(_delta: float) -> void:
	if field == null or not is_instance_valid(field):
		return
	_cursor = get_global_mouse_position()
	_valid = not _all_placed() and field.is_valid_deploy_point(_cursor)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if field == null or not is_instance_valid(field) or _all_placed():
		return
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var world: Vector2 = get_canvas_transform().affine_inverse() * event.position
		if field.is_valid_deploy_point(world):
			get_viewport().set_input_as_handled()
			var was_empty := _placed.is_empty()
			_placed.append(world)
			if was_empty and _has_two_waves():
				_update_swap_button()  # first click locks the swap toggle
			_update_hint()

func _on_start_pressed() -> void:
	if not _all_placed():
		return
	var groups := _ordered_groups()
	var first_count := _first_wave_count()
	var first := _flatten(groups.slice(0, first_count), _placed.slice(0, first_count))
	var second := _flatten(groups.slice(first_count, groups.size()), _placed.slice(first_count, _placed.size()))
	deploy_chosen.emit({
		"first_names": first.names,
		"first_positions": first.positions,
		"second_names": second.names,
		"second_positions": second.positions,
		"delay": _delay_seconds,
	})
	queue_free()

## Ghost sprite sizing mirrors Combatant._draw()'s sprite math (hero.tscn's
## body_radius/sprite_scale defaults — heroes don't exist yet at deploy time
## to read per-instance values from) so the preview matches the spawned size.
const GHOST_BODY_RADIUS := 22.0
const GHOST_SPRITE_SCALE := 1.8

func _draw_hero_sprite(hero_name: String, pos: Vector2, alpha: float) -> void:
	var texture := Hero.sprite_for(hero_name)
	var diameter := GHOST_BODY_RADIUS * 2.0 * GHOST_SPRITE_SCALE
	var tex_size := texture.get_size()
	var scale_factor := diameter / maxf(tex_size.x, tex_size.y)
	var draw_size := tex_size * scale_factor
	# Art faces left by default (Combatant._draw doc); heroes push right from
	# deploy, so match Combatant's moving-right flip (Vector2(-1, 1)) instead
	# of drawing the unflipped, left-facing default.
	draw_set_transform(pos, 0.0, Vector2(-1.0, 1.0))
	draw_texture_rect(texture, Rect2(-draw_size * 0.5, draw_size), false, Color(1.0, 1.0, 1.0, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw() -> void:
	var groups := _ordered_groups()
	var first_count := _first_wave_count()
	# Markers for heroes already placed, tagged with which wave they're in —
	# one click position per group, fanned out per-hero via _positions_for_group.
	for i in _placed.size():
		var group: Array = groups[i]
		var positions: Array[Vector2] = _positions_for_group(group, _placed[i])
		for j in group.size():
			draw_arc(positions[j], 16.0, 0.0, TAU, 24, Color.BLACK, 2.0, true)
			_draw_hero_sprite(group[j], positions[j], 0.7)
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
		var hero_name: String = current_group[j]
		var hero_color: Color = GameState.HERO_CATALOG[hero_name].color
		_draw_hero_sprite(hero_name, current_positions[j], pulse if _valid else pulse * 0.6)
		var font: Font = UIStyle.font() if UIStyle.font() != null else ThemeDB.fallback_font
		var size := 26
		var w := font.get_string_size(hero_name, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var at := current_positions[j] + Vector2(-w * 0.5, -48.0)
		draw_string_outline(font, at, hero_name, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color.BLACK)
		draw_string(font, at, hero_name, HORIZONTAL_ALIGNMENT_LEFT, -1, size, hero_color if _valid else c)
