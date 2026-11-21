class_name Buildable
extends StaticBody3D
## Base for built defenses (auto turret now; manual turret / trap in v0.5.1).
## Invulnerable by design — no take_hit, so bullets leave only impact FX —
## and solid: the world layer blocks movement, the interactable layer exposes
## resupply/inspection to the player's interact ray.

const LAYER_WORLD := 1
const LAYER_INTERACTABLE := 8


func _ready() -> void:
	collision_layer = LAYER_WORLD | LAYER_INTERACTABLE
	collision_mask = 0
