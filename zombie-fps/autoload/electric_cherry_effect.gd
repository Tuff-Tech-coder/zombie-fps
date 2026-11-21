class_name ElectricCherryEffect
extends Node
## Electric Cherry (ON_RELOAD): every reload releases a player-centered shock
## — AoE stun + damage, scaling with how empty the mag was. The floor keeps a
## near-full reload zapping a little; an empty-mag reload hits hard. Attached
## by PerkManager while the perk is active.

var _perk: Perk


func setup(perk: Perk) -> void:
	_perk = perk
	EventBus.weapon_reload_started.connect(_on_reload_started)


func _on_reload_started(_duration: float, mag: int, mag_size: int) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var emptiness := 1.0 - float(mag) / maxf(float(mag_size), 1.0)
	var damage := lerpf(_param("min_shock_damage", 20.0),
			_param("max_shock_damage", 90.0), emptiness)
	var radius: float = _param("radius", 3.5)
	var stun: float = _param("stun", 1.5)
	for e in EnemyPool.get_children():
		if e is Enemy and e.active and e.state != Enemy.State.DEAD \
				and e.global_position.distance_to(player.global_position) <= radius:
			e.stun(stun)
			e.take_damage(damage)  # environmental — no weak point
	_spawn_fx(player.global_position, radius)


func _param(key: String, default: float) -> float:
	return float(_perk.params.get(key, default))


## Transient one-shot ring of sparks + zap audio. Reload-rate, not hot-path —
## a short-lived node is fine here (the pooling rule targets per-shot churn).
func _spawn_fx(pos: Vector3, radius: float) -> void:
	var fx := Node3D.new()
	var sparks := CPUParticles3D.new()
	sparks.amount = 40
	sparks.lifetime = 0.3
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = radius * 0.6
	sparks.gravity = Vector3.ZERO
	sparks.initial_velocity_min = 1.0
	sparks.initial_velocity_max = 3.0
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.03, 0.2, 0.03)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.6, 0.85, 1.0)
	mesh.material = mat
	sparks.mesh = mesh
	fx.add_child(sparks)
	var audio := AudioStreamPlayer3D.new()
	audio.stream = PlaceholderSfx.impact()
	audio.bus = AudioManager.SFX_BUS
	audio.volume_db = -2.0
	fx.add_child(audio)
	get_tree().current_scene.add_child(fx)
	fx.global_position = pos + Vector3.UP
	sparks.emitting = true
	audio.play()
	get_tree().create_timer(1.0).timeout.connect(fx.queue_free)
