extends Control
class_name Tutorial

signal tutorial_finished

# TODO: GANTI DUMMY
const STEPS: Array[String] = [
	"Welcome! Let's learn how to play.",
	"Phase 1 - Choose items for your fortress.",
	"Phase 2 - Build your fortress before the wave!",
	"Phase 3 - Defend against the attack!",
	"You're ready. Good luck!",
]

var current_step: int = 0

@onready var step_label: Label = $StepContainer/StepLabel
@onready var next_button: Button = $NextButton
@onready var skip_button: Button = $SkipButton

func _ready() -> void:
	_update_step()

func _update_step() -> void:
	step_label.text  = STEPS[current_step]
	next_button.text = "Finish!" if current_step >= STEPS.size() - 1 else "Next"

func _on_next_pressed() -> void:
	if current_step >= STEPS.size() - 1:
		_finish()
	else:
		current_step += 1
		_update_step()

func _on_skip_pressed() -> void:
	_finish()

func _finish() -> void:
	SaveManager.complete_tutorial()
	emit_signal("tutorial_finished")
	queue_free()
