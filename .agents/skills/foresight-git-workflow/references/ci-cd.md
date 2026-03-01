# CI/CD

Use this reference when the task is about GitHub Actions, Docker publishing, Dependabot, or PR gates.

## Source Of Truth

If this reference and the workflow YAML differ, trust:

- `.github/workflows/ci.yml`
- `.github/workflows/docker.yml`
- `.github/workflows/auto-merge-dependabot.yml`
- `.github/dependabot.yml`

## Pull Request CI

`ci.yml` runs on pull requests only.

Current jobs:

- `scan_ruby`: `bin/brakeman --no-pager` and `bin/bundler-audit`
- `scan_js`: `bin/importmap audit`
- `lint`: `bin/rubocop -f github`
- `test`: `ruby -Itest -Ilib test/models/*_test.rb test/services/*_test.rb`

The repo’s broader local pre-PR gate remains:

```bash
bin/test
bundle exec rubocop
bin/brakeman --no-pager
```

## Docker Publish Workflow

`docker.yml` runs on:

- push to `main`
- manual dispatch with `gh workflow run docker.yml`

Current behavior:

- builds amd64 and arm64 images
- publishes `latest-amd64` and `latest-arm64`
- runs an amd64 smoke test against `http://localhost:3000/up`
- publishes multi-arch manifests for `latest` and the current date (`YYYY-MM-DD`)

## Dependabot And Auto-Merge

`.github/dependabot.yml` currently configures:

- Bundler updates weekly on Monday at 06:00 in `America/Denver`, grouped into one PR
- GitHub Actions updates monthly, grouped into one PR

`auto-merge-dependabot.yml` listens on `pull_request_target` and enables:

```bash
gh pr merge --auto --squash "$PR_URL"
```

for Dependabot PRs only.

## Useful GitHub CLI Commands

Check recent runs:

```bash
gh run list --workflow=ci.yml
gh run list --workflow=docker.yml
```

Trigger the Docker workflow manually:

```bash
gh workflow run docker.yml
```

List Dependabot PRs:

```bash
gh pr list --author="dependabot[bot]"
```
