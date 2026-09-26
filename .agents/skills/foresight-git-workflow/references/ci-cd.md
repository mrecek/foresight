# CI/CD

Use this reference to inspect or change pull-request validation, dependency automation, or container publication.

## Inspect Before Acting

Read the live files for exact jobs, schedules, versions, and commands:

- `.github/workflows/`
- `.github/dependabot.yml`
- `.github/scripts/`
- `config/validation.rb`

For mergeability or repository policy, inspect the live GitHub ruleset and repository merge settings. A workflow job is advisory until the ruleset requires its check.

## Pull-request Contract

`ci.yml` delegates each job to a named `bin/validate` stage. Every job currently defined in that workflow must be a required main-branch check. When adding, removing, or renaming a job, update and read back the ruleset in the same change.

Completion means every required check is present on the pull request and successful at its current head revision.

## Dependency Ownership

- Dependabot owns Bundler, GitHub Actions, and Docker base-digest proposals.
- Only Bundler patch and minor changes are eligible for auto-merge.
- The Ruby freshness workflow owns patch updates across `.ruby-version`, `.mise.toml`, `mise.lock`, and the digest-pinned Docker base.
- The container release workflow owns weekly OS-package refreshes. It rebuilds the named `os-packages` stage without changing source, classifies package inventories, and promotes a changed digest only after the common release gates pass.
- Ruby minor and major upgrades, GitHub Actions, and Docker changes stay under human review.
- The scheduled security workflow audits dependencies and scans the released digest daily. A stale or vulnerable released artifact dispatches one refresh through the common production lane; source dependency remediation still travels through a pull request.

Inspect Dependabot metadata and the eligibility script before changing an auto-merge boundary. Complete a change only when an ineligible ecosystem and major Bundler update still fail closed.

Automation pull requests created with `GITHUB_TOKEN` do not emit a new `pull_request` workflow run. The Ruby freshness workflow therefore dispatches `ci.yml` explicitly on its automation branch. If one stalls, inspect the freshness run, dispatched CI run at the pull-request head, and repository auto-merge settings before changing code.

## Container Publication

`docker.yml` is the common entry point for source, weekly, security, and manual releases. It builds a run-specific candidate, records both platform package inventories, stops unchanged refreshes without moving production, and gates changed candidates on application validation, package policy, vulnerability policy, manifest portability, smoke tests, provenance, and SBOM evidence.

Every accepted digest receives an immutable `release-<UTC time>-<source SHA>-<run>-<attempt>` recovery tag before `latest` moves. `rollback-container-release.yml` restores one retained verified release with an expected-current-digest guard. `container-retention.yml` defaults manual runs to dry-run, keeps the latest five promoted digests, and expires candidate-only artifacts after 14 days. All production tag mutation and cleanup uses the `foresight-container-production` concurrency group.

Publication is complete only when `latest` and the immutable release tag resolve to the verified digest. A failed partial promotion is recovered by rerunning the same workflow attempt; tag creation is idempotent and collisions fail closed.

## Inspection Commands

```bash
gh workflow list --all
gh run list --limit 20
gh pr checks <number>
gh api repos/{owner}/{repo}/rulesets
```
