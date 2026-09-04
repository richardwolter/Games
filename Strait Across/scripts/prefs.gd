## Small persistent preferences that are not part of a run.
##
## These live in user://settings.cfg, the same file the volume is kept in, rather
## than in the save. That distinction is the whole point: "I have seen this hint,
## stop showing it" is a fact about the player, not about their current game, and
## putting it in the save would resurrect every dismissed hint the moment they
## started a new run.
##
## Deliberately not an autoload. There is no state to hold — every call reads or
## writes the file — and a config read is a few hundred bytes off disk on an event
## the player caused, never in a frame loop.
class_name Prefs
extends RefCounted

const PATH := "user://settings.cfg"
const SECTION := "hints"


## The headless checks must neither read nor write real preferences.
##
## Reading is the half that actually bit: the smoke test asserts the shop nudge
## appears, and it passed until a preference set during ordinary play made it
## fail — the test was reporting on the developer's config rather than on the
## code. Writing is the more dangerous half, since a test run could silently
## turn off a hint for the player.
##
## Same condition Main uses for the save file, checked here rather than plumbed
## through so no future caller can forget it.
static func _inert() -> bool:
	var args := OS.get_cmdline_user_args()
	return args.has("--smoke") or args.has("--carcheck")


static func get_flag(key: String, fallback: bool = false) -> bool:
	if _inert():
		return fallback
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return fallback
	return bool(config.get_value(SECTION, key, fallback))


## Read-modify-write, so this cannot clobber the volume the audio system keeps in
## the same file.
static func set_flag(key: String, value: bool) -> void:
	if _inert():
		return
	var config := ConfigFile.new()
	config.load(PATH)
	config.set_value(SECTION, key, value)
	config.save(PATH)
