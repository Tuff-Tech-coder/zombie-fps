class_name RecipeNote
extends StaticBody3D
## Found note: reveals one formula in the crafting UI for THIS RUN ONLY —
## deliberately not a persistent unlock (DESIGN_DOC §11 bans meta-progression).
## Veterans never need one; free-combine always works.

@export var recipe: PerkRecipe


func _ready() -> void:
	assert(recipe != null, "RecipeNote needs a PerkRecipe")
	$Label.text = "Note"


func get_interact_prompt() -> String:
	return "E: Read note (%s formula)" % recipe.display_name


func interact(_player) -> void:
	CraftingSystem.reveal(recipe.output_perk.id)
	queue_free()
