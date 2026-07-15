class_name Enemy
extends CharacterBody3D
## Base for all enemy types — zombie variants and map bosses subclass this
## (DESIGN_DOC §8.2). Owns health, weak-point damage, the AI state machine,
## and the pooling contract (reset()/deactivate() — pooled enemies are never
## freed during play, DESIGN_DOC §8.4).
##
## Scene contract: Visual (EnemyVisual — owns the Model and ALL animation;
## this base speaks intent only and never touches animation machinery),
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

var health := 0.0
var state := State.DEAD
var active := false

var _player: Player
var _stun_time := 0.0
var _state_time := 0.0
var _attack_did_hit := false

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var visual: EnemyVisual = $Visual
@onready var head_shape: CollisionShape3D = $HeadShape
@onready var health_label: Label3D = $HealthLabel


func _ready() -> void:
	assert(visual != null, "Enemy scene needs a Visual (EnemyVisual) child")
	DebugManager.flags_changed.connect(_update_health_label)
	# RVO reply path — only ever fires when EnemyNavManager enabled avoidance
	# on this agent (DirectorConfig.avoidance_enabled, shipped off).
	agent.velocity_computed.connect(_on_velocity_computed)


## Pool activation: restore to a fresh combat-ready state.
func reset() -> void:
	health = max_health
	state = State.SPAWNING
	active = true
	_stun_time = 0.0
	_state_time = 0.0
	velocity = Vector3.ZERO
	# Clear any RVO desired velocity left over from this body's previous life,
	# or the first avoidance reply after re-acquire would move on stale data.
	agent.velocity = Vector3.ZERO
	collision_layer = LAYER_ENEMY
	collision_mask = MASK_WORLD_PLAYER_ENEMY
	visible = true
	process_mode = PROCESS_MODE_INHERIT
	_player = _find_player()
	visual.reset_visual()
	_update_health_label()
	EnemyNavManager.register(self)
	# LOD registration lives here (not die()) so the death animation stays
	# LOD-managed until deactivate() actually pools the body.
	AnimationLODManager.register(self)


## Pool deactivation: dormant, invisible, no physics. Called by EnemyPool.
func deactivate() -> void:
	active = false
	EnemyNavManager.unregister(self)
	AnimationLODManager.unregister(self)
	collision_layer = 0
	collision_mask = 0
	visible = false
	process_mode = PROCESS_MODE_DISABLED


## Brief full-body stun (electric shocks): movement and attacks freeze,
## the state machine resumes where it left off.
func stun(duration: float) -> void:
	if state != State.DEAD:
		_stun_time = maxf(_stun_time, duration)


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
	visual.play_death()
	_update_health_label()
	EventBus.enemy_died.emit(self)
	await get_tree().create_timer(death_duration).timeout
	# Guard: a reset() (re-acquired from pool) may have raced this timer.
	if state == State.DEAD:
		EnemyPool.release(self)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if _stun_time > 0.0:
		_stun_time -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity += get_gravity() * delta
		move_and_slide()
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
	if agent.avoidance_enabled and state == State.CHASING:
		# The chase move lands in _on_velocity_computed once RVO replies;
		# every other state (and avoidance off) keeps the direct path.
		return
	move_and_slide()


func _enter_chase() -> void:
	state = State.CHASING
	_state_time = 0.0
	visual.play_locomotion()


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
		if agent.avoidance_enabled:
			# Desired velocity goes through RVO; the safe result arrives in
			# _on_velocity_computed, which performs this frame's move.
			agent.set_velocity(Vector3(dir.x, 0.0, dir.z) * move_speed)
		else:
			velocity.x = dir.x * move_speed
			velocity.z = dir.z * move_speed
		_face(dir, delta)
	elif agent.avoidance_enabled:
		agent.set_velocity(Vector3.ZERO)
	if global_position.distance_to(_player.global_position) <= attack_range:
		_start_attack()


func _start_attack() -> void:
	state = State.ATTACKING
	_state_time = 0.0
	_attack_did_hit = false
	velocity.x = 0.0
	velocity.z = 0.0
	visual.play_attack()


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


## RVO-safe velocity (only emitted while avoidance is enabled). Avoidance
## replaces the horizontal chase velocity and nothing else: a same-frame
## transition out of CHASING (attack start, stun, death) already moved
## directly, so a stale reply is dropped instead of double-stepping.
func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if state != State.CHASING or _stun_time > 0.0:
		return
	velocity.x = safe_velocity.x
	velocity.z = safe_velocity.z
	move_and_slide()


func _face(dir: Vector3, delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), turn_speed * delta)


func _find_player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func _update_health_label() -> void:
	# The one debug check this class is allowed (see CODE_GUIDE debug rules).
	health_label.visible = DebugManager.show_enemy_health and state != State.DEAD
	health_label.text = str(ceili(maxf(health, 0.0)))
