## The switch on everything that isn't part of the game yet.
##
## Two ideas are being tried out — a battery-powered truck and a rope that ties
## two pieces together — and neither has earned a place in a normal run. Rather
## than a branch or a second scene, both live in the real game behind this flag:
##
##   godot -- --experimental
##
## Off, the dock, the shop and the strait are exactly what they always were. The
## experimental systems are still built and still saved (see the note in
## SaveGame.capture) — what the flag gates is the UI and the behaviour, never the
## persistence. A player who tries the flag once, buys upgrades and then launches
## normally must not have those upgrades silently deleted by the next autosave.
##
## Static on a class_name rather than an autoload, matching Campaign: the title
## and select screens change scene, and this has to survive that without being
## re-derived by whoever happens to be running.
class_name Experimental
extends RefCounted

const FLAG := "--experimental"

static var _enabled: bool = false
static var _parsed: bool = false


static func on() -> bool:
	if not _parsed:
		_parsed = true
		_enabled = OS.get_cmdline_user_args().has(FLAG)
	return _enabled
