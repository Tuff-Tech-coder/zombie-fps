class_name ShootingTarget
extends StaticBody3D
## Greybox weapon-feel target: flashes on hit, topples when depleted, then
## resets itself so the range stays usable without restarting.

@export var max_health := 60.0
@export var reset_delay := 2.5

var _health := 0.0
var _flash := 0.0
var _downed := false
var _mat: StandardMaterial3D

@onready var body: MeshInstance3D = $Body


func _ready() -> void:
	_health = max_health
	# Unique material per target so one flashing target doesn't light them all.
	_mat = body.get_active_material(0).duplicate() as StandardMaterial3D
	body.set_surface_override_material(0, _mat)


func take_hit(damage: float, _hit_pos: Vector3, _normal: Vector3, _shape_index: int = 0) -> void:
	if _downed:
		return
	_flash = 1.0
	_health -= damage
	if _health <= 0.0:
		_topple()


func _process(delta: float) -> void:
	if _flash <= 0.0 and _mat.emission_energy_multiplier <= 0.0:
		return
	_flash = maxf(_flash - delta * 5.0, 0.0)
	_mat.emission_energy_multiplier = _flash * 4.0


func _topple() -> void:
	_downed = true
	var tween := create_tween()
	tween.tween_property(self, "rotation:x", deg_to_rad(-82.0), 0.3)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_interval(reset_delay)
	tween.tween_property(self, "rotation:x", 0.0, 0.5)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_reset)


func _reset() -> void:
	_health = max_health
	_downed = false
