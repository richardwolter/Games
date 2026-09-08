## What the finds are called.
##
## Every one of them is a piece of furniture hidden in the lake, netted once, carried up the
## beach and stood in the shed. Until now they were called "Find 07", because the catalogue
## was generated straight off the sprite sheet and nobody had looked at the pictures. A
## reward the game cannot name is a reward the player cannot want.
##
## Keyed on the slicer's own piece names (tools/slice_sheets.gd, `furniture_00` upward), so
## a re-slice that renumbers the sheet renumbers these too — which is why the harness checks
## that every furniture piece still has a key rather than trusting this to stay in step.
##
## Read off assets/TopDownHouse_FurnitureState2.png in catalogue order and then corrected
## against the pictures, so these are what the art actually shows rather than what the
## slicer guessed; changing one is a one-line edit here and nothing to do with the lake.
##
## The `_r` keys at the end are the mirrored chairs. They are not on the sheet — sheets.gd
## flips their originals into the atlas at load, so they need names here the same as any
## other find.
##
## No `class_name`, for the same reason style.gd has none: consumers preload it, and a
## global class is registered into an editor-written cache that a headless tool run can find
## stale.
extends RefCounted

const TITLES := {
	"furniture_00": "Side table",
	"furniture_01": "Side stool",
	"furniture_02": "Kitchen chair",
	"furniture_03": "Side chair",
	"furniture_04": "Carved chair",
	"furniture_05": "Carved side chair",
	"furniture_06": "Side desk",
	"furniture_07": "Corner desk",
	"furniture_08": "Back chair",
	"furniture_09": "Back carved chair",
	"furniture_11": "Round stool",
	"furniture_12": "Small table",
	"furniture_13": "Woven mat",
	"furniture_14": "Runner rug",
	"furniture_15": "Runner rug",
	"furniture_16": "Bookshelf",
	"furniture_17": "Small table",
	"furniture_18": "Oval rug",
	"furniture_19": "Side table",
	"furniture_20": "Bookcase",
	"furniture_21": "Bookcase side",
	"furniture_23": "Big rug",
	"furniture_24": "Bookcase",
	"furniture_25": "Old clock",
	"furniture_26": "Floor lamp",
	"furniture_27": "Dresser side",
	"furniture_28": "Standing mirror",
	"furniture_29": "Coat hanger",
	"furniture_30": "Dresser",
	"furniture_31": "Armchair",
	"furniture_32": "Fireplace",
	"furniture_33": "Wing chair",
	"furniture_34": "Sofa",
	"furniture_35": "Wing chair back",
	"furniture_36": "Sofa back",
	"furniture_37": "Vase of flowers",
	"furniture_38": "Stove",
	"furniture_39": "Kitchen counter",
	"furniture_40": "Kitchen corner",
	"furniture_41": "Fridge",
	"furniture_42": "Sofa",
	"furniture_43": "Kitchen rack",
	"furniture_44": "Pet bed",
	"furniture_45": "Toilet",
	"furniture_46": "Toilet sink",
	"furniture_47": "Table lamp",
	"furniture_48": "Vinyl player",
	"furniture_49": "Bathtub",
	"furniture_50": "Ironing board",
	"furniture_03_r": "Side chair",
	"furniture_05_r": "Carved side chair",
}


## The name, or an empty string for a piece nobody has named yet.
##
## Empty rather than a made-up placeholder on purpose: every screen that shows a find checks
## for it and draws the picture alone, which reads as an object. "Find 07" read as a bug.
static func of(piece: String) -> String:
	return String(TITLES.get(piece, ""))
