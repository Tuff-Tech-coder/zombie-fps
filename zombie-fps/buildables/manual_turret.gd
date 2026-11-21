class_name ManualTurret
extends TurretGun
## Mounted MG (v0.5.1): the player mans it with E and becomes the trigger.
## While mounted the turret owns look/fire/reload input and the camera; the
## player's body stays parked at the Mount marker and remains vulnerable —
## rooted and exposed is the trade for the firepower.

## One E-press must not mount AND dismount: the same press reads as
## just_pressed in the player's idle frame and this turret's physics frame.
const MOUNT_INPUT_GRACE := 0.25

@export var yaw_limit_degrees := 60.0
@export var pitch_limit_degrees := 30.0
@export var mouse_sensitivity := 0.0022

var _mounted_player: Player = null
var _yaw := 0.0
var _pitch := 0.0
var _grace := 0.0

@onready var yaw_pivot: Node3D = $YawPivot
@onready var pitch_pivot: Node3D = $YawPivot/PitchPivot
@onready var cam: Camera3D = $YawPivot/PitchPivot/Camera3D
@onready var mount_point: Marker3D = $Mount


func get_interact_prompt() -> String:
	if _mounted_player:
		return ""
	return "E: Man %s (%d/%d)" % [data.display_name, loaded_ammo, capacity]


func interact(player) -> void:
	if _mounted_player == null:
		player.enter_mount(self)


## Turret side of the mount handshake — only Player.enter_mount calls this.
func on_mounted(player: Player) -> void:
	_mounted_player = player
	_grace = MOUNT_INPUT_GRACE
	_yaw = 0.0
	_pitch = 0.0
	yaw_pivot.rotation.y = 0.0
	pitch_pivot.rotation.x = 0.0
	cam.current = true
	# HUD reuse: announce this gun; the sidearm re-announces on dismount.
	EventBus.weapon_equipped.emit(data)
	EventBus.ammo_changed.emit(loaded_ammo, Inventory.count(data.ammo_type))
	EventBus.interact_prompt_changed.emit("E: dismount    R: reload")


func on_dismounted() -> void:
	_mounted_player = null
	cam.current = false
	EventBus.interact_prompt_changed.emit("")


func _unhandled_input(event: InputEvent) -> void:
	if _mounted_player == null:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_yaw = clampf(_yaw - motion.relative.x * mouse_sensitivity,
				-deg_to_rad(yaw_limit_degrees), deg_to_rad(yaw_limit_degrees))
		_pitch = clampf(_pitch - motion.relative.y * mouse_sensitivity,
				-deg_to_rad(pitch_limit_degrees), deg_to_rad(pitch_limit_degrees))
		yaw_pivot.rotation.y = _yaw
		pitch_pivot.rotation.x = _pitch


func _physics_process(delta: float) -> void:
	super(delta)
	if _mounted_player == null:
		return
	_grace = maxf(_grace - delta, 0.0)
	if Input.is_action_pressed("fire"):
		# Barrel-forward shot: the gunner spends a round whether it lands or not.
		var aim := muzzle.global_position - pitch_pivot.global_basis.z * data.range_meters
		if try_fire(aim, false):
			EventBus.ammo_changed.emit(loaded_ammo, Inventory.count(data.ammo_type))
	if Input.is_action_just_pressed("reload"):
		if reload_from_inventory() > 0:
			EventBus.ammo_changed.emit(loaded_ammo, Inventory.count(data.ammo_type))
	if _grace <= 0.0 and Input.is_action_just_pressed("interact"):
		_mounted_player.exit_mount()
