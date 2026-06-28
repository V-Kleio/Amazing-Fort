extends Node

## Manages scene transitions for the roguelite project.
const SCENE_MAIN_MENU: String = "res://scenes/ui/main_menu.tscn"
const SCENE_LEVEL_CONTROLLER: String = "res://scenes/level_controller.tscn"

@export var transition_duration: float = 0.3

var current_scene: Node = null
var is_transitioning: bool = false
var is_paused: bool = false

var transition_layer: CanvasLayer
var fade_rect: ColorRect

func _ready() -> void:
	var root: Window = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)
	_setup_transition()

func _setup_transition() -> void:
	transition_layer = CanvasLayer.new()
	transition_layer.layer = 100
	transition_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.modulate.a = 0.0
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_layer.add_child(fade_rect)
	add_child(transition_layer)


# Navigation
func load_main_menu() -> void:
	change_scene(SCENE_MAIN_MENU)

func load_level_controller() -> void:
	change_scene(SCENE_LEVEL_CONTROLLER)


# Transition
func change_scene(scene_path: String) -> void:
	if is_transitioning:
		return
	if is_paused:
		toggle_pause()
	is_transitioning = true
	await _fade_out()
	_deferred_change_scene(scene_path)
	await get_tree().process_frame
	await _fade_in()
	is_transitioning = false

func _fade_out() -> void:
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(fade_rect, "modulate:a", 1.0, transition_duration)
	await tween.finished

func _fade_in() -> void:
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(fade_rect, "modulate:a", 0.0, transition_duration)
	await tween.finished
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _deferred_change_scene(scene_path: String) -> void:
	if current_scene:
		current_scene.free()
	var new_scene: PackedScene = load(scene_path)
	if new_scene:
		current_scene = new_scene.instantiate()
		get_tree().root.add_child(current_scene)
		get_tree().current_scene = current_scene
	else:
		push_error("Failed to load scene: " + scene_path)


# Pause
func toggle_pause() -> void:
	is_paused = not is_paused
	get_tree().paused = is_paused
	GameEvents.game_paused.emit(is_paused)

func pause_game() -> void:
	if not is_paused:
		toggle_pause()

func unpause_game() -> void:
	if is_paused:
		toggle_pause()
