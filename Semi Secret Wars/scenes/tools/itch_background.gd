extends Node
## Bakes the itch.io page background (Designer, 2026-07-28) from assets already
## in the project — no new art. Run this scene and it writes OUTPUT_PATH, prints
## the path, and quits. Same approach as cover_image.gd; see that file for why a
## SubViewport bake beats a resized screenshot (the linework is hand-drawn and
## must not be resampled).
##
## It is literally the game's own menu page — PrepPage brings the ruled paper,
## margin rule, scribbles, bloodstains and scenery props with it — rendered at
## itch's canvas size instead of the game's.
##
## The one thing this adds on top: CENTER_WASH. itch.io centres the page's
## content column over this image, and the brief was "no visual interference in
## the centre". PrepPage already keeps props and scribbles out of x 0.20..0.80,
## but the ruled lines and the two faint under-column stains still run through
## it, and at background scale they fight the itch page text. The wash lays
## paper colour back over the middle band at a strength that fades to nothing
## before it reaches the decorated margins, so the centre reads as plain paper
## and the edges stay full-strength art.

## 2560x1440 rather than 1920x1080: itch stretches the background to the
## viewport, and on a wide desktop a 1920 image is upscaled — which is exactly
## the resampling the SubViewport bake exists to avoid. PrepPage scales its own
## props off a 1920x1080 design canvas, so this size renders them 1.33x, not
## cropped.
const BACKGROUND_SIZE := Vector2i(2560, 1440)
const OUTPUT_PATH := "res://assets/Itch_Background_2560x1440.png"

func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.size = BACKGROUND_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	viewport.add_child(_build_background())

	# Two frames: layout, then draw. Same reason as cover_image.gd.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	var image := viewport.get_texture().get_image()
	var err := image.save_png(OUTPUT_PATH)
	if err == OK:
		print("itch background written: %s (%dx%d)" % [OUTPUT_PATH, image.get_width(), image.get_height()])
	else:
		push_error("itch background save failed (%d): %s" % [err, OUTPUT_PATH])
	get_tree().quit()

func _build_background() -> Control:
	var root := Control.new()
	root.size = Vector2(BACKGROUND_SIZE)

	var page := PrepPage.new()
	page.size = Vector2(BACKGROUND_SIZE)
	root.add_child(page)

	var wash := CenterWash.new()
	wash.size = Vector2(BACKGROUND_SIZE)
	root.add_child(wash)
	return root

## The quiet band, drawn as vertical strips of PAGE_SOLID whose alpha eases from
## WASH_STRENGTH at the centre to zero at WASH_OUTER. smoothstep rather than a
## linear ramp: a linear fade leaves a visible edge where it reaches zero.
##
## The tuning constants live in here rather than at file scope because an inner
## class does not see the outer script's constants in GDScript.
class CenterWash extends Control:
	## Half-width of the quiet band, as a fraction of the image. itch's content
	## column is ~960px on a wide viewport (~0.19 either side of centre at this
	## size); WASH_INNER covers that with margin to spare, and the falloff out to
	## WASH_OUTER reaches zero at x 0.18/0.82, just outside PrepPage's 0.20/0.80
	## prop keep-out, so the wash stops before it can grey out a prop. An earlier
	## 0.40 outer bled onto the innermost sword and rock and left them looking
	## half-erased.
	const WASH_INNER := 0.22
	const WASH_OUTER := 0.32
	## Not 1.0 — at full strength the band reads as a white box pasted on the
	## page. At 0.72 the rules survive as a ghost, which keeps it paper.
	const WASH_STRENGTH := 0.72
	## Vertical strips faking the horizontal gradient. 160 across 2560px is one
	## every 16px, below the point where banding shows in flat paper.
	const WASH_STRIPS := 160

	func _draw() -> void:
		var strip_w := size.x / float(WASH_STRIPS)
		for i in WASH_STRIPS:
			var t := (float(i) + 0.5) / float(WASH_STRIPS)
			var d := absf(t - 0.5) * 2.0  # 0 at centre, 1 at either edge
			var a := WASH_STRENGTH * (1.0 - smoothstep(WASH_INNER * 2.0, WASH_OUTER * 2.0, d))
			if a <= 0.0:
				continue
			var c := UIStyle.PAGE_SOLID
			draw_rect(Rect2(float(i) * strip_w, 0.0, strip_w + 1.0, size.y),
					Color(c.r, c.g, c.b, a), true)
