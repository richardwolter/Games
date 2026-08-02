## Birds crossing the sky behind the strait.
##
## Pure decoration: no physics, no collision, nothing else in the game can see
## them. They exist so the sky isn't a still photograph — at the zoom levels this
## game is played at, the backdrop fills half the screen and never moves.
##
## They live in world space rather than on a CanvasLayer, for the same reason the
## backdrop does: anything that re-derives its position from the camera slides
## against the terrain when you pan, and reads as unglued.
##
## Flapping is a squash, not a frame swap. The sheet has one pose per bird — all
## of them mid-glide, wings out — so there are no frames to cycle. Scaling a
## silhouette vertically about its own middle is what a distant bird's wingbeat
## actually looks like from a mile off: the wings foreshorten and the body stays
## put. At these sizes it is entirely convincing and costs one sine per bird.
class_name SkyBirds
extends Node2D

const ART_DIR := "res://art/wildlife/"
## Every bird cut from the sheet. The small ones are distant singles and the
## trio; the big ones are near the front of the flock.
const SPRITES: Array[String] = [
	"bird_1", "bird_2", "bird_3", "bird_4", "bird_5", "bird_6", "bird_7",
]
## Which of those drawings face LEFT on the sheet.
##
## Same trap the fish fell into: the flip was done against a blanket "the sprites
## face right", so the two that aren't drawn that way flew tail-first. Recorded
## per drawing rather than fixed in the .png so the art stays as delivered.
const FACES_LEFT: Array[String] = ["bird_4", "bird_7"]

## How many birds are up at once.
@export var count: int = 9
## Height of a bird on screen, in world units. Tiny on purpose: these are meant
## to read as distance, and anything big enough to identify stops being scenery
## and starts being a character.
@export var min_height: float = 14.0
@export var max_height: float = 34.0
## World units per second, left or right. Slow — a bird that crosses the strait
## in a few seconds reads as a bee.
@export var min_speed: float = 26.0
@export var max_speed: float = 62.0
## Wingbeats per second. Small birds beat faster than big ones, so this is scaled
## by size per bird.
@export var flap_hz: float = 2.1
## How far the wings foreshorten at the bottom of a beat, as a fraction.
@export_range(0.0, 0.9) var flap_depth: float = 0.55


## One bird's flight. Kept as plain data with the Sprite2D alongside, because
## every one of these is read every frame and a node per property would be a
## get_node() per bird per frame for nothing.
class Bird:
	var sprite: Sprite2D
	var speed: float
	var flap: float
	var phase: float
	var bob: float
	var height: float


var _birds: Array[Bird] = []
## The band of sky birds may occupy, and how far they may fly past its sides
## before being sent back.
var _region: Rect2


func _ready() -> void:
	# Flown from _process, so exempt from physics interpolation — same reason as
	# the fish.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


## `sky` is the box birds fly in: the camera's bounds down to the waterline, so
## nothing ever flies below the horizon or under the terrain.
func populate(sky: Rect2, flock_seed: int) -> void:
	for bird: Bird in _birds:
		bird.sprite.queue_free()
	_birds.clear()
	_region = sky
	if sky.size.x <= 0.0 or sky.size.y <= 0.0:
		return

	# Each entry is [texture, faces_left], kept together so a bird can't be given
	# one drawing's picture and another's facing.
	var textures: Array[Array] = []
	for name: String in SPRITES:
		var texture := load(ART_DIR + name + ".png") as Texture2D
		if texture != null:
			textures.append([texture, FACES_LEFT.has(name)])
	if textures.is_empty():
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = flock_seed
	for i in count:
		_birds.append(_hatch(textures, rng))


func _hatch(textures: Array[Array], rng: RandomNumberGenerator) -> Bird:
	var bird := Bird.new()
	var sprite := Sprite2D.new()
	var drawing: Array = textures[rng.randi() % textures.size()]
	var texture := drawing[0] as Texture2D
	var art_faces_left := drawing[1] as bool
	sprite.texture = texture

	bird.height = rng.randf_range(min_height, max_height)
	var scale_factor: float = bird.height / maxf(float(texture.get_height()), 1.0)
	sprite.scale = Vector2(scale_factor, scale_factor)

	bird.speed = rng.randf_range(min_speed, max_speed)
	# Half of them fly the other way, by mirroring the sprite rather than by
	# rotating it — a rotated bird flies upside down. The mirror is relative to
	# which way this drawing faces, not to a blanket assumption about the sheet.
	if rng.randf() < 0.5:
		bird.speed = -bird.speed
	sprite.flip_h = (bird.speed < 0.0) != art_faces_left

	# Small birds beat faster. The ratio is deliberately exaggerated: at 20 world
	# units tall the difference is only readable if it is overdone.
	bird.flap = flap_hz * (max_height / maxf(bird.height, 1.0)) * rng.randf_range(0.85, 1.2)
	bird.phase = rng.randf() * TAU
	bird.bob = rng.randf_range(2.0, 7.0)

	# Higher in the band means further away, so it also means smaller and paler.
	# The pull towards the sky's own colour is what puts them behind the air
	# rather than pasted onto it.
	var depth: float = 1.0 - (bird.height - min_height) / maxf(max_height - min_height, 1.0)
	sprite.modulate = Color(1, 1, 1, lerpf(0.85, 0.45, depth))

	sprite.position = Vector2(
		rng.randf_range(_region.position.x, _region.end.x),
		# Kept out of the top and bottom tenth of the band: birds skimming the
		# waterline look like they are about to land, and birds pinned to the
		# ceiling look like a border.
		rng.randf_range(
			_region.position.y + _region.size.y * 0.10,
			_region.position.y + _region.size.y * 0.62
		)
	)
	add_child(sprite)
	bird.sprite = sprite
	return bird


func _process(delta: float) -> void:
	if _birds.is_empty():
		return
	var t := float(Time.get_ticks_msec()) / 1000.0
	# A margin so a bird turns round out of sight rather than popping at the edge
	# of the camera's reach.
	var margin: float = _region.size.x * 0.08 + 80.0

	for bird: Bird in _birds:
		var sprite := bird.sprite
		sprite.position.x += bird.speed * delta
		# The bob is tied to the wingbeat, a quarter-cycle behind it: a bird rises
		# on the downstroke. It is a couple of units and it is most of what makes
		# the flap read as effort rather than as a pulsing sprite.
		var beat: float = t * bird.flap * TAU + bird.phase
		sprite.position.y += sin(beat - PI * 0.5) * bird.bob * delta
		sprite.scale.y = absf(sprite.scale.x) * (1.0 - flap_depth * (0.5 + 0.5 * sin(beat)))

		if bird.speed > 0.0 and sprite.position.x > _region.end.x + margin:
			sprite.position.x = _region.position.x - margin
		elif bird.speed < 0.0 and sprite.position.x < _region.position.x - margin:
			sprite.position.x = _region.end.x + margin
