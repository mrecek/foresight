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

If you still control the terminal, stop `bin/dev` with `Ctrl+C`.

Otherwise:

```bash
pkill -f "bin/dev"
lsof -ti:3000 | xargs kill -9
```

Always stop the dev server after automated testing so port 3000 is available for the next run.
