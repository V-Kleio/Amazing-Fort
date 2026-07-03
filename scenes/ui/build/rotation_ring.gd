class_name RotationRing
extends Node2D

## The dotted circle drawn around a selected placeable. The player drags around it to
## rotate the piece (free rotation). Rendered with _draw() because Line2D has no dashing
## in Godot 4.6. Created in code by BuildPlacementController; not a scene.

const RING_COLOR: Color = Color(1.0, 1.0, 1.0, 0.7)
const KNOB_COLOR: Color = Color(1.0, 0.85, 0.2, 1.0)
const DOT_RADIUS: float = 5.0
const KNOB_RADIUS: float = 11.0

## Pixel tolerance around the ring line counted as "grabbing the ring" (for hit-testing).
const BAND: float = 32.0

@export var radius: float = 120.0
@export var dot_count: int = 24

var _handle_angle: float = 0.0

func _ready() -> void:
	z_index = 100  # draw above furniture sprites

## Position the ring on a piece and size it. Call whenever selection changes.
func configure(center: Vector2, ring_radius: float, angle: float) -> void:
	global_position = center
	radius = ring_radius
	_handle_angle = angle
	visible = true
	queue_redraw()

func set_handle_angle(angle: float) -> void:
	_handle_angle = angle
	queue_redraw()

## True if a world-space point lands on the ring band (used to start rotation).
func is_on_ring(world_point: Vector2) -> bool:
	if not visible:
		return false
	return absf(world_point.distance_to(global_position) - radius) <= BAND

func _draw() -> void:
	for i in dot_count:
		var angle: float = TAU * float(i) / float(dot_count)
		draw_circle(Vector2(cos(angle), sin(angle)) * radius, DOT_RADIUS, RING_COLOR)
	var knob: Vector2 = Vector2(cos(_handle_angle), sin(_handle_angle)) * radius
	draw_circle(knob, KNOB_RADIUS, KNOB_COLOR)
