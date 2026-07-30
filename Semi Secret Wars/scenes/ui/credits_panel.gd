class_name CreditsPanel
extends CanvasLayer
## The Credits modal — authorship plus the Freesound attribution list, reachable
## from the title screen (Designer, 2026-07-26).
##
## Same construction as SettingsPanel (read its doc for the reasoning about the
## click-swallowing scrim and building from UIStyle rather than Godot's own
## dialogs). Two deliberate differences:
##   * It does NOT pause the tree. Settings pauses because it is reachable
##     mid-battle and tweaking volume while the swarm eats your party is a
##     penalty; credits are a title-screen screen with nothing running behind
##     them to protect.
##   * The attribution list scrolls. It is 26 entries and growing, so a panel
##     sized to fit it all would be taller than the 1080 canvas.
##
## Usage: CreditsPanel.toggle(host) from a button, or .open(host).

## Below SettingsPanel's 210: if both are somehow up, Settings is the one the
## player is interacting with.
const LAYER := 205
const GROUP := "credits_panel"

const PANEL_WIDTH := 900.0
## Height cap on the scrolling attribution list. Sized so the panel — title,
## authorship block, heading, list, CLOSE button — clears the 1080 design canvas
## with margin at every step of the type scale.
const LIST_HEIGHT := 460.0

## Who made the game. Separate from the sourced-audio list below because these
## are authorship, not attribution obligations.
const CREDITS: Array[Array] = [
	["ART", "Modern Daedalus"],
	["GAME", "Modern Daedalus"],
]

## Every sound used, exactly as Freesound's own attribution export lists it,
## minus the "S:" row marker and the download timestamp (Designer, 2026-07-26 —
## neither is information a player needs). Order is the export's: newest
## download first.
##
## Kept as literal strings rather than parsed into name/author/licence fields:
## this is a legal attribution list, and the value of it is that it matches the
## source export verbatim. When new sounds are added, paste the new export rows
## here the same way.
const AUDIO_ATTRIBUTION: Array[String] = [
	"Monster Roar_8.mp3 by mitchanary | License: Attribution 4.0",
	"Paper Burn.wav by Soonus | License: Creative Commons 0",
	"Explosion 1.wav by theplax | License: Attribution 4.0",
	"Etherael - Blink - 01.wav by SoundFlakes | License: Attribution 4.0",
	"Step.wav by CGEffex | License: Attribution 4.0",
	"Dbl Click.mp3 by 7778 | License: Creative Commons 0",
	"defeated sigh.wav by Reitanna | License: Creative Commons 0",
	"Piano Game Over Theme (85 BPM) (F Minor) by kanaizo | License: Creative Commons 0",
	"Inspiring Music for Celebrations and Victories by ViraMiller | License: Attribution 4.0",
	"Ululu - dark mage casting a spell by faragilus | License: Creative Commons 0",
	"Sniper Scope zoom in by Supakid13 | License: Creative Commons 0",
	"pains.wav by Michel88 | License: Sampling+",
	"Lake Monster 27.wav by Debsound | License: Attribution NonCommercial 4.0",
	"Big plants (crops) growing quickly by Contant_aghony | License: Creative Commons 0",
	"Sacred Rune Lock 02 - Arcane Seal Activation by Coghezzi | License: Attribution 4.0",
	"DenseCrunchRe-rated_CaveIn.wav by zimbot | License: Attribution 4.0",
	"arrow_damage.wav by braqoon | License: Creative Commons 0",
	"Plant Stem Break 2 by JuneBeetle | License: Creative Commons 0",
	"Studio roar by AugustSandberg | License: Creative Commons 0",
	"Underground Ambient by TheoJT | License: Attribution 4.0",
	"Electronica Techno by TheoJT | License: Attribution 4.0",
	"knife_stabbing_water_melon_06212024 by Artninja | License: Attribution 4.0",
	"The Last gasp before death by randbsoundbites | License: Creative Commons 0",
	"Teleport-01b.wav by DWOBoyle | License: Attribution 4.0",
	"Arrow_Hit_1 by Mythmazter | License: Creative Commons 0",
	"War behind the Hills V2 by Blockfighter298 | License: Attribution 4.0",
]

signal closed

## Opens the panel unless one is already up. Returns the live panel either way.
## `host` is any node in the tree — like SettingsPanel, the panel parents itself
## to the scene root so a caller that frees itself can't take it along.
static func open(host: Node) -> CreditsPanel:
	var existing := _existing(host)
	if existing != null:
		return existing
	var panel := CreditsPanel.new()
	host.get_tree().root.add_child(panel)
	return panel

## Button behavior: a second press on the thing that opened it closes it again,
## rather than stacking a second copy.
static func toggle(host: Node) -> void:
	var existing := _existing(host)
	if existing != null:
		existing.close()
		return
	open(host)

static func _existing(host: Node) -> CreditsPanel:
	if host == null or not host.is_inside_tree():
		return null
	var found := host.get_tree().get_first_node_in_group(GROUP)
	return found as CreditsPanel

func _ready() -> void:
	# ALWAYS rather than PAUSABLE even though this panel doesn't pause anything
	# itself: it can be opened over a screen that already paused, and a frozen
	# modal with a dead CLOSE button is unrecoverable.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = LAYER
	add_to_group(GROUP)
	_build()

func _build() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0.1, 0.1, 0.1, 0.55)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	panel.add_theme_stylebox_override("panel", UIStyle.overlay_panel())
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	box.add_child(UIStyle.centered_label("CREDITS", UIStyle.SIZE_HEADING))

	for entry in CREDITS:
		box.add_child(UIStyle.centered_label("%s by %s" % [entry[0], entry[1]],
				UIStyle.SIZE_SUBHEAD))

	box.add_child(UIStyle.centered_label("AUDIO — Freesound.org", UIStyle.SIZE_BODY,
			UIStyle.GOLD))

	box.add_child(_build_attribution_list())

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	row.add_child(UIStyle.button("CLOSE", UIStyle.SIZE_SUBHEAD, close))

## The scrolling attribution rows. One label per sound rather than a single
## multi-line label so a long title wraps within its own row instead of pushing
## the rest of the list around.
func _build_attribution_list() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, LIST_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for line in AUDIO_ATTRIBUTION:
		var l := UIStyle.centered_label(line, UIStyle.SIZE_TINY, UIStyle.INK_MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(l)

	return scroll

func close() -> void:
	closed.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
