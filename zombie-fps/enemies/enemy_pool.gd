extends Node
## Enemy object pool (DESIGN_DOC §8.4): enemies are instantiated at most once
## each and recycled via Enemy.reset()/deactivate(). Nothing in the combat hot
## path ever instantiates or frees an enemy node.

const ZOMBIE_SCENE := preload("res://enemies/zombie_walker.tscn")
const MAX_ENEMIES := 50  # hard population ceiling, DESIGN_DOC §3

var _pool: Array[Enemy] = []


## Returns an activated enemy at `pos`, or null if the ceiling is reached.
func acquire(pos: Vector3) -> Enemy:
	var enemy := _find_inactive()
	if enemy == null:
		if _pool.size() >= MAX_ENEMIES:
			return null
		enemy = ZOMBIE_SCENE.instantiate() as Enemy
		add_child(enemy)
		enemy.deactivate()
		_pool.append(enemy)
	enemy.global_position = pos
	enemy.reset()
	return enemy


func release(enemy: Enemy) -> void:
	enemy.deactivate()


## Pooled enemies live under this autoload, so they survive a scene reload —
## the game-over restart calls this to clear the field.
func release_all() -> void:
	for enemy in _pool:
		if enemy.active:
			enemy.deactivate()


## True while any enemy on the field is still a threat. Corpses playing out
## their death animation (state == DEAD) don't count — they're active in the
## pool sense but already dead in the round sense.
func has_live_enemies() -> bool:
	for enemy in _pool:
		if enemy.active and enemy.state != Enemy.State.DEAD:
			return true
	return false


func active_count() -> int:
	var count := 0
	for enemy in _pool:
		if enemy.active:
			count += 1
	return count


func total_count() -> int:
	return _pool.size()


func _find_inactive() -> Enemy:
	for enemy in _pool:
		if not enemy.active:
			return enemy
	return null
