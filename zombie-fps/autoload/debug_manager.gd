extends Node
## All debug state and debug-only behavior lives here (v0.3.0 brief §9).
## Everything is gated on is_enabled(): flip DEBUG_ENABLED to false (or make
## a release export) and the panel removes itself, every flag reads false,
## and every function no-ops. Gameplay systems are allowed exactly one
## guarded check against this singleton (see CODE_GUIDE debug rules).

signal flags_changed

const DEBUG_ENABLED := true

var infinite_ammo := false
var infinite_health := false
var show_enemy_health := false

var _wave_active := false  # lit state for the wave button
var _spawn_cursor := 0


func _ready() -> void:
	# RoundManager stops on death; resync the wave toggle so the button's
	# first post-restart press is a START again.
	EventBus.player_died.connect(func() -> void: _wave_active = false)


func is_enabled() -> bool:
	return DEBUG_ENABLED and OS.is_debug_build()


## Flips a flag and returns the new value (buttons use it for their lamp).
func toggle_flag(flag: StringName) -> bool:
	if not is_enabled():
		return false
	match flag:
		&"infinite_ammo":
			infinite_ammo = not infinite_ammo
			flags_changed.emit()
			return infinite_ammo
		&"infinite_health":
			infinite_health = not infinite_health
			flags_changed.emit()
			return infinite_health
		&"show_enemy_health":
			show_enemy_health = not show_enemy_health
			flags_changed.emit()
			return show_enemy_health
	push_warning("Unknown debug flag: %s" % flag)
	return false


func spawn_zombies(count: int) -> void:
	if not is_enabled():
		return
	var points := get_tree().get_nodes_in_group("debug_spawn_point")
	if points.is_empty():
		push_warning("No debug_spawn_point markers in scene")
		return
	# Single spawns use the first marker (near the player, for melee testing);
	# hordes cycle through the rest (the big room, for stress testing).
	var horde_points := points.slice(1) if points.size() > 1 else points
	var spawned := 0
	for i in count:
		var point: Node3D = points[0] if count == 1 else horde_points[_spawn_cursor % horde_points.size()]
		_spawn_cursor += 1
		var jitter := Vector3.ZERO
		if count > 1:
			jitter = Vector3(randf_range(-1.2, 1.2), 0.0, randf_range(-1.2, 1.2))
		if EnemyPool.acquire(point.global_position + jitter) == null:
			push_warning("[debug] enemy cap reached (%d)" % EnemyPool.MAX_ENEMIES)
			break
		spawned += 1
	print("[debug] spawned %d zombie(s) — pool active=%d total=%d"
			% [spawned, EnemyPool.active_count(), EnemyPool.total_count()])


## Shortcut past scavenging so crafting is testable in isolation.
func grant_supplies() -> void:
	if not is_enabled():
		return
	Inventory.add(&"scrap", 8)
	Inventory.add(&"servo", 2)
	Inventory.add(&"9mm", 120)
	print("[debug] granted supplies — scrap 8, servo 2, 9mm 120")


## Returns the new open state (button lamp).
func toggle_door() -> bool:
	if not is_enabled():
		return false
	var opened := false
	for door in get_tree().get_nodes_in_group("debug_door"):
		opened = door.toggle()
	return opened


## Alternates start/end requests; RoundManager consumes them (since v0.4.0).
func toggle_wave_stub() -> bool:
	if not is_enabled():
		return false
	_wave_active = not _wave_active
	if _wave_active:
		request_wave_start()
	else:
		request_wave_end()
	return _wave_active


func request_wave_start() -> void:
	if not is_enabled():
		return
	print("[debug] wave START requested")
	EventBus.debug_wave_start_requested.emit()


func request_wave_end() -> void:
	if not is_enabled():
		return
	print("[debug] wave END requested")
	EventBus.debug_wave_end_requested.emit()
