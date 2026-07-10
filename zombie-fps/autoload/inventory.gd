extends Node
## Scavenged resources (DESIGN_DOC §4, §8.1): one bag of item-id → count.
## Ammo lives here too (since v0.5.0) — the weapon's reserve and every
## turret feed draw from this shared pool. Emits inventory_changed on every
## mutation; nothing reads the bag except through this API.

const ITEMS_DIR := "res://resources/items"

var _bag: Dictionary = {}       # StringName → int
var _registry: Dictionary = {}  # StringName → ItemResource (names/icons for UI)


func _ready() -> void:
	_load_registry()


func add(id: StringName, n: int) -> void:
	if n <= 0:
		return
	_bag[id] = count(id) + n
	EventBus.inventory_changed.emit(id, _bag[id])


## Clamped: refuses (and returns false) if the bag can't cover it.
func consume(id: StringName, n: int) -> bool:
	if n <= 0:
		return true
	if count(id) < n:
		return false
	_bag[id] = count(id) - n
	EventBus.inventory_changed.emit(id, _bag[id])
	return true


func count(id: StringName) -> int:
	return int(_bag.get(id, 0))


## inputs: Array of { "id": StringName, "qty": int } (BuildRecipe format).
func has(inputs: Array) -> bool:
	for input in inputs:
		if count(input["id"]) < int(input["qty"]):
			return false
	return true


## Fresh run: the bag survives scene reloads (autoload), so the run owner
## calls this on start — mirrors EnemyPool.release_all().
func reset() -> void:
	var ids := _bag.keys()
	_bag.clear()
	for id in ids:
		EventBus.inventory_changed.emit(id, 0)


func register_item(item: ItemResource) -> void:
	if item != null and item.id != &"" and not _registry.has(item.id):
		_registry[item.id] = item


func item(id: StringName) -> ItemResource:
	return _registry.get(id)


## Human name for an id even if no ItemResource is registered for it.
func display_name(id: StringName) -> String:
	var res: ItemResource = _registry.get(id)
	return res.display_name if res else String(id)


func _load_registry() -> void:
	var dir := DirAccess.open(ITEMS_DIR)
	if dir == null:
		push_warning("Inventory: missing items dir %s" % ITEMS_DIR)
		return
	for file in dir.get_files():
		if file.ends_with(".tres"):
			register_item(load(ITEMS_DIR.path_join(file)) as ItemResource)
