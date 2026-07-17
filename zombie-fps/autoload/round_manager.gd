extends Node
## Round lifecycle (DESIGN_DOC §3, §8.1): sole writer of GameState.round_number
## and GameState.phase. During ROUND it feeds the field from EnemyPool — up to
## the concurrency ceiling, topping up as enemies die — until the round's
## budget has spawned and died, then emits round_cleared and runs the PREP
## timer. In v0.4.0 the loop is started/stopped by the debug WAVE button (the
## greybox stays a free-fire range by default); real maps will drive this
## directly.
##
## Placement, pacing, and the live concurrency ceiling are answered by
## SpawnDirector (ARCH_PLAN §4) — this manager keeps sole ownership of the
## lifecycle, the budget, and the round-clear gate, and exposes
## round_progress() / live_count() so the director never counts in parallel.

const BOSS_SCENE := preload("res://enemies/pumpkin_boss.tscn")

var config: RoundConfig = preload("res://resources/rounds/greybox_rounds.tres")

var running := false

var _budget := 0
var _spawned_this_round := 0
## Round-spawned enemies still on the field. Debug-button spawns are absent
## on purpose — they never count toward clearing a round.
var _tracked: Array[Enemy] = []
## The map boss, alive between the final round clearing and map_cleared.
var _boss: Enemy = null

var _spawn_timer: Timer
var _prep_timer: Timer


func _ready() -> void:
	_spawn_timer = Timer.new()
	# One-shot, re-armed at the end of every _try_spawn: the interval is
	# re-read from SpawnDirector on each arm, so the pressure curve shifts
	# pacing spawn-by-spawn instead of once per round.
	_spawn_timer.one_shot = true
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
	_try_spawn()  # first enemy lands immediately, not one interval late; re-arms itself


func _try_spawn() -> void:
	if not running or GameState.phase != GameState.Phase.ROUND:
		return
	if _spawned_this_round >= _budget:
		return
	# The director scales the ceiling within config.max_concurrent by pressure.
	if _tracked.size() < SpawnDirector.current_concurrency_ceiling():
		var enemy := EnemyPool.acquire(SpawnDirector.next_spawn_position())
		if enemy != null:  # null = pool ceiling — defer this spawn to the next arm
			_tracked.append(enemy)
			_spawned_this_round += 1
	if _spawned_this_round < _budget:
		# Re-arm (also when topped out or deferred — the retry cadence the old
		# repeating timer provided). A death top-up resets the pending arm.
		_spawn_timer.start(SpawnDirector.current_spawn_interval())


func _on_enemy_died(enemy: Enemy) -> void:
	if enemy == _boss:
		_boss = null
		_finish_map(GameState.round_number)
		return
	# Untracked (debug-button) deaths still fall through to the clear check:
	# a round must never close while ANY live enemy is on the field, so a
	# lingering debug zombie defers the clear until it too is dead.
	var was_tracked := _tracked.has(enemy)
	if was_tracked:
		_tracked.erase(enemy)
	if not running or GameState.phase != GameState.Phase.ROUND:
		return
	if was_tracked and _spawned_this_round < _budget:
		_try_spawn()  # top up without waiting for the interval
	elif _spawned_this_round >= _budget and _tracked.is_empty() \
			and not EnemyPool.has_live_enemies():
		# die() flips state to DEAD before emitting, so the final kill closes
		# the round here — corpses mid-death-animation never block it.
		_end_round()


func _end_round() -> void:
	var cleared := GameState.round_number
	_spawn_timer.stop()
	if cleared >= config.rounds_per_map:
		# The final round hands off straight to the boss — no PREP lull, no
		# round_cleared (prep music must not flash in under the boss cue).
		_begin_boss_round()
		return
	GameState.phase = GameState.Phase.PREP
	EventBus.round_cleared.emit(cleared)
	_prep_timer.start(config.prep_duration)


func _on_prep_finished() -> void:
	_begin_round(GameState.round_number + 1)


## The map boss (v0.8.3): spawns once after the final round clears; stays in
## Phase.ROUND (it IS combat — and _try_spawn is inert with the budget met).
## The encounter dressing (health bar, arena) remains v0.9.0 scope.
func _begin_boss_round() -> void:
	EventBus.boss_round_started.emit()
	_boss = EnemyPool.acquire(SpawnDirector.next_spawn_position(), BOSS_SCENE)
	if _boss == null:
		# Pool ceiling edge — never strand the run waiting on a boss that
		# could not spawn.
		_finish_map(GameState.round_number)


func _finish_map(final_round: int) -> void:
	running = false
	GameState.phase = GameState.Phase.PREP
	print("[rounds] map cleared: boss down after %d rounds" % final_round)
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
	_boss = null


## Fraction of this round's budget already spawned (0..1) — the pressure
## curve's input. SpawnDirector reads this; it never keeps its own counter.
func round_progress() -> float:
	return 0.0 if _budget == 0 else float(_spawned_this_round) / float(_budget)


## Round-tracked enemies currently on the field (debug spawns excluded).
func live_count() -> int:
	return _tracked.size()
