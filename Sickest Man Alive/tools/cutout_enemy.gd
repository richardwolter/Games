extends SceneTree

## Turns a white-background reference render into a game-ready enemy sprite.
## Run by hand when a new creature lands in art_ref/:
##
##   godot --headless --script tools/cutout_enemy.gd
##
## Three jobs, in order:
##   1. knock out the background,
##   2. trim the empty margin,
##   3. scale to the size the other enemy sprites are authored at.
##
## The background is removed by FLOOD FILL from the borders, not by testing every
## pixel against white. Both of these creatures have near-white highlights inside
## them -- the fungus's whole face is pale -- and a global threshold punches holes
## straight through them. Only white that is connected to the edge of the image
## is background.

const OUT_DIR: String = "res://art/enemies"

## Above this luminance a pixel can be swallowed by the fill. Generous, because
## the fill is already constrained to what the border can reach.
const WHITE_CUT: float = 0.86
## Any channel spread above this is a colour, not paper, whatever its brightness.
const MAX_CHROMA: float = 0.06
## Sprites are authored around this tall. The renders are much bigger than
## anything the game draws (enemies render at ~74px), so this is about keeping
## the texture honest, not about detail.
const TARGET_HEIGHT: int = 600

const JOBS: Array[Dictionary] = [
	{"src": "res://art_ref/Funghi_Enemy.png", "out": "fungus.png"},
	{"src": "res://art_ref/Parasite_Enemy.png", "out": "parasite.png"},
]


func _init() -> void:
	for job: Dictionary in JOBS:
		var img := Image.load_from_file(job["src"])
		if img == null:
			push_error("Could not load %s" % job["src"])
			continue
		img.convert(Image.FORMAT_RGBA8)
		_knock_out_background(img)

		var used := img.get_used_rect()
		if used.size.x <= 0 or used.size.y <= 0:
			push_error("%s came out empty -- threshold too aggressive" % job["src"])
			continue
		var cut := img.get_region(used)
		if cut.get_height() > TARGET_HEIGHT:
			var w := int(round(float(cut.get_width()) * TARGET_HEIGHT / cut.get_height()))
			cut.resize(w, TARGET_HEIGHT, Image.INTERPOLATE_LANCZOS)

		var path := "%s/%s" % [OUT_DIR, job["out"]]
		var err := cut.save_png(path)
		print("%s  %s  %s" % [path, cut.get_size(), "ok" if err == OK else "FAILED %d" % err])
	quit()


## Clears every background pixel to full transparency, and feathers the pixels
## the fill stopped against.
##
## The feather matters more than it sounds: these renders are anti-aliased
## against white, so the outermost pixel of the creature is half paper. Cut hard
## and every silhouette gets a bright fringe that reads as a halo once the sprite
## is over a dark floor -- which is the only kind of floor this game has.
func _knock_out_background(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var bg := PackedByteArray()
	bg.resize(w * h)

	var queue: Array[Vector2i] = []
	for x in w:
		queue.append(Vector2i(x, 0))
		queue.append(Vector2i(x, h - 1))
	for y in h:
		queue.append(Vector2i(0, y))
		queue.append(Vector2i(w - 1, y))

	while not queue.is_empty():
		var p: Vector2i = queue.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
			continue
		var i := p.y * w + p.x
		if bg[i] == 1:
			continue
		if not _is_paper(img.get_pixel(p.x, p.y)):
			continue
		bg[i] = 1
		queue.append(Vector2i(p.x + 1, p.y))
		queue.append(Vector2i(p.x - 1, p.y))
		queue.append(Vector2i(p.x, p.y + 1))
		queue.append(Vector2i(p.x, p.y - 1))

	for y in h:
		for x in w:
			var i := y * w + x
			var px := img.get_pixel(x, y)
			if bg[i] == 1:
				img.set_pixel(x, y, Color(px.r, px.g, px.b, 0.0))
				continue
			# Kept, but touching the background: fade it out by how close to
			# paper it is, so the edge dissolves instead of stopping dead.
			if not _touches(bg, w, h, x, y):
				continue
			var lum := (px.r + px.g + px.b) / 3.0
			if lum <= WHITE_CUT:
				continue
			var a := 1.0 - (lum - WHITE_CUT) / (1.0 - WHITE_CUT)
			img.set_pixel(x, y, Color(px.r, px.g, px.b, clampf(a, 0.0, 1.0)))


## Paper, as opposed to a pale part of the creature: bright AND grey. The fungus
## is drawn in warm bone tones that are nearly this bright but never this
## neutral, which is what keeps the fill out of its face.
func _is_paper(px: Color) -> bool:
	var lo := minf(px.r, minf(px.g, px.b))
	var hi := maxf(px.r, maxf(px.g, px.b))
	return lo >= WHITE_CUT and (hi - lo) <= MAX_CHROMA


func _touches(bg: PackedByteArray, w: int, h: int, x: int, y: int) -> bool:
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx := x + d.x
		var ny := y + d.y
		if nx < 0 or ny < 0 or nx >= w or ny >= h:
			continue
		if bg[ny * w + nx] == 1:
			return true
	return false
