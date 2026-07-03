class_name BuildPhase
extends Node2D

## Build phase orchestrator. Wires the inventory bar (one slot per drafted furniture),
## the placement controller, the persistent Arena, and the Play button. Furniture-agnostic:
## it never references a concrete furniture type.
##
## Required layout tree (see docs/inventory_reticle_setup_guide.html):
##   BuildingPhase (Node2D)
##    └ CanvasLayer → Control (full rect, mouse_filter = Ignore)
##       ├ InventoryTray (Control, bottom-anchored)   <- slid to collapse/expand
##       │   ├ BarBackground (TextureRect, optional)
##       │   └ InventoryBar (HBoxContainer)           <- the slots
##       ├ InventoryToggle (TextureButton, briefcase) <- collapses/expands the tray
##       ├ PlayButton (TextureButton)
##       └ DeleteButton (TextureButton, hidden until a piece is selected)

@export var inventory_slot_scene: PackedScene
## Placement sound (editor-assignable; silent until you add an SFX asset).
@export var place_sfx: AudioStream

const SLOT_STAGGER: float = 0.06

@onready var _play_button: TextureButton = $CanvasLayer/Control/PlayButton
@onready var _delete_button: TextureButton = $CanvasLayer/Control/DeleteButton

var _controller: BuildPlacementController = null
var _inventory_bar: HBoxContainer = null
var _tray: Control = null
var _toggle: BaseButton = null

var _collapsed: bool = false
var _shown_y: float = 0.0
var _hidden_y: float = 0.0

func _ready() -> void:
	_resolve_inventory_nodes()

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

	GameEvents.try_connect(GameEvents.furniture_placed, _on_furniture_placed)

	_build_slots()
	_setup_juice()

## Resolve the inventory bar/tray/toggle, tolerating a pre-restructure scene (old flat bar).
func _resolve_inventory_nodes() -> void:
	_tray = get_node_or_null(^"CanvasLayer/Control/InventoryTray") as Control
	if _tray != null:
		_inventory_bar = _tray.get_node_or_null(^"InventoryBar") as HBoxContainer
	else:
		_inventory_bar = get_node_or_null(^"CanvasLayer/Control/InventoryBar") as HBoxContainer
	_toggle = get_node_or_null(^"CanvasLayer/Control/InventoryToggle") as BaseButton

## Start each build fresh so slot counts (which reset to full quantity) stay honest.
## The Kid and the Arena itself persist; only placed furniture is cleared.
func _clear_previous_placeables() -> void:
	for node in get_tree().get_nodes_in_group(&"placeable"):
		node.queue_free()

func _build_slots() -> void:
	if inventory_slot_scene == null or _inventory_bar == null:
		push_warning("BuildPhase: inventory_slot_scene or InventoryBar missing.")
		return
	for option in PlayerInventory.get_items(&"furniture"):
		var furniture: FurnitureDraftOption = option as FurnitureDraftOption
		if furniture == null or furniture.entity_scene == null:
			continue  # can't place without a prefab; skip (no slot)
		var slot: InventorySlot = inventory_slot_scene.instantiate() as InventorySlot
		_inventory_bar.add_child(slot)
		slot.setup(option, furniture.quantity)
		slot.slot_pressed.connect(_controller.begin_spawn)

## Entrance slide + staggered slot pop + button feedback + the collapse toggle.
## Runs after a layout frame so Control sizes/positions (needed for pivots) are final.
func _setup_juice() -> void:
	await get_tree().process_frame

	if _inventory_bar != null:
		var index: int = 0
		for child in _inventory_bar.get_children():
			var slot: InventorySlot = child as InventorySlot
			if slot == null or not slot.visible:
				continue
			UIJuice.center_pivot(slot)
			UIJuice.pop_in(slot, index * SLOT_STAGGER, 0.3, 0.7, true)
			index += 1

	# Play button: gentle breathe (scale) + press feedback (modulate — no scale conflict).
	if _play_button != null:
		UIJuice.center_pivot(_play_button)
		UIJuice.loop_breathe(_play_button, 0.03, 2.0)
		UIJuice.press_modulate(_play_button)

	if _toggle != null:
		UIJuice.center_pivot(_toggle)
		UIJuice.press_scale(_toggle)
		_toggle.pressed.connect(_toggle_inventory)

	if _tray != null:
		_shown_y = _tray.position.y
		var slide: float = maxf(_tray.size.y, 200.0) + 40.0
		_hidden_y = _shown_y + slide
		_tray.position.y = _hidden_y  # start below…
		_slide_tray(_shown_y)         # …and slide up into place

func _toggle_inventory() -> void:
	if _tray == null:
		return
	_collapsed = not _collapsed
	_slide_tray(_hidden_y if _collapsed else _shown_y)

func _slide_tray(target_y: float) -> void:
	var tween: Tween = _tray.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_tray, "position:y", target_y, 0.35)

func _on_furniture_placed(_entity: PlaceableEntity) -> void:
	AudioManager.play_sfx(place_sfx, randf_range(0.96, 1.06))

func _on_play_pressed() -> void:
	GameEvents.phase_finished.emit("building")

# Safety net during editor migration (harmless once the old ContinueButton is removed).
func _on_continue_pressed() -> void:
	GameEvents.phase_finished.emit("building")
