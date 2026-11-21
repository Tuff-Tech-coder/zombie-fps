extends Node
## Formula resolution (DESIGN_DOC §8.1): owns the PerkRecipe registry, the
## free-combine validation (exact multiset match, tier-gated), the craft
## (consume inputs → dose into Inventory), and the run-scoped recipe reveals
## from notes. Deliberately no recipe browser: veterans craft from memory;
## a found RecipeNote reveals a formula for this run only (never persistent —
## DESIGN_DOC §11 forbids meta-progression).

const PERKS_DIR := "res://resources/perks"

var revealed: Array[StringName] = []  # perk ids whose recipes are shown

var _recipes: Array[PerkRecipe] = []


func _ready() -> void:
	var dir := DirAccess.open(PERKS_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var res: Resource = load(PERKS_DIR.path_join(file))
		if res is PerkRecipe:
			_recipes.append(res)


func recipes_for_tier(tier: Perk.Tier) -> Array[PerkRecipe]:
	var out: Array[PerkRecipe] = []
	for r in _recipes:
		if r.required_tier <= tier:
			out.append(r)
	return out


## Exact multiset match of `mix` (id → qty) against recipes this tier can
## complete. Null when the mixture is unstable (no match).
func match_recipe(mix: Dictionary, tier: Perk.Tier) -> PerkRecipe:
	for r in recipes_for_tier(tier):
		if r.inputs.size() != mix.size():
			continue
		var matched := true
		for input in r.inputs:
			if int(mix.get(input["id"], 0)) != int(input["qty"]):
				matched = false
				break
		if matched:
			return r
	return null


## Consume the recipe's inputs and produce one dose into the Inventory.
func craft(recipe: PerkRecipe) -> bool:
	if not Inventory.has(recipe.inputs):
		return false
	for input in recipe.inputs:
		Inventory.consume(input["id"], input["qty"])
	Inventory.add(recipe.output_perk.id, 1)
	EventBus.perk_crafted.emit(recipe.output_perk)
	return true


func reveal(perk_id: StringName) -> void:
	if not revealed.has(perk_id):
		revealed.append(perk_id)


func recipe_for_perk(perk_id: StringName) -> PerkRecipe:
	for r in _recipes:
		if r.output_perk and r.output_perk.id == perk_id:
			return r
	return null


## Fresh run: reveals are run-scoped (found notes are not unlocks).
func reset_run() -> void:
	revealed.clear()
