extends Node2D

## Draft phase ("The Toybox"): rolls `offer_count` DraftOptions, deals one juicy DraftCard
## per option, applies the player's pick, then advances. Agnostic: never references a
## concrete DraftOption subclass, so new draftable types need no changes here.
##
## UI authored in choosing_phase.tscn + draft_card.tscn. Layout:
##   ChoosingPhase (Node2D)
##    └ CanvasLayer → Control (full rect)
##       ├ Bocil (TextureRect), Title (Label), CardsContainer (HBoxContainer)

@export var offer_count: int = 3
@export var draft_card_scene: PackedScene
## Optional sounds (editor-assignable; silent until you add audio).
@export var deal_sfx: AudioStream
@export var select_sfx: AudioStream

const CARD_STAGGER: float = 0.12

@onready var _title_label: Label = $CanvasLayer/Control/Title
@onready var _cards_container: HBoxContainer = $CanvasLayer/Control/CardsContainer
@onready var _bocil: TextureRect = $CanvasLayer/Control/Bocil

var _cards: Array[DraftCard] = []
var _resolved: bool = false
var _bocil_breathe: Tween = null

func _ready() -> void:
	_present_draft()

func _present_draft() -> void:
	_title_label.text = "I wonder what to build now, hehe"

	var options: Array[DraftOption] = DraftPool.from_directory().roll(offer_count)
	if options.is_empty() or draft_card_scene == null:
		if draft_card_scene == null:
			push_error("ChoosingPhase: draft_card_scene is not assigned in the inspector.")
		_show_empty_fallback()
		return

	for option in options:
		var card: DraftCard = draft_card_scene.instantiate() as DraftCard
		_cards_container.add_child(card)
		card.setup(option)
		card.card_selected.connect(_on_card_selected.bind(card))
		_cards.append(card)

	_run_intro()

## Speech-bubble pop → Bocil comes alive → deal the cards one by one → enable idle.
func _run_intro() -> void:
	await get_tree().process_frame  # let the container position the cards first

	UIJuice.center_pivot(_title_label)
	UIJuice.pop_in(_title_label, 0.0, 0.4, 0.8, true)

	#_setup_bocil()

	for card in _cards:
		card.play_deal_in()
		AudioManager.play_sfx(deal_sfx, randf_range(0.96, 1.06))
		await get_tree().create_timer(CARD_STAGGER).timeout

	await get_tree().create_timer(0.45).timeout  # let the last card land
	for card in _cards:
		card.enable_idle()

func _setup_bocil() -> void:
	if _bocil == null:
		return
	if _bocil.texture != null:
		_bocil.pivot_offset = _bocil.texture.get_size() * 0.5  # breathe/tilt from the art's center
	_bocil_breathe = UIJuice.loop_breathe(_bocil, 0.02, 3.2)

## A little rotational reaction when the player commits (breathe keeps running underneath).
func _bocil_react() -> void:
	if _bocil == null:
		return
	var tween: Tween = _bocil.create_tween()
	tween.tween_property(_bocil, "rotation", 0.06, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_bocil, "rotation", 0.0, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _on_card_selected(option: DraftOption, chosen: DraftCard) -> void:
	if _resolved:
		return
	_resolved = true

	AudioManager.play_sfx(select_sfx)
	_bocil_react()
	for card in _cards:
		if card == chosen:
			card.play_selected()
		else:
			card.play_dismissed()

	await get_tree().create_timer(0.45).timeout  # let the selection moment play
	option.apply()
	GameEvents.draft_option_selected.emit(option)
	_finish()

func _finish() -> void:
	GameEvents.phase_finished.emit("choosing")

## Degenerate case only (no options authored yet, or card scene missing): a code-built
## button so the loop can never soft-lock. The real UI is editor-authored.
func _show_empty_fallback() -> void:
	var button: Button = Button.new()
	button.text = "No draft options yet — Continue"
	button.custom_minimum_size = Vector2(380, 72)
	button.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	button.pressed.connect(_finish)
	$CanvasLayer/Control.add_child(button)

# Safety net during editor migration (harmless once the old ContinueButton is removed).
func _on_continue_pressed() -> void:
	pass
