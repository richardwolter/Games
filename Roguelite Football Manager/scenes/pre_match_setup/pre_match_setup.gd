extends Control

@onready var title_label: Label = $MarginContainer/MainRow/Sidebar/TitleLabel
@onready var formation_option: OptionButton = $MarginContainer/MainRow/Sidebar/FormationBox/FormationOption
@onready var pitch_container: VBoxContainer = $MarginContainer/MainRow/MainArea/PitchPanel/PitchContainer
@onready var bench_area: BenchDropArea = $MarginContainer/MainRow/MainArea/BenchPanel
@onready var bench_container: VBoxContainer = $MarginContainer/MainRow/MainArea/BenchPanel/BenchVBox/BenchScroll/BenchContainer
@onready var search_edit: LineEdit = $MarginContainer/MainRow/MainArea/BenchPanel/BenchVBox/SearchRow/SearchEdit
@onready var captain_option: OptionButton = $MarginContainer/MainRow/Sidebar/CaptainBox/CaptainOption
@onready var status_label: Label = $MarginContainer/MainRow/Sidebar/StatusLabel
@onready var auto_fill_button: Button = $MarginContainer/MainRow/Sidebar/ActionBox/AutoFillButton
@onready var play_match_button: Button = $MarginContainer/MainRow/Sidebar/ActionBox/PlayMatchButton
@onready var back_button: Button = $MarginContainer/MainRow/Sidebar/ActionBox/BackButton

const CATEGORY_ORDER := [Formation.SlotCategory.GK, Formation.SlotCategory.DEF, Formation.SlotCategory.MID, Formation.SlotCategory.FWD]
const CATEGORY_LABELS := {
	Formation.SlotCategory.GK: "Goalkeepers",
	Formation.SlotCategory.DEF: "Defenders",
	Formation.SlotCategory.MID: "Midfielders",
	Formation.SlotCategory.FWD: "Forwards",
}
const BENCH_GRID_COLUMNS := 5

var _formations: Array = []
var _slot_controls: Array = []
var _bench_filter: String = ""

func _ready() -> void:
	_formations = FormationLibrary.get_all()
	for formation in _formations:
		formation_option.add_item(formation.formation_name)
	formation_option.item_selected.connect(_on_formation_selected)
	captain_option.item_selected.connect(_on_captain_selected)
	bench_area.player_returned.connect(_on_player_returned)
	search_edit.text_changed.connect(_on_search_text_changed)
	auto_fill_button.pressed.connect(_on_auto_fill_pressed)
	play_match_button.pressed.connect(_on_play_match_pressed)
	back_button.pressed.connect(_on_back_pressed)
	GameState.lineup_changed.connect(_refresh)

	if GameState.formation == null:
		GameState.set_formation(_formations[0])
	else:
		var index: int = _formations.find(GameState.formation)
		formation_option.select(max(index, 0))
	_refresh()

func _on_formation_selected(index: int) -> void:
	GameState.set_formation(_formations[index])

func _on_captain_selected(index: int) -> void:
	GameState.set_captain(captain_option.get_item_metadata(index))

func _on_player_returned(source_slot: int) -> void:
	GameState.clear_slot(source_slot)

func _on_search_text_changed(new_text: String) -> void:
	_bench_filter = new_text.strip_edges().to_lower()
	_rebuild_bench()

func _on_slot_player_dropped(slot_index: int, player: Player) -> void:
	GameState.assign_to_slot(slot_index, player)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/club_management/club_management.tscn")

## Fills only currently-empty slots with the best remaining bench players
## (greedy: repeatedly assign the highest overall-x-eligibility match across
## all empty slots). Never touches slots the designer has already filled.
func _on_auto_fill_pressed() -> void:
	var formation: Formation = GameState.formation
	if formation == null:
		return
	var empty_slots: Array = []
	for i in GameState.lineup.size():
		if GameState.lineup[i] == null:
			empty_slots.append(i)
	if empty_slots.is_empty():
		return
	var available: Array = GameState.get_bench()
	while not empty_slots.is_empty() and not available.is_empty():
		var best_score: float = -1.0
		var best_slot: int = -1
		var best_player: Player = null
		for slot_index in empty_slots:
			var category: Formation.SlotCategory = formation.slots[slot_index]
			for player in available:
				var score: float = player.get_overall() * PositionCompatibility.get_best_multiplier(player, category)
				if score > best_score:
					best_score = score
					best_slot = slot_index
					best_player = player
		if best_player == null or best_score <= 0.0:
			break
		GameState.assign_to_slot(best_slot, best_player)
		empty_slots.erase(best_slot)
		available.erase(best_player)

func _on_play_match_pressed() -> void:
	GameState.pending_opponent = OpponentLineupBuilder.build()
	get_tree().change_scene_to_file("res://scenes/live_match/live_match.tscn")

func _refresh() -> void:
	var club := GameState.club
	var formation: Formation = GameState.formation
	title_label.text = "%s FC — Pre-Match Setup" % (club.club_name if club else "")
	_rebuild_pitch(formation)
	_rebuild_bench()
	_rebuild_captain_options()
	var filled: int = 0
	for player in GameState.lineup:
		if player != null:
			filled += 1
	status_label.text = "Lineup: %d/%d filled" % [filled, GameState.lineup.size()]
	play_match_button.disabled = filled < GameState.lineup.size()

func _rebuild_pitch(formation: Formation) -> void:
	for child in pitch_container.get_children():
		child.queue_free()
	_slot_controls.clear()
	if formation == null:
		return
	var current_row: HBoxContainer = null
	var current_category = null
	for i in formation.slots.size():
		var category = formation.slots[i]
		if current_row == null or category != current_category:
			current_row = HBoxContainer.new()
			current_row.add_theme_constant_override("separation", 12)
			pitch_container.add_child(current_row)
			current_category = category
		var slot := LineupSlot.new()
		current_row.add_child(slot)
		slot.set_slot(i, category)
		if i < GameState.lineup.size():
			slot.set_player(GameState.lineup[i])
		slot.player_dropped.connect(_on_slot_player_dropped)
		_slot_controls.append(slot)

func _rebuild_bench() -> void:
	for child in bench_container.get_children():
		child.queue_free()
	var grouped: Dictionary = {}
	for category in CATEGORY_ORDER:
		grouped[category] = []
	for player in GameState.get_bench():
		if not _matches_bench_filter(player):
			continue
		var category: Formation.SlotCategory = PositionCompatibility.get_natural_category(player)
		grouped[category].append(player)

	var any_shown: bool = false
	for category in CATEGORY_ORDER:
		var players: Array = grouped[category]
		if players.is_empty():
			continue
		any_shown = true
		var header := Label.new()
		header.text = "%s (%d)" % [CATEGORY_LABELS[category], players.size()]
		header.add_theme_font_size_override("font_size", 15)
		bench_container.add_child(header)

		var grid := GridContainer.new()
		grid.columns = BENCH_GRID_COLUMNS
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		bench_container.add_child(grid)
		for player in players:
			var chip := PlayerChip.new()
			chip.player = player
			chip.player_returned.connect(_on_player_returned)
			grid.add_child(chip)

	if not any_shown:
		var empty_label := Label.new()
		empty_label.text = "No bench players match \"%s\"." % _bench_filter if not _bench_filter.is_empty() else "No bench players."
		bench_container.add_child(empty_label)

func _matches_bench_filter(player: Player) -> bool:
	if _bench_filter.is_empty():
		return true
	if player.player_name.to_lower().contains(_bench_filter):
		return true
	for position in player.positions:
		var position_name: String = PlayerChip.POSITION_NAMES.get(position, "")
		if position_name.to_lower().contains(_bench_filter):
			return true
	return false

func _rebuild_captain_options() -> void:
	captain_option.clear()
	var captain_index: int = -1
	var lineup_players: Array = []
	for player in GameState.lineup:
		if player != null:
			lineup_players.append(player)
	for player in lineup_players:
		captain_option.add_item(player.player_name)
		captain_option.set_item_metadata(captain_option.item_count - 1, player)
		if player == GameState.captain:
			captain_index = captain_option.item_count - 1
	if lineup_players.is_empty():
		captain_option.add_item("No lineup players yet")
		captain_option.disabled = true
	else:
		captain_option.disabled = false
		if captain_index == -1:
			GameState.set_captain(lineup_players[0])
		else:
			captain_option.select(captain_index)
