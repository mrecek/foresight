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

- Dependabot owns weekly Bundler and pinned Ruby base patch proposals and separate security proposals.
- Only Bundler patches and patches to the declared Ruby base can auto-merge after required checks. Review mixed updates, unfamiliar metadata, and other upgrades.
- The Dockerfile declares the Ruby version. Local mise and shared CI setup read it with `bin/ruby-version`.
- The weekly release refreshes Debian packages and includes bot merges that suppress push events. Open the failed GitHub Actions run for the affected check. If the Ruby audit flags multiple gems, resolve them together and recheck the lockfile before retrying publication.

Inspect Dependabot metadata and the eligibility script before changing an auto-merge boundary. Complete a change only when an unrelated Docker image, Ruby series change, ineligible ecosystem, and minor or major Bundler update still fail closed.

For a stalled runtime update, inspect the ordinary Dependabot PR at its current head and its required checks. An unsupported Ruby installer requires a reviewed pin update in `.github/actions/setup-runtime/action.yml` before retrying. Version changes use the same Dependabot validation path as digest refreshes; no custom Ruby publisher or credential is needed.

## Container Publication

`docker.yml` is the common entry point for source, scheduled, security, and manual releases. It builds a run-specific candidate and gates every candidate on a current Ruby dependency audit, vulnerability policy, manifest portability, smoke tests on both native architectures, provenance, and SBOM evidence. The build, native verification matrix, and promotion jobs pass one immutable index digest through job outputs; promotion requires both native jobs to succeed. Keep QEMU limited to building. Every smoke run exercises web and jobs as separate containers sharing storage, proves maintenance through the real queue, and requires three clean shutdowns of each within the unchanged 30-second deadline. A separate early-startup stop check accepts normal signal termination before the jobs handlers are installed; forced termination always fails. Smoke logs remain available as architecture-specific artifacts when later checks do not run. Security policy exceptions use effective gem versions collected from the exact image under audit; repository lockfiles are not evidence of the released runtime. Scheduled builds refresh the OS stage even when Git has not changed.

Every accepted digest receives an immutable `release-<UTC time>-<source SHA>-<run>-<attempt>` recovery tag before `latest` moves. `rollback-container-release.yml` restores one retained verified release with an expected-current-digest guard. `container-retention.yml` defaults manual runs to dry-run, keeps the latest 30 promoted digests, and expires candidate-only artifacts after 14 days. All production tag mutation and cleanup uses the `foresight-container-production` concurrency group.

Publication is complete when `latest` and the immutable release tag both resolve to the verified digest. After a promotion failure, check those tags first. Retry just the failed promotion job if the candidate still matches the default branch and `latest` still matches the digest recorded before promotion. The intended release tag must be absent or already point to the candidate. If these conditions fail and publication is incomplete, start a new release from the current default branch. A full rerun creates a new candidate and release identity.

Registry rollback moves `latest`. For a Kubernetes installation pinned by digest, use its deployment workflow to restore a compatible image pin.

## Inspection Commands

```bash
gh workflow list --all
gh run list --limit 20
gh pr checks <number>
gh api repos/{owner}/{repo}/rulesets
```
