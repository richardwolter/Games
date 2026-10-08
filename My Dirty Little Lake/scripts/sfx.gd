## Every sound the game makes that is not the music.
##
## Recorded, mostly (2026-09-15, Richard): the sounds are files in `assets/sfx/`, cut from the
## recordings in `art_source/SFX` by `tools/build_sfx.py`. This header used to promise there
## would never be a folder of sound files; that was the placeholders talking. The last built
## sound, the siege's chime, went with the siege (2026-09-29, issue #38).
##
## **Built again for the hive** (2026-09-30, the beehive sidequest): its seven names arrived
## before their recordings, so `HiveSounds` makes them in code and `_build_hive` puts them in
## `_streams` for any name the file pass found nothing for. A recording dropped into
## `assets/sfx/` under the same name wins on the next boot with nothing here edited.
##
## The knock of a piece coming up in the mesh is **cut, by decision** (2026-09-16): every
## place that played it already drew a splash, dropped a piece in the crate or knocked the
## box, so the knock under those was the same event sounded twice. Don't put it back.
##
## An autoload (`Sound` in project.godot), so the main menu has its clicks and the start sound
## carries across the change of scene into the lake. `Sfx.main()` finds it; a run without it
## (a `--script` tool) gets null and stays quiet. It reads its levels from `Prefs` itself.
##
## Short sounds are fired through a small pool of players so two splashes at once are two
## sounds, with a pool of its own for the interface so a sweep of catches cannot steal a
## click. The ambience and the fireplace are held loops, eased in and out.
class_name Sfx
extends Node

const DIR := "res://assets/sfx/"

## The built sounds are made at this rate. Low for a wave file and plenty for a pop and a
## diesel.
const RATE := 22050

## How many short sounds can overlap. A cast sweeping a full net fires a splash and a knock
## per piece it lifts, so this wants to be more than a couple.
const VOICES := 12
const UI_VOICES := 3

## The colony's hum, as the hive room's catch step loops it (`HiveSounds`). The lake's own
## bed of it by the hive is gone (issue #29, 2026-10-06, Richard: "remove the constant
## buzzing close to the beehive"); the name stays loaded for the room. A built loop,
## peak-normalised rather than levelled, so this is by ear and not the builder's.
const HIVE_HUM_DB := -26.0

## Every recording: its loudness against the others in decibels, and how far its pitch is
## rolled either side of true on each play. A balance, not a volume — the player's setting
## rides on top.
##
## **The mix and nothing else** (2026-09-16, issue #1): `tools/build_sfx.py` now brings every
## cut to one loudness, so a number here no longer doubles as a rescue for a take that was
## recorded twenty decibels under the rest. Every figure was shifted by that file's own gain
## on the changeover, so what is written here is the balance Richard had tuned by ear, said
## over a level floor. A re-record shifts them again — the builder's report prints by how
## much, per name.
##
## The report's shift column reads the gain against the **raw cut**, which is what the old
## build wrote for most names. The footsteps, the sniffs, the wading and the boat's water
## were peak-normalised before, so for those five the changeover was worked out against a
## peak of 0.9 instead. Nothing in the pipeline does that any more, so the column is right
## from here on.
##
## The angler's own noises are close and the lake's far: the ferry's bell is across the
## island, the splash is at arm's length.
const SOUNDS := {
	&"ferry_bell": [-20.9, 0.02],
	&"boat_move": [-15.3, 0.05],
	&"net_throw": [-11.0, 0.06],
	## A lucky cast and a double cast (2026-10-06, Richard), each on top of the throw.
	&"lucky_cast": [-11.0, 0.0],
	&"double_cast": [-11.0, 0.0],
	&"net_splash": [-17.8, 0.04],
	## A landing that caught (issue #29): six mixed takes, the empty landing's level.
	&"net_land": [-17.8, 0.03],
	&"piece_splash": [-13.9, 0.0],
	&"drip": [-14.0, 0.05],
	&"haul": [-13.0, 0.0],
	&"find_caught": [-2.5, 0.0],
	&"find_chime": [-19.7, 0.03],
	&"coin": [-10.8, 0.08],
	&"upgrade": [-7.0, 0.0],
	&"pigeon_fly": [-18.5, 0.08],
	&"pigeon_coo": [-3.0, 0.06],
	&"bark": [-5.3, 0.06],
	&"sniff": [-9.8, 0.05],
	&"step_grass": [-14.9, 0.08],
	&"step_sand": [-15.9, 0.08],
	&"wading": [-19.9, 0.04],
	&"catch_pop": [0.0, 0.0],
	&"ui_hover": [-15.6, 0.03],
	&"ui_click": [-6.0, 0.02],
	&"ui_close": [-15.4, 0.0],
	&"shed_open": [-10.5, 0.0],
	&"game_start": [-21.1, 0.0],
	&"drop_big": [-5.1, 0.05],
	## A piece landing in the island crate: three takes of Richard's own recording, one of
	## which is played per drop. A small roll on top of three real drops, where one take
	## pitched about needed a whole ladder of steps to stop being a metronome.
	&"pop": [-18.0, 0.03],
	&"drop_small": [-10.2, 0.08],
	## The second batch (2026-09-28, `/grill-me` with Richard). Every file is levelled to
	## the same loudness, so these are the mix: the doors a little under the click, the
	## puddle a step over the dry steps, the animals well under the dogs' bark, the forest
	## and the geese far off. First guesses for Richard's ear.
	&"door_open": [-9.0, 0.03],
	&"door_close": [-9.0, 0.03],
	&"step_puddle": [-16.0, 0.03],
	&"frog": [-14.0, 0.0],
	&"duck": [-13.0, 0.04],
	&"geese": [-17.0, 0.03],
	&"forest": [-18.0, 0.0],
	## Issue #29 (2026-10-06): the cardinal's song, for the cardinal songbird, played at
	## `SONGBIRD_DB` on top like the forest takes the other three sing with.
	&"cardinal": [-18.0, 0.03],
	&"bee": [-17.0, 0.04],
	## The hive (2026-09-30): built in code by `HiveSounds` until a recording takes the name.
	## **Not levelled like everything above**: a built take is peak-normalised to 0.8, which
	## for a held buzz is some ten decibels louder than the builder's -22 LUFS, so these read
	## lower than the recordings they sit beside for the same place in the mix. First guesses
	## for Richard's ear, and every one wants moving when its recording drops in. The swarm is
	## across the lawn and heard as it lands; the puff, the crackle and the lid are the player's
	## own hands in the room; the crown and the flourish are the payoffs. The hum's figure is
	## the bed's (`HIVE_HUM_DB`), written here so the name is loaded and checked with the rest.
	&"hive_swarm": [-20.0, 0.03],
	&"hive_hum": [HIVE_HUM_DB, 0.0],
	&"hive_puff": [-15.0, 0.08],
	&"hive_crackle": [-17.0, 0.12],
	&"hive_pop": [-10.0, 0.06],
	&"hive_crown": [-11.0, 0.0],
	&"hive_done": [-12.0, 0.0],
}

## The hive's builders. Preloaded rather than named, so this autoload parses before the class
## cache has heard of `HiveSounds`: a sound board that fails to parse takes every sound with it.
const HIVE_SOUNDS := preload("res://scripts/hive_sounds.gd")
## The hive's one-shots that can come thick and fast, and the least gap between two of each:
## the uncap step cracks a row of wax for every row the knife passes, and a fast hand passes
## a lot of them (contract section 6: twenty a second at most).
const HIVE_GAPS := {&"hive_crackle": 1.0 / 20.0}

## The new sounds' pitch ladders, never the step played last (the net splash's rule).
const PUDDLE_PITCHES: Array[float] = [0.84, 0.92, 1.0, 1.08, 1.16]
## The first step into the lake: the puddle's recording on a ladder of its own, wider than a
## footstep's, because it is heard once a wade and one pitch read as one take (2026-09-30).
## Going into the water, angler or dog: the entry splash and the wash that opens a wade are
## played this far under their own level (2026-10-01, Richard: "volume down a lot for all").
const ENTRY_DB := -20.0
## The water a hull pushes, stepped like the net's splash so no two departures or berthings
## sound alike (2026-10-01, Richard). Never the step played last.
const BOAT_MOVE_PITCHES: Array[float] = [0.8, 0.88, 0.95, 1.02, 1.1, 1.18]
const ENTRY_PITCHES: Array[float] = [0.72, 0.82, 0.92, 1.02, 1.13, 1.24]
## The wading wash, stepped too: narrower than the entry, since it repeats every `WADE_EVERY`
## while the boots move and a wide swing would read as different water.
const WADE_PITCHES: Array[float] = [0.88, 0.94, 1.0, 1.06, 1.12]
const FROG_PITCHES: Array[float] = [0.8, 0.9, 1.0, 1.1, 1.22]
## Gaps, rolled each time in seconds, so a species is heard now and then rather than on a
## beat: one gap a species, shared by every animal of it (the dogs' rule).
const FROG_GAP := Vector2(6.0, 12.0)
const DUCK_GAP := Vector2(15.0, 30.0)
const FOREST_GAP := Vector2(20.0, 45.0)
const BEE_GAP := Vector2(60.0, 120.0)
## Songbirds (2026-10-03): a chirp off the forest's takes from a bird within earshot, on its own
## gap; a flush of wings when one flies up, quieter than a pigeon going over.
const SONGBIRD_GAP := Vector2(8.0, 18.0)
const FLUSH_GAP := Vector2(1.2, 2.5)
const SONGBIRD_DB := -4.0
const FLUSH_DB := -6.0
## The crowd (2026-10-05, `/grill-me` with Richard: "wildlife ambient sound should get
## progressively more constant as the player cleans the lake and there are more
## creatures"): a species' gap shrinks with how many of it are within earshot, down to
## `CROWD_LEAST` of itself at `CROWD_FULL` of them. One of a kind, or none counted, is the
## gap as written; a bare shore stays as sparse as it always was. The counts are pushed by
## `Wildlife` and `Flora` about once a second (`set_crowd`). A species still never stacks
## on itself; different species may overlap.
const CROWD_LEAST := 0.25
const CROWD_FULL := {
	&"frog": 8, &"duck": 3, &"songbird": 8, &"forest": 30, &"bee": 6,
}
## How often a duck call is the far geese instead of the mallard.
const GEESE_ODDS := 0.3
## The share of heard frights a frog ribbits on, held to `FROG_GAP` like its croaks.
const FROG_FRIGHT_ODDS := 1.0 / 3.0

## Sounds with players of their own, and how many (2026-09-15, first playtest). Through the
## shared pool they were stolen: a sweep lifting a dozen pieces fires a knock each, twelve
## voices go round in a frame, and the net's splash, the haul, the bell and the chime were cut
## off a fraction of a second in.
const CHANNELS := {
	&"net_splash": 2,
	&"net_land": 2,
	&"net_throw": 1,
	&"lucky_cast": 1,
	&"double_cast": 1,
	&"haul": 3,
	&"ferry_bell": 1,
	&"boat_move": 1,
	&"find_chime": 1,
	&"find_caught": 1,
	&"bark": 1,
	&"wading": 1,
	&"sniff": 1,
	# The hive's long payoffs, so a room full of crackles cannot take their voices: the swarm
	# landing, the crown, and the flourish at the end of a harvest.
	&"hive_swarm": 1,
	&"hive_crown": 1,
	&"hive_done": 1,
	&"catch_pop": 6,
}
## Of those, the ones that are never cut: with every player busy, the new one is skipped
## rather than one playing being stopped. The haul always finishes; the chime rings out.
## What rides the Ambience bus rather than SFX (2026-09-29, Richard): every animal, the
## weather and the beds. The world going on round the player, on its own slider; what the
## player does (net, money, ferry, crate, steps, interface) stays on SFX. One place decides:
## `play` routes each voice by this set, the dedicated players read it too.
const AMBIENT := [
	&"frog", &"duck", &"geese", &"forest", &"cardinal", &"crickets", &"bee", &"pigeon_fly",
	&"pigeon_coo",
	&"bark", &"sniff", &"wading", &"fireplace", &"lake_ambient", &"rain", &"thunder",
	# The colony is the world going on; the player's hands in the hive room stay on SFX.
	&"hive_swarm", &"hive_hum",
]

## The bus a named sound plays on.
static func bus_of(name: StringName) -> StringName:
	return Prefs.BUS_AMBIENCE if name in AMBIENT else Prefs.BUS_SFX

const NEVER_CUT := [&"haul", &"find_chime", &"ferry_bell", &"boat_move", &"wading"]

## What the lake is still allowed to make a noise with while the upgrades board is up
## (2026-09-15, Richard: "keep only music, ambient and money from lake sounds").
##
## The board covers the lake, and a dog barking, a ferry setting off or a pigeon going over
## behind it is a noise with nothing to look at. The money is the exception because it is
## what the board is about: a sale landing while the shop is open is the number on the plate
## moving. The ambience is a bed, not a sound, and keeps running — the lake is still there.
## Interface sounds come through `play_ui` and are not the lake's, so they are untouched.
const WHILE_SHOPPING := [&"coin", &"upgrade"]

## The same for the shed: the room covers the lake, so the lake is not heard from inside it —
## no ferry setting off, no water, no dog (2026-09-15, Richard). What the room itself makes goes
## on: its door, the pieces put down, the fire, and the interface.
const WHILE_INDOORS := [
	&"ui_hover", &"ui_click", &"ui_close", &"shed_open", &"drop_big", &"drop_small", &"upgrade",
	&"door_open", &"door_close",
	# The wash room is indoors too, and a find coming clean on its stand rings the find's own
	# sound (issue #37). Nothing in the shed plays it, so the shed is no louder for this.
	&"find_caught",
]

## **A landing says whether it caught** (2026-09-18, `/grill-me` with Richard: "there isn't
## much of a difference when I cast a net and it catches nothing"). The ladder is split, and
## the split is what the extra pitches were spent on: a landing that took something draws
## from the low, heavy half and an empty one from the high, light half, `EMPTY_SPLASH_DB`
## quieter. Random across the whole range, pitch could not also mean anything. Six steps a
## half, so either kind of cast has as many to fall on as every cast had before. Each half
## keeps its own "never the last one" memory. (The single six-step ladder went with the lit
## net, deleted 2026-09-29.)
const NET_SPLASH_CAUGHT: Array[float] = [0.62, 0.68, 0.74, 0.81, 0.88, 0.95]
const NET_SPLASH_EMPTY: Array[float] = [1.0, 1.06, 1.12, 1.18, 1.24, 1.3]
const EMPTY_SPLASH_DB := -5.0
## **A landing that caught is a different recording each time** (issue #29, 2026-10-06,
## Richard: "more variation to the sound of the net splashing when hit the water with
## objects"): `net_land`'s six takes are the net's splash with another of the lake's
## recordings laid under it, never the take played last, still on the caught half of the
## ladder above, and rolled this many decibels either way.
const LAND_DB_ROLL := 1.5

## What a catch is answered with: **one swell, then water draining off the mesh**
## (2026-09-18, second `/grill-me` the same day, Richard: "too scripted, it feels the same
## every catch... less of a series of pops"). The first pass that morning was a run of one to
## five piece splashes 0.09 s apart, counted off a ladder of piece counts — and there is one
## piece-splash recording, so it was the same take retriggered on a fixed beat with a count
## anybody could learn. **Retired**: `CATCH_RUN_AT`, `CATCH_RUN_GAP`, `CATCH_RUN_MOST` and the
## queue of weights.
##
## The swell is that one recording played **once** a landing, `SWELL_AFTER` behind the net's
## own splash (rolled, so the two are never the same distance apart), louder and lower the
## fuller the net came down, with a pitch and a level roll on top. `SWELL_SOFT_ODDS` of them
## start a little way into the take, eased in, so the attack is sometimes a slap and
## sometimes a round push of water. A second net landing with it (the double cast) joins the
## first's swell rather than doubling it (`SWELL_GAP`).
const SWELL_AFTER := Vector2(0.08, 0.2)
const SWELL_DB := Vector2(-5.0, 2.0)
const SWELL_PITCH := Vector2(1.12, 0.84)
const SWELL_PITCH_ROLL := 0.1
const SWELL_DB_ROLL := 1.5
const SWELL_SOFT_ODDS := 0.35
const SWELL_SOFT_FROM := Vector2(0.03, 0.09)
const SWELL_SOFT_IN := 0.05
const SWELL_GAP := 0.3
## How many pieces a swell at full size is, and how much of the size is the count against
## the mean weight of what came up: a bag of cans is not a sofa.
const SWELL_FULL := 12.0
const SWELL_BY_COUNT := 0.6

## The drips after it: none to `DRIPS_MOST`, **rolled** — the fuller the net the more it
## leans to the top, but one bottle can drip twice and a full bag once. Each lands at a time
## of its own anywhere between `DRIP_FROM` and `DRIP_TO` after the swell, so there is no beat
## to learn; each is a take and a pitch of its own, and each is quieter than the one before.
## Cut from the two recordings retired as the angler's wet step for sounding like drips.
const DRIPS_MOST := 4
const DRIPS_WAITING_MOST := 6
const DRIPS_LEAN := Vector2(0.2, 3.8)
const DRIPS_ROLL := 1.2
const DRIP_FROM := 0.2
const DRIP_TO := 1.3
const DRIP_DB := -4.0
const DRIP_FALLS := -2.5
const DRIP_PITCH := Vector2(0.82, 1.3)

## A grab on the way home is a plip: one drip take, pitched by what was grabbed, no more
## than one every `GRAB_GAP`. The swell is the landing's alone — a reel through a thick bay
## grabs several times a second, and a swell each would be the series of pops again. The
## haul rising with the load is what says the net is getting heavier.
const GRAB_GAP := 0.32
const GRAB_DB := -2.0
const GRAB_PITCH := Vector2(1.25, 0.85)

## And the throw with it (2026-09-17, Richard): the cast is two takes in a row, so pitching
## the splash alone left the whoosh in front of it identical every time. A narrower spread
## than the splash's — the throw is the rope leaving the hand, and a wide swing on it reads
## as a different net rather than the same one thrown again.
const NET_THROW_PITCHES: Array[float] = [0.9, 0.97, 1.04, 1.12]

## The same for the two sounds a long haul fires most often (2026-09-16, Richard: "not too
## repetitive and tiring"). The coin lands once a piece sold and the thud once a piece boxed,
## so both are heard dozens of times a minute; one take at one pitch turns into a metronome.
## The coin's stand on their own. The thud has no ladder: it has three recordings of its own
## (2026-09-17), and `POP_PITCH`/`POP_PITCHES` went with the single take they were disguising.
const COIN_PITCHES: Array[float] = [0.88, 0.96, 1.04, 1.14]

## The find chime rings no more than once in this many seconds, from its start: the marker
## held over a find hears a ring now and then, not a peal.
const CHIME_GAP := 6.0


## The two long beds. The lake's recording is quiet (it peaks at a fifth of full scale), so it
## sits up where the short sounds sit down.
const AMBIENCE_DB := -21.1
const FIRE_DB := -5.5
## How long the wading water is silent between plays. Held as one loop it was water running
## without a break; this is a wash, a pause, and another wash.
const WADE_EVERY := 1.0

## The held loops. Read from a file each, and each set to loop on the way in.
const BEDS: Array[StringName] = [&"lake_ambient", &"fireplace", &"crickets"]

## **Crickets in the late afternoon** (issue #29, 2026-10-06, `/grill-me` with Richard: "a
## little bit of texture to lake ambient, but it shouldn't be too constant or repetitive").
## Only once the day's sun is past `CRICKET_FROM` (0 first light, 1 dusk; the loop runs it
## 0.15 to 0.8, so about a quarter of each loop), and then in spells: a wait of `CRICKET_GAP`,
## then `CRICKET_SPELL` seconds of the loop from a random point in it, eased in and out over
## `CRICKET_EASE`. Never in the shed. Ambience bus. All first guesses for Richard's ear.
const CRICKET_FROM := 0.62
const CRICKET_GAP := Vector2(15.0, 40.0)
const CRICKET_SPELL := Vector2(4.0, 10.0)
const CRICKET_EASE := 1.5
const CRICKET_DB := -26.0

## **Each dog barks at its own pitch** (issue #29, 2026-10-06), by its pack slot (`Dog.slot`,
## the breed's rule): dark brown lowest, then yellow, tan-and-white, orange. By size was the
## ask, and the four sheets are one silhouette (575 px of ink each), so the darker coat
## takes the deeper voice. `SOUNDS`' own roll rides on top.
const BARK_PITCHES: Array[float] = [0.94, 1.18, 1.06, 0.82]
## How far the lake goes under while the shed is open: heard through its wall.
const AMBIENCE_DUCK := -14.0

const CHINK_GAP := 0.06
const HOVER_GAP := 0.05
## The fleet rings no more than once in this many seconds, however many hulls set off, and
## pushes water no more than once in this many: two hulls leaving together used to play the
## same take over itself, which is what read as a weird space sound.
const BELL_GAP := 25.0
const BOAT_MOVE_GAP := 2.5
## And the same for a hull coming home (2026-09-16, Richard: the ferry arriving should have
## water and bell too, sparsely). Longer than the departure's, so an arrival bell is the
## occasional one: leaving is an announcement, coming alongside is not.
const BERTH_BELL_GAP := 70.0

## The haul is played again this often while the net is being reeled, each time pitched and
## levelled off how hard it is working.
const HAUL_EVERY := 1.0
## And each repeat within one haul is this much quieter than the last, down to HAUL_SPENT: one
## cast is one pull losing its strength, not the same wash over and over.
const HAUL_FALLS := -4.0
const HAUL_SPENT := -16.0

## A bed at or under this is not playing at all: the floor the fades run down to. It is not
## the player's slider any more (2026-09-16, issue #26) — the sliders are audio buses now
## (`Prefs`), and what is written here is each sound's own balance against the others.
const SILENT := -50.0

## How quickly a held bed fades in and out, in decibels a second.
const BED_FADE := 18.0

## Loaded recordings, name to every variant of it (`step_sand_1`, `step_sand_2`... all go
## under `step_sand`).
var _streams := {}


## When each gap-limited sound last played, in seconds.
var _last := {}

## Which step each of the pitched sounds last used, by name. See `_next_pitch`.
var _pitch_step := {}
## Name to the time its next play is allowed (`_due`).
var _next_due := {}
## How many of each species are within earshot, as last pushed (`set_crowd`).
var _crowd := {}

## The coo and the start sound get players nobody else can take. The coo went through the
## pool once, and a cast closing on a pigeon closes on a dozen pieces in the same sweep: eight
## voices later its voice had been handed to a bottle.
var _coo_player: AudioStreamPlayer
var _start_player: AudioStreamPlayer

var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
## Name to its own players (see CHANNELS), and the next one of each to steal.
var _channels := {}
var _channel_next := {}
var _ui_voices: Array[AudioStreamPlayer] = []
var _next_ui: int = 0

var _haul_effort: float = 0.0
var _haul_wait: float = 0.0
## How many times the wash has been played since this haul started.
var _haul_plays: int = 0
## The swell a landing is owed: how long until it sounds (under zero, none), and how big.
var _swell_wait: float = -1.0
var _swell_size: float = 0.0
## The drips still to come: `{"wait", "db", "pitch"}` each, every one on its own clock.
var _drips: Array[Dictionary] = []


## The beds: whether each is wanted, and the level each has eased to (before the trim).
var _ambience_player: AudioStreamPlayer
var _ambience_on: bool = false
var _ambience_duck: bool = false
var _ambience_at: float = SILENT
var _fire_player: AudioStreamPlayer
var _fire_on: bool = false
var _fire_at: float = SILENT
## The colony's hum: the level the lake last asked for and the level it has eased to.
var _cricket_player: AudioStreamPlayer
## Where the day's sun is, pushed by the lake (`set_sun`); under nought, no day.
var _sun: float = -1.0
## Seconds until the next spell starts (or, during one, until it eases out).
var _cricket_wait: float = -1.0
var _cricket_on: bool = false
var _cricket_at: float = SILENT
var _wade_on: bool = false
## Who is in the shallows: the angler and any dog, as a set. See `set_wading`.
var _wading: Dictionary = {}
var _wade_wait: float = 0.0
## Whether the next wash opens a wade: set only by the angler's entry (`play_lake_entry`),
## so stopping and walking on in the water, or a dog going in, is not a new wade. That wash
## is the loudest thing on the way in, landing a frame or two after the entry splash, so it
## takes the entry's wide ladder; the repeats keep the narrow one (2026-09-30).
var _wade_fresh: bool = false

var _rng := RandomNumberGenerator.new()


## The autoload, or null in a run that has none.
static func main() -> Sfx:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(^"Sound") as Sfx


## An interface sound from anywhere, without every button holding a reference.
static func ui(name: StringName) -> void:
	var sound := main()
	if sound != null:
		sound.play_ui(name)


## Whether the upgrades board is up, and the lake's own sounds are therefore held (see
## `WHILE_SHOPPING`). The scene pushes it; `hush` lets it go with everything else.
var shopping: bool = false

## Whether the player is in the shed, where the lake is out of earshot (`WHILE_INDOORS`).
var indoors: bool = false
var _from_room := false

## Every recording started, with the level and pitch it went out at: what the trailer's film
## probe listens to, to lay the game's own sounds under the edit in step with the picture.
## Nothing in the game connects to it.
signal played(path: String, db: float, pitch: float)


func _ready() -> void:
	_rng.randomize()
	_load_recordings()
	# After the file pass and before any bed takes its first stream: a recording found above
	# is kept, and the hum bed below gets whichever it is.
	_build_hive()
	# Ben Paramore's bubble (assets/sfx/catch_pop.wav); the built pops only without it.
	if (_streams.get(&"catch_pop", []) as Array).is_empty():
		_streams[&"catch_pop"] = _make_pops()
	for i in VOICES:
		_voices.append(_player())
	for i in UI_VOICES:
		_ui_voices.append(_player())
	for name: StringName in CHANNELS:
		var own: Array[AudioStreamPlayer] = []
		for i in int(CHANNELS[name]):
			own.append(_player())
		_channels[name] = own
		_channel_next[name] = 0
	_coo_player = _player(null, bus_of(&"pigeon_coo"))
	_start_player = _player()
	_ambience_player = _player(_first(&"lake_ambient"), bus_of(&"lake_ambient"))
	_fire_player = _player(_first(&"fireplace"), bus_of(&"fireplace"))
	_cricket_player = _player(_first(&"crickets"), bus_of(&"crickets"))


## Every voice goes to the SFX bus, which is where the player's slider now is. The lake's
## own bed is the exception: Ambience is its own slider, so it is its own bus.
func _player(stream: AudioStream = null, bus: StringName = Prefs.BUS_SFX) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	add_child(player)
	return player


## Every name in SOUNDS, plus the two beds, as one file or as numbered variants.
func _load_recordings() -> void:
	var names: Array = SOUNDS.keys()
	names.append_array(BEDS)
	# The barks and sniffs are numbered like the steps.
	for name: StringName in names:
		var found: Array[AudioStream] = []
		for ext: String in [".wav", ".ogg"]:
			var path := DIR + String(name) + ext
			if ResourceLoader.exists(path):
				found.append(load(path))
		var n := 1
		while ResourceLoader.exists(DIR + "%s_%d.wav" % [name, n]):
			found.append(load(DIR + "%s_%d.wav" % [name, n]))
			n += 1
		for stream in found:
			# The beds loop; a wave file has to be told where, since the cut has no loop point
			# written into it.
			if name not in BEDS:
				continue
			var ogg := stream as AudioStreamOggVorbis
			if ogg != null:
				ogg.loop = true
			var wav := stream as AudioStreamWAV
			if wav != null:
				wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
				wav.loop_begin = 0
				wav.loop_end = wav.data.size() / 4
		_streams[name] = found


## The hive's names with no file behind them, built (`HiveSounds`): one take each, three of
## the puff and the crackle so `next_step` has something to step between. Here, at boot and
## not on first play, because test_lake asks that every name in SOUNDS is loaded.
##
## A recorded hum has no loop point written into it, and the bed pass above cannot give it
## one — it assumes a stereo file — so a found `hive_hum` is looped here on a copy, counted
## in its own frames.
func _build_hive() -> void:
	for name: StringName in HIVE_SOUNDS.BOOT:
		var found: Array = _streams.get(name, [])
		if found.is_empty():
			_streams[name] = HIVE_SOUNDS.takes(name)
		elif name == &"hive_hum":
			var looped: Array[AudioStream] = []
			for stream: AudioStream in found:
				looped.append(HIVE_SOUNDS.looped(stream))
			_streams[name] = looped


## How many recordings a name loaded, so a caller picking one by hand does not have to know.
func _count(name: StringName) -> int:
	return int((_streams.get(name, []) as Array).size())


func _first(name: StringName) -> AudioStream:
	var list: Array = _streams.get(name, [])
	return list[0] if not list.is_empty() else null


func _process(delta: float) -> void:
	if _haul_effort > 0.0 and not shopping:
		_haul_wait -= delta
		if _haul_wait <= 0.0:
			_haul_wait = HAUL_EVERY
			var spent := maxf(HAUL_FALLS * float(_haul_plays), HAUL_SPENT)
			play(
				&"haul",
				lerpf(-8.0, 1.0, _haul_effort) + spent,
				lerpf(0.88, 1.1, _haul_effort)
			)
			_haul_plays += 1
	else:
		_haul_wait = 0.0
		_haul_plays = 0
	_tick_catch(delta)
	var ambience_want := SILENT
	if _ambience_on:
		ambience_want = AMBIENCE_DB + (AMBIENCE_DUCK if _ambience_duck else 0.0)
	_ambience_at = _bed(_ambience_player, _ambience_at, ambience_want, delta)
	_fire_at = _bed(_fire_player, _fire_at, FIRE_DB if _fire_on else SILENT, delta)
	_tick_crickets(delta)
	# The held sounds go quiet with the rest of the lake while the board is up. The ambience
	# above does not: it is the bed the lake plays under everything, board or no board.
	# The wading wash: while the boots are moving water, play it, let it finish, wait
	# WADE_EVERY, play it again. Its own player, so nothing cuts it short.
	if _wade_on and not shopping:
		if is_playing(&"wading"):
			_wade_wait = WADE_EVERY
		else:
			_wade_wait -= delta
			if _wade_wait <= 0.0:
				_wade_wait = WADE_EVERY
				play(&"wading", 0.0, wade_pitch())
	else:
		_wade_wait = 0.0


## One frame of a bed: ease its level towards where it is wanted, and stop it outright once it
## is inaudible so a quiet lake costs nothing. A stopped bed starts again from the top.
func _bed(player: AudioStreamPlayer, at: float, want: float, delta: float) -> float:
	if player == null or player.stream == null:
		return at
	var now := move_toward(at, want, BED_FADE * delta)
	if now <= SILENT + 0.01:
		if player.playing:
			player.stop()
		return now
	player.volume_db = now
	if not player.playing:
		player.play()
	return now


## Stop everything held. The lake calls this on its way out, because this node outlives it
## and a haul or an ambience left running into the main menu is a ghost.
func hush() -> void:
	shopping = false
	indoors = false
	_haul_effort = 0.0
	_haul_plays = 0
	_swell_wait = -1.0
	_drips.clear()
	_ambience_on = false
	_ambience_duck = false
	_fire_on = false
	_sun = -1.0
	_cricket_on = false
	_cricket_wait = -1.0
	_wade_on = false
	_wade_wait = 0.0


## A recording by name, through the pool. `db` is added to its balance and `pitch` multiplies
## its roll. Any variant, picked at random.
## `take` picks one of a name's numbered recordings by hand, for a sound whose variants are
## what stand in for a pitch ladder; -1 leaves the roll to chance, as every other name does.
func play(
	name: StringName, db: float = 0.0, pitch: float = 1.0, take: int = -1
) -> AudioStreamPlayer:
	var list: Array = _streams.get(name, [])
	if list.is_empty() or not may_play(name):
		return null
	var voice: AudioStreamPlayer
	if _channels.has(name):
		var own: Array[AudioStreamPlayer] = _channels[name]
		voice = _idle(own)
		if voice == null:
			if name in NEVER_CUT:
				return null
			voice = own[_channel_next[name]]
			_channel_next[name] = (int(_channel_next[name]) + 1) % own.size()
	else:
		voice = _idle(_voices)
		if voice == null:
			voice = _voices[_next_voice]
			_next_voice = (_next_voice + 1) % _voices.size()
	var tune: Array = SOUNDS.get(name, [0.0, 0.0])
	var spread: float = tune[1]
	voice.stream = list[take % list.size()] if take >= 0 else list[_rng.randi() % list.size()]
	voice.bus = bus_of(name)
	voice.volume_db = float(tune[0]) + db
	voice.pitch_scale = pitch * _rng.randf_range(1.0 - spread, 1.0 + spread)
	voice.play()
	played.emit(voice.stream.resource_path, voice.volume_db, voice.pitch_scale)
	return voice


## Whether a sound of the lake's may be heard at all right now: where the player is, and the
## upgrades board holding everything but the money. Not the volume — a slider at zero mutes
## the bus (`Prefs`), and asking the setting here as well would be a second copy of it.
func may_play(name: StringName) -> bool:
	if _from_room:
		return true
	return (
		(not shopping or name in WHILE_SHOPPING)
		and (not indoors or name in WHILE_INDOORS)
	)


## A bark or a coo **out of the wash room's own view** (2026-09-19): the dogs and pigeons in
## its backdrop answer the jet. Not on `WHILE_INDOORS` — put there, the lake's real pack,
## which goes on barking behind the room, would be let through with them. The room's own
## call is what is let through, not the name.
func room_bark(slot: int = -1) -> void:
	_from_room = true
	play_bark(slot)
	_from_room = false


## A dog petted in the shed sniffs through the room's own door (2026-09-28), the way the wash
## room's backdrop barks: the room's call is what is let in, not the name.
func room_sniff() -> void:
	_from_room = true
	play_sniff()
	_from_room = false


func room_coo() -> void:
	_from_room = true
	play_coo()
	_from_room = false


## The first player in a pool with nothing playing, or null.
func _idle(pool: Array[AudioStreamPlayer]) -> AudioStreamPlayer:
	for voice in pool:
		if not voice.playing:
			return voice
	return null


## Whether a sound with players of its own is still sounding.
func is_playing(name: StringName) -> bool:
	for voice: AudioStreamPlayer in _channels.get(name, []):
		if voice.playing:
			return true
	return false


## The same, through the interface's own voices.
func play_ui(name: StringName) -> void:
	if name == &"ui_hover" and not _gap(name, HOVER_GAP):
		return
	var list: Array = _streams.get(name, [])
	if list.is_empty() or _ui_voices.is_empty():
		return
	var voice := _ui_voices[_next_ui]
	_next_ui = (_next_ui + 1) % _ui_voices.size()
	var tune: Array = SOUNDS.get(name, [0.0, 0.0])
	var spread: float = tune[1]
	voice.stream = list[_rng.randi() % list.size()]
	voice.volume_db = float(tune[0])
	voice.pitch_scale = _rng.randf_range(1.0 - spread, 1.0 + spread)
	voice.play()
	played.emit(voice.stream.resource_path, voice.volume_db, voice.pitch_scale)


## Whether `gap` seconds have passed since `name` last got through, and if so, marks now.
func _gap(name: StringName, gap: float) -> bool:
	var now := float(Time.get_ticks_msec()) / 1000.0
	if now - float(_last.get(name, -1000.0)) < gap:
		return false
	_last[name] = now
	return true



## A thrown net landing. `caught` is whether the landing's own sweep took anything, so the
## sweep has to have run first. See NET_SPLASH_CAUGHT.
func play_landing(caught: bool) -> void:
	if caught and _count(&"net_land") > 0:
		play(
			&"net_land",
			_rng.randf_range(-LAND_DB_ROLL, LAND_DB_ROLL),
			_next_pitch(&"net_splash_caught", NET_SPLASH_CAUGHT),
			next_step(&"net_land", _count(&"net_land"))
		)
	elif caught:
		play(&"net_splash", 0.0, _next_pitch(&"net_splash_caught", NET_SPLASH_CAUGHT))
	else:
		play(
			&"net_splash",
			EMPTY_SPLASH_DB,
			_next_pitch(&"net_splash_empty", NET_SPLASH_EMPTY)
		)


## How big a swell `weights` is worth, 0 to 1: how many came up against SWELL_FULL, and how
## heavy they were. The root of the count, because the first few pieces are most of the
## difference between a catch and none.
static func swell_size(weights: Array[float]) -> float:
	if weights.is_empty():
		return 0.0
	var sum := 0.0
	for weight in weights:
		sum += weight
	var by_count := sqrt(minf(float(weights.size()) / SWELL_FULL, 1.0))
	var by_weight := clampf(sum / float(weights.size()) / 0.85, 0.0, 1.0)
	return lerpf(by_weight, by_count, SWELL_BY_COUNT)


## What a landing's sweep lifted, as the weights its drawn splashes were given: one swell
## behind the net's own splash, then the drips. See SWELL_AFTER and DRIPS_MOST.
func play_lifted(weights: Array[float]) -> void:
	if weights.is_empty() or not may_play(&"piece_splash"):
		return
	var fresh := _gap(&"swell", SWELL_GAP)
	if fresh:
		_pop_rung = 0
	_pop_ladder(weights.size(), POP_FIRST)
	var size := swell_size(weights)
	if fresh:
		_swell_wait = _rng.randf_range(SWELL_AFTER.x, SWELL_AFTER.y)
		_swell_size = size
	else:
		# A second net down with the first: one body of water, as big as the bigger.
		_swell_size = maxf(_swell_size, size)
	var lean := lerpf(DRIPS_LEAN.x, DRIPS_LEAN.y, size)
	var count := clampi(roundi(lean + _rng.randf_range(-DRIPS_ROLL, DRIPS_ROLL)), 0, DRIPS_MOST)
	var times: Array[float] = []
	for i in count:
		times.append(_rng.randf_range(DRIP_FROM, DRIP_TO))
	times.sort()
	var after := maxf(_swell_wait, 0.0)
	for i in count:
		if _drips.size() >= DRIPS_WAITING_MOST:
			return
		_drips.append({
			"wait": after + times[i],
			"db": DRIP_DB + DRIP_FALLS * float(i) + _rng.randf_range(-1.5, 1.5),
			"pitch": _rng.randf_range(DRIP_PITCH.x, DRIP_PITCH.y),
		})


## The catch's pops (2026-10-01, Richard: "a soft pop when objects are caught, satisfying
## as it gets more items"; second pass: louder and lower): one soft built bubble pop a
## piece, after the net's splash, each a step up `POP_PITCH` from the last and a
## touch louder, the gaps tightening, so a full net is a rising run. Capped at `POPS_MOST`.
## Grabs on the way home carry on the same cast's ladder. Built in code until Nuven records
## one; since 2026-10-01 it is the recording `catch_pop.wav`, the built takes a fallback.
const POP_DB := -10.0
const POPS_MOST := 80
## A run longer than `POP_EVEN` pieces has its gaps shrunk to fit about as long as that
## many would take, so a full net is a quick rattle rather than a five-second count.
const POP_EVEN := 14
const POP_FIRST := 0.14
## Third pass: the pitch climbs `POP_PITCH` from the first pop to the `POPS_MOST`th, and the
## run is not a beat: `POP_CLUMP` of pops land within `POP_TOGETHER` of the one before
## (overlapping it), the rest after an uneven `POP_GAP`.
const POP_GAP := Vector2(0.05, 0.16)
const POP_CLUMP := 0.5
const POP_TOGETHER := 0.02
const POP_PITCH := Vector2(0.4, 0.7)
const POP_LOUDER := 0.35
const POP_TOP_STEPS := 14
var _pop_rung := 0
var _pops: Array = []
## Pops sounded so far, ever: the haul count over the angler steps up one figure a pop
## (`HaulCount`, 2026-10-01: "match the number going up on player head").
var pops_heard := 0


func pops_waiting() -> int:
	return _pops.size()


func _pop_ladder(count: int, after: float) -> void:
	var wait := after
	for i in mini(count, POPS_MOST):
		if _pops.size() >= POPS_MOST:
			return
		var rung := mini(_pop_rung, POP_TOP_STEPS)
		_pops.append({
			"wait": wait,
			"pitch": lerpf(POP_PITCH.x, POP_PITCH.y, float(rung) / float(POP_TOP_STEPS))
				* _rng.randf_range(0.97, 1.03),
			"db": POP_DB + POP_LOUDER * float(rung) + _rng.randf_range(-1.0, 0.5),
		})
		_pop_rung += 1
		var squeeze := minf(1.0, float(POP_EVEN) / float(maxi(count, 1)))
		if _rng.randf() < POP_CLUMP:
			wait += _rng.randf_range(0.0, POP_TOGETHER)
		else:
			wait += _rng.randf_range(POP_GAP.x, POP_GAP.y) * squeeze


func _tick_pops(delta: float) -> void:
	for i in range(_pops.size() - 1, -1, -1):
		var pop: Dictionary = _pops[i]
		pop["wait"] = float(pop["wait"]) - delta
		if float(pop["wait"]) <= 0.0:
			_pops.remove_at(i)
			pops_heard += 1
			play(&"catch_pop", float(pop["db"]), float(pop["pitch"]))


## Three soft bubble pops: a sine gliding up as the bubble closes, a quick attack and a short
## decay, a little second harmonic for body. Peak 0.5, so `POP_DB` is the mix.
func _make_pops() -> Array[AudioStream]:
	var takes: Array[AudioStream] = []
	for k in 3:
		var length := 0.07 + 0.012 * float(k)
		var n := int(RATE * length)
		var samples := PackedFloat32Array()
		samples.resize(n)
		var phase := 0.0
		var from := 430.0 + 40.0 * float(k)
		for i in n:
			var t := float(i) / RATE
			var u := t / length
			var freq := from * (1.0 + 0.9 * (1.0 - exp(-u * 6.0)))
			phase += TAU * freq / RATE
			var env := minf(t / 0.003, 1.0) * exp(-t / (0.018 + 0.004 * float(k)))
			samples[i] = 0.5 * env * (sin(phase) + 0.18 * sin(phase * 2.0))
		takes.append(_to_wav(samples, false))
	return takes


## A grab on the way home. See GRAB_GAP.
func play_grab(weights: Array[float]) -> void:
	if not weights.is_empty() and may_play(&"piece_splash"):
		_pop_ladder(weights.size(), 0.0)
	if weights.is_empty() or not _gap(&"grab", GRAB_GAP):
		return
	var size := swell_size(weights)
	_drip(GRAB_DB + _rng.randf_range(-2.0, 1.0), lerpf(GRAB_PITCH.x, GRAB_PITCH.y, size))


func _drip(db: float, pitch: float) -> void:
	play(&"drip", db, pitch, next_step(&"drip", _count(&"drip")))


## The swell and the drips, each on its own clock. Dropped whole the moment the lake may not
## be heard: a board opening over a catch is not owed the rest of it when it shuts.
func _tick_catch(delta: float) -> void:
	if _swell_wait < 0.0 and _drips.is_empty() and _pops.is_empty():
		return
	if not may_play(&"piece_splash"):
		_swell_wait = -1.0
		_drips.clear()
		_pops.clear()
		return
	_tick_pops(delta)
	if _swell_wait >= 0.0:
		_swell_wait -= delta
		if _swell_wait < 0.0:
			_sound_swell(_swell_size)
	for i in range(_drips.size() - 1, -1, -1):
		var drip: Dictionary = _drips[i]
		drip["wait"] = float(drip["wait"]) - delta
		if float(drip["wait"]) <= 0.0:
			_drips.remove_at(i)
			_drip(float(drip["db"]), float(drip["pitch"]))


func _sound_swell(size: float) -> void:
	var db := lerpf(SWELL_DB.x, SWELL_DB.y, size) + _rng.randf_range(-SWELL_DB_ROLL, SWELL_DB_ROLL)
	var pitch := lerpf(SWELL_PITCH.x, SWELL_PITCH.y, size)
	pitch *= _rng.randf_range(1.0 - SWELL_PITCH_ROLL, 1.0 + SWELL_PITCH_ROLL)
	var voice := play(&"piece_splash", db, pitch)
	if voice == null or _rng.randf() >= SWELL_SOFT_ODDS:
		return
	# Past its own attack, and eased in over a few mix buffers: started cold in the middle
	# of a waveform a take clicks.
	var full := voice.volume_db
	voice.play(_rng.randf_range(SWELL_SOFT_FROM.x, SWELL_SOFT_FROM.y))
	voice.volume_db = full - 30.0
	create_tween().tween_property(voice, "volume_db", full, SWELL_SOFT_IN)


## One of `steps`, never the one this name used last, so two plays in a row are always a
## different pitch. SOUNDS' own small roll goes on top of it in `play`.
func _next_pitch(name: StringName, steps: Array[float]) -> float:
	return steps[next_step(name, steps.size())]


## An index under `count`, never the one this name was last given. The pitch ladders and the
## thud's three takes are the same rule — what is being avoided is the repeat, not the pitch.
func next_step(name: StringName, count: int) -> int:
	# A name whose files are missing asks for a step of nothing; `play` will drop it anyway.
	if count <= 1:
		return 0
	var was := int(_pitch_step.get(name, -1))
	var step := _rng.randi() % count
	if step == was:
		step = (step + 1 + _rng.randi() % (count - 1)) % count
	_pitch_step[name] = step
	return step


## The net leaving the angler's hands.
func play_throw() -> void:
	play(&"net_throw", 0.0, _next_pitch(&"net_throw", NET_THROW_PITCHES))


## What the luck roll made of a cast, on top of its throw (2026-10-06, Richard): the lucky
## cast's own sound, the double cast's hit, or both when it is both. `double` only when the
## second net really flies.
## Neither is rolled in pitch (Richard, same day); the lucky one is played lower, at
## `LUCKY_PITCH`.
const LUCKY_PITCH := 0.85


func play_luck(lucky: bool, double: bool) -> void:
	if lucky:
		play(&"lucky_cast", 0.0, LUCKY_PITCH)
	if double:
		play(&"double_cast")


## A piece of rubbish landing in a box. One of three takes of the same drop, never the one
## played last: this is a sound the player hears a thousand times, and it has its own
## recording rather than the shed's furniture thud pitched down (2026-09-17).
##
## Its own name, so the shed's allow-list refuses it without being asked to: a yard filling
## while the player decorates is out of earshot like the rest of the lake, which `play_pop`
## used to have to say for itself while it borrowed `drop_big`.
func play_pop() -> void:
	play(&"pop", 0.0, 1.0, next_step(&"pop", _count(&"pop")))


## A ferry setting off from the island's dock.
func play_bell() -> void:
	# The water the hull pushes as it leaves, one hull at a time; the bell over it, now and then.
	if not is_playing(&"boat_move") and _gap(&"boat_move", BOAT_MOVE_GAP):
		play(&"boat_move", 0.0, _next_pitch(&"boat_move", BOAT_MOVE_PITCHES))
	if not is_playing(&"ferry_bell") and _gap(&"ferry_bell", BELL_GAP):
		play(&"ferry_bell")


## A ferry coming alongside the island's dock. The water it pushes as it comes in, on the
## fleet's own gap; the bell over it far more rarely than on the way out.
##
## The pier end is silent, by decision (2026-09-16): it is across the lake from where the
## player stands, and the coins are what say a delivery landed.
func play_berth() -> void:
	if not is_playing(&"boat_move") and _gap(&"boat_move", BOAT_MOVE_GAP):
		play(&"boat_move", 0.0, _next_pitch(&"boat_move", BOAT_MOVE_PITCHES))
	if not is_playing(&"ferry_bell") and _gap(&"ferry_bell", BERTH_BELL_GAP):
		play(&"ferry_bell")


## A find brought up in the net.
func play_find_caught() -> void:
	play(&"find_caught")


## A find shining at the player: one uncovered. Rung only if it is not already ringing.
func play_find_chime() -> void:
	_ring_chime()


## The aim marker over a shining find, or not, every frame. While it is over one the chime
## rings now and then, no more than once in CHIME_GAP; once it leaves, the one playing
## finishes and nothing more starts. Never restarted while it is still sounding.
func hover_find(over: bool) -> void:
	if over:
		_ring_chime()


func _ring_chime() -> void:
	if not is_playing(&"find_chime") and _gap(&"find_chime", CHIME_GAP):
		play(&"find_chime")


## An upgrade bought.
func play_bought() -> void:
	play(&"upgrade")


## A coin reaching the plate. No more than one every CHINK_GAP.
func play_chink() -> void:
	if _gap(&"coin", CHINK_GAP):
		play(&"coin", 0.0, _next_pitch(&"coin", COIN_PITCHES))


## A pigeon going over.
func play_wings() -> void:
	play(&"pigeon_fly")


## A pigeon lifted out of the lake, saying so. On its own player.
func play_coo() -> void:
	var list: Array = _streams.get(&"pigeon_coo", [])
	if _coo_player == null or list.is_empty() or not may_play(&"pigeon_coo"):
		return
	var tune: Array = SOUNDS[&"pigeon_coo"]
	_coo_player.stream = list[0]
	_coo_player.volume_db = float(tune[0])
	_coo_player.pitch_scale = _rng.randf_range(1.0 - tune[1], 1.0 + tune[1])
	_coo_player.play()
	played.emit(_coo_player.stream.resource_path, _coo_player.volume_db, _coo_player.pitch_scale)


## The net being hauled. `effort` is how much water it is moving; zero stops the haul
## sound from being played again. Called every frame by the lake.
func set_drag(effort: float) -> void:
	_haul_effort = clampf(effort, 0.0, 1.0)


## One footstep. `surface` is &"grass" or &"sand"; the shallows are a held loop instead
## (`set_wading`), because what the recording has is water being moved, not a footfall.
func play_step(surface: StringName) -> void:
	play(StringName("step_" + String(surface)))


## Whether somebody is walking in the shallows, pushed every frame by each walker that can
## be in them — the angler and every dog (2026-09-16).
##
## Keyed by walker, because there is one wading loop and four dogs: a boolean set by
## whoever pushed last would be turned off by a dog on the lawn while the angler stood in
## the water. The loop runs if anybody is in it; the key is dropped when its walker leaves
## the tree, so a freed dog cannot hold it on for ever.
func set_wading(wading: bool, who: Object = null) -> void:
	if wading:
		_wading[who] = true
	else:
		_wading.erase(who)
	for walker: Variant in _wading.keys():
		if walker != null and not is_instance_valid(walker):
			_wading.erase(walker)
	_wade_on = not _wading.is_empty()


## The pitch of the next wash: the entry's wide ladder when it opens a wade, the narrow one
## after. Public so the harness can ask it without a player in the tree.
func wade_pitch() -> float:
	if _wade_fresh:
		_wade_fresh = false
		return _next_pitch(&"wade_entry", ENTRY_PITCHES)
	return _next_pitch(&"wading", WADE_PITCHES)


## A footfall in a puddle on the lawn.
func play_puddle_step() -> void:
	play(&"step_puddle", 0.0, _next_pitch(&"step_puddle", PUDDLE_PITCHES))


## The first step into the lake: the puddle's splash on `ENTRY_PITCHES`, with a memory of its
## own so a puddle on the lawn does not decide the next entry's pitch.
func play_lake_entry() -> void:
	play(&"step_puddle", ENTRY_DB, _next_pitch(&"lake_entry", ENTRY_PITCHES))
	_wade_fresh = true


## The shed's door: the creak going in, the solid shut coming out.
func play_door(open: bool) -> void:
	play(&"door_open" if open else &"door_close")


## Whether a species' own rolled gap has run out; if so, rolls the next one, shortened by
## the crowd within earshot (`crowd_scale`).
func _due(name: StringName, gap: Vector2) -> bool:
	var now := float(Time.get_ticks_msec()) / 1000.0
	if now < float(_next_due.get(name, -1.0)):
		return false
	_next_due[name] = now + _rng.randf_range(gap.x, gap.y) * crowd_scale(name)
	return true


## How many of a species are within earshot now. Set by the wildlife and the flora.
func set_crowd(name: StringName, count: int) -> void:
	_crowd[name] = count


## What a species' gap is multiplied by for the crowd within earshot: 1 for one or none,
## easing to `CROWD_LEAST` at `CROWD_FULL`. A species with no crowd entry is not scaled.
func crowd_scale(name: StringName) -> float:
	if not CROWD_FULL.has(name):
		return 1.0
	var full := maxi(2, int(CROWD_FULL[name]))
	var share := clampf(float(int(_crowd.get(name, 0)) - 1) / float(full - 1), 0.0, 1.0)
	return lerpf(1.0, CROWD_LEAST, share)


## A frog within earshot croaking. Sparse by `FROG_GAP`, whatever the frogs are doing.
func play_frog() -> bool:
	if not may_play(&"frog") or not _due(&"frog", FROG_GAP):
		return false
	play(&"frog", 0.0, _next_pitch(&"frog", FROG_PITCHES))
	return true


## A brood within earshot calling; `arriving` is the first ducks the lake has seen, which
## always call. Now and then the far geese instead of the mallard.
func play_duck(arriving: bool = false) -> void:
	if not may_play(&"duck"):
		return
	if not _due(&"duck", DUCK_GAP) and not arriving:
		return
	if arriving:
		_next_due[&"duck"] = float(Time.get_ticks_msec()) / 1000.0 + DUCK_GAP.x
		play(&"duck", 0.0, 1.0, next_step(&"duck", _count(&"duck")))
		play(&"geese", -3.0, 1.0, next_step(&"geese", _count(&"geese")))
		return
	if _rng.randf() < GEESE_ODDS:
		play(&"geese", 0.0, 1.0, next_step(&"geese", _count(&"geese")))
	else:
		play(&"duck", 0.0, 1.0, next_step(&"duck", _count(&"duck")))


## Birds and insects off the woods while a plant near the angler grows in.
func play_forest() -> void:
	if may_play(&"forest") and _due(&"forest", FOREST_GAP):
		play(&"forest", 0.0, 1.0, next_step(&"forest", _count(&"forest")))


## A songbird within earshot singing, on the songbirds' own gap: a cardinal sings the
## cardinal's own song (issue #29), the other three one of the forest's takes.
func play_songbird(species: String = "") -> void:
	var name := &"cardinal" if species == "cardinal" and _count(&"cardinal") > 0 else &"forest"
	if may_play(name) and _due(&"songbird", SONGBIRD_GAP):
		play(name, SONGBIRD_DB, 1.0, next_step(name, _count(name)))


## A songbird flushed within earshot: the pigeon's wings, quieter, on their own gap.
func play_flush() -> void:
	if may_play(&"pigeon_fly") and _due(&"flush", FLUSH_GAP):
		play(&"pigeon_fly", FLUSH_DB, 1.25)


## A bee going by, left ear to right, baked into the take. Very rare.
func play_bee() -> void:
	if may_play(&"bee") and _due(&"bee", BEE_GAP):
		play(&"bee")


## A bark. `slot` is the dog's pack slot, which picks its voice (`BARK_PITCHES`); under nought,
## true pitch. `db` is added to the balance, for the faint bark from across the island.
func play_bark(slot: int = -1, db: float = 0.0) -> void:
	play(&"bark", db, bark_pitch(slot))


static func bark_pitch(slot: int) -> float:
	return 1.0 if slot < 0 else BARK_PITCHES[posmod(slot, BARK_PITCHES.size())]


func play_sniff() -> void:
	play(&"sniff")


## A piece put down in the shed: a tap for a small thing or a painting, a thud for furniture.
func play_drop(small: bool) -> void:
	play(&"drop_small" if small else &"drop_big")


## Whether a lit fireplace is in the room the player is looking at.
func set_fireplace(lit: bool) -> void:
	_fire_on = lit


## Where the day's sun is (`DayCycle.sun`), pushed every frame by the lake: what the crickets
## wait on. Under nought, no day and no crickets.
func set_sun(sun: float) -> void:
	_sun = sun


## Whether the crickets may be heard now: a late afternoon on a lake the player is out on.
func crickets_due() -> bool:
	return _sun >= CRICKET_FROM and _ambience_on and not indoors


## One frame of the crickets: a wait, a spell from a random point in the loop, a wait again.
## Out of the late afternoon a spell under way eases out and the next wait is rolled afresh.
func _tick_crickets(delta: float) -> void:
	if _cricket_player == null or _cricket_player.stream == null:
		return
	if not crickets_due():
		_cricket_on = false
		_cricket_wait = -1.0
	else:
		if _cricket_wait < 0.0:
			_cricket_wait = _rng.randf_range(CRICKET_GAP.x, CRICKET_GAP.y)
		_cricket_wait -= delta
		if _cricket_wait <= 0.0:
			_cricket_on = not _cricket_on
			if _cricket_on:
				_cricket_wait = _rng.randf_range(CRICKET_SPELL.x, CRICKET_SPELL.y)
				if not _cricket_player.playing:
					_cricket_player.volume_db = SILENT
					_cricket_player.play(
						_rng.randf_range(0.0, _cricket_player.stream.get_length())
					)
			else:
				_cricket_wait = _rng.randf_range(CRICKET_GAP.x, CRICKET_GAP.y)
	var want := CRICKET_DB if _cricket_on else SILENT
	var rate := (CRICKET_DB - SILENT) / CRICKET_EASE
	_cricket_at = move_toward(_cricket_at, want, rate * delta)
	if _cricket_at <= SILENT + 0.01:
		if _cricket_player.playing:
			_cricket_player.stop()
		return
	_cricket_player.volume_db = _cricket_at


## One of the hive's one-shots, for the room and the lake. A name with takes (the puff, the
## crackle) never plays the one it played last; a name in `HIVE_GAPS` is held to its gap and
## gives back null when it is too soon. `pitch_roll` false plays it at true pitch, for a sound
## a step is pitching itself; `db` is added to its balance.
func play_hive(name: StringName, pitch_roll: bool = true, db: float = 0.0) -> AudioStreamPlayer:
	if HIVE_GAPS.has(name) and not _gap(name, float(HIVE_GAPS[name])):
		return null
	var voice := play(name, db, 1.0, next_step(name, _count(name)))
	if voice != null and not pitch_roll:
		voice.pitch_scale = 1.0
	return voice


## Whether the lake is up, and whether it is being heard through the shed's wall.
func set_ambience(playing: bool, ducked: bool = false) -> void:
	_ambience_on = playing
	_ambience_duck = ducked


## New game or Continue, pressed on the menu. Its own player, on this node, so it carries on
## into the lake after the menu is gone.
func play_start() -> void:
	var list: Array = _streams.get(&"game_start", [])
	if _start_player == null or list.is_empty():
		return
	_start_player.stream = list[0]
	_start_player.volume_db = float(SOUNDS[&"game_start"][0])
	_start_player.play()
	played.emit(_start_player.stream.resource_path, _start_player.volume_db, _start_player.pitch_scale)


## Float buffer to a 16-bit mono wave, clipped rather than normalised so a sound that was
## built too loud is a mistake that can be heard and fixed.
func _to_wav(samples: PackedFloat32Array, looping: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	if looping:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav
