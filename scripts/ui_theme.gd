## The game's look, in one place: palette plus a Theme built from it.
##
## The sprites are flat cel-shaded shapes with one heavy black outline, so the UI
## is the same recipe — flat fills, a 3px near-black border on everything, and no
## gradients or shadows. Anything that reads as "chrome" fights the art.
##
## Built in code rather than authored as a .tres because every value here is
## derived from four colours and two radii; a binary theme resource would hide
## that relationship and make a palette change a manual click-through.
class_name UITheme
extends RefCounted

## Outline black. The same near-black the sprites are drawn with — pure black
## reads as a hole against the sunset backdrop.
const INK := Color("141414")
## The primary. Crate bands, the car, the plank highlights.
##
## Softened from the sprite yellow (f5c21b). At full saturation it is the
## brightest thing on the screen by a wide margin — brighter than the sunset it
## sits on — so every mustard panel pulled the eye away from the strait and the
## black type on it buzzed. Pulling it towards gold keeps the hue the crates are
## painted in while dropping it below the backdrop in loudness.
const MUSTARD := Color("dfa93c")
## Deeper gold, for shading and for the pressed state of anything mustard.
const AMBER := Color("bf8524")
## Bright coin gold, for money read on a dark plate. The green MONEY below is for
## money on cream, where a light gold would disappear.
const GOLD := Color("f0c766")
const WOOD := Color("c98a3c")
const STEEL := Color("9aa3aa")
## Panel fill. Warm off-white lifted from the refrigerator sprite.
const CREAM := Color("ede7da")
## Cream one step down, for wells and secondary buttons.
const CREAM_DIM := Color("d9cebb")
## Disabled fill and disabled text.
const MUTE := Color("b9b2a6")
const MUTE_TEXT := Color("8a8279")
const SUBTLE_TEXT := Color("6b6259")
## The highlight. Lifted from the plastic barrel — the one saturated colour in
## the sprite set that isn't mustard, so it marks the shop as a different kind of
## thing from the mustard status chrome without introducing a new hue.
const ACCENT := Color("4fa3d8")
## Go. Only ever on START CROSSING and BUY, so green always means "spend/commit".
const GREEN := Color("2e7d3a")
const GREEN_TEXT := Color("cdebd3")
const MONEY := Color("1f6b2e")
const DANGER := Color("c0392b")

const BORDER := 3
const RADIUS := 8
const RADIUS_PANEL := 14

## Body copy. Small because the panel is deliberately narrow.
const FONT_SIZE := 13
## Buttons, counts, and anything that has to survive being glanced at.
const FONT_SIZE_LOUD := 15
const FONT_SIZE_TITLE := 21
const FONT_SIZE_SMALL := 11


## A flat fill with the house outline. `radius` defaults to the button radius.
static func box(fill: Color, radius: int = RADIUS, border: int = BORDER) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_border_width_all(border)
	sb.border_color = INK
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


## Painted button artwork, cut from Buttons.jpg by tools/slice_buttons.gd.
const ART_DIR := "res://art/ui/"


## A button that *is* its artwork — no stylebox, no frame, just the painted sign.
##
## Sized from a target height so the art keeps its own proportions; these signs
## have wildly different aspects (the Salvage Shop crate is nearly square, the
## Continue pipe is more than twice as wide as it is tall) and forcing them to a
## common rectangle would squash them.
##
## `min_width` pads the box without stretching the art, for the cases where a
## button needs to reserve more room than its picture occupies.
static func art_button(name: String, height: float, min_width: float = 0.0) -> TextureButton:
	var button := TextureButton.new()
	var texture := load(ART_DIR + name + ".png") as Texture2D
	button.texture_normal = texture
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	if texture != null:
		var size := texture.get_size()
		button.custom_minimum_size = Vector2(
			maxf(height * size.x / size.y, min_width), height
		)
	else:
		button.custom_minimum_size = Vector2(maxf(min_width, height), height)
	return button


## The same thing sized by width instead of height.
##
## Which axis you pin matters a lot with these signs: QUIT is nearly square and
## CONTINUE is two and a half times as wide as it is tall, so a shared height
## makes QUIT a postage stamp next to it. In a menu column the eye compares
## widths, so that is the axis to fix; in a dock row it compares heights.
static func art_button_by_width(name: String, width: float) -> TextureButton:
	var texture := load(ART_DIR + name + ".png") as Texture2D
	var height := width
	if texture != null:
		var size := texture.get_size()
		height = width * size.y / size.x
	return art_button(name, height)


## A piece of the painted sheet used as a picture rather than as a control,
## sized from a target height the way art_button() is.
static func art_image(name: String, height: float) -> TextureRect:
	var rect := art_overlay(name)
	if rect.texture != null:
		var size := rect.texture.get_size()
		rect.custom_minimum_size = Vector2(height * size.x / size.y, height)
	else:
		rect.custom_minimum_size = Vector2(height, height)
	return rect


## A TextureRect that lines up pixel-for-pixel with an art_button's picture, for
## overlays that have to follow the artwork's own silhouette.
static func art_overlay(name: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = load(ART_DIR + name + ".png") as Texture2D
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Wraps a container in a painted plate. The four chrome surfaces — the dock, the
## header readout, the shop frame and the settings panel — all go through here,
## so "what a painted surface looks like" is one decision rather than four.
static func paint(container: Container, box: PaintedBox) -> void:
	container.add_theme_stylebox_override(&"panel", box)


## Dark painted metal. The backing for readouts, where the numbers should be the
## bright thing rather than the plate they sit on.
const SLATE := Color("332e28")


## A button that is a small painted plate with enamel lettering.
##
## The one factory for every control that isn't a painted sign from the sheet —
## the settings control on both screens and the two contextual dock buttons. They
## were each styled separately before and each came out looking like it belonged
## to a different game.
## `note` paints a music note on the plate instead of taking a label, for the
## settings control — the only setting is the volume, so the note is the name.
static func plate_button(
	label: String, fill: Color, min_size: Vector2 = Vector2.ZERO, note: bool = false
) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = min_size
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		var shade := fill
		if state == &"hover":
			shade = fill.lightened(0.16)
		elif state == &"pressed":
			shade = fill.darkened(0.16)
		var box := PaintedBox.plate(shade)
		box.note = note
		button.add_theme_stylebox_override(state, box)
	for state: StringName in [
		&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"
	]:
		button.add_theme_color_override(state, CREAM)
	button.add_theme_constant_override(&"outline_size", 4)
	button.add_theme_color_override(&"font_outline_color", INK)
	return button


## A heading rendered on a painted tin sign, for the titles of the two modals.
## Panels are boards; the thing that names a board is a sign nailed to it.
static func sign_label(text: String, fill: Color = MUSTARD) -> PanelContainer:
	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override(&"panel", PaintedBox.sign(fill))
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	as_title(label)
	outline(label, 3)
	label.add_theme_color_override(&"font_color", CREAM)
	strip.add_child(label)
	return strip


## A small fully-rounded chip, for counts and badges sitting on top of a control.
static func pill(fill: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(9)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	return sb


## Builds the Theme. Apply it to a UI root; children inherit.
static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE

	_style_button(theme)
	_style_panel(theme)
	_style_label(theme)
	_style_scroll(theme)
	_style_tooltip(theme)
	return theme


## Hover text, which was the one surface still wearing Godot's defaults: a pale
## translucent slab with dark grey type, floating over a sunset. Every card in
## the belt and every row in the shop carries one, and they were the hardest
## thing on screen to read.
##
## Inverted instead of made into another cream panel: a tooltip is transient and
## sits *on top of* the panel that spawned it, so it has to separate itself from
## cream chrome rather than join it. Near-black with cream type is the strongest
## contrast the palette allows, and it reads as a label on a dark plate — which
## the header and the settings knob already are.
static func _style_tooltip(theme: Theme) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = INK
	sb.set_border_width_all(2)
	sb.border_color = CREAM
	sb.set_corner_radius_all(RADIUS)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	theme.set_stylebox(&"panel", &"TooltipPanel", sb)
	theme.set_color(&"font_color", &"TooltipLabel", CREAM)
	# No outline: it is white-on-black already, and the sticker outline the rest of
	# the game's floating text uses would only thicken the glyphs.
	theme.set_color(&"font_outline_color", &"TooltipLabel", INK)
	theme.set_constant(&"outline_size", &"TooltipLabel", 0)
	theme.set_font_size(&"font_size", &"TooltipLabel", FONT_SIZE_LOUD)


static func _style_button(theme: Theme) -> void:
	# Pressed sinks by shading the fill rather than moving the box: a 1px nudge
	# would break the alignment of the piece rows, which are read as a column.
	theme.set_stylebox(&"normal", &"Button", box(CREAM))
	theme.set_stylebox(&"hover", &"Button", box(CREAM.lightened(0.25)))
	theme.set_stylebox(&"pressed", &"Button", box(CREAM.darkened(0.12)))
	theme.set_stylebox(&"focus", &"Button", box(CREAM, RADIUS, BORDER + 1))
	var disabled := box(MUTE)
	disabled.border_color = INK.lightened(0.35)
	theme.set_stylebox(&"disabled", &"Button", disabled)

	theme.set_color(&"font_color", &"Button", INK)
	theme.set_color(&"font_hover_color", &"Button", INK)
	theme.set_color(&"font_pressed_color", &"Button", INK)
	theme.set_color(&"font_focus_color", &"Button", INK)
	theme.set_color(&"font_disabled_color", &"Button", MUTE_TEXT)
	theme.set_font_size(&"font_size", &"Button", FONT_SIZE_LOUD)


static func _style_panel(theme: Theme) -> void:
	var panel := box(CREAM, RADIUS_PANEL)
	panel.content_margin_left = 10
	panel.content_margin_right = 10
	panel.content_margin_top = 10
	panel.content_margin_bottom = 10
	theme.set_stylebox(&"panel", &"PanelContainer", panel)
	theme.set_stylebox(&"panel", &"Panel", panel)


static func _style_label(theme: Theme) -> void:
	theme.set_color(&"font_color", &"Label", INK)
	theme.set_font_size(&"font_size", &"Label", FONT_SIZE)
	# The default font is a light sans, which disappears over the sunset. An
	# outline gives it the sticker weight the sprites have without a font file.
	theme.set_color(&"font_outline_color", &"Label", INK)
	theme.set_constant(&"outline_size", &"Label", 0)
	theme.set_constant(&"separation", &"VBoxContainer", 4)
	theme.set_constant(&"separation", &"HBoxContainer", 6)


static func _style_scroll(theme: Theme) -> void:
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = INK
	grabber.set_corner_radius_all(4)
	theme.set_stylebox(&"grabber", &"VScrollBar", grabber)
	theme.set_stylebox(&"grabber_highlight", &"VScrollBar", grabber)
	theme.set_stylebox(&"grabber_pressed", &"VScrollBar", grabber)
	var trough := StyleBoxFlat.new()
	trough.bg_color = CREAM_DIM
	trough.set_corner_radius_all(4)
	theme.set_stylebox(&"scroll", &"VScrollBar", trough)


## How far a hovered control swells, and how long it takes.
const HOVER_SCALE := 1.055
const PRESS_SCALE := 0.965
const HOVER_TIME := 0.09


## Fullscreen, from anywhere.
##
## Lived in main.gd, which meant the title screen advertised "F11 fullscreen"
## and then ignored the key. Shared from here so both screens — and the settings
## panel's button — are toggling the same thing.
static func toggle_fullscreen() -> void:
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN
	)


## Does this key mean "fullscreen"?
##
## F as well as F11, because in a browser F11 never reaches the game: it is the
## browser's own fullscreen shortcut and is consumed before the canvas sees a
## keydown. F is unclaimed, so it is the binding that actually works on itch —
## F11 is kept for the desktop build, where players expect it.
static func is_fullscreen_key(key: Key) -> bool:
	return key == KEY_F11 or key == KEY_F


## Fire a one-shot through the Audio autoload, if there is one.
##
## Static, and reached by absolute path, because everything in this file is
## static and the callers are scattered across screens that have no reason to
## hold an audio reference. Silent when the autoload is absent, which is the
## case in the headless checks.
static func play(sound: StringName) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var audio := tree.root.get_node_or_null(^"/root/Audio")
	if audio != null:
		audio.play_sound(sound)


## Gives every Button under `root` a hover swell and a press dip.
##
## Applied by walking the tree rather than at each construction site, so a button
## added later can't quietly miss out — call this once after a screen is built,
## and again after any batch of buttons is added.
static func enliven(root: Node) -> void:
	for node: Node in root.get_children():
		if node is BaseButton and not node.has_meta(&"hover_motion"):
			add_hover_motion(node as BaseButton)
		enliven(node)


## The sound a button makes, when it should not be the ordinary UI click.
## Set before enliven() reaches the button.
static func set_click_sound(button: BaseButton, sound: StringName) -> void:
	button.set_meta(&"click_sound", sound)


## Scale is used rather than position or a style swap because it's the one
## transform that costs no layout: the control's rect is unchanged, so a swelling
## belt card can't nudge its neighbours along the dock.
static func add_hover_motion(button: BaseButton) -> void:
	button.set_meta(&"hover_motion", true)

	# Clicks are wired here rather than at each button, for the same reason the
	# hover swell is: enliven() already walks every button on a screen, so a
	# control added later cannot quietly end up silent. Anything wanting a
	# different sound says so with set_click_sound().
	var sound: StringName = button.get_meta(&"click_sound", &"ui_click")
	button.pressed.connect(func() -> void: play(sound))
	# Scaling happens about the centre; the default pivot is the top-left, which
	# reads as the control sliding down-right rather than growing.
	button.pivot_offset = button.size * 0.5
	button.resized.connect(func() -> void: button.pivot_offset = button.size * 0.5)

	button.mouse_entered.connect(func() -> void: _scale_to(button, HOVER_SCALE))
	button.mouse_exited.connect(func() -> void: _scale_to(button, 1.0))
	button.button_down.connect(func() -> void: _scale_to(button, PRESS_SCALE))
	button.button_up.connect(func() -> void:
		_scale_to(button, HOVER_SCALE if button.is_hovered() else 1.0)
	)


## A disabled button must stay inert — swelling under the cursor would promise a
## click that won't happen.
static func _scale_to(button: BaseButton, target: float) -> void:
	if button.disabled:
		target = 1.0
	var running := button.get_meta(&"hover_tween", null) as Tween
	if running != null and running.is_valid():
		running.kill()
	var tween := button.create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(button, ^"scale", Vector2(target, target), HOVER_TIME)
	button.set_meta(&"hover_tween", tween)


## Closes a modal when the player clicks the dimmed area around it.
##
## `overlay` must be the full-screen control that catches clicks and `frame` the
## panel itself; a click anywhere outside the frame's visible rectangle counts as
## backing out. Every modal in the game already treats Escape that way, and the
## click is the same gesture with the mouse the hand is already on.
##
## Attached to the overlay rather than being a check inside each modal's own
## input handling, so a modal added later gets it by construction.
static func dismiss_on_outside_click(
	overlay: Control, frame: Control, on_dismiss: Callable
) -> void:
	overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is not InputEventMouseButton:
			return
		var mb := event as InputEventMouseButton
		if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if not is_instance_valid(frame) or visible_rect(frame).has_point(mb.global_position):
			return
		overlay.accept_event()
		on_dismiss.call()
	)


## Where a control actually appears on screen, accounting for scale.
##
## get_global_rect() reports the layout rectangle, which for a scaled control is
## not what the player sees — the shop panel shrinks itself to fit, and using the
## layout rect there would treat a click in the empty margin beside the shrunken
## panel as a click on it.
static func visible_rect(control: Control) -> Rect2:
	var origin: Vector2 = (
		control.global_position + control.pivot_offset * (Vector2.ONE - control.scale)
	)
	return Rect2(origin, control.size * control.scale)


## A yes/no modal, built from this theme rather than from ConfirmationDialog —
## that brings its own OS-styled window chrome and would be the one thing on
## screen that doesn't look like the rest of the game.
##
## Returns the overlay so the caller can dismiss it on Escape; it frees itself on
## either button.
static func confirm(
	parent: Node, message: String, accept_text: String, on_accept: Callable
) -> Control:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(INK, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(centre)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(360, 0)
	# The confirm shares the settings panel's boards on purpose: the comment above
	# promises every modal is one object with different contents, and that only
	# holds if the skin follows too.
	paint(frame, PaintedBox.board(WOOD, 3))
	centre.add_child(frame)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 14)
	frame.add_child(column)

	var leaf := PanelContainer.new()
	paint(leaf, PaintedBox.board(CREAM, 0))
	column.add_child(leaf)

	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", FONT_SIZE_LOUD)
	leaf.add_child(label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 10)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)

	# Cancel first and in the neutral colour: the destructive option should never
	# be the one the hand goes to by reflex.
	var cancel := Button.new()
	cancel.text = "CANCEL"
	cancel.custom_minimum_size = Vector2(140, 40)
	cancel.add_theme_stylebox_override(&"normal", box(CREAM_DIM))
	cancel.pressed.connect(overlay.queue_free)
	buttons.add_child(cancel)

	var accept := Button.new()
	accept.text = accept_text
	accept.custom_minimum_size = Vector2(140, 40)
	accept.add_theme_stylebox_override(&"normal", box(DANGER))
	accept.add_theme_color_override(&"font_color", Color.WHITE)
	accept.add_theme_color_override(&"font_hover_color", Color.WHITE)
	accept.pressed.connect(func() -> void:
		overlay.queue_free()
		on_accept.call()
	)
	buttons.add_child(accept)

	# Clicking away is a cancel, never an accept. The destructive option must
	# only ever happen because it was aimed at.
	dismiss_on_outside_click(overlay, frame, overlay.queue_free)
	enliven(overlay)
	cancel.grab_focus()
	return overlay


## The end-of-game card.
##
## A modal rather than the banner the campaign end used to get: finishing every
## strait is the one moment the game has to mark, and a line of text over the
## water that clears itself after four seconds is indistinguishable from the
## message you get for sinking.
##
## Deliberately does NOT stop play. Dismissing it leaves the player in the last
## level with their bridge and their money, free to keep messing about, which is
## the only thing left to do and the thing this game is actually for.
static func congratulations(
	parent: Node, lines: Array[String], on_title: Callable
) -> Control:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(INK, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(centre)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(470, 0)
	paint(frame, PaintedBox.board(WOOD, 4))
	centre.add_child(frame)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 12)
	frame.add_child(column)

	column.add_child(sign_label("EVERY STRAIT CROSSED"))

	var leaf := PanelContainer.new()
	paint(leaf, PaintedBox.board(CREAM, 0))
	column.add_child(leaf)

	var text := VBoxContainer.new()
	text.add_theme_constant_override(&"separation", 6)
	leaf.add_child(text)

	for i in lines.size():
		var line := Label.new()
		line.text = lines[i]
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# First line is the sentence, the rest are the figures.
		line.add_theme_font_size_override(
			&"font_size", FONT_SIZE_LOUD if i == 0 else FONT_SIZE
		)
		if i > 0:
			line.add_theme_color_override(&"font_color", SUBTLE_TEXT)
		text.add_child(line)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 10)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)

	var stay := plate_button("KEEP BUILDING", STEEL.darkened(0.34), Vector2(170, 42))
	stay.pressed.connect(overlay.queue_free)
	buttons.add_child(stay)

	var title := plate_button("MAIN MENU", AMBER, Vector2(170, 42))
	title.pressed.connect(func() -> void:
		overlay.queue_free()
		on_title.call()
	)
	buttons.add_child(title)

	dismiss_on_outside_click(overlay, frame, overlay.queue_free)
	enliven(overlay)
	stay.grab_focus()
	return overlay


## The bare bones of a modal: dim, centred board, tin sign heading, cream leaf,
## a CLOSE button, Escape/click-away dismissal.
##
## confirm(), congratulations() and settings() predate this and each build their
## own; this exists for panels whose contents need live game state and so can't
## live in this file at all. Returns [overlay, content] — the caller fills the
## content column and never touches the rest.
static func modal(parent: Node, title: String, min_width: float = 380.0) -> Array:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(INK, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(centre)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(min_width, 0)
	paint(frame, PaintedBox.board(WOOD, 4))
	centre.add_child(frame)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 12)
	frame.add_child(column)

	column.add_child(sign_label(title))

	var leaf := PanelContainer.new()
	paint(leaf, PaintedBox.board(CREAM, 0))
	column.add_child(leaf)

	var content := VBoxContainer.new()
	content.add_theme_constant_override(&"separation", 10)
	leaf.add_child(content)

	var close := Button.new()
	close.text = "CLOSE"
	close.custom_minimum_size = Vector2(0, 40)
	close.add_theme_stylebox_override(&"normal", box(MUSTARD))
	close.pressed.connect(overlay.queue_free)
	column.add_child(close)

	dismiss_on_outside_click(overlay, frame, overlay.queue_free)
	return [overlay, content]


## The settings panel. Small, because there is exactly one setting.
##
## Built here alongside confirm() so every modal in the game is the same object
## with different contents, rather than each screen growing its own.
##
## Returns the overlay; it frees itself on Close, and the caller can free it to
## dismiss on Escape.
static func settings(parent: Node) -> Control:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	# Runs while the tree is paused, or the slider would be dead in a paused
	# game — which is exactly when the settings are open.
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(INK, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(centre)

	# A stacked board, so the panel reads as planks nailed together the way the
	# dock does — the settings are the same object as everything else on screen.
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(380, 0)
	paint(frame, PaintedBox.board(WOOD, 4))
	centre.add_child(frame)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 12)
	frame.add_child(column)

	column.add_child(sign_label("SETTINGS"))

	# The controls sit on a cream leaf pinned to the boards: text on bare wood is
	# a legibility problem, and it also loses the "paperwork on a workbench" read.
	var leaf := PanelContainer.new()
	paint(leaf, PaintedBox.board(CREAM, 0))
	column.add_child(leaf)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override(&"separation", 10)
	leaf.add_child(inner)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	inner.add_child(row)

	var label := Label.new()
	label.text = "Master volume"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var readout := Label.new()
	readout.custom_minimum_size = Vector2(46, 0)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(readout)

	var audio := parent.get_node_or_null(^"/root/Audio")
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.custom_minimum_size = Vector2(0, 24)
	slider.value = float(audio.master_volume) if audio != null else 1.0
	inner.add_child(slider)

	readout.text = "%d%%" % roundi(slider.value * 100.0)
	slider.value_changed.connect(func(value: float) -> void:
		readout.text = "%d%%" % roundi(value * 100.0)
		if audio != null:
			audio.master_volume = value
	)
	# Written on release, not on every step: dragging a slider emits dozens of
	# changes a second and each one would be a file write.
	slider.drag_ended.connect(func(changed: bool) -> void:
		if changed and audio != null:
			audio.save_settings()
	)

	# Also a button, not only a key. Browsers only enter fullscreen from a real
	# user gesture, and a click is the gesture they never argue with — whereas a
	# keypress can be swallowed by the page or the browser first.
	var screen := plate_button("FULLSCREEN", SLATE, Vector2(0, 36))
	screen.pressed.connect(toggle_fullscreen)
	inner.add_child(screen)

	var close := Button.new()
	close.text = "CLOSE"
	close.custom_minimum_size = Vector2(0, 40)
	close.add_theme_stylebox_override(&"normal", box(MUSTARD))
	close.pressed.connect(func() -> void:
		if audio != null:
			audio.save_settings()
		overlay.queue_free()
	)
	column.add_child(close)

	# Same as Close: the volume is already applied and saved on release, so
	# clicking away can't lose anything.
	dismiss_on_outside_click(overlay, frame, func() -> void:
		if audio != null:
			audio.save_settings()
		overlay.queue_free()
	)
	enliven(overlay)
	slider.grab_focus()
	return overlay


## Text drawn straight onto the world (over water and sky) needs its own outline
## to stay legible; text inside a cream panel must not have one.
static func outline(label: Label, size: int = 5) -> void:
	label.add_theme_constant_override(&"outline_size", size)
	label.add_theme_color_override(&"font_outline_color", INK)


## Sets a label's role in one call, so the panel code reads as layout only.
static func as_heading(label: Label) -> void:
	label.add_theme_font_size_override(&"font_size", FONT_SIZE_SMALL)
	label.add_theme_color_override(&"font_color", SUBTLE_TEXT)


## A heading sitting on painted wood rather than on cream. The subtle brown of
## as_heading() all but vanishes against the boards, so this flips to cream with
## the sprites' own outline behind it.
static func as_caption(label: Label) -> void:
	label.add_theme_font_size_override(&"font_size", FONT_SIZE_SMALL)
	label.add_theme_color_override(&"font_color", CREAM)
	outline(label, 4)


static func as_title(label: Label) -> void:
	label.add_theme_font_size_override(&"font_size", FONT_SIZE_TITLE)
	label.add_theme_color_override(&"font_color", INK)
