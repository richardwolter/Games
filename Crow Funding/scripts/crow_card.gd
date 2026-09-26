extends PanelContainer
## A roster card that shows one crow's name, tier, XP bar, and status.

const CrowScript = preload("res://scripts/crow.gd")

var crow: CrowScript

@onready var name_label: Label = $VBox/NameLabel
@onready var tier_label: Label = $VBox/TierLabel
@onready var xp_bar: ProgressBar = $VBox/XPBar
@onready var status_label: Label = $VBox/StatusLabel

func setup(crow_node: CrowScript) -> void:
	crow = crow_node
	name_label.text = crow.crow_name
	refresh()

func refresh() -> void:
	if crow == null:
		return
	tier_label.text = "%s  (Tier %d)" % [crow.get_tier_name(), crow.tier + 1]
	var lo: int = crow.xp_floor()
	var hi: int = crow.xp_ceiling()
	xp_bar.max_value = maxi(1, hi - lo)
	xp_bar.value = clampi(crow.xp - lo, 0, int(xp_bar.max_value))
	status_label.text = crow.status
