# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/); versioning is
semantic (pre-1.0: minor = milestone, patch = fixes within it). See DESIGN_DOC §12
for the milestone roadmap.

## [0.8.3] — Phase-driven music pools, boss round, single-channel stinger

> Audio patch on v0.8.2's rotation: round music now actually belongs to
> rounds, the death song can never stack or outlive a respawn — and the
> map boss now actually spawns after the final round.

### Added

- **The boss round**: after the final round clears (`rounds_per_map`,
  city 8 / greybox 5), RoundManager skips the PREP lull and spawns
  `PumpkinBoss` at a director-chosen marker (`boss_round_started` on the
  EventBus, phase stays ROUND); killing it emits `map_cleared` (now LIVE,
  no longer reserved) and ends the run. Encounter dressing (health bar,
  arena, difficulty pass) stays v0.9.0 scope.
- **Boss music is live**: `boss_round_started` crossfades to the map's
  `boss_track` (breach.mp3) played as a single-track pool — it loops for
  the whole fight without the import loop flag; `map_cleared` returns to
  the prep rotation as the victory lap.

### Changed

- **Music is phase-driven again, with the rotation kept per-phase**:
  `MapMusic.tracks` split into **`prep_tracks`** (level load + PREP +
  between rounds) and **`round_tracks`** (while a round is live).
  AudioManager consumes `round_started`/`round_cleared` once more,
  crossfading between the two pools; the shuffle-bag rotation (no
  immediate repeats, advance on `finished`) runs within whichever pool is
  active. Pool switches ride the existing two-player crossfade — the
  outgoing song stops, never layers — and re-entering the already-active
  pool keeps the current song running. An empty pool is silence by design;
  both map soundtracks ship with populated pools — prep rotates
  stitches / witness prevention, rounds rotate Killphase / pathogen /
  repulse (a placeholder split of the six placeholder songs; reshuffling
  is a .tres edit).
- **Single-channel one-shot rule** baked into AudioManager: it owns a
  FIXED set of players (two music + one dedicated stinger channel) and
  always stop/replaces through them — ad-hoc players are banned. The
  death stinger (city: `game_over.mp3`) plays on the dedicated channel
  with stop-before-play, and `set_soundtrack()` (the respawn path) stops
  it — one death = exactly one death song, a second death replaces it,
  and it can't bleed into the new run.

### Fixed

- Death-song layering: `_on_player_died` used to spawn a fresh
  AudioStreamPlayer per death (freed only when the stream finished), so
  full-length death songs stacked across quick death/respawn cycles.

### Verified (CLI harness, real kill-driven flow on the city map)

- Load → prep rotation (witness prevention → stitches on song end);
  WAVE → round pool at 0 dB with the prep player stopped (no overlap);
  re-emitting `round_started` kept the same song at the same position.
- Killing the (shortened) final round spawned the boss and crossfaded to
  breach.mp3; forcing the song's end restarted breach (looping);
  a headshot kill printed the map-cleared line, emitted `map_cleared`,
  and returned the prep rotation with the run stopped.
- Death: exactly ONE stinger player (`game_over.mp3`); a second death
  restarted it in place (still one player); `set_soundtrack()` on respawn
  stopped it and resumed the prep rotation.

## [0.8.2] — Rotating randomized soundtrack + T-pose spawn-flash fix

> Off-roadmap patch on top of v0.8.1, driven by playtest feedback.

### Changed

- **Music is now a randomized rotation, not phase crossfades**: `MapMusic`
  replaces `prep_track`/`combat_track` with a **`tracks` pool** — regular
  play (prep AND rounds alike) draws random songs via a shuffle-bag (every
  song plays once per cycle, no immediate repeats) and rolls to the next
  pick the moment a song ends (fixes "the round song ends and nothing
  replaces it" — rotation rides the player's `finished` signal, so pool
  tracks must NOT set the import loop flag). Only the boss keeps ONE
  dedicated song (`boss_track`, still the reserved v0.9.0 seam).
  `round_started`/`round_cleared` are deliberately no longer consumed by
  AudioManager. Both map soundtracks now pool the five
  `resources/audio/placeholder/` songs (stitches / Killphase / pathogen /
  repulse / witness prevention) with `breach` as the dedicated boss song.

### Fixed

- **T-pose flash on spawn** (the residual "enemies T-pose when moving"
  report): `reset_visual()`'s `playback.start()` only takes effect on the
  tree's next evaluation, leaving the retargeted rest pose (a T) visible
  for the first frame(s) of every on-camera spawn — caught live as a
  `Start`-node rest-pose sample on a FULL-LOD fresh spawn. `EnemyVisual`
  now forces a zero-delta `advance()` immediately after starting locomotion
  in `_ready` and `reset_visual()`.

### Verified (live via MCP, city map)

- Launch picked a random pool song; four forced song-ends rotated through
  the remaining four (full bag, zero repeats, zero silence gaps); death
  faded both players out; restart resumed rotation with a fresh pick.
- Three T-pose soak passes (0.25 s sampling) across fresh waves, mass
  kills, pool reuse, and a round transition: **zero** rest-pose incidents,
  including 35 sampled SPAWNING windows (the previous flash reproducer) —
  and a game-over pause froze a spawning enemy posed, not T-posed.

## [0.8.1] — Audio system: buses, AudioManager, per-map soundtracks, data-driven SFX

> Off-roadmap patch (like the v0.4.2 bhop patch). Replaces "synth-only" with
> a real audio architecture; the synth placeholders remain the fallback so
> the game is audible with zero sound assets.

### Added

- **Music / SFX buses** (`default_bus_layout.tres`, both send → Master).
  Every world/weapon/enemy player routes to SFX via `AudioManager.SFX_BUS`;
  volumes verified independent.
- **`AudioManager`** (autoload): two crossfading music players on the Music
  bus, phase-driven purely by EventBus — level load → prep track (free-fire
  default), `round_started` → combat, `round_cleared` → prep,
  `player_died` → fade + optional stinger (runs through the game-over pause,
  `PROCESS_MODE_ALWAYS`). `map_cleared`/`boss_track` left as the RESERVED
  v0.9.0 seam. Unassigned phase track = silence, no error.
- **Per-map soundtracks — the core contract**: `MapMusic` resource schema
  (`audio/map_music.gd`: prep/combat/(reserved) boss tracks, death stinger,
  crossfade_time) authored per map under `resources/audio/`. Each map's root
  is now a **`Level`** (`world/level.gd`) that hands its own `soundtrack`
  .tres to `AudioManager.set_soundtrack()` — greybox assigns
  `greybox_soundtrack.tres` in-scene; `city.gd` preloads
  `city_soundtrack.tres` beside its round/director configs. AudioManager
  contains zero map knowledge: a new map's music = a new .tres.
- **Data-driven weapon SFX**: `WeaponData.fire_sound / reload_sound /
  dry_sound` — a real gun sound is a file assigned in the .tres; unset
  falls back to the synth `PlaceholderSfx` (current behavior preserved).
  Same swappable pattern added to `ImpactEffect.impact_sound` and
  `DestructibleLight.break_sound`; turret gunfire, electric trap hum and
  Electric Cherry zaps re-routed to the SFX bus.
- **Enemy SFX** (enemies were silent): optional `Sfx` AudioStreamPlayer3D in
  the enemy scene contract + `Enemy.chase_sound / attack_sound / death_sound`
  exports triggered from the AI transitions (`_enter_chase`, `_start_attack`,
  `die()`; the boss's leap windup reuses the attack snarl as its audible
  telegraph). Data-driven, silent when unset; both enemy scenes ship with the
  generated placeholder vocal set (boss at `pitch_scale 0.65`).
- **Generated placeholder audio** (`audio/_sfx_bake.gd`, headless one-shot in
  the `_texture_bake.gd` tradition): deterministic synth music loops (greybox
  A-rooted 100 BPM pair, city D-rooted 110 BPM pair — audibly distinct on
  purpose), death stinger, and the zombie groan/snarl/gurgle set, committed
  as `resources/audio/generated/*.res`. Swapping in real CC0 files
  (DESIGN_DOC §10) is editing the .tres references only.

### Fixed

- `[audio] buses/default_bus_layout` in `project.godot` pointed at a
  non-existent `res://music` — now points at the real bus layout.

### Verified (CLI harness, headless-driven)

- Music=bus 1 / SFX=bus 2; −20 dB on Music leaves SFX at 0 dB (independent).
- City load → `city_prep_loop` at 0 dB; `round_started` → crossfade to
  `city_combat_loop` (prep at −60, stopped); `round_cleared` → back to prep;
  `player_died` → both players fading (caught at −28 dB) with the stinger
  playing over the game-over pause.
- Greybox load → `greybox_prep_loop` — a different track through identical
  code: per-map soundtracks proven with two live maps.
- Weapon: unset `fire_sound` → synth fallback (runtime-generated
  AudioStreamWAV) on the SFX bus; assigning a stream on a duplicated
  WeaponData made the fresh weapon play it instead.
- Walker: vocal set assigned, `Sfx` on the SFX bus, groan playing (and
  positional) the moment `_enter_chase` fired.

## [Unreleased] — Mixamo enemy models: Romero walker + Pumpkinhulk map-boss placeholder

> First final-quality rigs through the Phase 1 `EnemyVisual` retargeted seam.
> Version bump to be coordinated with the maintainer (uses 2 of the ≤4
> enemy-type budget, DESIGN_DOC §11).

### Added

- **Mixamo "Romero"** (`enemies/models/romero/`) is the standard walker's rig:
  gaunt bloodied shambler, T-pose FBX imported retargeted
  (`import_as_skeleton_bones=true` + BoneMap vs `SkeletonProfileHumanoid`),
  ~1.77 m tall at natural scale. `zombie_walker.tscn` is a pure resource swap —
  zero `enemy.gd` edits: `Visual/Model` → Romero, the three clip exports →
  `"shared/Zombie{Walk,Attack,Death}"`, `HeadShape`/body capsule realigned to
  the hunched-shamble silhouette measured in-game (head sphere r=0.26 @
  (0, 1.45, -0.08); capsule r=0.35 h=1.4, shortened so head-height rays reach
  the head sphere instead of the capsule dome).
- **Mixamo "Pumpkinhulk L Shaw"** → **`PumpkinBoss`**
  (`enemies/pumpkin_boss.gd` + `.tscn`), the map-boss placeholder
  (DESIGN_DOC §6/§11: tougher enemy, ONE special behavior, no phases): thin
  `extends Enemy` subclass; tanky via scene export overrides only
  (health 450 = 7.5× walker, speed 3.2, damage 30, range 2.4, death 4.6 s).
  Model scaled 1.4× → ~2.86 m; pumpkin head is the weak point: the mutant
  gait/swipe swing the pumpkin through a ~2 m envelope, so the `HeadShape`
  sphere (r=0.5) is **bone-tracked** — `PumpkinBoss._track_head_shape()`
  follows the Head bone each physics frame (runtime-resolved like
  `EnemyVisual`'s player lookup; body capsule r=0.6 h=2.4; body=shape 0,
  head=shape 1 contract intact).
- **Anti-kite leap** (the boss's one special behavior), entirely inside
  `PumpkinBoss` via `_physics_process` override + `super` delegation — base
  state machine untouched: past `leap_trigger_distance` (12 m, CHASING,
  unstunned, on floor, off cooldown) the boss telegraphs
  (`visual.play_attack()`, `leap_windup` 0.4 s), re-aims, then arcs
  velocity-driven through `move_and_slide()` (walls stop it; leap owns Y) to
  land `leap_landing_gap` (3 m) SHORT of the player — standing still eats the
  ordinary follow-up melee, moving slips it. `leap_damage` default 0 (no
  landing thump). All eight knobs are `@export`s; placeholder values for the
  maintainer. Leap never writes `agent.target_position` (one-writer rule
  intact); `reset()` override clears leap state for pool reuse.
- **Shared retargeted `AnimationLibrary`**
  (`enemies/models/mixamo_shared/zombie_shared_anims.res`): 7 Mixamo clips
  (zombie walk/attack/death + run spare; mutant walk/swipe/death), exported
  Without Skin @30 fps, retargeted through `SkeletonProfileHumanoid` and
  compressed (`Animation.compress()`). One library serves both rigs (clip
  memory constant per MODEL_BUDGET). TWO BoneMaps ship alongside — Mixamo
  bone prefixes differ per character (`mixamorig_*` hulk / `mixamorig5_*`
  Romero, `:`→`_` sanitized on import). **Mixamo's "In Place" export option
  did NOT strip root motion** on any walk/run clip (1.3–2.4 m of Hips travel
  per loop → the visual sawtooths off its collider), so the library build
  pins every locomotion clip's Hips position track to its first-frame X/Z
  (Y bob kept) before compressing.
- **Debug SPAWN BOSS button** (debug strip, same shootable pattern):
  `DebugManager.spawn_boss()` → `EnemyPool.acquire(pos, BOSS_SCENE)` at the
  near marker, so boss + leap are testable before the v0.9.0 encounter.
- Mixamo origin notes (`MIXAMO_ORIGIN.md`) under each model folder; CREDITS
  rows for both characters + the clip set.

### Changed

- **`EnemyPool` generalized to per-scene free-lists**
  (`acquire(pos, scene := ZOMBIE_SCENE)`, `Dictionary[PackedScene → Array]`):
  boss pools separately from walkers; instantiate-once/recycle contract and
  the **global** `MAX_ENEMIES=50` cap unchanged; `active_count()` /
  `has_live_enemies()` / `release_all()` / `total_count()` sum across pools.
  `RoundManager` untouched (default arg).
- `debug_panel.tscn` board widened for the 11th button.

### Budget notes (MODEL_BUDGET.md) — flagged, not hidden

- **Bones**: Romero 66, Pumpkinhulk 67 (both incl. fingers + one node-bone)
  vs the ≤40/≈55 ceiling — no local DCC tooling (no Blender) to strip
  fingers; animation-LOD carries the cost until a decimation pass.
- **Tris**: Pumpkinhulk 9,620 (1 surface/material ✓) — singular boss,
  acceptable overage. **Romero 49,593 tris / 2 surfaces** — far over the
  2–4 k target for the pooled walker; importer-generated mesh LODs +
  animation-LOD mitigate, but this is THE candidate for the
  PROFILING_PLAYBOOK step-2 spawn-ramp before any 50-walker soak. Decimation
  (and a texture atlas to get back to 1 draw call) needs a DCC pass —
  deliberately not attempted here.
- **Nav**: boss capsule r=0.6 / agent r=0.7 vs the city navmesh baked at
  `agent_radius 0.45` — the boss can clip tight alleys/doorways. Flagged per
  the brief (bigger nav agent bake, or keep the boss to open arenas — data
  decision, not silently fixed). Boss round-spawn pacing also deliberately
  unbuilt (v0.9.0 encounter scope).

### Fixed (post-review)

- **Enemies faced away from the player**: the retarget import already leaves
  Mixamo rigs facing +Z, which is the axis `Enemy._face` points at movement —
  the 180° Y flips on both `Model` nodes made them walk backwards. Flips
  removed (walker `HeadShape` z-offset mirrored to match). Verified by
  screenshot on a CLI harness run — the earlier "model forward" vector check
  measured the wrong axis convention.
- **T-posing while moving / on death**: wave spawns land far off-screen and
  `AnimationLODManager` can demote them to PAUSED **before the AnimationTree's
  first evaluation** — the playback never leaves the state machine's Start
  node and the skeleton freezes at REST pose (a literal T-pose on retargeted
  rigs; KayKit's idle-like rest pose had masked the same latent race).
  `EnemyVisual` now forces a zero-delta `advance()` when a state change or
  demotion lands on a throttled tree. Reproduced (enemies stuck on `Start`
  with rest-pose gliding at 5.2 m/s) and re-verified clean over a full wave
  in the city map via CLI harness.

### Verified (all in-game via the MCP harness, city map)

- **Walker parity through the new rig**: debug spawn → SPAWNING → CHASING at
  5.2 m/s (model forward · velocity = 0.998, no moonwalk) → ATTACKING with
  model forward exactly on the player vector → melee actually killed the
  test player → death anim node `death` plays once, collision drops, pooled
  invisible after `death_duration`. Weak point exact: body hit 60→48 (1×),
  head hit 48→24 (2×).
- **Headshot alignment vs the VISIBLE head** (camera-origin raycasts at the
  head bone, the same query weapons use): walker 6/6 head-shape hits while
  walking; boss 7/8 at 8 m engagement range (1 miss raced a teleport, hit
  nothing — no wrong-shape damage). Boss point-blank rays from under the
  chin legitimately hit the chest (real occlusion, not misalignment).
- **Boss**: spawns via SPAWN BOSS as `PumpkinBoss` (450 hp, 3.2 m/s), own
  free-list (walker + boss = total 2 under the one autoload), pumpkin 2×
  (450→400 body, 400→300 head), MutantDeath → pooled after 4.6 s, and the
  SAME instance re-acquired on respawn with full health and clean leap state.
- **Leap**: at 13.2 m (> trigger 12) — windup tell, airborne at t≈0.75 s
  (y=1.03 arc), landed with cooldown counting (4.73 s), state stayed CHASING
  through `super` delegation, then the ordinary attack: standing player ate
  exactly 30 (100→70); a player who moved during the follow-up took 0. While
  falling (no floor), the leap correctly refused to trigger. Export-driven:
  dropping `leap_trigger_distance` 12→6 at runtime made a 7 m kite trigger
  the pounce; windup/cooldown writes behaved likewise — zero code edits.
- **Animation-LOD on both rigs**: REDUCED (walker @18 m stunned, boss
  @12.5 m): `lod=1`, `AnimationTree.active=false`, pose still advancing
  (manual 10 Hz). PAUSED (walker @32 m): `lod=2`, pose frozen. FULL
  restored on approach. Locomotion looped across minutes of testing on both.
- `RoundManager` untouched: normal wave spawning unchanged through the
  default-arg pool (walker free-list).

## [Unreleased] — Horde Performance Architecture (foundational)

> Cross-cutting architecture work (ARCH_PLAN.md), off the linear milestone
> track. Version bump coordinated with the maintainer when the phases land.

### Changed — Phase 1: enemy ↔ visual decoupling

- Extracted **`EnemyVisual`** (`enemies/enemy_visual.gd`, the enemy scene's
  `Visual` node): owns the `Model` + all animation. It builds the
  `locomotion`/`attack`/`death` AnimationTree **in code** from three exported
  clip names, resolves the `AnimationPlayer` at runtime, and exposes an intent
  API (`play_locomotion/attack/death`, `reset_visual`, graded
  `set_lod_level(level, hz)`). Retargeted-library mode (`SkeletonProfileHumanoid`)
  is supported as a data switch for final models; import checklist in CODE_GUIDE.
- `Enemy` base now contains **no** `anim_tree`/`_playback` access — it speaks
  only intent to `$Visual`. Removed the bare `set_animation_enabled` hook
  (superseded by `set_lod_level`) and the `loop_animations` export (the visual
  loops locomotion itself). `zombie_walker.tscn` restructured: `Visual` node owns
  the Model; the per-scene AnimationTree sub-resources are gone.

### Verified

- `zombie_walker` chases, attacks, dies, pools, and registers weak-point hits
  identically through the seam (body 60→48, headshot 48→24 = exact 2×, second
  headshot →0, returned to pool).
- **Resource-only swap proven**: pointing `Model` at a different humanoid GLB
  (`Skeleton_Warrior`) with the same three clip names spawned and behaved
  correctly with zero `enemy.gd` edits.

### Added — Phase 2: animation-LOD framework

- **`AnimationLODManager`** (autoload) assigns each active enemy an LOD level
  from distance-to-camera + frustum visibility and drives the `EnemyVisual`
  seam: `FULL` (engine-ticked) → `REDUCED` (manual advance at a config Hz) →
  `PAUSED` (frozen) → `CULLED` (opt-in hidden). Staggered evaluation
  (`evaluations_per_tick`, round-robin) like the nav manager; sticky hysteresis
  on band edges; `offscreen_demotion`; `level_counts()` for the Phase 4 overlay.
  Enemies register in `reset()` / unregister in `deactivate()` (not `die()`, so
  death anims stay LOD-managed until pooled).
- **`LODConfig`** resource (`enemies/lod_config.gd` →
  `resources/config/lod_config.tres`) holds every threshold — distance bands,
  update rates, hysteresis, demotion, cull/background flags. **All defaults are
  explicit placeholders** for Opus to profile against the final rigs.
- Background-crowd tier (DESIGN_DOC §8.4) present as a **data-gated hook only**
  (`background_tier_enabled` default false + an empty `_hand_off_to_background`
  seam) — not implemented, not required.

### Verified

- SPAWN-10 in the debug room: the population's LOD tracks distance **and**
  facing. Standing in a converged cluster, facing away → `REDUCED=10`; spinning
  180° to face the same enemies → `FULL=10` — identical positions, camera
  facing alone flipped the whole set. Spread test showed a mixed
  FULL/REDUCED/PAUSED distribution by distance+visibility, with
  `AnimationTree.active == (level == FULL)` confirming the skeletal cost is
  actually dropped for throttled enemies (verified via `level_counts()`; the
  visual overlay lands in Phase 4).
- Hysteresis observed holding levels across the band-edge dead zone (no flicker).
- Every threshold changed behavior from `lod_config.tres` with no code edit.

### Added — Phase 3: spawn director + group behavior

- **`SpawnDirector`** (autoload) answers RoundManager's three questions —
  `next_spawn_position()`, `current_spawn_interval()`,
  `current_concurrency_ceiling()` — and never spawns or counts budget itself.
  Placement scores the existing `enemy_spawn_point` markers: in-frustum and
  too-near markers are rejected, survivors scored by behind-the-player
  view-dot + preferred distance band, and cohort **bursts** stick to one
  marker cluster (`burst_marker_stickiness`) so waves funnel through a
  chokepoint together. Graceful fallback: if every marker is rejected the
  least-visible/farthest one is used anyway (one warning) — a round can
  never stall on placement. Pacing maps an exported pressure `Curve`
  (input: `RoundManager.round_progress()`) onto spawn interval and a
  concurrency ceiling that scales *within* `RoundConfig.max_concurrent`,
  hard-clamped to the pool's 50.
- **`DirectorConfig`** resource (`autoload/director_config.gd` →
  `resources/config/greybox_director.tres`) holds every director and
  group-behavior knob — **all defaults are explicit placeholders** for the
  PROFILING_PLAYBOOK pass. The shipped flat-0.5 curve reproduces the old
  fixed pacing exactly (interval 0.8 s). Two deliberate deltas from
  ARCH_PLAN §4, both documented in the schema: `avoidance_enabled` ships
  **false** (RVO cost at 50 agents measured well over budget, see Verified),
  and `ring_target_radius` was added because the surround ring needs a
  target radius distinct from its trigger radius or arrivals would hold
  formation outside melee reach.
- **Group behavior in `EnemyNavManager`** — still the only writer of
  `agent.target_position`: each registered enemy gets a stable recycled
  **slot** index; within `ring_radius` of the player the slot maps to a
  fixed ring angle (`ring_spacing_degrees`) at melee reach — approachers fan
  out and surround instead of stacking; outside the ring, every
  1/`flank_fraction`-th slot approaches with a lateral `flank_distance`
  offset, alternating sides; everyone else aims true, as before.
- **Config-gated RVO separation**: at registration the nav manager applies
  `avoidance_enabled`/`radius`/`max_neighbors` to the agent, plus
  `max_speed = move_speed` (RVO resolves crowd overlap at up to `max_speed`,
  default 10 — packed zombies got flung at ~4.5× walk speed until capped).
  When enabled, the enemy's chase velocity routes through
  `agent.set_velocity()` → `velocity_computed` (stale replies after a
  same-frame state change are dropped); when disabled — the shipped default
  — the movement step is the pre-existing direct path, unchanged.

### Changed

- `RoundManager`'s spawn timer is now **one-shot and re-armed** at the end
  of every `_try_spawn()` (including topped-out/deferred attempts, matching
  the old repeating-timer retry cadence): the interval is re-read from the
  director on each arm, so the pressure curve shifts pacing spawn-by-spawn.
  The concurrency check reads the director's ceiling; placement is fully
  delegated (spawn jitter moved into `DirectorConfig.spawn_jitter`); new
  read API `round_progress()` / `live_count()`. Budget growth, death
  top-up, and the round-clear gate are untouched.

### Verified

- Round 1 spawned exactly its budget (6/6) and cleared to PREP on the last
  kill with corpses still animating (v0.4.x gate intact). All six spawns
  arrived ≥30 m out as one cohort on a single marker cluster; round 2 sent
  9-of-10 through the corridor cluster + 1 from room B.
- With every marker inside the camera frustum, spawning continued from the
  least-visible/farthest marker with exactly one warning — no stall.
- Pressure is pure data: swapping in a ramped Curve at runtime moved the
  interval 1.2 → 0.4 s and the ceiling 12 → 24 across round progress with
  zero code edits; restoring the flat curve returned 0.8 s / 18.
- Ring: nine converged enemies each held their exact slot angle
  (24°·slot at radius 1.2) around the cornered player; far enemies aimed
  true. Flank: slots 0/4 offset ±4 m laterally on opposite wings, slot 1
  aimed true; repeated reads byte-identical (no jitter).
- RVO at the 50-agent cap: no NaNs/explosions, speeds capped at exactly
  2.2 m/s after the max_speed fix. Frame cost recorded for the playbook:
  physics ~2.1 ms while spread out, **17.4 ms converged into a jam vs
  3.75 ms with avoidance off** — the measured basis for shipping RVO off.

### Added — Phase 4: perf overlay, budgets, playbook, docs

- **Perf overlay** (`ui/perf_overlay.gd/.tscn`): CanvasLayer of read-only
  taps — FPS / frame ms / physics ms / draw calls (Performance monitors),
  active enemies (`EnemyPool.active_count()`), and the LOD level
  distribution (`AnimationLODManager.level_counts()`). Hidden by default,
  toggled by a new shootable **PERF** button through
  `DebugManager.show_perf_overlay`. It lives inside `debug_panel.tscn`
  (row respaced to ten buttons), so the whole fixture strips with the
  debug flag; no gameplay script references it.
- **`MODEL_BUDGET.md`** (repo root): first-principles per-enemy asset
  ceiling for the v0.8.0 art pass at 50 agents / 60 FPS on the target box —
  bones ≤40 (hard ~55), ~2–4k tris near, 1 material / 1 draw call, 3
  compressed clips, horde totals — every row marked "profile to confirm",
  plus the shared-retargeted-library note that keeps clip memory constant
  across the ≤4-type firewall.
- **`PROFILING_PLAYBOOK.md`** (repo root): the ordered measurement pass
  (baseline → spawn ramp at forced FULL → LOD band sweep → RVO go/no-go →
  director pressure) with the monitor to read and the `.tres` knob each
  step tunes, a recording template, and today's first RVO data point
  already logged.
- **CODE_GUIDE**: horde section extended with the Phase 3 division of
  responsibility (RoundManager lifecycle / SpawnDirector questions /
  EnemyNavManager targets), "why each knob exists" entries for the
  director knobs, and the Phase 4 profiling/budget cross-links.

### Verified

- PERF button lights green and shows the overlay, second hit hides both;
  hidden by default on boot. With 10 spawned the readout tracked
  `enemies 10`, and a 180° camera turn alone flipped the LOD line
  REDUCED 3 / PAUSED 7 → PAUSED 10 (identical positions — facing drove
  the distribution). Draw calls fell 610 → 58 turning from the room to a
  wall: the taps are live. Overlay + button strip with the debug flag via
  the existing debug_panel self-free (the overlay also self-frees
  independently).

## [0.8.0] — 2026-07-15

> First full map (DESIGN_DOC §12), built on the horde architecture above.
> v0.7.0 (second weapon) intentionally skipped by the maintainer — the map
> milestone was pulled forward.

### Added

- **First full map: WW2 British city, pre-bombing** (`world/city/city.tscn`) —
  a slice of 1930s–40s London rendered in the KFMod idiom (fog, blackout,
  emptiness; intact buildings, no bombsite dressing). Two street registers
  joined by chokepoints: a Portland-stone **boulevard** (curved west facade,
  ground-floor colonnade, domed corner building, tram rails) and a brick
  **high street** with a back-alley loop (alley → courtyard → back lane →
  colonnade passage) plus a dead-end yard. One **enterable tenement**
  (shop + back room, stair hall with enclosed stairwell, upstairs flat)
  routes horde traffic *through* the building via four doors and the stair.
- **Dressed, CSG-free scene** per the CODE_GUIDE rule: an invisible
  collision/nav **proxy** (`StaticBody3D` + 83 box shapes) under
  `NavigationRegion3D/Geometry`; all visuals outside it — ~500 textured
  `MeshInstance3D` primitives, window/paper MultiMeshes, primitive-built
  period props (K6 telephone box, pillar box, cast-iron lamp standards,
  two double-decker buses, burnt-out cars with fire glow, sandbag
  barricades, handcart, washing line, boarded monument), fictional-brand
  signage (shop fascias + hanging signs as `Label3D`, poster decals), and
  KFMod interiors (dado rail + stained plaster/wallpaper two-band walls,
  checkerboard tile, floorboards, furniture, ajar panel doors).
- **Original texture set** (`world/city/textures/`, 20 PNGs) generated
  in-engine by the kept-in-repo tool `_texture_bake.gd` (FastNoiseLite +
  Image API; poster decals via SubViewport + serif system font) — zero
  third-party assets, provenance in `CREDITS.md`. Includes blast-taped /
  boarded / blacked-out window decals (192 instances in 3 MultiMeshes).
- **Pre-baked navigation** (`world/city/city_navmesh.res`, 292 polys):
  baked once from the proxy colliders and saved; the city does **no**
  runtime bake at load (the greybox keeps `nav_region.gd`). Doorways are
  1.8 m wide × 2.4 m high — the tested minimum for `agent_radius 0.45` /
  `agent_height 2.0` voxelization; the tenement stair is a 24.6° ramp in
  an enclosed stairwell (wall + newel post) so paths can't shortcut its
  open side.
- **Set-dressing crowd** (DESIGN_DOC §3/§8.4): one `MultiMeshInstance3D`
  of still silhouettes (fogged plaza beyond the north barricade, a picket
  line, rooftop fire-watchers on the parapets) + one of barrage balloons.
  Exactly **2 draw calls** measured, zero per-frame AI, outside the nav
  Geometry, unreachable and unshootable. The
  `AnimationLODManager._hand_off_to_background()` seam stays dormant.
- **Per-map data, no new systems**: `resources/rounds/city_rounds.tres`
  (8 start / +5 / cap 30 / 25 s prep / 8 rounds) and
  `resources/config/city_director.tres` (authored ramp `pressure_curve`,
  burst 4–8, stickiness 0.8, preferred range 14–32 m); `world/city/city.gd`
  assigns both to the autoload managers at load — the map's only script.
- 15 `enemy_spawn_point` markers (streets, alleys, courtyard, lane, yard,
  colonnade **and inside the tenement**: shop back room, upstairs bedroom,
  landing) + 2 debug spawn markers; scavenge circuit of 26 pickups, the
  pre-placed bench, lab/burner/turret/MG/trap build spots and the cherry
  recipe note (bedroom); debug panel + perf overlay live in the map.

### Changed

- `application/run/main_scene` → `res://world/city/city.tscn` (the greybox
  stays in-repo as the dev/free-fire scene); project version → 0.8.0.
- City `WorldEnvironment` carries the greybox grade with fog retuned for
  the larger volume (density 0.052, luminous grey-green fog light 1.05,
  ambient 0.42, volumetric inject 0.32) — KFMod read: short sightlines,
  warm pools vs cold dark, grain + vignette intact.

### Fixed

- `AnimationLODManager._physics_process` could divide modulo-zero when the
  registered set emptied mid-loop (e.g. a mass `release_all` racing the
  tick) — now breaks out safely.

### Verified

- Blockout playtested before dressing: WAVE starts rounds; a south-cluster
  cohort walked 24 m up the boulevard and converged on the surround ring
  (1.7–2.3 m); round 1 → PREP → round 2 (budget 5→7) → "map cleared after
  2 rounds" with `EventBus.map_cleared` observed (runtime-shrunk config).
- Interior funnel both ways: with the player in the flat, street spawns
  entered the tenement and queued **up** the stairwell single file
  (Y 0→1→2→3 samples) to melee range; a bedroom-marker spawn descended
  and reached a player at the junction. Same routes re-verified on the
  dressed proxy and again on the **pre-baked** mesh (street→flat path,
  24 waypoints; no bake warning in the load log).
- Scavenge circuit on the map: pickup E-interact (scrap 0→2), build spot
  consumed exactly 4 scrap + 1 servo and instanced the auto turret, bench
  and recipe-note prompts live.
- Perf on the dressed map at the 50-agent cap, worst case (all on-screen,
  LOD FULL 48/50): 152 FPS / 6.2 ms frame / 3.0 ms physics — 2.6×
  headroom on the 16.67 ms budget; crowd toggled on/off moved draw calls
  by exactly 2; perf overlay live in the city (PERF button).
- Firewall (§11): hand-authored map, faked crowd (no AI/nav/pool/take_hit),
  1 enemy type (placeholder KayKit rig stays — MODEL_BUDGET gate honored,
  no final rig imported), no currency, boss seam left for v0.9.0,
  single-player only.

## [0.6.0] — 2026-07-11

### Added

- **Perk framework** (DESIGN_DOC §4.2): `Perk` resources (delivery/trigger/
  tier + effect), `PerkRecipe` formulas, both authored under resources/perks/.
  `PerkManager` fills its stub: 4-slot cap, apply/remove/swap/clear,
  `get_multiplier` stat aggregation, effect-node attach/detach,
  `perks_changed`. `CraftingSystem` fills its stub as the §8.1 formula
  resolver: tier-gated exact-multiset matching, crafting into Inventory
  doses, run-scoped recipe reveals.
- **Four perks**: Stamin-Up (move ×1.2), Double Tap (fire rate ×1.33),
  Deadshot Daiquiri (spread ×0.4) — bench-tier pure data; Electric Cherry —
  lab-tier scripted ON_RELOAD: a player-centered AoE shock (stun + damage)
  scaling with mag emptiness, floored so a near-full reload still zaps.
  Enemies gained `stun(duration)`.
- **Crafting stations**: pre-placed bench; the lab is a buildable (4 scrap +
  2 coils) whose formula needs a HEATED compound — the new Burner buildable
  (2 scrap + 1 coil) converts cherry extract → concentrate. Free-combine UI
  (mouse released, player frozen): compounds → mix → Combine validates;
  match crafts a dose, miss reads "unstable" and consumes nothing; held
  doses apply from the same screen. No recipe browser — a RecipeNote pickup
  reveals a formula for the run only (no meta-progression).
- **HUD perk slots**: the reserved region now shows a chip per active perk;
  at the 4-cap every chip gains the gold border (§4.2).
- Eight COMPOUND items + pickups scattered through the greybox; a cherry-
  formula note; debug CLEAR PERKS button; GRANT extended with compounds.
- `weapon_reload_started` now carries (duration, mag, mag_size).

### Verified

- Stamin-Up crafted at the bench from memory (no note); a wrong mix read
  "unstable" with inventory byte-identical; the CORRECT Electric Cherry
  mixture at the bench also read "unstable" with nothing consumed (tier
  gate), then crafted at the built lab; the burner heat step converted
  extract → concentrate ahead of it.
- All four doses ingested: slots full, HUD chips wore the gold cap border,
  and the multipliers measured exactly — walk 4.50 → 5.40 (×1.2), 18 → 24
  rounds per 2-second burst (×1.33), spread multiplier 0.40 reported at the
  read point.
- Electric Cherry zap scaled precisely with emptiness: mag 6/30 reload dealt
  exactly 76 (killed through 60 HP, stun registered), mag 19/30 dealt exactly
  45.7 (survivor at 14.3), and a full mag refused to reload — no zap.
- Debug clear-perks emptied the slots (multipliers back to 1.00, walk back
  to 4.50) and a re-crafted dose applied again; death → restart wiped perks,
  reveals, compounds and doses to a clean bag.

## [0.5.1] — 2026-07-10

### Added

- **Manual turret (Mounted MG)** — second craftable (5 scrap + 1 servo): a
  WeaponData-driven MG (manual_mg.tres, 7.62mm, 20 dmg @ 12 rps, 150-round
  mag) on a yaw/pitch rig with arc clamps. E mounts: the turret camera takes
  over, every player input path is suppressed, and the body parks at the
  mount — still vulnerable (rooted + exposed is the trade). While mounted:
  mouse aims within the clamps, LMB fires (a pulled trigger always spends the
  round, hit or miss), R refills the mag from the shared Inventory pool,
  E dismounts. The HUD shows the MG while mounted and the sidearm after.
  Dying while mounted force-dismounts before the game-over overlay.
- **Electric trap** — third craftable (3 scrap + 2 coils): E-activated zone
  over the corridor, IDLE → ACTIVE (8 s) → COOLDOWN (10 s). Environmental
  damage (no weak points): a 100-burst to each enemy entering the live zone
  (or already inside at activation) plus a 16-per-tick DoT while they stay.
  Current 60-HP zombies die to the burst outright; tankier future waves will
  survive and bleed — no rework needed. Arc particles + a synthesized looping
  electric buzz (no binary audio). Refuses activation while live/recharging;
  the prompt live-counts the recharge.
- New items: Coil (part) and 7.62mm (ammo) + pickups; both recipes as .tres;
  build spots placed (MG facing room B's spawn lane, trap covering the
  corridor funnel); debug GRANT extended (coil, 7.62mm).

### Changed

- **TurretGun refactor**: the shared gun core (WeaponData hitscan, local
  magazine, cooldown, Inventory resupply) moved out of AutoTurret into a
  `TurretGun` base; the sentry keeps its never-waste-a-round targeting, the
  MG gets always-spend trigger semantics — one `try_fire` serves both.
- Project version to 0.5.1.

### Verified

- Built the MG (prompt costed 5/5 + 1/1, parts consumed); E mounted: viewport
  camera switched to the turret rig, held-W moved the player zero meters,
  aim clamps pinned at exactly −60°/+60° under massive synthetic mouse input,
  R moved 150 rounds Inventory→mag (7.62 pool 300→150), sustained fire spent
  61 rounds while aimed at the clamp (misses cost ammo), a re-centered burst
  killed a zombie crossing the lane, and E dismounted — camera and movement
  restored, prompt ray resumed. Sidearm 9mm pool untouched throughout
  (caliber separation).
- A zombie melee'd the mounted player once god-mode dropped and killed them:
  death force-dismounted cleanly — the game-over overlay rendered from the
  player camera with the Sterling re-announced on the HUD.
- Trap: built for exactly 3 scrap + 2 coils; activation burst-killed the
  wave zombie standing in the zone and the round cleared to PREP on that
  kill (trap kills advance rounds); "already inside at activation" burst
  path confirmed; E during ACTIVE/COOLDOWN refused (state and timer
  unchanged, prompt live-counting the recharge 10→1 s); state lamp/label
  cycled READY → LIVE → RECHARGING.
- Emergent and kept: buildables aren't in the navmesh, so enemies jam
  against a turret's face — it barricades its own front and has a real
  dead-zone below its pitch clamp (attackers can hug the base).

## [0.5.0] — 2026-07-10

### Added

- **Items & Inventory** (DESIGN_DOC §4): `ItemResource` (.tres under
  resources/items/ — 9mm ammo, scrap, servo) and the `Inventory` autoload — one
  bag of id→count with add/consume/count/has/reset, an id→item registry for
  UI names, and `inventory_changed` on every mutation.
- **Ammo unification**: `WeaponData.ammo_type` names the caliber; a weapon's
  reserve now IS the Inventory's count of that caliber. Reloads consume from
  the shared pool; run start seeds it (player resets + reseeds the Inventory,
  mirroring the enemy-pool restart hygiene).
- **Interaction system**: `interact` action (E), physics layer 4
  "interactable", and a duck-typed Interactable contract
  (`interact(player)` / `get_interact_prompt()`) probed by a short
  camera-center ray; prompts stream to the HUD via
  `interact_prompt_changed` and refresh live as costs/counts change.
- **Pickups**: spinning labeled world items on the interactable layer (never
  block movement); E adds to the Inventory, emits `resource_picked_up`, and
  removes the pickup. Scrap/servo/9mm placed through the greybox.
- **Building foundation**: `BuildRecipe` .tres (inputs + scene),
  `BuildSpot` fixed locations (ghost + costed prompt flagging missing parts,
  consume-and-instance on E, EMPTY again on scene reload), and the
  invulnerable solid `Buildable` base.
- **Auto turret** — first craftable (4 scrap + 1 servo): WeaponData-driven
  sentry (turret_smg.tres, 9mm) with a local 120-round magazine that starts
  empty. Targets the nearest live enemy inside its detection sphere, fires the
  same `take_hit` hitscan contract as the player's gun (weak points included),
  holds fire on walls and corpses, idles when empty, and resupplies via E from
  the SAME 9mm pool the player's Sterling reloads from.
- HUD: scavenged-supplies readout, interaction prompt under the crosshair,
  and the reserve counter now tracks the shared ammo pool live.
- Debug: GRANT PARTS panel button (+`DebugManager.grant_supplies`), gated
  behind the debug flag like everything else.

### Changed

- `Weapon.reserve` (local var) replaced by `reserve()` reading the Inventory.
- EventBus: `inventory_changed`, `interact_prompt_changed` added;
  `resource_picked_up` is now live.
- Project version to 0.5.0.

### Verified

- E-pickup: prompt "E: Take Scrap ×2" from the real ray → bag scrap=2, HUD
  supplies update; run-start seed put exactly 120 9mm in the bag.
- Build gate: prompt flagged "Scrap 2/4, Servo 0/1", E refused (no turret, no
  consumption); after GRANT the prompt live-updated to 4/4 1/1 and E built the
  turret, consuming exactly 4 scrap + 1 servo — and the ray seamlessly began
  returning the built turret's resupply prompt.
- Resupply moved 120 rounds bag→turret (bag 240→120); a spawned zombie died to
  exactly six 10-damage turret rounds (120→114 on the live status label) and
  the turret held fire afterward with ammo remaining.
- Crossover: reloading the Sterling pulled 11 rounds from the same pool
  (mag 19→30, 9mm 120→109) — turret rounds are rounds the sidearm can't fire.
- Invulnerability: 11 player rounds point-blank left the turret untouched.
- Death → restart: bag wiped and reseeded (scrap 0, servo 0, 9mm 120), turret
  gone, pickups restored; with the debug flag off, grant is inert.

## [0.4.2] — 2026-07-10

> Off-roadmap movement work — not a DESIGN_DOC §12 milestone. Versioned as a
> patch to keep minor versions aligned with the roadmap.

### Added

- **Bunny hopping**: airborne movement switched from clamped `move_toward` to
  Quake/Source-style air accelerate — only the velocity component along the
  wish direction is capped (small `air_speed_cap`), so strafe + same-direction
  mouse turn builds speed while holding W straight gains nothing. Hard
  horizontal ceiling at `walk_speed × bhop_speed_cap_mult` (9.9 m/s default,
  ~40% over sprint). Grounded movement is unchanged and doubles as friction:
  land without re-jumping and speed bleeds back to walk/sprint.
- **Autohop + manual tap, both live**: held jump re-hops on every landing at
  the base air accel; a fresh press (jump-buffered ~0.1 s, honored on the
  landing frame) earns a faster air accel for that whole hop — rhythmic
  re-tapping reaches the same cap in fewer hops. Walking off a ledge without
  jumping falls at the base accel. All tuning exported on the player.
- **Crouch jumping**: jumping while crouched is allowed; ducking while
  airborne re-anchors the capsule to its top so the feet tuck up by
  (stand − crouch) ≈ 0.6 m — enough to mount ledges a normal jump can't. No
  extra jump velocity: the benefit is purely the tuck. Landing while tucked
  lifts the body origin so the feet (and eye line) stay continuous, then
  stands up only with headroom, per the existing check.

### Changed

- A hop that starts below run speed still receives ground acceleration on the
  hop frame, so holding jump from a standstill accelerates toward walk speed
  instead of pogoing at air-cap speed; at or above run speed the hop frame
  skips ground friction entirely (the momentum carry that makes bhop work).
- Removed the now-dead `air_control` export (superseded by air accelerate).
- Project version to 0.4.2.

### Verified

- Ground feel unchanged: walk 4.50, sprint 6.97, crouch multiplier intact.
- Straight-W autohop never exceeded the 0.7 m/s air wish cap (no free speed);
  strafe+turn autohop built 6.97 → 9.83 peak; manual-tap built faster at every
  sample (7.89 vs 7.08 at t=2) and hit the 9.90 cap by hop 5; no pattern ever
  exceeded 9.90 (the exact configured ceiling).
- A missed hop bled 9.83 → 4.50 within a second of grounded running.
- Standstill held-jump climbed 0.70 → 4.03 across six hops (pogo-lock fixed).
- Against a 1.35 m test ledge: normal jump bounced off the face; crouch-jump
  mounted it and stood up on top at exactly ledge height with no ejection
  (verified with a runtime-spawned platform; a 1.1 m greybox wall turned out
  to be mountable by a plain jump within physics tolerance, so it can't
  differentiate).

## [0.4.1] — 2026-07-09

### Fixed

- A round could be declared cleared while a live debug-spawned zombie was
  still on the field (debug spawns are intentionally untracked, so they didn't
  block round-clear). The clear is now gated on the field being free of *live*
  enemies (`EnemyPool.has_live_enemies()`, which excludes corpses in their
  death animation), and the clear condition is re-evaluated on every enemy
  death — tracked or not — so the deferred clear fires the moment the last
  live enemy dies.

### Verified

- Killing a full round wave with a debug zombie still chasing defers the clear
  (phase stays ROUND, tracked=0, live=true); killing that zombie closes the
  round synchronously on the killing blow; a plain round with no debug spawns
  still clears exactly on its last kill (spawned=budget, no added delay);
  a lingering corpse (pool active=1, live=false) does not block the clear;
  wave-end still resets to a zeroed, empty state.

## [0.4.0] — 2026-07-09

### Added

- **Round lifecycle** (`RoundManager`, DESIGN_DOC §3): ROUND phase feeds the
  field from `EnemyPool` on a spawn interval up to a concurrency cap, topping
  up as enemies die; when the round's whole budget has spawned and died it
  emits `round_cleared`, runs a PREP timer, then bumps the round and emits
  `round_started`. RoundManager is now the sole writer of
  `GameState.round_number` / `GameState.phase`.
- **Data-driven tuning**: `RoundConfig` Resource (starting budget, growth,
  max concurrent, spawn interval, prep duration, rounds per map) authored as
  `resources/rounds/greybox_rounds.tres` — a new map is a new .tres, not code.
- **Round spawn markers**: `enemy_spawn_point` group in the greybox (rooms A/B
  + corridor), outside the NavigationRegion geometry subtree per the nav rule.
- **Debug WAVE button is live**: start begins a fresh run at round 1; end stops
  the loop and clears the field. Rounds never auto-start on load — the greybox
  stays a free-fire range until the button is shot.
- **Map end seam**: clearing `rounds_per_map` stops the loop, logs the boss
  hand-off placeholder, and emits the new `EventBus.map_cleared` (boss consumes
  it in v0.9.0 — not built now).
- Raw HUD round readout (top center): ROUND n / cleared–prep / map cleared,
  driven purely by EventBus.

### Changed

- Player death now also resets RoundManager (timers stopped, counters zeroed)
  and resyncs the WAVE button, so ENTER-restart plus one button press begins a
  clean run at round 1.
- Debug wave signals are no longer stubs — RoundManager consumes them.
- Project version to 0.4.0.

### Verified

- Round 1 spawned exactly its budget and stopped; concurrent alive never
  exceeded max_concurrent (2-cap test: budget 4 held at 2 alive, deaths topped
  up instantly to exactly 4 total); the round cleared only after the last
  enemy died; the prep timer gated round 2; budget grew per config (2→4→6);
  map end fired after rounds_per_map with the loop halted; WAVE stopped
  mid-round and cleared the field (round 0, empty pool); player death mid-round
  zeroed all counters and, after restart, a single WAVE press started a fresh
  round 1. Shipped greybox .tres (6/+4, cap 24, 0.8s, 10s prep, 5 rounds)
  loads and reports correctly.

## [0.3.0] — 2026-07-09

### Added

- **First enemy**: `Enemy` base class (health, weak-point/headshot bonus damage
  via per-shape hit resolution, `die()`, pooling `reset()`/`deactivate()`
  contract, animation-LOD hook) with `ZombieWalker` as the first subclass.
- **Enemy model**: KayKit *Character Pack: Skeletons* minion (CC0) with bundled
  walk/attack/death animations, driven by an `AnimationTree` state machine
  (locomotion → attack → death). Substituted for Mixamo (which needs an
  interactive Adobe login) with identical wiring — swapping models later is a
  scene-only change. License ships alongside the model.
- **Enemy AI**: Spawning → Chasing → Attacking → Dead state machine; melee damage
  lands on the swing's contact frame; enemies face their movement/target.
- **Navigation**: `NavigationRegion3D` with runtime bake over the whole greybox;
  `EnemyNavManager` autoload staggers path updates (fixed budget per physics
  tick, round-robin) so enemies never repath per-frame.
- **`EnemyPool`** autoload: enemies are instantiated once and recycled — no
  instantiate/free in the combat loop; hard cap of 50; survives scene reloads.
- **Live player health**: `Player.take_damage`, HUD updates on every hit, death
  at zero HP with a freeze + "YOU DIED" overlay and ENTER-to-restart.
- **Debug system** (strippable via one flag + auto-disabled in release builds):
  `DebugManager` autoload with `infinite_ammo` / `infinite_health` /
  `show_enemy_health` flags and spawn/door/wave functions; an in-world panel of
  seven shootable buttons with lit on/off lamps (spawn 1, spawn 10, the three
  toggles, sliding debug door, wave-request stub that only emits
  `debug_wave_start/end_requested`); per-enemy floating health readouts; a big
  empty debug room behind the door for horde stress tests.
- **EventBus**: `player_died`, `debug_wave_start_requested`,
  `debug_wave_end_requested`; `enemy_died` is now live.
- Named physics layers: world (1), player (2), enemy (3).

### Changed

- `take_hit` contract gains a `shape_index` parameter so multi-shape bodies
  (enemy head vs body) can resolve weak points; all implementers updated.
- Player moved to physics layer 2 (mask: world + enemies).
- Project version to 0.3.0.

### Verified

- Zombie paths from the debug room through three doorways to the player around
  obstacles; 20-enemy horde stress test; body shot 60→48 vs headshot 48→24
  (exact 2× weak-point math); 11 kills by live gunfire returned to the pool with
  zero leaks (total stayed 20 across kills, deaths, and a scene restart);
  disabling the debug flag removes the panel and inerts every debug effect.

## [0.2.0] — 2026-07-08

### Added

- **Project setup**: Godot 4.7 project configured for 3D FPS — Forward+ renderer,
  Jolt physics, input map (WASD move, mouse look, Shift sprint, Ctrl crouch, Space
  jump, LMB fire, R reload), main scene, project version.
- **Folder structure** per CODE_GUIDE.md: `autoload/`, `player/`, `weapons/`,
  `world/`, `ui/`, `resources/`.
- **Autoload stubs** (DESIGN_DOC §8.1): `EventBus` with all §8.3 signals declared
  (future-milestone signals annotated), `GameState` run-state shell, plus empty
  `RoundManager`, `Inventory`, `CraftingSystem`, `PerkManager` shells.
- **FPS controller** (`player/`): CharacterBody3D with walk, sprint, crouch (with
  headroom check), jump, gravity, clamped mouse-look; all tuning via exported vars;
  camera recoil driven by the weapon's `fired` signal.
- **Weapon system** (`weapons/`): `Weapon` base class (ammo + reserve tracking,
  fire-rate limiting, reload timing, auto-reload on empty trigger, EventBus
  announcements) and `HitscanWeapon` subclass (camera-center raycast with spread,
  range, muzzle flash + light, viewmodel kick, pooled impact effects with spark
  burst + fading scorch decal, per-shot audio). Placeholder gunshot/reload/dry/impact
  sounds synthesized at runtime (`placeholder_sfx.gd`) — zero binary audio assets.
- **First weapon as data**: `WeaponData` Resource schema + `resources/weapons/sterling_9mm.tres`
  (mid-range 9mm automatic — damage, fire rate, mag, reserve, reload time, spread,
  range, recoil all data-driven).
- **Greybox test space** (`world/greybox.tscn`): two rooms joined by a corridor
  (CSG with collision), crates, pillars, chest-high cover; four self-resetting
  shooting targets that flash on hit and topple when depleted.
- **KFMod lighting starter** (DESIGN_DOC §7): WorldEnvironment with heavy cool
  depth + volumetric fog, low cool ambient, Filmic tonemap (low white point),
  desaturated/contrast-bumped adjustments, restrained glow, light SSAO; three
  sparse warm pooled OmniLights; the corridor light is destructible — shooting it
  kills it permanently (sparks + darkness); fullscreen film-grain + vignette
  post overlay (`ui/film_grain.gdshader`).
- **Placeholder HUD** (`ui/`): health value, weapon name, ammo/reserve readout,
  reload indicator, crosshair, and a reserved bottom-left perk-slot region —
  updates exclusively via EventBus signals.
- **Docs**: initialized `CODE_GUIDE.md`; this changelog.

## [0.1.0] — design only

- `DESIGN_DOC.md`: concept, pillars, locked decisions, economy/perk design,
  architecture, KFMod aesthetic direction, scope firewall, milestone roadmap.
