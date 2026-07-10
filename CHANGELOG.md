# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/); versioning is
semantic (pre-1.0: minor = milestone, patch = fixes within it). See DESIGN_DOC §12
for the milestone roadmap.

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
