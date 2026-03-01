---
name: foresight-dev
description: >
  Local development, runtime, testing, and validation workflow for the Foresight Rails app.
  Use when an agent needs to run the app, debug locally, start the dev server, enable test
  mode, seed demo data, run tests, validate a code change, or smoke test the application.
---

# Foresight Dev

Own local development and validation tasks for this repository.

## Source of Truth

- Trust repo commands in `bin/` over prose summaries when they disagree.
- Use `bin/dev` for the standard local runtime.
- Hand off commit, PR, push, merge, rebase, and CI/CD workflow questions to [`../foresight-git-workflow/SKILL.md`](../foresight-git-workflow/SKILL.md).

## Read the Right Reference

- For install, bootstrap, and standard startup, read [references/local-setup.md](references/local-setup.md).
- For `TEST_MODE`, demo data, demo credentials, and shutting down the dev server, read [references/runtime-and-demo-mode.md](references/runtime-and-demo-mode.md).
- For local verification, targeted tests, RuboCop, and Brakeman, read [references/testing-and-validation.md](references/testing-and-validation.md).

## Working Rules

- Prefer the lightest command that proves the requested change.
- Stop background dev servers when you are finished with runtime testing.
- Keep commit and PR policy out of this skill; that belongs to `foresight-git-workflow`.
