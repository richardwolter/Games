class_name PrepPage
extends Control

## Ruled notebook-paper background, matching the battlefield's page draw
## (lane_field.gd _draw_page) so the prep screen reads as the same world.
## Shared by every menu screen — TitleScreen, PrepMenu, AbilitiesPage,
## StatsPage — so anything added here shows up on all four.
##
## Scenery + bloodstains (Designer, 2026-07-25: "so it's not a blank notebook
## page... a few blood smudges like it has been battled on") reuse the
## battlefield's own art and visual language rather than inventing a second
## one: the same sprite PNGs LaneField draws as lane props, and the same
## layered-lobe blot shape BloodLayer bakes where minions die.

## Palette lives in UIStyle now — these aliases stay so existing call sites
## (prep_menu.gd's card borders, etc.) keep working, but there is only one
## definition of "paper" and "ink" in the game.
const PAGE_COLOR := UIStyle.PAGE_SOLID
const RULE_COLOR := UIStyle.RULE
const MARGIN_COLOR := UIStyle.MARGIN
const INK_COLOR := UIStyle.INK

const RULE_SPACING := 42.0

# -- Scenery ------------------------------------------------------------------

const TEX_ROCK_1 := preload("res://assets/sprites/Rock-1_Color.png")
const TEX_ROCK_2 := preload("res://assets/sprites/Rock-2_Color.png")
const TEX_TREE_BUSHY := preload("res://assets/sprites/Tree-Bushy_Color.png")
const TEX_ALIEN_TREE := preload("res://assets/sprites/Alien-Tree_Color.png")
const TEX_ALIEN_TREE_THIN := preload("res://assets/sprites/Alien-Tree-Thin_Color.png")
const TEX_PLANT := preload("res://assets/sprites/Plant_Color.png")
const TEX_MUSHROOM := preload("res://assets/sprites/Mushroom_Color.png")
const TEX_SWORD := preload("res://assets/sprites/Sword_Ground_Color.png")
const TEX_SPACESHIP := preload("res://assets/sprites/Destroyed-Spaceship_Color.png")

## Hand-placed props, NOT scattered randomly — the page has to stay readable
## behind a centred UI column, and a random scatter would sooner or later put
## a tree behind the START RUN button.
##
## Position is normalised (fraction of the control's size) so the layout holds
## at any window size; `height` is in design-canvas pixels (1920x1080) and is
## scaled by the same factor. `pos` is the prop's GROUND POINT — bottom-centre,
## matching LaneField._draw_prop_sprite — so tall art stands on the page
## instead of floating around a centre point.
##
## Every x sits outside 0.20..0.80. PrepMenu's laid-out column measures 1122px
## on the 1920 canvas (verified, not estimated), i.e. x 0.21..0.79, and it is
## the widest of the four screens — so that band is the keep-out zone.
const SCENERY := [
	# Left margin strip.
	{"tex": TEX_TREE_BUSHY, "pos": Vector2(0.055, 0.30), "height": 200.0, "flip": false},
	{"tex": TEX_ROCK_1, "pos": Vector2(0.135, 0.40), "height": 70.0, "flip": false},
	{"tex": TEX_PLANT, "pos": Vector2(0.030, 0.52), "height": 95.0, "flip": true},
	{"tex": TEX_MUSHROOM, "pos": Vector2(0.115, 0.63), "height": 58.0, "flip": false},
	{"tex": TEX_ALIEN_TREE_THIN, "pos": Vector2(0.065, 0.87), "height": 215.0, "flip": false},
	{"tex": TEX_ROCK_2, "pos": Vector2(0.150, 0.93), "height": 62.0, "flip": true},
	# Right margin strip.
	{"tex": TEX_ALIEN_TREE, "pos": Vector2(0.945, 0.34), "height": 225.0, "flip": true},
	{"tex": TEX_ROCK_2, "pos": Vector2(0.865, 0.45), "height": 78.0, "flip": false},
	{"tex": TEX_SWORD, "pos": Vector2(0.905, 0.62), "height": 120.0, "flip": false},
	{"tex": TEX_PLANT, "pos": Vector2(0.965, 0.73), "height": 88.0, "flip": false},
	{"tex": TEX_TREE_BUSHY, "pos": Vector2(0.880, 0.95), "height": 195.0, "flip": true},
	# Bottom corners — the wreck anchors the page and reads as "something
	# happened here", which is the whole point of the pass.
	{"tex": TEX_SPACESHIP, "pos": Vector2(0.140, 0.995), "height": 150.0, "flip": false},
	{"tex": TEX_MUSHROOM, "pos": Vector2(0.820, 0.99), "height": 50.0, "flip": true},

	# -- Second pass (Designer, 2026-07-26: "spread more assets ... without
	# interfering") -------------------------------------------------------
	# Everything below still respects the 0.20..0.80 keep-out. The margins had
	# gaps at the top and between the existing clusters, which read as two
	# decorated strips rather than a page that continues past the UI.
	#
	# TOP band: the previous layout started at y 0.30, leaving the upper page
	# bare behind the logo/title row. These fill it at small sizes so they read
	# as distance rather than crowding the heading.
	{"tex": TEX_MUSHROOM, "pos": Vector2(0.045, 0.12), "height": 44.0, "flip": true},
	{"tex": TEX_ROCK_2, "pos": Vector2(0.165, 0.16), "height": 52.0, "flip": false},
	{"tex": TEX_PLANT, "pos": Vector2(0.100, 0.21), "height": 70.0, "flip": false},
	{"tex": TEX_ROCK_1, "pos": Vector2(0.925, 0.13), "height": 58.0, "flip": true},
	{"tex": TEX_ALIEN_TREE_THIN, "pos": Vector2(0.835, 0.22), "height": 150.0, "flip": false},
	{"tex": TEX_MUSHROOM, "pos": Vector2(0.975, 0.24), "height": 40.0, "flip": false},
	# Filling the left strip's gaps.
	{"tex": TEX_SWORD, "pos": Vector2(0.175, 0.55), "height": 95.0, "flip": true},
	{"tex": TEX_ROCK_2, "pos": Vector2(0.020, 0.68), "height": 48.0, "flip": false},
	{"tex": TEX_MUSHROOM, "pos": Vector2(0.155, 0.77), "height": 46.0, "flip": true},
	{"tex": TEX_PLANT, "pos": Vector2(0.085, 0.72), "height": 66.0, "flip": true},
	# Filling the right strip's gaps.
	{"tex": TEX_ROCK_1, "pos": Vector2(0.815, 0.38), "height": 54.0, "flip": false},
	{"tex": TEX_MUSHROOM, "pos": Vector2(0.980, 0.54), "height": 42.0, "flip": true},
	{"tex": TEX_ROCK_2, "pos": Vector2(0.830, 0.80), "height": 60.0, "flip": true},
	{"tex": TEX_PLANT, "pos": Vector2(0.955, 0.88), "height": 72.0, "flip": false},
	# Bottom edge, outside the column.
	{"tex": TEX_ROCK_1, "pos": Vector2(0.055, 0.97), "height": 50.0, "flip": true},
	{"tex": TEX_SWORD, "pos": Vector2(0.755, 0.995), "height": 88.0, "flip": true},
	{"tex": TEX_ROCK_2, "pos": Vector2(0.960, 0.99), "height": 46.0, "flip": false},
]

## Props sit slightly back from the UI — they're set dressing, not content, and
## full-strength art next to the hand-drawn logo competed with it.
const SCENERY_ALPHA := 0.85

# -- Bloodstains --------------------------------------------------------------

## Same ink-on-paper colour BloodLayer bakes onto the battlefield.
## UIStyle.CRIMSON (the staff-gem red) at half value — written out as a literal
## because a const initializer can't call .darkened(). Same colour BloodLayer
## bakes onto the battlefield; keep the two in step by hand if CRIMSON moves.
const STAIN_COLOR := Color("600c0c")

## Normalised stain centres with a design-pixel radius each. Kept to the
## margins for the same reason as the scenery, except the two faint ones under
## the column: cards are translucent paper (UIStyle.CARD), so a stain showing
## faintly through a card reads as the page having been bled on BEFORE the UI
## was laid over it, which is exactly the intent.
const STAINS := [
	{"pos": Vector2(0.085, 0.20), "radius": 34.0, "alpha": 0.30},
	# The stain that used to sit at (0.155, 0.55) is gone (Designer,
	# 2026-07-26): the Duo Pairings help text moved into that band when the
	# pairing panel became three columns, and the blot sat directly behind the
	# words. Stains are page dressing — text wins.
	{"pos": Vector2(0.045, 0.72), "radius": 40.0, "alpha": 0.28},
	{"pos": Vector2(0.925, 0.22), "radius": 28.0, "alpha": 0.26},
	{"pos": Vector2(0.845, 0.68), "radius": 36.0, "alpha": 0.30},
	{"pos": Vector2(0.955, 0.88), "radius": 24.0, "alpha": 0.22},
	# Faint, under the UI column.
	{"pos": Vector2(0.400, 0.15), "radius": 30.0, "alpha": 0.13},
	{"pos": Vector2(0.640, 0.90), "radius": 26.0, "alpha": 0.12},
]

## Fixed seed: a notebook page does not rearrange its own stains. _draw runs
## again on every resize, so the blot lobes/speckles must come out identical
## each time — re-seeding per draw is what keeps them stable.
const STAIN_SEED := 20260725
## Separate seed for the PageMarks pass, so tuning one set of marks doesn't
## reshuffle the bloodstains that were already signed off.
const MARKS_SEED := 20260726

## Preloaded by PATH rather than referenced by its `class_name`: a brand-new
## script isn't in Godot's global class cache until the editor rescans, so
## `PageMarks.draw_marks(...)` fails to parse on a fresh checkout (or on the
## first run after the file is added) with "Identifier not declared". preload
## resolves at compile time from the path and never has that gap.
const PageMarksLib := preload("res://scripts/page_marks.gd")

## The horizontal band the centred UI column occupies on every menu screen.
## Named constants now that both the prop layout and the scribble keep-out read
## them — see SCENERY's doc for where 0.20..0.80 comes from.
const UI_COLUMN_MIN_X := 0.20
const UI_COLUMN_MAX_X := 0.80

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, PAGE_COLOR, true)
	var y := fmod(RULE_SPACING, RULE_SPACING)
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), RULE_COLOR, 1.5, true)
		y += RULE_SPACING
	var mx := size.x * 0.08
	draw_line(Vector2(mx, 0), Vector2(mx, size.y), MARGIN_COLOR, 2.0, true)

	# Order matters: marks and stains soak into the paper (over the rules, under
	# the props), props stand on top of them, UI draws over everything as a
	# sibling added after this node.
	#
	# FIXED seed for the menus — a notebook doesn't rearrange its own scribbles
	# between visits, and _draw re-runs on every resize, so a random seed would
	# make the marks crawl whenever the window changed. The battlefield passes a
	# fresh one instead; see PageMarks.
	PageMarksLib.draw_marks(self, rect, MARKS_SEED, _art_scale(), 1.0, _ui_keep_out())
	_draw_stains()
	_draw_scenery()

## The centre band the UI column occupies — scribbles and smudges stay out of
## it for the same reason SCENERY does: this page sits behind text that has to
## stay readable. Same 0.20..0.80 measurement the prop layout uses.
func _ui_keep_out() -> Rect2:
	return Rect2(Vector2(size.x * UI_COLUMN_MIN_X, 0.0),
			Vector2(size.x * (UI_COLUMN_MAX_X - UI_COLUMN_MIN_X), size.y))

## Uniform scale from the 1920x1080 design canvas, so prop heights and stain
## radii shrink together with the page instead of one drifting from the other.
func _art_scale() -> float:
	if size.x <= 0.0 or size.y <= 0.0:
		return 1.0
	return minf(size.x / 1920.0, size.y / 1080.0)

func _draw_scenery() -> void:
	var s := _art_scale()
	var tint := Color(1.0, 1.0, 1.0, SCENERY_ALPHA)
	for prop in SCENERY:
		var tex: Texture2D = prop["tex"]
		var tex_size := tex.get_size()
		if tex_size.y <= 0.0:
			continue
		var base: Vector2 = (prop["pos"] as Vector2) * size
		# The authored heights above assume the drawing fills its texture. The
		# colored art (2026-07-25) carries transparent margin, so each prop's
		# height is compensated by the same measured factors the battlefield
		# uses — otherwise the same rock reads at two different sizes between
		# the prep page and the lane.
		var height: float = float(prop["height"]) * s * LaneField.art_pad_height(tex)
		var draw_size := Vector2(tex_size.x * (height / tex_size.y), height)
		var r := Rect2(base - Vector2(draw_size.x * 0.5, draw_size.y), draw_size)
		if prop["flip"]:
			# Negative width mirrors in place, same trick as
			# LaneField._draw_prop_sprite.
			r = Rect2(r.position + Vector2(draw_size.x, 0.0), Vector2(-draw_size.x, draw_size.y))
		draw_texture_rect(tex, r, false, tint)

func _draw_stains() -> void:
	var s := _art_scale()
	var rng := RandomNumberGenerator.new()
	rng.seed = STAIN_SEED
	for stain in STAINS:
		_draw_blot((stain["pos"] as Vector2) * size, float(stain["radius"]) * s,
				float(stain["alpha"]), rng)

## One bloodstain, built the way BloodLayer builds its baked ones: a handful of
## overlapping lobes (an irregular blot silhouette rather than one clean
## circle) plus a few small satellite speckles flicked further out. Each lobe
## is three nested circles of rising alpha, which approximates that layer's
## harder-than-linear falloff with plain draw_circle calls — no per-pixel image
## baking needed for a static background.
func _draw_blot(center: Vector2, radius: float, alpha: float, rng: RandomNumberGenerator) -> void:
	for i in rng.randi_range(4, 6):
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(0.0, radius * 0.35)
		var lobe := center + Vector2(cos(ang), sin(ang)) * dist
		var lobe_r := radius * rng.randf_range(0.55, 0.9)
		for step in 3:
			var t := 1.0 - float(step) * 0.28
			draw_circle(lobe, lobe_r * t, Color(STAIN_COLOR.r, STAIN_COLOR.g,
					STAIN_COLOR.b, alpha * 0.45))
	for i in rng.randi_range(3, 6):
		var ang := rng.randf() * TAU
		var dist := radius * rng.randf_range(0.8, 2.2)
		var speck := center + Vector2(cos(ang), sin(ang)) * dist
		draw_circle(speck, radius * rng.randf_range(0.08, 0.22),
				Color(STAIN_COLOR.r, STAIN_COLOR.g, STAIN_COLOR.b,
						alpha * rng.randf_range(0.5, 0.85)))
