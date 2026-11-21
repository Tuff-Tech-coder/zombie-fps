class_name Perk
extends Resource
## Perk definition (DESIGN_DOC §4.2): data-driven, authored as .tres under
## resources/perks/. Perks are doses — ingested or attached — so syringes,
## beakers, bottles and food read as perks; machinery does not (MACHINE is
## reserved for Who's-Who-style perks).
##
## Effect model: simple stat perks are pure data (stat + multiplier read via
## PerkManager.get_multiplier at a handful of gameplay read points); special
## perks name an effect_script (a Node) that PerkManager attaches on apply.

enum Delivery { INGESTIBLE, ATTACHABLE, MACHINE }
enum Trigger { PASSIVE, ON_RELOAD, ON_HIT, ON_KILL, ON_DEATH }
enum Tier { BENCH, LAB }

@export var id: StringName = &""
@export var display_name := "Perk"
@export var icon: Texture2D
## Placeholder chip color for the HUD until real icons exist.
@export var color := Color(0.8, 0.8, 0.8)
@export var delivery := Delivery.INGESTIBLE
@export var trigger := Trigger.PASSIVE
@export var tier := Tier.BENCH

@export_group("Stat effect (PASSIVE)")
@export var stat: StringName = &""
@export var multiplier := 1.0

@export_group("Scripted effect")
## Node script attached by PerkManager while the perk is active.
@export var effect_script: Script
## Free-form tuning read by the effect script.
@export var params: Dictionary = {}
