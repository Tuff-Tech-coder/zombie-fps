class_name DebugButton
extends StaticBody3D
## A shootable debug control. The button is only a trigger and a status lamp —
## all actual behavior routes through DebugManager so it strips with the
## debug flag.

const LABELS := {
	"spawn_1": "SPAWN 1",
	"spawn_10": "SPAWN 10",
	"infinite_ammo": "INF AMMO",
	"infinite_health": "INF HP",
	"enemy_health_bars": "ENEMY HP",
	"door": "DOOR",
	"wave": "WAVE",
	"grant": "GRANT PARTS",
}
const TOGGLES := ["infinite_ammo", "infinite_health", "enemy_health_bars", "door", "wave"]

@export_enum("spawn_1", "spawn_10", "infinite_ammo", "infinite_health", "enemy_health_bars", "door", "wave", "grant")
var action := "spawn_1"

var _mat: StandardMaterial3D
var _lit := false

@onready var plate: MeshInstance3D = $Plate
@onready var label: Label3D = $Label


func _ready() -> void:
	# Unique material per button so lamps light independently.
	_mat = plate.get_active_material(0).duplicate() as StandardMaterial3D
	plate.set_surface_override_material(0, _mat)
	label.text = LABELS.get(action, action)
	_apply_lamp()


func take_hit(_damage: float, _hit_pos: Vector3, _normal: Vector3, _shape_index: int = 0) -> void:
	if not DebugManager.is_enabled():
		return
	match action:
		"spawn_1":
			DebugManager.spawn_zombies(1)
		"spawn_10":
			DebugManager.spawn_zombies(10)
		"infinite_ammo", "infinite_health":
			_lit = DebugManager.toggle_flag(StringName(action))
		"enemy_health_bars":
			_lit = DebugManager.toggle_flag(&"show_enemy_health")
		"door":
			_lit = DebugManager.toggle_door()
		"wave":
			_lit = DebugManager.toggle_wave_stub()
		"grant":
			DebugManager.grant_supplies()
	if action in TOGGLES:
		_apply_lamp()
	else:
		_flash()


## Toggle lamp: bright green when on, dim red when off — readable at a glance.
func _apply_lamp() -> void:
	if _lit:
		_mat.emission = Color(0.2, 1.0, 0.3)
		_mat.emission_energy_multiplier = 1.8
	else:
		_mat.emission = Color(0.9, 0.15, 0.1)
		_mat.emission_energy_multiplier = 0.25


func _flash() -> void:
	_mat.emission = Color(1.0, 0.9, 0.5)
	_mat.emission_energy_multiplier = 2.5
	var tween := create_tween()
	tween.tween_property(_mat, "emission_energy_multiplier", 0.25, 0.35)
	tween.tween_callback(_apply_lamp)
