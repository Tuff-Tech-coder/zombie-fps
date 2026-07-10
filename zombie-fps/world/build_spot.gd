class_name BuildSpot
extends StaticBody3D
## Fixed build location — no free placement (DESIGN_DOC §11 firewall).
## EMPTY shows a translucent ghost + costed prompt; interact builds the
## recipe's scene here if the Inventory covers the inputs. Scene reload
## returns the spot to EMPTY: buildables never persist across a run.

const LAYER_INTERACTABLE := 8

@export var recipe: BuildRecipe

var _built := false

@onready var ghost: Node3D = $Ghost
@onready var label: Label3D = $Label


func _ready() -> void:
	assert(recipe != null, "BuildSpot needs a BuildRecipe")
	collision_layer = LAYER_INTERACTABLE
	collision_mask = 0
	label.text = recipe.display_name


func get_interact_prompt() -> String:
	if _built:
		return ""
	var costs := PackedStringArray()
	for input in recipe.inputs:
		var have := Inventory.count(input["id"])
		var qty := int(input["qty"])
		costs.append("%s %d/%d" % [Inventory.display_name(input["id"]), mini(have, qty), qty])
	return "E: Build %s — %s" % [recipe.display_name, ", ".join(costs)]


func interact(_player) -> void:
	if _built or not Inventory.has(recipe.inputs):
		return  # the prompt already shows what's missing
	for input in recipe.inputs:
		Inventory.consume(input["id"], input["qty"])
	var built: Node3D = recipe.buildable_scene.instantiate()
	get_parent().add_child(built)
	built.global_transform = global_transform
	_built = true
	ghost.visible = false
	label.visible = false
	# Stop catching the interact ray — the buildable handles it from here.
	collision_layer = 0
