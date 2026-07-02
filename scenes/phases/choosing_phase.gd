extends Node2D

## Draft phase ("The Toybox"): rolls `offer_count` DraftOptions from the auto-scanned
## pool, shows one editor-built DraftCard per option, applies the player's pick to the
## run (PlayerInventory + events), then advances the loop. Agnostic: never references a
## concrete DraftOption subclass, so new draftable types need no changes here.
##
## UI is authored in choosing_phase.tscn + draft_card.tscn (see docs/draft_setup_guide.html).
## Required layout tree:
##   ChoosingPhase (Node2D)  <- this script
##    └ CanvasLayer
##       └ Control (full rect)
##          ├ TitleLabel (Label)
##          └ CardsContainer (HBoxContainer)

@export var offer_count: int = 3
@export var draft_card_scene: PackedScene

@onready var _title_label: Label = $CanvasLayer/Control/Title
@onready var _cards_container: HBoxContainer = $CanvasLayer/Control/CardsContainer

var _resolved: bool = false

func _ready() -> void:
	_present_draft()

func _present_draft() -> void:
	_title_label.text = "Round %d — Choose Your Draft" % GameManager.current_round

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
		card.card_selected.connect(_on_card_selected)

## Degenerate case only (no options authored yet, or card scene missing): a code-built
## button so the loop can never soft-lock. The real UI is editor-authored.
func _show_empty_fallback() -> void:
	var button: Button = Button.new()
	button.text = "No draft options yet — Continue"
	button.custom_minimum_size = Vector2(380, 72)
	button.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	button.pressed.connect(_finish)
	$CanvasLayer/Control.add_child(button)

func _on_card_selected(option: DraftOption) -> void:
	if _resolved:
		return
	_resolved = true
	option.apply()
	GameEvents.draft_option_selected.emit(option)
	_finish()

func _finish() -> void:
	GameEvents.phase_finished.emit("choosing")

# Safety net during editor migration (harmless once the old ContinueButton is removed).
func _on_continue_pressed() -> void:
	pass
