class_name Settings
extends CanvasLayer

## Mobile settings overlay: Master/Music/SFX volume sliders, a Mute-all toggle, and a
## Replay-Tutorial button. Binds to AudioManager (applies live, persists on close) and
## SaveManager. A CanvasLayer (layer 90) so it sits above in-game HUDs; PROCESS_MODE_ALWAYS
## so it works while the game is paused. The opener handles pausing/unpausing.
##
## Required node tree (see docs/audio_settings_setup_guide.html):
##   Settings (CanvasLayer, layer 90)  <- this script
##    └ Root (Control, full rect)      <- fade target
##       ├ Background (ColorRect)
##       └ Panel (PanelContainer) → VBox (VBoxContainer)
##          ├ TitleLabel (Label)
##          ├ MasterRow (HBoxContainer) → Label + MasterSlider (HSlider)
##          ├ MusicRow  (HBoxContainer) → Label + MusicSlider (HSlider)
##          ├ SfxRow    (HBoxContainer) → Label + SfxSlider (HSlider)
##          ├ MuteRow   (HBoxContainer) → Label + MuteToggle (CheckButton)
##          ├ ResetTutorialButton (Button)
##          └ CloseButton (Button)

signal on_close

@onready var _root: Control = $Root
@onready var _master_slider: HSlider = $Root/Panel/VBox/MasterRow/MasterSlider
@onready var _music_slider: HSlider = $Root/Panel/VBox/MusicRow/MusicSlider
@onready var _sfx_slider: HSlider = $Root/Panel/VBox/SfxRow/SfxSlider
@onready var _mute_toggle: CheckButton = $Root/Panel/VBox/MuteRow/MuteToggle
@onready var _reset_tutorial_button: Button = $Root/Panel/VBox/ResetTutorialButton
@onready var _close_button: Button = $Root/Panel/VBox/CloseButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Initialize controls from persisted state BEFORE connecting (avoids spurious applies).
	_master_slider.value = AudioManager.get_master_volume()
	_music_slider.value = AudioManager.get_music_volume()
	_sfx_slider.value = AudioManager.get_sfx_volume()
	_mute_toggle.button_pressed = AudioManager.is_muted()

	_master_slider.value_changed.connect(AudioManager.apply_master_volume)
	_music_slider.value_changed.connect(AudioManager.apply_music_volume)
	_sfx_slider.value_changed.connect(AudioManager.apply_sfx_volume)
	_mute_toggle.toggled.connect(AudioManager.set_muted)
	_reset_tutorial_button.pressed.connect(_on_reset_tutorial_pressed)
	_close_button.pressed.connect(_on_close_pressed)

	_root.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(_root, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)

func _on_reset_tutorial_pressed() -> void:
	SaveManager.reset_tutorial()
	_reset_tutorial_button.disabled = true
	_reset_tutorial_button.text = "Tutorial will replay"

func _on_close_pressed() -> void:
	# Persist the final slider values (they were only applied live while dragging).
	AudioManager.set_master_volume(_master_slider.value)
	AudioManager.set_music_volume(_music_slider.value)
	AudioManager.set_sfx_volume(_sfx_slider.value)

	var tween: Tween = create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE)
	await tween.finished
	on_close.emit()
	queue_free()
