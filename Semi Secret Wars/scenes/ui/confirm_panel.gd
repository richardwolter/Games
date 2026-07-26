class_name ConfirmPanel
extends CanvasLayer
## A yes/no modal in the notebook style — the one place the game asks "are you
## sure?" (Designer, 2026-07-26: confirm before abandoning a run, confirm
## before NEW GAME wipes a save).
##
## Godot's own ConfirmationDialog is a Window with the OS theme and its own
## button strings; this is a plain CanvasLayer overlay built from UIStyle, so a
## prompt looks like the rest of the game and can't be styled apart from it by
## accident.
##
## Runs at PROCESS_MODE_ALWAYS on a layer above everything (including
## LevelUpScreen at 100) because the battle prompt has to work while the tree
## is paused — a level-up pick pausing the game must not make "Back to menu"
## unanswerable.
##
## Usage: ConfirmPanel.ask(host, "TITLE", "body", "CONFIRM", callable). The
## panel frees itself on either answer; only `on_confirm` runs, on confirm.

const LAYER := 200

signal confirmed
signal cancelled

## Builds, parents and shows a prompt in one call. `host` is any node in the
## tree — the panel is added to the scene root rather than to `host`, so a
## caller that frees itself (a scene change) can't take the prompt with it.
static func ask(host: Node, title: String, body: String, confirm_text: String,
		on_confirm: Callable, cancel_text: String = "CANCEL") -> ConfirmPanel:
	var panel := ConfirmPanel.new()
	panel._title = title
	panel._body = body
	panel._confirm_text = confirm_text
	panel._cancel_text = cancel_text
	if on_confirm.is_valid():
		panel.confirmed.connect(on_confirm)
	host.get_tree().root.add_child(panel)
	return panel

var _title := ""
var _body := ""
var _confirm_text := "CONFIRM"
var _cancel_text := "CANCEL"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = LAYER
	_build()

func _build() -> void:
	# Full-screen scrim: dims what's behind AND swallows clicks, so the button
	# underneath that opened this prompt can't be pressed again while it's up.
	var scrim := ColorRect.new()
	scrim.color = Color(0.1, 0.1, 0.1, 0.55)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.add_theme_stylebox_override("panel", UIStyle.overlay_panel())
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)

	box.add_child(UIStyle.centered_label(_title, UIStyle.SIZE_HEADING, UIStyle.DANGER))
	box.add_child(UIStyle.wrapped_label(_body, 720.0, UIStyle.SIZE_BODY))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	box.add_child(row)
	# Cancel first and on the left: the safe answer is the one the hand lands
	# on, and the destructive one never sits where a reflexive click goes.
	row.add_child(UIStyle.button(_cancel_text, UIStyle.SIZE_SUBHEAD, _on_cancel))
	row.add_child(UIStyle.button(_confirm_text, UIStyle.SIZE_SUBHEAD, _on_confirm))

func _on_confirm() -> void:
	confirmed.emit()
	queue_free()

func _on_cancel() -> void:
	cancelled.emit()
	queue_free()

## Escape answers "no" — never "yes", whatever the prompt is about.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_cancel()
