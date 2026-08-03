## What build is this?
##
## Playtesters report against a build, not against a commit, and "is this the one
## with the fish fixed" is a question they cannot answer from inside the game
## unless the game says. So the title screen prints this.
##
## The version is read from project.godot rather than duplicated here, so there is
## one place to bump it. The stamp below is rewritten by tools/build_web.sh on
## every export — it is deliberately a generated constant rather than something
## read at runtime, because the obvious runtime answers do not survive an export:
## a file's modification time is gone once it is inside the .pck, and on web there
## is no filesystem to ask in the first place.
##
## If the stamp ever reads "dev", the build was made by hand from the editor
## rather than through the script, and its date is unknown.
class_name BuildInfo
extends RefCounted

## Rewritten on export. Do not edit by hand.
const STAMP := "2026-08-03 1338"


static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


## The one line to show a playtester, e.g. "v0.5.0 · build 2026-08-02 1042".
static func line() -> String:
	return "v%s · build %s" % [version(), STAMP]
