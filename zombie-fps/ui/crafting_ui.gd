extends CanvasLayer
## Free-combine crafting screen (v0.6.0): add compounds to a mix, Combine
## validates against formulas the station's tier can complete — match crafts
## a dose, no match reads "unstable" and consumes nothing. No recipe browser
## by design; found notes reveal formulas for the run. Held doses are
## ingestible from here (Apply → PerkManager). Raw placeholder styling.

var _station: CraftingStation = null
var _mix: Dictionary = {}  # id → qty

@onready var title_label: Label = %Title
@onready var compound_list: VBoxContainer = %CompoundList
@onready var mix_list: VBoxContainer = %MixList
@onready var dose_list: VBoxContainer = %DoseList
@onready var hints_label: Label = %Hints
@onready var result_label: Label = %Result


func _ready() -> void:
	add_to_group("crafting_ui")
	visible = false
	%CombineButton.pressed.connect(_on_combine)
	%ClearButton.pressed.connect(_on_clear)
	%CloseButton.pressed.connect(close)
	EventBus.inventory_changed.connect(func(_id, _n) -> void:
		if visible:
			_rebuild())
	EventBus.perks_changed.connect(func() -> void:
		if visible:
			_rebuild())


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()


func open_station(station: CraftingStation) -> void:
	_station = station
	_mix.clear()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	result_label.text = ""
	_rebuild()


func close() -> void:
	visible = false
	_station = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_combine() -> void:
	if _station == null:
		return  # UI driven while closed — nothing to combine against
	if _mix.is_empty():
		result_label.text = "Add compounds to the mix."
		return
	var recipe := CraftingSystem.match_recipe(_mix, _station.tier)
	if recipe == null or not CraftingSystem.craft(recipe):
		# Unknown at this tier (or bench-blocked lab formula): nothing is lost.
		result_label.text = "Unstable mixture — nothing happens."
		return
	result_label.text = "Crafted: %s (dose)" % recipe.output_perk.display_name
	_mix.clear()
	_rebuild()


func _on_clear() -> void:
	_mix.clear()
	_rebuild()


func _add_to_mix(id: StringName) -> void:
	var in_mix := int(_mix.get(id, 0))
	if in_mix < Inventory.count(id):
		_mix[id] = in_mix + 1
	_rebuild()


func _remove_from_mix(id: StringName) -> void:
	var in_mix := int(_mix.get(id, 0))
	if in_mix <= 1:
		_mix.erase(id)
	else:
		_mix[id] = in_mix - 1
	_rebuild()


func _apply_dose(id: StringName) -> void:
	var perk: Perk = PerkManager.perk(id)
	if perk == null:
		return
	if PerkManager.is_full():
		result_label.text = "Perk slots full — clear one first."
		return
	if PerkManager.has_perk(id):
		result_label.text = "%s is already active." % perk.display_name
		return
	if PerkManager.apply(perk):
		Inventory.consume(id, 1)
		result_label.text = "Ingested %s." % perk.display_name
	_rebuild()


func _rebuild() -> void:
	if _station == null:
		return
	title_label.text = "CRAFTING — %s" % ("LAB" if _station.tier == Perk.Tier.LAB else "BENCH")
	_fill_compounds()
	_fill_mix()
	_fill_doses()
	_fill_hints()


func _fill_compounds() -> void:
	_clear_children(compound_list)
	for id: StringName in Inventory.all_ids():
		var item := Inventory.item(id)
		if item == null or item.category != ItemResource.Category.COMPOUND:
			continue
		if PerkManager.perk(id) != null:
			continue  # doses list separately
		var available := Inventory.count(id) - int(_mix.get(id, 0))
		if available <= 0 and not _mix.has(id):
			continue
		var btn := Button.new()
		btn.text = "%s ×%d  →" % [item.display_name, available]
		btn.disabled = available <= 0
		btn.pressed.connect(_add_to_mix.bind(id))
		compound_list.add_child(btn)


func _fill_mix() -> void:
	_clear_children(mix_list)
	for id: StringName in _mix:
		var btn := Button.new()
		btn.text = "←  %s ×%d" % [Inventory.display_name(id), _mix[id]]
		btn.pressed.connect(_remove_from_mix.bind(id))
		mix_list.add_child(btn)


func _fill_doses() -> void:
	_clear_children(dose_list)
	for id: StringName in Inventory.all_ids():
		var perk: Perk = PerkManager.perk(id)
		if perk == null or Inventory.count(id) <= 0:
			continue
		var btn := Button.new()
		btn.text = "Apply %s ×%d" % [perk.display_name, Inventory.count(id)]
		btn.pressed.connect(_apply_dose.bind(id))
		dose_list.add_child(btn)


func _fill_hints() -> void:
	var lines := PackedStringArray()
	for perk_id in CraftingSystem.revealed:
		var recipe := CraftingSystem.recipe_for_perk(perk_id)
		if recipe == null:
			continue
		var parts := PackedStringArray()
		for input in recipe.inputs:
			parts.append("%d× %s" % [input["qty"], Inventory.display_name(input["id"])])
		lines.append("%s = %s (%s)" % [recipe.display_name, " + ".join(parts),
				"Lab" if recipe.required_tier == Perk.Tier.LAB else "Bench"])
	hints_label.text = "\n".join(lines) if not lines.is_empty() else "No formulas known — combine and find out."


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
