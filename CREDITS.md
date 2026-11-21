# CREDITS — asset provenance

Per DESIGN_DOC §10 / CODE_GUIDE license hygiene: every third-party asset is
logged here (CC-BY requires credit; CC0 is logged for provenance).

## Third-party assets

| Asset | Author | Source | License | Used for |
|---|---|---|---|---|
| Character Pack: Skeletons (`Skeleton_Minion.glb`) | KayKit / Kay Lousberg | github.com/KayKit-Game-Assets | CC0 | All enemies (walker and boss, boss scaled up); license file alongside the model under `enemies/models/` |
| Godot AI addon v3.0.3 (`addons/godot_ai/`) | Godot AI contributors | upstream plugin repo | MIT | Editor tooling only; license in `zombie-fps/godot-ai-LICENSE.txt` |

## Original works (no license obligations)

- **City textures** (`zombie-fps/world/city/textures/*.png`, v0.8.0): all 20
  generated in-engine by `world/city/textures/_texture_bake.gd` (FastNoiseLite
  + Image API; poster decals rendered through a SubViewport using a serif
  system font). Signage and posters use **fictional period brands** only
  (Bovrin, Pennywhistle Tea, Oakhurst, Merriweather's, Grow & Save, plus the
  shop names on the high street) — no real trademarks are reproduced.
- **City geometry and props** (`world/city/city.tscn`): hand-authored from
  Godot primitive meshes; no imported models.
- **Audio**: all music and SFX are synthesized in-engine
  (`weapons/placeholder_sfx.gd`, `audio/_sfx_bake.gd` → `resources/audio/generated/*.res`).
  No third-party audio is included.

## Project license

The project's own code, scenes and generated assets are MIT-licensed (see
`LICENSE` at the repo root). Third-party items in the table above keep their
own licenses (KayKit: CC0; Godot AI addon: MIT).
