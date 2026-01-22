# CI/CD Pipeline

This document describes the automated CI/CD workflows for Foresight.

## Overview

```
┌─────────────────────────────────────────────────────────────────┐
│  Pull Request Created                                           │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  CI Workflow runs: scan_ruby, scan_js, lint, test               │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  PR merged to main                                              │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  Docker Workflow triggers automatically                         │
│  • Builds amd64 + arm64 images                                  │
│  • Runs smoke test                                              │
│  • Pushes to ghcr.io with :latest tag                           │
└─────────────────────────────────────────────────────────────────┘
```

## Workflows

### CI (`ci.yml`)

Runs on pull requests only. Must pass before merging.

| Job | Purpose |
|-----|---------|
| `scan_ruby` | Brakeman security scan |
| `scan_js` | JavaScript dependency audit |
| `lint` | RuboCop style enforcement |
| `test` | Full test suite (171 tests) |

> **Optimization:** CI does not run on push to main—the PR check is sufficient. This halves CI runs per merge.

### Docker Build (`docker.yml`)

Triggers on:
- **Push to main** - Automatic after PR merge
- **Manual dispatch** - For ad-hoc builds

Builds multi-architecture images (amd64 + arm64), runs a smoke test, and pushes to GitHub Container Registry with `:latest` and date-based tags.

**Path exclusions:** Documentation changes (`*.md`, `docs/**`) and Dependabot config updates don't trigger Docker builds.

### Auto-Merge Dependabot (`auto-merge-dependabot.yml`)

Automatically enables `--auto --squash` merge for Dependabot PRs. Once CI passes, the PR merges without manual intervention.

Uses `pull_request_target` trigger so the workflow only appears in the Actions tab for Dependabot PRs—regular PRs won't see this workflow at all.

## Dependency Management

Dependabot is configured for zero-touch dependency updates:

| Ecosystem | Schedule | Grouping |
|-----------|----------|----------|
| Ruby gems | Weekly (Monday 6am MST) | All gems in single PR |
| GitHub Actions | Monthly | All actions in single PR |

### How It Works

1. **Monday 6am**: Dependabot creates ONE grouped PR with all gem updates
2. **CI runs**: All 4 jobs must pass
3. **Auto-merge**: PR merges automatically when CI is green
4. **Docker builds**: New image pushed to `ghcr.io/mrecek/foresight:latest`

### Why Grouped Updates?

Individual dependency PRs create a "rebase cascade" - after merging one PR, all others conflict via `Gemfile.lock` and need rebasing. Grouping eliminates this overhead for solo/small team development.

## Container Registry

Images are published to: `ghcr.io/mrecek/foresight`

| Tag | Description |
|-----|-------------|
| `:latest` | Most recent build (multi-arch manifest) |
| `:YYYY-MM-DD` | Date-stamped build |
| `:latest-amd64` | AMD64-specific image |
| `:latest-arm64` | ARM64-specific image |

## Manual Operations

### Trigger Docker Build Manually

```bash
gh workflow run docker.yml
```

### Check Workflow Status

```bash
gh run list --workflow=ci.yml
gh run list --workflow=docker.yml
```

### View Dependabot PRs

```bash
gh pr list --author="dependabot[bot]"
```
