# MODEL_BUDGET — Per-Enemy Asset Ceiling (Horde Phase 4)

> First-principles budget so enemy/rig selection for the v0.8.0 art pass
> cannot blow the frame budget at the 50-agent cap. Target box: **RTX 4060 /
> i5-13600KF at 60 FPS** (16.67 ms/frame). Every number below is a **starting
> target to be validated by PROFILING_PLAYBOOK.md** against the actual
> imported rigs — grounded, not arbitrary, but not yet measured.

## The one number that explains the cost

In Godot 4 the dominant per-enemy cost is **skeletal**: CPU bone-pose updates
plus `AnimationTree` evaluation, not raster. Reference order of magnitude:
CPU-skinning ~100 characters at 50 bones × 5,000 verts ≈ 25M vertex
transforms per frame ≈ ~60 ms — about **3.6× a whole 60 FPS frame** (the
large-`Skeleton3D` slowdown is a tracked Godot issue). That is exactly why
the Phase 2 animation-LOD throttles `AnimationTree.advance()`: the budget
below keeps the **un-throttled near set** lean, and LOD carries the rest.

## Budgets (each: profile to confirm)

| Budget | Provisional target | Rationale / ceiling |
|---|---|---|
| **Bones / rig** | ≤ **40**, hard ceiling ~55 | Bone count drives the CPU pose update — it is the skeletal multiplier on everything. Use a *game* rig, not a VFX skeleton: Mixamo standard is ≈65 with fingers — strip fingers/face on import. KayKit rigs are already lean. |
| **Triangles (near)** | ~**2,000–4,000** | KFMod low-poly (DESIGN_DOC §7) makes this trivial; heavy fog hides silhouette simplification well before it reads as cheap. |
| **LOD tiers** | source LOD0/1 if the asset ships them; else animation-LOD + distance only | Geometry LOD is secondary to animation-LOD in Godot 4 — don't buy tris savings with extra import complexity until profiling says raster is the wall. |
| **Materials / draw calls** | **1 material, 1 draw call** per enemy | At 50 agents a second material doubles enemy draw calls (50 → 100). Atlas the texture instead. |
| **Animation set** | 3 clips (walk / attack / death); **import compression on**; ~30 fps sampling | Matches the `EnemyVisual` 3-state machine exactly — extra clips are dead weight per rig. |
| **Horde totals @ 50** | ≤ ~**150–200k tris**, ≤ ~**50 draw calls** from enemies | Leaves raster headroom for fogged city dressing (v0.8.0). Validate on the 4060 per the playbook. |

## Retarget note (why clip memory doesn't scale with enemy types)

Final humanoid rigs use `EnemyVisual`'s **retargeted mode**: the GLB imports
with `import_as_skeleton_bones = true` + a **BoneMap** against
`SkeletonProfileHumanoid`, and a single shared compressed `AnimationLibrary`
is injected at bind time (import checklist: CODE_GUIDE → Horde architecture).
One clip library therefore serves **every** humanoid rig — clip memory is a
constant, not a per-type cost, which keeps the ≤4-enemy-type firewall
(DESIGN_DOC §11) cheap to honor.

## How to use this file

Picking or building an enemy model for v0.8.0+: check the candidate against
every row **before** import work starts; then run PROFILING_PLAYBOOK.md
step 2 (spawn ramp, LOD forced FULL) with the real rig to confirm the near-set
cost, and re-tune `lod_config.tres` bands afterwards. If a candidate misses a
row, fix the asset (strip bones, atlas, decimate) — never widen the budget to
fit the asset.
