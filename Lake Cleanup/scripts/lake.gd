## The lake: the basin, the rubbish floating on it, the island it is worked from, and the
## pollution meter everything feeds.
##
## Isometric. One basin, seen from above and at an angle, so what the player looks at is
## the water's surface — and only what is on the surface is drawn. The rubbish is still a
## stack per tile (see lake_grid.gd), but the stacks below the waterline are data the
## player reads through the top piece rather than a heap to render. There is no physics
## anywhere in this game: the water is a shader and the splashes are hand-drawn, so
## nothing can pop, jitter, explode, or fall through anything.
##
## The loop is two halves that need each other. The angler stands on the island and casts
## a net at the water; the pollution meter drops the instant the mouth closes on a piece
## (see _on_net_caught), not whenever the haul finishes crossing the lake — what the net
## drags home goes into the yard instead, which is a hard cap on the catch rather than
## the thing the meter watches. So the only way to keep fishing is the other half: the
## ferry loads the yard and does a round of the four merchants on the bank, one per
## material, selling as it goes — and that is where the money comes from. Cleaning and
## earning are two different actions on purpose.
##
## This script owns none of that work. It builds the basin, wires the four things that do
## (angler, net, yard, ferry) to each other and to the grid, and is the one place the
## meter and the purse move.
##
## Named so the harness can read the numbers that decide how the view behaves —
## `tools/test_lake.gd` checks the zoom against `ZOOM_OUT_PULL` — rather than keeping its
## own copy of them, which is the sort of copy that goes stale without anything failing.
class_name Lake
extends Node2D

## Where the UI's colours, sizes and font are decided. See scripts/style.gd.
const Style := preload("res://scripts/style.gd")

## Master palette colors. See scripts/palette.gd and resources/palette.tres.
const Palette := preload("res://scripts/palette.gd")
const DogArt := preload("res://scripts/dog_art.gd")


## The lake is laid out from this, once, at load. Same seed, same lake, every run — which
## is what makes a tuning pass a comparison rather than a new roll of the dice.
const LAKE_SEED := 20260817


## How far back the view sits to begin with. Isometric, so the basin is twice as wide as
## it is tall on screen.
const VIEW_ZOOM := 0.62

## How far in and out the wheel may take the view. The lake is far bigger than one screen
## at a readable zoom, so the two ends are doing different jobs: zoomed in is where the
## player aims a cast, zoomed out is where they read the basin as a whole and decide which
## side of the island to walk to.
## Zoomed in is a hard number; zoomed out is the whole lake and not one pixel further.
##
## It used to be a hard number too, at 0.22, and that let the player pull back until the
## basin was a green stain in the middle of a screen of grass — nothing to read and nothing
## to decide. The far end is now whatever zoom fits the waterline inside the window, worked
## out from the basin and the window rather than written down, so it frames the same lake on
## any screen. MIN_ZOOM stays as the floor under that, for a window too small to fit it.
const MIN_ZOOM := 0.22
const MAX_ZOOM := 1.8

## How much room is left round the lake at that far end, as a fraction of the basin. A
## shoreline drawn hard against the edge of the window reads as cropped.
const ZOOM_FIT_MARGIN := 0.04

## How much bank the far end of the zoom shows past the waterline, in tiles.
##
## The lake and the four piers on it, and nothing else worth pulling back for. A pier stands
## `Dropoff.PIER_OUT` past the waterline and is most of a hundred pixels wide from there, so
## this is that plus enough air to keep it off the edge of the window.
##
## It has been further out. Thirteen tiles showed the wood behind the bank, which sounded
## like more of the place and read as a lake going away from you — the boats got small, the
## piers got small, and the thing the player is actually doing sat in the middle of a lot of
## scenery.
const ZOOM_OUT_TILES := 4.0

## And then held in by this much again: the far end of the wheel is this multiple of the zoom
## that would fit the lake and its piers exactly.
##
## Over one, so the view stops before the whole basin is on screen. The lake is bigger than a
## window at any size worth reading it at, and a zoom that fits all of it is a zoom at which
## a bottle is three pixels — the whole-lake view is a map, and this is a game about looking
## at the water in front of you.
const ZOOM_OUT_PULL := 1.68

## And the same for the drag: the view may be pushed this fraction of the way out to where
## the ground runs out, rather than all of it.
##
## The far corners of the ground are wood and nothing else — no lake, no piers, nothing to
## do — so a drag that reaches them is a drag that takes the player away from the game and
## makes them come back.
const DRAG_PULL := 1.5

## What is behind everything, where there is no ground drawn: the `Sky` layer's fill, which
## sits under the whole scene and used to be a flat grey.
##
## Woodland, so the far distance past the last of the trees is more of the same rather than
## the inside of a window. That is what makes the edge of the ground a non-question, at any
## zoom and any shape of window, for nothing.
##
## Chasing it with more ground does not work. The view at the far end of the zoom is wider
## than any ring worth drawing — the tall test window alone wants ground half again as far
## out as the trees ever reach — so the ring grows, and the props with it, and the edge is
## still one drag away.
const BEYOND := Color(0.16, 0.22, 0.14)
## Per wheel notch. The wheel moves one zoom level per notch whatever this is; it only says
## which way (and `_zoom_by` lets a bigger factor jump further).
const ZOOM_STEP := 1.12

## World pixels to one pixel of the art — the ground pack's `Ground.SCALE`, and what the
## rubbish, finds and pigeons are drawn at.
##
## Zoom is held to levels where one of these covers a whole number of real screen pixels,
## worked out through the window's stretch (see `_zoom_level`), and the drawn camera position
## is snapped to whole screen pixels (`_snap_camera`). Between them the art and the water's
## pixel grid land on the same screen pixels every frame, so panning and zooming do not make
## them shimmer. Free zoom put a two-pixel cell at 2.8 screen pixels, drawn as two or three
## depending on where the camera happened to be.
##
## It is why there is no lean-in on a cast any more: the gentlest step between levels is a
## third, far past the thirteen per cent the cast used to push.
const ART_PIXEL := 2.0

## How far the view slides off the angler and onto the net while a cast is out, and how
## quickly it takes up and gives back that slack.
##
## Not all the way onto it. The angler is the thing being played and wants to stay on
## screen; sitting between the two of them is what makes a long cast read as a throw across
## the water rather than as the lake sliding sideways. It needs no ending of its own —
## reeling brings the net home to the angler, so the two points converge and the view
## arrives back where it started at the moment the haul finishes.
const CAST_LOOK := 0.45
const LOOK_SPEED := 3.4

## How far the middle button may move while held and still count as a tap rather than a
## drag, in screen pixels. A tap recentres the view on the angler.
const PAN_TAP := 4.0

## How quickly a cast takes the view back, as a fraction of the offset a second. Throwing
## the net is asking to watch it, so the pan is handed back and the cast's own follow takes
## over — out to the net, and home with it. Eased rather than dropped: a view that jumps the
## moment you click has thrown the player somewhere rather than taken them there.
const PAN_RELEASE := 3.2

## How the meter's reading is bent before the water is painted with it. Under one, so the
## lake stays dirty-looking well past halfway: at fifty per cent cleared it still paints at
## about sixty-five.
##
## Only the water. The meter itself goes on reading what is actually left, because a progress
## bar that flatters itself is a progress bar nobody believes twice.
const FILTH_BITE := 0.62

## How far the stain round a floating piece reaches, in tiles, and how it falls off.
##
## The map is a distance map from the rubbish: a tile with a piece on it is foul, and the
## water round it is stained by how near it is to the nearest piece, down to clean at
## FILTH_BLUR tiles out. Nothing else goes into it — not the piece's pollution value, not
## the tile's capacity, not an average. It used to be an average (each tile's pollution
## over its capacity, box-blurred three tiles): a lone piece over deep water averaged down
## to near nothing and floated on blue, while the blur carried a full tile's green two
## tiles out over empty water. Both are lies about where the junk is, and the water's
## whole job is to say where the junk is.
##
## FILTH_FALL bends the falloff. Under one holds the stain up near the piece and drops it
## late: at 0.6 the tile next to a piece still reads foul, two out reads murky, three clean.
const FILTH_BLUR := 3
const FILTH_FALL := 0.6

## Seconds between rebuilds of the map, at most. It is a moment of work on a grid this size
## and none of it has to be frame-exact, but a cast landing ten pieces should not pay for it
## ten times.
const FILTH_REMAP := 0.2



## Below this zoom the rubbish drops its footprint and its outline. A piece is about
## twenty pixels across, so under half zoom those two details are a pixel wide and cost
## half the geometry on screen for nothing.
const DETAIL_ZOOM := 0.5

## What netting a pigeon pays, and what a piece pays at a merchant — a flat fee for
## anything landed, plus what its filth is worth. Lives in resources/economy.tres (see
## `EconomyConfig`) now, loaded into `_economy` by `_load_upgrades()`.
var _economy: EconomyConfig

## How close to the shed the angler has to stand to open it, in tiles.
const SHOP_RANGE := 3.2

## How art is sized when it is floating in the lake.
##
## Everything is drawn at the same scale first, so a wardrobe really is four times a mug
## and the lake reads as a lake full of things rather than a lake full of one size. The two
## limits are only there for the extremes: a four-pixel crumb has to be visible at all, and
## a bed has to leave room for the water around it.
## The window was 15 to 46, which sounded wide and was not: the furniture sheet's middling
## cell is 32 pixels on its longest side, so every cell of 31 or more came out at exactly 46
## and the whole catalogue of beds, wardrobes and sofas drew at one size. Widened to 11-68 —
## six times between the smallest crumb and the biggest bed instead of three. Sixty-eight is
## about a tile wide: the size of the ferry, well under the shed, which is as far as this
## should go before a wardrobe starts eating the tiles either side of it.
##
## Two, not one and a half: two is `ART_PIXEL`, one pixel of the art to one pixel of the ground
## pack, so a piece lands on the same screen pixels as everything else at every zoom level.
## At 1.5 each source pixel was three quarters of one, and thin details dropped out.
const SPRITE_SCALE := 2.0
const SPRITE_SMALLEST := 11.0
const SPRITE_LARGEST := 68.0

## Hulls the lake will hold. Used to read 3, on the theory that three ferries working one
## yard was already more loading than the yard produces — 2026-09 playtest says otherwise
## (see docs/balance/2026-09-06.md): the yard sat thousands deep the whole run. Raised to 5;
## `fleet`'s own `.tres` gates how many of those are actually for sale.
const MAX_BOATS := 5

## What the first skimmer fitted brings up. The track walks from here to a certainty at
## its last level.
const SKIM_FIRST_CHANCE := 0.30

## Per-track price curve, value curve, and level cap now live in `resources/upgrades/*.tres`
## (see `UpgradeTrack`) for every track except `skimmer`, whose payoff is a chance curve
## rather than this price-and-value shape — it keeps its own entry here.
const MAX_LEVELS := {
	&"skimmer": 10,
}

## How loud the music is when it is turned right up, in decibels, and how far down "off"
## is. Silence is a volume rather than a stopped player: a track that keeps running while
## muted comes back where it would have been rather than restarting mid-session.
## The top of the music slider, in decibels. Above unity: the track was mixed quietly and
## the old ceiling of minus six left it under the water at every setting.
const MUSIC_LOUDEST := 4.0

## The song as heard from indoors: the same recording, squeezed into a 190 Hz to 7.2 kHz
## band with a little drive and a slap of room, baked into a second file.
##
## It was a bus with four effects on it, which is the obvious way to do this and works
## everywhere except where the game actually ships: the web export runs the mix but not the
## bus effects, so on itch the shed sounded exactly like the lake. A second track is dumber
## and it is the same in every build.
##
## The band is wide, and deliberately so. The first pass took it down to a
## five-hundred-to-three-thousand band with real overdrive on top, which is what a bad radio
## measures like and not what one should sound like in a game: it swallowed the song. This
## only thins it — the bass goes and the very top goes, and everything that carries the tune
## stays.
const RADIO_TRACK := preload("res://assets/music_goin_radio.mp3")

## How fast the song moves between outdoors and indoors, as a fraction of the way there a
## second: a quarter of a second door. The two recordings run side by side and one is faded
## up as the other goes down, because swapping the stream under a single player and seeking
## to where the other one had reached is a cut, however small the gap, and a cut in the
## middle of a bar is heard as a fault.
const RADIO_FADE := 4.0
const MUSIC_SILENT := -60.0

## How fast the finished lake lights up, as a fraction of the way there a second.
const SPARKLE_RISE := 0.5

## The corner cross on a panel: how big it is and how far in from the corner it sits.
const CLOSE_BOX := 34.0
const CLOSE_INSET := 12.0

## Where a run is kept between sessions, and how often it writes itself there.
##
## The lake itself is not in the file — it is the same lake every time, from LAKE_SEED —
## but what has been taken out of it is, because that is the whole of the progress. The
## save is written on its own timer rather than on every change: a purchase or a sale can
## happen several times a second, and the field is the biggest thing in the file.
const SAVE_PATH := "user://lake_cleanup.save"
## 6: ten rubbish kinds appended to TRASH_ORDER. Saved stacks hold indices into the whole
## def list and the finds follow the rubbish in it, so every find's index moved.
const SAVE_VERSION := 6
const AUTOSAVE_EVERY := 20.0




## Where this run is saved, and whether it picks up where the last one left off. Both are
## settable before the scene enters the tree, which is how the test harness runs against a
## save file of its own instead of the player's.
var save_path: String = SAVE_PATH
var autoload_save: bool = true

## Set by the settings door, and true for exactly one scene load: the level being walked
## into starts from nothing rather than from its own save.
##
## Static because it has to survive the scene change that carries it — the node that sets
## it is gone by the time the node that reads it is built. Cleared as soon as it is read,
## so a level loaded any other way is the saved one again.
static var start_fresh: bool = false

## 0 clean, 1 filthy. The one number the shader, the HUD, and every upgrade agree on.
var pollution: float = 1.0

## Currency, earned by selling at the merchants on the bank.
var sludge: float = 0.0

## Upgrade levels for the net. Five axes, one per thing a cast is: how wide it sweeps, how
## heavy a piece it lifts, how far it throws, how fast it comes back, how much it holds.
var net_width_level: int = 0
var net_strength_level: int = 0
var net_range_level: int = 0
var reel_level: int = 0
var net_hold_level: int = 0

## The yard on the island.

## The ferry. There from the first minute: catching does not pay, only selling does, so a
## player without a boat has no way to earn the upgrades that would buy one. It starts
## slow and small instead, and is upgraded along the three axes a run has — and a fourth,
## the skimmer, which is off until it is bought.
var boat_speed_level: int = 0
var cargo_level: int = 0
var skimmer_level: int = 0

## Hulls bought on top of the one the player starts with, up to MAX_BOATS in the water. A
## second ferry is the only upgrade that buys a whole extra round of the lake at once, so
## it is priced well above anything that only makes the first one better.
var fleet_level: int = 0

## The dog. Two tracks of training: how many pieces it brings back in one trip out, and how
## much comes off the longest it will laze about between trips. Neither raises what it is
## able to pick up — heavy and wide junk stays the net's and the skimmer's business.
var dog_fetch_level: int = 0
var dog_wait_level: int = 0

## Pieces landed on the island, ever, and pieces sold. Two numbers because they are two
## different achievements now.
var caught: int = 0
var sold_count: int = 0

## How much each merchant has taken, in TrashDef.Kind order. The four yards are only
## interesting if the player can see that they are being used unevenly.
var sold_by_kind := PackedInt32Array([0, 0, 0, 0])

## The pigeons. They perch on floating rubbish, so the flock is a reading of how dirty the
## water in front of the player is — and a perched one is worth netting.
var _flock: Flock

## How many birds have been netted, and what one is worth. A bird pays about as much as a
## good piece of scrap, and pays on the spot rather than waiting on a ferry run.
var birds_caught: int = 0

## The art, cut from the sheets in assets/ and welded into one atlas. Null-safe: with no
## art the lake draws the blocked-in placeholders it was prototyped on.
var _sheets: Sheets

## Furniture found in the lake, by piece name, in the order it was pulled out. One of each
## exists and it is never sold — it goes in the shed.
##
## An Array rather than a PackedStringArray on purpose: the room is handed this list and
## edits alongside it, and a packed array would hand it a copy that stops agreeing with
## this one the moment either side changes.
var unlocked: Array[String] = []

## What the player has put where, as `{piece, cell}` rows. Owned here rather than by the
## room so it saves with everything else.
var decor: Array = []

var _grid: LakeGrid
## The zoom the player set with the wheel, and how far a cast in progress is leaning on top
## of it. The camera's own zoom is the two multiplied together and is written every frame,
## so neither can be read back as the authority for the other.
var _view_zoom: float = VIEW_ZOOM
## How far the view has slid from the angler towards the net, 0 to 1.
var _cast_look: float = 0.0

## Where the player has dragged the view to with the middle button, as an offset in world
## units from wherever the camera would otherwise be. It stays where it is put: a view that
## crept back to the angler on its own would be a view you cannot use to look at anything.
var _pan := Vector2.ZERO
## Whether the middle button is down, and how far it has been moved since it went down. A
## press that goes nowhere is a request to look at the angler again rather than a drag.
var _panning: bool = false
var _pan_moved: float = 0.0
## Set when a cast or a step asks for the view back, cleared when the player takes it again.
## Without it the giving-back stops the moment the net lands, which on a short cast leaves
## the view sitting a little off the angler forever.
var _pan_yielded: bool = false
## Where the angler was last frame, for noticing that they have started walking.
var _angler_was := Vector2.INF

## The hut on the island, cut out of the shed button. Null-safe: with no picture the lake
## falls back to the blocked-in one it drew before.
var _shed_art: Texture2D

## The grass growing round the hut's walls, baked the first time it is drawn. Static, by
## decision — no sway — so one bake lasts the run.
var _shed_skirt: Skirt.Patch

var _splash: WaterSplash
var _prints: Footprints
var _sfx: Sfx

## The indoors half of the music: the same song through a wall, on its own player. Both
## players run from the same moment for the whole session, so what the crossfade moves
## between is two copies of the same bar rather than two positions in a song.
var _radio: AudioStreamPlayer

## Whether the song should be the indoors one, and how far it has got there: 0 is the lake,
## 1 is the hut.
var _radio_on: bool = false
var _radio_at: float = 0.0
var _haul: Haul
var _camera: Camera2D
## The fleet, in the order it was bought. The first is the ferry in the scene; the rest
## are built when they are paid for.
var _boats: Array[Boat] = []
var _angler: Angler
var _net: CastNet
var _yard: Yard

## The dog. It fetches, it dozes on the grass, and it can be petted; see scripts/dog.gd.
var _dog: Dog

## The daylight, and the two things it is painted with: one modulate over the whole world
## canvas, and the fill behind it. The HUD, the shop board and the shed room are on canvas
## layers of their own and are deliberately not touched by either — a menu that dims at dusk
## is a menu that is harder to read at dusk, for nothing.
var _day: DayCycle
var _daylight: CanvasModulate
var _water_material: ShaderMaterial

## The island's shed. A drawn node with nothing else to do.
var _island: Node2D

## The four merchants on the bank, held in TrashDef.Kind order so a material index is a
## dropoff index everywhere.
var _dropoffs: Array[Dropoff] = []

## How far the camera may travel, in world pixels. Taken from the lake's own extent so the
## view cannot be panned off into empty space.
var _bounds := Rect2()

var _menu_open: bool = false
var _settings_open: bool = false
var _shed_open: bool = false

## Every purchasable track but `skimmer`, loaded from resources/upgrades/*.tres. Keyed by
## the same StringName used throughout the shop (`&"net_width"`, `&"cargo"`, ...).
const UPGRADE_ORDER := [
	"net_width", "net_strength", "net_range", "reel", "net_hold",
	"boat_speed", "cargo", "fleet",
	"dog_fetch", "dog_wait",
]
var _upgrades: Dictionary = {}

## Seconds until the next autosave, and what the HUD says about the last one.
var _autosave_in: float = AUTOSAVE_EVERY
## True once the save has been thrown away, so the reload on the way out does not put it
## straight back.
var _wiping: bool = false
var _save_note: String = ""
var _save_note_for: float = 0.0

## The per-tile filth map handed to the water shader, and its texture. Rebuilt on a timer
## whenever something has come out of the water.
var _filth_map: Image
var _filth_texture: ImageTexture
var _filth_stale: bool = false
var _filth_remap_in: float = 0.0

var _filth_total: float = 1.0
var _filth_left: float = 1.0

## Whether the player has ever been thanked for this lake. Kept for the record and for old
## saves; it does not gate the closing screen any more.
##
## It used to. Showing the words once ever sounds like good manners and was a trap: the way
## on to the second lake is a door on that screen, so a player who cleaned the basin, read
## the words, and came back later found a finished lake with nothing to do on it and no way
## off it. A finished lake now offers its ending whenever it is opened — once per sitting,
## because the run is only finished once — and the door is therefore always there.
##
## The end of the run. `_cleaned` is the lake having nothing left in it, which is what the
## water is lit by; `_farewell_shown` is whether the player has been thanked, which happens
## once per save rather than once per session.
var _cleaned: bool = false
## Seconds until the next "is the lake empty" walk. See _look_for_the_end.
var _clean_check_in: float = 0.0
## What that walk found still floating, once the meter is on the floor. -1 before it has
## been asked. This is the difference between a lake that is finished and one that is only
## finished to two decimal places, and the player cannot see it without being told.
var _left_over: int = -1
## The card that holds a new find up. Built once and kept: it shows one find at a time and
## queues the rest, so it has to outlive any one of them.
var _trophy: Trophy

## The pigeon pop-up, and the roll that decides whether a catch gets one. A half: often enough
## to be part of what netting a bird is, rare enough that it is not a receipt.
var _pigeon: PigeonPop
const POP_ODDS := 0.5
var _pop_rng := RandomNumberGenerator.new()

var _farewell_shown: bool = false
var _farewell: Farewell
## How far the sparkle has come up, 0 to 1. Eased rather than switched so the lake brightens
## over a couple of seconds — the last piece is lifted and the water answers.
var _sparkle_at: float = 0.0

@onready var _shop: PanelContainer = %Shop
@onready var _close_menu: Button = %CloseMenu
@onready var _skin: HudSkin = %Skin
@onready var _shop_skin: ShopSkin = %ShopSkin
@onready var _buy_net_width: Button = %BuyNetWidth
@onready var _buy_net_strength: Button = %BuyNetStrength
@onready var _buy_net_range: Button = %BuyNetRange
@onready var _buy_reel: Button = %BuyReel
@onready var _buy_net_hold: Button = %BuyNetHold
@onready var _buy_boat_speed: Button = %BuyBoatSpeed
@onready var _buy_cargo: Button = %BuyCargo
@onready var _buy_skimmer: Button = %BuySkimmer
@onready var _buy_fleet: Button = %BuyFleet
@onready var _shed: PanelContainer = %Shed
@onready var _room: ShedRoom = %Room
@onready var _open_shed: Button = %OpenShed
@onready var _open_upgrades: UiButton = %OpenUpgrades
@onready var _settings: SettingsSkin = %Settings
@onready var _open_settings: PlankButton = %OpenSettings
@onready var _music: AudioStreamPlayer = %Music
@onready var _send_now: Button = %SendNow
@onready var _auto_ferry: CheckButton = %AutoFerry


## Loads every track's price and value curve from resources/upgrades/*.tres, and what
## selling pays from resources/economy.tres. Called once from _ready — a balance pass
## edits those files, not this function.
func _load_upgrades() -> void:
	for id in UPGRADE_ORDER:
		var path := "res://resources/upgrades/%s.tres" % id
		var res: Resource = load(path)
		if res == null:
			push_error("Lake: missing %s" % path)
			continue
		_upgrades[StringName(id)] = res
	_economy = load("res://resources/economy.tres") as EconomyConfig
	if _economy == null:
		push_error("Lake: missing res://resources/economy.tres")
		_economy = EconomyConfig.new()


## How far out from its own tile a cast sweeps, in tiles. Level 0 is a single tile: the net
## you start with catches exactly what you drag it over, and everything wider than that is
## bought.
##
## Fractions rather than whole rings. A radius counted in whole tiles goes 1, 5, 13, 29
## tiles a cast — every purchase doubles the mouth and by the third one the net is a
## dragnet.
##
## The step starts small and grows: the first couple of levels are a slightly bigger mouth
## rather than a new net, so the early game is still a game of aiming, and the levels bought
## late are the ones that feel like money well spent. Numbers live in
## resources/upgrades/net_width.tres.
func net_radius() -> float:
	return _upgrades[&"net_width"].value(net_width_level)


## The heaviest TrashDef.tier the net can lift. resources/upgrades/net_strength.tres.
func net_power() -> int:
	return int(_upgrades[&"net_strength"].value(net_strength_level))


## How far the angler can throw, in tiles.
##
## Starts short on purpose — the rod once reached a third of the way across the basin at
## the first upgrade, which made the boat pointless and the lake small — but it accelerates,
## because a track whose price multiplies while its reach only adds is a track that is worth
## less every time you buy it. The squared term is what keeps the late levels worth the
## money. Numbers live in resources/upgrades/net_range.tres.
func net_range() -> float:
	return _upgrades[&"net_range"].value(net_range_level)


## How fast the net comes home, in tiles per second. resources/upgrades/reel.tres.
func reel_speed() -> float:
	return _upgrades[&"reel"].value(reel_level)


## How many pieces one cast can bring in. resources/upgrades/net_hold.tres.
func net_hold() -> int:
	return int(_upgrades[&"net_hold"].value(net_hold_level))


## Ferry speed, in tiles per second. resources/upgrades/boat_speed.tres.
func boat_speed() -> float:
	return _upgrades[&"boat_speed"].value(boat_speed_level)


## resources/upgrades/cargo.tres.
func boat_cargo() -> int:
	return int(_upgrades[&"cargo"].value(cargo_level))


## How many pieces one trip out may bring back. resources/upgrades/dog_fetch.tres.
func dog_fetch() -> int:
	return int(_upgrades[&"dog_fetch"].value(dog_fetch_level))


## Seconds off the top of the dog's wait between trips, so the longest it will laze about
## comes down and the shortest does not. resources/upgrades/dog_wait.tres, and see
## Dog.MOOD_MOST for what it is taken off.
func dog_wait_cut() -> float:
	return _upgrades[&"dog_wait"].value(dog_wait_level)


## How wide the skimmer bites as it sails, in tiles out from the hull. Below zero is no
## skimmer fitted, which is what every ferry starts as.
func skim_radius() -> int:
	return _skim_level() - 1


## The heaviest tier the skimmer can lift. Deliberately behind the net: the boat catching
## what the player cannot yet catch by hand would read as the game playing itself.
func skim_power() -> int:
	return maxi(_skim_level() - 1, 0) / 2


## Odds that a piece the skimmer passes over actually comes up. A net dragged behind a
## moving hull is a chance at a piece rather than a certainty, and most of what the
## skimmer upgrade buys is that chance going up — the first one fitted still misses most of
## what it passes, and even a maxed one lets some slip underneath.
func skim_chance() -> float:
	var level := _skim_level()
	if level < 1:
		return 0.0
	var top := float(MAX_LEVELS[&"skimmer"])
	return clampf(lerpf(SKIM_FIRST_CHANCE, 1.0, float(level - 1) / (top - 1.0)), 0.0, 1.0)


## Deck space the skimmer gets on top of the hold, so a ferry loaded to the brim out of
## the yard can still fish on the way.
func skim_hold() -> int:
	return _skim_level()


## How many slots down the skimmer digs for the material it is running out. More than one,
## always: it is looking for one material in particular, and on the way to the sawmill most
## of what is floating on top is not timber.
func skim_depth() -> int:
	return 1 + _skim_level()


## The level the skimmer numbers are read at: what was bought, held to the top of the
## track, so a save written before the cap cannot run a skimmer past the end of it.
func _skim_level() -> int:
	return mini(skimmer_level, MAX_LEVELS[&"skimmer"])


func _ready() -> void:
	($Sky/Fill as ColorRect).color = BEYOND
	_day = %Day as DayCycle
	_daylight = %Daylight as CanvasModulate
	_pop_rng.randomize()
	_load_upgrades()
	_grid = $Grid as LakeGrid
	_camera = $Camera as Camera2D
	_boats = [$Boat as Boat]
	_angler = $Angler as Angler
	_net = $Net as CastNet
	_yard = $Yard as Yard
	_dog = $Dog as Dog

	var shore := Iso.shore_outline()
	_shape_bank()
	_shape_water(shore)
	_shape_island()
	_shape_dropoffs()
	_tune_ground()

	_shed_art = Art.texture(SHED_ART)

	_sfx = Sfx.new()
	_sfx.name = &"Sfx"
	add_child(_sfx)

	# Over the island and the shed: the catch is thrown across them, not through them.
	_haul = Haul.new()
	_haul.name = &"Haul"
	_haul.z_index = 8
	_haul.z_as_relative = false
	_haul.grid = _grid
	_haul.sfx = _sfx
	_haul.arrived.connect(_on_haul_arrived)
	add_child(_haul)

	_splash = WaterSplash.new()
	_splash.name = &"Splash"
	# Just under the floating rubbish (z 5), every splash alike. Drawn over it, a catch's
	# crown and specks covered the pieces around the net; the splash is the water moving,
	# and anything floating in that water is in front of it.
	_splash.z_index = 4
	_splash.z_as_relative = false
	add_child(_splash)

	_prints = Footprints.new()
	_prints.name = &"Footprints"
	# Over the ground, under whoever is walking on it.
	_prints.z_index = 4
	_prints.z_as_relative = false
	add_child(_prints)

	_grid.z_index = 5
	_grid.z_as_relative = false
	# The rubbish bobs on the GPU. That is what lets its geometry be built once and left
	# alone until the view moves or a piece is taken, instead of every frame.
	var bob := ShaderMaterial.new()
	bob.shader = load("res://shaders/rubbish.gdshader")
	bob.set_shader_parameter(&"wave_amplitude", LakeGrid.WAVE_AMPLITUDE)
	bob.set_shader_parameter(&"wave_speed", LakeGrid.WAVE_SPEED)
	_grid.material = bob
	_sheets = Sheets.new()
	if not _sheets.load_all():
		_sheets = null
	_grid.sheets = _sheets
	_grid.build(_all_defs(), _level_seed(), _fills_the_lake())
	_hide_treasures()
	_filth_total = maxf(_grid.filth_left(), 0.001)
	_filth_left = _filth_total
	pollution = 1.0
	_build_filth_map()

	_build_trophy()
	_build_pigeon_pop()

	_bounds = _outline_bounds(shore)
	_view_zoom = VIEW_ZOOM
	_push_zoom()
	_camera.position = Iso.tile_to_world(Iso.CENTRE.x, Iso.CENTRE.y)

	# The yard sits beside the shed, far enough off it that the pile does not grow through
	# the roof.
	_yard.grid = _grid
	# The dog needs the water to fish out of, somebody to be pleased to see, and the crate
	# to put things in. What happens to what it brings back is the lake's business, not the
	# dog's, so it hands the piece over and forgets about it.
	_dog.grid = _grid
	_dog.angler = _angler
	_angler.day = _day
	_dog.day = _day
	_dog.fetched.connect(_dog_brought_back)
	_push_dog_numbers()
	_dog.petted.connect(func() -> void:
		if _sfx != null:
			_sfx.play_bought()
	)
	# Clear of the shed and clear of where the angler stands: a crate you spawn inside is a
	# crate you have to walk out of before you can see it.
	# One layer over the walker band that means "past the hut, short of the crate", so
	# somebody standing north of the crate is drawn behind it. See `_sort_walkers`.
	_yard.day = _day
	_yard.z_index = CRATE_LAYER
	_yard.position = Iso.tile_to_world(
		Iso.ISLAND_CENTRE.x + 2.7, Iso.ISLAND_CENTRE.y + 2.7
	)
	# Told after the crate has been put somewhere, not before: the dog walks to this, and a
	# crate whose position is still the origin sends it to the top left corner of the world
	# to drop things in the water.
	_dog.crate_tile = Vector2(Iso.ISLAND_CENTRE.x + 2.7, Iso.ISLAND_CENTRE.y + 2.7)
	# The angler is told as well, but for the opposite reason: the dog walks to the crate and
	# the player walks round it.
	_angler.crate_tile = _dog.crate_tile

	# The flock sits between the floating rubbish and the splashes: birds are on the water,
	# and a splash is on top of everything.
	_flock = Flock.new()
	_flock.name = &"Flock"
	_flock.z_index = 6
	_flock.z_as_relative = false
	_flock.grid = _grid
	_flock.angler = _angler
	_flock.sfx = _sfx
	add_child(_flock)

	_net.grid = _grid
	_net.splash = _splash
	_angler.splash = _splash
	_dog.splash = _splash
	_angler.prints = _prints
	_dog.prints = _prints
	_net.sfx = _sfx
	_net.angler = _angler
	_net.flock = _flock
	_net.landed.connect(_on_net_landed)
	_net.caught.connect(_on_net_caught)
	_net.caught_bird.connect(_on_bird_caught)

	# The ferry lives on the island's south side and works its way round the bank from
	# there, calling at whichever merchants its load is for.
	_fit_out(_boats[0], 0)
	_push_net_numbers()
	_push_boat_numbers()

	_buy_net_width.pressed.connect(_buy.bind(&"net_width"))
	_buy_net_strength.pressed.connect(_buy.bind(&"net_strength"))
	_buy_net_range.pressed.connect(_buy.bind(&"net_range"))
	_buy_reel.pressed.connect(_buy.bind(&"reel"))
	_buy_net_hold.pressed.connect(_buy.bind(&"net_hold"))
	_buy_boat_speed.pressed.connect(_buy.bind(&"boat_speed"))
	_buy_cargo.pressed.connect(_buy.bind(&"cargo"))
	_buy_skimmer.pressed.connect(_buy.bind(&"skimmer"))
	_buy_fleet.pressed.connect(_buy.bind(&"fleet"))
	_room.sheets = _sheets
	_room.unlocked = unlocked
	_room.decor = decor
	# The room shows the finds by the names the defs give them rather than by their
	# catalogue keys: "furniture_07" is not something anybody pulled out of a lake.
	for def: TrashDef in _grid.defs:
		if def.keepsake and not def.display_name.is_empty():
			_room.titles[String(def.piece)] = def.display_name
	_shop_skin.bought.connect(_buy)
	# The picture at the head of the net and ferry boards: the ferry's own baked hull and
	# the net laid out. The dog's board draws the dog itself.
	# The hull at a fixed turn of the circle, with what the board needs to lay the same wake
	# under it that the lake does: the heading that frame faces, where the water meets the
	# hull in the picture (`anchor`, from art_frame), and the wake's own size — all in the
	# picture's pixels, so the board scales them with it.
	# Frame 14 of 16: bow towards the camera and to the right, the big sail full on.
	var turn := 0.88
	var ferry := Boat.art_frame(turn)
	if not ferry.is_empty():
		var frame := (ferry["region"] as Rect2).size.y
		var to_frame := Boat.HULL_IN_FRAME / Boat.HULL_LENGTH
		ferry["heading"] = Boat.turn_heading(turn)
		ferry["half_length"] = Boat.HULL_LENGTH * 0.5 * to_frame
		ferry["half_width"] = Boat.HULL_WIDTH * 0.5 * to_frame
		ferry["frame"] = frame
		_shop_skin.sprites[&"boat"] = ferry
	var mesh: Dictionary = _net.art_frame(&"land", -1)
	if not mesh.is_empty() and _net.art_sheet() != null:
		_shop_skin.sprites[&"net"] = {"sheet": _net.art_sheet(), "region": mesh["region"]}
	# A few pieces of rubbish for the net to lie over, off the lake's own atlas.
	if _sheets != null and _sheets.atlas != null:
		var catch: Array = []
		for slug in ["metal_can1", "plastic_cup1", "rubber_duck"]:
			if _sheets.has(StringName(slug)):
				catch.append({"sheet": _sheets.atlas, "region": _sheets.region_of(StringName(slug))})
		_shop_skin.sprites[&"catch"] = catch
	_lend_button_art(ferry, mesh)
	_skin.shed_pressed.connect(_set_shed.bind(true))
	_skin.upgrades_pressed.connect(_set_menu.bind(true))
	_open_upgrades.pressed.connect(_set_menu.bind(true))
	_open_shed.pressed.connect(_set_shed.bind(true))
	_room.close_asked.connect(_set_shed.bind(false))
	_open_settings.pressed.connect(_set_settings.bind(true))
	# Last of the HUD's children, so it lies over the shed rather than under it. The shed
	# fills the screen now, and a settings panel drawn beneath that is a settings panel
	# nobody can see or press.
	_settings.get_parent().move_child(_settings, -1)
	_settings.get_parent().move_child(_open_settings, -1)
	_settings.fullscreen_toggled.connect(_set_fullscreen)
	_settings.music_toggled.connect(_set_music)
	_settings.music_level_changed.connect(_set_music_level)
	_settings.sfx_toggled.connect(_set_sfx)
	_settings.sfx_level_changed.connect(_set_sfx_level)
	_push_sfx()
	_settings.quit_pressed.connect(_quit)
	_settings.wipe_pressed.connect(wipe_save)
	_settings.swap_label = _other_level_name()
	_settings.swap_pressed.connect(_swap_levels)
	_settings.close_asked.connect(_set_settings.bind(false))
	_send_now.pressed.connect(_send_ferry)
	_auto_ferry.toggled.connect(_set_auto_ferry)
	_close_menu.pressed.connect(_set_menu.bind(false))
	_shop_skin.close_asked.connect(_set_menu.bind(false))
	# Not the shed. It has no panel to hang a cross on the corner of any more — the room is
	# the whole screen — so its own cross sits over the top of the inventory column, where
	# the thing it closes actually is. See ShedRoom.
	_polish_panel_controls()
	_set_menu(false)
	_settings.fullscreen = _is_fullscreen()
	_start_music()
	_set_settings(false)
	_set_shed(false)
	_push_water_colours()
	if autoload_save and not start_fresh:
		load_game()
	start_fresh = false
	_seed_starter_bed()


## What the corner buttons draw (`hud_buttons.gd`): the net and ferry the shop was lent,
## the hut, and a fixed row of finds off the clean sheet for the shed to stand in front of.
## Handed to the HUD and to the shed's copy of the upgrades button alike, so they are one
## button. Whatever is missing is left out, and the button draws without it.
## Tall pieces first — they make the back row — then the low ones for the row in front.
const BUTTON_DECOR := [
	&"decor_bookcase_tall", &"decor_fridge", &"decor_old_clock", &"decor_mirror",
	&"decor_coat_hanger", &"decor_standing_lamp", &"decor_stove", &"decor_kitchen_counter",
	&"decor_sofa", &"decor_dresser", &"decor_nightstand", &"decor_vynil_player",
	&"decor_center_table", &"decor_lamp", &"decor_pet_bed", &"decor_flower_pot",
]


func _lend_button_art(ferry: Dictionary, mesh: Dictionary) -> void:
	var lent := {}
	if not ferry.is_empty():
		lent["boat"] = ferry
	if not mesh.is_empty() and _net.art_sheet() != null:
		lent["net"] = {"sheet": _net.art_sheet(), "region": mesh["region"]}
	if _shed_art != null:
		lent["shed"] = _shed_art
	if _sheets != null and _sheets.atlas != null:
		var decor: Array = []
		for slug: StringName in BUTTON_DECOR:
			if _sheets.has(slug):
				decor.append({"sheet": _sheets.atlas, "region": _sheets.view_region_of(slug, 0)})
		lent["decor"] = decor
	_skin.sprites = lent
	UiButton.sprites = lent


## The bank: the land the lake sits in, drawn as the shore ring grown outward. Two flat
## shapes, not a heightmap — nothing walks on it and nothing is hidden behind it.
## The seams a second level hangs off.
##
## Level two is a scene that inherits this one and a script that extends this file, so the
## HUD, the shop, the shed, the ferry and the net all come across without being copied.
## What follows is the whole of what it is allowed to change: what the field is built from,
## what happens when the field is empty, what goes in the save, and what the keyboard does
## first. Each one has the level-one answer as its body, so this file on its own behaves
## exactly as it did before they existed.

## Which lake this is. The seed is in the save and checked on load, so a save from one
## level can never be read into the other.
func _level_seed() -> int:
	return LAKE_SEED


## Does this lake start with rubbish floating on it? The first one is the rubbish; the
## second one is what its yards make and nothing else.
func _fills_the_lake() -> bool:
	return true


## What this level is called, for the save file and nothing else.
func level_name() -> String:
	return "lake"


## The last piece has come out of the water. Level one calls that an ending.
func _on_lake_cleaned() -> void:
	_farewell_shown = true
	_show_farewell()


## Anything the level wants kept, added to the dictionary on its way to disk.
func _save_extra(_save: Dictionary) -> void:
	pass


## And read back out of it. Called after everything common has been applied.
func _load_extra(_save: Dictionary) -> void:
	pass


## First refusal on a key or a click. True means the level dealt with it.
func _extra_input(_event: InputEvent) -> bool:
	return false


## The land the lake sits in: the bank around the waterline and the wide ring of ground
## past it, both drawn from pixel-art tiles. See scripts/ground.gd, which decides what goes
## where from the same basin shape the water shader reads.
##
## It used to be three flat polygons with a few thousand hand-thrown specks over them. The
## specks were there to make smooth fills read as ground next to pixel-art rubbish; tiles
## are ground, so the specks went with the fills.
func _shape_bank() -> void:
	var ground := Ground.new()
	ground.name = &"Ground"
	ground.layer = Ground.Layer.OUTSIDE
	ground.day = _day
	add_child(ground)
	_grounds.append(ground)

	if OS.is_debug_build() and OS.get_environment("BENCH_OFF").contains("ground"):
		ground.visible = false


## Both layers of ground, for the tuner.
var _grounds: Array[Ground] = []


## The ground's sliders, F4, debug builds only. See GroundTuner.
func _tune_ground() -> void:
	if not OS.is_debug_build():
		return
	var tuner := GroundTuner.new()
	tuner.name = &"GroundTuner"
	tuner.grounds = _grounds
	tuner.water = _water_material
	add_child(tuner)

## How far the drawn water is carried past the waterline, in tiles — about sixteen screen
## pixels, which is a tile's worth of wet sand.
##
## Drawing only. Nothing in Iso moves, so the angler walks where they always did and the
## rubbish floats where it always did; the water is simply painted a little way up the beach
## instead of stopping on the tile edge under it. Mirrored by `shore_lap` in the shader,
## which has to agree or the paint and its polygon part company.
const SHORE_LAP := 0.45

## The island's coast laps: how far up its beach the drawn water runs at the crest of a wave,
## in tiles, how many waves go round the island, and how fast they travel.
##
## Drawing only, like SHORE_LAP — but unlike SHORE_LAP this one is *not* mirrored into Iso, by
## decision. It cannot be: Iso is static, and a wave in it would dry and wet the ground under a
## walker several times a second. The wave only ever runs one way instead (see `coast_wave` in
## water.gdshader), so the paint covers sand the code calls dry and never uncovers water the
## code calls wet. The angler and the dog walk exactly where they always did.
##
## Held well under `Ground.BEACH_IN` (2.6), the island's beach: a lap that reaches the lawn is
## a flood, not a wave. `test_lake` guards both ends.
##
## Found on the F4 sliders and baked 2026-09-12, up from a first guess of 0.18 / 3 / 0.35.
const COAST_WAVE := 0.32
const COAST_WAVES := 3.0
const COAST_WAVE_SPEED := 0.75

## How far past the waterline the water polygon is actually drawn, in tiles: the lap, the
## wave's crest, and slack enough that the crest is never clipped by the rim.
##
## The bank's edge is carved by the shader's discard now, not by this rim, so the rim only has
## to stay out of the way. The slack is not decoration: `Iso.shore_outline` adds its grow to the
## wobbled radius in tiles, while the shader's `shore_fraction` folds `shore_lap` into the radius
## *before* the wobble multiplies it, so at the basin's widest lobe the discard's crest reaches
## about 1.25 times the wave plus a fifteenth of a tile further out than a plain
## SHORE_LAP + COAST_WAVE ring does. Doubling the wave and adding a tenth clears that for any
## COAST_WAVE, and the surplus is fragments that discard. `test_lake` walks the ring and checks
## it, rather than trusting this arithmetic.
const WATER_RIM := SHORE_LAP + COAST_WAVE * 2.0 + 0.1

## The palette swatches water.gdshader draws with, under the same names on both sides.
const WATER_SWATCHES: Array[StringName] = [
	&"water_clean_deep", &"water_clean_mid", &"water_clean", &"water_clean_shallow",
	&"water_clean_light", &"water_dirty_deep", &"water_dirty_mid", &"water_dirty",
	&"water_dirty_shallow", &"water_dirty_light", &"water_murky_deep", &"water_murky_mid",
	&"water_murky", &"water_murky_shallow", &"water_murky_light",
]


func _shape_water(_shore: PackedVector2Array) -> void:
	var visual := Polygon2D.new()
	visual.name = &"WaterVisual"
	visual.polygon = Iso.shore_outline(WATER_RIM)
	visual.z_index = 2
	visual.z_as_relative = false
	_water_material = ShaderMaterial.new()
	_water_material.shader = load("res://shaders/water.gdshader")
	_water_material.set_shader_parameter(&"tile_w", Iso.TILE_W)
	_water_material.set_shader_parameter(&"tile_h", Iso.TILE_H)
	_water_material.set_shader_parameter(&"basin_centre", Iso.CENTRE)
	_water_material.set_shader_parameter(&"basin_radius", Iso.RADIUS)
	_water_material.set_shader_parameter(&"island_centre", Iso.ISLAND_CENTRE)
	_water_material.set_shader_parameter(&"island_radius", Iso.ISLAND_RADIUS)
	_water_material.set_shader_parameter(&"shore_lap", SHORE_LAP)
	_water_material.set_shader_parameter(&"coast_wave", COAST_WAVE)
	_water_material.set_shader_parameter(&"coast_waves", COAST_WAVES)
	_water_material.set_shader_parameter(&"coast_wave_speed", COAST_WAVE_SPEED)

	# The water's ramps from the master palette. The shader's own defaults are the same values,
	# so a missing palette file still draws the right water.
	var palette := Palette.master()
	if palette != null:
		for swatch: StringName in WATER_SWATCHES:
			_water_material.set_shader_parameter(swatch, palette.get(swatch))
		var foam := palette.foam
		foam.a = 0.75
		_water_material.set_shader_parameter(&"foam_color", foam)
		_water_material.set_shader_parameter(&"foam_dirty", palette.foam_dirty)

	visual.material = _water_material
	add_child(visual)


## The layers the angler and the dog are put on, and the two things they can stand behind.
##
## Five numbers rather than the two the game had, because sorting by hand needs somewhere to
## put a walker between the hut and the crate — see `_sort_walkers`. Everything else on the
## island is under all of these: the water is 2, the sand and its scatter 3.
const BEHIND_SHED := 5

## How far past the hut's front line something has to stand before it counts as behind it,
## in world pixels.
##
## Walking up against the front wall put the angler's feet within a pixel of that line, and
## the flip that followed swallowed the top of the hat into the hut while the boots were
## still out on the grass. The walking rule already keeps anyone out of the footprint, so
## this slack costs nothing: nobody can stand in the strip it gives away.
const SHED_BEHIND_SLACK := 6.0
const SHED_LAYER := 6
const BEHIND_CRATE := 7
const CRATE_LAYER := 8
const IN_FRONT := 9


## The island: its beach and grass, tiled the same way the bank is, and the shed the
## upgrades are bought in.
##
## Drawn over the water polygon rather than cut out of it, because the water's outline is
## one generated ring and putting a hole in it would mean triangulating an annulus for a
## shape nothing ever moves. The shader shoals the water up to the beach so the join does
## not read as a sticker on deep water.
func _shape_island() -> void:
	# The island's ground, under the water like the bank's: the water shader cuts itself out
	# inside the island's curve, and that curve is the coast. There used to be a second node
	# here, the shelf of drowned sand the island sent out under the lake when it stood on top
	# of the water — see Ground.ISLAND_UNDER for why it went.
	var ground := Ground.new()
	ground.name = &"IslandGround"
	ground.layer = Ground.Layer.ISLAND
	ground.day = _day
	if OS.is_debug_build() and OS.get_environment("BENCH_OFF").contains("ground"):
		ground.visible = false
	add_child(ground)
	_grounds.append(ground)

	_island = Node2D.new()
	_island.name = &"IslandShed"
	# Above the layer a walker gets when it is behind the hut, and below the one it gets
	# when it is past it. See `_sort_walkers`.
	_island.z_index = SHED_LAYER
	_island.z_as_relative = false
	_island.draw.connect(_draw_shed)
	add_child(_island)
	_island.queue_redraw()


## The four merchants on the bank, one per material, spread a quarter of the lake apart.
##
## The plastic yard sits due south, straight out from the island's dock, because plastic is
## what a new net brings in and the first run the player ever sees should be a short one.
## The rest are spaced round from there, so filling out the net into the other materials is
## also what opens up the rest of the map.
func _shape_dropoffs() -> void:
	var order := [
		[TrashDef.Kind.PLASTIC, PI * 0.5, Color(0.42, 0.66, 0.78)],
		[TrashDef.Kind.TIMBER, 0.0, Color(0.66, 0.50, 0.28)],
		[TrashDef.Kind.METAL, -PI * 0.5, Color(0.62, 0.64, 0.70)],
		[TrashDef.Kind.RUBBER, PI, Color(0.32, 0.30, 0.34)],
	]
	_dropoffs.resize(0)
	for row: Array in order:
		var stop := Dropoff.new()
		stop.kind = row[0] as int
		stop.tint = row[2] as Color
		# Just inside the waterline, so the hull has water under it when it arrives.
		stop.berth = Iso.basin_point(row[1] as float, 0.92)
		stop.name = StringName("Dropoff" + stop.kind_name())
		# Above the rubbish (5), not below it: a yard stands on the bank and the water in
		# front of it is where the junk is. At 4 the piers were drawn under every bottle
		# floating near the shore.
		stop.z_index = 6
		stop.z_as_relative = false
		add_child(stop)
		_dropoffs.append(stop)
	# Held in TrashDef.Kind order, so a material index is a dropoff index everywhere.
	_dropoffs.sort_custom(func(a: Dropoff, b: Dropoff) -> bool: return a.kind < b.kind)


func _outline_bounds(outline: PackedVector2Array) -> Rect2:
	var box := Rect2(outline[0], Vector2.ZERO)
	for point: Vector2 in outline:
		box = box.expand(point)
	return box


## The dog dropped something in the crate.
##
## The same two things a cast does: the yard is heavier and the lake is one piece cleaner.
## Deliberately not worth money on its own — the crate still has to be ferried — so the dog
## is a slow trickle of work done rather than a second income.
func _dog_brought_back(def_index: int) -> void:
	_yard.put(def_index)
	_filth_stale = true
	if _sfx != null:
		_sfx.play_catch()


## The starting junk set, one `.tres` per kind under `resources/trash/`. The numbers live
## in those files now — open one in the Inspector to retune it, no code edit needed.
##
## TRASH_ORDER is also the save format: a save's stacks store an *index* into this list,
## not a name (see lake_grid.gd's `restore`), so an existing save breaks if an entry here
## is reordered or removed. Add new kinds at the end only.
const TRASH_ORDER := [
	"metal_can1", "metal_can2", "metal_can3", "metal_can4",
	"metal_hanger", "metal_pan", "metal_phone", "metal_pot",
	"metal_support", "metal_teapot", "plastic_bowl", "plastic_cup1",
	"plastic_cup2", "plastic_mug", "plastic_plate", "plastic_sheet",
	"plastic_wrap", "rubber_ball", "rubber_bone", "rubber_disk",
	"rubber_duck", "rubber_tire", "wood_box1", "wood_box2",
	"wood_painting1", "wood_painting2", "wood_piece",
	# Second batch, art_source/New_Objects_Lake -> assets/lake_objects_new.png.
	"wood_painting3", "wood_painting4", "metal_lamp", "metal_mirror",
	"plastic_sign", "plastic_frame", "plastic_toy", "plastic_globe",
	"rubber_block", "rubber_toy",
]

func _default_defs() -> Array[TrashDef]:
	var defs: Array[TrashDef] = []
	for id in TRASH_ORDER:
		var path := "res://resources/trash/%s.tres" % id
		var res: Resource = load(path)
		if res == null:
			push_error("Lake: missing %s" % path)
			continue
		# Duplicated so every call (a fresh level, a restart) gets its own instance rather
		# than sharing the one `load()` caches — `_dress` mutates atlas/region/size on it.
		defs.append(res.duplicate() as TrashDef)
	return defs


## Every def the lake is built from: the rubbish above, and one entry per piece of
## furniture in the catalogue.
##
## The furniture is the collection. Exactly one of each is hidden in the water, none of it
## is sold, and pulling one out is what puts it in the shed — so its defs are generated
## from the art rather than written out, and a new sheet is new things to find.
func _all_defs() -> Array[TrashDef]:
	var all := _default_defs()
	if _sheets == null or not _sheets.by_sheet.has("decor_dirty"):
		_dress(all)
		return all
	for name: String in _sheets.by_sheet["decor_dirty"] as PackedStringArray:
		# Nameless pieces are not finds. Every decoration is named in tools/decor_sets.json
		# by hand, so this should never fire now — it fired when the collection was cut off a
		# sprite sheet by a slicer that kept anything big enough to be an item, offcuts
		# included, and a nameless offcut dealt as treasure turned up in the lake as a find
		# the player carried home and could not name. Kept as the gate that stops that.
		if _pretty(name).is_empty():
			continue
		var cells := _sheets.cells_of(name)
		var bulk := cells.x * cells.y
		var find := _def(
			_pretty(name),
			TrashDef.Kind.TIMBER if bulk % 2 == 0 else TrashDef.Kind.METAL,
			Vector2(26.0, 26.0),
			# Heavy: a wardrobe belongs at the bottom of a stack, under the mugs.
			0.22, 2.0 + 0.4 * float(bulk), 2.0 + 0.5 * float(bulk),
			clampi(bulk / 2, 1, 4), Color(0.58, 0.44, 0.32), StringName(name)
		)
		find.keepsake = true
		# One def per copy, not one def hidden several times: `_hide_treasures` plants one of
		# each keepsake def, and every copy has to be its own object in the water with its own
		# hiding place. Four chairs in one corner is a stack, not a set.
		for copy in _sheets.copies_of(StringName(name)):
			all.append(find if copy == 0 else find.duplicate() as TrashDef)
	_dress(all)
	return all


## Hide one of every find in the lake.
##
## Not part of the fill: the fill sorts by weight, and a find planted by it would sit at
## the bottom of the deepest stack in the middle of the basin every time. These are dealt
## from their own seeded shuffle across the deep water, a couple of slots down, so they are
## spread over the basin and none of them is on the surface waiting to be scooped.
func _hide_treasures() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _level_seed() ^ 0x5EED
	for i in _grid.defs.size():
		if not _grid.defs[i].keepsake:
			continue
		var planted := false
		for attempt in 40:
			var tx := rng.randi_range(2, Iso.COLS - 3)
			var ty := rng.randi_range(2, Iso.ROWS - 3)
			var index := _grid.index_of(tx, ty)
			var height := _grid.height_of(index)
			if height < 3:
				continue
			_grid.insert(index, maxi(height - 1 - rng.randi_range(0, 2), 0), i)
			planted = true
			break
		if not planted:
			_plant_anywhere(i)


## Put a find somewhere — anywhere — after the random darts all missed.
##
## Forty throws at tiles with three things on them is a fast way to place a find in a full
## lake and no guarantee at all in a sparse one: a run where the darts all landed on thin
## water dropped that find out of the game, and a collection that cannot be completed in a
## run is worse than one hidden somewhere obvious. The deepest stack on the board is the
## nearest thing to where it wanted to go, and the middle of it is still a dig.
func _plant_anywhere(def_index: int) -> void:
	var best := -1
	var deepest := -1
	for index in _grid.stacks.size():
		var height := _grid.height_of(index)
		if height > deepest:
			deepest = height
			best = index
	if best < 0:
		return
	_grid.insert(best, maxi(deepest - 1, 0), def_index)


## Everything found so far, as catalogue names. One of each, in the order it came out.
func found() -> Array[String]:
	return unlocked


## A catalogue name as something to read, or nothing at all.
##
## The names are baked into assets/pieces.json beside the rectangles, from the authored
## table in tools/decor_sets.json. Empty for a piece that has not been named rather than a
## stand-in: "Find 07" is not something anybody pulled out of a lake, and every screen that
## shows a find checks for the empty string and draws the picture on its own instead.
func _pretty(name: String) -> String:
	return "" if _sheets == null else _sheets.title_of(StringName(name))


## Point every def at its picture, and take its drawn size from the art rather than from
## the number written next to it. With no atlas the defs keep the blocked-in sizes they
## were authored with, which is what the placeholder path draws.
func _dress(defs: Array[TrashDef]) -> void:
	if _sheets == null:
		return
	for def: TrashDef in defs:
		if String(def.piece).is_empty() or not _sheets.has(def.piece):
			continue
		def.atlas = _sheets.atlas
		def.region = _sheets.region_of(def.piece)
		var art := def.region.size
		var longest := maxf(art.x, art.y)
		# Whole source pixels wherever the limits allow, like the angler, so a piece sits on the
		# art grid. A crumb too small at SPRITE_SCALE is scaled up by whole steps.
		#
		# The cap is the exception, and stays exact rather than whole: only the big finds reach
		# it, and rounding their scales inverted the proportion — a 44-pixel mirror rounded up
		# to 88 while a 55-pixel sofa rounded down to 55. Those few draw at exactly
		# SPRITE_LARGEST, slightly off the grid, and the biggest picture stays the biggest thing.
		var scale := SPRITE_SCALE
		if longest * scale < SPRITE_SMALLEST:
			scale = ceilf(SPRITE_SMALLEST / longest)
		elif longest * scale > SPRITE_LARGEST:
			scale = maxf(SPRITE_LARGEST / longest, SPRITE_SMALLEST / longest)
		def.size = art * scale


func _def(
	name: String, material: TrashDef.Kind, size: Vector2, lightness: float, filth: float,
	cost: float, tier: int, colour: Color, piece: StringName = &""
) -> TrashDef:
	var d := TrashDef.new()
	d.display_name = name
	d.material = material
	d.size = size
	d.lightness = lightness
	d.pollution = filth
	d.haul_cost = cost
	d.tier = tier
	d.block_color = colour
	d.piece = piece
	return d


## Casting, reeling, zooming, and the shed door. Four inputs, and no two of them mean the
## same thing at the same time.
func _unhandled_input(event: InputEvent) -> void:
	if _extra_input(event):
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		match key.keycode:
			KEY_E:
				# Walking up to the shed and pressing E opens the shed. The upgrades are a
				# thing you go into the shed to do, not a thing the shed is.
				if _settings_open:
					return
				if _shed_open:
					_set_shed(false)
				elif _menu_open:
					_set_menu(false)
				elif _at_shed():
					_set_shed(true)
				elif _dog != null and _dog.within_reach(_angler.tile_pos):
					# Standing next to the dog with nothing else under the key: the same
					# button that opens the shed says hello.
					_dog.pet()
				return
			KEY_ESCAPE:
				# One key backing out of whatever is open, innermost first: the shed, then
				# the shop board, and only on open water does it mean the settings.
				if _shed_open:
					_set_shed(false)
				elif _menu_open:
					_set_menu(false)
				else:
					_set_settings(not _settings_open)
				return
			KEY_F11:
				_settings.fullscreen = not _is_fullscreen()
				_set_fullscreen(_settings.fullscreen)
				return
			KEY_M:
				_settings.music_on = not _settings.music_on
				_push_music()
				return
			KEY_F6:
				wipe_save()
				return

	var drag := event as InputEventMouseMotion
	if drag != null and _panning:
		# Divided by the zoom, so a drag moves the world under the cursor by the distance
		# the cursor moved however far in or out the view is.
		_pan -= drag.relative / _camera.zoom
		_pan_moved += drag.relative.length()
		return

	var click := event as InputEventMouseButton
	if click == null:
		return

	# The middle button drags the view off the angler. Tapping it without dragging puts the
	# view back on them, which is the way out of having panned somewhere and lost yourself.
	if click.button_index == MOUSE_BUTTON_MIDDLE:
		if click.pressed:
			_panning = true
			_pan_moved = 0.0
			_pan_yielded = false
		else:
			_panning = false
			if _pan_moved < PAN_TAP:
				_pan = Vector2.ZERO
		return

	# The wheel zooms about the cursor, so the thing the player is pointing at is the
	# thing that stays put. Zooming about the screen's middle makes reaching a corner of
	# the lake a game of chasing it back.
	#
	# Guarded against any panel being open: this is _unhandled_input, so a wheel event over a
	# panel's own controls never reaches here — but the settings panel and the shop board
	# don't cover the whole screen, so a wheel turned over the exposed lake behind either one
	# used to zoom the lake out from under an open menu. The shed panel already covers nearly
	# everything, so this was likely never reachable from there, but it costs nothing to guard
	# uniformly rather than per-panel.
	if _settings_open or _menu_open or _shed_open:
		return
	if click.pressed and click.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom_by(ZOOM_STEP)
		return
	if click.pressed and click.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom_by(1.0 / ZOOM_STEP)
		return

	# The right button lays a lit net: the cast goes out, stays where it lands, and burns
	# or freezes there. It does nothing at all with an unlit net, which is why it is the
	# second button — the first one is the game, and this is the thing the charms buy.
	if click.button_index == MOUSE_BUTTON_RIGHT:
		if click.pressed and _net.state == CastNet.State.IDLE and _net.enchanted():
			_cast_at(get_global_mouse_position(), true)
		return

	if click.button_index != MOUSE_BUTTON_LEFT:
		return

	# A click that reaches this far is a click on the lake rather than on a panel — the
	# panels eat their own. So it closes whatever is open, which is what the "back to the
	# water" buttons were for and is a thing every player tries first anyway.
	if _settings_open or _menu_open or _shed_open:
		if click.pressed:
			_set_settings(false)
			_set_menu(false)
			_set_shed(false)
		return

	# Letting go is not part of the gesture any more: the net reels itself in from wherever
	# it lands, and a cast is one click rather than a click held down for the length of a
	# drag across the basin.
	if not click.pressed:
		return

	# Click to throw. A click on a net already down starts it moving again — the only way
	# it can be sitting still is a panel that was opened over it — and a click on one that
	# is already coming home is left alone.
	if _net.state == CastNet.State.IDLE:
		_cast_at(get_global_mouse_position())
	_net.set_pulling(true)


## Throw the net, on the numbers the player has now. The only cap is the net's own hold —
## the yard takes whatever comes back, however much of it there is.
func _cast_at(where: Vector2, laying: bool = false) -> void:
	_push_net_numbers()
	if _net.hold <= 0:
		return
	if _net.cast_to(where, laying):
		# Watching the cast is worth more than whatever the player had panned over to look
		# at, and they can always pan back.
		_pan_yielded = true


## Is the angler standing at the shed?
##
## Measured to where the hut stands, not to the island's middle — those are two thirds of a
## tile apart (`Iso.shed_centre`), which on a range of about three tiles is the difference
## between the door opening on the near side and on the far one.
func _at_shed() -> bool:
	return _angler.tile_pos.distance_to(Iso.shed_centre()) < SHOP_RANGE


## Zoom by a factor, keeping the world point under the cursor under the cursor.
##
## On levels: at least one level in the factor's direction, further if the factor asks for it,
## and never past either end.
func _zoom_by(factor: float) -> void:
	var level := _zoom_level_of(_view_zoom)
	var target := _zoom_level_of(_view_zoom * factor)
	if factor > 1.0:
		target = maxi(target, level + 1)
	elif factor < 1.0:
		target = mini(target, level - 1)
	var wanted := _zoom_level(clampi(target, _far_level(), _near_level()))
	if is_equal_approx(wanted, _view_zoom):
		return
	# Worked out from the camera's own mapping rather than by reading the mouse again
	# after moving it: the canvas transform only catches up next frame, so asking twice
	# would compare a fresh position against a stale one.
	var offset := get_viewport().get_mouse_position() - get_viewport_rect().size * 0.5
	var was := _camera.zoom.x
	_view_zoom = wanted
	_push_zoom()
	var now := _camera.zoom.x
	_camera.position = _clamped_view(_camera.position + offset / was - offset / now)


## Write the camera's zoom: what the player set, put on the nearest level and kept inside the
## same limits the wheel obeys.
func _push_zoom() -> void:
	# Levelled and clamped on the way out as well as when the wheel turns: the window can be
	# resized (or go fullscreen, which changes the stretch and so every level) under a view
	# that was already set, and anything outside can write `_view_zoom` directly.
	var level := clampi(_zoom_level_of(_view_zoom), _far_level(), _near_level())
	_view_zoom = _zoom_level(level)
	_camera.zoom = Vector2(_view_zoom, _view_zoom)


## How much of the way to close in one frame, for an ease that closes `rate` of the gap a
## second.
##
## Exponential rather than `rate * delta`: the linear form takes a bigger bite out of a long
## frame than the same time in short ones, so a view following at an uneven frame rate
## lurched — every slow frame a jump, every fast one a crawl. This closes the same share of
## the gap over the same time however it is cut up. At 60 fps the two differ by a hair.
static func _ease(rate: float, delta: float) -> float:
	return 1.0 - exp(-rate * delta)


## Snap where the camera is drawn to whole screen pixels, leaving where it is alone.
##
## The position stays smooth — following, dragging and the cast's slide all ease on it — and
## only the offset takes up the difference, so nothing that reads the camera's position is
## handed a stair-stepped value to ease from.
func _snap_camera() -> void:
	var per := _camera.zoom.x * _stretch()
	if per <= 0.0:
		return
	var drawn := (_camera.position * per).round() / per
	_camera.offset = drawn - _camera.position


## Real screen pixels to one canvas unit: the window's stretch, 1 at the base size.
func _stretch() -> float:
	var s := get_viewport().get_final_transform().get_scale().x
	return s if s > 0.0 else 1.0


## The zoom at a level: `level` screen pixels to every pixel of the art.
##
## Never past MAX_ZOOM, even at level one. A window stretched down below about a quarter of
## its base size (or a headless run, whose dummy display reports a stretch near nothing) has
## no whole level under the limit, and a view pushed ten times in is worse than one that is
## slightly off the pixel grid.
func _zoom_level(level: int) -> float:
	return minf(float(level) / (ART_PIXEL * _stretch()), MAX_ZOOM)


## The nearest level to a zoom.
func _zoom_level_of(zoom: float) -> int:
	return maxi(roundi(zoom * ART_PIXEL * _stretch()), 1)


## The closest level in: the last one not past MAX_ZOOM.
func _near_level() -> int:
	return maxi(floori(MAX_ZOOM * ART_PIXEL * _stretch() + 0.0001), 1)


## The furthest level out: the one nearest the fitted zoom.
##
## Nearest, not the first one out past it. On a stretched window the levels are a third or
## a half apart, and rounding outward went all the way to a view of the whole basin — the
## map `ZOOM_OUT_PULL` is there to stop.
func _far_level() -> int:
	return clampi(roundi(_fit_zoom() * ART_PIXEL * _stretch()), 1, _near_level())


## The zooms at the two ends, for the tests.
func _near_zoom() -> float:
	return _zoom_level(_near_level())


func _far_zoom() -> float:
	return _zoom_level(_far_level())


## The furthest out the view may go: the zoom at which the whole waterline sits inside the
## window with a margin round it.
##
## Never past MIN_ZOOM, which is the floor for a window so small or so odd a shape that
## fitting the lake into it would mean drawing the basin at a size nothing on it is legible
## at. Fitted rather than filled — the long axis is what runs out first, and cropping the
## ends off the lake is the thing this is here to stop.
func _fit_zoom() -> float:
	var span := Iso.basin_extent(ZOOM_OUT_TILES) * (1.0 + ZOOM_FIT_MARGIN)
	var view := get_viewport_rect().size
	if span.x <= 0.0 or span.y <= 0.0:
		return MIN_ZOOM
	return maxf(minf(view.x / span.x, view.y / span.y) * ZOOM_OUT_PULL, MIN_ZOOM)


func _set_menu(open: bool) -> void:
	_menu_open = open
	# The drawn board replaces the panel of buttons rather than sitting behind it. The panel
	# is kept in the tree — its buttons are still where the shop's numbers are written, and
	# the shed's own controls live on it — but it is never shown.
	_shop_skin.visible = open
	_shop.visible = false
	_push_radio()
	if open:
		_set_settings(false)
		_set_shed(false)
	_hold_the_angler()


## The room the finds go in. Opened from the shop, because the shed is where the player
## already is when they open it, and closed by the cross in its corner or by a click on the
## water around it.
func _set_shed(open: bool) -> void:
	_shed_open = open
	_shed.visible = open
	# The way to the shop sits in the corner beside Settings rather than on the shed's own
	# floor, so it is out of the way of both picking a find and putting it down. It is not a
	# child of the panel any more, so its own visibility has to be said here.
	_open_upgrades.visible = open
	if open:
		_shop.visible = false
		_menu_open = false
		_settings.visible = false
		_settings_open = false
		_room.unlocked = unlocked
		_room.decor = decor
		_room.carrying = &""
		_room.queue_redraw()
	# The lake's own readouts are not readable through a room and are not about it.
	_skin.visible = not open
	_push_radio()
	_hold_the_angler()


## The settings panel: the logbook and the window, which are about the session rather than
## about the lake and so are not in the shed with the upgrades.
func _set_settings(open: bool) -> void:
	_settings_open = open
	_settings.visible = open
	# Available on every screen except itself now, not just when the shed happens to be
	# closed — the shed check here was dead in practice anyway (nothing re-ran this when the
	# shed opened or closed on its own), and the button being covered while the shed was open
	# was really a draw-order issue, fixed in the scene: OpenSettings is now the last of the
	# HUD's overlay children, so it draws and takes input above the shed panel too.
	_open_settings.visible = not open
	# Settings lies over whatever was already on screen rather than clearing it. It used to
	# shut the shed on the way in, which left the room gone, the lake's own readouts still
	# hidden behind it, and nothing to press: opening settings from the decoration screen
	# emptied the screen. What is underneath is none of this panel's business.
	_hold_the_angler()


## The settings and shed panels are stock Godot controls (Button, CheckButton, HSlider) in
## the engine's default theme. Styled here with WoodUI's pieces — the wood-plank kit Richard
## gave as a style reference for this pass — so a settings checkbox reads as part of the same
## plank panel as its background rather than a grey engine default glued on. Bungee replaces
## RubbishFont2 here too, per the font swap asked for in the same message as the reference.
##
## Written once, at startup, over a fixed list of nodes, rather than as a Theme resource:
## a Theme's own file format is easy to get subtly wrong unseen, where this fails loudly
## per-control if a name is off instead of silently across the whole scene.
##
## Every scene Control in the game now, not just settings — including the shop panel's own
## buttons, which no player sees (the drawn board replaces it) but which would otherwise be
## the one corner of the scene still in the engine default. The drawn surfaces do not pass
## through here at all; they read the same constants directly out of style.gd.
## The labels the sweep reaches as well as the buttons. By full path, not by `%Title`: three
## panels each have a node called Title and a unique name can only point at one of them.
const _PANEL_LABELS := [
	"HUD/Shop/Pad/Scroll/Panel/Title",
	"HUD/Shop/Pad/Scroll/Panel/NetHeading",
	"HUD/Shop/Pad/Scroll/Panel/BoatHeading",
	"HUD/Shop/Pad/Scroll/Panel/DecorHeading",
	"HUD/Shed/Pad/Lines/Title",
	"HUD/Shed/Pad/Lines/Note",
]

## The two buttons that undo something. They used to be marked out three ways at once — a
## taller box, a bigger face, a colour of their own — which is two ways more than a warning
## needs. The colour is the one that stays.
const _PANEL_WARNINGS: Array[String] = []


func _polish_panel_controls() -> void:
	var font := Style.font()
	# Not the settings any more: it is a drawn board now (SettingsSkin), like the shop.
	var normal := WoodUI.panel_style(4, WoodUI.PLANK, WoodUI.PLANK_LIGHT, WoodUI.PLANK_DARK, 2)
	var hover := WoodUI.panel_style(
		4, WoodUI.PLANK_LIGHT, WoodUI.PLANK_LIGHT.lightened(0.2), WoodUI.PLANK, 2
	)
	var pressed := WoodUI.panel_style(4, WoodUI.PLANK_DARK, WoodUI.PLANK, WoodUI.SEAM, 2)
	var nodes: Array[Control] = []
	for path in [
		"%BuyNetWidth", "%BuyNetStrength", "%BuyNetRange", "%BuyReel", "%BuyNetHold",
		"%BuyBoatSpeed", "%BuyCargo", "%BuySkimmer", "%BuyFleet",
		"%OpenShed", "%SendNow", "%AutoFerry", "%CloseMenu",
	]:
		var node := get_node_or_null(path) as Control
		if node != null:
			nodes.append(node)
	for path in _PANEL_LABELS:
		var label := get_node_or_null(path) as Control
		if label != null:
			nodes.append(label)
	var warnings: Array[Control] = []
	for path in _PANEL_WARNINGS:
		var node := get_node_or_null(path) as Control
		if node != null:
			warnings.append(node)
	for node in nodes:
		if font != null:
			node.add_theme_font_override("font", font)
		var ink := Style.DANGER.lerp(Style.INK, 0.35) if node in warnings else Style.INK
		node.add_theme_color_override("font_color", ink)
		# The sweep owns the size as well as the colour, so the scene no longer carries
		# sixty per-node overrides that nothing keeps in step with each other.
		var size_px := Style.TEXT_BODY
		if node.name == &"Title":
			size_px = Style.TEXT_TITLE
		elif String(node.name).ends_with("Heading"):
			size_px = Style.TEXT_HEAD
		elif node.name == &"Note":
			size_px = Style.TEXT_SMALL
		node.add_theme_font_size_override("font_size", size_px)
		node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if node is BaseButton:
			node.add_theme_stylebox_override("normal", normal)
			node.add_theme_stylebox_override("hover", hover)
			node.add_theme_stylebox_override("pressed", pressed)
			node.add_theme_stylebox_override("focus", hover)
		if node is CheckButton:
			node.add_theme_icon_override("on", WoodUI.switch_icon(true))
			node.add_theme_icon_override("off", WoodUI.switch_icon(false))
## When to start asking whether the lake is finished, as a fraction of the filth it was
## built with, and how often to ask once it is that close.
##
## The meter cannot be the trigger on its own. It is a float that has had eighteen thousand
## subtractions done to it, and eighteen thousand subtractions do not land on zero — they
## land a millionth above it, which is a bar that reads empty and a game that never ends.
## So the meter reading nothing is the cue to ask the field, and the field is what answers.
const CLEAN_ENOUGH := 0.001
const CLEAN_CHECK_EVERY := 0.5


## Is it over yet?
##
## Only asked while the meter is on the floor, and only twice a second even then, because
## the answer means walking every stack in the basin. Both of those are why the question is
## cheap enough to keep asking rather than being wired to the last piece landing — a piece
## can leave the lake by the net, by the skimmer, or by burning, and an ending that has to
## be remembered by every one of those is an ending that will be forgotten by the next one.
func _look_for_the_end(delta: float) -> void:
	if _cleaned:
		return
	if _filth_left > _filth_total * CLEAN_ENOUGH:
		return
	_clean_check_in -= delta
	if _clean_check_in > 0.0:
		return
	_clean_check_in = CLEAN_CHECK_EVERY
	_left_over = _grid.piece_count() if _grid != null else 0
	_check_cleaned()


## Has the last piece come out of the water?
##
## Asked only once the meter has bottomed out, because the answer means walking every stack
## in the grid and the meter reaching zero is a necessary condition for it. The meter itself
## is not the test: it is a float that has had a few thousand subtractions done to it, and
## "close enough to zero" is not the same question as "is the lake empty".
func _check_cleaned() -> void:
	if _cleaned or _grid == null or _grid.piece_count() > 0:
		return
	_cleaned = true
	# The remainder is float dust from thousands of subtractions, and the lake is empty:
	# the meter is allowed to say so now that the field has been asked.
	_filth_left = 0.0
	pollution = 0.0
	if _sfx != null:
		_sfx.play_found()
	_on_lake_cleaned()
	# The moment is worth keeping without waiting for the autosave to come round.
	save_game()


## Lay the closing words over the lake.
func _show_farewell() -> void:
	if _farewell != null:
		return
	_farewell = Farewell.new()
	_farewell.dismissed.connect(_drop_farewell)
	# A cleaned lake is not the end of the game any more, only the end of the quiet part.
	var onward := _next_scene()
	if onward != "":
		_farewell.offer_onward()
		_farewell.onward.connect(_go_onward.bind(onward))
	# Its own layer, above the HUD rather than beside it: the closing words are the one thing
	# in the game that everything else — the island, the meter, the money — goes behind.
	var over := CanvasLayer.new()
	over.name = &"Farewell"
	over.layer = 20
	over.add_child(_farewell)
	add_child(over)
	_hold_the_angler()


## The player has read it. Let go of it at once rather than when it finishes fading, so the
## angler gets their legs back on the click rather than half a second after it.
## Where the ending leads, or an empty string for a level that is the last one.
func _next_scene() -> String:
	return "res://scenes/siege.tscn"


## Take the door. The run is written first: what carries into the next level is read back
## out of the save, so the save has to be the finished one before the scene goes away.
func _go_onward(scene: String) -> void:
	save_game()
	_farewell = null
	get_tree().change_scene_to_file(scene)


func _drop_farewell() -> void:
	_farewell = null
	_hold_the_angler()


## Hang a cross in a panel's top right corner.
##
## The cross is a child of the HUD rather than of the panel: a PanelContainer stretches what
## it is given to fill itself, which is right for the contents and wrong for something meant
## to sit in a corner of them. So it is pinned to the panel's rectangle instead, and moves
## with it when the window changes shape.
func _pin_close(panel: Control, closing: Callable) -> void:
	var cross := CloseButton.new()
	cross.size = Vector2(CLOSE_BOX, CLOSE_BOX)
	cross.pressed.connect(closing)
	panel.get_parent().add_child(cross)
	var place := func() -> void:
		cross.visible = panel.visible
		cross.position = Vector2(
			panel.position.x + panel.size.x - CLOSE_BOX - CLOSE_INSET,
			panel.position.y + CLOSE_INSET
		)
	place.call()
	panel.item_rect_changed.connect(place)
	panel.visibility_changed.connect(place)


## The angler stays put while anything is open over the lake, so holding a key to reach a
## button does not walk them into the water behind the panel.
func _hold_the_angler() -> void:
	var busy := (
		_menu_open or _settings_open or _shed_open
		or _farewell != null
	)
	_angler.can_walk = not busy
	# The net is held where it is for as long as the panel is up, and goes back to reeling
	# itself in the moment the water is in front of the player again. Nothing is held down,
	# so nothing is dropped by opening the shed mid-cast.
	_net.set_pulling(not busy)


## The music: one long track, looped, started the moment the lake is, and started twice.
##
## Looping is set here as well as on the imported files so a re-import cannot quietly end
## the song four minutes in, and the indoors copy is started in the same breath as the
## outdoors one: two players from the same instant stay in step for as long as they both
## run, which is what lets the shed door be a fade rather than a seek.
func _start_music() -> void:
	if _radio == null:
		_radio = AudioStreamPlayer.new()
		_radio.name = &"MusicRadio"
		_radio.stream = RADIO_TRACK
		_radio.volume_db = MUSIC_SILENT
		add_child(_radio)
	for player in [_music, _radio]:
		var track := player.stream as AudioStreamMP3
		if track != null:
			track.loop = true
		# A stream that runs out anyway — a browser that decoded it short, an import that
		# came back without the loop — is put back to the top rather than left silent.
		if not player.finished.is_connected(_restart_music):
			player.finished.connect(_restart_music.bind(player))
	_push_music()
	if not _music.playing:
		_music.play()
	if not _radio.playing:
		_radio.play()


## Both copies back to the top together, so they are still the same bar when they get there.
func _restart_music(_who: AudioStreamPlayer) -> void:
	_music.play()
	if _radio != null:
		_radio.play()
	_push_music()


## Aim the song at the room or at the lake. Called whenever a panel opens: the shed and the
## upgrades board are both inside the hut, and a song heard from inside a hut is a song heard
## through a wall. The move itself is made a frame at a time in `_fade_radio`.
func _push_radio() -> void:
	_radio_on = _menu_open or _shed_open


## Volume, from the two controls that set it. Muting leaves the track running quietly
## rather than stopping it, so turning it back on does not start the song again.
func _push_music() -> void:
	if _radio == null:
		_music.volume_db = _music_db()
		return
	# Equal-power would be the textbook curve, but these are the same recording a filter
	# apart: they sum rather than fight, and a straight level crossfade keeps the song at one
	# loudness through the door.
	var db := _music_db()
	_music.volume_db = db + linear_to_db(maxf(1.0 - _radio_at, 0.0001))
	_radio.volume_db = db + linear_to_db(maxf(_radio_at, 0.0001))


## The level both players are working from: what the two controls in the settings say.
func _music_db() -> float:
	return (
		lerpf(MUSIC_SILENT, MUSIC_LOUDEST, _settings.music_level)
		if _settings.music_on else MUSIC_SILENT
	)


## One frame of the walk between the lake and the hut.
func _fade_radio(delta: float) -> void:
	if _radio == null:
		return
	var want := 1.0 if _radio_on else 0.0
	if is_equal_approx(_radio_at, want):
		return
	_radio_at = move_toward(_radio_at, want, RADIO_FADE * delta)
	_push_music()



## The sound effects' own level. Separate from the music because they are separate things:
## a player who wants the lake quiet and the radio on is not confused, they are working.
func _push_sfx() -> void:
	if _sfx != null:
		_sfx.set_level(_settings.sfx_level, _settings.sfx_on)


func _set_sfx(_on: bool) -> void:
	_push_sfx()


func _set_sfx_level(_level: float) -> void:
	# Dragging the slider up is a request to hear it, the same as the music's.
	if not _settings.sfx_on:
		_settings.sfx_on = true
	_push_sfx()


func _set_music(_on: bool) -> void:
	_push_music()


func _set_music_level(_level: float) -> void:
	if not _settings.music_on:
		_settings.music_on = true
	_push_music()


func _is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN 		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


## Borderless fullscreen rather than exclusive: the lake is a window to alt-tab out of.
func _set_fullscreen(on: bool) -> void:
	if on == _is_fullscreen():
		return
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED
	)


func _quit() -> void:
	save_game()
	get_tree().quit()


## A piece lifted off the water, the moment the net's mouth closes on it. The meter moves
## here and nowhere else: the water reads as cleaner the instant the piece is out of it,
## not whenever the haul happens to finish crossing the lake to the angler.
func _on_net_caught(def_index: int) -> void:
	var def := _grid.defs[def_index]
	_filth_left = maxf(_filth_left - def.pollution, 0.0)
	_filth_stale = true
	pollution = clampf(_filth_left / _filth_total, 0.0, 1.0)


## The catch coming out of the net, back at the angler. The pollution meter has already
## moved (see _on_net_caught) — what is left to decide here is only where each piece goes:
## a find onto the shelf in the shed, everything else thrown on to the yard.
func _on_net_landed(cargo: PackedInt32Array) -> void:
	var from := _angler.rod_tip()
	var slot := 0
	for i in cargo.size():
		var def := _grid.defs[cargo[i]]
		# A find never joins the pile and is never sold. It goes on the shelf in the shed,
		# which is the only thing in this game that is kept rather than spent.
		if def.keepsake:
			_keep(def)
			caught += 1
			continue
		_haul.send(
			cargo[i], from, _yard.drop_point(), slot, cargo.size(), null, null, _angler
		)
		slot += 1
		caught += 1


## A thrown piece reaching wherever it was thrown. A boat tagged itself and takes it into
## the hold; anything else was bound for the yard, which always has room for it.
func _on_haul_arrived(def_index: int, tag: Variant) -> void:
	var boat := tag as Boat
	if boat != null:
		boat.stow(def_index)
		return
	# Tagged with a yard: a piece a ferry has just thrown ashore, paid for as it comes down
	# rather than when the hull tipped it, so the purse and the picture agree.
	var sale := tag as Dropoff
	if sale != null:
		_on_sold(PackedInt32Array([def_index]), sale.kind)
		return
	_yard.put(def_index)


## A pigeon in the net. Paid on the spot: it never reaches the yard, it is not a material
## any merchant buys, and it was never part of the lake's filth — so the meter does not
## move for it either.
func _on_bird_caught(at: Vector2) -> void:
	sludge += _economy.bird_bonus
	birds_caught += 1
	if _splash != null:
		_splash.splash(at, 0.55)
	# And, on some catches, the bird itself: the head in the corner and the coo that goes with
	# it, both off the one roll. They are halves of the same joke — a coo with no bird is a
	# noise from nowhere, and a bird with no coo is a picture — so either both happen or
	# neither does. The money is not part of the bargain and arrives every time.
	if _pop_rng.randf() >= POP_ODDS:
		return
	if _pigeon != null:
		_pigeon.pop(roundi(_economy.bird_bonus))
	if _sfx != null:
		_sfx.play_coo()


## The pigeon in the corner, on its own layer just under the finds card: a bird is worth a
## laugh and a decoration is worth a look, and when both land at once the decoration wins.
func _build_pigeon_pop() -> void:
	_pigeon = PigeonPop.new()
	_pigeon.name = &"PigeonPop"
	var over := CanvasLayer.new()
	over.name = &"Pigeon"
	over.layer = 18
	over.add_child(_pigeon)
	add_child(over)


## The card that holds a new find up, on its own layer just under the ending's. Above the
## HUD, because a wardrobe coming out of the lake outranks the meter for two seconds, and
## below the farewell, because the end of the run outranks everything.
func _build_trophy() -> void:
	_trophy = Trophy.new()
	_trophy.name = &"Trophy"
	_trophy.sheets = _sheets
	var over := CanvasLayer.new()
	over.name = &"Finds"
	over.layer = 19
	over.add_child(_trophy)
	add_child(over)


## Put a find on the shed's shelf. Once each: the lake holds one of every piece, and a
## second copy of the same name would be a bug worth swallowing quietly rather than
## showing the player twice in their inventory.
## The bed the shed starts with rather than one anybody has to fish out — the one piece of
## furniture that was never dirty. Runs once per session after load_game(), whether a save
## was read or not, so a fresh game gets it and a save from before it existed backfills it
## the same way: only added when it is not already on the shelf.
func _seed_starter_bed() -> void:
	var piece := "decor_bed"
	if unlocked.has(piece):
		return
	unlocked.append(piece)
	if _room != null:
		_room.place(StringName(piece), Vector2i(1, 1))


func _keep(def: TrashDef) -> void:
	var name := String(def.piece)
	if name.is_empty():
		return
	# Kept up to the number that were hidden. It used to be one of anything, which was the
	# same rule as "one of each was planted"; now the chairs come four to a set, and the
	# shelf has to hold four of them without holding a fifth that was never in the water.
	var held := 0
	for kept: String in unlocked:
		if kept == name:
			held += 1
	if _sheets != null and held >= _sheets.copies_of(StringName(name)):
		return
	unlocked.append(name)
	_note_save(
		"Something for the shed" if def.display_name.is_empty()
		else "%s — it can go in the shed" % def.display_name
	)
	# Held up in the middle of the screen as well as written in the corner. The shed is two
	# clicks away, so without this the player never sees what they found.
	if _trophy != null:
		_trophy.show_find(def.piece, def.display_name)
	if _sfx != null:
		_sfx.play_chime()


## The ferry landing a load at one of the four merchants. The purse moves here and nowhere
## else.
##
## The meter is not touched: anything the boat is carrying either came out of the yard,
## where it was already counted, or was skimmed out of the water on the way — and that
## second case is counted below, because it left the lake when the skimmer took it.
func _on_sold(cargo: PackedInt32Array, kind: int) -> void:
	for i in cargo.size():
		sludge += _economy.piece_base_pay + _grid.defs[cargo[i]].pollution * _economy.piece_filth_pay
		sold_count += 1
	sold_by_kind[kind] += cargo.size()


## A piece the ferry's skimmer took out of the water on its way past. It left the lake
## when the skimmer closed on it, so the meter moves now rather than when it is sold —
## the same rule the net follows, and the reason both report through here.
func _on_skimmed(def_index: int) -> void:
	_filth_left = maxf(_filth_left - _grid.defs[def_index].pollution, 0.0)
	pollution = clampf(_filth_left / _filth_total, 0.0, 1.0)
	_filth_stale = true
	caught += 1


## What `skimmer` costs: the price of its first level, and what each level multiplies the
## next one by. Every other track's price lives in its own resources/upgrades/*.tres now.
const PRICES := {
	&"skimmer": [26.0, 1.48],
}


## Every track the shop sells, in the order the board lists them. The rows themselves carry
## a name and a picture as well, but the HUD only wants to count them, and counting them
## should not mean formatting nine lines of text every frame.
const TRACKS := [
	&"net_width", &"net_strength", &"net_range", &"reel", &"net_hold",
	&"boat_speed", &"cargo", &"skimmer", &"fleet",
	&"dog_fetch", &"dog_wait",
]


## How many upgrades could be bought right now. Drawn on the HUD's upgrades button, so that
## money worth spending says so on the way in rather than only once the board is open.
func _affordable() -> int:
	var count := 0
	for key: StringName in TRACKS:
		if not is_maxed(key) and sludge >= cost_of(key):
			count += 1
	return count


## Every upgrade as one row of the drawn boards: which board it stands on, what it is,
## what it does now, what the next level costs, and whether it can be paid for.
func _shop_rows() -> Array:
	var out: Array = []
	var listed := [
		[&"net_width", &"net", "Width", "%d tiles" % _tiles_in_radius(net_radius())],
		[&"net_strength", &"net", "Strength", "lifts tier %d" % net_power()],
		[&"net_range", &"net", "Range", "%.1f tiles" % net_range()],
		[&"reel", &"net", "Speed", "%.1f tiles/s" % reel_speed()],
		[&"net_hold", &"net", "Haul", "%d per cast" % net_hold()],
		[&"boat_speed", &"boat", "Speed", "%.1f tiles/s" % boat_speed()],
		[&"cargo", &"boat", "Hold", "%d aboard" % boat_cargo()],
		[&"skimmer", &"boat", "Skimmer", (
			"off" if skimmer_level <= 0
			else "%d items, %d%%" % [skim_hold(), roundi(skim_chance() * 100.0)]
		)],
		[&"fleet", &"boat", "Extra ferry", "%d in the water" % fleet_size()],
		[&"dog_fetch", &"dog", "Fetching", "%d per trip" % dog_fetch()],
		[&"dog_wait", &"dog", "Keenness", "waits %.0fs at most" % maxf(
			Dog.MOOD_MOST - dog_wait_cut(), Dog.MOOD_LEAST
		)],
	]
	for line: Array in listed:
		var key: StringName = line[0]
		var full := is_maxed(key)
		var price := cost_of(key)
		out.append({
			"key": key,
			"board": line[1],
			"name": line[2],
			# Its own field, not part of the name: the shop draws it in the clean water's blue
			# so the level stands off the name (2026-09-11).
			"level": "(Lvl %d)" % _level_of(key),
			"value": line[3],
			# A track with nothing left to sell says so in a word: a dash reads as a price
			# that failed to print.
			"cost": "Max" if full else "$%d" % roundi(price),
			"afford": not full and sludge >= price,
		})
	return out


## The net's numbers, from the levels the player has now.
##
## Pushed whenever they change rather than only at the moment of a cast. The ring drawn on
## the water is the net's own range, so a net that has not been thrown since the game started
## draws the range it was built with — which on a loaded save is a ring for somebody else's
## rod. It is the first thing on screen and it was the one thing lying about the save.
func _push_net_numbers() -> void:
	_net.radius = net_radius()
	_net.power = net_power()
	_net.range_tiles = net_range()
	_net.reel_speed = reel_speed()
	_net.hold = net_hold()


## The day, onto the things that show it.
##
## The modulate does the world in one multiply, so nothing that draws has to know what time
## it is. The fill behind the lake is a separate canvas and has to be tinted by hand, or the
## woodland past the last of the trees stays at noon while the lake goes gold. (The water
## used to take the sun's lean as well, to gather its glints into a strip under the sun;
## the glints are gone and so is that.)
func _push_daylight() -> void:
	if _day == null:
		return
	if _daylight != null:
		_daylight.color = _day.tint
	($Sky/Fill as ColorRect).color = BEYOND * _day.tint
	# The floating rubbish's shadows, which are shader-driven and so cannot be re-laid as the
	# sun moves. One uniform, every frame; see LakeGrid.sun_lean.
	if _grid != null:
		_grid.sun_lean(_day.lean)


## The other level, as a scene and as the words on the button that goes there. The lake is
## level one, so its door leads to the siege; the siege overrides both halves.
##
## Not the same door as the ending: that one is earned and only opens once the water is
## clean. This one is a way to walk between the two lakes at any time, which is what makes
## either of them worth looking at twice.
func _other_level_scene() -> String:
	return "res://scenes/siege.tscn"


func _other_level_name() -> String:
	return "Go to the siege  (level 2, fresh)"


## Take the door. The level left is written on the way out — the siege reads the first
## lake's save for the upgrades a player arrives with, so it has to be the finished one —
## and the level walked into is built from scratch rather than from its own save.
func _swap_levels() -> void:
	save_game()
	start_fresh = true
	get_tree().change_scene_to_file(_other_level_scene())


## Cost of the next level on a track.
func cost_of(what: StringName) -> float:
	var track: UpgradeTrack = _upgrades.get(what)
	if track != null:
		return track.cost(_level_of(what))
	var price: Array = PRICES[what]
	return float(price[0]) * pow(float(price[1]), float(_level_of(what)))


## Where a track stops. resources/upgrades/*.tres for everything but `skimmer`.
func _level_cap(what: StringName) -> int:
	var track: UpgradeTrack = _upgrades.get(what)
	if track != null:
		return track.level_cap
	return int(MAX_LEVELS.get(what, 0))


func _level_of(what: StringName) -> int:
	match what:
		&"net_width":
			return net_width_level
		&"net_strength":
			return net_strength_level
		&"net_range":
			return net_range_level
		&"reel":
			return reel_level
		&"net_hold":
			return net_hold_level
		&"boat_speed":
			return boat_speed_level
		&"cargo":
			return cargo_level
		&"skimmer":
			return skimmer_level
		&"fleet":
			return fleet_level
		&"dog_fetch":
			return dog_fetch_level
		&"dog_wait":
			return dog_wait_level
		_:
			return 0


## Whether a track has sold everything it has. The board, the old buttons and the buy
## itself all ask here, so the three cannot disagree about what is still for sale.
func is_maxed(what: StringName) -> bool:
	return _level_of(what) >= _level_cap(what)


## One track's level out of a save, held to what the track now sells.
func _saved_level(levels: Dictionary, what: StringName) -> int:
	return clampi(int(levels.get(String(what), 0)), 0, _level_cap(what))


func _buy(what: StringName) -> void:
	if is_maxed(what):
		return
	var price := cost_of(what)
	if sludge < price:
		return
	sludge -= price
	match what:
		&"net_width":
			net_width_level += 1
		&"net_strength":
			net_strength_level += 1
		&"net_range":
			net_range_level += 1
		&"reel":
			reel_level += 1
		&"net_hold":
			net_hold_level += 1
		&"boat_speed":
			boat_speed_level += 1
		&"cargo":
			cargo_level += 1
		&"skimmer":
			skimmer_level += 1
		&"fleet":
			fleet_level += 1
			_add_boat()
		&"dog_fetch":
			dog_fetch_level += 1
		&"dog_wait":
			dog_wait_level += 1
	# After the level goes on, not before: the sound is the purchase landing, and a buy that
	# fell through above has already returned without making one. The sparkle over the
	# board's sprite is the same receipt for the eye.
	if _sfx != null:
		_sfx.play_bought()
	_shop_skin.cheer(what)
	_push_net_numbers()
	_push_boat_numbers()
	_push_dog_numbers()


## How close two hulls may come, in tiles, and how fast they ease apart when they are closer
## than that. A beam and a bit: the hulls are long, but two boats a length apart nose to tail
## are a queue at a yard and read fine, while two a beam apart abreast are one boat drawn
## twice. Under the 2.4 tiles the moorings are spread by, or a fleet at rest would push
## itself out of its own row.
const PART_CLEAR := 1.7
const PART_EASE := 2.6


## Keep the hulls out of each other.
##
## Not physics, and not a rule the boats obey: each pair that has come too close is eased
## apart by half the overlap each, after they have all moved, and the route they are on is
## untouched — a nudged hull sails on from wherever it now is, because every leg is planned
## from `tile_pos`. The same bargain `Boat._shove_aside` strikes with the floating rubbish,
## for the same reason: one representation, no bodies, nothing to fall out of step with.
##
## Two boats exactly on top of each other have no direction to part along, so they take one
## off their place in the fleet rather than a roll — a nudge nobody can see the reason for is
## still better than two hulls that never separate, and a rolled one would jitter.
func _part_the_fleet(delta: float) -> void:
	if _boats.size() < 2:
		return
	var ease := _ease(PART_EASE, delta)
	for i in _boats.size():
		for j in range(i + 1, _boats.size()):
			var one := _boats[i]
			var two := _boats[j]
			var gap := two.tile_pos - one.tile_pos
			var apart := gap.length()
			if apart >= PART_CLEAR:
				continue
			var way := (
				gap / apart if apart > 0.001
				else Vector2(cos(float(i) * 2.4), sin(float(i) * 2.4))
			)
			var push := way * (PART_CLEAR - apart) * 0.5 * ease
			one.tile_pos -= push
			two.tile_pos += push


## Everything a hull needs to work, and where it ties up.
##
## Berths are spread along the island's south shore so a fleet at rest is a row of moored
## boats rather than one boat drawn several times. They stay outside the beach, which is
## what the route planner already assumes of the dock.
func _fit_out(boat: Boat, index: int) -> void:
	_reberth(boat, index)
	boat.day = _day
	boat.dropoffs = _dropoffs
	boat.yard = _yard
	boat.grid = _grid
	boat.splash = _splash
	boat.sfx = _sfx
	boat.haul = _haul
	# The skimmer drags the angler's net, so it is handed the angler's picture of one.
	boat.skim_sheet = _net.art_sheet()
	boat.skim_frame = _net.art_frame(&"land", -1)
	boat.sold.connect(_on_sold)
	boat.skimmed.connect(_on_skimmed)


## How many hulls the player owns.
func fleet_size() -> int:
	return 1 + fleet_level


## Build a bought hull and put it in the water. Re-berths the whole fleet afterwards: the
## row of moorings is centred on the island, so every boat's home moves when one is added.
func _add_boat() -> void:
	var boat := Boat.new()
	boat.name = &"Boat%d" % _boats.size()
	boat.z_index = 12
	boat.z_as_relative = false
	# A hull of its own, so two ferries on the same leg do not fish up the same pieces in
	# the same order.
	boat.rng_seed = 771144 + 4013 * _boats.size()
	boat.auto_ferry = _auto_ferry.button_pressed
	_boats.append(boat)
	_fit_out(boat, _boats.size() - 1)
	add_child(boat)
	for i in _boats.size():
		_reberth(_boats[i], i)


## Move a moored boat to its place in the row. A boat already out on a run keeps sailing
## and comes home to the new berth.
func _reberth(boat: Boat, index: int) -> void:
	boat.dock = Vector2(
		Iso.ISLAND_CENTRE.x + (float(index) - 0.5 * float(fleet_size() - 1)) * 2.4,
		Iso.ISLAND_CENTRE.y + Iso.ISLAND_RADIUS.y + 2.2
	)
	if not boat.is_running():
		boat.tile_pos = boat.dock


## The ferry's numbers, pushed whenever they change rather than read every frame. A run
## already under way keeps the numbers it set off with only for its current leg — speed is
## re-read each frame from the boat's own field, which is what an upgrade felt instantly
## should do.
## What training has bought the dog. Pushed the same way and for the same reason as the
## net's and the ferry's: a loaded save has to reach the animal before it next decides what
## to do, or the first trip of the session is the trip an untrained dog would have made.
func _push_dog_numbers() -> void:
	if _dog == null:
		return
	_dog.fetch_most = dog_fetch()
	_dog.wait_cut = dog_wait_cut()


func _push_boat_numbers() -> void:
	for boat in _boats:
		boat.speed = boat_speed()
		boat.capacity = boat_cargo()
		boat.skim_radius = skim_radius()
		boat.skim_power = skim_power()
		boat.skim_chance = skim_chance()
		boat.skim_hold = skim_hold()
		boat.skim_depth = skim_depth()


## Send one hull out: the first one sitting at its berth. The button is a nudge for a
## player who has turned the automatic runs off, not a way to dispatch the whole fleet
## into a yard that only has one load in it.
func _send_ferry() -> void:
	for boat in _boats:
		if boat.dispatch():
			return


func _set_auto_ferry(on: bool) -> void:
	for boat in _boats:
		boat.auto_ferry = on


## How fast the view drifts to keep up with the angler.
const FOLLOW_SPEED := 6.0


## One engine for the whole fleet, driven by the busiest hull. Two boats loading at once
## are not twice as loud — they are one dock making a noise, and mixing a second copy of
## the same loop against itself would only phase.
func _push_engine() -> void:
	if _sfx == null:
		return
	var effort := 0.0
	var moving := false
	for boat in _boats:
		effort = maxf(effort, boat.engine_effort())
		if boat.is_running():
			moving = true
	_sfx.set_engine(effort, moving)
	_sfx.set_drag(_net_wash())


## How much water the net is pushing, 0 to 1. Nothing unless it is being hauled: a net
## sitting on the water is not making a sound. A wide mouth full of junk moves more water
## than an empty one, and the mouth pursing shut on the way in quiets it as it comes.
func _net_wash() -> float:
	if _net == null or _net.state != CastNet.State.REELING:
		return 0.0
	var load := float(_net.catch.size()) / maxf(float(_net.hold), 1.0)
	return clampf(0.36 + 0.64 * load, 0.0, 1.0) * lerpf(1.0, 0.45, _net.closed())


func _process(delta: float) -> void:
	_push_daylight()
	_part_the_fleet(delta)
	_fade_radio(delta)
	_remap_filth(delta)
	# The camera follows the angler rather than being panned: the arrow keys are theirs
	# now, and a view that has to be driven separately from the character is two jobs for
	# one pair of hands. While a cast is out it drifts off them and onto the net.
	_cast_look = lerpf(
		_cast_look,
		CAST_LOOK if _net.state != CastNet.State.IDLE else 0.0,
		_ease(LOOK_SPEED, delta)
	)
	# Walking asks for the view back too. Panning is for looking at the lake, and the moment
	# the player starts moving they have stopped looking and started going somewhere —
	# which they want to be able to see. Noticed by watching the angler rather than by
	# reading the keys, so it holds however they came to move.
	if _angler_was.distance_to(_angler.tile_pos) > 0.001 and _angler_was != Vector2.INF:
		_pan_yielded = true
	_angler_was = _angler.tile_pos

	# A cast takes the view back off whoever panned it away, and goes on taking it until it
	# has all of it. Not while they are still holding the button, though — a hand on the
	# mouse outranks the net.
	if _pan_yielded and not _panning and _pan != Vector2.ZERO:
		_pan = _pan.lerp(Vector2.ZERO, _ease(PAN_RELEASE, delta))
		if _pan.length() < 1.0:
			_pan = Vector2.ZERO

	# Eased while it is following something, and snapped while the player is dragging it:
	# a view that lags a hand on the mouse feels like a view being argued with.
	_camera.position = _clamped_view(
		_watching() if _panning
		else _camera.position.lerp(_watching(), _ease(FOLLOW_SPEED, delta))
	)

	_look_for_the_end(delta)

	_save_note_for = maxf(_save_note_for - delta, 0.0)
	_autosave_in -= delta
	if _autosave_in <= 0.0:
		save_game()

	_push_zoom()
	_snap_camera()

	_grid.set_view(_visible_world_rect())
	_grid.set_detailed(_camera.zoom.x >= DETAIL_ZOOM)
	_push_water_colours()
	_push_engine()
	_update_hud()
	_sort_walkers()
	_island.queue_redraw()


## Which of the two solid things on the island the angler and the dog are currently behind.
##
## Everything here is drawn on fixed layers rather than sorted by depth — the water, the
## sand, the shed, the boat, each with a number — and the two things that walk about were
## given a number over the top of all of it, so the angler stood in front of the shed while
## standing behind it. Godot's own y-sorting would want every one of these on one layer with
## its own origin at its feet, which the polygons and the drawn scatter are not.
##
## So the walkers are sorted by hand, and only against the two things they can actually go
## behind: the hut and the crate. Three bands, because there are two obstacles at different
## depths — behind both, between them, and in front of both — and the layers of the hut and
## the crate were spread apart to leave room for the middle one.
func _sort_walkers() -> void:
	if _angler != null:
		_angler.z_index = _walker_layer(_angler.position)
	if _dog != null:
		_dog.z_index = _walker_layer(_dog.position)


## The layer for something standing here. See `_sort_walkers`.
##
## Demoted only by an obstacle it is actually behind rather than by depth alone: the dog
## swims out into the top half of the lake, which is north of the hut and nowhere near it,
## and a rule that read depth on its own put the animal underneath the floating rubbish.
func _walker_layer(at: Vector2) -> int:
	var shed := Iso.tile_to_world(Iso.shed_centre().x, Iso.shed_centre().y)
	# Behind the hut means north of **both** its near faces and inside the width of the
	# picture — the crate's rule, for the same two reasons it has it.
	#
	# A flat line across the near corner put somebody standing beside the hut, level with its
	# left corner, behind a wall that was nowhere near them. And the sideways limit has to be
	# the drawing's width rather than the footprint's: the roof overhangs the walls it stands
	# on, so a walker north of the hut and out past the footprint's corner was still covered
	# by the picture and was being drawn over it — the angler clipping through the shed.
	var shed_off := Iso.world_to_tile(at - shed)
	if shed_off.x < Iso.SHED_FOOT.x and shed_off.y < Iso.SHED_FOOT.y 			and absf(at.x - shed.x) < _shed_drawn_wide() * 0.5 			and at.y < _shed_front() - SHED_BEHIND_SLACK:
		return BEHIND_SHED
	# Behind the crate means north of both near faces, not north of its bottom point: those
	# faces slope up from that point, and a flat line there put somebody standing just south
	# of a face behind the planks. The footprint is square in tile space, so the faces are
	# the two tile axes.
	var off := Iso.world_to_tile(at - _yard.position)
	if off.x < Yard.FOOT_HALF and off.y < Yard.FOOT_HALF \
			and absf(at.x - _yard.position.x) < Yard.CRATE.x * 0.5:
		return BEHIND_CRATE
	return IN_FRONT


## How wide the hut's picture is drawn, in world pixels — the roof, not the walls' feet.
## Falls back to the footprint's own width on screen when there is no picture.
func _shed_drawn_wide() -> float:
	if _shed_art == null:
		return (Iso.SHED_FOOT.x + Iso.SHED_FOOT.y) * Iso.TILE_W
	return _shed_art.get_size().x * (Iso.SHED_TALL / _shed_art.get_size().y)


## The world y of the near edge of the shed's footprint.
##
## The footprint is a rectangle in tile space and the screen runs down `x + y`, so its nearest
## point is its near corner: both half-extents past the middle. It was an ellipse, where the
## answer was `sqrt(a² + b²)` instead — keep this in step with `Iso.in_shed`, because a third
## of a tile here is the difference between standing behind the hut and standing through it.
func _shed_front() -> float:
	var mid := Iso.shed_centre()
	var reach := Iso.SHED_FOOT.x + Iso.SHED_FOOT.y
	return (mid.x + mid.y + reach) * Iso.TILE_H * 0.5


## Where the view wants to be: the angler, drawn out towards the net while one is in the
## water.
##
## The net's tile position rather than its drawn one, which rides the swell — a camera that
## bobs with the water is a camera nobody asked for.
func _watching() -> Vector2:
	if _cast_look <= 0.001:
		return _angler.position + _pan
	return _angler.position.lerp(
		Iso.tile_to_world(_net.tile_pos.x, _net.tile_pos.y), _cast_look
	) + _pan


## Keep the camera over the ground.
##
## Not over the lake, as it used to be: the window is cleared to grey, the ground stops at
## `Ground.OUTER_OUT` tiles past the waterline, and anything past that is grey. So what is
## clamped is not where the camera stands but what it can see — the whole visible rectangle
## is kept inside the ground, and the camera is only allowed as far as that leaves it.
##
## When the view is wider than the ground itself — which it can be at the far end of the
## zoom on a wide window — there is no position that hides the edge, so it sits in the middle
## and shows the same amount on both sides rather than all of it down one.
##
## The box below only bounds the view inside the ring's own bounding rectangle, and the ring
## is an ellipse: it falls well short of that rectangle's corners the same way a circle falls
## short of the square drawn around it. A window box-clamped this way still shows its own
## four corners past the last tree, so `_pulled_to_forest` checks those corners directly,
## against the ground itself, and pulls the camera the rest of the way in if the box was not
## enough.
func _clamped_view(at: Vector2) -> Vector2:
	var ground := Iso.basin_extent(Ground.OUTER_OUT) * 0.5
	var middle := Iso.tile_to_world(Iso.CENTRE.x, Iso.CENTRE.y)
	var half := get_viewport_rect().size / _camera.zoom * 0.5
	var room := (ground - half) / DRAG_PULL
	var boxed := Vector2(
		middle.x + clampf(at.x - middle.x, -maxf(room.x, 0.0), maxf(room.x, 0.0)),
		middle.y + clampf(at.y - middle.y, -maxf(room.y, 0.0), maxf(room.y, 0.0))
	)
	return _pulled_to_forest(boxed, middle, half)


## How many tiles of forest a screen corner has to have solidly under it, short of
## `Ground.OUTER_OUT` where the ground itself runs out. Past `Ground.WOOD_FULL` (19), so a
## corner pulled in to clear this is a corner sitting in full canopy, not on the bare last row
## of sand.
const CORNER_MARGIN := 4.0


## How far out of the water the furthest of the view's four actual corners is, in tiles.
## `_clamped_view`'s box only ever checks the view's edges against the ring's bounding box;
## this checks the corners themselves against the ground, which is the shape that is actually
## drawn.
func _worst_corner_out(pos: Vector2, half: Vector2) -> float:
	var worst := -INF
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner := pos + Vector2(half.x * sx, half.y * sy)
			var tile := Iso.world_to_tile(corner)
			worst = maxf(worst, Ground.out_of_water(tile.x, tile.y))
	return worst


## Pulls `pos` straight back towards `middle` until all four corners of a `half`-sized view
## centred there have forest under them.
##
## A straight-line pull rather than an independent one per axis: a corner is the combination
## of both, and pulling only the axis that offended it would let the other one drift back out
## as soon as this ran again. Bisected rather than solved, because the boundary it is aiming
## at is the wobbly, elliptical one `Ground.out_of_water` actually draws, not a shape with a
## closed-form edge.
func _pulled_to_forest(pos: Vector2, middle: Vector2, half: Vector2) -> Vector2:
	var limit := Ground.OUTER_OUT - CORNER_MARGIN
	if _worst_corner_out(pos, half) <= limit:
		return pos
	var lo := 0.0
	var hi := 1.0
	for _i in 12:
		var mid := (lo + hi) * 0.5
		if _worst_corner_out(middle.lerp(pos, mid), half) <= limit:
			lo = mid
		else:
			hi = mid
	return middle.lerp(pos, lo)


func _visible_world_rect() -> Rect2:
	# In world units, so the cull matches what the camera can actually see rather than
	# what a zoom of 1 would have shown.
	var size := get_viewport_rect().size / _camera.zoom
	return Rect2(_camera.global_position - size * 0.5, size)


## Rebuild the filth map if something has left the lake since the last one, and no more
## often than FILTH_REMAP.
func _remap_filth(delta: float) -> void:
	_filth_remap_in -= delta
	if not _filth_stale or _filth_remap_in > 0.0:
		return
	_filth_stale = false
	_filth_remap_in = FILTH_REMAP
	_build_filth_map()


## The filth map: how foul the water is on each tile of the basin, spread out into the water
## around each piece, one texel per tile for the water shader to read.
##
## This is what makes cleaning visible. The meter at the top of the screen is the whole lake
## averaged, and averages are the enemy of feedback: five casts that clear the water in front
## of the player move it by a percent, and the water in front of the player is what they are
## looking at. With the map, that water goes blue while the next bay is still soup.
##
## Built whole rather than patched where a cast landed: it is a distance map, and taking a
## piece out moves the nearest-piece distance of everything round it. One sweep of a grid
## the size of a postage stamp is cheaper than the bookkeeping.
func _build_filth_map() -> void:
	var cols := Iso.COLS
	var rows := Iso.ROWS
	var far := float(FILTH_BLUR + 1)
	var dist := PackedFloat32Array()
	dist.resize(cols * rows)
	dist.fill(far)
	# The sources: every tile with a piece floating on it. Not the dry ones — litter on the
	# beach is not in the water.
	for index in _grid.stacks.size():
		if _grid.stacks[index].is_empty():
			continue
		if index < _grid.dry.size() and _grid.dry[index] == 1:
			continue
		dist[index] = 0.0
	_chamfer(dist, cols, rows)

	var pixels := PackedByteArray()
	pixels.resize(cols * rows)
	for i in dist.size():
		var near := clampf(1.0 - dist[i] / float(FILTH_BLUR), 0.0, 1.0)
		pixels[i] = int(round(pow(near, FILTH_FALL) * 255.0))

	# The grid keeps a copy for what it draws on the CPU — the ripple rings read the state
	# of the water under their piece off it, the way the shader does off the texture.
	_grid.filth = pixels

	if _filth_map == null:
		_filth_map = Image.create_from_data(cols, rows, false, Image.FORMAT_R8, pixels)
		_filth_texture = ImageTexture.create_from_image(_filth_map)
	else:
		_filth_map.set_data(cols, rows, false, Image.FORMAT_R8, pixels)
		_filth_texture.update(_filth_map)

	if _water_material != null:
		_water_material.set_shader_parameter(&"filth_map", _filth_texture)
		_water_material.set_shader_parameter(&"filth_tiles", Vector2(cols, rows))
		_water_material.set_shader_parameter(&"filth_mapped", 1.0)


## Distance from every tile to the nearest source, in tiles, in place: `dist` comes in as 0
## on the sources and something big everywhere else, and goes out as the distance. Two
## sweeps of the grid, forwards then back, each cell taking the least of its already-swept
## neighbours plus the step to them — a chamfer transform, which is the distance to within
## a few per cent and costs eight looks a tile rather than a search.
func _chamfer(dist: PackedFloat32Array, cols: int, rows: int) -> void:
	const SIDE := 1.0
	const CORNER := 1.4142
	for ty in rows:
		for tx in cols:
			var i := ty * cols + tx
			var d := dist[i]
			if tx > 0:
				d = minf(d, dist[i - 1] + SIDE)
			if ty > 0:
				d = minf(d, dist[i - cols] + SIDE)
				if tx > 0:
					d = minf(d, dist[i - cols - 1] + CORNER)
				if tx < cols - 1:
					d = minf(d, dist[i - cols + 1] + CORNER)
			dist[i] = d
	for ty in range(rows - 1, -1, -1):
		for tx in range(cols - 1, -1, -1):
			var i := ty * cols + tx
			var d := dist[i]
			if tx < cols - 1:
				d = minf(d, dist[i + 1] + SIDE)
			if ty < rows - 1:
				d = minf(d, dist[i + cols] + SIDE)
				if tx < cols - 1:
					d = minf(d, dist[i + cols + 1] + CORNER)
				if tx > 0:
					d = minf(d, dist[i + cols - 1] + CORNER)
			dist[i] = d


## The lake clearing up is the progress bar, so the shader gets the meter directly rather
## than a colour picked per state.
func _push_water_colours() -> void:
	if _water_material == null:
		return
	# Bent, not passed straight through. The lake's filth reads as a straight line down and
	# the first half of a clean-up is the half nobody sees: a hundred casts in, the number
	# has moved and the water has barely changed. Rooting it holds the muck up through the
	# first half and then lets it go all at once, so the back half of the job is the part
	# that visibly pays.
	var shown := pow(pollution, FILTH_BITE)
	_water_material.set_shader_parameter(&"pollution", shown)
	_sparkle_at = move_toward(
		_sparkle_at, 1.0 if _cleaned else 0.0, SPARKLE_RISE * get_process_delta_time()
	)
	_water_material.set_shader_parameter(&"sparkle", _sparkle_at)


func _update_hud() -> void:
	_skin.pollution = pollution
	_skin.money = sludge
	_skin.stock = _yard.held.size()
	var affordable := _affordable()
	_skin.available = affordable
	# And on the shed's copy of the same button, which is the only one on screen while the
	# player is inside.
	_open_upgrades.note = "%d available" % affordable
	_skin.hint = _last_pieces_line()

	if not _menu_open:
		return
	_shop_skin.rows = _shop_rows()

	_buy_net_width.text = "Net width %d  —  %d tiles  (%d)" % [
		net_width_level, _tiles_in_radius(net_radius()), roundi(cost_of(&"net_width"))
	]
	_buy_net_strength.text = "Net strength %d  —  lifts tier %d  (%d)" % [
		net_strength_level, net_power(), roundi(cost_of(&"net_strength"))
	]
	_buy_net_range.text = "Cast range %d  —  %.1f tiles  (%d)" % [
		net_range_level, net_range(), roundi(cost_of(&"net_range"))
	]
	_buy_reel.text = "Line speed %d  —  %.1f tiles/s  (%d)" % [
		reel_level, reel_speed(), roundi(cost_of(&"reel"))
	]
	_buy_net_hold.text = "Net haul %d  —  %d per cast  (%d)" % [
		net_hold_level, net_hold(), roundi(cost_of(&"net_hold"))
	]
	for pair: Array in [
		[_buy_net_width, &"net_width"], [_buy_net_strength, &"net_strength"],
		[_buy_net_range, &"net_range"], [_buy_reel, &"reel"],
		[_buy_net_hold, &"net_hold"],
		[_buy_boat_speed, &"boat_speed"], [_buy_cargo, &"cargo"],
		[_buy_skimmer, &"skimmer"], [_buy_fleet, &"fleet"]
	]:
		var key: StringName = pair[1]
		(pair[0] as Button).disabled = is_maxed(key) or sludge < cost_of(key)

	_buy_boat_speed.text = "Ferry speed %d  —  %.1f tiles/s  (%d)" % [
		boat_speed_level, boat_speed(), roundi(cost_of(&"boat_speed"))
	]
	_buy_cargo.text = "Ferry hold %d  —  carries %d  (%d)" % [
		cargo_level, boat_cargo(), roundi(cost_of(&"cargo"))
	]
	_buy_skimmer.text = "Skimmer %d  —  %s  (%d)" % [
		skimmer_level,
		"not fitted" if skim_radius() < 0
			else "%d tiles, %d deep, tier %d, %d%% of what it passes, %d items" % [
				_tiles_in_radius(skim_radius()), skim_depth(), skim_power(),
				roundi(skim_chance() * 100.0), skim_hold()
			],
		roundi(cost_of(&"skimmer"))
	]
	if fleet_size() < MAX_BOATS:
		_buy_fleet.text = "Extra ferry %d  —  %d in the water  (%d)" % [
			fleet_level, fleet_size(), roundi(cost_of(&"fleet"))
		]
	else:
		_buy_fleet.text = "Extra ferry %d  —  %d ferries is the whole fleet" % [
			fleet_level, fleet_size()
		]
	_open_shed.text = "Decorate the shed  —  %d found, %d out" % [
		unlocked.size(), decor.size()
	]
	_send_now.disabled = not _any_boat_docked() or _yard.held.is_empty()



## The one thing a filth meter cannot say: how much is left when the answer is "nearly
## nothing".
##
## The meter is weighted by how dirty a piece is, so the last hundred cups read as an empty
## bar, and a player looking at an empty bar and no ending has been told the lake is clean
## by the only thing in the game that tells them anything. This is what says otherwise —
## and it only appears once the bar is on the floor, so it is never noise.
func _last_pieces_line() -> String:
	if _cleaned or _left_over <= 0:
		return ""
	if _left_over == 1:
		return "One last piece is still out there"
	return "%d pieces still out there" % _left_over


## The fleet in one line: the lone ferry reads as it always did, and a fleet reads as a
## count of what is out rather than a wall of per-boat status.
func _fleet_line() -> String:
	if _boats.size() == 1:
		var only := _boats[0]
		return "Ferry: %s    %d / %d aboard" % [
			only.status_line(), only.cargo.size(), only.capacity
		]
	var out := 0
	var aboard := 0
	for boat in _boats:
		if boat.is_running():
			out += 1
		aboard += boat.cargo.size()
	return "Ferries: %d of %d out    %d aboard" % [out, _boats.size(), aboard]


func _runs_done() -> int:
	var total := 0
	for boat in _boats:
		total += boat.runs_done
	return total


func _any_boat_docked() -> bool:
	for boat in _boats:
		if not boat.is_running():
			return true
	return false


## Everything a run is, written to one file.
##
## The lake is not stored — it is the same basin from the same seed every time — but the
## stacks are, because what has been pulled out of them is the progress. A ferry out on
## the water is saved as its cargo and nothing else: reconstructing a half-finished lap
## down to its waypoints would be a lot of file for a boat that can simply set off again.
func save_game() -> bool:
	_autosave_in = AUTOSAVE_EVERY
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		_note_save("could not write the save")
		return false

	var afloat := PackedInt32Array()
	for boat in _boats:
		afloat.append_array(boat.cargo)

	var save := {
		"version": SAVE_VERSION,
		"seed": _level_seed(),
		"level": level_name(),
		"sludge": sludge,
		"levels": {
			"net_width": net_width_level, "net_strength": net_strength_level,
			"net_range": net_range_level, "reel": reel_level,
			"net_hold": net_hold_level,
			"boat_speed": boat_speed_level, "cargo": cargo_level,
			"skimmer": skimmer_level, "fleet": fleet_level,
			"dog_fetch": dog_fetch_level, "dog_wait": dog_wait_level,
		},
		"caught": caught,
		"sold_count": sold_count,
		"birds_caught": birds_caught,
		"sold_by_kind": sold_by_kind,
		"runs_done": _runs_done(),
		"auto_ferry": _auto_ferry.button_pressed,
		"fullscreen": _is_fullscreen(),
		"music": _settings.music_on,
		"music_level": _settings.music_level,
		"farewell": _farewell_shown,
		"sfx": _settings.sfx_on,
		"sfx_level": _settings.sfx_level,
		"angler": _angler.tile_pos,
		"yard_held": _yard.held,
		"unlocked": unlocked,
		"decor": decor,
		"afloat": afloat,
		"stacks": _grid.stacks,
	}
	_save_extra(save)
	file.store_var(save, true)
	file.close()
	_note_save("saved")
	return true


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


## Read a run back. Anything wrong with the file — missing, from another lake, from an
## older layout — leaves the fresh game alone rather than half-applying itself.
func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return false
	var raw: Variant = file.get_var(true)
	file.close()
	var save := raw as Dictionary
	var written := 0 if save == null else int(save.get("version", 0))
	if save == null or written != SAVE_VERSION 			or int(save.get("seed", 0)) != _level_seed():
		_note_save("the save is from another build — ignored")
		return false
	if not _grid.restore(save.get("stacks", []) as Array):
		_note_save("the save does not fit this lake — ignored")
		return false

	# Held to the caps on the way in. A save written before a track had a top level can
	# carry a number the shop no longer sells, and every number in the game is read off
	# these fields.
	var levels := save.get("levels", {}) as Dictionary
	net_width_level = _saved_level(levels, &"net_width")
	net_strength_level = _saved_level(levels, &"net_strength")
	net_range_level = _saved_level(levels, &"net_range")
	reel_level = _saved_level(levels, &"reel")
	net_hold_level = _saved_level(levels, &"net_hold")
	boat_speed_level = _saved_level(levels, &"boat_speed")
	cargo_level = _saved_level(levels, &"cargo")
	skimmer_level = _saved_level(levels, &"skimmer")
	dog_fetch_level = _saved_level(levels, &"dog_fetch")
	dog_wait_level = _saved_level(levels, &"dog_wait")

	sludge = float(save.get("sludge", 0.0))
	caught = int(save.get("caught", 0))
	sold_count = int(save.get("sold_count", 0))
	birds_caught = int(save.get("birds_caught", 0))
	sold_by_kind = PackedInt32Array(save.get("sold_by_kind", PackedInt32Array([0, 0, 0, 0])))

	# Finds and where they were put. Anything the catalogue no longer knows is dropped:
	# re-cutting the sheets renames pieces, and that must not take a save down with it.
	unlocked.clear()
	for name: String in save.get("unlocked", []) as Array:
		# And anything the game no longer offers is dropped too: a save written while the
		# nameless offcuts were still findable holds them, and a shelf with an unnameable
		# thing on it is worse than a shelf with a gap.
		if _pretty(name).is_empty():
			continue
		if _sheets == null or _sheets.has(StringName(name)):
			unlocked.append(name)
	decor.clear()
	for row: Dictionary in save.get("decor", []) as Array:
		var name := String(row.get("piece", ""))
		if not unlocked.has(name):
			continue
		decor.append({
			"piece": name,
			"cell": [int((row["cell"] as Array)[0]), int((row["cell"] as Array)[1])],
			# Which way round it was left standing, and whether its fire was lit. A piece
			# with one face reads as 0 whatever is in the file. See ShedRoom._row_view.
			"view": int(row.get("view", 0)),
		})

	# The fleet is rebuilt to the size that was bought, and every hull comes home empty:
	# whatever was aboard goes back on the pile it was loaded from, so nothing is quietly
	# thrown away by saving mid-run.
	_yard.held = PackedInt32Array(save.get("yard_held", PackedInt32Array()))
	var wanted := _saved_level(levels, &"fleet")
	while fleet_level < wanted:
		fleet_level += 1
		_add_boat()
	for boat in _boats:
		boat.cargo.resize(0)
		boat.state = Boat.State.DOCKED
		boat.target = -1
		boat.tile_pos = boat.dock
		boat.runs_done = 0
	_boats[0].runs_done = int(save.get("runs_done", 0))
	for piece: int in PackedInt32Array(save.get("afloat", PackedInt32Array())):
		_yard.put(piece)

	_settings.fullscreen = bool(save.get("fullscreen", _is_fullscreen()))
	_set_fullscreen(_settings.fullscreen)
	_settings.music_level = clampf(float(save.get("music_level", _settings.music_level)), 0.0, 1.0)
	_settings.music_on = bool(save.get("music", true))
	_push_music()
	# A lake that was finished before the game was closed is finished when it comes back,
	# and lit that way from the first frame rather than brightening as if it had just
	# happened. The thanks are not repeated: they were earned once.
	_farewell_shown = bool(save.get("farewell", false))
	# An empty lake and a finished run are two different facts, and loading one must not
	# assert the other. `_cleaned` is the flag that says the ending has been dealt with, so
	# setting it from the piece count alone swallowed the ending of every run that was saved
	# on its last catch and reopened: the words were owed, the flag said they were not, and
	# the game sat there with an empty meter and nothing to say.
	#
	# The lit water is the part that really is about the piece count, so it is read from
	# that directly rather than through the flag.
	var empty := _grid.piece_count() == 0
	# Never carried in from the file. `_cleaned` means "the ending has been dealt with in
	# this sitting", and a sitting that has just started has dealt with nothing — so a
	# finished lake is worked out again from the field a frame later, and says so again.
	_cleaned = false
	_sparkle_at = 1.0 if empty else 0.0
	_settings.sfx_level = clampf(float(save.get("sfx_level", _settings.sfx_level)), 0.0, 1.0)
	_settings.sfx_on = bool(save.get("sfx", true))
	_push_sfx()
	if _room != null:
		_room.unlocked = unlocked
		_room.decor = decor
	_auto_ferry.button_pressed = bool(save.get("auto_ferry", true))
	_set_auto_ferry(_auto_ferry.button_pressed)
	_angler.stand_at(save.get("angler", _angler.tile_pos) as Vector2)
	if _trophy != null:
		_trophy.clear()
	_net.set_pulling(false)
	_net.state = CastNet.State.IDLE
	_net.catch.resize(0)
	_push_net_numbers()
	_net.tile_pos = _angler.tile_pos
	_push_boat_numbers()
	_push_dog_numbers()

	# The meter is re-read from the field rather than stored: it is a fraction of a total
	# that the build already worked out, and the field is the truth.
	_filth_left = _grid.filth_left()
	pollution = clampf(_filth_left / _filth_total, 0.0, 1.0)
	_filth_stale = true
	_camera.position = Iso.tile_to_world(_angler.tile_pos.x, _angler.tile_pos.y)
	_load_extra(save)
	_note_save("loaded")
	return true


## Throw the save away and start the lake again. The scene is reloaded rather than reset
## in place: a fresh run is exactly what the first frame of the game already builds.
func wipe_save() -> void:
	_wiping = true
	if has_save():
		# The engine's own path, not a globalized one: on the web there is no such thing as
		# an absolute path to a save, and user:// is understood everywhere.
		DirAccess.remove_absolute(save_path)
	get_tree().reload_current_scene()


func _note_save(what: String) -> void:
	_save_note = what
	_save_note_for = 2.5


func _notification(what: int) -> void:
	# Closing the window is the commonest way a session ends, and losing the last twenty
	# seconds of it to the autosave timer is the kind of thing that makes a save feel
	# untrustworthy. A wipe is the one exit that must not write anything back.
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not _wiping and _grid != null:
		save_game()


## What each of the four merchants has taken, as one line. The four yards only read as
## four choices if the player can see they are being used unevenly.
func _sold_tally() -> String:
	var parts := PackedStringArray()
	for kind in TrashDef.KIND_NAMES.size():
		parts.append("%s %d" % [TrashDef.KIND_NAMES[kind], sold_by_kind[kind]])
	return "  ".join(parts)


## Tiles in a diamond of this radius. Shown in the shop, because "radius 3" means nothing
## and "25 tiles" is the thing being bought.
## How many tiles a cast of this radius covers. Counted rather than derived: the sweep takes
## every tile centre inside a circle, and there is no closed form for how many of those
## there are at a fractional radius.
func _tiles_in_radius(radius: float) -> int:
	var count := 0
	var span := int(ceil(radius))
	for dy in range(-span, span + 1):
		for dx in range(-span, span + 1):
			if float(dx * dx + dy * dy) <= radius * radius:
				count += 1
	return count


## The hut's picture, and the roll its grass comes off. A fixed seed: the same hut grows the
## same grass every time the game is opened.
##
## There used to be a soft black quad under the hut here as well — a contact patch, so the
## hut had something to stand on. Gone, by decision (2026-09-12): the grass along the bottom
## line is what says the hut meets the ground now, and a dark pool under a skirt of blades
## read as two shadows.
const SHED_ART := "res://assets/shed.png"
const SHED_SEED := 4477

## The doorway across the hut's picture, as fractions of its width, kept clear of grass.
##
## Measured off `assets/shed.png`: the door panel on the front-left wall runs columns 30 to
## 47 of 130, and a blade of the hem's full height reaches its bottom board. A door with
## grass growing across it is a door nobody has opened, and this is the one the player walks
## through several times a run — so the threshold is trodden bare. Re-measure with the hut.
const SHED_DOOR := Vector2(0.22, 0.37)

## Where the hut's picture is laid and where the building stands inside it both live in `Iso`
## now (`SHED_STAND`, `SHED_ART_GROUND`, `shed_centre`), because the walkers need them too:
## the walls' feet are an isometric diamond and the art's last row is that diamond's **near
## corner**, not its middle, so the building stands about two thirds of a tile north of where
## the picture bottoms out. Drawing off one number and colliding off another is what put the
## footprint off the hut. Re-measure `SHED_ART_GROUND` if the hut is re-cut
## (`tools/slice_shed.gd`): it is the diamond's side corners, rows 93 and 103 of 127, as a
## fraction of the picture's height up from the bottom.


## The shed, and the prompt over it when the angler is close enough to use it.
##
## The same hut that is drawn on the shed button, cut out of it by tools/slice_shed.gd. One
## picture for the thing and the button that opens it: the player learns what the button
## means by having walked up to it.
func _draw_shed() -> void:
	var at := Iso.tile_to_world(Iso.ISLAND_CENTRE.x, Iso.ISLAND_CENTRE.y)
	# Where the bottom row of the picture is laid, and where inside the picture the walls
	# actually stand. Everything cast from the hut hangs off the second one.
	var feet := _shed_feet()
	var stand := feet + Vector2(0.0, Iso.SHED_TALL * Iso.SHED_ART_GROUND)

	if _shed_art != null:
		# Standing on the footprint rather than centred on it: the middle of the picture is
		# halfway up a wall.
		var size := _shed_art.get_size() * (Iso.SHED_TALL / _shed_art.get_size().y)
		# The hut's shadow: its own picture again, laid across the grass away from the sun.
		# A building is the biggest thing on the island and the one whose shadow says most
		# about where the light is coming from, so it swings with the rest of the land.
		#
		# Rooted where the building stands, not at the bottom of the picture — the art's last
		# row is the near corner of the diamond its walls stand on, and a shadow pinned there
		# began a good way down the grass in front of the building it belonged to.
		if _day != null:
			_island.draw_set_transform_matrix(
				Shade.lying(feet, _day.lean, _day.stretch)
			)
			# The picture, in the shadow's own space: as far above the root as the walls
			# stand above their feet in the art.
			_island.draw_texture_rect(
				_shed_art,
				Rect2(
					Vector2(-size.x * 0.5, -size.y * (1.0 - Iso.SHED_ART_GROUND)), size
				),
				false,
				Shade.tint(_day.ink)
			)
			_island.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_island.draw_texture_rect(
			_shed_art, Rect2(stand - Vector2(size.x * 0.5, size.y), size), false
		)
		# And the grass over the bottom line, which is the whole point of it: the last row
		# of the picture is a straight cut, and blades standing along it are what stop the
		# hut reading as a sticker on the lawn.
		_shed_grass(Rect2(stand - Vector2(size.x * 0.5, size.y), size)).over(_island)
		# Over the hut, not over the tile: the two are not the same point.
		_draw_shed_lamp(feet)
		return

	_draw_shed_blocked(at)


## The hut's grass, baked once off the hut's own silhouette. The island redraws every frame,
## so this cannot be a few hundred `draw_rect` calls — it is one triangle array and one draw
## call, built the first time the hut is drawn and kept.
func _shed_grass(box: Rect2) -> Skirt.Patch:
	if _shed_skirt == null:
		_shed_skirt = Skirt.hem(
			Art.image(SHED_ART), box, SHED_SEED, PackedVector2Array([SHED_DOOR])
		)
	return _shed_skirt


## Where the hut stands, in world pixels: the middle of the diamond its walls' feet make, and
## the same point the walking rule keeps everyone out of (`Iso.shed_centre`). The shadow and
## the grass hang off it. With no picture there is nothing standing, so the blocked-in hut
## uses the tile it is drawn on.
func _shed_feet() -> Vector2:
	if _shed_art == null:
		return Iso.tile_to_world(Iso.ISLAND_CENTRE.x, Iso.ISLAND_CENTRE.y)
	var mid := Iso.shed_centre()
	return Iso.tile_to_world(mid.x, mid.y)


## The hut as it was blocked in before there was a picture of it. Kept for the same reason
## every other placeholder here is: the art can be missing.
func _draw_shed_blocked(at: Vector2) -> void:
	var ink := Color(0.11, 0.09, 0.1)
	var wall := PackedVector2Array([
		at + Vector2(-30.0, -6.0), at + Vector2(0.0, 9.0),
		at + Vector2(30.0, -6.0), at + Vector2(30.0, -30.0),
		at + Vector2(0.0, -15.0), at + Vector2(-30.0, -30.0)
	])
	_island.draw_colored_polygon(wall, Color(0.60, 0.44, 0.30))
	var roof := PackedVector2Array([
		at + Vector2(-34.0, -32.0), at + Vector2(0.0, -15.0),
		at + Vector2(34.0, -32.0), at + Vector2(0.0, -50.0)
	])
	_island.draw_colored_polygon(roof, Color(0.44, 0.29, 0.24))
	for shape: PackedVector2Array in [wall, roof]:
		var closed := shape.duplicate()
		closed.append(shape[0])
		_island.draw_polyline(closed, ink, 1.6)

	# The door, so "this is a building you go into" is legible at a glance.
	_island.draw_colored_polygon(
		PackedVector2Array([
			at + Vector2(-9.0, -6.0), at + Vector2(0.0, -1.0),
			at + Vector2(0.0, -20.0), at + Vector2(-9.0, -25.0)
		]),
		Color(0.22, 0.17, 0.14)
	)

	_draw_shed_lamp(at)


## A lamp over the door when the shed can be used. Cheaper to read than a floating label,
## and it does not need a font at four different zoom levels.
func _draw_shed_lamp(at: Vector2) -> void:
	if not _at_shed() or _menu_open:
		return
	var over := at + Vector2(0.0, -Iso.SHED_TALL - 10.0)
	_island.draw_circle(over, 7.0, Color(1.0, 0.92, 0.62, 0.9))
	_island.draw_circle(over, 12.0, Color(1.0, 0.92, 0.62, 0.25))
