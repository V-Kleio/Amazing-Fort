extends Control
class_name WinScreen

@export var win_texture: Texture2D
@export var lose_texture: Texture2D
@export var banner_texture: Texture2D

@onready var _character_image: TextureRect = get_node_or_null(^"CenterContainer/CharacterImage")
@onready var _banner_image: TextureRect = get_node_or_null(^"CenterContainer/VBox/BannerImage")
@onready var _result_label: Label = get_node_or_null(^"CenterContainer/VBox/BannerImage/ResultLabel")
@onready var _primary_button: Button = get_node_or_null(^"CenterContainer/VBox/HBox/PrimaryButton")
@onready var _menu_button: Button = get_node_or_null(^"CenterContainer/VBox/HBox/MenuButton")

var is_win: bool = true

func setup(win: bool) -> void:
	is_win = win

func _ready() -> void:
	if _primary_button != null:
		_primary_button.text = "Continue" if is_win else "Replay"
		if not _primary_button.pressed.is_connected(_on_primary_pressed):
			_primary_button.pressed.connect(_on_primary_pressed)
	
	if _menu_button != null:
		if not _menu_button.pressed.is_connected(_on_menu_pressed):
			_menu_button.pressed.connect(_on_menu_pressed)
	
	if _result_label != null:
		_result_label.text = "You Survived!" if is_win else "You Died!"
	
	if _character_image != null:
		_character_image.texture = win_texture if is_win else lose_texture
	
	if _banner_image != null:
		_banner_image.texture = banner_texture

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)

func _on_primary_pressed() -> void:
	await _fade_out()
	if is_win:
		GameManager.next_round()
	else:
		SceneManager.load_level_controller()
	queue_free()

func _on_menu_pressed() -> void:
	await _fade_out()
	SceneManager.load_main_menu()
	queue_free()

func _fade_out() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE)
	await tween.finished
