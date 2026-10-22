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
##
## **It also keeps the Donation Bank's ledger** (`bank`, 2026-10-22): this account's one gift
## and the last global total, in the same file, and the two aggregated stats Steam sums over
## every player (`DONATED`, `DONORS`; entered on Steamworks as `docs/steam/donation_bank.md`
## says). Here because Steam is started here, by the same rules.
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

## The Donation Bank's two stats: this account's gift (INT, aggregated, increment only, max
## `DonationBank.MOST`) and whether it gave (INT, aggregated, increment only, max 1). Steam's
## global total of each is every player's added up.
const DONATED := "DONATED"
const DONORS := "DONORS"
## The least time between two asks for the global total, and how long an ask may go
## unanswered before it is given up.
const GLOBAL_GAP := 30.0
const GLOBAL_WAIT := 15.0
## How long to wait for the account's own stats before acting without them.
const STATS_WAIT := 10.0

## Earned ids, in the order they were earned.
var earned: Array[String] = []
## Where `earned` and the bank's ledger are kept. The harness points it elsewhere.
var path := FILE
## The Donation Bank's ledger: the game's own, the one the lake's board shows.
var bank := DonationBank.new()

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
## Whether the account's own stats are in (`user_stats_received`, or `STATS_WAIT` gone by), so
## its stats can be read and set. The gift waits for it, and is tried again every `RETRY`.
var _stats_in := false
var _stats_wait := STATS_WAIT
var _gift_retry := 0.0
## When the global total was last asked for, in seconds of the engine's clock.
var _asked_at := -1000.0


static func main() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(^"Achievements")


func _ready() -> void:
	_read()
	bank.file = path
	bank.read()


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


## The bank has just taken this account's gift: tell Steam, now or once it can be told.
func donated() -> void:
	if _start():
		_settle_gift()


## Ask Steam for every player's total. False where there is no Steam to ask; a second ask
## inside `GLOBAL_GAP` of an answered one is nothing (the total moves slowly, and Steam limits
## how often it may be asked).
func refresh_global() -> bool:
	if not _start():
		return false
	var now := Time.get_ticks_msec() / 1000.0
	if bank.asking or (bank.live and now - _asked_at < GLOBAL_GAP):
		return true
	_asked_at = now
	bank.asking = true
	bank.changed.emit()
	_steam.call(&"requestGlobalStats", 0)
	return true


func _process(delta: float) -> void:
	if _steam == null:
		return
	_tend_bank(delta)
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


## The bank's side of a frame with Steam up: the account's stats given up on after
## `STATS_WAIT`, a gift Steam would not take yet tried again, an ask that never came back
## dropped.
func _tend_bank(delta: float) -> void:
	if not _stats_in:
		_stats_wait -= delta
		if _stats_wait <= 0.0:
			_stats_in = true
			_settle_gift()
	elif bank.given > 0 and not bank.sent:
		_gift_retry -= delta
		if _gift_retry <= 0.0:
			_gift_retry = RETRY
			_settle_gift()
	if bank.asking and Time.get_ticks_msec() / 1000.0 - _asked_at > GLOBAL_WAIT:
		bank.asking = false
		bank.changed.emit()


## Square the ledger with the account's own stats. **Steam is what says whether this account
## has given**, wherever it gave: a gift made on another computer comes into this ledger, and
## a gift made offline here is sent unless the account turns out to have given already.
func _settle_gift() -> void:
	if _steam == null or not _stats_in:
		return
	if int(_steam.call(&"getStatInt", DONORS)) >= 1:
		if bank.given <= 0:
			bank.given = maxi(1, int(_steam.call(&"getStatInt", DONATED)))
			bank.floor_total = maxi(bank.floor_total, bank.total + bank.given)
		bank.sent = true
		bank.write()
		bank.changed.emit()
		return
	if bank.given <= 0 or bank.sent:
		return
	var told := bool(_steam.call(&"setStatInt", DONATED, bank.given))
	told = bool(_steam.call(&"setStatInt", DONORS, 1)) and told
	if not told:
		# The stats not published on Steamworks yet, or not in: tried again every `RETRY`.
		_gift_retry = RETRY
		return
	bank.sent = true
	bank.write()
	_dirty = true
	bank.changed.emit()


## GodotSteam's `user_stats_received`: this account's stats are in and may be read and set.
## The arguments are not read; defaults, so a build that sends fewer still connects.
func _on_user_stats(_game: Variant = null, _result: Variant = null, _user: Variant = null) -> void:
	_stats_in = true
	_settle_gift()


## GodotSteam's `global_stats_received`: every player's totals, answered. The result is "ok"
## in GodotSteam 4 (an int 1 in builds that pass the SDK's code through).
func _on_global_stats(_game: Variant = null, result: Variant = null) -> void:
	bank.asking = false
	var ok := (
		result == null
		or (result is String and String(result) == "ok")
		or ((result is int or result is float) and int(result) == 1)
	)
	if ok and _steam != null:
		bank.total = maxi(0, int(_steam.call(&"getGlobalStatInt", DONATED)))
		bank.donors = maxi(0, int(_steam.call(&"getGlobalStatInt", DONORS)))
		bank.seen_at = int(Time.get_unix_time_from_system())
		bank.live = true
		bank.write()
	bank.changed.emit()


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
	if steam.has_signal(&"user_stats_received"):
		steam.connect(&"user_stats_received", _on_user_stats)
	if steam.has_signal(&"global_stats_received"):
		steam.connect(&"global_stats_received", _on_global_stats)
	return true


func _read() -> void:
	earned.clear()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	for id: Variant in cfg.get_value("earned", "ids", []) as Array:
		if ALL.has(String(id)) and not earned.has(String(id)):
			earned.append(String(id))


## Loaded first and only the earned list set: the bank keeps its own section in the same file.
func _write() -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)
	cfg.set_value("earned", "ids", earned)
	cfg.save(path)
