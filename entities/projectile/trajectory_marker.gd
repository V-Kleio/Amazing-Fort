extends Node2D

@onready var line: Line2D = $Line2D

@export var max_points: int = 8 
@export var time_step: float = 0.05

func _ready() -> void:
	line.clear_points()

func update_trajectory(start_pos: Vector2, direction: Vector2, force: float, ball_scene: PackedScene) -> void:
	line.clear_points()
	
	if direction.y > 0.3:
		direction.y = 0.3
		direction = direction.normalized()
		
	var velocity: Vector2 = direction * force
	var temp_ball = ball_scene.instantiate()
	var gravity_scale = temp_ball.gravity_scale
	temp_ball.queue_free()
	
	var effective_gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity") * gravity_scale
	
	for i in max_points:
		var t: float = i * time_step
		var x: float = velocity.x * t
		var y: float = velocity.y * t + 0.5 * effective_gravity * t * t
		line.add_point(Vector2(x, y))
		
	global_position = start_pos

func show_trajectory() -> void:
	visible = true

func hide_trajectory() -> void:
	visible = false
