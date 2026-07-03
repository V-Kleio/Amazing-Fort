extends Node2D
class_name AttackingPhase

## Player survives if they last this many seconds without losing.
@export var round_duration: float = 30.0

@onready var round_label: Label          = $CanvasLayer/Control/RoundLabel
@onready var result_container: Control   = $CanvasLayer/Control/ResultContainer
@onready var result_label: Label         = $CanvasLayer/Control/ResultContainer/ResultLabel
@onready var continue_button: Button     = $CanvasLayer/Control/ResultContainer/ContinueButton

var is_active: bool = false

func _ready() -> void:
	#result_container.hide()
	round_label.text = "Round %d" % GameManager.current_round
	is_active = true
	continue_button.pressed.connect(func() -> void:
		GameEvents.phase_finished.emit("attacking_win")
	)
	_start_round_timer()

func _start_round_timer() -> void:
	var timer: SceneTreeTimer = get_tree().create_timer(round_duration)
	timer.timeout.connect(_on_round_timeout)

func _on_round_timeout() -> void:
	if not is_active:
		return  # already resolved (win/lose) before timer ran out
	resolve_win()

# TODO: add attack logic
func resolve_win() -> void:
	if not is_active:
		return
	is_active = false
	result_label.text = "You Survived!"
	result_container.show()
	continue_button.pressed.connect(func() -> void:
		GameEvents.phase_finished.emit("attacking_win")
	)

func resolve_lose() -> void:
	if not is_active:
		return
	is_active = false
	result_label.text = "Defeated..."
	result_container.show()
	continue_button.pressed.connect(func() -> void:
		GameEvents.phase_finished.emit("attacking_lose")
	)

# DEBUG
func _input(event: InputEvent) -> void:
	if not is_active:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_W:
			resolve_win()
		elif event.keycode == KEY_L:
			resolve_lose()

func _on_continue_pressed() -> void:
	pass # Replace with function body.
