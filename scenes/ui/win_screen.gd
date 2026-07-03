extends Control
class_name WinScreen

## Result overlay with two buttons:
##   WIN  → ResultLabel "Round N Complete!" · PrimaryButton "Continue" · MenuButton "Main Menu"
##   LOSE → ResultLabel "Defeated!"          · PrimaryButton "Replay"   · MenuButton "Main Menu"
## Continue advances the round; Replay restarts the whole run; Main Menu exits.
## Layout is editor-authored (see docs/hud_result_setup_guide.html); refs are null-guarded.
##   WinScreen (Control) → Background (ColorRect) → Panel → VBox → ResultLabel + PrimaryButton + MenuButton

@onready var _result_label: Label = get_node_or_null(^"Panel/VBox/ResultLabel")
@onready var _primary_button: Button = get_node_or_null(^"Panel/VBox/PrimaryButton")
@onready var _menu_button: Button = get_node_or_null(^"Panel/VBox/MenuButton")

var is_win: bool = true

## Called by level_controller BEFORE add_child, so _ready reads the correct result.
func setup(win: bool) -> void:
	is_win = win

func _ready() -> void:
	if _primary_button != null:
		_primary_button.text = "Continue" if is_win else "Replay"
		_primary_button.pressed.connect(_on_primary_pressed)
	if _menu_button != null:
		_menu_button.text = "Main Menu"
		_menu_button.pressed.connect(_on_menu_pressed)
	if _result_label != null:
		_result_label.text = "Round %d Complete!" % GameManager.current_round if is_win else "Defeated!"

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)

func _on_primary_pressed() -> void:
	await _fade_out()
	if is_win:
		GameManager.next_round()               # advances via level_controller's round loop
	else:
		SceneManager.load_level_controller()   # Replay = fresh run (start_game resets round/health)
	queue_free()

func _on_menu_pressed() -> void:
	await _fade_out()
	SceneManager.load_main_menu()
	queue_free()

func _fade_out() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE)
	await tween.finished
