extends Node2D

## Attack indicator + barrage spawner. During Build it aims a reticle at the Kid (a
## telegraph). When combat starts the reticle hides and it fires a stream of balls whose
## fire rate and angle-spread escalate over the round. Balls are in group "enemy_projectile".
##
## Reticle parts (optional, null-guarded): Arrow (Sprite2D), ProjectileIcon (Sprite2D),
## plus Marker2D (muzzle / ball spawn).

@export var initial_delay: float = 1.5
@export var launch_force_min: float = 800.0
@export var launch_force_max: float = 1200.0
@export var ball_scene: PackedScene
## Plushie sprites randomized per shot (assign in editor). Empty = keep ball default.
@export var projectile_sprites: Array[Texture2D] = []
@export var icon_max_size: float = 130.0
## On-screen size (px) of the ring/arrow art (its .tscn scale is tiny → invisible without this).
@export var ring_display_size: float = 220.0
@export var icon_offset: Vector2 = Vector2.ZERO
@export var projectile_display_size: float = 120.0
@export var launch_sfx: AudioStream
## Seconds between shots at the round's start / end (fire rate escalates).
@export var fire_interval_start: float = 2.0
@export var fire_interval_end: float = 0.55
## Aim wobble (deg) at the round's start / end (angle variety escalates).
@export var spread_start: float = 10.0
@export var spread_end: float = 45.0
## Unused (kept so the .tscn's assignment doesn't warn); the dotted arc was removed.
@export var trajectory_marker_scene: PackedScene

@onready var marker: Marker2D = $Marker2D
@onready var _arrow: Sprite2D = get_node_or_null(^"Arrow")
@onready var _projectile_icon: Sprite2D = get_node_or_null(^"ProjectileIcon")

var facing_right: bool = true
var _active: bool = false
var _attack_duration: float = 15.0
var _elapsed: float = 0.0
var _fire_timer: float = 0.0

# --- Build-phase telegraph -------------------------------------------------

func setup(spawn_on_right_side: bool) -> void:
	facing_right = not spawn_on_right_side
	_aim_reticle(_direction_to_kid(_origin()))
	_set_preview_icon()
	_scale_reticle()

func _origin() -> Vector2:
	return marker.global_position if marker != null else global_position

func _direction_to_kid(origin: Vector2) -> Vector2:
	var kid: Node2D = get_tree().get_first_node_in_group(&"kid") as Node2D
	if kid != null:
		return (kid.global_position - origin).normalized()
	return Vector2.RIGHT if facing_right else Vector2.LEFT

func _aim_reticle(dir: Vector2) -> void:
	if _arrow != null:
		_arrow.rotation = dir.angle() - PI / 2.0  # arrow art points down at rotation 0

func _scale_reticle() -> void:
	if _arrow != null and _arrow.texture != null:
		_arrow.scale = _fit_scale(_arrow.texture, ring_display_size)
	if _projectile_icon != null:
		_projectile_icon.position = icon_offset

func _set_preview_icon() -> void:
	if _projectile_icon == null:
		return
	var texture: Texture2D = _random_sprite()
	if texture == null:
		texture = _read_default_ball_texture()
	if texture == null:
		return
	_projectile_icon.texture = texture
	_projectile_icon.scale = _fit_scale(texture, icon_max_size)

# --- Barrage ---------------------------------------------------------------

## Begin the escalating barrage over `duration` seconds. Reticle hides once combat starts.
func start_attack_phase(duration: float = 15.0) -> void:
	_attack_duration = duration
	_hide_reticle()
	await get_tree().create_timer(initial_delay).timeout
	_active = true

func _hide_reticle() -> void:
	if _arrow != null:
		_arrow.visible = false
	if _projectile_icon != null:
		_projectile_icon.visible = false

func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	if _elapsed >= _attack_duration:
		_active = false  # phase timer ends the round; stop spawning
		return
	_fire_timer += delta
	var t: float = clampf(_elapsed / _attack_duration, 0.0, 1.0)
	var interval: float = lerpf(fire_interval_start, fire_interval_end, t)
	if _fire_timer >= interval:
		_fire_timer = 0.0
		_fire(lerpf(spread_start, spread_end, t))

func _fire(spread_deg: float) -> void:
	if ball_scene == null:
		return
	var dir: Vector2 = _direction_to_kid(_origin())
	dir = dir.rotated(deg_to_rad(randf_range(-spread_deg, spread_deg)))
	var force: float = randf_range(launch_force_min, launch_force_max)

	var ball: RigidBody2D = ball_scene.instantiate()
	get_tree().current_scene.add_child(ball)
	ball.global_position = _origin()
	_apply_ball_sprite(ball, _random_sprite())
	if launch_sfx != null:
		AudioManager.play_sfx(launch_sfx, randf_range(0.95, 1.05))
	ball.launch(dir, force)

func cleanup() -> void:
	_active = false

# --- Helpers ---------------------------------------------------------------

func _random_sprite() -> Texture2D:
	if projectile_sprites.is_empty():
		return null
	return projectile_sprites[randi() % projectile_sprites.size()]

func _apply_ball_sprite(ball: Node, sprite: Texture2D) -> void:
	if sprite == null:
		return
	var ball_sprite: Sprite2D = ball.get_node_or_null(^"Sprite2D") as Sprite2D
	if ball_sprite != null:
		ball_sprite.texture = sprite
		ball_sprite.scale = _fit_scale(sprite, projectile_display_size)

func _read_default_ball_texture() -> Texture2D:
	if ball_scene == null:
		return null
	var temp: Node = ball_scene.instantiate()  # not added to the tree → its _ready won't run
	var sprite: Sprite2D = temp.get_node_or_null(^"Sprite2D") as Sprite2D
	var texture: Texture2D = sprite.texture if sprite != null else null
	temp.free()
	return texture

func _fit_scale(texture: Texture2D, target: float) -> Vector2:
	var longest: float = maxf(texture.get_width(), texture.get_height())
	if longest <= 0.0:
		return Vector2.ONE
	return Vector2.ONE * (target / longest)
