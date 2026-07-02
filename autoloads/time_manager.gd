extends Node

## Simplified TimeManager - handles time scale and time-aware delays

var time_scale: float = 1.0:
	set(value):
		time_scale = clamp(value, 0.0, 10.0)
		Engine.time_scale = time_scale

func _ready() -> void:
	print("[TIME MANAGER] Initialized")

## Create a time-scale-aware timer (returns Timer node)
func create_timer(duration: float) -> Timer:
	var timer: Timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	add_child(timer)
	timer.start()
	return timer

## Async wait with time scale awareness (use with await)
func wait(duration: float) -> void:
	var timer: Timer = create_timer(duration)
	await timer.timeout
	timer.queue_free()

## Pause the game (sets time scale to 0)
func pause() -> void:
	time_scale = 0.0

## Resume the game (sets time scale to 1)
func resume() -> void:
	time_scale = 1.0

## Check if game is paused
func is_paused() -> bool:
	return time_scale == 0.0

## Set time scale to slow motion
func set_slow_motion(scale: float = 0.5) -> void:
	time_scale = scale