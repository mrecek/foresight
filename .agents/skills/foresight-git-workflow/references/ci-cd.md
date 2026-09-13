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
- The OS package freshness workflow inspects the immutable released image. When Debian packages are stale, it advances only `OS_PATCH_EPOCH`, validates a rebuilt image, opens one pull request, explicitly dispatches protected CI, and enables squash auto-merge.
- Ruby minor and major upgrades, GitHub Actions, and Docker changes stay under human review.
- The scheduled security workflow detects dependency, application, and image findings; remediation still travels through a pull request.

Inspect Dependabot metadata and the eligibility script before changing an auto-merge boundary. Complete a change only when an ineligible ecosystem and major Bundler update still fail closed.

Automation pull requests created with `GITHUB_TOKEN` do not emit a new `pull_request` workflow run. Ruby and OS refresh workflows therefore dispatch `ci.yml` explicitly on the automation branch. If one stalls, inspect the source freshness run, the dispatched CI run at the pull-request head, and repository auto-merge settings before changing code.

## Container Publication

`docker.yml` builds an unpromoted candidate, smoke-tests every supported architecture, verifies provenance, then promotes release tags. The full commit-SHA tag is the completion marker. `reconcile-container-release.yml` repairs a partial promotion without rebuilding accepted artifacts.

Publication is complete only when the manifest contains every supported architecture, smoke tests passed, provenance refers to the promoted digest, and the commit-SHA marker exists.

## Inspection Commands

```bash
gh workflow list --all
gh run list --limit 20
gh pr checks <number>
gh api repos/{owner}/{repo}/rulesets
```
