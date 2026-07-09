extends CanvasLayer
## Placeholder HUD: raw values, no styling pass. Reads EventBus only — it
## must never reach into player/weapon nodes (DESIGN_DOC §8.3).

@onready var health_label: Label = %HealthValue
@onready var ammo_label: Label = %AmmoValue
@onready var weapon_label: Label = %WeaponName
@onready var reload_label: Label = %ReloadNote
@onready var round_label: Label = %RoundNote


func _ready() -> void:
	reload_label.visible = false
	round_label.visible = false
	EventBus.player_health_changed.connect(_on_health_changed)
	EventBus.ammo_changed.connect(_on_ammo_changed)
	EventBus.weapon_equipped.connect(_on_weapon_equipped)
	EventBus.weapon_reload_started.connect(_on_reload_started)
	EventBus.weapon_reload_finished.connect(_on_reload_finished)
	EventBus.round_started.connect(_on_round_started)
	EventBus.round_cleared.connect(_on_round_cleared)
	EventBus.map_cleared.connect(_on_map_cleared)


func _on_health_changed(current: float, _max_health: float) -> void:
	health_label.text = str(roundi(current))


func _on_ammo_changed(mag: int, reserve: int) -> void:
	ammo_label.text = "%d / %d" % [mag, reserve]


func _on_weapon_equipped(data: WeaponData) -> void:
	weapon_label.text = data.display_name


func _on_reload_started(_duration: float) -> void:
	reload_label.visible = true


func _on_reload_finished() -> void:
	reload_label.visible = false


func _on_round_started(round_number: int) -> void:
	round_label.visible = true
	round_label.text = "ROUND %d" % round_number


func _on_round_cleared(round_number: int) -> void:
	round_label.text = "ROUND %d CLEARED — PREP" % round_number


func _on_map_cleared() -> void:
	round_label.text = "MAP CLEARED"
