extends Control
class_name Credits

signal on_close

func _ready() -> void:
	modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)

func _on_close_pressed() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE)
	await tween.finished
	emit_signal("on_close")
	queue_free()
