class_name BattleFX
## Static one-shot VFX helpers shared by Combatant deaths, LaneSpawnPoint
## destruction, and hero deploy — see PRODUCTION.md "Battlefield VFX Pass".
##
## Every effect here is a plain self-freeing node added as a sibling of the
## thing that triggered it (same convention Combatant._spawn_death_particles
## already used), so effects keep playing after their owner queue_free()s.
## No autoload, no .tscn — matches the existing code-created-node convention.
##
## Budget: large swarm wipes can trigger dozens of deaths in one frame. Every
## *transient burst* (death_pop, blood_spray, teleport sparks/beam/ring) this
## file creates registers against a shared live-count budget; once over
## budget, optional bursts are skipped while the core pop — the readability-
## critical part — always plays. Nothing here runs during headless balance
## sweeps (RunState.headless).
##
## Ground clutter (Designer, 2026-07-24: "players should be able to see
## debris and everything left out on parts of the lane heroes already passed
## through") is a separate concern from the burst budget above: ground
## splashes, paper scraps, and debris shards no longer fade out or
## queue_free — they stay on the field like BloodLayer's stains, so a lane
## reads as fought-over once the party has pushed through it. Since they're
## permanent, they're tracked in their own FIFO list capped at MAX_CLUTTER;
## past the cap the oldest piece (not necessarily the least visible one, but
## the one furthest back down the lane and least likely to still be on
## screen) is freed to make room, so total node count stays bounded across a
## very long battle.

const MAX_LIVE := 48
static var _live := 0

const MAX_CLUTTER := 300
static var _clutter: Array[Node] = []

static func _headless() -> bool:
	return Engine.get_main_loop() == null or RunState.headless

## Reserves `cost` slots against the shared burst budget. Returns false
## (reserves nothing) when it would push the live count over MAX_LIVE —
## callers use this to drop optional flourishes under heavy load while the
## mandatory core effect (which never checks the budget) still plays.
static func _try_reserve(cost: int) -> bool:
	if _live + cost > MAX_LIVE:
		return false
	_live += cost
	return true

static func _track(node: Node, cost: int = 1) -> void:
	_live += cost
	node.tree_exited.connect(func(): _live = maxi(0, _live - cost))

## For nodes whose budget slot was already reserved via _try_reserve (so the
## live count must not be incremented again here) — just wires the release.
static func _track_reserved(node: Node) -> void:
	node.tree_exited.connect(func(): _live = maxi(0, _live - 1))

## Registers a permanent ground-clutter piece (splash/scrap/shard). Evicts the
## oldest piece once MAX_CLUTTER is exceeded instead of ever fading this one.
static func _track_clutter(node: Node) -> void:
	_clutter.append(node)
	node.tree_exited.connect(func(): _clutter.erase(node))
	if _clutter.size() > MAX_CLUTTER:
		var oldest: Node = _clutter.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

## -- Deaths -----------------------------------------------------------------

## Core death burst: always plays (never budget-gated) so every kill reads,
## even under a mass swarm wipe. `scale` multiplies size/count for bigger
## units (villains, gates) — see Combatant.death_fx_scale.
static func death_pop(parent: Node, pos: Vector2, color: Color, radius: float, scale: float = 1.0) -> void:
	if _headless() or parent == null:
		return
	var burst := CPUParticles2D.new()
	burst.global_position = pos
	burst.emitting = false
	burst.one_shot = true
	burst.amount = int(30 * scale)
	burst.lifetime = 0.6
	burst.explosiveness = 1.0
	burst.direction = Vector2.UP
	burst.spread = 180.0
	burst.gravity = Vector2(0, 280)
	burst.damping_min = 40.0
	burst.damping_max = 70.0
	burst.initial_velocity_min = 80.0 * scale
	burst.initial_velocity_max = 260.0 * scale
	burst.scale_amount_min = maxf(1.5, radius * 0.08) * scale
	burst.scale_amount_max = maxf(3.0, radius * 0.16) * scale
	burst.color = color
	parent.add_child(burst)
	_track(burst)
	burst.emitting = true
	var t := burst.get_tree().create_timer(burst.lifetime + 0.1)
	t.timeout.connect(burst.queue_free)

## Directional dark-red spray layered on top of death_pop, biased toward
## `dir` (the incoming hit direction) so it reads as blood flying off the hit,
## not just a generic puff. Textured with _ink_speck_texture (irregular
## blotchy specks, see below) instead of CPUParticles2D's default flat quad —
## a field of clean squares/dots was the single biggest "digital" tell in the
## old look. Skipped first under budget pressure.
static func blood_spray(parent: Node, pos: Vector2, dir: Vector2, radius: float, scale: float = 1.0) -> void:
	if _headless() or parent == null or not _try_reserve(1):
		return
	var spray := CPUParticles2D.new()
	spray.texture = _ink_speck_texture()
	spray.global_position = pos
	spray.emitting = false
	spray.one_shot = true
	spray.amount = int(16 * scale)
	spray.lifetime = 0.4
	spray.explosiveness = 1.0
	spray.direction = (dir if dir != Vector2.ZERO else Vector2.UP).normalized()
	spray.spread = 55.0
	spray.gravity = Vector2(0, 320)
	spray.initial_velocity_min = 120.0 * scale
	spray.initial_velocity_max = 300.0 * scale
	spray.scale_amount_min = maxf(1.2, radius * 0.06) * scale
	spray.scale_amount_max = maxf(2.2, radius * 0.11) * scale
	# Random initial rotation per speck so the (already irregular) texture
	# doesn't visibly repeat across a burst of a dozen particles.
	spray.angle_min = -180.0
	spray.angle_max = 180.0
	spray.color = Color(0.5, 0.06, 0.05)
	parent.add_child(spray)
	_track_reserved(spray)
	spray.emitting = true
	var t := spray.get_tree().create_timer(spray.lifetime + 0.1)
	t.timeout.connect(spray.queue_free)

## Permanent ground blob left under a death — an irregular ink-blot pool plus
## a few smaller satellite droplets flicked outward, rather than one
## perfectly smooth circular splash, so it reads as ink soaked into paper.
## Stays on the field (ground clutter, not a fading burst — see class doc).
static func ground_splash(parent: Node, pos: Vector2, color: Color, radius: float) -> void:
	if _headless() or parent == null:
		return
	_ink_blob(parent, pos, color, radius)
	var droplets := randi_range(3, 5)
	for i in droplets:
		var ang := randf() * TAU
		var dist := radius * randf_range(0.9, 1.8)
		var drop_pos := pos + Vector2(cos(ang), sin(ang)) * dist
		var drop_r := radius * randf_range(0.12, 0.3)
		_ink_blob(parent, drop_pos, color, drop_r)

## -- Ink-on-paper shared helpers ---------------------------------------------

## A single irregular ink-blot polygon: two offset sine harmonics plus
## per-point jitter give the outline a few bulges/pinches instead of reading
## as a uniformly-noisy circle (which still looks like a soft digital blob at
## a glance). Ground-squashed to read as a pool on the floor. Permanent —
## registered as clutter, not tweened out.
static func _ink_blob(parent: Node, pos: Vector2, color: Color, radius: float) -> void:
	var splash := Polygon2D.new()
	var pts := PackedVector2Array()
	var point_count := 14
	var wobble_a := randf_range(0.15, 0.3)
	var wobble_b := randf_range(0.08, 0.2)
	var phase_a := randf() * TAU
	var phase_b := randf() * TAU
	for i in point_count:
		var ang := TAU * float(i) / point_count
		var wobble := 1.0 + wobble_a * sin(ang * 3.0 + phase_a) + wobble_b * sin(ang * 5.0 + phase_b)
		var r := radius * wobble * randf_range(0.85, 1.05)
		pts.append(Vector2(cos(ang) * r, sin(ang) * r * 0.5))
	splash.polygon = pts
	splash.color = color
	splash.color.a = 0.6
	splash.global_position = pos
	parent.add_child(splash)
	parent.move_child(splash, 0)
	_track_clutter(splash)

## Cached (built once, reused forever) small speck texture: a few overlapping
## off-center soft blobs baked into one image, so each blood particle reads as
## an irregular ink speck instead of CPUParticles2D's default flat quad.
static var _ink_speck_tex: ImageTexture = null

static func _ink_speck_texture() -> ImageTexture:
	if _ink_speck_tex != null:
		return _ink_speck_tex
	var size := 16
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 1.0, 1.0, 0.0))
	var center := Vector2(size, size) * 0.5
	for b in 4:
		var offset := Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
		var r := randf_range(3.5, 6.0)
		for y in size:
			for x in size:
				var d := Vector2(x + 0.5, y + 0.5).distance_to(center + offset)
				if d <= r:
					var a := 1.0 - d / r
					var px := img.get_pixel(x, y)
					img.set_pixel(x, y, Color(1.0, 1.0, 1.0, maxf(px.a, a * a)))
	_ink_speck_tex = ImageTexture.create_from_image(img)
	return _ink_speck_tex

## Torn chunk of the dying unit's own sprite: a random region of `texture`
## drawn on a self-contained Node2D that tumbles, settles, and then stays put
## — permanent ground clutter, not a fading burst (see class doc). Sinks
## beneath living units (move_child 0) like ground_splash. Units with no
## sprite_texture just don't call this (Combatant checks before calling).
static func paper_scrap(parent: Node, pos: Vector2, texture: Texture2D, facing: float, radius: float, art_scale: float = 1.0) -> void:
	if _headless() or parent == null or texture == null:
		return
	var scrap := _PaperScrap.new()
	scrap.texture = texture
	scrap.global_position = pos
	scrap.diameter = radius * 2.0 * art_scale
	scrap.facing = facing
	parent.add_child(scrap)
	parent.move_child(scrap, 0)
	_track_clutter(scrap)

## -- Spawn gate destruction --------------------------------------------------

## Chunky shards + torn portal-art fragments + a bright expansion ring, on top
## of an (already-scaled-up) death_pop. Shards/fragments are permanent ground
## clutter (see class doc); the flash ring is the one transient piece here
## and still self-frees quickly.
static func debris_burst(parent: Node, pos: Vector2, color: Color, texture: Texture2D, radius: float) -> void:
	if _headless() or parent == null:
		return
	_flash_ring(parent, pos, radius)
	var dark := color.darkened(0.35)
	for i in 24:
		var shard := _DebrisShard.new()
		shard.color = color if i % 2 == 0 else dark
		shard.global_position = pos
		shard.throw_dir = Vector2.RIGHT.rotated(randf() * TAU)
		shard.throw_dist = randf_range(120.0, 320.0)
		shard.size = randf_range(6.0, 16.0)
		parent.add_child(shard)
		parent.move_child(shard, 0)
		_track_clutter(shard)
	if texture != null:
		for i in 3:
			paper_scrap(parent, pos + Vector2(randf_range(-12, 12), randf_range(-12, 12)), texture, 1.0 if i % 2 == 0 else -1.0, radius, 1.6)

static func _flash_ring(parent: Node, pos: Vector2, radius: float) -> void:
	var ring := _FlashRing.new()
	ring.global_position = pos
	ring.max_radius = radius * 3.0
	parent.add_child(ring)
	_track(ring)

## -- Hero teleport-in ---------------------------------------------------------

## Beam + expanding ring + upward sparks at a hero's landing spot. Always
## plays (deploy is a rare, low-frequency event, never worth budget-gating).
static func teleport_in(parent: Node, pos: Vector2, color: Color) -> void:
	if _headless() or parent == null:
		return
	var beam := _TeleportBeam.new()
	beam.global_position = pos
	beam.color = color
	parent.add_child(beam)
	_track(beam)

	var sparks := CPUParticles2D.new()
	sparks.global_position = pos
	sparks.emitting = false
	sparks.one_shot = true
	sparks.amount = 22
	sparks.lifetime = 0.5
	sparks.explosiveness = 0.8
	sparks.direction = Vector2.UP
	sparks.spread = 35.0
	sparks.gravity = Vector2(0, -40)
	sparks.initial_velocity_min = 60.0
	sparks.initial_velocity_max = 160.0
	sparks.scale_amount_min = 1.5
	sparks.scale_amount_max = 3.0
	sparks.color = color
	parent.add_child(sparks)
	_track(sparks)
	sparks.emitting = true
	var t := sparks.get_tree().create_timer(sparks.lifetime + 0.1)
	t.timeout.connect(sparks.queue_free)


## -- Internal self-drawing helper node classes -------------------------------

## Expanding white-hot ring used by a gate's debris_burst — same self-freeing
## Node2D-with-_draw pattern as scenes/combat/duo/stomp_wave.gd.
class _FlashRing extends Node2D:
	var max_radius := 100.0
	var _t := 0.0
	const DURATION := 0.35
	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if _t >= DURATION:
			queue_free()
	func _draw() -> void:
		var p := clampf(_t / DURATION, 0.0, 1.0)
		var c := Color(1.0, 0.95, 0.8, 1.0 - p)
		draw_arc(Vector2.ZERO, max_radius * p, 0.0, TAU, 32, c, 6.0, true)
		draw_circle(Vector2.ZERO, max_radius * 0.15 * (1.0 - p), Color(1.0, 1.0, 0.9, (1.0 - p) * 0.8))

## A single rotating, thrown, settling debris chunk for a gate explosion.
## Permanent once it settles — see class doc.
class _DebrisShard extends Node2D:
	var color := Color.WHITE
	var throw_dir := Vector2.RIGHT
	var throw_dist := 200.0
	var size := 10.0
	var _spin_speed := 0.0
	func _ready() -> void:
		_spin_speed = randf_range(-8.0, 8.0)
		# tween_property's target is an absolute value, not a delta — must add
		# the shard's own starting position (global_position was set by the
		# caller before add_child, so `position` here is already resolved into
		# the parent's local space) or every shard converges on the parent's
		# local origin instead of scattering from where it died.
		var start_pos := position
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(self, "position", start_pos + throw_dir * throw_dist, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "rotation", _spin_speed, 0.5)
	func _draw() -> void:
		var h := size * 0.5
		draw_colored_polygon(PackedVector2Array([
			Vector2(-h, -h * 0.6), Vector2(h, -h * 0.3), Vector2(h * 0.6, h), Vector2(-h * 0.8, h * 0.5)
		]), color)

## Torn sprite fragment left behind by a death — draws a random region of the
## source texture and tumbles/hops on spawn. Permanent once it settles — see
## class doc.
class _PaperScrap extends Node2D:
	var texture: Texture2D
	var diameter := 32.0
	var facing := 1.0
	var _region := Rect2()
	var _draw_size := Vector2.ZERO
	func _ready() -> void:
		var tex_size := texture.get_size()
		var region_frac := randf_range(0.4, 0.6)
		var rw := tex_size.x * region_frac
		var rh := tex_size.y * region_frac
		var rx := randf_range(0.0, tex_size.x - rw)
		var ry := randf_range(0.0, tex_size.y - rh)
		_region = Rect2(rx, ry, rw, rh)
		var scale_factor := diameter / maxf(tex_size.x, tex_size.y)
		_draw_size = Vector2(rw, rh) * scale_factor
		scale = Vector2(-facing, 1.0)
		# Same absolute-vs-relative pitfall as _DebrisShard: add the scrap's own
		# starting position or it warps toward the parent's local origin.
		var start_pos := position
		var hop := start_pos + Vector2(randf_range(-70.0, 70.0), -randf_range(40.0, 90.0))
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(self, "position", hop, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "rotation", randf_range(-0.6, 0.6), 0.4)
	func _draw() -> void:
		draw_texture_rect_region(texture, Rect2(-_draw_size * 0.5, _draw_size), _region, Color(1, 1, 1, 0.92))

## Vertical materialize beam + expanding ring for a hero landing on deploy.
class _TeleportBeam extends Node2D:
	var color := Color.WHITE
	var _t := 0.0
	const DURATION := 0.3
	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if _t >= DURATION:
			queue_free()
	func _draw() -> void:
		var p := clampf(_t / DURATION, 0.0, 1.0)
		var beam_h := lerpf(140.0, 10.0, p)
		var beam_w := lerpf(10.0, 46.0, p)
		var c := color
		c.a = (1.0 - p) * 0.85
		draw_rect(Rect2(-beam_w * 0.5, -beam_h, beam_w, beam_h), c, true)
		var ring_c := color
		ring_c.a = 1.0 - p
		draw_arc(Vector2.ZERO, lerpf(10.0, 50.0, p), 0.0, TAU, 28, ring_c, 4.0, true)

## Draws a hand-drawn ability-VFX sprite centred on `at`, sized to `diameter`
## along its longest edge and faded to `alpha` (Designer, 2026-07-25 — the
## ability effects carry real art now instead of plain expanding arcs).
##
## A plain draw helper rather than a spawned node: every caller already has an
## expanding/fading timer of its own driving a _draw(), so this only replaces
## the draw_arc line inside it. Callers pass the ability's REAL radius so the
## art keeps matching the damage area when mods/boons widen it.
static func draw_burst(canvas: CanvasItem, tex: Texture2D, at: Vector2,
		diameter: float, alpha: float) -> void:
	if tex == null or diameter <= 0.0 or alpha <= 0.0:
		return
	var tex_size := tex.get_size()
	var longest := maxf(tex_size.x, tex_size.y)
	if longest <= 0.0:
		return
	var draw_size := tex_size * (diameter / longest)
	canvas.draw_texture_rect(tex, Rect2(at - draw_size * 0.5, draw_size), false,
			Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0)))
