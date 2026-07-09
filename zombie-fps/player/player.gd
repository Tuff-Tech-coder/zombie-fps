class_name Player
extends CharacterBody3D
## First-person controller: movement, look, and fire *input* only. All gun
## behavior lives on the equipped Weapon (first child of WeaponHolder).

@export_group("Movement")
@export var walk_speed := 4.5
@export var sprint_multiplier := 1.55
@export var crouch_multiplier := 0.55
@export var acceleration := 40.0    ## m/s² on the ground
@export var air_control := 0.35    ## fraction of ground acceleration kept airborne
@export var jump_velocity := 4.6

@export_group("Look")
@export var mouse_sensitivity := 0.0022  ## radians per mouse pixel
@export var pitch_limit_degrees := 89.0

@export_group("Crouch")
@export var stand_height := 1.8
@export var crouch_height := 1.2
@export var crouch_lerp_speed := 10.0

@export_group("Stats")
@export var max_health := 100.0  ## fixed stub until damage arrives in v0.3.0

var health := 100.0
var _pitch := 0.0
var _crouching := false

@onready var head: Node3D = $Head
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var capsule: CapsuleShape3D = collision_shape.shape as CapsuleShape3D
@onready var weapon: Weapon = $Head/Camera3D/WeaponHolder.get_child(0) as Weapon


func _ready() -> void:
	health = max_health
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	weapon.fired.connect(_on_weapon_fired)
	# Deferred so the HUD (a sibling) is connected before the first broadcast.
	call_deferred("_announce_health")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		rotate_y(-motion.relative.x * mouse_sensitivity)
		_set_pitch(_pitch - motion.relative.y * mouse_sensitivity)
	elif event.is_action_pressed("ui_cancel"):
		# Testing convenience: Esc frees the mouse, any click recaptures.
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if weapon.data.automatic:
		if Input.is_action_pressed("fire"):
			weapon.try_fire()
	elif Input.is_action_just_pressed("fire"):
		weapon.try_fire()
	if Input.is_action_just_pressed("reload"):
		weapon.start_reload()


func _physics_process(delta: float) -> void:
	_update_crouch(delta)

	if not is_on_floor():
		velocity += get_gravity() * delta
	elif Input.is_action_just_pressed("jump") and not _crouching:
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)
	wish.y = 0.0
	if wish.length_squared() > 0.0:
		wish = wish.normalized()
	# Reduced-but-nonzero air accel keeps jumps steerable.
	var accel := acceleration if is_on_floor() else acceleration * air_control
	var hvel := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * _current_speed(), accel * delta)
	velocity.x = hvel.x
	velocity.z = hvel.z
	move_and_slide()


func _current_speed() -> float:
	if _crouching:
		return walk_speed * crouch_multiplier
	if Input.is_action_pressed("sprint") and is_on_floor():
		return walk_speed * sprint_multiplier
	return walk_speed


func _update_crouch(delta: float) -> void:
	var want := Input.is_action_pressed("crouch")
	if not want and _crouching and not _has_headroom():
		want = true  # something overhead — stay down until it's clear
	_crouching = want
	var target := crouch_height if _crouching else stand_height
	if absf(capsule.height - target) < 0.001:
		return
	capsule.height = lerpf(capsule.height, target, minf(crouch_lerp_speed * delta, 1.0))
	collision_shape.position.y = capsule.height * 0.5
	head.position.y = capsule.height - 0.15


func _has_headroom() -> bool:
	var from := global_position + Vector3.UP * (capsule.height - 0.1)
	var to := global_position + Vector3.UP * (stand_height + 0.1)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _set_pitch(value: float) -> void:
	_pitch = clampf(value,
			-deg_to_rad(pitch_limit_degrees), deg_to_rad(pitch_limit_degrees))
	head.rotation.x = _pitch


func _on_weapon_fired() -> void:
	# Camera recoil stays applied (the player re-aims); viewmodel kick is the
	# weapon's own job.
	_set_pitch(_pitch + deg_to_rad(weapon.data.recoil_pitch))
	rotate_y(deg_to_rad(randf_range(-weapon.data.recoil_yaw, weapon.data.recoil_yaw)))


func _announce_health() -> void:
	EventBus.player_health_changed.emit(health, max_health)
