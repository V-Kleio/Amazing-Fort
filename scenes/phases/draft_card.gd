class_name DraftCard
extends TextureButton

## Reusable card that renders ANY DraftOption, with playful juice: bouncy deal-in,
## hover/press feedback, idle bob, and select/dismiss animations. ChoosingPhase drives
## the timing (deal-in stagger, then enable_idle; play_selected/play_dismissed on pick).
##
## Property discipline (so tweens never fight, and containers don't re-sort mid-anim):
##   interaction (hover/press/select) → scale · idle → position · deal/dismiss → both + modulate.

signal card_selected(option: DraftOption)

const HOVER_SCALE: float = 1.06
const PRESS_SCALE: float = 0.94
const SELECT_SCALE: float = 1.16
const IDLE_BOB_PIXELS: float = 7.0

## Optional hover sound (editor-assignable; silent until you add audio).
@export var hover_sfx: AudioStream

@onready var _rarity_bar: ColorRect = $Margin/VBox/Rarity
@onready var _name_label: Label = $Margin/VBox/Name
@onready var _icon_rect: TextureRect = $Margin/VBox/Icon
@onready var _description_label: Label = $Margin/VBox/Description

var _option: DraftOption = null
var _interactive: bool = false
var _hovered: bool = false
var _base_position: Vector2 = Vector2.ZERO
var _scale_tween: Tween = null
var _idle_tween: Tween = null

func _ready() -> void:
	# Let taps/clicks fall through the layout nodes to the Button itself.
	for node in Discovery.find_children_of_type(self, Control):
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = custom_minimum_size * 0.5  # scale/rotate from the card's center
	modulate.a = 0.0  # hidden until dealt in
	pressed.connect(_on_pressed)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	if _option != null:
		_apply(_option)

## Populate the card from a DraftOption. Safe to call before or after _ready().
func setup(option: DraftOption) -> void:
	_option = option
	if is_node_ready():
		_apply(option)

func _apply(option: DraftOption) -> void:
	if option == null:
		return
	_name_label.text = option.display_name
	_description_label.text = option.description
	_icon_rect.texture = option.icon
	var accent: Color = option.get_rarity_color()
	_rarity_bar.color = accent
	_name_label.add_theme_color_override("font_color", accent)

# --- Intro / idle (driven by ChoosingPhase) --------------------------------

## Bouncy pop-up into place. Call after the card is positioned by its container.
func play_deal_in() -> void:
	_kill(_scale_tween)
	_base_position = position
	position = _base_position + Vector2(0.0, 90.0)
	scale = Vector2.ONE * 0.8
	modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.35)
	tween.tween_property(self, "position", _base_position, 0.45).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK)

## Begin gentle idle bob and allow interaction. Call once deal-in has settled.
func enable_idle() -> void:
	_interactive = true
	_base_position = position
	_kill(_idle_tween)
	var period: float = randf_range(2.6, 3.4)  # varied so cards drift out of sync
	_idle_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_property(self, "position:y", _base_position.y - IDLE_BOB_PIXELS, period * 0.5)
	_idle_tween.tween_property(self, "position:y", _base_position.y + IDLE_BOB_PIXELS, period * 0.5)

# --- Selection outcome (driven by ChoosingPhase) ---------------------------

func play_selected() -> void:
	_interactive = false
	_kill(_idle_tween)
	_kill(_scale_tween)
	z_index = 1  # lift above the dismissed cards
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
		.tween_property(self, "scale", Vector2.ONE * SELECT_SCALE, 0.28)

func play_dismissed() -> void:
	_interactive = false
	_kill(_idle_tween)
	_kill(_scale_tween)
	var tween: Tween = create_tween().set_parallel(true).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_property(self, "scale", Vector2.ONE * 0.82, 0.3)
	tween.tween_property(self, "position:y", position.y + 80.0, 0.3)

# --- Interaction feedback --------------------------------------------------

func _on_mouse_entered() -> void:
	if not _interactive:
		return
	_hovered = true
	_scale_to(HOVER_SCALE)
	if hover_sfx != null:
		AudioManager.play_sfx(hover_sfx)

func _on_mouse_exited() -> void:
	_hovered = false
	if _interactive:
		_scale_to(1.0)

func _on_button_down() -> void:
	if _interactive:
		_scale_to(PRESS_SCALE)

func _on_button_up() -> void:
	if _interactive:
		_scale_to(HOVER_SCALE if _hovered else 1.0)

func _scale_to(target: float) -> void:
	_kill(_scale_tween)
	_scale_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(self, "scale", Vector2.ONE * target, 0.16)

func _on_pressed() -> void:
	if _interactive and _option != null:
		card_selected.emit(_option)

func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
