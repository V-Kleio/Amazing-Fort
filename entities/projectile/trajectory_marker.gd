extends Node2D

@onready var line: Line2D = $Line2D

@export var max_points: int = 20
@export var time_step: float = 0.1
@export var gravity: float = 980.0


func _ready() -> void:
	line.points = []

func update_trajectory(start_pos: Vector2, direction: Vector2, force: float) -> void:
	var points = []
	var velocity = direction * force
	for i in max_points:
		var t = i * time_step
		var x = velocity.x * t
		var y = velocity.y * t + 0.5 * gravity * t * t
		points.append(Vector2(x, y))
		
	line.points = points
	position = start_pos

func show_trajectory() -> void:
	visible = true

func hide_trajectory() -> void:
	visible = false
