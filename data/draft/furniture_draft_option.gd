class_name FurnitureDraftOption
extends DraftOption

## A draftable piece of furniture the player can place during the Build phase.
##
## Kept forward-compatible with the future EntityData / PlaceableEntity work: it only
## holds a scene reference + quantity, with no dependency on systems not built yet.
## Uses the default apply() -> stored in PlayerInventory under the "furniture" bucket,
## which the Build phase will read to spawn the player's placeable inventory.

## Scene to instantiate as a placeable during Build (a PlaceableEntity-style scene).
@export var entity_scene: PackedScene
## How many copies of this furniture the draft grants.
@export var quantity: int = 1

func get_category() -> StringName:
	return &"furniture"
