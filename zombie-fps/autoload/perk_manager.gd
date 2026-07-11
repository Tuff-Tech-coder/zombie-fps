extends Node
## Active perks (DESIGN_DOC §4.2, §8.1): the slot cap, apply/remove/swap, and
## the stat-multiplier aggregation gameplay reads at its few read points
## (player speed, weapon fire rate/spread — mirroring the DebugManager
## one-check pattern). Scripted perks get their effect node attached here
## while active. Perk definitions load from resources/perks/ at boot.

const MAX_PERKS := 4
const PERKS_DIR := "res://resources/perks"

var active: Array[Perk] = []

var _perks: Dictionary = {}     # id → Perk
var _handlers: Dictionary = {}  # id → effect Node


func _ready() -> void:
	var dir := DirAccess.open(PERKS_DIR)
	if dir == null:
		push_warning("PerkManager: missing %s" % PERKS_DIR)
		return
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var res: Resource = load(PERKS_DIR.path_join(file))
		if res is Perk:
			_perks[res.id] = res
			_register_dose_item(res)


func perk(id: StringName) -> Perk:
	return _perks.get(id)


func has_perk(id: StringName) -> bool:
	for p in active:
		if p.id == id:
			return true
	return false


func is_full() -> bool:
	return active.size() >= MAX_PERKS


## Fills a free slot. Refuses when full or already active (no double-stacking
## the same perk). The caller consumes the dose only on success.
func apply(p: Perk) -> bool:
	if p == null or is_full() or has_perk(p.id):
		return false
	active.append(p)
	if p.effect_script != null:
		var handler: Node = p.effect_script.new()
		add_child(handler)
		handler.setup(p)
		_handlers[p.id] = handler
	EventBus.perks_changed.emit()
	return true


## Frees the slot — perks are swappable, not permanent.
func remove(perk_id: StringName) -> void:
	for p in active:
		if p.id == perk_id:
			active.erase(p)
			break
	if _handlers.has(perk_id):
		_handlers[perk_id].queue_free()
		_handlers.erase(perk_id)
	EventBus.perks_changed.emit()


func clear_all() -> void:
	for p in active.duplicate():
		remove(p.id)


## Product of the active PASSIVE perks' multipliers for a stat; 1.0 when none.
func get_multiplier(stat: StringName) -> float:
	var result := 1.0
	for p in active:
		if p.trigger == Perk.Trigger.PASSIVE and p.stat == stat:
			result *= p.multiplier
	return result


## Fresh run — the run owner (player _ready) calls this, like Inventory.reset.
func reset_run() -> void:
	clear_all()


## Crafted doses live in the Inventory as items; synthesize their item
## definitions from the perk list so the HUD/UI can name them.
func _register_dose_item(p: Perk) -> void:
	var item := ItemResource.new()
	item.id = p.id
	item.display_name = "%s (dose)" % p.display_name
	item.category = ItemResource.Category.COMPOUND
	Inventory.register_item(item)
