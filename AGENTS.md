# Repository Instructions

This repository uses Git at the repository root only:
`/home/work/myProject/customLightGlue/LightGlue`.

Before changing code, always inspect the repository state:

```bash
git status --short --branch
```

Git workflow rules for this repository:

- `main` is the sync baseline. Daily work should happen on branches named `work/YYYYMMDD-<topic>`.
- Do not start an automatic Codex edit session from a dirty working tree.
- When a model should modify files, prefer `scripts/codex_auto_commit.sh` over plain `codex`.
- Plain `codex` is fine for reading, analysis, and planning, but it does not guarantee an automatic Git checkpoint.
- Automatic checkpoints created by the wrapper use `codex:` or `codex-wip:` commit prefixes.
- The wrapper does not push to remotes. Push only after reviewing the local commits.
- If the Git workflow changes, update `docs/git-workflow.md` in the same change.

Preferred automatic edit entrypoint:

```bash
scripts/codex_auto_commit.sh -m "short summary" "your implementation prompt"
```

Authoritative workflow documentation:

- `docs/git-workflow.md`
