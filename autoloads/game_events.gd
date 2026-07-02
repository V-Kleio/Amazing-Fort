extends Node

## Global Signal Bus
## Existing signals
signal commands_executed()
signal block_out_of_bounds_error(block_id: int)
signal no_block_to_modify_error()
signal max_blocks_exceeded_error()
signal level_completed_after_phone_close(level_id: String)
signal level_selected(level_id: String)
signal level_completed(level_id: String)
signal game_paused(is_paused: bool)

## Roguelite phase signals
signal phase_finished(phase_name: String)
signal game_over()
signal game_won()
signal round_started(round_number: int)

## Draft phase signals
signal draft_option_selected(option: DraftOption)
signal upgrade_acquired(option: DraftOption)

## Safely connect if not already connected
func try_connect(sig: Signal, callable: Callable) -> void:
	if not sig.is_connected(callable):
		sig.connect(callable)

## Safely disconnect if connected
func try_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)
