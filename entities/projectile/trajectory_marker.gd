extends Node2D

@onready var line: Line2D = $Line2D
@export var max_points: int = 20
@export var time_step: float = 0.05


func _ready() -> void:
	line.points = []

func update_trajectory(start_pos: Vector2, direction: Vector2, force: float, ball_scene: PackedScene) -> void:
	var points = []
	var velocity = direction * force
	var temp_ball = ball_scene.instantiate()
	var gravity_scale = temp_ball.gravity_scale
	temp_ball.queue_free()
	var effective_gravity = ProjectSettings.get_setting("physics/2d/default_gravity") * gravity_scale
	
	for i in max_points:
		var t = i * time_step
		var x = velocity.x * t
		var y = velocity.y * t + 0.5 * effective_gravity * t * t
		points.append(Vector2(x, y))

	print("Jumlah titik: ", points.size())
	print("Titik-titik: ", points)
	line.points = points
	position = start_pos

func show_trajectory() -> void:
	visible = true

func hide_trajectory() -> void:
	visible = false
