class_name HealthDisplay
extends Node2D

## A row of hearts showing the Kid's remaining health, driven by GameEvents.kid_damaged.
## Drawn in code: uses `heart_texture` if assigned, else a simple heart shape (so it works
## before art exists). Typically added as a child of the Kid, positioned above its head.

@export var heart_texture: Texture2D
@export var max_hearts: int = 3
@export var spacing: float = 96.0
@export var heart_size: float = 72.0

const FILLED_COLOR: Color = Color(0.96, 0.36, 0.55)
const EMPTY_COLOR: Color = Color(0.32, 0.20, 0.24, 0.7)

var _current: int = 0

func _ready() -> void:
	z_index = 60
	_current = GameManager.player_health
	GameEvents.try_connect(GameEvents.kid_damaged, _on_kid_damaged)
	GameEvents.try_connect(GameEvents.round_started, _on_round_started)
	queue_redraw()

func _on_kid_damaged(remaining: int) -> void:
	_current = remaining
	queue_redraw()
	_pop()

	if _current <= 0:
		visible = false

func _on_round_started(_round_number: int) -> void:
	_current = GameManager.player_health

	visible = true 
	queue_redraw()

func _pop() -> void:
	scale = Vector2.ONE * 1.15
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _draw() -> void:
	var start_x: float = -(max_hearts - 1) * spacing * 0.5
	for i in max_hearts:
		var center: Vector2 = Vector2(start_x + i * spacing, 0.0)
		_draw_heart(center, i < _current)

func _draw_heart(center: Vector2, filled: bool) -> void:
	if heart_texture != null:
		var tint: Color = Color.WHITE if filled else EMPTY_COLOR
		var rect: Rect2 = Rect2(center - Vector2(heart_size, heart_size) * 0.5, Vector2(heart_size, heart_size))
		draw_texture_rect(heart_texture, rect, false, tint)
		return
	# Fallback heart: two lobes + a point.
	var color: Color = FILLED_COLOR if filled else EMPTY_COLOR
	var lobe: float = heart_size * 0.28
	draw_circle(center + Vector2(-lobe, -lobe * 0.5), lobe, color)
	draw_circle(center + Vector2(lobe, -lobe * 0.5), lobe, color)
	var points: PackedVector2Array = PackedVector2Array([
		center + Vector2(-heart_size * 0.5, -lobe * 0.3),
		center + Vector2(heart_size * 0.5, -lobe * 0.3),
		center + Vector2(0.0, heart_size * 0.62),
	])
	draw_colored_polygon(points, color)
