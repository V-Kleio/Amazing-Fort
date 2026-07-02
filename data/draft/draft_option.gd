class_name DraftOption
extends Resource

## Base contract every draftable presents to the draft pool, card UI, and inventory.
##
## Subclass this to add a new kind of draftable (furniture, upgrade, relic, ...).
## The generic systems (DraftPool, DraftCard, PlayerInventory, ChoosingPhase) only
## ever read this base API, so a new subclass needs NO changes to any of them.
##
## To add a new type: extend this, override get_category(), and optionally override
## can_offer()/apply() for special behavior. Then author .tres in data/draft/options/.

enum Rarity { COMMON, UNCOMMON, RARE, EPIC }

@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var rarity: Rarity = Rarity.COMMON
## Relative chance of being offered by the pool. 0 = never offered.
@export var weight: float = 1.0

## Category key PlayerInventory uses to bucket this grant. Override per subclass.
func get_category() -> StringName:
	return &"generic"

## Whether this option may currently be offered. Override for conditional/unique options.
func can_offer() -> bool:
	return weight > 0.0

## Grant this option to the current run. Default: store it in the inventory.
## Override (and call super()) to add extra behavior, e.g. emitting an event.
func apply() -> void:
	PlayerInventory.add(self)

## Presentation helper: accent color for the card, derived from rarity.
func get_rarity_color() -> Color:
	match rarity:
		Rarity.UNCOMMON:
			return Color(0.35, 0.82, 0.45)  # green
		Rarity.RARE:
			return Color(0.32, 0.56, 0.96)  # blue
		Rarity.EPIC:
			return Color(0.72, 0.42, 0.92)  # purple
		_:
			return Color(0.78, 0.78, 0.80)  # common: grey
