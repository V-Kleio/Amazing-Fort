# IMPORTANT
1. DO NOT Modify godot sensitive files such as .tscn and .tres
2. If we need to use the godot game engine interface, after generating code, generate an html file detailing what to do in detailed step by step manner

# Amazing Fort - Guide

## Architecture Paradigm
**Code-First, Component-Driven, and Event-Oriented**.

## Core Rules (ALWAYS Follow)

1. **Code-First Behavior**: Logic belongs in scripts, not the editor. Use `@onready` wiring over editor connections.
   ```gdscript
   # CORRECT - Code-first wiring
   @onready var sprite: AnimatedSprite2D = %AnimatedSprite2D

   # WRONG - Editor signal connections
   # Never connect signals via editor Inspector
   ```

2. **Composition over Inheritance**: Use small, specialized components instead of deep class hierarchies.
   ```gdscript
   # CORRECT - Attach LightEmitterComponent + CollisionToggler
   # WRONG - class Player extends Entity extends Creature
   ```

3. **Discovery Pattern**: Components find dependencies using unique names (`%NodeName`) or [Discovery.gd](../shared/utils/Discovery.gd).
   ```gdscript
   # For parent-child relationships (tight coupling acceptable)
   @onready var sprite: Sprite2D = %PlayerSprite

   # For sibling components
   var light: LightEmitterComponent = Discovery.get_component(self, LightEmitterComponent)

   # For finding parents
   var level: Node2D = Discovery.find_parent_of_type(self, Node2D)
   ```

4. **Resources for Data**: Use custom Resource classes (`.tres`) for all tweakable variables and stats.
   ```gdscript
   # WRONG - Hardcoded values
   const JUMP_POWER = 600.0

   # CORRECT - Resource-driven data
   @export var stats: FrogStats  # Resource with jump_power property
   ```

5. **Signals as Glue**: Use [GameEvents](../autoloads/game_events.gd) Global Signal Bus for cross-component communication.
   ```gdscript
   # WRONG - Direct references
   get_node("../UI/Score").add_score(100)

   # CORRECT - Event-driven decoupling
   GameEvents.firefly_collected.emit()
   ```

6. **Typed GDScript**: Always use static typing (`var x: int = 0`).

7. **Tooling**: Use `@tool` and `_get_configuration_warnings()` to provide editor feedback.
   ```gdscript
   @tool
   class_name LightEmitterComponent
   extends Node2D

   func _get_configuration_warnings() -> PackedStringArray:
       if not data:
           return ["LightEmitterData resource is required!"]
       return []
   ```

## GameEvents Signal Bus Pattern
GameEvents.gd enforces three rules:
1. **Passive Listeners**: Connect in `_ready()`
2. **Anonymous Emitters**: Emit without knowing listeners
3. **Typed Parameters**: `signal light_updated(light_id: String, position: Vector2, ...)`

## Discovery Utility for Component Wiring
Discovery.gd provides static methods for type-safe node queries:

```gdscript
# Find sibling components (same parent)
var light: LightEmitterComponent = Discovery.get_component(self, LightEmitterComponent)

# Walk up scene tree
var level: Node2D = Discovery.find_parent_of_type(self, Node2D)

# Find children recursively
var lights: Array[Node] = Discovery.find_children_of_type(self, LightEmitterComponent)
```

## Critical Anti-Patterns (NEVER Do This)

```gdscript
# Direct node path dependencies
var player = get_node("../../Player")

# Editor signal connections (code-first only!)
# (no signal connections in Inspector)

# Hardcoded constants instead of resources
const SPEED = 300.0

# Untyped variables
var damage = 10

# Using Engine.time_scale directly (use TimeManager)
Engine.time_scale = 0.5
```

# The Game

## 1. The Elevator Pitch
**Logline:** A 2D mobile physics-puzzle auto-battler where players draft household junk to build the ultimate pillow fort, then watch in real-time as physics-driven sibling warfare tests their architectural genius.
**The Vibe:** *Amazing Alex* meets *World of Goo*, wrapped in the nostalgic, chaotic imagination of a childhood fort. 

## 2. Core Pillars & The MDA Framework
If you are generating systems, code, or content for this game, every decision must serve these pillars:

*   **Aesthetics (The Target Emotion):** Nostalgic creativity and hilarious chaos. The player should feel like a methodical architect during the build phase, and an excited spectator during the combat phase.
*   **Dynamics (The Play Experience):** Emergent physics destruction. Losing shouldn't feel frustrating; it should look funny. The tension comes from gravity and impulse forces interacting with the player's custom geometry.
*   **Mechanics (The Rules):** Modular, data-driven entity components. Strict separation between the "time-frozen" building phase and the "dynamic physics" combat phase. 

## 3. The Core Gameplay Loop
The game operates in an endless micro-roguelite structure:
1.  **Drafting (The Toybox):** Choose 1 of 3 randomized bundles of items (Anchors, Props, Blankets) or physics-modifying Relics.
2.  **Building (The Architect):** Time and gravity are paused. Players drag, drop, and rotate items around their "Kid" avatar to build a shelter. Indicators show where incoming attacks will spawn.
3.  **Combat (The Sibling Siege):** Time resumes. Gravity activates. AI spawns projectiles from the screen edges. The player watches as an auto-battler. If the Kid's 3 HP is depleted, the run ends.

## 4. Thematic & Art Direction Guardrails
When suggesting new items, enemies, or modifiers, adhere to these thematic rules:
*   **No Lethal Weapons:** Enemies are siblings or imaginary monsters. Projectiles are Nerf darts, rolled-up socks, paper airplanes, or RC cars. 
*   **Household Architecture:** Building materials are strictly items found in a 1990s/2000s living room or bedroom (Couch cushions, encyclopedias, broomsticks, folding chairs, laundry baskets).
*   **The "Magic" of Imagination:** Relics and modifiers can have "magical" effects, but framed through a child's imagination (e.g., "Static Electricity" makes blankets stronger; "Lava Floor" makes dropped items bounce).

## 5. Systemic Assumptions for Code Generation
When writing scripts or architecture for this game, assume the following constraints:
*   **Mobile-First:** Inputs are strictly Touch, Drag, and simple UI taps. Avoid complex multi-touch gestures.
*   **Performance Budget:** We are on mobile. Avoid complex soft-body or cloth physics. Fake it using 2D Box/Circle colliders, 2D Hinge Joints, and clever mass/drag values. 
*   **Agnostic Event-Driven Design:** Do not hardcode item behaviors. Use a central Event Bus (`OnCombatStart`, `OnItemPlaced`, `OnProjectileHit`) so we can easily add new Relics and Modifiers by subscribing to events.
*   **Fail-Safe Physics:** Because Box2D physics can jitter or explode, code defensive constraints. Limit max velocities, use continuous collision detection only on fast projectiles, and aggressively put rigidbodies to sleep when the combat phase ends.

# Systems Architecture: Modular Auto-Battler Engine

## 1. High-Level Engine Philosophy
The engine is entirely **Data-Driven** and **Agnostic**. 
* The code does not know what a "Pillow" or a "Nerf Dart" is. 
* It only understands `PlaceableEntities`, `Projectiles`, and `Modifiers`. 
* Content (items, enemies, relics) is generated by feeding Data Objects (Resources in Godot) into these core systems.

---

## 2. The Core State Machine (Phase Manager)
A global manager that dictates what systems are active. Only one state runs at a time.

*   **`STATE_DRAFT`**: 
    *   *Active Systems:* UI Manager, Drafting Pool.
    *   *Action:* Presents `BundleData` objects. Passes selected data to the Player Inventory.
*   **`STATE_BUILD`**: 
    *   *Active Systems:* Placement System, Input Handler.  
*   **`STATE_COMBAT`**: 
    *   *Active Systems:* Physics Engine (`timeScale = 1`), Wave Manager, Projectile Spawners.
    *   *Action:* Converts all `PlaceableEntities` to Dynamic physics objects. Executes `WaveData`.
*   **`STATE_RESOLVE`**: 
    *   *Active Systems:* Cleanup Manager.
    *   *Action:* Destroys broken entities, saves surviving entities' positions to the persistent base state, increments Wave counter.

---

## 3. Entity Component Architecture

### A. PlaceableEntity (The Building Blocks)
Every piece of furniture shares this single class/node. Its behavior is dictated by its injected `EntityData`.

**Injected Variables (`EntityData`):**
*   `Enum Type`: Anchor, Prop, or Bridge. (Defines placement rules).
*   `Float Mass`: Determines physics weight.
*   `Float Friction`: Determines slipperiness.
*   `Float Bounciness`: Determines energy retention on impact.
*   `Int Durability`: How much impulse force it can take before breaking (Destroyed).

**Core Methods:**
*   `Initialize(EntityData)`: Sets up the colliders and physics materials based on data.
*   `SetGhostMode(bool)`: Toggles colliders to triggers during `STATE_BUILD`.
*   `ActivatePhysics()`: Switches from Kinematic to Dynamic on `STATE_COMBAT` start.
*   `TakeDamage(int amount)`: Reduces durability.

### B. ProjectileEntity (The Threats)
Every enemy attack shares this class. 

**Injected Variables (`ProjectileData`):**
*   `Float BaseSpeed`: Velocity upon spawning.
*   `Float Mass`: Determines impact force against `PlaceableEntities`.
*   `Int Damage`: How much HP it removes from the Kid (or Durability from entities).
*   `Enum TrajectoryType`: Linear, Arced, Homing.

**Core Methods:**
*   `Launch(Vector2 target)`: Applies initial impulse.
*   `OnCollisionEnter2D()`: Calculates impact, triggers destruction or bouncing.

---

## 4. The Event-Bus & Modifier System (Relics)

To support Relics/Upgrades without hardcoding, the engine uses a Global Event Bus. Modifiers are agnostic logic blocks that subscribe to these events.

**Global Hooks (Event Triggers):**
*   `OnCombatStart` (Triggers when PLAY is pressed)
*   `OnEntityPlaced` (Triggers when an item drops in Build mode)
*   `OnProjectileHit` (Passes the Projectile and the hit Entity)
*   `OnKidTakeDamage`

**The Modifier Class (RelicLogic):**
A Relic is just a data container that connects a `Trigger` to an `Effect`.
*   *Example 1 (Heavy Items):* Listens for `OnEntityPlaced`. Effect: Multiplies `Entity.Mass` by 1.5.
*   *Example 2 (Bouncy Forcefield):* Listens for `OnProjectileHit`. Effect: If hit Entity is type `Prop`, reflect Projectile velocity by -1.
*   *Example 3 (Regen):* Listens for `OnCombatStart`. Effect: Restores 1 HP to the Kid.

---

## 5. Wave & Spawner Engine

The Combat Phase is dictated by agnostic `WaveData` injected into the Wave Manager.

**WaveData Structure:**
*   `Float Duration`: Total time of the combat phase.
*   `List<SpawnInstruction>`: A list of chronologically sorted spawn events.

**SpawnInstruction Structure:**
*   `Float Timestamp`: When in the phase to fire (e.g., 2.5 seconds in).
*   `Vector2 SpawnOrigin`: Where on the screen edge to spawn.
*   `ProjectileData Payload`: What type of projectile to fire.

*Engine Logic:* The Wave Manager simply reads the `WaveData` array. When the combat timer hits `Timestamp`, it instantiates the `Payload` at the `SpawnOrigin` and points it at the Kid.