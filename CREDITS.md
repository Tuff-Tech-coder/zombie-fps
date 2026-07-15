# CREDITS — asset provenance

Per DESIGN_DOC §10 / CODE_GUIDE license hygiene: every third-party asset is
logged here (CC-BY requires credit; CC0 is logged for provenance).

## Third-party assets

| Asset | Author | Source | License | Used for |
|---|---|---|---|---|
| Character Pack: Skeletons (`Skeleton_Minion.glb`) | KayKit / Kay Lousberg | github.com/KayKit-Game-Assets | CC0 | Placeholder enemy rig (since v0.3.0; license file alongside the model under `enemies/models/`) |

## Original works (no license obligations)

- **City textures** (`zombie-fps/world/city/textures/*.png`, v0.8.0): all 20
  generated in-engine by `world/city/textures/_texture_bake.gd` (FastNoiseLite
  + Image API; poster decals rendered through a SubViewport using a serif
  system font). Signage and posters use **fictional period brands** only
  (Bovrin, Pennywhistle Tea, Oakhurst, Merriweather's, Grow & Save, plus the
  shop names on the high street) — no real trademarks are reproduced.
- **City geometry and props** (`world/city/city.tscn`): hand-authored from
  Godot primitive meshes; no imported models.
- **Audio**: all SFX are runtime-synthesized placeholders
  (`weapons/placeholder_sfx.gd`) — no binary audio assets yet (period
  ambience sourcing per DESIGN_DOC §10 remains open).
