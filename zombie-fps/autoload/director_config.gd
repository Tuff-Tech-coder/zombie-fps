class_name DirectorConfig
extends Resource
## Spawn/AI director tuning (ARCH_PLAN §4). Consumed by SpawnDirector
## (placement + pacing) and EnemyNavManager (group behavior + RVO params).
##
## EVERY VALUE HERE IS A PLACEHOLDER. These defaults are guesses, not tuned
## numbers — the real distances, curve, and rates are derived per
## PROFILING_PLAYBOOK.md against the final rigs. Re-tuning is editing the
## .tres, never touching code.

@export_group("Placement (metres, placeholder)")
## Candidates closer than this to the player are rejected outright.
@export var min_spawn_distance := 8.0
## Scoring bonus band: markers inside this range of the player are preferred.
@export var preferred_distance_range := Vector2(10.0, 25.0)
## Scoring weight for markers behind the player (view-dot weighted).
@export var behind_bias := 0.5
## XZ jitter around the chosen marker so a burst doesn't stack on one point.
## (Moved here from RoundManager — placement noise is placement data.)
@export var spawn_jitter := 0.8

@export_group("Cohort bursts")
## Enemies per cohort. A burst reuses one marker cluster so a wave arrives
## together — funnelling emerges from placement, not from nav code.
@export var burst_size_range := Vector2i(3, 6)
## Chance a burst member sticks to its cohort's marker instead of re-scoring.
@export var burst_marker_stickiness := 0.75

@export_group("Pacing / pressure")
## pressure = pressure_curve.sample(fraction of round budget spawned).
## Flat 0.5 reproduces pre-director pacing; the difficulty ramp is authored
## here, never in code.
@export var pressure_curve: Curve
## Seconds between spawns at pressure 0 / pressure 1.
@export var interval_relaxed := 1.2
@export var interval_peak := 0.4
## Concurrency ceiling at pressure 0, as a fraction of
## RoundConfig.max_concurrent (which stays the data owner of the cap).
@export var concurrent_floor_fraction := 0.5

@export_group("Group behavior (EnemyNavManager)")
## Fraction of nav slots that approach with a lateral offset.
@export var flank_fraction := 0.25
## Lateral offset distance, perpendicular to the enemy→player line (m).
@export var flank_distance := 4.0
## Within this distance of the player, enemies target per-slot ring points
## instead of the player's exact position (anti-stack fan-out).
@export var ring_radius := 6.0
## Angular gap between ring slots (degrees).
@export var ring_spacing_degrees := 24.0
## Radius of the targeted ring itself — must sit inside Enemy.attack_range so
## an enemy arriving at its slot still triggers its attack. (Schema addition
## over ARCH_PLAN §4: the ring needs a target radius distinct from its
## trigger radius, or arrivals would hold formation outside melee reach.)
@export var ring_target_radius := 1.2

@export_group("Local separation (RVO)")
## SHIPS OFF — deliberate change from ARCH_PLAN §4 (which listed true): RVO
## at 50 agents has unmeasured frame cost on this rig. Enable only when
## PROFILING_PLAYBOOK measurement #4 clears it.
@export var avoidance_enabled := false
@export var avoidance_radius := 0.5
@export var avoidance_max_neighbors := 8
