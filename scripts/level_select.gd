## Pick a strait. Sits between the title screen and the game.
##
## Every level is a card carrying its own backdrop, which is the only picture of
## that level that exists and the one the player will recognise it by — a list of
## names would make level 2 and level 3 the same thing with different numbers.
##
## Locked levels are shown rather than hidden. Knowing there are four straits and
## you are on the second is the progression; a list that grows an entry at a time
## hides the shape of the run from the person making it.
extends Control

const TITLE_SCENE := "res://scenes/title_screen.tscn"
const MAIN_SCENE := "res://scenes/main.tscn"

## Card size. Wide enough for a backdrop to read as scenery rather than as a
## thumbnail, small enough that four stand across the 1280 canvas in one row.
const CARD := Vector2(276, 190)
const ART_HEIGHT := 116.0
const GAP := 16
## How far into the backdrop the card's crop reaches: 2.6 keeps roughly the
## middle two fifths of the picture's height. High enough that the scenery reads
## at card size, low enough that the crop is still a view rather than a texture.
const SNIPPET_ZOOM := 2.6
## Where the backdrop's waterline lands in the card, top to bottom.
##
## 1.0 — the crop stops AT the waterline and shows none of the water. Everything
## a backdrop paints below its horizon is the near-black mass the strait is cut
## into, which the game itself never shows; even a sliver of it reads as a dark
## bar ruled across the bottom of the card rather than as water.
const HORIZON_IN_CARD := 1.0

var _levels: Array[LevelDef] = []
var _unlocked: int = 0
var _standings: Dictionary[int, PackedInt32Array] = {}
var _saved_level: int = 0
var _modal: Control = null
var _boards: Leaderboard = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The game's theme, which this screen was the only one never to apply — the
	# title screen and the HUD both build it. Without it every Label here fell
	# back to the engine default of white text, and the cards only looked right
	# because each of their labels happened to set its own colour by hand. Any new
	# panel that didn't do the same came out white on cream, which is what the
	# leaderboard table did.
	theme = UITheme.build()
	_levels = Campaign.levels()
	_boards = Leaderboard.new()
	add_child(_boards)
	_read_save()
	_build()

	var audio := get_node_or_null(^"/root/Audio")
	if audio != null:
		audio.call(&"set_level_music", _saved_level)


## Progress comes straight out of the save file rather than from a LevelManager:
## this screen runs before the game scene exists, and it only needs three facts.
func _read_save() -> void:
	var data := SaveGame.load_data()
	if data.is_empty():
		return
	_saved_level = int(data.get("level", 0))
	_unlocked = int(data.get("unlocked", 0))
	# Through SaveGame rather than parsing `records` here, which is what this used
	# to do: it was the same loop written twice, and when the standings changed
	# unit this screen would have gone on showing the old numbers as records.
	_standings = SaveGame.standings_of(data)


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = UITheme.INK
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override(&"separation", 18)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(column)

	var heading := CenterContainer.new()
	column.add_child(heading)
	heading.add_child(UITheme.sign_label("CHOOSE A STRAIT"))

	# A flow, so a fifth level wraps onto a second line instead of running off
	# the side of the screen the day one is added.
	var row := HFlowContainer.new()
	row.add_theme_constant_override(&"h_separation", GAP)
	row.add_theme_constant_override(&"v_separation", GAP)
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	column.add_child(row)

	for i in _levels.size():
		row.add_child(_build_card(i))

	var back := CenterContainer.new()
	column.add_child(back)
	# The button says where it goes, because from here those are two different
	# places — back into the strait you stepped out of, or out to the menu.
	var button := UITheme.plate_button(
		"BACK TO STRAIT" if Campaign.return_to_game else "MAIN MENU",
		UITheme.STEEL.darkened(0.34),
		Vector2(220, 42)
	)
	button.pressed.connect(_on_back)
	back.add_child(button)

	UITheme.enliven(self)


func _build_card(index: int) -> Control:
	var level := _levels[index]
	# Playable means cleared before, or the first level you have not cleared —
	# the same rule the campaign already advances by.
	var playable := index <= _unlocked

	var card := PanelContainer.new()
	card.custom_minimum_size = CARD
	UITheme.paint(card, PaintedBox.board(UITheme.CREAM, 0))
	# A locked card is dimmed by DRAWING it darker, never by making it
	# translucent. Fading the whole card was the first attempt and it let the
	# card's own painted boards show through the artwork — which read as a pale
	# band slicing the picture in half, wider than the picture itself, because the
	# board behind it is the width of the whole card.

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 4)
	card.add_child(column)

	# The level's own backdrop, cropped to the card. A locked one is drained of
	# colour rather than blanked: you can see the place, you have not been there.
	var well := PanelContainer.new()
	var well_box := PaintedBox.board(UITheme.CREAM_DIM, 0)
	well_box.radius = UITheme.RADIUS
	well_box.set_margins(4, 4)
	well.add_theme_stylebox_override(&"panel", well_box)
	well.custom_minimum_size = Vector2(0, ART_HEIGHT)
	well.clip_contents = true
	column.add_child(well)

	var art := TextureRect.new()
	art.texture = _snippet(level)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.custom_minimum_size = Vector2(0, ART_HEIGHT - 8)
	# Opaque either way: darkened and cooled towards slate for a locked level, so
	# the place is still legible but plainly not yours yet.
	if not playable:
		art.modulate = Color(0.46, 0.48, 0.54)
	well.add_child(art)

	var name_label := Label.new()
	name_label.text = level.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override(&"font_size", UITheme.FONT_SIZE_LOUD)
	# Ink, not the theme's default: the card is cream and the default is near
	# white, which put the level's name almost out of sight on its own card.
	name_label.add_theme_color_override(
		&"font_color", UITheme.INK if playable else UITheme.SUBTLE_TEXT
	)
	column.add_child(name_label)

	var best := Label.new()
	best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best.add_theme_color_override(&"font_color", UITheme.SUBTLE_TEXT)
	var table: PackedInt32Array = _standings.get(index, PackedInt32Array())
	best.text = (
		"best bridge $%d" % table[0] if not table.is_empty()
		else "not crossed yet" if playable
		else "locked"
	)
	column.add_child(best)

	var play := UITheme.plate_button(
		"PLAY" if playable else "LOCKED",
		UITheme.AMBER if playable else UITheme.STEEL.darkened(0.34),
		Vector2(0, 36)
	)
	play.disabled = not playable
	play.pressed.connect(_on_pick.bind(index))
	column.add_child(play)

	column.add_child(_build_scores_row(index, not table.is_empty()))
	return card


## The SCORES button, on a strait the player has actually crossed.
##
## Crossed rather than unlocked: `playable` includes the next strait you have
## never touched, and a scoreboard is a record of what you did here. Offering one
## for a level with nothing on it is a button that opens an empty box.
##
## Uncrossed cards get an empty spacer of the same height instead of nothing at
## all. The cards sit in a flow row aligned along their tops, so a card one
## button shorter than its neighbours doesn't look like a card without a button —
## it looks like the row is broken.
func _build_scores_row(index: int, crossed: bool) -> Control:
	if not crossed:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, SCORES_HEIGHT)
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return spacer

	var scores := UITheme.plate_button(
		"LEADERBOARD", UITheme.STEEL.darkened(0.34), Vector2(0, SCORES_HEIGHT)
	)
	scores.pressed.connect(_show_scores.bind(index))
	return scores


## Shorter than PLAY. Looking at the board is the secondary thing to do on a card
## whose whole purpose is to start a level.
const SCORES_HEIGHT := 28.0


## The leaderboard for one strait, without entering it.
##
## Built from the same pieces as the crossing panel, so the board a player sees
## here is the board they saw when they set the score — including the name field,
## which is the only place to set a name without finishing a crossing first.
func _show_scores(index: int) -> void:
	if _modal != null and is_instance_valid(_modal):
		_modal.queue_free()

	var parts := UITheme.modal(self, _levels[index].display_name.to_upper(), 380.0)
	_modal = parts[0] as Control
	var content := parts[1] as VBoxContainer

	if Leaderboard.has_board(index):
		UITheme.refresh_online_board(
			UITheme.online_board_section(content, _boards, index), _boards, index
		)
	else:
		# No board configured, or no way to reach one. Says so plainly rather than
		# opening an empty panel that looks like a strait nobody has crossed.
		var none := Label.new()
		none.text = "Leaderboard unavailable."
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.add_theme_color_override(&"font_color", UITheme.SUBTLE_TEXT)
		content.add_child(none)

	UITheme.enliven(_modal)


## A close crop of the level's backdrop, taken around its painted horizon.
##
## Shrinking the whole picture into the card was the wrong instinct: these
## backdrops are deliberately wide and deliberately hazy, and at card size the
## city that is meant to be a distant skyline became four grey pixels — which is
## the point at which people start reaching for blurs and vignettes to make a
## thumbnail look like something. A snippet needs none of that. It shows the
## place at nearly the size the player will see it at in the game.
##
## Cropped around `backdrop_horizon` rather than around the middle of the file,
## because that is where the level's own scenery is: the padding above and below
## is sky and ground the game never shows either.
func _snippet(level: LevelDef) -> Texture2D:
	var source := level.backdrop if level.backdrop != null else _default_backdrop()
	if source == null:
		return null
	var full := Vector2(source.get_width(), source.get_height())
	var card_aspect := CARD.x / (ART_HEIGHT - 8.0)

	# Height of the crop, then the width the card's shape asks for. Clamped to the
	# file, so a small or narrow backdrop simply crops less rather than sampling
	# past its own edge.
	var height: float = minf(full.y / SNIPPET_ZOOM, full.y)
	var width: float = minf(height * card_aspect, full.x)
	height = minf(width / card_aspect, full.y)

	# The waterline sits near the BOTTOM of the crop, not its middle.
	#
	# Every backdrop paints a deep, near-black block below its horizon — the water
	# the strait is cut into, which in game is hidden behind the terrain and the
	# water surface and is never seen. Centring the crop on the horizon put half
	# of that block on the card, which on the forest read as a dark slab covering
	# the bottom of the picture. Sliding the crop up keeps the scenery, which is
	# the part the player will recognise, and leaves a sliver of water to say
	# there is a strait here.
	var horizon_y := full.y * level.backdrop_horizon
	var origin := Vector2(
		clampf(full.x * 0.5 - width * 0.5, 0.0, full.x - width),
		clampf(horizon_y - height * HORIZON_IN_CARD, 0.0, full.y - height)
	)

	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(origin, Vector2(width, height))
	return atlas


## The scene's own default scenery, for a level that sets no backdrop of its own.
## Read from world.tscn rather than named here, so the two cannot disagree about
## what "the default" is.
func _default_backdrop() -> Texture2D:
	var world := load("res://scenes/world.tscn") as PackedScene
	if world == null:
		return null
	var state := world.get_state()
	for i in state.get_node_count():
		for p in state.get_node_property_count(i):
			if state.get_node_property_name(i, p) == &"texture":
				return state.get_node_property_value(i, p) as Texture2D
	return null


func _on_pick(index: int) -> void:
	Campaign.requested_level = index
	Campaign.return_to_game = false
	get_tree().change_scene_to_file(MAIN_SCENE)


## Back where the player came from. Returning to the game asks for no particular
## level, so it resumes the save the HUD wrote on its way out — the same strait,
## the same bridge still standing in it.
func _on_back() -> void:
	if Campaign.return_to_game:
		Campaign.return_to_game = false
		Campaign.requested_level = -1
		get_tree().change_scene_to_file(MAIN_SCENE)
		return
	get_tree().change_scene_to_file(TITLE_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.is_echo():
		return
	if (event as InputEventKey).keycode != KEY_ESCAPE:
		return
	# Escape closes the scoreboard first and leaves the screen second. The guard
	# here predates anything ever setting _modal, so until now Escape over an open
	# panel did nothing at all rather than shutting it.
	if is_instance_valid(_modal):
		_modal.queue_free()
		return
	_on_back()
