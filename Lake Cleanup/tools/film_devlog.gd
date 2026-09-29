extends "res://tools/film_trailer.gd"
## Films the shots the devlog is cut from, on the trailer's own machinery: same posing, same
## frame dump into tools/film/<shot>/, a save and a log of its own. The cut is
## `marketing/My Dirty Little Lake/devlog/build_devlog.py`, on Save ME's beat.
##
##   godot --path . --fixed-fps 60 res://tools/film_devlog.tscn --log-file tools/film/last_devlog_engine.log
##
## `FILM_ONLY=devlog_day_rain` re-shoots by name. The wash, the wildlife and the dirty lake
## under the logo are the trailer's own frames (`wash`, `wildlife`, `clean_hold`), not
## filmed here.
##
## The shots run dirtiest first, because thinning only ever cleans: the day and the rain on
## a nearly fresh lake, the plain casts widening as the water clears to half, then the gold
## and the double cast over the half-clean lake.

## Kept frames the day runs from first light to late afternoon over, and where the shower
## and the two flashes come in.
const DAY_RUN := 600
const RAIN_AT := 540
const FLASHES := [780, 960]
## Where the light ends: the day's `turn_at`, the last of the afternoon before it eases back.
const DAY_END := 0.88


func _init() -> void:
	SAVE_PATH = "user://film_devlog.save"
	LOG_PATH = "res://tools/film/last_devlog.log"


func _plan() -> void:
	_shots = [
		# One locked camera over the island: the sun swings from morning to late afternoon,
		# then a shower rolls in with two flashes. The light is the game's own, no night.
		["devlog_day_rain", 20.0, func() -> void:
			_hide_boats()
			_stand(Vector2(-3.6, 3.6), LEFT)
			_thin(0.1)
			_zoom(3)
			_hold = Iso.tile_to_world(Iso.ISLAND_CENTRE.x + 1.5, Iso.ISLAND_CENTRE.y + 1.5),
		func(f: int) -> void:
			var k := f - SETTLE
			var day: DayCycle = _main.get(&"_day")
			if k <= DAY_RUN:
				day.phase = DAY_END * clampf(float(maxi(k, 0)) / float(DAY_RUN), 0.0, 1.0)
			var weather: Weather = _main.get(&"_weather")
			if k == RAIN_AT:
				weather.pour(60.0)
			if k in FLASHES:
				weather.strike()
			if k % 120 == 0:
				_say("  day %d: phase %.2f rain %.2f" % [k, day.phase, weather.rain()])],
		# The plain casts, net widening and the water clearing: Width 0 on the dirty lake, then
		# the top of the track over a lake half clean. The trailer's ferries stand between them
		# in the cut (2026-09-25, Richard: the middle cast out, a boat scene in).
		["devlog_net_small", 6.0, func() -> void:
			_hide_boats()
			_dry()
			_zoom(6)
			_main.set(&"net_width_level", 0)
			_stand(Vector2(3.6, -3.6), ACROSS)
			_thin(0.15, [_angler.tile_pos + ACROSS.normalized() * 6.0])
			_free(),
		func(f: int) -> void:
			if f == SETTLE + 36:
				_cast(ACROSS, 6.0)],
		["devlog_net_wide", 6.0, func() -> void:
			_hide_boats()
			_dry()
			_zoom(5)
			_main.set(&"net_width_level", 20)
			_stand(Vector2(3.6, -3.6), ACROSS)
			_thin(0.5, [_angler.tile_pos + ACROSS.normalized() * 12.0])
			_free(),
		func(f: int) -> void:
			if f == SETTLE + 36:
				_cast(ACROSS, 12.0)],
		# The gold net alone, then a plain net with its double beside it, over half clean.
		["devlog_net_lucky", 8.5, func() -> void:
			_hide_boats()
			_dry()
			_zoom(6)
			_main.set(&"net_width_level", 12)
			_stand(Vector2(3.6, -3.6), ACROSS)
			_thin(0.55, [_angler.tile_pos + ACROSS.normalized() * 8.0])
			_free(),
		func(f: int) -> void:
			if f == SETTLE + 36:
				_cast(ACROSS, 8.0, true, false)],
		["devlog_net_double", 8.5, func() -> void:
			_hide_boats()
			_dry()
			_zoom(5)
			_main.set(&"net_width_level", 12)
			_stand(Vector2(-3.6, 3.6), LEFT)
			_thin(0.55, [_angler.tile_pos + LEFT.normalized() * 8.0], 8.0)
			_free(),
		func(f: int) -> void:
			if f == SETTLE + 36:
				_cast(LEFT, 8.0, false, true)],
	]
	var only := OS.get_environment("FILM_ONLY")
	if only != "":
		var names := only.split(",")
		_shots = _shots.filter(func(s: Array) -> bool: return s[0] in names)


## The shower and the day put back after the day shot, so the casts are in fair weather at
## the day's own start: a forced `pour` runs its full length otherwise.
func _dry() -> void:
	var weather: Weather = _main.get(&"_weather")
	weather.set(&"_left", 0.0)
	weather.set(&"_rain", 0.0)
	(_main.get(&"_day") as DayCycle).phase = 0.35
