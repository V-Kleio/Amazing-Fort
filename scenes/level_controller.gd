extends Node2D

@export var choosing_phase_scene: PackedScene
@export var building_phase_scene: PackedScene
@export var attacking_phase_scene: PackedScene
@export var win_screen_scene: PackedScene
@export var tutorial_scene: PackedScene
@export var attacker_scene: PackedScene
@export var spawn_offset_range: float = 50.0
## The child the player protects. Spawned once into the persistent Arena.
@export var kid_scene: PackedScene
## Optional floor/walls (StaticBody2D) added to the Arena. Leave empty if not needed yet.
@export var arena_bounds_scene: PackedScene
## The settings overlay opened by the in-game pause button.
@export var settings_scene: PackedScene
## Background track for gameplay; crossfades in (leave empty until you have audio assets).
@export var gameplay_music: AudioStream

## Bottom-center of the 1920x1080 design space (no camera → world coords == screen coords).
const KID_POSITION: Vector2 = Vector2(960.0, 980.0)

@onready var phase_container: Node = $PhaseContainer
@onready var spawn_left: Marker2D = $SpawnPointLeft
@onready var spawn_right: Marker2D = $SpawnPointRight
## Optional in-game pause button (added to the editor HUD; safe if absent).
@onready var _pause_button: Button = get_node_or_null(^"HUD/PauseButton")

var current_phase_node: Node = null
var attacker_instance: Node = null
## Persistent world that survives phase swaps: holds the Kid + all placed furniture.
var arena: Node2D = null
var _settings_open: bool = false

func _ready() -> void:
	GameEvents.try_connect(GameEvents.phase_finished, _on_phase_finished)
	GameEvents.try_connect(GameEvents.game_over, _on_game_over)

	if _pause_button != null:
		_pause_button.pressed.connect(_on_pause_pressed)

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
	_ensure_arena()
	AudioManager.play_music(gameplay_music)
	GameManager.start_game()
	_load_phase(choosing_phase_scene)

## Create the persistent Arena once per session, as a sibling of PhaseContainer so it is
## never freed by _load_phase. Spawns optional bounds + the Kid into it.
func _ensure_arena() -> void:
	if arena != null and is_instance_valid(arena):
		return
	arena = Node2D.new()
	arena.name = "Arena"
	arena.add_to_group(&"arena")
	add_child(arena)

	if arena_bounds_scene != null:
		arena.add_child(arena_bounds_scene.instantiate())

	if kid_scene != null:
		var kid: Node2D = kid_scene.instantiate()
		arena.add_child(kid)
		kid.global_position = KID_POSITION

## Accessor for phases that prefer a direct reference over the &"arena" group lookup.
func get_arena() -> Node2D:
	return arena


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

## Pause the game and open the settings overlay (unpauses on close).
func _on_pause_pressed() -> void:
	if _settings_open or settings_scene == null:
		return
	var settings: Settings = settings_scene.instantiate() as Settings
	if settings == null:
		push_error("LevelController: settings_scene root is not a Settings node.")
		return
	_settings_open = true
	SceneManager.pause_game()
	get_tree().root.add_child(settings)
	settings.on_close.connect(_on_settings_closed)

func _on_settings_closed() -> void:
	_settings_open = false
	SceneManager.unpause_game()
	
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
