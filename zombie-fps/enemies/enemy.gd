class_name Enemy
extends CharacterBody3D
## Base for all enemy types — zombie variants and map bosses subclass this
## (DESIGN_DOC §8.2). Owns health, weak-point damage, the AI state machine,
## and the pooling contract (reset()/deactivate() — pooled enemies are never
## freed during play, DESIGN_DOC §8.4).
##
## Scene contract: Model (holds an AnimationPlayer somewhere inside),
## AnimationTree (state machine with states "locomotion", "attack", "death"),
## NavigationAgent3D, HeadShape (weak-point CollisionShape3D), HealthLabel.

enum State { SPAWNING, CHASING, ATTACKING, DEAD }

const LAYER_ENEMY := 4
const MASK_WORLD_PLAYER_ENEMY := 7

@export_group("Stats")
@export var max_health := 60.0
@export var weakpoint_multiplier := 2.0
@export var move_speed := 2.2
@export var turn_speed := 8.0
@export var attack_damage := 15.0
@export var attack_range := 1.7
@export var attack_duration := 1.2   ## full attack cycle before re-deciding
@export var attack_hit_time := 0.45  ## seconds into the attack when damage lands
@export var spawn_delay := 0.4
@export var death_duration := 2.6    ## death anim + corpse linger before pooling

@export_group("Animation")
## Imported GLB animations don't loop by default; these are forced to loop.
@export var loop_animations: PackedStringArray = []

var health := 0.0
var state := State.DEAD
var active := false

var _player: Player
var _state_time := 0.0
var _attack_did_hit := false
var _playback: AnimationNodeStateMachinePlayback

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var model: Node3D = $Model
@onready var head_shape: CollisionShape3D = $HeadShape
@onready var health_label: Label3D = $HealthLabel


func _ready() -> void:
	# The AnimationPlayer lives inside the imported model scene, whose internal
	# layout we don't control — resolve it at runtime instead of hardcoding.
	var anim_player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	assert(anim_player != null, "Enemy model needs an AnimationPlayer")
	for anim_name in loop_animations:
		anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	anim_tree.anim_player = anim_tree.get_path_to(anim_player)
	anim_tree.active = true
	_playback = anim_tree.get("parameters/playback")
	DebugManager.flags_changed.connect(_update_health_label)


## Pool activation: restore to a fresh combat-ready state.
func reset() -> void:
	health = max_health
	state = State.SPAWNING
	active = true
	_state_time = 0.0
	velocity = Vector3.ZERO
	collision_layer = LAYER_ENEMY
	collision_mask = MASK_WORLD_PLAYER_ENEMY
	visible = true
	process_mode = PROCESS_MODE_INHERIT
	_player = _find_player()
	_playback.start(&"locomotion")
	_update_health_label()
	EnemyNavManager.register(self)


## Pool deactivation: dormant, invisible, no physics. Called by EnemyPool.
func deactivate() -> void:
	active = false
	EnemyNavManager.unregister(self)
	collision_layer = 0
	collision_mask = 0
	visible = false
	process_mode = PROCESS_MODE_DISABLED


func take_damage(amount: float, is_weakpoint := false) -> void:
	if state == State.DEAD:
		return
	health -= amount * (weakpoint_multiplier if is_weakpoint else 1.0)
	_update_health_label()
	if health <= 0.0:
		die()


## Weapon-ray contract (see CODE_GUIDE): maps the hit shape to the weak point.
func take_hit(damage: float, _hit_pos: Vector3, _normal: Vector3, shape_index: int = 0) -> void:
	var shape_node := shape_owner_get_owner(shape_find_owner(shape_index))
	take_damage(damage, shape_node == head_shape)


func die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	velocity = Vector3.ZERO
	# Corpses don't block bullets or bodies; stop steering it too.
	collision_layer = 0
	collision_mask = 0
	EnemyNavManager.unregister(self)
	_playback.start(&"death")
	_update_health_label()
	EventBus.enemy_died.emit(self)
	await get_tree().create_timer(death_duration).timeout
	# Guard: a reset() (re-acquired from pool) may have raced this timer.
	if state == State.DEAD:
		EnemyPool.release(self)


## LOD hook (tuned in v0.8.0): lets a manager pause animation for distant
## or off-screen enemies — the single biggest per-enemy cost (DESIGN_DOC §8.4).
func set_animation_enabled(on: bool) -> void:
	anim_tree.active = on


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_state_time += delta
	if not is_on_floor():
		velocity += get_gravity() * delta
	match state:
		State.SPAWNING:
			if _state_time >= spawn_delay:
				_enter_chase()
		State.CHASING:
			_chase(delta)
		State.ATTACKING:
			_attack_update(delta)
	move_and_slide()


func _enter_chase() -> void:
	state = State.CHASING
	_state_time = 0.0
	_playback.start(&"locomotion")


func _chase(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = _find_player()
		if _player == null:
			velocity.x = 0.0
			velocity.z = 0.0
			return
	# The path target is set by EnemyNavManager on its stagger cadence —
	# never recomputed here per-frame (DESIGN_DOC §8.4).
	var next := agent.get_next_path_position()
	var to_next := next - global_position
	to_next.y = 0.0
	if to_next.length_squared() > 0.0001:
		var dir := to_next.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		_face(dir, delta)
	if global_position.distance_to(_player.global_position) <= attack_range:
		_start_attack()


func _start_attack() -> void:
	state = State.ATTACKING
	_state_time = 0.0
	_attack_did_hit = false
	velocity.x = 0.0
	velocity.z = 0.0
	_playback.start(&"attack")


func _attack_update(delta: float) -> void:
	if is_instance_valid(_player):
		var to_player := _player.global_position - global_position
		to_player.y = 0.0
		if to_player.length_squared() > 0.0001:
			_face(to_player.normalized(), delta)
		# Damage lands on the swing's contact frame, and only if the player
		# hasn't stepped out of reach.
		if not _attack_did_hit and _state_time >= attack_hit_time:
			_attack_did_hit = true
			if global_position.distance_to(_player.global_position) <= attack_range * 1.35:
				_player.take_damage(attack_damage)
	if _state_time >= attack_duration:
		if is_instance_valid(_player) \
				and global_position.distance_to(_player.global_position) <= attack_range:
			_start_attack()
		else:
			_enter_chase()


func _face(dir: Vector3, delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), turn_speed * delta)


func _find_player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func _update_health_label() -> void:
	# The one debug check this class is allowed (see CODE_GUIDE debug rules).
	health_label.visible = DebugManager.show_enemy_health and state != State.DEAD
	health_label.text = str(ceili(maxf(health, 0.0)))
