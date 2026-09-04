@tool
extends EditorPlugin

## Hangs the Upgrade Forge off the bottom panel, beside Output and Debugger.
##
## Bottom rather than a side dock on purpose: a level is a list of effects laid
## out as sentences, and sentences need width.

const DockScript := preload("res://addons/upgrade_forge/upgrade_dock.gd")

const MENU_ITEM := "Upgrade Forge (item upgrades)"

var _dock: Control


func _enter_tree() -> void:
	_dock = DockScript.new()
	_dock.name = "Upgrade Forge"
	add_control_to_bottom_panel(_dock, "Upgrade Forge")
	# Second way in. The bottom bar is a row of small buttons that is easy to
	# miss, and this is a tool someone opens once a fortnight to write content.
	add_tool_menu_item(MENU_ITEM, _open)


func _exit_tree() -> void:
	remove_tool_menu_item(MENU_ITEM)
	if _dock != null:
		remove_control_from_bottom_panel(_dock)
		_dock.queue_free()
		_dock = null


func _open() -> void:
	if _dock != null:
		make_bottom_panel_item_visible(_dock)
