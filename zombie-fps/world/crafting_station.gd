class_name CraftingStation
extends StaticBody3D
## Interactable crafting point. A station completes recipes whose
## required_tier <= its tier: bench recipes work anywhere, lab recipes only
## at the lab. The bench is pre-placed scenery (interactable-only); the lab
## ships as a buildable, so `solid` mirrors the Buildable layer setup.

const LAYER_WORLD := 1
const LAYER_INTERACTABLE := 8

@export var tier := Perk.Tier.BENCH
## Buildable-style stations block movement; scenery benches don't.
@export var solid := false


func _ready() -> void:
	collision_layer = (LAYER_WORLD if solid else 0) | LAYER_INTERACTABLE
	collision_mask = 0


func get_interact_prompt() -> String:
	return "E: Craft (%s)" % ("Lab" if tier == Perk.Tier.LAB else "Bench")


func interact(_player) -> void:
	var ui := get_tree().get_first_node_in_group("crafting_ui")
	if ui:
		ui.open_station(self)
