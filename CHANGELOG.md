# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/); versioning is
semantic (pre-1.0: minor = milestone, patch = fixes within it). See DESIGN_DOC §12
for the milestone roadmap.

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
