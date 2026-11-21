class_name Pickup
extends StaticBody3D
## Scavengeable world item (DESIGN_DOC §4). Lives on the interactable layer
## only, so it never blocks movement; the player's interact ray finds it.

const SPIN_SPEED := 1.2

@export var item: ItemResource
@export var quantity := 1

@onready var label: Label3D = $Label
@onready var mesh: MeshInstance3D = $Mesh


func _ready() -> void:
	assert(item != null, "Pickup needs an ItemResource")
	Inventory.register_item(item)
	label.text = "%s ×%d" % [item.display_name, quantity]


func _process(delta: float) -> void:
	mesh.rotate_y(SPIN_SPEED * delta)  # slow spin so it reads in the dark


func get_interact_prompt() -> String:
	return "E: Take %s ×%d" % [item.display_name, quantity]


func interact(_player) -> void:
	Inventory.add(item.id, quantity)
	EventBus.resource_picked_up.emit(item)
	queue_free()
