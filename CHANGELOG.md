# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/); versioning is
semantic (pre-1.0: minor = milestone, patch = fixes within it). See DESIGN_DOC §12
for the milestone roadmap.

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
