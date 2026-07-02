class_name DraftCard
extends Button

## Reusable card that renders ANY DraftOption from its shared base fields.

signal card_selected(option: DraftOption)

@onready var _rarity_bar: ColorRect = $Margin/VBox/Rarity
@onready var _name_label: Label = $Margin/VBox/Name
@onready var _icon_rect: TextureRect = $Margin/VBox/Icon
@onready var _description_label: Label = $Margin/VBox/Description

var _option: DraftOption = null

func _ready() -> void:
	# Let taps/clicks fall through the layout nodes to the Button itself.
	for node in Discovery.find_children_of_type(self, Control):
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	pressed.connect(_on_pressed)
	if _option != null:
		_apply(_option)

## Populate the card from a DraftOption. Safe to call before or after _ready().
func setup(option: DraftOption) -> void:
	_option = option
	if is_node_ready():
		_apply(option)

func _apply(option: DraftOption) -> void:
	if option == null:
		return
	_name_label.text = option.display_name
	_description_label.text = option.description
	_icon_rect.texture = option.icon
	var accent: Color = option.get_rarity_color()
	_rarity_bar.color = accent
	_name_label.add_theme_color_override("font_color", accent)

func _on_pressed() -> void:
	if _option != null:
		card_selected.emit(_option)
