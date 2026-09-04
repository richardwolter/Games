## The start menu: the key art, and the two things you can do.
##
## If TITLE_ART exists it is the whole screen — it carries its own logo, so the
## drawn LogoTitle lockup stands down and the menu is just buttons over the
## bottom of the picture. Without it the screen falls back to assembling itself
## from art/background.png plus the drawn lockup, which is what shipped before
## the painted art existed and is still what runs if the file goes missing.
extends Control

const MAIN_SCENE := "res://scenes/main.tscn"
## Where CONTINUE and NEW GAME both go: the player picks a strait before the game
## scene is built, so nothing has to be torn down and reloaded if they change
## their mind. The headless checks still jump straight to MAIN_SCENE, which is
## why both constants live here.
const SELECT_SCENE := "res://scenes/level_select.tscn"
## How tall the menu signs are drawn. Big enough to read as the painted objects
## they are, small enough to stay in the band of open water along the bottom
## without reaching up into the truck.
const BUTTON_HEIGHT := 78.0
## Clear space either side of the middle sign.
const SIGN_GAP := 90.0
## Painted key art for the menu. One image, carrying its own title lockup.
const TITLE_ART := "res://art/title_screen.jpg"

## The new-game confirmation, while it's up. It owns the keyboard until dismissed.
var _modal: Control
## True when the painted art is in use, which changes how the menu is laid out.
var _has_art: bool = false


func _ready() -> void:
	# The headless checks in main.gd drive the game scene directly and have no
	# way to press a button, so the menu steps out of their way.
	var args := OS.get_cmdline_user_args()
	if args.has("--smoke") or args.has("--carcheck"):
		get_tree().change_scene_to_file.call_deferred(MAIN_SCENE)
		return

	# The menu plays the music of the level the player would resume into, so
	# Continue is scored by where they actually are rather than by where the game
	# begins. With no save this is level 1's theme, which is also correct.
	var audio := get_node_or_null(^"/root/Audio")
	if audio != null:
		audio.set_level_music(SaveGame.saved_level())

	theme = UITheme.build()
	_has_art = ResourceLoader.exists(TITLE_ART)
	_build_backdrop()
	if not _has_art:
		_build_logo()
	_build_menu()
	UITheme.enliven(self)


func _build_backdrop() -> void:
	if _has_art:
		var art := TextureRect.new()
		art.texture = load(TITLE_ART) as Texture2D
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# Cover rather than fit: letterbox bars around painted key art look like
		# a bug, and losing a little off the edges of a deliberately loose
		# composition does not.
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(art)

		# A scrim under the buttons only. The art runs edge to edge and the
		# bottom of it is busy, so without this the button row competes with
		# whatever happens to be painted behind it.
		var scrim := TextureRect.new()
		scrim.texture = _fade_to_bottom()
		scrim.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		scrim.offset_top = -170.0
		scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		scrim.stretch_mode = TextureRect.STRETCH_SCALE
		scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(scrim)
		return

	var sky := TextureRect.new()
	sky.texture = load("res://art/background.png") as Texture2D
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Cover, not fit: an empty band above or below the backdrop would be the
	# first thing the player ever sees.
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)

	# A water band along the bottom, so the logo's bridge has something to span.
	var water := ColorRect.new()
	water.color = Color("3e5c8c")
	water.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	water.offset_top = -170.0
	water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(water)


## A 1px-wide gradient, transparent at the top and near-opaque ink at the
## bottom, stretched across the button band. Built in code so there is no
## gradient asset to keep in sync with the palette.
func _fade_to_bottom() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(UITheme.INK, 0.0))
	gradient.set_color(1, Color(UITheme.INK, 0.72))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	texture.width = 1
	texture.height = 64
	return texture


func _build_logo() -> void:
	var logo := LogoTitle.new()
	logo.unit = 78.0
	# Centred horizontally, sitting in the upper half — the menu takes the lower.
	logo.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	logo.grow_horizontal = Control.GROW_DIRECTION_BOTH
	logo.position = Vector2(0, 40)
	add_child(logo)


func _build_menu() -> void:
	# One shallow row along the very bottom. Stacked in the middle of the picture
	# the signs sat on top of the truck and the crate raft — the art's focal
	# point — so they are spread sideways into the strip of open water instead,
	# where the composition carries nothing.
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.offset_bottom = -18.0
	column.add_theme_constant_override(&"separation", 10)
	column.alignment = BoxContainer.ALIGNMENT_END
	add_child(column)

	# With a save present, resuming is the default action and gets the big
	# button; starting over is the deliberate one and has to be asked for.
	var resuming := SaveGame.has_save()

	# Without a save there is nothing to continue, so NEW GAME takes the middle
	# slot instead. The signs say the right thing either way, which is why there
	# is no "START BUILDING" artwork.
	#
	# All three on one line, pinned to a common HEIGHT rather than a common
	# width. In a row the eye compares heights, so that is the axis to fix — and
	# it lets CONTINUE come out naturally widest, which is the primacy it wants
	# without needing to be drawn any taller than its neighbours.
	# The main action is centred on the SCREEN, not centred as part of the group.
	#
	# A plain centred row centres the three signs together, and since they are
	# different widths that leaves the one button the player is actually going to
	# press sitting off to one side of the settings plate and the F11 line
	# underneath it. Two equally-expanding side slots put the middle sign exactly
	# on the centre line whatever its neighbours weigh, and the neighbours hang
	# off it — the outer two are the ones that can afford to be asymmetric.
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 0)
	column.add_child(row)

	var left := HBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(left)

	var play := UITheme.art_button(
		"continue" if resuming else "new_game", BUTTON_HEIGHT
	)
	play.pressed.connect(_on_play_pressed)
	row.add_child(play)

	var right := HBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_child(right)

	# With a save, NEW GAME balances QUIT on the far side; without one there is
	# nothing to put there and the left slot simply stays empty, which keeps the
	# middle sign on the centre line either way.
	if resuming:
		var fresh := UITheme.art_button("new_game", BUTTON_HEIGHT)
		fresh.pressed.connect(_on_new_game_pressed)
		left.add_child(fresh)
		left.add_child(_gap())

	right.add_child(_gap())
	var quit := UITheme.art_button("quit", BUTTON_HEIGHT)
	quit.pressed.connect(func() -> void: get_tree().quit())
	right.add_child(quit)

	# The kit's painted SETTINGS sign — the same control as the one in the corner
	# of the game scene, so settings is one recognisable object wherever you meet
	# it. Taller here than in that corner: this screen has the room, and the
	# corner does not.
	var settings := UITheme.kit_button("btn_settings", 38.0)
	settings.pressed.connect(_on_settings_pressed)
	var settings_row := HBoxContainer.new()
	settings_row.alignment = BoxContainer.ALIGNMENT_CENTER
	settings_row.add_child(settings)
	column.add_child(settings_row)

	var hint := Label.new()
	# F first: it is the one that works in a browser, and most players meeting
	# this game will meet it in a browser.
	hint.text = "F or F11 for fullscreen"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override(&"font_color", UITheme.CREAM)
	UITheme.outline(hint, 4)
	column.add_child(hint)

	_build_version_stamp()


## The build a playtester is on: top-left, on its own plate.
##
## Was bottom-right in dim grey and could not be found on the running game, for
## two reasons. The anchors were the real one — a preset sets the offsets, and
## then assigning `position` recomputes them against the anchor, so the label was
## being placed relative to the bottom-right corner and rendered off the edge of
## the screen. The offsets are therefore set directly here and `position` is left
## alone.
##
## The second reason is that it was too quiet even where it did land: small dim
## type over painted key art, with a scrim and three signs competing for the
## bottom of the picture. It has moved to the top-left, which the artwork leaves
## empty, and it sits on a dark plate so it reads over whatever is behind it —
## a tester has to be able to pick it off a screenshot without being told where
## to look.
func _build_version_stamp() -> void:
	var plate := PanelContainer.new()
	UITheme.paint(plate, PaintedBox.plate(UITheme.SLATE))
	plate.anchor_left = 0.0
	plate.anchor_top = 0.0
	plate.anchor_right = 0.0
	plate.anchor_bottom = 0.0
	plate.offset_left = 12.0
	plate.offset_top = 12.0
	# Zero size with GROW_END: the plate takes its width and height from the label
	# inside it, growing right and down from the corner it is pinned to.
	plate.offset_right = 12.0
	plate.offset_bottom = 12.0
	plate.grow_horizontal = Control.GROW_DIRECTION_END
	plate.grow_vertical = Control.GROW_DIRECTION_END
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)

	var label := Label.new()
	label.text = BuildInfo.line()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override(&"font_color", UITheme.CREAM)
	UITheme.outline(label, 4)
	plate.add_child(label)


## The air between the middle sign and its neighbours. A fixed spacer rather than
## the row's separation, because the row's separation would also apply between
## the expanding slots and the middle sign and push it off centre by half of it.
func _gap() -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(SIGN_GAP, 0)
	return spacer


func _on_play_pressed() -> void:
	# Arriving from the menu, so the select screen's BACK belongs to the menu.
	# Cleared here rather than trusted to have been cleared on the way out: a
	# player who quits to the title mid-run would otherwise leave it set.
	Campaign.return_to_game = false
	get_tree().change_scene_to_file(SELECT_SCENE)


func _on_settings_pressed() -> void:
	_modal = UITheme.settings(self)


## Starting over throws away a run that can't be recovered, so it asks. The save
## is deleted here rather than in Main, which simply resumes whatever it finds.
func _on_new_game_pressed() -> void:
	_modal = UITheme.confirm(
		self,
		"Start a new game?\nYour current run is deleted.",
		"NEW GAME",
		func() -> void:
			SaveGame.delete()
			# Straight into level 1: a new game has nothing to choose between, and
			# the select screen would show three locked cards and one PLAY button.
			Campaign.requested_level = 0
			get_tree().change_scene_to_file(MAIN_SCENE)
	)


## Enter and Space start the game, so the menu never needs the mouse. While the
## new-game prompt is up they must not — Enter would otherwise both answer the
## prompt and launch the game behind it.
func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.is_echo():
		return
	var key := (event as InputEventKey).keycode
	if is_instance_valid(_modal):
		if key == KEY_ESCAPE:
			_modal.queue_free()
			get_viewport().set_input_as_handled()
		return
	if UITheme.is_fullscreen_key(key):
		UITheme.toggle_fullscreen()
		get_viewport().set_input_as_handled()
	elif key == KEY_ENTER or key == KEY_KP_ENTER or key == KEY_SPACE:
		_on_play_pressed()
		get_viewport().set_input_as_handled()
