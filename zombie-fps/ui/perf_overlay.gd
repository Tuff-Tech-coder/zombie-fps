extends CanvasLayer
## Debug perf overlay (ARCH_PLAN §5): read-only taps on the Performance
## monitors, EnemyPool, and AnimationLODManager.level_counts() — it owns no
## state and no gameplay script references it. Toggled by the PERF debug
## button through DebugManager like every debug fixture, and removes itself
## entirely outside debug builds (the debug_panel strip pattern).

## Readout repaint cadence — a UI refresh rate, not a gameplay number.
@export var refresh_hz := 4.0

var _accum := 0.0

@onready var readout: Label = %Readout


func _ready() -> void:
	if not DebugManager.is_enabled():
		queue_free()
		return
	DebugManager.flags_changed.connect(_sync_visibility)
	_sync_visibility()


func _sync_visibility() -> void:
	visible = DebugManager.show_perf_overlay
	set_process(visible)
	if visible:
		_refresh()


func _process(delta: float) -> void:
	_accum += delta
	if _accum < 1.0 / refresh_hz:
		return
	_accum = 0.0
	_refresh()


func _refresh() -> void:
	var counts: Dictionary = AnimationLODManager.level_counts()
	readout.text = "FPS %d\nframe %.2f ms\nphysics %.2f ms\ndraw calls %d\nenemies %d\nLOD full %d / red %d / paused %d / culled %d" % [
		Performance.get_monitor(Performance.TIME_FPS),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		EnemyPool.active_count(),
		counts[EnemyVisual.LOD.FULL],
		counts[EnemyVisual.LOD.REDUCED],
		counts[EnemyVisual.LOD.PAUSED],
		counts[EnemyVisual.LOD.CULLED],
	]
