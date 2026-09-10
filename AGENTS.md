# AGENTS.md

## Stack

- Ruby
- SQLite
- Rails + Hotwire/Turbo + Stimulus
- Tailwind via the Rails toolchain

## Product Boundary

- Foresight is a public, self-hostable application distributed as an OCI container.
- Keep deployment guidance portable. Describe the container contract and SQLite's single-writer storage requirement, not a maintainer's infrastructure.

## Routes

- For local setup, runtime, test mode, demo data, debugging, or validation, read `.agents/skills/foresight-dev/SKILL.md`.
- For an explicit git operation or CI/CD investigation, read `.agents/skills/foresight-git-workflow/SKILL.md`.
- Canonical portable skills live in `.agents/skills/`.

## Boundaries

- Never perform git operations unless the user explicitly requests them.
- Treat repository commands and configuration as source of truth; agent prose supplies procedure and intent.
- Keep the public product, architecture, and contributor entry points in `README.md` and `CONTRIBUTING.md`; keep agent procedures in skills.
