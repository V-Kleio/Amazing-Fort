class_name UpgradeDraftOption
extends DraftOption

## A draftable upgrade/relic that modifies Combat via the (future) modifier system.
##
## On apply() it is stored in PlayerInventory under "upgrade" AND announced through
## GameEvents.upgrade_acquired, so the modifier/relic system can subscribe and react
## without this class knowing about it (agnostic, event-driven per docs/GUIDE.md).

## Identifier the modifier/relic system keys on to apply this upgrade's effect.
@export var upgrade_id: StringName = &""
## If true, this upgrade can only be owned once (won't be re-offered once acquired).
@export var is_unique: bool = true

func get_category() -> StringName:
	return &"upgrade"

func can_offer() -> bool:
	if not super.can_offer():
		return false
	if is_unique and PlayerInventory.has_upgrade(upgrade_id):
		return false
	return true

func apply() -> void:
	super.apply()
	GameEvents.upgrade_acquired.emit(self)
