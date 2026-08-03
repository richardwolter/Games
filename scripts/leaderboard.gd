## The online leaderboard: one board per strait, ranked by the cheapest bridge
## that got the truck across.
##
## Deliberately mirrors the local standings in LevelManager rather than inventing
## a second metric. The number submitted is the same bridge price the in-game
## table already ranks, and lower still wins — "I crossed strait 2 for $180" is a
## claim worth making to strangers in a way that "I crossed it" is not, because
## everybody who finishes the level has done that. It is also a figure the player
## can act on: the shop is right there.
##
## Talks to SimpleBoards (simpleboards.dev) over plain HTTP rather than through
## their Godot addon. The whole surface is two endpoints and this file is
## shorter than the plugin's config UI, and a prototype that can't be opened and
## understood in one sitting has cost more than it saved.
##
## Failure is always silent. A leaderboard is the least important thing on the
## screen after a crossing; a player on a plane should see their bridge scored
## and ranked locally exactly as before, with the online table simply absent.
## Nothing here is ever awaited by gameplay.
class_name Leaderboard
extends Node

## Emitted after a submission settles, successfully or not. `ok` is false for
## every kind of failure — no network, bad key, service down — because there is
## nothing the game does differently between them.
signal submitted(level_index: int, ok: bool)
## Emitted when a board has been read. `entries` is ordered as the service
## returned it, best first, each a {name: String, score: int}.
signal entries_fetched(level_index: int, entries: Array[Dictionary])

const BASE := "https://api.simpleboards.dev/api/"

## Shipped inside the binary, and extractable from it — in a web build it is
## sitting in plain text in the wasm. That is inherent to a keyed service called
## from a client with no server of our own, and it means the board is a
## scoreboard, not a proof: anyone who wants to post a 1 can. Fine for a game
## about balancing fridges on pontoons; do not later hang anything that matters
## off these numbers.
const API_KEY := "b7a4fc35-b81c-4944-a86d-3330e33d74cb"

## The one leaderboard, shared by every strait.
##
## SimpleBoards' free tier allows a single board, and four straits ranked
## together would not be a leaderboard: the score is the bridge's price and lower
## wins, so every level 1 crossing outranks every level 4 crossing and the whole
## table collapses into a level 1 list.
##
## So the levels are separated here instead. Each entry is tagged with the strait
## it was set on, the game fetches the entire board and splits it into four,
## sorts each ascending, and shows the one the player is looking at. The
## service's own ranking is never used or looked at — the board is storage, and
## the ranking is ours.
##
## Empty until the board exists in the SimpleBoards dashboard. An empty id
## disables the leaderboard and nothing else: the game plays identically and the
## panels show the local table alone.
const BOARD := "aab65174-bd6b-499b-d45c-08def12f5b49"

## How many rows a panel has room for, per strait. Applied after splitting, so
## eight busy level 1 entries can't crowd level 4 off its own board.
const SHOWN := 8

## Marks which strait an entry belongs to, appended to the player's id:
## «install id»-L2. Two jobs in one field, both of which need it to vary by level.
##
## It is the level tag, read back off every fetched entry to split the board.
## Chosen over the metadata field because playerId is a core column and certain
## to survive a round trip — if metadata came back missing or reshaped, every
## board would silently render empty and look like a network fault.
##
## It is ALSO the dedup key. The service keeps one entry per playerId, which is
## what stops a player who has crossed a strait nine times owning the whole
## table; with a single shared board and a single id, crossing level 2 would
## instead overwrite that player's level 1 entry. One id per level per player
## gives each person exactly one row on each of the four boards.
const LEVEL_TAG := "-L"

## Requests are dropped rather than queued past this. A player mashing START
## should not build a backlog of stale submissions that arrive minutes later.
const TIMEOUT := 8.0

## Where the player's identity lives in settings.cfg. Not in the save: the
## initials and the id are facts about the person, and starting a new game
## should not make them a stranger to the board.
const SECTION := "player"

## Last board read per level, so reopening the crossing panel shows the table
## immediately and refreshes underneath rather than flashing empty.
var _cache: Dictionary[int, Array] = {}


## Whether this level has a board configured at all. Every entry point checks
## it, so an unconfigured game makes no requests and shows no leaderboard UI.
##
## Also false under the headless checks. Those cross straits by design and would
## otherwise post the test harness's bridges to a public board — and mint an
## installation id into the developer's real settings file to do it. Same
## condition Prefs uses, checked separately rather than plumbed through so no
## future caller can forget it.
static func has_board(level_index: int) -> bool:
	if _inert() or BOARD.is_empty():
		return false
	return level_index >= 0


static func _inert() -> bool:
	var args := OS.get_cmdline_user_args()
	return args.has("--smoke") or args.has("--carcheck")


## The player's three arcade initials, or "" if they have never been asked.
##
## Three characters is the whole design: it is the format that says "put your
## name on the machine" without asking anyone to think about a username, and a
## board of AAA/BOB/ZZZ reads as a high-score table rather than a signup sheet.
static func player_name() -> String:
	return _read(&"initials", "")


static func set_player_name(initials: String) -> void:
	_write(&"initials", sanitize_initials(initials))


## Uppercase, A-Z and 0-9 only, exactly what the entry field allows. Applied on
## the way in as well as at the field, because the value also arrives from a
## config file a player can edit.
static func sanitize_initials(raw: String) -> String:
	var out := ""
	for c: String in raw.to_upper():
		if (c >= "A" and c <= "Z") or (c >= "0" and c <= "9"):
			out += c
		if out.length() == 3:
			break
	return out


## This player's id ON ONE STRAIT: a stable per-installation id, minted on first
## use, with the level tag appended. See LEVEL_TAG for why it varies by level.
##
## Not an identity or a login — losing it just means the next entry looks like a
## new player.
static func player_id(level_index: int) -> String:
	return install_id() + LEVEL_TAG + str(level_index)


## Which strait an entry was set on, read back off its playerId. -1 when the id
## carries no tag, which means an entry this build didn't write — dropped rather
## than guessed at, since putting it on the wrong board is worse than omitting it.
static func level_of(raw_player_id: String) -> int:
	var cut := raw_player_id.rfind(LEVEL_TAG)
	if cut < 0:
		return -1
	var tail := raw_player_id.substr(cut + LEVEL_TAG.length())
	return tail.to_int() if tail.is_valid_int() else -1


static func install_id() -> String:
	var existing := _read(&"id", "")
	if not existing.is_empty():
		return existing
	var minted := _mint_id()
	_write(&"id", minted)
	return minted


static func _mint_id() -> String:
	var bytes := PackedByteArray()
	for i in 16:
		bytes.append(randi() % 256)
	return bytes.hex_encode()


## Post one crossing. Fire and forget: nothing awaits this, and a caller that
## wants to know can listen for `submitted`.
##
## `points` is the bridge's total shop price. Sent as a string because that is
## what the service's own examples do, and it is the one field where guessing
## wrong costs a rejected entry.
func submit(level_index: int, points: int) -> void:
	var initials := player_name()
	if not has_board(level_index) or initials.is_empty():
		return

	# Only ever send an improvement. The service stores whatever arrived last, so
	# posting every crossing means a player's best bridge is replaced by their
	# most recent one — they would watch their own record fall off the board by
	# playing badly, which is the opposite of what a leaderboard is for.
	#
	# Measured against what was actually POSTED, not against the local standings.
	# Somebody who set their initials after already crossing a strait has a local
	# record they can't beat and has never appeared on the board; against the
	# standings they would stay invisible forever, and against this they post
	# their next crossing and are on it.
	var best := posted_best(level_index)
	if best >= 0 and points >= best:
		submitted.emit(level_index, true)
		return

	var ok := await _post(level_index, points, initials)
	if ok:
		# Recorded only on success, so a run lost to a dropped connection is
		# retried by the next crossing rather than remembered as posted.
		_write(&"posted_%d" % level_index, str(points))
		_write(POSTED_NAME, initials)
	submitted.emit(level_index, ok)


## Put this player's entry on the board, with no improvement check.
##
## Split out from submit() because renaming has to write a score it has already
## written — the gate in submit() is about scores, and a rename is not a score.
func _post(level_index: int, points: int, initials: String) -> bool:
	var body := JSON.stringify({
		"leaderboardId": BOARD,
		"playerId": player_id(level_index),
		"playerDisplayName": initials,
		"score": str(points),
		# Duplicates the level already encoded in playerId, purely so the board is
		# readable by a human in the SimpleBoards dashboard. The game splits on
		# playerId and never reads this back — see LEVEL_TAG.
		#
		# A STRING, not an object. The service rejects a nested object here with a
		# 500 and a JSON parse error, which is what silently broke every
		# submission until a live POST was tried by hand — the field is free text
		# as far as it is concerned.
		"metadata": "level %d" % (level_index + 1),
	})
	var headers := PackedStringArray([
		"x-api-key: " + API_KEY,
		"Content-Type: application/json",
	])

	var result: Array = await _request(BASE + "entries", headers, HTTPClient.METHOD_POST, body)
	var ok: bool = not result.is_empty() and result[0] >= 200 and result[0] < 300
	if not ok:
		# A warning, not an error: this is an expected outcome offline, and
		# push_error in a release build is noise on a thing the player cannot fix.
		#
		# Carries the status and the service's own reply, because the failure the
		# player reports is "my score isn't on the board" and every cause of that
		# — no network, a rejected field, a bad key — looks identical from the
		# outside. Without the body, diagnosing it means adding this line anyway.
		push_warning("Leaderboard submit failed for level %d: %s" % [
			level_index + 1, _describe(result)
		])
	return ok


## The name the board currently shows for this player, as far as we know.
const POSTED_NAME := &"posted_name"


## Whether the board is showing a name the player has since changed.
##
## Renaming does not move an entry — playerId is unchanged, so the old initials
## sit there until something posts again. Nothing would: a crossing only posts an
## improvement, so a player who renames and then never beats their own bridge
## keeps the old name on the board indefinitely.
static func needs_rename() -> bool:
	var initials := player_name()
	if initials.is_empty() or not has_board(0):
		return false
	return _read(POSTED_NAME, "") != initials and not posted_levels().is_empty()


## Every strait this installation has an entry on, read back from the posted_N
## keys rather than assumed from the campaign length — the file is the record of
## what is actually out there.
static func posted_levels() -> Array[int]:
	var out: Array[int] = []
	var config := ConfigFile.new()
	if config.load(Prefs.PATH) != OK:
		return out
	if not config.has_section(SECTION):
		return out
	for key: String in config.get_section_keys(SECTION):
		if not key.begins_with("posted_"):
			continue
		var tail := key.substr("posted_".length())
		if tail.is_valid_int():
			out.append(tail.to_int())
	out.sort()
	return out


## Rewrite this player's entries under their current initials.
##
## One post per strait they are already on, each carrying the score that is
## already there — the service replaces on repeated playerId, so this changes the
## name and nothing else.
##
## Silent and best-effort. A rename that fails offline is not reported: the
## marker only advances when every post succeeded, so the next time a board is
## opened this runs again and catches up.
func republish() -> void:
	if not needs_rename():
		return
	var initials := player_name()
	var all_ok := true
	for level: int in posted_levels():
		var points := posted_best(level)
		if points < 0:
			continue
		all_ok = await _post(level, points, initials) and all_ok
	if all_ok:
		_write(POSTED_NAME, initials)


## A failed response as one readable line, for the log.
static func _describe(result: Array) -> String:
	if result.is_empty():
		return "no response (offline, DNS, or timeout)"
	var body := (result[1] as PackedByteArray).get_string_from_utf8().strip_edges()
	return "HTTP %d %s" % [int(result[0]), body if not body.is_empty() else "(empty body)"]


## The best bridge this installation has successfully posted for a strait, or -1
## if it has never posted one.
##
## Kept beside the initials in settings.cfg rather than in the save: it describes
## what the remote board already holds, and starting a new game does not empty
## the board.
static func posted_best(level_index: int) -> int:
	var raw := _read(&"posted_%d" % level_index, "")
	return raw.to_int() if raw.is_valid_int() else -1


## Read the board and split it into one table per strait.
##
## `level_index` says which table the caller is waiting to see, but the request
## is the same either way — there is one board and it comes back whole — so every
## level's cache is refreshed from the one round trip. Opening the crossing panel
## therefore also fills in the level select's boards for free.
##
## Emits `entries_fetched` on success and stays quiet otherwise, leaving whatever
## was cached in place: a failed refresh should not blank a table the player is
## looking at.
##
## Returns whether the board was actually read. The caller needs that to tell an
## empty table apart from an unreachable one — they look identical from the
## cache, and telling a player the board is unavailable when it is simply empty
## reports a fault that isn't there. An empty board is the normal state of a new
## leaderboard, and the first thing anyone will see.
func fetch(level_index: int) -> bool:
	if not has_board(level_index):
		return false

	var headers := PackedStringArray(["x-api-key: " + API_KEY])
	var url := BASE + "leaderboards/%s/entries" % BOARD
	var result: Array = await _request(url, headers, HTTPClient.METHOD_GET)
	if result.is_empty() or result[0] != 200:
		return false

	var parsed: Variant = JSON.parse_string((result[1] as PackedByteArray).get_string_from_utf8())
	if not parsed is Array:
		return false

	_cache = _split_by_level(parsed as Array)
	entries_fetched.emit(level_index, cached(level_index))
	return true


## Sorts the whole board into per-level tables, one row per player, best first.
##
## Ranked here rather than trusting the order the service sent, because that
## order is across all four straits at once and by a rule we don't control. Lower
## price wins, so each table is sorted ascending and cut to SHOWN afterwards —
## cutting first would let a crowded level 1 push level 4 off its own board.
##
## Players are collapsed to their single best entry on the way through. submit()
## already avoids posting anything worse than what it posted before, so in the
## ordinary case there is nothing here to collapse. This is the belt to that
## braces: it holds whether or not the service replaces an entry on repeat
## playerId — behaviour that is not documented anywhere I can check, and if it
## appends instead, then without this one determined player owns every visible
## row and the board stops being a comparison between people.
##
## Keyed on playerId, which already carries the level, so two people who picked
## the same three letters stay two rows.
static func _split_by_level(raw: Array) -> Dictionary[int, Array]:
	var best: Dictionary[String, Dictionary] = {}
	for item: Variant in raw:
		if not item is Dictionary:
			continue
		var entry := _to_entry(item as Dictionary)
		if entry.is_empty():
			continue
		var who := str((item as Dictionary).get("playerId", ""))
		var seen: Variant = best.get(who, null)
		if seen == null or int(entry["score"]) < int((seen as Dictionary)["score"]):
			best[who] = entry

	var out: Dictionary[int, Array] = {}
	for who: String in best:
		var entry := best[who]
		var level: int = entry["level"]
		if not out.has(level):
			out[level] = []
		out[level].append(entry)

	for level: int in out:
		var table: Array = out[level]
		table.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["score"]) < int(b["score"])
		)
		if table.size() > SHOWN:
			table.resize(SHOWN)
	return out


## The last board we read for this level, possibly empty and possibly stale.
func cached(level_index: int) -> Array[Dictionary]:
	var raw: Array = _cache.get(level_index, [])
	var out: Array[Dictionary] = []
	for entry: Variant in raw:
		out.append(entry as Dictionary)
	return out


## Flattens one of the service's entry objects into the three fields we use, or
## an empty Dictionary if it isn't usable.
##
## Scores come back as strings, which is why they went out as strings. A row that
## doesn't parse is dropped rather than shown as zero: a $0 bridge would sit at
## the top of an ascending board and read as an unbeatable record.
##
## An entry with no level tag is dropped for the same reason — it belongs to no
## strait we can name, and putting it on the wrong board is worse than leaving it
## off. In practice that means entries written by a build older than this one.
static func _to_entry(entry: Dictionary) -> Dictionary:
	var score := str(entry.get("score", "")).strip_edges()
	if not score.is_valid_int():
		return {}
	var level := level_of(str(entry.get("playerId", "")))
	if level < 0:
		return {}
	var name := str(entry.get("playerDisplayName", "")).strip_edges()
	# Plain String keys, matching what UITheme.online_table() reads. A Dictionary
	# tells &"score" and "score" apart, so mixing the two silently yields nothing.
	return {
		"name": sanitize_initials(name) if not name.is_empty() else "???",
		"score": score.to_int(),
		"level": level,
	}


## One HTTP round trip. Returns [response_code, body] or [] if it never got
## there. The HTTPRequest node is created and freed per call — these happen once
## per crossing, and a pooled one would be state to reason about for no gain.
func _request(
	url: String, headers: PackedStringArray, method: int, body: String = ""
) -> Array:
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	add_child(http)

	if http.request(url, headers, method, body) != OK:
		http.queue_free()
		return []

	var result: Array = await http.request_completed
	http.queue_free()
	# result is [result, response_code, headers, body].
	if result[0] != HTTPRequest.RESULT_SUCCESS:
		return []
	return [result[1] as int, result[3] as PackedByteArray]


static func _read(key: StringName, fallback: String) -> String:
	var config := ConfigFile.new()
	if config.load(Prefs.PATH) != OK:
		return fallback
	return str(config.get_value(SECTION, key, fallback))


## Read-modify-write, so this cannot clobber the volume or the hint flags kept
## in the same file. Same reasoning as Prefs.set_flag().
static func _write(key: StringName, value: String) -> void:
	var config := ConfigFile.new()
	config.load(Prefs.PATH)
	config.set_value(SECTION, key, value)
	config.save(Prefs.PATH)
