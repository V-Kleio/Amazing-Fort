extends Control

@export var credits_scene: PackedScene
@export var settings_scene: PackedScene
## Background track for the menu; crossfades in (leave empty until you have audio assets).
@export var menu_music: AudioStream

@onready var _title: TextureRect = $Title
@onready var _bocil: TextureRect = $Bocil
@onready var _start_button: TextureButton = $StartButton
@onready var _settings_button: Button = $SettingsButton

func _ready() -> void:
	AudioManager.play_music(menu_music)
	_animate_menu()

## Subtle entrance + idle life + touch feedback (see components/ui_juice.gd).
func _animate_menu() -> void:
	await get_tree().process_frame  # let anchored sizes/positions settle
	UIJuice.center_pivot(_start_button)
	UIJuice.center_pivot(_settings_button)

	# Entrances (staggered, gentle).
	UIJuice.fade_slide_in(_title, Vector2(0.0, -60.0), 0.0, 0.5)
	UIJuice.fade_slide_in(_bocil, Vector2(-120.0, 0.0), 0.1, 0.5)
	UIJuice.pop_in(_start_button, 0.28, 0.45)
	UIJuice.pop_in(_settings_button, 0.42, 0.4, 0.92)

	# Touch feedback (Start owns scale via breathe → use modulate; Settings has no idle → scale).
	UIJuice.press_modulate(_start_button)
	UIJuice.press_scale(_settings_button)

	# Idle loops begin once the entrances have settled.
	await get_tree().create_timer(0.95).timeout
	UIJuice.loop_bob(_title, 5.0, 3.0)
	UIJuice.loop_bob(_bocil, 4.0, 3.6)
	UIJuice.loop_breathe(_start_button, 0.025, 2.2)

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
