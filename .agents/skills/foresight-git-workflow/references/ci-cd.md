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
- The container release workflow owns daily OS-package refreshes. It rebuilds the named `os-packages` stage and publishes every verified scheduled candidate, including unchanged package inventories. The schedule also catches updates merged with `GITHUB_TOKEN`, which suppresses downstream push events.
- Ruby minor and major upgrades, GitHub Actions, and Docker changes stay under human review.
- The scheduled security workflow audits dependencies and scans the released digest daily with read-only permissions. Vulnerable images and builds older than seven days fail with actionable evidence; remediation travels through source updates and the independent release lane.

Inspect Dependabot metadata and the eligibility script before changing an auto-merge boundary. Complete a change only when an ineligible ecosystem and major Bundler update still fail closed.

The Ruby updater uses a stable automation branch and the pinned create-pull-request action to create or update its proposal. Closing an unmerged proposal does not permanently suppress future attempts: the next stale-version run recreates the proposal. To pause updates intentionally, disable the freshness workflow. The updater dispatches `ci.yml` explicitly on every open proposal head because `GITHUB_TOKEN` events do not start unattended pull-request CI. If one stalls, inspect the freshness run, dispatched CI at the current head, and required checks. An unsupported Ruby error from setup-ruby requires a reviewed action-pin update before retrying; the action embeds its supported runtime list.

## Container Publication

`docker.yml` is the common entry point for source, scheduled, security, and manual releases. It builds a run-specific candidate and gates every candidate on application validation, vulnerability policy, manifest portability, smoke tests on both native architectures, provenance, and SBOM evidence. The build, native verification matrix, and promotion jobs pass one immutable index digest through job outputs; promotion requires both native jobs to succeed. Keep QEMU limited to building. Every smoke run requires three clean shutdowns within the unchanged 30-second deadline. Security policy exceptions use effective gem versions collected from the exact image under audit; repository lockfiles are not evidence of the released runtime. Scheduled builds refresh the OS stage even when Git has not changed.

Every accepted digest receives an immutable `release-<UTC time>-<source SHA>-<run>-<attempt>` recovery tag before `latest` moves. `rollback-container-release.yml` restores one retained verified release with an expected-current-digest guard. `container-retention.yml` defaults manual runs to dry-run, keeps the latest 30 promoted digests, and expires candidate-only artifacts after 14 days. All production tag mutation and cleanup uses the `foresight-container-production` concurrency group.

Publication is complete only when `latest` and the immutable release tag resolve to the verified digest. A failed partial promotion is recovered by rerunning the same workflow attempt; tag creation is idempotent and collisions fail closed.

## Inspection Commands

```bash
gh workflow list --all
gh run list --limit 20
gh pr checks <number>
gh api repos/{owner}/{repo}/rulesets
```
