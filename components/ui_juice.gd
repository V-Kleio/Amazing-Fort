class_name UIJuice
extends RefCounted

## Reusable, stateless UI "juice" helpers — gentle tweens for entrances, idle motion, and
## touch feedback. Each creates a tween owned by the passed node (so it's freed with the
## node). Tuned subtle: TRANS_SINE / TRANS_CUBIC EASE_OUT, no overshoot. Usable on any
## Control (main menu now; win screen / others later).
##
## Property discipline (so concurrent tweens never fight over one property):
##   idle bob → position · idle breathe → scale · press feedback → modulate or scale.

## Move a control's scale/rotation pivot to its center. Call before any scale effect
## (sizes are only final after the first layout pass — await a frame first).
static func center_pivot(control: Control) -> void:
	control.pivot_offset = control.size * 0.5

## Fade + slide a control in from `offset`, settling at its authored position.
static func fade_slide_in(control: Control, offset: Vector2, delay: float = 0.0, dur: float = 0.5) -> void:
	var target: Vector2 = control.position
	control.position = target + offset
	control.modulate.a = 0.0
	var tween: Tween = control.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "position", target, dur).set_delay(delay)
	tween.tween_property(control, "modulate:a", 1.0, dur).set_delay(delay)

## Fade + scale a control in (needs a centered pivot). `bouncy` = springy overshoot.
static func pop_in(control: Control, delay: float = 0.0, dur: float = 0.45, from_scale: float = 0.9, bouncy: bool = false) -> void:
	control.scale = Vector2.ONE * from_scale
	control.modulate.a = 0.0
	var trans: int = Tween.TRANS_BACK if bouncy else Tween.TRANS_CUBIC
	var tween: Tween = control.create_tween().set_parallel(true).set_trans(trans).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, dur).set_delay(delay)
	tween.tween_property(control, "modulate:a", 1.0, dur).set_delay(delay)

## Endless gentle vertical bob around the control's current position.
static func loop_bob(control: Control, pixels: float = 5.0, period: float = 3.0) -> Tween:
	var base_y: float = control.position.y
	var tween: Tween = control.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(control, "position:y", base_y - pixels, period * 0.5)
	tween.tween_property(control, "position:y", base_y + pixels, period * 0.5)
	return tween

## Endless gentle scale pulse (needs a centered pivot).
static func loop_breathe(control: Control, amount: float = 0.025, period: float = 2.2) -> Tween:
	var tween: Tween = control.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(control, "scale", Vector2.ONE * (1.0 + amount), period * 0.5)
	tween.tween_property(control, "scale", Vector2.ONE, period * 0.5)
	return tween

## Dim a button briefly while held (touch-friendly; uses modulate so it won't fight a scale idle).
static func press_modulate(button: BaseButton, dim: float = 0.9) -> void:
	button.button_down.connect(func() -> void:
		button.create_tween().tween_property(button, "modulate", Color(dim, dim, dim, 1.0), 0.06)
	)
	button.button_up.connect(func() -> void:
		button.create_tween().tween_property(button, "modulate", Color.WHITE, 0.12)
	)

## Squash a button slightly while held (needs a centered pivot; use only where there's no scale idle).
static func press_scale(button: BaseButton, down: float = 0.97) -> void:
	button.button_down.connect(func() -> void:
		button.create_tween().tween_property(button, "scale", Vector2.ONE * down, 0.06)
	)
	button.button_up.connect(func() -> void:
		button.create_tween().tween_property(button, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE)
	)
