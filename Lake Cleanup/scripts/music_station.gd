## The music: one station for the whole session, from the engine starting to the window
## closing (2026-09-15, `/grill-me` with Richard).
##
## An autoload (`Music` in project.godot), so nothing restarts on a change of scene: the menu
## and the lake hear the same stream, and walking back to the menu from the lake does not
## start the song over. The scenes only say where the player is — indoors, a board open, the
## ending — and push the volume; every player lives here.
##
## - **The playlist** runs beatgucci, Save ME, Goin and round again, forever. The next song
##   comes up underneath over `FADE` seconds; the one playing holds its level and only fades
##   over its own last `FADE_OUT`.
##   beatgucci stops at 2:12 by decision; that cut is in the file (`tools/build_music.py`),
##   so a song's length is always where it ends.
## - **Muffled** (the upgrades board or the settings open on the lake): the song playing
##   crossfades to its radio copy, the same recording through a wall, started on the same
##   instant so the two stay in step and the door is a fade rather than a seek.
## - **Indoors** (the shed): Indie Boi through the radio. It has been playing since the engine
##   started and loops on its own, so walking in lands wherever it has reached; the playlist
##   carries on muted underneath and is where it would have been on the way out.
## - **The ending** (the farewell on a cleaned lake, the Credits board on the menu): Habibs
##   fades in over everything from its start, and fades back out to the playlist, which kept
##   running underneath.
##
## Silence is a volume, never a stopped player, for the same reason as always: a track that
## keeps running while muted comes back where it would have been.
class_name MusicStation
extends Node

const DIR := "res://assets/music/"

## The lake's songs in the order they play, looping back to the first.
const PLAYLIST: Array[StringName] = [&"beatgucci", &"save_me", &"goin"]
const SHED_SONG := &"indie_boi"
const ENDING_SONG := &"habibs"

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

## Where the player is. Set by the scenes; faded towards a frame at a time.
var muffled: bool = false
var indoors: bool = false
var ending: bool = false

## Take the song's own position from its player when it has one. Off for the test harness,
## which drives the clock by hand under a dummy audio driver.
var follow_players: bool = true

## Which song of the playlist is leading, and how far into it.
var _song: int = 0
var _at: float = 0.0
## The song fading in under the end of the leading one, or -1.
var _next: int = -1

var _radio_at: float = 0.0
var _shed_at: float = 0.0
var _ending_at: float = 0.0

## slug -> [outdoors player or null, radio player or null]
var _players: Dictionary = {}
var _shed: AudioStreamPlayer
var _ending: AudioStreamPlayer


static func main() -> MusicStation:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(^"Music") as MusicStation


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for slug in PLAYLIST:
		_players[slug] = [_player(slug, ""), _player(slug, "_radio")]
	_shed = _player(SHED_SONG, "_radio", true)
	_ending = _player(ENDING_SONG, "", true)
	_start(_song)
	if _shed != null:
		_shed.play()
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
	var lead := _outdoors(_song)
	if follow_players and lead != null and lead.playing and lead.get_playback_position() > 0.0:
		_at = lead.get_playback_position()
	else:
		_at += delta
	var length := _length(_song)
	if _next < 0 and _at >= length - FADE:
		_next = (_song + 1) % PLAYLIST.size()
		_start(_next)
	if _at >= length:
		_stop(_song)
		_at -= length
		_song = _next if _next >= 0 else (_song + 1) % PLAYLIST.size()
		if _next < 0:
			_start(_song)
		_next = -1
	_radio_at = move_toward(_radio_at, 1.0 if muffled else 0.0, DOOR_FADE * delta)
	_shed_at = move_toward(_shed_at, 1.0 if indoors else 0.0, DOOR_FADE * delta)
	_ending_at = move_toward(_ending_at, 1.0 if ending else 0.0, delta / FADE)
	if _ending != null and _ending_at <= 0.0 and _ending.playing:
		_ending.stop()
	_push()


## What every player is being given right now, as linear gain before the volume and the
## song's own level: `"<slug>"` outdoors, `"<slug>_radio"` through the wall.
func gains() -> Dictionary:
	var out := {}
	var ending_gain := sin(_ending_at * PI * 0.5)
	var rest := cos(_ending_at * PI * 0.5)
	var shed_gain := sin(_shed_at * PI * 0.5) * rest
	var lake := cos(_shed_at * PI * 0.5) * rest
	for index in PLAYLIST.size():
		var song := lake * _song_gain(index)
		out[String(PLAYLIST[index])] = song * (1.0 - _radio_at)
		out[String(PLAYLIST[index]) + "_radio"] = song * _radio_at
	out[String(SHED_SONG) + "_radio"] = shed_gain
	out[String(ENDING_SONG)] = ending_gain
	return out


## Which song is leading, and how far into it.
func now_playing() -> StringName:
	return PLAYLIST[_song]


func song_time() -> float:
	return _at


func is_playing(slug: StringName) -> bool:
	if slug == SHED_SONG:
		return _shed != null and _shed.playing
	if slug == ENDING_SONG:
		return _ending != null and _ending.playing
	var pair: Array = _players.get(slug, [null, null])
	return pair[0] != null and (pair[0] as AudioStreamPlayer).playing


## The song on its way out keeps its level until `FADE_OUT` of it is left; the one coming in
## eases up under it, squared so it is still quiet while the other is still whole. The two
## together never rise much over one song's worth — about a decibel at the crossing.
func _song_gain(index: int) -> float:
	if index == _song:
		if _next < 0:
			return 1.0
		return cos(_going() * PI * 0.5)
	if index == _next:
		return pow(sin(_handover() * PI * 0.5), 2.0)
	return 0.0


## How far the next song is into its four seconds, 0 to 1.
func _handover() -> float:
	return clampf((_at - (_length(_song) - FADE)) / FADE, 0.0, 1.0)


## How far the song playing is into its own last seconds, 0 to 1.
func _going() -> float:
	return clampf((_at - (_length(_song) - FADE_OUT)) / FADE_OUT, 0.0, 1.0)


func _push() -> void:
	var given := gains()
	for slug: StringName in PLAYLIST:
		var pair: Array = _players[slug]
		_apply(pair[0], given[String(slug)], slug)
		_apply(pair[1], given[String(slug) + "_radio"], slug)
	_apply(_shed, given[String(SHED_SONG) + "_radio"], SHED_SONG)
	_apply(_ending, given[String(ENDING_SONG)], ENDING_SONG)


func _apply(player: AudioStreamPlayer, gain: float, slug: StringName) -> void:
	if player == null:
		return
	player.volume_db = (
		OFF_DB if gain < 0.0001
		else float(GAIN_DB.get(slug, 0.0)) + linear_to_db(gain)
	)


func _player(slug: StringName, suffix: String, loop: bool = false) -> AudioStreamPlayer:
	var path := DIR + String(slug) + suffix + ".mp3"
	if not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStreamMP3
	if stream == null:
		return null
	stream.loop = loop
	var player := AudioStreamPlayer.new()
	player.name = String(slug) + suffix
	player.stream = stream
	player.bus = Prefs.BUS_MUSIC
	player.volume_db = OFF_DB
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player


func _outdoors(index: int) -> AudioStreamPlayer:
	return (_players[PLAYLIST[index]] as Array)[0]


func _length(index: int) -> float:
	var lead := _outdoors(index)
	if lead == null:
		return 180.0
	return lead.stream.get_length()


func _start(index: int) -> void:
	for player: AudioStreamPlayer in _players[PLAYLIST[index]]:
		if player != null:
			player.play()


func _stop(index: int) -> void:
	for player: AudioStreamPlayer in _players[PLAYLIST[index]]:
		if player != null:
			player.stop()
