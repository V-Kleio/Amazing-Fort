extends Node2D

@export var choosing_phase_scene: PackedScene
@export var building_phase_scene: PackedScene
@export var attacking_phase_scene: PackedScene
@export var win_screen_scene: PackedScene
@export var tutorial_scene: PackedScene
@export var attacker_scene: PackedScene
@export var spawn_offset_range: float = 50.0

@onready var phase_container: Node = $PhaseContainer
@onready var spawn_left: Marker2D = $SpawnPointLeft
@onready var spawn_right: Marker2D = $SpawnPointRight

var current_phase_node: Node = null
var attacker_instance: Node = null

func _ready() -> void:
	GameEvents.try_connect(GameEvents.phase_finished, _on_phase_finished)
	GameEvents.try_connect(GameEvents.game_over, _on_game_over)

	_show_tutorial_if_needed()

func _show_tutorial_if_needed() -> void:
	if not SaveManager.is_tutorial_completed():
		# Tutorial instantiated on top, blocks input until done
		var tutorial: Node = tutorial_scene.instantiate()
		add_child(tutorial)
		tutorial.tutorial_finished.connect(_on_tutorial_finished)
	else:
		_begin_session()

func _on_tutorial_finished() -> void:
	_begin_session()

func _begin_session() -> void:
	GameManager.start_game()
	_load_phase(choosing_phase_scene)


func _load_phase(scene: PackedScene) -> void:
	if current_phase_node and is_instance_valid(current_phase_node):
		current_phase_node.queue_free()
		await get_tree().process_frame
	current_phase_node = scene.instantiate()
	phase_container.add_child(current_phase_node)

func _on_phase_finished(phase_name: String) -> void:
	match phase_name:
		"choosing":
			GameManager.current_phase = GameManager.Phase.BUILDING
			_load_phase(building_phase_scene)
			_spawn_attacker()
		"building":
			GameManager.current_phase = GameManager.Phase.ATTACKING
			_load_phase(attacking_phase_scene)
			attacker_instance.start_attack_phase()
		"attacking_win":
			_cleanup_attacker()
			_load_win_screen()
		"attacking_lose":
			GameManager.end_game_lose()

func _load_win_screen() -> void:
	if current_phase_node and is_instance_valid(current_phase_node):
		current_phase_node.queue_free()
		await get_tree().process_frame
	var win: Node = win_screen_scene.instantiate()
	phase_container.add_child(win)
	GameEvents.try_connect(GameEvents.round_started, _on_round_continued)

func _on_round_continued(_round_number: int) -> void:
	GameEvents.try_disconnect(GameEvents.round_started, _on_round_continued)
	_cleanup_attacker()
	_load_phase(choosing_phase_scene)

func _on_game_over() -> void:
	SceneManager.load_main_menu()
	
func _spawn_attacker() -> void:
	if attacker_instance and is_instance_valid(attacker_instance):
		return

	attacker_instance = attacker_scene.instantiate()
	add_child(attacker_instance)

	var spawn_on_right: bool = randf() < 0.5
	var base_point: Vector2 = spawn_right.global_position if spawn_on_right else spawn_left.global_position
	var offset := Vector2(
		randf_range(-spawn_offset_range, spawn_offset_range),
		randf_range(-spawn_offset_range, spawn_offset_range)
	)
	attacker_instance.global_position = base_point + offset

	attacker_instance.setup(spawn_on_right)

func _cleanup_attacker() -> void:
	if attacker_instance and is_instance_valid(attacker_instance):
		attacker_instance.cleanup()
		attacker_instance.queue_free()
		attacker_instance = null
