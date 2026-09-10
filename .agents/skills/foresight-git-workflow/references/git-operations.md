# Git Operations

Use this reference after the user explicitly requests git work. A request to ship or rapid-ship authorizes the normal branch, commit, push, pull-request, green-CI, and merge sequence; a request to change code alone stops before those operations.

## Prepare

Inspect the current branch, worktree, and diff. Preserve unrelated changes. Use a `codex/<type>/<topic>` branch when the host requires the `codex/` prefix; otherwise use `<type>/<topic>`, where type is `feature`, `fix`, `chore`, or `docs`.

Bring an existing branch up to date with `origin/main` before final validation. Use force-with-lease only for a branch whose rewritten commits belong to the current task.

## Prove

Run the lightest focused checks during development. Before delivery, run:

```bash
bin/validate
```

The delivery gate is green when the complete local contract passes on the supported runtime and the diff contains only intended changes.

## Commit And Open

Group commits by independently reviewable outcome. Use Conventional Commits:

```text
<type>[(scope)][!]: <imperative summary>
```

Stage explicit paths, commit, push the branch, and open a pull request whose body states the outcome, material decisions, and validation evidence. Never place credentials or private environment details in commits or pull requests.

## Merge And Close

Read the current pull-request head and required checks after the final push. Merge only the reviewed head when every required check is successful:

```bash
gh pr merge --squash --delete-branch <number>
```

Completion means the pull request is merged by squash, `main` contains the accepted result, the delivered branch is removed, and any durable task records the accepted revision and evidence.
