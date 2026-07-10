class_name ItemResource
extends Resource
## Scavengeable item definition (DESIGN_DOC §4): authored as .tres under
## resources/items/, never hardcoded. Ammo items use the caliber as their id
## (e.g. &"9mm") so weapons and turrets can share the pool by StringName.

enum Category { COMPOUND, PART, AMMO }

@export var id: StringName = &""
@export var display_name := "Item"
@export var icon: Texture2D
@export var category := Category.PART
