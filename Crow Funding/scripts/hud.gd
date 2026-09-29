extends CanvasLayer
const Text = preload("res://scripts/text.gd")
## HUD: balcony signs and crates (labels, title, roster notice board, Pantry food
## panel, Upgrades shop, loot log), plus the end-of-day daily report overlay.

const CrowCardScene = preload("res://scenes/crow_card.tscn")
const StationsScript = preload("res://scripts/stations.gd")
const Ink = preload("res://scripts/ink.gd")

@onready var money_label: Label = %MoneyLabel
@onready var day_label: Label = %DayLabel
@onready var title_label: Label = %TitleLabel
@onready var loot_log: Label = %LootLog
@onready var roster: VBoxContainer = %Roster
@onready var pantry: PanelContainer = %Pantry
@onready var meal_selector: HBoxContainer = %MealSelector
@onready var food_rows: VBoxContainer = %FoodRows
@onready var upgrade_rows: VBoxContainer = %UpgradeRows
@onready var crew_label: Label = %CrewLabel
@onready var recruit_cost_label: Label = %RecruitCostLabel
@onready var recruit_button: Button = %RecruitButton
@onready var report_overlay: Control = %ReportOverlay
@onready var report_title: Label = %ReportTitle
@onready var report_rows: VBoxContainer = %ReportRows
@onready var report_totals: Label = %ReportTotals
@onready var report_start: Button = %ReportStartButton

var game = null

# Ink on paper, like the drawings: every label the HUD builds in code reads this.
const INK := Color(0.1, 0.1, 0.11)

var _stock_labels: Array[Label] = []
var _meal_buttons: Array[Button] = []
var _food_buy_buttons: Array[Button] = []
var _upgrade_level_labels: Array[Label] = []
var _upgrade_cost_labels: Array[Label] = []
var _upgrade_buttons: Array[Button] = []
var _btn_normal: StyleBoxFlat
var _btn_pressed: StyleBoxFlat
var _btn_hover: StyleBoxFlat

func setup(game_node) -> void:
	game = game_node
	_apply_ink_theme()
	title_label.text = Text.HUD_TITLE
	rebuild_roster()
	_build_pantry(game_node)
	_build_upgrades(game_node)
	recruit_button.pressed.connect(game_node.recruit_crow)
	report_start.pressed.connect(game_node.start_new_day)
	refresh(game_node)
	render_log(game_node.log_lines)

func _apply_ink_theme() -> void:
	# the one ink look (scripts/ink.gd); the scene's own panel and font-colour
	# overrides are cleared so it shows through
	for child in get_children():
		if child is Control:
			Ink.strip(child)
			(child as Control).theme = Ink.theme()
	get_node("Pantry/VBox/Title").text = Text.HUD_PANTRY
	get_node("Upgrades/VBox/Title").text = Text.HUD_UPGRADES
	for title in [get_node("Pantry/VBox/Title"), get_node("Upgrades/VBox/Title"), report_title]:
		title.add_theme_font_size_override("font_size", Ink.TEXT_HEAD)
	money_label.add_theme_font_size_override("font_size", Ink.TEXT_HEAD)
	day_label.add_theme_font_size_override("font_size", Ink.TEXT_HEAD)
	var dispatch: Button = get_node("DispatchButton")
	dispatch.theme_type_variation = &"InkAccent"
	dispatch.add_theme_font_size_override("font_size", Ink.TEXT_HEAD)
	for box in [pantry, get_node("Upgrades")]:
		var tight := Ink.panel()
		tight.set_content_margin_all(5)
		tight.content_margin_left = 8
		box.add_theme_stylebox_override("panel", tight)
	loot_log.add_theme_font_size_override("font_size", Ink.TEXT_SMALL)
	# the loose labels read as paper slips with the panels' ink shadow
	for slip in [money_label, day_label, loot_log]:
		var sb := Ink.panel()
		sb.shadow_offset = Vector2(3, 3)
		sb.set_content_margin_all(6)
		slip.add_theme_stylebox_override("normal", sb)
	# the report sits on a veil like every board
	var veil := ColorRect.new()
	veil.color = Color(Ink.PAPER, 0.55)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	report_overlay.add_child(veil)
	report_overlay.move_child(veil, 0)
	get_node("ReportOverlay/Center/Panel").custom_minimum_size = Vector2(460, 0)
	report_start.theme_type_variation = &"InkAccent"

func rebuild_roster() -> void:
	for child in roster.get_children():
		roster.remove_child(child)
		child.free()
	if game == null:
		return
	var crew: Array = []
	for node in game.crows.get_children():
		if node.has_method("grant_xp"):
			crew.append(node)
	for start in range(0, crew.size(), 3):
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		row.add_theme_constant_override("separation", 6)
		roster.add_child(row)
		var end := mini(start + 3, crew.size())
		for i in range(start, end):
			var card: PanelContainer = CrowCardScene.instantiate()
			row.add_child(card)
			if card.has_method("setup"):
				card.setup(crew[i])

## Buttons built in code take the ink theme from the panel; only the size here.
func _make_wood_button(btn: Button) -> void:
	btn.add_theme_font_size_override("font_size", Ink.TEXT_SMALL)

func _wood_style(col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(3)
	sb.set_border_width_all(2)
	sb.border_color = INK
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	sb.content_margin_top = 1.0
	sb.content_margin_bottom = 1.0
	return sb

func _build_pantry(game_node) -> void:
	for child in food_rows.get_children():
		child.queue_free()
	_stock_labels.clear()
	_food_buy_buttons.clear()
	for i in game_node.FOODS.size():
		var food: Dictionary = game_node.FOODS[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_label := Label.new()
		name_label.text = str(food.name)
		name_label.custom_minimum_size = Vector2(56, 0)
		row.add_child(name_label)
		var stock_label := Label.new()
		stock_label.custom_minimum_size = Vector2(34, 0)
		row.add_child(stock_label)
		_stock_labels.append(stock_label)
		var effect_label := Label.new()
		effect_label.text = str(food.effect)
		effect_label.add_theme_font_size_override("font_size", 10)
		effect_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(effect_label)
		var buy_button := Button.new()
		buy_button.text = Text.SHOP_BUY_BATCH
		buy_button.pressed.connect(game_node.buy_food.bind(str(food.key)))
		_make_wood_button(buy_button)
		row.add_child(buy_button)
		_food_buy_buttons.append(buy_button)
		food_rows.add_child(row)
	_meal_buttons.clear()
	for child in meal_selector.get_children():
		child.queue_free()
	for i in game_node.FOODS.size():
		var food: Dictionary = game_node.FOODS[i]
		var btn := Button.new()
		btn.text = str(food.name)
		btn.toggle_mode = true
		btn.pressed.connect(game_node.select_food.bind(str(food.key)))
		_make_wood_button(btn)
		meal_selector.add_child(btn)
		_meal_buttons.append(btn)

func _build_upgrades(game_node) -> void:
	for child in upgrade_rows.get_children():
		upgrade_rows.remove_child(child)
		child.free()
	_upgrade_level_labels.clear()
	_upgrade_cost_labels.clear()
	_upgrade_buttons.clear()
	for track in game_node.UPGRADES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var name_label := Label.new()
		name_label.text = str(track.name)
		name_label.custom_minimum_size = Vector2(84, 0)
		row.add_child(name_label)
		var level_label := Label.new()
		level_label.custom_minimum_size = Vector2(40, 0)
		row.add_child(level_label)
		_upgrade_level_labels.append(level_label)
		var cost_label := Label.new()
		cost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(cost_label)
		_upgrade_cost_labels.append(cost_label)
		var buy_button := Button.new()
		buy_button.text = Text.SHOP_BUY
		buy_button.pressed.connect(game_node.buy_upgrade.bind(str(track.key)))
		_make_wood_button(buy_button)
		row.add_child(buy_button)
		_upgrade_buttons.append(buy_button)
		upgrade_rows.add_child(row)

func refresh(game_node) -> void:
	money_label.text = Text.HUD_COINS % game_node.money
	day_label.text = Text.HUD_DAY % game_node.day
	for row in roster.get_children():
		for card in row.get_children():
			if card.has_method("refresh"):
				card.refresh()
	var shop_allowed: bool = game_node.can_shop()
	for i in _stock_labels.size():
		var food: Dictionary = game_node.FOODS[i]
		_stock_labels[i].text = Text.PANTRY_STOCK % game_node.food_stock[food.key]
		_food_buy_buttons[i].disabled = not shop_allowed or int(game_node.money) < int(food.cost) * game_node.FOOD_BATCH
	for i in _meal_buttons.size():
		var food: Dictionary = game_node.FOODS[i]
		var selected: bool = str(food.key) == str(game_node.selected_food)
		_meal_buttons[i].button_pressed = selected
		_meal_buttons[i].disabled = not shop_allowed
		if selected:
			_meal_buttons[i].text = str(food.name) + Text.PANTRY_SELECTED
		else:
			_meal_buttons[i].text = str(food.name)
	for i in _upgrade_level_labels.size():
		var track: Dictionary = game_node.UPGRADES[i]
		var key: String = str(track.key)
		var level := int(game_node.upgrade_levels[key])
		var costs: Array = track.costs
		_upgrade_level_labels[i].text = Text.SHOP_LEVEL % [level, costs.size()]
		if level >= costs.size():
			_upgrade_cost_labels[i].text = Text.SHOP_MAX_CAPS
			_upgrade_buttons[i].disabled = true
			_upgrade_buttons[i].text = Text.SHOP_MAX
		else:
			var cost := int(costs[level])
			_upgrade_cost_labels[i].text = Text.SHOP_PRICE % cost
			_upgrade_buttons[i].disabled = not shop_allowed or int(game_node.money) < cost
			_upgrade_buttons[i].text = Text.SHOP_BUY
	var crew_total := 0
	for node in game_node.crows.get_children():
		if node.has_method("grant_xp"):
			crew_total += 1
	var cap := int(game_node.ROSTER_CAP)
	var full := crew_total >= cap
	crew_label.text = Text.RECRUIT_CREW % [crew_total, cap]
	var rec_cost := int(game_node._recruit_cost())
	var can_recruit: bool = shop_allowed and not full and int(game_node.money) >= rec_cost
	if full:
		recruit_cost_label.text = Text.RECRUIT_FULL
		recruit_button.disabled = true
		recruit_button.text = Text.RECRUIT_FULL
	else:
		recruit_cost_label.text = Text.RECRUIT_NEXT % rec_cost
		recruit_button.disabled = not can_recruit
		recruit_button.text = Text.RECRUIT

func show_report(day_n: int, crew: Array) -> void:
	report_title.text = Text.REPORT_TITLE % day_n
	for child in report_rows.get_children():
		report_rows.remove_child(child)
		child.free()
	var total_value := 0
	var total_objects := 0
	for crow in crew:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name_label := Label.new()
		name_label.text = str(crow.crow_name)
		name_label.custom_minimum_size = Vector2(112, 0)
		row.add_child(name_label)
		var tier_label := Label.new()
		tier_label.text = str(crow.get_tier_name())
		tier_label.custom_minimum_size = Vector2(92, 0)
		tier_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.31, 1))
		row.add_child(tier_label)
		var xp_label := Label.new()
		xp_label.text = Text.REPORT_XP % crow.day_xp
		xp_label.custom_minimum_size = Vector2(56, 0)
		row.add_child(xp_label)
		var obj_label := Label.new()
		obj_label.text = Text.REPORT_OBJECTS % crow.day_objects
		obj_label.custom_minimum_size = Vector2(96, 0)
		row.add_child(obj_label)
		var care_label := Label.new()
		var care := Text.REPORT_CARE % [StationsScript.label_of(crow.station), int(round(crow.day_stamina_from)), int(round(crow.stamina))]
		if crow.day_injured:
			care += Text.REPORT_HURT_TODAY
		elif crow.injury_days > 0:
			care += Text.REPORT_HURT_DAYS % crow.injury_days
		care_label.text = care
		care_label.custom_minimum_size = Vector2(230, 0)
		row.add_child(care_label)
		var val_label := Label.new()
		val_label.text = Text.REPORT_VALUE % crow.day_value
		val_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val_label)
		report_rows.add_child(row)
		total_value += crow.day_value
		total_objects += crow.day_objects
	report_totals.text = Text.REPORT_TOTALS % [total_value, total_objects]
	report_start.text = Text.REPORT_START % (day_n + 1)
	report_overlay.visible = true

func hide_report() -> void:
	report_overlay.visible = false

func flash_money() -> void:
	money_label.pivot_offset = money_label.size * 0.5
	money_label.scale = Vector2(1.12, 1.12)
	var tween := create_tween()
	tween.tween_property(money_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func render_log(lines: Array) -> void:
	var tail: Array = lines.slice(-8)
	var text := Text.LOG_TITLE
	for line in tail:
		text += "\n" + line
	loot_log.text = text