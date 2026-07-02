extends Node

## Run-state store for everything drafted this run.
##
## Category-agnostic: options are bucketed by DraftOption.get_category(), so a brand-new
## draftable category needs ZERO changes here. Later phases read their bucket, e.g. the
## Build phase reads get_items(&"furniture"). Cleared at the start of each new game.

var _items: Dictionary = {}  ## StringName category -> Array[DraftOption]

func _ready() -> void:
	GameEvents.try_connect(GameEvents.round_started, _on_round_started)

func _on_round_started(round_number: int) -> void:
	if round_number == 1:
		reset()

func add(option: DraftOption) -> void:
	if option == null:
		return
	var category: StringName = option.get_category()
	if not _items.has(category):
		_items[category] = [] as Array[DraftOption]
	var bucket: Array[DraftOption] = _items[category]
	bucket.append(option)


func get_items(category: StringName) -> Array[DraftOption]:
	if _items.has(category):
		return _items[category]
	return [] as Array[DraftOption]


func has_upgrade(id: StringName) -> bool:
	for option in get_items(&"upgrade"):
		var upgrade: UpgradeDraftOption = option as UpgradeDraftOption
		if upgrade != null and upgrade.upgrade_id == id:
			return true
	return false


func reset() -> void:
	_items.clear()
