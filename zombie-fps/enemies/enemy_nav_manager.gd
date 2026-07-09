extends Node
## Staggered navigation (DESIGN_DOC §8.4): repaths a small, fixed number of
## enemies per physics tick, round-robin, instead of every enemy every frame.
## Enemies read their agent's current path in _physics_process but never set
## their own target — this manager is the only writer.

## At the 50-enemy ceiling this still sweeps everyone every ~0.4 s, which is
## plenty for shamblers chasing one player.
const UPDATES_PER_TICK := 2

var _enemies: Array[Enemy] = []
var _cursor := 0
var _player: Node3D


func register(enemy: Enemy) -> void:
	if not _enemies.has(enemy):
		_enemies.append(enemy)


func unregister(enemy: Enemy) -> void:
	_enemies.erase(enemy)


func _physics_process(_delta: float) -> void:
	if _enemies.is_empty():
		return
	if not is_instance_valid(_player) or not _player.is_inside_tree():
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return
	for i in mini(UPDATES_PER_TICK, _enemies.size()):
		_cursor = _cursor % _enemies.size()
		_enemies[_cursor].agent.target_position = _player.global_position
		_cursor += 1
