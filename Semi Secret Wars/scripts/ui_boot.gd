extends Node
## Autoload that guarantees the notebook theme + handwritten font are live on
## every Control, whatever route the scene took to get on screen.
##
## project.godot's gui/theme/custom already assigns assets/ui/notebook_theme.tres
## to the tree root, which is enough on its own in a normal run. This exists for
## the two cases it doesn't cover:
##   - the theme resource fails to load (e.g. the .ttf hasn't been imported yet
##     on a fresh checkout), leaving the game on Godot's default sans;
##   - the font file is added/replaced without the theme being re-saved.
## Both are silent visual regressions rather than errors, which is exactly the
## kind of drift this whole pass is meant to stop, so we re-assert here.

const THEME_PATH := "res://assets/ui/notebook_theme.tres"

## True only when we assigned root.theme ourselves — see _exit_tree.
var _owns_root_theme := false

func _ready() -> void:
	var root := get_tree().root
	if root.theme == null and ResourceLoader.exists(THEME_PATH):
		root.theme = load(THEME_PATH)
		_owns_root_theme = true
	if root.theme != null and root.theme.default_font == null:
		var f := UIStyle.font()
		if f != null:
			root.theme.default_font = f
			root.theme.default_font_size = UIStyle.SIZE_BODY

## Autoloads outlive the rest of the tree, so a Theme parked on root.theme is
## still referenced when the engine runs its final ObjectDB sweep and gets
## reported as a leak at exit. Harmless in itself, but it buries real leaks in
## the same message, so drop the reference we added.
func _exit_tree() -> void:
	if not _owns_root_theme:
		return
	var root := get_tree().root if get_tree() != null else null
	if root != null:
		root.theme = null
