class_name TurretGun
extends Buildable
## Shared core for player-built guns (auto sentry + mounted MG): a WeaponData
## hitscan, a local magazine, and resupply from the shared Inventory ammo
## pool. Subclasses only decide who aims and pulls the trigger.
##
## Scene contract (unique names): %Muzzle, %Flash, %FlashTimer, %FireAudio,
## %StatusLabel.

const FLASH_TIME := 0.06
## Retry delay when a sentry shot would hit a wall — avoids a raycast per
## physics frame while blocked.
const BLOCKED_RETRY := 0.15
## Shot rays hit world + enemies only — turret fire can never hurt the player.
const SHOT_MASK := 1 | 4

@export var data: WeaponData
@export var capacity := 120

var loaded_ammo := 0

var _cooldown := 0.0

@onready var muzzle: Node3D = %Muzzle
@onready var flash: Node3D = %Flash
@onready var flash_timer: Timer = %FlashTimer
@onready var fire_audio: AudioStreamPlayer3D = %FireAudio
@onready var status_label: Label3D = %StatusLabel


func _ready() -> void:
	super()
	assert(data != null, "TurretGun needs a WeaponData resource")
	fire_audio.stream = PlaceholderSfx.gunshot()
	flash_timer.timeout.connect(func() -> void: flash.visible = false)
	_update_status()


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)


func can_fire() -> bool:
	return loaded_ammo > 0 and _cooldown <= 0.0


## One hitscan round toward aim_point (with per-axis spread). With
## require_enemy_hit the round is only spent when the first hit is an enemy
## (sentry behavior — never wastes ammo on walls); without it, pulling the
## trigger always costs the round (mounted-gunner behavior).
func try_fire(aim_point: Vector3, require_enemy_hit: bool) -> bool:
	if not can_fire():
		return false
	var origin := muzzle.global_position
	var dir := (aim_point - origin).normalized()
	var spread := deg_to_rad(data.spread_degrees)
	dir = dir.rotated(Vector3.UP, randf_range(-spread, spread))
	var side := dir.cross(Vector3.UP)
	if side.length_squared() > 0.001:
		dir = dir.rotated(side.normalized(), randf_range(-spread, spread))
	var query := PhysicsRayQueryParameters3D.create(
			origin, origin + dir * data.range_meters, SHOT_MASK, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var enemy: Object = null
	if not hit.is_empty() and hit.collider is Enemy:
		enemy = hit.collider
	if require_enemy_hit and enemy == null:
		_cooldown = BLOCKED_RETRY
		return false
	loaded_ammo -= 1
	_cooldown = 1.0 / data.fire_rate
	if enemy:
		# Same contract as the player's gun: weak points work for free.
		enemy.take_hit(data.damage, hit.position, hit.normal, hit.shape)
	flash.visible = true
	flash_timer.start(FLASH_TIME)
	fire_audio.play()
	_update_status()
	return true


## Tops the magazine up from the shared pool; returns rounds moved.
func reload_from_inventory() -> int:
	var transfer := mini(capacity - loaded_ammo, Inventory.count(data.ammo_type))
	if transfer <= 0:
		return 0
	Inventory.consume(data.ammo_type, transfer)
	loaded_ammo += transfer
	_update_status()
	return transfer


func _update_status() -> void:
	status_label.text = "%d/%d" % [loaded_ammo, capacity]
	status_label.modulate = Color(0.5, 1.0, 0.6) if loaded_ammo > 0 else Color(1.0, 0.45, 0.35)
