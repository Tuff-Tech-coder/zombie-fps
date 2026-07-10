class_name ElectricTrap
extends Buildable
## CoD-style corridor trap (v0.5.1): activate on E, electrify the zone for a
## while, then recharge. Damage is environmental (take_damage, no weak point):
## one big burst per enemy entering the live zone plus a DoT while they stay.
## Weak zombies die to the burst outright; tankier ones survive and bleed —
## that split falls straight out of health, so per-wave scaling needs no rework.

enum State { IDLE, ACTIVE, COOLDOWN }

@export var burst_damage := 100.0
@export var dot_per_second := 40.0
@export var active_duration := 8.0
@export var cooldown_duration := 10.0
@export var tick_interval := 0.4

var state := State.IDLE

var _state_time := 0.0
var _tick_accum := 0.0
var _zapped: Array[Enemy] = []  # already got this activation's burst

@onready var zone: Area3D = $Zone
@onready var arcs: CPUParticles3D = $ArcParticles
@onready var hum: AudioStreamPlayer3D = $HumAudio
@onready var status_label: Label3D = $StatusLabel
@onready var lamp: MeshInstance3D = $Lamp

var _lamp_mat: StandardMaterial3D


func _ready() -> void:
	super()
	hum.stream = PlaceholderSfx.electric_buzz()
	zone.body_entered.connect(_on_body_entered)
	_lamp_mat = lamp.get_active_material(0).duplicate() as StandardMaterial3D
	lamp.set_surface_override_material(0, _lamp_mat)
	_apply_state_fx()


func get_interact_prompt() -> String:
	match state:
		State.IDLE:
			return "E: Activate trap"
		State.ACTIVE:
			return "Trap live!"
		_:
			return "Trap recharging (%ds)" % ceili(cooldown_duration - _state_time)


func interact(_player) -> void:
	if state != State.IDLE:
		return  # the prompt already says it's live/recharging
	_enter_state(State.ACTIVE)


func _physics_process(delta: float) -> void:
	_state_time += delta
	match state:
		State.ACTIVE:
			_tick_accum += delta
			if _tick_accum >= tick_interval:
				_tick_accum -= tick_interval
				_dot_tick()
			if _state_time >= active_duration:
				_enter_state(State.COOLDOWN)
		State.COOLDOWN:
			if _state_time >= cooldown_duration:
				_enter_state(State.IDLE)


func _enter_state(next: State) -> void:
	state = next
	_state_time = 0.0
	_tick_accum = 0.0
	if next == State.ACTIVE:
		_zapped.clear()
		# Anyone already standing in the zone eats the burst immediately.
		for body in zone.get_overlapping_bodies():
			_zap(body)
	_apply_state_fx()


func _on_body_entered(body: Node3D) -> void:
	if state == State.ACTIVE:
		_zap(body)


func _zap(body: Node3D) -> void:
	if body is Enemy and body.state != Enemy.State.DEAD and not _zapped.has(body):
		_zapped.append(body)
		body.take_damage(burst_damage)  # environmental — no weak point


func _dot_tick() -> void:
	for body in zone.get_overlapping_bodies():
		if body is Enemy and body.state != Enemy.State.DEAD:
			body.take_damage(dot_per_second * tick_interval)


func _apply_state_fx() -> void:
	arcs.emitting = state == State.ACTIVE
	if state == State.ACTIVE:
		hum.play()
	else:
		hum.stop()
	match state:
		State.IDLE:
			status_label.text = "READY"
			_lamp_mat.emission = Color(0.3, 1.0, 0.4)
		State.ACTIVE:
			status_label.text = "LIVE"
			_lamp_mat.emission = Color(0.5, 0.85, 1.0)
		State.COOLDOWN:
			status_label.text = "RECHARGING"
			_lamp_mat.emission = Color(1.0, 0.3, 0.2)
