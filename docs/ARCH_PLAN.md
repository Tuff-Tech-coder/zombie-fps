# ARCH_PLAN — Horde Performance Architecture & AI/Spawn Director

> Phase 0 deliverable. Defines the seams before any code. Everything here
> follows the durability rule: mechanisms and data-driven knobs now; tuned
> numbers are Opus's job after the final models land. Every threshold named
> below lives in a `.tres` or an export — none in method bodies.

---

## 1. The four seams at a glance

| Seam | New file(s) | Owns | Talks to |
|---|---|---|---|
| Enemy visual controller | `enemies/enemy_visual.gd` | Model + AnimationTree + clip names + LOD execution | Enemy base (intent calls in), AnimationLODManager (LOD calls in) |
| Animation-LOD framework | `enemies/animation_lod_manager.gd` (autoload) + `enemies/lod_config.gd` schema + `resources/config/lod_config.tres` | LOD *decisions* (distance/visibility → level) | EnemyVisual (drives), EnemyPool registry (reads), perf overlay (exposes counts) |
| Spawn/AI director | `autoload/spawn_director.gd` (autoload) + `autoload/director_config.gd` schema + `resources/config/greybox_director.tres` | Placement, pacing/pressure, cohort bursts | RoundManager (queried by), EnemyNavManager (configures), player camera (reads) |
| Group behavior on nav | extends `enemies/enemy_nav_manager.gd` (no fork) | Flank offsets, surround-ring targets, separation config | NavigationAgent3D targets (still the ONLY writer) |

Supporting: `ui/perf_overlay.gd/.tscn` (debug-gated), `MODEL_BUDGET.md`,
`PROFILING_PLAYBOOK.md`, CODE_GUIDE horde section.

---

## 2. Phase 1 — Enemy ↔ visual decoupling

### The seam: `EnemyVisual` (Node3D, `enemies/enemy_visual.gd`)

New scene contract: the enemy scene's root keeps physics-side children
(`BodyShape`, `HeadShape`, `NavigationAgent3D`, `HealthLabel` — all
mesh-independent, unchanged), and gains one `Visual` child (EnemyVisual)
that owns the `Model` (instanced GLB) and the animation machinery.

**Key decision — the AnimationTree moves INTO code.** Today every enemy
scene hand-authors an AnimationNodeStateMachine and names clips in
sub-resources; that is per-scene boilerplate the brief calls out. Instead
`EnemyVisual` builds the three-state machine (`locomotion` / `attack` /
`death`) at runtime from three exported StringNames:

```gdscript
@export var locomotion_clip: StringName   # forced to loop at bind time
@export var attack_clip: StringName
@export var death_clip: StringName
@export var animation_library: AnimationLibrary  # optional — retarget mode
```

- **Bundled-clip mode (current KayKit rig):** `animation_library` empty; the
  AnimationPlayer is resolved inside the Model at runtime (existing
  behavior) and clips are looked up by name on it.
- **Retargeted mode (final models):** the GLB is imported with
  `import_as_skeleton_bones = true` + a BoneMap against
  `SkeletonProfileHumanoid`; a shared `AnimationLibrary` (retargeted clips)
  is assigned and injected into the resolved AnimationPlayer at bind time.
  One clip library then drives every humanoid rig. Import checklist goes in
  CODE_GUIDE (Phase 4); the mode switch is data (`animation_library` set or
  not), never code.

**Intent API (all the Enemy base is allowed to call):**

```gdscript
func play_locomotion() -> void
func play_attack() -> void        # restarts the swing
func play_death() -> void
func reset_visual() -> void       # pool re-activation: pose + LOD to full
func set_lod_level(level: int, update_hz: float) -> void
```

LOD execution lives here too (decisions come from the manager, §3):
- `FULL` — `anim_tree.active = true` (engine-ticked, every frame).
- `REDUCED` — `anim_tree.active = false`; EnemyVisual accumulates delta in
  `_process` and calls `anim_tree.advance(accum)` at `update_hz`. Standard
  Godot manual-advance throttling; pose updates cheaper, gameplay untouched.
- `PAUSED` — no advance; frozen pose (off-screen/far).
- `CULLED` — optional `model.visible = false` (config-gated; hook for the
  background tier, §3).

**Enemy base diff:** every `_playback.start(...)` / `anim_tree` touch is
replaced by one intent call; `_ready`'s AnimationPlayer plumbing moves into
EnemyVisual; `set_animation_enabled()` (the bare v0.3.0 hook) is deleted —
`set_lod_level` supersedes it (nothing else calls it). Acceptance: `grep
anim_tree\|_playback enemy.gd` returns nothing.

**Swap proof:** KayKit ships sibling rigs sharing the same animation set
(`Skeleton_Warrior.glb` etc. in the already-used CC0 repo). A variant scene
pointing `Model` at a different GLB with the same three clip names — zero
`enemy.gd` edits — demonstrates the resource-only swap criterion concretely.

Perk/trap interop note: `move_speed`, `weakpoint_multiplier`, damage flow
stay public vars on Enemy read at point-of-use (already true) — the v0.6.1
enemy-slow perk needs no new seam.

---

## 3. Phase 2 — Animation-LOD framework

### `AnimationLODManager` (autoload, `enemies/animation_lod_manager.gd`)

Mirrors the EnemyNavManager pattern exactly: enemies `register()` in
`reset()` and `unregister()` in `deactivate()`; the manager evaluates a
config-driven number of enemies per physics tick, round-robin (staggered —
never the whole population in one frame).

Per evaluation: distance to the current camera + frustum test
(`Camera3D.is_position_in_frustum`) → level from the config bands, with a
hysteresis margin so enemies straddling a band edge don't flicker between
levels. Off-screen applies a configured demotion (e.g. one level harsher).
The result is pushed once per change: `visual.set_lod_level(level, hz)`.

### `LODConfig` (Resource schema `enemies/lod_config.gd` → `resources/config/lod_config.tres`)

```gdscript
@export var evaluations_per_tick := 4          # stagger budget
@export var full_distance := 12.0              # ≤ → FULL
@export var reduced_distance := 25.0           # ≤ → REDUCED
@export var paused_distance := 45.0            # ≤ → PAUSED, > → cull zone
@export var hysteresis := 2.0                  # band-edge dead zone (m)
@export var offscreen_demotion := 1            # levels dropped when not in frustum
@export var reduced_update_hz := 10.0
@export var paused_update_hz := 0.0
@export var cull_visuals := false              # CULLED hides the model
@export var background_tier_enabled := false   # hook only — see below
```

Every default is **explicitly a placeholder** (file-comment: "to be profiled
by Opus per PROFILING_PLAYBOOK against final models"). Changing behavior =
editing the `.tres`.

**Background-crowd hook (not an implementation):** one config flag + one
documented extension point — when `background_tier_enabled` and an enemy
sits beyond `paused_distance`, the manager calls an (empty, documented)
`_hand_off_to_background(enemy)` seam. Whether a MultiMesh tier is ever
needed is Opus's call post-profiling; nothing else may reference the flag.

Manager exposes `level_counts() -> Dictionary` for the perf overlay.

---

## 4. Phase 3 — Spawn / AI director

### Division of responsibility (unchanged owners, new brain)

- **RoundManager** keeps round lifecycle, budget, top-up, round-clear —
  untouched logic. Two delegations replace its dumb parts:
  `_pick_spawn_point()` → `SpawnDirector.next_spawn_position()`, and the
  flat `spawn_interval` → `SpawnDirector.current_spawn_interval()` read each
  time the spawn timer is (re)armed.
- **SpawnDirector** (autoload) owns placement + pacing + cohort logic. It
  never spawns and never counts budget — it answers RoundManager's
  questions. Round progress for the pressure curve comes from data
  RoundManager already exposes (spawned/budget via a small read API), not a
  parallel counter.
- **EnemyNavManager** stays the sole writer of `agent.target_position`.
  Group behavior is computed inside it (from director config), never by a
  second writer.

### Smart placement (replaces random marker pick)

Candidates = the existing `enemy_spawn_point` markers (no scene rework).
Filter/score per spawn:
1. Reject inside the player camera frustum (`is_position_in_frustum`).
2. Reject closer than `min_spawn_distance` to the player.
3. Prefer (score) behind the player (view-dot), within
   `preferred_distance_range`, and the marker cluster the current cohort is
   already using (`burst_marker_stickiness` — cohorts arrive together).
4. **Graceful fallback:** if every marker is rejected, take the
   least-visible/farthest candidate anyway and log once — a round must never
   stall on placement.

### Pacing / pressure

`pressure(progress)` sampled from an exported `Curve` in DirectorConfig
(progress = fraction of round budget spawned). Pressure maps linearly onto:
- spawn interval: `lerp(interval_relaxed, interval_peak, pressure)`
- concurrency ceiling: `lerp(concurrent_floor_fraction, 1.0, pressure) ×
  RoundConfig.max_concurrent` (never above the pool's hard 50)
Flat-curve default reproduces today's behavior; the ramp is data.

### Group behavior (inside EnemyNavManager)

Per-enemy assignment stored **in the manager** (slot index assigned at
register, freed at unregister):
- **Flanking:** `flank_fraction` of slots get a lateral offset
  (`flank_distance`, perpendicular to the enemy→player line) applied to the
  nav target; the rest aim true.
- **Surround ring / anti-stack:** inside `ring_radius` of the player the
  target becomes a stable per-slot angle on a ring around the player instead
  of the exact point — approaching enemies fan out instead of stacking into
  one doorway pixel.
- **Local separation:** config-gated `NavigationAgent3D` RVO avoidance
  (`avoidance_enabled`, agent radius/neighbor params from DirectorConfig).
  This touches the enemy's movement step (velocity goes through
  `agent.velocity` → `velocity_computed`) — engine-sanctioned steering, and
  the one-writer rule (which governs `target_position`) is preserved.
  Config-gated because RVO has real cost at 50 agents — Opus profiles it.
- **Funneling** emerges from placement (cohorts spawned on one side route
  through the same chokepoint together) — burst placement is the mechanism;
  no special nav code.

### `DirectorConfig` (schema `autoload/director_config.gd` → `resources/config/greybox_director.tres`)

```gdscript
@export var min_spawn_distance := 8.0
@export var preferred_distance_range := Vector2(10.0, 25.0)
@export var behind_bias := 0.5              # scoring weight for out-of-view/behind
@export var burst_size_range := Vector2i(3, 6)
@export var burst_marker_stickiness := 0.75 # chance a cohort reuses its cluster
@export var pressure_curve: Curve           # default: flat 0.5 (placeholder)
@export var interval_relaxed := 1.2
@export var interval_peak := 0.4
@export var concurrent_floor_fraction := 0.5
@export var flank_fraction := 0.25
@export var flank_distance := 4.0
@export var ring_radius := 6.0
@export var ring_spacing_degrees := 24.0
@export var avoidance_enabled := true
@export var avoidance_radius := 0.5
@export var avoidance_max_neighbors := 8
```

All placeholders, same Opus-profiling comment.

### EventBus

Registration and config queries follow the **existing direct-call
precedent** (EnemyNavManager registration is direct, not signaled). No new
cross-system events are required; if review wants pressure surfaced for
HUD/telemetry later, `director_pressure_changed(pressure: float)` is the
one candidate — proposed but **not** added until something consumes it
(signals-first is for events with listeners, not speculative broadcast).

---

## 5. Phase 4 — Spec, playbook, overlay, docs

- **Perf overlay** (`ui/perf_overlay.gd/.tscn`): FPS, frame ms, physics ms,
  draw calls (Performance monitors), active enemies (EnemyPool), LOD level
  distribution (AnimationLODManager). CanvasLayer, hidden by default,
  toggled by a new PERF debug-panel button routed through DebugManager,
  removed entirely when the debug flag is off (existing strip pattern).
- **MODEL_BUDGET.md**: first-principles budget for the final zombie models
  on RTX 4060 / i5-13600KF at 50 agents / 60 FPS: bone count ceiling,
  triangle budget per LOD, material/draw-call rule, animation set size/fps.
- **PROFILING_PLAYBOOK.md**: ordered measurement procedure (baseline empty
  scene → 10/25/50 spawns → toggle each LOD band → toggle RVO), which
  monitor to read for each, and which `.tres` knob each result tunes.
- **CODE_GUIDE.md**: horde-architecture section — the visual seam contract,
  LOD framework, director division of responsibility, the data-driven-knob
  rule, and "adding an enemy type without blowing the budget" (reuse the
  shared clip library, fit MODEL_BUDGET, one material, register with all
  three managers via the base class — which it gets for free).

---

## 6. Existing-file touch list

| File | Phase | Change |
|---|---|---|
| `enemies/enemy.gd` | 1 | AnimationTree plumbing out; intent calls to `$Visual`; delete `set_animation_enabled`; register/unregister with AnimationLODManager (2) |
| `enemies/zombie_walker.tscn` | 1 | Restructure: `Visual` node (EnemyVisual) owning Model; AnimationTree sub-resources deleted (built in code); clip names as exports |
| `enemies/enemy_nav_manager.gd` | 3 | Slot assignment, flank/ring target computation, DirectorConfig read; still sole target writer |
| `autoload/round_manager.gd` | 3 | Delegate placement + interval to SpawnDirector (two call sites) |
| `autoload/event_bus.gd` | 3 | Only if review approves `director_pressure_changed`; otherwise untouched |
| `autoload/debug_manager.gd`, `world/debug_button.gd`, `world/debug_panel.tscn` | 4 | PERF toggle button (panel respace to 10) |
| `world/greybox.tscn` | 3 (maybe) | Possibly a few extra `enemy_spawn_point` markers for placement variety; no structural change |
| `project.godot` | 2, 3 | +2 autoloads (AnimationLODManager, SpawnDirector) via editor/MCP only |
| `CHANGELOG.md` | each | Foundational entries; version bump coordinated with maintainer (off the milestone track) |

Untouched on purpose: `enemy_pool.gd` (contract is durable as-is),
`round_config.gd` (round data stays round data; director data is separate),
`nav_region.gd` (runtime bake unchanged — navmesh architecture note: the
region already parses only the Geometry subtree; buildables stay out of the
bake, which Phase 3 placement must respect but not change).

## 7. Conformance notes (CODE_GUIDE)

- Signals-first: no new speculative signals; registration follows the
  established direct-call manager pattern.
- One-writer nav rule: extended inside the one writer, never forked.
- Pooling contract: `reset()`/`deactivate()` gain register/unregister calls
  only — no lifecycle change, nothing freed in hot paths.
- Data-driven rule: two new Resource schemas; every number quoted above is a
  placeholder default in a `.tres`, commented for Opus's profiling pass.
- Debug routing: overlay + toggle through DebugManager, strips with the flag.
- Jolt config: already enabled project-wide; Phase 3 verifies agent physics
  settings (avoidance on/off) are config-gated rather than assumed.

## 8. Risks / flags for review

1. **Editor MCP is currently disconnected** — Phases 1–4 need it for
   autoload registration, scene reload syncs, and live verification
   (screenshots, harness driving). Phase 0 is unaffected.
2. Runtime-built AnimationTree (Phase 1) trades scene-inspectability for
   zero per-enemy authoring; flagged in case the maintainer prefers
   scene-authored trees.
3. RVO avoidance cost at 50 agents is unknown against placeholder rigs —
   shipped config-gated ON with conservative params; the playbook makes it
   measurement #4.
4. The retargeted-library path can be configured but not *proven* until a
   SkeletonProfileHumanoid-mapped model exists; the sibling-KayKit swap test
   proves the seam's resource-only claim in the meantime.
