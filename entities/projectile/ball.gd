extends RigidBody2D
class_name Projectile

@export var max_speed: float = 2000.0
@export var min_bounce_variance: float = 0.85
@export var max_bounce_variance: float = 1.15
@export var random_impulse_strength: float = 400.0
@export var chaos_deflect_deg: float = 35.0
@export var spin_impulse_strength: float = 12.0
@export var acceleration_rate: float = 900.0
@export var collision_decay: float = 0.08
@export var hard_material_boost: float = 1.5
@export var soft_material_damp: float = 0.8
@export var stop_linear_threshold: float = 5.0
@export var stop_angular_threshold: float = 0.15
@export var stop_duration_to_win: float = 5.0

signal fully_stopped

var collision_count: int = 0
var _contact_normals: Dictionary = {}
var _stopped_timer: float = 0.0
var _has_won: bool = false
var _can_accelerate: bool = true

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	body_entered.connect(_on_body_entered)

func launch(direction: Vector2, force: float) -> void:
	linear_velocity = direction.normalized() * force
	collision_count = 0
	_stopped_timer = 0.0
	_has_won = false
	_can_accelerate = true

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	_contact_normals.clear()
	for i in state.get_contact_count():
		var body := state.get_contact_collider_object(i)
		if body != null:
			_contact_normals[body.get_instance_id()] = state.get_contact_local_normal(i)

func _on_body_entered(body: Node) -> void:
	var normal: Vector2 = _contact_normals.get(body.get_instance_id(), Vector2.ZERO)
	var variance = randf_range(min_bounce_variance, max_bounce_variance)
	linear_velocity *= variance
	
	var current_impulse: float = random_impulse_strength
	
	if body.is_in_group("hard_material"):
		linear_velocity *= hard_material_boost
	elif body.is_in_group("soft_material"):
		linear_velocity *= soft_material_damp
		_can_accelerate = false
		current_impulse = 0.0 # <-- Impulse dinonaktifkan untuk soft material
	else:
		collision_count += 1
		linear_velocity *= max(1.0 - collision_decay * collision_count, 0.0)
		
	linear_velocity = linear_velocity.rotated(deg_to_rad(randf_range(-chaos_deflect_deg, chaos_deflect_deg)))
	var impulse_direction := normal.rotated(randf_range(-PI * 0.4, PI * 0.4)) if normal != Vector2.ZERO else Vector2.RIGHT.rotated(randf_range(0, TAU))
	
	apply_impulse(impulse_direction * current_impulse)
	apply_torque_impulse(randf_range(-spin_impulse_strength, spin_impulse_strength))
	_stopped_timer = 0.0

func _physics_process(delta: float) -> void:
	_accelerate(delta)
	_clamp_speed()
	_check_fully_stopped(delta)

func _accelerate(delta: float) -> void:
	if collision_count > 0 or not _can_accelerate:
		return
	if linear_velocity.length() > 0.0:
		linear_velocity += linear_velocity.normalized() * acceleration_rate * delta

func _clamp_speed() -> void:
	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed

func _check_fully_stopped(delta: float) -> void:
	if _has_won:
		return
		
	var is_slow: bool = linear_velocity.length() < stop_linear_threshold and abs(angular_velocity) < stop_angular_threshold
	
	if is_slow:
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0
		sleeping = true
		_stopped_timer += delta
		
		if _stopped_timer >= stop_duration_to_win:
			_has_won = true
			fully_stopped.emit()
	else:
		_stopped_timer = 0.0
