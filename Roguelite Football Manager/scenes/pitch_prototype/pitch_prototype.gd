extends Node2D

## Visual pitch view: top-down pitch + 11-a-side placeholder characters laid
## out per real Formation resources (reused from resources/formation.gd /
## formation_library.gd, not invented here). Used two ways:
## - Standalone (scenes/pitch_prototype/pitch_prototype.tscn run directly):
##   _ready() defaults both sides to a sample formation for visual testing.
## - Embedded in scenes/live_match (via a SubViewport): live_match.gd calls
##   configure() with the real LiveMatchState formations/lineups, then
##   play_kick() / update_lineup() / update_formation() as match events fire.
## Sprite art is uniform per side (only one idle/run/kick character exists
## per team in the asset pack), so Player identity is only tracked to know
## which pitch slot to react on — not to change how a slot looks.

const FRAME_SIZE: Vector2i = Vector2i(100, 103)
const IDLE_FRAME_COUNT: int = 4
const RUN_FRAME_COUNT: int = 4
const KICK_FRAME_COUNT: int = 9

const IDLE_FPS: float = 4.0
const RUN_FPS: float = 8.0
const KICK_FPS: float = 12.0

const IDLE_DURATION: float = 2.0
const RUN_DURATION: float = 1.5

## Player display height target (~1.2x the sprite sheet's native character
## content height of ~33px) so the character reads as "a little bigger"
## than the ~24px ball, per Designer sign-off. Art-only scale, not a
## gameplay balance value.
const PLAYER_SCALE: float = 1.2

const TILE_PIXELS: int = 16
const TILE_SCALE: int = 2
const FIELD_COLS: int = 40
const BORDER_ROWS_PER_SIDE: int = 2
const GRASS_ROWS: int = 26

## Sample formation used when run standalone (not embedded in Live Match).
const SAMPLE_FORMATION_INDEX: int = 1 # "Solid Defense (4-4-2)"

const CATEGORY_ORDER: Array = [Formation.SlotCategory.GK, Formation.SlotCategory.DEF, Formation.SlotCategory.MID, Formation.SlotCategory.FWD]
const CATEGORY_DEPTH_FRACTION: Dictionary = {
	Formation.SlotCategory.GK: 0.06,
	Formation.SlotCategory.DEF: 0.28,
	Formation.SlotCategory.MID: 0.52,
	Formation.SlotCategory.FWD: 0.80,
}
const ROW_MARGIN_RATIO: float = 0.08

## Extra breathing room (px, pre-zoom) added around the field when fitting
## the camera, so lines/goals never sit flush against the viewport edge.
const CAMERA_PADDING: float = 12.0

const KICK_TRAVEL_SECONDS: float = 0.35
const KICK_HOLD_SECONDS: float = 0.15
const KICK_RETURN_SECONDS: float = 0.35

enum State { IDLE, RUN, KICK }

@onready var pitch: TileMapLayer = $Pitch
@onready var grass: ColorRect = $Grass
@onready var markings: Node2D = $Markings
@onready var goals: Node2D = $Goals
@onready var ball: Sprite2D = $Ball
@onready var home_team: Node2D = $HomeTeam
@onready var away_team: Node2D = $AwayTeam
@onready var camera: Camera2D = $Camera2D

var _states: Dictionary = {}
var _timers: Dictionary = {}

var _grass_rect: Rect2 = Rect2()
var _field_center: Vector2 = Vector2.ZERO
var _home_frames: SpriteFrames
var _away_frames: SpriteFrames

var _home_lineup: Array = []
var _away_lineup: Array = []
var _home_formation: Formation = null
var _away_formation: Formation = null
## Which end the home side currently attacks. Flips at half-time (real
## football swaps ends each half) — away always attacks the opposite end.
var _home_attacks_right: bool = true
var _ball_tween: Tween = null

## While a kick/shot tween owns the ball sprite's position, update_ball_state
## must not also write to it (both run every frame and would fight over the
## same property) — this flag lets update_ball_state skip the position write
## and only keep updating the air/ground visual (modulate/offset).
var _ball_animation_active: bool = false

## Milestone 14: Expose grass rect for movement system init.
func get_grass_rect() -> Rect2:
	return _grass_rect


func _ready() -> void:
	_home_frames = _build_sprite_frames("res://assets/soccorpia/home_idle.png", "res://assets/soccorpia/home_run.png", "res://assets/soccorpia/home_kick.png")
	_away_frames = _build_sprite_frames("res://assets/soccorpia/away_idle.png", "res://assets/soccorpia/away_run.png", "res://assets/soccorpia/away_kick.png")

	var field_pixel_w: float = FIELD_COLS * TILE_PIXELS * TILE_SCALE
	var field_pixel_h: float = (BORDER_ROWS_PER_SIDE * 2 + GRASS_ROWS) * TILE_PIXELS * TILE_SCALE
	var grass_top: float = BORDER_ROWS_PER_SIDE * TILE_PIXELS * TILE_SCALE
	_grass_rect = Rect2(0.0, grass_top, field_pixel_w, GRASS_ROWS * TILE_PIXELS * TILE_SCALE)

	grass.position = _grass_rect.position
	grass.size = _grass_rect.size
	markings.set_field_rect(_grass_rect)
	goals.set_field_rect(_grass_rect)

	_field_center = Vector2(field_pixel_w / 2.0, field_pixel_h / 2.0)
	ball.position = _field_center
	camera.position = _field_center
	camera.enabled = true

	for sprite in home_team.get_children():
		sprite.sprite_frames = _home_frames
		sprite.scale = Vector2(PLAYER_SCALE, PLAYER_SCALE)
		sprite.animation_finished.connect(_on_animation_finished.bind(sprite))
		_states[sprite] = State.IDLE
		_timers[sprite] = randf() * IDLE_DURATION
		sprite.play("idle")
	for sprite in away_team.get_children():
		sprite.sprite_frames = _away_frames
		sprite.scale = Vector2(PLAYER_SCALE, PLAYER_SCALE)
		sprite.animation_finished.connect(_on_animation_finished.bind(sprite))
		_states[sprite] = State.IDLE
		_timers[sprite] = randf() * IDLE_DURATION
		sprite.play("idle")

	var sample_formation: Formation = FormationLibrary.get_all()[SAMPLE_FORMATION_INDEX]
	configure(sample_formation, [], sample_formation, [])

	call_deferred("_update_camera_fit")
	get_viewport().size_changed.connect(_update_camera_fit)


## Lays out both sides per their formation and remembers each slot's Player
## (may contain nulls/be empty, as with the standalone sample) so later
## events can look up which pitch slot to react on.
func configure(home_formation: Formation, home_lineup: Array, away_formation: Formation, away_lineup: Array) -> void:
	_home_lineup = home_lineup.duplicate()
	_away_lineup = away_lineup.duplicate()
	_home_formation = home_formation
	_away_formation = away_formation
	_place_team(home_team, home_formation, _home_attacks_right)
	_place_team(away_team, away_formation, not _home_attacks_right)


## Call when a home substitution lands — updates which Player occupies the
## slot so a later goal_scored lookup resolves correctly. Visual appearance
## is unchanged (both starters and subs share the same placeholder sprite).
func update_lineup(slot_index: int, incoming: Player) -> void:
	if slot_index >= 0 and slot_index < _home_lineup.size():
		_home_lineup[slot_index] = incoming


## Call when the home side changes formation mid-match — re-lays-out the
## home team's 11 sprites into the new shape.
func update_formation(new_formation: Formation, new_lineup: Array) -> void:
	_home_lineup = new_lineup.duplicate()
	_home_formation = new_formation
	_place_team(home_team, new_formation, _home_attacks_right)


## Half-time end swap: re-lays-out both sides on their new attacking end and
## flips which goal a scored shot flies toward. Called once, right when the
## second half kicks off.
func set_attacking_sides(home_attacks_right: bool) -> void:
	_home_attacks_right = home_attacks_right
	if _home_formation != null:
		_place_team(home_team, _home_formation, _home_attacks_right)
	if _away_formation != null:
		_place_team(away_team, _away_formation, not _home_attacks_right)


## Milestone 14: Update player positions per frame from movement system.
func update_player_positions(movement_system: PlayerMovementSystem) -> void:
	var home_children: Array = home_team.get_children()
	var away_children: Array = away_team.get_children()
	for i in home_children.size():
		var pos: Vector2 = movement_system.get_player_position(true, i)
		home_children[i].position = pos
		var speed: float = movement_system.get_player_movement_speed(true, i)
		_update_player_animation_speed(home_children[i], speed)
	for i in away_children.size():
		var pos: Vector2 = movement_system.get_player_position(false, i)
		away_children[i].position = pos
		var speed: float = movement_system.get_player_movement_speed(false, i)
		_update_player_animation_speed(away_children[i], speed)


## Milestone 14: Update ball rendering based on ball state (height/color).
## Skips the position write while a kick/shot tween is animating the ball
## (see _ball_animation_active) so the two don't fight over the same frame.
func update_ball_state(ball_state: BallState) -> void:
	if not _ball_animation_active:
		ball.position = ball_state.position
	if ball_state.in_air:
		ball.modulate = Color.WHITE  ## Bright when in air.
		ball.offset = Vector2(0, -20)  ## Raised visually.
	else:
		ball.modulate = Color(0.7, 0.7, 0.7)  ## Darkened when on ground.
		ball.offset = Vector2(0, 0)  ## At ground level.


## Milestone 17: the ball's actual flight (passer -> receiver, or passer ->
## interception point) is already driven every frame by BallState via
## update_ball_state (PossessionSystem._update_pass_flight interpolates
## position each frame over the real pass duration) — so this only adds the
## passer's visual follow-through, not the ball movement itself.
func animate_pass(is_home: bool, passer: Player, _receiver: Player, _start_pos: Vector2, _end_pos: Vector2, _duration: float) -> void:
	var lineup: Array = _home_lineup if is_home else _away_lineup
	var team: Node2D = home_team if is_home else away_team
	var index: int = lineup.find(passer) if passer != null else -1
	if index == -1 or index >= team.get_children().size():
		return
	var sprite: AnimatedSprite2D = team.get_children()[index]
	_timers[sprite] = 0.0
	_states[sprite] = State.KICK
	sprite.play("kick")


## Update animation speed based on movement velocity.
func _update_player_animation_speed(sprite: AnimatedSprite2D, speed: float) -> void:
	if speed > 0.5:
		if _states.get(sprite) != State.RUN:
			_states[sprite] = State.RUN
			_timers[sprite] = 0.0
			sprite.play("run")
	elif speed > 0.0:
		if _states.get(sprite) == State.KICK:
			return
		_states[sprite] = State.RUN
		sprite.play("run")
	else:
		if _states.get(sprite) != State.KICK:
			_states[sprite] = State.IDLE
			_timers[sprite] = 0.0
			sprite.play("idle")


## Call on a goal_scored event — forces the scorer's sprite into its kick
## animation and sends the ball toward the goal that side attacks. Silently
## does nothing if the scorer can't be resolved to a pitch slot (e.g. no
## scorer, as with an empty lineup).
func play_kick(is_home: bool, scorer: Player) -> void:
	_animate_shot(is_home, scorer)


## Same ball-flight/kick visual as play_kick, for a shot that didn't score
## (saved/off target). The asset pack has no distinct "save" animation, so
## the visual is identical either way — only the score/event text differs.
func play_shot_attempt(is_home: bool, shooter: Player) -> void:
	_animate_shot(is_home, shooter)


func _animate_shot(is_home: bool, player: Player) -> void:
	var lineup: Array = _home_lineup if is_home else _away_lineup
	var team: Node2D = home_team if is_home else away_team
	var index: int = lineup.find(player) if player != null else -1
	if index != -1 and index < team.get_children().size():
		var sprite: AnimatedSprite2D = team.get_children()[index]
		_timers[sprite] = 0.0
		_states[sprite] = State.KICK
		sprite.play("kick")

	var team_attacks_right: bool = _home_attacks_right if is_home else not _home_attacks_right
	var target_x: float = _grass_rect.end.x if team_attacks_right else _grass_rect.position.x
	var target: Vector2 = Vector2(target_x, _grass_rect.get_center().y)
	if _ball_tween != null and _ball_tween.is_running():
		_ball_tween.kill()
	## Own the ball sprite's position for the flight; PossessionSystem has
	## already set BallState to a loose ball at `target` (a goalmouth
	## scramble), so handing back to state-driven updates at the end lands
	## almost exactly where the tween left it — no visible snap.
	_ball_animation_active = true
	_ball_tween = create_tween()
	_ball_tween.tween_property(ball, "position", target, KICK_TRAVEL_SECONDS)
	_ball_tween.tween_callback(func(): _ball_animation_active = false)


func _place_team(team: Node2D, formation: Formation, attacks_right: bool) -> void:
	var positions: Array = _compute_formation_positions(formation, _grass_rect, attacks_right)
	var children: Array = team.get_children()
	for i in children.size():
		children[i].position = positions[i] if i < positions.size() else positions[positions.size() - 1]


func _compute_formation_positions(formation: Formation, field_rect: Rect2, attacks_right: bool) -> Array:
	var counts: Dictionary = {}
	var seen: Dictionary = {}
	for category in CATEGORY_ORDER:
		counts[category] = formation.get_count(category)
		seen[category] = 0

	var positions: Array = []
	positions.resize(formation.slots.size())
	for i in formation.slots.size():
		var category = formation.slots[i]
		var count: int = counts[category]
		var depth_fraction: float = CATEGORY_DEPTH_FRACTION[category]
		var x: float
		if attacks_right:
			x = field_rect.position.x + depth_fraction * (field_rect.size.x / 2.0)
		else:
			x = field_rect.end.x - depth_fraction * (field_rect.size.x / 2.0)
		var top: float = field_rect.position.y + field_rect.size.y * ROW_MARGIN_RATIO
		var usable_height: float = field_rect.size.y * (1.0 - 2.0 * ROW_MARGIN_RATIO)
		var idx_in_row: int = seen[category]
		seen[category] += 1
		var t: float = 0.5 if count <= 1 else (idx_in_row + 0.5) / float(count)
		positions[i] = Vector2(x, top + t * usable_height)
	return positions


## Fits the whole pitch inside whatever viewport this scene is rendered
## into (the full window when run standalone, a smaller SubViewport when
## embedded in Live Match) without ever zooming in past native scale.
## Pads the fit by the goal frames' protrusion (they're drawn outside the
## grass rect, at each end) plus a little breathing room, so a tight
## width- or height-constrained fit doesn't clip them off-screen.
##
## Camera2D.zoom scales world units *up* into screen pixels (screen_px =
## world_units * zoom) — a *higher* zoom value magnifies (zooms IN), it
## does not zoom out. To fit a field of a given size into a viewport, the
## zoom must be vp_size / field_size (smaller of the two axes, so neither
## overflows), capped at 1.0 so it's never magnified past native scale.
func _update_camera_fit() -> void:
	var field_pixel_w: float = FIELD_COLS * TILE_PIXELS * TILE_SCALE
	var field_pixel_h: float = (BORDER_ROWS_PER_SIDE * 2 + GRASS_ROWS) * TILE_PIXELS * TILE_SCALE
	var vp_size: Vector2 = get_viewport_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return
	var padded_w: float = field_pixel_w + 2.0 * (goals.GOAL_DEPTH + CAMERA_PADDING)
	var padded_h: float = field_pixel_h + 2.0 * CAMERA_PADDING
	var zoom_factor: float = min(vp_size.x / padded_w, vp_size.y / padded_h, 1.0)
	camera.zoom = Vector2(zoom_factor, zoom_factor)


func _process(delta: float) -> void:
	for sprite in _states.keys():
		_timers[sprite] += delta
		var state: State = _states[sprite]
		if state == State.IDLE and _timers[sprite] >= IDLE_DURATION:
			_timers[sprite] = 0.0
			_states[sprite] = State.RUN
			sprite.play("run")
		elif state == State.RUN and _timers[sprite] >= RUN_DURATION:
			_timers[sprite] = 0.0
			_states[sprite] = State.KICK
			sprite.play("kick")


func _on_animation_finished(sprite: AnimatedSprite2D) -> void:
	if _states.get(sprite) == State.KICK:
		_timers[sprite] = 0.0
		_states[sprite] = State.IDLE
		sprite.play("idle")


func _build_sprite_frames(idle_path: String, run_path: String, kick_path: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	_add_animation(frames, "idle", idle_path, IDLE_FRAME_COUNT, IDLE_FPS, true)
	_add_animation(frames, "run", run_path, RUN_FRAME_COUNT, RUN_FPS, true)
	_add_animation(frames, "kick", kick_path, KICK_FRAME_COUNT, KICK_FPS, false)
	return frames


func _add_animation(frames: SpriteFrames, anim_name: String, sheet_path: String, frame_count: int, fps: float, loops: bool) -> void:
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, fps)
	frames.set_animation_loop(anim_name, loops)

	var sheet: Texture2D = load(sheet_path)
	for i in range(frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * FRAME_SIZE.x, 0, FRAME_SIZE.x, FRAME_SIZE.y)
		frames.add_frame(anim_name, atlas)
