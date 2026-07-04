class_name TutorialGuide
extends Node

## First-run coaching. Points a hand + caption at each key action through the player's
## first round (draft → build → play → survive), non-blocking, driven entirely by GameEvents,
## then marks the tutorial complete. Created by level_controller on the first run; owns a
## CoachMark; survives phase swaps as a Level child (it needs no phase references).

## Screen-space anchors (1920x1080, no camera). Tune to taste.
const CARDS_ANCHOR: Vector2 = Vector2(1200.0, 760.0)
const INVENTORY_ANCHOR: Vector2 = Vector2(960.0, 1050.0)
const PLAY_ANCHOR: Vector2 = Vector2(1850.0, 230.0)
## Rough time for the DEFEND splash to clear before the final caption.
const TRANSITION_WAIT: float = 3.0

var hand_texture: Texture2D

var _coach: CoachMark = null
var _placed_once: bool = false
var _done: bool = false

func _ready() -> void:
	_coach = CoachMark.new()
	_coach.hand_texture = hand_texture
	add_child(_coach)

	GameEvents.try_connect(GameEvents.phase_finished, _on_phase_finished)
	GameEvents.try_connect(GameEvents.draft_option_selected, _on_drafted)
	GameEvents.try_connect(GameEvents.furniture_placed, _on_placed)

	_show_draft_hint()

func _show_draft_hint() -> void:
	await get_tree().create_timer(0.6).timeout  # let the choosing phase settle / deal cards
	if _done:
		return
	_coach.show_hint(CARDS_ANCHOR, "Tap a card to draft an item!")

func _on_drafted(_option: DraftOption) -> void:
	if _done:
		return
	_coach.hide_hint()  # the building phase begins on phase_finished("choosing")

func _on_placed(_entity: PlaceableEntity) -> void:
	if _done or _placed_once:
		return
	_placed_once = true
	_coach.show_hint(PLAY_ANCHOR, "Press Play to start the attack!")

func _on_phase_finished(phase_name: String) -> void:
	if _done:
		return
	match phase_name:
		"choosing":
			await get_tree().create_timer(0.5).timeout  # let the building phase load
			if _done:
				return
			_placed_once = false
			_coach.show_hint(INVENTORY_ANCHOR, "Drag furniture out to shield your kid!")
		"building":
			# Core loop is taught once Play is pressed → mark complete now.
			SaveManager.complete_tutorial()
			_coach.hide_hint()
			await get_tree().create_timer(TRANSITION_WAIT).timeout  # past the DEFEND splash
			if _done:
				return
			_coach.show_hint(Vector2.ZERO, "Survive — protect your hearts!", false)
			await get_tree().create_timer(3.0).timeout
			_finish()
		"attacking_win", "attacking_lose":
			_finish()  # safety: a fast round ends before the survive caption

func _finish() -> void:
	if _done:
		return
	_done = true
	if not SaveManager.is_tutorial_completed():
		SaveManager.complete_tutorial()
	if _coach != null:
		_coach.hide_hint()
	queue_free()
