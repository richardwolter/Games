class_name TutorialDirector
extends CanvasLayer
## The tutorial's voice: a queue of freeze-and-explain popups (Designer,
## 2026-07-31: "we can freeze the game to explain important information, so
## players dont miss out on important mechanics").
##
## One director instance plays one queue of steps and frees itself. Callers hand
## it an Array of step Dictionaries and an optional `on_done`:
##
##   TutorialDirector.run(self, [
##       {"title": "DUO", "body": "...", "focus": some_control},
##   ], _on_intro_done)
##
## Step keys, all optional but `body`:
##   title   heading line (omit for a bodies-only beat)
##   body    the explanation itself
##   button  label on the advance button (default NEXT; the last step's default
##           is GOT IT — see _button_text)
##   focus   a Control to spotlight: the dim leaves its rect bright and the
##           popup moves to the opposite half of the screen so it can't cover
##           the thing being pointed at
##   align   "top"/"bottom"/"center", overriding the automatic placement above
##   portraits  Array of hero names drawn as a row of real portraits (the
##           Warden + Beacon reveal), using the same art the field uses
##
## Construction follows ConfirmPanel exactly — scrim + UIStyle overlay panel on
## a CanvasLayer, PROCESS_MODE_ALWAYS — because this has the same job: be
## readable and clickable while the tree behind it is frozen. Godot's own
## dialogs are OS-themed Windows and would look like a different game.
##
## FREEZE: the director pauses the tree while a queue is up and unpauses when
## the queue drains. It records the tree's pause state on entry and restores
## THAT, so a queue shown over an already-paused screen (the post-loss beat,
## which fires from BattleManager._end) doesn't hand control back early.

## Above LevelUpScreen (100) and the deploy UI (40) — while the tutorial is
## talking it is the only thing the player can act on. Below ConfirmPanel (200),
## which is what the SKIP button opens on top of this.
const LAYER := 190
const GROUP := "tutorial_director"

## Deliberately small (Designer, 2026-07-31: "try to make all pop up cards
## smaller") — a tutorial card is a caption on the game, not a page of it.
const PANEL_WIDTH := 520.0
## Keep-out from the screen edges when the card is parked or clamped.
const EDGE_MARGIN := 40.0
## Gap between the card and the thing it points at.
const FOCUS_GAP := 24.0
## Hero art on a card that shows portraits — smaller than the prep/HOW TO PLAY
## boxes, since these sit inside a deliberately small card.
const PORTRAIT_BOX := Vector2(96, 78)

## Dim over everything except a spotlit control. Lighter than ConfirmPanel's
## 0.55 scrim: the player is being asked to LOOK at the battlefield/menu behind
## this, not just to answer a question about it.
const SCRIM := Color(0.1, 0.1, 0.1, 0.45)
## Outline drawn around a spotlit control so the eye lands on it immediately.
const SPOTLIGHT_PAD := 10.0
const SPOTLIGHT_WIDTH := 4.0

signal finished

var _steps: Array = []
var _index := 0
var _was_paused := false
var _panel: Control = null
var _spotlight: _Spotlight = null
## The current step's spotlit control, re-measured every frame — see _process.
var _focus: Control = null
## Step asked for dead-centre placement regardless of any focus.
var _force_center := false

## Builds, parents and starts a queue in one call. `host` is any node in the
## tree; like ConfirmPanel the director parents to the scene ROOT, so a caller
## that frees itself (a scene change, a dying battle manager) can't take the
## explanation with it.
static func run(host: Node, steps: Array, on_done: Callable = Callable()) -> TutorialDirector:
	var d := TutorialDirector.new()
	d._steps = steps
	if on_done.is_valid():
		d.finished.connect(on_done)
	host.get_tree().root.add_child(d)
	return d

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = LAYER
	add_to_group(GROUP)
	_was_paused = get_tree().paused
	get_tree().paused = true
	_spotlight = _Spotlight.new()
	_spotlight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_spotlight.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_spotlight)
	_show_step()

func _show_step() -> void:
	if _index >= _steps.size():
		_finish()
		return
	var step: Dictionary = _steps[_index]
	if _panel != null and is_instance_valid(_panel):
		_panel.queue_free()
	_focus = step.get("focus", null)
	# "center" still means "ignore the focus and sit dead centre" — the reveal
	# beats use it, where the card IS the content and there's nothing to point at.
	_force_center = String(step.get("align", "")) == "center"
	_spotlight.focus_rect = _focus_rect(_focus)
	_spotlight.queue_redraw()
	_panel = _build_panel(step, _spotlight.focus_rect)
	add_child(_panel)

## The spotlight follows its control every frame rather than being measured once
## at show time. Two reasons, both real: the DUO CONTROL panel is repositioned
## by BattleHUD every frame (see its _place_duo_control), and a prep-tour step
## reveals a hidden section immediately before spotlighting it, so the container
## has not laid out yet on the frame the step opens.
func _process(_delta: float) -> void:
	if _spotlight == null:
		return
	var r := _focus_rect(_focus)
	if r != _spotlight.focus_rect:
		_spotlight.focus_rect = r
		_spotlight.queue_redraw()
	_position_panel()

## Screen rect of a spotlit control, or a zero rect when the step has no focus
## (nothing is cut out of the dim). A control that isn't in the tree or is
## hidden spotlights nothing rather than pointing at a stale rectangle.
func _focus_rect(focus: Control) -> Rect2:
	if focus == null or not is_instance_valid(focus) or not focus.is_visible_in_tree():
		return Rect2()
	return focus.get_global_rect().grow(SPOTLIGHT_PAD)

func _build_panel(step: Dictionary, focus_rect: Rect2) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.overlay_panel())
	_place(panel, step, focus_rect)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := String(step.get("title", ""))
	if title != "":
		box.add_child(UIStyle.centered_label(title,
				int(step.get("title_size", UIStyle.SIZE_SUBHEAD)),
				step.get("title_color", UIStyle.EMBER)))

	var portraits: Array = step.get("portraits", [])
	if not portraits.is_empty():
		box.add_child(_portrait_row(portraits))

	# A card can be title-only (the summon beat) — an empty label would just add
	# a band of dead paper under the heading.
	var body := String(step.get("body", ""))
	if body != "":
		box.add_child(UIStyle.wrapped_label(body, PANEL_WIDTH - 60.0, UIStyle.SIZE_SMALL))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	row.add_child(UIStyle.button(_button_text(step), UIStyle.SIZE_SMALL, _advance))
	# Every popup carries the exit (Designer, 2026-07-31) — a replayer or a
	# tester must never be trapped in the tutorial. Behind a confirm, since
	# skipping hands out the whole roster and can't be walked back.
	#
	# Opt-out for beats where the offer would be absurd: by the summon card the
	# tutorial battle is already over and there is nothing left to skip past.
	if not bool(step.get("no_skip", false)):
		row.add_child(UIStyle.compact_button("SKIP TUTORIAL", UIStyle.SIZE_TINY, _ask_skip))
	return panel

## NEXT while there's more to say, GOT IT on the last step — so the final click
## of a beat doesn't promise a screen that isn't coming. An explicit "button"
## on the step wins over both.
func _button_text(step: Dictionary) -> String:
	if step.has("button"):
		return String(step["button"])
	return "GOT IT" if _index == _steps.size() - 1 else "NEXT"

## Sizes the card. WHERE it goes is decided every frame in _position_panel,
## because the card's own height isn't known until the container has laid out.
func _place(panel: PanelContainer, _step: Dictionary, _focus_rect: Rect2) -> void:
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.grow_horizontal = Control.GROW_DIRECTION_END
	panel.grow_vertical = Control.GROW_DIRECTION_END
	# Off-screen until positioned, so a card never flashes at the origin on the
	# frame it's built.
	panel.position = Vector2(-9999, -9999)

## Puts the card BESIDE what it points at — horizontally centred on the focus,
## directly under it when there's room, above it otherwise — and dead centre
## when a step has no focus (Designer, 2026-07-31: "UI positioning should be
## more centered and point to what it is talking about").
##
## This replaced anchor presets, which were the reason cards hung off the screen:
## PRESET_CENTER_BOTTOM with grow BOTH centres the panel ON the bottom edge, so
## half of every bottom-aligned card was below the screen.
func _position_panel() -> void:
	if _panel == null or not is_instance_valid(_panel):
		return
	var view := get_viewport().get_visible_rect().size
	var card := _panel.size
	var f := _spotlight.focus_rect
	var pos := (view - card) * 0.5
	if f.size != Vector2.ZERO and not _force_center:
		pos.x = f.get_center().x - card.x * 0.5
		if f.end.y + FOCUS_GAP + card.y <= view.y - EDGE_MARGIN:
			pos.y = f.end.y + FOCUS_GAP
		elif f.position.y - FOCUS_GAP - card.y >= EDGE_MARGIN:
			pos.y = f.position.y - FOCUS_GAP - card.y
		else:
			# Neither above nor below fits (a tall target): sit beside it, on
			# whichever side has more room.
			pos.y = clampf(f.get_center().y - card.y * 0.5, EDGE_MARGIN,
					maxf(EDGE_MARGIN, view.y - card.y - EDGE_MARGIN))
			pos.x = (f.position.x - FOCUS_GAP - card.x) if f.get_center().x > view.x * 0.5 \
					else (f.end.x + FOCUS_GAP)
	pos.x = clampf(pos.x, EDGE_MARGIN, maxf(EDGE_MARGIN, view.x - card.x - EDGE_MARGIN))
	pos.y = clampf(pos.y, EDGE_MARGIN, maxf(EDGE_MARGIN, view.y - card.y - EDGE_MARGIN))
	_panel.position = pos

## The real hero art, same source the field and HOW TO PLAY use — a player must
## recognise Warden and Beacon on the battlefield because they met this exact
## drawing here.
func _portrait_row(hero_names: Array) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	for hero_name in hero_names:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col.add_child(UIStyle.hero_portrait(String(hero_name), PORTRAIT_BOX))
		var color: Color = GameState.HERO_CATALOG.get(hero_name, {}).get("color", UIStyle.INK)
		col.add_child(UIStyle.centered_label(String(hero_name), UIStyle.SIZE_TINY, color))
		row.add_child(col)
	return row

func _advance() -> void:
	_index += 1
	_show_step()

func _ask_skip() -> void:
	ConfirmPanel.ask(self, "SKIP TUTORIAL",
			"Skip the tutorial? Warden and Beacon join immediately and you go "
			+ "straight to the prep menu. You can't replay it without starting a new game.",
			"Skip It", _do_skip, "Keep Playing")

func _do_skip() -> void:
	# Tutorial.skip() changes scene, which frees this director with the scene it
	# was parented beside — but the root outlives the change, so it has to go
	# explicitly or the popup would sit over the prep menu.
	queue_free()
	get_tree().paused = false
	Tutorial.skip()

func _finish() -> void:
	get_tree().paused = _was_paused
	finished.emit()
	queue_free()

## The dim, with a hole cut for the spotlit control. Drawn as four rects around
## the focus rather than with a mask/shader: the focused control keeps its own
## real colours (a shader dim over the whole screen would wash it out too), and
## there is nothing to keep in sync with the theme.
class _Spotlight extends Control:
	var focus_rect := Rect2()

	func _draw() -> void:
		var full := Rect2(Vector2.ZERO, size)
		if focus_rect.size == Vector2.ZERO:
			draw_rect(full, TutorialDirector.SCRIM)
			return
		var f := focus_rect
		# Above / below the hole, then the two side strips beside it.
		draw_rect(Rect2(0, 0, size.x, f.position.y), TutorialDirector.SCRIM)
		draw_rect(Rect2(0, f.end.y, size.x, size.y - f.end.y), TutorialDirector.SCRIM)
		draw_rect(Rect2(0, f.position.y, f.position.x, f.size.y), TutorialDirector.SCRIM)
		draw_rect(Rect2(f.end.x, f.position.y, size.x - f.end.x, f.size.y), TutorialDirector.SCRIM)
		draw_rect(f, UIStyle.EMBER, false, TutorialDirector.SPOTLIGHT_WIDTH)
