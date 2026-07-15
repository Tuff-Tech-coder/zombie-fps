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
  world + interactable layers. Note: buildables are NOT in the navmesh (built
  after the runtime bake), so enemies path through their space and get
  physically blocked — emergent barricading, kept on purpose.
- **`TurretGun`** (v0.5.1) sits between `Buildable` and the two turrets: the
  WeaponData hitscan, local magazine (`loaded_ammo`/`capacity`), cooldown, and
  `reload_from_inventory()` resupply live here. `try_fire(aim_point,
  require_enemy_hit)` is the one trigger: with the flag, a round is spent only
  if the first hit is an enemy (`AutoTurret` — never wastes ammo on walls);
  without it, pulling the trigger always costs the round (`ManualTurret`).
  Scene contract via unique names: `%Muzzle`, `%Flash`, `%FlashTimer`,
  `%FireAudio`, `%StatusLabel` (remember: `unique_name_in_owner = true` is a
  property line in .tscn, not a node-header attribute).
- **Mount contract** (v0.5.1): `Player.enter_mount(turret)` /
  `Player.exit_mount()` own the player side (park at the turret's `Mount`
  marker, suppress ALL player input paths — look, movement, fire/reload,
  interact ray — but `take_damage` stays live: rooted + exposed is the
  trade). The turret side is `on_mounted(player)` / `on_dismounted()` —
  camera switch, HUD announce (`weapon_equipped` + `ammo_changed`), and
  mounted input (mouse aim within clamps, LMB fire, R reload, E dismount).
  A ~0.25 s input grace after mounting stops the same E press from
  mounting and dismounting in one go (a press edge fires in both the
  player's idle frame and the turret's physics frame). `Player._die()`
  force-exits the mount before emitting `player_died` so game-over never
  renders through the turret camera.
- **`ElectricTrap`** (v0.5.1): IDLE → ACTIVE → COOLDOWN state machine on an
  enemy-masked Area3D zone. Damage is environmental via
  `enemy.take_damage(amount)` (no weak point): a one-time burst per enemy per
  activation (on entry, and to anyone inside at activation) plus a DoT tick
  while they remain. Weak enemies die to the burst, tanky ones bleed — the
  split falls out of health, so wave scaling needs no trap rework. Kills flow
  through `die()` → `enemy_died`, so they advance rounds with zero special
  handling. `interact()` only fires from IDLE; the prompt live-counts the
  recharge.

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
- **Scene contract** (see `zombie_walker.tscn`): `Visual` (an `EnemyVisual` —
  see Horde architecture below — owning the `Model`), `NavigationAgent3D`,
  `HeadShape`, `HealthLabel`. The `Enemy` base speaks intent to `$Visual`
  (`play_locomotion/attack/death`, `reset_visual`, `set_lod_level`) and **never
  touches `anim_tree`/`_playback` directly** — that seam makes the final-model
  swap a resource swap. The weak-point/head colliders stay on the physics body
  (mesh-independent).
- **AI state machine**: `SPAWNING → CHASING → ATTACKING → DEAD` enum in the base.
  Attack damage lands at `attack_hit_time` into the swing, only if the player is
  still in reach.
- **Staggered navigation**: `EnemyNavManager` (autoload) is the *only* writer of
  `agent.target_position`, repathing `UPDATES_PER_TICK` enemies per physics tick
  round-robin. Enemies read `get_next_path_position()` but never set targets.
- **`EnemyPool`** (autoload): `acquire(pos)` / `release(enemy)`, hard cap
  `MAX_ENEMIES = 50` (DESIGN_DOC §3). Pooled nodes live under the autoload and
  survive scene reloads — restart paths must call `release_all()`.
- Collision layers: 1 = world, 2 = player, 3 = enemy, 4 = interactable. Weapon
  rays exclude the wielder and hit everything else.

## Horde architecture — the enemy visual seam (Phase 1)

The zombie models are placeholders; the final rigs differ substantially, and
skeletal animation is the dominant per-enemy cost. So the `Enemy` base is
decoupled from its visual/rig behind **`EnemyVisual`** (`enemies/enemy_visual.gd`,
the scene's `Visual` node), and swapping the whole rig is a resource-only change.

- **Intent API** (all the base may call): `play_locomotion()`, `play_attack()`,
  `play_death()`, `reset_visual()` (pool re-activation), `set_lod_level(level, hz)`.
- **The AnimationTree is built in code**, not authored per-scene: `EnemyVisual`
  constructs a 3-state machine (`locomotion`/`attack`/`death`) at runtime from
  three exported `StringName` clip names, and resolves the `AnimationPlayer`
  inside the `Model` at runtime (never hardcode its internal path). A new humanoid
  is: point `Model` at the new GLB, set the three clip names — **zero `enemy.gd`
  edits** (verified by swapping to a sibling KayKit rig).
- **Adding an enemy type without blowing the budget**: reuse this seam (new scene,
  new `Model` GLB + clip names, subclass `Enemy` only if behavior differs); fit
  `MODEL_BUDGET.md`; keep to one material; it registers with the pool and managers
  for free through the base. Do not re-author an AnimationTree in the scene.
- **Two rig modes**, switched by whether `EnemyVisual.animation_library` is set:
  - *Bundled* (current KayKit): clips live on the model's own AnimationPlayer,
    referenced by bare name (`&"Walking_D_Skeletons"` etc.).
  - *Retargeted* (final models): a shared retargeted `AnimationLibrary` is injected
    at bind time and clips use the `"shared/Clip"` form. **Import checklist** for a
    retargeted humanoid GLB: in the GLB's Import dock set
    `import_as_skeleton_bones = true`, assign a **BoneMap** built against
    `SkeletonProfileHumanoid`, reimport; author the shared library once (retarget a
    clip set through the same profile) and assign it to `animation_library`. One
    library then drives every humanoid rig. (Current placeholder uses bundled mode;
    `Skeleton_Minion.glb.import` intentionally has `import_as_skeleton_bones=false`.)

### Animation-LOD framework (Phase 2)

Skeletal animation is the dominant per-enemy cost, so **`AnimationLODManager`**
(autoload, `enemies/animation_lod_manager.gd`) throttles it by distance +
on-screen visibility. Decisions live in the manager; *execution* lives in
`EnemyVisual.set_lod_level(level, hz)`.

- **Levels** (`EnemyVisual.LOD`): `FULL` (AnimationTree engine-ticked every
  frame) → `REDUCED` (tree inactive; manually `advance()`d at `reduced_update_hz`)
  → `PAUSED` (frozen pose) → `CULLED` (frozen + Model hidden, opt-in).
- **Pattern = EnemyNavManager's**: enemies `register()` in `reset()` and
  `unregister()` in `deactivate()` — **not** `die()`, so a corpse's death
  animation stays LOD-managed until it actually pools. Only
  `evaluations_per_tick` enemies are re-evaluated per physics tick, round-robin
  (staggered, never the whole population in one frame).
- **Decision**: distance-to-camera picks a base band; out-of-frustum demotes by
  `offscreen_demotion` levels; **hysteresis** makes band edges sticky (an enemy
  hovering on a boundary keeps its level until it crosses by the margin) so the
  level never flip-flops. `level_counts()` feeds the Phase 4 perf overlay.
- **Every threshold is in `LODConfig`** (`enemies/lod_config.gd` →
  `resources/config/lod_config.tres`) — distance bands, update rates,
  hysteresis, demotion, cull/background flags. **All defaults are placeholders**
  (commented as such); the real numbers come from PROFILING_PLAYBOOK.md against
  the final rigs. No LOD number ever lives in a method body.
- **Background-crowd tier** (DESIGN_DOC §8.4) is a **hook only**:
  `background_tier_enabled` (default false) + the empty
  `_hand_off_to_background()` seam. Whether a MultiMesh tier is ever built is a
  post-profiling decision; nothing implements or requires it.

### Spawn/AI director & group behavior (Phase 3)

Round pacing and enemy placement are split across three owners — keep the
division exactly:

- **`RoundManager`** owns the round **lifecycle**: budget, spawn timer,
  death top-up, the round-clear gate, and `GameState` phase/round writes.
  Its spawn timer is one-shot and re-armed after every spawn attempt, so
  the interval below is re-read spawn-by-spawn. It exposes
  `round_progress()` / `live_count()` as the read API.
- **`SpawnDirector`** (autoload) **answers questions and never spawns**:
  `next_spawn_position()` (scores `enemy_spawn_point` markers — frustum
  and min-distance rejection, behind-the-player and preferred-range
  scoring, cohort-burst marker stickiness, and a never-stall fallback to
  the least-visible marker), `current_spawn_interval()` and
  `current_concurrency_ceiling()` (both mapped from an authored pressure
  `Curve` sampled at `RoundManager.round_progress()`; the ceiling scales
  *within* `RoundConfig.max_concurrent` and is hard-clamped to the pool's
  50). It keeps no parallel counters.
- **`EnemyNavManager`** owns **targets + group math** and stays the ONLY
  writer of `agent.target_position`: stable per-enemy slot indices drive a
  surround ring near the player (per-slot angles at melee reach — the
  anti-stack) and lateral flank offsets for a configured fraction of slots.
  It also applies the RVO params to agents at registration —
  `avoidance_enabled` ships **false** (measured ~17 ms physics at a
  50-agent jam vs ~3.75 ms off; PROFILING_PLAYBOOK #4 is the gate), and
  `agent.max_speed` is capped at the enemy's `move_speed` so RVO can never
  fling packed bodies. When avoidance is off the enemy movement step is
  the plain direct path; when on, chase velocity routes through
  `agent.set_velocity()` → `velocity_computed`.

Every knob for all of the above lives in **`DirectorConfig`**
(`autoload/director_config.gd` → `resources/config/greybox_director.tres`,
all placeholder defaults). A new map's pacing/placement feel is a new
director `.tres`, not code. Registration/queries are direct calls per the
established manager precedent — no new EventBus signals
(`director_pressure_changed` stays unproposed until something listens).

### Why each horde knob exists

- `evaluations_per_tick` — trades LOD responsiveness against per-tick cost;
  the stagger keeps the manager itself off the frame-time hot path at 50 agents.
- distance bands (`full`/`reduced`/`paused_distance`) — the core cost curve:
  animate what the player can actually see and judge; freeze what they can't.
- `hysteresis` — kills level flicker at boundaries (visible popping otherwise).
- `offscreen_demotion` — off-screen skeletal work is nearly pure waste, so it's
  demoted hardest; separated from distance so the two can be tuned independently.
- `reduced_update_hz` — the single biggest lever on mid-distance cost; low
  enough to save frames, high enough that re-entering view doesn't visibly snap.
- `cull_visuals` / `background_tier_enabled` — escalation seams held in reserve
  for when profiling proves the frozen-pose tier isn't cheap enough.
- `min_spawn_distance` / frustum rejection — spawns the player can watch pop
  in break the dread pillar; the never-stall fallback exists because a round
  that can't place is worse than one visible spawn.
- `pressure_curve` + `interval_relaxed/peak` + `concurrent_floor_fraction` —
  the whole difficulty ramp as one authored curve; flat 0.5 = the exact
  pre-director pacing, so feel changes are always a data diff.
- `burst_size_range` / `burst_marker_stickiness` — cohorts arriving together
  is what makes funneling emerge from placement alone (no nav code).
- `ring_radius` / `ring_spacing_degrees` / `ring_target_radius` — fan-out at
  melee range instead of a one-pixel stack; the target radius must stay
  inside `Enemy.attack_range` or arrivals hold formation without swinging.
- `flank_fraction` / `flank_distance` — a few approach vectors off the
  straight line read as intent without any real squad AI.
- `avoidance_*` — RVO separation, gated because its cost at a converged
  50-agent jam is measured in whole milliseconds (see PROFILING_PLAYBOOK #4).

### Profiling & budgets (Phase 4)

- The **perf overlay** (`ui/perf_overlay.gd/.tscn`) is a read-only debug
  fixture: Performance monitors + `EnemyPool.active_count()` +
  `AnimationLODManager.level_counts()`. It lives inside `debug_panel.tscn`,
  is toggled by the shootable **PERF** button through
  `DebugManager.show_perf_overlay`, and strips with the debug flag like the
  rest of the panel. No gameplay script references it.
- **`MODEL_BUDGET.md`** (repo root) is the per-enemy asset ceiling (bones,
  tris, materials, clips) for the v0.8.0 art pass — check candidates against
  it *before* import work; fix the asset, never widen the budget.
- **`PROFILING_PLAYBOOK.md`** (repo root) is the ordered measurement pass
  that turns every placeholder in `lod_config.tres` and
  `greybox_director.tres` into a measured number. Re-run it after any rig
  swap or horde-system change.

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

## Perks & crafting (v0.6.0)

- **`Perk`** (`autoload/perk.gd`, .tres under `resources/perks/`): id, name,
  delivery (INGESTIBLE/ATTACHABLE; MACHINE reserved), trigger (PASSIVE /
  ON_RELOAD / ON_HIT / ON_KILL / ON_DEATH), tier (BENCH/LAB), plus the effect.
  Perks are doses — syringes, bottles, food — never machinery.
  Two effect shapes:
  · **Stat perks are pure data**: `stat` + `multiplier`. Gameplay multiplies
    its base by `PerkManager.get_multiplier(&"stat")` at the point of use —
    the read points are player `_current_speed` (move_speed), weapon fire
    cooldown (fire_rate) and hitscan spread (spread). One read per stat,
    mirroring the DebugManager one-check rule. A new stat perk is a .tres.
  · **Scripted perks** name an `effect_script` (a Node) + `params` dict;
    PerkManager attaches it while active (Electric Cherry hooks
    `weapon_reload_started`, which now carries mag/mag_size for emptiness
    scaling). Detach = node freed on remove.
- **`PerkManager`** (autoload): `MAX_PERKS = 4`; apply (refuses full or
  duplicate — the caller consumes the dose only on success), remove (perks
  are swappable), clear_all, get_multiplier, `perks_changed` on any change.
  Doses live in the Inventory under the perk's id; their ItemResources are
  synthesized at boot.
- **`CraftingSystem`** (autoload — DESIGN_DOC §8.1's formula resolver):
  PerkRecipe registry, `match_recipe(mix, tier)` (exact multiset, recipes of
  required_tier ≤ the station's tier), `craft` (consume → dose → 
  `perk_crafted`), and run-scoped `revealed` recipe ids from notes.
- **Stations**: `CraftingStation` (tier BENCH/LAB) opens the combine UI on E.
  The bench is pre-placed scenery; the lab is a buildable (BuildRecipe) and
  its formulas may need **heated** compounds — the `Burner` buildable converts
  input→output compound (e.g. cherry extract → concentrate). Lab recipes
  refuse to match at a bench, indistinguishably from a wrong guess.
- **Combine-and-validate, no browser**: the UI shows compounds, you build a
  mix, Combine either crafts or reads "unstable" (nothing consumed —
  the failed mix stays for adjustment). Veterans craft from memory;
  a `RecipeNote` pickup reveals one formula in the UI **for the run only**
  (never a persistent unlock — §11). HUD perk chips fill per active perk and
  all gain the gold border at the cap (§4.2).
- Enemies now have `stun(duration)` — a brief full-body freeze used by
  electric effects; the AI resumes where it left off.

## Navigation

- The greybox navmesh is **baked at runtime** (`world/nav_region.gd`) because the
  CSG layout still changes every milestone. Only children of the
  `NavigationRegion3D` (the `Geometry` tree) are parsed — keep doors, targets,
  panels, and other dynamic objects *outside* that subtree so they don't carve
  the mesh.
- **Dressed maps pre-bake** (v0.8.0): the city ships a saved
  `NavigationMesh` resource (`world/city/city_navmesh.res`) baked once from
  an invisible collision/nav **proxy** (`Geometry/Proxy`, a StaticBody3D of
  plain box shapes for floors/walls/ramps/prop blockers) — no bake at load.
  All visual dressing lives under a separate `Visuals` tree outside
  `Geometry`. Rebaking after a proxy change: run the scene once with
  `nav_region.gd` temporarily attached (or bake in-editor) and save the
  resource back over the `.res`.
- **Nav-critical dimensions** (measured, v0.8.0): with `agent_radius 0.45` /
  `agent_height 2.0` and default 0.25 cells, doorways must be ≥ **1.8 m wide
  and 2.4 m tall** or the voxelized bake disconnects them (2.1 m doors are a
  rounding coin flip). Walkable ramps (stairs) must have their open sides
  walled to full height — otherwise the bake connects the ramp to the floor
  across its low side edge, a shortcut `CharacterBody3D` cannot climb, and
  enemies wedge there. Fatten inside corners at ramp exits (e.g. a newel
  post) so path corners keep clearance.

## Scenes

- One scene per entity; the script is attached at the scene root; the root node is
  the entity's class (`Player` → `CharacterBody3D`, targets → `StaticBody3D`).
- Levels instance entity scenes; they don't rebuild them from nodes.
- Greybox geometry uses `CSGBox3D` with `use_collision = true` — fine for greybox,
  to be replaced in the art pass (v0.8.0), never in shipped dressed maps.
- Dressed maps (v0.8.0, `world/city/city.tscn`) contain **no CSG**: collision
  is the `Geometry/Proxy` StaticBody3D (also the nav bake source, see
  Navigation), visuals are plain `MeshInstance3D` primitives + MultiMeshes
  under `Visuals/`, with proxy and visual surfaces authored to coincide so
  bullet impacts land on the visible faces.

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
