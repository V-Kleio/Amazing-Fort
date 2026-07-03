class_name BuildPhase
extends Node2D

## Build phase orchestrator. Wires the inventory bar (one slot per drafted furniture),
## the placement controller, the persistent Arena, and the Play button. Furniture-agnostic:
## it never references a concrete furniture type.
##
## Required layout tree (see docs/build_setup_guide.html):
##   BuildingPhase (Node2D)  <- this script
##    └ CanvasLayer
##       └ Control (full rect, mouse_filter = Ignore)
##          ├ InventoryBar (HBoxContainer, anchored bottom, mouse_filter = Stop)
##          ├ PlayButton (Button)
##          └ DeleteButton (Button, hidden until a piece is selected)

@export var inventory_slot_scene: PackedScene

@onready var _inventory_bar: HBoxContainer = $CanvasLayer/Control/InventoryBar
@onready var _play_button: Button = $CanvasLayer/Control/PlayButton
@onready var _delete_button: Button = $CanvasLayer/Control/DeleteButton

var _controller: BuildPlacementController = null

func _ready() -> void:
	var arena: Node2D = get_tree().get_first_node_in_group(&"arena") as Node2D
	if arena == null:
		push_warning("BuildPhase: no Arena found (run via level_controller). Placement disabled.")

	_clear_previous_placeables()

	_controller = BuildPlacementController.new()
	_controller.arena = arena
	_controller.inventory_bar = _inventory_bar
	_controller.play_button = _play_button
	_controller.delete_button = _delete_button
	add_child(_controller)

	_delete_button.hide()
	_delete_button.pressed.connect(_controller._delete_selected)
	_play_button.pressed.connect(_on_play_pressed)

	_build_slots()

## Start each build fresh so slot counts (which reset to full quantity) stay honest.
## The Kid and the Arena itself persist; only placed furniture is cleared.
func _clear_previous_placeables() -> void:
	for node in get_tree().get_nodes_in_group(&"placeable"):
		node.queue_free()

func _build_slots() -> void:
	if inventory_slot_scene == null:
		push_warning("BuildPhase: inventory_slot_scene is not assigned in the inspector.")
		return
	for option in PlayerInventory.get_items(&"furniture"):
		var furniture: FurnitureDraftOption = option as FurnitureDraftOption
		if furniture == null or furniture.entity_scene == null:
			continue  # can't place without a prefab; skip (no slot)
		var slot: InventorySlot = inventory_slot_scene.instantiate() as InventorySlot
		_inventory_bar.add_child(slot)
		slot.setup(option, furniture.quantity)
		slot.slot_pressed.connect(_controller.begin_spawn)

func _on_play_pressed() -> void:
	GameEvents.phase_finished.emit("building")

# Safety net during editor migration (harmless once the old ContinueButton is removed).
func _on_continue_pressed() -> void:
	GameEvents.phase_finished.emit("building")
