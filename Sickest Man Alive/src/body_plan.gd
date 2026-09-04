class_name BodyPlan
extends RefCounted

## The uncle, as a graph with a drawing attached. Three separate facts:
##
##   LINKS  what connects to what, and which wall the door sits on. This is the
##          anatomy. Nothing infers it.
##   PARTS  what each room IS -- name, region, colour.
##   cell   where the room sits on the minimap. Layout only. Never read to work
##          out where a door leads.
##
## Adjacency used to be implicit in the cells, which was elegant right up until
## a room needed two doors on one wall going to two different places. A fork
## cannot be expressed as "the cell to my west", so the edge list is written out.
##
## Adding a part is a row in PARTS plus at least one row in LINKS. A part with
## no link is an unreachable room and the floor test says so.

enum Region { HEAD, TORSO, ARM, LEG, CORE_ORGAN }

## What is waiting on the other side of a door, in the vaguest terms that are
## still worth knowing. Drawn as a pip on fork doors, where the player is being
## asked to choose blind otherwise.
enum Hint { NONE, COMBAT, CACHE, HAZARD }

## How a part plays, as opposed to what it is.
##
## CHAMBER  the default box.
## LANE     long and narrow, walked end to end. Limbs are chains with one way in
##          and one way out, so a square room makes them feel like filler; a lane
##          makes the walk out of an arm read as the journey it is.
## CAVERN   large and broken up with cover. Organs are the destinations.
enum RoomShape { CHAMBER, LANE, CAVERN }

## Parts whose shape does not follow from their region.
const LANE_OVERRIDES: PackedStringArray = []

## Joints and junctions. A limb segment is a lane, but the shoulder, elbow and
## hand it runs between are where the fork doors live, and two doorways will not
## fit across the 440 short end of a lane. Making the joints boxes is also the
## honest read: a forearm is a corridor, an elbow is a place where things meet.
const CHAMBER_OVERRIDES: PackedStringArray = [
	"l_shoulder", "r_shoulder", "l_elbow", "r_elbow", "l_hand", "r_hand",
	"l_hip", "r_hip", "l_knee", "r_knee", "l_foot", "r_foot",
]


static func shape_of(id: String) -> RoomShape:
	if LANE_OVERRIDES.has(id):
		return RoomShape.LANE
	if CHAMBER_OVERRIDES.has(id):
		return RoomShape.CHAMBER
	match PARTS[id]["region"] as Region:
		Region.ARM, Region.LEG:
			return RoomShape.LANE
		Region.CORE_ORGAN:
			return RoomShape.CAVERN
		_:
			return RoomShape.CHAMBER

## id -> {name, cell, region, color}
##
## `cell` is where the room is DRAWN on the minimap and nothing else. Spine parts
## sit on x = 0 and step by two; the two halves of a fork sit one cell either
## side, between them. The body reads as a silhouette that thickens where there
## is a choice to make.
const PARTS: Dictionary = {
	# --- throat, upward from the sternum ---
	"neck_base":    {"name": "Base of Throat",  "cell": Vector2i(0, -5),  "region": Region.HEAD,  "color": Color(0.66, 0.44, 0.44)},
	"trachea":      {"name": "Trachea",         "cell": Vector2i(-1, -6), "region": Region.HEAD,  "color": Color(0.70, 0.52, 0.50)},
	"thyroid":      {"name": "Thyroid",         "cell": Vector2i(1, -6),  "region": Region.HEAD,  "color": Color(0.62, 0.40, 0.46)},
	"larynx":       {"name": "Larynx",          "cell": Vector2i(0, -7),  "region": Region.HEAD,  "color": Color(0.68, 0.46, 0.44)},

	# --- head ---
	"mouth":        {"name": "Mouth",           "cell": Vector2i(0, -8),  "region": Region.HEAD,  "color": Color(0.74, 0.44, 0.44)},
	"tongue":       {"name": "Tongue",          "cell": Vector2i(-1, -9), "region": Region.HEAD,  "color": Color(0.78, 0.42, 0.44)},
	"nasal":        {"name": "Nasal Cavity",    "cell": Vector2i(1, -9),  "region": Region.HEAD,  "color": Color(0.70, 0.56, 0.54)},
	"sinus":        {"name": "Sinus",           "cell": Vector2i(0, -10), "region": Region.HEAD,  "color": Color(0.68, 0.60, 0.56)},
	"cranium":      {"name": "Cranium",         "cell": Vector2i(-1, -11), "region": Region.HEAD, "color": Color(0.74, 0.72, 0.64)},
	"brain":        {"name": "Brain",           "cell": Vector2i(1, -11), "region": Region.CORE_ORGAN, "color": Color(0.80, 0.68, 0.70)},
	"crown":        {"name": "Crown",           "cell": Vector2i(0, -12), "region": Region.HEAD,  "color": Color(0.72, 0.70, 0.62)},
	"l_ear":        {"name": "Left Inner Ear",  "cell": Vector2i(-1, -13), "region": Region.HEAD, "color": Color(0.66, 0.62, 0.56)},
	"r_ear":        {"name": "Right Inner Ear", "cell": Vector2i(1, -13), "region": Region.HEAD,  "color": Color(0.66, 0.62, 0.56)},
	"pineal":       {"name": "Pineal Gland",    "cell": Vector2i(0, -14), "region": Region.CORE_ORGAN, "color": Color(0.58, 0.46, 0.72)},

	# --- chest ---
	"sternum":      {"name": "Sternum",         "cell": Vector2i(0, -4),  "region": Region.TORSO, "color": Color(0.70, 0.68, 0.60)},
	"l_lung":       {"name": "Left Lung",       "cell": Vector2i(-1, -3), "region": Region.CORE_ORGAN, "color": Color(0.85, 0.55, 0.60)},
	"r_lung":       {"name": "Right Lung",      "cell": Vector2i(1, -3),  "region": Region.CORE_ORGAN, "color": Color(0.85, 0.55, 0.60)},
	"pericardium":  {"name": "Pericardium",     "cell": Vector2i(0, -2),  "region": Region.CORE_ORGAN, "color": Color(0.72, 0.30, 0.34)},
	"heart":        {"name": "Heart",           "cell": Vector2i(0, -1),  "region": Region.CORE_ORGAN, "color": Color(0.80, 0.18, 0.24)},

	# --- abdomen ---
	"diaphragm":    {"name": "Diaphragm",       "cell": Vector2i(0, 0),   "region": Region.TORSO, "color": Color(0.64, 0.44, 0.42)},
	"spleen":       {"name": "Spleen",          "cell": Vector2i(-1, 1),  "region": Region.CORE_ORGAN, "color": Color(0.50, 0.28, 0.42)},
	"pancreas":     {"name": "Pancreas",        "cell": Vector2i(1, 1),   "region": Region.CORE_ORGAN, "color": Color(0.76, 0.66, 0.44)},
	"stomach":      {"name": "Stomach",         "cell": Vector2i(0, 2),   "region": Region.CORE_ORGAN, "color": Color(0.72, 0.62, 0.30)},
	"liver":        {"name": "Liver",           "cell": Vector2i(-1, 3),  "region": Region.CORE_ORGAN, "color": Color(0.55, 0.25, 0.22)},
	"kidney":       {"name": "Right Kidney",    "cell": Vector2i(1, 3),   "region": Region.CORE_ORGAN, "color": Color(0.52, 0.30, 0.28)},
	"duodenum":     {"name": "Duodenum",        "cell": Vector2i(0, 4),   "region": Region.CORE_ORGAN, "color": Color(0.76, 0.56, 0.42)},
	"small_bowel":  {"name": "Small Intestine", "cell": Vector2i(-1, 5),  "region": Region.CORE_ORGAN, "color": Color(0.78, 0.58, 0.45)},
	"large_bowel":  {"name": "Large Intestine", "cell": Vector2i(1, 5),   "region": Region.CORE_ORGAN, "color": Color(0.70, 0.52, 0.40)},
	"gut":          {"name": "Intestines",      "cell": Vector2i(0, 6),   "region": Region.CORE_ORGAN, "color": Color(0.78, 0.58, 0.45)},
	"bladder":      {"name": "Bladder",         "cell": Vector2i(-1, 7),  "region": Region.CORE_ORGAN, "color": Color(0.72, 0.72, 0.50)},
	"rectum":       {"name": "Rectum",          "cell": Vector2i(1, 7),   "region": Region.CORE_ORGAN, "color": Color(0.60, 0.44, 0.36)},
	"pelvis":       {"name": "Pelvis",          "cell": Vector2i(0, 8),   "region": Region.TORSO, "color": Color(0.68, 0.66, 0.58)},

	# --- left arm (player's left, screen left). Bone above, muscle below. ---
	"l_shoulder":   {"name": "Left Shoulder",   "cell": Vector2i(-2, -4), "region": Region.ARM,   "color": Color(0.62, 0.42, 0.40)},
	"l_humerus":    {"name": "Left Humerus",    "cell": Vector2i(-3, -5), "region": Region.ARM,   "color": Color(0.70, 0.68, 0.60)},
	"l_biceps":     {"name": "Left Biceps",     "cell": Vector2i(-3, -3), "region": Region.ARM,   "color": Color(0.60, 0.34, 0.34)},
	"l_elbow":      {"name": "Left Elbow",      "cell": Vector2i(-4, -4), "region": Region.ARM,   "color": Color(0.64, 0.50, 0.44)},
	"l_radius":     {"name": "Left Radius",     "cell": Vector2i(-5, -5), "region": Region.ARM,   "color": Color(0.70, 0.68, 0.60)},
	"l_flexor":     {"name": "Left Forearm",    "cell": Vector2i(-5, -3), "region": Region.ARM,   "color": Color(0.58, 0.34, 0.34)},
	"l_hand":       {"name": "Left Hand",       "cell": Vector2i(-6, -4), "region": Region.ARM,   "color": Color(0.56, 0.36, 0.34)},

	# --- right arm ---
	"r_shoulder":   {"name": "Right Shoulder",  "cell": Vector2i(2, -4),  "region": Region.ARM,   "color": Color(0.62, 0.42, 0.40)},
	"r_humerus":    {"name": "Right Humerus",   "cell": Vector2i(3, -5),  "region": Region.ARM,   "color": Color(0.70, 0.68, 0.60)},
	"r_biceps":     {"name": "Right Biceps",    "cell": Vector2i(3, -3),  "region": Region.ARM,   "color": Color(0.60, 0.34, 0.34)},
	"r_elbow":      {"name": "Right Elbow",     "cell": Vector2i(4, -4),  "region": Region.ARM,   "color": Color(0.64, 0.50, 0.44)},
	"r_radius":     {"name": "Right Radius",    "cell": Vector2i(5, -5),  "region": Region.ARM,   "color": Color(0.70, 0.68, 0.60)},
	"r_flexor":     {"name": "Right Forearm",   "cell": Vector2i(5, -3),  "region": Region.ARM,   "color": Color(0.58, 0.34, 0.34)},
	"r_hand":       {"name": "Right Hand",      "cell": Vector2i(6, -4),  "region": Region.ARM,   "color": Color(0.56, 0.36, 0.34)},

	# --- left leg. Bone outboard, muscle inboard. ---
	"l_hip":        {"name": "Left Hip",        "cell": Vector2i(-2, 9),  "region": Region.LEG,   "color": Color(0.64, 0.56, 0.48)},
	"l_femur":      {"name": "Left Femur",      "cell": Vector2i(-3, 10), "region": Region.LEG,   "color": Color(0.70, 0.68, 0.60)},
	"l_quad":       {"name": "Left Quadriceps", "cell": Vector2i(-1, 10), "region": Region.LEG,   "color": Color(0.58, 0.34, 0.34)},
	"l_knee":       {"name": "Left Knee",       "cell": Vector2i(-2, 11), "region": Region.LEG,   "color": Color(0.64, 0.56, 0.48)},
	"l_tibia":      {"name": "Left Tibia",      "cell": Vector2i(-3, 12), "region": Region.LEG,   "color": Color(0.70, 0.68, 0.60)},
	"l_calf":       {"name": "Left Calf",       "cell": Vector2i(-1, 12), "region": Region.LEG,   "color": Color(0.56, 0.34, 0.34)},
	"l_foot":       {"name": "Left Foot",       "cell": Vector2i(-2, 13), "region": Region.LEG,   "color": Color(0.54, 0.36, 0.34)},

	# --- right leg ---
	"r_hip":        {"name": "Right Hip",       "cell": Vector2i(2, 9),   "region": Region.LEG,   "color": Color(0.64, 0.56, 0.48)},
	"r_femur":      {"name": "Right Femur",     "cell": Vector2i(3, 10),  "region": Region.LEG,   "color": Color(0.70, 0.68, 0.60)},
	"r_quad":       {"name": "Right Quadriceps", "cell": Vector2i(1, 10), "region": Region.LEG,   "color": Color(0.58, 0.34, 0.34)},
	"r_knee":       {"name": "Right Knee",      "cell": Vector2i(2, 11),  "region": Region.LEG,   "color": Color(0.64, 0.56, 0.48)},
	"r_tibia":      {"name": "Right Tibia",     "cell": Vector2i(3, 12),  "region": Region.LEG,   "color": Color(0.70, 0.68, 0.60)},
	"r_calf":       {"name": "Right Calf",      "cell": Vector2i(1, 12),  "region": Region.LEG,   "color": Color(0.56, 0.34, 0.34)},
	"r_foot":       {"name": "Right Foot",      "cell": Vector2i(2, 13),  "region": Region.LEG,   "color": Color(0.54, 0.36, 0.34)},
}

## Every connection in the body, written once. `a_dir` is the wall of `a` the
## doorway sits on; b's door is on the opposite wall of b.
##
## The direction is declared rather than derived from the two cells, because a
## fork's branches sit diagonally off the parent and a delta of (1, -1) does not
## name a wall. Layout and topology disagreeing is a warning in print_body, not
## a broken door.
const LINKS: Array = [
	# --- throat and head, upward from the sternum ---
	{"a": "sternum", "b": "neck_base", "a_dir": "n"},
	{"a": "neck_base", "b": "trachea", "a_dir": "n"},
	{"a": "neck_base", "b": "thyroid", "a_dir": "n"},
	{"a": "trachea", "b": "larynx", "a_dir": "n"},
	{"a": "thyroid", "b": "larynx", "a_dir": "n"},
	{"a": "larynx", "b": "mouth", "a_dir": "n"},
	{"a": "mouth", "b": "tongue", "a_dir": "n"},
	{"a": "mouth", "b": "nasal", "a_dir": "n"},
	{"a": "tongue", "b": "sinus", "a_dir": "n"},
	{"a": "nasal", "b": "sinus", "a_dir": "n"},
	{"a": "sinus", "b": "cranium", "a_dir": "n"},
	{"a": "sinus", "b": "brain", "a_dir": "n"},
	{"a": "cranium", "b": "crown", "a_dir": "n"},
	{"a": "brain", "b": "crown", "a_dir": "n"},
	{"a": "crown", "b": "l_ear", "a_dir": "n"},
	{"a": "crown", "b": "r_ear", "a_dir": "n"},
	{"a": "l_ear", "b": "pineal", "a_dir": "n"},
	{"a": "r_ear", "b": "pineal", "a_dir": "n"},

	# --- chest and abdomen, downward from the sternum ---
	{"a": "sternum", "b": "l_lung", "a_dir": "s"},
	{"a": "sternum", "b": "r_lung", "a_dir": "s"},
	{"a": "l_lung", "b": "pericardium", "a_dir": "s"},
	{"a": "r_lung", "b": "pericardium", "a_dir": "s"},
	{"a": "pericardium", "b": "heart", "a_dir": "s"},
	{"a": "heart", "b": "diaphragm", "a_dir": "s"},
	{"a": "diaphragm", "b": "spleen", "a_dir": "s"},
	{"a": "diaphragm", "b": "pancreas", "a_dir": "s"},
	{"a": "spleen", "b": "stomach", "a_dir": "s"},
	{"a": "pancreas", "b": "stomach", "a_dir": "s"},
	{"a": "stomach", "b": "liver", "a_dir": "s"},
	{"a": "stomach", "b": "kidney", "a_dir": "s"},
	{"a": "liver", "b": "duodenum", "a_dir": "s"},
	{"a": "kidney", "b": "duodenum", "a_dir": "s"},
	{"a": "duodenum", "b": "small_bowel", "a_dir": "s"},
	{"a": "duodenum", "b": "large_bowel", "a_dir": "s"},
	{"a": "small_bowel", "b": "gut", "a_dir": "s"},
	{"a": "large_bowel", "b": "gut", "a_dir": "s"},
	{"a": "gut", "b": "bladder", "a_dir": "s"},
	{"a": "gut", "b": "rectum", "a_dir": "s"},
	{"a": "bladder", "b": "pelvis", "a_dir": "s"},
	{"a": "rectum", "b": "pelvis", "a_dir": "s"},

	# --- left arm, outward from the chest ---
	{"a": "sternum", "b": "l_shoulder", "a_dir": "w"},
	{"a": "l_shoulder", "b": "l_humerus", "a_dir": "w"},
	{"a": "l_shoulder", "b": "l_biceps", "a_dir": "w"},
	{"a": "l_humerus", "b": "l_elbow", "a_dir": "w"},
	{"a": "l_biceps", "b": "l_elbow", "a_dir": "w"},
	{"a": "l_elbow", "b": "l_radius", "a_dir": "w"},
	{"a": "l_elbow", "b": "l_flexor", "a_dir": "w"},
	{"a": "l_radius", "b": "l_hand", "a_dir": "w"},
	{"a": "l_flexor", "b": "l_hand", "a_dir": "w"},

	# --- right arm ---
	{"a": "sternum", "b": "r_shoulder", "a_dir": "e"},
	{"a": "r_shoulder", "b": "r_humerus", "a_dir": "e"},
	{"a": "r_shoulder", "b": "r_biceps", "a_dir": "e"},
	{"a": "r_humerus", "b": "r_elbow", "a_dir": "e"},
	{"a": "r_biceps", "b": "r_elbow", "a_dir": "e"},
	{"a": "r_elbow", "b": "r_radius", "a_dir": "e"},
	{"a": "r_elbow", "b": "r_flexor", "a_dir": "e"},
	{"a": "r_radius", "b": "r_hand", "a_dir": "e"},
	{"a": "r_flexor", "b": "r_hand", "a_dir": "e"},

	# --- left leg, downward from the hips ---
	{"a": "pelvis", "b": "l_hip", "a_dir": "w"},
	{"a": "l_hip", "b": "l_femur", "a_dir": "s"},
	{"a": "l_hip", "b": "l_quad", "a_dir": "s"},
	{"a": "l_femur", "b": "l_knee", "a_dir": "s"},
	{"a": "l_quad", "b": "l_knee", "a_dir": "s"},
	{"a": "l_knee", "b": "l_tibia", "a_dir": "s"},
	{"a": "l_knee", "b": "l_calf", "a_dir": "s"},
	{"a": "l_tibia", "b": "l_foot", "a_dir": "s"},
	{"a": "l_calf", "b": "l_foot", "a_dir": "s"},

	# --- right leg ---
	{"a": "pelvis", "b": "r_hip", "a_dir": "e"},
	{"a": "r_hip", "b": "r_femur", "a_dir": "s"},
	{"a": "r_hip", "b": "r_quad", "a_dir": "s"},
	{"a": "r_femur", "b": "r_knee", "a_dir": "s"},
	{"a": "r_quad", "b": "r_knee", "a_dir": "s"},
	{"a": "r_knee", "b": "r_tibia", "a_dir": "s"},
	{"a": "r_knee", "b": "r_calf", "a_dir": "s"},
	{"a": "r_tibia", "b": "r_foot", "a_dir": "s"},
	{"a": "r_calf", "b": "r_foot", "a_dir": "s"},
]

## Exclusive choices. Walking into one branch seals the others for the rest of
## the run, and all of them come back together at `join`.
##
##   from      the room whose wall holds the branch doors
##   branches  the branch ENTRANCE ids, one door each
##   join      where the branches meet again
##
## Branches must be the same length as each other, so how far a room is from the
## entry wound is a fact about the body and not about a choice made three rooms
## ago. The floor test enforces it.
const FORKS: Array = [
	# --- throat and head ---
	{"from": "neck_base", "branches": ["trachea", "thyroid"], "join": "larynx"},
	{"from": "mouth", "branches": ["tongue", "nasal"], "join": "sinus"},
	{"from": "sinus", "branches": ["cranium", "brain"], "join": "crown"},
	{"from": "crown", "branches": ["l_ear", "r_ear"], "join": "pineal"},

	# --- chest and abdomen ---
	{"from": "sternum", "branches": ["l_lung", "r_lung"], "join": "pericardium"},
	{"from": "diaphragm", "branches": ["spleen", "pancreas"], "join": "stomach"},
	{"from": "stomach", "branches": ["liver", "kidney"], "join": "duodenum"},
	{"from": "duodenum", "branches": ["small_bowel", "large_bowel"], "join": "gut"},
	{"from": "gut", "branches": ["bladder", "rectum"], "join": "pelvis"},

	# --- arms: bone or muscle, twice each ---
	{"from": "l_shoulder", "branches": ["l_humerus", "l_biceps"], "join": "l_elbow"},
	{"from": "l_elbow", "branches": ["l_radius", "l_flexor"], "join": "l_hand"},
	{"from": "r_shoulder", "branches": ["r_humerus", "r_biceps"], "join": "r_elbow"},
	{"from": "r_elbow", "branches": ["r_radius", "r_flexor"], "join": "r_hand"},

	# --- legs ---
	{"from": "l_hip", "branches": ["l_femur", "l_quad"], "join": "l_knee"},
	{"from": "l_knee", "branches": ["l_tibia", "l_calf"], "join": "l_foot"},
	{"from": "r_hip", "branches": ["r_femur", "r_quad"], "join": "r_knee"},
	{"from": "r_knee", "branches": ["r_tibia", "r_calf"], "join": "r_foot"},
]

## Where the suit can get in. Two kinds, and both are extremities in the sense
## that matters -- entering at the heart would skip the entire journey the
## premise is built on.
##
## The four limb tips are punched in from outside. The rest are holes the body
## already has: you go in the way things go in. They start the run much closer to
## the head, which is the point of them -- a run from an ear is a different shape
## of run from one from a foot, and the boss placement below reacts to that
## rather than assuming everyone came from a limb.
const ENTRY_POINTS: PackedStringArray = [
	"l_hand", "r_hand", "l_foot", "r_foot",
	"rectum", "nasal", "mouth", "l_ear", "r_ear",
]

## Where the infection may nest: anywhere `is_spine` is true, and nothing else.
##
## This used to be a hand-written list of six organs, which answered the question
## by avoiding it -- and meant the boss sat in one of the same six every run,
## however far the entry wound happened to be from them. The rule underneath that
## list was only ever "must not be sealable": a boss behind a seal is a run that
## cannot be finished. Stating the rule lets the infection nest anywhere on the
## spine while keeping the guarantee, and `is_spine` already says it exactly.

## Parts that must never hold a pedestal: the entry point is decided at run
## time, and a limb tip is a dead end you would have to walk back out of.
const NO_ITEM: PackedStringArray = ["l_hand", "r_hand", "l_foot", "r_foot"]


static func cell_of(id: String) -> Vector2i:
	return PARTS[id]["cell"] as Vector2i


static func id_at(cell: Vector2i) -> String:
	for id: String in PARTS:
		if PARTS[id]["cell"] == cell:
			return id
	return ""


## A link's name, the same from either end. This is what a door is identified
## by from the moment it is built to the moment the player walks through it --
## a direction no longer says where you are going once two doors share a wall.
static func link_id(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]


static func links_of(id: String) -> Array:
	var out: Array = []
	for link: Dictionary in LINKS:
		if link["a"] == id or link["b"] == id:
			out.append(link)
	return out


## What a part connects to, ignoring which wall.
static func neighbours_of(id: String) -> Array:
	var out: Array = []
	for link: Dictionary in LINKS:
		if link["a"] == id:
			out.append(link["b"])
		elif link["b"] == id:
			out.append(link["a"])
	return out


## The fork this part is a branch entrance of, or {} if it is not one.
static func fork_for_branch(id: String) -> Dictionary:
	for fork: Dictionary in FORKS:
		if (fork["branches"] as Array).has(id):
			return fork
	return {}


## Every room inside a branch, entrance included. Flood filled with the fork's
## two ends walled off, so the fill cannot leak out into the rest of the body and
## seal half the floor.
static func branch_cells(branch_id: String) -> Array:
	var fork := fork_for_branch(branch_id)
	if fork.is_empty():
		return []
	var blocked: Dictionary = {fork["from"]: true, fork["join"]: true}
	for other: String in fork["branches"]:
		if other != branch_id:
			blocked[other] = true

	var seen: Dictionary = {branch_id: true}
	var queue: Array[String] = [branch_id]
	var out: Array = []
	while not queue.is_empty():
		var id: String = queue.pop_front()
		out.append(id)
		for n: String in neighbours_of(id):
			if blocked.has(n) or seen.has(n):
				continue
			seen[n] = true
			queue.append(n)
	return out


## True when a part is on no fork branch at all -- reachable whatever the player
## chooses. The boss and every way out of the body have to be here, or a run can
## seal its own ending away.
static func is_spine(id: String) -> bool:
	if _spine.is_empty():
		for part: String in PARTS:
			_spine[part] = true
		for fork: Dictionary in FORKS:
			for branch: String in fork["branches"]:
				for member: String in branch_cells(branch):
					_spine[member] = false
	return _spine.get(id, false)


## Computed once from FORKS. Not a const: a const cannot flood fill.
static var _spine: Dictionary = {}
