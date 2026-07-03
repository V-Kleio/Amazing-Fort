extends RigidBody2D

@export var max_speed: float = 1500.0
@export var min_bounce_variance: float = 0.7
@export var max_bounce_variance: float = 0.95
@export var random_impulse_strength: float = 50.0


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 2
	body_entered.connect(_on_body_entered)

func launch(direction: Vector2, force: float) -> void:
	linear_velocity = direction.normalized() * force

func _on_body_entered(body: Node) -> void:
	var variance = randf_range(min_bounce_variance, max_bounce_variance)
	linear_velocity *= variance
	var random_direction := Vector2.RIGHT.rotated(randf_range(0, TAU))
	apply_impulse(random_direction * random_impulse_strength)

func _physics_process(delta: float) -> void:
	_clamp_speed()

func _clamp_speed() -> void:
	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed
