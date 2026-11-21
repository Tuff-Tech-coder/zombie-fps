extends Node
## Animation-LOD framework (ARCH_PLAN §3, DESIGN_DOC §8.4). Assigns each active
## enemy an LOD level from distance-to-camera + on-screen visibility and drives
## its EnemyVisual seam. Skeletal animation is the dominant per-enemy cost in
## Godot 4, so distant/off-screen enemies get throttled or frozen while near
## on-screen ones animate fully.
##
## DECISIONS live here; EXECUTION lives in EnemyVisual.set_lod_level(). Mirrors
## the EnemyNavManager pattern: enemies register() in reset() and unregister()
## in deactivate() (NOT die() — a corpse's death animation stays LOD-managed
## until it actually pools), and only a config-driven fraction are evaluated
## per physics tick, round-robin. Every threshold is in LODConfig — no tuned
## numbers here.

var config: LODConfig = preload("res://resources/config/lod_config.tres")

var _enemies: Array[Enemy] = []
var _cursor := 0


func register(enemy: Enemy) -> void:
	if not _enemies.has(enemy):
		_enemies.append(enemy)


func unregister(enemy: Enemy) -> void:
	_enemies.erase(enemy)


func _physics_process(_delta: float) -> void:
	if _enemies.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	for i in mini(config.evaluations_per_tick, _enemies.size()):
		# The set can empty mid-loop (a mass release racing this tick) —
		# the entry guard alone leaves the modulo below dividing by zero.
		if _enemies.is_empty():
			break
		_cursor %= _enemies.size()
		_evaluate(_enemies[_cursor], cam)
		_cursor += 1


## LOD-level distribution for the perf overlay (Phase 4): {level: count}.
func level_counts() -> Dictionary:
	var counts := {
		EnemyVisual.LOD.FULL: 0,
		EnemyVisual.LOD.REDUCED: 0,
		EnemyVisual.LOD.PAUSED: 0,
		EnemyVisual.LOD.CULLED: 0,
	}
	for enemy in _enemies:
		var level: int = enemy.visual.lod_level()
		counts[level] += 1
	return counts


func active_count() -> int:
	return _enemies.size()


func _evaluate(enemy: Enemy, cam: Camera3D) -> void:
	# Sample the chest so a body at the frustum edge still counts as visible.
	var sample := enemy.global_position + Vector3.UP
	var dist := cam.global_position.distance_to(sample)
	var in_view := cam.is_position_in_frustum(sample)
	var current: int = enemy.visual.lod_level()

	var level := _distance_level(dist, current)
	if not in_view:
		level += config.offscreen_demotion

	# Cull zone: beyond paused_distance the raw level is 3. Hand off to the
	# (unimplemented, data-gated) background tier if enabled; then clamp to
	# CULLED or PAUSED depending on whether visuals are allowed to hide.
	if config.background_tier_enabled and level >= EnemyVisual.LOD.CULLED:
		_hand_off_to_background(enemy)
	var max_level: int = EnemyVisual.LOD.CULLED if config.cull_visuals else EnemyVisual.LOD.PAUSED
	level = clampi(level, EnemyVisual.LOD.FULL, max_level)

	enemy.visual.set_lod_level(level, _update_hz_for(level))


## Distance → level (0 FULL, 1 REDUCED, 2 PAUSED, 3 cull-zone) with sticky
## hysteresis: to leave the current level you must cross the band edge by the
## hysteresis margin, so an enemy hovering on a boundary doesn't flip-flop.
func _distance_level(dist: float, current: int) -> int:
	var bands := [config.full_distance, config.reduced_distance, config.paused_distance]
	var level := 0
	for i in bands.size():
		# Widen the boundary outward while at/inside this band, inward once
		# past it — the current level "wins" the dead zone either way.
		var edge: float = bands[i] + (config.hysteresis if current <= i else -config.hysteresis)
		if dist > edge:
			level = i + 1
		else:
			break
	return level


func _update_hz_for(level: int) -> float:
	match level:
		EnemyVisual.LOD.REDUCED:
			return config.reduced_update_hz
		_:
			# FULL is engine-ticked (hz unused); PAUSED/CULLED use the pause rate.
			return config.paused_update_hz


## Framework seam (DESIGN_DOC §8.4) — intentionally empty. If a MultiMesh /
## simple-path background-crowd tier is ever built, distant enemies are handed
## off here. Gated by LODConfig.background_tier_enabled (default false), so this
## never fires until Opus decides the tier is warranted post-profiling.
func _hand_off_to_background(_enemy: Enemy) -> void:
	pass
