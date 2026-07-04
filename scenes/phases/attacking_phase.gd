extends Node2D
class_name AttackingPhase

@export var round_duration: float = 15.0

@onready var round_label: Label = $CanvasLayer/Control/RoundLabel

var is_active: bool = false

func _ready() -> void:
	round_label.text = "Round %d" % GameManager.current_round
	is_active = true
	
	# Win is now timeout-only (survive the escalating barrage); ball_stopped no longer ends the round.
	
	var kids = get_tree().get_nodes_in_group(&"kid")
	if kids.size() > 0:
		kids[0].died.connect(resolve_lose)
		
	_start_round_timer()

func _start_round_timer() -> void:
	var timer: SceneTreeTimer = get_tree().create_timer(round_duration)
	timer.timeout.connect(_on_round_timeout)

func _on_round_timeout() -> void:
	if not is_active:
		return
	resolve_win()

func resolve_win() -> void:
	if not is_active:
		return
	is_active = false
	GameEvents.phase_finished.emit("attacking_win")

func resolve_lose() -> void:
	if not is_active:
		return
	is_active = false
	GameEvents.phase_finished.emit("attacking_lose")

func _input(event: InputEvent) -> void:
	if not is_active:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_W:
			resolve_win()
		elif event.keycode == KEY_L:
			resolve_lose()

# Safety no-op: the .tscn still wires a hidden ContinueButton.pressed to this method.
func _on_continue_pressed() -> void:
	pass
