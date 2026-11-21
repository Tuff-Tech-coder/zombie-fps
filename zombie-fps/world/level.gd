class_name Level
extends Node3D
## Base for every map root: the per-map data contract. Today that's the
## soundtrack — each map assigns its own MapMusic .tres here (in the scene,
## or in code before _ready like city.gd's preload style) and AudioManager
## stays map-agnostic. A new map's music = a new .tres on its root.

@export var soundtrack: MapMusic


func _ready() -> void:
	AudioManager.set_soundtrack(soundtrack)
