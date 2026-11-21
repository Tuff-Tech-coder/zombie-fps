class_name BuildRecipe
extends Resource
## Data-driven build formula (DESIGN_DOC §4): inputs consumed from the
## Inventory, scene instanced at the BuildSpot. Authored as .tres under
## resources/recipes/ — a new buildable is a new .tres, not code.

@export var display_name := "Buildable"
## Array of { "id": StringName, "qty": int }
@export var inputs: Array[Dictionary] = []
@export var buildable_scene: PackedScene
