extends Node
## Staggered navigation (DESIGN_DOC §8.4): repaths a small, fixed number of
## enemies per physics tick, round-robin, instead of every enemy every frame.
## Enemies read their agent's current path in _physics_process but never set
## their own target — this manager is the ONLY writer of agent.target_position.
##
## Group behavior (ARCH_PLAN §4) lives here too, still inside the one writer:
## each registered enemy holds a stable slot index; near the player the slot
## maps to a fixed ring angle (anti-stack fan-out), farther out a configured
## fraction of slots approach with a lateral flank offset. RVO separation
## params are applied to agents at registration — config-gated, shipped OFF
## until PROFILING_PLAYBOOK measurement #4 clears the cost. Every knob lives
## in DirectorConfig.

## At the 50-enemy ceiling this still sweeps everyone every ~0.4 s, which is
## plenty for shamblers chasing one player.
const UPDATES_PER_TICK := 2

var config: DirectorConfig = preload("res://resources/config/greybox_director.tres")

var _enemies: Array[Enemy] = []
var _cursor := 0
var _player: Node3D
## enemy → stable slot index: drives the per-enemy ring angle and flank role
## so targets never jitter frame-to-frame. Freed indices are recycled.
var _slots := {}
var _free_slots: Array[int] = []
var _next_slot := 0


func register(enemy: Enemy) -> void:
	if not _enemies.has(enemy):
		_enemies.append(enemy)
		var slot: int
		if _free_slots.is_empty():
			slot = _next_slot
			_next_slot += 1
		else:
			slot = _free_slots.pop_back()
		_slots[enemy] = slot
	_apply_avoidance_config(enemy)


func unregister(enemy: Enemy) -> void:
	_enemies.erase(enemy)
	if _slots.has(enemy):
		_free_slots.append(_slots[enemy])
		_slots.erase(enemy)


func _physics_process(_delta: float) -> void:
	if _enemies.is_empty():
		return
	if not is_instance_valid(_player) or not _player.is_inside_tree():
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return
	for i in mini(UPDATES_PER_TICK, _enemies.size()):
		_cursor = _cursor % _enemies.size()
		var enemy := _enemies[_cursor]
		enemy.agent.target_position = _target_for(enemy, _player.global_position)
		_cursor += 1


## All group-behavior target math — no second writer, ever.
func _target_for(enemy: Enemy, player_pos: Vector3) -> Vector3:
	var slot: int = _slots.get(enemy, 0)
	var to_player := player_pos - enemy.global_position
	to_player.y = 0.0
	# Ring / anti-stack: near the player, target a stable per-slot point at
	# melee reach instead of stacking into the exact player pixel. World-fixed
	# slot angles make approachers fan out and surround.
	if to_player.length() <= config.ring_radius:
		var angle := deg_to_rad(config.ring_spacing_degrees * slot)
		return player_pos + Vector3(cos(angle), 0.0, sin(angle)) * config.ring_target_radius
	# Flank: offset the approach laterally, perpendicular to the enemy→player
	# line; non-flank slots aim true, exactly as before.
	var side := _flank_side(slot)
	if side != 0.0 and to_player.length_squared() > 0.0001:
		var lateral := to_player.normalized().cross(Vector3.UP)
		return player_pos + lateral * config.flank_distance * side
	return player_pos


## Flank role from the slot, stable for the enemy's lifetime: 0 = aim true,
## ±1 = lateral side. With flank_fraction 0.25 every 4th slot flanks,
## alternating sides so the arc widens on both wings.
func _flank_side(slot: int) -> float:
	if config.flank_fraction <= 0.0:
		return 0.0
	var period := maxi(1, roundi(1.0 / config.flank_fraction))
	if slot % period != 0:
		return 0.0
	@warning_ignore("integer_division")  # flanker ordinal — truncation intended
	return 1.0 if (slot / period) % 2 == 0 else -1.0


## RVO separation (ARCH_PLAN §4), applied at registration — the one place
## agent avoidance state is configured. When disabled (the shipped default)
## the enemy's movement step stays on its direct path, untouched.
func _apply_avoidance_config(enemy: Enemy) -> void:
	enemy.agent.avoidance_enabled = config.avoidance_enabled
	if config.avoidance_enabled:
		enemy.agent.radius = config.avoidance_radius
		enemy.agent.max_neighbors = config.avoidance_max_neighbors
		# RVO resolves crowd overlap with velocities up to max_speed (default
		# 10) — cap it at the enemy's own stat or packed zombies get flung
		# apart at ~4.5× walk speed (measured live at the 50-agent jam).
		enemy.agent.max_speed = enemy.move_speed
