class_name PumpkinBoss
extends Enemy
## Map-boss placeholder (DESIGN_DOC §6/§11): a tougher, slower walker with
## exactly ONE special behavior — an anti-kite leap. All ordinary behavior is
## the Enemy base, reached via super delegation; the leap runs entirely in
## this subclass so the base state machine stays untouched. Tanky stats live
## on the scene as export overrides (data, not code).
##
## Leap intent: a player kiting past leap_trigger_distance gets pounced at —
## the boss closes most of the gap but lands leap_landing_gap short, so
## standing still eats the ordinary follow-up melee while moving slips it.
## The leap itself deals no damage unless leap_damage is raised from 0.

enum LeapPhase { NONE, WINDUP, AIR }

@export_group("Leap")
@export var leap_trigger_distance := 12.0  ## player farther than this (m) → eligible
@export var leap_cooldown := 5.0           ## s between leaps
@export var leap_windup := 0.4             ## s telegraph before launch
@export var leap_air_time := 0.7           ## s airborne
@export var leap_landing_gap := 3.0        ## lands THIS far short of the player (m)
@export var leap_max_distance := 14.0      ## cap on horizontal travel (m)
@export var leap_height := 3.0             ## arc apex (m), visual only
@export var leap_damage := 0.0             ## optional landing thump; 0 = none

var _leaping := false
var _leap_phase := LeapPhase.NONE
var _leap_time := 0.0
var _leap_cd := 0.0
var _leap_from := Vector3.ZERO
var _leap_to := Vector3.ZERO

var _skeleton: Skeleton3D
var _head_bone := -1


func _ready() -> void:
	super._ready()
	# Resolved at runtime like EnemyVisual resolves its AnimationPlayer —
	# never hardcode the imported rig's internal layout.
	_skeleton = visual.model.find_child("GeneralSkeleton", true, false)
	if _skeleton != null:
		_head_bone = _skeleton.find_bone("Head")


## Pooling hygiene: a re-acquired boss must never resume a stale leap.
func reset() -> void:
	super.reset()
	_leaping = false
	_leap_phase = LeapPhase.NONE
	_leap_time = 0.0
	_leap_cd = 0.0


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		# Death mid-leap included: the base's DEAD early-out owns the frame.
		super._physics_process(delta)
		return
	_track_head_shape()
	_leap_cd = maxf(0.0, _leap_cd - delta)
	if _leaping:
		_leap_update(delta)
		return
	if _can_leap():
		_start_leap()
		return
	super._physics_process(delta)


func _can_leap() -> bool:
	if state != State.CHASING or _stun_time > 0.0 or _leap_cd > 0.0 \
			or not is_on_floor() or not is_instance_valid(_player):
		return false
	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	return to_player.length() > leap_trigger_distance


func _start_leap() -> void:
	_leaping = true
	_leap_phase = LeapPhase.WINDUP
	_leap_time = 0.0
	velocity = Vector3.ZERO
	# The tell reuses the attack swing — a dedicated leap clip would need a
	# 4th EnemyVisual state (seam change, out of scope for a placeholder).
	visual.play_attack()
	_play_sound(attack_sound)  # audible telegraph to match the visual tell


func _leap_update(delta: float) -> void:
	_leap_time += delta
	match _leap_phase:
		LeapPhase.WINDUP:
			velocity = Vector3.ZERO
			_face_player(delta)
			if _leap_time >= leap_windup:
				_launch()
		LeapPhase.AIR:
			var t := minf(_leap_time / leap_air_time, 1.0)
			var desired := _leap_from.lerp(_leap_to, t)
			desired.y = _leap_from.y + leap_height * 4.0 * t * (1.0 - t)
			# Velocity-driven so walls stop the pounce; we own Y for the arc,
			# so base gravity is deliberately not applied while airborne.
			velocity = (desired - global_position) / delta
			move_and_slide()
			_face_player(delta)
			if t >= 1.0 or (t > 0.5 and is_on_floor()):
				_land()


## WINDUP → AIR: aim is re-read at launch, so the tell is dodgeable sideways
## but backpedaling doesn't stretch the landing gap.
func _launch() -> void:
	if not is_instance_valid(_player):
		_end_leap()
		return
	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	if dist < 0.001:
		_end_leap()
		return
	var dir := to_player / dist
	var target_dist := clampf(dist - leap_landing_gap, 0.0, leap_max_distance)
	_leap_from = global_position
	_leap_to = _leap_from + dir * target_dist
	_leap_phase = LeapPhase.AIR
	_leap_time = 0.0


func _land() -> void:
	if leap_damage > 0.0 and is_instance_valid(_player) \
			and global_position.distance_to(_player.global_position) <= attack_range * 1.35:
		_player.take_damage(leap_damage)
	_end_leap()


## Back to the base state machine: state stayed CHASING the whole time, so
## next frame's super._physics_process resumes chase/attack normally — a
## player still inside attack_range gets the ordinary swing.
func _end_leap() -> void:
	_leaping = false
	_leap_phase = LeapPhase.NONE
	_leap_cd = leap_cooldown
	velocity = Vector3.ZERO
	visual.play_locomotion()


## The pumpkin swings through a ~2 m envelope (heavy torso lumber + broad
## swipe) — a static weak-point sphere either misses it or eclipses the body,
## so the collider follows the head bone. Frozen visuals (animation-LOD
## PAUSED) freeze the collider with them, which stays consistent.
func _track_head_shape() -> void:
	if _head_bone < 0:
		return
	var head_xform: Transform3D = _skeleton.global_transform * _skeleton.get_bone_global_pose(_head_bone)
	# Offset in the BONE's frame: the pumpkin's centre sits above the neck
	# joint along the bone axis, so it follows the hunch/swing correctly.
	head_shape.global_position = head_xform * Vector3(0, 0.18, 0.0)


func _face_player(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	if to_player.length_squared() > 0.0001:
		_face(to_player.normalized(), delta)
