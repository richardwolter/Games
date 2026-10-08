extends RefCounted
## The game's own sound for the trailer (2026-10-08, `/grill-me` with Richard: "make sure all
## the sfx from recorded scenes are triggering and recorded"). The film probes logged only
## what `Sfx.play` started (`sfx.txt`), so every bed, the hose, the rain, the thunder, the
## tornado's wind, the hive and the interface were missing and had to be laid by hand.
##
## Now the SFX and Ambience buses are recorded, a stem each, per shot: `sfx.wav` and
## `ambience.wav` in the shot's folder, starting on its first kept frame. The music bus is
## muted. **Only under Godot's Movie Maker** (`--write-movie`): at a fixed frame rate the
## audio driver runs in real time and falls out of step with a film that saves a JPEG a
## frame, while Movie Maker mixes exactly one frame's worth of sound a frame. The movie file
## it writes is thrown away; the probe's own JPEGs are the picture.
##
##   godot --path . --fixed-fps 60 --write-movie tools/film/_movie.avi res://tools/film_trailer.tscn
##
## (with an `override.cfg` holding `editor/movie_writer/mjpeg_quality` low, so the throwaway
## file stays small, deleted after). Without Movie Maker nothing is recorded and nothing
## changes. The buses are set here, not through `Prefs`, so `settings.cfg` is never touched.
##
## No class_name: preload it.

const BUSES: Array[StringName] = [&"SFX", &"Ambience"]

var on := false
var _recs := {}


func _init() -> void:
	on = Engine.get_write_movie_path() != ""
	if not on:
		return
	var music := AudioServer.get_bus_index(Prefs.BUS_MUSIC)
	if music >= 0:
		AudioServer.set_bus_mute(music, true)
	_level(Prefs.BUS_MASTER, 1.0)
	_level(Prefs.BUS_SFX, 0.8)
	_level(Prefs.BUS_AMBIENCE, 0.7)
	for bus in BUSES:
		var at := AudioServer.get_bus_index(bus)
		if at < 0:
			continue
		var rec := AudioEffectRecord.new()
		rec.format = AudioStreamWAV.FORMAT_16_BITS
		AudioServer.add_bus_effect(at, rec)
		_recs[bus] = rec


## Prefs' own default levels, through Prefs' own curve, straight onto the bus.
func _level(bus: StringName, level: float) -> void:
	var at := AudioServer.get_bus_index(bus)
	if at < 0:
		return
	AudioServer.set_bus_mute(at, false)
	AudioServer.set_bus_volume_db(
		at, Prefs.volume_db(level, true, float(Prefs.BUS_TOP[bus]), Prefs.BUS_SILENT)
	)


## The shot's first kept frame: every stem starts from here.
func begin() -> void:
	for rec: AudioEffectRecord in _recs.values():
		rec.set_recording_active(false)
		rec.set_recording_active(true)


## The shot is over: each stem written to `dir` (an absolute folder).
func finish(dir: String) -> void:
	for bus: StringName in _recs:
		var rec: AudioEffectRecord = _recs[bus]
		if not rec.is_recording_active():
			continue
		var wav := rec.get_recording()
		rec.set_recording_active(false)
		if wav != null:
			wav.save_to_wav(dir.path_join("%s.wav" % String(bus).to_lower()))
