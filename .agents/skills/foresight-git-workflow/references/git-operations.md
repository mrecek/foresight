# Git Operations

Use this reference only after the user explicitly requests git operations.

## Core Gate

- Finish the code-change and local validation work first.
- Present results to the user before moving into commit or PR actions.
- Do not commit, push, create a PR, or merge until the user explicitly asks.

## Analyze Changes First

Inspect the working tree before choosing a branch or commit strategy:

```bash
git status
git diff
```

Understand:

- which files changed
- whether the change is a feature, fix, chore, or docs update
- whether the work naturally splits into multiple commits

## Branch Naming

Use the repo branch types:

- `feature/` for new capabilities or enhancements
- `fix/` for bug fixes
- `chore/` for maintenance, dependencies, or build changes
- `docs/` for documentation-only work

Format the branch as `<type>/<short-kebab-description>`.

If the host agent runtime requires an additional prefix, apply that prefix while preserving the repo branch type.

## Create Or Update The Branch

```bash
git checkout main
git pull --ff-only origin main
git checkout -b <type>/<short-kebab-description>
```

If the branch already exists and is behind `main`, update it with:

```bash
git fetch origin main
git rebase origin/main
```

## Required Local Checks Before Commit

Run these checks and ensure they pass before committing:

```bash
bin/test
bundle exec rubocop
bin/brakeman --no-pager
```

Verification criteria:

- tests finish with `0 failures, 0 errors`
- RuboCop reports no offenses
- Brakeman reports `0 warnings` and no obsolete ignores

If a changed file affects a fingerprint in `config/brakeman.ignore`, update that ignore entry as needed.

## Commit Grouping

Use multiple commits when:

- database migrations are present
- the work has distinct phases such as refactor then feature
- multiple application layers change with clean boundaries

Use a single commit when the changes are tightly coupled or small.

Before committing, present the proposed grouping to the user and get confirmation.

## Commit Messages

Use this format:

```text
<type>: <imperative summary under 72 chars>

- Key change 1
- Key change 2
- Key change 3
```

Guidelines:

- describe what changed and why
- use imperative mood
- focus the body on intent and impact, not file-by-file mechanics

## Commit, Push, And PR Flow

After the user approves the branch and commit plan:

```bash
git add <approved paths>
git commit -m "<message>"
git push -u origin HEAD
gh pr create --title "<title>" --body "<body>"
```

For a multi-commit plan, stage and commit each approved group separately.

The PR body should summarize:

- what the PR accomplishes
- the key changes
- notable decisions or trade-offs

## Merge Gate

Before merging:

- ensure CI is green
- confirm merge with the user

Check status with:

```bash
gh pr checks
```

If the branch is behind `main`, rebase, rerun:

```bash
bin/test
bundle exec rubocop
bin/brakeman --no-pager
```

Then push with `--force-with-lease` and wait for CI to pass again.

When approved and green, merge with:

```bash
gh pr merge --rebase --delete-branch
```
