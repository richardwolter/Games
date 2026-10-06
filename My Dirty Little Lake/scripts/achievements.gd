## The `Achievements` autoload: Steam's achievements for My Dirty Little Lake (app 5375170),
## and the Rich Presence line friends see (`presence_clean`).
##
## The lake decides what is earned and calls `unlock`; this node only remembers it and tells
## Steam (2026-10-06, `/grill-me` with Richard). Two rules:
##
## - **The game runs the same without Steam.** GodotSteam is a GDExtension
##   (`addons/godotsteam/`); without it, without the Steam client, or under `--headless`
##   nothing is started and nothing fails. No relaunch through Steam, no DRM.
## - **What is earned is kept here, not in the run's save** (`user://achievements.cfg`), so
##   it survives a New game, which deletes the save. Whatever is in the file is pushed to
##   Steam the first time Steam starts, so an achievement earned offline or outside Steam
##   lands the next time the game runs under it.
##
## Steam is started lazily, on the first `sync` or `unlock`, which only the game's own lake
## calls (`Lake._owns_achievements`): a harness or a probe never reaches this node, so it
## never shows the account as playing.
##
## Not in `project.godot`'s autoloads (the open editor re-saves that file from memory):
## `Prefs._ready` hangs it off the root as `Achievements`.
class_name Achievements
extends Node

const APP_ID := 5375170

## The API names, as entered on the Steamworks partner site (docs/steam/achievements.md).
const DECORAHOLIC := "DECORAHOLIC"
const FRIEND_OF_NATURE := "FRIEND_OF_NATURE"
const BEST_PALS := "BEST_PALS"
const GREAT_NET := "GREAT_NET"
const MAXIMALIST := "MAXIMALIST"
const TWISTERED := "TWISTERED"
const HONEYMAKER := "HONEYMAKER"
const ISLAND_DJ := "ISLAND_DJ"
const CHEAPSKATE := "CHEAPSKATE"
const ALL := [
	DECORAHOLIC, FRIEND_OF_NATURE, BEST_PALS, GREAT_NET, MAXIMALIST,
	TWISTERED, HONEYMAKER, ISLAND_DJ, CHEAPSKATE,
]

const FILE := "user://achievements.cfg"

## Earned ids, in the order they were earned.
var earned: Array[String] = []

var _steam: Object = null
var _tried := false
## Steam has been told something since the last `storeStats`.
var _dirty := false
## Ids Steam would not take yet (its stats not in, or the achievement not published on
## Steamworks yet), asked again every `RETRY` seconds.
var _pending: Array[String] = []
var _retry_in := 0.0
## The figure last sent as Rich Presence.
var _presence := ""
const RETRY := 5.0


static func main() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(^"Achievements")


func _ready() -> void:
	_read()


## Push everything already earned to Steam. The game's lake calls it once it has loaded.
func sync() -> void:
	if not _start():
		return
	for id in earned:
		_tell_steam(id)


## Earn one. Known ids only; a second call is nothing.
func unlock(id: String) -> void:
	if not ALL.has(id):
		push_warning("Achievements: unknown id %s" % id)
		return
	if not earned.has(id):
		earned.append(id)
		_write()
	if _start():
		_tell_steam(id)


func has(id: String) -> bool:
	return earned.has(id)


## Rich Presence (2026-10-06, Richard: percent only): friends see "Cleaning the lake: 42%
## clean" whatever the player is doing. The words are the `#Status` token of the localization
## file uploaded on Steamworks (`docs/steam/rich_presence.vdf`); the game sets only the figure.
## Sent only when the whole percent changes. The game's own lake calls it, like `unlock`.
func presence_clean(percent: int) -> void:
	if not _start():
		return
	var figure := "%d%%" % clampi(percent, 0, 100)
	if figure == _presence:
		return
	_presence = figure
	_steam.call(&"setRichPresence", "percent", figure)
	_steam.call(&"setRichPresence", "steam_display", "#Status")


## Whether Steam is up and talking. For the probe and the log, nothing else reads it.
func steam_up() -> bool:
	return _steam != null


func _process(delta: float) -> void:
	if _steam == null:
		return
	if not _pending.is_empty():
		_retry_in -= delta
		if _retry_in <= 0.0:
			_retry_in = RETRY
			for id in _pending.duplicate():
				_pending.erase(id)
				_tell_steam(id)
	if _dirty:
		_dirty = false
		_steam.call(&"storeStats")


func _tell_steam(id: String) -> void:
	var got: Variant = _steam.call(&"getAchievement", id)
	if got is Dictionary and bool((got as Dictionary).get("achieved", false)):
		return
	if bool(_steam.call(&"setAchievement", id)):
		_dirty = true
	elif not _pending.has(id):
		_pending.append(id)


## Start Steam's API once. False, and quietly, wherever it cannot be had.
func _start() -> bool:
	if _tried:
		return _steam != null
	_tried = true
	if DisplayServer.get_name() == "headless" or not Engine.has_singleton("Steam"):
		return false
	var steam := Engine.get_singleton("Steam")
	# Callbacks embedded: GodotSteam runs them itself every frame.
	var res: Variant = steam.call(&"steamInitEx", APP_ID, true)
	if not res is Dictionary or int((res as Dictionary).get("status", -1)) != 0:
		return false
	_steam = steam
	return true


func _read() -> void:
	earned.clear()
	var cfg := ConfigFile.new()
	if cfg.load(FILE) != OK:
		return
	for id: Variant in cfg.get_value("earned", "ids", []) as Array:
		if ALL.has(String(id)) and not earned.has(String(id)):
			earned.append(String(id))


func _write() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("earned", "ids", earned)
	cfg.save(FILE)
