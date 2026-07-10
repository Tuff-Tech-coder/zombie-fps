class_name Player
extends CharacterBody3D
## First-person controller: movement, look, and fire *input* only. All gun
## behavior lives on the equipped Weapon (first child of WeaponHolder).

@export_group("Movement")
@export var walk_speed := 4.5
@export var sprint_multiplier := 1.55
@export var crouch_multiplier := 0.55
@export var acceleration := 40.0    ## m/s² on the ground (doubles as friction)
@export var jump_velocity := 4.6

@export_group("Bunny Hop")
## Hard horizontal ceiling as a multiple of walk_speed. Only ever bites while
## airborne — grounded movement is already clamped to walk/sprint.
@export var bhop_speed_cap_mult := 2.2
## Per-tick air wish-speed cap (the Source "30 units" analog). Small on
## purpose: it kills straight-line air gain while strafe+turn stays additive.
@export var air_speed_cap := 0.7
@export var air_accelerate := 60.0      ## autohop / held-jump hops: slow build
@export var air_accelerate_tap := 90.0  ## fresh-tap hops: fast build, same cap
@export var jump_buffer_time := 0.1     ## seconds a jump press stays usable
@export var autohop_enabled := true     ## held jump re-hops on landing

@export_group("Look")
@export var mouse_sensitivity := 0.0022  ## radians per mouse pixel
@export var pitch_limit_degrees := 89.0

@export_group("Crouch")
@export var stand_height := 1.8
@export var crouch_height := 1.2
@export var crouch_lerp_speed := 10.0

@export_group("Stats")
@export var max_health := 100.0

## Eye sits this far below the capsule top.
const EYE_DROP := 0.15

var health := 100.0
var _pitch := 0.0
var _crouching := false
var _dead := false
var _jump_buffer := 0.0
var _hop_accel := 0.0  # air accel chosen at liftoff, held for the whole hop
var _tucked := false   # airborne crouch: capsule anchored at the top

@onready var head: Node3D = $Head
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var capsule: CapsuleShape3D = collision_shape.shape as CapsuleShape3D
@onready var weapon: Weapon = $Head/Camera3D/WeaponHolder.get_child(0) as Weapon


func _ready() -> void:
	health = max_health
	_hop_accel = air_accelerate
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
	_update_jump_buffer(delta)

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)
	wish.y = 0.0
	if wish.length_squared() > 0.0:
		wish = wish.normalized()

	if is_on_floor():
		var tap := _jump_buffer > 0.0
		if tap or (autohop_enabled and Input.is_action_pressed("jump")):
			_jump_buffer = 0.0
			velocity.y = jump_velocity
			# The accel picked at liftoff rides the whole hop. A buffered
			# fresh tap earns the faster build even if jump is also held,
			# so rhythmic re-tapping beats holding.
			_hop_accel = air_accelerate_tap if tap else air_accelerate
			# Below run speed the hop frame still gets ground acceleration —
			# otherwise holding jump from a standstill pogos at air-cap speed
			# forever. At or above run speed it's skipped: that's the
			# momentum carry that makes bhop work.
			if Vector2(velocity.x, velocity.z).length() < _current_speed():
				var hvel := Vector3(velocity.x, 0.0, velocity.z)\
						.move_toward(wish * _current_speed(), acceleration * delta)
				velocity.x = hvel.x
				velocity.z = hvel.z
			_accelerate(wish, air_speed_cap, _hop_accel, delta)
		else:
			_hop_accel = air_accelerate  # ledge walk-offs get the base accel
			# Grounded move_toward doubles as friction: a missed hop bleeds
			# speed back toward walk/sprint.
			var hvel := Vector3(velocity.x, 0.0, velocity.z)\
					.move_toward(wish * _current_speed(), acceleration * delta)
			velocity.x = hvel.x
			velocity.z = hvel.z
	else:
		velocity += get_gravity() * delta
		_accelerate(wish, air_speed_cap, _hop_accel, delta)

	_cap_horizontal_speed()
	move_and_slide()


func _update_jump_buffer(delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = jump_buffer_time
	else:
		_jump_buffer = maxf(_jump_buffer - delta, 0.0)


## Quake-style air accelerate: only the velocity component along wishdir is
## capped (at wishspeed), so strafing while turning into the strafe keeps
## adding speed, while pushing straight ahead adds nothing.
func _accelerate(wishdir: Vector3, wishspeed: float, accel: float, delta: float) -> void:
	var current := Vector2(velocity.x, velocity.z).dot(Vector2(wishdir.x, wishdir.z))
	var add := wishspeed - current
	if add <= 0.0:
		return
	var amount := minf(accel * wishspeed * delta, add)
	velocity.x += wishdir.x * amount
	velocity.z += wishdir.z * amount


func _cap_horizontal_speed() -> void:
	var flat := Vector2(velocity.x, velocity.z)
	var cap := walk_speed * bhop_speed_cap_mult
	if flat.length() > cap:
		flat = flat.normalized() * cap
		velocity.x = flat.x
		velocity.z = flat.y


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
	capsule.height = lerpf(capsule.height, target, minf(crouch_lerp_speed * delta, 1.0))

	# Airborne duck anchors the capsule TOP so the feet tuck up by
	# (stand - crouch) ≈ 0.6 m — the reach that lets a crouch-jump mount a
	# ledge a plain jump can't. Grounded crouch stays feet-anchored.
	var tucked := _crouching and not is_on_floor()
	if _tucked and not tucked and is_on_floor():
		# Landing while tucked: lift the origin so the capsule bottom (the
		# feet) stays put through the re-anchor. Keeps ledge landings from
		# ejecting the body and keeps the eye continuous.
		global_position.y += stand_height - capsule.height
	_tucked = tucked

	# The shape moves instantly (physics must be exact); the eye lerps so
	# transitions never snap the camera.
	if tucked:
		collision_shape.position.y = stand_height - capsule.height * 0.5
	else:
		collision_shape.position.y = capsule.height * 0.5
	var eye_target := (stand_height - EYE_DROP) if tucked else (capsule.height - EYE_DROP)
	head.position.y = lerpf(head.position.y, eye_target, minf(crouch_lerp_speed * delta, 1.0))


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


func take_damage(amount: float) -> void:
	if _dead:
		return
	if DebugManager.infinite_health:  # the one debug check (CODE_GUIDE rules)
		return
	health = maxf(health - amount, 0.0)
	EventBus.player_health_changed.emit(health, max_health)
	if health <= 0.0:
		_die()


func _die() -> void:
	_dead = true
	# The game-over overlay listens for this and freezes the tree.
	EventBus.player_died.emit()


func _on_weapon_fired() -> void:
	# Camera recoil stays applied (the player re-aims); viewmodel kick is the
	# weapon's own job.
	_set_pitch(_pitch + deg_to_rad(weapon.data.recoil_pitch))
	rotate_y(deg_to_rad(randf_range(-weapon.data.recoil_yaw, weapon.data.recoil_yaw)))


func _announce_health() -> void:
	EventBus.player_health_changed.emit(health, max_health)
