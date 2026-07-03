class_name InventorySlot
extends Button

## One item in the bottom inventory bar: a furniture option's icon + a remaining count.
## Pressing it (on button_down, so placement is one continuous gesture) asks the placement
## controller to spawn a piece. Modeled on DraftCard. The scene layout is editor-authored.
##
## Required node tree (see docs/build_setup_guide.html):
##   InventorySlot (Button)  <- this script
##    ├ Icon (TextureRect)
##    └ Count (Label)

signal slot_pressed(option: DraftOption, slot: InventorySlot)

@onready var _icon: TextureRect = $Icon
@onready var _count: Label = $Count

var _option: DraftOption = null
## Remaining placements. Runtime-only — never mutate option.quantity.
var remaining: int = 0

func _ready() -> void:
	# Let presses fall through the icon/label to the Button itself.
	for node in Discovery.find_children_of_type(self, Control):
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	button_down.connect(_on_button_down)
	if _option != null:
		_apply()

func setup(option: DraftOption, count: int) -> void:
	_option = option
	remaining = count
	if is_node_ready():
		_apply()

func _apply() -> void:
	_icon.texture = _option.icon
	_refresh()

func consume() -> void:
	remaining = maxi(0, remaining - 1)
	_refresh()

func refund() -> void:
	remaining += 1
	_refresh()

func _refresh() -> void:
	_count.text = str(remaining)
	disabled = remaining <= 0
	# Depleted slots vanish entirely (the HBox reflows); reappear on refund.
	visible = remaining > 0

func _on_button_down() -> void:
	if remaining > 0 and _option != null:
		slot_pressed.emit(_option, self)
