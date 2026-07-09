# CODE_GUIDE.md — Project Conventions

> Initialized in v0.2.0 per DESIGN_DOC §9. This documents the conventions **actually
> in use** — update it when a convention changes, not speculatively.

## Project layout

The Godot project lives in `zombie-fps/`. Top-level folders:

| Folder | Contents |
|---|---|
| `autoload/` | Singleton scripts registered in Project Settings (EventBus, GameState, …) |
| `player/` | FPS controller scene + script |
| `weapons/` | `Weapon` base, per-type subclasses, weapon scenes, shared weapon FX |
| `world/` | Levels (greybox for now) and world objects (targets, destructible lights) |
| `ui/` | HUD, post-process overlays (film grain), future menus |
| `resources/` | **Data only** — authored `.tres` files, grouped by domain (`resources/weapons/`, later `resources/perks/`, `resources/formulas/`) |

Docs (`DESIGN_DOC.md`, `CODE_GUIDE.md`, `CHANGELOG.md`) live at the repo root, one
level above the Godot project.

## Naming

- Files and folders: `snake_case` (`hitscan_weapon.gd`, `film_grain.gdshader`).
- Classes: `PascalCase` via `class_name` (`HitscanWeapon`, `WeaponData`).
- Autoload scripts have **no** `class_name` — they're addressed by their autoload
  name (`EventBus`, `GameState`).
- Node names: `PascalCase` (`WeaponHolder`, `MuzzleFlash`).
- Signals: past-tense events (`fired`, `ammo_changed`, `round_cleared`).
- Private members and methods: leading underscore (`_cooldown`, `_fire_ray()`).
- Constants: `SCREAMING_SNAKE_CASE`.

## Signals — the EventBus pattern (DESIGN_DOC §8.3)

- **Cross-system events go through `EventBus`** (`autoload/event_bus.gd`). It is a
  pure declaration file: signals only, no logic, ever.
- Emitters don't know their listeners: the weapon emits `EventBus.ammo_changed`;
  the HUD connects to it. The HUD never reaches into player/weapon nodes.
- **Direct signals are allowed only between a parent and its own children**, for
  tightly-coupled mechanics (e.g. `Weapon.fired` → `Player` applies camera recoil).
- Signals for future milestones are declared on EventBus ahead of time (annotated
  with their milestone) so downstream briefs slot in without plumbing changes.
- First-frame broadcasts from `_ready()` are deferred (`call_deferred`) so sibling
  listeners are connected before the first emit.

## Resource-authoring rule (DESIGN_DOC §4)

Gameplay numbers never live in scripts. The pattern:

1. A schema script: `class_name WeaponData extends Resource` with `@export` fields.
2. Authored instances as `.tres` under `resources/<domain>/`
   (e.g. `resources/weapons/sterling_9mm.tres`).
3. Behavior scripts take the resource via an exported var (`@export var data: WeaponData`).

Adding a gun/perk/recipe means authoring a new `.tres`, not editing systems.
Tuning values that are per-scene rather than per-data-asset (movement speeds, mouse
sensitivity) are `@export` vars on the node — still no magic numbers in method bodies.

## Gameplay contracts

- **Hittable objects** implement `take_hit(damage: float, hit_pos: Vector3, normal: Vector3)`.
  Hitscan weapons duck-type on `has_method("take_hit")` — no registration needed.
  (`ShootingTarget` and `DestructibleLight` are the reference implementations.)
- **Pooling (DESIGN_DOC §8.4):** repeated effects/entities are pooled up front and
  recycled — no `instantiate()`/`queue_free()` in hot loops. See the impact-effect
  pool in `weapons/hitscan_weapon.gd`.
- Weapon subclasses override `_do_fire()`; the `Weapon` base owns ammo, fire-rate
  gating, and reload timing. Optional audio child nodes (`ReloadAudio`, `DryAudio`)
  are picked up by name if present.

## Scenes

- One scene per entity; the script is attached at the scene root; the root node is
  the entity's class (`Player` → `CharacterBody3D`, targets → `StaticBody3D`).
- Levels instance entity scenes; they don't rebuild them from nodes.
- Greybox geometry uses `CSGBox3D` with `use_collision = true` — fine for greybox,
  to be replaced in the art pass (v0.8.0), never in shipped dressed maps.

## Placeholders

- Audio is synthesized at load time by `weapons/placeholder_sfx.gd` so the repo
  ships zero binary sound assets pre-art-pass. Replace wholesale during the asset
  pass with sources from DESIGN_DOC §10.
- HUD styling is intentionally raw; the bottom-left `PerkArea` region is reserved
  for the v0.6.0 perk icons.

## Editor / tooling workflow

- The Godot editor is normally open with the godot-ai MCP plugin. **Never hand-edit
  `project.godot` while the editor is running** — the editor overwrites it. Use the
  editor UI (or MCP tools: `autoload_manage`, `input_map_manage`,
  `project_manage settings_set`) for autoloads, input actions, and settings.
- `.tscn`/`.gd` files may be edited as text while the editor is open; trigger a
  filesystem scan afterwards so `class_name` registration updates.
- Gotcha: `Transform3D(...)` in `.tscn` files lists **basis rows**, not axis
  columns — a hand-written rotation that looks right column-wise is transposed.

## Comments & docs

- Comment **why**, not what. A comment that restates the next line gets deleted.
- Keep functions small and single-purpose (DESIGN_DOC §9).
- Semantic versioning, pre-1.0: minor = milestone, patch = fixes within it.
- Every milestone updates `CHANGELOG.md` (Keep-a-Changelog: Added / Changed /
  Fixed / Removed) and bumps `application/config/version`.
