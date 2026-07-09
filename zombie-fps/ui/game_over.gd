extends CanvasLayer
## Game-over overlay: freezes the tree on player death, restarts on accept.
## PROCESS_MODE_ALWAYS so it keeps reading input while everything is paused.

func _ready() -> void:
	visible = false
	EventBus.player_died.connect(_on_player_died)


func _on_player_died() -> void:
	visible = true
	get_tree().paused = true


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_accept"):
		return
	# Pooled enemies live under the EnemyPool autoload and would survive the
	# scene reload — clear the field before restarting.
	EnemyPool.release_all()
	get_tree().paused = false
	get_tree().reload_current_scene()
