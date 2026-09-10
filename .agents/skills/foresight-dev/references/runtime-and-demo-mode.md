# Runtime And Demo Mode

Use this reference when you need an easy local runtime for manual or automated testing.

## Test Mode

Enable test mode with:

```bash
TEST_MODE=true bin/dev
```

When test mode is active:

- authentication is bypassed
- session timeout is disabled
- the UI shows a visible test-mode banner
- test mode is disabled automatically in production environments

## Demo Data

Seed sample accounts, recurring rules, and transactions with:

```bash
SEED_DEMO_DATA=true bin/rails db:seed
```

This creates demo credentials:

- username: `demo`
- password: `demo1234`

## Recommended Runtime Flows

For agent-driven local testing:

```bash
SEED_DEMO_DATA=true bin/rails db:seed
TEST_MODE=true bin/dev
```

For manual testing with authentication enabled:

```bash
SEED_DEMO_DATA=true bin/rails db:seed
bin/dev
```

Then sign in with `demo` / `demo1234`.

## Stopping The Dev Server

Stop `bin/dev` with `Ctrl+C` when its terminal is attached. For a detached run, retain its process or session identifier, send that exact process `TERM`, and confirm it exited.

When ownership is unknown, inspect the process and leave it running until its identity is established. Port ownership alone is not proof that a process belongs to this task.

Completion means every process started by the current task has exited and its port is released.
