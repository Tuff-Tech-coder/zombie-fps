extends Node3D
## Debug fixture root: removes itself entirely outside debug builds, so
## nothing shootable or visible remains in a release.

func _ready() -> void:
	if not DebugManager.is_enabled():
		queue_free()
