extends Node2D

@export var choosing_phase_scene: PackedScene
@export var building_phase_scene: PackedScene
@export var attacking_phase_scene: PackedScene
@export var win_screen_scene: PackedScene
@export var tutorial_scene: PackedScene
## The child the player protects. Spawned once into the persistent Arena.
@export var kid_scene: PackedScene
## Optional floor/walls (StaticBody2D) added to the Arena. Leave empty if not needed yet.
@export var arena_bounds_scene: PackedScene

## Bottom-center of the 1920x1080 design space (no camera → world coords == screen coords).
const KID_POSITION: Vector2 = Vector2(960.0, 980.0)

@onready var phase_container: Node = $PhaseContainer

var current_phase_node: Node = null
## Persistent world that survives phase swaps: holds the Kid + all placed furniture.
var arena: Node2D = null

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
	_ensure_arena()
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
		"building":
			GameManager.current_phase = GameManager.Phase.ATTACKING
			_load_phase(attacking_phase_scene)
		"attacking_win":
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
	_load_phase(choosing_phase_scene)

func _on_game_over() -> void:
	SceneManager.load_main_menu()
