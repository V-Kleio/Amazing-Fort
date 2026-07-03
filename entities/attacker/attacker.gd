extends Node2D

## The attack indicator: a reticle (arrow + projectile icon) that aims at the Kid, then
## launches the ball toward the Kid. The projectile sprite is randomized among a set of
## plushie textures; the same chosen sprite is shown in the reticle AND used for the ball.
##
## Reticle parts are optional & null-guarded:
##   Attacker (Node2D)
##    ├ Arrow (Sprite2D)           points DOWN at rotation 0; rotated to aim at the Kid
##    ├ ProjectileIcon (Sprite2D)  shows the chosen plushie (scaled to icon_max_size)
##    └ Marker2D                   muzzle (ball spawn)

@export var initial_delay: float = 2.0
## Random aim wobble (degrees) added to the straight-at-Kid direction.
@export var aim_spread_deg: float = 8.0
@export var launch_force_min: float = 800.0
@export var launch_force_max: float = 1200.0
@export var ball_scene: PackedScene
## The plushie sprites to randomize between (assign in the editor). Empty = keep ball default.
@export var projectile_sprites: Array[Texture2D] = []
## Largest on-screen size (px) for the reticle icon.
@export var icon_max_size: float = 130.0
## On-screen size (px) the ring/arrow art is scaled to (its .tscn scale is tiny → invisible).
@export var ring_display_size: float = 220.0
## Nudge the plushie icon to sit inside the ring (art-dependent; default centered).
@export var icon_offset: Vector2 = Vector2.ZERO
## On-screen size (px) the fired ball's sprite is scaled to (keeps varied art matching the collider).
@export var projectile_display_size: float = 120.0
@export var launch_sfx: AudioStream
## Unused (kept so the .tscn's assignment doesn't warn); the dotted arc was removed.
@export var trajectory_marker_scene: PackedScene

@onready var marker: Marker2D = $Marker2D
@onready var _arrow: Sprite2D = get_node_or_null(^"Arrow")
@onready var _projectile_icon: Sprite2D = get_node_or_null(^"ProjectileIcon")

var facing_right: bool = true
var final_direction: Vector2
var final_force: float
var ball_instance: RigidBody2D = null
var _chosen_sprite: Texture2D = null

func setup(spawn_on_right_side: bool) -> void:
	facing_right = not spawn_on_right_side

	var origin: Vector2 = marker.global_position if marker != null else global_position
	var dir: Vector2 = _direction_to_kid(origin)
	dir = dir.rotated(deg_to_rad(randf_range(-aim_spread_deg, aim_spread_deg)))

	final_direction = dir
	final_force = randf_range(launch_force_min, launch_force_max)

	_choose_sprite()
	_aim_reticle(dir)
	_set_projectile_icon()
	_scale_reticle()

## Make the reticle art visible (its .tscn scale is tiny) and nudge the icon into the ring.
func _scale_reticle() -> void:
	if _arrow != null and _arrow.texture != null:
		_arrow.scale = _fit_scale(_arrow.texture, ring_display_size)
	if _projectile_icon != null:
		_projectile_icon.position = icon_offset

## Direction from `origin` to the Kid, else a horizontal fallback toward screen center.
func _direction_to_kid(origin: Vector2) -> Vector2:
	var kid: Node2D = get_tree().get_first_node_in_group(&"kid") as Node2D
	if kid != null:
		return (kid.global_position - origin).normalized()
	return Vector2.RIGHT if facing_right else Vector2.LEFT

## Pick a random plushie for this round (used for both the icon and the ball).
func _choose_sprite() -> void:
	if projectile_sprites.is_empty():
		_chosen_sprite = null
	else:
		_chosen_sprite = projectile_sprites[randi() % projectile_sprites.size()]

## Rotate the arrow to point along `dir` (arrow art points down at rotation 0).
func _aim_reticle(dir: Vector2) -> void:
	if _arrow != null:
		_arrow.rotation = dir.angle() - PI / 2.0

## Show the chosen plushie (or the ball's default) in the ring, scaled to a max size.
func _set_projectile_icon() -> void:
	if _projectile_icon == null:
		return
	var texture: Texture2D = _chosen_sprite if _chosen_sprite != null else _read_default_ball_texture()
	if texture == null:
		return
	_projectile_icon.texture = texture
	_projectile_icon.scale = _fit_scale(texture, icon_max_size)

func _read_default_ball_texture() -> Texture2D:
	if ball_scene == null:
		return null
	var temp: Node = ball_scene.instantiate()  # not added to the tree → its _ready won't run
	var sprite: Sprite2D = temp.get_node_or_null(^"Sprite2D") as Sprite2D
	var texture: Texture2D = sprite.texture if sprite != null else null
	temp.free()
	return texture

## Uniform scale so the texture's longest side equals `target` pixels.
func _fit_scale(texture: Texture2D, target: float) -> Vector2:
	var longest: float = maxf(texture.get_width(), texture.get_height())
	if longest <= 0.0:
		return Vector2.ONE
	return Vector2.ONE * (target / longest)

func start_attack_phase() -> void:
	await get_tree().create_timer(initial_delay).timeout
	_fire()

func _fire() -> void:
	ball_instance = ball_scene.instantiate()
	get_tree().current_scene.add_child(ball_instance)
	ball_instance.global_position = marker.global_position
	_apply_ball_sprite(ball_instance)
	ball_instance.fully_stopped.connect(_on_ball_fully_stopped)
	if launch_sfx != null:
		AudioManager.play_sfx(launch_sfx)
	ball_instance.launch(final_direction, final_force)

## Swap the fired ball's sprite to the chosen plushie, scaled to a consistent size.
func _apply_ball_sprite(ball: Node) -> void:
	if _chosen_sprite == null:
		return
	var sprite: Sprite2D = ball.get_node_or_null(^"Sprite2D") as Sprite2D
	if sprite != null:
		sprite.texture = _chosen_sprite
		sprite.scale = _fit_scale(_chosen_sprite, projectile_display_size)

func _on_ball_fully_stopped() -> void:
	GameEvents.ball_stopped.emit()

func cleanup() -> void:
	if ball_instance and is_instance_valid(ball_instance):
		ball_instance.queue_free()
		ball_instance = null
