class_name Room
extends Node2D

## One organ. Geometry is built in code from the exit list, because a room
## with three doors and a room with two are the same room with a different
## hole in the wall -- authoring four wall variants by hand is how you end up
## with sixteen.

signal door_used(link_id: String)
signal item_taken(item: Item)
## One mote picked up, forwarded from the room's DnaLayer. The run keeps the
## running total; the room only knows what was on its own floor.
signal dna_collected(value: int)
signal cleared
## The player touched this room's way out of the body. Only ever fired during
## the rampage, and only in a room that has an exit at all.
signal escaped

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")
## Backdrop art for the limbs. A limb chain alternates bone and muscle the whole
## way down, so these two are what tell one lane from the next at a glance --
## which is exactly why they are split by TISSUE and not by region.
const MUSCLE_BACKDROP: Texture2D = preload("res://art/rooms/muscles_bg.png")
const MUSCLE_PARTS: PackedStringArray = [
	"l_biceps", "r_biceps", "l_flexor", "r_flexor",
	"l_quad", "r_quad", "l_calf", "r_calf",
]
## The long bones, plus the joints between them. A knee is a bone place: it is
## where two of them meet, and putting the joints on the muscle side would break
## up every limb's read for no anatomical reason.
const BONE_BACKDROP: Texture2D = preload("res://art/rooms/bones_bg.png")
const BONE_PARTS: PackedStringArray = [
	"l_humerus", "r_humerus", "l_radius", "r_radius",
	"l_femur", "r_femur", "l_tibia", "r_tibia",
	"l_shoulder", "r_shoulder", "l_elbow", "r_elbow", "l_hand", "r_hand",
	"l_hip", "r_hip", "l_knee", "r_knee", "l_foot", "r_foot",
]
## The gut, everything from the stomach down plus the two glands that feed it.
## Not the spleen: it sits in among them but it is lymphatic, and it is one of
## the few organs down there that is NOT part of the same system.
const DIGESTIVE_BACKDROP: Texture2D = preload("res://art/rooms/digestive_bg.png")
const DIGESTIVE_PARTS: PackedStringArray = [
	"stomach", "duodenum", "small_bowel", "large_bowel", "gut", "rectum",
	"liver", "pancreas",
]
## How far past the room's own footprint the backdrop is drawn, as a fraction of
## the interior on each side. The camera follows the player down a long lane, so
## the picture has to still cover the frame when he is standing at either end.
const BACKDROP_OVERSCAN: float = 0.6
## How far the photo is pushed toward black. The art is a full brightness
## illustration and the game is read off small bright sprites -- see ART_BIBLE,
## "Enemy health has to stay readable". Scenery loses this argument every time,
## and the backdrop is behind the walls where nothing is fought at all.
const BACKDROP_DIM: float = 0.5
## Dark wash over the top, so the busiest parts of the image never compete with
## something standing in front of them.
const BACKDROP_WASH: Color = Color(0.04, 0.02, 0.03, 0.35)
## How far the floor is dropped from the backdrop's mean colour. Same hue, so
## the room reads as cut INTO the flesh around it; different value, so the floor
## still separates from the surround. With the muscle art this lands the floor
## at roughly (0.15, 0.08, 0.08) -- a shade lighter than the dimmed, washed
## backdrop, which is the right way round: the floor is the lit surface the
## fight happens on.
const FLOOR_FROM_BACKDROP_DARKEN: float = 0.45

const VIRUS_ART: Texture2D = preload("res://art/enemies/virus.png")
const WORM_ART: Texture2D = preload("res://art/enemies/worm.png")
const FUNGUS_ART: Texture2D = preload("res://art/enemies/fungus.png")
const PARASITE_ART: Texture2D = preload("res://art/enemies/parasite.png")
## The scientist wears the KID's own sheet, tinted to something drained. That is
## the creature: the player's silhouette coming at him out of the dark, which is
## a thing no purpose-drawn monster can do. Swap this the moment the sheet has a
## proper one -- nothing else here assumes it.
const SCIENTIST_ART: Texture2D = preload("res://art/kid.png")

## The bestiary. One row per creature: how it fights, what it looks like, and
## the handful of numbers that make two rows sharing a behaviour still feel like
## different animals. Picked from the room's seeded rng, so a given seed always
## populates a room the same way.
##
## Art and behaviour are chosen TOGETHER and never independently -- the player
## has to be able to read the threat off the body before it does anything.
##
## `height` is on-screen size, and it is the ONLY size number here: the hitbox is
## measured off the sprite's opaque pixels at spawn, so a creature drawn wider
## than it is tall gets a hitbox that says so without anyone typing a radius.
## The kid is drawn about 104px tall. Every ordinary creature stays under this,
## so the player is the biggest thing in any room he can win -- and the boss,
## which sets its own height, is instantly readable as the exception.
const ENEMY_MAX_HEIGHT: float = 86.0

const BESTIARY: Array[Dictionary] = [
	## Green spiked ball. Walks you down on a weaving line.
	{
		"art": VIRUS_ART, "behavior": Enemy.Behavior.CHASER,
		"height": 78.0, "faces": 1.0,
		"speed": 1.0, "health": 1.0, "contact": 1.0,
	},
	## Purple grub. Keeps its distance and spits.
	{
		"art": WORM_ART, "behavior": Enemy.Behavior.SPITTER,
		"height": 82.0, "faces": 1.0,
		"speed": 0.7, "health": 1.0, "contact": 1.0, "spits": true,
	},
	## Fungus: sits, tenses, throws itself across the room, then has to breathe.
	## Tougher than the chaser, because the whole enemy is a rhythm to learn and
	## one that dies to a stray shot never teaches it.
	{
		"art": FUNGUS_ART, "behavior": Enemy.Behavior.CHARGER,
		# The biggest of the ordinary creatures -- it is the one that has to be
		# seen bracing from across the room -- but still under the kid.
		"height": ENEMY_MAX_HEIGHT, "faces": 1.0,
		"speed": 0.95, "health": 1.5, "contact": 1.0,
	},
	## Parasite: does not want anything to do with the player. Wanders, blocks
	## shots, gets in the way. No contact damage at all -- it is an obstacle with
	## a pulse, and hurting on touch would make it just another chaser.
	{
		"art": PARASITE_ART, "behavior": Enemy.Behavior.WANDERER,
		# The one creature drawn looking left.
		"height": 74.0, "faces": -1.0,
		"speed": 1.85, "health": 0.35, "contact": 0.0,
	},
]

## Creatures that belong to particular places, and are never in the ordinary
## draw. Kept out of BESTIARY on purpose: that list is what a wave rolls from,
## and a can of deodorant turning up in a lung would undo the thing the whole
## bestiary is for -- that where you are is readable off what is attacking you.
##
## The can got in the way in goes and rolled on from there, so it turns up
## anywhere along the tract -- thickest at the end it came in by, and thinning
## out the further up you get. See CAN_CHANCE_HOME and CAN_CHANCE_TRACT.
const CAN_HOME: PackedStringArray = ["rectum"]

## The aerosol. Rolls in a straight line, gasses the floor behind it, and shoves
## everything organic out of its way.
##
## Bigger than the kid, and the only thing in the bestiary that is. It is not
## alive and it is not part of the body -- it is an object that got in, and the
## fact that it does not respect ENEMY_MAX_HEIGHT is the read.
const CAN_ROW: Dictionary = {
	"art": null, "behavior": Enemy.Behavior.ROLLER,
	"height": 170.0, "faces": 0.0,
	# Slow. The whole enemy is a thing you have time to see coming and have to
	# move around, and a fast one is just an unfair chaser.
	"speed": 0.62, "health": 3.0, "contact": 2.0,
	"large": true, "can": true, "tall": true,
}

## The scientist. Something the player's own shape, gone wrong, holding the same
## gun and using it badly.
const SCIENTIST_ROW: Dictionary = {
	"art": SCIENTIST_ART, "behavior": Enemy.Behavior.SKITTER,
	# The one creature allowed to stand as tall as the kid, because being his
	# size is the entire point of it.
	"height": 104.0, "faces": 0.0,
	"speed": 1.15, "health": 0.8, "contact": 0.0,
	"darts": true, "tall": true,
	# Drained and cold. It is him with the life taken out, not a new colour of
	# creature -- but lifted well off the near-black it was, because `tint`
	# MULTIPLIES the sprite and a dark organ was swallowing him whole.
	"tint": Color(0.62, 0.64, 0.80),
	# What actually makes him findable: the body gives off light, in the same
	# amber his darts are. Shooter and shot read as one thing, so a floor full of
	# orange tells the player where it is coming from without them tracing a
	# single shot back.
	"glow": Color(1.0, 0.58, 0.06), "glow_amount": 0.55,
}

## How often a spawn in a qualifying room is the can instead of an ordinary
## creature. Common enough at the rectum that the room is about it, and rare
## enough further up the tract to stay a surprise rather than a theme.
const CAN_CHANCE_HOME: float = 0.4
const CAN_CHANCE_TRACT: float = 0.12

## How often a spawn anywhere else is a scientist. They are not anatomy -- they
## are somebody's experiment loose in the body -- so they are not tied to a
## region the way everything else is, only kept out of rooms that already have a
## specialist of their own. One strange thing per room.
const SCIENTIST_CHANCE: float = 0.09

const SPIT_STATS: AttackStats = preload("res://config/enemy_spit.tres")
const DART_STATS: AttackStats = preload("res://config/scientist_dart.tres")
## The infections, by kind. A lookup rather than a match per kind, so a fourth
## boss is a row in a table instead of a fourth branch in a spawn function.
##
## `preload` resolves at PARSE time, so every scene named here has to exist
## before this file will compile at all -- which is why the two new bosses landed
## as scenes before anything referenced them.
const BOSS_SCENES: Dictionary = {
	MapData.BossKind.WORM: preload("res://scenes/boss.tscn"),
	MapData.BossKind.CAN: preload("res://scenes/boss_can.tscn"),
	MapData.BossKind.FUNGUS: preload("res://scenes/boss_fungus.tscn"),
}
## The rampage's own creature: the immune system finally noticing, arriving fast
## and dying to almost anything. A separate scene rather than a re-tuned Enemy
## so the two can be balanced without one dragging the other around.
const WBC_SCENE: PackedScene = preload("res://scenes/wbc.tscn")

## The rampage's spawn markers run on a shorter fuse than a wave's. A wave is
## something you position yourself for; a rampage spawn is something you are
## already running past.
const RAMPAGE_MARKER_LEAD: float = 0.55
const RAMPAGE_LIVE_CAP: int = 26

## Gap between the two pedestals of a cache. Wide enough that walking to one
## cannot brush the other -- the choice must never be made by the hitbox.
const PEDESTAL_SPACING: float = 150.0

## The wall tiles, cut from art_ref/Side_walls_Grid.png by
## tools/make_wall_tiles.gd. Each one wraps along the axis it repeats on, so a
## wall of any length has no seam in it. Re-run that tool if the sheet changes.
## Several cuts of each, picked per room from the seeded rng: one tile used
## everywhere makes forty rooms read as forty copies of one room.
const WALL_TILES_H: Array[Texture2D] = [
	preload("res://art/rooms/wall_h_0.png"),
	preload("res://art/rooms/wall_h_1.png"),
	preload("res://art/rooms/wall_h_2.png"),
]
const WALL_TILES_V: Array[Texture2D] = [
	preload("res://art/rooms/wall_v_0.png"),
	preload("res://art/rooms/wall_v_1.png"),
	preload("res://art/rooms/wall_v_2.png"),
]
## How much of the part's own colour is washed into its walls. Enough that a
## lung and a femur are not lined with identical meat, not so much that the
## tiles stop looking like the same body.
const WALL_TINT_STRENGTH: float = 0.45
## Brightness spread between rooms, either side of 1.
const WALL_SHADE_JITTER: float = 0.16

## Strength of the warm pool of light over the middle of a room. The organ is
## the light source -- there is nothing else down here -- so it is tinted with
## the part's own colour.
const AMBIENT_GLOW: float = 0.16
## How thick the wall LOOKS, measured outward from the room's edge. Much thicker
## than the collision below it, and entirely outside the playable floor: the
## inner face of the art sits exactly on the surface the player collides with, so
## a wall that reads as heavy meat never lies about where it stops you.
const WALL_VISUAL: float = 76.0

const WALL: float = 20.0
const DOOR_INSET: float = 110.0

## Narrowest strip of wall allowed between two doorways, or between a doorway and
## a corner. Below this the two gaps read as one wide hole, and the pier between
## them is a sliver a fast mover can be shoved through.
const MIN_PIER: float = 60.0


## How many doors a given wall of this room can hold. A fork opening onto the
## short end of a lane is the failure this exists to catch, before it ships as
## overlapping doorways and a wall segment with negative width.
static func wall_capacity(span: float) -> int:
	return int(floor((span - MIN_PIER) / (Door.GAP + MIN_PIER)))

## Room footprint. Set per room from MapData -- an organ is a cavern, a forearm
## is a lane -- so nothing here may assume a fixed size. It used to be a const,
## and everything derived from it was a const too; those are now functions of
## this.
var interior: Vector2 = MapData.CHAMBER_SIZE

## --- hazards ---------------------------------------------------------------
## Hazards are placed by ANATOMY, not by difficulty: acid is in the digestive
## tract because that is where acid is, mold is in the airways because that is
## where mold is, and a cramp happens in a limb because that is what cramps.
## A room's hazard is therefore part of knowing where you are.
const ACID_PARTS: PackedStringArray = [
	"stomach", "duodenum", "small_bowel", "large_bowel", "gut",
	"pancreas", "liver", "spleen", "rectum",
]
const MOLD_PARTS: PackedStringArray = [
	"trachea", "larynx", "l_lung", "r_lung", "nasal", "sinus", "neck_base",
	"mouth", "diaphragm",
]

## Lungs that have been smoked in. Visual only -- these rooms already carry mold
## as their hazard, and a second one on the same rooms would make the airways the
## part of the body everyone routes around.
const SMOKE_PARTS: PackedStringArray = ["l_lung", "r_lung"]

## Where the nervous system misfires. The brain throws telegraphed bolts instead
## of a pool or a shove: it is the one organ whose hazard should be something it
## AIMS, and the warning on the floor is what makes that fair.
const SHOCK_PARTS: PackedStringArray = ["brain"]
## Seconds between bolts, and how far off the player one may land. Off, not on:
## a strike centred exactly where the player stands is a strike they can only
## escape by moving, every time, which is a tax rather than a hazard.
const SHOCK_INTERVAL_MIN: float = 3.4
const SHOCK_INTERVAL_MAX: float = 5.8
const SHOCK_LEAD: float = 150.0
## How many land at once as the room gets busier. The second one is what turns a
## bolt from something you step out of into something you have to step BETWEEN.
const SHOCK_BURST_MAX: int = 2
const SHOCK_RADIUS_MIN: float = 74.0
const SHOCK_RADIUS_MAX: float = 108.0

const ACID_POOL_MIN: int = 2
const ACID_POOL_MAX: int = 4
const ACID_RADIUS_MIN: float = 62.0
const ACID_RADIUS_MAX: float = 108.0

const MOLD_MIN: int = 2
const MOLD_MAX: int = 4

## Seconds between cramps, and how long the walls rumble before the one shove.
## The rumble is the entire warning, so it is long enough to run out of the
## middle of the room -- the shove is toward the centre, so the walls are where
## it hurts.
## Rare and hard rather than frequent and nudging: a cramp you can plan around
## between fights, that genuinely relocates you when it lands.
## The fight a cache is worth. Two waves exactly, whatever size room it landed
## in, and lighter than a combat room of the same depth would throw -- the point
## is to make the player earn the pedestal, not to make caches the hardest fights
## on the floor and have people route around their own supplies.
const ITEM_GATE_WAVES: int = 2
const ITEM_GATE_BUDGET: float = 0.7

## How deep the wall collision runs behind its visible surface. Sized against the
## hardest shove in the game: a cramp moves a body about a third of this in one
## physics frame, so there is no step that can clear the far side of it.
const WALL_THICKNESS: float = 120.0

const CRAMP_INTERVAL_MIN: float = 16.0
const CRAMP_INTERVAL_MAX: float = 26.0
const CRAMP_RUMBLE: float = 1.3
const CRAMP_PUSH: float = 1250.0
## How far from a wall the shove still reaches. Beyond this the room just shakes.
## Wide enough that most of a lane's width is in range of one wall or the other.
const CRAMP_REACH: float = 360.0

var kind: MapData.RoomKind = MapData.RoomKind.COMBAT
var shape: BodyPlan.RoomShape = BodyPlan.RoomShape.CHAMBER
var display_name: String = ""
var part_id: String = ""
var region: BodyPlan.Region = BodyPlan.Region.TORSO
var part_color: Color = Color(0.5, 0.3, 0.3)
var doors: Dictionary = {}   ## link id -> Door

var _live: Array[Node] = []
var _combat_active: bool = false
## Enemy counts still owed, one entry per unspawned wave. Popped from the front.
var _pending_waves: Array[int] = []

## A cache's items, held from the moment the room is built until its gate is
## fought off. Empty in every room that is not an uncleared cache, which is what
## makes _release_offer safe to call on any room's clear path.
var _pending_offer: Array = []
## Markers currently counting down. The room is not clear while any exist, even
## if nothing is alive -- otherwise the doors open a frame before the wave lands.
var _markers: Array[SpawnMarker] = []
var _wave_depth: int = 0
var _rng: RandomNumberGenerator = null
## The doorway the player walked in through, by link id. Empty on the run's
## first room, where they did not come through a door at all.
var _entry_link: String = ""
## This room's own exit records, kept so the doors can be found by link id
## after build time.
var _exits: Array = []
## Cover blocks, in room space. Kept so _draw can paint what the collision says.
var _obstacles: Array[Rect2] = []
## The room's actual boundary, in room space, wound clockwise. See
## _build_outline. Everything that places or draws anything reads this rather
## than `interior`.
var _outline: PackedVector2Array = PackedVector2Array()
## Per outline point: 1 if it falls inside a doorway's clearance, so that both
## the collision and the wall art skip it.
var _outline_door: PackedByteArray = PackedByteArray()
## The wall body, kept so the doors can hang their plugs off the same one. A plug
## on its own body is a second static surface meeting the wall at a seam, and a
## seam between two static bodies is a thing a shoved body slips through.
var _wall_body: StaticBody2D = null
## One entry per opening left in the wall: `a` and `b` are the two outline points
## the solid wall stops at, so a plug is measured off the hole it actually fills
## rather than off the door's nominal width.
var _wall_holes: Array[Dictionary] = []
## This room's wall look, rolled once at build time off the seeded rng so a room
## is lined the same way every time it is walked back into.
var _wall_tex_h: Texture2D = null
var _wall_tex_v: Texture2D = null
var _wall_tint: Color = Color.WHITE
## Which tile the wall is currently laying, while _draw_walks around the loop.
## Held between edges so the choice has hysteresis -- see _draw_walls.
var _wall_upright: bool = false
## Whether each axis' tiles are mirrored across the wall. A tile that wraps along
## its length still wraps when flipped, so this is two more looks for free.
var _wall_flip_h: bool = false
var _wall_flip_v: bool = false

## Seconds until the next cramp starts rumbling. Zero on a room that cannot
## cramp at all, which is how the tick knows to do nothing.
var _cramp_timer: float = 0.0
## Seconds until the brain throws its next bolt. Zero on every room that is not
## the brain, which is how the tick knows to do nothing.
var _shock_timer: float = 0.0
## Counts down through the rumble; the shove lands when it reaches zero.
var _cramp_rumble: float = 0.0
## How hard the walls are shaking right now, 0..1. Drawn, not simulated.
var _cramp_shake: float = 0.0

## --- rampage ---
## Set by the run manager. While true the room keeps producing white cells for
## as long as the player stands in it, forever, and clearing is not a thing that
## can happen any more.
var rampage: bool = false
## Seconds between rampage spawns, and how many arrive each time. Both are owned
## by the run manager, because the escalation is a property of the RUN's clock,
## not of how long you happen to have been in this particular room -- otherwise
## hiding in a fresh room would reset the pressure.
var rampage_interval: float = 3.0
var rampage_batch: int = 1
var _rampage_timer: float = 0.0
var _rampage_live: Array[Node] = []

## The floor's memory. Built first thing in build(), fed from the map, and the
## only thing in the room that survives leaving it.
var _blood: BloodLayer = null

## Uncollected DNA on this floor. Like the blood, it belongs to the run and not
## to this Room object.
var _dna: DnaLayer = null


## Where along a wall the nth of `count` doors sits. Evenly spaced, so a single
## door lands dead centre exactly as it always did and a pair sits at thirds.
func door_offset(dir: String, slot: int, count: int) -> float:
	var span := interior.x if dir == "n" or dir == "s" else interior.y
	return span * float(slot + 1) / float(count + 1)


## Where the player stands after walking in through a given doorway, just inside
## it.
func entry_point(from_dir: String, slot: int = 0, count: int = 1) -> Vector2:
	var along := door_offset(from_dir, slot, count)
	match from_dir:
		"n": return Vector2(along, DOOR_INSET)
		"s": return Vector2(along, interior.y - DOOR_INSET)
		"w": return Vector2(DOOR_INSET, along)
		"e": return Vector2(interior.x - DOOR_INSET, along)
		_: return interior * 0.5


## Where the player stands after arriving through a named doorway. Falls back to
## the middle of the room when there is no doorway to speak of -- the run's first
## room, or a test dropping the player in.
func entry_point_for_link(id: String) -> Vector2:
	var e := _exit_for_link(id)
	if e.is_empty():
		return interior * 0.5
	return entry_point(e["dir"], e["slot"], e["count"])


func door_point(dir: String, slot: int = 0, count: int = 1) -> Vector2:
	var along := door_offset(dir, slot, count)
	match dir:
		"n": return Vector2(along, 8.0)
		"s": return Vector2(along, interior.y - 8.0)
		"w": return Vector2(8.0, along)
		_: return Vector2(interior.x - 8.0, along)


func _exit_for_link(id: String) -> Dictionary:
	if id == "":
		return {}
	for e: Dictionary in _exits:
		if e["link"] == id:
			return e
	return {}


## --- organic outline -------------------------------------------------------
##
## A room is authored as a RECTANGLE and always will be: doors sit on walls,
## lanes are long, the minimap is a grid, and every one of those wants straight
## edges to reason about. What changes here is only the boundary that is drawn
## and collided with -- the rectangle is eaten into until what is left is a
## cavity in tissue rather than a box.
##
## The rectangle therefore stays the room's frame of reference. entry_point,
## door_offset and the spawn margins all still speak in it; the outline is a
## deformation of it that everything else is checked against.

## Points around the boundary. Enough that a 1700px lane's curve is smooth,
## few enough that the wall is ~70 textured quads rather than hundreds.
const OUTLINE_SAMPLES: int = 128
## How much one axis has to beat the other before the wall switches between the
## horizontal and vertical tile. See _draw_walls.
const ORIENT_HYSTERESIS: float = 1.35
## Baseline bite out of the rectangle, as a fraction of the SHORT side -- so a
## narrow lane loses the same proportion of itself as a cavern does and neither
## ends up impassable.
const OUTLINE_INSET: float = 0.05
## How far the boundary breathes either side of that baseline.
const OUTLINE_WOBBLE: float = 0.055
## Corner radius, as a fraction of the short side. This is what does most of the
## work: a rectangle with rounded corners already reads as a cavity rather than
## as a room, before any wobble is applied.
const CORNER_ROUND: float = 0.30
## Bones are drawn straight, because bones ARE straight -- they get the inset and
## almost none of the wobble. Everything else is soft tissue.
const BONE_WOBBLE_MULT: float = 0.18
## Clear space kept either side of a doorway, where the boundary is pinned back
## to the rectangle. Slightly wider than the door itself so nobody has to thread
## a gap that is narrower than the opening it leads to.
const DOOR_CLEAR: float = Door.GAP * 0.62
## Distance over which the boundary eases from pinned-at-the-door back to its
## own shape. Abrupt would put a corner in the wall beside every doorway.
const DOOR_EASE: float = 130.0


## Builds the boundary polygon: one point per sample, walked around the
## rectangle's perimeter and pushed inward.
##
## Every deformation is a function of the perimeter parameter and uses WHOLE
## harmonics of it, so the last point joins the first with no seam. That is the
## one hard constraint here -- an outline that does not close is a room with a
## hole in the wall.
func _build_outline(rng: RandomNumberGenerator) -> void:
	_outline = PackedVector2Array()
	_outline_door = PackedByteArray()

	var short_side := minf(interior.x, interior.y)
	var base := short_side * OUTLINE_INSET
	var wobble_amp := short_side * OUTLINE_WOBBLE
	if BONE_PARTS.has(part_id):
		wobble_amp *= BONE_WOBBLE_MULT

	# Two harmonics with independent phases: one alone is a regular scallop, and
	# a room that scallops evenly reads as decoration rather than as anatomy.
	var freq_a := rng.randi_range(2, 3)
	var freq_b := rng.randi_range(4, 6)
	var phase_a := rng.randf() * TAU
	var phase_b := rng.randf() * TAU

	var path := _rounded_rect_path()
	var doors := _door_points()

	for i in path.size():
		var step: Dictionary = path[i]
		var pos: Vector2 = step["pos"]
		var normal: Vector2 = step["normal"]

		var u := float(i) / path.size()
		var wobble := sin(u * TAU * freq_a + phase_a) * 0.62 			+ sin(u * TAU * freq_b + phase_b) * 0.38
		var inset := base + wobble * wobble_amp

		# Doorways win over everything: pinned flush to the rectangle inside the
		# clearance, easing back out to the room's own shape beyond it. Measured
		# in the room, not along the path, because what has to stay clear is the
		# space in front of the opening.
		var gap := _door_distance(doors, pos)
		var open := clampf((gap - DOOR_CLEAR) / DOOR_EASE, 0.0, 1.0)
		var eased := open * open * (3.0 - 2.0 * open)  # smoothstep
		var shaped := pos - normal * maxf(inset, 0.0)
		# Pinned back to the rectangle's own edge on the STRAIGHTS only. Doors
		# always land on a straight -- the closest one can sit to a corner is a
		# third of the span, well outside the radius -- and dragging an arc
		# sample back to the sharp corner it replaced puts a spike in the
		# boundary that crosses its neighbours.
		if bool(step["arc"]):
			_outline.append(shaped)
		else:
			_outline.append((step["rect_pos"] as Vector2).lerp(shaped, eased))
		_outline_door.append(1 if gap <= DOOR_CLEAR else 0)


## The base shape, before any wobble: the room's rectangle with its corners
## replaced by real quarter-circle arcs, walked clockwise and sampled evenly by
## arc length.
##
## Arcs rather than pushing the corner samples inward. Insetting a corner
## perpendicular to each of the two edges that meet there sends the path back on
## itself -- the last point of the north edge ends up to the RIGHT of the first
## point of the east edge -- and a polygon that crosses itself will not
## triangulate, so the floor, the light and the walls all silently vanish. An arc
## is traversed once, in order, and cannot do that.
##
## Each sample also carries the point on the original rectangle it came from, so
## a doorway can pin the boundary back to the wall the door node actually sits on.
func _rounded_rect_path() -> Array[Dictionary]:
	var w := interior.x
	var h := interior.y
	# Radius is capped at a third of the short side: beyond that a lane stops
	# being a corridor and becomes a lozenge.
	var r := minf(minf(w, h) * CORNER_ROUND, minf(w, h) / 3.0)

	# Clockwise from the north-west corner. Straights are shortened by the radius
	# at both ends; each arc turns 90 degrees between them.
	var straights: Array[Dictionary] = [
		{"from": Vector2(r, 0.0), "to": Vector2(w - r, 0.0), "normal": Vector2.UP},
		{"from": Vector2(w, r), "to": Vector2(w, h - r), "normal": Vector2.RIGHT},
		{"from": Vector2(w - r, h), "to": Vector2(r, h), "normal": Vector2.DOWN},
		{"from": Vector2(0.0, h - r), "to": Vector2(0.0, r), "normal": Vector2.LEFT},
	]
	var arcs: Array[Dictionary] = [
		{"centre": Vector2(w - r, r), "start": -PI * 0.5},
		{"centre": Vector2(w - r, h - r), "start": 0.0},
		{"centre": Vector2(r, h - r), "start": PI * 0.5},
		{"centre": Vector2(r, r), "start": PI},
	]

	var arc_len := PI * 0.5 * r
	var total := 0.0
	for s: Dictionary in straights:
		total += (s["to"] as Vector2).distance_to(s["from"])
	total += arc_len * 4.0

	var out: Array[Dictionary] = []
	for k in 4:
		var straight: Dictionary = straights[k]
		var from: Vector2 = straight["from"]
		var to: Vector2 = straight["to"]
		var normal: Vector2 = straight["normal"]
		var n := maxi(int(round(from.distance_to(to) / total * OUTLINE_SAMPLES)), 1)
		for i in n:
			var pos := from.lerp(to, float(i) / n)
			out.append({"pos": pos, "normal": normal, "rect_pos": pos, "arc": false})

		var arc: Dictionary = arcs[k]
		var centre: Vector2 = arc["centre"]
		var start: float = arc["start"]
		var m := maxi(int(round(arc_len / total * OUTLINE_SAMPLES)), 1)
		for i in m:
			var a := start + PI * 0.5 * float(i) / m
			var dir := Vector2.from_angle(a)
			# The corner of the rectangle this arc replaced, for door pinning.
			var corner := centre + Vector2(signf(dir.x), signf(dir.y)) * r
			out.append({
				"pos": centre + dir * r,
				"normal": dir,
				"rect_pos": corner,
				"arc": true,
			})
	return out


## Where each doorway sits, in room space, on the rectangle's own edge.
func _door_points() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for e: Dictionary in _exits:
		out.append(door_point(e["dir"], e["slot"], e["count"]))
	return out


func _door_distance(doors: Array[Vector2], p: Vector2) -> float:
	var best := INF
	for d in doors:
		best = minf(best, p.distance_to(d))
	return best


## Is this point inside the room's actual floor? Everything that places anything
## -- spawns, hazards, cover -- has to ask, because the rectangle is now bigger
## than the room.
func contains_point(p: Vector2) -> bool:
	if _outline.is_empty():
		return Rect2(Vector2.ZERO, interior).has_point(p)
	return Geometry2D.is_point_in_polygon(p, _outline)


## Point, with a clearance. Used to keep bodies and pools off the wall rather
## than merely inside it.
func has_clearance(p: Vector2, margin: float) -> bool:
	if not contains_point(p):
		return false
	for i in _outline.size():
		var a := _outline[i]
		var b := _outline[(i + 1) % _outline.size()]
		if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < margin:
			return false
	return true


func build(map: MapData, cell: Vector2i, rng: RandomNumberGenerator, arrival_link: String = "") -> void:
	# The player is not moved to their entry point until after build() returns,
	# so their current position is last room's. Remember where they will be.
	# Without this the wall tiles clamp instead of repeating, and every segment
	# shows one stretched copy with a smear where it ran out.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	# Findable by anything that has to bleed on the floor and is not a child of
	# the room -- the player lives beside it in the scene.
	add_to_group(&"room")
	_entry_link = arrival_link
	# Every room needs the rng, not just the ones that plan waves: a start room
	# or an emptied cache still has to place rampage spawns later.
	_rng = rng
	kind = map.kind_of(cell)
	shape = map.shape_of(cell)
	interior = map.size_of(cell)
	display_name = map.name_of(cell)
	part_color = map.color_of(cell)
	part_id = map.id_of(cell)
	region = map.region_of(cell)
	_exits = map.exits_of(cell)
	_roll_wall_look(rng)

	# Before anything that can die is added, so pools stay under the creatures
	# standing in them. The array comes from the map by reference: what the layer
	# appends is what the run remembers.
	_blood = BloodLayer.new()
	_blood.name = "Blood"
	add_child(_blood)
	_blood.load_splats(map.blood_of(cell))

	# Right after the blood, so DNA lies ON the pools rather than under them, and
	# still under every creature.
	_dna = DnaLayer.new()
	_dna.name = "Dna"
	add_child(_dna)
	_dna.load_motes(map.dna_of(cell))
	_dna.collected.connect(func(value: int) -> void: dna_collected.emit(value))

	# The boundary is decided before anything is built on it: walls, cover,
	# hazards and spawns are all placed against this polygon, not the rectangle.
	_build_outline(rng)
	_build_walls(_exits)
	_build_doors(_exits)
	if shape == BodyPlan.RoomShape.CAVERN:
		_build_obstacles(_exits, rng)
	_build_hazards(rng)

	# Clearing is permanent. Backtracking through a farmed room must be
	# walking, not fighting -- respawns are what make exploration feel taxed.
	if not map.is_cleared(cell):
		match kind:
			MapData.RoomKind.COMBAT:
				_plan_waves(map.distance_from_start(cell), rng)
				_begin_next_wave()
			MapData.RoomKind.BOSS:
				_spawn_boss(map.boss_kind_of(cell))
			MapData.RoomKind.ITEM:
				# The cache is guarded now. Pedestals are held back until the
				# room is clear, so walking in on one is the start of a fight
				# rather than the end of a decision.
				_pending_offer = map.rooms[cell]["items"]
				_plan_waves(map.distance_from_start(cell), rng,
					ITEM_GATE_WAVES, ITEM_GATE_BUDGET)
				_begin_next_wave()
			_:
				pass

	# A room with nothing to kill is open from the first frame.
	_combat_active = not (_live.is_empty() and _markers.is_empty() and _pending_waves.is_empty())
	_set_doors_locked(_combat_active)
	if not _combat_active:
		# Covers the start room, and every room walked back into after it was
		# emptied. Old DNA on a farmed floor should not need a second lap.
		_dna.set_magnet(true)
	if not _combat_active and kind != MapData.RoomKind.START:
		# Covers a cache whose gate planned nothing to fight. The offer still has
		# to arrive, or the room is a dead end holding items nobody can reach.
		_release_offer()
		cleared.emit()


func _process(delta: float) -> void:
	# Hazards are a property of the ROOM, not of the fight, so they keep running
	# through the early returns below -- a cleared limb still cramps.
	_tick_cramp(delta)
	_tick_shock(delta)

	if rampage:
		_tick_rampage(delta)
		return
	if not _combat_active:
		return
	# A pending marker is a wave in flight. Never treat it as an empty room.
	if not _markers.is_empty():
		return
	for n in _live:
		if is_instance_valid(n):
			return
	# Field is empty. Next wave, or the room is done.
	if not _pending_waves.is_empty():
		_live.clear()
		_begin_next_wave()
		return
	_combat_active = false
	_live.clear()
	_set_doors_locked(false)
	# The last wave is down, so the sweep is no longer a decision -- see
	# DnaMote's magnet block. Deliberately not reached during a rampage: that
	# path returns above, and a room that can never be cleared never pays out
	# for free.
	_dna.set_magnet(true)
	# Before the signal, not after: `cleared` is what marks the room cleared on
	# the map, and a listener that reacted by leaving would strand the pedestals
	# in a room that now believes it has already been emptied.
	_release_offer()
	cleared.emit()


# --- geometry ---

## The room's boundary, as collision. One concave shape built from the outline's
## own edges, minus the stretches that are doorways.
##
## Segments rather than a filled polygon: the room is the INSIDE, and a solid
## polygon would be a block the player cannot enter. ConcavePolygonShape2D takes
## a flat list of pairs, so an open doorway is simply a pair that is never added
## -- no special case, no plug, no second body.
##
## The doorway stretches are also where the wall art stops, and both read the
## same `_outline_door` flags, so the hole you can see and the hole you can walk
## through cannot drift apart.
func _build_walls(_exits: Array) -> void:
	if _outline.is_empty():
		return
	var body := StaticBody2D.new()
	body.collision_layer = 16
	body.collision_mask = 0
	add_child(body)

	_wall_body = body
	_wall_holes.clear()

	var centre := interior * 0.5
	for i in _outline.size():
		var j := (i + 1) % _outline.size()
		# An edge is solid only if both of its ends are. Either end being inside
		# a doorway makes it part of the opening.
		if _outline_door[i] == 1 or _outline_door[j] == 1:
			# The first skipped edge of a run opens the hole, and the last one
			# closes it. Recording the opening HERE, from the same test that
			# decides where wall stops, is the whole point: a plug measured from
			# Door.GAP instead was 140 wide in a 173 wide hole, and left about
			# sixteen pixels of daylight down each jamb -- two pixels more than
			# the kid's own radius, so a locked door was a door with two thin
			# doors either side of it.
			if _outline_door[i] == 0:
				_wall_holes.append({"a": _outline[i], "b": _outline[i], "open": true})
			elif _outline_door[j] == 0 and not _wall_holes.is_empty() \
					and bool(_wall_holes[-1]["open"]):
				_wall_holes[-1]["b"] = _outline[j]
				_wall_holes[-1]["open"] = false
			continue
		var a: Vector2 = _outline[i]
		var b: Vector2 = _outline[j]
		var span := b - a
		var length := span.length()
		if length < 0.5:
			continue

		# One box per edge instead of one zero-thickness segment for the whole
		# ring. A CharacterBody2D shoved hard at a segment can finish its step
		# past the line, and depenetration then has no way to tell which side it
		# was supposed to be on -- so it pushes the body further OUT and the kid
		# is outside the room. It took a cramp to expose it because a cramp is
		# the only thing in the game that moves him faster than he can walk.
		# A box has an inside, so the worst a hard shove can do is end up buried
		# in it, and buried resolves back into the room every time.
		var normal := span.orthogonal().normalized()
		# Outward, whichever way the winding happens to run: the outline is built
		# per room shape and is not guaranteed to be wound consistently.
		if normal.dot(((a + b) * 0.5) - centre) < 0.0:
			normal = -normal

		var shape := RectangleShape2D.new()
		shape.size = Vector2(length, WALL_THICKNESS)
		var cs := CollisionShape2D.new()
		cs.shape = shape
		# Pushed out by half its thickness so the INNER face lands exactly on the
		# outline. The playable floor is unchanged by this; all the new thickness
		# is behind the surface, where nothing stands.
		cs.position = (a + b) * 0.5 + normal * (WALL_THICKNESS * 0.5)
		cs.rotation = span.angle()
		body.add_child(cs)


## Cover blocks, so an organ is a space to fight through rather than a bigger
## empty box. A cavern without them just makes the walk longer.
##
## Placed on a coarse grid rather than at random points: random placement in a
## room this size reliably produces two blocks touching and a third sealing a
## doorway, and rejection-sampling that away costs more than just choosing from
## legal slots in the first place.
func _build_obstacles(exits: Array, rng: RandomNumberGenerator) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 16
	body.collision_mask = 0
	add_child(body)

	# Keep clear of the door corridors and of the middle, which holds the boss or
	# the pedestal.
	var corridor := Door.GAP * 0.5 + 90.0
	var slots: Array[Vector2] = []
	for gx in 3:
		for gy in 2:
			var p := Vector2(
				interior.x * (0.26 + 0.24 * gx),
				interior.y * (0.30 + 0.40 * gy)
			)
			if p.distance_to(interior * 0.5) < 240.0:
				continue
			var blocks_door := false
			for e: Dictionary in exits:
				var side: String = e["dir"]
				var d := door_point(side, e["slot"], e["count"])
				if side == "n" or side == "s":
					blocks_door = blocks_door or absf(p.x - d.x) < corridor
				else:
					blocks_door = blocks_door or absf(p.y - d.y) < corridor
			if blocks_door:
				continue
			# Cover has to sit in the room, not in the wall the room curves away
			# behind. Half the largest block is the clearance asked for.
			if not has_clearance(p, 110.0):
				continue
			slots.append(p)

	# Fisher-Yates on the seeded rng, NOT Array.shuffle() -- that draws from the
	# global RNG and would make a seeded run stop reproducing itself.
	for i in range(slots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := slots[i]
		slots[i] = slots[j]
		slots[j] = tmp

	var count := mini(3, slots.size())
	for i in count:
		var size := Vector2(rng.randf_range(120.0, 210.0), rng.randf_range(120.0, 210.0))
		var centre: Vector2 = slots[i] + Vector2(
			rng.randf_range(-40.0, 40.0), rng.randf_range(-30.0, 30.0))
		var rect := Rect2(centre - size * 0.5, size)
		_obstacles.append(rect)

		# Capsule, not a box: the block is DRAWN as a lump, and a square hitbox
		# under a round shape catches the player on a corner that is not there.
		var cs := CollisionShape2D.new()
		SpriteFootprint.apply_capsule(cs, rect, 0.94)
		body.add_child(cs)


func _build_doors(exits: Array) -> void:
	for e: Dictionary in exits:
		var d := Door.new()
		d.link_id = e["link"]
		d.dir = e["dir"]
		# Signposted only where the door is one of a pair on the same wall, which
		# is exactly where the player is being asked to choose and would otherwise
		# be choosing blind.
		if e["count"] > 1:
			d.label = e["label"]
			d.hint = e["hint"]
		d.position = door_point(e["dir"], e["slot"], e["count"])
		d.used.connect(func(id: String) -> void: door_used.emit(id))
		add_child(d)
		doors[e["link"]] = d
		d.attach_plug(_build_plug(d.position))


## The solid the door drops into its own opening while locked.
##
## Built here rather than inside Door, and parented to the WALL body, because
## both facts it needs belong to the room: how wide the hole in the wall actually
## came out, and how deep the wall around it is. A door that guesses at either
## one gets a plug that does not fit, which is a plug with a way past it.
##
## Returns null on a door with no matching hole, which is not an error worth
## crashing over -- an unpluggable door is a door that is always open.
func _build_plug(at: Vector2) -> CollisionShape2D:
	if _wall_body == null:
		return null

	var best: Dictionary = {}
	var best_dist := INF
	for hole: Dictionary in _wall_holes:
		var mid: Vector2 = ((hole["a"] as Vector2) + (hole["b"] as Vector2)) * 0.5
		var dist := mid.distance_squared_to(at)
		if dist < best_dist:
			best_dist = dist
			best = hole
	if best.is_empty():
		return null

	var a: Vector2 = best["a"]
	var b: Vector2 = best["b"]
	var span := b - a
	var length := span.length()
	if length < 0.5:
		return null

	# Measured, aligned and sized exactly as the wall boxes are, so the plug is
	# the missing box out of that ring rather than a lid laid over it.
	var normal := span.orthogonal().normalized()
	if normal.dot(((a + b) * 0.5) - interior * 0.5) < 0.0:
		normal = -normal

	var shape := RectangleShape2D.new()
	shape.size = Vector2(length, WALL_THICKNESS)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = (a + b) * 0.5 + normal * (WALL_THICKNESS * 0.5)
	cs.rotation = span.angle()
	cs.disabled = true
	_wall_body.add_child(cs)
	return cs


func _set_doors_locked(value: bool) -> void:
	for d: Door in doors.values():
		d.set_locked(value)


# --- contents ---

## Splits the room's whole enemy budget into waves. Bigger rooms get both more
## waves and fatter ones -- a cavern that emptied in one go was just a chamber
## with a longer walk, and a lane that got a cavern's wave was a wall of meat.
##
## Waves escalate: the last one is the biggest, so a room reads as building
## pressure rather than a flat drip.
## `force_waves` pins the count instead of taking it from the room's size, and
## `budget_mult` scales how much meat is split across them. Both exist for the
## cache gate, which has to be the same shape of fight in a lane as in a cavern
## -- "two waves" is a promise the player reads off the map, so it cannot quietly
## become three because the cache landed somewhere roomy.
func _plan_waves(depth: int, rng: RandomNumberGenerator, force_waves: int = 0,
		budget_mult: float = 1.0) -> void:
	_wave_depth = depth
	_rng = rng

	var area_factor := (interior.x * interior.y) / (MapData.CHAMBER_SIZE.x * MapData.CHAMBER_SIZE.y)
	var wave_count := force_waves if force_waves > 0 else clampi(roundi(1.0 + area_factor), 2, 4)
	# Floored at the wave count, not at 3: every wave hands out at least one
	# enemy, so a budget below the count silently inflates itself anyway and the
	# total stops describing what actually spawns.
	var total := clampi(roundi((3 + depth) * area_factor * budget_mult), wave_count, 20)

	# Weighted 1:2:3:... so later waves are heavier, then hand the rounding
	# leftovers to the final wave rather than smearing them.
	var weight_sum := wave_count * (wave_count + 1) / 2
	var handed_out := 0
	for i in wave_count:
		var n := maxi(1, roundi(float(total) * float(i + 1) / float(weight_sum)))
		if i == wave_count - 1:
			n = maxi(1, total - handed_out)
		handed_out += n
		_pending_waves.append(n)


## Places the next wave's markers. The enemies themselves arrive when each
## marker expires.
func _begin_next_wave() -> void:
	if _pending_waves.is_empty():
		return
	var count: int = _pending_waves.pop_front()
	for i in count:
		_place_marker(_spawn_position())


func _place_marker(pos: Vector2, for_rampage: bool = false) -> void:
	var m := SpawnMarker.new()
	m.position = pos
	if for_rampage:
		m.lead = RAMPAGE_MARKER_LEAD
		m.tint = Color(0.92, 0.96, 1.0)
		m.expired.connect(_on_rampage_marker_expired)
	else:
		# Mostly the warning colour, with a trace of the room so it still belongs
		# to the organ. Straight part_color came out as dim floor-coloured smudge.
		m.tint = part_color.lerp(Color(1.0, 0.35, 0.25), 0.8).lightened(0.15)
		m.expired.connect(_on_marker_expired)
	add_child(m)
	_markers.append(m)


# --- rampage ---

## Switches the room over to the endgame. Nothing about this room can be
## "cleared" any more: the doors are forced open and stay open, because the
## rampage is a chase and a locked door during a chase is just a death.
func set_rampage(active: bool) -> void:
	if rampage == active:
		return
	rampage = active
	if not active:
		return
	_combat_active = false
	_set_doors_locked(false)
	# Half an interval of grace on arrival, so walking through a door is not
	# immediately walking into a spawn.
	_rampage_timer = rampage_interval * 0.5


## Distance a freshly placed exit portal must keep from the player. Escaping is
## the end of the run, so it has to be walked into on purpose -- a portal that
## materialises under someone standing still ends their run for them.
const PORTAL_CLEARANCE: float = 260.0


## Puts this room's way out of the body on the floor. Off centre, because a
## boss room and a cache room both already have something standing there, and
## offset along whichever axis the room is long on -- a third of the way down a
## 440-tall lane is close enough to the middle to be standing on.
func add_exit_portal(exit_label: String) -> void:
	var p := ExitPortal.new()
	p.label = exit_label
	p.position = _portal_position()
	p.entered.connect(func() -> void: escaped.emit())
	add_child(p)


func _portal_position() -> Vector2:
	var horizontal := interior.x >= interior.y
	var near := Vector2(interior.x * 0.32, interior.y * 0.5) if horizontal \
		else Vector2(interior.x * 0.5, interior.y * 0.32)
	var far := Vector2(interior.x - near.x, interior.y * 0.5) if horizontal \
		else Vector2(interior.x * 0.5, interior.y - near.y)

	if not is_inside_tree():
		return near
	var player := get_tree().get_first_node_in_group(&"player_body") as Node2D
	if player == null:
		return near
	var here := to_local(player.global_position)
	if here.distance_to(near) >= PORTAL_CLEARANCE:
		return near
	# Both ends crowded means a room too small to keep away in. Take the far one:
	# it is still the better of the two.
	return far


func _tick_rampage(delta: float) -> void:
	_rampage_timer -= delta
	if _rampage_timer > 0.0:
		return
	_rampage_timer = maxf(rampage_interval, 0.1)

	# Hard ceiling on what one room may hold. The interval keeps shrinking for
	# the whole rampage, so without this a player who stops moving eventually
	# meets a room that is solid white cells and a frame rate to match.
	# Not filter(): it returns an untyped Array, which cannot be assigned back to
	# an Array[Node] at runtime.
	var alive: Array[Node] = []
	for n in _rampage_live:
		if is_instance_valid(n):
			alive.append(n)
	_rampage_live = alive
	if _rampage_live.size() >= RAMPAGE_LIVE_CAP:
		return

	for i in maxi(rampage_batch, 1):
		_place_marker(_spawn_position(), true)


func _on_rampage_marker_expired(marker: SpawnMarker) -> void:
	_markers.erase(marker)
	var e := WBC_SCENE.instantiate() as Enemy
	e.position = marker.position
	add_child(e)
	_rampage_live.append(e)


func _on_marker_expired(marker: SpawnMarker) -> void:
	_markers.erase(marker)
	var e := _make_enemy(_roll_row())
	e.position = marker.position
	add_child(e)
	_live.append(e)


## Picks what this spawn is. Ordinary draw from the bestiary, with a chance of
## the local specialist wherever one belongs.
##
## The roll happens HERE rather than in the wave plan, so a room's specialists
## are spread through its waves instead of arriving as a block -- and so a room
## that qualifies for one is never guaranteed to be all of them.
func _roll_row() -> Dictionary:
	var can_chance := 0.0
	if CAN_HOME.has(part_id):
		can_chance = CAN_CHANCE_HOME
	elif DIGESTIVE_PARTS.has(part_id):
		can_chance = CAN_CHANCE_TRACT
	if can_chance > 0.0 and _rng.randf() < can_chance:
		return CAN_ROW

	# The rectum is the one room that is ABOUT the cans -- two in five spawns --
	# so nothing else strange goes in it. Further up the tract they are only an
	# occasional hazard, and shutting the scientists out of eight organs on the
	# strength of a one-in-eight roll would cost more than it protects.
	if not CAN_HOME.has(part_id) and _rng.randf() < SCIENTIST_CHANCE:
		return SCIENTIST_ROW
	return _ordinary_row()


func _ordinary_row() -> Dictionary:
	return BESTIARY[_rng.randi_range(0, BESTIARY.size() - 1)]


## Builds one creature from a bestiary row. Every row goes through here, so the
## depth scaling and the shared defaults exist once -- a new creature is a row,
## never a new branch at the spawn site.
func _make_enemy(row: Dictionary) -> Enemy:
	var e := ENEMY_SCENE.instantiate() as Enemy
	e.behavior = row["behavior"]
	e.max_health = (12.0 + _wave_depth * 3.0) * float(row.get("health", 1.0))
	e.move_speed *= float(row.get("speed", 1.0))
	e.contact_damage *= float(row.get("contact", 1.0))
	e.is_large = bool(row.get("large", false))
	if row.has("tint"):
		e.body_color = row["tint"]
	if row.has("glow"):
		e.glow_color = row["glow"]
		e.glow_amount = float(row.get("glow_amount", 0.5))
	# Set before the art: set_art re-measures the hitbox off the scaled sprite,
	# and the scale comes from this.
	#
	# The ceiling keeps the player the biggest thing in any room he can win, so
	# `tall` is how a row says it is deliberately not one of the things that rule
	# is about. Exactly two use it, and both for the same reason: their SIZE is
	# the read. The can is an object that got in and is bigger than he is; the
	# scientist is his own silhouette, which only lands if it is his height.
	var height := float(row.get("height", e.sprite_height))
	e.sprite_height = height if row.get("tall", false) else minf(height, ENEMY_MAX_HEIGHT)
	e.art_facing = float(row.get("faces", -1.0))
	if row.get("can", false):
		# Drawn, not textured. Proportioned off the row's height so the one
		# number still controls how big it is.
		e.can_size = Vector2(height * 0.45, height)
	e.set_art(row["art"])
	if row.get("spits", false):
		e.shot_stats = SPIT_STATS
	if row.get("darts", false):
		e.shot_stats = DART_STATS
		# Fires often and badly. The threat is the number of darts in the air,
		# so the interval is well under the spitter's.
		e.shot_interval = 0.85
		e.shot_range = 460.0
	return e


## Lays a puff of propellant on the floor, in room space. Routed through the room
## rather than spawned by the can itself, for the same reason blood and DNA are:
## the thing that dropped it is a creature that can die mid-trail, and a hazard
## parented to a corpse goes with it.
func drop_fumes(where: Vector2, life: float) -> void:
	var cloud := FumeCloud.new()
	cloud.lifetime = life
	cloud.position = where
	add_child(cloud)


## Puts a pool of something's blood on this floor, permanently. `where` is in
## room space, which is what a creature's own `position` already is.
##
## The only way anything bleeds. Everything that dies routes through here rather
## than spawning its own decal node, so the run's record of a room is one list in
## one place and cannot be half-persisted.
func spill_blood(where: Vector2, color: Color, size: float) -> void:
	if _blood == null:
		return
	_blood.add_splat(where, color, size)


## Same, for anything that is not a child of the room -- the player lives beside
## it in the scene, not inside it.
func spill_blood_global(where: Vector2, color: Color, size: float) -> void:
	spill_blood(to_local(where), color, size)


## Drops DNA on this floor, where it stays until it is walked over. Room-local,
## like spill_blood, and with the same global-space twin.
func drop_dna(where: Vector2, value: int) -> void:
	if _dna == null:
		return
	_dna.drop(where, value)


func drop_dna_global(where: Vector2, value: int) -> void:
	drop_dna(to_local(where), value)


## Somewhere legal to put a marker: inside the margins, out of the cover blocks,
## and not on top of the player -- the marker is a warning, but a warning you
## are already standing in is just damage.
func _spawn_position() -> Vector2:
	# Margins have to scale now: a lane is 440 across, and a fixed 180 inset
	# would leave a strip barely wider than the enemy to spawn in.
	var margin := Vector2(
		minf(180.0, interior.x * 0.25),
		minf(140.0, interior.y * 0.25)
	)
	var keep_clear: Array[Vector2] = []
	if _entry_link != "":
		keep_clear.append(entry_point_for_link(_entry_link))
	# Guarded on the tree, not just on the result: MapData and Room are meant to
	# be inspectable headlessly, and tools/test_floor.gd builds rooms that are
	# not in any tree at all. get_tree() on a detached node is an error, not null.
	if is_inside_tree():
		var player := get_tree().get_first_node_in_group(&"player_body") as Node2D
		if player != null:
			keep_clear.append(to_local(player.global_position))

	var pos := interior * 0.5
	for attempt in 16:
		pos = Vector2(
			_rng.randf_range(margin.x, interior.x - margin.x),
			_rng.randf_range(margin.y, interior.y - margin.y)
		)
		if _inside_obstacle(pos, 40.0):
			continue
		# The rectangle is no longer the room. A marker outside the boundary
		# spawns an enemy in the wall.
		if not has_clearance(pos, 60.0):
			continue
		var too_close := false
		for p in keep_clear:
			if pos.distance_to(p) < 200.0:
				too_close = true
				break
		if too_close:
			continue
		# Two markers on the same tile look like one, and the pair of enemies
		# shove each other out of the room's geometry on arrival.
		var overlaps := false
		for m in _markers:
			if pos.distance_to(m.position) < SpawnMarker.RADIUS * 2.0:
				overlaps = true
				break
		if not overlaps:
			break
	return pos


func _inside_obstacle(point: Vector2, pad: float) -> bool:
	for r in _obstacles:
		if r.grow(pad).has_point(point):
			return true
	return false


func _spawn_boss(kind: MapData.BossKind) -> void:
	# Survivable rather than fatal on an unknown kind: a room that is marked BOSS
	# and cannot name its occupant should still be a fight, or the run is
	# unfinishable for a reason nobody can see.
	if not BOSS_SCENES.has(kind):
		push_warning("Room '%s': no scene for boss kind %d, falling back to the worm."
			% [part_id, kind])
		kind = MapData.BossKind.WORM
	var b := (BOSS_SCENES[kind] as PackedScene).instantiate() as Node2D
	b.position = interior * 0.5
	add_child(b)
	_live.append(b)


## Lays the cache's offer out as one pedestal per item, spread either side of
## the room's centre, and wires them so taking any one of them retracts the
## rest. The player gets exactly one.
##
## Still no menu, for the same reason Pedestal has none: walking into the one
## you want IS the choice. The only thing that changed is that there are now two
## things to walk into.
## Raises a held cache's pedestals, once. Cleared before spawning rather than
## after, so a pedestal that emits on the same frame it is built cannot re-enter
## here and lay the offer down twice.
func _release_offer() -> void:
	if _pending_offer.is_empty():
		return
	var items := _pending_offer
	_pending_offer = []
	_spawn_offer(items)


func _spawn_offer(items: Array) -> void:
	var offer: Array[Pedestal] = []
	for i in items.size():
		var item := items[i] as Item
		if item == null:
			continue
		var p := Pedestal.new()
		p.item = item
		# Centred as a group whatever the count, so a one-item cache still sits
		# on the middle of the floor instead of off to one side.
		var spread := PEDESTAL_SPACING * (float(i) - (items.size() - 1) * 0.5)
		p.position = interior * 0.5 + Vector2(spread, 0.0)
		offer.append(p)
		add_child(p)

	for p in offer:
		p.taken.connect(func(it: Item) -> void:
			for other in offer:
				if other != p and is_instance_valid(other):
					other.retract()
			item_taken.emit(it)
		)


# --- hazards ---

## One room, one hazard, decided by where in the body it is. Placed on every
## visit rather than remembered: a hazard is scenery, not progress, and the
## seeded rng means a given room lays its pools out the same way every time.
func _build_hazards(rng: RandomNumberGenerator) -> void:
	if ACID_PARTS.has(part_id):
		_build_acid(rng)
	elif MOLD_PARTS.has(part_id):
		_build_mold(rng)
	elif region == BodyPlan.Region.ARM or region == BodyPlan.Region.LEG:
		_cramp_timer = rng.randf_range(CRAMP_INTERVAL_MIN, CRAMP_INTERVAL_MAX)

	# Both of these sit OUTSIDE the chain above rather than in it. The chain
	# picks one hazard per room and the lungs already lose that contest to mold,
	# so smoke would never appear if it had to win it -- and it does not need to,
	# because it is not a hazard.
	if SMOKE_PARTS.has(part_id):
		var smoke := SmokeLayer.new()
		smoke.name = "Smoke"
		smoke.build(rng, interior)
		add_child(smoke)
	if SHOCK_PARTS.has(part_id):
		_shock_timer = rng.randf_range(SHOCK_INTERVAL_MIN, SHOCK_INTERVAL_MAX)


## Pools, kept off the doorways and off the cover. A pool across the only way in
## is not a hazard, it is a toll.
func _build_acid(rng: RandomNumberGenerator) -> void:
	var count := rng.randi_range(ACID_POOL_MIN, ACID_POOL_MAX)
	for i in count:
		var r := rng.randf_range(ACID_RADIUS_MIN, ACID_RADIUS_MAX)
		var spot := _hazard_spot(rng, r)
		if spot == Vector2.INF:
			continue
		var pool := AcidPool.new()
		pool.shape(rng, r)
		pool.position = spot
		add_child(pool)


func _build_mold(rng: RandomNumberGenerator) -> void:
	# The clumps drift, so they get the whole room to drift IN rather than a
	# spawn point each. Inset by the wall plus a body width.
	var field := Rect2(Vector2(WALL + 40.0, WALL + 40.0),
		interior - Vector2(WALL + 40.0, WALL + 40.0) * 2.0)
	for i in rng.randi_range(MOLD_MIN, MOLD_MAX):
		var m := Mold.new()
		m.bounds = field
		var spot := _hazard_spot(rng, 40.0)
		if spot == Vector2.INF:
			continue
		m.position = spot
		add_child(m)


## Somewhere a hazard can sit: inside the walls, clear of every doorway's
## approach, and clear of the cover blocks.
func _hazard_spot(rng: RandomNumberGenerator, r: float) -> Vector2:
	for attempt in 24:
		var p := Vector2(
			rng.randf_range(WALL + r, interior.x - WALL - r),
			rng.randf_range(WALL + r, interior.y - WALL - r)
		)
		var ok := has_clearance(p, r * 0.6)
		for e: Dictionary in _exits:
			if not ok:
				break
			if p.distance_to(entry_point(e["dir"], e["slot"], e["count"])) < r + DOOR_INSET:
				ok = false
				break
		if ok:
			for block in _obstacles:
				if block.grow(r * 0.5).has_point(p):
					ok = false
					break
		if ok:
			return p
	# Nowhere legal. Better a room with one pool fewer than a pool in a doorway.
	return Vector2.INF


## Cramp: a long rumble, then ONE shove, then quiet again. Deliberately a single
## impulse rather than a sustained force -- a room that pushes continuously is a
## room the player is fighting instead of the enemies in it.
func _tick_cramp(delta: float) -> void:
	if _cramp_timer <= 0.0 and _cramp_rumble <= 0.0:
		return

	if _cramp_rumble > 0.0:
		_cramp_rumble -= delta
		_cramp_shake = clampf(1.0 - _cramp_rumble / CRAMP_RUMBLE, 0.0, 1.0)
		queue_redraw()
		if _cramp_rumble <= 0.0:
			_fire_cramp()
			_cramp_shake = 0.0
			_cramp_timer = _rng.randf_range(CRAMP_INTERVAL_MIN, CRAMP_INTERVAL_MAX)
			queue_redraw()
		return

	_cramp_timer -= delta
	if _cramp_timer <= 0.0:
		_cramp_rumble = CRAMP_RUMBLE


## The brain firing off down the wrong nerve. Marks go on the floor near the
## player, and land a beat later -- see ShockStrike, which owns the whole of the
## warning and the hit.
##
## Aimed near the player rather than anywhere in the room, because a bolt that
## lands somewhere they were never standing is weather. Aimed NEAR rather than
## AT, because one that lands exactly on them is a move-or-be-hit prompt with
## only one answer.
func _tick_shock(delta: float) -> void:
	if _shock_timer <= 0.0:
		return
	_shock_timer -= delta
	if _shock_timer > 0.0:
		return
	_shock_timer = _rng.randf_range(SHOCK_INTERVAL_MIN, SHOCK_INTERVAL_MAX)

	var player := get_tree().get_first_node_in_group(&"player_body") as Node2D
	if player == null:
		return
	var at := to_local(player.global_position)
	# Nothing while he is not actually in here. A brain left ticking in an empty
	# room would have the player walk back in to a floor already full of marks.
	if not contains_world_point(player.global_position):
		return

	# Two only once there is something else to dodge as well. A pair of bolts in
	# an empty room is a puzzle; a pair during a fight is the hazard doing its job.
	var count := 1
	if _combat_active and _rng.randf() < 0.45:
		count = SHOCK_BURST_MAX

	for i in count:
		var strike := ShockStrike.new()
		strike.radius = _rng.randf_range(SHOCK_RADIUS_MIN, SHOCK_RADIUS_MAX)
		var offset := Vector2.from_angle(_rng.randf() * TAU) \
			* _rng.randf_range(SHOCK_LEAD * 0.35, SHOCK_LEAD)
		# Kept off the walls, so a bolt cannot land somewhere the only way out of
		# it is through the room's edge.
		strike.position = Vector2(
			clampf(at.x + offset.x, strike.radius, interior.x - strike.radius),
			clampf(at.y + offset.y, strike.radius, interior.y - strike.radius))
		add_child(strike)


## The shove itself. Everything with a body in the room is thrown AWAY from
## whichever wall is nearest it, hardest right up against the wall and fading
## out by CRAMP_REACH -- the muscle is contracting, so the walls are what move.
func _fire_cramp() -> void:
	var victims: Array[Node] = []
	var player := get_tree().get_first_node_in_group(&"player_body") as Node2D
	if player != null:
		victims.append(player)
	for n in get_tree().get_nodes_in_group(&"enemy_bodies"):
		victims.append(n)

	for v in victims:
		var node := v as Node2D
		if node == null or not node.has_method(&"push"):
			continue
		var local := to_local(node.global_position)
		var away := _push_from_walls(local)
		if away == Vector2.ZERO:
			continue
		node.push(away * CRAMP_PUSH)


## Whether a WORLD point is standing on this room's floor. The sibling of
## contains_point, which takes a point already in room space -- the player and
## the enemies live beside the room rather than inside it, so everything asking
## about them has a global position and nothing else.
##
## Falls to false on a room with no outline yet, where contains_point falls back
## to the interior rectangle. The difference is deliberate: an unbuilt room
## should answer "the player is not in me", and the rectangle would say yes for
## anyone standing in the neighbour it shares an edge with.
func contains_world_point(world: Vector2) -> bool:
	if _outline.is_empty():
		return false
	return Geometry2D.is_point_in_polygon(to_local(world), _outline)


## Combined push-off from all four walls at a point in room space. Summed rather
## than taken from the nearest wall alone, so a body wedged in a corner is thrown
## out diagonally instead of scraping along one side.
func _push_from_walls(local: Vector2) -> Vector2:
	var out := Vector2.ZERO
	var gaps := [
		[local.x, Vector2.RIGHT],
		[interior.x - local.x, Vector2.LEFT],
		[local.y, Vector2.DOWN],
		[interior.y - local.y, Vector2.UP],
	]
	for entry: Array in gaps:
		var gap: float = maxf(entry[0], 0.0)
		if gap >= CRAMP_REACH:
			continue
		out += (entry[1] as Vector2) * (1.0 - gap / CRAMP_REACH)
	return out.normalized() if out.length() > 0.001 else Vector2.ZERO


## Decides how this room's walls look. Drawn from the room's own seeded rng, so
## it is stable across visits and reproduces with the run seed -- a room that
## re-rolls its walls every time you walk back in reads as a different room.
##
## The two axes are rolled independently: matching north and east walls would put
## the same bundle in the corner twice, which is the one place two tiles are seen
## touching.
func _roll_wall_look(rng: RandomNumberGenerator) -> void:
	_wall_tex_h = WALL_TILES_H[rng.randi_range(0, WALL_TILES_H.size() - 1)]
	_wall_tex_v = WALL_TILES_V[rng.randi_range(0, WALL_TILES_V.size() - 1)]
	_wall_flip_h = rng.randf() < 0.5
	_wall_flip_v = rng.randf() < 0.5
	var shade := 1.0 + rng.randf_range(-WALL_SHADE_JITTER, WALL_SHADE_JITTER)
	_wall_tint = Color.WHITE.lerp(part_color.lightened(0.15), WALL_TINT_STRENGTH) * shade
	_wall_tint.a = 1.0


## The walls, as tissue rather than as a line. Painted from the SAME segment list
## the collision was built from, so the art has a gap exactly where the doorway
## is and nowhere else.
##
## Each segment is filled with its side's tile, repeating along the wall. The
## tile is scaled so its short axis lands exactly on WALL_VISUAL -- fitting it by
## stretching instead would make a long wall's fibres thinner than a short one's,
## and two rooms would not look like the same body.
func _draw_walls() -> void:
	if _outline.is_empty() or _wall_tex_h == null or _wall_tex_v == null:
		return

	var count := _outline.size()
	var normals := _vertex_normals()
	_wall_upright = false

	# Arc length accumulated around the whole loop, so the texture keeps one
	# constant pitch through every curve. Measuring per quad instead would
	# stretch the fibres wherever the boundary bends, which is exactly where the
	# eye is looking.
	var run := 0.0
	for i in count:
		var j := (i + 1) % count
		var a := _outline[i]
		var b := _outline[j]
		var length := a.distance_to(b)
		if length <= 0.001:
			continue

		# Doorways are holes in the art as well as in the collision, and both
		# read the same flags.
		if _outline_door[i] == 1 or _outline_door[j] == 1:
			run += length
			continue

		var along := (b - a) / length
		# Hysteresis on the tile choice: a bare "which axis is bigger" test flips
		# back and forth every few samples as an arc passes 45 degrees, and tiles
		# the corner as alternating strips of two different materials. The wall
		# only changes tile once one axis clearly dominates.
		if absf(along.y) > absf(along.x) * ORIENT_HYSTERESIS:
			_wall_upright = true
		elif absf(along.x) > absf(along.y) * ORIENT_HYSTERESIS:
			_wall_upright = false
		var upright := _wall_upright
		var tex := _wall_tex_v if upright else _wall_tex_h
		# Which way round the tile is used: it wraps along its width when laid
		# horizontally and along its height when laid vertically.
		var tile_along := float(tex.get_height() if upright else tex.get_width())
		var tile_across := float(tex.get_width() if upright else tex.get_height())
		var flip := _wall_flip_v if upright else _wall_flip_h

		# MITRED to the shared vertex normals, so consecutive quads meet on
		# exactly the same outer point. Offsetting each quad by its own edge
		# normal instead leaves a wedge of empty floor at every bend -- which on a
		# rounded corner is most of it, and the wall comes out as a ring of loose
		# planks with daylight between them.
		var outer_a := a + normals[i] * WALL_VISUAL
		var outer_b := b + normals[j] * WALL_VISUAL
		# A tight concave turn can mitre the two outer points past each other,
		# which folds the quad into a bow tie and fails to triangulate. Falling
		# back to the plain edge normal there costs a hairline seam nobody sees.
		if (outer_b - outer_a).dot(along) <= 0.0:
			var edge_normal := _outward(along)
			outer_a = a + edge_normal * WALL_VISUAL
			outer_b = b + edge_normal * WALL_VISUAL

		# UVs are NORMALISED: 1.0 is one whole tile, not one texel. One tile
		# covers `tile_along * (WALL_VISUAL / tile_across)` world pixels -- the
		# length it comes out at once it has been scaled to the wall's thickness.
		var pitch := tile_along * (WALL_VISUAL / tile_across)
		var u0 := run / pitch
		var u1 := (run + length) / pitch
		var v0 := 1.0 if flip else 0.0
		var v1 := 0.0 if flip else 1.0

		# Inner edge first, then outer, wound the same way as the quad's points.
		var uvs := PackedVector2Array()
		if upright:
			uvs = PackedVector2Array([
				Vector2(v0, u0), Vector2(v0, u1), Vector2(v1, u1), Vector2(v1, u0),
			])
		else:
			uvs = PackedVector2Array([
				Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1),
			])

		draw_polygon(
			PackedVector2Array([a, b, outer_b, outer_a]),
			PackedColorArray([_wall_tint, _wall_tint, _wall_tint, _wall_tint]),
			uvs, tex)
		run += length


## Outward normal at every outline point: the average of the two edges meeting
## there, lengthened so a mitred corner stays WALL_VISUAL thick around the bend
## rather than pinching in.
##
## Shared between neighbouring quads, which is the whole point -- both sides of a
## vertex have to arrive at the same outer coordinate or the wall opens up.
func _vertex_normals() -> PackedVector2Array:
	var count := _outline.size()
	var out := PackedVector2Array()
	for i in count:
		var prev := _outline[(i - 1 + count) % count]
		var here := _outline[i]
		var next := _outline[(i + 1) % count]

		var n_in := _outward((here - prev).normalized())
		var n_out := _outward((next - here).normalized())
		var n := (n_in + n_out)
		if n.length_squared() < 0.0001:
			n = n_out
		n = n.normalized()

		# Miter length. Capped, because at a near-reversal the exact factor goes
		# to infinity and would fling the outer edge across the room.
		var cosine := maxf(n.dot(n_out), 0.35)
		out.append(n / cosine)
	return out


## Which side of an edge is out of the room. The outline is walked clockwise
## around the rectangle in screen space (y down), so the outside is consistently
## one side of the direction of travel -- but it is derived rather than assumed,
## because a deformed boundary can locally reverse.
func _outward(along: Vector2) -> Vector2:
	return Vector2(along.y, -along.x).normalized()


## Mean colour of a texture, measured once per texture and cached for the
## process. Measured rather than hand-picked so that replacing the artwork moves
## the floor colour with it -- a floor tint copied off the old picture by eye is
## a thing that silently stops matching.
##
## Sampled on a grid instead of every pixel: a 1366x768 image is a million reads
## in GDScript, and 64x64 lands within a rounding error of the true mean.
static var _avg_cache: Dictionary = {}

static func _average_color(tex: Texture2D) -> Color:
	var key := tex.resource_path
	if _avg_cache.has(key):
		return _avg_cache[key]

	var img := tex.get_image()
	var avg := Color(0.5, 0.4, 0.4)
	if img != null and img.get_width() > 0 and img.get_height() > 0:
		var steps := 64
		var sum := Vector3.ZERO
		var taken := 0
		for iy in steps:
			for ix in steps:
				var px := img.get_pixel(
					int(float(ix) / steps * img.get_width()),
					int(float(iy) / steps * img.get_height())
				)
				# Transparent padding would drag the mean toward black without
				# ever being seen.
				if px.a < 0.5:
					continue
				sum += Vector3(px.r, px.g, px.b)
				taken += 1
		if taken > 0:
			sum /= float(taken)
			avg = Color(sum.x, sum.y, sum.z)
	_avg_cache[key] = avg
	return avg


## The picture behind this room, if it has one. One lookup for every user, so
## the floor tint and the backdrop can never disagree about which room this is.
func _backdrop_texture() -> Texture2D:
	if MUSCLE_PARTS.has(part_id):
		return MUSCLE_BACKDROP
	if BONE_PARTS.has(part_id):
		return BONE_BACKDROP
	if DIGESTIVE_PARTS.has(part_id):
		return DIGESTIVE_BACKDROP
	return null


## Photographic surround. It sits BEHIND and BEYOND the room -- the floor is
## painted over the middle of it -- so what the player sees outside the walls is
## the flesh this corridor was cut through, not empty black.
##
## Overscanned well past the interior because the camera follows the player
## inside long rooms and the backdrop has to still cover the frame at either
## end. Drawn to FILL rather than tiled: the seam of a repeated photograph reads
## as a mistake in a way that a stretched one does not, and a lane's stretch runs
## along the muscle fibres, which is the direction stretching muscle is
## invisible in.
func _draw_backdrop() -> void:
	var tex := _backdrop_texture()
	if tex == null:
		return
	var margin := interior * BACKDROP_OVERSCAN
	var rect := Rect2(-margin, interior + margin * 2.0)
	var dim := Color(BACKDROP_DIM, BACKDROP_DIM, BACKDROP_DIM, 1.0)
	draw_texture_rect(tex, rect, false, dim)
	draw_rect(rect, BACKDROP_WASH)


## The room's light: one soft source over the middle of the floor, falling off
## into the corners. Built once as a radial gradient and stretched over whatever
## the room's footprint is, so a lane and a cavern are lit by the same rule.
##
## A texture rather than a Light2D. Lights would mean every drawn thing needs a
## normal map and a light mask to look right, and everything here is flat art on
## a flat floor -- the gradient buys the same read for none of that.
static var _vignette: GradientTexture2D = null
static var _glow: GradientTexture2D = null

## Clear in the middle, dark at the rim. Three stops, not two: a straight ramp
## from the centre darkens the ground the player is standing on, and the lit
## pool has to stay flat before it starts falling away.
static func _vignette_texture() -> GradientTexture2D:
	if _vignette == null:
		_vignette = _radial(
			PackedFloat32Array([0.0, 0.45, 1.0]),
			PackedColorArray([
				Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.62),
			]))
	return _vignette


## The other way round: solid at the centre, gone by the rim. Drawn white so the
## modulate carries the colour -- one texture serves every organ.
static func _glow_texture() -> GradientTexture2D:
	if _glow == null:
		_glow = _radial(
			PackedFloat32Array([0.0, 0.55, 1.0]),
			PackedColorArray([
				Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.0),
			]))
	return _glow


static func _radial(offsets: PackedFloat32Array, colors: PackedColorArray) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.offsets = offsets
	grad.colors = colors
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex


## Ambient pass, over the floor and under everything that stands on it. Two
## layers: a warm wash in the part's own colour, which is the light the organ
## gives off, and the vignette, which is the dark it does not reach.
func _draw_ambient() -> void:
	var glow := part_color.lerp(Color(1.0, 0.85, 0.7), 0.35)
	glow.a = AMBIENT_GLOW
	# Pulled toward the light source, so the bright side of the room is the side
	# the shadows point away from.
	# Both passes are drawn as the room's own polygon with the gradient mapped
	# across its bounding box. Drawn as rectangles they would spill light and
	# shadow out over the walls, which sit outside the floor now.
	var bounds := Rect2(Vector2.ZERO, interior)
	var pool := bounds.grow(-40.0)
	pool.position -= Lighting.DIRECTION * 40.0
	_draw_gradient_polygon(_glow_texture(), pool, glow)
	# Vignette last and always: it is the falloff, and anything drawn into the
	# corners after it would be brighter than the middle of the room.
	_draw_gradient_polygon(_vignette_texture(), bounds, Color(0.02, 0.01, 0.02, 1.0))


## Paints a gradient over the room's floor, stretched across `frame`. The UVs are
## in texture pixels, so the gradient's own 256x256 is mapped onto whatever the
## frame is regardless of the room's size or shape.
func _draw_gradient_polygon(tex: Texture2D, frame: Rect2, tint: Color) -> void:
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var size := tex.get_size()
	for p in _outline:
		var t := (p - frame.position) / frame.size
		uvs.append(t * size)
		colors.append(tint)
	draw_polygon(_outline, colors, uvs, tex)


## The rumble, drawn as a band of tensing muscle creeping in from all four
## walls. It thickens as the cramp builds, which is what tells the player both
## THAT it is coming and how long is left -- the warning has to live in the room
## the shove comes from, not on the HUD.
func _draw_cramp() -> void:
	if _cramp_shake <= 0.0:
		return
	var band := CRAMP_REACH * 0.35 * _cramp_shake
	var flush := Color(0.95, 0.35, 0.35, 0.10 + 0.25 * _cramp_shake)
	draw_rect(Rect2(Vector2.ZERO, Vector2(interior.x, band)), flush)
	draw_rect(Rect2(Vector2(0.0, interior.y - band), Vector2(interior.x, band)), flush)
	draw_rect(Rect2(Vector2.ZERO, Vector2(band, interior.y)), flush)
	draw_rect(Rect2(Vector2(interior.x - band, 0.0), Vector2(band, interior.y)), flush)
	# Jitter on the outline: the walls themselves are shaking, and a static edge
	# under a pulsing fill reads as a light being turned up rather than as tissue
	# under tension.
	var j := 3.0 * _cramp_shake
	draw_rect(Rect2(Vector2(randf_range(-j, j), randf_range(-j, j)), interior),
		Color(0.95, 0.4, 0.4, 0.5 * _cramp_shake), false, 4.0)


## A lump of tissue filling `rect`. Deterministic from the rect itself -- no rng
## and no stored state, so it draws the same every frame without anything having
## to remember it.
func _blob_polygon(rect: Rect2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var centre := rect.get_center()
	var radii := rect.size * 0.5
	# The seed comes off the position, so two blocks the same size in different
	# places are still different lumps.
	var phase := centre.x * 0.031 + centre.y * 0.017
	for i in 14:
		var a := TAU * float(i) / 14.0
		var wobble := 1.0 + 0.13 * sin(a * 3.0 + phase) + 0.07 * sin(a * 5.0 - phase * 1.7)
		out.append(centre + Vector2(cos(a) * radii.x, sin(a) * radii.y) * wobble)
	return out


func _draw() -> void:
	if _outline.is_empty():
		return
	# Floor is the body part's own colour, dropped to near-black so enemies
	# and shots stay readable. Room identity should register in peripheral
	# vision without anyone reading the banner.
	# Backdrop first: it is the world OUTSIDE this room, so everything else is
	# painted over it.
	_draw_backdrop()
	_draw_walls()

	var floor_tint := part_color.darkened(0.82)
	if kind == MapData.RoomKind.BOSS:
		floor_tint = part_color.darkened(0.72)
	# A room with a backdrop takes its floor from the picture instead of from the
	# part colour, so the floor and the surround read as one place.
	var backdrop := _backdrop_texture()
	if backdrop != null:
		floor_tint = _average_color(backdrop).darkened(FLOOR_FROM_BACKDROP_DARKEN)
	# The floor IS the outline. Filling the rectangle instead would paint floor
	# out past the wall the player collides with.
	draw_colored_polygon(_outline, floor_tint)
	draw_polyline(_outline + PackedVector2Array([_outline[0]]),
		part_color.darkened(0.4), 3.0)
	_draw_cramp()

	# Cover reads as raised tissue: lighter than the floor, with the same outline
	# weight as the room edge so it is obviously solid rather than decoration.
	# Drawn as lumps, not blocks -- nothing in a body is a box.
	for r in _obstacles:
		# Cover stands up off the floor, so it casts like anything else does.
		Lighting.draw_shadow(self, Vector2(r.get_center().x, r.end.y - r.size.y * 0.12),
			r.size.x, 0.0, 0.8)
		var blob := _blob_polygon(r)
		draw_colored_polygon(blob, part_color.darkened(0.55))
		draw_polyline(blob + PackedVector2Array([blob[0]]),
			part_color.darkened(0.25), 3.0)

	# Light last: it falls on the floor AND on everything built into it.
	_draw_ambient()
