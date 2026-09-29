## The music: one station for the whole session, from the engine starting to the window
## closing (2026-09-15, `/grill-me` with Richard).
##
## An autoload (`Music` in project.godot), so nothing restarts on a change of scene: the menu
## and the lake hear the same stream, and walking back to the menu from the lake does not
## start the song over. The scenes only say where the player is — indoors, a board open, the
## ending — and push the volume; every player lives here.
##
## - **The lake's list** runs beatgucci, Save ME, Goin and round again by default. The next
##   song comes up underneath over `FADE` seconds; the one playing holds its level and only
##   fades over its own last `FADE_OUT`.
##   beatgucci stops at 2:12 by decision; that cut is in the file (`tools/build_music.py`),
##   so a song's length is always where it ends.
## - **Muffled** (the upgrades board or the wash room open on the lake): the song playing
##   crossfades to its radio copy, the same recording through a wall, started on the same
##   instant so the two stay in step and the door is a fade rather than a seek.
## - **Indoors** (the shed): the shed's list through the radio, Indie Boi by default. It has
##   been playing since the engine started, so walking in lands wherever it has reached; the
##   lake's list carries on muted underneath and is where it would have been on the way out.
## - **The ending** (the farewell on a cleaned lake, the Credits board on the menu): Habibs
##   fades in over everything from its start, and fades back out to the playlist, which kept
##   running underneath.
## - **The record player** (2026-09-28, `/grill-me` with Richard): the lake and the shed each
##   play a list the player ticked on the record player's menu (`RecordMenu`), in `SONGS`'
##   order, looping. **Two tracks, each on its own players**, so one song can be on both
##   lists at different places in it. **Synced** drops the shed's track: the shed hears the
##   lake's own song through the radio, at the same second. Habibs can be ticked only once
##   the lake has been cleaned (`habibs_open`). The picks are the run's, carried in the save
##   (`picks`/`take_picks`); a save without them reads as the old fixed lists.
##
## Silence is a volume, never a stopped player, for the same reason as always: a track that
## keeps running while muted comes back where it would have been.
class_name MusicStation
extends Node

const DIR := "res://assets/music/"

## The lake's songs by default, in the order they play, looping back to the first.
const PLAYLIST: Array[StringName] = [&"beatgucci", &"save_me", &"goin"]
const SHED_SONG := &"indie_boi"
const ENDING_SONG := &"habibs"
## Every song the record player offers, in the order a list plays them.
const SONGS: Array[StringName] = [&"beatgucci", &"save_me", &"goin", &"indie_boi", &"habibs"]
## The two places a list plays in.
const LAKE := &"lake"
const SHED := &"shed"

## How long the next song takes to come up under the one playing, and how long the ending
## takes to come and go.
const FADE := 4.0

## How long the song on its way out takes to go, at the very end of it (2026-09-15, Richard:
## "getting cut too quickly on fade out, it should play a little longer").
##
## The two used to be one number, an equal-power crossfade over the outgoing song's last four
## seconds. Save ME plays at full level to its final sample — it has no outro — so four
## seconds of fade is four seconds of the song thrown away, and it reads as being cut off.
## Now the song on its way out is left alone until this much of it is left, and what overlaps
## it is the next song easing in underneath.
const FADE_OUT := 1.5
## How fast the sound moves between outdoors, the radio and the shed, as a fraction of the
## way a second: a quarter of a second door, as it was.
const DOOR_FADE := 4.0

## Each song's level against the others, in decibels, levelled to Goin's loudness (-11.1
## LUFS, what the slider was tuned on) off `ebur128` on the built files. The mixes were
## delivered at up to five decibels apart, which a crossfade turns into a jump. Zero
## everywhere is the songs as delivered.
const GAIN_DB := {
	&"beatgucci": 2.3,
	&"save_me": -0.7,
	&"goin": 0.0,
	&"indie_boi": 1.6,
	&"habibs": -2.7,
}

## Under this a player is not heard at all: a song that is not the one playing, or the one
## being faded out under it.
##
## The player's slider is **not** here any more (2026-09-16, issue #26): every player is on
## the Music bus and the slider is that bus's volume (`Prefs`). What this file sets is the
## crossfade and each song's own levelling, which is what it was always for.
const OFF_DB := -80.0

## Each song's beat grid, measured off the built files (tools/measure_beats.py): its tempo
## and where its first beat falls, in seconds. The animals move to it (2026-09-22,
## `/grill-me` with Richard: frogs hop on beats, turtles nod on every beat, dragonflies dart
## on one, the bees' orbit pulses). A song with no entry runs at FALLBACK_BPM from nought.
const BEATS := "res://assets/music/beats.json"
const FALLBACK_BPM := 120.0

## Where the player is. Set by the scenes; faded towards a frame at a time.
var muffled: bool = false
var indoors: bool = false
var ending: bool = false
## The shed hears the lake's track through the radio instead of its own.
var synced: bool = false
## Habibs may be put on a list: the lake has been cleaned once on this run.
var habibs_open: bool = false

## Take the song's own position from its player when it has one. Off for the test harness,
## which drives the clock by hand under a dummy audio driver.
var follow_players: bool = true

var _radio_at: float = 0.0
var _shed_at: float = 0.0
var _ending_at: float = 0.0
var _sync_at: float = 0.0

var _lake: Track = Track.new()
var _shed: Track = Track.new()
var _ending: AudioStreamPlayer
var _beats: Dictionary = {}


## One list playing on its own players: which song leads, how far in, and the next one
## easing in under its last seconds.
class Track:
	extends RefCounted
	var list: Array[StringName] = []
	## slug -> [outdoors player or null, radio player or null]
	var players: Dictionary = {}
	var song: int = 0
	var at: float = 0.0
	var next: int = -1
	## Counts every change of song, played through or skipped: the menu's needle reads it.
	var changes: int = 0
	## Paused under a lifted needle until the skip lands.
	var held: bool = false

	func slug() -> StringName:
		return list[song] if song < list.size() else &""

	func _lead_of(slug_asked: StringName) -> AudioStreamPlayer:
		var pair: Array = players.get(slug_asked, [null, null])
		return pair[0] if pair[0] != null else pair[1]

	func length_of(index: int) -> float:
		if index < 0 or index >= list.size():
			return 180.0
		var p := _lead_of(list[index])
		if p == null:
			return 180.0
		return p.stream.get_length()

	func start(index: int, from: float = 0.0) -> void:
		for p: AudioStreamPlayer in players.get(list[index], []):
			if p != null:
				p.play(from)

	func stop_slug(slug_asked: StringName) -> void:
		for p: AudioStreamPlayer in players.get(slug_asked, []):
			if p != null:
				p.stream_paused = false
				p.stop()

	## Pause what is playing: the needle is up.
	func hold() -> void:
		held = true
		for index in [song, next]:
			if index >= 0 and index < list.size():
				for p: AudioStreamPlayer in players.get(list[index], []):
					if p != null:
						p.stream_paused = true

	func next_slug() -> StringName:
		if list.is_empty():
			return &""
		return list[next if next >= 0 else (song + 1) % list.size()]

	func step(delta: float, follow: bool) -> void:
		if list.is_empty() or held:
			return
		var p := _lead_of(slug())
		if follow and p != null and p.playing and p.get_playback_position() > 0.0:
			at = p.get_playback_position()
		else:
			at += delta
		var length := length_of(song)
		# One song on the list: it loops on itself, with no handover to its own players.
		if list.size() == 1:
			if at >= length:
				at -= length
				start(song, at)
				changes += 1
			return
		if next < 0 and at >= length - FADE:
			next = (song + 1) % list.size()
			start(next)
		if at >= length:
			stop_slug(list[song])
			at -= length
			song = next if next >= 0 else (song + 1) % list.size()
			if next < 0:
				start(song)
			next = -1
			changes += 1

	func skip() -> void:
		held = false
		if list.is_empty():
			return
		var to := next if next >= 0 else (song + 1) % list.size()
		stop_slug(list[song])
		if next >= 0:
			stop_slug(list[next])
		song = to
		next = -1
		at = 0.0
		start(song)
		changes += 1

	## Take a new list, keeping the song playing if it is still on it; otherwise go on to
	## the first song after it in `SONGS`' order that is.
	func take(new_list: Array[StringName]) -> void:
		var was := slug()
		if next >= 0 and next < list.size() and list[next] != was:
			stop_slug(list[next])
		next = -1
		if not was.is_empty() and new_list.has(was):
			list = new_list
			song = list.find(was)
			return
		if not was.is_empty():
			stop_slug(was)
		list = new_list
		song = 0
		if not was.is_empty():
			var from := SONGS.find(was)
			for i in list.size():
				if SONGS.find(list[i]) > from:
					song = i
					break
		at = 0.0
		if not list.is_empty():
			start(song)
		changes += 1

	func gain_of(slug_asked: StringName) -> float:
		if list.is_empty():
			return 0.0
		if slug_asked == list[song]:
			if next < 0:
				return 1.0
			return cos(going() * PI * 0.5)
		if next >= 0 and slug_asked == list[next]:
			return pow(sin(handover() * PI * 0.5), 2.0)
		return 0.0

	func handover() -> float:
		return clampf((at - (length_of(song) - FADE)) / FADE, 0.0, 1.0)

	func going() -> float:
		return clampf((at - (length_of(song) - FADE_OUT)) / FADE_OUT, 0.0, 1.0)

	## [slug, seconds into it] of the song heard loudest.
	func heard() -> Array:
		if list.is_empty():
			return [PLAYLIST[0], at]
		if next >= 0 and handover() > 0.5:
			return [list[next], at - (length_of(song) - FADE)]
		return [list[song], at]

	func playing(slug_asked: StringName) -> bool:
		for p: AudioStreamPlayer in players.get(slug_asked, []):
			if p != null and p.playing:
				return true
		return false


static func main() -> MusicStation:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(^"Music") as MusicStation


func _init() -> void:
	_lake.list = PLAYLIST.duplicate()
	_shed.list = [SHED_SONG]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if FileAccess.file_exists(BEATS):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(BEATS))
		if parsed is Dictionary:
			_beats = parsed
	for slug in SONGS:
		_lake.players[slug] = [_player(slug, "", "lake_"), _player(slug, "_radio", "lake_")]
		_shed.players[slug] = [null, _player(slug, "_radio", "shed_")]
	_ending = _player(ENDING_SONG, "", "end_")
	_lake.start(_lake.song)
	_shed.start(_shed.song)
	_push()


func _process(delta: float) -> void:
	step(delta)


## A scene going away takes its rooms with it: nothing it opened is still open.
func leave_rooms() -> void:
	muffled = false
	indoors = false
	ending = false


func set_ending(on: bool) -> void:
	if on and not ending and is_zero_approx(_ending_at) and _ending != null:
		_ending.play()
	ending = on


## Move the station on by `delta` seconds. `_process` calls it; the test calls it by hand.
func step(delta: float) -> void:
	_lake.step(delta, follow_players)
	_shed.step(delta, follow_players)
	_radio_at = move_toward(_radio_at, 1.0 if muffled else 0.0, DOOR_FADE * delta)
	_shed_at = move_toward(_shed_at, 1.0 if indoors else 0.0, DOOR_FADE * delta)
	_sync_at = move_toward(_sync_at, 1.0 if synced else 0.0, DOOR_FADE * delta)
	_ending_at = move_toward(_ending_at, 1.0 if ending else 0.0, delta / FADE)
	if _ending != null and _ending_at <= 0.0 and _ending.playing:
		_ending.stop()
	# The ending loops by hand: the stream is shared with the lists' players, which must not
	# loop on their own or their clock never reaches the handover.
	elif _ending != null and ending and not _ending.playing and follow_players:
		_ending.play()
	_push()


## What every player is being given right now, as linear gain before the volume and the
## song's own level: `"<slug>"` and `"<slug>_radio"` for the lake's track, `"shed_<slug>"`
## for the shed's (always through the radio), `"end"` for the ending's Habibs.
func gains() -> Dictionary:
	var out := {}
	var ending_gain := sin(_ending_at * PI * 0.5)
	var rest := cos(_ending_at * PI * 0.5)
	var shed_gain := sin(_shed_at * PI * 0.5) * rest
	var lake := cos(_shed_at * PI * 0.5) * rest
	# Synced, the shed's share goes to the lake's own song through the radio.
	var shed_own := shed_gain * (1.0 - _sync_at)
	var shed_lake := shed_gain * _sync_at
	for slug in SONGS:
		var song := _lake.gain_of(slug)
		out[String(slug)] = lake * song * (1.0 - _radio_at)
		out[String(slug) + "_radio"] = (lake * _radio_at + shed_lake) * song
		out["shed_" + String(slug)] = shed_own * _shed.gain_of(slug)
	out["end"] = ending_gain
	return out


## Which song is leading on the lake, and how far into it.
func now_playing() -> StringName:
	return _lake.slug()


func song_time() -> float:
	return _lake.at


## The track a place is hearing: the shed's is the lake's while synced.
func _track(place: StringName) -> Track:
	return _shed if place == SHED and not synced else _lake


## The song leading in a place.
func playing_in(place: StringName) -> StringName:
	return _track(place).slug()


## The song a skip in a place would go to.
func next_in(place: StringName) -> StringName:
	return _track(place).next_slug()


## Hold a place's song under a lifted needle; the next `skip` plays on.
func hold(place: StringName) -> void:
	_track(place).hold()


## How many times a place's song has changed, for the needle.
func changes_in(place: StringName) -> int:
	return _track(place).changes


## Skip to the next song on a place's list.
func skip(place: StringName) -> void:
	_track(place).skip()
	_push()


## A place's own list, whatever the sync says.
func list_of(place: StringName) -> Array[StringName]:
	return (_shed if place == SHED else _lake).list.duplicate()


func ticked(place: StringName, slug: StringName) -> bool:
	return (_shed if place == SHED else _lake).list.has(slug)


func can_pick(slug: StringName) -> bool:
	return SONGS.has(slug) and (slug != ENDING_SONG or habibs_open)


## Tick or untick a song on a place's list. Refused for a locked song, and for the last song
## on a list — a list is never empty. Returns whether anything changed.
func toggle(place: StringName, slug: StringName) -> bool:
	if not can_pick(slug):
		return false
	var track := _shed if place == SHED else _lake
	var wanted: Array = track.list.duplicate()
	if wanted.has(slug):
		if wanted.size() <= 1:
			return false
		wanted.erase(slug)
	else:
		wanted.append(slug)
	track.take(_ordered(wanted))
	_push()
	return true


func set_synced(on: bool) -> void:
	synced = on


## What the save carries.
func picks() -> Dictionary:
	return {
		"lake": _lake.list.map(func(s): return String(s)),
		"shed": _shed.list.map(func(s): return String(s)),
		"synced": synced,
	}


## Take a save's picks; anything missing or unknown falls back to the old fixed lists.
func take_picks(saved: Dictionary) -> void:
	_lake.take(_read_list(saved.get("lake"), PLAYLIST))
	_shed.take(_read_list(saved.get("shed"), [SHED_SONG]))
	synced = bool(saved.get("synced", false))
	_sync_at = 1.0 if synced else 0.0
	_push()


func _read_list(raw, fallback: Array) -> Array[StringName]:
	var out: Array = []
	if raw is Array:
		for s in raw:
			var slug := StringName(str(s))
			if SONGS.has(slug) and not out.has(slug):
				out.append(slug)
	if out.is_empty():
		out = fallback.duplicate()
	return _ordered(out)


func _ordered(list: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for slug in SONGS:
		if list.has(slug):
			out.append(slug)
	return out


## Beats since the start of the song the lake is hearing, as a float: a whole number is a
## beat. The song is whichever is loudest — the ending over the playlist once it is more
## than half up, the next song over the one leaving once the handover is half done — so the
## beat follows what is heard. **The clock runs whether or not anything is audible**
## (muted, muffled, through the shed wall): by decision, the animals keep dancing to a
## silent song rather than dropping out of step. It jumps at a change of song; callers
## counting beats treat a jump backwards as a fresh start.
func beat_clock() -> float:
	var song := _heard()
	var grid: Dictionary = _beats.get(String(song[0]), {})
	var bpm := float(grid.get("bpm", FALLBACK_BPM))
	var offset := float(grid.get("offset", 0.0))
	return (float(song[1]) - offset) * bpm / 60.0


## Seconds a beat lasts in the song being heard.
func beat_length() -> float:
	var grid: Dictionary = _beats.get(String(_heard()[0]), {})
	return 60.0 / float(grid.get("bpm", FALLBACK_BPM))


## [slug, seconds into it] of the song the beat follows: the lake's track, the animals
## being out on the lake.
func _heard() -> Array:
	if _ending_at > 0.5 and _ending != null and _ending.playing:
		return [ENDING_SONG, _ending.get_playback_position()]
	return _lake.heard()


## How far into the lake's song, settable by the harness.
var _at: float:
	get:
		return _lake.at
	set(value):
		_lake.at = value


func is_playing(slug: StringName) -> bool:
	if slug == ENDING_SONG and _ending != null and _ending.playing:
		return true
	return _lake.playing(slug) or _shed.playing(slug)


func _push() -> void:
	if _lake.players.is_empty():
		return
	var given := gains()
	for slug in SONGS:
		var pair: Array = _lake.players[slug]
		_apply(pair[0], given[String(slug)], slug)
		_apply(pair[1], given[String(slug) + "_radio"], slug)
		_apply((_shed.players[slug] as Array)[1], given["shed_" + String(slug)], slug)
	_apply(_ending, given["end"], ENDING_SONG)


func _apply(player: AudioStreamPlayer, gain: float, slug: StringName) -> void:
	if player == null:
		return
	player.volume_db = (
		OFF_DB if gain < 0.0001
		else float(GAIN_DB.get(slug, 0.0)) + linear_to_db(gain)
	)


func _player(slug: StringName, suffix: String, prefix: String) -> AudioStreamPlayer:
	var path := DIR + String(slug) + suffix + ".mp3"
	if not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStreamMP3
	if stream == null:
		return null
	var player := AudioStreamPlayer.new()
	player.name = prefix + String(slug) + suffix
	player.stream = stream
	player.bus = Prefs.BUS_MUSIC
	player.volume_db = OFF_DB
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player


## The lake track's length of song `index`, for the harness.
func _length(index: int) -> float:
	return _lake.length_of(index)
