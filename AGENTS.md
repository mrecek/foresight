# AGENTS.md

## Stack

- Ruby
- SQLite
- Rails + Hotwire/Turbo + Stimulus
- Tailwind via the Rails toolchain

## Agent Workflow

- Use `.agents/skills/foresight-dev/` for local setup, running the app, test mode, demo data, local debugging, and validation.
- Use `.agents/skills/foresight-git-workflow/` only when the user explicitly requests commit, push, PR, merge, rebase, or CI/CD workflow investigation.
- Canonical portable skills live in `.agents/skills/`.

## Boundaries

- Never perform git operations unless the user explicitly requests them.
- Prefer repository source-of-truth files over prose summaries when they disagree.
- Keep human-facing documentation in `README.md` and `CONTRIBUTING.md`; keep agent workflow detail in skills.
