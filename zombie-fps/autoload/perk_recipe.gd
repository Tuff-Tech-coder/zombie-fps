class_name PerkRecipe
extends Resource
## Crafting formula (DESIGN_DOC §4.2): compound inputs → a perk dose.
## Authored as .tres under resources/perks/ next to the perks themselves.
## A station can complete recipes of required_tier <= its own tier.

@export var display_name := "Formula"
## Array of { "id": StringName, "qty": int } — COMPOUND item ids.
@export var inputs: Array[Dictionary] = []
@export var output_perk: Perk
@export var required_tier := Perk.Tier.BENCH
