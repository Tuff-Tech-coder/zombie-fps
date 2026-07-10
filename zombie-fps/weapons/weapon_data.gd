class_name WeaponData
extends Resource
## Per-gun tuning. Author new guns as .tres files under resources/weapons/
## — stats never live in scripts (DESIGN_DOC §4 data-driven rule).

@export var display_name := "Unnamed"
@export var automatic := true
@export var damage := 10.0
@export var fire_rate := 8.0        ## shots per second
@export var mag_size := 30
## Caliber — matches an ItemResource id (e.g. &"9mm"). All reserve ammo of
## this type lives in the Inventory, shared with turrets (since v0.5.0).
@export var ammo_type: StringName = &""
@export var reserve_ammo := 120     ## starting rounds seeded into Inventory at run start
@export var reload_time := 2.0      ## seconds
@export var spread_degrees := 1.5   ## max deviation from aim, per axis
@export var range_meters := 60.0
@export var recoil_pitch := 0.4     ## camera kick per shot, degrees
@export var recoil_yaw := 0.15      ## random horizontal jitter, degrees
