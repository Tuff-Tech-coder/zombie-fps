# Lab report: repo-conventions

Branch `claude/repo-conventions`, from `main` @ 689a935 (clean CC0-only import).

## What changed
1. Design docs moved into `docs/`; added `docs/README.md` index and empty `briefs/`, `prompts/done/`, `lab-reports/`.
2. `CLAUDE.md`: batch conventions, git workflow summary, commands.
3. `docs/git-workflow.md`: the full branch / commit / PR rules.
4. `zombie-fps/tests/`: headless smoke suite, 29 checks (no `.fbx`/`.mp3` in the project; walker, boss, city and greybox scenes load and instantiate; both soundtracks have non-empty streams; enemy clips exist on the skeleton; the WAVE-button path starts a run, zombies spawn, boss spawns and dies).
5. `docs/CHANGELOG.md`: Unreleased entry recording the CC0 asset swap.

## Tests
`godot --headless --path zombie-fps res://tests/test_runner.tscn` → `TESTS: 29/29 passed`, exit 0.

## Not checked
- Nothing was played with a screen: no visual check of the skeleton enemies and no check of boss attack feel.
- The headless run ends with the engine's "objects leaked at exit" warnings; not investigated.

## Notes for the owner
- No tag is created. To tag the current baseline: `git tag -a v0.8.3.5 -m "Baseline: CC0-only build" <commit>` then `git push origin v0.8.3.5`.
