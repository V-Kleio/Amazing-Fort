extends Control

@export var credits_scene: PackedScene
@export var settings_scene: PackedScene
## Background track for the menu; crossfades in (leave empty until you have audio assets).
@export var menu_music: AudioStream

func _ready() -> void:
	AudioManager.play_music(menu_music)

func _on_start_pressed() -> void:
	SceneManager.load_level_controller()

func _on_credits_pressed() -> void:
	if credits_scene:
		var credits: Node = credits_scene.instantiate()
		get_tree().root.add_child(credits)

func _on_settings_pressed() -> void:
	if settings_scene:
		var settings: Node = settings_scene.instantiate()
		get_tree().root.add_child(settings)

func _on_quit_pressed() -> void:
	get_tree().quit()
