class_name HitscanWeapon
extends Weapon
## Raycast gun. Fires from the active camera's center so hits always match
## the crosshair — the viewmodel is purely cosmetic.

const IMPACT_POOL_SIZE := 16
const MODEL_RECOVER_SPEED := 12.0

var _impact_scene: PackedScene = preload("res://weapons/impact_effect.tscn")
var _impacts: Array[ImpactEffect] = []
var _next_impact := 0
var _exclude: Array[RID] = []
var _model_rest: Transform3D

@onready var model: Node3D = $Model
@onready var muzzle_flash: Node3D = $Model/MuzzleFlash
@onready var fire_audio: AudioStreamPlayer = $FireAudio
@onready var flash_timer: Timer = $FlashTimer


func _ready() -> void:
	super()
	_model_rest = model.transform
	fire_audio.stream = PlaceholderSfx.gunshot()
	flash_timer.timeout.connect(func() -> void: muzzle_flash.visible = false)
	# The wielder's body must never eat its own rays.
	var body: Node = get_parent()
	while body != null and not (body is CharacterBody3D):
		body = body.get_parent()
	if body:
		_exclude = [(body as CharacterBody3D).get_rid()]
	# Deferred: current_scene isn't set yet while the world is instancing.
	_build_impact_pool.call_deferred()


func _process(delta: float) -> void:
	super(delta)
	# Spring the viewmodel back to rest after recoil kicks.
	model.transform = model.transform.interpolate_with(
			_model_rest, minf(delta * MODEL_RECOVER_SPEED, 1.0))


func _do_fire() -> void:
	_fire_ray()
	fire_audio.play()
	muzzle_flash.visible = true
	muzzle_flash.scale = Vector3.ONE * randf_range(0.8, 1.2)
	flash_timer.start()
	model.position.z += 0.06
	model.rotation.x += deg_to_rad(2.5)


func _fire_ray() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var spread := deg_to_rad(data.spread_degrees)
	var dir := -cam.global_basis.z
	dir = dir.rotated(cam.global_basis.x, randf_range(-spread, spread))
	dir = dir.rotated(cam.global_basis.y, randf_range(-spread, spread))
	var query := PhysicsRayQueryParameters3D.create(
			cam.global_position, cam.global_position + dir * data.range_meters)
	query.exclude = _exclude
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider: Object = hit.collider
	if collider and collider.has_method("take_hit"):
		# shape index lets multi-shape bodies (enemies) resolve weak points
		collider.take_hit(data.damage, hit.position, hit.normal, hit.shape)
	_spawn_impact(hit.position, hit.normal)


func _build_impact_pool() -> void:
	# Pooled up front per DESIGN_DOC §8.4 — no instantiate churn while firing.
	# Effects live under the scene root so they don't inherit viewmodel motion.
	var host: Node = get_tree().current_scene
	if host == null:
		host = get_tree().root
	for i in IMPACT_POOL_SIZE:
		var fx := _impact_scene.instantiate() as ImpactEffect
		host.add_child(fx)
		_impacts.append(fx)


func _spawn_impact(pos: Vector3, normal: Vector3) -> void:
	if _impacts.is_empty():
		return
	_impacts[_next_impact].play_at(pos, normal)
	_next_impact = (_next_impact + 1) % _impacts.size()
