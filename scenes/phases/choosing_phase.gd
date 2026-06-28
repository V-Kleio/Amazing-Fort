extends Node2D


func _ready() -> void:
	print("[ChoosingPhase] Placeholder")

func _on_continue_pressed() -> void:
	GameEvents.phase_finished.emit("choosing")
