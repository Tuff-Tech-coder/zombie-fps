# PROFILING_PLAYBOOK — Horde Measurement Procedure (Horde Phase 4)

> The ordered, repeatable procedure that turns every placeholder in
> `resources/config/lod_config.tres` and
> `resources/config/greybox_director.tres` into a **measured** number on the
> target box (RTX 4060 / i5-13600KF, 60 FPS). Run it after any rig swap
> (v0.8.0 art pass) and after any change to the horde systems. Numbers land
> in the `.tres` files — never in code.
>
> Instrumentation: the **PERF debug button** (debug panel, room B east wall)
> toggles the perf overlay — FPS / frame ms / physics ms / draw calls /
> active enemies / LOD level distribution, all read-only taps. The same
> values come from `Performance.get_monitor(...)` for scripted capture.

Run each step in a debug build, in the greybox (or the current map), with a
freshly started game. Record numbers only after they settle (~5 s).

## 1. Baseline (the floor)

- **Do:** empty scene — no wave, no debug spawns. Overlay ON.
- **Read:** FPS, frame ms (`TIME_PROCESS`), physics ms
  (`TIME_PHYSICS_PROCESS`), draw calls
  (`RENDER_TOTAL_DRAW_CALLS_IN_FRAME`).
- **Tunes:** nothing — this is the reference floor every later delta is
  measured against. If the floor alone is near 16.67 ms, stop and fix the
  scene before touching enemy knobs.

## 2. Spawn ramp, LOD forced FULL (the un-optimized cost curve)

- **Do:** in `lod_config.tres`, set the three distance bands huge
  (e.g. 10× map size) so every enemy stays FULL. Debug-spawn **10 → 25 →
  50** (SPAWN 10 button; the debug room holds them). Record at each step.
- **Read:** frame ms and physics ms vs enemy count; draw calls.
- **Tunes:** nothing directly — this is the evidence line. It shows the
  skeletal dominance (frame ms should grow roughly linearly with FULL
  count) and validates/refutes MODEL_BUDGET.md for the current rig. If 50
  × FULL already fits the frame budget, LOD bands can be generous; if not,
  the gap is what steps 3's bands must claw back.

## 3. LOD bands (fills lod_config.tres)

- **Do:** restore `lod_config.tres`. With 50 spawned, sweep one knob at a
  time: `reduced_distance`, `paused_distance`, `reduced_update_hz` (and
  `evaluations_per_tick` if LOD reaction feels laggy). After each change,
  walk toward/away from the horde and spin the camera.
- **Read:** frame ms vs the overlay's **LOD distribution** (the
  `level_counts()` line) — cost should track the FULL+REDUCED share, not
  raw enemy count. Watch a REDUCED enemy while closing distance:
  re-entering FULL must not visibly snap (raise `reduced_update_hz` or push
  `reduced_distance` out until it doesn't).
- **Tunes:** every band/rate in `lod_config.tres`. Keep `hysteresis` wide
  enough that no enemy flickers levels while you strafe on a band edge.

## 4. RVO go / no-go (fills avoidance_* in greybox_director.tres)

- **Do:** flip `avoidance_enabled` in `greybox_director.tres`, restart,
  debug-spawn 50, and let them fully converge on a cornered player (the
  worst case — a packed jam, not a walking line).
- **Read:** physics ms delta ON vs OFF at the same converged jam; watch for
  jitter/oscillation in the pile.
- **Tunes:** `avoidance_enabled` ships ON **only** if the jammed delta
  clears the frame budget; `avoidance_radius` / `avoidance_max_neighbors`
  trade separation quality against that delta.
- **First data point (2026-07-14, placeholder KayKit rig, greybox):**
  spread-out walking 50 ≈ 2.1 ms physics; **converged jam: 17.4 ms ON vs
  3.75 ms OFF** → shipped OFF. Agents' `max_speed` is capped at
  `move_speed` at registration — without the cap RVO flung packed zombies
  at ~4.5× walk speed.

## 5. Director pressure (fills the pacing knobs)

- **Do:** author a ramped `pressure_curve` in `greybox_director.tres`
  (0 → 1 over the round), start a real wave, and watch a full round.
- **Read:** spawn cadence early vs late in the round (interval should slide
  `interval_relaxed` → `interval_peak`), concurrent alive vs
  `RoundConfig.max_concurrent` (ceiling should slide
  `concurrent_floor_fraction` → 1.0), and the overlay's enemy count —
  which must **never** exceed the pool's 50.
- **Tunes:** `pressure_curve`, `interval_relaxed/peak`,
  `concurrent_floor_fraction` — the per-map difficulty feel. The flat 0.5
  curve is the "exactly like pre-director" reference to A/B against.

## Recording template

| Step | Enemies | FULL/RED/PAUSE/CULL | FPS | frame ms | physics ms | draw calls | notes |
|---|---|---|---|---|---|---|---|
| baseline | 0 | – | | | | | |
| ramp-FULL | 10 / 25 / 50 | all FULL | | | | | |
| bands | 50 | (record) | | | | | knob + value |
| RVO | 50 jam | – | | | | | ON vs OFF delta |
| pressure | wave | – | | | | | interval early/late |
