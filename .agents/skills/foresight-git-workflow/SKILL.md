---
name: foresight-git-workflow
description: >
  Explicit-request-only git operations and CI/CD workflow guidance for Foresight.
  Use when an agent is asked to commit changes, push a branch, open or merge a PR, rebase a
  branch, inspect GitHub Actions, explain what CI runs, check Docker publishing, or review
  Dependabot and auto-merge behavior.
---

# Foresight Git Workflow

Own git, PR, merge, and CI/CD workflow tasks for this repository.

## Hard Gate

- Use this skill only when the user explicitly requests git operations, or when the task is specifically about CI/CD workflow behavior.
- Do not infer permission to commit, push, create a PR, or merge from a code-change request alone.

## Source of Truth

Inspect repo configuration before acting:

- `.github/workflows/ci.yml`
- `.github/workflows/docker.yml`
- `.github/workflows/auto-merge-dependabot.yml`
- `.github/dependabot.yml`

Trust those files over prose summaries when they disagree.

## Read the Right Reference

- For commit, push, PR, merge, branch strategy, and approval checkpoints, read [references/git-operations.md](references/git-operations.md).
- For CI jobs, Docker publishing, Dependabot, and GitHub CLI inspection commands, read [references/ci-cd.md](references/ci-cd.md).
