extends RigidBody2D

@export var max_speed: float = 3000.0
@export var min_bounce_variance: float = 0.85
@export var max_bounce_variance: float = 1.15
@export var random_impulse_strength: float = 400.0
@export var chaos_deflect_deg: float = 35.0
@export var spin_impulse_strength: float = 12.0
@export var acceleration_rate: float = 900.0
@export var collision_decay: float = 0.08
@export var hard_material_boost: float = 1.5
@export var soft_material_damp: float = 0.5

var collision_count: int = 0

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 2
	body_entered.connect(_on_body_entered)

func launch(direction: Vector2, force: float) -> void:
	linear_velocity = direction.normalized() * force
	collision_count = 0

func _on_body_entered(body: Node) -> void:
	var variance = randf_range(min_bounce_variance, max_bounce_variance)
	linear_velocity *= variance
	if body.is_in_group("hard_material"):
		linear_velocity *= hard_material_boost
	elif body.is_in_group("soft_material"):
		linear_velocity *= soft_material_damp
	else:
		collision_count += 1
		linear_velocity *= max(1.0 - collision_decay * collision_count, 0.0)
	linear_velocity = linear_velocity.rotated(deg_to_rad(randf_range(-chaos_deflect_deg, chaos_deflect_deg)))
	var random_direction := Vector2.RIGHT.rotated(randf_range(0, TAU))
	apply_impulse(random_direction * random_impulse_strength)
	apply_torque_impulse(randf_range(-spin_impulse_strength, spin_impulse_strength))

func _physics_process(delta: float) -> void:
	_accelerate(delta)
	_clamp_speed()

func _accelerate(delta: float) -> void:
	if linear_velocity.length() > 0.0:
		linear_velocity += linear_velocity.normalized() * acceleration_rate * delta

func _clamp_speed() -> void:
	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed
