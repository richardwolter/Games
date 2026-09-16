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
## `tools/test_lake.gd` checks the two ends of the zoom against `MAX_ZOOM` and `_fit_zoom` —
## rather than keeping its own copy of them, which is the sort of copy that goes stale
## without anything failing.
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
##
## The near end came in from 1.8 (2026-09-13, Richard's call): on a 1080p window that is
## four screen pixels to an art pixel rather than five. The far end is the whole lake
## again, on the same call: it was held in past that by `ZOOM_OUT_PULL` (1.68, the
## argument being that a view of the whole basin is a map, not a game), which on 1080p
## stopped the wheel a level short with the lake wider than the window. The levels on a
## 1080p window are thirds, so there was no "a little further" to give — the next level
## out is the one that fits the lake.
const MIN_ZOOM := 0.22
const MAX_ZOOM := 1.5

## How much room is left round the lake at that far end, as a fraction of the basin. A
## shoreline drawn hard against the edge of the window reads as cropped.
const ZOOM_FIT_MARGIN := 0.04

## How much bank the far end of the zoom shows past the waterline, in tiles.
##
## The lake and the four piers on it, and nothing else worth pulling back for. A pier's
## platform stands two tiles back from the waterline with the recycle box on it (see
## tools/build_piers.py), so this is that plus enough air to keep it off the edge of the
## window.
##
## It has been further out. Thirteen tiles showed the wood behind the bank, which sounded
## like more of the place and read as a lake going away from you — the boats got small, the
## piers got small, and the thing the player is actually doing sat in the middle of a lot of
## scenery.
const ZOOM_OUT_TILES := 4.0

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
## Per wheel notch. The wheel moves one zoom stop per notch whatever this is; it only says
## which way (and `_zoom_by` lets a bigger factor jump further).
const ZOOM_STEP := 1.12

## Levels at least this far apart (in zoom) get a half level between the far end and the
## next one in, see `_zoom_stops`. A third: the levels on a 1080p window, and on anything
## coarser. At 1440p they are quarters and need no extra stop.
const HALF_STOP_GAP := 1.0 / 3.0

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
## arrives back where it started as the haul finishes (or a little after it, on a haul
## faster than `HOME_SPEED` lets the view travel).
const CAST_LOOK := 0.45
const LOOK_SPEED := 3.4

## How far in from the window's edges the net has to be when it comes down on the water, as
## a fraction of the view's half-width and half-height. `CAST_LOOK` puts the view most of
## the way out to the net but not all of it, and on a long cast most of the way is not
## far enough: the net lands on the edge of the window or past it. So the view is pulled the
## rest of the way out — only as far as it needs to be, and only ever towards the net — until
## the whole mouth sits inside this margin. Framed, not centred: the angler's share of the
## screen is kept wherever there is room to keep it.
##
## Measured against where the net will land while it flies, so the view is on its way to
## the landing from the throw rather than chasing the net there and arriving late — taken
## up over the first `FRAME_BY` of the flight rather than all at once, or the view jumped
## a hundred pixels on the frame of the click. The rest of the flight is for the follow
## to close on it, and the flying net itself pushes the view the last of the way if it
## has not (see `_process`): a short throw is over before the ease has done much.
const LAND_INSET := 0.25
const FRAME_BY := 0.6

## The most the view may travel on the way home, in world pixels a second.
##
## The view follows a point that is `CAST_LOOK` of the way out to the net, and on the haul
## that point comes home at `CAST_LOOK` of the reel speed — so a reel upgrade was a camera
## upgrade, and at the top of the track the view whipped home at several screens a second.
## What was bought was a faster net. Capped, the view pans home at a walking pace whatever
## the net is doing, and a net that beats it home is waited for.
##
## The way home only. The throw is faster than any reel by design (`CastNet.CAST_SPEED`),
## and a view that lagged the flying net would land it further off the middle of the
## screen, which is the opposite of what `LAND_INSET` is for.
##
## A ceiling, not the speed of the return: under it the view still follows the net at the
## net's own pace, so at a slow reel it stays between the angler and the net as it always
## did rather than going home ahead of the net and leaving it to come in from the edge.
## World pixels, so zooming out slows it on screen — the whole lake fits the window at the
## far end of the wheel and there is nothing there to pan across.
const HOME_SPEED := 260.0

## With a pad aiming, how far in from the window's edges the angler is kept while the view
## leans out towards the reticle, as a fraction of the half-view. The angler wins: past this
## the view stops leaning and the reticle is pushed along by the window's edge instead
## (`_pad_framed`, `PadAim.hold_in`).
const PAD_ANGLER_INSET := 0.15

## How far the middle button may move while held and still count as a tap rather than a
## drag, in screen pixels. A tap recentres the view on the angler.
const PAN_TAP := 4.0

## The button the view is dragged with. Not a bound verb: a drag is a gesture, not something
## the player asks for once, and `recentre` is the verb the bind board moves.
const PAN_BUTTON := MOUSE_BUTTON_MIDDLE

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

## The clean patch a catch opens (2026-09-13, Richard: "a glimpse of the cleaned lake
## before the grime sets in again"). The map only ever says where the junk is, and most
## casts lift the top piece off a stack that still has junk under it, so most casts moved
## no water at all — the catch had no answer in the lake. Now every sweep that takes
## something opens a patch of clean water at the mouth that the grime closes back over.
##
## A transient lie, by decision — the one exception to "water touching objects looks
## grimy". Its end state is always the map's own value, so an honest clear is revealed
## under the shrinking patch rather than replaced by it. Nets only: the dog and the ferry
## leave the water alone. Not saved.
##
## Sized to the catch: the mouth itself, plus PATCH_REACH tiles more for a full hold, in
## proportion for less. Opens over PATCH_IN seconds (the grime drawing apart, the closing
## run backwards), holds whole for PATCH_HOLD of PATCH_LIFE, then closes over the rest —
## slowly, by Richard's call (2026-09-13: "appear and disappear more slowly"; the first
## cut snapped open and was gone in 2 s). PATCHES is the shader's cap; past it the oldest
## is replaced.
const PATCHES := 14
const PATCH_LIFE := 2.0
const PATCH_IN := 0.2
const PATCH_HOLD := 0.1
const PATCH_REACH := 0.5
## The patch's shape is a blob noise rolled per catch (`_patch_rng`): the rim wanders in and
## out of the mouth's disc and the grime comes back as spots that grow and join, so no two
## catches look alike and nothing reads as the net's ring stamped on the water. The
## shape's knobs are the shader's (`patch_blotch`, `patch_shape`, `patch_top`, `patch_soft`).



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

## The finds float smaller than the rubbish (Richard, 2026-09-13: "objects floating on
## lake too big, scale down 1.2x" — the decorations only, not every piece of rubbish).
## Divides SPRITE_SCALE and SPRITE_LARGEST for a keepsake def, so a find draws at 1.67
## world px per art px and the big ones cap at 57. Not a whole art pixel, so a find bobbing
## on the swell crawls a little on the grid; weighed and accepted, to be judged in play.
const FIND_SHRINK := 1.2

## Hulls the lake will hold. Used to read 3, on the theory that three ferries working one
## yard was already more loading than the yard produces — 2026-09 playtest says otherwise
## (see docs/balance/2026-09-06.md): the yard sat thousands deep the whole run. Raised to 5;
## `fleet`'s own `.tres` gates how many of those are actually for sale.
const MAX_BOATS := 4

## What the first skimmer fitted brings up. The track walks from here to a certainty at
## its last level.
const SKIM_FIRST_CHANCE := 0.30

## Per-track price curve, value curve, and level cap now live in `resources/upgrades/*.tres`
## (see `UpgradeTrack`) for every track except `skimmer`, whose payoff is a chance curve
## rather than this price-and-value shape — it keeps its own entry here.
const MAX_LEVELS := {
	&"skimmer": 10,
}

## Tracks the shop no longer sells but the code still carries (2026-09-14, Richard: keep the
## code, hide the rows). The skimmer, and the market's five sell-by-tier tracks. Not listed,
## not counted as affordable, and `_buy` refuses them; their levels still save and load so
## a file written before they were shelved reads without complaint. `tier_pay` is 1 for all.
const SHELVED := [&"skimmer", &"sell_0", &"sell_1", &"sell_2", &"sell_3", &"sell_4"]

## Dogs in the pack at most: the one adopted plus what `dog_count` buys (2026-09-14). All of
## them share one Fetching and Keenness level and one drawing.
const MAX_DOGS := 4

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
## Where the lake goes when it is left: the main menu.
const MENU_SCENE := "res://scenes/menu.tscn"
## 6: ten rubbish kinds appended to TRASH_ORDER. Saved stacks hold indices into the whole
## def list and the finds follow the rubbish in it, so every find's index moved.
## 8: the kitchen chairs and the old table left the catalogue and four rubbish-born finds
## (two paintings, the chew toy, the globe) joined it; the def list changed again.
## 10: the shed places furniture on whole source pixels rather than on eight-pixel cells
## (2026-09-16), so a `decor` row's numbers mean something eight times smaller.
const SAVE_VERSION := 10

## The one older save this build still reads, and it is read rather than refused because the
## only thing that changed in it is the unit the shed's furniture is placed in: a version 9
## file is exact in cells, so its rows are scaled by `ShedRoom.CELL` and every piece lands
## back where it stood. Everything else in the file is identical, which is what makes the one
## exception to "older saves are refused rather than migrated" safe. Don't grow this into a
## migration chain: the next change to the def list refuses it again.
const SAVE_SHED_CELLS := 9

## The piece of furniture the shed starts with, and so the one find not in the lake.
const STARTER_BED := "decor_bed"

## The one find that starts on the surface, by the island, so the first casts have a
## decoration to bring home; and how far past the rubbish's inner edge it may lie. Kept
## inside a level-0 throw: the shelf is 2.3 tiles out and the rod starts at 3.4, so the
## band is narrow, and the piece is tier 0 (see `_all_defs`).
const FIRST_FIND := &"decor_pet_bed"
const FIRST_FIND_OUT := 0.8

## How far apart the hidden finds are dealt, in tiles: two a cast apart read as a hoard.
const FIND_APART := 7.0
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

## Tree test mode (2026-09-12): the proposed upgrade tree played as its own game, started from
## the main menu's "New game (tree)" so it can be tried before it replaces the shop. A tree run
## starts with the net only and the tree file's starting money; the first ferry and the dog are
## bought. It saves to its own slot and writes a playtest log (`TreeLog`). The shop, its
## tracks and every normal run are untouched. See `UpgradeTree` and docs/progression/lake-tree.md.
##
## `start_tree` is set by the menu and read once, the way `start_fresh` is; `tree_mode` can
## also be set before the scene enters the tree, which is how tools/test_tree.tscn runs it.
const TREE_SAVE_PATH := "user://lake_cleanup_tree.save"
static var start_tree: bool = false
var tree_mode: bool = false
var _tree: UpgradeTree
## Node id -> rank owned. Shared with the tree screen, so it is edited in place, never replaced.
var _tree_owned: Dictionary = {}
var _tree_stats: Dictionary = {}
var _tree_screen: TreeScreen
## Seconds of play in this tree run, saved with it, and the playtest log's clocks.
var _tree_play: float = 0.0
var _tree_progress_in: float = 0.0
var _tree_last_cast: float = -1.0
const TREE_PROGRESS_EVERY := 30.0
## Pieces in the lake when it was built, for the log's cleared share.
var _pieces_full: int = 0

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
## Dogs adopted on top of the first, up to MAX_DOGS in the pack. resources/upgrades/dog_count.tres.
var dog_count_level: int = 0

## The market board (2026-09-13): what a piece of each weight tier sells for, one track per
## tier (`sell_0`..`sell_4`, in TrashDef.tier order); the Recycle Bonus, one yard at a time
## paying over the odds for `BONUS_EVERY` seconds before the bonus moves on; and what a
## netted pigeon is worth. Plus two more on the net's board: the odds of a lucky haul (one
## tier deeper and a few more in the bag, that cast only) and of a double cast (a second net
## thrown alongside the first at a nearby spot with rubbish on it, its own hold).
var sell_levels := PackedInt32Array([0, 0, 0, 0, 0])
var recycle_bonus_level: int = 0
var bird_worth_level: int = 0
var lucky_haul_level: int = 0
var double_cast_level: int = 0

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
## Whether the view is on its way home from a haul, and so held under `HOME_SPEED`. Set on
## the first frame of the reel and kept until the view has settled back on the angler:
## the net beating the view home is the whole reason for the cap, so the cap cannot be
## allowed to lift the moment the net arrives.
var _homing: bool = false

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
## The whole pack, `_dog` first. Every dog is wired like the first (`_fit_dog`) and shares
## its numbers; they only differ in where they stand and what they have claimed.
var _dogs: Array[Dog] = []

## The daylight, and the two things it is painted with: one modulate over the whole world
## canvas, and the fill behind it. The HUD, the shop board and the shed room are on canvas
## layers of their own and are deliberately not touched by either — a menu that dims at dusk
## is a menu that is harder to read at dusk, for nothing.
var _day: DayCycle
var _daylight: CanvasModulate
var _water_material: ShaderMaterial

## The island's shed. A drawn node with nothing else to do.
var _island: Node2D
var _shed_cast: Shade.Cast

## The four merchants on the bank, held in TrashDef.Kind order so a material index is a
## dropoff index everywhere.
var _dropoffs: Array[Dropoff] = []

## How far the camera may travel, in world pixels. Taken from the lake's own extent so the
## view cannot be panned off into empty space.
var _bounds := Rect2()

var _menu_open: bool = false
var _settings_open: bool = false
var _shed_open: bool = false
## The bind board, opened from the settings board's Controls row. Made on demand rather than
## put in the scene: it is a board a player opens once a run at most.
var _controls_open: bool = false
var _controls: ControlsSkin

## Every purchasable track but `skimmer`, loaded from resources/upgrades/*.tres. Keyed by
## the same StringName used throughout the shop (`&"net_width"`, `&"cargo"`, ...).
const UPGRADE_ORDER := [
	"net_width", "net_strength", "net_range", "reel", "net_hold",
	"boat_speed", "cargo", "fleet",
	"dog_fetch", "dog_wait",
	"sell_0", "sell_1", "sell_2", "sell_3", "sell_4",
	"recycle_bonus", "bird_worth", "lucky_haul", "double_cast",
	"dog_count",
]
var _upgrades: Dictionary = {}

## The Recycle Bonus: which material's yard is paying over the odds right now (-1 until the
## first level is bought), and how long it has left before the bonus moves to another yard.
## Only the sale counts — a piece landed at the boosted yard inside the window, whenever it
## was netted — and the window is fixed: the upgrade raises the bonus, never the time.
## Not saved: it is a clock, and a load starts it again.
const BONUS_EVERY := 30.0
var _bonus_kind: int = -1
var _bonus_left: float = 0.0

## The luck rolls — lucky haul and double cast — on their own generator, so they change
## nothing about the pigeon's timing or the lake's fill.
var _luck_rng := RandomNumberGenerator.new()
## How many more pieces a lucky haul's bag takes, that cast only.
const LUCKY_EXTRA := 4
## How far from where the first net lands the second one may land, in tiles, and how close
## to the first it may not: a second net on top of the first is one net drawn twice.
const DOUBLE_NEAR := 4.0
const DOUBLE_APART := 1.5

## The second net: thrown by a double cast, reeled in like the first, landing its own catch
## in the yard through the same signals. Made in `_ready`, hidden whenever it is stowed so
## it does not draw a second range ring and marker under the angler's feet.
var _net2: CastNet

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
## The open clean patches: `at` (world), `radius` (world px, long axis), `born` (on
## `_patch_clock`), `seed` (the shape's roll).
var _patches: Array[Dictionary] = []
var _patch_clock: float = 0.0
var _patch_rng := RandomNumberGenerator.new()
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

## Coins flying from a sale at a pier to the money plate, on the HUD's layer.
var _coins: CoinFly

var _farewell_shown: bool = false
## Seconds left of the shimmer the ending opens on, counting down to the words. Above zero
## only during the beat; the farewell itself is what says the ending is up afterwards.
var _ending_in: float = 0.0
var _farewell: Farewell

## The pad's reticle and its assist, see scripts/pad_aim.gd. `at` is INF while the mouse is
## aiming; `_pad_was` notices the switch so the reticle starts where the pointer was.
var _aim := PadAim.new()
var _pad_was: bool = false
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
	if tree_mode:
		return _tree_stat("net_radius")
	return _upgrades[&"net_width"].value(net_width_level)


## The heaviest TrashDef.tier the net can lift. resources/upgrades/net_strength.tres.
func net_power() -> int:
	if tree_mode:
		return int(_tree_stat("net_power"))
	return int(_upgrades[&"net_strength"].value(net_strength_level))


## How far the angler can throw, in tiles.
##
## Starts short on purpose — the rod once reached a third of the way across the basin at
## the first upgrade, which made the boat pointless and the lake small — but it accelerates,
## because a track whose price multiplies while its reach only adds is a track that is worth
## less every time you buy it. The squared term is what keeps the late levels worth the
## money. Numbers live in resources/upgrades/net_range.tres.
func net_range() -> float:
	if tree_mode:
		return _tree_stat("net_range")
	return _upgrades[&"net_range"].value(net_range_level)


## How fast the net comes home, in tiles per second. resources/upgrades/reel.tres.
func reel_speed() -> float:
	if tree_mode:
		return _tree_stat("reel")
	return _upgrades[&"reel"].value(reel_level)


## How many pieces one cast can bring in. resources/upgrades/net_hold.tres.
func net_hold() -> int:
	if tree_mode:
		return int(_tree_stat("net_hold"))
	return int(_upgrades[&"net_hold"].value(net_hold_level))


## Ferry speed, in tiles per second. resources/upgrades/boat_speed.tres.
func boat_speed() -> float:
	if tree_mode:
		return _tree_stat("boat_speed")
	return _upgrades[&"boat_speed"].value(boat_speed_level)


## resources/upgrades/cargo.tres.
func boat_cargo() -> int:
	if tree_mode:
		return int(_tree_stat("cargo"))
	return int(_upgrades[&"cargo"].value(cargo_level))


## How many pieces one trip out may bring back. resources/upgrades/dog_fetch.tres.
func dog_fetch() -> int:
	if tree_mode:
		return int(_tree_stat("dog_fetch"))
	return int(_upgrades[&"dog_fetch"].value(dog_fetch_level))


## Seconds off the top of the dog's wait between trips, so the longest it will laze about
## comes down and the shortest does not. resources/upgrades/dog_wait.tres, and see
## Dog.MOOD_MOST for what it is taken off.
func dog_wait_cut() -> float:
	if tree_mode:
		return _tree_stat("dog_wait_cut")
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


## What a piece of weight tier `tier` sells for, as a multiple of its plain pay.
## resources/upgrades/sell_N.tres. Tree runs have no market board and sell at par.
func tier_pay(tier: int) -> float:
	if tree_mode:
		return 1.0
	var t := clampi(tier, 0, sell_levels.size() - 1)
	var key := StringName("sell_%d" % t)
	if key in SHELVED:
		return 1.0
	return _upgrades[key].value(sell_levels[t])


## How much over the odds the boosted yard pays, as a fraction (0.25 is +25%).
## resources/upgrades/recycle_bonus.tres.
func recycle_bonus() -> float:
	if tree_mode:
		return _tree_stat("recycle_bonus")
	return _upgrades[&"recycle_bonus"].value(recycle_bonus_level)


## What a netted pigeon pays. resources/upgrades/bird_worth.tres times the economy's bonus.
func bird_pay() -> float:
	if tree_mode:
		return _economy.bird_bonus * _tree_stat("bird_worth")
	return _economy.bird_bonus * _upgrades[&"bird_worth"].value(bird_worth_level)


## Odds that a cast is a lucky one. resources/upgrades/lucky_haul.tres.
func lucky_chance() -> float:
	if tree_mode:
		return _tree_stat("lucky_odds")
	return _upgrades[&"lucky_haul"].value(lucky_haul_level)


## Odds that a cast throws a second net. resources/upgrades/double_cast.tres.
func double_cast_chance() -> float:
	if tree_mode:
		return _tree_stat("double_odds")
	return _upgrades[&"double_cast"].value(double_cast_level)


## How many slots down the skimmer digs for the material it is running out. More than one,
## always: it is looking for one material in particular, and on the way to the sawmill most
## of what is floating on top is not wood.
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
	_setup_tree()
	_grid = $Grid as LakeGrid
	_camera = $Camera as Camera2D
	_boats = [$Boat as Boat]
	_angler = $Angler as Angler
	_net = $Net as CastNet
	_yard = $Yard as Yard
	_dog = $Dog as Dog
	_dogs = [_dog]

	var shore := Iso.shore_outline()
	_shape_bank()
	_shape_water(shore)
	_shape_island()
	_shape_dropoffs()
	_tune_ground()

	_shed_art = Art.texture(SHED_ART)

	# The autoload, so the start sound pressed on the menu is still playing as the lake comes
	# up. A run without it — a tool scene — gets its own board.
	_sfx = Sfx.main()
	if _sfx == null:
		_sfx = Sfx.new()
		_sfx.name = &"Sfx"
		add_child(_sfx)
	_sfx.set_ambience(true)
	_grid.find_surfaced.connect(func(_index: int) -> void: _sfx.play_find_chime())

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
	# The yards read the grid's clock, so the shadow a jetty throws on the water rises and
	# falls with the swell the rubbish beside it rides.
	for stop: Dropoff in _dropoffs:
		stop.grid = _grid
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
	_pieces_full = _grid.piece_count()
	_filth_total = maxf(_grid.filth_left(), 0.001)
	_filth_left = _filth_total
	pollution = 1.0
	_build_filth_map()

	_build_trophy()
	_build_pigeon_pop()
	_build_coins()

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
	_angler.day = _day
	_fit_dog(_dog)
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
	for dog in _dogs:
		dog.crate_tile = Vector2(Iso.ISLAND_CENTRE.x + 2.7, Iso.ISLAND_CENTRE.y + 2.7)
	# The angler is told as well, but for the opposite reason: the dog walks to the crate and
	# the player walks round it.
	_angler.crate_tile = _dog.crate_tile

	# The flock is drawn over the whole lake (2026-09-16, Richard's call): birds are the one
	# thing here that is genuinely in the air, and at z 6 they were cut in half by a pier
	# deck, hidden behind a moored hull and walked in front of by the angler. Above the net
	# and the finds' beams too — "over everything" was the whole of the instruction, and a
	# bird that vanishes behind the thing being cast at it is the bug, not the fix.
	_flock = Flock.new()
	_flock.name = &"Flock"
	_flock.z_index = BIRD_LAYER
	_flock.z_as_relative = false
	_flock.grid = _grid
	_flock.angler = _angler
	_flock.sfx = _sfx
	_flock.day = _day
	add_child(_flock)

	_net.grid = _grid
	_net.splash = _splash
	_angler.splash = _splash
	for dog in _dogs:
		dog.splash = _splash
		dog.prints = _prints
	_angler.prints = _prints
	_net.sfx = _sfx
	_net.angler = _angler
	_net.flock = _flock
	# And back the other way: the flock asks the net whether a perched bird is inside reach,
	# which is what decides the rim. The player's own net, not the double cast's helper.
	_flock.net = _net
	_net.landed.connect(_on_net_landed)
	_net.caught.connect(_on_net_caught)
	_net.swept.connect(_on_net_swept.bind(_net))
	_net.caught_bird.connect(_on_bird_caught)

	# The double cast's net: the first one over again, on the same signals, but a helper —
	# it never plays the angler's throw or ends it, that is the first net's gesture.
	_net2 = CastNet.new()
	_net2.name = &"Net2"
	_net2.helper = true
	_net2.z_as_relative = false
	_net2.z_index = _net.z_index
	_net2.grid = _grid
	_net2.splash = _splash
	_net2.sfx = _sfx
	_net2.angler = _angler
	_net2.flock = _flock
	_net2.visible = false
	_net2.landed.connect(_on_net_landed)
	_net2.caught.connect(_on_net_caught)
	_net2.swept.connect(_on_net_swept.bind(_net2))
	_net2.caught_bird.connect(_on_bird_caught)
	add_child(_net2)

	# The ferry lives on the island's south side and works its way round the bank from
	# there, calling at whichever merchants its load is for.
	_fit_out(_boats[0], 0)
	_push_net_numbers()
	_push_boat_numbers()
	if tree_mode:
		_sync_tree_world()

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
	# The house's own bed is never a def (`_all_defs` skips it), so its name comes off the
	# catalogue, or the shelf shows a picture with no word under it (Richard, 2026-09-13).
	if _sheets != null and not _pretty(STARTER_BED).is_empty():
		_room.titles[STARTER_BED] = _pretty(STARTER_BED)
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
	_room.close_asked.connect(_shut.bind(_set_shed))
	_open_settings.pressed.connect(_set_settings.bind(true))
	# Last of the HUD's children, so it lies over the shed rather than under it. The shed
	# fills the screen now, and a settings panel drawn beneath that is a settings panel
	# nobody can see or press.
	_settings.get_parent().move_child(_settings, -1)
	_settings.get_parent().move_child(_open_settings, -1)
	# The volumes are audio buses now (2026-09-16, issue #26): the board sets them through
	# `Prefs` and nothing has to be pushed from here. What is left is the doors it opens.
	_settings.controls_asked.connect(_set_controls.bind(true))
	_settings.quit_pressed.connect(_quit)
	_settings.wipe_pressed.connect(wipe_save)
	_settings.swap_label = _other_level_name()
	_settings.swap_pressed.connect(_swap_levels)
	_settings.close_asked.connect(_shut.bind(_set_settings))
	_send_now.pressed.connect(_send_ferry)
	_auto_ferry.toggled.connect(_set_auto_ferry)
	_close_menu.pressed.connect(_set_menu.bind(false))
	_shop_skin.close_asked.connect(_shut.bind(_set_menu))
	if tree_mode:
		_build_tree_screen()
	# Not the shed. It has no panel to hang a cross on the corner of any more — the room is
	# the whole screen — so its own cross sits over the top of the inventory column, where
	# the thing it closes actually is. See ShedRoom.
	_polish_panel_controls()
	_set_menu(false)
	_start_music()
	_set_settings(false)
	_set_controls(false)
	_set_shed(false)
	_push_water_colours()
	var loaded := false
	if autoload_save and not start_fresh:
		loaded = load_game()
	start_fresh = false
	if tree_mode:
		_begin_tree_session(loaded)
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
	# The lake gets the first two seconds to itself: the sparkle rising, the note ringing and
	# the end song coming in. The words follow. See ENDING_BEAT.
	_ending_in = ENDING_BEAT
	_push_rooms()


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


## The corner buttons' canvas, F7, debug builds only. See ButtonTuner. Built on the key
## rather than at start-up: it is a panel over the whole screen, and one that is up whenever
## the game is is a panel in the way.
func _tune_buttons() -> void:
	if not OS.is_debug_build():
		return
	var open := get_node_or_null(^"ButtonTuner")
	if open != null:
		open.queue_free()
		return
	var tuner := ButtonTuner.new()
	tuner.name = &"ButtonTuner"
	tuner.sprites = _skin.sprites
	add_child(tuner)


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
	_patch_rng.randomize()
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

## The flock, above the lot of it — hulls (12), the haul (8), the piers, the walkers, and
## the net and the finds' beams at 20. A pigeon is the only thing on this lake that is
## actually in the air, and nothing here is ever in front of one.
const BIRD_LAYER := 21


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
		[TrashDef.Kind.WOOD, 0.0, Color(0.66, 0.50, 0.28)],
		[TrashDef.Kind.METAL, -PI * 0.5, Color(0.62, 0.64, 0.70)],
		[TrashDef.Kind.RUBBER, PI, Color(0.32, 0.30, 0.34)],
	]
	_dropoffs.resize(0)
	for row: Array in order:
		var stop := Dropoff.new()
		stop.kind = row[0] as int
		stop.tint = row[2] as Color
		# The jetty leaves the bank at the drawn waterline — Iso's line plus the lap the
		# water is painted past it — and the berth is alongside the jetty's end, worked out
		# by the yard itself from that one bearing.
		stop.moor(row[1] as float, SHORE_LAP)
		stop.day = _day
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
		# The crate's own thud, the same one a piece landing in it plays from anywhere else.
		# It used to be the knock, which was the water it came out of and not the box.
		_sfx.play_pop()


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
		# The house's own bed is never in the water: the shed starts with it
		# (`_seed_starter_bed`), so a second one to fish out was a find nobody needed.
		# Richard, 2026-09-13. Leaves the pet bed, which is a find.
		if name == STARTER_BED:
			continue
		var cells := _sheets.cells_of(name)
		var bulk := cells.x * cells.y
		var find := _def(
			_pretty(name),
			TrashDef.Kind.WOOD if bulk % 2 == 0 else TrashDef.Kind.METAL,
			Vector2(26.0, 26.0),
			# Heavy: a wardrobe belongs at the bottom of a stack, under the mugs.
			0.22, 2.0 + 0.4 * float(bulk), 2.0 + 0.5 * float(bulk),
			clampi(bulk / 2, 1, 4), Color(0.58, 0.44, 0.32), StringName(name)
		)
		find.keepsake = true
		# The first find is for the first net: tier 0, or a net at power 0 cannot lift it.
		if StringName(name) == FIRST_FIND:
			find.tier = 0
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
	var planted_at: Array[Vector2] = []
	# The pet bed first, afloat by the island — the one find that is not a dig, so the net
	# has something for the shed within its first few casts (Richard, 2026-09-13). Planted
	# first so the rest keep their distance from it, not the other way round.
	var first := _first_find_tile(rng)
	for i in _grid.defs.size():
		var def := _grid.defs[i]
		if not def.keepsake:
			continue
		if def.piece == FIRST_FIND and first >= 0:
			_grid.insert(first, _grid.height_of(first), i)
			planted_at.append(Vector2(_grid.tile_of(first)))
			first = -1
			continue
		var planted := false
		# Spread out: a dart is refused inside FIND_APART of a find already down, until the
		# darts run low and any deep tile will do. Forty darts found tiles; a hundred and
		# twenty find spaced ones on a lake this size, and the fallback keeps the guarantee.
		for attempt in 160:
			var tx := rng.randi_range(2, Iso.COLS - 3)
			var ty := rng.randi_range(2, Iso.ROWS - 3)
			var index := _grid.index_of(tx, ty)
			var height := _grid.height_of(index)
			if height < 3:
				continue
			if attempt < 120 and _too_near(Vector2(tx, ty), planted_at):
				continue
			_grid.insert(index, maxi(height - 1 - rng.randi_range(0, 2), 0), i)
			planted_at.append(Vector2(tx, ty))
			planted = true
			break
		if not planted:
			_plant_anywhere(i)


func _too_near(at: Vector2, others: Array[Vector2]) -> bool:
	for other: Vector2 in others:
		if at.distance_to(other) < FIND_APART:
			return true
	return false


## A tile for the first find: floating rubbish in the first band of water past the island's
## shelf, picked off the seed. -1 if the lake has none there (a bare test lake).
func _first_find_tile(rng: RandomNumberGenerator) -> int:
	var near := Iso.SHELF_TILES + Iso.SHELF_CLEAR
	var pool := PackedInt32Array()
	for ty in Iso.ROWS:
		for tx in Iso.COLS:
			var out := Iso.past_shelf(Vector2(tx, ty))
			if out < near or out > near + FIRST_FIND_OUT:
				continue
			var index := _grid.index_of(tx, ty)
			if _grid.height_of(index) >= 1 and _grid.dry[index] == 0:
				pool.append(index)
	if pool.is_empty():
		return -1
	return pool[rng.randi() % pool.size()]


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
		var shrink := FIND_SHRINK if def.keepsake else 1.0
		var scale := SPRITE_SCALE / shrink
		if longest * scale < SPRITE_SMALLEST:
			scale = ceilf(SPRITE_SMALLEST / longest)
		elif longest * scale > SPRITE_LARGEST / shrink:
			scale = maxf(SPRITE_LARGEST / shrink / longest, SPRITE_SMALLEST / longest)
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


## Casting, reeling, zooming, and the shed door — every one of them through the input map
## (2026-09-16, issue #26), so the bind board can move any of them.
##
## **Only the keyboard and the mouse are read here.** The pad's own buttons are read once a
## frame in `_pad_buttons`, because a trigger is an axis and a held axis is a stream of
## events; an action holds both devices, so acting on a joypad event here as well would
## answer every pad press twice.
##
## The keys that are not verbs stay hard-wired: Escape backs out of whatever is open, F11 is
## the window, M mutes the music, and F6 and F7 are the debug doors. None of them are in the
## bind table, by decision — Escape is what cancels a capture, and a player who rebinds the
## way out of a board has no way out of the board.
func _unhandled_input(event: InputEvent) -> void:
	if _extra_input(event):
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		match key.keycode:
			KEY_ESCAPE:
				# One key backing out of whatever is open, innermost first: the shed, then
				# the shop board, and only on open water does it mean the settings.
				if _controls_open:
					_shut(_set_controls)
				elif _shed_open:
					_shut(_set_shed)
				elif _menu_open:
					_shut(_set_menu)
				elif _settings_open:
					_shut(_set_settings)
				else:
					_set_settings(true)
				return
			KEY_F11:
				_flip_fullscreen()
				return
			KEY_M:
				_settings.music_on = not _settings.music_on
				Prefs.store(&"music_on", _settings.music_on)
				return
			KEY_F6:
				wipe_save()
				return
			KEY_F7:
				_tune_buttons()
				return

	var drag := event as InputEventMouseMotion
	if drag != null and _panning:
		# Divided by the zoom, so a drag moves the world under the cursor by the distance
		# the cursor moved however far in or out the view is.
		_pan -= drag.relative / _camera.zoom
		_pan_moved += drag.relative.length()
		return

	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return

	# The shed door and saying hello to a dog.
	if _desk_pressed(event, &"interact"):
		if _settings_open or _controls_open:
			return
		if _shed_open:
			_shut(_set_shed)
		elif _menu_open:
			_shut(_set_menu)
		elif _at_shed():
			_set_shed(true)
		elif _dog_in_reach() != null:
			# Standing next to a dog with nothing else under the key: the same button that
			# opens the shed says hello.
			_dog_in_reach().pet()
		return
	if _desk_pressed(event, &"open_shed") and not _panelled():
		_set_shed(true)
		return
	if _desk_pressed(event, &"open_upgrades") and not _shed_open and not _settings_open 			and not _controls_open:
		_set_menu(not _menu_open)
		return
	if _desk_pressed(event, &"open_settings") and not _panelled():
		_set_settings(true)
		return

	var click := event as InputEventMouseButton
	if click == null:
		return

	# The middle button drags the view off the angler. Tapping it without dragging puts the
	# view back on them, which is the way out of having panned somewhere and lost yourself.
	# The drag is the button's, not a verb's: `recentre` is what the bind board moves, and a
	# binding that is not a mouse button acts on the press instead of on a tap.
	if click.button_index == PAN_BUTTON:
		if click.pressed:
			_panning = true
			_pan_moved = 0.0
			_pan_yielded = false
		else:
			_panning = false
			if _pan_moved < PAN_TAP and not _panelled():
				_pan = Vector2.ZERO
		return

	# Guarded against any panel being open: this is _unhandled_input, so a wheel event over a
	# panel's own controls never reaches here — but the settings panel and the shop board
	# don't cover the whole screen, so a wheel turned over the exposed lake behind either one
	# used to zoom the lake out from under an open menu.
	if _panelled():
		# A click that reaches this far is a click on the lake rather than on a panel — the
		# panels eat their own. So it closes whatever is open, which is what the "back to the
		# water" buttons were for and is a thing every player tries first anyway.
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			_set_controls(false)
			_set_settings(false)
			_set_menu(false)
			_set_shed(false)
		return

	# The wheel zooms about the cursor, so the thing the player is pointing at is the thing
	# that stays put. Zooming about the screen's middle makes reaching a corner of the lake a
	# game of chasing it back.
	if _desk_pressed(event, &"zoom_in"):
		_zoom_by(ZOOM_STEP)
		return
	if _desk_pressed(event, &"zoom_out"):
		_zoom_by(1.0 / ZOOM_STEP)
		return
	if _desk_pressed(event, &"recentre"):
		_pan = Vector2.ZERO
		return

	# A lit net is laid: the cast goes out, stays where it lands, and burns or freezes there.
	# It does nothing at all with an unlit net, which is why it is the second button — the
	# first one is the game, and this is the thing the charms buy.
	if _desk_pressed(event, &"lay_net"):
		if _net.state == CastNet.State.IDLE and _net.enchanted():
			_cast_at(get_global_mouse_position(), true)
		return

	# Letting go is not part of the gesture any more: the net reels itself in from wherever
	# it lands, and a cast is one click rather than a click held down for the length of a
	# drag across the basin.
	#
	# Click to throw. A click on a net already down starts it moving again — the only way it
	# can be sitting still is a panel that was opened over it — and a click on one that is
	# already coming home is left alone.
	if _desk_pressed(event, &"cast"):
		if _net.state == CastNet.State.IDLE:
			_cast_at(get_global_mouse_position())
		_net.set_pulling(true)


## Whether a press of this action came from the desk — a key or a mouse button — rather than
## from the pad, which `_pad_buttons` answers.
func _desk_pressed(event: InputEvent, action: StringName) -> bool:
	if not (event is InputEventKey or event is InputEventMouseButton):
		return false
	return event.is_action_pressed(action)


## Whether any board is over the lake.
func _panelled() -> bool:
	return _settings_open or _menu_open or _shed_open or _controls_open


## F11, and the window row's two ordinary modes. Borderless rather than exclusive: the lake
## is a window to alt-tab out of, and exclusive is the one the settings board asks about.
func _flip_fullscreen() -> void:
	var to := (
		Prefs.WindowMode.WINDOWED if Prefs.live_window_mode() != Prefs.WindowMode.WINDOWED
		else Prefs.WindowMode.BORDERLESS
	)
	Prefs.store(&"window_mode", to)
	Prefs.apply_window()


## Whether the pad should drive a pointer (see scripts/pad.gd): only while something the
## mouse is for is up. On the bare lake the right stick is the reticle's.
func pad_cursor_wanted() -> bool:
	return _menu_open or _settings_open or _shed_open or _controls_open or _farewell != null


## Where a cast goes: the pad's reticle while there is one, else the mouse.
func aim_point() -> Vector2:
	return _aim.at if _aim.at != Vector2.INF else get_global_mouse_position()


## The pad, once a frame: the reticle's life, its step and the assist, and the buttons.
##
## Buttons are read here with `is_action_just_pressed` rather than as events, because the
## triggers are axes and an axis past its deadzone is a stream of events — read as events,
## a trigger held down would throw again the moment the net was home. The buttons `Pad` turns
## into the mouse while a board is up (A, B, the shoulders) are only acted on here when
## nothing is, so the two never both answer one press.
func _pad_tick(delta: float) -> void:
	var pad := Pad.is_pad()
	if pad and not _pad_was:
		var pointer := get_global_mouse_position()
		_aim.at = pointer if _visible_world_rect().has_point(pointer) else _angler.position
	elif not pad:
		_aim.at = Vector2.INF
	_pad_was = pad
	var busy := pad_cursor_wanted()
	if pad:
		if not busy:
			var stick := Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down")
			_aim.step(delta, stick, _visible_world_rect(), _net)
		_aim.hold_in(_visible_world_rect(), _camera.zoom.x)
	_net.pad_aim = _aim.at
	# **Pad mode only** (2026-09-16): one action holds both devices now, and
	# `is_action_just_pressed` does not care which one pressed it — so read on every frame
	# this answered the keyboard's Escape and the mouse's click as well as the pad's, and the
	# desk answered them again in `_unhandled_input`. Two answers to one press is no answer:
	# Escape opened the settings here and closed them there, in the same frame.
	if pad:
		_pad_buttons(busy)


func _pad_buttons(busy: bool) -> void:
	if Input.is_action_just_pressed(&"open_settings"):
		_set_settings(not _settings_open)
		return
	if _settings_open or _controls_open or _farewell != null:
		return
	if _shed_open:
		# The room's own verbs, the shed's R and E. Their own actions, because the buttons
		# that turn a piece and work a switch in here open the shed and the upgrades out
		# there: one button, two places, and `Binds` checks a clash inside a context only.
		if Input.is_action_just_pressed(&"shed_rotate"):
			_room.turn_carried()
		if Input.is_action_just_pressed(&"shed_switch"):
			_room.switch_near()
		return
	if Input.is_action_just_pressed(&"open_upgrades"):
		_set_menu(not _menu_open)
		return
	if busy:
		return
	if Input.is_action_just_pressed(&"open_shed"):
		# X on the water is the corner's decorate button: the shed from anywhere.
		_set_shed(true)
		return
	if Input.is_action_just_pressed(&"interact"):
		if _at_shed():
			_set_shed(true)
		elif _dog_in_reach() != null:
			_dog_in_reach().pet()
		return
	if Input.is_action_just_pressed(&"recentre"):
		_aim.at = _angler.position
	if Input.is_action_just_pressed(&"zoom_in"):
		_zoom_by(ZOOM_STEP, aim_point())
	if Input.is_action_just_pressed(&"zoom_out"):
		_zoom_by(1.0 / ZOOM_STEP, aim_point())
	if Input.is_action_just_pressed(&"lay_net"):
		if _net.state == CastNet.State.IDLE and _net.enchanted():
			_cast_at(aim_point(), true)
	if Input.is_action_just_pressed(&"cast"):
		# The click's own gesture: throw from idle, and a net sitting still is set pulling.
		if _net.state == CastNet.State.IDLE:
			_cast_at(aim_point())
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
		if not laying:
			_roll_luck(where)
		if tree_mode:
			var since := -1.0 if _tree_last_cast < 0.0 else snappedf(_tree_play - _tree_last_cast, 0.01)
			TreeLog.write("cast", _tree_play, {"since_last": since})
			_tree_last_cast = _tree_play


## The two luck rolls on a cast just thrown. A lucky haul goes on the net itself, for this
## cast only (`CastNet.luck_power`/`luck_hold`, cleared when it comes home). A double cast
## throws the second net at a spot near the first with rubbish on it — none found, no
## second net: luck that lands on bare water is a net thrown at nothing.
func _roll_luck(where: Vector2) -> void:
	if _luck_rng.randf() < lucky_chance():
		_net.luck_power = 1
		_net.luck_hold = LUCKY_EXTRA
	if _net2 == null or _net2.state != CastNet.State.IDLE:
		return
	if _luck_rng.randf() >= double_cast_chance():
		return
	var spot := _double_spot(Iso.world_to_tile(where))
	if spot != Vector2.INF:
		_net2.cast_to(Iso.tile_to_world(spot.x, spot.y))


## Somewhere for the second net to land: a tile within `DOUBLE_NEAR` of the first net's
## target and at least `DOUBLE_APART` from it, with a piece on top the net can lift, that
## the angler could have thrown at. One picked at random from all of them, or INF.
func _double_spot(target: Vector2) -> Vector2:
	var found: Array[Vector2] = []
	var span := int(ceil(DOUBLE_NEAR))
	var cx := int(floor(target.x))
	var cy := int(floor(target.y))
	for ty in range(maxi(cy - span, 0), mini(cy + span + 1, Iso.ROWS)):
		for tx in range(maxi(cx - span, 0), mini(cx + span + 1, Iso.COLS)):
			var tile := Vector2(float(tx) + 0.5, float(ty) + 0.5)
			var away := tile.distance_to(target)
			if away > DOUBLE_NEAR or away < DOUBLE_APART:
				continue
			if _grid.reachable_slot(_grid.index_of(tx, ty), 1, net_power()) < 0:
				continue
			if not _net2.can_cast_to(Iso.tile_to_world(tile.x, tile.y)):
				continue
			found.append(tile)
	if found.is_empty():
		return Vector2.INF
	return found[_luck_rng.randi_range(0, found.size() - 1)]


## Is the angler standing at the shed?
##
## Measured to where the hut stands, not to the island's middle — those are two thirds of a
## tile apart (`Iso.shed_centre`), which on a range of about three tiles is the difference
## between the door opening on the near side and on the far one.
func _at_shed() -> bool:
	return _angler.tile_pos.distance_to(Iso.shed_centre()) < SHOP_RANGE


## Zoom by a factor, keeping the world point under the cursor under the cursor.
##
## On stops (`_zoom_stops`): at least one stop in the factor's direction, further if the
## factor asks for it, and never past either end.
##
## The spot stays put afterwards too (2026-09-14, Richard): the move is written into `_pan`,
## so the follow does not ease the view back onto the angler a moment later and undo the
## zoom. A wheel zoom is a pan like a middle-button drag, and is given back the same way —
## walking, a cast, or a tap of the middle button.
func _zoom_by(factor: float, about := Vector2.INF) -> void:
	var stops := _zoom_stops()
	var index := _nearest_stop(stops, _view_zoom)
	var target := _nearest_stop(stops, _view_zoom * factor)
	if factor > 1.0:
		target = maxi(target, index + 1)
	elif factor < 1.0:
		target = mini(target, index - 1)
	var wanted: float = stops[clampi(target, 0, stops.size() - 1)]
	if is_equal_approx(wanted, _view_zoom):
		return
	# Worked out from the camera's own mapping rather than by reading the mouse again
	# after moving it: the canvas transform only catches up next frame, so asking twice
	# would compare a fresh position against a stale one.
	var offset := get_viewport().get_mouse_position() - get_viewport_rect().size * 0.5
	# Or about the pad's reticle, which is the pad's pointer: `about` in world pixels.
	if about != Vector2.INF:
		offset = (about - _camera.position) * _camera.zoom
	var was := _camera.zoom.x
	_view_zoom = wanted
	_push_zoom()
	var now := _camera.zoom.x
	_keep_view_at(_clamped_view(_camera.position + offset / was - offset / now))


## Put the view here and hold it here, as a pan. See `_zoom_by`.
func _keep_view_at(to: Vector2) -> void:
	_camera.position = to
	if _angler == null:
		return
	# The pan that makes the view want to be exactly here, measured against where it wants to
	# be without one — not added to the camera's move, or a view still easing after the
	# angler would carry that lag into the pan and drift off the spot.
	_pan = to - (_watching() - _pan)
	_pan_yielded = false


## Write the camera's zoom: what the player set, put on the nearest stop and kept inside the
## same limits the wheel obeys.
func _push_zoom() -> void:
	# Stopped and clamped on the way out as well as when the wheel turns: the window can be
	# resized (or go fullscreen, which changes the stretch and so every level) under a view
	# that was already set, and anything outside can write `_view_zoom` directly.
	var stops := _zoom_stops()
	_view_zoom = stops[_nearest_stop(stops, _view_zoom)]
	_camera.zoom = Vector2(_view_zoom, _view_zoom)


## Every zoom the wheel may land on, far to near: the whole pixel levels between the two ends,
## plus a half level just in from the far end where the levels are coarse (`HALF_STOP_GAP`).
##
## The half level is the one exception to the pixel rule (2026-09-14, Richard's call): on a
## 1080p window the levels are thirds, and the jump from the whole lake at 0.33 to 0.67 read
## as stuck. The stop at 0.5 is 1.5 screen pixels to an art pixel, so the art draws 1 and 2
## pixels wide by turns and crawls a little while the view moves there. Accepted, to be
## judged in play. Finer windows already have stops that close and get no half level.
func _zoom_stops(stretch: float = -1.0) -> Array[float]:
	var far := _far_level(stretch)
	var near := _near_level(stretch)
	var stops: Array[float] = []
	for level in range(far, near + 1):
		stops.append(_zoom_level(level, stretch))
	if near > far and stops[1] - stops[0] >= HALF_STOP_GAP - 0.001:
		stops.insert(1, (stops[0] + stops[1]) * 0.5)
	return stops


## The index of the stop nearest a zoom.
static func _nearest_stop(stops: Array[float], zoom: float) -> int:
	var best := 0
	for i in stops.size():
		if absf(stops[i] - zoom) < absf(stops[best] - zoom):
			best = i
	return best


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
##
## `stretch` defaults to the window's own; the tests pass one to ask about other screens.
func _zoom_level(level: int, stretch: float = -1.0) -> float:
	return minf(float(level) / (ART_PIXEL * _stretch_or(stretch)), MAX_ZOOM)


## The closest level in: the last one not past MAX_ZOOM.
func _near_level(stretch: float = -1.0) -> int:
	return maxi(floori(MAX_ZOOM * ART_PIXEL * _stretch_or(stretch) + 0.0001), 1)


## The furthest level out: the first one at or out past the fitted zoom, so the whole lake
## and its piers are on screen there.
##
## Out past it, not nearest. On a stretched window the levels are a third or a half apart,
## and the nearest level to the fit is as likely to be in from it as out — a far end at
## which the lake is wider than the window is the far end not doing its job. Level one on a
## window too small for any level to fit, as before.
func _far_level(stretch: float = -1.0) -> int:
	var s := _stretch_or(stretch)
	return clampi(floori(_fit_zoom() * ART_PIXEL * s + 0.0001), 1, _near_level(s))


## The stretch given, or the window's own when none was.
func _stretch_or(stretch: float) -> float:
	return stretch if stretch > 0.0 else _stretch()


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
	return maxf(minf(view.x / span.x, view.y / span.y), MIN_ZOOM)


func _set_menu(open: bool) -> void:
	_menu_open = open
	# The drawn board replaces the panel of buttons rather than sitting behind it. The panel
	# is kept in the tree — its buttons are still where the shop's numbers are written, and
	# the shed's own controls live on it — but it is never shown.
	_shop_skin.visible = open and not tree_mode
	_shop.visible = false
	if _tree_screen != null:
		_tree_screen.visible = open
		if open:
			_tree_screen.open()
	_push_rooms()
	if open:
		_set_settings(false)
		_set_shed(false)
	_hold_the_angler()


## The room the finds go in. Opened from the shop, because the shed is where the player
## already is when they open it, and closed by the cross in its corner or by a click on the
## water around it.
func _set_shed(open: bool) -> void:
	if open and not _shed_open and _sfx != null:
		_sfx.play(&"shed_open")
	if tree_mode and open != _shed_open and _tree != null:
		TreeLog.write("shed_open" if open else "shed_close", _tree_play)
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
	# The lake's own readouts are not readable through a room and are not about it. The coins
	# go with them: they are drawn over everything, and they are a receipt for the plate.
	_skin.visible = not open
	if _coins != null:
		_coins.visible = not open
		if open:
			_coins.clear()
	_push_rooms()
	if _sfx != null:
		# The lake heard through the hut's wall.
		_sfx.set_ambience(true, open)
	_hold_the_angler()


## The settings panel: the logbook and the window, which are about the session rather than
## about the lake and so are not in the shed with the upgrades.
## A board closed by the player — its cross, a click off it, Escape — rather than put away
## by another board opening over it, which is the only case that makes the closing sound.
func _shut(close: Callable) -> void:
	Sfx.ui(&"ui_close")
	close.call(false)


## The bind board. It lies over the settings board that opened it, and closing it leaves
## that one up: the player asked for the controls, not for the settings to go away.
func _set_controls(open: bool) -> void:
	if open and _controls == null:
		_controls = ControlsSkin.new()
		_controls.name = &"Controls"
		_controls.set_anchors_preset(Control.PRESET_FULL_RECT)
		_controls.close_asked.connect(_shut.bind(_set_controls))
		_settings.get_parent().add_child(_controls)
	if _controls == null:
		return
	_controls_open = open
	_controls.visible = open
	_hold_the_angler()


func _set_settings(open: bool) -> void:
	if not open:
		_set_controls(false)
	if open:
		# Read again on the way in: F11, the menu's board and this one are one set of values.
		_settings.pull_prefs()
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
	_push_rooms()
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

## How long the lake has to itself before a word is written over it (2026-09-16, Richard:
## a little bit of the lake shimmer and sound before the message and the credits).
##
## The water is lighting up, the note is ringing and the end song is already coming in
## under all of it. Two seconds, by decision: a breath, not a held shot.
const ENDING_BEAT := 2.0


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
	# And nothing is still on its way to the crate (2026-09-16, Richard: the run ends when
	# the last item has been put into the box). A piece leaves the water in a net's hold or
	# a dog's mouth, and the ending used to fire the instant it left rather than the instant
	# it landed — the player watched the words arrive with the last piece still in hand. The
	# ferries may go on running underneath; what they carry is already in the box.
	if not _all_landed():
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


## Is every piece that has left the water in the crate?
##
## The nets' holds and the dogs' mouths, and the pieces in the air between either of them
## and the box. Everything past that point — a ferry's hold, a yard's heap — is stock, and
## stock is not the lake.
func _all_landed() -> bool:
	for net: CastNet in [_net, _net2]:
		if net != null and not net.catch.is_empty():
			return false
	for dog in _dogs:
		if dog != null and dog.carrying() > 0:
			return false
	# Only the flights bound for the crate, which are the ones the net throws and the ones
	# alone that carry no tag (`_on_haul_arrived`): cargo crossing to a hull and cargo a
	# ferry is landing at a pier are both tagged, and both are stock already.
	return _haul == null or _haul.flying_to(null) == 0


## The shimmer before the words. Run down every frame once the lake is finished; the words
## are raised on the frame it reaches zero, and never again (the farewell itself is the
## guard after that).
func _count_the_beat(delta: float) -> void:
	if _ending_in <= 0.0:
		return
	_ending_in -= delta
	if _ending_in <= 0.0:
		_ending_in = 0.0
		_show_farewell()


## Whether the ending is up: the shimmer it opens on, or the words themselves. What the
## music station is told, so the end song comes in with the beat rather than with the text.
func ending() -> bool:
	return _ending_in > 0.0 or _farewell != null


## Lay the closing words over the lake.
func _show_farewell() -> void:
	if _farewell != null:
		return
	_farewell = Farewell.new()
	_farewell.dismissed.connect(_drop_farewell)
	_farewell.to_menu.connect(_quit)
	# A cleaned lake is not the end of the game any more, only the end of the quiet part.
	var onward := _next_scene()
	if onward != "":
		_farewell.offer_onward()
		_farewell.onward.connect(_go_onward.bind(onward))
	else:
		# A lake with nowhere to go on to is the end of the game, so the credits roll under
		# the words (2026-09-16). A level that leads somewhere does not end anything.
		_farewell.roll_credits()
	# Its own layer, above the HUD rather than beside it: the closing words are the one thing
	# in the game that everything else — the island, the meter, the money — goes behind.
	var over := CanvasLayer.new()
	over.name = &"Farewell"
	over.layer = 20
	over.add_child(_farewell)
	add_child(over)
	_push_rooms()
	_hold_the_angler()


## The player has read it. Let go of it at once rather than when it finishes fading, so the
## angler gets their legs back on the click rather than half a second after it.
## Where the ending leads, or an empty string for a level that is the last one. The siege
## is set aside (2026-09-12): the cleaned lake ends here, and the farewell's door is the
## menu's.
func _next_scene() -> String:
	return ""


## Take the door. The run is written first: what carries into the next level is read back
## out of the save, so the save has to be the finished one before the scene goes away.
func _go_onward(scene: String) -> void:
	save_game()
	_farewell = null
	get_tree().change_scene_to_file(scene)


func _drop_farewell() -> void:
	_farewell = null
	_push_rooms()
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
		_menu_open or _settings_open or _shed_open or _controls_open
		or _farewell != null
	)
	_angler.can_walk = not busy
	# The net is held where it is for as long as the panel is up, and goes back to reeling
	# itself in the moment the water is in front of the player again. Nothing is held down,
	# so nothing is dropped by opening the shed mid-cast.
	_net.set_pulling(not busy)
	if _net2 != null:
		_net2.set_pulling(not busy)


## The music is the `Music` station's (`scripts/music_station.gd`): an autoload, so the song
## that was playing on the menu carries on into the lake rather than starting over. The lake
## only says where the player is; how loud it is is the Music bus's, set by the settings
## board through `Prefs`.
func _start_music() -> void:
	var music := MusicStation.main()
	if music != null:
		music.leave_rooms()
	_push_rooms()


## Tell the station where the player is. The shed is Indie Boi through its wall; the upgrades
## board and the settings are the lake's own song through the radio; the closing words are
## Habibs. Called whenever one of those opens or closes.
func _push_rooms() -> void:
	# The upgrades board covers the lake, so the lake goes quiet behind it: the song through
	# the radio, the ambience, and the money. See `Sfx.WHILE_SHOPPING`.
	if _sfx != null:
		_sfx.shopping = _menu_open
		_sfx.indoors = _shed_open
	var music := MusicStation.main()
	if music == null:
		return
	music.indoors = _shed_open
	music.muffled = _menu_open or _settings_open
	music.set_ending(ending())


## The way out of the lake is the menu, not the desktop (2026-09-12): the run is written
## first, and the menu's own Quit and the window's cross are what close the game.
func _quit() -> void:
	save_game()
	_farewell = null
	get_tree().change_scene_to_file(MENU_SCENE)


## A piece lifted off the water, the moment the net's mouth closes on it. The meter moves
## here and nowhere else: the water reads as cleaner the instant the piece is out of it,
## not whenever the haul happens to finish crossing the lake to the angler.
func _on_net_caught(def_index: int) -> void:
	var def := _grid.defs[def_index]
	_filth_left = maxf(_filth_left - def.pollution, 0.0)
	_filth_stale = true
	pollution = clampf(_filth_left / _filth_total, 0.0, 1.0)


## A sweep of a mouth that took something: open a clean patch there. Every sweep its own
## patch with its own roll (Richard, 2026-09-13): a reel that takes on its way home was
## growing the one patch it had, which repeated the same shape at every grab; now each grab
## is a new pool of clean water in a new shape, and the cap keeps a long drag from piling
## them up.
func _on_net_swept(at: Vector2, taken: int, hold: int, mouth: float, _net_from: CastNet) -> void:
	var radius := patch_radius(taken, hold, mouth)
	var fresh := {"at": at, "radius": radius, "born": _patch_clock, "seed": _patch_rng.randf()}
	if _patches.size() < PATCHES:
		_patches.append(fresh)
		return
	var oldest := 0
	for i in _patches.size():
		if float(_patches[i]["born"]) < float(_patches[oldest]["born"]):
			oldest = i
	_patches[oldest] = fresh


## How far a catch's clean patch reaches, in world px along the long axis: the mouth that
## made it, plus PATCH_REACH tiles more in proportion to how much of the hold it took.
func patch_radius(taken: int, hold: int, mouth: float) -> float:
	var share := clampf(float(taken) / float(maxi(hold, 1)), 0.0, 1.0)
	return mouth + Iso.tile_circle_extent(PATCH_REACH) * share


## How open a patch is, 0 at the catch, 1 whole, 0 gone: opening over PATCH_IN, whole
## through PATCH_HOLD of its life, then closing over the rest, both ends eased so nothing
## snaps.
func _patch_open(patch: Dictionary) -> float:
	var age := _patch_clock - float(patch["born"])
	if age < PATCH_IN:
		var u := clampf(age / PATCH_IN, 0.0, 1.0)
		return u * u * (3.0 - 2.0 * u)
	var t := clampf((age / PATCH_LIFE - PATCH_HOLD) / (1.0 - PATCH_HOLD), 0.0, 1.0)
	return 1.0 - t * t * (3.0 - 2.0 * t)


## Every frame: age the patches, drop the ones that have closed, hand the rest to the water.
func _push_patches(delta: float) -> void:
	_patch_clock += delta
	for i in range(_patches.size() - 1, -1, -1):
		if _patch_clock - float(_patches[i]["born"]) >= PATCH_LIFE:
			_patches.remove_at(i)
	if _water_material == null:
		return
	var packed := PackedVector4Array()
	packed.resize(PATCHES)
	var seeds := PackedFloat32Array()
	seeds.resize(PATCHES)
	for i in mini(_patches.size(), PATCHES):
		var patch := _patches[i]
		var at: Vector2 = patch["at"]
		packed[i] = Vector4(at.x, at.y, float(patch["radius"]), _patch_open(patch))
		seeds[i] = float(patch["seed"])
	_water_material.set_shader_parameter(&"patches", packed)
	_water_material.set_shader_parameter(&"patch_seeds", seeds)


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
	# rather than when the hull tipped it, so the purse and the picture agree. It goes on
	# the yard's heap, and a coin sets off from there for the plate (2026-09-13).
	var sale := tag as Dropoff
	if sale != null:
		sale.put(def_index)
		# Not while the shed is up: its room covers the lake and the money plate with it.
		if _coins != null and not _shed_open:
			_coins.fly(sale.drop_point())
		_on_sold(PackedInt32Array([def_index]), sale.kind)
		return
	_yard.put(def_index)


## A pigeon in the net. Paid on the spot: it never reaches the yard, it is not a material
## any merchant buys, and it was never part of the lake's filth — so the meter does not
## move for it either.
func _on_bird_caught(at: Vector2) -> void:
	sludge += bird_pay()
	birds_caught += 1
	if _splash != null:
		_splash.splash(at, 0.55)
	# And, on some catches, the bird itself: the head at the side of the screen and the coo
	# that goes with it, both off the one roll. They are halves of the same joke — a coo with
	# no bird is a noise from nowhere, and a bird with no coo is a picture — so either both
	# happen or neither does. The money is not part of the bargain and arrives every time.
	var showing := _pop_rng.randf() < POP_ODDS
	if showing:
		showing = _pigeon != null and _pigeon.pop(roundi(bird_pay()))
		if _sfx != null:
			_sfx.play_coo()
	# And a coin to the purse, the way a sale at a yard sends one (2026-09-16). A pigeon is
	# the only thing in the game that pays on the spot, and it was the only money in the game
	# that arrived with nothing crossing the screen.
	#
	# **It leaves the bird.** With the head coming in, that is the head, and the coin waits
	# for it (`_on_pigeon_arrived`) — a coin setting off from an empty edge of the screen a
	# tenth of a second before the pigeon got there is money from nowhere. With no head this
	# catch, it leaves the bird's own splash out on the water instead. Either way, one catch
	# is one coin.
	if not showing:
		_send_bird_coin(at)


## The head has finished coming in: the catch's coin sets off from it, in screen pixels,
## since the pop is drawn on its own CanvasLayer and is nowhere on the lake.
func _on_pigeon_arrived(at: Vector2) -> void:
	if _coins != null and not _shed_open:
		_coins.fly_from(at)


## The coin for a catch that gets no head, from the bird's own place on the water.
##
## Not while the shed is up, either way — its room covers the plate the coin is aimed at.
func _send_bird_coin(at: Vector2) -> void:
	if _coins != null and not _shed_open:
		_coins.fly(at)


## The pigeon in the corner, on its own layer just under the finds card: a bird is worth a
## laugh and a decoration is worth a look, and when both land at once the decoration wins.
func _build_pigeon_pop() -> void:
	_pigeon = PigeonPop.new()
	_pigeon.name = &"PigeonPop"
	_pigeon.arrived.connect(_on_pigeon_arrived)
	var over := CanvasLayer.new()
	over.name = &"Pigeon"
	over.layer = 18
	over.add_child(_pigeon)
	add_child(over)


## Coins from a sale to the purse, on the HUD's own layer after the skin, so they fly over
## the plate they land on. Under the pigeon and the finds card: a coin is a receipt, and
## those two are events.
func _build_coins() -> void:
	_coins = CoinFly.new()
	_coins.name = &"Coins"
	_coins.set_anchors_preset(Control.PRESET_FULL_RECT)
	_coins.target = _skin.coin_centre
	_coins.landed.connect(_on_coin_landed)
	_skin.get_parent().add_child(_coins)


## A coin reached the plate: the plate lights, and the coin says so.
func _on_coin_landed(_carry: int) -> void:
	_skin.shine()
	if _sfx != null:
		_sfx.play_chink()


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
	var piece := STARTER_BED
	if unlocked.has(piece):
		return
	unlocked.append(piece)
	if _room != null:
		# One cell in from the corner, as it always stood — in pixels now.
		_room.place(StringName(piece), Vector2i(ShedRoom.CELL, ShedRoom.CELL))


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
		_sfx.play_find_caught()


## The ferry landing a load at one of the four merchants. The purse moves here and nowhere
## else.
##
## The meter is not touched: anything the boat is carrying either came out of the yard,
## where it was already counted, or was skimmed out of the water on the way — and that
## second case is counted below, because it left the lake when the skimmer took it.
func _on_sold(cargo: PackedInt32Array, kind: int) -> void:
	for i in cargo.size():
		sludge += piece_pay(cargo[i], kind)
		sold_count += 1
	sold_by_kind[kind] += cargo.size()


## What one piece pays landed at the `kind` yard right now: the flat fee and the filth cut
## (`EconomyConfig`), times its weight tier's sell track, times the Recycle Bonus if that
## yard is the boosted one this moment.
func piece_pay(def_index: int, kind: int) -> float:
	var def := _grid.defs[def_index]
	var pay := _economy.piece_base_pay + def.pollution * _economy.piece_filth_pay
	# Heavier tiers always pay more than the tiers before them (Richard, 2026-09-14): a
	# step of the whole per tier, on top of the piece's own filth. `test_lake` guards the
	# order piece by piece, so a kind's pollution has to stay inside its tier's band.
	pay *= 1.0 + _economy.tier_pay_step * float(def.tier)
	pay *= tier_pay(def.tier)
	if kind == _bonus_kind:
		pay *= 1.0 + recycle_bonus()
	return pay


## The Recycle Bonus moves on: another yard than the one it was at, for a fresh window.
## Never the same yard twice running, so the bonus is seen to travel.
func _move_bonus() -> void:
	_bonus_left = BONUS_EVERY
	if _dropoffs.is_empty():
		_bonus_kind = -1
		return
	var others: Array[Dropoff] = _dropoffs.filter(func(d: Dropoff) -> bool: return d.kind != _bonus_kind)
	if others.is_empty():
		others = _dropoffs
	_bonus_kind = others[_luck_rng.randi_range(0, others.size() - 1)].kind
	for stop: Dropoff in _dropoffs:
		stop.boosted = stop.kind == _bonus_kind


## The bonus clock, ticked every frame once the first level is owned.
func _tick_bonus(delta: float) -> void:
	if _bonus_kind < 0:
		return
	_bonus_left -= delta
	if _bonus_left <= 0.0:
		_move_bonus()


## Which material's yard the Recycle Bonus is at, or -1 for none.
func bonus_kind() -> int:
	return _bonus_kind


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
	&"dog_fetch", &"dog_wait", &"dog_count",
	&"sell_0", &"sell_1", &"sell_2", &"sell_3", &"sell_4",
	&"recycle_bonus", &"bird_worth", &"lucky_haul", &"double_cast",
]

## What the market board calls each weight tier's sell track.
const TIER_NAMES := ["Light", "Small", "Medium", "Heavy", "Bulky"]

## What each upgrade is, one line, for the "?" in the corner of its row. Placeholder
## wording for now (2026-09-13): Richard writes the real lines once the rows read right.
const BLURBS := {
	&"net_width": "Placeholder: how wide the net's mouth opens, so one cast covers more water.",
	&"net_strength": "Placeholder: the heaviest weight tier the net can lift.",
	&"net_range": "Placeholder: how far from the shore the angler can throw.",
	&"reel": "Placeholder: how fast the net is reeled back in.",
	&"net_hold": "Placeholder: how many pieces one cast can carry home.",
	&"boat_speed": "Placeholder: how fast the ferry sails between the island and the yards.",
	&"cargo": "Placeholder: how many pieces the ferry carries a trip.",
	&"skimmer": "Placeholder: a skimmer on the ferry picks up rubbish as it sails.",
	&"fleet": "Placeholder: another ferry in the water.",
	&"dog_fetch": "Placeholder: how many pieces the dog brings back a trip.",
	&"dog_wait": "Placeholder: how long the dog lazes about between trips, at most.",
	&"dog_count": "Placeholder: another dog for the pack, trained like the first.",
	&"lucky_haul": "Placeholder: odds that a cast lifts one tier heavier and holds more.",
	&"double_cast": "Placeholder: odds that a cast throws a second net beside the first.",
	&"sell_0": "Placeholder: what light pieces sell for at the yards.",
	&"sell_1": "Placeholder: what small pieces sell for at the yards.",
	&"sell_2": "Placeholder: what medium pieces sell for at the yards.",
	&"sell_3": "Placeholder: what heavy pieces sell for at the yards.",
	&"sell_4": "Placeholder: what bulky pieces sell for at the yards.",
	&"recycle_bonus": "Placeholder: one yard at a time pays over the odds, and it moves.",
	&"bird_worth": "Placeholder: what a netted pigeon is worth.",
}


## How many upgrades could be bought right now. Drawn on the HUD's upgrades button, so that
## money worth spending says so on the way in rather than only once the board is open.
func _affordable() -> int:
	var count := 0
	if tree_mode:
		for n: Dictionary in _tree.nodes:
			var id: String = n["id"]
			if _tree.is_buyable(_tree_owned, id) and sludge >= _tree.cost(_tree_owned, id):
				count += 1
		return count
	for key: StringName in TRACKS:
		if key in SHELVED:
			continue
		if not is_maxed(key) and sludge >= cost_of(key):
			count += 1
	return count


## Every upgrade as one row of the drawn boards: which board it stands on, what it is,
## what it does now and what the next level buys, what that costs, and whether it can be
## paid for.
##
## Percentages and whole numbers only (Richard, 2026-09-13): a track that scales a rate
## reads as a percent over its level 0 ("+40%"), a track that counts reads as the count
## ("3 per cast"), and the next level's figure follows in brackets. No tenths anywhere.
func _shop_rows() -> Array:
	var out: Array = []
	# Each line: key, board, name, and what the value reads at a given level.
	var listed := [
		[&"net_width", &"net", "Width", func(l: int) -> String: return _pct_at(&"net_width", l)],
		[&"net_strength", &"net", "Strength", func(l: int) -> String:
			return "Tier %d" % int(_track_value(&"net_strength", l))],
		[&"net_range", &"net", "Range", func(l: int) -> String: return _pct_at(&"net_range", l)],
		[&"reel", &"net", "Speed", func(l: int) -> String: return _pct_at(&"reel", l)],
		[&"net_hold", &"net", "Haul", func(l: int) -> String:
			return "%d per cast" % int(_track_value(&"net_hold", l))],
		[&"boat_speed", &"boat", "Speed", func(l: int) -> String: return _pct_at(&"boat_speed", l)],
		[&"cargo", &"boat", "Hold", func(l: int) -> String:
			return "%d aboard" % int(_track_value(&"cargo", l))],
		[&"fleet", &"boat", "Extra ferry", func(l: int) -> String: return "%d in the water" % (1 + l)],
		[&"dog_fetch", &"dog", "Fetching", func(l: int) -> String:
			return "%d per trip" % int(_track_value(&"dog_fetch", l))],
		[&"dog_wait", &"dog", "Keenness", func(l: int) -> String:
			return "waits %ds at most" % roundi(maxf(
				Dog.MOOD_MOST - _track_value(&"dog_wait", l), Dog.MOOD_LEAST
			))],
		[&"dog_count", &"dog", "Pack", func(l: int) -> String:
			return "%d dog%s" % [1 + l, "" if l == 0 else "s"]],
		[&"lucky_haul", &"net", "Lucky haul", func(l: int) -> String:
			return "%d%%: +1 tier, +%d held" % [
				roundi(_track_value(&"lucky_haul", l) * 100.0), LUCKY_EXTRA
			]],
		[&"double_cast", &"net", "Double cast", func(l: int) -> String:
			return "%d%%: second net" % roundi(_track_value(&"double_cast", l) * 100.0)],
	]
	listed.append([&"recycle_bonus", &"market", "Recycle Bonus", func(l: int) -> String:
		if l <= 0:
			return "off"
		var bonus := "+%d%%" % roundi(_track_value(&"recycle_bonus", l) * 100.0)
		if l != recycle_bonus_level or _bonus_kind < 0:
			return bonus
		return "%s %s, %ds" % [bonus, TrashDef.KIND_NAMES[_bonus_kind].to_lower(), ceili(_bonus_left)]
	])
	listed.append([&"bird_worth", &"market", "Pigeons", func(l: int) -> String:
		return "$%d a bird" % roundi(_economy.bird_bonus * _track_value(&"bird_worth", l))])
	for line: Array in listed:
		var key: StringName = line[0]
		var full := is_maxed(key)
		var price := cost_of(key)
		var level := _level_of(key)
		var reads: Callable = line[3]
		var now: String = reads.call(level)
		out.append({
			"key": key,
			"board": line[1],
			"name": line[2],
			# Its own field, not part of the name: the shop draws it in the clean water's blue
			# so the level stands off the name (2026-09-11), and small (2026-09-13).
			"level": "Lvl %d" % level,
			# What it does now, and what the next level buys after it, unless there is none.
			"value": now if full else "%s  (%s next)" % [now, reads.call(level + 1)],
			# What the upgrade is, for the row's "?" — placeholder wording for now.
			"blurb": String(BLURBS.get(key, "")),
			# A track with nothing left to sell says so in a word: a dash reads as a price
			# that failed to print.
			"cost": "Max" if full else "$%d" % roundi(price),
			"afford": not full and sludge >= price,
		})
	return out


## A track's value at a level, straight off the resource. The shop's rows ask for the
## level after the one owned too, which no getter answers.
func _track_value(key: StringName, level: int) -> float:
	var track: UpgradeTrack = _upgrades.get(key)
	if track == null:
		return 0.0
	return track.value(level)


## A scaling track as a percent over its level 0: "+0%" to begin with, "+40%" later. A
## track whose base is nothing has no percent to be over and reads as its plain number.
func _pct_at(key: StringName, level: int) -> String:
	var base := _track_value(key, 0)
	if base <= 0.0:
		return "%d" % roundi(_track_value(key, level))
	return "+%d%%" % roundi((_track_value(key, level) / base - 1.0) * 100.0)


## `skim_chance` at any level, not only the one owned.
func _skim_chance_at(level: int) -> float:
	if level < 1:
		return 0.0
	var top := float(MAX_LEVELS[&"skimmer"])
	return clampf(lerpf(SKIM_FIRST_CHANCE, 1.0, float(level - 1) / (top - 1.0)), 0.0, 1.0)


## What the market's legend under the boards says (2026-09-13, second pass, Richard):
## the four materials with what a piece of each pays on average, the tiers with their sell
## rates, and one line of explanation. Nothing else — the first pass said too much.
func _shop_legend() -> Dictionary:
	# The sell-by-tier rates used to stand here; the tracks are shelved (2026-09-14).
	var tiers: Array = []
	var yards: Array = []
	for kind in TrashDef.KIND_NAMES.size():
		yards.append([TrashDef.KIND_NAMES[kind], "$%d" % roundi(_mean_pay_of(kind))])
	return {
		"tiers": tiers,
		"yards": yards,
		"rule": "Each material sells at its own yard. Heavier pieces always pay more.",
	}


## What a piece of one material pays on average at its own yard, over the rubbish kinds of
## that material (finds are not for sale), at today's tier rates and bonus.
func _mean_pay_of(kind: int) -> float:
	if _grid == null:
		return 0.0
	var total := 0.0
	var count := 0
	for i in _grid.defs.size():
		var def: TrashDef = _grid.defs[i]
		if def.keepsake or int(def.material) != kind:
			continue
		total += piece_pay(i, kind)
		count += 1
	return total / float(count) if count > 0 else 0.0


## The net's numbers, from the levels the player has now.
##
## Pushed whenever they change rather than only at the moment of a cast. The ring drawn on
## the water is the net's own range, so a net that has not been thrown since the game started
## draws the range it was built with — which on a loaded save is a ring for somebody else's
## rod. It is the first thing on screen and it was the one thing lying about the save.
func _push_net_numbers() -> void:
	for net: CastNet in [_net, _net2]:
		if net == null:
			continue
		net.radius = net_radius()
		net.power = net_power()
		net.range_tiles = net_range()
		net.reel_speed = reel_speed()
		net.hold = net_hold()


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
		&"dog_count":
			return dog_count_level
		&"recycle_bonus":
			return recycle_bonus_level
		&"bird_worth":
			return bird_worth_level
		&"lucky_haul":
			return lucky_haul_level
		&"double_cast":
			return double_cast_level
		_:
			var tier := _sell_tier(what)
			return sell_levels[tier] if tier >= 0 else 0


## Which weight tier a `sell_N` track is for, or -1 for any other track.
func _sell_tier(what: StringName) -> int:
	var key := String(what)
	if not key.begins_with("sell_"):
		return -1
	var tier := key.trim_prefix("sell_").to_int()
	return tier if tier >= 0 and tier < sell_levels.size() else -1


## Whether a track has sold everything it has. The board, the old buttons and the buy
## itself all ask here, so the three cannot disagree about what is still for sale.
func is_maxed(what: StringName) -> bool:
	return _level_of(what) >= _level_cap(what)


## One track's level out of a save, held to what the track now sells.
func _saved_level(levels: Dictionary, what: StringName) -> int:
	return clampi(int(levels.get(String(what), 0)), 0, _level_cap(what))


func _buy(what: StringName) -> void:
	if is_maxed(what) or what in SHELVED:
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
		&"dog_count":
			dog_count_level += 1
			_add_dog()
		&"recycle_bonus":
			recycle_bonus_level += 1
			# The first level starts the clock: until then no yard is boosted.
			if _bonus_kind < 0:
				_move_bonus()
		&"bird_worth":
			bird_worth_level += 1
		&"lucky_haul":
			lucky_haul_level += 1
		&"double_cast":
			double_cast_level += 1
		_:
			var tier := _sell_tier(what)
			if tier >= 0:
				sell_levels[tier] += 1
	# After the level goes on, not before: the sound is the purchase landing, and a buy that
	# fell through above has already returned without making one. The sparkle over the
	# board's sprite is the same receipt for the eye.
	if _sfx != null:
		_sfx.play_bought()
	_shop_skin.cheer(what)
	_push_net_numbers()
	_push_boat_numbers()
	_push_dog_numbers()


# ------------------------------------------------------------------ tree test mode
# See `tree_mode`. Everything below runs only in a tree run.

## Reads the tree file when this is a tree run. A file that does not load leaves the run as an
## ordinary one, on the ordinary save, rather than half a tree, and says why.
func _setup_tree() -> void:
	if start_tree:
		tree_mode = true
		save_path = TREE_SAVE_PATH
		start_tree = false
	if not tree_mode:
		return
	_tree = UpgradeTree.load_file()
	if not _tree.error.is_empty():
		push_error("Lake: tree mode is off, %s" % _tree.error)
		tree_mode = false
		_tree = null
		if save_path == TREE_SAVE_PATH:
			save_path = SAVE_PATH
		return
	if not _tree.unused_stats.is_empty():
		push_warning("Lake: the tree changes stats the game does not read: %s" % ", ".join(_tree.unused_stats))
	_tree_stats = _tree.stats(_tree_owned)


func _tree_stat(stat: String) -> float:
	return float(_tree_stats.get(stat, 0.0))


## Stats recomputed from what is owned, and the world brought in line with them.
func _apply_tree(push: bool = true) -> void:
	_tree_stats = _tree.stats(_tree_owned)
	_sync_tree_world()
	if push:
		_push_net_numbers()
		_push_boat_numbers()
		_push_dog_numbers()


## In a tree run the ferries and the dog exist only once they are bought. The first ferry is
## the scene's own hull, kept hidden and still until then; the rest are built as they are paid
## for, exactly as the shop's Extra ferry builds them.
func _sync_tree_world() -> void:
	var want := fleet_size()
	while _boats.size() < want:
		_add_boat()
	for i in _boats.size():
		var on := i < want
		_boats[i].visible = on
		_boats[i].set_process(on)
		_reberth(_boats[i], i)
	for i in _dogs.size():
		# The tree adopts one dog; the pack is the shop's.
		var adopted := _tree_stat("dog") >= 1.0 and i == 0
		_dogs[i].visible = adopted
		_dogs[i].set_process(adopted)
	# The Recycle Bonus clock starts with the first node that gives a bonus, as the shop's first
	# level does; until then no yard shines.
	if _bonus_kind < 0 and recycle_bonus() > 0.0:
		_move_bonus()


func _build_tree_screen() -> void:
	_tree_screen = TreeScreen.new()
	_tree_screen.name = &"TreeScreen"
	_tree_screen.tree = _tree
	_tree_screen.owned = _tree_owned
	_tree_screen.money_of = func() -> float: return sludge
	_tree_screen.visible = false
	_shop_skin.get_parent().add_child(_tree_screen)
	_tree_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tree_screen.buy_asked.connect(buy_node)
	_tree_screen.close_asked.connect(_shut.bind(_set_menu))


## A tree run has begun: fresh (the file's starting money, nothing owned) or from its save.
func _begin_tree_session(loaded: bool) -> void:
	if not loaded:
		_tree_owned.clear()
		_tree_play = 0.0
		sludge = _tree.start_money
		_apply_tree()
	_tree_progress_in = 0.0
	TreeLog.write("session", _tree_play, {
		"started": "continue" if loaded else "new",
		"tree_file": UpgradeTree.PATH,
		"nodes": _tree.nodes.size(),
		"owned": _tree_owned.keys(),
		"sludge": roundi(sludge),
		"cleared": snappedf(_cleared_share(), 0.0001),
	})


## Buying a node off the tree screen. The same rules the screen draws by: visible, not already
## owned to its last rank, and paid for.
func buy_node(id: String) -> void:
	if not tree_mode or not _tree.is_buyable(_tree_owned, id):
		return
	var price := _tree.cost(_tree_owned, id)
	if sludge < price:
		return
	sludge -= price
	_tree_owned[id] = _tree.rank_of(_tree_owned, id) + 1
	_apply_tree()
	if _sfx != null:
		_sfx.play_bought()
	if _tree_screen != null:
		_tree_screen.bought()
	TreeLog.write("purchase", _tree_play, {
		"id": id,
		"rank": _tree_owned[id],
		"cost": roundi(price),
		"sludge_after": roundi(sludge),
		"cleared": snappedf(_cleared_share(), 0.0001),
		"box": _yard.held.size(),
	})


## Share of the lake's pieces gone since it was built, for the playtest log.
func _cleared_share() -> float:
	return 1.0 - float(_grid.piece_count()) / float(maxi(_pieces_full, 1))


func _tick_tree_log(delta: float) -> void:
	_tree_play += delta
	_tree_progress_in -= delta
	if _tree_progress_in > 0.0:
		return
	_tree_progress_in = TREE_PROGRESS_EVERY
	TreeLog.write("progress", _tree_play, {
		"cleared": snappedf(_cleared_share(), 0.0001),
		"pieces_left": _grid.piece_count(),
		"sludge": roundi(sludge),
		"birds": birds_caught,
		"box": _yard.held.size(),
		"ferries": fleet_size(),
		"owned": _tree_owned.size(),
		"in_shed": _shed_open,
		"tree_open": _menu_open,
	})


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
	if tree_mode:
		return maxi(int(_tree_stat("boats")), 0)
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
	for dog in _dogs:
		dog.fetch_most = dog_fetch()
		dog.wait_cut = dog_wait_cut()
		if tree_mode:
			# The tree's dog numbers are relative to the file's base (6 tiles, 0.35 of trips,
			# pace 1), so a base dog is exactly today's dog and the nodes scale it from there.
			var base_reach := maxf(float(_tree.base_stats.get("dog_reach", 6.0)), 0.001)
			dog.reach = Dog.REACH * _tree_stat("dog_reach") / base_reach
			var beach := _tree_stat("dog_beach")
			dog.strand_first = beach if beach > Dog.STRAND_ODDS else 0.0
			dog.strand_speed = maxf(_tree_stat("dog_strand_speed"), 0.1)


## How many dogs the pack has: the first plus what `dog_count` bought. The tree has one.
func dog_count() -> int:
	if tree_mode:
		return 1
	return 1 + dog_count_level


## The nearest dog the angler could pet from where they stand, or null.
func _dog_in_reach() -> Dog:
	var best: Dog = null
	var best_gap := INF
	for dog in _dogs:
		if dog == null or not dog.visible or not dog.within_reach(_angler.tile_pos):
			continue
		var gap := dog.tile_pos.distance_to(_angler.tile_pos)
		if gap < best_gap:
			best_gap = gap
			best = dog
	return best


## Wire a dog the way the scene's first one is wired: the water to fish out of, somebody to
## be pleased to see, the crate to put things in, the day for its shadow. One place, so a
## dog bought later cannot be missing something the first one has.
func _fit_dog(dog: Dog) -> void:
	dog.grid = _grid
	dog.angler = _angler
	dog.day = _day
	dog.fetched.connect(_dog_brought_back)
	dog.petted.connect(func() -> void:
		if _sfx != null:
			_sfx.play_sniff()
	)
	_push_dog_numbers()


## A dog bought for the pack: the scene's dog again, standing a stride off from the others
## so the new one is seen to arrive, drawn on the walkers' layer like the first.
func _add_dog() -> void:
	if _dogs.size() >= MAX_DOGS:
		return
	var dog := Dog.new()
	dog.name = &"Dog%d" % _dogs.size()
	dog.z_index = _dog.z_index
	dog.z_as_relative = false
	dog.tile_pos = _dog.tile_pos + Vector2(0.9, -0.6) * float(_dogs.size())
	dog.crate_tile = _dog.crate_tile
	dog.splash = _splash
	dog.prints = _prints
	_dogs.append(dog)
	_fit_dog(dog)
	add_child(dog)


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
		if boat.visible and boat.dispatch():
			return


func _set_auto_ferry(on: bool) -> void:
	for boat in _boats:
		boat.auto_ferry = on


## How fast the view drifts to keep up with the angler: the share of the gap it closes a
## second, see `_ease`. Its speed is its distance from what it is following, which is what
## makes a fast net a fast camera — `HOME_SPEED` is the ceiling over it on the way home.
const FOLLOW_SPEED := 6.0


## The net's wash, pushed every frame.
##
## The fleet's own engine loop went with the diesel it was built from (2026-09-15): the ferry
## is a sail boat, the water it pushes and its bell say it is leaving, and a loop under the
## whole game was heard as a wind and a tick.
func _push_engine() -> void:
	if _sfx == null:
		return
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
	_pad_tick(delta)
	_push_daylight()
	_part_the_fleet(delta)
	_remap_filth(delta)
	_push_patches(delta)
	_tick_bonus(delta)
	if _net2 != null:
		_net2.visible = _net2.state != CastNet.State.IDLE
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
	var walking := (
		_angler_was != Vector2.INF and _angler_was.distance_to(_angler.tile_pos) > 0.001
	)
	if walking:
		_pan_yielded = true
	_angler_was = _angler.tile_pos

	# A cast takes the view back off whoever panned it away, and goes on taking it until it
	# has all of it. Not while they are still holding the button, though — a hand on the
	# mouse outranks the net.
	if _pan_yielded and not _panning and _pan != Vector2.ZERO:
		_pan = _pan.lerp(Vector2.ZERO, _ease(PAN_RELEASE, delta))
		if _pan.length() < 1.0:
			_pan = Vector2.ZERO

	# The view is clamped to the ground, so the pan it is dragged by is clamped with it.
	# Dragged past the edge, the surplus is dropped rather than wound up out of sight —
	# wound up, dragging back did nothing until all of it had been unwound, which at the far
	# end of the zoom, where the edge is a hand's width away, read as the sides sticking.
	# Only a pan there is: a view the ground alone holds off the angler is not a pan, and
	# writing the clamp back into an empty one would make it one.
	if _pan != Vector2.ZERO:
		var bare := _watching() - _pan
		_pan = _clamped_view(bare + _pan) - bare

	# The way home is capped, see HOME_SPEED: from the first frame of the haul until the
	# view is back on the angler. A throw lifts it — the throw is not capped — and so does
	# the angler walking off once the net is in, since the view is then following them and
	# not coming home from anything. A hand on the mouse snaps the view to wherever it
	# wants to be, which ends the way home as surely as arriving does.
	match _net.state:
		CastNet.State.REELING:
			_homing = true
		CastNet.State.FLYING:
			_homing = false
		CastNet.State.IDLE:
			if walking or _panning or (_watching() - _camera.position).length() < 1.0:
				_homing = false

	# Eased while it is following something, and snapped while the player is dragging it:
	# a view that lags a hand on the mouse feels like a view being argued with.
	if _panning:
		_camera.position = _clamped_view(_watching())
	else:
		var step := (_watching() - _camera.position) * _ease(FOLLOW_SPEED, delta)
		if _homing:
			step = step.limit_length(HOME_SPEED * delta)
		var at := _camera.position + step
		# The flying net pushes the view along if the ease has fallen behind it, so it
		# comes down inside the margin however short the throw was. The throw only: on
		# the haul the cap outranks the frame, and the net is coming towards the middle of
		# the screen anyway.
		if _net.state == CastNet.State.FLYING:
			at = _framed_on(at, _net.tile_pos)
		_camera.position = _clamped_view(at)

	_look_for_the_end(delta)
	_count_the_beat(delta)
	if tree_mode:
		_tick_tree_log(delta)

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
		var stood := _walker_layer(_angler.position)
		_angler.z_index = stood
		# The net and its rope go with the angler, one layer under (2026-09-16, Richard:
		# casting north off solid ground, the end of the rope showed against the player).
		#
		# The net's job here is to be *behind* the figure — the rope starts inside the
		# outline and the body is what hides its cut end, see `CastNet._lay_rope`. That was
		# written against a fixed z 8 and an angler on 9, and it quietly stopped being true
		# wherever the angler drops a band: behind the hut they are on 5 and behind the
		# crate on 7, so the net and the whole rope with it were drawn over the player.
		# Following the walker rule is what makes "behind the angler" mean it everywhere.
		#
		# The cost, behind the hut only: the net goes to 4, under the floating rubbish at 5,
		# so the rope passes behind junk on its way out. The angler is already tied with the
		# soup on that band; a two-pixel line going under a bottle is the lesser wrong.
		if _net != null:
			_net.z_index = stood - 1
		if _net2 != null:
			_net2.z_index = stood - 1
	for dog in _dogs:
		dog.z_index = _walker_layer(dog.position)


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
	var at := _angler.position
	if _cast_look > 0.001:
		at = at.lerp(Iso.tile_to_world(_net.tile_pos.x, _net.tile_pos.y), _cast_look)
	# And out past that as far as the landing needs, see LAND_INSET: towards where the net
	# is going while it flies, taken up over the first FRAME_BY of the flight; and towards
	# where it is once it is down, where the pull shrinks as the net comes in and hands the
	# view back to CAST_LOOK's point on its own — no seam where it lets go.
	match _net.state:
		CastNet.State.FLYING:
			var flown := _net.cast_progress() / CastNet.THROW_SHARE
			at = at.lerp(_framed_on(at, _net.target), clampf(flown / FRAME_BY, 0.0, 1.0))
		CastNet.State.SETTLED, CastNet.State.REELING:
			at = _framed_on(at, _net.tile_pos)
		CastNet.State.IDLE:
			if _aim.at != Vector2.INF:
				at = _pad_framed(at)
	return at + _pan


## `at`, leaned out towards the pad's reticle until the ghost mouth under it is inside the
## same margin a landing net is framed in (`_framed_on`), and then held back so the angler
## stays inside `PAD_ANGLER_INSET` of the window. Only as far as it needs: a reticle already
## well inside the view moves nothing.
func _pad_framed(at: Vector2) -> Vector2:
	var framed := _framed_on(at, Iso.world_to_tile(_aim.at))
	var half := get_viewport_rect().size / _camera.zoom * 0.5 * (1.0 - PAD_ANGLER_INSET)
	return framed.clamp(_angler.position - half, _angler.position + half)


## `at`, pulled towards the tile `spot` until a window centred on the result has the net's
## whole mouth inside its middle, see LAND_INSET. Left alone when it already has, which is
## every short cast. Only ever towards the net.
func _framed_on(at: Vector2, spot: Vector2) -> Vector2:
	var net := Iso.tile_to_world(spot.x, spot.y)
	var half := get_viewport_rect().size / _camera.zoom * 0.5 * (1.0 - LAND_INSET)
	# The mouth's full width both ways: the drawn net is wider than it is tall, but the
	# crown and the bundle in a throw stand up off the water, and a margin that is a
	# little generous down the screen costs nothing.
	var room := (half - Vector2.ONE * _net.open_extent()).max(Vector2.ZERO)
	return Vector2(
		clampf(at.x, net.x - room.x, net.x + room.x),
		clampf(at.y, net.y - room.y, net.y + room.y)
	)


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
	_shop_skin.legend = _shop_legend()

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
			"dog_count": dog_count_level,
			"sell_0": sell_levels[0], "sell_1": sell_levels[1], "sell_2": sell_levels[2],
			"sell_3": sell_levels[3], "sell_4": sell_levels[4],
			"recycle_bonus": recycle_bonus_level, "bird_worth": bird_worth_level,
			"lucky_haul": lucky_haul_level, "double_cast": double_cast_level,
		},
		"caught": caught,
		"sold_count": sold_count,
		"birds_caught": birds_caught,
		"sold_by_kind": sold_by_kind,
		"runs_done": _runs_done(),
		"auto_ferry": _auto_ferry.button_pressed,
		# The settings are not in here, by decision (2026-09-15): they are `Prefs`', written
		# to user://settings.cfg on every press, and one set of them across the menu and the
		# lake. A save that carried its own copy handed it back on load and undid whatever the
		# player had set on the menu.
		"farewell": _farewell_shown,
		"angler": _angler.tile_pos,
		"yard_held": _yard.held,
		"unlocked": unlocked,
		"decor": decor,
		"afloat": afloat,
		"stacks": _grid.stacks,
	}
	if tree_mode:
		save["tree"] = true
		save["tree_owned"] = _tree_owned
		save["tree_play"] = _tree_play
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
	var readable := written == SAVE_VERSION or written == SAVE_SHED_CELLS
	if save == null or not readable 			or int(save.get("seed", 0)) != _level_seed():
		_note_save("the save is from another build — ignored")
		return false
	# A tree run and a shop run never read each other's file: their upgrades are not the same
	# thing, and a ferry bought one way would be a ferry nobody paid for the other.
	if bool(save.get("tree", false)) != tree_mode:
		_note_save("the save is from the other mode — ignored")
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
	for tier in sell_levels.size():
		sell_levels[tier] = _saved_level(levels, StringName("sell_%d" % tier))
	recycle_bonus_level = _saved_level(levels, &"recycle_bonus")
	bird_worth_level = _saved_level(levels, &"bird_worth")
	lucky_haul_level = _saved_level(levels, &"lucky_haul")
	double_cast_level = _saved_level(levels, &"double_cast")
	# The bonus clock starts over on a load; which yard it lands on first is the roll's.
	_bonus_kind = -1
	_bonus_left = 0.0
	if recycle_bonus_level > 0:
		_move_bonus()

	sludge = float(save.get("sludge", 0.0))
	caught = int(save.get("caught", 0))
	sold_count = int(save.get("sold_count", 0))
	birds_caught = int(save.get("birds_caught", 0))
	sold_by_kind = PackedInt32Array(save.get("sold_by_kind", PackedInt32Array([0, 0, 0, 0])))
	if tree_mode:
		_tree_owned.clear()
		_tree_owned.merge(_tree.sanitize(save.get("tree_owned", {}) as Dictionary))
		_tree_play = float(save.get("tree_play", 0.0))
		_apply_tree(false)

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
	# A version 9 file holds cells; this build places in pixels. See SAVE_SHED_CELLS.
	var decor_scale := ShedRoom.CELL if written == SAVE_SHED_CELLS else 1
	for row: Dictionary in save.get("decor", []) as Array:
		var name := String(row.get("piece", ""))
		if not unlocked.has(name):
			continue
		decor.append({
			"piece": name,
			"cell": [
				int((row["cell"] as Array)[0]) * decor_scale,
				int((row["cell"] as Array)[1]) * decor_scale,
			],
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
	var dogs_wanted := _saved_level(levels, &"dog_count")
	while dog_count_level < dogs_wanted:
		dog_count_level += 1
		_add_dog()
	for boat in _boats:
		boat.cargo.resize(0)
		boat.state = Boat.State.DOCKED
		boat.target = -1
		boat.tile_pos = boat.dock
		boat.runs_done = 0
	_boats[0].runs_done = int(save.get("runs_done", 0))
	for piece: int in PackedInt32Array(save.get("afloat", PackedInt32Array())):
		_yard.put(piece)

	# What the player has set comes from `Prefs`, not from the file: see save_game(). An old
	# save's copy of them is ignored.
	_settings.pull_prefs()
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
	if _room != null:
		_room.unlocked = unlocked
		_room.decor = decor
	_auto_ferry.button_pressed = bool(save.get("auto_ferry", true))
	_set_auto_ferry(_auto_ferry.button_pressed)
	_angler.stand_at(save.get("angler", _angler.tile_pos) as Vector2)
	if _trophy != null:
		_trophy.clear()
	for net: CastNet in [_net, _net2]:
		if net == null:
			continue
		net.set_pulling(false)
		net.state = CastNet.State.IDLE
		net.catch.resize(0)
		net.luck_power = 0
		net.luck_hold = 0
		net.tile_pos = _angler.tile_pos
	_push_net_numbers()
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
	start_tree = tree_mode
	if has_save():
		# The engine's own path, not a globalized one: on the web there is no such thing as
		# an absolute path to a save, and user:// is understood everywhere.
		DirAccess.remove_absolute(save_path)
	get_tree().reload_current_scene()


func _note_save(what: String) -> void:
	_save_note = what
	_save_note_for = 2.5


func _exit_tree() -> void:
	# The station is an autoload too, and the rooms it was told about were this scene's.
	var music := MusicStation.main()
	if music != null:
		music.leave_rooms()
	# The sound board is an autoload and outlives the lake: its engine, haul, fire and
	# ambience are the lake's and go with it.
	if _sfx != null:
		_sfx.hush()


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
		var picture := Rect2(stand - Vector2(size.x * 0.5, size.y), size)
		# The hut's shadow: its own silhouette dragged along the sun, on a node of its own
		# behind this one. Not `Shade.lying` — a shear anchored on any one line comes away
		# from a picture whose base is the near corner of a diamond. See Shade.sweep.
		if _day != null:
			_shed_shade().lay(
				Art.image(SHED_ART), picture, _day.lean, _day.stretch,
				Iso.SHED_ART_GROUND, _day.ink
			)
		_island.draw_texture_rect(_shed_art, picture, false)
		# And the grass over the bottom line, which is the whole point of it: the last row
		# of the picture is a straight cut, and blades standing along it are what stop the
		# hut reading as a sticker on the lawn.
		_shed_grass(picture).over(_island)
		# Over the hut, not over the tile: the two are not the same point.
		_draw_shed_lamp(feet)
		return

	_draw_shed_blocked(at)


## The node the hut's swept shadow lives on: a child of the island's canvas, drawn behind the
## island's own commands so the hut covers the half of the sweep that is under it. Made on
## first use, because the picture has to be there before there is anything to cast.
func _shed_shade() -> Shade.Cast:
	if _shed_cast == null:
		_shed_cast = Shade.Cast.new()
		_shed_cast.name = &"ShedShade"
		_island.add_child(_shed_cast)
	return _shed_cast


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
