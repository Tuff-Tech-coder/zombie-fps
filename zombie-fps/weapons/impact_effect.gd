class_name ImpactEffect
extends Node3D
## Pooled hit feedback: spark burst + a scorch decal that fades out.
## Owned and recycled by the weapon's impact pool — never freed mid-game.

const DECAL_LIFETIME := 6.0

## Assign a real impact file here to replace the synth placeholder.
@export var impact_sound: AudioStream

var _age := DECAL_LIFETIME

@onready var sparks: CPUParticles3D = $Sparks
@onready var decal: Decal = $Decal
@onready var audio: AudioStreamPlayer3D = $Audio


func _ready() -> void:
	audio.stream = impact_sound if impact_sound else PlaceholderSfx.impact()
	audio.bus = AudioManager.SFX_BUS
	visible = false
	set_process(false)


func play_at(pos: Vector3, normal: Vector3) -> void:
	# Nudged off the surface so the decal never z-fights the wall.
	global_position = pos + normal * 0.01
	# Decals project along local -Y, so aim Y down the surface normal.
	global_basis = _basis_from_y(normal)
	visible = true
	_age = 0.0
	set_process(true)
	sparks.restart()
	audio.play()


func _process(delta: float) -> void:
	_age += delta
	decal.modulate.a = maxf(1.0 - _age / DECAL_LIFETIME, 0.0)
	if _age >= DECAL_LIFETIME:
		visible = false
		set_process(false)


static func _basis_from_y(y: Vector3) -> Basis:
	var x := y.cross(Vector3.FORWARD)
	if x.length_squared() < 0.001:  # normal is (anti)parallel to FORWARD
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	return Basis(x, y, x.cross(y))
