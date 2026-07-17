extends Node
## Enemy object pool (DESIGN_DOC §8.4): enemies are instantiated at most once
## each and recycled via Enemy.reset()/deactivate(). Nothing in the combat hot
## path ever instantiates or frees an enemy node.
##
## One free-list per enemy scene (walker, map boss, ...); the MAX_ENEMIES
## ceiling is global across all of them, so a boss on the field takes a slot
## out of the same 50 the horde uses.

const ZOMBIE_SCENE := preload("res://enemies/zombie_walker.tscn")
const MAX_ENEMIES := 50  # hard population ceiling, DESIGN_DOC §3

var _pools := {}  # PackedScene → Array[Enemy]


## Returns an activated enemy at `pos`, or null if the ceiling is reached.
## Callers that don't say which enemy they want get the standard walker.
func acquire(pos: Vector3, scene: PackedScene = ZOMBIE_SCENE) -> Enemy:
	var pool: Array[Enemy] = _pools.get_or_add(scene, [] as Array[Enemy])
	var enemy := _find_inactive(pool)
	if enemy == null:
		if total_count() >= MAX_ENEMIES:
			return null
		enemy = scene.instantiate() as Enemy
		add_child(enemy)
		enemy.deactivate()
		pool.append(enemy)
	enemy.global_position = pos
	enemy.reset()
	return enemy


func release(enemy: Enemy) -> void:
	enemy.deactivate()


## Pooled enemies live under this autoload, so they survive a scene reload —
## the game-over restart calls this to clear the field.
func release_all() -> void:
	for pool: Array[Enemy] in _pools.values():
		for enemy in pool:
			if enemy.active:
				enemy.deactivate()


## True while any enemy on the field is still a threat. Corpses playing out
## their death animation (state == DEAD) don't count — they're active in the
## pool sense but already dead in the round sense.
func has_live_enemies() -> bool:
	for pool: Array[Enemy] in _pools.values():
		for enemy in pool:
			if enemy.active and enemy.state != Enemy.State.DEAD:
				return true
	return false


func active_count() -> int:
	var count := 0
	for pool: Array[Enemy] in _pools.values():
		for enemy in pool:
			if enemy.active:
				count += 1
	return count


func total_count() -> int:
	var count := 0
	for pool: Array[Enemy] in _pools.values():
		count += pool.size()
	return count


func _find_inactive(pool: Array[Enemy]) -> Enemy:
	for enemy in pool:
		if not enemy.active:
			return enemy
	return null
