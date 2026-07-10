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
| `enemies/` | `Enemy` base, per-type subclasses, `EnemyPool`/`EnemyNavManager`, imported models under `enemies/models/<name>/` (with their LICENSE) |
| `buildables/` | `Buildable` base + built defenses (auto turret; manual turret/trap in v0.5.1), `BuildRecipe` schema |
| `world/` | Levels (greybox for now) and world objects (targets, lights, pickups, build spots, debug fixtures) |
| `ui/` | HUD, overlays (film grain, game over), future menus |
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
Round pacing follows the same rule: `RoundConfig` (`autoload/round_config.gd`)
instances live in `resources/rounds/` — a new map's rounds are a new .tres that
a map assigns to `RoundManager.config`.
Tuning values that are per-scene rather than per-data-asset (movement speeds, mouse
sensitivity) are `@export` vars on the node — still no magic numbers in method bodies.

## Gameplay contracts

- **Hittable objects** implement
  `take_hit(damage: float, hit_pos: Vector3, normal: Vector3, shape_index: int = 0)`.
  Hitscan weapons duck-type on `has_method("take_hit")` — no registration needed.
  The `shape_index` (from the ray result) lets multi-shape bodies resolve weak
  points; single-shape implementers just ignore it. (`ShootingTarget`,
  `DestructibleLight`, `Enemy`, and `DebugButton` are the implementations.)
- **Pooling (DESIGN_DOC §8.4):** repeated effects/entities are pooled up front and
  recycled — no `instantiate()`/`queue_free()` in hot loops. See the impact-effect
  pool in `weapons/hitscan_weapon.gd` and `enemies/enemy_pool.gd`.
- Weapon subclasses override `_do_fire()`; the `Weapon` base owns ammo, fire-rate
  gating, and reload timing. Optional audio child nodes (`ReloadAudio`, `DryAudio`)
  are picked up by name if present.
- **Damage to the player** goes through `Player.take_damage(amount)` — never write
  `health` directly. It emits `player_health_changed` and handles death.
- **Interactables** (v0.5.0) are duck-typed like hittables: implement
  `interact(player) -> void` and `get_interact_prompt() -> String`, and sit on
  physics layer 4 ("interactable") so the player's short camera ray finds them.
  Prompts are re-read every frame (their text is stateful — costs, counts), and
  reach the HUD via `EventBus.interact_prompt_changed`. Pickups, BuildSpots, and
  buildable resupply are the implementations. Interactable-only bodies (layer 4,
  mask 0) block nothing; buildables add the world layer to be solid.
- **Ammo lives in the Inventory** (v0.5.0): `WeaponData.ammo_type` names an
  ItemResource id (the caliber, e.g. `&"9mm"`); a weapon's reserve IS
  `Inventory.count(ammo_type)`, and turret feeds consume the same pool. Only
  the magazine is weapon-local. `reserve_ammo` means "rounds seeded into the
  Inventory at run start" — the player does the seeding in `_ready` right after
  `Inventory.reset()` (run-owner hygiene, like `EnemyPool.release_all()`).

## Items, Inventory & building (v0.5.0)

- **`ItemResource`** (`autoload/item_resource.gd`): id (StringName; calibers use
  the caliber as id), display_name, icon, category (COMPOUND/PART/AMMO).
  Authored under `resources/items/`; the Inventory autoload loads that folder
  into its id→item registry at boot (pickups also register their item, so a
  new item works even before it's in the folder scan).
- **`Inventory`** (autoload): the single bag of id→count. API: `add`,
  `consume` (clamped, returns success), `count`, `has(inputs)`, `reset()`.
  Every mutation emits `EventBus.inventory_changed(id, count)` — the HUD and
  prompts read counts, never the bag.
- **`BuildRecipe`** (`buildables/build_recipe.gd`): inputs
  (`[{ "id": StringName, "qty": int }]`) + buildable_scene + display_name,
  authored under `resources/recipes/`. A new buildable is a new .tres.
- **`BuildSpot`** (fixed locations only — free placement is firewalled):
  EMPTY shows a ghost + costed prompt; `interact` consumes inputs and instances
  the recipe's scene at the spot, then drops off the interactable layer so the
  built thing takes over the ray. Scene reload = spot back to EMPTY; buildables
  never persist across a run.
- **`Buildable`** base: invulnerable by design (no `take_hit`), solid on
  world + interactable layers. `AutoTurret` is the reference subclass — driven
  by a `WeaponData` .tres, local magazine loaded via interact from the shared
  ammo pool, targets the nearest live enemy in its Area3D, fires with the same
  `take_hit` contract as the player's gun (weak points work for free), never
  wastes rounds on walls or corpses.

## Enemies (v0.3.0)

- **`Enemy` base** (`enemies/enemy.gd`, CharacterBody3D): every zombie variant and
  map boss subclasses it. Load-bearing methods — don't fork their semantics:
  - `take_damage(amount, is_weakpoint)` → applies `weakpoint_multiplier`, triggers `die()`.
  - `take_hit(...)` → maps the ray's `shape_index` to the `HeadShape` node for
    weak-point detection (body capsule is shape 0, head sphere is shape 1).
  - `die()` → death anim, `EventBus.enemy_died`, then **returns itself to the pool**
    after `death_duration`. Never `queue_free`.
  - `reset()` / `deactivate()` → the pooling contract: full restore to combat-ready /
    dormant (invisible, collision off, `PROCESS_MODE_DISABLED`).
- **Scene contract** (see `zombie_walker.tscn`): `Model` (imported scene containing
  an AnimationPlayer — resolved at runtime, never hardcode its internal path),
  `AnimationTree` (state machine with states named `locomotion` / `attack` /
  `death`; code drives it via `playback.start()`, no authored transitions),
  `NavigationAgent3D`, `HeadShape`, `HealthLabel`. Looping anims are listed in the
  exported `loop_animations` (imported GLB animations don't loop by default).
- **AI state machine**: `SPAWNING → CHASING → ATTACKING → DEAD` enum in the base.
  Attack damage lands at `attack_hit_time` into the swing, only if the player is
  still in reach.
- **Staggered navigation**: `EnemyNavManager` (autoload) is the *only* writer of
  `agent.target_position`, repathing `UPDATES_PER_TICK` enemies per physics tick
  round-robin. Enemies read `get_next_path_position()` but never set targets.
- **`EnemyPool`** (autoload): `acquire(pos)` / `release(enemy)`, hard cap
  `MAX_ENEMIES = 50` (DESIGN_DOC §3). Pooled nodes live under the autoload and
  survive scene reloads — restart paths must call `release_all()`.
- **Animation LOD hook**: `set_animation_enabled(on)` exists for the v0.8.0 LOD
  manager; don't add per-enemy animation costs that bypass it.
- Collision layers: 1 = world, 2 = player, 3 = enemy. Weapon rays exclude the
  wielder and hit everything else.

## Debug system (v0.3.0)

- **Everything debug lives in or routes through `DebugManager`** (autoload), gated
  by `DebugManager.is_enabled()` (`DEBUG_ENABLED` const AND `OS.is_debug_build()`).
  Flip the const to false and the panel removes itself, all flags read false, and
  every debug function no-ops.
- Gameplay systems get **at most one guarded check** against DebugManager, at the
  point of effect. Current checks (the complete list — keep it short):
  `Weapon.try_fire` (`infinite_ammo`), `Player.take_damage` (`infinite_health`),
  `Enemy._update_health_label` (`show_enemy_health`).
- The in-world **debug panel** (`world/debug_panel.tscn`, room B east wall) is a row
  of shootable `DebugButton`s — they implement `take_hit` like any target and only
  call DebugManager. Toggle buttons read the returned state and light green (on) /
  dim red (off). New debug behavior = a DebugManager function + a button wired by
  its `action` export, not code scattered in gameplay scripts.
- The **wave button is a stub**: it alternates `EventBus.debug_wave_start_requested`
  / `debug_wave_end_requested` and logs. RoundManager consumes these in v0.4.0.
- The debug room (big empty greybox behind the sliding `DebugDoor`) exists for
  spawn/path stress tests; its door is walkable in the navmesh on purpose (closed
  = physical block only).

## Navigation

- The greybox navmesh is **baked at runtime** (`world/nav_region.gd`) because the
  CSG layout still changes every milestone. Only children of the
  `NavigationRegion3D` (the `Geometry` tree) are parsed — keep doors, targets,
  panels, and other dynamic objects *outside* that subtree so they don't carve
  the mesh.

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
