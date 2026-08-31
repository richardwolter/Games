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
## a net at the water; what the net drags home goes into the yard, and that is where the
## pollution meter drops, because that piece is out of the lake. The yard is a hard cap,
## so the only way to keep fishing is the other half: the ferry loads the yard and does a
## round of the four merchants on the bank, one per material, selling as it goes — and that
## is where the money comes from. Cleaning and earning are two different actions on purpose.
##
## This script owns none of that work. It builds the basin, wires the four things that do
## (angler, net, yard, ferry) to each other and to the grid, and is the one place the
## meter and the purse move.
extends Node2D

## The lake is laid out from this, once, at load. Same seed, same lake, every run — which
## is what makes a tuning pass a comparison rather than a new roll of the dice.
const LAKE_SEED := 20260817

## How far past the waterline the bank is drawn, in tiles.
const BANK_MARGIN := 9.0

## How far back the view sits to begin with. Isometric, so the basin is twice as wide as
## it is tall on screen.
const VIEW_ZOOM := 0.62

## How far in and out the wheel may take the view. The lake is far bigger than one screen
## at a readable zoom, so the two ends are doing different jobs: zoomed in is where the
## player aims a cast, zoomed out is where they read the basin as a whole and decide which
## side of the island to walk to.
const MIN_ZOOM := 0.22
const MAX_ZOOM := 1.8
## Per wheel notch. Multiplicative, so a notch is the same felt step at either end.
const ZOOM_STEP := 1.12

## How much closer the view gets over the course of a cast, and how quickly it eases to
## and from that. A cast is the one thing in this game that happens at a moment rather than
## over an afternoon, and leaning in for it is most of what makes it feel like one.
##
## Multiplied onto whatever the player has set with the wheel rather than replacing it, so
## it reads as leaning in from where they were standing instead of the view being taken off
## them and handed back.
## Gentle on purpose. At forty per cent the view moved enough over a cast to be felt in the
## stomach, and a camera that has to be endured is worse than one that does nothing.
const CAST_PUSH := 1.13

## Leaning in and letting go are not the same speed. Following a cast has to be quick or the
## view arrives after the thing it was meant to be watching — the first version eased both
## ways at one rate and hit its closest a second *after* the net was already home. Letting go
## is slow on purpose: the cast is over, and there is nothing to keep up with.
const PUSH_IN := 4.5
const PUSH_OUT := 1.6

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

## The island's colours, and how far in from the waterline the grass starts, in tiles.
const SAND := Color(0.78, 0.70, 0.50)
const SAND_WET := Color(0.66, 0.58, 0.41)
const PEBBLE := Color(0.58, 0.54, 0.46)
const GRASS := Color(0.36, 0.45, 0.27)
const GRASS_DARK := Color(0.28, 0.36, 0.21)
const TUFT := Color(0.44, 0.54, 0.31)
const SHORE_INK := Color(0.16, 0.14, 0.11, 0.55)
const GRASS_IN := -1.1

## How many specks go into the sand-to-grass edge and over the ground, and how far either
## side of the edge they may stray, in tiles.
const EDGE_SPECKS := 150
const EDGE_RAGGED := 0.45
const GROUND_SPECKS := 620

## Below this zoom the rubbish drops its footprint and its outline. A piece is about
## twenty pixels across, so under half zoom those two details are a pixel wide and cost
## half the geometry on screen for nothing.
const DETAIL_ZOOM := 0.5

## What netting a pigeon pays.
const BIRD_BONUS := 26.0

## How close to the shed the angler has to stand to open it, in tiles.
const SHOP_RANGE := 3.2

## How art is sized when it is floating in the lake.
##
## Everything is drawn at the same scale first, so a wardrobe really is four times a mug
## and the lake reads as a lake full of things rather than a lake full of one size. The two
## limits are only there for the extremes: a four-pixel crumb has to be visible at all, and
## a bed has to leave room for the water around it.
const SPRITE_SCALE := 1.5
const SPRITE_SMALLEST := 15.0
const SPRITE_LARGEST := 46.0

## Hulls the lake will hold. Three ferries working one yard is already more loading than
## the yard produces, and a fourth would be a purchase that changes nothing.
const MAX_BOATS := 3

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
const SAVE_VERSION := 2
const AUTOSAVE_EVERY := 20.0

## Where this run is saved, and whether it picks up where the last one left off. Both are
## settable before the scene enters the tree, which is how the test harness runs against a
## save file of its own instead of the player's.
var save_path: String = SAVE_PATH
var autoload_save: bool = true

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
var _cast_push: float = 1.0
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

var _splash: WaterSplash
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
var _water_material: ShaderMaterial
## The rubbish's own material, so the filth on it can be pushed with the water's.
var _grime_material: ShaderMaterial

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

## Seconds until the next autosave, and what the HUD says about the last one.
var _autosave_in: float = AUTOSAVE_EVERY
## True once the save has been thrown away, so the reload on the way out does not put it
## straight back.
var _wiping: bool = false
var _save_note: String = ""
var _save_note_for: float = 0.0

var _filth_total: float = 1.0
var _filth_left: float = 1.0

## The end of the run. `_cleaned` is the lake having nothing left in it, which is what the
## water is lit by; `_farewell_shown` is whether the player has been thanked, which happens
## once per save rather than once per session.
var _cleaned: bool = false
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
@onready var _close_shed: Button = %CloseShed
@onready var _settings: PanelContainer = %Settings
@onready var _open_settings: Button = %OpenSettings
@onready var _fullscreen: CheckButton = %Fullscreen
@onready var _music: AudioStreamPlayer = %Music
@onready var _music_on: CheckButton = %MusicOn
@onready var _music_level: HSlider = %MusicLevel
@onready var _sfx_on: CheckButton = %SfxOn
@onready var _sfx_level: HSlider = %SfxLevel
@onready var _quit_game: Button = %QuitGame
@onready var _save_now: Button = %SaveNow
@onready var _load_now: Button = %LoadNow
@onready var _wipe_save: Button = %WipeSave
@onready var _send_now: Button = %SendNow
@onready var _auto_ferry: CheckButton = %AutoFerry


## How far out from its own tile a cast sweeps, in tiles. Level 0 is a single tile: the net
## you start with catches exactly what you drag it over, and everything wider than that is
## bought.
##
## Fractions rather than whole rings. A radius counted in whole tiles goes 1, 5, 13, 29
## tiles a cast — every purchase doubles the mouth and by the third one the net is a
## dragnet. Under half a tile a level, the same five purchases run 1, 5, 9, 13, 21.
func net_radius() -> float:
	return 0.7 + 0.45 * float(net_width_level)


## The heaviest TrashDef.tier the net can lift.
func net_power() -> int:
	return net_strength_level


## How far the angler can throw, in tiles.
##
## Starts short on purpose — the rod once reached a third of the way across the basin at
## the first upgrade, which made the boat pointless and the lake small — but it accelerates,
## because a track whose price multiplies while its reach only adds is a track that is worth
## less every time you buy it. The squared term is what keeps the late levels worth the
## money: 3.4 tiles at the start, 12.5 by level five, past twenty by level eight.
func net_range() -> float:
	var level := float(net_range_level)
	return 3.4 + 1.15 * level + 0.16 * level * level


## How fast the net comes home, in tiles per second.
func reel_speed() -> float:
	return 2.6 + 0.9 * float(reel_level)


## How many pieces one cast can bring in.
func net_hold() -> int:
	return 3 + 2 * net_hold_level


## Ferry speed, in tiles per second.
func boat_speed() -> float:
	return 3.0 + 1.1 * float(boat_speed_level)


func boat_cargo() -> int:
	return 4 + 3 * cargo_level


## How wide the skimmer bites as it sails, in tiles out from the hull. Below zero is no
## skimmer fitted, which is what every ferry starts as.
func skim_radius() -> int:
	return skimmer_level - 1


## The heaviest tier the skimmer can lift. Deliberately behind the net: the boat catching
## what the player cannot yet catch by hand would read as the game playing itself.
func skim_power() -> int:
	return maxi(skimmer_level - 1, 0) / 2


## Odds that a piece the skimmer passes over actually comes up. A net dragged behind a
## moving hull is a chance at a piece rather than a certainty, and most of what the
## skimmer upgrade buys is that chance going up — the first one fitted misses four times
## out of five, and even a maxed one lets some slip underneath.
func skim_chance() -> float:
	if skimmer_level < 1:
		return 0.0
	return minf(0.18 + 0.11 * float(skimmer_level - 1), 0.85)


## Deck space the skimmer gets on top of the hold, so a ferry loaded to the brim out of
## the yard can still fish on the way.
func skim_hold() -> int:
	return 2 * skimmer_level


## How many slots down the skimmer digs for the material it is running out. More than one,
## always: it is looking for one material in particular, and on the way to the sawmill most
## of what is floating on top is not timber.
func skim_depth() -> int:
	return 1 + skimmer_level


func _ready() -> void:
	_grid = $Grid as LakeGrid
	_camera = $Camera as Camera2D
	_boats = [$Boat as Boat]
	_angler = $Angler as Angler
	_net = $Net as CastNet
	_yard = $Yard as Yard

	var shore := Iso.shore_outline()
	_shape_bank()
	_shape_water(shore)
	_shape_island()
	_shape_dropoffs()

	_shed_art = Art.texture("res://assets/shed.png")

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
	# Above the floating rubbish: a splash is on top of the water by definition.
	_splash.z_index = 7
	_splash.z_as_relative = false
	add_child(_splash)

	_grid.z_index = 5
	_grid.z_as_relative = false
	# The rubbish bobs on the GPU. That is what lets its geometry be built once and left
	# alone until the view moves or a piece is taken, instead of every frame.
	var bob := ShaderMaterial.new()
	bob.shader = load("res://shaders/rubbish.gdshader")
	bob.set_shader_parameter(&"wave_amplitude", LakeGrid.WAVE_AMPLITUDE)
	bob.set_shader_parameter(&"wave_speed", LakeGrid.WAVE_SPEED)
	_grid.material = bob
	_grime_material = bob
	_sheets = Sheets.new()
	if not _sheets.load_all():
		_sheets = null
	_grid.sheets = _sheets
	_grid.build(_all_defs(), LAKE_SEED)
	_hide_treasures()
	_filth_total = maxf(_grid.filth_left(), 0.001)
	_filth_left = _filth_total
	pollution = 1.0

	_bounds = _outline_bounds(shore)
	_view_zoom = VIEW_ZOOM
	_push_zoom()
	_camera.position = Iso.tile_to_world(Iso.CENTRE.x, Iso.CENTRE.y)

	# The yard sits beside the shed, far enough off it that the pile does not grow through
	# the roof.
	_yard.grid = _grid
	# Clear of the shed and clear of where the angler stands: a crate you spawn inside is a
	# crate you have to walk out of before you can see it.
	_yard.position = Iso.tile_to_world(
		Iso.ISLAND_CENTRE.x + 2.7, Iso.ISLAND_CENTRE.y + 2.7
	)

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
	_net.sfx = _sfx
	_net.angler = _angler
	_net.flock = _flock
	_net.landed.connect(_on_net_landed)
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
		if def.keepsake:
			_room.titles[String(def.piece)] = def.display_name
	_shop_skin.bought.connect(_buy)
	# Pictures for the rows the upgrades board was not drawn with: the ferry's own baked
	# sprite for the boat tracks, and the net for the skimmer, which is a net.
	var ferry := Boat.art_frame(0.62)
	var mesh: Dictionary = _net.art_frame(&"land", -1)
	if not ferry.is_empty():
		# The same hull three times, told apart by what is drawn beside it: an arrow up for
		# going faster, a plus for carrying more, and a second hull for a second hull.
		_shop_skin.icons[&"boat_speed"] = _lent(ferry, &"arrow", 0.95)
		_shop_skin.icons[&"cargo"] = _lent(ferry, &"plus", 0.95)
		_shop_skin.icons[&"fleet"] = _lent(ferry, &"pair", 0.72)
	if not mesh.is_empty() and _net.art_sheet() != null:
		_shop_skin.icons[&"skimmer"] = _lent(
			{"sheet": _net.art_sheet(), "region": mesh["region"]}, &"", 0.62
		)
	_skin.shed_pressed.connect(_set_shed.bind(true))
	_skin.upgrades_pressed.connect(_set_menu.bind(true))
	_open_upgrades.pressed.connect(_set_menu.bind(true))
	_open_shed.pressed.connect(_set_shed.bind(true))
	_close_shed.pressed.connect(_set_shed.bind(false))
	_open_settings.pressed.connect(_set_settings.bind(true))
	_fullscreen.toggled.connect(_set_fullscreen)
	_music_on.toggled.connect(_set_music)
	_music_level.value_changed.connect(_set_music_level)
	_sfx_on.toggled.connect(_set_sfx)
	_sfx_level.value_changed.connect(_set_sfx_level)
	_push_sfx()
	_quit_game.pressed.connect(_quit)
	_save_now.pressed.connect(save_game)
	_load_now.pressed.connect(load_game)
	_wipe_save.pressed.connect(wipe_save)
	_send_now.pressed.connect(_send_ferry)
	_auto_ferry.toggled.connect(_set_auto_ferry)
	_close_menu.pressed.connect(_set_menu.bind(false))
	_shop_skin.close_asked.connect(_set_menu.bind(false))
	_pin_close(_settings, _set_settings.bind(false))
	_pin_close(_shed, _set_shed.bind(false))
	_set_menu(false)
	_fullscreen.button_pressed = _is_fullscreen()
	_start_music()
	_set_settings(false)
	_set_shed(false)
	_push_water_colours()
	if autoload_save:
		load_game()


## The bank: the land the lake sits in, drawn as the shore ring grown outward. Two flat
## shapes, not a heightmap — nothing walks on it and nothing is hidden behind it.
func _shape_bank() -> void:
	var grass := Polygon2D.new()
	grass.name = &"Bank"
	grass.polygon = Iso.shore_outline(BANK_MARGIN)
	grass.color = Color(0.34, 0.39, 0.28)
	grass.z_index = 0
	grass.z_as_relative = false
	add_child(grass)

	# A mud collar just outside the waterline, so the water does not meet the grass on a
	# hard line. The lake's edge is the one place the eye goes first.
	var mud := Polygon2D.new()
	mud.name = &"Shore"
	mud.polygon = Iso.shore_outline(1.4)
	mud.color = Color(0.42, 0.38, 0.29)
	mud.z_index = 1
	mud.z_as_relative = false
	add_child(mud)


## Build the water's visible polygon: the lake's surface, flat on the plane. The shader
## works out depth per pixel from the tile under it, so the polygon carries no depth
## information of its own and needs no interior vertices.
func _shape_water(shore: PackedVector2Array) -> void:
	var visual := Polygon2D.new()
	visual.name = &"WaterVisual"
	visual.polygon = shore
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
	visual.material = _water_material
	add_child(visual)


## The island: sand, grass, and the shed the upgrades are bought in.
##
## Drawn over the water polygon rather than cut out of it, because the water's outline is
## one generated ring and putting a hole in it would mean triangulating an annulus for a
## shape nothing ever moves. The shader shoals the water up to the beach so the join does
## not read as a sticker on deep water.
func _shape_island() -> void:
	var sand := Polygon2D.new()
	sand.name = &"IslandSand"
	sand.polygon = Iso.island_outline()
	sand.color = SAND
	sand.z_index = 3
	sand.z_as_relative = false
	add_child(sand)

	var grass := Polygon2D.new()
	grass.name = &"IslandGrass"
	grass.polygon = Iso.island_outline(GRASS_IN)
	grass.color = GRASS
	grass.z_index = 3
	grass.z_as_relative = false
	add_child(grass)

	# The detail over the two flat fills. Drawn rather than another polygon because what it
	# is drawing is scatter — speckles, tufts, a broken edge — and a polygon cannot be
	# speckled.
	var detail := Node2D.new()
	detail.name = &"IslandDetail"
	detail.z_index = 3
	detail.z_as_relative = false
	detail.draw.connect(_draw_island.bind(detail))
	add_child(detail)
	detail.queue_redraw()

	_island = Node2D.new()
	_island.name = &"IslandShed"
	_island.z_index = 4
	_island.z_as_relative = false
	_island.draw.connect(_draw_shed)
	add_child(_island)
	_island.queue_redraw()


## The island's surface: a wet ring at the waterline, a broken edge between sand and grass,
## and a scatter of pebbles and tufts over both.
##
## All of it is diamonds lying on the plane rather than dots, and all of it is drawn once
## from a fixed seed. The point is to meet the drawn shed halfway: the hut is pixel art with
## a hard outline and visible grain, and it was standing on two smooth vector blobs. Chunky
## speckles at a consistent size read as the same kind of picture without anybody having to
## paint an island.
func _draw_island(on: Node2D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8812

	# Wet sand where the water has been, just inside the waterline: filled to the edge, cut
	# back to a ring with dry sand, and then the grass laid over again — the ring's inner
	# cut reaches past the treeline and would otherwise bury the whole lawn under beach.
	on.draw_colored_polygon(Iso.island_outline(), SAND_WET)
	on.draw_colored_polygon(Iso.island_outline(-0.4), SAND)
	on.draw_colored_polygon(Iso.island_outline(GRASS_IN), GRASS)

	# The edge between sand and grass, broken up. Diamonds either side of the line, grass
	# ones out on the sand and sand ones in on the grass, so the boundary reads as ragged
	# turf rather than as a cut.
	for i in EDGE_SPECKS:
		var angle := TAU * float(i) / float(EDGE_SPECKS)
		for k in 3:
			var off := rng.randf_range(-EDGE_RAGGED, EDGE_RAGGED)
			var at := Iso.island_point(angle + rng.randf_range(-0.02, 0.02), GRASS_IN + off)
			_speck(on, at, rng.randf_range(0.7, 1.3), GRASS if off > 0.0 else SAND)

	# Pebbles on the beach and tufts on the grass, both thrown at the island and kept only
	# where they landed on the right ground. Rejecting is shorter than working out where the
	# ring is at every angle, and the ring is a wobble rather than a circle.
	for i in GROUND_SPECKS:
		var angle := rng.randf_range(0.0, TAU)
		var out := sqrt(rng.randf())
		var tile := Iso.ISLAND_CENTRE + Vector2(
			cos(angle) * Iso.ISLAND_RADIUS.x * out, sin(angle) * Iso.ISLAND_RADIUS.y * out
		)
		if Iso.in_shed(tile.x, tile.y):
			continue
		var edge := Iso.island_fraction(tile.x, tile.y)
		if edge > 0.99:
			continue
		var at := Iso.tile_to_world(tile.x, tile.y)
		# The grass starts a little in from the waterline; the same fraction says which.
		if edge > 0.76:
			_speck(on, at, rng.randf_range(0.5, 1.0), PEBBLE if rng.randf() < 0.5 else SAND_WET)
		else:
			_speck(on, at, rng.randf_range(0.6, 1.2), TUFT if rng.randf() < 0.6 else GRASS_DARK)

	# And an outline round the whole thing, which is the one thing the shed has that a
	# polygon never does.
	var rim := Iso.island_outline()
	var closed := rim.duplicate()
	closed.append(rim[0])
	on.draw_polyline(closed, SHORE_INK, 1.6)


## One speck of ground: a small diamond, so it lies on the plane like everything else here.
func _speck(on: Node2D, at: Vector2, scale: float, tint: Color) -> void:
	var wide := Iso.TILE_W * 0.075 * scale
	var tall := Iso.TILE_H * 0.075 * scale
	on.draw_colored_polygon(
		PackedVector2Array([
			at + Vector2(0.0, -tall), at + Vector2(wide, 0.0),
			at + Vector2(0.0, tall), at + Vector2(-wide, 0.0)
		]),
		tint
	)


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
		stop.z_index = 4
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


## The starting junk set: fifteen kinds, across five tiers and all four materials.
##
## Every material spans a range of tiers on purpose. If plastic were all tier 0 and metal
## all tier 4, the four yards would come into play one after another as the net got
## stronger and three of them would be dead weight for the first hour. Spread this way,
## every run has something for most of the yards from the start, and what changes with a
## stronger net is which of each material you can lift.
##
## `lightness` only sorts the stacks — light near the surface, heavy at the bottom. It is
## not a force any more, and nothing solves for it.
func _default_defs() -> Array[TrashDef]:
	var p := TrashDef.Kind.PLASTIC
	var w := TrashDef.Kind.TIMBER
	var m := TrashDef.Kind.METAL
	var r := TrashDef.Kind.RUBBER
	return [
		_def("Mug", p, Vector2(13.0, 15.0), 2.4, 0.4, 0.15, 0,
			Color(0.90, 0.87, 0.80), &"small_49"),
		_def("Jar", p, Vector2(14.0, 18.0), 2.3, 0.6, 0.2, 0,
			Color(0.86, 0.84, 0.80), &"small_55"),
		_def("Bottle", p, Vector2(10.0, 21.0), 2.0, 0.9, 0.3, 0,
			Color(0.80, 0.85, 0.76), &"small_28"),
		_def("Fish bowl", p, Vector2(17.0, 19.0), 1.4, 1.6, 1.0, 2,
			Color(0.74, 0.66, 0.34), &"small_25"),

		_def("Shelf board", w, Vector2(26.0, 9.0), 1.75, 1.2, 0.7, 0,
			Color(0.55, 0.44, 0.30), &"small_44"),
		_def("Book", w, Vector2(20.0, 12.0), 1.6, 1.8, 0.9, 1,
			Color(0.62, 0.50, 0.32), &"small_30"),
		_def("Chopping board", w, Vector2(20.0, 18.0), 1.4, 2.0, 1.1, 2,
			Color(0.60, 0.48, 0.30), &"small_26"),
		_def("Crate", w, Vector2(22.0, 17.0), 1.2, 2.2, 1.4, 3,
			Color(0.78, 0.70, 0.24), &"small_16"),

		_def("Tin plate", m, Vector2(18.0, 13.0), 1.9, 0.6, 0.5, 0,
			Color(0.66, 0.68, 0.72), &"small_36"),
		_def("Cooking pot", m, Vector2(18.0, 18.0), 0.8, 3.2, 2.6, 2,
			Color(0.42, 0.36, 0.30), &"small_32"),
		_def("Teapot", m, Vector2(21.0, 15.0), 0.6, 3.4, 3.0, 3,
			Color(0.50, 0.50, 0.55), &"small_54"),
		_def("Wall clock", m, Vector2(20.0, 20.0), 0.45, 4.5, 4.2, 4,
			Color(0.62, 0.63, 0.66), &"small_08"),

		_def("Rubber duck", r, Vector2(19.0, 15.0), 2.1, 1.0, 0.5, 0,
			Color(0.26, 0.25, 0.26), &"small_06"),
		_def("Chew toy", r, Vector2(18.0, 10.0), 1.6, 1.4, 0.9, 1,
			Color(0.24, 0.22, 0.24), &"small_22"),
		_def("Ball", r, Vector2(14.0, 15.0), 1.05, 2.6, 1.8, 2,
			Color(0.20, 0.19, 0.20), &"small_31"),
		_def("Urn", r, Vector2(16.0, 18.0), 0.5, 3.8, 3.2, 4,
			Color(0.18, 0.17, 0.19), &"small_24"),
	]


## Every def the lake is built from: the rubbish above, and one entry per piece of
## furniture in the catalogue.
##
## The furniture is the collection. Exactly one of each is hidden in the water, none of it
## is sold, and pulling one out is what puts it in the shed — so its defs are generated
## from the art rather than written out, and a new sheet is new things to find.
func _all_defs() -> Array[TrashDef]:
	var all := _default_defs()
	if _sheets == null or not _sheets.by_sheet.has("furniture"):
		_dress(all)
		return all
	for name: String in _sheets.by_sheet["furniture"] as PackedStringArray:
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
		all.append(find)
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
	rng.seed = LAKE_SEED ^ 0x5EED
	for i in _grid.defs.size():
		if not _grid.defs[i].keepsake:
			continue
		for attempt in 40:
			var tx := rng.randi_range(2, Iso.COLS - 3)
			var ty := rng.randi_range(2, Iso.ROWS - 3)
			var index := _grid.index_of(tx, ty)
			var height := _grid.height_of(index)
			if height < 3:
				continue
			_grid.insert(index, maxi(height - 1 - rng.randi_range(0, 2), 0), i)
			break


## Everything found so far, as catalogue names. One of each, in the order it came out.
func found() -> Array[String]:
	return unlocked


## A catalogue name as something to read. Naming the art by hand is a job for later; the
## catalogue is laid out to take those names when they are written.
func _pretty(name: String) -> String:
	return "Find %s" % name.get_slice("_", 1)


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
		var scale := clampf(
			SPRITE_SCALE,
			SPRITE_SMALLEST / longest,
			maxf(SPRITE_LARGEST / longest, SPRITE_SMALLEST / longest)
		)
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
				return
			KEY_F11:
				_fullscreen.button_pressed = not _is_fullscreen()
				return
			KEY_M:
				_music_on.button_pressed = not _music_on.button_pressed
				return
			KEY_F5:
				save_game()
				return
			KEY_F9:
				_note_save("nothing to load" if not load_game() else "loaded")
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
	if click.pressed and click.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom_by(ZOOM_STEP)
		return
	if click.pressed and click.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom_by(1.0 / ZOOM_STEP)
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

	if not click.pressed:
		_net.set_pulling(false)
		return

	# One gesture: press to throw, hold to reel it back, release to stop. The press is
	# recorded as a pull either way, so a fresh cast starts reeling the instant it lands
	# instead of asking for a second click.
	if _net.state == CastNet.State.IDLE:
		_cast_at(get_global_mouse_position())
	_net.set_pulling(true)


## Throw the net, on the numbers the player has now. The only cap is the net's own hold —
## the yard takes whatever comes back, however much of it there is.
func _cast_at(where: Vector2) -> void:
	_push_net_numbers()
	if _net.hold <= 0:
		return
	if _net.cast_to(where):
		# Watching the cast is worth more than whatever the player had panned over to look
		# at, and they can always pan back.
		_pan_yielded = true


## Is the angler standing at the shed?
func _at_shed() -> bool:
	return _angler.tile_pos.distance_to(Iso.ISLAND_CENTRE) < SHOP_RANGE


## Zoom by a factor, keeping the world point under the cursor under the cursor.
func _zoom_by(factor: float) -> void:
	var wanted := clampf(_view_zoom * factor, MIN_ZOOM, MAX_ZOOM)
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


## Write the camera's zoom: what the player set, leaned on by whatever a cast in progress
## is asking for, and kept inside the same limits the wheel obeys.
func _push_zoom() -> void:
	var wanted := clampf(_view_zoom * _cast_push, MIN_ZOOM, MAX_ZOOM)
	_camera.zoom = Vector2(wanted, wanted)


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
	_open_settings.visible = not open and not _shed_open
	if open:
		_shed.visible = false
		_shed_open = false
	_hold_the_angler()


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
	if _sfx != null:
		_sfx.play_chime()
	if not _farewell_shown:
		_farewell_shown = true
		_show_farewell()
	# The moment is worth keeping without waiting for the autosave to come round.
	save_game()


## Lay the closing words over the lake.
func _show_farewell() -> void:
	if _farewell != null:
		return
	_farewell = Farewell.new()
	_farewell.dismissed.connect(_drop_farewell)
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
	if busy:
		_net.set_pulling(false)


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
		lerpf(MUSIC_SILENT, MUSIC_LOUDEST, clampf(_music_level.value, 0.0, 1.0))
		if _music_on.button_pressed else MUSIC_SILENT
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
		_sfx.set_level(clampf(_sfx_level.value, 0.0, 1.0), _sfx_on.button_pressed)


func _set_sfx(_on: bool) -> void:
	_push_sfx()


func _set_sfx_level(_level: float) -> void:
	# Dragging the slider up is a request to hear it, the same as the music's.
	if not _sfx_on.button_pressed:
		_sfx_on.button_pressed = true
	_push_sfx()


func _set_music(_on: bool) -> void:
	_push_music()


func _set_music_level(_level: float) -> void:
	if not _music_on.button_pressed:
		_music_on.button_pressed = true
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


## A cast landing on the island. The meter moves here and nowhere else on this path: the
## piece is out of the water the moment it reaches the yard.
## The catch coming out of the net. The lake decides what happens to each piece here and
## now — the water is cleaner the moment it is landed — but the pieces bound for the yard
## are thrown there rather than teleported, and the pile only takes them when they land.
func _on_net_landed(cargo: PackedInt32Array) -> void:
	var from := _angler.rod_tip()
	var slot := 0
	for i in cargo.size():
		var def := _grid.defs[cargo[i]]
		# A find never joins the pile and is never sold. It goes on the shelf in the shed,
		# which is the only thing in this game that is kept rather than spent.
		if def.keepsake:
			_keep(def)
			_filth_left = maxf(_filth_left - def.pollution, 0.0)
			caught += 1
			continue
		_haul.send(
			cargo[i], from, _yard.drop_point(), slot, cargo.size(), null, null, _angler
		)
		slot += 1
		_filth_left = maxf(_filth_left - def.pollution, 0.0)
		caught += 1
	pollution = clampf(_filth_left / _filth_total, 0.0, 1.0)


## A thrown piece reaching wherever it was thrown. A boat tagged itself and takes it into
## the hold; anything else was bound for the yard, which always has room for it.
func _on_haul_arrived(def_index: int, tag: Variant) -> void:
	var boat := tag as Boat
	if boat != null:
		boat.stow(def_index)
		return
	_yard.put(def_index)


## A pigeon in the net. Paid on the spot: it never reaches the yard, it is not a material
## any merchant buys, and it was never part of the lake's filth — so the meter does not
## move for it either.
func _on_bird_caught(at: Vector2) -> void:
	sludge += BIRD_BONUS
	birds_caught += 1
	if _splash != null:
		_splash.splash(at, 0.55)
	_note_save("A pigeon! %d sludge" % roundi(BIRD_BONUS))


## Put a find on the shed's shelf. Once each: the lake holds one of every piece, and a
## second copy of the same name would be a bug worth swallowing quietly rather than
## showing the player twice in their inventory.
func _keep(def: TrashDef) -> void:
	var name := String(def.piece)
	if name.is_empty() or unlocked.has(name):
		return
	unlocked.append(name)
	_note_save("%s — it can go in the shed" % def.display_name)


## The ferry landing a load at one of the four merchants. The purse moves here and nowhere
## else.
##
## The meter is not touched: anything the boat is carrying either came out of the yard,
## where it was already counted, or was skimmed out of the water on the way — and that
## second case is counted below, because it left the lake when the skimmer took it.
func _on_sold(cargo: PackedInt32Array, kind: int) -> void:
	for i in cargo.size():
		sludge += _grid.defs[cargo[i]].pollution * 10.0
		sold_count += 1
	sold_by_kind[kind] += cargo.size()


## A piece the ferry's skimmer took out of the water on its way past. It left the lake
## when the skimmer closed on it, so the meter moves now rather than when it is sold —
## the same rule the net follows, and the reason both report through here.
func _on_skimmed(def_index: int) -> void:
	_filth_left = maxf(_filth_left - _grid.defs[def_index].pollution, 0.0)
	pollution = clampf(_filth_left / _filth_total, 0.0, 1.0)
	caught += 1


## What each track costs: the price of its first level, and what each level multiplies the
## next one by.
##
## The extra hull is the other end of the same scale: it is a second round of the lake
## running at once, which no single-boat upgrade can match, so it starts high and triples.
const PRICES := {
	&"net_width": [15.0, 1.7],
	&"net_strength": [15.0, 1.7],
	# Cheaper and flatter than the tracks either side of it. Range buys no catch rate and no
	# money — it buys not having to walk — so at the shared 1.7 it was the one upgrade that
	# priced itself out of the game before it got good.
	&"net_range": [12.0, 1.42],
	&"reel": [15.0, 1.7],
	&"net_hold": [15.0, 1.7],
	&"boat_speed": [15.0, 1.7],
	&"cargo": [15.0, 1.7],
	&"skimmer": [15.0, 1.7],
	&"fleet": [240.0, 3.0],
}


## Every upgrade as one row of the drawn board: what it is, what it does now, what the next
## level costs, and whether it can be paid for.
##
## The five icons on the sheet are the net's, in the order they are drawn on it. The ferry's
## upgrades have no picture yet and say so with an index of -1 rather than borrowing one.
func _shop_rows() -> Array:
	var out: Array = []
	var listed := [
		[&"net_width", 0, "Width", "%d tiles" % _tiles_in_radius(net_radius())],
		[&"net_strength", 1, "Strength", "lifts tier %d" % net_power()],
		[&"net_range", 2, "Range", "%.1f tiles" % net_range()],
		[&"reel", 3, "Speed", "%.1f tiles/s" % reel_speed()],
		[&"net_hold", 4, "Haul", "%d per cast" % net_hold()],
		[&"boat_speed", -1, "Ferry speed", "%.1f tiles/s" % boat_speed()],
		[&"cargo", -1, "Ferry hold", "%d aboard" % boat_cargo()],
		[&"skimmer", -1, "Skimmer", (
			"off" if skimmer_level <= 0
			else "%d tiles, %d%%" % [_tiles_in_radius(float(skim_radius())), roundi(skim_chance() * 100.0)]
		)],
		[&"fleet", -1, "Extra ferry", "%d in the water" % fleet_size()],
	]
	for line: Array in listed:
		var key: StringName = line[0]
		var full := key == &"fleet" and fleet_size() >= MAX_BOATS
		var price := cost_of(key)
		out.append({
			"key": key,
			"icon": line[1],
			"name": "%s (Lvl %d)" % [line[2], _level_of(key)],
			"value": line[3],
			# No brackets: the tag is painted with a pair of its own, and its end caps are
			# what get drawn either side of this.
			"cost": "—" if full else "$%d" % roundi(price),
			"afford": not full and sludge >= price,
		})
	return out


## One lent picture for the upgrades board: what to draw, what mark goes with it, and how
## much of its tile it fills.
func _lent(art: Dictionary, glyph: StringName, fill: float) -> Dictionary:
	return {
		"sheet": art["sheet"], "region": art["region"], "glyph": glyph, "fill": fill
	}


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


## Cost of the next level on a track.
func cost_of(what: StringName) -> float:
	var price: Array = PRICES[what]
	return float(price[0]) * pow(float(price[1]), float(_level_of(what)))


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
		_:
			return 0


func _buy(what: StringName) -> void:
	if what == &"fleet" and fleet_size() >= MAX_BOATS:
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
	_push_net_numbers()
	_push_boat_numbers()


## Everything a hull needs to work, and where it ties up.
##
## Berths are spread along the island's south shore so a fleet at rest is a row of moored
## boats rather than one boat drawn several times. They stay outside the beach, which is
## what the route planner already assumes of the dock.
func _fit_out(boat: Boat, index: int) -> void:
	_reberth(boat, index)
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
	_fade_radio(delta)
	# The camera follows the angler rather than being panned: the arrow keys are theirs
	# now, and a view that has to be driven separately from the character is two jobs for
	# one pair of hands. While a cast is out it drifts off them and onto the net.
	_cast_look = lerpf(
		_cast_look,
		CAST_LOOK if _net.state != CastNet.State.IDLE else 0.0,
		clampf(LOOK_SPEED * delta, 0.0, 1.0)
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
		_pan = _pan.lerp(Vector2.ZERO, clampf(PAN_RELEASE * delta, 0.0, 1.0))
		if _pan.length() < 1.0:
			_pan = Vector2.ZERO

	# Eased while it is following something, and snapped while the player is dragging it:
	# a view that lags a hand on the mouse feels like a view being argued with.
	_camera.position = _clamped_view(
		_watching() if _panning
		else _camera.position.lerp(_watching(), clampf(FOLLOW_SPEED * delta, 0.0, 1.0))
	)

	if _filth_left <= 0.0:
		pollution = 0.0
		_check_cleaned()

	_save_note_for = maxf(_save_note_for - delta, 0.0)
	_autosave_in -= delta
	if _autosave_in <= 0.0:
		save_game()

	# Eased rather than set: the push follows the cast, and a camera that snapped to it
	# would be a cut.
	var wants := lerpf(1.0, CAST_PUSH, _net.cast_progress())
	_cast_push = lerpf(
		_cast_push, wants,
		clampf((PUSH_IN if wants > _cast_push else PUSH_OUT) * delta, 0.0, 1.0)
	)
	_push_zoom()

	_grid.set_view(_visible_world_rect())
	_grid.set_detailed(_camera.zoom.x >= DETAIL_ZOOM)
	_push_water_colours()
	_push_engine()
	_update_hud()
	_island.queue_redraw()


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


## Keep the camera over the lake. The margin lets the bank show around the edges rather
## than stopping the view exactly at the waterline.
func _clamped_view(at: Vector2) -> Vector2:
	var margin := Vector2(Iso.TILE_W, Iso.TILE_H) * BANK_MARGIN
	var box := _bounds.grow_individual(margin.x, margin.y, margin.x, margin.y)
	return Vector2(
		clampf(at.x, box.position.x, box.position.x + box.size.x),
		clampf(at.y, box.position.y, box.position.y + box.size.y)
	)


func _visible_world_rect() -> Rect2:
	# In world units, so the cull matches what the camera can actually see rather than
	# what a zoom of 1 would have shown.
	var size := get_viewport_rect().size / _camera.zoom
	return Rect2(_camera.global_position - size * 0.5, size)


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
	# The junk wears the same filth the water does. It is floating in it.
	if _grime_material != null:
		_grime_material.set_shader_parameter(&"grime", shown)


func _update_hud() -> void:
	_skin.pollution = pollution
	_skin.money = sludge
	_skin.stock = _yard.held.size()
	_load_now.disabled = not has_save()

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
		(pair[0] as Button).disabled = sludge < cost_of(pair[1] as StringName)
	if fleet_size() >= MAX_BOATS:
		_buy_fleet.disabled = true

	_buy_boat_speed.text = "Ferry speed %d  —  %.1f tiles/s  (%d)" % [
		boat_speed_level, boat_speed(), roundi(cost_of(&"boat_speed"))
	]
	_buy_cargo.text = "Ferry hold %d  —  carries %d  (%d)" % [
		cargo_level, boat_cargo(), roundi(cost_of(&"cargo"))
	]
	_buy_skimmer.text = "Skimmer %d  —  %s  (%d)" % [
		skimmer_level,
		"not fitted" if skim_radius() < 0
			else "%d tiles, %d deep, tier %d, %d%% of what it passes, +%d deck" % [
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

	file.store_var({
		"version": SAVE_VERSION,
		"seed": LAKE_SEED,
		"sludge": sludge,
		"levels": {
			"net_width": net_width_level, "net_strength": net_strength_level,
			"net_range": net_range_level, "reel": reel_level,
			"net_hold": net_hold_level,
			"boat_speed": boat_speed_level, "cargo": cargo_level,
			"skimmer": skimmer_level, "fleet": fleet_level,
		},
		"caught": caught,
		"sold_count": sold_count,
		"birds_caught": birds_caught,
		"sold_by_kind": sold_by_kind,
		"runs_done": _runs_done(),
		"auto_ferry": _auto_ferry.button_pressed,
		"fullscreen": _is_fullscreen(),
		"music": _music_on.button_pressed,
		"music_level": _music_level.value,
		"farewell": _farewell_shown,
		"sfx": _sfx_on.button_pressed,
		"sfx_level": _sfx_level.value,
		"angler": _angler.tile_pos,
		"yard_held": _yard.held,
		"unlocked": unlocked,
		"decor": decor,
		"afloat": afloat,
		"stacks": _grid.stacks,
	}, true)
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
	if save == null or int(save.get("version", 0)) != SAVE_VERSION 			or int(save.get("seed", 0)) != LAKE_SEED:
		_note_save("the save is from another build — ignored")
		return false
	if not _grid.restore(save.get("stacks", []) as Array):
		_note_save("the save does not fit this lake — ignored")
		return false

	var levels := save.get("levels", {}) as Dictionary
	net_width_level = int(levels.get("net_width", 0))
	net_strength_level = int(levels.get("net_strength", 0))
	net_range_level = int(levels.get("net_range", 0))
	reel_level = int(levels.get("reel", 0))
	net_hold_level = int(levels.get("net_hold", 0))
	boat_speed_level = int(levels.get("boat_speed", 0))
	cargo_level = int(levels.get("cargo", 0))
	skimmer_level = int(levels.get("skimmer", 0))

	sludge = float(save.get("sludge", 0.0))
	caught = int(save.get("caught", 0))
	sold_count = int(save.get("sold_count", 0))
	birds_caught = int(save.get("birds_caught", 0))
	sold_by_kind = PackedInt32Array(save.get("sold_by_kind", PackedInt32Array([0, 0, 0, 0])))

	# Finds and where they were put. Anything the catalogue no longer knows is dropped:
	# re-cutting the sheets renames pieces, and that must not take a save down with it.
	unlocked.clear()
	for name: String in save.get("unlocked", []) as Array:
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
		})

	# The fleet is rebuilt to the size that was bought, and every hull comes home empty:
	# whatever was aboard goes back on the pile it was loaded from, so nothing is quietly
	# thrown away by saving mid-run.
	_yard.held = PackedInt32Array(save.get("yard_held", PackedInt32Array()))
	var wanted := mini(int(levels.get("fleet", 0)), MAX_BOATS - 1)
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

	_fullscreen.button_pressed = bool(save.get("fullscreen", _is_fullscreen()))
	_music_level.value = clampf(float(save.get("music_level", _music_level.value)), 0.0, 1.0)
	_music_on.button_pressed = bool(save.get("music", true))
	_push_music()
	# A lake that was finished before the game was closed is finished when it comes back,
	# and lit that way from the first frame rather than brightening as if it had just
	# happened. The thanks are not repeated: they were earned once.
	_farewell_shown = bool(save.get("farewell", false))
	_cleaned = _grid.piece_count() == 0
	_sparkle_at = 1.0 if _cleaned else 0.0
	_sfx_level.value = clampf(float(save.get("sfx_level", _sfx_level.value)), 0.0, 1.0)
	_sfx_on.button_pressed = bool(save.get("sfx", true))
	_push_sfx()
	if _room != null:
		_room.unlocked = unlocked
		_room.decor = decor
	_auto_ferry.button_pressed = bool(save.get("auto_ferry", true))
	_set_auto_ferry(_auto_ferry.button_pressed)
	_angler.stand_at(save.get("angler", _angler.tile_pos) as Vector2)
	_net.set_pulling(false)
	_net.state = CastNet.State.IDLE
	_net.catch.resize(0)
	_push_net_numbers()
	_net.tile_pos = _angler.tile_pos
	_push_boat_numbers()

	# The meter is re-read from the field rather than stored: it is a fraction of a total
	# that the build already worked out, and the field is the truth.
	_filth_left = _grid.filth_left()
	pollution = clampf(_filth_left / _filth_total, 0.0, 1.0)
	_camera.position = Iso.tile_to_world(_angler.tile_pos.x, _angler.tile_pos.y)
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


## The shed, and the prompt over it when the angler is close enough to use it.
##
## The same hut that is drawn on the shed button, cut out of it by tools/slice_shed.gd. One
## picture for the thing and the button that opens it: the player learns what the button
## means by having walked up to it.
func _draw_shed() -> void:
	var at := Iso.tile_to_world(Iso.ISLAND_CENTRE.x, Iso.ISLAND_CENTRE.y)

	# Footprint first, so the hut has something to stand on rather than floating. Drawn to
	# the same ellipse the angler is kept out of, so what looks solid is what is solid.
	var ring := PackedVector2Array()
	for i in 25:
		var angle := TAU * float(i) / 24.0
		var tile := Iso.ISLAND_CENTRE + Vector2(
			cos(angle) * Iso.SHED_FOOT.x, sin(angle) * Iso.SHED_FOOT.y
		)
		ring.append(Iso.tile_to_world(tile.x, tile.y))
	_island.draw_colored_polygon(ring, Color(0.0, 0.0, 0.0, 0.16))

	if _shed_art != null:
		# Standing on the footprint rather than centred on it: the hut's own base is the
		# bottom of the picture, and the middle of it is halfway up a wall.
		var size := _shed_art.get_size() * (Iso.SHED_TALL / _shed_art.get_size().y)
		_island.draw_texture_rect(
			_shed_art,
			Rect2(at - Vector2(size.x * 0.5, size.y - Iso.TILE_H * 0.35), size),
			false
		)
		_draw_shed_lamp(at)
		return

	_draw_shed_blocked(at)


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

