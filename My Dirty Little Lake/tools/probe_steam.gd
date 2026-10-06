extends SceneTree
## Is GodotSteam loaded, does Steam start, and does it know the nine achievements? Writes
## tools/last_probe_steam.log. Starts Steam's API for the app, so run it only by hand, never
## from a harness.
##   godot --path . --headless --script res://tools/probe_steam.gd
## Waits up to WAIT seconds for the schema, which arrives after the API starts.
const WAIT := 10.0

var _steam: Object
var _out: FileAccess
var _t := 0.0


func _init() -> void:
	_out = FileAccess.open("res://tools/last_probe_steam.log", FileAccess.WRITE)
	_out.store_line("singleton %s" % Engine.has_singleton("Steam"))
	if not Engine.has_singleton("Steam"):
		_finish()
		return
	_steam = Engine.get_singleton("Steam")
	_out.store_line("init %s" % str(_steam.call(&"steamInitEx", 5375170, false)))
	_out.store_line("running %s  app %s" % [_steam.call(&"isSteamRunning"), _steam.call(&"getAppID")])
	_out.store_line("owns %s  logged on %s" % [_steam.call(&"isSubscribed"), _steam.call(&"loggedOn")])
	# Asks for this user's stats, which fetches the schema too, where the client has none.
	_out.store_line("has requestCurrentStats %s" % _steam.has_method(&"requestCurrentStats"))
	_out.store_line("requestUserStats %s" % str(_steam.call(&"requestUserStats", _steam.call(&"getSteamID"))))


func _process(delta: float) -> bool:
	if _steam == null:
		return true
	_steam.call(&"run_callbacks")
	_t += delta
	var count := int(_steam.call(&"getNumAchievements"))
	if count > 0 or _t > WAIT:
		_out.store_line("after %.1f s: %d achievements" % [_t, count])
		for i in count:
			var api := String(_steam.call(&"getAchievementName", i))
			_out.store_line("  %s  known to the game: %s  %s" % [api, Achievements.ALL.has(api),
				str(_steam.call(&"getAchievement", api))])
		for api: String in Achievements.ALL:
			_out.store_line("game id %s  on Steam: %s" % [api, str(_steam.call(&"getAchievement", api))])
		_finish()
	return false


func _finish() -> void:
	_out.close()
	quit()
