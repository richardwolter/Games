## One kind of rubbish in the lake.
##
## Everything gameplay needs to know about a piece of junk lives here and not in the
## scene, so sprites can be regenerated and numbers retuned without touching code.
##
## Deliberately small. There is no physics in this game, so there is no mass, no heft,
## no buoyancy coefficient, no collision shape and no polygon decomposition to author —
## a kind of rubbish is a picture and four numbers, and adding one is a two-minute job.
class_name TrashDef
extends Resource

## What this is made of, and therefore which yard on the shore buys it. Four of them, one
## per dropoff — the ferry's whole route is decided by which of these are in its hold.
enum Kind { PLASTIC, TIMBER, METAL, RUBBER }

## The four, in enum order, for anything that needs to name one.
const KIND_NAMES := ["Plastic", "Timber", "Metal", "Rubber"]

@export var display_name: String = "Bottle"

## Which of the four dropoffs takes it.
@export var material: Kind = Kind.PLASTIC

## Optional. With no texture the piece draws as a flat blocked-in quad, which is what
## the prototype runs on until the generated sprites land.
@export var sprite: Texture2D

## The piece of art this is, as a name in the sliced catalogue, and where that name lands
## in the shared atlas. Both are filled in by lake.gd when the art loads; with no atlas the
## piece falls back to the blocked-in quad, so the game still runs with assets/ missing.
@export var piece: StringName = &""
var atlas: Texture2D
var region := Rect2()

## True for the one-off finds: furniture, a single instance of each hidden in the lake,
## which is kept and put in the shed rather than sold.
@export var keepsake: bool = false

## Drawn size. Sprites are scaled to it rather than the other way round, so a regenerated
## sprite at a different pixel size does not change how the piece reads.
@export var size: Vector2 = Vector2(18.0, 20.0)

## How much of the lake's filth this piece accounts for. Arbitrary units — the meter is
## normalised against the total the lake was built with.
@export var pollution: float = 1.0

## Seconds of hauling at rate 1.0. This is the number that replaced mass: a cup comes out
## instantly, a fridge is a commitment.
@export var haul_cost: float = 0.4

## Minimum carry-strength level, or boat net power, needed to shift it at all.
@export var tier: int = 0

## Where it settles in the heap. Higher floats nearer the surface; this is the only thing
## the old buoyancy number is still doing, and it is a sort key rather than a force.
@export var lightness: float = 1.6

## Placeholder fill, used only while sprite is null.
@export var block_color: Color = Color(0.78, 0.74, 0.66)


func get_height() -> float:
	return size.y


## Draw this piece in local space onto whichever canvas is mid-`_draw`. The caller sets
## the transform, so one call serves the heap, the boat's hold, and anything else that
## needs to show a piece.
func stamp(canvas: CanvasItem, tint: Color = Color.WHITE) -> void:
	var rect := Rect2(-size * 0.5, size)
	if atlas != null:
		canvas.draw_texture_rect_region(atlas, rect, region, tint)
		return
	if sprite != null:
		canvas.draw_texture_rect(sprite, rect, false, tint)
		return
	canvas.draw_rect(rect, block_color * tint)
	# Near-black outline, so placeholder junk still separates from the water the way the
	# finished sprites are meant to.
	canvas.draw_rect(rect, Color(0.11, 0.09, 0.1, tint.a), false, 1.5)


## Draw this piece as it looks floating on an isometric surface: a squashed body sitting
## in a flat diamond of disturbed water.
##
## The squash is the whole trick. A picture drawn upright on a plane seen at an angle is
## the one thing that reads as pasted-on, so the body is compressed to the same 2:1 ratio
## the tiles use and given a footprint that lies flat in it.
func stamp_iso(canvas: CanvasItem, tint: Color = Color.WHITE) -> void:
	var footprint := Vector2(size.x * 1.15, size.x * 1.15 * 0.5)
	# The waterline the piece displaces. Drawn first, so the body stands in it.
	_diamond(canvas, Vector2(0.0, size.y * 0.18), footprint, Color(1.0, 1.0, 1.0, 0.14 * tint.a))

	# Art is drawn upright and read as standing in the water rather than lying on it, so
	# unlike the blocked-in placeholder it is not squashed to the plane's ratio.
	if atlas != null:
		canvas.draw_texture_rect_region(
			atlas, Rect2(-size * 0.5, size), region, tint
		)
		return

	var body := Vector2(size.x, size.y * 0.72)
	var rect := Rect2(-body * 0.5, body)
	if sprite != null:
		canvas.draw_texture_rect(sprite, rect, false, tint)
		return
	canvas.draw_rect(rect, block_color * tint)
	# A darker top face, so the block has a direction on the plane rather than being a
	# floating square.
	canvas.draw_rect(
		Rect2(rect.position, Vector2(body.x, body.y * 0.35)), block_color.lightened(0.18) * tint
	)
	canvas.draw_rect(rect, Color(0.11, 0.09, 0.1, tint.a), false, 1.5)


func _diamond(canvas: CanvasItem, at: Vector2, extent: Vector2, colour: Color) -> void:
	canvas.draw_colored_polygon(
		PackedVector2Array([
			at + Vector2(0.0, -extent.y * 0.5), at + Vector2(extent.x * 0.5, 0.0),
			at + Vector2(0.0, extent.y * 0.5), at + Vector2(-extent.x * 0.5, 0.0)
		]),
		colour
	)
