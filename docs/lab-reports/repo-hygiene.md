# Lab report: repo-hygiene

Branch `claude/repo-hygiene`, from `main` @ 6ec824a (after repo-conventions merged).

## What changed
- `.gitignore`: added `.godot/`, `.import/`, `*.tmp`, `/builds/`, `/export/` (root and `zombie-fps/`), OS junk (`.DS_Store`, `Thumbs.db`, `desktop.ini`, `*.swp`), alongside `_private/` and `_to_delete/`. `*.import` files stay tracked.

## Checks (no file changes needed)
- **Large files:** none over 50 MB. Largest tracked file is `Skeleton_Minion.glb` (4.8 MB); next are the generated audio loops (0.5 MB). No Git LFS needed.
- **Engine version / renderer / main scene** (`zombie-fps/project.godot`): Godot **4.7**, features `"4.7", "Forward Plus"` (no `rendering_method` override, so Forward+), main scene `res://world/city/city.tscn`.
- **Export presets:** `export_presets.cfg` is not tracked yet (the playable-build batch creates it).
- **Junk tracked:** none (`.tmp`, OS files, `export_presets.cfg` absent).
- **Headless import** (`--import`): no errors or warnings.
- **Headless boot** (`--quit-after 600`): no script, resource or audio errors. Only exit-time engine messages: "2 ObjectDB instances were leaked at exit" and "1 resources still in use at exit". Not investigated.
- **Tests:** `TESTS: 29/29 passed`.
