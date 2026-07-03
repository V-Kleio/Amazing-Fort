class_name BuildPlacementController
extends Node2D

## Amazing-Alex-style placement state machine, furniture-agnostic (operates on any
## PlaceableEntity). Handles: spawn-above-finger, drag-with-Y-offset, keep-holding on
## overlap, tap-to-select, move (re-drag), rotate (via RotationRing), delete (refund).
##
## Input is handled via MOUSE events (covers desktop mouse AND emulated touch). Committed
## pieces are parented to the persistent Arena; the ring lives under this controller and
## is freed with the Build phase. Refs (arena/inventory_bar/play_button/delete_button) are
## assigned by BuildPhase before this node is added to the tree.

enum State { IDLE, DRAGGING, SELECTED, ROTATING }

## Upward offset so the placed object isn't hidden under the thumb while dragging.
const Y_OFFSET: float = 140.0
## Point-query mask targeting the FurnitureOverlap layer (bit 5 → value 16).
const FURNITURE_OVERLAP_MASK: int = 1 << 4

var arena: Node2D
var inventory_bar: Control
var play_button: Button
var delete_button: Button

var _state: State = State.IDLE
var _held_piece: PlaceableEntity = null
var _selected: PlaceableEntity = null
## True while dragging a freshly-spawned piece that hasn't consumed its slot count yet.
var _held_is_new: bool = false
var _pointer_down: bool = false
var _pre_rotation: float = 0.0
var _piece_to_slot: Dictionary = {}  ## PlaceableEntity -> InventorySlot

var _ring: RotationRing = null

func _ready() -> void:
	_ring = RotationRing.new()
	_ring.visible = false
	add_child(_ring)

# --- Spawn (connected to InventorySlot.slot_pressed on button_down) ---------

func begin_spawn(option: DraftOption, slot: InventorySlot) -> void:
	if arena == null:
		push_warning("BuildPlacementController: no Arena to place into; cannot spawn.")
		return
	var furniture: FurnitureDraftOption = option as FurnitureDraftOption
	if furniture == null or furniture.entity_scene == null:
		push_warning("BuildPlacementController: furniture option has no entity_scene; cannot spawn.")
		return
	var piece: PlaceableEntity = furniture.entity_scene.instantiate() as PlaceableEntity
	if piece == null:
		push_error("BuildPlacementController: entity_scene root is not a PlaceableEntity.")
		return
	arena.add_child(piece)
	piece.global_position = _pointer_world()
	_piece_to_slot[piece] = slot
	_begin_drag(piece, true)

# --- Per-frame tracking ------------------------------------------------------

func _process(_delta: float) -> void:
	if not _pointer_down:
		return
	match _state:
		State.DRAGGING:
			if _held_piece != null:
				_held_piece.global_position = _pointer_world()
				_held_piece.set_tint(not _held_piece.is_overlapping())
		State.ROTATING:
			if _selected != null:
				var angle: float = (get_global_mouse_position() - _selected.global_position).angle()
				_selected.rotation = angle
				_ring.set_handle_angle(angle)
				_selected.set_tint(not _selected.is_overlapping())

# --- Input (mouse buttons only; motion is polled in _process) ----------------

func _unhandled_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if button.pressed:
		_on_pointer_pressed(get_global_mouse_position())
	else:
		_on_pointer_released()
	get_viewport().set_input_as_handled()

func _on_pointer_pressed(world: Vector2) -> void:
	_pointer_down = true
	match _state:
		State.IDLE:
			var piece: PlaceableEntity = _piece_at(world)
			if piece != null:
				_begin_drag(piece, false)  # grab-and-move in one gesture; ring shows on commit
		State.SELECTED:
			if _selected != null and _can_rotate(_selected) and _ring.is_on_ring(world):
				_pre_rotation = _selected.rotation
				_state = State.ROTATING
			else:
				var piece: PlaceableEntity = _piece_at(world)
				if piece != null:
					_begin_drag(piece, false)
				else:
					_deselect()
		_:
			pass  # already dragging/rotating: just (re)assert pointer_down

func _on_pointer_released() -> void:
	_pointer_down = false
	match _state:
		State.DRAGGING:
			if _held_piece == null:
				_state = State.IDLE
				return
			if _held_piece.is_overlapping():
				_held_piece.set_tint(false)  # keep holding: cannot commit on overlap
				return
			_commit_held()
		State.ROTATING:
			if _selected != null:
				if _selected.is_overlapping():
					_selected.rotation = _pre_rotation
					_ring.set_handle_angle(_pre_rotation)
				_selected.clear_tint()
			_state = State.SELECTED

# --- Delete (wired to delete_button.pressed by BuildPhase) -------------------

func _delete_selected() -> void:
	if _selected == null:
		return
	var slot: InventorySlot = _piece_to_slot.get(_selected) as InventorySlot
	if slot != null:
		slot.refund()
	_piece_to_slot.erase(_selected)
	var removed: PlaceableEntity = _selected
	_deselect()
	GameEvents.furniture_removed.emit(removed)
	removed.queue_free()

# --- State helpers -----------------------------------------------------------

func _commit_held() -> void:
	var piece: PlaceableEntity = _held_piece
	piece.clear_tint()
	if _held_is_new:
		var slot: InventorySlot = _piece_to_slot.get(piece) as InventorySlot
		if slot != null:
			slot.consume()
	_held_piece = null
	_set_ui_passthrough(false)
	GameEvents.furniture_placed.emit(piece)
	_select(piece)

func _begin_drag(piece: PlaceableEntity, is_new: bool) -> void:
	_selected = null
	_ring.visible = false
	if delete_button != null:
		delete_button.hide()
	_held_piece = piece
	_held_is_new = is_new
	_pointer_down = true
	_set_ui_passthrough(true)
	_state = State.DRAGGING

func _select(piece: PlaceableEntity) -> void:
	_selected = piece
	if _can_rotate(piece):
		_ring.configure(piece.global_position, piece.get_ring_radius(), piece.rotation)
	else:
		_ring.visible = false
	if delete_button != null:
		delete_button.show()
	_state = State.SELECTED

func _deselect() -> void:
	_selected = null
	_ring.visible = false
	if delete_button != null:
		delete_button.hide()
	_state = State.IDLE

func _can_rotate(piece: PlaceableEntity) -> bool:
	return piece.data == null or piece.data.can_rotate

# --- Utilities ---------------------------------------------------------------

func _pointer_world() -> Vector2:
	return get_global_mouse_position() + Vector2(0.0, -Y_OFFSET)

## First PlaceableEntity whose OverlapArea contains the point (nearest under the finger).
func _piece_at(world: Vector2) -> PlaceableEntity:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var params: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	params.position = world
	params.collide_with_areas = true
	params.collide_with_bodies = false
	params.collision_mask = FURNITURE_OVERLAP_MASK
	for hit in space.intersect_point(params):
		var piece: Node = Discovery.find_parent_of_type(hit.get("collider"), PlaceableEntity)
		if piece != null:
			return piece as PlaceableEntity
	return null

## While a piece is held or rotating, make the bar + its slots + buttons click-through so
## drag motion/release reaches this controller; restore blocking otherwise.
func _set_ui_passthrough(passthrough: bool) -> void:
	var filter: int = Control.MOUSE_FILTER_IGNORE if passthrough else Control.MOUSE_FILTER_STOP
	if inventory_bar != null:
		inventory_bar.mouse_filter = filter
		for slot in Discovery.find_children_of_type(inventory_bar, InventorySlot):
			(slot as InventorySlot).mouse_filter = filter
	if play_button != null:
		play_button.mouse_filter = filter
	if delete_button != null:
		delete_button.mouse_filter = filter
