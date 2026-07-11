class_name Burner
extends Buildable
## Heat source (v0.6.0): lab formulas need heated compounds, and heating
## takes a burner you find parts for and build. Interact converts every held
## unit of the input compound into its heated form.

@export var input_item: StringName = &"cherry_extract"
@export var output_item: StringName = &"cherry_concentrate"


func get_interact_prompt() -> String:
	var held := Inventory.count(input_item)
	if held <= 0:
		return "Burner — needs %s to heat" % Inventory.display_name(input_item)
	return "E: Heat %s ×%d → %s" % [Inventory.display_name(input_item), held,
			Inventory.display_name(output_item)]


func interact(_player) -> void:
	var held := Inventory.count(input_item)
	if held <= 0:
		return
	Inventory.consume(input_item, held)
	Inventory.add(output_item, held)
