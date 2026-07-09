# Design Doc — Wave-Survival FPS (working title: TBD)

> **Purpose of this file:** the single canonical reference for the project. Read this first, every session, before writing code. It defines *what the game is* and *how it is architected* so implementation briefs can stay small. When a brief and this doc conflict, this doc wins unless the brief explicitly supersedes a section.

**Status:** pre-production · **Version:** 0.1.0 (design only) · **Engine:** Godot 4.x · **Language:** GDScript · **Target:** PC, keyboard + mouse, single-player

---

## 1. Concept & pillars

A round-based wave-survival FPS. Call of Duty: Zombies and Killing Floor for the gameplay loop; **KFMod** (the original 2005–2008 Unreal Tournament 2004 total conversion, early/gritty era) for the aesthetic. Deliberately small in scope: a few maps, a compact arsenal.

**Pillars (every decision serves these):**

1. **Scavenge, don't shop.** There is no points or cash currency. Power comes from what you find, craft, and build.
2. **Dread over spectacle.** Dark, grimy, oppressive British industrial-horror. Atmosphere carries the game, not fidelity.
3. **Small and finishable.** Scope is a feature. The firewall list in §11 is binding.

---

## 2. Locked decisions

| Decision | Value | Notes |
|---|---|---|
| Engine | Godot 4.x, GDScript | Stay in the existing Claude Code + Godot MCP toolchain |
| Platform | PC, keyboard/mouse | No controller/mobile scope |
| Players | Single-player only | **No netcode.** This is the biggest scope firewall |
| Loop | Round-based, fixed rounds per map, ending in a map-specific boss | Not endless |
| Physics | Jolt (Godot 4.4+ built-in) | Chosen for enemy-count headroom |

---

## 3. Core loop

1. **Round** — a fixed number of simple zombie enemies spawn and attack. Player survives by killing them.
2. **Prep phase** — a timed gap between rounds. Player scavenges the map, crafts, builds traps/defenses, repositions.
3. Repeat for a **set number of rounds per map** (tunable per map).
4. **Boss fight** — each map ends with a **map-specific boss**, designed for that map. Kept deliberately simple: a tougher enemy with one or two special behaviors, not a bullet-hell setpiece.
5. Map complete.

**Enemy population target:** a "few dozen" active at once (design around ~24–40, hard ceiling ~50). This is well inside Godot's comfortable range with the performance patterns in §8. The *feeling* of a horde comes from relentless respawning and funneling through tight spaces — not from hundreds of on-screen bodies. On larger maps (e.g. the planned city map), background density is faked with **static or simple-path models**, never additional active-AI enemies.

---

## 4. Economy — scavenge / craft / build (the distinctive system)

**There is no currency.** No points, no cash, no wall-buys. Everything is scavenged, crafted, or built.

### 4.1 Resources
Chemicals and compounds are scattered around the map and picked up during rounds and the prep phase. These are the raw inputs to crafting. (Weapon upgrade parts, trap materials, etc. are also scavenged.)

### 4.2 Perk crafting
- **Perks are crafted**, not bought. The player collects specific chemicals/compounds and combines them via **formulas** (recipes) into specific perks.
- Perks are **powerful passives** in the CoD: Zombies mold (e.g. movement, damage resistance, weapon handling, etc. — exact roster TBD).
- **Perk limit:** the player can hold a capped number of perks at once. **Tentatively 4** (tunable). When the cap is reached, the perk symbols in the **bottom-left HUD** gain a **colored border** to signal the limit is hit.
- Perks are meant to enable **build/class variety** — the player shapes a playstyle by which perks they craft.

### 4.3 Baseline progression outside perks
- **Max health and reload speed increase through non-perk means** (scavenged/crafted upgrades or round-based baseline growth — mechanism TBD).
- This is intentional: keeping health and reload *off* the perk slots frees the limited perk slots for expressive, build-defining choices instead of mandatory survival stats.

### 4.4 Weapons, traps, builds
Gun upgrades, traps, and other defenses are likewise **scavenged, crafted, or built** during rounds/prep. Same resource-and-formula spirit as perks.

> **Data-driven requirement:** perks, crafting formulas, and pickups must be **`Resource`-based data**, not hardcoded logic. Adding a perk or recipe should mean authoring a new `.tres`, not editing systems. See §8.

---

## 5. Combat & weapons

- First-person, standard FPS movement (walk, sprint, crouch, jump), mouse-look.
- **Compact arsenal** — a handful of guns with distinct roles (e.g. sidearm, shotgun, an automatic). Exact roster TBD; start with one in v0.2.0.
- Each weapon: fire (hitscan or projectile — most start hitscan), reload, ammo, recoil, and clear impact feedback (hit reactions, sound, muzzle flash). **Weapon feel is a first-class concern** — it is the difference between "functional" and "fun."
- Damage model supports weak points (e.g. headshots) for zombies.

---

## 6. Enemies

- **Simple zombies** as the staple: chase the player on the navmesh, melee on contact, die (with weak-point bonus damage). One or two variants max in the vertical slice (e.g. a basic walker and a faster/tankier variant).
- **Bosses:** one per map, map-specific, deliberately simple.
- Enemies are **pooled** and reuse **Mixamo** rigs + animations (walk/run/attack/death).
- **Performance is a design constraint, not an afterthought** — see §8.4.

---

## 7. Aesthetic — KFMod

Target: the early, gritty KFMod look. British industrial-horror *survival*, not arcade action. Grimy, oppressive, claustrophobic — council estates, farms, manors, sewers, hospitals, biotech labs. Low-poly, low-res, UE2.5-era fidelity. **The mood rides on lighting, fog, and color grade — not on polygon count.** This is what makes the game achievable on free assets.

**Concrete Godot starting directions (tune to taste):**

- **`WorldEnvironment`:** low ambient light energy; heavy **fog** (depth + optional volumetric), cool grey-blue tint, high density for short sightlines.
- **Adjustments:** enabled — **desaturated** (~0.6–0.7 saturation), slight contrast bump, brightness slightly down (lifted blacks kept crushed-ish, not milky).
- **Tonemap:** Filmic or AgX with a low white point.
- **Glow/bloom:** restrained and subtle. KFMod is not bloomy — resist the modern-shooter glow.
- **Post:** a **film-grain** pass (shader or `CanvasLayer` overlay) and a subtle vignette.
- **Lighting:** sparse, **pooled** `OmniLight3D`s — dim warm pools against the cool ambient. **Some lights are destructible** (shootable → switch off), and that darkness is part of the tension, not a bug.
- **SSAO:** light, to catch grime in corners. **Shadows:** soft, low-res is fine (fits the low-fi look).

---

## 8. Architecture

Keep systems decoupled via signals. Establish base classes and autoloads *early* so later content is data + subclasses, not new plumbing.

### 8.1 Autoloads (singletons)
- **`EventBus`** — global signal hub; systems emit/listen here to stay decoupled.
- **`GameState`** — run state: current map, round number, phase (round vs. prep), player alive/dead.
- **`RoundManager`** — spawn scheduling, round progression, per-round enemy budget, boss trigger.
- **`Inventory`** — scavenged resources (chemicals/compounds/parts).
- **`CraftingSystem`** — resolves formulas → outputs (perks, upgrades, traps).
- **`PerkManager`** — active perks, the perk-slot cap, applies passive effects.
- **`AudioManager`** — (optional, add when needed).

### 8.2 Base classes / data
- **`Weapon`** (base) → per-gun behavior; hitscan vs. projectile variants. Per-gun config via exported vars or a `WeaponData` `Resource`.
- **`Enemy`** (base, `CharacterBody3D`) → zombie variants and bosses as subclasses.
- **`Perk`** (`Resource`) — data-driven perk definitions (id, name, icon, passive effect params).
- **`CraftingFormula`** (`Resource`) — data-driven recipes (inputs → output).
- **`Pickup`** (base) — scavengeable resources in the world.

### 8.3 Signals-first
Systems communicate through `EventBus` signals (e.g. `enemy_died`, `round_started`, `round_cleared`, `perk_crafted`, `resource_picked_up`), not direct cross-references. This keeps HUD, audio, and progression loosely coupled.

### 8.4 Performance patterns (bake in from the start)
- **Jolt physics** (project setting).
- **Object pooling** for enemies and any projectiles/bullets — no runtime `instantiate`/`queue_free` churn in the hot loop.
- **Staggered navigation:** a manager updates path targets for a *fraction* of enemies per frame; individual enemies do **not** recompute paths every frame.
- **Animation LOD:** pause/simplify skeletal animation for distant or off-screen enemies (skeletal animation is the single biggest per-enemy cost in Godot 4).
- **Background crowd** (city map): static or simple-path/`MultiMesh` models — **no full AI**.

---

## 9. Documentation & versioning standards

- **Semantic versioning.** Pre-1.0 (`0.x.y`): minor `x` = a milestone/feature set, patch `y` = fixes within it.
- **`CHANGELOG.md`** — granular, Keep-a-Changelog style (Added / Changed / Fixed / Removed), updated every milestone.
- **`CODE_GUIDE.md`** — project conventions: naming, node/scene structure, signal patterns, folder layout, resource-authoring rules. Initialized in v0.2.0 and kept current.
- Keep functions small and single-purpose; comment *why*, not *what*.

---

## 10. Asset sources (free stack)

All cross-engine, imports into Godot. **Prefer CC0; verify the license on each asset before shipping.**

- **Enemies + animations:** Mixamo (free, royalty-free; ships embedded in a compiled game).
- **Grimy textures/materials:** ambientCG, Poly Haven, CGBookcase (all CC0 PBR).
- **Props / weapons / modular environment:** Kenney, Quaternius (CC0); itch.io packs (per-asset license).
- **Audio:** Sonniss GDC bundle (royalty-free), Freesound (filter for CC0), Kenney audio (CC0), Pixabay.

---

## 11. Scope firewall — NOT in this project

These are out of scope. Do not build them, do not architect speculatively for them. Flag if a request implies one.

- ❌ Co-op / multiplayer / any netcode
- ❌ More than ~4 enemy types total (across the whole game)
- ❌ Complex, multi-phase bullet-hell bosses
- ❌ Procedural / infinite map generation
- ❌ Meta-progression / persistent unlocks between runs
- ❌ Controller or mobile support
- ❌ A currency/economy of any kind (violates Pillar 1)

---

## 12. Milestone roadmap

Each milestone = one bounded implementation brief. Build in this order; don't skip ahead.

| Version | Milestone |
|---|---|
| **v0.2.0** | Project setup + FPS controller + one hitscan weapon + greybox test space + KFMod lighting starter + placeholder HUD |
| v0.3.0 | First enemy (Mixamo zombie): navmesh chase, melee, damage, death, pooling |
| v0.4.0 | Round/wave manager: prep phase, per-round budgets, spawn scaling |
| v0.5.0 | Scavenge + `Inventory` + first craftable output |
| v0.6.0 | Perk system: formulas, slot cap + HUD border indicator, passive application; health/reload upgrades (outside perks) |
| v0.7.0 | Second weapon + a weapon-upgrade path |
| v0.8.0 | First full map (city): greybox → dressed, with faked background crowd |
| v0.9.0 | Map boss fight |
| **v1.0.0** | Vertical slice complete: one full map, rounds, boss, scavenge/craft economy, ~3 weapons, ~2 enemy types |
