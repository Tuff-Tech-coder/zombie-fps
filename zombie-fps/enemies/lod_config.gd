class_name LODConfig
extends Resource
## Animation-LOD tuning (ARCH_PLAN §3). Consumed by AnimationLODManager.
##
## EVERY VALUE HERE IS A PLACEHOLDER. These defaults are guesses, not tuned
## numbers — the real distance bands, update rates, and hysteresis are derived
## by Opus post-model-swap per docs/PROFILING_PLAYBOOK.md, against the final rigs.
## Re-tuning is editing this .tres, never touching code.

## How many enemies the manager re-evaluates per physics tick (round-robin,
## staggered like EnemyNavManager). Higher = snappier LOD, more cost per tick.
@export var evaluations_per_tick := 4

@export_group("Distance bands (metres, placeholder)")
## <= this and on-screen → FULL (engine-ticked every frame).
@export var full_distance := 12.0
## <= this → REDUCED (manual advance at reduced_update_hz).
@export var reduced_distance := 25.0
## <= this → PAUSED (frozen pose). Beyond → cull zone (PAUSED, or CULLED if
## cull_visuals; and the background-tier hook fires if enabled).
@export var paused_distance := 45.0
## Sticky dead-zone around each band edge so enemies straddling a boundary
## don't flip-flop between levels. Applied ± against the current level.
@export var hysteresis := 2.0
## Levels an off-screen (out-of-frustum) enemy is demoted by. 1 = an
## on-screen-near FULL enemy becomes REDUCED the moment it leaves view.
@export var offscreen_demotion := 1

@export_group("Update rates (Hz, placeholder)")
## Skeleton advance rate while REDUCED. 0 would freeze; keep > 0.
@export var reduced_update_hz := 10.0
## Advance rate while PAUSED. 0 = fully frozen pose.
@export var paused_update_hz := 0.0

@export_group("Culling & background tier")
## When true, cull-zone enemies hide their Model (CULLED) instead of just
## freezing the pose (PAUSED). Whether this is worth it is Opus's call.
@export var cull_visuals := false
## Framework hook ONLY (DESIGN_DOC §8.4). When true, an enemy past
## paused_distance is handed to AnimationLODManager._hand_off_to_background()
## — an empty, documented seam. Whether a MultiMesh background tier is ever
## needed is decided post-profiling; nothing implements it yet.
@export var background_tier_enabled := false
