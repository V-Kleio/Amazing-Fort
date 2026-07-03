class_name EntityData
extends Resource

## Data-driven physics + behavior for a PlaceableEntity (furniture).
##
## Baked per furniture prefab via `@export var data: EntityData` on the scene. The Build
## phase reads it to configure frozen-placement physics; the Combat phase (a teammate's
## work) reads mass/friction/bounciness/durability/gravity when it calls
## PlaceableEntity.activate_physics(). Adding a new furniture type is just a new .tres.

@export var display_name: String = ""

@export_group("Physics")
## Weight — heavier pieces resist projectile impacts harder.
@export var mass: float = 1.0
## Surface friction (0 = slippery, 1 = grippy). Feeds PhysicsMaterial.friction.
@export_range(0.0, 1.0) var friction: float = 0.6
## Energy retained on impact (0 = no bounce, 1 = very bouncy). Feeds PhysicsMaterial.bounce.
@export_range(0.0, 1.0) var bounciness: float = 0.0
## Gravity multiplier applied once physics activates in Combat.
@export var gravity_scale: float = 1.0
@export var linear_damp: float = 0.0
@export var angular_damp: float = 0.0

@export_group("Combat")
## Impulse/impact the piece can absorb before breaking (read by the Combat phase).
@export var durability: float = 100.0
## If true, the piece won't spin once physics activates.
@export var rotation_locked_in_combat: bool = false

@export_group("Build")
## Whether the rotation ring is offered for this piece during Build.
@export var can_rotate: bool = true
## Rotation-ring radius. 0 = auto-derive from the sprite's extents.
@export var ring_radius: float = 0.0
