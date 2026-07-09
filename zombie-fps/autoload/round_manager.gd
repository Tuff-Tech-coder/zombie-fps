extends Node
## Round lifecycle (DESIGN_DOC §3, §8.1): sole writer of GameState.round_number
## and GameState.phase. During ROUND it feeds the field from EnemyPool — up to
## the concurrency cap, topping up as enemies die — until the round's budget
## has spawned and died, then emits round_cleared and runs the PREP timer.
## In v0.4.0 the loop is started/stopped by the debug WAVE button (the greybox
## stays a free-fire range by default); real maps will drive this directly.

var config: RoundConfig = preload("res://resources/rounds/greybox_rounds.tres")

var running := false

var _budget := 0
var _spawned_this_round := 0
## Round-spawned enemies still on the field. Debug-button spawns are absent
## on purpose — they never count toward clearing a round.
var _tracked: Array[Enemy] = []

var _spawn_timer: Timer
var _prep_timer: Timer


func _ready() -> void:
	_spawn_timer = Timer.new()
	_spawn_timer.timeout.connect(_try_spawn)
	add_child(_spawn_timer)
	_prep_timer = Timer.new()
	_prep_timer.one_shot = true
	_prep_timer.timeout.connect(_on_prep_finished)
	add_child(_prep_timer)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.player_died.connect(_on_player_died)
	EventBus.debug_wave_start_requested.connect(_on_wave_start_requested)
	EventBus.debug_wave_end_requested.connect(_on_wave_end_requested)


## Fresh run: counters zeroed, begins at round 1.
func start_run() -> void:
	stop()
	_tracked.clear()
	running = true
	_begin_round(1)


## Halts spawning and timers. Field/state cleanup is the caller's choice.
func stop() -> void:
	running = false
	_spawn_timer.stop()
	_prep_timer.stop()


func _begin_round(round_number: int) -> void:
	if not running:
		return
	GameState.round_number = round_number
	GameState.phase = GameState.Phase.ROUND
	_budget = config.budget_for(round_number)
	_spawned_this_round = 0
	EventBus.round_started.emit(round_number)
	_try_spawn()  # first enemy lands immediately, not one interval late
	_spawn_timer.start(config.spawn_interval)


func _try_spawn() -> void:
	if not running or GameState.phase != GameState.Phase.ROUND:
		return
	if _spawned_this_round >= _budget:
		_spawn_timer.stop()
		return
	if _tracked.size() >= config.max_concurrent:
		return  # topped out — a death will top up
	var point := _pick_spawn_point()
	if point == null:
		push_warning("RoundManager: no enemy_spawn_point markers in scene")
		return
	var jitter := Vector3(randf_range(-0.8, 0.8), 0.0, randf_range(-0.8, 0.8))
	var enemy := EnemyPool.acquire(point.global_position + jitter)
	if enemy == null:
		return  # pool ceiling — defer this spawn to the next tick
	_tracked.append(enemy)
	_spawned_this_round += 1
	if _spawned_this_round >= _budget:
		_spawn_timer.stop()


func _on_enemy_died(enemy: Enemy) -> void:
	if not _tracked.has(enemy):
		return  # debug-button spawn — not part of the round
	_tracked.erase(enemy)
	if not running or GameState.phase != GameState.Phase.ROUND:
		return
	if _spawned_this_round < _budget:
		_try_spawn()  # top up without waiting for the interval
	elif _tracked.is_empty():
		_end_round()


func _end_round() -> void:
	var cleared := GameState.round_number
	_spawn_timer.stop()
	GameState.phase = GameState.Phase.PREP
	EventBus.round_cleared.emit(cleared)
	if cleared >= config.rounds_per_map:
		_finish_map(cleared)
		return
	_prep_timer.start(config.prep_duration)


func _on_prep_finished() -> void:
	_begin_round(GameState.round_number + 1)


func _finish_map(final_round: int) -> void:
	running = false
	# Boss hand-off seam — the map boss consumes this in v0.9.0.
	print("[rounds] map cleared after %d rounds — boss fight lands in v0.9.0" % final_round)
	EventBus.map_cleared.emit()


func _on_player_died() -> void:
	stop()
	# Drop refs now — game_over releases the actual nodes before the reload.
	_tracked.clear()
	_reset_run_state()


func _on_wave_start_requested() -> void:
	if running:
		return
	start_run()


func _on_wave_end_requested() -> void:
	stop()
	EnemyPool.release_all()
	_tracked.clear()
	_reset_run_state()


func _reset_run_state() -> void:
	GameState.round_number = 0
	GameState.phase = GameState.Phase.PREP
	_budget = 0
	_spawned_this_round = 0


func _pick_spawn_point() -> Node3D:
	var points := get_tree().get_nodes_in_group("enemy_spawn_point")
	if points.is_empty():
		return null
	return points[randi() % points.size()]
