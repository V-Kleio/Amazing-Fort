class_name PlaceableEntity
extends RigidBody2D

## A piece of furniture the player places during Build.
##
## Frozen (non-falling) with active colliders during Build; a teammate's Combat phase
## calls activate_physics() to drop it into the sim. Behavior is data-driven via
## EntityData, so a new furniture type is just a new scene reusing this script + a .tres.
##
## Required node tree (see docs/build_setup_guide.html):
##   PlaceableEntity (RigidBody2D)  <- this script
##    ├ Sprite2D
##    ├ CollisionShape2D            (physics shape; Furniture layer)
##    └ OverlapArea (Area2D)        (build-time overlap probe; FurnitureOverlap layer)
##       └ CollisionShape2D         (>= body shape + ~2px skin)

const TINT_VALID: Color = Color(0.55, 1.0, 0.55, 0.9)
const TINT_INVALID: Color = Color(1.0, 0.45, 0.45, 0.9)

@export var data: EntityData

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _overlap_area: Area2D = $OverlapArea

var durability: float = 100.0

## Real-time overlap count driven by OverlapArea signals (freeze-independent, not stale).
var _overlap_count: int = 0

func _ready() -> void:
	add_to_group(&"placeable")
	input_pickable = false  # placement uses physics point queries, not CollisionObject picking

	_overlap_area.area_entered.connect(_on_overlap_added)
	_overlap_area.area_exited.connect(_on_overlap_removed)
	_overlap_area.body_entered.connect(_on_overlap_added)
	_overlap_area.body_exited.connect(_on_overlap_removed)

	_apply_data()
	set_build_mode(true)

## Configure physics from the injected EntityData (safe when data is null → engine defaults).
func _apply_data() -> void:
	if data == null:
		return
	mass = data.mass
	durability = data.durability
	linear_damp = data.linear_damp
	angular_damp = data.angular_damp
	var material: PhysicsMaterial = PhysicsMaterial.new()
	material.friction = data.friction
	material.bounce = data.bounciness
	physics_material_override = material

# --- Build-phase API -------------------------------------------------------

## Frozen, gravity-free, colliders + overlap probe active. Called on spawn.
func set_build_mode(_enabled: bool) -> void:
	freeze = true
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	gravity_scale = 0.0
	_overlap_area.monitoring = true

func is_overlapping() -> bool:
	return _overlap_count > 0

func set_tint(valid: bool) -> void:
	_sprite.modulate = TINT_VALID if valid else TINT_INVALID

func clear_tint() -> void:
	_sprite.modulate = Color.WHITE

## Ring radius for this piece: explicit from data, else auto from the sprite's extents.
func get_ring_radius() -> float:
	if data != null and data.ring_radius > 0.0:
		return data.ring_radius
	if _sprite != null and _sprite.texture != null:
		var extents: Vector2 = _sprite.texture.get_size() * _sprite.scale.abs() * 0.5
		return maxf(extents.x, extents.y) * 1.25
	return 120.0

# --- Combat-phase handoff (called by the teammate's Combat phase) ----------

## Drop the piece into the live physics sim: stop the build-time overlap probe and
## restore dynamic physics from the EntityData.
func activate_physics() -> void:
	_overlap_area.set_deferred("monitoring", false)
	_overlap_area.set_deferred("monitorable", false)
	if data != null:
		gravity_scale = data.gravity_scale
		lock_rotation = data.rotation_locked_in_combat
	else:
		gravity_scale = 1.0
	freeze = false

# --- Internals -------------------------------------------------------------

func _on_overlap_added(_other: Node) -> void:
	_overlap_count += 1

func _on_overlap_removed(_other: Node) -> void:
	_overlap_count = maxi(0, _overlap_count - 1)
