## Data definition for one type of bridge-building junk.
## Everything the spawner needs to build a BridgeObject lives here, so adding a
## new object type is just a new .tres file.
class_name ObjectDef
extends Resource

@export var display_name: String = "Object"

## What class of salvage this is, and with it what a bridge made of it costs on
## the leaderboard: 10 points for bronze, 20 silver, 30 gold, 40 deluxe.
##
## The tier is the level a piece is unlocked at, which is also the booster tier
## that can roll it — junk you have had since level 1 is bronze, and the girder
## and the container you only see on level 4 are deluxe. That keeps the scoring
## honest about what it is measuring: a crossing built from four girders is a
## richer solution than one built from four planks, and the leaderboard should
## say so even though both used four pieces.
enum Tier { BRONZE, SILVER, GOLD, DELUXE }
@export var tier: Tier = Tier.BRONZE

## "box" uses size as width/height. "circle" uses size.x as the diameter.
## "polygon" uses size as the box the outline is stretched to fill.
@export_enum("box", "circle", "polygon") var shape: String = "box"
@export var size: Vector2 = Vector2(100, 20)

## The outline, for "polygon" pieces only. Points are in a unit box centred on
## zero — (-0.5, -0.5) is the top-left corner of `size` — so `size` alone decides
## how big the piece is and the outline never has to be retraced to resize it.
##
## Traced from the artwork rather than authored, by the tool that cuts the piece
## out (tools/make_ramp.gd). A shape that is neither a box nor a circle only earns
## its complexity if the collision actually follows the drawing: the point of the
## ramp is that the truck runs up the curve, and a rectangle around it would be a
## crate wearing a picture of a ramp.
##
## May be concave. BridgeObject decomposes it into convex parts, which is what the
## physics server needs.
@export var polygon: PackedVector2Array = PackedVector2Array()

@export var mass: float = 10.0

## Relative to neutral. 1.0 = neutrally buoyant when fully submerged,
## above 1.0 floats, below 1.0 sinks.
@export_range(0.0, 4.0, 0.05) var buoyancy: float = 1.2

@export_range(0.0, 2.0, 0.05) var friction: float = 0.8
@export_range(0.0, 1.0, 0.05) var bounce: float = 0.0

@export var color: Color = Color("c8a165")

## Artwork, stretched to fit size. Each piece picks one at random when it's
## made, so a stack of planks isn't six copies of the same drawing — some junk
## has one look, some has several. Purely cosmetic: the physics come from the
## numbers above, whatever the piece looks like.
##
## With none set, the piece is drawn as a flat coloured shape instead. color
## matters either way — the ghost tint and the shop rows use it.
@export var textures: Array[Texture2D] = []


## Which artwork a freshly made piece should wear. -1 when the def has none.
func roll_variant() -> int:
	return randi() % textures.size() if not textures.is_empty() else -1


func get_texture(variant: int) -> Texture2D:
	if variant < 0 or variant >= textures.size():
		return null
	return textures[variant]

## Shop price. Booster packs are tuned to beat this per piece, in exchange for
## not letting you choose — so keep this honest about how good the piece is.
##
## Doubles as the piece's leaderboard cost: a crossing is ranked by what the
## bridge under it was worth, lowest total winning. That means this number is now
## load-bearing twice over — pricing a strong piece too cheaply makes it both a
## bargain in the shop and a free ride up the board.
@export var price: int = 10


## Vertical extent used to work out how submerged a sample point is.
func get_height() -> float:
	return size.x if shape == "circle" else size.y


## The outline in local pixels, ready to hand to a shape or to draw. `mirrored`
## returns it flipped left-to-right, which is how a piece with a handedness — a
## ramp — faces the other way.
func polygon_points(mirrored: bool = false) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(polygon.size())
	for i in polygon.size():
		# Reversed as well as negated: mirroring a polygon reverses its winding,
		# and a convex decomposition fed clockwise points where it expects
		# counter-clockwise gives back parts that are inside out.
		var point := polygon[polygon.size() - 1 - i] if mirrored else polygon[i]
		out[i] = Vector2(-point.x if mirrored else point.x, point.y) * size
	return out


## A three-word read of what this piece is physically like, e.g.
## "long · light · floats". Derived rather than authored so it can't drift out of
## sync when the numbers are tuned — the shop is describing the actual physics.
##
## The thresholds are calibrated against the current set: a plank is 220 long and
## 8 mass, a girder is 520 and 85. They're bands, not a scale, because the player
## needs "can this span the gap and will it stay up", not two decimal places.
func descriptor() -> String:
	return "%s · %s · %s · %s" % [
		_span_word(), _weight_word(), _float_word(), _grip_word()
	]


func _span_word() -> String:
	var longest := maxf(size.x, size.y)
	if longest >= 400.0:
		return "very long"
	if longest >= 200.0:
		return "long"
	if longest >= 120.0:
		return "chunky"
	return "small"


func _weight_word() -> String:
	if mass >= 60.0:
		return "heaviest"
	if mass >= 30.0:
		return "heavy"
	if mass >= 12.0:
		return "solid"
	return "light"


func _float_word() -> String:
	# Its own band above "very buoyant", because the pontoon is meant to be the
	# piece you buy *for* its float, and a shop line that describes it the same way
	# as a barrel is not making that case.
	if buoyancy >= 3.0:
		return "unsinkable"
	if buoyancy >= 2.0:
		return "very buoyant"
	if buoyancy >= 1.3:
		return "floats"
	# Just over neutral means it wallows at the surface rather than riding on it,
	# which behaves differently enough to be worth its own word.
	if buoyancy >= 1.0:
		return "wallows"
	return "sinks"


## How well the truck's tyres bite on this. Worth its own word because friction
## is now the difference between a deck that can be driven and one that can only
## be looked at, and a player who cannot see it is choosing blind: the metal that
## spans the gap is exactly the metal that will not let the truck climb.
func _grip_word() -> String:
	if friction >= 1.4:
		return "grippy"
	if friction >= 0.85:
		return "good grip"
	if friction >= 0.5:
		return "smooth"
	return "slippery"
