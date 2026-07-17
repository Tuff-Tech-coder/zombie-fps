class_name EnemyVisual
extends Node3D
## The enemy's visual controller (ARCH_PLAN §2): owns the Model and all
## animation machinery so the Enemy base speaks pure intent and a final-model
## swap is a resource swap, never a refactor. The AnimationTree is built at
## runtime from three exported clip names — no per-scene state-machine
## authoring, no clip names in code.
##
## Two data modes, switched by whether `animation_library` is set:
##  · Bundled (current KayKit rigs): clips live on the model's own
##    AnimationPlayer, referenced by bare name.
##  · Retargeted (final models): the GLB is imported as skeleton bones with a
##    SkeletonProfileHumanoid BoneMap, and a shared retargeted
##    AnimationLibrary is injected at bind time; clip exports then use the
##    "shared/ClipName" form. Import checklist: CODE_GUIDE → Horde
##    architecture.
##
## Scene contract: one child named "Model" (the instanced rig, containing an
## AnimationPlayer somewhere inside).

## LOD execution levels. DECISIONS live in AnimationLODManager (Phase 2);
## this node only executes the level it is told.
enum LOD { FULL, REDUCED, PAUSED, CULLED }

const SHARED_LIBRARY_NAME := &"shared"

@export var locomotion_clip: StringName = &""  ## forced to loop at bind time
@export var attack_clip: StringName = &""
@export var death_clip: StringName = &""
## Optional retargeted clip library (final-model mode). Empty = clips are
## bundled on the rig.
@export var animation_library: AnimationLibrary

var _anim_tree: AnimationTree
var _playback: AnimationNodeStateMachinePlayback
var _lod_level: int = LOD.FULL
var _update_hz := 0.0
var _accum := 0.0

@onready var model: Node3D = $Model


func _ready() -> void:
	# The AnimationPlayer lives inside the imported model scene, whose
	# internal layout we don't control — resolve at runtime, never hardcode.
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	assert(player != null, "EnemyVisual: Model contains no AnimationPlayer")
	if animation_library != null:
		player.add_animation_library(SHARED_LIBRARY_NAME, animation_library)
	for clip in [locomotion_clip, attack_clip, death_clip]:
		assert(player.has_animation(clip), "EnemyVisual: missing clip '%s'" % clip)
	# Imported GLB clips don't loop by default; locomotion must.
	player.get_animation(locomotion_clip).loop_mode = Animation.LOOP_LINEAR

	var machine := AnimationNodeStateMachine.new()
	_add_state(machine, &"locomotion", locomotion_clip)
	_add_state(machine, &"attack", attack_clip)
	_add_state(machine, &"death", death_clip)
	_anim_tree = AnimationTree.new()
	_anim_tree.name = "AnimationTree"  # stable name for inspection/debug
	add_child(_anim_tree)
	_anim_tree.anim_player = _anim_tree.get_path_to(player)
	_anim_tree.tree_root = machine
	_anim_tree.active = true
	_playback = _anim_tree.get("parameters/playback")
	_playback.start(&"locomotion")
	set_process(false)  # _process only ticks in REDUCED


# -- intent API: everything the Enemy base is allowed to ask for ------------

func play_locomotion() -> void:
	_playback.start(&"locomotion")
	_apply_if_throttled()


func play_attack() -> void:
	_playback.start(&"attack")  # start() restarts the swing each call
	_apply_if_throttled()


func play_death() -> void:
	_playback.start(&"death")
	_apply_if_throttled()


## Pool re-activation: fresh pose, full animation, visible.
func reset_visual() -> void:
	set_lod_level(LOD.FULL, 0.0)
	_playback.start(&"locomotion")


## State switches must land visibly even while LOD-throttled: a PAUSED corpse
## shows the death pose (not frozen locomotion), a throttled fresh spawn is
## posed (not Start-node rest). Mirrors the REDUCED manual-advance pattern.
func _apply_if_throttled() -> void:
	if _anim_tree != null and not _anim_tree.active:
		_anim_tree.advance(0.0)


# -- LOD execution (decisions come from AnimationLODManager, Phase 2) --------

## FULL: engine-ticked every frame. REDUCED: manual advance at update_hz.
## PAUSED: frozen pose. CULLED: frozen and hidden (the manager only assigns
## CULLED when its config allows hiding).
func set_lod_level(level: int, update_hz: float) -> void:
	if level == _lod_level and is_equal_approx(update_hz, _update_hz):
		return
	_lod_level = level
	_update_hz = update_hz
	_accum = 0.0
	_anim_tree.active = level == LOD.FULL
	if level != LOD.FULL:
		# A demotion can land before the tree's first idle evaluation (fresh
		# spawn far off-screen): without one forced evaluation the playback
		# never leaves the state machine's Start node and the skeleton holds
		# its REST pose — on retargeted rigs, a T-posing glider. A zero-delta
		# advance pins the current state's actual pose before throttling.
		_anim_tree.advance(0.0)
	set_process(level == LOD.REDUCED)
	model.visible = level != LOD.CULLED


func lod_level() -> int:
	return _lod_level


func _process(delta: float) -> void:
	# REDUCED only: accumulate real time, advance the tree in chunks so the
	# pose stays correct while skeleton updates happen at update_hz.
	_accum += delta
	if _update_hz > 0.0 and _accum >= 1.0 / _update_hz:
		_anim_tree.advance(_accum)
		_accum = 0.0


func _add_state(machine: AnimationNodeStateMachine, state: StringName, clip: StringName) -> void:
	var node := AnimationNodeAnimation.new()
	node.animation = clip
	machine.add_node(state, node)
