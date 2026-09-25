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
##
## **That distance map is the stain's outline now, not its strength** (2026-09-17, Richard:
## "I see the same green shade, until I remove all the objects, then it turns clear on that
## spot"). Presence alone could not say anything until a tile was empty: every wet tile
## holds a stack, so lifting the top of one moved no water. The strength is how much
## rubbish the water round a tile still holds — see FILTH_POOL — and the two are
## multiplied, which keeps both halves of the old rule: water past the stain's reach is
## clean whatever the average says (no green over empty water), and water touching a piece
## is never clean (FILTH_FLOOR — no lone piece floating on blue).
const FILTH_BLUR := 3
const FILTH_FALL := 0.6

## How much rubbish an area holds: the pieces in every stack within FILTH_POOL tiles, over
## what those tiles could hold at Iso.MAX_SLOTS each — only the tiles the fill or the strand
## can put anything on, so the island's bare shelf does not water the figure down.
##
## Over the deepest a stack goes, not over what each tile started with, by decision: depth
## is already smooth across the basin (Iso.depth_at), so a fresh lake is darkest round the
## island and lightens to the bank, and nothing has to be saved — the map is still worked
## out from the stacks alone. Broad by decision too: one early cast moves nothing by
## itself, a handful in one bay moves it a shade.
##
## FILTH_SHARE_BITE bends the share before it is used: under one holds the water dark for
## longer, over one lightens it early. FILTH_FLOOR is what the strength bottoms out at
## where there is any rubbish at all, picked to land inside the first state past clean
## (LakeGrid.FILTH_STATE_AT) on a tile with a piece on it. `test_lake` guards that.
##
## **Towards the outer bank a tile's room is its own, not the deepest's** (FILTH_BANK_FROM,
## second pass the same day, Richard: "the beach shores are too clear... more grimy even
## with less objects"). Against nine slots a full two-deep shallow is a quarter full and
## read murky going hazy from the first frame. From FILTH_BANK_FROM of the way out to the
## bank the room eases from MAX_SLOTS to what the fill actually put there (the strand's
## tiles count FILTH_STRAND_ROOM), so a full shallow reads as dirty as a full deep bay —
## and still lightens a piece at a time, which a flat lift near the bank (asked for first,
## turned down on the pushback) would not: it holds until the last piece and then jumps.
## Outer bank only: by the island the weight is nought and nothing there moved.
const FILTH_POOL := 3
const FILTH_BANK_FROM := 0.5
const FILTH_STRAND_ROOM := 2
const FILTH_SHARE_BITE := 0.7
const FILTH_FLOOR := 0.34

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
## Slower and smoother again on 2026-09-16 (issue #31, Richard: the grime should get back
## together "a little bit slower", and continuously — not in beats): life 2 to 4 s, the
## opening 0.2 to 0.4 s, and PATCH_CLOSE_SOFT is the shader's `patch_soft`, raised so the
## threads thicken as a gradient rather than arriving. Continuous by his call, over a
## stepped or swell-timed close.
const PATCHES := 14
const PATCH_LIFE := 4.0
const PATCH_IN := 0.4
const PATCH_HOLD := 0.1
const PATCH_REACH := 0.5
const PATCH_CLOSE_SOFT := 0.6

## The lane a reel parts through the grime (issue #31, 2026-09-16, Richard: "a small clear
## way as it drags through grime before the grime gets back in again, very subtle but
## noticeable"). Only a net with a catch aboard leaves one — his call over every reel — so
## the lane is the catch being dragged home, not the net. A chain of small patches dropped
## every LANE_SPACING world px of travel along the mouth's path, LANE_WIDE of the mouth
## across, each closing over LANE_LIFE the way a patch does. One roll per reel
## (`_lane_seed`), so the chain reads as one lane rather than a string of beads.
## LANE_POINTS mirrors the shader's `lane[]`; past it the oldest point is reused, which is
## the tail of the lane closing anyway.
const LANE_POINTS := 24
const LANE_SPACING := 14.0
const LANE_WIDE := 0.5
const LANE_LIFE := 2.0
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
## Where the pump stands, in tiles off the middle of the hut's walls: out past the near
## right wall, clear of the roof's overhang, on the side the door is not. And how close the
## angler has to be to work it — well inside `SHOP_RANGE`, which the pump stands within, so
## beside the pump the key is the pump's and everywhere else round the hut it is the door's.
## By eye on `tools/shot_pump.tscn`.
const PUMP_AT := Vector2(2.1, -0.5)
const PUMP_RANGE := 1.5

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

## Per-track price curve, value curve, and level cap now live in `resources/upgrades/*.tres`
## (see `UpgradeTrack`) for every track.

## Dogs in the pack at most: the one adopted plus what `dog_count` buys (2026-09-14). All of
## them share one Fetching, Keenness and Strong Dogs level and one drawing.
const MAX_DOGS := 4

## World pixels a level of Strong Dogs adds to how wide a piece the pack can carry. Four
## levels takes `Dog.CARRY_WIDE` from 16 to 32 — the art's own width times SPRITE_SCALE, so
## from an 8-pixel drawing to a 16-pixel one. Anything wider is the net's alone, by decision
## (2026-09-21): at CARRY_SCALE it would hang half the dog's length out of its mouth.
const DOG_WIDE_STEP := 4.0

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
## 8: the kitchen chairs and the old table left the catalogue and four rubbish-born finds
## (two paintings, the chew toy, the globe) joined it; the def list changed again.
## 10: the shed places furniture on whole source pixels rather than on eight-pixel cells
## (2026-09-16), so a `decor` row's numbers mean something eight times smaller.
## 11: a second pet bed and a second chew toy joined the finds (2026-09-17); the def list
## changed, and the version 9 shed-unit read went with it, as its own note said it would.
## 12: the fill's depth band was inverted and is fixed, and the top of every stack is now
## chosen for variety (2026-09-17). The def list is untouched, so a version 11 file would
## load and run — and keep its old surface for ever, since a save stores its stacks rather
## than its seed. Refused instead: the point of the change is what a lake looks like, and a
## save that quietly opted out of it is a save nobody can judge it by.
## 13: the aquarium and the rug joined the finds, and seven pieces gained a switched-off
## view as their view 0 (2026-09-20) — a toilet saved facing side on would come back empty
## and facing front. Richard started fresh rather than have a v12 file read.
## 14: the rubbish is cut from one PSD (2026-09-21): forty-nine kinds joined and five left
## (`plastic_toy`, `plastic_globe`, `rubber_bone`, `wood_painting3`/`4`), so every index in
## a saved stack moved.
const SAVE_VERSION := 15

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

## The finds a new shed wants first, and the net tier each is lifted at whatever its bulk
## says (Richard, 2026-09-17): the small ones by the first net, the furniture after the
## first Strength buy. They are hidden within `EARLY_OUT` tiles of the island's shelf, one
## slot down, under nothing heavier than themselves — early means never waiting on Strength.
const EARLY_FINDS := {
	&"decor_pet_bed": 0,
	&"decor_chew_toy": 0,
	&"decor_lamp": 0,
	&"decor_vynil_player": 1,
	&"decor_loveseat": 1,
	&"decor_center_table": 1,
}
## The bands the rest are dealt into by tier, in tiles past the shelf: tiers 1-2 between
## `EARLY_OUT` and `MID_OUT`, tiers 3-4 beyond. By rule, so a new find needs no authoring.
const EARLY_OUT := 15.0
const MID_OUT := 25.0
const LATE_TIER := 3
const AUTOSAVE_EVERY := 20.0




## Where this run is saved, and whether it picks up where the last one left off. Both are
## settable before the scene enters the tree, which is how the test harness runs against a
## save file of its own instead of the player's.
var save_path: String = SAVE_PATH
var autoload_save: bool = true

## For a probe that follows the lake across a scene change (`tools/shot_reload.gd`): the path
## **every** lake brought up in this session saves to, whatever else it was told. Static,
## because the lake that comes up after a reload is built by the boot scene, and no tool can
## hand that one a `save_path` — so without this it is the player's own run, loaded, played
## and autosaved by a probe. That happened (2026-09-17): a probe's bug left the game running
## on the real save and it was written. Empty in the game, and nothing in the game sets it.
static var session_save_path: String = ""

## Set by the settings door, and true for exactly one scene load: the level being walked
## into starts from nothing rather than from its own save.
##
## Static because it has to survive the scene change that carries it — the node that sets
## it is gone by the time the node that reads it is built. Cleared as soon as it is read,
## so a level loaded any other way is the saved one again.
static var start_fresh: bool = false

## Where the load goes, for `tools/probe_boot.gd`: `_ready` appends [label, usec] here while
## this is an Array. Null in play, so a mark costs one comparison.
static var boot_marks: Variant = null


static func _mark(label: String) -> void:
	if boot_marks != null:
		(boot_marks as Array).append([label, Time.get_ticks_usec()])


## Seconds of play in this shop run, saved with it, and the playtest log's clocks (`PlayLog`).
var _play: float = 0.0
var _play_progress_in: float = 0.0
var _play_last_cast: float = -1.0
const PLAY_PROGRESS_EVERY := 30.0
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
## slow and small instead, and is upgraded along the axes a run has.
var boat_speed_level: int = 0
var cargo_level: int = 0
## Fast Sell: how much comes off the gap between two pieces of a hull's volley, at both
## ends of its run. resources/upgrades/boat_volley.tres.
var boat_volley_level: int = 0

## Hulls bought on top of the one the player starts with, up to MAX_BOATS in the water. A
## second ferry is the only upgrade that buys a whole extra round of the lake at once, so
## it is priced well above anything that only makes the first one better.
var fleet_level: int = 0

## The dog. Three tracks of training: how many pieces it brings back in one trip out, how
## much comes off the longest it will laze about between trips, and how heavy and how big a
## piece it can get its mouth round at all (Strong Dogs, 2026-09-17).
var dog_fetch_level: int = 0
var dog_wait_level: int = 0
var dog_strength_level: int = 0
## Dogs adopted on top of the first, up to MAX_DOGS in the pack. resources/upgrades/dog_count.tres.
var dog_count_level: int = 0

## The luck board: the Recycle Bonus, one yard at a time paying over the odds for
## `BONUS_EVERY` seconds before the bonus moves on; what a netted pigeon is worth; the odds of
## a lucky haul (one tier deeper and a few more in the bag, that cast only) and of a double
## cast (a second net thrown alongside the first at a nearby spot with rubbish on it, its own
## hold). The five sell-by-tier tracks that stood beside them were cut on 2026-09-18.
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
## Finds that have been netted and not yet washed, oldest first (issue #37). **Must wash to
## place**: a find waits here, at the pump, and only moves to `unlocked` — the shed's shelf —
## once it has come clean on the wash stand. Saved as names; an older save has no such key
## and everything it holds in `unlocked` is simply washed already.
var unwashed: Array[String] = []

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

## The free camera (2026-09-20, `/grill-me` with Richard): the toggle beside the gear pins the
## view to a spot in the world, `_free_at`, and nothing takes it back — not a cast, not a
## step, not the landing's framing, not the way home. The player aims by the cursor and the
## view is theirs: the middle drag and the wheel as ever, plus the window's edges
## (`_edge_scroll`). The angler may walk off the screen, by decision.
##
## **Session only, mouse only, no key**: not in `Prefs`, not in the save, every launch starts
## following; in pad mode the view follows as it always did (the reticle's lean and
## `hold_in` need it to), and free mode resumes when the mouse is picked up again.
var _free_view: bool = false
var _free_at := Vector2.ZERO
## Whether the pointer is inside the window. It stays at its last spot when it leaves, which
## on an edge is a view scrolling on for ever with nobody's hand on it.
var _mouse_inside: bool = true
## The edge scroll: how close to the window's edge the pointer has to be, in canvas pixels,
## and how fast the view goes at the very edge, in view heights a second so it is the same
## on the screen at every zoom — `PadAim`'s rule. First guesses.
const EDGE_MARGIN := 24.0
const EDGE_SPEED := 0.9

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
## The water pump beside the hut, where a find is washed before the shed will take it
## (issue #37). See `Pump`.
var _pump: Pump
var _wash: WashRoom
var _wash_open := false

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

## Every purchasable track, loaded from resources/upgrades/*.tres. Keyed by
## the same StringName used throughout the shop (`&"net_width"`, `&"cargo"`, ...).
const UPGRADE_ORDER := [
	"net_width", "net_strength", "net_range", "reel", "net_hold",
	"boat_speed", "cargo", "boat_volley", "fleet",
	"dog_fetch", "dog_wait", "dog_strength",
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

## The per-tile filth map handed to the water shader, and its texture. Rebuilt on a timer
## whenever something has come out of the water.
var _filth_map: Image
var _filth_texture: ImageTexture
var _filth_stale: bool = false
## What each tile could hold, summed — see `_pooled_share`. Built once; the basin does not move.
var _filth_room := PackedInt32Array()
## Which tiles are the lake's water, 1 or 0 — see `_count_clean`. Asked once, with `_water_tiles`.
var _wet_mask := PackedByteArray()
## The open clean patches: `at` (world), `radius` (world px, long axis), `born` (on
## `_patch_clock`), `seed` (the shape's roll).
var _patches: Array[Dictionary] = []
var _patch_clock: float = 0.0
var _patch_rng := RandomNumberGenerator.new()
## The lane's points, oldest first once full: `at`, `radius`, `born`. `_lane_last` is where
## each net last dropped one, keyed by instance id, and `_lane_seed` the reel's roll.
var _lane: Array[Dictionary] = []
var _lane_last: Dictionary[int, Vector2] = {}
var _lane_seed: float = 0.5
var _filth_remap_in: float = 0.0

var _filth_total: float = 1.0
var _filth_left: float = 1.0

## Whether the player has been thanked for this lake, and the gate on the closing screen:
## the words and the credit roll happen **once per save** (2026-09-19, Richard: "after player
## has already ended the game, a continue should not trigger the end credits or message
## again"). Continue into a finished lake and what comes up is the lit clean water and the
## HUD — the shed, the pump, the decorating — with nothing written over it.
##
## It gated nothing between 2026-09-12 and then, and that is worth knowing why: the way on
## to the second lake was a door on that screen, so a lake that showed its ending last week
## and refused to show it again was a lake with nothing to do on it and no way off it. The
## siege is set aside and `_next_scene()` has returned "" ever since, so the farewell's only
## door is the menu's — which the settings board offers on any run. The reason died with the
## onward door; the gate is back.
##
## Still keyed on the flag rather than on the field, so an ending that was **owed** is paid:
## a lake saved with its last piece still in a net's hold, or lost to a crash before the
## words arrived, has an empty field and a false flag, and gets its ending on the way back in.
##
## `_cleaned` is the lake having nothing left in it, which is what the water is lit by and
## which is worked out again every sitting; this is whether the player has been thanked.
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
var _farewell: Farewell

# The arrival and the letter (2026-09-19, `/grill-me` with Richard, issue #24).
#
# A new game lands the angler and his dog by boat, walks him up to the shed and opens the
# letter on its door (`scripts/letter.gd`). **Unskippable and therefore short**, by
# decision: about twelve seconds from the glide landing to the cards being up, with no key
# that cuts it — a skip is an admission that the thing is too long.
#
# `_intro_done` is the save's own flag, and **a save with no such key reads as done**: every
# file written before this existed belongs to somebody who has already played, and giving
# them the arrival on Continue would be a bug wearing a tutorial's clothes. Nothing else in
# the save moved, so there is no `SAVE_VERSION` bump.
enum Arrive { OFF, SAILING, WALKING, READING }
var _intro_done: bool = false
var _arrive: int = Arrive.OFF
var _letter: Letter
var _letter_open: bool = false

# The led cast (2026-09-22): a cast press on water the net cannot reach from where the
# angler stands walks him towards it and throws the moment it comes into reach — one
# gesture, so a better spot no longer needs WASD first. `_led_cast` is the world point
# committed at the press (not the pointer, which is free to move), INF for none;
# `_led_throw` is whether a throw is owed at the end of the walk — false when no standing
# spot on the island reaches the point, in which case the walk ends at the shore nearest
# it and the player aims again. Straight line plus `Angler._slide`, no path planning: the
# island is convex bar three boxes, which is what the dogs make do with. Any walk input,
# a board, the menu, the arrival or a net no longer idle cancels it; a new press retargets.
# Session state only, nothing saved.
var _led_cast := Vector2.INF
var _led_throw: bool = false
## Seconds the walk has made no ground (a corner of the hut, the crate's face): past
## `LED_STALL` it is given up rather than left pushing at a wall for ever.
var _led_stall: float = 0.0
var _led_was := Vector2.INF
const LED_STALL := 0.6

# The first steps (2026-09-22, `/grill-me` with Richard, issue #24; `scripts/first_steps.gd`):
# after the letter closes on a new game, walking and casting are taught on the lake. Move to
# a spot on the beach (the cast held till then), cast and catch, read the note by the box.
# `_steps_done` is saved, **absent reads as done** (the `intro_done` rule), and a run saved
# before the last step starts the steps over from the walk: nothing of where they had got to
# is kept, by decision.
var _steps_done: bool = true
## The shop's tour (`ShopSkin.tour`), saved as `shop_tour`, absent reads as done. Where it had
## got to is the board's for the session: closed half way, it picks up there next time the
## shop opens; quit half way, it starts over.
var _shop_tour_done: bool = true

# The decoration tour (2026-09-22, `/grill-me` with Richard, issue #24; `scripts/tour_card.gd`):
# the first time a new game opens the shed, five cards walk washing and placing, the new
# game's bed the first thing washed (free). A find netted before the shed was ever opened
# puts a hint on the Decorate button first. Saved as `decor_tour`, absent reads as done;
# where it had got to is the session's.
enum DecorTour { OFF, HINT, PLANK, PLANK_WAIT, LIST, STAND, WASHING, SHELF, ROOM }
var _decor_tour_done: bool = true
var _decor_tour: int = DecorTour.OFF
var _tour_card: TourCard
## Seconds before the hint goes up (the find-caught card first), and before a washed find
## takes the player back into the shed (its shine first).
var _decor_tour_wait: float = 0.0
const DECOR_TOUR_CARDS := 5
const DECOR_HINT_AFTER := 2.8
const DECOR_BACK_AFTER := 1.6
## How clean the find on the stand has to be before the stand's card gives way: a little of
## the coat off, so the card is read before the spray takes it down.
const DECOR_SPRAYED := 0.04
## How many pieces stood in the room when the shelf's card came up; -1 before it has.
var _decor_tour_placed := -1
## How clean the find was when the stand's card came up; -1 before it has.
var _decor_stand_from := -1.0
const DECOR_HINT := "You caught a decoration! Open Decorate to see it."
const DECOR_PLANK := "You need to wash objects before it is available for decoration."
const DECOR_LIST := "Select the object to wash, it costs $5 to $15 depending on size."
const DECOR_STAND := "Point and click to spray the object with water. It goes to decoration inventory when done."
const DECOR_STAND_PAD := "Aim and hold %s to spray the object with water. It goes to decoration inventory when done."
const DECOR_SHELF := "Select and drag the object to its position. Press %s to rotate or change style."
const DECOR_SHELF_PAD := "Press %s to pick up and place an object. Press %s to rotate or change style."
const DECOR_ROOM := "You can interact with some objects. It shows when available."
var _steps: FirstSteps
## The tile the walk step points at, and the world point the cast step rings.
var _steps_beach := Vector2.INF
var _steps_water := Vector2.INF
## The note: whether the catch has landed in the crate yet, and the seconds it has left.
var _steps_landed: bool = false
var _steps_left: float = 0.0
## How long finding the two spots took, for the probe's log.
var _steps_found_ms: int = 0
## Within this many tiles of the beach spot counts as standing on it.
const STEPS_ARRIVE := 0.6
## The beach spot is at least this far from where the angler stands, so there is a walk.
const STEPS_WALK_LEAST := 3.0
## Where along the net's range the cast spot is looked for, as shares of it.
const STEPS_CAST_FROM := 0.35
const STEPS_CAST_TO := 0.85
## The cast ring is this share of the net's open mouth, tested at this many points round it.
const STEPS_RING_SHARE := 0.5
const STEPS_RING_TESTS := 12
## How far in from the last standing point the beach spot sits, in tiles: on the sand.
const STEPS_BEACH_IN := 0.6
## The note stays this long after the catch lands, and never longer than `STEPS_NOTE_MOST`.
const STEPS_NOTE_HOLD := 5.0
const STEPS_NOTE_MOST := 14.0
## How far over the crate's foot its mouth is, in world pixels: where the note's arrow points.
const STEPS_CRATE_UP := 34.0
## Under this many tiles of movement in a frame counts as standing still.
const LED_STILL := 0.002

## The pad's reticle and its assist, see scripts/pad_aim.gd. `at` is INF while the mouse is
## aiming; `_pad_was` notices the switch so the reticle starts where the pointer was.
var _aim := PadAim.new()
var _pad_was: bool = false
## How far the sparkle has come up, 0 to 1. Eased rather than switched so the lake brightens
## over a couple of seconds — the last piece is lifted and the water answers.
var _sparkle_at: float = 0.0

@onready var _hud_layer: CanvasLayer = $HUD
@onready var _skin: HudSkin = %Skin
@onready var _shop_skin: ShopSkin = %ShopSkin
@onready var _shed: PanelContainer = %Shed
@onready var _room: ShedRoom = %Room
@onready var _open_upgrades: UiButton = %OpenUpgrades
@onready var _settings: SettingsSkin = %Settings
@onready var _open_settings: PlankButton = %OpenSettings
@onready var _free_camera: PlankButton = %FreeCamera

## Whether a docked hull sets off on its own. A plain bool since the stock shop panel went
## (2026-09-20): it used to live in a `CheckButton` nobody could see or press, on a panel the
## drawn board replaced. Saved under `auto_ferry`, as it always was.
var _auto_ferry_on: bool = true


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


## The multiple on the gap between two pieces of a ferry's volley, at both ends of its run:
## 1.0 untrained, down to 0.4 at the top of Fast Sell. A cut rather than a scale in the
## `.tres`, the way `dog_wait` is, so the curve counts up from nothing like every other
## track. resources/upgrades/boat_volley.tres, and see Haul._gap for what it does and does
## not touch.
func boat_volley_gap() -> float:
	return 1.0 - _upgrades[&"boat_volley"].value(boat_volley_level)


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


## The heaviest weight tier the pack will pick up, and the widest piece it can get its mouth
## round, in world pixels. One track raises both: tier on its own would open three kinds in
## the whole catalogue, because `def.size.x` is the art's own width at SPRITE_SCALE and that
## is the gate that actually binds. The top of the track is everything no wider than 32.
## resources/upgrades/dog_strength.tres.
func dog_carry_tier() -> int:
	return Dog.CARRY_TIER + int(_upgrades[&"dog_strength"].value(dog_strength_level))


func dog_carry_wide() -> float:
	return Dog.CARRY_WIDE + DOG_WIDE_STEP * _upgrades[&"dog_strength"].value(dog_strength_level)


## How much over the odds the boosted yard pays, as a fraction (0.25 is +25%).
## resources/upgrades/recycle_bonus.tres.
func recycle_bonus() -> float:
	return _upgrades[&"recycle_bonus"].value(recycle_bonus_level)


## What a netted pigeon pays. resources/upgrades/bird_worth.tres times the economy's bonus.
func bird_pay() -> float:
	return _economy.bird_bonus * _upgrades[&"bird_worth"].value(bird_worth_level)


## Odds that a cast is a lucky one. resources/upgrades/lucky_haul.tres.
func lucky_chance() -> float:
	return _upgrades[&"lucky_haul"].value(lucky_haul_level)


## Odds that a cast throws a second net. resources/upgrades/double_cast.tres.
func double_cast_chance() -> float:
	return _upgrades[&"double_cast"].value(double_cast_level)


func _ready() -> void:
	($Sky/Fill as ColorRect).color = BEYOND
	_mark("children ready")
	_day = %Day as DayCycle
	_daylight = %Daylight as CanvasModulate
	_pop_rng.randomize()
	_load_upgrades()
	# A probe's path outranks the player's slot.
	if not session_save_path.is_empty():
		save_path = session_save_path
	_mark("upgrades")
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
	_mark("shapes and ground")

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
	_mark("sfx")

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
	_mark("sheets")
	_grid.build(_all_defs(), _level_seed(), _fills_the_lake())
	_mark("grid build")
	_hide_treasures()
	_mark("hide treasures")
	_pieces_full = _grid.piece_count()
	_filth_total = maxf(_grid.filth_left(), 0.001)
	_filth_left = _filth_total
	pollution = 1.0
	_build_filth_map()
	_mark("filth map")

	_build_trophy()
	_build_pigeon_pop()
	_build_coins()
	_mark("trophy pop coins")

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

	# The pump, on the crate's own layer: a walker north of it is put a band under, see
	# `_walker_layer`. Nobody is told where it is — `Pump.tile` is a static the walkers ask.
	_pump = Pump.new()
	_pump.name = &"Pump"
	_pump.day = _day
	_pump.z_index = CRATE_LAYER
	Pump.tile = Iso.shed_centre() + PUMP_AT
	_pump.position = Iso.tile_to_world(Pump.tile.x, Pump.tile.y)
	add_child(_pump)

	# The flock is drawn over the whole lake (2026-09-16, Richard's call): birds are the one
	# thing here that is genuinely in the air, and at z 6 they were cut in half by a pier
	# deck, hidden behind a moored hull and walked in front of by the angler. Above the net
	# and the finds' beams too — "over everything" was the whole of the instruction, and a
	# bird that vanishes behind the thing being cast at it is the bug, not the fix.
	_grow_nature()
	_mark("nature")

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
	_mark("flock and nets")

	# The ferry lives on the island's south side and works its way round the bank from
	# there, calling at whichever merchants its load is for.
	_fit_out(_boats[0], 0)
	_push_net_numbers()
	_push_boat_numbers()
	_mark("fit out boat")

	_room.sheets = _sheets
	_room.unlocked = unlocked
	_room.decor = decor
	# How many dogs may be in the shed at once. A Callable rather than a number, because the
	# pack grows mid-run (`_add_dog`) and a count pushed here would hold the room at one dog
	# for the whole session. The wash room's own pattern.
	_room.pack_size = func() -> int: return _dogs.size()
	_room.day = _day
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
	_mark("shop art")
	_skin.shed_pressed.connect(_set_shed.bind(true))
	_skin.upgrades_pressed.connect(_set_menu.bind(true))
	_open_upgrades.pressed.connect(_set_menu.bind(true))
	_room.close_asked.connect(_shut.bind(_set_shed))
	_room.wash_asked.connect(_shed_to_wash)
	_open_settings.pressed.connect(_set_settings.bind(true))
	# Last of the HUD's children, so it lies over the shed rather than under it. The shed
	# fills the screen now, and a settings panel drawn beneath that is a settings panel
	# nobody can see or press.
	_settings.get_parent().move_child(_settings, -1)
	_settings.get_parent().move_child(_open_settings, -1)
	_free_camera.pressed.connect(_toggle_free_view)
	# The volumes are audio buses now (2026-09-16, issue #26): the board sets them through
	# `Prefs` and nothing has to be pushed from here. What is left is the doors it opens.
	_settings.controls_asked.connect(_set_controls.bind(true))
	_settings.quit_pressed.connect(_quit)
	_settings.wipe_pressed.connect(wipe_save)
	_settings.swap_label = _other_level_name()
	_settings.swap_pressed.connect(_swap_levels)
	_settings.close_asked.connect(_shut.bind(_set_settings))
	_shop_skin.close_asked.connect(_shut.bind(_set_menu))
	_shop_skin.tour_ended.connect(_on_shop_tour_ended)
	# Not the shed. It has no panel to hang a cross on the corner of any more — the room is
	# the whole screen — so its own cross sits over the top of the inventory column, where
	# the thing it closes actually is. See ShedRoom.
	_set_menu(false)
	_start_music()
	_set_settings(false)
	_set_controls(false)
	_set_shed(false)
	_push_water_colours()
	_mark("panels and music")
	var loaded := false
	if autoload_save and not start_fresh:
		loaded = load_game()
	start_fresh = false
	_mark("load game")
	if _logs_play():
		_begin_play_session(loaded)
	_seed_starter_bed()
	_mark("end")
	_raise_front(loaded)


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
##
## The words are owed only once per save (2026-09-19). Everything else here happens every
## time a finished lake is worked out — the lit water, the meter on the floor, the write —
## because those are facts about the field, not about the player having been thanked.
func _on_lake_cleaned() -> void:
	var owed := not _farewell_shown
	_farewell_shown = true
	if not owed:
		return
	# Straight to the words and the end song (2026-09-18, Richard: "no need for the end game
	# bell, lets run straight to the message and credit song"). The two-second beat of
	# clean water and the struck note that opened it are gone: the words take `Farewell.FADE_IN`
	# to arrive, the lake is lighting up under them the whole time, and that is the breath.
	# `_show_farewell` pushes the rooms, which is what tells the station.
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

## Nature coming back (2026-09-16): the plants on the shores and the fish in the clean
## water, both read off the filth map and `_clean_share`. See flora.gd and fish.gd.
var _flora: Flora
var _fish: Fish
## The animals that come back with it (2026-09-22): frogs, turtles, ducks, dragonflies.
var _wildlife: Wildlife
## The share of the lake's water tiles the map calls clean, 0..1, set by each map build.
var _clean_share: float = 0.0
## Every water tile index the map calls clean, as of the last build.
var _clean_tiles := PackedInt32Array()
## How many water tiles there are to be clean, counted once.
var _water_tiles: int = 0
## The glints on clean water: the tease of the finished lake's sparkle. `glint` in the
## water shader, driven off `_clean_share` bent by GLINT_BITE so the first clean bay pops a
## little and the last stretch pops a lot.
## Sparser on 2026-09-16 (Richard: "decrease the amount of sparkle on clean water during
## gameplay, it should be more sparse"): GLINT_MOST 0.7 to 0.4 and the shader's cell
## 14 to 20 art px (GLINT_CELL), about a third of the pops there were.
## And again on 2026-09-18 (Richard: "decrease the clean lake sparkle while lake is still
## grimy"), both knobs: fewer at the finish (GLINT_MOST 0.4 to 0.25) and far fewer early
## (GLINT_BITE 1.4 to 2.5) — at half clean 0.044 where it was 0.15. The light belongs to the
## last stretch; a lake that is mostly soup has not earned it yet.
## And a third time the day after (Richard: "still too much sparkle on clean water at early
## game, it should be really sparse and rare"): GLINT_BITE 2.5 to 5. Counted rather than
## guessed this time. A pop is one cell's roll, five ticks a second, so a screen of nothing
## but clean water at zoom 1 (576 cells) shows 259 x glint pops a second, and four times
## that at the 0.5 stop. At 2.5 that was 1.2 a second at a fifth of the lake clean and 3.2 at
## three tenths — a steady twinkle, not a rare one. At 5 it is one in fifty seconds and one
## in six, 2 a second at half clean, and the old rate again only from about nine tenths.
## `test_lake` holds the early rate, not the constant.
## And a fourth, an hour later, from 92% cleared (Richard: "still too much shine overall,
## tone down a lot"): the bite had fixed the early game and left the ceiling where it was,
## so nine tenths clean was still 38 pops a second on a clean screen and 150 at the 0.5
## stop. GLINT_MOST 0.25 to 0.03, an eighth, and the bite back to 3.5 so what is left is
## spread over the run instead of all arriving at the end: 0.1 a second at three tenths
## clean, 0.7 at half, 3.6 at eight tenths, 5.4 at nine — lower than it was at every share.
## `test_lake` holds both ends now.
const GLINT_BITE := 3.5
const GLINT_MOST := 0.03
const GLINT_CELL := 20.0


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
	&"water_hazy_deep", &"water_hazy_mid", &"water_hazy", &"water_hazy_shallow",
	&"water_hazy_light", &"water_foul_deep", &"water_foul_mid", &"water_foul",
	&"water_foul_shallow", &"water_foul_light",
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
	_water_material.set_shader_parameter(&"patch_soft", PATCH_CLOSE_SOFT)
	_water_material.set_shader_parameter(&"glint_cell", GLINT_CELL)
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
	# The meter moves for the dog's pieces too. It did not, so a lake the pack helped clear
	# never read empty — and the ending, which waited on the meter, never came.
	_filth_left = maxf(_filth_left - _grid.defs[def_index].pollution, 0.0)
	pollution = clampf(_filth_left / _filth_total, 0.0, 1.0)
	_filth_stale = true
	_ask_the_end()
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
	# The first two batches, kept in their old order.
	"metal_can1", "metal_can2", "metal_can3", "metal_can4", "metal_hanger", "metal_pan",
	"metal_phone", "metal_pot", "metal_support", "metal_teapot", "plastic_bowl",
	"plastic_cup1", "plastic_cup2", "plastic_mug", "plastic_plate", "plastic_sheet",
	"plastic_wrap", "rubber_ball", "rubber_disk", "rubber_duck", "rubber_tire", "wood_box1",
	"wood_box2", "wood_painting1", "wood_painting2", "wood_piece", "metal_lamp",
	"metal_mirror", "plastic_sign", "plastic_frame", "rubber_block", "rubber_toy",
	# Third batch, 2026-09-21: forty-nine kinds for variety, same PSD.
	"metal_bar", "metal_box1", "metal_box2", "metal_cart", "metal_controller",
	"metal_dumbell", "metal_extinguisher", "metal_mirror2", "metal_phone2", "metal_pot2",
	"metal_radio", "metal_shaker", "metal_sound", "plastic_bottle", "plastic_bottles",
	"plastic_chair", "plastic_sign2", "plastic_toy1", "plastic_toy2", "plastic_toy3",
	"plastic_toy4", "plastic_toy5", "plastic_vase", "rubber_ball2", "rubber_ball3",
	"rubber_ball4", "rubber_shoes", "rubber_tire2", "rubber_toy2", "rubber_toy3",
	"rubber_toy4", "rubber_toy5", "rubber_utensil", "wood_block", "wood_board", "wood_box3",
	"wood_box4", "wood_box5", "wood_chair", "wood_door", "wood_drawer", "wood_guitar",
	"wood_lamp", "wood_plank1", "wood_plank2", "wood_sign", "wood_skateboard", "wood_stool",
	"wood_toy",
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
		if EARLY_FINDS.has(StringName(name)):
			find.tier = int(EARLY_FINDS[StringName(name)])
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
		# Every tile in the find's own band, shuffled off the seed; the first one clear of
		# FIND_APART of every find already down wins, and failing that the one furthest from
		# all of them. This was 800 darts over the whole square, most of which missed the
		# band — so the spacing was luck, and the late band is short of room: past MID_OUT
		# only a few hundred tiles are three deep, bunched towards the bank, for fourteen
		# finds. A change to the fill (2026-09-21, the third rubbish batch) was enough to tip
		# it from two crowded pairs to three.
		# When the band has no tile clear, the spacing wins over the band, as the darts'
		# fallback always had it: any deep tile in the lake that is clear. Only then the
		# roomiest tile in the band. `test_lake` allows two finds out of their band.
		var early := EARLY_FINDS.has(def.piece)
		var spots := _find_spots(def, early, _find_band(def))
		_shuffle(spots, rng)
		var pick := _clear_spot(spots, planted_at)
		if pick < 0:
			var anywhere := _find_spots(def, early, Vector2(0.0, INF))
			_shuffle(anywhere, rng)
			pick = _clear_spot(anywhere, planted_at)
		if pick < 0:
			var roomiest := -1.0
			for index in spots:
				var room := _room_from(Vector2(_grid.tile_of(index)), planted_at)
				if room > roomiest:
					roomiest = room
					pick = index
		if pick < 0:
			# A collection that cannot be completed is the worse failure.
			_plant_anywhere(i)
			continue
		var down := 0 if early else rng.randi_range(0, 2)
		_grid.insert(pick, maxi(_grid.height_of(pick) - 1 - down, 0), i)
		planted_at.append(Vector2(_grid.tile_of(pick)))


## The tiles a find may be hidden in: deep enough, wet, inside `band`, and for an early
## find, under nothing heavier than itself — so early never means waiting on Strength.
func _find_spots(def: TrashDef, early: bool, band: Vector2) -> PackedInt32Array:
	var spots := PackedInt32Array()
	for ty in range(2, Iso.ROWS - 2):
		for tx in range(2, Iso.COLS - 2):
			var index := _grid.index_of(tx, ty)
			var height := _grid.height_of(index)
			if height < 3 or _grid.dry[index] != 0:
				continue
			var out := Iso.past_shelf(Vector2(tx, ty))
			if out < band.x or out > band.y:
				continue
			if early and _grid.def_at(index, height - 1).tier > def.tier:
				continue
			spots.append(index)
	return spots


## Fisher-Yates off the given generator, so the deal is the seed's and nobody else's.
func _shuffle(spots: PackedInt32Array, rng: RandomNumberGenerator) -> void:
	for n in range(spots.size() - 1, 0, -1):
		var k := rng.randi_range(0, n)
		var held := spots[n]
		spots[n] = spots[k]
		spots[k] = held


## The band a find is hidden in, as tiles past the island's shelf (from, to).
func _find_band(def: TrashDef) -> Vector2:
	var near := Iso.SHELF_TILES + Iso.SHELF_CLEAR
	if EARLY_FINDS.has(def.piece):
		return Vector2(near, EARLY_OUT)
	if def.tier < LATE_TIER:
		return Vector2(EARLY_OUT, MID_OUT)
	return Vector2(MID_OUT, INF)


## The first of `spots` at least FIND_APART from every find already down, or -1.
func _clear_spot(spots: PackedInt32Array, planted_at: Array[Vector2]) -> int:
	for index in spots:
		if _room_from(Vector2(_grid.tile_of(index)), planted_at) >= FIND_APART:
			return index
	return -1


## How far `at` is from the nearest of `others`; infinite with none.
func _room_from(at: Vector2, others: Array[Vector2]) -> float:
	var least := INF
	for other: Vector2 in others:
		least = minf(least, at.distance_to(other))
	return least



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


## Put a find somewhere — anywhere — when its band has no tile deep enough.
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
	# Behind the menu, and on the way down out of it, the lake reads nothing: the menu's own
	# boards answer Escape and F11, and a click meant for a plank must not also be a cast.
	if _fronted() or _arrive != Arrive.OFF:
		return
	if _extra_input(event):
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		match key.keycode:
			KEY_ESCAPE:
				# One key backing out of whatever is open, innermost first: the shed, then
				# the shop board, and only on open water does it mean the settings.
				if _letter_open:
					_shut(_set_letter)
				elif _controls_open:
					_shut(_set_controls)
				elif _wash_open:
					_shut(_set_wash)
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
		if _free_now():
			_free_at = _clamped_view(_free_at - drag.relative / _camera.zoom)
		else:
			_pan -= drag.relative / _camera.zoom
		_pan_moved += drag.relative.length()
		return

	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return

	# The shed door and saying hello to a dog.
	if _desk_pressed(event, &"interact"):
		if _settings_open or _controls_open:
			return
		if _wash_open:
			_shut(_set_wash)
		elif _shed_open:
			_shut(_set_shed)
		elif _menu_open:
			_shut(_set_menu)
		elif _at_pump():
			_open_wash()
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
				_recentre()
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
		_recentre()
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
		if _steps != null and _steps.note_hit(get_viewport().get_mouse_position()):
			_end_first_steps()
			return
		if _net.state == CastNet.State.IDLE:
			_cast_or_walk(get_global_mouse_position())
		_net.set_pulling(true)


## Whether a press of this action came from the desk — a key or a mouse button — rather than
## from the pad, which `_pad_buttons` answers.
func _desk_pressed(event: InputEvent, action: StringName) -> bool:
	if not (event is InputEventKey or event is InputEventMouseButton):
		return false
	return event.is_action_pressed(action)


## Whether any board is over the lake.
func _panelled() -> bool:
	return (
		_settings_open or _menu_open or _shed_open or _controls_open or _wash_open
		or _letter_open
	)


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
	return (
		_menu_open or _settings_open or _shed_open or _controls_open or _farewell != null
		or _in_menu or _wash_open or _letter_open
	)


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
	# No reticle and no verbs behind the menu: the pad there is the menu's pointer.
	if _fronted():
		_aim.at = Vector2.INF
		_net.pad_aim = Vector2.INF
		_pad_was = false
		return
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
		if _at_pump():
			_open_wash()
		elif _at_shed():
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
			_cast_or_walk(aim_point())
		_net.set_pulling(true)


## The cast press: throw if the spot is in reach, otherwise walk towards it and throw on
## arrival (see `_led_cast`). A press on the island or the bank is nothing, as it always was.
func _cast_or_walk(where: Vector2) -> void:
	if _steps != null and _steps.step == FirstSteps.Step.MOVE:
		_walk_not_cast(where)
		return
	if _net.in_reach(where):
		_stop_led_cast()
		_cast_at(where)
		return
	var tile := Iso.world_to_tile(where)
	if Iso.island_fraction(tile.x, tile.y) < 1.0 or Iso.shore_fraction(tile.x, tile.y) >= 1.0:
		# Not water. A spot on the island the boots may stand on is walked to (Richard,
		# 2026-09-22: a click on the isle walks there, it does not just stand); the hut,
		# the crate, the pump and the bank are nothing.
		if bool(_angler.call(&"_can_stand", tile)):
			_led_cast = where
			_led_throw = false
			_led_stall = 0.0
			_led_was = _angler.tile_pos
			_angler.walk_to = tile
			_pan_yielded = true
		return
	var shore: Vector2 = _angler.shore_toward(tile)
	_led_cast = where
	_led_throw = shore.distance_to(tile) <= _net.range_tiles
	_led_stall = 0.0
	_led_was = _angler.tile_pos
	# Reachable: straight at the spot, the frame it comes into reach is the throw. Not:
	# to the shore nearest it, where the walk ends and nothing is thrown.
	_angler.walk_to = tile if _led_throw else shore
	_pan_yielded = true


## The walk step's press: the cast is held until the angler has walked, so a press on water
## walks to the shore towards it and throws nothing; a press on the island walks there.
func _walk_not_cast(where: Vector2) -> void:
	var tile := Iso.world_to_tile(where)
	var wet := Iso.island_fraction(tile.x, tile.y) >= 1.0 and Iso.shore_fraction(tile.x, tile.y) < 1.0
	var to: Vector2 = _angler.shore_toward(tile) if wet else tile
	if not bool(_angler.call(&"_can_stand", to)):
		return
	_led_cast = where
	_led_throw = false
	_led_stall = 0.0
	_led_was = _angler.tile_pos
	_angler.walk_to = to
	_pan_yielded = true


func _stop_led_cast() -> void:
	if _led_cast == Vector2.INF:
		return
	_led_cast = Vector2.INF
	_led_throw = false
	_angler.walk_to = Vector2.INF


## One frame of the led cast. The walk is the angler's own (`walk_to`); this is what ends it.
func _led_step(delta: float) -> void:
	if _led_cast == Vector2.INF:
		return
	var pushed := Input.get_vector(&"walk_left", &"walk_right", &"walk_up", &"walk_down")
	if _panelled() or _in_menu or _arrive != Arrive.OFF or _farewell != null 			or _net.state != CastNet.State.IDLE or pushed != Vector2.ZERO:
		_stop_led_cast()
		return
	if _led_throw and _net.in_reach(_led_cast):
		var at := _led_cast
		_stop_led_cast()
		_cast_at(at)
		return
	if _angler.walk_to == Vector2.INF:
		# The shore was reached with nothing in range: the player aims again from here.
		_stop_led_cast()
		return
	if _angler.tile_pos.distance_to(_led_was) < LED_STILL:
		_led_stall += delta
		if _led_stall >= LED_STALL:
			_stop_led_cast()
			return
	else:
		_led_stall = 0.0
	_led_was = _angler.tile_pos


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
		if _logs_play():
			var gap := -1.0 if _play_last_cast < 0.0 else snappedf(_play - _play_last_cast, 0.01)
			PlayLog.write("cast", _play, {"since_last": gap})
			_play_last_cast = _play


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


## The wash room, up or down. Built the first time it is asked for, on the HUD's layer over
## the skin, the way the shed's room lies over it. Going down takes whatever was on the
## stand off it unwashed and unpaid for — the room's own rule.
func _set_wash(open: bool) -> void:
	if open and _wash == null:
		_wash = WashRoom.new()
		_wash.name = &"WashRoom"
		_wash.sheets = _sheets
		_wash.purse = func() -> float: return sludge
		_wash.day = _day
		_wash.filth_left = func() -> float: return pollution
		_wash.pack_size = func() -> int: return _dogs.size()
		_wash.fleet_size = func() -> int: return fleet_size()
		# The lake's own rubbish for the water behind the stand: the lighter tiers, no finds.
		for def: TrashDef in _grid.defs:
			if not def.keepsake and def.tier <= 2 and def.atlas != null:
				_wash.rubbish.append({"sheet": def.atlas, "region": def.region})
		_wash.flock = _flock
		_wash.washed.connect(_on_find_washed)
		_wash.close_asked.connect(_shut.bind(_set_wash))
		_skin.get_parent().add_child(_wash)
	if _wash == null:
		return
	if open and not _wash_open and _sfx != null:
		_sfx.play(&"shed_open")
	_wash_open = open
	_wash.waiting = unwashed
	_wash.free.assign([STARTER_BED])
	if open and _decor_tour in [DecorTour.PLANK, DecorTour.PLANK_WAIT]:
		_decor_tour = DecorTour.LIST
	_wash.open(open)
	_skin.visible = not open
	if _coins != null:
		_coins.visible = not open
		if open:
			_coins.clear()
	_push_rooms()


func _open_wash() -> void:
	if _panelled():
		return
	_set_wash(true)


## The shelf's wash plank: the shed goes down and the wash room comes up in the one click.
## The pump stands inside `SHOP_RANGE`, so the player at the shed door is in reach of it;
## the room's own close returns to the lake, not to the shed.
func _shed_to_wash() -> void:
	if not _shed_open:
		return
	_set_shed(false)
	_set_wash(true)


## A find has come clean on the stand: the soap is paid for now, not when it was picked, and
## the find goes on the shed's shelf. Saved on the spot, like everything else kept.
func _on_find_washed(piece: StringName, soap: int) -> void:
	var name := String(piece)
	if not unwashed.has(name):
		return
	unwashed.erase(name)
	unlocked.append(name)
	sludge = maxf(sludge - float(soap), 0.0)
	if _decor_tour in [DecorTour.LIST, DecorTour.STAND, DecorTour.WASHING]:
		_decor_tour = DecorTour.SHELF
		_decor_tour_wait = DECOR_BACK_AFTER
	if _room != null:
		_room.unlocked = unlocked


## Close enough to the pump to work it. Asked before `_at_shed`, which it stands inside.
func _at_pump() -> bool:
	return Pump.tile != Vector2.INF and _angler.tile_pos.distance_to(Pump.tile) < PUMP_RANGE


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
	_free_at = to
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
	_shop_skin.visible = open
	if open:
		_skin.hush_pulse(&"upgrades")
		if not _shop_tour_done and _shop_skin.tour < 0:
	if not open:
		_skin.purse_over = Rect2()
			_shop_skin.tour = 0
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
	if open != _shed_open and _logs_play():
		PlayLog.write("shed_open" if open else "shed_close", _play)
	_shed_open = open
	_shed.visible = open
	if open:
		_skin.hush_pulse(&"shed")
	# The way to the shop sits in the corner beside Settings rather than on the shed's own
	# floor, so it is out of the way of both picking a find and putting it down. It is not a
	# child of the panel any more, so its own visibility has to be said here.
	_open_upgrades.visible = open
	if open:
		_menu_open = false
		_settings.visible = false
		_settings_open = false
		_room.unlocked = unlocked
		_room.unwashed = unwashed
		_room.decor = decor
		_room.carrying = &""
		_room.opened()
		_room.queue_redraw()
		if not _decor_tour_done and _decor_tour <= DecorTour.HINT:
			_decor_tour = DecorTour.PLANK if not unwashed.is_empty() else DecorTour.SHELF
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


## How often to ask whether the lake is finished.
##
## The meter is not the trigger and, since 2026-09-17, not the cue to ask either. It is a
## float that has had eighteen thousand subtractions done to it, and it only moves for the
## paths that remember to move it: `CLEAN_ENOUGH`, the fraction under which the field used
## to be asked, was never reached on a lake the dogs helped clear. The field is what
## answers, and it is asked on this clock and whenever a piece lands in the crate.
const CLEAN_CHECK_EVERY := 0.5

## Is it over yet?
##
## Only asked while the meter is on the floor, and only twice a second even then, because
## the answer means walking every stack in the basin. Both of those are why the question is
## cheap enough to keep asking rather than being wired to the last piece landing — a piece
## can leave the lake by the net, by a dog, or by burning, and an ending that has to
## be remembered by every one of those is an ending that will be forgotten by the next one.
func _look_for_the_end(delta: float) -> void:
	if _cleaned:
		return
	# No meter gate any more (2026-09-17). The float was the cue to ask the field, and any
	# path that took a piece without moving the float — the dogs' deliveries did not — left
	# it above the old threshold for good, so the field was never asked and the run never ended.
	# The walk is 8464 `size()` calls twice a second, which is nothing; the truth is cheap
	# enough to ask outright. A piece landing in the crate asks at once, see `_ask_the_end`.
	_clean_check_in -= delta
	if _clean_check_in > 0.0:
		return
	_clean_check_in = CLEAN_CHECK_EVERY
	_left_over = _grid.piece_count() if _grid != null else 0
	_check_cleaned()


## A piece has just gone into the island's crate: ask on the next frame rather than at the
## next half second, so the ending starts as the last one lands. Next frame, not now — the
## haul and the dog are both still mid-handover when they call, and would answer "not yet".
func _ask_the_end() -> void:
	_clean_check_in = 0.0


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


## Whether the ending is up, which is the closing words being on screen. What the music
## station is told, so the end song comes in with them.
func ending() -> bool:
	return _farewell != null


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


# The arrival, and the letter (issue #24)
# =======================================
#
# What a new game opens with, in order: the glide down out of the menu, a ferry sailing in
# off the lake, the angler and his dog stepping off at the dock, a walk up to the shed, and
# the letter pinned to its door opening itself. The player's hands are held throughout and
# come back when the cards are closed.
#
# **The boat is the fleet's own first hull**, by decision, not a visitor built for the
# occasion: it berths and is the ferry from then on, which is both one less thing to build
# and an answer to where the ferry came from. It is `moored` while the letter is up so it
# does not set off on a run behind the cards.
#
# **The note on the door is the intro's alone.** It opens itself, and it is gone afterwards;
# the cards are read again from the main menu's "How to play" plank. The cost, accepted: a
# player ten minutes in has to go through the menu to re-read them.

## Where the pair step off, as a share of the way from the island's middle out to the berth:
## its own beach, on the side the hull came alongside.
const ARRIVE_ASHORE := 0.82
## How far out the hull starts, as a share of the basin's radius — off the drawn lake, so it
## comes in over the water rather than fading up on it.
const ARRIVE_OUT := 1.3
## How long the pair stand on the boards before setting off, and how long the note is looked
## at before it opens. Two small beats, so neither reads as a snap.
const ARRIVE_STEP_OFF := 0.6
const ARRIVE_READ := 0.8

var _arrive_wait: float = 0.0


## Arm the arrival, at the moment the glide sets off: the hull goes out onto the lake, and
## the pair go with it. Called from `_begin_glide`, after `_release_world` — which unmoors
## every hull, and this one is to stay put once it lands.
func _start_arrival() -> void:
	if _intro_done or _boats.is_empty():
		return
	_steps_done = false
	_shop_tour_done = false
	_decor_tour_done = false
	_bed_to_the_pump()
	_arrive = Arrive.SAILING
	_arrive_wait = ARRIVE_STEP_OFF
	var hull := _boats[0]
	hull.moored = true
	hull.arrive_from(_arrival_berth(hull))
	# Standing where the boat comes alongside, out of sight until they step off it. The
	# berth itself is water, and `stand_at` would walk them off it to the nearest dry tile
	# — which is inland, so the pair appeared halfway up the island instead of on its beach.
	_angler.stand_at(_ashore_of(hull.dock))
	_angler.visible = false
	for dog in _dogs:
		dog.visible = false
		dog.doze(true, false)
	_hold_the_angler()


## Where the door is along the hut's left front face (the +y face, the one drawn on the
## picture's left half), as a share of the half-footprint from the middle: `SHED_DOOR` is
## columns 0.22-0.37 of the picture, whose near corner is at 0.5, so its middle is 0.4 of the
## face in from that corner — 0.2 of the half-width past the middle.
const DOOR_ALONG := 0.2
## How far in front of the wall the angler stops to read the note, in tiles.
const DOOR_STAND := 0.45


## The spot in front of the hut's door (2026-09-24): the arrival leads the angler here, where
## the note is pinned beside the door.
func _before_the_door() -> Vector2:
	var mid := Iso.shed_centre()
	return Vector2(
		mid.x + Iso.SHED_FOOT.x * DOOR_ALONG, mid.y + Iso.SHED_FOOT.y + DOOR_STAND
	)


## Where the arriving hull sets off from: the plastic yard's berth, out on the water
## (2026-09-24). A point off the basin put the hull under way across the forest and the
## beach before it reached the lake. Off the lake only when there are no yards.
func _arrival_berth(hull: Boat) -> Vector2:
	for stop: Dropoff in _dropoffs:
		if stop.kind == TrashDef.Kind.PLASTIC:
			return stop.berth
	return Iso.basin_point(Iso.basin_angle(hull.dock), ARRIVE_OUT)


## The beach on the side a berth is: the island's own ring, taken in a little. Measured off
## `Iso.ISLAND_RADIUS` rather than as a share of the way out to the berth — the berth lies
## a couple of tiles beyond the ring, so a share of it is still water however small it looks.
func _ashore_of(berth: Vector2) -> Vector2:
	var way := (berth - Iso.ISLAND_CENTRE).normalized()
	return Iso.ISLAND_CENTRE + Vector2(
		way.x * Iso.ISLAND_RADIUS.x, way.y * Iso.ISLAND_RADIUS.y
	) * ARRIVE_ASHORE


## One frame of it. Three beats and no timeline: the hull's own state machine says when it
## has berthed, and the angler's own walk says when he has arrived.
func _arrival_step() -> void:
	match _arrive:
		Arrive.SAILING:
			if _boats.is_empty() or _boats[0].state != Boat.State.DOCKED:
				return
			_arrive_wait -= get_process_delta_time()
			if _arrive_wait > 0.0:
				return
			_angler.visible = true
			for dog in _dogs:
				dog.tile_pos = _ashore_of(_boats[0].dock)
				dog.visible = true
				dog.doze(false)
			_angler.walk_to = _before_the_door()
			_arrive = Arrive.WALKING
			_arrive_wait = ARRIVE_READ
		Arrive.WALKING:
			if _angler.walk_to != Vector2.INF:
				return
			_arrive_wait -= get_process_delta_time()
			if _arrive_wait > 0.0:
				return
			# A state of its own, and not for tidiness: `WALKING` is tested every frame, and
			# without somewhere to go the step raised the letter again on each one — which
			# calls `Letter.open`, which puts the reader back on the first card. The cards
			# could not be paged at all until this was here.
			_arrive = Arrive.READING
			_set_letter(true)


## The letter is down: the intro is over, the flag is written, and the hull may sail.
func _finish_intro() -> void:
	if _arrive == Arrive.OFF:
		return
	_arrive = Arrive.OFF
	_angler.walk_to = Vector2.INF
	for boat in _boats:
		boat.moored = false
	_intro_done = true
	save_game()


## One frame of the first steps: start them once the letter is down and the view is the
## player's, move them on, and hand the overlay where everything is this frame.
func _first_steps_step(delta: float) -> void:
	if _steps_done or not _intro_done or _arrive != Arrive.OFF or _glide >= 0.0:
		if _steps != null:
			_steps.visible = false
		return
	if _steps == null or _steps.step == FirstSteps.Step.OFF:
		if not _begin_first_steps():
			return
	var hidden := _panelled() or _farewell != null
	_steps.visible = not hidden
	_steps.pad = Pad.is_pad()
	_steps.head = _angler.position + Vector2(0.0, -FirstSteps.HEAD_UP)
	match _steps.step:
		FirstSteps.Step.MOVE:
			if _angler.tile_pos.distance_to(_steps_beach) <= STEPS_ARRIVE:
				_steps.step = FirstSteps.Step.CAST
				_steps.beach = Vector2.INF
		FirstSteps.Step.CAST:
			# The piece the ring was on can go (a dog, the second net): find another.
			if not _sure_catch(_steps_water):
				_push_net_numbers()
				_steps_water = _cast_spot_from(_angler.tile_pos)
			_steps.water = _steps_water
			_steps.water_wide = _steps_ring()
		FirstSteps.Step.NOTE:
			_steps.water = Vector2.INF
			# Over the box's mouth, not its foot: the arrow stands on this point.
			_steps.crate = _yard.position + Vector2(0.0, -STEPS_CRATE_UP)
			# A pad has no pointer on the bare lake to click the note shut with.
			if Pad.is_pad():
				_steps_left = minf(_steps_left, STEPS_NOTE_HOLD)
			if not hidden:
				_steps_left -= delta
			if _steps_left <= 0.0:
				_end_first_steps()


## Put the steps up: find the beach spot and the water off it, and build the overlay the
## first time. False (and the steps marked done) where no spot is found, so a lake with no
## catchable water near the island is never stuck on a hint it cannot finish.
func _begin_first_steps() -> bool:
	_push_net_numbers()
	var started := Time.get_ticks_msec()
	var beach := _beach_spot()
	if beach == Vector2.INF:
		_steps_done = true
		return false
	if _steps == null:
		_steps = FirstSteps.new()
		_steps.name = &"FirstSteps"
		var hud := _settings.get_parent()
		hud.add_child(_steps)
		# Under every board on the layer: it is hidden while one is up anyway.
		hud.move_child(_steps, 0)
	_steps_beach = beach
	_steps_found_ms = Time.get_ticks_msec() - started
	_steps_water = _cast_spot_from(beach)
	_steps.keys = [
		Binds.label_of(Binds.bound(&"walk_up", "key")),
		Binds.label_of(Binds.bound(&"walk_left", "key")),
		Binds.label_of(Binds.bound(&"walk_down", "key")),
		Binds.label_of(Binds.bound(&"walk_right", "key")),
	]
	_steps.beach = Iso.tile_to_world(beach.x, beach.y)
	_steps.water = Vector2.INF
	_steps.crate = Vector2.INF
	_steps.step = FirstSteps.Step.MOVE
	return true


## A new game's bed starts at the pump, not in the shed: the decoration tour washes it first.
func _bed_to_the_pump() -> void:
	unlocked.erase(STARTER_BED)
	for i in range(decor.size() - 1, -1, -1):
		if String((decor[i] as Dictionary)["piece"]) == STARTER_BED:
			decor.remove_at(i)
	if not unwashed.has(STARTER_BED):
		unwashed.append(STARTER_BED)
	if _room != null:
		_room.unlocked = unlocked
		_room.unwashed = unwashed


## One frame of the decoration tour: what the card points at and says, given which room is
## up. A card waits for its room — shut the shed on the second card and it is there again
## the next time the shed opens.
func _decor_tour_step(delta: float) -> void:
	if _decor_tour_done or _decor_tour == DecorTour.OFF:
		if _tour_card != null and _tour_card.visible:
			_tour_card.show_card(Rect2())
		return
	if _tour_card == null:
		_tour_card = TourCard.new()
		_tour_card.name = &"DecorTour"
		_skin.get_parent().add_child(_tour_card)
		_tour_card.next_asked.connect(_decor_tour_next)
		_tour_card.skip_asked.connect(_end_decor_tour)
	# Over every board and room on the layer.
	_skin.get_parent().move_child(_tour_card, _skin.get_parent().get_child_count() - 1)
	var pad := Pad.is_pad()
	_tour_card.pad = pad
	var off := Rect2()
	if _decor_tour_wait > 0.0:
		_decor_tour_wait -= delta
		_tour_card.show_card(off)
		if _decor_tour_wait <= 0.0 and _decor_tour == DecorTour.SHELF and _wash_open:
			_set_wash(false)
			_set_shed(true)
		return
	var room := _room_box_of
	match _decor_tour:
		DecorTour.HINT:
			if _panelled() or _fronted():
				_tour_card.show_card(off)
			else:
				_tour_card.show_card(_skin.shed_box(), DECOR_HINT)
		DecorTour.PLANK:
			_tour_card.show_card(room.call(_room.wash_plank_box()) if _shed_open else off, DECOR_PLANK, 1, DECOR_TOUR_CARDS, true)
		DecorTour.PLANK_WAIT, DecorTour.WASHING:
			if _shed_open:
				_tour_card.show_card(room.call(_room.wash_plank_box()))
			else:
				_tour_card.show_card(off)
		DecorTour.LIST:
			# A click on a find in the list puts it on the stand, and the stand's card is up
			# over it (2026-09-24): the click is the step, not a way past it.
			if _wash_open and _wash.stand().state != WashStand.State.EMPTY:
				_decor_tour = DecorTour.STAND
			elif _wash_open:
				_tour_card.show_card(_wash_list_box(), DECOR_LIST, 2, DECOR_TOUR_CARDS, true)
			else:
				_tour_card.show_card(room.call(_room.wash_plank_box()) if _shed_open else off)
		DecorTour.STAND:
			if _wash_open and _decor_stand_from < 0.0:
				_decor_stand_from = _wash.stand().share_clean()
			if _wash_open and _wash.stand().share_clean() > _decor_stand_from + DECOR_SPRAYED:
				_decor_tour = DecorTour.WASHING
			elif _wash_open:
				var words := DECOR_STAND_PAD % Binds.shown(&"cast", true) if pad else DECOR_STAND
				_tour_card.show_card(_wash_stand_box(), words, 3, DECOR_TOUR_CARDS, true)
			else:
				_tour_card.show_card(room.call(_room.wash_plank_box()) if _shed_open else off)
		DecorTour.SHELF:
			var words := DECOR_SHELF % Binds.shown(&"shed_rotate", false)
			if pad:
				words = DECOR_SHELF_PAD % ["A", Binds.shown(&"shed_rotate", true)]
			# A piece put down on the floor is the step done: the room's card follows.
			if _decor_tour_placed < 0:
				_decor_tour_placed = _room.decor.size()
			if _shed_open and _room.carrying.is_empty() and _room.decor.size() > _decor_tour_placed:
				_decor_tour = DecorTour.ROOM
			elif _shed_open and not _room.carrying.is_empty():
				_tour_card.show_card(off)
			else:
				_tour_card.show_card(room.call(_room.shelf_box()) if _shed_open else off, words, 4, DECOR_TOUR_CARDS, true)
		DecorTour.ROOM:
			var lit: Rect2 = _room.switch_box()
			if lit.size.x <= 0.0:
				lit = _room.room_box()
			_tour_card.show_card(room.call(lit) if _shed_open else off, DECOR_ROOM, 5, DECOR_TOUR_CARDS)


## A rect in the shed room's own pixels, on the HUD layer the card is drawn on.
func _room_box_of(box: Rect2) -> Rect2:
	if box.size.x <= 0.0:
		return Rect2()
	return Rect2(_room.global_position + box.position, box.size)


## The wash room's tray (with its title plank) and its stand, on the card's layer.
func _wash_list_box() -> Rect2:
	var box := _wash.tray_box()
	box = box.grow_individual(0.0, WashRoom.TRAY_RIBBON * 0.5, 0.0, 0.0)
	return Rect2(_wash.global_position + box.position, box.size)


func _wash_stand_box() -> Rect2:
	var view := _wash.size
	var wide := WashStand.STAND_WIDE
	return Rect2(
		_wash.global_position + Vector2(view.x * (1.0 - wide) * 0.5, view.y * 0.17),
		Vector2(view.x * wide, view.y * 0.76)
	)


func _decor_tour_next() -> void:
	match _decor_tour:
		DecorTour.PLANK:
			_decor_tour = DecorTour.PLANK_WAIT
		DecorTour.LIST:
			_decor_tour = DecorTour.STAND
		DecorTour.STAND:
			_decor_tour = DecorTour.WASHING
		DecorTour.SHELF:
			_decor_tour = DecorTour.ROOM
		DecorTour.ROOM:
			_end_decor_tour()


## Read through or skipped: not shown again.
func _end_decor_tour() -> void:
	_decor_tour = DecorTour.OFF
	_decor_tour_done = true
	if _tour_card != null:
		_tour_card.show_card(Rect2())
	save_game()


## The shop's tour is over, read through or skipped: it is not shown again.
func _on_shop_tour_ended(_skipped: bool) -> void:
	_shop_tour_done = true
	save_game()


## The last step is over: the flag, and a save so a Continue does not teach it again.
func _end_first_steps() -> void:
	if _steps != null:
		_steps.step = FirstSteps.Step.OFF
		_steps.visible = false
	_steps_done = true
	save_game()


## A spot on the island's beach, off which green water is in reach: the nearest such spot
## at least `STEPS_WALK_LEAST` from the angler, or the nearest at all, or INF.
func _beach_spot() -> Vector2:
	var best := Vector2.INF
	var best_far := Vector2.INF
	for i in 48:
		var turn := TAU * float(i) / 48.0
		var far := Iso.ISLAND_CENTRE + Vector2(cos(turn), sin(turn)) * 30.0
		var edge: Vector2 = _angler.shore_toward(far)
		var spot := edge.move_toward(Iso.ISLAND_CENTRE, STEPS_BEACH_IN)
		if not bool(_angler.call(&"_can_stand", spot)):
			continue
		if _cast_spot_from(spot) == Vector2.INF:
			continue
		var gap := spot.distance_to(_angler.tile_pos)
		if gap >= STEPS_WALK_LEAST and (best_far == Vector2.INF or gap < best_far.distance_to(_angler.tile_pos)):
			best_far = spot
		if best == Vector2.INF or gap < best.distance_to(_angler.tile_pos):
			best = spot
	return best_far if best_far != Vector2.INF else best


## Green water in reach of a standing tile, straight out from the island's middle through
## it: the first spot along that line where the aim ring would read green. A world point.
func _cast_spot_from(stand: Vector2) -> Vector2:
	var out := (stand - Iso.ISLAND_CENTRE).normalized()
	if out == Vector2.ZERO:
		return Vector2.INF
	var reach := _net.range_tiles
	var along := reach * STEPS_CAST_FROM
	var side := Vector2(-out.y, out.x)
	var tries: Array[Vector2] = []
	while along <= reach * STEPS_CAST_TO:
		# Straight out first, then a tile and two either side of the line.
		for aside in [0.0, 1.0, -1.0, 2.0, -2.0]:
			tries.append(stand + out * along + side * aside)
		along += 0.25
	for tile in tries:
		if Iso.island_fraction(tile.x, tile.y) < 1.0 or Iso.shore_fraction(tile.x, tile.y) >= 1.0:
			continue
		var at := Iso.tile_to_world(tile.x, tile.y)
		if Iso.world_to_tile(at).distance_to(stand) + _steps_ring() / (Iso.TILE_W * 0.5) > reach:
			continue
		if _sure_catch(at):
			return at
	return Vector2.INF


## The cast ring's half-width in world pixels: a share of the net's open mouth. What makes
## a throw anywhere inside it a sure catch is `_sure_catch`, not the size.
func _steps_ring() -> float:
	return _net.open_extent() * STEPS_RING_SHARE


## Whether a throw landing anywhere in the ring round this spot catches: the aim ring's own
## verdict at the middle and at `STEPS_RING_TESTS` points round the rim and half way in.
func _sure_catch(at: Vector2) -> bool:
	if at == Vector2.INF or not _net.would_catch(at):
		return false
	var wide := _steps_ring()
	for i in STEPS_RING_TESTS:
		var turn := TAU * float(i) / float(STEPS_RING_TESTS)
		var rim := Vector2(cos(turn) * wide, sin(turn) * wide * 0.5)
		if not _net.would_catch(at + rim) or not _net.would_catch(at + rim * 0.5):
			return false
	return true


## The cards, on the HUD's layer over everything the lake draws. Built the first time they
## are asked for, the way the wash room and the bind board are.
func _set_letter(open: bool) -> void:
	if open and _letter == null:
		_letter = Letter.new()
		_letter.name = &"Letter"
		_letter.set_anchors_preset(Control.PRESET_FULL_RECT)
		_letter.close_asked.connect(_shut.bind(_set_letter))
		_settings.get_parent().add_child(_letter)
	if _letter == null:
		return
	if open and not _letter_open and _sfx != null:
		_sfx.play(&"shed_open")
	_letter_open = open
	if open:
		_letter.open()
	else:
		_letter.visible = false
		_finish_intro()
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
		or _farewell != null or _fronted() or _letter_open or _arrive != Arrive.OFF
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
		# The wash room covers the lake as the shed's does, and is as deaf to it.
		_sfx.indoors = _shed_open or _wash_open
	var music := MusicStation.main()
	if music == null:
		return
	music.indoors = _shed_open
	# The wash room too (Richard, 2026-09-19): the song through the radio, as behind the shop.
	music.muffled = _menu_open or _settings_open or _wash_open
	music.set_ending(ending())


## The way out of the lake is the menu, not the desktop (2026-09-12): the run is written
## first, and the menu's own Quit and the window's cross are what close the game.
##
## **No scene change** (2026-09-17): the menu is an overlay on this lake, so going to it is
## the view dimming, that dimmed frame frozen over the screen, the world snapped into the
## menu's pose behind it, and the frozen frame dissolving onto the menu (`Curtain.dissolve`).
## A lake borrowed by a tool has no curtain, and does it at once.
func _quit() -> void:
	if _fronted():
		return
	if _curtain == null:
		_go_to_menu()
		return
	# The lake stops answering now, not when the view has dimmed.
	_leaving = true
	_hold_the_angler()
	_curtain.dissolve(_go_to_menu)


func _go_to_menu() -> void:
	_leaving = false
	if _farewell != null:
		_farewell.get_parent().queue_free()
		_farewell = null
	_enter_menu(false)
	# Written once the pose is struck, not before it: the catch in the net, the sticks in
	# the dogs' mouths and the holds afloat are all in the crate by now, so the file holds
	# every piece. Written first, as it used to be, a net's catch was in neither.
	save_game()


# ---- The menu over the lake -------------------------------------------------------------
#
# The main menu is this scene (2026-09-17, `/grill-me` with Richard): the lake is the
# game's main scene, the player's own run loads behind the doors, and `MainMenu` is an
# overlay on a layer of its own. Behind it the world is alive but **posed** — water, birds,
# fish, flora and the day all run; the dogs are asleep, the hulls are moored, the angler
# stands idle, nothing sells, nothing is saved and no input reaches the lake. The view is
# pulled back to the whole lake, because the lake clearing up is the progress bar and the
# menu says nothing else about the run. Continue takes the menu off and glides the view down
# to the angler; there is no scene change to wait for. Supersedes `scenes/menu.tscn`, the
# baked `menu_lake.png` and `change_scene_to_file` in both directions.
#
# **Only a lake run as the game wears it.** A tool or a harness instantiates `main.tscn`
# under a node of its own, and gets the lake it always did: no menu, no curtain, playing
# from the first frame. `test_lake` raises the menu by hand (`_enter_menu`).

## Set before a reload to come up playing rather than in the menu: New game over a run, the
## tree's doors, F6. Read once, the way `start_fresh` is.
static var skip_menu: bool = false
## The game's first scene, which a reload goes back through: one loading screen in the game.
const BOOT_SCENE := "res://scenes/boot.tscn"

const MENU_LAYER := 30
## Where across the window the lake's middle stands behind the menu: right of centre, so the
## logo and the planks have the left bank to stand over. As far as the ground allows — the
## view is still clamped to it, and on a wide window that may be less than this asks.
const MENU_LAKE_AT := 0.62
## The glide down to the angler, in seconds, and the share of it after which the HUD starts
## to come in. **The one zoom glide in the game, by decision** (Richard, over stepping stop
## by stop): the pixel rule is about where the view *rests*, and this passes through the
## fractional levels in a second and a half and lands on a stop. The art crawls while it
## moves; accepted, for this move only. The wheel still steps.
const GLIDE_TIME := 1.6
const GLIDE_HUD_FROM := 0.6
## A lake that comes up playing (`skip_menu`) sets off on its glide this long after it goes
## in: the curtain's held frames and the better part of its dissolve.
const SKIP_GLIDE_AFTER := 0.7

## For the probes that photograph the menu: wear the front although borrowed. Set before the
## scene enters the tree, like `save_path`.
var force_front: bool = false
## For the one probe that photographs the arrival: play it although the lake is borrowed.
## Read once, the way `skip_menu` is, so it cannot leak into the next lake of the session.
static var force_intro: bool = false

var _in_menu: bool = false
## On the way to the menu: the view is dimming and the lake has stopped answering.
var _leaving: bool = false
## Seconds into the glide, or under zero when there is none.
var _glide: float = -1.0
var _glide_zoom_from: float = 1.0
var _glide_zoom_to: float = 1.0
## Where the angler stood on the screen when the glide began, off the middle, in pixels.
var _glide_offset := Vector2.ZERO
var _menu: MainMenu
var _curtain: Curtain


## Whether the menu has the lake: up, on its way up, or on its way off.
func _fronted() -> bool:
	return _in_menu or _leaving or _glide >= 0.0


## The end of `_ready`: the curtain and, unless told otherwise, the menu.
func _raise_front(loaded: bool) -> void:
	var playing := skip_menu
	skip_menu = false
	# Borrowed by a tool: see the header. A borrowed lake also never plays the arrival —
	# a harness that raises the menu by hand and glides down out of it is not a new game,
	# and a probe photographing the front is not one either — unless it says so, which is
	# what `tools/shot_letter.tscn` is for.
	if get_parent() != get_tree().root:
		if not force_intro:
			_intro_done = true
			_steps_done = true
			_shop_tour_done = true
			_decor_tour_done = true
		force_intro = false
		if not force_front:
			return
	# Under the loading screen's own picture, which the boot scene has just been showing.
	_curtain = Curtain.new()
	add_child(_curtain)
	_curtain.open_on()
	_build_menu()
	_menu.has_run = loaded
	_enter_menu(true)
	if not playing:
		return
	# Straight into the game: the same pose and the same view, with no doors on it, and the
	# glide setting off by itself as the loading picture goes. One way down into the lake.
	_menu.put_away(true)
	get_tree().create_timer(SKIP_GLIDE_AFTER).timeout.connect(_begin_glide)


func _build_menu() -> void:
	if _menu != null:
		return
	var over := CanvasLayer.new()
	over.name = &"MenuLayer"
	over.layer = MENU_LAYER
	add_child(over)
	_menu = MainMenu.new()
	_menu.name = &"Menu"
	_menu.visible = false
	_menu.play_asked.connect(_begin_glide)
	_menu.reload_asked.connect(_reload_as)
	over.add_child(_menu)


## Raise the menu and strike the pose behind it. `at_once` is the boot, which comes up under
## the curtain with the pack scattered over the island; otherwise it is the way back from
## the game, struck behind the curtain's frozen frame, where each dog lies down where it
## stands.
func _enter_menu(at_once: bool) -> void:
	_build_menu()
	_in_menu = true
	_glide = -1.0
	_set_controls(false)
	_set_settings(false)
	_set_menu(false)
	_set_shed(false)
	_set_wash(false)
	_stop_led_cast()
	_pose_world(at_once)
	_hud_layer.visible = false
	if _coins != null:
		_coins.clear()
	_pan = Vector2.ZERO
	_panning = false
	_pan_yielded = false
	# Back from the menu the view glides down onto the angler, which a pinned view cannot.
	_free_view = false
	_free_camera.lit = false
	_cast_look = 0.0
	_homing = false
	_hold_the_angler()
	_hold_menu_view()
	_snap_camera()
	# Back from the game there is a run behind the menu whether or not one was loaded: it
	# has just been played, and New game would throw it away.
	_menu.has_run = _menu.has_run or not at_once
	_menu.show_up(at_once)


## The pose: everything in flight brought home, the fleet moored, the pack asleep. Nothing
## is lost to it — a catch, a hold and a mouthful all end up in the crate, which is the
## rule a save already keeps for a hold afloat — and nothing is sold by it.
func _pose_world(scatter: bool) -> void:
	for net: CastNet in [_net, _net2]:
		if net != null:
			net.stow()
	if _haul != null:
		_haul.land_all()
	for boat in _boats:
		boat.moored = true
		for piece in boat.moor_now():
			_yard.put(piece)
	for dog in _dogs:
		for piece in dog.doze(true, scatter):
			_dog_brought_back(piece)
	_sort_walkers()


## Let the pose go: the fleet may sail and the pack wakes, each dog in its own time.
func _release_world() -> void:
	for boat in _boats:
		boat.moored = false
	for dog in _dogs:
		dog.doze(false)


## The view behind the menu: the far stop, the whole lake, its middle `MENU_LAKE_AT` across.
func _hold_menu_view() -> void:
	_view_zoom = _zoom_stops()[0]
	_push_zoom()
	_camera.position = _menu_view()


func _menu_view() -> Vector2:
	var middle := Iso.tile_to_world(Iso.CENTRE.x, Iso.CENTRE.y)
	var wide := get_viewport_rect().size.x / _camera.zoom.x
	return _clamped_view(middle - Vector2((MENU_LAKE_AT - 0.5) * wide, 0.0))


## Continue, or New game where there was nothing to lose: the menu goes and the view comes
## down. The world is let go at once — a ferry setting off as the view arrives is the game
## starting — but the player's hands come back only when the view has landed.
func _begin_glide() -> void:
	if not _in_menu:
		return
	_in_menu = false
	_menu.put_away()
	_release_world()
	var stops := _zoom_stops()
	_glide = 0.0
	_glide_zoom_from = _camera.zoom.x
	_glide_zoom_to = stops[_nearest_stop(stops, VIEW_ZOOM)]
	_glide_offset = (_watching() - _camera.position) * _glide_zoom_from
	_autosave_in = AUTOSAVE_EVERY
	_skin.modulate.a = 0.0
	_open_settings.modulate.a = 0.0
	_free_camera.modulate.a = 0.0
	_hud_layer.visible = true
	_start_arrival()


## One frame of the glide. The zoom runs in its logarithm, so the push reads as one even
## move rather than fast then slow; and what is interpolated is **where the angler stands on
## the screen**, not the camera's place in the world, so they drift steadily to the middle
## instead of swinging in on the curve a lerped position makes under a moving zoom.
func _glide_step(delta: float) -> void:
	_glide += delta
	var t := clampf(_glide / GLIDE_TIME, 0.0, 1.0)
	var eased := t * t * (3.0 - 2.0 * t)
	var zoom := exp(lerpf(log(_glide_zoom_from), log(_glide_zoom_to), eased))
	_camera.zoom = Vector2(zoom, zoom)
	_camera.position = _clamped_view(_watching() - _glide_offset * (1.0 - eased) / zoom)
	var hud := clampf((t - GLIDE_HUD_FROM) / (1.0 - GLIDE_HUD_FROM), 0.0, 1.0)
	_skin.modulate.a = hud
	_open_settings.modulate.a = hud
	_free_camera.modulate.a = hud
	if t < 1.0:
		return
	_glide = -1.0
	_view_zoom = _glide_zoom_to
	_push_zoom()
	_hold_the_angler()


## This lake is thrown away for another, behind the loading screen: a fresh run over this
## one, or the tree's. The file is deleted here, where it is known which file is this run's.
## The game's own lake goes back through the boot scene, off a curtain already showing that
## scene's first frame; a borrowed one reloads whatever borrowed it.
func _reload_as(fresh: bool) -> void:
	_leaving = true
	var go := func() -> void:
		_wiping = true
		if fresh:
			# This run's own file: a harness plays on a path of its own.
			if FileAccess.file_exists(save_path):
				DirAccess.remove_absolute(save_path)
		skip_menu = true
		if get_parent() == get_tree().root:
			get_tree().change_scene_to_file(BOOT_SCENE)
		else:
			get_tree().reload_current_scene()
	if _curtain == null:
		go.call()
	else:
		_curtain.to_loading(go)


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
	if taken > 0 and _net_from == _net and _steps != null and _steps.step == FirstSteps.Step.CAST:
		_steps.step = FirstSteps.Step.NOTE
		_steps_landed = false
		_steps_left = STEPS_NOTE_MOST
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


## A net reeling with a catch aboard drops a lane point every LANE_SPACING of travel; a net
## doing anything else forgets where it last dropped one, so the next reel starts a fresh
## lane with a fresh roll.
func _lay_lane(net: CastNet) -> void:
	if net == null:
		return
	var id := net.get_instance_id()
	if net.state != CastNet.State.REELING or net.catch.is_empty():
		if _lane_last.erase(id) and _lane_last.is_empty():
			_lane_seed = _patch_rng.randf()
		return
	var at := net.world_pos()
	if _lane_last.has(id) and (_lane_last[id] as Vector2).distance_to(at) < LANE_SPACING:
		return
	_lane_last[id] = at
	var point := {"at": at, "radius": net.mouth_extent() * LANE_WIDE, "born": _patch_clock}
	if _lane.size() < LANE_POINTS:
		_lane.append(point)
		return
	var oldest := 0
	for i in _lane.size():
		if float(_lane[i]["born"]) < float(_lane[oldest]["born"]):
			oldest = i
	_lane[oldest] = point


## How open a lane point is: the patch's own curve, over the lane's shorter life.
func _lane_open(point: Dictionary) -> float:
	var age := _patch_clock - float(point["born"])
	if age < PATCH_IN:
		var u := clampf(age / PATCH_IN, 0.0, 1.0)
		return u * u * (3.0 - 2.0 * u)
	var t := clampf((age / LANE_LIFE - PATCH_HOLD) / (1.0 - PATCH_HOLD), 0.0, 1.0)
	return 1.0 - t * t * (3.0 - 2.0 * t)


## Every frame: age the patches and the lane, drop what has closed, hand the rest to the
## water.
func _push_patches(delta: float) -> void:
	_patch_clock += delta
	for i in range(_patches.size() - 1, -1, -1):
		if _patch_clock - float(_patches[i]["born"]) >= PATCH_LIFE:
			_patches.remove_at(i)
	_lay_lane(_net)
	_lay_lane(_net2)
	for i in range(_lane.size() - 1, -1, -1):
		if _patch_clock - float(_lane[i]["born"]) >= LANE_LIFE:
			_lane.remove_at(i)
	if _water_material == null:
		return
	var lane := PackedVector4Array()
	lane.resize(LANE_POINTS)
	for i in mini(_lane.size(), LANE_POINTS):
		var at: Vector2 = _lane[i]["at"]
		lane[i] = Vector4(at.x, at.y, float(_lane[i]["radius"]), _lane_open(_lane[i]))
	_water_material.set_shader_parameter(&"lane", lane)
	_water_material.set_shader_parameter(&"lane_seed", _lane_seed)
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
	if _fish != null:
		_fish.scare(_net.position)
	if _wildlife != null:
		_wildlife.scare(_net.position)
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
	if _steps != null and _steps.step == FirstSteps.Step.NOTE and not _steps_landed:
		_steps_landed = true
		_steps_left = minf(_steps_left, STEPS_NOTE_HOLD)
	_ask_the_end()


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
	# Waiting at the pump is still had: a new game's bed goes there (the decoration tour).
	if unlocked.has(piece) or unwashed.has(piece):
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
	# Washed or waiting, a copy is a copy: counted over both lists.
	var held := 0
	for kept: String in unlocked + unwashed:
		if kept == name:
			held += 1
	if _sheets != null and held >= _sheets.copies_of(StringName(name)):
		return
	# To the pump, not to the shelf (issue #37): it is washed before the shed will have it.
	unwashed.append(name)
	if not _decor_tour_done and _decor_tour == DecorTour.OFF:
		_decor_tour = DecorTour.HINT
		_decor_tour_wait = DECOR_HINT_AFTER
	# Held up in the middle of the screen as well as written in the corner. The shed is two
	# clicks away, so without this the player never sees what they found.
	if _trophy != null:
		_trophy.show_find(def.piece, def.display_name)
	if _sfx != null:
		_sfx.play_find_caught()


## The ferry landing a load at one of the four merchants. The purse moves here and nowhere
## else.
##
## The meter is not touched: everything the boat is carrying came out of the yard, where it
## was already counted.
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


## Every track the shop sells, in the order the board lists them. The rows themselves carry
## a name and a picture as well, but the HUD only wants to count them, and counting them
## should not mean formatting nine lines of text every frame.
const TRACKS := [
	&"net_width", &"net_strength", &"net_range", &"reel", &"net_hold",
	&"boat_speed", &"cargo", &"boat_volley", &"fleet",
	&"dog_fetch", &"dog_wait", &"dog_strength", &"dog_count",
	&"recycle_bonus", &"bird_worth", &"lucky_haul", &"double_cast",
]

## What each weight tier is called.
const TIER_NAMES := ["Light", "Small", "Medium", "Heavy", "Bulky"]

## What each upgrade is, one line, for the "?" in the corner of its row. Placeholder
## wording for now (2026-09-13): Richard writes the real lines once the rows read right.
## What stands between a row's figure now and its figure one level on. A mark rather than
## the words "(… next)": it is half the width, it is the same in every language, and Bungee
## has it (checked in `tools/probe_shop_glyphs.gd`).
const ARROW := "→"

const BLURBS := {
	&"net_width": "How wide the net's mouth opens, so one cast covers more water.",
	&"net_strength": "The heaviest weight tier the net can lift.",
	&"net_range": "How far from the shore the angler can throw.",
	&"reel": "How fast the net is reeled back in.",
	&"net_hold": "How many pieces one cast can carry home.",
	&"boat_speed": "How fast the ferry sails between the island and the yards.",
	&"cargo": "How many pieces the ferry carries a trip.",
	&"boat_volley": "How quickly a ferry throws its load aboard and into the yard's box.",
	&"fleet": "Another ferry in the water.",
	&"dog_fetch": "How many pieces the dog brings back a trip.",
	&"dog_wait": "How long the dog lazes about between trips, at most.",
	&"dog_count": "Another dog for the pack, trained like the first.",
	&"dog_strength": "The heaviest and biggest pieces the dogs can carry back.",
	&"lucky_haul": "Odds that a cast lifts one tier heavier and holds more.",
	&"double_cast": "Odds that a cast throws a second net beside the first.",
	&"recycle_bonus": "One yard at a time pays over the odds, and it moves.",
	&"bird_worth": "What a netted pigeon is worth.",
}


## How many upgrades could be bought right now. Drawn on the HUD's upgrades button, so that
## money worth spending says so on the way in rather than only once the board is open.
func _affordable() -> int:
	var count := 0
	for key: StringName in TRACKS:
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
	# Each line: key, board, name, the suffix that closes the figure, what the figure reads
	# at a given level, and — where a word goes in front instead — the prefix.
	#
	# The value is the figure now, `ARROW`, and the figure one level on, with **the prefix on
	# the first and the suffix on the last**, so a word or mark is said exactly once and the
	# two numbers stand bare between them: `100 → 135%`, `Tier 2 → 3`, `$26 → 30`, `12 → 9s`.
	# A maxed track shows one figure wearing both.
	#
	# **No nouns** (Richard, 2026-09-17): "a cast", "aboard", "a trip", "dogs" and "boats" are
	# gone — the row's name and its "?" already say what is being counted, and the widest
	# line in the shop was the thing deciding how small every row had to be drawn. `%`, `$`
	# and `s` stay, being marks rather than words, and "Tier" stays, being a concept of the
	# game with its own names rather than a unit of the row.
	var listed := [
		[&"net_width", &"net", "Width", "%", func(l: int) -> String: return _pct_at(&"net_width", l)],
		[&"net_strength", &"net", "Strength", "", func(l: int) -> String:
			return "%d" % int(_track_value(&"net_strength", l)), "Tier "],
		[&"net_range", &"net", "Range", "%", func(l: int) -> String: return _pct_at(&"net_range", l)],
		[&"reel", &"net", "Reel", "%", func(l: int) -> String: return _pct_at(&"reel", l)],
		[&"net_hold", &"net", "Catch", "", func(l: int) -> String:
			return "%d" % int(_track_value(&"net_hold", l))],
		[&"boat_speed", &"boat", "Sailing", "%", func(l: int) -> String: return _pct_at(&"boat_speed", l)],
		[&"cargo", &"boat", "Hold", "", func(l: int) -> String:
			return "%d" % int(_track_value(&"cargo", l))],
		[&"boat_volley", &"boat", "Loading", "%", func(l: int) -> String:
			# How fast the load moves as a share of how fast it moved at level 0, not the cut
			# itself: a row that says the gap is 40% of what it was is a row about the code.
			# The gap is what shrinks and the flight never does, so this tops out near 250%.
			return "%d" % roundi(100.0 / maxf(1.0 - _track_value(&"boat_volley", l), 0.01))],
		[&"fleet", &"boat", "Fleet", "", func(l: int) -> String: return "%d" % (1 + l)],
		[&"dog_count", &"dog", "Pack", "", func(l: int) -> String: return "%d" % (1 + l)],
		[&"dog_strength", &"dog", "Carry", "", func(l: int) -> String:
			return "%d" % (Dog.CARRY_TIER + int(_track_value(&"dog_strength", l))), "Tier "],
		[&"dog_fetch", &"dog", "Fetch", "", func(l: int) -> String:
			return "%d" % int(_track_value(&"dog_fetch", l))],
		[&"dog_wait", &"dog", "Keenness", "s", func(l: int) -> String:
			return "%d" % roundi(maxf(
				Dog.MOOD_MOST - _track_value(&"dog_wait", l), Dog.MOOD_LEAST
			))],
		# The odds and the bonus are bare percents, not shares of a base: there is no base to
		# be a share of, and they start at 0 where a scaling track starts at 100, which is
		# what tells the two kinds of percent on this board apart.
		[&"lucky_haul", &"luck", "Lucky cast", "%", func(l: int) -> String:
			return "%d" % roundi(_track_value(&"lucky_haul", l) * 100.0)],
		[&"double_cast", &"luck", "Double cast", "%", func(l: int) -> String:
			return "%d" % roundi(_track_value(&"double_cast", l) * 100.0)],
		# Which yard has the bonus, and how long it has left, is on the pricing plate
		# (`_shop_legend`): the bonus is a change to what one material pays, and the plate is
		# the one place that says what materials pay. The row sells a multiplier, so the row
		# says the multiplier.
		[&"recycle_bonus", &"luck", "Bonus yard", "%", func(l: int) -> String:
			return "%d" % roundi(_track_value(&"recycle_bonus", l) * 100.0)],
		[&"bird_worth", &"luck", "Pigeons", "", func(l: int) -> String:
			return "%d" % roundi(_economy.bird_bonus * _track_value(&"bird_worth", l)), "$"],
	]
	for line: Array in listed:
		var key: StringName = line[0]
		var full := is_maxed(key)
		var price := cost_of(key)
		var level := _level_of(key)
		var suffix: String = line[3]
		var reads: Callable = line[4]
		var prefix: String = String(line[5]) if line.size() > 5 else ""
		var now: String = reads.call(level)
		var said := now if full else "%s %s %s" % [now, ARROW, reads.call(level + 1)]
		said = prefix + said + suffix
		out.append({
			"key": key,
			"board": line[1],
			"name": line[2],
			# The figure alone. "Lvl" is a word the row does not need and a translation would
			# have to carry, and the rail it stands in is what says the figure is a level.
			"level": str(level),
			"value": said,
			# What the upgrade is, for the row's "?".
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


## What a scaling track is worth at a level, as a **share of what it was worth at level 0**:
## `100` at the start, `900` at the top of the longest track. The figure the row prints, bare
## — the `%` is put on by `_shop_rows` as the line's suffix.
##
## It used to read the rise instead — `(value / base - 1) x 100`, printed as `+385%`. Two
## three-digit figures either side of the arrow came to 118px against a row's 87 and cut, and
## dropping the `+` to save the width would have been a lie: `385%` claims 3.85x where the
## stat is 4.85x. Measuring from the base instead needs no sign and is the same width.
## A track whose base is nothing has no share to be of, and reads as its plain number.
func _pct_at(key: StringName, level: int) -> String:
	var base := _track_value(key, 0)
	if base <= 0.0:
		return "%d" % roundi(_track_value(key, level))
	return "%d" % roundi(_track_value(key, level) / base * 100.0)


## What the market's legend under the boards says (2026-09-13, second pass, Richard):
## the four materials with what a piece of each pays on average, the tiers with their sell
## rates, and one line of explanation. Nothing else — the first pass said too much.
func _shop_legend() -> Dictionary:
	# The sell-by-tier rates used to stand here; the tracks were cut (2026-09-18).
	var tiers: Array = []
	var yards: Array = []
	for kind in TrashDef.KIND_NAMES.size():
		yards.append([TrashDef.KIND_NAMES[kind], "$%d" % roundi(_mean_pay_of(kind))])
	# The recycle bonus lives here rather than in its row: it is a change to what one
	# material pays, and this is the one place that says what materials pay.
	#
	# It carries no figure of its own, because `_mean_pay_of` goes through `piece_pay`,
	# which already multiplies the boosted kind — so the boosted material's price in `yards`
	# above *is* the boosted price, and always has been. The plate has been printing it for
	# as long as the bonus has existed, with nothing on it saying why the number moved. All
	# this adds is the saying. Empty when no bonus is running.
	var bonus := {}
	if _bonus_kind >= 0 and recycle_bonus_level > 0:
		bonus = {
			"kind": _bonus_kind,
			"pct": "+%d%%" % roundi(_track_value(&"recycle_bonus", recycle_bonus_level) * 100.0),
			"seconds": ceili(_bonus_left),
		}
	return {
		"tiers": tiers,
		"yards": yards,
		"bonus": bonus,
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
	return track.cost(_level_of(what)) if track != null else INF


## Where a track stops. resources/upgrades/*.tres.
func _level_cap(what: StringName) -> int:
	var track: UpgradeTrack = _upgrades.get(what)
	return track.level_cap if track != null else 0


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
		&"boat_volley":
			return boat_volley_level
		&"fleet":
			return fleet_level
		&"dog_fetch":
			return dog_fetch_level
		&"dog_wait":
			return dog_wait_level
		&"dog_strength":
			return dog_strength_level
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
		&"boat_volley":
			boat_volley_level += 1
		&"fleet":
			fleet_level += 1
			_add_boat()
		&"dog_fetch":
			dog_fetch_level += 1
		&"dog_wait":
			dog_wait_level += 1
		&"dog_strength":
			dog_strength_level += 1
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
	# After the level goes on, not before: the sound is the purchase landing, and a buy that
	# fell through above has already returned without making one. The sparkle over the
	# board's sprite is the same receipt for the eye.
	if _sfx != null:
		_sfx.play_bought()
	_shop_skin.cheer(what)
	if _logs_play():
		PlayLog.write("purchase", _play, {
			"id": String(what),
			"rank": _level_of(what),
			"cost": roundi(price),
			"sludge_after": roundi(sludge),
			"cleared": snappedf(_cleared_share(), 0.0001),
			"box": _yard.held.size(),
		})
	_push_net_numbers()
	_push_boat_numbers()
	_push_dog_numbers()


# ------------------------------------------------------------------ playtest log

## Whether this lake writes the playtest log: the player's own run and nothing else — the lake
## run as the game (the root's own child) on the player's own save path. A harness hangs its
## lake under a node of its own and a probe plays on a save of its own, and either is enough
## to keep it out: `tools/shot_menus` did neither once and wrote two lines into the real log.
func _logs_play() -> bool:
	return save_path == SAVE_PATH and is_inside_tree() and get_parent() == get_tree().root


## A sitting of the shop run has begun, fresh or from its save.
func _begin_play_session(loaded: bool) -> void:
	if not loaded:
		_play = 0.0
	_play_progress_in = 0.0
	_play_last_cast = -1.0
	var levels := {}
	for key: StringName in TRACKS:
		levels[String(key)] = _level_of(key)
	PlayLog.write("session", _play, {
		"started": "continue" if loaded else "new",
		"levels": levels,
		"sludge": roundi(sludge),
		"cleared": snappedf(_cleared_share(), 0.0001),
	})


## The shop run's clock, and a line of where the run stands every `PLAY_PROGRESS_EVERY`. `box`
## is the HUD's Waiting figure: the boats are meant to stay ahead of it (issue #23).
func _tick_play_log(delta: float) -> void:
	_play += delta
	if not _logs_play():
		return
	_play_progress_in -= delta
	if _play_progress_in > 0.0:
		return
	_play_progress_in = PLAY_PROGRESS_EVERY
	PlayLog.write("progress", _play, {
		"cleared": snappedf(_cleared_share(), 0.0001),
		"pieces_left": _grid.piece_count(),
		"sludge": roundi(sludge),
		"birds": birds_caught,
		"box": _yard.held.size(),
		"ferries": fleet_size(),
		"dogs": dog_count(),
		"in_shed": _shed_open,
		"shop_open": _menu_open,
	})


## Share of the lake's pieces gone since it was built, for the playtest log.
func _cleared_share() -> float:
	return 1.0 - float(_grid.piece_count()) / float(maxi(_pieces_full, 1))


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
	boat.sold.connect(_on_sold)


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
	boat.auto_ferry = _auto_ferry_on
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
		dog.carry_tier = dog_carry_tier()
		dog.carry_wide = dog_carry_wide()


## How many dogs the pack has: the first plus what `dog_count` bought. The tree has one.
func dog_count() -> int:
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
	dog.slot = _dogs.size()
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
		boat.volley_gap = boat_volley_gap()


## Whether a docked hull sets off on its own, for the whole fleet. Called by the harness and
## by `probe_rates`; nothing in the game turns it off since the stock panel's checkbox went.
func _set_auto_ferry(on: bool) -> void:
	_auto_ferry_on = on
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


## What an empty net pushes on its way home, of the 0 to 1 the haul's sound is driven by.
## 0.36 until 2026-09-18 (Richard: a cast that caught nothing sounded much like one that
## did): an empty reel was already a third of a full one. Near silent now, and anything
## grabbed on the way home brings it up through `load` as before.
const EMPTY_WASH := 0.12


## How much water the net is pushing, 0 to 1. Nothing unless it is being hauled: a net
## sitting on the water is not making a sound. A wide mouth full of junk moves more water
## than an empty one, and the mouth pursing shut on the way in quiets it as it comes.
func _net_wash() -> float:
	if _net == null or _net.state != CastNet.State.REELING:
		return 0.0
	var load := float(_net.catch.size()) / maxf(float(_net.hold), 1.0)
	return clampf(EMPTY_WASH + (1.0 - EMPTY_WASH) * load, 0.0, 1.0) * lerpf(1.0, 0.45, _net.closed())


## The player's view, once a frame: following the angler, leaning out to a cast, dragged by
## the mouse. Everything `_process` does about the camera while the game is being played —
## the menu's hold and the glide down out of it are the two times it is not.
func _drive_view(delta: float) -> void:
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

	_free_camera.visible = not _panelled()
	if _free_now():
		_drive_free_view(delta)
		return

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


## Whether the view is the player's own this frame: the toggle is on and the mouse is the
## device. The pad's reticle leans the view and is held inside the window by it, so in pad
## mode the view follows as ever and free mode waits for the mouse to come back.
func _free_now() -> bool:
	return _free_view and not Pad.is_pad()


## The toggle beside the gear. On, the view is pinned where it stands; off, the follow eases
## it home from wherever it was left, with no pan to unwind.
func _toggle_free_view() -> void:
	_free_view = not _free_view
	_free_camera.lit = _free_view
	_free_at = _camera.position
	_pan = Vector2.ZERO
	_pan_yielded = false
	_homing = false


## Look at the angler again: the middle button's tap and the `recentre` verb. In free mode
## the view jumps to them and stays free — it is the way out of having lost yourself, not
## the way out of the mode.
func _recentre() -> void:
	_pan = Vector2.ZERO
	if _angler != null:
		_free_at = _clamped_view(_angler.position)


## The free camera's frame: pinned to `_free_at`, moved by the drag, the wheel and the edges.
## Eased, so coming back from pad mode is a move and not a cut; snapped under a drag, as the
## follow is.
func _drive_free_view(delta: float) -> void:
	_homing = false
	_free_at = _clamped_view(_free_at + _edge_scroll() * delta)
	if _panning:
		_camera.position = _free_at
	else:
		_camera.position = _camera.position.lerp(_free_at, _ease(FOLLOW_SPEED, delta))


## How fast the window's edges are pushing the view, in world px a second. Nothing while the
## pointer is out of the window or the window out of focus, while a board is up, while the
## middle button has the view, or while the pointer is on a HUD button — the corner buttons
## are inside the margin, and a hand going for one would slide the lake out from under it.
func _edge_scroll() -> Vector2:
	if not _mouse_inside or not get_window().has_focus() or _panelled() or _panning:
		return Vector2.ZERO
	var at := get_viewport().get_mouse_position()
	if _over_hud(at):
		return Vector2.ZERO
	return _edge_push(at, get_viewport_rect().size) * (
		EDGE_SPEED * get_viewport_rect().size.y / _camera.zoom.y
	)


## The push at a pointer `at` in a window `size`: nought inside the margin's inner line,
## rising to one at the very edge, on each axis by itself.
static func _edge_push(at: Vector2, size: Vector2) -> Vector2:
	var push := Vector2.ZERO
	push.x = _edge_axis(at.x, size.x)
	push.y = _edge_axis(at.y, size.y)
	return push


static func _edge_axis(at: float, size: float) -> float:
	if at < EDGE_MARGIN:
		return -clampf(1.0 - at / EDGE_MARGIN, 0.0, 1.0)
	if at > size - EDGE_MARGIN:
		return clampf(1.0 - (size - at) / EDGE_MARGIN, 0.0, 1.0)
	return 0.0


func _over_hud(at: Vector2) -> bool:
	for button: Control in [_open_settings, _free_camera]:
		if button.visible and button.get_global_rect().has_point(at):
			return true
	return _skin.over_button()


func _process(delta: float) -> void:
	_pad_tick(delta)
	_push_daylight()
	_part_the_fleet(delta)
	_remap_filth(delta)
	_push_patches(delta)
	if not _in_menu:
		_tick_bonus(delta)
		_arrival_step()
		_led_step(delta)
		_first_steps_step(delta)
		_decor_tour_step(delta)
	if _net2 != null:
		_net2.visible = _net2.state != CastNet.State.IDLE
	# The view: held on the whole lake behind the menu, flown down to the angler when the
	# menu lets go, and the player's own the rest of the time.
	if _in_menu:
		_hold_menu_view()
	elif _glide >= 0.0:
		_glide_step(delta)
	else:
		_drive_view(delta)

	# Nothing is decided behind the menu: no ending found, no run clocked, nothing written.
	# The world there is a pose, and a pose has nothing to save that was not saved going in.
	if not _in_menu:
		_look_for_the_end(delta)
		_tick_play_log(delta)

		_autosave_in -= delta
		if _autosave_in <= 0.0:
			save_game()

	# Not during the glide, which writes the zoom itself: this puts it on a stop.
	if _glide < 0.0:
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
	# And behind the pump, the crate's rule over again: it stands on the crate's layer, the
	# two are nowhere near each other, and the band under that layer is over the hut — which
	# is right, because the pump stands in front of the hut's wall.
	if _pump != null:
		var from := Iso.world_to_tile(at - _pump.position)
		if from.x < Pump.FOOT_HALF and from.y < Pump.FOOT_HALF \
				and absf(at.x - _pump.position.x) < _pump.drawn_wide() * 0.5:
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
	var share := _pooled_share(cols, rows)

	var pixels := PackedByteArray()
	pixels.resize(cols * rows)
	for i in dist.size():
		var near := clampf(1.0 - dist[i] / float(FILTH_BLUR), 0.0, 1.0)
		if near <= 0.0:
			continue
		var strength := lerpf(FILTH_FLOOR, 1.0, pow(share[i], FILTH_SHARE_BITE))
		pixels[i] = int(round(pow(near, FILTH_FALL) * strength * 255.0))

	# The grid keeps a copy for what it draws on the CPU — the ripple rings read the state
	# of the water under their piece off it, the way the shader does off the texture.
	_grid.filth = pixels
	_count_clean()

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
		_water_material.set_shader_parameter(&"glint", pow(_clean_share, GLINT_BITE) * GLINT_MOST)
	if _flora != null:
		_flora.refresh(_clean_share)
	if _fish != null:
		_fish.refresh(_clean_share, _clean_tiles)
	if _wildlife != null:
		_wildlife.refresh(_clean_share, _clean_tiles)


## How full of rubbish the water round each tile is, 0 to 1: the pieces afloat within
## FILTH_POOL tiles over what those tiles could hold. See FILTH_POOL.
##
## Two summed-area tables, so the cost is a pass over the grid whatever the pool's width —
## this runs on every remap, in the middle of a haul. Whole numbers, so there is no drift
## in the sums. The table of what the tiles could hold never changes and is built once.
func _pooled_share(cols: int, rows: int) -> PackedFloat32Array:
	var wide := cols + 1
	if _filth_room.is_empty():
		_filth_room.resize(wide * (rows + 1))
		for ty in rows:
			var run := 0
			for tx in cols:
				run += _room_at(tx, ty)
				_filth_room[(ty + 1) * wide + tx + 1] = _filth_room[ty * wide + tx + 1] + run
	var held := PackedInt32Array()
	held.resize(wide * (rows + 1))
	for ty in rows:
		var run := 0
		var row := ty * cols
		for tx in cols:
			var index := row + tx
			if not (index < _grid.dry.size() and _grid.dry[index] == 1):
				run += _grid.stacks[index].size()
			held[(ty + 1) * wide + tx + 1] = held[ty * wide + tx + 1] + run

	var share := PackedFloat32Array()
	share.resize(cols * rows)
	for ty in rows:
		var top := maxi(ty - FILTH_POOL, 0) * wide
		var foot := mini(ty + FILTH_POOL + 1, rows) * wide
		for tx in cols:
			var left := maxi(tx - FILTH_POOL, 0)
			var right := mini(tx + FILTH_POOL + 1, cols)
			var room := (
				_filth_room[foot + right] - _filth_room[top + right]
				- _filth_room[foot + left] + _filth_room[top + left]
			)
			if room <= 0:
				continue
			var pieces := held[foot + right] - held[top + right] - held[foot + left] + held[top + left]
			share[ty * cols + tx] = clampf(float(pieces) / float(room), 0.0, 1.0)
	return share


## What one tile could hold, for the pooled share: MAX_SLOTS over most of the lake, easing
## to the tile's own fill towards the outer bank. Nought where nothing is ever put. In
## whole slots, so the summed tables stay whole numbers. See FILTH_BANK_FROM.
func _room_at(tx: int, ty: int) -> int:
	var own := 0
	if Iso.floats_here(tx, ty):
		own = maxi(_grid.room_of(_grid.index_of(tx, ty)), 1)
		# Inside the ring the room is the tile's own thin fill, the bank's rule brought in:
		# against the deepest tile a two-deep ring read hazy from the first frame, and the
		# ring exists to be seen lightening as it is worked.
		if Iso.past_shelf(Vector2(tx, ty)) < LakeGrid.RING_OUT:
			return own
	elif Iso.on_strand(tx, ty):
		own = FILTH_STRAND_ROOM
	else:
		return 0
	var out := Iso.shore_fraction(float(tx) + 0.5, float(ty) + 0.5)
	var bank := smoothstep(FILTH_BANK_FROM, 1.0, out)
	return maxi(int(round(lerpf(float(_grid.deepest()), float(own), bank))), 1)


## How much of the water reads clean on the map, and which tiles: the stage nature is at.
## Water tiles are the lake's wet ones off both shores; the island's clean ring counts, so
## a fresh lake is not at zero — and it should not be, since that ring is clean.
func _count_clean() -> void:
	_clean_tiles.resize(0)
	# Which tiles are water is asked once: it is a walk of the shore function per tile, and
	# at every remap it was most of what the map cost (12.7 ms of 20, tools/shot_grime).
	if _water_tiles == 0:
		_wet_mask.resize(_grid.stacks.size())
		_wet_mask.fill(0)
		for index in _grid.stacks.size():
			if _wet_tile(index):
				_wet_mask[index] = 1
				_water_tiles += 1
	for index in _wet_mask.size():
		if _wet_mask[index] == 1 and _grid.water_state(index) == 0:
			_clean_tiles.append(index)
	_clean_share = float(_clean_tiles.size()) / float(maxi(_water_tiles, 1))


func _wet_tile(index: int) -> bool:
	var tile := _grid.tile_of(index)
	if not Iso.in_lake(tile.x, tile.y):
		return false
	if index < _grid.dry.size() and _grid.dry[index] == 1:
		return false
	return Iso.shore_fraction(float(tile.x) + 0.5, float(tile.y) + 0.5) < 1.0


## The share of the lake's water that reads clean on the map, 0..1.
func clean_share() -> float:
	return _clean_share


## The plants and the fish, wired once the grounds, the grid, the crate and the fleet are
## there to read. Their first refresh is this call: the map was built before they were.
func _grow_nature() -> void:
	_flora = Flora.new()
	_flora.name = &"Flora"
	_flora.grid = _grid
	_flora.grounds = _grounds
	_flora.crate_tile = _dog.crate_tile
	var yards := PackedVector2Array()
	for stop: Dropoff in _dropoffs:
		yards.append(stop.foot)
		yards.append(stop.berth)
	_flora.avoid = yards
	add_child(_flora)
	_fish = Fish.new()
	_fish.name = &"Fish"
	_fish.grid = _grid
	_fish.splash = _splash
	_fish.boats = _boats
	add_child(_fish)
	_wildlife = Wildlife.new()
	_wildlife.name = &"Wildlife"
	_wildlife.grid = _grid
	_wildlife.splash = _splash
	_wildlife.flora = _flora
	_wildlife.day = _day
	_wildlife.crate_tile = _dog.crate_tile
	_wildlife.avoid = yards
	_wildlife.threats = _wildlife_threats
	_wildlife.music = MusicStation.main()
	_flora.music = _wildlife.music
	add_child(_wildlife)
	_flora.refresh(_clean_share)
	_fish.refresh(_clean_share, _clean_tiles)
	_wildlife.refresh(_clean_share, _clean_tiles)


## What frightens the animals, in world px: the angler, the pack, the hulls.
func _wildlife_threats() -> PackedVector2Array:
	var out := PackedVector2Array()
	if _angler != null:
		out.append(_angler.position)
	for dog in _dogs:
		if is_instance_valid(dog) and dog.visible:
			out.append(dog.position)
	for boat in _boats:
		if is_instance_valid(boat) and boat.visible:
			out.append(boat.position)
	return out


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
	_skin.waiting = unwashed.size()
	# And on the shed's copy of the same button, which is the only one on screen while the
	# player is inside.
	_open_upgrades.note = "%d available" % affordable
	_skin.hint = _last_pieces_line()

	if not _menu_open:
		return
	_shop_skin.rows = _shop_rows()
	# The purse hangs under the shop's first board while it is up, and goes home after.
	_skin.purse_over = _shop_skin.purse_box(_skin.money_size()) if _menu_open else Rect2()
	_shop_skin.tour_pad = Pad.is_pad()
	_shop_skin.legend = _shop_legend()


## The one thing a filth meter cannot say: how much is left when the answer is "nearly
## nothing".
##
## The meter is weighted by how dirty a piece is, so the last hundred cups read as an empty
## bar, and a player looking at an empty bar and no ending has been told the lake is clean
## by the only thing in the game that tells them anything. This is what says otherwise —
## and it only appears once the bar is on the floor, so it is never noise.
##
## Only from LAST_PIECES_FROM down (2026-09-17, Richard): "n pieces left" and nothing more,
## on the hint line over the pollution meter. `_left_over` is counted every
## CLEAN_CHECK_EVERY now that the end check has no meter gate, so the figure is live.
const LAST_PIECES_FROM := 50


func _last_pieces_line() -> String:
	if _cleaned or _left_over <= 0 or _left_over > LAST_PIECES_FROM:
		return ""
	if _left_over == 1:
		return "1 piece left"
	return "%d pieces left" % _left_over


func _runs_done() -> int:
	var total := 0
	for boat in _boats:
		total += boat.runs_done
	return total


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
			"boat_volley": boat_volley_level,
			"fleet": fleet_level,
			"dog_fetch": dog_fetch_level, "dog_wait": dog_wait_level,
			"dog_strength": dog_strength_level, "dog_count": dog_count_level,
			"recycle_bonus": recycle_bonus_level, "bird_worth": bird_worth_level,
			"lucky_haul": lucky_haul_level, "double_cast": double_cast_level,
		},
		"caught": caught,
		"sold_count": sold_count,
		"birds_caught": birds_caught,
		"sold_by_kind": sold_by_kind,
		"runs_done": _runs_done(),
		"auto_ferry": _auto_ferry_on,
		# The settings are not in here, by decision (2026-09-15): they are `Prefs`', written
		# to user://settings.cfg on every press, and one set of them across the menu and the
		# lake. A save that carried its own copy handed it back on load and undid whatever the
		# player had set on the menu.
		"farewell": _farewell_shown,
		"intro_done": _intro_done,
		"first_steps": _steps_done,
		"shop_tour": _shop_tour_done,
		"decor_tour": _decor_tour_done,
		"angler": _angler.tile_pos,
		"yard_held": _yard.held,
		"unlocked": unlocked,
		"unwashed": unwashed,
		"decor": decor,
		"afloat": afloat,
		"stacks": _grid.stacks,
	}
	save["play"] = _play
	_save_extra(save)
	file.store_var(save, true)
	file.close()
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
	var readable := written == SAVE_VERSION
	if save == null or not readable 			or int(save.get("seed", 0)) != _level_seed():
		return false
	if not _grid.restore(save.get("stacks", []) as Array):
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
	boat_volley_level = _saved_level(levels, &"boat_volley")
	dog_fetch_level = _saved_level(levels, &"dog_fetch")
	dog_wait_level = _saved_level(levels, &"dog_wait")
	dog_strength_level = _saved_level(levels, &"dog_strength")
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
	_play = float(save.get("play", 0.0))

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
	# What was waiting at the pump. No such key in an older save, and nothing waiting.
	unwashed.clear()
	for name: String in save.get("unwashed", []) as Array:
		if _pretty(name).is_empty():
			continue
		if _sheets == null or _sheets.has(StringName(name)):
			unwashed.append(name)
	decor.clear()
	for row: Dictionary in save.get("decor", []) as Array:
		var name := String(row.get("piece", ""))
		if not unlocked.has(name):
			continue
		decor.append({
			"piece": name,
			"cell": [
				int((row["cell"] as Array)[0]),
				int((row["cell"] as Array)[1]),
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
	# Absent means seen: see the arrival section. A run in progress never plays the intro.
	_intro_done = bool(save.get("intro_done", true))
	# Absent means done, as above. Not done means the steps start over from the walk.
	_steps_done = bool(save.get("first_steps", true))
	_shop_tour_done = bool(save.get("shop_tour", true))
	_decor_tour_done = bool(save.get("decor_tour", true))
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
	_set_auto_ferry(bool(save.get("auto_ferry", true)))
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
	return true


## Throw the save away and start the lake again. The scene is reloaded rather than reset
## in place: a fresh run is exactly what the first frame of the game already builds.
func wipe_save() -> void:
	_wiping = true
	# Straight back into the lake: this is a key pressed in play, not a trip to the menu.
	skip_menu = true
	if has_save():
		# The engine's own path, not a globalized one: on the web there is no such thing as
		# an absolute path to a save, and user:// is understood everywhere.
		DirAccess.remove_absolute(save_path)
	get_tree().reload_current_scene()


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
	# For the free camera's edge scroll, see `_mouse_inside`.
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		_mouse_inside = false
	elif what == NOTIFICATION_WM_MOUSE_ENTER:
		_mouse_inside = true


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
		if not _intro_done:
			_draw_door_note(picture)
		# Over the hut, not over the tile: the two are not the same point.
		_draw_shed_lamp(feet)
		return

	_draw_shed_blocked(at)


## Where the note hangs on the hut's picture: across (a share of its width, just right of the
## door, which ends at 0.37) and up (a share of its height above the wall's foot there).
const NOTE_ACROSS := 0.41
const NOTE_UP := 0.2
## The note's size in art pixels, before the wall's slope shears it.
const NOTE_CELLS := Vector2i(5, 6)


## The letter pinned beside the door, on a new game until it has been read (2026-09-24):
## a sheet of the letter's paper laid on the left front wall, sheared to its 2:1 slope, with
## a few ruled lines and a pin. Whole art pixels, so it sits on the hut's own grain.
func _draw_door_note(picture: Rect2) -> void:
	var px := ART_PIXEL
	# The wall's foot runs up to the left at the diamond's slope from the near corner, which
	# is the picture's bottom middle.
	var x := picture.position.x + picture.size.x * NOTE_ACROSS
	var foot := picture.end.y - (picture.get_center().x - x) * 0.5
	var at := Vector2(snappedf(x, px), snappedf(foot - picture.size.y * NOTE_UP, px))
	for i in NOTE_CELLS.x:
		# Each column one pixel higher every other one: the wall's slope, down to the right.
		var col := at + Vector2(i * px, floorf(i * 0.5) * px)
		for j in NOTE_CELLS.y:
			var ink := Style.PAPER
			if i == 0 or j == NOTE_CELLS.y - 1:
				ink = Style.PAPER_EDGE
			elif j % 2 == 1 and i < NOTE_CELLS.x - 1 and j > 1:
				ink = Style.PAPER_RULE
			_island.draw_rect(Rect2(col + Vector2(0.0, (j - NOTE_CELLS.y) * px), Vector2(px, px)), ink)
	var pin := at + Vector2(floorf(NOTE_CELLS.x * 0.5) * px, (1 - NOTE_CELLS.y) * px)
	_island.draw_rect(Rect2(pin, Vector2(px, px)), Color(0.72, 0.18, 0.16))


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
	# Beside the pump the key is the pump's, and the lamp is over that instead.
	if _pump != null:
		_pump.lit = _at_pump() and not _menu_open
	if not _at_shed() or _at_pump() or _menu_open:
		return
	var over := at + Vector2(0.0, -Iso.SHED_TALL - 10.0)
	_island.draw_circle(over, 7.0, Color(1.0, 0.92, 0.62, 0.9))
	_island.draw_circle(over, 12.0, Color(1.0, 0.92, 0.62, 0.25))
