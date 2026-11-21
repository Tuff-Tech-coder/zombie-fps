class_name DestructibleLight
extends StaticBody3D
## Shootable light (DESIGN_DOC §7): losing it is meant to hurt visibility —
## the resulting darkness is part of the tension, so it never comes back on.

## Assign a real glass-break file here to replace the synth placeholder.
@export var break_sound: AudioStream

var _broken := false

@onready var light: OmniLight3D = $Light
@onready var bulb: MeshInstance3D = $Bulb
@onready var sparks: CPUParticles3D = $Sparks
@onready var audio: AudioStreamPlayer3D = $BreakAudio


func _ready() -> void:
	audio.stream = break_sound if break_sound else PlaceholderSfx.impact()
	audio.bus = AudioManager.SFX_BUS


func take_hit(_damage: float, _hit_pos: Vector3, _normal: Vector3, _shape_index: int = 0) -> void:
	if _broken:
		return
	_broken = true
	light.visible = false
	bulb.visible = false  # hiding the bulb reads as "shattered" in greybox
	sparks.restart()
	audio.play()
