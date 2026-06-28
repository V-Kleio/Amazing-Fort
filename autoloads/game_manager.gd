extends Node

## Runtime game state for the current roguelite session.
## Resets each new game

enum Phase { CHOOSING, BUILDING, ATTACKING }

var current_round: int = 0
var current_phase: Phase = Phase.CHOOSING
var player_health: int = 3
var is_game_active: bool = false

func start_game() -> void:
	current_round  = 1
	player_health  = 3
	is_game_active = true
	current_phase  = Phase.CHOOSING
	GameEvents.round_started.emit(current_round)

func next_round() -> void:
	current_round += 1
	current_phase  = Phase.CHOOSING
	GameEvents.round_started.emit(current_round)

func take_damage(amount: int = 1) -> void:
	player_health -= amount
	if player_health <= 0:
		end_game_lose()

func end_game_lose() -> void:
	is_game_active = false
	GameEvents.game_over.emit()

func end_game_win() -> void:
	is_game_active = false
	GameEvents.game_won.emit()
