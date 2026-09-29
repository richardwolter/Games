extends PanelContainer
## A roster card that shows one crow's name, tier, XP bar, and status.

const CrowScript = preload("res://scripts/crow.gd")
const Care = preload("res://scripts/care.gd")
const StationsScript = preload("res://scripts/stations.gd")

var crow: CrowScript

@onready var name_label: Label = $VBox/NameLabel
@onready var tier_label: Label = $VBox/TierLabel
@onready var xp_bar: ProgressBar = $VBox/XPBar
@onready var status_label: Label = $VBox/StatusLabel

var care_label: Label
var stamina_bar: ProgressBar

func _ready() -> void:
	# stamina bar and care line, built here so the card scene stays as it was
	stamina_bar = xp_bar.duplicate()
	stamina_bar.max_value = Care.STAMINA_MAX
	$VBox.add_child(stamina_bar)
	care_label = status_label.duplicate()
	$VBox.add_child(care_label)

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
	stamina_bar.value = crow.stamina
	var care := "Stamina %d  -  %s" % [int(round(crow.stamina)), StationsScript.label_of(crow.station)]
	if crow.injury_days > 0:
		care += "  -  HURT (%dd)" % crow.injury_days
	elif crow.stamina < Care.LOW_STAMINA:
		care += "  -  tired"
	care_label.text = care
