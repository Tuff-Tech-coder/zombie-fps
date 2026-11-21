# Zombie FPS

Single-player wave-survival FPS in Godot 4.7 (GDScript), inspired by CoD Zombies and Killing Floor. The Godot project is in `zombie-fps/`; docs are in `docs/`. Read `docs/DESIGN_DOC.md` and `docs/CODE_GUIDE.md` before changing code.

## Conventions (every batch)

- One batch = one branch = one pull request. Update batches are small and scoped to one prompt in `docs/prompts/`.
- Each section of the prompt is its own commit, able to be rolled back alone.
- Cross-system events go through `EventBus`. Rules and numbers live in `resources/` data or tuning constants, not scattered in scenes (`docs/CODE_GUIDE.md`).
- **CC0-only assets.** Every third-party asset is logged in `CREDITS.md` with its license. Nothing without a clear redistributable license enters the repo (no Mixamo, no ripped music, no reference screenshots). Generated placeholders (`audio/_sfx_bake.gd`, `world/city/textures/_texture_bake.gd`) are fine.
- Design calls and what shipped go in `docs/CHANGELOG.md`. Keep `docs/CODE_GUIDE.md` current when a convention changes.
- A batch ends with a lab report in `docs/lab-reports/<batch>.md` (what changed, test counts, what was checked in-engine). As the last commit, `git mv` the batch's prompt from `docs/prompts/` to `docs/prompts/done/`. Then push, open the PR, and **stop and report**. Don't start the next batch.
- Never commit `_private/` or `_to_delete/` (both git-ignored). Do not delete files; move them to `_to_delete/`.
- Stage only your own files. Never discard the user's uncommitted edits.

## Git workflow

Full rules in `docs/git-workflow.md`. Short version:

- Start from `main`: `git checkout main && git pull && git checkout -b claude/<batch>` (kebab-case).
- Push after each commit (`git push -u origin claude/<batch>`).
- End with a PR into `main` (`gh pr create`) titled with the batch name; body = lab-report summary + test counts. The user reviews and merges. **Never merge or push to `main`.**
- The remote is private. Never change repo visibility and never create releases.
- Tag only when the user calls a build a milestone: `git tag -a v0.N.N -m "<what>"`, then push the tag.
- Do not rewrite history on `main`. The history was reset once (clean CC0-only import); keep it linear and reviewable.
- The Godot editor may have this folder open. Tell the user before a checkout or pull that changes many files; the editor needs a restart afterwards.

## Commands

Godot 4.7 is at `C:/Users/Dan/Desktop/Godot_v4.7-stable_win64_console.exe` (call it `$G`). Run from the repo root.

```bash
$G --headless --path zombie-fps --import                         # refresh imports / class cache
$G --headless --path zombie-fps --quit-after 600                 # boot the game headless; watch for errors
$G --headless --path zombie-fps res://tests/test_runner.tscn     # all tests: one summary line, exit code 1 on failure
```

- Run every Godot command under a time limit: `timeout -k 10 300 $G ...`. One Godot process at a time; end any `--headless` process left behind.
- Tests are scenes, not `--script` runs, because autoloads (`EventBus`, `RoundManager`, ...) only exist when the scene tree boots.
- Rounds start via the debug WAVE button in the world (`DebugManager.toggle_wave_stub()`), not automatically.
