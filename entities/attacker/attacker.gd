extends Node2D

@export var initial_delay: float = 2.0
@export var max_angle_deviation: float = 25.0
@export var launch_force_min: float = 800.0
@export var launch_force_max: float = 1200.0
@export var ball_scene: PackedScene
@export var trajectory_marker_scene: PackedScene

@onready var marker: Marker2D = $Marker2D

var facing_right: bool = true
var final_direction: Vector2
var final_force: float
var trajectory_instance: Node2D


func _ready() -> void:
	pass

func setup(spawn_on_right_side: bool) -> void:
	if spawn_on_right_side:
		scale.x = -1
		facing_right = false
	else:
		scale.x = 1
		facing_right = true

	var base_direction: Vector2 = Vector2.RIGHT if facing_right else Vector2.LEFT
	var deviation: float = randf_range(-max_angle_deviation, max_angle_deviation)
	final_direction = base_direction.rotated(deg_to_rad(deviation))
	final_force = randf_range(launch_force_min, launch_force_max)

	trajectory_instance = trajectory_marker_scene.instantiate()
	get_parent().add_child(trajectory_instance)
	trajectory_instance.update_trajectory(marker.global_position, final_direction, final_force, ball_scene)
	trajectory_instance.show_trajectory()

func start_attack_phase() -> void:
	await get_tree().create_timer(initial_delay).timeout
	_fire()

func _fire() -> void:
	if trajectory_instance and is_instance_valid(trajectory_instance):
		trajectory_instance.hide_trajectory()

	var ball_instance: RigidBody2D = ball_scene.instantiate()
	get_tree().current_scene.add_child(ball_instance)
	ball_instance.global_position = marker.global_position
	ball_instance.launch(final_direction, final_force)

func cleanup() -> void:
	if trajectory_instance and is_instance_valid(trajectory_instance):
		trajectory_instance.queue_free()
		trajectory_instance = null
