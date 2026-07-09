# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/); versioning is
semantic (pre-1.0: minor = milestone, patch = fixes within it). See DESIGN_DOC §12
for the milestone roadmap.

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
