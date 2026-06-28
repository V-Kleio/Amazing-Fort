extends Node2D

## fortress_data will be populated by BuildingPhase and read by AttackingPhase
var fortress_data: Dictionary = {}

func _ready() -> void:
	print("[BuildingPhase] Placeholder")

func _on_continue_pressed() -> void:
	GameEvents.phase_finished.emit("building")
