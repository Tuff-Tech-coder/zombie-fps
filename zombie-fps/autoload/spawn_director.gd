extends Node
## Spawn/AI director (ARCH_PLAN §4): answers RoundManager's three questions —
## where to spawn, how fast, and how many at once. It NEVER spawns and never
## counts budget: round lifecycle stays in RoundManager; this node is the
## placement/pacing brain it queries. Round progress for the pressure curve
## comes from RoundManager.round_progress(), not a parallel counter.
##
## Placement scores the existing enemy_spawn_point markers: never inside the
## player's camera frustum, never closer than min_spawn_distance, preferring
## markers behind the player inside the preferred range — and cohort bursts
## stick to one marker cluster so a wave funnels through the same chokepoint
## together. Every knob lives in DirectorConfig.

var config: DirectorConfig = preload("res://resources/config/greybox_director.tres")

var _burst_remaining := 0
var _burst_marker: Node3D
var _warned_no_markers := false
var _warned_fallback := false


## Scored placement. Never fails: if every marker is rejected, the least
## visible / farthest one is returned anyway (warned once) — a round must
## never stall on placement.
func next_spawn_position() -> Vector3:
	var markers := get_tree().get_nodes_in_group("enemy_spawn_point")
	if markers.is_empty():
		if not _warned_no_markers:
			_warned_no_markers = true
			push_error("SpawnDirector: no enemy_spawn_point markers in scene")
		return Vector3.ZERO
	var chosen := _choose_marker(markers)
	_burst_marker = chosen
	_burst_remaining -= 1
	var jitter := Vector3(randf_range(-config.spawn_jitter, config.spawn_jitter), 0.0,
			randf_range(-config.spawn_jitter, config.spawn_jitter))
	return chosen.global_position + jitter


## Pressure-mapped seconds between spawns. RoundManager re-reads this on
## every (re)arm of its one-shot spawn timer, so pacing shifts spawn-by-spawn.
func current_spawn_interval() -> float:
	return lerpf(config.interval_relaxed, config.interval_peak, _pressure())


## Pressure-mapped concurrency ceiling. Scales WITHIN RoundConfig's
## max_concurrent (still the data owner), hard-clamped to the pool cap.
func current_concurrency_ceiling() -> int:
	var fraction := lerpf(config.concurrent_floor_fraction, 1.0, _pressure())
	return clampi(roundi(fraction * RoundManager.config.max_concurrent), 1, EnemyPool.MAX_ENEMIES)


func _pressure() -> float:
	# A missing curve degrades to the flat 0.5 the shipped .tres authors.
	if config.pressure_curve == null:
		return 0.5
	return config.pressure_curve.sample(RoundManager.round_progress())


func _choose_marker(markers: Array) -> Node3D:
	if _burst_remaining <= 0:
		_burst_remaining = randi_range(config.burst_size_range.x, config.burst_size_range.y)
		_burst_marker = null  # new cohort → free to pick a new cluster
	var player := get_tree().get_first_node_in_group("player") as Node3D
	# Same live-camera lookup as AnimationLODManager — never a stored ref.
	var cam := get_viewport().get_camera_3d()
	var survivors: Array[Node3D] = []
	for marker: Node3D in markers:
		if _rejected(marker, player, cam):
			continue
		survivors.append(marker)
	if survivors.is_empty():
		if not _warned_fallback:
			_warned_fallback = true
			push_warning("SpawnDirector: every spawn marker rejected — falling back to least-visible")
		return _fallback_marker(markers, player, cam)
	# Cohort stickiness: while a burst is running, reuse its cluster with the
	# configured probability — funnelling is emergent from placement alone.
	if _burst_marker != null and survivors.has(_burst_marker) \
			and randf() < config.burst_marker_stickiness:
		return _burst_marker
	return _best_scored(survivors, player, cam)


func _rejected(marker: Node3D, player: Node3D, cam: Camera3D) -> bool:
	# Chest-height sample, matching AnimationLODManager's frustum probe.
	if cam != null and cam.is_position_in_frustum(marker.global_position + Vector3.UP):
		return true
	if player != null \
			and marker.global_position.distance_to(player.global_position) < config.min_spawn_distance:
		return true
	return false


func _best_scored(candidates: Array[Node3D], player: Node3D, cam: Camera3D) -> Node3D:
	var best: Node3D = candidates[0]
	var best_score := -INF
	for marker in candidates:
		var score := _score(marker, player, cam)
		if score > best_score:
			best_score = score
			best = marker
	return best


func _score(marker: Node3D, player: Node3D, cam: Camera3D) -> float:
	if player == null:
		return 0.0
	var to_marker := marker.global_position - player.global_position
	var dist := to_marker.length()
	var score := 0.0
	# View-dot is negative behind the player, so -dot rewards spawning there.
	if cam != null and dist > 0.001:
		var view_dir := -cam.global_transform.basis.z
		score += -view_dir.dot(to_marker / dist) * config.behind_bias
	if dist >= config.preferred_distance_range.x and dist <= config.preferred_distance_range.y:
		score += 1.0
	return score


## The all-rejected fallback: out-of-frustum beats in-view outright; distance
## from the player breaks ties. No filters — this must always return a marker.
func _fallback_marker(markers: Array, player: Node3D, cam: Camera3D) -> Node3D:
	var best: Node3D = markers[0]
	var best_out := false
	var best_dist := -INF
	for marker: Node3D in markers:
		var out := cam == null or not cam.is_position_in_frustum(marker.global_position + Vector3.UP)
		var dist := 0.0
		if player != null:
			dist = marker.global_position.distance_to(player.global_position)
		if (out and not best_out) or (out == best_out and dist > best_dist):
			best = marker
			best_out = out
			best_dist = dist
	return best
