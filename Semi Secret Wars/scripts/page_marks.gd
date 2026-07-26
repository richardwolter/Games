class_name PageMarks
## Scribbles, pen stains and smudges scattered over a notebook page (Designer,
## 2026-07-26: "so it feels more dirty and alive").
##
## Shared by PrepPage (the menu background) and LaneField (the battlefield), so
## a page is dressed the same way wherever it appears. The one difference is
## deliberate and is the whole reason `rng_seed` is a parameter:
##
##   * MENUS pass a FIXED seed. A notebook does not rearrange its own scribbles
##     between visits, and _draw re-runs on every resize — a random seed would
##     make the marks crawl each time the window changed.
##   * The BATTLEFIELD passes a fresh seed per load, so every level looks like
##     a different page out of the same notebook.
##
## Everything here is drawn in ink at low alpha and sits UNDER the props and
## units, so it never competes with anything the player has to read.

## Pen colour. Deliberately the ink the rest of the game is drawn with (a
## desaturated near-black), not a second grey invented here.
const MARK_INK := UIStyle.SOOT

## Existing art reused at small sizes as ground grime, rather than new assets —
## these are already the battlefield's own scatter props.
const TEX_SMUDGE := preload("res://assets/sprites/Ground-Smudge.png")
const TEX_PAW := preload("res://assets/sprites/Paw_Print_Smudge.png")

## Per-1920x1080-page counts at density 1.0. Kept low on purpose: this is
## texture, not content, and a page that reads as "written on" tips into "torn
## out of a bin" fast.
const SCRIBBLE_COUNT := 14
const STAIN_COUNT := 18
const SMUDGE_COUNT := 10

## Alpha ranges. Scribbles are pen pressure; stains are ink that soaked in; the
## sprite smudges are the faintest, since they carry real drawn detail and read
## much stronger than a blot of the same size.
const SCRIBBLE_ALPHA := Vector2(0.05, 0.13)
const STAIN_ALPHA := Vector2(0.05, 0.14)
const SMUDGE_ALPHA := Vector2(0.04, 0.10)

## Draws a full set of marks inside `rect`.
##
## `keep_out` is a rect the marks stay out of — the menus use it to protect the
## centre column the UI sits in. Pass an empty Rect2 (the default) for a page
## with nothing to avoid, like the battlefield.
##
## `density` scales every count; `art_scale` scales every size, so marks shrink
## with the page instead of a 1080p-authored blot dominating a small window.
static func draw_marks(canvas: CanvasItem, rect: Rect2, rng_seed: int,
		art_scale: float = 1.0, density: float = 1.0,
		keep_out: Rect2 = Rect2()) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	_draw_scribbles(canvas, rect, rng, art_scale, density, keep_out)
	_draw_stains(canvas, rect, rng, art_scale, density, keep_out)
	_draw_smudges(canvas, rect, rng, art_scale, density, keep_out)

## A point inside `rect` and outside `keep_out`. Gives up after a few tries and
## returns the last candidate — with a keep-out covering less than half the
## page, failing 8 times running is rare enough that biasing the distribution
## matters less than the cost of looping forever.
static func _pick_point(rect: Rect2, rng: RandomNumberGenerator, keep_out: Rect2) -> Vector2:
	var p := Vector2.ZERO
	for attempt in 8:
		p = Vector2(rng.randf_range(rect.position.x, rect.end.x),
				rng.randf_range(rect.position.y, rect.end.y))
		if keep_out.size == Vector2.ZERO or not keep_out.has_point(p):
			return p
	return p

## Loose pen doodles: a short wandering stroke, drawn as a polyline whose
## direction drifts a little at every step. A straight line reads as a ruled
## rule; the drift is what makes it read as somebody scribbling.
static func _draw_scribbles(canvas: CanvasItem, rect: Rect2, rng: RandomNumberGenerator,
		art_scale: float, density: float, keep_out: Rect2) -> void:
	for i in int(SCRIBBLE_COUNT * density):
		var start := _pick_point(rect, rng, keep_out)
		var angle := rng.randf() * TAU
		var steps := rng.randi_range(4, 9)
		var step_len := rng.randf_range(9.0, 26.0) * art_scale
		var pts := PackedVector2Array([start])
		var at := start
		for s in steps:
			angle += rng.randf_range(-1.1, 1.1)
			at += Vector2(cos(angle), sin(angle)) * step_len
			pts.append(at)
		var a := rng.randf_range(SCRIBBLE_ALPHA.x, SCRIBBLE_ALPHA.y)
		canvas.draw_polyline(pts, Color(MARK_INK, a),
				rng.randf_range(1.2, 2.6) * art_scale, true)

## Pen stains: a small ink blot with a couple of flicked specks beside it —
## the same "lobes plus speckles" idea PrepPage uses for blood, at a fraction
## of the size and in ink rather than red.
static func _draw_stains(canvas: CanvasItem, rect: Rect2, rng: RandomNumberGenerator,
		art_scale: float, density: float, keep_out: Rect2) -> void:
	for i in int(STAIN_COUNT * density):
		var center := _pick_point(rect, rng, keep_out)
		var radius := rng.randf_range(2.5, 9.0) * art_scale
		var a := rng.randf_range(STAIN_ALPHA.x, STAIN_ALPHA.y)
		for lobe_i in rng.randi_range(2, 4):
			var ang := rng.randf() * TAU
			var lobe := center + Vector2(cos(ang), sin(ang)) * radius * rng.randf_range(0.0, 0.5)
			canvas.draw_circle(lobe, radius * rng.randf_range(0.5, 1.0), Color(MARK_INK, a))
		for speck_i in rng.randi_range(1, 4):
			var ang := rng.randf() * TAU
			var speck := center + Vector2(cos(ang), sin(ang)) * radius * rng.randf_range(1.2, 3.5)
			canvas.draw_circle(speck, radius * rng.randf_range(0.12, 0.3),
					Color(MARK_INK, a * rng.randf_range(0.5, 1.0)))

## Existing smudge/paw art shrunk right down and faded out, so the page carries
## some real drawn grime among the procedural marks (Designer: "use small
## sprites we already have, and shrink them so they look like a little stain").
## Randomly flipped so the same two textures don't visibly repeat.
static func _draw_smudges(canvas: CanvasItem, rect: Rect2, rng: RandomNumberGenerator,
		art_scale: float, density: float, keep_out: Rect2) -> void:
	for i in int(SMUDGE_COUNT * density):
		var tex: Texture2D = TEX_SMUDGE if rng.randf() < 0.6 else TEX_PAW
		var tex_size := tex.get_size()
		if tex_size.x <= 0.0 or tex_size.y <= 0.0:
			continue
		var at := _pick_point(rect, rng, keep_out)
		var height := rng.randf_range(14.0, 40.0) * art_scale
		var draw_size := Vector2(tex_size.x * (height / tex_size.y), height)
		var r := Rect2(at - draw_size * 0.5, draw_size)
		if rng.randf() < 0.5:
			r = Rect2(r.position + Vector2(draw_size.x, 0.0), Vector2(-draw_size.x, draw_size.y))
		canvas.draw_texture_rect(tex, r, false,
				Color(1.0, 1.0, 1.0, rng.randf_range(SMUDGE_ALPHA.x, SMUDGE_ALPHA.y)))
