class_name AutoTurret
extends TurretGun
## Sentry (first craftable, v0.5.0): aims itself at the nearest live enemy
## in its detection sphere and fires only when the shot will land — never
## wastes rounds on walls or corpses. Starts empty; resupply on E.

const AIM_TURN_SPEED := 10.0

@onready var detect: Area3D = $Detection
@onready var head: Node3D = $Head


func _ready() -> void:
	super()
	# The detection sphere IS the weapon range; shared shape resource must be
	# duplicated or every turret would resize together.
	var shape: CollisionShape3D = $Detection/CollisionShape3D
	shape.shape = shape.shape.duplicate()
	(shape.shape as SphereShape3D).radius = data.range_meters


func _physics_process(delta: float) -> void:
	super(delta)
	if loaded_ammo <= 0:
		return
	var target := _nearest_live_enemy()
	if target == null:
		return
	_aim_at(target, delta)
	try_fire(target.global_position + Vector3.UP, true)


func get_interact_prompt() -> String:
	var ammo_name := Inventory.display_name(data.ammo_type)
	if loaded_ammo >= capacity:
		return "%s full (%d/%d)" % [ammo_name, loaded_ammo, capacity]
	if Inventory.count(data.ammo_type) <= 0:
		return "Turret needs %s (%d/%d)" % [ammo_name, loaded_ammo, capacity]
	return "E: Load %s (%d/%d)" % [ammo_name, loaded_ammo, capacity]


func interact(_player) -> void:
	reload_from_inventory()


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
