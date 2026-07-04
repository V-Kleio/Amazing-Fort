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
const HIT_TINT: Color = Color(1.0, 0.6, 0.6)
## Min seconds between damage instances on one piece (prevents multi-contact spam from one pass).
const DAMAGE_COOLDOWN: float = 0.2

@export var data: EntityData
## Optional sound played when the piece breaks.
@export var break_sfx: AudioStream

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _overlap_area: Area2D = $OverlapArea

var durability: float = 100.0

## Real-time overlap count driven by OverlapArea signals (freeze-independent, not stale).
var _overlap_count: int = 0
## Sprite's authored scale, captured so juice pops can return to it.
var _base_sprite_scale: Vector2 = Vector2.ONE
## Combat durability state.
var _max_durability: float = 100.0
var _is_broken: bool = false
var _damage_cd_left: float = 0.0

func _ready() -> void:
	add_to_group(&"placeable")
	input_pickable = false
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	# Also collide with the Kid (layer 3) so pieces rest against it instead of passing through.
	set_collision_mask_value(3, true)
	_base_sprite_scale = _sprite.scale
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
	_max_durability = data.durability
	linear_damp = data.linear_damp
	angular_damp = data.angular_damp
	var material: PhysicsMaterial = PhysicsMaterial.new()
	material.friction = data.friction
	material.bounce = data.bounciness
	physics_material_override = material
	# Optional group so the ball's bounce logic reacts to this piece in combat.
	if data.combat_material_group != &"":
		add_to_group(data.combat_material_group)

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
		var extents: Vector2 = _sprite.texture.get_size() * _base_sprite_scale.abs() * 0.5
		return maxf(extents.x, extents.y) * 1.25
	return 120.0

# --- Juice -----------------------------------------------------------------

## Pop the sprite in from small (called when a piece is freshly spawned).
func play_spawn_pop() -> void:
	if _sprite == null:
		return
	_sprite.scale = _base_sprite_scale * 0.6
	_sprite.create_tween().tween_property(_sprite, "scale", _base_sprite_scale, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Quick squash-and-settle "thunk" (called when a piece is committed into place).
func play_commit_pop() -> void:
	if _sprite == null:
		return
	var tween: Tween = _sprite.create_tween()
	_sprite.scale = _base_sprite_scale
	tween.tween_property(_sprite, "scale", _base_sprite_scale * Vector2(1.18, 0.86), 0.07).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_sprite, "scale", _base_sprite_scale, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# --- Combat-phase handoff (called by the teammate's Combat phase) ----------

## Drop the piece into the live physics sim: stop the build-time overlap probe and
## restore dynamic physics from the EntityData.
func activate_physics() -> void:
	_overlap_area.set_deferred("monitoring", false)
	_overlap_area.set_deferred("monitorable", false)
	if data != null and data.anchored_in_combat:
		# Stays put: a static obstacle projectiles bounce off, but it won't fall.
		freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
		freeze = true
		return
	# Default: dynamic — falls, collides, and gets knocked around by projectiles.
	if data != null:
		gravity_scale = data.gravity_scale
		lock_rotation = data.rotation_locked_in_combat
	else:
		gravity_scale = 1.0
	freeze = false

# --- Combat damage ---------------------------------------------------------

func _process(delta: float) -> void:
	if _damage_cd_left > 0.0:
		_damage_cd_left -= delta

## Take projectile damage. A short cooldown stops one pass from multi-hitting; below
## broken_threshold the sprite swaps to its cracked version; at 0 the piece breaks.
func take_damage(amount: float) -> void:
	if amount <= 0.0 or _damage_cd_left > 0.0:
		return
	_damage_cd_left = DAMAGE_COOLDOWN
	durability -= amount
	_flash_hit()
	if durability <= 0.0:
		_break()
		return
	var threshold: float = data.broken_threshold if data != null else 0.3
	if not _is_broken and durability <= _max_durability * threshold \
			and data != null and data.broken_texture != null:
		_is_broken = true
		_sprite.texture = data.broken_texture

func _flash_hit() -> void:
	if _sprite == null:
		return
	_sprite.modulate = HIT_TINT
	_sprite.create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.2).set_trans(Tween.TRANS_SINE)

func _break() -> void:
	GameEvents.furniture_removed.emit(self)
	if break_sfx != null:
		AudioManager.play_sfx(break_sfx)
	# Disable collisions + physics, play a shrink+fade, then free.
	collision_layer = 0
	collision_mask = 0
	freeze = true
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_sprite, "scale", _base_sprite_scale * 0.2, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.18)
	await tween.finished
	queue_free()

# --- Internals -------------------------------------------------------------

func _on_overlap_added(_other: Node) -> void:
	_overlap_count += 1

func _on_overlap_removed(_other: Node) -> void:
	_overlap_count = maxi(0, _overlap_count - 1)
