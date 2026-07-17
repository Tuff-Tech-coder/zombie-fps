extends CanvasLayer
## Placeholder HUD: raw values, no styling pass. Reads EventBus only — it
## must never reach into player/weapon nodes (DESIGN_DOC §8.3).

@onready var health_label: Label = %HealthValue
@onready var ammo_label: Label = %AmmoValue
@onready var weapon_label: Label = %WeaponName
@onready var reload_label: Label = %ReloadNote
@onready var round_label: Label = %RoundNote
@onready var skip_label: Label = %SkipNote
@onready var prompt_label: Label = %InteractPrompt
@onready var supplies_label: Label = %Supplies

var _ammo_type: StringName = &""
var _last_mag := 0
var _supplies: Dictionary = {}  # StringName → int
var _perk_slots: HBoxContainer = null


func _ready() -> void:
	reload_label.visible = false
	round_label.visible = false
	prompt_label.visible = false
	# Shown only during the between-rounds PREP countdown (round_cleared →
	# round_started). The key name is read live so a rebind stays truthful.
	skip_label.visible = false
	for ev in InputMap.action_get_events(&"skip_prep"):
		if ev is InputEventKey:
			skip_label.text = "Press %s to skip prep" % (ev as InputEventKey).as_text_keycode()
			break
	EventBus.player_health_changed.connect(_on_health_changed)
	EventBus.ammo_changed.connect(_on_ammo_changed)
	EventBus.weapon_equipped.connect(_on_weapon_equipped)
	EventBus.weapon_reload_started.connect(_on_reload_started)
	EventBus.weapon_reload_finished.connect(_on_reload_finished)
	EventBus.round_started.connect(_on_round_started)
	EventBus.round_cleared.connect(_on_round_cleared)
	EventBus.map_cleared.connect(_on_map_cleared)
	EventBus.inventory_changed.connect(_on_inventory_changed)
	EventBus.interact_prompt_changed.connect(_on_interact_prompt_changed)
	EventBus.perks_changed.connect(_on_perks_changed)
	_build_perk_slots()
	_on_perks_changed()


func _on_health_changed(current: float, _max_health: float) -> void:
	health_label.text = str(roundi(current))


func _on_ammo_changed(mag: int, reserve: int) -> void:
	_last_mag = mag
	ammo_label.text = "%d / %d" % [mag, reserve]


func _on_weapon_equipped(data: WeaponData) -> void:
	weapon_label.text = data.display_name
	_ammo_type = data.ammo_type


func _on_inventory_changed(id: StringName, count: int) -> void:
	# Ammo pickups / turret loads move the reserve without a weapon event.
	if id == _ammo_type:
		ammo_label.text = "%d / %d" % [_last_mag, count]
	if count <= 0:
		_supplies.erase(id)
	else:
		_supplies[id] = count
	var lines := PackedStringArray()
	for item_id: StringName in _supplies:
		lines.append("%s ×%d" % [Inventory.display_name(item_id), _supplies[item_id]])
	supplies_label.text = "\n".join(lines)


func _on_interact_prompt_changed(text: String) -> void:
	prompt_label.text = text
	prompt_label.visible = not text.is_empty()


## The reserved bottom-left region becomes real perk slots: one chip per
## active perk; every chip gains the colored border at the cap (§4.2).
func _build_perk_slots() -> void:
	var slots := HBoxContainer.new()
	slots.name = "PerkSlots"
	slots.add_theme_constant_override("separation", 6)
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	%PerkArea.add_child(slots)
	for i in PerkManager.MAX_PERKS:
		var chip := PanelContainer.new()
		chip.custom_minimum_size = Vector2(52, 44)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 15)
		chip.add_child(label)
		slots.add_child(chip)
	_perk_slots = slots


func _on_perks_changed() -> void:
	if _perk_slots == null:
		return
	var at_cap := PerkManager.is_full()
	for i in _perk_slots.get_child_count():
		var chip: PanelContainer = _perk_slots.get_child(i)
		var label: Label = chip.get_child(0)
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(4)
		if i < PerkManager.active.size():
			var perk: Perk = PerkManager.active[i]
			style.bg_color = perk.color.darkened(0.45)
			# §4.2: at the cap every filled symbol gains the colored border.
			style.set_border_width_all(2 if at_cap else 0)
			style.border_color = Color(1.0, 0.8, 0.2)
			label.text = _monogram(perk.display_name)
			label.add_theme_color_override("font_color", Color.WHITE)
		else:
			style.bg_color = Color(0, 0, 0, 0.35)
			style.set_border_width_all(0)
			label.text = ""
		chip.add_theme_stylebox_override("panel", style)


func _monogram(name: String) -> String:
	var letters := PackedStringArray()
	for word in name.split(" ", false):
		letters.append(word.substr(0, 1).to_upper())
	return "".join(letters).substr(0, 2)


func _on_reload_started(_duration: float, _mag: int, _mag_size: int) -> void:
	reload_label.visible = true


func _on_reload_finished() -> void:
	reload_label.visible = false


func _on_round_started(round_number: int) -> void:
	round_label.visible = true
	round_label.text = "ROUND %d" % round_number
	skip_label.visible = false


func _on_round_cleared(round_number: int) -> void:
	round_label.text = "ROUND %d CLEARED — PREP" % round_number
	skip_label.visible = true


func _on_map_cleared() -> void:
	round_label.text = "MAP CLEARED"
	skip_label.visible = false
