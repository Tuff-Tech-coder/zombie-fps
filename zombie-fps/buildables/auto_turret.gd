class_name AutoTurret
extends Buildable
## First craftable (v0.5.0): sentry gun driven by a WeaponData resource.
## Feeds on the SAME Inventory ammo pool as the player's gun — every round
## loaded here is a round the sidearm can't fire. Starts empty; resupply via
## the interact ray. Idles with no ammo or no live target.

## Retry delay when the shot ray is blocked by level geometry — avoids
## paying a raycast every physics frame against a wall.
const BLOCKED_RETRY := 0.15
const AIM_TURN_SPEED := 10.0
const FLASH_TIME := 0.06
## Shot rays hit world + enemies only — a turret can never hurt the player.
const SHOT_MASK := 1 | 4

@export var data: WeaponData
@export var capacity := 120

var loaded_ammo := 0

var _cooldown := 0.0

@onready var detect: Area3D = $Detection
@onready var head: Node3D = $Head
@onready var muzzle: Node3D = $Head/Muzzle
@onready var flash: Node3D = $Head/Muzzle/Flash
@onready var flash_timer: Timer = $FlashTimer
@onready var fire_audio: AudioStreamPlayer3D = $FireAudio
@onready var status_label: Label3D = $StatusLabel


func _ready() -> void:
	super()
	assert(data != null, "AutoTurret needs a WeaponData resource")
	# The detection sphere IS the weapon range; shared shape resource must be
	# duplicated or every turret would resize together.
	var shape: CollisionShape3D = $Detection/CollisionShape3D
	shape.shape = shape.shape.duplicate()
	(shape.shape as SphereShape3D).radius = data.range_meters
	fire_audio.stream = PlaceholderSfx.gunshot()
	flash_timer.timeout.connect(func() -> void: flash.visible = false)
	_update_status()


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if loaded_ammo <= 0:
		return
	var target := _nearest_live_enemy()
	if target == null:
		return
	_aim_at(target, delta)
	if _cooldown <= 0.0:
		_fire_at(target)


func get_interact_prompt() -> String:
	var ammo_name := Inventory.display_name(data.ammo_type)
	if loaded_ammo >= capacity:
		return "%s full (%d/%d)" % [ammo_name, loaded_ammo, capacity]
	if Inventory.count(data.ammo_type) <= 0:
		return "Turret needs %s (%d/%d)" % [ammo_name, loaded_ammo, capacity]
	return "E: Load %s (%d/%d)" % [ammo_name, loaded_ammo, capacity]


func interact(_player) -> void:
	var transfer := mini(capacity - loaded_ammo, Inventory.count(data.ammo_type))
	if transfer <= 0:
		return
	Inventory.consume(data.ammo_type, transfer)
	loaded_ammo += transfer
	_update_status()


func _nearest_live_enemy() -> Enemy:
	# Corpses drop off the enemy layer in die(), so they leave the Area3D on
	# their own; the state check covers the same-frame kill edge.
	var best: Enemy = null
	var best_dist := INF
	for body in detect.get_overlapping_bodies():
		if body is Enemy and body.state != Enemy.State.DEAD:
			var dist := global_position.distance_squared_to(body.global_position)
			if dist < best_dist:
				best_dist = dist
				best = body
	return best


func _aim_at(target: Enemy, delta: float) -> void:
	var to_target := target.global_position - head.global_position
	to_target.y = 0.0
	if to_target.length_squared() < 0.0001:
		return
	head.rotation.y = lerp_angle(head.rotation.y,
			atan2(to_target.x, to_target.z) - global_rotation.y, AIM_TURN_SPEED * delta)


func _fire_at(target: Enemy) -> void:
	var origin := muzzle.global_position
	var aim_point := target.global_position + Vector3.UP * 1.0
	var dir := (aim_point - origin).normalized()
	var spread := deg_to_rad(data.spread_degrees)
	dir = dir.rotated(Vector3.UP, randf_range(-spread, spread))
	var query := PhysicsRayQueryParameters3D.create(
			origin, origin + dir * data.range_meters, SHOT_MASK, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not (hit.collider is Enemy):
		_cooldown = BLOCKED_RETRY  # wall in the way — wait, don't waste ammo
		return
	# Same contract as the player's gun: weak points work for free.
	hit.collider.take_hit(data.damage, hit.position, hit.normal, hit.shape)
	loaded_ammo -= 1
	_cooldown = 1.0 / data.fire_rate
	flash.visible = true
	flash_timer.start(FLASH_TIME)
	fire_audio.play()
	_update_status()


func _update_status() -> void:
	status_label.text = "%d/%d" % [loaded_ammo, capacity]
	status_label.modulate = Color(0.5, 1.0, 0.6) if loaded_ammo > 0 else Color(1.0, 0.45, 0.35)
