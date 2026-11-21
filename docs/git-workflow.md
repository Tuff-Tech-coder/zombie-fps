# Git workflow

`main` is always the latest build the owner has reviewed. Nothing reaches it without review.

## A batch

1. **Branch.** `git checkout main && git pull && git checkout -b claude/<batch-name>` (kebab-case, e.g. `claude/crafting-pass`). Stack on an unmerged batch only when the owner says so; say which base in the PR.
2. **Prompt.** The batch is built from one file in `docs/prompts/` (kebab-case, e.g. `v0-9-0-crafting-pass.md`). The prompt says what to build, split into sections. It does not describe git mechanics.
3. **Commits.** One commit per section, message `<batch> <n>: <what>`. Each commit leaves the game booting. Push after every commit.
4. **Tests.** Run the smoke suite (command in `CLAUDE.md`) before each push.
5. **Close-out.** Last commits: the lab report (`docs/lab-reports/<batch>.md`), a `docs/CHANGELOG.md` entry, and `git mv` of the prompt into `docs/prompts/done/`.
6. **Pull request.** `gh pr create` into `main`, titled with the batch name; body = the lab report's summary, test counts and a link to the report.
7. **Stop.** The owner runs the build, playtests, reviews and merges. Only then does the next batch start, from the updated `main`.

## Rules

- The remote is private. Never change visibility, never create releases, never push to `main`.
- No history rewrites on shared branches (`main`, or a branch with an open PR).
- Tags are annotated, on `main`, and only when the owner calls a build a milestone (`v0.N.N`, matching `docs/CHANGELOG.md`).
- Every third-party asset needs a license that allows redistribution and an entry in `CREDITS.md` before it is committed.
- `_private/` and `_to_delete/` are git-ignored working folders; never commit them.
