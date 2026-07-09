class_name Weapon
extends Node3D
## Gun base: ammo, fire-rate gating, reload timing (DESIGN_DOC §8.2).
## Subclasses implement _do_fire() — hitscan today, projectile later.
## Optional child nodes named "ReloadAudio"/"DryAudio" are used if present,
## so subclass scenes opt in without the base hard-requiring them.

signal fired

@export var data: WeaponData

var mag := 0
var reserve := 0
var reloading := false

var _cooldown := 0.0

@onready var _reload_audio: AudioStreamPlayer = get_node_or_null("ReloadAudio")
@onready var _dry_audio: AudioStreamPlayer = get_node_or_null("DryAudio")


func _ready() -> void:
	assert(data != null, "Weapon requires a WeaponData resource")
	mag = data.mag_size
	reserve = data.reserve_ammo
	if _reload_audio:
		_reload_audio.stream = PlaceholderSfx.reload_click()
	if _dry_audio:
		_dry_audio.stream = PlaceholderSfx.dry_click()
	# Deferred so HUD listeners (siblings in the world scene) exist first.
	call_deferred("_announce")


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)


func try_fire() -> void:
	if reloading or _cooldown > 0.0:
		return
	if mag <= 0:
		_cooldown = 0.3  # dry clicks tick slower than the real fire rate
		if _dry_audio:
			_dry_audio.play()
		start_reload()  # empty trigger pull auto-reloads
		return
	if not DebugManager.infinite_ammo:  # the one debug check (CODE_GUIDE rules)
		mag -= 1
	_cooldown = 1.0 / data.fire_rate
	_do_fire()
	fired.emit()
	EventBus.weapon_fired.emit(self)
	EventBus.ammo_changed.emit(mag, reserve)


func start_reload() -> void:
	if reloading or reserve <= 0 or mag == data.mag_size:
		return
	reloading = true
	if _reload_audio:
		_reload_audio.play()
	EventBus.weapon_reload_started.emit(data.reload_time)
	await get_tree().create_timer(data.reload_time).timeout
	if not is_inside_tree():
		return
	var loaded := mini(data.mag_size - mag, reserve)
	mag += loaded
	reserve -= loaded
	reloading = false
	if _reload_audio:
		_reload_audio.play()
	EventBus.weapon_reload_finished.emit()
	EventBus.ammo_changed.emit(mag, reserve)


func _announce() -> void:
	EventBus.weapon_equipped.emit(data)
	EventBus.ammo_changed.emit(mag, reserve)


func _do_fire() -> void:
	push_warning("Weapon subclass must override _do_fire()")
