class_name CoachMark
extends CanvasLayer

## A non-blocking tutorial overlay: a top caption strip + a bobbing pointer hand.
## Built entirely in code and mouse-transparent, so it guides without ever eating input.
## Layer 70 → above the phase UI + HUD, below the DefendTransition (80).

const HAND_SIZE: float = 150.0

## The pointer hand sprite (set by TutorialGuide before add_child; caption-only if null).
var hand_texture: Texture2D
var font = preload("res://assets/fonts/DarumadropOne-Regular.ttf")



var _caption_bg: ColorRect
var _caption: Label
var _hand: TextureRect
var _bob: Tween = null

func _ready() -> void:
	layer = 70
	_build()
	hide_hint()

func _build() -> void:
	_caption_bg = ColorRect.new()
	_caption_bg.color = Color(0.08, 0.08, 0.1, 0.72)
	_caption_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption_bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_caption_bg.offset_top = 120.0
	_caption_bg.offset_bottom = 244.0
	add_child(_caption_bg)

	_caption = Label.new()
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.set_anchors_preset(Control.PRESET_FULL_RECT)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_font_override("font", font)
	_caption.add_theme_font_size_override("font_size", 48)
	_caption_bg.add_child(_caption)

	_hand = TextureRect.new()
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand.texture = hand_texture
	_hand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hand.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hand.custom_minimum_size = Vector2(HAND_SIZE, HAND_SIZE)
	_hand.size = Vector2(HAND_SIZE, HAND_SIZE)
	add_child(_hand)

## Show a caption (always) and, optionally, the bobbing hand centered on `hand_screen_pos`.
func show_hint(hand_screen_pos: Vector2, text: String, show_hand: bool = true) -> void:
	visible = true
	_caption.text = text
	_caption_bg.modulate.a = 0.0
	_caption_bg.create_tween().tween_property(_caption_bg, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE)

	if show_hand and hand_texture != null:
		_hand.visible = true
		_hand.position = hand_screen_pos - _hand.size * 0.5
		_start_bob()
	else:
		_stop_bob()
		_hand.visible = false

func hide_hint() -> void:
	_stop_bob()
	visible = false

func _start_bob() -> void:
	_stop_bob()
	_bob = UIJuice.loop_bob(_hand, 16.0, 0.9)

func _stop_bob() -> void:
	if _bob != null and _bob.is_valid():
		_bob.kill()
	_bob = null
