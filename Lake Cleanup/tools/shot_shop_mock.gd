## Saves a picture of each proposed upgrades-shop layout, over the real lake, in the game's
## own wood and the game's own font — plus the shop as it stands today, for comparison.
##
## Run it with the desktop build, not --headless: nothing renders under the dummy driver.
##   <godot> --path . tools/shot_shop_mock.tscn
##
## Writes `tools/last_shop_now.png` (today's shop, fresh and maxed) and
## `tools/last_shop_<layout>_<state>.png` for each of the three proposals. A probe, not a
## test: which of these to build is a thing to look at, not to assert.
extends Node

const ShopMock := preload("res://tools/shop_mock.gd")

## Every row, with the proposed name and the proposed `now -> next unit` value, at a fresh
## save and at the top of its curve. The prices are the real ones off the `.tres` curves.
## `key` and `board` match the live shop so the groups line up.
const ROWS := [
	[&"net_width", &"net", "Width", 0, "+0% → +35%", "$25", 20, "+700%", "$6820"],
	[&"net_strength", &"net", "Strength", 0, "Tier 0 → 1", "$60", 4, "Tier 4", "$4100"],
	[&"net_range", &"net", "Range", 0, "+0% → +40%", "$20", 20, "+800%", "$5760"],
	[&"reel", &"net", "Reel", 0, "+0% → +33%", "$14", 20, "+667%", "$3310"],
	[&"net_hold", &"net", "Catch", 0, "4 → 5 a cast", "$40", 20, "24 a cast", "$420000"],
	[&"lucky_haul", &"luck", "Lucky cast", 0, "0% → 6%", "$180", 10, "60%", "$21400"],
	[&"double_cast", &"luck", "Double cast", 0, "0% → 5%", "$220", 10, "50%", "$18600"],
	[&"boat_speed", &"boat", "Sailing", 0, "+0% → +40%", "$30", 20, "+800%", "$7300"],
	[&"cargo", &"boat", "Hold", 0, "4 → 5 aboard", "$40", 20, "24 aboard", "$420000"],
	[&"boat_volley", &"boat", "Loading", 0, "+0% → +18%", "$300", 4, "+150%", "$3194"],
	[&"fleet", &"boat", "Fleet", 0, "1 → 2 boats", "$200", 3, "4 boats", "$5000"],
	[&"dog_count", &"dog", "Pack", 0, "1 → 2 dogs", "$150", 3, "4 dogs", "$8112"],
	[&"dog_strength", &"dog", "Carry", 0, "Tier 0 → 1", "$120", 4, "Tier 4", "$5271"],
	[&"dog_fetch", &"dog", "Fetch", 0, "1 → 2 a trip", "$90", 4, "5 a trip", "$2400"],
	[&"dog_wait", &"dog", "Keenness", 0, "12s → 9s", "$70", 3, "4s", "$1800"],
	[&"recycle_bonus", &"luck", "Bonus yard", 0, "off → +15%", "$260", 8, "+120%", "$9300"],
	[&"bird_worth", &"luck", "Pigeons", 0, "$8 → $10", "$140", 8, "$34", "$7700"],
]

## Which rows a player can afford in each state. A shop where everything is buyable and one
## where nothing is says nothing about the row that cannot be: both are drawn.
const AFFORD_FRESH := [&"net_width", &"net_range", &"reel", &"net_hold", &"dog_wait"]
const AFFORD_MAXED := [&"net_hold", &"cargo", &"lucky_haul", &"bird_worth"]

const SHOTS := ["four_up"]

## A live recycle bonus, for the three ways of showing it. Metal, so the boosted column is
## in the middle of the plate rather than at an end, which is the harder case to lay out.
const BONUS := {"kind": 2, "pay": "$75", "pct": "+120%", "seconds": 22}
const BONUS_STYLES := ["star", "plate", "line"]

var _main: Node
var _mock: ShopMock


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_main)
	_run()


## One picture at a time, each set up and then saved on the next frame the renderer
## actually finishes. Driven by `frame_post_draw` rather than by a count of physics ticks:
## the lake behind these boards does not hold 60 fps at 1920x1080, so physics runs several
## times per drawn frame and a plan clocked on `_physics_process` saves whichever state the
## renderer had got to, not the one that was asked for.
func _run() -> void:
	await _drawn(8)
	_main.call(&"_set_menu", true)
	await _drawn(6)
	_save("last_shop_now")
	_build_mock()
	for layout in SHOTS:
		for worst in [false, true]:
			_mock.mode = StringName(layout)
			_mock.maxed = worst
			_mock.rows = _rows(worst)
			_mock.bonus = {}
			_mock.visible = true
			_mock.queue_redraw()
			await _drawn(2)
			_save("last_shop_%s_%s" % [layout, "maxed" if worst else "fresh"])
	# And the three ways of saying which material the recycle bonus is on, over a run where
	# the track has been bought and the bonus is live.
	_mock.maxed = true
	_mock.rows = _rows(true)
	_mock.bonus = BONUS
	for style in BONUS_STYLES:
		_mock.bonus_style = StringName(style)
		_mock.queue_redraw()
		await _drawn(2)
		_save("last_shop_bonus_%s" % style)
	get_tree().quit()


func _drawn(frames: int) -> void:
	for i in frames:
		await RenderingServer.frame_post_draw


## The mock stands on the HUD layer over the real shop, which is hidden under it.
func _build_mock() -> void:
	var skin: Control = _main.get_node(^"HUD/ShopSkin")
	_mock = ShopMock.new()
	_mock.sprites = skin.get(&"sprites")
	# The pricing plate's figures are the lake's own, worked out at today's rates, not a
	# second set written down here.
	_mock.legend = skin.get(&"legend")
	_mock.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skin.get_parent().add_child(_mock)
	skin.visible = false


## The rows in one state. `level` is the figure alone: the word "Lvl" is one the row does
## not need and a translation would have to carry.
func _rows(worst: bool) -> Array:
	var afford := AFFORD_MAXED if worst else AFFORD_FRESH
	var out: Array = []
	for line: Array in ROWS:
		out.append({
			"key": line[0],
			"board": line[1],
			"name": line[2],
			"level": str(line[6] if worst else line[3]),
			"value": String(line[7] if worst else line[4]),
			"cost": String(line[8] if worst else line[5]),
			"afford": line[0] in afford,
		})
	return out


func _save(name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://tools/%s.png" % name))
