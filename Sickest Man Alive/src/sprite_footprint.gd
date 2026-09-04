class_name SpriteFootprint
extends RefCounted

## Builds collision shapes that match what is actually drawn.
##
## Hand-tuned radii drift the moment the art changes: the kid was a 14px circle
## against a sprite three times that, so shots passed visibly through him and he
## walked through gaps he plainly did not fit in. Measuring the sprite instead
## means the hitbox is wrong only if the ART is wrong.
##
## Measured from the OPAQUE pixels, not the texture rectangle. A PNG exported
## with padding would otherwise hand out a hitbox made mostly of nothing.

## texture RID -> opaque Rect2 in texture pixels. Reading an image back off the
## GPU is not free and the same handful of textures are used for every enemy on
## the floor.
static var _opaque_cache: Dictionary = {}


## The opaque bounds of a texture, in its own pixels. Falls back to the full
## rectangle for anything that cannot be read back (compressed formats, and
## anything that is not a plain image).
static func opaque_rect(tex: Texture2D) -> Rect2:
	if tex == null:
		return Rect2()
	var key := tex.get_rid()
	if _opaque_cache.has(key):
		return _opaque_cache[key]

	var full := Rect2(Vector2.ZERO, tex.get_size())
	var rect := full
	var img := tex.get_image()
	if img != null:
		if img.is_compressed():
			img = img.duplicate()
			if img.decompress() != OK:
				img = null
	if img != null:
		var used := img.get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			rect = Rect2(used)

	_opaque_cache[key] = rect
	return rect


## One sprite's opaque bounds expressed in `root`'s local space.
static func local_rect(sprite: Sprite2D, root: Node2D) -> Rect2:
	if sprite == null or sprite.texture == null or not sprite.visible:
		return Rect2()

	var used := opaque_rect(sprite.texture)
	# Sprite2D places its texture from `offset`, and `centered` shifts it by half
	# the FULL texture -- the opaque sub-rect rides along inside that.
	var origin := sprite.offset + used.position
	if sprite.centered:
		origin -= sprite.texture.get_size() * 0.5

	var to_root := root.global_transform.affine_inverse() * sprite.global_transform
	var corners: Array[Vector2] = [
		to_root * origin,
		to_root * (origin + Vector2(used.size.x, 0.0)),
		to_root * (origin + Vector2(0.0, used.size.y)),
		to_root * (origin + used.size),
	]

	var out := Rect2(corners[0], Vector2.ZERO)
	for c in corners:
		out = out.expand(c)
	return out


## The union of several sprites, in `root`'s local space. Empty sprites drop out
## rather than dragging the union to the origin.
static func union_rect(sprites: Array[Sprite2D], root: Node2D) -> Rect2:
	var out := Rect2()
	var started := false
	for s in sprites:
		var r := local_rect(s, root)
		if r.size == Vector2.ZERO:
			continue
		out = r if not started else out.merge(r)
		started = true
	return out


## Writes a capsule wrapping `rect` into an existing CollisionShape2D.
##
## Capsule rather than rectangle: a boxy hitbox catches on corners it looks like
## it should slide past, and this game is played by running through gaps.
## CapsuleShape2D's long axis is Y, so a sprite wider than it is tall gets the
## shape turned a quarter turn rather than a different shape class -- one code
## path for both, and the caller never has to know which it got.
static func apply_capsule(cs: CollisionShape2D, rect: Rect2, shrink: float = 1.0) -> void:
	if cs == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var w := rect.size.x * shrink
	var h := rect.size.y * shrink
	var capsule := CapsuleShape2D.new()
	if h >= w:
		capsule.radius = w * 0.5
		capsule.height = h
		cs.rotation = 0.0
	else:
		capsule.radius = h * 0.5
		capsule.height = w
		cs.rotation = PI * 0.5
	cs.shape = capsule
	cs.position = rect.get_center()
