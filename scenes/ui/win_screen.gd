extends Control
class_name WinScreen

@onready var round_label: Label = $ContentVBox/RoundLabel
@onready var continue_button: Button = $ContinueButton

func _ready() -> void:
	round_label.text      = "Round %d Complete!" % GameManager.current_round
	continue_button.text  = "Continue to Round %d" % (GameManager.current_round + 1)
	modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)

func _on_continue_pressed() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE)
	await tween.finished
	GameManager.next_round()
	queue_free()
