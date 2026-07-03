class_name DefendTransition
extends CanvasLayer

## Comic-book "DEFEND YOURSELF!" splash shown between Build and Attack. The Background
## covers the screen so the level can swap phases behind it: emits `covered` once it's
## hiding everything, then slams its parts in, holds, fades out, and emits `finished`.
##
## Required node tree (see docs/transition_setup_guide.html) — parts are optional and
## null-guarded, so you can wire only the ones you have:
##   DefendTransition (CanvasLayer, layer 80)  <- this script
##    └ Root (Control, full rect)              <- fade target
##       ├ Background (TextureRect, full rect, opaque — covers the swap)
##       ├ Triangle / Character / Title / SpeechBubble (TextureRect parts)

signal covered
signal finished

## Optional slam sound played when the title lands.
@export var impact_sfx: AudioStream

const HOLD_TIME: float = 1.5

@onready var _root: Control = $Root
@onready var _background: TextureRect = get_node_or_null(^"Root/Background")
@onready var _triangle: TextureRect = get_node_or_null(^"Root/Triangle")
@onready var _character: TextureRect = get_node_or_null(^"Root/Character")
@onready var _title: TextureRect = get_node_or_null(^"Root/Title")
@onready var _speech_bubble: TextureRect = get_node_or_null(^"Root/SpeechBubble")

var _can_skip: bool = false
var _skipped: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 80
	# Pre-hide the animated parts so they don't flash before the entrance plays.
	for part in [_triangle, _character, _title, _speech_bubble]:
		if part != null:
			part.modulate.a = 0.0
	_play()

func _play() -> void:
	# 1) Background covers the screen → tell the caller it's safe to swap phases behind us.
	await get_tree().process_frame
	await get_tree().process_frame
	_can_skip = true
	covered.emit()

	# 2) Slam the parts in (playful, staggered).
	if _character != null:
		UIJuice.fade_slide_in(_character, Vector2(-180.0, 0.0), 0.0, 0.35)
	if _triangle != null:
		_center_pivot(_triangle)
		UIJuice.pop_in(_triangle, 0.05, 0.3, 0.7, true)
	if _title != null:
		_slam_in(_title)
	if impact_sfx != null:
		AudioManager.play_sfx(impact_sfx)
	_shake_root()
	if _speech_bubble != null:
		_center_pivot(_speech_bubble)
		UIJuice.pop_in(_speech_bubble, 0.3, 0.25, 0.5, true)

	# 3) Hold (tap to skip), then fade out and finish.
	await _hold_or_skip()
	await _fade_out()
	finished.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if not _can_skip:
		return
	var tapped: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if tapped:
		_skipped = true
		get_viewport().set_input_as_handled()

# --- Helpers ---------------------------------------------------------------

func _slam_in(control: Control) -> void:
	_center_pivot(control)
	control.modulate.a = 0.0
	control.scale = Vector2.ONE * 1.8
	var tween: Tween = control.create_tween().set_parallel(true).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, 0.12)
	tween.tween_property(control, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)

func _shake_root(strength: float = 12.0, steps: int = 5) -> void:
	if _root == null:
		return
	var base: Vector2 = _root.position
	var tween: Tween = _root.create_tween()
	for i in steps:
		var offset: Vector2 = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
		tween.tween_property(_root, "position", base + offset, 0.03)
	tween.tween_property(_root, "position", base, 0.03)

func _hold_or_skip() -> void:
	var timer: SceneTreeTimer = get_tree().create_timer(HOLD_TIME)
	while timer.time_left > 0.0 and not _skipped:
		await get_tree().process_frame

func _fade_out() -> void:
	if _root == null:
		return
	var tween: Tween = _root.create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	await tween.finished

func _center_pivot(control: Control) -> void:
	var extent: Vector2 = control.size
	if extent == Vector2.ZERO and control is TextureRect and (control as TextureRect).texture != null:
		extent = (control as TextureRect).texture.get_size()
	control.pivot_offset = extent * 0.5
